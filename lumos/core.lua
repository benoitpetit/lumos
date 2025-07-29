-- Lumos Core Module
local flags = require('lumos.flags')

local core = {}

-- Configuration file loader
function core.load_config(file_path)
    -- Placeholder logic for loading a config file (YAML, JSON, etc.)
    -- This function would parse the file and add config variables
    -- to the application's settings or flags.
    print("Loading configuration from " .. file_path)
end

-- Parse command line arguments into structured data with subcommand support
function core.parse_arguments(args)
    local parsed = {
        command = nil,
        subcommand = nil,
        subcommands = {},
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
        merged_flags[flag_name] = result
        return true
    end
    
    -- Start with app-level persistent flags
    if app.persistent_flags then
        for flag_name, flag_def in pairs(app.persistent_flags) do
            local value = parsed_flags[flag_name] or parsed_flags[flag_def.short]
            if value ~= nil then
                validate_single_flag(flag_name, value, flag_def)
            end
        end
    end
    
    -- Add command-level persistent flags
    if cmd and cmd.persistent_flags then
        for flag_name, flag_def in pairs(cmd.persistent_flags) do
            local value = parsed_flags[flag_name] or parsed_flags[flag_def.short]
            if value ~= nil then
                validate_single_flag(flag_name, value, flag_def)
            end
        end
    end
    
    -- Add command-specific flags
    if cmd and cmd.flags then
        for flag_name, flag_def in pairs(cmd.flags) do
            local value = parsed_flags[flag_name] or parsed_flags[flag_def.short]
            if value ~= nil then
                validate_single_flag(flag_name, value, flag_def)
            end
        end
    end
    
    -- Copy remaining parsed flags that weren't validated
    for flag_name, flag_value in pairs(parsed_flags) do
        if merged_flags[flag_name] == nil then
            merged_flags[flag_name] = flag_value
        end
    end
    
    return merged_flags, errors
end

-- Execute the appropriate command with parsed arguments
function core.execute_command(app, parsed_args)
    local cmd = core.find_command(app, parsed_args.command)
    
    if not cmd then
        if parsed_args.command then
            print("Error: Unknown command '" .. parsed_args.command .. "'")
            core.show_help(app)
            return false
        else
            core.show_help(app)
            return true
        end
    end
    
    -- Handle subcommands if present
    if parsed_args.subcommand and cmd.subcommands then
        local subcmd = core.find_subcommand(cmd, parsed_args.subcommand)
        if subcmd then
            -- Check for help flag on subcommand
            if parsed_args.flags.help or parsed_args.flags.h then
                core.show_command_help(app, subcmd)
                return true
            end
            
            -- Execute subcommand action
            if subcmd.action then
                local context = {
                    args = parsed_args.args,
                    flags = parsed_args.flags,
                    command = subcmd,
                    parent = cmd
                }
                return subcmd.action(context)
            else
                print("Error: No action defined for subcommand '" .. subcmd.name .. "'")
                return false
            end
        else
            print("Error: Unknown subcommand '" .. parsed_args.subcommand .. "' for command '" .. cmd.name .. "'")
            return false
        end
    end
    
    -- Check for help flag
    if parsed_args.flags.help or parsed_args.flags.h then
        core.show_command_help(app, cmd)
        return true
    end
    
    -- Validate and merge flags
    local validated_flags, validation_errors = core.validate_and_merge_flags(app, cmd, parsed_args.flags)
    if #validation_errors > 0 then
        for _, error in ipairs(validation_errors) do
            print("Error: " .. error)
        end
        return false
    end
    
    -- Execute the command action if it exists
    if cmd.action then
        local context = {
            args = parsed_args.args,
            flags = validated_flags,
            command = cmd
        }
        return cmd.action(context)
    else
        -- If no action but has subcommands, show help
        if cmd.subcommands and #cmd.subcommands > 0 then
            core.show_command_help(app, cmd)
            return true
        else
            print("Error: No action defined for command '" .. cmd.name .. "'")
            return false
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
        print("Available commands:")
        for _, cmd in ipairs(app.commands) do
            print("  " .. cmd.name .. "\t" .. (cmd.description or ""))
        end
        print()
    end
    
    print("Global flags:")
    print("  -h, --help    Show help information")
    print("  -v, --version Show version information")
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
