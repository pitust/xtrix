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
import xtrm.obj.vm;
import xtrm.user.sched;
import xtrm.user.syscalls;
import xtrm.interrupt.regs;
import xtrm.interrupt.lapic;
import xtrm.kdbg;

__gshared bool is_real_hw = false;

extern(C) void interrupt_handler(Regs* r) {
	sched_save_preirq(r);
	kdbg_step();
	if (r.isr == 0xd && r.cs == 0x1b && ((r.error) & 0x7) == 2) {
		// the first syscall is always coming from init(1) and is always a ke_log
		// this checks if we are on real hw or qemu.
		// qemu sets the codes wrong, so we have a special case for it.
		if (r.error == 0x82) {
			is_real_hw = true;
		}
		if (is_real_hw)
			r.isr = (r.error >> 3) + 0xf0;
		else
			r.isr = (r.error >> 4) + 0xf0;
	}
	if (r.isr == LAPIC_DEADLINE_IRQ) {
		sched_yield();

		sched_restore_postirq(r);
		lapic_eoi();
		// the kernel reschedules by hand and not using preemption
		if (r.cs == 0x1b) {
			lapic_deadline_me();
		}
		return;
	}
	if (r.isr >= 0x100) {
		ulong sysno = r.isr - 0x100;
		sched_restore_postirq(r);
		syscall_handler(sysno, r);
		r.rip += 2;
		return;
	}
	if (r.isr != LAPIC_DEADLINE_IRQ) printk("rx irq #{} in thread {}!", iotuple("x86/irq", r.isr), current.tag.ptr);
	if (r.isr == 0xe) {
		printk("\x1b[r] ERROR: \x1b[w_0] Got page fault while executing code in ring{}", r.cs & 3);
		ulong cr2;
		asm {
			mov RAX, CR2;
			mov cr2, RAX;
		}
		printk("cr2: {*}", cr2);
		printk("flags: {x}", r.flags);
		printk("rsp: {x}", r.rsp);
		static foreach (field; __traits(allMembers, Regs)) {{
			long dist = cast(long)__traits(getMember, r, field) - cast(long)cr2;
			if (dist < 0) dist = -dist;
			if (dist < 0x1000) printk(field~": {*}", __traits(getMember, r, field));
		}}
		printk("error: {x}", r.error);
		printk("thread: `{}`", current.tag.ptr);
		printk("is doing user copy: {}", isDoingUserCopy);
		if (cr2 != r.rip) printk("insn: {x}", *cast(ushort*)r.rip);
		if (r.cs == 0x28 && isDoingUserCopy && *cast(ushort*)r.rip == 0xa4f3) {
			r.rip += 2;
			printk("ok back to you, kernel.");
			return;
		}
	}
	
	printk("Encontered unknown interrupt from ring{}! rip={*}", r.cs&3, r.rip);
	printk("Error information: {} | {x}", r.error, r.error);
	if ((r.cs&3) == 3) {
		printk("guesstrace breadcrumbs:");
		// 0xfffffffffff00000 & p == 0x0000000000200000
		ulong nvp = 0;
		while (r.rsp & 0x0f) r.rsp++; // align the stack
		printk("return pointer:    0      {*}", r.rip);
		while (r.rsp < 0xfe0004000) {
			// 0xfffffffffff00000 & p == 0x0000000000200000
			ulong* e = cast(ulong*)r.rsp;
			ulong a = e[0], b = e[1];
			printk("{x}:    {*}      {*}", r.rsp, a, b);
			if ((0xfffffffffff00000 & a) == 0x200000) nvp++;
			if ((0xfffffffffff00000 & b) == 0x200000) nvp++;
			r.rsp += 0x10;
		}
	}

	while (1) {
		asm {
			cli; hlt;
		}
	}
}
