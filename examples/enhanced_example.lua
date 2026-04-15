#!/usr/bin/env lua

-- Lumos Enhanced Example
-- Demonstrates subcommands, JSON output, and input validation

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local prompt = require('lumos.prompt')
local json = require('lumos.json')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "enhanced_app",
    version = "2.0.0",
    description = "Enhanced Lumos App with new features"
})

-- Define a command (simplified without subcommands for now)
local users_cmd = app:command("users", "Manage users")
users_cmd:flag("-l --list", "List all users")

users_cmd:action(function(ctx)
    if ctx.flags.list then
        local users = {{name = "Alice"}, {name = "Bob"}}
        if ctx.flags.json then
            print(json.encode(users))
        else
            for _, user in ipairs(users) do
                logger.info("User: " .. user.name)
            end
        end
    else
        logger.info("No action specified")
    end
    return true
end)

-- Command demonstrating input validation
local validate_cmd = app:command("validate", "Validate an email address")
validate_cmd:flag("-e --email", "Email to validate (interactive prompt if omitted)")

validate_cmd:action(function(ctx)
    local email = ctx.flags.email
    if not email or email == "" then
        email = prompt.input("Enter your email")
    end

    -- Guard against nil/empty input (e.g. EOF in non-interactive mode)
    if not email or email == "" then
        logger.info("No email provided.")
        return false
    end

    local valid, result = prompt.validate(email, prompt.validators.email)
    if valid then
        logger.info("Valid email: " .. result)
    else
        logger.info("Invalid email format!")
    end
    return valid
end)

-- Add global flags
app:flag("-j --json", "Output in JSON format")

os.exit(app:run(arg))
