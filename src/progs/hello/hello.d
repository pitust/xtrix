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
import libxtrix.syscall;
import libsrpc.rpc_server;
import libxtrix.libc.malloc;
import progs.init.init_srpc;


/// _start is the OS-invoked entrypoint for xtrix user programs
pragma(mangle, "main") extern(C)
int _main(ulong argc, char** argv) {
	printf("{}: hello, world!", argv[0]);
	long xid = sys_open_pipe(PipeSide.client, 0x4141_4242);
	anoerr("sys_open_pipe");

	printf("pipe: {x}", xid);
	// ulong[1] data = [69_420];
	// sys_send_data(xid, cast(void*)data.ptr, 8);
	ulong u = 1337;
	sys_send_data(xid, &u, u.sizeof);
	printf("ul: {}", u);
	anoerr("sys_send_data");
	// sys_close(xid);
	// anoerr("sys_close");
	
	InitSRPC* conn = connect!(InitSRPC)(0x1314d0deda64c37a);

	return 0;
}
