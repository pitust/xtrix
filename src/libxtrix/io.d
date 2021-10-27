module libxtrix.io;

import libxtrix.syscall;
import libxtrix.intops;

private __gshared char[4096] printf_buffer;
private __gshared ulong printf_buf_offset = 0;

private void putch(char c) {
	if (c == '\n') {
		KeLog(printf_buffer.ptr, printf_buf_offset);
		printf_buf_offset = 0;
	} else {
		printf_buffer[printf_buf_offset++] = c;
	}
}

void _pvalue(T)(T value) {
	static if (is(T == ulong)) {
		_pvalue("<ulong>");	
	} else static if (is(T == int)) {
		sprinti(value, 10, 0, "", "", &putch, "", "", "", "", "");
	} else static if (is(T == string)) {
		foreach (chr; value) putch(chr);
	} else static if (is(T : immutable(char)*) || is(T : char*)) {
		while (*value) putch(*value++);
	} else {
		static assert(false, "todo print of type " ~ T.stringof);
	}
}

void printf(Args...)(string fmt, Args argz) {
	ulong off = 0;
	static foreach (arg; argz) {{
		while (true) {
			if (fmt[off] == '{' && fmt[off + 1] == '}') break;
			putch(fmt[off++]);
		}
		off += 2;
		_pvalue(arg);
	}}

	while (off < fmt.length) putch(fmt[off++]);
	putch('\n');
}
