# Lumos Usage Examples

Real-world examples demonstrating Lumos CLI framework features.

## Basic CLI Application

A simple file utility CLI:

```lua
local lumos = require('lumos')
local color = require('lumos.color')
local lfs = require('lfs')

local app = lumos.new_app({
    name = "fileutil",
    version = "0.1.0",
    description = "File utilities CLI"
})

-- Global flags
app:flag("-v --verbose", "Enable verbose output")

-- List files command
local list = app:command("list", "List files in directory")
list:arg("directory", "Directory to list (default: current)")
list:flag("-l --long", "Show detailed information")
list:flag("-a --all", "Show hidden files")

list:action(function(ctx)
    local dir = ctx.args[1] or "."
    
    for file in lfs.dir(dir) do
        if file ~= "." and file ~= ".." then
            local skip = false
            if not ctx.flags.all and file:sub(1,1) == "." then
                skip = true
            end

            if not skip then
                if ctx.flags.long then
                    local attr = lfs.attributes(dir .. "/" .. file)
                    if attr then
                        local size = attr.size or 0
                        local mode = attr.mode or "unknown"
                        print(string.format("%s %8d %s", mode, size, file))
                    end
                else
                    local file_color = lfs.attributes(dir .. "/" .. file, "mode") == "directory"
                        and color.blue or color.white
                    print(file_color(file))
                end
            end
        end
    end
    return true
end)

app:run(arg)
```

## Advanced CLI with Subcommands

A deployment tool with nested commands:

```lua
local lumos = require('lumos')
local color = require('lumos.color')
local prompt = require('lumos.prompt')
local progress = require('lumos.progress')

local app = lumos.new_app({
    name = "deploy",
    version = "2.0.0",
    description = "Application deployment tool"
})

-- Global persistent flags
app:persistent_flag("--dry-run", "Show what would be done")
app:persistent_flag("--config", "Configuration file path")

-- Application management
local app_cmd = app:command("app", "Application management")
app_cmd:persistent_flag("--env", "Environment (staging/production)")

-- Deploy application
local deploy_cmd = app_cmd:subcommand("deploy", "Deploy application")
deploy_cmd:arg("version", "Version to deploy")
deploy_cmd:flag("-f --force", "Force deployment")
deploy_cmd:flag_int("--timeout", "Deployment timeout", 30, 3600)

deploy_cmd:action(function(ctx)
    local version = ctx.args[1]
    local env = ctx.flags.env or "staging"
    local timeout = ctx.flags.timeout or 300
    
    if not version then
        print(color.red("Error: Version is required"))
        return false
    end
    
    print(color.cyan("Deploying " .. version .. " to " .. env))
    
    if ctx.flags.force or prompt.confirm("Continue with deployment?", false) then
        if ctx.flags.dry_run then
            print(color.yellow("Dry run: Would deploy " .. version))
        else
            local bar = progress.new({
                total = 100,
                format = "[{bar}] {percentage}% - Deploying...",
                width = 40
            })
            
            for i = 1, 100 do
                bar:update(i)
                -- Simulate deployment work
                os.execute("sleep 0.02")
            end
            
            print(color.green("Deployment successful!"))
        end
    else
        print("Deployment cancelled")
    end
    
    return true
end)

-- Rollback command
local rollback_cmd = app_cmd:subcommand("rollback", "Rollback deployment")
rollback_cmd:flag_int("--steps", "Number of steps to rollback", 1, 10)

rollback_cmd:action(function(ctx)
    local steps = ctx.flags.steps or 1
    local env = ctx.flags.env or "staging"
    
    print(color.yellow("Rolling back " .. steps .. " steps in " .. env))
    
    if ctx.flags.dry_run then
        print(color.yellow("Dry run: Would rollback " .. steps .. " steps"))
    else
        print(color.green("Rollback completed"))
    end
    
    return true
end)

-- Database management
local db_cmd = app:command("db", "Database management")
db_cmd:persistent_flag("--host", "Database host")
db_cmd:persistent_flag("--port", "Database port")

local migrate_cmd = db_cmd:subcommand("migrate", "Run database migrations")
migrate_cmd:flag("--up", "Run up migrations")
migrate_cmd:flag("--down", "Run down migrations")

migrate_cmd:action(function(ctx)
    local host = ctx.flags.host or "localhost"
    local port = ctx.flags.port or "5432"
    
    print(color.blue("Connecting to " .. host .. ":" .. port))
    
    if ctx.flags.up then
        print(color.green("Running UP migrations"))
    elseif ctx.flags.down then
        print(color.yellow("Running DOWN migrations"))
    else
        print(color.red("Error: Specify --up or --down"))
        return false
    end
    
    return true
end)

app:run(arg)
```

## Interactive CLI Application

A task manager with interactive features:

```lua
local lumos = require('lumos')
local color = require('lumos.color')
local prompt = require('lumos.prompt')
local json = require('lumos.json')
local tbl = require('lumos.table')

local app = lumos.new_app({
    name = "tasks",
    version = "0.1.0",
    description = "Simple task manager"
})

local tasks_file = "tasks.json"

-- Load tasks from file
local function load_tasks()
    local file = io.open(tasks_file, "r")
    if not file then
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    local ok, tasks = pcall(json.decode, content)
    return ok and tasks or {}
end

-- Save tasks to file
local function save_tasks(tasks)
    local file = io.open(tasks_file, "w")
    if file then
        file:write(json.encode(tasks))
        file:close()
        return true
    end
    return false
end

-- Add task command
local add_cmd = app:command("add", "Add a new task")
add_cmd:arg("title", "Task title")
add_cmd:option("--priority", "Task priority")

add_cmd:action(function(ctx)
    local title = ctx.args[1]
    if not title then
        title = prompt.input("Task title:")
    end
    
    if not title or title == "" then
        print(color.red("Error: Task title is required"))
        return false
    end
    
    local priority = ctx.flags.priority or 
        prompt.select("Priority:", {"Low", "Medium", "High"}, 2)
    
    local tasks = load_tasks()
    table.insert(tasks, {
        id = #tasks + 1,
        title = title,
        priority = priority,
        completed = false,
        created = os.date("%Y-%m-%d %H:%M")
    })
    
    if save_tasks(tasks) then
        print(color.green("Task added: " .. title))
    else
        print(color.red("Failed to save task"))
        return false
    end
    
    return true
end)

-- List tasks command
local list_cmd = app:command("list", "List all tasks")
list_cmd:flag("--completed", "Show only completed tasks")
list_cmd:flag("--pending", "Show only pending tasks")
list_cmd:flag("--json", "Output in JSON format")

list_cmd:action(function(ctx)
    local tasks = load_tasks()
    
    if #tasks == 0 then
        print("No tasks found")
        return true
    end
    
    -- Filter tasks
    local filtered = {}
    for _, task in ipairs(tasks) do
        local include = true
        if ctx.flags.completed and not task.completed then
            include = false
        end
        if ctx.flags.pending and task.completed then
            include = false
        end
        if include then
            table.insert(filtered, task)
        end
    end
    
    if ctx.flags.json then
        print(json.encode(filtered))
    else
        local data = {}
        for _, task in ipairs(filtered) do
            local status = task.completed and color.green("Done") or color.yellow("Pending")
            local priority_color = task.priority == "High" and color.red or 
                                 task.priority == "Medium" and color.yellow or color.white
            
            table.insert(data, {
                id = tostring(task.id),
                title = task.title,
                priority = priority_color(task.priority),
                status = status,
                created = task.created
            })
        end
        
        print(tbl.create(data, {
            headers = {"ID", "Title", "Priority", "Status", "Created"}
        }))
    end
    
    return true
end)

-- Complete task command
local complete_cmd = app:command("complete", "Mark task as completed")
complete_cmd:arg("id", "Task ID")

complete_cmd:action(function(ctx)
    local id = tonumber(ctx.args[1])
    if not id then
        print(color.red("Error: Task ID is required"))
        return false
    end
    
    local tasks = load_tasks()
    local found = false
    
    for _, task in ipairs(tasks) do
        if task.id == id then
            task.completed = true
            found = true
            print(color.green("Task completed: " .. task.title))
            break
        end
    end
    
    if not found then
        print(color.red("Task not found: " .. id))
        return false
    end
    
    return save_tasks(tasks)
end)

-- Interactive mode
local interactive_cmd = app:command("interactive", "Interactive task management")

interactive_cmd:action(function(ctx)
    while true do
        local action = prompt.select("What would you like to do?", {
            "Add task",
            "List tasks",
            "Complete task",
            "Exit"
        }, 1)
        
        if action == 1 then
            -- Add task
            local title = prompt.input("Task title:")
            if title and title ~= "" then
                local priority = prompt.select("Priority:", {"Low", "Medium", "High"}, 2)
                local tasks = load_tasks()
                table.insert(tasks, {
                    id = #tasks + 1,
                    title = title,
                    priority = priority,
                    completed = false,
                    created = os.date("%Y-%m-%d %H:%M")
                })
                save_tasks(tasks)
                print(color.green("Task added!"))
            end
            
        elseif action == 2 then
            -- List tasks
            local tasks = load_tasks()
            if #tasks > 0 then
                for _, task in ipairs(tasks) do
                    local status = task.completed and "[DONE]" or "[TODO]"
                    local status_color = task.completed and color.green or color.yellow
                    print(task.id .. ". " .. task.title .. " " .. status_color(status))
                end
            else
                print("No tasks found")
            end
            
        elseif action == 3 then
            -- Complete task
            local id_str = prompt.input("Task ID to complete:")
            local id = tonumber(id_str)
            if id then
                local tasks = load_tasks()
                for _, task in ipairs(tasks) do
                    if task.id == id then
                        task.completed = true
                        save_tasks(tasks)
                        print(color.green("Task completed!"))
                        break
                    end
                end
            end
            
        else
            -- Exit
            break
        end
        
        print() -- Empty line for spacing
    end
    
    print(color.cyan("Goodbye!"))
    return true
end)

app:run(arg)
```

## Configuration-Driven CLI

A deployment tool that uses configuration files:

```lua
local lumos = require('lumos')
local color = require('lumos.color')
local config = require('lumos.config')
local core = require('lumos.core')
local json = require('lumos.json')

local app = lumos.new_app({
    name = "configapp",
    version = "0.1.0",
    description = "Configuration-driven deployment tool"
})

-- Global configuration flag
app:persistent_flag("-c --config", "Configuration file")

-- Deploy command with configuration
local deploy_cmd = app:command("deploy", "Deploy with configuration")
deploy_cmd:arg("environment", "Target environment")
deploy_cmd:option("--timeout", "Override timeout setting")
deploy_cmd:flag("--dry-run", "Show what would be done")

deploy_cmd:action(function(ctx)
    local env = ctx.args[1] or "staging"
    
    -- Load configuration with priority hierarchy
    local default_config = {
        timeout = 300,
        retries = 3,
        parallel = false,
        environments = {
            staging = {host = "staging.example.com", port = 8080},
            production = {host = "prod.example.com", port = 80}
        }
    }
    
    local file_config = {}
    if ctx.flags.config then
        -- core.load_config supports both JSON and key=value files
        file_config = core.load_config(ctx.flags.config) or {}
    end
    
    local env_config = config.load_env("DEPLOY") -- DEPLOY_* variables
    
    -- Merge configurations: defaults < file < environment < flags
    local final_config = config.merge_configs(
        default_config,
        file_config,
        env_config,
        {timeout = ctx.flags.timeout} -- command line overrides
    )
    
    print(color.cyan("Deployment Configuration:"))
    print(json.encode(final_config))
    print()
    
    local env_settings = final_config.environments[env]
    if not env_settings then
        print(color.red("Error: Unknown environment: " .. env))
        return false
    end
    
    print(color.blue("Deploying to " .. env .. "..."))
    print("Host: " .. env_settings.host)
    print("Port: " .. env_settings.port)
    print("Timeout: " .. final_config.timeout .. "s")
    
    if ctx.flags.dry_run then
        print(color.yellow("Dry run completed"))
    else
        print(color.green("Deployment successful"))
    end
    
    return true
end)

app:run(arg)
```

## Secure CLI with Logging

A secure file management CLI using `lumos.security` and `lumos.logger`:

```lua
local lumos = require('lumos')
local color = require('lumos.color')
local security = require('lumos.security')
local logger = require('lumos.logger')

local app = lumos.new_app({
    name = "securefile",
    version = "0.1.0",
    description = "Secure file management CLI"
})

-- Configure logging
logger.set_level("INFO")
logger.configure_from_env("SECUREFILE")

local read_cmd = app:command("read", "Read a file safely")
read_cmd:arg("path", "File path")

read_cmd:action(function(ctx)
    local path = ctx.args[1]
    if not path then
        print(color.red("Error: path is required"))
        return false
    end
    
    local safe_path, err = security.sanitize_path(path)
    if not safe_path then
        logger.error("Invalid path", {input = path, error = err})
        print(color.red("Error: " .. err))
        return false
    end
    
    local file, ferr = security.safe_open(safe_path, "r")
    if not file then
        logger.error("Cannot open file", {path = safe_path, error = ferr})
        print(color.red("Error: " .. ferr))
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Sanitize output to prevent terminal escape injection
    print(security.sanitize_output(content))
    logger.info("File read", {path = safe_path, size = #content})
    return true
end)

local exec_cmd = app:command("exec", "Execute a safe command")
exec_cmd:arg("program", "Program to run")
exec_cmd:arg("args", "Arguments")

exec_cmd:action(function(ctx)
    local program = ctx.args[1]
    local args = ctx.args[2] or ""
    
    local safe_program, err = security.sanitize_command_name(program)
    if not safe_program then
        logger.error("Invalid command", {input = program, error = err})
        print(color.red("Error: " .. err))
        return false
    end
    
    local safe_args = security.shell_escape(args)
    local cmd = safe_program .. " " .. safe_args
    
    logger.info("Executing command", {command = cmd})
    local success = os.execute(cmd)
    return success == 0 or success == true
end)

app:run(arg)
```

## Modern CLI with Middleware and Typed Flags

An example showcasing Lumos 0.3.x features: middleware chains, typed flags, mutex groups, and typed errors.

```lua
local lumos = require('lumos')
local color = require('lumos.color')
local platform = require('lumos.platform')

local app = lumos.new_app({
    name = "deployctl",
    version = "0.3.4",
    description = "Modern deployment controller"
})

-- Global middleware
app:use(lumos.middleware.builtin.logger())
app:use(lumos.middleware.builtin.dry_run())

-- Command with advanced flags and middleware
local deploy = app:command("deploy", "Deploy an application")

deploy:arg("app", "Application name", { required = true })

-- Typed flags
deploy:flag_enum("-e --env", "Environment", {"dev", "staging", "prod"})
deploy:flag_int("--workers", "Number of workers", 1, 64)
deploy:flag_float("-r --rate", "Deployment rate", { min = 0.0, max = 1.0, precision = 2 })
deploy:flag_array("-t --tags", "Deployment tags", { separator = ",", unique = true })
deploy:flag_path("-c --config", "Config file", { must_exist = true, extensions = {".json"} })
deploy:flag_url("--endpoint", "API endpoint", { schemes = {"https"} })

-- Mutually exclusive input flags
deploy:mutex_group("target", {
    deploy:flag_string("--image", "Container image"),
    deploy:flag_string("--git", "Git repository URL")
}, { required = true })

-- Per-command middleware
deploy:use(lumos.middleware.builtin.auth({ env_var = "DEPLOY_API_KEY" }))
deploy:use(lumos.middleware.builtin.confirm({ message = "Deploy to production?", default = false }))

deploy:action(function(ctx)
    if ctx.dry_run then
        print(color.yellow("[DRY-RUN] Would deploy " .. ctx.args[1]))
        return lumos.success({ dry_run = true })
    end

    if not platform.is_interactive() and not ctx.flags.force then
        return lumos.new_error("EXECUTION_FAILED", "Non-interactive mode requires --force")
    end

    print(color.green("Deploying " .. ctx.args[1] .. " to " .. ctx.flags.env))
    print("Workers: " .. tostring(ctx.flags.workers))
    print("Rate: " .. tostring(ctx.flags.rate))
    print("Tags: " .. table.concat(ctx.flags.tags or {}, ", "))

    return lumos.success({ deployed = true, app = ctx.args[1] })
end)

app:run(arg)
```

## Usage Examples Summary

These examples show different patterns:

1. **Basic CLI**: Simple commands with file operations
2. **Advanced CLI**: Nested subcommands with interactive prompts
3. **Interactive CLI**: Menu-driven interface with persistent data
4. **Configuration CLI**: External configuration with environment variables
5. **Secure CLI**: Input sanitization, safe file operations, and structured logging
6. **Modern CLI**: Middleware, typed flags, mutex groups, and typed errors (0.3.x)

Each example demonstrates key Lumos features:
- Command and subcommand definition
- Flag parsing and validation (including advanced types)
- Interactive prompts and progress bars
- Configuration management
- Typed error handling and colored output
- JSON data handling
- Table formatting
- Security features and logging
- Middleware chains and cross-platform detection
