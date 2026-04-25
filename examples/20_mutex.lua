#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "mutex_demo",
    version = "1.0.0",
    description = "Demonstrates mutually exclusive flags"
})

local deploy = app:command("deploy", "Deploy application")

deploy:flag_string("-e --env", "Target environment", {
    choices = {"staging", "production"}
})
deploy:flag_string("-f --file", "Deploy from file")
deploy:flag_string("-u --url", "Deploy from URL")

-- Make --file and --url mutually exclusive
deploy:mutex_group("source", {"file", "url"})

deploy:action(function(ctx)
    if ctx.flags.env then
        print("Environment: " .. color.cyan(ctx.flags.env))
    end
    if ctx.flags.file then
        print("Deploy from file: " .. color.cyan(ctx.flags.file))
    end
    if ctx.flags.url then
        print("Deploy from URL: " .. color.cyan(ctx.flags.url))
    end
    return true
end)

os.exit(app:run(arg))
