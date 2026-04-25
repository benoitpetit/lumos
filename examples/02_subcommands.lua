#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "project_manager",
    version = "1.0.0",
    description = "Manage projects with subcommands"
})

app:flag("-j --json", "JSON output")
app:flag("-v --verbose", "Verbose output")

local project = app:command("project", "Project operations")

local create = project:subcommand("create", "Create a new project")
create:arg("name", "Project name"):required(true)
create:arg("template", "Project template"):default("default")
create:flag("-d --dir", "Target directory")
create:flag("--public", "Make project public")

create:action(function(ctx)
    print("Creating project: " .. color.cyan(ctx.args[1]))
    print("Template: " .. ctx.args[2])
    print("Directory: " .. (ctx.flags.dir or "current"))
    print("Public: " .. tostring(ctx.flags.public))
    return true
end)

local list = project:subcommand("list", "List all projects")
list:flag("-a --all", "Show all projects")
list:flag("--limit", "Limit number of results"):default(10)

list:action(function(ctx)
    local projects = {
        {name = "alpha", status = "active", stars = 42},
        {name = "beta", status = "archived", stars = 12},
        {name = "gamma", status = "active", stars = 156}
    }
    if ctx.flags.json then
        print(require("lumos.json").encode(projects))
    else
        for _, p in ipairs(projects) do
            print(string.format("  %s [%s] ★ %d",
                color.cyan(p.name), p.status, p.stars))
        end
    end
    return true
end)

local delete = project:subcommand("delete", "Delete a project")
delete:arg("name", "Project name"):required(true)
delete:flag("-f --force", "Skip confirmation")

delete:action(function(ctx)
    print("Deleting project: " .. color.red(ctx.args[1]))
    return true
end)

local info = project:subcommand("info", "Show project details")
info:arg("name", "Project name"):required(true)
info:flag("--wide", "Show extended info")

info:action(function(ctx)
    print("Project: " .. color.cyan(ctx.args[1]))
    print("Status: active")
    print("Created: 2024-01-15")
    return true
end)

os.exit(app:run(arg))