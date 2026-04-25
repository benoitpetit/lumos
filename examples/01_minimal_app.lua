#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "greeting",
    version = "1.0.0",
    description = "A minimal Lumos application"
})

app:flag("-v --verbose", "Enable verbose output")

local greet = app:command("greet", "Greet someone")
greet:arg("name", "Name of the person"):required(true)
greet:flag("-u --uppercase", "Uppercase output")
greet:flag("-c --color", "Color output")

greet:action(function(ctx)
    local msg = "Hello, " .. ctx.args[1] .. "!"
    if ctx.flags.uppercase then msg = msg:upper() end
    if ctx.flags.color then msg = color.green(msg) end
    print(msg)
    return true
end)

local about = app:command("about", "Show application info")
about:action(function(ctx)
    print(color.cyan("greeting v1.0.0") .. " - A minimal Lumos application")
    return true
end)

os.exit(app:run(arg))