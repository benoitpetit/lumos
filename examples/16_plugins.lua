#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "plugin_demo",
    version = "1.0.0",
    description = "Plugin system demonstrations"
})

local function analytics_plugin(cmd, opts)
    opts = opts or {}
    local track_events = opts.track_events ~= false

    cmd:pre_run(function(ctx)
        ctx._start_time = os.clock()
        if track_events then
            print(color.dim("[analytics] Tracking: " .. ctx.command.name))
        end
    end)

    cmd:post_run(function(ctx, result, err)
        if ctx._start_time then
            local duration = os.clock() - ctx._start_time
            print(color.dim(string.format("[analytics] Duration: %.3fs", duration)))
        end
    end)

    return cmd
end

local function validation_plugin(cmd, opts)
    opts = opts or {}
    local strict = opts.strict or false

    cmd:pre_run(function(ctx)
        print(color.dim("[validation] Running pre-flight checks..."))

        if strict and not ctx.args[1] then
            error("Strict mode: arguments required")
        end
    end)

    return cmd
end

local demo = app:command("demo", "Basic plugin usage")

demo:plugin(analytics_plugin, {track_events = true})
demo:plugin(validation_plugin, {strict = false})

demo:action(function(ctx)
    print(color.green("\n✓ Main action executed with plugins"))
    return true
end)

local multi = app:command("multi", "Multiple plugins")

multi:plugin(analytics_plugin)
multi:plugin(validation_plugin)

multi:action(function(ctx)
    print(color.green("\n✓ Multi-plugin command executed"))
    return true
end)

local chain = app:command("chain", "Plugin chain on app level")

chain:plugin(function(cmd)
    cmd:pre_run(function(ctx)
        print(color.dim("[plugin-a] Before command"))
    end)
    return cmd
end)

chain:plugin(function(cmd)
    cmd:pre_run(function(ctx)
        print(color.dim("[plugin-b] Before command"))
    end)
    return cmd
end)

chain:plugin(function(cmd)
    cmd:post_run(function(ctx)
        print(color.dim("[plugin-c] After command"))
    end)
    return cmd
end)

chain:action(function(ctx)
    print(color.green("[action] Executing"))
    return true
end)

local custom = app:command("custom", "Custom plugin factory")

local function create_telemetry_plugin(options)
    options = options or {}
    local service_name = options.service or "unknown"

    return function(cmd)
        cmd:pre_run(function(ctx)
            local telemetry = {
                service = service_name,
                command = ctx.command.name,
                timestamp = os.time()
            }
            ctx._telemetry = telemetry
            print(color.cyan("[telemetry] Tracking: " .. service_name))
        end)

        cmd:post_run(function(ctx, result, err)
            if ctx._telemetry then
                local status = err and "failed" or "success"
                print(color.dim(string.format("[telemetry] %s - %s",
                    ctx._telemetry.command, status)))
            end
        end)

        return cmd
    end
end

custom:plugin(create_telemetry_plugin({service = "custom-service"}))

custom:action(function(ctx)
    print(color.green("\n✓ Custom plugin executed"))
    return true
end)

local inject = app:command("inject", "Inject functionality via plugin")

inject:plugin(function(cmd)
    local original_action = cmd.action

    cmd:action(function(ctx)
        print(color.dim("[inject] Before original action"))

        local result = original_action(ctx)

        print(color.dim("[inject] After original action"))

        return result
    end)
end)

inject:action(function(ctx)
    print(color.bold("  [original] Main action!"))
    return true
end)

os.exit(app:run(arg))