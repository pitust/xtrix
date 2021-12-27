// libxk hash prefix tree
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
module libxk.hashmap;

import libxk.malloc;
import libxk.cstring;
import core.lifetime;

private ulong mmhash_mix(ulong value) {
	// i think this doesn't help memory usage that much lmao

	// value ^= value >> 33;
	// value *= 0xFF51AFD7ED558CCD;
	// value ^= value >> 33;
	// value *= 0xC4CEB9FE1A85EC53;
	// value ^= value >> 33;
	return value;
}

struct HashMap(K, V) {
	Item root;

	this(ref HashMap!(K,V) r) { assert(false, "hashmaps are not copyable (yet)!"); }

	struct ChainItem {
		K key;
		V value;
		bool hasInitializedValue;
		ChainItem* next;
	}

	struct Item {
		union {
			ChainItem* ci;
			Item*[16] left;
		}
	}

	private ChainItem* getItemForK(const ref K k, bool init) {
		ulong index = mmhash_mix(hashOf(k));
		ulong shift = 0;
		Item* cur = &root;
		while (shift < 64) {
			ulong ii = index & 0x0f;
			index >>= 4;
			shift += 4;

			if (!cur.left[ii]) {
				cur.left[ii] = cast(Item*) libxk_sized_malloc(Item.sizeof);
				memset(cast(byte*) cur.left[ii], 0, Item.sizeof);
			}
			cur = cur.left[ii];
		}
		ChainItem* cit = cur.ci;
		ChainItem** citp = &cur.ci;
		while (cit) {
			if (cit.key == k)
				return cit;
			citp = &cit.next;
			cit = cit.next;
		}
		if (!init)
			return null;
		cit = *citp = cast(ChainItem*) libxk_sized_malloc(ChainItem.sizeof);
		memset(cast(byte*) cit, 0, ChainItem.sizeof);
		cit.key = k;
		return cit;
	}
	void del(K k) {
		ulong index = mmhash_mix(hashOf(k));
		ulong shift = 0;
		Item* cur = &root;
		while (shift < 64) {
			ulong ii = index & 0x0f;
			index >>= 4;
			shift += 4;

			if (!cur.left[ii]) {
				cur.left[ii] = cast(Item*) libxk_sized_malloc(Item.sizeof);
				memset(cast(byte*) cur.left[ii], 0, Item.sizeof);
			}
			cur = cur.left[ii];
		}
		ChainItem* cit = cur.ci;
		cur.ci = null;
		ChainItem* clist = cit;
		while (clist) {
			this[cit.key] = clist.value;
			clist = clist.next;
		}
		clist = cit;
		while (clist) {
			ChainItem* next = clist.next;
			release(clist);
			clist = next;
		}
	}

	ref V opIndex(K index) {
		ChainItem* ci = getItemForK(index, false);
		assert(ci, "key does not exist in this hashmap!");
		return ci.value;
	}

	auto opIndexAssign(T)(T valueUncast, K index) {
		ChainItem* ci = getItemForK(index, true);
		if (ci.hasInitializedValue)
			ci.value = valueUncast;
		else
			emplace(&ci.value, valueUncast);
		ci.hasInitializedValue = true;

		return valueUncast;
	}

	auto opBinaryRight(string op, L)(const L lhs) {
		static if (op == "in") {
			static assert(is(L == K),
				"Cannot have key of type " ~ L.stringof ~ " in hashmap " ~ K.stringof ~ " =>" ~ V.stringof);
			ChainItem* ci = getItemForK(lhs, false);
			return ci != null;
		} else
			static assert(0, "Operator " ~ op ~ " not implemented");
	}
}