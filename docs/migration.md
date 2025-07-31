# 🔄 Lumos Migration & Upgrade Guide

Guide for upgrading Lumos versions and migrating existing CLI applications.

## 📋 Table of Contents

- [Version Compatibility](#version-compatibility)
- [Upgrade Instructions](#upgrade-instructions)
- [Breaking Changes](#breaking-changes)
- [Migration Examples](#migration-examples)
- [Troubleshooting](#troubleshooting)

## 📊 Version Compatibility

| Version | Lua | LuaRocks | Status | Support |
|---------|-----|----------|--------|---------|
| 0.1.x   | 5.1+ | 3.9+ | Current | ✅ Active |
| 0.2.x   | 5.1+ | 3.9+ | Planned | 🚧 Development |

## ⬆️ Upgrade Instructions

### From Source Installation

If you installed Lumos from source:

```bash
# Navigate to your Lumos directory
cd /path/to/lumos

# Pull latest changes
git pull origin main

# Reinstall
bash scripts/install.sh
```

### From LuaRocks (when available)

```bash
# Update to latest version
luarocks install --local lumos

# Or update to specific version
luarocks install --local lumos 0.2.0
```

### Verify Upgrade

```bash
lumos version
# Should show the new version number
```

## 🔧 Breaking Changes

### Version 0.1.0 → 0.2.0 (Planned)

#### API Changes

**Flag Parsing Enhancement**
```lua
-- Old (0.1.x)
cmd:flag("--config", "Config file path")

-- New (0.2.x) - More specific typing
cmd:flag_path("--config", "Config file path")
```

**Configuration Loading**
```lua
-- Old (0.1.x)
local config = lumos.load_config("config.json")

-- New (0.2.x) - More explicit
local config = require('lumos.config')
local settings = config.load_file("config.json")
```

#### Deprecated Features

- `lumos.load_config()` → Use `lumos.config.load_file()`
- Basic flag typing → Use specific `flag_*` methods

### Version 0.2.0 → 0.3.0 (Future)

#### Planned Changes

**Plugin System Introduction**
```lua
-- New plugin registration
lumos.register_plugin('my-plugin', {
    commands = {...},
    ui_components = {...}
})
```

**Enhanced Validation**
```lua
-- New schema-based validation
cmd:flag_string("--email", "Email address")
   :validate(lumos.validators.email)
```

## 📝 Migration Examples

### Migrating a Simple CLI

**Before (0.1.x)**
```lua
local lumos = require('lumos')
local app = lumos.new_app({
    name = "myapp",
    version = "1.0.0"
})

local cmd = app:command("deploy", "Deploy app")
cmd:flag("--env", "Environment")
cmd:option("--config", "Config file")

cmd:action(function(ctx)
    local env = ctx.flags.env or "staging"
    local config_file = ctx.flags.config
    
    if config_file then
        local config = lumos.load_config(config_file)
        -- Use config
    end
    
    print("Deploying to " .. env)
    return true
end)

app:run(arg)
```

**After (0.2.x)**
```lua
local lumos = require('lumos')
local config_loader = require('lumos.config')

local app = lumos.new_app({
    name = "myapp",
    version = "1.0.0"
})

local cmd = app:command("deploy", "Deploy app")
cmd:flag_string("--env", "Environment")
cmd:flag_path("--config", "Config file")

cmd:action(function(ctx)
    local env = ctx.flags.env or "staging"
    local config_file = ctx.flags.config
    
    local config = {}
    if config_file then
        config = config_loader.load_file(config_file)
    end
    
    print("Deploying to " .. env)
    return true
end)

app:run(arg)
```

### Migrating Complex Applications

**Configuration Management Migration**

```lua
-- Old approach (0.1.x)
local function load_app_config()
    local config = {}
    
    -- Load from file
    if file_exists("config.json") then
        config = lumos.load_config("config.json")
    end
    
    -- Override with environment
    if os.getenv("APP_ENV") then
        config.env = os.getenv("APP_ENV")
    end
    
    return config
end

-- New approach (0.2.x)
local function load_app_config()
    local config_loader = require('lumos.config')
    
    return config_loader.merge_configs(
        {env = "development"}, -- defaults
        config_loader.load_file("config.json"),
        config_loader.load_env("APP")
    )
end
```

**UI Component Updates**

```lua
-- Old (0.1.x) - Basic usage
local color = require('lumos.color')
print(color.red("Error: " .. message))

-- New (0.2.x) - Enhanced with formatting
local color = require('lumos.color')
local format = require('lumos.format')

print(color.format("{red}{bold}Error:{reset} " .. message))
```

## 🔍 Migration Checklist

### Pre-Migration

- [ ] Backup your existing project
- [ ] Review breaking changes for your version
- [ ] Update dependencies in your project
- [ ] Test in a separate environment

### During Migration

- [ ] Update Lumos installation
- [ ] Update import statements
- [ ] Replace deprecated API calls
- [ ] Update configuration loading
- [ ] Test each command individually

### Post-Migration

- [ ] Run full test suite
- [ ] Verify CLI generation still works
- [ ] Update project documentation
- [ ] Update CI/CD scripts if needed

## 🛠️ Automated Migration Tools

### Migration Script (Future Feature)

```bash
# Planned migration helper
lumos migrate --from 0.1.0 --to 0.2.0 ./my-cli-project
```

### Code Analysis

```bash
# Check for deprecated usage
lumos check-deprecated ./my-cli-project
```

## 🐛 Troubleshooting

### Common Migration Issues

#### Module Not Found Errors

**Problem**: `module 'lumos.config' not found`

**Solution**:
```bash
# Reinstall Lumos completely
luarocks remove --local lumos
luarocks make --local lumos-dev-1.rockspec
```

#### API Method Not Available

**Problem**: `attempt to call method 'flag_string' (a nil value)`

**Solution**: Check if you're using the correct Lumos version:
```bash
lumos version
# If version is older than expected, upgrade first
```

#### Configuration Loading Broken

**Problem**: Old `lumos.load_config()` not working

**Solution**: Update to new configuration API:
```lua
-- Replace this
local config = lumos.load_config("config.json")

-- With this
local config_loader = require('lumos.config')
local config = config_loader.load_file("config.json")
```

### Migration Testing

Create a test script to verify migration:

```lua
#!/usr/bin/env lua
-- test-migration.lua

local lumos = require('lumos')

-- Test basic functionality
assert(lumos.version, "Version not available")
print("✓ Basic loading works")

-- Test new APIs
local color = require('lumos.color')
assert(color.red, "Color module not working")
print("✓ Color module works")

local config = require('lumos.config')
assert(config.load_file, "Config module not working")
print("✓ Config module works")

print("Migration test passed!")
```

Run with: `lua test-migration.lua`

## 📚 Additional Resources

- [API Reference](api.md) - Complete API documentation
- [Architecture Guide](architecture.md) - Understanding Lumos internals
- [Development Guide](dev.md) - Contributing to Lumos
- [Examples](use.md) - Real-world usage examples

## 🆘 Getting Help

If you encounter issues during migration:

1. **Check the documentation** for your specific version
2. **Search existing issues** on GitHub
3. **Create an issue** with:
   - Current Lumos version
   - Target version
   - Error messages
   - Minimal reproduction example

## 📅 Migration Schedule

| Version | Release Date | Migration Window | End of Support |
|---------|-------------|------------------|----------------|
| 0.1.x   | Current     | N/A              | 6 months after 0.2.0 |
| 0.2.x   | Q2 2024     | 3 months         | 6 months after 0.3.0 |

**Migration Window**: Period during which both old and new APIs are supported.
**End of Support**: After this date, only security fixes will be provided.
