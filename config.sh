#!/bin/bash

GIT=$(which git)
EDITOR=$(which vim)

MD="$HOME/smog/md"
PKG="$HOME/pkg"
BIN="$HOME/bin"
LIB="$HOME/lib"

NTHREADS=$((`nproc`*2))

MASTERBRANCH="mastermind"
