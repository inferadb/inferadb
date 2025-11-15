# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

InferaDB is a distributed inference engine for authorization, designed for fine-grained, low-latency environments. This is a **meta-repository** that orchestrates multiple components via git submodules:

- **server**: Core policy engine (Rust) - Handles IPL parsing, relationship graph traversal, and decision evaluation
- **management**: Management API for orchestrating tenants and configurations
- **dashboard**: Web console for policy design, simulation, and observability (TanStack Start, Hono, React)
- **cli**: Developer tooling for managing schemas, policies, and modules (Rust-based CLI)

The root Makefile delegates all commands to the appropriate submodule (currently `server/`).

## Development Setup

### Initial Setup

```bash
make setup  # Setup development environment. Installs tools using Mise, dependencies, etc.
```

The project uses **mise** for tool management. All commands automatically use mise if available.

### Building

```bash
# Debug build
make build

# Release build (optimized)
make release
```

The binary is `inferadb-server` (located in `server/crates/infera-bin`).

### Documentation & Analysis

```bash
# Generate and open docs
make doc
```

### Development Reset

```bash
# Clean build artifacts
make clean

# Full reset (Docker, volumes, networks, cargo cache, etc.)
make reset
```

## Important Notes

- When working with code or resources under the `server` directory, follow the additional guidance of the `server/CLAUDE.md` file therein.
