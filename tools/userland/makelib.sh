set -ex

rm -rf build/user/$1 || true
mkdir -p build/user/$1
ldc2 -mattr=-sse,-sse2,-sse3,-ssse3 -code-model=small -I src \
    --relocation-model=static --gdwarf --oq \
    --od build/user/$1 `find src/$1 -type f | grep '\.d'` \
    -c --threads $(nproc) --betterC -mtriple=x86_64-elf
ld.lld -r build/user/$1/*.o -o build/$1.o
