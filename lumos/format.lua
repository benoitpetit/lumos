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

-- Detect Windows
local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

-- Check if stdout is a TTY (cross-platform). Exposed so other modules can reuse
-- this result without spawning a second subprocess.
local function is_tty()
    if is_windows() then
        return io.type(io.stdout) == "file"
    end
    local handle = io.popen("test -t 1 && echo true || echo false")
    if handle then
        local result = handle:read("*a"):gsub("%s+", "")
        handle:close()
        return result == "true"
    end
    return false
end

-- Expose is_tty so other modules (e.g. color) can reuse it without a second spawn
format.is_tty = is_tty

-- Check if terminal supports formatting (single source of truth: terminal module)
local function supports_formatting()
    local ok, term = pcall(require, "lumos.terminal")
    if ok and term and term.should_use_colors then
        return term.should_use_colors()
    end
    -- Fallback
    if os.getenv("NO_COLOR") then
        return false
    end
    if os.getenv("FORCE_COLOR") then
        return true
    end
    return is_tty()
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
function format.uppercase(text)
    return text:upper()
end

function format.lowercase(text)
    return text:lower()
end

function format.capitalize(text)
    if #text == 0 then return text end
    return text:sub(1, 1):upper() .. text:sub(2):lower()
end

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

-- Padding
function format.pad_left(text, width)
    return string.format("%" .. tostring(width) .. "s", text)
end

function format.pad_right(text, width)
    return string.format("%-" .. tostring(width) .. "s", text)
end

function format.pad_center(text, width)
    local pad = width - #text
    if pad <= 0 then return text end
    local left = math.floor(pad / 2)
    local right = pad - left
    return string.rep(" ", left) .. text .. string.rep(" ", right)
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
