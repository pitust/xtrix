// libxtrix system call wrappers
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
module libxtrix.syscall;

private extern(C) void __assert(const char* assertion, const char* file, int line);

enum error : long {
	EOK = 0,
	ETYPE = -1,
	EACCES = -2,
	ENOSYS = -3,
    EAGAIN = -4,
    EFAULT = -5,
    EINVAL = -6,
    ESTALE = -9999
}

// the enumeration is a contract with the kernel.
enum type {
    nullobj,
    mem,
    memref,
    vm,
    thr,
    chan,
    cred,
    credproof,
    credverity,
	responder,
}

void sys_dbglog(const char* str, ulong length) {
    asm {
        mov RDI, str;
        mov RSI, length;
        int 0x10;
    }
}
void sys_dbglog(string str) {
	sys_dbglog(str.ptr, str.length);
}


void sys_mmap(ulong addr, ulong size) {
	assert(false, "TODO: mmap");
}
