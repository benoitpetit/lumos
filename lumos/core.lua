-- Lumos Core Module (Facade)
-- Delegates to specialized sub-modules for parsing, validation, execution, and help rendering.

local core = {}

-- Exit code constants
 core.EXIT_OK = 0
 core.EXIT_ERROR = 1
 core.EXIT_USAGE = 2

-- Sub-modules
local parser = require("lumos.parser")
local validator = require("lumos.validator")
local executor = require("lumos.executor")
local help_renderer = require("lumos.help_renderer")

-- Configuration file loader — delegates to config module to avoid duplication
function core.load_config(file_path)
    return require("lumos.config").load_file(file_path)
end

-- Parsing functions
function core.suggest_command(...) return parser.suggest_command(...) end
function core.suggest_flag(...) return parser.suggest_flag(...) end
function core.parse_arguments(...) return parser.parse_arguments(...) end
function core.find_command(...) return parser.find_command(...) end
function core.find_subcommand(...) return parser.find_subcommand(...) end

-- Validation functions
function core.validate_args(...) return validator.validate_args(...) end
function core.validate_and_merge_flags(...) return validator.validate_and_merge_flags(...) end

-- Execution functions
function core.execute_action(...) return executor.execute_action(...) end
function core.execute_command(...) return executor.execute_command(...) end

-- Help rendering functions
function core.show_help(...) return help_renderer.show_help(...) end
function core.show_command_help(...) return help_renderer.show_command_help(...) end

return core
