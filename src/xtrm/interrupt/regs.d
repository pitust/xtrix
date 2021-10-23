module xtrm.interrupt.regs;

extern (C) struct Regs {
    ulong r15;
    ulong r14;
    ulong r13;
    ulong r12;
    ulong r11;
    ulong r10;
    ulong r9;
    ulong r8;
    ulong rdi;
    ulong rsi;
    ulong rdx;
    ulong rcx;
    ulong rbx;
    ulong rax;
    ulong rbp;

    ulong isr;
    ulong error;
    ulong rip;
    ulong cs;
    ulong flags;
    ulong rsp;
    ulong ss;
}
