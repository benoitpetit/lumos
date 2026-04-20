-- Lumos Configuration Module
-- Simple configuration file loader supporting JSON and basic key-value pairs

local json = require('lumos.json')
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

-- Minimal TOML parser supporting flat tables, basic arrays, strings, numbers, booleans
function config.parse_toml(content)
    local result = {}
    local section = nil
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            -- Section header [section] or [section.subsection]
            local sec = line:match("^%[([^%]]+)%]$")
            if sec then
                section = sec:gsub("%s+", "")
            else
                local key, value = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                if key and value then
                    local full_key = section and (section .. "." .. key) or key
                    -- Trim trailing comment (naive: everything after unquoted #)
                    local val = value:match("^(.-)%s*#.*$") or value
                    val = val:match("^%s*(.-)%s*$")
                    -- String
                    local str = val:match('^"(.*)"$') or val:match("^'(.*)'$")
                    if str then
                        result[full_key] = str
                    elseif val:lower() == "true" then
                        result[full_key] = true
                    elseif val:lower() == "false" then
                        result[full_key] = false
                    elseif tonumber(val) then
                        result[full_key] = tonumber(val)
                    elseif val:match("^%[") then
                        -- Basic array [1, 2, "three"]
                        local arr = {}
                        local arr_content = val:match("^%[(.*)%]$") or ""
                        for item in arr_content:gmatch("([^,]+)") do
                            item = item:match("^%s*(.-)%s*$")
                            local item_str = item:match('^"(.*)"$') or item:match("^'(.*)'$")
                            if item_str then
                                table.insert(arr, item_str)
                            elseif item:lower() == "true" then
                                table.insert(arr, true)
                            elseif item:lower() == "false" then
                                table.insert(arr, false)
                            elseif tonumber(item) then
                                table.insert(arr, tonumber(item))
                            else
                                table.insert(arr, item)
                            end
                        end
                        result[full_key] = arr
                    else
                        result[full_key] = val
                    end
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
            return config.parse_toml(content)
        end)
        if success then
            logger.info("Loaded TOML configuration", {path = file_path})
            return result
        else
            logger.error("Invalid TOML in config file", {path = file_path, error = tostring(result)})
            return nil, "Invalid TOML in config file: " .. file_path
        end
    end

    -- Simple key=value parser for other files
    local result = config.parse_key_value(content)
    logger.info("Loaded key-value configuration", {path = file_path})
    return result
end

-- Load configuration from environment variables with a prefix.
-- On POSIX systems the `env` command is used to enumerate all variables;
-- on Windows (or when `env` is unavailable) the function returns an empty
-- table to avoid a crash with an unresolvable shell command.
function config.load_env(prefix)
    local result = {}
    local filter = prefix and (prefix .. "_") or ""

    -- Portability guard: io.popen("env") does not work on Windows.
    local is_windows = package.config:sub(1,1) == "\\"
    if is_windows then
        logger.debug("config.load_env: skipping env enumeration on Windows")
        return result
    end

    local handle = io.popen("env 2>/dev/null")
    if not handle then return result end

    for line in handle:lines() do
        -- Guard against multi-line values embedded in a single popen line:
        -- only process lines that contain an '=' sign.
        local key, value = line:match("^([^=\n]+)=(.*)")
        if key then
            local match = filter == "" or key:sub(1, #filter) == filter
            if match then
                local short_key = (filter ~= "" and key:sub(#filter + 1) or key):lower()
                if short_key ~= "" then
                    if value == "true" then
                        result[short_key] = true
                    elseif value == "false" then
                        result[short_key] = false
                    elseif tonumber(value) then
                        result[short_key] = tonumber(value)
                    else
                        result[short_key] = value
                    end
                end
            end
        end
    end
    handle:close()

    return result
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
