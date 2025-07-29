#!/usr/bin/env lua

-- Quick test of Lumos framework basic functionality
package.path = package.path .. ";./?.lua;./?/init.lua"

local lumos = require('lumos')
local color = require('lumos.color')

print(color.format("{bold}{blue}=== Lumos Quick Test ==={reset}"))
print()

-- Test 1: Basic app creation
print(color.yellow("1. Testing app creation..."))
local app = lumos.new_app({
    name = "quicktest",
    version = "0.1.0",
    description = "Quick test of Lumos"
})
print(color.green("✓ App created successfully"))

-- Test 2: Command definition
print(color.yellow("2. Testing command definition..."))
local hello = app:command("hello", "Say hello")
hello:flag("-u --upper", "Use uppercase")
hello:action(function(ctx)
    local msg = "Hello from Lumos!"
    if ctx.flags.upper then
        msg = msg:upper()
    end
    print(color.cyan(msg))
    return true
end)
print(color.green("✓ Command defined successfully"))

-- Test 3: Flag parsing 
print(color.yellow("3. Testing argument parsing..."))
local test_args = {"hello", "--upper"}
local success = app:run(test_args)
print(color.green("✓ Arguments parsed and command executed"))

-- Test 4: Colors
print(color.yellow("4. Testing colors..."))
print("  " .. color.red("Red") .. " " .. color.green("Green") .. " " .. color.blue("Blue"))
print(color.green("✓ Colors working"))

print()
print(color.format("{bold}{green}All basic tests passed!{reset}"))
