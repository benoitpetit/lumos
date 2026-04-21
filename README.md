# Lumos CLI Framework

<p align="center">
    <img src="assets/lumosb&wclear.png" alt="Lumos Logo" width="250">
</p>

<p align="center">
    <strong>A modern CLI framework for Lua</strong><br>
    Build powerful command-line applications with ease
</p>

<p align="center">
    <a href="docs/qs.md">Quick Start</a> &bull;
    <a href="docs/api.md">API Docs</a> &bull;
    <a href="docs/use.md">Examples</a> &bull;
    <a href="#installation">Install</a>
</p>

---
> 💡 **Lumos is actively developed.** If you encounter a bug or have a feature request, please [open an issue](https://github.com/benoitpetit/lumos/issues/new) — we read everything.


**Lumos** (Latin for "light") brings clarity to CLI development in Lua. Inspired by Cobra for Go, it provides everything you need to build professional command-line applications with minimal code and maximum functionality.

## What Makes Lumos Special

- **Project Generator** - `lumos new` creates complete CLI projects in seconds
- **Intuitive API** - Fluent, chainable methods for defining commands and flags
- **POSIX Compliance** - Supports `--` end-of-options and `-abc` combined short flags
- **Rich UI Components** - Colors, progress bars, prompts, tables out of the box
- **Middleware Chain** - Express-like middleware with auth, dry-run, retry, rate-limiting, and more
- **Advanced Flags** - int, float, array, enum, path, url, email with built-in validation
- **Hidden & Deprecated Flags** - Evolve your CLI without breaking users
- **Shell Integration** - Auto-completion, man pages, and documentation generation
- **Configuration Management** - JSON, TOML, and key=value files, environment variables, built-in cache
- **Test-Ready** - Generated projects include a Busted configuration and a starter test file
- **Minimal Dependencies** - Only requires `luafilesystem`, modular architecture
- **Cross-Platform** - Linux, macOS, and native Windows with automatic detection
- **Portable Bundles** - Create self-contained single-file Lua scripts with `lumos bundle`
- **Standalone Packages** - Create zero-dependency executables with `lumos package`
- **Native Builds** - Compile to native binaries with `lumos build` (embeds Lua VM)
- **Security Built-in** - Input sanitization, safe file operations, rate limiting
- **Structured Logging** - 5-level logger with child loggers and environment configuration
- **Native HTTP Client** - GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS with curl backend
- **Lazy Loading** - On-demand module loading for fast startup (< 30ms)

## 5-Minute Quick Start

### TL;DR

```bash
# Install Lumos from LuaRocks
luarocks install --local lumos

# Create your first CLI app
lumos new hello-world && cd hello-world

# Run it!
lua src/main.lua greet "CLI Master"
# Output: Hello, CLI Master!
```

### Step-by-Step Guide

**Step 1: Install Lumos**
```bash
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

# Zero dependencies: standalone package using a precompiled launcher
lumos package src/main.lua -o dist/myapp

# Target a different OS (e.g. Windows from Linux)
lumos package src/main.lua -o dist/myapp -t windows-x86_64

# See which package targets are available in your installation
lumos package --list-targets

# (Optional) Download missing launchers for known targets
lumos package --sync-runtime --list-targets

# Maximum control: native binary with embedded Lua VM
lumos build src/main.lua -o dist/myapp

# Cross-compile to Windows from Linux
lumos build src/main.lua -o dist/myapp -t windows-x86_64

# For macOS targets from Linux, use package launchers
lumos package src/main.lua -o dist/myapp -t darwin-aarch64

./dist/myapp --help
```

## Example CLI Code

```lua
local lumos = require('lumos')
local color = require('lumos.color')

local app = lumos.new_app({
    name = "my-awesome-cli",
    version = "0.3.6",
    description = "My awesome CLI application"
})

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
    return lumos.success({ greeted = name })
end)

app:run(arg)
```

## Installation

### Prerequisites
- Lua 5.1+ or LuaJIT
- LuaRocks >= 3.8

### Option 1: From LuaRocks (Recommended)
```bash
luarocks install --local lumos

# Add to PATH if needed
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Option 2: System-wide Installation
```bash
sudo luarocks install lumos
```

### Option 3: Development Installation
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos
luarocks make --local lumos-dev-1.rockspec
```

### Verify Installation
```bash
lumos version
# Should output: Lumos CLI Framework v0.3.6
```

## The Runtime & Distribution Model

Lumos ships with a **`runtime/`** directory containing everything needed to bundle, package, or build your CLI without external dependencies:

- **Precompiled launchers** (`runtime/lumos-launcher-<os>-<arch>`): Standalone binaries embedding a Lua interpreter. Used by `lumos package` to create zero-dependency executables without a C compiler.
- **Static libraries & headers** (`runtime/lib/<platform>/liblua.a` + `include/*.h`): Bundled cross-compilation toolchains. `lumos build` prefers these over system libraries to guarantee version compatibility, especially when cross-compiling (e.g. Windows from Linux). They also serve as a fallback if system Lua dev packages are not installed.
- **`launcher.c`**: Source code of the launcher, useful for custom builds or auditing.

All of these are installed automatically when you run `luarocks install lumos` or `luarocks make`.

### Three Ways to Distribute Your CLI

| Method | Command | Output | Needs Lua on target? | Needs C compiler? | Includes native C modules? |
|--------|---------|--------|----------------------|-------------------|---------------------------|
| **Bundle** | `lumos bundle` | Single `.lua` script | ✅ Yes | ❌ No | ❌ No |
| **Package** | `lumos package` | Native executable | ❌ No | ❌ No | ❌ No (fails if detected) |
| **Build** | `lumos build` | Native binary | ❌ No | ✅ Yes | ✅ Yes (`liblua.a` always bundled; optional user C modules like `lfs`/`lpeg` if `.a` found) |

- **`bundle`** is fastest and most portable among Lua users.
- **`package`** gives you a native binary with **no C compiler required** on your build machine, thanks to the precompiled launchers.
- **`build`** gives maximum control: it compiles a native binary embedding the Lua VM, and can statically link C modules like `lfs` or `lpeg` if their `.a` archives are available.

### Cross-Compilation

`lumos package` works from any host to any target because it uses precompiled launchers:

```bash
# From Linux, package for Windows or macOS
lumos package src/main.lua -t windows-x86_64
lumos package src/main.lua -t darwin-aarch64
```

`lumos build` compiles a native binary and requires a matching cross-compiler:

| From → To | Supported | Required Tool |
|-----------|-----------|---------------|
| Linux → Windows | ✅ Yes | `x86_64-w64-mingw32-gcc` (mingw-w64) |
| Linux → Linux ARM64 | ✅ Yes | `aarch64-linux-gnu-gcc` |
| Linux → macOS | ❌ No* | Install [osxcross](https://github.com/tpoechtrager/osxcross) to unblock |
| macOS → Any | ✅ Yes | Xcode Command Line Tools |

\* From Linux, use `lumos package -t darwin-*` instead for macOS targets.

## Key Features

### Commands & Flags
```lua
local deploy = app:command("deploy", "Deploy application")
deploy:arg("environment", "Target environment")
deploy:flag("-f --force", "Force deployment")
deploy:option("--timeout", "Deployment timeout")
```

### Advanced Typed Flags
```lua
cmd:flag_int("-p --port", "Port number", 1, 65535)
cmd:flag_float("-r --rate", "Rate", { min = 0.0, max = 1.0, precision = 2 })
cmd:flag_array("-t --tags", "Tags", { separator = ",", unique = true })
cmd:flag_enum("-l --level", "Log level", {"debug", "info", "warn", "error"})
cmd:flag_path("-c --config", "Config file", { must_exist = true, extensions = {".json", ".toml"} })
cmd:flag_url("--endpoint", "API endpoint", { schemes = {"https"} })
cmd:flag_email("--notify", "Notification email")
```

### Combined Short Flags (POSIX)
```bash
myapp deploy -fvt production
# Equivalent to: myapp deploy -f -v -t production
```

### End-of-Options Delimiter
```bash
myapp rm -- -file-starting-with-dash
# Treats -file-starting-with-dash as a positional argument, not a flag
```

### Mutually Exclusive Flags
```lua
cmd:flag_string("-f --file", "Input file")
cmd:flag_string("-u --url", "Input URL")
cmd:mutex_group("input", {"file", "url"}, { required = true })
```

### Hidden & Deprecated Flags
```lua
-- Hide a command from help (visible only with LUMOS_DEBUG=1)
cmd:hidden(true)

-- Mark a flag as deprecated
cmd:flag("--legacy-mode", "Old mode")
    :deprecated("Use --modern-mode instead")
```

### Typed Errors
```lua
cmd:action(function(ctx)
    if not file_exists(ctx.flags.config) then
        return lumos.new_error("CONFIG_ERROR", "Config file not found", {
            path = ctx.flags.config,
            suggestion = "Create it with 'lumos init'"
        })
    end
    return lumos.success({ deployed = true })
end)
```

### Middleware
```lua
app:use(lumos.middleware.builtin.logger())
app:use(lumos.middleware.builtin.dry_run())
app:use(lumos.middleware.builtin.verbosity())  -- Standard -v / -vv / -vvv

app:command("deploy", "Deploy")
    :use(lumos.middleware.builtin.auth({ env_var = "API_KEY" }))
    :use(lumos.middleware.builtin.confirm({ message = "Deploy to production?" }))
    :use(lumos.middleware.builtin.rate_limit({ max_requests = 10, window_seconds = 60 }))
    :use(lumos.middleware.builtin.retry({ max_attempts = 3, backoff = "exponential" }))
    :action(function(ctx) ... end)
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

### Cross-Platform Detection
```lua
local platform = require('lumos.platform')
print(platform.name())        -- "linux", "macos", "windows"
print(platform.arch())        -- "amd64", "arm64"
platform.supports_colors()    -- boolean
platform.is_interactive()     -- boolean
platform.is_piped()           -- boolean (auto-disables colors)
```

### Configuration Management
```lua
local config = require('lumos.config')
local core = require('lumos.core')

-- Supports JSON, TOML, and key=value files
local settings = config.merge_configs(
    {timeout = 30},                   -- defaults
    core.load_config("config.toml"),  -- file (JSON, TOML, or key=value)
    config.load_env("MYAPP"),         -- environment variables
    ctx.flags                         -- command line
)

-- With in-memory cache
local cached = config.load_file_cached("config.json")
```

### Integrated Profiling
```lua
local profiler = require('lumos.profiler')
profiler.enable()
profiler.start("heavy_task")
-- ... code ...
profiler.stop("heavy_task")
profiler.report()
```

### Minimal Bundles (Tree-Shaking)
```lua
local bundle = require('lumos.bundle')
bundle.minimal("src/main.lua", "dist/myapp.lua", { minify = true })
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

local safe = security.sanitize_output(user_input)
local path, err = security.sanitize_path(user_path)
local ok, err = security.safe_mkdir("./data")

logger.info("Action performed", {user = "john", id = 42})
```

### Native HTTP Client
```lua
local http = require('lumos.http')

-- GET with query parameters
local resp, err = http.get("https://api.example.com/users", {
    query = {page = "1", limit = "10"}
})

-- POST with JSON body (auto-encoded)
local resp, err = http.post("https://api.example.com/users", {
    body = {name = "Alice", email = "alice@example.com"},
    headers = {["X-Request-ID"] = "abc123"}
})

-- Authenticated request
local resp, err = http.put("https://api.example.com/users/1", {
    body = {name = "Bob"},
    auth = {bearer = "my_api_token"},
    timeout = 10
})

-- Response helpers
if resp and resp.ok then
    local data = resp.json()
    print(data.id)
end
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

### Output Format Control
```bash
# Get structured JSON output
myapp info --format=json
# or
myapp info --json
```

### Plugins & Hooks
```lua
-- Register a plugin globally on the app
lumos.use(app, function(app, opts)
    app:flag("--dry-run", "Simulate without side effects")
end)

-- Or attach to a single command
app:command("deploy", "Deploy app")
    :plugin(function(cmd, opts)
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

### No-Args-Is-Help
```lua
local app = lumos.new_app({
    name = "myapp",
    no_args_is_help = true  -- Shows help instead of error when no subcommand given
})
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

Explore real CLI applications built with Lumos in our [Usage Examples](docs/use.md).

## Contributing

We welcome contributions!

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

- **Version:** 0.3.6
- **License:** MIT
- **Lua Versions:** 5.1, 5.2, 5.3, 5.4, LuaJIT
- **Platforms:** Linux, macOS, Windows (native)
- **Tests:** 455 passing tests
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
