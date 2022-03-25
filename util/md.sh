# Functions for working with metadata files.
# These are plain text files, each line is
# one key-value pair. File name is exact name
# of corresponding PKG.
# Auxiliary metadata files contain the symbolic
# links we created for a PKG. These files have
# the '.libs' and '.bins' extensions respectively.

# Test if package metadata file exist
md_exists() {
    test -f "$MDD/$1"
}

# List names of all packages
md_list() {
    ls "$MDD" | grep -vE '\.(libs)|(bins)$'
}

# Remove package metadata
md_remove() {
    rm -v "$MDD/$1"
}

# Read package metadata and store into the AA 'md'
# (should be declared by calling function).
md_load() {
    local key val
    md_exists "$1" || return 1
    
    while IFS=': ' read -r key val; do
        md[$key]="$val"
    done < "$MDD/$1"
}

# Save key-value pairs of the AA 'md' into package
# metadata. Overwrites file if it exists.
md_dump() {
    local action='created'
    local key fp="$MDD/$1"

    md_exists "$1" && md_remove "$1" && action='updated'
    touch "$fp" || return 1
    for key in ${!md[@]}; do
        echo "$key: ${md[$key]}" >> "$fp"
    done

    echo "$action metadata '$fp'"
}

# ---- functions for symlink metadata ---- #

# Check if pkg has symlink metadata
md_links_exist() {
    [ -f "$MDD/$1".bins ] || [ -f "$MDD/$1".libs ]
}

# Remove symlink metadata
md_links_remove() {
    rm -vf "$MDD/$1"{.bins,.libs}
}

# Read links metadata and store into the named AA.
# NOTE: name of the AA should match the extension of
# the metadata file.
# NOTE: reverse order of key/values just to make the
# plain text file more readable (linkname -> path).
md_links_load() {
    local -n targs=$2
    local key val

    [ -f "$MDD/$1.$2" ] || return 1

    while IFS=': ' read -r key val; do
        targs[$val]="$key"
    done < "$MDD/$1.$2"
}

# Store contents of the named AA into a metadata file.
# NOTE: name of the AA should match the extension 
# of the metadata file.
# NOTE: reverse order of key/values as above.
md_links_dump() {
    local -n targs=$2
    local key fp="$MDD/$1.$2" action='created'

    [ -f "$fp" ] && rm "$fp" && action='updated'

    for key in ${!targs[@]}; do
        echo "${targs[$key]}: $key" >> "$fp"
    done

    echo "$action link metadata '$fp'"
}
