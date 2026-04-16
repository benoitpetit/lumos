-- Lumos Error Codes
-- Standardized error codes and definitions for the typed error system

local codes = {
    -- 0: Success
    SUCCESS = { code = 0, message = "Success" },

    -- 1-9: User errors (arguments)
    INVALID_ARGUMENT = {
        code = 1,
        message = "Invalid argument",
        user_facing = true,
        suggestion = "Check the command syntax"
    },
    MISSING_REQUIRED = {
        code = 2,
        message = "Missing required argument",
        user_facing = true,
        suggestion = "Provide the missing value"
    },
    INVALID_FLAG = {
        code = 3,
        message = "Invalid flag",
        user_facing = true
    },
    MUTEX_VIOLATION = {
        code = 4,
        message = "Mutually exclusive flags",
        user_facing = true,
        suggestion = "Use only one of the conflicting flags"
    },
    INVALID_TYPE = {
        code = 5,
        message = "Invalid value type",
        user_facing = true
    },
    OUT_OF_RANGE = {
        code = 6,
        message = "Value out of range",
        user_facing = true
    },
    INVALID_FORMAT = {
        code = 7,
        message = "Invalid format",
        user_facing = true
    },

    -- 10-19: Execution errors
    EXECUTION_FAILED = {
        code = 10,
        message = "Execution failed",
        retryable = true
    },
    PERMISSION_DENIED = {
        code = 11,
        message = "Permission denied",
        user_facing = true
    },
    RESOURCE_NOT_FOUND = {
        code = 12,
        message = "Resource not found",
        user_facing = true
    },
    TIMEOUT = {
        code = 13,
        message = "Timeout",
        retryable = true
    },
    RATE_LIMITED = {
        code = 14,
        message = "Too many requests",
        retryable = true,
        retry_after = true
    },

    -- 20-29: System errors
    IO_ERROR = { code = 20, message = "Input/output error" },
    NETWORK_ERROR = {
        code = 21,
        message = "Network error",
        retryable = true
    },
    CONFIG_ERROR = {
        code = 22,
        message = "Configuration error",
        user_facing = true
    },

    -- 30-39: Internal errors
    INTERNAL_ERROR = { code = 30, message = "Internal error" },
    NOT_IMPLEMENTED = { code = 31, message = "Feature not implemented" },

    -- 40+: Custom errors (reserved for users)
    CUSTOM = { code = 40, message = "Custom error" },
}

return codes
