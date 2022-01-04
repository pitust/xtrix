module libxtrix.rpcutil;

import libxtrix.io;
import libxtrix.gc;
import libxtrix.events;
import libxtrix.syscall;
import libxk.bytebuffer;

void rpcutil_handle(ulong epid, HandlerType handler) {
    ev_on(delegate bool(pid, rid, buf) {
        if (buf.length <= 4) return false;
        if (*cast(uint*)&buf[0] != epid) return false;
        handler(pid, rid, buf[4 .. $]);
        return true;
    });
}

private __gshared ubyte[4096] leave_me_alone;
private ubyte[] rpcutil_get_buffer(ubyte[] data, ref ulong off, ulong siz) {
    if (off + siz > data.length) return leave_me_alone[0 .. siz];
    off += siz;
    return data[(off-siz) .. off];
}
uint rpcutil_decode_uint(ubyte[] data, ref ulong off) {
    ubyte[] d = rpcutil_get_buffer(data, off, 4);
    return *cast(uint*)d;
}
string rpcutil_decode_string(ubyte[] data, ref ulong off) {
    uint len = rpcutil_decode_uint(data, off);
    char[] mystring = alloc_array!(char)(len);
    ubyte[] b = rpcutil_get_buffer(data, off, len);
    foreach (i; 0 .. len) mystring[i] = cast(char)b[i];
    return cast(string)mystring;
}

void rpcutil_encode_uint(ref ByteBuffer buf, uint i) { buf.writeRaw(&i, 4); }
void rpcutil_encode_string(ref ByteBuffer buf, string str) {
    uint i = cast(uint)buf.size;
    rpcutil_encode_uint(buf, i);
    foreach (chr; str) {
        buf << cast(ubyte)chr;
    }
}
void rpcutil_submit_ev(ulong pid, ref ByteBuffer buf) {
    do { sys_sendmsg(pid, 0, buf.size, buf.data); } while (errno == error.EINVAL);
}
void rpcutil_prepare(ref ByteBuffer buf, uint rid) {
    rpcutil_encode_uint(buf, rid);
}