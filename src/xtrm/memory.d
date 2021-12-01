// xtrix physical memory manager and kernel heap
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
module xtrm.memory;

import xtrm.io;
import xtrm.support;

__gshared ulong eslab, saddr;

private struct Slab {
	Slab* next;
	ulong count;
}

private struct Pool {
	Slab* next = null;
	ulong dataContained = 0;
	ulong size = 0;
	this(ulong size) {
		this.size = size;
	}
}

private __gshared Pool ppage = Pool(4096), plarge = Pool(256), psmol = Pool(64), pquad = Pool(16);

Pool* get_pool(string name) {
	if (name == "pool/page") return &ppage;
	if (name == "pool/large") return &plarge;
	if (name == "pool/small") return &psmol;
	if (name == "pool/quad") return &pquad;
	assert(false, "Cannot get unknown pool!");
}

ulong* aquad() {
	return cast(ulong*)allocate_on_pool(pquad);
}
void fquad(ulong* q) {
	add_to_pool(pquad, cast(void*)q);
}

void* allocate_on_pool(ref Pool pool) {
	if (pool.next == null) {
		assert(pool.size != 4096, "OOM: no memory left! there is nothing we can do!!!");

		Slab* s = cast(Slab*)allocate_on_pool(ppage);
		s.count = 4096 / pool.size;
		s.next = null;
		pool.next = s;
		pool.dataContained += 4096;
	}

	pool.dataContained -= pool.size;

	if (pool.next.count == 1) {
		void* val = cast(void*)pool.next;
		pool.next = pool.next.next;
		memset(cast(byte*)val, 0, pool.size);
		return val;
	}

	pool.next.count -= 1;
	void* val = cast(void*)((cast(ulong)pool.next) + pool.size * pool.next.count);
	memset(cast(byte*)val, 0, pool.size);
	return val;
}
void add_to_pool(ref Pool pool, void* data) {
	Slab* slab = cast(Slab*)data;
	slab.next = pool.next;
	slab.count = 1;
	pool.next = slab;
	pool.dataContained += pool.size;
}

T* alloc(T, Args...)(Args args) {
	import core.lifetime;

	T* val;
	static if (T.sizeof == 4096) {
		enum asize = 4096;
		val = cast(T*)allocate_on_pool(ppage);
	} else static if (T.sizeof > 64) {
		static if (T.sizeof > 256 && T.sizeof != 4096) pragma(msg, T.sizeof);
		static assert(T.sizeof <= 256, "Cannot allocate " ~ T.stringof ~ " on the slabheaps"
			~ "(spam pitust to implement non-exact 4k pool support). size=");
		enum asize = 256;
		val = cast(T*)allocate_on_pool(plarge);
	} else {
		enum asize = 64;
		val = cast(T*)allocate_on_pool(psmol);
	}
	memset(cast(byte*)val, 0, asize);
	emplace(val, args);
	return val;
}

extern(C) void* libxk_sized_malloc(ulong size) {
	if (size == 4096) {
		return cast(void*)allocate_on_pool(ppage);
	} else if (size > 64) {
		assert(size <= 256, "Cannot allocate libxk data on the slabheaps"
			~ "(spam pitust to implement non-exact 4k pool support)");
		return cast(void*)allocate_on_pool(plarge);
	} else {
		return cast(void*)allocate_on_pool(psmol);
	}
}
extern(C) void libxk_sized_free(ulong size, void* pointer) {
	free(size, pointer);
}

void free(T)(T* data) {
	destroy!(false)(data);
	free(T.sizeof, cast(void*)data);
}
void free(ulong count, void* data) {
	if (count == 4096 || count == 2048) {
		add_to_pool(ppage, data);
	} else if (count > 64) {
		assert(count <= 256, "Cannot free this much bytes!");
		add_to_pool(plarge, data);
	} else {
		add_to_pool(psmol, data);
	}
}
void memory_stats() {
	printk("Memory usage by pool:");
	printk("  + Page-frame pool       {}", iotuple("fmt/bytes", ppage.dataContained));
	printk("  + 256-byte obj pool     {}", iotuple("fmt/bytes", plarge.dataContained));
	printk("  + 64-byte smol obj pool {}", iotuple("fmt/bytes", psmol.dataContained));
}

private extern(C) pragma(mangle, "free")
void __broken_c_free() { assert(false, "cannot free: kernel has a broken c free."); }

private extern(C) pragma(mangle, "malloc")
void __broken_c_malloc() { assert(false, "cannot malloc: kernel has a broken c malloc."); }

private __gshared bool cptop = false;
private __gshared ulong[256] kpages;

private ulong* get_ptr_ptr(ulong va) {
	import xtrm.cpu.cr3;
	assert(va >= 0xffff800000000000);
	va -= 0xffff800000000000;

	if (!cptop) {
		cptop = true;
		kernel_copy_from_cr3(&kpages);
	}

	ulong[] pte = kpages;
	ulong va_val = va & 0x000f_ffff_ffff_f000;
	ulong[3] va_values = [
		((((va_val >> 12) >> 9) >> 9) >> 9) & 0x1ff,
		(((va_val >> 12) >> 9) >> 9) & 0x1ff,
		((va_val >> 12) >> 9) & 0x1ff,
	];
	foreach (key; va_values) {
		ulong ptk = pte[key];
		if (!((ptk) & 1)) {
			ulong new_page_table = (cast(ulong)alloc!(ubyte[4096])()) - 0xffff800000000000;
			ptk = pte[key] = 0x07 | new_page_table;
		}
		
		pte = *cast(ulong[512]*)(0xffff800000000000 + ptk & ~0xfff);
	}

	return &pte[(va_val >> 12) & 0x1ff];
}

void kmemmap(ulong va, ulong phy) {
	import xtrm.cpu.cr3 : kernel_copy_to_cr3;
	*get_ptr_ptr(va) = 3 | phy;
	kernel_copy_to_cr3(&kpages);
}

private __gshared ulong vmbase = 0xffff900000000000;

ulong alloc_stack(out ulong[4] to_free) {
	import xtrm.util : phys;
	ulong vmaddr = vmbase;

	foreach (i; 0 .. 4) {
		ulong phy = cast(ulong)phys(allocate_on_pool(ppage));
		kmemmap(vmbase, phy);
		vmbase += 0x1000;
		to_free[i] = phy;
	}
	vmbase += 0x4000;
	return vmaddr;
}
void release_stack(ulong[4] to_free) {
	import xtrm.util : virt;
	foreach (stak; to_free) {
		add_to_pool(ppage, cast(void*)virt(stak));
	}
}
