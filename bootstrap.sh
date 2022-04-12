#!/bin/bash

# These section contains fixed parameters, please do not change
BOOTSTRAP=$(basename $0)
#REF="0.0.1"
REF=master
#MODE=tag
MODE=branch
SHA=
CONFIGSH="config.sh"
CONFIGDEF="config.def.sh"
SMOG_REPO="https://gitlab.com/vgratian/smog"
CONFIGDEF_URL="${SMOG_REPO}/-/raw/${REF}/${CONFIGDEF}"
BOOTSTRAP_URL="${SMOG_REPO}/-/raw/${REF}/${BOOTSTRAP}"

# Directory where we will download temporary files
BOOTSTRAP_PATH="/tmp/smog_boostrap"

# If you don't want to be asked questions, use the "-s" (silent) flag
INTERACTIVE=true

# List of parameters that are required to configure smog. Default
# values are defined below or will be sourced from "config.sh.def".
declare -a VARS
VARS=( GIT EDITOR ROOT PKG BIN LIB SMOG MDD MASTERBRANCH NPROCS LDSOCONF BASHRC )

# Explanation of each parameter
declare -A COMMENTS
COMMENTS=(
    [GIT]="git command that smog will invoke to clone repositories"
    [EDITOR]="text editor command"
    [ROOT]="root directory for folders defined below"
    [PKG]="path of directory where smog will clone your git packages"
    [BIN]="directory where smog will create symlinks to binaries
this is used when you invoke 'smog reflect PKG' and smog detects executables"
    [LIB]="directory where smog will create symlinks to shared libraries
this is used when you invoke 'smog reflect PKG' and smog detects .so files"
    [SMOG]="directory where smog itself will be cloned"
    [MDD]="subdirectory where smog will store metadata of packages"
    [MASTERBRANCH]="name of the branch that smog will create after cloning a repository
(such that your local changes don't mess with the upstream source code)"
    [NPROCS]="number of processes to use when syncing packages (passed to xargs)
default is number of CPUs * 2; use '0' to run as many as possible"
    [LDSOCONF]="path to file created to integrate smog with ldconfig
empty means no file will be created"
    [BASHRC]="path to your bashrc, used to update your PATH environment variable
empty means don't update PATH"
)

INTERACTIVE_GUIDE="
you will be asked what parameters to use.
  -> hit ENTER to use default value (printed in square brackets)
  -> enter double quotes (\"\") to unset it or set it to empty.
  -> note: values can be nested bash variables or commands."

RAWROOT=
EXPORT_PATH_COMMENT="# directory of binary symlinks maintained by smog"
SOURCE_COMP_COMMENT="# autocomplete script for smog commands and packages"

# terminal colors
BOLD="\033[1m"
CLEAR="\033[0m"
GREY="\033[90m"

version() {
    echo "smog bootstrapper v${REF}"
}

usage() {
    version
    echo "
DESCRPTION:
    This script will bootstrap smog and configure itself as a smog package.
    Normally, the bootstrap process will run interactively and ask what
    parameters to use. The '-s' flag will force it to run silently and use
    default parameters instead.

    With the 'undo' argument, the script will uninstall smog. CAUTION:
    this will permanently delete not only smog, but also all packages that
    you might have installed with it.

USAGE:
    Download the bootstrap script:
        wget ${BOOTSTRAP_URL}

    Run the bootstrap:
        ./${BOOTSTRAP} [-s]

    Undo the bootstrap:
        ./${BOOTSTRAP} undo

    Show bootstrap version:
        ./${BOOTSTRAP} version

    Show this help message:
        ./${BOOTSTRAP} help

OPTIONS:
    -s      run silently and use default parameters
    "
}

abort() {
    echo "${1-abort}" >&2
    exit 1
}

# create tmp directory and download default config
prepare() {
    # clean up existing directory
    if [ -d "$BOOTSTRAP_PATH" ]; then
        rm -rvf "$BOOTSTRAP_PATH" || abort
    fi

    mkdir -p "$BOOTSTRAP_PATH" || abort
    cd "$BOOTSTRAP_PATH"
    echo "created bootstrap directory '$BOOTSTRAP_PATH'"

    printf "%b" $GREY
    wget "$CONFIGDEF_URL" || abort
    printf "%b" $CLEAR
    printf "downloaded [%s]\n" "$CONFIGDEF_URL"
}


cleanup() {
    rm "$BOOTSTRAP_PATH/config*.sh"
    rm -vd "$BOOTSTRAP_PATH"
}

# read default config and create a new config file
configure() {
    [ -r "$CONFIGDEF" ] || abort "can't read [$CONFIGDEF]"

    # config file should not exist, not a problem, but might
    # be a sign you are messing up with an existing installation
    [ -e "$CONFIGSH" ] && abort "file '"$CONFIGSH"' already exists"

    touch "$CONFIGSH" || abort

    printf "\n%b" $BOLD
    if [ -z "$INTERACTIVE" ]; then
        printf "configuring smog with default parameters\n%b" $CLEAR
    else
        printf "configuring smog interactively:%b%s\n" $CLEAR "$INTERACTIVE_GUIDE"
    fi

    for v in "${VARS[@]}"; do

        # read default value (this way, we don't expand nested vars)
        val=$(grep ^$v= $CONFIGDEF | tail -n1 | cut -d= -f2-)

        if [ "$INTERACTIVE" ]; then
            # print comment about parameter
            printf "\n%b%b%s:%b%b " "$GREY" "$BOLD" "$v" "$CLEAR" "$GREY"
            printf "${COMMENTS[$v]}"
            printf "%b\n" "$CLEAR"
            # ask user input
            read -p "value for $v [$val]: "
            [ -n "$REPLY" ] && val="$REPLY"
        fi

        # write to config file
        readarray -t comments <<< ${COMMENTS[$v]}
        # start each comment line with '#'
        for c in "${comments[@]}"; do printf "# %s\n" "$c" >> $CONFIGSH; done
        printf "%s=%s\n\n" "$v" "$val" >> $CONFIGSH
    done

    echo
    printf "created config [%s/%s]\n" "$BOOTSTRAP_PATH" "$CONFIGSH"
    printf "please review it and hit ENTER to continue"
    read
    echo
}

# check if variables are OK
validate() {

    local ok=true
    echo "validating $CONFIGSH.. "

    #. "$BOOTSTRAP_PATH/$CONFIGSH" || abort "can't source $CONFIGSH"
    . "$BOOTSTRAP_PATH/$CONFIGSH" 

    # TODO check bash version

    echo -n " -> checking GIT [$GIT].. "
    $GIT version > /dev/null
    if [ $? -ne 0 ]; then
        echo "git command failed"
        ok=
    else
        echo "OK"
    fi

    echo -n " -> checking EDITOR [$EDITOR].. "
    which $EDITOR > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "editor command failed"
        ok=
    else
        echo "OK"
    fi

    # check variables which can't be empty
    echo " -> checking required variables.. "
    for v in ROOT PKG SMOG MDD MASTERBRANCH NPROCS; do
        if [ -z "${!v}" ]; then
            echo "     '$v' can't be empty"
            ok=
        fi
    done

    # nprocs must be valid integer
    test "$NPROCS" -ge 0 2> /dev/null
    if [ $? -ne 0 ]; then
        echo "     'NPROCS' positive integer"
        ok=
    fi

    [ -z $ok ] && abort
    echo "OK"
    echo

    # store unexpanded $ROOT for later use bashrc
    # val=$(grep ^$v= $CONFIGDEF | tail -n1 | cut -d= -f2-)
    RAWROOT=$(grep '^$ROOT=' "$BOOTSTRAP_PATH/$CONFIGSH" | tail -n1 | cut -d= -f2-)
    # to be safe
    if [ -z "$RAWROOT" ]; then
        RAWROOT="$ROOT"
    elif [ ${RAWROOT::1} == '"' ] && [ ${RAWROOT: -1} == '"' ]; then
        RAWROOT="${RAWROOT:1:-1}"
    fi
}

filesystem_create() {
    echo "creating directories.."

    # jic
    [ -d "$ROOT/$SMOG" ] && abort "directory '$ROOT/$SMOG' exists"

    for d in BIN LIB PKG SMOG; do
        [ -z "${!d}" ] && continue
        [ -d "$ROOT/${!d}" ] && continue  # TODO warn?
        mkdir -vp "$ROOT/${!d}" || abort
    done
}

repository_clone() {
    cd "$ROOT/$SMOG"
    echo -e "${BOLD}changed directory to '$ROOT/$SMOG'${CLEAR}"
    echo

    echo -e "cloning repository [$SMOG_REPO] $GREY"
    $GIT clone --depth=1 -c advice.detachedHead=false -b "$REF" "$SMOG_REPO".git/ .
    [ $? -ne 0 ] && abort
    # get current head SHA if in branch mode
    if [ "$MODE" == branch ]; then
        SHA=$( $GIT log origin/"$REF" -1 --pretty=format:%H )
    fi
    $GIT checkout -b "$MASTERBRANCH" || abort
    echo -e "$CLEAR"

    echo -n "copy "
    cp -v "$BOOTSTRAP_PATH/$CONFIGSH" . || abort
    echo

}

# create metadata file for smog
metadata_create() {
    mkdir -vp "$ROOT/$MDD" || abort
    local f="$ROOT/$MDD/smog"
    touch "$f" || abort "failed to create metadata '$f'"

    cat << EOF > "$f"
url: $SMOG_REPO.git/
path: $SMOG
mode: $MODE
ref: $REF
EOF
    [ -n "$SHA" ] && echo "sha: $SHA" >> "$f"
    echo "created metadata file '$f"
    echo
}

shell_integrate() {
    [ -z "$BIN" ] && return

    echo -n "symlink "
    ln -sv "$ROOT/$SMOG/smog" "$ROOT/$BIN/smog"
    echo "smog: smog" >> "$ROOT/$MDD/smog.bin"

    if [ -z "$BASHRC" ]; then
        echo "'\$BASHRC' is not defined, you can manually integrate smog to your shell:"
        echo " -> update your \$PATH to include '$ROOT/$BIN'"
        echo " -> source autocompletion script '$ROOT/$SMOG/bash-completion.sh'"
        return
    fi

    local changed=

    # check if bashrc already contains $PKG
    if grep '^export PATH=' "$ROOT/$BASHRC" | grep -qE "/$BIN[:\"]"; then
        echo "seems like '$BASHRC' already contains path '$ROOT/$BIN'"
    # put after last 'export PATH' or before first 'return'
    else
        local EXPORT_PATH="export PATH=\"$ROOT/$BIN:\$PATH\""
        local line=$( grep -n '^export PATH' "$ROOT/$BASHRC" | tail -n1 | cut -d: -f1 )
        if [ -n "$line" ] && [ "$line" -gt 0 ]; then
            ((line++))
            sed -i \'"$line" i "$EXPORT_PATH"\' "$ROOT/$BASHRC"
            sed -i \'"$line" i "$EXPORT_PATH_COMMENT"\' "$ROOT/$BASHRC"
            echo "updated \$PATH in '$ROOT/$BASHRC' at $line"
        else
            echo "$EXPORT_PATH_COMMENT" >> "$ROOT/$BASHRC"
            echo "$EXPORT_PATH" >> "$ROOT/$BASHRC"
            echo "updated \$PATH in '$ROOT/$BASHRC'"
        fi
        changed=yes
    fi

    if complete -p > /dev/null 2>&1; then
        local SOURCE_COMP=". \"$ROOT/$SMOG/bash-completion.sh\""
        echo "$SOURCE_COMP_COMMENT" >> "$ROOT/$BASHRC"
        echo "$SOURCE_COMP" >> "$ROOT/$BASHRC"
        echo "added autocompletion script in '$ROOT/$BASHRC'"
        changed=yes
    else
        echo "skipped autocompletion script: does your bash support it?"
    fi

    if [ -n $changed ]; then
        echo -e "${BOLD}tip: run '. $BASHRC' to update your shell session${CLEAR}"
    fi
    echo
}

ldconf_integrate() {
    [ -z "$LIB" ] && return

    if [ -z "$LDSOCONF" ]; then
        echo "'\$LDSOCONF' is not defined, but smog can link sharedlibs in '$ROOT/$LIB'"
        echo "you can manually configure ldconfig to cache this directory."
        return
    fi

    echo "integrating '$ROOT/$LIBS' to ldconfig.."

    local fn=($basename $LDSOCONF)
    local dest=$(dirname $LDSOCONF)

    if ! ldconfig --help > /dev/null 2>&1; then
        echo "skip: seems like you don't use ldconfig"
        return
    fi

    if [ ! -d "$dest" ]; then
        echo "skip: directory '$dest' does not exist"
        return
    fi

    echo "$ROOT/$LIB" > $fn
    if ( >> "$dest/test" ) 2> /dev/null; then
        mv -v "$fn" "$dest"
    else
        echo "sudo required to create file [$LDSOCONF]"
        sudo mv -v "$fn" "$dest"
    fi

    echo "tip: whenever smog links shared libs, run 'sudo ldconfig' to update cache'"
    echo
}

bootstrap() {
    prepare && configure && validate

    filesystem_create && repository_clone && metadata_create

    shell_integrate && ldconf_integrate

    cleanup

    echo -e "$BOLD"
    echo "successfully bootstrapped smog!"
    echo -en "$CLEAR"

    echo " -> run 'smog sync smog' to check for new version of smog"
    echo " -> run 'smog update smog' to update smog to a new version"
}


remove_pkgs() {

    local pkg
    local -i count=0

    echo "removing smog packages"
    . ./util/md.sh || abort "can't source 'util/md.sh'"

    for pkg in $(md_list); do
        if [ "$pkg" != smog ]; then
            # TODO requires to confirm (or implement -f)
            md_links_exist "$pkg" && ./smog -f unlink "$pkg"
            ./smog -f remove "$pkg"
            echo " -> removed pkg '$pkg'"
            ((count++))
        fi
    done
    echo "removed $count packages"
    echo
}
undo() {
    ./smog version > /dev/null 2>&1 || abort "please run this script in smog directory"
    echo -en "$BOLD"
    echo "WARNING: THIS WILL REMOVE SMOG *AND*"
    echo " ALL PACKAGES YOU HAVE INSTALLED WITH SMOG"
    echo " ALL METADATA FILES OF PACKAGES"
    echo " ALL GIT REPOS THAT WERE CLONED"
    echo " ALL SOURCE CODE CHANGES IN LOCAL BRANCHES"
    echo " ALL SYMLINKS CREATED BY SMOG"
    echo -e "$CLEAR"
    read -p "continue? [y/N]:"
    [ "$REPLY" == y ] || [ "$REPLY" == yes ] || abort
    echo "type I AM ABSOLUTELY SURE if you are really sure:"
    read
    [ "$REPLY" == 'I AM ABSOLUTE SURE' ] || abort

    . ./config.sh || abort "can't source 'config.sh'"
    # step 1: uninstall and unlink all pkgs
    remove_pkgs || abort

    # step 2: remove smog directory
    rm -rvf "$MDD" || abort
    rm -rvf "$SMOG" || abort

    # step 3: remove directories if defined in config and if empty
    # (those are not necessarily owned by smog)
    #for d in PKG BIN LIB


}


# outdates vars!!
install() {

    # create symlink to smog
    mkdir -p $BIN
    # TODO: HOME_DIR is not defined
    ln -s $SMOG/smog $BIN/smog
    echo "export PATH=\"${BIN}:\$PATH\"" >> $HOME/.bashrc

    # create link to our libs
    mkdir -p "$LIB"
    # requires sudo
    sudo mkdir -p "$LD_DIR"
    sudo echo "$LIB" > "$LD_DIR/$LD_FILE"
}

# reject to run as root user
[ "$EUID" -eq 0 ] && abort "you can't run this as root"
[ $(id -u) -eq 0 ] 2>/dev/null && "you can't run this with sudo"

case $1 in
    help | -h | -help | --help )
        usage ;;
    version )
        version ;;
    undo )
        undo ;;
    -s )
        INTERACTIVE=
        bootstrap ;;
    '' )
        bootstrap ;;
    * )
        abort "invalid argument: $1" ;;
esac
    
