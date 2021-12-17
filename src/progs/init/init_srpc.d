// SRPC handler for init
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
module progs.init.init_srpc;


import libxtrix.io;
import libxk.malloc;
import libsrpc.rpc_server;

struct InitSRPC {
	this() @disable;
	void close();
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
	void set(ulong val) { i = val; }
	ulong update(ulong val) { ulong old = i; i = val; return old; }
}

void rpc_publish() {
	srpc_impl* impl = alloc!(srpc_impl)();
	RPCListener l = publish_srpc!(InitSRPC)(impl);
	l.attach(0x1314d0deda64c37a);
	l.loop();
}
