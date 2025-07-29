# Lumos CLI Framework

**Lumos** (Latin for "light") is a modern CLI framework for Lua, inspired by Cobra for Go. It brings clarity and simplicity to command-line application development with an elegant, fluent API.

## 🌟 Key Features

- ✅ **POSIX-compliant argument parsing** - Short (`-h`) and long (`--help`) flags
- ✅ **Fluent command definition API** - Chainable method calls for easy setup
- ✅ **Automatic help generation** - Beautiful help text with examples
- ✅ **Color and styling support** - ANSI colors with terminal detection
- ✅ **Progress bars** - Simple and fancy progress indicators
- ✅ **Interactive prompts** - Text input, confirmations, selections
- ✅ **Global and local flags** - Cascade flags from parent to child commands
- ✅ **Robust error handling** - Clear error messages and validation

## 📦 Installation

### Requirements
- Lua 5.1+ or LuaJIT
- LuaRocks package manager
- Unix-like system (Linux, macOS) or Windows

### Install from LuaRocks

```bash
# Install Lumos from LuaRocks
luarocks install lumos
```

### Use in your projects

```lua
-- Simply require Lumos (no path setup needed with LuaRocks)
local lumos = require('lumos')
local color = require('lumos.color')
local prompt = require('lumos.prompt')
local progress = require('lumos.progress')
```

### Development Installation

For development or to try the latest version:

```bash
# Clone and install locally
git clone https://github.com/yourusername/lumos.git
cd lumos
luarocks make lumos-0.1.0-1.rockspec
```

### Manual Installation (without LuaRocks)

If you can't use LuaRocks:

```bash
git clone https://github.com/yourusername/lumos.git
cd lumos

# Add to your Lua scripts:
# package.path = package.path .. ";/path/to/lumos/?.lua;/path/to/lumos/?/init.lua"
```



## 📋 Tableaux encadrés (Table)

Lumos permet de créer facilement des tableaux encadrés pour afficher des listes ou des cadres dans votre CLI :

```lua
local tbl = require('lumos.table')
local items = {"Un", "Deux", "Trois"}
print(tbl.boxed(items))
--[[
Affiche :
┌───────┐
│ Un    │
│ Deux  │
│ Trois │
└───────┘
]]
```

Voir `test/table.lua` pour plus d'exemples.

## 🚀 Quick Example

After installing with `luarocks install lumos`:

```lua
#!/usr/bin/env lua

-- No path setup needed with LuaRocks!
local lumos = require('lumos')
local color = require('lumos.color')

-- Create application
local app = lumos.new_app({
    name = "myapp",
    version = "1.0.0",
    description = "My awesome CLI application"
})

-- Add global flags
app:flag("-v --verbose", "Enable verbose output")

-- Define a command
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
        message = color.format("{green}" .. message .. "{reset}")
    end
    
    print(message)
    return true
end)

-- Run the app
app:run(arg)
```

## 📚 Complete API Reference

### Application (`lumos.new_app`)

#### Creating an Application
```lua
local app = lumos.new_app({
    name = "myapp",           -- Application name (required)
    version = "1.0.0",        -- Version string (optional)
    description = "My app"    -- Description (optional)
})
```

#### Application Methods
- `app:command(name, description)` - Create a new command
- `app:flag(spec, description)` - Add a global flag
- `app:run(args)` - Parse arguments and execute commands

### Commands

#### Creating Commands
```lua
local cmd = app:command("commandname", "Command description")
```

#### Command Methods
- `cmd:arg(name, description)` - Add positional argument
- `cmd:flag(spec, description)` - Add boolean flag
- `cmd:option(spec, description)` - Add flag with value
- `cmd:action(function)` - Set command action

#### Flag Specifications
```lua
-- Boolean flags
cmd:flag("-v --verbose", "Enable verbose output")
cmd:flag("--debug", "Enable debug mode")
cmd:flag("-q", "Quiet mode")

-- Options (flags with values)
cmd:option("-o --output", "Output file")
cmd:option("--format", "Output format")
```

#### Action Context
The action function receives a context object:
```lua
cmd:action(function(ctx)
    -- ctx.args - Array of positional arguments
    -- ctx.flags - Table of flag values
    -- ctx.command - Reference to command object
    
    local name = ctx.args[1]
    if ctx.flags.verbose then
        print("Verbose mode enabled")
    end
    
    return true -- Return true for success, false for error
end)
```

### Colors and Styling (`lumos.color`)

#### Basic Colors
```lua
local color = require('lumos.color')

print(color.red("Red text"))
print(color.green("Green text"))
print(color.blue("Blue text"))
print(color.yellow("Yellow text"))
print(color.magenta("Magenta text"))
print(color.cyan("Cyan text"))
print(color.bold("Bold text"))
print(color.dim("Dim text"))
```

#### Template Formatting
```lua
print(color.format("{red}Error:{reset} Something went wrong"))
print(color.format("{green}{bold}Success!{reset} Operation completed"))
print(color.format("{blue}Info:{reset} {dim}Additional details{reset}"))
```

#### Available Colors
- Basic: `red`, `green`, `blue`, `yellow`, `magenta`, `cyan`, `black`, `white`
- Bright: `bright_red`, `bright_green`, etc.
- Background: `bg_red`, `bg_green`, etc.
- Styles: `bold`, `dim`, `italic`, `underline`, `strikethrough`
- Special: `reset` (clears all formatting)

#### Color Control
```lua
color.enable()          -- Force enable colors
color.disable()         -- Force disable colors
color.is_enabled()      -- Check if colors are enabled
```

### Progress Bars (`lumos.progress`)

#### Simple Progress
```lua
local progress = require('lumos.progress')

for i = 1, 100 do
    progress.simple(i, 100)
    -- Do work here
end
```

#### Advanced Progress Bar
```lua
local bar = progress.new({
    total = 100,
    width = 50,
    format = "[{bar}] {percentage}% ({current}/{total}){eta}",
    fill = "█",
    empty = "░",
    prefix = "Processing: ",
    suffix = " Complete"
})

for i = 1, 100 do
    bar:update(i)  -- or bar:increment()
    -- Do work here
end
```

### Interactive Prompts (`lumos.prompt`)

#### Text Input
```lua
local prompt = require('lumos.prompt')

local name = prompt.input("What's your name?", "Anonymous")
local email = prompt.input("Email address:")
```

#### Password Input
```lua
local password = prompt.password("Enter password")
```

#### Confirmation
```lua
local confirm = prompt.confirm("Are you sure?", false)
local proceed = prompt.confirm("Continue?", true) -- Default to yes
```

#### Selection
```lua
local options = {"Option 1", "Option 2", "Option 3"}
local choice, value = prompt.select("Choose an option:", options, 1)
print("You chose: " .. value)
```

#### Validation
```lua
local valid, result = prompt.validate(input, function(val)
    return #val > 3
end, "Input must be longer than 3 characters")
```

## 🧪 Testing and Examples

### Running Examples

All commands should be run from the project root directory:

#### Basic Hello Example
```bash
# Show help
lua examples/hello.lua --help

# Greet someone
lua examples/hello.lua greet Alice
lua examples/hello.lua greet Bob --uppercase
lua examples/hello.lua goodbye Charlie --formal
```

#### Comprehensive Demo
```bash
# Show all available commands
lua test/demo-cli.lua --help

# Test basic greeting
lua test/demo-cli.lua greet Alice --colorful

# Test colors
lua test/demo-cli.lua colors --all

# Test progress bars
lua test/demo-cli.lua progress --duration 2

# Test interactive prompts (requires terminal input)
lua test/demo-cli.lua interactive

# Get framework information
lua test/demo-cli.lua info

# Run feature tests
lua test/demo-cli.lua test --all
```

#### File Manager Example
```bash
# List files with colors
lua test/filemanager.lua list . --color

# Count Lua files
lua test/filemanager.lua count . --type lua

# Simulate backup (dry run)
lua test/filemanager.lua backup ./test ./backup --dry-run
```

#### Quick Test
```bash
# Run basic functionality test
lua test/quick-test.lua
```

## 🏗️ Project Structure

```
lumos/
├── lumos/
│   ├── init.lua          # Main entry point
│   ├── app.lua           # Application and command logic
│   ├── core.lua          # Argument parsing and execution
│   ├── flags.lua         # POSIX flag parsing
│   ├── color.lua         # Color and styling
│   ├── progress.lua      # Progress bars
│   └── prompt.lua        # Interactive prompts
├── examples/
│   └── hello.lua         # Basic example
├── test/
│   ├── demo-cli.lua      # Comprehensive demo
│   ├── filemanager.lua   # Realistic file manager example
│   ├── quick-test.lua    # Quick functionality test
│   └── README.md         # Test documentation
├── presentation.md       # Project analysis (French)
├── tech.md              # Technical specifications (French)
└── README.md            # This file
```

## 🐛 Troubleshooting

### Common Issues

1. **Module not found error**
   ```
   lua: module 'lumos' not found
   ```
   **Solution**: Ensure the package path is correctly set:
   ```lua
   package.path = package.path .. ";./lumos/?.lua;./lumos/?/init.lua"
   ```

2. **Colors not working**
   - Check if your terminal supports ANSI colors
   - Verify that `TERM` environment variable is set
   - Use `LUMOS_NO_COLOR=1` to disable colors if needed

3. **Interactive prompts not working**
   - Ensure you're running in a real terminal (not IDE output)
   - Some prompts require TTY support

### Debug Mode
Enable verbose output in any application:
```bash
lua your-app.lua command --verbose
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Follow Lua coding conventions
4. Add tests for new features
5. Update documentation
6. Submit a pull request

### Development Setup
```bash
git clone https://github.com/your-repo/lumos.git
cd lumos

# Run tests
lua test/demo-cli.lua test --all

# Test examples
lua examples/hello.lua --help
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [Cobra](https://cobra.dev/) CLI framework for Go
- Follows [POSIX Utility Syntax Guidelines](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
- Built with ❤️ for the Lua community

---

**Lumos** - *Bringing light to CLI development in Lua* ✨
