#!/usr/bin/env lua

-- Demonstration of the Lumos loader module
-- Shows different loader styles and statuses

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local loader = require('lumos.loader')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "loader_demo",
    version = require("lumos").version,
    description = "Demonstrates the Lumos loader module"
})

local function simulate_work(duration)
    local start_time = os.clock()
    local target_duration = duration or 0.1
    while os.clock() - start_time < target_duration do
        -- Simulate work
    end
end

app:command("demo", "Run the loader demo"):action(function(ctx)
    print("=== Demonstration of the Lumos Loader module ===\n")

    -- 1. Standard loader with success
    print("1. Standard loader with success:")
    loader.start("Database connection", "standard")
    for i = 1, 15 do
        loader.next()
        simulate_work(0.1)
    end
    loader.success()
    print()

    -- 2. Dots loader with failure
    print("2. Dots loader with failure:")
    loader.start("File download", "dots")
    for i = 1, 8 do
        loader.next()
        simulate_work(0.15)
    end
    loader.fail()
    print()

    -- 3. Bounce loader with stop
    print("3. Bounce loader with stop:")
    loader.start("Data processing", "bounce")
    for i = 1, 6 do
        loader.next()
        simulate_work(0.12)
    end
    loader.stop()
    print()

    -- 4. Simulation of multiple tasks
    print("4. Simulation of multiple tasks:")
    local tasks = {
        {message = "System initialization", style = "standard", duration = 0.08, iterations = 12, result = "success"},
        {message = "Module loading", style = "dots", duration = 0.1, iterations = 10, result = "success"},
        {message = "Permission check", style = "bounce", duration = 0.06, iterations = 15, result = "success"},
        {message = "Network configuration", style = "standard", duration = 0.12, iterations = 8, result = "fail"},
        {message = "Saving parameters", style = "dots", duration = 0.09, iterations = 11, result = "success"},
    }

    for _, task in ipairs(tasks) do
        loader.start(task.message, task.style)
        for i = 1, task.iterations do
            loader.next()
            simulate_work(task.duration)
        end
        if task.result == "success" then
            loader.success()
        elseif task.result == "fail" then
            loader.fail()
        else
            loader.stop()
        end
    end

    print()
    print("5. Demonstration of different loader styles:")

    print("\n   STANDARD style:")
    loader.start("   Standard example", "standard")
    for i = 1, 8 do
        loader.next()
        simulate_work(0.1)
    end
    loader.success()

    print("\n   DOTS style:")
    loader.start("   Dots example", "dots")
    for i = 1, 8 do
        loader.next()
        simulate_work(0.1)
    end
    loader.success()

    print("\n   BOUNCE style:")
    loader.start("   Bounce example", "bounce")
    for i = 1, 8 do
        loader.next()
        simulate_work(0.1)
    end
    loader.success()

    print()
    print("=== Feature summary ===\n")
    print(color.bold("Available styles:"))
    print("  • standard : | / - \\")
    print("  • dots     : .   ..  ...")
    print("  • bounce   : ◜ ◠ ◝ ◞ ◡ ◟")
    print()
    print(color.bold("Available methods:"))
    print("  • loader.start(message, style) - Starts a loader")
    print("  • loader.next()                 - Animates the loader")
    print("  • loader.success()              - Ends with success")
    print("  • loader.fail()                 - Ends with failure")
    print("  • loader.stop()                 - Stops the loader")
    print()
    logger.info("Loader demonstration completed successfully!")

    return true
end)

os.exit(app:run(arg))
