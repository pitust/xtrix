trap 'echo "/dev/null" >.qemu-debugcon-addr; exit' INT TERM
echo "$(tty)" >.qemu-debugcon-addr
while [ true ]; do
    sleep 10000000
done