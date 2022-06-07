module progs.discoveryd.discoveryd;

import libxtrix.gc;
import libxtrix.io;
import libxk.stringmap;
import libxtrix.syscall;
import libxtrix.events;
import xtrix_rpc.logger;
import xtrix_rpc.svcdiscovery;

pragma(mangle, "main") extern(C)
int _main(ulong argc, char** argv) {
	printf("{}: starting discovery server...", argv[0]);

	struct decl {
		string name;
		ulong pid;
	}
	decl[] d = [];

	svcdiscovery_server.onDeclare((pid, name) {
		d = concat(d, decl(name, pid));
		return completedSignal();
	});
	svcdiscovery_server.onFind((name) {
		foreach (decl cd; d) {
			if (cd.name == name) {
				return completedFuture(cast(int)cd.pid);
			}
		}
		return newFuture!(int)(); // die
	});

	ev_loop();
	
	return 0;
}