module progs.init.init_srpc;

import libxtrix.io;
import libxk.malloc;
import libsrpc.rpc_server;

struct InitSRPC {
    this() @disable;
    void hello();
    ulong get();
    void set(ulong val);
    ulong update(ulong val);
}

struct srpc_impl {
    ulong i = 0;
    void hello() { printf("hello, world!"); }
    ulong get() { return i; }
    void inc() { i++; }
}

void rpc_publish() {
    srpc_impl* impl = alloc!(srpc_impl)();
    publish_srpc!(InitSRPC)("init_srpc", impl);
}
