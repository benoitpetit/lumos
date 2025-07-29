-- Lumos Progress Module
-- Provides progress bar functionality for long-running operations

local progress = {}

-- Progress bar class
local ProgressBar = {}
ProgressBar.__index = ProgressBar

function ProgressBar:new(config)
    config = config or {}
    
    local bar = {
        total = config.total or 100,
        current = 0,
        width = config.width or 50,
        format = config.format or "[{bar}] {percentage}% {current}/{total}",
        fill = config.fill or "=",
        empty = config.empty or " ",
        prefix = config.prefix or "",
        suffix = config.suffix or "",
        show_eta = config.show_eta ~= false,
        start_time = os.time()
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

function ProgressBar:render()
    local percentage = math.floor((self.current / self.total) * 100)
    local filled_width = math.floor((self.current / self.total) * self.width)
    local empty_width = self.width - filled_width
    
    local bar = string.rep(self.fill, filled_width) .. string.rep(self.empty, empty_width)
    
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
    
    -- Clear line and print progress
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

-- Create a new progress bar
function progress.new(config)
    return ProgressBar:new(config)
end

-- Simple progress function for quick use
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

return progress
