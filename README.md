
## smog
**smog** (**s**ource **m**anager **o**ver **g**it) is a source-code manager with some features of a package manager.

*Why smog?* I download and build software from git-repositories quite often and it is common that I modify the source-code. I needed a tool to solve the following:
* store each repo in a unique path on my computer (à la `go get`)
* easily check for remote updates
* easily update while maintaining my local changes

Meanwhile, I dislike `sudo make install`, especially for software that's not stable or I don't fully trust. Therefore, additionally, I wanted the tool to be able to:
* create symlinks to binaries and add to my `PATH`
* create symlinks to ELF libraries and enable `ldconfig` to cache them
* and abviously: easily cleanup these symlinks and remove the repository.

smog solves these issues by creating plain-text [metadata](#metadata) files for each _smog package_ and utilizing `git` with basic bash commands for maintaining them.

smog is [configured](#configure) by a few bash variables and it manages each package in either _tage_ or _branch_ [mode](#modes).

As a proof-of-concept, smog can manage itself as a _smog package_, meaning that you upgrade smog with the command `smog update smog`.

## Features

smog is best described by its main commands:

* `smog add URL` - clones a git repository and creates package metadata
* `smog show PKG` - shows metadata of a package
* `smog path PKG` - prints path of the local repository 
* `smog list` - lists all packages
* `smog sync` - lists all packages that have remote updates
* `smog update PKG` - updates local repository with remote changes
* `smog link PKG` - scans for binaries, executables and sharedlibs and creates symbolic links in the directories `$BIN` and `$LIB`

## Installation

### Requirements

- `git`
- `bash` (>= `4.3`) and a few common bash programs:
    * `test`, `cat`, `cut`, `ln`, `readlink`, `tr`, etc.
    * `grep`, `sed`, `file`, `xargs` (for asynchronous syncing)
- optionally `vim` or any other text editor
- the bootstrapper additionally requires `wget`

### Bootstrapping

This is the recommended way of installation. The bootstrapper will install and configure smog as a package of itself.

Just download the bootstrapper script and run with bash:

```bash
wget -nv https://raw.githubusercontent.com/vgratian/smog/master/bootstrab
bash bootstrap
rm bootstrap
```

If you don't want to be asked too many questions, use the `-s` flag:

```bash
bash bootstrap -s
```

### Manual Installation

Clone the respository in a location of your choice and copy the default config file to `config.sh`:

```bash
git clone https://github.com/vgratian/smog
cd smog
cp config-def config
```

Edit `config.sh`: at the very least, you should make sure the following:
* `$SMOG` matches the the directory where smog is cloned
* the directories `$PKG` and `$MDD` exist and are empty
* the directories `$BIN` and `$LIB` exist, or these variables are unset (`""`)

Additionally, you might want to:
* add [the autocompletion script](bash-autocomplete) to your `.bashrc`
* update your `$PATH` to include the directory `$BIN` (if set)
* update `ldconfig` to include the directory `$LIB` (if set)

## Usage

For a comprehensive list of commands and options, simply run `smog help`. 

### Add and link a package
Here is a typical example of using smog. First, I add dwm, my favorite window-manager:

```bash
smog add git://git.suckless.org/dwm
```

Secondly, I want to build `dwm`. This is not done smog, and I'll do it myself:

```bash
cd `smog path dwm`
make dwm
```

Finallly, I want to add the binary `dwm` to my `PATH`, and I do this with smog:
```bash
smog link dwm
```

### Query packages

To get a plain list of packages, run `smog list`. For a more detailed list, run `smog list -m`. To show details of a package, run `smog show PKG` or `smog show PKG -m`.

Similarly, for a list of updatable packages, run `smog sync`. For a list of all packages and their status, run `smog sync -m` (packages that are up-to-date, will be printed in grey). To sync a single package, run `smog sync PKG`.


### Remove a package

To remove a package and all of its files, run `smog remove PKG`. If smog created symlinks for PKG, it will first unlink them, delete the local repostory and metadata file of the package.

If you only want to remove symlinks of a package, run `smog unlink PKG`.

## Config

smog is configured by a set of bash variables that are sourced from `config`. Default values are provided in [`config-def`](config-def).


| variable           | type           | description                                                                    |
|--------------------|----------------|--------------------------------------------------------------------------------|
| `GIT`              | command name   | git command invoked to clone, manage and query git repositories.<br />normally this is just `git`, I use Void's `chroot-git`. |
| `EDITOR`           | command name   | text editor to allow user to modify a generated list.<br />default is `vim`, but you shoud be able to use `vi`, `nano` or a GUI text editor. |
| `ROOT`             | directory path | The parent of the directories that smog operates on (described below).<br />this can't be empty, should be writable and is normally `$HOME`.<br />allows you to chroot or sandbox smog.|
| `BIN` (_optional_) | directory path | directory where symlinks are created to binaries and exectubles (when you run `smog link PKG`). |
| `LIB` (_optional_) | directory path | directory where symlinks are created to shared libraries (when you run `smog link PKG`). |
| `PKG`              | directory path | directory where repositories are cloned (when you run `smog add URL`). |
| `SMOG`             | directory path | smog home directory - containing the source-code and `config.sh`.<br />if you bootstrapped smog, this directory is `$PKG/github.com/vgratian/smog`. |
| `MDD`              | directory path | location of metadata files |
| `LOCALBRANCH`     | string         | name of the local working branch - smog will create this branch after cloning a repostory, this helps to isolate your local changes from the upstream source code and update the repository smoothly.<br />note: avoid names that might conflict remote branch names, such as `master`, `main`. |
| `NPROCS`           | integer        | number of processes when syncing packages (passed to `xargs`).<br />default is number of CPUs * 2, use `0` to run as many as possible.|
| `BASHRC` (_optional_)   | file path      | _only used for bootstrapping:_<br />if not empty, the bootstrapper will edit `$BASHRC` to:<ul><li>add `$BIN` to your `$PATH`</li><li>add [the autocompletion script](bash-autocomplete)</li></ul>|
| `LDSOCONF` (_optional_) | file path      | _only used for bootstrapping:_<br />if not empty and if `$LIB` is defined, the bootstrapper will, create a config file for `ldconfig` allowing it to cache sharedlibs in _smog packages_.<br />note: this is normally in `/etc/ld.so.conf.d/` and the bootstrapper might ask for sudo to create `LDSOCONF`. |

## Modes
Each  _smog package_, a.k.a. your local repository, is associated with a remote git [reference](https://git-scm.com/book/en/v2/Git-Internals-Git-References): either _tag_ or _branch_. This decides how the package is updated:

* ***branch mode***: package is updatable if new commit(s) are available on the remote branch. `smog update PKG` will pull these commits and merge to `$LOCALBRANCH`.
* ***tag mode***: package is updatable if tag(s) are available on the remote repository that appear to be more recent. `smog update PKG` will pull the most recent tag and merge to `$LOCALBRANCH`.

Since tags tend to be more stable, this is the preferred mode when new package is created. If no tags are available, smog will prefer the branch `master` or `main`. You can control this behaviour with the `-t`, `-b`, `-T <TAG>` and `-B <BRANCH>`. Examples:

* Add package `dino` in branch mode:
```bash
smog add https://github.com/dino/dino -b
```

* Add `dino` in branch mode and use branch `feature/handy`:
```bash
smog add https://github.com/dino/dino -B feature/handy
```

* Add package `dwm` in tag mode and use tag `6.0`:
```bash
smog add git://git.suckless.org/dwm -T 6.0
```

* Update `dwm` to tag `6.2`:
```bash
smog update dwm -T 6.2
```

## Metadata
Each package is defined by a plain-text metadata file in the directory `$MDD`. The basic variables are described below:

| variable          | type            | description                                              |
|-------------------|-----------------|----------------------------------------------------------|
| `url`             | string          | the address of the remote repository                     |
| `path`            | string          | relative path of local repository in `$PKG`              |
| `mode`            | string          | `tag` or `branch`                                        |
| `ref`             | string          | name of the remote reference                             |
| `sha`             | string          | (only in branch-mode) SHA-1 of the last commit we have pulled from the remote branch |

### Manipulating metadata
Normally you should not want to touch metadata files. But there are a few optional variables, that help to control how the package is managed (**warning: these might change in the future**):

| variable          | type            | description                                              |
|-------------------|-----------------|----------------------------------------------------------|
| `builddir`        | string          | subdirectory to scan when running `smog link PKG`        |
| `tag_pattern`     | regex           | only check matching tags when running `smog update PKG`  |

These variables can be changed with the unadvertised command `smog set PKG key=value`.

## Contributing

If you use smog, I would appreciate if you provide feedback or open an issue for a bug or feature request.

You are also welcome to open a merge request, if you want to contribute to this project.

If the project grows, it will be likely that bash is replaced by a compiled language.
