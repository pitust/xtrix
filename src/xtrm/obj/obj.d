// xtrix object core and type list
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
module xtrm.obj.obj;

import xtrm.io;
import xtrm.memory;

enum ObjType {
    nullobj,
    mem,
    memref,
    vm,
    thr,
    chan,
    cred,
    credproof,
    credverity,
	responder,
}

struct Obj {
    ObjType type;
    ulong rc = 0;
}
private __gshared Obj _nullobj = Obj(ObjType.nullobj, 999999999);

// lifetime(return value): the return value is owned by the kernel as a whole, and needs not be refcounted
Obj* getnull() {
    return &_nullobj;
}
