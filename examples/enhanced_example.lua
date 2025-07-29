#!/usr/bin/env lua

-- Lumos Enhanced Example
-- Demonstrates subcommands, JSON output, and input validation

package.path = package.path .. ';../lumos/?.lua;../lumos/?/init.lua'

local lumos = require('lumos')
local prompt = require('lumos.prompt')
local json = require('lumos.json')

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
                print("User: " .. user.name)
            end
        end
    else
        print("No action specified")
    end
    return true
end)

-- Add global flags
app:flag("-j --json", "Output in JSON format")

-- Utilize input validators
local email = prompt.input("Enter your email")
local valid, result = prompt.validate(email, prompt.validators.email)
if valid then
    print("Valid email: " .. result)
else
    print("Invalid email format!")
end

app:run(arg)

