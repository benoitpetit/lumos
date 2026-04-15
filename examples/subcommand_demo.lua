#!/usr/bin/env lua

-- Lumos Subcommand Demo
-- Demonstrates subcommand functionality

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local json = require('lumos.json')

local logger = require('lumos.logger')
-- Create app
local app = lumos.new_app({
    name = "subcmd_demo",
    version = "2.0.0",
    description = "Demonstrates subcommand functionality"
})

-- Add global JSON flag
app:flag("-j --json", "Output in JSON format")

-- User management command with subcommands
local user_cmd = app:command("user", "User management operations")

-- Create subcommand
local create_user = user_cmd:subcommand("create", "Create a new user")
create_user:arg("username", "Username for the new user")
create_user:flag("-a --admin", "Grant admin privileges")

create_user:action(function(ctx)
    local username = ctx.args[1]
    if not username then
        logger.error("Error: Username required")
        return false
    end
    
    local user_data = {
        username = username,
        admin = ctx.flags.admin or false,
        created = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    if ctx.flags.json then
        print(json.encode(user_data))
    else
        logger.info("✓ User created successfully:")
        logger.info("  Username: " .. color.cyan(user_data.username))
        logger.warn("  Admin: " .. (user_data.admin and color.yellow("Yes") or "No"))
        logger.info("  Created: " .. color.dim(user_data.created))
    end
    
    return true
end)

-- List subcommand
local list_users = user_cmd:subcommand("list", "List all users")
list_users:action(function(ctx)
    local users = {
        {username = "alice", admin = true},
        {username = "bob", admin = false},
        {username = "charlie", admin = false}
    }
    
    if ctx.flags.json then
        print(json.encode(users))
    else
        logger.info("Users:")
        for _, user in ipairs(users) do
            local admin_badge = user.admin and color.yellow(" [ADMIN]") or ""
            logger.info("• " .. color.cyan(user.username) .. admin_badge)
        end
    end
    
    return true
end)

-- Run the app
os.exit(app:run(arg))
