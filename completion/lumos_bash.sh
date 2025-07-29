_lumos_completions() {
    local cur prev words
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words="$(lumos --help | awk '/^  [^ ]+/ {print $1}')"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "$(lumos --help | awk '/Global flags:/,/Available commands:/ {if ($1 ~ /^-\/?/) print $1}')" -- ${cur}) )
        return 0
    fi

    if [[ ${prev} != -* ]] && [[ ${cur} != -* ]] ; then
        COMPREPLY=( $(compgen -W "${words}" -- ${cur}) )
        return 0
    fi
}

complete -F _lumos_completions lumos
