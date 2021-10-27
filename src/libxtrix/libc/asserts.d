module libxtrix.libc.asserts;


extern (C) void __assert(char* assertion, char* file, int line) {

    import libxtrix.io : printf;
	import libxtrix.syscall;

	printf("Kernel assertion failed: '{}' at {}:{}", assertion, file, line);

    while (1) {
        asm {
            rep; nop;
        }
    }
}
