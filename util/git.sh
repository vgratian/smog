#!/bin/bash

# List available or matching git refs. This function is
# a wrapper around the 'git ls-remote' command.
# Results are stored into the 3 variables:
#   - 'refsarr' array holding all refnames (sorted),
#   - 'refs'    AA with refname -> sha pairs (unsorted),
#   - 'ref'     string, holds the last refname
# Parameters:
#   - url       URL of git repo
#   - mode      type of refname (branch or tag)
#   - prefer    name of preferred branch or tag name, if not
#               empty, only fetch matching refs.
list_git_refs() {
    local url="$1" mode="$2" prefer="$3"
    local data flags

    # If user requested a specific tag or branch, we will only
    # check if those are available. Otherwise we list all
    # available refs.
    #[ -z ${OPTS[$mode]} ] && target=available || target=matching

    [ $mode == tag ] && flags="-t --sort=version:refname" || flags="-h"

    #if [ $mode == tag ]; then
    #    flags="-t --sort=version:refname $url ${OPTS[tag]-}"
    #    plural=tags
    #else
    #    flags="-h $url ${OPTS[branch]-}"
    #    plural=branches
    #fi

	data=$( $GIT ls-remote $flags $url $prefer )
    test $? || return 1

    local sha refname

    while read -r sha refname; do
        # not sure, but refnames ending with '^{}' seem 
        # to be a git bug, messing our search
        [ "${refname: -3}" == ^{} ] && continue
        ref=$(echo "$refname" | cut -s -d/ -f3)
        [ -n "$ref" ] && refs[$ref]=$sha && refsarr+=($ref)
    done <<< $data

}

# Helper function for the command 'add'. Checks user preference
# and loads available refs and shas.
check_git_refs() {
    # A repo can be cloned either using a tag or a branch as ref.
    # If user has no preference, we will check tags first.
    mode=${OPTS[mode]-tag}
    [ ${OPTS[branch]} ] && mode=branch

    if [ $mode == tag ]; then
        [ "${OPTS[tag]}" ] && echo "checking matching tags.." || echo "checking available tags.."
        list_git_refs "$url" tag "${OPTS[tag]-}"
        echo " -> found ${#refs[@]}"

        if [ ${#refs[@]} -eq 0 ]; then
            # abort if user asked for tags
            [ ${OPTS[mode]} ] || [ ${OPTS[tag]} ] && abort
			check_proceed "try branches?"
			ref=
			mode="branch"
        fi

    fi

    if [ $mode == branch ]; then
        [ "${OPTS[branch]}" ] && echo "checking matching branches.." || echo "checking available branches.."
        list_git_refs "$url" branch "${OPTS[branch]-}"
        echo " -> found ${#refs[@]}"

        [ ${#refs[@]} -eq 0 ] && abort

        # mark 'master' or 'main' as preferred branch
        if [ ! "${OPTS[branch]}" ]; then
            ref=
            [ ${refs[main]} ] && ref=main
            [ ${refs[master]} ] && ref=master
        fi
    fi
}

