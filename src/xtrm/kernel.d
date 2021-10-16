module xtrm.kernel;

import xtrm.io;
import xtrm.memory;
import xtrm.stivale;
import xtrm.support;
import xtrm.util;


uint rgb(ubyte r, ubyte b, ubyte g) {
    return ((cast(uint)r) << 16) | ((cast(uint)g) << 8) | ((cast(uint)b) << 0);
}

extern (C) void kmain(StivaleStruct* struc) {
    printk("Hello, kernel!");
    ulong i = 0;
    StivaleModule* mod = struc.modules;
    while (i < struc.module_count) {
        if (mod.name[0] == 0) {
            assert(false, "No anonymous modules pls");
        }
        if (strisequal(mod.name.ptr, "font.sfn")) {
            printk("Found font!");
            ssfnc_do_init(mod.begin, struc.framebuffer_addr, struc.framebuffer_width, struc.framebuffer_height, struc
                    .framebuffer_pitch);
            
            io_fonts_initialized();
            printk("\x1b[r]xtrix\x1b[w_0] booting, please wait...");
        }
        
        i++;
    }
    E820Entry[] t = ArrayRepr!(E820Entry).from(struc.memory_map_addr, struc.memory_map_entries).into();
    printk("Discovering memory regions...");
    ulong mem = 0;
    foreach (E820Entry e; t) {
        if (e.type == 1) {
            printk("    + [{p}; {p}]", e.base, e.length);
            mem += e.length;
            foreach (iter; 0..(e.length >> 12)) {
                add_to_pool(*get_pool("pool/page"), cast(void*)(e.base + (iter << 12)));
            }
        }
    }
    printk("Discovered \x1b[g]{}\x1b[w_0] of memory!", iotuple("fmt/bytes", mem));
    printf("$ ");
}
