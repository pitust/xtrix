module xtrm.obj.chan;

import xtrm.io;
import xtrm.util;
import xtrm.memory;
import xtrm.obj.obj;

private struct ChanMessage {
    Obj* msg;
    ChanMessage* next;
}
struct Chan {
    Obj obj = Obj(ObjType.chan); alias obj this;
    private ChanMessage* messageQueue;

    // lifetime(msg): msg is owned by the caller
    void enqueue(Obj* msg) {
        msg.rc++;
        ChanMessage* m = messageQueue;
        messageQueue = alloc!ChanMessage();
        messageQueue.next = m;
        messageQueue.msg = msg;
    }
    // lifetime(returned value): returned value is transferred to the caller
    Obj* dequeue() {
        ChanMessage* m = messageQueue;
        if (!m) return null;
        messageQueue = messageQueue.next;
        return m.msg;
    }
    // lifetime(returned value): returned value is owned by the channel object
    Obj* peek() {
        ChanMessage* m = messageQueue;
        if (!m) return null;
        return m.msg;
    }
}
