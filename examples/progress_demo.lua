#!/usr/bin/env lua

-- Demonstration of the Lumos progress module
-- Shows different types of progress bars

-- Add parent directory to search path
package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local progress = require('lumos.progress')
local color = require('lumos.color')

local logger = require('lumos.logger')
local app = lumos.new_app({
    name = "progress_demo",
    version = "0.2.1",
    description = "Demonstrates the Lumos progress module"
})

local function simulate_work(duration)
    local start_time = os.clock()
    local target_duration = duration or 0.1
    while os.clock() - start_time < target_duration do
        -- Simulate work
    end
end

app:command("demo", "Run the progress demo"):action(function(ctx)
    print("=== Demonstration of the Lumos Progress module ===\n")

    -- 1. Simple progress bar
    print("1. Simple progress bar:")
    for i = 1, 10 do
        progress.simple(i, 10)
        simulate_work(0.05)
    end
    print()

    -- 2. Advanced progress bar
    print("2. Advanced progress bar:")
    local bar1 = progress.new({
        total = 20,
        width = 40,
        format = "[{bar}] {percentage}% ({current}/{total}) {eta}",
        fill = "█",
        empty = "░",
        prefix = "Processing: ",
        suffix = " Finished"
    })
    for i = 1, 20 do
        bar1:update(i)
        simulate_work(0.03)
    end
    print()

    -- 3. Different bar styles
    print("3. Different styles:")

    print("Classic style:")
    local bar_classic = progress.new({
        total = 15,
        width = 30,
        style = "classic",
        format = "Classic: [{bar}] {percentage}%"
    })
    for i = 1, 15 do
        bar_classic:update(i)
        simulate_work(0.02)
    end
    print()

    print("Unicode style:")
    local bar_unicode = progress.new({
        total = 15,
        width = 30,
        style = "unicode",
        format = "Unicode: [{bar}] {percentage}%"
    })
    for i = 1, 15 do
        bar_unicode:update(i)
        simulate_work(0.02)
    end
    print()

    print("Blocks style:")
    local bar_blocks = progress.new({
        total = 15,
        width = 30,
        style = "blocks",
        format = "Blocks: [{bar}] {percentage}%"
    })
    for i = 1, 15 do
        bar_blocks:update(i)
        simulate_work(0.02)
    end
    print()

    -- 4. Bar with dynamic colors
    print("4. Bar with dynamic colors:")
    local bar_colored = progress.new({
        total = 30,
        width = 50,
        format = "Colored: [{bar}] {percentage}%",
        color_fn = function(bar, current, total)
            local ratio = current / total
            if ratio < 0.33 then
                return color.red(bar)
            elseif ratio < 0.66 then
                return color.yellow(bar)
            else
                return color.green(bar)
            end
        end
    })
    for i = 1, 30 do
        bar_colored:update(i)
        simulate_work(0.015)
    end
    print()

    -- 5. Usage with increment
    print("5. Usage with increment:")
    local bar_increment = progress.new({
        total = 50,
        width = 40,
        format = "Incremental: [{bar}] {current}/{total}"
    })
    local batch_sizes = {5, 10, 15, 20}
    for _, batch_size in ipairs(batch_sizes) do
        for j = 1, batch_size do
            bar_increment:increment()
            simulate_work(0.01)
        end
        simulate_work(0.05)
    end
    bar_increment:finish()
    print()

    -- 6. Multiple bars in parallel (simulation)
    print("6. Multiple bars simulation:")
    print("Task A:")
    local task_a = progress.new({
        total = 8,
        format = "  A: [{bar}] {percentage}%"
    })
    print("Task B:")
    local task_b = progress.new({
        total = 12,
        format = "  B: [{bar}] {percentage}%"
    })
    for i = 1, 12 do
        if i <= 8 then
            task_a:update(i)
        end
        task_b:update(i)
        simulate_work(0.05)
    end

    print()
    print("Demonstration finished!")
    logger.info("All progress bars have been successfully tested")

    return true
end)

os.exit(app:run(arg))
