-- lumos/native_build.lua
-- Native static binary builder for Lumos CLI applications.
-- Embeds the Lua VM, amalgamated Lua code (optionally as bytecode),
-- and static native modules into a single executable.

local native_build = {}

local bundle = require("lumos.bundle")
local fs = require("lumos.fs")
local security = require("lumos.security")
local runtime_manager = require("lumos.runtime_manager")
local lfs = require("lfs")

local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

local function find_runtime_root_for_target(target)
    for _, runtime_dir in ipairs(runtime_manager.get_runtime_dirs()) do
        local lib_dir = runtime_dir .. PATH_SEP .. "lib" .. PATH_SEP .. target
        if fs.path_exists(lib_dir) then
            return runtime_dir
        end
    end
    return nil
end

local BUILD_CACHE_DIR = ".lumos" .. PATH_SEP .. "cache"

local function ensure_build_cache_dir()
    if not fs.path_exists(BUILD_CACHE_DIR) then
        fs.mkdir_p(BUILD_CACHE_DIR)
    end
end

-- Generate a random filename inside the build cache
local counter = 0
local function random_tmp_name(ext)
    ensure_build_cache_dir()
    counter = counter + 1
    local suffix = tostring(math.random(100000, 999999)) .. "_" .. tostring(counter) .. "_" .. tostring(os.time())
    return BUILD_CACHE_DIR .. PATH_SEP .. "tmp_" .. suffix .. (ext or "")
end

-- Utility: execute shell command and return stdout, stderr, exit code
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



-- Known osxcross installation directories
local OSXCROSS_DIRS = {
    "/usr/local/osxcross",
    "/opt/osxcross",
    os.getenv("HOME") and (os.getenv("HOME") .. "/osxcross") or nil,
    "/tmp/osxcross",
}

-- Cross-platform command lookup (which / where)
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

-- Preferred compiler candidates
local COMPILER_CANDIDATES = {
    "cc", "gcc", "clang", "musl-gcc", "aarch64-linux-gnu-gcc",
    "x86_64-w64-mingw32-gcc", "o64-clang", "oa64-clang"
}

-- Preferred luac candidates
local LUAC_CANDIDATES = {
    "luac", "luac5.4", "luac5.3", "luac5.2", "luac5.1"
}

local SUPPORTED_BUILD_TARGETS = {
    ["linux-x86_64"] = true,
    ["linux-aarch64"] = true,
    ["windows-x86_64"] = true,
    ["darwin-x86_64"] = true,
    ["darwin-aarch64"] = true,
}

local function normalize_arch(arch)
    if not arch then
        return nil
    end
    local normalized = arch:lower()
    if normalized == "amd64" then
        normalized = "x86_64"
    elseif normalized == "arm64" then
        normalized = "aarch64"
    end
    return normalized
end

local function normalize_os(os_name)
    if not os_name then
        return nil
    end
    local normalized = os_name:lower()
    if normalized == "macos" then
        normalized = "darwin"
    end
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
    return {
        os = os_name,
        arch = arch,
        normalized = os_name .. "-" .. arch,
    }, nil
end

function native_build.detect_host_target()
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

    local arch = normalize_arch(uname_m)
    return uname_s .. "-" .. (arch or "x86_64")
end

function native_build.resolve_target(target)
    local selected = target or native_build.detect_host_target()
    local parsed, parse_err = parse_target(selected)
    if not parsed then
        return nil, parse_err
    end

    if not SUPPORTED_BUILD_TARGETS[parsed.normalized] then
        local supported = {}
        for t in pairs(SUPPORTED_BUILD_TARGETS) do
            table.insert(supported, t)
        end
        table.sort(supported)
        return nil, "Unsupported build target: " .. parsed.normalized .. ". Supported targets: " .. table.concat(supported, ", ")
    end

    local host_parsed = parse_target(native_build.detect_host_target())
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

-- Detect available C compiler
-- @return string|nil compiler path
function native_build.detect_compiler(preferred)
    if preferred then
        return find_command(preferred)
    end
    for _, name in ipairs(COMPILER_CANDIDATES) do
        local path = find_command(name)
        if path then return path end
    end
    return nil
end

-- Detect Lua version string used by pkg-config (e.g. "5.3")
local function get_lua_version()
    -- LuaJIT reports "LuaJIT 2.1.0-beta3" but uses 5.1 ABI
    local v = _VERSION:match("%d+%.%d+") or "5.1"
    return v
end

local function is_luajit()
    return type(_G.jit) == "table" or (_VERSION and _VERSION:match("LuaJIT"))
end

-- Detect available luac compiler and verify version matches target VM
-- @param preferred string|nil preferred luac name
-- @param target_version string|nil expected Lua version (defaults to current VM version)
-- @return string|nil luac path, string|nil error
function native_build.detect_luac(preferred, target_version)
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
            -- Verify version match
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

-- Compile Lua source string to bytecode string
-- @return string|nil bytecode, string|nil error
function native_build.bytecode_compile(lua_code, preferred_luac, target_version)
    local luac, lerr = native_build.detect_luac(preferred_luac, target_version)
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

-- Try pkg-config for a given module name
-- @return string|nil cflags, string|nil libs
local function pkg_config(name)
    local cflags, _, ccode = shell_exec("pkg-config --cflags " .. security.shell_escape(name) .. " 2>/dev/null")
    local libs, _, lcode = shell_exec("pkg-config --libs " .. security.shell_escape(name) .. " 2>/dev/null")
    if (ccode == 0 or ccode == true) and (lcode == 0 or lcode == true) then
        return cflags:gsub("%s+$", ""), libs:gsub("%s+$", "")
    end
    return nil, nil
end

-- Discover Lua toolchain: includes + static library
-- @return table|nil toolchain { compiler, cflags, ldflags, liblua_path, lua_include_dir, static }
function native_build.detect_toolchain(options)
    options = options or {}
    local target, target_err = native_build.resolve_target(options.target)
    if not target then
        return nil, target_err
    end
    local target_info = parse_target(target)
    local target_os = target_info and target_info.os or nil
    local preferred_compiler = options.cc

    -- Target-aware compiler selection
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

    local compiler = native_build.detect_compiler(preferred_compiler)
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
    local short_ver = major .. minor -- e.g. "53"

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
        -- Add MinGW sysroot paths when cross-compiling for Windows
        if compiler:find("mingw") then
            table.insert(common, "/usr/x86_64-w64-mingw32/lib")
            table.insert(common, "/usr/i686-w64-mingw32/lib")
        end
        for _, p in ipairs(common) do table.insert(search_paths, p) end

        local env_lib = os.getenv("LUA_LIB") or os.getenv("LUA_LIBDIR")
        if env_lib then table.insert(search_paths, 1, env_lib) end

        -- Add bundled cross-compiled libraries from runtime/lib/<target>
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
    -- Prefer bundled cross-compiled headers to guarantee version match with liblua.a
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

    -- If we are using a bundled cross-compiled library, discard system pkg-config
    -- flags to avoid mixing system headers with the bundled library.
    if liblua_path:find("runtime/lib", 1, true) then
        cflags = "-I" .. lua_include_dir
        ldflags = ""
    end

    -- musl-gcc is typically used specifically for static linking
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

-- Discover static archive for a native Lua C module (e.g. "lfs")
-- @return string|nil path to lib<name>.a
function native_build.find_static_native_module(name)
    local home = os.getenv("HOME") or os.getenv("USERPROFILE")
    local lua_ver = get_lua_version()
    local search_paths = {}

    -- Project-local paths (useful for vendored static libs)
    local cwd = lfs.currentdir()
    if cwd and cwd ~= "" then
        table.insert(search_paths, cwd)
        table.insert(search_paths, cwd .. PATH_SEP .. "lib")
        table.insert(search_paths, cwd .. PATH_SEP .. "build")
    end

    -- LuaRocks user trees
    if home then
        table.insert(search_paths, home .. PATH_SEP .. ".luarocks" .. PATH_SEP .. "lib" .. PATH_SEP .. "lua" .. PATH_SEP .. lua_ver)
        table.insert(search_paths, home .. PATH_SEP .. ".luarocks" .. PATH_SEP .. "lib")
    end

    -- Parse package.cpath entries to discover nearby lib directories
    local cpath_sep = IS_WINDOWS and ";" or ";"
    for entry in (package.cpath or ""):gmatch("([^" .. cpath_sep .. "]+)") do
        local dir = entry:match("^(.+)[/\\][^/\\]+$")
        if dir then
            table.insert(search_paths, dir)
        end
    end

    local common = {
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib/aarch64-linux-gnu",
        "/usr/lib64",
        "/usr/lib",
        "/usr/local/lib",
        "/opt/homebrew/lib",
    }
    -- Add MinGW sysroot paths for cross-compilation
    if IS_WINDOWS or (package.config:sub(1,1) == "/" and find_command("x86_64-w64-mingw32-gcc")) then
        table.insert(common, "/usr/x86_64-w64-mingw32/lib")
        table.insert(common, "/usr/i686-w64-mingw32/lib")
    end
    for _, p in ipairs(common) do table.insert(search_paths, p) end

    local candidates = {
        "lib" .. name .. ".a",
        "liblua" .. name .. ".a",
    }

    local seen = {}
    for _, dir in ipairs(search_paths) do
        if dir and dir ~= "" and not seen[dir] then
            seen[dir] = true
            for _, cand in ipairs(candidates) do
                local p = dir .. PATH_SEP .. cand
                if fs.path_exists(p) then return p end
            end
        end
    end
    return nil
end

-- Hex-encode a Lua string into a C byte array
local function hex_encode(data)
    local lines = {}
    local line = {}
    for i = 1, #data do
        local b = data:byte(i)
        table.insert(line, string.format("0x%02x", b))
        if #line == 16 then
            table.insert(lines, "  " .. table.concat(line, ", ") .. ",")
            line = {}
        end
    end
    if #line > 0 then
        table.insert(lines, "  " .. table.concat(line, ", ") .. ",")
    end
    return table.concat(lines, "\n")
end

-- Generate the C wrapper source code
-- @param payload string The Lua payload (source or bytecode)
-- @param opts table Options: native_modules, compress (boolean)
-- @return string main_c content
function native_build.generate_c_wrapper(payload, opts)
    opts = opts or {}
    local native_modules = opts.native_modules or {}

    local hex = hex_encode(payload)

    local externs = {}
    local registrations = {}
    for _, mod in ipairs(native_modules) do
        local open_name = mod:gsub("%.", "_")
        table.insert(externs, string.format("extern int luaopen_%s(lua_State *L);", open_name))
        table.insert(registrations, string.format([[
#ifdef STATIC_%s
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_pushcfunction(L, luaopen_%s);
  lua_setfield(L, -2, "%s");
  lua_pop(L, 2);
#endif]], open_name:upper(), open_name, mod))
    end

    local extern_block = table.concat(externs, "\n")
    local register_block = table.concat(registrations, "\n")

    local payload_decl = string.format([[
static const unsigned char bundled_lua[] = {
%s
};
static const size_t bundled_lua_len = sizeof(bundled_lua);]], hex)
    local main_body = [[
  if (luaL_loadbuffer(L, (const char *)bundled_lua, bundled_lua_len, "@bundled") != LUA_OK) {
    fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
    lua_close(L);
    return 1;
  }
]]

    local c_preamble = [[
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif
]]
    local c_mid1 = [[

static void register_preload(lua_State *L) {
]]
    local c_mid2 = [[
}

static void set_arg(lua_State *L, int argc, char *argv[]) {
  int i;
  lua_createtable(L, argc, 0);
  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i);
  }
  lua_setglobal(L, "arg");
}

int main(int argc, char *argv[]) {
  lua_State *L = luaL_newstate();
  if (!L) {
    fprintf(stderr, "Error: cannot create Lua state\n");
    return 1;
  }
  luaL_openlibs(L);
  register_preload(L);
  set_arg(L, argc, argv);
]]
    local c_epilogue = [[
  if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
    fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
    lua_close(L);
    return 1;
  }
  lua_close(L);
  return 0;
}
]]

    return c_preamble
        .. extern_block .. "\n\n"
        .. payload_decl .. "\n\n"
        .. c_mid1
        .. register_block .. "\n"
        .. c_mid2
        .. main_body
        .. c_epilogue
end

-- Map of require names -> static library search names
local KNOWN_NATIVE_MODULES = {
    -- Filesystem
    lfs = "lfs",

    -- Networking
    socket = "socket",
    ["socket.core"] = "socket_core",
    mime = "mime",
    ["mime.core"] = "mime_core",
    ssl = "ssl",
    ["ssl.core"] = "ssl_core",

    -- JSON
    cjson = "cjson",
    ["cjson.core"] = "cjson_core",
    rapidjson = "rapidjson",
    yajl = "yajl",

    -- Database
    lsqlite3 = "lsqlite3",
    dbi = "dbi",

    -- Parsing / pattern matching
    lpeg = "lpeg",
    lpeglabel = "lpeglabel",

    -- Cryptography
    bcrypt = "bcrypt",
    argon2 = "argon2",
    md5 = "md5",
    sha2 = "sha2",
    openssl = "openssl",
    ossl = "ossl",

    -- Compression
    zlib = "zlib",
    lz4 = "lz4",
    zstd = "zstd",
    brotli = "brotli",

    -- POSIX / OS
    posix = "posix",
    unix = "unix",
    term = "term",
    linenoise = "linenoise",
    readline = "readline",
    winio = "winio",

    -- System / process
    system = "system",
    proc = "proc",
    spawn = "spawn",
    lanes = "lanes",
    pthread = "pthread",

    -- Event loops / async
    ev = "ev",
    inotify = "inotify",
    epoll = "epoll",
    kqueue = "kqueue",

    -- HTTP / clients
    curl = "curl",
    ["cURL"] = "cURL",

    -- Protocol / serialization
    pb = "pb",
    struct = "struct",
    uuid = "uuid",
    base64 = "base64",
    cmsgpack = "cmsgpack",

    -- Images
    gd = "gd",
    vips = "vips",

    -- XML
    expat = "expat",
    xmlreader = "xmlreader",

    -- Encoding / i18n
    iconv = "iconv",
    utf8 = "utf8",

    -- Bit manipulation
    bit = "bit",
    bit32 = "bit32",

    -- Misc
    sysctl = "sysctl",
    expect = "expect",
    child = "child",
}

-- Determine which native C modules are used by the amalgamated code
function native_build.detect_native_modules(lua_code)
    local natives = {}
    for req_name, lib_name in pairs(KNOWN_NATIVE_MODULES) do
        _ = lib_name
        if lua_code:find(req_name, 1, true) then
            local escaped = req_name:gsub("([%.%-%+%*%?%[%]%^%$%(%)])", "%%%1")
            -- Check multiple common require patterns
            local patterns = {
                'require%("' .. escaped .. '"',
                "require%('" .. escaped .. "'",
                'require "' .. escaped .. '"',
                "require '" .. escaped .. "'",
                'require%(' .. escaped .. '%)',
                'require%s*,%s*"' .. escaped .. '"',
                "require%s*,%s*'" .. escaped .. "'",
            }
            local found = false
            for _, p in ipairs(patterns) do
                if lua_code:find(p) then
                    found = true
                    break
                end
            end
            if found then
                table.insert(natives, req_name)
            end
        end
    end
    return natives
end

function native_build.detect_project_native_modules(options)
    options = options or {}
    if not options.entry then
        return {}
    end

    local project_dir = options.project_dir or "."
    local search_paths = options.search_paths or {
        project_dir,
        project_dir .. PATH_SEP .. "src",
        project_dir .. PATH_SEP .. "lib",
        project_dir .. PATH_SEP .. "lumos",
        ".",
    }

    local modules = bundle.analyze(options.entry, search_paths) or {}
    local files = { options.entry }
    for _, mod in ipairs(modules) do
        if mod.path and mod.name and not mod.name:match("^lumos") then
            table.insert(files, mod.path)
        end
    end

    local native_set = {}
    for _, file_path in ipairs(files) do
        local code = fs.read_file(file_path)
        if code then
            local found = native_build.detect_native_modules(code)
            for _, mod_name in ipairs(found) do
                native_set[mod_name] = true
            end
        end
    end

    local native_list = {}
    for mod_name in pairs(native_set) do
        table.insert(native_list, mod_name)
    end
    table.sort(native_list)
    return native_list
end

-- Compile the C wrapper into a native binary
local function compile(main_c_path, output_path, toolchain, native_module_paths, native_modules, options)
    local is_mingw = toolchain.compiler:find("mingw")
    local is_darwin = toolchain.compiler:find("clang") and (toolchain.compiler:find("o64") or toolchain.compiler:find("oa64"))

    -- For osxcross, the compiler wrapper needs its own tools (ld64, ar, etc.) on PATH
    -- and its libraries (libxar) on LD_LIBRARY_PATH
    local env_prefix = ""
    if is_darwin then
        -- Resolve symlinks to find the real osxcross bin directory
        local real_compiler, _, rc = shell_exec("readlink -f " .. security.shell_escape(toolchain.compiler))
        if rc == 0 then
            real_compiler = real_compiler:gsub("%s+$", "")
        else
            real_compiler = toolchain.compiler
        end
        local compiler_dir = real_compiler:match("^(.+)[/\\][^/\\]+$")
        if compiler_dir then
            local lib_dir = compiler_dir:match("^(.+)[/\\]bin$") .. PATH_SEP .. "lib"
            env_prefix = "env PATH=" .. security.shell_escape(compiler_dir) .. ":$PATH LD_LIBRARY_PATH=" .. security.shell_escape(lib_dir) .. ":$LD_LIBRARY_PATH "
        end
    end

    local cmd_parts = {
        env_prefix .. security.shell_escape(toolchain.compiler),
        toolchain.cflags,
    }
    if (toolchain.static or options.static) and not is_darwin then
        table.insert(cmd_parts, "-static")
    end
    -- Define STATIC_xxx macros so the C wrapper registers native modules in package.preload
    for _, mod in ipairs(native_modules or {}) do
        local macro = "STATIC_" .. mod:gsub("[^%a_]", "_"):upper()
        table.insert(cmd_parts, "-D" .. macro)
    end
    table.insert(cmd_parts, security.shell_escape(main_c_path))
    if toolchain.liblua_path then
        table.insert(cmd_parts, security.shell_escape(toolchain.liblua_path))
    else
        table.insert(cmd_parts, toolchain.ldflags)
    end
    for _, mod_path in ipairs(native_module_paths or {}) do
        table.insert(cmd_parts, security.shell_escape(mod_path))
    end
    if not is_mingw and not is_darwin and not IS_WINDOWS then
        table.insert(cmd_parts, "-lm -ldl")
    elseif is_darwin then
        table.insert(cmd_parts, "-lm")
    end
    table.insert(cmd_parts, "-o " .. security.shell_escape(output_path))

    local cmd = table.concat(cmd_parts, " ")
    local stdout, stderr, code = shell_exec(cmd)
    if code ~= 0 then
        return false, "Compilation failed.\nCommand: " .. cmd .. "\n" .. stderr .. stdout
    end
    return true, nil, cmd
end

local function djb2_hash(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + str:byte(i)) % 4294967296
    end
    return string.format("%08x", hash)
end

-- Detect Lua version from headers (e.g. 5.4 from LUA_VERSION_NUM 504)
local function get_lua_version_from_headers(include_dir)
    local fh = io.open(include_dir .. "/lua.h", "r")
    if not fh then return nil end
    local content = fh:read("*a")
    fh:close()
    local num = content:match("#define%s+LUA_VERSION_NUM%s+(%d+)")
    if num then
        local n = tonumber(num)
        local major = math.floor(n / 100)
        local minor = n % 100
        return major .. "." .. minor
    end
    return nil
end

-- Build a standalone native binary
-- @param options table
--   entry, output, project_dir, include_lumos, strip_comments,
--   cc, static, search_paths, bytecode
-- @return boolean success, string|nil err, table|nil info
function native_build.create(options)
    options = options or {}

    local resolved_target, target_err = native_build.resolve_target(options.target)
    if not resolved_target then
        return false, target_err
    end
    options.target = resolved_target

    local target_info = parse_target(resolved_target)
    local is_windows_target = target_info and target_info.os == "windows"

    -- Step 1: Amalgamate Lua code
    local ok, err, lua_code, modules_count = bundle.amalgamate(options)
    if not ok then
        return false, err
    end

    -- Remove shebang: luaL_loadbuffer does not ignore it
    lua_code = lua_code:gsub("^#![^\n]*\n?", "")

    local payload = lua_code
    local is_bytecode = false

    -- Step 2: Detect toolchain (needed early for bytecode version matching)
    local toolchain, terr = native_build.detect_toolchain(options)
    if not toolchain then
        return false, terr
    end

    -- Step 3: Bytecode compilation (with cache)
    if options.bytecode then
        ensure_build_cache_dir()
        local bc_key = djb2_hash(lua_code)
        local bc_cache = BUILD_CACHE_DIR .. PATH_SEP .. "bytecode-" .. bc_key .. ".luac"
        local f = io.open(bc_cache, "rb")
        if f then
            payload = f:read("*a")
            f:close()
            is_bytecode = true
        else
            local header_ver = get_lua_version_from_headers(toolchain.lua_include_dir)
            local preferred_luac = nil
            if header_ver then
                preferred_luac = "luac" .. header_ver
            end
            local bc, berr = native_build.bytecode_compile(payload, preferred_luac, header_ver)
            if not bc then
                return false, berr
            end
            payload = bc
            is_bytecode = true
            local wf = io.open(bc_cache, "wb")
            if wf then
                wf:write(bc)
                wf:close()
            end
        end
    end

    -- Step 4: Determine output path (before writing any temp file so failures are cheap)
    local output_path = options.output
    local entry_file = options.entry
    if not output_path then
        local basename = entry_file:match("([^/\\]+)%.lua$") or "build"
        local out_dir = options.output_dir or "dist"
        if not fs.path_exists(out_dir) then
            fs.mkdir_p(out_dir)
        end
        output_path = out_dir .. PATH_SEP .. basename
    else
        local parent = output_path:match("^(.+)[/\\][^/\\]+$")
        if parent then
            if not fs.path_exists(parent) then
                fs.mkdir_p(parent)
            end
        end
    end

    -- Append .exe on Windows targets if missing
    if is_windows_target and not output_path:match("%.exe$") then
        output_path = output_path .. ".exe"
    end

    -- Step 5: Detect native C modules used
    local native_modules = native_build.detect_project_native_modules(options)
    local native_module_paths = {}
    local missing_native = {}
    local linked_native_modules = {}
    for _, mod in ipairs(native_modules) do
        local path = native_build.find_static_native_module(mod)
        if path then
            table.insert(native_module_paths, path)
            table.insert(linked_native_modules, mod)
        else
            table.insert(missing_native, mod)
        end
    end

    -- Step 6: Generate C wrapper
    local main_c = native_build.generate_c_wrapper(payload, {
        native_modules = linked_native_modules,
    })

    local main_c_path = random_tmp_name(".c")
    local f = io.open(main_c_path, "w")
    if not f then
        return false, "Cannot write temporary C file: " .. main_c_path
    end
    f:write(main_c)
    f:close()

    -- Step 7: Compile
    local cok, cerr, cmd = compile(main_c_path, output_path, toolchain, native_module_paths, native_modules, {
        static = options.static,
    })
    if not options.debug_build then
        os.remove(main_c_path)
    end
    if not cok then
        return false, cerr
    end

    return true, nil, {
        output = output_path,
        target = resolved_target,
        modules_count = modules_count,
        size = lfs.attributes(output_path, "size") or 0,
        compiler = toolchain.compiler,
        command = cmd,
        missing_native = missing_native,
        bytecode = is_bytecode,
        static = toolchain.static,
        debug_build = options.debug_build,
        main_c_path = options.debug_build and main_c_path or nil,
    }
end

return native_build
