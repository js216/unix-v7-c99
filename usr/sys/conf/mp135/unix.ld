MEMORY
{
	RAM (rwx) : ORIGIN = 0xc01e0000, LENGTH = 0x20000
	TAB (rwx) : ORIGIN = 0xc0200000, LENGTH = 0x20000000
}
u = 0xFFE00000;
ENTRY(start)
start = _start - 0x90200000;
SECTIONS
{
	.text : AT(ADDR(.text) - 0x90200000) { *(.text*) } > RAM
	.rodata : AT(ADDR(.rodata) - 0x90200000) { *(.rodata*) } > RAM
	.data : AT(ADDR(.data) - 0x90200000) { *(.data*) } > RAM
	. = ALIGN(4);
	__bss_start = .;
	.bss : AT(ADDR(.bss) - 0x90200000) {
		*(EXCLUDE_FILE(*/c.o) .bss*)
		*(EXCLUDE_FILE(*/c.o) COMMON)
	} > RAM
	__bss_end = .;
	.ddrbss (NOLOAD) : ALIGN(4096) {
		__ddrbss_start = .;
		*(.ddrbss*)
		*/c.o(.bss* COMMON)
		__ddrbss_end = .;
	} > TAB
}
