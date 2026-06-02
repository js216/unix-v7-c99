ENTRY(_start)
SECTIONS
{
	. = 0x10;
	.text : { *(.text*) }
	.rodata : { *(.rodata*) }
	.data : { *(.data*) }
	.bss : { *(.bss*) *(COMMON) }
	end = .;
}
