#import "defs.typ": *

== Startup and Processes <ch-startup>

The system described here runs on two machines, and the book names them
throughout as follows.

*The QEMU machine* is the `virt` machine of the QEMU emulator (version
10.0), configured with a single ARM Cortex-A7 processor and, by the `-m 512M`
option which `make qemu` (#f("Makefile")) gives it, 512 MB of memory at
address 0x40000000, an ARM Generic Interrupt Controller (GIC) version
2 at 0x08000000, the ARM generic timer, an ARM PL011 UART (a serial line
interface) at 0x09000000 as the console, and, as the disk, a virtio
block device (virtio being an interface which QEMU offers in place of
real hardware), found among the virtio "MMIO" slots at 0x0a000000. QEMU loads the kernel into
memory itself and starts it at its entry point; the disk is a file on
the host, made by `mkfs` from the prototype `boot/rootfs.proto`.

*The MP135 machine* is STMicroelectronics' STM32MP135F-DK, a small
board built around the company's STM32MP135F system-on-chip. The chip
contains one ARM Cortex-A7 processor running at up to 1 GHz, 128 KB of
on-chip memory (SYSRAM) at 0x2ffe0000, and the controllers below; the
board adds 512 MB of DDR3L memory, at 0xc0000000, and an SD card slot. The console is the chip's UART4 at
0x40010000, the disk is the SD card on its SDMMC1 controller at
0x58005000, and the interrupt controller is again a GIC version 2, at
0xa0021000. The kernel is linked to run in SYSRAM, where the chip's
boot ROM places what it loads from the SD card; the build makes the
kernel and the root file system, but not yet the image, with the
header the ROM requires, nor puts anything where the ROM looks for it.
Once running, the kernel must bring up the DDR memory itself
(#f("stm32ddr.c")) before it can use it.

The Cortex-A7 implements the ARMv7-A architecture: sixteen 32-bit
registers, a status register `CPSR`, separate processor modes for user
programs and for each kind of exception, a memory management unit (MMU)
which maps virtual addresses through page tables in memory, and a
floating point unit, VFPv4 with the Advanced SIMD extension, with 32
double registers, the counterpart of the PDP-11/45's floating point
processor. The
equivalents of the PDP-11's `spl` routines (which set the processor
priority, and so mask interrupts), segmentation registers, and trap
vectors are described where the code uses them: in #f("low.s"),
#f("mch.s"), and #f("machdep.c"). The differences between the machines,
the addresses above in particular, are confined to the configuration
files of @ch-drivers and to the drivers, one set for each machine. Main memory
is called _core_ throughout, as v7 called it after the magnetic core
memories of its day.

The addresses above are physical. Once the MMU is on, a program sees
virtual addresses, and the four gigabytes of them are divided as on the
PDP-11, where each mode had its own: the user's address space is the
lower three gigabytes, from 0 to 0xbfffffff (`USERSIZE`,
#f("param.h")), and the kernel's is the top gigabyte, which user mode
cannot touch. A process's text begins at the bottom, at 0xa0, its data
follows, and its stack ends at 0xc0000000; nothing else is mapped there
(#f("ureg.c")). The kernel's gigabyte is laid out alike on both
machines, by the `map` lines of their configurations (#f("qemuconf"),
#f("mp135conf")):

#table(
  columns: (auto, 1fr, 1fr),
  stroke: none,
  table.header[*Kernel address*][*QEMU machine*][*MP135 machine*],
  [0xc0000000], [memory 0x40000000--0x5fffffff: kernel, then core], [SYSRAM block 0x2fe00000; kernel at 0xc01e0000],
  [0xc0200000], [(memory, continued)], [DDR 0xc0000000--0xdfffffff: tables, then core],
  [0xf0000000], [GIC 0x08000000], [UART4 0x40010000],
  [0xf0200000], [UART 0x09000000], [RCC, PWR, GPIO 0x50000000],
  [0xf0400000], [virtio 0x0a000000], [SDMMC1 0x58005000],
  [0xf0600000], [], [DDR controller 0x5a003000],
  [0xf0800000], [], [GIC 0xa0021000],
  [0xf0a00000], [], [TZC 0x5c006000],
  [0xfff00000], [`u`, the current process's u-area], [`u`, likewise],
)

On the MP135 machine, RCC is the chip's reset and clock controller, PWR
its power controller, GPIO its general purpose pins, SDMMC1 the SD card
controller, and TZC the TrustZone address space controller, which
guards the DDR memory. The u-area at the top is the per process data
area of #f("user.h"): the `user` structure and kernel stack of the
process which is running.

Memory and devices are mapped in blocks of 2 MB, each at a fixed
distance from its physical address; the right-hand columns give the
physical address of each block's contents. The kernel's addresses are
therefore not physical, and three places must convert: the kernel
reaches a click of core (the unit in which core is allocated, a page of
4096 bytes, #f("map.h")) through `CLKADDR` (#f("seg.h")), a driver gives
a device the physical address of a buffer through `vtop`
(#f("machdep.c")), and `/dev/mem` and `/dev/kmem` (#f("mem.c")) take
their offsets as physical and kernel addresses respectively.


#source("/usr/sys/h/map.h")

A resource map is a list of the free areas of some resource. Each
element gives the size of one area and the address of its first unit,
both measured in whatever unit suits the resource. The system keeps
three such lists, for main memory, for the swap area, and for the pool
of user page tables, and all three are managed by the two procedures
of #f("malloc.c"), which do not need to know which resource they are
handling. Main memory and the pool are measured in
_clicks_, the granule in which the memory management unit maps memory,
and in which v7 counts all of core; the swap area is measured in
512-byte disk blocks. On the PDP-11 a click was 64 bytes. Here, as in
UNIX/32V, which kept v7's machinery and made the click the VAX's
512-byte page, a click is the ARM's page of 4096 bytes.

The fields were `short` and `unsigned short` in v7, so that an address
could reach 65536 clicks (four megabytes of core) or as many swap
blocks, and a size half as far. A click number is now the physical
address divided by 4096, as on the PDP-11 it was the address divided
by 64, and the MP135 machine's memory begins at 0xc0000000, click
786432. A size outgrows a `short` as well: 512 MB is 131072 clicks.
Both fields are therefore `int`.
`m_addr` is signed, although an address is never negative, because
`malloc` and `mfree` (#f("malloc.c")) take and return an `int`; no map
is large enough for the sign to matter.

#lines(1, 5)

The maps themselves follow: `coremap` for main memory, `swapmap` for
the swap area, and, new in the port, `ptmap` for the pool of user page
tables (#f("ureg.c")).

In v7 these lines defined storage, not merely declared it, and the
header is included by six files. Each file therefore contained its own
definition of `coremap` and `swapmap`, and the PDP-11 loader merged
such uninitialised definitions into one, as the Unix loaders always
had. C99 allows an object only one external definition, so the lines
now declare the arrays `extern`; the same was done for the variables of
#f("systm.h"). They also no longer give the dimensions, `CMAPSIZ` and
the rest of #f("param.h"): those are computed from `NPROC` and `NTEXT`,
which are now variables, and a declaration of an array at file scope
must have a constant size or none. The maps are defined, with their
sizes, in the configuration (#f("qemu/c.c")).

#lines(6, 9)
#source("/usr/sys/sys/malloc.c")

This file holds the two procedures which manage a resource map
(#f("map.h")): `malloc` takes an area out of the free list and `mfree`
puts one back. They know nothing of the resource itself. The same code
hands out core to processes and to texts (the read-only instructions of
a program, shared by every process running it) in units of 4096-byte clicks
(`swapin`, `newproc`, and `expand` in #f("slp.c"), `xexpand` in
#f("text.c")), swap space in units of 512-byte disk blocks (`xswap`
and `xalloc` in #f("text.c"), and `exece` in #f("sys1.c"), which
borrows swap to hold its argument list), and the user page tables,
also in clicks (`ptbuild` in #f("ureg.c")).
Despite its name, `malloc` has nothing to do with the C library routine
of the same name.

The correctness of both procedures rests on three rules about the list,
which every operation must preserve:

+ The free areas appear in order of increasing address.
+ No two entries describe adjacent areas; two such areas are always
  merged into one entry.
+ The list ends at the first entry with a zero size. This sentinel is
  not itself a free area, and its address field means nothing.

There is a fourth, less evident, rule: every element of the array
beyond the sentinel also has a zero size. The arrays start out zero,
and, as will be seen, the code which shortens the list leaves zeros
behind it. `mfree` depends on this when it lengthens the list.

Neither procedure checks for the end of the array, so the arrays must
be large enough never to overflow. v7 raised `NPROC` to 150 but left
`CMAPSIZ` and `SMAPSIZ` at 50 entries, and so assumed that memory never
became fragmented into fifty pieces; past that, `mfree` would write
beyond the end of the map. A sounder bound is easily had: a map can
hold no more free areas than there are allocated areas between them,
plus one, and it needs one entry more for the sentinel. `CMAPSIZ`,
`SMAPSIZ`, and `PMAPSIZ` (#f("param.h")) are computed from this bound, and the
configuration of each machine gives the maps those sizes
(#f("qemu/c.c")).

#lines(1, 14)

`malloc` uses the "first fit" rule: it takes the first area in the list
which is large enough, and allocates from its low end. The search (21)
stops at the sentinel, whose size is zero.

#lines(15, 22)

The request is carved off the front of the area (23--24); the entry
remains, describing what is left.

If nothing is left (25), the entry must go. Every following
entry, up to and including the sentinel, is moved down one place.
Notice that the loop copies the address before it tests the size, and
that the test is the value of the size just copied, not a comparison.
The loop stops after it has copied the sentinel's zero; the old slot of
the sentinel keeps its own zero, which is the fourth rule above.

v7 wrote the controlling expression with single parentheses. C99 does
not mind, but `gcc` warns of an assignment used as a truth value, and
the port compiles without warnings; the second pair of parentheses
(29) tells the compiler that the assignment is intended. The same
change appears at line 76, and throughout the system.

#lines(23, 30)

The address is returned (31) as an `int`, although `a` is unsigned, as
it was in v7.

Zero (34) means failure. This is safe only because no free area ever
begins at address zero. For core, click numbers are physical page
numbers, and neither machine has memory at address zero; for swap,
`startup` (#f("machdep.c")) frees the map starting at block 1 and
decrements `swplo` (the first block of the swap area on its device) to
compensate, so that block zero of the swap area is never named.

#lines(31, 35)

The comment, v7's, calls the address `aa`, a name the parameter does
not have.

#lines(36, 48)

Freeing core may allow the scheduler to bring in a process
which is waiting on disk. If `sched` (#f("slp.c")) has gone to sleep
for want of core (`runin` set), it is woken at once. Note that the map
has not yet been updated when the wakeup is issued; this is harmless,
since `wakeup` merely makes `sched` runnable, and the kernel is not
preempted, so `sched` cannot look at the map before `mfree` returns.

#lines(49, 52)

The loop with the empty body (53) steps `bp` forward past every area
which begins at or below `a`. At its end, `bp` points to the first area
above the one being returned, or to the sentinel. The new area belongs
just before `bp`.

There are now four cases. If the area being returned begins where the
previous area ends (54--55), the previous entry simply grows.

If it now also reaches the next area (56--62), the two entries become
one: the previous entry absorbs the next, and the rest of the list,
sentinel included, moves down one place. As in `malloc`, the slot
vacated at the end keeps its zero size. If `bp` is the sentinel, its
address is meaningless, and the test at line 56 may succeed by chance;
it then adds a zero size and the loop does not run, so no harm is done.

#lines(53, 63)

Otherwise, if the area being returned ends where the next
area begins, the next entry is extended downwards. The test of
`bp->m_size` prevents a match against the meaningless address of the
sentinel.

#lines(64, 67)

Otherwise a new entry is needed. It is written into `bp`,
and the entry which was there is carried forward, in `a` and `t`, into
the next slot, which in turn gives up its own entry, and so on. When
the entry displaced is the sentinel, the size carried forward is zero
and the loop stops without storing it. The slot after, which is now
the end of the list, needs no zero written into it: by the fourth
rule, it already holds one.

Note that a zero `size` (68) changes nothing; it is tested only in this
last case, since in the others adding zero is harmless.

#lines(68, 79)
#source("/usr/sys/sys/prf.c")

The kernel's means of speaking to the operator. `printf` writes
directly to the console, one character at a time, without buffering
and without interrupts; it is used at startup, for hardware errors, and
for the last words of a dying system. `panic`, `prdev`, and `deverror`
are built on it, and it in turn calls `printn` for numbers and
`putchar` for each character.

In v7 `putchar` belonged to the console driver, and so it does here: it
is defined in #f("pl011.c") for the QEMU machine and in
#f("stm32usart.c") for the MP135 machine, and each machine's kernel
links only its own driver. Either waits,
with a time limit, for the transmitter to have room, writes the
character with the transmitter interrupt masked, and follows a newline
with a carriage return, as v7 did. It also keeps a copy of everything printed in `msgbuf`.

Of the included files, #f("param.h") provides `dev_t` and the macros
`major` and `minor`, #f("systm.h") the declarations of `update`,
`idle`, and `putchar`, and #f("buf.h") the buffer header used by
`deverror`. Nothing here needs #f("seg.h") or #f("conf.h"); v7
included them too.

Two lines are new. `<stdarg.h>` (6) supplies the macros through which
`printf` now finds its arguments; it is one of the headers which C99
requires even of a freestanding implementation, so it is available
although the kernel is built without a C library. `printn` is declared
(7) because `printf` calls it before its definition. A K&R compiler
assumed an undeclared function returned `int`; C99 forbids the call,
and the port's `-Wmissing-prototypes` asks for a prototype ahead of
every external definition. It is declared here rather than in
#f("systm.h") because no other file uses it.

#lines(1, 8)

`panicstr` is set by `panic` and read by nothing in the system. It
exists so that whoever examines memory after a crash can find the
message, even if the console printed nothing.

#lines(9, 15)

The comment promises `%d`, `%u`, `%o`, `%x`, `%s`, and `%D`. There is no
`%c` and no field width. An unrecognised letter after `%` is silently
swallowed, along with its argument, if any; a `%` at the very end of
the format makes `printf` read beyond the terminating null (44), so
the format had better be correct.

The change from v7 is in the way the arguments are found. v7 declared
one argument `x1` after the format and set `adx` to its address. On
the PDP-11 all arguments were pushed onto the stack, the last first,
so that the later arguments lay at successively higher addresses
above `x1`, and `printf` walked through them by incrementing an
integer pointer. A `%D` argument occupied two words; v7 fetched it
through a `long` pointer and stepped `adx` one word further than
usual. Under the ARM procedure call standard the first four words of
arguments are passed in registers `r0` to `r3`, and only the rest on
the stack; the address of a parameter tells nothing about where the
next one is. C99's only defined way to reach unnamed arguments is
`<stdarg.h>`. So the declaration becomes `...` (29), `adx` becomes a
`va_list` (32) started by `va_start` (35), and each conversion fetches
its argument with `va_arg` and the right type (46, 48, 52), which also
advances past it. The extra step for `%D` and the increment at the
bottom of the loop are therefore gone. `va_end` (39) is called before
the return because C99 requires each `va_start` to be matched by one.

`fmt` is no longer `register`: C99 leaves `va_start` undefined when
its last named parameter has that storage class. `register c` (31)
becomes `register int c`, since C99 has no implicit `int`. The doubled parentheses at line 49 are explained in
#f("malloc.c").

The reader may wonder at `%D` (51). On the PDP-11 `int` had 16 bits
and `long` 32, and a block number or a byte count needed `%D`. Here
both have 32 bits, so `%D` and `%d` print the same; it is kept because
the callers use it.

The other numeric conversions fetch their argument as `unsigned` (46).
v7 converted it to `long`, which on the PDP-11 widened 16 bits to 32
and could never produce a negative value; `%d` of $-1$ printed 65535,
which is what the comment means by "`%d` (==`%u`)". Here `unsigned` and
`long` are the same size, and the conversion would turn any value of
$2^31$ or more negative: a kernel address such as `0xc0101234` would
print as `-3FEFEDCC`. The cast is gone and `printn` takes an `unsigned
long`, so the value arrives intact. `%d` of $-1$ prints 4294967295, as
the comment promises.

#lines(16, 55)

`printn` produces the digits of `n` in base `b` by printing the higher
digits, `n/b`, recursively, and then the lowest. The recursion ends
because each call divides by at least 8; a 32-bit number has at most
eleven octal digits.

v7 began with a test for a negative number, which "shouldn't happen"
and on the PDP-11 could not. With v7's conversion it could happen here,
and for $-2^31$ the negation would overflow, the remainder (67) go
negative, and the digit string be indexed out of bounds. With `n`
unsigned, as the comment (58) says, the test could never succeed and is
removed. `%D` of a negative `long` would now print as a large
unsigned number; no caller passes one.

The doubled parentheses at line 65 are again those of #f("malloc.c").

#lines(56, 68)

`panic` is the system's response to a state it cannot repair. It
records the message, writes out what it can, prints, and stops.

First `update` (80, #f("alloc.c")) writes the super-blocks, the modified
inodes, and the delayed-write buffers to disk, so that as little as
possible of the file systems is lost. If the panic arose in the disk
code itself, this may not succeed, and if `update` was already running
when the panic came, its lock `updlock` makes it return at once.

#lines(69, 81)

The system does not halt but idles for ever. `idle`
(#f("mch.s")) was on the PDP-11 a `wait` instruction at processor
priority zero; on ARM it enables interrupts with `cpsie i`, waits for
one with `wfi`, and disables them again. Interrupts therefore continue
to be taken: transfers already under way, including those started by
`update`, complete, and the clock keeps running. The only way out is
to restart the machine.

#lines(82, 84)

`prdev` reports a problem with a device, giving its major and minor
numbers. It is used mainly by the file system code in #f("alloc.c"),
for a full or corrupted file system.

#lines(85, 97)

`deverror` is called by a disk driver whose transfer has failed. The
comment calls it `deverr`, as in v7. The block number is a `daddr_t`,
hence `%D`. The two further words were on the PDP-11 copies of the
controller's error registers, for which octal was the natural form.
The two disk drivers pass a single status value and a zero:
#f("virtio_blk.c") the status byte returned by the virtual device,
#f("stm32sd.c") the status register of the SD controller.

#lines(98, 112)
#source("/usr/sys/h/param.h")

#f("param.h") is the first file which nearly every kernel source file
includes, and most of the other `.h` files assume that it has been
included before them. It reserves no storage, though it declares some
(146, 147), but defines the constants and simple types upon
which the remainder of the system is built. As elsewhere in UNIX,
defined constants are written in upper case only.

The file falls into six parts: the tunable parameters, the priorities,
the signals, the "fundamental constants", some conversion macros and
types, and finally a few machine-dependent definitions.

These are the parameters which an installation may reasonably alter.
Most of them fix the dimensions of tables which are allocated
statically, once and for all, when the system is built: `NBUF` for
the buffer cache, `NINODE` for the in-core inodes, `NFILE` for the open
file table, `NPROC` for the process table, and so on. Doubling `NPROC`
costs space in every system, whether the processes exist or not.

In v7 they were numbers, and one `param.h` served one installation. The
two machines here are built together, from one copy of the kernel's
sources, and each configuration gives them its own values
(#f("qemuconf")), generous, since both have 512 MB. `NBUF`, `NINODE`,
`NFILE`, `NMOUNT` (5--8), `NCALL`, `NPROC`, `NTEXT`, and `NCLIST` (19--22)
are therefore the names of variables, declared at the end of the file
(146). The configuration file which `mkconf` writes for each machine
defines the tables at the configured sizes, and the variables with them
(#f("qemu/c.c")); everywhere else a table's size is read at run time,
as in the loops which search the tables, `for (p = &proc[0]; p <
&proc[NPROC]; p++)`. User programs which read the tables, `ps` and
`pstat`, read the variables too, from the kernel's memory.

`MAXMEM` (9), like every size in core, is expressed in clicks of 4096
bytes (see below). In v7 it was `64*32`, 64 K words of 32 clicks each,
and the comment recalled the units. It is now 32768 clicks, 128 MB: the
largest image a process can have. The user address space (`USERSIZE`)
is far larger, but an image must fit in core, where the machines have
512 MB, and `startup` (#f("machdep.c")) limits `maxmem` to `MAXMEM`.
v7's `fork` (#f("sys1.c")) also insisted that the swap area could hold
a process of this size; the port's asks only for room for the caller's
own image. The configuration (#f("qemuconf")) makes the swap area large
enough for one image of `MAXMEM` clicks and more.

`SSIZE` and `SINCR` (11, 12) are the size of the stack which `exec`
gives a new program and the amount by which `grow` (#f("sig.c")) enlarges
it, both in clicks. v7 had 20 clicks of 64 bytes, 1280 bytes, for each;
here each is one page, 4096 bytes, the least whole number of clicks
which holds v7's amount.

`CMAPSIZ` and `SMAPSIZ` (15, 16) are the sizes of the two resource maps
(#f("map.h")), which v7 left at 50 while it raised `NPROC` to 150. They
are derived from a bound on the number of free areas. Each free area of a map lies between
two allocated ones, so the free areas number at most one more than the
allocated areas, and the map needs one entry more for its sentinel
(#f("malloc.c")). Core holds at most a process image for each process
and a text for each `text` entry, and `expand` (#f("slp.c")) briefly
holds two images of the process it grows: `NPROC+NTEXT+1` allocated
areas, hence `NPROC+NTEXT+3` entries. The swap area holds at most an
image for each process, a copy of each text, and the argument list of
each process in the middle of an `exec` (#f("sys1.c")): `2*NPROC+NTEXT`
allocated areas, hence `2*NPROC+NTEXT+2`. Since `NPROC` and `NTEXT`
are variables, so are these sizes; only the configuration file, where
the names are constants again, uses them to define the maps.

`PMAPSIZ` and `NPTAB` (17, 18) are new. The user page tables of the
processes in core are taken from a pool of `NPTAB` pages which `startup`
sets aside, and allocated from it with a third map, `ptmap`
(#f("ureg.c")). Each process holds one run of pages from the pool, so
by the same bound the map needs `NPROC+2` entries. A small process needs
four pages of tables; the 256 beyond `4*NPROC` let a few hold more.

`HZ` (23) is the number of clock interrupts per second. The PDP-11 took
its clock from the mains frequency; here the ARM generic timer is
programmed to interrupt `HZ` times each second (`clkstart`, #f("machdep.c")).

The local time zone (24, 25) is compiled into the system. This is why
`date` reports Eastern time unless the kernel is rebuilt.

#lines(1, 28)

Priorities for processes which `sleep`. The lower the value, the more
urgent the process: `PSWP` is the most urgent of all. A process which
sleeps at a priority of `PZERO` or less cannot be disturbed by a
signal; one which sleeps above `PZERO` may be, and will then return
from the system call prematurely. The reader will find this
distinction tested in `sleep` (#f("slp.c")).

#lines(29, 44)

`NSIG` is one more than the number of signals, since signal zero means
"no signal". The pending signals of a process are kept as bits in
`p_sig` (#f("proc.h")), and v7 allowed sixteen, the bits of a PDP-11
word. `p_sig` is now an `int`, and `NSIG` has been raised from 17 to 32:
31 signals, as many as a 32-bit word holds without its sign bit, which
`1<<(sig-1)` must not reach. The comment (52, 53) has been changed to
match. Only v7's fifteen signals have names; the others may be sent,
caught, and ignored by number.

#lines(45, 70)

`NBPW` (76), the number of bytes per word, was already `sizeof(int)`
in v7, and so is now 4 rather than 2.

A disk block holds 512 bytes. Since a block number (`daddr_t`, 132)
occupies four bytes on both machines, an indirect block holds 128 block
numbers (`NINDIR`), and `NMASK` and `NSHIFT` are unchanged.

`USIZE` (85) is the size, in clicks, of the "per process data area":
the `user` structure followed by the kernel stack. It has grown from
1024 bytes, 16 clicks of 64 bytes, to two pages, 8192 bytes, because a
thirty-two bit kernel stack is larger. The `user` structure takes 968
of them, which leaves 7224 for the stack. The compiler can report the
stack frame of every procedure and the calls each makes
(`-fcallgraph-info=su`), and from that report the deepest chain of
calls was measured: about 630 bytes from a system call or a trap,
including the 68-byte register frame of #f("low.s"), through `exec`,
`readi`, `bmap`, and the buffer cache down to `sleep`, `swtch`, and a
`printf`; about 280 more for an interrupt taken at that point; and at
most some 260 for the bounded recursions of `printn` (#f("prf.c")),
one level for each digit, and `tloop` (#f("iget.c")), one for each
level of indirect block. The kernel thus needs about 1.2 KB of stack
and has more than six times that; one page would also suffice, with
less to spare. The measurement is not part of the build. `UBASE` (86) is the address at
which the data area of the current process always appears, so that the
kernel may refer to it simply as `u`. It lies in the topmost megabyte
of the kernel's part of the address space, above everything else the
kernel maps (@ch-startup).

`USERSIZE` (87) is new: the size of the user's virtual address space,
which begins at address zero. It is the counterpart of the PDP-11's
64 KB. It is three gigabytes, all of the address space below the
kernel's (@ch-startup).

A character list ("clist") is built of blocks, each holding a pointer
to the next block and `CBSIZE` (97) characters. With a four byte
pointer, 12 characters (rather than 14) keep each block 16 bytes long,
and `CROUND` remains 017 as the comment demands.

#lines(71, 99)

The conversion macros. A click was 64 bytes, the granule of the PDP-11
memory management unit. The ARM unit maps pages of 4096 bytes, and the
click is now the page. UNIX/32V made the same change on the VAX, whose
page was 512 bytes: it kept v7's macros and changed only their
constants. So here: `ctob` and `btoc` (117, 120) shift by 12 rather
than 6, and `ctod` (108), which converts clicks to 512-byte disk
blocks, multiplies by 8, where it once divided by 8, rounding up.

A PDP-11 segment was 128 clicks, 8 KB, and `ctos` and `stoc` (104,
105) converted between the two units; `sbreak` (#f("sys1.c")) uses them
to find where the data begins, at the first segment after the text.
On the ARM the unit of mapping and of protection is the page itself, so
a segment is one click, and the macros convert nothing.

`itod` and `itoo` (111, 114) find inode `x` on the disk: the block of the
i-list which holds it, and its place in the block. The i-list begins at
block 2, and an inode is now 128 bytes, four to a block (#f("ino.h")),
so the macros shift by 2 and mask with 3 where v7's, for eight inodes of
64 bytes, shifted by 3 and masked with 7; the addend, `2*INOPB-1`, is 7
where it was 15.

#lines(100, 130)

`ino_t` is `unsigned short`, so that an inode number still occupies two
bytes in a directory entry on the disk (#f("dir.h")). `label_t` has ten
words, to hold registers r4 to r11, the stack pointer, and the link
register, which are saved by `save` (#f("mch.s")); the comment, which in v7
spoke of the PDP-11's registers 2 to 7, now says so.

`time_t` (135) is a `long long`, a signed count of 64 bits, where v7's
was a `long`. On the PDP-11 and on the ARM alike a `long` is 32 bits,
and a signed count of seconds since 1970 in 32 bits ends on 19 January
2038; 64 bits last for some 292 thousand million years. The ARM
aligns a `long long` on eight bytes, so every structure which holds a
`time_t` is laid out anew: the inode on the disk (#f("ino.h")), the
super-block (#f("filsys.h")), `stat` (#f("stat.h")), `user` and `xproc`
(#f("user.h"), #f("proc.h")), and the records of accounting, of the
login history, and of the archive formats which the commands keep.

#lines(131, 139)

These describe the PDP-11 processor status word, and survive because
`clock` (#f("clock.c")) examines its argument `ps` with `USERMODE`. The
ARM has no such word to offer; `irq` (#f("machdep.c")) instead passes
`UMODE` if the interrupted program was in user mode, and zero
otherwise. v7 also defined `INTPRI` and `BASEPRI`, with which `clock`
asked whether the interrupted program had run at a raised priority.
An interrupt can only be taken here while interrupts are enabled, which
is the base priority, so the test was always false; both are gone.

#lines(140, 145)

The declarations of variables. The first are the table sizes, defined
by the configuration (#f("qemu/c.c")). The values which may differ
between the two machines are defined there too: the end of core
(`coretop`), the attributes of a user page (`pguser`, #f("ureg.c")), and
the addresses of the interrupt controller. `corebase` and `coreoff`,
where core begins and how far its kernel addresses lie from its physical
ones, are computed by `machine_init` (#f("machdep.c")).

User programs include a copy of the file, `/usr/include/sys/param.h`,
as they did in v7. The copy is identical to this file but for a guard
around `NULL` (88), which `stdio.h` (#f("stdio.h")) defines as well; a
program which includes both would otherwise define it twice. The same
holds for the other headers which appear in both places, `inode.h`
among them, except that `stat.h` and `timeb.h` add prototypes for their
system calls (#f("stat.h")).

#lines(146, 147)
#source("/usr/sys/h/systm.h")

#f("systm.h") is the kernel's collection of global variables and,
in the port, of declarations for the procedures which more than one
file calls. In v7 it held only the former, together with a handful of
function declarations, mostly for routines which return pointers;
every other routine was declared implicitly by its first
call. Strict C99 has no implicit declarations, so the file has grown
from 81 lines to 182, nearly all of the growth being one long list.

In v7 none of the variables was declared `extern`, except those
defined in assembler or in some particular file (`regloc`, `icode`,
`szicode`, `sysent`). Every file which included the header therefore
emitted a "tentative definition" of each, and the linker merged them
into a single zeroed copy: the old common-block convention of the UNIX
linker. C99 permits one external definition of an object in the whole
program, and GCC does not merge such definitions by default. Every
variable is therefore now declared `extern`, and defined once:
`rootdev`, `swapdev`, `pipedev`, `swplo`, and `nswap` with their values
in the configuration file #f("qemu/c.c"), as in v7; `msgbufp` and the
clock's variables in #f("machdep.c"); `l1tab` and `l1pa` in
#f("ureg.c"); the rest in #f("main.c"). Since the array sizes (6,
39) come from #f("param.h"), that file must be included first.

v7's `cputype`, the model of PDP-11, and `lks`, the address of the
clock's register, are gone with the hardware they described.

#lines(1, 26)

`runin`, `runout`, and `runrun` (29-31) are the flags by which `sched`
and `swtch` (#f("slp.c")) communicate. `regloc` (38) is defined in
#f("sysent.c"), which also holds v7's `trap.c`; its comment says so.

`msgbufp` (40) is new. v7 defined this pointer into the circular
buffer `msgbuf` in its console driver, `kl.c`. There are two console
drivers here, #f("pl011.c") for the QEMU machine and #f("stm32usart.c")
for the MP135 machine, and both append to the buffer, so the pointer is
defined once in #f("machdep.c") and declared here for both.

The four variables of the clock (46, 47) are new as well. `clkstart`
(#f("machdep.c")) sets them up, and `clock`
(#f("clock.c")) uses them to set the deadline of each tick. `l1tab` and
`l1pa` (48, 49) locate the first-level page tables of the processes,
one for each slot of the process table, by the kernel's address and by
the physical address the hardware needs; `startup` (#f("machdep.c"))
takes them from core, and `sureg` (#f("ureg.c")) fills them.

#lines(27, 49)

These are v7's own declarations, now given parameter lists. `namei` (57) takes as
its first argument the routine which fetches the next character of the
path name: `uchar` when the name is in user space, `schar` when it is
in the kernel.

#lines(50, 66)

The list which follows is entirely new. Each procedure which is
called from another file, or before its definition, is declared once
here, with a prototype, instead of being declared in each calling file
or not at all. The routines are grouped by return type and sorted by
name.

The forward declarations (67) deserve a word. A structure tag which first appears inside
a prototype's parameter list belongs to that prototype alone, and a
later definition of the structure would be a different type. `inode`,
`proc`, `buf`, `file`, and `filsys` have already been declared at file
scope by lines 7 to 65; `clist`, `map`, `text`, `tty`, and `uprof` have
not, so they are declared, without members, before the lists use them.
`uprof` is the tag the port gives to the profiling arguments `u_prof`
in #f("user.h"), so that `addupc` can be declared.

Most names in the list will be familiar from v7, now typed as
`void` because they return nothing. Among them are the system call
handlers, which take no arguments since they find them through
`u.u_ap`. The rest belong to the port:

- `machine_init`, `install_sigtramp`, `irq`, `panictrap`,
  `sigreturn`, and `vtop` are in #f("machdep.c"), and so, in the second
  list, are `fumem` and `sumem`, which read and write a byte for the
  memory special files. `sigreturn` is system
  call 63, which a signal handler returns through. `irq` is the
  interrupt handler. `vtop` (157) turns a kernel address into the
  physical address a device must be given.
- `ptfree` (#f("ureg.c")) releases a process's page tables.
- `ttyhold` and `ttyunhold` (#f("tty.c")) hold back console input
  which the raw queue cannot take.
- `arm_sync_icache`, `dcflush`, `dcinval`, `dmbsy`, `idle`, `restfp`, `savfp`,
  `tlbflush`, `ttbset`, and the generic timer accessors `cntv_ctl_set` and
  `cntv_cval_set` are in #f("mch.s"). There, too, are `cntfrq_get`, `dfar`, and `dfsr`, in the
  second list (137--140), which return the timer frequency and the
  address and status of the last data abort. `savfp` and `restfp`, v7's
  names, store and load the floating point registers of the current
  process.
- `cninit`, `bdinit`, and `clock_ddr_init` are generated by `mkconf`
  into each machine's #f("qemu/c.c"). They call the initialisation
  routines of the console, `klinit`, and of the disk, `rkinit`, and on
  the MP135 machine also `ddrinit` (#f("stm32ddr.c")).
- The drivers keep v7's names. `rkstrategy` and its companions are
  defined by #f("virtio_blk.c") for the QEMU machine and by
  #f("stm32sd.c") for the MP135 machine; likewise the `kl` routines and
  `putchar` by #f("pl011.c") and by #f("stm32usart.c"). Each machine's
  kernel links only its own drivers, so the names never clash.
- `user_trap_handler` (#f("sysent.c")) converts an undefined instruction
  or an abort taken in user mode into a signal, unless the abort only
  asked for more stack, and then, like the end of v7's `trap`,
  recomputes the priority and switches if `runrun` is set. Its third
  argument is the address which a data abort failed to reach. The
  interrupt path in #f("low.s") also calls it, with signal zero, for
  the second purpose alone.
- `nostrat`, `nordwr`, `noioctl`, `nolioctl`, and `nulltty`
  (#f("subr.c")) fill the slots of the device and line switches. v7 put
  `nodev` and `nulldev` in every such slot whatever its arguments,
  which K&R C allowed; with prototypes, each kind of slot needs a
  placeholder of the matching type.
- `addupc` (68) was assembler in v7's `mch.s`; it is now C, in
  `clock.c`, and is called from `clock` and from `trap`.

`clock` (75) had in v7 seven parameters, which mirrored the PDP-11
interrupt frame. Only the last two, the program counter and the
processor status, were ever used, and only they remain; `irq` passes
the saved PC and the mode (#f("param.h")).

#lines(67, 135)

The routines which return a value. `expand` (140) and `xswap` (154)
are among them, where v7's returned nothing: each returns zero when
there is no swap space for the image (#f("slp.c"), #f("text.c")).
`save` (148) returns twice, like
`setjmp`: zero when it saves, one when `resume` later returns through
the saved label. `max` and `min` keep v7's `int` result, although
their arguments are `unsigned`. `cntvct_get` (156), which reads the
generic timer's counter (#f("mch.s")), returns all 64 bits of it as an
`unsigned long long`. `machine_init` (155) returns the address at which
#f("low.s") is to place the kernel stack.

`printf` (158) has a true variable argument list. v7's `printf`
walked up the PDP-11 stack from the address of its first argument.
Under the ARM calling convention the first four arguments arrive in
registers, so #f("prf.c") uses `<stdarg.h>` instead.

#lines(136, 158)

On a PDP-11 with separate instruction and data spaces, reading a
program's text required different instructions (`mfpi`, `mtpi`) from
reading its data, hence v7's separate routines `fuibyte`, `suiword`,
and so on. The ARM has one address space, so the I-space forms are
simply aliases, and their callers (`passc`, `cpass`, `iomove`,
`procxmt`) keep v7's text.

#lines(159, 164)

Counters for `iostat`, kept by the clock and by the drivers, which
set and clear their bit of `dk_busy` around each transfer. Like the
variables above, they are `extern` here and defined in #f("main.c").

#lines(165, 173)

The table of system calls, defined in #f("sysent.c") and indexed by
`trap` with the number of the call. The handler (181) was declared in
v7 as returning `int`, by default. The handlers return nothing; their
results go back to the user through `u.u_r`. It is now a pointer to a
`void` function of no arguments, and every handler is defined so.

#lines(174, 182)
#source("/usr/sys/h/seg.h")

In v7, #f("seg.h") held the addresses of the PDP-11 memory management
registers (the KT-11 unit) and the bits of a segment descriptor. The
PDP-11 divided each address space into eight segments of up to 8 KB,
each described by a pair of registers: an address register, giving the
base in clicks, and a descriptor register, giving the length and the
access rights. None of that hardware exists here, and v7's definitions
for it are gone. What remains of v7's file is its first comment,
corrected to describe what follows, and the two access rights, followed
by the definitions which the port adds.

#lines(1, 4)

`RO` and `RW` (5, 6) are the access rights which callers pass to
`estabur` (#f("ureg.c")) for the text: read-only, or read and write.
On the PDP-11 they were the access field of a descriptor register. Here
they are the access permission bits of a long-format page entry, bits 6
and 7, and `ptbuild` (#f("ureg.c")) ors them into the entries which
map the text: 11
lets user mode read the page but not write it, 01 lets it do both, and
in either case the kernel may do both. The data and the stack are
always mapped `RW`. The page entries' other bits come from `pguser`,
which the configuration gives without the access bits
(#f("qemuconf")).

#lines(5, 6)

`UENTRY_SIGTRAMP` (7) is the user address of a two-instruction
trampoline, `mov r7, #63; svc #0`, which `xalloc` (#f("text.c")) writes
into every text it reads in (`install_sigtramp`, #f("machdep.c")). `sendsig` sets the link
register to it before entering a signal handler, so that the handler's
return executes the `sigreturn` system call. v7's `sendsig` needed no
such help: it pushed the old program counter and status word onto the
user stack, and the catcher in the C library returned with `rtt`. In
the port the kernel restores the interrupted registers itself, in
`sigreturn`. Address 8 lies below the point at which programs begin
(0xa0, #f("Makefile")), so it can never collide with a program, and
location 0 still reads as zero.

`CLKADDR` (8) converts a click number into a kernel address. On the
PDP-11, a click number was a physical address divided by 64, and the
kernel reached it by loading a segmentation register. Here a click
number is a physical address divided by 4096, a page number, and all of
core is mapped into the kernel's address space at a fixed distance,
`coreoff`, from its physical address (@ch-startup), so the conversion is
a shift and an addition. The shift is done on an `unsigned` value, since
the MP135 machine's memory lies above 0x80000000, where an `int` would
overflow. Every place where v7 manipulated memory by click
(`copyseg`, `clearseg`, `swap`, `physio`) goes through this macro.

#lines(7, 8)

The remainder are constants of the ARM's long-descriptor tables
(#f("low.s")), used by `machine_init` (#f("machdep.c")), by `sureg`
(#f("ureg.c")), and by the table of regions which `mkconf` writes into
#f("qemu/c.c"). Each entry is 64 bits, of which the attributes occupy
the low twelve and the top twelve.

`BLK_KERN` (9) describes a 2 MB block of kernel memory. Read from the
right: block type (1); attribute index 0 (bits 2 to 4), which `MAIR0`
defines as normal memory, cached write-back; access permission 00 (bits
6 and 7), read and write for the kernel and nothing for user mode;
inner shareable (0x300); and the access flag (0x400), without which the
first reference would fault. It is global (bit 11 clear), so that its
translations survive a change of the user's tables.

`BLK_DEV` (10) describes a block of device registers: attribute index 1,
device memory, which is neither cached nor touched speculatively; the
same permission and access flag; and, in the top word, the "execute
never" bits for both privileged and user mode (bits 53 and 54), which
keep the processor from fetching instructions from device memory, even
speculatively, as the architecture requires. Its shareability is
ignored. Both kinds of block are reached only through the kernel's
table, at addresses above `USERSIZE`, and user mode cannot reach them at
all, whatever their permission bits.

`PTE_TAB` (11) is the type of an entry which points to a table of the
next level, and also the type of a page entry at the third level.
`PGSHIFT` and `PGSIZE` (12, 13) describe the 4 KB page, the unit of the
user mapping, and `PTPGB` (14) the number of pages in a gigabyte, the
reach of a second-level table. `struct memregion` (15) is the type of
the table `board_map`, which `mkconf` writes into #f("qemu/c.c") from the
`map` lines of the machine's configuration file. Each entry is a range of
physical addresses, the kernel address at which it is to be mapped, and
the block descriptor bits to use.

#lines(9, 15)
#source("/usr/sys/conf/low.s")

#f("low.s") takes the place of v7's `l.s`, the "low core" file. On the
PDP-11, `l.s` filled the bottom of physical memory with the interrupt
vectors (a new PC and PS for each trap and each device) and supplied, for
every device, a two-instruction stub which entered the common routine
`call` with the address of the C handler. `mkconf` generated it anew for
each configuration. None of that survives. The ARM has eight exception
vectors, and only one of them serves all devices; the interrupt
controller (GIC) is asked which device interrupted, and `irq`
(#f("machdep.c")) looks the answer up in `intrtab`, which `mkconf` now
writes into #f("qemu/c.c"). So #f("low.s") is the same for every
configuration, and it holds what in v7 was split between `l.s` and the
start of `mch.s`: the reset code (v7's `start`), the vectors, and the
assembler `trap` and `call` routines which build the register frame for
C.

A few ARM facts are needed throughout. The processor is always in one
of several modes, named by the low five bits of the program status
register `cpsr`: user (`0x10`), IRQ (`0x12`), supervisor or SVC
(`0x13`), abort (`0x17`), undefined (`0x1b`), and system (`0x1f`). The
kernel runs in SVC mode, which plays the part of the PDP-11's kernel
mode. Each exception enters its own mode, and each mode except system
has private ("banked") copies of `sp` (`r13`) and `lr` (`r14`), and a
saved program status register `spsr`, into which the hardware copies
`cpsr` at the exception. The return address goes into the new mode's
`lr`. Bit 7 of `cpsr` (`I`) masks interrupts and bit 6 (`F`) the fast
interrupts; `cpsid` sets and `cpsie` clears them. The registers `r0` to
`r12` are shared by all modes (apart from `r8` to `r12` in the unused FIQ
mode). Coprocessor 15 (`p15`), reached by `mrc` (read) and `mcr` (write),
holds the system control registers: the MMU, the caches, and the like.

The processor arrives at `_start` (2) from the boot loader in SVC mode.
Interrupts and fast interrupts are masked at once (3), the analogue of
v7's `spl 7` state at the start.

The system control register `SCTLR` is then read, and five bits are
cleared: the instruction cache (bit 12), the data cache (2), branch
prediction (11), "high vectors" (13), which would place the vectors at
`0xffff0000`, and the MMU itself (0). Whatever the boot loader left
switched on, the kernel now runs on physical addresses with no cache.
`isb` makes sure that the following instructions are fetched under the
new setting.

The kernel is linked to run at its kernel addresses, above 0xc0000000
(@ch-startup), but the loader has put it at its physical address and
started it there (#f("qemu/unix.ld")). Until the MMU is on, an absolute
address taken from the program is therefore wrong by a constant, and
the code up to line 91 must be position-independent: it may branch
relative to the PC, and load constants, but use the address of a
variable only after correcting it.

#lines(1, 11)

The TLB (the cache of address translations), the instruction
cache, and the branch predictor are invalidated, so that nothing from the
loader's regime can be found in them later. The data cache is dealt with
below. `dsb` waits for these operations to finish.

#lines(12, 17)

`adr` (18) forms the address of `_start` from the PC, and so yields
where the kernel actually is; the literal `=_start` (19) is the address
at which it was linked. Their difference, kept in `r4`, turns any
kernel address into a physical one.

The `bss` area is cleared, a word at a time, as `start` cleared it in
v7, at its physical address. The bounds are symbols defined by the
linker script. The boot stack and the boot translation tables lie in
the area being cleared; this is harmless, since nothing has yet been
put in them.

#lines(18, 29)

The MMU is used in the "long-descriptor" format of the ARM's Large
Physical Address Extension, which the Cortex-A7 implements. Its tables
have 8-byte entries; a first-level entry maps a gigabyte, a
second-level entry two megabytes, and a third-level entry a page, and
an entry at either of the first two levels may map its whole range
directly (a "block") instead of pointing to a table of the next level.
The format can divide the address space between two tables, one for
the low addresses and one for the high, which the short-descriptor
format of the earlier ARMs cannot do at a three-gigabyte boundary; that
is why it is used. The kernel's table `kl2` (204) is a second-level
table of 512 entries, which together map the gigabyte from 0xc0000000.

Here `kl2` receives the blocks which hold the kernel itself, from
`_start` to the end of `bss`. `r0` runs over the numbers of the 2 MB
blocks, `r1` is the last, and each entry is the block's physical
address, the kernel address plus `r4`, or'ed with `0x701` (37): a block
(1), of attribute 0, normal write-back memory (below), shareable
(`0x300`), with the access flag set (`0x400`), and with access
permission 00, read and write for the kernel only. `ubfx` takes the
low nine bits of the block number, the index in the table. The upper
word of each entry stays zero. The difference in `r4` is a multiple of
2 MB on both machines (#f("qemuconf")), as it must be for a block to map
the kernel exactly.

#lines(30, 46)

`bootl1` (206) is a first-level table for the low addresses, with a
single entry: the gigabyte which contains the kernel's physical
address is mapped onto itself. When the MMU is turned on, the next
instructions are still fetched at physical addresses, and this mapping
keeps them in place; `machine_init` removes it.

#lines(47, 53)

Bit 6 of the auxiliary control register `ACTLR` (the "SMP" bit) is set.
The Cortex-A7 does not treat shareable memory as coherent until this bit
is set, and without it cached writes to memory can be lost. It must be set
before the caches are enabled.

The cache size selection register is set to 0 (58), the level 1 data
cache, so that the next read describes it. The cache size
identification register `CCSIDR` gives the logarithm of the line size
in bytes (`r1`), the number of ways less one (`r3`), and the number of
sets less one (`r7`). `ip`, the count of leading zeros of `r3`, is the
shift which puts a way number into the top bits of a word.

Each line of the data cache is invalidated "by set and way"
(`DCISW`, `c7, c6, 2`), the operand being the way shifted to the top,
or'ed with the set shifted by the line size. The outer loop counts the
sets down, the inner the ways. Invalidation, not cleaning, is wanted:
the cache has been off since `_start`, and whatever it holds must not
be written back over memory.

#lines(54, 77)

The memory attribute register `MAIR0` (78, 79) defines the attributes
which entries name by number: 0 is normal memory, cached write-back in
both inner and outer caches (`0xff`), and 1 is device memory (`0x04`),
which is neither cached nor accessed speculatively. The translation
table base control register `TTBCR` (80, 81) selects the long format
(bit 31) and divides the address space: with `T1SZ` 2, the top gigabyte
is translated through `TTBR1`, starting at the second level, and the
rest, from 0 to 0xbfffffff, through `TTBR0`; table walks for both go
through the write-back caches and are shareable, as the kernel's own
writes to the tables are. The 64-bit `TTBR0` and `TTBR1` (82, 83),
written with `mcrr`, receive the physical addresses of `bootl1` and
`kl2`; `r2` is still zero, the upper word.

In `SCTLR`, the MMU (bit 0), the data cache (2), and the instruction
cache (12) are turned on together. The PDP-11 counterpart is the single
instruction at the end of v7's `start` which set bit 0 of `SSR0`, once
the segmentation registers had been loaded. The load of the PC (91)
then jumps from the physical address, where the identity mapping kept
execution going, to the kernel address of the next line.

#lines(78, 92)

A provisional stack, at the start of the kernel's `bss` (200--202),
serves until the u-area of process 0 can be mapped. v7 needed no such
thing: its `start` set the memory management registers inline and then
pointed `sp` at the u-area directly.

The vector base address register `VBAR` is loaded with the
address of `vectors` (111). With bit 13 of `SCTLR` clear, the processor
takes exceptions through this table, wherever it lies. The table must be
aligned on 32 bytes (110).

#lines(93, 95)

The floating point unit, VFPv4 with the Advanced SIMD extension (NEON)
on both machines, is off at reset. It is reached as coprocessors 10 and
11, and the coprocessor access control register `CPACR` (96--98) opens
both to privileged and user mode. After the `isb` (99), which makes this
and the new `VBAR` take effect, the enable bit of the floating point
exception register `FPEXC` (bit 30) is set (100, 101). The unit is left
on for good. User programs execute its instructions directly; the kernel
is compiled without them (#f("sys.mk")), so the registers always hold
the state of the current process, which `savfp` and `restfp`
(#f("mch.s")) move to and from its u-area. v7's floating point
processor needed no such step.

#lines(96, 101)

`machine_init` (#f("machdep.c")) maps the device registers, starts the
console, brings up the DDR memory of the MP135 machine, maps the rest
of memory, clears the tables which live in it, maps the u-area of
process 0 at `UBASE`, and removes the identity mapping.

The stack pointer is then moved (103) to the top of the u-area, whose
address `machine_init` returns: `UBASE` (0xFFF00000) plus the
`USIZE` pages of the area, 8192 bytes. The assembler does not read
#f("param.h"), so the sum is left to C, which does. From now on the SVC stack is always the kernel stack of the
current process, at the same virtual address in every process, as
`KDSA6` arranged on the PDP-11.

`main` (#f("main.c")) is called (104). Process 0 never returns from it;
it ends in `sched`. Process 1, made by `newproc`, does return here, after
`main` has copied `icode` to user address 0.

#lines(102, 104)

The return to user mode. `spsr` is set to `0x10`, user mode
with both interrupt masks clear, `lr` to 0, and `movs pc, lr` copies
`spsr` into `cpsr` while it jumps: the standard ARM return from an
exception. This is v7's sequence of pushing a user-mode PS and a zero PC
and executing `rtt`. No user stack pointer is set: `icode` needs none,
and the `exec` it performs gives `/etc/init` its own.

#lines(105, 108)

The exception vectors. Each entry is an instruction, not an address, and
is executed in the mode which the exception selects; here each is a
branch. In order they serve reset, undefined instruction, supervisor call
(`svc`, the ARM's `trap` instruction), prefetch abort (an instruction
fetch from an unmapped or forbidden address), data abort (the same for a
load or store), a reserved slot, IRQ, and FIQ. Reset simply restarts the
system. The reserved slot and FIQ should never be taken, and lead to
`badtrap` (153).

Note that the PDP-11 distinguished its traps by vector, and wrote the
trap type into the low bits of the new PS (`br7+n` in `l.s`) for `trap`
to recover. On the ARM the vector, and the signal chosen at 162, 171, or 185,
carry the same information.

#lines(109, 119)

The system call entry, the counterpart of v7's `trap` routine when it is
entered by a `sys` instruction. The processor arrives in SVC mode with
interrupts masked, `lr` holding the address after the `svc` and `spsr`
the user's `cpsr`. The task is to lay down on the kernel stack a frame
of all the user's registers, in the order which #f("reg.h") describes,
and to hand its address to C.

`srsdb sp!, #0x13` (122), "store return state", pushes `lr` and `spsr`
onto the stack of the mode named (SVC), and updates that stack pointer.
Room is then made for fifteen words, and `stmia sp, {r0-r14}^`
stores `r0` to `r14`. The `^` makes the instruction store the *user*
mode's banked `sp` and `lr`, not SVC's, without a change of mode. The
architecture forbids writeback with this form, hence the separate `sub`.

The frame is thus seventeen words: `r0`--`r12` at 0 to 48, the user `sp`
at 52, the user `lr` at 56, the return PC at 60, and the saved status at
64. This is why `R6`, `R7`, and `RPS` in #f("reg.h") are 13, 15, and 16:
`u.u_ar0[R6]` is the user stack pointer, `u.u_ar0[R7]` the PC, just as
`r6` and `r7` were `sp` and `pc` on the PDP-11.

#lines(120, 124)

`trap` (#f("sysent.c")) is called with the frame's address,
which it saves in `u.u_ar0`. Interrupts are enabled for the duration of
the system call and masked again afterwards. v7's `trap` routine also
lowered the priority (`spl 0` in `call1`) before calling C. The return
is shared with the other traps (192).

#lines(125, 129)

The interrupt entry, which does the work of v7's `call`. An IRQ arrives
in IRQ mode, with `lr` four bytes beyond the instruction to be resumed;
line 132 corrects it.

The return state is then pushed, not on an IRQ stack, but on the SVC
stack, and the processor changes to SVC mode itself with both masks
set. IRQ mode therefore needs no stack of its own, and none is set up.
If the interrupt came from user mode, the SVC stack is empty and the
frame goes at the top of the u-area; if it came from the kernel, the
frame goes below whatever the kernel was using, and nests as on the
PDP-11.

#lines(130, 134)

The registers are saved as before. If the kernel was
interrupted, the `sp` and `lr` stored are the user's, not the kernel's;
they are restored unchanged at the end, so no harm is done. The kernel's
own `sp` is the frame pointer itself.

The one register in danger is SVC's `lr`. When the kernel is
interrupted, it may hold a live return address, and the `bl` at 139
would destroy it. It is kept in `r5` (137, 140), which the C calling
convention obliges `irq` to preserve.

`irq` (#f("machdep.c")) asks the GIC for the interrupt number,
and calls `clock` or the device handler.

#lines(135, 139)

If the interrupted program was in user mode (the mode field of
the saved status, at offset 64, is `0x10`) and `runrun` is set, the
process should give up the processor before it returns. v7's `call`
did this by calling `trap` with type 12; here the code joins the traps'
call of `user_trap_handler` (#f("sysent.c")) below (187), with signal 0
and a zero address (149, 150). Signal 0 posts nothing; the call only
runs the same tail as a trap: `issig`, `psig`, `setpri`, and `qswtch`.
Otherwise the frame is unloaded at once (192). Without this test a
process which never made a system call would never be preempted, nor
see a signal.

#lines(140, 151)

`badtrap` catches the two vectors which should never be used. It calls
`panictrap` (#f("machdep.c")), which panics. It runs in whatever mode
the stray exception selected, on a stack which was never set up.

#lines(152, 155)

The remaining exceptions all become signals to the process. The three
entries differ in the correction to `lr` and in the signal number. For
a prefetch abort `lr` is four bytes past the instruction, for a data
abort eight, and the correction makes the saved PC address the
offending instruction, which the return then executes again, as it must
once the stack has grown. For an undefined instruction `lr` is also
four bytes past the instruction, and is left so: as after the PDP-11's
trap, the saved PC addresses the next instruction, and a handler of the
signal which returns, an emulator of a missing instruction, for
example, continues there instead of meeting the same instruction again.
In Thumb state, which the library's arithmetic routines use, `lr` is
only two bytes past the instruction, the next one only if the
instruction was 16 bits long; `user_trap_handler` (#f("sysent.c"))
adds the other two for a 32-bit one.
An undefined instruction yields signal 4 (`SIGINS`), either abort
signal 11 (`SIGSEG`). The PDP-11's illegal instruction and segmentation traps
gave the same signals; its bus error (`SIGBUS`) has no counterpart here.

The frame is built exactly as for an interrupt (158--161, 167--170,
176--179). Only then is the signal number loaded, into `r0` (162, 171,
185), and `user_trap_handler` receives the signal, the frame, and in
`r2` an address (187--190). For a data abort the address is the one the
instruction failed to reach, read from the fault address register
`DFAR` (186), by which the handler decides whether the stack should
grow (#f("sysent.c")); a prefetch abort passes zero (172), and so does
an undefined instruction (163). The handler reads the address only for
`SIGSEG`, but it is given a defined value in every case, never the
user's `r2`, which the `stmia` has saved but left in the register. The handler
panics, after printing the fault address and status (`dfar`, `dfsr`,
#f("mch.s")), if the exception came from the kernel.

A data abort taken by the kernel may be one which it expects. While one
of the routines which reach user memory runs, `nofault` (#f("mch.s"))
holds the address at which it wants to continue if a user reference
fails, as v7's `trap` found it in `nofault` on the PDP-11. That address
is then written over the saved PC (180--184), and the exception returns
there at once, by the common return below, without calling C. The
saved registers are restored as they were at the fault, and SVC mode's
own `lr`, which C would have destroyed, is never touched. A fault in
user mode cannot meet `nofault` set, since the routines clear it
before they return.

The save is repeated, rather than shared by all three, because no
register is free to carry the signal number to a common save: `r0` to
`r12` are the user's until they have been stored, and the banked `sp`
and `lr` of the abort and undefined modes are left behind by the change
to SVC mode.

`user_trap_handler` runs with interrupts enabled (189), as `trap` does
for a system call, and as v7's `trap` ran at priority 0 (`spl 0` in
`call1`). The work it may do, the copying of a grown stack or the
writing of a core image, would otherwise hold off the clock and the
console for its whole length. The call made for `runrun` is treated
alike, though v7's `call` stayed at the priority of the interrupt: the
interrupt has been acknowledged (#f("machdep.c")), and a further one
nests on the SVC stack as it would over any other kernel code.
Interrupts are masked again before the frame is unloaded (191), since
the saved state must not be disturbed between the `ldmia` and the
`rfeia`.

#lines(156, 191)

The common return, the counterpart of the `rtt` at the end of v7's
`call`. `ldmia ... ^` (193), without the PC in the list, loads the user
mode's banked registers, as the `stmia` stored them. `rfeia sp!` (195),
"return from exception", pops the PC and the saved status together into
`pc` and `cpsr`, so the mode, the interrupt mask, and the condition flags
of the interrupted program are restored with its PC in one step.

#lines(192, 195)

The boot stack, 8192 bytes, which is used only until line 103, and the
two boot tables. `kl2` must be aligned on 4 KB, and goes on serving as
the kernel's table; `bootl1`, which needs 32, follows it.

#lines(196, 205)
#source("/usr/sys/conf/mch.s")

v7's `mch.s` held, besides the startup code, every operation which C
could not express on the PDP-11: the `trap` and `call` routines,
`save` and `resume`, the `spl` family, the transfers between kernel and
user space (`fubyte`, `copyin`, and their kin), `copyseg` and `clearseg`,
`idle`, the long division routines `ldiv` and `lrem`, the C function
prologue and epilogue `csv` and `cret`, and the profiling code. On the
ARM much of this has gone elsewhere. The startup, `trap`, and `call` are in
#f("low.s"). `copyseg` and `clearseg` are ordinary C in #f("machdep.c"),
since all of memory is mapped into the kernel's own address space.
Division, procedure linkage, and `addupc` are left to the compiler or to C.
What remains here is the set of routines which must use particular
instructions: those which touch the processor's special registers, the
MMU and caches, the interrupt mask, the timer, and the stack pointer,
and those which reach user memory with the user's permissions, as v7's
did with `mfpi` and `mtpi`.

`p15`, coprocessor 15, holds the system control registers; `mrc` reads
one into a general register and `mcr` writes one. The ARM calling
convention passes the first four arguments in `r0` to `r3`, returns a
result in `r0`, and requires `r4` to `r11` and `sp` to be preserved.
`bx lr` is the return.

`dmbsy` is a data memory barrier: every memory access before it is
observed before any after it. The virtio disk driver (#f("virtio_blk.c"))
uses it to make the descriptors visible to the device before the ring
index which offers them, and the index before the notification; and on
an interrupt, to read the completed request only after the index which
reports it. The
PDP-11 performed accesses in program order and needed nothing of this
kind.

#lines(1, 10)

The interrupt priority routines. The PDP-11 had eight priority levels in
its PS, and a device interrupted only when its level exceeded the
processor's, so that a clock at level 6 could interrupt a disk handler
running at level 5. The ARM core has a single interrupt mask bit, `I`
(bit 7 of `cpsr`). So the levels collapse into two: `spl0` and `spl1`
clear the mask, `spl5`, `spl6`, and `spl7` set it, and every interrupt
handler runs with all interrupts masked. v7's `spl4`, which nothing in
this system calls, is omitted.

Each routine returns the previous `cpsr` in `r0` (14, 25), as v7's
returned the old PS, so that `s = spl6(); ... splx(s);` works.
`splx` (29) looks only at the `I` bit of the value it is given.

Neither `spl0` nor `splx` will unmask interrupts while
`irq_ready` is zero (15--18, 32--35). `clkstart` (#f("machdep.c")) sets it once the
interrupt controller and the timer have been programmed, and then calls
`spl0` itself. Until then interrupts stay masked, whatever `spl0` calls
the initialisation makes.

#lines(11, 40)

Access to the ARM generic timer, which replaces the PDP-11's line clock.
`cntfrq_get` reads `CNTFRQ`, the counter frequency, which the boot loader
or the emulator has set. `cntvct_get` reads `CNTVCT`, the 64-bit count
itself, into `r0` and `r1`, the registers in which a C procedure
returns an `unsigned long long`; the `isb` before it keeps the
processor from reading the counter ahead of the instructions which
precede the call. `cntv_cval_set` loads the compare register of the
virtual timer, which interrupts once the count reaches it, from the
`unsigned long long` argument passed in the same two registers, and
`cntv_ctl_set` writes its control register (1 enables it, with the
interrupt unmasked). `isb` makes the new setting take effect before the
routine returns. `clkstart` (#f("machdep.c")) and `clock`
(#f("clock.c")) use them to produce an interrupt every `1/HZ` second,
and the console's `putchar` (#f("pl011.c"), #f("stm32usart.c")) times
its wait with `cntvct_get`.

#lines(41, 59)

`save(lab)`
records in the array `lab` (a `label_t`, #f("param.h")) the registers
which a C procedure must preserve across a call, together with the stack
pointer and the return address, and returns 0. On the PDP-11 these were
`r2` to `r5`, `sp`, and the PC; here they are `r4` to `r11`, `sp`, and
`lr`: ten words.

#lines(60, 66)

`resume(p_addr, lab)` switches the u-area window to process `p_addr` and
returns, with the value 1, from the `save` which stored `lab`.
Interrupts are masked first (69), as v7 raised the priority to 7.

The physical address of the new u-area, `p_addr` shifted left by 12,
is or'ed with `0x703`, which in a page entry means "page, normal
write-back memory, shareable, accessed, kernel read and write, no user
access", and stored in the third-level table `kl3u`, which maps the top
2 MB of the address space. `UBASE` is 256 pages into that range, hence
the offset `256*8` (70); the entries are 8 bytes apart, and their upper
words stay zero. The constant does not fit an ARM immediate operand, and
is loaded into `ip` (72) first. The u-area of the new process now
appears at `UBASE`. This is the counterpart of v7's single store into
`KDSA6`, the kernel segment register for the u-area.

The window may be cached although it points at different memory after
each switch. The Cortex-A7's data cache is indexed and tagged by
physical address, so a line cached through the old mapping belongs to
the old process's memory and can never be found through the new one;
only the TLB, which holds the old translation, must be cleared, and
is, below.

Exactly `USIZE` pages, two, are mapped, as `machine_init`
(#f("machdep.c")) maps them for process 0; the two stores are written
out because the assembler cannot read #f("param.h"). The other entries
of `kl3u` stay invalid, so that a stray kernel reference beyond the
top of the u-area faults.

#lines(67, 76)

`dsb` makes the table writes visible to the hardware table walker; the
translations of the two pages of `u` are then invalidated
(`TLBIMVAA`, by address, whatever the address space identifier), so
that no translation of `UBASE` to the old u-area remains, and `dsb` and
`isb` wait for that to take effect. The user's mapping is not touched
here; `sureg` (#f("ureg.c")) changes it after the switch.

#lines(77, 83)

The registers are reloaded from `lab`. The reader should
observe that `lab` is always one of `u.u_rsav`, `u.u_qsav`, or `u.u_ssav`,
which lie in the `user` structure; so it is read through the new
mapping, from the new process's u-area. With the new `sp`, and the
saved `lr` held in `r2`, the routine returns into the new process, at
the point where it called `save`, which now appears to return 1.

Two points deserve notice. From the moment the entries are rewritten
(74) until `sp` is reloaded (85), the stack of the old process may
already have vanished from `UBASE`, and the stack pointer addresses the
new process's u-area at a meaningless position; the routine therefore
uses no stack at all, and an interrupt, which would push a frame there,
must be masked. Once the new stack is in place, `spl0` (87) unmasks
them, as v7's `resume` ended with `spl 0`. `spl0` is a call, which
overwrites `lr`; that is why the saved `lr` is loaded into `r2`, which
`spl0` leaves alone, and the return is through it (89). Without the
call, interrupts would stay masked until the process next called `spl0`
or `splx` or returned to user mode; after `expand` had moved a process,
for instance, they would be held off for the rest of the system call.

#lines(84, 89)

`dcflush(addr, n)` cleans and invalidates the data cache over a range of
memory, and `dcinval(addr, n)` only invalidates it. The cache type register `CTR` gives in bits 16 to 19 the log of
the smallest data cache line in words; `r2` becomes the line size in
bytes. The start is rounded down to a line boundary, and each line is
cleaned and invalidated to the point of coherency (`DCCIMVAC`,
`c7, c14, 1`): any dirty data is written to memory and the line is
discarded. `dcinval` enters with `r12` set and discards each line
without writing it (`DCIMVAC`, `c7, c6, 1`). The SD card driver of the
MP135 machine (#f("stm32sd.c")) calls `dcflush` on a buffer before a
DMA (direct memory access) transfer, in which the controller reads or
writes memory by itself, and `dcinval` after a read, since that
controller's DMA does not see the cache: memory must hold what the
processor wrote before the device reads it, and the processor must not
find stale lines after the device has written. The PDP-11 had no cache, and so no such routine.

#lines(90, 111)

`arm_sync_icache` makes instructions just written to memory visible to
instruction fetch. It is called with the kernel address and length of
what was written: by `xalloc` (#f("text.c")) after it has read in a
text and planted the signal trampoline, by `xexpand` (#f("text.c")) and
`swapin` (#f("slp.c")) after a text has been read back from the swap area, by
`procxmt` (#f("sig.c")), with the user address instead, after a
debugger has stored a word into the text, and by `main` (#f("main.c")) after it copies out `icode`. Nothing
else is ever executed: a program's data and stack are not, and the
process switch, which changes only the mapping, does not call it.

The instructions were written through the data cache, while the
instruction cache fills from the point of unification, which on the
Cortex-A7 lies beyond the level 1 data cache. Each line of the range is therefore
cleaned to that point (`DCCMVAU`, `c7, c11, 1`), with the same line
size and rounding as `dcflush`; the loop tests before it cleans, so
that a length of zero cleans nothing. The instruction cache is then
discarded entire (`ICIALLU`): it is indexed by virtual address and
tagged by physical, so a stale line for the memory may sit under any
alias, and the user addresses at which the text will run are not those
through which the kernel wrote it. The branch predictor (`BPIALL`)
goes with it.

#lines(112, 134)

`tlbflush` invalidates the whole TLB (`TLBIALL`) and the branch
predictor. `machine_init` (#f("machdep.c")) calls it after it changes
the kernel's own mapping.

`ttbset(a)` makes the first-level table at physical address `a` the
user's: `TTBR0` is loaded with it (147), its upper word zero, which also
makes the address space identifier zero. The user's entries are marked
"not global", and the kernel's are global, so `TLBIASID` (149) with
identifier 0 invalidates the translations of the old user mapping and
keeps the kernel's; the branch predictor, which holds targets of the
old mapping, goes too. The caches, which are indexed and tagged so as
not to depend on the mapping, are left alone. The tables need no
cleaning: the walker reads them through the data cache (#f("low.s")).
`sureg` (#f("ureg.c")) calls it at every process switch, and whenever
it has rebuilt the current process's tables.

#lines(135, 154)

The routines which move data between the kernel and the current user
process, which were in v7's `mch.s` too. On the PDP-11 they used the
`mfpi` and `mtpi` instructions, which fetch and store through the
previous mode's mapping, that of the user; the ARM has their exact
counterparts in `ldrt` and `strt` and their byte forms, which load and
store with the permissions of user mode even when executed by the
kernel. A user address which is not mapped, or which only the kernel
may touch, faults, just as `mfpi` trapped on a missing segment.

The fault is caught, in v7's way, through `nofault` (269). Each routine
first stores there the address of `uerr` (229); if one of its user
references faults, the data abort handler (#f("low.s")) finds `nofault`
set and returns, not to the faulting instruction, but to `uerr`, which
clears `nofault` and returns -1. A routine which completes clears it at
`uok` (225) and returns its value. Only these routines set `nofault`,
so any other fault in the kernel is still a `panic`. `r3` holds the
address of `nofault` throughout, and the abort restores the registers
as they were at the fault, so `uerr` finds it there.

`fubyte` and `fuword` return the byte or word at a user address, or -1;
`subyte` and `suword` store one, and return 0 or -1. The byte is loaded
without sign extension, whatever the signedness of `char`. The loaded
value goes first into `r1` (159, 175): a load which wrote back to its
own base register would be unpredictable, and the `t` forms always
write back. v7 distinguished `fuibyte` from `fubyte`, instruction space
from data space; #f("systm.h") makes the former names aliases of these.

`copyin(from, to, n)` and `copyout` move `n` bytes from a user address
to a kernel one, and back, and return 0, or -1 if any user reference
faults. As v7's did, they move words when both addresses and the count
are multiples of the word (195--199, 214--218), and bytes otherwise
(200--204, 219--223). Only the user side of each move uses the `t`
form.

#lines(155, 234)

`idle` is v7's, in ARM form. Interrupts are enabled, and `wfi` ("wait for
interrupt") halts the processor until one arrives, as the PDP-11's
`wait` did. The interrupt is taken at once, and the PC it saves is that
of the instruction after `wfi`, labelled `1` (238). Its address is
stored in `waitloc` (264, 265), which `clock` (#f("clock.c")) compares
with the interrupted PC to count the time spent idle. `idle` must
therefore be the last routine in the file to have a label `1`, which
`1b` finds by searching backwards. v7's `idle` restored the previous PS
on the way out; this one simply masks interrupts again, which suits
both callers, `swtch` and `panic`: the one loops at `spl6` and the
other loops forever.

#lines(235, 240)

`savfp` and `restfp` store and load the floating point state of the
current process, as v7's did for the PDP-11's floating point processor.
On the ARM the state is the status and control register `FPSCR`, which
holds the rounding mode and the cumulative exception flags, and the 32
double registers `d0` to `d31`, which the Advanced SIMD instructions
share. `vmrs` and `vmsr` move `FPSCR`; `vstmia` and `vldmia` move
sixteen registers each, the most one instruction allows. The layout is
that of `u_fps` (#f("user.h")): `FPSCR` in the first word, and the
registers from byte 8, where the alignment of a `double` puts them. v7's
routines first tested `fpp` for the presence of the hardware, and passed
registers 4 and 5 through register 0, which its store instructions could
not reach directly; here both machines have the unit (#f("low.s")) and
every register is stored directly. `FPEXC` needs no saving, since the
unit stays enabled. v7's `stst`, which fetched the code of a floating
exception, has no counterpart: the unit of the Cortex-A7 takes no trap
on an arithmetic exception, so `SIGFPT` is never sent, and a program
finds what happened in the cumulative flags of `FPSCR`.

#lines(241, 254)

`dfar` and `dfsr` return the data fault address and status registers,
which describe the last data abort. `user_trap_handler` (#f("sysent.c"))
prints them before it panics on a fault in kernel mode, much as v7's
`trap` printed the memory management status registers it had copied into
`ssr`.

#lines(255, 262)

`waitloc` is a word of initialised data holding the address of the
label in `idle`, as `_waitloc` was in v7. `nofault` is the word which
v7 also kept in `mch.s`, zero except while a user reference is made.

#lines(263, 271)

`kl3u` is the third-level table which maps the top 2 MB of the
address space, page by page; of its 512 entries only the two at
`UBASE` are used, rewritten by `resume` at each switch. `machine_init`
hooks it into the last entry of `kl2` (#f("low.s")). It is aligned on
4 KB, as every table of the long format must be, and placed in a section
of its own, `.ddrbss`, which the clearing loop in #f("low.s") does not
touch. On the MP135 machine the kernel itself lives in SYSRAM, and this
section is put in the DDR memory, which cannot
be used until `machine_init` has initialised its controller; that
routine clears the section afterwards.

#lines(272, 275)
#source("/usr/sys/sys/main.c")

#f("main.c") holds the procedure through which the kernel passes exactly
once, while it brings itself up, together with two initialisation
routines for the file system and the buffer cache which it calls.

On the PDP-11 the path to `main` began in `l.s` and `mch.s`, which set
up the kernel segmentation registers, placed the per process data area
of process 0 just above the end of the kernel, cleared the bss, and
turned memory management on. The ARM path is similar. `_start` in
#f("low.s") disables the MMU and caches, clears the bss, maps the
kernel at its kernel addresses, enables the MMU, sets a provisional
stack, and installs the vectors; it then calls `machine_init`
(#f("machdep.c")), which completes the kernel's mapping. Only then is
the stack pointer moved to the top of the per process data area of
process 0, at `UBASE`+8192, and `main` called.

`iinit` and `binit` are declared (13) because `main` calls them before
their definitions below. v7 needed no such line, since its compiler took an
undeclared function to return `int`; C99 does not allow the call.

The definitions at 14--36 are new. v7 defined these variables in the
headers themselves, in #f("systm.h") and, for `mpxip` (36), in
#f("inode.h"), and relied on the linker to merge the copies which each
including file made. The headers now declare them `extern`
(#f("systm.h") gives the reason), and each is defined here, once. `rootdev`, `swapdev`, `pipedev`, `swplo`, and
`nswap` are not among them, because the configuration file
#f("qemu/c.c") defines them with their values; nor are the maps and the
mount table, which v7's `main.c` defined, since their sizes are now
part of the configuration too (#f("param.h")). v7's `cputype` is gone
(#f("systm.h")).

The comment above `main` lists its work. Its first item reads "free
user core" (44), where v7's read "clear and free user core", since
`startup` no longer clears core (#f("machdep.c")).

#lines(1, 53)

`startup` (58) sets aside the page tables of the processes, frees the
rest of core outside process 0, and initialises the block device.

#lines(54, 58)

`p_addr` of process 0, set at line 63, is the click at which its per
process data area begins. v7 read it from the kernel segmentation
register `KISA6` (`ka6`), whose value `mch.s` had chosen. Here
`machine_init` has already mapped the first `USIZE` clicks of core, at
`corebase`, at `UBASE`, so the click is that of `corebase`.

The remaining fields of `proc[0]` (64--69) are as in v7: the process
occupies only its `USIZE` clicks, is runnable, is in core, and is never
to be swapped. `u` and `proc[0]` are linked through `u_procp`.

#lines(59, 70)

`clkstart` (76) now does rather more than start the clock: it also
programs the interrupt controller and is the point at which interrupts
are first allowed (#f("machdep.c")). Everything which follows may
therefore sleep: `iinit` waits for the disk.

`rootdir` and the current directory of process 0 are obtained as
separate references to the root inode; each `iget` returns it locked,
and the lock is released at once (81, 83).

#lines(71, 85)

`newproc` (92) makes process 1 as a copy of process 0 and returns zero
to the parent, which falls through to `sched` (103) and never comes back.
Process 1 eventually resumes in `newproc` with a value of one, and
takes the branch.

#lines(86, 92)

The image is first enlarged to hold `icode`: `btoc(szicode)` is one
click, so the image becomes the u-area and one page.
`estabur` (#f("ureg.c")) then checks the size and calls `sureg`, which
maps the page into the user window at virtual address 0, and
`copyout` writes `icode` (#f("machdep.c")) through that mapping, to
user address 0.

`arm_sync_icache` (96) is new. The ARM, unlike the PDP-11, has
separate instruction and data caches which are not kept coherent by the
hardware: the instructions just stored may sit in the data cache, and
stale lines may sit in the instruction cache. The routine (#f("mch.s"))
writes the copied bytes back from the data cache, through the kernel's
own address for them, then discards the instruction cache and the branch
predictor.

#lines(93, 96)

`main` then returns to `_start` (#f("low.s")), which, as v7's `start` did
with `rtt`, sets the saved status register to user mode and jumps to
location 0. Process 1 begins to execute `icode`.

#lines(97, 104)

`iinit` opens the root device, reads its super-block (block 1,
`SUPERB`), and copies it into a buffer which is never released, the
first entry of the mount table. The super-block's time of last
modification becomes the initial time of day, until `date` or
`stime` corrects it.

#lines(105, 136)

The buffers themselves (146), defined, as their number now is, by the
configuration (#f("qemu/c.c")). v7 declared each as `BSIZE+BSLOP`, i.e.
514, bytes of `char`. With 514 bytes every second buffer would start on
an address which is only two-byte aligned, and the DMA engine of the SD
card controller of the MP135 machine requires a word-aligned buffer
address; the odd buffers would be corrupted on transfer. Alignment on
a word is not enough either. The same DMA bypasses the data cache,
whose lines on the Cortex-A7 are 64 bytes, and the driver must clean
and invalidate the lines a buffer occupies (#f("stm32sd.c")); a line
shared with the neighbouring buffer, which the processor may be
changing meanwhile, would be written back over the new data, or
discarded with the neighbour's changes. Each row is therefore rounded
up to a multiple of 64 bytes, 576, and made of `int`s, so that the
array is at least aligned for `int`. Rounding alone would align the
rows only relative to the start of the array, which C places where it
will; `binit` therefore moves every buffer up by the same amount, less
than 64 bytes, to bring the first, and with it all the rest, onto a
64-byte boundary (165). The configuration provides one row more than
`NBUF` (#f("mkconf.c")), so that the last buffer still fits. The casts
at 165 are the price.

#lines(137, 147)

`binit` links every buffer into the free list through `brelse`, then
makes each block device's queue (`d_tab`) an empty circular list, and
counts the block devices in `nblkdev`. The scan of `bdevsw` ends at
the first entry without an open routine, the null entry with which
#f("qemu/c.c") closes the table.

#lines(148, 181)
#source("/usr/sys/sys/machdep.c")

In v7, #f("machdep.c") collected those parts of the machine-dependent
code which could be written in C: the bootstrap program `icode`,
`startup`, `clkstart`, `sendsig`, and the routines for the UNIBUS map
of the 11/70, which are gone with the map; the ARM's devices address
all of memory. The assembly language remainder lived in `mch.s`. The
port keeps
v7's procedures in v7's order, rewriting their bodies for the ARM, and
appends a second half which does the work that `mch.s` did on the
PDP-11 with the help of the memory management unit: building the
kernel's page tables, copying and clearing clicks, returning from a
signal, and reading memory for `/dev/mem` and `/dev/kmem`.

The whole port rests on one arrangement of the ARM MMU, which it is
best to describe before the code. The PDP-11/45 divided the 64 KB user
address space into eight segments of up to 8 KB, each described by an
address register (`UISA`) and a descriptor register (`UISD`); the
kernel had a second set of registers, and its own seventh segment was
pointed by `KISA6` at the per process data area of the current process.
The ARM, in the long-descriptor format which the port uses
(#f("low.s")), likewise translates the address space through two
tables: the low three gigabytes, 0 to `USERSIZE`, through the table in
`TTBR0`, and the top gigabyte through the table in `TTBR1`. The port
uses them thus (@ch-startup gives the addresses):

- The top gigabyte is the kernel's. Its table, `kl2`, maps the kernel
  image, the whole of core, and the device registers by 2 MB blocks,
  once, at boot, and never changes. Kernel addresses are not physical
  addresses: each region is mapped at the address its `map` line in
  the configuration gives (#f("qemuconf")). This is the counterpart of
  v7's kernel segments 0 to 5, which never changed. User mode may not
  touch any of it.

- The last entry of `kl2` points to `kl3u`, whose entries at `UBASE`
  map the per process data area of the current process. `resume`
  (#f("mch.s")) rewrites them on every switch, exactly as v7's `resume`
  reloaded `KISA6`. Hence `u` is always at `UBASE`.

- The low three gigabytes are the user's. Each process has its own
  first-level table, of four entries, and the tables below it which its
  image needs, built by `sureg` (#f("ureg.c")) from the process's
  sizes and its place in core. A process switch loads `TTBR0` with the
  new process's table, as v7's `sureg` loaded `UISA` and `UISD`.

A process image in core keeps v7's form: `USIZE` clicks of per process
data area at `p_addr`, then the data, then the stack, packed together.
In the user's address space the data begins at the bottom, and the
stack ends at the top, at `USERSIZE`, with a gap between them which is
not mapped. Each grows towards the other: the data by `sbreak`
(#f("sys1.c")) and the stack by `grow` (#f("sig.c")), and each growth
enlarges the image in core. Since every page is mapped separately, and
tables exist only where something is mapped, the gap costs nothing.

`conf.h` is included (12) for `struct intr`, the table of device
interrupts which `clkstart` and `irq` use.

#lines(1, 13)

`icode` is the first user program, copied by `main` (#f("main.c")) to user
address 0 of process 1. In v7 it was eleven words of PDP-11 machine
code assembled by hand into octal. The ARM version is ten words of
hand-assembled ARM code, in hexadecimal, and the comment now says so.

#lines(14, 20)

The first four words perform `exec("/etc/init", initp)`. The arguments
are passed in `r0` and `r1` and the system call number (11) in `r7`;
`svc` replaces the PDP-11's `sys` (`trap`) instruction, whose low byte
carried the number. `exec` (#f("sys1.c")) takes two arguments and
supplies the null environment itself, so nothing is put in `r2`.
Should the `exec` fail, the program loops on the branch to itself (25),
as v7's did, and the system goes no further.

#lines(21, 25)

`initp`, the argument vector `{init, 0}`, follows at offset `0x14`,
and then the string `/etc/init`, stored little-endian, at `0x1c`, in
v7's order. Because the program is loaded at address 0, its own
offsets serve as addresses, and both fit the 8-bit immediate field of
`mov`.

#lines(26, 32)

v7's `startup` found the size of core by experiment: it slid a user
segment through physical memory a click at a time until a reference
failed, clearing each click and freeing it into `coremap` as it went.
On the ARM the limits of core are known and nothing is probed:
`machine_init` (below) has set `corebase` to the physical address of
the first page after the kernel and its tables, and the configuration
(#f("qemu/c.c")) gives `coretop`. Both are physical addresses, since
click numbers are.

#lines(33, 45)

Core begins with the `USIZE` clicks of the per process data area of
process 0 (see `main`), as v7 began at `*ka6 + USIZE`. Two new
reservations follow it. The first-level user tables, 32 bytes for each
slot of the process table, take the next clicks (47--51); `l1tab` is
their kernel address, through which `sureg` writes them, and `l1pa` the
physical one, which `TTBR0` needs. The click number is converted to
`unsigned` before `ctob` shifts it (48): on the MP135 machine core lies
above 0xC0000000, and the shift of a signed `int` past the largest
`int` would be undefined. They are cleared, so that every
process starts with an empty address space. The next `NPTAB` clicks
(52, 53) are the pool from which `sureg` takes the lower tables, freed
into `ptmap` as v7 freed core into `coremap`. The rest of core is freed
(54, 55). Core is no longer cleared here; `machine_init` clears the
area of process 0, and `exec` (#f("sys1.c")) clears each image it
builds, so the v7 comment (43) now says only "free".

As in v7, `maxmem` (54) is first the amount of core, which is printed
(56), and is then limited to `MAXMEM` (#f("param.h")), the largest image
a process may have (57, 58). `estabur` (#f("ureg.c")) refuses any image
larger than `maxmem`.

#lines(46, 58)

The swap area (59, 60) is set up as in v7.

v7 ended `startup` by pointing user segment 7 at the I/O page.
Its place is taken by `bdinit` (61), which #f("qemu/c.c") defines to call the
block driver's initialisation routine. This must come before
`clkstart`, since the `virtio` driver only learns its interrupt number
when it probes the device.

#lines(59, 62)

`sysphys`, system call 52, let the super-user map a piece of physical
memory, such as device registers, into a segment of his address space.
v7's recorded the segment in `u_uisa` and `u_uisd` and called `sureg`.
The prototype which replaces them describes only text, data, and stack
(#f("user.h")), and has no place for a physical segment. The body is
therefore replaced: the super-user is refused with `EINVAL`, the error v7 gave
for a request it could not satisfy, and anyone else, as in v7, with the
error of `suser`.

#lines(63, 75)

Hence to the clock. The PDP-11 had a line clock (KW11-L) or a
programmable clock (KW11-P) on the UNIBUS, each with its own interrupt
vector and priority; v7's `clkstart` tried one, then the other, and
set its interrupt enable bit. On the ARM every device interrupt reaches
the processor through a single line from the Generic Interrupt
Controller (GIC), whose distributor (`gicdbase`) and processor interface
(`giccbase`) registers are reached through `GICD` and `GICC` (81, 82).
The clock is the processor's own generic timer: interrupt 27 (`TIMER`)
is the private interrupt of its virtual timer.

`intrtab` (84) is generated by `mkconf` in #f("qemu/c.c"): for each
configured device, a pointer to the variable holding its interrupt
number and the routine to call. A pointer, rather than the number,
because some numbers are not known until the driver has probed its
device.

`gicen` (90) gives interrupt `n` a middling priority (0x80) in the
distributor's byte-per-interrupt priority array at `0x400`, then sets
its bit in the set-enable registers at `0x100`.

#lines(76, 95)

`clkstart` first reads `CNTFRQ` (101), which gives the frequency of the
system counter. `clkreload` is the number of its counts in `1/HZ`
second, and `clkrem` (103) what the division leaves over, which
`clock` (#f("clock.c")) adds in so that the ticks keep exact time. A
frequency below `HZ` (the register is set by firmware) is the one
remaining way to "find no clock".

It then enables the timer and every configured device interrupt whose
number is known (104--107); enables the distributor, lets interrupts of
every priority through the processor interface (the priority mask
register at 4), and enables the interface (108--110); and sets the
timer's first deadline, `clkreload` counts after the present value of
the counter, and starts it (111, 112). `clkcval` (85) keeps the
deadline, from which `clock` computes the next.

Only then (113, 114) may interrupts be taken. `spl0` (#f("mch.s")) unmasks
interrupts only when `irq_ready` is set, so any earlier call, as from a
driver, leaves them masked while the GIC
is still unprogrammed. Since `main` calls `clkstart` before `iinit`,
the read of the root super-block is already driven by interrupts.

#lines(96, 115)

`irq` is new. It is called from `irq_entry` (#f("low.s")) with a pointer to
the saved registers of the interrupted program, in the layout of
#f("reg.h"), and with interrupts masked; it plays the part of v7's
`call` in `mch.s` together with the PDP-11's vectored interrupts.

Reading the acknowledge register (`0xc`) at line 123 yields the number of
the highest priority pending interrupt, in its low ten bits, and marks
it active.

For the timer (124, 125), call `clock` (#f("clock.c")), which sets the
next deadline. v7's `clock` took seven arguments, the words of the
PDP-11 interrupt frame, but used only the program counter and the
processor status; those two are all that are passed now. The status is
reduced to `UMODE` if the interrupted program was in user mode (mode
bits `0x10`) and zero otherwise. `main` has set up process 0 before it
calls `clkstart`, so `clock` always finds a current process.

Otherwise (126--129), call the routine of the device whose number
matches. A spurious interrupt (1023) matches nothing.

Writing the same value to the end-of-interrupt register (`0x10`) at
line 130 retires the interrupt.

All interrupts share one level. The PDP-11's priorities have collapsed
into "masked" and "unmasked", and until the end of interrupt is written
the controller delivers no other interrupt, even to a handler which
unmasks the IRQ, as `clock` does with `spl1` (#f("clock.c")). After
that, an IRQ left unmasked, or unmasked again for the call of
`user_trap_handler` in the tail of `irq_entry` (#f("low.s")), lets a
second interrupt in before the first frame is unloaded. It nests
as any interrupt of the kernel does: its frame goes below the first,
and the `r5` saved in it, which carries the first entry's `lr`, is
restored before the first entry uses it.

#lines(116, 131)

`sendsig` arranges for the signal handler at `p` to be called when the
process next returns to user mode. On the PDP-11 it pushed the
processor status and program counter onto the user stack and set the
program counter to the handler, simulating an interrupt; the handler
(in fact a stub in the C library) ended with `rtt`, which popped both.
The ARM has no user-mode instruction which can restore the status
register from memory, and the C calling convention lets the handler
clobber `r0` to `r3`, `r12`, and the condition flags, so the whole
register frame must be saved and a system call is needed to restore it.
The floating point state is saved with it: the handler may compute in
floating point, and the program it interrupted, stopped at any
instruction, needs every register back, its status register `FPSCR`
included. v7 saved none of it, and a handler which used floating point
could disturb the program it interrupted.

#lines(132, 140)

`n` (142) is the user stack pointer less the size of the frame,
rounded down to a multiple of 8 as the ARM calling convention requires.
The frame is the registers, `m` bytes (141), 17 words: `r0` to `r15`
and the status register, followed by `u.u_fps` (#f("user.h")), where
`psig` (#f("sig.c")) has just stored the floating point registers.

First `grow` (#f("sig.c")) is asked to extend the stack to cover the
frame (143), as in v7: the stack segment holds only what the process has
used so far, and the frame may lie below it. The frame is then copied
out (144--149), the registers and then the floating point state, with
`copyout` (#f("mch.s")), which fails if any part of it lies outside the
process's memory. If the frame cannot be written,
the process is sent `SIGSEG`, with its handler first reset to the
default so that it is not caught in turn.

#lines(141, 149)

The stack pointer is then lowered past the frame; the link
register, `u_ar0[14]`, for which #f("reg.h") has no name, is set to the
trampoline at `UENTRY_SIGTRAMP` (see `install_sigtramp`, 298); the
program counter (`R7`, which in #f("reg.h") is `r15`) to the handler; and
`r0` to the signal number, the handler's argument. v7 also cleared the
trace bit in the saved status, so that a traced process would not trap
on the handler's first instruction; the ARM status register has no
trace bit. What is cleared instead (154) is the Thumb state: the `T`
bit (5), the `IT` bits (10 to 15, 25, and 26), which make the next
instructions of a Thumb `if-then` block conditional, and the `E` bit
(9), big-endian data. Every program here is compiled to ARM code, but
the compiler's support library `libgcc`, which supplies the 64-bit
division `__aeabi_ldivmod` and its relatives, is the Thumb build, so a
signal may well interrupt Thumb code. The handler is ARM code and must
be entered in ARM state, with no `if-then` block pending.

When the handler returns, it returns to the trampoline, with the stack
pointer at the frame, and the trampoline issues `sigreturn` (235).

#lines(150, 156)

The remainder of the file is new.

`board_map` (157) comes from #f("qemu/c.c"): the regions which the
machine's configuration file asks to be mapped, each with its kernel
address, its physical bounds, and the attribute bits of its block
descriptors. The `__` symbols (158) are defined by the linker script.
`.ddrbss` is a second, uninitialised data section: on the MP135 machine
the kernel image runs from SYSRAM, and the large tables are placed in
the DDR memory, which is useless until it has been set up. On the QEMU
machine it is ordinary memory. The tables (159) are reserved in
#f("low.s") and #f("mch.s").

`msgbufp` (160), the pointer into the circular buffer of console
output read by `dmesg`, was defined in v7's console driver `kl.c`. It
is here because either of two console drivers may be configured
(#f("pl011.c") or #f("stm32usart.c")), and both use it.

`kmap` enters the regions of `board_map` into the kernel's table
`kl2`, 2 MB at a time: those of device registers if `dev` is set, the
others if not. The entry for a kernel address is its block number, the
address shifted right by 21, less the 0x600 blocks below 0xc0000000,
which the mask (171) takes away. The attributes, spelled `BLK_KERN` and
`BLK_DEV` in the configuration files, are defined in #f("seg.h"):
kernel memory is normal, cacheable, and accessible only from the
kernel; device memory is device memory, never executable, and likewise
closed to user mode. Since entries which were invalid are made valid,
no stale translation can exist; `tlbflush` (#f("mch.s")) is called all
the same, since a region may be entered twice, as the kernel's own is.

`vtop` (176) is the inverse of the kernel's mapping: it finds the
region of memory which holds a kernel address, and returns the physical
address. A device which reads or writes memory by itself (the virtio
disk of the QEMU machine, the SD card controller of the MP135 machine) must be
given physical addresses, and its driver calls `vtop` on each buffer.
This is the counterpart of v7's `b_xmem` and of the arithmetic by which
v7's drivers turned a segment and an offset into the 18-bit address of
the UNIBUS. A device region has no physical memory behind it, and an
address found in no region is an error.

#lines(157, 188)

`machine_init` is called from `_start` (#f("low.s")), running at its
kernel address on a small stack in the bss, with only the kernel image
mapped. It first maps the device registers and initialises the console
(195, 196), so that `printf` and `panic` work from here on.

On the MP135 machine it then starts the DDR controller
(`clock_ddr_init` is empty on the QEMU machine). Only then are the other regions mapped (198), the
DDR memory among them: a mapping of memory which does not yet work
would invite the processor to touch it speculatively. `.ddrbss`, which
`_start` could not clear, is cleared (199, 200).

Core begins at the first page boundary after `.ddrbss`, the last part
of the kernel to be placed (#f("qemu/unix.ld")). On the QEMU machine
that is just past the kernel image; on the MP135 machine, whose kernel
runs from SYSRAM, it is just past the tables in DDR. Neither needs to be
stated in the configuration, which gives only the top of core.
`corebase` is the physical address (202), and `coreoff` (201) the
difference between the kernel and physical addresses of all of core,
which lies in one region; `CLKADDR` (#f("seg.h")) adds it to turn a
click into a kernel address.

The `USIZE` pages of the per process data area of process 0, the first
of core, are entered in `kl3u` at `UBASE` (203, 204), with the attributes
of a kernel page, as in `resume` (#f("mch.s")), and `kl3u` is hooked
into the last entry of `kl2` (205), which covers the top 2 MB of the
address space; no region of `board_map` reaches so high. The identity
mapping of `bootl1` (#f("low.s")) is removed (206): from here on
nothing below `USERSIZE` is mapped but the user's. The area of process 0
is then cleared (208, 209); v7's `start` did the same for process 0.

The address returned (210) is the top of the u-area, where #f("low.s")
puts the kernel stack.

#lines(189, 211)

`copyseg` and `clearseg` copy and clear one click, a page of 1024
words. In v7 they were in `mch.s`, and had to borrow a user segment to
reach a physical click; here core is mapped into the kernel's own
address space, and `CLKADDR` (#f("seg.h")) converts a click number to a
pointer. The routines which move data between the kernel and the user,
`fubyte`, `copyin`, and the rest, are in #f("mch.s"), as they were in
v7.

#lines(212, 232)

`sigreturn`, system call 63, undoes `sendsig`. It is called by the
trampoline, at which point the user stack pointer addresses the saved
frame.

#lines(233, 240)

The frame is copied in through `copyin`, which fails unless it lies in
the process's memory; a bad stack pointer earns `SIGSEG`. The floating
point part goes straight to `u.u_fps`, and `u_fpsaved` (248) makes the
return to user mode load it (#f("sysent.c")). A forged `FPSCR` can do
no harm: it holds nothing but the user's own modes and flags.

#lines(241, 248)

`r0` to `r15` are restored (249, 250).

Of the saved status register (251), only the condition flags (bits 27
to 31), the `GE` flags (16 to 19), and the Thumb state that `sendsig`
cleared (the `T`, `IT`, and `E` bits) are taken; the mode is set to user
mode, `0x10`, with the interrupt masks `A`, `I`, and `F` clear. A forged
frame therefore cannot return the process to the processor in a
privileged mode, nor with interrupts masked, while a signal which
interrupted Thumb code, in the middle of a 64-bit division, say,
returns to it in Thumb state and inside its `if-then` block.

`trap` (#f("sysent.c")) will store `r_val1` and `r_val2` into
`r0` and `r1` as the results of this system call; setting them to the
saved values (252, 253) makes the return restore those two registers too.

#lines(249, 254)

`fumem` and `sumem` serve the memory special files (#f("mem.c")) one byte
at a time, in the role that `fuibyte` and `suibyte`, with a user segment
pointed at physical memory, played in v7's `mem.c`.

`memaddr` translates a file offset to a kernel address. For `/dev/kmem`
(minor 1) the offset is a kernel address; for `/dev/mem` (minor 0) it
is a physical address, which is moved into the kernel's addresses by
the difference between them (269). Two stretches of memory may be read:
the kernel image, from `_start` to the end of `bss`, and everything from
`.ddrbss` to the top of core, which on both machines lie in one region
each; `/dev/kmem` may also read the u-area of the current process at
`UBASE` (262). Anything else returns -1, and the driver sets `ENXIO`:
in particular the device registers, whose reading could have effects,
and the reserved parts of the 2 MB blocks.

#lines(255, 295)

`install_sigtramp` writes the two-instruction signal trampoline,
`sigreturn` by `svc`, at user address 8 (#f("seg.h")). `xalloc`
(#f("text.c")) calls it while the text it has just read in is still
mapped writable, so that the trampoline becomes part of the shared
text. The stores go through `suword` (#f("mch.s")), with the
permissions of user mode.

`panictrap` is the target of the vectors which should never be taken
(#f("low.s")).

#lines(296, 308)
#source("/usr/sys/h/proc.h")

A process is represented in two places. Its `proc` structure, one
element of the array `proc` (31), stays in memory throughout the life
of the process and holds what the system must know about it even
when the rest of it is on the swap device: whether it is in memory,
where it is, why it sleeps, and the information that scheduling and
signals need. The rest of the process state, the `user` structure
(#f("user.h")), lives at the bottom of the process's own memory image
and is swapped with it.

`p_stat` (10) takes one of the values on lines 34 to 39; a zero entry
is free. `p_flag` (11) is a set of the bits on lines 42 to 48.

`p_pri` (12) is the scheduling priority, recomputed by `setpri`
(#f("slp.c")) from `p_cpu` and `p_nice`, or set by `sleep` to the
priority given for the event. A smaller value is more urgent, so the
comment's "negative" means the highest of all. `p_time` and `p_cpu`
are kept in a `char`, and `clock` stops each at its maximum so that
it cannot wrap.

`p_sig` (16) is the set of pending signals, one bit each, the bit for
signal _n_ being 1 shifted left _n_-1. v7 kept it in a `short`, the
sixteen bits of which held its sixteen signals; it is now an `int`, for
the 31 signals which `NSIG` (#f("param.h")) allows. `xp_sig` (63), its
counterpart in `struct xproc` below, is widened with it, so that the
fields after it still lie where `proc`'s do.

`p_addr` (21) and `p_size` (22) locate the image. When `SLOAD` is set,
`p_addr` is a click number, the physical address divided by 4096
(`CLKADDR`, #f("seg.h")); otherwise it is a block number on the swap
device. `p_size`
is in clicks in both cases, and includes the `USIZE` clicks of the
`user` structure and kernel stack, which come first.

`p_addr` has been widened from `short` to `int`. On the PDP-11, whose
largest memory was 4 MB, a click number fitted in sixteen bits. Here
the MP135 machine's memory lies above 0xc0000000, at click numbers
beyond 786432, and a swap address can exceed 65536 as well
(#f("qemuconf")). `p_size` is bounded by `maxmem`, which is at most
`MAXMEM` (#f("param.h")), 32768 clicks, one more than a `short` holds;
it has been widened too.

`p_ptab` and `p_nptab` (23, 24) are new: the first click and the number
of the pages of user page tables which the process holds while it is in
core, taken from the pool by `sureg` and given back by `ptfree`
(#f("ureg.c")). `p_nptab` is zero while the process has none, as after
it has been swapped out, created, or moved in core.

`p_wchan` (25) is the address on which a sleeping process waits;
`wakeup` compares it with its argument. `p_textp` (26) points to the
shared text segment, which every program has (#f("text.c")); only
process 0, and process 1 while it runs `icode`, have none. `p_link` (27) chains the runnable processes
into the list headed by `runq` (#f("systm.h")): `setrq` (#f("slp.c")) adds a
process to it, and `swtch` searches it for the most urgent one that is
in memory. `p_clktim` (28) counts down the seconds of an `alarm`.

#lines(1, 32)

`SWAIT` is listed but never set by v7 itself. `SIDL` covers the brief
time in `newproc` while a child is being copied, and `SZOMB` the time
between `exit` and the parent's `wait`.

#lines(33, 40)

`SLOAD` is the bit which decides how `p_addr` is to be read. `SSYS`
marks process 0, which is never swapped. `SLOCK` holds a process in
memory temporarily: while it is being swapped out, while its text is
read in, and while `physio` transfers directly to or from its image.
`SSWAP` marks a process whose image was written to the swap area from
the middle of `newproc`, `expand`, or `xexpand`, so that `swtch` (#f("slp.c"))
resumes it through `u_ssav` rather than `u_rsav`. `SULOCK` holds a
process in memory at the user's request, through the `lock` system call
(`syslock`). `STRC` and `SWTED` serve `ptrace`.

#lines(41, 49)

When a process exits, its image is released, but its `proc` entry
lingers in the `SZOMB` state until the parent collects it with
`wait`. At that point the entry must carry the exit status and the
times used, which no field of `proc` provides. `exit` (#f("sys1.c")) casts
the `proc` entry to an `xproc` and stores them in place: the first
eleven fields coincide, and the new ones overlay `p_addr` and the
fields after it, which are now meaningless.

The overlay works only if `xproc` is no larger than `proc`. With
`p_addr` now four bytes, `xp_xstat` covers half of it, the two
`time_t`s, eight bytes each, are aligned to offset 24, and `xproc` ends
at 40 bytes, inside the 52 bytes of a `proc` entry. The times thus lie
over `p_size`, `p_ptab`, `p_nptab`, and `p_wchan`. None of these means
anything in a zombie, but two are read again when the entry is reused,
so `wait` (#f("sys1.c")) clears them as it frees it: `p_wchan`, as in
v7, and `p_nptab`, without which `ptfree` (#f("ureg.c")) would hand the
system time of the dead process to `mfree` as a number of page tables.

#lines(50, 71)
#source("/usr/sys/h/user.h")

The `user` structure is the second half of the description of a
process, the half that can be swapped. It sits at the base of the
process's image in memory, followed by the kernel stack of the
process, the two together occupying `USIZE` clicks (#f("param.h")): the
"per process data area". Only the data area of the current process is
addressable, always at the same kernel address, and the kernel calls
it `u`. To switch processes is, at bottom, to change which data area
appears there.

The opening comment is v7's. `USIZE` is now two clicks of 4096 bytes,
8 KB, rather than 16 of 64, and the comment gives the new unit; the
block appears at virtual address `UBASE`, 0xFFF00000, which the
comment now gives in place of v7's 0140000. That address was
the start of the seventh kernel segment, and v7
switched processes by reloading that segment's address register
(`ka6`). The port maps the window through its own third-level page
table, `kl3u` (#f("mch.s")), which covers the top 2 MB of the kernel's
address space. `resume` writes the physical address of the new
process's data area into that table and discards the old translations,
after which the same virtual addresses show the new `u`.

`EXCLOSE` (15) is the bit of `u_pofile` (56) which marks a file to be
closed by `exec`.

#lines(1, 16)

`u_rsav` (19) holds the registers saved by `save` (#f("mch.s")) when the
process gives up the processor in `swtch`, and restored by `resume`.
`label_t` now has ten words: r4 to r11, the stack pointer, and the link
register, the registers which the ARM procedure call standard requires
a callee to preserve.

The floating point fields (20--25) are v7's. `u_fps` holds the state
of the floating point unit while the process is not using it: the
status register `FPSCR` in `u_fpsr`, and the registers in `u_fpregs`,
of which the ARM has 32 to the PDP-11's 6. `u_fpsaved` says that the
hardware registers have been stored here, and must be reloaded before
the return to user mode. `trap` and `user_trap_handler` (#f("sysent.c"))
clear it on entry; `swtch`, `newproc`, and `expand` (#f("slp.c")),
and `psig` (#f("sig.c")) store the registers and set it whenever another
process may take the unit or the u-area may be copied; and the return to
user mode reloads them if it is set. Since the registers are saved only
when they must be, a process which makes a system call and continues
pays nothing for them. `exec` clears the area, `ptrace` permits writes to
it, and a core file, which begins with the u-area, carries it. `u_fper`,
v7's floating error code, is unused (#f("mch.s")).

#lines(17, 25)

`u_segflg` (26) tells `iomove` and its relatives where `u_base`
points: 1 for kernel space, 0 or 2 for user data or text. Since the
I-space routines are aliases of the D-space ones (#f("systm.h")), 0 and 2
now mean the same. `u_error` is the error number that a system call
returns. The four user and group ids follow, effective and real.
`u_procp` (32) links back to the process's `proc` entry, and `u_ap`
points to the arguments of the current system call.

`u_r` (34) holds the one or two values that a system call returns. In
v7 the structure inside the union had no member name: the old C
compiler kept all structure member names in a single table, and
`u.u_r.r_val1` was accepted although the union had no member called
`r_val1`. C99 requires a name. The structure is now the member
`u_pair` (38), and the two macros (42, 43) let the many statements
which write `u.u_r.r_val1` remain as v7 wrote them. `r_time` fills both
words of the pair, as it did on the PDP-11; the union is therefore
aligned on eight bytes.

#lines(26, 43)

The parameters of an I/O transfer, which `readi`, `writei`, and the
drivers consume: `u_base`, `u_count`, and `u_offset`. After them come
the current and root directories, and the working storage of `namei`
(#f("nami.c")): the current component of the path name, a pointer into
the name, a copy of the directory entry, and the parent directory.

#lines(44, 52)

In v7, `u_uisa` and `u_uisd` held the prototypes of the sixteen PDP-11
user segmentation registers, which `estabur` computed and from which
`sureg` loaded the hardware (#f("ureg.c")). The ARM's mapping needs a
smaller prototype: the sizes, in clicks, of the text, the data, and the
stack to be mapped (53), and the access rights of the text, `RO` or
`RW` (54). `u_ofile` (55) is the
table of open files, indexed by file descriptor. `u_arg` (57) receives
the arguments of a system call from the saved registers r0 to r3;
no call takes more than four. `u_tsize`, `u_dsize`, and `u_ssize` (58--60)
are the sizes, in clicks, of the three parts of the user image.

#lines(53, 60)

`u_qsav` (61) is the label to which `sleep` returns when a signal
interrupts a system call; `trap` sets it on every call. `u_ssav`
serves `expand` and the swapping code, which may need to resume a
process at the point where its image was copied. `u_signal` (63) holds, for each
signal, zero for the default action, one to ignore it, or the address
of a catching routine; an `int` holds an address on the ARM, as it did
on the PDP-11.
The four times are counted in clock ticks.

`u_ar0` (68) points to the user's registers as saved on the kernel
stack on entry to the system. The frame in the port holds r0 to r14,
the program counter, and the status register, and #f("reg.h") gives the
index of each in the frame. `u_prof` holds the parameters of the
`profil` system call. Its structure has been given the tag `uprof` so
that `addupc` (#f("clock.c")), which v7 wrote in assembler, can be declared
to take a pointer to it and read the fields by name. `u_ttyp` and `u_ttyd` (77, 78) name the
controlling terminal.

#lines(61, 78)

`u_exdata` (79) is the header of the program being executed, read by
`getxfile` (#f("sys1.c")). In v7 it was the eight-word `a.out` header.
The executables here are in ELF, the Executable and Linkable Format,
and the structure has been rearranged to
hold the pieces of an ELF file which the kernel needs. Its first 52
bytes overlay the ELF file header. The fields that the kernel reads have
names; the rest are fill:

- `ux_mag` (80) receives the four identifying bytes, `\x7fELF`, which
  read as a little-endian word are 0x464c457f.
- `ux_entloc` (82), the entry point, and `ux_phoff` (83), the file
  offset of the program header table, fall at the offsets of the ELF
  fields `e_entry` and `e_phoff`.
- `ux_phnum` (85) is the number of program headers.

`ux_ph` (86--89) then receives two program headers, or rather their
first six fields: type, file offset, virtual address, physical address,
size in the file, and size in memory. `getxfile` fills it with the two
loadable segments of the program: the text, read-only and executable,
and the data, which the linker places in separate pages
(#f("Makefile")). This is the ELF form of v7's 0410 executable, whose
text was shared and read-only. The remaining two fields of a program
header are not needed.

v7's `ux_tsize` and `ux_dsize`, the sizes of the text and the
initialised data, which the kernel still names, are now macros (91,
92) for the sizes in the file of the two segments. `ux_bsize`,
`ux_ssize`, `ux_unused`, and `ux_relflg` have gone. The data's size in
memory includes the uninitialised data, as v7's `ux_bsize` added it;
since the image is cleared before the segment is read in, that part
reads as zero without further work.

#lines(79, 92)

`u_comm` (93) is the last component of the name of the program, for
accounting and `ps`; `u_start` and `u_acflag` are also for accounting.
`u_cmask` (97) is the `umask`.

`u_stack` (98) marks the end of the structure. The kernel stack begins
at the top of the data area, 0xFFF02000, where #f("low.s") sets the
supervisor mode stack pointer, and grows down towards it. Nothing but
the size of the area guarantees that it does not reach the structure.

#lines(93, 103)

In v7, `u` was an external variable (105). Its address was fixed not
by storage but by the assembler line `_u = 140000` in `mch.s`, which
made `_u` an absolute symbol. The port does the same with one line of
the linker script, `u = 0xFFF00000`, which `mkconf` writes
(#f("qemu/unix.ld")): `u` is the `struct user` at `UBASE`, and every
reference to it is to that fixed address, as in v7. A program which
includes #f("user.h") for the structure may still name a variable of
its own `u`, as `ps` does.

#lines(104, 106)

The error numbers which a system call may return in `u_error`. The
user sees them in `errno`. They are unchanged from v7.

#lines(107, 141)
#source("/usr/sys/sys/ureg.c")

#f("ureg.c") contains the procedures through which the rest of the
system controls a process's user address space. `estabur` validates
the sizes of the text, data, and stack of a new or changed image and
records them as a _prototype_ in the `user` structure. `sureg` loads the
hardware from the prototype, adding the physical address of the image;
it is called whenever the image may have moved: by `estabur`, by
`newproc` and `expand` (#f("slp.c")), by `xexpand` (#f("text.c")), and
when a process is resumed in `swtch`.

The division of labour is v7's, and so is the shape of the address
space. On the PDP-11 the prototype was a set of sixteen segmentation
registers, `u.u_uisa` and `u.u_uisd`, eight segments of up to 8 KB
each, and `estabur` had to fit the text, the data, and the stack into
them, round each up to whole segments, and mark the stack as growing
downward. On the ARM every 4 KB page has its own entry, so the
prototype is simply the three sizes and the text's access rights
(#f("user.h")): the text occupies the bottom of the address space, the
data follows it, and the stack ends at `USERSIZE`.

The hardware, however, is no longer a set of registers. It is a tree of
tables in memory (#f("low.s")): a first-level table of four entries,
each covering a gigabyte; for each gigabyte in use, a second-level
table of 512 entries, each covering 2 MB; and for each 2 MB in use, a
third-level table of 512 page entries. The first-level tables live in
`l1tab` (10, 11), one for each slot of the process table, set aside by
`startup` (#f("machdep.c")). The others are built in pages from the
pool, and are kept from one switch to the next, as the PDP-11 kept the
prototype; a switch only points `TTBR0` at the process's table.

#lines(1, 12)

`ptbuild` makes the tables of the current process `p`. The text is
found at the core address of the shared text segment, if there is one,
and the data and stack in the process's own image (26--28), as in v7's
`sureg`.

The text and the data occupy `n` pages from address 0 upwards; they
need one second-level table for each gigabyte they reach (30) and one
third-level table for each 2 MB (31). The stack, which ends at
`USERSIZE`, needs one third-level table for each 2 MB (32) and, if it is
not empty, one second-level table, for the third gigabyte. `estabur`
ensures that text and data stay within the first two gigabytes and the
stack within the third. A process with nothing mapped, such as process
0, needs no tables at all (34).

The pages are taken from the pool as one run (36). If the pool is
exhausted, the process is killed, as `xalloc` (#f("text.c")) kills one
for which no `text` entry remains; its first-level table stays empty,
so that any reference to its address space faults. With `NPTAB`
(#f("param.h")) pages, this happens only when many large processes are in
core at once.

The run is cleared, and laid out in order: the second-level tables of
the low gigabytes, their third-level tables, the second-level table of
the stack's gigabyte, and its third-level tables. An entry which points
to a table holds its physical address and the type `PTE_TAB`
(#f("seg.h")). Consecutive tables of a level are consecutive in memory,
so the 512-entry tables may be treated as one longer array: the low
third-level tables are entered in the second-level tables from their
first entry (50, 51), and the text and data pages in the third-level
tables from their first (53--58). The text pages carry the access
rights of the prototype; the data pages, from `USIZE` clicks into the
image, are read and write.

The stack's tables are entered at the top of their second-level table
(63, 64), and its pages at the top of its third-level tables, mapped
upward from the page after the data (65--67), so that the last page of
the image is the last page below `USERSIZE`. The attributes other than
the access rights come from the configuration (`pguser`,
#f("qemuconf")); among them is "not global", which lets `ttbset`
(#f("mch.s")) discard the user's translations alone.

#lines(13, 68)

`ptfree` returns a process's tables to the pool and empties its
first-level table. It is called whenever the tables no longer describe
the image: by `estabur` when the prototype changes, by `expand`
(#f("slp.c")) when the image moves, by `xswap` (#f("text.c")) when it
leaves core, and by `exit` (#f("sys1.c")). The first-level table is
emptied even when there were no tables, so that a slot of the process
table always begins with an empty address space.

#lines(69, 84)

`sureg` builds the tables of the current process if it has none, and
loads them with `ttbset` (#f("mch.s")), which also discards the
previous process's translations. At a process switch, the usual case,
the tables already exist and only `TTBR0` changes; after the process
has been created, swapped in, or moved, or its sizes have changed, they
are built afresh. A text in core never moves while a process which uses
it is in core, so the tables of a process need never change because of
another.

#lines(85, 101)

`estabur` makes v7's two checks. Separate instruction and data spaces
(`sep`), which the PDP-11/40 lacked and v7 refused there, cannot be had
on the ARM either (118, 119). The text, data, and stack must fit the
address space as the tables are arranged, as v7 required them to fit
its eight segments (120): text and data in the first two gigabytes, the
stack in the third, so that they never overlap. `ctos`
(#f("param.h")) counts a segment of one click, and `PTPGB`
(#f("seg.h")) is the number of pages in a gigabyte. And the image,
with its per process data area, must not exceed `maxmem` (122, 123),
which `startup` (#f("machdep.c")) has limited to `MAXMEM`. The sum is
cast to `int` for that comparison, because `maxmem` is an `int`: C99
would otherwise compare the two as unsigned, as v7 did, and the
compiler would warn of it. The test at line 120 has already bounded the sum, so
the cast cannot make it negative.

The prototype is then recorded (124--127), the old tables are released,
and new ones built and loaded. Callers ask for a mapping before the
image itself has changed: `grow` and `sbreak` check the new sizes
before they call `expand`, and `xalloc` (#f("text.c")) asks for the text
alone, writable, while it reads the text in. Between the call and the
change the mapping may name pages which the image does not yet have,
but nothing touches them until `expand` has moved the image and built
the tables again.

#lines(102, 135)
#source("/usr/sys/sys/slp.c")

#f("slp.c") is the heart of process management. It holds the procedures
by which a process gives up the processor (`sleep`, `swtch`), by which
another makes it runnable again (`wakeup`, `setrun`), the calculation of
user priorities (`setpri`), the scheduler proper (`sched`, `swapin`),
and the two procedures which create or move a process image in memory
(`newproc`, `expand`). Apart from the C99 dressing and a few additions
for the ARM, described below, the file is v7's, and it is the clearest
place to see that the port changed the machine under the system rather
than the system itself.

Everything here turns on the pair `save` and `resume` (#f("mch.s")),
which switch between processes. `save(lab)` stores in the `label_t` `lab` the registers
which a called procedure must preserve, together with the stack pointer
and the return address, and returns zero. `resume(a, lab)` makes the
process image at click address `a` the current one, by mapping its
per-process area at the fixed address of `u`, then reloads the registers
from `lab` and returns one, as though from the corresponding `save`. The
pair is thus the kernel's `setjmp` and `longjmp`, with an exchange of
address spaces thrown in. In the PDP-11 version `save` kept r2 to r5 and
the stack pointer, and `resume` reloaded the kernel segmentation register
`KDSA6`; on the ARM `save` keeps r4 to r11, the stack pointer, and the
link register, and `resume` rewrites the entries of the third-level page
table `kl3u` which map `u` and then discards their translations.

Since `lab` always lies within `u`, and `resume` reads it only after the
new process has been mapped, it is the incoming process's copy of the
label which is used (#f("mch.s")); the comment at line 421 says as much.

The declaration of `swapin` (12) is new. `sched` (240) calls it before
its definition, as `printf` calls `printn` (#f("prf.c")); no other file uses it, so the declaration is here and not in #f("systm.h").

A process sleeps on a _channel_: an address which by convention stands
for the event awaited, such as that of the buffer or inode concerned.
Processes which sleep are kept on `SQSIZE` short lists, chained through
`p_link`. `HASH` (15) picks the list from the address of the
channel. The cast to `int` may now give a negative number for a kernel
address with its top bit set, but the mask removes the sign.

#lines(1, 17)

`sleep` records why (`chan`) and how urgently (`pri`) the current process
waits, puts it on the appropriate sleep list, and calls `swtch`.

The processor priority is raised by `spl6` (36), which on the ARM masks
the IRQ (#f("mch.s")), so that no interrupt handler can call `wakeup`
while the proc entry and the list are half changed. The repeated test
of `chan` (41) is v7's.

#lines(18, 46)

If `pri` is above `PZERO`, the sleep may be broken by a signal.
A signal already pending (48) cancels the sleep before it has begun.
Otherwise, if `sched` is waiting on `runin` for a sleeping process to
swap out (56), it is roused, since this process is now such a candidate.
After `swtch` returns, the signal test is repeated (61): a signal is one
of the events which may have ended the sleep, by way of `setrun`.

#lines(47, 68)

A signal is handled by abandoning the system call altogether.
`resume` to `u.u_qsav` with the process's own address is a non-local
goto: control reappears in `trap` as a second return from the
`save(u.u_qsav)` made there before the system call routine was entered,
and `trap` reports `EINTR`. The comment's "trap1/trap.c" refers to v7's
`trap.c`; in this system `trap` is in #f("sysent.c").

Note that callers of `sleep` above `PZERO` are therefore never told that
they were interrupted; any locks they hold must be such that the
abandoned system call leaves nothing inconsistent.

#lines(69, 79)

`wakeup` walks the one list on which processes sleeping on `chan` may
be, unlinks each such process, clears its channel, and hands it to
`setrun`. Several unrelated channels may hash to the same list, hence
the test of `p_wchan` (96). Since `p_link` is reused by `setrun` to put
the process on the run queue, the successor is taken (100, 102) before
`setrun` is called.

#lines(80, 112)

`setrq` adds a process to the run queue `runq`, a list chained through
the same `p_link`: a process is either asleep or runnable, never both.
The search for a duplicate is purely diagnostic, as the comment admits.

`setrq` is now `static`, since only #f("slp.c") calls it; this spares it
a declaration in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand.

#lines(113, 136)

`setrun` is called from interrupt routines, from `wakeup`, and from
places such as `psignal` which wish to rouse a process whatever it is
waiting for. In the last case the process is still on a sleep list, and
`wakeup` of its channel (153) is the correct way to take it off. The
doubled parentheses at 153 are those of #f("malloc.c").

#lines(137, 158)

If the newly runnable process is more urgent than the current one,
`runrun` asks for a call of `swtch` at the next opportunity, which is the
return from a trap or interrupt to user mode. If `sched` is idle (161)
for want of a runnable swapped-out process, and this is one, `sched` is
woken.

#lines(159, 165)

`setpri` computes the priority with which a user process will compete:
`PUSER`, plus a share of recent processor use (`p_cpu`, which `clock`
increments each tick and decays each second), plus the bias `p_nice`.
The result is never above 127, so that it fits in the `char` `p_pri`.

The `0377` mask (178) undid the sign extension of a PDP-11 `char`. On
the ARM `char` is unsigned and the mask changes nothing, but it is
harmless and is v7's.

The reader may be puzzled that `runrun` is set (182) when the process
whose priority was just computed is better than `curpri`, whereas that
process may not be the current one. `clock` calls `setpri` for every
user process once a second, and it is precisely when one of these has
become more deserving than the running process that a switch is wanted.

#lines(166, 186)

`sched` is the endless loop of process 0, entered from `main` after
`newproc` has made process 1. It moves images between core and the
swap area: it chooses the runnable swapped-out process which has been
out longest (219--224), weighted by `p_nice`, and tries to bring it in.
If there is none, it sleeps on `runout` (230), to be roused by `setrun`
or by `xswap` (#f("text.c")).

If there is no room for the chosen process (240), a victim is sought:
first the largest process sleeping at a priority from which a signal
could rouse it, or stopped by tracing (260); failing that, the process
which has been longest in core. The victim is swapped out only if the
first kind was found, or if the process to be brought in has waited 3
seconds and the victim has had 2 (279); otherwise `sched` sleeps on
`runin`, which `clock` wakes each second, `sleep` (56) when a
candidate appears, and `mfree` (#f("malloc.c")) when core is freed.

The parentheses added in (260) make explicit v7's reliance on `&&`
binding more tightly than `||`, of which `gcc` warns otherwise; the
meaning is unchanged. The same change appears throughout the system.

If the swap area has no room for the victim, `xswap` returns zero
(281), where v7 panicked. The victim keeps its core, `SLOAD` is set
again (283), and `sched` sleeps on `runin` as though no victim had been
found, to try again when `clock` or `sleep` wakes it. The process
waiting to come in waits longer; nothing else is disturbed.

On the PDP-11 this code was in constant use. Here memory is ample, and
in practice the first search always fails or `swapin` succeeds; the
code is kept intact all the same, together with the swap area which
`fork` insists upon.

#lines(187, 289)

`swapin` allocates core for the data area and, if the process has a
shared text segment not yet in core, for the text as well; reads both
in; and releases the swap space. It returns zero, having undone its
allocations, if either `malloc` fails.

A text read back from the swap area is new to the instruction cache, which
may hold stale lines for the same memory; `arm_sync_icache`
(#f("mch.s")) is called on it, as in `xexpand` (#f("text.c")). The
include of #f("seg.h") (11), for `CLKADDR`, is for that call. The
doubled parentheses at 305 are those of #f("malloc.c").

#lines(290, 328)

`qswtch` gives up the processor without sleeping: the current process
is put back on the run queue and `swtch` is called. `trap` uses it when
`runrun` is set.

#lines(329, 341)

`swtch` chooses the next process to run and runs it. It works in three
stages and involves, in general, three
processes: the one giving up the processor, process 0, which always
acts as an intermediary, and the one taking it over.

#lines(342, 362)

Unless the caller is process 0 itself, its state is saved in
`u.u_rsav` and process 0 is resumed at `u.u_qsav`. The zero return from
`save` (364) continues on the second branch; the nonzero return comes
much later, when this process is chosen again, and then `sureg`
re-establishes its user mappings before `swtch` returns to its caller.

Before process 0 runs, and through it another process, the floating
point registers are stored in the u-area unless that has already been
done since this process entered the kernel (#f("user.h")). The kernel
itself never touches them, so they still hold this process's values;
the next process to return to user mode loads its own.

#lines(363, 373)

The double `save` (385) is explained by its comment. The point to grasp
is that `u.u_qsav` in process 0 marks the entrance to the search loop:
every switch passes through it by the `resume` of (372).

#lines(374, 387)

With interrupts masked, the run queue is searched for the
loaded runnable process of best (lowest) priority, and that process is
removed from the queue. If there is none, `idle` waits for an interrupt
and the search is repeated. On the PDP-11 `idle` executed `wait`; here
it unmasks the IRQ and executes `wfi`.

#lines(388, 419)

The incoming process is resumed at `u.u_rsav` unless it has
`SSWAP` set (423), in which case it is resumed at `u.u_ssav`. The flag is set
by `newproc` (541), by `expand` (587), and by `xexpand` (#f("text.c")),
all of which made an image of a process (on the swap area or in fresh
core) after doing `save(u.u_ssav)`. In such an image `u.u_rsav` is stale:
it was recorded by some earlier switch, or, in `expand`'s case, by the
call of `swtch` from `qswtch` (588), after the image had already been
written. Hence the explicit choice of label.

Note that the ARM `resume` masks interrupts while the mapping and
registers are changed and, like the PDP-11 version, which ended at
priority zero, unmasks them again with `spl0` once the new stack is in
place (#f("mch.s")).

v7 called `spl0` here, before `resume`, after `curpri` was set. The call
is gone, so that interrupts stay masked from the search through to the
point in `resume` where the new stack pointer is loaded. The reason is
the compiler. The call of `resume` is the last statement of `swtch`, and
GCC makes it a tail call: it pops `swtch`'s own stack frame, the saved
registers and the return address, and then branches to `resume`. In
process 0 that frame is not dead, for `u.u_rsav`, which `swtch` saved
in it (385), still points at it: when process 0 is itself chosen, it
returns from `swtch` through the very words just popped. An interrupt
taken between the pop and `resume`'s masking would push its register
frame over them, and process 0 would later return through the frame's
saved status word as though it were an address. With interrupts masked
nothing can be pushed there.

#lines(420, 426)

`newproc` is the body of `fork`, and of the creation of process 1 by
`main`. It returns 1 in the new process and 0 in the old.

#lines(427, 447)

A process id is chosen which is in use neither as a process id
nor as a process group, cycling below 30000. At the same time the first
empty slot of `proc` is noted. `fork` (#f("sys1.c")) has already made
sure that one exists.

#lines(448, 466)

The new entry is filled in, and the reference counts of
everything the child will share with its parent, its open files, text,
and current and root directories, are incremented.

#lines(467, 495)

The child's image is a copy of the parent's, `u` included, made after
the parent has done `save(u.u_ssav)` (515). Before the copy,
`u.u_procp` is set to the child's entry (502), so that the copy differs
from the original in that one respect; the parent restores it (538), and
loads its own page tables again (539), for the reason given below.

The floating point registers are stored in the parent's u-area just
before (507--510), so that the copy holds them, with `u_fpsaved` set,
and the child loads them on its first return to user mode
(#f("sysent.c")), whichever process has used the unit since. v7 did not
store them here, and its child took whatever the registers held when it
first ran, usually, but not always, its parent's values.

When the child is first chosen by `swtch` its `SSWAP` flag (541) causes
it to be resumed at `u.u_ssav`; its `save` returns 1, and `newproc`
returns 1 to `fork`. The child's kernel stack, being part of `u`, is
copied with the rest, and since `u` always appears at the same virtual
address the stack pointer in the label remains valid. The child has no
page tables yet, since `exit` or `xswap` released those of the slot's
previous occupant; the `sureg` which follows its `save` builds them
(#f("ureg.c")).

A word on C. The compiler does not know that `save` may return twice,
since it is declared as an ordinary function. This is safe because, in
every use in this file, the second return reads no local variable: it
calls `sureg` and returns a constant. The registers which the callers
higher up the stack expect to find preserved were pushed on that stack
before `save` was reached, and are still there when it returns again.

#lines(496, 524)

If there is no core for the copy (525), the parent's image is written
to the swap area as the child's image, without freeing the core
(`xswap` with second argument zero). `rpp->p_addr` is pointed at the
parent's core for the purpose, and `SIDL` keeps the parent from being
chosen for swapping in the meanwhile. While `xswap` waits for the
write, the parent sleeps and is resumed in `swtch` as the child, for
`u.u_procp` names the child's entry: the `sureg` there builds page
tables in the child's slot, mapping the parent's core, and loads them.
`xswap` frees them once the image is written (#f("text.c")), and the
`sureg` at (539) points the processor back at the parent's own tables.
The value of `xswap` is not tested here: it cannot be zero, because
`fork` has just found swap space for an image of this size
(#f("sys1.c")), and nothing has slept since. Otherwise (534) the image is
copied, a click at a time, by `copyseg` (#f("machdep.c")). On the PDP-11
`copyseg` had to borrow a user segmentation register to reach physical
memory; here the kernel maps all of memory, and `CLKADDR` turns a click
number into an address.

The copy is of the whole image, as in v7: the per process area, the
data, and the stack, which is no more than the program has asked for
(`getxfile`, #f("sys1.c")). A small program's image is a few clicks.

#lines(525, 543)

`expand` changes the size of the current process's image to `newsize`
clicks. A shrinking image simply gives back its tail (570). A growing
one is copied into a new area (593), after which `resume` (596)
switches to the copy, whose `save` (573) then returns 1. The comment's
"taking care to reset registers" is a PDP-11 relic in effect: since `u`
and the kernel stack always appear at the same virtual address, the
copy needs no adjustment, and `resume` only has to remap `u` to the new
area. The page tables of the old image are released first (591), and
`sureg` builds new ones for the copy (#f("ureg.c")). A shrinking image
keeps its tables: the caller has already set the new sizes with
`estabur`, whose tables no longer reach the tail given back.

If there is no core (578), the image is written to the swap area at its
old size `n` but with `p_size` already set to the new one, the old core
is freed, and the process gives up the processor with `SSWAP` set. The
floating point registers are stored in the u-area first (579--582),
since the copy on the swap area is the one which will come back, and
`swtch` would store them only after it had been written; v7 omitted
this. When
`sched` brings it back, `swapin` allocates the larger size, and the
process resumes at `u.u_ssav` (573) and returns from `expand` as if
nothing had happened. Note that until `swtch` resumes another process it
goes on running in core which is already free; nothing can reallocate
it in that interval, since no interrupt routine allocates core.

If there is no swap space either, `xswap` fails (583), and v7 panicked.
Now `p_size` is set back, the image is left as it was, and `expand`
returns zero; it returns one in every other case (571, 575, 597, the
last unreached, since `resume` does not return). The callers decide:
`sbreak` (#f("sys1.c")) fails with `ENOMEM`, and `grow` (#f("sig.c"))
fails, so that the fault which wanted more stack becomes `SIGSEG`;
both are refusals of a request, as when an image would exceed
`maxmem`. Only `exec` cannot refuse, because the process has already
given up its old image: it is killed, with the message "out of swap
space", as v7 kills a process for which the text table has no room
(#f("text.c")). Of the ways to survive, these change least: the process
which asked is the only one affected, and v7's own ways of failing are
used.

#lines(544, 598)
