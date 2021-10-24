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
    volatileStore(cast(uint*)(apic_base + 0x380), /* soon */ 1);
}
void lapic_eoi() {
    volatileStore(cast(uint*)(apic_base + 0xB0), 0);
}
