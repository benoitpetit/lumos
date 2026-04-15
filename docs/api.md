# Lumos API Reference

Complete API documentation for the Lumos CLI framework.

## Core API

### `lumos.new_app(config)`

Creates a new CLI application.

**Parameters:**
- `config` (table): Application configuration
  - `name` (string): Application name (required)
  - `version` (string): Version string (optional)
  - `description` (string): Description (optional)

**Returns:** Application instance

```lua
local lumos = require('lumos')
local app = lumos.new_app({
    name = "myapp",
    version = "0.1.0",
    description = "My CLI application"
})
```

### Available Modules

Lumos exports the following modules:

- `lumos.app` - Application builder
- `lumos.core` - Core utilities (argument parsing, config loading)
- `lumos.flags` - Flag parsing
- `lumos.color` - Color output
- `lumos.format` - Text formatting
- `lumos.loader` - Loading animations
- `lumos.progress` - Progress bars
- `lumos.prompt` - User prompts
- `lumos.table` - Table formatting
- `lumos.json` - JSON utilities (full spec support, nested objects, unicode)
- `lumos.config` - Configuration file management
- `lumos.completion` - Shell completion
- `lumos.manpage` - Man page generation
- `lumos.markdown` - Markdown documentation
- `lumos.security` - Input sanitization and validation
- `lumos.logger` - Structured logging
- `lumos.bundle` - Programmatic bundling API
- `lumos.native_build` - Native binary compilation API
- `lumos.package` - Standalone executable packaging API (stub-based)

## Application Methods

### `app:command(name, description)`

Creates a new command.

**Parameters:**
- `name` (string): Command name
- `description` (string): Command description

**Returns:** Command instance

```lua
local deploy = app:command("deploy", "Deploy application")
```

### `app:flag(spec, description)`

Adds a global flag.

**Parameters:**
- `spec` (string): Flag specification (e.g., "-v --verbose")
- `description` (string): Flag description

```lua
app:flag("-v --verbose", "Enable verbose output")
```

### `app:persistent_flag(spec, description)`

Adds a persistent flag inherited by all commands.

```lua
app:persistent_flag("--dry-run", "Show what would be done")
```

### `app:run(args)`

Parses arguments and executes commands.

**Parameters:**
- `args` (table): Command line arguments (usually `arg`)

```lua
app:run(arg)
```

## Command Methods

### `cmd:arg(name, description)`

Adds a positional argument.

```lua
cmd:arg("environment", "Target environment")
```

### `cmd:flag(spec, description)`

Adds a boolean flag.

```lua
cmd:flag("-f --force", "Force operation")
```

### `cmd:option(spec, description)`

Adds a flag that accepts a string value. This is an alias for `cmd:flag_string()`.

```lua
cmd:option("-c --config", "Configuration file")
```

### `cmd:subcommand(name, description)`

Creates a subcommand.

```lua
local subcmd = cmd:subcommand("start", "Start service")
```

### `cmd:alias(name)`

Adds an alias for the command.

```lua
cmd:alias("d")  -- 'deploy' can now be called as 'd'
```

### `cmd:action(function)`

Sets the command action.

```lua
cmd:action(function(ctx)
    -- ctx.args - positional arguments
    -- ctx.flags - flag values
    -- ctx.command - command reference
    -- ctx.parent - parent command (for subcommands)
    return true  -- success
end)
```

## Typed Flags

### `cmd:flag_int(spec, description, min, max)`

Integer flag with validation.

```lua
cmd:flag_int("--port", "Port number", 1024, 65535)
```

### `cmd:flag_string(spec, description)`

String flag (equivalent to `:option()`).

```lua
cmd:flag_string("--name", "Resource name")
```

### `cmd:flag_email(spec, description)`

Email flag with validation.

```lua
cmd:flag_email("--email", "Email address")
```

## Color Module (`lumos.color`)

### Basic Colors

```lua
local color = require('lumos.color')

color.red("Error message")
color.green("Success message")
color.blue("Info message")
color.yellow("Warning message")
color.magenta("Debug message")
color.cyan("System message")
color.white("Normal text")
color.black("Dark text")
```

### Bright Colors

```lua
color.colorize("Bright red text", "bright_red")
color.colorize("Bright green text", "bright_green")
color.colorize("Bright blue text", "bright_blue")
```

### Text Styles (delegated to format module)

```lua
color.bold("Bold text")  -- Uses format.bold internally
color.dim("Dimmed text") -- Uses format.dim internally
```

### Background Colors

```lua
color.colorize("Red background", "bg_red")
color.colorize("Green background", "bg_green")
color.colorize("Blue background", "bg_blue")
```

### Template Formatting

```lua
color.format("{red}Error:{reset} Something went wrong")
color.format("{green}{bold}Success!{reset}")
```

### Color Control

```lua
color.enable()     -- Force enable colors
color.disable()    -- Force disable colors
color.is_enabled() -- Check if colors are enabled
```

### Contextual Helpers

```lua
color.status.success("Done!")
color.status.error("Failed!")
color.status.warning("Caution!")
color.status.info("Note:")

color.log.info("Application started")
color.log.error("Connection failed")
```

## Format Module (`lumos.format`)

The format module handles ANSI text formatting and text transformations.

### Text Styles

```lua
local format = require('lumos.format')

format.bold("Bold text")
format.italic("Italic text")
format.underline("Underlined text")
format.strikethrough("Strikethrough text")
format.dim("Dimmed text")
format.reverse("Reversed text")
format.hidden("Hidden text")
```

### Template Formatting

```lua
format.format("{bold}This is bold{reset} and {italic}this is italic{reset}")
format.format("{underline}Underlined{reset} with {strikethrough}strikethrough{reset}")
```

### Text Truncation

```lua
format.truncate("Very long text that needs truncation", 15)
-- Returns: "Very long te..."

format.truncate("Long text", 10, " [more]")
-- Returns: "Lo [more]"
```

### Word Wrapping

```lua
local lines = format.wrap("This is a long sentence that should be wrapped", 20)
-- Returns: {"This is a long", "sentence that should", "be wrapped"}

for i, line in ipairs(lines) do
    print(i .. ": " .. line)
end
```

### Case Transformations

```lua
format.title_case("hello world")     -- "Hello World"
format.camel_case("hello_world")     -- "helloWorld"
format.snake_case("HelloWorld")      -- "hello_world"
format.kebab_case("HelloWorld")      -- "hello-world"
```

### Format Combining

```lua
-- Combine multiple formats
format.combine("Important text", "bold", "underline")

-- Use functions
format.combine("Styled text", format.italic, format.reverse)
```

### Format Control

```lua
format.enable()     -- Enable formatting
format.disable()    -- Disable formatting
format.is_enabled() -- Check if formatting is enabled
```

## Progress Module (`lumos.progress`)

### Simple Progress

```lua
local progress = require('lumos.progress')

for i = 1, 100 do
    progress.simple(i, 100)
    -- do work
end
```

### Advanced Progress Bar

```lua
local bar = progress.new({
    total = 100,
    width = 50,
    format = "[{bar}] {percentage}% ({current}/{total})",
    fill = "=",
    empty = " ",
    prefix = "Processing: "
})

for i = 1, 100 do
    bar:update(i)
    -- do work
end
```

### Progress Bar Methods

```lua
bar:update(value)     -- Set progress
bar:increment(amount) -- Increment progress
bar:finish()          -- Complete
```

### Colored Progress Bars

```lua
local bar = progress.new({
    total = 100,
    color_fn = function(bar, current, total)
        return progress.color_bar(bar, current, total)
    end
})
```

## Prompt Module (`lumos.prompt`)

### Text Input

```lua
local prompt = require('lumos.prompt')

local name = prompt.input("Name:", "default")
local email = prompt.input("Email:")
```

### Password Input

```lua
local password = prompt.password("Password:")
```

On Windows or systems without `stty`, this falls back to normal text input.

### Confirmation

```lua
local confirmed = prompt.confirm("Continue?", true)
```

### Selection

```lua
local options = {"Option 1", "Option 2", "Option 3"}
local choice, value = prompt.select("Choose:", options, 1)
```

On Windows or without `stty`, falls back to `prompt.simple_select()`.

### Multi-Selection

```lua
local options = {"Option 1", "Option 2", "Option 3"}
local selected = prompt.multiselect("Choose multiple:", options)
-- Returns table of selected items with value and index
-- On Windows/fallback, returns empty table
```

### Input Validation

```lua
local valid, value = prompt.validate(user_input, function(input)
    return tonumber(input) ~= nil
end, "Please enter a valid number")
```

### Predefined Validators

```lua
prompt.validators.email("test@example.com")   -- true
prompt.validators.number("42")                -- true
```

## Loader Module (`lumos.loader`)

### Basic Loading Animation

```lua
local loader = require('lumos.loader')

loader.start("Processing...")
for i = 1, 50 do
    loader.next()  -- Advance animation
    -- do work
end
loader.success()  -- or loader.fail() or loader.stop()
```

### Animation Styles

```lua
loader.start("Loading", "standard")  -- |, /, -, \
loader.start("Loading", "dots")      -- ., .., ...
loader.start("Loading", "bounce")    -- spinning characters
```

## Table Module (`lumos.table`)

### Simple Boxed Lists

```lua
local tbl = require('lumos.table')

local items = {"Item 1", "Item 2", "Item 3"}
print(tbl.boxed(items))
```

### Boxed Tables with Options

```lua
print(tbl.boxed(items, {
    header = "My Items",
    footer = "Total: 3",
    align = "center",  -- "left", "center", "right"
    large = true       -- Adapt to terminal width
}))
```

### Advanced Tables

```lua
local data = {
    {Name = "Alice", Age = 30, Score = 95},
    {Name = "Bob", Age = 25, Score = 87},
    {Name = "Carol", Age = 28, Score = 92}
}

-- Table with borders
print(tbl.create(data, {
    headers = {"Name", "Age", "Score"},
    align = {"left", "right", "center"},
    min_width = 5,
    max_width = 20
}))
```

### Simple Tables (No Borders)

```lua
print(tbl.simple(data, {
    headers = {"Name", "Age", "Score"},
    separator = "  ",  -- Custom column separator
    align = {"left", "right", "center"}
}))
```

### Key-Value Tables

```lua
local config = {
    host = "localhost",
    port = 8080,
    debug = true
}

-- Bordered key-value table
print(tbl.key_value(config))

-- Simple key-value table
print(tbl.key_value(config, {simple = true}))
```

### Custom Borders

```lua
print(tbl.create(data, {
    headers = {"Name", "Age", "Score"},
    border = {
        top_left = "╔", top_right = "╗",
        bottom_left = "╚", bottom_right = "╝",
        horizontal = "═", vertical = "║",
        cross = "╬", top_tee = "╦",
        bottom_tee = "╩", left_tee = "╠", right_tee = "╣"
    }
}))
```

## JSON Module (`lumos.json`)

### Encoding and Decoding

```lua
local json = require('lumos.json')

-- Encode any Lua table to JSON
local json_string = json.encode({name = "John", age = 30, tags = {"dev", "ops"}})
-- {"name":"John","age":30,"tags":["dev","ops"]}

-- Decode JSON string to Lua table
local data = json.decode('{"name":"John","age":30}')

-- Supports nested objects, arrays, unicode escapes, and all standard JSON escapes
local complex = json.decode('{"nested":{"a":[1,2,3]},"unicode":"café"}')
```

**Supported features:**
- Nested objects and arrays of arbitrary depth
- Unicode escapes (`\uXXXX`, surrogate pairs)
- All standard escapes (`\n`, `\t`, `\r`, `\"`, `\\`, `\b`, `\f`, `\/`)
- Numbers (including negative and scientific notation)
- `null`, `true`, `false`
- Strict validation with trailing data detection

## Configuration Module (`lumos.config`)

### Loading Configuration

```lua
local config = require('lumos.config')

-- From JSON or key=value file
local file_config = config.load_file("config.json")

-- From environment variables
local env_config = config.load_env("MYAPP")  -- MYAPP_* variables

-- Merge configurations
local final_config = config.merge_configs(
    {default = "value"},  -- defaults
    file_config,          -- file config
    env_config,           -- environment
    ctx.flags             -- command line
)
```

### Core Configuration Loading

```lua
local config = require('lumos.config')

-- Preferred: use the config module directly
local cfg = config.load_file("app.json")
local cfg2 = config.load_file("app.conf")

-- core.load_config is a convenience alias that delegates to config.load_file
local core = require('lumos.core')
local cfg3 = core.load_config("app.json")  -- equivalent to config.load_file
```

## Security Module (`lumos.security`)

### Input Sanitization

```lua
local security = require('lumos.security')

-- Escape shell arguments
local safe = security.shell_escape(user_input)

-- Sanitize file paths
local path, err = security.sanitize_path(user_path)

-- Sanitize terminal output
local clean = security.sanitize_output(user_input)

-- Validate emails
local valid, err = security.validate_email(email)

-- Validate URLs
local valid, err = security.validate_url(url)

-- Validate integers
local valid, num = security.validate_integer(value, 1, 100)

-- Validate command names
local name, err = security.sanitize_command_name(cmd_name)

-- Check for elevated privileges
if security.is_elevated() then
    print("Warning: running as root")
end

-- Rate limiting
local allowed, err = security.rate_limit("api", 10, 60)
```

### Safe File Operations

```lua
-- Open files safely (prevents writing to /etc, /sys, /proc)
local file, err = security.safe_open(path, "r")

-- Create directories safely
local ok, err = security.safe_mkdir(path)
```

## Logger Module (`lumos.logger`)

### Basic Logging

```lua
local logger = require('lumos.logger')

logger.error("Critical error", {code = 500})
logger.warn("Deprecated feature", {feature = "old_api"})
logger.info("User action", {user = "john"})
logger.debug("Cache miss", {key = "user:123"})
logger.trace("Entry point", {func = "main"})
```

### Configuration

```lua
-- Set level by name or constant
logger.set_level("INFO")
logger.set_level(logger.LEVELS.DEBUG)

-- Redirect to file
logger.set_output("/var/log/myapp.log")

-- Toggle features
logger.set_timestamp(true)
logger.set_context(true)
logger.set_colors(false)

-- Configure from environment (reads LUMOS_LOG_LEVEL, LUMOS_LOG_FILE, etc.)
logger.configure_from_env("LUMOS")
```

### Child Loggers

```lua
local user_logger = logger.child({user = "john", session = "abc123"})
user_logger.info("Action performed")  -- Includes fixed context
```

### Auto-Level Detection

```lua
logger.auto("Error: connection failed")  -- Logs as ERROR
logger.auto("Warning: disk space low")   -- Logs as WARN
logger.auto("Debug info here")           -- Logs as DEBUG
logger.auto("User logged in")            -- Logs as INFO
```

## Bundle Module (`lumos.bundle`)

`lumos.bundle` amalgamates Lua modules into a single portable script. It now uses `package.searchers` (or `package.loaders` on Lua 5.1) for clean module resolution instead of monkey-patching `require`. Results are automatically cached in `.lumos/cache/`.

### Programmatic API

```lua
local bundle = require('lumos.bundle')

-- Create a bundle
local success, err, info = bundle.create({
    entry = "src/main.lua",
    output = "dist/myapp",
    include_lumos = true,
    strip_comments = true
})

if success then
    print("Bundle created: " .. info.output)
    print("Modules: " .. info.modules_count)
    print("Size: " .. info.size .. " bytes")
else
    print("Error: " .. err)
end

-- Analyze dependencies
local modules = bundle.analyze("src/main.lua", {".", "./src"})
for _, mod in ipairs(modules) do
    print(mod.name .. " -> " .. mod.path)
end

-- List Lumos modules
local lumos_mods = bundle.get_lumos_modules()
```

## Native Build Module (`lumos.native_build`)

### Programmatic API

```lua
local native_build = require('lumos.native_build')

local ok, err, info = native_build.create({
    entry = "src/main.lua",
    output = "dist/myapp",
    include_lumos = true,
    strip_comments = true,
    static = true,         -- force static linking
    bytecode = true,       -- compile to bytecode before embedding
    debug_build = true,    -- keep temporary C wrapper
})

if ok then
    print("Binary built: " .. info.output)
    print("Size: " .. info.size .. " bytes")
    print("Compiler: " .. info.compiler)
    if info.static then
        print("Statically linked")
    end
    if info.debug_build then
        print("C wrapper kept at: " .. info.main_c_path)
    end
else
    print("Error: " .. err)
end
```

### Toolchain Detection

```lua
local tc, err = native_build.detect_toolchain({ cc = "musl-gcc" })
if tc then
    print("Compiler: " .. tc.compiler)
    print("Headers: " .. tc.lua_include_dir)
end
```

## Package Module (`lumos.package`)

### Programmatic API

```lua
local pkg = require('lumos.package')

-- List available stub targets
local targets = pkg.list_targets()
for _, t in ipairs(targets) do
    print("Target: " .. t)
end

-- Create a standalone package
local ok, err, info = pkg.create({
    entry = "src/main.lua",
    output = "dist/myapp",
    target = "linux-x86_64",
    include_lumos = true,
    strip_comments = true,
})

if ok then
    print("Package created: " .. info.output)
    print("Target: " .. info.target)
    print("Total size: " .. info.size .. " bytes")
    print("Stub size: " .. info.stub_size .. " bytes")
else
    print("Error: " .. err)
end
```

## Documentation Generation

### Shell Completion

```lua
local completion_script = app:generate_completion("bash")
app:generate_completion("all", "./completions")
```

### Man Pages

```lua
local manpage = app:generate_manpage()
app:generate_manpage(nil, "./man")
```

### Markdown Documentation

```lua
local docs = app:generate_docs("markdown")
app:generate_docs("markdown", "./docs")
```

## Error Handling

Commands should return boolean values:

```lua
cmd:action(function(ctx)
    if not ctx.args[1] then
        print("Error: argument required")
        return false  -- indicates failure
    end
    
    -- do work
    return true  -- indicates success
end)
```

## Context Object

The action function receives a context object:

```lua
{
    args = {...},      -- Positional arguments array
    flags = {...},     -- Flag values table
    command = cmd,     -- Command reference
    parent = cmd       -- Parent command reference (for subcommands)
}
```

## Flag Types

Lumos supports several flag types:

- `boolean`: True/false flags
- `string`: String values
- `int`: Integer values with optional min/max
- `email`: Email addresses with validation

## Persistent Flags

Flags can be inherited by subcommands:

```lua
app:persistent_flag("--verbose", "Enable verbose output")
local cmd = app:command("deploy", "Deploy app")
local subcmd = cmd:subcommand("start", "Start deployment")
-- Both cmd and subcmd inherit --verbose flag
```
