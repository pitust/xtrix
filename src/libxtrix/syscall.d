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

// layout: the layout of XHandle is a contract with the kernel.
struct XHandle {
	private ulong value;
	private error err;
	
	@disable this();
	this(ulong handleValue) {
		value = handleValue;
		err = error.EOK;
	}
	this(error handleValue) {
		err = handleValue;
		assert(err != error.EOK);
	}

	bool isError() {
		return err != error.EOK;
	}
	ulong getHandle() {
		assert(!isError, "handle XHandle errors correctly!");
		return value;
	}
	error getError() {
		assert(isError, "what? why are you getting an error? no errors here!");
		return err;
	}
	type getType() {
		return KeGetType(this);
	}
	type type_of() {
		return KeGetType(this);
	}
	ref XHandle aok(string file = __FILE__, int line = __LINE__)(string assertion = "Expected valid handle") {
		if (isError) __assert(assertion.ptr, file.ptr, line);
		return this;
	}
	void release() {
		KeDeleteObject(this);
		this.err = error.ESTALE;
	}
}

XHandle long2handle(long l) {
	if (l < 0) return XHandle(cast(error)-l);
	return XHandle(cast(ulong)l);
}

XHandle KeCreateVM() {
	long r;
	asm {
		int 0x11;
		mov r, RAX;
	}
	return long2handle(r);
}
long KeLoadELF(XHandle vm, XHandle elf) {
	ulong vmp = vm.getHandle, elfp = elf.getHandle;
	long r;

	asm {
		mov RDI, vmp;
		mov RSI, elfp;
		int 0x12;
		mov r, RAX;
	}
	return r;
}
XHandle KeCreateThread(XHandle vm, ulong rip, ulong rdi, ulong rsi, ulong rdx, ulong rsp) {
	ulong vmp = vm.getHandle;
	long h;
	asm {
		mov RDI, vmp;
		mov RSI, rip;
		mov RDX, rdi;
		mov RCX, rsi;
		mov R8, rdx;
		mov R9, rsp;
		int 0x16;
		mov h, RAX;
	}
	return long2handle(h);
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
XHandle KeAllocateMemoryObject(ulong size) {
	long r;
	asm {
		mov RDI, size;
		int 0x1b;
		mov r, RAX;
	}
	return long2handle(r);
}
error KeReadMemory(XHandle obj, ulong addr, ulong count, void* outaddr) {
	error r;
	if (obj.isError) assert(false, "Cannot map an error into memory dumbo");
	ulong hvalue = obj.getHandle();
	asm {
		mov RDI, hvalue;
		mov RSI, addr;
		mov RDX, count;
		mov RCX, outaddr;
		int 0x1e;
		mov r, RAX;
	}
	return r;
}
error KeMapMemory(XHandle vm, ulong addr, XHandle h) {
	error r;
	ulong vmvalue = vm.getHandle();
	ulong hvalue = h.getHandle();
	asm {
		mov RDI, vmvalue;
		mov RSI, hvalue;
		mov RDX, addr;
		int 0x33;
		mov r, RAX;
	}
	return r;
}
error KeMapMemory(XHandle h, ulong addr) {
	error r;
	if (h.isError) assert(false, "Cannot map an error into memory dumbo");
	ulong hvalue = h.getHandle();
	asm {
		mov RDI, hvalue;
		mov RSI, addr;
		int 0x35;
		mov r, RAX;
	}
	return r;
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
ulong KeASLRAddress() {
	ulong res;
    asm {
        int 0x13;
		mov res, RAX;
    }
	return res;
}
XHandle KeReadPhysicalMemory(ulong addr, ulong  size) {
	long r;
	asm {
		mov RDI, addr;
		mov RSI, size;
		int 0x38;
		mov r, RAX;
	}
	return long2handle(r);
}
error KeReadPhysicalMemory(ulong addr, ulong size, void* outaddr) {
	error r;
	asm {
		mov RDI, addr;
		mov RSI, size;
		mov RDX, outaddr;
		int 0x39;
		mov r, RAX;
	}
	return r;
}
XHandle KeInvoke(XHandle chan, XHandle msg) {
	long ret;
	ulong chanh = chan.getHandle;
	ulong msgh = msg.getHandle;
	asm {
		mov RDI, chanh;
		mov RSI, msgh;
		int 0x3b;
		mov ret, RAX;
	}
	return long2handle(ret);
}
XHandle KeCreateKeyedChannel(ulong key) {
	long res;
	asm {
		mov RDI, key;
		int 0x27;
		mov res, RAX;
	}
	return long2handle(res);
}
void KeDeleteObject(XHandle to_be_deleted) {
	ulong a = to_be_deleted.getHandle;
	asm {
		mov RDI, a;
		int 0x22;
	}
}
error KeRespond(XHandle resulter, XHandle response) {
	ulong a = resulter.getHandle, b = response.getHandle;
	error res;
	asm {
		mov RDI, a;
		mov RSI, b;
		int 0x3d;
		mov res, RAX;
	}
	return res;
}
XHandle KePoll(XHandle* channels, ulong count, ulong* selected, XHandle* resulter) {
	long res;
	long theresulter;
	asm {
		mov RDI, channels;
		mov RSI, count;
		mov RDX, selected;
		lea RCX, resulter;
		int 0x3c;
		mov res, RAX;
	}
	*resulter = long2handle(theresulter);
	return long2handle(res);
}
