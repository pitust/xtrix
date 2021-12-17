// srpc encoder
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
module libsrpc.encoder;

import libxtrix.io;
import libxk.list;
import libxk.bytebuffer;

/// encode `value` into a ByteBuffer
ByteBuffer encode(T)(T value) {
	ByteBuffer buf;
	static if (is(T == ubyte)) {
		// ubytes are encoded as-is
		buf << value;
	} else static if (is(T == ulong)) {
		// numbers are memcpy'ed in
		buf.writeRaw(&value, 8);
	} else static if (is(T == uint)) {
		// numbers are memcpy'ed in
		buf.writeRaw(&value, 4);
	} else static if (is(T == string)) {
		// strings are encoded as {uint, chars}
		buf << encode(cast(uint)value.length);
		foreach (c; value) {
			buf << cast(ubyte)c;
		}
	} else static assert(false, "cannot encode type " ~ T.stringof);

	return buf;
}

T decode(T)(ubyte* payload, ulong length, ref ulong offset) {
	static if (is(T == ulong)) {
		assert(offset + 8 <= length, "decode out of bounds");
		ulong res = *cast(ulong*)(payload + offset);
		offset += 8;
		return res;
	} else static if (is(T == uint)) {
		assert(offset + 4 <= length, "decode out of bounds");
		uint res = *cast(uint*)(payload + offset);
		offset += 4;
		return res;
	} else static if (is(T == char)) {
		static assert(T.sizeof == 1);
		assert(offset + 1 <= length, "decode out of bounds");
		char res = *cast(char*)(payload + offset);
		offset += 1;
		return res;
	} else static if (is(T U : List!U)) {
		List!U arr;
		uint len = decode!uint(payload, length, offset);
		arr.reserve(len);

		foreach (i; 0 .. len) {
			arr.append(decode!U(payload, length, offset));
		}
		return arr;
	} else static if (is(T == void)) {
		return;
	} else {
		static assert(false, "Cannot decode " ~ T.stringof);
	}
}
