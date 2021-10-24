module xtrm.obj.vm;

import xtrm.io;
import xtrm.util;
import xtrm.memory;
import xtrm.obj.obj;
import xtrm.obj.memory;

struct VMEntry {
    ulong addr; Memory* mem;

    bool contains(ulong va) {
        if (va < addr) return false;
        if (va >= addr + (mem.pgCount << 12)) return false;
        return true;
    }
}
struct VM {
    Obj obj = Obj(ObjType.vm); alias obj this;
    ulong[256]* lowhalf;
    VMEntry[256]* vme;
    ulong vme_count = 0;

    private ulong* get_ptr_ptr(ulong va) {
        assert(lowhalf, "No lowhalf!");
        ulong[] pte = *lowhalf;

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

    void map(ulong va, Memory* phy) {
        (*vme)[vme_count++] = VMEntry(va, phy);
        phy.rc += 1;
        foreach (i; 0 .. phy.pgCount) {
            ulong phyaddr = phys((*phy.pages)[i]);
            serial_printk("map: {*} -> {*}", va + (i << 12), phyaddr);
            *get_ptr_ptr(va + (i << 12)) = 7 | phyaddr;
        }
    }
    Memory* region_for(ulong va, out ulong offset) {
        foreach (i; 0 .. vme_count) {
            if ((*vme)[i].contains(va)) {
                offset = va - (*vme)[i].addr;
                return (*vme)[i].mem;
            }
        }
        return null;
    }
}