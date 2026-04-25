-- Lumos Environment Loader Module
-- Load configuration from environment variables with a prefix.

local logger = require('lumos.logger')
local env_loader = {}

function env_loader.load(prefix)
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
        logger.debug("env_loader.load: could not enumerate environment variables")
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

return env_loader
