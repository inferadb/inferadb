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
    echo "  kubectl logs -f deployment/inferadb-management -n ${NAMESPACE} | grep -i discovery"
    echo ""
    echo "  # Scale management and watch server discover new endpoints"
    echo "  kubectl scale deployment/inferadb-management --replicas=4 -n ${NAMESPACE}"
    echo ""
    echo "  # Update deployment with new changes"
    echo "  ./tests/scripts/k8s-local-update.sh"
    echo ""
    echo "  # Run integration tests"
    echo "  ./tests/scripts/k8s-local-run-integration-tests.sh"
    echo ""
    echo "  # Stop and tear down cluster"
    echo "  ./tests/scripts/k8s-local-stop.sh"
}

main() {
    log_info "Checking status of InferaDB local Kubernetes cluster..."

    echo ""
    show_status
}

# Run main function
main "$@"
