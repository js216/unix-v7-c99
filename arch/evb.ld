/*
 * STM32MP135 EVB linker script.
 * The bench bootloader's `two` command loads the kernel image into
 * DDR at 0xC0000000, then `jump` enters at the ELF entry point.
 * Keep the layout otherwise identical to arch/a7.ld so qemu and
 * EVB builds share the same arch/sys C code unchanged.
 */
ENTRY(_start)
SECTIONS
{
   . = 0xC0000000;     /* STM32MP135 DDR load address */

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
