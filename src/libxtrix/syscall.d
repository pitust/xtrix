module libxtrix.syscall;

import libxtrix.io; // todo: circular dep

enum error {
	type_error,
	perm_error,
	lock_error,
	todo_error
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
	if (r > 0) printf("kecreatechannel is calling long2handle with errors");
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
