module xtrm.user.syscalls;

import xtrm.io;
import xtrm.obj.memory;
import xtrm.user.sched;
import xtrm.interrupt.regs;

void syscall_handler(ulong sys, Regs* r) {
    if (sys == 0) {
        if (r.rdi > 64) r.rdi = 64;

        ulong offset;
        char[64] messagebuf;
        char[] message = messagebuf[0 .. r.rdi];
        Memory* range = current.vm.region_for(r.rsi, offset);
        if (range == null) {
            printk("[user] warn: efault while handlink KeLog!");
            return;
        }
        range.read(offset, cast(ubyte[])message);

        printk("[user] {}", message);
    } else {
        printk("[user] warn: enosys {}", sys);
    }
}