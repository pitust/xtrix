// xtrix system call handler
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
module xtrm.user.syscalls;

import xtrm.io;
import xtrm.obj.memory;
import xtrm.user.sched;
import xtrm.interrupt.regs;

void syscall_handler(ulong sys, Regs* r) {
    if (sys == 0) {
        if (r.rdi > 64) r.rdi = 64;

        ulong offset;
        char[64] messagebuf;
        char[] message = messagebuf[0 .. r.rdi];
        Memory* range = current.vm.region_for(r.rsi, offset);
        if (range == null) {
            printk("[user] warn: efault while handlink KeLog!");
            return;
        }
        range.read(offset, cast(ubyte[])message);

        printk("[user] {}", message);
    } else {
        printk("[user] warn: enosys {}", sys);
    }
}