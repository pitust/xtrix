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
import xtrm.util;
import xtrm.util;
import xtrm.memory;
import xtrm.stivale;
import xtrm.support;
import xtrm.cpu.cr3;
import xtrm.cpu.gdt;
import xtrm.obj.vm;
import xtrm.obj.obj;
import xtrm.obj.thread;
import xtrm.user.sched;
import xtrm.obj.memory;
import xtrm.interrupt.regs;
import xtrm.interrupt.idt;
import xtrm.interrupt.lapic;


uint rgb(ubyte r, ubyte b, ubyte g) {
    return ((cast(uint)r) << 16) | ((cast(uint)g) << 8) | ((cast(uint)b) << 0);
}

void init_mman(StivaleStruct* struc) {
    E820Entry[] t = ArrayRepr!(E820Entry).from(struc.memory_map_addr, struc.memory_map_entries).into();
    ulong mem = 0;
    foreach (E820Entry e; t) {
        if (e.type == 1) {
            mem += e.length;
            foreach (iter; 0..(e.length >> 12)) {
                add_to_pool(*get_pool("pool/page"), cast(void*)(0xffff800000000000 + e.base + (iter << 12)));
            }
        }
    }
}

extern (C) void kmain(StivaleStruct* struc) {
    init_low_half();

    StivaleModule* init = null;

    printk("Hello, kernel!");
    ulong i = 0;
    StivaleModule* mod = struc.modules;
    while (i < struc.module_count) {
        if (mod.name[0] == 0) {
            assert(false, "No anonymous modules pls");
        }
        if (strisequal(mod.name.ptr, "font")) {
            ssfnc_do_init(mod.begin, struc.framebuffer_addr, struc.framebuffer_width, struc.framebuffer_height, struc
                    .framebuffer_pitch);
            
            io_fonts_initialized();
            printk("Welcome to \x1b[r]xtrix!\x1b[w_0]  Copyright (C) 2021  pitust");
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

    memory_stats();

    Regs r;
    r.cs = 0x1b;
    r.flags = /* IF */ 0x200;
    r.ss = 0x23;

    Thread* t = alloc!Thread;
    t.vm = alloc!VM;
    t.rsp0 = alloc!(ubyte[4096])();
    t.vm.vme = alloc!(VMEntry[256]);
    t.vm.lowhalf = cast(ulong[256]*)alloc!(ulong[512]);

    ulong addr = cast(ulong)virt(init.begin);
    ulong len = init.end - init.begin;
    ubyte[] data = ArrayRepr!(ubyte).from(cast(ubyte*)addr, len).into();

    enum off_e_entry = 24;
    enum off_e_phoff = off_e_entry + 8;
    enum off_e_phentsize = off_e_phoff + 8 + 8 + 4 + 2;
    enum off_e_phnum = off_e_phentsize + 2;

    enum off_p_type = 0;
    enum off_p_offset = 8;
    enum off_p_vaddr = off_p_offset + 8;
    enum off_p_filesz = off_p_vaddr + 16;
    enum off_p_memsz = off_p_filesz + 8;

    ulong e_entry = *cast(ulong*)&data[off_e_entry];
    ushort e_phnum = *cast(ushort*)&data[off_e_phnum];
    ushort e_phentsize = *cast(ushort*)&data[off_e_phentsize];
    ulong e_phoff = *cast(ulong*)&data[off_e_phoff];

    foreach (phdr; 0 .. e_phnum) {
        ulong curphoff = e_phoff + e_phentsize * phdr;

        uint p_type = *cast(uint*)&data[curphoff + off_p_type];
        ulong p_offset = *cast(ulong*)&data[curphoff + off_p_offset];
        ulong p_vaddr = *cast(ulong*)&data[curphoff + off_p_vaddr];
        ulong p_filesz = *cast(ulong*)&data[curphoff + off_p_filesz];
        ulong p_memsz = *cast(ulong*)&data[curphoff + off_p_memsz];

        if (p_type != 1) continue;
        Memory* mm = Memory.allocate(p_memsz);
        mm.write(0, ArrayRepr!(ubyte).from(&data[p_offset], p_filesz).into());

        serial_printk("copy {x} bytes @ {*} -> {*}", p_filesz, p_offset, p_vaddr);
        if (p_memsz != p_filesz) serial_printk("set {x} bytes @ {*}", p_memsz - p_filesz, p_offset + p_filesz);
        t.vm.map(p_vaddr, mm);
        mm.release(); // release handle on the stack
    }
    Memory* stack = Memory.allocate(0x4000);
    t.vm.map(0xfe0000000, stack);
    r.rip = e_entry;
    r.rsp = 0xfe0004000;
    stack.release();

    t.handles = alloc!(Obj*[512])();
    t.regs = r;

    create_thread(t);

    while (true) {
        asm { cli; int 0xfe; }
    }
}
