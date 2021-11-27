set -ex

set -e
if [ ! -e builddir ]; then
    meson builddir --cross cross.ini
fi

set -ex
cd builddir && ninja && cd ..
cp builddir/init.elf build
# cp builddir/hello.elf build

# sh tools/userland/makelib.sh libxtrix
# sh tools/userland/makelib.sh libxk
# sh tools/userland/makelib.sh libsrpc
# sh tools/userland/makeprog.sh init srpc
# sh tools/userland/makeprog.sh hello
