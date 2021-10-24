module progs.hello.hello;

void log(string s) {
    ulong leng = s.length;
    immutable(char)* strd = s.ptr;
    asm {
        mov RDI, leng;
        mov RSI, strd;
        int 0x10;
    }
}

extern (C) void _start() {
    log("hello, world!");
    while (true) {}
}