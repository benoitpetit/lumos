#!/usr/bin/env lua
-- Interactive CLI Demo
-- Demonstrates Lumos prompt module: forms, wizards, autocomplete, search, and validation

local lumos = require('lumos')
local prompt = require('lumos.prompt')
local format = require('lumos.format')
local logger = require('lumos.logger')

local app = lumos.new_app({
    name = "interactive_cli",
    description = "Interactive CLI Demo",
    version = "1.0.0"
})

local cmd = app:command("run", "Run the interactive demo")

cmd:action(function()
    logger.info("=== Interactive CLI Demo ===")

    -- 1. Simple validated number input
    local age = prompt.number("Enter your age", 1, 120, 25)
    logger.info("Age: " .. tostring(age))

    -- 2. Required input with built-in validator
    local email = prompt.required_input(
        "Email address",
        prompt.validators.email,
        "Please enter a valid email"
    )
    logger.info("Email: " .. email)

    -- 3. Autocomplete from a list
    local languages = {"Lua", "Python", "JavaScript", "Go", "Rust", "Zig"}
    local favorite = prompt.autocomplete("Favorite language", languages, "Lua")
    logger.info("Favorite language: " .. favorite)

    -- 4. Searchable selection
    local tools = {"Docker", "Kubernetes", "Terraform", "Ansible", "Pulumi", "Vagrant"}
    local _, tool = prompt.search("Pick a DevOps tool", tools)
    if tool then
        logger.info("Selected tool: " .. tool)
    else
        logger.warn("No tool selected")
    end

    -- 5. Multi-step wizard
    local settings = prompt.wizard("Project Setup", {
        {
            title = "Basic Info",
            fields = {
                { name = "project", label = "Project name", type = "input", required = true },
                { name = "license", label = "License", type = "select", options = { "MIT", "Apache-2.0", "GPL-3.0" }, default = 1 },
            }
        },
        {
            title = "Configuration",
            fields = {
                { name = "port", label = "Server port", type = "number", min = 1024, max = 65535, default = 8080 },
                { name = "enable_ssl", label = "Enable SSL?", type = "confirm", default = true },
            }
        }
    })

    logger.info("--- Wizard Results ---")
    for k, v in pairs(settings) do
        logger.info(k .. " = " .. tostring(v))
    end

    -- 6. Quick form for credentials
    local creds = prompt.form("Credentials", {
        { name = "username", label = "Username", type = "input", required = true },
        { name = "password", label = "Password", type = "password" },
    })
    logger.info("Username: " .. creds.username)
    logger.info("Password: " .. string.rep("*", #creds.password))

    logger.info("Demo complete!")
    return true
end)

os.exit(app:run(arg))
