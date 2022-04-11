#!/bin/bash

# Create symlinks for the targets provided and print
# what is done. If the symlinks exists (i.e. points to
# the same target), just skip. If a symlink exists with
# the same linkname but points somewhere else, warn.
# Args:
#   $1 - AA containing targets as keys and linkname as values
#   $2 - Directory where we create links (i.e. "destination")
#   $3 - Root directory of targets (i.e. "prefix")
links_create() {
    local -n targets=$1
    local dest="$2" root="$3"
    local target linkname

    for target in "${!targets[@]}"; do
        linkname="${targets[$target]}"
        # check link name does not exist
        if [ -f "$dest/$linkname" ]; then
            if [ "$(readlink $dest/$linkname)" == "$root/$target" ]; then
                printf "%-25s %-25s %s\n" "skipped (exists)" "$linkname" "$target"
                ((skipped++))
            else
                printf "%-25s %-25s %s\n" "skipped (conflic)" "$linkname" "$target"
                ((conflicts++))
            fi
            continue
        fi

        ln -s "$root/$target" "$dest/$linkname" || abort
        printf "%-25s %-25s %s\n" "created" "$linkname" "$target"
        ((created++))
    done
}

# Look for dead links in the directory 'dest'. I.e., any
# symlink that points to a file in 'root', but is not in
# our targets.
links_clean() {
    local -n targets=$1
    local dest="$2" root="$3"
    local linkname targetp target

    # size of root path (to compare paths)
    local -i n=${#root}

    for linkname in $(ls "$dest"); do
        targetp=$( readlink "$dest/$linkname" )
        # ignore if link doesn't point to our root directory
        [ "${targetp::$n}" == "$root" ] || continue
        # relative target path
        target=${targetp:(($n+1))}

        if [ ! ${targets[$target]+_} ] && [ ! -f "$targetp" ] ; then
            unlink "$dest/$linkname"
            printf "%-25s %-25s %s\n" "cleaned (deadlink)" "$linkname" "$target"
            ((cleaned++))
        fi
    done
}

# Remove all links to the targets provided.
links_remove() {
    local -n targets=$1
    local dest="$2" root="$3"
    local linkname target realtarget

    for target in "${!targets[@]}"; do
        linkname="${targets[$target]}"
        [ -L "$dest/$linkname" ] || continue
        realtarget=$(readlink "$dest/$linkname")
        if [ "$realtarget" == "$root/$target" ]; then
            unlink "$dest/$linkname"
            targets[$target]=
            printf "%-25s %-25s %s\n" "removed" "$linkname" "$target"
            ((removed++))
        else
            printf "%-25s %-25s %s\n" "skipped (not found)" "$linkname" "$target"
            ((skipped++))
        fi
    done
}

# Scan for binaries, shell scripts and sharedlibs. 
# Mark them as targets and add to the AAs bin and lib.
# Args:
#   $1 - Root directory to scan
#   $2 - Subdirectory (always empty if non-recursive)
#   $3 - If not empty, run recursively in subdirectories
links_scan() {
    local r="$1" d="$2" rec="$3"
    local fn fp type

    for fn in $( ls "$r/$d" ); do
        # relative path in root directory
        [ -z "$d" ] && fp="$fn" || fp="$d/$fn"

        # ignore links
        [ -L "$r/$fp" ] && continue

        # ignore directories
        if [ -d "$r/$fp" ]; then
            [ -n "$rec" ] && links_scan "$r" "$fp" "$rec"
            continue
        fi

        # ignore non-executables
        [ -x "$r/$fp" ] || continue

        type=$(file -b --mime-type "$r/$fp" | sed -E 's|.*-([a-z]+)$|\1|')

        case "$type" in
            shellscript | executable )
                [ ! ${bin[$fp]+_} ] && bin[$fp]="$fn" ;;
            sharedlib )
                [ ! ${lib[$fp]+_} ] && lib[$fp]="$fn" ;;
        esac
    done
}


links_edit() {
    local -n btargs=$2
    local -n ltargs=$3

    local fn='__smog_links_tmp'
    local k x line cur

    local bsection="# -- binaries or scripts -- #"
    local lsection="# -- shared libraries -- #"

    [ -f "$fn" ] && rm -v "$fn"  # safe?

    cat << EOF > "$fn"
# Below is the list of files that smog detected and will create
# symlinks for. Each line consists of the linkname (basename)
# and the filepath, seperated by ' -> '. Remove a line if you
# don't want a file to be linked. You can also change the linkname.
#
# Note: filepaths are relative in the 'root' directory:
# $1
#
# Please preserve the file format. Please don't change comments!"
EOF

    if [ ${#btargs[@]} -ne 0 ]; then
        echo "$bsection" >> "$fn"
        echo "" >> "$fn"
        for k in "${!btargs[@]}"; do echo "${btargs[$k]} -> $k" >> "$fn"; done
    fi

    if [ ${#ltargs[@]} -ne 0 ]; then
        echo "" >> "$fn"
        echo "$lsection" >> "$fn"
        echo "" >> "$fn"
        for k in "${!ltargs[@]}"; do echo "${ltargs[$k]} -> $k" >> "$fn"; done
    fi

    #echo "created temporary file '$fn'"

    $EDITOR "$fn"

    btargs=()
    ltargs=()
    while read -r line; do
        [ -z "$line" ] && continue

        if [ "${line::1}" == '#' ]; then
            [ "$line" == "$bsection" ] && cur=b && continue
            [ "$line" == "$lsection" ] && cur=l
            continue
        fi

        [ -z "$cur" ] && continue

        IFS='# ' read -r k x <<< $(echo "$line" | sed -E 's|^(.+) -> (.+)$|\1# \2|')
        #echo "   -> $k = [$x]"
        [ -n "$x" ] && [ -n "$k" ] || continue # TODO warn
        [ -f "$1/$x" ] || abort "invalid file '$1/$x'"
        [ "$cur" == b ] && btargs["$x"]="$k" || ltargs["$x"]="$k"
    done < "$fn"

    rm "$fn"
}
