# Lumos Test Suite

This directory contains the comprehensive test suite for the Lumos CLI framework using the Busted testing framework.

## Overview

The test suite covers all modules of the Lumos framework with unit tests designed to ensure 100% code coverage and robust functionality.

## Test Files

- **`init_spec.lua`** - Tests for the main Lumos module and exports
- **`app_spec.lua`** - Tests for application creation and command logic
- **`flags_spec.lua`** - Tests for POSIX flag parsing functionality
- **`color_spec.lua`** - Tests for color and styling support
- **`progress_spec.lua`** - Tests for progress bar functionality
- **`prompt_spec.lua`** - Tests for interactive prompts and input validation
- **`table_spec.lua`** - Tests for boxed table formatting
- **`loader_spec.lua`** - Tests for loading animations and spinners

## Running Tests

### Prerequisites

Install the test dependencies:

```bash
luarocks install busted
luarocks install luacov
```

### Running All Tests

From the project root directory:

```bash
# Run all tests
busted spec/

# Run tests with verbose output
busted --verbose spec/

# Run tests with coverage analysis
busted --coverage spec/
```

### Running Individual Test Files

```bash
# Test a specific module
busted spec/color_spec.lua
busted spec/progress_spec.lua
```

### Test Configuration

The test suite uses the `.busted` configuration file in the project root, which includes:

- Verbose output
- Coverage analysis
- Pattern matching for `_spec.lua` files
- Correct Lua path configuration

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

- **IO Mocking** - Capturing `io.write` and `io.read` for testing output and input
- **Time Mocking** - Controlling `os.time` for consistent progress bar testing
- **Function Restoration** - Properly restoring original functions after each test

## Coverage Goals

The test suite aims for:

- **100% line coverage** across all modules
- **100% branch coverage** for conditional logic
- **Comprehensive edge case testing**
- **Error condition validation**

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

A successful test run should show:

```
●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
69 successes / 0 failures / 0 errors / 0 pending : X.XXXXX seconds
```

Any failures or errors indicate issues that need to be addressed before merging changes.
