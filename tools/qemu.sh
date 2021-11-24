set -ex

sh tools/all.sh && reset

if [ ! -e .qemu-debugcon-addr ]; then
    echo "/dev/null" >.qemu-debugcon-addr
fi
clear >"$(cat .qemu-debugcon-addr)"
qemu-system-x86_64 -drive format=raw,file=xtrix.iso -debugcon "file:$(cat .qemu-debugcon-addr)" -s