# Lumos CLI Framework

<p align="center">
    <img src="assets/lumosb&wclear.png" alt="Lumos Logo" width="250">
</p>

<p align="center">
    <strong>A modern CLI framework for Lua</strong><br>
    Build powerful command-line applications with ease
</p>

<p align="center">
    <a href="docs/qs.md">🚀 Quick Start</a> •
    <a href="docs/api.md">📚 API Docs</a> •
    <a href="docs/use.md">💡 Examples</a> •
    <a href="#installation">⚡ Install</a>
</p>

---

**Lumos** (Latin for "light") brings clarity to CLI development in Lua. Inspired by Cobra for Go, it provides everything you need to build professional command-line applications with minimal code and maximum functionality.

## ✨ What Makes Lumos Special

- **🚀 Project Generator** - `lumos new` creates complete CLI projects in seconds
- **🎯 Intuitive API** - Fluent, chainable methods for defining commands and flags
- **🎨 Rich UI Components** - Colors, progress bars, prompts, and tables out of the box
- **🔧 Shell Integration** - Auto-completion, man pages, and documentation generation
- **⚙️ Configuration Management** - JSON and key=value files, environment variables, and more
- **🧪 Test-Ready** - Generated projects include a Busted configuration and a starter test file
- **📦 Minimal Dependencies** - Only requires `luafilesystem`, modular architecture
- **🌍 Cross-Platform** - Linux and macOS fully supported; Windows support is best-effort via WSL or cross-compilation
- **🚀 Portable Bundles** - Create self-contained single-file Lua scripts with `lumos bundle` (requires Lua runtime)
- **📦 Standalone Packages** - Create zero-dependency executables with `lumos package` using a precompiled stub (Linux x86_64 included; other platforms require a matching stub)
- **🔨 Native Builds** - Compile to native binaries with `lumos build` (embeds Lua VM + static linking)
- **🔒 Security Built-in** - Input sanitization, safe file operations, rate limiting
- **📝 Structured Logging** - 5-level logger with child loggers and environment configuration

## 🚀 5-Minute Quick Start

### 📎 TL;DR - Get Started Now

```bash
# Install Lumos from LuaRocks
luarocks install --local lumos

# Create your first CLI app
lumos new hello-world && cd hello-world

# Run it!
lua src/main.lua greet "CLI Master"
# Output: Hello, CLI Master!
```

### 🔍 Step-by-Step Guide

**Step 1: Install Lumos**
```bash
# Install from LuaRocks (recommended)
luarocks install --local lumos

# Add to PATH if needed
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Step 2: Create Your CLI Project**
```bash
lumos new my-awesome-cli
# Follow the interactive prompts
cd my-awesome-cli
```

**Step 3: Test Your CLI**
```bash
lua src/main.lua --help        # See generated help
lua src/main.lua greet World   # Try the sample command
```

**Step 4: Develop & Test**
```bash
make install  # Install test dependencies
make test     # Run the test suite
```

**Step 5: Distribute Your CLI (Optional)**

```bash
# Fast: bundled Lua script (requires Lua on target)
lumos bundle src/main.lua -o dist/myapp

# Zero dependencies: standalone package using a precompiled stub
lumos package src/main.lua -o dist/myapp

# Maximum control: native binary with embedded Lua VM
lumos build src/main.lua -o dist/myapp

./dist/myapp --help
```

🎉 **Congratulations!** You now have a fully functional CLI application with tests, documentation, and shell integration ready to go.

## Example CLI Code

Here's what your generated CLI looks like:

```lua
local lumos = require('lumos')
local color = require('lumos.color')

local app = lumos.new_app({
    name = "my-awesome-cli",
    version = "0.2.1",
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

## ⚡ Installation

### Prerequisites
- Lua 5.1+ or LuaJIT
- LuaRocks >= 3.9

### Option 1: From LuaRocks (Recommended)
```bash
# Install Lumos from LuaRocks
luarocks install --local lumos

# Add to PATH if needed
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Option 2: System-wide Installation
```bash
# Install globally (requires sudo)
sudo luarocks install lumos
```

### Option 3: Development Installation
```bash
# For contributing to Lumos
git clone https://github.com/benoitpetit/lumos.git
cd lumos
luarocks make --local lumos-dev-1.rockspec
```

### Verify Installation
```bash
lumos version
# Should output: Lumos CLI Framework v0.2.1
```

**Note**: The `--local` flag installs Lumos in your user directory (`~/.luarocks/`). For system-wide installation, omit `--local` and use `sudo`.

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
local confirmed = prompt.confirm("Continue?", true)
local choice = prompt.select("Choose", {"apple", "banana"})
```

### Configuration Management
```lua
local config = require('lumos.config')
local core = require('lumos.core')

local settings = config.merge_configs(
    {timeout = 30},              -- defaults
    core.load_config("config.json"),  -- file (JSON or key=value)
    config.load_env("MYAPP"),         -- environment
    ctx.flags                         -- command line
)
```

### Shell Integration
```lua
-- Generate completions
local completion = app:generate_completion("bash")

-- Generate man pages
local manpage = app:generate_manpage()

-- Generate markdown documentation
local docs = app:generate_docs("markdown", "./docs")
```

### Security & Logging
```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

-- Sanitize user input
local safe = security.sanitize_output(user_input)

-- Validate paths
local path, err = security.sanitize_path(user_path)

-- Safe file operations
local ok, err = security.safe_mkdir("./data")
local file, err = security.safe_open("./data/log.txt", "a")

-- Structured logging
logger.info("Action performed", {user = "john", id = 42})
```

### Advanced Prompts
```lua
local prompt = require('lumos.prompt')

-- Numeric input with constraints
local age = prompt.number("Age", 0, 120)

-- Multi-line editor ($EDITOR or notepad.exe on Windows)
local notes = prompt.editor("Notes", "Default text...")

-- Form builder
local profile = prompt.form("Profile", {
    {name = "name", type = "input", required = true},
    {name = "email", type = "input", validate = prompt.validators.email},
    {name = "newsletter", type = "confirm", default = false}
})

-- Wizard
local result = prompt.wizard("Setup", {
    {title = "Profile", fields = {
        {name = "username", type = "input", required = true}
    }},
    {title = "Confirm", fields = {
        {name = "agree", type = "confirm", required = true}
    }}
})
```

### Plugins & Hooks
```lua
-- Register a plugin globally
lumos.use("command", function(cmd, opts)
    cmd:flag("--dry-run", "Simulate without side effects")
end)

-- Or attach to a single command
app:command("deploy", "Deploy app")
    :use(function(cmd, opts)
        cmd:flag("--region", "Target region")
    end)

-- Hooks for setup / teardown
app:command("migrate", "Run migrations")
    :pre_run(function(ctx)
        print("Connecting to database...")
    end)
    :post_run(function(ctx)
        print("Migration complete!")
    end)

-- Global hooks
app:persistent_pre_run(function(ctx)
    logger.info("Starting command", {cmd = ctx.command.name})
end)
```

## Documentation

Complete documentation is available in the `docs/` directory:

- **[Quick Start Guide](docs/qs.md)** - Get running in 5 minutes
- **[CLI Tool Usage](docs/cli.md)** - How to use `lumos new` to create projects
- **[API Reference](docs/api.md)** - Complete framework API documentation
- **[Usage Examples](docs/use.md)** - Real-world CLI examples and patterns
- **[Security Guide](docs/security.md)** - Security features and best practices
- **[Bundling Guide](docs/bundle.md)** - Creating portable single-file executables

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

- **Version:** 0.2.1
- **License:** MIT
- **Lua Versions:** 5.1, 5.2, 5.3, 5.4, LuaJIT
- **Platforms:** Linux, macOS, Windows (WSL)
- **Tests:** 359 passing tests
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
