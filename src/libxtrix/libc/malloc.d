// xtrix memory allocator
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
module libxtrix.libc.malloc;

import libxtrix.io;
import libxtrix.syscall;
import libxtrix.libc.string;

private const __gshared ulong[14] bucketSizes = [
	0x20, 0x40, 0x60, 0x80,
	0xc0, 0x100, 0x180, 0x200,
	0x300, 0x400, 0x600, 0x800
];

private __gshared ulong[14] bucketPointers;
private __gshared ulong bucketbase = 0x9d000000000UL;
private __gshared ulong top_sizemap_paged_address = 0x7f0000UL;
private const __gshared sizemap_address = 0x7f0000UL;

pragma(inline) private ulong getSizemapAddress(ulong bucketAdress) {
	return ((bucketAdress - 0x9d000000000) >> 4) + 0x7f0000UL;
}

private void addTargetSliceToBucket(ulong base, ulong ti) {
	ulong old = bucketPointers[ti];
	bucketPointers[ti] = base;
	*cast(ulong*)base = old;
}

private ulong addSliceToBucket(ulong maxsz, ulong csz, ulong base) {
	if (maxsz < bucketSizes[0])
		return csz;
	ulong tsize = 0x20, tindex = 0;
	foreach (i; 0 .. bucketSizes.length) {
		if ((bucketSizes[i] > maxsz) || (bucketSizes[i] > csz)) {
			addTargetSliceToBucket(base, tindex);
			return tsize;
		}
		tsize = bucketSizes[i];
		tindex = i;
	}
	addTargetSliceToBucket(base, tindex);
	return tsize;
}

private void addToBucket(ulong bindex) {
	sys_mmap(bucketbase, 4096);
	ulong addr = bucketbase;
	bucketbase += 4096;
	ulong csize = 4096;
	while (csize > bucketSizes[0]) {
		ulong count = addSliceToBucket(bucketSizes[bindex], csize, addr);
		addr += count;
		csize -= count;
	}
}

extern(C) void* malloc(ulong size) {
	foreach (idx; 0 .. bucketSizes.length) {
		ulong ssize = bucketSizes[idx];
		if (ssize > size) {
			if (!bucketPointers[idx])
				addToBucket(idx);

			ulong ptr = bucketPointers[idx];
			bucketPointers[idx] = *cast(ulong*)ptr;
			ulong maskPointer = getSizemapAddress(ptr);
			if (maskPointer > top_sizemap_paged_address) {
				assert(maskPointer - 4096 <= top_sizemap_paged_address,
					"The malloc failed; top sizemap paged address is wayyyy below the mask ptr");
				sys_mmap(top_sizemap_paged_address, 4096);
				top_sizemap_paged_address += 4096;
			}
			(cast(ubyte*)maskPointer)[0] = cast(ubyte)idx;
			(cast(ubyte*)maskPointer)[1] = 1;
			memset(cast(byte*)ptr, 0xe3, ssize);
			memset(cast(byte*)ptr, 0x00, size);
			return cast(void*)ptr;
		}
	}
	assertf(false, "Cannot allocate block of size {}", size);
	assert(false); // unreachable
}
extern(C) void free(void* pointer) {
	// some c programs rely on free(null) being fine
	if (pointer == null) return;

	ulong ptr = cast(ulong)pointer;
	if (ptr < 0x9d000000000) {
		printf("invalid free!");
		return;
	}
	ulong maskPointer = getSizemapAddress(ptr);
	if (maskPointer < top_sizemap_paged_address) {
		printf("invalid free!");
		return;
	}
	ubyte bucket = (cast(ubyte*)maskPointer)[0];
	ubyte mode = (cast(ubyte*)maskPointer)[1];
	ulong size = bucketSizes[bucket];
	memset(cast(byte*)ptr, 0xe1, size);
	addTargetSliceToBucket(ptr, bucket);
}
extern(C) ulong malloc_size(void* pointer) {
	// some c programs rely on free(null) being fine
	ulong ptr = cast(ulong)pointer;
	if (ptr < 0x9d000000000) return 0;
	ulong maskPointer = getSizemapAddress(ptr);
	if (maskPointer < top_sizemap_paged_address) {
		return 0;
	}
	ubyte bucket = (cast(ubyte*)maskPointer)[0];
	ubyte mode = (cast(ubyte*)maskPointer)[1];
	ulong size = bucketSizes[bucket];
	return size;
}

extern(C) void libxk_sized_free(ulong size, void* pointer) { free(pointer); }
extern(C) void* libxk_sized_malloc(ulong size) { return malloc(size); }

alias libc_free = free;
