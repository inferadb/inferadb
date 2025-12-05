#!/bin/bash

set -euo pipefail

# Helper functions for idempotent repository metadata management

# Get current repository description
get_description() {
    local repo="$1"
    gh repo view "$repo" --json description --jq '.description // ""'
}

# Get current repository topics as newline-separated list
get_topics() {
    local repo="$1"
    gh repo view "$repo" --json repositoryTopics --jq '.repositoryTopics // [] | .[].name'
}

# Ensure repository has correct description
ensure_description() {
    local repo="$1"
    local description="$2"

    local current
    current=$(get_description "$repo")

    if [[ "$current" != "$description" ]]; then
        echo "  ~ description (updating)"
        gh repo edit "$repo" --description "$description"
    else
        echo "  ✓ description (matches)"
    fi
}

# Ensure topic exists on repository
ensure_topic() {
    local repo="$1"
    local topic="$2"

    if echo "$CURRENT_TOPICS" | grep -qx "$topic"; then
        echo "  ✓ $topic (exists)"
    else
        echo "  + $topic (adding)"
        gh repo edit "$repo" --add-topic "$topic"
    fi
}

# Remove topic if it exists on repository
remove_topic() {
    local repo="$1"
    local topic="$2"

    if echo "$CURRENT_TOPICS" | grep -qx "$topic"; then
        echo "  - $topic (removing)"
        gh repo edit "$repo" --remove-topic "$topic"
    fi
}

# Remove deprecated topics from a repository
remove_deprecated_topics() {
    local repo="$1"

    # Topics to remove (deprecated or low-value for discoverability)
    local deprecated=(
        "authzen"
        "fine-grained-authorization"
        "relationship-based-access-control"
        "open-source"
        "foundationdb"
    )

    for topic in "${deprecated[@]}"; do
        remove_topic "$repo" "$topic"
    done
}

# =============================================================================
# Repository Definitions
# =============================================================================

# Common topics for all repositories
COMMON_TOPICS=(
    "inferadb"
    "authorization"
    "access-control"
    "permissions"
    "rebac"
    "zanzibar"
    "fine-grained-access-control"
)

# -----------------------------------------------------------------------------
# Meta-repository: inferadb/inferadb
# -----------------------------------------------------------------------------
process_inferadb() {
    local repo="inferadb/inferadb"
    echo ""
    echo "Processing $repo"
    echo "================"

    CURRENT_TOPICS=$(get_topics "$repo")

    # Flagship description for the meta-repository
    # Pattern: [What it is] — [key differentiator], [second differentiator]
    ensure_description "$repo" "The distributed inference engine for authorization — high performance fine-grained permission checks at scale. Inspired by Google Zanzibar and AuthZEN compliant."

    echo ""
    echo "  Topics:"

    # Common topics
    for topic in "${COMMON_TOPICS[@]}"; do
        ensure_topic "$repo" "$topic"
    done

    # Meta-repo specific topics (umbrella project)
    ensure_topic "$repo" "policy-engine"
    ensure_topic "$repo" "rust"

    # Cleanup deprecated topics
    remove_deprecated_topics "$repo"
}

# -----------------------------------------------------------------------------
# Server: inferadb/server
# -----------------------------------------------------------------------------
process_server() {
    local repo="inferadb/server"
    echo ""
    echo "Processing $repo"
    echo "================"

    CURRENT_TOPICS=$(get_topics "$repo")

    # Pattern: [What it is] — [key differentiator], [second differentiator]
    ensure_description "$repo" "InferaDB authorization engine — high-performance ReBAC with declarative policies, graph evaluation, and sub-millisecond latency. Inspired by Google Zanzibar and AuthZEN compliant."

    echo ""
    echo "  Topics:"

    # Common topics
    for topic in "${COMMON_TOPICS[@]}"; do
        ensure_topic "$repo" "$topic"
    done

    # Server-specific topics
    ensure_topic "$repo" "rust"
    ensure_topic "$repo" "policy-engine"
    ensure_topic "$repo" "graph-database"
    ensure_topic "$repo" "grpc"
    ensure_topic "$repo" "rest-api"
    ensure_topic "$repo" "wasm"
    ensure_topic "$repo" "caching"

    # Cleanup deprecated topics
    remove_deprecated_topics "$repo"
}

# -----------------------------------------------------------------------------
# Management: inferadb/management
# -----------------------------------------------------------------------------
process_management() {
    local repo="inferadb/management"
    echo ""
    echo "Processing $repo"
    echo "================"

    CURRENT_TOPICS=$(get_topics "$repo")

    # Pattern: [What it is] — [key differentiator], [second differentiator]
    ensure_description "$repo" "InferaDB control plane — multi-tenant orchestration with headless APIs, Kubernetes-native deployment, and WebAuthn authentication."

    echo ""
    echo "  Topics:"

    # Common topics
    for topic in "${COMMON_TOPICS[@]}"; do
        ensure_topic "$repo" "$topic"
    done

    # Management-specific topics
    ensure_topic "$repo" "rust"
    ensure_topic "$repo" "multi-tenant"
    ensure_topic "$repo" "rbac"
    ensure_topic "$repo" "webauthn"
    ensure_topic "$repo" "passkeys"
    ensure_topic "$repo" "audit-logging"
    ensure_topic "$repo" "grpc"
    ensure_topic "$repo" "rest-api"
    ensure_topic "$repo" "jwt"

    # Cleanup deprecated topics
    remove_deprecated_topics "$repo"
}

# -----------------------------------------------------------------------------
# Dashboard: inferadb/dashboard
# -----------------------------------------------------------------------------
process_dashboard() {
    local repo="inferadb/dashboard"
    echo ""
    echo "Processing $repo"
    echo "================"

    CURRENT_TOPICS=$(get_topics "$repo")

    # Pattern: [What it is] — [key differentiator], [second differentiator]
    ensure_description "$repo" "InferaDB management dashboard — web console for self-service user, organization, team and vault management, with policy design, decision simulation, and relationship visualization."

    echo ""
    echo "  Topics:"

    # Common topics
    for topic in "${COMMON_TOPICS[@]}"; do
        ensure_topic "$repo" "$topic"
    done

    # Dashboard-specific topics
    ensure_topic "$repo" "typescript"
    ensure_topic "$repo" "react"
    ensure_topic "$repo" "vite"
    ensure_topic "$repo" "tanstack"
    ensure_topic "$repo" "dashboard"
    ensure_topic "$repo" "web-ui"

    # Cleanup deprecated topics
    remove_deprecated_topics "$repo"
}

# -----------------------------------------------------------------------------
# Tests: inferadb/tests
# -----------------------------------------------------------------------------
process_tests() {
    local repo="inferadb/tests"
    echo ""
    echo "Processing $repo"
    echo "================"

    CURRENT_TOPICS=$(get_topics "$repo")

    # Pattern: [What it is] — [key differentiator], [second differentiator]
    ensure_description "$repo" "InferaDB E2E test suite — Kubernetes deployment scripts and integration tests for InferaDB authorization"

    echo ""
    echo "  Topics:"

    # Common topics
    for topic in "${COMMON_TOPICS[@]}"; do
        ensure_topic "$repo" "$topic"
    done

    # Tests-specific topics
    ensure_topic "$repo" "rust"
    ensure_topic "$repo" "integration-testing"
    ensure_topic "$repo" "e2e-testing"
    ensure_topic "$repo" "kubernetes"
    ensure_topic "$repo" "helm"
    ensure_topic "$repo" "docker"

    # Cleanup deprecated topics
    remove_deprecated_topics "$repo"
}

# -----------------------------------------------------------------------------
# Docs: inferadb/docs
# -----------------------------------------------------------------------------
process_docs() {
    local repo="inferadb/docs"
    echo ""
    echo "Processing $repo"
    echo "================"

    CURRENT_TOPICS=$(get_topics "$repo")

    # Pattern: [What it is] — [key differentiator], [second differentiator]
    ensure_description "$repo" "InferaDB documentation — technical specifications, deployment guides, and design documents"

    echo ""
    echo "  Topics:"

    # Common topics
    for topic in "${COMMON_TOPICS[@]}"; do
        ensure_topic "$repo" "$topic"
    done

    # Docs-specific topics
    ensure_topic "$repo" "documentation"
    ensure_topic "$repo" "deployment"
    ensure_topic "$repo" "architecture"

    # Cleanup deprecated topics
    remove_deprecated_topics "$repo"
}

# =============================================================================
# Main Execution
# =============================================================================

echo "InferaDB Repository Metadata Manager"
echo "====================================="
echo ""
echo "This script updates repository descriptions and topics."
echo "Requires: gh CLI authenticated with repo permissions"

# Process all repositories
process_inferadb
process_server
process_management
process_dashboard
process_tests
process_docs

echo ""
echo "Done!"
