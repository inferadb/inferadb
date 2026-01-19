# Contributing to InferaDB

Thank you for your interest in contributing to [InferaDB](https://inferadb.com)! We welcome contributions from the community and are grateful for any help you can provide.

## Code of Conduct

This project and everyone participating in it is governed by the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [open@inferadb.com](mailto:open@inferadb.com).

## How to Contribute

### Reporting Issues

- **Bug Reports**: Search existing issues first to avoid duplicates. Include version information, steps to reproduce, expected vs actual behavior, and relevant logs.
- **Feature Requests**: Describe the use case, proposed solution, and alternatives considered.
- **Security Issues**: Do **not** open public issues for security vulnerabilities. Instead, email [security@inferadb.com](mailto:security@inferadb.com).

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the development workflow** documented in the repository's [README.md](README.md)
3. **Write clear commit messages** following [Conventional Commits](https://www.conventionalcommits.org/)
4. **Ensure all tests pass** before submitting
5. **Update documentation** if your changes affect public APIs or user-facing behavior
6. **Submit a pull request** with a clear description of your changes

### Development Setup

Each repository has its own development setup and workflow. See the repository's [README.md](README.md) for prerequisites, build commands, and development workflow.

### Running Integration Tests

InferaDB includes integration tests that run against real infrastructure. These tests are optional and are skipped by default.

#### Ledger Integration Tests

Tests for the unified `LedgerBackend` storage implementation:

```bash
# Using Docker Compose (recommended)
cd common/crates/inferadb-storage-ledger/docker
./run-integration-tests.sh

# Or manually with a running Ledger server
RUN_LEDGER_INTEGRATION_TESTS=1 \
LEDGER_ENDPOINT=http://localhost:50051 \
cargo test --package inferadb-storage-ledger --test real_ledger_integration
```

#### Engine + Ledger Integration Tests

Tests for the Engine service with Ledger backend:

```bash
cd engine/docker/ledger-integration-tests
./run-tests.sh

# Or manually
RUN_LEDGER_INTEGRATION_TESTS=1 \
LEDGER_ENDPOINT=http://localhost:50051 \
cargo test --package inferadb-engine-api --test ledger_integration --features ledger
```

#### Control + Ledger Integration Tests

Tests for the Control service with Ledger backend:

```bash
cd control/docker/ledger-integration-tests
./run-tests.sh

# Or manually
RUN_LEDGER_INTEGRATION_TESTS=1 \
LEDGER_ENDPOINT=http://localhost:50051 \
cargo test --package inferadb-control-storage --test ledger_integration_tests --features ledger
```

#### Test Script Options

All integration test scripts support these options:

- `--clean`: Clean up Docker volumes and containers
- `--shell`: Start an interactive shell in the test runner container

Environment variables:

- `LEDGER_BUILD=1`: Force rebuild of Ledger Docker image
- `KEEP_RUNNING=1`: Keep Ledger running after tests complete

## Review Process

1. **Automated Checks**: CI will run tests, linters, and formatters
2. **Peer Review**: At least one maintainer will review your contribution
3. **Feedback**: Address any review comments
4. **Approval**: Once approved, a maintainer will merge your contribution

## License

By contributing to [InferaDB](https://github.com/inferadb), you agree that your contributions will be dual-licensed under:

- [Apache License, Version 2.0](LICENSE-APACHE)
- [MIT License](LICENSE-MIT)

## Questions?

If you have questions or need help:

- Join our [Discord server](https://discord.gg/inferadb) to chat with the community
- Email us at [open@inferadb.com](mailto:open@inferadb.com)

Thank you for helping make InferaDB better!
