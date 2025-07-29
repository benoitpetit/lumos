#compdef lumos

_lumos() {
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
            commands=($(lumos --help | awk '/^  [^ ]+/ {print $1}'))
            _describe -t commands 'lumos commands' commands
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

_lumos "$@"
