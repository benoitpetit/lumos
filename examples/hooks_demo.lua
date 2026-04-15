#!/usr/bin/env lua

-- Hooks & Exit Codes Demo
-- Demonstrates pre_run / post_run hooks and standard exit codes

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "hooks_demo",
    version = "0.2.0",
    description = "Demonstrates hooks and exit codes"
})

-- Global persistent hooks
app:persistent_pre_run(function(ctx)
    logger.info("[global] Setup before every command")
end)

app:persistent_post_run(function(ctx)
    logger.info("[global] Teardown after every command")
end)

-- Deploy command with per-command hooks
local deploy = app:command("deploy", "Deploy the application")

deploy:pre_run(function(ctx)
    logger.debug("[pre_run] Checking deployment prerequisites...")
end)

deploy:post_run(function(ctx)
    logger.info("[post_run] Deployment cleanup done.")
end)

deploy:action(function(ctx)
    logger.info("Deploying...")
    return true
end)

-- A command that simulates failure to show exit code behavior
local fail = app:command("fail", "Simulate an error")
fail:action(function(ctx)
    logger.error("Something went wrong!")
    return false
end)

-- Run and propagate the exit code
os.exit(app:run(arg))
