set -ex

sh tools/all.sh && reset && qemu-system-x86_64 -drive format=raw,file=xtrix.iso -debugcon stdio -s