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
    version = "1.0.0",
    description = "My CLI application"
})
```

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

Adds a flag that accepts a value.

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

### Styles

```lua
color.bold("Bold text")
color.dim("Dimmed text")
color.italic("Italic text")
color.underline("Underlined text")
color.strikethrough("Strikethrough text")
```

### Background Colors

```lua
color.bg_red("Red background")
color.bg_green("Green background")
color.bg_blue("Blue background")
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
bar:reset()           -- Reset to start
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

### Confirmation

```lua
local confirmed = prompt.confirm("Continue?", true)
```

### Selection

```lua
local options = {"Option 1", "Option 2", "Option 3"}
local choice = prompt.select("Choose:", options, 1)
```

### Multi-Selection

```lua
local options = {"Option 1", "Option 2", "Option 3"}
local selected = prompt.multiselect("Choose multiple:", options)
-- Returns table of selected items with value and index
```

### Input Validation

```lua
local valid_input = prompt.input("Port:", nil, function(value)
    local num = tonumber(value)
    return num and num > 0 and num < 65536
end, "Please enter a valid port number")
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

### Tables with Headers

```lua
print(tbl.boxed(items, {
    header = "My Items",
    footer = "Total: 3",
    align = "center"
}))
```

## JSON Module (`lumos.json`)

### Encoding and Decoding

```lua
local json = require('lumos.json')

-- Encode
local json_string = json.encode({name = "John", age = 30})

-- Decode
local data = json.decode('{"name":"John","age":30}')
```

## Configuration Module (`lumos.config`)

### Loading Configuration

```lua
local config = require('lumos.config')

-- From file
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
    app = app         -- Application reference
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
