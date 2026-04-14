# Lumos Test Suite

This directory contains the comprehensive test suite for the Lumos CLI framework using the Busted testing framework.

## Overview

The test suite covers all modules of the Lumos framework with unit tests designed to ensure broad code coverage and robust functionality.

## Test Files

- **`init_spec.lua`** - Tests for the main Lumos module and exports
- **`app_spec.lua`** - Tests for application creation and command logic
- **`flags_spec.lua`** - Tests for POSIX flag parsing functionality
- **`flags_advanced_spec.lua`** - Tests for typed flags, validation, and persistent flags
- **`color_spec.lua`** - Tests for color and styling support
- **`format_spec.lua`** - Tests for text formatting utilities
- **`progress_spec.lua`** - Tests for progress bar functionality
- **`prompt_spec.lua`** - Tests for interactive prompts and input validation
- **`table_spec.lua`** - Tests for boxed table formatting
- **`loader_spec.lua`** - Tests for loading animations and spinners
- **`json_spec.lua`** - Tests for JSON encode/decode
- **`config_spec.lua`** - Tests for configuration file loading (JSON and key=value)
- **`logger_spec.lua`** - Tests for structured logging with levels, context, and output redirection
- **`security_spec.lua`** - Tests for shell escaping, path validation, and input sanitization
- **`bundle_spec.lua`** - Tests for application bundling into standalone scripts
- **`core_advanced_spec.lua`** - Tests for argument parsing, command execution, and help generation
- **`completion_spec.lua`** - Tests for shell completion script generation (bash/zsh/fish)
- **`manpage_spec.lua`** - Tests for man page generation
- **`documentation_spec.lua`** - Tests for Markdown documentation generation

## Running Tests

### Prerequisites

Install the test dependencies:

```bash
luarocks install busted
luarocks install luacov  # optional, for coverage reports
```

### Running All Tests

From the project root directory:

```bash
# Run all tests (recommended)
make test

# Run with coverage analysis
make test-coverage
```

### Running Individual Test Files

```bash
busted spec/color_spec.lua
busted spec/logger_spec.lua
```

### Test Configuration

The test suite uses the `.busted` configuration file in the project root, which sets:

- Verbose output
- Correct Lua path configuration (local modules take priority over installed ones)
- Pattern matching for `_spec.lua` files

## Test Structure

Each test file follows the same structure:

```lua
local module = require('lumos.module_name')

describe('Module Name', function()
  before_each(function()
    -- Setup code
  end)

  after_each(function()
    -- Cleanup code
  end)

  describe('feature group', function()
    it('should do something', function()
      -- Test assertions
    end)
  end)
end)
```

## Mocking and Test Utilities

The tests use various mocking techniques:

- **IO Mocking** - Capturing `io.write` / `io.read` for testing output and input
- **Global Print Mocking** - Intercepting `_G.print` to capture CLI output
- **Time Mocking** - Controlling `os.time` for consistent progress bar testing
- **Logger Output Redirection** - Using an in-memory table mock for `logger.set_output`
- **Function Restoration** - Properly restoring original functions in `after_each`

## Test Categories

### Unit Tests
- Test individual functions in isolation
- Mock external dependencies
- Focus on single responsibility

### Integration Tests
- Test module interactions
- Validate full workflow scenarios
- Test CLI argument parsing end-to-end

### Edge Case Tests
- Empty inputs
- Invalid parameters
- Boundary conditions
- Error scenarios

## Contributing Tests

When adding new functionality:

1. Write tests first (TDD approach)
2. Ensure all edge cases are covered
3. Mock external dependencies appropriately
4. Follow existing naming conventions
5. Add descriptive test names
6. Group related tests logically

## Test Results

A successful test run shows:

```
269 successes / 0 failures / 0 errors / 0 pending : X.XXXXX seconds
```

Any failures or errors indicate issues that need to be addressed before merging changes.
