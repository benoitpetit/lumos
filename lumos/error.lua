-- Lumos Error Module
-- Typed error system with formatting, retry logic, and success helpers

local Error = {}
Error.__index = Error
Error.codes = require("lumos.error_codes")

Error.__tostring = function(e)
    return string.format("[%s] %s", e.type, e.message)
end

--- Creates a new typed error
---@param error_type string Error type key (e.g. "INVALID_ARGUMENT")
---@param message string|nil Custom message (uses default from codes if nil)
---@param context table|nil Additional context (details, suggestion, exit_code, retryable, retry_after)
---@return table
function Error.new(error_type, message, context)
    local code_def = Error.codes[error_type] or Error.codes.CUSTOM
    context = context or {}

    local err = setmetatable({}, Error)
    err.type = error_type
    err.message = message or code_def.message
    err.context = context
    err.exit_code = context.exit_code or code_def.code
    err.retryable = context.retryable or code_def.retryable or false
    err.retry_after = context.retry_after
    err.timestamp = os.time()
    err.stack = debug.traceback("", 2)

    return err
end

--- Checks if the error is retryable
---@return boolean
function Error:is_retryable()
    return self.retryable
end

--- Returns retry-after delay if applicable
---@return number|nil
function Error:retry_after()
    return self.retry_after
end

--- Formats the error for user display
---@return string
function Error:format_user()
    local lines = {}

    table.insert(lines, string.format("Error: %s", self.message))

    local code_def = Error.codes[self.type]
    if code_def and code_def.suggestion then
        table.insert(lines, string.format("\nSuggestion: %s", code_def.suggestion))
    end

    if self.context.suggestion then
        table.insert(lines, string.format("\nSuggestion: %s", self.context.suggestion))
    end

    if self.context.details and next(self.context.details) then
        table.insert(lines, "\nDetails:")
        for k, v in pairs(self.context.details) do
            table.insert(lines, string.format("  %s: %s", k, tostring(v)))
        end
    end

    return table.concat(lines, "\n")
end

--- Formats the error for logging
---@return table
function Error:format_log()
    return {
        type = self.type,
        message = self.message,
        exit_code = self.exit_code,
        context = self.context,
        timestamp = self.timestamp,
        stack = self.stack
    }
end

--- Creates a success result object
---@param data table|nil Data to return
---@return table
function Error.success(data)
    return {
        success = true,
        data = data or {},
        exit_code = 0
    }
end

--- Checks if a value is a Lumos error
---@param value any
---@return boolean
function Error.is_error(value)
    return type(value) == "table" and getmetatable(value) == Error
end

return Error
