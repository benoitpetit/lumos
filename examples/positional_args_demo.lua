#!/usr/bin/env lua

-- Positional Arguments Validation Demo
-- Demonstrates required, type, min/max, default, and custom validate

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "positional_args_demo",
    version = "0.2.1",
    description = "Demonstrates positional argument validation"
})

local greet = app:command("greet", "Greet someone")

greet:arg("name", "Name to greet", {
    required = true,
    type = "string",
    validate = function(v)
        return #v >= 2
    end
})

greet:arg("count", "How many times", {
    type = "number",
    min = 1,
    max = 10,
    default = 1
})

greet:action(function(ctx)
    local name = ctx.args[1]
    local count = ctx.args[2] or 1
    for i = 1, count do
        logger.info("Hello, " .. color.cyan(name) .. "!")
    end
    return true
end)

os.exit(app:run(arg))
