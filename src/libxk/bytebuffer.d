// A buffer of bytes for xtrix
// Copyright (C) 2021 pitust <piotr@stelmaszek.com>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
