#!/usr/bin/env lua

-- Basic example using the Lumos framework
-- Demonstrates main features: commands, arguments, flags

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

-- Create the application
local app = lumos.new_app({
    name = "myapp",
    version = "1.0.0", 
    description = "Basic example using Lumos"
})

-- Add global flags
app:flag("-v --verbose", "Enable detailed output")
app:flag("--debug", "Enable debug mode")

-- "greet" command to greet someone
local greet = app:command("greet", "Greet a person")
greet:arg("name", "Name of the person to greet")
greet:flag("-u --uppercase", "Display in uppercase") 
greet:flag("-c --colorful", "Display in color")
greet:examples({
    "myapp greet Alice",
    "myapp greet Bob --uppercase",
    "myapp greet Charlie --colorful"
})

greet:action(function(ctx)
    local name = ctx.args[1] or "World"
    local message = "Hello, " .. name .. "!"
    
    if ctx.flags.uppercase then
        message = message:upper()
    end
    
    if ctx.flags.colorful then
        message = color.green(message)
    end
    
    if ctx.flags.verbose then
        print(color.dim("Verbose mode enabled"))
        print(color.dim("Received arguments: " .. table.concat(ctx.args or {}, ", ")))
    end
    
    print(message)
    return true
end)

-- "info" command for information
local info = app:command("info", "Display application information")
info:flag("-a --all", "Show all information")

info:action(function(ctx)
    print(color.bold("Application Information:"))
    print("Name: " .. color.cyan("myapp"))
    print("Version: " .. color.yellow("1.0.0"))
    
    if ctx.flags.all then
        print("Framework: " .. color.magenta("Lumos"))
        print("Language: " .. color.blue("Lua"))
        print("Available commands: greet, info")
    end
    
    return true
end)

-- Run the application with command line arguments
app:run(arg)
