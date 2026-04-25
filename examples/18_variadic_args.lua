#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "variadic_demo",
    version = "1.0.0",
    description = "Demonstrates variadic positional arguments"
})

-- Copy command with one destination and multiple sources
local copy = app:command("copy", "Copy files to a destination")
copy:arg("dest", "Destination directory", {required = true})
copy:arg("sources", "Source files", {variadic = true, required = true})

copy:action(function(ctx)
    local dest = ctx.args[1]
    local sources = ctx.args[2]

    print(color.bold("Destination: ") .. color.cyan(dest))
    print(color.bold("Sources:"))
    for _, src in ipairs(sources) do
        print("  - " .. src)
    end
    return true
end)

-- List command with optional variadic files
local list = app:command("list", "List given files (or all if none)")
list:arg("files", "Files to list", {variadic = true})

list:action(function(ctx)
    local files = ctx.args[1] or {}
    if #files == 0 then
        print(color.dim("No files specified."))
    else
        print(color.bold("Files:"))
        for _, f in ipairs(files) do
            print("  " .. f)
        end
    end
    return true
end)

os.exit(app:run(arg))
