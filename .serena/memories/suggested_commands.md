# InferaDB Meta-Repository - Suggested Commands

## Git Submodule Operations

```bash
# Clone with all submodules
git clone --recursive https://github.com/inferadb/inferadb

# Initialize submodules after clone
git submodule update --init --recursive

# Update all submodules to latest
git submodule update --remote --merge

# Update specific submodule
git submodule update --remote engine

# Check submodule status
git submodule status

# Pull changes in all submodules
git submodule foreach git pull origin main
```

## Development Commands (from README)

```bash
# One-time setup
make setup

# Start engine with hot-reload
make engine-dev

# Start control plane with hot-reload
make control-dev

# Start dashboard (localhost:5173)
make dashboard-dev

# Build all (debug)
make build

# Run all quality checks (format, lint, audit)
make check

# Run tests
make test

# Show all available commands
make help
```

## Kubernetes Operations

```bash
# Start local K8s stack
make k8s-start

# Check deployment health
make k8s-status

# Stop (preserves data)
make k8s-stop

# Remove all resources
make k8s-purge
```

## Per-Submodule Commands
Each submodule has its own Makefile with similar targets. Navigate to the submodule and use:

```bash
# In any submodule (engine/, control/, etc.)
make help          # List available commands
make setup         # One-time setup
make test          # Run tests
make check         # Format + lint + audit
make dev           # Development server with hot-reload
```

## System Utilities (macOS/Darwin)

```bash
# File operations
ls -la              # List files with details
find . -name "*.rs" # Find files by pattern
tree -L 2           # Directory structure (brew install tree)

# Text search
grep -rn "pattern"  # Search in files
rg "pattern"        # ripgrep (faster, brew install ripgrep)

# Process management
ps aux | grep inferadb
lsof -i :8080       # Check port usage

# Docker (if installed)
docker ps           # Running containers
docker logs <id>    # Container logs
```

## Common Workflows

### Starting Development Environment
```bash
# 1. Ensure submodules are up to date
git submodule update --init --recursive

# 2. Set up development environment
make setup

# 3. Start services (in separate terminals)
make engine-dev     # Terminal 1
make control-dev    # Terminal 2
make dashboard-dev  # Terminal 3
```

### Before Committing
```bash
# In the relevant submodule directory
make check  # Runs format, lint, audit
make test   # Run tests
```
