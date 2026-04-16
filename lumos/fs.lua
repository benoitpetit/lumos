-- Lumos FS Module
-- Cross-platform file system utilities

local fs = {}

local lfs
local function get_lfs()
    if not lfs then
        lfs = require("lfs")
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
    local f, err = io.open(path, "rb")
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
    local f, err = io.open(path, "wb")
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
    local attr = get_lfs().attributes(path)
    return attr ~= nil
end

--- Check if path is a regular file
---@param path string
---@return boolean
function fs.is_file(path)
    return get_lfs().attributes(path, "mode") == "file"
end

--- Check if path is a directory
---@param path string
---@return boolean
function fs.is_dir(path)
    return get_lfs().attributes(path, "mode") == "directory"
end

--- Create directory recursively
---@param path string
---@return boolean success
function fs.mkdir_p(path)
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
        -- Windows drive letter handling (e.g., C:\)
        if path:match("^%a:") then
            current = parts[1] .. PATH_SEP
            table.remove(parts, 1)
        end
    end

    for _, part in ipairs(parts) do
        current = current .. part .. PATH_SEP
        if not fs.path_exists(current) then
            local ok, _ = get_lfs().mkdir(current)
            if not ok and not fs.path_exists(current) then
                return false
            end
        end
    end
    return true
end

--- Remove a directory recursively
---@param path string
---@return boolean success
function fs.rmdir_p(path)
    local lfs = get_lfs()
    local function rm(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local full = dir .. PATH_SEP .. file
                local attr = lfs.attributes(full)
                if attr and attr.mode == "directory" then
                    rm(full)
                else
                    os.remove(full)
                end
            end
        end
        lfs.rmdir(dir)
    end
    local attr = lfs.attributes(path)
    if attr and attr.mode == "directory" then
        rm(path)
        return true
    end
    return false
end

return fs
