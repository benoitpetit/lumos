-- Lumos Progress Module
-- Provides rich progress bar functionality for long-running operations

local progress = {}

local color = require('lumos.color')

-- Progress bar class
local ProgressBar = {}
ProgressBar.__index = ProgressBar

function ProgressBar:new(config)
    config = config or {}
    local bar = {
        total = config.total or 100,
        current = 0,
        width = config.width or 50,
        format = config.format or "[{bar}] {percentage}% {current}/{total}{eta}",
        fill = config.fill or "=",
        empty = config.empty or " ",
        prefix = config.prefix or "",
        suffix = config.suffix or "",
        message = config.message or "",
        show_eta = config.show_eta ~= false,
        auto_newline = config.auto_newline ~= false,
        start_time = os.time(),
        style = config.style or "classic", -- classic, unicode, blocks
        color_fn = config.color_fn or nil,
        table_mode = config.table_mode or false,
        _completed_rendered = false,
        _last_len = 0,
    }
    return setmetatable(bar, ProgressBar)
end

function ProgressBar:update(value)
    if value then
        self.current = math.min(value, self.total)
    end
    self:render()
end

function ProgressBar:increment(amount)
    amount = amount or 1
    self.current = math.min(self.current + amount, self.total)
    self:render()
end

--- Shortcut for increment(1)
function ProgressBar:tick()
    self:increment(1)
end

--- Reset the bar to zero and restart timing.
function ProgressBar:reset()
    self.current = 0
    self._completed_rendered = false
    self._last_len = 0
    self.start_time = os.time()
    self:render()
end

--- Change the displayed message and re-render.
-- @param msg New message text.
function ProgressBar:set_message(msg)
    self.message = msg or ""
    self:render()
end

--- Adjust the total on the fly (useful when size is discovered dynamically).
-- @param total New total value (minimum 1).
function ProgressBar:set_total(total)
    self.total = math.max(1, total or 100)
    self:render()
end

--- Return true if the bar has reached 100%.
function ProgressBar:is_complete()
    return self.current >= self.total
end

--- Return the current percentage (0-100).
function ProgressBar:get_percentage()
    return math.floor((self.current / self.total) * 100)
end

--- Return elapsed seconds since start.
function ProgressBar:get_elapsed()
    return os.time() - self.start_time
end

--- Return estimated seconds remaining, or nil if unknown.
function ProgressBar:get_eta()
    local elapsed = self:get_elapsed()
    if self.current > 0 and elapsed > 0 then
        local rate = self.current / elapsed
        return math.floor((self.total - self.current) / rate)
    end
    return nil
end

--- Return the processing rate (items per second), or nil if unknown.
function ProgressBar:get_rate()
    local elapsed = self:get_elapsed()
    if self.current > 0 and elapsed > 0 then
        return self.current / elapsed
    end
    return nil
end

function ProgressBar:get_bar()
    local filled_width = math.floor((self.current / self.total) * self.width)
    local empty_width = self.width - filled_width
    local bar = ""
    if self.style == "classic" then
        bar = string.rep(self.fill, filled_width) .. string.rep(self.empty, empty_width)
    elseif self.style == "unicode" then
        bar = string.rep("█", filled_width) .. string.rep("░", empty_width)
    elseif self.style == "blocks" then
        local blocks = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}
        local block_count = self.width
        local prog = (self.current / self.total) * block_count
        local full_blocks = math.floor(prog)
        local partial_block = math.floor((prog - full_blocks) * (#blocks - 1) + 1)
        bar = string.rep(blocks[#blocks], full_blocks)
        if full_blocks < block_count then
            bar = bar .. blocks[partial_block]
            bar = bar .. string.rep(blocks[1], block_count - full_blocks - 1)
        end
    end
    if self.color_fn then
        bar = self.color_fn(bar, self.current, self.total)
    end
    return bar
end

function ProgressBar:render()
    local percentage = math.floor((self.current / self.total) * 100)
    local bar = self:get_bar()
    local eta_text = ""
    if self.show_eta and self.current > 0 then
        local elapsed = os.time() - self.start_time
        if elapsed > 0 then
            local rate = self.current / elapsed
            local remaining = (self.total - self.current) / rate
            eta_text = string.format(" ETA: %ds", math.floor(remaining))
        end
    end
    local output = self.format
        :gsub("{bar}", bar)
        :gsub("{percentage}", percentage)
        :gsub("{current}", self.current)
        :gsub("{total}", self.total)
        :gsub("{bytes_current}", progress.format_bytes(self.current))
        :gsub("{bytes_total}", progress.format_bytes(self.total))
        :gsub("{eta}", eta_text)
        :gsub("{message}", self.message)
    if self.table_mode then
        output = progress.table_bar(bar, self.current, self.total)
    end
    local text = self.prefix .. output .. self.suffix
    local visible_len = #color.strip(text)
    if self._last_len and self._last_len > visible_len then
        io.write("\r" .. string.rep(" ", self._last_len) .. "\r")
    else
        io.write("\r")
    end
    io.write(text)
    io.flush()
    self._last_len = visible_len
    if self.current >= self.total and not self._completed_rendered then
        if self.auto_newline then
            io.write("\n")
        end
        self._completed_rendered = true
        self._last_len = 0
    end
end

function ProgressBar:finish()
    self.current = self.total
    if not self._completed_rendered then
        self:render()
    end
end

function progress.new(config)
    return ProgressBar:new(config)
end

--- Iterate over a table with an automatic progress bar.
-- @param items Array-like table to iterate over.
-- @param config Optional progress bar configuration.
-- @return Iterator function (usable in a for-loop).
function progress.iter(items, config)
    config = config or {}
    local total = #items
    local bar = progress.new({
        total = total,
        format = config.format or "[{bar}] {percentage}% {current}/{total}",
        width = config.width,
        style = config.style,
        message = config.message,
        show_eta = config.show_eta,
        auto_newline = config.auto_newline,
    })
    local i = 0
    return function()
        i = i + 1
        if items[i] then
            bar:increment(1)
            return items[i]
        else
            if not bar._completed_rendered then
                bar:finish()
            end
            return nil
        end
    end
end

--- Run a function while showing a progress bar.
-- The function receives the bar as first argument.
-- @param total Total steps expected.
-- @param fn Function to execute.
-- @param config Optional progress bar configuration.
function progress.run(total, fn, config)
    config = config or {}
    local bar = progress.new({
        total = total,
        format = config.format,
        width = config.width,
        style = config.style,
        message = config.message,
        show_eta = config.show_eta,
        auto_newline = config.auto_newline,
    })
    local ok, err = pcall(fn, bar)
    if ok then
        if not bar._completed_rendered then
            bar:finish()
        end
    else
        if not bar._completed_rendered then
            bar:finish()
        end
        error(err, 0)
    end
end

--- Create a progress bar specialized for byte transfers.
-- Supports {bytes_current} and {bytes_total} in the format string.
-- @param total_bytes Total size in bytes.
-- @param config Optional progress bar configuration.
function progress.bytes(total_bytes, config)
    config = config or {}
    return progress.new({
        total = total_bytes,
        format = config.format or "[{bar}] {percentage}% {bytes_current}/{bytes_total}",
        width = config.width or 40,
        style = config.style or "classic",
        message = config.message,
        show_eta = config.show_eta,
        auto_newline = config.auto_newline,
    })
end

--- Format a byte count into a human-readable string.
-- @param bytes Number of bytes.
-- @return String like "1.50 MB" or "512 B".
function progress.format_bytes(bytes)
    if type(bytes) ~= "number" or bytes < 0 then
        return "0 B"
    end
    local units = {"B", "KB", "MB", "GB", "TB"}
    local unit_idx = 1
    local size = bytes
    while size >= 1024 and unit_idx < #units do
        size = size / 1024
        unit_idx = unit_idx + 1
    end
    if unit_idx == 1 then
        return string.format("%d %s", size, units[unit_idx])
    else
        return string.format("%.2f %s", size, units[unit_idx])
    end
end

function progress.simple(current, total, width)
    width = width or 50
    local percentage = math.floor((current / total) * 100)
    local filled = math.floor((current / total) * width)
    local bar = string.rep("=", filled) .. string.rep(" ", width - filled)
    io.write(string.format("\r[%s] %d%% (%d/%d)", bar, percentage, current, total))
    io.flush()
    if current >= total then
        io.write("\n")
    end
end

-- Styles helpers
-- color_fn can be a function or a string
function progress.color_bar(bar, current, total, color_fn)
    if type(color_fn) == "function" then
        return color_fn(bar, current, total)
    elseif type(color_fn) == "string" and color[color_fn] then
        return color[color_fn](bar)
    else
        local ratio = current / total
        if ratio < 0.33 then
            return color.red(bar)
        elseif ratio < 0.66 then
            return color.yellow(bar)
        else
            return color.green(bar)
        end
    end
end

function progress.table_bar(bar, current, total)
    return string.format("| Progress | %s | %d/%d |", bar, current, total)
end

return progress
