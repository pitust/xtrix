set -ex

rm -rf build/user/$1 || true
mkdir -p build/user/$1
ldc2 -mattr=-sse,-sse2,-sse3,-ssse3 -code-model=small -I src \
    -I phobos --relocation-model=static --gdwarf --oq \
    --od build/user/$1 `find src/progs/$1 -type f | grep '\.d'` \
    -c --threads $(nproc) --betterC -mtriple=x86_64-linux-gnu --flto=full
A0="$1"
shift
ld.lld $(printf "build/lib%s.o\n" xtrix xk $@) build/user/$A0/*.o -o build/$A0.elf -T src/userland.ld
