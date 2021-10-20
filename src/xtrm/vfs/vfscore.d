module xtrm.vfs.vfscore;

import xtrm.stivale;
import xtrm.memory;
import xtrm.io;

enum XTHandleFlags {
    NONE = 0,
    NOSEEK = 1,
    INVALID = 2,
}

struct XT_HANDLE {
    private ulong* rc = null;
    private VirtualFSHandler* handler = null;
    private ulong offset = 0;
    bool valid = true;
    private void* _data;
    private XTHandleFlags _flags;

    void release() {
        _before_use();
        handler.release_handle(&this);
        this.handler = null;
        this.valid = false;
    }

    this(VirtualFSHandler* fs_handler, string path, VirtualFSMode mode = VirtualFSMode.OPEN) {
        this.handler = fs_handler;
        this.offset = 0;
        _flags = XTHandleFlags.INVALID;
        this._data = fs_handler.open(path, mode, _flags);
        assert(fs_handler != null);
        rc = aquad();
        *rc = 1;
    }
    this(ref XT_HANDLE h) {
        this.rc = h.rc;
        this.valid = h.valid;
        this._data = h._data;
        this._flags = h._flags;
        *rc += 1;
    }
    ~this() {
        *rc -= 1;
        if (*rc == 0) {
            release();
            fquad(this.rc);
        }
    }
    private void _before_use() {
        assert(this.valid);
        assert(/* sanity */ *this.rc < 0x100000);
    }

    void* data() {
        _before_use();
        return _data;
    }
    XTHandleFlags flags() {
        _before_use();
        return _flags;
    }
    long read(ubyte* buffer, ulong count) {
        _before_use();
        assert(count < 0xFF_FF_FF_FF);

        long countm = count;
        handler.read_from_handle(&this, offset, buffer, countm);
        if (countm < 0) return countm;
        offset += countm;
        return countm;
    }
    long write(ubyte* buffer, ulong count) {
        _before_use();
        assert(count < 0xFF_FF_FF_FF);

        long countm = count;
        handler.write_to_handle(&this, offset, buffer, countm);
        if (countm < 0) return countm;
        offset += countm;
        return countm;
    }
}

enum VirtualFSMode {
    OPEN,
    CREATE,
    CREATEDIR,
}

struct VirtualFSHandler {
    XT_HANDLE* function(string path, VirtualFSMode mode, out XTHandleFlags flags) open;
    void function(XT_HANDLE* handle) release_handle;
    void function(XT_HANDLE* handle, ulong offset, ubyte* buffer, ref long count) read_from_handle;
    void function(XT_HANDLE* handle, ulong offset, ubyte* buffer, ref long count) write_to_handle;
}

private struct VFSListHashTableBucket {
    VFSListHashTableBucket* next;
    string nodeName;
    VirtualFSHandler entry;
}

private struct VFSListHashTable {
    VFSListHashTableBucket*[256] buckets;
}

private __gshared VFSListHashTable vfslist;

private ubyte hash(string s) {
    uint h = 0, g;
    foreach (c; s) {
        h = (h << 4) + cast(uint) c;
        g = h & 0xf0000000;
        if (g)
            h ^= g >> 24;
        h &= ~g;
    }
    return (cast(ubyte) h) & 0xff;
}

void init_vfscore(StivaleStruct* struc) {
    // no init for now
}

void definevfs(string path, VirtualFSHandler handle) {
    ubyte h = hash(path);
    VFSListHashTableBucket* obu = vfslist.buckets[h];
    VFSListHashTableBucket* nbu = alloc!(VFSListHashTableBucket)();
    nbu.nodeName = path;
    nbu.next = obu;
    nbu.entry = handle;
}
ref VirtualFSHandler getvfs(string path) {
    VFSListHashTableBucket* bucket = vfslist.buckets[h];
    while (bucket) {
        if (bucket.nodeName == path) return bucket.entry;

        bucket = bucket.next;
    }
}