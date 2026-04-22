#  Lumos Security Guide

Security guide and best practices for using Lumos in production.

## Table of Contents

- [Overview](#overview)
- [Security Features](#security-features)
- [Best Practices](#best-practices)
- [Protection Against Vulnerabilities](#protection-against-vulnerabilities)
- [Secure Configuration](#secure-configuration)
- [Audit and Monitoring](#audit-and-monitoring)
- [Deployment Checklist](#deployment-checklist)

## Overview

Lumos includes robust security features to protect your CLI applications against common vulnerabilities.

### Security Modules

- **`lumos.security`** - Input sanitization, validation, and safe operations
- **`lumos.logger`** - Structured logging for audit trails

## Security Features

### security.lua Module

The `security` module provides functions to secure your applications:

```lua
local security = require('lumos.security')

-- Escape shell arguments
local safe_arg = security.shell_escape(user_input)
os.execute("ls " .. safe_arg)

-- Validate paths
local path, err = security.sanitize_path(user_path)
if not path then
    print("Invalid path: " .. err)
    return
end

-- Open files safely
local file, err = security.safe_open(path, "r")
if not file then
    print("Cannot open file: " .. err)
    return
end

-- Validate emails
local valid, err = security.validate_email(email)
if not valid then
    print("Invalid email: " .. err)
end

-- Validate URLs
local valid, err = security.validate_url(url)
if not valid then
    print("Invalid URL: " .. err)
end

-- Validate integers with ranges
local valid, num = security.validate_integer(value, 1, 100)
if not valid then
    print("Invalid integer")
end

-- Validate command names
local name, err = security.sanitize_command_name(cmd_name)
if not name then
    print("Invalid command name: " .. err)
end

-- Sanitize terminal output
local clean = security.sanitize_output(user_input)

-- Check for elevated privileges
if security.is_elevated() then
    print("Warning: running as root")
end

-- Rate limiting
local allowed, err = security.rate_limit("api_call", 10, 60)
if not allowed then
    print("Rate limit exceeded")
end
```

### logger.lua Module

The `logger` module offers structured logging with levels:

```lua
local logger = require('lumos.logger')

-- Different log levels
logger.error("Critical error occurred", {user = "admin", code = 500})
logger.warn("Deprecated feature used", {feature = "old_api"})
logger.info("User logged in", {user = "john", ip = "192.168.1.1"})
logger.debug("Cache miss", {key = "user:123"})
logger.trace("Function entry", {func = "process_data"})

-- Configuration
logger.set_level("INFO")  -- or logger.LEVELS.INFO
logger.set_output("/var/log/myapp.log")
logger.set_timestamp(true)
logger.set_colors(true)

-- Configure from environment
logger.configure_from_env("MYAPP")  -- Reads MYAPP_LOG_LEVEL, etc.

-- Logger with fixed context
local user_logger = logger.child({user = "john", session = "abc123"})
user_logger.info("Action performed")  -- Automatically includes context

-- Auto-level detection based on keywords
logger.auto("Error: connection failed")  -- Logs as ERROR
logger.auto("Warning: disk space low")   -- Logs as WARN
logger.auto("Debug trace here")          -- Logs as DEBUG
logger.auto("Server started")            -- Logs as INFO
```

## Best Practices

### 1. User Input Validation

**BAD:**
```lua
local cmd = app:command("delete", "Delete file")
cmd:arg("file", "File to delete")
cmd:action(function(ctx)
    os.execute("rm " .. ctx.args[1])  -- DANGEROUS!
end)
```

**GOOD:**
```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

local cmd = app:command("delete", "Delete file")
cmd:arg("file", "File to delete")
cmd:action(function(ctx)
    local file_path, err = security.sanitize_path(ctx.args[1])
    if not file_path then
        logger.error("Invalid file path", {error = err, input = ctx.args[1]})
        print("Error: " .. err)
        return false
    end
    
    local escaped_path = security.shell_escape(file_path)
    local success = os.execute("rm " .. escaped_path)
    
    if success then
        logger.info("File deleted", {path = file_path})
        return true
    else
        logger.error("Failed to delete file", {path = file_path})
        return false
    end
end)
```

### 2. Secure File Handling

**BAD:**
```lua
local file = io.open(user_provided_path, "w")
file:write(data)
file:close()
```

**GOOD:**
```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

local file, err = security.safe_open(user_provided_path, "w")
if not file then
    logger.error("Cannot open file", {path = user_provided_path, error = err})
    print("Error: " .. err)
    return false
end

file:write(data)
file:close()
logger.info("File written successfully", {path = user_provided_path})
```

### 3. Appropriate Logging

```lua
local logger = require('lumos.logger')

-- Log important actions
cmd:action(function(ctx)
    logger.info("Command executed", {
        command = ctx.command.name,
        user = os.getenv("USER"),
        args = ctx.args,
        flags = ctx.flags
    })
    
    -- Your business logic...
    
    if error_occurred then
        logger.error("Operation failed", {
            command = ctx.command.name,
            error = error_message,
            details = error_details
        })
    end
end)
```

### 4. Protection Against Privilege Escalation

```lua
local security = require('lumos.security')
local logger = require('lumos.logger')

-- Check if running with elevated privileges
if security.is_elevated() then
    logger.warn("Running with elevated privileges", {
        user = os.getenv("USER"),
        uid = security.is_elevated() and 0 or nil
    })
    
    print("  Warning: Running as root/administrator")
    print("This is not recommended for this command.")
    
    -- Ask for confirmation
    local prompt = require('lumos.prompt')
    if not prompt.confirm("Continue anyway?", false) then
        return false
    end
end
```

## Protection Against Vulnerabilities

### Shell Command Injection

**Problem:** Execution of arbitrary commands via malicious input.

**Solution:**
```lua
local security = require('lumos.security')

-- Always escape arguments
local safe_filename = security.shell_escape(filename)
os.execute("cat " .. safe_filename)

-- Or use validated paths
local path, err = security.sanitize_path(filename)
if path then
    os.execute("cat " .. security.shell_escape(path))
end
```

### Path Traversal

**Problem:** Access to files outside the allowed directory.

**Solution:**
```lua
local security = require('lumos.security')

-- Validate the path
local path, err = security.sanitize_path(user_path)
if not path then
    print("Invalid path: " .. err)
    return false
end

-- Verify path is within allowed directory
local allowed_dir = "/var/app/data/"
if not path:match("^" .. allowed_dir) then
    logger.warn("Path traversal attempt", {path = path})
    print("Access denied: path outside allowed directory")
    return false
end
```

### Prompt Code Injection

**Problem:** Malicious escape sequences in inputs.

**Solution:**
```lua
local security = require('lumos.security')
local prompt = require('lumos.prompt')

local input = prompt.input("Enter name")
local safe_input = security.sanitize_output(input)

-- Use safe_input instead of input
print("Hello, " .. safe_input)
```

### Rate Limiting

**Problem:** Resource abuse through repeated calls.

**Solution:**
```lua
local security = require('lumos.security')

local cmd = app:command("api-call", "Call external API")
cmd:action(function(ctx)
    local allowed, err = security.rate_limit("api_call", 10, 60)
    if not allowed then
        logger.warn("Rate limit exceeded", {command = "api-call"})
        print("Error: Too many requests. Please wait.")
        return false
    end
    
    -- API call...
end)
```

## Secure Configuration

### Environment Variables

```bash
# Logging
export LUMOS_LOG_LEVEL=INFO
export LUMOS_LOG_FILE=/var/log/myapp.log
export LUMOS_LOG_TIMESTAMP=true

# Disable colors in production
export LUMOS_NO_COLOR=1

# Debug mode (includes stacktraces)
export LUMOS_DEBUG=1
```

### File Permissions

```bash
# Configuration files
chmod 600 config.json

# Data directories
chmod 700 /var/app/data

# Logs
chmod 640 /var/log/myapp.log
chown app:log /var/log/myapp.log
```

### Secure Configuration Loading

```lua
local config = require('lumos.config')
local security = require('lumos.security')
local logger = require('lumos.logger')

-- Validate config file path
local config_path = os.getenv("APP_CONFIG") or "./config.json"
local validated_path, err = security.sanitize_path(config_path)

if not validated_path then
    logger.error("Invalid config path", {path = config_path, error = err})
    os.exit(1)
end

-- Load config
local cfg, load_err = config.load_file(validated_path)
if not cfg then
    logger.error("Failed to load config", {error = load_err})
    os.exit(1)
end

logger.info("Configuration loaded", {path = validated_path})
```

## Audit and Monitoring

### Logging Security Events

```lua
local logger = require('lumos.logger')

-- Connections/Authentication
logger.info("User authenticated", {
    user = username,
    method = "password",
    ip = remote_ip
})

-- Denied access attempts
logger.warn("Access denied", {
    user = username,
    resource = resource_path,
    reason = "insufficient_permissions"
})

-- Sensitive modifications
logger.info("Configuration changed", {
    user = username,
    file = config_file,
    changes = changed_keys
})

-- Security errors
logger.error("Security violation detected", {
    type = "path_traversal",
    user = username,
    input = malicious_input
})
```

### Structured Log Format

Logs are formatted as:
```
2026-01-21 14:30:45 [ERROR] Security violation detected [type=path_traversal user=john input=../../etc/passwd]
```

Easily parseable with tools like `jq`, `grep`, or centralized logging systems (ELK, Splunk, etc.).

## Deployment Checklist

### Before Deploying to Production

- [ ] All user inputs are validated with `security.sanitize_*`
- [ ] Shell commands use `security.shell_escape()`
- [ ] Files are opened with `security.safe_open()`
- [ ] Logging is configured with appropriate levels
- [ ] Security events are logged
- [ ] File permissions are correct (600/700)
- [ ] Debug mode is disabled (`LUMOS_DEBUG` not set)
- [ ] Stacktraces are not exposed to users
- [ ] Rate limiting is implemented for expensive operations
- [ ] Dependencies are up to date (`luarocks list`)
- [ ] Security tests pass (`busted spec/security_spec.lua`)

### Continuous Monitoring

- [ ] Logs are collected and analyzed regularly
- [ ] Alerts are configured for critical events
- [ ] Performance metrics are tracked
- [ ] Intrusion attempts are detected
- [ ] Security updates are applied promptly

## In Case of Security Incident

1. **Isolate**: Stop the application if necessary
2. **Analyze**: Examine logs with `logger`
3. **Contain**: Identify and block the source
4. **Fix**: Patch the vulnerability
5. **Verify**: Test the fix
6. **Document**: Create a post-mortem

### Log Analysis

```bash
# Search for path traversal attempts
grep "path_traversal" /var/log/myapp.log

# Search for security errors
grep "\[ERROR\]" /var/log/myapp.log | grep -i security

# Analyze exceeded rate limits
grep "Rate limit exceeded" /var/log/myapp.log

# Denied access attempts
grep "Access denied" /var/log/myapp.log
```

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE - Common Weakness Enumeration](https://cwe.mitre.org/)
- [Lua Security Considerations](https://www.lua.org/pil/8.1.html)

## Updates

This security guide is updated regularly. Review it before each major deployment.

---

**Guide Version:** 1.0  
**Last Updated:** April 2026  
**Lumos Framework:** v0.3.7+
