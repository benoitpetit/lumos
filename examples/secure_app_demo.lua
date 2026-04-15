#!/usr/bin/env lua
-- Example: Secure CLI Application with Lumos
-- Demonstrates security features, logging, and error handling

local lumos = require('lumos')
local security = require('lumos.security')
local logger = require('lumos.logger')
local prompt = require('lumos.prompt')

-- Configure logging
logger.set_level("INFO")
logger.configure_from_env("SECURE_APP")

-- Create application
local app = lumos.new_app({
    name = "secure-app",
    version = "1.0.0",
    description = "A secure CLI application demonstrating Lumos security features"
})

-- Command: Read File (with security)
local read_cmd = app:command("read", "Read a file securely")
read_cmd:arg("file", "File path to read")
read_cmd:flag("--verbose -v", "Verbose output")
read_cmd:action(function(ctx)
    local file_path = ctx.args[1]
    
    -- Validate path
    local validated_path, err = security.sanitize_path(file_path)
    if not validated_path then
        logger.error("Invalid file path", {error = err, input = file_path})
        logger.error("❌ Error: " .. err)
        return false
    end
    
    -- Log the operation
    logger.info("Reading file", {path = validated_path, user = os.getenv("USER")})
    
    -- Open file securely
    local file, open_err = security.safe_open(validated_path, "r")
    if not file then
        logger.error("Cannot open file", {path = validated_path, error = open_err})
        logger.error("❌ Error: " .. open_err)
        return false
    end
    
    -- Read and display content
    local content = file:read("*all")
    file:close()
    
    if ctx.flags.verbose then
        logger.info("📄 File: " .. validated_path)
        logger.info("📏 Size: " .. #content .. " bytes")
        logger.info("---")
    end
    
    print(content)
    logger.info("File read successfully", {path = validated_path, size = #content})
    
    return true
end)

-- Command: Create Directory (with security)
local mkdir_cmd = app:command("mkdir", "Create directory securely")
mkdir_cmd:arg("dir", "Directory path to create")
mkdir_cmd:action(function(ctx)
    local dir_path = ctx.args[1]
    
    -- Check for elevated privileges
    if security.is_elevated() then
        logger.warn("Running with elevated privileges", {
            command = "mkdir",
            user = os.getenv("USER")
        })
        
        logger.warn("⚠️  Warning: Running with elevated privileges")
        if not prompt.confirm("Continue?", false) then
            logger.info("Operation cancelled by user")
            return false
        end
    end
    
    -- Create directory securely
    local success, err = security.safe_mkdir(dir_path)
    
    if success then
        logger.info("Directory created", {path = dir_path})
        logger.info("✅ Directory created: " .. dir_path)
        return true
    else
        logger.error("Failed to create directory", {path = dir_path, error = err})
        logger.error("❌ Error: " .. (err or "Failed to create directory"))
        return false
    end
end)

-- Command: Validate Input
local validate_cmd = app:command("validate", "Validate user input")
validate_cmd:arg("type", "Type to validate (email, url, integer)")
validate_cmd:arg("value", "Value to validate")
validate_cmd:action(function(ctx)
    local input_type = ctx.args[1]
    local input_value = ctx.args[2]
    
    logger.debug("Validating input", {type = input_type, value = input_value})
    
    local valid, err
    
    if input_type == "email" then
        valid, err = security.validate_email(input_value)
    elseif input_type == "url" then
        valid, err = security.validate_url(input_value)
    elseif input_type == "integer" then
        valid, err = security.validate_integer(input_value)
    else
        logger.error("❌ Unknown validation type: " .. input_type)
        logger.info("Available types: email, url, integer")
        return false
    end
    
    if valid then
        logger.info("Validation succeeded", {type = input_type, value = input_value})
        logger.info("✅ Valid " .. input_type .. ": " .. input_value)
        return true
    else
        logger.warn("Validation failed", {type = input_type, value = input_value, error = err})
        logger.error("❌ Invalid " .. input_type .. ": " .. err)
        return false
    end
end)

-- Command: Rate-Limited Operation
local api_cmd = app:command("api-call", "Simulate rate-limited API call")
api_cmd:action(function(ctx)
    -- Check rate limit (max 3 calls per 10 seconds)
    local allowed, err = security.rate_limit("api_call", 3, 10)
    
    if not allowed then
        logger.warn("Rate limit exceeded", {command = "api-call"})
        logger.error("❌ " .. err)
        logger.info("Please wait before trying again.")
        return false
    end
    
    logger.info("API call executed", {timestamp = os.time()})
    logger.info("✅ API call successful")
    logger.info("Remaining calls: Check with multiple rapid calls")
    
    return true
end)

-- Command: Demo Error Handling
local error_cmd = app:command("demo-error", "Demonstrate error handling")
error_cmd:action(function(ctx)
    logger.info("Demonstrating error handling")
    
    -- This will be caught by the error handler in app:run
    error("This is a simulated error for demonstration")
end)

-- Command: Security Check
local check_cmd = app:command("security-check", "Run security diagnostics")
check_cmd:action(function(ctx)
    logger.info("🔒 Security Diagnostics")
    logger.info("=" .. string.rep("=", 50))
    
    -- Check if running as root
    if security.is_elevated() then
        logger.warn("⚠️  WARNING: Running with elevated privileges")
        logger.warn("Security check: elevated privileges detected")
    else
        logger.info("✅ Running with normal user privileges")
    end
    
    -- Check environment
    local debug_mode = os.getenv("LUMOS_DEBUG")
    if debug_mode then
        logger.warn("⚠️  DEBUG mode enabled (not recommended for production)")
    else
        logger.info("✅ DEBUG mode disabled")
    end
    
    -- Check log configuration
    local log_level = logger.get_level()
    logger.info("ℹ️  Log level: " .. log_level)
    
    -- Test validations
    logger.info("\n📋 Testing input validations:")
    
    local tests = {
        {type = "email", value = "test@example.com", should_pass = true},
        {type = "email", value = "invalid-email", should_pass = false},
        {type = "url", value = "https://example.com", should_pass = true},
        {type = "url", value = "ftp://example.com", should_pass = false},
    }
    
    for _, test in ipairs(tests) do
        local valid
        if test.type == "email" then
            valid = security.validate_email(test.value)
        elseif test.type == "url" then
            valid = security.validate_url(test.value)
        end
        
        local icon = (valid == test.should_pass) and "✅" or "❌"
        logger.info(string.format("  %s %s: %s", icon, test.type, test.value))
    end
    
    logger.info("\n✅ Security check complete")
    logger.info("Security check completed")
    
    return true
end)

-- Run the application
os.exit(app:run(arg))
