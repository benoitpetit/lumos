-- Lumos Security Module
-- Provides security utilities for safe command execution and input validation

local security = {}

-- Escape shell arguments to prevent command injection
-- Wraps argument in single quotes and escapes any single quotes within
function security.shell_escape(arg)
    if not arg or arg == "" then
        return "''"
    end
    
    -- Convert to string if not already
    arg = tostring(arg)
    
    -- Escape single quotes by ending quote, adding escaped quote, starting quote again
    arg = arg:gsub("'", "'\\''")
    
    -- Wrap in single quotes
    return "'" .. arg .. "'"
end

-- Validate and sanitize file paths to prevent path traversal attacks
function security.sanitize_path(path)
    if not path or path == "" then
        return nil, "Empty path"
    end
    
    -- Remove dangerous characters
    local sanitized = path:gsub("[;&|$`<>]", "")
    
    -- Check for path traversal attempts
    if sanitized:match("%.%.") then
        return nil, "Path traversal detected"
    end
    
    -- Remove multiple slashes
    sanitized = sanitized:gsub("/+", "/")
    
    -- Remove trailing slash unless it's root
    if sanitized ~= "/" then
        sanitized = sanitized:gsub("/$", "")
    end
    
    return sanitized
end

-- Safely create directory with validation
function security.safe_mkdir(path)
    local sanitized, err = security.sanitize_path(path)
    if not sanitized then
        return false, err
    end
    
    -- Use shell_escape for additional protection
    local escaped_path = security.shell_escape(sanitized)
    local cmd = "mkdir -p " .. escaped_path
    
    local success = os.execute(cmd)
    return success == 0 or success == true, success and nil or "Failed to create directory"
end

-- Safely open file with validation
function security.safe_open(path, mode)
    local sanitized, err = security.sanitize_path(path)
    if not sanitized then
        return nil, err
    end
    
    -- Validate mode
    local valid_modes = {r = true, w = true, a = true, ["r+"] = true, ["w+"] = true, ["a+"] = true}
    if not valid_modes[mode] then
        return nil, "Invalid file mode"
    end
    
    -- Check if trying to write to system directories
    if (mode == "w" or mode == "a" or mode == "w+" or mode == "a+") then
        if sanitized:match("^/etc/") or sanitized:match("^/sys/") or sanitized:match("^/proc/") then
            return nil, "Cannot write to system directory"
        end
    end
    
    local file, open_err = io.open(sanitized, mode)
    if not file then
        return nil, open_err
    end
    
    return file
end

-- Validate email format
function security.validate_email(email)
    if not email or type(email) ~= "string" then
        return false, "Invalid email format"
    end
    
    local pattern = "^[A-Za-z0-9%.%+_%%-]+@[A-Za-z0-9%-]+%.[A-Za-z]+$"
    if not email:match(pattern) then
        return false, "Invalid email format"
    end
    
    -- Additional checks
    if #email > 254 then
        return false, "Email too long"
    end
    
    local local_part = email:match("^([^@]+)@")
    if local_part and #local_part > 64 then
        return false, "Email local part too long"
    end
    
    return true
end

-- Validate URL format
function security.validate_url(url)
    if not url or type(url) ~= "string" then
        return false, "Invalid URL format"
    end
    
    local pattern = "^https?://[%w%.%-]+[%w%.%-/]*$"
    if not url:match(pattern) then
        return false, "Invalid URL format (only http/https allowed)"
    end
    
    -- Check for suspicious patterns
    if url:match("@") then
        return false, "URLs with @ are not allowed"
    end
    
    return true
end

-- Sanitize user input for display (prevent terminal escape sequence injection)
function security.sanitize_output(text)
    if not text then
        return ""
    end
    
    text = tostring(text)
    
    -- Remove control characters except newline (\n = 0x0A) and tab (\t = 0x09)
    -- Range: 0x00-0x08, 0x0B-0x0C, 0x0E-0x1F, 0x7F
    local clean = {}
    for i = 1, #text do
        local byte = text:byte(i)
        -- Keep printable chars (>= 32 and < 127) or newline (10) or tab (9)
        if byte == 9 or byte == 10 or (byte >= 32 and byte < 127) then
            table.insert(clean, string.char(byte))
        end
    end
    text = table.concat(clean)
    
    -- Remove ANSI escape sequences that aren't from our color module
    -- This is a basic filter, real ANSI codes from lumos.color will be allowed
    local has_escape = text:match("\27%[")
    if has_escape then
        -- Only allow known safe ANSI codes (colors, formatting)
        text = text:gsub("\27%[[^mK]", "")
    end
    
    return text
end

-- Validate integer with range
function security.validate_integer(value, min, max)
    local num = tonumber(value)
    if not num or math.floor(num) ~= num then
        return false, "Must be an integer"
    end
    
    if min and num < min then
        return false, "Must be >= " .. min
    end
    
    if max and num > max then
        return false, "Must be <= " .. max
    end
    
    return true, num
end

-- Sanitize command name (only allow alphanumeric, dash, underscore)
function security.sanitize_command_name(name)
    if not name or type(name) ~= "string" then
        return nil, "Invalid command name"
    end
    
    if not name:match("^[a-zA-Z0-9_%-]+$") then
        return nil, "Command name can only contain letters, numbers, dash and underscore"
    end
    
    if #name > 64 then
        return nil, "Command name too long"
    end
    
    return name
end

-- Check if running with elevated privileges (security warning)
function security.is_elevated()
    local uid = os.getenv("UID") or ""
    local euid = os.getenv("EUID") or ""
    
    -- Check if root
    if uid == "0" or euid == "0" then
        return true
    end
    
    -- Try to detect via id command
    local handle = io.popen("id -u 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result:match("^0") then
            return true
        end
    end
    
    return false
end

-- Rate limiting for repeated operations (simple implementation)
local rate_limits = {}

function security.rate_limit(key, max_calls, window_seconds)
    window_seconds = window_seconds or 60
    max_calls = max_calls or 10
    
    local now = os.time()
    
    if not rate_limits[key] then
        rate_limits[key] = {calls = {}, window = window_seconds, max = max_calls}
    end
    
    local limit = rate_limits[key]
    
    -- Remove old calls outside the window
    local new_calls = {}
    for _, call_time in ipairs(limit.calls) do
        if now - call_time < limit.window then
            table.insert(new_calls, call_time)
        end
    end
    limit.calls = new_calls
    
    -- Check if limit exceeded
    if #limit.calls >= limit.max then
        return false, "Rate limit exceeded"
    end
    
    -- Add current call
    table.insert(limit.calls, now)
    return true
end

return security
