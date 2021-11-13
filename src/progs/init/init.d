module progs.init.init;

import libxtrix.io;
import std.typecons;
import libxtrix.syscall;

struct phy { ulong base; mixin Proxy!(base); }

struct StivaleModule {
    void* begin; // Address where the module is loaded
    void* end; // End address of the module
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

extern (C) void _start(ulong phy_stivale2_structure) {
    StivaleStruct s;
    assert_success(KeReadPhysicalMemory(phy_stivale2_structure, StivaleStruct.sizeof, &s));
    phy modp = s.modules;
    printf("mods: {*}", s.module_count);
    foreach (i; 0..s.module_count) {
        StivaleModule mod;
        assert_success(KeReadPhysicalMemory(cast(ulong)modp, StivaleModule.sizeof, &mod));
        printf("module: {}", mod.name);
        modp = mod.next;
    }
    XHandle c1 = KeCreateKeyedChannel(0xed45c6b9c4a45ba3).aok();
    XHandle c2 = KeCreateKeyedChannel(0xed45c6b9c4a45ba3).aok();
    KePushMessage(c1, KeAllocateMemRefObject("loll"));
    XHandle r = KePopMessage(c2);
    printf("m: {}", r.getType());


    while(1) {}
}
