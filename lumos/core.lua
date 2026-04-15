-- Lumos Core Module
local flags = require('lumos.flags')
local logger = require('lumos.logger')
local config_module = require('lumos.config')

local core = {}

-- Exit code constants
 core.EXIT_OK = 0
 core.EXIT_ERROR = 1
 core.EXIT_USAGE = 2

-- Configuration file loader — delegates to config module to avoid duplication
function core.load_config(file_path)
    return config_module.load_file(file_path)
end

-- Levenshtein distance for "Did you mean?" suggestions
local function levenshtein(s, t)
    local m, n = #s, #t
    if m == 0 then return n end
    if n == 0 then return m end
    local d = {}
    for i = 0, m do d[i] = {} end
    for i = 0, m do d[i][0] = i end
    for j = 0, n do d[0][j] = j end
    for i = 1, m do
        for j = 1, n do
            local cost = s:byte(i) == t:byte(j) and 0 or 1
            d[i][j] = math.min(d[i-1][j] + 1, math.min(d[i][j-1] + 1, d[i-1][j-1] + cost))
        end
    end
    return d[m][n]
end

-- Suggest a similar command name when input is unknown
function core.suggest_command(app, input_name)
    local best_match = nil
    local best_distance = math.huge
    for _, cmd in ipairs(app.commands) do
        local names = {cmd.name}
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do table.insert(names, alias) end
        end
        for _, name in ipairs(names) do
            local dist = levenshtein(input_name, name)
            if dist < best_distance and dist <= 2 then
                best_distance = dist
                best_match = name
            end
        end
    end
    return best_match
end

-- Parse command line arguments into structured data with subcommand support
function core.parse_arguments(args, app)
    local parsed = {
        command = nil,
        subcommand = nil,
        flags = {},
        args = {},
        raw_args = args or {}
    }
    
    if not args or #args == 0 then
        return parsed
    end
    
    local i = 1
    local command_count = 0
    
    while i <= #args do
        local arg = args[i]
        
        -- Handle flags (starting with - or --)
        if arg:match('^%-%-?') then
            local flag_result = flags.parse_single_flag(arg, args, i)
            parsed.flags[flag_result.name] = flag_result.value
            i = flag_result.next_index
        -- Handle commands and subcommands
        elseif command_count == 0 then
            parsed.command = arg
            command_count = 1
            i = i + 1
        elseif command_count == 1 and app then
            -- Check if this could be a subcommand
            local cmd = core.find_command(app, parsed.command)
            if cmd and cmd.subcommands then
                local subcmd = core.find_subcommand(cmd, arg)
                if subcmd then
                    parsed.subcommand = arg
                    command_count = 2
                    i = i + 1
                else
                    -- Not a subcommand, treat as positional argument
                    table.insert(parsed.args, arg)
                    i = i + 1
                end
            else
                -- No subcommands possible, treat as positional argument
                table.insert(parsed.args, arg)
                i = i + 1
            end
        else
            -- All remaining non-flag arguments are positional arguments
            table.insert(parsed.args, arg)
            i = i + 1
        end
    end
    
    return parsed
end

-- Find and return the matching command from the app (including aliases)
function core.find_command(app, command_name)
    if not command_name then
        return nil
    end
    
    for _, cmd in ipairs(app.commands) do
        -- Check main command name
        if cmd.name == command_name then
            return cmd
        end
        
        -- Check aliases
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                if alias == command_name then
                    return cmd
                end
            end
        end
    end
    
    return nil
end

-- Find subcommand within a command
function core.find_subcommand(command, subcommand_name)
    if not command.subcommands or not subcommand_name then
        return nil
    end
    
    for _, subcmd in ipairs(command.subcommands) do
        if subcmd.name == subcommand_name then
            return subcmd
        end
    end
    
    return nil
end

-- Validate positional arguments based on command definitions
function core.validate_args(cmd, parsed_args)
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
        
        -- Required check
        if arg_def.required and (value == nil or value == "") then
            table.insert(errors, "Argument '" .. arg_def.name .. "' is required")
            goto continue
        end
        
        -- Skip further validation if value is still nil (and not required)
        if value == nil then
            table.insert(validated, value)
            goto continue
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
            goto continue
        end
        
        -- Custom validator
        if arg_def.validate then
            local ok, err_msg = pcall(arg_def.validate, result)
            if not ok then
                table.insert(errors, "Argument '" .. arg_def.name .. "' validation failed: " .. tostring(err_msg))
                goto continue
            elseif err_msg == false then
                table.insert(errors, "Argument '" .. arg_def.name .. "' is invalid")
                goto continue
            end
        end
        
        table.insert(validated, result)
        ::continue::
    end
    
    return validated, errors
end

-- Validate and merge flags (including persistent flags)
function core.validate_and_merge_flags(app, cmd, parsed_flags)
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
    
    return merged_flags, errors
end

-- Run a list of hooks, returning false if any hook errors
local function run_hooks(hooks, context)
    if not hooks then return true end
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(hook, context)
        if not ok then
            io.stderr:write("Error in hook: " .. tostring(err) .. "\n")
            return false
        end
    end
    return true
end

-- Execute the appropriate command with parsed arguments
function core.execute_command(app, parsed_args)
    local cmd = core.find_command(app, parsed_args.command)
    
    if not cmd then
        if parsed_args.command then
            logger.warn("Unknown command", {command = parsed_args.command})
            io.stderr:write("Error: Unknown command '" .. parsed_args.command .. "'\n")
            local suggestion = core.suggest_command(app, parsed_args.command)
            if suggestion then
                io.stderr:write("Did you mean '" .. suggestion .. "'?\n")
            end
            core.show_help(app)
            return core.EXIT_USAGE
        else
            core.show_help(app)
            return core.EXIT_OK
        end
    end
    
    logger.debug("Executing command", {command = cmd.name, args = parsed_args.args})
    
    -- Handle subcommands if present
    if parsed_args.subcommand and cmd.subcommands then
        local subcmd = core.find_subcommand(cmd, parsed_args.subcommand)
        if subcmd then
            -- Check for help flag on subcommand
            if parsed_args.flags.help or parsed_args.flags.h then
                core.show_command_help(app, subcmd)
                return core.EXIT_OK
            end
            
            -- Validate args and flags for subcommand
            if rawget(subcmd, 'action') then
                local validated_args, arg_errors = core.validate_args(subcmd, parsed_args)
                if #arg_errors > 0 then
                    logger.error("Subcommand argument validation failed", {errors = arg_errors})
                    for _, error in ipairs(arg_errors) do
                        io.stderr:write("Error: " .. error .. "\n")
                    end
                    return core.EXIT_USAGE
                end

                local validated_flags, validation_errors = core.validate_and_merge_flags(app, subcmd, parsed_args.flags)
                if #validation_errors > 0 then
                    logger.error("Subcommand flag validation failed", {errors = validation_errors})
                    for _, error in ipairs(validation_errors) do
                        io.stderr:write("Error: " .. error .. "\n")
                    end
                    return core.EXIT_USAGE
                end

                -- Execute subcommand action
                local context = {
                    args = validated_args,
                    flags = validated_flags,
                    command = subcmd,
                    parent = cmd,
                    config = app.loaded_config,
                    env = app.loaded_env
                }
                
                if not run_hooks(app.persistent_pre_runs, context) then return core.EXIT_ERROR end
                if not run_hooks(subcmd.pre_runs, context) then return core.EXIT_ERROR end
                local success, result = xpcall(subcmd.action, function(err)
                    if debug and type(debug.traceback) == "function" then
                        return err .. "\n" .. debug.traceback("", 2)
                    end
                    return err
                end, context)
                run_hooks(subcmd.post_runs, {success = success, result = result, config = context.config, env = context.env, command = subcmd, parent = cmd, args = context.args, flags = context.flags})
                run_hooks(app.persistent_post_runs, {success = success, result = result, config = context.config, env = context.env, command = subcmd, parent = cmd, args = context.args, flags = context.flags})
                if not success then
                    logger.error("Command action failed", {command = subcmd.name, error = tostring(result)})
                    if os.getenv("LUMOS_DEBUG") then
                        io.stderr:write("Error executing command: " .. tostring(result) .. "\n")
                    else
                        local user_msg = tostring(result):match("^([^\n]+)") or tostring(result)
                        io.stderr:write("Error executing command: " .. user_msg .. "\n")
                    end
                    return core.EXIT_ERROR
                end
                return (result == false) and core.EXIT_ERROR or core.EXIT_OK
            else
                io.stderr:write("Error: No action defined for subcommand '" .. subcmd.name .. "'\n")
                return core.EXIT_USAGE
            end
        else
            io.stderr:write("Error: Unknown subcommand '" .. parsed_args.subcommand .. "' for command '" .. cmd.name .. "'\n")
            return core.EXIT_USAGE
        end
    end
    
    -- Check for help flag
    if parsed_args.flags.help or parsed_args.flags.h then
        core.show_command_help(app, cmd)
        return core.EXIT_OK
    end
    
    -- Validate args and flags
    local validated_args, arg_errors = core.validate_args(cmd, parsed_args)
    if #arg_errors > 0 then
        logger.error("Argument validation failed", {errors = arg_errors})
        for _, error in ipairs(arg_errors) do
            io.stderr:write("Error: " .. error .. "\n")
        end
        return core.EXIT_USAGE
    end

    local validated_flags, validation_errors = core.validate_and_merge_flags(app, cmd, parsed_args.flags)
    if #validation_errors > 0 then
        logger.error("Flag validation failed", {errors = validation_errors})
        for _, error in ipairs(validation_errors) do
            io.stderr:write("Error: " .. error .. "\n")
        end
        return core.EXIT_USAGE
    end
    
    -- Execute the command action if it exists
    if rawget(cmd, 'action') then
        local context = {
            args = validated_args,
            flags = validated_flags,
            command = cmd,
            config = app.loaded_config,
            env = app.loaded_env
        }
        
        -- Execute with error handling.
        -- xpcall captures the traceback at the point of the actual error,
        -- not at the recovery site.  Guard against sandboxed Lua without debug lib.
        local function error_handler(err)
            if debug and type(debug.traceback) == "function" then
                return err .. "\n" .. debug.traceback("", 2)
            end
            return err
        end
        
        if not run_hooks(app.persistent_pre_runs, context) then return core.EXIT_ERROR end
        if not run_hooks(cmd.pre_runs, context) then return core.EXIT_ERROR end
        local success, result = xpcall(cmd.action, error_handler, context)
        run_hooks(cmd.post_runs, {success = success, result = result, config = context.config, env = context.env, command = cmd, args = context.args, flags = context.flags})
        run_hooks(app.persistent_post_runs, {success = success, result = result, config = context.config, env = context.env, command = cmd, args = context.args, flags = context.flags})
        if not success then
            logger.error("Command action failed", {command = cmd.name, error = tostring(result)})
            if os.getenv("LUMOS_DEBUG") then
                io.stderr:write("Error executing command: " .. tostring(result) .. "\n")
            else
                -- Strip traceback from user-visible message when not in debug mode
                local user_msg = tostring(result):match("^([^\n]+)") or tostring(result)
                io.stderr:write("Error executing command: " .. user_msg .. "\n")
            end
            return core.EXIT_ERROR
        end
        return (result == false) and core.EXIT_ERROR or core.EXIT_OK
    else
        -- If no action but has subcommands, show help
        if cmd.subcommands and #cmd.subcommands > 0 then
            core.show_command_help(app, cmd)
            return core.EXIT_OK
        else
            logger.warn("No action defined for command", {command = cmd.name})
            io.stderr:write("Error: No action defined for command '" .. cmd.name .. "'\n")
            return core.EXIT_USAGE
        end
    end
end

-- Display help for the entire application
function core.show_help(app)
    print(app.name .. " v" .. app.version)
    print(app.description)
    print()
    print("Usage: " .. app.name .. " [command] [flags]")
    print()
    
    if #app.commands > 0 then
        -- Group commands by category
        local categorized = {}
        local uncategorized = {}
        for _, cmd in ipairs(app.commands) do
            if cmd._category then
                categorized[cmd._category] = categorized[cmd._category] or {}
                table.insert(categorized[cmd._category], cmd)
            else
                table.insert(uncategorized, cmd)
            end
        end
        
        for category, cmds in pairs(categorized) do
            print(category .. " commands:")
            for _, cmd in ipairs(cmds) do
                print("  " .. cmd.name .. "\t" .. (cmd.description or ""))
            end
            print()
        end
        
        if #uncategorized > 0 then
            print("Available commands:")
            for _, cmd in ipairs(uncategorized) do
                print("  " .. cmd.name .. "\t" .. (cmd.description or ""))
            end
            print()
        end
    end
    
    print("Global flags:")
    print("  -h, --help    Show help information")
    print("  -v, --version Show version information")

    -- Display app-level flags defined via app:flag()
    if app.global_flags and next(app.global_flags) then
        for flag_name, flag_def in pairs(app.global_flags) do
            local flag_text = "  "
            if flag_def.short then
                flag_text = flag_text .. "-" .. flag_def.short .. ", "
            end
            flag_text = flag_text .. "--" .. flag_name
            if flag_def.description then
                flag_text = flag_text .. "\t" .. flag_def.description
            end
            print(flag_text)
        end
    end

    -- Display app-level persistent flags defined via app:persistent_flag()
    if app.persistent_flags and next(app.persistent_flags) then
        print()
        print("Persistent flags (inherited by all commands):")
        for flag_name, flag_def in pairs(app.persistent_flags) do
            local flag_text = "  "
            if flag_def.short then
                flag_text = flag_text .. "-" .. flag_def.short .. ", "
            end
            flag_text = flag_text .. "--" .. flag_name
            if flag_def.description then
                flag_text = flag_text .. "\t" .. flag_def.description
            end
            print(flag_text)
        end
    end
end

-- Display help for a specific command
function core.show_command_help(app, cmd)
    print("Usage: " .. app.name .. " " .. cmd.name .. " [flags] [arguments]")
    print()
    print(cmd.description or "No description available")
    print()
    
    if cmd.examples and type(cmd.examples) == "table" and #cmd.examples > 0 then
        print("Examples:")
        for _, example in ipairs(cmd.examples) do
            print("  " .. example)
        end
        print()
    end
    
    if cmd.flags and next(cmd.flags) then
        print("Flags:")
        for name, flag in pairs(cmd.flags) do
            local flag_text = "  "
            if flag.short then
                flag_text = flag_text .. "-" .. flag.short .. ", "
            end
            flag_text = flag_text .. "--" .. name
            if flag.description then
                flag_text = flag_text .. "\t" .. flag.description
            end
            print(flag_text)
        end
    end
end

return core
