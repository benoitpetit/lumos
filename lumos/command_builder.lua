-- Lumos Command Builder Module
-- Fluent API for building CLI commands and flags.

local command_builder = {}

-- Utility function to parse flag specifications
-- Supports: -s --long, --long -s, --long, -s
function command_builder.parse_flag_spec(spec)
    -- Try -s --long format
    local short, long = spec:match("^%-([a-zA-Z])%s+%-%-([a-zA-Z%-]+)$")
    if short and long then
        return short, long
    end

    -- Try --long -s format
    long, short = spec:match("^%-%-([a-zA-Z%-]+)%s+%-([a-zA-Z])$")
    if long and short then
        return short, long
    end

    -- Try --long only
    long = spec:match("^%-%-([a-zA-Z%-]+)$")
    if long then
        return nil, long
    end

    -- Try -s only
    short = spec:match("^%-([a-zA-Z])$")
    if short then
        return short, nil
    end

    return nil, nil
end

-- Internal helper to create flag definitions and reduce duplication
function command_builder.add_flag_to(target_table, spec, description, flag_type, options)
    local short, long = command_builder.parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    options = options or {}
    if flag_type == "enum" and (not options.choices or #options.choices == 0) then
        error("Enum flag requires a non-empty choices table")
    end
    -- Duplicate check
    if long and target_table[long] then
        error("Duplicate flag: --" .. long)
    end
    if short then
        for _, existing in pairs(target_table) do
            if existing.short == short then
                error("Duplicate short flag: -" .. short)
            end
        end
    end
    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = flag_type or "boolean"
    }
    for k, v in pairs(options) do
        flag[k] = v
    end
    local key = (long or short):gsub("-", "_")
    target_table[key] = flag
    return flag
end

-- Command class for fluent API
local Command = {}
Command.__index = Command

function Command:arg(name, description, options)
    self.args = self.args or {}
    options = options or {}
    local arg_def = {
        name = name,
        description = description,
        required = options.required or false,
        type = options.type or nil,
        min = options.min or nil,
        max = options.max or nil,
        default = options.default or nil,
        validate = options.validate or nil,
        variadic = options.variadic or false
    }
    table.insert(self.args, arg_def)
    self._last_arg = arg_def
    self._last_flag = nil
    return self
end

-- Add subcommand support to Command
function Command:subcommand(name, description)
    self.subcommands = self.subcommands or {}
    local subcmd = setmetatable({
        name = name,
        description = description,
        flags = {},
        args = {},
        parent = self
    }, Command)

    table.insert(self.subcommands, subcmd)
    return subcmd
end

function Command:flag(spec, description)
    self.flags = self.flags or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "boolean")
    return self
end

-- option() is an alias for flag_string()
function Command:option(spec, description)
    return self:flag_string(spec, description)
end

function Command:examples(example_list)
    self.examples = example_list
    return self
end

function Command:action(func)
    self.action = func
    return self
end

-- Add aliases support
function Command:alias(alias_name)
    self.aliases = self.aliases or {}
    table.insert(self.aliases, alias_name)
    return self
end

-- Add category support
function Command:category(name)
    self._category = name
    return self
end

function Command:hidden(value)
    self._hidden = value ~= false
    return self
end

-- Hook support
function Command:pre_run(fn)
    self.pre_runs = self.pre_runs or {}
    table.insert(self.pre_runs, fn)
    return self
end

function Command:post_run(fn)
    self.post_runs = self.post_runs or {}
    table.insert(self.post_runs, fn)
    return self
end

function Command:persistent_pre_run(fn)
    self.persistent_pre_runs = self.persistent_pre_runs or {}
    table.insert(self.persistent_pre_runs, fn)
    return self
end

function Command:persistent_post_run(fn)
    self.persistent_post_runs = self.persistent_post_runs or {}
    table.insert(self.persistent_post_runs, fn)
    return self
end

-- Fluent flag modifiers (operate on the most recently added flag)
function Command:default(value)
    if self._last_flag then self._last_flag.default = value end
    if self._last_arg then self._last_arg.default = value end
    return self
end

function Command:required(value)
    if self._last_flag then self._last_flag.required = value ~= false end
    if self._last_arg then self._last_arg.required = value ~= false end
    return self
end

function Command:env(var)
    if self._last_flag then self._last_flag.env = var end
    return self
end

function Command:validate(fn)
    if self._last_flag then self._last_flag.custom_validator = fn end
    if self._last_arg then self._last_arg.validate = fn end
    return self
end

function Command:hidden_flag(value)
    if self._last_flag then self._last_flag.hidden = value ~= false end
    return self
end

function Command:deprecated(message)
    if self._last_flag then
        self._last_flag.deprecated = true
        self._last_flag.deprecation_message = message or "This flag is deprecated"
    end
    return self
end

function Command:countable()
    if self._last_flag then
        self._last_flag.countable = true
    end
    return self
end

function Command:group(name)
    if self._last_flag then
        self._last_flag._group = name
    end
    return self
end

function Command:complete(choices)
    if self._last_flag then
        self._last_flag.completion_choices = choices
    end
    return self
end

function Command:plugin(plugin_fn, opts)
    local plugin_mod = require('lumos.plugin')
    plugin_mod.use(self, plugin_fn, opts)
    return self
end

-- Typed flag methods
function Command:flag_int(spec, description, min, max)
    self.flags = self.flags or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "int", {min = min, max = max})
    return self
end

function Command:flag_duration(spec, description, min, max)
    self.flags = self.flags or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "duration", {min = min, max = max})
    return self
end

function Command:flag_map(spec, description)
    self.flags = self.flags or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "map")
    return self
end

function Command:flag_string(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "string", {
        choices = options.choices,
        min_length = options.min_length,
        max_length = options.max_length,
        pattern = options.pattern
    })
    return self
end

function Command:flag_email(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "email", {
        pattern = options.pattern
    })
    return self
end

-- Persistent flag methods
function Command:persistent_flag(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "boolean", {persistent = true})
    return self
end

function Command:persistent_flag_string(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "string", {persistent = true})
    return self
end

function Command:persistent_flag_int(spec, description, min, max)
    self.persistent_flags = self.persistent_flags or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "int", {min = min, max = max, persistent = true})
    return self
end

function Command:persistent_flag_email(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "email", {
        persistent = true,
        pattern = options.pattern
    })
    return self
end

function Command:persistent_flag_url(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "url", {
        persistent = true,
        schemes = options.schemes,
        require_host = options.require_host,
        require_path = options.require_path,
        allow_localhost = options.allow_localhost
    })
    return self
end

function Command:persistent_flag_path(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "path", {
        persistent = true,
        must_exist = options.must_exist,
        allow_file = options.allow_file,
        allow_dir = options.allow_dir,
        extensions = options.extensions,
        resolve = options.resolve,
        absolute = options.absolute
    })
    return self
end

function Command:persistent_flag_float(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "float", {
        persistent = true,
        min = options.min, max = options.max, precision = options.precision
    })
    return self
end

function Command:persistent_flag_array(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "array", {
        persistent = true,
        separator = options.separator,
        item_type = options.item_type,
        min_items = options.min_items,
        max_items = options.max_items,
        unique = options.unique
    })
    return self
end

function Command:persistent_flag_enum(spec, description, choices, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.persistent_flags, spec, description, "enum", {
        persistent = true,
        choices = choices,
        case_sensitive = options.case_sensitive
    })
    return self
end

function Command:flag_url(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "url", {
        schemes = options.schemes,
        require_host = options.require_host,
        require_path = options.require_path,
        allow_localhost = options.allow_localhost
    })
    return self
end

function Command:flag_path(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "path", {
        must_exist = options.must_exist,
        allow_file = options.allow_file,
        allow_dir = options.allow_dir,
        extensions = options.extensions,
        resolve = options.resolve,
        absolute = options.absolute
    })
    return self
end

function Command:flag_float(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "float", {
        min = options.min,
        max = options.max,
        precision = options.precision
    })
    return self
end

function Command:flag_array(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "array", {
        separator = options.separator,
        item_type = options.item_type,
        min_items = options.min_items,
        max_items = options.max_items,
        unique = options.unique
    })
    return self
end

function Command:flag_enum(spec, description, choices, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = command_builder.add_flag_to(self.flags, spec, description, "enum", {
        choices = choices,
        case_sensitive = options.case_sensitive
    })
    return self
end

function Command:mutex_group(name, flags_list, options)
    self.mutex_groups = self.mutex_groups or {}
    local resolved_flags = {}
    for _, item in ipairs(flags_list or {}) do
        if type(item) == "string" then
            -- item is a flag name key in cmd.flags
            local flag_def = self.flags and self.flags[item]
            if flag_def then
                table.insert(resolved_flags, flag_def)
            end
        elseif type(item) == "table" and item.long then
            -- item is a flag definition table
            self.flags = self.flags or {}
            if not self.flags[item.long] then
                self.flags[item.long] = item
            end
            table.insert(resolved_flags, item)
        elseif type(item) == "table" and item._last_flag then
            -- item is likely the command itself returned by fluent API
            -- Use the most recently added flag at the time of call
            table.insert(resolved_flags, item._last_flag)
        end
    end
    self.mutex_groups[name] = {
        flags = resolved_flags,
        required = options and options.required or false
    }
    return self
end

function Command:use(middleware_fn, priority)
    self.middleware_chain = self.middleware_chain or {}
    table.insert(self.middleware_chain, {
        fn = middleware_fn,
        priority = priority or 100
    })
    -- Sort by priority
    table.sort(self.middleware_chain, function(a, b)
        return a.priority < b.priority
    end)
    return self
end

command_builder.Command = Command

return command_builder
