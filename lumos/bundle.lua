-- lumos/bundle.lua
-- Module for bundling Lua CLI applications into portable single-file executables
-- Supports amalgamation of multiple Lua modules into one distributable file

local bundle = {}

local fs = require("lumos.fs")
local security = require("lumos.security")


local PATH_SEP = _G.package.config:sub(1, 1)
local IS_WINDOWS = PATH_SEP == "\\"

-- Default configuration
local default_config = {
    include_lumos = true,
    shebang = "#!/usr/bin/env lua",
    strip_comments = false,
    output_dir = "dist",
    version = false,
}

-- List of Lumos core modules
local LUMOS_MODULES = {
    "lumos.init",
    "lumos.app",
    "lumos.core",
    "lumos.parser",
    "lumos.validator",
    "lumos.executor",
    "lumos.help_renderer",
    "lumos.flags",
    "lumos.color",
    "lumos.config",
    "lumos.json",
    "lumos.yaml",
    "lumos.loader",
    "lumos.progress",
    "lumos.prompt",
    "lumos.table",
    "lumos.security",
    "lumos.logger",
    "lumos.completion",
    "lumos.manpage",
    "lumos.markdown",
    "lumos.format",
    "lumos.bundle",
    "lumos.native_build",
    "lumos.package",
    "lumos.plugin",
    "lumos.error",
    "lumos.error_codes",
    "lumos.version",
    "lumos.platform",
    "lumos.terminal",
    "lumos.middleware",
    "lumos.profiler",
    "lumos.config_cache",
    "lumos.runtime_manager",
    "lumos.fs"
}

local read_file = fs.read_file
local write_file = fs.write_file
local path_exists = fs.path_exists
local is_file = fs.is_file
local mkdir_p = fs.mkdir_p

--- Strip Lua comments from code
---@param code string
---@return string
local function strip_comments(code)
    local result = {}
    local i = 1
    local n = #code
    while i <= n do
        local c1 = code:sub(i, i)
        local c2 = code:sub(i+1, i+1)
        if c1 == "-" and c2 == "-" then
            local c3 = code:sub(i+2, i+2)
            local c4 = code:sub(i+3, i+3)
            if c3 == "[" and c4 == "[" then
                -- multi-line comment --[[ ... ]]
                local j = i + 4
                while j <= n do
                    if code:sub(j, j+1) == "]]" then
                        i = j + 2
                        break
                    end
                    j = j + 1
                end
                if j > n then
                    i = n + 1
                end
            else
                -- single-line comment
                while i <= n and code:sub(i, i) ~= "\n" do
                    i = i + 1
                end
            end
        else
            table.insert(result, c1)
            i = i + 1
        end
    end
    return table.concat(result)
end

--- Find module file path
---@param module_name string
---@param search_paths table
---@return string|nil
local function find_module(module_name, search_paths)
    local file_path = module_name:gsub("%.", PATH_SEP)

    for _, base_path in ipairs(search_paths) do
        -- Try direct path
        local path = base_path .. PATH_SEP .. file_path .. ".lua"
        if path_exists(path) then
            return path
        end

        -- Try init.lua for packages
        path = base_path .. PATH_SEP .. file_path .. PATH_SEP .. "init.lua"
        if path_exists(path) then
            return path
        end
    end

    return nil
end

--- Extract required modules from Lua code
--- Note: This pattern only catches static string requires (require("foo") or require('foo')).
--- Dynamic requires (require(var), pcall(require, "foo"), long brackets) are not detected.
---@param code string
---@return table
local function extract_requires(code)
    local requires = {}

    -- Match require('module') and require("module")
    for module in code:gmatch("require%s*%(?%s*['\"]([^'\"]+)['\"]%s*%)?") do
        requires[module] = true
    end
    -- Match pcall(require, 'module') and similar patterns
    for module in code:gmatch("require%s*,%s*['\"]([^'\"]+)['\"]") do
        requires[module] = true
    end

    return requires
end

--- Recursively collect all dependencies
---@param entry_file string
---@param search_paths table
---@param collected table
---@param visited table
---@return table, table, string|nil
local function collect_dependencies(entry_file, search_paths, collected, visited)
    collected = collected or {}
    visited = visited or {}

    if visited[entry_file] then
        return collected, visited, nil
    end
    visited[entry_file] = true

    local content, err = read_file(entry_file)
    if not content then
        return collected, visited, err
    end

    local requires = extract_requires(content)

    for module_name, _ in pairs(requires) do
        -- Skip standard library modules and native C modules
        if not module_name:match("^string$") and
           not module_name:match("^table$") and
           not module_name:match("^math$") and
           not module_name:match("^io$") and
           not module_name:match("^os$") and
           not module_name:match("^debug$") and
           not module_name:match("^coroutine$") and
           not module_name:match("^package$") and
           not module_name:match("^lfs$") and
           not module_name:match("^utf8$") then

            local module_path = find_module(module_name, search_paths)
            if module_path and not visited[module_path] then
                table.insert(collected, {
                    name = module_name,
                    path = module_path
                })
                local _, _, child_err = collect_dependencies(module_path, search_paths, collected, visited)
                if child_err then
                    return collected, visited, child_err
                end
            end
        end
    end

    return collected, visited, nil
end

--- Generate the bundle preloader code
---@param modules table
---@param config table
---@return string
local function generate_preloader(modules, config)
    local lines = {}

    table.insert(lines, "-- Bundled modules preloader")
    table.insert(lines, "-- Compatibility: use loadstring for Lua 5.1, load for 5.2+")
    table.insert(lines, "local _loadcode = loadstring or load")
    table.insert(lines, "local _BUNDLED_MODULES = {}")
    table.insert(lines, "")

    for _, mod in ipairs(modules) do
        local content, err = read_file(mod.path)
        if content then
            -- Remove shebang if present
            content = content:gsub("^#![^\n]*\n", "")

            if config.strip_comments then
                content = strip_comments(content)
            end

            -- Replace version placeholder if provided
            local app_version = config.version
            if app_version then
                content = content:gsub('"__APP_VERSION__"', string.format('"%s"', app_version))
            else
                content = content:gsub('"__APP_VERSION__"', '"dev"')
            end

            -- Use long string with unique delimiter to avoid conflicts
            -- Find a delimiter that doesn't appear in the content
            local delimiter = "="
            local level = 0
            while content:find("%]" .. delimiter .. "%]") or content:find("%[" .. delimiter .. "%[") do
                level = level + 1
                delimiter = string.rep("=", level)
            end

            local open_bracket = "[" .. delimiter .. "["
            local close_bracket = "]" .. delimiter .. "]"

            table.insert(lines, string.format("_BUNDLED_MODULES[%q] = assert(_loadcode(%s", mod.name, open_bracket))
            table.insert(lines, content)
            table.insert(lines, close_bracket .. string.format(", %q))", "@" .. mod.name))
            table.insert(lines, "")
            table.insert(lines, "")
        end
    end

    -- Add bundled module searcher (compatible Lua 5.1+ via package.loaders fallback)
    table.insert(lines, [[
-- Install bundled module searcher
local _BUNDLED_SEARCHERS = package.searchers or package.loaders
table.insert(_BUNDLED_SEARCHERS, 1, function(name)
    if _BUNDLED_MODULES[name] then
        return _BUNDLED_MODULES[name]
    end
    return nil
end)
]])

    return table.concat(lines, "\n")
end

-- Simple djb2 hash for cache keys
local function djb2_hash(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + str:byte(i)) % 4294967296
    end
    return string.format("%08x", hash)
end

local CACHE_DIR = ".lumos" .. PATH_SEP .. "cache"

local function ensure_cache_dir()
    mkdir_p(CACHE_DIR)
end

local function amalgamation_cache_key(entry_content, options, modules)
    local shebang_val
    if options.shebang ~= nil then
        shebang_val = tostring(options.shebang)
    else
        shebang_val = tostring(default_config.shebang)
    end
    local key_parts = {
        entry_content,
        tostring(options.include_lumos),
        tostring(options.strip_comments),
        shebang_val,
        tostring(options.version or ""),
    }
    -- Include dependency contents so cache is invalidated when any dependency changes
    for _, mod in ipairs(modules or {}) do
        local content = read_file(mod.path) or ""
        table.insert(key_parts, content)
    end
    return djb2_hash(table.concat(key_parts, "|"))
end

--- Amalgamate a Lua CLI application into a single Lua string
---@param options table Bundle options
---@return boolean success
---@return string|nil error_message
---@return string|nil amalgamated_lua
---@return number|nil modules_count
function bundle.amalgamate(options)
    options = options or {}

    local config = {}
    for k, v in pairs(default_config) do
        if options[k] ~= nil then
            config[k] = options[k]
        else
            config[k] = v
        end
    end


    local entry_file = options.entry
    local project_dir = options.project_dir or "."

    if not entry_file then
        return false, "Entry file is required"
    end

    if not path_exists(entry_file) then
        return false, "Entry file not found: " .. entry_file
    end

    if not is_file(entry_file) then
        return false, "Entry path is not a file: " .. entry_file
    end

    -- Read raw entry content
    local raw_entry_content, err = read_file(entry_file)
    if not raw_entry_content then
        return false, err
    end

    -- Determine search paths
    local entry_dir = entry_file:match("^(.+)[/\\][^/\\]+$") or "."
    local search_paths = options.search_paths or {
        entry_dir,
        project_dir,
        project_dir .. PATH_SEP .. "src",
        project_dir .. PATH_SEP .. "lib",
        project_dir .. PATH_SEP .. "lumos"
    }

    -- Add Lumos installation paths
    local home = os.getenv("HOME") or os.getenv("USERPROFILE")
    if home then
        local version = _VERSION:match("%d+%.%d+") or "5.1"
        table.insert(search_paths, home .. PATH_SEP .. ".luarocks" .. PATH_SEP .. "share" .. PATH_SEP .. "lua" .. PATH_SEP .. version)
    end

    -- Also check current working directory for local lumos
    table.insert(search_paths, ".")

    -- Collect all dependencies BEFORE computing cache key
    local modules = {}
    local visited = {}

    -- If include_lumos, add all Lumos modules first
    if config.include_lumos then
        for _, module_name in ipairs(LUMOS_MODULES) do
            local module_path = find_module(module_name, search_paths)
            if module_path then
                -- Convert lumos.init to just lumos for require compatibility
                local require_name = module_name
                if module_name == "lumos.init" then
                    require_name = "lumos"
                end
                table.insert(modules, {
                    name = require_name,
                    path = module_path
                })
                visited[module_path] = true
            end
        end
    end

    -- Collect project dependencies
    local _, _, collect_err = collect_dependencies(entry_file, search_paths, modules, visited)
    if collect_err then
        return false, "Failed to collect dependencies: " .. collect_err
    end

    -- Compute cache key including all dependency contents
    local cache_key = amalgamation_cache_key(raw_entry_content, options, modules)
    local cache_path = CACHE_DIR .. PATH_SEP .. "amalgamate-" .. cache_key .. ".lua"
    ensure_cache_dir()

    -- Try cache first
    local cached = read_file(cache_path)
    if cached then
        -- Count modules in cached bundle (approximate: count _BUNDLED_MODULES entries)
        local modules_count = 0
        for _ in cached:gmatch('_BUNDLED_MODULES%[%"') do
            modules_count = modules_count + 1
        end
        return true, nil, cached, modules_count
    end

    -- Process entry content
    local entry_content = raw_entry_content:gsub("^#![^\n]*\n", "")

    if config.strip_comments then
        entry_content = strip_comments(entry_content)
    end

    -- Replace version placeholder if provided
    local app_version = options.version
    if app_version then
        entry_content = entry_content:gsub('"__APP_VERSION__"', string.format('"%s"', app_version))
    else
        -- Replace with 'dev' as default so the placeholder doesn't cause runtime errors
        entry_content = entry_content:gsub('"__APP_VERSION__"', '"dev"')
    end

    -- Generate bundle
    local bundle_parts = {}

    -- Shebang
    if config.shebang and config.shebang ~= "" then
        table.insert(bundle_parts, config.shebang)
        table.insert(bundle_parts, "")
    end

    -- Header comment
    table.insert(bundle_parts, "-- ============================================")
    table.insert(bundle_parts, "-- Bundled Lua CLI Application")
    table.insert(bundle_parts, "-- Generated by Lumos Bundle")
    table.insert(bundle_parts, string.format("-- Date: %s", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(bundle_parts, string.format("-- Modules bundled: %d", #modules))
    table.insert(bundle_parts, "-- ============================================")
    table.insert(bundle_parts, "")

    -- Preloader with all modules
    if #modules > 0 then
        table.insert(bundle_parts, generate_preloader(modules, config))
        table.insert(bundle_parts, "")
    end

    -- Main entry code
    table.insert(bundle_parts, "-- ============================================")
    table.insert(bundle_parts, "-- Main Application")
    table.insert(bundle_parts, "-- ============================================")
    table.insert(bundle_parts, "")
    table.insert(bundle_parts, entry_content)

    local final_bundle = table.concat(bundle_parts, "\n")

    -- Write to cache
    write_file(cache_path, final_bundle)

    return true, nil, final_bundle, #modules
end

--- Bundle a Lua CLI application
---@param options table Bundle options
---@return boolean success
---@return string|nil error_message
function bundle.create(options)
    local success, err, final_bundle, modules_count = bundle.amalgamate(options)
    if not success then
        return false, err
    end

    local output_file = options.output
    local entry_file = options.entry
    local config = {}
    for k, v in pairs(default_config) do
        if options[k] ~= nil then
            config[k] = options[k]
        else
            config[k] = v
        end
    end

    -- Determine output path
    if not output_file then
        local basename = entry_file:match("([^" .. PATH_SEP:gsub("\\", "\\\\") .. "]+)%.lua$") or "bundle"
        mkdir_p(config.output_dir)
        output_file = config.output_dir .. PATH_SEP .. basename
    else
        -- Create parent directory for custom output path
        local parent_dir = output_file:match("^(.+)[/\\][^/\\]+$")
        if parent_dir then
            mkdir_p(parent_dir)
        end
    end

    -- Write bundle
    local ok, write_err = write_file(output_file, final_bundle)
    if not ok then
        return false, write_err
    end

    -- Make executable on Unix-like systems
    if not IS_WINDOWS then
        os.execute("chmod +x " .. security.shell_escape(output_file))
    end

    return true, nil, {
        output = output_file,
        modules_count = modules_count,
        size = #final_bundle
    }
end

--- Get list of Lumos core modules
---@return table
function bundle.get_lumos_modules()
    return LUMOS_MODULES
end

--- Analyze a project and list its dependencies
---@param entry_file string
---@param search_paths table
---@return table
function bundle.analyze(entry_file, search_paths)
    search_paths = search_paths or {"."}

    local modules = {}
    collect_dependencies(entry_file, search_paths, modules, {})

    return modules
end

--- Analyze dependencies of a source file and classify them
---@param source_file string
---@return table|nil deps
---@return string|nil err
function bundle.analyze_dependencies(source_file)
    local file, err = read_file(source_file)
    if not file then
        return nil, err
    end

    local deps = {
        required = {},
        optional = {},
        lumos_modules = {},
        external_modules = {}
    }

    local patterns = {
        { pattern = "require%s*%(%s*['\"]([^'\"]+)['\"]%s*%)", optional = false },
        { pattern = "require%s+['\"]([^'\"]+)['\"]", optional = false },
        { pattern = "pcall%s*%(%s*require%s*,%s*['\"]([^'\"]+)['\"]", optional = true },
    }

    for _, p in ipairs(patterns) do
        for match in file:gmatch(p.pattern) do
            local dep_list = p.optional and deps.optional or deps.required
            dep_list[match] = true
            if match:match("^lumos") then
                deps.lumos_modules[match] = true
            else
                deps.external_modules[match] = true
            end
        end
    end

    return deps
end

--- Determine required Lumos modules from dependency analysis
---@param deps table
---@return table
function bundle.get_required_lumos_modules(deps)
    local required = {
        "lumos.init",
        "lumos.app",
        "lumos.core",
        "lumos.flags",
    }

    local submodule_map = {
        ["lumos.color"] = "lumos.color",
        ["lumos.format"] = "lumos.format",
        ["lumos.loader"] = "lumos.loader",
        ["lumos.progress"] = "lumos.progress",
        ["lumos.prompt"] = "lumos.prompt",
        ["lumos.table"] = "lumos.table",
        ["lumos.json"] = "lumos.json",
        ["lumos.config"] = "lumos.config",
        ["lumos.security"] = "lumos.security",
        ["lumos.logger"] = "lumos.logger",
        ["lumos.completion"] = "lumos.completion",
        ["lumos.manpage"] = "lumos.manpage",
        ["lumos.markdown"] = "lumos.markdown",
        ["lumos.bundle"] = "lumos.bundle",
        ["lumos.native_build"] = "lumos.native_build",
        ["lumos.package"] = "lumos.package",
        ["lumos.plugin"] = "lumos.plugin",
        ["lumos.error"] = "lumos.error",
        ["lumos.error_codes"] = "lumos.error_codes",
        ["lumos.platform"] = "lumos.platform",
        ["lumos.terminal"] = "lumos.terminal",
        ["lumos.middleware"] = "lumos.middleware",
        ["lumos.profiler"] = "lumos.profiler",
        ["lumos.config_cache"] = "lumos.config_cache",
    }

    for mod in pairs(deps.lumos_modules) do
        local main_mod = mod:match("^(lumos%.[^%.]+)")
        if main_mod and submodule_map[main_mod] then
            table.insert(required, submodule_map[main_mod])
        elseif mod == "lumos" then
            -- require("lumos") implies init, but we also pull in commonly used modules
            -- The core four are already included.
        end
    end

    -- Deduplicate
    local seen = {}
    local unique = {}
    for _, mod in ipairs(required) do
        if not seen[mod] then
            seen[mod] = true
            table.insert(unique, mod)
        end
    end

    return unique
end

--- Creates a minimal bundle containing only used modules
---@param source_file string
---@param output_file string
---@param options table|nil { minify = boolean }
---@return boolean success
---@return string|nil error
function bundle.minimal(source_file, output_file, options)
    options = options or {}

    local deps, err = bundle.analyze_dependencies(source_file)
    if not deps then
        return false, err
    end

    local lumos_modules = bundle.get_required_lumos_modules(deps)
    local parts = {}

    table.insert(parts, "-- Lumos Minimal Bundle")
    table.insert(parts, "-- Source: " .. source_file)
    table.insert(parts, "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(parts, "-- Modules: " .. table.concat(lumos_modules, ", "))
    table.insert(parts, "")

    for _, mod in ipairs(lumos_modules) do
        local mod_path = mod:gsub("%.", PATH_SEP) .. ".lua"
        local paths_to_try = {
            "." .. PATH_SEP .. mod_path,
            "." .. PATH_SEP .. "lumos" .. PATH_SEP .. mod:match("^lumos%.(.+)$") .. ".lua",
            package.searchpath(mod, package.path)
        }

        local content
        for _, try_path in ipairs(paths_to_try) do
            if try_path then
                local data = read_file(try_path)
                if data then
                    content = data
                    break
                end
            end
        end

        if content then
            if options.minify then
                content = bundle.minify(content)
            end
            table.insert(parts, "-- BEGIN " .. mod)
            table.insert(parts, content)
            table.insert(parts, "-- END " .. mod)
            table.insert(parts, "")
        end
    end

    -- Include main source
    local main_content = read_file(source_file)
    if main_content then
        table.insert(parts, "-- BEGIN main: " .. source_file)
        table.insert(parts, main_content)
        table.insert(parts, "-- END main: " .. source_file)
    end

    local ok, err = write_file(output_file, table.concat(parts, "\n"))
    if not ok then
        return false, err or ("Cannot create output file: " .. output_file)
    end

    return true
end

--- Simple minification of Lua code
---@param content string
---@return string
function bundle.minify(content)
    -- Step 1: strip comments safely (preserves strings and long brackets)
    content = strip_comments(content)
    -- Step 2: collapse multiple spaces/tabs
    content = content:gsub("[ \t]+", " ")
    -- Step 3: trim whitespace around lines
    content = content:gsub("\n%s+", "\n")
    content = content:gsub("%s+\n", "\n")
    content = content:gsub("^%s+", "")
    content = content:gsub("%s+$", "")
    return content
end

return bundle
