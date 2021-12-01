module libxk.malloc;

extern(C) void libxk_sized_free(ulong size, void* pointer);
extern(C) void* libxk_sized_malloc(ulong size);

T* alloc(T, Args...)(Args args) {
	import core.lifetime;
	T* val = cast(T*)libxk_sized_malloc(T.sizeof);
	emplace(val, args);
	return val;
}

void free(T)(T* data) {
	destroy!(false)(data);
	libxk_sized_free(T.sizeof, cast(void*)data);
}
alias release = free;
