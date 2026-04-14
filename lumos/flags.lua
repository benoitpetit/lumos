-- Lumos Flags Module
local flags = {}

-- Flag validators
local validators = {
    int = function(value)
        local num = tonumber(value)
        return num and math.floor(num) == num, "must be an integer"
    end,
    
    number = function(value)
        local num = tonumber(value)
        return num ~= nil, "must be a number"
    end,
    
    email = function(value)
        local pattern = "^[A-Za-z0-9%.%+_%%-]+@[A-Za-z0-9%-]+%.[A-Za-z]+$"
        return value:match(pattern) ~= nil, "must be a valid email"
    end,
    
    url = function(value)
        local pattern = "^https?://[%w%.%-]+[%w%.%-/]*$"
        return value:match(pattern) ~= nil, "must be a valid URL"
    end,
    
    path = function(value)
        return value and value ~= "", "must be a valid path"
    end
}

-- Validate flag value based on type and constraints
function flags.validate_flag(flag_def, value)
    if not flag_def then
        return true, value
    end
    
    -- Type validation
    if flag_def.type and validators[flag_def.type] then
        local valid, error_msg = validators[flag_def.type](value)
        if not valid then
            return false, error_msg
        end
        
        -- Convert value to appropriate type
        if flag_def.type == "int" or flag_def.type == "number" then
            value = tonumber(value)
        end
    end
    
    -- Range validation for numbers
    if flag_def.min and value < flag_def.min then
        return false, "must be >= " .. flag_def.min
    end
    
    if flag_def.max and value > flag_def.max then
        return false, "must be <= " .. flag_def.max
    end
    
    -- Required validation
    if flag_def.required and (value == nil or value == "") then
        return false, "is required"
    end
    
    return true, value
end

-- Parse a single flag and return its name, value, and index
function flags.parse_single_flag(arg, args, start_index)
    local name, value
    local next_index = start_index + 1

    if arg:sub(1, 2) == "--" then
        -- Long flag
        name = arg:sub(3)
        local eq_pos = name:find("=")
        if eq_pos then
            value = name:sub(eq_pos + 1)
            name = name:sub(1, eq_pos - 1)
        elseif next_index <= #args and not args[next_index]:match("^%-%-?") then
            value = args[next_index]
            next_index = next_index + 1
        else
            value = true  -- Boolean flag
        end
        -- Normalize hyphens to underscores so --dry-run → ctx.flags.dry_run
        name = name:gsub("-", "_")
    elseif arg:sub(1, 1) == "-" then
        -- Short flag
        name = arg:sub(2, 2)
        if #arg > 2 then
            value = arg:sub(3)
        elseif next_index <= #args and not args[next_index]:match("^%-%-?") then
            value = args[next_index]
            next_index = next_index + 1
        else
            value = true
        end
    end

    return {name = name, value = value, next_index = next_index}
end

return flags
