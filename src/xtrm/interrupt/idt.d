module xtrm.interrupt.idt;

import xtrm.memory;
import xtrm.io;

private extern(C) void isr_common();

private __gshared ubyte[4096] isr_data;
private __gshared ulong offset = 0;

private __gshared ubyte[4096] idt;

private __gshared ubyte[10] idtr;

private ulong makeisr(ubyte isr) {
    ulong addr = offset;
    uint isr_common_ptr = cast(uint)&isr_common;
    // cool huh?
    ubyte[4] isr_common_bytes = *cast(ubyte[4]*)&isr_common_ptr;

    if (((isr) < 0x8 || isr > 0xE) && isr != 0x11 && isr != 0x1E) {
        // push imm8[0]
        isr_data[offset++] = 0x6a;
        isr_data[offset++] = 0x00;
    }
    // push imm32[isr_data]
    isr_data[offset++] = 0x68;
    isr_data[offset++] = isr;
    isr_data[offset++] = 0x00;
    isr_data[offset++] = 0x00;
    isr_data[offset++] = 0x00;

    // push imm32[isr_common]
    isr_data[offset++] = 0x68;
    isr_data[offset++] = isr_common_bytes[0];
    isr_data[offset++] = isr_common_bytes[1];
    isr_data[offset++] = isr_common_bytes[2];
    isr_data[offset++] = isr_common_bytes[3];

    // ret
    isr_data[offset++] = 0xc3;

    return cast(ulong)&isr_data[addr];
}

void init_idt() {
    ulong irqs_offset = 0;
    foreach (ubyte isr; 0 .. 256) {
        assert(!(irqs_offset & 0x7));
        ulong ptr = makeisr(isr);
        ubyte[8] ptr_bytes = *cast(ubyte[8]*)&ptr;
        // two low pointer bytes
        idt[irqs_offset++] = ptr_bytes[0];
        idt[irqs_offset++] = ptr_bytes[1];
        // gdt selector
        idt[irqs_offset++] = 0x28;
        idt[irqs_offset++] = 0x00;
        // ist
        idt[irqs_offset++] = 0x00;
        // type
        idt[irqs_offset++] = 0x8e;
        // the rest of the pointer
        idt[irqs_offset++] = ptr_bytes[2];
        idt[irqs_offset++] = ptr_bytes[3];
        idt[irqs_offset++] = ptr_bytes[4];
        idt[irqs_offset++] = ptr_bytes[5];
        idt[irqs_offset++] = ptr_bytes[6];
        idt[irqs_offset++] = ptr_bytes[7];
        // reserved
        idt[irqs_offset++] = 0;
        idt[irqs_offset++] = 0;
        idt[irqs_offset++] = 0;
        idt[irqs_offset++] = 0;
    }
    // eh, doesn't matter
    idtr[0] = 0xff; idtr[1] = 0xff;
    *cast(ubyte**)(&idtr[2]) = idt.ptr;
    ubyte* idtr_raw = idtr.ptr;
    asm {
        mov RAX, idtr_raw;
        lidt [RAX];
        int 3;
    }
}