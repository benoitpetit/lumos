#!/usr/bin/env lua

-- Example Lumos CLI Application
package.path = package.path .. ";./?.lua;./?/init.lua"
local lumos = require('lumos')

-- Create a new application
local app = lumos.new_app({
    name = "hello",
    version = "1.0.0",
    description = "A simple greeting CLI application"
})

-- Add a global flag
app:flag("-v --verbose", "Enable verbose output")

-- Define a greet command
local greet = app:command("greet", "Greet someone")
greet:arg("name", "Name to greet")
greet:flag("-q --quiet", "Be quiet")
greet:flag("-u --uppercase", "Use uppercase")
-- Examples:
-- hello greet Alice
-- hello greet Bob --quiet
-- hello greet --uppercase World

greet:action(function(ctx)
    local name = ctx.args[1] or "World"
    local message = "Hello " .. name .. "!"
    
    if ctx.flags.uppercase then
        message = message:upper()
    end
    
    if not ctx.flags.quiet then
        print(message)
    end
    
    return true
end)

-- Define a goodbye command
local goodbye = app:command("goodbye", "Say goodbye to someone")
goodbye:arg("name", "Name to say goodbye to")
goodbye:flag("-f --formal", "Use formal goodbye")

goodbye:action(function(ctx)
    local name = ctx.args[1] or "friend"
    local message
    
    if ctx.flags.formal then
        message = "Farewell, " .. name .. "."
    else
        message = "Bye " .. name .. "!"
    end
    
    print(message)
    return true
end)

-- Run the application
app:run(arg)
