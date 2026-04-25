-- Lumos Middleware Module
-- Express-like middleware chain for apps and commands

local Middleware = {}
Middleware.__index = Middleware

local Error = require("lumos.error")

--- Creates a new middleware chain
function Middleware.new()
    return setmetatable({
        chain = {}
    }, Middleware)
end

--- Adds a middleware function to the chain
---@param fn function middleware(ctx, next)
---@param priority number lower = earlier (default 100)
function Middleware:use(fn, priority)
    priority = priority or 100
    table.insert(self.chain, {
        fn = fn,
        priority = priority
    })
    table.sort(self.chain, function(a, b)
        return a.priority < b.priority
    end)
    return self
end

--- Executes the middleware chain around a final action
---@param ctx table command context
---@param final_fn function the action to execute
function Middleware:execute(ctx, final_fn)
    local index = 1

    local function next_fn()
        local entry = self.chain[index]
        index = index + 1
        if entry then
            return entry.fn(ctx, next_fn)
        else
            return final_fn()
        end
    end

    return next_fn()
end

-- Builtin middleware factories
Middleware.builtin = {}

--- Logger middleware: logs command start/completion with duration
function Middleware.builtin.logger(options)
    options = options or {}
    local logger = require("lumos.logger")
    return function(ctx, next)
        local start_time = os.clock()
        logger.info("Command starting", {
            command = ctx.command.name,
            args = ctx.args,
            flags = ctx.flags
        })
        local result, err = next()
        local duration = os.clock() - start_time
        if err then
            logger.error("Command failed", {
                command = ctx.command.name,
                duration_ms = duration * 1000,
                error = err.message or tostring(err)
            })
        else
            logger.info("Command completed", {
                command = ctx.command.name,
                duration_ms = duration * 1000
            })
        end
        return result, err
    end
end

--- Auth middleware: checks for an API key
function Middleware.builtin.auth(options)
    options = options or {}
    return function(ctx, next)
        local key = ctx.flags["api_key"] or ctx.flags["api-key"] or os.getenv(options.env_var or "API_KEY")
        if not key then
            return nil, Error.new("INVALID_ARGUMENT", "API key is required", {
                suggestion = "Use --api-key or set " .. (options.env_var or "API_KEY")
            })
        end
        ctx.auth = { api_key = key }
        return next()
    end
end

--- Dry-run middleware: announces simulation mode
function Middleware.builtin.dry_run(options)
    options = options or {}
    local color = require("lumos.color")
    return function(ctx, next)
        if ctx.flags["dry_run"] or ctx.flags["dry-run"] then
            ctx.dry_run = true
            print(color.yellow("[DRY-RUN] Simulation mode active"))
            print(color.yellow("[DRY-RUN] No changes will be made"))
            print()
        end
        return next()
    end
end

--- Confirm middleware: asks user for confirmation
function Middleware.builtin.confirm(options)
    options = options or {}
    local prompt = require("lumos.prompt")
    return function(ctx, next)
        if ctx.flags.force or ctx.dry_run then
            return next()
        end
        local message = options.message or "Continue?"
        local default = options.default or false
        local confirmed = prompt.confirm(message, default)
        if not confirmed then
            return nil, Error.new("INVALID_ARGUMENT", "Operation cancelled by user")
        end
        return next()
    end
end

--- Rate limit middleware: in-process rate limiting
function Middleware.builtin.rate_limit(options)
    options = options or {}
    local security = require("lumos.security")
    local max_requests = options.max_requests or 100
    local window_seconds = options.window_seconds or 60
    return function(ctx, next)
        local key = options.key_fn and options.key_fn(ctx) or ctx.command.name
        local allowed = security.rate_limit(key, max_requests, window_seconds)
        if not allowed then
            return nil, Error.new("RATE_LIMITED", "Too many requests", {
                suggestion = "Please try again later"
            })
        end
        return next()
    end
end

-- Portable sleep helper
local function sleep(seconds)
    local ok, socket = pcall(require, "socket")
    if ok and socket and socket.select then
        socket.select(nil, nil, seconds)
        return
    end
    if package.config:sub(1,1) ~= "\\" then
        os.execute("sleep " .. tostring(seconds) .. " 2>/dev/null")
    else
        -- Windows fallback: busy-wait
        local start = os.clock()
        while os.clock() - start < seconds do end
    end
end

--- Retry middleware: retries the action on retryable errors
function Middleware.builtin.retry(options)
    options = options or {}
    local max_attempts = options.max_attempts or 3
    local backoff = options.backoff or "fixed" -- "fixed" or "exponential"
    local base_delay = options.base_delay or 1
    local logger = require("lumos.logger")
    return function(ctx, next)
        local last_err
        for attempt = 1, max_attempts do
            local result, err = next()
            if not err then
                return result, err
            end
            last_err = err
            if type(err) == "table" and err.is_retryable and not err:is_retryable() then
                return result, err
            end
            if attempt < max_attempts then
                local delay = (backoff == "exponential") and (base_delay * math.pow(2, attempt - 1)) or base_delay
                logger.warn("Retrying after error", {attempt = attempt, delay = delay, error = err.message or tostring(err)})
                sleep(delay)
            end
        end
        return nil, last_err
    end
end

--- Verbosity middleware: standardises -v / -vv / -vvv into log levels
function Middleware.builtin.verbosity(options)
    options = options or {}
    local logger = require("lumos.logger")
    return function(ctx, next)
        local v = ctx.flags.v or ctx.flags.verbose
        if type(v) == "number" then
            if v >= 3 then
                logger.set_level("TRACE")
            elseif v >= 2 then
                logger.set_level("DEBUG")
            elseif v >= 1 then
                logger.set_level("INFO")
            end
        elseif v == true then
            logger.set_level("INFO")
        end
        return next()
    end
end

--- Timeout middleware: aborts the action if it exceeds a duration
function Middleware.builtin.timeout(options)
    options = options or {}
    local seconds = options.seconds or options.timeout or 30
    local Error = require("lumos.error")

    -- Use wall-clock time when LuaSocket is available, otherwise fallback to CPU time
    local has_socket, socket = pcall(require, "socket")
    local gettime = has_socket and socket.gettime or os.clock

    return function(ctx, next)
        -- Lua doesn't have native coroutine timeout, but we can use a simple
        -- cooperative approach: start a timer and check after next() returns.
        -- For true preemption we'd need os.execute('sleep') tricks, but this
        -- is sufficient for most CLI operations.
        local start = gettime()
        local result, err = next()
        local elapsed = gettime() - start
        if elapsed > seconds then
            return nil, Error.new("TIMEOUT", "Operation exceeded " .. seconds .. " seconds")
        end
        return result, err
    end
end

--- Circuit breaker middleware: stops calling the action after repeated failures
function Middleware.builtin.circuit_breaker(options)
    options = options or {}
    local failure_threshold = options.failure_threshold or 5
    local recovery_timeout = options.recovery_timeout or 30
    local half_open_max_calls = options.half_open_max_calls or 3

    local state = "closed"      -- closed, open, half_open
    local failures = 0
    local last_failure_time = nil
    local half_open_calls = 0

    local Error = require("lumos.error")
    local logger = require("lumos.logger")

    return function(ctx, next)
        if state == "open" then
            if os.time() - last_failure_time >= recovery_timeout then
                logger.info("Circuit breaker entering half-open state")
                state = "half_open"
                half_open_calls = 0
            else
                return nil, Error.new("EXECUTION_FAILED", "Circuit breaker is OPEN")
            end
        end

        if state == "half_open" and half_open_calls >= half_open_max_calls then
            return nil, Error.new("EXECUTION_FAILED", "Circuit breaker is OPEN (half-open limit reached)")
        end

        if state == "half_open" then
            half_open_calls = half_open_calls + 1
        end

        local result, err = next()

        if err then
            failures = failures + 1
            last_failure_time = os.time()
            if failures >= failure_threshold then
                logger.warn("Circuit breaker tripped to OPEN", {failures = failures})
                state = "open"
            end
        else
            if state == "half_open" then
                logger.info("Circuit breaker recovered to CLOSED")
                state = "closed"
                failures = 0
                last_failure_time = nil
            elseif state == "closed" then
                failures = 0
            end
        end

        return result, err
    end
end

return Middleware
