// xtrix kernel entrypoint
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
module xtrm.kernel;

import xtrm.io;
import xtrm.rng;
import xtrm.util;
import xtrm.kdbg;
import xtrm.memory;
import xtrm.obj.vm;
import xtrm.stivale;
import xtrm.support;
import xtrm.cpu.cr3;
import xtrm.cpu.gdt;
import xtrm.obj.obj;
import xtrm.user.elf;
import xtrm.obj.thread;
import xtrm.user.sched;
import xtrm.obj.memory;
import xtrm.interrupt.regs;
import xtrm.interrupt.idt;
import xtrm.interrupt.lapic;

enum BORDER = 16;
enum BORDERx2 = BORDER * 2;
enum BORDERx4 = BORDER * 4;

uint rgb(ubyte r, ubyte b, ubyte g) {
	return ((cast(uint)r) << 16) | ((cast(uint)g) << 8) | ((cast(uint)b) << 0);
}

void init_mman(StivaleStruct* struc) {
	E820Entry[] t = ArrayRepr!(E820Entry).from(struc.memory_map_addr, struc.memory_map_entries).into();
	ulong mem = 0;
	foreach (E820Entry e; t) {
		random_mixseed(cast(ulong)e.base + e.type);
		random_mixseed(cast(ulong)e.length + e.type);
		random_mixseed(cast(ulong)e.base + e.length);
		if (e.type == 1) {
			mem += e.length;
			if (!eslab && e.length > (1 << 20)) {
				e.length -= (1 << 20);
				eslab = e.base;
				e.base += (1 << 20);
			}
			foreach (iter; 0..(e.length >> 12)) {
				add_to_pool(*get_pool("pool/page"), cast(void*)(0xffff800000000000 + e.base + (iter << 12)));
			}
		}
	}
	assert(eslab, "Cannot allocate the ESLAB!");
}

extern (C) void kmain(StivaleStruct* struc) {
	saddr = cast(ulong)struc;
	init_low_half();
	random_mixseed(struc.epoch);

	StivaleModule* init = null;

	printk("Hello, kernel!");
	ulong i = 0;
	StivaleModule* mod = struc.modules;
	while (i < struc.module_count) {
		if (mod.name[0] == 0) {
			assert(false, "No anonymous modules pls");
		}
		random_mixseed(cast(ulong)mod.name.ptr);
		random_mixseed(cast(ulong)mod.begin);
		random_mixseed(cast(ulong)mod.end);
		if (strisequal(mod.name.ptr, "font")) {
			ssfnc_do_init(mod.begin,
				struc.framebuffer_addr + struc.framebuffer_pitch * BORDER + BORDERx4,
				struc.framebuffer_width - BORDERx2,
				struc.framebuffer_height - BORDERx2,
				struc.framebuffer_pitch
			);
			random_mixseed(cast(ulong)struc.framebuffer_addr);
			random_mixseed(struc.framebuffer_width + struc.framebuffer_pitch);
			random_mixseed(struc.framebuffer_height);
			
			io_fonts_initialized(struc);
			// this w_0 is needed because there is some startup bs
			printk("\x1b[w_0]Welcome to \x1b[r]xtrix!\x1b[w_0]  Copyright (C) 2021  pitust");
			printk("This program comes with ABSOLUTELY NO WARRANTY; for details type `ktool --gpl w'.");
			printk("This is free software, and you are welcome to redistribute it");
			printk("under certain conditions; type `ktool --gpl c' for details.\n");
		}
		if (strisequal(mod.name.ptr, "init")) {
			init = mod;
		}
		
		i++;
		mod = mod.next;
	}

	if (!init) assert(false, "no init :death:");

	_printf("Discovering memory regions...         "); init_mman(struc); printk("\x1b[g][done]");
	_printf("Initializing the scheduler...         "); init_sched(); printk("\x1b[g][done]");
	_printf("Initializing the local APIC...        "); init_lapic(); printk("\x1b[g][done]");
	_printf("Initializing the GDT...               "); init_gdt(); printk("\x1b[g][done]");
	_printf("Initializing the IDT...               "); init_idt(); printk("\x1b[g][done]");
	_printf("Initializing the Serial ports...      "); 
	if (serial_init()) {
		printk("\x1b[r][failed]");
		printk("warning: kdbg cannot function");
	} else {
		printk("\x1b[g][done]");
	}
	memory_stats();

	Regs r;
	r.cs = 0x1b;
	r.flags = /* IF */ 0x200;
	r.ss = 0x23;

	Thread* t = alloc!Thread;
	// init is init's own parent. don't question this. not worth it.
	t.ppid = 1;
	t.rsp0_virt = alloc_stack(t.rsp0_phy);
	t.vm = alloc!VM;
	t.vm.do_init();
	t.pid = 1;

	ulong e_entry = load_elf(t.vm, cast(ulong)init.begin, init.end-init.begin);

	enum STACK_SIZE = 0x4000;
	Memory* stack = Memory.allocate(STACK_SIZE);
	t.vm.map(0xf_e000_0000, stack);
	r.rip = e_entry;
	r.rdi = cast(ulong)cast(uint)struc;
	r.rsp = 0xfe0000000 + STACK_SIZE;
	memcpy(cast(byte*)t.tag.ptr, cast(const byte*)"init\x00".ptr, 5);

	t.regs = r;

	create_thread(t);

	while (true) {
		asm { cli; int 0xfe; }
	}
}
