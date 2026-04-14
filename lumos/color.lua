-- Lumos Color Module
-- Provides ANSI color support with automatic terminal detection

local color = {}
local format = require('lumos.format')

-- ANSI color codes
local colors = {
    reset = "\27[0m",
    black = "\27[30m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    
    -- Bright colors
    bright_black = "\27[90m",
    bright_red = "\27[91m",
    bright_green = "\27[92m",
    bright_yellow = "\27[93m",
    bright_blue = "\27[94m",
    bright_magenta = "\27[95m",
    bright_cyan = "\27[96m",
    bright_white = "\27[97m",
    
    -- Background colors
    bg_black = "\27[40m",
    bg_red = "\27[41m",
    bg_green = "\27[42m",
    bg_yellow = "\27[43m",
    bg_blue = "\27[44m",
    bg_magenta = "\27[45m",
    bg_cyan = "\27[46m",
    bg_white = "\27[47m"
}

-- Check if terminal supports colors
local function supports_color()
    -- Check for LUMOS_NO_COLOR environment variable
    if os.getenv("LUMOS_NO_COLOR") or os.getenv("NO_COLOR") then
        return false
    end
    
    -- Check for TERM environment variable
    local term = os.getenv("TERM")
    if term and (term:match("color") or term:match("xterm") or term:match("screen")) then
        return true
    end
    
    -- Reuse format module's TTY detection to avoid spawning a second subprocess
    return format.is_tty()
end

local color_enabled = supports_color()

-- Colorize text with the given color
function color.colorize(text, color_name)
    if not color_enabled or not colors[color_name] then
        return text
    end
    return colors[color_name] .. text .. colors.reset
end

-- Template-based colorization
function color.format(template)
    if not color_enabled then
        -- Strip color tags from template
        return template:gsub("{[^}]+}", "")
    end
    
    return template:gsub("{([^}]+)}", function(color_name)
        return colors[color_name] or ""
    end)
end

-- Convenience functions for common colors
function color.red(text)
    return color.colorize(text, "red")
end

function color.green(text)
    return color.colorize(text, "green")
end

function color.yellow(text)
    return color.colorize(text, "yellow")
end

function color.blue(text)
    return color.colorize(text, "blue")
end

function color.magenta(text)
    return color.colorize(text, "magenta")
end

function color.cyan(text)
    return color.colorize(text, "cyan")
end

function color.black(text)
    return color.colorize(text, "black")
end

function color.white(text)
    return color.colorize(text, "white")
end

-- Convenience functions for text formatting — respect color_enabled so that
-- color.disable() also disables bold/dim (unlike a raw format.bold delegation).
function color.bold(text)
    if not color_enabled then return text end
    return "\27[1m" .. text .. "\27[0m"
end

function color.dim(text)
    if not color_enabled then return text end
    return "\27[2m" .. text .. "\27[0m"
end

-- Enable/disable colors
function color.enable()
    color_enabled = true
end

function color.disable()
    color_enabled = false
end

function color.is_enabled()
    return color_enabled
end

-- Contextual color helpers
color.status = {
    success = function(text) return color.green(text) end,
    error = function(text) return color.red(text) end,
    warning = function(text) return color.yellow(text) end,
    info = function(text) return color.blue(text) end
}

color.log = {
    debug = function(text) return format.dim(color.colorize("[DEBUG] " .. text, "reset")) end,
    info = function(text) return color.blue("[INFO] " .. text) end,
    warn = function(text) return color.yellow("[WARN] " .. text) end,
    error = function(text) return color.red("[ERROR] " .. text) end
}

-- Progress-based coloring
function color.progress_color(percentage)
    if percentage < 33 then
        return "red"
    elseif percentage < 66 then
        return "yellow"
    else
        return "green"
    end
end

return color
