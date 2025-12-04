#!/usr/bin/env bash
#
# Stop (pause) local Kubernetes cluster
#
# This script stops the kind cluster's Docker container without deleting it.
# The cluster can be restarted with k8s-local-start.sh without rebuilding.
# To completely destroy the cluster, use k8s-local-purge.sh instead.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-inferadb-local}"

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
        log_warn "Cluster '${CLUSTER_NAME}' does not exist. Nothing to stop."
        return 1
    fi
    return 0
}

get_cluster_container() {
    # Kind creates a container named <cluster-name>-control-plane
    echo "${CLUSTER_NAME}-control-plane"
}

check_container_running() {
    local container_name
    container_name=$(get_cluster_container)
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0
    fi
    return 1
}

stop_cluster() {
    local container_name
    container_name=$(get_cluster_container)

    log_info "Stopping kind cluster container '${container_name}'..."
    docker stop "${container_name}"
    log_info "Cluster stopped ✓"
}

main() {
    log_info "Stopping InferaDB local Kubernetes cluster..."

    if ! check_cluster_exists; then
        log_info "Nothing to do."
        exit 0
    fi

    if ! check_container_running; then
        log_info "Cluster '${CLUSTER_NAME}' is already stopped."
        exit 0
    fi

    stop_cluster

    log_info "Stop complete! 🎉"
    echo ""
    log_info "To restart the cluster, run:"
    echo "  ./tests/scripts/k8s-local-start.sh"
    echo ""
    log_info "To completely destroy the cluster, run:"
    echo "  ./tests/scripts/k8s-local-purge.sh"
}

# Run main function
main "$@"
