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
    -- Environment overrides take precedence over TTY detection
    if os.getenv("FORCE_COLOR") then
        return true
    end
    if os.getenv("NO_COLOR") then
        return false
    end
    local p = get_platform()
    if p.is_piped() then
        return false
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

-- Internal: run a shell command and return its stdout
local function shell_output(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if handle then
        local out = handle:read("*a") or ""
        handle:close()
        return out
    end
    return ""
end

-- Internal: extract a number from text using a pattern
local function extract_num(text, pattern)
    local m = text:match(pattern)
    if m then
        return tonumber(m)
    end
    return nil
end

--- Returns terminal width in columns
function terminal.width()
    local w = nil
    local p = get_platform()
    if p.is_windows() then
        w = extract_num(shell_output("mode con"), "Columns:%s*(%d+)")
    else
        local out = shell_output("stty size")
        local _, cols = out:match("(%d+)%s+(%d+)")
        w = tonumber(cols)
    end
    if not w then
        w = tonumber(os.getenv("COLUMNS")) or 80
    end
    return w
end

--- Returns terminal height in rows
function terminal.height()
    local h = nil
    local p = get_platform()
    if p.is_windows() then
        h = extract_num(shell_output("mode con"), "Lines:%s*(%d+)")
    else
        local out = shell_output("stty size")
        local rows = out:match("(%d+)%s+%d+")
        h = tonumber(rows)
    end
    if not h then
        h = tonumber(os.getenv("LINES")) or 24
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

-- Internal: write an ANSI sequence only when output is not piped
local function ansi_write(seq)
    if not get_platform().is_piped() then
        io.write(seq)
    end
end

--- Moves cursor to row, col (1-based)
function terminal.move_cursor(row, col)
    ansi_write(string.format("\27[%d;%dH", row, col))
end

--- Saves cursor position
function terminal.save_cursor()
    ansi_write("\27[s")
end

--- Restores cursor position
function terminal.restore_cursor()
    ansi_write("\27[u")
end

--- Clears from cursor to end of line
function terminal.clear_to_end()
    ansi_write("\27[K")
end

--- Clears from cursor to end of screen
function terminal.clear_to_bottom()
    ansi_write("\27[J")
end

--- Hides the cursor
function terminal.hide_cursor()
    ansi_write("\27[?25l")
end

--- Shows the cursor
function terminal.show_cursor()
    ansi_write("\27[?25h")
end

return terminal
