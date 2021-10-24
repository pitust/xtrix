set -ex

rm -rf build/user/hello || true
mkdir -p build/user/hello
ldc2 -mattr=-sse,-sse2,-sse3,-ssse3 -code-model=small -I src \
    --relocation-model=static --gdwarf --oq \
    --od build `find src/progs/hello -type f | grep '\.d'` \
    -c --threads $(nproc) --betterC -mtriple=x86_64-elf
ld.lld build/*.o -o build/hello.elf -T src/userland.ld
