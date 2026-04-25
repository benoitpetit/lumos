#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")
local http = require("lumos.http")

local app = lumos.new_app({
    name = "http_demo",
    version = "1.0.0",
    description = "HTTP client demonstrations"
})

app:flag("-j --json", "JSON output")
app:flag("-v --verbose", "Verbose output")

local get = app:command("get", "HTTP GET request")
get:arg("url", "URL to fetch"):required(true)
get:flag_string("-H --header", "Custom header (key:value)")
get:flag_int("-t --timeout", "Request timeout (seconds)", 1, 3600)

get:action(function(ctx)
    print(color.bold("=== HTTP GET ===\n"))
    print("URL: " .. color.cyan(ctx.args[1]))

    local headers = {}
    if ctx.flags.header then
        local h = ctx.flags.header
        local key, val = h:match("([^:]+):(.+)")
        if key then headers[key:match("^%s*(.-)%s*$")] = val:match("^%s*(.-)%s*$") end
        print("Headers: " .. require("lumos.json").encode(headers))
    end

    print("\nFetching...")
    local response, err = http.get(ctx.args[1], {
        headers = headers,
        timeout = tonumber(ctx.flags.timeout)
    })

    if err then
        print(color.red("Error: " .. tostring(err)))
        return false
    end

    print(color.green("\n✓ Request successful"))
    print("\nStatus: " .. color.yellow(response.status))
    print("Headers: " .. color.dim(require("lumos.json").encode(response.headers)))

    if response.body then
        print("\nBody (" .. #response.body .. " bytes):")
        local body_preview = response.body:sub(1, 500)
        if #response.body > 500 then body_preview = body_preview .. "..." end
        print(color.dim(body_preview))
    end

    return true
end)

local post = app:command("post", "HTTP POST request")
post:arg("url", "URL to post to"):required(true)
post:flag_string("-d --data", "Request body")
post:flag_string("-H --header", "Custom header")
post:flag_int("-t --timeout", "Timeout", 1, 3600)

post:action(function(ctx)
    print(color.bold("=== HTTP POST ===\n"))
    print("URL: " .. color.cyan(ctx.args[1]))
    print("Data: " .. color.yellow(ctx.flags.data))

    print("\nPosting...")
    local response, err = http.post(ctx.args[1], ctx.flags.data, {
        headers = {
            ["Content-Type"] = "application/json"
        },
        timeout = tonumber(ctx.flags.timeout)
    })

    if err then
        print(color.red("Error: " .. tostring(err)))
        return false
    end

    print(color.green("\n✓ POST successful"))
    print("Status: " .. color.yellow(response.status))

    return true
end)

local methods = app:command("methods", "Test all HTTP methods")

methods:action(function(ctx)
    print(color.bold("=== HTTP Methods ===\n"))

    local base_url = "https://httpbin.org"
    local methods = {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"}

    for _, method in ipairs(methods) do
        local ok = pcall(function()
            local fn = http[method:lower()]
            if fn then
                local response = fn(base_url .. "/" .. method:lower())
                if response and response.status then
                    print(string.format("  %-10s %s %d",
                        color.cyan(method),
                        color.green("✓"),
                        response.status))
                end
            end
        end)

        if not ok then
            print(string.format("  %-10s %s",
                color.cyan(method),
                color.red("✗")))
        end
    end

    print(color.dim("\nNote: Using httpbin.org for testing"))
    return true
end)

local headers = app:command("headers", "Custom headers demo")

headers:action(function(ctx)
    print(color.bold("=== Custom Headers ===\n"))

    local custom_headers = {
        ["X-Custom-Header"] = "lumos-demo",
        ["X-Request-ID"] = "12345",
        ["Authorization"] = "Bearer token123"
    }

    print("Sending request with custom headers:")
    for k, v in pairs(custom_headers) do
        print(string.format("  %s: %s", color.cyan(k), color.yellow(v)))
    end

    local response, err = http.get("https://httpbin.org/headers", {
        headers = custom_headers
    })

    if err then
        print(color.red("Error: " .. tostring(err)))
        return false
    end

    print(color.green("\n✓ Response received"))
    print("Server received headers:")
    print(color.dim(response.body))

    return true
end)

os.exit(app:run(arg))