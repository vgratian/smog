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
list_refs() {
    local url="$1" mode="$2" prefer="$3"
    local data flags

    [ $mode == tag ] && flags="-t --sort=version:refname" || flags="-h"

	data=$( $GIT ls-remote $flags $url $prefer )
    [ $? -eq 0 ] || return 1

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
check_refs() {
    # A repo can be cloned either using a tag or a branch as ref.
    # If user has no preference, we will check tags first.
    mode=${OPTS[mode]-tag}
    [ ${OPTS[branch]} ] && mode=branch

    if [ $mode == tag ]; then
        [ "${OPTS[tag]}" ] && echo -n "checking matching tags.. " || \
            echo -n "checking available tags.."
        list_refs "$url" tag "${OPTS[tag]-}" || return 1
        echo "found ${#refs[@]}"

        if [ ${#refs[@]} -eq 0 ]; then
            # Abort if user explicitely asked for tags
            [ ${OPTS[mode]} ] || [ ${OPTS[tag]} ] && return 1
			ask "try branches?" || return 1
			ref=
			mode=branch
        fi
    fi

    if [ $mode == branch ]; then
        [ "${OPTS[branch]}" ] && echo -n "checking matching branches.. " \
            || -n echo "checking available branches.. "
        list_refs "$url" branch "${OPTS[branch]-}"
        echo "found ${#refs[@]}"

        [ ${#refs[@]} -eq 0 ] && return 1

        # Mark 'master' or 'main' as preferred branch, unless
        # the '-B' flag was provided with a branch name.
        if [ ! "${OPTS[branch]}" ]; then
            ref=
            [ ${refs[main]} ] && ref=main
            [ ${refs[master]} ] && ref=master
        fi
    fi
}

# Helper function for command 'update'. Check if
# a valid tag is available for update.
check_tags() {

    local tag="${OPTS[tag]-}"

    # explicitely asked to use a tag
    if [ -n "$tag" ]; then
        [ ! ${refs[$tag]+_} ] && echo "tag '$tag' not found" && return 1
        ref="$tag"
        # If tag is not in 'refsarr', it is likely older than current
        # tag ('refsarr' holds tags that are newer).
        if ! printf '%s\n' | grep -xq "$tag"; then
            echo -en "$BOLD"
            echo "warning: '$tag' might be older than current '${md[ref]}'"
            echo -en "$CLEAR"
        fi
    fi

    # if a tag is selected, ask user to confirm
    if [ -n "$ref" ]; then
        if ! ask "update to [$ref]?"; then
            # don't continue if only one tag is available
            [ -n "$tag" ] && return 1
            [ ${#refsarr[@]} -eq 1 ] && return 1
            ref= # unset, so we ask user to select
        fi
    fi

    # if nothing was selected, ask user choice
    if [ -z "$ref" ]; then
        select ref in "${refsarr[@]}"; do break; done
    fi

    # final test
    test -n "$ref"
}

