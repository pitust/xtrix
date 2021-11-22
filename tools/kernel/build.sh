#!/bin/sh

set -ex

rm -rf build/kernel || true
mkdir -p build/kernel build/kcache
ldc2_wrap() {
    ldc2 --cache=build/kcache -mattr=-sse,-sse2,-sse3,-ssse3 -code-model=kernel -I src \
        -I phobos --relocation-model=static --gdwarf --oq \
        --od build/kernel `find src/xtrm src/libxk -type f | grep '\.d'` \
        -c --threads $(nproc) --betterC -mtriple=x86_64-elf "$@"
}
if [ "$KERNEL_VER_SMOOTHSTART" = 1 ]; then
    ldc2_wrap "--d-version=SmoothStart"
else
    ldc2_wrap
fi
nasm -gdwarf -felf64 src/boot.s -o build/kernel/boot.o
nasm -gdwarf -felf64 src/xtrm/interrupt/isr.s -o build/kernel/isrcommon.o
clang -target x86_64-elf -Iinc src/xtrm/ssfn.c -Iscalable-font2 -c -o build/kernel/c_ssfn.o
ld.lld build/kernel/*.o -o build/kernel.elf -T src/kernel.ld
