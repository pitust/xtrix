#!/bin/sh

set -ex

rm build/*.o || true
ldc2 -mattr=-sse,-sse2,-sse3,-ssse3 -code-model=kernel -I src \
    --relocation-model=static --gdwarf --oq \
    --od build `find src/xtrm -type f | grep '\.d'` \
    -c --threads $(nproc) --betterC -mtriple=x86_64-elf
nasm -felf64 src/boot.s -o build/boot.o
nasm -felf64 src/xtrm/interrupt/isr.s -o build/isrcommon.o
x86_64-elf-gcc -Iinc src/xtrm/ssfn.c -Iscalable-font2 -c -o build/c_ssfn.o
ld.lld build/*.o -o build/kernel -T src/kernel.ld
sh makeiso.sh