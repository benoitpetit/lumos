-- Lumos Configuration Module
-- Simple configuration file loader supporting JSON and basic key-value pairs

local json = require('lumos.json')

local config = {}

-- Load configuration from a file
function config.load_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Could not open configuration file: " .. file_path
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Try to parse as JSON first
    if file_path:match("%.json$") then
        local success, result = pcall(function()
            return json.decode(content)
        end)
        if success then
            return result
        else
            return nil, "Invalid JSON in config file: " .. file_path
        end
    end
    
    -- Simple key=value parser for other files
    local config = {}
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace
        if line ~= "" and not line:match("^#") then -- ignore empty lines and comments
            local key, value = line:match("^([^=]+)=(.*)$")
            if key and value then
                key = key:match("^%s*(.-)%s*$")
                value = value:match("^%s*(.-)%s*$")
                
                -- Try to convert value to appropriate type
                if value == "true" then
                    config[key] = true
                elseif value == "false" then
                    config[key] = false
                elseif tonumber(value) then
                    config[key] = tonumber(value)
                else
                    config[key] = value
                end
            end
        end
    end
    
    return config
end

-- Load configuration from environment variables with a prefix
function config.load_env(prefix)
    local config = {}
    prefix = prefix and (prefix .. "_") or ""
    
    -- Simple environment variable reader
    -- In a real implementation, you might use os.getenv in a loop
    -- For now, we'll provide a basic structure
    local common_vars = {
        "DEBUG", "VERBOSE", "CONFIG_FILE", "LOG_LEVEL", 
        "OUTPUT_FORMAT", "COLOR", "TIMEOUT"
    }
    
    for _, var in ipairs(common_vars) do
        local env_var = prefix .. var
        local value = os.getenv(env_var)
        if value then
            local key = var:lower()
            
            -- Convert to appropriate type
            if value == "true" then
                config[key] = true
            elseif value == "false" then
                config[key] = false
            elseif tonumber(value) then
                config[key] = tonumber(value)
            else
                config[key] = value
            end
        end
    end
    
    return config
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
