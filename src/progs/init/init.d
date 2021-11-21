module progs.init.init;

import libxtrix.io;
import std.typecons;
import libxk.hashmap;
import libxtrix.syscall;
import progs.init.init_srpc;

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

extern (C) void _start(ulong phy_stivale2_structure) {
    StivaleStruct s;
    assert_success(KeReadPhysicalMemory(phy_stivale2_structure, StivaleStruct.sizeof, &s));
    phy modp = s.modules;
    foreach (i; 0..s.module_count) {
        StivaleModule mod;
        assert_success(KeReadPhysicalMemory(cast(ulong)modp, StivaleModule.sizeof, &mod));
        printf("module: {}", mod.name);
        modp = mod.next;
    	if (mod.name[0 .. 4] == "init" && mod.name[4] == 0) continue;
        if (mod.name[0 .. 4] == "font" && mod.name[4] == 0) continue;
		printf("Starting init binary {}!", mod.name.ptr);
		XHandle s2m = KeReadPhysicalMemory(mod.begin, mod.end-mod.begin).aok("mod load failed");
		XHandle vm = KeCreateVM().aok("creating virtual address space failed.");
		long ent = KeLoadELF(vm, s2m);
		if (ent>>63) {
            printf("cannot load module {}, elf load failed", mod.name.ptr);
            assert(false, "ELF loader failed.");
        }
		enum STACK_SIZE = 0x4000;
		XHandle stack = KeAllocateMemoryObject(STACK_SIZE);
		assert_success(KeMapMemory(vm, 0xfe0000000, stack));
		KeCreateThread(vm, ent, 0, 0, 0, 0xfe0000000 + STACK_SIZE).release();
        printf("started {}", mod.name.ptr);

        s2m.release(); vm.release();
	}

    rpc_publish();
    assert(false, "RPC died :(");
}

