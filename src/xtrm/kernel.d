module xtrm.kernel;

import xtrm.io;
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

    printk("Hello, kernel!");
    ulong i = 0;
    StivaleModule* mod = struc.modules;
    while (i < struc.module_count) {
        if (mod.name[0] == 0) {
            assert(false, "No anonymous modules pls");
        }
        if (strisequal(mod.name.ptr, "font.sfn")) {
            ssfnc_do_init(mod.begin, struc.framebuffer_addr, struc.framebuffer_width, struc.framebuffer_height, struc
                    .framebuffer_pitch);
            
            io_fonts_initialized();
            printk("Welcome to \x1b[r]xtrix!\x1b[w_0]  Copyright (C) 2021  pitust");
            printk("This program comes with ABSOLUTELY NO WARRANTY; for details type `ktool --gpl w'.");
            printk("This is free software, and you are welcome to redistribute it");
            printk("under certain conditions; type `ktool --gpl c' for details.\n");
        }
        
        i++;
    }

    printf("Discovering memory regions...         "); init_mman(struc); printk("\x1b[g][done]");
    printf("Initializing the scheduler...         "); init_sched(); printk("\x1b[g][done]");
    printf("Initializing the local APIC...        "); init_lapic(); printk("\x1b[g][done]");

    memory_stats();

    ubyte[] a = *alloc!(ubyte[2])();
    a[0] = 0xeb; a[1] = 0xfe;

    Regs r;
    r.cs = 0x28;
    r.flags = /* IF */ 0x200;
    r.ss = 0x30;
    r.rip = cast(ulong) a.ptr;
    r.rsp = cast(ulong) alloc!(ubyte[4096])();

    r.rsp += 4096;

    Thread* t = alloc!Thread;
    t.vm = alloc!VM;
    t.vm.lowhalf = cast(ulong[256]*)alloc!(ulong[512]);
    t.handles = alloc!(Obj*[512])();
    t.regs = r;

    create_thread(t);

    init_gdt();
    init_idt();
    asm { sti; }
    lapic_deadline_me();
    asm { hlt; }
    printk("hey!");
}
