-- Lumos Configuration Module
-- Simple configuration file loader supporting JSON, YAML, TOML, key-value pairs, and Lua.

local json = require('lumos.json')
local yaml = require('lumos.yaml')
local toml = require('lumos.toml')
local env_loader = require('lumos.env_loader')
local security = require('lumos.security')
local logger = require('lumos.logger')

local config = {}

-- Parse a key=value text block into a Lua table.
-- Lines starting with # are treated as comments.
-- Values are auto-converted to boolean or number when possible.
function config.parse_key_value(content)
    local result = {}
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace
        if line ~= "" and not line:match("^#") then -- ignore empty lines and comments
            local key, value = line:match("^([^=]+)=(.*)$")
            if key and value then
                key   = key:match("^%s*(.-)%s*$")
                value = value:match("^%s*(.-)%s*$")

                if value == "true" then
                    result[key] = true
                elseif value == "false" then
                    result[key] = false
                elseif tonumber(value) then
                    result[key] = tonumber(value)
                else
                    result[key] = value
                end
            end
        end
    end
    return result
end

-- Load configuration from a file
function config.load_file(file_path)
    logger.debug("Loading configuration file", {path = file_path})

    local file, err = security.safe_open(file_path, "r")
    if not file then
        logger.error("Could not open configuration file", {path = file_path, error = err})
        return nil, "Could not open configuration file: " .. (err or file_path)
    end

    local content = file:read("*all")
    file:close()

    -- Try to parse as JSON first
    if file_path:match("%.json$") then
        local success, result = pcall(function()
            return json.decode(content)
        end)
        if success then
            logger.info("Loaded JSON configuration", {path = file_path})
            return result
        else
            logger.error("Invalid JSON in config file", {path = file_path, error = tostring(result)})
            return nil, "Invalid JSON in config file: " .. file_path
        end
    end

    -- Try TOML
    if file_path:match("%.toml$") then
        local success, result = pcall(function()
            return toml.parse(content)
        end)
        if success then
            logger.info("Loaded TOML configuration", {path = file_path})
            return result
        else
            logger.error("Invalid TOML in config file", {path = file_path, error = tostring(result)})
            return nil, "Invalid TOML in config file: " .. file_path
        end
    end

    -- Try YAML
    if file_path:match("%.ya?ml$") then
        local success, result = pcall(function()
            return yaml.decode(content)
        end)
        if success then
            logger.info("Loaded YAML configuration", {path = file_path})
            return result
        else
            logger.error("Invalid YAML in config file", {path = file_path, error = tostring(result)})
            return nil, "Invalid YAML in config file: " .. file_path
        end
    end

    -- Try native Lua config (must return a table)
    if file_path:match("%.lua$") then
        -- Sandbox environment: only pure data-construction functions
        local safe_env = {
            pairs = pairs, ipairs = ipairs, next = next,
            tonumber = tonumber, tostring = tostring, type = type,
            math = math, string = string, table = table,
            os = {date = os.date, time = os.time, difftime = os.difftime, clock = os.clock},
        }
        local chunk, load_err
        if setfenv then
            -- Lua 5.1 / LuaJIT
            chunk, load_err = loadfile(file_path)
            if chunk then setfenv(chunk, safe_env) end
        else
            -- Lua 5.2+
            local f = io.open(file_path, "r")
            if f then
                local content = f:read("*a")
                f:close()
                chunk, load_err = load(content, nil, "t", safe_env)
            else
                load_err = "Cannot read file"
            end
        end
        if not chunk then
            logger.error("Invalid Lua in config file", {path = file_path, error = load_err})
            return nil, "Invalid Lua in config file: " .. file_path .. " (" .. tostring(load_err) .. ")"
        end
        local success, result = pcall(chunk)
        if success then
            if type(result) == "table" then
                logger.info("Loaded Lua configuration", {path = file_path})
                return result
            else
                logger.error("Lua config did not return a table", {path = file_path, type = type(result)})
                return nil, "Lua config must return a table: " .. file_path
            end
        else
            logger.error("Invalid Lua in config file", {path = file_path, error = tostring(result)})
            return nil, "Invalid Lua in config file: " .. file_path .. " (" .. tostring(result) .. ")"
        end
    end

    -- Simple key=value parser for other files
    local result = config.parse_key_value(content)
    logger.info("Loaded key-value configuration", {path = file_path})
    return result
end

-- Load configuration from environment variables with a prefix.
-- On POSIX systems the `env` command is used to enumerate all variables;
-- on Windows the `set` command is used.
function config.load_env(prefix)
    return env_loader.load(prefix)
end

-- Validate a configuration table against a schema.
-- Schema format: { field_name = { type = "string", required = true, validate = function(v) return true end } }
function config.validate_schema(data, schema)
    local errors = {}
    for field, rules in pairs(schema) do
        local value = data[field]
        if rules.required and (value == nil or value == "") then
            table.insert(errors, field .. " is required")
        end
        if value ~= nil and rules.type and type(value) ~= rules.type then
            table.insert(errors, field .. " must be " .. rules.type .. " (got " .. type(value) .. ")")
        end
        if value ~= nil and rules.validate and not rules.validate(value) then
            table.insert(errors, field .. " validation failed")
        end
    end
    return #errors == 0, errors
end

-- Load a configuration file through the in-memory cache.
function config.load_file_cached(path, options)
    local config_cache = require("lumos.config_cache")
    return config_cache.load(path, options)
end

-- Load and validate a configuration file.
function config.load_validated(path, schema)
    local data, err = config.load_file(path)
    if not data then return nil, err end
    local ok, errors = config.validate_schema(data, schema)
    if not ok then
        return nil, "Validation failed: " .. table.concat(errors, "; ")
    end
    return data
end

-- Simple shallow merge of two tables
function config.merge(base, override)
    local result = {}
    if base then
        for k, v in pairs(base) do
            result[k] = v
        end
    end
    if override then
        for k, v in pairs(override) do
            result[k] = v
        end
    end
    return result
end

-- Merge configurations with priority: flags > env > config_file > defaults
function config.merge_configs(defaults, config_file, env_config, flags)
    local merged = {}

    -- Start with defaults
    if defaults then
        for k, v in pairs(defaults) do
            merged[k] = v
        end
    end

    -- Override with config file
    if config_file then
        for k, v in pairs(config_file) do
            merged[k] = v
        end
    end

    -- Override with environment
    if env_config then
        for k, v in pairs(env_config) do
            merged[k] = v
        end
    end

    -- Override with flags (highest priority)
    if flags then
        for k, v in pairs(flags) do
            merged[k] = v
        end
    end

    return merged
end

return config
