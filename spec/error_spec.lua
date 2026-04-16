-- Error module tests
local Error = require('lumos.error')

describe("Error Module", function()
    it('creates a typed error', function()
        local err = Error.new("INVALID_ARGUMENT", "bad arg", { detail = 1 })
        assert.is_true(Error.is_error(err))
        assert.equal("INVALID_ARGUMENT", err.type)
        assert.equal("bad arg", err.message)
        assert.equal(1, err.context.detail)
        assert.equal(1, err.exit_code)
    end)

    it('uses default message from codes', function()
        local err = Error.new("MISSING_REQUIRED")
        assert.equal("Missing required argument", err.message)
        assert.equal(2, err.exit_code)
    end)

    it('checks retryable', function()
        local err = Error.new("TIMEOUT")
        assert.is_true(err:is_retryable())

        local err2 = Error.new("INVALID_ARGUMENT")
        assert.is_false(err2:is_retryable())
    end)

    it('formats for user with suggestion', function()
        local err = Error.new("INVALID_ARGUMENT", "bad", {
            suggestion = "Try --help",
            details = { flag = "count" }
        })
        local text = err:format_user()
        assert.truthy(text:find("bad"))
        assert.truthy(text:find("Try %-%-help"))
        assert.truthy(text:find("flag"))
    end)

    it('formats for log', function()
        local err = Error.new("IO_ERROR", "disk full")
        local log = err:format_log()
        assert.equal("IO_ERROR", log.type)
        assert.equal("disk full", log.message)
        assert.is_number(log.timestamp)
        assert.is_string(log.stack)
    end)

    it('creates success object', function()
        local ok = Error.success({ id = 42 })
        assert.is_true(ok.success)
        assert.equal(42, ok.data.id)
        assert.equal(0, ok.exit_code)
    end)

    it('distinguishes errors from plain tables', function()
        assert.is_true(Error.is_error(Error.new("CUSTOM")))
        assert.is_false(Error.is_error({ message = "x" }))
        assert.is_false(Error.is_error(nil))
        assert.is_false(Error.is_error("err"))
    end)

    it('supports __tostring', function()
        local err = Error.new("INTERNAL_ERROR", "oops")
        assert.equal("[INTERNAL_ERROR] oops", tostring(err))
    end)
end)
