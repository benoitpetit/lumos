-- Lumos FS Module
-- Cross-platform file system utilities

local fs = {}

local security = require("lumos.security")

local lfs
local function get_lfs()
    if lfs == nil then
        local ok, mod = pcall(require, "lfs")
        lfs = ok and mod or false
    end
    return lfs
end

local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

--- Read file contents
---@param path string
---@return string|nil content
---@return string|nil error
function fs.read_file(path)
    local f, err = security.safe_open(path, "rb")
    if not f then
        return nil, err or ("Cannot read file: " .. path)
    end
    local content = f:read("*a")
    f:close()
    return content
end

--- Write file contents
---@param path string
---@param content string
---@return boolean success
---@return string|nil error
function fs.write_file(path, content)
    local f, err = security.safe_open(path, "wb")
    if not f then
        return false, err or ("Cannot write file: " .. path)
    end
    f:write(content)
    f:close()
    return true
end

--- Check if path exists
---@param path string
---@return boolean
function fs.path_exists(path)
    local lfs_mod = get_lfs()
    if lfs_mod then
        return lfs_mod.attributes(path) ~= nil
    end
    -- Fallback without lfs
    if not IS_WINDOWS then
        local ok = os.execute("test -e " .. security.shell_escape(path) .. " 2>/dev/null")
        return ok == 0 or ok == true
    else
        local ok = os.execute("if exist " .. security.shell_escape(path) .. " (exit 0) else (exit 1)")
        return ok == 0 or ok == true
    end
end

--- Check if path is a regular file
---@param path string
---@return boolean
function fs.is_file(path)
    local lfs_mod = get_lfs()
    if lfs_mod then
        return lfs_mod.attributes(path, "mode") == "file"
    end
    -- Fallback: if we can open it for reading, it's a file
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

--- Check if path is a directory
---@param path string
---@return boolean
function fs.is_dir(path)
    local lfs_mod = get_lfs()
    if lfs_mod then
        return lfs_mod.attributes(path, "mode") == "directory"
    end
    if not IS_WINDOWS then
        local ok = os.execute("test -d " .. security.shell_escape(path) .. " 2>/dev/null")
        return ok == 0 or ok == true
    else
        local ok = os.execute("cd /d " .. security.shell_escape(path) .. " >nul 2>nul")
        return ok == 0 or ok == true
    end
end

--- Normalize a path by resolving . and .. components
---@param path string
---@return string
function fs.normalize_path(path)
    if not path or path == "" then
        return "."
    end
    local is_absolute = path:sub(1, 1) == "/" or (IS_WINDOWS and path:match("^[a-zA-Z]:") ~= nil)
    local parts = {}
    for part in path:gmatch("[^/\\]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end
    local normalized = table.concat(parts, PATH_SEP)
    if is_absolute then
        normalized = PATH_SEP .. normalized
    end
    return normalized ~= "" and normalized or "."
end

--- Create directory recursively
---@param path string
---@return boolean success
function fs.mkdir_p(path)
    local lfs_mod = get_lfs()
    if lfs_mod then
        local parts = {}
        local sep_escaped = PATH_SEP:gsub("\\", "\\\\")
        for part in path:gmatch("[^" .. sep_escaped .. "]+") do
            table.insert(parts, part)
        end

        local current = ""
        if not IS_WINDOWS then
            if path:sub(1, 1) == PATH_SEP then
                current = PATH_SEP
            end
        else
            if path:match("^%a:[/\\]") then
                current = parts[1] .. PATH_SEP
                table.remove(parts, 1)
            end
        end

        for _, part in ipairs(parts) do
            current = current .. part .. PATH_SEP
            if not fs.path_exists(current) then
                local ok, _ = lfs_mod.mkdir(current)
                if not ok and not fs.path_exists(current) then
                    return false
                end
            end
        end
        return true
    end

    -- Fallback without lfs
    if not IS_WINDOWS then
        local ok = os.execute("mkdir -p " .. security.shell_escape(path) .. " 2>/dev/null")
        return ok == 0 or ok == true
    else
        -- Windows: mkdir does not have -p; build path step by step
        local parts = {}
        for part in path:gmatch("[^" .. PATH_SEP:gsub("\\", "\\\\") .. "]+") do
            table.insert(parts, part)
        end
        local current = ""
        if path:match("^%a:[/\\]") then
            current = parts[1] .. PATH_SEP
            table.remove(parts, 1)
        end
        for _, part in ipairs(parts) do
            current = current .. part .. PATH_SEP
            if not fs.path_exists(current) then
                local ok = os.execute("mkdir " .. security.shell_escape(current) .. " 2>nul")
                if not ok and not fs.path_exists(current) then
                    return false
                end
            end
        end
        return true
    end
end

--- Remove a directory recursively
---@param path string
---@return boolean success
function fs.rmdir_p(path)
    local lfs_mod = get_lfs()
    if lfs_mod then
        local function rm(dir)
            for file in lfs_mod.dir(dir) do
                if file ~= "." and file ~= ".." then
                    local full = dir .. PATH_SEP .. file
                    local attr = lfs_mod.attributes(full)
                    if attr and attr.mode == "directory" then
                        rm(full)
                    else
                        os.remove(full)
                    end
                end
            end
            lfs_mod.rmdir(dir)
        end
        local attr = lfs_mod.attributes(path)
        if attr and attr.mode == "directory" then
            rm(path)
            return true
        end
        return false
    end

    -- Fallback without lfs
    if not IS_WINDOWS then
        local ok = os.execute("rm -rf " .. security.shell_escape(path) .. " 2>/dev/null")
        return ok == 0 or ok == true
    else
        local ok = os.execute("rmdir /s /q " .. security.shell_escape(path) .. " 2>nul")
        return ok == 0 or ok == true
    end
end

return fs
