module xtrm.obj.chan;

import xtrm.io;
import xtrm.util;
import xtrm.memory;
import xtrm.obj.obj;

private struct ChanMessage {
    Obj* msg;
	bool* wake; Obj** resp;
    ChanMessage* next;
}
struct Responder {
    Obj obj = Obj(ObjType.responder); alias obj this;
	
	Obj** vwrite; bool* wake; bool valid;
	
	// lifetime(o): o is transferred to the responder.
	void respond(Obj* o) {
		assert(valid);
		*vwrite = o;
		valid = false;
		*wake = true;
	}
}
struct Chan {
    Obj obj = Obj(ObjType.chan); alias obj this;
    private ChanMessage* messageQueue;
    private ChanMessage* invokeQueue;

    // lifetime(msg): msg is owned by the caller. the caller guarantees that resp and wake lives as long as *wake is false.
    void enqueueInvoke(Obj* msg, bool* wake, Obj** resp) {
        msg.rc++;
        ChanMessage* m = invokeQueue;
        invokeQueue = alloc!ChanMessage();
        invokeQueue.next = m;
    	invokeQueue.msg = msg;
		invokeQueue.wake = wake;
		invokeQueue.resp = resp;
		*wake = false;
    }
    // lifetime(msg): msg is owned by the caller
    void enqueue(Obj* msg) {
        msg.rc++;
        ChanMessage* m = messageQueue;
        messageQueue = alloc!ChanMessage();
        messageQueue.next = m;
        messageQueue.msg = msg;
    }
    // lifetime(returned value): returned value is transferred to the caller.
	// the caller guarantees that response is valid when *wake is set to true.
	// the caller guarantees that wake or response are not going to be accesed after *wake is set to true.
    Obj* dequeueInvoke(out bool* wake, out Obj** response) {
        ChanMessage* m = invokeQueue;
        if (!m) return null;
        invokeQueue = invokeQueue.next;
		wake = m.wake;
		response = m.resp;
        return m.msg;
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
