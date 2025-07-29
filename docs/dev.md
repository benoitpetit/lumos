# Lumos Local Development Guide

This guide covers how to set up and work with Lumos for local development.

## Prerequisites

Before starting, ensure you have:
- Lua 5.1 or later (or LuaJIT)
- LuaRocks package manager
- Git

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos
```

### 2. Install Dependencies

```bash
# Install required dependencies
luarocks install --local luafilesystem
luarocks install --local busted  # For testing
```

### 3. Install Lumos for Development

```bash
# Install using the development rockspec
luarocks make --local lumos-dev-1.rockspec
```

This installs:
- All Lumos modules in `~/.luarocks/share/lua/5.1/lumos/`
- The `lumos` CLI binary in `~/.luarocks/bin/lumos`
- Dependencies if not already present

### 4. Configure Your Shell

Add LuaRocks bin directory to your PATH:

```bash
# For Bash
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# For Zsh
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# For Fish
echo 'set -gx PATH $HOME/.luarocks/bin $PATH' >> ~/.config/fish/config.fish
```

### 5. Verify Installation

```bash
# Check Lumos CLI is available
lumos version

# Should output:
# Lumos CLI Framework v1.0.0
# A modern CLI framework for Lua
# https://github.com/benoitpetit/lumos
```

## Development Workflow

### Running Tests

```bash
# Run all tests
make test
# or directly
busted

# Run tests with coverage
busted --coverage
```

### Testing the CLI Locally

You can test the CLI without installation:

```bash
# From the project root
lua bin/lumos version
lua bin/lumos new mytest

# Test CLI generation
lua bin/lumos new testproject
cd testproject
make install && make test
```

### Making Changes

When you modify the Lumos source code:

1. **For module changes** (lumos/*.lua):
   ```bash
   # Reinstall to pick up changes
   luarocks make --local lumos-dev-1.rockspec
   ```

2. **For CLI changes** (bin/lumos):
   ```bash
   # Reinstall to update the binary
   luarocks make --local lumos-dev-1.rockspec
   ```

3. **For tests**:
   ```bash
   # Just run tests - no reinstall needed
   busted
   ```

### Working with Examples

```bash
# Test examples work with your changes
make examples

# Test specific examples
cd examples
lua basic_app.lua --help
lua advanced_features.lua user list
```

## Development Tools

### Makefile Targets

The project includes helpful Makefile targets:

```bash
make test           # Run all tests
make install        # Install for development
make examples       # Run example applications
make doc            # Generate documentation
make clean          # Clean build artifacts
make test-cli       # Test CLI generation
make check-rockspec # Validate rockspec files
```

### Directory Structure

```
lumos/
├── lumos/              # Core framework modules
│   ├── init.lua        # Main entry point
│   ├── app.lua         # Application builder
│   ├── core.lua        # Core functionality
│   ├── flags.lua       # Flag parsing
│   ├── color.lua       # Color output
│   ├── prompt.lua      # Interactive prompts
│   ├── progress.lua    # Progress bars
│   └── ...
├── bin/
│   └── lumos           # CLI generator script
├── examples/           # Example applications
├── spec/               # Test specifications
├── docs/               # Documentation
├── scripts/            # Utility scripts
└── *.rockspec          # Package specifications
```

## Debugging

### CLI Issues

If the CLI doesn't work:

```bash
# Test local CLI directly
lua bin/lumos version

# Check if modules are found
lua -e "package.path='./?.lua;./?/init.lua;'..package.path; print(require('lumos').version)"
```

### Module Loading Issues

```bash
# Check Lua path
lua -e "print(package.path)"

# Test module loading
lua -e "print(require('lumos.color').red('test'))"
```

### Installation Issues

```bash
# Remove and reinstall
luarocks remove --local lumos
luarocks make --local lumos-dev-1.rockspec

# Check installation
luarocks list --local
```

## Testing Changes

### Unit Tests

```bash
# Run specific test files
busted spec/app_spec.lua
busted spec/color_spec.lua

# Run with verbose output
busted --verbose
```

### Integration Tests

```bash
# Test CLI generation end-to-end
./bin/lumos new integration-test
cd integration-test
make install
make test
lua src/main.lua greet "Test"
```

### Example Validation

```bash
# Ensure examples still work
cd examples
for file in *.lua; do
    echo "Testing $file"
    lua "$file" --help > /dev/null || echo "Failed: $file"
done
```

## Publishing Workflow

When ready to publish:

1. **Update version numbers**:
   - `VERSION` file
   - `lumos/init.lua`
   - Create new production rockspec: `lumos-X.Y.Z-1.rockspec`

2. **Test production build**:
   ```bash
   luarocks make --local lumos-1.0.0-1.rockspec
   ```

3. **Run full test suite**:
   ```bash
   make test
   make examples
   ```

4. **Publish to LuaRocks**:
   ```bash
   luarocks upload lumos-1.0.0-1.rockspec
   ```

## Troubleshooting

### Common Issues

**"Module 'lumos' not found"**
- Ensure you've run `luarocks make --local lumos-dev-1.rockspec`
- Check that `~/.luarocks/share/lua/5.1` is in your Lua path

**"Command 'lumos' not found"**
- Add `~/.luarocks/bin` to your PATH
- Or use the full path: `~/.luarocks/bin/lumos`

**Tests failing after changes**
- Reinstall: `luarocks make --local lumos-dev-1.rockspec`
- Check for syntax errors in modified files

**Examples not working**
- Verify package paths in example files are correct
- Ensure examples use `../?.lua;../?/init.lua` path

### Development Tips

1. **Use local paths for testing**: Test changes directly with `lua bin/lumos` before reinstalling
2. **Frequent testing**: Run tests after each significant change
3. **Check examples**: Always verify examples work after core changes
4. **Version consistency**: Keep version numbers in sync across all files
5. **Clean installs**: Remove and reinstall when making major changes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following this development guide
4. Add tests for new functionality
5. Ensure all tests pass
6. Update documentation if needed
7. Submit a pull request

For more information, see the main [README.md](../README.md) and [API documentation](api.md).
