module xtrm.support;

extern (C) byte* memset(byte* mem, int data, size_t len) {
    for (size_t i = 0; i < len; i++)
        mem[i] = cast(byte) data;
    return mem;
}
extern (C) int memcmp(const byte* s1, const byte* s2, size_t n) {
    foreach (i; 0 .. n) {
        if (s1[i] < s2[i])
            return -1;
        if (s1[i] > s2[i])
            return 1;
    }
    return 0;
}
extern(C) bool strisequal(const(char)* left, const(char)* right) {
    while (*left && *right && *left == *right) { left++; right++; }
    return *left == *right;
}