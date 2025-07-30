# Lumos CLI Framework

<p align="center">
    <img src="assets/lumosb&wclear.png" alt="Lumos Logo" width="250">
</p>

<p align="center">
    <strong>A modern CLI framework for Lua</strong><br>
    Build powerful command-line applications with ease
</p>

<p align="center">
    <a href="docs/qs.md">Quick Start</a> •
    <a href="docs/">Documentation</a> •
    <a href="docs/use.md">Examples</a> •
    <a href="#installation">Installation</a>
</p>

---

**Lumos** (Latin for "light") brings clarity to CLI development in Lua. Inspired by Cobra for Go, it provides everything you need to build professional command-line applications with minimal code and maximum functionality.

## What Makes Lumos Special

- **Project Generator** - `lumos new` creates complete CLI projects in seconds
- **Intuitive API** - Fluent, chainable methods for defining commands and flags
- **Rich UI Components** - Colors, progress bars, prompts, and tables out of the box
- **Shell Integration** - Auto-completion, man pages, and documentation generation
- **Configuration Management** - JSON files, environment variables, and more
- **Test-Ready** - Generated projects include complete test suites

## Quick Start

### For End Users (when Lumos is published on LuaRocks)

```bash
# 1. Install Lumos from LuaRocks
luarocks install --local lumos

# 2. Create your first CLI project
lumos new my-awesome-cli
cd my-awesome-cli

# 3. Test it out
make install  # Install project dependencies
lua src/main.lua greet World
```

### For Developers (using Lumos from source)

```bash
# 1. Clone and install Lumos
git clone https://github.com/benoitpetit/lumos.git
cd lumos
bash scripts/install.sh

# 2. Create a new CLI project
lumos new my-awesome-cli
cd my-awesome-cli

# 3. Test it out
make install  # Install project dependencies
lua src/main.lua greet World
```

**That's it!** You now have a fully functional CLI application.

## Example CLI Code

Here's what your generated CLI looks like:

```lua
local lumos = require('lumos')
local color = require('lumos.color')

local app = lumos.new_app({
    name = "my-awesome-cli",
    version = "0.1.0",
    description = "My awesome CLI application"
})

-- Add a command with arguments and flags
local greet = app:command("greet", "Greet someone")
greet:arg("name", "Name of person to greet")
greet:flag("-u --uppercase", "Use uppercase")
greet:flag("-c --colorful", "Use colors")

greet:action(function(ctx)
    local name = ctx.args[1] or "World"
    local message = "Hello, " .. name .. "!"
    
    if ctx.flags.uppercase then
        message = message:upper()
    end
    
    if ctx.flags.colorful then
        message = color.green(message)
    end
    
    print(message)
    return true
end)

app:run(arg)
```

## Installation

### Prerequisites
- Lua 5.1+ or LuaJIT
- LuaRocks >= 3.9
- Git (for installation from source)

### Option 1: Quick Install (Recommended)
```bash
# Clone and install using the provided script
git clone https://github.com/benoitpetit/lumos.git
cd lumos
bash scripts/install.sh
```

### Option 2: Manual Installation with LuaRocks
```bash
# For development (if you're modifying Lumos)
luarocks make --local lumos-dev-1.rockspec

# For production use
luarocks make --local lumos-0.1.0-1.rockspec
```

### Option 3: From LuaRocks Repository (when published)
```bash
luarocks install --local lumos
```

**Note**: The `--local` flag installs Lumos in your user directory. For system-wide installation, run without `--local` using sudo.

## Key Features

### Commands & Flags
```lua
local deploy = app:command("deploy", "Deploy application")
deploy:arg("environment", "Target environment")  
deploy:flag("-f --force", "Force deployment")
deploy:option("--timeout", "Deployment timeout")
```

### Rich UI Components
```lua
local color = require('lumos.color')
local progress = require('lumos.progress')
local prompt = require('lumos.prompt')

print(color.green("Success!"))
progress.simple(75, 100)
local name = prompt.input("Your name:", "Anonymous")
```

### Configuration Management
```lua
local config = require('lumos.config')

local settings = config.merge_configs(
    {timeout = 30},              -- defaults
    config.load_file("config.json"),  -- file
    config.load_env("MYAPP"),         -- environment
    ctx.flags                         -- command line
)
```

### Shell Integration
```bash
# Generate completions
lumos-app --generate-completion bash > completion.sh

# Generate man pages  
lumos-app --generate-manpage > lumos-app.1

# Generate documentation
lumos-app --generate-docs markdown
```

## Documentation

Complete documentation is available in the `docs/` directory:

- **[Quick Start Guide](docs/qs.md)** - Get running in 5 minutes
- **[CLI Tool Usage](docs/cli.md)** - How to use `lumos new` to create projects
- **[API Reference](docs/api.md)** - Complete framework API documentation
- **[Usage Examples](docs/use.md)** - Real-world CLI examples and patterns
- **[Development Guide](docs/dev.md)** - Local development setup and workflow

## Examples

Explore real CLI applications built with Lumos in our [Usage Examples](docs/use.md):

- **Basic CLI** - Simple file utility with commands and flags
- **Advanced CLI** - Deployment tool with nested subcommands
- **Interactive CLI** - Task manager with prompts and menus
- **Configuration CLI** - External configuration management

## Contributing

We welcome contributions! Here's how to get started:

### Development Setup
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos

# Install for development
luarocks make --local lumos-dev-1.rockspec

# Run tests
busted

# Test CLI generation
./bin/lumos new test-project
cd test-project
make install && make test
```

## Project Status

- **Version:** 0.1.0
- **License:** MIT
- **Lua Versions:** 5.1, 5.2, 5.3, 5.4, LuaJIT
- **Platforms:** Linux, macOS, Windows (WSL)
- **Tests:** 147 passing tests
- **Dependencies:** luafilesystem

## Acknowledgments

- Inspired by [Cobra](https://cobra.dev/) CLI framework for Go
- Follows [POSIX Utility Syntax Guidelines](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
- Built with care for the Lua community

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
    <strong>Lumos</strong> - <em>Bringing light to CLI development in Lua</em>
</p>
