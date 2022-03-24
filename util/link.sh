#!/bin/bash

# workflow:
#  - create symlink for each target, unless
#       - exists: just skip
#       - link name used: warn and skip
#  - second iteration: check all links and remove dead links

# Args:
#   $1 - AA containing targets as keys
#   $2 - Directory where we create links (i.e. "destination")
#   $3 - Root directory of targets (i.e. "prefix")
#   $4 - If not empty, check existing links to 'Root' and clean dead links

# printf "%-15s %-20% %s\n"

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

links_remove() {
    local -n targets=$1
    local dest="$2" root="$3"
    local linkname targetp target

    for target in "${!targets[@]}"; do
        linkname="${targets[$target]}"
    done

}

links_create2() {
    local -n targets=$1
    local dest="$2" root="$3"

    # size of root path (to compare paths)
    local -i n=${#root}

    local target targetlong linkname

    # scan link directory for existing or dead links
    for linkname in $( ls "$dest" ); do
        [ -L "$dest/$linkname" ] || continue
        # full path of target file
        targetlong=$( readlink "$dest/$linkname" )
        # ignore if link doesn't point to our root directory
        [ "${targetlong::$n}" == "$root" ] || continue

        # relative target path
        target=${targetlong:$n}

        # link already exists, make note so that we don't recreate
        if [ ${targets[$target]+_} ]; then
            bins[$target]="$linkname"
            ((kept++))
            printf "%-10s %-25s %s\n" "<keep>" "$linkname" "$target"
        else
            # remove dead link
            unlink "$dest/$linkname"
            ((removed++))
            printf "%-10s %-25s %s\n" "<remove>" "$linkname" "$target"
        fi
    done

    # create links for each target (except those we skipped)
    # and check for name conflicts
    #for target in "${!targets[@]}"; do

        # skip target if a link already exists
    #    [ -n "${targets[$target]}" ] && continue

     #   linkname=$( basename "$target" )

     #   # name conflict
     #   if [ -f "$dest/$linkname" ]; then
     #       ((conflicts++))
     #       printf "%-10s %-25s %s\n" "<conflict>" "$linkname" "$target"



    #done


    #for t in "${!targets[@]}"; do
        # link name
     #   n=$( basename "$target" )
        
        # link already exists
      #  if [ -e "$dest/$n" ]; then
            
      #  fi


    #done

}


# Positional arguments:
#   $1 - AA where we put binary targets
#   $2 - AA where we put shared lib targets
#   $3 - Root directory to scan
#   $4 - Subdirectory (always empty if non-recursive)
#   $5 - If not empty, runs recursively in subdirectories
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

COMMENT_INTRO="
# Below is the list of files that smog detected and will create
# symlinks for. Each line consists of the linkname (basename)
# and the filepath, seperated by ' -> '. Remove a line if you
# don't want a file to be linked. You can also change the linkname.
#
# Please preserve the file format. Please don't change comments!"

COMMENT_BINS="# -- binaries or scripts -- #"

COMMENT_LIBS="# -- shared libraries -- #"

links_edit() {
    local -n btargs=$2
    local -n ltargs=$3

    local fn='_smog_links_edit.txt'
    local k x line cur

    [ -f "$fn" ] && rm -v "$fn"
    echo "$COMMENT_INTRO" > "$fn"
    echo "#" >> "$fn"
    echo "# Note: filepaths are relative in the 'root' directory:" >> "$fn"
    echo "# $1" >> "$fn"
    echo "" >> "$fn"

    if [ ${#btargs[@]} -ne 0 ]; then
        echo "$COMMENT_BINS" >> "$fn"
        echo "" >> "$fn"
        for k in "${!btargs[@]}"; do echo "${btargs[$k]} -> $k" >> "$fn"; done
    fi

    if [ ${#ltargs[@]} -ne 0 ]; then
        echo "" >> "$fn"
        echo "$COMMENT_LIBS" >> "$fn"
        echo "" >> "$fn"
        for k in "${!ltargs[@]}"; do echo "${ltargs[$k]} -> $k" >> "$fn"; done
    fi

    echo "created tmp file [$fn]"
    $EDITOR "$fn"

    # TODO read results
    btargs=()
    ltargs=()
    while read -r line; do
        [ -z "$line" ] && continue

        if [ "${line::1}" == '#' ]; then
            [ "$line" == "$COMMENT_BINS" ] && cur=b && continue
            [ "$line" == "$COMMENT_LIBS" ] && cur=l
            continue
        fi

        [ -z "$cur" ] && continue

        IFS='# ' read -r k x <<< $(echo "$line" | sed -E 's|^(.+) -> (.+)$|\1# \2|')
        echo "   -> $k = [$x]"
        [ -n "$x" ] && [ -n "$k" ] || continue # TODO warn
        [ -f "$1/$x" ] || abort "invalid file '$1/$x'"
        [ "$cur" == b ] && btargs["$x"]="$k" || ltargs["$x"]="$k"
    done < "$fn"

    echo " -- OK -- "
    # TODO remove tmp file
}
