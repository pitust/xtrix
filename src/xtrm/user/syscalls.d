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
import xtrm.rng;
import xtrm.util;
import xtrm.memory;
import xtrm.obj.vm;
import xtrm.cpu.cr3;
import xtrm.obj.obj;
import xtrm.support;
import libxk.hashmap;
import xtrm.obj.chan;
import xtrm.user.elf;
import xtrm.obj.thread;
import xtrm.obj.memory;
import xtrm.user.sched;
import xtrm.interrupt.regs;

enum error : long {
	ETYPE = -1,
	EACCES = -2,
	ENOSYS = -3,
    EAGAIN = -4,
    EFAULT = -5,
    EINVAL = -6,
}

private __gshared ulong khbase = 0;
private ulong su_offset_handle(ulong handle) {
    if (!khbase) khbase = random_ulong() & 0xfff0_0000; // this is not for security but for debuggability
    return handle + khbase;
}
private ulong su_unoffset_handle(ulong handle) {
    if (!khbase) khbase = random_ulong() & 0xfff0_0000; // this is not for security but for debuggability
    return handle - khbase;
}

// lifetime(o): o is owned by the callee and is transferred to the caling thread.
void su_register_handle(Regs* r, Obj* o) {
    Thread* c = current();
    long handle = c.allocateHandle();
    if (handle < 0) {
        printk("[user] warn: eagain while allocating a handle");
        r.rax = cast(ulong)(error.EAGAIN);
        return;
    }
    (*c.handles)[handle] = o;
    r.rax = su_offset_handle(handle);
}
// lifetime(return value): the returned value is owned by the calling thread
Obj* su_get_handle(ulong h) {
    h = su_unoffset_handle(h);

    if (h >= 512) return getnull();
    Obj* handle = (*current.handles)[h];
    if (!handle) return getnull();
    return handle;
}

__gshared char[8192] ke_log_buffer;
__gshared HashMap!(ulong, Chan*) channels;

void syscall_handler(ulong sys, Regs* r) {
    if (sys == 0) {
        ulong offset;
        char[] message = ke_log_buffer[0 .. r.rsi];
        current.vm.copy_out_of(r.rdi, message.ptr, r.rsi);
        printk("[user] {}", message);
    } else {
        printk("[user] warn: enosys {x}", sys);
		r.rax = cast(ulong)(error.ENOSYS);
	}
}
