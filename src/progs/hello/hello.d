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
pragma(mangle, "main") int _main() {
	printf("hello: welcome to process 2!");
	// InitSRPC* rpc = connect!(InitSRPC)(0x1314d0deda64c37a);
	// printf("(hello) rpc time!");
	// rpc.hello();
	// printf("value: {}", rpc.get());
	// printf("value: {}", rpc.update(69));
	// printf("value: {}", rpc.update(420));
	// rpc.set(0x41414242);
	// printf("value: {x}", rpc.get());
	// rpc.set(0);
	while (true) {}
}
