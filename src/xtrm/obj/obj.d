module xtrm.obj.obj;

import xtrm.io;

enum ObjType {
    nullobj,
    mem,
    memref,
    vm,
    thr,
    chan,
    cred,
    credproof,
    credverity,
}

struct Obj {
    ObjType type;
    ulong rc = 1;

    void release() {
        rc--;
        if (rc == 0) {
            printk("[obj] should release a kernel object!");
        }
    }
}