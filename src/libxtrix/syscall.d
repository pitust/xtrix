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

enum error : long {
	EOK = 0,
	ETYPE = -1,
	EACCES = -2,
	ENOSYS = -3,
    EAGAIN = -4,
    EFAULT = -5,
}

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
}

struct XHandle {
	private bool _isError;
	private ulong _inner;
	private error _inner_err;
	
	@disable this();
	this(ulong handleValue) {
		_inner = handleValue;
		_isError = false;
	}
	this(error handleValue) {
		_inner_err = handleValue;
		_isError = true;
	}

	bool isError() {
		return _isError;
	}
	ulong getHandle() {
		assert(!isError, "handle XHandle errors correctly!");
		return _inner;
	}
	error getError() {
		assert(isError, "what? why are you getting an error? no errors here!");
		return _inner_err;
	}
	type getType() {
		return KeGetType(this);
	}
}

XHandle long2handle(long l) {
	if (l < 0) return XHandle(cast(error)-l);
	return XHandle(cast(ulong)l);
}

type KeGetType(XHandle handle) {
	ulong xh = handle.getHandle();
	type ty;
	asm {
		mov RDI, xh;
		int 0x24;
		mov ty, RAX;
	}
	return ty;
}
error KePushMessage(XHandle chan, XHandle obj) {
	if (chan.isError || obj.isError) assert(false, "Handle errors before calling KePushMessage!");
	error e;
	ulong ch = chan.getHandle(), oh = obj.getHandle();
	asm {
		mov RDI, ch;
		mov RSI, oh;
		int 0x2b;
		mov e, RAX;
	}
	return e;
}
ulong KeGetMemObjectSize(XHandle memhandle) {
	ulong mh = memhandle.getHandle();
	ulong size;
	asm {
		mov RDI, mh;
		int 0x1d;
		mov size, RAX;
	}
	return size;
}
XHandle KePopMessage(XHandle chan) {
	long r;
	ulong ch = chan.getHandle();
	asm {
		mov RDI, ch;
		int 0x2c;
		mov r, RAX;
	}
	return long2handle(r);
}
XHandle KeAllocateMemRefObject(const(void)* data, ulong size) {
	long r;
	asm {
		mov RDI, data;
		mov RSI, size;
		int 0x1c;
		mov r, RAX;
	}
	return long2handle(r);
}
// byte, ubyte and string forms
XHandle KeAllocateMemRefObject(byte[] data) {
	return KeAllocateMemRefObject(data.ptr, data.length);
}
XHandle KeAllocateMemRefObject(ubyte[] data) {
	return KeAllocateMemRefObject(data.ptr, data.length);
}
XHandle KeAllocateMemRefObject(string data) {
	return KeAllocateMemRefObject(data.ptr, data.length);
}
XHandle KeCreateChannel() {
	long r;
	asm {
		int 0x26;
		mov r, RAX;
	}
	return long2handle(r);
}
void KeLog(const char* str, ulong length) {
    asm {
        mov RDI, str;
        mov RSI, length;
        int 0x10;
    }
}
void KeLog(string str) {
	KeLog(str.ptr, str.length);
}
