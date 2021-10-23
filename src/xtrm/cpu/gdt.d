module xtrm.cpu.gdt;

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

void init_gdt() {
    gdtr[0] = 7 * 8 - 1; gdtr[1] = 0x00;
    *cast(ulong**)(&gdtr[2]) = gdt.ptr;
    ubyte* gdtr_raw = gdtr.ptr;
    asm {
        mov RAX, gdtr_raw;
        lgdt [RAX];
    }

}