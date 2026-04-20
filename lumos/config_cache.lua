-- Lumos Config Cache Module
-- In-memory caching for configuration files with mtime invalidation

local config_cache = {}

local cache = {}

local function get_mtime(path)
    -- Prefer lfs (cross-platform) over stat command
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs then
        local attr = lfs.attributes(path, "modification")
        if attr then return attr end
    end
    -- Fallback for POSIX systems without lfs
    local IS_WINDOWS = package.config:sub(1, 1) == "\\"
    local cmd
    if IS_WINDOWS then
        -- No reliable built-in stat; try PowerShell as last resort
        cmd = "powershell -NoProfile -Command \"(Get-Item '" .. path:gsub("'", "''") .. "').LastWriteTimeUtc.ToUnixTimeSeconds()\" 2>nul"
    else
        -- Try BSD stat first (macOS), then GNU stat (Linux)
        cmd = "stat -f %m " .. path .. " 2>/dev/null || stat -c %Y " .. path .. " 2>/dev/null"
    end
    local handle = io.popen(cmd)
    if handle then
        local mtime = handle:read("*n")
        handle:close()
        return mtime
    end
    return nil
end

--- Loads a configuration file with caching.
---@param path string file path
---@param options table|nil { reload = boolean }
---@return table|nil data
---@return string|nil error
function config_cache.load(path, options)
    options = options or {}

    -- Force reload if requested
    if options.reload then
        cache[path] = nil
    end

    -- Check cache validity via mtime
    if cache[path] then
        local current_mtime = get_mtime(path)
        if current_mtime and current_mtime == cache[path].mtime then
            return cache[path].data
        end
        -- mtime changed or unavailable; invalidate
        cache[path] = nil
    end

    -- Load via core config module
    local config = require("lumos.config")
    local data, err = config.load_file(path)
    if not data then
        return nil, err
    end

    -- Store in cache
    cache[path] = {
        data = data,
        mtime = get_mtime(path),
        loaded_at = os.time()
    }

    return data
end

--- Invalidates one or all cached entries.
---@param path string|nil if nil, clears entire cache
function config_cache.invalidate(path)
    if path then
        cache[path] = nil
    else
        cache = {}
    end
end

return config_cache
