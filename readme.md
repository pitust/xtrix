# xtrix
xtrix is a unix-like microkernel designed with a minimal kernel interface.

## compiling

1. Set up git submodules: `git submodule init && git submodule update`
2. Apply patches: `patch phobos.patch`
3. Just run `sh build.sh` to get the iso or `sh dev.sh` for build+run (in development mode)
