// xtrix thread objects
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
module xtrm.obj.thread;

import xtrm.memory;
import xtrm.obj.obj;
import xtrm.obj.vm;
import xtrm.interrupt.regs;

struct Thread {
    Obj obj = Obj(ObjType.thr); alias obj this;
    Regs regs;
    VM* vm;
    Obj*[512]* handles;
    ubyte[4096]* rsp0;
	ulong sleepgen;
    char[3872] tag;
	long allocateHandle() {
        assert(handles);
        foreach (i; 0 .. 512) {
            if ((*handles)[i]) continue;
            return i;
        }
        return -1;
    }
}
