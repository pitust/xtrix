module xtrm.obj.obj;

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
}