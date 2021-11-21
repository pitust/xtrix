module progs.init.init;

import libxk.date;
import libxtrix.io;
import std.typecons;
import libxtrix.syscall;
import libxtrix.libc.malloc;

struct phy { ulong base; mixin Proxy!(base); }

struct StivaleModule {
    ulong begin; // Address where the module is loaded
    ulong end; // End address of the module
    char[128] name; // 0-terminated ASCII string passed alongside the module (as specified in the config file)
    phy next; // Pointer to the next module (if any), check module_count, in the stivale_struct
}

struct StivaleStruct {
    ulong cmdline; // Address of a null-terminated cmdline
    ulong memory_map_addr; // Address of the memory map
    ulong memory_map_entries; // Count of memory map entries
    void* framebuffer_addr; // Address of the graphical framebuffer if available.
    ushort framebuffer_pitch; // Pitch of the framebuffer in bytes
    ushort framebuffer_width; // Width and height of the framebuffer in pixels
    ushort framebuffer_height;
    ushort framebuffer_bpp; // Bits per pixel
    ulong rsdp; // Address the ACPI RSDP structure
    ulong module_count; // Count of modules that stivale loaded according to config
    phy modules; // Address of the first entry in the linked list of modules (described below)
    ulong epoch; // UNIX epoch at boot, read from system RTC
}

extern(C) int main(string[] args) {
    StivaleStruct struc;
    ulong addr = 0xfefe_0000;
    printf("Hello, world!");
    
    sys_phyread(0x6b7a0db87ad4d3c1, &struc, StivaleStruct.sizeof);
    anoerr("sys_phyread");

    phy mod = struc.modules;
    foreach (i; 0 .. struc.module_count) {
        StivaleModule mod_desc;
        sys_phyread(mod.base, &mod_desc, StivaleModule.sizeof);
        if (mod_desc.name[0..5] != "font\x00" && mod_desc.name[0..5] != "init\x00") {
            printf(" + {}", mod_desc.name.ptr);
            ulong size =  (mod_desc.end - mod_desc.begin + 4095) & ~0xfff;
            sys_phymap(mod_desc.begin, addr, size);
            anoerr("sys_phymap");

            if (!sys_fork()) {
                // anoerr("sys_fork");
                // char*[2] argv;
                // argv[0] = mod_desc.name.ptr;
                // sys_rawexec(cast(void*)addr, size, 1, argv.ptr);
                // assert(false, "failed to exec!");
                printf("child...");
            } else {
                // addr += size;
                printf("parent...");
            }
        }
        mod = mod_desc.next;
    }
    
    while (1) {}
}

