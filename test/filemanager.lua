#!/usr/bin/env lua

-- Realistic File Manager CLI demonstration using Lumos
package.path = package.path .. ";./?.lua;./?/init.lua"

local lumos = require('lumos')
local color = require('lumos.color')
local progress = require('lumos.progress')
local prompt = require('lumos.prompt')

-- Create file manager application
local app = lumos.new_app({
    name = "filemanager",
    version = "1.0.0",
    description = "A simple file management CLI tool built with Lumos"
})

-- Global flags
app:flag("-v --verbose", "Enable verbose output")
app:flag("--dry-run", "Show what would be done without executing")

-- LIST command
local list = app:command("list", "List files and directories")
list:arg("path", "Path to list (default: current directory)")
list:flag("-a --all", "Show hidden files")
list:flag("-l --long", "Use long listing format")
list:flag("--color", "Colorize output")

list:action(function(ctx)
    local path = ctx.args[1] or "."
    
    if ctx.flags.verbose then
        print(color.dim("Listing contents of: " .. path))
    end
    
    -- Execute ls command
    local cmd = "ls"
    if ctx.flags.all then cmd = cmd .. " -a" end
    if ctx.flags.long then cmd = cmd .. " -l" end
    cmd = cmd .. " " .. path
    
    if ctx.flags.verbose then
        print(color.dim("Running: " .. cmd))
    end
    
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        if ctx.flags.color then
            -- Simple colorization
            result = result:gsub("([%w%-_%.]+%.txt)", color.blue("%1"))
            result = result:gsub("([%w%-_%.]+%.lua)", color.green("%1"))
            result = result:gsub("([%w%-_%.]+%.md)", color.yellow("%1"))
        end
        
        print(result)
    else
        print(color.red("Error: Could not list directory"))
        return false
    end
    
    return true
end)

-- COUNT command
local count = app:command("count", "Count files in directory")
count:arg("path", "Path to count files in")
count:flag("-r --recursive", "Count recursively")
count:flag("--type", "File type to count (e.g., lua, txt)")

count:action(function(ctx)
    local path = ctx.args[1] or "."
    
    if ctx.flags['dry-run'] then
        print(color.yellow("DRY RUN: Would count files in " .. path))
        return true
    end
    
    print(color.format("{bold}Counting files in: {cyan}" .. path .. "{reset}"))
    
    local cmd = "find " .. path
    if not ctx.flags.recursive then
        cmd = cmd .. " -maxdepth 1"
    end
    cmd = cmd .. " -type f"
    
    if ctx.flags.type then
        cmd = cmd .. " -name '*." .. ctx.flags.type .. "'"
    end
    
    -- Simulate progress for counting
    print("Scanning...")
    local bar = progress.new({
        total = 100,
        width = 40,
        format = "[{bar}] {percentage}%"
    })
    
    for i = 1, 100, 10 do
        bar:update(i)
        os.execute("sleep 0.05") -- Simulate work
    end
    bar:finish()
    
    local handle = io.popen(cmd .. " | wc -l")
    if handle then
        local count = handle:read("*a"):gsub("%s+", "")
        handle:close()
        
        print(color.format("{green}Found {bold}" .. count .. "{reset}{green} files{reset}"))
        
        if ctx.flags.verbose then
            print(color.dim("Command used: " .. cmd .. " | wc -l"))
        end
    else
        print(color.red("Error: Could not count files"))
        return false
    end
    
    return true
end)

-- BACKUP command
local backup = app:command("backup", "Create backup of files")
backup:arg("source", "Source directory or file")
backup:arg("destination", "Backup destination")
backup:flag("-c --compress", "Compress backup")
backup:flag("-x --exclude", "Patterns to exclude")

backup:action(function(ctx)
    local source = ctx.args[1]
    local dest = ctx.args[2]
    
    if not source then
        print(color.red("Error: Source path required"))
        return false
    end
    
    if not dest then
        dest = prompt.input("Enter backup destination", source .. "_backup")
    end
    
    local confirm = prompt.confirm("Create backup of '" .. source .. "' to '" .. dest .. "'?", true)
    if not confirm then
        print("Backup cancelled")
        return true
    end
    
    if ctx.flags['dry-run'] then
        print(color.yellow("DRY RUN: Would backup " .. source .. " to " .. dest))
        return true
    end
    
    print(color.format("{bold}Creating backup...{reset}"))
    
    -- Simulate backup progress
    local bar = progress.new({
        total = 50,
        width = 50,
        format = "[{bar}] {percentage}% - Backing up files{eta}",
        fill = "█",
        empty = "░"
    })
    
    for i = 1, 50 do
        bar:increment()
        os.execute("sleep 0.1")
    end
    
    print(color.green("✓ Backup completed successfully!"))
    print(color.dim("Backup saved to: " .. dest))
    
    return true
end)

-- CLEAN command  
local clean = app:command("clean", "Clean temporary files")
clean:flag("--temp", "Clean temporary files")
clean:flag("--logs", "Clean log files")
clean:flag("--cache", "Clean cache files")

clean:action(function(ctx)
    if not (ctx.flags.temp or ctx.flags.logs or ctx.flags.cache) then
        print(color.yellow("No cleanup options specified. Use --temp, --logs, or --cache"))
        return true
    end
    
    local confirm = prompt.confirm("This will delete files. Are you sure?", false)
    if not confirm then
        print("Cleanup cancelled")
        return true
    end
    
    if ctx.flags['dry-run'] then
        print(color.yellow("DRY RUN: Would clean specified file types"))
        return true
    end
    
    print(color.format("{bold}Cleaning files...{reset}"))
    
    local cleaned = 0
    if ctx.flags.temp then
        print("• Cleaning temporary files...")
        cleaned = cleaned + 5  -- Simulated
    end
    
    if ctx.flags.logs then
        print("• Cleaning log files...")
        cleaned = cleaned + 3  -- Simulated
    end
    
    if ctx.flags.cache then
        print("• Cleaning cache files...")
        cleaned = cleaned + 8  -- Simulated
    end
    
    print(color.format("{green}✓ Cleaned {bold}" .. cleaned .. "{reset}{green} files{reset}"))
    return true
end)

-- Run the application
app:run(arg)
