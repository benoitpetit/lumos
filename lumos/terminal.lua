-- Lumos Terminal Module
-- Terminal capabilities and control helpers

local terminal = {}

local platform
local function get_platform()
    if not platform then
        platform = require("lumos.platform")
    end
    return platform
end

--- Determines if colors should be used
function terminal.should_use_colors()
    local p = get_platform()
    if p.is_piped() then
        return false
    end
    if os.getenv("NO_COLOR") then
        return false
    end
    if os.getenv("FORCE_COLOR") then
        return true
    end
    return p.supports_colors()
end

--- Determines if animations should be used
function terminal.should_use_animations()
    local p = get_platform()
    return p.is_interactive() and not p.is_piped()
end

--- Determines if interactive prompts are possible
function terminal.supports_interactive_prompts()
    return get_platform().is_interactive()
end

--- Returns terminal width in columns
function terminal.width()
    local w = 80
    local p = get_platform()
    if p.is_windows() then
        local handle = io.popen("mode con 2>nul")
        if handle then
            local out = handle:read("*a") or ""
            handle:close()
            local cols = out:match("Columns:%s*(%d+)")
            if cols then
                w = tonumber(cols)
            end
        end
    else
        local handle = io.popen("stty size 2>/dev/null")
        if handle then
            local out = handle:read("*a") or ""
            handle:close()
            local _, cols = out:match("(%d+)%s+(%d+)")
            if cols then
                w = tonumber(cols)
            end
        end
    end
    if w == 80 then
        local env = os.getenv("COLUMNS")
        if env then
            w = tonumber(env) or 80
        end
    end
    return w
end

--- Returns terminal height in rows
function terminal.height()
    local h = 24
    local p = get_platform()
    if p.is_windows() then
        local handle = io.popen("mode con 2>nul")
        if handle then
            local out = handle:read("*a") or ""
            handle:close()
            local rows = out:match("Lines:%s*(%d+)")
            if rows then
                h = tonumber(rows)
            end
        end
    else
        local handle = io.popen("stty size 2>/dev/null")
        if handle then
            local out = handle:read("*a") or ""
            handle:close()
            local rows = out:match("(%d+)%s+%d+")
            if rows then
                h = tonumber(rows)
            end
        end
    end
    if h == 24 then
        local env = os.getenv("LINES")
        if env then
            h = tonumber(env) or 24
        end
    end
    return h
end

--- Clears the screen
function terminal.clear()
    if get_platform().is_windows() then
        os.execute("cls")
    else
        io.write("\27[2J\27[H")
    end
end

--- Moves cursor to row, col (1-based)
function terminal.move_cursor(row, col)
    io.write(string.format("\27[%d;%dH", row, col))
end

--- Saves cursor position
function terminal.save_cursor()
    io.write("\27[s")
end

--- Restores cursor position
function terminal.restore_cursor()
    io.write("\27[u")
end

--- Clears from cursor to end of line
function terminal.clear_to_end()
    io.write("\27[K")
end

--- Clears from cursor to end of screen
function terminal.clear_to_bottom()
    io.write("\27[J")
end

--- Hides the cursor
function terminal.hide_cursor()
    io.write("\27[?25l")
end

--- Shows the cursor
function terminal.show_cursor()
    io.write("\27[?25h")
end

return terminal
