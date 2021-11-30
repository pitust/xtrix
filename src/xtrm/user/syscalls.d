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

enum XIDMessageType {
	complete,
	ul
}

struct XIDMessage {
	XIDMessageType ty;
	void* outbuf;
}

__gshared char[8192] ke_log_buffer;
__gshared ulong pid_start = 1;
__gshared HashMap!(ulong, Thread*) procs;
__gshared HashMap!(ulong, ulong*) xid_servers;
__gshared HashMap!(ulong, XIDMessage*) xidmsg;

void syscall_handler(ulong sys, Regs* r) {
	procs[current.pid] = current; // todo: this is overly heavy-handed
	r.rax = -9999;
    switch (sys) {
        case 0x00: {
            ulong offset;
            char[] message = ke_log_buffer[0 .. r.rsi];
            current.vm.copy_out_of(r.rdi, message.ptr, r.rsi);
            printk("\x1b[y]{}({})\x1b[w_0] {}", current.tag.ptr, current.pid, message);
            break;
        }
		case 0x01: {
			ulong addr = r.rdi; ulong len = r.rsi;
			Memory* m = Memory.allocate(len);
			current.vm.map(addr, m);
			copy_to_cr3(current.vm.lowhalf);
			r.rax = 0;
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
		case 0x03: {
			ulong pipeside = r.rdi; ulong pipeid = r.rsi;

			if (pipeside > 1) {
				printk("ps: {x}", pipeside);
				r.rax = error.EINVAL;
				return;
			}

			if (!pipeside) {
				// client
				ulong xid = (random_ulong() << 32) ^ random_ulong() ^ (random_ulong() >> 32);
				xid &= 0xffff_ffff_ffff;
				while (true) {
					if (pipeid in xid_servers && xid_servers[pipeid]) {
						*xid_servers[pipeid] = xid;
						r.rax = xid;
						system_sleep_gen += 1;
						printk("RR");
						return;
					}
					current.sleepgen = system_sleep_gen + 1;
					asm { int 0xfe; }
				}
			} else {
				// server
				while (pipeid in xid_servers && xid_servers[pipeid]) {
					current.sleepgen = system_sleep_gen + 1;
					asm { int 0xfe; }
				}
				ulong cid = 0;
				xid_servers[pipeid] = &cid;
				system_sleep_gen += 1;
				while (!cid) {
					current.sleepgen = system_sleep_gen + 1;
					asm { int 0xfe; }
				}
				xid_servers[pipeid] = null;
				system_sleep_gen += 1;

				assert(cid, "no cid set!");
				r.rax = cid;
				printk("TT");
				return;
			}
			break;
		}
		case 0x0a: {
			ulong xid = r.rdi; ulong msgdata = r.rsi;
			while (!(xid in xidmsg)) {
				current.sleepgen = system_sleep_gen + 1;
				asm { int 0xfe; }
			}
			while (!xidmsg[xid] || xidmsg[xid].ty != XIDMessageType.ul) {
				current.sleepgen = system_sleep_gen + 1;
				asm { int 0xfe; }
			}
			XIDMessage* msg = xidmsg[xid];
			*cast(ulong*)msg.outbuf = msgdata;
			msg.ty = XIDMessageType.complete;
			system_sleep_gen += 1;
			r.rax = 0;
			break;
		}
		case 0x0b: {
			ulong xid = r.rdi;
			if (!(xid in xidmsg))
				xidmsg[xid] = null;
			
			while (xidmsg[xid]) {
				current.sleepgen = system_sleep_gen + 1;
				asm { int 0xfe; }
			}
			XIDMessage msg;
			msg.ty = XIDMessageType.ul;
			ulong dat = 0;
			msg.outbuf = &dat;
			xidmsg[xid] = &msg;
			system_sleep_gen += 1;
			while (msg.ty == XIDMessageType.ul) {
				current.sleepgen = system_sleep_gen + 1;
				asm { int 0xfe; }
			}
			xidmsg[xid] = null;
			system_sleep_gen += 1;

			r.rax = dat;
			break;
		}
        case 0x10: {
            VM* newvm = alloc!VM;
            newvm.do_init();
            current.vm.cloneto(newvm);
            Thread* nt = alloc!Thread();
            nt.rsp0_virt = alloc_stack(nt.rsp0_phy);
            nt.vm = newvm;
            nt.regs = *r;
            nt.regs.rax = 0;
            nt.regs.rip += 2;
            nt.pid = ++pid_start;
            nt.ppid = current.pid;
            memcpy(cast(byte*)nt.tag, cast(const byte*)"forked ", 7);
            memcpy((cast(byte*)nt.tag) + 7, cast(const byte*)current.tag, nt.tag.length - 7);
            r.rax = nt.pid;
            create_thread(nt);
            break;
        }
		case 0x11: {
		//     sys_exec(elfptr, elfsz, argc, argv)
             ulong elfptr = r.rdi; ulong elfsz = r.rsi; ulong argc = r.rdx; ulong argv = r.rcx;
			
			VM* vm = current.vm;
			char[256]*[16] argvd;
			foreach (i; 0 .. argc) {
				char[256]* c = argvd[i] = alloc!(char[256]);
				char* str = (*c).ptr;
				ulong pointer = argv + i * 8;
				vm.copy_out_of(pointer, &pointer, 8);
				vm.copy_out_of(pointer, str, 256);
			}
			
			if (elfsz > (1 << 20)) {
				assert(false, "ELF max size is 2mb");
			}
			vm.copy_out_of(elfptr, cast(void*)virt(eslab), elfsz);
			vm.die();
			free(vm);
			vm = alloc!VM;
            vm.do_init();
			memset(cast(byte*)vm.lowhalf.ptr, 0, 2048);
			ulong e_entry = load_elf(vm, eslab, elfsz);
			current.vm = vm;
			memset(cast(byte*)&current.regs, 0, Regs.sizeof);
			
			enum STACK_SIZE = 0x4000;
			Memory* stack = Memory.allocate(STACK_SIZE);
			vm.map(0xfe0000000, stack);
			current.regs.rip = e_entry;
			current.regs.cs = 0x1b;
			current.regs.flags = 0x200;
			current.regs.ss = 0x23;
			current.regs.rsp = 0xfe0000000 + STACK_SIZE;
            current.regs.rip -= 2;
			copy_to_cr3(vm.lowhalf);

			memcpy(cast(byte*)current.tag.ptr, cast(const byte*)"<unnamed>", 10); 

            ulong argvp = (current.regs.rsp -= argc * 8);
			foreach (i; 0 .. argc) {
				if (i == 0) {
					char* str = (*argvd[i]).ptr;
					char* so = current.tag.ptr;
					while (*str) { *so++ = *str++; }
					*so = 0;
				}
                ulong len = strlen((*argvd[i]).ptr);
                current.regs.rsp -= len + 1;
                (*argvd[i]).ptr[len] = 0;
                vm.copy_into(current.regs.rsp, (*argvd[i]).ptr, len + 1);
                ulong ptr = current.regs.rsp;
                vm.copy_into(argvp + i * 8, &ptr, 8);
                
				free(argvd[i]);
			}
            current.regs.rsp -= current.regs.rsp & 0x0f;
            current.regs.rsp -= 0x10;
            current.regs.rdi = argc;
            current.regs.rsi = argvp;
			*r = current.regs;

			break;
        }
        case 0x13: {
            ulong phy = r.rdi; ulong vaddr = r.rsi; ulong len = r.rdx;
            if (phy == 0x6b7a0db87ad4d3c1) phy = saddr;
            current.vm.copy_into(vaddr, cast(void*)virt(phy), len);
            r.rax = 0;
            break;
        }
		case 0x14: {
			if (current.pid == 1) assert(false, "attempting to kill init!");
			ulong exit_code = r.rdi;
			Thread* parent;
			while (true) {
				if (current.ppid !in procs) {
					assert(false, "todo: reparenting of orphans");
				}
				parent = procs[current.ppid];
				if (parent.is_wfor == current.pid || parent.is_wfor == 1) {
					break;
				}
				current.sleepgen = system_sleep_gen + 1;
				asm { int 0xfe; }
			}
			system_sleep_gen += 1;
			current.vm.die();
			free(current.vm);
			parent.is_wfor = 0;
			parent.waitpid = current.pid;
			parent.waitcode = exit_code;
			current.suicide = true;
			asm { int 0xfe; }
			assert(false, "cannot reschedule");
			break;
		}
		case 0x15: {
			current.is_wfor = /* everything */ 1;
			while (current.is_wfor) {
				system_sleep_gen += 1;
				current.sleepgen = system_sleep_gen + 1;
				asm { int 0xfe; }
			}
			r.rax = current.waitpid;
			r.rbx = current.waitcode;
			return;
		}
		default: {
			printk("\x1b[y]{}({})\x1b[w_0] enosys {x}", current.tag.ptr, current.pid, sys);
			r.rax = cast(ulong)(error.ENOSYS);
			break;
		}
	}
}
