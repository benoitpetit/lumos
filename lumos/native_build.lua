-- lumos/native_build.lua
-- Native static binary builder for Lumos CLI applications.
-- Embeds the Lua VM, amalgamated Lua code (optionally as bytecode),
-- and static native modules into a single executable.

local native_build = {}

local bundle = require("lumos.bundle")
local fs = require("lumos.fs")
local security = require("lumos.security")
local runtime_manager = require("lumos.runtime_manager")
local toolchain = require("lumos.native_build.toolchain")
local native_modules = require("lumos.native_build.modules")

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

-- ---------------------------------------------------------------------------
-- Delegated functions from submodules
-- ---------------------------------------------------------------------------

function native_build.detect_host_target()
    return toolchain.detect_host_target()
end

function native_build.resolve_target(target)
    return toolchain.resolve_target(target)
end

function native_build.detect_compiler(preferred)
    return toolchain.detect_compiler(preferred)
end

function native_build.detect_luac(preferred, target_version)
    return toolchain.detect_luac(preferred, target_version)
end

function native_build.bytecode_compile(lua_code, preferred_luac, target_version)
    return toolchain.bytecode_compile(lua_code, preferred_luac, target_version)
end

function native_build.detect_toolchain(options)
    return toolchain.detect_toolchain(options)
end

function native_build.generate_c_wrapper(payload, opts)
    return native_modules.generate_c_wrapper(payload, opts)
end

function native_build.detect_native_modules(lua_code)
    return native_modules.detect_native_modules(lua_code)
end

function native_build.detect_project_native_modules(options)
    return native_modules.detect_project_native_modules(options)
end

function native_build.find_static_native_module(name)
    return native_modules.find_static_native_module(name)
end

-- ---------------------------------------------------------------------------
-- Compilation
-- ---------------------------------------------------------------------------

local function compile(main_c_path, output_path, tool, native_module_paths, natives, options)
    local is_mingw = tool.compiler:find("mingw")
    local is_darwin = (options.target_os == "darwin") or (tool.compiler:find("clang") and (tool.compiler:find("o64") or tool.compiler:find("oa64")))

    local env_prefix = ""
    if is_darwin then
        local real_compiler, _, rc = shell_exec("readlink -f " .. security.shell_escape(tool.compiler))
        if rc == 0 then
            real_compiler = real_compiler:gsub("%s+$", "")
        else
            real_compiler = tool.compiler
        end
        local compiler_dir = real_compiler:match("^(.+)[/\\][^/\\]+$")
        if compiler_dir then
            local lib_dir = compiler_dir:match("^(.+)[/\\]bin$") .. PATH_SEP .. "lib"
            env_prefix = "env PATH=" .. security.shell_escape(compiler_dir) .. ":$PATH LD_LIBRARY_PATH=" .. security.shell_escape(lib_dir) .. ":$LD_LIBRARY_PATH "
        end
    end

    local cmd_parts = {
        env_prefix .. security.shell_escape(tool.compiler),
        tool.cflags,
    }
    if (tool.static or options.static) and not is_darwin then
        table.insert(cmd_parts, "-static")
    end
    for _, mod in ipairs(natives or {}) do
        local macro = "STATIC_" .. mod:gsub("[^%a_]", "_"):upper()
        table.insert(cmd_parts, "-D" .. macro)
    end
    table.insert(cmd_parts, security.shell_escape(main_c_path))
    if tool.liblua_path then
        table.insert(cmd_parts, security.shell_escape(tool.liblua_path))
    else
        table.insert(cmd_parts, tool.ldflags)
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

-- ---------------------------------------------------------------------------
-- Main build orchestration
-- ---------------------------------------------------------------------------

function native_build.create(options)
    options = options or {}

    local resolved_target, target_err = native_build.resolve_target(options.target)
    if not resolved_target then
        return false, target_err
    end
    options.target = resolved_target

    local target_info = toolchain.resolve_target(resolved_target)
    -- resolve_target returns string on success, so parse it again
    local function parse_target_str(t)
        local raw = t:lower()
        local os_name, arch = raw:match("^([%w_]+)%-([%w_]+)$")
        return { os = os_name, arch = arch }
    end
    local tinfo = parse_target_str(resolved_target)
    local is_windows_target = tinfo and tinfo.os == "windows"

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
    local tool, terr = native_build.detect_toolchain(options)
    if not tool then
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
            local header_ver = get_lua_version_from_headers(tool.lua_include_dir)
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

    -- Step 4: Determine output path
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
    local natives = native_build.detect_project_native_modules(options)
    local native_module_paths = {}
    local missing_native = {}
    local linked_native = {}
    for _, mod in ipairs(natives) do
        local path = native_build.find_static_native_module(mod)
        if path then
            table.insert(native_module_paths, path)
            table.insert(linked_native, mod)
        else
            table.insert(missing_native, mod)
        end
    end

    -- Step 6: Generate C wrapper
    local main_c = native_build.generate_c_wrapper(payload, {
        native_modules = linked_native,
    })

    local main_c_path = random_tmp_name(".c")
    local f = io.open(main_c_path, "w")
    if not f then
        return false, "Cannot write temporary C file: " .. main_c_path
    end
    f:write(main_c)
    f:close()

    -- Step 7: Compile
    local cok, cerr, cmd = compile(main_c_path, output_path, tool, native_module_paths, natives, {
        static = options.static,
        target_os = tinfo and tinfo.os,
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
        size = (get_lfs() and get_lfs().attributes(output_path, "size")) or 0,
        compiler = tool.compiler,
        command = cmd,
        missing_native = missing_native,
        bytecode = is_bytecode,
        static = tool.static,
        debug_build = options.debug_build,
        main_c_path = options.debug_build and main_c_path or nil,
    }
end

return native_build
