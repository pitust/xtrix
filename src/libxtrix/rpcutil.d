module libxtrix.rpcutil;

import libxtrix.io;
import libxtrix.events;

void rpcutil_handle(ulong epid, HandlerType handler) {
    ev_on(delegate bool(pid, rid, buf) {
        if (buf.length <= 4) return false;
        if (*cast(uint*)&buf[0] != epid) return false;
        printf("libxtrix events: got request for EP {}!", epid);
        return true;
    });
}

string rpcutil_decode_string(ubyte[] data, ref ulong off) {
    assert(false, "TODO: decode!");
}