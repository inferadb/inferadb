#!/usr/bin/env bash
#
# Stop and completely tear down local Kubernetes cluster
#
# This script deletes the kind cluster and cleans up all associated resources.
# After running this script, you'll need to run k8s-local-start.sh to recreate
# the cluster from scratch.
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
    if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warn "Cluster '${CLUSTER_NAME}' does not exist. Nothing to stop."
        return 1
    fi
    return 0
}

show_cluster_info() {
    log_info "Current cluster resources:"
    echo ""
    kubectl get all -n "${NAMESPACE}" 2>/dev/null || log_warn "Namespace '${NAMESPACE}' not found or empty"
    echo ""
}

delete_cluster() {
    log_info "Deleting kind cluster '${CLUSTER_NAME}'..."

    kind delete cluster --name "${CLUSTER_NAME}"

    log_info "Cluster deleted ✓"
}

cleanup_docker_images() {
    log_info "Checking for orphaned Docker images..."

    # Note: We don't automatically delete the images as they may be used by other clusters
    # or the user may want to keep them for quick restarts

    if docker images | grep -q "inferadb-server:local"; then
        log_info "Found inferadb-server:local image (not deleted)"
    fi

    if docker images | grep -q "inferadb-management:local"; then
        log_info "Found inferadb-management:local image (not deleted)"
    fi

    log_info "To remove Docker images manually, run:"
    echo "  docker rmi inferadb-server:local inferadb-management:local"
}

main() {
    log_info "Stopping InferaDB local Kubernetes cluster..."

    if ! check_cluster_exists; then
        log_info "Nothing to do."
        exit 0
    fi

    # Show what's about to be deleted
    show_cluster_info

    # Ask for confirmation if running interactively
    if [ -t 0 ]; then
        log_warn "This will completely destroy the cluster '${CLUSTER_NAME}' and all its data."
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled by user."
            exit 0
        fi
    fi

    delete_cluster
    cleanup_docker_images

    log_info "Teardown complete! 🎉"
    echo ""
    log_info "To recreate the cluster, run:"
    echo "  ./scripts/k8s-local-start.sh"
}

# Run main function
main "$@"
