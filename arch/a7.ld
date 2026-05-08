ENTRY(_start)
SECTIONS
{
   . = 0x40000000;     /* QEMU -kernel load address */

   .text : {
      *(.text)        /* Include all code sections */
 }

 .data : { *(.data) }

 __bss_start = .;
 .bss  : { *(.bss)  }
 __bss_end = .;

 .stack : {
    *(.stack)       /* Include our stack reservation */
 }
}
