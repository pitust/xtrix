def remap(name):
	if name[0:2] != '_D':
		return name
	str = []
	name = name[2:]
	while True:
		while name[0].isdigit():
			i = ''
			while name[0].isdigit():
				i += name[0]
				name = name[1:]
			i = int(i)
			str.append(name[:i])
			name = name[i:]
		if name[0:3] == '__T':
			name = name[3:]
			continue
		break
	return '.'.join(str)

for fn in bv.functions: fn.name = remap(fn.name)
for symname in bv.symbols:
	for sym in bv.symbols[symname]:
		if sym.type == SymbolType.DataSymbol and symname[0:2] == '_D':
			bv.define_user_symbol(Symbol(SymbolType.DataSymbol, sym.address, remap(sym.name)))
