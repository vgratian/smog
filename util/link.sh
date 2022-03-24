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
                printf "%-10s %-25s %s\n" "<exists>" "$linkname" "$target"
                ((kept++))
            else
                printf "%-10s %-25s %s\n" "<conflict>" "$linkname" "$target"
                ((conf++))
            fi
            continue
        fi

        ln -s "$root/$target" "$dest/$linkname" || abort
        ((added++))
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
        target=${targetp:$n}

        if [ ! ${targets[$target]+_} ] && [ ! -f "$targetp" ] ; then
            unlink "$dest/$linkname"
            printf "%-10s %-25s %s\n" "remove: deadlink" "$linkname" "$target"
            ((removed++))
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
        if [ "$realtarget" == "$target" ]; then
            unlink "$dest/$linkname"
            targets[$target]=
            printf "%-10s %-25s %s\n" "removed" "$dest/$linkname" "$target"
        else
            printf "%-10s %-25s %s\n" "skipped" "$dest/$linkname" "$target"
        fi
    done
}

# Scan for binaries, shell scripts and sharedlibs. 
# Mark them as targets and create a link name.
# Args:
#   $1 - AA where we put executable targets
#   $2 - AA where we put shared lib targets
#   $3 - Root directory to scan
#   $4 - Subdirectory (always empty if non-recursive)
#   $5 - If not empty, run recursively in subdirectories
links_scan() {
    local -n btargs=$1
    local -n ltargs=$2
    local r="$3" d="$4" rec="$5"

    echo " --> root=[$r] dir=[$d] rec=[$rec]=(${#rec})"

    local fn fp type

    for fn in $( ls "$r/$d" ); do
        # relative path in root directory
        [ -z "$d" ] && fp="$fn" || fp="$d/$fn"

        # ignore links
        [ -L "$r/$fp" ] && continue

        # ignore directories
        if [ -d "$r/$fp" ]; then
            echo "  -> rec? [$rec]"
            [ -n "$rec" ] && links_scan bins libs "$r" "$fp" "$rec"
            continue
        fi

        # ignore non-executables
        [ -x "$r/$fp" ] || continue

        type=$(file -b --mime-type "$r/$fp" | sed -E 's|.*-([a-z]+)$|\1|')

        case "$type" in
            shellscript | executable )
                printf "    %-8s %-20s %s\n" "<bin>" "$fn" "$fp"
                btargs[$fp]="$fn" ;;
            sharedlib )
                printf "    %-8s %-20s %s\n" "<lib>" "$fn" "$fp"
                ltargs[$fp]="$fn" ;;
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

    echo "created temporary file '$fn'"

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

    rm -v "$fn"
}
