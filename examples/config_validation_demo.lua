#!/usr/bin/env lua

-- Config Schema Validation Demo
-- Demonstrates validate_schema() and load_validated()

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local config = require('lumos.config')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "config_validation_demo",
    version = "0.2.2",
    description = "Demonstrates config schema validation"
})

app:command("demo", "Run the validation demo"):action(function(ctx)
    local schema = {
        host = { required = true, type = "string" },
        port = { type = "number", validate = function(v) return v > 0 and v < 65536 end },
        debug = { type = "boolean" }
    }

    -- Validate an in-memory table
    local settings = { host = "localhost", port = 8080, debug = false }
    local ok, errors = config.validate_schema(settings, schema)

    if not ok then
        logger.error("Validation failed: " .. table.concat(errors, "; "))
        return false
    end

    logger.info("Config is valid!")
    logger.info("Host: " .. settings.host)
    logger.info("Port: " .. settings.port)

    return true
end)

os.exit(app:run(arg))
