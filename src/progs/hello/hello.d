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

/// _start is the OS-invoked entrypoint for xtrix user programs
extern (C) void _start() {
    printf("creating a channel...");
	XHandle chan = KeCreateChannel();
	if (chan.isError) assert(false, "KeCreateChannel failed!");
	printf("channel handle: {}", chan.getHandle());
	XHandle data = KeAllocateMemRefObject("hello, channel world!");
	if (data.isError) assert(false, "KeAllocateMemRefObject failed!");
	printf("data handle: {}", data.getHandle());
	error e = KePushMessage(chan, data);
	if (e) printf("error pushing message: {}", cast(long)e);

	while (true) {}
}
