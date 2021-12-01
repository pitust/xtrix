// Stivale1 glue structures for xtrix
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
module xtrm.stivale;

struct StivaleModule {
	void* begin; // Address where the module is loaded
	void* end; // End address of the module
	char[128] name; // 0-terminated ASCII string passed alongside the module (as specified in the config file)
	StivaleModule* next; // Pointer to the next module (if any), check module_count, in the stivale_struct
}

struct E820Entry {
	ulong base;      // Physical address of base of the memory section
	ulong length;    // Length of the section
	uint type;      // Type (described below)
	uint unused;
}

struct StivaleStruct {
	const char* cmdline; // Address of a null-terminated cmdline
	E820Entry* memory_map_addr; // Address of the memory map (entries described below)
	ulong memory_map_entries; // Count of memory map entries
	void* framebuffer_addr; // Address of the graphical framebuffer if available.
	// Else, 0
	ushort framebuffer_pitch; // Pitch of the framebuffer in bytes
	ushort framebuffer_width; // Width and height of the framebuffer in pixels
	ushort framebuffer_height;
	ushort framebuffer_bpp; // Bits per pixel
	ulong rsdp; // Address the ACPI RSDP structure
	ulong module_count; // Count of modules that stivale loaded according to config
	StivaleModule* modules; // Address of the first entry in the linked list of modules (described below)
	ulong epoch; // UNIX epoch at boot, read from system RTC
	ulong flags; // Flags
	// bit 0: 1 if booted with BIOS, 0 if booted with UEFI
	// bit 1: 1 if extended colour information passed, 0 if not
	// bit 2: SMBIOS entry points passed.
	// All other bits are undefined and set to 0.
	// Extended colour information follows. Only access if bit 1 of flags is set.
	ubyte fb_memory_model; // Memory model: 1=RGB, all other values undefined
	ubyte fb_red_mask_size; // RGB mask sizes and left shifts
	ubyte fb_red_mask_shift;
	ubyte fb_green_mask_size;
	ubyte fb_green_mask_shift;
	ubyte fb_blue_mask_size;
	ubyte fb_blue_mask_shift;
	ubyte reserved;
	// Addresses of the SMBIOS entry points follow. Only access if bit 2 of flags is set.
	ulong smbios_entry_32; // 0 if entry point unavailable
	ulong smbios_entry_64; // 0 if entry point unavailable
}
