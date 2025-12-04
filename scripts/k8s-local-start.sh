#!/usr/bin/env bash
#
# Start local Kubernetes cluster for InferaDB
#
# This script creates a kind cluster and deploys all InferaDB components:
# - FoundationDB
# - Management API (with Kubernetes service discovery)
# - Server (with Kubernetes service discovery)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-inferadb-local}"
NAMESPACE="${NAMESPACE:-inferadb}"
SERVER_IMAGE="${SERVER_IMAGE:-inferadb-server:local}"
MANAGEMENT_IMAGE="${MANAGEMENT_IMAGE:-inferadb-management:local}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=()

    if ! command -v kind &> /dev/null; then
        missing+=("kind")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install with: brew install ${missing[*]}"
        exit 1
    fi

    if ! docker ps &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi

    log_info "All prerequisites satisfied ✓"
}

create_cluster() {
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
        return 0
    fi

    log_info "Creating kind cluster '${CLUSTER_NAME}'..."

    cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
  - containerPort: 30081
    hostPort: 3000
    protocol: TCP
  - containerPort: 30090
    hostPort: 9090
    protocol: TCP
  - containerPort: 30091
    hostPort: 9091
    protocol: TCP
- role: worker
- role: worker
EOF

    log_info "Cluster created ✓"
    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
}

build_images() {
    log_info "Building Docker images..."

    # Build server
    log_info "Building server image..."
    docker build -t "${SERVER_IMAGE}" server/ || {
        log_error "Failed to build server image"
        exit 1
    }

    # Build management
    log_info "Building management image..."
    docker build -f management/Dockerfile.integration -t "${MANAGEMENT_IMAGE}" management/ || {
        log_error "Failed to build management image"
        exit 1
    }

    log_info "Images built ✓"
}

load_images() {
    log_info "Loading images into kind cluster..."

    kind load docker-image "${SERVER_IMAGE}" --name "${CLUSTER_NAME}"
    kind load docker-image "${MANAGEMENT_IMAGE}" --name "${CLUSTER_NAME}"

    log_info "Images loaded ✓"
}

create_namespace() {
    log_info "Creating namespace '${NAMESPACE}'..."

    kubectl create namespace "${NAMESPACE}" 2>/dev/null || true
    kubectl config set-context --current --namespace="${NAMESPACE}"

    log_info "Namespace ready ✓"
}

deploy_rbac() {
    log_info "Deploying RBAC resources..."

    kubectl apply -f server/k8s/rbac.yaml -n "${NAMESPACE}"
    kubectl apply -f management/k8s/rbac.yaml -n "${NAMESPACE}"

    log_info "RBAC deployed ✓"
}

deploy_foundationdb() {
    log_info "Deploying FoundationDB..."

    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: foundationdb-cluster-file
  namespace: ${NAMESPACE}
data:
  fdb.cluster: "docker:docker@foundationdb-0.foundationdb:4500"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: foundationdb
  namespace: ${NAMESPACE}
spec:
  serviceName: foundationdb
  replicas: 1
  selector:
    matchLabels:
      app: foundationdb
  template:
    metadata:
      labels:
        app: foundationdb
    spec:
      containers:
      - name: foundationdb
        image: foundationdb/foundationdb:7.3.69
        ports:
        - containerPort: 4500
        env:
        - name: FDB_NETWORKING_MODE
          value: container
        volumeMounts:
        - name: data
          mountPath: /var/fdb/data
        - name: logs
          mountPath: /var/fdb/logs
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
  - metadata:
      name: logs
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: foundationdb
  namespace: ${NAMESPACE}
spec:
  clusterIP: None
  sessionAffinity: None
  selector:
    app: foundationdb
  ports:
  - port: 4500
    targetPort: 4500
---
apiVersion: v1
kind: Service
metadata:
  name: foundationdb-cluster
  namespace: ${NAMESPACE}
spec:
  selector:
    app: foundationdb
  ports:
  - port: 4500
    targetPort: 4500
EOF

    log_info "Waiting for FoundationDB pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=foundationdb -n "${NAMESPACE}" --timeout=120s

    log_info "FoundationDB pod deployed ✓"
}

initialize_foundationdb() {
    log_info "Initializing FoundationDB cluster..."

    # Get the FDB pod name
    local fdb_pod
    fdb_pod=$(kubectl get pods -l app=foundationdb -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$fdb_pod" ]; then
        log_error "FoundationDB pod not found"
        return 1
    fi

    # Wait for FDB server to be responsive (it takes a moment after pod is ready)
    log_info "Waiting for FDB server to be responsive..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if kubectl exec -n "${NAMESPACE}" "$fdb_pod" -- fdbcli --exec "status minimal" 2>/dev/null | grep -q "The database is"; then
            log_info "FDB server is responsive"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warn "FDB still not fully responsive, attempting configuration anyway..."
    fi

    # Check if database is already configured
    local status
    status=$(kubectl exec -n "${NAMESPACE}" "$fdb_pod" -- fdbcli --exec "status minimal" 2>/dev/null || true)

    if echo "$status" | grep -q "The database is available"; then
        log_info "FDB cluster already configured and available ✓"
        return 0
    fi

    # Initialize cluster with single SSD configuration (or memory for faster tests)
    log_info "Configuring FDB cluster (new single ssd)..."
    if kubectl exec -n "${NAMESPACE}" "$fdb_pod" -- fdbcli --exec "configure new single ssd" 2>/dev/null; then
        log_info "FDB cluster configured successfully"
    else
        # If configure fails, it might already be configured - check status
        local recheck_status
        recheck_status=$(kubectl exec -n "${NAMESPACE}" "$fdb_pod" -- fdbcli --exec "status minimal" 2>/dev/null || true)
        if echo "$recheck_status" | grep -q "The database is available"; then
            log_info "FDB cluster already configured ✓"
        else
            log_warn "FDB configuration may have failed, but proceeding..."
        fi
    fi

    # Wait for cluster to become available
    log_info "Waiting for FDB cluster to become available..."
    local init_max_attempts=30
    local init_attempt=0

    while [ $init_attempt -lt $init_max_attempts ]; do
        local cluster_status
        cluster_status=$(kubectl exec -n "${NAMESPACE}" "$fdb_pod" -- fdbcli --exec "status minimal" 2>/dev/null || true)

        if echo "$cluster_status" | grep -q "The database is available"; then
            log_info "FDB cluster is available ✓"
            return 0
        fi
        init_attempt=$((init_attempt + 1))
        sleep 2
    done

    log_warn "FDB cluster availability check timed out, but proceeding..."
    return 0
}

deploy_management() {
    log_info "Deploying Management API..."

    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inferadb-management-api
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: inferadb-management-api
  template:
    metadata:
      labels:
        app: inferadb-management-api
    spec:
      serviceAccountName: inferadb-management
      containers:
      - name: management-api
        image: ${MANAGEMENT_IMAGE}
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
          name: public
        - containerPort: 9091
          name: internal
        env:
        - name: RUST_LOG
          value: "info,infera_management_core=debug,infera_discovery=debug"
        - name: INFERADB_MGMT__SERVER__HTTP_HOST
          value: "0.0.0.0"
        - name: INFERADB_MGMT__SERVER__HTTP_PORT
          value: "3000"
        - name: INFERADB_MGMT__SERVER__INTERNAL_HOST
          value: "0.0.0.0"
        - name: INFERADB_MGMT__SERVER__INTERNAL_PORT
          value: "9091"
        - name: INFERADB_MGMT__STORAGE__BACKEND
          value: "foundationdb"
        - name: INFERADB_MGMT__STORAGE__FDB_CLUSTER_FILE
          value: "/var/fdb/fdb.cluster"
        # Kubernetes discovery enabled via config.integration.yaml
        - name: INFERADB_MGMT__SERVER_VERIFICATION__ENABLED
          value: "true"
        - name: INFERADB_MGMT__SERVER_VERIFICATION__SERVER_JWKS_URL
          value: "http://inferadb-server:9090/.well-known/jwks.json"
        - name: INFERADB_MGMT__SERVER_VERIFICATION__CACHE_TTL_SECONDS
          value: "300"
        - name: MANAGEMENT_API_AUDIENCE
          value: "http://inferadb-management-api:3000"
        volumeMounts:
        - name: fdb-cluster-file
          mountPath: /var/fdb
          readOnly: true
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: fdb-cluster-file
        configMap:
          name: foundationdb-cluster-file
          items:
          - key: fdb.cluster
            path: fdb.cluster
---
apiVersion: v1
kind: Service
metadata:
  name: inferadb-management-api
  namespace: ${NAMESPACE}
spec:
  selector:
    app: inferadb-management-api
  ports:
  - name: public
    port: 3000
    targetPort: 3000
    nodePort: 30081
  - name: internal
    port: 9091
    targetPort: 9091
    nodePort: 30091
  type: NodePort
EOF

    log_info "Waiting for Management API to be ready..."
    kubectl wait --for=condition=available deployment/inferadb-management-api -n "${NAMESPACE}" --timeout=120s

    log_info "Management API deployed ✓"
}

deploy_server() {
    log_info "Deploying Server..."

    # Create server identity secret if it doesn't exist
    if ! kubectl get secret inferadb-server-identity -n "${NAMESPACE}" &>/dev/null; then
        log_info "Creating server identity secret..."
        kubectl create secret generic inferadb-server-identity -n "${NAMESPACE}" \
            --from-literal=server-identity.pem="-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEICBavKgCnA54kjkPsUVqz4K2or443E+EOQVU/yDZUWz3
-----END PRIVATE KEY-----"
    fi

    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inferadb-server
  namespace: ${NAMESPACE}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: inferadb-server
  template:
    metadata:
      labels:
        app: inferadb-server
    spec:
      serviceAccountName: inferadb-server
      containers:
      - name: inferadb
        image: ${SERVER_IMAGE}
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
          name: public
        - containerPort: 9090
          name: internal
        env:
        - name: RUST_LOG
          value: "info,infera_discovery=debug,infera_auth=debug"
        - name: INFERA__SERVER__HOST
          value: "0.0.0.0"
        - name: INFERA__SERVER__PORT
          value: "8080"
        - name: INFERA__SERVER__INTERNAL_HOST
          value: "0.0.0.0"
        - name: INFERA__SERVER__INTERNAL_PORT
          value: "9090"
        - name: INFERA__AUTH__ENABLED
          value: "true"
        - name: INFERA__AUTH__MANAGEMENT_API_URL
          value: "http://inferadb-management-api:3000"
        - name: INFERA__AUTH__MANAGEMENT_INTERNAL_API_URL
          value: "http://inferadb-management-api:9091"
        - name: INFERA__AUTH__JWKS_BASE_URL
          value: "http://inferadb-management-api:3000"
        - name: INFERA__AUTH__JWKS_CACHE_TTL
          value: "300"
        - name: INFERA__AUTH__MANAGEMENT_CACHE_TTL_SECONDS
          value: "300"
        - name: INFERA__AUTH__CERT_CACHE_TTL_SECONDS
          value: "900"
        - name: INFERA__AUTH__MANAGEMENT_VERIFY_VAULT_OWNERSHIP
          value: "true"
        - name: INFERA__AUTH__MANAGEMENT_VERIFY_ORG_STATUS
          value: "true"
        - name: INFERA__AUTH__DISCOVERY__MODE__TYPE
          value: "kubernetes"
        - name: KUBERNETES_NAMESPACE
          value: "${NAMESPACE}"
        - name: INFERA__AUTH__DISCOVERY__CACHE_TTL_SECONDS
          value: "30"
        - name: INFERA__STORE__BACKEND
          value: "foundationdb"
        - name: INFERA__STORE__FDB_CLUSTER_FILE
          value: "/var/fdb/fdb.cluster"
        - name: INFERA__STORE__CONNECTION_STRING
          value: "foundationdb-cluster:4500"
        - name: INFERA__AUTH__SERVER_IDENTITY_PRIVATE_KEY
          valueFrom:
            secretKeyRef:
              name: inferadb-server-identity
              key: server-identity.pem
        volumeMounts:
        - name: fdb-cluster-file
          mountPath: /var/fdb
          readOnly: true
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: fdb-cluster-file
        configMap:
          name: foundationdb-cluster-file
          items:
          - key: fdb.cluster
            path: fdb.cluster
---
apiVersion: v1
kind: Service
metadata:
  name: inferadb-server
  namespace: ${NAMESPACE}
spec:
  selector:
    app: inferadb-server
  ports:
  - name: public
    port: 8080
    targetPort: 8080
    nodePort: 30080
  - name: internal
    port: 9090
    targetPort: 9090
    nodePort: 30090
  type: NodePort
EOF

    log_info "Waiting for Server to be ready..."
    kubectl wait --for=condition=available deployment/inferadb-server -n "${NAMESPACE}" --timeout=120s

    log_info "Server deployed ✓"
}

show_status() {
    log_info "Deployment Status:"
    echo ""
    kubectl get pods -n "${NAMESPACE}"
    echo ""
    kubectl get svc -n "${NAMESPACE}"
    echo ""

    log_info "Access URLs:"
    echo "  Server:      http://localhost:8080"
    echo "  Management:  http://localhost:3000"
    echo ""

    log_info "Useful Commands:"
    echo "  # Watch server logs (look for discovery messages)"
    echo "  kubectl logs -f deployment/inferadb-server -n ${NAMESPACE} | grep -i discovery"
    echo ""
    echo "  # Watch management logs"
    echo "  kubectl logs -f deployment/inferadb-management-api -n ${NAMESPACE} | grep -i discovery"
    echo ""
    echo "  # Scale management and watch server discover new endpoints"
    echo "  kubectl scale deployment/inferadb-management-api --replicas=4 -n ${NAMESPACE}"
    echo ""
    echo "  # Update deployment with new changes"
    echo "  ./scripts/k8s-local-update.sh"
    echo ""
    echo "  # Run integration tests"
    echo "  ./scripts/k8s-local-run-integration-tests.sh"
    echo ""
    echo "  # Stop and tear down cluster"
    echo "  ./scripts/k8s-local-stop.sh"
}

main() {
    log_info "Starting InferaDB local Kubernetes cluster..."

    check_prerequisites
    create_cluster
    build_images
    load_images
    create_namespace
    deploy_rbac
    deploy_foundationdb
    initialize_foundationdb
    deploy_management
    deploy_server

    log_info "Setup complete! 🎉"
    echo ""
    show_status
}

# Run main function
main "$@"
