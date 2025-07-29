#!/usr/bin/env lua

-- Example CLI using Lumos installed from LuaRocks
-- This example assumes Lumos has been installed with: luarocks install lumos

-- No package.path setup needed when using LuaRocks!
local lumos = require('lumos')
local color = require('lumos.color')
local progress = require('lumos.progress')
local prompt = require('lumos.prompt')

-- Create a task manager application
local app = lumos.new_app({
    name = "taskman",
    version = "1.0.0",
    description = "A simple task manager built with Lumos from LuaRocks"
})

-- Global flags
app:flag("-v --verbose", "Enable verbose output")
app:flag("--no-color", "Disable colored output")

-- ADD command
local add = app:command("add", "Add a new task")
add:arg("task", "Task description")
add:flag("-u --urgent", "Mark task as urgent")
add:flag("-t --tag", "Add a tag to the task")

add:action(function(ctx)
    local task = ctx.args[1]
    if not task then
        print(color.red("Error: Task description is required"))
        return false
    end
    
    local prefix = ctx.flags.urgent and color.red("[URGENT] ") or ""
    local tag = ctx.flags.tag and color.blue("[" .. ctx.flags.tag .. "] ") or ""
    
    print(color.green("✓ Added task:") .. " " .. prefix .. tag .. task)
    
    if ctx.flags.verbose then
        print(color.dim("Task added with ID: " .. math.random(1000, 9999)))
    end
    
    return true
end)

-- LIST command
local list = app:command("list", "List all tasks")
list:flag("-a --all", "Show completed tasks too")
list:flag("-u --urgent-only", "Show only urgent tasks")

list:action(function(ctx)
    print(color.format("{bold}=== Task List ==={reset}"))
    print()
    
    -- Simulate some tasks
    local tasks = {
        {id = 1, text = "Complete project documentation", urgent = false, completed = false},
        {id = 2, text = "Fix critical bug in authentication", urgent = true, completed = false},
        {id = 3, text = "Review pull requests", urgent = false, completed = true},
        {id = 4, text = "Prepare presentation slides", urgent = true, completed = false}
    }
    
    for _, task in ipairs(tasks) do
        if (not ctx.flags.urgent_only or task.urgent) and 
           (ctx.flags.all or not task.completed) then
            
            local status = task.completed and color.dim("[✓]") or "[ ]"
            local urgency = task.urgent and color.red("[URGENT] ") or ""
            local text = task.completed and color.dim(task.text) or task.text
            
            print(string.format("%s %s%s", status, urgency, text))
        end
    end
    
    return true
end)

-- WORK command with progress simulation
local work = app:command("work", "Start working on tasks")
work:option("-d --duration", "Work duration in minutes")
work:flag("--focus", "Enable focus mode")

work:action(function(ctx)
    local duration = tonumber(ctx.flags.duration) or 25 -- Default pomodoro
    
    if ctx.flags.focus then
        print(color.format("{yellow}🍅 Starting {bold}FOCUS MODE{reset}{yellow} for " .. duration .. " minutes{reset}"))
    else
        print(color.format("{blue}Starting work session for " .. duration .. " minutes{reset}"))
    end
    
    print()
    
    -- Simulate work progress
    local bar = progress.new({
        total = duration * 4, -- quarters of minutes
        width = 50,
        format = "[{bar}] {percentage}% - {current}/{total} mins{eta}",
        fill = "▓",
        empty = "░"
    })
    
    for i = 1, duration * 4 do
        bar:update(i)
        os.execute("sleep 0.25") -- 0.25 second = 1/4 minute in simulation
    end
    
    print()
    print(color.green("🎉 Work session completed! Great job!"))
    
    return true
end)

-- CONFIG command with interactive prompts
local config = app:command("config", "Configure task manager settings")
config:flag("--reset", "Reset to default settings")

config:action(function(ctx)
    if ctx.flags.reset then
        print(color.yellow("Resetting to default settings..."))
        return true
    end
    
    print(color.format("{bold}=== Task Manager Configuration ==={reset}"))
    print()
    
    -- Get user preferences
    local name = prompt.input("Your name", "Anonymous")
    local theme = prompt.select("Choose color theme:", {"Dark", "Light", "Auto"}, 3)
    local notifications = prompt.confirm("Enable notifications?", true)
    local pomodoro_length = prompt.input("Default pomodoro length (minutes)", "25")
    
    print()
    print(color.format("{green}Configuration saved:{reset}"))
    print("  Name: " .. color.cyan(name))
    print("  Theme: " .. color.cyan(theme))
    print("  Notifications: " .. (notifications and color.green("Yes") or color.red("No")))
    print("  Pomodoro: " .. color.cyan(pomodoro_length) .. " minutes")
    
    return true
end)

-- Run the application
app:run(arg)
