// xtrix memory object
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
module xtrm.obj.memory;

import xtrm.io;
import xtrm.util;
import xtrm.memory;
import xtrm.obj.obj;
import xtrm.obj.vm;

struct Memory {
    Obj obj = Obj(ObjType.mem); alias obj this;
    ulong pgCount;
    ulong[32]* pages;

    // lifetime(returned value): returned value is owned by the caller
    static Memory* allocate(ulong size) {
        Memory* m = alloc!(Memory)();
        size = (size + 4095) & ~0xfff;
        m.pgCount = size >> 12;
        m.pages = alloc!(ulong[32])();
        foreach (i; 0 .. m.pgCount) {
            (*m.pages)[i] = phys(cast(ulong) allocate_on_pool(*get_pool("pool/page")));
        }

        return m;
    }

    void write(ulong offset, ubyte[] values) {
        foreach (i; 0 .. values.length) {
            ubyte b = values[i];
            ulong off = offset + i;
            ulong page = off >> 12;
            ulong pageoff = off & 0xfff;
            assert((*pages)[page]);
            *cast(ubyte*)virt((*pages)[page] + pageoff) = b;
        }
    }
    void read(ulong offset, ubyte[] values) {
        foreach (i; 0 .. values.length) {
            ulong off = offset + i;
            ulong page = off >> 12;
            ulong pageoff = off & 0xfff;
            if (page >= pages.length) return;
            values[i] = *cast(ubyte*)virt((*pages)[page] + pageoff);
        }
    }
    ref ubyte opIndex(ulong off) {
        ulong page = off >> 12;
        ulong pageoff = off & 0xfff;
        return *cast(ubyte*)virt((*pages)[page] + pageoff);
    }

    void write16(ulong offset, ushort value) {
        write(offset, *cast(ubyte[2]*)&value);
    }
}

struct MemRef {
    Obj obj = Obj(ObjType.memref); alias obj this;
    ulong size;
    ulong pagecnt;
    ulong[32]* pages;

    // lifetime(returned value): returned value is owned by the caller
    static MemRef* allocate(ulong size) {
        MemRef* m = alloc!(MemRef)();
        m.size = size;
        size = (size + 4095) & ~0xfff;
        m.pagecnt = size >> 12;
        m.pages = alloc!(ulong[32])();
        foreach (i; 0 .. ((size) >> 12)) {
            (*m.pages)[i] = phys(cast(ulong) allocate_on_pool(*get_pool("pool/page")));
        }

        return m;
    }
    ref ubyte opIndex(ulong off) {
        ulong page = off >> 12;
        ulong pageoff = off & 0xfff;
        return *cast(ubyte*)virt((*pages)[page] + pageoff);
    }

    void copy_to_user_address(ulong va) {
        foreach (p; 0 .. pagecnt) {
            ulong data = (*pages)[p];
            ulong cnt = 4096;
            if (p == pagecnt - 1) cnt = size & 0xfff;
            isDoingUserCopy = true;
            asm {
                mov RDI, va;
                mov RSI, data;
                mov RCX, cnt;
                rep; movsb;
            }
            isDoingUserCopy = false;
        }
    }
    void copy_from_user_address(ulong va) {
        foreach (p; 0 .. pagecnt) {
            ulong data = (*pages)[p];
            ulong cnt = 4096;
            if (p == pagecnt - 1) cnt = size & 0xfff;
            isDoingUserCopy = true;
            asm {
                mov RSI, va;
                mov RDI, data;
                mov RCX, cnt;
                rep; movsb;
            }
            isDoingUserCopy = false;
        }
    }
}
