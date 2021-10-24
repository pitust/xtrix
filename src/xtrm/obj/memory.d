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
            printk("write: {x} -> {*}", b, phys((*pages)[page] + pageoff));
            *cast(ubyte*)virt((*pages)[page] + pageoff) = b;
        }
    }
    void read(ulong offset, ubyte[] values) {
        foreach (i; 0 .. values.length) {
            ulong off = offset + i;
            ulong page = off >> 12;
            ulong pageoff = off & 0xfff;
            assert((*pages)[page]);
            values[i] = *cast(ubyte*)virt((*pages)[page] + pageoff);
        }
    }

    void write16(ulong offset, ushort value) {
        write(offset, *cast(ubyte[2]*)&value);
    }
}