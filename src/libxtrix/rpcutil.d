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
int rpcutil_decode_int(ubyte[] data, ref ulong off) {
    ubyte[] d = rpcutil_get_buffer(data, off, 4);
    return *cast(int*)d;
}
string rpcutil_decode_string(ubyte[] data, ref ulong off) {
    uint len = rpcutil_decode_uint(data, off);
    char[] mystring = alloc_array!(char)(len);
    ubyte[] b = rpcutil_get_buffer(data, off, len);
    foreach (i; 0 .. len) mystring[i] = cast(char)b[i];
    return cast(string)mystring;
}

void rpcutil_encode_uint(ref ByteBuffer buf, uint i) { buf.writeRaw(&i, 4); }
void rpcutil_encode_int(ref ByteBuffer buf, int i) { buf.writeRaw(&i, 4); }
void rpcutil_encode_string(ref ByteBuffer buf, string str) {
    uint i = cast(uint)str.length;
    rpcutil_encode_uint(buf, i);
    foreach (chr; str) {
        buf << cast(ubyte)chr;
    }
}
void rpcutil_submit_ev(ulong pid, ref ByteBuffer buf) {
    do { sys_sendmsg(pid, 0, buf.size, buf.data); } while (errno == error.EINVAL);
}
Signal rpcutil_submit_sig(ulong pid, ref ByteBuffer buf) {
    Signal s = newSignal();
    ulong rid = ev_bind_callback((srcpid, rid, buf) {
        if (srcpid != pid) assert(false, "TODO: handle RPC hijacking");
        s.resolve();
    });
    do { sys_sendmsg(pid, rid, buf.size, buf.data); } while (errno == error.EINVAL);
    return s;
}
Future!(ubyte[]) rpcutil_submit(ulong pid, ref ByteBuffer buf) {
    Future!(ubyte[]) fut = newFuture!(ubyte[])();
    ulong rid = ev_bind_callback((srcpid, rid, buf) {
        if (srcpid != pid) assert(false, "TODO: handle RPC hijacking");
        fut.resolve(buf);
    });
    do { sys_sendmsg(pid, rid, buf.size, buf.data); } while (errno == error.EINVAL);
    return fut;
}
void rpcutil_prepare(ref ByteBuffer buf, uint rid) {
    rpcutil_encode_uint(buf, rid);
}
void rpcutil_sigrespond(ulong pid, ulong rid, Signal sig) {
    sig.then(() {
        do { sys_sendmsg(pid, rid, 0, null); } while (errno == error.EINVAL);
    });
}
T rpcutil_as_future(T)(T v) { return v; }
void rpcutil_respond_int(ulong pid, ulong rid, Future!int arg) {
    arg.then((ref int i) {
        ByteBuffer msg;
        rpcutil_encode_int(msg, i);
        do { sys_sendmsg(pid, rid, msg.size, msg.data); } while (errno == error.EINVAL);
    });
}