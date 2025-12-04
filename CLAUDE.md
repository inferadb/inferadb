# InferaDB

Distributed authorization engine implementing Zanzibar-inspired ReBAC with native policy language (IPL).

## Repository Structure

Meta-repository with git submodules. Each component has its own `CLAUDE.md` with detailed guidance.

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

## Kubernetes (Local)

```bash
make k8s-start          # Start local kind cluster
make k8s-test           # Run E2E integration tests
make k8s-status         # Check cluster status
make k8s-stop           # Stop cluster (preserves state)
make k8s-purge          # Destroy cluster completely
```

## Testing Instructions

- Run `make test` before committing
- Run `make check` for format/lint/audit
- Component tests: `cargo test -p <crate-name>`
- Single test: `cargo test <test_name>`
- Integration tests require Docker: `make test-integration`
- E2E tests require K8s: `make k8s-test`

## Key Conventions

- **Toolchain**: Managed via `mise.toml`
- **Formatting**: `cargo +nightly fmt --all` (rustfmt) + prettier
- **Linting**: `cargo clippy --workspace --all-targets -- -D warnings`
- **Submodules**: Run `git submodule update --init --recursive` if files missing

## Configuration

- Server env prefix: `INFERADB__` (double underscore separator)
- Management env prefix: `INFERADB_MGMT__`
- Config files: `config.yaml` in each component

## Important Notes

- Read `server/CLAUDE.md` when working in `server/`
- Read `management/CLAUDE.md` when working in `management/`
- Both components use layered architecture with strict dependency rules
- All storage operations are vault-scoped (multi-tenancy)
- Only asymmetric JWT algorithms allowed (EdDSA, RS256)
