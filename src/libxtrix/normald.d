module libxtrix.normald;

import libxtrix.libc.string;
import libxtrix.libc.malloc;

private alias extern(C) int function(char[][] args) MainFunc;

private extern (C) __gshared void* _Dmodule_ref = null;
extern (C) int _d_run_main(int argc, char** argv, MainFunc mainFunc) {
    char[][] args = (cast(char[]*)malloc(argc * 16))[0 .. argc];
    foreach (i; 0 .. argc) {
        args[i] = argv[i][0 .. strlen(argv[i])];
    }
    return mainFunc(args);
}

private extern(C) void do_exit(ulong code);
extern(C) void _d_arraybounds_index(string file, uint line, size_t index, size_t length) {
	import libxtrix.io : printf;

	printf("Array access out of bounds at index {}, while only {} items are present! {}:{}", index, length, file, line);

	do_exit(255);
}
extern(C) void _d_assert_msg(string msg, string file, uint line) {
    import libxtrix.io : printf;

	printf("Assertion failed: {}! {}:{}", msg, file, line);

	do_exit(255);
}
extern(C) void _d_assert(string file, uint line) {
    import libxtrix.io : printf;

	printf("Assertion failed at {}:{}!", file, line);

	do_exit(255);
}

pragma(mangle, "_d_eh_personality")
private extern(C) void d_eh_personality() { assert(0, "_d_eh_personality called!"); }

pragma(mangle, "_Unwind_Resume")
private extern(C) void Unwind_Resume() { assert(0, "_Unwind_Resume called!"); }
