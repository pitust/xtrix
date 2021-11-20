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
    r.rax = handle;
}
// lifetime(return value): the returned value is owned by the calling thread
Obj* su_get_handle(ulong h) {
    if (h >= 512) return getnull();
    return (*current.handles)[h];
}

__gshared char[8192] ke_log_buffer;
__gshared HashMap!(ulong, Chan*) channels;

void syscall_handler(ulong sys, Regs* r) {
    if (sys == 0) {
        ulong offset;
        char[] message = ke_log_buffer[0 .. r.rsi];
        current.vm.copy_out_of(r.rdi, message.ptr, r.rsi);
        printk("[user] {}", message);
    } else if (sys == 0x01) {
        VM* vm = alloc!VM;
        vm.vme = alloc!(VMEntry[256]);
        vm.lowhalf = cast(ulong[256]*)alloc!(ulong[512]);
        su_register_handle(r, &vm.obj);
    } else if (sys == 0x02) {
        VM* target_vm = cast(VM*)su_get_handle(r.rdi);
        MemRef* code = cast(MemRef*)su_get_handle(r.rsi);
        if (target_vm.type != ObjType.vm) { assert(false, "todo: error on wrong types in KeLoadELF"); }
        if (code.type != ObjType.memref) { assert(false, "todo: error on wrong types in KeLoadELF"); }
        if (code.size >= (1 << 20)) { assert(false, "todo: error on bounds in KeLoadELF"); }
        code.copy_to_phy(eslab);
        r.rax = load_elf(target_vm, eslab, code.size);
    } else if (sys == 0x03) {
        ulong offset = 0;
        do {
            r.rax = random_aslr();
        } while (current.vm.region_for(r.rax, offset));
    } else if (sys == 0x06) {
        // vm handle: rdi
        VM* target_vm = cast(VM*)su_get_handle(r.rdi);

        if (target_vm.type != ObjType.vm) { assert(false, "todo: error on wrong types in KeLoadELF"); }

        Thread* t = alloc!Thread;
        t.rsp0 = alloc!(ubyte[4096])();
        t.vm = target_vm;
        
        t.regs.cs = 0x1b;
        t.regs.flags = /* IF */ 0x200;
        t.regs.ss = 0x23;

        t.regs.rip = r.rsi;
        t.regs.rdi = r.rdx;
        t.regs.rsi = r.rcx;
        t.regs.rdx = r.r8;
        t.regs.rsp = r.r9;
        current.sleepgen += 999;
        printk("rip: {*}", t.regs.rip);
        memcpy(cast(byte*)t.tag.ptr, cast(immutable byte*)"new-thread\x00".ptr, 5);

        target_vm.rc++;
        t.handles = alloc!(Obj*[512])();

        create_thread(t);
        r.rax = 0;
    } else if (sys == 0x0b) {
        ulong offset;
        Memory* mr = Memory.allocate(r.rdi);
        su_register_handle(r, &mr.obj);
    } else if (sys == 0x0c) {
        MemRef* mr = MemRef.allocate(r.rsi);
        mr.copy_from_user_address(r.rdi);
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
    } else if (sys == 0x17) {
        if (r.rdi in channels) {
            Chan* c = channels[r.rdi];
            c.rc++;
            su_register_handle(r, &c.obj);
        } else {
            Chan* c = alloc!Chan;
            c.rc++;
            channels[r.rdi] = c;
            su_register_handle(r, &c.obj);
        }
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
    } else if (sys == 0x0e) {
        Obj* obj = su_get_handle(r.rdi);

        if (obj.type != ObjType.mem && obj.type != ObjType.memref) {
            printk("[user] warn: etype while handling KeReadMemory: not a mem/memref!");
            r.rax = cast(ulong)(error.ETYPE);
            return;
        }
        r.rax = cast(ulong)(error.ENOSYS);
        if (obj.type == ObjType.memref) {
            // addr, count, outaddr
            MemRef* memref = cast(MemRef*)obj;
            if (r.rsi != 0) {
                printk("[user] warn: einval while handling KeReadMemory: memrefs cannot be read at offset!");
                r.rax = cast(ulong)(error.ETYPE);
                return;
            }
            if (r.rdx != memref.size) {
                printk("[user] warn: einval while handling KeReadMemory: memrefs cannot be read partially!");
                r.rax = cast(ulong)(error.ETYPE);
                return;
            }
            memref.copy_to_user_address(r.rdi);
            r.rax = 0;
        }
        return;
    } else if (sys == 0x23) {
        VM* target_vm = cast(VM*)su_get_handle(r.rdi);
        Obj* mem = su_get_handle(r.rsi);
        if (target_vm.type != ObjType.vm) { assert(false, "todo: error on wrong types in KeLoadELF"); }

        if (mem.type != ObjType.mem) {
            printk("[user] warn: etype while handling KeMapMemory/2: not a memory object!");
            r.rax = cast(ulong)(error.ETYPE);
            return;
        }
        Memory* m = cast(Memory*)mem;
        target_vm.map(r.rdx, m);
        copy_to_cr3(current.vm.lowhalf);
        r.rax = 0;
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
    } else if (sys == 0x28) {
        // addr, size
        MemRef* mref = MemRef.allocate(r.rsi);
        mref.copy_from_phy(r.rdi);
        su_register_handle(r, &mref.obj);
    } else if (sys == 0x29) {
        current.vm.copy_into(r.rdx, cast(void*)virt(r.rdi), r.rsi);
        r.rax = 0;
    } else if (sys == 0x2c) {
		while (true) {
			foreach (i; 0 .. r.rsi) {
				printk("KePoll is checking chan{}", i);
				ulong hpointer = r.rdi + i * 16;
				ulong handle;
				current.vm.copy_out_of(hpointer, &handle, 8);
	
				printk(" h: {}", handle);
				Obj* h = su_get_handle(handle);
				if (h.type != ObjType.chan) {
					assert(false, "incorrect handle and errors are not implemented yet");
				}
				Chan* c = cast(Chan*)h;
				bool* wake; Obj** resp;
				Obj* msg = c.dequeueInvoke(wake, resp);
				if (msg == null) continue;
				Responder* responder = alloc!Responder();
				su_register_handle(r, &responder.obj);
				if (r.rax < 0x1000) su_register_handle(r, msg);
				current.vm.copy_into(r.rdx, &i, 8);
				return;
			}
			current.sleepgen = system_sleep_gen + 1;
			asm { int 0xfe; }
		}
	} else {
        printk("[user] warn: enosys {x}", sys);
		r.rax = cast(ulong)(error.ENOSYS);
	}
}
