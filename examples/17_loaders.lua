#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local loader = require("lumos.loader")

local app = lumos.new_app({
    name = "loader_demo",
    version = "1.0.0",
    description = "Loading animation demonstrations"
})

-- List all built-in styles
local styles = loader.get_styles()

-- Build a lookup set for fast validation
local style_set = {}
for _, name in ipairs(styles) do
    style_set[name] = true
end

-- Simple spinner demo
local basic = app:command("basic", "Basic spinner cycle")
basic:flag_string("-s --style", "Spinner style"):default("standard")

basic:action(function(ctx)
    local style = ctx.flags.style
    if not style_set[style] then
        print(color.red("Unknown style: " .. tostring(style)))
        print("Available: " .. table.concat(styles, ", "))
        return false
    end

    print(color.bold("=== Basic Spinner ===\n"))
    print("Style: " .. color.cyan(style) .. "\n")

    loader.start("Processing", style)
    for i = 1, 20 do
        loader.next()
        os.execute("sleep 0.1")
    end
    loader.success()

    return true
end)

-- Showcase all styles
local showcase = app:command("showcase", "Show all spinner styles")

showcase:action(function(ctx)
    print(color.bold("=== Style Showcase ===\n"))

    for _, name in ipairs(styles) do
        loader.start("Style: " .. color.yellow(name), name)
        for i = 1, 8 do
            loader.next()
            os.execute("sleep 0.08")
        end
        loader.clear()
    end

    print(color.green("✓ All styles shown"))
    return true
end)

-- Dynamic message updates
local dynamic = app:command("dynamic", "Update message on the fly")

dynamic:action(function(ctx)
    print(color.bold("=== Dynamic Message ===\n"))

    loader.start("Step 1: Connecting")
    for i = 1, 5 do
        loader.next()
        os.execute("sleep 0.1")
    end

    loader.update("Step 2: Authenticating")
    for i = 1, 5 do
        loader.next()
        os.execute("sleep 0.1")
    end

    loader.update("Step 3: Fetching data")
    for i = 1, 5 do
        loader.next()
        os.execute("sleep 0.1")
    end

    loader.success()
    return true
end)

-- Status outcomes demo
local outcomes = app:command("outcomes", "Success, fail, warning, info")

outcomes:action(function(ctx)
    print(color.bold("=== Status Outcomes ===\n"))

    -- Success
    loader.start("Saving configuration")
    for i = 1, 5 do loader.next(); os.execute("sleep 0.05") end
    loader.success()

    -- Fail
    loader.start("Uploading to remote")
    for i = 1, 5 do loader.next(); os.execute("sleep 0.05") end
    loader.fail()

    -- Warning
    loader.start("Checking disk space")
    for i = 1, 5 do loader.next(); os.execute("sleep 0.05") end
    loader.warning("Disk 90% full")

    -- Info
    loader.start("Running diagnostics")
    for i = 1, 5 do loader.next(); os.execute("sleep 0.05") end
    loader.info("No issues found")

    -- Clear (silent)
    loader.start("Silent operation")
    for i = 1, 3 do loader.next(); os.execute("sleep 0.05") end
    loader.clear()
    print(color.dim("  (cleared without marker)"))

    return true
end)

-- Automatic run() wrapper
local run = app:command("run", "Run wrapper demo")

run:action(function(ctx)
    print(color.bold("=== loader.run() Wrapper ===\n"))

    local result = loader.run(function(ld)
        -- fn receives the loader, can call update if desired
        for i = 1, 3 do
            ld:next()
            os.execute("sleep 0.1")
        end
        return 42
    end, "Computing answer", "dots2")

    print("Result: " .. color.cyan(tostring(result)))

    -- Demonstrate failure path
    print(color.dim("\nSimulating failure..."))
    local ok, err = pcall(function()
        loader.run(function()
            error("Something went wrong")
        end, "Risky operation")
    end)

    if not ok then
        print(color.dim("Caught: " .. tostring(err)))
    end

    return true
end)

-- Change style on the fly
local switch = app:command("switch", "Switch style mid-animation")

switch:action(function(ctx)
    print(color.bold("=== Style Switching ===\n"))

    loader.start("Initial style", "standard")
    for i = 1, 6 do
        loader.next()
        os.execute("sleep 0.08")
    end

    loader.set_style("dots2")
    for i = 1, 6 do
        loader.next()
        os.execute("sleep 0.08")
    end

    loader.set_style("bounce")
    for i = 1, 6 do
        loader.next()
        os.execute("sleep 0.08")
    end

    loader.success()
    return true
end)

-- Multiple independent loader instances
local instances = app:command("instances", "Multiple concurrent loaders")

instances:action(function(ctx)
    print(color.bold("=== Independent Instances ===\n"))

    local ld1 = loader.new("Uploading file", "arrow")
    local ld2 = loader.new("Indexing database", "dots2")

    ld1:start()
    ld2:start()

    for i = 1, 6 do
        ld1:next()
        ld2:next()
        os.execute("sleep 0.08")
    end

    ld1:success()
    ld2:warning("Index rebuilt with conflicts")

    return true
end)

os.exit(app:run(arg))
