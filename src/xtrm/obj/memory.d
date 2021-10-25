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


struct Memory {
    Obj obj = Obj(ObjType.mem); alias obj this;
    ulong pgCount;
    ulong[32]* pages;

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
            values[i] = *cast(ubyte*)virt((*pages)[page] + pageoff);
        }
    }

    void write16(ulong offset, ushort value) {
        write(offset, *cast(ubyte[2]*)&value);
    }
}
