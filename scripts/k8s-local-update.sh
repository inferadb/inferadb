#!/usr/bin/env bash
#
# Update InferaDB deployment in existing kind cluster
#
# This script rebuilds Docker images and updates the running deployment
# with new binaries and configuration changes. Use this for rapid iteration
# during development without tearing down the entire cluster.
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

check_cluster_exists() {
    if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist."
        log_info "Create it first with: ./scripts/k8s-local-start.sh"
        exit 1
    fi
    log_info "Cluster '${CLUSTER_NAME}' exists ✓"
}

build_and_load_images() {
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

    log_info "Loading images into kind cluster..."
    kind load docker-image "${SERVER_IMAGE}" --name "${CLUSTER_NAME}"
    kind load docker-image "${MANAGEMENT_IMAGE}" --name "${CLUSTER_NAME}"
    log_info "Images loaded ✓"
}

update_rbac() {
    log_info "Updating RBAC resources..."

    kubectl apply -f server/k8s/rbac.yaml -n "${NAMESPACE}"
    kubectl apply -f management/k8s/rbac.yaml -n "${NAMESPACE}"

    log_info "RBAC updated ✓"
}

restart_deployments() {
    log_info "Restarting deployments to use new images..."

    # Restart management API
    kubectl rollout restart deployment/inferadb-management -n "${NAMESPACE}"
    log_info "Waiting for Management API rollout..."
    kubectl rollout status deployment/inferadb-management -n "${NAMESPACE}" --timeout=120s

    # Restart server
    kubectl rollout restart deployment/inferadb-server -n "${NAMESPACE}"
    log_info "Waiting for Server rollout..."
    kubectl rollout status deployment/inferadb-server -n "${NAMESPACE}" --timeout=120s

    log_info "Deployments restarted ✓"
}

show_status() {
    log_info "Current Deployment Status:"
    echo ""
    kubectl get pods -n "${NAMESPACE}"
    echo ""

    log_info "Recent Server Logs:"
    kubectl logs deployment/inferadb-server -n "${NAMESPACE}" --tail=10
    echo ""

    log_info "Recent Management API Logs:"
    kubectl logs deployment/inferadb-management -n "${NAMESPACE}" --tail=10
}

main() {
    log_info "Updating InferaDB deployment in local Kubernetes cluster..."

    check_cluster_exists
    build_and_load_images
    update_rbac
    restart_deployments

    log_info "Update complete! 🎉"
    echo ""
    show_status
}

# Run main function
main "$@"
