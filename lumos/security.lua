-- Lumos Security Module
-- Provides security utilities for safe command execution and input validation

local security = {}

local IS_WINDOWS = _G.package.config:sub(1, 1) == "\\"

-- Escape shell arguments to prevent command injection
-- On Unix: wraps argument in single quotes and escapes any single quotes within.
-- On Windows: wraps in double quotes and escapes backslashes and double quotes.
function security.shell_escape(arg)
    if not arg or arg == "" then
        if IS_WINDOWS then return '""' end
        return "''"
    end

    -- Convert to string if not already
    arg = tostring(arg)

    if IS_WINDOWS then
        -- Windows CMD/PowerShell: escape backslashes and double quotes
        arg = arg:gsub("(\\*)", "%1%1"):gsub("\"", "\\\"")
        return '"' .. arg .. '"'
    end

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
    
    -- Normalise Windows-style backslashes to forward slashes before any checks
    -- so that traversal attempts like "foo\..\bar" are correctly detected.
    local sanitized = path:gsub("\\", "/")
    
    -- Remove dangerous characters
    sanitized = sanitized:gsub("[;&|$`<>]", "")
    
    -- Check for path traversal attempts
    if sanitized:match("/%.%./") or sanitized:match("^%.%./") or sanitized:match("/%.%.$") or sanitized == ".." then
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

-- Safely create directory with validation (cross-platform)
function security.safe_mkdir(path)
    local sanitized, err = security.sanitize_path(path)
    if not sanitized then
        return false, err
    end

    local lfs = require("lfs")
    local parts = {}
    -- sanitize_path always normalizes to "/", so we split on "/"
    for part in sanitized:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    local sep = IS_WINDOWS and "\\" or "/"
    local current = ""
    if not IS_WINDOWS then
        if sanitized:sub(1, 1) == "/" then
            current = "/"
        end
    else
        if sanitized:match("^%a:") then
            current = parts[1] .. sep
            table.remove(parts, 1)
        end
    end

    for _, part in ipairs(parts) do
        current = current .. part .. sep
        local attr = lfs.attributes(current)
        if not attr then
            local ok, mkdir_err = lfs.mkdir(current)
            if not ok then
                -- It may have been created concurrently
                attr = lfs.attributes(current)
                if not attr then
                    return false, mkdir_err or "Failed to create directory"
                end
            end
        elseif attr.mode ~= "directory" then
            return false, "Path exists but is not a directory: " .. current
        end
    end

    return true
end

-- Safely open file with validation
function security.safe_open(path, mode)
    local sanitized, err = security.sanitize_path(path)
    if not sanitized then
        return nil, err
    end
    
    -- Validate mode
    local valid_modes = {r = true, w = true, a = true, ["r+"] = true, ["w+"] = true, ["a+"] = true, rb = true, wb = true, ab = true, ["rb+"] = true, ["wb+"] = true, ["ab+"] = true}
    if not valid_modes[mode] then
        return nil, "Invalid file mode"
    end
    
    -- Check if trying to write to system directories
    if mode:match("^[wa]") then
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

-- Generate a safer temporary file name than os.tmpname()
-- Adds random entropy to avoid predictable names and collisions.
function security.temp_file()
    local base = os.tmpname()
    local entropy = tostring(math.random(0, 0xFFFFFFFF))
    return base .. "_" .. entropy
end

-- Generate a safer temporary directory name
function security.temp_dir()
    return security.temp_file() .. "_dir"
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
    text = text:gsub("[%z\1-\8\11\12\14-\31\127]", "")
    
    -- Remove ANSI escape sequences that aren't from our color module
    -- Covers all CSI sequences: ESC [ <params> <final-byte>
    local has_escape = text:match("\27%[")
    if has_escape then
        -- Only allow known safe ANSI codes (colors, formatting)
        text = text:gsub("\27%[[\32-\126]*[@-~]", "")
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
    if IS_WINDOWS then
        -- Try Windows elevated check via whoami /groups (looks for S-1-16-12288 = high integrity)
        local handle = io.popen("whoami /groups 2>nul")
        if handle then
            local result = handle:read("*a")
            handle:close()
            if result and result:find("S%-1%-16%-12288") then
                return true
            end
        end
        return false
    end
    -- Use `id -u` as the authoritative source — works on all POSIX systems.
    local handle = io.popen("id -u 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result:match("^0") then
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
