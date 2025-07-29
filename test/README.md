# Lumos Framework Test Demo

This directory contains a comprehensive demonstration of the Lumos CLI framework capabilities.

## Running the Demo

**Important**: All commands should be run from the project root directory, not from inside the test directory.

From the project root:

```bash
lua test/demo-cli.lua --help
```

The scripts are configured to load Lumos from the current directory, so running from the root ensures the proper module path.

## Available Commands

### 1. `greet` - Basic Command Usage
Demonstrates basic command structure, arguments, and flags.

```bash
# Run from project root:
lua test/demo-cli.lua greet Alice
lua test/demo-cli.lua greet Bob --uppercase
lua test/demo-cli.lua greet Charlie --colorful --quiet
```

### 2. `colors` - Color and Styling
Shows ANSI color support and styling capabilities.

```bash
# Run from project root:
lua test/demo-cli.lua colors
lua test/demo-cli.lua colors --all
lua test/demo-cli.lua colors --test
```

### 3. `progress` - Progress Bars
Demonstrates progress bar functionality.

```bash
# Run from project root:
lua test/demo-cli.lua progress
lua test/demo-cli.lua progress --type simple --duration 5
lua test/demo-cli.lua progress --type fancy --duration 2
```

### 4. `interactive` - Interactive Prompts
Shows various types of user prompts and interactions.

```bash
# Run from project root:
lua test/demo-cli.lua interactive
lua test/demo-cli.lua interactive --skip
```

### 5. `info` - Framework Information
Displays information about the Lumos framework.

```bash
# Run from project root:
lua test/demo-cli.lua info
lua test/demo-cli.lua info --version-only
```

### 6. `test` - Feature Testing
Runs tests on various framework components.

```bash
# Run from project root:
lua test/demo-cli.lua test --all
lua test/demo-cli.lua test --parsing
lua test/demo-cli.lua test --colors --progress
```

## Global Flags

- `-h, --help` - Show help information
- `-v, --version` - Show version information
- `--verbose` - Enable verbose output
- `--no-color` - Disable colored output

## Features Demonstrated

✅ **POSIX-compliant argument parsing**
- Short flags (`-h`) and long flags (`--help`)
- Flag combination and value assignment
- Global and command-specific flags

✅ **Fluent command definition API**
- Chained method calls for easy command setup
- Argument and flag definitions
- Action handlers with context

✅ **Automatic help generation**
- Application-level help
- Command-specific help
- Example usage in help text

✅ **Color and styling support**
- ANSI color codes
- Template-based formatting
- Automatic terminal detection
- Color disable options

✅ **Progress bars**
- Simple and fancy progress indicators
- Customizable appearance
- ETA calculation

✅ **Interactive prompts**
- Text input with defaults
- Password input (with echo hiding attempt)
- Confirmation prompts (y/n)
- Selection from lists
- Multi-selection (simplified)

✅ **Robust error handling**
- Unknown command detection
- Flag validation
- Graceful error messages

## Example Session

```bash
# All commands run from project root:

# Show main help
lua test/demo-cli.lua --help

# Greet someone
lua test/demo-cli.lua greet Alice --colorful

# Test colors
lua test/demo-cli.lua colors --all

# Run a progress bar demo
lua test/demo-cli.lua progress --duration 3

# Try interactive prompts
lua test/demo-cli.lua interactive

# Get framework info
lua test/demo-cli.lua info

# Run all tests
lua test/demo-cli.lua test --all
```

## Notes

- The demo requires Lua 5.1+ to run
- Color support depends on terminal capabilities
- Progress bars use `sleep` command for timing
- Interactive prompts work best in a real terminal (not in IDE output)
