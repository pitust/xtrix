module progs.init.init_srpc;

// BLOCKED ON: srpc



// import libxtrix.io;
// import libxk.malloc;
// import libsrpc.rpc_server;

// struct InitSRPC {
//     this() @disable;
//     void close();
//     void hello();
//     ulong get();
//     void set(ulong val);
//     ulong update(ulong val);
// }

// struct srpc_impl {
//     ulong i = 0;
//     void hello() { printf("hello, world!"); }
//     ulong get() { return i; }
//     void inc() { i++; }
//     void set(ulong val) { i = val; }
//     ulong update(ulong val) { ulong old = i; i = val; return old; }
// }

// void rpc_publish() {
//     srpc_impl* impl = alloc!(srpc_impl)();
//     RPCListener l = publish_srpc!(InitSRPC)(impl);
// 	l.attach(0x1314d0deda64c37a);
// 	l.loop();
// }
