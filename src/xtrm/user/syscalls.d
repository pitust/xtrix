// xtrix system call handler
// Copyright (C) 2021 pitust <piotr@stelmaszek.com>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
module xtrm.user.syscalls;

import xtrm.io;
import xtrm.memory;
import xtrm.obj.chan;
import xtrm.obj.thread;
import xtrm.obj.memory;
import xtrm.user.sched;
import xtrm.interrupt.regs;

enum error : long {
	ETYPE = -1,
	EACCES = -2,
	ENOSYS = -3,
    EAGAIN = -4
}

__gshared char[8192] ke_log_buffer;

void syscall_handler(ulong sys, Regs* r) {
    if (sys == 0) {
        ulong offset;
        char[] message = ke_log_buffer[0 .. r.rdi];
        Memory* range = current.vm.region_for(r.rsi, offset);
        if (r.rdi > 8192) r.rdi = 8192;
        if (r.rdi > (range.pgCount << 12)) r.rdi = range.pgCount << 12;
        if (range == null) {
            printk("[user] warn: efault while handlink KeLog!");
            return;
        }
        range.read(offset, cast(ubyte[])message);

        printk("[user] {}", message);
    } else if (sys == 0x16) {
        Thread* c = current();
        long handle = c.allocateHandle();
        if (handle < 0) {
            printk("[user] warn: eagain while allocating a handle");
            r.rax = cast(ulong)(error.EAGAIN);
            return;
        }
        Chan* chan = alloc!Chan;
        c.handles[handle] = &chan.obj;
		r.rax = handle;
    } else {
        printk("[user] warn: enosys {x}", sys);
		r.rax = cast(ulong)(error.ENOSYS);
		printk("we set rax to {x}", r.rax);
	}
}
