#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "middleware_demo",
    version = "1.0.0",
    description = "Middleware chain demonstrations"
})

app:flag("-v --verbose", "Verbose output")
app:countable()

local demo = app:command("demo", "Show all middleware types")
demo:flag("--auth", "Include auth middleware")
demo:flag("--timeout", "Include timeout middleware"):default(5)
demo:flag("--retry", "Include retry middleware")
demo:flag("--circuit", "Include circuit breaker")
demo:flag("--dry-run", "Enable dry-run mode")

if app._last_flag then app._last_flag = nil end

demo:use(lumos.middleware.builtin.logger())

demo:action(function(ctx)
    print(color.bold("\n=== Middleware Chain Demo ===\n"))
    print("Current middleware chain:")
    print("  1. " .. color.cyan("logger") .. " - logs command start/completion")

    local chain_idx = 2

    if ctx.flags.auth then
        print(string.format("  %d. %s - checks API key", chain_idx, color.cyan("auth")))
        chain_idx = chain_idx + 1
    end

    if ctx.flags.timeout then
        print(string.format("  %d. %s - timeout after %ds", chain_idx, color.cyan("timeout"), ctx.flags.timeout))
        chain_idx = chain_idx + 1
    end

    if ctx.flags.retry then
        print(string.format("  %d. %s - retries on failure", chain_idx, color.cyan("retry")))
        chain_idx = chain_idx + 1
    end

    if ctx.flags.circuit then
        print(string.format("  %d. %s - circuit breaker pattern", chain_idx, color.cyan("circuit_breaker")))
        chain_idx = chain_idx + 1
    end

    if ctx.flags.dry_run then
        print(string.format("  %d. %s - simulation mode", chain_idx, color.cyan("dry_run")))
    end

    print(color.green("\n✓ Middleware chain executed successfully"))
    return true
end)

local order = app:command("order", "Middleware execution order")

order:action(function(ctx)
    print(color.bold("\n=== Middleware Execution Order ===\n"))

    local execution_log = {}

    local function log(msg)
        table.insert(execution_log, msg)
        print(color.dim(msg))
    end

    local test_app = lumos.new_app({name = "test"})
    local cmd = test_app:command("test", "Test command")

    cmd:use(function(ctx, next)
        log("1. [auth] Check permissions")
        return next()
    end, 10)

    cmd:use(function(ctx, next)
        log("2. [validation] Validate input")
        return next()
    end, 20)

    cmd:use(function(ctx, next)
        log("3. [rate_limit] Check rate limit")
        return next()
    end, 30)

    cmd:use(function(ctx, next)
        log("4. [main] Execute command")
        return next()
    end, 100)

    cmd:action(function(ctx)
        log("5. [action] Command executed")
        return true
    end)

    print(color.dim("Execution flow:\n"))
    test_app:run({"test"})

    return true
end)

local auth_demo = app:command("auth", "Auth middleware demo")

auth_demo:use(lumos.middleware.builtin.auth({env_var = "DEMO_API_KEY"}))

auth_demo:action(function(ctx)
    print(color.green("\n✓ Authentication successful!"))
    print("  API Key: " .. color.cyan(string.rep("*", 8) .. "..."))
    print("  User: " .. color.yellow(ctx.auth and ctx.auth.api_key or "unknown"))
    return true
end)

local retry_demo = app:command("retry", "Retry middleware demo")

retry_demo:flag("--fail-at", "Simulate failure at attempt"):default(3)
retry_demo:flag("--max-attempts", "Max retry attempts"):default(5)

retry_demo:use(lumos.middleware.builtin.retry({
    max_attempts = 5,
    backoff = "exponential",
    base_delay = 0.1
}))

retry_demo:action(function(ctx)
    local attempt = tonumber(ctx.flags.fail_at) or 3
    local current = (ctx._retry_count or 0) + 1

    ctx._retry_count = current

    if current < attempt then
        print(color.yellow(string.format("Attempt %d/%d - simulating failure...", current, ctx.flags.max_attempts)))
        error("Simulated failure on attempt " .. current)
    end

    print(color.green(string.format("\n✓ Success on attempt %d!", current)))
    ctx._retry_count = nil
    return true
end)

os.exit(app:run(arg))