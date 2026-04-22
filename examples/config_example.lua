#!/usr/bin/env lua

-- Configuration Example using Lumos Framework
-- Demonstrates configuration loading from files and environment

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local config = require('lumos.config')

local logger = require('lumos.logger')
-- Create the application with config support
local app = lumos.new_app({
    name = "config_app",
    version = "2.0.0",
    description = "Configuration example using Lumos",
    config_file = "config.json",
    env_prefix = "CONFIG_APP"
})

-- Add global configuration flag
app:flag("--config", "Configuration file path")

-- Deploy command with configuration
local deploy = app:command("deploy", "Deploy application")
deploy:arg("target", "Deployment target")
deploy:flag_int("--timeout", "Deployment timeout in seconds", 1, 3600)
deploy:flag("--dry-run", "Show what would be deployed")

deploy:action(function(ctx)
    local target = ctx.args[1] or "production"
    
    -- Load configuration
    local configs = {}
    
    -- Try to load from config file (JSON, YAML, or TOML)
    if ctx.flags.config then
        local file_config, err = config.load_file(ctx.flags.config)
        if file_config then
            configs.file = file_config
            logger.info("Loaded config from: " .. ctx.flags.config)
        else
            logger.warn("Could not load config: " .. err)
        end
    end

    -- Demo: show that YAML configs work out of the box
    local yaml = require('lumos.yaml')
    local sample_yaml = [[
host: localhost
port: 8080
features:
  - logging
  - metrics
]]
    local yaml_config = yaml.decode(sample_yaml)
    logger.info("YAML sample host: " .. tostring(yaml_config.host))
    
    -- Load from environment
    local env_config = config.load_env("CONFIG_APP")
    if next(env_config) then
        configs.env = env_config
        logger.info("Loaded environment config")
    end
    
    -- Merge all configurations
    local merged = config.merge_configs(
        {timeout = 30}, -- defaults
        configs.file,
        configs.env,
        ctx.flags -- command line flags have highest priority
    )
    
    logger.info("Deployment Configuration:")
    logger.info("Target: " .. color.cyan(target))
    logger.warn("Timeout: " .. color.yellow(merged.timeout .. "s"))
    logger.info("Dry run: " .. (merged.dry_run and color.green("Yes") or color.dim("No")))
    
    if merged.dry_run then
        logger.info("This is a dry run - no actual deployment")
    else
        logger.info("Deploying to " .. target .. "...")
    end
    
    return true
end)

-- Run the app
os.exit(app:run(arg))
