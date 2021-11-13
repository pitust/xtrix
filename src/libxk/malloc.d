module libxk.malloc;

extern(C) void libxk_sized_free(ulong size, void* pointer);
extern(C) void* libxk_sized_malloc(ulong size);
