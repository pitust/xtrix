// libxtrix D-only io code
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
module libxtrix.io;

import std.traits;
import libxtrix.intops;
import libxtrix.syscall;

private __gshared char[4096] printf_buffer;
private __gshared ulong printf_buf_offset = 0;
private __gshared char printmode = ' ';

private void putch(char c) {
	if (c == 0) return;
	if (c == '\n') {
		KeLog(printf_buffer.ptr, printf_buf_offset);
		printf_buf_offset = 0;
	} else {
		printf_buffer[printf_buf_offset++] = c;
	}
}

private template uq(T) {
	static if (is(T U == const(U)[])) {
		alias uq = U[];
	} else static if (is(T U == immutable(U)[])) {
		alias uq = U[];
	} else alias uq = T;
}

void _pvalue(T)(T value) {
	static if (isNumeric!(T) && !is(T U == enum)) {
		int base, pad = 0;
		const(char)* prefix;
		if (printmode == ' ') { base = 10; prefix = ""; }
		else if (printmode == 'x') { base = 16; prefix = "0x"; }
		else if (printmode == '*') { base = 16; prefix = "0x"; pad = 16; }
		else if (printmode == 'p') { base = 16; prefix = "0x"; pad = 16; }
		else assertf(false, "Unknown print mode {}", printmode);
		sprinti(value, base, pad, "0", prefix, &putch, "", "", "", "", "");
	} else static if (is(T == string)) {
		foreach (chr; value) putch(chr);
	} else static if (is(T == char)) {
		putch(value);
	} else static if (is(T : immutable(char)*) || is(T : char*)) {
		while (*value) putch(*value++);
	} else static if (is(uq!(T) : char[])) {
		foreach (chr; value) putch(chr);
	} else static if (__traits(isStaticArray, T) && is(typeof(uq!(T).init[0]) == char)) {
		foreach (chr; value) putch(chr);
	} else static if (is(T == error)) {
		if(false) {}
		else if (value == error.EOK) _pvalue("No error");
		else if (value == error.ETYPE) _pvalue("Inappropriate type or format");
		else if (value == error.EACCES) _pvalue("Permission denied");
		else if (value == error.ENOSYS) _pvalue("Function not implemented");
		else if (value == error.EAGAIN) _pvalue("Resource temporarily unavailable");
		else if (value == error.EFAULT) _pvalue("Bad address");
		else if (value == error.EINVAL) _pvalue("Invalid argument");
		else _pvalue("Unknown error");
	} else static if (is(T == type)) {
		if(false) {}
		else if (value == type.nullobj) _pvalue("type::nullobj");
		else if (value == type.mem) _pvalue("type::mem");
		else if (value == type.memref) _pvalue("type::memref");
		else if (value == type.vm) _pvalue("type::vm");
		else if (value == type.thr) _pvalue("type::thr");
		else if (value == type.chan) _pvalue("type::chan");
		else if (value == type.cred) _pvalue("type::cred");
		else if (value == type.credproof) _pvalue("type::credproof");
		else if (value == type.credverity) _pvalue("type::credverity");
		else _pvalue("type::<unknown>");
	} else {
		static assert(false, "todo print of type " ~ T.stringof);
	}
}

void printf(Args...)(string fmt, Args argz) {
	ulong off = 0;
	static foreach (arg; argz) {{
		while (true) {
			if (fmt[off] == '{' && fmt[off + 1] == '}') break;
			if (fmt[off] == '{' && fmt[off + 2] == '}') break;
			putch(fmt[off++]);
		}
		off += 2;
		printmode = ' ';
		if (fmt[off - 1] != '}') {
			off += 1;
			printmode = fmt[off - 2];
		}
		_pvalue(arg);
	}}

	while (off < fmt.length) putch(fmt[off++]);
	putch('\n');
}
void assertf(string file = __FILE__, int line = __LINE__, AssertT, Args...)(AssertT at, string fmt, Args argz) {
	if (at) return;
	ulong off = 0;
	_pvalue("Assertion failed: '");
	static foreach (arg; argz) {{
		while (true) {
			if (fmt[off] == '{' && fmt[off + 1] == '}') break;
			putch(fmt[off++]);
		}
		off += 2;
		_pvalue(arg);
	}}

	while (off < fmt.length) putch(fmt[off++]);
	printf("' at {}:{}", file, line);
	while (1) {}
}


void assert_success(string file = __FILE__, uint line = __LINE__)(error e) {
	if (e != error.EOK) {
		printf("Unexpected error: {} at {}:{}", e, file, line);
	}
}
void assert_success(string file = __FILE__, uint line = __LINE__)(XHandle h) {
	if (h.isError()) assert_success!(file, line)(h.getError());
}