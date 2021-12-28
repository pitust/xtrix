// xtrix garbage collector
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

// NOTE: this GC comes from the MIT-licensed diode codebase, see
// https://github.com/pitust/diode/blob/trunk/source/libsys/mem.d
module libxtrix.gc;

import libxtrix.io;
import core.lifetime;
import libxtrix.libc.malloc;

private enum SweepColor {
	// note that scanned and not scanned are flipped around if `is_flipped` is set

	BLACK, // not scanned
	GRAY, // in process of being scanned
	WHITE, // scanned
}

private struct BlockHeader {
	ulong size;
	BlockHeader* next;
	BlockHeader* prev;
	SweepColor color;
}

private struct Block(T) {
	ulong magic;
	BlockHeader header;
	T data;
}

private __gshared BlockHeader* first = cast(BlockHeader*) 0;
private __gshared bool is_flipped = cast(BlockHeader*) 0;
__gshared ulong maysweep = 0;
__gshared void** elfbase;
__gshared void** elftop;

private SweepColor _swept() {
	return is_flipped ? SweepColor.BLACK : SweepColor.WHITE;
}

private SweepColor _not_swept() {
	return is_flipped ? SweepColor.WHITE : SweepColor.BLACK;
}

private T[] array(T)(T* ptr, ulong len) {
	union U {
		ulong[2] a;
		T[] b;
	}
	U data;
	data.a[0] = len;
	data.a[1] = cast(ulong)ptr;
	return data.b;
}

T[] alloc_array(T)(ulong n) {
	maysweep += 1;
	if (maysweep) {
		sweep();
		maysweep = 0;
	}

	alias Blk = Block!(T);
	Blk* b = cast(Blk*) malloc(ulong.sizeof + BlockHeader.sizeof + n * T.sizeof);
	b.magic = *cast(ulong*) "TRICOLOR".ptr;
	b.header.color = _swept;
	b.header.next = first;
	b.header.size = n * T.sizeof;
	b.header.prev = cast(BlockHeader*) 0;
	if (first) first.prev = &b.header;
	b.header.size = T.sizeof;
	first = &b.header;
	return array(&b.data, n);
}

T[] arr(T)(T[] args...) {
	return args;
}
T[] concat(T)(T[] arra, T[] args...) {
	T[] arr = alloc_array!(T)(arra.length + args.length);
	foreach (i; 0 .. arr.length) {
		if (arra.length > i) emplace(&arr.ptr[i], arra[i]);
		else emplace(&arr.ptr[i], args[i - arra.length]);
	}
	return arr;
}
T[] concat(T)(T[] arra, T[] args) {
	T[] arr = alloc_array!(T)(arra.length + args.length);
	foreach (i; 0 .. arr.length) {
		if (arra.length > i) emplace(&arr.ptr[i], arra[i]);
		else emplace(&arr.ptr[i], args[i - arra.length]);
	}
	return arr;
}

T* alloc(T, Args...)(Args args) {
	maysweep += 1;
	if (maysweep == 5) {
		sweep();
		maysweep = 0;
	}


	alias Blk = Block!(T);
	Blk* b = cast(Blk*) malloc(Blk.sizeof);
	b.magic = *cast(ulong*) "TRICOLOR".ptr;
	b.header.color = _swept;
	b.header.next = first;
	b.header.size = T.sizeof;
	b.header.prev = cast(BlockHeader*) 0;
	if (first) first.prev = &b.header;
	b.header.size = T.sizeof;
	first = &b.header;
	emplace(&b.data, args);
	return &b.data;
}
extern(C) void* _d_allocmemory(ulong size) {
	maysweep += 1;
	if (maysweep == 5) {
		sweep();
		maysweep = 0;
	}

	alias Blk = Block!(ubyte[0]);
	Blk* b = cast(Blk*) malloc(Blk.sizeof + size);
	b.magic = *cast(ulong*) "TRICOLOR".ptr;
	b.header.color = _swept;
	b.header.next = first;
	b.header.size = size;
	b.header.prev = cast(BlockHeader*) 0;
	if (first) first.prev = &b.header;
	first = &b.header;
	return &b.data;
}

private void do_dealloc(BlockHeader* v) {
	if (v.next)
		v.next.prev = v.prev;
	if (v.prev)
		v.prev.next = v.next;
	if (first == v)
		first = v.next;
	printf("frii: {*} color={} | {}", (cast(void*)v) + BlockHeader.sizeof, cast(int)v.color, cast(int)_not_swept());
	free((cast(void*) v) - 8);
}

private void do_sweep_of(void* d) {
	void* ogptr = d;
	
	{
		BlockHeader* h = first;
		while (h) {
			if (h < d && h.size + cast(void*)&h[1] > d) {
				d = cast(void*)h;
				d -= 8;
				break;
			}

			h = h.next;
		}
		if (!h) return;
	}

	ulong magic = *cast(ulong*)(d);
	if (ogptr == cast(void*)0x000009d000000da8) {
		printf("da8 starts at {p}, with m={x}", d, magic);
	}
	if (magic != *cast(ulong*) "TRICOLOR".ptr) {
		/* wrong magic */
		printf("m: {p} vs {p}", magic, *cast(ulong*) "TRICOLOR".ptr);
		assert(false, "wrong magic but it's in the list");
		return;
	}
	// we are pretty sure this is a valid object. sweep it.
	BlockHeader* hdr = cast(BlockHeader*)(d + ulong.sizeof);

	if (hdr.color == SweepColor.GRAY) /* being sweeped */ return;

	hdr.color = SweepColor.GRAY;

	ulong size = hdr.size;
	ulong ptrcnt = size / 8;
	foreach (i; 0 .. ptrcnt) {
		do_sweep_of(cast(void*)*cast(ulong*)(i * 8 + ogptr));
	}

	hdr.color = _swept;
}

void sweep() {
	printf("!!! gee cee");
	ulong[15] regs;
	ulong* rp = regs.ptr;
	asm {
		mov RAX, rp;

		mov [RAX + 0x0], RBX;
		mov [RAX + 0x8], RCX;
		mov [RAX + 0x10], RDX;
		mov [RAX + 0x18], RBP;
		mov [RAX + 0x20], RSI;
		mov [RAX + 0x28], RDI;
		mov [RAX + 0x30], R8;
		mov [RAX + 0x38], R9;
		mov [RAX + 0x40], R10;
		mov [RAX + 0x48], R11;
		mov [RAX + 0x50], R12;
		mov [RAX + 0x58], R13;
		mov [RAX + 0x60], R14;
		mov [RAX + 0x68], R15;
		mov [RAX + 0x70], RSP;
	}
	// FIXME: this should really be a syscall, as it is in diode
	ulong stack_top = 0xfe0004000;
	ulong stack_bottom = regs[14];
	is_flipped = !is_flipped;
	foreach (i; stack_bottom .. (stack_top - 7)) {
		// if (i & 7) continue;
		if (i == 0x0000000fe0003f48) { printf("sus: {}", *cast(void**)i); }
		if (i == 0x0000000fe0003f50) { printf("amogus: {}", *cast(void**)i); }
		do_sweep_of(*(cast(void**) i));
	}
	foreach (ulong reg; regs) {
		do_sweep_of(cast(void*) reg);
	}
	printf("elfbase={} elftop={}", cast(void*)elfbase, cast(void*)elftop);
	foreach (void** ee; elfbase .. elftop) {
		if (ee == cast(void**)0x0000000000212008) {
			printf("SWEEP: {*}", *ee);
		}
		do_sweep_of(*ee);
	}
	BlockHeader* h = first;
	while (h) {
		if (h.color == _not_swept) {
			BlockHeader* n = h.next;
			do_dealloc(h);
			h = n;
		} else
			h = h.next;
	}
}
