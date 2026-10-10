#set page(width: 6in, height: 9in, margin: (x: 0.75in, y: 50pt), header-ascent: 18pt)
#set text(size: 10pt)
#let running = context {
  let p = here().page()
  let k = p - locate(<main>).page() + 1
  let n = str(k)
  let here-p(h) = h.location().page() == p
  if query(heading.where(level: 1)).any(here-p) {
    if calc.even(k) { n } else { align(right, n) }
  } else if calc.even(k) {
    let sec = query(heading.where(level: 1).before(here())).last()
    n + h(1fr) + emph(numbering("1", ..counter(heading).at(sec.location())) + h(1em) + sec.body)
  } else {
    let on = query(heading.where(level: 2)).filter(here-p)
    let sub = if on.len() > 0 { on.first() } else { query(heading.where(level: 2).before(here())).last() }
    emph(sub.body) + h(1fr) + n
  }
}
#set raw(tab-size: 8)
#show heading: set block(below: 1em)
#show heading.where(level: 1): it => { pagebreak(weak: true); it }
#set heading(numbering: "1")
#show heading.where(level: 2): set heading(numbering: none)
#let first = state("first", 1)
#show raw.where(block: true): set text(size: 6.8pt)
#show raw.where(block: true): it => {
  show raw.line: l => context box(width: 3em, align(right, text(fill: gray, str(l.number + first.get() - 1)))) + h(1em) + box(width: 1fr, l.body)
  it
}
#let file = state("file", "")
#let text-of(path) = read(path).trim("\n", at: end).split("\n")
#let lines(a, b) = context {
  first.update(a)
  raw(text-of(file.get()).slice(a - 1, b).join("\n"), block: true, lang: "c")
}
#let source(path) = { file.update(path); [#heading(level: 2, path)#label(if path.ends-with("/c.c") or path.ends-with(".ld") or path.starts-with("/usr/src/") { path.split("/").slice(-2).join("/") } else { path.split("/").last() })] }
#let f(name) = link(label(name), raw(name))
#let listing(path) = { source(path); lines(1, text-of(path).len()) }

#align(center)[
  #v(4cm)
  #text(size: 24pt, weight: "bold")[#text(size: 22pt)[UNIX]#text(weight: "regular")[#sym.dagger] Level Seven]
  #v(0.5em)
  #text(size: 16pt)[Source Code and Commentary]
  #v(2em)
  #text(size: 12pt)[Jakob Kastelic]
  #v(3cm)
]

Unix, the greatest operating system ever created, served tens of thousands of
users with a kernel that fit in under 100 kB of core. This repository aims to
bring the Seventh Edition kernel up to date with C99 to run on hardware
available nowadays.

#v(1em)
*References*

- Ritchie, Dennis M., and Ken Thompson. "The UNIX Time-Sharing System."
  _Communications of the ACM_ 17, no. 7 (1974): 365--375.
- Lions, John. _A Commentary on the Sixth Edition UNIX Operating System._
  Department of Computer Science, University of New South Wales, 1977.
- Bach, Maurice J. _The Design of the UNIX Operating System._ Prentice-Hall,
  1986.

#place(bottom + left)[
  #line(length: 1in, stroke: 0.5pt)
  #v(-0.4em)
  #text(size: 9pt)[#sym.dagger;UNIX is a Trademark of Bell Laboratories.]
]
#pagebreak()
#show outline.entry.where(level: 1): set block(above: 1.4em)
#show outline.entry.where(level: 1): set text(weight: "bold")
#block(below: 1.2em, text(size: 1.4em, weight: "bold")[Contents])
#columns(2, outline(title: none))
#pagebreak()
#set page(numbering: "1", header: running, footer: [])
#counter(page).update(1)
#metadata(none) <main>

= Startup and Processes

The system described here runs on two machines, and the book names them
throughout as follows.

*The QEMU machine* is the `virt` machine of the QEMU emulator (version
10.0), configured with a single ARM Cortex-A7 processor. It has 64 MB
of memory at address 0x40000000, a GIC version 2 interrupt controller at
0x08000000, the ARM generic timer, a PL011 serial line at 0x09000000 as
the console, and a virtio block device, found among the virtio
"MMIO" slots at 0x0a000000, as the disk. QEMU loads the kernel into
memory itself and starts it at its entry point; the disk is a file on
the host, made by `mkfs` from the prototype `boot/rootfs.proto`.

*The MP135 machine* is STMicroelectronics' STM32MP135F-DK, a small
board built around the company's STM32MP135F system-on-chip. The chip
contains one ARM Cortex-A7 processor running at up to 1 GHz, 128 KB of
on-chip memory (SYSRAM) at 0x2ffe0000, and the controllers below; the
board adds 512 MB of DDR3L memory, at 0xc0000000, and an SD card slot. The console is the chip's UART4 at
0x40010000, the disk is the SD card on its SDMMC1 controller at
0x58005000, and the interrupt controller is again a GIC version 2, at
0xa0021000. The chip's boot ROM reads the kernel from the SD card into
SYSRAM and starts it; the kernel must then bring up the DDR memory
itself (#f("stm32ddr.c")) before it can use it.

The Cortex-A7 implements the ARMv7-A architecture: sixteen 32-bit
registers, a status register `CPSR`, separate processor modes for user
programs and for each kind of exception, and a memory management unit
which maps virtual addresses through page tables in memory. The
equivalents of the PDP-11's `spl` routines (which set the processor
priority, and so mask interrupts), segmentation registers, and trap
vectors are described where the code uses them: in #f("low.s"),
#f("mch.s"), and #f("machdep.c"). The differences between the machines,
the addresses above in particular, are confined to the configuration
files of Section 6 and to the drivers, one set for each machine. Main memory
is called _core_ throughout, as v7 called it after the magnetic core
memories of its day.


#source("/usr/sys/h/map.h")

A resource map is a list of the free areas of some resource. Each
element gives the size of one area and the address of its first unit,
both measured in whatever unit suits the resource. The system keeps two
such lists, one for main memory and one for the swap area, and both are
managed by the two procedures of #f("malloc.c"), which do not need to
know which resource they are handling. Main memory is measured in
_clicks_ of 64 bytes, the granule in which the PDP-11's memory
management unit allocated memory, and in which v7 counts all of core;
the swap area is measured in 512-byte disk blocks.

The fields were `short` and `unsigned short` in v7, so that an address
could reach 65536 clicks (four megabytes of core) or as many swap
blocks, and a size half as far. Both machines have more memory than
that: core is counted in clicks from `corebase` (#f("seg.h")), and the
64 megabytes of the QEMU machine amount to a million clicks; the MP135
machine has eight times as many. Both fields are therefore `int`.
`m_addr` is signed, although an address is never negative, because
`malloc` and `mfree` (#f("malloc.c")) take and return an `int`; no map
is large enough for the sign to matter.

#lines(1, 5)

The two maps themselves follow: `coremap` for main memory and `swapmap`
for the swap area. Their dimensions, `CMAPSIZ` and `SMAPSIZ`, come from
#f("param.h"), which must therefore be included first.

In v7 these two lines defined storage, not merely declared it, and the
header is included by six files. Each file therefore contained its own
definition of `coremap` and `swapmap`, and the PDP-11 loader merged
such uninitialised definitions into one, as the Unix loaders always
had. C99 allows an object only one external definition, so the lines
now declare the arrays `extern`, and #f("main.c") defines them, once.
The same was done for the variables of #f("systm.h").

#lines(6, 8)
#source("/usr/sys/sys/malloc.c")

This file holds the two procedures which manage a resource map
(#f("map.h")): `malloc` takes an area out of the free list and `mfree`
puts one back. They know nothing of the resource itself. The same code
hands out core to processes and to texts (the read-only instructions of
a program, shared by every process running it) in units of 64-byte clicks
(`swapin`, `newproc`, and `expand` in #f("slp.c"), `xexpand` in
#f("text.c")) and swap space in units of 512-byte disk blocks (`xswap`
and `xalloc` in #f("text.c"), and `exece` in #f("sys1.c"), which
borrows swap to hold its argument list).
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

Neither procedure checks for the end of the array. `CMAPSIZ` and
`SMAPSIZ` (#f("param.h")) are 50 while `NPROC` is 150, as in v7; it is
assumed that memory never becomes fragmented into fifty pieces.

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
begins at address zero. For core, `startup` (#f("machdep.c")) frees
memory from click `64+USIZE` up; for swap, it frees the map starting
at block 1 and decrements `swplo` (the first block of the swap area on
its device) to compensate, so that block zero of
the swap area is never named.

#lines(31, 35)

The comment calls the address `aa`, a name the parameter no longer has;
v7 left the comment so.

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

In v7 `putchar` belonged to the console driver, and so it does in the port: it is
defined in #f("pl011.c") under QEMU, and in `stm32usart.c` on the
STM32MP135; each board's kernel links only its own driver. Either waits,
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

`register c` (31) becomes `register int c`, since C99 has no implicit
`int`. The doubled parentheses at line 49 are explained in
#f("malloc.c").

The reader may wonder at `%D` (51). On the PDP-11 `int` had 16 bits
and `long` 32, and a block number or a byte count needed `%D`. Here
both have 32 bits, so `%D` and `%d` print the same; it is kept because
the callers use it.

The other numeric conversions fetch their argument as `unsigned` (46).
v7 converted it to `long`, which on the PDP-11 widened 16 bits to 32
and could never produce a negative value; `%d` of $-1$ printed 65535,
which is what the comment means by "`%d` (==`%u`)". Here `unsigned` and
`long` are the same size, and the conversion turned any value of $2^31$
or more negative: an address of `0xc0101234`, in the STM32MP135's
memory, printed as `-3FEFEDCC`. The cast is gone and `printn` now takes
an `unsigned long`, so the value arrives intact. `%d` of $-1$ prints
4294967295, as the comment promises.

#lines(16, 55)

`printn` produces the digits of `n` in base `b` by printing the higher
digits, `n/b`, recursively, and then the lowest. The recursion ends
because each call divides by at least 8; a 32-bit number has at most
eleven octal digits.

v7 began with a test for a negative number, which "shouldn't happen"
and on the PDP-11 could not. On ARM it did, by the conversion described
above, and for $-2^31$ the negation overflowed, the remainder (67) went
negative and the digit string was indexed out of bounds. With `n`
unsigned, as the comment (58) always said, the test could never succeed
and is removed. `%D` of a negative `long` would now print as a large
unsigned number; no caller passes one.

The doubled parentheses at line 65 are again those of #f("malloc.c").

#lines(56, 68)

`panic` is the system's response to a state it cannot repair. It
records the message, writes out what it can, prints, and stops.

First `update` (#f("alloc.c")), at line 80, writes the super-blocks, the modified
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
The port's two disk drivers pass a single status value and a zero:
#f("virtio_blk.c") the status byte returned by the virtual device,
`stm32sd.c` the status register of the SD controller.

#lines(98, 112)
#source("/usr/sys/h/param.h")

#f("param.h") is the first file which nearly every kernel source file
includes, and most of the other `.h` files assume that it has been
included before them. It reserves no storage, with the single exception
noted below (146), but defines the constants and simple types upon
which the remainder of the system is built. As elsewhere in UNIX,
defined constants are written in upper case only.

The file falls into six parts: the tunable parameters, the priorities,
the signals, the "fundamental constants", some conversion macros and
types, and finally a few machine-dependent definitions.

These are the parameters which an installation may reasonably alter.
Most of them fix the dimensions of tables which are allocated
statically, once and for all, when the system is compiled: `NBUF` for
the buffer cache, `NINODE` for the in-core inodes, `NFILE` for the open
file table, `NPROC` for the process table, and so on. Doubling `NPROC`
costs space in every system, whether the processes exist or not.

`MAXMEM` (9) is expressed in units of 64 bytes ("clicks"); the comment
recalls that 32 clicks made one thousand PDP-11 words. Its only use now
is in `fork` (#f("sys1.c")), which insists that the swap area could hold a
process of this size before it allows a new one to be made.

`HZ` (21) is the number of clock interrupts per second. The PDP-11 took
its clock from the mains frequency; here the ARM generic timer is
programmed to interrupt `HZ` times each second (`clkstart`, #f("machdep.c")).

The local time zone (22, 23) is compiled into the system. This is why
`date` reports Eastern time unless the kernel is rebuilt.

#lines(1, 26)

Priorities for processes which `sleep`. The lower the value, the more
urgent the process: `PSWP` is the most urgent of all. A process which
sleeps at a priority of `PZERO` or less cannot be disturbed by a
signal; one which sleeps above `PZERO` may be, and will then return
from the system call prematurely. The reader will find this
distinction tested in `sleep` (#f("slp.c")).

#lines(27, 42)

`NSIG` is one more than the number of signals, since signal zero means
"no signal". The pending signals of a process are kept as bits in
`p_sig` (#f("proc.h")), and v7 allowed sixteen, the bits of a PDP-11
word. `p_sig` is now an `int`, and `NSIG` has been raised from 17 to 32:
31 signals, as many as a 32-bit word holds without its sign bit, which
`1<<(sig-1)` must not reach. The comment (50, 51) has been changed to
match. Only v7's fifteen signals have names; the others may be sent,
caught, and ignored by number.

#lines(43, 68)

`NBPW` (74), the number of bytes per word, is no longer the constant 2
but `sizeof(int)`, which is 4.

A disk block holds 512 bytes. Since a block number (`daddr_t`, 129)
occupies four bytes on both machines, an indirect block holds 128 block
numbers (`NINDIR`), and `NMASK` and `NSHIFT` are unchanged.

`USIZE` (83) is the size, in clicks, of the "per process data area":
the `user` structure followed by the kernel stack. It has grown from 16
clicks (1024 bytes) to 128 clicks (8192 bytes), because a thirty-two
bit kernel stack is larger. `UBASE` (84) is the address at which the
data area of the current process always appears, so that the kernel may
refer to it simply as `u`.

A character list ("clist") is built of blocks, each holding a pointer
to the next block and `CBSIZE` (94) characters. With a four byte
pointer, 12 characters (rather than 14) keep each block 16 bytes long,
and `CROUND` remains 017 as the comment demands.

#lines(69, 96)

The conversion macros. A click is 64 bytes: the granule of the PDP-11
memory management unit. The ARM unit maps pages of 4096 bytes, but the
system still counts memory in clicks, 64 to a page.

#lines(97, 127)

`ino_t` is `unsigned short`, so that an inode number still occupies two
bytes in a directory entry on the disk (#f("dir.h")). `label_t` has ten
words, to hold registers r4 to r11, the stack pointer, and the link
register, which are saved by `save` (#f("mch.s")); the comment, which in v7
spoke of the PDP-11's registers 2 to 7, now says so.

#lines(128, 136)

These describe the PDP-11 processor status word, and survive because
`clock` (#f("clock.c")) examines its argument `ps` with them. The ARM has no
such word to offer; `irq` (#f("machdep.c")) instead passes `UMODE` if the
interrupted program was in user mode, and zero otherwise. Hence
`BASEPRI` is always false.

#lines(137, 144)

The one declaration of variables in the file. The addresses which
differ between the two boards (the kernel, the start and end of user
memory, the interrupt controller) are defined in the #f("qemu/c.c") which
`mkconf` generates for each board.

#lines(145, 146)
#source("/usr/sys/h/systm.h")

#f("systm.h") is the kernel's collection of global variables and,
in our port, of declarations for the procedures which more than one
file calls. In v7 it held only the former, together with a handful of
function declarations, mostly for routines which return pointers;
every other routine was declared implicitly by its first
call. Strict C99 has no implicit declarations, so the file has grown
from 81 lines to 176, nearly all of the growth being one long list.

In v7 none of the variables was declared `extern`, except those
defined in assembler or in some particular file (`regloc`, `icode`,
`szicode`, `sysent`). Every file which included the header therefore
emitted a "tentative definition" of each, and the linker merged them
into a single zeroed copy: the old common-block convention of the UNIX
linker. C99 permits one external definition of an object in the whole
program, and modern compilers no longer merge by default. Every
variable is therefore now declared `extern`, and defined once:
`rootdev`, `swapdev`, `pipedev`, `swplo`, and `nswap` with their values
in the configuration file #f("qemu/c.c"), as in v7; `msgbufp` in
#f("machdep.c"); the rest in #f("main.c"), except `lks`, which nothing
uses. Since the array sizes (6, 41) come from
#f("param.h"), that file must be included first.

`cputype` (9) is never assigned on the ARM and so remains zero. The
tests of it in `sureg` (#f("ureg.c")) and `mapalloc` (#f("machdep.c"))
which select PDP-11/40 and 11/70 behaviour are therefore never true.
`lbolt` (10) counts clock ticks up to `HZ`, not to 60 as its comment
says.

#lines(1, 11)

#lines(12, 27)

`runin`, `runout`, and `runrun` (30-32) are the flags by which `sched`
and `swtch` (#f("slp.c")) communicate. `lks` (35) is a PDP-11 remnant
which nothing uses. `regloc` (40) is now defined in #f("sysent.c"), which
in our port also contains v7's `trap.c`; its comment is corrected to
say so.

`msgbufp` (42) is new. v7 defined this pointer into the circular
buffer `msgbuf` in its console driver, `kl.c`. The port has two
console drivers, #f("pl011.c") for QEMU and `stm32usart.c` for the
MP135, and both append to the buffer, so the pointer is now defined
once in #f("machdep.c") and declared here for both, without the comment
the other lines carry.

The four variables of the clock (48, 49) are new as well. `clkstart`
(#f("machdep.c")), which defines them, sets them up, and `clock`
(#f("clock.c")) uses them to set the deadline of each tick.

#lines(28, 49)

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

Line 65 deserves a word. A structure tag which first appears inside
a prototype's parameter list belongs to that prototype alone, and a
later definition of the structure would be a different type. `inode`,
`proc`, `buf`, `file`, and `filsys` have already been declared at file
scope by lines 7 to 63; `clist`, `map`, `text`, `tty`, and `uprof` have
not, so they are declared, without members, before the lists use them.
`uprof` is the tag the port gives to the profiling arguments `u_prof`
in #f("user.h"), so that `addupc` can be declared.

Most names in the list will be familiar from v7, now typed as
`void` because they return nothing. Among them are the system call
handlers, which take no arguments since they find them through
`u.u_ap`. The rest belong to the port:

- `arm_sureg`, `machine_init`, `install_sigtramp`, `irq`, `panictrap`,
  and `sigreturn` are in #f("machdep.c"). `sigreturn` is system call 63,
  which a signal handler returns through. `irq` is the interrupt
  handler.
- `mmu_on`, `arm_sync_icache`, `dcflush`, `dmbsy`, `idle`, `savfp`, and
  the generic timer accessors `cntv_ctl_set` and `cntv_cval_set` are
  in #f("mch.s"). There, too, are `cntfrq_get`, `dfar`, and `dfsr`, in the
  second list (133--136), which return the timer frequency and the
  address and status of the last data abort. `savfp` does nothing,
  since no floating point state is saved.
- `cninit` and `clock_ddr_init` are generated by `mkconf` into each
  board's #f("qemu/c.c"). They call the console's initialisation routine
  `klinit`, and on the MP135 also `ddrinit` (`stm32ddr.c`).
- The drivers keep v7's names. `rkstrategy` and its companions
  are defined by #f("virtio_blk.c") under QEMU and by `stm32sd.c` on
  the MP135; likewise the `kl` routines and `putchar` by #f("pl011.c")
  and by `stm32usart.c`. Each board's kernel links only its own
  drivers, so the names never clash.
- `user_trap_handler` (#f("sysent.c")) converts an undefined instruction
  or an abort taken in user mode into a signal, and then, like the end
  of v7's `trap`, recomputes the priority and switches if `runrun` is
  set. The interrupt path in #f("low.s") also calls it, with signal
  zero, for that second purpose alone.
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

#lines(67, 131)

The routines which return a value. `save` (144) returns twice, like
`setjmp`: zero when it saves, one when `resume` later returns through
the saved label. `max` and `min` keep v7's `int` result, although
their arguments are `unsigned`. `cntvct_get` (151), which reads the
generic timer's counter (#f("mch.s")), returns all 64 bits of it as an
`unsigned long long`.

`printf` (152) has a true variable argument list. v7's `printf`
walked up the PDP-11 stack from the address of its first argument.
Under the ARM calling convention the first four arguments arrive in
registers, so the port's #f("prf.c") uses `<stdarg.h>` instead.

#lines(132, 152)

On a PDP-11 with separate instruction and data spaces, reading a
program's text required different instructions (`mfpi`, `mtpi`) from
reading its data, hence v7's separate routines `fuibyte`, `suiword`,
and so on. The ARM has one address space, so the I-space forms are
simply aliases, and their callers (`passc`, `cpass`, `iomove`,
`procxmt`) keep v7's text.

#lines(153, 158)

Counters for `iostat`, kept by the clock and by the drivers, which
set and clear their bit of `dk_busy` around each transfer. Like the
variables above, they are now `extern`, and defined in #f("main.c").

#lines(159, 167)

The table of system calls, defined in #f("sysent.c") and indexed by
`trap` with the number of the call. The handler (175) was declared in
v7 as returning `int`, by default. The handlers return nothing; their
results go back to the user through `u.u_r`. It is now a pointer to a
`void` function of no arguments, and every handler is defined so.

#lines(168, 176)
#source("/usr/sys/h/seg.h")

In v7, #f("seg.h") held the addresses of the PDP-11 memory management
registers (the KT-11 unit) and the bits of a segment descriptor. The
first 23 lines are v7's, unaltered but for one word; the ARM definitions which the port
uses are appended after them. The arrangement is deliberate: the v7
text stays where a reader of v7 expects it, and what is new is
visibly new.

#lines(1, 4)

The PDP-11 divided each address space into eight segments of up to
8 KB, each described by a pair of registers: an address register,
giving the base in clicks, and a descriptor register, giving the
length and the access rights. `UISD`, `UISA`, and `UDSA` (5-7) are the
addresses of the first such registers for user mode. Nothing in the
port uses them.

The bits on lines 8 to 12 are still referred to. `sureg`
(#f("ureg.c")) runs v7's loop over the prototype registers `u.u_uisa`
and `u.u_uisd` (#f("user.h")), testing `TX` and `ABS` to choose the base
of each segment; v7's `sysphys` (#f("machdep.c")) marked a segment
`ABS`, but the port's refuses the call and marks nothing. But `estabur` no longer fills the prototypes, and the
result of `sureg`'s loop is thrown away: the ARM mapping is built from
`p_addr` and `p_size` alone, by `arm_sureg`. `RO` and `RW`, which
callers still pass to `estabur`, are ignored there. `TX` and `ABS` were
never hardware bits, only flags for `sureg`.

#lines(5, 13)

`ka6` (18) was the kernel's handle on the segmentation register for
kernel page 6, through which the per process data area of the current
process appeared. Here it is a variable that nothing reads; the same
job is done by the page table `uarea_l2` (#f("mch.s")). v7 relied on
the common-block convention to define it once in spite of its being
included many times; C99 allows a single definition, so it is now
declared `extern`, like the variables of #f("systm.h"), and since
nothing refers to it, it is defined nowhere.

#lines(14, 19)

`UBMAP` (23) addressed the map through which UNIBUS devices on the
11/70 reached memory beyond 18 bits. `mapalloc` still refers to it, but
returns at once because `cputype` is never 70.

The ARM definitions begin at line 24.

`USERSIZE` (24) is the size of the user's virtual address space: one
megabyte at virtual address zero. It is a single entry of the first
level page table, which points to a second level table (`user_l2`)
of 256 small pages. The text and data of a program are loaded from
low addresses upward, and `exece` (#f("sys1.c")) places the arguments and
the initial stack just below `USERSIZE`; `sbreak` and `physio` check
against it. It is the counterpart of the PDP-11's 64 KB.

`UENTRY_SIGTRAMP` (25) is the user address of a two-instruction
trampoline, `mov r7, #63; svc #0`, which `getxfile` writes into every
new image (`install_sigtramp`, #f("machdep.c")). `sendsig` sets the link
register to it before entering a signal handler, so that the handler's
return executes the `sigreturn` system call. v7's `sendsig` needed no
such help: it pushed the old program counter and status word onto the
user stack, and the catcher in the C library returned with `rtt`. In
the port the kernel restores the interrupted registers itself, in
`sigreturn`. Address 8 lies
below the point at which programs are loaded (0x10), so it can never
collide with a program, and location 0 still reads as zero.

`NCLICK` (26) is the number of 64-byte clicks between `corebase` and
`coretop`, the part of physical memory given to processes. Both
bounds come from the board's #f("qemu/c.c"). `CLKADDR` (27) converts a click
number into a kernel address. On the PDP-11, a click number _was_ a
physical address divided by 64, and the kernel reached it by loading a
segmentation register. Here click numbers count from `corebase`, and
that memory is mapped one-to-one into the kernel's address space, so
the conversion is plain arithmetic. Every place where v7 manipulated
memory by click (`copyseg`, `clearseg`, `swap`, `physio`) goes through
this macro.

#lines(20, 27)

The remainder are ARMv7 short-descriptor page table constants, used
by `machine_init` (#f("machdep.c")) and by the board table which `mkconf`
writes into #f("qemu/c.c").

`SEC_KERN` (28) is the descriptor for a one-megabyte section of
kernel memory. Read from the right: section type (2), bufferable and
cacheable (0xc), access permission 01, which grants access only in
privileged modes (0x400), memory type extension 001 (0x1000), which
with the C and B bits makes it normal write-back memory, and shareable
(0x10000).

`SEC_DEV` (29) describes a section of device registers: section type
with all type and cache bits zero, which makes it strongly ordered,
execute never (0x10), and access permission 01 (0x400), as for kernel
memory. The sections are mapped at their physical addresses in the one
first-level table, which serves user mode too; a user program that
loaded from the UART's address would reach the UART unless the
permission bits forbade it. An earlier version had permission 11,
which grants access in user mode as well, and so left every device
register open to user programs. Execute never keeps the processor
from fetching instructions, even speculatively, from device memory,
as the architecture requires.

`PTE_PT` (30) is the type field of a first-level entry which points to
a second-level table. `PGSHIFT` and `PGSIZE` (31, 32) describe the
4 KB small page, the unit of the user mapping. `struct memregion`
(33) is the type of the table `board_map`, which `mkconf` writes into
#f("qemu/c.c") from the `map` lines of the board's configuration file. Each
entry is a range of addresses to be mapped one-to-one, and the
section descriptor bits to use.

#lines(28, 33)
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

#lines(1, 11)

The TLB (the cache of address translations), the instruction
cache, and the branch predictor are invalidated, so that nothing from the
loader's regime can be found in them later. The data cache is dealt with
in `mmu_on` (#f("mch.s")). `dsb` waits for these operations to finish.

#lines(12, 17)

A provisional stack, at the end of the kernel's `bss` (115--117),
serves until the u-area of process 0 can be mapped. v7 needed no such
thing: its `start` set the memory management registers inline and then
pointed `sp` at the u-area directly.

The vector base address register `VBAR` is loaded with the
address of `vectors` (38). With bit 13 of `SCTLR` clear, the processor
takes exceptions through this table, wherever it lies. The table must be
aligned on 32 bytes (37).

#lines(18, 21)

The `bss` area is cleared, a word at a time, as `start` cleared
it in v7. The bounds are symbols defined by the linker script. Note that
the boot stack itself lies in the area being cleared; this is harmless,
since nothing has yet been pushed on it.

#lines(22, 28)

`machine_init` (#f("machdep.c")) starts the console, clears the
page tables, builds the kernel's translation table, maps the u-area of
process 0 at `UBASE`, and turns on the MMU and caches. Since the kernel
is mapped at its own physical address, execution and the boot stack carry
on undisturbed once translation is on.

The stack pointer is then moved (30) to the top of the u-area: `UBASE`
(`0x4F000000`) plus `USIZE*64` (8192). The assembler does not read
#f("param.h"), so the number is written out and must be kept in step by
hand. From now on the SVC stack is always the kernel stack of the
current process, at the same virtual address in every process, as
`KDSA6` arranged on the PDP-11.

`main` (#f("main.c")) is called (31). Process 0 never returns from it;
it ends in `sched`. Process 1, made by `newproc`, does return here, after
`main` has copied `icode` to user address 0.

#lines(29, 31)

The return to user mode. `spsr` is set to `0x10`, user mode
with both interrupt masks clear, `lr` to 0, and `movs pc, lr` copies
`spsr` into `cpsr` while it jumps: the standard ARM return from an
exception. This is v7's sequence of pushing a user-mode PS and a zero PC
and executing `rtt`. No user stack pointer is set: `icode` needs none,
and the `exec` it performs gives `/etc/init` its own.

#lines(32, 35)

The exception vectors. Each entry is an instruction, not an address, and
is executed in the mode which the exception selects; here each is a
branch. In order they serve reset, undefined instruction, supervisor call
(`svc`, the ARM's `trap` instruction), prefetch abort (an instruction
fetch from an unmapped or forbidden address), data abort (the same for a
load or store), a reserved slot, IRQ, and FIQ. Reset simply restarts the
system. The reserved slot and FIQ should never be taken, and lead to
`badtrap` (83).

Note that the PDP-11 distinguished its traps by vector, and wrote the
trap type into the low bits of the new PS (`br7+n` in `l.s`) for `trap`
to recover. On the ARM the vector, and the signal chosen at 93 or 105,
carry the same information.

#lines(36, 46)

The system call entry, the counterpart of v7's `trap` routine when it is
entered by a `sys` instruction. The processor arrives in SVC mode with
interrupts masked, `lr` holding the address after the `svc` and `spsr`
the user's `cpsr`. The task is to lay down on the kernel stack a frame
of all the user's registers, in the order which #f("reg.h") describes,
and to hand its address to C.

`srsdb sp!, #0x13` (49), "store return state", pushes `lr` and `spsr`
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

#lines(47, 51)

`trap` (#f("sysent.c")) is called with the frame's address,
which it saves in `u.u_ar0`. Interrupts are enabled for the duration of
the system call and masked again afterwards. v7's `trap` routine also
lowered the priority (`spl 0` in `call1`) before calling C. The return
is shared with the other traps (109).

#lines(52, 56)

The interrupt entry, which does the work of v7's `call`. An IRQ arrives
in IRQ mode, with `lr` four bytes beyond the instruction to be resumed;
line 59 corrects it.

The return state is then pushed, not on an IRQ stack, but on the SVC
stack, and the processor changes to SVC mode itself with both masks
set. IRQ mode therefore needs no stack of its own, and none is set up.
If the interrupt came from user mode, the SVC stack is empty and the
frame goes at the top of the u-area; if it came from the kernel, the
frame goes below whatever the kernel was using, and nests as on the
PDP-11.

#lines(57, 61)

The registers are saved as before. If the kernel was
interrupted, the `sp` and `lr` stored are the user's, not the kernel's;
they are restored unchanged at the end, so no harm is done. The kernel's
own `sp` is the frame pointer itself.

The one register in danger is SVC's `lr`. When the kernel is
interrupted, it may hold a live return address, and the `bl` at 66
would destroy it. It is kept in `r5` (64, 80), which the C calling
convention obliges `irq` to preserve.

`irq` (#f("machdep.c")) asks the GIC for the interrupt number,
and calls `clock` or the device handler.

#lines(62, 66)

If the interrupted program was in user mode (the mode field of
the saved status, at offset 64, is `0x10`) and `runrun` is set, the
process should give up the processor before it returns. v7's `call`
did this by calling `trap` with type 12; here `user_trap_handler`
(#f("sysent.c")) is called with signal 0, which posts nothing but runs
the same tail as a trap: `issig`, `psig`, `setpri`, and `qswtch`. The
interrupt was taken with interrupts masked; `swtch` may have unmasked
them, so line 78 masks them again before the frame is unloaded. Without
this test a process which never made a system call would never be
preempted, nor see a signal.

#lines(67, 81)

`badtrap` catches the two vectors which should never be used. It calls
`panictrap` (#f("machdep.c")), which panics. It runs in whatever mode
the stray exception selected, on a stack which was never set up.

#lines(82, 85)

The remaining exceptions all become signals to the process. The three
entries differ in the correction to `lr` and in the signal number. For an undefined instruction `lr` is four bytes past
the instruction, for a prefetch abort four, for a data abort eight; after
the correction the saved PC addresses the offending instruction. An
undefined instruction yields signal 4 (`SIGINS`), either abort signal
11 (`SIGSEG`). The PDP-11's illegal instruction and segmentation traps
gave the same signals; its bus error (`SIGBUS`) has no counterpart here.

The frame is built exactly as for an interrupt (89--92, 101--104).
Only then is the signal number loaded, into `r0` (93, 105), and
`user_trap_handler` receives the signal and the frame (107, 108). It
panics, after printing the fault address and status (`dfar`, `dfsr`,
#f("mch.s")), if the exception came from the kernel. The two aborts,
having the same signal, share the code from 100.

The save is repeated, rather than shared by all three, because no
register is free to carry the signal number to a common save: `r0` to
`r12` are the user's until they have been stored, and the banked `sp`
and `lr` of the abort and undefined modes are left behind by the change
to SVC mode. An earlier version put the number in `ip` (`r12`) before
the save, so that the frame recorded it in place of the user's `r12`,
and a process which caught `SIGINS` or `SIGSEG` and returned from its
handler resumed with `r12` changed.

#lines(86, 108)

The common return, the counterpart of the `rtt` at the end of v7's
`call`. `ldmia ... ^` (110), without the PC in the list, loads the user
mode's banked registers, as the `stmia` stored them. `rfeia sp!` (112),
"return from exception", pops the PC and the saved status together into
`pc` and `cpsr`, so the mode, the interrupt mask, and the condition flags
of the interrupted program are restored with its PC in one step.

#lines(109, 112)

The boot stack, 8192 bytes, which is used only until line 30.

#lines(113, 117)
#source("/usr/sys/conf/mch.s")

v7's `mch.s` held, besides the startup code, every operation which C
could not express on the PDP-11: the `trap` and `call` routines,
`save` and `resume`, the `spl` family, the transfers between kernel and
user space (`fubyte`, `copyin`, and their kin), `copyseg` and `clearseg`,
`idle`, the long division routines `ldiv` and `lrem`, the C function
prologue and epilogue `csv` and `cret`, and the profiling code. On the
ARM much of this has gone elsewhere. The startup, `trap`, and `call` are in
#f("low.s"). The user space transfers, `copyseg`, and `clearseg` are
ordinary C in #f("machdep.c"): user memory is mapped into the kernel's
own address space below `USERSIZE`, so a range check suffices where
v7 needed the `mfpi` and `mtpi` instructions and a `nofault` handler.
Division, procedure linkage, and `addupc` are left to the compiler or to C.
What remains here is the small set of routines which must touch the
processor's special registers: the MMU and caches, the interrupt mask,
the timer, and the stack pointer.

`p15`, coprocessor 15, holds the system control registers; `mrc` reads
one into a general register and `mcr` writes one. The ARM calling
convention passes the first four arguments in `r0` to `r3`, returns a
result in `r0`, and requires `r4` to `r11` and `sp` to be preserved.
`bx lr` is the return.

#lines(1, 4)

`mmu_on(l1)` is called once, from `machine_init` (#f("machdep.c")),
with the translation table which that routine has just filled.

Bit 6 of the auxiliary control register `ACTLR` (the "SMP" bit)
is set first. The Cortex-A7 does not treat shareable memory as coherent until
this bit is set, and an earlier version of the port found that cached
writes to DDR were lost without it. It must be set before the caches are
enabled.

#lines(5, 11)

`TTBR0` receives the address of the first-level table `l1` (12). The
translation table base control register is left at its reset value, so
that this one table covers the whole 4 GB address space.

The domain access control register is set to 1 (13, 14): domain 0, the
only one used, is a "client", so that every access is checked against
the permission bits in the table entries. This is what keeps user mode
out of kernel pages.

The cache size selection register is set to 0 (15--17), the level 1
data cache, so that the next read describes it.

#lines(12, 17)

The cache size identification register `CCSIDR` describes the
selected cache. From it are computed the logarithm of the line size in
bytes (`r3`), the number of ways less one (`r4`), and the number of sets
less one (`r6`). `r5`, the count of leading zeros of `r4`, is the shift
which puts a way number into the top bits of a word.

#lines(18, 25)

Each line of the data cache is invalidated "by set and way"
(`DCISW`, `c7, c6, 2`), the operand being the way shifted to the top,
or'ed with the set shifted by the line size. The outer loop counts the
sets down, the inner the ways. Invalidation, not cleaning, is wanted:
the cache has been off since `_start` (#f("low.s")), and whatever it
holds must not be written back over memory.

#lines(26, 35)

In `SCTLR`, the MMU (bit 0), the data cache (2), and the
instruction cache (12) are turned on together. The kernel's own addresses
map to themselves, so the instruction after the `mcr` is found at the
same place; `isb` ensures that it is fetched under the new regime.

The PDP-11 counterpart is the single instruction at the end of v7's
`start` which set bit 0 of `SSR0`, once the segmentation registers had
been loaded.

#lines(36, 43)

`dmbsy` is a data memory barrier: every memory access before it is
observed before any after it. The virtio disk driver (#f("virtio_blk.c"))
uses it to make the descriptors visible to the device before the ring
index which offers them, and the index before the notification; and on
an interrupt, to read the completed request only after the index which
reports it. The
PDP-11 performed accesses in program order and needed nothing of this
kind.

#lines(44, 47)

The interrupt priority routines. The PDP-11 had eight priority levels in
its PS, and a device interrupted only when its level exceeded the
processor's, so that a clock at level 6 could interrupt a disk handler
running at level 5. The ARM core has a single interrupt mask bit, `I`
(bit 7 of `cpsr`). So the levels collapse into two: `spl0` and `spl1`
clear the mask, `spl5`, `spl6`, and `spl7` set it, and every interrupt
handler runs with all interrupts masked. v7's `spl4`, which nothing in
this system calls, is omitted.

Each routine returns the previous `cpsr` in `r0` (51, 62), as v7's
returned the old PS, so that `s = spl6(); ... splx(s);` works.
`splx` (66) looks only at the `I` bit of the value it is given.

Neither `spl0` nor `splx` will unmask interrupts while
`irq_ready` is zero (52--55, 69--72). `clkstart` (#f("machdep.c")) sets it once the
interrupt controller and the timer have been programmed, and then calls
`spl0` itself. Until then interrupts stay masked, whatever `spl0` calls
the initialisation makes.

#lines(48, 77)

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
and the console's `putchar` (#f("pl011.c")) times its wait with
`cntvct_get`.

#lines(78, 96)

`save(lab)`
records in the array `lab` (a `label_t`, #f("param.h")) the registers
which a C procedure must preserve across a call, together with the stack
pointer and the return address, and returns 0. On the PDP-11 these were
`r2` to `r5`, `sp`, and the PC; here they are `r4` to `r11`, `sp`, and
`lr`: ten words.

#lines(97, 103)

`resume(p_addr, lab)` switches the u-area window to process `p_addr` and
returns, with the value 1, from the `save` which stored `lab`.
Interrupts are masked first (106), as v7 raised the priority to 7.

The physical address of the new u-area,
`corebase + p_addr*64` (`CLKADDR`, #f("seg.h")), is or'ed with
`0x12`, which in a small page entry means "kernel read and write, no
user access, not cached", and stored in the first entries of the
second-level table `uarea_l2`, a page apart. That table maps the
megabyte at `UBASE`, so the u-area of the new process now appears at
`UBASE`. This is the counterpart of v7's single store into `KDSA6`, the
kernel segment register for the u-area. The window is left uncached, an
earlier version of the file explained, because it points at different memory after each
switch.

Exactly `USIZE*64` bytes, two pages, are mapped, as `machine_init`
(#f("machdep.c")) maps them for process 0. An earlier version mapped four
pages, a relic of a larger u-area; the last two then aliased the first
8 KB of the process image, so that a stray kernel reference beyond the
top of the u-area silently read or wrote user memory instead of
faulting.

#lines(104, 114)

`dsb` makes the table writes visible to the hardware table
walker; the TLB is then invalidated entirely (`TLBIALL`), so that no
translation of `UBASE` to the old u-area remains, and `dsb` and `isb`
wait for that to take effect.

#lines(115, 119)

The registers are reloaded from `lab`. The reader should
observe that `lab` is always one of `u.u_rsav`, `u.u_qsav`, or `u.u_ssav`,
which lie in the `user` structure; so it is read through the new
mapping, from the new process's u-area. With the new `sp`, and the
saved `lr` held in `r2`, the routine returns into the new process, at
the point where it called `save`, which now appears to return 1.

Two points deserve notice. From the moment the entries are rewritten
(112) until `sp` is reloaded (121), the stack of the old process may
already have vanished from `UBASE`, and the stack pointer addresses the
new process's u-area at a meaningless position; the routine therefore
uses no stack at all, and an interrupt, which would push a frame there,
must be masked. Once the new stack is in place, `spl0` (123) unmasks
them, as v7's `resume` ended with `spl 0`. `spl0` is a call, which
overwrites `lr`; that is why the saved `lr` is loaded into `r2`, which
`spl0` leaves alone, and the return is through it (125). An earlier
version omitted the call and left interrupts masked until the process
next called `spl0` or `splx` or returned to user mode; after `expand`
had moved a process, for instance, interrupts were held off for the
rest of the system call.

#lines(120, 125)

`dcflush(addr, n)` cleans and invalidates the data cache over a range of
memory. The cache type register `CTR` gives in bits 16 to 19 the log of
the smallest data cache line in words; `r2` becomes the line size in
bytes. The start is rounded down to a line boundary, and each line is
cleaned and invalidated to the point of coherency (`DCCIMVAC`,
`c7, c14, 1`): any dirty data is written to memory and the line is
discarded. The SD card driver of the STM32MP135 (`stm32sd.c`) calls it on
a buffer before and after a DMA transfer, since that controller's DMA
does not see the cache: memory must hold what the processor wrote before
the device reads it, and the processor must not find stale lines after
the device has written. The PDP-11 had no cache, and so no such routine.

#lines(126, 141)

`arm_sync_icache` is called whenever the user's instructions may have
changed: by `sureg` (`arm_sureg`, #f("machdep.c")) after it rewrites the
user page table, by `getxfile` (#f("sys1.c")) after it has read in a
program and planted the signal trampoline,
and by `main` (#f("main.c")) after it copies out `icode`.

First the TLB is invalidated, which disposes of the old process's
user translations after `arm_sureg` has changed `user_l2`.

#lines(142, 148)

The level 1 data cache is cleaned by set and way (`DCCSW`,
`c7, c10, 2`), with the same loop as in `mmu_on`. The instructions which
`exec` read in were written through the data cache, and the instruction
cache fetches from memory; cleaning writes them out. On the Cortex-A7
level 1 is the point at which the two caches meet, so it suffices.

#lines(149, 169)

Then the instruction cache (`ICIALLU`) and the branch
predictor (`BPIALL`) are invalidated, so that the new program is fetched
afresh. `r0` must be reloaded with zero at 165, having been overwritten
at 147.

#lines(170, 176)

`idle` is v7's, in ARM form. Interrupts are enabled, and `wfi` ("wait for
interrupt") halts the processor until one arrives, as the PDP-11's
`wait` did. The interrupt is taken at once, and the PC it saves is that
of the instruction after `wfi`, labelled `1` (181). Its address is
stored in `waitloc` (194, 195), which `clock` (#f("clock.c")) compares
with the interrupted PC to count the time spent idle. v7's `idle`
restored the previous PS on the way out; this one simply masks
interrupts again, which suits both callers, `swtch` and `panic`:
the one loops at `spl6` and the other loops forever.

`savfp` shares the final `bx lr` and does nothing. v7 saved the PDP-11
floating point registers into `u.u_fps`. This kernel never enables the
ARM's floating point unit, so there is no state to save, but the calls
in `swtch` (#f("slp.c")) and `psig` (#f("sig.c")) are kept.

#lines(177, 183)

`dfar` and `dfsr` return the data fault address and status registers,
which describe the last data abort. `user_trap_handler` (#f("sysent.c"))
prints them before it panics on a fault in kernel mode, much as v7's
`trap` printed the memory management status registers it had copied into
`ssr`.

#lines(184, 191)

`waitloc` is a word of initialised data holding the address of the
label in `idle`, as `_waitloc` was in v7.

#lines(192, 195)

The translation tables. `l1` is the first-level table: 4096 words, each
describing one megabyte of the address space, either directly (a
"section") or by pointing to a second-level table of 256 words, each
describing a 4 KB page. The hardware requires the first-level table to be
aligned on 16 KB (198). `user_l2` maps the first megabyte, the user's
address space, and `uarea_l2` the megabyte at `UBASE`; both are
rewritten as processes come and go, by `arm_sureg` and `resume`
respectively. Everything else is mapped by sections which
`machine_init` builds once from the board's memory map.

The tables are placed in a section of their own, `.ddrbss`, which the
clearing loop in #f("low.s") does not touch. On the STM32MP135 the
kernel itself lives in a 128 KB on-chip RAM, and this section is put in
the external DDR memory, which cannot be used until `machine_init` has
initialised its controller; that routine clears the section afterwards.

#lines(196, 204)
#source("/usr/sys/sys/main.c")

#f("main.c") holds the procedure through which the kernel passes exactly
once, while it brings itself up, together with two initialisation
routines for the file system and the buffer cache which it calls.

On the PDP-11 the path to `main` began in `l.s` and `mch.s`, which set
up the kernel segmentation registers, placed the per process data area
of process 0 just above the end of the kernel, cleared the bss, and
turned memory management on. The ARM path is shorter. `_start` in
#f("low.s") disables the MMU and caches, sets a provisional stack,
installs the vectors, and clears the bss; it then calls `machine_init`
(#f("machdep.c")), which builds the page tables and enables the MMU.
Only then is the stack pointer moved to the top of the per process data
area of process 0, at `UBASE`+8192, and `main` called.

Line 13 declares `iinit` and `binit`, which `main` calls before their
definitions below. v7 needed no such line, since its compiler took an
undeclared function to return `int`; C99 does not allow the call.

The definitions at 14--40 are new. v7 defined these variables in the
headers themselves: every file which included #f("systm.h") or
#f("map.h") contained its own `int lbolt;`, `struct map coremap[...]`,
and so on, and the linker merged the copies into one. C99 allows an
object only one external definition in the whole program, and a modern
toolchain merges such "common" symbols only when asked to. The headers
now declare the variables `extern`, and each is defined here, once.
`rootdev`, `swapdev`, `pipedev`, `swplo`, and `nswap` are not among them,
because the configuration file #f("qemu/c.c") defines them with their
values; nor are `lks` and `ka6`, which nothing uses any longer.

#lines(1, 57)

`startup` (62) frees the core outside process 0 and initialises the
block device.

#lines(58, 62)

`p_addr` of process 0, set at line 67, is the click at which its per process data
area begins. v7 read it from the kernel segmentation register `KISA6`
(`ka6`), whose value `mch.s` had chosen. Here `machine_init` has
already mapped clicks 64 to 64+`USIZE`-1 of core at `UBASE`, so the
value is a constant. The reader may wonder why not click 0. Click 0
cannot be handed out at all, since `malloc` (#f("malloc.c")) returns 0 to
report failure; and every process image must begin on a page boundary
(4096 bytes, 64 clicks) for the MMU to map it. Click 64 is the first
address satisfying both, and the core below it is simply never used.

The remaining fields of `proc[0]` (68--73) are as in v7: the process
occupies only its `USIZE` clicks, is runnable, is in core, and is never
to be swapped. `u` and `proc[0]` are linked through `u_procp`.

#lines(63, 74)

`clkstart` (80) now does rather more than start the clock: it also
programs the interrupt controller and is the point at which interrupts
are first allowed (#f("machdep.c")). Everything which follows may
therefore sleep: `iinit` waits for the disk.

`rootdir` and the current directory of process 0 are obtained as
separate references to the root inode; each `iget` returns it locked,
and the lock is released at once (85, 87).

#lines(75, 89)

`newproc` (96) makes process 1 as a copy of process 0 and returns zero
to the parent, which falls through to `sched` (107) and never comes back.
Process 1 eventually resumes in `newproc` with a value of one, and
takes the branch.

#lines(90, 96)

The image is first enlarged to hold `icode`. `expand` (#f("slp.c")) rounds
the new size up to a whole number of pages, so that what is allocated
is the u-area and one page.
`estabur` (#f("ureg.c")) then checks the size and calls `sureg`, which
maps the page into the user window at virtual address 0, and
`copyout` writes `icode` (#f("machdep.c")) through that mapping, to
user address 0.

`arm_sync_icache` (100) is new. The ARM, unlike the PDP-11, has
separate instruction and data caches which are not kept coherent by the
hardware: the instructions just stored may sit in the data cache, and
stale lines may sit in the instruction cache. The routine (#f("mch.s"))
writes the data cache back, then discards the instruction cache, the
branch predictor, and the TLB.

#lines(97, 100)

`main` then returns to `_start` (#f("low.s")), which, as v7's `start` did
with `rtt`, sets the saved status register to user mode and jumps to
location 0. Process 1 begins to execute `icode`.

#lines(101, 108)

`iinit` opens the root device, reads its super-block (block 1,
`SUPERB`), and copies it into a buffer which is never released, the
first entry of the mount table. The super-block's time of last
modification becomes the initial time of day, until `date` or
`stime` corrects it.

#lines(109, 140)

The buffers themselves (150). v7 declared each as `BSIZE+BSLOP`, i.e.
514, bytes of `char`. With 514 bytes every second buffer started on an
address which was only two-byte aligned, and the internal DMA engine of
the SD card controller on the STM32MP135 requires a word-aligned buffer
address; the odd buffers were corrupted on transfer. Each row is now
rounded up to 516 bytes and made of `int`s. Rounding alone would align
the rows only relative to the start of the array, and C promises no
alignment for a `char` array; an `int` array is aligned for `int`, so
every row starts on a word. The cast at 169 is the price.

#lines(141, 151)

`binit` links every buffer into the free list through `brelse`, then
makes each block device's queue (`d_tab`) an empty circular list, and
counts the block devices in `nblkdev`. The scan of `bdevsw` ends at
the first entry without an open routine, the null entry with which
#f("qemu/c.c") closes the table.

#lines(152, 185)
#source("/usr/sys/sys/machdep.c")

In v7, #f("machdep.c") collected those parts of the machine-dependent
code which could be written in C: the bootstrap program `icode`,
`startup`, `clkstart`, `sendsig`, and the UNIBUS map routines for the
11/70. The assembly language remainder lived in `mch.s`. The port keeps
v7's procedures in v7's order, rewriting their bodies for the ARM, and
appends a second half which does the work that `mch.s` did on the
PDP-11 with the help of the memory management unit: building the page
tables, loading the user mapping, copying and clearing clicks, moving
data between kernel and user space, and reading physical memory for
`/dev/mem`.

The whole port rests on one arrangement of the ARM MMU, which it is
best to describe before the code. The PDP-11/45 divided the 64 KB user
address space into eight segments of up to 8 KB, each described by an
address register (`UISA`) and a descriptor register (`UISD`); the
kernel's own seventh segment was pointed by `KISA6` at the per process
data area of the current process. The ARM short-descriptor format
offers instead a first-level table (`l1`) of 4096 entries, each
covering one megabyte, which may map a megabyte section directly or
point to a second-level table of 256 entries mapping 4 KB pages. The
port uses it thus:

- The kernel's own addresses (its image, the whole of core, the device
  registers) are mapped one to one by sections, once, at boot; a kernel
  address is a physical address. This is the counterpart of v7's
  kernel segments 0 to 5, which never changed.

- Entry 0 of `l1` points to `user_l2`, whose 256 pages make the 1 MB
  window, virtual addresses 0 to `USERSIZE`, in which every user
  program runs. `arm_sureg` (215) fills it on each process switch from
  the physical image of the current process, as `sureg` filled `UISA`.

- The entry for `UBASE` points to `uarea_l2`, whose first entries map
  the per process data area of the current process. `resume`
  (#f("mch.s")) rewrites them on every switch, exactly as v7's `resume`
  reloaded `KISA6`. Hence `u` is always at `UBASE`.

A process image in core keeps v7's form: `USIZE` clicks of per process
data area at `p_addr`, then the user's memory. On the PDP-11 the user's
memory was divided into text, data, and a stack at the top of the address
space, with a gap between; here every program that has been through
`exec` is given the whole 1 MB at once, contiguous, and its stack sits
at the top of it.

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
On the ARM the configuration (#f("qemu/c.c")) states the limits of core,
`corebase` and `coretop`, and nothing is probed.

#lines(33, 45)

All of core is freed (46, 47) except its first 64+`USIZE` clicks: the
unused first page and the per process data area of process 0 (see
`main`). Core is no longer cleared here; `machine_init` clears the
area of process 0, and `exec` (#f("sys1.c")) clears each image it builds.
The v7 comment (43) is therefore only half true.

`maxmem` (48) was the size of core, limited by `MAXMEM`. It now bounds
the size of a process rather than of memory: one per process data area
plus the 1 MB user window, which is all that `estabur` (#f("ureg.c")) will
permit. The printed figure (49) is the amount of core freed.

#lines(46, 49)

The swap area (50, 51) is set up as in v7.

v7 ended `startup` by pointing user segment 7 at the I/O page.
Its place is taken by `bdinit` (52), which #f("qemu/c.c") defines to call the
block driver's initialisation routine. This must come before
`clkstart`, since the `virtio` driver only learns its interrupt number
when it probes the device. The 11/70 UNIBUS map initialisation is gone
with the 11/70.

#lines(50, 53)

`sysphys`, system call 52, let the super-user map a piece of physical
memory, such as device registers, into a segment of his address space.
v7's recorded the segment in `u_uisa` and `u_uisd` and called `sureg`.
Since `arm_sureg` (215) takes no notice of those prototypes, the call
would succeed and map nothing, and a program which relied on it would
go on to use addresses which are not there. The body is therefore
replaced: the super-user is refused with `EINVAL`, the error v7 gave
for a request it could not satisfy, and anyone else, as in v7, with the
error of `suser`.

#lines(54, 66)

Hence to the clock. The PDP-11 had a line clock (KW11-L) or a
programmable clock (KW11-P) on the UNIBUS, each with its own interrupt
vector and priority; v7's `clkstart` tried one, then the other, and
set its interrupt enable bit. On the ARM every device interrupt reaches
the processor through a single line from the Generic Interrupt
Controller (GIC), whose distributor (`gicdbase`) and processor interface
(`giccbase`) registers are reached through `GICD` and `GICC` (72, 73).
The clock is the processor's own generic timer: interrupt 27 (`TIMER`)
is the private interrupt of its virtual timer.

`intrtab` (75) is generated by `mkconf` in #f("qemu/c.c"): for each
configured device, a pointer to the variable holding its interrupt
number and the routine to call. A pointer, rather than the number,
because some numbers are not known until the driver has probed its
device.

`gicen` (80) gives interrupt `n` a middling priority (0x80) in the
distributor's byte-per-interrupt priority array at `0x400`, then sets
its bit in the set-enable registers at `0x100`.

#lines(67, 86)

`clkstart` first reads `CNTFRQ` (92), which gives the frequency of the
system counter. `clkreload` is the number of its counts in `1/HZ`
second, and `clkrem` (94) what the division leaves over, which
`clock` (#f("clock.c")) adds in so that the ticks keep exact time. A
frequency below `HZ` (the register is set by firmware) is the one
remaining way to "find no clock".

It then enables the timer and every configured device interrupt whose
number is known (95--98); enables the distributor, lets interrupts of
every priority through the processor interface (the priority mask
register at 4), and enables the interface (99--101); and sets the
timer's first deadline, `clkreload` counts after the present value of
the counter, and starts it (102, 103). `clkcval` (76) keeps the
deadline, from which `clock` computes the next.

Only then (104, 105) may interrupts be taken. `spl0` (#f("mch.s")) unmasks
interrupts only when `irq_ready` is set, so any earlier call, as from a
driver, leaves them masked while the GIC
is still unprogrammed. Since `main` calls `clkstart` before `iinit`,
the read of the root super-block is already driven by interrupts.

#lines(87, 106)

`irq` is new. It is called from `irq_entry` (#f("low.s")) with a pointer to
the saved registers of the interrupted program, in the layout of
#f("reg.h"), and with interrupts masked; it plays the part of v7's
`call` in `mch.s` together with the PDP-11's vectored interrupts.

Reading the acknowledge register (`0xc`) at line 156 yields the number of
the highest priority pending interrupt, in its low ten bits, and marks
it active.

For the timer (115, 116), call `clock` (#f("clock.c")), which sets the
next deadline. v7's `clock` took seven arguments, the words of the
PDP-11 interrupt frame, but used only the program counter and the
processor status; those two are all that are passed now. The status is
reduced to `UMODE` if the interrupted program was in user mode (mode
bits `0x10`) and zero otherwise. `main` has set up process 0 before it
calls `clkstart`, so `clock` always finds a current process.

Otherwise (117--120), call the routine of the device whose number
matches. A spurious interrupt (1023) matches nothing.

Writing the same value to the end-of-interrupt register (`0x10`) at
line 163 retires the interrupt.

Note that all interrupts share one level. The six PDP-11 priorities of
`spl4` to `spl7` have collapsed into "masked" and "unmasked", and an
interrupt handler is never itself interrupted.

#lines(107, 122)

`sendsig` arranges for the signal handler at `p` to be called when the
process next returns to user mode. On the PDP-11 it pushed the
processor status and program counter onto the user stack and set the
program counter to the handler, simulating an interrupt; the handler
(in fact a stub in the C library) ended with `rtt`, which popped both.
The ARM has no user-mode instruction which can restore the status
register from memory, and the C calling convention lets the handler
clobber `r0` to `r3`, `r12`, and the condition flags, so the whole
register frame must be saved and a system call is needed to restore it.

#lines(123, 131)

`n` (132) is the user stack pointer less the size of the frame (17
words: `r0` to `r15` and the status register), rounded down to a
multiple of 8 as the ARM calling convention requires.

The frame is copied out (133--137) with `copyout`, which checks that
it lies in the user window. v7 called `grow` here to extend the stack
segment; the 1 MB window is wholly allocated, so there is nothing to
grow. If the frame cannot be written, the process is sent `SIGSEG`,
with its handler first reset to the default so that it is not caught
in turn.

#lines(132, 137)

The stack pointer is then lowered past the frame; the link
register, `u_ar0[14]`, for which #f("reg.h") has no name, is set to the
trampoline at `UENTRY_SIGTRAMP` (see `install_sigtramp`, 406); the
program counter (`R7`, which in #f("reg.h") is `r15`) to the handler; and
`r0` to the signal number, the handler's argument. v7 also cleared the
trace bit in the saved status, so that a traced process would not trap
on the handler's first instruction; the ARM status register has no
trace bit.

When the handler returns, it returns to the trampoline, with the stack
pointer at the frame, and the trampoline issues `sigreturn` (308).

#lines(138, 142)

`mapalloc` and `mapfree` are v7's, for the UNIBUS map of the 11/70.
They compile, but nothing sets `cputype`, which is therefore 0;
`mapalloc` always returns at once, and no buffer is ever marked
`B_MAP`, so `mapfree` is never called from `iodone` (#f("bio.c")).

#lines(143, 185)

The remainder of the file is new.

`board_map` (187) comes from #f("qemu/c.c"): the regions which the board's
configuration file asks to be mapped by sections, each with the
attribute bits of its section descriptors. The `__` symbols (188) are
defined by the linker script. `.ddrbss` is a second, uninitialised
data section: on the STM32MP135 the kernel image runs from the 128 KB of
on-chip SYSRAM, and the page tables and other large arrays are placed in
external DDR memory, which is useless until it has been set up. On the
QEMU board it is ordinary memory. The page tables themselves (189) are
reserved in #f("mch.s") in `.ddrbss`: `l1` must be aligned on 16 KB.

`msgbufp` (190), the pointer into the circular buffer of console
output read by `dmesg`, was defined in v7's console driver `kl.c`. It
is here because either of two console drivers may be configured
(#f("pl011.c") or the MP135's), and both use it.

#lines(186, 191)

`machine_init` is called from `_start` (#f("low.s")), with the MMU off,
running on a small stack in the bss. It first initialises the console
(199), so that `printf` and `panic` work from here on.

On the MP135, it then starts the DDR controller (`clock_ddr_init`
is empty on QEMU), and clears `.ddrbss`, which `_start` could not do.

#lines(192, 202)

Each region of `board_map` is mapped by one-megabyte sections,
with physical address equal to virtual address. The attributes,
spelled `SEC_KERN` and `SEC_DEV` in the configuration files, are
defined in #f("seg.h"): kernel memory is normal, cacheable, and accessible
only from the kernel; device memory is strongly ordered, never
executable, and likewise closed to user mode.

Entry 0 (206) points to the second-level table of the user window;
`PTE_PT` marks a page-table descriptor. Its 256 entries are filled by
`arm_sureg`, and stay zero, i.e. invalid, until then.

The entry for `UBASE` (0x4F000000) points to `uarea_l2` (207). The
order of these assignments matters: on the MP135, `UBASE` lies inside
the device region `0x40000000` to `0x60000000`, whose section entry is
here overwritten.

#lines(203, 207)

The `USIZE`×64 bytes, two pages, of the per process
data area of process 0 (clicks 64 onwards of core) are mapped at
`UBASE` (208, 209). The attribute `0x12` describes a small page which
the kernel may read and write and user mode may not touch. The area is
then cleared (210, 211); v7's `start` did the same for process 0.

`mmu_on` (#f("mch.s")) loads the table base register, sets domain 0
to "client" so that the permission bits are checked, invalidates the
data cache, and turns on the MMU and the caches. Since the kernel is mapped
one to one, execution continues undisturbed at the next instruction.

#lines(208, 213)

`arm_sureg` is the ARM half of `sureg` (#f("ureg.c")), which calls it,
and so it runs whenever v7 would load the user segmentation registers:
after `estabur`, `expand`, and a process switch. The test (220) protects
the first call, made before `main` has set `u_procp`.

#lines(214, 221)

The user's memory begins `USIZE` clicks after `p_addr` (222).
`n` (223) is the number of pages in it. `p_size` is always a multiple
of 64 clicks, because `expand` rounds it so.

The first `n` pages of the window are mapped (224, 225), with the attributes
`pguser` from the configuration (user read and write, and the board's
cache policy); the rest are left invalid. Every program that has been
through `exec` fills the window, so only process 1, while it runs
`icode` in a single page, has invalid pages. There is no distinction of
text from data: text is writable, and `xrw` of `estabur` is ignored.

`arm_sync_icache` (#f("mch.s")) then invalidates the whole TLB, so that
the new entries take effect, and brings the caches into step with an
image which may just have been copied.

#lines(222, 227)

`copyseg` and `clearseg` copy and clear one click, 64 bytes or 16
words. In v7 they were in `mch.s`, and had to borrow a user segment to
reach a physical click; here core is mapped into the kernel's own
address space, and `CLKADDR` (#f("seg.h")) converts a click number to a
pointer.

#lines(228, 248)

The routines which move data between the kernel and the current user
process. On the PDP-11 these lived in `mch.s` and used the `mfpi` and
`mtpi` instructions, which fetch and store through the previous
(user) mode's mapping; a reference to a missing segment trapped, and the
trap handler, finding `nofault` set, made the routine return -1.

On the ARM the user window is mapped in the same table as the kernel,
at addresses which do not overlap it, and kernel mode may read and
write user pages directly. So each routine checks only that the
address range lies inside the window, with `uaddr` (250), written so
that `a+n` cannot overflow, and then dereferences an ordinary
pointer. No fault is caught: a reference from kernel mode to an invalid
page is a kernel trap and a `panic`. That is safe because, as noted
above, only `icode` runs with part of the window unmapped.

v7 distinguished `fuibyte` from `fubyte`, instruction space from
data space; #f("systm.h") makes the former names aliases of these.

The `& 0377` (261) gives the byte without sign extension, whatever the
signedness of `char`.

#lines(249, 306)

`sigreturn`, system call 63, undoes `sendsig`. It is called by the
trampoline, at which point the user stack pointer addresses the saved
frame.

#lines(307, 313)

The frame is copied in through `copyin`, which bounds it to the
user window; a bad stack pointer earns `SIGSEG`.

#lines(314, 318)

`r0` to `r15` are restored (319, 320).

Of the saved status register (321), only the condition flags (bits 27
to 31) and the `GE` flags (16 to 19) are taken. The mode bits are not:
otherwise a forged frame could return the process to the processor in
a privileged mode.

`trap` (#f("sysent.c")) will store `r_val1` and `r_val2` into
`r0` and `r1` as the results of this system call; setting them to the
saved values (322, 323) makes the return restore those two registers too.

#lines(319, 324)

`fumem` and `sumem` serve the memory special files (#f("mem.c")) one byte
at a time, in the role that `fuibyte` and `suibyte`, with a user segment
pointed at physical memory, played in v7's `mem.c`.

`memaddr` translates a file offset to a kernel address. An offset below
`kernbase` is taken relative to core, so that a program which, as on
the PDP-11, computes the address of a process image as `p_addr`×64
reads the right bytes; any other offset is an address in its own right.
In either case the address must lie within the kernel image, `.ddrbss`,
or core, all of which are mapped; anything else returns -1, and the
driver sets `ENXIO`.

#lines(325, 360)

`install_sigtramp` writes the two-instruction signal trampoline,
`sigreturn` by `svc`, at user address 8. It is called by `exec`
(#f("sys1.c")) after the new image has been loaded; `fork` copies it with
the rest of the image. Address 8 lies below `0x10`, where programs are
linked to begin, so no program overwrites it.

`panictrap` is the target of the vectors which should never be taken
(#f("low.s")).

#lines(361, 373)
#source("/usr/sys/h/proc.h")

A process is represented in two places. Its `proc` structure, one
element of the array `proc` (29), stays in memory throughout the life
of the process and holds what the system must know about it even
when the rest of it is on the swap device: whether it is in memory,
where it is, why it sleeps, and the information that scheduling and
signals need. The rest of the process state, the `user` structure
(#f("user.h")), lives at the bottom of the process's own memory image
and is swapped with it.

The file differs from v7 in a single line.

`p_stat` (10) takes one of the values on lines 32 to 37; a zero entry
is free. `p_flag` (11) is a set of the bits on lines 40 to 46.

`p_pri` (12) is the scheduling priority, recomputed by `setpri`
(#f("slp.c")) from `p_cpu` and `p_nice`, or set by `sleep` to the
priority given for the event. A smaller value is more urgent, so the
comment's "negative" means the highest of all. `p_time` and `p_cpu`
are kept in a `char`, and `clock` stops each at its maximum so that
it cannot wrap.

`p_sig` (16) is the set of pending signals, one bit each, the bit for
signal _n_ being 1 shifted left _n_-1. v7 kept it in a `short`, the
sixteen bits of which held its sixteen signals; it is now an `int`, for
the 31 signals which `NSIG` (#f("param.h")) allows. `xp_sig` (61), its
counterpart in `struct xproc` below, is widened with it, so that the
fields after it still lie where `proc`'s do.

`p_addr` (21) and `p_size` (22) locate the image. When `SLOAD` is set,
`p_addr` is a click number counted from `corebase` (`CLKADDR`,
#f("seg.h")); otherwise it is a block number on the swap device. `p_size`
is in clicks in both cases, and includes the `USIZE` clicks of the
`user` structure and kernel stack, which come first.

`p_addr` has been widened from `short` to `int`. On the PDP-11, whose
largest memory was 4 MB, a click number fitted in sixteen bits.
Here a click is still 64 bytes but memory is far larger: the
QEMU configuration gives processes 64 MB, or 1048576 clicks, and the
MP135 some 500 MB. `p_size`, on the other hand, is bounded by
`maxmem`, which is the one megabyte of `USERSIZE` plus `USIZE`, 16512
clicks; it still fits in a `short` and has been left alone.

`p_wchan` (23) is the address on which a sleeping process waits;
`wakeup` compares it with its argument. `p_textp` (24) points to the
shared text segment, if there is one. In this port none is ever
created, since programs are loaded as a single writable segment, and
`p_textp` remains null. `p_link` (25) chains the runnable processes
into the list headed by `runq` (#f("systm.h")): `setrq` (#f("slp.c")) adds a
process to it, and `swtch` searches it for the most urgent one that is
in memory. `p_clktim` (26) counts down the seconds of an `alarm`.

#lines(1, 30)

`SWAIT` is listed but never set by v7 itself. `SIDL` covers the brief
time in `newproc` while a child is being copied, and `SZOMB` the time
between `exit` and the parent's `wait`.

#lines(31, 38)

`SLOAD` is the bit which decides how `p_addr` is to be read. `SSYS`
marks process 0, which is never swapped. `SLOCK` holds a process in
memory temporarily: while it is being swapped out, while its text is
read in, and while `physio` transfers directly to or from its image.
`SULOCK` does the same at the user's request, through the `lock`
system call (`syslock`). `STRC` and `SWTED` serve `ptrace`.

#lines(39, 47)

When a process exits, its image is released, but its `proc` entry
lingers in the `SZOMB` state until the parent collects it with
`wait`. At that point the entry must carry the exit status and the
times used, which no field of `proc` provides. `exit` (#f("sys1.c")) casts
the `proc` entry to an `xproc` and stores them in place: the first
eleven fields coincide, and the new ones overlay `p_addr` and the
fields after it, which are now meaningless.

The overlay works only if `xproc` is no larger than `proc`. With
`p_addr` now four bytes, `xp_xstat` covers half of it, the two
`time_t`s are aligned to offset 24, and `xproc` ends at 32 bytes, well
inside the 44 bytes of a `proc` entry.

#lines(48, 69)
#source("/usr/sys/h/user.h")

The `user` structure is the second half of the description of a
process, the half that can be swapped. It sits at the base of the
process's image in memory, followed by the kernel stack of the
process, the two together occupying `USIZE` clicks (#f("param.h")): the
"per process data area". Only the data area of the current process is
addressable, always at the same kernel address, and the kernel calls
it `u`. To switch processes is, at bottom, to change which data area
appears there.

The opening comment is v7's. `USIZE` is now 128 clicks, 8 KB, rather
than 16, and the block appears at virtual address `UBASE`, 0x4F000000,
which the comment now gives in place of v7's 0140000. That address was
the start of the seventh kernel segment, and v7
switched processes by reloading that segment's address register
(`ka6`). The port reserves one megabyte of kernel address space for
the window, with its own second-level page table, `uarea_l2`
(#f("mch.s")). `resume` writes the physical address of the new process's
data area into that table and flushes the TLB, after which the same
virtual addresses show the new `u`.

`EXCLOSE` (15) is the bit of `u_pofile` (56) which marks a file to be
closed by `exec`.

#lines(1, 16)

`u_rsav` (19) holds the registers saved by `save` (#f("mch.s")) when the
process gives up the processor in `swtch`, and restored by `resume`.
`label_t` now has ten words: r4 to r11, the stack pointer, and the link
register, the registers which the ARM procedure call standard requires
a callee to preserve.

The floating point fields (20-25) are v7's, and still have their
PDP-11 shape. `swtch` and `psig` call `savfp` to store the registers
here before they might be inspected, `exec` clears them, and `ptrace`
permits writes to them. But `savfp` (#f("mch.s")) is an empty routine,
since the port saves no floating point state, so the area stays zero.

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
which write `u.u_r.r_val1` remain as v7 wrote them.

#lines(26, 43)

The parameters of an I/O transfer, which `readi`, `writei`, and the
drivers consume: `u_base`, `u_count`, and `u_offset`. After them come
the current and root directories, and the working storage of `namei`
(#f("nami.c")): the current component of the path name, a pointer into
the name, a copy of the directory entry, and the parent directory.

#lines(44, 52)

`u_uisa` and `u_uisd` (53, 54) are the prototypes of the sixteen
PDP-11 user segmentation registers, from which `sureg` loaded the
hardware. They are kept, but the port's user mapping is derived from
`p_addr` and `p_size`, not from them (#f("seg.h")). `u_ofile` (55) is the
table of open files, indexed by file descriptor. `u_arg` (57) receives
the arguments of a system call from the saved registers r0 to r3;
no call takes more than four. `u_tsize`, `u_dsize`, and `u_ssize` (58-60)
are the sizes, in clicks, of the three parts of the user image.

#lines(53, 60)

`u_qsav` (61) is the label to which `sleep` returns when a signal
interrupts a system call; `trap` sets it on every call. `u_ssav`
serves `expand` and the swapping code, which may need to resume a
process at the point where its image was copied. `u_signal` (63) holds, for each
signal, zero for the default action, one to ignore it, or the address
of a catching routine; an `int` holds an address on both machines.
The four times are counted in clock ticks.

`u_ar0` (68) points to the user's registers as saved on the kernel
stack on entry to the system. The frame in the port holds r0 to r14,
the program counter, and the status register, and #f("reg.h") gives the
index of each in the frame. `u_prof` holds the parameters of the
`profil` system call. Its structure has been given the tag `uprof` so
that `addupc` (`clock.c`), which v7 wrote in assembler, can be declared
to take a pointer to it and read the fields by name. `u_ttyp` and `u_ttyd` (77, 78) name the
controlling terminal.

#lines(61, 78)

`u_exdata` (79) is the header of the program being executed, read by
`getxfile` (#f("sys1.c")). In v7 it was the eight-word `a.out` header. Our executables are in ELF, and the
structure has been rearranged to hold two pieces of an ELF file. Its
first 52 bytes overlay the ELF file header. The fields that the
kernel reads have names; the rest are fill:

- `ux_mag` (80) receives the four identifying bytes, `\x7fELF`, which
  read as a little-endian word are 0x464c457f.
- `ux_tsize` (81) overlays further identification bytes. `getxfile`
  sets it to zero after the header has been checked, to say that there
  is no separate text segment; programs are linked `-N` into one
  writable segment, the ELF counterpart of v7's 0407 format.
- `ux_entloc` (83), the entry point, and `ux_phoff` (84), the file
  offset of the program header table, fall at the offsets of the ELF
  fields `e_entry` and `e_phoff`.
- `ux_phnum` (86) is the number of program headers.

The next six words, from `ux_type` (87) onward, receive the first six
fields of one program header: its type, file offset, virtual address,
physical address, size in the file (`ux_dsize`, which keeps v7's name),
and size in memory. `getxfile` reads 24 bytes from each program header
in turn into this place until it finds one of type 1, the loadable
segment. The remaining two fields of the program header are not
needed.

v7's `ux_bsize`, `ux_ssize`, `ux_unused`, and `ux_relflg` have gone.
The data size of the new image is taken as `ux_addr` plus `ux_msize`.
Since the whole image is cleared before the segment is read in, the
part beyond `ux_dsize`, the uninitialised data, reads as zero without
further work.

#lines(79, 90)

`u_comm` (91) is the last component of the name of the program, for
accounting and `ps`; `u_start` and `u_acflag` are also for accounting.
`u_cmask` (95) is the `umask`.

`u_stack` (96) marks the end of the structure. The kernel stack begins
at the top of the data area, 0x4F002000, where #f("low.s") sets the
supervisor mode stack pointer, and grows down towards it. Nothing but
the size of the area guarantees that it does not reach the structure.

#lines(91, 101)

In v7, `u` was an external variable (103). Its address was fixed not
by storage but by the assembler line `_u = 140000` in `mch.s`, which
made `_u` an absolute symbol. The port does the same with one line of
the linker script, `u = 0x4F000000`, which `mkconf` writes
(#f("qemu/unix.ld")): `u` is the `struct user` at `UBASE`, and every
reference to it is to that fixed address, as in v7. A program which
includes #f("user.h") for the structure may still name a variable of
its own `u`, as `ps` does.

#lines(102, 104)

The error numbers which a system call may return in `u_error`. The
user sees them in `errno`. They are unchanged from v7.

#lines(105, 139)
#source("/usr/sys/sys/ureg.c")

#f("ureg.c") contains the two procedures through which the rest of the
system controls a process's user address space. `estabur` validates
the sizes of the text, data, and stack of a new or changed image and, in
v7, computed from them a set of _prototype_ segmentation registers,
relative to the start of the image, kept in `u.u_uisa` and `u.u_uisd`.
`sureg` loaded the hardware registers from the prototypes, adding the
physical address of the image; it is called whenever the image may have
moved: by `estabur`, by `expand` (#f("slp.c")), and when a process is
resumed in `swtch`.

The division of labour survives on the ARM, but with almost nothing
left to divide. A PDP-11 address space had eight segments of up to 8 KB
each, so `estabur` had to fit text, data, and stack into them separately,
round each up to whole segments, decide which were read-only and which
grew downward, and possibly give text a separate instruction space. The
ARM port gives every process one contiguous 1 MB window, mapped page
for page onto the physical image (see #f("machdep.c")). There is nothing
to compute but the image's address and size, and both are in the
`proc` structure.

#lines(1, 8)

`sureg` keeps the v7 loop in form. It still forms, for each of the
sixteen prototypes, the physical click address of the segment: the
text base for a text segment (`TX`), zero for an absolute one (`ABS`,
which only v7's `sysphys` made), otherwise the data base. But v7 stored each sum into
the hardware address register `UISA` and copied each descriptor into
`UISD`, through the pointers `rap` and `rdp`. Those registers are gone:
`rap` and `rdp` now point at the local arrays `auisa` and `auisd` (19,
30, 31), which are written and never read, so that the loop (33--36)
stands as v7 wrote it. The mapping is in fact made by `arm_sureg` (37),
from `p_addr` and `p_size` alone.

Two details of the loop are dead on the ARM. `cputype` (28) is never set
and so is never 40; and `p_textp` (25) is always null, since `exec`
(#f("sys1.c")) treats every program as having no separate text.

#lines(9, 38)

`estabur` is reduced to the one check that still has meaning: that the
image, together with its per process data area, does not exceed
`maxmem`, which `startup` (#f("machdep.c")) has set to `USIZE` plus the
clicks of the 1 MB window. The sum is cast to `int` for the comparison,
because `maxmem` is an `int`; v7 compared it as unsigned.

Everything else is deleted. The checks that text, data and stack each
fit within the eight segments, with or without separate I and D space,
have no counterpart in a 1 MB window which is always wholly mapped. The
construction of the prototypes is gone with the hardware they described;
`u_uisa` and `u_uisd` are no longer written here, and survive only for
`sysphys`. The arguments `sep` and `xrw` are accepted and ignored (54):
there is no separate instruction space, and since every user page is
mapped read-write, a read-only text cannot be had either.

#lines(39, 64)
#source("/usr/sys/sys/slp.c")

#f("slp.c") is the heart of process management. It holds the procedures
by which a process gives up the processor (`sleep`, `swtch`), by which
another makes it runnable again (`wakeup`, `setrun`), the calculation of
user priorities (`setpri`), the scheduler proper (`sched`, `swapin`),
and the two procedures which create or move a process image in memory
(`newproc`, `expand`). Apart from the C99 dressing the file is v7's, and
it is the clearest place to see that the port changed the machine under
the system rather than the system itself.

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
link register, and `resume` rewrites the entries of the second level page
table `uarea_l2` which map `u` and then discards the TLB.

Note that `lab` is always one of `u.u_rsav`, `u.u_qsav`, or `u.u_ssav`,
that is, an address within `u`. `resume` reads it only after the new
process has been mapped, so that it is the incoming process's copy of
the label which is used. The comment at (417) says as much.

The declaration of `swapin` (11) is new. `sched` (239) calls it before
its definition, which v7 C permitted and C99 does not; no other file
uses it, so the declaration is here and not in #f("systm.h").

A process sleeps on a _channel_: an address which by convention stands
for the event awaited, such as that of the buffer or inode concerned.
Processes which sleep are kept on `SQSIZE` short lists, chained through
`p_link`. `HASH` (14) picks the list from the address of the
channel. The cast to `int` may now give a negative number for a kernel
address with its top bit set, but the mask removes the sign.

#lines(1, 16)

`sleep` records why (`chan`) and how urgently (`pri`) the current process
waits, puts it on the appropriate sleep list, and calls `swtch`.

The processor priority is raised by `spl6` (35) so that no interrupt
handler can call `wakeup` while the proc entry and the list are half
changed. The port keeps v7's names for these routines: on the ARM there
is only one level worth distinguishing, so `spl5`, `spl6`, and `spl7` all
mask the IRQ, `spl0` and `spl1` unmask it, and `splx` restores the state
of the I bit in the value returned by an earlier call, which is the saved
CPSR where the PDP-11 returned its processor status word (#f("mch.s")).
The repeated test of `chan` (40) is v7's.

#lines(17, 45)

If `pri` is above `PZERO`, the sleep may be broken by a signal.
A signal already pending (47) cancels the sleep before it has begun.
Otherwise, if `sched` is waiting on `runin` for a sleeping process to
swap out (55), it is roused, since this process is now such a candidate.
After `swtch` returns, the signal test is repeated (60): a signal is one
of the events which may have ended the sleep, by way of `setrun`.

#lines(46, 67)

A signal is handled by abandoning the system call altogether.
`resume` to `u.u_qsav` with the process's own address is a non-local
goto: control reappears in `trap` as a second return from the
`save(u.u_qsav)` made there before the system call routine was entered,
and `trap` reports `EINTR`. The comment's "trap1/trap.c" refers to v7's
`trap.c`; in this system `trap` is in #f("sysent.c").

Note that callers of `sleep` above `PZERO` are therefore never told that
they were interrupted; any locks they hold must be such that the
abandoned system call leaves nothing inconsistent.

#lines(68, 78)

`wakeup` walks the one list on which processes sleeping on `chan` may
be, unlinks each such process, clears its channel, and hands it to
`setrun`. Several unrelated channels may hash to the same list, hence
the test of `p_wchan` (95). Since `p_link` is reused by `setrun` to put
the process on the run queue, the successor is taken (99, 101) before
`setrun` is called.

#lines(79, 111)

`setrq` adds a process to the run queue `runq`, a list chained through
the same `p_link`: a process is either asleep or runnable, never both.
The search for a duplicate is purely diagnostic, as the comment admits.

`setrq` is now `static`, since only #f("slp.c") calls it; this spares it
a declaration in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand.

#lines(112, 135)

`setrun` is called from interrupt routines, from `wakeup`, and from
places such as `psignal` which wish to rouse a process whatever it is
waiting for. In the last case the process is still on a sleep list, and
`wakeup` of its channel (152) is the correct way to take it off. The
extra parentheses around the assignment (152) only tell the compiler
that `=` is meant.

#lines(136, 157)

If the newly runnable process is more urgent than the current one,
`runrun` asks for a call of `swtch` at the next opportunity, which is the
return from a trap or interrupt to user mode. If `sched` is idle (160)
for want of a runnable swapped-out process, and this is one, `sched` is
woken.

#lines(158, 164)

`setpri` computes the priority with which a user process will compete:
`PUSER`, plus a share of recent processor use (`p_cpu`, which `clock`
increments each tick and decays each second), plus the bias `p_nice`.
The result is never above 127, so that it fits in the `char` `p_pri`.

The `0377` mask (177) undid the sign extension of a PDP-11 `char`. On
the ARM `char` is unsigned and the mask changes nothing, but it is
harmless and is v7's.

The reader may be puzzled that `runrun` is set (181) when the process
whose priority was just computed is better than `curpri`, whereas that
process may not be the current one. `clock` calls `setpri` for every
user process once a second, and it is precisely when one of these has
become more deserving than the running process that a switch is wanted.

#lines(165, 185)

`sched` is the endless loop of process 0, entered from `main` after
`newproc` has made process 1. It moves images between core and the
swap area: it chooses the runnable swapped-out process which has been
out longest (218-223), weighted by `p_nice`, and tries to bring it in.
If there is none, it sleeps on `runout` (229), to be roused by `setrun`
or by `xswap` (#f("text.c")).

If there is no room for the chosen process (239), a victim is sought:
first the largest process sleeping at a priority from which a signal
could rouse it, or stopped by tracing (259); failing that, the process
which has been longest in core. The victim is swapped out only if the
first kind was found, or if the process to be brought in has waited 3
seconds and the victim has had 2 (278); otherwise `sched` sleeps on
`runin`, which `clock` wakes each second and `sleep` (55) wakes when a
candidate appears.

The parentheses added in (259) make explicit v7's reliance on `&&`
binding more tightly than `||`; the meaning is unchanged.

On the PDP-11 this code was in constant use. Here memory is ample, and
in practice the first search always fails or `swapin` succeeds; the
code is kept intact all the same, together with the swap area which
`fork` insists upon.

#lines(186, 287)

`swapin` allocates core for the data area and, if the process has a
shared text segment not yet in core, for the text as well; reads both
in; and releases the swap space. It returns zero, having undone its
allocations, if either `malloc` fails.

In this system no text segment is ever shared: programs are linked as
one writable segment and `getxfile` (#f("sys1.c")) sets the text size
to zero, so `p_textp` is always zero and (303-317) is never executed.
The parentheses (303) are again for the compiler only.

#lines(288, 324)

`qswtch` gives up the processor without sleeping: the current process
is put back on the run queue and `swtch` is called. `trap` uses it when
`runrun` is set.

#lines(325, 337)

`swtch` chooses the next process to run and runs it. As in the sixth
edition it works in three stages and involves, in general, three
processes: the one giving up the processor, process 0, which always
acts as an intermediary, and the one taking it over.

#lines(338, 358)

Unless the caller is process 0 itself, its state is saved in
`u.u_rsav` and process 0 is resumed at `u.u_qsav`. The zero return from
`save` (360) continues on the second branch; the nonzero return comes
much later, when this process is chosen again, and then `sureg`
re-establishes its user mappings before `swtch` returns to its caller.

`savfp` stood for saving the PDP-11/45 floating point registers. The
kernel and the user programs are compiled for soft floating point and
no floating point register is ever in use, so `savfp` in #f("mch.s") is
an empty routine and `u_fpsaved` merely records that it was called.

#lines(359, 369)

The double `save` (381) is explained by its comment. The point to grasp
is that `u.u_qsav` in process 0 marks the entrance to the search loop:
every switch passes through it by the `resume` of (368).

#lines(370, 383)

With interrupts masked, the run queue is searched for the
loaded runnable process of best (lowest) priority, and that process is
removed from the queue. If there is none, `idle` waits for an interrupt
and the search is repeated. On the PDP-11 `idle` executed `wait`; here
it unmasks the IRQ and executes `wfi`.

#lines(384, 416)

The incoming process is resumed at `u.u_rsav` unless it has
`SSWAP` set (420), in which case it is resumed at `u.u_ssav`. The flag is set
by `newproc` (533), by `expand` (573), and by `xexpand` (#f("text.c")),
all of which made an image of a process (on the swap area or in fresh
core) after doing `save(u.u_ssav)`. In such an image `u.u_rsav` is stale:
it was recorded by some earlier switch, or, in `expand`'s case, by the
call of `swtch` from `qswtch` (574), after the image had already been
written. Hence the explicit choice of label.

Note that the ARM `resume` masks interrupts while the mapping and
registers are changed and, like the PDP-11 version, which ended at
priority zero, unmasks them again with `spl0` once the new stack is in
place (#f("mch.s")).

#lines(417, 423)

`newproc` is the body of `fork`, and of the creation of process 1 by
`main`. It returns 1 in the new process and 0 in the old.

#lines(424, 444)

A process id is chosen which is in use neither as a process id
nor as a process group, cycling below 30000. At the same time the first
empty slot of `proc` is noted. `fork` (#f("sys1.c")) has already made
sure that one exists.

#lines(445, 463)

The new entry is filled in, and the reference counts of
everything the child will share with its parent, its open files, text,
and current and root directories, are incremented.

#lines(464, 492)

The child's image is a copy of the parent's, `u` included, made after
the parent has done `save(u.u_ssav)` (508). Before the copy,
`u.u_procp` is set to the child's entry (499), so that the copy differs
from the original in that one respect; the parent restores it (531).

When the child is first chosen by `swtch` its `SSWAP` flag (533) causes
it to be resumed at `u.u_ssav`; its `save` returns 1, and `newproc`
returns 1 to `fork`. The child's kernel stack, being part of `u`, is
copied with the rest, and since `u` always appears at the same virtual
address the stack pointer in the label remains valid.

A word on C. The compiler does not know that `save` may return twice,
since it is declared as an ordinary function (`returns_twice` was tried
and made no difference to the code). This is safe because, in every use
in this file, the second return reads no local variable: it calls
`sureg` and returns a constant. The registers which the callers higher
up the stack expect to find preserved were pushed on that stack before
`save` was reached, and are still there when it returns again. For a while the port declared `p`
`volatile` in case it should be clobbered; since it is not used after
the second return, the qualifier was removed.

#lines(493, 517)

If there is no core for the copy (518), the parent's image is written
to the swap area as the child's image, without freeing the core
(`xswap` with second argument zero). `rpp->p_addr` is pointed at the
parent's core for the purpose, and `SIDL` keeps the parent from being
chosen for swapping in the meanwhile. Otherwise (527) the image is
copied, a click at a time, by `copyseg` (#f("machdep.c")). On the PDP-11
`copyseg` had to borrow a user segmentation register to reach physical
memory; here the kernel maps all of memory, and `CLKADDR` turns a click
number into an address.

The copy is of the whole image, as in v7. An image here is always
large, since `exec` gives every process the full 1 MB user window, so
`fork` copies 16512 clicks; an earlier version of the port copied only
the data area and the stack, but the full copy proved no slower under
QEMU and v7's loop was restored.

#lines(518, 535)

`expand` changes the size of the current process's image to `newsize`
clicks. A shrinking image simply gives back its tail (563). A growing
one is copied into a new area (578), after which `resume` (581)
switches to the copy, whose `save` (566) then returns 1. The comment's
"taking care to reset registers" is a PDP-11 relic in effect: since `u`
and the kernel stack always appear at the same virtual address, the
copy needs no adjustment, and `resume` only has to remap `u` to the new
area; `sureg` then maps the user pages there too.

If there is no core (571), the image is written to the swap area at its
old size `n` but with `p_size` already set to the new one, the old core
is freed, and the process gives up the processor with `SSWAP` set. When
`sched` brings it back, `swapin` allocates the larger size, and the
process resumes at `u.u_ssav` (566) and returns from `expand` as if
nothing had happened. Note that until `swtch` resumes another process it
goes on running in core which is already free; nothing can reallocate
it in that interval, since no interrupt routine allocates core.

The rounding at (557) is new. The ARM memory unit maps pages of 4096
bytes, 64 clicks; `resume` and `sureg` map the image page by page from
`p_addr`, which must therefore lie on a page boundary. By making every
image a whole number of pages, and starting `coremap` on a page
boundary (`startup`, #f("machdep.c")), every allocation and every freed
tail stays page aligned. Callers which compute a size in clicks, such as
`main` for the image of `icode`, rely on the rounding; `grow`
(#f("sig.c")) reads back `p_size` after the call and so sees the rounded
size.

#lines(536, 582)

= Entering the Kernel

#source("/usr/sys/h/reg.h")

When a process enters the kernel, by a system call, an interrupt, or an
exception, its registers are saved on the kernel stack, and `u.u_ar0` is
set to point at the saved `r0`. #f("reg.h") gives the position of every
other saved register as an index from that point, so that the kernel
may write `u.u_ar0[R6]` for the user's stack pointer without knowing how
the frame was built.

In v7 the frame was assembled partly by the PDP-11 hardware (`pc` and
`ps`) and partly by the `call` and `trap` routines of `l.s`, and the
registers did not lie in order: `r1` was two words below `r0`, `r2` to
`r5` further below again, `pc` and `ps` above. Hence v7's indices were
-2, -9, -8, -7, -6, -3, 1, and 2. On the ARM the frame is built by
#f("low.s") in a single order: `r0` to `r12` at indices 0 to 12, the
user's `sp` at 13, its `lr` at 14, the return address at 15, and the
saved status register (`spsr`) at 16. The PDP-11 names are kept for the
registers that have counterparts: `r6` was the stack pointer, so `R6` is
13; `r7` was the program counter, so `R7` and `PC` are both 15; and
`RPS`, which named the processor status word, now names the saved `cpsr`.

Note that `R7` is the PDP-11 `r7`, that is the PC, not the ARM `r7`. The
ARM registers `r6` to `r12` and `lr` have no names here; code which
needs one writes the index, as `trap` (#f("sysent.c")) does with `r[7]`,
the register which holds the system call number.

`TBIT` (17), the PDP-11 trace bit, is kept from v7, though nothing uses
it any longer: the ARM has no equivalent bit in its status register, and
`procxmt` (#f("sig.c")) no longer sets it.

#lines(1, 17)
#source("/usr/sys/h/callo.h")

The callout table holds requests of the form "call `c_func(c_arg)` after
so many clock ticks". It is kept sorted by time, and each `c_time` is
the delay relative to the entry before it, so that the clock interrupt
need only decrement the first non-zero entry (`clock`, #f("clock.c")). An
entry with a null `c_func` ends the list. In this system its only user
is the console driver, which calls `timeout` to have `ttrstrt` resume
output after a delay (#f("pl011.c")).

The only change is the type of `c_func` (15). In v7 it was an `int`
function of unspecified arguments; now it is declared as a `void`
function of one `caddr_t`, which is how `clock` calls it and what
`timeout` accepts, so that every routine placed in the table must have
exactly that type. `ttrstrt` (#f("tty.c")) was changed to take a `caddr_t`
for this reason.

Line 17 defines the table itself in a header, after the v7 manner. This
is legal C99 only because #f("clock.c") is the one file which includes
#f("callo.h"); the headers which many files include declare their
variables `extern` instead (see #f("systm.h")).

#lines(1, 17)
#source("/usr/sys/sys/clock.c")

#f("clock.c") contains `clock`, the handler of the clock interrupt,
`timeout`, by which other parts of the system ask to be called back
later, and, new in this port, `addupc`, the profiling routine.

`addupc`, which `clock` calls before its definition at the end of the
file, is declared in #f("systm.h"), since `trap` (#f("sysent.c")) calls
it too. In v7 it was an assembly routine in `mch.s`.

`SCHMAG` (10) is a fraction written as a bare macro: since `x*SCHMAG`
expands to `x*8/10`, the multiplication is done first and the result is
the integer 0.8`x`. It sets how fast the record of recent processor use
decays (123).

#lines(1, 11)

On the PDP-11 `clock` was entered from the assembler routine `call`, and
its parameters were the words which the hardware and `call` had left on
the stack: the device number, the stack pointer, `r1`, the new PS, `r0`,
and the `pc` and `ps` of the interrupted program. Only the last two were
used. The caller is now `irq` (#f("machdep.c")), an ordinary C
procedure, and `clock` takes just those two: the interrupted `pc`, and
for `ps` either `UMODE` or zero, according to whether the processor was
in user mode.

`clock` runs `HZ` (60) times a second, with interrupts masked, and must
therefore be brief. The list of functions in the comment is v7's; the
second has lost its code.

#lines(12, 35)

v7 restarted the KW11-L line clock by writing 0115 to its status
register (`lks`), and on the larger PDP-11s then copied the console
switch register to the display lights (`display`). There are no
lights, and the second comment has gone with its code.

The ARM generic timer interrupts when its counter reaches the value in
the compare register `CNTV_CVAL`, and the port restarts it, under v7's
comment, by giving it the next such value (#f("mch.s")). `clkcval` is
the deadline of the tick just taken, and the next is `clkreload`
counts later, the counter frequency divided by `HZ` (#f("machdep.c")).
Since each deadline follows from the last and not from the moment the
interrupt was taken, the time spent reaching `clock` never accumulates.
Nor is the remainder of that division lost: the frequency is not in
general a multiple of `HZ` (QEMU's 62.5 MHz leaves 40 over), so
`clkrem` is gathered in `clkfrac`, and each time a whole `HZ` has
gathered, one more count is added to the deadline. Over `HZ` ticks the
deadline advances by exactly the frequency, and the clock keeps the
counter's time. Should interrupts have been masked for longer than a
tick, the new deadline is already past, the timer interrupts again at
once, and the tick is made up rather than lost.

#lines(36, 46)

If the callout list is not empty, the first entry whose time
has not yet expired is charged one tick. Entries already at zero are
waiting to be called, which happens next.

#lines(47, 58)

`BASEPRI(ps)` (63) asked whether the interrupted program had been
running at a raised processor priority. If so, v7 put off the calling of
callouts, and the once-per-second work below, until a later tick, so as
not to run them inside some other, half-finished, interrupt routine. On
the ARM `irq` never passes a `ps` with priority bits, so the test is
always false. This is correct: the clock interrupt can only be taken
when the IRQ is unmasked, which is the state that `spl0` and `spl1`
give, and that is the ARM equivalent of priority zero. A clock tick can
therefore never interrupt a routine which has raised its priority with
`spl5` and above, nor a device interrupt routine.

#lines(59, 69)

Every expired callout is called, in order, with its argument,
and the remainder of the list is then moved down to the front of the
table. `spl5` was meant to lower the PDP-11 priority from 6 to 5,
admitting other clock-level work; on the ARM the IRQ is already masked
and `spl5` changes nothing. The extra parentheses at 78 tell the
compiler that the assignment is meant.

#lines(70, 85)

`out` is reached on every tick. The tick is charged to the current
process as user or system time. If the process is being profiled
(`pr_scale` non-zero), its histogram is incremented at the interrupted
`pc` by `addupc`. The call is v7's; `u_prof` has been given the
structure tag `uprof` (#f("user.h")) so that `addupc` can be declared to
take a pointer to it.

`dk_time` (104) gathers statistics for `iostat`: `a` is formed from the
busy bits of up to three disks (`dk_busy`, which the block drivers set
and clear), plus 8 for a user process of lowered priority, 16 for system
time, and another 8 if the processor was idle. The test for idleness is
that the interrupted `pc` is `waitloc`, the address just after the `wfi`
in `idle` (#f("mch.s")).

`p_cpu` (106), the recent use of the processor, is incremented but not
allowed to wrap round to zero.

#lines(86, 107)

Once a second, when `lbolt` reaches `HZ`, the system's slower duties are
done: `time` is advanced, everyone waiting on `lbolt` is woken, and for
every process the time in its present state (`p_time`, used by `sched`
in #f("slp.c")) is incremented, an `alarm` (`p_clktim`) is counted down
and fires `SIGCLK` when it expires, and `p_cpu` is decayed by the factor
0.8, with the `nice` bias added. User processes have their priorities
recomputed by `setpri`. Finally `sched`, if waiting on `runin`, is
roused.

`runrun` is set (114), so that the current process gives up the
processor at its next return to user mode. This is what makes the
priorities just recomputed take effect against a process which computes
without pause and so never sleeps.

`spl1` (113) unmasks the IRQ. On the PDP-11 it let other interrupts in
while the loop over `proc` was done. Here it does not: the interrupt
controller delivers no further interrupt until `irq` writes the end of
interrupt, after `clock` returns. The `& 0377` (123) undid sign extension
of a PDP-11 `char` and is harmless on the ARM, where `char` is unsigned.

#lines(108, 137)

`timeout` inserts an entry into the callout list. The list
is walked (163--166), the delay of each earlier entry being subtracted from `t`,
until the place is found where the remainder is less than the next
entry's delay. That entry's delay is reduced by `t` (169), since it
will now be counted after the new one. The tail of the list,
including its null terminator, is then moved up one place (170--178) to make room.

The table must keep one slot for the terminator, hence the comparison
with `NCALL-1` (167). The processor priority is raised to the maximum
for the duration, since `clock` changes the same list.

The type of `fun` is now that of `c_func` (#f("callo.h")).

#lines(138, 183)

`addupc` is new as C. v7's was a PDP-11 assembly routine in `mch.s`,
called, as this one is, from `clock` and from `trap`. Given the program
counter `pc`, a pointer `p` to the profile parameters of `u.u_prof`
(buffer base, buffer size in bytes, offset, and scale), and an
increment `t`, it adds `t` to the 16-bit counter which covers `pc`. An
earlier version of the port took `p` as an `unsigned *` and read the
four members as an array; reading the `short *` member `pr_base`
through such a pointer breaks the aliasing rules of C99, and the
members are now named.

The index is (`pc` - offset) × scale / 65536 bytes, made even so as to
select a `short`. As in the assembler, both factors are halved first;
but the product of two 32-bit values may need 64 bits, so it is formed
as an `unsigned long long` (190). An odd byte offset is rounded up to
the next counter, as the PDP-11 code did.

#lines(184, 192)

The counter is read and written with `copyin` and
`copyout`, two bytes at a time, since the user's buffer may be
anywhere. If it cannot be reached, profiling is turned off by clearing
the scale, as v7 did by way of `nofault`.

#lines(193, 199)
#source("/usr/sys/sys/sysent.c")

In v7 #f("sysent.c") held nothing but the table of system calls, and the
procedure which used it, `trap`, lived with the other trap handling in
`trap.c`. In this port `trap.c` is gone and its surviving parts are
here: the table, `regloc`, a much reduced `trap` which handles only
system calls, `user_trap_handler`, which handles every other exception,
and the two dummy calls `nosys` and `nullsys`.

The includes added at 3--5 are among those of v7's `trap.c`; #f("dir.h")
and #f("user.h") for `u`, and #f("reg.h") for the register indices, are
all that `trap` now needs. `EBIT` (6), the carry bit of the saved
status register, is v7's definition from `trap.c`, with the bit's
position in the ARM's `CPSR`.

v7 declared every system call routine here as an `int` function (56
lines, deleted). Now #f("systm.h") declares them all with prototypes, as
`void` functions of no arguments. `nosys` and `nullsys` (7, 8) are v7's,
moved from `trap.c`: `nosys` fails with `EINVAL`, and `nullsys` does
nothing. They are used only in the table, so they are made `static` and
defined before it, which spares them a declaration.

#lines(1, 9)

The table is indexed by system call number. Each entry gives the number
of arguments, the number of them passed in registers, and the routine.
The entries are now in braces, as C99 asks of an array of structures.

On the PDP-11 a system call was the instruction `sys n`, and its
arguments were passed partly in registers and partly as words following
the instruction in the program text: `sy_nrarg`, the second column, was
the number which came in `r0` and `r1`, and the rest were fetched from
the instruction stream. On the ARM all arguments come in registers, so
the two columns are now equal and the counts have been corrected for
the 32-bit word:

- `seek` (19) took four words, since its offset was a two-word `long`;
  now it takes three. `stime` (25) likewise drops from two to one.
- `tell` (40), which is `nosys` in any case, is given no arguments.

Two slots have changed their routine. Slot 56, the multiplexor
`mpxchan`, was in v7 either the real multiplexed file system or the
stub in `fakemx.c`, which failed with `EINVAL`. Neither is part of the
port, and `nosys` gives the same result. Slot 63, which v7 reserved
"for internal use", is now `sigreturn` (#f("machdep.c")), which a
signal handler's trampoline calls to restore the registers which
`sendsig` saved; the PDP-11 needed no such call, since v7's library
returned from a handler with the `rtt` instruction, which reloads both
`pc` and `ps` from the user stack.

#lines(10, 83)

`regloc` maps the PDP-11 register numbers 0 to 7, and the status word,
onto indices in the saved frame (#f("reg.h")). `ptrace` uses it. It
comes from v7's `trap.c`.

#lines(84, 84)

`trap` is called from the `svc` entry in #f("low.s") with a pointer to
the frame of saved registers, with interrupts enabled. It is v7's
system call case, taken out of the switch over trap types, with the
differences which follow.

#lines(85, 95)

The carry bit is cleared (96), as v7 cleared it on entry; it is set
again below if the call fails.

The call number (97) is not fetched from the low six bits of the
`sys` instruction in user memory, but taken from the register `r7`,
where the library stub has put it (`r[7]` is the ARM `r7`, not `R7`,
which is the `pc`). This is the convention of ARM Linux. A number
greater than 63 is reduced modulo 64.

The `sy_narg` arguments are copied from `r0` upwards (98, 99). v7
found its register arguments through `regloc`, and then advanced the
saved `pc` past any inline arguments; there are none here, so the saved
`pc` already addresses the instruction after the `svc`. No entry of the
table asks for more than 4 arguments, within the 5 words of `u_arg`
(#f("user.h")).

Number 0, `indir`, executed the `sys` instruction at an address given
inline, with that instruction's inline arguments. There being no inline
arguments, it is reduced to `nullsys`; `trap` no longer has the special
case for it.

The second return value is preset to the user's `r1` (102), as in v7.
The first is preset to zero (101), where v7 preset it to the user's
`r0`. v7's library stubs cleared `r0` themselves after a call which
returns no value, such as `close` or `chdir`; here every stub returns
`r0` as the kernel leaves it (#f("libc/syscall.s")), and the preset makes
such a call return zero rather than its first argument.

#lines(96, 103)

The call itself is made as in v7. The `save` of `u.u_qsav` provides the point to
which `sleep` (#f("slp.c")) returns when a signal interrupts a system
call, and in that event the call fails with `EINTR`.

An error is reported as in v7 (110--116): the carry bit is set in the
saved status register, and the error number is returned in `r0`. The
library's `cerror` (#f("libc/syscall.s")) tests the carry, stores `r0` in
`errno`, and returns -1. Since the error is not encoded in `r0`, a
successful call may return any value, a `time` after January 2038
among them.

#lines(104, 116)

The common tail of v7's `trap` follows (117--121): any pending signal is acted
upon, the process's priority is recomputed, and if a more deserving
process is waiting the processor is given up.

If the process is being profiled (92, 122, 123), the system time spent
in the call, the ticks which `clock` added to `u_stime` meanwhile, is
charged to the user's `pc`, which is the instruction after the `svc`;
`clock` (#f("clock.c")) charges only ticks in user mode, so without this
a program which spends its time in system calls would show nothing.
This is v7's code, but for the `pc`, which v7 received as a parameter
and here is taken from the frame. v7 finally restored the floating
point registers if `psig` had saved them; there are none to restore,
and that line is gone.

#lines(117, 124)

`user_trap_handler` handles the rest of v7's `trap`: the exceptions
other than `svc`, and the preemption check after an interrupt. It is
called from #f("low.s") with a signal number and the saved frame.

If the exception was not taken in user mode (`0x10`, 128--132), the
kernel itself has faulted, and the system panics, after printing the
faulting address and its cause from the coprocessor registers `DFAR`
and `DFSR`. v7 printed the PDP-11 equivalents.

#lines(125, 132)

Otherwise the signal is posted to the current process and
the same tail as in `trap` is run. A signal number of zero is passed by
the interrupt entry, when `runrun` is set: `psignal` then posts nothing,
and the call serves only to reach the tail, as v7's type 12 trap did.

Most of v7's cases have no counterpart. An undefined instruction gives
`SIGINS` and both kinds of abort `SIGSEG` (#f("low.s")); a breakpoint
instruction also arrives as a prefetch abort, and gives `SIGSEG`, not
`SIGTRC`. There are no `iot` and `emt` instructions, no floating point
exceptions, and no parity registers. A segmentation fault no longer
attempts to grow the stack, since a process's stack already has the
whole of its 1 MB window to grow into (see `grow`, #f("sig.c")).

#lines(133, 141)
#source("/usr/sys/sys/sys1.c")

#f("sys1.c") holds the system calls which make, change, and end
processes: `exec` and `exece`, with their helpers `getxfile` and
`setregs`; `exit` (through `rexit`); `wait`; `fork`; and `sbreak`, which
changes the size of the data area. This is the file in which the port's
departures from the PDP-11 are most visible to user programs, because
it defines the shape of a process image: the format of the executable
file, the layout of the arguments on the stack, and the convention by
which `fork` tells parent from child.

`getxfile` and `setregs` are declared (12, 13) because they are used
before they are defined, and C99 does not allow an undeclared function
to be called.

#lines(1, 14)

`exec` is `exece` with no environment. `exece` first checks that the
file is executable: `access` checks the permission of the caller, and
(47--51) a file must be an ordinary file with at least one of its three
execute bits set, so that the super-user, to whom `access` grants
everything, cannot execute a data file.

The initialisation of `cp` (35) is new; it quiets the compiler, which
cannot see that `cp` is always set (at 90) before it is used.

#lines(15, 51)

The arguments and environment strings must survive the destruction of
the old image, and are too big for the kernel stack, so they are copied
into a temporary area of `NCARGS` bytes on the swap device, one buffer
at a time (`bawrite` does not wait for the write to finish). `na` counts
all the strings, `ne` those of the environment; `nc` is the total of
their lengths. The two lists are walked as one: when `argp` runs out,
`envp` takes over.

A fault in reading either list gives `EFAULT`, and too much gives
`E2BIG`; `bad` then releases the swap area.

#lines(52, 101)

Once `getxfile` has built the new image, the strings are copied back
from the swap area to the top of the new user stack, and a vector of
pointers to them is built below, in the form which the C start-up
routine expects.

#lines(102, 106)

v7 placed the strings at `-nc - NBPW` (107): on the PDP-11 user
addresses were 16 bits, and a negative number named a location below the
top of the 64 KB address space. The ARM user window is `USERSIZE`, 1 MB,
and the strings now end one word below its top. The stack pointer
(`ap`) is rounded down to a multiple of 8, since the ARM procedure call
standard requires that alignment at every call, and `crt0` calls `main`
without adjusting it.

#lines(107, 109)

The new stack, from `ap` upwards, holds the argument count, the
argument pointers and a zero, the environment pointers and a zero, and
then the strings, followed by a zero word at 133. The `0377` mask at 130
is v7's; here `c` is never negative.

#lines(110, 133)

`setregs` then prepares the registers for the new program. At `bad` the
buffer and the swap area are released in every case, success included.

#lines(134, 141)

`getxfile` reads the header of the executable and builds the new image.
Here the port departs furthest from v7. v7 accepted only its own
`a.out` formats, distinguished by the magic numbers listed in the
comment; this kernel accepts only ELF files, which is what the cross
compiler produces, and the comment is a relic. The ELF loader is a
deliberate exception to the port's practice of keeping v7's formats.

#lines(142, 167)

The first 52 bytes of the file, the ELF header, are read
into `u.u_exdata`, whose fields have been rearranged to match it
(#f("user.h")).

#lines(168, 181)

The search which follows is new. If the magic number is that of ELF (`\x7fELF` read as
a little-endian word), the program header table is read, one entry of
32 bytes at a time, at offset `ux_phoff`. The first 24 bytes of each
entry are read over the tail of `u_exdata`, until one of type 1
(`PT_LOAD`), a loadable segment, is found. The programs are linked with
`-N` into one segment holding text and data together, so the first such
header describes the whole program. A file which is not ELF, or which
has no loadable segment, gives `ENOEXEC`.

#lines(182, 195)

The text size is set to zero: no program has a separate,
shareable text segment. This is the ELF form of v7's 0407 executable,
for which v7 also folded the text into the data and set the text size to
zero. In consequence the `ETXTBSY` test which follows can never succeed.

#lines(196, 201)

The data size `ds` (207--213) is measured from address zero to the end
of the segment in memory (`ux_addr` plus `ux_msize`), which takes in the
uninitialised data as v7's sum of `ux_dsize` and `ux_bsize` did. The
check for overflow is changed to fit: a sum of unsigned numbers which
wraps round is smaller than either addend. The stack is given `SSIZE`
clicks plus room for the arguments.

The overlay branch (215--226) is dead, since `overlay` is never set; it
is kept as v7 wrote it, but for the parentheses that make the
precedence of `&&` over `||` explicit (216).

#lines(202, 229)

From line 236 the old image is abandoned. v7 expanded the image
to `USIZE+ds+ss` clicks and cleared it. Here the process is always given
the whole 1 MB window, `USERSIZE>>6` clicks, besides its `USIZE` clicks
of per-process area (238), and all of it is cleared. The uninitialised
data and the stack therefore read as zero, and neither `sbreak` nor the
growth of the stack need ever change the size of the image.

#lines(230, 242)

The segment is read from the file into user space at its
own address, `ux_addr`, from the file offset `ux_off`, for `ux_dsize`
bytes, the size of the segment in the file. v7 read text and data from
just after its header to address zero.

#lines(243, 252)

The set-user-id and set-group-id bits take effect unless
the process is being traced, in which case it is stopped with `SIGTRC`
instead, so that the tracing parent can examine the new image.

#lines(253, 266)

The sizes are recorded and the user mapping set by
`estabur`. Two calls are new. `install_sigtramp` (#f("machdep.c"))
writes the two-instruction trampoline to which signal handlers return.
`arm_sync_icache` (#f("mch.s")) makes the instructions just written
visible to instruction fetch: the ARM has separate instruction and data
caches, and the new program was written through the data cache, while
the instruction cache may still hold the old program's code at the same
addresses. The PDP-11 had no caches to worry about.

#lines(267, 276)

`setregs` first resets to the default the signals that were caught
(287--289), since the handlers no longer exist; signals that were ignored
(value 1) stay ignored. Then the registers are cleared (290--292). v7
cleared those which `regloc` names as `r0` to `r5`: on the PDP-11 every
general register but the stack pointer `r6` and the `pc` `r7`. The port
clears every general register of the ARM in the same way, `r0` to `r12`
and `lr`, all but the stack pointer, which is already set for the new
program, and the `pc`, which is set next; the new program inherits
nothing from the old. When the call returns, `trap` (#f("sysent.c"))
puts `u.u_r.r_val1` and `u.u_r.r_val2` in `r0` and `r1`. The first is
zero, but the second is the caller's `r1`, the old program's argument
pointer, so it is cleared too (293). The `pc` is set to the entry point
with bit 0 cleared (294); on the PDP-11 this ensured an even address. On the
ARM bit 0 of an entry point would select Thumb state, which no program
here uses.

#lines(277, 294)

The floating point save area is cleared, files marked close-on-exec are
closed, and the last component of the name of the file (left in
`u.u_dbuf` by `namei`) is kept for accounting.

#lines(295, 309)

`rexit` is the system call; `exit` is also called by the kernel, from
`psig` and `stop` (#f("sig.c")), with a signal number. The user's code
goes in the high byte of the status and the signal in the low, as
`wait` reports them.

`exit` gives up everything the process holds: signals are all set to be
ignored, so that nothing can interrupt the exit; files, current and root
directories, text, and finally core are released. Note that after
`mfree` (358) the process goes on running on the stack within the
per-process area it has just freed; as in `expand` (#f("slp.c")), this is
safe because nothing can allocate core before `swtch` has chosen
another process.

The process becomes a zombie. Its `proc` entry is reused as an `xproc`
(#f("proc.h")) to hold the exit status and the times, which are all
that the parent will need. Children are handed to `init` (process 1),
which is woken in case it is waiting; stopped children are set running
so that they can die. Finally the parent is woken, and `swtch` is
called, never to return.

#lines(310, 377)

`wait` looks for a child which is a zombie. If it finds one, it
collects the status and times, frees the `proc` entry, and returns the
child's pid and status. A stopped, traced child is reported once, with
the signal which stopped it and the low byte 0177. If there are children
but none is ready, the parent sleeps on its own `proc` entry, which
`exit` (372) and `stop` wake, and looks again. If there are none,
`ECHILD`.

#lines(378, 427)

`fork` checks that the swap area could hold a process of the maximum
size, finds a free `proc` entry, and counts the caller's processes. The
last slot of `proc` is reserved for the super-user, so that he can
still log in and kill something when the table is full.

`newproc` (#f("slp.c")) returns 1 in the child and 0 in the parent, but
the user program must also be told which it is. v7 did it with a trick
which the port keeps. In the child `fork` returns the parent's pid
(469); in the parent it advances the saved `pc` by one word (481), so
that the parent skips the instruction after the `svc`, a branch which
only the child therefore takes. `R7` is the PDP-11's name for the `pc`
(#f("reg.h")), and `NBPW` is now four bytes, the size of an ARM
instruction, as it was two, the size of a PDP-11 one. The library stub
(`fork.s`) is built on it as v7's was: the parent returns the child's
pid, or -1 with `errno` set if the call failed, and the child, at the
branch, stores the parent's pid in `par_uid` and returns 0.

In the child, the times are cleared and `AFORK` marks for accounting a
process which has not yet called `exec`.

#lines(428, 482)

`sbreak` sets the size of the data area. In v7 it went on to change the
size of the process image with `expand`, and since the stack lay above
the data in core, it had to copy the stack up or down, a click at a
time, by the amount of the change, and clear the clicks added. Here the
image already spans the whole window (238), so the routine ends once the
new size has been accepted by `estabur`, which refuses a data area that
would run into the stack (#f("ureg.c")), and recorded. The total size
`n` computed at 506 is no longer used, but the line is v7's.

Nothing is cleared. The memory beyond the old break is the process's
own: `exec` cleared all of it, and `fork` copies the parent's. Clearing
would in fact be wrong, because every address in the window is mapped,
and a program may use memory beyond its break before it asks for it.
The shell does just that, having grown on the PDP-11 by catching the
fault; an earlier version of the port which cleared the added clicks
destroyed data the shell was already using, and the shell hung on long
words.

#lines(483, 512)
#source("/usr/sys/sys/sys4.c")

#f("sys4.c") is a collection of small system calls: those concerned
with time, user and group identity, signals, and a few file operations
which fitted nowhere else. Apart from the dressing of C99 it is v7's.
The one addition is the declaration of `chdirec` (9), which `chdir`
calls before its definition.

Every routine here follows the pattern of a system call: the arguments
are found through `u.u_ap`, overlaid by a local structure `a` which
names them; results go to `u.u_r`, and errors to `u.u_error`.

`gtime` returns the time in seconds. `r_time` is a `time_t` overlaying
the pair `r_val1`, `r_val2`. On the PDP-11 the `long` filled both, and
the time came back in `r0` and `r1`; now it fills `r_val1` alone and
comes back in `r0`. Errors are signalled by the carry bit (`trap`,
#f("sysent.c")), so the call goes on working after the time passes
2,147,483,647 seconds, in January 2038, although a signed `time_t`
then reads as negative.

#lines(1, 23)

`ftime` returns the time with a fraction, read from `lbolt`, the count
of ticks within the current second. Interrupts are masked while `time`
and `lbolt` are read together, so that the clock cannot advance one
without the other between the two reads. The test at 42 allowed for v7's
`clock`, which could let `lbolt` run past `HZ` when it postponed its
once-a-second work; on the ARM that never happens (#f("clock.c")). The
time zone is the one compiled into the system (#f("param.h")).

The structure returned is described in #f("timeb.h").

`stime` sets the time; only the super-user may. The argument is one
word now, where it was two on the PDP-11 (see the table in
#f("sysent.c")).

#lines(24, 66)

Each process has a real and an effective user id, and the same for
groups. `setuid` and `setgid` set both, and are permitted if the new id
is the real one, or to the super-user; a set-user-id program may thus
return to its real identity, but not the other way. `getuid` and
`getgid` return the real id in `r0` and the effective in `r1`; the
library entries `geteuid` and `getegid` pick out the second. `getpid`
likewise returns the parent's id alongside.

#lines(67, 122)

`nice` adds to `p_nice` (#f("proc.h")), the bias to the scheduling
priority which `setpri` (#f("slp.c")) applies. Only the super-user may
make it smaller, and the result is kept within 0 and `2*NZERO-1`.

#lines(123, 149)

`unlink` removes a directory entry. `namei` with flag 2 returns the
parent directory, locked, with the entry's inode number in
`u.u_dent.d_ino` and `u.u_offset` just beyond the entry.

#lines(150, 170)

If the entry names the directory itself, as `.` does, `iget`
would wait forever for the lock which the caller already holds; the
inode is used directly, with its count raised.

Only the super-user may remove an entry for a directory (178), since a
careless unlink can leave the tree inconsistent. An inode on another
device must be a mounted file system's root (183). If the
file is a shared text in use (187--192), `xrele` tries to free it; if it is still
in use and this is its last link, `ETXTBSY`. In this system no text is
shared, and the code is idle.

The entry is cleared (193--199) by writing it back with inode number
zero; the inode loses a link, and is freed by `iput` if it has none left
and is not open.

#lines(171, 205)

`chdir` and `chroot` share `chdirec`, which replaces the inode pointed
to by `ipp`. The new directory is unlocked but keeps the reference
which `namei` took (`prele`, 236); the old one is locked and released.
Only the super-user may change the root.

#lines(206, 246)

`chmod` and `chown` operate through `owner`, which returns the locked
inode only if the caller owns it or is the super-user. Only the
super-user may set the sticky bit (`ISVTX`, 262), which asks that a
program's text be kept on the swap area after its last user has gone; when it is removed,
`xrele` drops any text which was being kept for the file. In v7 only the
super-user may give a file away (281).

#lines(247, 287)

`ssig` is the system call behind `signal`. It sets the disposition of
signal `a`: 0 for the default action, 1 to ignore it, or the address of
a handler, and returns the previous disposition. `SIGKIL` cannot be
changed. Any instance of the signal already pending is discarded (306).

`kill` sends a signal to a process, or (pid 0) to every process in the
caller's process group, or, for the super-user only, (pid -1) to every
process. In the last two cases processes 0 and 1, the scheduler and
`init`, are spared (334). An ordinary user may only signal his own
processes.

#lines(288, 343)

`times` copies out the four times kept in #f("user.h") (`u_utime`,
`u_stime`, `u_cutime`, `u_cstime`), which are declared together so that
one `copyout` serves. `profil` records the parameters of profiling, which
`clock` and `addupc` (#f("clock.c")) use. `alarm` sets the number of
seconds until `SIGCLK`, which `clock` counts down, and returns the
number that were left.

#lines(344, 391)

`pause` sleeps on the address of `u`, on which no one ever calls
`wakeup`. The priority `PSLEP` is above `PZERO`, so a signal ends the
sleep; `sleep` (#f("slp.c")) then does not return here at all, but
abandons the system call through `u.u_qsav`.

`umask` sets the mask applied to the mode of new files and returns the
old one. `utime` sets the access and modification times of a file,
through `iupdat` (#f("iget.c")), from two times in user memory. `ICHG`
makes `iupdat` stamp the change time with the present; that is the one
time which `utime` cannot set, as its comment says.

#lines(392, 446)
#source("/usr/sys/h/timeb.h")

The structure filled in by `ftime` (#f("sys4.c")): the time in seconds,
the milliseconds within the second, the local time zone in minutes west
of Greenwich, and a flag saying whether daylight saving time is
observed. The file is v7's, unchanged.

Its size has changed none the less. On the PDP-11 the four members
occupied 4, 2, 2, and 2 bytes, 10 in all. On the ARM a `time_t` must
lie on a four-byte boundary, so the compiler pads the structure to 12
bytes, so that the next one in an array would be aligned. The kernel
copies out `sizeof(t)` bytes and the library is compiled with the same
header, so the two agree.

#lines(1, 9)
#source("/usr/sys/sys/sig.c")

#f("sig.c") implements signals, which UNIX of this time called
"software interrupts", and the tracing of one process by another,
which is built on them. A signal is sent by setting a bit in the
receiving process's `p_sig` (`psignal`); nothing else happens to the
receiver until it next passes through `trap` or `user_trap_handler`
(#f("sysent.c")), or wakes from an interruptible `sleep`
(#f("slp.c")). There it asks `issig` whether a signal is pending and, if
so, calls `psig` to take the action. A process thus always acts on a
signal itself, and only on its way back to user mode.

The action is one of three, chosen by `u.u_signal[n]` (#f("user.h")):
0, the default, which for most signals is to exit, sometimes with a core
image; 1, to ignore the signal; or otherwise the address of a user
procedure, the handler, which `sendsig` (#f("machdep.c")) arranges to be
called as if by an interrupt.

`core` and `procxmt` are declared (10) since they are called before
their definitions.

#lines(1, 11)

The `ipc` structure carries one request at a time from a tracing parent
to its stopped child. `ip_lock` holds the pid of the child being served,
so that a second parent waits its turn.

#lines(12, 31)

`signal` sends a signal to every process of a process group. Its one caller
is the terminal input routine, for the interrupt and quit characters
(#f("tty.c")). Group 0 belongs to no terminal.

#lines(32, 50)

`psignal` posts the signal. A signal number out of range is ignored,
and so is 0, which posts nothing; `user_trap_handler` passes 0 when it
only wants the tail of trap processing. (64): A process with a poor
priority is given `PUSER`, so that it soon runs and sees the signal.
(66): If it is sleeping at a priority above `PZERO`, it is woken, and
`sleep` will abandon the system call. A process sleeping at `PZERO` or
below, typically waiting for a disk transfer, is left alone, and sees
the signal when it returns to user mode.

#lines(51, 68)

`issig` finds the lowest-numbered pending signal which the process does
not ignore, discarding the ignored ones on the way. A traced process
(`STRC`) stops even for an ignored signal, so that the parent may see
it.

Note the test `u_signal[n]&1` (90). A handler's address is taken to be
even, and the value 1 the only odd one. This held on the PDP-11, where
instructions lay on word boundaries, and holds here, where the programs
are compiled as ARM code (`-marm`) whose instructions are four-byte
aligned. A function in Thumb code has an odd address, and could not be
used as a handler.

#lines(69, 95)

`stop` puts a traced process into the `SSTOP` state, wakes its parent,
which may be waiting in `wait` (#f("sys1.c")), and gives up the processor.
When the parent's `ptrace` sets it running, `procxmt` carries out the
parent's request; the loop continues until a request lets the process
go on. If the parent is `init`, because the tracer has died, there is
no one to serve and the process exits.

`stop` is now `static`: only #f("sig.c") calls it, and so it needs no
prototype in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand of an external function.

#lines(96, 121)

`psig` takes the action for the signal which `issig` found.

`savfp` (137--140) stood for saving the PDP-11's floating point
registers before a handler or a core dump could need them; here it is an
empty routine (#f("mch.s")), kept for form.

#lines(122, 146)

If a handler is set (147--152), it is called through `sendsig`. The
disposition is first reset to the default, so that a second signal
before the handler has re-established itself is fatal; the exceptions are
`SIGINS` and `SIGTRC`, which a debugger or an emulator of missing
instructions would want to catch repeatedly. `u.u_error` is cleared,
since a system call interrupted by the signal has already been
abandoned.

#lines(147, 153)

Otherwise the process exits with the signal number as its
status, and for the signals which indicate a program error, with a core
image as well; the 0200 bit tells `wait` that one was written.

#lines(154, 169)

`fsig` returns the number of the lowest pending signal. Signal `n` is
bit `n-1` of `p_sig`.

#lines(170, 187)

`core` writes the file `core` in the current directory: first the whole
per-process area, `USIZE` clicks, which contains the saved registers,
then the user's memory. It refuses unless the file is an ordinary one
which the user may write, and unless the effective user id equals the
real one, so that a set-user-id program leaves no core image. The
comment above admits that the protection is not thorough.

#lines(188, 223)

For the second write `estabur` maps the whole image as
data, so that `writei` may copy it from user space. On the PDP-11 this
was data and stack, perhaps a few kilobytes. Here the image is always
the full 1 MB window, and every core file is a little over 1 MB long.

`schar` was declared here in v7; it is now declared in #f("systm.h"),
and the line is deleted.

#lines(224, 233)

`grow` extended the PDP-11 stack downward. On that machine the stack
lay at the top of the 64 KB address space, so `-ctob(u.u_ssize)` was the
lowest address of the stack as an unsigned 16-bit number; a reference
below it was a segmentation trap, and `trap` and `sendsig` called `grow`
to enlarge the stack, moving it in core with `copyseg`.

In this port `grow` is never called. The stack starts at the top of the
1 MB window and may run down until it meets the data, all of which is
mapped from the start (`getxfile`, #f("sys1.c")). The routine is kept,
unchanged, though its arithmetic belongs to a 16-bit machine.

#lines(234, 265)

`ptrace` is the parent's side of tracing. A request of 0 (282) is made
by the child, which asks to be traced; usually it does so between `fork`
and `exec`, so that the `exec` stops it (`getxfile`, #f("sys1.c")).
Otherwise the parent names a stopped child of its own. The request is
placed in `ipc`, the child is set running, and the parent sleeps until
the child has taken it (`ip_req` reaches 0) or refused it (-1). The
answer comes back in `ip_data`.

#lines(266, 310)

`procxmt` is the child's side, run in the child's context from `stop`,
so that the child's own address space is the one mapped. It returns 1
when the child is to resume, 0 when it is to wait for another request.

Requests 1 and 2 read a word of the child's instruction and data space.
On the ARM the two are one, and `fuiword` is merely another name for
`fuword` (#f("systm.h")).

#lines(311, 344)

Request 3 reads a word of the per-process area, at a byte offset. The
offset is turned into an index of `int`s by `>>2`, where v7 had `>>1`,
since an `int` is now four bytes, not two. The limit `ctob(USIZE)` has
grown with `USIZE` (#f("param.h")).

#lines(345, 351)

Request 4 writes a word into the program's text, to plant a breakpoint
for instance. v7 had to make a shared text segment private first and
make the text writable for the duration; here there is no shared text
and the window is always writable, so the `p_textp` test does nothing,
and `xrw` of `estabur` is ignored. The parentheses at 359 only tell the
compiler that the assignment is meant.

The second `estabur` has a use of its own, however. The word is stored
through the data cache, and the processor fetches instructions through
its instruction cache, which may still hold the old word. `estabur`
calls `sureg`, which ends in `arm_sync_icache` (#f("mch.s"),
#f("machdep.c")): the data cache is cleaned and the instruction cache
discarded, so the planted instruction is the one executed.

#lines(352, 372)

Request 5 writes a word of data. Request 6 writes a word of the
per-process area, but only in three places: the floating point save
area, a saved register named by `regloc`, or the saved status register.

The `&0377` (388) is new. In v7 the values of `regloc` were negative,
and the PDP-11's signed `char` gave the right index. On the ARM they are
all positive and `char` is unsigned; the mask converts the `char` to an
`int` before it is used as an index, of which the compiler would
otherwise warn, and changes nothing. Note that, as on the PDP-11, only
the registers `r0` to `r5`, the stack pointer, and the `pc` can be
written: `regloc` names no other.

#lines(373, 389)

A new status word must not be allowed to give the child a
privileged mode. v7 forced the PDP-11 current and previous mode bits to
"user" by or-ing in 0170000. Here everything is discarded except the
condition flags (bits 27 to 31) and the `GE` flags (16 to 19), and the
mode field is set to user mode, `0x10` (020). v7's following line, which
cleared the priority bits 5 to 7, is kept; on the ARM it clears the
Thumb bit and the two interrupt masks, which the previous line has
already cleared.

#lines(390, 399)

Request 7 resumes the child, optionally at a new `pc`, with the
pending signals replaced by the one given (or none). v7's request 9,
handled by the same code, also set the PDP-11 trace bit (`TBIT`), so
that the child would trap again after one instruction. The ARM's status
register has no such bit, and single-stepping would need the debug
hardware, so request 9 has been removed, with the comment which
described it: it now reaches `error` like any unknown request, and
`ptrace` (307) fails with `EIO` rather than letting the child
run on as if it had asked for request 7.

Request 8 makes the child exit. The `return` added after `exit` is
never reached; it keeps the compiler, which does not know that `exit`
does not return, from warning that control falls into the next case.

#lines(400, 420)
#source("/usr/sys/h/acct.h")

The record which the kernel appends to the accounting file when a
process exits (`acct`, #f("acct.c")), and which the command `sa`
summarises. The file is v7's, unchanged.

`comp_t` (5) packs a time into 16 bits, as a three-bit exponent of 8
and a thirteen-bit mantissa, which reaches some 17,000 million; `compress` produces it. The user and
system times are in ticks, the elapsed time in seconds; `ac_btime`, the
time of the `fork`, is a date in seconds.

Though no line has changed, the record has. `ac_tty` (17) is a `dev_t`,
which is now an `int` of four bytes (#f("param.h")), where it was two on
the PDP-11; it is placed on a four-byte boundary, and the structure is
padded to a multiple of four. A record is therefore 36 bytes, not 32.
Since `sa` is compiled with the same header, it reads the records
correctly; accounting files from a PDP-11 could not be read.

`acctbuf` and `acctp` are only declared here; the definitions are in
the configuration file generated by `mkconf` (#f("qemu/c.c")). `AFORK`
is set by `fork` and cleared by `exec` (#f("sys1.c")); `ASU` by `suser`
whenever the super-user's privilege is used.

#lines(1, 25)
#source("/usr/sys/sys/acct.c")

#f("acct.c") holds process accounting, which is new since the sixth
edition, and the unrelated `syslock`. The file is v7's. `compress` is
declared (9) because `acct` calls it before its definition.

#lines(1, 10)

`sysacct` turns accounting on, naming the file to which records are to
be appended, or off, given a null name. Only the super-user may do
either. The file must exist and be an ordinary file. Its inode is kept
in `acctp`, with the reference which `namei` took but unlocked
(`prele`), for as long as accounting is on.

#lines(11, 48)

`acct` is called by `exit` (#f("sys1.c")), after the process has closed
its files but while its `u` is still intact, and writes one record
(#f("acct.h")) at the end of the accounting file. The command name was
saved by `exec`; the user and system times are in ticks, the elapsed
time in seconds. `ac_mem` and `ac_io` are always zero, here as in v7.

The cast at 63 is new: `sizeof` yields an unsigned value, and the
compiler warns of a comparison between it and the signed `i`.

#lines(49, 74)

If the write fails, perhaps for want of space, the file's
size is set back, so that no partial record remains. The inode is
locked throughout with `plock`, since several processes may be exiting
at once.

#lines(75, 85)

`compress` converts a count to the 16-bit `comp_t`. While the value
needs more than thirteen bits, it is divided by 8 and the exponent
raised; `round` keeps the highest bit shifted out by the last division,
which is the half, so that the result is rounded to the nearest. If the
rounding carries into a fourteenth bit, one more division is needed.

#lines(86, 109)

`syslock` sets or clears `SULOCK` (#f("proc.h")) for the calling
process, which keeps `sched` (#f("slp.c")) from choosing it to be swapped
out. Only the super-user may use it. `exit` clears the flag.

#lines(110, 131)

= Disks and Shared Text

#source("/usr/sys/h/text.h")

A program whose text is "pure", that is, never written, may be shared by
every process which executes it. One copy is kept in core while any of
those processes is in core, and one copy on the swap device for as long
as any of them exists. The `text` table records each such segment; a
process finds its entry through `p_textp` (#f("proc.h")).

`x_daddr` (9) is the block number of the swap copy, counted from
`swplo`. `x_caddr` (10) is the click number of the core copy. `x_count`
(13) is the number of processes which use the text at all, and
`x_ccount` (14) the number of those which are in core: the core copy may
be freed when the second reaches zero, the swap copy only when the first
does.

`x_caddr` has been widened from `short` to `int`, for the reason already
given for `p_addr` in #f("proc.h"): a click number counted from
`corebase` no longer fits in sixteen bits. `x_daddr` and `x_size` stay
`short`, since the swap area (872 blocks) and a text, which could be at
most the 1 MB user window, both fit.

`XLOAD` (22) says that the core copy is being read from the file and has
no counterpart on the swap device yet; `XWRIT` (21) that the swap copy
must be written when the core copy is next given up. `XLOCK` and `XWANT`
(23, 24) are the usual pair: a lock, and a request to be woken when it is
released.

Note that the whole mechanism lies idle in this port. Programs are
loaded as a single writable segment and `exec` sets the text size to
zero (#f("sys1.c")), so no entry of `text` is ever filled. The table and
the file which manages it are kept because the rest of v7 refers to them.

#lines(1, 24)
#source("/usr/sys/sys/text.c")

#f("text.c") manages the `text` table of #f("text.h"), and holds besides
the one procedure, `xswap`, by which a process image is written to the
swap device.

Apart from `xswap`, nothing in the file does any work in this port:
every process has a text size of zero (#f("sys1.c")), so `p_textp` is
always `NULL`, `xalloc` returns at its first test, and `xfree` and
`xccdec` at theirs. The code is v7's, and is read here for what it
would do if a shared text were ever made.

The declaration of three procedures (11, 12) is new. Each is used in
this file before its definition, which C99 does not allow without a
prototype, and no other file calls them. The procedures which other
files call are declared in #f("systm.h").

#lines(1, 13)

`xswap` writes process `p` to the swap device. `os` is the size of the
image in core; it differs from `p_size` only when `expand` (#f("slp.c"))
swaps out a process whose size has already been increased, in which case
the space allocated on the swap device is for the new size (31) while
only the old size is written (36).

#lines(14, 33)

`SLOCK` (34) keeps `sched` from choosing the process as a victim while
the write is in progress. The process's claim on the core copy of
its text is given up (35); if it was the last process in core using that
text, the core copy is freed, having first been written out if `XWRIT`
says the swap copy is stale. The core is freed (37) unless `ff` is zero,
which is the case when `newproc` makes the child's image on the swap
device from the parent's core, which the parent goes on using.

`p_addr` now holds a swap block number and `SLOAD` is cleared; `p_time`
restarts, since `sched` measures how long a process has been out. If
`sched` is waiting on `runout` for something to bring in, this process
is now such a thing.

Note that `swap` (#f("bio.c")) sleeps until the transfer is complete, so
that `xswap` returns only when the image is safely on the disk.

#lines(34, 46)

`xfree` is called by `exit` and `exec` to detach the current process
from its text. The lock is taken (60) only to wait for anyone else
working on the entry; it is dropped again at once (61), without the
wakeup which `xunlock` would give. None is needed: no other process can
have asked for the lock in the moment since `xlock` returned, for this
one has not slept in between.

If this was the last user and the text is not "sticky" (64), the entry
is emptied: swap copy and core copy are freed and the inode released.
The test of `ILOCK` (69) protects a caller's lock: `exec` calls `xfree`
while it holds the lock on the inode of the new program, which may be
this very inode, and `iput` ends by unlocking the inode it is given
(`prele`, #f("iget.c")). If the inode is locked, the count is merely
decremented, and the lock is left to its owner.

A sticky text (mode bit `ISVTX`, #f("inode.h")) keeps its swap copy after
the last user has gone, so that the next `exec` of the same program need
not read the file. In that case, as in the case of other users remaining,
only the in-core count is decremented (74).

#lines(47, 75)

`xalloc` is called by `exec` after the new program's header has been
read into `u.u_exdata`. With a text size of zero it returns at once (94),
and in this port it always does.

#lines(76, 96)

The table is searched both for an entry already holding the
text of inode `ip`, and for the first free entry. If the text is found,
the process becomes another user: if no other user is in core, the core
copy is brought in from the swap device by `xexpand` (108).

#lines(97, 114)

If the table is full, the process is killed.

#lines(115, 119)

Otherwise the free entry is claimed, with `XLOAD` set to show
that its contents come from the file rather than from the swap device,
and swap space and core are allocated. The user mapping is then
set up with the text segment only (132--139), writable for the moment, and the text
is read from the file into it; `u_segflg` 2 directs `readi` to
instruction space, which on the ARM is the same as data space. `XWRIT` (141) then ensures that the swap copy is
written when the core copy is first given up.

#lines(120, 142)

`xexpand` obtains core for a text which has none. If core is available,
the text is read in from its swap copy, unless `XLOAD` says it is about
to be read from the file instead.

If not, the process makes room for itself by swapping itself out
(164), and leaves the matter to `sched`, which brings in data area and
text together (`swapin`, #f("slp.c")). The pattern is that of `expand`:
`save(u.u_ssav)` (160) is the point to which the process returns, by way
of `SSWAP` and `swtch`, once it is back in core; it then reloads its
user mapping with `sureg` and returns. `qswtch` (167) does not return.

#lines(143, 169)

The lock on a text entry. `xlock` sleeps at `PSWP`, a priority at which
no signal can interrupt it.

#lines(170, 192)

`xccdec` is called when a process using a text leaves core, by being
swapped out or by giving up the text. When the last such process has
gone, the core copy is freed, but first written to the swap device if
it has never been written there (`XWRIT`).

#lines(193, 213)

`xumount` is called by `umount` (#f("sys3.c")): a file system cannot be
unmounted while a sticky text from it holds its inode. `xrele` is called
when write access to a file is checked (`access`, #f("fio.c")), when the
file is unlinked, and when `chmod` clears its sticky bit (#f("sys4.c")):
a text which no process is using should not hold the inode, nor survive
a change to the file. Both pass the work to `xuntext`, which empties the
entry only if no process uses it (254).

The test in `xrele` (237) has gained parentheses. v7 wrote
`ip->i_flag&ITEXT==0`, which C parses as `ip->i_flag & (ITEXT==0)`,
which is always zero, so that v7 never took the early return and always
searched the table. The search finds nothing for an inode without
`ITEXT`, so the bug cost only time; the port writes what was meant.

#lines(214, 267)
#source("/usr/sys/h/buf.h")

#f("buf.h") is unchanged from v7. Each `buf` is a header which describes
a block transfer: the device and block number, the core address, and the
byte count, and the state of the operation in `b_flags`. The data itself
lies elsewhere: for an entry of the array `buf`, which forms the buffer
cache, in the rows of `buffers` (#f("main.c")), to which
`binit` points `b_addr`; for the headers used by `swap` and `physio`
(#f("bio.c")), in the process image being transferred.

The head of a driver's lists is itself a `buf`, the `d_tab` of the
driver's `bdevsw` entry (#f("conf.h")), and the names at the end of the
file (69--72) rename those fields of it which serve another purpose
there: `b_actf` and `b_actl` are the head and tail of the queue of
requests, `b_active` says that the device is busy, and `b_errcnt` counts
retries. A header on that queue is linked through `av_forw`, which is
free for the purpose, since a busy buffer is not on the available list.

Two lists thread the cache. `b_forw` and `b_back` link every buffer to
the device with which it is associated, so that `getblk` can find a
block by searching one short list; `av_forw` and `av_back` link the
buffers which are not busy, in the order in which they were released, so
that the one least recently used is at the front. The comment (1--20)
states the rules.

`b_xmem` (38) held the high-order bits of the 18- or 22-bit PDP-11
physical address, of which `b_addr` held only the low sixteen. On the
ARM `b_addr` is a full 32-bit address; `b_xmem` is still set by `swap`
and `physio` but read by no driver. `b_un` (30--36) lets the same
address be used as a pointer to whatever the block contains.

#lines(1, 45)

The flags. `B_DONE` means that the contents are valid, `B_BUSY` that
some process or the driver owns the buffer, and `B_DELWRI` that the
contents are newer than the disk and must be written before the buffer
is reused. `B_AGE` puts a buffer at the front of the available list
rather than the back, so that it is reused first. `B_PHYS` and `B_MAP`
concern the UNIBUS map of the PDP-11/70, which `mapalloc`
(#f("machdep.c")) still sets up only on that processor; here it never
does. `B_TAPE` is set in the `d_tab` of a magnetic tape driver, of
which there is none. `B_PBUSY` and `B_PACK` are used by no file of
this system.

#lines(46, 72)
#source("/usr/sys/h/conf.h")

#f("conf.h") declares the switches through which the rest of the system
reaches the device drivers. A device number has two parts: the major
number, which selects an entry of `bdevsw` or `cdevsw`, and so a
driver; and the minor number, which the driver interprets as it pleases.
Neither the file system nor #f("bio.c") knows any driver by name. The tables
themselves are defined in the `c.c` which `mkconf` generates for each
configuration (#f("qemu/c.c")); the comment's `conf.c` is the sixth
edition's name for that file, which v7's `mkconf` already wrote as
`c.c`.

A block device needs only `open`, `close`, and a strategy routine, which
accepts a `buf` and queues it for transfer, and the head of the driver's
queue, `d_tab` (#f("buf.h")). A character device has `read` and `write`,
which take their arguments from `u` (`u_base`, `u_count`, and
`u_offset`), an `ioctl`, and, for terminals, `d_stop` and the array of
`tty` structures. The line switch `linesw` gives the procedures of a line
discipline, the processing between a terminal's driver and the user,
which #f("tty.c") supplies for the one discipline there is.

In v7 every entry was declared as a pointer to a function returning
`int`, with its arguments unspecified, and the tables were filled with
whatever routine came to hand, `nodev` and `nulldev` included. Here each
pointer has a full prototype, so that the compiler checks every entry of
the tables and every call through them. Most of the routines return
nothing and are declared `void`; `l_read`, `l_meta`, and `l_modem`
return `int`, and `l_write` keeps v7's `char *`. A routine of the wrong
type no longer fits a slot, which is why the generated tables use
`nostrat`, `nordwr`, `noioctl`, `nolioctl`, and `nulltty` (#f("subr.c"))
where v7 used `nodev` and `nulldev` for everything.

The incomplete declarations of `struct buf` and `struct tty` (10, 11)
are new. A structure first named inside a prototype is local to that
prototype, and would not be the same type as the one defined later in
#f("buf.h") or #f("tty.h"); declaring the tags first at file level makes
them so, whether or not those headers have been included.

#lines(1, 49)

`struct intr` is new. It is the type of `intrtab` in the generated
#f("qemu/c.c"), which pairs each interrupting device with its handler,
as the PDP-11's interrupt vectors in `l.s` did. `i_irq` points to the
driver's variable holding its interrupt number, rather than holding the
number itself, because a driver may learn its number only when it finds
its device: the virtio disk (#f("virtio_blk.c")) does. `clkstart` and
`irq` (#f("machdep.c")) enable and dispatch interrupts from the table.

#lines(50, 55)
#source("/usr/sys/conf/qemu/c.c")

This file is not written by hand. `mkconf` (#f("mkconf.c")) reads a
short description of the machine, #f("qemuconf") for the QEMU `virt`
board, and writes `c.c`, which holds the device switches declared in
#f("conf.h"), the choice of root and swap devices, the principal tables
of the system, and, new in this port, the facts about the board which
differ between QEMU and the MP135 (#f("mp135/c.c")). Everything else in
the kernel is the same for both boards; the board is chosen by linking
with one `c.c` or the other.

v7 generated its `c.c` in the same way, with a companion `l.s` holding
the PDP-11 interrupt vectors. The port has no `l.s`: its interrupt
vectors are fixed (#f("low.s")), and the routing of interrupts to drivers
is the table `intrtab` at the end of this file.

The includes are v7's, with #f("seg.h") added for `struct memregion`
and the `SEC_` attributes used below. v7's copy declared every driver
routine it named, as `int nodev();` and the like; here all of them are
declared with prototypes in #f("systm.h"), which is already included,
and the declarations are gone.

#lines(1, 14)

The block device switch. `mkconf` lists every block device it knows,
in a fixed order, so that a device keeps its major number whatever the
configuration: `rk` is always 0. A device which is configured gets its
driver's entry; one which is not gets an entry which fails. Only `rk` is
configured here, and the routines named `rk` are those of the virtio
disk driver (#f("virtio_blk.c")), which took v7's names so that
`mkconf`'s table could be used unchanged. On the MP135 the same entry
names the routines of the SD card driver, #f("stm32sd.c"), which took
v7's names too; each board's kernel links only its own driver.

Note the braces around each row, without which `-Wall` warns that a
structure within an array is initialised without its own braces, and `nostrat` where v7 wrote
`nodev`: the strategy slot now has a type of its own (#f("conf.h")).
v7's configuration also had the TU16 magnetic tape, `ht`, at major 7.

`rktab` (15) is the head of the disk's queue. v7's `c.c` defined it,
and so did `rk.c`, and the loader merged the two definitions into one
common symbol. Here `c.c` only takes its address, and declares it
`extern`; the one definition is in the driver (#f("virtio_blk.c")), as
in `rk.c`.

#lines(15, 29)

The character device switch, in the same manner. The console (major 0),
memory (8), the raw disk (9), and the controlling terminal `tty` (17)
are configured. Of these only the disk is named in #f("qemuconf"):
`mkconf` always includes the console, memory, and `tty`. The console's routines are named `kl`, after the
PDP-11's KL11 interface, and are those of #f("pl011.c").

The raw disk entry uses `rkread` and `rkwrite`, which call `physio`
(#f("bio.c")) with the disk's strategy routine. v7's `nodev` in the
`ioctl` slot becomes `noioctl`, and v7's `nulldev` in `d_stop` becomes
`nulltty`, again because the slots now have types.

#lines(30, 54)

The one line discipline, that of #f("tty.c"). In v7 the row was
`ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart`, which put
`ttstart` in the seventh slot, `l_rend`, though the structure names a
later slot `l_start` for it. Nothing calls either slot for this
discipline, so the mistake was harmless; the port puts `ttstart` where
its name says. `nolioctl` replaces `nodev` in `l_ioctl`.

#lines(55, 59)

Root, swap, and pipe devices are all minor device 0 of major device 0,
the one disk. The file system occupies its first 10648 blocks
(#f("rootfs.proto")), and the swap area is the 872 blocks after it,
from `swplo`. This is the arrangement of v7's own RK05 configuration,
where `swplo` was 4000 and the swap area ended at block 4872, the end
of the pack; putting the swap area after the file system keeps it clear
of the superblock, the block which describes a file system as a whole,
in block 1.

#lines(60, 65)

The main tables of the system are defined here rather than in the files
which use them, so that their sizes are visibly a matter of
configuration. v7 also defined here `ldmpx`, a pointer to `mpxchan`,
for its multiplexed files; the port carries neither the multiplexor
(`mx1.c`, `mx2.c`) nor its stub `fakemx.c`, and the definition is gone.

#lines(66, 75)

From here on the file is new: the facts about the board, taken from
lines of #f("qemuconf") which v7's format did not have.

`kernbase` (76) is the address at which the kernel is loaded, at the
start of QEMU's memory. `corebase` and `coretop` (77) bound the memory
which `startup` (#f("machdep.c")) gives to `coremap` for process images:
the 64 MB above the first 64 MB, which hold the kernel. Click numbers
in `p_addr` count from `corebase` (`CLKADDR`, #f("seg.h")). `pguser`
(78) holds the attribute bits of the second-level page table entries
which map user pages: readable and writable in user mode, executable,
and cacheable. `gicdbase` and `giccbase` (79) locate the distributor and
the processor interface of the ARM generic interrupt controller.

`board_map` (81) lists the regions which the kernel maps one-to-one in
1 MB sections before it turns on the MMU (`machine_init`,
#f("machdep.c")): all of memory, as cacheable kernel memory, and the
64 MB from `0x08000000` in which QEMU places its devices (the interrupt
controller, the UART, and the virtio transports), as device memory
which may not be executed. Because memory is mapped at its own address,
an address in the kernel is also a physical address, which is what a
device performing DMA requires (#f("virtio_blk.c")).

#lines(76, 87)

`intrtab` (89) pairs each configured interrupting device with its
handler (`struct intr`, #f("conf.h")): the console and the disk. The
number is reached through a pointer, since the disk driver learns its
own only when it finds the device. The clock is not in the table; it is
handled by `irq` itself.

The three procedures at the end are the glue by which the
machine-dependent code calls the configured drivers without naming
them: `cninit` sets up the console early in `machine_init`, `bdinit`
finds the disk at the end of `startup`, and `clock_ddr_init`, which on
the MP135 starts the memory controller (#f("stm32ddr.c")), does nothing
here, since QEMU's memory needs no initialisation. `putchar`, the
console output of `printf` (#f("prf.c")), needs no glue: the console
driver defines it under v7's name (#f("pl011.c")).

#lines(88, 98)
#source("/usr/sys/dev/virtio_blk.c")

This is the disk driver for the QEMU `virt` board. It replaces v7's
`rk.c`, the driver for the RK05 cartridge disk, and takes over its
names (`rkstrategy`, `rkintr`, `rktab`, and so on), its configuration
entry in `mkconf` (#f("qemu/c.c")), and as much of its text as the new
device allows. The reader who compares the two files will find the same
three procedures doing the same three jobs. `rkstrategy` adds a request
to the queue and starts the device if it is idle; `rkstart` gives the
request at the head of the queue to the device; `rkintr`, called when
the device has finished, completes that request and starts the next.
Only one request is in the device at a time. The new procedure, `rkinit`,
finds and prepares the device, which an RK11 never needed. Even v7's
heading comment (2) is kept, since the driver is configured as `rk`.

The device is a "virtio" block device, an interface designed for
virtual machines rather than for hardware. QEMU provides up to 32 virtio
transports, each a block of registers 0x200 bytes long, from address
`0x0a000000`. The driver uses the original ("legacy") form of the
interface. Requests are passed through a "virtqueue" in the machine's
memory: a table of descriptors, each giving the address and length of
a piece of memory; an "available" ring, in which the driver places the
first descriptor of each new request; and a "used" ring, in which the
device returns the requests it has finished.

#lines(1, 11)

v7's `RKADDR`, the RK11's registers as a `struct device` at `0177400`,
is now (12) the register at offset `off` of the transport which
`rkinit` has found, at `vbase`; the `struct device` is deleted.
`NRKBLK`, the size of a pack (14), is now the size of the disk, which
the device gives in 512-byte sectors in the first word of its
configuration space, at offset `0x100`. The rest of v7's definitions
are kept, although nothing uses them: `NRK`, the number of drives (13),
and the RK11's command and status bits (16--25). `NVQ` (26) is the number of
descriptors in the virtqueue; a request needs three.

#lines(12, 32)

`struct vring` (33) lays out the virtqueue as the legacy interface
requires. Each descriptor has a
64-bit address, of which the ARM fills only the low word, a length,
flags, and the index of the next descriptor of a chain. The available
ring follows the descriptors, and the used ring begins at the next
multiple of 4096 bytes, the alignment which `rkinit` gives the device,
as the legacy interface prescribes; `pad` (45) fills the space between.
Each element of the used ring is a pair of words, hence `2*NVQ`. The
specification puts one more halfword after `aring`, which is not
declared, and QEMU leaves it out when it computes where the used ring
lies; with an alignment of four the two would have differed by a word,
but rounded up to 4096 bytes both arrive at the same place.

The declaration of `rkstart` (51) is new, needed because `rkstrategy`
calls it before its definition. `vqbuf` (55) is reserved with 4095
bytes to spare, so that `rkinit` can
place the virtqueue on a page boundary within it, as the legacy
interface demands. `vreq` is the header of a request: its type, read or
write, and the sector, which counts 512-byte units, so that a block
number serves unchanged. `vstatus` receives the device's report, zero
for success. One of each suffices, since the driver has only one
request in the device at a time. `rktab` and `rrkbuf` are v7's.

#lines(33, 64)

`rkinit` is called by `bdinit` (#f("qemu/c.c")) at the end of `startup`.
Each transport is examined for the magic number `virt` (as a
little-endian word) and a device type of 2, a block device; an empty
transport reports type 0.

#lines(65, 72)

The device is acknowledged and told that a driver exists, by writing 1
and then 3 to the status register (73, 74). The
virtqueue is then described to the device (75--79): the page size, the number of
descriptors, the alignment of the used ring, and the page number of the
ring itself. `vq` is the address rounded up to a page; since the kernel
maps memory at its own address (#f("qemu/c.c")), the same number serves
as the physical address which the device needs. Status 7 (80) says the
driver is ready.

The interrupt of the n-th transport (81) is shared peripheral
interrupt 16 + n of the interrupt controller, number 48 + n. `intrtab`
reaches `rkirq` through a pointer for that reason, and `clkstart`
(#f("machdep.c")), which enables the interrupts in the table, runs after
`rkinit`.

Several things are left as they are found. The queue selection
register is not written, since queue 0, the only one, is selected after
a reset. `aflags` is zero, which asks for an interrupt on each
completion; and every entry of `aring`, which names the first descriptor
of a request, is zero, which is right, since every request starts at
descriptor 0. Both lie in `vqbuf`, which is zero, being uninitialised
data.

#lines(73, 83)

`rkstrategy` is v7's. A block number beyond the end of the disk is
rejected at once (90--94), as v7 rejected one beyond the end of the
pack. Such requests arise: `breada` (#f("bio.c")) reads ahead the block
after the last, and without the check the device would fail the
request and `rkintr` would report and retry it ten times.

The call of `mapalloc`, for the UNIBUS map of the PDP-11/70, is kept; it
returns at once, since `cputype` is never 70 (#f("machdep.c")). The
priority is raised with `spl5` and lowered with `spl0`, as in v7: the
routine is called at process level. During startup `spl0` leaves
interrupts masked until `clkstart` has set `irq_ready` (#f("mch.s")).

The queue is that of v7, threaded through `av_forw` and headed in
`rktab` (#f("buf.h")).

#lines(84, 106)

`rkstart` gives the request at the head of the queue to the device. v7
computed the drive, cylinder, and sector, and loaded four registers,
the last of which started the transfer; the port fills in a chain of
three descriptors: the header `vreq` (116--121), which the device reads;
the data (122--125), which the device writes on a read (flags 3, "next"
and "device writes") and reads on a write (flag 1); and the status byte
(126--128), which the device writes.

The minor device number, which v7 used to choose one of four drives, is
ignored: there is one disk.

#lines(107, 128)

The barrier `dmbsy` (#f("mch.s")) ensures that the device
sees the descriptors before the incremented index of the available ring,
and the index before the write of the queue number to the notify
register, which starts the device. No cache need be cleaned for the
data, since QEMU's device reads and writes the same memory the processor
sees.

The remaining lines are v7's: they record the transfer for `iostat`.
`dk_wds` is counted in units of 32 PDP-11 words, 64 bytes, since
`iostat` multiplies it by 32.

#lines(129, 138)

`rkintr` is called by `irq` (#f("machdep.c")) when the disk interrupts.
The interrupt is acknowledged by writing back the bits read from
the interrupt status register (144). It is ignored if no
request is outstanding, as in v7, or if the device has not yet returned
it in the used ring. The barrier (147) keeps the processor from reading
`vstatus` or the data before it has seen the device's index.

#lines(139, 147)

An error is reported by a nonzero status byte. v7 reported the
RK11's error and drive status registers by `deverror` (#f("prf.c")),
then reset the controller and waited for it; the port reports the status
and has nothing to reset. The retry, up to ten times, and the remainder
of the procedure are v7's: the request is taken off the queue, completed
by `iodone` (#f("bio.c")), and the next is started.

#lines(148, 165)

The raw disk, `cdevsw` entry 9, transfers directly between the disk and
the user's memory by way of `physio` (#f("bio.c")), using the private
header `rrkbuf`.

#lines(166, 178)
#source("/usr/sys/dev/bio.c")

#f("bio.c") holds the buffer cache and the other routines which stand
between the rest of the system and the block device drivers. The file
system never calls a driver: it asks for a block by device and number
(`bread`, `getblk`), changes the buffer it receives, and gives it back
in one of four ways (`bwrite`, `bdwrite`, `bawrite`, `brelse`). Whether
any transfer takes place, and when, is decided here. The file also holds
`swap`, which moves process images, and `physio`, which moves data
between a device and a user's memory without passing it through the
cache.

The file is v7's but for the dressing of C99 and two places which
computed PDP-11 physical addresses, in `swap` and `physio`. The
declarations at (9--11) are new: each of these procedures is called
before its definition and only within this file.

#lines(1, 11)

`DISKMON` compiles in the counters of `io_info`, which `iostat` reads
from `/dev/kmem`: reads, read-aheads, cache hits, and writes, and in
`bufcount` how deep in the available list each buffer found in the
cache was.

Two headers, `swbuf1` and `swbuf2`, serve `swap`, so that two transfers
of process images may be queued at once.

#lines(12, 33)

`bread` returns a busy buffer holding the block. If `getblk` finds that
the buffer already holds valid data (`B_DONE`), nothing more need be
done; otherwise a read is queued by the strategy routine and `iowait`
sleeps until it is complete.

#lines(34, 78)

`breada` is used by `readi` (#f("rdwri.c")) when a file is read
sequentially: besides the block wanted, it starts the reading of the
next one, `rablkno`, without waiting for it.

#lines(79, 89)

If no buffer is associated with the wanted block (90), one is taken and
its read is started. If one is, it may be busy, and `getblk` would sleep
on it; `incore` lets `breada` pass it by, leave `bp` null, and start the
read-ahead first. Only then (115) does `bread` obtain the wanted block,
sleeping if it must. The read-ahead buffer is marked `B_ASYNC`, so that
`iodone` releases it when its transfer is done; no one waits for it.

#lines(90, 118)

`bwrite` queues a write and, unless it is asynchronous, waits for it and
releases the buffer. The flags are cleared before the write is queued,
the old value being kept in `flag`. An asynchronous write of a delayed
write block (139) is the case of a buffer reclaimed by `getblk` or
pushed out by `bflush`; it is marked `B_AGE`, so that when `iodone`
releases it the buffer goes to the front of the available list, to be
reused first.
Only an error in starting a plain asynchronous write can be reported
(142), since the process which caused a delayed write may be gone.

#lines(119, 143)

`bdwrite` marks the buffer to be written later, when it is taken for
another block or when `bflush` runs; a block which is written a little
at a time is then written once. A tape, whose blocks must be written in
order, is written at once; no tape driver is configured in this system.
`bawrite` starts the write without waiting.

#lines(144, 176)

`brelse` returns a buffer to the available list. Those waiting for this
buffer, and those waiting for any buffer, are woken. A buffer whose
transfer failed is detached from its device (194), so that its contents
will not be found again by `getblk`. A buffer marked `B_AGE` goes to the
head of the list, others to the tail; the head is where `getblk` takes
buffers from, so the list is in order of least recent use.

The list is changed with interrupts masked, since `iodone`, called from
an interrupt routine, may call `brelse` for an asynchronous transfer.

#lines(177, 211)

`incore` says whether some buffer is associated with the block, valid
or not.

#lines(212, 228)

`getblk` is the heart of the cache. The major device number is
first checked (244) against `nblkdev`, the number of entries in `bdevsw`, which
`binit` (#f("main.c")) counts; an entry whose `d_tab` is null (251) is a
device which is not configured.

#lines(229, 251)

The device's list is searched for the block. If the buffer
is busy, the caller sleeps, and searches again when woken, since the
buffer may meanwhile have been given to another block. Otherwise the
buffer is taken from the available list (`notavail`). The interval
between the test of `B_BUSY` (256) and the sleep is protected by `spl6`,
since an interrupt could otherwise release the buffer and issue its
wakeup before the sleep began, and the sleeper would never be woken.

#lines(252, 274)

If the block is not in the cache, the buffer at the head of the
available list is taken; if it holds a delayed write, the write is
started and the search begun again. The buffer is moved from the list of
its old device to that of the new, and given its new identity. Note that
`B_DONE` is not set, which tells `bread` that the block must be read.

#lines(275, 298)

`geteblk` obtains a buffer associated with no device. It holds the
in-core copy of a mounted file system's superblock (`iinit`,
#f("main.c"); `smount`, #f("sys3.c")), and the zeros which `readi`
returns for a hole in a file. It is placed on the list of `bfreelist`, which serves as
the device list for `NODEV`.

#lines(299, 333)

`iowait` sleeps until the transfer on a buffer is complete, then passes
any error to `u.u_error` (`geterror`). `notavail` removes a buffer from
the available list and marks it busy.

#lines(334, 364)

`iodone` is called by a driver's interrupt routine when a transfer
finishes. It frees the UNIBUS map if the transfer had it, which on this
machine never happens, and marks the buffer done. An asynchronous
transfer has no one waiting, so the buffer is released; otherwise the
process waiting in `iowait`, `swap`, or `physio` is woken.

`clrbuf` zeroes a buffer, a word at a time; `sizeof(int)` makes the count
128 words here, where it was 256 on the PDP-11.

#lines(365, 400)

`swap` transfers `count` clicks of a process image between core, at
click `coreaddr`, and the swap device, at block `blkno` of the swap area.
It is called by `xswap` (#f("text.c")) and by `swapin` (#f("slp.c")),
and sleeps until the transfer is complete.

#lines(401, 410)

Of the two swap headers, the first is used unless it is busy; the second is
taken if no one is already waiting for it, else the caller waits for
the first.

#lines(411, 419)

The image is transferred (420--437) in pieces of at most `01700`
clicks. On the PDP-11 the byte count of a transfer was bounded by a
sixteen-bit register, and `01700` clicks is 61440 bytes. Here neither
`b_bcount` nor the virtio request has such a limit, but the loop is kept,
and an image of the full size of 16512 clicks is moved in eighteen
transfers.

v7 set `b_addr` (428) to the low sixteen bits of the physical address,
`coreaddr<<6`, and `b_xmem` to the high bits. The port uses `CLKADDR`
(#f("seg.h")), which counts clicks from `corebase` and gives the
kernel's address for the click; since the kernel maps memory at its own
address (#f("qemu/c.c")), that is also the physical address which the
driver gives the device. `b_xmem` (429) is still computed, but no
driver reads it.

The priority is raised again (431) after the strategy routine, which
in v7 lowered it, before `B_DONE` is tested; the reason is that given
for `getblk`.

An error in swapping is fatal (443): a process image cannot be recovered.

#lines(420, 444)

`bflush` starts the writing of every delayed-write buffer of a device,
or of all devices. It is called by `update` (#f("alloc.c")), which is
itself called by `sync`, by `umount`, and by `panic`. Each write changes the available
list, so the search starts again from the head after each one.

#lines(445, 468)

`physio` implements the raw devices: it transfers directly between the
device and the user's memory, using a header which belongs to the
driver, and does as much in one transfer as the user asks for. The
transfer is described by `u_base`, `u_count`, and `u_offset`, as for
`read` and `write`.

#lines(469, 490)

The checks (491) are v7's, with one added: the transfer must lie within
the user's address space, the 1 MB `USERSIZE` window. The
check that a transfer does not overlap the text segment (494--503) is kept, though
the text size is always zero here.

v7 then checked that the transfer lay wholly in the data segment or
wholly in the stack, the two parts of the PDP-11's 64 KB user address
space, which lay in separate places in core; hence the masks `01777`,
which reduce an address to a click number within that space. The port
deletes the check and the masks: every process has the whole window,
mapped contiguously from its image in core, and so any address below
`USERSIZE` belongs to it.

#lines(491, 510)

v7 found the physical address of the user's buffer by
reading the user segmentation registers (`UISA` or `UDSA`), simulating
the translation which the hardware would have made. The port has no such
registers; an earlier version read the copies kept in `u.u_uisa`, which
the port never fills in, and so sent raw transfers to low physical
memory. The address is now computed from the layout of the image: the user's memory begins `USIZE` clicks into it
(#f("proc.h")), at `p_addr`, and `CLKADDR` converts the click number to
an address, as in `swap` (515, 516).

`SLOCK` (521) keeps the process in core while the device transfers
into its memory: the address given to the device would be wrong if the
image were swapped out and brought back elsewhere.

#lines(511, 536)

`geterror` passes the error of a failed transfer to the user. The
comment's last sentence was true of v7's drivers and remains so here:
neither disk driver sets `b_error`.

#lines(537, 551)

= File System

#source("/usr/sys/h/file.h")

#f("file.h") is v7's but for one type. A `file` structure stands between
the descriptors of one or more processes and the inode of an open file.
`open`, `creat`, and `pipe` (#f("sys2.c"), #f("pipe.c")) each make a new
one; `fork` and `dup` merely make a second descriptor point at an
existing one, and increment `f_count`. The read/write pointer is kept
here, not in the inode and not in `u`, so that processes which share a
`file` also share the position in it, as a shell and its children must
when they write in turn to the same output.

`f_count` (11) was a `char`. On the PDP-11 it was signed and could
count to 127; on the ARM `char` is unsigned and the limit was 255.
Every process forked from a shell shares its terminal's `file`, so a
process table larger than v7's 150 entries could wrap the count to
zero and free the entry while still in use; nothing checks for
overflow, here or in v7. It is now a `short`, which counts to 32767. `f_offset` is a `long` on both machines,
but on the PDP-11 it occupied two words, high word first, where here it
is a single word.

The union's second member, `f_chan`, and the flags `FMPX`, `FMPY`, and
`FMP` belong to v7's multiplexed files, `mx1.c` and `mx2.c`. Those files
are not part of this system, so no `file` is ever marked as a channel
and the tests of `FMP` in `rdwr`, `seek`, and `closef` always take the
ordinary path. `FKERNEL` was used by nothing even in v7.

A `file` now occupies 12 bytes rather than 8: the inode pointer has
grown to four bytes, and a byte of padding after `f_flag` puts the
`short` `f_count`, and the pointer after it, on their boundaries.

#lines(1, 28)
#source("/usr/sys/h/inode.h")

The in-core inode. The table `inode` holds one entry for each file which
is in use in any way: open, current or root directory of some process,
being executed, mounted on, or merely in the middle of a path being
searched by `namei`. `iget` (#f("iget.c")) finds or fills an entry;
`iput` releases it. An entry is free when `i_count` is zero, and is
identified, as the opening comment says, by the pair `i_dev` and
`i_number`.

The fields from `i_mode` onward are a copy of the inode on the disk
(#f("ino.h")), expanded for convenience: the thirteen block addresses
are held as full `daddr_t`s where the disk holds three bytes for each.
The three times are not kept at all. Instead the flags `IACC`, `IUPD`,
and `ICHG` record that the access, modification, or change time is due,
and `iupdat` writes the current time straight into the disk copy when
it next writes the inode out. This is why `stat` (#f("sys3.c")) reads
the times from the disk.

`NADDR` is 13: ten direct block addresses followed by a single, a
double, and a triple indirect block, as interpreted by `bmap`
(#f("subr.c")). `NINDEX` and `struct group` belong to v7's multiplexed
files, which this system does not have (see #f("file.h")).

#lines(1, 25)

`i_flag` is a `char`, as in v7. `i_count` (29) was one too, and could
count 127 references to an inode on the PDP-11 and 255 on the ARM. The
root directory is the current directory of most processes, so a process
table larger than v7's 150 entries could wrap its count to zero, and the
inode would be freed while in use. It is now a `short`.

`i_un` is a union because a special file has no blocks. For a regular
file or directory it holds the block addresses and `i_lastr`, the last
logical block read, which `readi` (#f("rdwri.c")) compares with the
next request to detect sequential reading and start a read-ahead. For a
special file the first address holds instead the device number
`i_rdev`, put there by `mknod` (#f("sys2.c")), and the rest was the
multiplexor's `i_group`.

In v7 the two structures within the union had no names, and the program
wrote `ip->i_un.i_addr` as though their members were members of the
union itself. The PDP-11 compiler allowed this, because a member name
was little more than an offset and type, valid in any structure. C99
requires a member to be named, so the structures are now `u_reg` and
`u_dev`, and the macros (47--49) let every use keep v7's spelling: 
`ip->i_un.i_addr[0]` becomes `ip->i_un.u_reg.i_addr[0]`. The
corresponding macro for `i_group` was dropped because nothing refers to
it.

#lines(26, 50)

`mpxip` is now declared `extern`. In v7 this line was a definition, and
every file which included #f("inode.h") defined the same variable,
leaving the linker to merge the copies. C99 leaves that behaviour
undefined, and the compiler no longer allows it by default, so the
headers now only declare such variables and #f("main.c") defines each
once. `mpxip` is never set in this system, so the tests of it in
`namei` (#f("nami.c")) always fail.

#lines(51, 55)

`ILOCK` and `IWANT` implement the lock on an inode: whoever finds the
inode locked sets `IWANT` and sleeps on its address, and `prele`
(#f("pipe.c")) wakes the sleepers when the lock is released. `ITEXT`
marks the inode of a program whose text is in the text table, and which
therefore may not be written; since no program here has a separate text
segment (#f("text.c")), the flag is never set. `IMOUNT` marks an inode
on which a file system is mounted, which `iget` replaces by the root of
that file system.

#lines(56, 64)

The file types occupy the top four bits of `i_mode`, below them the
set-user-id, set-group-id, and sticky bits, and below those the nine
permission bits, of which only the owner's three are named. `access`
(#f("fio.c")) shifts its argument to reach the group and other bits.

Note that `IFCHR&IFBLK` is 020000, a bit common to the character and
block types and absent from the directory and regular types; `rdwr`
and `smount` use it as a short test for "special file". The pipe code
borrows `IREAD` and `IWRITE` as flags, since a pipe's mode is never
examined for permission (#f("pipe.c")).

#lines(65, 78)
#source("/usr/sys/sys/sys2.c")

#f("sys2.c") holds the system calls which open, close, read, write, and
position files, together with `link`, `mknod`, and `access`. They are
thin: each decodes its arguments from `u.u_ap`, finds the inode or the
`file` concerned, and passes the real work to the routines of
#f("fio.c"), #f("rdwri.c"), #f("nami.c"), and #f("iget.c"). Apart from
the C99 dressing the file is v7's.

The declaration (8) is new. `rdwr` and `open1` are called before their
definitions and from no other file, so they are declared here rather
than in #f("systm.h").

#lines(1, 26)

`rdwr` serves both `read` and `write`. The arguments are reached, as in
every v7 system call, through `u.u_ap`, which `trap` (#f("sysent.c"))
points at `u.u_arg`, into which it has copied the caller's arguments
from r0 upward; the local structure `a` gives them names.

#lines(27, 47)

The descriptor must have been opened for the direction wanted. The
transfer is then described to `readi` and `writei` by the variables
`u_base`, `u_count`, and `u_offset` in `u`; a `u_segflg` of zero says
that `u_base` is an address in user space. A pipe has its own
discipline (#f("pipe.c")).

#lines(48, 59)

For an ordinary file or directory the inode is locked for the duration
of the transfer, so that the reads and writes of different processes on
one file do not interleave within a call. A special file is not locked:
a read from a terminal may wait indefinitely, and the lock would stop
every other process from using the same inode, even to write to the
terminal. The test `IFCHR&IFBLK` is explained in #f("inode.h").

The offset advances by the number of bytes actually moved (75), which is
also the value returned (77).

#lines(60, 78)

`open` obtains the inode with `namei` and lets `open1` do the rest.
The increment (96) turns the user's mode of 0, 1, or 2 into `FREAD`,
`FWRITE`, or both.

`creat` asks `namei` to prepare for creation (flag 1). If the file does
not exist, `namei` returns `NULL` with no error, and leaves in
`u.u_pdir` the locked inode of the directory and in `u.u_offset` the
place for the new entry; `maknode` (#f("iget.c")) then makes the file.
The sticky bit is removed from the mode (116), since only the
super-user may set it, by `chmod`. The third argument of `open1`
records which case arose: 2 for a new file, 1 for an existing one,
which must be truncated.

#lines(79, 122)

`open1` checks permission unless the file is new: `creat` made it with
the mode the caller asked for, and the caller must be able to write to
it whatever that mode. A directory may be opened for reading only.

#lines(123, 147)

`namei` and `maknode` both return the inode locked; the lock is
released now that the file's state has been checked, and the reference
count keeps the inode in the table. `falloc` (#f("fio.c")) finds both a
descriptor and a `file`; it leaves the descriptor in `u.u_r.r_val1`,
which is the value returned to the user, and also remembered in `i`
(153) in case `openi`, which may call a driver's open routine, should
fail. In that case the descriptor and the `file` are released by hand,
and the inode by `iput`.

#lines(148, 162)

`close` clears the descriptor and hands the `file` to `closef`
(#f("fio.c")), which does the real work only on the last close.

`seek` sets the offset in the `file` absolutely, relative to its
present value, or relative to the size of the file, according to
`sbase`. A pipe has no meaningful offset. On the PDP-11 an `off_t`
occupied two argument words and the result was returned in r0 and r1
together, by way of `r_off` (#f("user.h")), which overlays both
`r_val1` and `r_val2`. Here an `off_t` is one word: the offset is one
argument and the result is returned in r0 alone. The C library's
`lseek` is built to match.

#lines(163, 210)

`link` makes a second name for an existing file. Only the super-user
may link a directory (228), since a directory with two parents would
make the meaning of its ".." entry ambiguous, and a loop of directories
could never be freed. The comment explains why the inode is unlocked
before the second `namei`: the new name may lie on a path which passes
through the file itself, if it is a directory, and `namei` would then
wait forever for the lock which this process holds.

#lines(211, 238)

`trap` set `u.u_dirp` to the first argument; it is pointed at the
second for a call of `namei` with flag 1. If the name exists the call
fails. Otherwise `u.u_pdir` is the directory to receive the entry,
which must be on the same device as the file, since a directory entry
holds only an inode number. `wdir` (#f("iget.c")) writes the entry and
releases `u.u_pdir`.

#lines(239, 261)

`mknod` is the super-user's general means of making an inode: the mode
is taken as given, so it is the only way to make a special file or a
directory. The `mkdir` command, which runs as the super-user, calls
`mknod` and then `link` twice, for "." and "..". For a special file the
third argument, the device number, goes into the first block address
(289). Nothing checks that a non-special inode receives a zero there.

Note the way an error from `suser` is handled: the test at (284) also
catches it, so that the `goto out` path is taken only when `ip` has been
set.

#lines(262, 293)

`saccess`, the `access` system call, asks whether the real rather than
the effective user could use the file in the given ways. It does so by
installing the real ids for the duration of the `namei` and the calls
of `access` (#f("fio.c")), which leave any refusal in `u.u_error`. The
caller's mode uses the bits 4, 2, and 1, which the shifts (315--319)
compare with the owner's bits of `IREAD`, `IWRITE`, and `IEXEC`.

#lines(294, 325)
#source("/usr/sys/sys/fio.c")

#f("fio.c") holds the small routines which manage open files and
permissions: the conversion of a descriptor to a `file`, the allocation
of descriptors and `file`s, the last close and the first open of a file,
and the tests of permission. The file is v7's but for the type of the
close routine and two casts, explained below.

`getf` checks a descriptor and returns the `file` it refers to, or sets
`EBADF`. Each process has `NOFILE` descriptors, the slots of the array
`u.u_ofile`.

#lines(1, 31)

`closef` is called when a descriptor is closed, whether by `close`, by
`exit`, by `exec` for a descriptor marked close-on-exec, or by `dup` when
the target descriptor is in use. Only the last reference to a `file`
does anything (54).

In v7 the close routine was declared `int (*cfunc)()` and called with a
third argument, the multiplexor channel `f_chan`, which only the
multiplexor's own routines used. The switch tables are now fully
typed (#f("conf.h")): a close routine is `void` and takes the device
and the flag only, so the variable `cp`, its assignment, and the third
argument (91) have gone.

#lines(32, 64)

When either end of a pipe is closed, the two addresses on which its
reader and writer may be sleeping, `ip+2` and `ip+1`, are woken. The
`iput` which follows reduces `i_count` to one, and the survivor, finding
that it is alone, gives up (#f("pipe.c")).

#lines(65, 71)

A special file has a close routine, which is called only on the last
close of the device: the loop (88) looks for any other `file` still open
on the same inode. `f_count` was cleared first (64), so that the loop
does not find the `file` being closed. Note that the test is by inode,
not by device number: two special files with the same major and minor
numbers are closed independently. The inode has already been released
by `iput` (70); only its address is compared.

#lines(72, 92)

`openi` calls the open routine of a special file's driver, after
checking that the major device number is within the switch table. `maj`
is `unsigned` while `nchrdev` and `nblkdev` are `int`; the casts at
(111) and (118) state the comparison as unsigned, as it was in v7 by the
rules of C, and keep the compiler from warning of a comparison between
signed and unsigned. Since the counts are small and positive, the
meaning is unchanged. Opening an ordinary file or directory needs no
action.

#lines(93, 126)

`access` returns zero if the current user may use the inode in the way
given by `mode`, which is one of the owner's bits `IREAD`, `IWRITE`, and
`IEXEC`; otherwise it sets `u.u_error` and returns one. Most callers
ignore the result and test `u.u_error`.

Writing is refused on a file system mounted read-only, and on a program
in use as a shared text. In the latter case `xrele` (#f("text.c")) first
tries to free the text, which succeeds if it is merely kept for its
sticky bit and no process is running it.

#lines(127, 158)

The super-user may do anything; whether a file with no execute bit at
all may be run is tested in `exec` (#f("sys1.c")). For anyone else the
mode is shifted to the group or other bits only when the user is not
the owner, so a file of mode 077 is closed to its owner and open to
everybody else.

#lines(159, 171)

`owner` is the common beginning of `chmod`, `chown`, and `utime`, in
#f("sys4.c"): it finds the named file and allows the call only to its
owner or the super-user.

`suser` also sets `ASU` in `u.u_acflag`, so that the accounting record
written at exit (#f("acct.c")) shows that super-user privilege was
used.

#lines(172, 211)

`ufalloc` finds the lowest free descriptor, leaves it in `u.u_r.r_val1`
as the value to be returned, and clears the per-descriptor flags in
`u_pofile`, of which the only one is close-on-exec. `falloc` adds a free
`file` and links the two.

#lines(212, 259)
#source("/usr/sys/sys/rdwri.c")

#f("rdwri.c") moves data between a file and the place described by
`u_base`, `u_count`, `u_offset`, and `u_segflg` in `u`. `readi` and
`writei` work a block at a time through the buffer cache (#f("bio.c")),
asking `bmap` (#f("subr.c")) where each block of the file lies;
`iomove` copies the part of a block which is wanted. Character special
files bypass all this and go straight to their drivers.

The declaration of `iomove` (8) is new: `readi` calls it before its
definition, and no other file does.

#lines(1, 8)

`readi` refuses a negative offset, which can arise from `seek`, since
that does not check. It marks the access time as due, and hands a
character device the whole request. In v7 the call read
`return((*cdevsw[major(dev)].d_read)(dev))`, returning whatever the
driver returned from a procedure whose value nobody used. Both are
`void` now, so the call and the `return` are separate statements.

#lines(9, 43)

The offset is split into a logical block number and a position within
the block, and `n` is the most that can come from this block. The sixth
edition needed `lshift` to do this with its two-word offset; a `long`
shift has done since v7. `min`, below, compares as `unsigned`.

For a file, `n` is cut to what remains before the end of the file, and
`bmap` converts the logical block number into a block of the device;
`dev` is now the device on which the file lies, whereas `i_rdev` (37)
was the device a block special file refers to. For a block special file
the logical block is the physical one, and the following block is the
obvious candidate for read-ahead.

#lines(44, 59)

`bmap` returns −1 for a block which was never written: such a hole in a
file reads as zeros, from a cleared buffer which belongs to no device.
If the previous read of this inode ended in the block before, the
reading is taken to be sequential, and `breada` is asked to start
reading the next block, `rablock`, which `bmap` left as a side effect.
`b_resid` (68) is nonzero only if the device transferred less than a
whole block, as at the end of a disk.

#lines(60, 73)

`writei` follows the same pattern. A write to a character device marks
the inode as modified, so that the times of a terminal show its last
use.

#lines(74, 117)

A write of a whole block need not read the old contents first, and
`getblk` merely assigns a buffer; a partial write must read the block
so that the rest of it is preserved. The block is written with
`bdwrite` (126), which marks it dirty and releases it. It reaches the
disk when its buffer is reused or at the next `sync`; a file written a
byte at a time thus costs one disk write per block, not one per call.

Only a regular file or a directory grows (127); a block special file
has no size of its own. `IUPD` and `ICHG` are set again each time round
the loop; once would do.

#lines(118, 132)

`max` and `min` take `unsigned` arguments and return `int`, as in v7.
Comparing as unsigned matters in `readi` and `writei`: `u_count` is
`unsigned`, and a request for more than the largest `int` must not
appear negative.

#lines(133, 158)

`iomove` moves `n` bytes between the buffer at `cp` and `u_base`. There
are two methods, as the comment says. If the other side is in user space
(`u_segflg` not 1) and the count and both addresses are multiples of
`NBPW`, a single `copyin` or `copyout` moves the lot; otherwise the bytes
go one at a time through `cpass` and `passc` (#f("subr.c")), each of
which checks the user address and counts.

On the PDP-11 the test was for evenness, `NBPW` being 2, and the
machine-language routines moved words. Here `NBPW` is 4, and `copyin`
and `copyout` (#f("machdep.c")) are a range check followed by `bcopy`
(#f("subr.c")), a byte loop; the single call is cheaper than one call of
`passc` per byte, but alignment no longer matters to it. The test is
v7's and has been left alone.

`u_segflg` 2 meant user instruction space, which the PDP-11/45 and /70
kept apart from data space. The ARM has no such division, and
`copyiin` and `copyiout` are names for `copyin` and `copyout`, defined
as macros in #f("systm.h"), so that v7's text is unchanged here and in
`passc` and `cpass`.

#lines(159, 216)
#source("/usr/sys/sys/subr.c")

#f("subr.c") is a miscellany. Its chief inhabitant is `bmap`, which
defines how a file is laid out on the disk; the rest are the
byte-at-a-time transfer routines `passc` and `cpass`, the dummy entries
for the device switches, and `bcopy`.

`bmap` maps the logical block `bn` of the file `ip` to a block of the
device, allocating one, together with any indirect blocks needed to
reach it, if `rwflg` is `B_WRITE` and none exists yet. When reading, a
missing block is reported as −1, which `readi` (#f("rdwri.c")) turns
into a block of zeros.

#lines(1, 31)

The first `NADDR-3`, that is ten, addresses in the inode point directly
at data blocks, so a file of up to 5120 bytes needs no indirect block.
A new block comes from `alloc` (#f("alloc.c")) already cleared, in a
buffer which is released at once with `bdwrite`: it will be written
before the buffer is reused, and in the meantime `readi` and `writei`
will find it in the cache. The read-ahead block is the next direct
address, if there is one.

The three kinds of indirect block each have their own address in the
inode, so no file ever changes form as it grows.

#lines(32, 50)

Beyond the direct blocks, `bn` is reduced step by step by the number of
blocks reachable through a single, then a double, then a triple indirect
block: 128, 128², and 128³ blocks,
since an indirect block of 512 bytes holds `NINDIR` four-byte addresses
and `NSHIFT` is 7. When the loop stops, `j` is 3 for single, 2 for double,
and 1 for triple indirection, and `sh` is the number of bits which
select the entry at the top level.

The largest file is thus 10 + 128 + 16384 + 2097152 blocks, a little
over 1 GB. That is within the 2 GB which a 32-bit `off_t` can address,
on this machine as on the PDP-11.

#lines(51, 71)

The top-level indirect block is found in the inode, or allocated.

#lines(72, 84)

Each pass of the loop reads one indirect block and picks out the next
address with `sh` and `NMASK`. A block allocated at a lower level is
recorded in the indirect block above it, which is then itself written
with `bdwrite`. Note that an I/O error yields zero rather than −1.

The addresses in an indirect block are `daddr_t`s exactly as they lie in
memory, so their byte order is the ARM's: least significant byte first.
The PDP-11 stored a `long` with its high word first, so the indirect
blocks of a disk made here are not those of a PDP-11 disk, although
there are 128 to a block on both.

`NINDIR` is computed with `sizeof` and is therefore unsigned; the cast
at (115) makes the comparison with the `int` `i` explicitly unsigned, so
that the compiler does not warn of mixed signedness. Since `i` is never
negative, the meaning is v7's.

#lines(85, 118)

`passc` delivers one character to the place described by `u_base` and
`u_segflg`, and counts it. A `u_segflg` of 1 means a kernel address,
which is stored into directly. Note the conditional expression at
(134): `<` binds more tightly than `?:`, so that only `subyte`'s result
is compared with zero, while `suibyte`'s is tested for being nonzero.
Both return −1 on a fault and zero otherwise, so the two readings agree
and the line, which is v7's, works.

The return of −1 on the last character lets a driver's read routine
stop as soon as the request is satisfied.

#lines(119, 142)

`cpass` is the converse, fetching one character of a write. The mask
(168) mattered on the PDP-11, where the direct fetch for a kernel
address sign-extended the `char`. On the ARM a `char` is unsigned and
`fubyte` (#f("machdep.c")) already returns a value from 0 to 255, so the
mask changes nothing.

#lines(143, 169)

`nodev` and `nulldev` fill the slots of the device switches
(#f("conf.h")) for which a driver has no routine: one makes the
operation an error, the other a no-op. In v7 the same two routines,
declared without parameters, served in every slot, since the
switch tables were arrays of `int (*)()` and C did not check the
arguments. Now each slot has a prototype, and a function put in it must
have that type. `nodev` and `nulldev` take a device and a flag, the
arguments of an open or close routine, and so can occupy only those
slots; the parameters are unused.

#lines(170, 191)

The other kinds of slot get new routines of their own: `nostrat` for a
block driver's strategy routine, `nordwr` for a character driver's read
and write, `noioctl` for its `ioctl`, `nolioctl` for a line discipline's
`ioctl`, and `nulltty` for the routines which take only a `tty`, such as
a character driver's stop routine and a line discipline's close.

#lines(192, 229)

`bcopy` copies a byte at a time. Since the loop tests after the copy, a
count of zero would run on through memory; no caller passes one.

#lines(230, 244)
#source("/usr/sys/h/dir.h")

#f("dir.h") is unchanged from v7. A directory is a file of 16-byte
entries, each an inode number and a name of up to `DIRSIZ` characters,
padded with nulls but not terminated by one when it is fourteen long.
An entry whose `d_ino` is zero is empty. The `#ifndef` lets a user
program which has already defined `DIRSIZ` include the file.

The entry must stay 16 bytes, since the kernel copies directory entries
to and from the disk as they lie in memory (`namei`, `wdir`). That is
one reason why `ino_t` (#f("param.h")) is still an `unsigned short`: two
bytes followed by fourteen `char`s need no padding. A 16-bit number,
least significant byte first, has the same layout on the PDP-11 and the
ARM, so a directory block is byte for byte what it was in v7.

#lines(1, 8)
#source("/usr/sys/sys/nami.c")

#f("nami.c") holds `namei`, which turns a path name into an inode, and
the two routines from which it takes the name one character at a time.
`namei` is called by every system call that names a file, and by `core`
(#f("sig.c")); `core` alone uses `schar`, because the name "core" is a
string in the kernel. The file is v7's; only the declarations have
changed.

The interface is subtle, and is best summarised by the cases in which
`namei` returns:
- with `flag` 0, the inode of the named file, locked and with its count
  incremented, or `NULL` with `u.u_error` set;
- with `flag` 1 (create), the inode of an existing file, as for 0; or,
  if only the last component is missing and the directory may be
  written, `NULL` with no error, the locked parent directory in
  `u.u_pdir`, the name in `u.u_dbuf`, and `u.u_offset` at the slot for
  the new entry; this is what `maknode` and `wdir` (#f("iget.c")) expect;
- with `flag` 2 (delete), the locked parent directory, with the entry
  in `u.u_dent` and `u.u_offset` just past it, for `unlink`
  (#f("sys4.c")) to clear.

#lines(1, 30)

The search starts at the root if the name begins with a slash, the root
being the process's own (`u_rdir`, set by `chroot`) if it has one;
otherwise at the current directory. `iget` is called for an inode which
is certainly in the table already, to lock it and count the reference
which `namei` will hold. Repeated slashes are skipped. An empty name
means the starting directory itself, which cannot be created or
removed.

#lines(31, 45)

`cloop` is entered once for each component. The component is gathered
into `u.u_dbuf`, silently truncated to `DIRSIZ` characters and padded
with nulls, so that it can be compared with a directory entry as a
whole.

The tests of `!` belong to the multiplexor: a path such as `x!y` named a
channel of a multiplexed file. `mpxip` is never set in this system
(#f("inode.h")), so they are never true.

#lines(46, 81)

The directory to be searched must be a directory, and the user must
have execute permission on it, which for a directory means permission
to search. `eo` will record the first empty slot, for `creat`.

#lines(82, 101)

`eloop` examines one entry per pass. Reaching the end of the directory
without a match is an error, except when the last component is to be
created. Then, if the directory may be written, the place for the new
entry is the first empty slot (`eo` is the offset just past it) or, if
there is none, the end of the directory. In the latter case the
directory is about to grow, and is marked as modified (120).

#lines(102, 126)

At each block boundary the next block of the directory is read, through
`bmap` but not `readi`, since the entries are wanted in the buffer rather
than copied to a user. There is no read-ahead.

#lines(127, 143)

The entry is copied into `u.u_dent` before it is compared: it is
needed there afterwards, for the inode number and, by `unlink`, for the
whole entry. The comparison is of all `DIRSIZ` bytes, which is why the
component was padded.

#lines(144, 163)

A match. If this is the last component and the caller wants to delete
it, the parent directory is returned, provided that it may be written.

Otherwise the search descends. The cascade of `if`s (178--183) handles
".." in the root directory of a mounted file system: such a root's ".."
names the root itself, inode `ROOTINO`, and the test of `d_name[1]`
tells ".." from ".", which matches the other two tests as well. The
mount table is searched, from entry 1 since entry 0 is the root file
system, for the file system on this device, and the search for ".."
starts again in the directory on which it is mounted. This is the
converse of the substitution which `iget` (#f("iget.c")) makes when it
meets an inode marked `IMOUNT`.

Note the order at (190, 191): the directory is released before the next
inode is fetched, and `d` saves its device. Were the parent still
locked, a lookup of ".." would have `iget` wait for the lock held by
this very process.

#lines(164, 199)

`schar` takes the name from kernel space, `uchar` from user space with
`fubyte` (#f("machdep.c")), which returns −1 for an address outside the
user's memory. The mask in `schar` undid the sign extension of a PDP-11
`char`; on the ARM `char` is unsigned and the mask is idle.

#lines(200, 225)
#source("/usr/sys/h/filsys.h")

#f("filsys.h") is unchanged from v7. It describes the super-block, block
`SUPERB` (1) of every file system; block 0 is left for a bootstrap. The
i-list, the array of inodes on the disk, occupies blocks 2 up to `s_isize`−1, so that `s_isize` is in
effect the number of the first block which may hold data, and
`badblock` (#f("alloc.c")) checks block numbers against it and against
`s_fsize`. A mounted file system's super-block is kept in a buffer of
its own, found through the mount table (#f("mount.h")), and written back
by `update` when `s_fmod` says that it has changed.

`s_free` and `s_inode` cache up to `NICFREE` free blocks and `NICINOD`
free inodes (#f("param.h")); `alloc` and `ialloc` explain how they are
replenished. `s_flock` and `s_ilock` lock the two lists while a process
sleeps in the middle of changing them; they mean nothing on the disk,
and `smount` (#f("sys3.c")) clears them. The fields after `s_time` are
kept by the programs which examine file systems, not by the kernel.

The structure is v7's, but its image on the disk is not. The compiler
lays it out for the ARM: a `long` is stored least significant byte
first, where the PDP-11 put its high word first, and it is aligned on a
four-byte boundary, so that two bytes of padding follow `s_isize`,
`s_nfree`, and the four flags. The super-block is 448 bytes here, against
440 on the PDP-11. Since `mkfs` (#f("cmd/mkfs.c")) is compiled by the ARM
cross-compiler from these same headers (#f("Makefile")), and run on the
host under emulation, the file systems it builds agree with the
kernel; a disk written by a PDP-11 could not be mounted without
conversion.

#lines(1, 23)
#source("/usr/sys/h/mount.h")

The mount table has one entry for each mounted file system. `m_bufp`
points to the buffer, taken from the cache by `geteblk` and never
released while the file system is mounted, which holds its super-block;
an entry is free when `m_bufp` is null. `m_inodp` is the inode of the
directory on which the file system is mounted. Entry 0 is the root file
system, filled in by `iinit` (#f("main.c")); its `m_inodp` is never
used. `smount` and `sumount` (#f("sys3.c")) make and clear the other
entries, `getfs` (#f("alloc.c")) searches the table by device, and `iget`
(#f("iget.c")) and `namei` (#f("nami.c")) by inode, to cross a mount
point downward and upward respectively.

The one change is the word `extern` (6). In v7 the line defined `mount`
in every file which included the header, relying on the linker to merge
the copies into one; C99 makes that undefined and the compiler no longer
accepts it by default. The table is now defined once, in #f("main.c").

#lines(1, 11)
#source("/usr/sys/h/ino.h")

#f("ino.h") is unchanged from v7. It is the inode as stored in the i-list
on the disk, 64 bytes, `INOPB` to a block. The macros `itod` and `itoo`
(#f("param.h")) find the block and the position in it of inode `i`;
inode 1 is the first of block 2, and inode 0 does not exist, a zero in a
directory entry meaning "empty".

Thirteen block addresses are packed into `di_addr`, three bytes each, the
fortieth byte being unused; a block number must therefore be less than
2²⁴, which `iupdat` (#f("iget.c")) checks. `iexpand` and
`iupdat` unpack and pack them.

On the ARM the layout of the structure is the same as on the PDP-11:
four `short`s bring `di_size` to offset 8, already a multiple of four,
and the forty bytes of addresses bring the times to offset 52. The byte
order, however, is not. A `long` here is stored least significant byte
first, and the three bytes of an address are packed in the same order;
the PDP-11 kept the high word of a `long` first, and its three-byte
addresses accordingly began with bits 16 to 23. The kernel's packing in
#f("iget.c"), the private `ltol3` of `mkfs` (#f("cmd/mkfs.c")), and the
C library's `l3tol` and `ltol3`, used by the programs which examine file
systems, all follow the ARM's order.

#lines(1, 22)
#source("/usr/sys/sys/sys3.c")

#f("sys3.c") holds `stat`, `fstat`, `dup`, `mount`, and `umount`. Apart
from the C99 dressing it is v7's. The declaration of `stat1` (14) is
new: it is called before its definition and from no other file.

#lines(1, 14)

`fstat` and `stat` differ only in how they find the inode. For a pipe,
`fstat` passes the reader's offset, so that the size reported is the
number of bytes written but not yet read.

#lines(15, 53)

`stat1` fills a `stat` (#f("stat.h")) and copies it to the user. The
in-core inode holds no times (#f("inode.h")), so any times which are due
are first written to the disk inode by `iupdat`, and the three times are
then read back from the disk inode itself, found with `itod` and `itoo`.

#lines(54, 90)

`dup` returns a second descriptor for an open `file`. v7 overloads it to
provide `dup2` as well: if the descriptor carries the bit 0100, the
second argument names the new descriptor, which is first closed if it
is open. The C library's `dup2` sets the bit. Note that `dup` of a
descriptor onto itself does nothing (122).

#lines(91, 128)

`smount` mounts the block device named by the first argument on the
file named by the second. `getmdev` checks the first; `u.u_dirp`, which
`trap` (#f("sysent.c")) set to the first argument, is then pointed at
the second for `namei`. The file mounted on must be in use by no one
else, so that no process has it open or as its current directory, and
must not be special. Nothing requires it to be a directory, though
anything else would be useless.

#lines(129, 157)

The mount table is searched both for a free entry and for an entry for
the same device, which would make the call fail.

The device is opened, for writing unless the mount is read-only, and the
super-block is read and copied into a buffer of its own, obtained with
`geteblk` and held for as long as the file system is mounted; the cached
copy of block 1 is then released like any other. The locks are cleared,
since the copy on the disk may have been written while a list was being
changed. Finally the inode is marked `IMOUNT`, which `iget`
(#f("iget.c")) will notice from now on, and unlocked; its reference
count stays raised until the unmount.

#lines(158, 195)

`sumount`. Before the table is examined, `xumount` (#f("text.c")) gives
up the texts kept for sticky programs on the device, and `update`
(#f("alloc.c")) writes out everything modified. If any inode of the
device is still in the table, a file on it is in use and the call
fails.

The structure `a` describes the argument but is never used, since
`getmdev` finds the name through `u.u_dirp`. v7 declared it `register
struct a { ... };`, which declares a tag but no variable, so that the
`register` applies to nothing, and the compiler warns of it. The
`register` has gone; the unused declaration is kept as v7's.

#lines(196, 236)

`getmdev` returns the device number of a block special file, after
checking that its major number is within `bdevsw`.

#lines(237, 259)
#source("/usr/sys/h/stat.h")

#f("stat.h") is unchanged from v7. It is the structure which `stat` and
`fstat` (#f("sys3.c")) fill in, and user programs see it in `/usr/include/sys/stat.h`, a
copy of this file to which prototypes for the two calls have been added;
the `S_` names repeat the mode bits of
#f("inode.h") for their use.

The kernel and the programs are compiled for the ARM from the same
declaration, so they agree on its layout, which is not the PDP-11's:
`dev_t` is an `int` of four bytes, and two bytes of padding after
`st_gid` align `st_rdev`, so that a `stat` is 36 bytes rather than 30.

#lines(1, 28)
#source("/usr/sys/sys/iget.c")

#f("iget.c") manages the in-core inode table (#f("inode.h")): `iget`
brings an inode into it, `iput` lets it go, and `iupdat` writes it back.
`itrunc` frees a file's blocks, and `maknode` and `wdir` create a file
and its directory entry. The file is v7's apart from the C99 dressing
and one real change: the order in which a block address is packed into
three bytes, in `iexpand` and `iupdat`.

The declarations (11, 12) are new: `iexpand` and `tloop` are used before
their definitions, and only here.

#lines(1, 13)

`iget` returns the inode `ino` of the device `dev`, locked and with its
reference count incremented. Every inode that a process holds was
obtained here, by `namei` (#f("nami.c")) or `ialloc` (#f("alloc.c")),
or by `main` for the root.

#lines(14, 39)

The table is searched for the inode. If it is present but locked, the
caller sleeps and then starts the whole search afresh, since while it
slept the entry may have been released and even reused for another
inode.

If the inode is one on which a file system is mounted, the request is
redirected to the root, `ROOTINO`, of the mounted file system, whose
device is found by searching the mount table (#f("mount.h")) for the
entry which points back at this inode. This is how a path descends
through a mount point; `namei` handles the climb back up through "..".

Meanwhile the first free entry, one with no references, has been noted
in `oip`.

#lines(40, 64)

If the inode is not in the table, the free entry is claimed and locked,
and the block of the i-list which holds the inode is read. If the read
fails, the entry is released and `NULL` is returned; the caller finds
the error in `u.u_error`, set by the buffer routines.

#lines(65, 90)

`iexpand` copies the disk inode (#f("ino.h")) into the table entry,
unpacking each three-byte block address into a four-byte `daddr_t`.

The PDP-11 stored a `long` as two words, the high word first, each word
with its low byte first. v7 therefore copied the first byte of an
address into bits 16 to 23, put a zero into bits 24 to 31, and copied
the other two bytes into bits 0 to 15. On the ARM a `long` is stored
least significant byte first, so the port copies the three bytes into
the low three bytes of the `daddr_t` and the zero into the top one, the
zero having moved from second place to last. The disk format of the
addresses has changed with it: bits 0 to 7 come first. `mkfs` builds
file systems in the same order (#f("cmd/mkfs.c")).

#lines(91, 112)

`iput` releases a reference. The last reference does the real work. If
the file has no links left, its blocks are freed by `itrunc`, its mode
cleared to mark the disk inode free, and its number returned to the
super-block's list by `ifree` (#f("alloc.c")). In either case the inode
is written back if it has changed, and the entry is cleared.

The inode is locked during this, since `itrunc` and `iupdat` may sleep
on the disk; `prele` is called twice, once to wake any process which
waited on the dying entry, and once for every release. A file which is
unlinked while open thus survives until its last close, which is the
basis of the convention for temporary files.

#lines(113, 140)

`iupdat` writes an in-core inode back into its block, provided that one
of the flags says it has changed and the file system is not mounted
read-only. The access and modification times are taken from the
arguments, which lets `utime` (#f("sys4.c")) set arbitrary times; the
change time is always the present. The block is released with
`bdwrite`, so the write itself is deferred.

The packing of the addresses is the reverse of `iexpand`, and has
changed in the same way: the three low bytes are copied, and it is now
the fourth byte, the most significant, which is checked. A nonzero
value there means a block number too large to record. For a
multiplexed file the addresses held other data and were exempt; such
files do not exist here.

#lines(141, 191)

`itrunc` frees every block of a regular file or directory; a special
file's first address is its device number and the rest are meaningless.
The addresses are freed from the last to the first, so that the blocks
are pushed onto the free list in reverse and will be allocated again in
their original order, as the comment explains. The three indirect
addresses are handed to `tloop` with flags which give their depth.

#lines(192, 238)

`tloop` frees the blocks listed in an indirect block, recursively if
`f1` says that they are themselves indirect, and then the indirect
block itself. The buffer is released before each recursive call, and
read again afterwards, so that a deep file does not hold several
buffers at once. Since the cache usually still holds the block, the
second reading costs little.

The entries of an indirect block are read as `daddr_t`s in the ARM's
byte order, as `bmap` (#f("subr.c")) wrote them.

#lines(239, 271)

`maknode` creates a file for `creat`, `mknod`, and `core`, after a call
of `namei` with flag 1 has left the parent directory in `u.u_pdir`. The
inode is allocated on the parent's device, given the requested mode
less the bits in the process's `umask`, and entered in the directory by
`wdir`. A mode with no type makes a regular file.

#lines(272, 295)

`wdir` writes the directory entry: the new inode number and the name
which `namei` left in `u.u_dbuf`, at the offset which `namei` left in
`u.u_offset`, through `writei` with a kernel address. If the directory
has been removed since it was searched, it has no links, and the entry
is refused. Either way the directory is released.

#lines(296, 318)
#source("/usr/sys/h/fblk.h")

#f("fblk.h") is unchanged from v7. It describes the first words of a
block in the chain of free-block lists: when the super-block's list
`s_free` is full, `free` (#f("alloc.c")) writes the count and the list
into the block being freed, in this form, and starts a new list with
that block alone; `alloc` reads them back when the list is exhausted.

`df_nfree` is an `int`, two bytes on the PDP-11 and four here, so that
the addresses begin at byte 4 of the block rather than byte 2. Like
the super-block and the indirect blocks, these blocks are laid out as
the ARM lays out the structure.

#lines(1, 5)
#source("/usr/sys/sys/alloc.c")

#f("alloc.c") allocates and frees the two resources of a file system,
disk blocks and inodes, using the lists kept in the super-block
(#f("filsys.h")). It also holds `getfs`, which finds the super-block of
a mounted device, and `update`, the body of `sync`. Apart from the C99
dressing the file is v7's. The declaration of `badblock` (12) is new:
it is called before its definition, and only here. `FBLKP` lets a buffer
be viewed as a `struct fblk` (#f("fblk.h")).

#lines(1, 14)

The free blocks of a file system form a chain of lists. The super-block
holds up to `NICFREE` free block numbers in `s_free`; the first of these
names a block which holds the previous `NICFREE` numbers, the first of
which names another such block, and so on. The first entry of the last
list is zero, which marks the end. Only the top of the chain is in
core, and both ends of the operation work on the top: `alloc` takes the
last number in `s_free`, `free` adds one there.

`alloc` first waits while another process is refilling the list.

#lines(15, 35)

A number is taken from the list. A count out of range, or the
terminating zero, means that the file system is full; a number outside
the data area, which is what a damaged or foreign file system would
yield, is reported by `badblock` and skipped.

#lines(36, 46)

If that was the last number in `s_free`, the block it names holds the
next list, which is read into the super-block before the block is handed
out; `s_flock` makes any other `alloc` or `free` wait while the read is
in progress. The block itself then becomes the one allocated.

#lines(47, 60)

The new block is given to the caller in a cleared buffer, obtained with
`getblk` since its old contents do not matter. The clearing is what
makes a new indirect block contain no addresses and a new directory
block contain only empty entries. `s_fmod` tells `update` that the
super-block must be written.

On failure the count is set to zero, so that later calls fail at once.

#lines(61, 71)

`free` is the converse. A list emptied by `alloc` at the end of the
chain is restarted with the terminating zero. If the list is full, it
is written, with its count, into the block being freed, which thereby
becomes the head of the chain, and the list starts again with that
block alone. Unlike most writes of the file system, this one is
synchronous (`bwrite`).
`s_fmod` is set both at the start and at the end; the second suffices.

The layout of the block is that of `struct fblk` on the ARM: a four-byte
count followed by `NICFREE` four-byte addresses, all in the ARM's byte
order.

#lines(72, 108)

`badblock` checks that a block number lies between the end of the
i-list and the end of the file system.

#lines(109, 128)

`ialloc` allocates an inode. Free inodes are handled differently from
free blocks: the super-block caches up to `NICINOD` free inode numbers,
but there is no chain. A free inode is recognised on the disk by its
mode of zero, and when the cache is empty the i-list is simply searched
for more.

#lines(129, 155)

A number is taken from the cache, and the inode is fetched with `iget`.
Inode 1 is never allocated: v7 reserved it, and `ROOTINO`, 2, is the
root. The cache may be out of
date, since `ifree` adds numbers without any check, so the mode is
examined: if it is still zero the inode is the caller's, with its
addresses cleared; otherwise the next number is tried. The caller fills
in the mode, which marks the inode as allocated.

#lines(156, 175)

The search of the i-list starts at block 2, inode 1. An inode which is
free on the disk may yet be in the inode table: just allocated and not
yet written back, or in the course of being released. Such inodes are
skipped. `s_ilock` keeps other allocations, and `ifree`, out while the
search proceeds, since `bread` may sleep.

#lines(176, 210)

`ifree` returns an inode number to the cache, unless the cache is full
or being refilled. A number which is dropped is not lost: the next
search of the i-list will find the inode, since `iput` (#f("iget.c"))
has cleared its mode.

#lines(211, 231)

`getfs` finds the super-block of a mounted device in the mount table
(#f("mount.h")). It also repairs nonsensical counts, so that a corrupted
super-block causes a "no space" message rather than an access beyond the
lists. The `return` after `panic`, which never returns, is v7's.

#lines(232, 269)

`update` is called by the `sync` system call (#f("sys4.c")), by
`sumount` (#f("sys3.c")), and by `panic` (#f("prf.c")). In normal
running the program `/etc/update` calls `sync` every thirty seconds.
`updlock` keeps two updates from running at once.

Each modified super-block is stamped with the time and written: the
whole block is copied from the private buffer of the mount table into a
buffer for block 1, obtained with `getblk` since its old contents are
not wanted. A super-block whose lists are locked is
passed over until the next time, since its contents may be half
changed. Then each inode which is in use and not locked is written with
`iupdat`; the extra reference keeps `iput` from treating the call as the
last release. Finally `bflush` (#f("bio.c")) starts the writing of every
delayed-write buffer.

#lines(270, 314)
#source("/usr/sys/sys/pipe.c")

#f("pipe.c") implements pipes. A pipe is an ordinary inode, allocated on
the device `pipedev` (the root device, on both boards, by the `c.c`
which `mkconf` writes) but entered in no directory, and opened twice: by
one `file` for reading and by another for writing. Data written to the
pipe is appended to the file; the reader reads from its own offset; and
when the reader catches up, the file is emptied. Since the file stays
small and is soon read, its blocks normally live only in the buffer
cache, but nothing prevents them from being written to the disk. The
file is v7's apart from the C99 dressing.

`PIPSIZ` bounds the size of the file. Ten direct blocks hold 5120 bytes,
which is the limit of the comment; a larger pipe would need an indirect
block for every access.

#lines(1, 18)

`pipe` allocates the inode and two `file`s. Each `falloc` leaves its
descriptor in `u.u_r.r_val1`, so the first is saved in `r`; at the end
the read descriptor is returned in r0 and the write descriptor in r1,
by way of `r_val2`, which `trap` (#f("sysent.c")) copies to the caller's
r1. The C library's `pipe` stores the two in the caller's array.

The inode is returned by `ialloc` locked, but no `prele` follows: the
assignment to `i_flag` (56) clears `ILOCK` along with everything else.
The reference count is 2, one for each `file`, and the link count stays
0, so that the inode and its blocks are freed by `iput` (#f("iget.c"))
when both ends are closed.

#lines(19, 57)

`readp`. The inode is locked for the whole of each operation, as the
comment says, very conservatively. If the pipe is empty, the reader
waits for data, having first unlocked the inode. A reference count
below 2 means that the write side is closed, and the read returns
nothing, which the program takes as the end of file. Otherwise the
reader marks its wait by setting `IREAD` in the mode, a bit the pipe
can spare since its mode is never checked for permission, and sleeps
on the address `ip+2`. `PPIPE` is above `PZERO`, so the sleep may be
broken by a signal.

#lines(58, 91)

The data is read with `readi` from the reader's own offset, the one in
its `file`. If everything has been read, both the offset and the size
are set back to zero: the next write will start again at the beginning
of the file, reusing the same blocks, which are probably still in the
cache. A writer waiting for room is then woken, on `ip+1`.

#lines(92, 112)

`writep` writes in pieces of at most `PIPSIZ` bytes, waiting between
them for the reader. `c` counts what remains. If the read side has
gone, the writer is sent `SIGPIPE`, which by default kills it, and the
call fails with `EPIPE`; a program which ignores the signal sees the
error.

#lines(113, 150)

A full pipe makes the writer set `IWRITE` and sleep on `ip+1` until
`readp` empties it.

#lines(151, 164)

The write always goes at the end of the file, at `i_size`, whatever the
offset in the writer's `file`. As the comment says, a pipe which is not
full accepts a whole piece of up to `PIPSIZ` bytes, and so may grow to
almost twice `PIPSIZ`. Afterwards a waiting reader is woken.

`min` (#f("rdwri.c")) takes `unsigned` arguments, and the casts (174)
only make that conversion explicit; they are v7's.

#lines(165, 183)

`plock` and `prele` are the lock on an inode in general, not only for
pipes: whoever finds it locked sets `IWANT` and sleeps on the inode's
address, at `PINOD`, which is below `PZERO`, so that no signal can
interrupt the wait. `prele` wakes all such sleepers, and the first to
run takes the lock; the others find it locked again and go back to
sleep.

#lines(184, 217)

= Character Devices

#source("/usr/sys/dev/sys.c")

#f("sys.c") is the driver for `/dev/tty`, major device 17 in the
character switch of #f("qemu/c.c"). It drives no hardware. A process
which opens `/dev/tty` is given its controlling terminal, whatever that
happens to be, so that a routine such as `getpass` can talk
to the user even when its standard input and output have been
redirected.

The controlling terminal is recorded in `u.u_ttyp` and `u.u_ttyd` by
`ttyopen` (#f("tty.c")) when a process with no process group opens a
terminal, and is inherited across `fork`. Each routine here ignores its
own device number and calls the corresponding routine of the real
driver with `u.u_ttyd` in its place, so that the real driver sees its
own minor device. A process without a controlling terminal is refused
with `ENXIO` (18).

There is no close routine: the switch has `nulldev` in that slot. The
real terminal's close routine is called only when the last file open on
the terminal itself is closed, and a file open on `/dev/tty` does not
count among those.

The include of #f("systm.h") (5) is new. It holds the prototypes of
`syopen` and its companions, which `-Wmissing-prototypes` requires to be
in sight before the definitions, and against which the compiler checks them.

#lines(1, 22)

The other three routines follow the same pattern. `sysioctl` passes on
the command and its argument unchanged, so that `stty`, which acts
on its standard output, works as well when that output is `/dev/tty`.

#lines(23, 46)
#source("/usr/sys/dev/mem.c")

#f("mem.c") is the driver for the memory special files, major device 8.
Through it a program such as `ps` reads the kernel's tables, and a
privileged user may inspect or patch the running system. Minor device
2, `/dev/null`, discards what is written to it and returns end of file
at once.

The lone `#` (1) dates from the time when the C compiler passed a file
through the preprocessor only if its first character was `#`. In C99
it is a null directive and does nothing.

The include of #f("systm.h") (13) is new; it declares `fumem`, `sumem`,
`passc`, and `cpass`, and the prototypes of the two routines here.
#f("seg.h") (17) is still included, as in v7, although nothing it
defines for the PDP-11 memory unit is used any longer.

#lines(1, 18)

`mmread` copies bytes, one at a time, from memory at the file offset
to the user, until `passc` (#f("subr.c")) reports that the request is
satisfied or `fumem` (#f("machdep.c")) finds that the offset names no
memory. The second case is an error, `ENXIO`, as it was in v7.

v7 could not simply dereference the offset. The PDP-11 kernel had only
64 KB of address space, so for each byte `mmread` raised the priority
to 7, borrowed the first user segmentation register, set it to the
64-byte click containing the offset, fetched the byte with `fuibyte`
through that segment, and put the register back. For minor device 1 the
click was first translated through the kernel's own segmentation
registers (`ka6`), so that the offset was a kernel virtual address
rather than a physical one. All of this has gone. The ARM kernel maps
the kernel image and the whole of core at fixed addresses, so the
translation is the simple one done by `memaddr` in #f("machdep.c"): an
offset below `kernbase` is taken relative to the start of core, and any
other offset is a kernel address in its own right. Minor devices 0 and
1 therefore behave identically. The PDP-11 conventions survive: a
process image is found at offset `p_addr` times 64, and a kernel
variable at the address which `nlist` reports for it, in either file.
`ps` reads both from `/dev/mem`.

#lines(19, 30)

`mmwrite` is the converse. `cpass` (#f("subr.c")) fetches the next byte
from the user and has already advanced `u.u_offset` when it returns,
hence the `-1` (44). The writes are checked as the reads are: an earlier
version of the port stored each byte through an unchecked pointer,
which put a byte at a different address from the one a read at the same
offset would fetch, and panicked the kernel on an unmapped address. It
now uses `sumem`, which shares `memaddr` with `fumem`.

#lines(31, 47)
#source("/usr/sys/sys/prim.c")

#f("prim.c") manages the character lists, or clists, in which the
terminal drivers queue characters on their way in and out. The only
changes from v7 are those of prototype syntax; what deserves attention
is that a scheme designed around the sizes of the PDP-11 works
unaltered on a machine with four-byte pointers.

A clist (#f("tty.h")) is a count and two character pointers: `c_cf` to
the first character in the queue and `c_cl` just past the last. The
characters themselves are held in a chain of `cblock`s (7), each a link
followed by `CBSIZE` characters. Free blocks are chained through the
same link from `cfreelist`.

The whole scheme rests on an invariant: every `cblock` begins at an
address which is a multiple of `CROUND+1`. On the PDP-11 a block was a
two-byte link and 14 characters; here it is a four-byte link and 12
characters (#f("param.h")), so a block is still 16 bytes long, and
`CROUND` is still 017. A character pointer whose low four bits are zero
therefore points just past the end of a block (since the first
character of a block lies at offset 4, never at offset 0), and the block
containing any character is found by clearing those four bits. No
block needs to record how full it is.

The pool `cfree` (12) of `NCLIST` blocks is fixed in size. `cbad` (14)
counts calls of `ndflush` with an impossible count; nothing reads it.

#lines(1, 15)

`getc` removes and returns the first character of a queue, or −1 if it
is empty. All the procedures in the file run at `spl6`, since the queues
are shared with the interrupt routines; on the ARM this simply masks
the IRQ.

The mask with `0377` (31) mattered on the PDP-11, whose characters were
signed: without it the character 0377, which #f("tty.c") uses as a line
delimiter, would have been returned as −1 and mistaken for an empty
queue. On the ARM `char` is unsigned and the mask changes nothing.

When the count reaches zero (32), the block holding the character just
taken is freed, and both pointers are cleared. Otherwise, if `c_cf` has
just stepped past the end of a block (39), the block is freed and
`c_cf` moves to the first character of the next. The casts of pointers
to `int` (34, 39) were safe on the PDP-11 because both were 16 bits;
they are equally safe here, where both are 32.

#lines(16, 49)

`q_to_b` moves up to `cc` characters from a queue to a buffer, freeing
blocks as it goes, and returns the number moved. It was used by v7's
multiplexed files (`mx2.c`), which are not part of this system; nothing
here calls it.

#lines(50, 93)

`ndqb` and `ndflush` serve a driver which transmits by DMA, such as
v7's DH11 driver `dh.c`. `ndqb` returns the number of characters which
lie contiguously in the first block of the queue, stopping, if `flag`
is `0200`, before the first delay character; the driver hands that
stretch of memory to the device, and when the transfer is done
`ndflush` removes it from the queue. The negative counts which both
accept belong to v7's packet driver (`pk1.c`, `pk2.c`), which used them
to record how many bytes it still expected. None of these drivers is
part of this system, and neither procedure is called.

#lines(94, 188)

`putc` appends a character to a queue, returning 0, or −1 if no block
is free. A new block is needed if the queue is empty (197), or if
`c_cl` lies just past the end of the last block (205). In the second
case the free block is linked into the chain through the old block's
link before `cfreelist` is tested, so that a failure leaves the old
block's link `NULL` as before. The callers in #f("tty.c") mostly ignore
the result; a character for which there is no room is lost.

#lines(189, 221)

`b_to_q` appends `cc` characters from a buffer and returns the number
which did not fit. `canon` (#f("tty.c")) uses it to move an edited line
to the canonical queue.

#lines(222, 268)

`cinit` is called once by `main`. The C compiler aligns `cfree` only as
strictly as a pointer requires, so its start is rounded up to a
16-byte boundary (282) and as many whole blocks as fit are put on the
free list; when `cfree` was not already aligned, one block is lost.

The second loop counts the entries of `cdevsw` (#f("qemu/c.c")) up to
the terminating entry with no open routine. Every unconfigured slot is
filled with `nodev`, which is not zero, so `nchrdev` counts them too;
`openi` (#f("fio.c")) uses it to reject an impossible major number,
and an unconfigured one fails in `nodev`.

#lines(269, 291)

`getw` and `putw` move a 16-bit quantity, as the comment says; the
words of this machine are wider, but the procedures were only ever
used by the multiplexed files, to queue events and their values, and
they are unused here.

#lines(292, 323)
#source("/usr/sys/dev/partab.c")

#f("partab.c") is v7's, unchanged. `partab` has one entry for each of
the 128 ASCII characters, and each entry carries two pieces of
information. The top bit, `0200`, is the bit which gives the character
even parity. The low bits classify the character for `ttyoutput`
(#f("tty.c")), which computes the column and the delay after it from the
class: 0 for a printing character, 1 for one which does not move the
carriage, 2 for backspace, 3 for newline, 4 for tab, 5 for vertical
motion (form feed), and 6 for carriage return. Vertical tab (013) is
classed as non-printing.

v7's `kl.c` added the parity bit to each character as it sent it. The
port's console drivers send the character as it is (#f("pl011.c")), so
only the classification is used now. On the PDP-11 an entry with the
top bit set was a negative `char`; here `char` is unsigned, and since
`ttyoutput` masks the entry with `077` before using it, the difference
does not arise.

#lines(1, 21)
#source("/usr/sys/h/tty.h")

#f("tty.h") declares the structures shared by the terminal drivers and
the common terminal code of #f("tty.c"), together with the modes, state
bits, and `ioctl` commands which they use.

The `clist` is the head of a character queue, whose blocks are managed
by #f("prim.c"). The comment's "4-word blocks" remains true in a new
sense: a block is now four 32-bit words, where on the PDP-11 it was
eight 16-bit ones. A `clist` itself has grown from six bytes to twelve.

#lines(1, 14)

`struct tc` holds the special characters which v7 made settable through
`TIOCSETC`: interrupt, quit, the stop and start characters for output,
end of file, and an extra input delimiter. The user's view of the same
six bytes is `struct tchars` in `sgtty.h`. The drivers named in the
comment are v7's; in this system the only one is the console, whose
driver (#f("pl011.c")) still uses `kl11` as the name of its `tty`
array.

#lines(15, 35)

There is one `tty` for each terminal line. It contains the three
queues: characters as they arrive from the device (`t_rawq`), lines
after erase and kill processing (`t_canq`), and characters waiting to be
sent (`t_outq`). `t_oproc` is the driver's routine to start output, which
`ttstart` (#f("tty.c")) calls.

Several fields serve devices which this system lacks: `t_chan` belonged
to the multiplexed files and is always `NULL`; `t_iproc`, `t_linep`,
and `t_addr` are not used (v7's `kl.c` kept the device's address in
`t_addr`, but the PL011 is at a fixed address). The union `t_un` holds
the special characters or, when the state bit `CNTLQ` is set, a fourth
queue; nothing here sets that bit.

Two changes were forced by C99. The procedure pointers (41, 42) now
have prototypes, and return nothing, matching the routines stored in
them. The union (58--61) in v7 contained `struct tc;`, a structure with
no member name. The v7 compiler kept all member names in one table and
let any of them be applied to any structure, so `tp->t_un.t_intrc`
reached the first byte of the union without further ado. C99 does not
allow this: a structure without a name declares no member at all, and
C99 has no anonymous members. The structure is therefore given the
member name `tc`, and the shorthand `tun` (64), through which every use
in #f("tty.c") is written, now includes it, so that `tun.t_intrc` is
unchanged in the source.

#lines(36, 65)

`struct ttiocb` is the argument of `TIOCGETP` and `TIOCSETP`, and
corresponds to `struct sgttyb` in `sgtty.h`. `ioc_flags` is an `int`, so
the structure has grown from six bytes to eight; since the kernel and
the user programs agree on the size of `int`, nothing else follows.

#lines(66, 76)

The sleep priorities `TTIPRI` and `TTOPRI` are above `PZERO`
(#f("param.h")), so a process waiting for a terminal can be interrupted
by a signal. The default erase and kill characters are still `#` and
`@`. `TTHIWAT` and `TTLOWAT` bound the output queue: a writer sleeps when
it holds more than 100 characters and is woken when it has fallen to 50.
When the raw queue exceeds `TTYHOG` characters, all the queues are
thrown away.

The modes are those of `stty`. `NLDELAY`, `TBDELAY`, `CRDELAY`, and
`VTDELAY` are fields which select a terminal type for the output delays
in `ttyoutput`; `XTABS` is the value of the tab field which asks for
tabs to be expanded into spaces. `DONE` and `IENABLE` are the status
bits of a DEC serial interface; nothing in this system uses the
definitions here. Of the state bits, `XCLUDE` and `HUPCLS` may be set by
`ioctl`, but only v7's drivers for other interfaces (`dc.c`, `dh.c`, and
`dz.c`) acted on them, and
the console's driver ignores them; `DKCMD` to `DKLINGR` belong to the
datakit and are never set.

#lines(77, 130)

The `ioctl` commands encode a letter for the class of device and a
number. The `t` commands are carried out by `ttioccomm` (#f("tty.c")),
and `FIOCLEX` and `FIONCLEX` by `ioctl` itself. Of the `d` commands,
which are the datakit's, `ttioccomm` passes `DIOCGETP` and `DIOCSETP` to
the line discipline, which here rejects them; the `x` commands are the
multiplexor's.

#lines(131, 162)
#source("/usr/sys/dev/pl011.c")

#f("pl011.c") is the console driver for QEMU's `virt` machine. It
takes the place of v7's `kl.c`, the driver for the DEC KL11 and DL11
single-line serial interfaces, and it has been kept as close to
`kl.c` as the hardware allows: the file keeps `kl.c`'s comment, its
order, its procedure names (`klopen`, `klread`, `klstart`, and so on),
and its `tty` array `kl11`, so that the character switch in
#f("qemu/c.c") names the console's routines exactly as v7's did. The
STM32MP135's console driver, `stm32usart.c`, follows `kl.c` in the
same way and defines the same names; each board's kernel links only
its own.

The hardware is an ARM PrimeCell PL011 UART. Where the KL11 had four
registers on the UNIBUS (receiver status and data, transmitter status
and data), the PL011 has a single data register `UARTDR` for both
directions, a flag register `UARTFR` which tells whether the
transmitter has room, and a group of interrupt registers: a mask
(`UARTIMSC`), the masked status (`UARTMIS`), and a clear register
(`UARTICR`). The UART's receive and transmit buffers ("FIFOs") are
disabled after reset and the driver leaves them so; each then holds one
character, which is how the KL11 behaved.

#lines(1, 10)

`KLADDR` (12), the console's address, is no longer a pointer to a
`struct device` but the physical address of the UART, `0x09000000`, at
which the kernel maps it; the register macros (19--24) are built on it.
Each is `volatile`, since a read of `UARTDR` removes a character from
the receiver and a write sends one. `TXFF` (25) is the flag "transmitter
full"; `RXI` and `TXI` are the receive and transmit interrupt bits.

The other definitions are v7's. `KLBASE` and `DLBASE`, the addresses of
further KL11s and DL11s, and the receiver bits `DSRDY` and `RDRENB` are
no longer used, nor were the delay bits `NL1` to `TAB1` used even in
v7; they remain because they still compile. `DLDELAY` is still added to
every output delay (135).

#lines(11, 35)

The declarations of `ttrstrt` and `partab` have gone: the first is in
#f("systm.h") with a prototype, and the second is no longer used here.
`klirq` (38) is the console's interrupt number at the interrupt
controller, which `intrtab` (#f("qemu/c.c")) reaches through a pointer;
33 is shared peripheral interrupt 1, to which QEMU wires the UART. `struct
device` is v7's description of the KL11's registers and is now unused.

#lines(36, 46)

`klopen` no longer computes the device's address and stores it in
`t_addr`: there is only one line, and its registers are at a fixed
address. Where `kl.c` set the interrupt enable bits in the receiver and
transmitter status registers, `klopen` unmasks both interrupts in
`UARTIMSC` (66).

The default modes differ from v7's. v7 assumed an upper case terminal
(`LCASE`) needing a delay after carriage return (`CR2`); the port
leaves both out. With `LCASE` the console prints every letter in upper
case and the shell's `|` as `\!`, since `ttyoutput` (#f("tty.c"))
maps them for a terminal that has no lower case. With `CR2` each
carriage return is followed by a delay of 10 ticks, which with
`DLDELAY` makes 14 ticks, 0.23 seconds at 60 Hz: a listing of `/bin`,
107 lines, took 25 seconds to print. Without them lower case passes
unchanged in both directions and output runs at the speed of the line.
`EVENP` remains, although nothing here generates parity.

#lines(47, 68)

`klclose`, `klread`, and `klwrite` are v7's. As in v7, closing the
console does not disable its receiver interrupt, so characters typed
while it is closed still go to `ttyinput` and accumulate in the raw
queue until `TTYHOG` is reached.

#lines(69, 90)

`klxint` and `klrint` were reached in v7 through separate interrupt
vectors, whose processor status words carried the minor device number.
Here they are called only from `klintr` below, with minor device 0, and
are `static`.

`klxint` restarts output and wakes a writer once the queue has drained
to `TTLOWAT`. v7 first asked whether the line was attached to a
multiplexed file (`t_chan`), and if so called `mcstart` in `mx2.c`;
those files are not part of this system and the test has gone.

`klrint` reads the character from `UARTDR`. The KL11 had to be told
(`RDRENB`) to receive another character; the PL011 receives
continuously, and reading `UARTDR` also clears the receive interrupt.
The bits above the character which the PL011 returns, flags for
framing, parity, break, and overrun errors, are removed by the mask in
`ttyinput` (#f("tty.c")).

#lines(91, 112)

`klioctl` hands the commands to the common code. v7's `kl.c` called it
`ttioccom`, with one `m`, although #f("tty.c") defines `ttioccomm`. The
PDP-11 loader kept only eight characters of a symbol, counting the
underscore which the compiler prefixed to every external name, so to it
the two spellings were the same name. Here the misspelling would be an
undefined symbol, and is corrected.

#lines(113, 120)

`klstart` sends the next character of the output queue if the
transmitter has room, which is the meaning of the KL11's `DONE` bit; a
character above `0177` is a delay, and `ttrstrt` is scheduled to start
output again when it has passed.

v7 added the parity bit from `partab` to each ordinary character
(`c | (partab[c]&0200)`). The port sends the character as it is. The
UART is set for eight data bits without parity, as the PL011 is by
default and as terminal emulators expect, so the parity bit reaches the
terminal as part of the character: with it, the shell's prompt `#`,
which has odd parity, is printed as `£`. In `RAW` mode all eight bits
are sent, as `kl.c` did.

#lines(121, 139)

Two procedures are new. `klinit` is called by `cninit`
(#f("qemu/c.c")) early in `machine_init` (#f("machdep.c")). It sets
`UARTCR` to `0x301`, which enables the UART (bit 0), its transmitter
(bit 8), and its receiver (bit 9). The reset value leaves the UART
disabled; QEMU transmits regardless, but logs each character as a
guest error, and a real PL011 would send nothing.

`klintr` is the console's entry in `intrtab`, called by `irq`
(#f("machdep.c")) when the interrupt controller reports interrupt 33.
The one interrupt serves both directions, so the masked status is
examined to decide which of v7's two handlers to call. The transmit
interrupt is raised each time the transmitter has taken a character
and is cleared explicitly (153), before `klxint` perhaps writes the
next; it thus occurs once for each character sent, as the KL11's did.

#lines(140, 156)

`putchar` is the console output of `printf` (#f("prf.c")). It polls
the transmitter, bypassing the `tty` structure and its queues, and is
`kl.c`'s, with the PL011's registers in place of the KL11's. Every
character but null, carriage return, and delete is first copied into
the circular buffer `msgbuf`. The pointer `msgbufp`, which v7 defined
in `kl.c` just above `putchar`, is now defined in #f("machdep.c").

The procedure waits a bounded time for the transmitter to have room.
v7 bounded the wait by counting 30000 turns of its loop, some thirty
character times on the PDP-11. A count of turns means nothing on a
processor many times faster: a Cortex-A7 at 1 GHz makes them in about
one character time at 115200 baud, and the end of a panic message was
lost. The port bounds the wait by time instead. `timo` is set to the
value which the generic timer's counter, read by `cntvct_get`
(#f("mch.s")), will reach one clock tick later, `1/HZ` second or some
190 character times, and the loop gives up when the counter gets there.

The console's interrupts are masked while the character is written, as
v7 cleared the transmitter status register, and the old mask is
restored at the end. A newline is followed by a carriage return. v7
then sent two deletes, which gave a mechanical terminal time to return
its carriage; they are gone, since no terminal of today needs the time,
and they arrived among the output. The final call with 0 only waits for
the last character to leave.

v7 also gave up printing if the last character
received was a null or a break. That test has gone: on the PL011 it
could not be made without reading `UARTDR`, which would remove a
character from the receive queue and so steal it from the input. The comment
about the console switches was already stale in v7.

#lines(157, 198)
#source("/usr/sys/dev/tty.c")

#f("tty.c") holds the code common to all terminals: what a driver such
as #f("pl011.c") does not need to know about. Under it lie the device
routines, which move single characters to and from the hardware; above
it, the `read`, `write`, and `ioctl` system calls. Between them it
implements v7's one line discipline, discipline 0 of `linesw`
(#f("qemu/c.c")): erase and kill processing, echoing, the interrupt,
quit, stop, and start characters, the expansion of tabs, the mapping of
newline to carriage return and line feed, the conventions for upper
case terminals, and the delays which slow terminals need.

Its procedures fall into two halves. The "top half" runs on behalf of a
process, in `read`, `write`, `open`, `close`, and `ioctl`, and may sleep.
The "bottom half", `ttyinput` and `ttstart` with what they call, is
reached from the driver's interrupt routine and may not. The queues of
the `tty` (#f("tty.h")) lie between the two, and the top half raises the
priority with `spl5` whenever it examines them. On the ARM this masks
the IRQ, as do `spl6` and `spl7` (#f("mch.s")).

v7 included `mx.h` here for the multiplexed files (`mx1.c` and
`mx2.c`). They are not part of this system, so the include, and the
three places below which handed characters or signals to a multiplexed
channel, have gone. The tests of `t_chan` which remain (347, 710) still
compile, and always find it `NULL`.

`partab` (16) is now declared `extern`. In v7 `char partab[];` at file
level was taken as a reference to the array in #f("partab.c"); in C99
it is a tentative definition, which would give this file an array of
its own. The four procedures declared at (17, 18) are used before they
are defined, and only in this file; C99 requires a declaration first.

#lines(1, 19)

`maptab` is used by `canon` for a character preceded by a backslash.
A non-zero entry is the character which the pair stands for on an upper
case terminal: `\(` stands for `{`, `\!` for `|`, and `\a` (typed as
`\A`, since such a terminal's input is folded to lower case) for a real
capital. `canon` makes an escaped erase or kill character, whatever it has been
set to, stand for itself (374, 375).
The table has only 128 entries, which suffices since `canon` consults
it only for characters already cut to seven bits.

#lines(20, 55)

`ttyopen` is called by the driver's open routine. If the opening process
belongs to no process group, as a process descended from `init` does
until it opens a terminal, this terminal becomes its controlling
terminal, recorded in `u` for #f("sys.c"), and the process joins the
terminal's group. The group is named by the process id of the first
process to join it, normally the child which `init` forks for the line
and which opens it before becoming `getty`; and it is to this group that `ttyinput` sends interrupts and quits.

`ttyclose`, called on the last close, dissolves the group and waits
for output to drain before discarding everything else.

#lines(56, 107)

`stty` and `gtty` are the older system calls, kept for programs
written before `ioctl`. Each rearranges its arguments in `u.u_arg` into those of an
`ioctl` with the command `TIOCSETP` or `TIOCGETP`, and calls `ioctl`.

`ioctl` itself deals with the two commands which concern the file
descriptor rather than the device, setting or clearing close on exec,
and passes everything else to the character device's `ioctl` routine.

#lines(108, 165)

`ttioccomm` performs the commands common to all terminals; a driver's
`ioctl` routine calls it, and reports `ENOTTY` if it returns zero.

`TIOCSETD` changes the line discipline. `t` is unsigned, so a negative
number fails the test against `nldisp`, which is 1 here. The cast
(196) is new. It makes explicit the conversion of `nldisp` to unsigned
which C performs in any case, so that the compiler need not warn of a
comparison between signed and unsigned values. Likewise `t_line`, a `char`, is
now converted to `int` (201, and again at 266) before it subscripts
`linesw`: a `char` subscript draws a warning, since `char` is signed on
some machines.

v7 passed `addr` as a third argument to the discipline's open routine
(203). No open routine in v7 or here takes one, and with a prototype for
`l_open` (#f("conf.h")) the call must match it, so the argument has
gone.

#lines(166, 207)

`TIOCSETP` waits for output to drain and discards input before the new
modes are installed; `TIOCSETN` installs them at once. The comment
(223) is new: it tells the compiler, which otherwise warns, that falling
from one case into the next is intended.

`TIOCSETC` and `TIOCGETC` copy the special characters as a block,
the six bytes of `struct tc`, through the shorthand `tun`.

#lines(208, 286)

`wflushtty` waits, at `spl5`, until the driver has sent every character
of the output queue, then flushes the queues. The sleep on `t_outq` is
ended by the driver's transmit interrupt (`klxint`, #f("pl011.c")),
which wakes a sleeper when `ASLEEP` is set and the queue has drained to
`TTLOWAT`.

`flushtty` throws away the contents of all three queues and wakes
anyone waiting for them. The driver's `d_stop` routine is called to
abandon output in progress; the console needs none, and its entry is
`nulltty` (#f("subr.c")).

#lines(287, 327)

`canon` moves one line from the raw queue to the canonical queue,
which `ttread` then copies to the user. In the normal mode it waits
until the raw queue holds at least one complete line, which `ttyinput`
marks by appending a delimiter and counting it in `t_delct`; in `RAW`
or `CBREAK` mode it waits for any character at all. If the line is not open,
`CARR_ON` is clear and `canon` returns zero at once.

`canon` is now `static`. Only this file calls it, and the change spares
it a declaration in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand.

The extra parentheses in the condition (345, 346) are new and make
explicit what v7 left to the precedence of `&&` over `||`; the meaning
is unchanged. v7's early `return` (349) left the processor at `spl5`,
and so kept every interrupt, the clock's among them, masked until the
process next returned to user mode. `spl0` (348) now unmasks them
first, as the normal path does after the loop.

#lines(328, 353)

The line is assembled in `canonb` (#f("systm.h")), starting at its
third byte, so that `bp[-1]` and `bp[-2]` can always be examined: the
two bytes before the line remain zero. An erase removes the last
character, a kill restarts the line, and the end of file character is
dropped, so that one typed at the start of a line yields a read of no
bytes. After a backslash, `maptab` is consulted; if the pair is to be
replaced, `bp` steps back over the backslash, unless the backslash was
itself escaped. The delimiter `0377` cannot be mistaken for a typed
character, since in the normal mode `ttyinput` keeps only seven bits.

When the queue has emptied below a fifth of `TTYHOG`, a terminal which
was told to stop sending (`TBLOCK`, see `ttyblock`) is sent the start
character.

#lines(354, 399)

`ttyrend` accepts a block of input at once, from a driver which receives
by DMA. No driver here does so, and the slot `l_rend` of `linesw` is
empty; v7's `mkconf` had in fact put `ttstart` in that slot, one place
too early, and it now occupies `l_start`. v7 began the raw case by
handing the block to a multiplexed channel, if there was one; the
`else` has gone, which is why the `wakeup` (413) is indented as it is.

#lines(400, 422)

`ttyinput` is called by the driver's receive interrupt with each
character. `tk_nin` counts them for the statistics of `iostat`. The
mask with `0377` (437) keeps the character proper: the PL011 returns
error flags above it.

In the normal mode the character is cut to seven bits and the special
characters act at once. The stop and start characters suspend and
resume output. The interrupt and quit characters flush the queues and
send `SIGINT` or `SIGQUIT` to every process in the terminal's group by
`signal` (#f("sig.c")); v7 first offered the signal to a multiplexed
channel, and the indentation of the call (465) is a remnant of the
`else` which followed.

The raw queue is discarded entirely if it has grown beyond `TTYHOG`,
on the theory that nobody is reading it. Otherwise the character is
appended; at the end of a line, or for any character in `RAW` or
`CBREAK` mode, readers are woken, and in the normal mode a delimiter
is appended too, counted only if `putc` succeeded. Finally the
character is echoed, a kill being followed by a newline, and output
started. The echo goes through `ttyoutput` at interrupt level, which
is why `ttyoutput` must never sleep.

#lines(423, 490)

`ttyblock` serves `TANDEM` mode, in which the terminal is a machine
that obeys the stop and start characters itself. When the raw and canonical
queues together hold half of `TTYHOG`, the stop character is sent to
it.

#lines(491, 512)

`ttyoutput` puts one character on the output queue, transformed as the
modes require. In `RAW` mode it goes unchanged. Otherwise a tab may be
expanded into spaces by recursive calls; for an upper case terminal,
the characters which it cannot print are replaced by a backslash and a
substitute, and lower case letters by capitals; and with `CRMOD` a
newline is preceded by a carriage return.

#lines(513, 572)

The rest of `ttyoutput` maintains `t_col`, the column of the carriage,
and computes the delay which should follow the character. The class of
the character comes from `partab` (#f("partab.c")), and the terminal's
type from fields of `t_flags`. A delay of `c` clock ticks is queued as
the character `c|0200`, which the driver recognises as a delay rather
than a character to send (`klstart`, #f("pl011.c")); since ordinary
characters were cut to seven bits above, there is no confusion.

For the tab of a Model 37 teletype, `1 - (*colp | ~07)` is the
number of columns to the next tab stop. The expression works as in v7
although `t_col` is now an unsigned `char`: it is promoted to `int`
before the `|`, and the result is the same. The comment at (589) is
new, as at (223).

#lines(573, 645)

`ttrstrt` is called by the clock when a delay has expired; it clears
`TIMEOUT` and restarts output. It now takes the `caddr_t` which
`timeout` (#f("clock.c")) passes to it, and converts it to the `tty`
pointer that v7 declared directly as its parameter: `timeout`'s
prototype admits only procedures taking a `caddr_t`.

`ttstart` calls the driver's start routine, unless output is stopped,
delayed, or already in progress.

#lines(646, 677)

`ttread` and `ttwrite` are the line discipline's read and write
routines, which the driver's own routines call. `ttread` copies the
canonical queue to the user, refilling it with `canon` when it is
empty. Its result, the number of characters still waiting, served the
multiplexed files and is ignored here.

`ttwrite` passes each character from the user to `ttyoutput`. When more
than `TTHIWAT` characters are queued it starts output and sleeps,
until the transmit interrupt wakes it at `TTLOWAT`. For a multiplexed line it
would instead return the address to wait on (710, 711); since `t_chan`
is always `NULL`, it returns `NULL`.

#lines(678, 721)

= More Drivers

#source("/usr/sys/conf/qemuconf")

#f("qemuconf") describes the QEMU `virt` board to `mkconf`
(#f("mkconf.c")), which reads it on its standard input and writes
#f("qemu/c.c") and #f("qemu/unix.ld"). The first five lines are in v7's
own format, and could have come from v7's `rktmconf`. A line holding
only a device name (`rk`) configures one such device; `root` and `swap`
name the device and minor device of the root file system and of the
swap area; `swplo` and `nswap` give the first block and the length of
the swap area. v7's `rktmconf` put the swap area at block 4000 of the
RK05; here it starts at block 10648, just after the root file system
(#f("rootfs.proto")), and holds 872 blocks, v7's figure. v7 also
configured a magnetic tape, `tm`, of which this system has none.

The console, `mem`, and `tty` are not named, since `mkconf` configures
them unasked.

#lines(1, 5)

The remaining lines are new, and describe the board rather than its
devices. All the numbers are hexadecimal, without the `0x`.

`ram` gives the origin and length of the memory into which the kernel
is linked: the first 64 MB of QEMU's memory, at `0x40000000`. `core`
bounds the memory which holds process images, the 64 MB above it.
`gic` gives the addresses of the interrupt controller's distributor and
processor interface. `pguser` is the attribute part of a second level
page table entry for a user page; `0x47e` is a small page, readable and
writable in user mode, shareable, and cached write-back.

Each `map` line names a range of physical addresses which the kernel
maps at the same virtual address, in sections of 1 MB, and the
attributes of the section entries, copied into #f("qemu/c.c") as
written. `SEC_KERN` and `SEC_DEV` are defined in #f("seg.h"). The first
line covers all of memory, kernel and core alike; the second the
devices, among them the interrupt controller, the UART, and the virtio
transports.

#lines(6, 11)
#source("/usr/sys/conf/mp135conf")

The configuration of the STM32MP135 board, in the format of
#f("qemuconf"). The devices, root, and swap are the same: one disk,
configured as `rk` although it is an SD card driven by #f("stm32sd.c"),
holding the root file system and, after it, the swap area. The console
is the board's UART, driven by #f("stm32usart.c").

#lines(1, 5)

The memory of the MP135 is in two pieces which are not contiguous. The
boot ROM loads the kernel from the SD card into the 128 KB of on-chip
SYSRAM at `0x2ffe0000` and jumps to it; this is `ram`. Process images,
and anything else too large for SYSRAM, live in the 512 MB of external
DDR memory at `0xc0000000`.

`tables` is a keyword which only this board uses. It names a second
region for the linker, into which `mkconf` places the section
`.ddrbss`: the first level page table and the two second level tables
reserved in #f("mch.s"), 18 KB which SYSRAM cannot spare. They take the
start of DDR, and `core` therefore begins 1 MB higher, at `0xc0100000`.

`pguser` (10) is `0x472`, which differs from QEMU's `0x47e` in leaving
out the cache bits: a user page is normal memory, but not cached. The
`map` line for DDR (12) has the corresponding attributes, `0x11402`,
where QEMU's memory is mapped `SEC_KERN`. The reason is the SD card's
DMA controller, which does not see the processor's data cache. Process
images are read and written by DMA, during swapping and raw I/O, and
with the core uncached no cache maintenance is needed for them. The
user mapping must then be uncached too, since the kernel writes a new
image (in `fork` and `exec`) through its own mapping of DDR, and the
process would otherwise read stale lines through a cached one. The
kernel itself, in SYSRAM, is cached (11), and the disk driver cleans and
invalidates the cache around each transfer to or from the buffer cache.

The other maps are the peripherals (13) and the interrupt controller
(14), which on this chip lies apart from them.

The last line, `ddr`, asks for `ddrinit` (#f("stm32ddr.c")) to be called
early in `machine_init` (#f("machdep.c")), before the page tables in DDR
are touched.

#lines(6, 15)
#source("/usr/sys/conf/mkconf.c")

`mkconf` is the program by which a kernel is configured. It reads a
description of the installation (#f("qemuconf"), #f("mp135conf")) and
writes the files which differ from one installation to another. v7's
`mkconf` wrote three: `c.c`, the device switches and tables; `l.s`, the
PDP-11's interrupt vectors and the assembler stubs which led from each
vector to its C handler; and `mch0.s`, a few assembler definitions
which chose the tape on which the system would dump core after a crash.
This one writes two: `c.c`, as before (#f("qemu/c.c")), and a linker
script, `unix.ld` (#f("qemu/unix.ld")).

The port keeps v7's program and its device table, and changes it in
four ways. The pass which wrote `l.s` is gone, since the ARM's vectors
are fixed (#f("low.s")) and interrupts are routed by a table in `c.c`;
so is the pass which wrote `mch0.s`, since there is no crash dump. A new
first pass writes the linker script. The configuration has new
keywords for the facts about the board, and `c.c` gets a new tail which
records them. Lastly, the strings which `mkconf` copies into `c.c`
have been made acceptable to a C99 compiler.

`mkconf` runs on the host, not on the target, and is compiled as strict
C99 like the rest. `<string.h>` (2) declares `strcmp`, which v7 used
undeclared. The prototypes (4, 5) are needed because the procedures are
used before they are defined.

The flag bits (7--14) are v7's. `CHAR`, `BLOCK`, `ROOT`, `SWAP`, and
`PIPE` are still used. `INTR`, `EVEN`, and `KL` controlled the layout of
the vectors in `l.s`, and are now inert.

#lines(1, 15)

The order of the names in `btab` and `ctab` is the order of the entries
in `bdevsw` and `cdevsw`: the index of a name is its major device
number. A device which is not configured still occupies its place, so
that the numbers never change, and the special files on the disk remain
valid whatever the configuration. Both lists are v7's.

#lines(16, 51)

`struct tab` describes one kind of device: its name; the number of
such devices configured (`count`), negative for those which are always
present and may not be configured; the address of its interrupt
vector on the PDP-11 (`address`); its flags; and seven strings. `codea`,
`codeb`, and `codec` are PDP-11 assembler, the vector and the stubs for
`l.s`, and are no longer used. `coded` and `codee` are the device's
entries in `bdevsw` and `cdevsw`, and `codef` and `codeg` any
declarations which those entries need, written into `c.c` before the
switch.

Every entry of the table now has its own braces, which C99 compilers
expect (`-Wmissing-braces`); v7 initialised the array of structures as
one flat list.

The console's entry and that of `mem` are changed in their `cdevsw`
strings and their declarations. Each slot of a switch now has a type of
its own (#f("conf.h")), so v7's `nodev` in the `ioctl` slot becomes
`noioctl` and its `nulldev` in the `d_stop` slot becomes `nulltty`. The
declarations, such as `int klopen(), klclose(), ...`, are now empty
strings: every driver routine is declared with a prototype in
#f("systm.h"), which `c.c` includes, and v7's old-style declarations
would conflict with them.

#lines(52, 89)

The entries for devices which no configuration of this system names
are unchanged but for their braces. Their declarations remain in v7's
style, and their drivers do not exist; to configure one would produce a
`c.c` which neither compiles cleanly nor links. The entries for the
clock and for memory parity never contributed anything but vectors, and
are now without effect.

#lines(90, 205)

The `rk` entry has the same changes as the console's. Its block
declaration was `int rkstrategy();` and a definition of `rktab`, the
head of the disk's queue, which the disk driver also defined; v7's
loader merged the two as a common symbol. Now `rkstrategy` is declared
in #f("systm.h"), and `rktab` is declared `extern`, so that the driver's
definition (#f("virtio_blk.c"), #f("stm32sd.c")) is the only one. Both
boards' disk drivers took v7's `rk` names, so this one entry serves for
each.

#lines(206, 217)

The rest of v7's table is unchanged but for braces, except for `tty`,
the controlling terminal, whose `d_stop` slot becomes `nulltty`. v7's
terminating `0` is now `{0}`.

#lines(218, 420)

`stre` heads `c.c` with its includes. v7 followed them with
declarations of `nulldev` and `nodev`; those are in #f("systm.h"), and
their place is taken by the include of #f("seg.h"), which defines
`struct memregion` and the section attributes used at the end of
`c.c`.

#lines(421, 439)

The remaining text of `c.c`. v7 wrote a bare `0` after the last entry
of each switch; the port writes `{0}`, again for the braces. In `strg`,
v7 printed `nswap` with `%l`, which is not a conversion of C99's
`printf`: the compiler rejects it, and the host's library prints `%;`
in place of the number. Since `nswap` is an `int`, the port uses `%d`.

v7 had one more array here, `strg1a`, which defined `ldmpx`, a pointer
to `mpxchan` used by the multiplexed files, unless the configuration
said `mpx`. The multiplexor is not part of this system, and the array is
gone. The declarations of the line discipline routines, before `strj`,
are gone for the same reason as the drivers'. The discipline's row
is changed as described under #f("qemu/c.c"): it has braces, typed
null routines, and `ttstart` in the slot `l_start`, where v7 had put it
in `l_rend`. The row for the packet driver `pk` (`strk`), which a
`pack` line would add, gets braces and zeros for the three slots v7
omitted; its declarations (`stri`) are v7's.

#lines(440, 519)

v7's variables, followed by new ones (533--538) which hold the board
description: whether DDR must be started (`ddr`); the origin and length
of the kernel's memory (`ramb`, `ramn`) and of the region for its page
tables (`tabb`, `tabn`); the core window; `pguser`; the addresses of the
interrupt controller; and up to `NMAP` regions to be mapped, each with
its attributes kept as text. The length of `mapa`'s strings is that of
an input line, so that no token can overflow it. v7 declared `pack`
twice (521, 531), which C permits for a variable without an initialiser.

#lines(520, 539)

The configuration is read in one go, and then the outputs are written,
each by redirecting the standard output with `freopen`, as v7 did.

The first pass, which in v7 wrote `l.s`, now writes the linker script.
The kernel's text, read-only data, initialised data, and uninitialised
data (`.bss`) are placed one after another in `RAM`. The symbols
`__bss_start` and `__bss_end` tell `low.s` (#f("low.s")) what to clear;
`__bss_start` is aligned to a word, since the clearing is done a word at
a time before the MMU is on, when an unaligned store faults. The section
`.ddrbss` holds the page tables. It is aligned to 16 KB, which the first
level table requires, is not loaded (`NOLOAD`), and is cleared by
`machine_init` (#f("machdep.c")) once memory is ready. It is placed in
the `tables` region if the configuration has one, as on the MP135, and
otherwise in `RAM`. No entry point is named; the linker's default,
`_start`, is the right one. Between the regions and the sections the
symbol `u` is set to `0x4F000000`, the value of `UBASE` (#f("param.h")),
as v7's `mch.s` set `_u`; `mkconf` is a program of the build machine
and does not include the kernel's headers, so the address is written
out here, and the two must agree.

#lines(540, 566)

The second pass writes `c.c` as v7 did. The assignments within the
tests of the `for` loops (577, 584, 609, 616) are wrapped in a second
pair of parentheses, which tells the compiler that `=` is meant. Each
configured row is now enclosed in braces. A device which is not
configured gets a row of routines which fail: v7 wrote `nodev` in every
slot, but the slots now have types of their own, so a block device's
strategy slot gets `nostrat`, and a character device's read and write
slots `nordwr`, its `ioctl` slot `noioctl`, and its `d_stop` slot
`nulltty` (#f("conf.h")).

#lines(567, 625)

The line disciplines, root, swap, and pipe devices, and the tables
follow as in v7, except that the definition of `ldmpx` has gone.

#lines(626, 641)

The tail of `c.c` is new. It defines the board's addresses for the
kernel, the core window, `pguser`, and the interrupt controller, which
#f("machdep.c") and #f("seg.h") use; `board_map`, the regions to map,
whose attributes are copied as written in the configuration, so that
it may name `SEC_KERN` and `SEC_DEV`; and `intrtab`, which pairs the
console's and the disk's interrupt numbers with their handlers.

Last come three small procedures by which the machine-dependent code
starts the configured drivers without naming them: `cninit`, `bdinit`,
and `clock_ddr_init`, which calls `ddrinit` only if the configuration
said `ddr`. The names they call, like those in `intrtab`, are fixed:
every board's drivers use v7's `kl` and `rk` names, and only one
board's drivers are linked into a kernel.

v7 ended `main` by writing `mch0.s`, which set `HTDUMP` or `TUDUMP`
according to whether a TU16 tape was configured, so that the core dump
routine in `mch.s` knew where to write. There is no dump routine in
this system, and the pass is gone.

#lines(642, 657)

`puke` writes a list of lines. v7 passed a second argument, which each
line could use as a `printf` argument; no line used it, and it is gone.

#lines(658, 668)

`input` reads one line of the configuration. The arrays `keyw` and `dev`
were 32 characters long in v7, while a line may be 99; since `%s` copies
a whole word, a long word overflowed them. They are now as long as the
line.

v7 first scanned the line for an optional count, a keyword, a device,
and a number, and if no count was found, took the count as 1 and
added one to the number of fields converted. The test `n>0` shows
that v7's `sscanf` went on to the later conversions when the leading
number was missing, and so it did: v7's `_doscan` has no exit on a
failed conversion. C99's `sscanf`, which is the host's here, stops at
the first failure and returns 0, so the port scans the line a second
time without the count.

The keywords which describe the board are recognised first (689--708).
Their numbers are read in hexadecimal. A malformed line is reported by
`badline`, a new procedure holding v7's message, which returns 1, so that
reading continues as in v7. A ninth `map` line falls through to "cannot
find".

#lines(669, 708)

The remainder of `input` is v7's. A device name adds to that device's
count, subject to the checks that a fixed device is not configured and
that a device whose vector has a fixed address is configured only
once. The addresses in the table are the PDP-11's octal vector
addresses written as decimal numbers; from 300 on lie the floating
vectors, allotted in turn, so that several devices of a kind could be
configured. The other keywords set the swap area, the root, swap,
and pipe devices, and the options `pack` and `mpx`; `mpx` is now
accepted and ignored.

#lines(709, 791)

`badline` is the end of v7's `input`, made a procedure so that the new
keywords can use it in an expression. `equal` is v7's.

#lines(792, 804)
#source("/usr/sys/conf/mp135/c.c")

The configuration of the STM32MP135, written by `mkconf`
(#f("mkconf.c")) from #f("mp135conf"). Since the two configurations
name the same devices, root, and swap, the first 75 lines are identical
to those of #f("qemu/c.c"), to whose commentary the reader is referred.
The routines behind the names are different: `kl` is now the UART
driver #f("stm32usart.c"), and `rk` the SD card driver #f("stm32sd.c").

#lines(1, 75)

The kernel is linked at the start of SYSRAM, `0x2ffe0000` (76), and
process images occupy DDR from `0xc0100000` to its end (77). `pguser`
(78) maps user pages uncached, for the reason given under #f("mp135conf").
The interrupt controller is the Cortex-A7's own, at `0xa0021000` and
`0xa0022000` (79).

`board_map` maps four regions at their own addresses: the 1 MB which
contains SYSRAM, cached, for the kernel; DDR, uncached; the 512 MB of
peripherals; and the 1 MB containing the interrupt controller.

#lines(76, 88)

`intrtab` is the same as QEMU's, though the numbers behind `klirq` and
`rkirq` differ (85 and 82, #f("stm32usart.c"), #f("stm32sd.c")). The one
difference in the glue is `clock_ddr_init`, which here calls `ddrinit`
(#f("stm32ddr.c")), since the configuration ends with `ddr`.

#lines(89, 100)
#source("/usr/sys/dev/stm32usart.c")

The console driver of the STM32MP135 board. Like #f("pl011.c") on QEMU,
it is v7's `kl.c` with a different device under it, and it keeps
`kl.c`'s comment, order, names, and `tty` array `kl11`, so that the
switch entry `klopen, klclose, klread, klwrite, klioctl` in
#f("mp135/c.c") is v7's. Only one of the two drivers is linked into a
kernel. Where the two drivers make the same change to `kl.c`, as in the
default modes in `klopen`, the omission of the parity bit in `klstart`,
and the break test in `putchar`, the commentary on #f("pl011.c") applies
and is not repeated here.

The device is UART4, one of the chip's USARTs ("universal synchronous
asynchronous receiver transmitter"), whose pins the board brings out
as its serial console. Its registers differ from
both the KL11's and the PL011's. There is one control register `CR1`,
holding the enables of the unit, transmitter, and receiver and of the
interrupts; a baud rate register `BRR`; an interrupt and status register
`ISR`; a register `ICR` for clearing error flags; and separate
registers for received (`RDR`) and transmitted (`TDR`) data.

#lines(1, 10)

`KLADDR` is the physical address of UART4, at which the kernel maps it.
`RCC` (15) is the chip's reset and clock controller and `GPIOD` (16) the
fourth port of general purpose pins; `klinit` needs a few registers of
each. The bits of `CR1` (33--37) are those for the enables; `RXNE`
("receive register not empty") and `TXE` ("transmit register empty")
are the status bits in `ISR`. The unused definitions of `kl.c` stay, as
they do in #f("pl011.c").

#lines(11, 47)

`klirq` is 85, shared peripheral interrupt 53 of the interrupt
controller, to which the chip wires UART4. v7's declarations of
`ttrstrt` and `partab` have gone, as in #f("pl011.c").

#lines(48, 58)

`klinit` is called by `cninit` (#f("mp135/c.c")) at the start of
`machine_init` (#f("machdep.c")), before the MMU is on. The kernel
otherwise takes the clocks as the boot ROM left them, but the UART
is given a clock of its own choosing so that its speed does not depend
on that state. In turn: the clock of `GPIOD` is enabled (62), and pins
PD6 and PD8 are switched to their alternate function 8 (64--66), which
connects them to UART4's transmitter and receiver. The clock of UART4
is enabled on its bus (67), and HSI, the internal 64 MHz oscillator,
which runs from reset, is chosen as its kernel clock (69). `BRR` (70)
divides that clock to 115200 baud: 64000000/115200 is 555.6. Lastly
the unit, the transmitter, and the receiver are enabled. Every other
bit of `CR1` is written as zero: eight data bits, no parity, and the
UART's FIFOs disabled, so that one character is held in each direction,
as on the KL11.

The registers which enable clocks are of a "set" kind: a one sets the
corresponding bit, and a zero leaves it alone. Each write is followed
by a read of the same register (63, 68), which does not complete until
the write has, so that the clock is running before the device it feeds
is touched.

#lines(59, 73)

`klopen`, `klclose`, `klread`, and `klwrite` are those of #f("pl011.c"),
except that the receiver interrupt is enabled by setting `RXNEIE` in
`CR1` (93). The transmitter interrupt is not enabled here; see
`klstart`.

#lines(74, 117)

`klxint` turns off the transmitter interrupt (125) before calling
`ttstart`, which will turn it on again if it sends a character. The
reason lies in the nature of `TXE`. The PL011, like the KL11, raises
its transmit interrupt once, when a character has gone. The USART's
`TXE` is a condition, not an event: it is set whenever the transmit
register is empty, and while both it and `TXEIE` are set the interrupt
remains asserted. With nothing more to send, an enabled interrupt would
be taken again the moment it was returned from.

`klrint` takes the character from `RDR`, which also clears `RXNE`.
Writing 017 to `ICR` (139) clears the error flags for parity, framing,
noise, and overrun. An overrun in particular, with `RXNEIE` set, would
otherwise hold the interrupt asserted for good.

#lines(118, 141)

`klioctl` is that of #f("pl011.c"), with v7's misspelling `ttioccom`
corrected.

#lines(142, 150)

`klstart` sends the next character if the transmit register is empty,
or arranges a delay, as in `kl.c`. `TXEIE` is set (167) whenever
something was taken from the queue, so that the interrupt follows when
the character has gone. Strictly, for a delay nothing has been
written, `TXE` stays set, and the interrupt comes at once; `klxint` then
calls `ttstart`, which finds the `TIMEOUT` state set and returns, and
the interrupt is disabled until `ttrstrt` restarts output.

#lines(151, 170)

`klintr` is the entry in `intrtab`, called by `irq` (#f("machdep.c"))
for interrupt 85. It calls one or both of v7's handlers. The test of
`TXEIE` (176) is needed because `TXE` is set nearly always, and an
interrupt from the receiver must not be taken for one from the
transmitter.

#lines(171, 179)

`putchar` is `kl.c`'s with `ISR`, `TDR`, and `CR1` in place of the
KL11's registers. Where `kl.c` cleared the transmitter status register,
and with it the interrupt enable, this clears `TXEIE` alone, since the
receiver's enable lives in the same register and must be kept; the
whole of `CR1` is restored at the end. If output was in progress,
`TXEIE` comes back set and the transmit register is empty, and the
interrupt which follows restarts it. The wait for the transmitter is
bounded by time, and a newline is followed by a carriage return alone,
as in #f("pl011.c").

#lines(180, 220)
#source("/usr/sys/dev/stm32sd.c")

The disk of the STM32MP135 board is its SD card, and this is its
driver. Like #f("virtio_blk.c") on QEMU, it replaces v7's `rk.c` and
takes over its names, its configuration entry, and its shape: a queue
headed in `rktab`, `rkstrategy` to add a request, `rkstart` to give the
head of the queue to the device, `rkintr` to finish it and start the
next, and `rkread` and `rkwrite` for the raw disk. It is closer to
`rk.c` than the virtio driver, because the device is closer to an RK11:
it is given a command and the address of a buffer, moves the data by
DMA, and interrupts when done.

The controller is SDMMC1. Two of its parts matter here. The command
path sends a command to the card, with a 32-bit argument, and receives
the card's response; the data path moves blocks of data between the
card and the controller, and the controller's own DMA engine, the
"IDMA", moves them between the controller and memory. A read is
command 17, `READ_SINGLE_BLOCK`, whose argument is the number of the
block; a write is command 24, `WRITE_BLOCK`.

Much is assumed. The boot ROM has just loaded the kernel from this
card, so the card is powered, identified, selected, and in the state
in which it accepts these commands, and the controller's clock and bus
width are set. The driver issues none of the commands by which a card
is brought to that state, and touches neither the clock nor the pins.
It also assumes a high capacity (SDHC or SDXC) card, whose commands
address 512-byte blocks; an older card counted in bytes.

#lines(1, 11)

v7's `RKADDR`, the RK11's registers as a `struct device`, becomes `SD`,
the register of the controller at offset `off`; the structure is
deleted. `NRKBLK` (14) is the number of blocks the system uses, the
file system and the swap area of the configuration (#f("mp135conf")),
which end at block 11520. The card itself is larger, but its size could
be read only with a command which the card accepts in another state
than the one the ROM leaves it in. `NRK` and the RK11's bits are kept
although unused, as in #f("virtio_blk.c"), but four of the names are
given new values and used. `RCOM` and `WCOM` (17, 18) are the command numbers 17 and 24.
`GO` (19) holds the bits of the command register which start a
command: `CPSMEN` (`0x1000`), which enables the command path;
`WAITRESP` equal to 1 (`0x100`), which asks for a short response; and
`CMDTRANS` (`0x40`), which says that the command is one with data, so
that the data path starts with it. `IENABLE` (21) is the interrupt mask:
the six bits for command and data CRC failures, command and data
timeouts, transmit underrun, and receive overrun (`0x3f`); the end of
the data (`0x100`); and an IDMA transfer error (`0x8000000`). `ERR`
(36) is the same set without the end of data.

The register offsets (26--35) follow. In the data control register,
`BLK512` (38) sets the block size to 512 bytes and `DTDIR` (37)
the direction from card to controller. `CLEAR` (39) has a bit for every
flag that the interrupt clear register can clear.

#lines(12, 40)

`rkstart` is declared (46) because `rkstrategy` calls it before its
definition. `rkirq` is 82, shared peripheral interrupt 50, to which the
chip wires SDMMC1. `rktab` and `rrkbuf` are v7's. `rkoff` is new: the
offset within the current request of the block being transferred.

#lines(41, 51)

`rkinit`, called by `bdinit` (#f("mp135/c.c")) at the end of
`startup`, sets the data timeout to its largest value, so that a slow
card is waited for; everything else is as the ROM left it. The timeout
is the one setting the ROM's state cannot be trusted for: the ROM only
reads, and a card may take far longer to finish a write than a read.

#lines(52, 57)

`rkstrategy` is v7's, with more in its test of the request. A block
number beyond `NRKBLK` is rejected, as v7 rejected one beyond the end
of the pack, and so is a request whose count is not a whole number of
blocks or whose buffer is not on a word boundary, neither of which the
card and the IDMA can do: the IDMA's address register ignores the two
low bits. The buffer cache and the swap area always move whole blocks
from aligned addresses, so these two tests can fail only for raw I/O, which `physio` (#f("bio.c")) lets through
with an even address and count.

#lines(58, 80)

`rkstart` transfers one block of the request at the head of the queue,
the one at offset `rkoff`. Commands 17 and 24 move exactly one block,
and a request from `physio` may be longer; `rkintr` steps through it.
v7 converted the block number into the drive, cylinder, and sector of
the RK05 and loaded four registers; here the minor device is ignored,
since there is one card, and the block number is the argument of the
command.

The cache is cleaned and invalidated over the block's buffer (90) by
`dcflush` (#f("mch.s")), which writes any modified lines to memory and
discards them. The IDMA reads and writes memory directly, without
seeing the processor's data cache: before a write the data must be in
memory, and before a read no modified line may be left to overwrite
the incoming data later. For the core, which DDR holds uncached
(#f("mp135conf")), this does nothing; it matters for the buffer cache in
SYSRAM, which is cached.

The device is then programmed in the order the controller requires:
the old flags are cleared, the data path is stopped and given the
length and the block size and direction, the IDMA is given the
buffer's address and enabled, the interrupts are unmasked, and the
argument is set. Writing the command register (103) starts the
transfer. The counts for `iostat` are v7's, but count one block per
command.

#lines(81, 109)

`rkintr` is called by `irq` (#f("machdep.c")) at the end of the data or
on an error. It reads the status, clears every flag, masks the
interrupts, and stops the IDMA, so that a stray interrupt finds the
device quiet; then, as in v7, it ignores an interrupt for which no
request is active.

On an error the status is reported by `deverror` (#f("prf.c")) and the
same block retried, up to v7's ten times. v7 also reset the RK11 and
waited for it to be ready; there is no reset here. On success the next
block of the request is started if there is one (132), and the request
is otherwise complete. After a read, the cache is cleaned and
invalidated once more over the whole buffer, so that any line which the
processor may have fetched while the transfer was under way is
discarded. The rest is v7's.

#lines(110, 145)

`rkread` and `rkwrite` are v7's, for the raw disk.

#lines(146, 158)
#source("/usr/sys/dev/stm32ddr.c")

This file is not a driver in v7's sense: it has no switch entry and no
special file, and its one procedure, `ddrinit`, is called once, early
in `machine_init` (#f("machdep.c")), through `clock_ddr_init`
(#f("mp135/c.c")), and never again. Its job is to make the external DDR
memory of the MP135 usable. v7 had nothing like it, since a PDP-11's
core was ready when the machine was switched on.

The boot ROM of the MP135 brings up only the chip's internal SYSRAM, 128
KB, and loads the kernel into it. The 512 MB of DDR3 on the board are
dead until a memory controller and its physical interface ("PHY")
have been clocked, configured, and trained to the particular chips;
this is normally the work of a first-stage boot loader, and here the
kernel is the first stage. The page tables, the core, and all the
processes are in DDR (#f("mp135conf")), so the work must be done before
anything else touches it; `machine_init` calls `ddrinit` immediately
after the console is set up, before it clears `.ddrbss` and builds the
page tables. Doing it later, in a user program, was considered and
rejected: the kernel, its page tables, and the first processes would
then all have to fit in SYSRAM, and they do not.

This is also the one place where the kernel changes the chip's clocks.
Elsewhere they are taken as the ROM left them, but the DDR needs a
clock of a particular frequency which the ROM does not provide.

The register values are those of the board's reference firmware, for
DDR3 at 533 MHz (DDR3-1066). Unlike the other drivers, this one names
its registers by their offsets and gives no names to the bits; the
values below are explained in the text.

#lines(1, 9)

`ddrc` is a list of pairs, register offset and value, for the memory
controller, ended by `0xFFFF`. In turn they set: the type and width of
the memory (`MSTR`, at offset 0); the mode register access, derating,
power saving, and refresh controls (`0x10`--`0x60`); the impedance
calibration (`0x180`); the timing of the interface to the PHY, the "DFI"
(`0x190`--`0x1c4`); on-die termination (`0x244`); debugging and the port
configuration (`0x300`--`0x400`); the refresh timing (`0x64`); the
timings of the DRAM itself, the `DRAMTMG` registers (`0x100`--`0x138`);
the mapping of address bits to bank, row, and column (`0x204`--`0x22c`);
`INIT0` (`0xd0`), whose value says, among other things, that the PHY
and not the controller will initialise the DRAM; and the scheduling and
quality of service of the port (`0x250`--`0x4a0`). The order is that of
the reference firmware.

#lines(10, 70)

`dphy` is the same for the PHY: its general configuration, I/O and
data lane settings (`0x8`--`0x200`), its timing (`0x18`--`0x3c`), and the
values of the four DDR3 mode registers, `MR0` to `MR3` (`0x40`--`0x4c`),
which the PHY writes into the DRAM when it initialises it.

#lines(71, 94)

`pgwait` waits for the PHY to finish a piece of work which `PIR` has
started. The PHY's general status register `PGSR` (`0xc`) reports the
end in bit 0, or a failure in one of the error bits `0x3e0`: of the
impedance calibration, of the initialisation of the DRAM, or of the
training below. Either ends the wait (100, 101). A failure leaves the
memory unusable, and the kernel cannot run without it, so the status
is printed and the system stops with a panic (102--105). The status is
printed first because `panic` (#f("prf.c")) calls `update`, which the
buffer cache, not yet set up, might keep from returning.

#lines(95, 107)

First the clock. The external 24 MHz crystal oscillator, HSE, is
switched on and waited for (114--116). PLL2 is stopped and waited for
(117--119), given HSE as its reference (120), and configured: the
reference is divided by 3 and multiplied by 66 plus a fraction of
5120/8192, which gives 533 MHz, and its R output, which clocks the
DDR, divides that by 1 (121--124). The outputs and the PLL are then
enabled, and the PLL waited for until it is locked.

#lines(108, 129)

If a previous low power mode left the DDR pads in retention (bit 12 of
the power controller's `PWR_CR3`), the PHY could not drive the memory;
retention is turned off (130--133).

DDR is guarded by the TrustZone address space controller, `TZC`, at
`0x5c006000`, which filters every access by its address and by the
security state of the bus master. Its clock, and that of the memory
encryption unit beside it, are enabled (134--136); then, with its
filter disabled, region 0, which covers the whole of DDR, is opened to
reading and writing by every master (137--140). The SD card's DMA
controller is one of the masters which must reach it.

#lines(130, 141)

The controller is now started up, following the sequence in the
reference firmware. Through `DDRITFCR`, the RCC's register for the DDR
interface, automatic clock gating is turned off for the duration (142);
all the resets of the controller and PHY are asserted (143); their
clocks are enabled (144); and the resets of the PHY and of the
controller's register interface are released (145, 146). The loop
(147) waits for the logic to settle. Its body reads a register, which
the compiler must do, since an empty delay loop is removed by an
optimising compiler, as happened in this file at one time.

#lines(142, 148)

The controller is told not to consider the PHY ready (`DFIMISC`,
149), and is programmed from `ddrc`. The remaining resets, of the
controller's core, its AXI port, and the PHY's register interface, are
released (152), and the PHY is programmed from `dphy`. The PHY
performs some initialisation of its own on leaving reset; its general
status register `PGSR` (`0xc`) reports the end of it in bit 0, and that
is awaited (155).

#lines(149, 157)

Writing `0x1007f` to the PHY's initialisation register `PIR` (158)
asks it to reset and lock its DLLs, calibrate the output impedance,
reset the memory and run its initialisation sequence, and to report
completion to the controller only when all of this is done (bit 16). After a short delay, which
lets the previous completion flag drop, `pgwait` (161) waits for the
work to be done, or stops the system if it has failed.

The controller is then told that the PHY is ready. `DFIMISC` is one
of the controller's "quasi-dynamic" registers, which may be changed
only between a clear and a set of `sw_done` in `SWCTL` (`0x320`); the
controller acknowledges in `SWSTAT` (`0x324`). Once the change is
acknowledged, the controller brings the memory to normal operation,
which `STAT` (`0x4`) reports as mode 1 (167).

#lines(158, 169)

Finally the PHY is trained. It must learn when, relative to its own
clock, the strobe which accompanies data read from the memory is valid
("DQS gate training"); without this, reads do not work. During the
training the controller must not issue refresh commands, so, by the
same handshake, automatic refresh is turned off (172) and the
controller again told that the PHY is not ready. `PIR` is set to
`0x81` (176), which runs the training, and its completion is awaited
by `pgwait` (179), as before. Refresh is turned back on and the PHY declared ready
(180--185).

The controller's AXI port, through which the processor and the DMA
controllers reach memory, is enabled (187), and clock gating is
restored (188). DDR may now be used.

#lines(170, 189)

= User Space

#source("/usr/src/libc/csu/crt0.s")

Every C program begins here. `crt0.o` is linked first, ahead of the
program's own objects and the library, and its `_start` is the entry
point which the linker writes into the ELF header and `exece`
(#f("sys1.c")) loads into the saved `pc`. The routine has three jobs: to
find the arguments and the environment which `exece` left on the stack,
to call `main` with them, and to pass the value which `main` returns to
`exit`. It also holds the definitions of the two variables which the
library shares with every program, `environ` and `errno`.

The file is a rewrite of v7's PDP-11 `crt0.s`. Even the names have
changed. The PDP-11 C compiler
prefixed an underscore to every external name, so that v7's `_main`,
`_exit`, and `_environ` were C's `main`, `exit`, and `environ`, and the
entry point, being no C name, was `start`. The ARM compiler adds no
prefix, so the names lose their underscores, and the entry point is
called `_start` because that is the symbol which the GNU linker takes for
the entry by default.

On entry the stack pointer addresses the block that `exece` built: the
argument count, the argument pointers and a zero, the environment
pointers and a zero, and the strings. `argc` (3) is loaded into `r0`,
`argv` (4), the address of the word above it, into `r1`, and the
environment pointer (5, 6), `argc` + 1 words above `argv`, into `r2`.
This is the ARM procedure call standard: the first four arguments of a
call travel in `r0` to `r3`, so `main(argc, argv, envp)` finds its three
arguments ready. The environment pointer is also stored in `environ`
(7, 8), where the `exec` stubs `execl` and `execv` (and through them
`execvp`, #f("gen/execvp.c")), and `getenv`, find it.

v7 had to work harder. Its C passed arguments on the stack, so the
routine made room for two extra words below `argc` and copied in `argc`,
`argv`, and the environment pointer, in the order in which `main`
expected to find them. And it found the environment by searching
`argv` for its terminating zero, then compared the address so reached
with that of the first string: if the two met, the stack had no
environment list at all, and `environ` was made to point at the final zero instead.
The port's `exece` always supplies both lists, and the address is
computed directly. Two more PDP-11 instructions are gone. `setd` put
the floating point unit into double precision mode; here there is no
floating point hardware in use, since everything is compiled for
software floating point. `clr -2(r0)` cleared the word just below the
first string, which v7's `exece` had already set to zero; the port's
start-up does not touch the block at all.

The stack pointer is not adjusted before the call. The standard
requires it to be a multiple of 8 at every call, and `exece` rounds it
so (#f("sys1.c")).

`main`'s return value is left in `r0`, which is where `exit` (10) wants
its argument; v7 had to move it onto the stack. `exit` flushes the
standard I/O buffers and calls `_exit`, which does not return. As in
v7, the call of `exit` is followed by a bare `exit` system call (11,
12), in case `exit` should come back: the call number 1 is put in `r7`
and `svc` traps, as in `cerror` (#f("libc/syscall.s")).

#lines(1, 12)

`.comm` reserves a word of `bss` under each name. `environ` was in v7's
`crt0.s` too, as a two byte word in `.bss`. `errno` was not: v7 declared
it in `cerror.s`, the routine which sets it. In the port it moved here
when the start-up was briefly written partly in C, with both variables
defined in that C file, and it stayed when the start-up became
assembler again. Since every program links `crt0.o`, this is the one
definition of `errno`; the C files of the library declare it `extern`.
That matters: when `perror.c` also defined `errno`, the linker resolved
the common symbol by pulling `perror.o`, and `sys_errlist` with it, into
every program which made a system call.

v7's file ended by reserving two bytes at the start of `.data`. In a
program with separate instruction and data spaces, data location 0
would otherwise have held a variable, whose address would then compare
equal to a null pointer. The port's programs are linked at `0x10`, with
the signal trampoline at 8 (#f("seg.h")), so no object of the program can
lie at address 0, and the padding is gone.

#lines(13, 14)
#source("/usr/src/libc/syscall.s")

This short routine is where every system call made by a C program
enters the kernel. Each library stub, such as `read` in
#f("sys/read.s"), loads its call number into `ip` and branches here;
`cerror` makes the call and turns the kernel's reply into the C
convention, a result or -1 with the error number in `errno`. Only
`fork` makes its call itself, since the kernel returns to its parent
and its child at different places (#f("sys1.c")).

The file corresponds to nothing in v7 of the same name and content.
v7's `syscall.s`, a compatibility routine of its library, was a
routine `syscall(n, r0, r1, a1, ...)` which built a `sys` instruction
for call `n` at run time; the port's version of it, `syscall3`, was used
by nothing and has been dropped. What this file does replace is v7's
`cerror.s`, together with the `sys` instruction which each v7 stub
contained. The name `cerror` is v7's; its job has grown.

On the PDP-11 a system call was the instruction `sys n`, a trap whose
low bits held the call number. Arguments came partly in `r0` and partly
in the words following the instruction, which the kernel fetched from
user space and stepped over (#f("sysent.c")). The kernel reported failure
by setting the carry bit in the saved processor status, with the error
number in `r0`. Each stub therefore tested the carry with `bec`
(branch if carry clear) after the trap and, on an error, jumped to
`cerror`, which stored `r0` in `errno`, loaded -1, unwound the stub's
`r5` frame, and returned to the stub's caller.

The ARM has `svc`, which takes an exception to the kernel's `svc_entry`
(#f("low.s")); there the user registers and status are saved, and `trap`
(#f("sysent.c")) is called with a pointer to them. The 24-bit immediate
field of `svc` is ignored. The call number is taken from `r7`, the
convention of ARM Linux, and the arguments from `r0` upwards. These are
exactly the registers in which the ARM procedure call standard passes a
C function's first four arguments, so by the time a stub is entered the
arguments are already where the kernel wants them, and the stub need
only supply the number. No call of this system has more than four
arguments.

The stub cannot put the number in `r7` itself: `r7` is one of the
registers (`r4` to `r11`) which a called function must preserve. It
uses `ip` (`r12`), which the standard leaves free for any routine to
destroy, and branches with `b`, not `bl`, so that the link register
still holds the return address in the stub's caller. `cerror` saves the
caller's `r7` on the stack (3), moves the number into it (4), traps (5),
and restores it (6).

Note that `ip` is also the register which the linker may use in a
veneer, a few instructions it inserts when a branch cannot reach its
target. An ARM branch reaches 32 MB either way, and a program here is
less than 1 MB, so no veneer is ever placed between a stub and `cerror`.

Note too that the push of one word leaves the stack pointer misaligned
by 4 while the call is in progress. Nothing is called meanwhile; and if
a signal is delivered on the way back to user mode, `sendsig`
(#f("machdep.c")) rounds the handler's stack down to a multiple of 8.

#lines(1, 6)

`trap` reports failure as v7's kernel did, by setting the carry bit in
the saved status, which `svc_entry` restores to the `CPSR` on the way
back, with the error number in `r0`. A successful call clears the carry
and returns its result in `r0`, with a second value in `r1`. Every
other register comes back as it was. If the carry is clear, `r0` is
returned to the caller unchanged (7), with `bxcc`: a return through the
link register, executed only if the carry is clear, the ARM's form of
v7's `bec`. Otherwise `r0` is stored in `errno` (8, 9) and -1 returned
(10, 11); `mvn r0, #0` loads the complement of zero, which is -1.

Neither the stores nor the return disturb the flags, so the carry
reaches the caller of `cerror`. Stubs whose calls return two values, or
store results through a pointer, such as `pipe`, `wait`, and `sbrk`,
call `cerror` with `bl` instead, and test the carry themselves on its
return. Since the error is not in the value, a call may succeed with any
result, an offset from `lseek` beyond 2 GB or a `time` after January
2038 among them.

#lines(7, 11)
#source("/usr/src/libc/sys/read.s")

`read` stands for the fifty or so stubs in the library's `sys`
directory, one file per system call, as in v7. Most are just these
three instructions with a different number: the number of the call in
the table `sysent` (#f("sysent.c")), here 3, is loaded into `ip`, and
`cerror` (#f("libc/syscall.s")) does the rest. The three arguments of
`read(fd, buf, count)` arrive in `r0`, `r1`, and `r2`, which is where
`trap` will look for them, and they are not touched. Because the stub
branches rather than calls, `cerror` returns straight to the caller of
`read`.

v7's `read.s` ran to two dozen lines, and the difference is instructive.
The file descriptor went in `r0`, but the buffer address and the count
had to be words following a `sys` instruction. Since they differ from
call to call, and the program text is read-only and may be shared, the
stub could not write them after an instruction in its own text. It kept
a template, `sys .read` followed by two empty words, in its data
segment, stored the arguments into it, and executed it with `sys 0`,
the indirect system call, whose one inline word gave the address of
the instruction to be performed. It then tested the carry bit and
either jumped to `cerror` or popped its frame pointer and returned.
None of this has a counterpart here: the arguments need no
rearrangement, and the error test is common to every stub.

The comment explaining the call's conventions, the definition of
`.read` as 3, and the underscore of the C name (#f("csu/crt0.s")) have
gone. `.globl cerror` is v7's line; the GNU assembler would in any case
treat an undefined name as external.

#lines(1, 5)
#source("/usr/src/libc/sys/signal.s")

`signal(n, func)` sets the action to be taken on signal `n`: 0 for the
default, 1 to ignore the signal, or the address of a function to be
called. It returns the previous action. In the port it is an ordinary
stub, call 48, identical in form to `read` (#f("sys/read.s")). The
kernel's `ssig` (#f("sys4.c")) checks the signal number, rejecting 0,
anything not below `NSIG`, and `SIGKIL`, and exchanges `func` with
`u.u_signal[n]`.

v7's `signal.s` ran to nearly ninety lines, because on the PDP-11 a C function
could not be the target of a signal directly. When a signal was caught
v7's `sendsig` pushed the processor status and the program counter onto
the user stack and started the process at the handler's address, as an
interrupt would; the code there had to preserve every register and end
with `rtt`, the instruction which pops both words back. A C function
was free to change `r0`, `r1`, and the condition codes, and ended with
`rts`. So the library
interposed a vector of its own. For each signal there was an entry in
`tvect`, a `jsr r0` to common code which saved `r0` to `r4`, computed the
signal number from the address of the entry, called the user's function
through the table `dvect` with the number as its argument, restored the
registers, and executed `rtt`. `signal` stored the user's function in
`dvect[n]` and gave the kernel the address of `tvect`'s entry for `n`
instead, unless the action was 0 or odd. Because the kernel's previous
value was then the address of a `tvect` entry, `signal` returned the
old `dvect[n]` instead, unless the kernel's value was odd, meaning
ignored. It also checked `n` against `NSIG` itself before indexing its
tables, and failed with `EINVAL` (22) if the number was out of range.

All of that work has moved into the kernel. The ARM `sendsig`
(#f("machdep.c")) saves the whole register frame, seventeen words
including the status register, on the user stack, then enters the
handler as an ordinary C call: `r0` holds the signal number, the stack
pointer lies below the frame, and the link register holds the address of
a two-instruction trampoline at user address 8, `mov r7, #63; svc #0`
(#f("seg.h")). When the handler returns, the trampoline makes system call
63, `sigreturn`, which reloads the frame and resumes the interrupted
program. The ARM has no user-mode instruction which, like `rtt`, reloads the
program counter and the status register together, and the handler, being C, may freely change `r0` to `r3`, `ip`, and
the condition flags; a library routine could not have done the job
even if it had wished to. The handler is thus a real C function of one
argument, which is why the handlers in `init` (#f("cmd/init.c")) and
elsewhere now take an `int`, and why `signal.h` declares
`void (*signal(int sig, void (*func)(int sig)))(int sig)`.

Since the kernel holds the user's own function, the value it returns
is the previous action as the user set it, and no translation is
needed. The one-level semantics noted in v7's deleted comment are
unchanged: when a signal other than `SIGINS` or `SIGTRC` is caught,
`psig` (#f("sig.c")) resets the action to the default before calling
`sendsig`, so a handler which wishes to catch the next one must call
`signal` again.

Note that the convention that an odd action means "ignore" survives
only because no handler can have an odd address. On the PDP-11
instructions were at even addresses. On the ARM an odd function address
denotes Thumb code; every program here is compiled with `-marm`, so
every function lies on a word boundary.

#lines(1, 4)
#source("/usr/src/cmd/init.c")

`init` is process 1. `main` (#f("main.c")) makes it with `newproc`,
copies into it the few instructions of `icode` (#f("machdep.c")), and
lets it go to user mode, where `icode` executes `/etc/init`. From then on
`init` is the ancestor of every other process. It never exits. It
starts a shell on the console for the single user; when that shell
ends it runs the command file `/etc/rc` (#f("rc")); and then, for each
terminal enabled in `/etc/ttys` (#f("ttys")), it forks a process which
opens the terminal and executes `getty` (#f("cmd/getty.c")). Each time
one of these processes dies, whether `getty` gave up, or `login`
(#f("cmd/login.c")) failed, or the user's shell finished, `init` notes the
logout in the accounting files and starts a fresh `getty` on the same
line.

`init` also inherits every orphan. When a process exits, `exit`
(#f("sys1.c")) makes process 1 the parent of its children, so `init`'s
`wait` collects them too; most of its loops simply discard the ones it
does not recognise.

Two signals steer it. A hangup, `kill -1 1` from the super-user,
makes it kill everything and return to single-user mode; an interrupt,
`kill -2 1`, makes it read `/etc/ttys` again, so that terminals can be
enabled and disabled without a reboot.

The file is v7's with C99 declarations. `stdio.h` (5) is included,
although `init` uses no standard I/O, because the port's `stdio.h`
(#f("stdio.h")) carries the prototypes of the library's system call
stubs, `fork`, `execl`, `alarm`, and the rest, and C99 does not allow a
function to be called without a declaration. For the same reason the
functions of the file are declared before use (38--40); v7 relied on
their being implicitly `int`. Elsewhere `register i` has become
`register int i`, since C99 has no implicit `int`.

`ALL` and `EVER` (8, 9) supply the control part of a `for` statement,
so that loops may be written `for(ALL)` and `for(EVER)`. `itab` holds one entry per
active terminal: the line name, the `getty` table character, and the
process id of the process serving it, 0 if none.

#lines(1, 41)

`main` is the outer loop: kill everything, run a single-user shell, run
`/etc/rc`, read `/etc/ttys` and start the `getty`s, then wait for
children until `wait` fails. `wait` fails only when `init` has no
children at all, which happens when every `getty` has been killed;
`multiple` then returns, and the cycle starts again from the shutdown.

The `setjmp` (46) marks the point to which `reset` (311) returns when a
hangup arrives. `reset` was declared locally in v7 (deleted), as a
function returning `int`; it is now declared at 39 as a `void` function
of the signal number, the form which `signal` requires (#f("sys/signal.s")).

`merge` is called with an argument (52) because it doubles as the
handler for `SIGINT`, and a handler receives the signal number; v7
called it with none.

#lines(42, 55)

`shutdown` clears the table, killing any process it names, and then
kills every other process. `kill(-1, SIGKILL)` (69) from the super-user
sends the signal to every process but 0 and 1 (`kill`, #f("sys4.c")).
`init` then waits for all its children. Should some child fail to die
(a process sleeping in the kernel at a priority below `PZERO` does not
see signals), the alarm set at 67 fires after a minute, `reset` jumps
back to the `setjmp`, and the shutdown begins again. Finally the file
descriptors are closed, so that the next stage starts clean.

#lines(56, 76)

`single` forks a shell on the console and waits for it to finish. The
child opens `/dev/console` for reading and writing; it gets descriptor 0,
since all are closed, and the two `dup`s give 1 and 2. As this is the
child's first terminal, `ttyopen` (#f("tty.c")) makes it the leader of a
process group belonging to the console, so that the interrupt and quit
characters typed there reach the shell and its children. `init` itself
never opens a terminal; its process group is 0, and no character typed
on any terminal can signal it.

The shell is called with the name `-` (94). A name beginning with `-`
tells the shell (#f("sh/main.c")) that it is a login shell, so it reads
`.profile` in its current directory, here the root. The super-user is
not asked for a password, since whoever holds the console holds the
machine. When this shell ends, normally by an end-of-file typed on the
console, the system goes multi-user. The commented-out `alarm` (85--87)
is v7's.

#lines(77, 99)

`runcom` runs `/etc/rc` with the shell and waits for it. The child's
standard input, output, and error are the root directory, opened for
reading (108), so that the commands of `/etc/rc` have no terminal and
must name `/dev/console` explicitly if they wish to be heard, as
#f("rc") does.

#lines(100, 116)

`multiple` is where `init` spends nearly all its time. It waits for any
child to die; if the child served a terminal, the logout is recorded
by `rmut` and a new `getty` is forked by `dfork`. An entry with `pid` -1
is one for which `fork` failed in `dfork` (275); it is retried whenever
any child dies.

#lines(117, 134)

`term` ends the service of one table entry.

#lines(135, 146)

`rline` reads one line of `/etc/ttys` into the structure `line`. A line
is a flag character, `1` if the terminal is to be served and `0` if not,
the character naming the `getty` table, and the terminal's name of up
to seven characters, the rest being discarded. A line whose terminal
cannot be both read and written (174), or which is malformed, is treated
as disabled. `rline` returns 0 only at the end of the file.

#lines(147, 181)

`maktty` builds the terminal's path name in `tty`. `get` reads one
character, mapping the newline to 0 and end of file to -1.

Note that `b` (200) is a `char`. On the PDP-11 a byte with its top bit
set became negative when returned, and would end the file early; on
the ARM `char` is unsigned and the byte is returned as it is. The text of
`/etc/ttys` is ASCII, so the difference is never seen.

#lines(182, 207)

`merge` brings `itab` into line with `/etc/ttys`. It first empties
`/etc/utmp` (216), the list of users logged in, and re-arms itself as
the handler for `SIGINT`: the kernel resets a caught signal to its
default when it is delivered (`psig`, #f("sig.c")), and a second
interrupt would otherwise kill `init`, and with it the system.

The table is then rearranged in place. `q` marks the end of the entries
already matched. For each enabled line of the file, the table is
searched from the start for an entry with the same name, an empty entry
matching anything (226). The entry found, if it lies at or beyond `q`,
is exchanged with the one at `q`, the process id moving with its line
and `q`'s old line moving to the slot vacated, and `q` advances. An
entry found below `q` is a duplicate line in the file and is ignored.
When the file is exhausted, the entries from `q` onwards are for
terminals no longer enabled, and `term` kills their processes. Any
entry which has a line but no process, a newly enabled terminal, is
given a `getty`.

#lines(208, 253)

`dfork` forks the process which will serve a terminal. In the child,
the signals which `init` catches are reset to the default (they would
be reset by `exec` in any case, but `chown` and `open` come first). The
terminal is given back to the super-user, with mode 0622, writable by
all so that `write` and `mail` can reach it; `login` will give it to the
user. Opening it (267) makes the child the leader of the terminal's
process group, as in `single`. In v7 the open of a dial-up
line slept until the modem reported a call, so that this is where an
idle line's process waited; the UART drivers of the port
(#f("pl011.c")) have no modem control, and the open returns at once.

`getty` is called with the name `-` and one argument, the table
character from `/etc/ttys`, which is borrowed from the `tty` buffer
(270, 271).

#lines(254, 276)

`rmut` records that the user of a line has gone. In `/etc/utmp` the
entry for the line, if any, has its name cleared and its time set to
now. To `/usr/adm/wtmp`, the history of logins, a record with the line
name and an empty user name is appended; `login` writes the matching
record with the user's name. Either file is skipped if it cannot be
opened, so the history is kept only if `/usr/adm/wtmp` has been
created.

The `utmp` structure is 16 bytes on both machines: two arrays of 8
characters and a `long` of 4 bytes, so the files have the same format as
v7's.

#lines(277, 309)

`reset` abandons whatever `init` was doing and returns to `main`.
Note what happens on the ARM. `sendsig` (#f("machdep.c")) has placed the
interrupted registers on the user stack and called `reset` with the link
register pointing at the trampoline. `longjmp` (#f("gen/setjmp.s"))
restores the registers saved by `setjmp`, including the stack pointer,
so the trampoline is never reached and `sigreturn` never called; the
saved frame is simply left behind in the part of the stack being
discarded. The kernel keeps nothing on behalf of the handler, so
nothing needs to be undone.

#lines(310, 316)
#source("/usr/src/cmd/getty.c")

`getty` is the program which `init` (#f("cmd/init.c")) runs on every
enabled terminal. It arrives with the terminal open as descriptors 0, 1,
and 2, and one argument, the character which `/etc/ttys` (#f("ttys"))
gave for the line. Its task is to make the terminal usable: to choose a
speed and a set of modes, print the `login:` prompt, read the user's
name, and execute `login` (#f("cmd/login.c")) with it. On a dial-up line
the speed of the caller's terminal was not known in advance, and
`getty` found it by trial: if what arrived could not be a name, it
switched to the next speed of a cycle and prompted again.

The `#` on line 1 is a relic of earlier compilers, which ran the
preprocessor only on a file whose first character was `#`.

The declarations at 8--11 are new. C99 requires a declaration of every
function before it is called, and v7 had none here. `getty` cannot take
them from `stdio.h` (#f("stdio.h")), as the other commands do, because it
defines a `puts` of its own (209) which differs from the library's, so
it declares the system calls it uses itself. `stty` is declared by
`sgtty.h`.

`tchars` (16) sets the special characters: interrupt (DEL), quit
(FS, control-backslash), start and stop output (DC1 and DC3, control-Q
and control-S), end of file (EOT, control-D), and the additional
delimiter, 0377, meaning none. On the PDP-11 `'\377'` in a `char` was -1,
on the ARM it is 255; in either case it can never equal an input
character, since `ttyinput` (#f("tty.c")) strips the top bit from every
character unless the terminal is in raw mode.

#lines(1, 17)

Each entry of `itab` describes one attempt: its own name, the name of
the entry to try next, the modes for reading the name and the modes to
set once the name has been read, the input and output speeds, and the
prompt. The initial modes always include `RAW`, so that every
character comes through at once, without echo, erase processing, or
interpretation of the interrupt character, and `ANYP`, so that either
parity is accepted. The final modes add `ECHO` and, for most terminals,
`CRMOD` and the delays (`NL1`, `CR1`, and so on) which slow mechanical
terminals needed after a newline or carriage return. The prompts begin
with escape sequences for particular terminals, now meaningless.

The first table is a cycle of four entries, named `'0'`, 1, 2, and 3:
the numbers are not characters, so no line of `/etc/ttys` can select
entries 1 to 3 directly. They are reached only by stepping from `'0'`.

Every entry is now enclosed in braces. C allows the members of the
elements of an array of structures to be listed without them, but the
port compiles with `-Wall`, whose `-Wmissing-braces` objects, and
`-Werror`.

#lines(18, 49)

The remaining tables. Most name themselves as successor, so that a
line given one of them never changes speed. The console of the port is
the entry `14console` in `/etc/ttys`: enabled, with table `'4'`, the
"Console Decwriter", whose modes ask for carriage return mapping and
tab expansion on output. The speeds of any table are irrelevant here.
`tty.c` records them, but the UART drivers (#f("pl011.c")) never program
the speed, which is fixed when the board starts, just as the KL11
console of the PDP-11 had a speed set by jumpers.

#lines(50, 103)

`name` (107) receives the name which `getname` reads, and `crmod`,
`upper`, and `lower` record what it learns about the terminal on the
way.

v7 had here `partab`, a table of parity bits for the ASCII characters,
which `putchr` used to send every character with even parity, since in
raw mode the kernel adds none. The UART drivers of the port send eight
data bits without parity (#f("pl011.c")), and a terminal emulator takes
the eighth bit as part of the character, so the parity bit garbled the
prompt: the `g` of `login:`, which has an odd number of one bits,
arrived as `ç`. The table and its use are removed.

#lines(104, 112)

`main` chooses the first table from its argument; with none it uses
`'0'`. For a line of type `'3'`, a Bell 212 modem which can answer at
300 or 1200 bits per second, the current speed decides between the two
cycles (124--130).

#lines(113, 131)

The loop. The modes and speeds of the chosen table are set with
`TIOCSETP`, the special characters with `TIOCSETC`, and the prompt is
written. If `getname` returns 1, a name has been read: the erase and
kill characters are set to v7's `#` and `@`, the final modes adjusted
by what `getname` learnt about the terminal, and `login` executed with
the name as its argument. The modes are set by `stty`, which is `ioctl`
with `TIOCSETP`. Otherwise the next table is tried.

Note that the list of arguments to `execl` (156) ends with an `int` 0
where a null pointer is meant. The function is variadic, so the
compiler does not convert it; the call works because an `int` and a
pointer are the same size, two bytes on the PDP-11 and four on the ARM.

#lines(132, 161)

`getname` reads the name one character at a time, with the parity bit
removed (177). A NUL means that the character was not received
properly, which is what a terminal sending at a different speed, or a
break, produces; `getname` returns 0, and `main` moves to the next
table. End of file or EOT ends `getty`, and `init` starts another.

Since the terminal is in raw mode, `getname` echoes each character
itself (183), and does its own erasing (`#`) and killing (`@`). It also
learns about the terminal: if the name was ended by a carriage return,
the terminal needs `CRMOD`; if it contains upper case letters, they are
converted to lower case, and unless lower case letters appeared as well
the terminal is assumed to have no lower case, so `LCASE` will be set.
A space becomes an underscore, since `login` reads the name as a single
word.

The test of `np` (181) stops the loop when 15 characters have been
stored, leaving room in `name` for the null which `*np = 0` (202)
stores. v7 stopped at 16, and the null went one byte beyond the end of
`name`.

#lines(162, 206)

`puts` writes a string without the newline which the library's
`puts` adds, and `putchr` writes a single character, now as it is.

#lines(207, 224)
#source("/usr/src/cmd/login.c")

`login` turns the process which `init` (#f("cmd/init.c")) forked for a
terminal into the user's session. It is entered from `getty`
(#f("cmd/getty.c")) with the name typed at the `login:` prompt, or from
the shell, where `login` is a built-in command which executes this
program in place of the shell. It checks the password, records the
login, changes the ownership of the terminal and the identity of the
process to those of the user, and finally executes the user's shell. No
new process is made at any stage: the process which `init` forked
becomes in turn `getty`, `login`, and the shell, keeps its process id,
its open terminal, and its process group throughout, and only when the
shell exits does `init`'s `wait` return.

Coming from `getty`, `login` runs as the super-user, since `init` and
everything it forks are root's. That is what allows it to change the
process's identity at all (`setuid`, #f("sys4.c")). Run from an
ordinary user's shell, it is the super-user too, since `/bin/login` is
set-user-id root, as in v7 (#f("rootfs.proto")).

`nouser` (15) is the entry used for a name which is not in the
password file. Its encrypted password "nope" is not one which `crypt`
can produce, so no password matches it, and an intruder cannot tell a
wrong name from a wrong password. v7 initialized only its first two
members; the remaining seven are now given explicitly, as zeros. The
reason is the warning flags: `-Wextra` includes
`-Wmissing-field-initializers`, which, with `-Werror`, rejects a
structure initializer shorter than the structure. The values are those
C supplied in any case.

v7 declared the library functions it used (`getpwnam`, `crypt`,
`getpass`, and so on) at the head of the file (deleted). In the port they are
declared, with prototypes, in `pwd.h` and `stdio.h` (#f("stdio.h")), and
the old declarations would conflict with them. `showmotd` is declared
(23) because it is called before its definition. `environ` (24) is
defined in #f("csu/crt0.s").

#lines(1, 25)

The process allows itself a minute (33): if no one has logged in by
then, `SIGALRM`, whose default action is to exit, ends it, and `init`
starts a new `getty`. Interrupt and quit are ignored, so that the
typing of either cannot be used to escape from `login` with the
privileges of the super-user.

The three calls of `nice` (36--38) restore the normal scheduling
priority, whatever the process inherited. `nice(-100)` lowers `p_nice`
to its minimum of 0, a change only the super-user may make, and
`nice(20)` raises it to `NZERO` (#f("param.h")), the default. `nice(0)`
changes nothing.

The erase and kill characters are set to `#` and `@` (39--42), and any
descriptors beyond the standard three are closed. `ttyname` finds the
terminal's name by searching `/dev` for the device which descriptor 0
is open on.

#lines(26, 48)

The name is read here unless it came as an argument; it is the place to
which a failed attempt returns. The name is cut to the 8 characters of
`ut_name` (#f("cmd/init.c")), and a space becomes an underscore, as in
`getty`.

#lines(49, 66)

The password file is searched with `getpwnam`, which reads it with the
routines of #f("stdio/getpwent.c"). If the user has a password, one is
read without echo by `getpass` (#f("stdio/getpass.c")) and encrypted with
`crypt` (#f("gen/crypt.c")), using as salt the first two characters of the
stored encryption. The result is compared with the stored encryption;
the password itself is never stored. Finally the process moves to the
user's home directory.

#lines(67, 81)

The login is recorded. `ttyslot` returns the number of the terminal's
line in `/etc/ttys`, counting from 1, and that numbers the user's
record in `/etc/utmp`; `init`'s `rmut` will clear it at logout. The
same record is appended to `/usr/adm/wtmp`. The line name stored is
the terminal's name with `/dev/` removed (86).

#lines(82, 94)

The terminal is given to the user (95), and then the group and the user
id are changed, in that order, since after `setuid` the process would no
longer be allowed `setgid`. From here on the process is the user's.

The environment is replaced by `envinit` (100): `HOME`, completed from
the password entry (101), and `PATH`. `minusnam` becomes `-` followed by
the last component of the shell's name, so that `/bin/sh` is called
`-sh` and reads the user's `.profile` (#f("sh/main.c")). The file mode
creation mask is set to 02, so that new files are not writable by the
other members of the group.

The message of the day is shown, then a note if the user's mailbox is
not empty, and the shell is executed with `execlp` (#f("gen/execvp.c")),
interrupt and quit restored to the default first. If it cannot be
executed, the process exits, and `init` starts a new `getty`. As in
`getty`, the `0` ending the argument list of `execlp` (119) is an `int`
standing for a null pointer.

#lines(95, 122)

`showmotd` copies `/etc/motd` to the terminal, and an interrupt stops
the copy. The interrupt handler `catch` is now `static`, since nothing
outside this file uses it, and the port compiles with
`-Wmissing-prototypes`, which asks for a prototype in a header for every
function that is not. It takes the signal number, as every handler now
does (#f("sys/signal.s")), and ignores it.

#lines(123, 146)
#source("/usr/src/libc/stdio/getpass.c")

`getpass` prints a prompt and reads a password of up to eight
characters with echo turned off. `login` (#f("cmd/login.c")) is its chief
user; `su`, `passwd`, `newgrp`, and `crypt` are others.

It reads from `/dev/tty`, the process's controlling terminal, even if
the standard input has been redirected; the special file is served by
#f("sys.c"), which passes the request to the terminal recorded in
`u.u_ttyp` when the process group was formed (`ttyopen`, #f("tty.c")). If
the process has no terminal the open fails and the standard input is
used instead. The stream is made unbuffered (19) so that nothing beyond
the password's newline is consumed. Interrupts are ignored while echo
is off, since a program killed at that moment would leave the terminal
silent.

The echo is turned off by clearing `ECHO` in the terminal's modes with
`gtty` and `stty`, and the old modes are put back afterwards. The prompt
and the newline which the user's return did not echo are written on
the standard error. Only eight characters are kept, since `crypt`
(#f("gen/crypt.c")) uses no more; the rest of the line is read and
discarded. The password is returned in a static buffer, which the next
call overwrites.

v7 declared `signal` locally (deleted) as a function returning a
pointer to a function returning `int`, and `sig` to match. `signal.h`
now declares `signal` with a prototype, and handlers are functions of
one `int` returning nothing (#f("sys/signal.s")), so `sig` (14) has that
type and the local declaration of `signal` would conflict with the
header's.

#lines(1, 38)
#source("/usr/src/libc/stdio/getpwent.c")

These routines read the password file, `/etc/passwd` (#f("passwd")), one
entry at a time. `getpwent` returns the next entry as a `struct passwd`
(declared in `pwd.h`); `setpwent` rewinds the file, opening it if
necessary; `endpwent` closes it. `getpwnam` and `getpwuid`, in files of
their own, call `setpwent`, then `getpwent` until they find the name
or user id wanted, and then `endpwent`. `login` (#f("cmd/login.c")) uses `getpwnam`.

The file is v7's with prototype definitions; `setpwent` and `endpwent`,
which return no value, are now `void` where v7 left them implicitly
`int`.

#lines(1, 26)

An entry is a line of seven fields separated by colons: the name, the
encrypted password, the user and group ids, a comment field (by
convention the user's full name, `pw_gecos`), the home directory, and
the shell. A field may be empty; an empty password means that none is
asked for, and an empty shell means `/bin/sh`.

The line is read into the static buffer `line`, and the fields are
not copied: `pwskip` replaces each colon by a NUL and returns the
address of the next field, so that the members of the structure point
into `line`. The final field is cut at the newline (64, 65). The
numbers are converted with `atoi`. `pw_quota` and `pw_comment` are not
in the file at all and are set to 0 and the empty string.

Note that every call reuses the same `line` and the same `passwd`, so
the result of one call is destroyed by the next. A caller which needs
two entries at once must copy the first. And, since `fgets` reads at
most `BUFSIZ` characters, a longer line would be split and its tail
read as an entry of its own; a password file has no such lines.

#lines(27, 67)

= Reading Commands

#source("/usr/src/cmd/sh/defs.h")

The shell is an ordinary user program, `/bin/sh`, but it is the one
through which nearly everything else is run, and it occupies this and
the next two sections. Its work divides into three parts. It reads
characters and assembles them into words (#f("sh/io.c"), #f("sh/word.c"));
it parses the words into a tree of commands, built by `cmd`
(#f("sh/cmd.c")); and it walks the tree, forking, redirecting, and
executing, in `execute` (#f("sh/xec.c")). Around these lie the variables
(#f("sh/name.c")), the substitution of parameters and of command output
(#f("sh/macro.c")), the expansion of file name patterns
(#f("sh/expand.c")), and two storage allocators (#f("sh/stak.c"),
#f("sh/blok.c")). The main loop in #f("sh/main.c") prints a prompt,
calls `cmd` to read one command, hands the tree to `execute`, and throws
the tree away.

This is S. R. Bourne's shell, the shell of v7. It is written in a dialect of its own: #f("sh/mac.h")
redefines the control structures of C after Algol 68, so that `if` is
written `IF ... THEN ... FI`. The port keeps the dialect. It also keeps
the shell's habit of assigning one type to the result of another by
means of a cast, but where v7's compiler accepted any pointer to the
left of `->`, C99 demands one of the right type, and the tree code in
#f("sh/cmd.c") has gained typed pointers accordingly.

#f("sh/defs.h") is included by every source file of the shell, and
includes most of the other headers in turn. The lone `#` on the first
line of each file is a relic: early C compilers ran the preprocessor
only on a file whose first character was `#`. To C99 it is an empty
directive.

The first definitions are the codes with which the shell exits after an
error (`SIGFLG` is or-ed into the status of a command killed by a
signal), and the node types of the command tree. A node's type is in
its low four bits (`COMMSK`); the bits above qualify a fork node: print
the process id (`FPRS`), ignore interrupts (`FINT`), do not wait
(`FAMP`), and connect or close a pipe (`FPIN`, `FPOU`, `FPCL`).

#lines(1, 34)

The codes of the built-in commands, which `builtin` looks up in the
table `commands` (#f("sh/msg.c")) and `execute` switches on.

`INIO` and `OTIO` (57, 58) are the descriptors to which the shell moves
its own input and output (#f("sh/main.c")), so that they are out of the
way of the descriptors 0 to 9 which a user may redirect (`USERIO`). An
I/O node's `iofile` holds the descriptor in its low four bits
(`IOUFD`) and the kind of redirection above them.

#lines(35, 77)

In v7 this block declared, without arguments, only the functions which
returned something other than `int` (81--104); every other function,
and every system call, was declared implicitly by its first call. C99
has no implicit declarations. The port gives each of v7's declarations
a prototype and adds the rest (105--139): every function the shell
shares between its files, and the system calls it makes. The system
calls are declared here, because the shell cannot include the port's
`stdio.h`, which carries their prototypes (#f("stdio.h")): that file
defines `FILE`, `BUFSIZ`, and `EOF`, which the shell defines for
itself, differently (#f("sh/mode.h"), #f("sh/mac.h")). `gtty`, `stat`,
and `signal` are not in the list; their declarations come from
`sgtty.h`, `sys/stat.h`, and `signal.h`.

Four v7 declarations are gone. `expr`, of type `REAL`, was declared and
never defined. `execs`, `copyto`, and `staknam` are `LOCAL` (that is,
`static`) in their own files, and C99 does not allow a `static`
definition to follow a declaration with external linkage; they are
declared in their files instead.

`alloc` (80) is defined as `malloc`. The shell's own allocator
(#f("sh/blok.c")) is therefore the program's `malloc`, and the library's
(#f("gen/malloc.c")) is never loaded. `free` takes `void *`, to agree
with the library's declaration of the same name.

#lines(78, 139)

`round(a,b)` rounds the address `a` up to a multiple of `b`, a power of
two. It converts the pointer to `int` and returns an `int`, which works
because on the ARM, as on the PDP-11, the two are the same size; the
callers in #f("sh/stak.c") and #f("sh/blok.c") now cast the result back
to a pointer, as C99 requires. `assert` is defined away.

From here on most of the lines declare variables. In v7 they were
written without `extern`: each was a tentative definition in every file
that included #f("sh/defs.h"), and the loader merged the copies into a
single "common" symbol. C99 permits one definition only, and the port no
longer compiles with `-fcommon`, so the header now declares them
`extern`, and #f("sh/main.c") and #f("sh/stak.c") define them.

#lines(140, 167)

The `MSG` strings are defined in #f("sh/msg.c"); the `NAMNOD`s, the
nodes for the shell's built-in variables, in #f("sh/name.c").
`standin` (226) is the current input file, of which `input` and `eof`
name two fields.

The flags record the options set with `set` or on the command line,
together with some internal state: `ttyflg` (239) marks an interactive
shell, `forked` a shell process which is a child of the shell proper,
`waiting` a shell idle at its prompt, and `prompt` that a prompt is to
be printed.

#lines(168, 248)

`subshell` and `errshell` are the targets of the shell's two non-local
jumps, both set in #f("sh/main.c"). `brkincr` is the amount by which the
data segment is extended (#f("sh/stak.c")).

`signal.h` (257) is new. It supplies the prototype of `signal`, and
`SIG_IGN`, with which #f("sh/fault.c") now tests whether a signal was
ignored, where v7 compared the result of `signal` with 1. `fault` is
declared with the signal number it receives, so that it has the type
which `signal` expects of a handler.

#lines(249, 275)

`execbrk` (285) was a `BOOL` in v7, that is a `char`. It is set to
`-loopcnt` by `continue`, and the loops of #f("sh/xec.c") test
`execbrk<0`. A PDP-11 `char` was signed and held the negative value; an
ARM `char` is unsigned, so the test would never succeed. It is now an
`INT`.

`notfound` is declared twice (296, 313), as in v7. `end` (316) is the
address which the loader assigns to the end of the program's
uninitialised data; the shell's heap begins there.

#lines(276, 318)
#source("/usr/src/cmd/sh/mode.h")

#f("sh/mode.h") names the shell's types and lays out its data
structures, chief among them the nodes of the command tree.

`BYTESPERWORD` (7) is the unit to which the shell aligns everything it
allocates. v7 already wrote it as `sizeof(char *)`, so it is 4 on the
ARM without change, where it was 2 on the PDP-11; the stack, the heap,
and the space `word` reserves for a link (#f("sh/word.c")) all follow
it.

The type names are v7's. `BOOL` is a `char`, and the shell's `TRUE` is
`-1` (#f("sh/mac.h")); since an ARM `char` is unsigned, a `BOOL` set to
`TRUE` holds 255. Nothing compares a `BOOL` with `TRUE`, so the
difference is never seen; the one variable whose sign mattered,
`execbrk`, has become an `INT` (#f("sh/defs.h")).

`VOID` was `int` in v7, for a compiler without `void`; it is now `void`,
so that a function declared `VOID` returns nothing and the compiler can
say so. `REAL` survives, though nothing uses it.

#lines(1, 23)

Each structure gets a typedef for itself or for a pointer to it.
v7 also typedef'd `SYSTAB` here (deleted), as an array of `struct
sysnod`, before that structure was defined; C99 does not allow an array
of an incomplete type, and the line has moved below the definition
(110).

#lines(24, 46)

The "cheats" convert a pointer to an `int`, so that the shell can set
and clear a flag in its low bit (#f("sh/blok.c"), #f("sh/service.c")).
`Rcheat` is a cast, and depends only on an `int` being as wide as a
pointer, which holds on the ARM. `Lcheat` gave an lvalue, through the
member `_cheat` of the union v7 declared at this point (deleted). That
declaration declares nothing, and C99 rejects it. Its two uses violated
the aliasing rules of C99, writing a pointer through an `int` lvalue,
and have been rewritten as plain assignments with `Rcheat`; the macro
stays, unused.

The union `address` gathers the pointer types, so that `end`
(#f("sh/defs.h")) can be declared as an array of it.

#lines(47, 71)

v7 defined `struct void` here (deleted), a structure with one member,
apparently so that `void` could appear in a declaration where the
compiler had no such type. In C99 `void` is a keyword, and the line is
an error.

A heap block (`struct blk`) is a single word: a pointer to the next
block, the user's data following it (#f("sh/blok.c")).

`struct fileblk` is an input file: its descriptor, line number,
end-of-file flag, the size of a read, the next and last characters of
the buffer, a list of further strings to be read in turn (`feval`), and
a link to the input it interrupted (`fstak`). The shell's `BUFSIZ` is 64,
not the library's 512. `struct filehdr` is the same with a buffer of
one byte, used when the input is a string in memory and needs no
buffer.

A `sysnod` pairs a name with a code. `reserved` and `commands`
(#f("sh/msg.c")) are tables of these, ended by a null name.

#lines(72, 111)

The nodes of the tree. Every node begins with its `INT` type, so that a
`TREPTR` can stand for any of them until the type has been examined;
#f("sh/xec.c") then converts the pointer to the specific kind. The fork
and command nodes, like `struct trenod`, follow the type with an I/O
list, which is how `item` can attach redirections to a fork node
through `treio` (#f("sh/cmd.c")). A `comnod` is a simple command, with its
arguments and the assignments which precede it; `ifnod`, `whnod`,
`fornod`, and `swnod` are the compound commands; a `regnod` is one arm
of a `case`; a `lstnod` joins two commands with `;`, `&&`, `||`, or a
pipe; a `parnod` holds a parenthesised command; a `forknod` asks
`execute` to fork. `argnod` and `dolnod` are headers: the text of the
argument or parameter list follows in the same block.

The `...TYPE` macros give the size of each node for `getstak`.

#lines(112, 202)
#source("/usr/src/cmd/sh/mac.h")

Bourne wrote the shell, and later the debugger `adb`, in a C disguised
as Algol 68, and #f("sh/mac.h") is the disguise. Each keyword expands
to the punctuation of the C statement it replaces: `IF c THEN s FI`
becomes `if( c ){ s ;}`, `WHILE c DO s OD` becomes `while( c ){ s ;}`,
and `REP s PER c DONE` is a `do`-`while` loop. `LOOP ... POOL` is a loop
without a test, left by `break` or `return`. The brackets of each
construct are supplied by its keywords, so a body of several statements
needs no braces, and an `ELIF` chain needs no nesting. `SWITCH x IN
... ENDSW` frames a `switch`; the cases inside are written in plain C.

Note that `FI` and `OD` supply a semicolon. A statement before them may
omit its own, and the shell's sources often do (`IF x THEN y=0 FI`).

`LOCAL` is `static`, and `PROC` (for `extern`) is no longer used: the
port declares the shell's local functions `LOCAL` before their
definitions (#f("sh/cmd.c")), where v7 declared them `PROC`.

The file is v7's, unchanged.

#lines(1, 37)

`TRUE` is `-1`, all bits set, and `EOF` is 0: the shell's own end of
file is a null character, unrelated to the `EOF` of `stdio.h`.
`QUOTE` (50) is the bit the shell sets in a character to mark it quoted
(#f("sh/word.c")); the characters it reads are ASCII, and this bit is
otherwise unused. `STRIP` removes it again.

#lines(38, 60)
#source("/usr/src/cmd/sh/sym.h")

The values that `word` (#f("sh/word.c")) returns in `wdval`. An ordinary
word is 0, and a single special character is itself. A reserved word
has `SYMFLG` (0400) set, and its low bits are chosen so that `chksym`
(#f("sh/cmd.c")) can be given several acceptable symbols or-ed together,
and can tell whether `wdval` is one of them by masking. A doubled
character, such as `;;` or `&&`, is the character with `SYMREP` set.

`NLFLG` and `MTFLG` are the flags of `cmd`: a newline may end the
command, and the command may be empty. `MARK` is or-ed into a character
pushed back into `peekc`, so that a pushed-back null, which is the
shell's end of file, still reads as non-zero.

The file is v7's, unchanged.

#lines(1, 46)
#source("/usr/src/cmd/sh/ctype.h")

The shell classifies characters by two tables of its own,
`_ctype1` and `_ctype2` (#f("sh/ctype.c")), rather than by the library's
`ctype.h`. Each entry is a set of bits. The first table serves the
lexical analysis of #f("sh/word.c"): blanks (`T_SPC`), the characters
which end a word (`T_MET`, `T_DIP`, `T_EOR`, `T_EOF`), quotes, and the
characters which a backslash may escape. The second serves the
parameters of #f("sh/macro.c"): digits, the letters and underscore that
make an identifier (`T_IDC`), the special parameters such as `$#` and
`$?` (`T_SHN`), and the operators of `${...}`, such as `-` and `=`.
The `_XXX` names give the class of each individual character, for use
in the tables.

#lines(1, 68)

Each test checks first that the character does not carry the quote bit
(#f("sh/mac.h")), since a quoted character never has a special meaning;
only then is the table consulted. As the comment warns, the macros
evaluate their argument twice.

v7 subscripted the tables with `c` itself. The port masks it with
`0377`. The argument is often a `char`, and GCC warns of a subscript of
type `char` (`-Wchar-subscripts`), because a signed `char` may be
negative; the port treats every warning as an error. The mask makes the
subscript an `int`. It does not change a character's value, and the
quote test has already excluded the values above 0177, so the subscript
stays within the 128 entries of the table. The declarations of the tables have become `extern`
(69, 80); in v7 they were tentative definitions in every file.

#lines(69, 90)
#source("/usr/src/cmd/sh/ctype.c")

The two tables of character classes, laid out one row for each eight
ASCII codes. The only changes are the `=` before each initialiser (12,
61). v7's compiler still accepted the older form without it, which C99
does not.

In the first table, note that the null character is `_EOF`, the
shell's end of file, and that only space, tab, and newline separate
words; the characters `&;<>|` (`T_DIP`) and `()^` (`T_MET`) end a word
too.

#lines(1, 58)

In the second, the capitals, small letters, and underscore make
identifiers; `@` and `*` are both `T_AST`, the parameters which stand
for all the positional arguments.

#lines(59, 107)
#source("/usr/src/cmd/sh/brkincr.h")

The initial and largest amounts, in bytes, by which `locstak`
(#f("sh/stak.c")) extends the shell's data segment. The file is v7's.

#lines(1, 2)
#source("/usr/src/cmd/sh/stak.h")

The shell manages its memory itself, in two regions which share the
data segment above `end`. At the bottom is a heap (#f("sh/blok.c")),
from which `alloc` hands out blocks of any size which live until they
are freed: the variables' nodes and values, and the lists of
positional parameters. Immediately above the heap lies the
"stack" (#f("sh/stak.c")), which holds everything that lives no longer
than one command: the words as they are read, the parse tree, and the
expanded arguments. Allocation from the stack costs an addition, and
nothing on it is ever freed singly; at the top of its command loop the
shell simply resets the stack to its base (`tdystak`, #f("sh/main.c")).

Five pointers describe the stack. `stakbas` is its base and `brkend`
the current end of the data segment. Items already allocated lie
between `stakbas` and `stakbot`; the item being built runs from
`stakbot` to `staktop`. A string of unknown length, such as a word, is
built by `locstak`, which makes sure there is room, then `pushstak` for
each character, then `endstak` or `fixstak`, which ends the string and
makes it a permanent item.

The heap grows upward into the stack. When it does, `addblok` copies
the item under construction to a new place above the heap
(#f("sh/blok.c")), so that a pointer into it becomes stale. Code that
may call `alloc` in the middle of building an item, such as a variable
lookup during substitution, therefore keeps an offset from `stakbot`
(`relstak`) and converts it back afterwards (`absstak`, `setstak`), as
the first comment explains.

The declarations of the five pointers are `extern` (61--73); they are
defined in #f("sh/stak.c"). The functions have prototypes.

#lines(1, 76)
#source("/usr/src/cmd/sh/stak.c")

The procedures of the stack described in #f("sh/stak.h").

The definitions of `stakbsy`, `stakbas`, `brkend`, and `staktop`
(13, 14) are new; in v7 the header's tentative definitions served
(#f("sh/defs.h")). `stakbot` starts at `nullstr`, an empty string, so
that it is a valid pointer before `main` has set up storage.

#lines(1, 16)

`getstak` allocates an item of known size, such as a tree node. The
size is rounded up to `BYTESPERWORD`, so that the next item, and every
node, begins on a four byte boundary. Note that nothing checks that the
item fits below `brkend`. That is the business of `locstak`, below,
and, in v7, of a signal.

#lines(17, 29)

`locstak` begins an item of unknown size. If fewer than `BRKINCR`
bytes remain between `stakbot` and the end of the data segment, it
extends the segment by `brkincr` with `setbrk` (#f("sh/setbrk.c")), and
increases `brkincr` by 256, up to `BRKMAX`, so that a shell which keeps
needing room asks for it in larger pieces.

One call is not a guarantee: a long word may outgrow the space while it
is being pushed, one character at a time, and nothing tests for that.
On the PDP-11 the store beyond the end of the segment caused a memory
fault, `SIGSEGV`, which the shell catches; `fault` (#f("sh/fault.c"))
extends the segment by `brkincr` and returns. Before sending the
signal, v7's `trap` had called `backup`, which undid the side effects of
the failed instruction on the registers, so that the instruction was
executed again when the handler returned, and this time succeeded. The
shell thus grew on demand, at the cost of depending on the machine's
ability to restart an instruction after a fault.

The port gives every process the whole of its 1 MB window, mapped and
cleared by `exec` (#f("sys1.c"), #f("ureg.c")), whatever its break. A
store beyond `brkend` therefore succeeds, and no fault comes; the
segment's recorded size simply catches up at the next call of `locstak`.
This is harmless as long as the kernel leaves such memory alone. An
earlier version of `sbreak` cleared the memory between the old and the
new break, and so destroyed heap links and words which the shell had
already stored there: the shell hung on long words, or lost parts of
them. `sbreak` no longer clears anything (#f("sys1.c")).

#lines(30, 42)

`savstak` returns the current position, for a later `tdystak`.
`endstak` ends the item at `argp` with a null, makes it permanent, and
starts the next item at the following word boundary. The cast of
`round`'s result to `STKPTR` (54) is new: `round` yields an `int`, and
C99 does not convert an integer to a pointer without one.

#lines(43, 56)

`tdystak` returns the stack to the position `x`. Blocks on the chain
`stakbsy` are parts of the stack that `addblok` turned into heap blocks
(#f("sh/blok.c")); those that lie above `x` are freed. `x` may lie
below the present base, if the stack has moved since it was saved;
`max` then keeps the new base. `rmtemp` (#f("sh/error.c")) removes the
temporary files made since `x`, which it recognises because their I/O
nodes were also allocated on the stack, above `x`. The cast of `x` to
`IOPTR` (66) is new, to match the prototype.

#lines(57, 67)

`stakchk`, called from the command loop, gives back data space when
more than two increments of it lie above the stack's base. On this
system the memory stays mapped, and only the size recorded by the
kernel shrinks.

`cpystak` copies a string to a new item.

#lines(68, 80)
#source("/usr/src/cmd/sh/blok.c")

The heap. The arena is a circular list of blocks, each beginning with
one word (`struct blk`, #f("sh/mode.h")) which points to the next block;
the size of a block is the distance to its successor. Because every
block begins on a word boundary, the low bit of the pointer is free,
and `BUSY` in it marks the block as in use. The last block, `bloktop`,
is a header only, which points back to the first, at `end`, with
`BUSY` set so that it is never merged.

`busy` reads the bit through `Rcheat`, a cast of the pointer to `int`
(#f("sh/mode.h")). On the PDP-11 a pointer was a 16 bit word and on the
ARM it is a 32 bit one, but on both machines it fits an `int`, which is
all the cast needs.

#lines(1, 25)

`alloc` (which is the program's `malloc`, #f("sh/defs.h")) looks for a
free block of at least `rbytes`, the request plus the header, rounded
to a word. The search starts at `blokp`, where the last one ended, and
goes round the circle: first fit, as the comment says. Adjacent free
blocks are merged as they are met (35). A block larger than needed is
split, and the remainder, from `blokp` up, stays free. The counter `c`
lets the search pass the wrap from `bloktop` back to `end` only once;
if nothing is found, `addblok` enlarges the arena and the search starts
again.

The cast to `POS` in the comparison (36) is new. The difference of two
pointers is signed, `rbytes` is unsigned, and GCC warns of the
comparison of the two (`-Wsign-compare`); the comparison was unsigned
in v7 too, and the cast only says so.

#lines(26, 49)

`addblok` adds at least `reqd` bytes to the top of the arena, which
means moving the stack, since the stack lies directly above
`bloktop`. If there are items on the stack, the stack, up to the end of
the item under construction, becomes a busy block of the heap: the old
`bloktop` now points past it, and its first word, the one just below
`stakbas`, links it into the chain `stakbsy`, so that `tdystak`
(#f("sh/stak.c")) can free it later. The arena then grows by `reqd`
rounded up to a multiple of `brkincr`; the new `bloktop` points back to
`end`, busy (67). Finally the item under construction is copied to the
new base of the stack, two words above `bloktop`, one for the
`bloktop` header and one to serve as the `stakbsy` link when the stack
next turns into a block.

The items already on the stack thus keep their addresses; only the
current item moves, which is why #f("sh/stak.h") warns about pointers
into it. Note that `addblok` does not itself extend the data segment.
On the PDP-11 the stores into the new space would fault and be extended
by `fault`; here they land in memory that is already mapped (see
#f("sh/stak.c")). The cast of `round`'s result (58) is new, as in
#f("sh/stak.c").

#lines(50, 73)

`free` clears the busy bit of the block's header, the word before
`ap`. Pointers at or above `bloktop` are ignored. Such a value lies on
the stack, or among the arguments and environment strings which `exec`
placed at the top of memory, and the callers (`freeargs`, for one, in
#f("sh/args.c")) free values without asking where they came from.

The argument is `void *`, where v7 had `BLKPTR`, to match the standard
declaration of `free` (#f("sh/defs.h")). v7 cleared the bit in place
through `Lcheat`, writing the pointer through an `int` lvalue. That
breaks the aliasing rules of C99, under which the optimiser may assume
that a store to an `int` does not change a pointer; the port reads the
pointer, clears the bit, and stores it back (80).

#lines(74, 82)

`chkbptr` checks the arena when the shell is compiled with `DEBUG`,
which it never is. It is left as v7 wrote it, in the old style, and
would not compile under C99.

#lines(83, 108)
#source("/usr/src/cmd/sh/setbrk.c")

`setbrk` moves the end of the data segment by `incr` bytes, which may
be negative, and records the new end in `brkend`. It returns the old
end, or `-1` cast to a pointer if the kernel refused; `fault`
(#f("sh/fault.c")) tests for that, now by comparing with `(BYTPTR)-1`;
v7, whose `setbrk` returned an `int`, compared with `-1`. `sbrk` is the library's (`sbrk.s`), which calls the `break`
system call, `sbreak` in #f("sys1.c").

The return type `BYTPTR` (12) is new. v7 left `setbrk` to default to
`int`, though it returns a pointer, and declared it nowhere; on the
PDP-11 a pointer and an `int` were the same size, and returning one as
the other did no harm. The port declares it in #f("sh/defs.h"), with
the type of the value it actually returns.

#lines(1, 18)
#source("/usr/src/cmd/sh/main.c")

`main` sets up the shell's storage, signals, and variables, decides
where commands are to come from, and calls `exfile`, which reads and
executes them until the end of the input.

The definitions at 23--30 are new. They are the variables which
#f("sh/defs.h") declares; in v7 the header itself defined them, in
every file, and the loader merged the copies. `execargs.h` (31) defines
the pointer `execargs`, explained below.

`exfile` is declared `LOCAL`, where v7 declared it `PROC`, that is
`extern`, and then defined it `LOCAL`. C99 forbids a `static`
definition after a declaration with external linkage.

#lines(1, 37)

The storage is set up first: `stdsigs` (#f("sh/fault.c")) arranges,
among other things, to catch `SIGSEGV`, by which v7 grew the data
segment (#f("sh/stak.c")); `setbrk` gives the shell its first
`BRKINCR` bytes; and `addblok` makes the first heap block and places
the stack above it (#f("sh/blok.c")). Only then can anything be
allocated. `getenv` (#f("sh/name.c")) turns the environment into shell
variables.

The test for a restricted shell, by the letter `r` in the shell's name,
was commented out in v7 already, so `rflag` stays `ttyflg`, and a
restricted shell can only be had with the option `-r`.

`options` (#f("sh/args.c")) processes the flags and returns the number
of arguments left. If there is no file name among them, or the flag
`-s` was given, commands are read from the standard input (`stdflg`);
`dolv` and `dolc` are left describing the positional parameters, with
`dolv[0]` the name of the shell or of the command file, `$0`.

#lines(38, 61)

`subshell` is the point to which the shell returns when it is asked to
run a command file without execute format. `execs` (#f("sh/service.c"))
finds that `exec` fails with `ENOEXEC`, opens the file as the shell's
input, sets the new arguments, and jumps here, in the child process
which was to have executed it. The shell then starts afresh, from the
setting of `$#`, `$0`, `$$`, and the temporary file names, but skips
the profile.

The profile is read only by a login shell, which `login` (#f("cmd/login.c")) starts with a `-` before its
name. While it is read, `exfile` is given `ttyflg` as `prof`; see
below. A command string given with `-c` is set up as the input by
`estabf` (#f("sh/io.c")); otherwise the input is the standard input or
the named file. `comdiv--` makes a null `comdiv` non-null, so that a
later `set -c` is not taken as a command string (`options`, #f("sh/args.c")).

On re-entry for a command file (92), the shell stores `dolv` through
`execargs`, at the top of its user stack. That word is where `ps`
looks for the arguments of a process, and the store makes the command
file appear there under its own name. In v7 `execargs` was
`(char **)-2`, the last word of the PDP-11's 64 KB address space; in
the port it is `0x100000-4`, the last word of the 1 MB window, which
`exec` leaves zero. The cast of `dolv` to `char *` is new: v7 stored a
`char **` where a `char *` belongs without one.

#lines(62, 97)

`exfile` moves the input and output descriptors to `INIO` and `OTIO`,
out of the way of the descriptors a user may redirect, and sets them to
be closed on `exec` (`Ldup`, below).

The shell is interactive if `-i` was given, or if input and output are
both terminals, as `gtty` succeeding shows. An interactive shell sets
the prompts and ignores `SIGTERM` (`KILL` in #f("sh/defs.h") is 15).
`statb` serves only as a buffer for `gtty`, and the port casts its
address to the type that `gtty`'s prototype demands.

Errors return to `errshell`, through `exitsh` (#f("sh/error.c")), but
only in an interactive shell; any other exits. That is why the profile
is read with `ttyflg` set in `flags` (from `prof`, 124): an error in
the profile comes back here, and `exfile` returns, abandoning the
profile but not the shell.

`mailtime` is `volatile`, where v7 had `register`. It is changed after
the `setjmp` (127) and used after a `longjmp` to it, and C99 leaves the
value of such a variable indeterminate unless it is `volatile`.

#lines(98, 130)

The command loop. `tdystak(0)` discards everything left on the stack by
the last command, and `stakchk` gives back any surplus memory
(#f("sh/stak.c")). An interactive shell then reports new mail, judged by
a change in the time of the last modification of the file named in
`$MAIL`, and prints `PS1`. `alarm(TIMEOUT)` would end a shell left idle
too long; here `TIMEOUT` is 0 (#f("sh/timeout.h")), so no alarm is set.

`readc` reads the first character of the command, which is pushed back
into `peekc`, so that `eof` can be tested before parsing begins. `cmd`
(#f("sh/cmd.c")) then parses one command, up to a newline, and
`execute` (#f("sh/xec.c")) runs it. v7 called `execute` with two
arguments, leaving the two pipe arguments undefined; the prototype
demands all four, and the port passes zeros. The option `-t`
(`oneflg`) ends the shell after one command.

#lines(131, 158)

`chkpr` prints the secondary prompt, `PS2`, when a command continues on
a further line. `settmp` makes the prefix of the names of temporary
files from the process id: `/tmp/sh-` followed by the id.

`Ldup` moves descriptor `fa` to `fb` and sets close-on-exec on it. v7
wrote `dup(fa|DUPFLG, fb)`: the `dup` system call took the second
descriptor as an extra argument when the flag `DUPFLG` (#f("sh/dup.h"))
was or-ed into the first. The library's `dup2` does exactly that, and,
unlike `dup`, has a prototype with two arguments.

#lines(159, 181)
#source("/usr/src/cmd/sh/io.c")

The shell's input is a stack of `fileblk`s (#f("sh/mode.h")), of which
`standin` is the top; `readc` (#f("sh/word.c")) takes characters from it.
This file sets up and changes the input, opens and creates files on
behalf of the rest of the shell, and copies here documents.

`initf` makes descriptor `fd` the source of `standin`. An interactive
shell, or one run with `-t`, reads one character at a time, a size of
1; any other reads 64 bytes. Reading a byte at a time, the shell never
takes more than the command it is about to run: what follows, typed
ahead or left in the input, belongs to the commands it starts or, with
`-t`, to whatever reads the input after the shell.

#lines(1, 24)

`estabf` makes the string `s` the input, with no file behind it
(`fdes` is -1). The end, `fend`, is placed after the terminating null,
since `length` (#f("sh/string.c")) counts it; `readc` sees the null and
then finds the input exhausted. `push` and `pop` stack and unstack
inputs, for `eval` and `.` (`execexp`, #f("sh/xec.c")), the `read`
command (#f("sh/name.c")), and the substitutions of #f("sh/macro.c").

#lines(25, 58)

`chkopen` and `create` open a file or report failure. `failed`
(#f("sh/error.c")) does not return, but the compiler, which cannot
know that, warns of a function that may end without returning a value;
the port adds `return(0)` (77, 99). `rename` moves a descriptor, by
`dup2`, where v7 used `dup` with `DUPFLG` (see `Ldup` in
#f("sh/main.c")). `tmpfil` makes a fresh temporary file, named from the
prefix made by `settmp` and a serial number.

#lines(59, 107)

`copy` reads the here documents named in the list `ioparg` (they were
collected in `iopend` by `inout`, #f("sh/cmd.c"), and are read once the
command line is complete). The list was built backwards, so `copy`
first recurses to its end, and the documents are read in the order in
which they were named. Each is copied line by line to a temporary
file, until a line equal to the terminating word; the I/O node is
changed to name the file, and joined to the chain `iotemp`, so that the
file is removed after the command. The text is read with `nextc`,
which handles `\` escapes, unless the terminating word contained
quotes. Then `trim` (#f("sh/service.c")) sets `nosubst`, and the text is
read raw and marked not to undergo substitution.

`nosubst` (110) is now declared `extern`. v7 defined it both here and
in #f("sh/service.c"), which worked only because the loader merged the
two. The parentheses around the assignment in the test (120) are new,
and tell GCC that `=` is meant.

#lines(108, 137)
#source("/usr/src/cmd/sh/word.c")

The lexical analyser. `word` reads the next word or symbol and leaves
its code in `wdval` (#f("sh/sym.h")): 0 for an ordinary word, whose
text is in `wdarg`; a reserved word's code if one is acceptable here;
or the character, or doubled character, which ends a word.

The declaration of `readb` (12) is new. v7 called it before its
definition and let it be declared implicitly, which C99 does not
allow.

#lines(1, 17)

An ordinary word is built on the stack as a `struct argnod`, ready to
be linked into an argument list: `locstak` begins an item, and the text
starts one word in (22), leaving room for the link `argnxt`. That the
offset is `BYTESPERWORD` and the link a pointer agree on the ARM as on
the PDP-11, since `BYTESPERWORD` is the size of a pointer
(#f("sh/mode.h")).

Quoting is recorded in the characters themselves. Within `'...'`, every
character has the quote bit or-ed in, and the whole is enclosed in
double quotes; within double quotes or backquotes, `nextc` sets the bit on
escaped characters only, since parameters and commands are still to be
substituted there (#f("sh/macro.c")). A quoted character fails every
test of #f("sh/ctype.h"), and so cannot end the word. The quote bits
are removed by `trim` once substitution is done. On the PDP-11 a `char`
with the quote bit set was negative, on the ARM it is not; nothing here
depends on which.

`wdset` notes a word of the form `name=value`, which is an assignment if
`name` is an identifier. A single digit followed by `<` or `>` is not a
word but the descriptor of a redirection: `word` calls itself to read
the operator, and leaves the digit in `wdnum`. Otherwise, when the
parser has set `reserv`, the word is looked up among the reserved
words.

v7 used `argp`, a `char *`, as a pointer to the `argnod` as well, which
its compiler permitted. The port adds `arg` (23), of the right type,
and uses it from the end of the word on (45--53).

#lines(18, 56)

A character which ends a word is a symbol in itself. If it is one of
`&;<>|` (`dipchar`) and is doubled, it becomes the doubled symbol;
otherwise the second character is pushed back. The null character,
which `readc` returns at the end of the input, becomes `EOFSYM`. At the
end of a line, any here documents named on it are read (`copy`,
#f("sh/io.c")), since their text begins on the next line.

#lines(57, 71)

`nextc` deals with the backslash. Before a newline it joins the lines,
printing the secondary prompt. Inside double quotes, where `quote` is
the quote character, a backslash is kept, and the following character
pushed back, unless that character is the quote itself or one of the
characters `escchar` allows; anywhere else the next character is taken
quoted.

#lines(72, 86)

`readc` returns the next character of the input. A character pushed
back in `peekc` comes first; the assignment to the `char` `c` drops
`MARK`. Then come characters left in the buffer. A null in the buffer
ends a string set up by `estabf`; if the input has a list of further
strings (`feval`, set by `execexp` in #f("sh/xec.c") for the
arguments of `eval`), the next is begun,
separated by a space. `-v` (`readpr`) echoes the input as it is read,
and the line count `flin` serves the messages of #f("sh/cmd.c").
When the buffer is empty, `readb` refills it; at the end of a file the
descriptor is closed and `EOF`, the null character, is returned
from then on.

#lines(87, 118)

`readb` reads again when a read is interrupted by a signal which has
a trap set (`trapnote`). A signal without a trap (`SIGSET`) is instead
treated as an error by `sigchk` (#f("sh/error.c")), which ends the
shell or, if it is interactive, abandons the command. The return type
`INT` is a mechanical addition.

#lines(119, 128)
#source("/usr/src/cmd/sh/cmd.c")

The parser. It is written by recursive descent, one procedure to each
rule of the grammar given in the comments: `cmd` for a sequence of
commands, `list` for commands joined by `&&` and `||`, `term` for a
pipeline, and `item` for a single command, simple or compound. Each
calls `word` (#f("sh/word.c")) for the next symbol, which it finds in
`wdval`, and returns a tree of the nodes of #f("sh/mode.h"), allocated
on the stack with `getstak`. The tree lasts until the command loop of
#f("sh/main.c") resets the stack, after `execute` has run it.

The parser keeps one symbol of lookahead, in `wdval`. A procedure is
entered with the first symbol of its phrase already read, or reads it
itself, according to the flag `NLFLG`; and it returns with the symbol
after the phrase in `wdval`. Reserved words are recognised only where a
command may begin, which the parser announces by incrementing `reserv`
before it calls `word`; `word` clears it again.

The procedures of the file are declared `LOCAL` at the top (13--23),
where v7 declared them `PROC`, that is `extern`, and defined them
`LOCAL`, a contradiction C99 does not allow. `skipnl` was declared
`VOID`, but returns `wdval`, and `item` uses the result (232); with
`VOID` now `void` it is declared, and defined, `INT`.

#lines(1, 30)

`makefork` and `makelist` make the two commonest nodes. v7 declared the
local `t` in each as a `TREPTR` and assigned the fields of a fork or
list node through it, which its compiler allowed for any structure
pointer. The port declares `t` as the pointer it is, and converts it to
`TREPTR` on return. `getstak` returns a `STKPTR`, a `char *`, and each
call of it now has a cast to the type of node wanted, as C99 requires. The same change is made throughout `item` below,
where the port introduces a pointer of the specific type (`s`, `it`,
`fr`, `wh`, `c`) beside v7's `t`.

`makelist` initialises `t` to 0. `synbad` never returns, but the
compiler cannot know it, and would otherwise warn that `t` may be
returned unset.

#lines(31, 51)

`cmd` parses a list, then looks at what ended it. A newline, when
`NLFLG` allows one, is treated as `;`. An `&` makes the list into a
fork node which is not waited for (`FAMP`), ignores interrupts (`FINT`),
and has its process id printed (`FPRS`); then, like `;`, it may be
followed by a further command, parsed by a recursive call. `sym` is the
symbol the caller expects to end the command, such as `fi` or `)`;
`chksym` insists on it.

The comments `/* fallthrough */` (82, 94) are new, and tell GCC that the
missing `break` is intended; it warns of one otherwise. The
parentheses around the assignment (85) say the same of `=` in a test.

#lines(52, 103)

`list` and `term` make the left-to-right chains of `&&`, `||`, and the
pipe. A pipeline becomes a `TFIL` node over two fork nodes: the left
writes the pipe (`FPOU`), the right reads it and closes it in the shell
(`FPIN|FPCL`). `^` is an older spelling of `|`. Since the right side is
parsed by a recursive call, a long pipeline nests to the right.

#lines(104, 144)

`syncase` parses the arms of a `case` until `esac`, or `}`: each arm is
a list of patterns separated by `|`, then `)`, a command list, and `;;`.
The patterns are chained by reusing the words' own `argnxt` links.

#lines(145, 171)

`item` parses one command. A simple command may begin with
redirections, so when `flag` allows, `inout` collects them first.

#lines(172, 195)

The compound commands. Each allocates its node and fills it by calling
`cmd` with the symbol which must end each part. `elif` is handled by
treating it as the start of a nested `if`, with `wdval` set to `IFSYM`
and `item` called again; the nested `if` consumes the `fi`, and the
outer returns at once (219).

#lines(196, 221)

`for` takes a name, an optional `in` with its list of words, which is
parsed as a simple command and stored as a `COMPTR` (234), then a
`do ... done` or a `{ ... }`. The cast of the result of `item` is new.
`while` and `until` share a node, distinguished by type. A brace group
is no node at all, but just its command list; a parenthesised command
is a `TPAR` node inside a fork node, so that it is run in a subshell.

#lines(222, 269)

The simple command. Words are taken until a symbol appears; each is
either an assignment, chained on `argset`, or an argument, appended to
the list through `argtail`. Assignments are recognised only before the
first argument, unless the option `-k` (`keyflg`) is set. Redirections
may be interleaved with the words. `argset` is declared as a pointer to
`ARGPTR`, though it holds an `ARGPTR`; v7 assigned between the two types
freely, and the port casts (291, 300).

If no command begins here (`default`), but redirections were found, a
command without words is made, and the case falls through (275, with
the new comment). After a compound command, redirections may follow
(305); they wrap the command in a fork node, through whose `treio` they
are applied. The parentheses around the assignment (306) are new.

#lines(270, 310)

`skipnl` reads symbols until one is not a newline, prompting with
`PS2` for each.

#lines(311, 317)

`inout` parses one redirection, and recursively those that follow. The
descriptor, if one was given before the operator, is in `wdnum`; the
kind of redirection is or-ed above it (#f("sh/defs.h")). A `<<`
document is also put on `iopend`, to be read at the end of the line
(#f("sh/word.c")). `<&` and `>&` are distinguished by reading one more
character directly, and `<>` gives read and write. The `>` case falls
through into the `<` case to make that test (339, with the new
comment).

#lines(318, 361)

`chkword` requires an ordinary word. `chksym` requires the symbol
`sym`, or one of several reserved words or-ed together: when both
`sym` and `wdval` are reserved words, `x` is their common bits, and
equals `wdval` only if all of `wdval`'s bits are in `sym`
(#f("sh/sym.h")).

#lines(362, 376)

`synbad` reports a syntax error, naming the offending symbol through
`prsym`, with the line number when the shell is not interactive, and
leaves through `exitsh` (#f("sh/error.c")).

#lines(377, 411)
#source("/usr/src/cmd/sh/msg.c")

The shell's strings, gathered in one file so that each is stored once.
A `MSG` is an array of `char`, so each name stands for the address of
its text. `version` is used nowhere; it records the version of the
shell in the binary. The default `PATH` (55) searches the current
directory first.

#lines(1, 67)

`reserved` pairs each reserved word with its code from #f("sh/sym.h");
`word` (#f("sh/word.c")) searches it with `syslook` (#f("sh/name.c")).
`sysmsg` gives, for each signal number, the message printed when a
command dies of it (#f("sh/service.c")). The entries for interrupt and
broken pipe are null, since a user who interrupts a command, or a
command whose reader has gone, needs no message. `commands` is the
table of built-in commands, with their codes from #f("sh/defs.h");
the entry for `[`, `SYSTST`, is commented out, as in v7.

The only changes are the `=` before the initialisers of the three
tables (70, 89, 111), which v7's compiler did not require.

#lines(68, 136)

= Running Commands

#source("/usr/src/cmd/sh/dup.h")

`DUPFLG` is the flag which v7's `dup` system call recognised in its
first argument: or-ed into the descriptor, it made `dup` take a second
argument and move the descriptor to that number, as `dup2` does on later
systems. #f("sh/main.c") and #f("sh/io.c") still include the file, but
call the library's `dup2` instead (`Ldup` and `rename`), so that the
call agrees with a prototype of two arguments. The definition is now
used nowhere.

#lines(1, 10)
#source("/usr/src/cmd/sh/timeout.h")

`TIMEOUT` is the number of seconds an interactive shell may sit at its
prompt before it gives up. The command loop of #f("sh/main.c") calls
`alarm(TIMEOUT)` before each read, and `fault` (#f("sh/fault.c"))
ends the shell if the alarm arrives while it is still waiting. With the
value 0, as in v7, the call cancels any alarm instead, and an idle shell
waits indefinitely. A site which wanted the feature changed this file.

#lines(1, 10)
#source("/usr/src/cmd/sh/xec.c")

`execute` walks a command tree made by `cmd` (#f("sh/cmd.c")) and does
what it says. It is recursive: each kind of node calls `execute` on its
parts, and the value returned is the exit status of the last command
run, which the conditional nodes test. Most of the shell's work with the
kernel happens here or in the routines of #f("sh/service.c") that it
calls: `fork` (#f("sys1.c")) to make a process for a command, `pipe`
(#f("pipe.c")) to connect two, `exece` (#f("sys1.c")) to run a program,
and `wait` (#f("sys1.c")) to collect its status.

v7 called `execute` with only two arguments when no pipe was involved,
leaving `pf1` and `pf2` undefined, which its compiler allowed. With a prototype every call must
pass four, and the port passes zeros throughout the file.

`commands` (15), the table of built-in commands, is defined in
#f("sh/msg.c"); the declaration is now `extern`, where v7's tentative
definition relied on the loader to merge it with the real one
(#f("sh/defs.h")).

#lines(1, 21)

`execflg` is set when the command is the last thing the current process
has to do. A simple command may then be executed by `exec` without a
`fork` first (242), since there is nothing to come back to.

`sav` and `tdystak` (415) bracket the whole routine: whatever the
command allocated on the stack, its expanded arguments in particular,
is discarded when it ends. A nonzero `execbrk` (31) means that `break`
or `continue` is unwinding the loops, and every command until the
enclosing loop is reached is skipped by this test.

`com` is initialised (34) in the port. It is set only in the `TCOM`
case, and used after the fall into `TFORK` only when the type is `TCOM`;
GCC cannot follow the correlation and warned that it might be used
unset.

#lines(22, 38)

A simple command. Its words are expanded by `getarg`, which substitutes
parameters and generates file names, and `scan` gathers the results into
an argument vector `com` (#f("sh/service.c")). The expansion builds the
global chain `gchain`, which is saved and restored around it because
expanding a word may itself execute a command, by command substitution
(#f("sh/macro.c")), and so re-enter `execute`.

Note that the parser never wraps a simple command in a fork node: only
now, after expansion, can the shell tell whether the name is one of its
own commands (`syslook`). The assignments which precede a built-in
command, or stand alone, are made in the shell itself (54); those
before a program are made in the child for that program only (299).
The option `-x` (`execpr`) prints the expanded command.

The port names the node through `c`, a `COMPTR`, where v7 used the
generic `t` for every field. In particular v7 read the I/O list of a
command node as `t->treio`; it is now `c->comio`, the same word, since
both structures put it after the type (#f("sh/mode.h")). The
parentheses around the condition (53) mark the assignment within it as
intended.

#lines(39, 65)

The built-in commands. `.` reads commands from a file in the current
shell by way of `execexp` (420). `times` prints the user and system
times of the shell's children, which the kernel accumulates in
`u_cutime` and `u_cstime` (`times`, #f("sys4.c")); `prt` converts ticks
to minutes and seconds assuming 60 to the second, which is still `HZ`
(#f("param.h")).

`break` and `continue` work through `execbrk`. `continue` sets it to
`-loopcnt`, a negative value which the loops below reset to zero after
each pass of the body. `break` sets it to the positive `loopcnt`, and
`break n` sets `breakcnt` as well, which each loop on the way out
decrements, so that `n` loops are left. This is why `execbrk` must hold a
negative number, and is no longer a `char` (#f("sh/defs.h")).

v7 let the `exit` case fall through into the next, harmless since
`exitsh` never returns. GCC warns of a fall through between cases
without a comment to say it is meant; the port ends the case with
`break` (88), which states the intent better.

#lines(66, 101)

`trap` with a command and signal numbers stores the command in
`trapcom` and catches the signals; an empty command ignores them
instead. If the first argument is a number, there is no command, and
the listed traps are removed. Without arguments the traps are listed.
The mechanism is in #f("sh/fault.c").

#lines(102, 131)

`exec` applies its redirections to the shell itself (135). With no
command, that is all. Otherwise it falls into `login` (and `newgrp`,
which has the same code): the shell marks itself `forked`, so that an
error now ends it rather than returning to the prompt, restores the
signals it inherited (`oldsigs`), and executes the command in its own
process. If the `exec` fails, `done` ends the shell. The comment
`/* fallthrough */` (137) is new and silences GCC; the `break` after
`done` (142) is new for the reason given for `exit`.

`wait` calls `await(-1)`, which collects children until there are none
left (#f("sh/service.c")).

#lines(132, 166)

The `test` command was meant to be built in, but v7 left it commented
out; `test` is a separate program.

`set` with arguments processes options and replaces the positional
parameters; without, and without assignments, it lists the variables.
`readonly` and `export` share code, with `exitval` borrowed to hold the
attribute until it is reset (198). The comment at 189 is new.

`eval` runs its arguments as commands with `execexp`. The second
parameter of `execexp` is declared `UFD`, an `int`, but serves two
purposes: a file descriptor when the first is null, otherwise the
address of the list of further arguments. v7 passed the address
without a cast; C99 requires one each way, here and at 426, and the
conversion is exact because an `int` and a pointer are both 32 bits on
the ARM, as both were 16 on the PDP-11.

#lines(167, 206)

`umask` was added to the shell after Bourne, by someone who wrote
plain C with spaces for indentation instead of the macros of
#f("sh/mac.h"); the port keeps it as it is. In v7 the declaration at
209 lacked its semicolon, a syntax error, and the port adds it.

#lines(207, 224)

`builtin` (#f("sh/builtin.c")) is a hook for local built-in commands,
and returns zero. v7 passed it `argn` and `com`, which its definition
ignored; it is now declared without parameters and called without
arguments.

A built-in command may not be redirected, except `exec` and `:`, which
cleared `io` above. After a built-in, traps raised meanwhile are run by
`chktrap`. A command with no words and no redirections consisted only
of assignments, and is finished. The remaining cases, a program to run
or redirections with no command, fall through (239, new comment) to be
forked.

#lines(225, 240)

The fork. No process is made if `execflg` says this is the last
command of the present process, unless the node is to run in the
background (`FAMP`) or write into a pipe (`FPOU`): in either case the
shell must go on to do something else. If `fork` fails, because the
process table is full, the shell waits ten seconds with `alarm` and `pause` and
tries again; an interrupt meanwhile ends the attempt through `sigchk`.

Only the zero or nonzero value of `fork` is used. The port's kernel
returns 0 in the child, where v7's returned the parent's pid and relied
on the library to tell the two apart (#f("sys1.c")); the shell sees the
same values either way.

The parent prints the child's pid for `&` in an interactive shell, and
closes its copy of the pipe once the reading end of a pipeline has been
forked (`FPCL`). It then waits (`await`) for an ordinary command,
records (`post`) the writer of a pipe, to be waited for together with
the reader at the end of the pipeline, or, for `&`, stores the pid in
`$!` and does not wait at all.

#lines(241, 264)

The child. It is marked `forked`, forgets its parent's temporary files
and children, and makes temporary names of its own (`settmp`,
#f("sh/main.c")). `oldsigs` (#f("sh/fault.c")) restores the signals to
their state on entry, except those which a `trap` set to be ignored. A
command run with `&` ignores interrupt and quit (276), and, unless its
standard input was otherwise set, reads `/dev/null`, so that it cannot
compete with the terminal. Ignored signals stay ignored across `exec`
(`setregs`, #f("sys1.c")); this is all the protection v7 gives the
terminal against a background command.
v7 wrote `signal(INTR,1)`; the port uses `SIG_IGN`, which
`signal.h` defines as the pointer the prototype of `signal` expects.

The pipe ends are moved to the standard input or output with `rename`
(#f("sh/io.c")), and the unused end is closed: a reader sees the end of
a pipe only when every descriptor for its writing end has been closed
(`readp`, #f("pipe.c")), and a stray copy in the reader itself would
hang it. Then the node's redirections are applied, after those defaults,
so that they win.

A subtree, from a parenthesised command, an `&`, or a pipeline, is run
by a recursive `execute` with `execflg` set, so that its last command
is executed without a further fork. A simple command is executed by
`execa`. Either way `done` ends the child if control comes back.

The `break` (304) is new. In v7 the `TFORK` case ended without one,
since both branches leave by `break` or `done`, and control passed into
`TPAR` in appearance only.

#lines(265, 305)

A parenthesised command runs in a child made by the enclosing fork
node. Its diagnostic output, `output`, is a private copy of descriptor
2 made by `exfile` (#f("sh/main.c")); it is replaced by a fresh copy of
the present descriptor 2, so that a redirection of the standard error
around the parentheses applies to the subshell's own messages too. The
`break` (310) is new, as at 304.

#lines(306, 311)

A pipeline. A pipe is made, and the left side is run with it as `pf2`,
its output; the right side is then run with it as `pf1`, its input,
and with the original `pf2`, so that a longer pipeline, which nests to
the right, passes its last output through. The left side is a fork node
with `FPOU`, so `execute` returns as soon as it has been forked, and
the right side, which has `FPCL`, closes the pipe in the shell and
waits for both. The pipe is made only now, when it is needed, so that
the shell holds at most one at a time. `l` (314) is the port's typed
pointer, as `c` above.

#lines(312, 322)

The lists: `;`, `&&`, and `||`. Only the right side of each inherits
`execflg`, since the left must return to the shell.

#lines(323, 339)

`for`. Without `in`, the loop runs over the positional parameters, and
`useargs` (#f("sh/args.c")) increments their use count, so that a `set`
in the body does not free them while the loop is using them;
`freeargs` releases them at the end. With `in`, the list is expanded as
for a command. `scan` leaves the first word of its result untrimmed
(#f("sh/service.c")), and `trim` here removes its quoting.

`loopcnt` counts the loops entered, for `break` and `continue`; on
leaving, `breakcnt` is decremented and becomes the new `execbrk`, which
stops the next loop out if more remain to be broken.

#lines(340, 366)

`while` and `until` differ in one comparison: the body is run while the
status of the condition, compared with zero, agrees with the type. The
exit status is that of the last pass of the body, or zero if there was
none.

#lines(367, 389)

`case`. The word is expanded and its quoting removed. Each pattern of
each arm is expanded in turn and matched with `gmatch`
(#f("sh/expand.c")). Characters quoted in the pattern still carry the
quote bit and match only themselves; failing that, the pattern is
trimmed and compared as a plain string. The first arm with a match is
run and the search ends. The typed pointers `s` and `re` are the port's,
and the `TREPTR` casts (394, 406) are needed because v7 used `t` to walk
the list of `regnod`s, which have no type field at all.

After any command, `exitset` (#f("sh/error.c")) copies the status into
`$?`.

#lines(390, 417)

`execexp` executes a string, for `eval` and for traps, or the contents
of an open file, for `.`. A new input block is pushed on the input
stack (#f("sh/io.c")), the whole input is parsed by one call of `cmd`,
with newlines taken as `;`, and only then executed. A file read with
`.` is therefore parsed completely before any of it runs.

#lines(418, 432)
#source("/usr/src/cmd/sh/service.c")

The routines with which `execute` (#f("sh/xec.c")) does its detailed
work: redirection, the search of `$PATH` and the `exec` of a program,
the waiting for children, and the conversion of a command's words into
an argument vector.

The three `LOCAL` declarations (13--15) are new in this form. v7
declared `gsort` `PROC`, that is `extern`, and `execs` in
#f("sh/defs.h"), and then defined both `LOCAL`; `split` it did not
declare at all, and its first use in `getarg` declared it implicitly as
an external function. C99 forbids a `static` definition after a
declaration with external linkage, and has no implicit declarations.

`errno` and `sysmsg` are now declared `extern`. They are defined in the
C library and in #f("sh/msg.c"); in v7 these lines were tentative
definitions, merged by the loader with the real ones, which C99 does not
allow (#f("sh/defs.h")). The error numbers are defined here by hand, as
in v7, rather than taken from `errno.h`.

#lines(1, 32)

`initio` applies a list of redirections, in order, to the present
process. A here document has already been copied to a temporary file
when its line was read (#f("sh/io.c")); `subst` (#f("sh/macro.c")) copies it again,
substituting parameters, into a second temporary file, which is opened
for reading and at once unlinked, so that it vanishes when closed. `<&`
and `>&` duplicate a descriptor, or with `-` close it; the others open
or create the named file. The new descriptor is moved to the one being
redirected by `rename` (#f("sh/io.c")). A restricted shell may not
redirect output.

`fd` is initialised to -1 (36) in the port. On the path through
`failed` (56) it is never assigned, but GCC cannot know that `failed`
does not return, and warned that `fd` might be used unset.

#lines(33, 67)

`getpath` returns the list of directories to search for a command: the
empty string, meaning the name itself, if the name contains `/`; else
`$PATH`, or the default `:/bin:/usr/bin` (#f("sh/msg.c")), whose
empty first entry stands for the current directory. `return(0)`
(81) is new. It is never reached, since the one path which arrives
there passes through `failed`; v7 let control run off the end of the
function, of which GCC warns.

`pathopen` opens a file found by the search, for `.`. `catpath` builds
on the stack the next candidate, the first directory of `path` joined to
`name`, and returns the rest of the list, or 0 when it is exhausted.

#lines(68, 106)

`execa` tries each directory in turn. Before the first `exec` the
exported variables are marked (`exname`) and the environment is built
(`setenv`, #f("sh/name.c")). The parentheses around the assignment (119)
are new and tell GCC that `=` is meant.

`execs` calls `execve` (`exece` in #f("sys1.c")); if it returns at all,
it has failed, and `errno` says why. `ENOENT` and most others send the
search on to the next directory, remembering for the final message that
a file was found but could not be executed.

`ENOEXEC` means that the file exists but is not a program. The shell
then takes it to be a command file and runs it itself: this is how a
shell procedure is executed, since v7's kernel knows nothing of `#!`.
The shell, already the child made for the command, resets its flags and
input, opens the file as its input, makes the arguments the positional
parameters, and jumps to `subshell` in `main` (#f("sh/main.c")), which
starts afresh. The port's kernel returns `ENOEXEC` for any file that is
not ELF (#f("sys1.c")), so every shell procedure takes this path.
`ETXTBSY` cannot occur, since no text segment is shared.

The comments `/* fallthrough */` are new. GCC warns of a case which
runs into the next without one; after `longjmp` and `failed` control
does not in fact pass, and only the last, from `default` into
`ENOENT`, is a fall through in earnest.

#lines(107, 166)

The shell remembers in `pwlist` the children it intends to wait for.
`post` adds one, overwriting the last slot if the table is full;
`postclr` empties it, in a newly forked child.

#lines(167, 196)

`await` posts `i` and then calls `wait` until every posted child has
been collected. Each pid returned is struck from the list; a child
which was never posted, such as a background command that has finished
meanwhile, is reaped all the same, and its status is counted with the
rest. `await(-1)`, for the command `wait`, posts -1, which only the
-1 returned by `wait` when no children remain can strike out; it thus
waits for all children.

The status is as `wait` delivers it (#f("sys1.c")): the exit code in
the high byte, and in the low byte the number of the signal which
killed the process, with 0200 if a core image was written, or 0177 if it
is stopped under trace. A death by signal is reported, by the message in
`sysmsg`, preceded by the pid unless the process was the one awaited
by an interactive shell. The status kept, `rc`, is the first nonzero one collected,
a signal being marked with `SIGFLG`; with the option `-e` any failure
ends the shell. The parentheses at 224 are new.

#lines(197, 248)

`trim` strips the quote bit, 0200, which #f("sh/macro.c") sets on
quoted characters, and records in `nosubst` whether any was found.
`nosubst` is defined here; v7 defined it in #f("sh/io.c") as well. The
parentheses at 258 and 259 are new.

`mactrim` substitutes parameters in a word and removes its quoting.

#lines(249, 271)

`scan` makes the argument vector. The words are on `gchain` in reverse
order, so the vector is filled from its end. The low bit of a link,
`ARGMK`, marks the end of the group of names which one pattern
generated; each group is sorted by `gsort` as it is completed, and the
words otherwise keep their order. Every word but the last taken, which
is `com[0]`, is trimmed here.

The flag bit is cleared and set by casting the pointer to an `int`
(`Rcheat`, #f("sh/mode.h")). C99 needs a cast back to a pointer (274,
289), and another on the result of `getstak` (277).

#lines(272, 293)

`gsort` is a Shell sort, by `cf` (#f("sh/string.c")), with gaps each
one less than a power of two, decreasing to 1.

#lines(294, 316)

`getarg` expands each word of a command and returns the number of
arguments it produced.

`split` divides the result of substitution at the characters of
`$IFS`. Each field is pushed on the stack with room for a link before
it, so that it forms an `argnod` (#f("sh/mode.h")), and is offered to
`expand` (#f("sh/expand.c")), which puts the file names a pattern
matches on `gchain`; if there are none, the field itself goes on the
chain (`makearg`). Either way the head of the chain is then marked as
the end of a group, for `scan`.

`argp` is a `STRING`, and v7 took `->argval` from it directly; the port
casts it to `ARGPTR` (352, 355). v7 set the mark with `Lcheat`, storing
into the pointer through an `int` lvalue, which C99's rules of aliasing
do not allow; it came to light when the port began to compile with
optimisation, and is now an assignment (357).

#lines(317, 359)
#source("/usr/src/cmd/sh/fault.c")

The shell's handling of signals. Two tables are indexed by signal
number: `trapcom` holds the command set by `trap` for each signal, and
`trapflg` its state. `SIGMOD` (#f("sh/defs.h")) records that the shell
has changed the signal's disposition from the one it inherited;
`TRAPSET` and `SIGSET` that the signal has arrived, with or without a
trap. Signal 0 stands for the exit of the shell (`done`,
#f("sh/error.c")).

The handler does next to nothing at the moment of the signal. It only
sets flags, which the shell examines at safe points: `sigchk`
(#f("sh/error.c")) before and after each command, `chktrap` after a
built-in or a child, and the input routines while a command is read.

#lines(1, 18)

`fault` first catches the signal again. The kernel resets a caught
signal to its default before calling the handler (`psig`, #f("sig.c")),
so a second interrupt arriving before this line would kill the shell.

`MEMF` is `SIGSEGV`, the means by which v7's shell grew its data
segment. When a store beyond the break faulted, the PDP-11 kernel undid
the effects of the faulting instruction on the registers (`backup`)
before it sent the signal, so that the instruction was executed again
on return from the handler; `fault` had meanwhile extended the segment
with `setbrk`, and the second attempt succeeded (#f("sh/stak.c")). The
comparison with `(BYTPTR)-1` is new: `setbrk` returns a pointer
(#f("sh/setbrk.c")), and C99 does not compare one with the integer -1.

On the ARM the trick would still work: a data abort leaves the saved
`pc` at the faulting instruction (#f("low.s")), so that returning from
the handler retries it. But it is not needed, since the whole of the
1 MB window is mapped from `exec` onwards, and a store beyond the break
does not fault (#f("sys1.c")). A `SIGSEGV` the shell receives here comes
from a wild reference outside the window; extending the break cannot
cure it, and the fault recurs until `sbreak` refuses to let the data
meet the stack, whereupon `error` reports `nospace`.

`ALARM` ends a shell which is waiting at its prompt
(#f("sh/timeout.h")). Other alarms, such as the one with which a failed
`fork` is retried (#f("sh/xec.c")), only interrupt a `pause`. Any other
signal is noted, as a trap to be run or as a reason to abandon the
command.

#lines(19, 37)

`stdsigs` sets up the signals for the main shell: quit is ignored,
interrupt is caught, and so are `SIGSEGV`, for v7's growth of the
data segment, and the alarm.

`ignsig` ignores a signal and returns 1 if it was already ignored. A
signal the shell inherited as ignored, as an interrupt is in a command
run with `&`, is left so: `getsig` catches a signal only if the shell
itself changed it, or it was not ignored on entry. Hence a `trap` cannot
revive an interrupt in a background shell.

v7 asked whether the old disposition was 1 by testing its low bit
(52), which a function address, being even on the PDP-11, had clear. The
port compares with `SIG_IGN` instead, since C99 allows no arithmetic on
a pointer to a function.

#lines(38, 67)

`oldsigs` is called in a child before it runs a command, and in the
shell before `exec`. Every trap is forgotten by `clrsig`, except one
that `trap` set to be ignored, with an empty command, and pending
signals are discarded. A signal the shell had changed is caught once
more by `fault`, which serves a child that goes on running shell code,
such as a parenthesised command. At `exec` the kernel resets caught
signals to their defaults and leaves ignored ones alone (`setregs`,
#f("sys1.c")). A program therefore receives the signals as the shell
inherited them, except those ignored by `trap ''`.

`clrsig` frees the trap's command; `free` of a null pointer is harmless in this allocator
(#f("sh/blok.c")).

#lines(68, 94)

`chktrap` runs the traps of the signals which have arrived since the
last call, preserving `$?` across them. The parentheses at 106 are new,
to mark the assignment in the condition as intended.

#lines(95, 113)
#source("/usr/src/cmd/sh/builtin.c")

`builtin` is called by `execute` (#f("sh/xec.c")) for a command name
which is not in the table of built-in commands, and returns zero: no
further commands are built in. It is a place for an installation to add
its own. v7's file held only the function, with its type left to
default to `int`. The port includes #f("sh/defs.h"), so that the
definition is preceded by the prototype which `-Wmissing-prototypes`
demands, and declares the function without parameters; v7's caller
passed two arguments which the definition never declared.

#lines(1, 4)
#source("/usr/src/cmd/sh/error.c")

How the shell stops: after an error, after a signal, or at the end.

`exitset` copies the exit status into the variable `$?`. `sigchk`,
called before and after every command, abandons the command if a signal
for which no trap is set has arrived (`fault`, #f("sh/fault.c")); the
status is then `SIGFAIL`.

#lines(1, 32)

`failed` prints a message, prefixed by the name of the shell or
command file when the shell is not interactive (`prp`, #f("sh/print.c")), and ends the
command with the status `ERROR`. Neither it nor `error` returns; the
compiler is not told so, which is why some callers in
#f("sh/service.c") carry statements that are never reached, to quiet
its warnings.

#lines(33, 48)

`exitsh` decides between ending the shell and abandoning the command.
Only an interactive shell (`ttyflg`), which is neither a forked child
nor running with `-e` (`errflg`), survives an error: `clearup`
(#f("sh/args.c")) discards the pending input files and `for` lists, and
`longjmp` returns to `errshell` in `exfile` (#f("sh/main.c")), which
reads the next command. Anything else exits through `done`.

#lines(49, 66)

`done` runs the trap set on signal 0, the shell's exit, clearing it
first so that an error within it does not run it again, removes the
temporary files, and exits. The parentheses around the assignment (71)
are new and tell GCC that it is intended.

`rmtemp` unlinks the temporary files made since `base`, which hold
here documents. The I/O nodes naming them are chained through `iolst`
from `iotemp` (`copy`, #f("sh/io.c")); being allocated on the stack, they lie at higher
addresses the later they were made, so a comparison of addresses finds
those newer than `base` (`tdystak`, #f("sh/stak.c")). `done` passes
0 and removes them all.

#lines(67, 86)

= Words and Variables

#source("/usr/src/cmd/sh/name.h")

#f("sh/name.h") describes a shell variable. Each is a `namnod`, and the
nodes form a binary tree ordered by name (`lookup`, #f("sh/name.c")):
`namlft` and `namrgt` are the two subtrees, `namid` the name, `namval`
the present value, and `namenv` the value which the variable had in the
environment, or will be given in the environment of the next program
(`exname`). A variable which has never been set has a null `namval`,
which is not the same as an empty one.

The flags in `namflg` mark a variable as read-only (`N_RDONLY`), as
exported (`N_EXPORT`), or as having come from the environment
(`N_ENVNAM`). `N_ENVPOS` is not used anywhere in the shell. The highest
flag, `0100000`, was the sign bit of a PDP-11 `int`; in the thirty-two
bit `INT` of the ARM it is an ordinary bit, and nothing compares
`namflg` with zero except through a mask. The file is unchanged from
v7.

#lines(1, 25)
#source("/usr/src/cmd/sh/name.c")

The shell's variables. They live in a binary tree of `namnod`s
(#f("sh/name.h")), searched and extended by `lookup`; names and values
are copies on the heap (#f("sh/blok.c")), made by `make`. The file also
holds the two conversions between the variables and the environment:
`getenv`, which turns the environment the shell was given into
variables, and `setenv`, which builds the environment of a program
about to be executed.

The declarations of `chkid` and `namwalk` (12, 13) are needed because
both are called before they are defined; v7 declared `chkid` with
`PROC`, meaning `extern`, and `namwalk` not at all. Both are `LOCAL`,
that is `static`, as their definitions are.

The tree starts with the seven variables which the shell itself
consults, already linked as a balanced tree with `MAIL` at its root:
`FILEMATCH`, `HOME`, and `IFS` to the left, `PATH`, `PS1`, and `PS2` to
the right, in alphabetical order. Their names are strings of
#f("sh/msg.c"). v7 initialised only the first three fields and wrote
the null links as `NIL`, which is `(char *)0` (#f("sh/mode.h")). C99
does not convert a `char *` to a `NAMPTR` without a cast, so the links
are now plain zeros, and the three fields left to default are given
explicitly, since `-Wextra` warns of a structure initialiser which
omits fields.

#lines(1, 26)

`syslook` finds a word in a table of `sysnod`s, terminated by a null
name: the reserved words and the built-in commands (#f("sh/msg.c")).
The first characters are compared before `eq` is called, which spares a
procedure call for most entries. It returns zero for a word not in the
table, which is why no code in either table is zero.

#lines(27, 46)

`setlist` makes the assignments of a list of words, each of the form
`name=value`. Each is substituted and unquoted by `mactrim`
(#f("sh/service.c")) and handed to `setname` with the attributes `xp`;
with `-x` the assignments are printed as they are made. `execute`
(#f("sh/xec.c")) calls it with zero for assignments made in the shell,
and with `N_EXPORT` for those which precede a command and are made in
the child just before the command is executed.

#lines(47, 60)

`setname` splits `name=value` at the `=`, which it replaces by a null
for the duration of `lookup`. A word whose name is not an identifier is
reported with `failed` (#f("sh/error.c")).

For a variable from the environment (`N_ENVNAM`) the value is not
copied: `namval` and `namenv` both point into the environment string
itself. That string lies at the top of the user stack, where `exece`
(#f("sys1.c")) placed it, above the heap. When such a value is later
replaced, `free` is called on it all the same; `free` ignores any
address above `bloktop` (#f("sh/blok.c")), and the call does no harm.

#lines(61, 82)

`assign` refuses to change a read-only variable. `dfault` sets a
variable only if it has no value, and `main` uses it to give `PS1`,
`PS2`, and `IFS` their defaults (#f("sh/main.c")).

#lines(83, 105)

`readvar` is the built-in command `read`. It reads one line of the
standard input and assigns its fields, separated by characters of
`$IFS`, to the named variables in turn; the last variable named takes
the remainder of the line. Missing fields leave the variables empty.

The first variable is looked up (113) before anything is placed on the
stack, as the comment warns: `lookup` may allocate, and an allocation
from the heap can move the item being built (#f("sh/stak.h")). The
position of the field is therefore held as an offset, `rel`, and
converted with `absstak` when it is needed. The cast of `relstak()` to
`STKPTR` is new: the macro yields a difference of pointers, an
integer, and C99 does not assign an integer to a pointer without a
cast. The offset is merely kept in a pointer variable until `absstak`
turns it back into an `int` with `Rcheat` (#f("sh/mode.h")).

The line is read through the shell's own buffered input, from a
duplicate of descriptor 0 pushed as a new input file (#f("sh/io.c")).
`read` must not consume more than the line, or the commands which
follow it in a script read from the same descriptor would lose their
input. If the descriptor can be repositioned, the buffer is filled as
`initf` chose; if it cannot, as for a terminal or a pipe, `lseek`
fails, and `fsiz` is set to one, so that `readb` reads a single
character at a time.

#lines(106, 120)

`nextc` (#f("sh/word.c")) applies the backslash convention. At the end,
the unread part of the buffer is given back by seeking backwards over
it (141): the duplicate shares its offset with descriptor 0 (`dup`,
#f("sys3.c")), so the next reader of the standard input starts just
after the line. The return value is 1 at the end of the file, which is
how a loop of `read` terminates.

#lines(121, 144)

`assnum` stores a number as the value of one of the shell's special
parameters, such as `$#` and `$?`, which are kept as strings
(`dolladr`, `exitadr`). `make` copies a string to the heap; `length`
(#f("sh/string.c")) counts the terminating null, so the copy has room
for it.

#lines(145, 161)

`lookup` finds the node of a name, or makes one. It descends the tree,
comparing with `cf`, keeping in `prev` the address of the link it
followed; when it falls off the tree, a new node is stored through
`prev`. The tree is never rebalanced, nor are nodes ever removed: v7
has no `unset`. A name which is not an identifier is reported by
`failed` before the search.

`prev` is initialised to zero (167) in the port. The loop always runs
at least once, since `namep` is never null, and so always sets `prev`
before the store at 188; GCC cannot see this and warned that it might
be used unset. The cast of `alloc`'s result to `NAMPTR` (184) is new:
`alloc` is `malloc`, which returns `void *`, and the cast serves the
reader rather than the compiler.

#lines(162, 189)

`chkid`: an identifier is a letter followed by letters and digits
(#f("sh/ctype.h"); the underscore is a letter there).

#lines(190, 204)

`namscan` applies a function to every variable, by an in-order walk of
the tree, so that `set` and `export` list the variables in alphabetical
order. The function is passed to `namwalk` through the static `namfn`
rather than as an argument, which saves a word on each level of the
recursion. The prototypes of `namfn` and of `namscan`'s parameter are
new.

#lines(205, 221)

`printnam` prints `name=value` for `set`; `sigchk` (#f("sh/error.c"))
lets an interrupt stop a long listing. `staknam` builds the same string
on the stack for the environment. It assumes that no item is being
built, so that `staktop` equals `stakbot`, and then takes the string as
an item with `getstak`. v7 declared `staknam` in #f("sh/defs.h") as
well; now its definition, which precedes its one use, is its only
declaration (#f("sh/defs.h")).

#lines(222, 243)

`exname` is applied to every variable in the child, just before a
program is executed (`execa`, #f("sh/service.c")). For an exported
variable it copies the present value into `namenv`. For any other it
does the reverse, resetting `namval` to `namenv`. Since `setenv` then
passes on `namval`, the new program receives the present value of every
exported variable and the original value of every variable inherited
from the environment, but nothing set only in the shell. In v7 a
variable from the environment is passed on whether or not it is
exported; only a change to it needs `export`. Since this happens in the
child, the shell's own values are not disturbed.

`printflg` serves `export` and `readonly` without arguments.

#lines(244, 266)

`getenv` makes a variable of each entry of `environ`, which `crt0`
(#f("csu/crt0.s")) set from the arguments of `main`. It has nothing to
do with the C library's `getenv`, which looks up a single name, and
`setenv` likewise has nothing to do with any library function. Note that an entry which does not have the form
`name=value` with an identifier for its name is fatal: `setname`
reports it, and since the flags are not yet set, `exitsh` ends the
shell (#f("sh/error.c")).

#lines(267, 274)

`setenv` builds the environment for `execve` in two passes over the
tree: the first counts the variables, the second pushes a pointer to a
`name=value` string for each one which has a value. The vector, with
its terminating zero, is allocated on the stack (299), and the count
includes variables without a value, so it may be a little larger than
needed. The cast of `getstak`'s result (299) is new, as `getstak`
returns a `char *`.

`countnam` and `pushnam` are now `LOCAL`. In v7 they had external
linkage, though nothing outside this file used them; with
`-Wmissing-prototypes` an external function must have a declaration in
scope before its definition, and making them `static` was the simpler
remedy. `(void)n` tells the compiler that `countnam` ignores its
argument.

#lines(275, 303)
#source("/usr/src/cmd/sh/macro.c")

Substitution. `macro` takes a word as `word` left it (#f("sh/word.c"))
and returns a new string in which each `$` parameter has been replaced
by its value and each command between backquotes by its output, and
from which the double quotes have been removed. The characters which
must not be interpreted further, because they were quoted, carry the
quote bit, 0200, for the benefit of `split`, `expand`, and `trim`
(#f("sh/service.c"), #f("sh/expand.c")). The same machinery,
entered through `subst`, substitutes in the text of a here document.

The technique is to make the word the shell's input. `macro` pushes a
file block whose source is the string (`estabf`, #f("sh/io.c")), and
`getch` reads it with `readc`, as though it were being typed. A
parameter's name, a default value in braces, and a command in
backquotes are thus all read by the same means, at any depth of
nesting, and the result is built on the stack.

`quote` is either zero or `QUOTE`, according as a double quote is open,
and is or-ed into every character copied; `quoted` counts the double
quotes seen. The declarations of `getch`, `comsubst`, and `flush`
(15, 16) are new: they are `LOCAL` functions called before their
definitions, which C99 does not allow without a declaration.

#lines(1, 17)

`copyto` copies characters, substituted by `getch`, to the stack until
`endch` or the end of the input. It is used with `}` for the word of
`${name-word}`, and with a null to copy a whole string. v7 declared it
to return a `STRING`, though it returns nothing and no caller uses a
value; it is now `VOID`.

#lines(18, 28)

`skipto` passes over the word of a `${...}` that is not to be used,
without substituting it. It must still recognise quotes and nested
braces, so that a `}` within them does not end the word too soon.

#lines(29, 47)

`getch` returns the next character of the result. Any character other
than `$`, a backquote, or a double quote (`subchar`, #f("sh/ctype.h"))
is returned as it is. The single quote is not among them: `word` has
already set the quote bit on everything between single quotes, and such
characters fail every test of #f("sh/ctype.h").

#lines(48, 57)

A `$` begins a substitution only if the next character could begin a
parameter (`dolchar`); otherwise it is pushed back and the `$` is
returned (135). After an optional brace, there are three kinds of
parameter.

A name is collected on the stack and looked up. Since `lookup` may
allocate, which can move the stack (#f("sh/stak.h")), its start is kept
as an offset, `argp`, and turned back into an address by `absstak`.
v7 assigned the integer `relstak()` to the `STRING` `argp` directly;
the port casts it (70, 103). The character which ended the name is
pushed back into `peekc`, with `MARK` so that even a null is seen as
present (#f("sh/word.c")). The second semicolon on line 75 is v7's.

A digit names a positional parameter: `$0` is the name of the shell or
script, `cmdadr`, and `$1` to `$9` are taken from `dolv`, or are unset
beyond `dolc` (#f("sh/args.c")). `$*` and `$@` (the two characters of
`astchar`) are treated as `$1`, with `dolg` set so that the remaining
parameters will follow. In the conditional expression of line 82 v7
mixed a pointer and an integer, the value of `dolg=0`, in the two arms.
C99 requires a pointer in both arms unless the integer is a constant
zero, which an assignment is not; the cast to `STRING` is new.

The special parameters `$$`, `$!`, `$#`, `$?`, and `$-` are strings
kept up to date by the code which changes them (`assnum`,
#f("sh/name.c"); `options`, #f("sh/args.c")), so that substitution
needs no conversion.

`n` was initialised to `NIL` (61) in v7. `NIL` is `(char *)0`
(#f("sh/mode.h")), which C99 does not assign to a `NAMPTR`; it is now
zero. `v` is initialised (64) in the port. Every path assigns it or
leaves by `error`, but `error` is an ordinary function, not declared
to return never, and when the port began to compile with optimisation
GCC warned that `v` might be used unset. The parentheses around the
assignment to `bra` (68) mark it as intended.

#lines(58, 95)

Within braces, the name may be followed by `-`, `=`, `?`, or `+` and a
word (`defchar` also accepts the closing brace). The word is wanted if
the parameter is unset, except after `+`, where it is wanted only if
the parameter is set; the exclusive or of line 104 (`NEQ` is `^`,
#f("sh/mac.h")) expresses exactly this. A wanted word is copied, with
substitution, straight onto the stack at the place where the result is
being built, and so becomes part of the result without further ado;
`argp` remembers where it began. An unwanted word is skipped.

Without braces, the character after the parameter belongs to the text
and is pushed back.

#lines(96, 111)

If the parameter is set, its value is pushed, unless `+` has supplied a
word instead. For `$*` and `$@` the loop continues through every
positional parameter, with a space between each two. The two differ
only within double quotes, and only in that space: for `"$*"` it is
quoted, so that the whole is a single word, while for `"$@"` it is not,
so that `split` will divide the result into one word per parameter, the
characters of each parameter remaining quoted. This is the whole of the
difference between the two in v7. The parentheses at 114 are new.

If the parameter is unset, `?` prints the word, or a standard message,
and abandons the command by way of `failed`; `=` assigns the word to the
variable, which must therefore be a name and not a digit. For `-` the
copied word is already in place. An unset parameter with no word is an
error only under `set -u` (`setflg`).

Every substitution ends by going back to `retry`: the value has been
pushed directly, and `getch` returns the next character after it.

#lines(112, 136)

A backquote starts a command substitution. A double quote toggles
`quote` and is itself dropped, unless it is the character the caller
is looking for: `subst` makes use of this exception, below.

#lines(137, 145)

`macro` saves and restores `quote` and `quoted`, sets the word up as
input, and copies it whole with `copyto(0)`. A word which consisted of
double quotes and nothing more, such as `""`, would leave an empty
result, and `split` drops empty fields (#f("sh/service.c")). A single
`QUOTE` character is therefore pushed (161): it is not a separator, and
`trim` later reduces it to the empty string, so that the word survives
as an empty argument.

The input block is a `FILEHDR` rather than a `FILEBLK`, the same
structure without the buffer, which is all a string needs, since
`estabf` points the input directly at the string (#f("sh/mode.h")).
`push` takes a `FILE`, a pointer to a `fileblk`; v7 passed the address
of the `filehdr` as it was, and C99 requires the cast (156).

#lines(146, 164)

`comsubst` runs the command between backquotes and substitutes its
output. The part of the result built so far is first made a permanent
item with `fixstak`, and `savptr` remembers it. The text of the command
is read up to the closing backquote into a new item; `trim` removes the
quote bits which `word` set on its escaped characters; and the text is
pushed as a new input string.

#lines(165, 181)

The whole string is parsed by `cmd` (#f("sh/cmd.c")) and wrapped in a
fork node whose output is a pipe (`FPOU`). As the comment says, the pipe
is made only after the command has been parsed; a syntax error leaves by
a jump to the command loop, and in that case no descriptors are left
open. The input block, which held the string, is then pointed at the
reading end of the pipe (`initf`, #f("sh/io.c")). `execute`
(#f("sh/xec.c")) forks the child, which runs the command with its
standard output on the pipe, records its process id with `post`, and,
because of `FPOU`, returns at once. The shell closes its copy of the
writing end, without which it would never see the end of the output
(`readp`, #f("pipe.c")).

The parse tree, which lay on the stack above `savptr`, is no longer
needed in the shell and is discarded by `tdystak`; the partial result
saved at `savptr` is copied back into place as the current item, and
the output of the command is appended to it, a character at a time,
through `readc`. Only after the end of the output does the shell wait
for the child (`await`, #f("sh/service.c")). The order matters: a pipe
holds at most `PIPSIZ` bytes (#f("pipe.c")), and a child with more to
say would block forever if the shell waited for it first. Trailing
newlines are then removed from the result, and `pop` closes the pipe.

The parentheses at 195 are new.

#lines(182, 203)

`subst` copies a here document from the descriptor `in` to `ot`,
substituting parameters and commands (`initio`, #f("sh/service.c")).
It calls `getch` with `DQUOTE` as the character it wants, so that a
double quote is returned as an ordinary character and quoting is never
switched on: within a here document `$` and backquotes are
interpreted but double quotes are not. The quote bits are stripped
from the result, which is written in pieces of `CPYSIZ` bytes from the
stack. With `-x` the substituted text is shown on the diagnostic output
as well. The parentheses at 216 are new.

#lines(204, 231)
#source("/usr/src/cmd/sh/expand.c")

File name generation. `split` (#f("sh/service.c")) offers each field of
a substituted word to `expand`, which, if the field contains an
unquoted `*`, `?`, or `[`, replaces it by the names of the existing
files which match, and returns their number; if it returns zero, the
field stands for itself. `gmatch` does the matching, for `expand` and
for the patterns of `case` (#f("sh/xec.c")). In v7 the expansion of a
pattern is done by the shell; earlier systems left it to a separate
program, `/etc/glob`.

v7 has no library routine to read a directory. A program which wants
the names in one opens the directory and reads it as an ordinary file,
in entries of 16 bytes: an inode number and a name of at most 14
characters, not terminated by a null when it is 14 long (#f("dir.h")).
The shell defines `DIRSIZ` as 15 before it includes `sys/dir.h` (12),
whose `#ifndef` then leaves it alone, so that `entry` has a fifteenth
character after the name. The reads (79) fill only the first 16 bytes
of the structure; the fifteenth character, cleared once at line 42,
stays zero and terminates every name.

The declaration of `addg` (27) was `PROC`, that is `extern`, in v7; it
is now `LOCAL`, to agree with the definition, and has a prototype.

#lines(1, 28)

The field is first scanned for a metacharacter (`fngchar`,
#f("sh/ctype.h")). Quoted characters carry the quote bit and fail the
test, so a quoted `*` is never a pattern. A field without a
metacharacter is returned at once with zero, except in a recursive call
for the remainder of a pattern (`rflg`, below): there a remaining
component such as the `x` of `*/x` must still be looked up, so that
only names which exist are produced.

`trapnote&SIGSET` (40) means that an interrupt has arrived without a
trap; the expansion is abandoned, and `sigchk` will deal with it.

#lines(29, 54)

The pattern is divided at the last `/` before the first metacharacter:
`s` becomes the directory to search, `cs` the component to match.
The `/` is overwritten by a null, so that `s` is a string by itself, or
`s` becomes `/` if the pattern began there, or the empty string if the
pattern contained no `/` before the metacharacter. An empty name refers
to the current directory (`namei`, #f("nami.c")). The directory is
examined with `stat` and opened for reading.

The null which divided the two is then replaced by `0200` (71), a
character which is not a null but whose seven bits are zero, and `cs`
moves past it. The directory part thus remains distinguishable for
`addg`, which stops at it, while the word as a whole stays one string,
to be repaired at the end.

#lines(55, 71)

If the component is followed by further components, as in `*/*.c`, the
pattern is cut again at the next `/` (`rescan`), and the matches of
this level are collected on a chain of their own, `gchain` being set to
zero for the purpose.

The directory is read entry by entry. An entry with a zero inode number
is empty. A name beginning with `.` is matched only by a component
which itself begins with `.`; this keeps `.` and `..`, and the files
which users choose to hide, out of the expansion of `*`. Each name that
matches is added to the chain by `addg`. The cast of `&entry` to
`char *` (79) is new: `read` has a prototype (#f("sh/defs.h")), and C99
does not convert a pointer to a structure to a `char *` without a cast.

In the rescan case, each path just made, a directory name followed by
the rest of the pattern, is expanded in turn by a recursive call with
`rflg` set, and the results are added to the original chain `schain`.
The paths of the intermediate level are abandoned on the stack, to be
freed with the rest of the command. The count returned is that of the
final names.

#lines(72, 102)

The original word is repaired, every character whose seven bits are
zero becoming `/` again. `split` may yet use the word itself, when
nothing matched. The names are not sorted here; `scan` sorts each
group of names as it builds the argument list (#f("sh/service.c")).
The parentheses at 107 are new.

#lines(103, 111)

`gmatch` matches the string `s` against the pattern `p`, recursively,
one character of each at a time. It knows nothing of `/` or of a
leading `.`; `expand` applies it to one component at a time.

A character of the string whose seven bits are zero, the lone `QUOTE`
which `macro` leaves for an empty quoted word (#f("sh/macro.c")), is
made `0200`, so that it is not taken for the end of the string.

In a class `[...]`, a character matches itself and `a-z` matches the
range; `lc`, the previous character, starts at a value no character can
reach, so that a leading `-` matches nothing. Each character of the
pattern is compared with its quote bit stripped. The upper bound of a
range used not to be: in `[a-'c']`, the quoted `c` is `0343`, and on the
ARM, where `char` is unsigned, every character from `a` upward fell
within the range, while on the PDP-11, where it would have been
negative, none did. The port masks it with `STRIP` (133), like the
others. v7 has no negated class.

#lines(112, 138)

An ordinary character must equal the character of the string; quoted,
it still matches only itself, after `STRIP`. If it does, the case falls
into that of `?`, which matches any one character. The comment
`/* fallthrough */` (142) is new, and tells GCC that the fall is
intended. A `*` at the end of the pattern matches whatever remains;
elsewhere every suffix of the string, including the empty one, is tried
against the rest of the pattern. The end of the pattern matches only
the end of the string.

#lines(139, 157)

`addg` builds a new argument on the stack, leaving room for the link
before it (`argnod`, #f("sh/mode.h")): the directory part up to the
`0200` marker, with a `/` in its place; the matched name; and, if there
is a rescan, a `/` and the rest of the pattern. `makearg` puts it on
`gchain`. The cast of `endstak`'s result to `ARGPTR` (180) is new.

#lines(158, 181)

v7 declared the parameter of `makearg` as a `STRING` and applied
`->argnxt` to it, which its compiler allowed; it is now an `ARGPTR`.

#lines(182, 188)
#source("/usr/src/cmd/sh/args.c")

The options and the positional parameters. `options` interprets the
flags given to the shell on its command line (#f("sh/main.c")) or to
`set` (#f("sh/xec.c")). The positional parameters `$1`, `$2`, ... are
kept in a vector on the heap, `dolv`, of which `dolc` counts the
members after `$0`; a `for` loop without `in` iterates over this vector
while its body may replace it with `set`, and the use counts of this
file let the two coexist.

The declaration of `copyargs` (12) was `PROC`, that is `extern`, in v7;
it is now `LOCAL`, to agree with the definition, and has a prototype.

`flagchar` and `flagval` are parallel tables of the option letters and
their bits in `flags` (#f("sh/defs.h")). `flagadr` holds the string
`$-`, the letters of the options in force. It has room for all ten
letters and the null; v7 gave it ten bytes, so that with every option
set the null was stored one byte past its end.

#lines(1, 23)

If the first argument begins with `-`, each of its letters is looked up
in `flagchar` and its bit set. `-x` and `-v` are first cleared (36), so
that `set -` turns both off; no other option can be turned off once it
is on. `-c` takes the next argument as the command string, `comdiv`,
and only once (#f("sh/main.c")). Each argument consumed is removed by
moving `argv[0]` up one place over it (45, 49), so that the caller
finds `$0` followed by what is left, and the new count is returned. An
unknown letter is reported by `failed` (#f("sh/error.c")).

#lines(24, 50)

`$-` is then rebuilt from the flags.

#lines(51, 64)

`setargs` makes a vector of new positional parameters, from the
arguments of `set`, or from those of a command file run by
`execs` (#f("sh/service.c")). The old vector `dolh` is released first:
`freeargs` frees it only if no `for` loop is using it.

The end of an argument vector is a null pointer, `ENDARGS`, and
`Rcheat` (#f("sh/mode.h")) converts the pointer to an `int` for the
comparison, a habit of the shell's which costs nothing on a machine
whose pointers fit in an `int`.

The cast of `copyargs`' result to `DOLPTR` (76) is new; see below.

#lines(65, 78)

`freeargs` drops one reference to a parameter block and returns the
next block on the chain `argfor`. When the count reaches zero the
strings and the block are freed. The parentheses at 87 are new, and
the cast at 90 is explained below.

#lines(79, 96)

The vector of parameters is a `dolnod` (#f("sh/mode.h")): a link
`dolnxt`, a use count `doluse`, and then the strings themselves,
starting at `dolarg`. `dolarg` is declared as an array of one `char`,
a placeholder for the start of a variable-length array of `STRING`s;
since it follows two words, it is suitably aligned for pointers on both
machines. `copyargs` allocates the two words of the header, `n`
pointers, and one more word for `ENDARGS`, which accounts for the
`3*BYTESPERWORD`. Each string is copied with `make`. `dolv` is pointed
at the first string, so that `dolv[1]` is `$1`. The function returns
the address of the block as a `STRING *`, which is how `np` was
allocated.

v7 treated `np`, a `STRING *`, as a `DOLPTR` where it suited it,
writing `np->doluse` and `np->dolarg` and assigning the result to
`dolh`; its compiler allowed `->` on any pointer, and any pointer to be
assigned to any other. C99 allows neither, and the port casts between
the two types at each such place (76, 90, 100, 104, 105). The layout
is unchanged.

#lines(97, 112)

`clearup` is called after an error (`exitsh`, #f("sh/error.c")) and
before a command file is run (`execs`): it releases the parameter
blocks held by `for` loops which will never finish, and pops every
input file, closing their descriptors.

`useargs`, called by `for` (#f("sh/xec.c")), adds a reference to the
present parameters and links them on `argfor`. If the body of the loop
then does `set`, `setargs` replaces `dolh`, but the old block survives
with the loop's reference until the loop ends and calls `freeargs`.
The parentheses at 118 are new.

The test at 128 is new. A `for` without a list inside another such loop
finds `dolh` already at the head of `argfor`, and v7 set its `dolnxt`
to the block itself. The two loops then ended with `argfor` still
naming the block, and the next `clearup` freed the parameters in use,
since the count reached zero, and went on round the self-made chain for
ever: `set a b c`, a nested `for i do for j do :; done; done`, and then
any failing command, such as `cd /nonexistent`, hung the shell. Now
the block is linked only when it is not at the head already. The inner
loop's `freeargs` then leaves `argfor` at the block's successor, and
the outer loop's reference is merely not released by a `clearup`
during that loop, which can cost a block, never free one in use.

#lines(113, 132)
#source("/usr/src/cmd/sh/print.c")

The shell's output routines, and its conversions between numbers and
strings. The shell does not use the standard I/O library
(#f("stdio.h")), whose buffers and code it does not need; every message
is written directly with `write` to `output`, the shell's diagnostic
descriptor, a copy of descriptor 2 (#f("sh/main.c")).

`numbuf` holds the result of `itos`. `prp` begins a diagnostic: a shell
which does not prompt, because it is not interactive, names itself
(`cmdadr`, which is `$0`) before the message, so that the user can tell
which script failed.

#lines(1, 33)

`prs` writes a string. `length` (#f("sh/string.c")) counts the
terminating null, hence the `-1`. `prc` writes a single character, and
ignores a null. The parentheses at 39 are new.

#lines(34, 49)

`prt` prints a time given in ticks, for `times` (#f("sh/xec.c")),
rounded to the nearest second, as hours, minutes, and seconds. The
divisor 60 is the clock rate of v7's PDP-11, which `HZ` (#f("param.h"))
keeps on the ARM, so the figures remain correct. The parentheses at 59
are new.

#lines(50, 64)

`itos` converts a number to decimal, without leading zeros, by dividing
by powers of ten in turn, down to 10; `pr` turns true at the first
nonzero digit. The number is taken as unsigned (`POS`). On the PDP-11
an unsigned `int` stopped at 65535, and v7 began at 10000, with room in
`numbuf` for five digits and the null. On the ARM an `INT` has up to
ten digits, so the division begins at 1000000000 (77) and `numbuf` (12)
has room for ten and the null. With v7's figures a number of 100000 or
more put a character other than a digit in the first place: a syntax
error at line 100002 of a command file was reported at line `:0002`.

#lines(65, 83)

`stoi` converts a string of digits, for `exit`, `break`, and `trap`,
and for the descriptor in a redirection such as `>&2`
(#f("sh/service.c")). A string that does not begin with a digit is reported as a bad
number. The test `r>=0` is meant to stop the conversion when the
number overflows; it relies on the overflow wrapping to a negative
value, as it did on the PDP-11. In C99 the overflow of a signed
integer is undefined, and the test cannot be counted on.

`return(0)` (98) is new. `failed` never returns, but nothing tells the
compiler so (the port does not use GNU's `noreturn` attribute), and
without it control appears to reach the end of a function which returns
a value, of which GCC warns.

#lines(84, 99)
#source("/usr/src/cmd/sh/string.c")

Four string routines, used throughout the shell in place of those of
the C library.

`movstr` copies `a` to `b` and returns the address of the null it
stored, not of the start, so that copies may be chained, each
continuing where the last ended; `staknam` (#f("sh/name.c")) builds
`name=value` with three calls in a row. The parentheses at 18 are new.

#lines(1, 20)

`any` tells whether `c` occurs in `s`. When `split` (#f("sh/service.c"))
asks whether a character is one of `$IFS`, a quoted character still
carries the quote bit and so equals none of them: this is how a quoted
blank is kept within a word. The parentheses at 26 are new.

`cf` compares two strings and returns zero if they are equal, or the
difference of the first two characters that differ, whose sign gives
their order. It orders the variables' tree (`lookup`, #f("sh/name.c")),
and the generated file names (`gsort`, #f("sh/service.c")), and through
the macro `eq` (#f("sh/defs.h")) it serves every test of equality.
Since `char` was signed on the PDP-11 and is unsigned on the ARM, a
character with its top bit set sorted before all of ASCII there and
sorts after it here. Names of variables are ASCII, so only a file name
containing such a byte can show the difference.

#lines(21, 42)

`length` returns the size of a string including its terminating null,
which is the number of bytes needed to copy it (`make`,
#f("sh/name.c")), and one more than the number to write (`prs`,
#f("sh/print.c")). It returns zero for a null pointer. The parentheses
at 48 are new.

#lines(43, 50)

= The C Library

#source("/usr/include/stdio.h")

The standard input-output package is the part of the library which
nearly every command uses, and #f("stdio.h") is its interface. The
package interposes a buffer between the program and the system calls
`read` and `write` (#f("rdwri.c")), so that a program which takes or
gives one character at a time pays for a system call only once per
`BUFSIZ` characters. `BUFSIZ` (1) is 512, the size of a disk block, so
that a full buffer is one transfer for the buffer cache (#f("bio.c")).

A stream is an entry of the array `_iob`, of which there are `_NFILE`
(2), the same number as the open files a process may have (`NOFILE`,
#f("param.h")). Each entry holds a pointer to the next character in the
buffer (`_ptr`), a count (`_cnt`) of the characters which remain to be
read from the buffer or the room which remains for writing, the address
of the buffer (`_base`), the flags, and the file descriptor. The test
`ifndef FILE` (3) lets a program declare the structure in its own way;
none in this system does. The storage for `_iob` and for the buffers of
the standard input and output is in `data.c`, which initialises the first
three entries.

Note that `_flag` and `_file` are `char`. On the PDP-11 `char` was
signed and on the ARM it is unsigned, but neither field ever holds a
value above 0177, and the flags are confined to eight bits.

#lines(1, 11)

The flags. `_IOREAD` and `_IOWRT` record the direction; `_IORW` marks a
stream opened for both (mode `"r+"` and the like), on which the
direction is decided by the first operation and changed by `fseek`.
`_IONBF` means unbuffered, `_IOMYBUF` that the buffer was obtained from
`malloc` and must be freed, `_IOSTRG` that the "file" is a string in
memory (`sprintf` and `sscanf`), and `_IOEOF` and `_IOERR` record the
conditions which `feof` and `ferror` report.

`getc` and `putc` (29, 31) are the heart of the package. Each
decrements the count; while the count stays non-negative it simply
takes or stores a character at `_ptr`, and only when the buffer is
exhausted does it call `_filbuf` or `_flsbuf` (#f("stdio/filbuf.c"),
#f("stdio/flsbuf.c")) to refill or empty it. `getc` masks the character
with `0377`, so that a byte of 0377 is not mistaken for `EOF`; this was
essential with the PDP-11's signed `char` and is harmless with the ARM's
unsigned one. `putc` likewise yields the stored character as the
unsigned value of a `char`.

#lines(12, 35)

In v7 the header declared only the five functions which return
something other than an `int`, which K&R C assumed for anything
undeclared; every other function, and every system call, was simply
called. C99 forbids a call to an undeclared function, and the port is
compiled with `-Wstrict-prototypes` and `-Wmissing-prototypes`, so every
function must be declared with a prototype before it is used or
defined. v7 had no `unistd.h`, `stdlib.h`, or `string.h` in which such
declarations belong, and nearly every program includes #f("stdio.h"), so
the prototypes of the whole library are collected here: the stdio
functions, the system call stubs (`read`, `fork`, `kill`, and so on),
the string routines, `malloc` and its relatives, the time conversions,
and the rest. The declarations of `stat`, `times`, `ftime`, `gtty`, and
`stty` are instead kept beside their structures in their own headers,
and `signal` in `signal.h`.

The argument and result types are v7's own, not those of later
standards. `sprintf` (72) returns its first argument, a `char *`;
`malloc` (85) returns `char *` and takes an `unsigned`; `index` and
`rindex` (84) take the character as a `char`; `sleep` and `putw` (76)
return nothing, as their v7 definitions did. `ioctl` (56) takes a
`void *` because its callers pass a pointer to whichever structure the
request needs. `exit`, `_exit`, and `abort` (73) are declared as plain
`void` functions, since the `noreturn` attribute is not C99. The
variadic functions, `printf` and `scanf` and their relatives and `execl`
and `execlp` (68--72), are declared with `...`; their definitions use
`stdarg.h` (#f("stdio/printf.c")).

`environ` (99) is defined in #f("csu/crt0.s"); the declaration lets the
`exec` routines and `getenv` find it.

#lines(36, 99)
#source("/usr/src/libc/stdio/filbuf.c")

`_filbuf` is called by `getc` (#f("stdio.h")) when the buffer of an
input stream is empty. It refills the buffer with one `read` and
returns the first character, or `EOF`.

A stream opened for both reading and writing becomes a reading stream
(10). A stream not open for reading, or a string being read by
`sscanf` (whose end is its end), yields `EOF` at once.

If the stream has no buffer yet, one is provided. An unbuffered stream
is given a buffer of one character, its own byte of `smallbuf`, chosen
by the file descriptor; reads are then made one character at a time, so
that nothing beyond the character asked for is consumed (`getpass`,
#f("stdio/getpass.c"), relies on this). Otherwise a buffer of `BUFSIZ`
bytes is taken from `malloc` (#f("gen/malloc.c")) and `_IOMYBUF` set so
that `fclose` will free it; if there is no memory the stream quietly
becomes unbuffered. The standard input needs none of this, since
`data.c` gives it the static buffer `_sibuf`.

The `read` returns the number of bytes read, zero at the end of the
file, or -1 on error. The count is decremented at once (30) for the
character about to be returned, so the two failures arrive as -1 and
-2; the first sets `_IOEOF`, the second `_IOERR`. A read-write stream at
its end drops `_IOREAD`, so that the next `putc` may turn it round.

`fileno` yields the `char` `_file`, and GCC objects to a `char` used as
a subscript (`-Wchar-subscripts`, part of `-Wall`), since a signed
`char` could index before the array. The mask `0377` (19) is
the port's: it makes the index an `int` and non-negative whatever the
signedness of `char`, which the port does not leave to a compiler
option. The return (40) masks the character in the same way as `getc`.
v7's local declaration of `malloc` is gone, #f("stdio.h") now declaring
it.

#lines(1, 41)
#source("/usr/src/libc/stdio/flsbuf.c")

The output half of the package: `_flsbuf`, which `putc`
(#f("stdio.h")) calls when the buffer is full; `fflush`, which writes out
what has been collected; `_cleanup`, which `exit` calls; and `fclose`.

`_flsbuf` is entered with the character `c` that would not fit. A
read-write stream becomes a writing stream and forgets any end of file.
An unbuffered stream writes the character alone, with its count left at
zero so that every `putc` comes here again.

A stream without a buffer gets one at its first character. The
standard output is treated specially: if it is a terminal it is made
unbuffered, so that output appears as it is produced, and otherwise it
uses the static `_sobuf` of `data.c`. Other streams get `BUFSIZ` bytes
from `malloc`, or become unbuffered if there are none. With a buffer in
hand, whatever it holds is written (40--43), and `c` becomes the first
character of the emptied buffer, with room for `BUFSIZ`-1 more. Note
that the standard error is unbuffered from the start (`data.c`), so
that diagnostics are never held back.

`rn` is the number of bytes meant to be written and `n` the number
written; any difference is an error. `c1` (19) exists because `write`
needs the address of a byte, and `c` is an `int`.

#lines(1, 53)

`fflush` writes the contents of the buffer of a buffered output stream
and resets the pointer and count. It does nothing to an unbuffered
stream or to one being read.

#lines(54, 71)

`_cleanup` closes every stream, and so flushes every buffer, when the
program calls `exit` (`cuexit.c`, whose `exit` calls `_cleanup` and then
`_exit`). A program which ends with `_exit`, as a child of `fork` usually
should, leaves its buffers unwritten; a buffer inherited from the parent
would otherwise be written twice. `_cleanup` gains `void` in both its
return and its argument list, as the prototype requires.

#lines(72, 85)

`fclose` flushes and closes the file, then frees and forgets a buffer
obtained from `malloc`, and forgets the one-byte buffer of an
unbuffered stream. A static buffer, from `data.c` or `setbuf`, stays
attached for the next use of the stream. A string stream is
left alone, since it has no file. Finally every flag is cleared.

The cast (104) is new. The complement of all eight flags is the `int`
`~0377`, -256, and GCC, seeing that `_flag & -256` must be zero for any
`char` `_flag`, warns that the conversion back to `char` changes the
value (`-Woverflow`); with `-Werror` the warning is fatal. Casting the
mask to `char` makes it 0 before the `&=`, which states the same effect
without the conversion. An earlier version of the port cast the whole
expression; the present form keeps v7's `&=`.

#lines(86, 107)
#source("/usr/src/libc/stdio/fopen.c")

`fopen` opens the named file as a stream. It is split in two: `_findiop`
(`findiop.c`) finds a free entry of `_iob` (#f("stdio.h")), one with
none of `_IOREAD`, `_IOWRT`, and `_IORW` set, and `_endopen`
(#f("stdio/endopen.c")) opens the file and fills the entry in.
`freopen` shares `_endopen`, giving it the stream it has just closed
instead of a new one. If every entry is in use `_findiop` returns
`NULL`, which `_endopen` passes on.

v7's local declarations of `_findiop` and `_endopen` are gone;
#f("stdio.h") declares both.

#lines(1, 7)
#source("/usr/src/libc/stdio/endopen.c")

`_endopen` does the work of `fopen` and `freopen`
(#f("stdio/fopen.c")). The mode is a string: its first character is
`r`, `w`, or `a`, and a `+` after it asks for reading and writing both.
Mode `w` creates or truncates the file. Mode `a` opens it for writing,
creating it only if it does not exist (`ENOENT`), and seeks to its end;
the seek is made once, so a program which seeks elsewhere and writes
will not have its output appended. Mode `r` opens an existing file. The
`open` modes 0, 1, and 2 are read, write, and both (`open1`,
#f("sys2.c")).

Note that `errno` is examined (24) only after a failure, and that if
the second `create` fails too, `lseek` is applied to -1, fails
harmlessly, and the failure is reported below (38).

The stream is then set up: an empty buffer, the file descriptor, and
the direction. A buffer is not allocated here; the first `getc` or
`putc` does that (#f("stdio/filbuf.c"), #f("stdio/flsbuf.c")).

The static declaration of `create` (3) is new. `create` is defined
after its first use, which K&R C allowed by assuming an `int` function;
C99 requires a declaration first, and v7's `static` on the definition
must then be repeated on the declaration.

#lines(1, 52)

`create` makes the file with mode 0666, which the process's `umask`
reduces. `creat` opens the file only for writing, so a stream for mode
`w+` must close it and open it again for both.

#lines(53, 65)
#source("/usr/src/libc/stdio/fdopen.c")

`fdopen` makes a stream of a file descriptor which is already open,
typically one end of a pipe (`popen`, #f("stdio/popen.c")). As the
comment says, the system offers no way to ask how a descriptor was
opened, so the caller must state the mode again. Mode `a` seeks to the
end of the file before falling into the case for `w`.

The comment on the fall-through (28) has been reworded. GCC warns of a
`case` which runs into the next one (`-Wimplicit-fallthrough`, part of
`-Wextra`) unless a comment of a recognised form, such as
"fallthrough", marks it as intended; v7's "No break" is not one of
them. v7's local declaration of `_findiop` is gone, #f("stdio.h") now
declaring it.

#lines(1, 43)
#source("/usr/src/libc/stdio/setbuf.c")

`setbuf` gives a stream a buffer of the caller's, which must hold
`BUFSIZ` bytes, or makes the stream unbuffered if the buffer is `NULL`.
A buffer which the package had obtained from `malloc` is freed first.
The count is set to zero, so that the next `getc` or `putc` goes
through `_filbuf` or `_flsbuf`, which find the buffer in place and use
it. `setbuf` should be called before the stream is used; otherwise
characters already in the old buffer are lost.

#lines(1, 14)
#source("/usr/src/libc/stdio/doprnt.c")

`_doprnt` is the engine of `printf`, `fprintf`, and `sprintf`
(#f("stdio/printf.c"), #f("stdio/fprintf.c"), #f("stdio/sprintf.c")).
It interprets the format, takes the arguments one by one, converts each
into characters in a local buffer, and hands the result, with its
padding, to `_strout` (`strout.c`), which puts it on the stream with
`putc`.

In v7 this was not C at all but PDP-11 assembly, `doprnt.s`, with the
floating conversions in a second file `fltpr.s` (or `ffltpr.s`, which
merely printed `?`, for programs loaded without floating point). The
file here is a C replacement written for the port. It keeps v7's
conversions and their peculiarities, as listed below, and calls the
same helpers, `ecvt`, `fcvt`, and `gcvt` (#f("gen/ecvt.c")) for floating
point and `_strout` for output.

The great difference lies in how the arguments are found. On the PDP-11
every argument was pushed on the stack, the last first, so that they
lay in memory in order, each `int` or pointer one word, each `long` two,
and each `double` four. `printf(fmt, args)` was declared with one
argument after the format and passed `&args`, the address of the first
of the rest, and `doprnt.s` simply walked up the stack with
`(r4)+`, taking as many words as each conversion needed. On the ARM the
first four words of the arguments travel in `r0` to `r3`, and only the
rest on the stack, so the address of one argument says nothing about
where the next is. The callers are therefore declared with `...` and
use `stdarg.h`: `va_start` in a variadic function makes the compiler
spill the register arguments next to the stacked ones, and `va_arg`
fetches the next argument of a given type, observing the eight byte
alignment which the ARM procedure call standard gives to a `double` or
a `long long`. `_doprnt` receives a pointer to the caller's `va_list`
rather than a copy, because `gnum` also takes arguments from it, and C99
leaves a `va_list` indeterminate in a caller once a function to which
it was passed by value has used `va_arg` on it. The same interface lets
`awk`'s `error` pass its own arguments through.

v7's conversion `%r`, which took the next argument as the address of a
further format and argument list and continued from there, depended on
walking memory in exactly this way, and has no counterpart.

`gnum` reads a field width or precision: a decimal number, or `*`, which
takes the value from the argument list as v7's did.

#lines(1, 18)

The literal text up to the next `%` is passed to `_strout` in one
piece. `buf` must hold the longest conversion: a `%f` of the largest
`double`, about 1.8e308, needs 309 digits before the point, and the
precision is limited to 70 (103), so 400 bytes suffice. v7's buffer was
128 bytes, enough when the largest PDP-11 number was about 1.7e38.

#lines(19, 35)

A `-` asks for the result to be left-justified in its field; the
variable which records it is called `rjust`, after v7's assembly
variable of the same name and meaning. A leading `0` in the width asks
for zeros instead of spaces as padding. A precision is recorded with
`ndfnd` set, so that a precision of zero can be told from none.

In v7 a long argument was asked for by a capital letter, `%D`, `%O`,
`%X`, or `%U`, or by `l` (or `L`) before the lower-case letter; `%l`
followed by anything else meant `%u`, and the following character is
not consumed. All of this is kept (53--62). The distinction matters
less than it did: `int` and `long` are both 32 bits here, while on the
PDP-11 a `long` was two words of the argument list.

#lines(36, 62)

A signed conversion takes an `int` or a `long` and converts it to
`unsigned long`; if it was negative a `-` is stored and the magnitude
taken by unsigned negation, which is correct even for the most negative
value.

#lines(63, 74)

The unsigned conversions, and the common code for all integers. The
digits are generated backwards, from the least significant, into the
far end of `buf`, then copied forward to follow any sign. v7 printed
`%X` in lower case like `%x`, and so does this. A precision on an
integer has v7's meaning, not the later one: if it is nonzero, and so
is the number, a `0` is placed before the digits (88). The PDP-11 had
no instruction to divide a 32-bit number, so `doprnt.s` divided the two
words separately by a method it credits to Keith Davis; here `%` and
`/` on an `unsigned long` serve, and the Cortex-A7 divides in one
instruction.

#lines(75, 97)

The floating conversions take a `double`, the type to which a `float`
argument is always promoted. The precision, the number of digits after
the point, is 6 by default as in v7; it is limited to 70 for the sake
of `buf`. `%g` is wholly the business of `gcvt`.

`%e` asks `ecvt` for one digit more than the precision and lays them out
as a digit, the point, the rest, and the exponent. If the first digit
is `0` the value was zero, and the exponent is adjusted to print as
`+00`. The exponent of an IEEE `double` reaches 308, and is printed in
three digits from 100 up (127); `fltpr.s` had to provide only two,
since the PDP-11's exponent did not exceed 38.

`%f` asks `fcvt` for the given number of digits after the point. A value
below 1 begins with `0`. The digits before the point come from the
buffer, but `fcvt` returns no more than 79 digits in all, so a value of
1e80 or more runs out of digits; the tests of `*s` (137, 141) then
supply zeros in their place. A `double` carries only about seventeen
significant decimal digits, so nothing of value is lost.

#lines(98, 144)

`%c` stores the character unless it is the null character, as in v7. `%s`
takes the string, or `"(null)"` for a null pointer, which v7 also
printed, and uses at most the precision's worth of it. Neither is ever
padded with zeros. Note that for `%s` the result is not copied into
`buf`; `s` and `p` bracket the string itself.

#lines(145, 156)

Any other character is printed as itself, which is how `%%` prints a
percent sign. Then the padding is computed: `c` is the number of fill
characters, given to `_strout` as negative for padding on the left and
positive for padding on the right. `_strout` takes care that a minus
sign precedes the zeros of a zero-filled number.

#lines(157, 165)
#source("/usr/src/libc/stdio/printf.c")

`printf` formats its arguments on the standard output by way of
`_doprnt` (#f("stdio/doprnt.c")), and reports whether the stream has
suffered an error.

v7's `printf` was declared as taking one argument after the format,
`args`, and passed `&args` to `_doprnt`: on the PDP-11 the remaining
arguments followed `args` in memory, and the assembly `_doprnt` walked
along them. Under the ARM procedure call standard the first arguments
are in registers, and this no longer works. `printf` is therefore a
variadic function in the C99 manner. `va_start` (9) sets `args` to the
first argument after `fmt`, `_doprnt` is given its address so that
everything it takes with `va_arg` is taken from the one list, and
`va_end` (11) ends the use of the list, as C99 requires of every
`va_start`.

The declaration of `_doprnt` (3) is local to the files which call it,
as `_doprnt` is internal to the library and #f("stdio.h") does not
declare it; `stdarg.h` (2) is needed for the type `va_list`.

#lines(1, 13)
#source("/usr/src/libc/stdio/fprintf.c")

`fprintf` is `printf` (#f("stdio/printf.c")) with the stream given
explicitly. The changes from v7 are those made to `printf`: a variadic
definition, a `va_list` whose address is passed to `_doprnt`
(#f("stdio/doprnt.c")), and a local declaration of `_doprnt`.

#lines(1, 13)
#source("/usr/src/libc/stdio/sprintf.c")

`sprintf` formats into the string `str` instead of a file. It does so by
making a stream of the string: a `_iobuf` on its own stack whose pointer
addresses `str` and whose flags say that it is written (`_IOWRT`) and is
a string (`_IOSTRG`). `_doprnt` (#f("stdio/doprnt.c")) then writes on it
with `putc` like any other stream, and a final `putc` adds the null
character. The count of 32767, the largest `int` of the PDP-11, is
simply a number which no output is expected to reach; `putc` will call
`_flsbuf` only when it runs out, and the caller must in any case
provide a big enough string. The other fields of `_strbuf` are never
used and are left unset.

As in v7, `sprintf` returns `str`, not the number of characters, which
#f("stdio.h") declares accordingly. The changes from v7 are those made
to `printf` (#f("stdio/printf.c")): a variadic definition, a `va_list`
whose address is passed to `_doprnt`, and a local declaration of
`_doprnt`.

#lines(1, 18)
#source("/usr/src/libc/stdio/doscan.c")

`_doscan` is the engine of `scanf`, `fscanf`, and `sscanf`
(#f("stdio/scanf.c")), as `_doprnt` is of `printf`. It reads characters
from the stream as the format directs, converts them, and stores the
results through the pointers which follow the format. It returns the
number of items stored, or -1 if the input ended before anything could
be matched.

Unlike `_doprnt` the file was C in v7, so the port's changes are
modest. Three of them repair faults which v7 shared, and one replaces
the way the arguments were found.

`_sctab` (19) classifies characters: `SPC` marks the white space which
separates fields, and `STP` is set afresh for each `%[` conversion to
mark the characters which stop it. v7's table had 128 entries, but it
was indexed by the result of `getc`, which may be anything from 0 to
0377, and in `_getccl` by bytes of the format, which on the PDP-11
could be negative; input with the eighth bit set read beyond the table,
and a `%[` set with such characters wrote beyond it. The table now has
256 entries, one for each value of a byte. Only the first 64 are
written out; the rest are zero.

The prototypes (14--17) are new. `_doscan`, `_innum`, and `_instr` are
external, so `-Wmissing-prototypes` requires each to be declared before
its definition, and `_innum` calls `_instr`, defined after it. #f("stdio.h")
does not declare these internal routines.

#lines(1, 28)

The main loop. A `%` introduces a conversion, `%%` matches a percent
sign, white space in the format skips any amount of white space in the
input, and any other character must match the next input character
exactly, or the scan ends.

After the `%` comes an optional `*`, which suppresses the assignment,
then an optional field width, which defaults to 30000, in effect
unlimited; then `l` for long or `h` for short; then the conversion
letter. A capital letter means long, as in `printf`, so `%D` and `%E`
are `%ld` and `%le`. `%[` reads the character class at once with
`_getccl`.

In v7, `argp` was a pointer into the PDP-11 argument list, and `ptr` was
set at once to the address of the next argument (`ptr = argp++`), or to
0 if the assignment was suppressed; `_innum` then stored through it as
through a pointer to a pointer of the appropriate type, `**(float **)ptr`
and the like. Now `ptr` is set to `fmt` (48), which is used only as a
value known not to be null, to record that an argument is to be taken.

#lines(29, 72)

The argument itself is taken here (73--85), once the conversion letter
and the size are known, with `va_arg` and the type which the caller
really passed: `char *` for strings and characters, `float *` or
`double *` for the floating conversions, and `short *`, `int *`, or
`long *` for integers. The pointer is converted to `char *` for
`_innum`, which converts it back. Fetching every argument as an `int **`,
as v7 in effect did, is undefined in C99 (7.15.1.1), and so is storing a
`float` through an `int` object (6.5): under the ARM procedure call
standard all these pointers happen to be passed alike, but the compiler
is entitled to assume otherwise.

`_innum` handles every conversion, passing strings on to `_instr`. If
it stored something, and an argument was supplied for it, the count of
matches goes up. If the input ended, the scan ends.

#lines(73, 111)

`_innum` converts a number. The field width is first cut to 62
characters (124), since the characters of the field are copied into
`numbuf`, of 64 bytes, for `atof`; with v7's default width of 30000 a
long enough number overflowed the stack. 62 leaves room for an `e`
which may be added after the count is exhausted, and for the null
character. Leading white space is skipped, and a sign noted.

#lines(112, 148)

Digits are accumulated in `lcval` as they are read, by shifts for octal
and hexadecimal, and for decimal by `((lcval<<2) + lcval)<<1`, which
is ten times `lcval` without a multiplication, a saving on the PDP-11. A floating number is accumulated in the same way, uselessly,
but its characters are also kept in `numbuf`. A point is accepted only
in a floating conversion, and an exponent only after a digit has been
seen. The extra parentheses (151) state v7's precedence explicitly, to
satisfy `-Wparentheses`.

#lines(149, 184)

The character which ended the number is put back with `ungetc`, unless
it was `EOF`, which `*eofptr` reports. Nothing is stored if no
characters were taken or the assignment was suppressed. Otherwise the
value is stored according to the scale and size, now through a pointer
of the right type (199--215) rather than v7's double indirection. A
`float` is produced by converting the `double` from `atof`; v7's
declaration of `atof` has gone to #f("stdio.h").

#lines(185, 219)

`_instr` reads a string (`%s`), a character class (`%[`), or
characters (`%c`, by default one). A string first skips white space;
then it stops at white space, a class stops at a character marked `STP`,
and `%c` stops only when the count is exhausted. Only a `%c` is stored
without a null character. Note that `ptr` may be null for a suppressed
assignment, in which case the characters are read and discarded.

The first `getc` is masked with `0377` (236) for the enlarged table.
`EOF`, -1, then indexes entry 0377, which is harmless: the loop stops at
`EOF` in any case, and the second loop (244) tests for `EOF` before it
indexes the table.

#lines(220, 263)

`_getccl` builds the stop set for `%[`. A class beginning with `^`
names the characters which stop the scan; otherwise it names those which
do not. The loop sets or clears `STP` in all 256 entries, then flips it
for each character up to the `]`.

The loop at (280) has been rewritten. v7 masked the byte with `0177`
only for the comparison with `]` and indexed the table with the
unmasked, possibly negative, value; the byte is now taken with `0377`
once, and used as it is. v7 also stored each byte with `c++` and then
tested `c==0` for the end of the format, which therefore never succeeded
once it had been incremented, and an unterminated `%[abc` ran on past
the end of the format. The test is now made before the byte is entered,
and `_getccl` returns a pointer to the null character, at which
`_doscan` stops.

#lines(264, 289)
#source("/usr/src/libc/stdio/scanf.c")

The three entries to `_doscan` (#f("stdio/doscan.c")): `scanf` reads the
standard input, `fscanf` a given stream, and `sscanf` a string.

`sscanf` makes a stream of the string, as `sprintf` does
(#f("stdio/sprintf.c")), but for reading: `_IOREAD` and `_IOSTRG`, the
buffer and pointer at the string, and the count set to its length, so
that `getc` takes its characters in turn. When the count runs out,
`getc` calls `_filbuf`, which returns `EOF` at once for a string
(#f("stdio/filbuf.c")); `ungetc` can put a character back because the
buffer is the string itself.

In v7 each of the three was defined with a single argument `args`
after the format, whose address was passed on as that of the argument
list, since the PDP-11 laid the remaining arguments after it in memory. Each is now
a variadic function which hands `_doscan` the address of a `va_list`,
for the reasons given under `printf` (#f("stdio/printf.c")). Because
`va_end` must follow the scan, the result is kept in `r` and returned
afterwards. `_doscan` is declared locally (3), being internal to the
library.

#lines(1, 43)
#source("/usr/src/libc/gen/malloc.c")

The storage allocator of user programs. It should not be confused with
the kernel's `malloc` (#f("malloc.c")), which hands out clicks of core
and blocks of swap space from a resource map and keeps no record within
the space itself. This one manages a single arena of memory obtained
from the system with `sbrk`, which moves the end of the process's data
segment (`sbreak`, #f("sys1.c")), and keeps its bookkeeping inside the
arena, in a word before each block.

The file is v7's, with three repairs. It serves stdio for its buffers
(#f("stdio/filbuf.c")) and most commands which need tables of variable
size; the shell, which has an allocator of its own (#f("sh/blok.c")),
does not use it.

The debugging code (2--12, 172--189) is compiled only if `debug` is
defined, which it never is, and has been left in v7's K&R form. The
include of #f("stdio.h") (1) is new: it supplies the prototypes of
`malloc`, `free`, `realloc`, and `sbrk`, the last of which v7 declared
locally (deleted). It also defines `NULL` as 0, which line 44 then
defines again in the same words, as C99 allows.

`GRANULE` (14--19) is used only in the test at (99), where on the
PDP-11 it kept a margin of 64 words below the top of the 64 KB address
space when the arena grew; the comment does not say what the "break
bug" was. `pdp11` is not defined here, so the
margin is zero.

#lines(1, 19)

The comment describes the arena. It is a circular list of blocks, each
beginning with a pointer to the next; the size of a block is not
recorded but implied by the distance to its successor. Whether a block
is in use is recorded in the lowest bit of the pointer which begins it,
the `BUSY` bit, which `testbusy`, `setbusy`, and `clearbusy` examine and
change by converting the pointer to `INT`, here `int`, which on the ARM
is as wide as a pointer. Any gap in the arena, memory which `sbrk`
returned but which did not adjoin the arena's previous top, is made a
block permanently marked busy.

The arena is measured in units of `union store`, whose size `WORD` is
that of its largest member. On the PDP-11 this was two bytes; here it is
four, since the pointer and the `int` both take four. Every block
therefore starts on a four byte boundary, provided the arena does: the
static `allocs` is aligned for its pointer member, and the break, which
`sbrk` (`sbrk.s`) starts at the symbol `end`, lies on a word boundary
because the linker's script aligns `end` to four bytes. Since the two
low bits of every block's address are zero, the lowest is free to serve
as `BUSY`.

`ALIGN` and `NALIGN` exist so that an implementation may make `WORD`
larger, for the sake of a type with stricter alignment. The port leaves
them at `int` and 1, so a block returned by `malloc` is aligned to four
bytes only. The ARM procedure call standard asks for eight for a
`double`; but the instructions with which soft floating point code
loads and stores a `double` (`ldrd`, `strd`, `ldm`, and `stm`) require
only word alignment on the Cortex-A7, so a block of `double`s works.

`allocs` (54) is the initial arena of two words, `allocp` is the point
at which the next search starts, `alloct` is the last block, an empty
one whose pointer leads back to the first, and `allocx` holds a word
which `malloc` overwrote, for the benefit of `realloc`.

#lines(20, 58)

`malloc` first makes the initial arena on its first call: two blocks,
each pointing to the other and marked busy, so that the search has a
circle to travel round. A request of `nbytes` needs `nw` words: the
data rounded up to whole words, and one more for the pointer.

The test at (72) is new. `nw` is computed in `unsigned` arithmetic, and
a request near the largest `unsigned` wrapped round to a small number,
so that a huge request was given a tiny block; a request of two
gigabytes or more also reached `sbrk`, whose argument is an `int`, as a
negative increment. No request so large can be met in any case, and the
limit is chosen so that neither calculation can overflow below it.

#lines(59, 76)

The search, first-fit and circular, starts at `allocp`. At each free
block it first merges the free blocks which follow it (80--83); this is
the only place where free blocks are joined. If the merged block is
large enough, it is taken. The pointer `q` is always beyond `p` there,
since the search does not wrap within a merge.

`temp` counts the passes over the top of the arena; when it has passed
`alloct` twice without finding space, the arena must grow. It is a
static, for the reason given in its comment (64).

The test (84) was v7's `q>=p+nw && p+nw>=p`. The second half guarded
against `p+nw` passing the top of the PDP-11's address space and
wrapping to a small address; C leaves such an overflow undefined, and a
compiler may assume that it does not happen and discard the test. The
difference `q-p` of two pointers into the arena is computed instead,
which is defined and expresses the same thing.

#lines(77, 96)

To grow the arena, enough is asked for to satisfy the request, rounded
up to a multiple of `BLOCK` (1024 bytes), so that small requests do not
each cost a system call. The old top block is pointed at the new space,
and marked busy if the new space does not adjoin it, so that the gap is
never allocated; the last word of the new space becomes the new top,
pointing back to `allocs`. The search then resumes, and the merging step
joins the new space to any free block before it.

The test at (99) was v7's `q+temp+GRANULE < q`, a check that the new
top would not wrap round the end of the address space, which again
depends on pointer overflow. It is now made on the addresses converted
to `unsigned`, where wrapping is defined.

#lines(97, 112)

A block found to be large enough is split if it is larger than needed:
the remainder becomes a free block, and `allocp` is left at it so that
the next search starts there. Writing the remainder's pointer destroys
a word of the old contents of the block, which is kept in `allocx`. The
block taken is marked busy, and the address after its pointer word is
returned.

#lines(113, 122)

`free` clears the busy bit and nothing more. The block is not joined to
its neighbours here; that waits for the next search. Setting `allocp` to
the freed block makes the next `malloc` look there first, which suits a
program which frees what it has just allocated.

#lines(123, 137)

`realloc` changes the size of a block, moving it if necessary. It
honours a v7 promise which later allocators do not: the block may be one
freed since the last call of `malloc`. It frees the block if it is busy,
calls `malloc`, and copies the old contents if the result is elsewhere.
Since `free` changes nothing but the busy bit, the old contents survive
the call of `malloc`, with one exception: if `malloc` chose a block
starting below the old one and overlapping it, it may have split that
block and written a pointer into the old data; that word is restored
from `allocx` (167). The copy runs upwards, so that it is safe when the
new block lies below the old.

The parameter is now `char *ap`, as the prototype in #f("stdio.h") says,
and is converted to `p` (148); v7 declared the parameter itself as
`union store *`, which was possible only because nothing checked the
caller's argument against it.

The debugging routine `allock` follows.

#lines(138, 189)
#source("/usr/src/libc/gen/ctime.c")

The system keeps time as a single `long`, the number of seconds since
the beginning of 1970, Greenwich time: the kernel's `time`, advanced by
`clock` (#f("clock.c")) and read and set by the system calls `time`,
`stime`, and `ftime` (#f("sys4.c")). The routines here turn such a
number into a calendar date and a printable string. `date` and `ls -l`
are their best known users.

Since `long` is 32 bits on the ARM as on the PDP-11, and signed, the
count runs out early in 2038; nothing here can change that.

The comment's mention of a call to "the system" refers to `ftime`, which
returns, besides the time, the local time zone in minutes west of
Greenwich and a flag saying whether daylight saving time applies. Both
are constants compiled into the kernel, `TIMEZONE` and `DSTFLAG`
(#f("param.h")), so that every program on the machine agrees on them.
v7 was distributed for Eastern time, and so is the port.

#lines(1, 35)

`dmsize` gives the lengths of the months; February is changed to 29
temporarily by `gmtime` in a leap year. `daytab` records the two years
in which American daylight saving time followed emergency rules after
the oil crisis of 1973.

The braces around each entry of `daytab` (68, 69) are new: v7 relied on
the elision of braces in the initialiser of an array of structures,
which is legal C but draws `-Wmissing-braces`, part of `-Wall`.

v7 declared `gmtime`, `localtime`, `ctime`, and `asctime` here, and also
a `ct_num`, which was never defined or used. The public routines are
now declared, with prototypes, in #f("stdio.h"), which is included for
the purpose (40). `ct_numb` and `sunday` are used before they are
defined, so they need declarations of their own (72, 73), static like
the definitions.

`ctime` is simply the composition of the two routines below.

#lines(36, 79)

`localtime` subtracts the zone's offset from the time, breaks the result
into its parts with `gmtime`, and then decides whether daylight saving
time is in force: by default from 2 a.m. on the last Sunday in April to
1 a.m. on the last Sunday in October, which was the American rule from
1967 to 1986. If so, an hour is added and the parts computed again.
Since 2007 the American rule has been different, so the time printed
here is an hour wrong for some weeks of each year, in March and April
and around the start of November.

#lines(80, 110)

`sunday` finds the first Sunday on or after a given day of the year,
using the day of the week known for the current day. Days from the
end of February onwards (58) are moved one later in a leap year.

#lines(111, 123)

`gmtime` divides the time into days and seconds within the day,
correcting for a negative time, which is a moment before 1970. The
hours, minutes, and seconds are stored through `tp`, which walks the
first members of `struct tm` as though it were an array of `int`; this
depends on the members being consecutive `int`s, which they are on both
machines.

The day of the week is computed from the day count plus 7340036, a
number which is 4 more than a multiple of seven (1 January 1970 was a
Thursday, day 4) and large enough to keep the sum positive for any
day which a 32-bit time can express.

The year is found by subtracting the lengths of whole years. `dysize`
treats every fourth year as a leap year; this fails first in 2100, long
after the time itself has overflowed.

#lines(124, 184)

`asctime` produces the fixed format of 26 characters, newline and null
included. A template is copied into `cbuf`, and the names and the
numbers are written over it. `ct_numb` writes a number in two
character positions after skipping one; the hours, minutes, and
seconds are passed with 100 added, so that they keep a leading zero,
and the day of the month without, so that it gets a leading space.

The year is printed as its last two digits after the template's
`19`, which is changed to `20` (209--212) for a year of 2000 or later.
This provision is v7's own; with it `asctime` is correct until 2099.
The port's only change in this area is to `date`, whose parsing of a
two-digit year had no such provision.

The extra parentheses in the copy loop (193) tell the compiler that the
assignment in the condition is intended (`-Wparentheses`).

#lines(185, 236)
#source("/usr/src/libc/gen/atof.c")

`atof` converts a decimal number in characters, with an optional sign,
point, and exponent, to a `double`. `scanf` uses it for its floating
conversions (#f("stdio/doscan.c")), as do `awk`, `graph`, and `spline`.
Leading blanks are skipped, though not tabs; the conversion stops at the
first character which cannot continue the number.

#lines(1, 26)

The digits are accumulated as an integer in the `double` `fl`, the point
being remembered as a decimal exponent `exp`, which is decremented for
each digit after the point. Once `fl` reaches 2 to the power 56 (13), further
digits before the point only increment `exp`, and further digits after
it are ignored. The limit is the 56-bit fraction of the PDP-11's
`double`, the most digits it could hold exactly. The ARM's IEEE `double`
has a fraction of 53 bits, so digits accumulated between 2 to the
power 53 and 2 to the power 56 are rounded; the effect is confined to the last
bit or two of the result, and v7's constant has been kept.

#lines(27, 47)

The explicit exponent is added to `exp`. Its digits are accumulated
only while it is below 10000 (59), a test the port has added: v7 let
`eexp` grow without limit, and a long enough string of digits overflowed
the `int`, which C leaves undefined. Ten thousand is far beyond any
exponent which can make a difference, since the result is already zero
or infinite long before.

#lines(48, 72)

The scaling. Multiplying by a power of ten is done as multiplying by
the same power of five and then of two. The power of five is computed by
repeated squaring; the power of two is applied with `ldexp`, which only
changes the exponent of the `double` and is therefore exact. (`ldexp` is
`ldexp.c`, the port's C replacement for v7's PDP-11 assembly
`ldexp11.s`.)

A number whose magnitude is below 10 to the power -`LOGHUGE` becomes
zero at once (74). `LOGHUGE`, in `math.h`, was 39 on the PDP-11, whose
largest `double` was about 1.7e38; it is 308 for the IEEE `double`.

The test `fl == 0` (74) is new. A zero mantissa with a large exponent,
such as `0e500`, made `flexp` infinite, and zero times infinity is not
a number; such input now takes the path to zero directly. v7's PDP-11
had no infinities, and this case could not arise. The local declaration
of `ldexp` has gone, `math.h` now declaring it with a prototype.

#lines(73, 97)
#source("/usr/src/libc/gen/ecvt.c")

`ecvt` and `fcvt` convert a `double` to a string of decimal digits,
reporting the position of the decimal point in `*decpt` and the sign in
`*sign`, and leaving the placing of the point, the sign, and any
exponent to the caller. `ecvt` produces `ndigits` significant digits;
`fcvt` produces as many digits as are needed for `ndigits` of them to
follow the point. They serve `_doprnt` for `%e` and `%f`
(#f("stdio/doprnt.c")) and `gcvt` for `%g`. The result is in a static
buffer which the next call overwrites.

The includes and the static declaration of `cvt` (8--10) are new:
#f("stdio.h") holds the prototypes of `ecvt` and `fcvt`, and `math.h`
that of `modf`, which v7 declared locally; `cvt` is used before it is
defined.

#lines(1, 24)

`cvt` does the work for both, `eflag` telling them apart. The number of
digits is kept within the buffer of `NDIG` bytes, and the sign is
recorded and removed. `r2` will count the position of the decimal point.

#lines(25, 43)

The test at (44) is new. It replaces an infinity, or a NaN, which the
IEEE arithmetic of the ARM can produce and the PDP-11's could not, by
the largest finite `double`. Without it, the loop at (56) would never
end for an infinity, since dividing an infinity by ten leaves it
infinite.

`modf` splits the number into its integer part `fi` and its fraction.
The digits of the integer part are produced from the right by dividing
by ten and taking the remainder, `fj` being the fraction of `fi/10`; the
`.03` makes up for the inexactness of that fraction, which may fall
just short of a tenth of the digit. The digits are built backwards from
the end of `buf` and then moved to its start. A number below 1 instead
yields its leading zeros as a negative `r2`: it is multiplied by ten,
and `r2` decremented, as long as the product stays below 1.

The loop at (53--55) is new. The largest PDP-11 number, about 1.7e38,
had 39 digits before the point, and these always fitted in the 80 bytes
of `buf`. An IEEE `double` may have 309, and the digits, built
backwards from the end, ran off the front of the buffer for any number
of 1e80 or more. Numbers of 1e40 or more are therefore divided by
1e10 until they are smaller, `r2` counting ten places for each
division, and the fraction which the division leaves is discarded
(55). At most 40 digits are thus produced; the rest are lost, but a
`double` has only about seventeen significant decimal digits, and the
digits which follow are supplied as zeros by the fraction loop below
(the fraction of so large a number being zero) or by `_doprnt`.

#lines(44, 68)

`p1` marks the position one past the last digit wanted: `ndigits` from
the start for `ecvt`, `ndigits` past the point for `fcvt`. If that lies
before the start, as for a small number with too few places asked of
`fcvt`, the result is empty. Otherwise digits of the fraction are
produced, by repeated multiplication by ten, until there is one beyond
the last wanted, the buffer being full at worst; in the latter case the
result is returned unrounded, `NDIG`-1 digits long.

#lines(69, 85)

The extra digit rounds the result: 5 is added to it and the carry is
propagated leftwards. A carry out of the first digit, as when 9.99 is
rounded to two digits, makes that digit `1`, moves the point one place
right, and in `fcvt`'s case adds a digit at the end. The rounding digit
itself is then cut off by the null character.

#lines(86, 104)
#source("/usr/src/libc/gen/qsort.c")

`qsort` sorts an array of `n` elements of `es` bytes each, in place,
using the caller's function `fc` to compare two elements; `fc` returns a
negative number, zero, or a positive number as the first is less than,
equal to, or greater than the second. `ls`, `quot`, and `sa` are among
its users.

The comparison function and the element size are kept in statics, so
that the recursive `qs1` need not pass them on; `qsort` is therefore not
reentrant, which no program here requires.

The include of #f("stdio.h") (1), which declares `qsort`, and the
static declarations of the three helpers (2, 3), which are used before
they are defined, are new. The comparison function `qscmp` is now
declared with the types of its arguments (5), as #f("stdio.h") declares
`fc`.

#lines(1, 14)

`qs1` sorts the elements from `a` up to, but not including, `l`. It is
a quicksort which partitions three ways: elements less than the pivot,
elements equal to it, and elements greater. The equal elements gather
in a block from `lp` to `hp` in the middle, which takes no further part,
so that an array with many equal keys does not degrade the sort.

The pivot is the middle element. `n` is computed so that `a+n` is the
address of an element, not merely the middle byte.

`es` (19) is now `unsigned`. `n` is `unsigned`, and the comparison
`n <= es` (28) of an `unsigned` with an `int` draws `-Wsign-compare`
from GCC; both are unsigned now, which changes no result since `es` is
positive. v7's unused variable `k` has been deleted.

#lines(15, 33)

`i` moves up from the left and `j` down from the right. An element
found equal to the pivot block on either side is exchanged into it,
extending the block by one. An element less than the pivot stays where
it is on the left, and one greater on the right. When `i` has stopped
at a greater element and `j` at a lesser one, the two are exchanged. If
one side has run into the block while the other holds an element of the
wrong kind, `qstexc` rotates three elements: the misplaced element is
put on its proper side of the block, and the block moves one place
towards the side still being scanned.

#lines(34, 66)

When both scans have reached the block, the array is partitioned. The
smaller part is sorted by a recursive call and the larger by going back
to `start` with new bounds; recursion is thus confined to the smaller
part, so the depth of the stack grows only as the logarithm of `n`.

#lines(67, 83)

`qsexc` exchanges two elements and `qstexc` rotates three, a byte at a
time. Both now return `void`, as nothing uses a result.

#lines(84, 116)
#source("/usr/src/libc/gen/crypt.c")

`crypt` is the one-way function with which passwords are protected. The
password file (`/etc/passwd`) holds not the password but the result of
`crypt` applied to it; `login` (#f("cmd/login.c")) and `su` encrypt what
the user types and compare the results, and `passwd` stores the result
for a new password. The function is built on the Data Encryption
Standard (DES), which the file implements in full and also offers
directly as `setkey` and `encrypt`.

The implementation favours clarity over speed: every bit of the key, of
the block, and of the intermediate values occupies a `char` of its own,
holding 0 or 1, and every permutation of the standard is a loop over a
table of bit positions, numbered from 1 as in the standard.

The include of #f("stdio.h") (1), for the prototypes of `setkey`,
`encrypt`, and `crypt`, is new.

#lines(1, 35)

The tables for the key schedule. Of the 64 bits of a DES key, 56 are
used, in two halves `C` and `D` of 28 bits; the eight parity bits are
dropped by `PC1_C` and `PC1_D`. `KS` holds the sixteen 48-bit subkeys.

The initialiser of `PC1_D` (50) lacked its `=` in v7, a form left from
the earliest C which v7's compiler still accepted; C99 does not. Other
tables below had the same form and have had the same change.

#lines(36, 96)

`setkey` takes a key of 64 bits, one to a `char`, and computes the
sixteen subkeys: `C` and `D` are rotated left by one or two places for
each round, as `shifts` directs, and `PC2_C` and `PC2_D` select 48 of
their 56 bits.

#lines(97, 141)

The tables for the rounds. `E` expands the 32 bits of the right half to
48; it is a copy of `e`, because `crypt` alters it for each salt. `S`
holds the eight selection functions, each a table of 64 entries.

v7 declared `S` as `char S[8][64]` but initialised it with a single list
of 512 numbers, relying on the elision of the inner braces. That is
legal C, but draws `-Wmissing-braces`, part of `-Wall`, which `-Werror`
makes fatal. The table is now one-dimensional (163), and the index in
`encrypt` is computed as `j*64 + ...` (284) to match; the order of the
entries in memory, and so the result, is unchanged.

`L` and `R` are the two halves of the block. v7 declared them as two
arrays of 32, but `encrypt` indexes `L` with the positions of the
initial and final permutations, which run up to 64, and so assumed that
`R` followed `L` in memory. C makes no such promise, and once the port
was compiled with optimisation GCC's analysis reported the indexing as
out of bounds. `L` now has 64 entries, and `R` is defined as its second
half (223, 224).

#lines(142, 232)

`encrypt` enciphers the 64-bit block in place, or deciphers it if
`edflag` is nonzero, which only reverses the order in which the
subkeys are used. Each of the sixteen rounds computes a new right half
as the old left half exclusive-or a function of the old right half and
the subkey, and the old right half becomes the new left half. The
function expands the right half with `E`, adds the subkey, reduces each
group of six bits to four through a selection function, and permutes
the result with `P`. The comment at (278) explains the peculiar order
of the bits in the index of `S`.

#lines(233, 323)

`crypt` makes a key of the first eight characters of the password, seven
bits of each, the eighth position of each byte being left as the parity
bit which DES ignores. The salt, two characters of the 64 used in the
output (`.`, `/`, the digits, and the letters), gives twelve bits, each
of which, if set, exchanges two entries of `E`. The salt thus selects
one of 4096 variants of DES, so that the same password encrypts
differently for different users, and so that ordinary DES hardware
could not be used to search for passwords.

A block of zeros is enciphered 25 times with the key. The 64 bits of the
result, followed by two zero bits from the end of the 66 byte `block`,
make eleven characters of six bits each in the same alphabet, which
follow the two characters of the salt in the static `iobuf`: thirteen
characters in all, the form of every encrypted password in the password
file.

#lines(324, 380)
#source("/usr/src/libc/stdio/popen.c")

`popen` runs a command with its standard input or output connected to
the calling program by a pipe, and returns a stream for the other end;
`pclose` closes the stream and waits for the command to finish.

The mode is `"r"` if the caller will read the command's output, `"w"` if
it will write the command's input. `tst` (3) chooses between its two
arguments by the mode, and so decides which end of the pipe the caller
keeps (`myside`) and which the child gets (`hisside`). The child closes
the caller's end, moves its own end to descriptor 0 or 1 with `dup2`,
and executes the command through the shell, exactly as the shell would
for `sh -c`. `_exit` (24), not `exit`, ends a child whose `execl` fails,
so that the parent's stdio buffers, copied by `fork`, are not flushed a
second time.

`dup2` has no system call of its own: as in v7, the library's `dup2`
(`dup.s`) makes the call `dup` with 0100 added to the first descriptor,
and the kernel's `dup` (#f("sys3.c")) then takes the second argument as
the descriptor wanted, closing it first if it is open.

The terminating 0 of `execl`'s arguments (23) is an `int` where a
pointer is meant. On the ARM, as on the PDP-11, an `int` and a pointer
both occupy one word, and `execl` sees a null pointer. `execl` (`execl.s`)
is one of the few places where the PDP-11's way with arguments survives:
it pushes `r1` to `r3` just below any arguments which the caller
stacked, so that the arguments after the name lie in memory as a vector
ended by the 0, and hands the address of that vector to `exece`
(#f("sys1.c")) as `argv`.

The parent records the child's process id under the descriptor of its
end of the pipe, in `popen_pid`, which has one entry for each of the 20
descriptors a process may have (`NOFILE`, #f("param.h")).

#lines(1, 31)

`pclose` closes the stream, which sends an end of file to a command
reading from it, and waits for the child whose process id was recorded
for the descriptor. Other children which end meanwhile are reaped and
forgotten, as in `system` (#f("stdio/system.c")). Interrupt, quit, and
hangup are ignored during the wait, so that a signal meant for the
command, which shares the terminal, does not also kill the caller.

The three saved actions are now pointers to functions of one `int`
returning nothing (37), the type with which `signal.h` declares
`signal` (#f("sys/signal.s")); v7 declared them, together with `f` and
`r`, as pointers to functions returning `int`.

#lines(32, 53)
#source("/usr/src/libc/stdio/system.c")

`system` runs a command line through the shell and waits for it,
returning its status as `wait` reports it: the exit code shifted left
eight bits, or, if a signal ended the command, the signal's number in
the low byte. If the shell cannot be executed the child exits with
127.

The parent ignores interrupt and quit while it waits, so that a
character typed at the terminal to stop the command stops only the
command; the previous actions are restored afterwards. Any other child
which ends during the wait is collected and lost. Note that the signals
are ignored only after the `fork`, so the child has the caller's
actions, which the shell then adjusts for itself.

The include of #f("stdio.h") (1) is new: v7's `system.c` included only
`signal.h`, and called `fork`, `execl`, `_exit`, and `wait` without
declarations, which C99 does not allow. The saved actions are now
pointers to functions of one `int` returning nothing (8), the type of
handler which `signal` takes and returns (#f("sys/signal.s")); v7's were
pointers to functions returning `int`.

#lines(1, 23)
#source("/usr/src/libc/gen/execvp.c")

`execvp` and `execlp` are `execv` and `execl` with the search which the
shell makes for a command: if the name contains no `/`, each directory
named in the environment variable `PATH` is tried in turn. A file which
is not an executable program is taken to be a shell script and run with
`/bin/sh`. Programs which run other programs by name, such as `nice`,
`time`, and `find`, use these instead of duplicating the shell's
search.

The includes of #f("stdio.h") and `stdarg.h` (7, 8) are new: the first
declares `getenv`, `index`, `strlen`, `execv`, and `sleep`, which v7
called undeclared or declared here; the second is needed by `execlp`.
`execat` has a static declaration, since it is used before it is
defined, and `errno` (12) is declared `int` explicitly, C99 having no
implicit `int`. `NULL` is defined (6) before #f("stdio.h") is included, as in
v7; the header defines it again in the same way, which C99 permits.

#lines(1, 13)

`execlp` turns its arguments into a vector for `execvp`. v7's version
was a single line, `execvp(name, &argv)`: it named its first argument
after the name `argv` and passed its address, which on the PDP-11 was
the address of an array of all the arguments, laid out on the stack one
after another and ended by the caller's 0. Under the ARM procedure call
standard the first arguments arrive in registers, and the address of a
parameter is the address of a copy which the compiler has made
somewhere, with no promise about what follows it. An earlier version of
the port kept v7's line and worked only when the compiler happened to
spill the registers in order.

`execlp` now walks its arguments twice with `va_arg`: once to count them,
`n` starting at 2 for `arg0` and the terminating null pointer, and once
to copy them into `argv`, a variable length array, a C99 feature, on
the stack. The library's `execl` (`execl.s`) solves the same problem in
assembly, by pushing `r1` to `r3` beneath the stacked arguments so that
they form a vector after all; C offers no way to do that.

#lines(14, 35)

`execvp` takes the search path from the environment, or uses
`:/bin:/usr/bin`, whose empty first element stands for the current
directory. A name containing `/` is not searched for: `cp` is then the
empty string, and `execat` produces the name unchanged.

`fname`, the name being tried, was a fixed array of 128 bytes in v7, and
`execat` copied into it without a check, so that a long element of
`PATH` or a long name overflowed it. It is now a variable length array
(50) sized for the whole of `PATH` plus the name, a `/`, and the null
character, which is more than the longest element can need. Its
declaration had to move below the statements which find `pathstr`.

#lines(36, 51)

For each directory `execv` is tried, and returns only if it fails;
`errno` then tells why. `ENOEXEC` means the file exists and may be
executed but is not a program, so it is run as a script: `sh` is given
the file's name as its first argument, followed by the original
arguments after the zeroth, in `newargs`, whose 256 entries allow up to
254 arguments. `ETXTBSY`, a file being written while it is to be
executed, is retried up to four times, after sleeps of two, three,
four, and five seconds. `EACCES` is remembered, so that if no directory yields a
program the caller is told that a file was found but could not be
executed, rather than the error of the last directory tried. `ENOMEM`
and `E2BIG` will fail in every directory alike, and end the search.

The extra parentheses in the copying loop (60) tell the compiler that
the assignment is meant as the condition (`-Wparentheses`).

#lines(52, 84)

`execat` builds the name: the next element of the path, a `/` if the
element was not empty, and the name. It returns a pointer to the
element after, or 0 at the end of the path. An element ends at a `:`,
and also, for a reason the code does not record, at a `-`.

#lines(85, 100)
#source("/usr/src/libc/gen/setjmp.s")

`setjmp` and `longjmp` give C a non-local goto. `setjmp(env)` records
the state of the calling procedure in `env` and returns 0; a later
`longjmp(env, val)`, from any procedure called by it, however deeply,
abandons the procedures in between and makes that `setjmp` return a
second time, with the value `val`. `ed` and the shell (`error`,
#f("sh/error.c")) use the pair to return to the command loop after an
error, and `init` (#f("cmd/init.c")) to return to its main loop. They are
the user's counterpart of the kernel's `save` and `resume`
(#f("mch.s")), and the ARM versions are nearly the same code.

The file replaces v7's PDP-11 `setjmp.s`, which depended on the frame
conventions of the PDP-11 C compiler. There every procedure began by
calling `csv`, which pushed `r5`, the frame pointer, and the register
variables `r4` to `r2`, and ended by jumping to `cret`, which restored
them. v7's `setjmp` saved only three words: `r5`, the stack pointer, and
the return address, which is why `jmp_buf` (`setjmp.h`) was an array
of three `int`s. Its `longjmp` followed the chain of saved frame pointers
from its own frame back to the frame of `setjmp`'s caller, and then
returned through `cret` from the procedure that frame had called last, so
that `r2` to `r4` were restored from where that procedure had saved
them, with the values they had at that call. If the frame could not be
found it gave up, as its comment says, with `r2` to `r4` lost.

On the ARM no such chain exists: the code is compiled with `-Os`, which
keeps no frame pointer, and each procedure saves on its stack only the
registers it will itself use, in a layout known only to the compiler.
The ARM `setjmp` therefore saves outright everything which the ARM
procedure call standard requires a procedure to preserve for its
caller: `r4` to `r11`, the stack pointer, and the link register, which
holds the return address. It is the same set of ten words that `save`
stores in a `label_t` (#f("param.h")), and for the same reason. `r0` to
`r3` and `ip` may be destroyed by any call, so no caller of `setjmp`
expects them to survive it. There are no floating point registers to
save, since the programs are compiled for soft floating point.
`jmp_buf` now has ten `int`s to match.

`longjmp` reloads the ten words, which restores the stack pointer of
`setjmp`'s caller and discards every frame below it, and returns
through the saved link register as though from `setjmp`. The value is
`val`, unless that is 0, in which case it is 1, as in v7, so that the
caller can always tell the second return from the first; `movs` (10)
sets the condition codes as it copies, saving a separate comparison.

One consequence differs from v7. The registers are restored to their
values at the time of the `setjmp`, so a register variable of the
caller which changed between the `setjmp` and the `longjmp` reverts,
while a variable kept in memory does not. C leaves the value of such a
variable indeterminate after the `longjmp` unless it is declared
`volatile`, which allows both behaviours. Unlike `resume`, `longjmp`
changes no mapping: the process's address space is the same before
and after.

#lines(1, 12)

= Building the System

#source("/Makefile")

v7 was built on itself, by a collection of shell scripts and small
makefiles, one per directory: `conf/makefile` linked the kernel from
the archives `LIB1` and `LIB2` which the `mklib` scripts of `sys` and
`dev` had made; `compall` and `mklib` compiled and archived the C
library and the mathematical library; `cmake` compiled the commands
one at a time, each by its own line of shell, and the larger commands
(`sh`, `awk`, `dc`, and the rest) had makefiles of their own. None of
these is used. The port is built on another machine, by one `make`,
from this file and the fragments it includes: #f("sys.mk") for the
kernel, #f("libc/lib.mk"), #f("libm/lib.mk"), #f("cmd/cmd.mk"), and
#f("games/games.mk"). A single `make` sees the whole graph of
dependencies, so that a changed header recompiles exactly the files
which include it, a new `libc.a` relinks exactly the programs which use
it, a parallel build gives the same result as a serial one, and a
second `make` finds nothing to do. There is no compiler on the target
system; everything which runs there is compiled here.

The tools. `CROSS_COMPILE` is the prefix, in the manner of Linux's makefiles, of
the cross compiler for the target, a bare-metal ARM toolchain. `HOSTCC` compiles
the three programs which run during the build rather than on the
target: `mkconf` (#f("mkconf.c")), `mkfs` (#f("cmd/mkfs.c")), and the
`proc` of `awk` (#f("cmd/cmd.mk")). It too is an ARM compiler, for ARM
Linux; its programs are run on the build machine by user-mode
emulation. The reason is `mkfs`: compiled for the same processor as the
kernel, from the same headers, it lays out super-blocks, inodes, and
free lists exactly as the kernel will read them, with four-byte `long`s
stored least significant byte first, and no conversion is needed.
`flex` takes the place of v7's `lex`.

#lines(1, 6)

`W` is the set of warnings, shared by the target and the host programs.
Every file is compiled as strict C99 (`-std=c99 -Wpedantic`), and
`-Werror` makes every warning an error, so the build is free of
warnings or does not finish. The last three options insist on full
prototypes: no old-style definitions, no empty parameter lists, and no
external function without a prior declaration.

The flags for the target (`CFLAGS`). `-ffreestanding` tells the compiler
that there is no hosted C library behind the program. Among other
things it implies `-fno-builtin`, so that calls of `printf` or `strcpy`
remain calls of the port's own library rather than being replaced by
code the compiler supplies. `-nostdlib` keeps the
toolchain's own start-up file and libraries out of every link.
`-mcpu=cortex-a7 -marm` selects the processor of both boards, and the
ARM instruction set rather than Thumb. `-Os` optimizes for size; v7
compiled with `cc -O`, and the kernel's code shrinks from 61 KB to
38 KB, which matters on the MP135, where the whole kernel must fit in
128 KB of on-chip memory (#f("mp135/unix.ld")).

`-Wl,-N,-Ttext=0x10` are options for the linker, which the compiler
ignores when it only compiles; they apply to the link of every user
program (21), never to the kernel, which is linked by its own line in
#f("sys.mk"). `-N` makes a program one segment, text and data together,
writable and not aligned to a page: the ELF counterpart of v7's 0407
file, which `exec` (#f("sys1.c")) loads as a whole. `-Ttext=0x10` links
it at address `0x10`, leaving location 0 out of every program and
room for the signal trampoline at 8 (#f("seg.h")). `-MMD -MP` make the
compiler write, beside each object, a file of its header dependencies
(84).

`HOSTCFLAGS` link the host programs statically, so that the emulator
needs no ARM shared libraries, and keep the host library's `off_t` and
`time_t` at four bytes, the size of the port's own types, which
`mkfs` takes from the port's `<sys/types.h>`.

#lines(7, 15)

`T` and `Q` shorten the output. `T` prints the name of a tool and the
target in place of the whole command, and `Q` silences commands which
are only housekeeping; with `V=1` on the command line both are empty
and every command is shown. `COMPILE.c` and `COMPILE.s` are the
variables used by `make`'s built-in rules, so redefining them is enough
for every object in the tree to be compiled in place by those rules.

`LINK` links a user program from the objects and archives among its
prerequisites, in the order given there: `crt0.o` first, then the
program, then `libm.a` and `libc.a`. `-s` strips the symbol table, as
v7's `cc -s` did. `-lgcc` brings in the compiler's helper routines;
the programs are compiled for soft floating point, so every operation
on a `double` is such a call.

#lines(16, 21)

`all` is the default goal: the QEMU kernel and the root file system
image, and, after the fragments are read (31), the kernels of both
boards, whose names `KERNELS` only #f("sys.mk") supplies.

`GEN` collects the generated sources, among them the `c.c` and
`unix.ld` of each board and the output of `bison`. `.SECONDARY` keeps
`make` from deleting them as intermediate files once the objects are
made. Every object and generated file depends on the `Makefile`
itself (36), and on its own fragment as well, so that a change of flags
or of a rule remakes everything it could affect.

#lines(22, 36)

`bison` replaces v7's `yacc`. It is run as itself, not in its POSIX
mode, since the grammars use both v7's `%term` and some of `bison`'s
own declarations.

`boot/unix` is a copy of the QEMU kernel, which `make qemu` boots. QEMU
loads the ELF file at its link address and starts it at its entry,
`_start` (#f("low.s")); the disk is the root image, on a virtio block
device (#f("virtio_blk.c")), and the console is the board's UART on the
standard input and output.

#lines(37, 47)

The tree is built in place, and the programs are made where they will
lie in the target's file system: `bin/cat`, `etc/init`,
`usr/games/fortune`. The prototype file names them relative to the top
of the tree (#f("rootfs.proto")), and `mkfs` is run from there.
`ROOTFS_STATIC` lists the files of the image which are not compiled:
the shell scripts `1`, `true`, `false`, and `nohup`, the files of
#f("rc"), #f("ttys"), #f("passwd"), and #f("group"), and data such as
the dictionary, the fortunes, and `bc`'s library, all of which come
from the v7 tree (73).

The image is rebuilt whenever the kernel, `mkfs`, the prototype, or any
file in it changes. `V7_MKFS_TIME` gives `mkfs` the time to stamp on
every file and on the super-block: 284774400 seconds, 10 January 1979,
the date of the files on v7's own distribution tape. Two things depend
on it. The port once stamped every file with time zero, and `cron`, like
v7's, never reads a crontab dated zero, and then went on to use the
empty list it had not read; and the kernel takes its first idea of the
date from the super-block of the root file system (`iinit`,
#f("main.c")).

`mkfs` writes only the blocks which it uses. The image is then extended
to the end of the swap area, whose first block and length `awk` reads
from #f("qemuconf"), since QEMU will not read or write a block beyond
the end of the file.

#lines(48, 61)

`mkfs` must include the port's `<sys/param.h>`, `<sys/filsys.h>`, and
the rest, but the host's `<stdio.h>`, `<stdlib.h>`, and `<fcntl.h>`.
`-Iusr/include` would also bring in v7's `<stdio.h>`. Instead a
temporary directory is made, holding only a link named `sys` to
`usr/include/sys`, and put on the search path; `$$$$`, which reaches
the shell as `$$`, makes its name unique, and the `trap` removes it
however the compile ends.
Since `mkfs` is not one of the objects whose dependencies the compiler
records, its headers and the `Makefile` are named as prerequisites
explicitly: a `mkfs` built from stale headers would write a file system
which the kernel misreads.

#lines(62, 68)

The directories of the image which hold built programs or copied files,
and the copying of the files from the v7 tree. `etc` is left out: its
files are kept in the repository, where the image expects them. `cp -f`
replaces a previous copy, which is read-only like its original.

#lines(69, 74)

`.DELETE_ON_ERROR` removes a target whose command fails, so that a
half-written image or object is never taken for a finished one; `mkfs`
can therefore write the image in place.

The dependency files are read only for sources which still exist (84).
When a file in C is replaced by one in assembler, its old `.d` file
still names the `.c` file as a prerequisite of the object, and `make`
would otherwise stop for want of a rule to make it.

#lines(75, 84)
#source("/usr/sys/sys.mk")

#f("sys.mk") builds the kernels. It replaces v7's `conf/makefile` and
the two `mklib` scripts, and follows their plan: the files of `sys` are
archived as `LIB1`, those of `dev` as `LIB2`, and a kernel is linked
from the machine-language files and the configuration followed by the
two archives, so that only the procedures which something calls are
taken from them. As in v7, the objects are made by the compiler with
`-O` (here `-Os`) and the common `CFLAGS`; the kernel sources need no
search path, since they name their headers relative to themselves, as
`"../h/param.h"`.

`LIB1_OBJ` is every C file of `sys`. The drivers which belong to one
board only are kept out of `LIB2`: the UART and the disk of QEMU
(#f("pl011.c"), #f("virtio_blk.c")), and those of the MP135
(#f("stm32usart.c"), #f("stm32sd.c"), #f("stm32ddr.c")). The two sets
take the same v7 names, such as `klopen` and `rkstrategy`, and so could
not share one archive; each kernel is instead linked with its own
board's drivers (29, 30). `SYS_OBJ` names every kernel object, so that
the `Makefile` can make them all depend on itself.

v7's `conf/makefile` had a target `allsystems`, which ran `mkconf` and
`make` once for each of six configurations and renamed each `unix`
in turn. Here `BOARDS` lists the two configurations, and each kernel is
made in a directory of its own, `conf/qemu/unix` and `conf/mp135/unix`,
so that both are built by one `make`.

#lines(1, 12)

The archives are remade from scratch each time, since `ar rc` would
keep a member which had been deleted from the sources. v7's `mklib`
named the members one by one, in a fixed order; GNU `ar` writes an index
of the symbols, and the order no longer matters.

#lines(13, 18)

`mkconf` is a host program, built with the host compiler and the strict
flags. It is run, as in v7, in the directory which is to receive its
output, reading the configuration on its standard input; v7's
`conf` held one `c.c` at a time, which is why `allsystems` had to
build its kernels one after the other. A pattern rule with two targets
is made by one run of its recipe, which suits `mkconf`, since it writes
`c.c` and `unix.ld` together.

`c.c` lies one directory deeper than v7's, but `mkconf` still writes
v7's `#include "../h/param.h"`; the search path `-I$S/conf` (27) lets
`"../h/..."` be found from `conf`.

#lines(19, 28)

The link. In place of v7's `ld -X -i l.o mch.o c.o ../sys/LIB1
../dev/LIB2`, the compiler driver links `low.o`, `mch.o`, `c.o`, and
the board's drivers, then the two archives, with no start-up file or
library of the toolchain's (`-nostdlib`) and with the board's linker
script (#f("qemu/unix.ld")). `-i`, which gave the PDP-11 kernel separate
instruction and data spaces, has no meaning on the ARM, and `-X`, which
kept the local symbols, is not needed, since the GNU linker keeps them
unless told otherwise. The kernel is not stripped:
`ps`, `pstat`, and `iostat` look up the addresses of kernel variables
in the symbol table of `/unix`. `low.o` comes first, so that its
`_start` is the first instruction of the text, at the origin of `RAM`.

#lines(29, 32)
#source("/usr/src/libc/lib.mk")

#f("libc/lib.mk") builds the C library, `libc.a`, and the start-up file
`crt0.o` (#f("csu/crt0.s")), which every program is linked with first
but which is not a member of the library. It replaces v7's `compall`,
a list of `cc -c -O` commands, one per source file, and `mklib`, a
single `ar` command naming every object. Here the members are simply
all the C and assembler files of the library's four directories: the
top, which holds `syscall.s` (#f("libc/syscall.s")) and `memcpy.c`;
`gen`; `stdio`; and `sys`, the system call stubs, one per call as in
v7 (#f("sys/read.s")). `memcpy.c` has no v7 original. It defines
`memcpy` and `memset`, which GCC may call, even in freestanding code,
to copy or clear a structure. As in #f("sys.mk"), the archive is
remade from nothing, and its order does not matter.

The search path puts the port's `usr/include` ahead of the toolchain's
headers, so that `<stdio.h>` and the rest are v7's, while `<stdarg.h>`,
which v7 did not have, comes from the compiler.

#lines(1, 12)
#source("/usr/src/libm/lib.mk")

#f("libm/lib.mk") builds the mathematical library, `libm.a`, from every
C file of `libm`, in place of v7's `compall` and `mklib` for the same
directory. The functions are v7's, in C; v7's own `libm` already had no
assembler. Commands are linked with it before `libc.a`
(#f("cmd/cmd.mk")), since its functions call `frexp`, `ldexp`, and
`modf` from the C library.

#lines(1, 9)
#source("/usr/src/cmd/cmd.mk")

#f("cmd/cmd.mk") builds the commands. In v7 this was the work of
`cmake`, a shell script with a line for each command, giving its
compiler options and the directory in which it was installed, and of
the makefiles in the directories of the larger commands. Here the
single-file commands need no line each: every C or `yacc` file in
`cmd` is a command (6), and it is installed in `/bin` unless it is one
of those which v7's `cmake` put elsewhere. `CMD_ETC` and `CMD_USRLIB`
are those exceptions, `/etc` and `/usr/lib`. `CMD_DIRS` are the
commands of several files, each in a directory of its own.

`mkfs` is left out (6): it is compiled for the build machine by the
`Makefile` (#f("Makefile")), and the target has no copy. v7's `cmake`
also distinguished commands linked with `-n`, shared pure text, from
those linked with `-i`, separate instruction and data, which needed
the larger address space; every program here is linked the same way.

#lines(1, 9)

The objects. `awk` is listed by hand, because two of its objects come
from generated sources and one of its C files, `proc.c`, is not part of
`awk` at all. The other directories contribute all their C files.
`GEN` names the sources which `bison`, `flex`, and `awk`'s `proc` write.

#lines(10, 16)

Commands are compiled with v7's headers ahead of the toolchain's.

`YYSTACK_USE_ALLOCA` (20) is for the four parsers which `bison`
writes. With it, the parser grows its stack with the compiler's built-in
`alloca`; without it, it calls `malloc` and `free`, and, finding no
`<stdlib.h>`, declares them itself, with types which need not agree
with those of v7's library.

#lines(17, 20)

The links. Each command is linked from `crt0.o`, its own object, and the
libraries, by `LINK` (#f("Makefile")). The commands of `/bin` all get
`libm.a`, which only those calling its functions take anything from;
`graph` is one. A command's directory is an order-only prerequisite,
after the `|`: it must exist before the link, but its date, which
changes whenever a file is added to it, must not make every command in
it out of date.

#lines(21, 40)

`awk`. `bison` writes the parser and, with `--defines`, the header of
token numbers (`awk.h`), as v7's `yacc -d` wrote `y.tab.h`; the `&:`
says that one run makes both. `proc` is a program run during the build:
compiled with the token numbers of `awk.h`, it writes `proctab.c`, the table of the
procedures which evaluate each kind of node, as in v7. Being run here,
it is compiled by the host compiler, without v7's headers, with
`token.c`, whose table of token names it uses; both include `awk.h` and
`awk.def`, and are recompiled when either changes.

The lexical analyser is written by `flex` and edited on its way out by
`sed`. `flex` marks its `yy_fatal_error` as a function which never
returns, but the function ends with a call of `exit`, which v7's headers
do not declare in that way, and the compiler rejects the combination;
the attribute is dropped. The generated file includes `<string.h>` and
`<stdlib.h>`, which v7 did not have and which would bring in the
toolchain's declarations; `<stddef.h>` is included instead, for
`size_t`.

#lines(41, 50)
#source("/usr/src/games/games.mk")

#f("games/games.mk") builds the games, each from a single C file of
`usr/src/games`, and links them with the C library into `/usr/games`.
v7 had no script for them; its `games` directory held only the sources.
The games use v7's headers and nothing else from the tree, and none of
them needs `libm.a`. v7's `chess`, a directory of files partly in PDP-11 assembler, is not
among them.

#lines(1, 8)
#source("/usr/sys/conf/qemu/unix.ld")

#f("qemu/unix.ld") is the linker script for the QEMU kernel. It is
written by `mkconf` (#f("mkconf.c")) from the `ram` line of
#f("qemuconf"), in the pass which in v7 wrote `l.s`, and is used by the
link in #f("sys.mk").

v7 needed no script. Its kernel was linked with `ld -i`: instruction
and data in two separate spaces of 64 KB, each beginning at address
zero, with `l.s`, the interrupt vectors, at the bottom. The loader
defined `_etext`, `_edata`, and `_end`, and the start-up code in
`mch.s` used them to move the text to its resting place above the data
and to clear the memory from `_edata` to `_end`, before it turned on the
memory management unit. The ARM kernel is one image, linked at the
physical address at which it is loaded and runs, since the kernel's
mappings (#f("machdep.c")) make virtual addresses equal to physical
ones; there is nothing to move.

`MEMORY` declares the one region, `RAM`: the first 64 MB of QEMU's
memory, which begins at `0x40000000`. The kernel takes only its start;
process images are kept in the `core` above it (#f("qemuconf")), which
the linker is not told about.

`u` (5) is the per process data area, at `UBASE` (#f("param.h")): the
assignment defines the symbol which #f("user.h") declares, as v7's
`_u = 140000` did in `mch.s`. Its address lies outside `RAM`, in the
megabyte which `machine_init` (#f("machdep.c")) maps for it.

#lines(1, 5)

The kernel's text, read-only data, and initialised data follow one
another from the origin of `RAM`. The first input file is `low.o`
(#f("sys.mk")), so the first instruction is `_start` (#f("low.s")), at
`0x40000000`, where QEMU begins execution; no `ENTRY` is needed, since
`_start` is the linker's default.

`__bss_start` and `__bss_end` bound the uninitialised data, and play the
part of v7's `_edata` and `_end`: `_start` clears the memory between
them, a word at a time, before it calls any C. That is done with the
memory management unit off, when the processor faults on a store to an
unaligned word, hence the `ALIGN(4)`. `*(COMMON)` would collect
tentative definitions left as common symbols; GCC makes them only when
asked with `-fcommon`, which the port no longer uses, so it collects
nothing. `__bss_end` also tells `memaddr` (#f("machdep.c")) where the
kernel's memory ends, for `/dev/mem` and `/dev/kmem` (#f("mem.c")).

#lines(6, 14)

`.ddrbss` holds the translation tables reserved in #f("mch.s"): the
first level table, which the processor requires to lie on a 16 KB
boundary, and the two second level tables. `NOLOAD` makes it like
`.bss`: it occupies memory but nothing in the file. It is cleared, not
by `_start`, but by `machine_init` (#f("machdep.c")), between the
symbols `__ddrbss_start` and `__ddrbss_end`. On QEMU the distinction
serves nothing, and the section simply follows `.bss` in `RAM`; it
exists for the MP135 (#f("mp135/unix.ld")), where the tables lie in a
memory which cannot be written until `machine_init` has started it.

#lines(15, 20)
#source("/usr/sys/conf/mp135/unix.ld")

#f("mp135/unix.ld") is the MP135's linker script, written by `mkconf`
from #f("mp135conf"). It differs from #f("qemu/unix.ld") in its two
regions and in where it puts `.ddrbss`; `u` is defined in the same way.

`RAM` is the 128 KB of on-chip SYSRAM at `0x2ffe0000`, into which the
boot ROM loads the kernel. The text,
data, and `.bss` of the kernel must all fit there; the linker reports
an overflow of the region, so a kernel which has outgrown SYSRAM fails
to link rather than to boot. `TAB` is the external DDR memory at
`0xc0000000`, which holds the translation tables in `.ddrbss`, 18 KB
which SYSRAM cannot spare, at its very start; `core` begins 1 MB
higher (#f("mp135conf")).

Here the separation of `.ddrbss` from `.bss` matters. The DDR is dead
until `ddrinit` (#f("stm32ddr.c")) has started it, so `_start`
(#f("low.s")) may clear only `.bss`, in SYSRAM; `machine_init`
(#f("machdep.c")) clears `.ddrbss` after the DDR is running. `NOLOAD`
gives the section no contents in the file, so that nothing has to be
loaded into DDR before it is running.

#lines(1, 21)
#source("/usr/src/cmd/mkfs.c")

`mkfs` makes an empty file system, or, given a prototype file, one
already populated with directories, files, and special files. In v7 it
was an ordinary command, kept in `/etc`, which the administrator ran on
the PDP-11 against a disk partition. Here it never runs on the target:
it is compiled by the `Makefile` (#f("Makefile")) for the build
machine, where it writes the image of the root file system,
`boot/rootfs.img`, from #f("rootfs.proto"), taking the files from the
tree in which the system was built.

Since the image must be read by the ARM kernel, `mkfs` must lay out
every structure exactly as the kernel does. It does so by being compiled
by an ARM compiler, from the port's own headers, and run under
emulation: the super-block (#f("filsys.h")), the inodes (#f("ino.h")),
the free-list blocks (#f("fblk.h")), the directory entries
(#f("dir.h")), and the indirect blocks all come out with the ARM's
sizes, alignment, and byte order, without a line of conversion. The
changes from v7 are therefore few: those needed to compile it as a
program of the host, those of strict C99, the packing of block
addresses, a bigger limit on the size of a file, and the loss of the
bootstrap block.

`NIPB`, `NINDIR`, and `NDIRECT` are the numbers of inodes, block
addresses, and directory entries in a block: 8, 128, and 32. `MAXFILEBLK`
(9) is new: the largest number of blocks a file may have when ten are
addressed directly, 128 through the indirect block, and 128 times 128
through the double indirect block. `itoo` is the position of an inode in
its block, to go with the `itod` of #f("param.h").

The headers of the host's library (14--17) replace v7's `<a.out.h>`,
which was needed for the bootstrap; `<stdio.h>` too is the host's. The
headers of `<sys/...>` are the port's; the `Makefile` arranges for them
to be found without v7's `<stdio.h>`.

#lines(1, 24)

`ltol3` packs `n` block addresses, each held in a `long`, into three
bytes apiece, the form they take in an inode on the disk
(#f("ino.h")). v7 took it from the C library. That library is not
available to a program of the host, and v7's version was in any case
written for the PDP-11, which stores the high half of a `long` first:
it copied the bytes at offsets 0, 2, and 3 of the `long`. On the ARM
those would be bits 0 to 7, 16 to 23, and 24 to 31, and bits 8 to 15
would be lost. The private version takes the bits by shifting, least
significant byte first, which is the order in which `iexpand`
(#f("iget.c")) unpacks them. It is `static`, being defined before its
one use.

#lines(25, 34)

The global variables. `buf` is a scratch block. `fbuf` and `filsys` are
unions of a structure with a block-sized array, so that `wtfs` and
`rdfs`, which always transfer a whole block, never run off the end of
the structure. v7 then referred to the structure's members as though
they belonged to the union, as in `filsys.s_fsize`; early C compilers
allowed it, since member names were global, but C99 does not. The two
`#define`s (49, 55) turn every such use into a reference through the
member, `filsys.fs.s_fsize`, while the unions keep their v7 names: a
macro is not expanded again within its own expansion. v7's `struct exec
head`, the header of the bootstrap program, is gone with the bootstrap.

#lines(35, 69)

`main`. The time stamped on every file and on the super-block is taken
from the environment variable `V7_MKFS_TIME` if it is set, so that the
build gives the same image every time, and every file the date of the
v7 distribution (#f("Makefile")). `fsys` serves as a temporary for the
purpose before it receives its proper value.

The arguments are the file to be written and the prototype. Under
`STANDALONE`, never defined in this system, v7 could build `mkfs` as a
program for the bare machine, asking for its arguments on the console;
that code is kept but never compiled.

#lines(70, 122)

If the second argument is not a file which can be opened, it must be a
number, the size of an empty file system in blocks, with one inode for
every 25 blocks, up to the limit of 65500 inodes which a two-byte
`ino_t` allows. The casts here and below to `unsigned` compare an `int` or
a `long` with a value of type `size_t`, as the `sizeof` in `NIPB` makes it,
without the warning which `-Wextra` gives for such a comparison, and
which `-Werror` would make fatal. v7 printed a `long` with its own
`%D`; C99 spells it `%ld`. The second pair of parentheses around the
assignment in the test of the loop (125), here and in `getnum` (338),
tells the compiler that `=` is meant.

#lines(123, 142)

From a prototype, the first word names a bootstrap program. v7 copied
its text and data into block 0, which the PDP-11's boot ROMs read to
start the system. Here QEMU or the MP135's boot ROM loads the kernel
itself, and block 0 is never read; the prototype names `/dev/null`, and
the file is opened only to be closed again. The `else` and the blank
line which follow (153, 154) are what is left of v7's code around the
deleted lines, as is the comment, which has lost its second line.

The next two words are the size of the file system in blocks and the
number of inodes.

#lines(143, 167)

`s_m` and `s_n` describe the interleaving of the free list, three and
500 unless the command line says otherwise (see `bflist`). The i-list
is cleared, the free list built, the files made by `cfile`, and the
super-block written last, since `alloc` and `bfree` keep it up to date
as they go. In the message for a bad ratio, `s_isize - 2` is an `int`,
since `s_isize` is an `unsigned short`, and the format is corrected to
`%d`.

#lines(168, 201)

`cfile` makes one file, from the next entry of the prototype, and, if
the file is a directory, all the files within it, by calling itself.
The entry begins with the mode, as in `d--755`: the type, a `u` for
set-user-id, a `g` for set-group-id, and three octal digits; then the
owner and the group. The file is assembled in the kernel's in-core
inode structure (#f("inode.h")), which `mkfs` uses as a convenient
container.

`ib` holds the numbers of the file's blocks as they are allocated, and
now has room for `MAXFILEBLK` of them, not `NINDIR`. It lies on the
stack and takes 66 KB in every level of the recursion, which on the
host is of no consequence.

#lines(202, 253)

A regular file is copied from the named file a block at a time, each
block written as soon as it is full (`newblk`). A special file's
address field holds its major and minor device numbers. A directory
receives its entries `.` and `..`, and then one entry for each name up
to the `$` which ends it, each followed by the description of the file
to which it refers; the inode number in the entry is `ino+1`, the
number which `cfile` will give that file. The first call, with `par`
zero, makes the root, whose `..` is itself.

#lines(254, 313)

`gmode` translates a character of the mode by its position in `s`. v7
returned `(&m0)[i]`, taking the four arguments `m0` to `m3` to lie one
after another on the stack, as they did on the PDP-11. The ARM passes
the first four arguments of a call in registers and only the rest on
the stack, so the four are copied into an array (319).

#lines(314, 327)

`getnum` and `getstr` read a number and a word of the prototype; a `:`
begins a comment which runs to the end of the line.

#lines(328, 378)

`rdfs` and `wtfs` read and write block `bno` of the image, through the
host's `lseek`, `read`, and `write`. `rdfs` is now `static`: nothing
calls it before its definition, so it needs no separate declaration,
which `-Wmissing-prototypes` would demand of an external function.
`wtfs`, called first by `main`, is declared at (64). Its message (401)
had v7's `%D`, now `%ld`, which `rdfs` already used.

#lines(379, 404)

`alloc` and `bfree` take blocks from the free list and return them to it
exactly as the kernel's `alloc` and `free` do (#f("alloc.c")):
the super-block holds up to `NICFREE` free blocks, and when it is
exhausted or full, the list is read from or written to the block at
hand. `bfree` is `static` for the same reason as `rdfs`.

#lines(405, 441)

`entry` adds a directory entry to the directory's current block and,
when the block is full, writes it with `newblk`. `newblk` allocates and
writes a block of the current file, records its number in `ib`, and
clears the buffer. v7 reported "indirect block full" when `ib` held
`NINDIR` numbers; the limit is now `MAXFILEBLK`, but the message is
v7's.

#lines(442, 480)

`getch` reads the prototype, or, for an empty file system, the string
in `charp` which describes its root directory.

#lines(481, 493)

`bflist` builds the free list, and makes inode 1, which holds the bad
blocks of the disk; `badblk` reports none, so it is empty. The root is
therefore inode 2, as the kernel expects (`ROOTINO`, #f("param.h")).

The blocks are freed in an interleaved order: each group of `s_n`
blocks is freed in the order given by `adr`, which takes every
`s_m`-th block. Since the list is a stack, consecutive allocations then
fall `s_m` blocks apart, which on a rotating disk gave the processor
time to ask for the next block before it passed under the head. The
order is harmless on an SD card or a file. Block 0 is freed first and
so lies at the bottom of the stack, where `alloc` takes it as the sign
that no space is left.

The braces added around the inner `if` (537--548) only make explicit
that the `else` belongs to it, as it always did; without them GCC warns
of an ambiguous `else`.

#lines(494, 551)

`iput` writes a file's inode into the i-list. If the i-list is full, it
is the prototype's fault, and an error is reported. All three times are
the time of the build.

#lines(552, 580)

The block addresses. The first `LADDR` (ten) are copied into the inode.
If there are ten or more, an indirect block is allocated and written
straight from `ib`, starting at `ib[LADDR]`; a file of exactly ten
blocks, as in v7, thus gets an indirect block of zeros. v7 stopped
there: it moved the remaining numbers down to the start of `ib` and
wrote them, so no file could exceed `NINDIR` blocks, 64 KB. The kernel
itself, installed as `/unix`, and the dictionary are larger than that, so the
port adds a double indirect block (594--604): it allocates as many
indirect blocks as the file needs, each written from the next 128
entries of `ib`, and writes their numbers into a block of its own,
addressed by `i_addr[11]`. This is the layout the kernel's `bmap`
(#f("subr.c")) follows. The double indirect array `dbl` is cleared
first, so that the unused entries are zero.

The block addresses of all files, and the device numbers of special
files, are then packed into the disk inode by `ltol3`. The comment at
(605) tells GCC that the fall into the next case is intended, which it
would otherwise warn about.

#lines(581, 617)

`badblk` says that no block is bad; v7 left the parameter unused.

#lines(618, 625)
#source("/boot/rootfs.proto")

#f("rootfs.proto") is the prototype from which `mkfs` (#f("cmd/mkfs.c"))
makes the root file system, the only file system of the port. v7 was
distributed as an image of a whole disk; a site which made a new file
system from a prototype did so on the PDP-11 itself. Here the image is
made on the build machine, every time the system is built
(#f("Makefile")).

The format is v7's. The first word names the program to be written
into block 0 as a bootstrap: here `/dev/null`, since QEMU or the boot
ROM of the MP135 loads the kernel directly and block 0 is never read.
The second line gives the size of the file system, 10648 blocks of 512
bytes, a little over 5 MB, and the number of inodes, 2048, eight to a
block; `mkfs` gives the i-list blocks 2 to 258. The swap area follows on the same disk, from block
10648 (#f("qemuconf")). Then comes the root directory, described like
every other file: its mode, as `d--755`, its owner, and its group.

#lines(1, 3)

Within a directory, each line names an entry and describes the file:
the mode, the owner and the group, and, for a regular file, the file
on the build machine from which its contents are copied, relative to
the top of the tree. A `$` ends the directory. `mkfs` cannot make
links, so `[`, which `test` recognizes as its own
name, is a second copy of it. `1` is one of v7's shell scripts, like
`true`, `false`, and `nohup`; `osh` is the old shell.

Every file is owned by root but two in `/usr/adm`. A `u` in the second
place of a mode sets the set-user-id bit. It is given to the programs
which were set-user-id root in v7's distribution, because they must act
as the super-user whoever runs them: `login`, `mkdir`, `mv`, `newgrp`,
`passwd`, `rmdir`, and `su` here, and `atrun` in `/usr/lib`.

#lines(4, 111)

The special files. Each gives a type (`b` or `c`), and the major and
minor device numbers, which are v7's (#f("qemu/c.c")): the console is
character device 0, `mem`, `kmem`, and `null` are minor devices 0, 1,
and 2 of device 8 (#f("mem.c")), and `tty` is device 17. `mem` may be
read by anyone, as v7's `dmesg`, which is not set-user-id, requires:
`cron` runs it as `daemon` (#f("cmd/cron.c")). `root` and
`swap` are the same block device, the one disk, since the swap area lies
on it beyond the file system; `ps` reads `/dev/swap` for the images of
processes which are swapped out. There are no other terminals, so the
lines of `/etc/ttys` which name them are all disabled (#f("ttys")).

#lines(112, 120)

`/etc` holds the programs which v7 installed there, and its data:
#f("passwd"), #f("group"), #f("ttys"), the command file #f("rc"), and
`ddate`, an empty file in which `dump` records the dates of dumps.
`mtab` and `utmp` are not made here: `mount` writes the first when it
mounts something, and #f("rc") empties the second, creating it on the
first boot.

#lines(121, 137)

`/tmp` may be written by anyone. Under `/usr`, `adm` holds three empty
files. `messages` and `msgbuf` belong to `daemon`, so that `dmesg`, run
by `cron` as `daemon` every ten minutes (#f("cmd/cron.c")), can append the
kernel's new messages to the first and keep its copy of the message
buffer in the second; `/usr/adm` itself may be written only by root.
`wtmp` exists because `login` and `init` add their records to it only
if it exists; then the dictionary, the games and their fortunes, and the
programs and data of `/usr/lib`, among them `bc`'s library `lib.b` and
the table of `units`; and the spool directory of `at`, with the file in
which `atrun` keeps the time of its last run and the directory `past`
into which it moves each job while it runs. There is no `/usr/bin`.

#lines(138, 178)

`/unix` is the kernel built for QEMU. It is not booted from here, since
neither board loads its kernel from the file system; it is there for
its symbol table, which `ps`, `pstat`, and `iostat` read.

#lines(179, 180)
#source("/etc/rc")

#f("rc") is the command file which `init` (#f("cmd/init.c")) gives to
the shell when the system comes up, and waits for before it starts the
terminals. Its standard input, output, and error are the root
directory, opened for reading, so whatever is to be seen must be sent
to `/dev/console` explicitly, as the notice and the date are. It
removes the table of mounted file systems, since nothing is mounted
yet, and empties `/etc/utmp`, the record of who is logged in, creating
it on the first boot; it clears the temporary directories, and starts
`update` (#f("cmd/update.c")), which calls `sync` every thirty seconds,
and `cron` (#f("cmd/cron.c")). The line beginning with `:` is a comment,
as in v7, where accounting was likewise left off.

The file is v7's, less one line: v7 mounted `/usr` from a second disk
partition, `/dev/rp3`, of which this system has none. The lines for the
printer's lock and `/usr/tmp`, which do not exist here, are kept, since
they do no harm. Since nothing here creates `/etc/mtab`, the `rm`
complains on every boot that it does not exist; the complaint is lost,
since the standard error cannot be written.

#lines(1, 13)
#source("/etc/ttys")

#f("ttys") is v7's, unchanged. `init` (#f("cmd/init.c")) reads it to
learn which terminals to serve: on each line the first character is
`1` if a `getty` is to be run on the terminal and `0` if not, the
second chooses the table with which `getty` (#f("cmd/getty.c")) begins,
and the rest is the terminal's name in `/dev`. Only the console is
enabled, with table `4`, that of v7's console DECwriter. The 32 lines
`tty00` to `tty31` name the further terminal lines of a v7
installation; they are disabled here, and since the image has no such
special files (#f("rootfs.proto")), `init` would treat them as disabled
even if they were enabled. A line may be enabled while the system runs
by editing the file and sending `init` an interrupt, `kill -2 1`.

#lines(1, 33)
#source("/etc/passwd")

#f("passwd") is v7's, unchanged. Each line describes one user, in
fields separated by colons: the login name, the encrypted password, the
user and group ids, a comment, the home directory, and the program to
run in place of the shell, `/bin/sh` if the field is empty. `login`
(#f("cmd/login.c")) finds a user by `getpwnam`, which reads the file
through `getpwent` (#f("stdio/getpwent.c")), and compares the
encryption by `crypt` (#f("gen/crypt.c")) of what is typed with the
second field. `root` keeps the password of the v7 distribution.
`daemon`'s `x` is not a value `crypt` can produce, so no one can log in
by that name; the other users have no password. Of these, only `bin`
can in fact log in to this system. `login` refuses a user whose home
directory does not exist, and `/usr/sys`, `/usr/lib/uucp`, and
`/usr/dmr` are not in the image (#f("rootfs.proto")); `uucp`'s program,
`/usr/lib/uucico`, is missing as well.

#lines(1, 6)
#source("/etc/group")

#f("group") is v7's, unchanged. Each line names a group, gives its
password (none here), its group id, and the users who may join it with
`newgrp`. `ls -lg` and `find -group` read it themselves to translate
between names and numbers; `chgrp` and `newgrp` use `getgrnam` and its
companions from the C library. Note that
the users of #f("passwd") have group ids 1 to 4, so that `root` and
`daemon` belong to `other`; there is no group 0, though every file of
the image has group id 0 (#f("rootfs.proto")), and `ls -lg` therefore
shows those files' group as a number.

#lines(1, 4)

= Classic Programs

#source("/usr/src/cmd/ed.c")

`ed` is the editor of v7, and the program in this book in which its
authors' style of the early 1970s is best preserved: a single file of
global variables and short procedures, most of which communicate
through those globals, with `error` escaping from any depth by
`longjmp`. Three of its parts deserve study. The first is the
representation of the text: the lines are kept not in memory but in a
temporary file, and memory holds only an array of integers, one per
line, each giving where in that file its line lies. The second is the
reading and writing of that file through two buffers of one block
each. The third is the regular-expression code, `compile`, `execute`,
and `advance`, which was later lifted out of `ed` to make `grep`
(#f("cmd/grep.c")) and lives on, in one form or another, in most
programs which search text. The rest, the parsing of addresses and
commands, is straightforward, and is described only briefly.

The changes from v7 are C99 declarations, and the few others noted
fragment by fragment. Throughout the file, assignments used as
conditions, such as `while ((*p2++ = *p1++))` (150), have gained a
second pair of parentheses, which tell the compiler that `=` is meant.

`stdio.h` (8) is new. `ed` uses no standard I/O at all, but in the port
the header carries the prototypes of the system call stubs (#f("stdio.h")).
With it, v7's own `#define EOF -1` (deleted after 13) has gone, since
the header defines `EOF` with the same value. The `#define NULL 0` (9)
is v7's, and since it repeats the header's definition exactly, C allows
it to stand.

The codes `CBRA` to `CBACK` (17--25) are the instructions of the
compiled expressions, discussed with `compile`. `NBRA` limits an
expression to five `\(...\)` groups.

#lines(1, 28)

The state of the editor. `zero`, `dot`, and `dol` point into the array
of line pointers: `zero` at its start, an element which stands for the
nonexistent line 0, `dol` at the last line, and `dot` at the current
one. Line `n` is `zero[n]`. `addr1` and `addr2` are the addresses given
to the current command. `nlall` (89) is the number of elements
allocated, and is enlarged as the file grows.

`tfile` is the temporary file, `tline` the position in it at which the
next line will be written, and `ibuff` and `obuff` the two block
buffers, holding blocks `iblock` and `oblock`. `names` holds the marks
set by the `k` command, `globp` the text of a `g` command while it is
being executed, and `linebuf` the line being worked on.

`oldhup` and `oldquit` (54--55) are now pointers to `void` functions of
the signal number, which is what `signal` returns in the port
(#f("sys/signal.s")). The local declarations of `lseek`, `mktemp`,
`malloc`, and `realloc` have gone, since #f("stdio.h") declares them.
The prototypes (91--110) cover every procedure, since in this file
nearly every one is used before its definition.

#lines(29, 110)

`main` sets up the signals. The test of `SIGTERM` (120) installs
`quit` only if the signal was not already ignored; `SIG_DFL` is 0. The
tests at (157) and (159) are the same in another form: `SIG_IGN` is 1,
so the low bit of the old action is set only if the signal was being
ignored, as it is for a command run in the background. These casts
from a function pointer to `int` lose nothing on the ARM, whose
pointers and `int`s are both 32 bits.

A file named as an argument is read by placing `r` in `globp`, as
though it had been typed as the first command. The array of line
pointers is allocated, the temporary file named, and `setjmp` marks
the place to which `error` will return after each mistake. `quit` now
takes the signal number, being also a handler, and the direct call
passes 0. v7 declared the three handlers inside `main`, as functions
returning `int`; the prototypes above replace that declaration, and
`oldintr` (115) has the type of a handler.

#lines(111, 165)

`commands` is the main loop. It first collects up to two addresses,
separated by `,` or `;`. A `;` also sets `dot` to the first address,
so that the second is reckoned from it. When only one address is
given, both `addr1` and `addr2` are set to it. v7's local declaration
of `getfile` and `gettty` at the head of `commands` has gone, as the
prototypes cover them.

#lines(166, 194)

The commands themselves. Most call `setdot`, `setall`, `setnoaddr`, or
`nonzero` to supply default addresses or reject wrong ones, then
`newline` to check that nothing follows, and then do their work.

Five comments `/* fallthrough */` are new (213, 276, 293, 298, 341).
Each marks a case which, as in v7, runs on into the next; `-Wextra`
warns of such a fall-through unless it is marked. The one at (298)
follows a call of `quit`, which in fact never returns: it exits, or
reports an error and jumps back to `main`. The compiler is not told
this, and the comment satisfies it.

Some cases show the representation at work. A mark (260) records the
line pointer itself, not the line number, with its low bit cleared, so
that a mark follows its line however lines are added or deleted before
it; the search for a mark (466) compares pointers. `u` (329) undoes the
last substitution by putting back the line pointer which it replaced,
`subolda`; the old text is still in the temporary file, since nothing
there is ever overwritten. The mask `077777` at (371) is a relic of the
PDP-11's 16-bit `int`, and limits `=` to reporting 32767.

#lines(195, 387)

`address` parses one address: a number, `.`, `$`, a mark, or a pattern
between `/` or `?`, followed by any number of `+` and `-` offsets. A
pattern is compiled and the lines searched forwards or backwards from
`dot`, wrapping round at the ends, until a match is found or the search
returns to `dot`.

#lines(388, 484)

The address checks, and `newline`, which accepts a trailing `p` or `l`
to print the result. `filename` reads a file name after the command
letter, or supplies the remembered one, `savedfile`; the first name
given, or any given to `e` or `f`, is remembered.

#lines(485, 574)

`onintr` answers an interrupt with "?" by way of `error`, so that an
interrupted command is abandoned and the editor waits for the next.
`onhup` saves the buffer in `ed.hup` when the terminal hangs up.

`error` prints "?" and its argument, discards the rest of the input
line, and jumps back to `main`. The `lseek` of the standard input to
its end (623) matters when `ed` reads its commands from a file: one
mistake abandons the rest of the script, rather than running the
following commands on a buffer in an unknown state.

#lines(575, 638)

`getchr` reads one character, from `peekc` if a character has been
pushed back, from `globp` during a global command, and otherwise from
the standard input, one byte per `read`. Reading unbuffered is
deliberate: when `!` runs the shell, the shell reads its command from
the same input, and must find it there, not in `ed`'s buffer.

`gettty` reads a line of text for `a`, `i`, and `c`, ending at a line
holding only ".". `getfile` reads a line of a file, through `genbuf`.
Characters with the top bit set are refused, except that a buffer
containing them is first passed to `crblock` for decryption under `-x`.

#lines(639, 722)

`putfile` writes lines `addr1` to `addr2` to the file `io`, gathering
them in `genbuf` and encrypting each block first under `-x`. `count`
totals the characters, which `exfile` prints.

#lines(723, 762)

`append` adds lines after `a`, taking them one at a time from the
procedure `f` (`gettty`, `getfile`, `getsub`, or `getcopy`) until it
returns `EOF`. Each line is written to the temporary file by `putline`,
and its pointer is inserted after `dot` by moving the pointers above it
up by one.

When the array is full it is enlarged by 512 elements. The `free`
before `realloc` (775) relies on v7's `realloc` accepting a block freed
since the last `malloc` (#f("gen/malloc.c")), as `cron` and `diff` do
(#f("cmd/cron.c")). Since the array may move, `dot` and `dol` are
adjusted; any other pointer into it held by a caller is the caller's
problem, which `substitute` and `move` solve by comparing `zero` before
and after. The cast `(int)nlall` (772) is new: `nlall` is `unsigned`,
and the comparison with a signed difference of pointers draws a
warning from `-Wextra`.

#lines(763, 795)

`callunix` runs `sh -t`, which reads one line of input, the rest of the
`!` command, executes it, and exits. `savint` now has the type of a
signal handler, and `pid` is declared separately, since it is not a
function pointer. `quit` refuses to leave a modified buffer once,
unless `vflag` is clear; a second `q` succeeds.

#lines(796, 828)

`rdelete` removes the pointers of the deleted lines by moving the rest
down. The text stays in the temporary file. `gdelete`, used for the
common case `g/.../d`, compacts the array in one pass over the lines
marked by `global`, instead of one call of `rdelete`, and so one pass,
per line. It is now `static`, since nothing calls it before its
definition, and a static procedure needs no prototype.

#lines(829, 878)

Here is the representation of a line pointer. The temporary file is
written only at its end, and each line is stored there as a
null-terminated string. `tline` counts the file in units of two bytes,
and a line occupies a whole number of four-byte units (922), so that a
pointer is always even. Its low bit is free, and `global` uses it to
mark lines. Of the remaining bits, bits 1 to 7 give the offset within
a block of 512 bytes, in four-byte units, and bits 8 to 15 the block
number.

`getline` copies a line into `linebuf`, continuing at the start of the
next block (`tl += 0400`) when a line runs over the end of one.
`putline` stores `linebuf` at `tline` and returns its pointer; a
newline within the text, as a substitution can produce, ends the line
and leaves `linebp` at the rest, for `getsub` to collect.

These sixteen bits, and so a temporary file of at most 255 blocks, are
the PDP-11's limits. On the ARM `int` has 32 bits, but the masks at (922)
and (933) keep the arithmetic as it was, and `getblock` reports `TMP`
when the file would pass its 255th block (935).

#lines(879, 925)

`getblock` returns the address in a buffer of the byte at `atl`, and in
`nleft` the number of bytes from there to the end of the block. Two
buffers serve: `ibuff` for reading and `obuff` for writing. Since the
file is written only at its end, the block being written is always the
last, and `obuff` holds it until writing moves to a new block. Reading
may wander anywhere; `ibuff` is refilled as needed, written back first
if a write has gone into it (`ichanged`), which happens when the block
being read is also the one at the end. Under `-x` the temporary file is
encrypted too, with its own key.

v7 declared `read` and `write` here as external functions returning
`int`; they are now declared in #f("stdio.h"), with `char *` buffers,
which is the type of `iofcn` in `blkio`'s prototype, so that either may
be passed to it.

#lines(926, 983)

`init` empties the buffer: a fresh temporary file, created with mode
0600 and opened for reading and writing, `tline` at 2, no marks, and
empty buffers.

#lines(984, 1006)

`global` reads the command list of `g` or `v` into `globuf`, then marks,
in the low bit of each line pointer, the lines which match (or for `v`
do not). It then repeatedly finds the first marked line, clears its
mark, makes it `dot`, and runs `commands` with `globp` pointing at the
command list. When the list is exhausted, `getchr` returns `EOF`, and
`commands` returns (380). The search starts again from `zero` each
time, because the commands may have added, deleted, or moved lines;
the marks travel with the pointers.

#lines(1007, 1059)

`join` concatenates lines `addr1` to `addr2` in `genbuf`, writes the
result as a new line, and deletes the rest.

#lines(1060, 1082)

`substitute` applies `s` to each line in range which matches. `dosub`
builds the new line in `genbuf` from the part before the match, the
replacement, and the part after, and copies it back to `linebuf`. With
the `g` suffix, matching resumes after the previous match
(`execute(1, ...)`). The new line is written, its pointer replaces the
old one, and marks on the old line are moved to the new. If the
replacement contained escaped newlines, `putline` stopped at the first,
and `append` with `getsub` adds the remainder as further lines.

`compsub` reads the replacement. An escaped character is stored with
its top bit set, which is how `dosub` tells `\&` and `\1` from `&` and
`1`; `ed` refuses characters with the top bit set in its text, so the
bit is free for the purpose. The `&0377` at (1183), v7's, kept such a
character positive where `char` was signed. The local declaration of `getsub` has been
removed, as the prototype now precedes it.

#lines(1083, 1217)

`move` implements `m` and, with `cflag`, `t`, which first appends a
copy of the lines at the end of the buffer and then moves the copy. A
move of a block of line pointers to another place is a rotation of the
segment between them, done with three reversals in place: reversing
each part and then the whole leaves the two parts exchanged. No text
is copied, and no extra memory is needed. The local declaration of
`getcopy` has been removed.

#lines(1218, 1283)

`compile` translates a regular expression, read through `getchr` up to
the delimiter `aeof`, into `expbuf`. An empty expression reuses the
previous one. Each item becomes a code followed by its operand, if any:
`CCHR` with the character; `CDOT` alone; `CCL` or `NCCL` with a class;
`CBRA` and `CKET` with the number of a group; and `CBACK` with the
number of the group referred to. `$` is `CDOL` only at the end; `^` sets `circfl` only at the start.

`lastep` is the address of the last item compiled, so that a `*` can
be applied to it after the fact, by setting `STAR` in its code. The
codes of items which may be starred are even, so that the closure of
each has the odd code next above it.

A class is stored as its count, followed by the characters
themselves. A range `a-z` is expanded into every character between its
ends. `grep` stores a class as a bit map instead (#f("cmd/grep.c")).

#lines(1284, 1413)

`execute` tries the compiled expression on line `addr`, or, when `gf`
is set, on the rest of the current line after the previous match, for
the `g` suffix of `s`. `loc1` and `loc2` receive the beginning and end
of the match. `locs` records where the resumed search started, so that
a closure cannot match an empty string there a second time and repeat
the substitution forever. As in `grep`, if the expression begins with
a literal character, `advance` is tried only where that character
occurs.

The masks `&0377` (1420, 1421) are new: `c` is a `char`, and a
subscript of that type draws a warning from `-Wall`.

#lines(1414, 1464)

`advance` is the matcher. It walks the compiled expression and the line
together, each code testing and consuming characters, and returns 1 at
`CEOF`, leaving `loc2` at the end of the match. A closure first takes as
many characters as will match (`CCHR|STAR` and the others), and then,
at `star`, gives them back one at a time, calling `advance`
recursively on the rest of the expression from each point, until the
rest matches or nothing is left to give back. The match found is
therefore the leftmost, and the longest which allows the rest to
match. This backtracking is the whole of the algorithm, and it is what
`grep` copied.

A closure of a back reference (1523) gives back whole copies of the
group. If no number of copies will do, the match fails (1534), as in
`grep`'s copy of the case. v7 had `continue` here, which went on
matching the rest of the expression from `lp`, by then before the point
where the closure began, so that `/\(ab\)\1*a/` matched the line `ab`.

The masks `&0377` (1507, 1511) are new, for the same reason as in
`execute`.

#lines(1465, 1571)

`backref` compares the text of a group with the line. `cclass` searches
a class's list for a character; the null at the end of the line matches
no class, negated or not.

#lines(1572, 1597)

The output routines. `putchr` collects characters in `line` and writes
it when a newline arrives or 64 characters have gathered. Under `l` it
shows a tab as `>` struck over `-`, a backspace as `<` struck over `-`,
and other control characters as a backslash and two octal digits, and
folds long lines.

`ed` defines its own `puts`, which takes the place of the library's;
it now returns `int` with the value 0, to agree with the declaration of
`puts` in #f("stdio.h"). v7's returned nothing.

#lines(1598, 1666)

The encryption of `-x` and `x`. The key is read with echo turned off
(`getkey`), and passed with two characters of salt to
`/usr/lib/makekey`, which turns it into 13 characters by way of the
password-encryption routine of #f("gen/crypt.c"). `crinit` derives from
them three permutations of the 256 byte values, the tables of a rotor
machine: a scrambler `t1`, its inverse `t2`, and a self-inverse
reflector `t3`. `crblock` passes each byte through the scrambler, the
reflector, and back through the inverse, with the rotor positions
`n1` and `n2` stepping on with each byte of the file like the wheels
of a counter, so that
encryption and decryption are the same operation. This is the cipher
of the `crypt` command. For the temporary file, `makekey` at the end
mixes the time and the process id into the key, so that each session's
file is encrypted differently.

The signal handler pointer in `getkey` (1699) has the new type of a
handler.

#lines(1667, 1803)
#source("/usr/src/cmd/grep.c")

`grep` prints the lines of its files which match a regular expression.
Its name is the editor's command `g/re/p`, and its regular-expression
code is the editor's (#f("cmd/ed.c")), lifted out and adapted to a
program which reads a string from its argument list instead of a
terminal, and which needs to know only whether a line matches, not
where. The reader who has followed `compile`, `execute`, and `advance`
in `ed` will find the same three procedures here, with the same codes
and the same recursive treatment of the closure `*`. The differences
are noted below as they occur.

The whole file is v7's apart from C99 declarations and the masks
discussed below. The `&0377` masks on subscripts of type `char`
(122, 364--386) are new: such a subscript draws a warning from `-Wall`,
and the mask makes it an `int`. On the PDP-11, where `char` was signed,
v7's `islower(*p)` (122) would have indexed the character table with a
negative number for a byte with the top bit set; on the ARM `char` is
unsigned and the masks change no value.

#lines(1, 58)

The codes (14--22) are `ed`'s, with one difference: `CBACK` is 18
where `ed` has 14. `STAR` is or'ed into a code to mark a closure; the
codes of the items which may be starred are even, so that each closure
has the odd code next above its item's.
`NCCL` (18) is defined but never used, since a negated class is
compiled as an ordinary class with its bits inverted.

The buffers are larger than `ed`'s: `ESIZE` 256 against 128, and nine
bracketed subexpressions (`NBRA`) against five. `bittab` gives the bit
for each of the eight positions within a byte.

`main` collects the flags. With `-y`, each lower-case letter outside
brackets is replaced by a class matching both cases, so that `abc`
becomes `[Aa][Bb][Cc]`; text within brackets is copied as it stands.
The exit status is 0 if anything matched, 1 if nothing did, and 2 for
an error.

#lines(59, 147)

`compile` translates the pattern into `expbuf`. As in `ed`, `lastep`
remembers the start of the last item compiled, so that a following
`*` can set `STAR` in its code; a `*` at the start, or after `\(` or
`\)`, is an ordinary character. A `^` is recognized only at the start
(166), and sets `circf`; a `$` only at the end (192). `ed` reads the
pattern a character at a time through `getchr` up to a delimiter, and
an empty pattern there means "the previous one"; `grep` simply takes a
string ending in a null.

#lines(148, 196)

Character classes are where the two programs part company. `ed`
stores a class as a count followed by the characters themselves,
expanding a range such as `a-z` into all its members, and `cclass`
searches the list for each character of the line. `grep` stores a map
of 16 bytes, one bit for each of the 128 seven-bit characters, so that
testing a character costs one index and one mask (357--358), and a
range costs no more space than a single character. A negated class has
every bit inverted, except the bit for the null byte (220), which must
never match: it marks the end of the line.

The masks `&0177` in (211) and (215) are new. Each character of the
class set the bit `c`, and a character with its top bit set would have
set a bit beyond the 16 bytes, in whatever followed in `expbuf`. The
matcher looks only at the low seven bits of each character of the line
(357), so the compiler now does the same with the members of a class
and the ends of a range.

#lines(197, 226)

Parentheses `\(` and `\)` compile to `CBRA` and `CKET` with the number
of the subexpression; `\1` to `\9` to `CBACK`. Unlike `ed`, `grep`
checks at compile time that at least that many subexpressions have
been closed (`closed`, 248). Any other escaped character stands for itself.

The `goto defchar` (254) is new. v7 fell through from the escape case
into the default case below; the jump says so explicitly, which
`-Wextra`'s warning about implicit fall-through demands.

#lines(227, 265)

`execute` reads each line into `linebuf` and tries the expression at
each position in turn. A line longer than the buffer is cut, and its
remainder is read as the next line. With `circf` the match is tried
only at the start; if the expression begins with a literal character,
`advance` is called only where that character occurs. This is `ed`'s
`execute` without the bookkeeping: `ed` must record in `loc1` and
`loc2` where the match lies, for the substitute command, and carries a
flag for matches resumed in the middle of a line.

#lines(266, 327)

`advance` matches the expression at `ep` against the line at `lp`,
returning 1 for a match. Each code consumes one character or tests a
position. `CEOF`, the end of the expression, is success whatever
remains of the line, since a match need not extend to its end.

#lines(328, 362)

`CBRA` and `CKET` record where a subexpression began and ended, and
`CBACK` compares the text so recorded with the line. A back reference
under `*` matches the text as many times as it can, then gives back one
copy at a time until the rest of the expression matches. Note the
`return(0)` (394) when no number of copies will do. v7's `ed` ended the
same case with `continue`, which went on to match the rest of the
expression from a point before the repetition started; `grep`'s version
is the correct one, and `ed` now has it too (#f("cmd/ed.c")).

#lines(363, 396)

The closures. Each first consumes as many characters as it can,
leaving `curlp` at the start of the run and `lp` one beyond its end.
Then, at `star`, it tries the rest of the expression from each
possible end of the run in turn, longest first, so that the match found
is the leftmost-longest one which allows the remainder to match.

Here `grep` is more careful than `ed`. If the run is empty (417), it
carries on without a recursive call. If the next item is a literal
character, it tries only the ends at which that character follows,
which saves a call of `advance` for each position that cannot succeed.
`ed`'s loop instead calls `advance` at every position, but stops at
`locs` (#f("cmd/ed.c")), which `grep` does not need.

#lines(397, 442)

`succeed` prints a matching line, preceded as the flags require by the
file name, the block number (counted in `BSIZE` units of 512 bytes from
#f("param.h")), and the line number. With `-c` it only counts; with
`-l` it prints the name of the file and seeks to its end, so that the
next read ends the file at once. `printf("%D")` (286) is v7's form for
a `long`, which the port's `printf` still accepts
(#f("stdio/doprnt.c")).

#lines(443, 481)
#source("/usr/src/cmd/diff.c")

`diff` reports the differences between two files as the smallest set of
lines to be deleted from the first and added from the second, in the
form of `ed` commands. Finding that set is the problem of the longest
common subsequence: the lines common to both files, in order, of which
there are as many as possible. Every line not in it is a change.

The method is the one published by J. W. Hunt and M. D. McIlroy in 1976
as a Bell Laboratories technical report, "An Algorithm for Differential
File Comparison", which credits Harold Stone with its central idea; the
procedure which carries it out is accordingly named `stone`. The long
comment at the head of the file is the authors' own summary. The plan
is as follows.

First each line is reduced to a hash value (`readhash`), so that both
files can be held in memory as arrays of integers, and matching lines
are thereafter found by comparing numbers. A common prefix and suffix
are set aside (`prune`), since they belong to every longest common
subsequence. The lines of each file are sorted by hash value, and the
sorted arrays are merged (`equiv`); this gathers the lines of the second
file into equivalence classes of equal hash, and attaches to each line
of the first file the class of second-file lines it might match. The
lines of the first file are then taken in order, and for each the
candidate matches in its class are offered to a table of
"k-candidates" (`stone`), from which the longest common subsequence is
finally read off (`unravel`) into the vector `J`: `J[i]` is the line of
the second file matched with line `i` of the first, or 0. The matches
are verified against the actual text (`check`), since equal hashes need
not mean equal lines, and the unmatched runs are printed as commands
(`output`).

The lone `#` (1) is the same relic as in #f("mem.c").

#lines(1, 64)

`low` and `high` split a `long` into 16-bit halves for the hash.
`struct line` holds a line's serial number and hash value. The comments
"overlaid on" (90--97) refer to the reuse of memory described under
`main`.

v7's declarations of `fopen` and `mktemp` are gone, since the port's
#f("stdio.h") declares both. The prototypes (105--109) are for the
procedures used before their definitions; those defined before use
have been made `static` instead, which spares them a prototype.

#lines(65, 111)

`done` is also the handler for the signals caught while a temporary
file exists, and now takes the signal number; the direct calls of it
pass 0. `talloc` gains a `return(p)` (127) after `noroom`, which never
returns, because a function returning a value must not run off its
end; `p` is null there.

`ralloc` is v7's "compacting reallocation". It frees the block, frees
`dummy`, and allocates `dummy` again. `dummy` was the first block
allocated (324), so it lies low in the arena; v7's `free` leaves the
allocator's search pointer at the block just freed, and the `malloc`
inside `realloc` therefore starts searching from the bottom of the
arena (#f("gen/malloc.c")). The block is moved to the lowest place
which will hold it, and the arena is kept compact. Like `cron`'s use
(#f("cmd/cron.c")), it relies on `realloc` of a freed block.

#lines(112, 148)

`sort` is a Shell sort, ordering by hash value and, among equal values,
by serial number, so that each equivalence class ends up with its lines
in their order in the file. The test for "wraparound" (164) guarded
against a pointer passing the top of the PDP-11's 64 KB address space;
it can no longer succeed.

Two changes. `m` is now initialized (153): for an empty file the first
loop does not run, and v7 then halved an undefined `m`; the compiler's
analysis at `-Os` found this. The parentheses at (167--168) make
explicit that `&&` binds more tightly than `||`, as `-Wall` asks.

`unsort` uses the serial numbers to put the class indices of the first
file back into the file's own order.

#lines(149, 193)

If one argument is a directory, the file of the same base name within
it is meant. An argument `-` names the standard input, which is copied
to a temporary file, since `diff` reads each file more than once.

`prepare` reads a file, storing one hash per line from index 1 up, and
grows the array by one element per line with `ralloc`.

#lines(194, 246)

`prune` counts the identical lines at the start and at the end of the
two files, and renumbers the lines in between from 1; `sfile` and
`slen` describe these middles, on which the expensive part works.

`equiv` walks the two sorted arrays together. Each line of the first
file has its hash replaced by the position in the sorted second file of
the first line of equal hash, or 0 if there is none. Then the serial
numbers of the sorted second file are copied into `member`: the
equivalence classes, each listing its lines in increasing order, are
simply concatenated, and the first element of each class is negated to
mark its start. A final -1 stops the scan of the last class.

#lines(247, 291)

`main`. Memory is reused as soon as it is free: `member` is written
over the array of the second file, and `class` over that of the first,
each then shrunk with `ralloc`, since an `int` takes no more room than
the `struct line` it replaces. The comment's estimate of six words per
line was made for the PDP-11; with four-byte `int`s and `long`s the
proportions are much the same.

#lines(292, 360)

`stone` is the heart of the program. A k-candidate is a match `(x, y)`,
line `x` of the first file with line `y` of the second, which ends a
common subsequence of length `k` of the lines considered so far, and
whose `y` is the smallest possible for that length. The array `c`
(`klist`) holds in `c[k]` the index in `clist` of the current
k-candidate for each length. Their `y`s strictly increase with `k`,
since a subsequence of length `k` contains one of length `k-1` ending
earlier. Each candidate also records in `pred` the candidate of length
`k-1` it extends, so that the whole subsequence can be recovered.

The lines `i` of the first file are taken in order. For each, the
members `y` of its class are taken in increasing order. `search` finds,
by bisection, the length `l` of the shortest candidate whose `y` is at
least `y`. If that candidate's `y` equals `y`, nothing is gained.
Otherwise `(i, y)` extends the candidate of length `l-1` to a common
subsequence of length `l` ending lower in the second file than the
present one, and replaces it (387). If `l` exceeds every length so far,
the table grows by one (391--393), and the rest of the class, whose
`y`s are larger, cannot do better.

The subtle part is `oldc`. Several members of the same class may
replace entries during one line `i`, at increasing lengths. The
predecessor of a new candidate must come from an earlier line of the
first file, so when `l` is one more than the length just replaced,
the predecessor must be the candidate which was there before the
replacement, saved in `tc` (386, 388), not the new one, whose `x` is
`i` itself. Likewise a `y` no greater than the `y` of that saved
predecessor (378) cannot extend it, and is passed over. Note that
`continue` in a `do`-`while` goes to the test (395), which advances to
the next member of the class.

#lines(361, 399)

`newcand` adds a candidate to `clist`, a store from which nothing is
ever removed, growing it by one element at a time. `search` first tries
the commonest case, a `y` beyond every candidate.

`unravel` builds `J`. The prefix lines match themselves, the suffix
lines their counterparts, and the rest are filled in by following
`pred` back from the longest candidate.

#lines(400, 445)

`check` reads both files again, line by line in step with `J`. Each
pair of lines which `J` claims to match is compared character by
character; with `-b`, runs of blanks compare equal. A pair which
differs owes its match to equal hashes alone, and the match is
dropped, a "jackpot". What remains is a common subsequence, but
perhaps not a longest one, so that a line may be reported as changed
which a true match would have kept; the comment at the head of the file
accepts this. At
the same time the byte offset of the end of every line is recorded in
`ixold` and `ixnew`, so that `fetch` can later seek straight to any
line.

`c` and `d` (457) are now `int`, where v7 had `char`, for two reasons.
`isspace` is a macro which indexes a table, and a `char` subscript draws
a warning from `-Wall`. And on the ARM, whose `char` is unsigned, the
`EOF` returned by `getc` would become 255, which with `-b` indexes
`isspace`'s table beyond its end; the PDP-11's signed `char` kept it
-1, as the `int` now does.

#lines(446, 522)

`output` scans `J` for runs of unmatched lines and reports each run as
a `change`: lines `a` to `b` of the first file are replaced by lines `c`
to `d` of the second. An empty first range means an addition, an empty
second range a deletion. The sentinels `J[0]` and `J[m+1]` (532--533)
spare the loops tests for the ends. With `-e` the commands form an
`ed` script, and are produced from the end of the file backwards, so
that the line numbers in each command are not disturbed by the
commands already applied. `-f` gives the same commands in forward
order and a different form, for reading, not for `ed`.

#lines(523, 599)

`readhash` computes a line's hash: each character is added to a
`long` after a shift of seven bits more than the last, taken modulo 16,
and the two 16-bit halves are then folded together. With `-b`, blanks
are not hashed, and a run of them counts only as the gap of one shift.
`readhash` returns 0 at the end of the file, and a line never hashes to
0: the sum starts at 1, so that after the fold the halves can never
cancel. A last line without a newline is dropped, as in v7.

On the PDP-11 the result was reduced to a 16-bit `int`; on the ARM the
sum of the two `short` halves is kept in 32 bits. Two results which
differ by 65536, and which the PDP-11 would have reduced to the same
value, now stay distinct; otherwise only the values change.

#lines(600, 648)
#source("/usr/src/cmd/ps.c")

`ps` reports on processes, and it has no system call to ask. It reads
the kernel's process table directly: `nlist` finds the address of
`proc` in the symbol table of `/unix`, and the table is read from
`/dev/mem` at that address. For each process it then reads the
process's `user` structure, which lies in the process image
(#f("user.h")), from memory if the process is loaded and from the swap
area if not, and from the image it digs out the arguments with which
the program was started. Every structure involved, `proc`
(#f("proc.h")), `user`, and the layout of the image, is the kernel's
private business; `ps` must be compiled against the kernel's own
headers and must agree with it exactly. The mechanism shared with
`dmesg`, `nlist` on the ELF `/unix` and kernel addresses as offsets in
`/dev/mem`, is described in #f("cmd/dmesg.c").

`/dev/mem` may be read by anyone (#f("rootfs.proto")), but `/dev/swap`
only by root, and `ps` gives up if it cannot open both, so in this
system `ps` works only for the super-user.

v7 included `<core.h>`, which described the PDP-11 core image, for the
three macros `TXTRNDSIZ`, `stacktop`, and `stackbas`. The port has no
such header, and the macros are defined here (8--10), with the top of
the stack at `0x100000`, the end of the 1 MB user window, where the
PDP-11's was at `0x10000`, the end of its 64 KB address space. The
argument `siz` of `stacktop` was unused in v7 too.

`proc.h` and `user.h` are taken from the kernel's own directory (12,
14), since the port installs neither in `/usr/include/sys`. v7 also
included `<sys/tty.h>`, of which `ps` uses nothing; `u_ttyp` is only a
pointer to a `struct tty`, which C permits without the structure's
definition. The program's own variable `u` (25), into which it reads a
`user` structure from memory or swap, agrees with the `extern`
declaration of #f("user.h"). The members of `nl` are initialized in
full, since a partial initializer draws a warning from `-Wextra`.

#lines(1, 21)

v7 declared `lseek` and, wrongly, `strncmp` returning `char *`; both are
now declared in #f("stdio.h"), and these lines have gone. The procedures
of the file are declared with prototypes instead (33--36).

A device name is now `DIRSIZ+1` bytes (45), for the terminating null
which a directory entry of the full `DIRSIZ` characters lacks (see
`getdev` below).

#lines(22, 50)

The options are letters in the first argument, in any combination: `a`
for all users' processes, `x` for those without a terminal, `l` for
the long listing, `t` followed by a terminal name, `v` for the
children's times, `k` to read a core image of memory from
`/usr/sys/core` instead of the live system, and a number for a single
process.

#lines(51, 99)

`ps` first reads two kernel variables. `swapdev` is read into
`nl[1].n_value` and never used, since the swap area is reached through
the file `/dev/swap`; `swplo`, the first block of the swap area on its
device, is needed to find a swapped image. Then it seeks to `proc` and
reads `NPROC` entries in turn, one `struct proc` at a time. Since
`NPROC` comes from the program's `param.h`, it must agree with the
kernel's (#f("param.h")).

A slot with `p_stat` zero is unused. Processes of the super-user which
have no process group, that is, which never opened a terminal, such
as process 0, are shown only with `x`.

#lines(100, 153)

`getdev` builds a table of the character special files in `/dev`, by
name and device number, so that a terminal can later be named from the
device number recorded in a `user` structure. It reads the directory
as a plain file, one `struct direct` (#f("dir.h")) at a time.

A name which fills all `DIRSIZ` bytes of an entry has no terminating
null. v7 passed `d_name` straight to `stat` and copied it with `strcpy`,
reading past the entry and writing a byte past `dname`. The port copies
it with `strncpy` into the larger `dname`, whose last byte remains
zero, and passes the copy to `stat`; the copy is made before the type
is known, and a slot which is not a character device is simply
overwritten by the next. The loop also stops at the 256 entries the
table holds (168), where v7 had no limit.

The `#include` of `<sys/stat.h>` inside the procedure (158) is v7's.

#lines(154, 184)

`round` is now `static`; it is used only after its definition, and a
static procedure needs no separate prototype. `datmap` describes how
user addresses map onto the image, as a debugger's map would: addresses
from `b1` to `e1` lie at file offset `f1` plus the distance from `b1`,
and those from `b2` to `e2` at `f2` plus the distance from `b2`.

#lines(185, 199)

`prcom` handles one process. If it is loaded (`SLOAD`), its image is at
`p_addr` clicks in `/dev/mem`. In the port `p_addr` counts from
`corebase` (#f("proc.h")), and `memaddr` (#f("machdep.c")) takes an
offset below `kernbase` to be relative to `corebase` in just that way,
so v7's `ctob` of the click number still gives the right offset. If the
process is swapped out, `p_addr` is a block number in the swap area,
and `swplo` is added. The `user` structure is at the start of the image
in both cases.

The maps follow from the shape of the image, which is different on the
ARM. On the PDP-11 the image was the `USIZE` clicks of the `user` area,
then the data, then the stack, packed together; the stack segment, at
the top of the address space, followed the data in the image. v7 set
`f2` accordingly to the end of the data, `datmap.e1-datmap.b1` past the
`user` area. In the port, the image is the `user` area followed by the
whole 1 MB window (#f("sys1.c")), so that every user address lies at
its own offset from the end of the `user` area, and `f2` (236) is
`b2` past it. Until this was put right, `ps` sought the arguments in
the wrong place and printed blanks. The data map
is right unchanged, since the port's executables have no separate text
(`u_tsize` is zero) and `b1` is therefore zero.

#lines(200, 237)

The fields of the line. The mask `&0377` (243) is new. `p_stat` is a
`char`, and an array subscript of type `char` draws a warning from
`-Wall`; the mask makes it an `int`, and on the PDP-11, where `char`
was signed, it would also have kept the subscript positive. The
formats were made for the PDP-11, and three fields of the long listing
are widened for 32-bit values (136, 248, 253, 255): `ADDR`, the click
number in octal, from six digits to eight, since the 512 MB of the
MP135 machine has 8,388,608 clicks; `SZ` from four columns to five,
since the image of a process, its 1 MB window and its `user` area, is
2064 blocks, which v7's `%4d` ran into the
address; and `WCHAN`, a kernel address in octal, from seven columns to
twelve, room for eleven digits and a space. `SZ` is the image in
blocks of 512 bytes; since every user process has an image of the
whole window, it is the same for all of them. The times assume `HZ`
of 60, which holds (#f("param.h")).

#lines(238, 280)

The arguments are sought in the last 512 bytes of the image, the top of
the stack. First the last word of the window is examined: `exec` leaves
it zero, but the shell, when it runs a command file, stores there a
pointer to its own argument list (`execargs`, #f("sh/main.c")), so that
`ps` shows the name of the command file rather than `sh`. The pointers
and the strings are fetched one byte at a time through `getptr` and
`getbyte`, which apply `datmap`.

#lines(281, 303)

Otherwise the strings themselves are found. `exec` (#f("sys1.c")) puts
the argument and environment strings at the top of the stack, preceded
by the vector of pointers, which ends with a zero word. The scan goes
backwards from near the end for a word which is zero or -1, takes the
strings which follow it, turns nulls into spaces and unprintable
characters into `?`, and stops at the first `=`, which begins the
environment, cutting back to the preceding space.

v7 declared `abuf` as 512 `char`s and walked it with an `int` pointer
through casts; it is now 128 `int`s, and the casts in the loop have
gone. Reading a `char` array through an `int` pointer is undefined in
C99, which allows an object to be accessed only through its own type or
as characters, and nothing guarantees that a `char` array is aligned
for `int` accesses. The present compiler happens to place v7's array
on a word boundary, but `-Wcast-align=strict` rejects both casts. An
`int` array may be read as characters, as the rest of the loop does.

#lines(304, 338)

`gettty` names the terminal by searching the table of `getdev` for the
device number `u_ttyd`, dropping the prefix "tty".

#lines(339, 357)

`getptr` assembles a pointer from the image byte by byte, through
`getbyte`. Its counter is now `unsigned`, so that
the comparison with `sizeof` is between unsigned values. `getbyte`
finds the offset of a user address through the two maps and reads one
byte; an address in neither map reads as zero.

`within` compared `(unsigned)adr` with the `long` bounds. On the
PDP-11 the 16-bit `unsigned` was promoted to a 32-bit `long` and the
comparison was exact; on the ARM `unsigned` and `long` are both 32 bits,
the bounds would be converted to `unsigned` instead, and the compiler
warns of a comparison between signed and unsigned. Casting the address
to `long` keeps the comparison signed, which is correct for user
addresses, all of them below `0x100000`.

#lines(358, 400)
#source("/usr/src/cmd/dmesg.c")

Everything the kernel prints with `printf` (#f("prf.c")) passes through
the console driver's `putchar`, which keeps a copy of each character in
the circular buffer `msgbuf`, `MSGBUFS` (128) bytes long, with
`msgbufp` pointing at the next place to be written (#f("pl011.c")). The
buffer is defined in #f("main.c") and the pointer in #f("machdep.c").
`dmesg` copies the two out of the running kernel and prints the
buffer, oldest character first, so that messages which went to the
console while nobody watched can still be read.

It does so as `ps` does, and as any v7 program which inspects the
kernel must. `nlist` looks the names up in the symbol table of the
kernel's file, `/unix`, to learn their addresses, and the program then
reads memory at those addresses through `/dev/mem`. Both halves needed
work in the port, though none of it is in this file. v7's `nlist` read
the symbol table of an `a.out` file; the port's kernel, like its
programs (#f("sys1.c")), is an ELF file (#f("Makefile")), installed as
`/unix` in the image (#f("rootfs.proto")), and the port's `nlist` (`nlist.c`, in the C library) finds
the ELF symbol table instead, compares only the first eight characters
that `struct nlist` (in `a.out.h`) has room for, and puts back the
leading underscore with which the PDP-11 C compiler prefixed every
external name and which ELF compilers do not add. So `"_msgbuf"` (20)
still finds `msgbuf`. On the other side, an offset in `/dev/mem` at or
above `kernbase` is taken to be a kernel address (`memaddr`,
#f("machdep.c"); #f("mem.c")), so that the value `nlist` reports can be
used directly as the offset for `lseek`.

With the flag `-`, the program keeps in `/usr/adm/msgbuf` a copy of the
buffer as it was last seen, and prints only what has been added since.
The crontab runs it so every ten minutes, appending to
`/usr/adm/messages` (#f("cmd/cron.c")). The image provides both files,
owned by `daemon`, and makes `/dev/mem` readable by anyone
(#f("rootfs.proto")), since `cron` runs the program as `daemon`. Without
`/usr/adm/msgbuf` the `open` (38) would fail, the `read` and `write` on
descriptor -1 would fail harmlessly, the saved state would be all
zeros, and the whole buffer would be printed each time.

The members `n_type` and `n_value` of `nl` (19--22) are now given
explicitly, since a partial initializer draws a warning from
`-Wextra`. The third element, all zeros, ends the list for `nlist`.
`done` and `pdate` are declared before `main` (24), which uses them.

#lines(1, 23)

The two `read`s copy the buffer and the pointer. The check at (51) is the
only defence against a `/unix` which is not the running kernel: if the
pointer read at the address given for `msgbufp` does not lie within the
address given for `msgbuf`, the names belong to some other system. The
pointer is then moved (53) from the kernel's buffer to the program's
copy.

#lines(24, 53)

The comparison decides where printing begins. `mstart` is set to the
position recorded on the last run, and the copy is compared with the
saved buffer from the present write position round to `mstart`. That
stretch is the part of the old text which should not have been
overwritten since. If it is unchanged, the new text is the stretch from
`mstart` to `msgbufp`; if nothing at all is new, the program exits
silently. If it differs, the kernel has written more than a whole
buffer in the meantime, messages have been lost, and the program prints
"..." and the entire buffer, starting at `msgbufp`, the oldest
character. Null bytes, the part of the buffer never yet written, are
skipped.

#lines(54, 83)

`done` records the present buffer, its index, and the message which
ended the run, and exits. The message is not printed if it is the one
recorded last time: the test (90) compares the pointers, which works
because the same program, run again, places the same string at the same
address. A complaint such as "No mem" therefore appears once in the
log, not every ten minutes. `sflg` was cleared at (41), so the test of
it is always true.

`pdate` heads the output with the date, once, before the first thing
printed. `ctime` is now declared in #f("stdio.h"), and v7's local
declaration of it has been removed; `firstime` has gained its `int`.

#lines(84, 114)
#source("/usr/src/cmd/cron.c")

`cron` runs commands at stated times. It is started by #f("rc") and
never stops. Once a minute it compares the time with each line of the
table `/usr/lib/crontab`, and starts the commands whose times have
come. The image's table (from v7's tape) runs `dmesg` (#f("cmd/dmesg.c"))
every ten minutes, `atrun`, which starts the jobs queued by `at`, every
five, and `calendar` once a day at 1:20. Since the commands run as
the user `daemon` (31), the first entry works only because `/dev/mem`
may be read by anyone and `/usr/adm/messages` and `/usr/adm/msgbuf`
belong to `daemon` (#f("rootfs.proto")).

The design is a loop which keeps its own idea of the minute, `itime`,
advancing it by exactly 60 seconds each time round and sleeping until
the real time catches up. A minute is therefore never skipped, even if
the machine was busy, and never examined twice.

The declarations of `localtime`, `malloc`, and `realloc` (deleted after
17) are now in #f("stdio.h"). The procedures are declared at (21--23):
those used before their definitions need it in C99, and `cmp`, which v7
declared inside `main`, is declared at file scope so that
`-Wmissing-prototypes` sees the declaration before the definition.

#lines(1, 24)

`setuid(1)` makes the program, and so every command it runs, the
pseudo-user `daemon` of #f("passwd"), so that the table cannot be used
to do anything as root. The parent returns to #f("rc"). The `freopen`s
of "/" put the standard output and error on the root directory, opened
for reading: the descriptors are occupied, and anything a command
writes to them without a redirection fails harmlessly. The standard input is closed
again (43); `init` opens it on the table whenever it is read.

`itime` starts at the beginning of the current minute.

#lines(25, 44)

The table is read again only when its time of last modification
(`st_mtime`) is later than that of the copy last read, held in
`filetime`. Each minute thus costs one `stat`, and an edited table takes
effect within a minute, without a signal to `cron` or a restart.

`filetime` starts at zero, and the test is a strict "greater than". A
table dated zero is therefore never read at all, and `list`, still null,
is then scanned at (56). This was once a real failure in the port,
whose `mkfs` stamped every file with time zero; the image is now built
with every file dated 284774400 seconds, 10 January 1979, the date of
v7's own files (#f("Makefile"), #f("cmd/mkfs.c")), and the table is read
on the first pass. The same test means that a table replaced by an
older file is ignored until it is touched.

For each entry, `cmp` checks the five fields in order against the
minute, hour, day of the month, month (made 1 to 12 at (55), since
`localtime` counts from 0), and day of the week; it counts failures in
`flag`. If all match, the command, which follows the fields, is run.
The `slp` before it (64) makes sure the minute has really come, and the
`while` at (67) skips to the end of the command.

#lines(45, 71)

`init` compiles each field into a code and its operands. The codes are
100 to 104, and every number is less than 100 (`number`, 250), so a code
cannot be mistaken for a value. `EXACT` is followed by the value, `ANY`
by nothing, `LIST` by the values and a closing `LIST`, `RANGE` by the
two bounds. `cmp` returns the position of the next field. The code
after the `switch` (104) is never reached, since `init` writes no other
code.

#lines(72, 107)

`slp` sleeps until `itime`, if that is still in the future.

`ex` forks twice. The child forks again and exits at once, so that
`cron`'s `wait` returns immediately; the grandchild, now an orphan,
belongs to `init` (#f("cmd/init.c")), which collects it when it ends.
`cron` thus never waits for a command, and leaves no zombies. The
command is given to the shell with `-c`, with its standard input on
"/".

#lines(108, 135)

`init` reads the table into `list`, which starts with 512 bytes and
grows by 512 whenever fewer than 100 bytes remain at the start of a
line. Note that the margin is not a guarantee: a command line longer
than about 100 characters, started near the end, would write past the
block.

The calls of `free` before `realloc` (147, 159) rely on a promise of
v7's allocator: `realloc` accepts a block freed since the last `malloc`,
and still finds its contents there (#f("gen/malloc.c")). Since `realloc`
frees a busy block itself, the explicit `free` changes nothing. At
(148) any copying of the old contents is wasted, since the list is about
to be rebuilt.

#lines(136, 162)

A line is parsed field by field. A field is `*`, a number, a list of
numbers separated by commas, or a range `a-b`, followed by a blank. A
line with any other field, or which ends before the command, is
dropped (`ignore`), and parsing resumes on the next line. In the
command, `%` stands for a newline, so that one table entry can hold
several lines for the shell. The command is stored with a newline and a
null; at the end of the file two `EOS` codes are written, the first of
which ends the scan at (56).

#lines(163, 238)

`number` reads decimal digits and pushes back the first non-digit.

#lines(239, 253)
#source("/usr/src/cmd/update.c")

The kernel does not write a modified buffer at once. `bdwrite`
(#f("bio.c")) only marks it for delayed writing, the super-block of each
mounted file system is changed in memory, and an inode is copied to its
disk block when it is released, or when somebody asks. The asking is
the `sync` system call (#f("sys4.c")), whose whole body is `update`
(#f("alloc.c")). `/etc/update`, started by #f("rc"), makes that call
every thirty seconds for as long as the system runs, so that a crash
loses at most half a minute's work.

The program also does the kernel's inode cache a small service. The
three directories in `fillst` are opened once and never closed. An open
file holds a reference to its in-core inode (#f("iget.c")), so these
inodes stay in the table, and every search of `/bin` or `/usr/bin` by the
shell finds the directory's inode without reading it from the disk.

The `#include <stdio.h>` (7) is new: in the port that header declares
the system call stubs `fork`, `close`, `open`, `sync`, `alarm`, and
`pause`, and `exit` (#f("stdio.h")), which C99 will not let the program
call undeclared.

#lines(1, 15)

The parent returns at once, so that #f("rc") goes on to its next line,
and the child closes the standard files, which belong to the console.
The descriptors 0, 1, and 2 so freed are the ones the three `open`s
receive. The call `dosync(0)` performs the first `sync` and arms the
alarm; after that the process does nothing but `pause` until a signal
arrives.

`dosync` is declared before `main` (16) because it is used there before
its definition. v7 called it with no argument; it is a signal handler
and now takes the signal number, as the prototype of `signal`
(#f("sys/signal.s")) requires, so the direct call passes 0.

#lines(16, 32)

Each `SIGALRM` runs `dosync`, which calls `sync` and then sets the alarm
again. The `signal` call is repeated every time because a v7 signal
reverts to its default action when it is caught (`psig`, #f("sig.c")); a
second alarm finding the default action in place would kill the process.
`alarm` is served by the clock routine's once-a-second work
(#f("clock.c")), which decrements `p_clktim` and sends the signal when it
reaches zero.

The thirty-second `sync` also keeps the date on the disk. `update`
(#f("alloc.c")) stamps each modified super-block with the current
`time` before writing it, and `iinit` (#f("main.c")) takes the time of
day at boot from the root file system's `s_time`, since the kernel reads no
battery-backed clock on either board. A newly booted system therefore starts
from the last moment at which `update` found the super-block modified,
at most thirty seconds after the last allocation or release of a block
or inode, rather than from the 10 January 1979 of the image (#f("Makefile")). A system which has changed nothing on its disk
leaves `s_time` alone, since the stamp is written only together with a
modified super-block.

#lines(33, 41)
#source("/usr/src/cmd/mkdir.c")

v7 has no system call to make a directory. A directory is an inode of
type `IFDIR` whose contents are entries of the form described in
#f("dir.h"), and the kernel's only means of creating such an inode is
`mknod` (#f("sys2.c")), which takes the mode as given and is reserved
to the super-user. The new directory is then empty: it lacks even the
entries "." and "..", which the kernel does not supply, but which
`namei` (#f("nami.c")) expects to find, since apart from one test for
".." at the root of a mounted file system it looks them up as ordinary
names. `mkdir` adds them with two calls of `link`,
and `link` too refuses a directory to anyone but the super-user
(#f("sys2.c")). These restrictions protect the shape of the tree: a
directory linked into two places, or one without a correct "..", would
confuse `namei` and the programs which walk the file system.

The program is therefore installed set-user-id to root, mode 4755, as
on v7's distribution tape (#f("rootfs.proto")), and does its own
checking on behalf of the real user.

The signals which might stop the program are ignored (15--19) so that it
cannot be interrupted between the `mknod` and the second `link`, which
would leave a directory without its "..".

The declarations of `strcat` and `strcpy` (deleted after 8) are gone,
since the port's `stdio.h` declares the string routines with
prototypes (#f("stdio.h")). `mkdir` is declared before `main` (10)
because `main` calls it first.

#lines(1, 28)

The parent of the new directory is its name up to the last slash,
followed by "."; for a name with no slash, it is "." itself. `access`
asks with the real user and group ids whether the parent may be written
(`saccess`, #f("sys2.c")). In a set-user-id program this was the whole
of the permission check, since the effective id was root's and every
later call would succeed. Note that `strncpy` (41) leaves `pname`
unterminated, and the `strcpy` which follows supplies the terminator.
Neither buffer is checked against the 128 bytes declared for it.

#lines(29, 47)

`mknod` makes the inode with mode 040777, from which `maknode`
(#f("iget.c")) removes the bits of the creator's `umask`; its link count
is one, for the entry in the parent. `chown` gives it to the real user,
since otherwise it would belong to root, the effective user of a
set-user-id `mkdir`.

The first `link` makes the entry "." in the new directory, naming the
directory itself, and raises its count to two. The second makes ".."
name the parent, which raises the parent's count. If the first fails,
the entry in the parent is removed and the inode, its count back to
zero, is freed when the last reference goes.

If the second link fails, the assignment at (65) removes the last "."
of `dname`, so that `unlink` removes the entry "." made a moment
before, and `unlink(d)` then removes the entry in the parent. v7's line
lacked the `-1`: it stored a null byte over the null byte already
there, `unlink` was applied to the ".." which was never made, and the
directory was left with a count of one, from its own ".", and no name,
an inode lost until `icheck` or `clri` attended to it.

#lines(48, 70)
