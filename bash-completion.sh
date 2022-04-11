#/usr/bin/env bash

_smog_complete() {

    local -a all_commands=(add check list help version)
    local -a pkg_commands
    local cmd smog
    all_commands=(add check list help version)
    pkg_commands=(show path set sync update link unlink remove)
    all_commands+=(${pkg_commands[@]})

    # -- complete command name -- #

    if [ $COMP_CWORD -eq 1 ]; then
        if [ -z "${COMP_WORDS[1]}" ]; then
            COMPREPLY+=( "${all_commands[@]}" )
        else
            COMPREPLY+=( $( compgen -W "${all_commands[*]}" "${COMP_WORDS[1]}" ) )
        fi
        return
    fi

    # -- complete package name -- #

    [ $COMP_CWORD -eq 2 ] || return
    
    # check if command expects PKG as argument
    for cmd in ${pkg_commands[@]}; do [ "$cmd" == "${COMP_WORDS[1]}" ] && break; done

    [ "$cmd" == "${COMP_WORDS[1]}" ] || return

    smog="${COMP_WORDS[0]}"
    if [ -z "${COMP_WORDS[2]}" ]; then
        COMPREPLY+=( $( $smog list ) )
    else
        COMPREPLY+=( $( compgen -W "$( $smog list )" "${COMP_WORDS[2]}" ) )
    fi
}

complete -F _smog_complete smog
