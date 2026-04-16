# Lumos CLI Framework Makefile

.PHONY: test test-coverage install build clean doc examples help test-cli check-rockspec

# Resolve the busted binary at recipe execution time (not parse time) so it
# always reflects what is on PATH when make runs.
# Fallback to the user-local LuaRocks path when busted is not in PATH.
BUSTED = $(shell which busted 2>/dev/null || echo $(HOME)/.luarocks/bin/busted)

# Default target
all: test

# Run all tests
test:
	@echo "Running tests..."
	@$(BUSTED)

# Install lumos locally for development
install:
	@echo "Installing Lumos locally for development..."
	@luarocks install luafilesystem --local
	@luarocks install busted --local
	@luarocks make --local lumos-dev-1.rockspec

# Full system installation with path configuration
install-system:
	@echo "Installing Lumos with system integration..."
	@bash scripts/install.sh

# Install and configure for global usage
setup:
	@echo "Setting up Lumos for global usage..."
	@bash scripts/install.sh
	@echo "Setup complete! Restart your terminal or run: source ~/.bashrc"

# Install from rockspec for production
install-prod:
	@echo "Installing Lumos from production rockspec..."
	@luarocks make --local lumos-0.3.2-1.rockspec

# Build documentation
doc:
	@echo "Generating documentation..."
	@mkdir -p docs
	@lua bin/lumos --help > docs/lumos-cli-help.txt
	@echo "Documentation generated in docs/"

# Run examples
examples:
	@echo "Running examples..."
	@cd examples && lua basic_app.lua --help
	@cd examples && lua advanced_features.lua user list

# Build placeholder (delegates to install-prod)
build: install-prod

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf docs/*.txt
	@rm -rf .luarocks/

# Run tests with coverage (requires luacov: luarocks install luacov --local)
test-coverage:
	@echo "Running tests with coverage..."
	@$(BUSTED) --coverage

# Show available targets
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  test-coverage - Run tests with coverage (requires luacov)"
	@echo "  install       - Install locally for development"
	@echo "  install-prod  - Install from rockspec"
	@echo "  doc           - Generate documentation"
	@echo "  examples      - Run example applications"
	@echo "  clean         - Clean build artifacts"
	@echo "  help          - Show this help message"

# Test the lumos command locally (before installation)
test-cli:
	@echo "Testing lumos CLI locally..."
	@cd /tmp && $(PWD)/bin/lumos new testproject || echo "Interactive mode test complete"

# Check rockspec syntax
check-rockspec:
	@echo "Checking rockspec syntax..."
	@luarocks lint lumos-dev-1.rockspec
	@luarocks lint lumos-0.3.2-1.rockspec
