# Functions for working with metadata files.
# These are plain text files, each line is
# one key-value pair. File name is exact name
# of corresponding PKG.
# Auxiliary metadata files contain the symbolic
# links we created for a PKG. These files have
# the '.libs' and '.bins' extensions respectively.

# Test if package metadata file exist
md_exists() {
    test -e "$MDD/$1"
}

# List names of all packages
md_list() {
    ls "$MDD" | grep -vE "\.(libs)|(bins)$"
}

# Remove package metadata files
md_remove() {
    rm -vf "$MDD/$1"{'', .bins, .libs}
}

# Read package metadata and store into the AA 'md'
# (should be declared by calling function).
md_load() {
    local key val
    while IFS=': ' read -r key val; do
        md[$key]="$val"
    done < "$MDD/$1"
}

# Read links metadata and store into the two
# AA's: 'bins' and 'libs'.
md_load_links() {
    local key val
    if [ -e "$MDD/$1.bins" ]; then
        while IFS=': ' read -r key val; do
            bins[$key]="$val"
        done < "$MDD/$1.bins"
    fi

    if [ -e "$MDD/$1.libs" ]; then
        while IFS=': ' read -r key val; do
            libs[$key]="$val"
        done < "$MDD/$1.libs"
    fi
}

# Save key-value pairs of the AA 'md' into package
# metadata. Overwrites file if it exists.
md_dump() {
    action="created"
    md_exists "$1" && md_remove "$1" && action="updated"

    local k f="${MDD}/$1"
    touch "$f" || abort "can't create '$f'"
    for k in ${!md[@]}; do echo "$k: ${md[$k]}" >> "$f"; done
    echo "$action metadata '$f'"
}

# Save the two lists of symlinks in auxiliary 
# metadata files, calling function should provide
# the AA's 'bins' and 'libs'
md_dump_links() {

    local k bf="${MD}/$1.bins" lf="${MD}/$1.libs"
    rm -f "$bf" "$lf"
    for k in ${!bins[@]}; do echo "${bins[$k]}: $k" >> "$bf"; done
    for k in ${!libs[@]}; do echo "${libs[$k]}: $k" >> "$lf"; done

}
