module libxk.bytebuffer;

import libxk.malloc;
import libxk.cstring;
import std.algorithm;
import libxtrix.libc.malloc;

struct ByteBuffer {
	ulong* rc = null;
	ubyte* data = null;
	ulong size = 0, capacity = 0;
	
	void ensure() {
		if (rc) return;
		rc = alloc!ulong;
		*rc = 1;
	}
	this(ref ByteBuffer rhs) {
		rhs.ensure();
		rc = rhs.rc;
		(*rc)++;
	}
	~this() {
		ensure();
		if ((*rc)-- == 1) release(rc);
	}

	ref ubyte opIndex(ulong index) {
		ensure();
		assert(false, "todo");
	}

	ubyte opIndexAssign(ubyte valueUncast, ulong index) {
		ensure();
		assert(false, "todo");
	}

	ref opBinary(string op, R)(const R rhs) {
		static assert(op == "<<");
		ensure();

		static if (is(R == ByteBuffer)) {
			_ensure(size + rhs.size);
			memcpy(cast(byte*)data + size, cast(byte*)rhs.data, rhs.size);
			size += rhs.size;
		} else static if (is(R == ubyte)) {
			_ensure(size + 1);
			data[size++] = rhs;
		} else static assert(false, "Cannot add type " ~ R.stringof ~ " to a ByteBuffer");

		return this;
	}

	void writeRaw(void* dvalue, ulong count) {
		ensure();
		_ensure(size + count);
		memcpy(cast(byte*)data + size, cast(byte*)dvalue, count);
		size += count;
	}

	void _ensure(ulong needscap) {
		if (capacity < needscap) {
			void* ndata = malloc(max(needscap, capacity * 2 + 1));
			memcpy(cast(byte*)ndata, cast(byte*)data, size);
			capacity = needscap;
			void* oldata = data;
			data = cast(ubyte*)ndata;
			if (oldata) libc_free(oldata);
		}
	}
}
