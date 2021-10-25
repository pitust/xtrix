module libxtrix.libc.asserts;


extern (C) void __assert(char* assertion, char* file, int line) {

    import libxtrix.io : printf;

    printf("Kernel assertion failed: '{}' at {}:{}", assertion, file, line);

    asm {
        cli;
    }
    while (1) {
        asm {
            hlt;
        }
    }
}
