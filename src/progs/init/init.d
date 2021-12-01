module progs.init.init;

import libxk.date;
import libxtrix.io;
import std.typecons;
import libxk.hashmap;
import libxtrix.syscall;
import libxtrix.libc.malloc;
import libxtrix.libc.string;

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

	HashMap!(ulong, char*) children;

	sys_phyread(0x6b7a0db87ad4d3c1, &struc, StivaleStruct.sizeof);
	anoerr("sys_phyread");

	phy mod = struc.modules;
	foreach (i; 0 .. struc.module_count) {
		StivaleModule mod_desc;
		sys_phyread(mod.base, &mod_desc, StivaleModule.sizeof);
		if (mod_desc.name[0..5] != "font\x00" && mod_desc.name[0..5] != "init\x00") {
			printf(" + {}", mod_desc.name.ptr);
			ulong size =  (mod_desc.end - mod_desc.begin + 4095) & ~0xfff;
			ulong pid = sys_fork();
			if (!pid) {
				printf("child...");
				anoerr("sys_fork");
				sys_phymap(mod_desc.begin, addr, size);
				anoerr("sys_phymap");
				char*[2] argv;
				argv[0] = mod_desc.name.ptr;
				sys_rawexec(cast(void*)addr, size, 1, argv.ptr);
				anoerr("sys_rawexec");
				assert(false, "failed to exec!");
			} else {
				// addr += size;
				printf("parent...");
				ulong len = 1+strlen(mod_desc.name.ptr);
				char* str = cast(char*)malloc(len);
				memcpy(cast(byte*)str, cast(byte*)mod_desc.name.ptr, len+1);
				children[pid] = str;
			}
		}
		mod = mod_desc.next;
	}

	long xid = sys_open_pipe(PipeSide.server, 0x4141_4242);
	anoerr("sys_open_pipe");

	printf("pipe: {x}", xid);
	printf("ul: {}", sys_recv_ul(xid));
	anoerr("sys_recv_ul");
	
	while (true) {
		ulong code;
		long stat = sys_wait(code);
		if (stat < 0) anoerr("sys_wait");
		printf("Process \x1b[y]{}({})\x1b[w_0] exited with code {}", children[stat], stat, code);
	}
}

