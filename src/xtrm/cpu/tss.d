module xtrm.cpu.tss;

private __gshared ubyte[0x6b] tss;

void set_rsp0(ubyte[] rsp0) {
    *cast(ulong*)&tss[4] = cast(ulong)&rsp0.ptr[rsp0.length];
}

ulong tss_init() {
    tss[0x66] = 13;

    return cast(ulong)tss.ptr;
}