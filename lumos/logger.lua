-- Lumos Logger Module
-- Provides structured logging with levels and context

local logger = {}

-- Log levels
logger.LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
    TRACE = 5
}

-- Level names for display
local LEVEL_NAMES = {
    [1] = "ERROR",
    [2] = "WARN",
    [3] = "INFO",
    [4] = "DEBUG",
    [5] = "TRACE"
}

-- Current log level (default to INFO)
local current_level = logger.LEVELS.INFO

-- Log output destination (default to stderr for logs)
local log_output = io.stderr

-- Whether to include timestamps
local include_timestamp = true

-- Whether to include context
local include_context = true

-- Color support for log levels
local color_enabled = false
local colors = {
    ERROR = "\27[31m",   -- Red
    WARN = "\27[33m",    -- Yellow
    INFO = "\27[36m",    -- Cyan
    DEBUG = "\27[90m",   -- Bright black (gray)
    TRACE = "\27[37m",   -- White
    RESET = "\27[0m"
}

-- Check if colors should be enabled
local function init_colors()
    if os.getenv("LUMOS_NO_COLOR") or os.getenv("NO_COLOR") then
        return false
    end
    
    local term = os.getenv("TERM")
    if term and (term:match("color") or term:match("xterm")) then
        return true
    end
    
    return false
end

color_enabled = init_colors()

-- Format timestamp
local function format_timestamp()
    if not include_timestamp then
        return ""
    end
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Format context (key-value pairs)
local function format_context(context)
    if not context or not include_context then
        return ""
    end
    
    local parts = {}
    for key, value in pairs(context) do
        if type(value) == "table" then
            value = require('lumos.json').encode(value)
        else
            value = tostring(value)
        end
        table.insert(parts, key .. "=" .. value)
    end
    
    if #parts > 0 then
        return " [" .. table.concat(parts, " ") .. "]"
    end
    
    return ""
end

-- Core logging function
local function do_log(level, level_name, message, context)
    if level > current_level then
        return  -- Don't log if below current level
    end
    
    local timestamp = format_timestamp()
    local ctx = format_context(context)
    
    local color_start = ""
    local color_end = ""
    if color_enabled then
        color_start = colors[level_name] or ""
        color_end = colors.RESET
    end
    
    local log_line = string.format("%s%s [%s] %s%s%s\n",
        timestamp and (timestamp .. " ") or "",
        color_start,
        level_name,
        message,
        ctx,
        color_end
    )
    
    log_output:write(log_line)
    log_output:flush()
end

-- Public logging functions
function logger.error(message, context)
    do_log(logger.LEVELS.ERROR, "ERROR", message, context)
end

function logger.warn(message, context)
    do_log(logger.LEVELS.WARN, "WARN", message, context)
end

function logger.info(message, context)
    do_log(logger.LEVELS.INFO, "INFO", message, context)
end

function logger.debug(message, context)
    do_log(logger.LEVELS.DEBUG, "DEBUG", message, context)
end

function logger.trace(message, context)
    do_log(logger.LEVELS.TRACE, "TRACE", message, context)
end

-- Set log level
function logger.set_level(level)
    if type(level) == "string" then
        level = logger.LEVELS[level:upper()]
    end
    
    if level and level >= logger.LEVELS.ERROR and level <= logger.LEVELS.TRACE then
        current_level = level
        logger.debug("Log level set", {level = LEVEL_NAMES[level]})
    else
        logger.warn("Invalid log level", {provided = level})
    end
end

-- Get current log level
function logger.get_level()
    return current_level, LEVEL_NAMES[current_level]
end

-- Set log output destination
function logger.set_output(output)
    if type(output) == "string" then
        -- Open file
        local file, err = io.open(output, "a")
        if not file then
            logger.error("Failed to open log file", {file = output, error = err})
            return false
        end
        log_output = file
    elseif type(output) == "userdata" then
        -- File handle
        log_output = output
    else
        logger.warn("Invalid log output type")
        return false
    end
    
    return true
end

-- Enable/disable timestamps
function logger.set_timestamp(enabled)
    include_timestamp = enabled
end

-- Enable/disable context
function logger.set_context(enabled)
    include_context = enabled
end

-- Enable/disable colors
function logger.set_colors(enabled)
    color_enabled = enabled
end

-- Configure from environment
function logger.configure_from_env(prefix)
    prefix = prefix or "LUMOS"
    
    -- Log level
    local level_env = os.getenv(prefix .. "_LOG_LEVEL")
    if level_env then
        logger.set_level(level_env)
    end
    
    -- Log file
    local file_env = os.getenv(prefix .. "_LOG_FILE")
    if file_env then
        logger.set_output(file_env)
    end
    
    -- Timestamps
    local ts_env = os.getenv(prefix .. "_LOG_TIMESTAMP")
    if ts_env then
        logger.set_timestamp(ts_env ~= "false" and ts_env ~= "0")
    end
    
    -- Colors
    if os.getenv(prefix .. "_NO_COLOR") or os.getenv("NO_COLOR") then
        logger.set_colors(false)
    end
end

-- Log with automatic level detection based on keywords
function logger.auto(message, context)
    local msg_lower = message:lower()
    
    if msg_lower:match("error") or msg_lower:match("fail") or msg_lower:match("fatal") then
        logger.error(message, context)
    elseif msg_lower:match("warn") or msg_lower:match("warning") then
        logger.warn(message, context)
    elseif msg_lower:match("debug") or msg_lower:match("trace") then
        logger.debug(message, context)
    else
        logger.info(message, context)
    end
end

-- Create a child logger with fixed context
function logger.child(fixed_context)
    local child = {}
    
    for method_name, method_func in pairs(logger) do
        if type(method_func) == "function" and method_name:match("^[a-z]+$") then
            child[method_name] = function(message, context)
                local merged_context = {}
                if fixed_context then
                    for k, v in pairs(fixed_context) do
                        merged_context[k] = v
                    end
                end
                if context then
                    for k, v in pairs(context) do
                        merged_context[k] = v
                    end
                end
                return method_func(message, merged_context)
            end
        end
    end
    
    return child
end

-- Initialize from environment on load
logger.configure_from_env()

return logger
