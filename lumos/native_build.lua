-- lumos/native_build.lua
-- Native static binary builder for Lumos CLI applications.
-- Embeds the Lua VM, amalgamated Lua code (optionally as bytecode & compressed),
-- and static native modules into a single executable.

local native_build = {}

local bundle = require("lumos.bundle")
local security = require("lumos.security")

local lfs
local function get_lfs()
    if not lfs then
        lfs = require("lfs")
    end
    return lfs
end

-- Utility: execute shell command and return stdout, stderr, exit code
local function shell_exec(cmd)
    local tmpout = os.tmpname()
    local tmperr = os.tmpname()
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

-- Utility: check if file exists
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

-- Utility: detect Windows
local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

-- Preferred compiler candidates
local COMPILER_CANDIDATES = {
    "cc", "gcc", "clang", "musl-gcc", "x86_64-w64-mingw32-gcc"
}

-- Preferred luac candidates
local LUAC_CANDIDATES = {
    "luac", "luac5.4", "luac5.3", "luac5.2", "luac5.1"
}

-- Detect available C compiler
-- @return string|nil compiler path
function native_build.detect_compiler(preferred)
    if preferred then
        local out, _, code = shell_exec("which " .. security.shell_escape(preferred) .. " 2>/dev/null")
        if code == 0 then
            local path = out:gsub("%s+$", "")
            if path ~= "" then return path end
        end
        return nil
    end
    for _, name in ipairs(COMPILER_CANDIDATES) do
        local out, _, code = shell_exec("which " .. security.shell_escape(name) .. " 2>/dev/null")
        if code == 0 then
            local path = out:gsub("%s+$", "")
            if path ~= "" then return path end
        end
    end
    return nil
end

-- Detect available luac compiler
-- @return string|nil luac path
function native_build.detect_luac(preferred)
    if preferred then
        local out, _, code = shell_exec("which " .. security.shell_escape(preferred) .. " 2>/dev/null")
        if code == 0 then
            local path = out:gsub("%s+$", "")
            if path ~= "" then return path end
        end
        return nil
    end
    for _, name in ipairs(LUAC_CANDIDATES) do
        local out, _, code = shell_exec("which " .. security.shell_escape(name) .. " 2>/dev/null")
        if code == 0 then
            local path = out:gsub("%s+$", "")
            if path ~= "" then return path end
        end
    end
    return nil
end

-- Compile Lua source string to bytecode string
-- @return string|nil bytecode, string|nil error
function native_build.bytecode_compile(lua_code, preferred_luac)
    local luac = native_build.detect_luac(preferred_luac)
    if not luac then
        return nil, "No luac compiler found. Cannot compile to bytecode."
    end
    local tmp_in = os.tmpname() .. ".lua"
    local tmp_out = os.tmpname() .. ".luac"
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

-- Detect Lua version string used by pkg-config (e.g. "5.3")
local function get_lua_version()
    local v = _VERSION:match("%d+%.%d+") or "5.1"
    return v
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
    local compiler = native_build.detect_compiler(options.cc)
    if not compiler then
        return nil, "No C compiler found. Please install gcc, clang, or musl-gcc."
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
    local pkg_names = {
        "lua-" .. lua_ver,
        "lua" .. lua_ver,
        "lua"
    }
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
        for _, p in ipairs(common) do table.insert(search_paths, p) end

        local env_lib = os.getenv("LUA_LIB")
        if env_lib then table.insert(search_paths, 1, env_lib) end

        local candidates = {
            "liblua" .. lua_ver .. ".a",
            "liblua" .. major .. ".a",
            "liblua.a",
            "liblua" .. short_ver .. ".a",
        }
        for _, dir in ipairs(search_paths) do
            for _, cand in ipairs(candidates) do
                local p = dir .. "/" .. cand
                if file_exists(p) then
                    liblua_path = p
                    break
                end
            end
            if liblua_path then break end
        end
    end

    -- Find headers
    if not lua_include_dir then
        local inc_candidates = {
            "/usr/include/lua" .. lua_ver,
            "/usr/local/include/lua" .. lua_ver,
            "/opt/homebrew/include/lua" .. lua_ver,
            "/usr/include/lua" .. major,
            "/usr/include",
        }
        for _, dir in ipairs(inc_candidates) do
            if file_exists(dir .. "/lua.h") then
                lua_include_dir = dir
                break
            end
        end
    end

    if not lua_include_dir or not file_exists(lua_include_dir .. "/lua.h") then
        return nil, "Could not find Lua headers (lua.h). Please install lua-dev or liblua-dev."
    end

    if not liblua_path then
        if ldflags == "" then
            ldflags = "-llua" .. lua_ver
        end
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
    local home = os.getenv("HOME")
    local lua_ver = get_lua_version()
    local search_paths = {}
    if home then
        table.insert(search_paths, home .. "/.luarocks/lib/lua/" .. lua_ver)
    end
    local common = {
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib/aarch64-linux-gnu",
        "/usr/lib64",
        "/usr/lib",
        "/usr/local/lib",
        "/opt/homebrew/lib",
    }
    for _, p in ipairs(common) do table.insert(search_paths, p) end

    local candidates = {
        "lib" .. name .. ".a",
        "liblua" .. name .. ".a",
    }
    for _, dir in ipairs(search_paths) do
        for _, cand in ipairs(candidates) do
            local p = dir .. "/" .. cand
            if file_exists(p) then return p end
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
    mime = "mime",
    ssl = "ssl",

    -- JSON
    cjson = "cjson",
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
local function detect_native_modules(lua_code)
    local natives = {}
    for req_name, lib_name in pairs(KNOWN_NATIVE_MODULES) do
        if lua_code:find(req_name, 1, true) then
            local escaped = req_name:gsub("([%.%-%+%*%?%[%]%^%$%(%)])", "%%%1")
            -- Check multiple common require patterns
            local patterns = {
                'require%("' .. escaped .. '"',
                "require%('" .. escaped .. "'",
                'require "' .. escaped .. '"',
                "require '" .. escaped .. "'",
                'require%(' .. escaped .. '%)',
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

-- Compile the C wrapper into a native binary
local function compile(main_c_path, output_path, toolchain, native_module_paths, native_modules, options)
    local cmd_parts = {
        security.shell_escape(toolchain.compiler),
        toolchain.cflags,
    }
    if toolchain.static or options.static then
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
    if not is_windows() then
        table.insert(cmd_parts, "-lm -ldl")
    end
    table.insert(cmd_parts, "-o " .. security.shell_escape(output_path))

    local cmd = table.concat(cmd_parts, " ")
    local stdout, stderr, code = shell_exec(cmd)
    if code ~= 0 then
        return false, "Compilation failed.\nCommand: " .. cmd .. "\n" .. stderr .. stdout
    end
    return true, nil, cmd
end

local BUILD_CACHE_DIR = ".lumos/cache"

local function ensure_build_cache_dir()
    local lfs_mod = get_lfs()
    if not lfs_mod.attributes(BUILD_CACHE_DIR, "mode") then
        lfs_mod.mkdir(BUILD_CACHE_DIR)
    end
end

local function djb2_hash(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + str:byte(i)) % 4294967296
    end
    return string.format("%08x", hash)
end

-- Build a standalone native binary
-- @param options table
--   entry, output, project_dir, include_lumos, strip_comments,
--   cc, static, search_paths, bytecode
-- @return boolean success, string|nil err, table|nil info
function native_build.create(options)
    options = options or {}

    -- Step 1: Amalgamate Lua code
    local ok, err, lua_code, modules_count = bundle.amalgamate(options)
    if not ok then
        return false, err
    end

    -- Remove shebang: luaL_loadbuffer does not ignore it
    lua_code = lua_code:gsub("^#![^\n]*\n?", "")

    local payload = lua_code
    local is_bytecode = false

    -- Step 2: Bytecode compilation (with cache)
    if options.bytecode then
        ensure_build_cache_dir()
        local bc_key = djb2_hash(lua_code)
        local bc_cache = BUILD_CACHE_DIR .. "/bytecode-" .. bc_key .. ".luac"
        local f = io.open(bc_cache, "rb")
        if f then
            payload = f:read("*a")
            f:close()
            is_bytecode = true
        else
            local bc, berr = native_build.bytecode_compile(payload)
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

    -- Step 3: Detect toolchain
    local toolchain, terr = native_build.detect_toolchain(options)
    if not toolchain then
        return false, terr
    end

    -- Step 4: Determine output path (before writing any temp file so failures are cheap)
    local output_path = options.output
    local entry_file = options.entry
    if not output_path then
        local basename = entry_file:match("([^/]+)%.lua$") or "build"
        local out_dir = options.output_dir or "dist"
        local lfs_mod = get_lfs()
        if not lfs_mod.attributes(out_dir, "mode") then
            lfs_mod.mkdir(out_dir)
        end
        output_path = out_dir .. "/" .. basename
    else
        local parent = output_path:match("^(.+)/[^/]+$")
        if parent then
            local lfs_mod = get_lfs()
            if not lfs_mod.attributes(parent, "mode") then
                os.execute("mkdir -p " .. security.shell_escape(parent))
            end
        end
    end

    -- Step 5: Detect native C modules used
    local native_modules = detect_native_modules(lua_code)
    local native_module_paths = {}
    local missing_native = {}
    for _, mod in ipairs(native_modules) do
        local path = native_build.find_static_native_module(mod)
        if path then
            table.insert(native_module_paths, path)
        else
            table.insert(missing_native, mod)
        end
    end

    -- Step 6: Generate C wrapper
    local main_c = native_build.generate_c_wrapper(payload, {
        native_modules = native_modules,
    })

    local main_c_path = os.tmpname() .. ".c"
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
        modules_count = modules_count,
        size = get_lfs().attributes(output_path, "size") or 0,
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
