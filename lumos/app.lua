-- Lumos Application Module
local core = require('lumos.core')
local command_builder = require('lumos.command_builder')
local Command = command_builder.Command
local add_flag_to = command_builder.add_flag_to

local lumos = {}

function lumos.new_app(config)
    config = config or {}
    local app = {
        name = config.name or "myapp",
        version = config.version or "0.1.0",
        description = config.description or "A Lua CLI application",
        commands = {},
        global_flags = {
            quiet = {short = "q", long = "quiet", description = "Suppress non-error output", type = "boolean"}
        },
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

    function app:countable()
        if self._last_flag then
            self._last_flag.countable = true
        end
        return self
    end

    function app:default(value)
        if self._last_flag then self._last_flag.default = value end
        return self
    end

    function app:required(value)
        if self._last_flag then self._last_flag.required = value ~= false end
        return self
    end

    function app:env(var)
        if self._last_flag then self._last_flag.env = var end
        return self
    end

    function app:validate(fn)
        if self._last_flag then self._last_flag.custom_validator = fn end
        return self
    end

    function app:hidden_flag(value)
        if self._last_flag then self._last_flag.hidden = value ~= false end
        return self
    end

    function app:deprecated(message)
        if self._last_flag then
            self._last_flag.deprecated = true
            self._last_flag.deprecation_message = message or "This flag is deprecated"
        end
        return self
    end

    function app:complete(choices)
        if self._last_flag then
            self._last_flag.completion_choices = choices
        end
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

        -- Quiet mode: suppress non-error output and set logger to ERROR
        if parsed.flags.quiet or parsed.flags.q then
            local logger = require('lumos.logger')
            logger.set_level("ERROR")
            parsed.quiet = true
        end

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

        -- Remove framework-level flags so they don't trigger unknown-flag errors
        parsed.flags.json = nil

        -- Identify the target command early so we can check its flags
        local cmd = core.find_command(self, parsed.command)

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
        if not user_claimed_v and cmd then
            for _, fdef in pairs(cmd.flags or {}) do
                if fdef.short == "v" then user_claimed_v = true; break end
            end
        end
        local version_triggered = parsed.flags.version or
            (not user_claimed_v and parsed.flags.v)
        if version_triggered then
            if parsed.quiet then
                return core.EXIT_OK
            end
            if parsed.output_json then
                print(json.encode({version = self.version, name = self.name}))
            else
                print(self.name .. " v" .. self.version)
            end
            return core.EXIT_OK
        end

        -- Check for global help
        if parsed.flags.help or parsed.flags.h then
            if parsed.quiet then
                return core.EXIT_OK
            end
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
        elseif shell == "powershell" then
            return completion.generate_powershell(self)
        elseif shell == "all" then
            return completion.generate_all(self, output_dir, verbose)
        else
            error("Unsupported shell: " .. (shell or "nil") .. ". Supported: bash, zsh, fish, powershell, all")
        end
    end

    function app:add_completion_command(config)
        config = config or {}
        local name = config.name or "completion"
        local desc = config.description or "Generate shell completion scripts"
        local shells = config.shells or {"bash", "zsh", "fish", "powershell"}

        local cmd = self:command(name, desc)
        cmd:arg("shell", "Shell type (" .. table.concat(shells, "|") .. ")")
        cmd:action(function(ctx)
            local shell = ctx.args[1] and ctx.args[1]:lower() or ""
            if shell == "" then
                print("Usage: " .. self.name .. " " .. name .. " <shell>")
                print("Supported shells: " .. table.concat(shells, ", "))
                return false
            end
            local ok, result = pcall(function()
                return self:generate_completion(shell)
            end)
            if ok and result then
                print(result)
                return true
            else
                print("Error: unsupported shell '" .. shell .. "'")
                return false
            end
        end)
        return self
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
