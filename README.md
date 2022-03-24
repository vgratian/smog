
**CODE IS BEING REFACTORED -- DON'T USE OR UPDATE**

**smog** (**s**ource **m**anager **o**ver **g**it) is a utility for maintaining and updating packages that I download from various git-repositories and often have modified the source-code.

smog is not a package manager, since:
- it does not download binaries or build packages
- it does not handle dependencies

rather, it is a meta-package manger, since:
- it creates and maintains metadata files for your cloned repos
- it allows running binaries without install (e.g. the `reflect` command creates symlinks to binaries)
- it allows to conveniently update packages

currently this utility is not stable and very likely I will move it to anther language.

### Requirements

- `git`
- `bash` (>= `4.3`)
- a few common bash commands:
    * from GNU coreutils: `[`, `cat`, `cut`, `ln`, `readlink`, `tr`, etc.
    * `getopts`
    * `sed`
    * `grep`
    * `file`
    * `xargs` (for asynchronous syncing)

