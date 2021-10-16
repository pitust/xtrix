module xtrm.kernel;

import xtrm.io;
import xtrm.stivale;
import xtrm.support;

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

    printf("$ ");
}
