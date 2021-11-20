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

__gshared ulong eslab;

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

private __gshared Pool ppage = Pool(4096), plarge = Pool(256), psmol = Pool(256), pquad = Pool(16);

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
        val = cast(T*)allocate_on_pool(ppage);
    } else static if (T.sizeof > 64) {
        static assert(T.sizeof <= 256, "Cannot allocate " ~ T.stringof ~ " on the slabheaps"
            ~ "(spam pitust to implement non-exact 4k pool support). size=");
        val = cast(T*)allocate_on_pool(plarge);
    } else {
        val = cast(T*)allocate_on_pool(psmol);
    }
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
    if (count == 4096) assert(false,"todo: release pages.");
    if (count > 64) {
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
