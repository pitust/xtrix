module xtrm.obj.vm;

import xtrm.obj.obj;
// import xtrm.user.mem;

// struct VMEntry { ulong addr; Memory* mem; }
struct VM {
    Obj obj = Obj(ObjType.vm); alias obj this;
    ulong[256]* lowhalf;
}