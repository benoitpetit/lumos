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

return Middleware
