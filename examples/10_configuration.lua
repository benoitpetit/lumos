#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local config = require("lumos.config")
local json = require("lumos.json")

local app = lumos.new_app({
    name = "config_demo",
    version = "1.0.0",
    description = "Configuration management demonstrations"
})

app:flag("-c --config", "Config file path")
app:flag("-e --env", "Environment (dev|staging|prod)"):default("dev")

local load = app:command("load", "Load configuration")

load:action(function(ctx)
    print(color.bold("=== Configuration Loading ===\n"))

    local config_file = ctx.flags.config or "config.json"

    print(color.cyan("Loading from: ") .. config_file)

    local data, err = config.load_file(config_file)
    if data then
        print(color.green("✓ Loaded successfully"))
        print("\nContent:")
        print(json.encode_pretty(data))
    else
        print(color.yellow("⚠ File not found or error"))
        print("Error: " .. tostring(err))
    end

    return true
end)

local merge = app:command("merge", "Multi-source config merge")

merge:action(function(ctx)
    print(color.bold("=== Configuration Merge ===\n"))

    local sources = {
        {source = "defaults", data = {port = 8080, debug = false, theme = "dark"}},
        {source = "file", data = {port = 3000, log_level = "debug"}},
        {source = "env", data = {debug = true, database_url = "postgres://localhost"}}
    }

    print(color.dim("Merging configuration sources:\n"))
    for _, s in ipairs(sources) do
        print(string.format("  %s: %s", color.cyan(s.source), json.encode(s.data)))
    end

    local merged = {}
    for _, s in ipairs(sources) do
        merged = config.merge(merged, s.data)
    end

    print(color.dim("\nMerged result:\n"))
    print(json.encode_pretty(merged))

    print(color.dim("\nNote: Later sources override earlier ones"))
    return true
end)

local env = app:command("env", "Environment variable loading")

env:action(function(ctx)
    print(color.bold("=== Environment Variables ===\n"))

    local prefix = "MYAPP"
    print(color.cyan("Prefix: ") .. prefix)

    local env_data = config.load_env(prefix)
    print("\nLoaded environment variables:")
    print(json.encode_pretty(env_data))

    print(color.dim("\nDemonstrating with DEMO_* variables:"))
    os.execute("DEMO_VAR1=value1 DEMO_VAR2=value2 lua -e 'print(\"env vars:\", os.getenv(\"DEMO_VAR1\"), os.getenv(\"DEMO_VAR2\"))'")

    return true
end)

local formats = app:command("formats", "Different config formats")

formats:action(function(ctx)
    print(color.bold("=== Configuration Formats ===\n"))

    local examples = {
        {
            name = "JSON",
            content = '{"port": 8080, "debug": true, "features": ["auth", "logging"]}'
        },
        {
            name = "YAML-like",
            content = 'port: 8080\ndebug: true\nfeatures:\n  - auth\n  - logging'
        },
        {
            name = "Key-Value",
            content = 'PORT=8080\nDEBUG=true\nFEATURES=auth,logging'
        },
        {
            name = "TOML-like",
            content = 'port = 8080\ndebug = true\nfeatures = ["auth", "logging"]'
        }
    }

    for _, ex in ipairs(examples) do
        print(color.cyan(ex.name) .. ":")
        print("  " .. ex.content:gsub("\n", "\n  "))
        print()
    end

    print(color.dim("Lumos config module supports: JSON, YAML, TOML, key=value"))
    return true
end)

os.exit(app:run(arg))