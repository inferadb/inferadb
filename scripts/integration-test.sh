#!/usr/bin/env bash
# Integration Test Runner for InferaDB
# Orchestrates Docker Compose services and runs end-to-end integration tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.integration.yml"
LOG_DIR="./logs/integration"
TIMEOUT=300 # 5 minutes timeout for tests

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function to ensure containers are stopped
cleanup() {
    local exit_code=$?

    log_info "Cleaning up containers..."
    docker compose -f "${COMPOSE_FILE}" down --volumes --remove-orphans 2>/dev/null || true

    if [ $exit_code -ne 0 ]; then
        log_error "Integration tests failed with exit code $exit_code"
        exit $exit_code
    fi
}

# Collect logs on failure
collect_logs() {
    log_warn "Collecting service logs..."

    mkdir -p "${LOG_DIR}"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOG_DIR}/integration_failure_${timestamp}.log"

    log_info "Saving logs to ${log_file}"

    {
        echo "=== FoundationDB Logs ==="
        docker compose -f "${COMPOSE_FILE}" logs foundationdb
        echo ""

        echo "=== Management API Logs ==="
        docker compose -f "${COMPOSE_FILE}" logs management-api
        echo ""

        echo "=== Server Logs ==="
        docker compose -f "${COMPOSE_FILE}" logs server
        echo ""

        echo "=== Test Runner Logs ==="
        docker compose -f "${COMPOSE_FILE}" logs test-runner
    } > "${log_file}" 2>&1

    log_error "Logs saved to: ${log_file}"
}

# Wait for a service to be healthy
wait_for_health() {
    local service=$1
    local max_attempts=60
    local attempt=0

    log_info "Waiting for ${service} to be healthy..."

    while [ $attempt -lt $max_attempts ]; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "inferadb-${service}-integration" 2>/dev/null || echo "starting")

        if [ "$health_status" = "healthy" ]; then
            log_info "${service} is healthy!"
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 2

        if [ $((attempt % 10)) -eq 0 ]; then
            log_warn "${service} not healthy yet (attempt ${attempt}/${max_attempts})..."
        fi
    done

    log_error "${service} failed to become healthy within timeout"
    return 1
}

# Trap cleanup on exit
trap cleanup EXIT
trap 'collect_logs; cleanup' ERR

# Main execution
main() {
    log_info "Starting InferaDB integration tests..."

    # Ensure we're in the project root
    cd "$(dirname "$0")/.."

    # Clean up any existing containers
    log_info "Cleaning up any existing containers..."
    docker compose -f "${COMPOSE_FILE}" down --volumes --remove-orphans 2>/dev/null || true

    # Pull latest images
    log_info "Pulling latest Docker images..."
    docker compose -f "${COMPOSE_FILE}" pull --quiet

    # Build services
    log_info "Building services..."
    docker compose -f "${COMPOSE_FILE}" build --quiet

    # Start infrastructure services (foundationdb, management-api, server)
    log_info "Starting infrastructure services..."
    docker compose -f "${COMPOSE_FILE}" up -d foundationdb management-api server

    # Wait for all services to be healthy
    if ! wait_for_health "fdb"; then
        collect_logs
        exit 1
    fi

    if ! wait_for_health "management"; then
        collect_logs
        exit 1
    fi

    if ! wait_for_health "server"; then
        collect_logs
        exit 1
    fi

    log_info "All services are healthy. Running integration tests..."

    # Run integration tests using the test-runner service
    if docker compose -f "${COMPOSE_FILE}" run --rm test-runner; then
        log_info "✓ Integration tests passed!"
        exit 0
    else
        log_error "✗ Integration tests failed!"
        collect_logs
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
