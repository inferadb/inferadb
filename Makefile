# Makefile for InferaDB
# Delegates commands to submodule Makefiles (engine/ and control/)
#
# By default, commands run on BOTH the engine and control
# Use engine-<command> or control-<command> for specific targets
#
# Examples:
#   make test              - Run tests in both engine and control
#   make engine-test       - Run tests in engine only
#   make control-test      - Run tests in control only

.PHONY: help setup test test-fdb check format lint audit deny run build release clean reset dev doc coverage bench fix ci
.PHONY: engine-help engine-setup engine-test engine-check engine-format engine-lint engine-run engine-build engine-release engine-clean engine-reset engine-dev engine-doc
.PHONY: control-help control-setup control-test control-check control-format control-lint control-run control-build control-release control-clean control-reset control-dev control-doc
.PHONY: dashboard-help dashboard-setup dashboard-test dashboard-check dashboard-format dashboard-lint dashboard-typecheck dashboard-run dashboard-dev dashboard-build dashboard-release dashboard-clean dashboard-reset
.PHONY: k8s-start k8s-stop k8s-status k8s-update k8s-purge test-e2e

# Default target - show help
.DEFAULT_GOAL := help

# Color codes for output
COLOR_BLUE := \033[36m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m
COLOR_RESET := \033[0m

help: ## Show available commands
	@echo "$(COLOR_BLUE)InferaDB Meta-Repository Commands$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Combined Commands (run on both engine/ and control/):$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make setup$(COLOR_RESET)            - Setup development environment for both projects"
	@echo "  $(COLOR_BLUE)make test$(COLOR_RESET)             - Run tests in both projects"
	@echo "  $(COLOR_BLUE)make check$(COLOR_RESET)            - Run code quality checks in both projects"
	@echo "  $(COLOR_BLUE)make format$(COLOR_RESET)           - Format code in both projects"
	@echo "  $(COLOR_BLUE)make lint$(COLOR_RESET)             - Run linters in both projects"
	@echo "  $(COLOR_BLUE)make build$(COLOR_RESET)            - Build both projects"
	@echo "  $(COLOR_BLUE)make clean$(COLOR_RESET)            - Clean both projects"
	@echo "  $(COLOR_BLUE)make ci$(COLOR_RESET)               - Run CI checks on both projects"
	@echo ""
	@echo "$(COLOR_GREEN)Engine-Specific Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make engine-<command>$(COLOR_RESET)  - Run <command> in engine/ only"
	@echo "  $(COLOR_BLUE)make engine-help$(COLOR_RESET)       - Show engine-specific help"
	@echo ""
	@echo "$(COLOR_GREEN)Control-Specific Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make control-<command>$(COLOR_RESET)  - Run <command> in control/ only"
	@echo "  $(COLOR_BLUE)make control-help$(COLOR_RESET)       - Show control-specific help"
	@echo ""
	@echo "$(COLOR_GREEN)Dashboard Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make dashboard-<command>$(COLOR_RESET)  - Run <command> in dashboard/ only"
	@echo "  $(COLOR_BLUE)make dashboard-help$(COLOR_RESET)       - Show dashboard-specific help"
	@echo ""
	@echo "$(COLOR_GREEN)Kubernetes Environment:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make k8s-start$(COLOR_RESET)         - Start local K8s environment"
	@echo "  $(COLOR_BLUE)make k8s-stop$(COLOR_RESET)          - Stop K8s environment"
	@echo "  $(COLOR_BLUE)make k8s-status$(COLOR_RESET)        - Check K8s environment health"
	@echo "  $(COLOR_BLUE)make k8s-purge$(COLOR_RESET)         - Remove all K8s resources"
	@echo ""
	@echo "$(COLOR_YELLOW)Examples:$(COLOR_RESET)"
	@echo "  make test                  - Run unit tests in both projects"
	@echo "  make test-fdb              - Run FDB integration tests (requires Docker)"
	@echo "  make test-e2e              - Run E2E tests in K8s"
	@echo "  make k8s-start             - Start local K8s environment"
	@echo "  make dashboard-dev         - Start dashboard on http://localhost:5173"
	@echo ""

# ============================================================================
# Combined Commands (runs equivalent engine, control and dashboard commands)
# ============================================================================

setup: ## Setup development environment for both projects
	@echo "$(COLOR_BLUE)🔧 Setting up InferaDB development environment...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Setting up engine/$(COLOR_RESET)"
	@$(MAKE) -C engine setup
	@echo ""
	@echo "$(COLOR_GREEN)Setting up control/$(COLOR_RESET)"
	@$(MAKE) -C control setup
	@echo ""
	@echo "$(COLOR_GREEN)✅ Setup complete for both projects!$(COLOR_RESET)"

test: ## Run tests in both projects
	@echo "$(COLOR_BLUE)🧪 Running tests in both projects...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Testing engine/$(COLOR_RESET)"
	@$(MAKE) -C engine test
	@echo ""
	@echo "$(COLOR_GREEN)Testing control/$(COLOR_RESET)"
	@$(MAKE) -C control test
	@echo ""
	@echo "$(COLOR_GREEN)✅ All tests passed!$(COLOR_RESET)"

test-fdb: ## Run FDB integration tests in both projects (requires Docker)
	@echo "$(COLOR_BLUE)🧪 Running FDB integration tests...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Engine FDB tests$(COLOR_RESET)"
	@$(MAKE) -C engine test-fdb
	@echo ""
	@echo "$(COLOR_GREEN)Control FDB tests$(COLOR_RESET)"
	@$(MAKE) -C control test-fdb
	@echo ""
	@echo "$(COLOR_GREEN)✅ All FDB tests passed!$(COLOR_RESET)"

check: ## Run code quality checks in both projects
	@echo "$(COLOR_BLUE)🔍 Running code quality checks...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Checking engine/$(COLOR_RESET)"
	@$(MAKE) -C engine check
	@echo ""
	@echo "$(COLOR_GREEN)Checking control/$(COLOR_RESET)"
	@$(MAKE) -C control check
	@echo ""
	@echo "$(COLOR_GREEN)✅ All checks passed!$(COLOR_RESET)"

format: ## Format code in both projects
	@echo "$(COLOR_BLUE)📝 Formatting code...$(COLOR_RESET)"
	@$(MAKE) -C engine format
	@$(MAKE) -C control format
	@echo "$(COLOR_GREEN)✅ Formatting complete!$(COLOR_RESET)"

lint: ## Run linters in both projects
	@echo "$(COLOR_BLUE)🔍 Running linters...$(COLOR_RESET)"
	@$(MAKE) -C engine lint
	@$(MAKE) -C control lint

audit: ## Run security audit in both projects
	@echo "$(COLOR_BLUE)🔒 Running security audit...$(COLOR_RESET)"
	@$(MAKE) -C engine audit
	@$(MAKE) -C control audit

build: ## Build both projects
	@echo "$(COLOR_BLUE)🔨 Building both projects...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Building engine/$(COLOR_RESET)"
	@$(MAKE) -C engine build
	@echo ""
	@echo "$(COLOR_GREEN)Building control/$(COLOR_RESET)"
	@$(MAKE) -C control build
	@echo ""
	@echo "$(COLOR_GREEN)✅ Build complete!$(COLOR_RESET)"

release: ## Build release binaries for both projects
	@echo "$(COLOR_BLUE)🚀 Building release binaries...$(COLOR_RESET)"
	@$(MAKE) -C engine release
	@$(MAKE) -C control release

clean: ## Clean both projects
	@echo "$(COLOR_BLUE)🧹 Cleaning both projects...$(COLOR_RESET)"
	@$(MAKE) -C engine clean
	@$(MAKE) -C control clean

reset: ## Full reset of both projects
	@echo "$(COLOR_BLUE)⚠️  Performing full reset...$(COLOR_RESET)"
	@$(MAKE) -C engine reset
	@$(MAKE) -C control reset
	@echo "$(COLOR_GREEN)✅ Reset complete!$(COLOR_RESET)"

doc: ## Generate documentation for both projects
	@echo "$(COLOR_BLUE)📚 Generating documentation...$(COLOR_RESET)"
	@$(MAKE) -C engine doc
	@$(MAKE) -C control doc

ci: ## Run CI checks on both projects
	@echo "$(COLOR_BLUE)🤖 Running CI checks...$(COLOR_RESET)"
	@$(MAKE) -C engine ci
	@$(MAKE) -C control ci

# ============================================================================
# Engine-Specific Commands
# ============================================================================

engine-help: ## Show engine-specific help
	@$(MAKE) -C engine help

engine-setup: ## Setup engine development environment
	@$(MAKE) -C engine setup

engine-test: ## Run engine tests
	@$(MAKE) -C engine test

engine-test-integration: ## Run engine integration tests
	@$(MAKE) -C engine test-integration

engine-test-fdb: ## Run engine FDB tests
	@$(MAKE) -C engine test-fdb

engine-check: ## Run engine code quality checks
	@$(MAKE) -C engine check

engine-format: ## Format engine code
	@$(MAKE) -C engine format

engine-lint: ## Lint engine code
	@$(MAKE) -C engine lint

engine-run: ## Run engine
	@$(MAKE) -C engine run

engine-dev: ## Run engine with auto-reload
	@$(MAKE) -C engine dev

engine-build: ## Build engine
	@$(MAKE) -C engine build

engine-release: ## Build engine release binary
	@$(MAKE) -C engine release

engine-clean: ## Clean engine
	@$(MAKE) -C engine clean

engine-reset: ## Reset engine
	@$(MAKE) -C engine reset

engine-doc: ## Generate engine documentation
	@$(MAKE) -C engine doc

# ============================================================================
# Control-Specific Commands
# ============================================================================

control-help: ## Show Control-specific help
	@$(MAKE) -C control help

control-setup: ## Setup Control development environment
	@$(MAKE) -C control setup

control-test: ## Run Control tests
	@$(MAKE) -C control test

control-test-integration: ## Run Control integration tests
	@$(MAKE) -C control test-integration

control-test-fdb: ## Run Control FDB tests
	@$(MAKE) -C control test-fdb

control-check: ## Run Control code quality checks
	@$(MAKE) -C control check

control-format: ## Format Control code
	@$(MAKE) -C control format

control-lint: ## Lint Control code
	@$(MAKE) -C control lint

control-run: ## Run Control
	@$(MAKE) -C control run

control-dev: ## Run Control with auto-reload
	@$(MAKE) -C control dev

control-build: ## Build Control binary
	@$(MAKE) -C control build

control-release: ## Build Control release binary
	@$(MAKE) -C control release

control-clean: ## Clean Control
	@$(MAKE) -C control clean

control-reset: ## Reset Control
	@$(MAKE) -C control reset

control-doc: ## Generate Control documentation
	@$(MAKE) -C control doc

# ============================================================================
# Dashboard Commands
# ============================================================================

dashboard-help: ## Show dashboard-specific help
	@$(MAKE) -C dashboard help

dashboard-setup: ## Install dashboard dependencies
	@$(MAKE) -C dashboard setup

dashboard-test: ## Run dashboard tests
	@$(MAKE) -C dashboard test

dashboard-check: ## Run lint and typecheck on dashboard
	@$(MAKE) -C dashboard check

dashboard-format: ## Format dashboard code
	@$(MAKE) -C dashboard format

dashboard-lint: ## Lint dashboard code
	@$(MAKE) -C dashboard lint

dashboard-typecheck: ## Type-check dashboard
	@$(MAKE) -C dashboard typecheck

dashboard-run: ## Run dashboard production server
	@$(MAKE) -C dashboard run

dashboard-dev: ## Run dashboard dev server
	@$(MAKE) -C dashboard dev

dashboard-build: ## Build dashboard
	@$(MAKE) -C dashboard build

dashboard-release: ## Build dashboard for production
	@$(MAKE) -C dashboard release

dashboard-clean: ## Clean dashboard build artifacts
	@$(MAKE) -C dashboard clean

dashboard-reset: ## Reset dashboard
	@$(MAKE) -C dashboard reset

# ============================================================================
# Kubernetes Environment
# ============================================================================

k8s-start: ## Start local K8s environment
	@$(MAKE) -C tests start

k8s-stop: ## Stop K8s environment
	@$(MAKE) -C tests stop

k8s-status: ## Check K8s environment health
	@$(MAKE) -C tests status

k8s-update: ## Rebuild and redeploy K8s images
	@$(MAKE) -C tests update

k8s-purge: ## Remove all K8s resources and data
	@$(MAKE) -C tests purge

# ============================================================================
# E2E Tests
# ============================================================================

test-e2e: ## Run E2E integration tests in K8s
	@$(MAKE) -C tests test
