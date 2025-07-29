-- Lumos Flags Module
local flags = {}

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
