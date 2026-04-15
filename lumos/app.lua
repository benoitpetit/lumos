-- Lumos Application Module
local core = require('lumos.core')
local logger = require('lumos.logger')

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
    local short, long = parse_flag_spec(spec)

    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end

    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "boolean"
    }

    self.flags[long or short] = flag
    self._last_flag = flag
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

function Command:use(plugin_fn, opts)
    local plugin_mod = require('lumos.plugin')
    plugin_mod.use(self, plugin_fn, opts)
    return self
end

-- Add typed flag methods
function Command:flag_int(spec, description, min, max)
    self.flags = self.flags or {}
    local short, long = parse_flag_spec(spec)
    
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end

    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "int",
        min = min,
        max = max
    }

    self.flags[long or short] = flag
    self._last_flag = flag
    return self
end

function Command:flag_string(spec, description)
    self.flags = self.flags or {}
    local short, long = parse_flag_spec(spec)
    
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    
    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "string"
    }
    
    self.flags[long or short] = flag
    self._last_flag = flag
    return self
end

function Command:flag_email(spec, description)
    self.flags = self.flags or {}
    local short, long = parse_flag_spec(spec)
    
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    
    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "email"
    }
    
    self.flags[long or short] = flag
    self._last_flag = flag
    return self
end

-- Add persistent flag support (inherited by subcommands)
function Command:persistent_flag(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    local short, long = parse_flag_spec(spec)
    
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    
    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "boolean",
        persistent = true
    }
    
    self.persistent_flags[long or short] = flag
    self._last_flag = flag
    return self
end

function Command:persistent_flag_string(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    local short, long = parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    self.persistent_flags[long or short] = {
        short = short, long = long or short,
        description = description, type = "string", persistent = true
    }
    self._last_flag = self.persistent_flags[long or short]
    return self
end

function Command:persistent_flag_int(spec, description, min, max)
    self.persistent_flags = self.persistent_flags or {}
    local short, long = parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    self.persistent_flags[long or short] = {
        short = short, long = long or short,
        description = description, type = "int",
        min = min, max = max, persistent = true
    }
    self._last_flag = self.persistent_flags[long or short]
    return self
end

function Command:persistent_flag_email(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    local short, long = parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    self.persistent_flags[long or short] = {
        short = short, long = long or short,
        description = description, type = "email", persistent = true
    }
    self._last_flag = self.persistent_flags[long or short]
    return self
end

function Command:flag_url(spec, description)
    self.flags = self.flags or {}
    local short, long = parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    self.flags[long or short] = {
        short = short, long = long or short,
        description = description, type = "url"
    }
    self._last_flag = self.flags[long or short]
    return self
end

function Command:flag_path(spec, description)
    self.flags = self.flags or {}
    local short, long = parse_flag_spec(spec)
    if not long and not short then
        error("Invalid flag specification: " .. spec)
    end
    self.flags[long or short] = {
        short = short, long = long or short,
        description = description, type = "path"
    }
    self._last_flag = self.flags[long or short]
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
        env_prefix = config.env_prefix
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
        local short, long = parse_flag_spec(spec)
        
        if not long and not short then
            error("Invalid flag specification: " .. spec)
        end
        
        local flag = {
            short = short,
            long = long or short,
            description = description,
            type = "boolean",
            persistent = true
        }
        
        self.persistent_flags[long or short] = flag
        self._last_flag = flag
        return self
    end

    function app:persistent_flag_string(spec, description)
        self.persistent_flags = self.persistent_flags or {}
        local short, long = parse_flag_spec(spec)
        if not long and not short then error("Invalid flag specification: " .. spec) end
        self.persistent_flags[long or short] = {
            short = short, long = long or short,
            description = description, type = "string", persistent = true
        }
        self._last_flag = self.persistent_flags[long or short]
        return self
    end

    function app:persistent_flag_int(spec, description, min, max)
        self.persistent_flags = self.persistent_flags or {}
        local short, long = parse_flag_spec(spec)
        if not long and not short then error("Invalid flag specification: " .. spec) end
        self.persistent_flags[long or short] = {
            short = short, long = long or short,
            description = description, type = "int",
            min = min, max = max, persistent = true
        }
        self._last_flag = self.persistent_flags[long or short]
        return self
    end

    function app:persistent_flag_email(spec, description)
        self.persistent_flags = self.persistent_flags or {}
        local short, long = parse_flag_spec(spec)
        if not long and not short then error("Invalid flag specification: " .. spec) end
        self.persistent_flags[long or short] = {
            short = short, long = long or short,
            description = description, type = "email", persistent = true
        }
        self._last_flag = self.persistent_flags[long or short]
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
        local short, long = parse_flag_spec(spec)
        
        if not long and not short then
            error("Invalid flag specification: " .. spec)
        end

        local flag = {
            short = short,
            long = long or short,
            description = description,
            type = "boolean"
        }

        self.global_flags[long or short] = flag
        self._last_flag = flag
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
        
        -- Check for global JSON output flag
        if parsed.flags.json then
            parsed.output_json = true
        end

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
