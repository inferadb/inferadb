#!/usr/bin/env bash
#
# Run integration tests against local Kubernetes cluster
#
# This script runs the integration test suite against a running kind cluster.
# It uses the Docker Compose integration test runner to execute tests against
# the Kubernetes-deployed services.
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
COMPOSE_FILE="docker-compose.k8s-tests.yml"
LOG_DIR="./logs/integration"

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

check_deployments_ready() {
    log_info "Checking if deployments are ready..."

    # Check management API
    if ! kubectl get deployment inferadb-management-api -n "${NAMESPACE}" &>/dev/null; then
        log_error "Management API deployment not found."
        log_info "Deploy it first with: ./scripts/k8s-local-start.sh"
        exit 1
    fi

    # Check server
    if ! kubectl get deployment inferadb-server -n "${NAMESPACE}" &>/dev/null; then
        log_error "Server deployment not found."
        log_info "Deploy it first with: ./scripts/k8s-local-start.sh"
        exit 1
    fi

    # Wait for deployments to be ready
    log_info "Waiting for Management API to be ready..."
    kubectl wait --for=condition=available deployment/inferadb-management-api -n "${NAMESPACE}" --timeout=60s

    log_info "Waiting for Server to be ready..."
    kubectl wait --for=condition=available deployment/inferadb-server -n "${NAMESPACE}" --timeout=60s

    log_info "All deployments ready ✓"
}

run_integration_tests() {
    log_info "Running integration tests..."

    # Ensure we're in the project root
    cd "$(dirname "$0")/.."

    # Create log directory
    mkdir -p "${LOG_DIR}"

    # Run integration tests using Docker Compose test runner
    # The test runner will connect to the services via the exposed NodePorts
    log_info "Executing test suite..."

    if docker compose -f "${COMPOSE_FILE}" run --rm test-runner; then
        log_info "✓ Integration tests passed!"
        return 0
    else
        log_error "✗ Integration tests failed!"
        collect_logs
        return 1
    fi
}

collect_logs() {
    log_warn "Collecting Kubernetes logs..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOG_DIR}/k8s_integration_failure_${timestamp}.log"

    log_info "Saving logs to ${log_file}"

    {
        echo "=== FoundationDB Logs ==="
        kubectl logs -l app=foundationdb -n "${NAMESPACE}" --tail=100
        echo ""

        echo "=== Management API Logs ==="
        kubectl logs deployment/inferadb-management-api -n "${NAMESPACE}" --tail=100
        echo ""

        echo "=== Server Logs ==="
        kubectl logs deployment/inferadb-server -n "${NAMESPACE}" --tail=100
        echo ""

        echo "=== Pod Status ==="
        kubectl get pods -n "${NAMESPACE}" -o wide
        echo ""

        echo "=== Service Status ==="
        kubectl get svc -n "${NAMESPACE}"
    } > "${log_file}" 2>&1

    log_error "Logs saved to: ${log_file}"
}

show_helpful_commands() {
    log_info "Helpful debugging commands:"
    echo "  # View server logs"
    echo "  kubectl logs -f deployment/inferadb-server -n ${NAMESPACE}"
    echo ""
    echo "  # View management API logs"
    echo "  kubectl logs -f deployment/inferadb-management-api -n ${NAMESPACE}"
    echo ""
    echo "  # Check pod status"
    echo "  kubectl get pods -n ${NAMESPACE}"
    echo ""
    echo "  # Port forward to server"
    echo "  kubectl port-forward -n ${NAMESPACE} deployment/inferadb-server 8080:8080"
    echo ""
    echo "  # Port forward to management API"
    echo "  kubectl port-forward -n ${NAMESPACE} deployment/inferadb-management-api 3000:3000"
}

main() {
    log_info "Running integration tests against local Kubernetes cluster..."

    check_cluster_exists
    check_deployments_ready

    if run_integration_tests; then
        log_info "All tests passed! 🎉"
        exit 0
    else
        log_error "Tests failed. See logs above for details."
        show_helpful_commands
        exit 1
    fi
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker compose is available
if ! docker compose version >/dev/null 2>&1; then
    log_error "docker compose is not available. Please install Docker Compose v2."
    exit 1
fi

# Run main function
main "$@"
