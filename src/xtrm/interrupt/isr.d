module xtrm.interrupt.isr;

import xtrm.io;
import xtrm.interrupt.regs;
import xtrm.interrupt.lapic;
import xtrm.user.sched;

extern(C) void interrupt_handler(Regs* r) {
    sched_save_preirq(r);
    printk("recieved interrupt #{x}; responding...", r.isr);

    if (r.isr == LAPIC_DEADLINE_IRQ) {
        sched_yield();

        sched_restore_postirq(r);
        lapic_eoi();
        lapic_deadline_me();
        return;
    }

    while (1) {
        asm {
            cli; hlt;
        }
    }
}