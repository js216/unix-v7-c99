MEMORY
{
	RAM (rwx) : ORIGIN = 0xc0000000, LENGTH = 0x28000
}
u = 0xFFE00000;
ENTRY(start)
start = _start - 0x90020000;
SECTIONS
{
	.text : AT(ADDR(.text) - 0x90020000) { *(.text*) } > RAM
	.rodata : AT(ADDR(.rodata) - 0x90020000) { *(.rodata*) } > RAM
	.data : AT(ADDR(.data) - 0x90020000) { *(.data*) } > RAM
	. = ALIGN(4);
	__bss_start = .;
	.bss : AT(ADDR(.bss) - 0x90020000) {
		*(.bss*)
		*(COMMON)
	} > RAM
	__bss_end = .;
}
ASSERT(__bss_end <= _start + 0x200000, "the kernel must lie in one block")
