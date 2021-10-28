// x86 ISR handler for xtrix
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
	if (r.isr == 0xe) {
		printk("Got page fault while executing code in ring{}", r.cs & 3);
		ulong cr2;
		asm {
			mov RAX, CR2;
			mov cr2, RAX;
		}
		printk("cr2: {*}", cr2);
		printk("flags: {x}", r.flags);
	}

    if (r.isr == LAPIC_DEADLINE_IRQ) {
        sched_yield();

        sched_restore_postirq(r);
        lapic_eoi();
        // the kernel reschedules by hand and not using preemption
        if (r.cs == 0x1b) lapic_deadline_me();
        return;
    }
    if (r.isr >= 0x100) {
        ulong sysno = r.isr - 0x100;
		sched_restore_postirq(r);
        syscall_handler(sysno, r);
        r.rip += 2;
        return;
    }

    while (1) {
        asm {
            cli; hlt;
        }
    }
}
