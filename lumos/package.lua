-- lumos/package.lua
-- Package a Lumos CLI application into a standalone executable using a precompiled stub.
-- The stub embeds a Lua interpreter; we append the amalgamated Lua payload and a size footer.

local package = {}

local bundle = require("lumos.bundle")
local security = require("lumos.security")

local lfs
local function get_lfs()
    if not lfs then
        lfs = require("lfs")
    end
    return lfs
end

--- Read file contents
---@param path string
---@return string|nil
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

--- Write file contents
---@param path string
---@param content string
---@return boolean
local function write_file(path, content)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

--- Check if path exists
---@param path string
---@return boolean
local function path_exists(path)
    local attr = get_lfs().attributes(path)
    return attr ~= nil
end

--- Create directory recursively
---@param path string
---@return boolean
local function mkdir_p(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    local current = ""
    if path:sub(1, 1) == "/" then
        current = "/"
    end
    for _, part in ipairs(parts) do
        current = current .. part .. "/"
        if not path_exists(current) then
            local ok, err = get_lfs().mkdir(current)
            if not ok and not path_exists(current) then
                return false
            end
        end
    end
    return true
end

--- Encode a 64-bit unsigned integer as little-endian bytes
---@param n number
---@return string
local function u64_le(n)
    local bytes = {}
    for i = 0, 7 do
        table.insert(bytes, string.char(math.floor(n / (2 ^ (8 * i))) % 256))
    end
    return table.concat(bytes)
end

--- Determine the directory where this module is installed
---@return string
local function get_module_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        local dir = source:sub(2):match("^(.+)/package%.lua$")
        if dir then
            return dir
        end
    end
    return "lumos"
end

--- Get the project root directory (parent of lumos module dir)
---@return string
local function get_project_root()
    local mod_dir = get_module_dir()
    if mod_dir:match("/lumos$") then
        return mod_dir:sub(1, -7)
    end
    return "."
end

--- List available stub targets
---@return table targets
function package.list_targets()
    local root = get_project_root()
    local stubs_dir = root .. "/stubs"
    local targets = {}
    if path_exists(stubs_dir) then
        for file in get_lfs().dir(stubs_dir) do
            if file:match("^lumos%-stub%-") then
                local target = file:match("^lumos%-stub%-(.+)$")
                if target then
                    table.insert(targets, target)
                end
            end
        end
    end
    table.sort(targets)
    return targets
end

--- Find the stub binary path for a given target
---@param target string
---@return string|nil
function package.find_stub(target)
    local root = get_project_root()
    local stub_path = root .. "/stubs/lumos-stub-" .. target
    if path_exists(stub_path) then
        return stub_path
    end
    return nil
end

--- Package a Lua CLI application into a standalone executable
---@param options table
---   entry, output, project_dir, include_lumos, strip_comments, target
---@return boolean success
---@return string|nil error
---@return table|nil info
function package.create(options)
    options = options or {}

    local entry_file = options.entry
    if not entry_file then
        return false, "Entry file is required"
    end

    if not path_exists(entry_file) then
        return false, "Entry file not found: " .. entry_file
    end

    local target = options.target or "linux-x86_64"
    local stub_path = package.find_stub(target)
    if not stub_path then
        local available = table.concat(package.list_targets(), ", ")
        if available == "" then
            available = "none"
        end
        return false, "Stub not found for target: " .. target .. ". Available: " .. available
    end

    -- Amalgamate Lua code
    local ok, err, lua_code, modules_count = bundle.amalgamate(options)
    if not ok then
        return false, err
    end

    -- Remove shebang if present (the stub interpreter loads via luaL_loadbuffer)
    lua_code = lua_code:gsub("^#![^\n]*\n?", "")

    local stub_data = read_file(stub_path)
    if not stub_data then
        return false, "Cannot read stub binary: " .. stub_path
    end

    local payload = stub_data .. lua_code .. u64_le(#lua_code)

    local output_file = options.output
    if not output_file then
        local basename = entry_file:match("([^/]+)%.lua$") or "package"
        local out_dir = options.output_dir or "dist"
        mkdir_p(out_dir)
        output_file = out_dir .. "/" .. basename
    else
        local parent_dir = output_file:match("^(.+)/[^/]+$")
        if parent_dir then
            mkdir_p(parent_dir)
        end
    end

    if not write_file(output_file, payload) then
        return false, "Cannot write output file: " .. output_file
    end

    -- Make executable on Unix-like systems
    if _G.package.config:sub(1, 1) ~= "\\" then
        os.execute("chmod +x " .. security.shell_escape(output_file))
    end

    return true, nil, {
        output = output_file,
        target = target,
        modules_count = modules_count,
        size = #payload,
        stub_size = #stub_data,
    }
end

return package
