-- Lumos Shell Completion Module
local completion = {}

-- Generate Bash completion script
function completion.generate_bash(app)
    local commands = {}
    local flags = {}
    
    -- Extract commands
    for _, cmd in ipairs(app.commands) do
        table.insert(commands, cmd.name)
        -- Add aliases
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(commands, alias)
            end
        end
    end
    
    -- Extract global flags
    if app.persistent_flags then
        for flag_name, flag_def in pairs(app.persistent_flags) do
            table.insert(flags, "--" .. flag_name)
            if flag_def.short then
                table.insert(flags, "-" .. flag_def.short)
            end
        end
    end
    
    -- Add default flags
    table.insert(flags, "--help")
    table.insert(flags, "-h")
    table.insert(flags, "--version")
    table.insert(flags, "-v")
    
    local bash_script = string.format([==[
_lumos_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Available commands
    local commands="%s"
    
    # Available flags
    local flags="%s"
    
    # Complete flags
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${flags}" -- ${cur}) )
        return 0
    fi
    
    # Complete commands
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        return 0
    fi
    
    # Command-specific completions can be added here
    return 0
}

complete -F _lumos_completions %s
]==], table.concat(commands, " "), table.concat(flags, " "), app.name)
    
    return bash_script
end

-- Generate Zsh completion script
function completion.generate_zsh(app)
    local commands = {}
    
    -- Extract commands with descriptions
    for _, cmd in ipairs(app.commands) do
        local desc = cmd.description or "No description"
        table.insert(commands, string.format("'%s:%s'", cmd.name, desc))
        
        -- Add aliases
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(commands, string.format("'%s:%s'", alias, desc))
            end
        end
    end
    
    local zsh_script = string.format([[
#compdef %s

_%s() {
    typeset -A opt_args
    local curcontext="$curcontext" state line
    
    _arguments -C \
        '(- 1 *)'{-h,--help}'[show help information]' \
        '(- 1 *)'{-v,--version}'[show version information]' \
        '1: :->command' \
        '*: :->args' && return 0
    
    case $state in
        command)
            local commands
            commands=(%s)
            _describe -t commands '%s commands' commands
            ;;
        args)
            local command="$words[2]"
            case $command in
                *)
                    _files
                    ;;
            esac
            ;;
    esac
}

_%s "$@"
]], app.name, app.name, table.concat(commands, "\n        "), app.name, app.name)
    
    return zsh_script
end

-- Generate Fish completion script
function completion.generate_fish(app)
    local commands = {}
    
    -- Extract commands with descriptions
    for _, cmd in ipairs(app.commands) do
        local desc = cmd.description or "No description"
        table.insert(commands, string.format("echo '%s\\t%s'", cmd.name, desc))
        
        -- Add aliases
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(commands, string.format("echo '%s\\t%s'", alias, desc))
            end
        end
    end
    
    local fish_script = string.format([[
# Fish completion for %s
function __%s_complete_commands
    %s
end

function __%s_complete_flags
    echo '--help\\tShow help information'
    echo '-h\\tShow help information'
    echo '--version\\tShow version information'
    echo '-v\\tShow version information'
end

# Complete commands
complete -c %s -f -n "not __fish_seen_subcommand_from (___%s_complete_commands)" -a "(__%s_complete_commands)"

# Complete global flags
complete -c %s -f -n "__fish_use_subcommand" -a "(__%s_complete_flags)"

# Complete help flag for any subcommand
complete -c %s -l help -s h -d "Show help information"
complete -c %s -l version -s v -d "Show version information"
]], app.name, app.name, table.concat(commands, "\n    "), app.name, app.name, app.name, app.name, app.name, app.name, app.name, app.name)
    
    return fish_script
end

-- Generate all completion scripts
function completion.generate_all(app, output_dir, verbose)
    output_dir = output_dir or "completion"
        if verbose == nil then verbose = true end  -- Default to true for backwards compatibility
        
        -- Create output directory if it doesn't exist
        os.execute("mkdir -p " .. output_dir)
        
        -- Generate Bash completion
        local bash_script = completion.generate_bash(app)
        local bash_file = io.open(output_dir .. "/" .. app.name .. "_bash.sh", "w")
        if bash_file then
            bash_file:write(bash_script)
            bash_file:close()
            -- Removed verbose print for cleaner test output
        end
        
        -- Generate Zsh completion
        local zsh_script = completion.generate_zsh(app)
        local zsh_file = io.open(output_dir .. "/" .. app.name .. "_zsh.sh", "w")
        if zsh_file then
            zsh_file:write(zsh_script)
            zsh_file:close()
            -- Removed verbose print for cleaner test output
        end
        
        -- Generate Fish completion
        local fish_script = completion.generate_fish(app)
        local fish_file = io.open(output_dir .. "/" .. app.name .. ".fish", "w")
        if fish_file then
            fish_file:write(fish_script)
            fish_file:close()
            -- Removed verbose print for cleaner test output
        end
end

return completion
