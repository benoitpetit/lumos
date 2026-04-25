-- lumos/native_build/modules.lua
-- Native C module detection and C wrapper generation.

local fs = require("lumos.fs")
local bundle = require("lumos.bundle")
local security = require("lumos.security")

local modules = {}

local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

-- ---------------------------------------------------------------------------
-- lfs (optional)
-- ---------------------------------------------------------------------------

local lfs
local function get_lfs()
    if lfs == nil then
        local ok, mod = pcall(require, "lfs")
        lfs = ok and mod or false
    end
    return lfs
end

-- ---------------------------------------------------------------------------
-- Command lookup (duplicated to avoid circular deps)
-- ---------------------------------------------------------------------------

local function shell_exec(cmd)
    local tmp_out = os.tmpname() .. ".out"
    local tmp_err = os.tmpname() .. ".err"
    local ok, _, code = os.execute(cmd .. " >" .. tmp_out .. " 2>" .. tmp_err)
    local fh = io.open(tmp_out, "r")
    local stdout = fh and fh:read("*a") or ""
    if fh then fh:close() end
    fh = io.open(tmp_err, "r")
    local stderr = fh and fh:read("*a") or ""
    if fh then fh:close() end
    os.remove(tmp_out)
    os.remove(tmp_err)
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
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Hex encode and C wrapper generation
-- ---------------------------------------------------------------------------

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

function modules.generate_c_wrapper(payload, opts)
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

-- ---------------------------------------------------------------------------
-- Known native modules mapping
-- ---------------------------------------------------------------------------

local KNOWN_NATIVE_MODULES = {
    lfs = "lfs",
    socket = "socket",
    ["socket.core"] = "socket_core",
    mime = "mime",
    ["mime.core"] = "mime_core",
    ssl = "ssl",
    ["ssl.core"] = "ssl_core",
    cjson = "cjson",
    ["cjson.core"] = "cjson_core",
    rapidjson = "rapidjson",
    yajl = "yajl",
    lsqlite3 = "lsqlite3",
    dbi = "dbi",
    lpeg = "lpeg",
    lpeglabel = "lpeglabel",
    bcrypt = "bcrypt",
    argon2 = "argon2",
    md5 = "md5",
    sha2 = "sha2",
    openssl = "openssl",
    ossl = "ossl",
    zlib = "zlib",
    lz4 = "lz4",
    zstd = "zstd",
    brotli = "brotli",
    posix = "posix",
    unix = "unix",
    term = "term",
    linenoise = "linenoise",
    readline = "readline",
    winio = "winio",
    system = "system",
    proc = "proc",
    spawn = "spawn",
    lanes = "lanes",
    pthread = "pthread",
    ev = "ev",
    inotify = "inotify",
    epoll = "epoll",
    kqueue = "kqueue",
    curl = "curl",
    ["cURL"] = "cURL",
    pb = "pb",
    struct = "struct",
    uuid = "uuid",
    base64 = "base64",
    cmsgpack = "cmsgpack",
    gd = "gd",
    vips = "vips",
    expat = "expat",
    xmlreader = "xmlreader",
    iconv = "iconv",
    utf8 = "utf8",
    bit = "bit",
    bit32 = "bit32",
    sysctl = "sysctl",
    expect = "expect",
    child = "child",
}

function modules.detect_native_modules(lua_code)
    local natives = {}
    for req_name, lib_name in pairs(KNOWN_NATIVE_MODULES) do
        _ = lib_name
        if lua_code:find(req_name, 1, true) then
            local escaped = req_name:gsub("([%.%-%+%*%?%[%]%^%$%(%)])", "%%%1")
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

function modules.detect_project_native_modules(options)
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

    local mod_list = bundle.analyze(options.entry, search_paths) or {}
    local files = { options.entry }
    for _, mod in ipairs(mod_list) do
        if mod.path and mod.name and not mod.name:match("^lumos") then
            table.insert(files, mod.path)
        end
    end

    local native_set = {}
    for _, file_path in ipairs(files) do
        local code = fs.read_file(file_path)
        if code then
            local found = modules.detect_native_modules(code)
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

function modules.find_static_native_module(name)
    local home = os.getenv("HOME") or os.getenv("USERPROFILE")
    local lua_ver = _VERSION:match("%d+%.%d+") or "5.1"
    local search_paths = {}

    local lfs_mod = get_lfs()
    local cwd = lfs_mod and lfs_mod.currentdir() or os.getenv("PWD")
    if cwd and cwd ~= "" then
        table.insert(search_paths, cwd)
        table.insert(search_paths, cwd .. PATH_SEP .. "lib")
        table.insert(search_paths, cwd .. PATH_SEP .. "build")
    end

    if home then
        table.insert(search_paths, home .. PATH_SEP .. ".luarocks" .. PATH_SEP .. "lib" .. PATH_SEP .. "lua" .. PATH_SEP .. lua_ver)
        table.insert(search_paths, home .. PATH_SEP .. ".luarocks" .. PATH_SEP .. "lib")
    end

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

return modules
