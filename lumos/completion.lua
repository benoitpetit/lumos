-- Lumos Shell Completion Module
-- Supports: bash, zsh, fish, powershell
-- Features: commands, subcommands, aliases, flags (global, persistent, command-specific),
--           hidden filtering, enum value completion, custom completions.
local completion = {}
local security = require('lumos.security')
local logger = require('lumos.logger')
local app_utils = require('lumos.app_utils')

-- ========================================================================
-- Internal helpers
-- ========================================================================

local function collect_visible_commands(commands)
    local result = {}
    for _, cmd in ipairs(commands or {}) do
        if not cmd._hidden then
            table.insert(result, cmd)
        end
    end
    return result
end

local function collect_visible_flags(flags_table)
    local result = {}
    for _, flag in pairs(flags_table or {}) do
        if not flag.hidden then
            table.insert(result, flag)
        end
    end
    return result
end

local function get_flag_choices(flag)
    if flag.completion_choices then
        if type(flag.completion_choices) == "table" then
            return flag.completion_choices
        elseif type(flag.completion_choices) == "function" then
            local ok, result = pcall(flag.completion_choices)
            if ok and type(result) == "table" then
                return result
            end
        end
    end
    if flag.choices then
        return flag.choices
    end
    return nil
end

local function escape_for_shell(text, shell)
    if not text then return "" end
    if shell == "fish" then
        return text:gsub("'", "\\'")
    elseif shell == "powershell" then
        return text:gsub("'", "''")
    else
        -- bash / zsh
        return text:gsub("'", "'\\''")
    end
end

local function flag_to_optname(flag)
    if flag.long then
        return "--" .. flag.long
    elseif flag.short then
        return "-" .. flag.short
    end
    return nil
end

local function flag_optnames(flag)
    local names = {}
    if flag.long then
        table.insert(names, "--" .. flag.long)
    end
    if flag.short then
        table.insert(names, "-" .. flag.short)
    end
    return names
end

-- ========================================================================
-- Bash
-- ========================================================================

function completion.generate_bash(app)
    local visible_cmds = collect_visible_commands(app.commands)
    local global_flags = collect_visible_flags(app.global_flags)
    local persistent_flags = collect_visible_flags(app.persistent_flags)
    local safe_name = (app.name or "app"):gsub("[^%w]", "_")

    -- Build top-level command list
    local command_words = {}
    for _, cmd in ipairs(visible_cmds) do
        table.insert(command_words, cmd.name)
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(command_words, alias)
            end
        end
    end

    -- Build default flags
    local default_flags = {"--help", "-h", "--version"}
    if app_utils.version_short_available(app) then
        table.insert(default_flags, "-v")
    end

    -- Build global flag list (for all contexts)
    local global_flag_words = {}
    for _, flag in ipairs(global_flags) do
        for _, name in ipairs(flag_optnames(flag)) do
            table.insert(global_flag_words, name)
        end
    end
    for _, flag in ipairs(persistent_flags) do
        for _, name in ipairs(flag_optnames(flag)) do
            table.insert(global_flag_words, name)
        end
    end

    -- Collect per-command flags, subcommands, and enum value completions
    local cmd_flag_lines = {}
    local cmd_subcmd_lines = {}
    local enum_lines = {}

    -- App-level enum values
    for _, flag in ipairs(global_flags) do
        local choices = get_flag_choices(flag)
        if choices then
            for _, name in ipairs(flag_optnames(flag)) do
                table.insert(enum_lines, string.format(
                    "        %s) COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") ); return 0 ;;",
                    name,
                    table.concat(choices, " ")
                ))
            end
        end
    end
    for _, flag in ipairs(persistent_flags) do
        local choices = get_flag_choices(flag)
        if choices then
            for _, name in ipairs(flag_optnames(flag)) do
                table.insert(enum_lines, string.format(
                    "        %s) COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") ); return 0 ;;",
                    name,
                    table.concat(choices, " ")
                ))
            end
        end
    end

    for _, cmd in ipairs(visible_cmds) do
        local cmd_flags = collect_visible_flags(cmd.flags)
        local cmd_persistent = collect_visible_flags(cmd.persistent_flags)
        local all_cmd_flags = {}
        for _, flag in ipairs(cmd_flags) do
            for _, name in ipairs(flag_optnames(flag)) do
                table.insert(all_cmd_flags, name)
            end
            local choices = get_flag_choices(flag)
            if choices then
                for _, n in ipairs(flag_optnames(flag)) do
                    table.insert(enum_lines, string.format(
                        "        %s) COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") ); return 0 ;;",
                        n,
                        table.concat(choices, " ")
                    ))
                end
            end
        end
        for _, flag in ipairs(cmd_persistent) do
            for _, name in ipairs(flag_optnames(flag)) do
                table.insert(all_cmd_flags, name)
            end
            local choices = get_flag_choices(flag)
            if choices then
                for _, n in ipairs(flag_optnames(flag)) do
                    table.insert(enum_lines, string.format(
                        "        %s) COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") ); return 0 ;;",
                        n,
                        table.concat(choices, " ")
                    ))
                end
            end
        end

        if #all_cmd_flags > 0 then
            table.insert(cmd_flag_lines, string.format(
                "            %s) flags=\"$flags %s\" ;;",
                cmd.name,
                table.concat(all_cmd_flags, " ")
            ))
            if cmd.aliases then
                for _, alias in ipairs(cmd.aliases) do
                    table.insert(cmd_flag_lines, string.format(
                        "            %s) flags=\"$flags %s\" ;;",
                        alias,
                        table.concat(all_cmd_flags, " ")
                    ))
                end
            end
        end

        if cmd.subcommands and #cmd.subcommands > 0 then
            local subcmd_words = {}
            for _, sub in ipairs(cmd.subcommands) do
                if not sub._hidden then
                    table.insert(subcmd_words, sub.name)
                end
            end
            if #subcmd_words > 0 then
                table.insert(cmd_subcmd_lines, string.format(
                    "            %s)\n                if [[ $COMP_CWORD -eq $((cmd_idx+1)) ]]; then\n                    COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") )\n                fi\n                return 0\n                ;;",
                    cmd.name,
                    table.concat(subcmd_words, " ")
                ))
                if cmd.aliases then
                    for _, alias in ipairs(cmd.aliases) do
                        table.insert(cmd_subcmd_lines, string.format(
                            "            %s)\n                if [[ $COMP_CWORD -eq $((cmd_idx+1)) ]]; then\n                    COMPREPLY=( $(compgen -W \"%s\" -- \"$cur\") )\n                fi\n                return 0\n                ;;",
                            alias,
                            table.concat(subcmd_words, " ")
                        ))
                    end
                end
            end
        end
    end

    local enum_section = ""
    if #enum_lines > 0 then
        enum_section = "    case \"$prev\" in\n" .. table.concat(enum_lines, "\n") .. "\n    esac\n"
    end

    local cmd_flag_section = ""
    if #cmd_flag_lines > 0 then
        cmd_flag_section = "            case \"$found_cmd\" in\n" .. table.concat(cmd_flag_lines, "\n") .. "\n            esac\n"
    end

    local cmd_subcmd_section = ""
    if #cmd_subcmd_lines > 0 then
        cmd_subcmd_section = "            case \"$found_cmd\" in\n" .. table.concat(cmd_subcmd_lines, "\n") .. "\n            esac\n"
    end

    local bash_script = string.format([==[
_%s_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local found_cmd=""
    local cmd_idx=1

    for ((i=1; i<COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in
%s
            -*) ;;
        esac
    done

%s    if [[ $cur == -* ]]; then
        local flags="%s"
%s        COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
        return 0
    fi

%s    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "%s" -- "$cur") )
        return 0
    fi

    return 0
}

complete -F _%s_completions %s
]==],
        safe_name,
        (function()
            local detect_lines = {}
            for _, cmd in ipairs(visible_cmds) do
                local patterns = {cmd.name}
                if cmd.aliases then
                    for _, alias in ipairs(cmd.aliases) do
                        table.insert(patterns, alias)
                    end
                end
                table.insert(detect_lines, string.format(
                    "            %s) found_cmd=\"%s\"; cmd_idx=$i ;;",
                    table.concat(patterns, "|"),
                    cmd.name
                ))
            end
            return table.concat(detect_lines, "\n")
        end)(),
        enum_section,
        table.concat(default_flags, " ") .. " " .. table.concat(global_flag_words, " "),
        cmd_flag_section,
        cmd_subcmd_section,
        table.concat(command_words, " "),
        safe_name,
        app.name
    )

    return bash_script
end

-- ========================================================================
-- Zsh
-- ========================================================================

function completion.generate_zsh(app)
    local visible_cmds = collect_visible_commands(app.commands)
    local global_flags = collect_visible_flags(app.global_flags)
    local persistent_flags = collect_visible_flags(app.persistent_flags)

    -- Build root-level options for _arguments
    local root_options = {}
    table.insert(root_options, "        '(- 1 *)'{-h,--help}'[show help information]' \\")
    if app_utils.version_short_available(app) then
        table.insert(root_options, "        '(- 1 *)'{-v,--version}'[show version information]' \\")
    else
        table.insert(root_options, "        '(- 1 *)'--version'[show version information]' \\")
    end

    local function build_zsh_opt(flag)
        local opt = "        '"
        local names = {}
        if flag.short then table.insert(names, "-" .. flag.short) end
        if flag.long then table.insert(names, "--" .. flag.long) end
        opt = opt .. table.concat(names, ",") .. "'"
        opt = opt .. "[" .. escape_for_shell(flag.description or "", "zsh") .. "]"
        local choices = get_flag_choices(flag)
        if choices then
            opt = opt .. ":" .. (flag.long or flag.short) .. ":(" .. table.concat(choices, " ") .. ")"
        elseif flag.type == "path" then
            opt = opt .. ":file:_files"
        elseif flag.type == "int" or flag.type == "float" or flag.type == "number" then
            opt = opt .. ":number:"
        else
            opt = opt .. ":value:"
        end
        opt = opt .. "' \\"
        return opt
    end

    for _, flag in ipairs(global_flags) do
        table.insert(root_options, build_zsh_opt(flag))
    end
    for _, flag in ipairs(persistent_flags) do
        table.insert(root_options, build_zsh_opt(flag))
    end

    -- Build command list
    local command_items = {}
    for _, cmd in ipairs(visible_cmds) do
        table.insert(command_items, string.format("'%s:%s'", cmd.name, escape_for_shell(cmd.description or "No description", "zsh")))
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(command_items, string.format("'%s:%s'", alias, escape_for_shell(cmd.description or "No description", "zsh")))
            end
        end
    end

    -- Build per-command args cases
    local args_cases = {}
    for _, cmd in ipairs(visible_cmds) do
        local cmd_flags = collect_visible_flags(cmd.flags)
        local cmd_persistent = collect_visible_flags(cmd.persistent_flags)
        local has_flags = #cmd_flags > 0 or #cmd_persistent > 0
        local has_subcommands = cmd.subcommands and #cmd.subcommands > 0

        local lines = {}
        table.insert(lines, string.format("        %s)", cmd.name))
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(lines, string.format("        %s)", alias))
            end
        end

        if has_flags then
            table.insert(lines, "            _arguments -C \\")
            for _, flag in ipairs(cmd_flags) do
                local names = {}
                if flag.short then table.insert(names, "-" .. flag.short) end
                if flag.long then table.insert(names, "--" .. flag.long) end
                local opt = string.format("                '%s[%s]",
                    table.concat(names, ","),
                    escape_for_shell(flag.description or "", "zsh"))
                local choices = get_flag_choices(flag)
                if choices then
                    opt = opt .. ":" .. (flag.long or flag.short) .. ":(" .. table.concat(choices, " ") .. ")"
                elseif flag.type == "path" then
                    opt = opt .. ":file:_files"
                elseif flag.type == "int" or flag.type == "float" or flag.type == "number" then
                    opt = opt .. ":number:"
                else
                    opt = opt .. ":value:"
                end
                opt = opt .. "' \\"
                table.insert(lines, opt)
            end
            for _, flag in ipairs(cmd_persistent) do
                local names = {}
                if flag.short then table.insert(names, "-" .. flag.short) end
                if flag.long then table.insert(names, "--" .. flag.long) end
                local opt = string.format("                '%s[%s]",
                    table.concat(names, ","),
                    escape_for_shell(flag.description or "", "zsh"))
                local choices = get_flag_choices(flag)
                if choices then
                    opt = opt .. ":" .. (flag.long or flag.short) .. ":(" .. table.concat(choices, " ") .. ")"
                elseif flag.type == "path" then
                    opt = opt .. ":file:_files"
                elseif flag.type == "int" or flag.type == "float" or flag.type == "number" then
                    opt = opt .. ":number:"
                else
                    opt = opt .. ":value:"
                end
                opt = opt .. "' \\"
                table.insert(lines, opt)
            end
            if has_subcommands then
                table.insert(lines, "                '1: :->subcmd' && return 0")
            else
                table.insert(lines, "                '*: :->args' && return 0")
            end
            table.insert(lines, "            case $state in")
            if has_subcommands then
                table.insert(lines, "                subcmd)")
                table.insert(lines, "                    local subcommands")
                local sub_items = {}
                for _, sub in ipairs(cmd.subcommands) do
                    if not sub._hidden then
                        table.insert(sub_items, string.format("'%s:%s'", sub.name, escape_for_shell(sub.description or "", "zsh")))
                    end
                end
                table.insert(lines, "                    subcommands=(" .. table.concat(sub_items, " ") .. ")")
                table.insert(lines, "                    _describe -t subcommands '" .. cmd.name .. " subcommands' subcommands")
                table.insert(lines, "                    ;;")
            end
            table.insert(lines, "                args)")
            table.insert(lines, "                    _files")
            table.insert(lines, "                    ;;")
            table.insert(lines, "            esac")
        elseif has_subcommands then
            table.insert(lines, "            local subcommands")
            local sub_items = {}
            for _, sub in ipairs(cmd.subcommands) do
                if not sub._hidden then
                    table.insert(sub_items, string.format("'%s:%s'", sub.name, escape_for_shell(sub.description or "", "zsh")))
                end
            end
            table.insert(lines, "            subcommands=(" .. table.concat(sub_items, " ") .. ")")
            table.insert(lines, "            _describe -t subcommands '" .. cmd.name .. " subcommands' subcommands")
        else
            table.insert(lines, "            _files")
        end
        table.insert(lines, "            ;;")
        table.insert(args_cases, table.concat(lines, "\n"))
    end

    local zsh_script = string.format([[
#compdef %s

_%s() {
    typeset -A opt_args
    local curcontext="$curcontext" state line

    _arguments -C \
%s        '1: :->command' \
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
%s            *)
                _files
                ;;
            esac
            ;;
    esac
}

_%s "$@"
]],
        app.name,
        app.name,
        table.concat(root_options, "\n") .. "\n",
        table.concat(command_items, "\n        "),
        app.name,
        #args_cases > 0 and ("                " .. table.concat(args_cases, "\n                ") .. "\n") or "",
        app.name
    )

    return zsh_script
end

-- ========================================================================
-- Fish
-- ========================================================================

function completion.generate_fish(app)
    local lines = {}
    local visible_cmds = collect_visible_commands(app.commands)
    local global_flags = collect_visible_flags(app.global_flags)
    local persistent_flags = collect_visible_flags(app.persistent_flags)

    table.insert(lines, "# Fish completion for " .. app.name)
    table.insert(lines, "")

    -- Command completion function
    local fn_name = "__" .. app.name .. "_complete_commands"
    table.insert(lines, "function " .. fn_name)
    for _, cmd in ipairs(visible_cmds) do
        table.insert(lines, string.format("    echo '%s\\t%s'",
            cmd.name,
            escape_for_shell(cmd.description or "", "fish")))
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(lines, string.format("    echo '%s\\t%s'",
                    alias,
                    escape_for_shell(cmd.description or "", "fish")))
            end
        end
    end
    table.insert(lines, "end")
    table.insert(lines, "")

    -- Top-level commands
    table.insert(lines, string.format(
        "complete -c %s -f -n '__fish_use_subcommand' -a '(%s)'",
        app.name, fn_name))
    table.insert(lines, "")

    -- Default/global flags at root level
    table.insert(lines, string.format(
        "complete -c %s -n '__fish_use_subcommand' -l help -s h -d 'Show help information'",
        app.name))
    if app_utils.version_short_available(app) then
        table.insert(lines, string.format(
            "complete -c %s -n '__fish_use_subcommand' -l version -s v -d 'Show version information'",
            app.name))
    else
        table.insert(lines, string.format(
            "complete -c %s -n '__fish_use_subcommand' -l version -d 'Show version information'",
            app.name))
    end

    for _, flag in ipairs(global_flags) do
        local line = string.format("complete -c %s -n '__fish_use_subcommand' -l %s",
            app.name, flag.long or flag.short)
        if flag.short then
            line = line .. string.format(" -s %s", flag.short)
        end
        line = line .. string.format(" -d '%s'", escape_for_shell(flag.description or "", "fish"))
        local choices = get_flag_choices(flag)
        if choices then
            line = line .. " -a '" .. table.concat(choices, " ") .. "'"
        end
        table.insert(lines, line)
    end
    for _, flag in ipairs(persistent_flags) do
        local line = string.format("complete -c %s -n '__fish_use_subcommand' -l %s",
            app.name, flag.long or flag.short)
        if flag.short then
            line = line .. string.format(" -s %s", flag.short)
        end
        line = line .. string.format(" -d '%s'", escape_for_shell(flag.description or "", "fish"))
        local choices = get_flag_choices(flag)
        if choices then
            line = line .. " -a '" .. table.concat(choices, " ") .. "'"
        end
        table.insert(lines, line)
    end
    table.insert(lines, "")

    -- Per-command completions
    for _, cmd in ipairs(visible_cmds) do
        local cmd_names = {cmd.name}
        if cmd.aliases then
            for _, alias in ipairs(cmd.aliases) do
                table.insert(cmd_names, alias)
            end
        end
        local cond = "__fish_seen_subcommand_from " .. table.concat(cmd_names, " ")

        -- Command-specific flags
        local cmd_flags = collect_visible_flags(cmd.flags)
        local cmd_persistent = collect_visible_flags(cmd.persistent_flags)
        for _, flag in ipairs(cmd_flags) do
            local line = string.format("complete -c %s -n '%s' -l %s",
                app.name, cond, flag.long or flag.short)
            if flag.short then
                line = line .. string.format(" -s %s", flag.short)
            end
            line = line .. string.format(" -d '%s'", escape_for_shell(flag.description or "", "fish"))
            local choices = get_flag_choices(flag)
            if choices then
                line = line .. " -a '" .. table.concat(choices, " ") .. "'"
            end
            table.insert(lines, line)
        end
        for _, flag in ipairs(cmd_persistent) do
            local line = string.format("complete -c %s -n '%s' -l %s",
                app.name, cond, flag.long or flag.short)
            if flag.short then
                line = line .. string.format(" -s %s", flag.short)
            end
            line = line .. string.format(" -d '%s'", escape_for_shell(flag.description or "", "fish"))
            local choices = get_flag_choices(flag)
            if choices then
                line = line .. " -a '" .. table.concat(choices, " ") .. "'"
            end
            table.insert(lines, line)
        end

        -- Subcommands
        if cmd.subcommands and #cmd.subcommands > 0 then
            for _, sub in ipairs(cmd.subcommands) do
                if not sub._hidden then
                    table.insert(lines, string.format(
                        "complete -c %s -n '%s' -a '%s\\t%s'",
                        app.name,
                        cond,
                        sub.name,
                        escape_for_shell(sub.description or "", "fish")))
                end
            end
        end
    end

    return table.concat(lines, "\n") .. "\n"
end

-- ========================================================================
-- PowerShell
-- ========================================================================

function completion.generate_powershell(app)
    local visible_cmds = collect_visible_commands(app.commands)
    local global_flags = collect_visible_flags(app.global_flags)
    local persistent_flags = collect_visible_flags(app.persistent_flags)

    local lines = {}
    table.insert(lines, "# PowerShell completion for " .. app.name)
    table.insert(lines, "")

    -- Build command list
    local cmd_list = {}
    for _, cmd in ipairs(visible_cmds) do
        table.insert(cmd_list, string.format("        '%s'", cmd.name))
    end

    -- Build subcommands table
    local subcmd_entries = {}
    for _, cmd in ipairs(visible_cmds) do
        if cmd.subcommands and #cmd.subcommands > 0 then
            local sub_names = {}
            for _, sub in ipairs(cmd.subcommands) do
                if not sub._hidden then
                    table.insert(sub_names, string.format("'%s'", sub.name))
                end
            end
            if #sub_names > 0 then
                table.insert(subcmd_entries, string.format("        '%s' = @(%s)",
                    cmd.name, table.concat(sub_names, ", ")))
            end
        end
    end

    -- Build flags table
    local flag_entries = {}
    local all_global = {}
    for _, flag in ipairs(global_flags) do
        for _, name in ipairs(flag_optnames(flag)) do
            table.insert(all_global, string.format("'%s'", name))
        end
    end
    for _, flag in ipairs(persistent_flags) do
        for _, name in ipairs(flag_optnames(flag)) do
            table.insert(all_global, string.format("'%s'", name))
        end
    end
    -- default flags
    table.insert(all_global, "'--help'")
    table.insert(all_global, "'-h'")
    table.insert(all_global, "'--version'")
    if app_utils.version_short_available(app) then
        table.insert(all_global, "'-v'")
    end
    table.insert(flag_entries, string.format("        '_' = @(%s)", table.concat(all_global, ", ")))

    for _, cmd in ipairs(visible_cmds) do
        local cmd_flags = collect_visible_flags(cmd.flags)
        local cmd_persistent = collect_visible_flags(cmd.persistent_flags)
        local all_cmd_flags = {}
        for _, flag in ipairs(cmd_flags) do
            for _, name in ipairs(flag_optnames(flag)) do
                table.insert(all_cmd_flags, string.format("'%s'", name))
            end
        end
        for _, flag in ipairs(cmd_persistent) do
            for _, name in ipairs(flag_optnames(flag)) do
                table.insert(all_cmd_flags, string.format("'%s'", name))
            end
        end
        if #all_cmd_flags > 0 then
            table.insert(flag_entries, string.format("        '%s' = @(%s)",
                cmd.name, table.concat(all_cmd_flags, ", ")))
        end
    end

    -- Build enum values table
    local enum_entries = {}
    local function collect_enums(flags_table)
        for _, flag in pairs(flags_table or {}) do
            if not flag.hidden then
                local choices = get_flag_choices(flag)
                if choices then
                    local choice_strs = {}
                    for _, c in ipairs(choices) do
                        table.insert(choice_strs, string.format("'%s'", c))
                    end
                    for _, name in ipairs(flag_optnames(flag)) do
                        table.insert(enum_entries, string.format("        '%s' = @(%s)",
                            name, table.concat(choice_strs, ", ")))
                    end
                end
            end
        end
    end
    for _, cmd in ipairs(visible_cmds) do
        collect_enums(cmd.flags)
        collect_enums(cmd.persistent_flags)
    end
    collect_enums(app.global_flags)
    collect_enums(app.persistent_flags)

    local ps_script = string.format([[
# PowerShell completion for %s

$%s_completions = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @(
%s
    )

    $subcommands = @{
%s
    }

    $flags = @{
%s
    }

    $enum_values = @{
%s
    }

    $elements = $commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() }
    $found_cmd = $null
    $prev = $null
    if ($elements.Count -gt 0) {
        $prev = $elements[$elements.Count - 1]
        foreach ($el in $elements) {
            if ($commands -contains $el) { $found_cmd = $el }
        }
    }

    # Enum value completion
    if ($enum_values.ContainsKey($prev)) {
        $enum_values[$prev] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }

    # Flag completion
    if ($wordToComplete -match '^-') {
        $candidates = @()
        if ($flags.ContainsKey('_')) { $candidates += $flags['_'] }
        if ($found_cmd -and $flags.ContainsKey($found_cmd)) { $candidates += $flags[$found_cmd] }
        $candidates | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
        }
        return
    }

    # Subcommand completion
    if ($found_cmd -and $subcommands.ContainsKey($found_cmd)) {
        $subcommands[$found_cmd] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'Command', $_)
        }
        return
    }

    # Command completion
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'Command', $_)
    }
}

Register-ArgumentCompleter -Native -CommandName %s -ScriptBlock $%s_completions
]],
        app.name,
        app.name,
        table.concat(cmd_list, "\n"),
        #subcmd_entries > 0 and table.concat(subcmd_entries, "\n") or "",
        #flag_entries > 0 and table.concat(flag_entries, "\n") or "",
        #enum_entries > 0 and table.concat(enum_entries, "\n") or "",
        app.name,
        app.name
    )

    return ps_script
end

-- ========================================================================
-- Generate all
-- ========================================================================

function completion.generate_all(app, output_dir, verbose)
    output_dir = output_dir or "./completion"
    if verbose == nil then verbose = true end

    local shells = {
        {name = "bash", ext = "_bash.sh", gen = completion.generate_bash},
        {name = "zsh",  ext = "_zsh.zsh", gen = completion.generate_zsh},
        {name = "fish", ext = ".fish",    gen = completion.generate_fish},
        {name = "powershell", ext = "_powershell.ps1", gen = completion.generate_powershell},
    }

    local success, err = security.safe_mkdir(output_dir)
    if not success then
        logger.error("Failed to create completion directory", {dir = output_dir, error = err})
        if verbose then
            print("Error: " .. (err or "Failed to create directory"))
        end
        return false
    end

    for _, shell_info in ipairs(shells) do
        local script = shell_info.gen(app)
        local filepath = output_dir .. "/" .. app.name .. shell_info.ext
        local file, file_err = security.safe_open(filepath, "w")
        if file then
            file:write(script)
            file:close()
            if verbose then
                print("Generated " .. shell_info.name .. " completion: " .. filepath)
            end
        else
            logger.error("Failed to create " .. shell_info.name .. " completion file", {error = file_err})
        end
    end

    return true
end

return completion
