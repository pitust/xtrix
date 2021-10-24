module xtrm.interrupt.isr;

import xtrm.io;
import xtrm.user.syscalls;
import xtrm.interrupt.regs;
import xtrm.interrupt.lapic;
import xtrm.user.sched;

extern(C) void interrupt_handler(Regs* r) {
    sched_save_preirq(r);
    if (r.isr == 0xd && r.cs == 0x1b && ((r.error) & 0xf) == 2 && ((r.error) >> 4) >= 0x10) {
        r.isr = (r.error >> 4) + 0xf0;
    }
    serial_printk("rx irq #{}!", iotuple("x86/irq", r.isr));

    if (r.isr == LAPIC_DEADLINE_IRQ) {
        sched_yield();

        sched_restore_postirq(r);
        lapic_eoi();
        // the kernel reschedules by hand and not using preemption
        if (r.cs == 0x1b) lapic_deadline_me();
        return;
    }
    if (r.isr >= 0x100) {
        syscall_handler(r.isr - 0x100, r);
        sched_restore_postirq(r);
        r.rip += 2;
        return;
    }

    while (1) {
        asm {
            cli; hlt;
        }
    }
}