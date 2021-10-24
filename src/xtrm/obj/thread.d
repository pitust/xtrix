module xtrm.obj.thread;

import xtrm.memory;
import xtrm.obj.obj;
import xtrm.obj.vm;
import xtrm.interrupt.regs;

struct Thread {
    Obj obj = Obj(ObjType.thr); alias obj this;
    Regs regs;
    VM* vm;
    Obj*[512]* handles;
    ubyte[4096]* rsp0;
}