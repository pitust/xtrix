module libxk.cstring;

extern (C) byte* memcpy(byte* dst, const byte* src, size_t n);
extern (C) byte* memset(byte* mem, int data, size_t len);
extern (C) int memcmp(const byte* s1, const byte* s2, size_t n);
