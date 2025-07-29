# Lumos Quick Start

Get started with Lumos CLI framework in 5 minutes.

## Installation

### Quick Install (Recommended)
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos
bash scripts/install.sh
```

### Manual Install (if script fails)
```bash
git clone https://github.com/benoitpetit/lumos.git
cd lumos

# Create directories
mkdir -p $HOME/.luarocks/share/lua/5.1
mkdir -p $HOME/.luarocks/bin

# Copy modules and binary
cp -r lumos $HOME/.luarocks/share/lua/5.1/
cp bin/lumos $HOME/.luarocks/bin/
chmod +x $HOME/.luarocks/bin/lumos

# Add to PATH
echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Dependencies

Lumos requires:
- Lua 5.1+ (install with: `sudo apt-get install lua5.1` on Ubuntu/Debian)
- luafilesystem (install with: `luarocks install luafilesystem` if LuaRocks works)

## Create Your First CLI

### Generate Project
```bash
lumos new
```

### Test Generated App
```bash
lua src/main.lua --help
lua src/main.lua greet "World"
```

## Project Structure

```
my-cli/
├── src/
│   ├── main.lua        # Entry point
│   └── app.lua         # CLI logic
├── tests/
│   └── app_spec.lua    # Tests
├── Makefile           # Build tasks
├── README.md          # Documentation
├── .busted            # Test config
└── .gitignore         # Git ignore
```

## Basic Example

Create a simple CLI application:

```lua
local lumos = require('lumos')
local color = require('lumos.color')

local app = lumos.new_app({
    name = "example",
    version = "0.1.0",
    description = "Example CLI application"
})

-- Add global flag
app:flag("-v --verbose", "Enable verbose output")

-- Create command
local greet = app:command("greet", "Greet someone")
greet:arg("name", "Name to greet")
greet:flag("-u --uppercase", "Use uppercase")

greet:action(function(ctx)
    local name = ctx.args[1] or "World"
    local message = "Hello, " .. name .. "!"
    
    if ctx.flags.uppercase then
        message = message:upper()
    end
    
    if ctx.flags.verbose then
        print("Greeting: " .. name)
    end
    
    print(color.green(message))
    return true
end)

app:run(arg)
```

## Development Workflow

### Install Dependencies
```bash
make install
```

### Run Application
```bash
make run
# or
lua src/main.lua
```

### Run Tests
```bash
make test
# or
busted tests/
```

## Adding Features

### Multiple Commands
```lua
-- Add more commands
local goodbye = app:command("goodbye", "Say goodbye")
goodbye:arg("name", "Name to bid farewell")
goodbye:action(function(ctx)
    local name = ctx.args[1] or "World"
    print(color.blue("Goodbye, " .. name .. "!"))
    return true
end)
```

### Subcommands
```lua
local user = app:command("user", "User management")
local user_list = user:subcommand("list", "List users")
local user_create = user:subcommand("create", "Create user")

user_create:arg("username", "Username to create")
user_create:action(function(ctx)
    local username = ctx.args[1]
    print("Creating user: " .. username)
    return true
end)
```

### Interactive Features
```lua
local prompt = require('lumos.prompt')
local progress = require('lumos.progress')

local interactive = app:command("interactive", "Interactive demo")
interactive:action(function(ctx)
    local name = prompt.input("What's your name?", "Anonymous")
    local confirmed = prompt.confirm("Continue?", true)
    
    if confirmed then
        for i = 1, 100 do
            progress.simple(i, 100)
            -- simulate work
        end
        print(color.green("Done, " .. name .. "!"))
    end
    
    return true
end)
```

### Configuration
```lua
local config = require('lumos.config')

-- Load from file and environment
local settings = config.merge_configs(
    {timeout = 30, debug = false},  -- defaults
    config.load_file("config.json"),
    config.load_env("MYAPP"),
    ctx.flags
)
```

## Common Patterns

### Input Validation
```lua
cmd:action(function(ctx)
    local port = ctx.flags.port
    if port then
        local num = tonumber(port)
        if not num or num < 1 or num > 65535 then
            print(color.red("Error: Invalid port number"))
            return false
        end
    end
    return true
end)
```

### Error Handling
```lua
cmd:action(function(ctx)
    if not ctx.args[1] then
        print(color.red("Error: Missing required argument"))
        return false
    end
    
    -- do work
    local success = do_something()
    if not success then
        print(color.red("Operation failed"))
        return false
    end
    
    print(color.green("Success!"))
    return true
end)
```

### Help and Examples
```lua
local deploy = app:command("deploy", "Deploy application")
deploy:arg("environment", "Target environment (staging/production)")
deploy:flag("-f --force", "Force deployment without confirmation")
deploy:examples({
    "deploy staging",
    "deploy production --force",
    "deploy staging --config custom.json"
})
```

## Next Steps

- Read the [API Reference](api.md) for complete method documentation
- See [Usage Examples](use.md) for real-world scenarios
- Learn about the [CLI Tool](cli.md) for project management
- Check out the examples in the `examples/` directory

## Tips

1. **Start Simple**: Begin with basic commands and add complexity gradually
2. **Use Colors**: Improve user experience with colored output
3. **Add Help Text**: Provide clear descriptions for commands and flags
4. **Handle Errors**: Return false from actions to indicate failure
5. **Test Your CLI**: Write tests for your commands using the generated test suite
