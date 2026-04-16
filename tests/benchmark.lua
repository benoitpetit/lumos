-- Lumos Benchmark Suite
-- Simple performance benchmarks for core operations

local lumos = require("lumos")
local profiler = require("lumos.profiler")

profiler.enable()

-- Benchmark 1: Startup time
profiler.start("startup")
local app = lumos.new_app({ name = "benchmark" })
profiler.stop("startup")

-- Benchmark 2: Command creation
profiler.start("command_creation")
for i = 1, 100 do
    app:command("cmd" .. i, "Command " .. i)
        :arg("arg1", "Argument 1")
        :flag("-f --flag", "Flag")
        :action(function() end)
end
profiler.stop("command_creation")

-- Benchmark 3: Argument parsing
profiler.start("argument_parsing")
for i = 1, 1000 do
    app:run({ "cmd1", "value", "--flag" })
end
profiler.stop("argument_parsing")

-- Benchmark 4: UI rendering
local color = require("lumos.color")
profiler.start("ui_rendering")
for i = 1, 1000 do
    color.green("Test message " .. i)
end
profiler.stop("ui_rendering")

-- Report
profiler.report()

-- Goals for 0.3.X:
-- - Startup: < 30ms
-- - 100 commands creation: < 50ms
-- - 1000 argument parses: < 100ms
-- - 1000 UI messages: < 50ms
