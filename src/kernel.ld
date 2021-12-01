/* Tell the linker that we want an x86_64 ELF64 output file */
OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)

ENTRY(_start)

PHDRS
{
	text    PT_LOAD    FLAGS((1 << 0) | (1 << 2)) ;
	rodata  PT_LOAD    FLAGS((1 << 2)) ;
	data    PT_LOAD    FLAGS((1 << 1) | (1 << 2)) ;
}

SECTIONS
{
	. = 0xffffffff80200000;

	.text : {
		*(.text*)
	} :text

	. += 0x1000;

	.stivalehdr : {
		KEEP(*(.stivalehdr))
	} :rodata

	. += 0x1000;

	.rodata : {
		*(.rodata*)
	} :rodata

	. += 0x1000;

	.data : {
		*(.data*)
	} :data

	.bss : {
		*(COMMON)
		*(.bss*)
	} :data
}
