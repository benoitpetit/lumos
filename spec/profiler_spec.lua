-- Profiler module tests
local profiler = require('lumos.profiler')

describe("Profiler Module", function()
    before_each(function()
        profiler.reset()
        profiler.disable()
    end)

    it('starts and stops timing', function()
        profiler.enable()
        profiler.start("test")
        profiler.stop("test")
        -- Report should contain the entry
        assert.is_function(profiler.report)
    end)

    it('wraps a function', function()
        profiler.enable()
        local fn = profiler.wrap("add", function(a, b)
            return a + b
        end)
        assert.equal(5, fn(2, 3))
    end)

    it('prints report when enabled', function()
        profiler.enable()
        profiler.start("test")
        profiler.stop("test")
        local original_print = _G.print
        local output = {}
        _G.print = function(...) table.insert(output, table.concat({...}, " ")) end
        profiler.report()
        _G.print = original_print
        local found = false
        for _, line in ipairs(output) do
            if line:find("Profiling Report") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it('does nothing when disabled', function()
        profiler.start("test")
        profiler.stop("test")
        local original_print = _G.print
        local output = {}
        _G.print = function(...) table.insert(output, table.concat({...}, " ")) end
        profiler.report()
        _G.print = original_print
        local found = false
        for _, line in ipairs(output) do
            if line:find("disabled") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it('resets timings', function()
        profiler.enable()
        profiler.start("test")
        profiler.stop("test")
        profiler.reset()
        profiler.start("other")
        profiler.stop("other")
        -- After reset, the old timing should not appear in report output
        local original_print = _G.print
        local output = ""
        _G.print = function(s) output = output .. (s or "") .. "\n" end
        profiler.report()
        _G.print = original_print
        assert.is_nil(output:find("test"))
        assert.is_not_nil(output:find("other"))
    end)
end)
