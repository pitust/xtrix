module libxtrix.syscall;


void KeLog(const char* str, ulong length) {
    asm {
        mov RDI, length;
        mov RSI, str;
        int 0x10;
    }
}
