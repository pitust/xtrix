// Local APIC programming code for xtrix
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
module xtrm.interrupt.lapic;

import core.volatile;
import xtrm.cpu.msr;

private __gshared ulong apic_base;
enum LAPIC_DEADLINE_IRQ = 0xfe;

void init_lapic() {
    apic_base = 0xffff800000000000 + rdmsr(/* IA32_APIC_BASE */ 0x1b) & 0xffff_ffff_ffff_f000;
    uint* sivr = cast(uint*)(apic_base + 0xF0);
    volatileStore(sivr, volatileLoad(sivr) | 0x100);
    volatileStore(cast(uint*)(apic_base + 0x320), LAPIC_DEADLINE_IRQ);
    volatileStore(cast(uint*)(apic_base + 0x3E0), 0x03);
}

void lapic_deadline_me() {
    volatileStore(cast(uint*)(apic_base + 0x380), 0xffff);
}
void lapic_deadline_me_soon() {
    volatileStore(cast(uint*)(apic_base + 0x380), /* soon */ 100);
}
void lapic_eoi() {
    volatileStore(cast(uint*)(apic_base + 0xB0), 0);
}
