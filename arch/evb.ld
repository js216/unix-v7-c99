/*
 * STM32MP135 EVB linker script.
 * The bench bootloader's `two` command default loads the kernel
 * image from SD block 896 into DDR at 0xC2000000 and `jump` then
 * enters at that same address; the unix kernel must be linked
 * for that VA.  Layout otherwise mirrors arch/a7.ld so qemu and
 * EVB builds share the same arch/sys C code unchanged.
 */
ENTRY(_start)
SECTIONS
{
   . = 0xC2000000;     /* STM32MP135 `two` default kernel load addr */

   .text : {
      *(.text)
   }

   .data : { *(.data) }

   __bss_start = .;
   .bss  : { *(.bss)  }
   __bss_end = .;

   .stack : {
      *(.stack)
   }
}
