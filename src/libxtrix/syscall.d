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
	EACCES = -1,
	ENOSYS = -2,
	EAGAIN = -3,
	EFAULT = -4,
	EINVAL = -5,
	EWOULDBLOCK = -6,
}

__gshared extern(C) long errno;

long getpipe(long xid, long pipeid) {
	return xid << 8 | pipeid | (1UL << 63);
}

void sys_dbglog(const char* str, ulong length) {
	asm {
		mov RDI, str;
		mov RSI, length;
		int 0x10;
	}
}
void sys_dbglog(const char[] str) {
	sys_dbglog(str.ptr, str.length);
}

void sys_mmap(ulong addr, ulong size) {
	import libxtrix.io : anoerr;
	long eno;
	asm {
		mov RDI, addr;
		mov RSI, size;
		int 0x11;
		mov eno, RAX;
	}
	errno = eno;
	anoerr("sys_mmap"); // todo: probably not assert :^)
}

/// - (02) sys_phymap(phy, virt, len)
long sys_phymap(ulong phy, ulong virt, ulong len) {
	long r;
	asm {
		mov RDI, phy;
		mov RSI, virt;
		mov RDX, len;
		int 0x12;
		mov r, RAX;
	}
	errno = r;
	return r;
}
/// - (13) sys_phyread(phy, virt, len)
long sys_phyread(ulong phy, void* virt, ulong len) {
	long res;
	asm {
		mov RDI, phy;
		mov RSI, virt;
		mov RDX, len;
		int 0x23;
		mov res, RAX;
	}
	errno = res;
	return res;
}

// friendship pipes are anonymous
enum PipeSide : ulong { client = 0, server = 1, friendship = 2 }
// - (03) sys_open_pipe(side: 0=client 1=server, chan) -> xid
long sys_open_pipe(PipeSide side, ulong chan) {
	long xid;
	asm {
		mov RDI, side;
		mov RSI, chan;
		int 0x13;
		mov xid, RAX;
	}
	if (xid < 0) errno = xid;
	return xid;
}
// - (04) sys_close(xid)
void sys_close(ulong xid) {
	long res;
	asm {
		mov RDI, xid;
		int 0x14;
		mov res, RAX;
	}
	errno = res;
}
// - (05) sys_send_region(xid, addr, len)
// - (06) sys_recv_region(xid, addr, len) -> 0=success 1=fail
// - (07) sys_send_data(xid, dataptr, len)
error sys_send_data(ulong xid, void* dataptr, ulong len) {
	long res;
	asm {
		mov RDI, xid;
		mov RSI, dataptr;
		mov RDX, len;
		int 0x17;
		mov res, RAX;
	}
	errno = res;
	return cast(error)res;
}
// - (08) sys_send_vectored(xid, dataptr*, len*, rcount)
error sys_send_vectored(ulong xid, void*[] data, ulong[] len) {
	assert(data.length == len.length);
	return sys_send_vectored(xid, data.ptr, len.ptr, data.length);
}
error sys_send_vectored(ulong xid, void** data, ulong* len, ulong rcount) {
	long res;
	asm {
		mov RDI, xid;
		mov RSI, data;
		mov RDX, len;
		mov RCX, rcount;
		int 0x18;
		mov res, RAX;
	}
	errno = res;
	return cast(error)res;
}
// - (09) sys_recv_data(xid, dataptr, len)
error sys_recv_data(ulong xid, void* dataptr, ulong len) {
	long res;
	asm {
		mov RDI, xid;
		mov RSI, dataptr;
		mov RDX, len;
		int 0x19;
		mov res, RAX;
	}
	errno = res;
	return cast(error)res;
}
// - (0c) sys_silent_exit()
void sys_silent_exit() {
	asm {
		int 0x1c;
	}
}
// - (0d) sys_sendmsg(pid, rid, len, data)
void sys_sendmsg(ulong pid, ulong rid, ulong len, void* data) { 
	long res;
	asm {
		mov RDI, pid;
		mov RSI, rid;
		mov RDX, len;
		mov RCX, data;
		int 0x1d;
		mov res, RAX;
	}
	errno = res;
}
struct Message {
	ulong srcpid;
	ulong rid;
	ulong len;
}
long sys_recvmsg(Message* msg, void* arena, ulong maxlen, bool block) {
	ulong x;
	long res;
	ulong blocki = block;
	asm {
		mov RDI, msg;
		mov RSI, arena;
		mov RDX, maxlen;
		mov RCX, blocki;
		int 0x1e;
		mov res, RAX;
	}
	errno = res;
	return res;
}
// - (0e) sys_getpid() -> pid
// - (0f) sys_getuid() -> uid

/// - (10) sys_fork() -> 0=child cpid=parent
long sys_fork() {
	long r;
	asm {
		int 0x20;
		mov r, RAX;
	}
	errno = r < 0 ? r : 0;
	return r;
}

/// - (11) sys_exec(elfptr, elfsz, argc, argv)
long sys_rawexec(void* elfptr, ulong elfsz, ulong argc, char** argv) {
	long r;
	asm {
		mov RDI, elfptr;
		mov RSI, elfsz;
		mov RDX, argc;
		mov RCX, argv;
		int 0x21;
		mov r, RAX;
	}
	errno = r;
	return r;
}
// - (12) sys_setuid(sub-uid)
// - (14) sys_exit(code)
private extern(C) void ev_atexit();
private extern(C) void do_exit(ulong code) {
	asm {
		mov RDI, code;
		int 0x24;
	}
}
void sys_exit(ulong code) {
	ev_atexit();
	do_exit(code);
	assert(false, "cannot continue after exit!");
}

// - (15) sys_wait(pid) -> pid, resulting code
long sys_wait(out ulong code) {
	long result;
	code = 0;
	asm {
		int 0x25;
		mov result, RAX;
		mov code, RBX;
	}
	if (result < 0) errno = result;
	return result;
}
// - (16) sys_waitfor(pid) -> resulting code



pragma(mangle, "main")
private extern(C) int target_main(ulong argc, char** argv);

pragma(mangle, "elfbase") extern __gshared void* theelfbase;
pragma(mangle, "elftop") extern __gshared void* theelftop;

extern(C) void _start(ulong argc, char** argv) {
	import libxtrix.gc : elfbase, elftop;

	elfbase = &theelfbase; elftop = &theelftop;
	assert(elfbase && elftop);

	asm { xor RAX, RAX; } // a pathetic attempt at setting the result value to zero
	int code = target_main(argc, argv);
	sys_exit(code);
}