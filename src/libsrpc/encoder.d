module libsrpc.encoder;

import libxtrix.io;
import libxk.bytebuffer;

ByteBuffer encode(T)(T value) {
    ByteBuffer buf;
    static if (is(T == ubyte)) {
        buf << value;
    } else static if (is(T == ulong)) {
        buf.writeRaw(&value, 8);
    } else static if (is(T == uint)) {
        buf.writeRaw(&value, 4);
    } else static if (is(T == string)) {
        buf << encode(cast(uint)value.length);
        foreach (c; value) {
            buf << cast(ubyte)c;
        }
    } else static assert(false, "cannot encode type " ~ T.stringof);

    return buf;
}

T decode(T)(ubyte* payload, ulong length, ref ulong offset) {
    static assert(false, "Cannot decode " ~ T);
}
