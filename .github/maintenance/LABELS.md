# InferaDB Repository Labels

Standardized label configuration for GitHub issues and pull requests across all InferaDB repositories.

## Overview

This labeling strategy provides consistency across:

- `inferadb` (meta-repository)
- `inferadb/engine` (core policy engine)
- `inferadb/control` (control plane API)
- `inferadb/dashboard` (web console)
- `inferadb/tests` (E2E integration tests)

Labels use a **prefix-based naming convention** with consistent color coding per category.

---

## Label Categories

### Kind (Issue/PR Type)

Identifies what type of work this represents.

| Label                  | Color     | Description                                |
| ---------------------- | --------- | ------------------------------------------ |
| `kind/bug`             | `#d73a4a` | Something isn't working as expected        |
| `kind/feature`         | `#a2eeef` | New capability or functionality            |
| `kind/enhancement`     | `#84b6eb` | Improvement to existing functionality      |
| `kind/refactor`        | `#fbca04` | Code restructuring without behavior change |
| `kind/documentation`   | `#0075ca` | Documentation improvements                 |
| `kind/security`        | `#b60205` | Security-related issue or fix              |
| `kind/performance`     | `#d4c5f9` | Performance improvements or issues         |
| `kind/breaking-change` | `#e99695` | Introduces breaking changes                |

### Area (Component/Subsystem)

Identifies which part of the system is affected. Apply multiple if cross-cutting.

#### Core Areas (all repositories)

| Label          | Color     | Description                        |
| -------------- | --------- | ---------------------------------- |
| `area/api`     | `#c5def5` | REST/gRPC API layer                |
| `area/auth`    | `#c5def5` | Authentication and authorization   |
| `area/config`  | `#c5def5` | Configuration handling             |
| `area/docs`    | `#c5def5` | Documentation                      |
| `area/ci`      | `#c5def5` | CI/CD pipelines and GitHub Actions |
| `area/deps`    | `#c5def5` | Dependencies and supply chain      |
| `area/testing` | `#c5def5` | Test infrastructure and coverage   |

#### Engine-Specific Areas (`engine/` repository)

| Label               | Color     | Description                      |
| ------------------- | --------- | -------------------------------- |
| `area/policy`       | `#bfdadc` | IPL parser and policy evaluation |
| `area/reachability` | `#bfdadc` | Graph traversal and reachability |
| `area/storage`      | `#bfdadc` | Storage backends (Memory, FDB)   |
| `area/cache`        | `#bfdadc` | Caching layer                    |
| `area/types`        | `#bfdadc` | Shared types crate               |
| `area/wasm`         | `#bfdadc` | WebAssembly runtime              |
| `area/repl`         | `#bfdadc` | Interactive REPL                 |

#### Control-Specific Areas (`control/` repository)

| Label          | Color     | Description                          |
| -------------- | --------- | ------------------------------------ |
| `area/tenancy` | `#d4e5f7` | Multi-tenant organization management |
| `area/vault`   | `#d4e5f7` | Vault access control and sync        |
| `area/session` | `#d4e5f7` | User sessions and authentication     |
| `area/passkey` | `#d4e5f7` | WebAuthn/FIDO2 passkey support       |
| `area/client`  | `#d4e5f7` | Client certificates and tokens       |
| `area/team`    | `#d4e5f7` | Team management                      |

#### Dashboard-Specific Areas (`dashboard/` repository)

| Label       | Color     | Description               |
| ----------- | --------- | ------------------------- |
| `area/ui`   | `#e6ccf5` | User interface components |
| `area/ux`   | `#e6ccf5` | User experience and flows |
| `area/a11y` | `#e6ccf5` | Accessibility             |

#### Deployment Areas (meta-repository, tests)

| Label                | Color     | Description                   |
| -------------------- | --------- | ----------------------------- |
| `area/k8s`           | `#f9d0c4` | Kubernetes manifests and Helm |
| `area/docker`        | `#f9d0c4` | Docker images and compose     |
| `area/terraform`     | `#f9d0c4` | Terraform provider            |
| `area/observability` | `#f9d0c4` | Metrics, logging, tracing     |

### Priority

Indicates urgency and importance.

| Label               | Color     | Description                                        |
| ------------------- | --------- | -------------------------------------------------- |
| `priority/critical` | `#b60205` | Requires immediate attention (security, data loss) |
| `priority/high`     | `#d93f0b` | Should be addressed soon                           |
| `priority/medium`   | `#fbca04` | Normal priority                                    |
| `priority/low`      | `#0e8a16` | Nice to have, no urgency                           |

### Effort

Estimated complexity/size for planning.

| Label           | Color     | Description                       |
| --------------- | --------- | --------------------------------- |
| `effort/small`  | `#c2e0c6` | Quick fix, hours of work          |
| `effort/medium` | `#fef2c0` | Few days of work                  |
| `effort/large`  | `#f9d0c4` | Week+ of work, may need breakdown |

### Status

Current state of the issue/PR.

| Label                     | Color     | Description                                   |
| ------------------------- | --------- | --------------------------------------------- |
| `status/blocked`          | `#d73a4a` | Cannot proceed due to external dependency     |
| `status/needs-triage`     | `#fbca04` | Requires maintainer review and categorization |
| `status/needs-info`       | `#fbca04` | Waiting for more information from reporter    |
| `status/needs-design`     | `#c5def5` | Requires design/architecture discussion       |
| `status/in-progress`      | `#0e8a16` | Actively being worked on                      |
| `status/ready-for-review` | `#6f42c1` | PR ready for code review                      |

### Resolution

Final disposition for closed issues.

| Label                  | Color     | Description                |
| ---------------------- | --------- | -------------------------- |
| `resolution/duplicate` | `#cfd3d7` | Duplicate of another issue |
| `resolution/wontfix`   | `#cfd3d7` | Will not be addressed      |
| `resolution/invalid`   | `#cfd3d7` | Not a valid issue          |
| `resolution/by-design` | `#cfd3d7` | Working as intended        |

### Community

Labels for community engagement.

| Label              | Color     | Description            |
| ------------------ | --------- | ---------------------- |
| `good-first-issue` | `#7057ff` | Good for newcomers     |
| `help-wanted`      | `#008672` | Extra attention needed |
| `hacktoberfest`    | `#ff7518` | Hacktoberfest eligible |

### Automation

Applied automatically by bots/actions.

| Label            | Color     | Description                     |
| ---------------- | --------- | ------------------------------- |
| `dependencies`   | `#0366d6` | Dependency updates (Dependabot) |
| `github-actions` | `#000000` | GitHub Actions workflow changes |
| `stale`          | `#cfd3d7` | Marked stale by automation      |

### Changelog

For release notes categorization (PRs only).

| Label                  | Color     | Description                       |
| ---------------------- | --------- | --------------------------------- |
| `changelog/added`      | `#0e8a16` | New features for release notes    |
| `changelog/changed`    | `#fbca04` | Changes in existing functionality |
| `changelog/deprecated` | `#fef2c0` | Soon-to-be removed features       |
| `changelog/removed`    | `#d73a4a` | Removed features                  |
| `changelog/fixed`      | `#c5def5` | Bug fixes                         |
| `changelog/security`   | `#b60205` | Security fixes                    |
| `changelog/skip`       | `#cfd3d7` | Do not include in changelog       |

---

## Repository-Specific Labels

### Meta-Repository (`inferadb`)

In addition to core labels, include:

| Label            | Color     | Description                    |
| ---------------- | --------- | ------------------------------ |
| `repo/engine`    | `#1d76db` | Related to engine component    |
| `repo/control`   | `#1d76db` | Related to control component   |
| `repo/dashboard` | `#1d76db` | Related to dashboard component |
| `repo/tests`     | `#1d76db` | Related to tests component     |
| `repo/cli`       | `#1d76db` | Related to CLI component       |

---

## Label Application Guidelines

### For Issues

1. **Always apply**: One `kind/*` label
2. **Always apply**: At least one `area/*` label
3. **Recommended**: `priority/*` after triage
4. **Optional**: `effort/*` when scoped

### For Pull Requests

1. **Always apply**: One `kind/*` label
2. **Always apply**: At least one `area/*` label
3. **Recommended**: One `changelog/*` label
4. **Auto-applied**: `dependencies`, `github-actions`

### Triage Process

New issues should be triaged within 48 hours:

1. Add `status/needs-triage` to new issues
2. During triage:
   - Add `kind/*` label
   - Add `area/*` label(s)
   - Add `priority/*` label
   - Remove `status/needs-triage`
   - Add `status/needs-info` if clarification needed
3. For contribution opportunities:
   - Add `good-first-issue` for simple, well-scoped issues
   - Add `help-wanted` for issues needing community help

---

## Color Reference

| Category          | Primary Color   | Hex       |
| ----------------- | --------------- | --------- |
| Bug/Critical      | Red             | `#d73a4a` |
| Feature           | Light Cyan      | `#a2eeef` |
| Enhancement       | Light Blue      | `#84b6eb` |
| Documentation     | Blue            | `#0075ca` |
| Security          | Dark Red        | `#b60205` |
| Good First Issue  | Purple          | `#7057ff` |
| Help Wanted       | Teal            | `#008672` |
| Area (generic)    | Light Blue-Gray | `#c5def5` |
| Area (engine)     | Light Teal      | `#bfdadc` |
| Area (control)    | Light Sky Blue  | `#d4e5f7` |
| Area (dashboard)  | Light Purple    | `#e6ccf5` |
| Area (deployment) | Light Salmon    | `#f9d0c4` |
| Priority High     | Orange          | `#d93f0b` |
| Effort Small      | Light Green     | `#c2e0c6` |
| Neutral/Closed    | Gray            | `#cfd3d7` |

---

## GitHub CLI Commands

### Create labels for a repository

```bash
# Set repository
REPO="inferadb/engine"

# Kind labels
gh label create "kind/bug" --repo $REPO --color "d73a4a" --description "Something isn't working as expected"
gh label create "kind/feature" --repo $REPO --color "a2eeef" --description "New capability or functionality"
gh label create "kind/enhancement" --repo $REPO --color "84b6eb" --description "Improvement to existing functionality"
gh label create "kind/refactor" --repo $REPO --color "fbca04" --description "Code restructuring without behavior change"
gh label create "kind/documentation" --repo $REPO --color "0075ca" --description "Documentation improvements"
gh label create "kind/security" --repo $REPO --color "b60205" --description "Security-related issue or fix"
gh label create "kind/performance" --repo $REPO --color "d4c5f9" --description "Performance improvements or issues"
gh label create "kind/breaking-change" --repo $REPO --color "e99695" --description "Introduces breaking changes"

# Priority labels
gh label create "priority/critical" --repo $REPO --color "b60205" --description "Requires immediate attention"
gh label create "priority/high" --repo $REPO --color "d93f0b" --description "Should be addressed soon"
gh label create "priority/medium" --repo $REPO --color "fbca04" --description "Normal priority"
gh label create "priority/low" --repo $REPO --color "0e8a16" --description "Nice to have, no urgency"

# Effort labels
gh label create "effort/small" --repo $REPO --color "c2e0c6" --description "Quick fix, hours of work"
gh label create "effort/medium" --repo $REPO --color "fef2c0" --description "Few days of work"
gh label create "effort/large" --repo $REPO --color "f9d0c4" --description "Week+ of work, may need breakdown"

# Status labels
gh label create "status/blocked" --repo $REPO --color "d73a4a" --description "Cannot proceed due to external dependency"
gh label create "status/needs-triage" --repo $REPO --color "fbca04" --description "Requires maintainer review"
gh label create "status/needs-info" --repo $REPO --color "fbca04" --description "Waiting for more information"
gh label create "status/needs-design" --repo $REPO --color "c5def5" --description "Requires design discussion"
gh label create "status/in-progress" --repo $REPO --color "0e8a16" --description "Actively being worked on"
gh label create "status/ready-for-review" --repo $REPO --color "6f42c1" --description "PR ready for code review"

# Resolution labels
gh label create "resolution/duplicate" --repo $REPO --color "cfd3d7" --description "Duplicate of another issue"
gh label create "resolution/wontfix" --repo $REPO --color "cfd3d7" --description "Will not be addressed"
gh label create "resolution/invalid" --repo $REPO --color "cfd3d7" --description "Not a valid issue"
gh label create "resolution/by-design" --repo $REPO --color "cfd3d7" --description "Working as intended"

# Community labels
gh label create "good-first-issue" --repo $REPO --color "7057ff" --description "Good for newcomers"
gh label create "help-wanted" --repo $REPO --color "008672" --description "Extra attention needed"

# Core area labels
gh label create "area/api" --repo $REPO --color "c5def5" --description "REST/gRPC API layer"
gh label create "area/auth" --repo $REPO --color "c5def5" --description "Authentication and authorization"
gh label create "area/config" --repo $REPO --color "c5def5" --description "Configuration handling"
gh label create "area/docs" --repo $REPO --color "c5def5" --description "Documentation"
gh label create "area/ci" --repo $REPO --color "c5def5" --description "CI/CD pipelines"
gh label create "area/deps" --repo $REPO --color "c5def5" --description "Dependencies and supply chain"
gh label create "area/testing" --repo $REPO --color "c5def5" --description "Test infrastructure and coverage"

# Changelog labels
gh label create "changelog/added" --repo $REPO --color "0e8a16" --description "New features for release notes"
gh label create "changelog/changed" --repo $REPO --color "fbca04" --description "Changes in existing functionality"
gh label create "changelog/deprecated" --repo $REPO --color "fef2c0" --description "Soon-to-be removed features"
gh label create "changelog/removed" --repo $REPO --color "d73a4a" --description "Removed features"
gh label create "changelog/fixed" --repo $REPO --color "c5def5" --description "Bug fixes"
gh label create "changelog/security" --repo $REPO --color "b60205" --description "Security fixes"
gh label create "changelog/skip" --repo $REPO --color "cfd3d7" --description "Do not include in changelog"
```

### Delete default GitHub labels

```bash
REPO="inferadb/engine"

gh label delete "bug" --repo $REPO --yes 2>/dev/null || true
gh label delete "documentation" --repo $REPO --yes 2>/dev/null || true
gh label delete "duplicate" --repo $REPO --yes 2>/dev/null || true
gh label delete "enhancement" --repo $REPO --yes 2>/dev/null || true
gh label delete "good first issue" --repo $REPO --yes 2>/dev/null || true
gh label delete "help wanted" --repo $REPO --yes 2>/dev/null || true
gh label delete "invalid" --repo $REPO --yes 2>/dev/null || true
gh label delete "question" --repo $REPO --yes 2>/dev/null || true
gh label delete "wontfix" --repo $REPO --yes 2>/dev/null || true
```

---

## Automation Recommendations

### GitHub Actions: Auto-label PRs

```yaml
# .github/workflows/labeler.yml
name: Label PRs

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@v5
        with:
          repo-token: "${{ secrets.GITHUB_TOKEN }}"
```

### Labeler Configuration

```yaml
# .github/labeler.yml
area/api:
  - changed-files:
      - any-glob-to-any-file: "crates/*-api/**"

area/auth:
  - changed-files:
      - any-glob-to-any-file: "crates/*-auth/**"

area/storage:
  - changed-files:
      - any-glob-to-any-file: "crates/*-store/**"

area/policy:
  - changed-files:
      - any-glob-to-any-file: "crates/*-core/**"

area/docs:
  - changed-files:
      - any-glob-to-any-file: ["docs/**", "*.md"]

area/ci:
  - changed-files:
      - any-glob-to-any-file: ".github/**"

area/k8s:
  - changed-files:
      - any-glob-to-any-file: ["k8s/**", "helm/**"]

area/docker:
  - changed-files:
      - any-glob-to-any-file: ["Dockerfile*", "docker/**"]
```

### Stale Issue Bot

```yaml
# .github/workflows/stale.yml
name: Close stale issues

on:
  schedule:
    - cron: "0 0 * * *"

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: "This issue has been marked stale due to inactivity."
          stale-issue-label: "stale"
          exempt-issue-labels: "priority/critical,priority/high,status/blocked"
          days-before-stale: 60
          days-before-close: 14
```

---

## Migration from Default Labels

When setting up a new repository or migrating existing labels:

1. Export existing issues/PRs with their labels
2. Create mapping from old labels to new labels
3. Run delete commands for default labels
4. Run create commands for new labels
5. Update existing issues/PRs with new labels

### Common Mappings

| Old Label          | New Label              |
| ------------------ | ---------------------- |
| `bug`              | `kind/bug`             |
| `enhancement`      | `kind/enhancement`     |
| `documentation`    | `kind/documentation`   |
| `duplicate`        | `resolution/duplicate` |
| `good first issue` | `good-first-issue`     |
| `help wanted`      | `help-wanted`          |
| `invalid`          | `resolution/invalid`   |
| `wontfix`          | `resolution/wontfix`   |
