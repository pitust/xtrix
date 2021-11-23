#!/bin/sh

set -ex

rm -rf pack
mkdir -p pack/boot

cp build/*.elf pack/
cp assets/console.sfn pack
cp limine.cfg $HOME/limine/limine.sys $HOME/limine/limine-cd.bin $HOME/limine/limine-eltorito-efi.bin pack/boot/
xorriso -as mkisofs -b /boot/limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot /boot/limine-eltorito-efi.bin -efi-boot-part --efi-boot-image --protective-msdos-label pack -o xtrix.iso
limine-install xtrix.iso
