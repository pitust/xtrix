set -e

sh tools/all.sh && reset || exit

if [ ! -e .qemu-debugcon-addr ]; then
    echo "/dev/null" >.qemu-debugcon-addr
fi
clear >"$(cat .qemu-debugcon-addr)"
qemu-system-x86_64 -drive format=raw,file=xtrix.iso -debugcon "file:$(cat .qemu-debugcon-addr)" -serial stdio -s -no-reboot
printf "\n\n[system reset]\n\n" >"$(cat .qemu-debugcon-addr)"
