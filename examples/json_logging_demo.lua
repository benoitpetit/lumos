#!/usr/bin/env lua

-- JSON Logging & Quiet Mode Demo
-- Demonstrates JSON-formatted logs and global --quiet flag

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local logger = require('lumos.logger')

local app = lumos.new_app({
    name = "logging_demo",
    version = require("lumos").version,
    description = "JSON logging and quiet mode demo"
})

app:command("run", "Run a task with structured logging")
    :flag("--json", "Output logs as JSON")
    :action(function(ctx)
        if ctx.flags.json then
            logger.set_format("json")
        end

        logger.info("Task started", { task = "demo", pid = 42 })
        logger.warn("Low disk space", { percent = 12 })
        logger.debug("This is a debug message")
        logger.error("Something went wrong", { detail = "connection refused" })

        if ctx.flags.json then
            logger.set_format("text")
        end

        return true
    end)

app:command("quiet-check", "Show that quiet mode suppresses output")
    :action(function(ctx)
        -- When the user passes --quiet, only errors reach the terminal
        logger.info("This info is hidden in quiet mode")
        logger.warn("This warn is hidden in quiet mode")
        logger.error("This error is always shown")
        return true
    end)

os.exit(app:run(arg))
