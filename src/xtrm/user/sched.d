module xtrm.user.sched;

import xtrm.memory;
import xtrm.cpu.cr3;
import xtrm.interrupt.regs;
import xtrm.obj.obj;
import xtrm.obj.vm;
import xtrm.obj.thread;

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
    _cur.vm.lowhalf = cast(ulong[256]*)alloc!(ulong[512]);
    _cur.handles = alloc!(Obj*[512])();
    _cur.rsp0 = alloc!(ubyte[4096])();
}

void create_thread(Thread* t) {
    t.rc++;
    ThreadEntry* te = alloc!ThreadEntry;
    te.next = _cur.next;
    _cur.next = te;
    te.thr = t;
}

void sched_yield() {
    _cur = _cur.next;
}

void sched_save_preirq(Regs* r) {
    _cur.regs = *r;
    copy_from_cr3(_cur.vm.lowhalf);
}

void sched_restore_postirq(Regs* r) {
    *r = _cur.regs;
    copy_to_cr3(_cur.vm.lowhalf);
}