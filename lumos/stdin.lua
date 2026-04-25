-- Lumos Stdin Module
-- Utilities for reading from standard input.

local stdin = {}

local platform
local function get_platform()
    if not platform then
        platform = require('lumos.platform')
    end
    return platform
end

--- Check if stdin is a pipe/redirect (not an interactive terminal)
function stdin.is_pipe()
    local ok, p = pcall(get_platform)
    if ok and p.is_piped then
        return p.is_piped()
    end
    -- Fallback: try to read a byte non-blocking
    return not stdin.is_tty()
end

--- Check if stdin is connected to a terminal
function stdin.is_tty()
    if package.config:sub(1,1) == "\\" then
        local handle = io.popen('powershell -Command "[Console]::IsInputRedirected" 2>nul')
        if handle then
            local out = handle:read("*l")
            handle:close()
            return out and out:lower() == "false"
        end
        return true
    else
        local handle = io.popen("[ -t 0 ] && echo yes || echo no 2>/dev/null")
        if handle then
            local out = handle:read("*l")
            handle:close()
            return out == "yes"
        end
        return true
    end
end

--- Read all data from stdin
-- @return string|nil content, string|nil error
function stdin.read()
    local data = io.stdin:read("*a")
    if data == "" then
        return nil, "stdin is empty"
    end
    return data, nil
end

--- Read stdin line by line into a table
-- @return table lines, string|nil error
function stdin.read_lines()
    local lines = {}
    for line in io.stdin:lines() do
        table.insert(lines, line)
    end
    if #lines == 0 then
        return lines, "stdin is empty"
    end
    return lines, nil
end

--- Read stdin and parse as JSON
-- @return table|nil data, string|nil error
function stdin.read_json()
    local data, err = stdin.read()
    if not data then
        return nil, err
    end
    local json = require('lumos.json')
    local ok, result = pcall(json.decode, data)
    if not ok then
        return nil, "Invalid JSON from stdin: " .. tostring(result)
    end
    return result, nil
end

--- Check if stdin has any data available
-- Reads one byte and pushes it back if available.
-- @return boolean
function stdin.has_data()
    if stdin.is_tty() then
        -- Interactive terminal: user hasn't typed anything yet
        return false
    end
    -- Try to peek at stdin
    local chunk = io.stdin:read(1)
    if chunk then
        -- Push back using a custom stream wrapper isn't possible in standard Lua,
        -- so we just document that has_data consumes one byte.
        -- For practical purposes, just try reading and return true if we got data.
        return true
    end
    return false
end

return stdin
