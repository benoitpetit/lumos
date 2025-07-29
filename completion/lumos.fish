# Fish completion for lumos
function __lumos_complete_commands
    lumos --help | awk '/^  [^ ]+/ {print $1 "\t" $2}'
end

function __lumos_complete_flags
    lumos --help | awk '/Global flags:/,/Available commands:/ {if ($1 ~ /^-/) print $1}'
end

# Complete commands
complete -c lumos -f -n "not __fish_seen_subcommand_from (__lumos_complete_commands)" -a "(__lumos_complete_commands)"

# Complete global flags
complete -c lumos -f -n "__fish_use_subcommand" -a "(__lumos_complete_flags)"

# Complete help flag for any subcommand
complete -c lumos -l help -s h -d "Show help information"
complete -c lumos -l version -s v -d "Show version information"
