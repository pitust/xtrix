// TSS manager
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
module xtrm.cpu.tss;

private __gshared ubyte[0x6b] tss;

void set_rsp0(ulong rsp0) {
	*cast(ulong*)&tss[4] = rsp0 + 0x4000;
}

ulong tss_init() {
	tss[0x66] = 13;

	return cast(ulong)tss.ptr;
}
