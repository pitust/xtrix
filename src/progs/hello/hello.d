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
import libxtrix.libc.malloc;

/// _start is the OS-invoked entrypoint for xtrix user programs
extern (C) void _start() {
	XHandle chan = KeCreateChannel();
	if (chan.isError) assert(false, "KeCreateChannel failed!");
	{
		string msg = "hello, channel world!";
		XHandle data_out = KeAllocateMemRefObject(msg);
		assert_success(data_out);
		assert_success(KePushMessage(chan, data_out));
		printf("sent message: {}", msg);
	}

	{
		XHandle msg = KePopMessage(chan);
		assert_success(msg);
		if (msg.getType() != type.memref)
			assertf(false, "popped data handle is of type {}, expected type::memref", msg.getType());
		
		ulong msg_size = KeGetMemObjectSize(msg);
		char* data_in = cast(char*)malloc(msg_size + 1);
		assert_success(KeReadMemory(msg, 0, msg_size, data_in));
		printf("recieved message: {}", data_in);
	}

	while (true) {}
}
