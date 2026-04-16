-- Lumos Parser Module
-- Command line argument parsing and command lookup

local flags = require('lumos.flags')

local parser = {}

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
function parser.suggest_command(app, input_name)
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
function parser.parse_arguments(args, app)
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
            local cmd = parser.find_command(app, parsed.command)
            if cmd and cmd.subcommands then
                local subcmd = parser.find_subcommand(cmd, arg)
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
function parser.find_command(app, command_name)
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
function parser.find_subcommand(command, subcommand_name)
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

return parser
