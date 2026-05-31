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

 /* QEMU has no separate DRAM; .ddrbss is just placed in RAM here, but it is
  * zeroed by the same machine_init() path the MP135 uses (qemu verifies it). */
 .ddrbss : ALIGN(16384) {
    __ddrbss_start = .;
    *(.ddrbss) *(.ddrbss*)
    __ddrbss_end = .;
 }

 .stack : {
    *(.stack)
 }
}
