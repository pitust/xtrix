// libxk mem{cpy,set,cmp} declarations
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
module libxk.cstring;

extern (C) byte* memcpy(byte* dst, const byte* src, size_t n);
extern (C) byte* memset(byte* mem, int data, size_t len);
extern (C) int memcmp(const byte* s1, const byte* s2, size_t n);
