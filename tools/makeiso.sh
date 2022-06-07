#!/bin/sh

set -ex

rm -rf pack
mkdir -p pack/boot

OUT="$1"
shift 1

cp "$@" pack/
cp $HOME/limine/limine.sys $HOME/limine/limine-cd.bin $HOME/limine/limine-cd-efi.bin pack/boot/
xorriso -as mkisofs -b /boot/limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot /boot/limine-cd-efi.bin -efi-boot-part --efi-boot-image --protective-msdos-label pack -o $OUT
limine-deploy $OUT
