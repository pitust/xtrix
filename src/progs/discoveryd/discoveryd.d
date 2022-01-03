module progs.discoveryd.discoveryd;

import libxtrix.gc;
import libxtrix.io;
import libxk.stringmap;
import libxtrix.syscall;
import libxtrix.events;
import xtrix_rpc.logger_rpc;

// struct discoveryimpl {
// 	ulong lookup(string name) {
//         if (name !in idm) return 0;
//         return idm[name];
//     }
// 	void declare(string name, ulong id) {
//         if (name in idm) {
//             printf("failed to declare {}: already declared!", name);
//             return;
//         }
//         idm[name] = id;
//     }
// }

pragma(mangle, "main") extern(C)
int _main(ulong argc, char** argv) {
	printf("{}: starting discovery server...", argv[0]);

	// logger_rpc_server.onLogLine((line) {
	//     printf("log: {}", line);
	// });

	// ev_loop();

	Signal sig = newSignal();
	Future!int fut = newFuture!(int)();
	sig.then(delegate int() {
		return 3;
	}).then((ref int i) {
		fut.resolve(i);
		return i;
	}).then(delegate int(ref int i) {
		return i * 2;
	}).then((ref int i) {
		printf("value: {}", i);
		return i;
	});
	sig.resolve();
	fut.then((ref int i) {
		printf("value: {}", i);
	});

	// pid, rid, len, data
	ubyte[2] data = [69, 69];
	ulong rid = ev_bind_callback(delegate bool(pid, rid, buf) {
		assert(buf.length == 2);
		printf("resonse: {} {}", buf[0], buf[1]);
		return true;
	});
	sys_sendmsg(2, rid, 2, data.ptr); anoerr("sys_sendmsg");
	ev_loop();
	
	return 0;
}