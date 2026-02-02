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
3. **Write clear commit messages** following [Conventional Commits](#commit-message-format)
4. **Ensure all tests pass** before submitting
5. **Update documentation** if your changes affect public APIs or user-facing behavior
6. **Submit a pull request** with a clear description of your changes

### Development Setup

Each repository has its own development setup and workflow. See the repository's [README.md](README.md) for prerequisites, build commands, and development workflow.

## Commit Message Format

InferaDB uses [Conventional Commits](https://www.conventionalcommits.org/) to automate versioning and changelog generation. Every commit message must follow this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type       | Description                                                                             |
| ---------- | --------------------------------------------------------------------------------------- |
| `feat`     | New feature                                                                             |
| `fix`      | Bug fix                                                                                 |
| `docs`     | Documentation only                                                                      |
| `style`    | Formatting, whitespace (no code change)                                                 |
| `refactor` | Code change that neither fixes a bug nor adds a feature                                 |
| `perf`     | Performance improvement                                                                 |
| `test`     | Adding or correcting tests                                                              |
| `build`    | Build system or external dependencies                                                   |
| `ci`       | CI configuration                                                                        |
| `chore`    | Other changes that don't modify src or test                                             |
| `dx`       | Improvements related to Developer Experience                                            |
| `ai`       | Improvements related to agentic tooling                                                 |
| `imp`      | Improevments to the codebase that aren't necessarily a new feature, refactor or bug fix |
| `release`  | Work related to the release pipeline                                                    |

### Breaking Changes

For breaking changes, either:

- Add `!` after the type/scope: `feat(api)!: remove deprecated endpoints`
- Include `BREAKING CHANGE:` in the footer

Breaking changes trigger a **major** version bump.

### Scope

The scope should be the name of the affected module or component:

- `api` — API changes
- `storage` — Storage layer
- `raft` — Raft consensus
- `auth` — Authentication/authorization
- `cli` — CLI interface
- `docker` — Docker/container configuration

### Examples

**Patch release (fix):**

```
fix(storage): handle empty batch writes correctly
```

**Minor release (feature):**

```
feat(api): add batch permission check endpoint
```

**Major release (breaking change):**

```
feat(api)!: rename CheckPermission to Check

BREAKING CHANGE: The CheckPermission RPC has been renamed to Check.
Clients must update their code to use the new method name.
```

**No release (documentation):**

```
docs(readme): add installation instructions for ARM64
```

**Feature with body:**

```
feat(raft): implement leader lease optimization

Reduces read latency by allowing reads on the leader without
a round-trip to followers when the lease is valid.

Closes #123
```

### Pull Request Titles

Since we use **squash merging**, your PR title becomes the commit message. Format your PR title as a conventional commit:

```
feat(scope): description
```

The PR description should contain additional context that will be preserved in the squashed commit body.

## Version Scheme

InferaDB follows [Semantic Versioning](https://semver.org/):

| Release Type | Format                     | Example                   |
| ------------ | -------------------------- | ------------------------- |
| Stable       | `X.Y.Z`                    | `1.2.3`                   |
| Canary       | `X.Y.Z-canary.{run}+{sha}` | `1.2.4-canary.47+abc1234` |
| Nightly      | `X.Y.Z-nightly.{YYYYMMDD}` | `1.2.4-nightly.20260126`  |

- **Stable**: Production releases, triggered by merging release-please PRs
- **Canary**: Pre-release builds on every merge to main, version derived from next planned release
- **Nightly**: Scheduled daily builds at 2am UTC

## Hotfix Releases

Hotfixes address critical bugs in production without including unreleased changes from `main`. Use this process for emergency fixes to a prior release.

### When to Use Hotfix

- Security vulnerabilities in a released version
- Critical bugs blocking production usage
- Data integrity issues requiring immediate patch

### Hotfix Workflow

1. **Create hotfix branch from release tag:**

   ```bash
   git checkout v1.2.0
   git checkout -b hotfix/v1.2.1
   ```

2. **Apply fix commits:**

   ```bash
   # Cherry-pick specific commits or create new fixes
   git cherry-pick <commit-sha>
   # OR create the fix directly
   git commit -m "fix(storage): prevent data corruption on concurrent writes"
   ```

3. **Update version in Cargo.toml:**

   ```bash
   # Update version to the hotfix version
   cargo set-version 1.2.1
   ```

4. **Update CHANGELOG.md:**
   Add a new section at the top:

   ```markdown
   ## [1.2.1] - 2026-01-27

   ### Bug Fixes

   - **storage:** prevent data corruption on concurrent writes
   ```

5. **Push branch and create PR:**

   ```bash
   git push origin hotfix/v1.2.1
   ```

6. **Trigger release manually:**
   After PR review and merge to hotfix branch, trigger the release workflow manually:
   - Go to Actions → Release → Run workflow
   - Select the hotfix branch
   - Enter version: `v1.2.1`

### Release-Please Override

For hotfixes that need release-please automation, use `release-as` in the commit:

```
fix(storage): prevent data corruption

Release-As: 1.2.1
```

This tells release-please to use the specified version instead of computing it from commit history.

### Hotfix Best Practices

- Keep hotfixes minimal—only the critical fix, no refactoring
- Merge the fix back to `main` after the hotfix release
- Document the hotfix in the release notes
- Notify users through appropriate channels (Discord, email list)

## Review Process

1. **Automated Checks**: CI runs tests, linters, formatters, and validates commit messages
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
