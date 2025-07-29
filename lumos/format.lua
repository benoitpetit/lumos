-- Lumos Format Module  
-- Provides text formatting capabilities (bold, italic, etc.) independent of colors

local format = {}

-- ANSI format codes
local formats = {
    reset = "\27[0m",
    bold = "\27[1m",
    dim = "\27[2m", 
    italic = "\27[3m",
    underline = "\27[4m",
    strikethrough = "\27[9m",
    reverse = "\27[7m",
    hidden = "\27[8m"
}

-- Check if terminal supports formatting
local function supports_formatting()
    -- Check for NO_COLOR environment variables
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

local formatting_enabled = supports_formatting()

-- Apply formatting to text
function format.apply(text, format_name)
    if not formatting_enabled or not formats[format_name] then
        return text
    end
    return formats[format_name] .. text .. formats.reset
end

-- Template-based formatting
function format.format(template)
    if not formatting_enabled then
        -- Strip format tags from template
        return template:gsub("{[^}]+}", "")
    end
    
    return template:gsub("{([^}]+)}", function(format_name)
        return formats[format_name] or ""
    end)
end

-- Convenience functions for common styles
function format.bold(text)
    return format.apply(text, "bold")
end

function format.italic(text)
    return format.apply(text, "italic")
end

function format.dim(text)
    return format.apply(text, "dim")
end

function format.underline(text)
    return format.apply(text, "underline")
end

function format.strikethrough(text)
    return format.apply(text, "strikethrough")
end

function format.reverse(text)
    return format.apply(text, "reverse")
end

function format.hidden(text)
    return format.apply(text, "hidden")
end

-- Text truncation with ellipsis
function format.truncate(text, max_width, ellipsis)
    ellipsis = ellipsis or "..."
    if #text <= max_width then
        return text
    end
    return text:sub(1, max_width - #ellipsis) .. ellipsis
end

-- Word wrapping
function format.wrap(text, width)
    local lines = {}
    local line = ""
    
    for word in text:gmatch("%S+") do
        if #line + #word + 1 <= width then
            if #line > 0 then
                line = line .. " " .. word
            else
                line = word
            end
        else
            if #line > 0 then
                table.insert(lines, line)
            end
            line = word
        end
    end
    
    if #line > 0 then
        table.insert(lines, line)
    end
    
    return lines
end

-- Case transformations
function format.title_case(text)
    return text:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function format.camel_case(text)
    return text:gsub("_%a", string.upper):gsub("_", "")
end

function format.snake_case(text)
    return text:gsub("([a-z])([A-Z])", "%1_%2"):lower()
end

function format.kebab_case(text)
    return text:gsub("([a-z])([A-Z])", "%1-%2"):lower():gsub("_", "-")
end

-- Enable/disable formatting
function format.enable()
    formatting_enabled = true
end

function format.disable()
    formatting_enabled = false
end

function format.is_enabled()
    return formatting_enabled
end

-- Combine multiple formats
function format.combine(text, ...)
    local formats_to_apply = {...}
    local result = text
    
    for _, fmt in ipairs(formats_to_apply) do
        if type(fmt) == "string" and formats[fmt] then
            result = format.apply(result, fmt)
        elseif type(fmt) == "function" then
            result = fmt(result)
        end
    end
    
    return result
end

return format
