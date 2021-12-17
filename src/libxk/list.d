// libxk list container
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
module libxk.list;

import std.typecons;
import libxk.malloc;
import libxk.cstring;
import std.algorithm;

struct List(T) {
	ulong length = 0;
	ulong capacity = 0;
	RefCounted!(T*, RefCountedAutoInitialize.yes) payload;

	void reserve(ulong needed_cap) {
		if (capacity < needed_cap) {
			ulong need_to_get = max(capacity * 2, needed_cap);
			T* data = payload.refCountedPayload();
			T* newdata = cast(T*)libxk_sized_malloc(need_to_get * T.sizeof);

			memcpy(cast(byte*)newdata, cast(byte*)data, length * T.sizeof);
			
			if (data) libxk_sized_free(capacity * T.sizeof, data);
			payload.refCountedPayload = newdata;
		}
	}
	void append(ref T value) {
		reserve(length + 1);
		payload.refCountedPayload[length++] = value;
	}
	void append(T value) {
		reserve(length + 1);
		payload.refCountedPayload[length++] = value;
	}
	T[] to_slice() {
		struct A { ulong len; T* dat; }
		A a = A(length, payload.refCountedPayload());
		return *cast(T[]*)&a;
	}
}
