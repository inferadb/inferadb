#!/bin/bash

set -euo pipefail

# =============================================================================
# Repository Metadata Management Script
# =============================================================================
# Manages GitHub repository settings, labels, descriptions, and topics across
# all InferaDB repositories using repos.json configuration.
#
# Features:
#   - Single source of truth (repos.json)
#   - Repository settings (merge options, security, features)
#   - Allowlist-based cleanup (removes unlisted labels/topics)
#   - Idempotent operations (safe to run repeatedly)
#   - macOS compatible (works with Bash 3.2+)
#
# Usage:
#   ./repos.sh              # Process all repositories (settings, labels, topics)
#   ./repos.sh --settings   # Only process repository settings
#   ./repos.sh --labels     # Only process labels
#   ./repos.sh --topics     # Only process descriptions and topics
#   ./repos.sh --dependabot # Validate dependabot.yml configuration
#   ./repos.sh --dry-run    # Show what would be done without making changes
#
# Combine flags:
#   ./repos.sh --labels --topics          # Labels and topics, no settings
#   ./repos.sh --settings --dry-run       # Preview settings changes only
#   ./repos.sh --dependabot               # Check dependabot.yml coverage
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/repos.json"

# Parse command line arguments
# If no specific flags given, do everything. If any flag given, only do those.
DO_SETTINGS=default
DO_LABELS=default
DO_TOPICS=default
DO_DEPENDABOT=default
DRY_RUN=false

# Helper to set all others to false when first specific flag is given
first_flag_seen=false
set_exclusive() {
    if [[ "$first_flag_seen" == "false" ]]; then
        DO_SETTINGS=false
        DO_LABELS=false
        DO_TOPICS=false
        DO_DEPENDABOT=false
        first_flag_seen=true
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --settings)
            [[ "$DO_SETTINGS" == "default" ]] && set_exclusive
            DO_SETTINGS=true
            shift
            ;;
        --labels)
            [[ "$DO_LABELS" == "default" ]] && set_exclusive
            DO_LABELS=true
            shift
            ;;
        --topics)
            [[ "$DO_TOPICS" == "default" ]] && set_exclusive
            DO_TOPICS=true
            shift
            ;;
        --dependabot)
            [[ "$DO_DEPENDABOT" == "default" ]] && set_exclusive
            DO_DEPENDABOT=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --settings   Process repository settings (merge, security, features)"
            echo "  --labels     Process issue labels"
            echo "  --topics     Process descriptions and topics"
            echo "  --dependabot Validate dependabot.yml has required ecosystems"
            echo "  --dry-run    Show what would change without making changes"
            echo "  -h, --help   Show this help message"
            echo ""
            echo "If no options specified, processes everything."
            echo "Multiple options can be combined: --settings --labels"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--settings] [--labels] [--topics] [--dependabot] [--dry-run]"
            exit 1
            ;;
    esac
done

# Convert defaults to true (do everything if no specific flags)
[[ "$DO_SETTINGS" == "default" ]] && DO_SETTINGS=true
[[ "$DO_LABELS" == "default" ]] && DO_LABELS=true
[[ "$DO_TOPICS" == "default" ]] && DO_TOPICS=true
[[ "$DO_DEPENDABOT" == "default" ]] && DO_DEPENDABOT=true

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Validate JSON syntax early
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in $CONFIG_FILE"
    exit 1
fi

# =============================================================================
# Newline-separated lists for lookups (Bash 3.2 compatible)
# =============================================================================
ALLOWED_LABELS=""
ALLOWED_TOPICS=""
EXISTING_LABELS=""
EXISTING_LABELS_JSON=""
EXISTING_TOPICS=""

# =============================================================================
# Warning Collection (for end-of-run summary)
# =============================================================================
WARNINGS=""
WARNING_COUNT=0

# Add a warning to the collection
add_warning() {
    local repo="$1"
    local category="$2"
    local message="$3"
    WARNINGS=$(list_add "$WARNINGS" "$repo|$category|$message")
    ((WARNING_COUNT++)) || true
}

# =============================================================================
# Helper Functions
# =============================================================================

# Execute or print command based on dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "    [dry-run] $*"
        return 0
    fi
    "$@"
}

# Reset allowlists for new repository
reset_allowlists() {
    ALLOWED_LABELS=""
    ALLOWED_TOPICS=""
}

# Check if item exists in newline-separated list
list_contains() {
    local list="$1"
    local item="$2"
    echo "$list" | grep -qxF "$item"
}

# Add item to newline-separated list
list_add() {
    local list="$1"
    local item="$2"
    if [[ -z "$list" ]]; then
        echo "$item"
    else
        printf '%s\n%s' "$list" "$item"
    fi
}

# =============================================================================
# Settings Functions
# =============================================================================

# Map config key to gh repo edit flag
get_gh_flag() {
    local key="$1"
    case "$key" in
        delete_branch_on_merge)    echo "--delete-branch-on-merge" ;;
        allow_merge_commit)        echo "--enable-merge-commit" ;;
        allow_rebase_merge)        echo "--enable-rebase-merge" ;;
        allow_squash_merge)        echo "--enable-squash-merge" ;;
        allow_auto_merge)          echo "--enable-auto-merge" ;;
        allow_forking)             echo "--allow-forking" ;;
        allow_update_branch)       echo "--allow-update-branch" ;;
        enable_issues)             echo "--enable-issues" ;;
        enable_wiki)               echo "--enable-wiki" ;;
        enable_projects)           echo "--enable-projects" ;;
        enable_discussions)        echo "--enable-discussions" ;;
        enable_secret_scanning)    echo "--enable-secret-scanning" ;;
        enable_secret_scanning_push_protection) echo "--enable-secret-scanning-push-protection" ;;
        # These require API calls via security_and_analysis object
        enable_secret_scanning_validity_checks) echo "API_SEC_ANALYSIS" ;;
        enable_secret_scanning_non_provider_patterns) echo "API_SEC_ANALYSIS" ;;
        enable_secret_scanning_ai_detection) echo "API_SEC_ANALYSIS" ;;
        # These require API calls, not gh repo edit
        web_commit_signoff_required) echo "API" ;;
        enable_vulnerability_alerts) echo "API_VULN" ;;
        enable_automated_security_fixes) echo "API_SEC" ;;
        enable_private_vulnerability_reporting) echo "API_PVR" ;;
        # String-based merge commit settings (API only)
        squash_merge_commit_title)   echo "API_STRING" ;;
        squash_merge_commit_message) echo "API_STRING" ;;
        merge_commit_title)          echo "API_STRING" ;;
        merge_commit_message)        echo "API_STRING" ;;
        *)                         echo "" ;;
    esac
}

# Map config key to GitHub API field name
get_api_field() {
    local key="$1"
    case "$key" in
        delete_branch_on_merge)    echo "delete_branch_on_merge" ;;
        allow_merge_commit)        echo "allow_merge_commit" ;;
        allow_rebase_merge)        echo "allow_rebase_merge" ;;
        allow_squash_merge)        echo "allow_squash_merge" ;;
        allow_auto_merge)          echo "allow_auto_merge" ;;
        allow_forking)             echo "allow_forking" ;;
        allow_update_branch)       echo "allow_update_branch" ;;
        enable_issues)             echo "has_issues" ;;
        enable_wiki)               echo "has_wiki" ;;
        enable_projects)           echo "has_projects" ;;
        enable_discussions)        echo "has_discussions" ;;
        enable_secret_scanning)    echo "security_and_analysis.secret_scanning.status" ;;
        enable_secret_scanning_push_protection) echo "security_and_analysis.secret_scanning_push_protection.status" ;;
        enable_secret_scanning_validity_checks) echo "security_and_analysis.secret_scanning_validity_checks.status" ;;
        enable_secret_scanning_non_provider_patterns) echo "security_and_analysis.secret_scanning_non_provider_patterns.status" ;;
        enable_secret_scanning_ai_detection) echo "security_and_analysis.secret_scanning_ai_detection.status" ;;
        web_commit_signoff_required) echo "web_commit_signoff_required" ;;
        enable_vulnerability_alerts) echo "SPECIAL_VULN" ;;
        enable_automated_security_fixes) echo "SPECIAL_SEC" ;;
        enable_private_vulnerability_reporting) echo "SPECIAL_PVR" ;;
        # String-based merge commit settings
        squash_merge_commit_title)   echo "squash_merge_commit_title" ;;
        squash_merge_commit_message) echo "squash_merge_commit_message" ;;
        merge_commit_title)          echo "merge_commit_title" ;;
        merge_commit_message)        echo "merge_commit_message" ;;
        *)                         echo "" ;;
    esac
}

# Get current value from fetched repo settings
get_current_setting() {
    local key="$1"
    local api_field
    api_field=$(get_api_field "$key")

    # Special fields require separate API calls
    if [[ "$api_field" == "SPECIAL_VULN" ]]; then
        echo "$VULN_ALERTS_ENABLED"
        return
    elif [[ "$api_field" == "SPECIAL_SEC" ]]; then
        echo "$AUTO_SEC_ENABLED"
        return
    elif [[ "$api_field" == "SPECIAL_PVR" ]]; then
        echo "$PVR_ENABLED"
        return
    fi

    # Handle nested fields (security_and_analysis.*)
    if [[ "$api_field" == security_and_analysis.* ]]; then
        local nested_path="${api_field#security_and_analysis.}"
        local status
        status=$(echo "$CURRENT_SETTINGS" | jq -r ".security_and_analysis.$nested_path // \"disabled\"")
        # Convert "enabled"/"disabled" to true/false
        [[ "$status" == "enabled" ]] && echo "true" || echo "false"
    else
        echo "$CURRENT_SETTINGS" | jq -r ".$api_field // false"
    fi
}

# Apply a single setting (with error handling to continue on failure)
apply_setting() {
    local repo="$1"
    local key="$2"
    local desired="$3"
    local current="$4"

    local gh_flag
    gh_flag=$(get_gh_flag "$key")

    if [[ -z "$gh_flag" ]]; then
        echo "  ? $key (unknown setting, skipping)"
        return
    fi

    # Capture command output and exit status to handle errors gracefully
    local cmd_output
    local cmd_status=0

    # Note: API_STRING settings (merge commit title/message) are handled by apply_merge_commit_settings()
    if [[ "$gh_flag" == "API_STRING" ]]; then
        # This shouldn't be reached since we skip these in the main loop
        return
    fi

    # Boolean settings
    local desired_bool="false"
    local current_bool="false"
    [[ "$desired" == "true" ]] && desired_bool="true"
    [[ "$current" == "true" ]] && current_bool="true"

    # Human-readable labels
    local desired_label="DISABLE"
    local current_label="DISABLE"
    [[ "$desired_bool" == "true" ]] && desired_label="ENABLE"
    [[ "$current_bool" == "true" ]] && current_label="ENABLE"

    if [[ "$desired_bool" == "$current_bool" ]]; then
        echo "  ✓ $key -> $desired_label"
        return
    fi

    echo "  ~ $key ($current_label → $desired_label)"

    if [[ "$gh_flag" == "API" ]]; then
        # Use API for settings not supported by gh repo edit
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "    [dry-run] gh api -X PATCH repos/$repo -f $key=$desired_bool"
        else
            cmd_output=$(gh api -X PATCH "repos/$repo" -f "$key=$desired_bool" 2>&1) || cmd_status=$?
        fi
    elif [[ "$gh_flag" == "API_VULN" ]]; then
        # Vulnerability alerts: PUT to enable, DELETE to disable
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "    [dry-run] gh api -X PUT/DELETE repos/$repo/vulnerability-alerts"
        elif [[ "$desired_bool" == "true" ]]; then
            cmd_output=$(gh api -X PUT "repos/$repo/vulnerability-alerts" --silent 2>&1) || cmd_status=$?
        else
            cmd_output=$(gh api -X DELETE "repos/$repo/vulnerability-alerts" --silent 2>&1) || cmd_status=$?
        fi
    elif [[ "$gh_flag" == "API_SEC" ]]; then
        # Automated security fixes: PUT to enable, DELETE to disable
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "    [dry-run] gh api -X PUT/DELETE repos/$repo/automated-security-fixes"
        elif [[ "$desired_bool" == "true" ]]; then
            cmd_output=$(gh api -X PUT "repos/$repo/automated-security-fixes" --silent 2>&1) || cmd_status=$?
        else
            cmd_output=$(gh api -X DELETE "repos/$repo/automated-security-fixes" --silent 2>&1) || cmd_status=$?
        fi
    elif [[ "$gh_flag" == "API_PVR" ]]; then
        # Private vulnerability reporting: PUT to enable, DELETE to disable
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "    [dry-run] gh api -X PUT/DELETE repos/$repo/private-vulnerability-reporting"
        elif [[ "$desired_bool" == "true" ]]; then
            cmd_output=$(gh api -X PUT "repos/$repo/private-vulnerability-reporting" --silent 2>&1) || cmd_status=$?
        else
            cmd_output=$(gh api -X DELETE "repos/$repo/private-vulnerability-reporting" --silent 2>&1) || cmd_status=$?
        fi
    elif [[ "$gh_flag" == "API_SEC_ANALYSIS" ]]; then
        # Security analysis settings via PATCH with security_and_analysis object
        # Map config key to API field name
        local api_field_name
        case "$key" in
            enable_secret_scanning_validity_checks)      api_field_name="secret_scanning_validity_checks" ;;
            enable_secret_scanning_non_provider_patterns) api_field_name="secret_scanning_non_provider_patterns" ;;
            enable_secret_scanning_ai_detection)         api_field_name="secret_scanning_ai_detection" ;;
        esac
        local status_value="disabled"
        [[ "$desired_bool" == "true" ]] && status_value="enabled"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "    [dry-run] gh api -X PATCH repos/$repo --input (security_and_analysis.$api_field_name.status=$status_value)"
        else
            cmd_output=$(gh api -X PATCH "repos/$repo" \
                --input - <<< "{\"security_and_analysis\":{\"$api_field_name\":{\"status\":\"$status_value\"}}}" 2>&1) || cmd_status=$?
        fi
    else
        # Use gh repo edit
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "    [dry-run] gh repo edit $repo $gh_flag"
        elif [[ "$desired_bool" == "true" ]]; then
            cmd_output=$(gh repo edit "$repo" "$gh_flag" 2>&1) || cmd_status=$?
        else
            cmd_output=$(gh repo edit "$repo" "$gh_flag=false" 2>&1) || cmd_status=$?
        fi
    fi

    # Handle command result
    if [[ $cmd_status -ne 0 ]]; then
        # Extract error message (look for common patterns)
        local error_msg="unknown error"
        if echo "$cmd_output" | grep -qi "organization.*policy\|not allowed\|forbidden\|permission"; then
            error_msg="blocked by org policy"
        elif echo "$cmd_output" | grep -qi "not found"; then
            error_msg="not found or not available"
        elif echo "$cmd_output" | grep -qi "private.*fork\|fork.*private"; then
            error_msg="forking not allowed for private repos"
        elif echo "$cmd_output" | grep -qi "advanced.security\|ghas\|secret.protection"; then
            error_msg="requires GitHub Advanced Security"
        elif echo "$cmd_output" | grep -qi "public.*only\|not.*private"; then
            error_msg="only available for public repos"
        elif echo "$cmd_output" | grep -qi "always available\|always enabled"; then
            # Not an error - feature is automatically enabled
            echo "    ℹ Already enabled (automatic for this repo type)"
            return
        else
            # Use first line of error output, truncated
            error_msg=$(echo "$cmd_output" | head -1 | cut -c1-50)
        fi
        echo "    ⚠ Failed: $error_msg"
        add_warning "$repo" "settings" "$key: $error_msg"
    fi
}

process_settings() {
    local repo="$1"

    echo ""
    echo "  Settings:"

    # Fetch current settings via API (more complete than gh repo view)
    CURRENT_SETTINGS=$(gh api "repos/$repo" --jq '{
        delete_branch_on_merge,
        allow_merge_commit,
        allow_rebase_merge,
        allow_squash_merge,
        allow_auto_merge,
        allow_forking,
        allow_update_branch,
        has_issues,
        has_wiki,
        has_projects,
        has_discussions,
        web_commit_signoff_required,
        security_and_analysis,
        squash_merge_commit_title,
        squash_merge_commit_message,
        merge_commit_title,
        merge_commit_message
    }')

    # Fetch vulnerability alerts status (204 = enabled, 404 = disabled)
    if gh api "repos/$repo/vulnerability-alerts" --silent 2>/dev/null; then
        VULN_ALERTS_ENABLED="true"
    else
        VULN_ALERTS_ENABLED="false"
    fi

    # Fetch automated security fixes status
    if gh api "repos/$repo/automated-security-fixes" --silent 2>/dev/null; then
        AUTO_SEC_ENABLED="true"
    else
        AUTO_SEC_ENABLED="false"
    fi

    # Fetch private vulnerability reporting status
    if gh api "repos/$repo/private-vulnerability-reporting" --silent 2>/dev/null; then
        PVR_ENABLED="true"
    else
        PVR_ENABLED="false"
    fi

    # Get merged settings (common + repo-specific overrides)
    local repo_settings
    repo_settings=$(jq -c --arg repo "$repo" '
        .common.settings as $common |
        (.repositories[$repo].settings // {}) as $override |
        $common + $override
    ' "$CONFIG_FILE")

    # Process each setting (skip merge commit string settings - handled separately)
    local settings_keys
    settings_keys=$(echo "$repo_settings" | jq -r 'keys[]')

    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        # Skip merge commit string settings - they must be batched together
        case "$key" in
            squash_merge_commit_title|squash_merge_commit_message|merge_commit_title|merge_commit_message)
                continue
                ;;
        esac
        local desired current
        desired=$(echo "$repo_settings" | jq -r --arg k "$key" '.[$k]')
        current=$(get_current_setting "$key")
        apply_setting "$repo" "$key" "$desired" "$current"
    done <<< "$settings_keys"

    # Process merge commit string settings as a batch (must be sent together for valid combos)
    apply_merge_commit_settings "$repo" "$repo_settings"
}

# Apply merge commit title/message settings in a single API call
# These settings must be sent together to maintain valid combinations
apply_merge_commit_settings() {
    local repo="$1"
    local repo_settings="$2"

    # Check if merge methods are enabled (settings only apply when method is enabled)
    local squash_enabled merge_enabled
    squash_enabled=$(echo "$CURRENT_SETTINGS" | jq -r '.allow_squash_merge // false')
    merge_enabled=$(echo "$CURRENT_SETTINGS" | jq -r '.allow_merge_commit // false')

    # Get desired values
    local desired_squash_title desired_squash_msg desired_merge_title desired_merge_msg
    desired_squash_title=$(echo "$repo_settings" | jq -r '.squash_merge_commit_title // empty')
    desired_squash_msg=$(echo "$repo_settings" | jq -r '.squash_merge_commit_message // empty')
    desired_merge_title=$(echo "$repo_settings" | jq -r '.merge_commit_title // empty')
    desired_merge_msg=$(echo "$repo_settings" | jq -r '.merge_commit_message // empty')

    # Skip squash settings if squash merge is disabled
    if [[ "$squash_enabled" != "true" ]]; then
        if [[ -n "$desired_squash_title" || -n "$desired_squash_msg" ]]; then
            echo "  ⊘ squash_merge_commit_* (skipped - squash merge disabled)"
        fi
        desired_squash_title=""
        desired_squash_msg=""
    fi

    # Skip merge commit settings if merge commits are disabled
    if [[ "$merge_enabled" != "true" ]]; then
        if [[ -n "$desired_merge_title" || -n "$desired_merge_msg" ]]; then
            echo "  ⊘ merge_commit_* (skipped - merge commits disabled)"
        fi
        desired_merge_title=""
        desired_merge_msg=""
    fi

    # If no merge commit settings configured (or all skipped), skip
    if [[ -z "$desired_squash_title" && -z "$desired_squash_msg" && -z "$desired_merge_title" && -z "$desired_merge_msg" ]]; then
        return
    fi

    # Get current values
    local current_squash_title current_squash_msg current_merge_title current_merge_msg
    current_squash_title=$(echo "$CURRENT_SETTINGS" | jq -r '.squash_merge_commit_title // empty')
    current_squash_msg=$(echo "$CURRENT_SETTINGS" | jq -r '.squash_merge_commit_message // empty')
    current_merge_title=$(echo "$CURRENT_SETTINGS" | jq -r '.merge_commit_title // empty')
    current_merge_msg=$(echo "$CURRENT_SETTINGS" | jq -r '.merge_commit_message // empty')

    # Build list of changes needed
    local changes_needed=false
    local api_args=()

    if [[ -n "$desired_squash_title" && "$desired_squash_title" != "$current_squash_title" ]]; then
        echo "  ~ squash_merge_commit_title ($current_squash_title → $desired_squash_title)"
        api_args+=(-f "squash_merge_commit_title=$desired_squash_title")
        changes_needed=true
    elif [[ -n "$desired_squash_title" ]]; then
        echo "  ✓ squash_merge_commit_title -> $desired_squash_title"
        # Include current value to maintain valid combo
        api_args+=(-f "squash_merge_commit_title=$desired_squash_title")
    fi

    if [[ -n "$desired_squash_msg" && "$desired_squash_msg" != "$current_squash_msg" ]]; then
        echo "  ~ squash_merge_commit_message ($current_squash_msg → $desired_squash_msg)"
        api_args+=(-f "squash_merge_commit_message=$desired_squash_msg")
        changes_needed=true
    elif [[ -n "$desired_squash_msg" ]]; then
        echo "  ✓ squash_merge_commit_message -> $desired_squash_msg"
        # Include current value to maintain valid combo
        api_args+=(-f "squash_merge_commit_message=$desired_squash_msg")
    fi

    if [[ -n "$desired_merge_title" && "$desired_merge_title" != "$current_merge_title" ]]; then
        echo "  ~ merge_commit_title ($current_merge_title → $desired_merge_title)"
        api_args+=(-f "merge_commit_title=$desired_merge_title")
        changes_needed=true
    elif [[ -n "$desired_merge_title" ]]; then
        echo "  ✓ merge_commit_title -> $desired_merge_title"
        # Include current value to maintain valid combo
        api_args+=(-f "merge_commit_title=$desired_merge_title")
    fi

    if [[ -n "$desired_merge_msg" && "$desired_merge_msg" != "$current_merge_msg" ]]; then
        echo "  ~ merge_commit_message ($current_merge_msg → $desired_merge_msg)"
        api_args+=(-f "merge_commit_message=$desired_merge_msg")
        changes_needed=true
    elif [[ -n "$desired_merge_msg" ]]; then
        echo "  ✓ merge_commit_message -> $desired_merge_msg"
        # Include current value to maintain valid combo
        api_args+=(-f "merge_commit_message=$desired_merge_msg")
    fi

    # If no changes needed, we're done
    if [[ "$changes_needed" == "false" ]]; then
        return
    fi

    # Apply all merge commit settings in a single API call
    local cmd_output
    local cmd_status=0

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "    [dry-run] gh api -X PATCH repos/$repo ${api_args[*]}"
    else
        cmd_output=$(gh api -X PATCH "repos/$repo" "${api_args[@]}" 2>&1) || cmd_status=$?
    fi

    if [[ $cmd_status -ne 0 ]]; then
        local error_msg
        error_msg=$(echo "$cmd_output" | jq -r '.message // "unknown error"' 2>/dev/null || echo "$cmd_output" | head -1 | cut -c1-60)
        echo "    ⚠ Failed to update merge commit settings: $error_msg"
        add_warning "$repo" "settings" "merge_commit_settings: $error_msg"
    fi
}

# =============================================================================
# Label Functions
# =============================================================================

get_label_info() {
    local name="$1"
    echo "$EXISTING_LABELS_JSON" | jq -r --arg name "$name" \
        '.[] | select(.name == $name) | "\(.color)|\(.description)"'
}

label_needs_update() {
    local name="$1"
    local color="$2"
    local description="$3"

    local current
    current=$(get_label_info "$name")
    [[ -z "$current" ]] && return 1  # Doesn't exist

    local current_color="${current%%|*}"
    local current_description="${current#*|}"

    # Normalize colors (lowercase, no #)
    color=$(echo "${color#\#}" | tr '[:upper:]' '[:lower:]')
    current_color=$(echo "${current_color#\#}" | tr '[:upper:]' '[:lower:]')

    [[ "$current_color" != "$color" ]] || [[ "$current_description" != "$description" ]]
}

ensure_label() {
    local repo="$1"
    local name="$2"
    local color="$3"
    local description="$4"

    ALLOWED_LABELS=$(list_add "$ALLOWED_LABELS" "$name")

    if list_contains "$EXISTING_LABELS" "$name"; then
        if label_needs_update "$name" "$color" "$description"; then
            echo "  ~ $name (updating)"
            run_cmd gh label edit "$name" --repo "$repo" --color "$color" --description "$description"
        else
            echo "  ✓ $name"
        fi
    else
        echo "  + $name (creating)"
        run_cmd gh label create "$name" --repo "$repo" --color "$color" --description "$description"
    fi
}

cleanup_labels() {
    local repo="$1"
    local deleted=0

    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        if ! list_contains "$ALLOWED_LABELS" "$label"; then
            echo "  - $label (removing)"
            run_cmd gh label delete "$label" --repo "$repo" --yes
            ((deleted++)) || true
        fi
    done <<< "$EXISTING_LABELS"

    if [[ $deleted -eq 0 ]]; then
        echo "  ✓ No unlisted labels"
    else
        echo "  Removed $deleted unlisted label(s)"
    fi
}

# =============================================================================
# Topic Functions
# =============================================================================

ensure_topic() {
    local repo="$1"
    local topic="$2"

    ALLOWED_TOPICS=$(list_add "$ALLOWED_TOPICS" "$topic")

    if list_contains "$EXISTING_TOPICS" "$topic"; then
        echo "  ✓ $topic"
    else
        echo "  + $topic (adding)"
        run_cmd gh repo edit "$repo" --add-topic "$topic"
    fi
}

cleanup_topics() {
    local repo="$1"
    local removed=0

    while IFS= read -r topic; do
        [[ -z "$topic" ]] && continue
        if ! list_contains "$ALLOWED_TOPICS" "$topic"; then
            echo "  - $topic (removing)"
            run_cmd gh repo edit "$repo" --remove-topic "$topic"
            ((removed++)) || true
        fi
    done <<< "$EXISTING_TOPICS"

    if [[ $removed -eq 0 ]]; then
        echo "  ✓ No unlisted topics"
    else
        echo "  Removed $removed unlisted topic(s)"
    fi
}

# =============================================================================
# Dependabot Functions
# =============================================================================

# Validate dependabot.yml exists and has required ecosystem entries
process_dependabot() {
    local repo="$1"

    echo ""
    echo "  Dependabot:"

    # Get configured ecosystems for this repo
    local ecosystems_json
    ecosystems_json=$(jq -c --arg repo "$repo" '
        .repositories[$repo].ecosystems // []
    ' "$CONFIG_FILE")

    local ecosystem_count
    ecosystem_count=$(echo "$ecosystems_json" | jq 'length')

    if [[ "$ecosystem_count" -eq 0 ]]; then
        echo "  ✓ No ecosystems configured (skipping)"
        return
    fi

    # Fetch dependabot.yml from repo
    local api_response
    local file_content=""

    if api_response=$(gh api "repos/$repo/contents/.github/dependabot.yml" 2>/dev/null); then
        file_content=$(echo "$api_response" | jq -r '.content' | base64 -d 2>/dev/null || true)
    fi

    if [[ -z "$file_content" ]]; then
        local required_list
        required_list=$(echo "$ecosystems_json" | jq -r 'join(", ")')
        echo "  ⚠ Missing dependabot.yml"
        echo "    Required ecosystems: $required_list"
        add_warning "$repo" "dependabot" "missing dependabot.yml (needs: $required_list)"
        return
    fi

    echo "  ✓ dependabot.yml exists"

    # Check for each configured ecosystem in the file
    local missing_ecosystems=""
    local found_ecosystems=""

    while IFS= read -r ecosystem; do
        [[ -z "$ecosystem" ]] && continue

        # Check if this ecosystem is defined in the dependabot.yml
        # Look for 'package-ecosystem: "ecosystem"' or 'package-ecosystem: ecosystem'
        if echo "$file_content" | grep -qE "package-ecosystem:[[:space:]]*[\"']?${ecosystem}[\"']?"; then
            found_ecosystems=$(list_add "$found_ecosystems" "$ecosystem")
        else
            missing_ecosystems=$(list_add "$missing_ecosystems" "$ecosystem")
        fi
    done < <(echo "$ecosystems_json" | jq -r '.[]')

    # Report findings
    while IFS= read -r ecosystem; do
        [[ -z "$ecosystem" ]] && continue
        echo "    ✓ $ecosystem"
    done <<< "$found_ecosystems"

    while IFS= read -r ecosystem; do
        [[ -z "$ecosystem" ]] && continue
        echo "    ⚠ Missing: $ecosystem"
        add_warning "$repo" "dependabot" "missing ecosystem: $ecosystem"
    done <<< "$missing_ecosystems"
}

# =============================================================================
# Description Function
# =============================================================================

ensure_description() {
    local repo="$1"
    local description="$2"
    local current="$3"

    if [[ "$current" != "$description" ]]; then
        echo "  ~ Updating description"
        run_cmd gh repo edit "$repo" --description "$description"
    else
        echo "  ✓ Description matches"
    fi
}

# =============================================================================
# Main Processing Function
# =============================================================================

process_repository() {
    local repo="$1"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $repo"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    reset_allowlists

    # -------------------------------------------------------------------------
    # Get repository configuration
    # -------------------------------------------------------------------------
    local repo_config
    repo_config=$(jq -c --arg repo "$repo" '.repositories[$repo]' "$CONFIG_FILE")

    # -------------------------------------------------------------------------
    # Process Settings
    # -------------------------------------------------------------------------
    if [[ "$DO_SETTINGS" == "true" ]]; then
        process_settings "$repo"
    fi

    # -------------------------------------------------------------------------
    # Fetch existing labels/topics data
    # -------------------------------------------------------------------------
    local repo_json description_text

    if [[ "$DO_LABELS" == "true" ]]; then
        EXISTING_LABELS_JSON=$(gh label list --repo "$repo" --limit 200 --json name,color,description)
        EXISTING_LABELS=$(echo "$EXISTING_LABELS_JSON" | jq -r '.[].name')
    fi

    if [[ "$DO_TOPICS" == "true" ]]; then
        repo_json=$(gh repo view "$repo" --json description,repositoryTopics)
        EXISTING_TOPICS=$(echo "$repo_json" | jq -r '.repositoryTopics // [] | .[].name')
        description_text=$(echo "$repo_json" | jq -r '.description // ""')
    fi

    # -------------------------------------------------------------------------
    # Process Labels
    # -------------------------------------------------------------------------
    if [[ "$DO_LABELS" == "true" ]]; then
        echo ""
        echo "  Labels:"

        # Common labels
        while IFS= read -r label; do
            [[ -z "$label" ]] && continue
            local name color desc
            name=$(echo "$label" | jq -r '.name')
            color=$(echo "$label" | jq -r '.color')
            desc=$(echo "$label" | jq -r '.description')
            ensure_label "$repo" "$name" "$color" "$desc"
        done < <(jq -c '.common.labels[]' "$CONFIG_FILE")

        # Repository-specific labels
        while IFS= read -r label; do
            [[ -z "$label" ]] && continue
            local name color desc
            name=$(echo "$label" | jq -r '.name')
            color=$(echo "$label" | jq -r '.color')
            desc=$(echo "$label" | jq -r '.description')
            ensure_label "$repo" "$name" "$color" "$desc"
        done < <(echo "$repo_config" | jq -c '.labels // [] | .[]')

        echo ""
        echo "  Label Cleanup:"
        cleanup_labels "$repo"
    fi

    # -------------------------------------------------------------------------
    # Process Description and Topics
    # -------------------------------------------------------------------------
    if [[ "$DO_TOPICS" == "true" ]]; then
        local target_description skip_common
        target_description=$(echo "$repo_config" | jq -r '.description')
        skip_common=$(echo "$repo_config" | jq -r '.skip_common_topics // false')

        echo ""
        echo "  Description:"
        ensure_description "$repo" "$target_description" "$description_text"

        echo ""
        echo "  Topics:"

        # Common topics (unless skipped)
        if [[ "$skip_common" != "true" ]]; then
            while IFS= read -r topic; do
                [[ -z "$topic" ]] && continue
                ensure_topic "$repo" "$topic"
            done < <(jq -r '.common.topics[]' "$CONFIG_FILE")
        fi

        # Repository-specific topics
        while IFS= read -r topic; do
            [[ -z "$topic" ]] && continue
            ensure_topic "$repo" "$topic"
        done < <(echo "$repo_config" | jq -r '.topics // [] | .[]')

        echo ""
        echo "  Topic Cleanup:"
        cleanup_topics "$repo"
    fi

    # -------------------------------------------------------------------------
    # Process Dependabot
    # -------------------------------------------------------------------------
    if [[ "$DO_DEPENDABOT" == "true" ]]; then
        process_dependabot "$repo"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                    InferaDB Repository Manager                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Config:     $CONFIG_FILE"
echo "  Settings:   $DO_SETTINGS"
echo "  Labels:     $DO_LABELS"
echo "  Topics:     $DO_TOPICS"
echo "  Dependabot: $DO_DEPENDABOT"
echo "  Dry Run:    $DRY_RUN"
echo ""
echo "  Requires:   gh CLI authenticated with repo admin permissions"

# Read repository list
REPOS=$(jq -r '.repositories | keys[]' "$CONFIG_FILE")
REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')

echo "  Repos:     $REPO_COUNT"

# Process each repository
while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    process_repository "$repo"
done <<< "$REPOS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done! Processed $REPO_COUNT repositories."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =============================================================================
# Warning Summary
# =============================================================================
if [[ $WARNING_COUNT -gt 0 ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                         ⚠  Warning Summary                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  $WARNING_COUNT warning(s) found:"
    echo ""

    # Group warnings by repository
    current_repo=""
    while IFS= read -r warning_line; do
        [[ -z "$warning_line" ]] && continue

        warn_repo="${warning_line%%|*}"
        rest="${warning_line#*|}"
        warn_category="${rest%%|*}"
        warn_message="${rest#*|}"

        if [[ "$warn_repo" != "$current_repo" ]]; then
            [[ -n "$current_repo" ]] && echo ""
            echo "  $warn_repo:"
            current_repo="$warn_repo"
        fi

        echo "    [$warn_category] $warn_message"
    done <<< "$WARNINGS"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo ""
    echo "  ✓ No warnings"
fi
echo ""
