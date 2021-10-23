module xtrm.interrupt.isr;

import xtrm.io;
import xtrm.interrupt.regs;

extern(C) void interrupt_handler(Regs* r) {
    printk("ISR!!!");

    while (1) {
        asm {
            cli; hlt;
        }
    }
}