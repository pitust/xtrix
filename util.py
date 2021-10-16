import lldb

def run_cmd(cmd: str) -> str:
    r = lldb.SBCommandReturnObject()
    lldb.debugger.GetCommandInterpreter().HandleCommand(cmd, r)
    return r.GetOutput()

def run_monitor(cmd: str) -> str:
    return run_cmd('process plugin packet monitor ' + cmd)

def read_phys(addr: int) -> int:
    return eval(run_monitor('xp/1gx ' + hex(addr)).split('\r\n')[0].split(': ')[1])

def expand_cmd(cmd: str) -> int:
    return eval(run_cmd('p/x ' + cmd).split(' = ')[1].strip())

def read_reg(reg: str) -> int:
    return eval(run_cmd('re r ' + reg).split(' = ')[1].strip())

def pte_flagdump(f: int) -> str:
    fl = []
    if f & 1:
        fl.append('PRESENT')
    if f & 2:
        fl.append('WRITE')
    if f & 4:
        fl.append('USER')
    if f & 8:
        fl.append('WRITE_THROUGH')
    if f & 16:
        fl.append('NO_CACHE')
    if f & 32:
        fl.append('ACCESSED')
    if f & 64:
        fl.append('DIRTY')
    if f & 128:
        fl.append('HUGE')
    if f & 256:
        fl.append('GLOBAL')
    if f & (1 << 64):
        fl.append('NX')

    return ' '.join(fl)

def pwalk(vtarget: int):
    print(' === page table walk for', hex(vtarget), '===')
    vtarget <<= (64 - 48)
    cr3 = read_reg('cr3')
    for _ in range(0, 4):
        ptindex = (vtarget >> (64 - 9)) & 0x1ff
        pte = read_phys(cr3 + (ptindex << 3))
        vtarget <<= 9
        print('Page table entry:', hex(pte))
        print('  Physical:', hex(pte & 0xffff_ffff_ffff_f000))
        print('  Flags:', pte_flagdump(pte & 0xfff))
        print('  Page table index:', hex(ptindex))
        print()
        if pte == 0:
            return
        if pte & 0x80:
            return
        cr3 = pte & 0xffff_ffff_ffff_f000
    

def plookup(va: int) -> int:
    va <<= (64 - 48)
    cr3 = read_reg('cr3')
    for i in range(0, 4):
        ptindex = (va >> (64 - 9)) & 0x1ff
        pte = read_phys(cr3 + (ptindex << 3))
        va <<= 9
        if pte == 0:
            return
        if pte & 0x80:
            return
        if i == 3 and cr3 == 0:
            return None
        cr3 = pte & 0xffff_ffff_ffff_f000
    return cr3
    
def pwalk_cmd(debugger, command, result, internal_dict):
    pwalk(expand_cmd(command))