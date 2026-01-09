<div align="center">
    <p><a href="https://inferadb.com"><img src=".github/inferadb.png" width="100" alt="InferaDB Logo" /></a></p>
    <h1>InferaDB</h1>
    <p>
        <a href="https://discord.gg/inferadb"><img src="https://img.shields.io/badge/Discord-Join%20us-5865F2?logo=discord&logoColor=white" alt="Discord" /></a>
        <a href="#license"><img src="https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg" alt="License" /></a>
    </p>
    <p><i>in·fer·uh·dee·bee</i> (n.) — Authorization, solved.</p>
</div>

> [!IMPORTANT]
> Under active development. Not production-ready.

Authorization shouldn't be hard, or fragile. InferaDB delivers high-performance, fine-grained authorization at scale using hardware-accelerated graph traversal and distributed computing.

Its decentralized architecture supports flexible deployment — run it anywhere, scale it horizontally. Compose policies with a visual builder, or go deeper with custom WebAssembly logic.

InferaDB infers access decisions from your relationships, attributes, policies, and context. Every decision is logged to an immutable ledger — cryptographically signed and replayable.

Inspired by [Google Zanzibar](https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/), the system behind Google Drive, Docs, and YouTube. Built on the emerging [AuthZEN](https://openid.net/wg/authzen/) standard so you're never locked in. Ready to rethink authorization?

# Features

**Flexibility**
- ReBAC, RBAC, and ABAC support
- No-code visual policy design
- Extensible PBAC/RuBAC policy logic via WebAssembly

**Performance**
- Hardware acceleration for high-complexity workloads
- Graph-based permission resolution
- Parallel computation across distributed nodes
- Decentralized architecture for horizontal scaling

**Operations**
- Cryptographically verifiable audit trails
- Native observability and tracing

**Reliability**
- Self-optimizing queries and indexes
- Self-healing and fault-tolerant

# Services

InferaDB has four server components:

- [Engine](https://github.com/inferadb/engine) — Authorization engine
- [Control](https://github.com/inferadb/control) — Administration plane
- [Ledger](https://github.com/inferadb/ledger) — Blockchain persistence layer
- [Indexer](https://github.com/inferadb/indexer) — Query optimizer and index manager

# Clients

Administration tools:

- [Dashboard](https://github.com/inferadb/dashboard) — Web frontend
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
