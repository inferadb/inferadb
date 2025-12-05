# Makefile for InferaDB meta-repository
# Delegates commands to submodule Makefiles (server/ and management/)
#
# By default, commands run on BOTH server and management
# Use server-<command> or management-<command> for specific targets
#
# Examples:
#   make test              - Run tests in both server and management
#   make server-test       - Run tests in server only
#   make management-test   - Run tests in management only

.PHONY: help setup test test-fdb check format lint audit deny run build release clean reset dev doc coverage bench fix ci
.PHONY: server-help server-setup server-test server-check server-format server-lint server-run server-build server-release server-clean server-reset server-dev server-doc
.PHONY: management-help management-setup management-test management-check management-format management-lint management-run management-build management-release management-clean management-reset management-dev management-doc
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
	@echo "$(COLOR_GREEN)Combined Commands (run on both server/ and management/):$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make setup$(COLOR_RESET)            - Setup development environment for both projects"
	@echo "  $(COLOR_BLUE)make test$(COLOR_RESET)             - Run tests in both projects"
	@echo "  $(COLOR_BLUE)make check$(COLOR_RESET)            - Run code quality checks in both projects"
	@echo "  $(COLOR_BLUE)make format$(COLOR_RESET)           - Format code in both projects"
	@echo "  $(COLOR_BLUE)make lint$(COLOR_RESET)             - Run linters in both projects"
	@echo "  $(COLOR_BLUE)make build$(COLOR_RESET)            - Build both projects"
	@echo "  $(COLOR_BLUE)make clean$(COLOR_RESET)            - Clean both projects"
	@echo "  $(COLOR_BLUE)make ci$(COLOR_RESET)               - Run CI checks on both projects"
	@echo ""
	@echo "$(COLOR_GREEN)Server-Specific Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make server-<command>$(COLOR_RESET)  - Run <command> in server/ only"
	@echo "  $(COLOR_BLUE)make server-help$(COLOR_RESET)       - Show server-specific help"
	@echo ""
	@echo "$(COLOR_GREEN)Management-Specific Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)make management-<command>$(COLOR_RESET)  - Run <command> in management/ only"
	@echo "  $(COLOR_BLUE)make management-help$(COLOR_RESET)       - Show management-specific help"
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
# Combined Commands (runs equivalent server, management and dashboard commands)
# ============================================================================

setup: ## Setup development environment for both projects
	@echo "$(COLOR_BLUE)🔧 Setting up InferaDB development environment...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Setting up server/$(COLOR_RESET)"
	@$(MAKE) -C server setup
	@echo ""
	@echo "$(COLOR_GREEN)Setting up management/$(COLOR_RESET)"
	@$(MAKE) -C management setup
	@echo ""
	@echo "$(COLOR_GREEN)✅ Setup complete for both projects!$(COLOR_RESET)"

test: ## Run tests in both projects
	@echo "$(COLOR_BLUE)🧪 Running tests in both projects...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Testing server/$(COLOR_RESET)"
	@$(MAKE) -C server test
	@echo ""
	@echo "$(COLOR_GREEN)Testing management/$(COLOR_RESET)"
	@$(MAKE) -C management test
	@echo ""
	@echo "$(COLOR_GREEN)✅ All tests passed!$(COLOR_RESET)"

test-fdb: ## Run FDB integration tests in both projects (requires Docker)
	@echo "$(COLOR_BLUE)🧪 Running FDB integration tests...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Server FDB tests$(COLOR_RESET)"
	@$(MAKE) -C server test-fdb
	@echo ""
	@echo "$(COLOR_GREEN)Management FDB tests$(COLOR_RESET)"
	@$(MAKE) -C management test-fdb
	@echo ""
	@echo "$(COLOR_GREEN)✅ All FDB tests passed!$(COLOR_RESET)"

check: ## Run code quality checks in both projects
	@echo "$(COLOR_BLUE)🔍 Running code quality checks...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Checking server/$(COLOR_RESET)"
	@$(MAKE) -C server check
	@echo ""
	@echo "$(COLOR_GREEN)Checking management/$(COLOR_RESET)"
	@$(MAKE) -C management check
	@echo ""
	@echo "$(COLOR_GREEN)✅ All checks passed!$(COLOR_RESET)"

format: ## Format code in both projects
	@echo "$(COLOR_BLUE)📝 Formatting code...$(COLOR_RESET)"
	@$(MAKE) -C server format
	@$(MAKE) -C management format
	@echo "$(COLOR_GREEN)✅ Formatting complete!$(COLOR_RESET)"

lint: ## Run linters in both projects
	@echo "$(COLOR_BLUE)🔍 Running linters...$(COLOR_RESET)"
	@$(MAKE) -C server lint
	@$(MAKE) -C management lint

audit: ## Run security audit in both projects
	@echo "$(COLOR_BLUE)🔒 Running security audit...$(COLOR_RESET)"
	@$(MAKE) -C server audit
	@$(MAKE) -C management audit

build: ## Build both projects
	@echo "$(COLOR_BLUE)🔨 Building both projects...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)Building server/$(COLOR_RESET)"
	@$(MAKE) -C server build
	@echo ""
	@echo "$(COLOR_GREEN)Building management/$(COLOR_RESET)"
	@$(MAKE) -C management build
	@echo ""
	@echo "$(COLOR_GREEN)✅ Build complete!$(COLOR_RESET)"

release: ## Build release binaries for both projects
	@echo "$(COLOR_BLUE)🚀 Building release binaries...$(COLOR_RESET)"
	@$(MAKE) -C server release
	@$(MAKE) -C management release

clean: ## Clean both projects
	@echo "$(COLOR_BLUE)🧹 Cleaning both projects...$(COLOR_RESET)"
	@$(MAKE) -C server clean
	@$(MAKE) -C management clean

reset: ## Full reset of both projects
	@echo "$(COLOR_BLUE)⚠️  Performing full reset...$(COLOR_RESET)"
	@$(MAKE) -C server reset
	@$(MAKE) -C management reset
	@echo "$(COLOR_GREEN)✅ Reset complete!$(COLOR_RESET)"

doc: ## Generate documentation for both projects
	@echo "$(COLOR_BLUE)📚 Generating documentation...$(COLOR_RESET)"
	@$(MAKE) -C server doc
	@$(MAKE) -C management doc

ci: ## Run CI checks on both projects
	@echo "$(COLOR_BLUE)🤖 Running CI checks...$(COLOR_RESET)"
	@$(MAKE) -C server ci
	@$(MAKE) -C management ci

# ============================================================================
# Server-Specific Commands
# ============================================================================

server-help: ## Show server-specific help
	@$(MAKE) -C server help

server-setup: ## Setup server development environment
	@$(MAKE) -C server setup

server-test: ## Run server tests
	@$(MAKE) -C server test

server-test-integration: ## Run server integration tests
	@$(MAKE) -C server test-integration

server-test-fdb: ## Run server FDB tests
	@$(MAKE) -C server test-fdb

server-check: ## Run server code quality checks
	@$(MAKE) -C server check

server-format: ## Format server code
	@$(MAKE) -C server format

server-lint: ## Lint server code
	@$(MAKE) -C server lint

server-run: ## Run server
	@$(MAKE) -C server run

server-dev: ## Run server with auto-reload
	@$(MAKE) -C server dev

server-build: ## Build server
	@$(MAKE) -C server build

server-release: ## Build server release binary
	@$(MAKE) -C server release

server-clean: ## Clean server
	@$(MAKE) -C server clean

server-reset: ## Reset server
	@$(MAKE) -C server reset

server-doc: ## Generate server documentation
	@$(MAKE) -C server doc

# ============================================================================
# Management-Specific Commands
# ============================================================================

management-help: ## Show management-specific help
	@$(MAKE) -C management help

management-setup: ## Setup management development environment
	@$(MAKE) -C management setup

management-test: ## Run management tests
	@$(MAKE) -C management test

management-test-integration: ## Run management integration tests
	@$(MAKE) -C management test-integration

management-test-fdb: ## Run management FDB tests
	@$(MAKE) -C management test-fdb

management-check: ## Run management code quality checks
	@$(MAKE) -C management check

management-format: ## Format management code
	@$(MAKE) -C management format

management-lint: ## Lint management code
	@$(MAKE) -C management lint

management-run: ## Run management API
	@$(MAKE) -C management run

management-dev: ## Run management API with auto-reload
	@$(MAKE) -C management dev

management-build: ## Build management API
	@$(MAKE) -C management build

management-release: ## Build management API release binary
	@$(MAKE) -C management release

management-clean: ## Clean management
	@$(MAKE) -C management clean

management-reset: ## Reset management
	@$(MAKE) -C management reset

management-doc: ## Generate management documentation
	@$(MAKE) -C management doc

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
