# xtrix
xtrix is a unix-like microkernel designed with a minimal kernel interface.

## compiling

1. Set up git submodules: `git submodule init && git submodule update`
2. Just run `sh build.sh` to get the iso!

## development

In development the `dev.sh` script is used for building and starting xtrix in development mode. This connects to the cmd server, which you can start with `sh tools/cmd-server.sh`.
