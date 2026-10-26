MEMORY
{
	RAM (rwx) : ORIGIN = 0xc0000000, LENGTH = 0x4000000
}
u = 0xFFE00000;
ENTRY(start)
start = _start - 0x80000000;
SECTIONS
{
	.text : AT(ADDR(.text) - 0x80000000) { *(.text*) } > RAM
	.rodata : AT(ADDR(.rodata) - 0x80000000) { *(.rodata*) } > RAM
	.data : AT(ADDR(.data) - 0x80000000) { *(.data*) } > RAM
	. = ALIGN(4);
	__bss_start = .;
	.bss : AT(ADDR(.bss) - 0x80000000) {
		*(.bss*)
		*(COMMON)
	} > RAM
	__bss_end = .;
	.ddrbss (NOLOAD) : ALIGN(4096) {
		__ddrbss_start = .;
		*(.ddrbss*)
		__ddrbss_end = .;
	} > RAM
}
