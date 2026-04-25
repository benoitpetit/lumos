#!/usr/bin/env lua

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require("lumos")
local color = require("lumos.color")

local app = lumos.new_app({
    name = "typed_demo",
    version = "1.0.0",
    description = "Demonstrates all typed flags"
})

local demo = app:command("demo", "Test various flag types")

demo:flag_int("-p --port", "Port number", 1, 65535):default(8080)
demo:flag_float("--rate", "Rate value", {min = 0.0, max = 1.0, precision = 3})
demo:flag_string("-n --name", "Name value", {min_length = 2, max_length = 50})
demo:flag_email("-e --email", "Email address")
demo:flag_url("-u --url", "URL address", {require_host = true, allow_localhost = false})
demo:flag_path("-f --file", "File path", {must_exist = false, allow_file = true, allow_dir = false})
demo:flag_array("--tags", "List of tags", {separator = ",", unique = true})
demo:flag_enum("-s --status", "Status", {"pending", "active", "completed", "failed"}, {case_sensitive = false})

demo:flag("-v --verbose", "Verbose output")
demo:countable()

demo:examples({
    "typed_demo demo --port 3000 --email user@example.com --status active",
    "typed_demo demo --tags lua,cli,framework --rate 0.85"
})

demo:action(function(ctx)
    print(color.bold("=== Flag Values ==="))
    print("port: " .. color.yellow(tostring(ctx.flags.port)))
    print("rate: " .. color.yellow(tostring(ctx.flags.rate)))
    print("name: " .. color.yellow(ctx.flags.name or "nil"))
    print("email: " .. color.yellow(ctx.flags.email or "nil"))
    print("url: " .. color.yellow(ctx.flags.url or "nil"))
    print("file: " .. color.yellow(ctx.flags.file or "nil"))
    print("tags: " .. color.yellow(table.concat(ctx.flags.tags or {}, ", ")))
    print("status: " .. color.yellow(ctx.flags.status or "nil"))
    print("verbose count: " .. color.yellow(tostring(ctx.flags.verbose)))
    return true
end)

local validate = app:command("validate", "Validate typed flags")
validate:arg("email", "Email to validate")
validate:flag_email("--check", "Additional email check")

validate:action(function(ctx)
    local email = ctx.args[1] or ctx.flags.check

    if not email then
        print(color.red("No email provided"))
        return false
    end

    local valid, err = require("lumos.security").validate_email(email)
    if valid then
        print(color.green("✓ Valid email: " .. email))
    else
        print(color.red("✗ Invalid email: " .. (err or "unknown")))
    end
    return true
end)

os.exit(app:run(arg))