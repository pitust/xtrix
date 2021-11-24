module xtrm.user.elf;

import xtrm.io;
import xtrm.util;
import xtrm.obj.vm;
import xtrm.obj.memory;

ulong load_elf(VM* vm, ulong addr, ulong len) {
    ubyte[] data = ArrayRepr!(ubyte).from(cast(ubyte*)virt(addr), len).into();

    enum off_e_entry = 24;
    enum off_e_phoff = off_e_entry + 8;
    enum off_e_phentsize = off_e_phoff + 8 + 8 + 4 + 2;
    enum off_e_phnum = off_e_phentsize + 2;

    enum off_p_type = 0;
    enum off_p_offset = 8;
    enum off_p_vaddr = off_p_offset + 8;
    enum off_p_filesz = off_p_vaddr + 16;
    enum off_p_memsz = off_p_filesz + 8;

    ulong e_entry = *cast(ulong*)&data[off_e_entry];
    ushort e_phnum = *cast(ushort*)&data[off_e_phnum];
    ushort e_phentsize = *cast(ushort*)&data[off_e_phentsize];
    ulong e_phoff = *cast(ulong*)&data[off_e_phoff];

    foreach (phdr; 0 .. e_phnum) {
        ulong curphoff = e_phoff + e_phentsize * phdr;

        uint p_type = *cast(uint*)&data[curphoff + off_p_type];
        ulong p_offset = *cast(ulong*)&data[curphoff + off_p_offset];
        ulong p_vaddr = *cast(ulong*)&data[curphoff + off_p_vaddr];
        ulong p_filesz = *cast(ulong*)&data[curphoff + off_p_filesz];
        ulong p_memsz = *cast(ulong*)&data[curphoff + off_p_memsz];

        if (p_type != 1) continue;
        Memory* mm = Memory.allocate(p_memsz);
        mm.write(0, ArrayRepr!(ubyte).from(&data[p_offset], p_filesz).into());

        vm.map(p_vaddr, mm);
    }

    return e_entry;
}
