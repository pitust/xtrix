module xtrm.vfs.kernelfs;

import xtrm.stivale;
import xtrm.vfs.vfscore;

private XT_HANDLE* kernelfs_open(string path, VirtualFSMode mode, out XTHandleFlags flags) {
    assert(false, __FUNCTION__ ~ " is not implemented");
}

private void kernelfs_release_handle(XT_HANDLE* handle) {
    assert(false, __FUNCTION__ ~ " is not implemented");
}

private void kernelfs_read_from_handle(XT_HANDLE* handle, ulong offset, ubyte* buffer, ref long count) {
    assert(false, __FUNCTION__ ~ " is not implemented");
}

private void kernelfs_write_to_handle(XT_HANDLE* handle, ulong offset, ubyte* buffer, ref long count) {
    assert(false, __FUNCTION__ ~ " is not implemented");
}

void init_kernelfs(StivaleStruct* struc) {
    definevfs("kernelfs", VirtualFSHandler(
        &kernelfs_open,
        &kernelfs_release_handle,
        &kernelfs_read_from_handle,
        &kernelfs_write_to_handle
    ));
}
