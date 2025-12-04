#!/usr/bin/env bash
#
# Purge local Kubernetes cluster completely
#
# This script deletes the kind cluster and cleans up all associated resources
# WITHOUT prompting for confirmation. After running this script, you'll need
# to run k8s-local-start.sh to recreate the cluster from scratch.
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
    if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '${CLUSTER_NAME}' does not exist."
        return 1
    fi
    return 0
}

delete_cluster() {
    log_info "Deleting kind cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
    log_info "Cluster deleted ✓"
}

cleanup_docker_resources() {
    log_info "Cleaning up Docker resources..."

    # Remove InferaDB Docker images
    if docker images | grep -q "inferadb-server:local"; then
        log_info "Removing inferadb-server:local image..."
        docker rmi inferadb-server:local 2>/dev/null || log_warn "Could not remove inferadb-server:local"
    fi

    if docker images | grep -q "inferadb-management:local"; then
        log_info "Removing inferadb-management:local image..."
        docker rmi inferadb-management:local 2>/dev/null || log_warn "Could not remove inferadb-management:local"
    fi

    # Prune unused Docker resources related to kind
    log_info "Pruning unused Docker networks..."
    docker network prune -f 2>/dev/null || true

    # Remove any dangling volumes created by kind
    log_info "Pruning unused Docker volumes..."
    docker volume prune -f 2>/dev/null || true

    log_info "Docker cleanup complete ✓"
}

reset_kubernetes_context() {
    log_info "Cleaning up kubectl context..."

    # Remove the kind context from kubeconfig
    kubectl config delete-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
    kubectl config delete-cluster "kind-${CLUSTER_NAME}" 2>/dev/null || true
    kubectl config delete-user "kind-${CLUSTER_NAME}" 2>/dev/null || true

    log_info "Kubectl context cleaned ✓"
}

main() {
    log_info "Purging InferaDB local Kubernetes cluster..."
    log_warn "This will completely destroy the cluster '${CLUSTER_NAME}' and all its data."

    if check_cluster_exists; then
        delete_cluster
    else
        log_info "No cluster to delete."
    fi

    cleanup_docker_resources
    reset_kubernetes_context

    log_info "Purge complete! 🎉"
    echo ""
    log_info "To recreate the cluster, run:"
    echo "  ./tests/scripts/k8s-local-start.sh"
}

# Run main function
main "$@"
