// xtrix virtual memory objects and memory managment functions
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
module xtrm.obj.vm;

import xtrm.io;
import xtrm.util;
import xtrm.memory;
import xtrm.support;
import xtrm.obj.obj;
import xtrm.cpu.cr3;
import xtrm.obj.memory;
import xtrm.user.sched;

__gshared bool isDoingUserCopy = false;

struct VMEntry { 
    Memory* ptr;
    ulong addr;
}

struct VM {
    Obj obj = Obj(ObjType.vm); alias obj this;
    ulong[256]* lowhalf;
    VMEntry[256]* entries;
    ulong[512]* owned_pages;
    ulong vme_count = 0, owned_count = 0;
    bool did_init_correctly = false;

    void do_init() {
        did_init_correctly = true;
        entries = alloc!(VMEntry[256]);
        lowhalf = cast(ulong[256]*)alloc!(ulong[512]);
        owned_pages = alloc!(ulong[512]);
    }

    private ulong* get_ptr_ptr(ulong va) {
        assert(did_init_correctly, "Uninitialized thread!");
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
                ulong new_page_table = phys(cast(ulong)alloc!(ubyte[4096])());
                ptk = pte[key] = 0x07 | new_page_table;
                (*owned_pages)[owned_count++] = phys(new_page_table);
            }
            
            pte = *cast(ulong[512]*)(0xffff800000000000 + ptk & ~0xfff);
        }
        
        ulong* ptr = &pte[(va_val >> 12) & 0x1ff];
        return ptr;
    }

    void cloneto(VM* other) {
        assert(did_init_correctly, "Uninitialized thread!");
        foreach (i; 0 .. vme_count) {
            VMEntry ent = (*entries)[i];
            other.map(ent.addr, ent.ptr.clone());
        }
    }

    // lifetime(phy): phy is owned by the caller
    void map(ulong va, Memory* phy) {
        assert(did_init_correctly, "Uninitialized thread!");
        (*entries)[vme_count++] = VMEntry(phy, va);
        phy.rc += 1;
        foreach (i; 0 .. phy.pgCount) {
            ulong phyaddr = phys((*phy.pages)[i]);
            serial_printk("map: {*} -> {*}", va + (i << 12), phyaddr);
            *get_ptr_ptr(va + (i << 12)) = 7 | phyaddr;
        }
        asm {
            mov RAX, CR3;
            mov CR3, RAX;
        }
    }
    void map(ulong va, ulong phy) {
        serial_printk("map: {*} -> {*}", va, phys(phy));
        *get_ptr_ptr(va) = 7 | phys(phy);
        asm {
            mov RAX, CR3;
            mov CR3, RAX;
        }
    }
    void copy_into(ulong va, const(void)* data, ulong count) {
        copy_from_cr3(current.vm.lowhalf);
        copy_to_cr3(lowhalf);
        isDoingUserCopy = true;
        asm {
            mov RSI, data;
            mov RDI, va;
            mov RCX, count;
            rep; movsb;
        }
        isDoingUserCopy = false;
    }
    void copy_out_of(ulong va, void* data, ulong count) {
        copy_from_cr3(current.vm.lowhalf);
        copy_to_cr3(lowhalf);
        isDoingUserCopy = true;
        asm {
            mov RSI, va;
            mov RDI, data;
            mov RCX, count;
            rep; movsb;
        }
        isDoingUserCopy = false;
    }
	void die() {
        foreach (i; 0 .. vme_count) {
            VMEntry ent = (*entries)[i];
            ent.ptr.unref();
        }
        foreach (i; 0 .. owned_count) {
            free(cast(ubyte[4096]*)virt((*owned_pages)[i]));
        }
		free(entries);
		free(lowhalf);
		free(owned_pages);
		entries = null; lowhalf = null; owned_pages = null;
        did_init_correctly = false;
	}
}
