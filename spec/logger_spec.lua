local logger = require('lumos.logger')

describe('Logger Module', function()
    local original_stderr = io.stderr
    local captured_output = ""

    -- Helper: create an in-memory write capture
    local function make_capture_file()
        local buf = {}
        return {
            write = function(_, text) table.insert(buf, text) end,
            flush = function(_) end,
            get   = function()  return table.concat(buf) end,
            reset = function()  buf = {} end
        }
    end

    local capture

    before_each(function()
        capture = make_capture_file()
        -- Redirect logger output to our capture object
        logger.set_output(capture)
        logger.set_timestamp(false)
        logger.set_colors(false)
        logger.set_level("TRACE")
        -- set_level() itself emits a DEBUG message; clear it so tests start clean
        capture:reset()
    end)

    after_each(function()
        -- Restore stderr so other tests are unaffected
        logger.set_output(io.stderr)
        logger.set_level("INFO")
        logger.set_timestamp(true)
    end)

    -- -------------------------------------------------------------------------
    describe('Log levels', function()
        it('logs ERROR messages', function()
            logger.error("something broke")
            local out = capture:get()
            assert.is_not_nil(out:match("%[ERROR%]"))
            assert.is_not_nil(out:match("something broke"))
        end)

        it('logs WARN messages', function()
            logger.warn("be careful")
            local out = capture:get()
            assert.is_not_nil(out:match("%[WARN%]"))
            assert.is_not_nil(out:match("be careful"))
        end)

        it('logs INFO messages', function()
            logger.info("all good")
            local out = capture:get()
            assert.is_not_nil(out:match("%[INFO%]"))
            assert.is_not_nil(out:match("all good"))
        end)

        it('logs DEBUG messages when level is DEBUG', function()
            logger.set_level("DEBUG")
            logger.debug("low level detail")
            local out = capture:get()
            assert.is_not_nil(out:match("%[DEBUG%]"))
        end)

        it('logs TRACE messages when level is TRACE', function()
            logger.set_level("TRACE")
            logger.trace("very verbose")
            local out = capture:get()
            assert.is_not_nil(out:match("%[TRACE%]"))
        end)

        it('suppresses messages below current level', function()
            logger.set_level("ERROR")
            logger.info("should be hidden")
            local out = capture:get()
            assert.are.equal("", out)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('set_level / get_level', function()
        it('accepts string level names (uppercase)', function()
            logger.set_level("WARN")
            local level, name = logger.get_level()
            assert.are.equal(logger.LEVELS.WARN, level)
            assert.are.equal("WARN", name)
        end)

        it('accepts string level names (lowercase)', function()
            logger.set_level("debug")
            local level, name = logger.get_level()
            assert.are.equal(logger.LEVELS.DEBUG, level)
            assert.are.equal("DEBUG", name)
        end)

        it('accepts numeric levels', function()
            logger.set_level(logger.LEVELS.ERROR)
            local level, name = logger.get_level()
            assert.are.equal(1, level)
            assert.are.equal("ERROR", name)
        end)

        it('warns on invalid level and keeps current level', function()
            logger.set_level("INFO")
            -- Invalid level should produce a WARN log and NOT change the level
            capture:reset()
            logger.set_level("NOTVALID")
            local out = capture:get()
            assert.is_not_nil(out:match("%[WARN%]"))
            local level, name = logger.get_level()
            assert.are.equal("INFO", name)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('Context logging', function()
        it('appends key=value context to log line', function()
            logger.info("user logged in", {user = "alice", id = 42})
            local out = capture:get()
            assert.is_not_nil(out:match("user=alice"))
            assert.is_not_nil(out:match("id=42"))
        end)

        it('encodes table values as JSON in context', function()
            logger.info("data", {payload = {a = 1}})
            local out = capture:get()
            -- The context value for payload should be JSON-encoded
            assert.is_not_nil(out:match("payload="))
        end)

        it('omits context block when context is nil', function()
            logger.info("no context")
            local out = capture:get()
            assert.is_nil(out:match("%[%s"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('Timestamps', function()
        it('includes timestamp when enabled', function()
            logger.set_timestamp(true)
            logger.info("with timestamp")
            local out = capture:get()
            -- Timestamp format: YYYY-MM-DD HH:MM:SS
            assert.is_not_nil(out:match("%d%d%d%d%-%d%d%-%d%d"))
        end)

        it('omits timestamp when disabled', function()
            logger.set_timestamp(false)
            logger.info("without timestamp")
            local out = capture:get()
            assert.is_nil(out:match("%d%d%d%d%-%d%d%-%d%d"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('auto() level detection', function()
        it('routes messages containing "error" to ERROR level', function()
            logger.auto("critical error detected")
            local out = capture:get()
            assert.is_not_nil(out:match("%[ERROR%]"))
        end)

        it('routes messages containing "warn" to WARN level', function()
            logger.auto("warning: disk low")
            local out = capture:get()
            assert.is_not_nil(out:match("%[WARN%]"))
        end)

        it('routes generic messages to INFO level', function()
            logger.auto("application started")
            local out = capture:get()
            assert.is_not_nil(out:match("%[INFO%]"))
        end)

        it('routes messages containing "debug" to DEBUG level', function()
            logger.set_level("DEBUG")
            logger.auto("debug trace entry")
            local out = capture:get()
            assert.is_not_nil(out:match("%[DEBUG%]"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('child logger', function()
        it('creates a child logger with merged fixed context', function()
            local child = logger.child({component = "auth"})
            assert.is_function(child.info)
            assert.is_function(child.error)
            assert.is_function(child.warn)
        end)

        it('child logger injects fixed context into every message', function()
            local child = logger.child({service = "db"})
            child.info("query ok")
            local out = capture:get()
            assert.is_not_nil(out:match("service=db"))
        end)

        it('child logger merges fixed context with per-call context', function()
            local child = logger.child({service = "db"})
            child.info("query", {table = "users"})
            local out = capture:get()
            assert.is_not_nil(out:match("service=db"))
            assert.is_not_nil(out:match("table=users"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe('LEVELS table', function()
        it('exposes numeric log level constants', function()
            assert.are.equal(1, logger.LEVELS.ERROR)
            assert.are.equal(2, logger.LEVELS.WARN)
            assert.are.equal(3, logger.LEVELS.INFO)
            assert.are.equal(4, logger.LEVELS.DEBUG)
            assert.are.equal(5, logger.LEVELS.TRACE)
        end)
    end)
end)
