-- Lumos Color Module
-- Provides ANSI color support with automatic terminal detection

local color = {}

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
    bg_white = "\27[47m",
    
    -- Styles
    bold = "\27[1m",
    dim = "\27[2m",
    italic = "\27[3m",
    underline = "\27[4m",
    strikethrough = "\27[9m"
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
    
    -- Check if output is a TTY (basic check)
    local handle = io.popen("test -t 1 && echo true || echo false")
    if handle then
        local result = handle:read("*a"):gsub("%s+", "")
        handle:close()
        return result == "true"
    end
    
    return false
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

function color.bold(text)
    return color.colorize(text, "bold")
end

function color.dim(text)
    return color.colorize(text, "dim")
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

return color
