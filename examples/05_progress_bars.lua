#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local progress = require("lumos.progress")

local app = lumos.new_app({
    name = "progress_demo",
    version = "1.0.0",
    description = "Progress bar demonstrations"
})

local basic = app:command("basic", "Basic progress bar")
basic:flag_int("-w --width", "Bar width", 10, 100):default(50)
basic:flag_string("--style", "Bar style (classic|unicode|blocks)"):default("classic")

basic:action(function(ctx)
    print(color.bold("=== Basic Progress Bar ===\n"))

    local bar = progress.new({
        total = 100,
        width = tonumber(ctx.flags.width) or 50,
        format = "[{bar}] {percentage}% {current}/{total}",
        style = ctx.flags.style or "classic"
    })

    for i = 0, 100, 10 do
        bar:update(i)
        os.execute("sleep 0.1")
    end
    bar:finish()
    print(color.green("✓ Done!"))

    return true
end)

local labeled = app:command("labeled", "Progress with labels")

labeled:action(function(ctx)
    print(color.bold("=== Labeled Progress ===\n"))

    local labels = {"Downloading...", "Extracting...", "Installing...", "Configuring...", "Finalizing..."}

    for i, label in ipairs(labels) do
        print(color.cyan("\n" .. label))

        local bar = progress.new({
            total = 100,
            width = 40,
            format = "[{bar}] {percentage}%"
        })

        for j = 0, 100, 20 do
            bar:update(j)
            os.execute("sleep 0.15")
        end
        bar:finish()
    end

    print(color.green("\n✓ All steps completed!"))
    return true
end)

local multi = app:command("multi", "Multiple concurrent progress indicators")

multi:action(function(ctx)
    print(color.bold("=== Multi-Progress Demo ===\n"))

    local tasks = {
        {name = "Task A", total = 100, width = 30},
        {name = "Task B", total = 50, width = 30},
        {name = "Task C", total = 75, width = 30}
    }

    local bars = {}
    for i, task in ipairs(tasks) do
        bars[i] = progress.new({
            total = task.total,
            width = task.width,
            format = "  " .. task.name .. " [{bar}] {percentage}%",
            auto_newline = false
        })
    end

    local complete = false
    local counters = {0, 0, 0}

    while not complete do
        complete = true
        io.write("\27[3A")

        for i, bar in ipairs(bars) do
            if counters[i] < tasks[i].total then
                counters[i] = math.min(counters[i] + math.random(1, 10), tasks[i].total)
                bar:update(counters[i])
                io.write("\n")
                complete = false
            else
                bar:update(counters[i])
                io.write("\n")
            end
        end

        if not complete then
            os.execute("sleep 0.05")
        end
    end

    print(color.green("\n✓ All tasks completed!"))
    return true
end)

local file_ops = app:command("file-ops", "File operation simulation")

file_ops:action(function(ctx)
    print(color.bold("=== File Operations ===\n"))

    local files = {
        "config.yaml",
        "data.json",
        "script.lua",
        "README.md"
    }

    for i, filename in ipairs(files) do
        local bar = progress.new({
            total = 100,
            width = 40,
            format = "  Processing " .. color.cyan(filename) .. " [{bar}] {percentage}%"
        })

        for j = 0, 100, 5 do
            bar:update(j)
            os.execute("sleep 0.05")
        end
        bar:finish()
    end

    print(color.green("\n✓ All files processed!"))
    return true
end)

-- NEW: iter demo
local iter = app:command("iter", "Iterate with auto progress bar")

iter:action(function(ctx)
    print(color.bold("=== progress.iter() ===\n"))

    local items = {}
    for i = 1, 20 do
        table.insert(items, "item-" .. string.format("%02d", i))
    end

    for item in progress.iter(items, {format = "[{bar}] {percentage}% Processing {current}/{total}"}) do
        os.execute("sleep 0.05")
    end

    print(color.green("\n✓ All items processed!"))
    return true
end)

-- NEW: tick demo
local tick = app:command("tick", "Tick-based progress")

tick:action(function(ctx)
    print(color.bold("=== progress.tick() ===\n"))

    local bar = progress.new({
        total = 30,
        width = 30,
        format = "[{bar}] {percentage}% {current}/{total}"
    })

    for i = 1, 30 do
        bar:tick()
        os.execute("sleep 0.05")
    end
    bar:finish()

    print(color.green("✓ Done!"))
    return true
end)

-- NEW: bytes demo
local bytes = app:command("bytes", "Byte transfer simulation")

bytes:action(function(ctx)
    print(color.bold("=== progress.bytes() ===\n"))

    local total_bytes = 15 * 1024 * 1024 -- 15 MB
    local bar = progress.bytes(total_bytes, {
        format = "[{bar}] {percentage}% {bytes_current}/{bytes_total}{eta}"
    })

    local transferred = 0
    while transferred < total_bytes do
        transferred = math.min(transferred + math.random(512 * 1024, 2 * 1024 * 1024), total_bytes)
        bar:update(transferred)
        os.execute("sleep 0.1")
    end
    bar:finish()

    print(color.green("✓ Transfer complete!"))
    return true
end)

-- NEW: dynamic total/message demo
local dynamic = app:command("dynamic", "Dynamic total and message")

dynamic:action(function(ctx)
    print(color.bold("=== Dynamic Updates ===\n"))

    local bar = progress.new({
        total = 50,
        width = 30,
        format = "{message} [{bar}] {percentage}%"
    })

    bar:set_message("Phase 1")
    for i = 1, 25 do
        bar:tick()
        os.execute("sleep 0.05")
    end

    -- discovered more work
    bar:set_total(100)
    bar:set_message("Phase 2 (adjusted)")
    for i = 26, 100 do
        bar:update(i)
        os.execute("sleep 0.03")
    end
    bar:finish()

    print(color.green("\n✓ Dynamic progress complete!"))
    return true
end)

-- NEW: run wrapper demo
local run = app:command("run", "Run wrapper demo")

run:action(function(ctx)
    print(color.bold("=== progress.run() ===\n"))

    progress.run(20, function(bar)
        for i = 1, 20 do
            bar:tick()
            os.execute("sleep 0.05")
        end
    end, {format = "[{bar}] {percentage}% {message}", message = "Working..."})

    print(color.green("✓ Run complete!"))
    return true
end)

os.exit(app:run(arg))
