# AGENTS.md

InferaDB makes fine-grained access control fast and scalable with hardware-accelerated distributed graph traversal and a decentralized architecture that runs anywhere. Compose policies visually or go deeper with custom WebAssembly logic. Every decision is logged to a cryptographically signed, immutable ledger. [Zanzibar](https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/)-inspired. [AuthZEN](https://openid.net/wg/authzen/)-compliant. Zero lock-in.

## Critical Constraints

**These rules are non-negotiable:**

- No `unsafe` code
- No `.unwrap()` — use snafu `.context()`
- No `panic!`, `todo!()`, `unimplemented!()`
- No placeholder stubs — fully implement or don't write
- No TODO/FIXME/HACK comments
- No backwards compatibility shims or feature flags
- Write tests before implementation, target 90%+ coverage

## Serena (MCP Server)

Activate at session start: `mcp__plugin_serena_serena__activate_project`

**Use semantic tools, not file operations:**

| Task                 | Use                                            | Not                  |
| -------------------- | ---------------------------------------------- | -------------------- |
| Understand file      | `get_symbols_overview`                         | Reading entire file  |
| Find function/struct | `find_symbol` with pattern                     | Grep/glob            |
| Find usages          | `find_referencing_symbols`                     | Grep for text        |
| Edit function        | `replace_symbol_body`                          | Raw text replacement |
| Add code             | `insert_after_symbol` / `insert_before_symbol` | Line number editing  |
| Search patterns      | `search_for_pattern` with `relative_path`      | Global grep          |

**Symbol paths:** `ClassName/method_name` format. Patterns: `Foo` (any), `Foo/bar` (nested), `/Foo/bar` (exact root path).

**Workflow:**

1. `get_symbols_overview` first
2. `find_symbol` with `depth=1` to see methods without bodies
3. `include_body=True` only when needed
4. `find_referencing_symbols` before any refactor

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       Client Applications                         │
│                    (Dashboard, CLI, SDKs)                         │
└───────────────────────────┬──────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│         Engine          │     │        Control          │
│   Authorization checks  │     │   User/org management   │
│   Policy evaluation     │◄────│   Token issuance        │
│   Graph traversal       │     │   Vault access control  │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            │    ┌───────────────────────┐  │
            └────►   inferadb-storage    ◄──┘
                 │   (Unified Backend)   │
                 └───────────┬───────────┘
                             │
                 ┌───────────┴───────────┐
                 ▼                       ▼
         ┌─────────────┐         ┌─────────────┐
         │   Memory    │         │   Ledger    │
         │  (testing)  │         │(production) │
         └─────────────┘         └──────┬──────┘
                                        │
                                        ▼
                                ┌─────────────┐
                                │   Ledger    │
                                │   Cluster   │
                                └─────────────┘
```

## Error Handling

Use `snafu` with backtraces. Propagate with `?`. No `.unwrap()`.

## Code Quality

**Linting:** `cargo +1.85 clippy --all-targets -- -D warnings`

**Formatting:** `cargo +nightly fmt` (nightly required)

**Doc comments:** Use ```` ```no_run ```` for code examples — `cargo test` skips execution; `cargo doc` validates syntax.

**Markdown:** Be concise, no filler words, kebab-case filenames, specify language in code blocks. Prefer showing to telling.

**Writing:** No filler (very, really, basically), no wordiness (in order to → to, due to the fact → because), active voice, specific language.
