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
}

__gshared extern(C) long errno;

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

// - (02) sys_phymap(phy, virt, len)
void sys_phymap(ulong phy, ulong virt, ulong len) {
    assert(false, "TODO: phymap");
}
// - (13) sys_phyread(phy, virt, len)
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
// - (03) sys_open_pipe(side: 0=client 1=server, chan) -> xid
// - (04) sys_close(xid)
// - (05) sys_send_region(xid, addr, len)
// - (06) sys_recv_region(xid, addr, len) -> 0=success 1=fail
// - (07) sys_send_data(xid, dataptr, len)
// - (08) sys_recv_data_len(xid) -> len
// - (09) sys_recv_data(xid, dataptr, len) -> 0=success 1=fail
// - (0a) sys_send_ul(xid, ulong)
// - (0b) sys_recv_ul(xid) -> ulong
// - (0c) sys_send_barrier(xid)
// - (0d) sys_recv_barrier(xid)
// - (0e) sys_getpid() -> pid
// - (0f) sys_getuid() -> uid
// - (10) sys_fork() -> 0=child cpid=parent
// - (11) sys_exec(elfptr, elfsz, argc, argv)
// - (12) sys_setuid(sub-uid)


pragma(mangle, "main")
private extern(C) void target_main(ulong argc, ulong argv);

extern(C) void _start() {
    sys_dbglog("_start!");
    target_main(0, 0);
    while(1) {}
}
