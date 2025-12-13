#!/bin/bash

set -euo pipefail

# Helper functions for idempotent label management

# Check if label exists in cached list
label_exists() {
    local name="$1"
    echo "$EXISTING_LABELS" | grep -qx "$name"
}

# Get current label info (color and description) from cache
get_label_info() {
    local name="$1"
    echo "$EXISTING_LABELS_JSON" | jq -r --arg name "$name" '.[] | select(.name == $name) | "\(.color)|\(.description)"'
}

# Ensure label exists with correct color and description (creates or updates as needed)
ensure_label() {
    local repo="$1"
    local name="$2"
    local color="$3"
    local description="$4"

    if label_exists "$name"; then
        # Check if color or description needs updating
        local current_info
        current_info=$(get_label_info "$name")
        local current_color="${current_info%%|*}"
        local current_description="${current_info#*|}"

        # Normalize colors for comparison (lowercase, no leading #)
        # Using tr for macOS compatibility (Bash 3.2 doesn't support ${var,,})
        local normalized_color
        normalized_color=$(echo "${color#\#}" | tr '[:upper:]' '[:lower:]')
        current_color=$(echo "${current_color#\#}" | tr '[:upper:]' '[:lower:]')

        if [[ "$current_color" != "$normalized_color" ]] || [[ "$current_description" != "$description" ]]; then
            echo "  ~ $name (updating)"
            gh label edit "$name" --repo "$repo" --color "$color" --description "$description"
        else
            echo "  ✓ $name (exists)"
        fi
    else
        echo "  + $name (creating)"
        gh label create "$name" --repo "$repo" --color "$color" --description "$description"
    fi
}

# Delete label if it exists
delete_label() {
    local repo="$1"
    local name="$2"

    if label_exists "$name"; then
        echo "  - $name (deleting)"
        gh label delete "$name" --repo "$repo" --yes
    fi
}

# Loop through our repositories
for REPO in "inferadb/inferadb" "inferadb/engine" "inferadb/control" "inferadb/dashboard" "inferadb/tests" "inferadb/docs" "inferadb/cli"; do
    echo ""
    echo "Processing $REPO"
    echo "================"

    # Fetch existing labels once per repo (both names list and full JSON for updates)
    EXISTING_LABELS_JSON=$(gh label list --repo "$REPO" --limit 200 --json name,color,description)
    EXISTING_LABELS=$(echo "$EXISTING_LABELS_JSON" | jq -r '.[].name')

    # Delete default GitHub labels
    delete_label "$REPO" "bug"
    delete_label "$REPO" "documentation"
    delete_label "$REPO" "duplicate"
    delete_label "$REPO" "enhancement"
    delete_label "$REPO" "good first issue"
    delete_label "$REPO" "help wanted"
    delete_label "$REPO" "invalid"
    delete_label "$REPO" "question"
    delete_label "$REPO" "wontfix"
    delete_label "$REPO" "repo/server"
    delete_label "$REPO" "repo/management"

    # Repository-specific labels for meta-repository
    if [ "$REPO" == "inferadb/inferadb" ]; then
        ensure_label "$REPO" "repo/engine" "1d76db" "Related to authorizationengine component"
        ensure_label "$REPO" "repo/control" "1d76db" "Related to control plane component"
        ensure_label "$REPO" "repo/dashboard" "1d76db" "Related to dashboard component"
        ensure_label "$REPO" "repo/tests" "1d76db" "Related to tests component"
        ensure_label "$REPO" "repo/docs" "1d76db" "Related to docs component"
        ensure_label "$REPO" "repo/cli" "1d76db" "Related to CLI component"
    else
        delete_label "$REPO" "repo/server"
        delete_label "$REPO" "repo/management"
        delete_label "$REPO" "repo/dashboard"
        delete_label "$REPO" "repo/tests"
        delete_label "$REPO" "repo/docs"
        delete_label "$REPO" "repo/cli"
    fi

    # Deployment area labels (meta-repository and tests only)
    if [ "$REPO" == "inferadb/inferadb" ] || [ "$REPO" == "inferadb/tests" ]; then
        ensure_label "$REPO" "area/k8s" "f9d0c4" "Kubernetes manifests and Helm"
        ensure_label "$REPO" "area/docker" "f9d0c4" "Docker images and compose"
        ensure_label "$REPO" "area/terraform" "f9d0c4" "Terraform provider"
        ensure_label "$REPO" "area/observability" "f9d0c4" "Metrics, logging, tracing"
    else
        delete_label "$REPO" "area/k8s"
        delete_label "$REPO" "area/docker"
        delete_label "$REPO" "area/terraform"
        delete_label "$REPO" "area/observability"
    fi

    # Dashboard-specific labels
    if [ "$REPO" == "inferadb/dashboard" ]; then
        ensure_label "$REPO" "area/ui" "e6ccf5" "User interface components"
        ensure_label "$REPO" "area/ux" "e6ccf5" "User experience and flows"
        ensure_label "$REPO" "area/a11y" "e6ccf5" "Accessibility"
    else
        delete_label "$REPO" "area/ui"
        delete_label "$REPO" "area/ux"
        delete_label "$REPO" "area/a11y"
    fi

    # Server-specific labels
    if [ "$REPO" == "inferadb/server" ]; then
        ensure_label "$REPO" "area/policy" "bfdadc" "IPL parser and policy evaluation"
        ensure_label "$REPO" "area/reachability" "bfdadc" "Graph traversal and reachability"
        ensure_label "$REPO" "area/storage" "bfdadc" "Storage backends (Memory, FDB)"
        ensure_label "$REPO" "area/cache" "bfdadc" "Caching layer"
        ensure_label "$REPO" "area/types" "bfdadc" "Shared types crate"
        ensure_label "$REPO" "area/wasm" "bfdadc" "WebAssembly runtime"
        ensure_label "$REPO" "area/repl" "bfdadc" "Interactive REPL"
    else
        delete_label "$REPO" "area/policy"
        delete_label "$REPO" "area/reachability"
        delete_label "$REPO" "area/storage"
        delete_label "$REPO" "area/cache"
        delete_label "$REPO" "area/types"
        delete_label "$REPO" "area/wasm"
        delete_label "$REPO" "area/repl"
    fi

    # Management-specific labels
    if [ "$REPO" == "inferadb/management" ]; then
        ensure_label "$REPO" "area/tenancy" "d4e5f7" "Multi-tenant organization management"
        ensure_label "$REPO" "area/vault" "d4e5f7" "Vault access control and sync"
        ensure_label "$REPO" "area/session" "d4e5f7" "User sessions and authentication"
        ensure_label "$REPO" "area/passkey" "d4e5f7" "WebAuthn/FIDO2 passkey support"
        ensure_label "$REPO" "area/client" "d4e5f7" "Client certificates and tokens"
        ensure_label "$REPO" "area/team" "d4e5f7" "Team management"
    else
        delete_label "$REPO" "area/tenancy"
        delete_label "$REPO" "area/vault"
        delete_label "$REPO" "area/session"
        delete_label "$REPO" "area/passkey"
        delete_label "$REPO" "area/client"
        delete_label "$REPO" "area/team"
    fi

    # Docs-specific labels
    if [ "$REPO" == "inferadb/docs" ]; then
        ensure_label "$REPO" "area/architecture" "c9e4f6" "Architecture and design documents"
        ensure_label "$REPO" "area/deployment" "c9e4f6" "Deployment guides and runbooks"
        ensure_label "$REPO" "area/guides" "c9e4f6" "Tutorials and how-to guides"
        ensure_label "$REPO" "area/rfcs" "c9e4f6" "RFC and design proposals"
        ensure_label "$REPO" "area/whitepapers" "c9e4f6" "Technical whitepapers"
        ensure_label "$REPO" "area/security" "c9e4f6" "Security documentation"
    else
        delete_label "$REPO" "area/architecture"
        delete_label "$REPO" "area/deployment"
        delete_label "$REPO" "area/guides"
        delete_label "$REPO" "area/rfcs"
        delete_label "$REPO" "area/whitepapers"
        delete_label "$REPO" "area/security"
    fi

    # Core labels (all repositories)
    echo ""
    echo "  Core labels:"

    # Kind labels
    ensure_label "$REPO" "kind/bug" "d73a4a" "Something isn't working as expected"
    ensure_label "$REPO" "kind/feature" "a2eeef" "New capability or functionality"
    ensure_label "$REPO" "kind/enhancement" "84b6eb" "Improvement to existing functionality"
    ensure_label "$REPO" "kind/refactor" "fbca04" "Code restructuring without behavior change"
    ensure_label "$REPO" "kind/documentation" "0075ca" "Documentation improvements"
    ensure_label "$REPO" "kind/security" "b60205" "Security-related issue or fix"
    ensure_label "$REPO" "kind/performance" "d4c5f9" "Performance improvements or issues"
    ensure_label "$REPO" "kind/breaking-change" "e99695" "Introduces breaking changes"

    # Priority labels
    ensure_label "$REPO" "priority/critical" "b60205" "Requires immediate attention"
    ensure_label "$REPO" "priority/high" "d93f0b" "Should be addressed soon"
    ensure_label "$REPO" "priority/medium" "fbca04" "Normal priority"
    ensure_label "$REPO" "priority/low" "0e8a16" "Nice to have, no urgency"

    # Effort labels
    ensure_label "$REPO" "effort/small" "c2e0c6" "Quick fix, hours of work"
    ensure_label "$REPO" "effort/medium" "fef2c0" "Few days of work"
    ensure_label "$REPO" "effort/large" "f9d0c4" "Week+ of work, may need breakdown"

    # Status labels
    ensure_label "$REPO" "status/blocked" "d73a4a" "Cannot proceed due to external dependency"
    ensure_label "$REPO" "status/needs-triage" "fbca04" "Requires maintainer review and categorization"
    ensure_label "$REPO" "status/needs-info" "fbca04" "Waiting for more information from reporter"
    ensure_label "$REPO" "status/needs-design" "c5def5" "Requires design/architecture discussion"
    ensure_label "$REPO" "status/in-progress" "0e8a16" "Actively being worked on"
    ensure_label "$REPO" "status/ready-for-review" "6f42c1" "PR ready for code review"

    # Resolution labels
    ensure_label "$REPO" "resolution/duplicate" "cfd3d7" "Duplicate of another issue"
    ensure_label "$REPO" "resolution/wontfix" "cfd3d7" "Will not be addressed"
    ensure_label "$REPO" "resolution/invalid" "cfd3d7" "Not a valid issue"
    ensure_label "$REPO" "resolution/by-design" "cfd3d7" "Working as intended"

    # Community labels
    ensure_label "$REPO" "good-first-issue" "7057ff" "Good for newcomers"
    ensure_label "$REPO" "help-wanted" "008672" "Extra attention needed"
    ensure_label "$REPO" "hacktoberfest" "ff7518" "Hacktoberfest eligible"

    # Automation labels (created for consistency, though bots may also create them)
    ensure_label "$REPO" "dependencies" "0366d6" "Dependency updates (Dependabot)"
    ensure_label "$REPO" "github-actions" "000000" "GitHub Actions workflow changes"
    ensure_label "$REPO" "stale" "cfd3d7" "Marked stale by automation"

    # Core area labels
    ensure_label "$REPO" "area/api" "c5def5" "REST/gRPC API layer"
    ensure_label "$REPO" "area/auth" "c5def5" "Authentication and authorization"
    ensure_label "$REPO" "area/config" "c5def5" "Configuration handling"
    ensure_label "$REPO" "area/docs" "c5def5" "Documentation"
    ensure_label "$REPO" "area/ci" "c5def5" "CI/CD pipelines and GitHub Actions"
    ensure_label "$REPO" "area/deps" "c5def5" "Dependencies and supply chain"
    ensure_label "$REPO" "area/testing" "c5def5" "Test infrastructure and coverage"

    # Changelog labels
    ensure_label "$REPO" "changelog/added" "0e8a16" "New features for release notes"
    ensure_label "$REPO" "changelog/changed" "fbca04" "Changes in existing functionality"
    ensure_label "$REPO" "changelog/deprecated" "fef2c0" "Soon-to-be removed features"
    ensure_label "$REPO" "changelog/removed" "d73a4a" "Removed features"
    ensure_label "$REPO" "changelog/fixed" "c5def5" "Bug fixes"
    ensure_label "$REPO" "changelog/security" "b60205" "Security fixes"
    ensure_label "$REPO" "changelog/skip" "cfd3d7" "Do not include in changelog"

done

echo ""
echo "Done!"
