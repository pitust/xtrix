module xtrm.support;

/// memcpy - copy memory area
///
/// The  memcpy() function copies n bytes from memory area src to memory area dest.
/// The memory areas must not overlap. Use memmove(3) if the memory
/// areas do overlap.
///
/// The memcpy() function returns a pointer to dest.
extern (C) byte* memcpy(byte* dst, const byte* src, size_t n) {
    size_t i = 0;
    while (i + 8 <= n) {
        *(cast(ulong*)(&dst[i])) = *(cast(ulong*)(&src[i]));
        i += 8;
    }
    while (i + 4 <= n) {
        *(cast(uint*)(&dst[i])) = *(cast(uint*)(&src[i]));
        i += 4;
    }
    while (i + 2 <= n) {
        *(cast(ushort*)(&dst[i])) = *(cast(ushort*)(&src[i]));
        i += 2;
    }
    while (i + 1 <= n) {
        *(cast(byte*)(&dst[i])) = *(cast(byte*)(&src[i]));
        i += 1;
    }
    return dst;
}
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
