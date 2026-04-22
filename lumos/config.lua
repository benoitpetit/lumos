-- Lumos Configuration Module
-- Simple configuration file loader supporting JSON, YAML, TOML and basic key-value pairs

local json = require('lumos.json')
local yaml = require('lumos.yaml')
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

-- Minimal TOML parser supporting nested tables, inline tables, arrays, strings, numbers, booleans
function config.parse_toml(content)
    local result = {}
    local section = nil       -- current dotted section path (string)
    local section_type = nil  -- "table" or "array"

    -- Helper: split a dotted path into parts
    local function split_path(path)
        local parts = {}
        for part in path:gmatch("[^.]+") do
            table.insert(parts, part)
        end
        return parts
    end

    -- Helper: ensure nested tables exist and return the deepest table + last key
    local function ensure_table(root, parts)
        local current = root
        for i = 1, #parts - 1 do
            local part = parts[i]
            if type(current[part]) ~= "table" then
                current[part] = {}
            end
            current = current[part]
        end
        return current, parts[#parts]
    end

    -- Helper: parse a TOML value (scalar, array, inline table)
    local function parse_value(val)
        val = val:match("^%s*(.-)%s*$")
        if val == "" then return nil end

        -- Inline table
        if val:match("^%{") then
            local obj = {}
            local inner = val:match("^%{(.*)%}$")
            if inner then
                inner = inner:match("^%s*(.-)%s*$")
                -- Simple split by comma at top level
                local depth = 0
                local current = ""
                local kv_pairs = {}
                for i = 1, #inner do
                    local c = inner:sub(i, i)
                    if c == "{" then
                        depth = depth + 1
                        current = current .. c
                    elseif c == "}" then
                        depth = depth - 1
                        current = current .. c
                    elseif c == "," and depth == 0 then
                        table.insert(kv_pairs, current)
                        current = ""
                    else
                        current = current .. c
                    end
                end
                if current ~= "" then
                    table.insert(kv_pairs, current)
                end
                for _, kv in ipairs(kv_pairs) do
                    local k, v = kv:match("^%s*([%w_%-]+)%s*=%s*(.*)$")
                    if k then
                        obj[k] = parse_value(v)
                    end
                end
            end
            return obj
        end

        -- Array
        if val:match("^%[") then
            local arr = {}
            local inner = val:match("^%[(.*)%]$") or ""
            local depth = 0
            local current = ""
            for i = 1, #inner do
                local c = inner:sub(i, i)
                if c == "[" then
                    depth = depth + 1
                    current = current .. c
                elseif c == "]" then
                    depth = depth - 1
                    current = current .. c
                elseif c == "," and depth == 0 then
                    if current:match("%S") then
                        table.insert(arr, parse_value(current))
                    end
                    current = ""
                else
                    current = current .. c
                end
            end
            if current:match("%S") then
                table.insert(arr, parse_value(current))
            end
            return arr
        end

        -- String
        local str = val:match('^"(.*)"$') or val:match("^'(.*)'$")
        if str then
            return str
        end

        -- Boolean
        local lower = val:lower()
        if lower == "true" then return true end
        if lower == "false" then return false end

        -- Number
        local num = tonumber(val)
        if num then return num end

        -- Raw string
        return val
    end

    -- Helper: set a value in result under current section
    local function set_key(key, value)
        local parts
        if section then
            parts = split_path(section .. "." .. key)
        else
            parts = split_path(key)
        end
        local tbl, last = ensure_table(result, parts)
        tbl[last] = value
    end

    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            -- Table array [[section]]
            local arr_sec = line:match("^%[%[(.-)%]%]$")
            if arr_sec then
                section = arr_sec:gsub("%s+", "")
                section_type = "array"
                local parts = split_path(section)
                local tbl, last = ensure_table(result, parts)
                if type(tbl[last]) ~= "table" then
                    tbl[last] = {}
                end
                local new_entry = {}
                table.insert(tbl[last], new_entry)
                -- Redirect subsequent keys into the new entry
                -- We do this by treating section as the path to the new entry
                section = section .. "." .. tostring(#tbl[last])
                -- But this is tricky... let's instead store the array entry path
                -- Actually, simpler: store that we're in an array entry
                section_type = "array_entry"
                -- Override ensure_table behavior for array entries
                -- We need a way to know the current array entry
                -- Let's store the current array entry table directly
                result._toml_current_array_entry = new_entry
                result._toml_array_entry_depth = #parts
            else
                -- Section header [section] or [section.subsection]
                local sec = line:match("^%[([^%]]+)%]$")
                if sec then
                    section = sec:gsub("%s+", "")
                    section_type = "table"
                    result._toml_current_array_entry = nil
                    -- Ensure the table exists
                    local parts = split_path(section)
                    local tbl, last = ensure_table(result, parts)
                    if type(tbl[last]) ~= "table" then
                        tbl[last] = {}
                    end
                else
                    local key, value = line:match("^([%w_%-]+)%s*=%s*(.*)$")
                    if key and value then
                        -- Trim trailing comment (naive: everything after unquoted #)
                        local val_str = value:match("^(.-)%s*#.*$") or value
                        local parsed = parse_value(val_str)
                        if result._toml_current_array_entry and section_type == "array_entry" then
                            result._toml_current_array_entry[key] = parsed
                        else
                            set_key(key, parsed)
                        end
                    end
                end
            end
        end
    end

    -- Clean up internal markers
    result._toml_current_array_entry = nil
    result._toml_array_entry_depth = nil
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

    -- Simple key=value parser for other files
    local result = config.parse_key_value(content)
    logger.info("Loaded key-value configuration", {path = file_path})
    return result
end

-- Load configuration from environment variables with a prefix.
-- On POSIX systems the `env` command is used to enumerate all variables;
-- on Windows the `set` command is used.
function config.load_env(prefix)
    local result = {}
    local filter = prefix and (prefix .. "_") or ""

    local is_windows = package.config:sub(1,1) == "\\"
    local cmd
    if is_windows then
        cmd = "set 2>nul"
    else
        cmd = "env 2>/dev/null"
    end

    local handle = io.popen(cmd)
    if not handle then
        logger.debug("config.load_env: could not enumerate environment variables")
        return result
    end

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
