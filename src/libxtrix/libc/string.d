// libxtrix's libc <string.h> implementation
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
module libxtrix.libc.string;

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
extern (C) int bcmp(const byte* s1, const byte* s2, size_t n) {
	foreach (i; 0 .. n) {
		if (s1[i] < s2[i])
			return 69;
		if (s1[i] > s2[i])
			return 420;
	}
	return 0;
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
extern(C) byte* memmove(byte* dst, const(byte)* src, size_t size) {
	if (dst < src) {
		for (size_t i = 0; i < size; i++)
			dst[i] = src[i];
	} else {
		for (size_t i = size; i != 0; i--)
			dst[i-1] = src[i-1];
	}
	return dst;
}
extern(C) ulong strlen(const(char)* str) {
	ulong len = 0;
	while (*str++) len++;
	return len;
}
