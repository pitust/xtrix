module progs.init.init;

import libxk.date;
import libxtrix.io;
import std.typecons;
import libxtrix.syscall;

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
    
    while (1) {}
}

