module progs.discoveryd.discoveryd;

import libxtrix.gc;
import libxtrix.io;
import libxk.stringmap;
import libxtrix.syscall;
import libxtrix.events;
import xtrix_rpc.logger;

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

	logger_server.onLogLine((line) {
		printf("log: {}", line);
	});

	ev_loop();
	
	return 0;
}