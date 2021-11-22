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
import xtrm.user.elf;
import xtrm.obj.thread;
import xtrm.obj.memory;
import xtrm.user.sched;
import xtrm.interrupt.regs;

enum error : long {
	EACCES = -1,
	ENOSYS = -2,
    EAGAIN = -3,
    EFAULT = -4,
    EINVAL = -5,
}

__gshared char[8192] ke_log_buffer;

void syscall_handler(ulong sys, Regs* r) {
    r.rax = -9999;
    switch (sys) {
        case 0x00: {
            ulong offset;
            char[] message = ke_log_buffer[0 .. r.rsi];
            current.vm.copy_out_of(r.rdi, message.ptr, r.rsi);
            printk("[user] {}", message);
            break;
        }
        case 0x02: {
            ulong phy = r.rdi; ulong virt = r.rsi; ulong len = r.rdx;
            foreach (i; 0 .. (len + 4096) >> 12) {
                current.vm.map(virt + (i << 12), phy + (i << 12));
            }
            r.rax = 0;
            break;
        }
        case 0x10: {
            VM* newvm = alloc!VM;
            newvm.entries = alloc!(VMEntry[256]);
            newvm.lowhalf = cast(ulong[256]*)alloc!(ulong[512]);
            current.vm.cloneto(newvm);
            Thread* nt = alloc!Thread();
            nt.rsp0_virt = alloc_stack(nt.rsp0_phy);
            nt.vm = newvm;
            nt.regs = *r;
            nt.regs.rax = 0;
            nt.regs.rip += 2;
            memcpy(cast(byte*)nt.tag, cast(const byte*)"forked ", 7);
            memcpy((cast(byte*)nt.tag) + 7, cast(const byte*)current.tag, nt.tag.length - 7);
            r.rax = 69;
            create_thread(nt);
            break;
        }
        //     sys_exec(elfptr, elfsz, argc, argv)
        //     ulong elfptr = r.rdi; ulong elfsz = r.rsi; ulong argc = r.rdx; ulong argv = r.rdx;

        //     curre
        //     break;
        // }
        //     break;
        // }
        case 0x13: {
            ulong phy = r.rdi; ulong vaddr = r.rsi; ulong len = r.rdx;
            if (phy == 0x6b7a0db87ad4d3c1) phy = saddr;
            current.vm.copy_into(vaddr, cast(void*)virt(phy), len);
            r.rax = 0;
            break;
        }
        default: {
            printk("[user] warn: enosys {x}", sys);
            r.rax = cast(ulong)(error.ENOSYS);
            break;
        }
    }
}
