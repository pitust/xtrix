set -e

if [ ! -e .qemu-debugcon-addr ]; then
    echo "/dev/null" >.qemu-debugcon-addr
fi
printf "\e[3g\ec\e[!p\e[?3;4l\e[4l\e>" >"$(cat .qemu-debugcon-addr)"
clear >"$(cat .qemu-debugcon-addr)"
qemu-system-x86_64 -drive format=raw,file=xtrix.iso -debugcon "file:$(cat .qemu-debugcon-addr)" -serial stdio -s -no-reboot
printf "\n[system reset]\n\n" >"$(cat .qemu-debugcon-addr)"
