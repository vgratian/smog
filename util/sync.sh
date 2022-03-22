#!/bin/bash

sync_pkg() {
    local -A md refs
    local -a refsarr
    local url ref status color

    # TODO: update last commit hash
    # cmd: git log pkgdata[ref] -1 --pretty=format:%H

    md_load "$1" || abort "package '$1' does not exist"

    url="${md[url]}"
    ref="${md[ref]}"

    if [ "${md[mode]}" == branch ]; then
        sync_branch "$url" "$ref" "${md[sha]}"
    else
        sync_tag "$url" "$ref" "${md[tag_pattern]-}"
    fi

    case $? in
        0 ) color=$GREY ;;
        1 | 2 ) color=$BOLD ;;
        * ) color=$RED ;;
    esac

    printf "%b%-30s %-20s %-50s%b\n" $color "$1" "${md[mode]} '${md[ref]}'" "$status" $CLEAR
}

# Check for new commits on remote branch. Returns:
#   0:  no updates
#   1:  new commit(s) available
#   3:  error
#
# Parameters:
# - URL
# - current branch (refname)
# - current SHA
# 
# Variables
# - status:     human-readable status or error
sync_branch() {
    local url="$1" branch="$2" current_sha="$3"

    list_git_refs "$url" branch "$branch" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        status="error: 'git ls-remote' failed"
        return 3
    fi

    local sha="${refs[$branch]}"

    # invalid or missing hash
    if [ -z "$sha" ] || [ ${#sha} -ne 40 ]; then
        status="error: remote '$branch' not found"
        return 3
    fi

    # hash is different, means new commits
    if [ "$sha" != "$current_sha" ]; then
        status='new commit(s)'
        return 1
    fi

    status='up-to-date'
}

# Check for available new tags. Returns:
#   0: no updates
#   1: new tag available
#   2: new tags available
#   3: error
# Parameters:
# - URL
# - current tag (refname)
# - optional: tag pattern
# 
# Variables:
# - status:     human-friendly status
# - ref:        pre-selected tag (newest tag)
# - refsarr:    all updateable tags
sync_tag() {
    local url="$1" tag="$2" pttrn="$3"
    local -a arr
    local found refname

    list_git_refs "$url" tag > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        status="error: 'git ls-remote' failed"
        return 3
    fi

    # run over all available tags, pick tags that
    # are newer than our current tag
    for refname in "${refsarr[@]}"; do
        [ "$refname" == "$tag" ] && found=y && continue
        [ -z $found ] && continue
        [ -z "$pttrn" ] || grep -qP "$pttrn" <<< "$refname" || continue
        arr+=("$refname")
    done

    refsarr=("${arr[@]}")

    # current tag is not in the list, so we have to abort
    if [ -z $found ]; then
        status="error: remote '$tag' not found"
        return 3
    fi

    # fix last tag name
    local -i n=${#arr[@]}
    [ $n -gt 0 ] && ref="${arr[$(($n-1))]}"

    # exactly one tag available
    if [ "${#arr[@]}" -eq 1 ]; then
        status="new tag '$ref'"
        return 1
    fi

    # multiple new tags
    if [ "${#arr[@]}" -gt 1 ]; then
        status="$n new tags, last: '$ref'"
        return 2
    fi
    status='up-to-date'
}
