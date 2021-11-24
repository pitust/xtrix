// xtrix paging manager
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
module xtrm.cpu.cr3;

ulong cr3() {
    ulong value;
    asm {
        mov RAX, CR3;
        // mov CR3, RAX;
        mov value, RAX;
    }
    return value;
}
void copy_from_cr3(ulong[256]* cr3out) {
    static assert((*cr3out).sizeof == 2048);
    asm {
        mov RSI, CR3;
        mov RDI, 0xffff800000000000;
        add RSI, RDI;
        mov RDI, cr3out;
        mov RCX, 2048;
        rep; movsb;
    }
}
void copy_to_cr3(ulong[256]* cr3in) {
    static assert((*cr3in).sizeof == 2048);
    asm {
        mov RSI, CR3;
        mov RDI, 0xffff800000000000;
        add RDI, RSI;
        mov RSI, cr3in;
        mov RCX, 2048;
        rep; movsb;
        // mov RAX, CR3;
        // mov CR3, RAX;
    }
}
void kernel_copy_from_cr3(ulong[256]* cr3out) {
    static assert((*cr3out).sizeof == 2048);
    asm {
        mov RSI, CR3;
        add RSI, 2048;
        mov RDI, 0xffff800000000000;
        add RSI, RDI;
        mov RDI, cr3out;
        mov RCX, 2048;
        rep; movsb;
    }
}
void kernel_copy_to_cr3(ulong[256]* cr3in) {
    static assert((*cr3in).sizeof == 2048);
    asm {
        mov RSI, CR3;
        add RSI, 2048;
        mov RDI, 0xffff800000000000;
        add RDI, RSI;
        mov RSI, cr3in;
        mov RCX, 2048;
        rep; movsb;
        // mov RAX, CR3;
        // mov CR3, RAX;
    }
}
void init_low_half() {
    asm {
        mov RDI, CR3;
        mov RSI, 0xffff800000000000;
        add RDI, RSI;
        mov RAX, 0;
        mov RCX, 2048;
        rep; stosb;
        // mov RAX, CR3;
        // mov CR3, RAX;
    }
}