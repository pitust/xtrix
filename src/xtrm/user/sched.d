// xtrix round robin scheduler for threads
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
module xtrm.user.sched;

import xtrm.io;
import xtrm.memory;
import xtrm.cpu.tss;
import xtrm.cpu.cr3;
import xtrm.obj.obj;
import xtrm.obj.vm;
import xtrm.obj.thread;
import xtrm.obj.memory;
import xtrm.interrupt.regs;

__gshared ulong system_sleep_gen = 0;

private struct ThreadEntry {
    Thread* thr;
    ThreadEntry* next;
    alias thr this;
}
private __gshared ThreadEntry* _cur;

Thread* current() { return _cur.thr; }

void init_sched() {
    _cur = alloc!ThreadEntry;
    _cur.thr = alloc!Thread;
    _cur.next = _cur;
    _cur.vm = alloc!VM;
    _cur.vm.entries = alloc!(Memory*[512]);
    _cur.vm.lowhalf = cast(ulong[256]*)alloc!(ulong[512]);
    _cur.rsp0 = alloc!(ubyte[4096])();
	_cur.sleepgen = 0;
}

void create_thread(Thread* t) {
    t.rc++;
    ThreadEntry* te = alloc!ThreadEntry;
    te.next = _cur.next;
    _cur.next = te;
    te.thr = t;
}

void sched_yield() {
	do {
    	_cur = _cur.next;
		if (_cur.sleepgen < system_sleep_gen) _cur.sleepgen = system_sleep_gen;
	} while (_cur.sleepgen > system_sleep_gen);
}

void sched_save_preirq(Regs* r) {
    _cur.regs = *r;
    copy_from_cr3(_cur.vm.lowhalf);
}

void sched_restore_postirq(Regs* r) {
    *r = _cur.regs;
    copy_to_cr3(_cur.vm.lowhalf);
    set_rsp0(*_cur.rsp0);
}
