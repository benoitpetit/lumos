-- Lumos Application Module
local core = require('lumos.core')

local lumos = {}

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

function lumos.new_app(config)
    config = config or {}
    local app = {
        name = config.name or "myapp",
        version = config.version or "0.1.0",
        description = config.description or "A Lua CLI application",
        commands = {},
        global_flags = {}
    }

    function app:command(name, description)
        local cmd = setmetatable({
            name = name,
            description = description,
            flags = {},
            args = {}
        }, Command)
        
        table.insert(self.commands, cmd)
        return cmd
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

function app:run(args)
    args = args or {}
    
    -- Handle global flags first
    local parsed = core.parse_arguments(args)
    
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

    return app
end

return lumos
