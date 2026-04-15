#!/usr/bin/env lua

-- Typed Flags Example
-- Demonstrates advanced flag types with validation

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
-- Create the application
local app = lumos.new_app({
    name = "typed_flags_demo",
    version = "0.1.0",
    description = "Demonstrates typed flags with validation"
})

-- Create command with typed flags
local create = app:command("create", "Create a resource with validated inputs")
create:arg("name", "Resource name")

-- Different flag types with validation
create:flag_int("--port", "Port number", 1, 65535)
create:flag_int("--timeout", "Timeout in seconds", 1, 3600)
create:flag_email("--email", "Contact email address")
create:flag("--force", "Force creation without confirmation")

create:examples({
    "typed_flags_demo create myapp --port 8080 --email admin@example.com",
    "typed_flags_demo create webapp --port 3000 --timeout 30 --force"
})

create:action(function(ctx)
    local name = ctx.args[1]
    if not name then
        logger.error("Error: Resource name is required")
        return false
    end
    
    -- Display validated inputs
    logger.info(color.bold("Creating resource: " .. color.cyan(name)))
    
    if ctx.flags.port then
        logger.warn("Port: " .. color.yellow(ctx.flags.port))
    end
    
    if ctx.flags.timeout then
        logger.warn("Timeout: " .. color.yellow(ctx.flags.timeout .. "s"))
    end
    
    if ctx.flags.email then
        logger.info("Email: " .. color.green(ctx.flags.email))
    end
    
    if ctx.flags.force then
        logger.warn("Force mode enabled")
    end
    
    logger.info("✓ Resource created successfully!")
    return true
end)

-- Run the app
os.exit(app:run(arg))
