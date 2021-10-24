module xtrm.cpu.gdt;

import xtrm.cpu.tss;

private __gshared ulong[7] gdt = [
    /* [ 00 ] */ 0x0000000000000000, // null

    /* [ 08 ] */ 0x0000000000000000, // TSS (low)
    /* [ 10 ] */ 0x0000000000000000, // TSS (high)

    /* [ 18 ] */ 0x00affb000000ffff, // usermode 64-bit code
    /* [ 20 ] */ 0x00aff3000000ffff, // usermode 64-bit data

    /* [ 28 ] */ 0x00af9b000000ffff, // 64-bit code
    /* [ 30 ] */ 0x00af93000000ffff, // 64-bit data
];

private __gshared ubyte[10] gdtr;

private ulong bits(ulong shiftup, ulong shiftdown, ulong mask, ulong val) {
    return ((val >> (shiftdown - mask)) & ((1 << mask) - 1)) << shiftup;
}

void init_gdt() {
    ulong tss = tss_init();

    gdt[1] = 
        bits(16, 24, 24, tss) | bits(56, 32, 8, tss) | (103 & 0xff) | ((0b1001UL) << 40) | ((1UL) << 47);
    gdt[2] = tss >> 32;

    gdtr[0] = 7 * 8 - 1; gdtr[1] = 0x00;
    *cast(ulong**)(&gdtr[2]) = gdt.ptr;
    ubyte* gdtr_raw = gdtr.ptr;
    asm {
        mov RAX, gdtr_raw;
        lgdt [RAX];
    }

}