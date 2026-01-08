<div align="center">
    <p><a href="https://inferadb.com"><img src=".github/inferadb.png" width="100" alt="InferaDB Logo" /></a></p>
    <h1>InferaDB</h1>
    <p>
        <a href="https://discord.gg/inferadb"><img src="https://img.shields.io/badge/Discord-Join%20us-5865F2?logo=discord&logoColor=white" alt="Discord" /></a>
        <a href="#license"><img src="https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg" alt="License" /></a>
    </p>
    <p>High-Performance Authorization Database</p>
</div>

> [!IMPORTANT]
> Under active development. Not production-ready.

InferaDB delivers high-performance, fine-grained authorization at scale. Inspired by [Google Zanzibar](https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/) and built on the [AuthZEN](https://openid.net/wg/authzen/) standard, it achieves sub-millisecond latency with broad interoperability. Its distributed architecture scales horizontally across decentralized networks.

This repository aggregates InferaDB components as git submodules.

# Features

- ReBAC, RBAC, and ABAC support
- No-code visual policy design
- Extensible PBAC/RuBAC policy logic using WebAssembly
- Distributed graph traversal computation
- GPU acceleration for high-complexity workloads
- Decentralized architecture for horizontal scaling
- Blockchain for persistent storage
- Native observability and auditing
- Self-optimizing queries and indexes
- Self-healing and fault-tolerant

# Services

InferaDB comprises four server components:

- [Engine](https://github.com/inferadb/engine) — Authorization decision engine
- [Control](https://github.com/inferadb/control) — Administration plane
- [Ledger](https://github.com/inferadb/ledger) — Blockchain persistence layer
- [Indexer](https://github.com/inferadb/indexer) — Query optimizer and index manager

# Clients

Administration tools:

- [Dashboard](https://github.com/inferadb/dashboard) — Web management frontend
- [CLI](https://github.com/inferadb/cli) — Command-line interface

SDKs:

- [Rust](https://github.com/inferadb/rust)

API definitions:

- [REST (OpenAPI)](https://github.com/inferadb/api)
- [gRPC (Protobuf)](https://github.com/inferadb/proto)

# Pricing

InferaDB is [open source](#license) and free for any use. We offer managed hosting and professional services. [Learn more](https://inferadb.com/pricing).

# Community

Join us on [Discord](https://discord.gg/inferadb) for questions, discussions, and contributions.

# License

Dual-licensed under [MIT](LICENSE-MIT) or [Apache 2.0](LICENSE-APACHE).
