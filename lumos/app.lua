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

function Command:arg(name, description)
    self.args = self.args or {}
    table.insert(self.args, {name = name, description = description})
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

    -- Handle the case where we couldn't parse anything
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
    return self
end

function Command:option(spec, description)
    self.flags = self.flags or {}
    local short, long = spec:match("^%-([a-zA-Z])%s+%-%-([a-zA-Z%-]+)$")
    if not short then
        long = spec:match("^%-%-([a-zA-Z%-]+)$")
    end
    if not long then
        short = spec:match("^%-([a-zA-Z])$")
    end
    
    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "string"
    }
    
    self.flags[long or short] = flag
    return self
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
    return self
end

-- Add persistent flag support (inherited by subcommands)
function Command:persistent_flag(spec, description)
    self.persistent_flags = self.persistent_flags or {}
    local short, long = spec:match("^%-([a-zA-Z])%s+%-%-([a-zA-Z%-]+)$")
    if not short then
        long = spec:match("^%-%-([a-zA-Z%-]+)$")
    end
    if not long then
        short = spec:match("^%-([a-zA-Z])$")
    end
    
    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "boolean",
        persistent = true
    }
    
    self.persistent_flags[long or short] = flag
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
        
        local flag = {
            short = short,
            long = long or short,
            description = description,
            type = "boolean",
            persistent = true
        }
        
        if not long and not short then
            error("Invalid flag specification: " .. spec)
        end
        self.persistent_flags[long or short] = flag
        return self
    end

function app:flag(spec, description)
    local short, long = spec:match("^%-([a-zA-Z])%s+%-%-([a-zA-Z%-]+)$")
    if not short then
        long = spec:match("^%-%-([a-zA-Z%-]+)$")
    end
    if not long then
        short = spec:match("^%-([a-zA-Z])$")
    end

    local flag = {
        short = short,
        long = long or short,
        description = description,
        type = "boolean"
    }

    self.global_flags[long or short] = flag
    return self
end

local json = require('lumos.json')
local config = require('lumos.config')
local completion = require('lumos.completion')
local manpage = require('lumos.manpage')
local markdown = require('lumos.markdown')

function app:run(args)
    args = args or {}
    
    -- Handle global flags first
    local parsed = core.parse_arguments(args, self)
    
    -- Check for global JSON output flag
    if parsed.flags.json then
        parsed.output_json = true
    end

    -- Check for version flag
    if parsed.flags.version or parsed.flags.v then
        if parsed.output_json then
            print(json.encode({version = self.version, name = self.name}))
        else
            print(self.name .. " v" .. self.version)
        end
        return true
    end
    
    -- Check for global help
    if parsed.flags.help or parsed.flags.h then
        if parsed.output_json then
            print(json.encode({commands = self.commands, flags = parsed.flags}))
        else
            if not parsed.command then 
                core.show_help(self)
                return true
            end
        end
    end
    
    -- Execute command
    return core.execute_command(self, parsed)
end

    -- Phase 3: Shell Integration methods
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
