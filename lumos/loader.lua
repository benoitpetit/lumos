-- lumos/loader.lua
-- Terminal loading animations with rich styles, colors and lifecycle management.
-- Supports both module-level singleton usage and instantiable objects.

local loader = {}
local color = require("lumos.color")

local styles = {
    standard = {"|", "/", "-", "\\"},
    dots     = {".  ", ".. ", "...", "   "},
    dots2    = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
    bounce   = {"◜", "◠", "◝", "◞", "◡", "◟"},
    arrow    = {"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"},
    pulse    = {"◐", "◓", "◑", "◒"},
    circle   = {"◴", "◷", "◶", "◵"},
    square   = {"◰", "◳", "◲", "◱"},
    moon     = {"◎", "◉", "◎", "◉"},
    star     = {"✶", "✸", "✹", "✺", "✹", "✷"},
    toggle   = {"⊶", "⊷"},
    triangle = {"◢", "◣", "◤", "◥"},
}

-- ========================================================================
-- Instantiable Loader object
-- ========================================================================
local Loader = {}
Loader.__index = Loader

function Loader.new(msg, style_name)
    local self = setmetatable({}, Loader)
    self._state = {
        active   = false,
        style    = styles.standard,
        idx      = 1,
        message  = msg or "Loading",
        status   = "",
        last_len = 0,
    }
    if style_name then
        self._state.style = styles[style_name] or styles.standard
    end
    return self
end

-- Internal: clear the current line based on the previous output length.
function Loader:_clear_line()
    if self._state.last_len > 0 then
        io.write("\r" .. string.rep(" ", self._state.last_len) .. "\r")
    else
        io.write("\r")
    end
end

-- Internal: write text, track visible length and flush.
function Loader:_write_output(text)
    self._state.last_len = #color.strip(text)
    io.write(text)
    io.flush()
end

--- Start a loading animation.
function Loader:start(msg, style_name)
    local st = self._state
    st.active   = true
    st.style    = styles[style_name] or st.style
    st.idx      = 1
    st.message  = msg or st.message or "Loading"
    st.status   = "loading"
    local spinner = st.style[st.idx]
    local text    = "\r" .. color.cyan(st.message) .. " " .. color.bold(spinner)
    self:_write_output(text)
end

--- Stop the loader with a neutral [STOP] marker.
function Loader:stop()
    local st = self._state
    if st.active then
        self:_clear_line()
        self:_write_output(color.dim(st.message .. " [STOP]") .. "\n")
        st.active = false
        st.status = "stopped"
    end
end

--- Complete the loader with a green [OK] marker.
function Loader:success()
    local st = self._state
    if st.active then
        self:_clear_line()
        self:_write_output(color.green("✓ " .. st.message .. " [OK]") .. "\n")
        st.active = false
        st.status = "success"
    end
end

--- Complete the loader with a red [FAIL] marker.
function Loader:fail()
    local st = self._state
    if st.active then
        self:_clear_line()
        self:_write_output(color.red("✗ " .. st.message .. " [FAIL]") .. "\n")
        st.active = false
        st.status = "fail"
    end
end

--- Complete the loader with a yellow [WARN] marker and optional detail.
function Loader:warning(msg)
    local st = self._state
    if st.active then
        self:_clear_line()
        local suffix = msg and (" " .. msg) or ""
        self:_write_output(color.yellow("⚠ " .. st.message .. " [WARN]" .. suffix) .. "\n")
        st.active = false
        st.status = "warning"
    end
end

--- Complete the loader with a blue [INFO] marker and optional detail.
function Loader:info(msg)
    local st = self._state
    if st.active then
        self:_clear_line()
        local suffix = msg and (" " .. msg) or ""
        self:_write_output(color.blue("ℹ " .. st.message .. " [INFO]" .. suffix) .. "\n")
        st.active = false
        st.status = "info"
    end
end

--- Clear the loader line without any status marker.
function Loader:clear()
    local st = self._state
    if st.active then
        self:_clear_line()
        st.active = false
        st.status = "cleared"
    end
end

--- Advance the spinner to the next frame.
function Loader:next()
    local st = self._state
    if st.active then
        st.idx = st.idx % #st.style + 1
        local spinner = st.style[st.idx]
        local text    = "\r" .. color.cyan(st.message) .. " " .. color.bold(spinner)
        self:_write_output(text)
    end
end

--- Alias for `:next()`.
Loader.step = Loader.next

--- Update the loader message while keeping the animation running.
function Loader:update(msg)
    local st = self._state
    if st.active and msg then
        st.message = msg
        local spinner = st.style[st.idx]
        local text    = "\r" .. color.cyan(st.message) .. " " .. color.bold(spinner)
        self:_write_output(text)
    end
end

--- Return whether a loader is currently active.
function Loader:is_active()
    return self._state.active
end

--- Return the current status string.
function Loader:get_status()
    return self._state.status
end

--- Change the spinner style on the fly.
function Loader:set_style(style_name)
    local st = self._state
    if styles[style_name] then
        st.style = styles[style_name]
        st.idx   = 1
        if st.active then
            local spinner = st.style[st.idx]
            local text    = "\r" .. color.cyan(st.message) .. " " .. color.bold(spinner)
            self:_write_output(text)
        end
    end
end

--- Run a function with this loader instance animated.
function Loader:run(fn, msg, style_name)
    self:start(msg, style_name)
    local ok, result = pcall(fn, self)
    if ok then
        self:success()
        return result
    else
        self:fail()
        error(result, 0)
    end
end

-- ========================================================================
-- Module-level singleton API (backward compatible)
-- ========================================================================
local _default = Loader.new()

function loader.new(msg, style_name)
    return Loader.new(msg, style_name)
end

function loader.start(msg, style_name)
    return _default:start(msg, style_name)
end

function loader.stop()
    return _default:stop()
end

function loader.success()
    return _default:success()
end

function loader.fail()
    return _default:fail()
end

function loader.warning(msg)
    return _default:warning(msg)
end

function loader.info(msg)
    return _default:info(msg)
end

function loader.clear()
    return _default:clear()
end

function loader.next()
    return _default:next()
end

loader.step = loader.next

function loader.update(msg)
    return _default:update(msg)
end

function loader.is_active()
    return _default:is_active()
end

function loader.get_styles()
    local names = {}
    for name, _ in pairs(styles) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function loader.set_style(style_name)
    return _default:set_style(style_name)
end

function loader.run(fn, msg, style_name)
    return _default:run(fn, msg, style_name)
end

return loader
