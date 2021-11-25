module libxk.hashmap;

import libxk.malloc;
import libxk.cstring;
import core.lifetime;

private ulong mmhash_mix(ulong value) {
    value ^= value >> 33;
    value *= 0xFF51AFD7ED558CCD;
    value ^= value >> 33;
    value *= 0xC4CEB9FE1A85EC53;
    value ^= value >> 33;
    return value;
}

struct HashMap(K, V) {
    Item root;

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
