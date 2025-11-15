# Makefile for InferaDB meta-repository
# Delegates commands to submodule Makefiles

.PHONY: help setup test test-integration test-leaks test-load test-fdb test-aws test-gcp test-azure check format lint audit deny run build release clean reset dev doc coverage bench fix ci

# Default target - show help
.DEFAULT_GOAL := help

help: ## Show available commands
	@echo "InferaDB Meta-Repository Commands"
	@echo ""
	@echo "All commands delegate to the server/ submodule Makefile"
	@echo ""
	@$(MAKE) -C server help

# Development Setup
setup: ## Setup development environment
	@echo "🔧 Setting up InferaDB development environment..."
	@$(MAKE) -C server setup

build: ## Build the project
	@echo "🔧 Building InferaDB..."
	@$(MAKE) -C server build

run: ## Run the project
	@echo "🔧 Running InferaDB..."
	@$(MAKE) -C server run

doc: ## Generate documentation
	@echo "🔧 Generating documentation..."
	@$(MAKE) -C server doc

clean: ## Clean the project
	@echo "🔧 Cleaning InferaDB..."
	@$(MAKE) -C server clean

reset: ## Reset the project
	@echo "🔧 Resetting InferaDB..."
	@$(MAKE) -C server reset
