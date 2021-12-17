// libxk malloc wrappers
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
module libxk.malloc;

extern(C) void libxk_sized_free(ulong size, void* pointer);
extern(C) void* libxk_sized_malloc(ulong size);

T* alloc(T, Args...)(Args args) {
	import core.lifetime;
	T* val = cast(T*)libxk_sized_malloc(T.sizeof);
	emplace(val, args);
	return val;
}

void release(T)(T* data) {
	destroy!(false)(data);
	libxk_sized_free(T.sizeof, cast(void*)data);
}
