-- Lumos Shell Completion Module
local completion = {}
local security = require('lumos.security')
local logger = require('lumos.logger')

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
    local lines = {}
    local fn_name = "__" .. app.name .. "_complete_commands"

    -- Header
    table.insert(lines, "# Fish completion for " .. app.name)
    table.insert(lines, "")

    -- Helper function listing all commands with descriptions (tab-separated)
    table.insert(lines, "function " .. fn_name)
    for _, cmd in ipairs(app.commands) do
        local desc = cmd.description or ""
        table.insert(lines, string.format("    echo '%s\\t%s'", cmd.name, desc))
        -- Aliases
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(lines, string.format("    echo '%s\\t%s'", alias, desc))
            end
        end
    end
    table.insert(lines, "end")
    table.insert(lines, "")

    -- Top-level command completion
    table.insert(lines, string.format(
        "complete -c %s -f -a '(%s)'", app.name, fn_name))
    table.insert(lines, "")

    -- Global flags
    table.insert(lines, "# Global flags")
    table.insert(lines, string.format(
        "complete -c %s -l help -s h -d 'Show help information'", app.name))
    table.insert(lines, string.format(
        "complete -c %s -l version -s v -d 'Show version information'", app.name))

    -- Persistent flags
    if app.persistent_flags and next(app.persistent_flags) then
        for flag_name, flag_def in pairs(app.persistent_flags) do
            local desc = (flag_def.description or ""):gsub("'", "\\'")
            local line = string.format("complete -c %s -l %s", app.name, flag_name)
            if flag_def.short then
                line = line .. string.format(" -s %s", flag_def.short)
            end
            line = line .. string.format(" -d '%s'", desc)
            table.insert(lines, line)
        end
    end

    return table.concat(lines, "\n") .. "\n"
end

-- Generate all completion scripts
function completion.generate_all(app, output_dir, verbose)
    output_dir = output_dir or "./completion"
    if verbose == nil then verbose = true end
    
    -- Create output directory securely
    local success, err = security.safe_mkdir(output_dir)
    if not success then
        logger.error("Failed to create completion directory", {dir = output_dir, error = err})
        if verbose then
            print("Error: " .. (err or "Failed to create directory"))
        end
        return false
    end
    
    -- Generate Bash completion
    local bash_script = completion.generate_bash(app)
    local bash_file, bash_err = security.safe_open(output_dir .. "/" .. app.name .. "_bash.sh", "w")
    if bash_file then
        bash_file:write(bash_script)
        bash_file:close()
        if verbose then
            print("Generated Bash completion: " .. output_dir .. "/" .. app.name .. "_bash.sh")
        end
    else
        logger.error("Failed to create Bash completion file", {error = bash_err})
    end
    
    -- Generate Zsh completion
    local zsh_script = completion.generate_zsh(app)
    local zsh_file, zsh_err = security.safe_open(output_dir .. "/" .. app.name .. "_zsh.zsh", "w")
    if zsh_file then
        zsh_file:write(zsh_script)
        zsh_file:close()
        if verbose then
            print("Generated Zsh completion: " .. output_dir .. "/" .. app.name .. "_zsh.zsh")
        end
    else
        logger.error("Failed to create Zsh completion file", {error = zsh_err})
    end
    
    -- Generate Fish completion
    local fish_script = completion.generate_fish(app)
    local fish_file, fish_err = security.safe_open(output_dir .. "/" .. app.name .. ".fish", "w")
    if fish_file then
        fish_file:write(fish_script)
        fish_file:close()
        if verbose then
            print("Generated Fish completion: " .. output_dir .. "/" .. app.name .. ".fish")
        end
    else
        logger.error("Failed to create Fish completion file", {error = fish_err})
    end
    
    return true
end

return completion
