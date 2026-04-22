-- Middleware module tests
local Middleware = require('lumos.middleware')

describe("Middleware Module", function()
    it('creates a chain and executes in order', function()
        local m = Middleware.new()
        local order = {}
        m:use(function(ctx, next)
            table.insert(order, 1)
            return next()
        end)
        m:use(function(ctx, next)
            table.insert(order, 2)
            return next()
        end)
        local result = m:execute({}, function()
            table.insert(order, 3)
            return "done"
        end)
        assert.equal("done", result)
        assert.same({1, 2, 3}, order)
    end)

    it('sorts by priority', function()
        local m = Middleware.new()
        local order = {}
        m:use(function(ctx, next)
            table.insert(order, "b")
            return next()
        end, 200)
        m:use(function(ctx, next)
            table.insert(order, "a")
            return next()
        end, 100)
        m:execute({}, function()
            table.insert(order, "c")
        end)
        assert.same({"a", "b", "c"}, order)
    end)

    it('short-circuits the chain', function()
        local m = Middleware.new()
        m:use(function(ctx, next)
            return "stopped"
        end)
        m:use(function(ctx, next)
            return "never"
        end)
        local result = m:execute({}, function()
            return "action"
        end)
        assert.equal("stopped", result)
    end)

    it('builtin logger returns a middleware function', function()
        local mw = Middleware.builtin.logger()
        assert.is_function(mw)
    end)

    it('builtin auth rejects missing key', function()
        local mw = Middleware.builtin.auth({ env_var = "TEST_API_KEY" })
        local result, err = mw({ flags = {} }, function() return "ok" end)
        assert.is_nil(result)
        assert.is_not_nil(err)
        assert.equal("INVALID_ARGUMENT", err.type)
    end)

    it('builtin auth passes with key', function()
        local mw = Middleware.builtin.auth()
        local ctx = { flags = { api_key = "secret" } }
        local result, err = mw(ctx, function() return "ok" end)
        assert.equal("ok", result)
        assert.is_nil(err)
        assert.equal("secret", ctx.auth.api_key)
    end)

    it('builtin dry_run sets context flag', function()
        local mw = Middleware.builtin.dry_run()
        local ctx = { flags = { ["dry-run"] = true } }
        local result, err = mw(ctx, function() return "ok" end)
        assert.equal("ok", result)
        assert.is_true(ctx.dry_run)
    end)

    it('builtin rate_limit allows first request', function()
        local mw = Middleware.builtin.rate_limit({ max_requests = 1, window_seconds = 60 })
        local ctx = { command = { name = "test" } }
        local result, err = mw(ctx, function() return "ok" end)
        assert.equal("ok", result)
        assert.is_nil(err)
    end)

    it('builtin confirm proceeds when user confirms', function()
        local prompt = require('lumos.prompt')
        local original_confirm = prompt.confirm
        prompt.confirm = function() return true end
        
        local mw = Middleware.builtin.confirm({ message = "Continue?" })
        local ctx = { flags = {} }
        local result, err = mw(ctx, function() return "ok" end)
        
        prompt.confirm = original_confirm
        assert.equal("ok", result)
        assert.is_nil(err)
    end)

    it('builtin confirm cancels when user declines', function()
        local prompt = require('lumos.prompt')
        local original_confirm = prompt.confirm
        prompt.confirm = function() return false end
        
        local mw = Middleware.builtin.confirm({ message = "Continue?" })
        local ctx = { flags = {} }
        local result, err = mw(ctx, function() return "ok" end)
        
        prompt.confirm = original_confirm
        assert.is_nil(result)
        assert.is_not_nil(err)
        assert.equal("INVALID_ARGUMENT", err.type)
    end)

    it('builtin timeout allows fast operations', function()
        local mw = Middleware.builtin.timeout({ seconds = 5 })
        local ctx = {}
        local result, err = mw(ctx, function() return "ok" end)
        assert.equal("ok", result)
        assert.is_nil(err)
    end)

    it('builtin timeout errors on slow operations', function()
        local mw = Middleware.builtin.timeout({ seconds = 0.01 })
        local ctx = {}
        local result, err = mw(ctx, function()
            -- Simulate a slow operation
            local start = os.clock()
            while os.clock() - start < 0.1 do end
            return "ok"
        end)
        assert.is_nil(result)
        assert.is_not_nil(err)
        assert.equal("TIMEOUT", err.type)
    end)

    it('builtin circuit breaker allows calls when closed', function()
        local mw = Middleware.builtin.circuit_breaker({ failure_threshold = 3 })
        local ctx = {}
        local result, err = mw(ctx, function() return "ok" end)
        assert.equal("ok", result)
        assert.is_nil(err)
    end)

    it('builtin circuit breaker trips after threshold', function()
        local mw = Middleware.builtin.circuit_breaker({ failure_threshold = 2, recovery_timeout = 3600 })
        local ctx = {}
        -- First failure
        mw(ctx, function() return nil, { type = "ERROR" } end)
        -- Second failure (should trip)
        mw(ctx, function() return nil, { type = "ERROR" } end)
        -- Third call should be blocked
        local result, err = mw(ctx, function() return "ok" end)
        assert.is_nil(result)
        assert.is_not_nil(err)
        assert.equal("EXECUTION_FAILED", err.type)
    end)
end)
