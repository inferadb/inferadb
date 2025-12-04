# InferaDB Context

## Project Overview

InferaDB is a distributed inference engine for authorization, designed for fine-grained, low-latency environments. It implements a Zanzibar-inspired ReBAC (Relationship-based Access Control) system with a native policy language (IPL).

This directory is a **meta-repository** that orchestrates several independent components (submodules).

## Components

- **`server/`** (Rust): The core policy engine. Handles IPL parsing, graph traversal, and decision evaluation.
- **`management/`** (Rust): The control plane API. Handles tenant management, RBAC, and audit logging.
- **`dashboard/`** (Web): Web console for policy design and observability (TanStack Start, React).
- **`cli/`** (Rust): CLI tools for developers (schema validation, testing).
- **`terraform-provider-inferadb/`**: Terraform provider for InferaDB resources.
- **`docs/`**: Comprehensive documentation.

## Development Setup

### Prerequisites

- **Make**: Primary build orchestration tool.
- **Mise**: Recommended for tool version management (Rust, etc.).
- **Docker**: Required for integration tests and running local databases (FoundationDB, etc.).

### Initial Setup

Run the setup command to install tools and dependencies for both `server` and `management` components:

```bash
make setup
```

## Build and Run

The root `Makefile` delegates commands to the submodules. You can run commands for all components or target specific ones.

### Common Commands

| Command       | Description                                     |
| :------------ | :---------------------------------------------- |
| `make setup`  | Setup development environment for all projects. |
| `make build`  | Build all projects (Debug).                     |
| `make test`   | Run unit tests for all projects.                |
| `make check`  | Run format, lint, and audit checks.             |
| `make format` | Format code (Rustfmt, Prettier, Taplo).         |
| `make clean`  | Clean build artifacts.                          |

### Component-Specific Commands

Prefix commands with `server-` or `management-` to target a specific component.

**Server:**

- `make server-dev`: Start the server with auto-reload (watch mode).
- `make server-test`: Run server tests.
- `make server-run`: Run the server normally.

**Management:**

- `make management-dev`: Start the management API with auto-reload.
- `make management-test`: Run management API tests.

### Kubernetes (Local)

Scripts in `scripts/` allow running a local K8s cluster for integration testing.

- `make k8s-start`: Start local cluster.
- `make k8s-test`: Run integration tests within the cluster.
- `make k8s-stop`: Stop the cluster.

## Codebase Conventions

- **Language:** Primarily Rust (`server`, `management`, `cli`).
- **Toolchain:** Managed via `mise.toml`.
- **Formatting:** Enforced via `rustfmt` and `prettier`. Run `make format` before committing.
- **Testing:** Extensive use of unit and integration tests.
  - `make test`: Unit tests.
  - `make test-integration`: Integration tests (often requires Docker).
- **Submodules:** Remember to update submodules if files seem missing: `git submodule update --init --recursive`.

## Key Files

- `Makefile`: The central entry point for all commands.
- `CLAUDE.md`: Quick reference for AI assistants (and humans).
- `server/Cargo.toml` / `management/Cargo.toml`: Rust workspace configurations.
