set -ex

sh tools/userland/makelib.sh libxtrix
sh tools/userland/makelib.sh libxk
sh tools/userland/makelib.sh libsrpc
sh tools/userland/makeprog.sh init
sh tools/userland/makeprog.sh hello
