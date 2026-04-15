#!/usr/bin/env lua

-- Advanced Example using Lumos Framework
-- Demonstrates flags validation, aliases, and persistent flags

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
-- Create the application
local app = lumos.new_app({
    name = "advanced_app",
    version = "2.0.0",
    description = "Advanced example using Lumos"
})

-- Add persistent flags
app:persistent_flag("-f --force", "Force operation")

-- "add" command for adding items, with alias "a"
local add = app:command("add", "Add an item"):alias("a")
add:arg("item", "Item to add")
add:flag_int("--count", "Number of items to add", 1, 100)

add:action(function(ctx)
    local item = ctx.args[1] or "item"
    local count = ctx.flags.count or 1
    logger.info("Adding " .. count .. " " .. item .. "(s)")
    
    return true
end)

-- "remove" command for removing items
local remove = app:command("remove", "Remove an item")
remove:arg("item", "Item to remove")
remove:flag("-q --quiet", "Suppress output")
remove:action(function(ctx)
    local item = ctx.args[1] or "item"
    logger.info("Removing " .. item)
    return true
end)

-- Run the app
os.exit(app:run(arg))
