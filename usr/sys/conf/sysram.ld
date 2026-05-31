/*
 * MP135 kernel link map.  The STM32MP13 ROM loads this image into SYSRAM
 * (0x2FFE0000, 128 KB) from the SD card and jumps to _start; clocks and DDR
 * are dead until machine_init() brings them up, so the kernel code, data, and
 * SYSRAM bss + stacks live in SYSRAM.  DDR (0xC0000000, 512 MB) holds the
 * large system tables and the L1 page table (.ddrbss, too big for SYSRAM,
 * zeroed by machine_init once DRAM is up) plus the buffer cache and user core.
 */
ENTRY(_start)
MEMORY {
	SYSRAM (rwx) : ORIGIN = 0x2FFE0000, LENGTH = 128K
	DDR    (rwx) : ORIGIN = 0xC0000000, LENGTH = 512M
}
SECTIONS
{
	. = 0x2FFE0000;

	.text : { *(.text) *(.text*) } > SYSRAM

	.rodata : { *(.rodata) *(.rodata*) } > SYSRAM

	.data : { *(.data) *(.data*) } > SYSRAM

	__bss_start = .;
	.bss : { *(.bss) *(.bss*) *(COMMON) } > SYSRAM
	__bss_end = .;

	.stack : { *(.stack) } > SYSRAM

	.ddrbss (NOLOAD) : ALIGN(16384) {
		__ddrbss_start = .;
		*(.ddrbss) *(.ddrbss*)
		__ddrbss_end = .;
	} > DDR
}
