-- lumos/native_build/toolchain.lua
-- C compiler toolchain detection for native binary builds.

local fs = require("lumos.fs")
local security = require("lumos.security")
local runtime_manager = require("lumos.runtime_manager")

local toolchain = {}

local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

-- ---------------------------------------------------------------------------
-- Internal utilities
-- ---------------------------------------------------------------------------

local BUILD_CACHE_DIR = ".lumos" .. PATH_SEP .. "cache"

local function ensure_build_cache_dir()
    if not fs.path_exists(BUILD_CACHE_DIR) then
        fs.mkdir_p(BUILD_CACHE_DIR)
    end
end

local counter = 0
local function random_tmp_name(ext)
    ensure_build_cache_dir()
    counter = counter + 1
    local suffix = tostring(math.random(100000, 999999)) .. "_" .. tostring(counter) .. "_" .. tostring(os.time())
    return BUILD_CACHE_DIR .. PATH_SEP .. "tmp_" .. suffix .. (ext or "")
end

local function shell_exec(cmd)
    local tmpout = random_tmp_name(".out")
    local tmperr = random_tmp_name(".err")
    local full_cmd = cmd .. " >" .. security.shell_escape(tmpout) .. " 2>" .. security.shell_escape(tmperr)
    local ok, _, code = os.execute(full_cmd)
    local fh = io.open(tmpout, "r")
    local stdout = fh and fh:read("*a") or ""
    if fh then fh:close() end
    fh = io.open(tmperr, "r")
    local stderr = fh and fh:read("*a") or ""
    if fh then fh:close() end
    os.remove(tmpout)
    os.remove(tmperr)
    return stdout, stderr, (ok == true or ok == 0) and 0 or (code or 1)
end

local function find_command(name)
    if IS_WINDOWS then
        local out, _, code = shell_exec("where " .. security.shell_escape(name) .. " 2>nul")
        if code == 0 then
            local path = out:gsub("%s+$", "")
            if path ~= "" then return path end
        end
    else
        local out, _, code = shell_exec("which " .. security.shell_escape(name) .. " 2>/dev/null")
        if code == 0 then
            local path = out:gsub("%s+$", "")
            if path ~= "" then return path end
        end
        -- Fallback: search in known osxcross directories
        local OSXCROSS_DIRS = {
            "/usr/local/osxcross",
            "/opt/osxcross",
            os.getenv("HOME") and (os.getenv("HOME") .. "/osxcross") or nil,
            "/tmp/osxcross",
        }
        for _, dir in ipairs(OSXCROSS_DIRS) do
            if dir then
                local candidate = dir .. "/target/bin/" .. name
                if fs.path_exists(candidate) then
                    return candidate
                end
            end
        end
    end
    return nil
end

local function find_runtime_root_for_target(target)
    for _, runtime_dir in ipairs(runtime_manager.get_runtime_dirs()) do
        local lib_dir = runtime_dir .. PATH_SEP .. "lib" .. PATH_SEP .. target
        if fs.path_exists(lib_dir) then
            return runtime_dir
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Target parsing and detection
-- ---------------------------------------------------------------------------

local SUPPORTED_BUILD_TARGETS = {
    ["linux-x86_64"] = true,
    ["linux-aarch64"] = true,
    ["windows-x86_64"] = true,
    ["darwin-x86_64"] = true,
    ["darwin-aarch64"] = true,
}

local COMPILER_CANDIDATES = {
    "cc", "gcc", "clang", "musl-gcc", "aarch64-linux-gnu-gcc",
    "x86_64-w64-mingw32-gcc", "o64-clang", "oa64-clang"
}

local LUAC_CANDIDATES = {
    "luac", "luac5.4", "luac5.3", "luac5.2", "luac5.1"
}

local function normalize_arch(arch)
    if not arch then return nil end
    local normalized = arch:lower()
    if normalized == "amd64" then normalized = "x86_64" end
    if normalized == "arm64" then normalized = "aarch64" end
    return normalized
end

local function normalize_os(os_name)
    if not os_name then return nil end
    local normalized = os_name:lower()
    if normalized == "macos" then normalized = "darwin" end
    return normalized
end

local function parse_target(target)
    if type(target) ~= "string" or target == "" then
        return nil, "Target must be a non-empty string"
    end
    local raw = target:lower()
    local os_name, arch = raw:match("^([%w_]+)%-([%w_]+)$")
    if not os_name or not arch then
        return nil, "Invalid target format: " .. tostring(target) .. ". Expected <os>-<arch> (example: windows-x86_64)."
    end
    os_name = normalize_os(os_name)
    arch = normalize_arch(arch)
    return { os = os_name, arch = arch, normalized = os_name .. "-" .. arch }, nil
end

function toolchain.detect_host_target()
    if IS_WINDOWS then
        local arch = os.getenv("PROCESSOR_ARCHITECTURE") or "x86_64"
        arch = normalize_arch(arch)
        return "windows-" .. (arch or "x86_64")
    end
    local uname_s = "linux"
    local uname_m = "x86_64"
    local handle = io.popen("uname -s 2>/dev/null")
    if handle then
        local out = handle:read("*l")
        if out and out ~= "" then uname_s = out:lower() end
        handle:close()
    end
    handle = io.popen("uname -m 2>/dev/null")
    if handle then
        local out = handle:read("*l")
        if out and out ~= "" then uname_m = out:lower() end
        handle:close()
    end
    if uname_s:find("darwin", 1, true) then uname_s = "darwin"
    elseif uname_s:find("linux", 1, true) then uname_s = "linux" end
    return uname_s .. "-" .. (normalize_arch(uname_m) or "x86_64")
end

function toolchain.resolve_target(target)
    local selected = target or toolchain.detect_host_target()
    local parsed, parse_err = parse_target(selected)
    if not parsed then return nil, parse_err end
    if not SUPPORTED_BUILD_TARGETS[parsed.normalized] then
        local supported = {}
        for t in pairs(SUPPORTED_BUILD_TARGETS) do table.insert(supported, t) end
        table.sort(supported)
        return nil, "Unsupported build target: " .. parsed.normalized .. ". Supported targets: " .. table.concat(supported, ", ")
    end
    local host_parsed = parse_target(toolchain.detect_host_target())
    if host_parsed then
        if parsed.os == "darwin" and host_parsed.os ~= "darwin" then
            local has_darwin_cc = false
            if parsed.arch == "x86_64" then
                has_darwin_cc = find_command("o64-clang") ~= nil
            elseif parsed.arch == "aarch64" then
                has_darwin_cc = find_command("oa64-clang") ~= nil
            end
            if not has_darwin_cc then
                return nil,
                    "Cross-compiling native binaries to macOS is not supported on "
                    .. host_parsed.os
                    .. ". Install osxcross or build on macOS. Alternative: use 'lumos package -t "
                    .. parsed.normalized
                    .. "'."
            end
        end
        if parsed.os == "linux" and host_parsed.os ~= "linux" then
            return nil,
                "Cross-compiling native binaries to Linux is not supported on "
                .. host_parsed.os
                .. ". Use a Linux build host."
        end
    end
    return parsed.normalized, nil
end

-- ---------------------------------------------------------------------------
-- Compiler and luac detection
-- ---------------------------------------------------------------------------

function toolchain.detect_compiler(preferred)
    if preferred then
        return find_command(preferred)
    end
    for _, name in ipairs(COMPILER_CANDIDATES) do
        local path = find_command(name)
        if path then return path end
    end
    return nil
end

local function get_lua_version()
    local v = _VERSION:match("%d+%.%d+") or "5.1"
    return v
end

local function is_luajit()
    return type(_G.jit) == "table" or (_VERSION and _VERSION:match("LuaJIT"))
end

function toolchain.detect_luac(preferred, target_version)
    local target_ver = target_version or get_lua_version()
    local candidates = {}
    if preferred then
        table.insert(candidates, preferred)
    else
        for _, name in ipairs(LUAC_CANDIDATES) do
            table.insert(candidates, name)
        end
    end
    for _, name in ipairs(candidates) do
        local path = find_command(name)
        if path then
            local vout, _, vcode = shell_exec(security.shell_escape(path) .. " -v 2>&1")
            if vcode == 0 then
                local luac_ver = vout:match("(%d+%.%d+)")
                if luac_ver == target_ver then
                    return path
                end
            end
        end
    end
    return nil, "No luac compiler found matching Lua version " .. target_ver
end

function toolchain.bytecode_compile(lua_code, preferred_luac, target_version)
    local luac, lerr = toolchain.detect_luac(preferred_luac, target_version)
    if not luac then
        return nil, lerr or "No luac compiler found. Cannot compile to bytecode."
    end
    local tmp_in = random_tmp_name(".lua")
    local tmp_out = random_tmp_name(".luac")
    local f = io.open(tmp_in, "wb")
    if not f then
        return nil, "Cannot write temporary Lua file"
    end
    f:write(lua_code)
    f:close()
    local cmd = security.shell_escape(luac) .. " -o " .. security.shell_escape(tmp_out) .. " " .. security.shell_escape(tmp_in)
    local _, stderr, code = shell_exec(cmd)
    os.remove(tmp_in)
    if code ~= 0 then
        os.remove(tmp_out)
        return nil, "luac failed: " .. stderr
    end
    local fh = io.open(tmp_out, "rb")
    if not fh then
        os.remove(tmp_out)
        return nil, "Cannot read compiled bytecode"
    end
    local bytes = fh:read("*a")
    fh:close()
    os.remove(tmp_out)
    return bytes, nil
end

-- ---------------------------------------------------------------------------
-- pkg-config and toolchain assembly
-- ---------------------------------------------------------------------------

local function pkg_config(name)
    local cflags, _, ccode = shell_exec("pkg-config --cflags " .. security.shell_escape(name) .. " 2>/dev/null")
    local libs, _, lcode = shell_exec("pkg-config --libs " .. security.shell_escape(name) .. " 2>/dev/null")
    if (ccode == 0 or ccode == true) and (lcode == 0 or lcode == true) then
        return cflags:gsub("%s+$", ""), libs:gsub("%s+$", "")
    end
    return nil, nil
end

function toolchain.detect_toolchain(options)
    options = options or {}
    local target, target_err = toolchain.resolve_target(options.target)
    if not target then return nil, target_err end
    local target_info = parse_target(target)
    local target_os = target_info and target_info.os or nil
    local preferred_compiler = options.cc

    if not preferred_compiler then
        if target_os == "windows" then
            preferred_compiler = "x86_64-w64-mingw32-gcc"
        elseif target_os == "darwin" then
            if target_info.arch == "aarch64" then
                preferred_compiler = "oa64-clang"
            else
                preferred_compiler = "o64-clang"
            end
        elseif target_os == "linux" then
            if target_info.arch == "aarch64" then
                preferred_compiler = "aarch64-linux-gnu-gcc"
            end
        end
    end

    local compiler = toolchain.detect_compiler(preferred_compiler)
    if not compiler then
        return nil, "No C compiler found. Please install gcc, clang, or musl-gcc."
    end

    local is_mingw = compiler:find("mingw") ~= nil
    if target_os == "windows" and not is_mingw then
        return nil, "Target " .. target .. " requires a MinGW compiler (x86_64-w64-mingw32-gcc)."
    end
    if target_os ~= "windows" and is_mingw then
        return nil, "Compiler " .. compiler .. " targets Windows, but requested target is " .. target .. "."
    end

    local lua_ver = get_lua_version()
    local major = lua_ver:match("^(%d+)")
    local minor = lua_ver:match("%.(%d+)$")
    local short_ver = major .. minor

    local cflags = ""
    local ldflags = ""
    local liblua_path = nil
    local lua_include_dir = nil

    -- Try pkg-config variants
    local pkg_names = {}
    if is_luajit() then
        pkg_names = { "luajit" }
    else
        pkg_names = {
            "lua-" .. lua_ver,
            "lua" .. lua_ver,
            "lua"
        }
    end
    for _, name in ipairs(pkg_names) do
        local pc_cflags, pc_libs = pkg_config(name)
        if pc_cflags then
            for dir in pc_cflags:gmatch("%-I%s*(%S+)") do
                lua_include_dir = dir
                break
            end
            cflags = pc_cflags
            ldflags = pc_libs
            break
        end
    end

    -- Resolve liblua.a to an absolute path
    if not liblua_path then
        local search_paths = {}
        for libdir in (ldflags or ""):gmatch("%-L%s*(%S+)") do
            table.insert(search_paths, libdir)
        end
        local common = {
            "/usr/lib/x86_64-linux-gnu",
            "/usr/lib/aarch64-linux-gnu",
            "/usr/lib64",
            "/usr/lib",
            "/usr/local/lib",
            "/opt/homebrew/lib",
        }
        if compiler:find("mingw") then
            table.insert(common, "/usr/x86_64-w64-mingw32/lib")
            table.insert(common, "/usr/i686-w64-mingw32/lib")
        end
        for _, p in ipairs(common) do table.insert(search_paths, p) end

        local env_lib = os.getenv("LUA_LIB") or os.getenv("LUA_LIBDIR")
        if env_lib then table.insert(search_paths, 1, env_lib) end

        local runtime_dir = find_runtime_root_for_target(target)
        if runtime_dir and target then
            local cross_lib_dir = runtime_dir .. PATH_SEP .. "lib" .. PATH_SEP .. target
            if fs.path_exists(cross_lib_dir) then
                table.insert(search_paths, 1, cross_lib_dir)
            end
        end

        local candidates = {}
        if is_luajit() then
            candidates = {
                "libluajit-5.1.a",
                "libluajit.a",
                "liblua5.1.a",
            }
        else
            candidates = {
                "liblua" .. lua_ver .. ".a",
                "liblua" .. major .. ".a",
                "liblua.a",
                "liblua" .. short_ver .. ".a",
            }
        end
        for _, dir in ipairs(search_paths) do
            for _, cand in ipairs(candidates) do
                local p = dir .. "/" .. cand
                if fs.path_exists(p) then
                    liblua_path = p
                    break
                end
            end
            if liblua_path then break end
        end
    end

    -- Find headers
    local runtime_dir = find_runtime_root_for_target(target)
    if runtime_dir and target then
        local cross_inc_dir = runtime_dir .. PATH_SEP .. "lib" .. PATH_SEP .. target .. PATH_SEP .. "include"
        if fs.path_exists(cross_inc_dir .. "/lua.h") then
            lua_include_dir = cross_inc_dir
        end
    end

    if not lua_include_dir then
        local inc_candidates = {}
        if is_luajit() then
            inc_candidates = {
                "/usr/include/luajit-2.1",
                "/usr/include/luajit-2.0",
                "/usr/local/include/luajit-2.1",
                "/usr/local/include/luajit-2.0",
                "/opt/homebrew/include/luajit-2.1",
                "/opt/homebrew/include/luajit-2.0",
            }
        else
            inc_candidates = {
                "/usr/include/lua" .. lua_ver,
                "/usr/local/include/lua" .. lua_ver,
                "/opt/homebrew/include/lua" .. lua_ver,
                "/usr/include/lua" .. major,
                "/usr/include",
            }
            if compiler:find("mingw") then
                table.insert(inc_candidates, "/usr/x86_64-w64-mingw32/include")
                table.insert(inc_candidates, "/usr/i686-w64-mingw32/include")
            end
        end
        local env_inc = os.getenv("LUA_INCDIR")
        if env_inc then table.insert(inc_candidates, 1, env_inc) end
        for _, dir in ipairs(inc_candidates) do
            if fs.path_exists(dir .. "/lua.h") then
                lua_include_dir = dir
                break
            end
        end
    end

    if not lua_include_dir or not fs.path_exists(lua_include_dir .. "/lua.h") then
        return nil, "Could not find Lua headers (lua.h). Please install lua-dev or liblua-dev."
    end
    if not liblua_path then
        return nil, "Could not find static Lua library (liblua.a). Please install liblua-dev or lua-devel."
    end

    if liblua_path:find("runtime" .. PATH_SEP .. "lib" .. PATH_SEP, 1, true) then
        cflags = "-I" .. lua_include_dir
        ldflags = ""
    end

    local static = options.static
    if not static and compiler:find("musl") then
        static = true
    end

    return {
        compiler = compiler,
        cflags = cflags ~= "" and cflags or ("-I" .. lua_include_dir),
        ldflags = ldflags,
        liblua_path = liblua_path,
        lua_include_dir = lua_include_dir,
        static = static,
    }, nil
end

return toolchain
