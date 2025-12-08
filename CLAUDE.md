# InferaDB

Distributed authorization engine implementing Zanzibar-inspired ReBAC with native policy language (IPL).

## Repository Structure

Meta-repository with git submodules. Each component has its own `CLAUDE.md` with detailed guidance.

| Directory                      | Language   | Purpose                                                     |
| ------------------------------ | ---------- | ----------------------------------------------------------- |
| `engine/`                      | Rust       | Core policy engine (IPL parser, graph traversal, decisions) |
| `control/`                     | Rust       | Control plane API (tenants, RBAC, audit, tokens)            |
| `dashboard/`                   | TypeScript | Web console (TanStack Start, React)                         |
| `cli/`                         | Rust       | Developer tooling (schema validation, testing)              |
| `tests/`                       | Rust       | E2E integration tests and K8s scripts                       |
| `docs/`                        | -          | Whitepapers, deployment guides, RFC templates               |
| `terraform-provider-inferadb/` | -          | IaC provider (in development)                               |

## Quick Start

```bash
make setup              # Install tools (mise), dependencies
make build              # Debug build (both engine + control)
make test               # Unit tests (both)
make check              # Format + lint + audit
```

## Component Commands

Prefix with `engine-` or `control-` for specific targets:

```bash
make engine-dev         # Engine with auto-reload
make engine-test        # Engine tests only
make control-dev        # Control with auto-reload
make control-test       # Control tests only
```

## Kubernetes Environment

```bash
make k8s-start          # Start local K8s environment
make k8s-stop           # Stop environment (preserves state)
make k8s-status         # Check deployment health
make k8s-purge          # Remove all K8s resources
```

## Testing

```bash
make test               # Unit tests (engine + control)
make test-fdb           # FDB integration tests (requires Docker)
make test-e2e           # E2E tests in K8s
```

- Run `make test` before committing
- Run `make check` for format/lint/audit
- Component tests: `cargo test -p <crate-name>`
- Single test: `cargo test <test_name>`

## Key Conventions

- **Toolchain**: Managed via `mise.toml`
- **Formatting**: `cargo +nightly fmt --all` (rustfmt) + prettier
- **Linting**: `cargo clippy --workspace --all-targets -- -D warnings`
- **Submodules**: Run `git submodule update --init --recursive` if files missing

## Configuration

- Engine env prefix: `INFERADB__` (double underscore separator)
- Control env prefix: `INFERADB_CTRL__`
- Config files: `config.yaml` in each component

## Important Notes

- Read `engine/CLAUDE.md` when working in `engine/`
- Read `control/CLAUDE.md` when working in `control/`
- Read `tests/CLAUDE.md` when working in `tests/`
- Both components use layered architecture with strict dependency rules
- All storage operations are vault-scoped (multi-tenancy)
- Only asymmetric JWT algorithms allowed (EdDSA, RS256)
