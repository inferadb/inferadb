# InferaDB Meta-Repository - Task Completion Checklist

## After Making Changes

### If Changes Are in a Submodule

1. **Navigate to the submodule directory**
   ```bash
   cd engine/  # or control/, dashboard/, etc.
   ```

2. **Run quality checks**
   ```bash
   make check  # Runs format, lint, audit
   ```

3. **Run tests**
   ```bash
   make test
   ```

4. **Commit changes in the submodule**
   ```bash
   git add .
   git commit -m "type: description"
   ```

5. **Update submodule reference in meta-repo**
   ```bash
   cd ..  # Back to meta-repo root
   git add engine  # Stage submodule pointer update
   git commit -m "chore: update engine submodule"
   ```

### If Changes Are in Meta-Repository Root

1. **Stage and commit changes**
   ```bash
   git add .
   git commit -m "type: description"
   ```

Note: Meta-repository has minimal CI (submodule CI runs in respective repos).

## Quality Commands by Component

| Component | Format | Lint | Test |
|-----------|--------|------|------|
| Engine | `cargo +nightly fmt` | `cargo clippy` | `cargo nextest run` |
| Control | `cargo +nightly fmt` | `cargo clippy` | `cargo nextest run` |
| CLI | `cargo +nightly fmt` | `cargo clippy` | `cargo nextest run` |
| Dashboard | `npm run format` | `npm run lint` | `npm test` |
| Terraform Provider | `go fmt` | `golangci-lint` | `go test` |
| Rust SDK | `cargo +nightly fmt` | `cargo clippy` | `cargo nextest run` |

## Pre-Push Verification

For Rust submodules, run the full CI simulation:
```bash
make ci  # Runs check + test + deny
```

## Security Considerations

- Never commit secrets or credentials
- Check `.env` files are in `.gitignore`
- Review security audit results from `cargo audit`

## Documentation Updates

If your changes affect:
- Public APIs → Update API documentation
- User-facing behavior → Update relevant README
- Architecture → Update docs/ if significant
