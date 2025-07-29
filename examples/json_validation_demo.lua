#!/usr/bin/env lua

-- Lumos JSON and Validation Demo
-- Demonstrates JSON output and input validation

package.path = package.path .. ";../?.lua;../?/init.lua;"

local lumos = require('lumos')
local color = require('lumos.color')
local prompt = require('lumos.prompt')
local json = require('lumos.json')

-- Create app
local app = lumos.new_app({
    name = "json_demo",
    version = "2.0.0",
    description = "Demonstrates JSON output and input validation"
})

-- Add global JSON flag
app:flag("-j --json", "Output in JSON format")

-- Command to test JSON output
local list_cmd = app:command("list", "List sample data")
list_cmd:action(function(ctx)
    local data = {
        users = {
            {name = "Alice", email = "alice@example.com", age = 30},
            {name = "Bob", email = "bob@example.com", age = 25}
        },
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    if ctx.flags.json then
        print(json.encode(data))
    else
        print(color.bold("Sample Data:"))
        for _, user in ipairs(data.users) do
            print("• " .. color.cyan(user.name) .. " (" .. user.email .. ") - Age: " .. user.age)
        end
        print("Generated at: " .. color.dim(data.timestamp))
    end
    
    return true
end)

-- Command to test validation
local validate_cmd = app:command("validate", "Test input validation")
validate_cmd:action(function(ctx)
    print(color.bold("=== Input Validation Demo ==="))
    
    -- Email validation
    while true do
        local email = prompt.input("Enter your email:")
        local valid, error_msg = prompt.validate(email, prompt.validators.email, "Please enter a valid email address")
        
        if valid then
            print(color.status.success("✓ Valid email: " .. email))
            break
        else
            print(color.status.error("✗ " .. error_msg))
        end
    end
    
    -- Number validation
    while true do
        local age = prompt.input("Enter your age:")
        local valid, error_msg = prompt.validate(age, prompt.validators.number, "Please enter a valid number")
        
        if valid then
            print(color.status.success("✓ Valid age: " .. age))
            break
        else
            print(color.status.error("✗ " .. error_msg))
        end
    end
    
    print(color.status.info("Validation complete!"))
    return true
end)

-- Command to test enhanced colors
local colors_cmd = app:command("colors", "Test enhanced color features")
colors_cmd:action(function(ctx)
    print(color.bold("=== Enhanced Color Features ==="))
    
    -- Status colors
    print("Status colors:")
    print("  " .. color.status.success("Success message"))
    print("  " .. color.status.error("Error message"))
    print("  " .. color.status.warning("Warning message"))
    print("  " .. color.status.info("Info message"))
    
    print()
    
    -- Log colors
    print("Log colors:")
    print("  " .. color.log.debug("Debug message"))
    print("  " .. color.log.info("Info log entry"))
    print("  " .. color.log.warn("Warning log entry"))
    print("  " .. color.log.error("Error log entry"))
    
    print()
    
    -- Progress-based colors
    print("Progress-based colors:")
    for i = 10, 100, 20 do
        local color_name = color.progress_color(i)
        print("  " .. i .. "% - " .. color.colorize("Progress at " .. i .. "%", color_name))
    end
    
    return true
end)

-- Run the app
app:run(arg)
