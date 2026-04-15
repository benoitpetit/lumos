#!/usr/bin/env lua

-- Fluent Flag Modifiers Demo
-- Demonstrates :default(), :env(), :required(), and :validate()

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "fluent_flags_demo",
    version = "0.2.0",
    description = "Demonstrates fluent flag modifiers"
})

local deploy = app:command("deploy", "Deploy application")

deploy:flag_string("-e --env", "Deployment environment")
    :default("dev")
    :env("DEPLOY_ENV")
    :required(true)
    :validate(function(v)
        return v == "dev" or v == "staging" or v == "prod"
    end)

deploy:flag_int("-p --port", "Server port", 1, 65535)
    :default(8080)

deploy:flag_email("--notify", "Notification email")
    :env("DEPLOY_NOTIFY")

deploy:action(function(ctx)
    logger.info("Environment: " .. ctx.flags.env)
    logger.info("Port: " .. tostring(ctx.flags.port))
    if ctx.flags.notify then
        logger.info("Notify: " .. ctx.flags.notify)
    end
    return true
end)

os.exit(app:run(arg))
