-- Lumos Validator Module
-- Argument and flag validation

local flags = require('lumos.flags')

local validator = {}

-- Validate positional arguments based on command definitions
function validator.validate_args(cmd, parsed_args)
    local validated = {}
    local errors = {}
    if not cmd or not cmd.args then
        return parsed_args.args or {}, errors
    end
    
    for i, arg_def in ipairs(cmd.args) do
        local value = parsed_args.args[i]
        
        -- Apply default if argument is missing
        if value == nil and arg_def.default ~= nil then
            value = arg_def.default
        end
        
        repeat
            -- Required check
            if arg_def.required and (value == nil or value == "") then
                table.insert(errors, "Argument '" .. arg_def.name .. "' is required")
                break
            end
            
            -- Skip further validation if value is still nil (and not required)
            if value == nil then
                table.insert(validated, value)
                break
            end
            
            -- Type validation via flags module (reuse flag_def shape)
            local fake_flag = {
                type = arg_def.type,
                min = arg_def.min,
                max = arg_def.max
            }
            local valid, result = flags.validate_flag(fake_flag, value)
            if not valid then
                table.insert(errors, "Argument '" .. arg_def.name .. "' " .. result)
                break
            end
            
            -- Custom validator
            if arg_def.validate then
                local ok, err_msg = pcall(arg_def.validate, result)
                if not ok then
                    table.insert(errors, "Argument '" .. arg_def.name .. "' validation failed: " .. tostring(err_msg))
                    break
                elseif err_msg == false then
                    table.insert(errors, "Argument '" .. arg_def.name .. "' is invalid")
                    break
                end
            end
            
            table.insert(validated, result)
        until true
    end
    
    return validated, errors
end

-- Validate and merge flags (including persistent flags)
function validator.validate_and_merge_flags(app, cmd, parsed_flags)
    local merged_flags = {}
    local errors = {}
    
    -- Helper function to validate a flag
    local function validate_single_flag(flag_name, flag_value, flag_def)
        local valid, result = flags.validate_flag(flag_def, flag_value)
        if not valid then
            table.insert(errors, "Flag --" .. flag_name .. " " .. result)
            return false
        end
        if flag_def.custom_validator then
            local ok, err_msg = pcall(flag_def.custom_validator, result)
            if not ok then
                table.insert(errors, "Flag --" .. flag_name .. " validation failed: " .. tostring(err_msg))
                return false
            elseif err_msg == false then
                table.insert(errors, "Flag --" .. flag_name .. " is invalid")
                return false
            end
        end
        merged_flags[flag_name] = result
        return true
    end
    
    local function process_flag_defs(flag_defs)
        if not flag_defs then return end
        for flag_name, flag_def in pairs(flag_defs) do
            local env_value = nil
            if flag_def.env then
                env_value = os.getenv(flag_def.env)
            end
            local value = parsed_flags[flag_name] or parsed_flags[flag_def.short] or env_value or flag_def.default
            if value ~= nil then
                if flag_def.deprecated then
                    local color = require('lumos.color')
                    io.stderr:write(color.yellow("Warning: Flag --" .. flag_name .. " is deprecated. " .. (flag_def.deprecation_message or "") .. "\n"))
                end
                validate_single_flag(flag_name, value, flag_def)
            elseif flag_def.required then
                table.insert(errors, "Flag --" .. flag_name .. " is required")
            end
        end
    end
    
    -- Start with app-level global flags (non-persistent, app-scoped)
    process_flag_defs(app.global_flags)
    
    -- Add app-level persistent flags
    process_flag_defs(app.persistent_flags)
    
    -- Add command-level persistent flags
    process_flag_defs(cmd and cmd.persistent_flags or nil)
    
    -- Add command-specific flags
    process_flag_defs(cmd and cmd.flags or nil)
    
    -- Copy remaining parsed flags that weren't validated
    for flag_name, flag_value in pairs(parsed_flags) do
        if merged_flags[flag_name] == nil then
            merged_flags[flag_name] = flag_value
        end
    end

    -- Validate mutex groups
    if cmd and cmd.mutex_groups then
        for name, group in pairs(cmd.mutex_groups) do
            local count = 0
            local found = {}
            for _, flag in ipairs(group.flags) do
                local key = flag.long or flag.short
                if merged_flags[key] ~= nil then
                    count = count + 1
                    table.insert(found, "--" .. key)
                end
            end
            if count > 1 then
                table.insert(errors, "Flags " .. table.concat(found, ", ") .. " are mutually exclusive")
            elseif group.required and count == 0 then
                table.insert(errors, "At least one of " .. name .. " flags is required")
            end
        end
    end

    return merged_flags, errors
end

return validator
