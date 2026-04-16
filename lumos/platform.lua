-- Lumos Platform Module
-- Cross-platform detection and helpers

local platform = {
    _cache = {}
}

--- Detects the current operating system
function platform.detect()
    if platform._cache.detected then
        return platform._cache.detected
    end

    local name

    -- Windows detection via package.config
    if package.config:sub(1, 1) == "\\" then
        name = "windows"
    else
        -- Unix detection via uname
        local handle = io.popen("uname -s 2>/dev/null")
        if handle then
            local uname = handle:read("*l")
            handle:close()
            if uname then
                uname = uname:lower()
                if uname:match("darwin") then
                    name = "macos"
                elseif uname:match("linux") then
                    name = "linux"
                elseif uname:match("freebsd") then
                    name = "freebsd"
                elseif uname:match("openbsd") then
                    name = "openbsd"
                end
            end
        end
    end

    platform._cache.detected = name or "unknown"
    return platform._cache.detected
end

--- Detects the current architecture
function platform.arch()
    if platform._cache.arch then
        return platform._cache.arch
    end

    local arch

    if platform.is_windows() then
        arch = os.getenv("PROCESSOR_ARCHITECTURE")
    else
        local handle = io.popen("uname -m 2>/dev/null")
        if handle then
            arch = handle:read("*l")
            handle:close()
        end
    end

    if arch then
        arch = arch:lower()
        if arch:match("x86_64") or arch:match("amd64") then
            arch = "amd64"
        elseif arch:match("i%d86") then
            arch = "386"
        elseif arch:match("aarch64") or arch:match("arm64") then
            arch = "arm64"
        elseif arch:match("armv7") then
            arch = "armv7"
        end
    end

    platform._cache.arch = arch or "unknown"
    return platform._cache.arch
end

-- Platform helpers
function platform.name() return platform.detect() end
function platform.is_windows() return platform.detect() == "windows" end
function platform.is_macos() return platform.detect() == "macos" end
function platform.is_linux() return platform.detect() == "linux" end
function platform.is_unix() return not platform.is_windows() end

--- Checks if the terminal supports colors
function platform.supports_colors()
    if platform._cache.supports_colors ~= nil then
        return platform._cache.supports_colors
    end

    if os.getenv("NO_COLOR") then
        platform._cache.supports_colors = false
        return false
    end

    if os.getenv("FORCE_COLOR") then
        platform._cache.supports_colors = true
        return true
    end

    local supports = false
    if platform.is_windows() then
        -- Windows 10+ supports ANSI via conhost/Windows Terminal
        local handle = io.popen("ver 2>nul")
        if handle then
            local ver = handle:read("*a") or ""
            handle:close()
            local major = ver:match("(%d+)%.%d+")
            supports = tonumber(major) and tonumber(major) >= 10
        end
    else
        local term = os.getenv("TERM")
        supports = term and term ~= "dumb"
    end

    platform._cache.supports_colors = supports
    return supports
end

--- Checks if stdin/stdout are interactive (not piped)
function platform.is_interactive()
    if platform._cache.is_interactive ~= nil then
        return platform._cache.is_interactive
    end

    local interactive = false
    if platform.is_windows() then
        -- Best-effort: check if stdin is a char device via powershell or env hints
        local handle = io.popen('powershell -Command "[Console]::IsInputRedirected" 2>nul')
        if handle then
            local out = handle:read("*l")
            handle:close()
            if out and out:lower() == "false" then
                interactive = true
            end
        end
    else
        local stdin_h = io.popen("[ -t 0 ] && echo yes || echo no 2>/dev/null")
        local stdout_h = io.popen("[ -t 1 ] && echo yes || echo no 2>/dev/null")
        if stdin_h and stdout_h then
            local stdin_tty = stdin_h:read("*l") == "yes"
            local stdout_tty = stdout_h:read("*l") == "yes"
            stdin_h:close()
            stdout_h:close()
            interactive = stdin_tty and stdout_tty
        end
    end

    platform._cache.is_interactive = interactive
    return interactive
end

--- Checks if stdout is piped (not a tty)
function platform.is_piped()
    if platform._cache.is_piped ~= nil then
        return platform._cache.is_piped
    end

    local piped = false
    if platform.is_windows() then
        local handle = io.popen('powershell -Command "[Console]::IsOutputRedirected" 2>nul')
        if handle then
            local out = handle:read("*l")
            handle:close()
            if out and out:lower() == "true" then
                piped = true
            end
        end
    else
        local handle = io.popen("[ -t 1 ] && echo no || echo yes 2>/dev/null")
        if handle then
            piped = handle:read("*l") == "yes"
            handle:close()
        end
    end

    platform._cache.is_piped = piped
    return piped
end

--- Returns the path separator for the current platform
function platform.path_separator()
    return platform.is_windows() and "\\" or "/"
end

--- Returns the PATH list separator
function platform.path_list_separator()
    return platform.is_windows() and ";" or ":"
end

--- Converts a relative path to absolute (best-effort)
function platform.absolute_path(path)
    if not path or path == "" then
        return path
    end
    if platform.is_windows() then
        if path:match("^%a:[/\\]") then
            return path
        end
    else
        if path:sub(1, 1) == "/" then
            return path
        end
    end
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs then
        return lfs.currentdir() .. platform.path_separator() .. path
    end
    return path
end

--- Normalizes a path (removes . and ..)
function platform.normalize_path(path)
    if not path then return "" end
    local sep = platform.path_separator()
    path = path:gsub("[/\\]", sep)
    local parts = {}
    for part in path:gmatch("[^" .. sep:gsub("\\", "\\\\") .. "]+") do
        if part == ".." and #parts > 0 then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end
    -- Preserve leading slash on Unix
    local prefix = ""
    if not platform.is_windows() and path:sub(1, 1) == sep then
        prefix = sep
    end
    -- Preserve Windows drive letter
    if platform.is_windows() then
        local drive = path:match("^(%a:)")
        if drive then
            prefix = drive .. sep
        end
    end
    return prefix .. table.concat(parts, sep)
end

return platform
