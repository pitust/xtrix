import sys, os, subprocess

# guesstrace - guess stack traces (macOS only, really damn cool)

proc = subprocess.Popen('pbpaste',
    shell=True,
    stdout=subprocess.PIPE,
    bufsize=-1)

clip = proc.stdout.read().decode().strip().splitlines()
proc.kill()
clist = []

def try_bt(p):
    if 0xfffffffffff00000 & p == 0x0000000000200000:
        print('got code ptr:', hex(p - 1))
        clist.append(hex(p - (1 if len(clist) else 0)))

for line in clip:
    g1, g2 = line.split('      ')
    g1 = g1.split(' ')[-1]
    g1p = int(g1, 16)
    g2p = int(g2, 16)
    try_bt(g1p)
    try_bt(g2p)

proc = subprocess.Popen(
    'x86_64-elf-addr2line -p -e ' + sys.argv[1] + ' ' + ' '.join(clist) + ' | grep -v \'??:0\'',
    shell=True,
    stdout=subprocess.PIPE,
    bufsize=-1)

bt = proc.stdout.read().decode().strip().splitlines()
proc.kill()
if len(sys.argv) == 3 and sys.argv[2] == 'srht':
    bt = [
        entry
        for entry in bt
    ]
print('\n'.join(bt))
