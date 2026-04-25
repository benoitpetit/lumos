#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local security = require("lumos.security")

local app = lumos.new_app({
    name = "security_demo",
    version = "1.0.0",
    description = "Security utilities demonstration"
})

local sanitize = app:command("sanitize", "Input sanitization")

sanitize:action(function(ctx)
    print(color.bold("=== Path Sanitization ===\n"))

    local paths = {
        "../../../etc/passwd",
        "/absolute/path",
        "./relative/path",
        "path/with/..//../double/dots",
        "path/with\0null byte",
        "path/with|special|chars",
        "path/with$(command)substitution"
    }

    for _, path in ipairs(paths) do
        local display_path = path:gsub("%z", "\\0")
        local safe = security.sanitize_path(path)
        local status = (safe == path) and color.green("✓ safe") or color.yellow("⚠ sanitized")
        print(string.format("  %-40s -> %s", display_path, status))
        if safe and safe ~= path then
            print(string.format("      sanitized to: %s", safe))
        elseif not safe then
            print(string.format("      sanitized to: %s", color.red("nil (blocked)")))
        end
    end

    return true
end)

local shell = app:command("shell", "Shell command escaping")

shell:action(function(ctx)
    print(color.bold("=== Shell Escaping ===\n"))

    local dangerous = {
        "echo 'hello'; rm -rf /",
        "file$(touch hacked)",
        "data|cat /etc/passwd",
        "input`ls -la`",
        "normal argument"
    }

    for _, input in ipairs(dangerous) do
        local safe = security.shell_escape(input)
        print(string.format("  %-35s -> %s", input, safe))
    end

    return true
end)

local rate = app:command("rate", "Rate limiting test")

rate:flag("--requests", "Number of requests"):default(20)
rate:flag("--window", "Time window (seconds)"):default(5)

rate:action(function(ctx)
    print(color.bold("=== Rate Limiting Demo ===\n"))

    local max_requests = tonumber(ctx.flags.requests) or 20
    local window_seconds = tonumber(ctx.flags.window) or 5

    print(string.format("Testing: %d requests in %d second window\n", max_requests, window_seconds))

    local allowed = 0
    local denied = 0

    for i = 1, max_requests do
        local key = "rate_test_" .. (i % 5)
        local result = security.rate_limit(key, max_requests, window_seconds)

        if result then
            allowed = allowed + 1
            io.write(color.green("."))
        else
            denied = denied + 1
            io.write(color.red("."))
        end

        if i % 50 == 0 then io.write("\n") end
    end

    io.write("\n\n")
    print(string.format("Results: %d allowed, %d denied", allowed, denied))
    print(color.dim("Note: Rate limit resets after window expires"))

    return true
end)

local validation = app:command("validate", "Input validation")

validation:action(function(ctx)
    print(color.bold("=== Input Validation ===\n"))

    local security = require("lumos.security")

    local test_cases = {
        {type = "email", value = "user@example.com", expected = true},
        {type = "email", value = "invalid-email", expected = false},
        {type = "email", value = "@example.com", expected = false},
        {type = "url", value = "https://example.com", expected = true},
        {type = "url", value = "not-a-url", expected = false},
        {type = "url", value = "ftp://example.com/file", expected = false},
        {type = "integer", value = "42", expected = true},
        {type = "integer", value = "42.5", expected = false},
        {type = "integer", value = "abc", expected = false},
        {type = "range", value = 50, min = 0, max = 100, expected = true},
        {type = "range", value = 150, min = 0, max = 100, expected = false},
    }

    for _, tc in ipairs(test_cases) do
        local result
        if tc.type == "email" then
            result = security.validate_email(tc.value)
        elseif tc.type == "url" then
            result = security.validate_url(tc.value)
        elseif tc.type == "integer" then
            result = security.validate_integer(tc.value)
        elseif tc.type == "range" then
            result = security.validate_integer(tc.value, tc.min, tc.max)
        end

        local status = (result == tc.expected) and color.green("✓") or color.red("✗")
        local value = string.format("%s (%s)", tc.value, tc.type)
        print(string.format("  %s %-30s -> %s", status, value, tostring(result)))
    end

    return true
end)

os.exit(app:run(arg))