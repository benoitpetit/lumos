-- Lumos Profiler Module
-- Simple integrated profiling for performance analysis

local profiler = {}

local timings = {}
local enabled = false

function profiler.enable()
    enabled = true
end

function profiler.disable()
    enabled = false
end

function profiler.start(name)
    if not enabled then return end
    timings[name] = timings[name] or { count = 0, total = 0 }
    timings[name].start = os.clock()
end

function profiler.stop(name)
    if not enabled then return end
    local timing = timings[name]
    if timing and timing.start then
        local elapsed = os.clock() - timing.start
        timing.total = timing.total + elapsed
        timing.count = timing.count + 1
        timing.start = nil
    end
end

function profiler.wrap(name, fn)
    return function(...)
        profiler.start(name)
        local result = { fn(...) }
        profiler.stop(name)
        return (unpack or table.unpack)(result)
    end
end

function profiler.report()
    if not enabled then
        print("Profiler is disabled")
        return
    end

    print("\n=== Profiling Report ===\n")
    print(string.format("%-30s %10s %12s %12s", "Name", "Calls", "Total (ms)", "Avg (ms)"))
    print(string.rep("-", 70))

    local sorted = {}
    for name, timing in pairs(timings) do
        table.insert(sorted, { name = name, timing = timing })
    end

    table.sort(sorted, function(a, b)
        return a.timing.total > b.timing.total
    end)

    for _, item in ipairs(sorted) do
        local avg = item.timing.total / item.timing.count * 1000
        print(string.format("%-30s %10d %12.2f %12.2f",
            item.name,
            item.timing.count,
            item.timing.total * 1000,
            avg
        ))
    end

    print(string.rep("-", 70))
end

function profiler.reset()
    timings = {}
end

return profiler
