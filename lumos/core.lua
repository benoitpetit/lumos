-- Lumos Core Module
local flags = require('lumos.flags')

local core = {}

-- Parse command line arguments into structured data
function core.parse_arguments(args)
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
    while i <= #args do
        local arg = args[i]
        
        -- Handle flags (starting with - or --)
        if arg:match('^%-%-?') then
            local flag_result = flags.parse_single_flag(arg, args, i)
            parsed.flags[flag_result.name] = flag_result.value
            i = flag_result.next_index
        -- Handle commands (only the first non-flag argument is a command)
        elseif not parsed.command then
            parsed.command = arg
            i = i + 1
        else
            -- All remaining non-flag arguments are positional arguments
            table.insert(parsed.args, arg)
            i = i + 1
        end
    end
    
    return parsed
end

-- Find and return the matching command from the app
function core.find_command(app, command_name)
    if not command_name then
        return nil
    end
    
    for _, cmd in ipairs(app.commands) do
        if cmd.name == command_name then
            return cmd
        end
    end
    
    return nil
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
    
    -- Check for help flag
    if parsed_args.flags.help or parsed_args.flags.h then
        core.show_command_help(app, cmd)
        return true
    end
    
    -- Execute the command action if it exists
    if cmd.action then
        local context = {
            args = parsed_args.args,
            flags = parsed_args.flags,
            command = cmd
        }
        return cmd.action(context)
    else
        print("Error: No action defined for command '" .. cmd.name .. "'")
        return false
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
    
    if cmd.examples and #cmd.examples > 0 then
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
