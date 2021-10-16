module xtrm.asserts;

extern (C) void __assert(char* assertion, char* file, int line) {

    import xtrm.io : printk;

    printk("Kernel assertion failed: '{}' at {}:{}", assertion, file, line);

    asm {
        cli;
    }
    while (1) {
        asm {
            hlt;
        }
    }
}
