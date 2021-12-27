module progs.discoveryd.discoveryd;

import libxtrix.io;
import libxk.malloc;
import libxk.stringmap;
import libsrpc.rpc_server;

__gshared StringMap!(ulong) idm;

struct discoveryimpl {
	ulong lookup(string name) {
        if (name !in idm) return 0;
        return idm[name];
    }
	void declare(string name, ulong id) {
        if (name in idm) {
            printf("failed to declare {}: already declared!", name);
            return;
        }
        idm[name] = id;
    }
}

pragma(mangle, "main") extern(C)
int _main(ulong argc, char** argv) {
	printf("{}: starting discovery server...", argv[0]);

    idm["discoveryd"] = SRPC_FIND;
    
    discoveryimpl* impl = alloc!(discoveryimpl)();
	RPCListener l = publish_srpc!(InitServerConn)(impl);
	l.attach(SRPC_FIND);
	l.loop();

    return 0;
}