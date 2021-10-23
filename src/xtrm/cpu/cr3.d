module xtrm.cpu.cr3;

ulong cr3() {
    ulong value;
    asm {
        mov RAX, CR3;
        mov value, RAX;
    }
    return value;
}
void copy_from_cr3(ulong[256]* cr3out) {
    static assert((*cr3out).sizeof == 2048);
    asm {
        mov RSI, CR3;
        mov RDI, 0xffff800000000000;
        add RSI, RDI;
        mov RDI, cr3out;
        mov RCX, 2048;
        rep; movsb;
    }
}
void copy_to_cr3(ulong[256]* cr3in) {
    static assert((*cr3in).sizeof == 2048);
    asm {
        mov RSI, CR3;
        mov RDI, 0xffff800000000000;
        add RDI, RSI;
        mov RSI, cr3in;
        mov RCX, 2048;
        rep; movsb;
    }
}
void init_low_half() {
    asm {
        mov RDI, CR3;
        mov RSI, 0xffff800000000000;
        add RDI, RSI;
        mov RAX, 0;
        mov RCX, 2048;
        rep; stosb;
    }
}