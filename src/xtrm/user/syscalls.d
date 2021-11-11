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
import xtrm.memory;
import xtrm.cpu.cr3;
import xtrm.obj.obj;
import xtrm.obj.chan;
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
}

// lifetime(o): o is owned by the callee and lives for as long as the current thread object.
void su_register_handle(Regs* r, Obj* o) {
    Thread* c = current();
    long handle = c.allocateHandle();
    if (handle < 0) {
        printk("[user] warn: eagain while allocating a handle");
        r.rax = cast(ulong)(error.EAGAIN);
        return;
    }
    (*c.handles)[handle] = o;
    r.rax = handle;
}
// lifetime(return value): the return value is owned by the current thread at the time of the call
Obj* su_get_handle(ulong h) {
    if (h >= 512) return getnull();
    return (*current.handles)[h];
}

__gshared char[8192] ke_log_buffer;

void syscall_handler(ulong sys, Regs* r) {
    if (sys == 0) {
        ulong offset;
        char[] message = ke_log_buffer[0 .. r.rsi];
        Memory* range = current.vm.region_for(r.rdi, offset);
        if (r.rsi > 8192) r.rsi = 8192;
        if (range == null) {
            printk("[user] warn: efault while handling KeLog!");
            return;
        }
        range.read(offset, cast(ubyte[])message);

        printk("[user] {}", message);
    } else if (sys == 0x03) {
        ulong offset = 0;
        do {
            r.rax = random_aslr();
        } while (current.vm.region_for(r.rax, offset));
    } else if (sys == 0x0b) {
        ulong offset;
        Memory* mr = Memory.allocate(r.rdi);
        su_register_handle(r, &mr.obj);
    } else if (sys == 0x0c) {
        ulong offset;
        Memory* range = current.vm.region_for(r.rdi, offset);
        if (range == null) {
            printk("[user] warn: efault while handling KeAllocateMemRefObject!");
            r.rax = cast(ulong)(error.EFAULT);
            return;
        }
        MemRef* mr = MemRef.allocate(r.rsi);
        mr.copy_from(range, offset);
        su_register_handle(r, &mr.obj);
    } else if (sys == 0x0d) {
        Obj* h = su_get_handle(r.rdi);
        r.rax = 0;
        if (h.type == ObjType.mem) {
            r.rax = (cast(Memory*)h).pgCount << 12;
        }
        if (h.type == ObjType.memref) {
            r.rax = (cast(MemRef*)h).size;
        }
        if (r.rax == 0) {
            printk("[user] warn: etype while handling KeGetMemObjectSize!");
            r.rax = -error.ETYPE;
        }
    } else if (sys == 0x14) {
        if (r.rdi > 512) r.rax = ObjType.nullobj;
        else if ((*current.handles)[r.rdi] == null) r.rax = ObjType.nullobj;
        else r.rax = (*current.handles)[r.rdi].type;
    } else if (sys == 0x16) {
        Chan* chan = alloc!Chan;
        su_register_handle(r, &chan.obj);
    } else if (sys == 0x1b) {
        Obj* chan = su_get_handle(r.rdi);
        Obj* data = su_get_handle(r.rsi);

        if (chan.type != ObjType.chan) {
            printk("[user] warn: etype while handling KePushMessage: not a channel!");
            r.rax = cast(ulong)(error.ETYPE);
            return;
        }
        Chan* c = cast(Chan*)chan;
        c.enqueue(data);
        r.rax = 0;
        return;
    } else if (sys == 0x1c) {
        Obj* chan = su_get_handle(r.rdi);

        if (chan.type != ObjType.chan) {
            printk("[user] warn: etype while handling KePopMessage: not a channel!");
            r.rax = cast(ulong)(error.ETYPE);
            return;
        }
        Chan* c = cast(Chan*)chan;
        if (!c.peek()) {
            assert(false, "TODO: delaying on a pop");
        }
        su_register_handle(r, c.dequeue());
        return;
    } else if (sys == 0x25) {
        Obj* mem = su_get_handle(r.rdi);

        if (mem.type != ObjType.mem) {
            printk("[user] warn: etype while handling KeMapMemory/2: not a memory object!");
            r.rax = cast(ulong)(error.ETYPE);
            return;
        }
        Memory* m = cast(Memory*)mem;
        current.vm.map(r.rsi, m);
        copy_to_cr3(current.vm.lowhalf);
        r.rax = 0;
        return;
    } else {
        printk("[user] warn: enosys {x}", sys);
		r.rax = cast(ulong)(error.ENOSYS);
	}
}
