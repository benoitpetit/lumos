#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local config = require("lumos.config")

local app = lumos.new_app({
    name = "lua_config_demo",
    version = "1.0.0",
    description = "Demonstrates native Lua configuration files"
})

-- Create a temporary Lua config file
local tmp_config = os.tmpname() .. ".lua"
do
    local f = io.open(tmp_config, "w")
    f:write([[return {
    host = "localhost",
    port = 8080,
    features = {
        logging = true,
        cache = false
    },
    tags = {"dev", "api"}
}]])
    f:close()
end

local load = app:command("load", "Load Lua config")
load:action(function(ctx)
    local cfg, err = config.load_file(tmp_config)
    if not cfg then
        print(color.red("Error: " .. tostring(err)))
        return false
    end

    print(color.bold("Loaded Lua config:"))
    print("  host: " .. color.cyan(cfg.host))
    print("  port: " .. color.cyan(tostring(cfg.port)))
    print("  logging: " .. color.cyan(tostring(cfg.features.logging)))
    print("  tags: " .. color.cyan(table.concat(cfg.tags, ", ")))

    os.remove(tmp_config)
    return true
end)

os.exit(app:run(arg))
