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

struct ChildRecord {
	Thread* thr;
	ChildRecord* next;
}

struct KMessage {
	ulong srcpid, rid, len;
}

struct Thread {
	Obj obj = Obj(ObjType.thr); alias obj this;
	Regs regs;
	VM* vm;
	ulong[4] rsp0_phy;
	ulong rsp0_virt, sleepgen, pid, uid, ppid;
	ulong is_wfor, waitpid, waitcode, suicide;
	bool can_rx;
	uint clients;
	KMessage* rxmsg;
	void*[4] rx_arena;
	char[3742] tag;
}
