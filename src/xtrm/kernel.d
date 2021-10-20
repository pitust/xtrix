module xtrm.kernel;

import xtrm.io;
import xtrm.vfs.vfscore;
import xtrm.vfs.kernelfs;
import xtrm.memory;
import xtrm.stivale;
import xtrm.support;
import xtrm.util;


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
                add_to_pool(*get_pool("pool/page"), cast(void*)(e.base + (iter << 12)));
            }
        }
    }
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
    printf("Initializing VFSCore...               "); init_vfscore(struc); printk("\x1b[g][done]");
    printf("Initializing KernelFS...              "); init_kernelfs(struc); printk("\x1b[g][done]");
    // printf("Initializing ModuleFS...              "); init_modulefs(struc); printk("\x1b[g][done]");
    // printf("Initializing TmpFS...                 "); init_tmpfs(struc); printk("\x1b[g][done]");
    // printf("Initializing SystemFS...              "); init_systemfs(struc); printk("\x1b[g][done]");
    // printf("Initializing VFSRoot...               "); init_vfsroot(struc); printk("\x1b[g][done]");

    memory_stats();
    
    
}
