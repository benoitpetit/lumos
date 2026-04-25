-- lumos/runtime_manager.lua
-- Runtime launcher discovery and synchronization utilities.

local runtime_manager = {}

local fs = require("lumos.fs")
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

local KNOWN_TARGETS = {
    "linux-x86_64",
    "linux-aarch64",
    "windows-x86_64",
    "darwin-x86_64",
    "darwin-aarch64",
}

local function parse_launcher_target(filename)
    local target = filename:match("^lumos%-launcher%-(.+)$")
    if not target then
        return nil
    end
    return target:gsub("%.exe$", "")
end

local function dirname(path)
    return path:match("^(.+)[/\\][^/\\]+$")
end

local function add_unique(list, value)
    if not value or value == "" then
        return
    end
    for _, existing in ipairs(list) do
        if existing == value then
            return
        end
    end
    table.insert(list, value)
end

local function get_module_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        local path = source:sub(2)
        local dir = path:match("^(.+)[/\\]runtime_manager%.lua$")
        if dir then
            return dir
        end
    end
    return "lumos"
end

local function detect_host_target()
    if IS_WINDOWS then
        local arch = (os.getenv("PROCESSOR_ARCHITECTURE") or "x86_64"):lower()
        if arch:match("amd64") or arch:match("x86_64") then
            return "windows-x86_64"
        end
        return "windows-" .. arch
    end

    local uname_s = "linux"
    local uname_m = "x86_64"

    local handle = io.popen("uname -s 2>/dev/null")
    if handle then
        local out = handle:read("*l")
        if out and out ~= "" then
            uname_s = out:lower()
        end
        handle:close()
    end

    handle = io.popen("uname -m 2>/dev/null")
    if handle then
        local out = handle:read("*l")
        if out and out ~= "" then
            uname_m = out:lower()
        end
        handle:close()
    end

    if uname_s:find("darwin", 1, true) then
        uname_s = "darwin"
    elseif uname_s:find("linux", 1, true) then
        uname_s = "linux"
    end

    if uname_m:match("amd64") or uname_m:match("x86_64") then
        uname_m = "x86_64"
    elseif uname_m:match("arm64") or uname_m:match("aarch64") then
        uname_m = "aarch64"
    end

    return uname_s .. "-" .. uname_m
end

local function command_exists(cmd)
    local check_cmd
    if IS_WINDOWS then
        check_cmd = "where " .. security.shell_escape(cmd) .. " >NUL 2>NUL"
    else
        check_cmd = "command -v " .. security.shell_escape(cmd) .. " >/dev/null 2>&1"
    end
    local ok, why, code = os.execute(check_cmd)
    if type(ok) == "number" then
        return ok == 0
    end
    if ok == true then
        return (code or 0) == 0
    end
    return false
end

local function run_command(cmd)
    local ok, _, code = os.execute(cmd)
    if type(ok) == "number" then
        return ok == 0
    end
    if ok == true then
        return (code or 0) == 0
    end
    return false
end

local function download_file(url, output_path)
    local parent = dirname(output_path)
    if parent and not fs.path_exists(parent) then
        fs.mkdir_p(parent)
    end

    local cmd
    if IS_WINDOWS then
        cmd = "powershell -NoProfile -Command \"$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri "
            .. security.shell_escape(url)
            .. " -OutFile "
            .. security.shell_escape(output_path)
            .. "\""
    elseif command_exists("curl") then
        cmd = "curl -fL --retry 2 --connect-timeout 15 -o "
            .. security.shell_escape(output_path)
            .. " "
            .. security.shell_escape(url)
    elseif command_exists("wget") then
        cmd = "wget -q -O " .. security.shell_escape(output_path) .. " " .. security.shell_escape(url)
    else
        return false, "Neither curl nor wget is available to download runtime assets"
    end

    if not run_command(cmd) then
        return false, "Download failed for " .. url
    end

    if not fs.path_exists(output_path) then
        return false, "Downloaded file not found: " .. output_path
    end

    if not IS_WINDOWS then
        run_command("chmod +x " .. security.shell_escape(output_path))
    end

    return true
end

local function get_cache_root()
    if IS_WINDOWS then
        local local_app = os.getenv("LOCALAPPDATA")
        if local_app and local_app ~= "" then
            return local_app
        end
        local home = os.getenv("USERPROFILE") or os.getenv("HOME")
        if home and home ~= "" then
            return home .. PATH_SEP .. "AppData" .. PATH_SEP .. "Local"
        end
        return "."
    end

    local xdg_cache = os.getenv("XDG_CACHE_HOME")
    if xdg_cache and xdg_cache ~= "" then
        return xdg_cache
    end

    local home = os.getenv("HOME")
    if home and home ~= "" then
        return home .. PATH_SEP .. ".cache"
    end
    return "."
end

local function release_base_url()
    local env_url = os.getenv("LUMOS_RUNTIME_BASE_URL")
    if env_url and env_url ~= "" then
        return env_url:gsub("/$", "")
    end

    local version = "0.0.0"
    local ok, v = pcall(require, "lumos.version")
    if ok and type(v) == "string" and v ~= "" then
        version = v
    end
    return "https://github.com/benoitpetit/lumos/releases/download/v" .. version
end

function runtime_manager.detect_host_target()
    return detect_host_target()
end

function runtime_manager.get_cache_runtime_dir()
    return get_cache_root() .. PATH_SEP .. "lumos" .. PATH_SEP .. "runtime"
end

local function find_luarocks_runtime_dirs(module_dir)
    local dirs = {}
    if not module_dir or module_dir == "" or module_dir == "lumos" then
        return dirs
    end
    local lfs = get_lfs()
    if not lfs then
        return dirs
    end
    -- Heuristic: if module_dir is inside a LuaRocks tree (share/lua/X.Y/lumos),
    -- look for runtime in lib/luarocks/rocks-X.Y/lumos/<version>/runtime
    local tree_root = module_dir:match("^(.-)[/\\]share[/\\]lua[/\\]%d+%.%d+[/\\]lumos$")
    if tree_root then
        local rocks_base = tree_root .. PATH_SEP .. "lib" .. PATH_SEP .. "luarocks"
        if fs.is_dir(rocks_base) then
            for rocks_name in lfs.dir(rocks_base) do
                if rocks_name:match("^rocks%-") and fs.is_dir(rocks_base .. PATH_SEP .. rocks_name) then
                    local lumos_dir = rocks_base .. PATH_SEP .. rocks_name .. PATH_SEP .. "lumos"
                    if fs.is_dir(lumos_dir) then
                        for version_dir in lfs.dir(lumos_dir) do
                            if version_dir ~= "." and version_dir ~= ".." then
                                local candidate = lumos_dir .. PATH_SEP .. version_dir .. PATH_SEP .. "runtime"
                                if fs.is_dir(candidate) then
                                    add_unique(dirs, candidate)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return dirs
end

function runtime_manager.get_runtime_dirs()
    local dirs = {}

    local env_runtime = os.getenv("LUMOS_RUNTIME_DIR")
    if env_runtime and env_runtime ~= "" and fs.is_dir(env_runtime) then
        add_unique(dirs, fs.normalize_path(env_runtime))
    end

    local module_dir = get_module_dir()
    if module_dir and module_dir ~= "" and module_dir ~= "lumos" then
        local cursor = module_dir
        for _ = 1, 8 do
            local candidate = cursor .. PATH_SEP .. "runtime"
            if fs.is_dir(candidate) then
                add_unique(dirs, fs.normalize_path(candidate))
            end
            local parent = dirname(cursor)
            if not parent or parent == cursor then
                break
            end
            cursor = parent
        end

        for _, candidate in ipairs(find_luarocks_runtime_dirs(module_dir)) do
            add_unique(dirs, fs.normalize_path(candidate))
        end
    end

    local cache_runtime = runtime_manager.get_cache_runtime_dir()
    if fs.is_dir(cache_runtime) then
        add_unique(dirs, fs.normalize_path(cache_runtime))
    end

    return dirs
end

function runtime_manager.is_known_target(target)
    for _, known in ipairs(KNOWN_TARGETS) do
        if known == target then
            return true
        end
    end
    return false
end

function runtime_manager.known_targets()
    local list = {}
    for _, target in ipairs(KNOWN_TARGETS) do
        table.insert(list, target)
    end
    return list
end

function runtime_manager.list_targets()
    local targets = {}
    local lfs_mod = get_lfs()
    if not lfs_mod then
        return {}
    end
    for _, runtime_dir in ipairs(runtime_manager.get_runtime_dirs()) do
        local ok, iter, state = pcall(lfs_mod.dir, runtime_dir)
        if ok and iter then
            for file in iter, state do
                if file:match("^lumos%-launcher%-") then
                    local target = parse_launcher_target(file)
                    if target then
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

function runtime_manager.find_launcher(target)
    for _, runtime_dir in ipairs(runtime_manager.get_runtime_dirs()) do
        local launcher_path = runtime_dir .. PATH_SEP .. "lumos-launcher-" .. target
        if fs.path_exists(launcher_path) then
            return fs.normalize_path(launcher_path)
        end
        if fs.path_exists(launcher_path .. ".exe") then
            return fs.normalize_path(launcher_path .. ".exe")
        end
    end
    return nil
end

function runtime_manager.sync(options)
    options = options or {}

    local targets = {}
    if options.target and options.target ~= "" then
        table.insert(targets, options.target)
    else
        for _, target in ipairs(KNOWN_TARGETS) do
            table.insert(targets, target)
        end
    end

    local cache_runtime = runtime_manager.get_cache_runtime_dir()
    if not fs.path_exists(cache_runtime) then
        fs.mkdir_p(cache_runtime)
    end

    local base_url = options.base_url or release_base_url()
    local results = {}
    local all_ok = true

    for _, target in ipairs(targets) do
        if not runtime_manager.is_known_target(target) then
            results[target] = {
                status = "failed",
                error = "Unknown target: " .. target,
            }
            all_ok = false
        else
            local existing = runtime_manager.find_launcher(target)
            if existing and not options.force then
                results[target] = {
                    status = "already_available",
                    path = existing,
                }
            else
                local candidates = { "lumos-launcher-" .. target }
                if target:match("^windows") then
                    table.insert(candidates, "lumos-launcher-" .. target .. ".exe")
                end

                local downloaded = nil
                local last_err = nil
                for _, asset_name in ipairs(candidates) do
                    local url = base_url .. "/" .. asset_name
                    local out = cache_runtime .. PATH_SEP .. asset_name
                    local ok, err = download_file(url, out)
                    if ok then
                        downloaded = out
                        break
                    end
                    last_err = err
                end

                if downloaded then
                    results[target] = {
                        status = "downloaded",
                        path = downloaded,
                    }
                else
                    results[target] = {
                        status = "failed",
                        error = last_err or "Download failed",
                    }
                    all_ok = false
                end
            end
        end
    end

    if all_ok then
        return true, nil, results
    end

    local failed = {}
    for target, result in pairs(results) do
        if result.status == "failed" then
            table.insert(failed, target)
        end
    end
    table.sort(failed)
    return false, "Failed to sync runtime launcher(s): " .. table.concat(failed, ", "), results
end

function runtime_manager.ensure_target(target, options)
    if not target or target == "" then
        return nil, "Target is required"
    end
    local launcher = runtime_manager.find_launcher(target)
    if launcher then
        return launcher
    end

    local ok, err = runtime_manager.sync({
        target = target,
        force = options and options.force or false,
    })
    if not ok then
        return nil, err
    end

    launcher = runtime_manager.find_launcher(target)
    if launcher then
        return launcher
    end
    return nil, "Launcher not found after sync for target: " .. target
end

function runtime_manager.release_base_url()
    return release_base_url()
end

return runtime_manager
