module xtrm.memory;

import xtrm.io;
import xtrm.support;

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

T* alloc(T)() {
    static if (T.sizeof > 64) {
        static assert(T.sizeof <= 256, "Cannot allocate " ~ T.stringof ~ " on the slabheaps"
            ~ "(spam pitust to implement 4k pool support)");
        return cast(T*)allocate_on_pool(plarge);
    } else {
        return cast(T*)allocate_on_pool(psmol);
    }
}

void free(T)(T* data) {
    free(T.sizeof, cast(void*)data);
}
void free(ulong count, void* data) {
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