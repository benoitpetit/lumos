-- Lumos Plugin System
-- Simple extension mechanism for apps and commands

local plugin = {}

--- Apply a plugin to a target (app or command).
-- The plugin can be a function(target, opts) or a table with an init(target, opts) method.
function plugin.use(target, plugin_fn, opts)
    opts = opts or {}
    if type(plugin_fn) == "function" then
        plugin_fn(target, opts)
    elseif type(plugin_fn) == "table" and type(plugin_fn.init) == "function" then
        plugin_fn.init(target, opts)
    else
        error("Plugin must be a function or a table with an init() method")
    end
    return target
end

return plugin
