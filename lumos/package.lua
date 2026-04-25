-- lumos/package.lua
-- Package a Lumos CLI application into a standalone executable using a precompiled launcher.
-- The launcher embeds a Lua interpreter; we append the amalgamated Lua payload and a size footer.

local package = {}

local bundle = require("lumos.bundle")
local fs = require("lumos.fs")
local security = require("lumos.security")
local runtime_manager = require("lumos.runtime_manager")

local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

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

--- List available launcher targets
---@return table targets
function package.list_targets()
    return runtime_manager.list_targets()
end

--- Find the launcher binary path for a given target
---@param target string
---@return string|nil
function package.find_launcher(target)
    return runtime_manager.find_launcher(target)
end

--- Detect the host platform target
---@return string
function package.detect_host_target()
    return runtime_manager.detect_host_target()
end

function package.sync_runtime(options)
    return runtime_manager.sync(options)
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

    local project_native_modules = {}
    do
        local ok_nb, native_build = pcall(require, "lumos.native_build")
        if ok_nb and native_build and type(native_build.detect_project_native_modules) == "function" then
            project_native_modules = native_build.detect_project_native_modules(options)
        end
    end
    if #project_native_modules > 0 then
        local modules_list = table.concat(project_native_modules, ", ")
        return false,
            "Cannot package: native C modules detected (" .. modules_list .. "). "
            .. "'lumos package' does not support native C modules because it uses a precompiled "
            .. "Lua launcher without a C compiler step. "
            .. "Use 'lumos build' instead (e.g. lumos build " .. entry_file .. " -t " .. (options.target or package.detect_host_target()) .. ")."
    end

    local target = options.target or package.detect_host_target()
    local launcher_path, launcher_err = runtime_manager.ensure_target(target, {
        force = options.sync_runtime_force,
    })
    if not launcher_path then
        local available = table.concat(package.list_targets(), ", ")
        if available == "" then
            available = "none"
        end
        local details = launcher_err and (". " .. launcher_err) or ""
        return false, "Launcher not found for target: " .. target .. ". Available: " .. available .. details
    end

    -- Amalgamate Lua code
    local ok, err, lua_code, modules_count = bundle.amalgamate(options)
    if not ok then
        return false, err
    end

    -- Remove shebang if present (the launcher interpreter loads via luaL_loadbuffer)
    lua_code = lua_code:gsub("^#![^\n]*\n?", "")

    local launcher_data = read_file(launcher_path)
    if not launcher_data then
        return false, "Cannot read launcher binary: " .. launcher_path
    end

    -- Payload limit: defaults to 100 MiB, overridable via LUMOS_MAX_PAYLOAD_MB env var
    local MAX_PAYLOAD_MB = 100
    local env_max = os.getenv("LUMOS_MAX_PAYLOAD_MB")
    if env_max then
        local n = tonumber(env_max)
        if n and n > 0 then
            MAX_PAYLOAD_MB = math.floor(n)
        end
        if MAX_PAYLOAD_MB <= 0 then
            MAX_PAYLOAD_MB = 1
        end
    end
    local MAX_PAYLOAD = MAX_PAYLOAD_MB * 1024 * 1024
    if #lua_code > MAX_PAYLOAD then
        return false, "Payload exceeds maximum size of " .. MAX_PAYLOAD_MB .. " MiB (" .. tostring(#lua_code) .. " bytes). Set LUMOS_MAX_PAYLOAD_MB to increase the limit."
    end

    local payload = launcher_data .. lua_code .. u64_le(#lua_code)

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
        launcher_size = #launcher_data,
    }
end

return package
