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
	. = 0x0000000000200000;

	.text : ALIGN(4096) {
		*(.text*)
	} :text

	.rodata : ALIGN(4096) {
		*(.rodata*)
	} :rodata

	.data : ALIGN(4096) {
		*(.data*)
	} :data

	.bss : ALIGN(4096) {
		*(COMMON)
		*(.bss*)
	} :data
}
