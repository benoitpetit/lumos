#!/usr/bin/env lua

-- Plugin System Demo
-- Demonstrates lumos.use() and command:use()

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "plugin_demo",
    version = require("lumos").version,
    description = "Demonstrates the Lumos plugin system"
})

-- Define a reusable plugin
local debug_plugin = function(target, opts)
    target:flag("--debug", "Enable debug output")
    if opts and opts.verbose then
        target:flag("--trace", "Enable trace output")
    end
end

-- Apply plugin globally
lumos.use(app, debug_plugin, {verbose = true})

-- Define another plugin as a table
local logging_plugin = {
    init = function(target, opts)
        target:pre_run(function(ctx)
            logger.info("[log] Running command...")
        end)
    end
}

-- Chain plugin on a command
local deploy = app:command("deploy", "Deploy app")
    :plugin(logging_plugin)

deploy:action(function(ctx)
    if ctx.flags.debug then
        logger.debug("Debug mode enabled")
    end
    if ctx.flags.trace then
        logger.debug("Trace mode enabled")
    end
    logger.info("Deploying...")
    return true
end)

os.exit(app:run(arg))
