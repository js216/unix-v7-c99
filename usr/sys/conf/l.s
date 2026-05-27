ENTRY(_start)
SECTIONS
{
   . = 0x40000000;

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
