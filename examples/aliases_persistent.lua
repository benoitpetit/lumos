#!/usr/bin/env lua

-- Aliases and Persistent Flags Example
-- Demonstrates command aliases and persistent flag inheritance

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
-- Create the application
local app = lumos.new_app({
    name = "aliases_demo",
    version = "0.3.6",
    description = "Demonstrates command aliases and persistent flags"
})

-- Add persistent flags (inherited by all commands)
app:persistent_flag("-v --verbose", "Enable verbose output")
app:persistent_flag("--dry-run", "Show what would be done without executing")

-- Data persistence functions
local data_file = "examples/items_list.txt"

local function save_items(items)
    local file = io.open(data_file, "w")
    if file then
        for _, item in ipairs(items) do
            file:write(item .. "\n")
        end
        file:close()
        return true
    end
    return false
end

local function load_items()
    local items = {}
    local file = io.open(data_file, "r")
    if file then
        for line in file:lines() do
            if line:match("%S") then -- Only non-empty lines
                table.insert(items, line)
            end
        end
        file:close()
    else
        -- Default items if file doesn't exist
        items = {"book", "pen", "notebook"}
        save_items(items)
    end
    return items
end

local function add_item(item, count)
    local items = load_items()
    for i = 1, count do
        table.insert(items, item)
    end
    return save_items(items)
end

local function remove_item(item_to_remove)
    local items = load_items()
    local removed = false
    
    -- Try to remove by name first
    for i = #items, 1, -1 do
        if items[i] == item_to_remove then
            table.remove(items, i)
            removed = true
            break
        end
    end
    
    -- If not found by name, try by index
    if not removed then
        local index = tonumber(item_to_remove)
        if index and index >= 1 and index <= #items then
            table.remove(items, index)
            removed = true
        end
    end
    
    if removed then
        save_items(items)
    end
    return removed
end

-- Create command with multiple aliases
local add = app:command("add", "Add an item to the list")
add:alias("a")      -- Short alias
add:alias("create") -- Alternative name
add:alias("new")    -- Another alternative

add:arg("item", "Item to add")
add:flag_int("--count", "Number of items to add", 1, 100)

add:examples({
    "aliases_demo add book",
    "aliases_demo a book --count 5",      -- Using short alias
    "aliases_demo create book --verbose", -- Using alternative name
    "aliases_demo new book --dry-run"    -- Using another alias
})

add:action(function(ctx)
    local item = ctx.args[1]
    local count = ctx.flags.count or 1
    
    if not item then
        logger.error("Please provide an item to add")
        return false
    end
    
    if ctx.flags.verbose then
        logger.info("Verbose mode enabled")
        logger.info("Command used: " .. (ctx.command.name or "unknown"))
        logger.info("Item to add: " .. item)
        local flag_names = {}
        for name, _ in pairs(ctx.flags or {}) do
            table.insert(flag_names, name)
        end
        logger.info("All flags: " .. table.concat(flag_names, ", "))
    end
    
    if ctx.flags.dry_run then
        logger.warn("DRY RUN: Would add " .. count .. " " .. item .. "(s)")
    else
        if add_item(item, count) then
            logger.info("Added " .. count .. " " .. item .. "(s)")
        else
            logger.error("Failed to add items")
            return false
        end
    end
    
    return true
end)

-- Remove command with aliases
local remove = app:command("remove", "Remove an item from the list")
remove:alias("rm")
remove:alias("delete")
remove:alias("del")

remove:arg("item", "Item to remove")
remove:flag("--force", "Force removal without confirmation")

remove:action(function(ctx)
    local item = ctx.args[1]
    
    if not item then
        logger.error("Please provide an item to remove")
        return false
    end
    
    if ctx.flags.verbose then
        logger.info("Verbose mode enabled")
        logger.info("Item to remove: " .. item)
    end
    
    if ctx.flags.dry_run then
        logger.warn("DRY RUN: Would remove " .. item)
    else
        if remove_item(item) then
            if ctx.flags.force then
                logger.info("Forcefully removed " .. item)
            else
                logger.info("Removed " .. item)
            end
        else
            logger.error("Item '\''" .. item .. "\'' not found")
            return false
        end
    end
    
    return true
end)


-- List command to show aliases in help
local list = app:command("list", "List all items")
list:alias("ls")
list:alias("show")

list:action(function(ctx)
    local items = load_items()
    
    if ctx.flags.verbose then
        logger.info("Listing all items from " .. data_file .. ":")
    end
    
    if #items == 0 then
        logger.warn("No items in the list")
    else
        for i, item in ipairs(items) do
            logger.info(i .. ". " .. color.cyan(item))
        end
    end
    
    return true
end)

-- Run the app
os.exit(app:run(arg))
