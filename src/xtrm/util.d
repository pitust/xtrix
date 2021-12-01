// low-level d array and general OS programming utilties
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
module xtrm.util;

struct ArrayRepr(T) {
	ulong len;
	T* ptr;
	static ArrayRepr!(T) from(T[] arr) {
		return *cast(ArrayRepr!(T)*)(&arr);
	}
	static ArrayRepr!(T) from(T* data, ulong count) {
		return ArrayRepr!(T)(count, data);
	}
	T[] into() {
		return *cast(T[]*)(&this);
	}
}

enum PAGING_BASE = 0xffff800000000000;
enum NEGATIVE_2GB = 0xffffffff80000000;

T phys(T)(T t) {
	ulong u = cast(ulong)t;
	if (u > NEGATIVE_2GB) u -= NEGATIVE_2GB;
	if (u > PAGING_BASE) u -= PAGING_BASE;
	return cast(T)(u);
}

T virt(T)(T t) {
	ulong u = cast(ulong)t;
	if (u > NEGATIVE_2GB) u -= NEGATIVE_2GB;
	if (u > PAGING_BASE) u -= PAGING_BASE;
	return cast(T)(u + PAGING_BASE);
}
