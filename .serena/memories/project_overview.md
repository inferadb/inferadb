# InferaDB Meta-Repository - Project Overview

## Purpose

This is the meta-repository for InferaDB, a distributed fine-grained authorization engine inspired by Google Zanzibar with sub-millisecond latency at scale. The meta-repository manages all InferaDB components as git submodules.

## Status

Under active development. Not production-ready.

## Architecture

InferaDB follows a microservices architecture with clear separation of concerns:

- **Engine**: Policy Decision Point (PDP) - evaluates authorization requests
- **Control**: Policy Administration Point (PAP) - manages tenants, policies, credentials
- **Dashboard**: Web UI for policy design, simulation, and administration
- **CLI**: Command-line tooling for administration and debugging

## Tech Stack by Component

| Component          | Language       | Framework                  |
| ------------------ | -------------- | -------------------------- |
| Engine             | Rust           | Axum/Tonic, Ledger         |
| Control            | Rust           | Axum/Tonic, Ledger         |
| Dashboard          | TypeScript     | React, Vite                |
| CLI                | Rust           | Teapot TUI framework       |
| Terraform Provider | Go             | Terraform Plugin Framework |
| Rust SDK           | Rust           | Tokio                      |
| Deploy             | Terraform/Flux | Kubernetes                 |

## Submodules

| Directory                      | Description                                         | Repository                                      |
| ------------------------------ | --------------------------------------------------- | ----------------------------------------------- |
| `engine/`                      | High-performance ReBAC authorization engine         | github.com/inferadb/engine                      |
| `control/`                     | Multi-tenant control plane with WebAuthn auth       | github.com/inferadb/control                     |
| `dashboard/`                   | Web console for policy design and simulation        | github.com/inferadb/dashboard                   |
| `cli/`                         | Command-line interface for authorization management | github.com/inferadb/cli                         |
| `sdks/rust/`                   | Rust SDK for InferaDB APIs                          | github.com/inferadb/rust                        |
| `tests/`                       | E2E integration test suite                          | github.com/inferadb/tests                       |
| `deploy/`                      | Kubernetes deployment infrastructure                | github.com/inferadb/deploy                      |
| `docs/`                        | Technical documentation and RFCs                    | github.com/inferadb/docs                        |
| `teapot/`                      | Rust TUI framework used by the CLI                  | github.com/inferadb/teapot                      |
| `terraform-provider-inferadb/` | Terraform provider                                  | github.com/inferadb/terraform-provider-inferadb |

## Key Architectural Decisions

- **Ledger**: Chosen for ACID transactions, horizontal scaling, and multi-region support
- **gRPC + REST**: Dual API support (gRPC for performance, REST for compatibility)
- **AuthZEN Compliance**: Follows OpenID AuthZEN specification for interoperability
- **IPL (Infera Policy Language)**: Declarative, version-controlled policy language

## License

Dual-licensed under MIT and Apache 2.0 at your option.
