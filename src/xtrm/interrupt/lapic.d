module xtrm.interrupt.lapic;

import core.volatile;
import xtrm.cpu.msr;

__gshared ulong apic_base;

void init_lapic() {
    apic_base = rdmsr(/* IA32_APIC_BASE */ 0x1b) & 0xffff_ffff_ffff_f000;
    uint* sivr = cast(uint*)(apic_base + 0xF0);
    volatileStore(sivr, volatileLoad(sivr) | 0x100);
    volatileStore(cast(uint*)(apic_base + 0x320), 0xff);
    volatileStore(cast(uint*)(apic_base + 0x3E0), 0x03);
}

void lapic_deadline_me() {
    volatileStore(cast(uint*)(apic_base + 0x380), 0xfffff);
}
void lapic_eoi() {
    volatileStore(cast(uint*)(apic_base + 0xB0), 0);
}
