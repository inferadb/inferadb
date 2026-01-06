# InferaDB Meta-Repository - Style & Conventions

## Repository Structure
This meta-repository follows a consistent structure across submodules:
- Each submodule has its own CI/CD in its respective repository
- The meta-repository CI delegates to submodule repositories
- Documentation lives in each submodule + consolidated in `docs/`

## Rust Conventions (engine, control, cli, sdk)

### Rust Version & Toolchain
- Edition: 2021
- MSRV: 1.85
- Formatter: `cargo +nightly fmt` (uses style_edition 2024)

### Naming
```rust
// Types: PascalCase
struct AuthCache {}
enum Decision {}

// Functions/variables: snake_case
fn check_permission() {}
let user_id = "user:alice";

// Constants: SCREAMING_SNAKE_CASE
const MAX_DEPTH: usize = 10;
```

### Error Handling
- Use `thiserror` for custom error types
- Use `anyhow` for application-level errors
- Always provide context in error messages

### Documentation
- Document all public APIs with `///` doc comments
- Include: `# Arguments`, `# Returns`, `# Errors`, `# Example` sections

## TypeScript/React Conventions (dashboard)
- Framework: React with TypeScript
- Bundler: Vite
- Styling: Tailwind CSS
- State: React Query for server state

## Go Conventions (terraform-provider)
- Follow standard Go formatting with `gofmt`
- Use Terraform Plugin Framework patterns
- Error handling with explicit checks

## Commit Message Format
```
type: subject

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation only
- test: Adding/updating tests
- refactor: Code change that neither fixes nor adds
- perf: Performance improvement
- chore: Maintenance tasks
```

## Pull Request Template Checklist
All PRs should ensure:
- [ ] Tests pass locally (`make test`)
- [ ] Code quality checks pass (`make check`)
- [ ] Documentation updated (if applicable)
- [ ] No breaking changes (or clearly documented)

## Branch Strategy
- `main`: Primary development branch
- Each submodule maintains its own branches
- Meta-repository tracks submodule `main` branches

## File Organization
```
inferadb/
├── engine/          # Rust - Authorization engine
├── control/         # Rust - Control plane
├── dashboard/       # TypeScript/React - Web UI
├── cli/             # Rust - CLI tools
├── sdks/rust/       # Rust - Client SDK
├── tests/           # Rust - E2E tests
├── deploy/          # Terraform/Flux - K8s deployment
├── docs/            # Documentation site
├── teapot/          # Rust - TUI framework
├── terraform-provider-inferadb/  # Go - Terraform provider
└── terraform/       # Terraform modules
```
