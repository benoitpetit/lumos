-- lumos/package.lua
-- Package a Lumos CLI application into a standalone executable using a precompiled stub.
-- The stub embeds a Lua interpreter; we append the amalgamated Lua payload and a size footer.

local package = {}

local bundle = require("lumos.bundle")
local fs = require("lumos.fs")
local security = require("lumos.security")

local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"
local lfs = require("lfs")

local read_file = fs.read_file
local write_file = fs.write_file
local path_exists = fs.path_exists
local mkdir_p = fs.mkdir_p

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
        local path = source:sub(2)
        -- Cross-platform pattern for package.lua
        local dir = path:match("^(.+)[/\\]package%.lua$")
        if dir then
            return dir
        end
    end
    return "lumos"
end

--- List available stub targets
---@return table targets
function package.list_targets()
    local roots = {}
    -- Development checkout
    local dev_root = get_module_dir():match("^(.+)[/\\]lumos$")
    if dev_root then
        table.insert(roots, dev_root)
    end
    -- Installed rock tree (module dir parent might contain stubs if copy_directories worked)
    local mod_dir = get_module_dir()
    if mod_dir and mod_dir ~= "lumos" then
        local rock_root = mod_dir .. PATH_SEP .. ".." .. PATH_SEP .. ".."
        table.insert(roots, rock_root)
    end
    local targets = {}
    for _, root in ipairs(roots) do
        local stubs_dir = root .. PATH_SEP .. "stubs"
        if path_exists(stubs_dir) then
            for file in lfs.dir(stubs_dir) do
                if file:match("^lumos%-stub%-") then
                    local target = file:match("^lumos%-stub%-(.+)$")
                    if target and not targets[target] then
                        targets[target] = true
                    end
                end
            end
        end
    end
    local list = {}
    for target in pairs(targets) do
        table.insert(list, target)
    end
    table.sort(list)
    return list
end

--- Find the stub binary path for a given target
---@param target string
---@return string|nil
function package.find_stub(target)
    local roots = {}
    local dev_root = get_module_dir():match("^(.+)[/\\]lumos$")
    if dev_root then
        table.insert(roots, dev_root)
    end
    local mod_dir = get_module_dir()
    if mod_dir and mod_dir ~= "lumos" then
        local rock_root = mod_dir .. PATH_SEP .. ".." .. PATH_SEP .. ".."
        table.insert(roots, rock_root)
    end
    for _, root in ipairs(roots) do
        local stub_path = root .. PATH_SEP .. "stubs" .. PATH_SEP .. "lumos-stub-" .. target
        if path_exists(stub_path) then
            return stub_path
        end
    end
    return nil
end

--- Detect the host platform target
---@return string
local function detect_host_target()
    if IS_WINDOWS then
        local arch = os.getenv("PROCESSOR_ARCHITECTURE") or "x86_64"
        if arch:match("AMD64") or arch:match("x86_64") then
            return "windows-x86_64"
        end
        return "windows-" .. arch:lower()
    end
    local uname_s = "Linux"
    local uname_m = "x86_64"
    local handle = io.popen("uname -s 2>/dev/null")
    if handle then
        local out = handle:read("*l")
        if out then uname_s = out end
        handle:close()
    end
    handle = io.popen("uname -m 2>/dev/null")
    if handle then
        local out = handle:read("*l")
        if out then uname_m = out end
        handle:close()
    end
    local sys = uname_s:lower()
    if sys:find("darwin") then
        sys = "darwin"
    elseif sys:find("linux") then
        sys = "linux"
    end
    local arch = uname_m:lower()
    if arch:match("amd64") or arch:match("x86_64") then
        arch = "x86_64"
    elseif arch:match("aarch64") or arch:match("arm64") then
        arch = "aarch64"
    end
    return sys .. "-" .. arch
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

    local target = options.target or detect_host_target()
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

    -- 100 MiB limit enforced by stub.c
    local MAX_PAYLOAD = 100 * 1024 * 1024
    if #lua_code > MAX_PAYLOAD then
        return false, "Payload exceeds maximum size of 100 MiB (" .. tostring(#lua_code) .. " bytes)"
    end

    local payload = stub_data .. lua_code .. u64_le(#lua_code)

    local output_file = options.output
    if not output_file then
        local basename = entry_file:match("([^" .. PATH_SEP:gsub("\\", "\\\\") .. "]+)%.lua$") or "package"
        local out_dir = options.output_dir or "dist"
        mkdir_p(out_dir)
        output_file = out_dir .. PATH_SEP .. basename
    else
        local parent_dir = output_file:match("^(.+)[/\\][^/\\]+$")
        if parent_dir then
            mkdir_p(parent_dir)
        end
    end

    -- Append .exe on Windows targets if missing
    if target:match("^windows") and not output_file:match("%.exe$") then
        output_file = output_file .. ".exe"
    end

    -- Sanitize path before writing
    local sanitized, sanitize_err = security.sanitize_path(output_file)
    if not sanitized then
        return false, "Invalid output path: " .. tostring(sanitize_err)
    end
    output_file = sanitized

    if not write_file(output_file, payload) then
        return false, "Cannot write output file: " .. output_file
    end

    -- Make executable on Unix-like systems
    if not IS_WINDOWS then
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
