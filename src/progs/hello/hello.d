// Userland hello, world! program for xtrix
// Copyright (C) 2021 pitust <piotr@stelmaszek.com>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

module progs.hello.hello;

import libxtrix.io;
import libxtrix.events;
import libxtrix.syscall;
import libxtrix.libc.malloc;
import xtrix_rpc.logger;
import xtrix_rpc.svcdiscovery;


/// _start is the OS-invoked entrypoint for xtrix user programs
pragma(mangle, "main") extern(C)
int _main(ulong argc, char** argv) {
	printf("{}: hello, world!", argv[0]);
	
	auto client = logger_client(2);
	client.LogLine("Attempting to declare as hello...");
	auto svcclient = svcdiscovery_client(2);
	svcclient.Declare(3, "hello").then(() {
		client.LogLine("Now discovering hello...");
		return svcclient.Find("hello");
	}).then((ref int pid) {
		printf("hello => {}", pid);
		sys_exit(1);
	});
	
	ev_loop();
	return 0;
}
