-- Lumos Progress Module
-- Provides progress bar functionality for long-running operations

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
        show_eta = config.show_eta ~= false,
        start_time = os.time(),
        style = config.style or "classic", -- classic, unicode, blocks
        color_fn = config.color_fn or nil,
        table_mode = config.table_mode or false
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
        local progress = (self.current / self.total) * block_count
        local full_blocks = math.floor(progress)
        local partial_block = math.floor((progress - full_blocks) * (#blocks - 1) + 1)
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
        local rate = self.current / elapsed
        local remaining = (self.total - self.current) / rate
        eta_text = string.format(" ETA: %ds", math.floor(remaining))
    end
    local output = self.format
        :gsub("{bar}", bar)
        :gsub("{percentage}", percentage)
        :gsub("{current}", self.current)
        :gsub("{total}", self.total)
        :gsub("{eta}", eta_text)
    if self.table_mode then
        output = progress.table_bar(bar, self.current, self.total)
    end
    io.write("\r" .. self.prefix .. output .. self.suffix)
    io.flush()
    if self.current >= self.total then
        io.write("\n")
    end
end

function ProgressBar:finish()
    self.current = self.total
    self:render()
end

function progress.new(config)
    return ProgressBar:new(config)
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
        -- dynamic fallback as before
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
    -- show in table format 
    return string.format("| Progress | %s | %d/%d |", bar, current, total)
end

return progress