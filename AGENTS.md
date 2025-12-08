# InferaDB

Distributed authorization engine implementing Zanzibar-inspired ReBAC with native policy language (IPL).

## Repository Structure

Meta-repository with git submodules. Each component has its own `AGENTS.md` with detailed guidance.

| Directory                      | Language   | Purpose                                                     |
| ------------------------------ | ---------- | ----------------------------------------------------------- |
| `server/`                      | Rust       | Core policy engine (IPL parser, graph traversal, decisions) |
| `management/`                  | Rust       | Control plane API (tenants, RBAC, audit, tokens)            |
| `dashboard/`                   | TypeScript | Web console (TanStack Start, React)                         |
| `cli/`                         | Rust       | Developer tooling (schema validation, testing)              |
| `tests/`                       | Rust       | E2E integration tests and K8s scripts                       |
| `docs/`                        | -          | Whitepapers, deployment guides, RFC templates               |
| `terraform-provider-inferadb/` | -          | IaC provider (in development)                               |

## Quick Start

```bash
make setup              # Install tools (mise), dependencies
make build              # Debug build (both server + management)
make test               # Unit tests (both)
make check              # Format + lint + audit
```

## Component Commands

Prefix with `server-` or `management-` for specific targets:

```bash
make server-dev         # Server with auto-reload
make server-test        # Server tests only
make management-dev     # Management API with auto-reload
make management-test    # Management tests only
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
make test               # Unit tests (server + management)
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

- Server env prefix: `INFERADB__` (double underscore separator)
- Management env prefix: `INFERADB_CTRL__`
- Config files: `config.yaml` in each component

## Important Notes

- Read `server/AGENTS.md` when working in `server/`
- Read `management/AGENTS.md` when working in `management/`
- Read `tests/AGENTS.md` when working in `tests/`
- Both components use layered architecture with strict dependency rules
- All storage operations are vault-scoped (multi-tenancy)
- Only asymmetric JWT algorithms allowed (EdDSA, RS256)
