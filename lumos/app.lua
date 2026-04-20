-- Lumos Application Module
local core = require('lumos.core')

local lumos = {}

-- Utility function to parse flag specifications
local function parse_flag_spec(spec)
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
local function add_flag_to(target_table, spec, description, flag_type, options)
    local short, long = parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    options = options or {}
    if flag_type == "enum" and (not options.choices or #options.choices == 0) then
        error("Enum flag requires a non-empty choices table")
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
    target_table[long or short] = flag
    return flag
end

-- Command class for fluent API
local Command = {}
Command.__index = Command

function Command:arg(name, description, options)
    self.args = self.args or {}
    table.insert(self.args, {
        name = name,
        description = description,
        required = options and options.required or false,
        type = options and options.type or nil,
        min = options and options.min or nil,
        max = options and options.max or nil,
        default = options and options.default or nil,
        validate = options and options.validate or nil
    })
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
    self._last_flag = add_flag_to(self.flags, spec, description, "boolean")
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

-- Fluent flag modifiers (operate on the most recently added flag)
function Command:default(value)
    if self._last_flag then self._last_flag.default = value end
    return self
end

function Command:required(value)
    if self._last_flag then self._last_flag.required = value ~= false end
    return self
end

function Command:env(var)
    if self._last_flag then self._last_flag.env = var end
    return self
end

function Command:validate(fn)
    if self._last_flag then self._last_flag.custom_validator = fn end
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

function Command:plugin(plugin_fn, opts)
    local plugin_mod = require('lumos.plugin')
    plugin_mod.use(self, plugin_fn, opts)
    return self
end

-- Typed flag methods
function Command:flag_int(spec, description, min, max)
    self.flags = self.flags or {}
    self._last_flag = add_flag_to(self.flags, spec, description, "int", {min = min, max = max})
    return self
end

function Command:flag_string(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = add_flag_to(self.flags, spec, description, "string", {
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
    self._last_flag = add_flag_to(self.flags, spec, description, "email", {
        pattern = options.pattern
    })
    return self
end

-- Persistent flag methods
function Command:persistent_flag(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "boolean", {persistent = true})
    return self
end

function Command:persistent_flag_string(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "string", {persistent = true})
    return self
end

function Command:persistent_flag_int(spec, description, min, max)
    self.persistent_flags = self.persistent_flags or {}
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "int", {min = min, max = max, persistent = true})
    return self
end

function Command:persistent_flag_email(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "email", {
        persistent = true,
        pattern = options.pattern
    })
    return self
end

function Command:persistent_flag_url(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "url", {
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
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "path", {
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
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "float", {
        persistent = true,
        min = options.min, max = options.max, precision = options.precision
    })
    return self
end

function Command:persistent_flag_array(spec, description, options)
    self.persistent_flags = self.persistent_flags or {}
    options = options or {}
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "array", {
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
    self._last_flag = add_flag_to(self.persistent_flags, spec, description, "enum", {
        persistent = true,
        choices = choices,
        case_sensitive = options.case_sensitive
    })
    return self
end

function Command:flag_url(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = add_flag_to(self.flags, spec, description, "url", {
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
    self._last_flag = add_flag_to(self.flags, spec, description, "path", {
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
    self._last_flag = add_flag_to(self.flags, spec, description, "float", {
        min = options.min,
        max = options.max,
        precision = options.precision
    })
    return self
end

function Command:flag_array(spec, description, options)
    self.flags = self.flags or {}
    options = options or {}
    self._last_flag = add_flag_to(self.flags, spec, description, "array", {
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
    self._last_flag = add_flag_to(self.flags, spec, description, "enum", {
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

function lumos.new_app(config)
    config = config or {}
    local app = {
        name = config.name or "myapp",
        version = config.version or "0.1.0",
        description = config.description or "A Lua CLI application",
        commands = {},
        global_flags = {},
        persistent_flags = {},
        config_file = config.config_file,
        env_prefix = config.env_prefix,
        no_args_is_help = config.no_args_is_help
    }

    function app:command(name, description)
        local cmd = setmetatable({
            name = name,
            description = description,
            flags = {},
            args = {},
            aliases = {},
            persistent_flags = {}
        }, Command)

        table.insert(self.commands, cmd)
        return cmd
    end

    -- Add persistent flag support at app level
    function app:persistent_flag(spec, description)
        self.persistent_flags = self.persistent_flags or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "boolean", {persistent = true})
        return self
    end

    function app:persistent_flag_string(spec, description)
        self.persistent_flags = self.persistent_flags or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "string", {persistent = true})
        return self
    end

    function app:persistent_flag_int(spec, description, min, max)
        self.persistent_flags = self.persistent_flags or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "int", {min = min, max = max, persistent = true})
        return self
    end

    function app:persistent_flag_email(spec, description, options)
        self.persistent_flags = self.persistent_flags or {}
        options = options or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "email", {persistent = true, pattern = options.pattern})
        return self
    end

    function app:persistent_flag_url(spec, description, options)
        self.persistent_flags = self.persistent_flags or {}
        options = options or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "url", {
            persistent = true,
            schemes = options.schemes,
            require_host = options.require_host,
            require_path = options.require_path,
            allow_localhost = options.allow_localhost
        })
        return self
    end

    function app:persistent_flag_path(spec, description, options)
        self.persistent_flags = self.persistent_flags or {}
        options = options or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "path", {
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

    function app:persistent_flag_float(spec, description, options)
        self.persistent_flags = self.persistent_flags or {}
        options = options or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "float", {
            persistent = true,
            min = options.min, max = options.max, precision = options.precision
        })
        return self
    end

    function app:persistent_flag_array(spec, description, options)
        self.persistent_flags = self.persistent_flags or {}
        options = options or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "array", {
            persistent = true,
            separator = options.separator,
            item_type = options.item_type,
            min_items = options.min_items,
            max_items = options.max_items,
            unique = options.unique
        })
        return self
    end

    function app:persistent_flag_enum(spec, description, choices, options)
        self.persistent_flags = self.persistent_flags or {}
        options = options or {}
        self._last_flag = add_flag_to(self.persistent_flags, spec, description, "enum", {
            persistent = true,
            choices = choices,
            case_sensitive = options.case_sensitive
        })
        return self
    end

    function app:use(middleware_fn, priority)
        self.middleware_chain = self.middleware_chain or {}
        table.insert(self.middleware_chain, {
            fn = middleware_fn,
            priority = priority or 100
        })
        table.sort(self.middleware_chain, function(a, b)
            return a.priority < b.priority
        end)
        return self
    end

    -- App-level hooks
    function app:persistent_pre_run(fn)
        self.persistent_pre_runs = self.persistent_pre_runs or {}
        table.insert(self.persistent_pre_runs, fn)
        return self
    end

    function app:persistent_post_run(fn)
        self.persistent_post_runs = self.persistent_post_runs or {}
        table.insert(self.persistent_post_runs, fn)
        return self
    end

    function app:flag(spec, description)
        self._last_flag = add_flag_to(self.global_flags, spec, description, "boolean")
        return self
    end

    local json = require('lumos.json')
    local config_module = require('lumos.config')
    local completion = require('lumos.completion')
    local manpage = require('lumos.manpage')
    local markdown = require('lumos.markdown')

    function app:run(args)
        args = args or {}

        -- Auto-load configuration file if configured
        if self.config_file then
            local file_cfg, _ = config_module.load_file(self.config_file)
            if file_cfg then
                self.loaded_config = file_cfg
            end
        end

        -- Auto-load environment variables if a prefix is configured
        if self.env_prefix then
            self.loaded_env = config_module.load_env(self.env_prefix)
        end

        -- Handle global flags first
        local parsed = core.parse_arguments(args, self)

        -- Check for global output format
        parsed.output_format = "table"
        if parsed.flags.format then
            local fmt = tostring(parsed.flags.format):lower()
            if fmt == "json" or fmt == "table" or fmt == "yaml" then
                parsed.output_format = fmt
            end
        elseif parsed.flags.json then
            parsed.output_format = "json"
        end
        parsed.output_json = (parsed.output_format == "json")

        -- Check for version flag.
        -- Only treat bare -v as --version if the user has NOT already defined a
        -- -v short flag (e.g. --verbose -v).  --version is always honoured.
        local user_claimed_v = false
        for _, fdef in pairs(self.persistent_flags or {}) do
            if fdef.short == "v" then user_claimed_v = true; break end
        end
        if not user_claimed_v then
            for _, fdef in pairs(self.global_flags or {}) do
                if fdef.short == "v" then user_claimed_v = true; break end
            end
        end
        local version_triggered = parsed.flags.version or
            (not user_claimed_v and parsed.flags.v)
        if version_triggered then
            if parsed.output_json then
                print(json.encode({version = self.version, name = self.name}))
            else
                print(self.name .. " v" .. self.version)
            end
            return core.EXIT_OK
        end

        -- Check for global help
        if parsed.flags.help or parsed.flags.h then
            if parsed.output_json then
                -- Serialize only command names to avoid circular reference crashes
                local cmd_names = {}
                for _, cmd in ipairs(self.commands) do
                    table.insert(cmd_names, cmd.name)
                end
                print(json.encode({commands = cmd_names, flags = parsed.flags}))
            else
                if not parsed.command then
                    core.show_help(self)
                    return core.EXIT_OK
                end
            end
        end

        -- Execute command
        return core.execute_command(self, parsed)
    end

    function app:generate_completion(shell, output_dir, verbose)
        if shell == "bash" then
            return completion.generate_bash(self)
        elseif shell == "zsh" then
            return completion.generate_zsh(self)
        elseif shell == "fish" then
            return completion.generate_fish(self)
        elseif shell == "all" then
            completion.generate_all(self, output_dir, verbose)
            return nil
        else
            error("Unsupported shell: " .. (shell or "nil") .. ". Supported: bash, zsh, fish, all")
        end
    end

    function app:generate_manpage(command, output_dir)
        if command then
            local cmd = core.find_command(self, command)
            if not cmd then
                error("Command not found: " .. command)
            end
            return manpage.generate_command(self, cmd)
        else
            if output_dir then
                manpage.generate_all(self, output_dir)
                return nil
            else
                return manpage.generate_main(self)
            end
        end
    end

    function app:generate_docs(format, output_dir, verbose)
        format = format or "markdown"
        if format == "markdown" then
            if output_dir then
                markdown.generate_all(self, output_dir, verbose)
                return nil
            else
                return markdown.generate_main(self)
            end
        else
            error("Unsupported documentation format: " .. format .. ". Supported: markdown")
        end
    end

    return app
end

return lumos
