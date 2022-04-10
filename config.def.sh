# git command that smog will invoke to clone repositories
GIT=$(which git)

# text editor command
EDITOR=$(which vim)

# root directory for folders defined below
ROOT="$HOME"

# path of directory where smog will clone packages
PKG="pkg"

# directory where smog will create symlinks to binaries
# this is used when you invoke 'smoge reflect PKG'
BIN="bin"

# directory where smog will create symlinks to share libraries
LIB="lib"

# directory where smog itself will be cloned
SMOG="$PKG/gitlab.com/vgratian/smog"

# subdirectory where smog will store metadata of packages
MDD="$SMOG/mdd"

# name of the branch that smog will create after cloning a repository
# (such that your local changes don't mess with the upstream source code)
MASTERBRANCH="mastermind"

# number of processes to use when syncing packages (passed to xargs)
# default is number of CPUs * 2; use '0' to run as many as possible
NPROCS=$((`nproc`*2))

# path to file created to integrate smog with ldconfig
# empty means no file will be created
LDSOCONF="/etc/ld.so.conf.d/libsmog_${USER}.conf"

# path to your bashrc, used to update your PATH environment variable
# empty means don't update PATH
BASHRC=".bashrc"

