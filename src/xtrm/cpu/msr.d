module xtrm.cpu.msr;

ulong rdmsr(uint msr) {
    ulong res;
    asm {
        mov ECX, msr;
        rdmsr;
        shl RDX, 32;
        or RAX, RDX;
        mov res, RAX;
    }
    return res;
}