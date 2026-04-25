-- Lumos App Utilities
-- Shared helpers for app-related logic across modules.

local app_utils = {}

-- Returns true if no global or persistent flag already uses the short name "v",
-- meaning the framework can safely auto-register `-v` for --version.
function app_utils.version_short_available(app)
    if not app then return true end
    if app.global_flags then
        for _, flag_def in pairs(app.global_flags) do
            if flag_def.short == "v" then
                return false
            end
        end
    end
    if app.persistent_flags then
        for _, flag_def in pairs(app.persistent_flags) do
            if flag_def.short == "v" then
                return false
            end
        end
    end
    return true
end

return app_utils
