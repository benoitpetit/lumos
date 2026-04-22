#!/usr/bin/env lua

-- YAML Config Demo
-- Demonstrates YAML parsing, anchors, and aliases

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local yaml = require('lumos.yaml')
local color = require('lumos.color')
local logger = require('lumos.logger')

local app = lumos.new_app({
    name = "yaml_demo",
    version = require("lumos").version,
    description = "YAML configuration demo"
})

app:command("parse", "Parse a YAML string")
    :action(function(ctx)
        local doc = [[
defaults: &defaults
  adapter: postgres
  host: localhost

primary: &main
  name: web1
  port: 80

secondary: &backup
  name: web2
  port: 8080

copy_main: *main
copy_backup: *backup
]]
        local data = yaml.decode(doc)

        logger.info("YAML Anchors & Aliases:")
        logger.info("  defaults.adapter = " .. color.cyan(tostring(data.defaults.adapter)))
        logger.info("  copy_main.name (aliased) = " .. color.cyan(tostring(data.copy_main.name)))
        logger.info("  copy_backup.port (aliased) = " .. color.cyan(tostring(data.copy_backup.port)))

        return true
    end)

app:command("encode", "Encode a Lua table to YAML")
    :action(function(ctx)
        local data = {
            name = "lumos",
            version = "0.3.7",
            features = { "cli", "middleware", "yaml" }
        }
        local encoded = yaml.encode(data)
        print(color.green("Encoded YAML:"))
        print(encoded)
        return true
    end)

os.exit(app:run(arg))
