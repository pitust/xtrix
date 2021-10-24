set -ex

sh tools/all.sh && reset && qemu-system-x86_64 -hda extreme.iso -debugcon stdio -s