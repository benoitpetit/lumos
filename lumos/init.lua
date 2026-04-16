-- Main Lumos Entry Point
-- This module provides the public API for the Lumos CLI framework

local M = {}
M.version = require("lumos.version")

-- Module mapping for lazy loading
local modules = {
    app = "lumos.app",
    core = "lumos.core",
    flags = "lumos.flags",
    color = "lumos.color",
    format = "lumos.format",
    loader = "lumos.loader",
    progress = "lumos.progress",
    prompt = "lumos.prompt",
    table = "lumos.table",
    json = "lumos.json",
    config = "lumos.config",
    completion = "lumos.completion",
    manpage = "lumos.manpage",
    markdown = "lumos.markdown",
    security = "lumos.security",
    logger = "lumos.logger",
    bundle = "lumos.bundle",
    native_build = "lumos.native_build",
    package = "lumos.package",
    plugin = "lumos.plugin",
    error = "lumos.error",
    platform = "lumos.platform",
    terminal = "lumos.terminal",
    middleware = "lumos.middleware",
    profiler = "lumos.profiler",
    config_cache = "lumos.config_cache",
}

local cache = {}

-- Metatable for lazy loading
setmetatable(M, {
    __index = function(t, k)
        if modules[k] and not cache[k] then
            cache[k] = require(modules[k])
        end
        return cache[k]
    end
})

-- Core functions always available (do not trigger lazy loading of heavy modules)
function M.new_app(config)
    return require("lumos.app").new_app(config)
end

function M.use(plugin_type, fn)
    return require("lumos.plugin").use(plugin_type, fn)
end

function M.error(error_type, message, context)
    return require("lumos.error").new(error_type, message, context)
end

function M.success(data)
    return require("lumos.error").success(data)
end

function M.load_config(file_path)
    return require("lumos.core").load_config(file_path)
end

-- Optional preloading for critical paths
function M.preload(...)
    for _, name in ipairs({...}) do
        if modules[name] and not cache[name] then
            cache[name] = require(modules[name])
        end
    end
end

return M
