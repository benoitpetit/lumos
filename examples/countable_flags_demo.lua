#!/usr/bin/env lua

-- Countable Flags Demo
-- Demonstrates -v / -vv / -vvv style flags

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local logger = require('lumos.logger')
local Middleware = require('lumos.middleware')

local app = lumos.new_app({
    name = "countable_demo",
    version = require("lumos").version,
    description = "Countable flags demo"
})

-- Global verbosity middleware: -v sets INFO, -vv DEBUG, -vvv TRACE
app:use(Middleware.builtin.verbosity(), 5)

app:command("deploy", "Deploy the application")
    :flag("-v --verbose", "Increase verbosity"):countable()
    :action(function(ctx)
        local v = ctx.flags.verbose or 0
        logger.info("Verbosity level: " .. tostring(v))

        if v >= 1 then
            logger.info("Basic info enabled")
        end
        if v >= 2 then
            logger.debug("Debug info enabled")
        end
        if v >= 3 then
            logger.trace("Trace info enabled")
        end

        print(color.green("Deployment complete"))
        return true
    end)

os.exit(app:run(arg))
