#!/usr/bin/env lua

-- Advanced Lumos Example
-- Demonstrates all enhanced features

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local prompt = require('lumos.prompt')
local progress = require('lumos.progress')
local json = require('lumos.json')

local logger = require('lumos.logger')
-- Create enhanced app
local app = lumos.new_app({
    name = "advanced_cli",
    version = "2.0.0",
    description = "Advanced CLI demonstrating Lumos enhancements"
})

-- Add global flags
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
        logger.error("Username required")
        return false
    end
    
    -- Interactive prompts with validation
    local email = prompt.input("Enter email address")
    local valid_email, _ = prompt.validate(email, prompt.validators.email, "Invalid email format")
    
    if not valid_email then
        logger.error(_)
        return false
    end
    
    local age = prompt.input("Enter age:")
    local valid_age, _ = prompt.validate(age, prompt.validators.number, "Age must be a number")
    
    if not valid_age then
        logger.error(_)
        return false
    end
    
    local confirm = prompt.confirm("Create user with these details?", true)
    if not confirm then
        logger.info("User creation cancelled")
        return true
    end
    
    -- Simulate user creation with progress bar
    local bar = progress.new({
        total = 100,
        width = 40,
        format = "[{bar}] {percentage}% Creating user..."
    })
    
    for i = 1, 100, 10 do
        bar:update(i)
        os.execute("sleep 0.1") -- Simulate work
    end
    bar:finish()
    
    local user_data = {
        username = username,
        email = email,
        age = tonumber(age),
        admin = ctx.flags.admin or false,
        created = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    if ctx.flags.json then
        print(json.encode(user_data))
    else
        logger.info("User created successfully:")
        logger.info("  Username: " .. color.cyan(user_data.username))
        logger.info("  Email: " .. color.cyan(user_data.email))
        logger.info("  Age: " .. color.cyan(tostring(user_data.age)))
        logger.warn("  Admin: " .. (user_data.admin and color.yellow("Yes") or "No"))
        logger.info("  Created: " .. color.dim(user_data.created))
    end
    
    return true
end)

-- List subcommand
local list_users = user_cmd:subcommand("list", "List all users")
list_users:flag("-f --format", "Output format (table|json)")

list_users:action(function(ctx)
    local users = {
        {username = "alice", email = "alice@example.com", admin = true},
        {username = "bob", email = "bob@example.com", admin = false},
        {username = "charlie", email = "charlie@example.com", admin = false}
    }
    
    if ctx.flags.json or ctx.flags.format == "json" then
        print(json.encode(users))
    else
        logger.info("Users:")
        for _, user in ipairs(users) do
            local admin_badge = user.admin and color.yellow(" [ADMIN]") or ""
            logger.info("• " .. color.cyan(user.username) .. " (" .. user.email .. ")" .. admin_badge)
        end
    end
    
    return true
end)

-- Config command with nested subcommands
local config_cmd = app:command("config", "Configuration management")
local config_set = config_cmd:subcommand("set", "Set configuration value")
config_set:arg("key", "Configuration key")
config_set:arg("value", "Configuration value")

config_set:action(function(ctx)
    local key = ctx.args[1]
    local value = ctx.args[2]
    
    if not key or not value then
        logger.error("Both key and value are required")
        return false
    end
    
    local config_data = {key = key, value = value, updated = os.date("%Y-%m-%d %H:%M:%S")}
    
    if ctx.flags.json then
        print(json.encode(config_data))
    else
        logger.info("Configuration updated:")
        logger.info("  " .. color.bold(key) .. " = " .. color.cyan(value))
    end
    
    return true
end)

-- Interactive command demonstrating all prompt types
local interactive_cmd = app:command("interactive", "Interactive demo")

interactive_cmd:action(function(ctx)
    logger.info("=== Interactive Demo ===")
    
    -- Text input
    local name = prompt.input("What's your name?", "Anonymous")
    logger.info("Hello, " .. color.green(name) .. "!")
    
    -- Email validation
    local email
    repeat
        email = prompt.input("Enter your email")
        local valid, error_msg = prompt.validate(email, prompt.validators.email, "Please enter a valid email address")
        if not valid then
            logger.error(color.red(error_msg))
        else
            break
        end
    until false
    
    -- Number validation
    local age
    repeat
        age = prompt.input("Enter your age")
        local valid, error_msg = prompt.validate(age, prompt.validators.number, "Please enter a valid number")
        if not valid then
            logger.error(color.red(error_msg))
        else
            age = tonumber(age)
            break
        end
    until false
    
    -- Confirmation
    local newsletter = prompt.confirm("Subscribe to newsletter?", false)
    
    -- Selection
    local languages = {"Lua", "Python", "JavaScript", "Go", "Rust"}
    logger.info("Choose your favorite programming language:")
    local choice, language = prompt.select("Select", languages, 1)
    
    -- Multi-selection
    logger.info("Select your skills (use space to select, enter to confirm):")
    local skills = {"Programming", "Design", "Marketing", "Management", "Testing"}
    local selected_skills = prompt.multiselect("Skills", skills)
    
    -- Summary
    local summary = {
        name = name,
        email = email,
        age = age,
        newsletter = newsletter,
        favorite_language = language,
        skills = {}
    }
    
    for _, skill in ipairs(selected_skills) do
        table.insert(summary.skills, skill.value)
    end
    
    if ctx.flags.json then
        print(json.encode(summary))
    else
        logger.info("\n=== Summary ===")
        logger.info("Name: " .. color.cyan(summary.name))
        logger.info("Email: " .. color.cyan(summary.email))
        logger.info("Age: " .. color.cyan(tostring(summary.age)))
        logger.error("Newsletter: " .. (summary.newsletter and color.green("Yes") or color.red("No")))
        logger.warn("Favorite Language: " .. color.yellow(summary.favorite_language))
        logger.info("Skills: " .. color.magenta(table.concat(summary.skills, ", ")))
    end
    
    return true
end)

-- Run the application
os.exit(app:run(arg))
