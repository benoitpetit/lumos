#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local logger = require("lumos.logger")

local app = lumos.new_app({
    name = "logging_demo",
    version = "1.0.0",
    description = "Logger demonstrations"
})

app:flag("-j --json", "JSON output format")
app:flag("-v --verbose", "Verbose logging")
app:countable()

local basic = app:command("basic", "Basic logging")

basic:action(function(ctx)
    print(color.bold("=== Basic Logging ===\n"))

    local levels = {"trace", "debug", "info", "warn", "error"}
    for _, level in ipairs(levels) do
        logger.set_level(level:upper())
        logger.trace("This is a " .. level .. " message")
        logger.debug("This is a " .. level .. " message")
        logger.info("This is a " .. level .. " message")
        logger.warn("This is a " .. level .. " message")
        logger.error("This is a " .. level .. " message")
        print()
    end

    logger.set_level("INFO")
    return true
end)

local structured = app:command("structured", "Structured logging")

structured:action(function(ctx)
    print(color.bold("=== Structured Logging ===\n"))

    logger.info("User logged in", {
        user_id = 12345,
        username = "alice",
        ip = "192.168.1.100",
        user_agent = "Mozilla/5.0"
    })

    logger.warn("Request rate high", {
        current_rps = 1500,
        threshold = 1000,
        duration_seconds = 30
    })

    logger.error("Database connection failed", {
        host = "db.example.com",
        port = 5432,
        error_code = "ECONNREFUSED",
        retry_count = 3
    })

    print(color.dim("\nHint: Use --json flag to see JSON output"))
    return true
end)

local json_format = app:command("json", "JSON log format")

json_format:flag("-f --file", "Log to file")

json_format:action(function(ctx)
    print(color.bold("=== JSON Logging ===\n"))

    local log_entry = {
        timestamp = os.date("%Y-%m-%dT%H:%M:%SZ"),
        level = "INFO",
        message = "Application started",
        metadata = {
            version = "1.0.0",
            environment = "production",
            pid = require("lumos.platform").get_pid()
        }
    }

    print(color.cyan("JSON Output:"))
    print(require("lumos.json").encode_pretty(log_entry))

    return true
end)

local levels = app:command("levels", "Log level management")

levels:action(function(ctx)
    print(color.bold("=== Log Levels ===\n"))

    local levels = {
        {name = "TRACE", color = color.dim},
        {name = "DEBUG", color = color.magenta},
        {name = "INFO", color = color.green},
        {name = "WARN", color = color.yellow},
        {name = "ERROR", color = color.red}
    }

    for _, lvl in ipairs(levels) do
        local marker = "●"
        print(string.format("  %s %s %s", color.dim(marker), lvl.color(lvl.name), color.dim("- " .. lvl.name:lower() .. " messages")))
    end

    print()
    print("Current level: " .. color.cyan(logger.get_level()))

    return true
end)

os.exit(app:run(arg))