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
	ETYPE = -1,
	EACCES = -2,
	ENOSYS = -3,
    EAGAIN = -4
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
}

XHandle long2handle(long l) {
	if (l < 0) return XHandle(cast(error)-l);
	return XHandle(cast(ulong)l);
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
        mov RDI, length;
        mov RSI, str;
        int 0x10;
    }
}
void KeLog(string str) {
	KeLog(str.ptr, str.length);
}
