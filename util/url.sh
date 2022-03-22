#!/bin/bash

# Parse URL of a git-repository (reference:
# https://www.git-scm.com/docs/git-clone#_git_urls),
# and write to 'scheme', 'host', 'port', 'path' and 'pkg'.
url_parse() {
    # parse http-style url
    IFS='# ' read -r scheme host port path \
        <<< $(echo "$1" | sed -E 's|^([a-z]+://)?([^/:]+)(:[0-9]+)?(/.*)|\1# \2# \3# \4|')

    # parse ssh-style url
    if [ -z "$host" ] || [ -z "$path" ]; then
        IFS='# ' read -r scheme host path \
            <<< $(echo "$1" | sed -E 's|^([a-z]+@)([^/:]+):(.+)|\1# \2# \3#|')
    fi

    [ -n "$host" ] && [ -n "$path" ] || return 1

    # extract repo/package name from 'path'
    IFS='# ' read -r path pkg \
        <<< $(echo "$path" | sed -E 's|^(.*)?/([^/]+)/?$|\1# \2|')
    pkg=$(echo "$pkg" | sed -E 's|\.git$||')

    [ -z "$pkg" ] && return 1

    # cleanup redundant parts
    [ "${path::1}" == "/" ] && path="${path:1}"
    [ "${host::4}" == "git." ] && host="${host:4}"

    # reconstruct path that smog should use for local directory path
    [ -n "$path" ] && path="$host/$path/$pkg" || path="$host/$pkg"
}

