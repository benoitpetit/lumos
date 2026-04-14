-- lumos/bundle.lua
-- Module for bundling Lua CLI applications into portable single-file executables
-- Supports amalgamation of multiple Lua modules into one distributable file

local bundle = {}

local security = require("lumos.security")

local lfs
local function get_lfs()
    if not lfs then
        lfs = require("lfs")
    end
    return lfs
end

-- Default configuration
local default_config = {
    include_lumos = true,
    shebang = "#!/usr/bin/env lua",
    strip_comments = false,
    output_dir = "dist"
}

-- List of Lumos core modules
local LUMOS_MODULES = {
    "lumos.init",
    "lumos.app",
    "lumos.core",
    "lumos.flags",
    "lumos.color",
    "lumos.config",
    "lumos.json",
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
    "lumos.bundle"
}

--- Read file contents
---@param path string
---@return string|nil, string|nil
local function read_file(path)
    local f, err = security.safe_open(path, "r")
    if not f then
        return nil, "Cannot read file: " .. path .. " - " .. (err or "unknown error")
    end
    local content = f:read("*a")
    f:close()
    return content
end

--- Write file contents
---@param path string
---@param content string
---@return boolean, string|nil
local function write_file(path, content)
    local f, err = security.safe_open(path, "w")
    if not f then
        return false, "Cannot write file: " .. path .. " - " .. (err or "unknown error")
    end
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

--- Check if path is a regular file
---@param path string
---@return boolean
local function is_file(path)
    return get_lfs().attributes(path, "mode") == "file"
end

--- Detect Windows
---@return boolean
local function is_windows()
    return package.config:sub(1, 1) == "\\"
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

--- Strip Lua comments from code (simple version)
---@param code string
---@return string
local function strip_comments(code)
    -- Remove multi-line comments
    code = code:gsub("%-%-%[%[.-%]%]", "")
    -- Remove single-line comments (but preserve shebang)
    local lines = {}
    for line in code:gmatch("[^\n]*") do
        if not line:match("^%s*%-%-") or line:match("^#!") then
            -- Remove inline comments
            local stripped = line:gsub("%s*%-%-[^\n]*$", "")
            table.insert(lines, stripped)
        end
    end
    return table.concat(lines, "\n")
end

--- Find module file path
---@param module_name string
---@param search_paths table
---@return string|nil
local function find_module(module_name, search_paths)
    local file_path = module_name:gsub("%.", "/")
    
    for _, base_path in ipairs(search_paths) do
        -- Try direct path
        local path = base_path .. "/" .. file_path .. ".lua"
        if path_exists(path) then
            return path
        end
        
        -- Try init.lua for packages
        path = base_path .. "/" .. file_path .. "/init.lua"
        if path_exists(path) then
            return path
        end
    end
    
    return nil
end

--- Extract required modules from Lua code
---@param code string
---@return table
local function extract_requires(code)
    local requires = {}
    
    -- Match require('module') and require("module")
    for module in code:gmatch("require%s*%(?%s*['\"]([^'\"]+)['\"]%s*%)?") do
        requires[module] = true
    end
    
    return requires
end

--- Recursively collect all dependencies
---@param entry_file string
---@param search_paths table
---@param collected table
---@param visited table
---@return table, table
local function collect_dependencies(entry_file, search_paths, collected, visited)
    collected = collected or {}
    visited = visited or {}
    
    if visited[entry_file] then
        return collected, visited
    end
    visited[entry_file] = true
    
    local content, err = read_file(entry_file)
    if not content then
        return collected, visited
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
                collect_dependencies(module_path, search_paths, collected, visited)
            end
        end
    end
    
    return collected, visited
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
    
    -- Add custom require loader
    table.insert(lines, [[
-- Install bundled module loader
local _original_require = require
local function _bundled_require(name)
    if _BUNDLED_MODULES[name] then
        if package.loaded[name] == nil then
            local result = _BUNDLED_MODULES[name]()
            if result == nil then result = true end
            package.loaded[name] = result
        end
        return package.loaded[name]
    end
    return _original_require(name)
end
require = _bundled_require
]])
    
    return table.concat(lines, "\n")
end

--- Bundle a Lua CLI application
---@param options table Bundle options
---@return boolean success
---@return string|nil error_message
function bundle.create(options)
    options = options or {}
    
    local config = {}
    for k, v in pairs(default_config) do
        config[k] = options[k] ~= nil and options[k] or v
    end
    
    local entry_file = options.entry
    local output_file = options.output
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
    
    -- Determine search paths
    local search_paths = options.search_paths or {
        project_dir,
        project_dir .. "/src",
        project_dir .. "/lib",
        project_dir .. "/lumos"
    }
    
    -- Add Lumos installation paths
    local home = os.getenv("HOME")
    if home then
        local version = _VERSION:match("%d+%.%d+") or "5.1"
        table.insert(search_paths, home .. "/.luarocks/share/lua/" .. version)
    end
    
    -- Also check current working directory for local lumos
    table.insert(search_paths, ".")
    
    -- Collect all dependencies
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
    collect_dependencies(entry_file, search_paths, modules, visited)
    
    -- Read entry file
    local entry_content, err = read_file(entry_file)
    if not entry_content then
        return false, err
    end
    
    -- Remove shebang from entry file (we'll add our own)
    entry_content = entry_content:gsub("^#![^\n]*\n", "")
    
    if config.strip_comments then
        entry_content = strip_comments(entry_content)
    end
    
    -- Generate bundle
    local bundle_parts = {}
    
    -- Shebang
    table.insert(bundle_parts, config.shebang)
    table.insert(bundle_parts, "")
    
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
    
    -- Determine output path
    if not output_file then
        local basename = entry_file:match("([^/]+)%.lua$") or "bundle"
        mkdir_p(config.output_dir)
        output_file = config.output_dir .. "/" .. basename
    else
        -- Create parent directory for custom output path
        local parent_dir = output_file:match("^(.+)/[^/]+$")
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
    if not is_windows() then
        os.execute("chmod +x " .. security.shell_escape(output_file))
    end
    
    return true, nil, {
        output = output_file,
        modules_count = #modules,
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

return bundle
