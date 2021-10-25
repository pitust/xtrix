module libxtrix.io;

import libxtrix.syscall;

private __gshared char[4096] printf_buffer;
private __gshared ulong printf_buf_offset = 0;

private void putch(char c) {
	if (c == '\n') {
		KeLog(printf_buffer.ptr, printf_buf_offset);
	} else {
		printf_buffer[printf_buf_offset++] = c;
	}
}

void _pvalue(T)(T value) {
	assert(false, "todo print of type " ~ T.stringof);
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
