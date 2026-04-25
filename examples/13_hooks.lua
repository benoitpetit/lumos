#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "hooks_demo",
    version = "1.0.0",
    description = "Pre/post run hooks demonstrations"
})

app:flag("-v --verbose", "Verbose output")

local demo = app:command("demo", "Hook execution demo")

demo:pre_run(function(ctx)
    print(color.dim("[pre_run] Preparing command execution..."))
    print(color.dim("  args: " .. table.concat(ctx.args or {}, ", ")))
    print(color.dim("  flags: " .. require("lumos.json").encode(ctx.flags)))
end)

demo:post_run(function(ctx, result, err)
    if err then
        print(color.red("\n[post_run] Command failed: " .. tostring(err)))
    else
        print(color.green("\n[post_run] Command completed successfully"))
    end
    print(color.dim("  result: " .. tostring(result)))
end)

demo:action(function(ctx)
    print(color.bold("\n[action] Executing main command logic..."))
    print("  Processing: " .. color.cyan(ctx.args[1] or "default"))
    return true
end)

local persistent = app:command("persistent", "Persistent hooks across commands")

persistent:persistent_pre_run(function(ctx)
    print(color.cyan("\n[persistent_pre_run] Running before any command"))
    print("  Command: " .. ctx.command.name)
end)

persistent:persistent_post_run(function(ctx, result, err)
    print(color.cyan("[persistent_post_run] Running after any command"))
    print("  Duration: logged")
end)

persistent:subcommand("cmd1", "First command"):action(function(ctx)
    print(color.green("\n[cmd1] Executed"))
    return true
end)

persistent:subcommand("cmd2", "Second command"):action(function(ctx)
    print(color.green("\n[cmd2] Executed"))
    return true
end)

local lifecycle = app:command("lifecycle", "Full lifecycle demo")

lifecycle:pre_run(function(ctx)
    print(color.dim("[1/4] Pre-run: validating inputs"))
end)

lifecycle:use(function(ctx, next)
    print(color.dim("[2/4] Middleware: authentication check"))
    return next()
end, 50)

lifecycle:use(function(ctx, next)
    print(color.dim("[3/4] Middleware: logging request"))
    return next()
end, 60)

lifecycle:post_run(function(ctx, result, err)
    print(color.dim("[4/4] Post-run: cleanup and finalization"))
end)

lifecycle:action(function(ctx)
    print(color.green("\n✓ Main action executed"))
    return true
end)

os.exit(app:run(arg))