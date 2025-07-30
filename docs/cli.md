# Lumos CLI Usage

The Lumos CLI (`bin/lumos`) is the official generator for creating new CLI applications with the Lumos framework.

## Installation

There are several ways to install Lumos:

### Quick Install (Recommended)
```bash
# Clone and install using the provided script
git clone https://github.com/benoitpetit/lumos.git
cd lumos
bash scripts/install.sh
```

This installs the `lumos` binary in `~/.luarocks/bin/`, making it available as a CLI tool for creating new projects.

### Manual Installation
```bash
# For development
luarocks make --local lumos-dev-1.rockspec

# For production
luarocks make --local lumos-0.1.0-1.rockspec
```

---

## Local Development: Testing the Lumos CLI

If you are developing Lumos locally (before publishing to LuaRocks), you can test the CLI without global installation:

1. **From the Lumos project root**:
   ```bash
   lua bin/lumos
   # or to generate a project:
   lua bin/lumos new
   ```
   > Tip: You can also use `./bin/lumos` if the file is executable.

2. **Verify that the Lumos module is accessible**:
   - The script automatically adds the local path (`./lumos/`) to `package.path`.
   - If you encounter the error "Lumos is not available", make sure the `lumos/` folder contains the necessary files (`init.lua`, etc.) and that you are running the command from the project root.

3. **Add a Makefile target for simplicity**:
   Add to your `Makefile`:
   ```makefile
   run:
    @echo "Running Lumos CLI locally..."
    @lua bin/lumos
   ```
   Then you can run:
   ```bash
   make run
   ```

4. **To test the command everywhere** (optional):
   Temporarily add the `bin` folder to your PATH:
   ```bash
   export PATH=$PWD/bin:$PATH
   lumos
   ```
   (This works if the script is executable and paths are properly configured.)

---

## Creating a New CLI Project

Use the `lumos new` command to create a new project interactively:

```bash
lua bin/lumos new
# or
./bin/lumos new
```

(If you have installed Lumos globally, you can also use `lumos new`)

The generator will prompt you for:
- **Project name**: The name of your CLI application
- **Project description**: A brief description of what your CLI does

Example:
```
$ lumos new
Welcome to the Lumos CLI project generator!

Project name [myapp]: todo-cli
Project description [A CLI app built with Lumos]: Simple task management CLI
Creating project structure for todo-cli ...

✅ Lumos CLI project 'todo-cli' created successfully!

Next steps:
  cd todo-cli
  make install    # Install dependencies
  make run        # Run the application
  make test       # Run tests
```

## Generated Project Structure

The generator creates a complete project structure:

```
todo-cli/
├── src/
│   ├── main.lua         # Entry point script
│   └── app.lua          # Main application module
├── tests/
│   └── app_spec.lua     # Test specifications
├── docs/
├── .busted              # Busted test configuration
├── .gitignore           # Git ignore patterns
├── Makefile             # Build automation
└── README.md            # Project documentation
```

## Project Files Explained

### `src/main.lua`
The entry point that loads and runs your CLI application:
```lua
#!/usr/bin/env lua
-- Add local path for app module
local src_path = debug.getinfo(1, 'S').source:match("^@(.+/)main.lua$") or "./src/"
package.path = src_path .. "?.lua;" .. src_path .. "?/init.lua;" .. package.path
local ok, app = pcall(require, 'app')
if not ok then
    print("Error: module 'app' not found. Make sure Lumos is installed or present in ./src.")
    os.exit(1)
end

-- Entrypoint for your CLI app
app.run(arg)
```

### `src/app.lua`
The main application module with a sample command:
```lua
-- Auto-configure Lua paths for LuaRocks installation
local function setup_lua_paths()
    local home = os.getenv("HOME")
    if home then
        local version = _VERSION:match("%d+%.%d+") or "5.1"
        local luarocks_path = home .. "/.luarocks/share/lua/" .. version .. "/?.lua"
        local luarocks_cpath = home .. "/.luarocks/share/lua/" .. version .. "/?/init.lua"
        if not package.path:find(luarocks_path, 1, true) then
            package.path = luarocks_path .. ";" .. luarocks_cpath .. ";" .. package.path
        end
    end
end
setup_lua_paths()

local ok, lumos = pcall(require, 'lumos')
if not ok then
    error("Module 'lumos' is not available. Make sure it's installed with: luarocks install lumos")
end
local okc, color = pcall(require, 'lumos.color')
if not okc then
    color = { green = function(s) return s end }
end

local M = {}

function M.run(args)
    local app = lumos.new_app({
        name = "todo-cli",
        version = "0.1.0",
        description = "Simple task management CLI"
    })

    app:flag("-v --verbose", "Enable verbose mode")

    local greet = app:command("greet", "Greet someone")
    greet:arg("name", "Name of the person")
    greet:action(function(ctx)
        local name = ctx.args[1] or "World"
        print(color.green("Hello, " .. name .. "!"))
        return true
    end)

    app:run(args)
end

return M
```

## Working with Your Project

### Running the Application

```bash
# Navigate to your project
cd todo-cli

# Run the application directly
lua src/main.lua greet Alice

# Or use the Makefile
make run
```

### Installing Dependencies

```bash
make install
```

This installs:
- `busted` for testing
- `lumos` framework (if not installed globally)

### Running Tests

```bash
make test
# or directly
busted tests/
```

### Available Make Targets

- `make install` - Install dependencies
- `make test` - Run tests with Busted
- `make run` - Run the application
- `make docs` - Generate help documentation
- `make clean` - Clean build artifacts

## Customizing Your CLI

### Adding New Commands

Edit `src/app.lua` to add more commands:

```lua
-- Add a new command
local add_task = app:command("add", "Add a new task")
add_task:arg("title", "Task title")
add_task:flag("--priority", "Task priority")
add_task:action(function(ctx)
    local title = ctx.args[1]
    local priority = ctx.flags.priority or "normal"
    print("Added task: " .. title .. " (priority: " .. priority .. ")")
    return true
end)
```

### Adding Subcommands

```lua
-- Create a parent command
local task_cmd = app:command("task", "Task management")

-- Add subcommands
local list_cmd = task_cmd:subcommand("list", "List all tasks")
list_cmd:action(function(ctx)
    print("Listing tasks...")
    return true
end)

local complete_cmd = task_cmd:subcommand("complete", "Mark task as complete")
complete_cmd:arg("id", "Task ID")
complete_cmd:action(function(ctx)
    local id = ctx.args[1]
    print("Completed task: " .. id)
    return true
end)
```

## Additional CLI Commands

### Version Information

```bash
lumos version
```

Shows the Lumos CLI version and information.

## Development Tips

1. **Testing**: Write tests in the `tests/` directory following the `*_spec.lua` naming pattern
2. **Documentation**: Use `lua src/main.lua --help` to see generated help
3. **Dependencies**: Install dependencies locally with `luarocks install --local <package>`
4. **Path Management**: The generated project handles Lua path configuration automatically

## Troubleshooting

### Common Issues

**"Module 'lumos' not found"**
- In local development, make sure to run the command from the Lumos project root.
- Verify that the `lumos/` folder contains the necessary modules (`init.lua`, etc.).
- If needed, install Lumos with: `luarocks install lumos` (for global usage)

**"Module 'busted' not found"**
- Install Busted: `luarocks install busted`
- Or run `make install` in your project

**Permission denied when running**
- Make sure the main script is executable: `chmod +x src/main.lua`
- Or run with lua: `lua src/main.lua`

## Next Steps

Once your CLI is working:

1. **Package it**: Create a proper rockspec file for distribution
2. **Add completion**: Use Lumos completion features for shell integration
3. **Documentation**: Generate man pages with Lumos documentation tools
4. **Testing**: Add comprehensive tests for all commands and edge cases
