module xtrm.interrupt.isr;

import xtrm.io;
import xtrm.interrupt.regs;
import xtrm.interrupt.lapic;

extern(C) void interrupt_handler(Regs* r) {
    printk("recieved interrupt #{x}; responding...", r.isr);

    if (r.isr == LAPIC_DEADLINE_IRQ) {
        lapic_eoi();
        return;
    }

    while (1) {
        asm {
            cli; hlt;
        }
    }
}