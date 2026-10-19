#import "defs.typ": *

== Startup and Processes <ch-startup>

This chapter follows the kernel from its first instruction to its
first process, through the tables and routines which set up memory,
start the machine, and create and switch processes. The machines, the
address space, and the translation tables they rely on are described
in the Introduction (@ch-intro).

#source("/usr/sys/h/map.h")

A resource map is a list of the free areas of some resource. Each
element gives the size of one area and the address of its first unit,
both measured in whatever unit suits the resource. The system keeps
three such lists, for RAM, for the swap area, and for the pages
set aside at boot for user page tables (`NPTAB`, #f("param.h")), and
all three are managed by the two procedures of #f("malloc.c"). RAM
and the page tables are measured in pages of 4096~bytes, the
unit in which the MMU maps memory, and the swap area in 512-byte disk
blocks.

#lines-to("extern struct map coremap[];\t/* space for core allocation */", lead: true)

The maps themselves follow: `coremap` for RAM, `swapmap` for
the swap area, and, new in the port, `ptmap` for the pages of user page
tables (#f("ureg.c")).

#lines-to(none)
#source("/usr/sys/sys/malloc.c")

This file holds the two procedures which manage a resource map
(#f("map.h")): `malloc` takes an area out of the free list and `mfree`
puts one back.
Despite its name, `malloc` has nothing to do with the C library routine
of the same name.

The correctness of both procedures rests on four rules about the list,
which every operation must preserve:

+ The free areas appear in order of increasing address.
+ No two entries describe adjacent areas; two such areas are always
  merged into one entry.
+ The list ends at the first entry with a zero size. This sentinel is
  not itself a free area, and its address field means nothing.
+ Every element of the array beyond the sentinel also has a zero size.
  The arrays start out zero, and the code which shortens the list
  leaves zeros behind it; `mfree` depends on this when it lengthens the
  list.

Neither procedure checks for the end of the array, so the arrays must
be large enough never to overflow. A map can hold no more free areas
than there are allocated areas between them, plus one, and it needs one
entry more for the sentinel. `CMAPSIZ`,
`SMAPSIZ`, and `PMAPSIZ` (#f("param.h")) are computed from this bound, and the
configuration of each machine gives the maps those sizes
(#f("qemu/c.c")).

#lines-to("int")

`malloc` uses the "first fit" rule: it takes the first area in the list
which is large enough, and allocates from its low end. The search (#l("for (bp=mp; bp->m_size; bp++) {"))
stops at the sentinel, whose size is zero.

#lines-to("a = bp->m_addr;")

The request is carved off the front of the area (#l("a = bp->m_addr;")--#l("bp->m_addr += size;")); the entry
remains, describing what is left.

If nothing is left (#l("if ((bp->m_size -= size) == 0) {")), the entry must go. Every following
entry, up to and including the sentinel, is moved down one place.
Notice that the loop copies the address before it tests the size, and
that the test is the value of the size just copied, not a comparison.
The loop stops after it has copied the sentinel's zero; the old slot of
the sentinel keeps its own zero, which is the fourth rule above.

#lines-to("return(a);")

The address is returned (#l("return(a);")). Zero (#l("return(0);")) means failure. This is safe only because no free area ever
begins at address zero. For RAM, the addresses are physical page numbers, and neither machine
has RAM at address zero. For swap, `startup` (#f("machdep.c")) frees the
map starting at block 1, and decrements `swplo`, the first block of the
swap area on its device, to compensate. So block zero of the swap area
is never named.

#lines-to("if ((bp = mp)==coremap && runin) {")

Freeing RAM may allow the scheduler to bring in a process
which is waiting on disk. If `sched` (#f("slp.c")) has gone to sleep
for want of RAM (`runin` set), it is woken at once. Note that the map
has not yet been updated when the wakeup is issued; this is harmless,
since `wakeup` merely makes `sched` runnable, and the kernel is not
preempted, so `sched` cannot look at the map before `mfree` returns.

#lines-to("for (; bp->m_addr<=a && bp->m_size!=0; bp++);")

The loop with the empty body (#l("for (; bp->m_addr<=a && bp->m_size!=0; bp++);")) steps `bp` forward past every area
which begins at or below `a`. At its end, `bp` points to the first area
above the one being returned, or to the sentinel. The new area belongs
just before `bp`.

There are now four cases. If the area being returned begins where the
previous area ends (#l("if (bp>mp && (bp-1)->m_addr+(bp-1)->m_size == a) {")--#l("(bp-1)->m_size += size;")), the previous entry simply grows.

If it now also reaches the next area (#l("if (a+size == bp->m_addr) {")--#l("}", after: "(bp-1)->m_size = bp->m_size;")), the two entries become
one: the previous entry absorbs the next, and the rest of the list,
sentinel included, moves down one place. As in `malloc`, the slot
vacated at the end keeps its zero size. If `bp` is the sentinel, its
address is meaningless, and the test at line #l("if (a+size == bp->m_addr) {") may succeed by chance;
it then adds a zero size and the loop does not run, so no harm is done.

#lines-to("} else {")

Otherwise, if the area being returned ends where the next
area begins, the next entry is extended downwards. The test of
`bp->m_size` prevents a match against the meaningless address of the
sentinel.

#lines-to("} else if (size) {")

Otherwise a new entry is needed. It is written into `bp`,
and the entry which was there is carried forward, in `a` and `t`, into
the next slot, which in turn gives up its own entry, and so on. When
the entry displaced is the sentinel, the size carried forward is zero
and the loop stops without storing it. The slot after, which is now
the end of the list, needs no zero written into it: by the fourth
rule, it already holds one.

Note that a zero `size` (#l("} else if (size) {")) changes nothing; it is tested only in this
last case, since in the others adding zero is harmless.

#lines-to(none)
#source("/usr/sys/sys/prf.c")

The kernel's means of speaking to the operator. `printf` writes
directly to the console, one character at a time, without buffering
and without interrupts; it is used at startup, for hardware errors, and
for the last words of a dying system. `panic`, `prdev`, and `deverror`
are built on it, and it in turn calls `printn` for numbers and
`putchar` for each character.

`putchar` is defined in #f("pl011.c") for the QEMU machine and in
#f("otg.c") for the MP135 machine. Both keep a copy of everything printed
in `msgbuf` and follow a newline with a carriage return. The first waits, with a time limit, for the transmitter to have room,
and writes the character with the transmitter interrupt masked. The
second gathers the characters, with interrupts off, and sends them to
the host at each newline or when its buffer is full. It waits at most a
tick for the previous transfer.

#lines-to("/*")

`panicstr` is set by `panic` and read by nothing in the system. It
exists so that whoever examines RAM after a crash can find the
message, even if the console printed nothing.

#lines-to("/*", lead: true, after: "char\t*panicstr;")

The comment promises `%d`, `%u`, `%o`, `%x`, `%s`, and `%D`. There is no
`%c` and no field width. An unrecognised conversion is printed as written (#l("} else {")--#l("}", after: "putchar('%');")), and a `%` at
the very end of the format ends it (#l("c = *fmt++;")--#l("}", after: "c = *fmt++;")). v7's `printf` dropped the
first silently, leaving its argument to the next conversion, and read
past the terminating null on the second.

`%D` (#l("} else if (c == 'D') {")) prints a `long`, which here has the same 32~bits as an `int`,
so `%D` and `%d` print the same.

The other numeric conversions fetch their argument as `unsigned` (#l("printn(va_arg(adx, unsigned),")).
v7 converted it to `long`, which on the PDP-11 widened 16~bits to 32
and could never produce a negative value. So `%d` of $-1$ printed 65535,
which is what the comment means by "`%d` (==`%u`)". Here `unsigned` and
`long` are the same size, and the conversion would turn any value of
$2^31$ or more negative: a kernel address such as `0xc0101234` would
print as `-3FEFEDCC`. The cast is gone and `printn` takes an
`unsigned long`, so the value arrives intact. `%d` of $-1$ prints 4294967295, as
the comment promises.

#lines-to("/*", lead: true, after: "}")

`printn` produces the digits of `n` in base `b` by printing the higher
digits, `n/b`, recursively, and then the lowest. The recursion ends
because each call divides by at least 8; a 32-bit number has at most
eleven octal digits.

`printn` takes its number unsigned, as the comment (#l("* Print an unsigned integer in base b.")) says, so v7's
test for a negative `n` is gone. The sign of a `%D` argument is printed
by `printf` instead (#l("l = va_arg(adx, long);")--#l("printn(l, 10);")). It negates the value as `unsigned long`,
so that even $-2^31$ comes out right.

#lines-to("/*", lead: true, after: "}")

`panic` is the system's response to a state it cannot repair. It
records the message, writes out what it can, prints, and stops.

First `update` (93, #f("alloc.c")) writes the super-blocks, the modified
inodes, and the delayed-write buffers to disk, so that as little as
possible of the file systems is lost. If the panic arose in the disk
code itself, this may not succeed, and if `update` was already running
when the panic came, its lock `updlock` makes it return at once.
`updlock` starts locked (#f("main.c")), and `main` releases it only once `binit` has built the buffers. Until then `update` would walk
tables in DDR which the MP135 machine may not yet be able to reach, and
a free list not yet linked.

#lines-to("for(;;)")

The system does not halt but idles for ever. `idle`
(#f("mch.s")) was on the PDP-11 a `wait` instruction at processor
priority zero; on ARM it enables interrupts with `cpsie i`, waits for
one with `wfi`, and disables them again. Interrupts therefore continue
to be taken: transfers already under way, including those started by
`update`, complete, and the clock keeps running. The only way out is
to restart the machine.

#lines-to("/*", lead: true)

`prdev` reports a problem with a device, giving its major and minor
numbers. It is used mainly by the file system code in #f("alloc.c"),
for a full or corrupted file system.

#lines-to("/*", lead: true, after: "}")

`deverror` is called by a disk driver whose transfer has failed. The
block number is a `daddr_t`, hence `%D`. The two further words were on the PDP-11 copies of the
controller's error registers, for which octal was the natural form.
The two disk drivers pass a single status value and a zero:
#f("virtio_blk.c") the status byte returned by the virtual device,
#f("sd.c") the status register of the SD controller.

#lines-to(none)
#source("/usr/sys/h/param.h")

#f("param.h") is the first file which nearly every kernel source file
includes, and most of the other `.h` files assume that it has been
included before them. It reserves no storage, though it declares some
(#l("extern unsigned corebase, coretop, coreoff, gicdbase, giccbase;")), but defines the constants and simple types upon
which the remainder of the system is built. As elsewhere in UNIX,
defined constants are written in upper case only.

The file falls into six parts: the tunable parameters, the priorities,
the signals, the "fundamental constants", some conversion macros and
types, and finally a few machine-dependent definitions.

These are the parameters which an installation may reasonably alter.
Most of them fix the dimensions of tables which are allocated
statically, once and for all, when the system is built. Among them are
`NBUF` for the buffer cache, `NINODE` for the inodes held in RAM,
`NFILE` for the open file table, and `NPROC` for the process table. Doubling `NPROC`
costs space in every system, whether the processes exist or not.

`MAXMEM` (#l("#define\tMAXMEM\t32768\t\t/* max core per process */")) is the largest image a process may have, in pages. The
administrator chooses it; it is currently set to 32768, 128~MB, a
quarter of RAM. `startup`
(#f("machdep.c")) limits `maxmem` to `MAXMEM`. `fork` (#f("sys1.c"))
needs room on the swap area for a copy of its caller, since `newproc`
(#f("slp.c")) may have to swap the child out. It therefore asks for the caller's own
size. A test for a whole `MAXMEM` image would fail for good once a small
image lay in the middle of the swap area.

The disk holds the root file system, and after it the swap area. The
administrator decides how big each one is. The second line of
`boot/rootfs.proto` gives the size of the root file system in blocks
and its number of inodes; `mkfs` reads it. Each machine's configuration
(#f("qemuconf"), #f("mp135conf")) gives the block where swap starts,
`swplo`, and the number of swap blocks, `nswap`. Swap must start after
the root file system and end before the end of the disk. The system is
currently configured with a root file system of 16~MB with 1024 inodes,
which is about one inode per 16~KB, the average size of a file on it.
Swap is 512~MB, as much as RAM, so it can hold every process that RAM
can. The build's image holds only the root file system, not the swap
area.

`SSIZE` and `SINCR` (#l("#define\tSSIZE\t1\t\t/* initial stack size (*4096 bytes) */"), #l("#define\tSINCR\t1\t\t/* increment of stack (*4096 bytes) */")) are the size of the stack which `exec`
gives a new program and the amount by which `grow` (#f("sig.c")) enlarges
it, one page each, the smallest amount the MMU maps.

`CMAPSIZ`, `SMAPSIZ`, and `PMAPSIZ` (#l("#define\tCMAPSIZ\t(NPROC+NTEXT+3)\t/* size of core allocation area */")--#l("#define\tPMAPSIZ\t(NPROC+2)\t/* size of page table allocation area */")) are the sizes of the three
resource maps (#f("map.h")). They are derived from a bound on the number of free areas. Each free area of a map lies between
two allocated ones, so the free areas number at most one more than the
allocated areas, and the map needs one entry more for its sentinel
(#f("malloc.c")). RAM holds at most a process image for each process
and a text for each `text` entry, and `expand` (#f("slp.c")) briefly
holds two images of the process it grows: `NPROC+NTEXT+1` allocated
areas, hence `NPROC+NTEXT+3` entries. The swap area holds at most an
image for each process, a copy of each text, and the argument list of
each process in the middle of an `exec` (#f("sys1.c")): `2*NPROC+NTEXT`
allocated areas, hence `2*NPROC+NTEXT+2`. The pool of user page tables
(below) is allocated with the third map, `ptmap` (#f("ureg.c")); each
process holds one run of pages from it, hence `NPROC+2`.

`NPTAB` (#l("#define\tNPTAB\t(4*NPROC+256)\t/* pages of user page tables */")) is new: the user page tables of the processes in RAM are
taken from a pool of `NPTAB` pages which `startup` sets aside. A small process needs
four pages of tables: a table of the second level and one of the third
for its text and data, and the same for its stack. Each further 2~MB of
a region needs one more table of the third level, and the 256~pages
beyond `4*NPROC` give one for each 2~MB of the 512~MB of RAM. That
suffices while each page in RAM is mapped once, since only processes in
RAM have tables (`ptfree`, #f("ureg.c"), releases them when a process
is swapped out). A shared text, however, is mapped by every process
which uses it, so heavy sharing of a large text can exhaust the pool;
`ptbuild` then kills the process with "out of page tables".

`HZ` (#l("#define\tHZ\t60\t\t/* Ticks/second of the clock */")) is the number of clock interrupts per second. The PDP-11 took
its clock from the mains frequency; here the ARM generic timer is
programmed to interrupt `HZ` times each second (`clkstart`, #f("machdep.c")).

The local time zone (#l("#define\tTIMEZONE (5*60)\t\t/* Minutes westward from Greenwich */"), #l("#define\tDSTFLAG\t1\t\t/* Daylight Saving Time applies in this locality */")) is compiled into the system. This is why
`date` reports Eastern time unless the kernel is rebuilt.

#lines-to("/*", after: "#define\tNCARGS\t5120\t\t/* # characters in exec arglist */")

Priorities for processes which `sleep`. The lower the value, the more
urgent the process: `PSWP` is the most urgent of all. A process which
sleeps at a priority of `PZERO` or less cannot be disturbed by a
signal; one which sleeps above `PZERO` may be, and will then return
from the system call prematurely. The reader will find this
distinction tested in `sleep` (#f("slp.c")).

#lines-to("/*", after: "#define\tPUSER\t50")

`NSIG` is one more than the number of signals, since signal zero means
"no signal". The pending signals of a process are kept as bits in
`p_sig` (#f("proc.h")), and v7 allowed sixteen, the bits of a PDP-11
word. `p_sig` is now an `int`, and `NSIG` has been raised from 17 to 32:
31 signals, as many as a 32-bit word holds without its sign bit, which
`1<<(sig-1)` must not reach. Only v7's fifteen signals have names; the others may be sent,
caught, and ignored by number. FS (#l("#define\tSIGQUIT\t3\t/* quit (FS) */")) is the ASCII file separator,
control-backslash, the terminal's quit character.

#lines-to("/*", after: "#define\tSIGTRM\t15\t/* Catchable termination */")

`USIZE` (#l("#define\tUSIZE\t1\t\t/* size of user block (*4096) */")) is the size, in pages, of the "per process data area":
the `user` structure followed by the kernel stack. The `user`
structure takes 968~bytes, which leaves 3128 for the stack. The compiler can report the
stack frame of every procedure and the calls each makes
(`-fcallgraph-info=su`), and from that report the deepest chain of calls was measured. It has
three parts:

- about 630~bytes from a system call or a trap, including the 68-byte
  register frame of #f("low.s"), through `exec`, `readi`, `bmap`, and
  the buffer cache down to `sleep`, `swtch`, and a `printf`,
- about 280 more for an interrupt taken at that point,
- at most some 260 for the bounded recursions of `printn`
  (#f("prf.c")), one level for each digit, and `tloop` (#f("iget.c")),
  one for each level of indirect block.

The kernel thus needs about 1.2~KB of stack
and has more than twice that. The measurement is not part of the build. `UBASE` (#l("#define\tUBASE\t0xFFE00000U\t/* abs. addr of user block */")) is the address at
which the data area of the current process always appears, so that the
kernel may refer to it simply as `u`. It lies at the start of the last
2~MB block of the kernel's part of the address space, above everything
else the kernel maps.

`USRSIZE` (#l("#define\tUSRSIZE\t0xC0000000U\t/* size of user address space */")) is new: the size of the user's virtual address space,
which begins at address zero. It is the counterpart of the PDP-11's
64~KB. It is three gigabytes, all of the address space below the
kernel's.

A character list ("clist") is built of blocks, each holding a pointer
to the next block and `CBSIZE` (#l("#define\tCBSIZE\t12\t\t/* number of chars in a clist block */")) characters. With a four byte
pointer, 12 characters (rather than 14) keep each block 16~bytes long,
and `CROUND` is 017, as the comment demands.

#lines-to("/*", after: "#define\tCROUND\t017\t\t/* clist rounding: sizeof(int *) + CBSIZE - 1*/")

The conversion macros: `ptob` and `btop` (#l("#define\tptob(x)\t(x<<12)"), #l("#define\tbtop(x)\t((((unsigned)x+4095)>>12))")) convert pages of
4096~bytes to bytes and back, rounding up, and `ptod` (#l("#define\tptod(x)\t((x)<<3)")) converts
pages to 512-byte disk blocks.

`itod` and `itoo` (#l("#define\titod(x)\t(daddr_t)((((unsigned)x+7)>>2))"), #l("#define\titoo(x)\t(int)((x+7)&03)")) find inode `x` on the disk: the block of the
i-list which holds it, and its place in the block. An inode is 128
bytes, four to a block (#f("ino.h")), so the macros shift by 2 and mask
with 3. Inodes are numbered from 1 and the i-list begins at block 2, so
the addend, `2*INOPB-1`, which is 7, puts inode 1 in the first place of
block 2.

#lines-to("typedef\tstruct { int r[1]; } *\tphysadr;")

`label_t` (#l("typedef\tint\t\tlabel_t[10];\t/* regs 4-11, sp, lr */")) has ten words, for the registers which `save`
(#f("mch.s")) stores: r4 to r11, the stack pointer, and the link
register.

`time_t` (#l("typedef\tlong long\ttime_t;")) is a `long long`, a signed count of 64~bits, where v7's
was a `long`. On the PDP-11 and on the ARM alike a `long` is 32~bits,
and a signed count of seconds since 1970 in 32~bits ends on 19 January
2038; 64~bits last for some 292 thousand million years. The ARM
aligns a `long long` on eight bytes, so every structure which holds a `time_t` is laid out anew. These are
the inode on the disk (#f("ino.h")), the
super-block (#f("filsys.h")), `stat` (#f("stat.h")), `user` and `xproc`
(#f("user.h"), #f("proc.h")), and the records of accounting, of the
login history, and of the archive formats which the commands keep.

#lines-to("/*")

`USERMODE` (#l("#define\tUSERMODE(ps)\t((ps & UMODE)==020)")) tells whether the interrupted program was in user
mode, from the mode bits of its status register, which `irq`
(#f("machdep.c")) passes to `clock` (#f("clock.c")).

#lines-to("extern unsigned corebase, coretop, coreoff, gicdbase, giccbase;")

The declarations of variables. The values which differ between the
two machines are defined by the configuration (#f("qemu/c.c")): the
end of RAM (`coretop`) and the addresses of the interrupt controller. `corebase` and `coreoff`,
where RAM begins and how far its kernel addresses lie from its physical
ones, are computed by `machine_init` (#f("machdep.c")).

#lines-to(none)
#source("/usr/sys/h/systm.h")

#f("systm.h") is the kernel's collection of global variables and,
in the port, of declarations for the procedures which more than one
file calls. In v7 it held only the former, together with a handful of
function declarations, mostly for routines which return pointers;
every other routine was declared implicitly by its first
call. Strict C99 has no implicit declarations, so the file has grown
from 81~lines to 311, nearly all of the growth being one long list.

#lines-to("extern\tint\tmpid;\t\t\t/* last process id given out */", lead: true)

`runin`, `runout`, and `runrun` (29-31) are the flags by which `sched`
and `swtch` (#f("slp.c")) communicate. `regloc` (#l("extern\tchar\tregloc[];\t/* locs. of saved user registers (trap.c) */")) is defined in
#f("trap.c").

`msgbufp` (#l("extern\tchar\t*msgbufp;\t/* next place in msgbuf */")) is the place in `msgbuf` where the next character
goes. Both console drivers append to the buffer, so it is defined in
#f("machdep.c").

`clkstart` (#f("machdep.c")) sets up the clock's variables (#l("extern\tunsigned long long clkcval;\t/* when the clock is next due */"), #l("extern\tunsigned clkreload;\t\t/* counts per tick */")).
On each tick `clock` (#f("clock.c")) adds `clkreload`, the timer's
frequency divided by `HZ`, to the deadline `clkcval`. It also adds the
remainder of that division, `clkrem`, to `clkfrac`, and lengthens a
tick by one count whenever `clkfrac` reaches `HZ`, so that each second
lasts exactly the timer's frequency. `l1tab` and
`l1pa` (#l("extern\tunsigned long long *l1tab;\t/* user first-level tables */"), #l("extern\tunsigned l1pa;\t\t/* their physical address */")) locate the first-level page tables of the processes,
one for each slot of the process table. `l1tab` gives their kernel
address, and `l1pa` the physical address which the hardware needs.
`startup` (#f("machdep.c")) takes them from RAM, and `sureg`
(#f("ureg.c")) fills them.

#lines-to("dev_t getmdev(void);", lead: true)

#lines-to("struct clist; struct map; struct text; struct tty; struct uprof;")

The list which follows is entirely new. Each procedure which is
called from another file, or before its definition, is declared once
here, with a prototype, instead of being declared in each calling file
or not at all. The routines are grouped by return type and sorted by
name.

#lines-to("int\taccess(struct inode *ip, int mode);")

The routines which return a value.

#lines-to("#define\tfuibyte\tfubyte")

On a PDP-11 with separate instruction and data spaces, reading a
program's text required different instructions (`mfpi`, `mtpi`) from
reading its data, hence v7's separate routines `fuibyte`, `suiword`,
and so on. The ARM has one address space, so the I-space forms are
simply aliases, and their callers (`passc`, `cpass`, `iomove`,
`procxmt`) keep v7's text.

#lines-to("/*")

Counters for `iostat`, kept by the clock and by the drivers, which
set and clear their bit of `dk_busy` around each transfer. Like the
variables above, they are `extern` here and defined in #f("main.c").

#lines-to("/*", after: "extern\tlong\ttk_nout;")

The table of system calls, defined in #f("sysent.c") and indexed by
`trap` with the number of the call. The handler (#l("void\t(*sy_call)(void);\t/* handler */")) was declared in
v7 as returning `int`, by default. The handlers return nothing; their
results go back to the user through `u.u_r`. It is now a pointer to a
`void` function of no arguments, and every handler is defined so.

#lines-to(none)
#source("/usr/sys/h/seg.h")

In v7, #f("seg.h") held the addresses of the PDP-11 memory management
registers (the KT-11 unit) and the bits of a segment descriptor. The
PDP-11 divided each address space into eight segments of up to 8~KB. Each was described by a pair of
registers: an address register, giving the
base in 64-byte units, and a descriptor register, giving the length and the
access rights. None of that hardware exists here, and v7's definitions
for it are gone. What remains of v7's file is its first comment,
corrected to describe what follows, and the two access rights, followed
by the definitions which the port adds.

#lines-to("#define\tRO\t0300\t\t/* access abilities */")

`RO` and `RW` (#l("#define\tRO\t0300\t\t/* access abilities */"), #l("#define\tRW\t0100")) are the access rights which callers pass to
`estabur` (#f("ureg.c")) for the text: read-only, or read and write.
On the PDP-11 they were the access field of a descriptor register. Here
they are the access permission bits of a long-format page entry, bits 6
and 7, and `ptbuild` (#f("ureg.c")) ors them into the entries which map the text. The value 11 lets user
mode read the page but not write it, and 01 lets it do both. In either
case the kernel may do both. The data and the stack are
always mapped `RW`. The page entries' other bits are `PGUSER` (12,
below).

#lines-to("#define\tUENTRY_SIGTRAMP\t8")

`UENTRY_SIGTRAMP` (#l("#define\tUENTRY_SIGTRAMP\t8")) is the address of the signal trampoline
(`sendsig`, #f("machdep.c")).

`PGADDR` (#l("#define\tPGADDR(c)\t((char *)(((unsigned)(c)<<12)+coreoff))")) converts a page number into a kernel address. On the
PDP-11, v7's unit number was a physical address divided by 64, and the
kernel reached it by loading a segmentation register. Here a page
number is a physical address divided by 4096, and all of
RAM is mapped into the kernel's address space at a fixed distance,
`coreoff`, from its physical address, so the conversion is
a shift and an addition. The shift is done on an `unsigned` value, since
the MP135 machine's RAM lies above 0x80000000, where an `int` would
overflow. Every place where v7 reached RAM by unit number
(`copyseg`, `clearseg`, `swap`, `physio`) goes through this macro.

#lines-to("#define\tBLK_KERN\t0x701ULL")

The remainder are constants of the ARM's long-descriptor tables
(#f("low.s")), used by `machine_init` (#f("machdep.c")), by `sureg`
(#f("ureg.c")), and by the table of regions which `mkconf` writes into
#f("qemu/c.c"). Each entry is 64~bits, of which the attributes occupy
the low twelve and the top twelve.

`BLK_KERN` (#l("#define\tBLK_KERN\t0x701ULL")) describes a 2~MB block of RAM, mapped for the kernel. Read from the right, its fields are:

- block type (1),
- attribute index 0 (bits 2 to 4), which `MAIR0` defines as normal
  memory, cached write-back,
- access permission 00 (bits 6 and 7), read and write for the kernel
  and nothing for user mode,
- inner shareable (0x300),
- the access flag (0x400), without which the first reference would
  fault.

It is global (bit 11 clear), so that its
translations survive a change of the user's tables.

`BLK_DEV` (#l("#define\tBLK_DEV\t0x60000000000405ULL")) describes a block of device registers:

- attribute index 1, device memory, which is neither cached nor
  touched speculatively,
- the same permission and access flag,
- in the top word, the "execute never" bits for both privileged and
  user mode (bits 53 and 54), which keep the processor from fetching
  instructions from device memory, even speculatively, as the
  architecture requires.

Its shareability is
ignored. Both kinds of block are reached only through the kernel's
table, at addresses above `USRSIZE`, and user mode cannot reach them at
all, whatever their permission bits.

`PTE_TAB` (#l("#define\tPTE_TAB\t3")) is the type of an entry which points to a table of the
next level, and also the type of a page entry at the third level.
`PGUSER` (#l("#define\tPGUSER\t0xf03")) is the rest of every user page entry, to which `ptbuild`
(#f("ureg.c")) adds the access bits:

- page type (3),
- attribute index 0, normal write-back RAM,
- shareable (`0x300`),
- the access flag (`0x400`),
- "not global" (`0x800`), which lets `ttbset` (#f("mch.s")) discard
  the user's translations alone.

It is the same on
both machines. `PGSHIFT` and `PGSIZE` (#l("#define\tPGSHIFT\t12"), #l("#define\tPGSIZE\t4096")) describe the 4~KB page,
the unit of the user mapping, and `PTPGB` (#l("#define\tPTPGB\t(512*512)")) the number of pages in a
gigabyte, the reach of a second-level table. `struct memregion` (#l("struct memregion { unsigned va, start, end; unsigned long long attr; };")) is the type of
the table `board_map`, which `mkconf` writes into #f("qemu/c.c") from the
`map` lines of the machine's configuration file. Each entry is a range of
physical addresses, the kernel address at which it is to be mapped, and
the block descriptor bits to use.

#lines-to(none)
#source("/usr/sys/conf/low.s")

#f("low.s") takes the place of v7's `l.s`, the "low core" file. On the
PDP-11, `l.s` filled the bottom of physical memory with the interrupt vectors, a new PC and PS for each trap and each
device. It also supplied, for every device, a two-instruction stub which entered the common routine
`call` with the address of the C handler. `mkconf` generated it anew for
each configuration. None of that survives. The ARM has eight exception
vectors, and only one of them serves all devices; the interrupt
controller (GIC) is asked which device interrupted, and `irq`
(#f("machdep.c")) looks the answer up in `intrtab`, which `mkconf` now
writes into #f("qemu/c.c"). So #f("low.s") is the same for every configuration. It holds what in v7 was split between `l.s` and the
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

_Calling Convention._ Assembly language and C meet under the ARM
Procedure Call Standard (AAPCS). The first four arguments of a function
are passed in `r0` to `r3`, and its result is returned in `r0`. A
function may change `r0` to `r3`, `ip` (`r12`), and `lr`, but must
preserve `r4` to `r11` and `sp`. `bl` calls a function, leaving the
return address in `lr`, and `bx lr` returns.

The processor arrives at `_start` (#l("_start:")) from the boot loader in SVC mode.
Interrupts and fast interrupts are masked at once (#l("cpsid if", after: "_start:")), the analogue of
v7's `spl 7` state at the start.

The system control register `SCTLR` is then read, and five bits are
cleared: the instruction cache (bit 12), the data cache (2), branch
prediction (11), "high vectors" (13), which would place the vectors at
`0xffff0000`, and the MMU itself (0). `isb` makes sure that the following instructions are fetched under the
new setting.

The kernel is linked to run above 0xc0000000, but QEMU, or on the
MP135 machine the boot ROM, has put it at its physical address and
started it there. An absolute address taken from the program is therefore wrong by a
constant. Until the code has turned the MMU on and jumped to its kernel
address (#l("ldr pc, =1f")), it must be position-independent. It may branch relative
to the PC, and load constants, but may use the address of a variable
only after correcting it.

The constants at the top (#l(".set BLK_KERN, 0x701")--#l(".set PSR, 16")) repeat those of #f("seg.h"),
#f("param.h"), and #f("reg.h"), and must be kept equal to them by hand.

#lines-to("mov r0, #0")

The TLB (the cache of address translations), the instruction
cache, and the branch predictor are invalidated. The data cache is dealt with
below. `dsb` waits for these operations to finish.

#lines-to("adr r4, _start")

`adr` (#l("adr r4, _start")) forms the address of `_start` from the PC, and so yields
where the kernel actually is; the literal `=_start` (#l("ldr r0, =_start", after: "adr r4, _start")) is the address
at which it was linked. Their difference, kept in `r4`, turns any
kernel address into a physical one.

#lines-to("ldr r0, =__bss_start")

The `bss` area is cleared, a word at a time, at its physical address. The bounds are symbols defined by the
linker script. The boot stack and the boot translation tables lie in
the area being cleared; this is harmless, since nothing has yet been
put in them.

#lines-to("ldr r5, =kl2")

The MMU is used in its "long-descriptor" format. Its tables have 8-byte entries. A first-level entry maps a gigabyte, a
second-level entry two megabytes, and a third-level entry a page. An
entry at either of the first two levels may map its whole range
directly, as a "block", instead of pointing to a table of the next
level.
The format can divide the address space between two tables, one for
the low addresses and one for the high, which the short-descriptor
format of the earlier ARMs cannot do at a three-gigabyte boundary; that
is why it is used. The kernel's table `kl2` (#l("kl2:")) is a second-level
table of 512~entries, which together map the gigabyte from 0xc0000000.

Here `kl2` receives the blocks which hold the kernel itself, from
`_start` to the end of `bss`. `r0` runs over the numbers of the 2~MB
blocks, `r1` is the last, and each entry is the block's physical
address, the kernel address plus `r4`, or'ed with `BLK_KERN` (38,
#f("seg.h")). `ubfx` takes the
low nine bits of the block number, the index in the table. The upper
word of each entry stays zero. The difference in `r4` is a multiple of
2~MB on both machines (#f("qemuconf")), as it must be for a block to map
the kernel exactly.

#lines-to("ldr r6, =bootl1")

`bootl1` (#l("bootl1:")) is a first-level table for the low addresses, with a
single entry: the gigabyte which contains the kernel's physical
address is mapped onto itself. When the MMU is turned on, the next
instructions are still fetched at physical addresses, and this mapping
keeps them in place; `machine_init` removes it.

#lines-to("mrc p15, 0, r1, c1, c0, 1")

Bit 6 of the auxiliary control register `ACTLR`, the "SMP" bit, is
set. It makes the processor take part in the protocol which keeps
caches consistent with one another, and the Cortex-A7 requires it
before the caches are enabled, even when, as here, there is only one
processor.

#lines-to("mcr p15, 2, r2, c0, c0, 0")

The cache size selection register is set to 0 (#l("mcr p15, 2, r2, c0, c0, 0")), the level 1 data
cache, so that the next read describes it. The cache size
identification register `CCSIDR` gives the logarithm of the line size
in bytes (`r1`), the number of ways less one (`r3`), and the number of
sets less one (`r7`). `ip`, the count of leading zeros of `r3`, is the
shift which puts a way number into the top bits of a word.

#lines-to("1:\tmov r8, r3")

A line of the data cache is found by its set and its way: the cache is
divided into sets, and each set holds one line from each of its ways.
`DCISW` (`c7, c6, 2`, 73) discards the line named by its operand, which
carries the way number in its top bits and the set number just above
the bits that select a byte within a line. The outer loop counts the
sets down, the inner the ways. The lines are discarded, not written
back: the cache has been off since `_start`, so whatever it still holds
is stale, and writing it back would overwrite memory.

#lines-to("ldr r0, =0x4ff")

The memory attribute register `MAIR0` (#l("ldr r0, =0x4ff"), #l("mcr p15, 0, r0, c10, c2, 0")) defines the attributes which entries name by number. Attribute 0 is
normal memory, cached write-back in both inner and outer caches
(`0xff`). Attribute 1 is device memory (`0x04`), which is neither
cached nor accessed speculatively. The translation
table base control register `TTBCR` (#l("ldr r0, =0xb5023500"), #l("mcr p15, 0, r0, c2, c0, 2")) selects the long format (bit 31) and divides the address space. With
`T1SZ` 2, the top gigabyte is translated through `TTBR1`, starting at
the second level, and the rest, from 0 to 0xbfffffff, through `TTBR0`.
Table walks for both go through the write-back caches and are
shareable, as the kernel's own writes to the tables are. The 64-bit `TTBR0` and `TTBR1` (#l("mcrr p15, 0, r6, r2, c2"), #l("mcrr p15, 1, r5, r2, c2")),
written with `mcrr`, receive the physical addresses of `bootl1` and
`kl2`; `r2` is still zero, the upper word.

#lines-to("isb")

In `SCTLR`, the MMU (bit 0), the data cache (2), and the instruction
cache (12) are turned on together. The load of the PC (#l("ldr pc, =1f"))
then jumps from the physical address, where the identity mapping kept
execution going, to the kernel address of the next line.

#lines-to("ldr sp, =stack_top")

A provisional stack, at the start of the kernel's `bss` (#l(".balign 8")--#l("stack_top:")),
serves until the u-area of process 0 can be mapped.

The vector base address register `VBAR` is loaded with the address of
`vectors` (118), the table through which the processor takes
exceptions. The table must be aligned on 32~bytes (#l(".balign 32")).

#lines-to("mrc p15, 0, r0, c1, c0, 2")

The floating point unit, VFPv4 with the Advanced SIMD extension (NEON)
on both machines, is off at reset. It is reached as coprocessors 10 and
11, and the coprocessor access control register `CPACR` (#l("mrc p15, 0, r0, c1, c0, 2")--#l("mcr p15, 0, r0, c1, c0, 2")) opens
both to privileged and user mode. After the `isb` (#l("isb", after: "mcr p15, 0, r0, c1, c0, 2")), which makes this
and the new `VBAR` take effect, the enable bit of the floating point
exception register `FPEXC` (bit 30) is set (#l("mov r0, #(1 << 30)"), #l("vmsr fpexc, r0")). The unit is left
on for good. User programs execute its instructions directly; the kernel
is compiled without them (#f("sys.mk")), so the floating point registers always hold
the state of the current process, which `savfp` and `restfp`
(#f("mch.s")) move to and from its u-area.

#lines-to("bl machine_init")

`machine_init` (#f("machdep.c")) then does the rest, in order:

+ It maps the device registers and starts the console.
+ On the MP135 machine it brings up the DDR memory.
+ It maps the rest of RAM and clears the tables which live in it.
+ It maps the u-area of process 0 at `UBASE`.
+ It removes the identity mapping.

The stack pointer is then moved (#l("mov sp, r0")) to the top of the u-area, whose
address `machine_init` returns: `UBASE` (0xffe00000) plus the
`USIZE` page of the area, 4096~bytes. The sum is left to C, so that
`UBASE` and `USIZE` are written down in one place only. From now on the SVC stack is always the kernel stack of the
current process, at the same virtual address in every process.

`main` (#f("main.c")) is called (#l("bl main")). Process 0, the swapper, never
returns from it; it ends in `sched`. Process 1, which will become init,
does return here. `newproc` makes it as a copy of process 0, kernel stack
included, so it continues from the same point in `main`, which copies
`icode` to user address 0 for it and returns.

#lines-to("mov r0, #0x10")

_Return to User Mode._ `spsr` is set to `0x10`, user mode
with both interrupt masks clear, `lr` to 0, and `movs pc, lr` copies
`spsr` into `cpsr` while it jumps: the standard ARM return from an
exception. No user stack pointer is set: `icode` needs none,
and the `exec` it performs gives `/etc/init` its own.

#lines-to(".balign 32", lead: true)

_Exception Vectors._ Each entry is an instruction, not an address, and
is executed in the mode which the exception selects; here each is a
branch.

#lines-to("svc_entry:", lead: true)

_System Call Entry._ The processor arrives in SVC mode with
interrupts masked, `lr` holding the address after the `svc` and `spsr`
the user's `cpsr`. The task is to lay down on the kernel stack a frame
of all the user's registers, in the order which #f("reg.h") describes,
and to hand its address to C.

`srsdb sp!, #0x13` (#l("srsdb sp!, #0x13", after: "svc_entry:")), "store return state", pushes `lr` and `spsr`
onto the stack of the mode named (SVC), and updates that stack pointer.
Room is then made for fifteen words, and `stmia sp, {r0-r14}^`
stores `r0` to `r14`. The `^` makes the instruction store the *user*
mode's banked `sp` and `lr`, not SVC's, without a change of mode. The
architecture forbids writeback with this form, hence the separate `sub`.

#lines-to("mov r0, sp")

The frame is thus seventeen words: `r0`--`r12` at 0 to 48, the user `sp`
at 52, the user `lr` at 56, the return PC at 60, and the saved status at
64. This is why `SP`, `PC`, and `PSR` in #f("reg.h") are 13, 15, and 16:
`u.u_ar0[SP]` is the user stack pointer, `u.u_ar0[PC]` the PC.

`trap` (#f("trap.c")) is called (#l("bl trap")) with one argument, the address
of the frame of saved registers just built, which `mov r0, sp` (#l("mov r0, sp", after: "svc_entry:"))
puts in `r0`, the register for a function's first argument. `trap`
keeps it in `u.u_ar0`, through which the system calls reach the user's
registers. Interrupts are enabled (#l("cpsie i", after: "svc_entry:")) for the duration of the system
call and masked again afterwards (#l("cpsid i", after: "bl trap")). The return is shared with the
other traps (#l("2:", after: "bl user_trap_handler")).

#lines-to("irq_entry:", lead: true)

_Interrupt Entry._ The ARM enters IRQ mode with `lr` set to four
bytes beyond the instruction to be resumed, a convention of the
architecture, so line #l("sub lr, lr, #4", after: "irq_entry:") subtracts four.

#lines-to("srsdb sp!, #0x13")

The return state is then pushed, not on an IRQ stack, but on the SVC
stack, and the processor changes to SVC mode itself with both masks
set. IRQ mode therefore needs no stack of its own.
If the interrupt came from user mode, the SVC stack is empty and the
frame goes at the top of the u-area; if it came from the kernel, the
frame goes below whatever the kernel was using.

#lines-to("sub sp, sp, #PC*4")

The registers are then saved on the kernel stack, as for a system call.
When the interrupt came from a user program, all of its registers, `r0`
to `r14`, must be saved. But the processor is by now in SVC mode (#l("cpsid if, #0x13", after: "irq_entry:")),
which has its own banked `r13` and `r14`, so a plain `stmia` would store
SVC's. The `^` form stores the User mode registers, whether the
interrupt came from the kernel or from user space. The return's `ldmia`
(#l("ldmia sp, {r0-r14}^")), with the same `^`, loads them back unchanged.

SVC's own `sp` need not be saved. The entry lowers it by 8~bytes in
`srsdb` and by 60 in the `sub`, and the return raises it by the same
amounts (#l("add sp, sp, #PC*4"), #l("rfeia sp!")).

#lines-to("mov r5, lr")

SVC's `lr`, on the other hand, is overwritten by the `bl irq` (#l("bl irq")).
When the kernel is interrupted it may hold a live return address, so it
is kept in `r5` (#l("mov r5, lr"), #l("mov lr, r5")), which `irq` must preserve.

#lines-to("mov r0, sp")

`irq` (#f("machdep.c")) asks the GIC for the interrupt number,
and calls `clock` or the device handler.

#lines-to("mov lr, r5")

If the interrupted program was in user mode (the mode field of
the saved status, at offset 64, is `0x10`) and `runrun` is set, meaning
a process with a better priority is ready to run (#f("slp.c"),
#f("clock.c")), the current process must give up the processor before
it returns. The code then jumps to the call of `user_trap_handler`
which the traps below use (#l("1:", after: "mrc p15, 0, r2, c6, c0, 0")), with signal 0 and address 0 (150,
151). Signal 0 posts nothing, so the handler does only what it does at
the end of every trap: it takes any pending signal (`issig`, `psig`),
recomputes the priority (`setpri`), and gives up the processor
(`qswtch`). Otherwise the frame is unloaded at once (#l("2:", after: "bl user_trap_handler")). Without this
test a process which never made a system call would never be
preempted, nor see a signal.

#lines-to("badtrap:", lead: true)

`badtrap` catches the two vectors which should never be used. It
changes to SVC mode with interrupts masked, so that it runs on the
kernel stack, and calls `panictrap` (#f("machdep.c")), which panics.

#lines-to("undef_entry:", lead: true)

The remaining exceptions all become signals to the process. The
architecture sets `lr` past the instruction which caused the exception:
four bytes for an undefined instruction or a prefetch abort, eight for a
data abort. The abort entries subtract that (#l("sub lr, lr, #4", after: "pabort_entry:"), #l("sub lr, lr, #8")), so that the
saved PC addresses the offending instruction, and the return executes it
again. After a data abort on the stack, the handler grows the stack,
and the load or store that failed then succeeds. For an undefined
instruction `lr` is left alone, and the saved PC addresses the next
instruction: a handler of the signal which returns, an emulator of a
missing instruction, for example, continues there instead of meeting
the same instruction again.
In Thumb state, which the library's arithmetic routines use, `lr` is
only two bytes past the instruction, the next one only if the
instruction was 16~bits long; `user_trap_handler` (#f("trap.c"))
adds the other two for a 32-bit one.
An undefined instruction yields signal 4 (`SIGINS`), either abort
signal 11 (`SIGSEG`).

The save is repeated, rather than shared by all three, because no register is free to carry the signal number to a common
save. `r0` to `r12` are the user's until they have been stored, and the banked `sp`
and `lr` of the abort and undefined modes are left behind by the change
to SVC mode.

The frame is built exactly as for an interrupt (#l("srsdb sp!, #0x13", after: "undef_entry:")--#l("stmia sp, {r0-r14}^", after: "undef_entry:"), #l("srsdb sp!, #0x13", after: "pabort_entry:")--#l("stmia sp, {r0-r14}^", after: "pabort_entry:"),
#l("srsdb sp!, #0x13", after: "sub lr, lr, #8")--#l("stmia sp, {r0-r14}^", after: "sub lr, lr, #8")). Only then is the signal number loaded, into `r0` (164, 173,
187), and `user_trap_handler` receives the signal, the frame, and in
`r2` an address (#l("1:", after: "mrc p15, 0, r2, c6, c0, 0")--#l("bl user_trap_handler")). A prefetch abort passes zero (#l("mov r2, #0", after: "pabort_entry:")), and so does
an undefined instruction (#l("mov r2, #0", after: "mov r0, #SIGINS")). The handler reads the address only for
`SIGSEG`, but it is given a defined value in every case, never the
user's `r2`, which the `stmia` has saved but left in the register. The handler
panics, after printing the fault address and status (`dfar`, `dfsr`,
#f("mch.s")), if the exception came from the kernel.

#lines-to("dabort_entry:")

A data abort taken by the kernel may be one which it expects. While one
of the routines which reach user memory runs, `nofault` (#f("mch.s"))
holds the address at which it wants to continue if a user reference
fails. That address
is then written over the saved PC (#l("ldr r0, =nofault")--#l("bne 2f", after: "strne r0, [sp, #PC*4]")), and the exception returns
there at once, by the common return below, without calling C. The
saved registers are restored as they were at the fault, and SVC mode's
own `lr`, which C would have destroyed, is never touched. A fault in
user mode cannot meet `nofault` set, since the routines clear it
before they return.

#lines-to("mov r0, #SIGSEG")

For a data abort the address is the one the
instruction failed to reach, read from the fault address register
`DFAR` (#l("mrc p15, 0, r2, c6, c0, 0")), by which the handler decides whether the stack should
grow (#f("trap.c")).

#lines-to("1:")

`user_trap_handler` runs with interrupts enabled (#l("cpsie i", after: "mov r1, sp")). The work it may do, the copying of a grown stack or the
writing of a core image, would otherwise hold off the clock and the
console for its whole length. Unlike v7, the call made for `runrun` also runs with
interrupts enabled: the interrupt has been acknowledged (#f("machdep.c")), and a further one
nests on the SVC stack as it would over any other kernel code.
Interrupts are masked again before the frame is unloaded (#l("cpsid i", after: "bl user_trap_handler")), since
the saved state must not be disturbed between the `ldmia` and the
`rfeia`.

#lines-to("2:")

_Common Return._ `ldmia ... ^` (#l("ldmia sp, {r0-r14}^")), without the PC in the list, loads the User mode
registers, as the `stmia` stored them. `rfeia sp!` (#l("rfeia sp!")),
"return from exception", pops the PC and the saved status together into
`pc` and `cpsr`, so the mode, the interrupt mask, and the condition flags
of the interrupted program are restored with its PC in one step.

#lines-to(".bss", lead: true)

_Boot Stack and Tables._ The boot stack, one page, is used only until
`_start` moves the stack pointer to the u-area (#l("mov sp, r0")). The deepest chain
of calls from `machine_init`, through a `panic` and its `printf`, needs
under 700~bytes, and a fault taken during boot under 1.4~KB.
Interrupts stay masked until long after the switch, so none lands on
this stack. `kl2` is the kernel's
second-level table and stays in use after boot. It must be aligned on
4~KB. `bootl1` is the first-level table which holds the boot identity
mapping. It needs 32-byte alignment and follows `kl2`.

#lines-to(none)
#source("/usr/sys/conf/mch.s")

#f("mch.s") holds the routines which C cannot express, because each
needs particular instructions. They come in these groups:

- the memory barrier,
- the interrupt mask,
- the timer,
- `save` and `resume`,
- the caches,
- the TLB and the user's page table,
- the transfers to and from user memory,
- the idle loop,
- the floating point registers,
- the fault registers.

The
file ends with three variables.

The first five lines repeat constants of #f("seg.h") and #f("param.h"),
and must be kept equal to them by hand.

#lines-to("dmbsy:")

_Memory Barrier._ `dmbsy` is a data memory barrier: every memory access before it is
observed before any after it. The virtio disk driver (#f("virtio_blk.c"))
offers a request to the device by writing descriptors of the request,
then a counter in memory which tells the device how many requests have
been offered, then a notification register. It uses the barrier to make
each of these writes visible to the device before the next. On an
interrupt it uses it again, to read the completed request only after
the counter which reports it. The
PDP-11 performed accesses in program order and needed nothing of this
kind.

#lines-to("intr_enable:")

_Interrupt Masking._ The ARM core has a single interrupt mask bit, `I`
(bit 7 of `cpsr`). `intr_enable` (#l("intr_enable:")) clears it and `intr_disable` (#l("intr_disable:"))
sets it. Every interrupt handler runs with interrupts masked.

`intr_disable` returns the previous `cpsr` in `r0` (#l("mrs r0, cpsr")), so that
`s = intr_disable(); ... intr_restore(s);` puts back the caller's
state. `intr_restore` (#l("intr_restore:")) looks only at the `I` bit of the value it
is given.

#lines-to("cntfrq_get:", lead: true)

_Generic Timer._ `clkstart` (#f("machdep.c")) and `clock`
(#f("clock.c")) use these routines to produce an interrupt every `1/HZ`
second, a sixtieth (`HZ`, #f("param.h")), and the console's `putchar`
(#f("pl011.c"), #f("otg.c")) times its wait with `cntvct_get`.
`cntfrq_get` reads `CNTFRQ`, the counter frequency.

#lines-to("cntvct_get:", lead: true)

`cntvct_get` reads `CNTVCT`, the 64-bit time counter that increases at
`CNTFRQ` counts per second from reset, into `r0` and `r1`, the
registers in which a C function returns an `unsigned long long`. The
`isb` before it keeps the processor from reading the counter ahead of
the instructions which precede the call.

#lines-to("cntv_cval_set:", lead: true)

The processor has two timers, and both are driven by the same counter.
The physical timer compares its deadline with the counter itself. The
virtual timer compares it with the counter minus an offset. Only a
hypervisor can change that offset, and it does so to hide from a guest
system the time during which the guest was not running. There is no
hypervisor here, so the offset never changes, and the virtual timer
advances exactly as the physical one does. The kernel uses the virtual
timer because its interrupt has the same number, 27, on both machines.
The physical timer's number depends on whether the processor runs in
the Secure or the Non-secure state.

`cntv_cval_set` loads the timer's compare register from the
`unsigned long long` argument, passed in the same two registers. The
timer interrupts once the count reaches it. The `isb` makes the new
setting take effect before the routine returns.

#lines-to("cntv_ctl_set:", lead: true)

`cntv_ctl_set` writes the timer's control register: 1 enables it, with
the interrupt unmasked. Again the `isb` makes the setting take effect
before the routine returns.

#lines-to("save:", lead: true)

_Process Switching._ `save` and `resume` are the means by which the
kernel passes the processor from one process to another. `save` records
where the current process is, and `resume` makes another process
current and continues it from the point its own `save` recorded. Which
process runs next is decided elsewhere, by `swtch` (#f("slp.c")). These
two routines only carry the decision out. A process also uses them to
jump back to an earlier point of its own, to abandon an interrupted
system call or to continue after `expand` has moved it.

`save(lab)` records in `lab` (a `label_t`, #f("param.h")) the registers
which a function must preserve, `r4` to `r11` and `sp`, together with
the return address in `lr`, ten words in all, and returns 0.

#lines-to("resume:", lead: true)

`resume(p_addr, lab)` maps the u-area of process `p_addr` at `UBASE` in
place of the current one, and does not return to its caller. Instead it
reloads the registers which `save` stored in `lab`, so that the earlier
call of `save` appears to return a second time, now with the value 1. The 1 means that the process has been resumed. A
return of 0 means that the registers were saved just now.
Interrupts are masked first (#l("cpsid i", after: "resume:")).

#lines-to("ldr r2, =kl3u")

Every process's u-area appears at the same address, `UBASE`.
Switching processes therefore comes down to rewriting the page entries
for `UBASE`, the first `USIZE` of `kl3u`, to point at the new process's
u-area (#l("mov r0, #USIZE", after: "orr r3, r3, ip")--#l("bne 1b", after: "1:\tstr r3, [r2], #8")).

The data cache need not be flushed. It is tagged by physical address,
so a line cached through the old mapping can never be found through
the new one.

#lines-to("dsb ish")

A processor does not wait for a store to reach the cache. It puts the
store into a small store buffer and goes on with the next instruction,
and the buffer drains into the cache shortly after. The processor's own
loads look in the buffer, so a program always sees its own stores at
once. The MMU, which reads the page tables by itself, is not guaranteed
to, so it may for a while still find the old entry. `dsb` (#l("dsb ish", after: "1:	str r3, [r2], #8")) waits
until the buffer has drained. Similarly, the TLB, the MMU's own cache of translations, may still hold
the old translation of `UBASE`, and `TLBIMVAA` discards it, page by page (#l("ldr r3, =u")--#l("bne 1b", after: "1:\tmcr p15, 0, r3, c8, c7, 3")). The
second `dsb` and the `isb` (#l("dsb ish", after: "1:	mcr p15, 0, r3, c8, c7, 3"), #l("isb", after: "1:\tmcr p15, 0, r3, c8, c7, 3")) wait until the discard has taken
effect.

The user part of the address space, below 0xc0000000 (`USRSIZE`,
#f("param.h")), still maps the old process. `sureg` (#f("ureg.c"))
switches it after the switch is complete.

#lines-to("ldmia r1, {r4-r11}")

`swtch` (#f("slp.c")) usually calls `resume(p->p_addr, u.u_rsav)`. The second
argument is the address of `u.u_rsav`, which lies at a fixed place in
the page at `UBASE`. Before the switch, that place holds the old
process's saved registers. After the switch, the same place holds the
new process's, since the new process's u-area now appears at `UBASE`.
`resume` reads `lab` only after the switch (#l("ldmia r1, {r4-r11}")--#l("ldr r2, [r1, #36]")), so it gets the new
process's registers, the ones it saved there with `save(u.u_rsav)` when
it last gave up the processor.

From the stores (#l("1:	str r3, [r2], #8")) until `sp` is reloaded (#l("ldr sp, [r1, #32]")), `sp` still holds
the old process's stack address, but `UBASE` now shows the new
process's u-area. Anything pushed there would overwrite the new
process's kernel stack. So the routine uses no stack, and interrupts,
which would push a frame, stay masked. Once the new stack is in place,
`intr_enable` (#l("bl intr_enable")) unmasks them. `intr_enable` is a call, which
overwrites `lr`, so the saved `lr` is kept in `r2`, which `intr_enable`
leaves alone, and the return is through it (#l("bx r2")). Without the call,
interrupts would stay masked until the process next called
`intr_enable` or `intr_restore`, or returned to user mode. After
`expand` had moved a process, for instance, they would be held off for
the rest of the system call.

#lines-to("dcinval:", lead: true)

_Cache Maintenance._ The SD card controller of the MP135 machine
(#f("sd.c")) moves data between the card and memory by itself, by DMA
(direct memory access), and does not look in the data cache. Before a
transfer the driver calls `dcflush` on the buffer, which writes the
buffer's dirty lines to memory and discards them, so that the
controller reads what the processor wrote. After a read it calls
`dcinval`, which discards the buffer's lines without writing them, so
that the processor finds what the controller wrote and not stale lines.

#lines-to("arm_sync_icache:", lead: true)

`arm_sync_icache` makes instructions just written to memory visible to
instruction fetch. The kernel must call it whenever it writes
instructions that will be executed: a text read in from a file or back
from the swap area, the signal trampoline, `icode`, and a word that a
debugger stores into a text. A program's data and stack are never
executed, so they need no such care.

The new instructions are in the data cache, but instruction fetch does
not look there. It reads from the first level of memory that both kinds
of access share, called the point of unification, which on the
Cortex-A7 lies beyond the level 1 data cache. So each line of the range
is first written out to that point. The instruction cache may still
hold the old contents, and it is discarded entire rather than line by
line. It finds lines by virtual address, and the program will run the
text at its user addresses, not at the kernel addresses through which
it was written. The branch predictor remembers branch targets of the
old instructions, and is discarded with it.

#lines-to("dline:", lead: true)

`dline` serves all three routines. The line size differs between
processors, so it reads it from the cache type register `CTR`. It
rounds the start down to a line boundary, and returns the end of the
range in `r1`. The callers keep their return address in `r12` across
the call, which overwrites `lr`.

#lines-to("tlbflush:")

_Translation Tables._ `tlbflush` invalidates the whole TLB (`TLBIALL`) and the branch
predictor. `machine_init` (#f("machdep.c")) calls it after it changes
the kernel's own mapping.

#lines-to("ttbset:")

`ttbset(a)` makes the first-level table at physical address `a` the
user's. `TTBR0` is 64~bits wide in the long format, and is loaded from
two registers (#l("mcrr p15, 0, r0, r1, c2	@ TTBR0")). The upper one, zero, holds the address space
identifier, so every process runs with identifier 0. Each TLB entry is
either global, belonging to every address space, or tagged with the
identifier of one. The kernel's pages are global and the user's are
not, so discarding the entries of identifier 0 (`TLBIASID`, 140)
removes the old process's translations and keeps the kernel's. The
branch predictor, which remembers branch targets in the old mapping, is
discarded too. The caches are left alone, since they do not depend on
the mapping. The first `dsb` makes sure that `sureg`'s stores to the
new tables have left the store buffer, and the tables need no cleaning,
since the MMU reads them through the data cache. `sureg` (#f("ureg.c"))
calls `ttbset` at every process switch, and whenever it has rebuilt the
current process's tables.

#lines-to("fubyte:")

_User Memory._ These routines move data between the kernel and the
current user process. The ARM's `ldrt` and `strt`, and their byte forms,
load and store with the permissions of user mode even when the kernel
executes them. A user address which is not mapped, or which only the
kernel may touch, therefore faults.

`fubyte` and `fuword` return the byte or word at a user address, or -1;
`subyte` and `suword` store one, and return 0 or -1. The byte is loaded
without sign extension, whatever the signedness of `char`. The loaded
value goes first into `r1` (#l("ldrbt r1, [r0]"), #l("ldrt r1, [r0]")): a load which wrote back to its
own base register would be unpredictable, and `ldrt` and `strt` always
write back. v7 distinguished `fuibyte` from `fubyte`, instruction space
from data space; #f("systm.h") makes the former names aliases of these.

#lines-to("copyin:")

`copyin(from, to, n)` and `copyout` move `n` bytes from a user address
to a kernel one, and back, and return 0, or -1 if any user reference
faults. As v7's did, they move words when both addresses and the count
are multiples of the word (#l("1:	subs r2, r2, #4", after: "copyin:")--#l("b 1b", after: "copyin:"),
#l("1:	subs r2, r2, #4", after: "copyout:")--#l("b 1b", after: "copyout:")), and bytes otherwise
(#l("2:	subs r2, r2, #1", after: "copyin:")--#l("b 2b", after: "copyin:"),
#l("2:	subs r2, r2, #1", after: "copyout:")--#l("b 2b", after: "copyout:")). Only the user side of each move uses `ldrt` or
`strt`.

#lines-to("uok:")

A fault on a user address must not panic the kernel. The routine
should instead return -1. So each routine first stores the address of `uerr` (#l("uerr:")) in
`nofault` (#l("nofault:")). If one of its user references faults, the data abort
handler (#f("low.s")) finds `nofault` set and continues at `uerr` rather
than at the faulting instruction. `uerr` clears `nofault` and returns
-1. A routine which completes clears it at `uok` (#l("uok:")) and returns its
value. Only these routines set `nofault`, so any other fault in the
kernel is still a `panic`. `uerr` finds the address of `nofault` still
in `r3`, since the abort restores the registers as they were at the
fault.

#lines-to("idle:")

_Idle._ `idle` waits for an interrupt. `swtch` calls it with interrupts masked,
and `wfi` ("wait for interrupt") halts the processor until an interrupt
is pending, even a masked one. `cpsie i` then lets it be taken at once,
so the PC it saves is always that of `waitpc` (#l("waitpc:	cpsid i")). `waitloc` (255,
256) holds that address, and `clock` (#f("clock.c")) compares it with
the interrupted PC to count the time spent idle.

#lines-to("savfp:")

_Floating Point._ `savfp` and `restfp` store and load the floating
point state of the current process. On the ARM the state is the status
and control register `FPSCR`, which holds the rounding mode and the
cumulative exception flags, and the 32 double registers `d0` to `d31`,
which the processor's vector instructions (Advanced SIMD) also use.
`vmrs` and `vmsr` move `FPSCR`, and `vstmia` and `vldmia` move sixteen
registers each, the most one instruction allows. The layout is that of
`u_fps` (#f("user.h")): `FPSCR` in the first word, and the registers
from byte 8, where the alignment of a `double` puts them. Both machines
have the unit (#f("low.s")), and `FPEXC` needs no saving, since the
unit stays enabled. The Cortex-A7's unit takes no trap on an arithmetic
exception, so `SIGFPT` is never sent, and a program finds what happened
in the cumulative flags of `FPSCR`.

#lines-to("dfar:")

_Fault Registers._ `dfar` and `dfsr` return the data fault address and status registers,
which describe the last data abort. `user_trap_handler` (#f("trap.c"))
prints them before it panics on a fault in kernel mode.

#lines-to(".data")

`waitloc` holds the address of `waitpc`. `nofault` is zero except while
a user reference is made.

#lines-to(".section .ddrbss,\"aw\",%nobits")

`kl3u` is the page table through which `resume` switches the u-area.
The kernel's own table maps only whole 2~MB blocks, but a u-area is one
page within its process's image. So the 2~MB block at `UBASE` gets a
third-level table, which maps page by page. Of its 512~entries only the
first `USIZE` are used. The rest stay invalid, so that a stray
reference beyond the u-area faults. `machine_init` hooks the table into
the last entry of `kl2` (#f("low.s")). Like every table of the long
format, it is aligned on 4~KB. It lies in the section `.ddrbss`, which
on the MP135 machine is in the DDR memory and so cannot be cleared until
`machine_init` has started the DDR controller. The clearing loop in
#f("low.s") therefore leaves it alone, and `machine_init` clears it
afterwards.

#lines-to(none)
#source("/usr/sys/sys/main.c")

#f("main.c") holds `main`, which the kernel runs once, as it brings
itself up, and the two routines it calls to initialise the file system
and the buffer cache, `iinit` and `binit`.

On the PDP-11 the path to `main` began in `l.s` and `mch.s`. They set up the kernel segmentation registers, placed the per process data area
of process 0 just above the end of the kernel, cleared the bss, and
turned memory management on. The ARM path is similar. `_start` in
#f("low.s") disables the MMU and caches, clears the bss, maps the
kernel at its kernel addresses, enables the MMU, sets a provisional
stack, and installs the vectors; it then calls `machine_init`
(#f("machdep.c")), which completes the kernel's mapping. Only then is
the stack pointer moved to the top of the per process data area of
process 0, at `UBASE`+4096, and `main` called.

`iinit` and `binit` are declared (#l("void\tiinit(void), binit(void);")) because `main` calls them before
their definitions below. v7 needed no such line, since its compiler took an
undeclared function to return `int`; C99 does not allow the call.

The definitions at #l("char\tcanonb[CANBSIZ];")--#l("struct inode *mpxip;") are new. v7 defined these variables in the
headers themselves, in #f("systm.h") and, for `mpxip` (#l("struct inode *mpxip;")), in
#f("inode.h"), and relied on the linker to merge the copies which each
including file made. The headers now declare them `extern`
(#f("systm.h") gives the reason), and each is defined here, once. `rootdev`, `swapdev`, `pipedev`, `swplo`, and
`nswap` are not among them, because the configuration file
#f("qemu/c.c") defines them with their values; nor are the maps and the
mount table, which v7's `main.c` defined, since their sizes are now
part of the configuration too (#f("param.h")). v7's `cputype` is gone
(#f("systm.h")).

The comment above `main` lists its work. Its first item reads "free
user core" (#l("*\tfree user core")), where v7's read "clear and free user core", since
`startup` no longer clears RAM (#f("machdep.c")).

#lines-to("void", after: "*/")

`startup` (#l("startup();")) sets aside the page tables of the processes, frees the
rest of RAM outside process 0, and initialises the block device.

#lines-to("/*")

`p_addr` of process 0, set at line #l("proc[0].p_addr = btop(corebase);"), is the page at which its per
process data area begins. v7 read it from the kernel segmentation
register `KISA6` (`ka6`), whose value `mch.s` had chosen. Here
`machine_init` has already mapped the first `USIZE` pages of RAM, at
`corebase`, at `UBASE`, so the page is that of `corebase`.

The remaining fields of `proc[0]` (#l("proc[0].p_size = USIZE;")--#l("u.u_cmask = CMASK;")) are as in v7: the process
occupies only its `USIZE` pages, is runnable, is in RAM, and is never
to be swapped. `u` and `proc[0]` are linked through `u_procp`.

#lines-to("/*", after: "u.u_cmask = CMASK;")

`clkstart` (#l("clkstart();")) now does rather more than start the clock: it also
programs the interrupt controller and is the point at which interrupts
are first allowed (#f("machdep.c")). Everything which follows may
therefore sleep: `iinit` waits for the disk.

`rootdir` and the current directory of process 0 are obtained as
separate references to the root inode; each `iget` returns it locked,
and the lock is released at once (#l("rootdir->i_flag &= ~ILOCK;"), #l("u.u_cdir->i_flag &= ~ILOCK;")).

#lines-to("/*", after: "u.u_rdir = NULL;")

`newproc` (#l("if(newproc()) {")) makes process 1 as a copy of process 0 and returns zero
to the parent, which falls through to `sched` (#l("sched();")) and never comes back.
Process 1 eventually resumes in `newproc` with a value of one, and
takes the branch.

#lines-to("expand(USIZE + (int)btop(szicode));")

The image is first enlarged to hold `icode`: `btop(szicode)` is 1,
so the image becomes the u-area and one page.
`estabur` (#f("ureg.c")) then checks the size and calls `sureg`, which
maps the page into the user window at virtual address 0, and
`copyout` writes `icode` (#f("machdep.c")) through that mapping, to
user address 0.

`arm_sync_icache` (#l("arm_sync_icache(PGADDR(u.u_procp->p_addr+USIZE),")) is new. The ARM, unlike the PDP-11, has
separate instruction and data caches which are not kept coherent by the
hardware: the instructions just stored may sit in the data cache, and
stale lines may sit in the instruction cache. The routine (#f("mch.s"))
writes the copied bytes back from the data cache, through the kernel's
own address for them, then discards the instruction cache and the branch
predictor.

#lines-to("/*")

`main` then returns to `_start` (#f("low.s")), which, as v7's `start` did
with `rtt`, sets the saved status register to user mode and jumps to
location 0. Process 1 begins to execute `icode`.

#lines-to("/*", lead: true, after: "}")

`iinit` opens the root device, reads its super-block (block 1,
`SUPERB`), and copies it into a buffer which is never released, the
first entry of the mount table. The super-block's time of last
modification becomes the initial time of day, until `date` or
`stime` corrects it.

#lines-to("/*", lead: true, after: "}")

The buffers themselves (#l("extern int\tbuffers[][(BSIZE+BSLOP+63)/64*16];")), defined, as their number now is, by the
configuration (#f("qemu/c.c")). v7 declared each as `BSIZE+BSLOP`, i.e.
514, bytes of `char`. With 514~bytes every second buffer would start on
an address which is only two-byte aligned, and the DMA engine of the SD
card controller of the MP135 machine requires a word-aligned buffer
address; the odd buffers would be corrupted on transfer. Alignment on
a word is not enough either. The same DMA bypasses the data cache,
whose lines on the Cortex-A7 are 64~bytes, and the driver must clean
and invalidate the lines a buffer occupies (#f("sd.c")); a line
shared with the neighbouring buffer, which the processor may be
changing meanwhile, would be written back over the new data, or
discarded with the neighbour's changes. Each row is therefore rounded
up to a multiple of 64~bytes, 576, and made of `int`s, so that the
array is at least aligned for `int`. Rounding alone would align the
rows only relative to the start of the array, which C places where it
will; `binit` therefore moves every buffer up by the same amount, less
than 64~bytes, to bring the first, and with it all the rest, onto a
64-byte boundary (#l("bp->b_un.b_addr = (caddr_t)buffers[i] +")). The configuration provides one row more than
`NBUF` (#f("mkconf.c")), so that the last buffer still fits. The casts
at 166 are the price.

#lines-to("/*", after: "extern int\tbuffers[][(BSIZE+BSLOP+63)/64*16];")

`binit` links every buffer into the free list through `brelse`, then
makes each block device's queue (`d_tab`) an empty circular list, and
counts the block devices in `nblkdev`. The scan of `bdevsw` ends at
the first entry without an open routine, the null entry with which
#f("qemu/c.c") closes the table.

#lines-to(none)
#source("/usr/sys/sys/machdep.c")

In v7, #f("machdep.c") collected those parts of the machine-dependent
code which could be written in C: the bootstrap program `icode`,
`startup`, `clkstart`, `sendsig`, and the routines for the UNIBUS map
of the 11/70, which are gone with the map; the ARM's devices address
all of RAM. The assembly language remainder lived in `mch.s`. The
port keeps
v7's procedures in v7's order, rewriting their bodies for the ARM, and
appends a second half which does the work that `mch.s` did on the
PDP-11 with the help of the memory management unit: building the
kernel's page tables, copying and clearing pages, returning from a
signal, and reading memory for `/dev/mem` and `/dev/kmem`.

The whole port rests on one arrangement of the ARM MMU, which it is
best to describe before the code. The PDP-11/45 divided the 64~KB user
address space into eight segments of up to 8~KB, each described by an
address register (`UISA`) and a descriptor register (`UISD`); the
kernel had a second set of registers, and its own seventh segment was
pointed by `KISA6` at the per process data area of the current process.
The ARM, in the long-descriptor format which the port uses
(#f("low.s")), likewise translates the address space through two
tables: the low three gigabytes, 0 to `USRSIZE`, through the table in
`TTBR0`, and the top gigabyte through the table in `TTBR1`. The port
uses them thus:

- The top gigabyte is the kernel's. Its table, `kl2`, maps the kernel
  image, the whole of RAM, and the device registers by 2~MB blocks,
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
  sizes and its place in RAM. A process switch loads `TTBR0` with the
  new process's table, as v7's `sureg` loaded `UISA` and `UISD`.

A process image in RAM keeps v7's form: `USIZE` pages of per process
data area at `p_addr`, then the data, then the stack, packed together.
In the user's address space the data begins at the bottom, and the
stack ends at the top, at `USRSIZE`, with a gap between them which is
not mapped. Each grows towards the other: the data by `sbreak`
(#f("sys1.c")) and the stack by `grow` (#f("sig.c")), and each growth
enlarges the image in RAM. Since every page is mapped separately, and
tables exist only where something is mapped, the gap costs nothing.

`conf.h` is included (#l("#include \"../h/conf.h\"")) for `struct intr`, the table of device
interrupts which `clkstart` and `irq` use.

#lines-to("/*")

`icode` is the first user program, copied by `main` (#f("main.c")) to user
address 0 of process 1. In v7 it was eleven words of PDP-11 machine
code assembled by hand into octal. The ARM version is ten words of
hand-assembled ARM code, in hexadecimal, and the comment now says so.

#lines-to("0xe3a0001c,\t/* mov r0, #init */")

The first four words perform `exec("/etc/init", initp)`. The arguments
are passed in `r0` and `r1` and the system call number (11) in `r7`;
`svc` replaces the PDP-11's `sys` (`trap`) instruction, whose low byte
carried the number. `exec` (#f("sys1.c")) takes two arguments and
supplies the null environment itself, so nothing is put in `r2`.
Should the `exec` fail, the program loops on the branch to itself (#l("0xeafffffe,\t/* b . */")),
as v7's did, and the system goes no further.

#lines-to("0x0000001c,\t/* initp: init; 0 */")

`initp`, the argument vector `{init, 0}`, follows at offset `0x14`,
and then the string `/etc/init`, stored little-endian, at `0x1c`, in
v7's order. Because the program is loaded at address 0, its own
offsets serve as addresses, and both fit the 8-bit immediate field of
`mov`.

#lines-to("/*", lead: true)

v7's `startup` found the size of RAM by experiment: it slid a user
segment through physical memory 64~bytes at a time until a reference
failed, clearing each unit and freeing it into `coremap` as it went.
On the ARM the limits of RAM are known and nothing is probed:
`machine_init` (below) has set `corebase` to the physical address of
the first page after the kernel and its tables, and the configuration
(#f("qemu/c.c")) gives `coretop`. Both are physical addresses, since
page numbers are.

#lines-to("i = btop(corebase) + USIZE;")

RAM begins with the `USIZE` pages of the per process data area of
process 0 (see `main`), as v7 began at `*ka6 + USIZE`. Two new
reservations follow it. The first-level user tables, 32~bytes for each
slot of the process table, take the next pages (#l("l1tab = (unsigned long long *)PGADDR(i);")--#l("i += btop(32*NPROC);")); `l1tab` is
their kernel address, through which `sureg` writes them, and `l1pa` the
physical one, which `TTBR0` needs. The page number is converted to
`unsigned` before `ptob` shifts it (#l("l1pa = ptob((unsigned)i);")): on the MP135 machine RAM lies
above 0xc0000000, and the shift of a signed `int` past the largest
`int` would be undefined. They are cleared, so that every
process starts with an empty address space. The next `NPTAB` pages
(#l("mfree(ptmap, NPTAB, i);"), #l("i += NPTAB;")) are the pool from which `sureg` takes the lower tables, freed
into `ptmap` as v7 freed RAM into `coremap`. The rest of RAM is freed
(#l("maxmem = btop(coretop) - i;"), #l("mfree(coremap, maxmem, i);")). RAM is no longer cleared here; `machine_init` clears the
area of process 0, and `exec` (#f("sys1.c")) clears each image it
builds, so the v7 comment (#l("* free all of core")) now says only "free".

As in v7, `maxmem` (#l("maxmem = btop(coretop) - i;")) is first the amount of RAM, which is printed
(#l("printf(\"mem = %D\\n\", ptob((long)maxmem));")), and is then limited to `MAXMEM` (#f("param.h")), the largest image
a process may have (#l("if(MAXMEM < maxmem)"), #l("maxmem = MAXMEM;")). `estabur` (#f("ureg.c")) refuses any image
larger than `maxmem`.

#lines-to("mfree(swapmap, nswap, 1);")

The swap area (#l("mfree(swapmap, nswap, 1);"), #l("swplo--;")) is set up as in v7.

v7 ended `startup` by pointing user segment 7 at the I/O page.
Its place is taken by `bdinit` (#l("bdinit();")), which #f("qemu/c.c") defines to call the
block driver's initialisation routine. This must come before
`clkstart`, since the `virtio` driver only learns its interrupt number
when it probes the device.

#lines-to("/*", lead: true)

`sysphys`, system call 52, let the super-user map a piece of physical
memory, such as device registers, into a segment of his address space.
v7's recorded the segment in `u_uisa` and `u_uisd` and called `sureg`.
The prototype which replaces them describes only text, data, and stack
(#f("user.h")), and has no place for a physical segment. The body is
therefore replaced: the super-user is refused with `EINVAL`, the error v7 gave
for a request it could not satisfy, and anyone else, as in v7, with the
error of `suser`.

#lines-to("/*", lead: true, after: "}")

Hence to the clock. The PDP-11 had a line clock (KW11-L) or a
programmable clock (KW11-P) on the UNIBUS, each with its own interrupt
vector and priority; v7's `clkstart` tried one, then the other, and
set its interrupt enable bit. On the ARM every device interrupt reaches
the processor through a single line from the Generic Interrupt
Controller (GIC), whose distributor (`gicdbase`) and processor interface
(`giccbase`) registers are reached through `GICD` and `GICC` (#l("#define\tGICD(o)\t(*(volatile unsigned *)(gicdbase+(o)))"), #l("#define\tGICC(o)\t(*(volatile unsigned *)(giccbase+(o)))")).
The clock is the processor's own generic timer: interrupt 27 (`clkirq`,
86) is the private interrupt of its virtual timer.

`intrtab` (#l("extern struct intr intrtab[];")) is generated by `mkconf` in #f("qemu/c.c"): for the
clock and each configured device, a pointer to the variable holding its interrupt
number and the routine to call. A pointer, rather than the number,
because some numbers are not known until the driver has probed its
device.

`gicen` (#l("gicen(int n)")) gives interrupt `n` a middling priority (0x80) in the
distributor's byte-per-interrupt priority array at `0x400`, then sets
its bit in the set-enable registers at `0x100`.

#lines-to("void")

`clkstart` first reads `CNTFRQ` (#l("if((clkreload = cntfrq_get()/HZ) == 0)")), which gives the frequency of the
system counter. `clkreload` is the number of its counts in `1/HZ`
second, and `clkrem` (#l("clkrem = cntfrq_get()%HZ;")) what the division leaves over, which
`clock` (#f("clock.c")) adds in so that the ticks keep exact time. A
frequency below `HZ` (the register is set by firmware) is the one
remaining way to "find no clock".

It then enables every configured interrupt whose number is known, the
timer's among them (#l("for(ip = intrtab; ip->i_irq; ip++)", after: "clkrem = cntfrq_get()%HZ;")--#l("gicen(*ip->i_irq);")); enables the distributor, lets interrupts of
every priority through the processor interface (the priority mask
register at 4), and enables the interface (#l("GICD(0) = 1;")--#l("GICC(0) = 1;")); and sets the
timer's first deadline, `clkreload` counts after the present value of
the counter, and starts it (#l("cntv_cval_set(clkcval = cntvct_get() + clkreload);"), #l("cntv_ctl_set(1);")). `clkcval` (#l("unsigned long long clkcval;")) keeps the
deadline, from which `clock` computes the next.

Only then are interrupts unmasked (#l("intr_enable();")). An earlier call of
`intr_enable`, as from a driver, unmasks them too, but none can arrive,
since `machine_init` has switched the GIC off. Since `main` calls `clkstart` before `iinit`,
the read of the root super-block is already driven by interrupts.

#lines-to("void", lead: true, after: "}")

`irq` is new. It is called from `irq_entry` (#f("low.s")) with a pointer to
the saved registers of the interrupted program, in the layout of
#f("reg.h"), and with interrupts masked; it plays the part of v7's
`call` in `mch.s` together with the PDP-11's vectored interrupts.

Reading the acknowledge register (`0xc`) at line #l("n = GICC(0xc);") yields the number of
the highest priority pending interrupt, in its low ten bits, and marks
it active.

The routine whose number matches is called (#l("for(ip = intrtab; ip->i_irq; ip++)", after: "n = GICC(0xc);")--#l("(*ip->i_fn)((caddr_t)r[PC], r[PSR]);")) with the
interrupted program counter and status. The timer's routine is `clock`
(#f("clock.c")), which sets the next deadline and uses the two values to
charge the tick to the user or the system. The device routines ignore
them. `main` has set up process 0 before it calls `clkstart`, so `clock`
always finds a current process. A spurious interrupt (1023) matches
nothing.

Writing the same value to the end-of-interrupt register (`0x10`) at
line #l("GICC(0x10) = n;") retires the interrupt.

All interrupts share one level. The PDP-11's priorities have collapsed
into "masked" and "unmasked", and until the end of interrupt is written
the controller delivers no other interrupt, even to a handler which
unmasks the IRQ, as `clock` does with `intr_enable` (#f("clock.c")). After
that, an IRQ left unmasked, or unmasked again for the call of
`user_trap_handler` in the tail of `irq_entry` (#f("low.s")), lets a
second interrupt in before the first frame is unloaded. It nests
as any interrupt of the kernel does: its frame goes below the first,
and the `r5` saved in it, which carries the first entry's `lr`, is
restored before the first entry uses it.

#lines-to("/*", lead: true)

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

#lines-to("m = (PSR+1)*sizeof(int);")

`n` (#l("n = (u.u_ar0[SP] - m - sizeof(u.u_fps)) & ~7;")) is the user stack pointer less the size of the frame,
rounded down to a multiple of 8 as the ARM calling convention requires.
The frame is the registers, `m` bytes (#l("m = (PSR+1)*sizeof(int);")), 17~words: `r0` to `r15`
and the status register, followed by `u.u_fps` (#f("user.h")), where
`psig` (#f("sig.c")) has just stored the floating point registers.

First `grow` (#f("sig.c")) is asked to extend the stack to cover the
frame (#l("grow(n);")), as in v7: the stack segment holds only what the process has
used so far, and the frame may lie below it. The frame is then copied
out (#l("if(copyout((caddr_t)u.u_ar0, (caddr_t)n, m) < 0 ||")--#l("}", after: "copyout((caddr_t)&u.u_fps, (caddr_t)(n+m),")), the registers and then the floating point state, with
`copyout` (#f("mch.s")), which fails if any part of it lies outside the
process's memory. If the frame cannot be written,
the process is sent `SIGSEG`, with its handler first reset to the
default so that it is not caught in turn.

#lines-to("u.u_ar0[SP] = n;")

The stack pointer is then lowered past the frame; the link
register, `u_ar0[14]`, for which #f("reg.h") has no name, is set to the
trampoline at `UENTRY_SIGTRAMP` (see `install_sigtramp`, 314); the
program counter (`PC`) to the handler; and
`r0` to the signal number, the handler's argument. v7 also cleared the
trace bit in the saved status, so that a traced process would not trap
on the handler's first instruction; the ARM status register has no
trace bit. What is cleared instead (#l("u.u_ar0[PSR] &= ~0x0600fe20;")) is the Thumb state: the `T`
bit (5), the `IT` bits (10 to 15, 25, and 26), which make the next
instructions of a Thumb `if-then` block conditional, and the `E` bit
(9), big-endian data. Every program here is compiled to ARM code, but
the compiler's support library `libgcc`, which supplies the 64-bit
division `__aeabi_ldivmod` and its relatives, is the Thumb build, so a
signal may well interrupt Thumb code. The handler is ARM code and must
be entered in ARM state, with no `if-then` block pending.

When the handler returns, it returns to the trampoline, with the stack
pointer at the frame, and the trampoline issues `sigreturn` (#l("sigreturn(void)")).

#lines-to("extern struct memregion board_map[];")

The remainder of the file is new.

`board_map` (#l("extern struct memregion board_map[];")) comes from #f("qemu/c.c"): the regions which the
machine's configuration file asks to be mapped, each with its kernel
address, its physical bounds, and the attribute bits of its block
descriptors. The `__` symbols (#l("extern char _start[], __bss_end[], __ddrbss_start[], __ddrbss_end[];")) are defined by the linker script.
`.ddrbss` is a second, uninitialised data section: on the MP135 machine
the kernel image runs from SYSRAM, and the large tables are placed in
the DDR memory, which is useless until it has been set up. On the QEMU
machine it is ordinary RAM. The tables (#l("extern unsigned long long kl2[], kl3u[], bootl1[];")) are reserved in
#f("low.s") and #f("mch.s").

`msgbufp` (#l("char\t*msgbufp = msgbuf;")), the pointer into the circular buffer of console
output read by `dmesg`, was defined in v7's console driver `kl.c`. It
is here because either of two console drivers may be configured
(#f("pl011.c") or #f("otg.c")), and both use it.

`kmap` enters the regions of `board_map` into the kernel's table
`kl2`, 2~MB at a time: those of device registers if `dev` is set, the
others if not. The entry for a kernel address is its block number, the
address shifted right by 21, less the 0x600 blocks below 0xc0000000,
which the mask (#l("kl2[((m->va+a-m->start)>>21) & 0x1ff] =")) takes away. The attributes, spelled `BLK_KERN` and
`BLK_DEV` in the configuration files, are defined in #f("seg.h"):
kernel memory is normal, cacheable, and accessible only from the
kernel; device memory is device memory, never executable, and likewise
closed to user mode. Since entries which were invalid are made valid,
no stale translation can exist; `tlbflush` (#f("mch.s")) is called all
the same, since a region may be entered twice, as the kernel's own is.

`vtop` (#l("vtop(caddr_t va)")) is the inverse of the kernel's mapping: it finds the
region of RAM which holds a kernel address, and returns the physical
address. A device which reads or writes memory by itself (the virtio
disk of the QEMU machine, the SD card controller of the MP135 machine) must be
given physical addresses, and its driver calls `vtop` on each buffer.
This is the counterpart of v7's `b_xmem` and of the arithmetic by which
v7's drivers turned a segment and an offset into the 18-bit address of
the UNIBUS. A device region has no RAM behind it, and an
address found in no region is an error.

#lines-to("caddr_t")

`machine_init` is called from `_start` (#f("low.s")), running at its
kernel address on a small stack in the bss, with only the kernel image
mapped. It first maps the device registers, switches the GIC off,
whatever state QEMU or the boot ROM left it in, and initialises the
console (#l("kmap(1);")--#l("cninit();")), so that `printf` and `panic` work from here on. On the
MP135 machine that means taking over the USB controller and waiting up
to ten seconds for the host to open the port (#f("otg.c")).

On the MP135 machine it then has the PMIC power the DDR memory
(#f("pmic.c")) and starts the DDR controller (#f("ddr.c"))
(`clock_ddr_init` is empty on the QEMU machine). Only then are the other regions mapped (#l("kmap(0);")), the
DDR memory among them: a mapping of RAM which does not yet work
would invite the processor to touch it speculatively. `.ddrbss`, which
`_start` could not clear, is cleared (#l("for(p = __ddrbss_start; p < __ddrbss_end; p++)"), #l("*p = 0;", after: "for(p = __ddrbss_start; p < __ddrbss_end; p++)")).

RAM begins at the first page boundary after `.ddrbss`, the last part
of the kernel to be placed (#f("qemu/unix.ld")). On the QEMU machine
that is just past the kernel image; on the MP135 machine, whose kernel
runs from SYSRAM, it is just past the tables in DDR. Neither needs to be
stated in the configuration, which gives only the top of RAM.
`corebase` is the physical address (#l("corebase = ptob(btop(vtop(__ddrbss_end)));")), and `coreoff` (#l("coreoff = (unsigned)__ddrbss_end - vtop(__ddrbss_end);")) the
difference between the kernel and physical addresses of all of RAM,
which lies in one region; `PGADDR` (#f("seg.h")) adds it to turn a
page into a kernel address.

The `USIZE` pages of the per process data area of process 0, the first
of RAM, are entered in `kl3u` at `UBASE` (#l("for(a = 0; a < USIZE; a++)"), #l("kl3u[a] = (corebase + ptob(a)) | BLK_KERN | PTE_TAB;")), with the attributes
of a kernel page, as in `resume` (#f("mch.s")), and `kl3u` is hooked
into the last entry of `kl2` (#l("kl2[511] = vtop((caddr_t)kl3u) | PTE_TAB;")), which covers the top 2~MB of the
address space; no region of `board_map` reaches so high. The identity
mapping of `bootl1` (#f("low.s")) is removed (#l("bootl1[vtop(_start)>>30] = 0;")): from here on
nothing below `USRSIZE` is mapped but the user's. The area of process 0
is then cleared (#l("for(p = (char *)UBASE; p < (char *)UBASE + ptob(USIZE); p++)"), #l("*p = 0;", after: "for(p = (char *)UBASE; p < (char *)UBASE + ptob(USIZE); p++)")); v7's `start` did the same for process 0.

The address returned (#l("return((caddr_t)UBASE + ptob(USIZE));")) is the top of the u-area, where #f("low.s")
puts the kernel stack.

#lines-to("void", lead: true)

`copyseg` and `clearseg` copy and clear one page, 1024
words. In v7 they were in `mch.s`, and had to borrow a user segment to
reach physical RAM; here RAM is mapped into the kernel's own
address space, and `PGADDR` (#f("seg.h")) converts a page number to a
pointer. The routines which move data between the kernel and the user,
`fubyte`, `copyin`, and the rest, are in #f("mch.s"), as they were in
v7.

#lines-to("void", lead: true, after: "d[i] = 0;")

`sigreturn`, system call 63, undoes `sendsig`. It is called by the
trampoline, at which point the user stack pointer addresses the saved
frame.

#lines-to("a = (caddr_t)u.u_ar0[SP];")

The frame is copied in through `copyin`, which fails unless it lies in
the process's memory; a bad stack pointer earns `SIGSEG`. The floating
point part goes straight to `u.u_fps`, and `u_fpsaved` (#l("u.u_fpsaved = 1;")) makes the
return to user mode load it (#f("trap.c")). A forged `FPSCR` can do
no harm: it holds nothing but the user's own modes and flags.

#lines-to("for(i = 0; i < PSR; i++)")

`r0` to `r15` are restored (#l("for(i = 0; i < PSR; i++)"), #l("u.u_ar0[i] = f[i];")).

Of the saved status register (#l("u.u_ar0[PSR] = (f[PSR] & 0xfe0ffe20) | 0x10;")), only the condition flags (bits 27
to 31), the `GE` flags (16 to 19), and the Thumb state that `sendsig`
cleared (the `T`, `IT`, and `E` bits) are taken; the mode is set to user
mode, `0x10`, with the interrupt masks `A`, `I`, and `F` clear. A forged
frame therefore cannot return the process to the processor in a
privileged mode, nor with interrupts masked, while a signal which
interrupted Thumb code, in the middle of a 64-bit division, say,
returns to it in Thumb state and inside its `if-then` block.

`trap` (#f("trap.c")) will store `r_val1` and `r_val2` into
`r0` and `r1` as the results of this system call; setting them to the
saved values (#l("u.u_r.r_val1 = f[R0];"), #l("u.u_r.r_val2 = f[R1];")) makes the return restore those two registers too.

#lines-to("static char *", lead: true)

`fumem` and `sumem` serve the memory special files (#f("mem.c")) one byte
at a time, in the role that `fuibyte` and `suibyte`, with a user segment
pointed at physical memory, played in v7's `mem.c`.

`memaddr` translates a file offset to a kernel address. For `/dev/kmem`
(minor 1) the offset is a kernel address; for `/dev/mem` (minor 0) it
is a physical address, which is moved into the kernel's addresses by
the difference between them (#l("a += b - vtop((caddr_t)b);")). Two stretches of RAM may be read:
the kernel image, from `_start` to the end of `bss`, and everything from
`.ddrbss` to the top of RAM, which on both machines lie in one region
each; `/dev/kmem` may also read the u-area of the current process at
`UBASE` (#l("if(minor(dev) == 1 && (unsigned)off - UBASE < ptob(USIZE))")). Anything else returns -1, and the driver sets `ENXIO`.

`devaddr` (#l("devaddr(off_t off)")) turns a physical address within one of the board's
device blocks (the `BLK_DEV` entries of `board_map`) into the kernel
address at which that block is mapped. `/dev/mem` (#f("mem.c")) reads
and writes those addresses through it rather than through `fumem` and
`sumem`, a whole aligned word at a time, since the registers take no
narrower access.

#lines-to("void", lead: true)

`install_sigtramp` writes the two-instruction signal trampoline,
`sigreturn` by `svc`, at user address 8 (#f("seg.h")). `xalloc`
(#f("text.c")) calls it while the text it has just read in is still
mapped writable, so that the trampoline becomes part of the shared
text. The stores go through `suword` (#f("mch.s")), with the
permissions of user mode.

`panictrap` is the target of the vectors which should never be taken
(#f("low.s")).

#lines-to(none)
#source("/usr/sys/h/proc.h")

A process is represented in two places. Its `proc` structure, one
element of the array `proc` (#l("extern struct proc proc[];\t/* the proc table itself */")), stays in RAM throughout the life
of the process and holds what the system must know about it even
when the rest of it is on the swap device: whether it is in memory,
where it is, why it sleeps, and the information that scheduling and
signals need. The rest of the process state, the `user` structure
(#f("user.h")), lives at the bottom of the process's own memory image
and is swapped with it.

`p_stat` (#l("char\tp_stat;")) takes one of the values on lines 34 to 39; a zero entry
is free. `p_flag` (#l("char\tp_flag;")) is a set of the bits on lines 42 to 48.

`p_pri` (#l("char\tp_pri;\t\t/* priority, negative is high */")) is the scheduling priority, recomputed by `setpri`
(#f("slp.c")) from `p_cpu` and `p_nice`, or set by `sleep` to the
priority given for the event. A smaller value is more urgent, so the
comment's "negative" means the highest of all. `p_time` and `p_cpu`
are kept in a `char`, and `clock` stops each at its maximum so that
it cannot wrap.

`p_sig` (#l("int\tp_sig;\t\t/* signals pending to this process */")) is the set of pending signals, one bit each, the bit for
signal _n_ being 1 shifted left _n_-1. v7 kept it in a `short`, the
sixteen bits of which held its sixteen signals; it is now an `int`, for
the 31 signals which `NSIG` (#f("param.h")) allows. `xp_sig` (#l("int\txp_sig;\t\t/* signals pending to this process */")), its
counterpart in `struct xproc` below, is widened with it, so that the
fields after it still lie where `proc`'s do.

`p_addr` (#l("int\tp_addr;\t\t/* address of swappable image */")) and `p_size` (#l("int\tp_size;\t\t/* size of swappable image (pages) */")) locate the image. When `SLOAD` is set,
`p_addr` is a page number, the physical address divided by 4096
(`PGADDR`, #f("seg.h")); otherwise it is a block number on the swap
device. `p_size`
is in pages in both cases, and includes the `USIZE` pages of the
`user` structure and kernel stack, which come first.

`p_addr` has been widened from `short` to `int`. On the PDP-11, whose
largest memory was 4~MB, v7's unit number fitted in sixteen bits. Here
the MP135 machine's RAM lies above 0xc0000000, at page numbers
beyond 786432, and a swap address can exceed 65536 as well
(#f("qemuconf")). `p_size` is bounded by `maxmem`, which is at most
`MAXMEM` (#f("param.h")), 32768~pages, one more than a `short` holds;
it has been widened too.

`p_ptab` and `p_nptab` (#l("int\tp_ptab;\t\t/* user page tables (page) */"), #l("int\tp_nptab;\t/* their number, 0 if none */")) are new: the first page and the number
of the pages of user page tables which the process holds while it is in
RAM, taken from the pool by `sureg` and given back by `ptfree`
(#f("ureg.c")). `p_nptab` is zero while the process has none, as after
it has been swapped out, created, or moved in RAM.

`p_wchan` (#l("caddr_t p_wchan;\t/* event process is awaiting */")) is the address on which a sleeping process waits;
`wakeup` compares it with its argument. `p_textp` (#l("struct text *p_textp;\t/* pointer to text structure */")) points to the
shared text segment, which every program has (#f("text.c")); only
process 0, and process 1 while it runs `icode`, have none. `p_link` (#l("struct proc *p_link;\t/* linked list of running processes */")) chains the runnable processes
into the list headed by `runq` (#f("systm.h")): `setrq` (#f("slp.c")) adds a
process to it, and `swtch` searches it for the most urgent one that is
in RAM. `p_clktim` (#l("int\tp_clktim;\t/* time to alarm clock signal */")) counts down the seconds of an `alarm`.

#lines-to("/* stat codes */")

`SWAIT` is listed but never set by v7 itself. `SIDL` covers the brief
time in `newproc` while a child is being copied, and `SZOMB` the time
between `exit` and the parent's `wait`.

#lines-to("/* flag codes */")

`SLOAD` is the bit which decides how `p_addr` is to be read. `SSYS`
marks process 0, which is never swapped. `SLOCK` holds a process in
RAM temporarily: while it is being swapped out, while its text is
read in, and while `physio` transfers directly to or from its image.
`SSWAP` marks a process whose image was written to the swap area from
the middle of `newproc`, `expand`, or `xexpand`, so that `swtch` (#f("slp.c"))
resumes it through `u_ssav` rather than `u_rsav`. `SULOCK` holds a
process in RAM at the user's request, through the `lock` system call
(`syslock`). `STRC` and `SWTED` serve `ptrace`.

#lines-to("/*", after: "#define\tSULOCK\t0100\t\t/* user settable lock in core */")

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
at 40~bytes, inside the 52~bytes of a `proc` entry. The times thus lie
over `p_size`, `p_ptab`, `p_nptab`, and `p_wchan`. None of these means
anything in a zombie, but two are read again when the entry is reused,
so `wait` (#f("sys1.c")) clears them as it frees it: `p_wchan`, as in
v7, and `p_nptab`, without which `ptfree` (#f("ureg.c")) would hand the
system time of the dead process to `mfree` as a number of page tables.

#lines-to(none)
#source("/usr/sys/h/user.h")

The `user` structure is the second half of the description of a
process, the half that can be swapped. It sits at the base of the
process's image in RAM, followed by the kernel stack of the
process, the two together occupying `USIZE` pages (#f("param.h")): the
"per process data area". Only the data area of the current process is
addressable, always at the same kernel address, and the kernel calls
it `u`. To switch processes is, at bottom, to change which data area
appears there.

The opening comment is v7's. `USIZE` is now one page of 4096~bytes rather than 16 units of 64~bytes, and the comment gives the new unit; the
block appears at virtual address `UBASE`, 0xffe00000, which the
comment now gives in place of v7's 0140000. That address was
the start of the seventh kernel segment, and v7
switched processes by reloading that segment's address register
(`ka6`). The port maps the window through its own third-level page
table, `kl3u` (#f("mch.s")), which covers the top 2~MB of the kernel's
address space. `resume` writes the physical address of the new
process's data area into that table and discards the old translations,
after which the same virtual addresses show the new `u`.

`EXCLOSE` (#l("#define\tEXCLOSE\t01")) is the bit of `u_pofile` (#l("char\tu_pofile[NOFILE];\t/* per-process flags of open files */")) which marks a file to be
closed by `exec`.

#lines-to("struct\tuser")

`u_rsav` (#l("label_t\tu_rsav;\t\t\t/* save info when exchanging stacks */")) holds the registers saved by `save` (#f("mch.s")) when the
process gives up the processor in `swtch`, and restored by `resume`.
`label_t` now has ten words: r4 to r11, the stack pointer, and the link
register, the registers which the ARM procedure call standard requires
a callee to preserve.

The floating point fields (#l("int\tu_fper;\t\t\t/* FP error register */")--#l("} u_fps;")) are v7's. `u_fps` holds the state
of the floating point unit while the process is not using it: the
status register `FPSCR` in `u_fpsr`, and the registers in `u_fpregs`,
of which the ARM has 32 to the PDP-11's 6. `u_fpsaved` says that the
hardware registers have been stored here, and must be reloaded before
the return to user mode. `trap` and `user_trap_handler` (#f("trap.c"))
clear it on entry; `swtch`, `newproc`, and `expand` (#f("slp.c")),
and `psig` (#f("sig.c")) store the registers and set it whenever another
process may take the unit or the u-area may be copied; and the return to
user mode reloads them if it is set. Since the registers are saved only
when they must be, a process which makes a system call and continues
pays nothing for them. `exec` clears the area, `ptrace` permits writes to
it, and a core file, which begins with the u-area, carries it. `u_fper`,
v7's floating error code, is unused (#f("mch.s")).

#lines-to("char\tu_segflg;\t\t/* IO flag: 0:user D; 1:system; 2:user I */")

`u_segflg` (#l("char\tu_segflg;\t\t/* IO flag: 0:user D; 1:system; 2:user I */")) tells `iomove` and its relatives where `u_base`
points: 1 for kernel space, 0 or 2 for user data or text. Since the
I-space routines are aliases of the D-space ones (#f("systm.h")), 0 and 2
now mean the same. `u_error` is the error number that a system call
returns. The four user and group ids follow, effective and real.
`u_procp` (#l("struct proc *u_procp;\t\t/* pointer to proc structure */")) links back to the process's `proc` entry, and `u_ap`
points to the arguments of the current system call.

`u_r` (#l("union {\t\t\t\t/* syscall return values */")) holds the one or two values that a system call returns. In
v7 the structure inside the union had no member name: the old C
compiler kept all structure member names in a single table, and
`u.u_r.r_val1` was accepted although the union had no member called
`r_val1`. C99 requires a name. The structure is now the member
`u_pair` (#l("} u_pair;")), and the two macros (#l("#define\tr_val1\tu_pair.r_val1"), #l("#define\tr_val2\tu_pair.r_val2")) let the many statements
which write `u.u_r.r_val1` remain as v7 wrote them. `r_time` fills both
words of the pair, as it did on the PDP-11; the union is therefore
aligned on eight bytes.

#lines-to("caddr_t\tu_base;\t\t\t/* base address for IO */")

The parameters of an I/O transfer, which `readi`, `writei`, and the
drivers consume: `u_base`, `u_count`, and `u_offset`. After them come
the current and root directories, and the working storage of `namei`
(#f("nami.c")): the current component of the path name, a pointer into
the name, a copy of the directory entry, and the parent directory.

#lines-to("unsigned u_ptsize, u_pdsize, u_pssize;\t/* prototype sizes */")

In v7, `u_uisa` and `u_uisd` held the prototypes of the sixteen PDP-11
user segmentation registers, which `estabur` computed and from which
`sureg` loaded the hardware (#f("ureg.c")). The ARM's mapping needs a
smaller prototype: the sizes, in pages, of the text, the data, and the
stack to be mapped (#l("unsigned u_ptsize, u_pdsize, u_pssize;\t/* prototype sizes */")), and the access rights of the text, `RO` or
`RW` (#l("int\tu_pxrw;\t\t\t/* prototype of text access */")). `u_ofile` (#l("struct file *u_ofile[NOFILE];\t/* pointers to file structures of open files */")) is the
table of open files, indexed by file descriptor. `u_arg` (#l("int\tu_arg[5];\t\t/* arguments to current system call */")) receives
the arguments of a system call from the saved registers r0 to r3;
no call takes more than four. `u_tsize`, `u_dsize`, and `u_ssize` (#l("unsigned u_tsize;\t\t/* text size (pages) */")--#l("unsigned u_ssize;\t\t/* stack size (pages) */"))
are the sizes, in pages, of the three parts of the user image.

#lines-to("label_t\tu_qsav;\t\t\t/* label variable for quits and interrupts */")

`u_qsav` (#l("label_t\tu_qsav;\t\t\t/* label variable for quits and interrupts */")) is the label to which `sleep` returns when a signal
interrupts a system call; `trap` sets it on every call. `u_ssav`
serves `expand` and the swapping code, which may need to resume a
process at the point where its image was copied. `u_signal` (#l("int\tu_signal[NSIG];\t\t/* disposition of signals */")) holds, for each
signal, zero for the default action, one to ignore it, or the address
of a catching routine; an `int` holds an address on the ARM, as it did
on the PDP-11.
The four times are counted in clock ticks.

`u_ar0` (#l("int\t*u_ar0;\t\t\t/* address of users saved R0 */")) points to the user's registers as saved on the kernel
stack on entry to the system. The frame in the port holds r0 to r14,
the program counter, and the status register, and #f("reg.h") gives the
index of each in the frame. `u_prof` holds the parameters of the
`profil` system call. Its structure has been given the tag `uprof` so
that `addupc` (#f("clock.c")), which v7 wrote in assembler, can be declared
to take a pointer to it and read the fields by name. `u_ttyp` and `u_ttyd` (#l("struct tty *u_ttyp;\t\t/* controlling tty pointer */"), #l("dev_t\tu_ttyd;\t\t\t/* controlling tty dev */")) name the
controlling terminal.

#lines-to("struct {\t\t\t/* header of executable file */")

`u_exdata` (#l("struct {\t\t\t/* header of executable file */")) is the header of the program being executed, read by
`getxfile` (#f("sys1.c")). In v7 it was the eight-word `a.out` header.
The executables here are in ELF, the Executable and Linkable Format,
and the structure has been rearranged to
hold the pieces of an ELF file which the kernel needs. Its first 52
bytes overlay the ELF file header. The fields that the kernel reads have
names; the rest are fill:

- `ux_mag` (#l("int\tux_mag;\t\t/* magic number */")) receives the four identifying bytes, `\x7fELF`, which
  read as a little-endian word are 0x464c457f.
- `ux_entloc` (#l("unsigned ux_entloc;\t/* entry location */")), the entry point, and `ux_phoff` (#l("unsigned ux_phoff;")), the file
  offset of the program header table, fall at the offsets of the ELF
  fields `e_entry` and `e_phoff`.
- `ux_phnum` (#l("short\tux_phnum, ux_z[3];")) is the number of program headers.

`ux_ph` (#l("struct {", after: "short\tux_phnum, ux_z[3];")--#l("} ux_ph[2];\t\t/* text and data segments */")) then receives two program headers, or rather their
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

#lines-to("char\tu_comm[DIRSIZ];")

`u_comm` (#l("char\tu_comm[DIRSIZ];")) is the last component of the name of the program, for
accounting and `ps`; `u_start` and `u_acflag` are also for accounting.
`u_cmask` (#l("short\tu_cmask;\t\t/* mask for file creation */")) is the `umask`.

`u_stack` (#l("int\tu_stack[1];")) marks the end of the structure. The kernel stack begins
at the top of the data area, 0xffe02000, where #f("low.s") sets the
supervisor mode stack pointer, and grows down towards it. Nothing but
the size of the area guarantees that it does not reach the structure.

#lines-to("extern struct user u;", lead: true)

In v7, `u` was an external variable (#l("extern struct user u;")). Its address was fixed not
by storage but by the assembler line `_u = 140000` in `mch.s`, which
made `_u` an absolute symbol. The port does the same with one line of
the linker script, `u = 0xFFE00000`, which `mkconf` writes
(#f("qemu/unix.ld")): `u` is the `struct user` at `UBASE`, and every
reference to it is to that fixed address, as in v7. A program which
includes #f("user.h") for the structure may still name a variable of
its own `u`, as `ps` does.

#lines-to("/* u_error codes */")

The error numbers which a system call may return in `u_error`. The
user sees them in `errno`. They are unchanged from v7.

#lines-to(none)
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
registers, `u.u_uisa` and `u.u_uisd`, eight segments of up to 8~KB
each, and `estabur` had to fit the text, the data, and the stack into
them, round each up to whole segments, and mark the stack as growing
downward. On the ARM every 4~KB page has its own entry, so the
prototype is simply the three sizes and the text's access rights
(#f("user.h")): the text occupies the bottom of the address space, the
data follows it, and the stack ends at `USRSIZE`.

The hardware, however, is no longer a set of registers. It is a tree of
tables in RAM (#f("low.s")): a first-level table of four entries,
each covering a gigabyte; for each gigabyte in use, a second-level
table of 512~entries, each covering 2~MB; and for each 2~MB in use, a
third-level table of 512~page entries. The first-level tables live in
`l1tab` (#l("unsigned long long *l1tab;"), #l("unsigned l1pa;")), one for each slot of the process table, set aside by
`startup` (#f("machdep.c")). The others are built in pages from the
pool, and are kept from one switch to the next, as the PDP-11 kept the
prototype; a switch only points `TTBR0` at the process's table.

#lines-to("/*")

`ptbuild` makes the tables of the current process `p`. The text is
found at the RAM address of the shared text segment, if there is one,
and the data and stack in the process's own image (#l("taddr = daddr = p->p_addr;")--#l("taddr = p->p_textp->x_caddr;")), as in v7's
`sureg`.

The text and the data occupy `n` pages from address 0 upwards; they
need one second-level table for each gigabyte they reach (#l("n2 = (n+PTPGB-1) / PTPGB;")) and one
third-level table for each 2~MB (#l("n3lo = (n+511) / 512;")). The stack, which ends at
`USRSIZE`, needs one third-level table for each 2~MB (#l("n3hi = (u.u_pssize+511) / 512;")) and, if it is
not empty, one second-level table, for the third gigabyte. `estabur`
ensures that text and data stay within the first two gigabytes and the
stack within the third. A process with nothing mapped, such as process
0, needs no tables at all (#l("if(n == 0)")).

The pages are taken from the pool as one run (#l("if((a = malloc(ptmap, n)) == 0) {")). If the pool is
exhausted, the process is killed, as `xalloc` (#f("text.c")) kills one
for which no `text` entry remains; its first-level table stays empty,
so that any reference to its address space faults. With `NPTAB`
(#f("param.h")) pages, this happens only when many large processes are in
RAM at once.

The run is cleared, and laid out in order: the second-level tables of
the low gigabytes, their third-level tables, the second-level table of
the stack's gigabyte, and its third-level tables. An entry which points
to a table holds its physical address and the type `PTE_TAB`
(#f("seg.h")). Consecutive tables of a level are consecutive in memory,
so the 512-entry tables may be treated as one longer array: the low
third-level tables are entered in the second-level tables from their
first entry (#l("for(i = 0; i < n3lo; i++, a += PGSIZE)"), #l("t[i] = a | PTE_TAB;")), and the text and data pages in the third-level
tables from their first (#l("b = ptob((unsigned)taddr);")--#l("*t++ = b | PGUSER | RW;", after: "for(i = 0; i < u.u_pdsize; i++, b += PGSIZE)")). The text pages carry the access
rights of the prototype; the data pages, from `USIZE` pages into the
image, are read and write.

The stack's tables are entered at the top of their second-level table
(#l("for(i = 0; i < n3hi; i++)"), #l("t[512-n3hi+i] = (a += PGSIZE) | PTE_TAB;")), and its pages at the top of its third-level tables, mapped
upward from the page after the data (#l("t += 512 + 512*n3hi - u.u_pssize;")--#l("*t++ = b | PGUSER | RW;", after: "for(i = 0; i < u.u_pssize; i++, b += PGSIZE)")), so that the last page of
the image is the last page below `USRSIZE`. The attributes other than
the access rights are `PGUSER` (#f("seg.h")), among them "not
global", which lets `ttbset` (#f("mch.s")) discard the user's
translations alone.

#lines-to("/*", lead: true, after: "}")

`ptfree` returns a process's tables to the pool and empties its
first-level table. It is called whenever the tables no longer describe
the image: by `estabur` when the prototype changes, by `expand`
(#f("slp.c")) when the image moves, by `xswap` (#f("text.c")) when it
leaves RAM, and by `exit` (#f("sys1.c")). The first-level table is
emptied even when there were no tables, so that a slot of the process
table always begins with an empty address space.

#lines-to("/*", lead: true, after: "}")

`sureg` builds the tables of the current process if it has none, and
loads them with `ttbset` (#f("mch.s")), which also discards the
previous process's translations. At a process switch, the usual case,
the tables already exist and only `TTBR0` changes; after the process
has been created, swapped in, or moved, or its sizes have changed, they
are built afresh. A text in RAM never moves while a process which uses
it is in RAM, so the tables of a process need never change because of
another.

#lines-to("/*", lead: true, after: "}")

`estabur` makes v7's two checks. Separate instruction and data spaces
(`sep`), which the PDP-11/40 lacked and v7 refused there, cannot be had
on the ARM either (#l("if(sep)"), #l("goto err;", after: "if(sep)")). The text, data, and stack must fit the
address space as the tables are arranged, as v7 required them to fit
its eight segments (#l("if(nt+nd > 2*PTPGB || ns > PTPGB)")): text and data in the first two gigabytes, the
stack in the third, so that they never overlap. `PTPGB`
(#f("seg.h")) is the number of pages in a gigabyte. And the image,
with its per process data area, must not exceed `maxmem` (#l("if((int)(nt+nd+ns+USIZE) > maxmem)"), #l("goto err;", after: "if((int)(nt+nd+ns+USIZE) > maxmem)")),
which `startup` (#f("machdep.c")) has limited to `MAXMEM`. The sum is
cast to `int` for that comparison, because `maxmem` is an `int`: C99
would otherwise compare the two as unsigned, as v7 did, and the
compiler would warn of it. The test at line #l("if(nt+nd > 2*PTPGB || ns > PTPGB)") has already bounded the sum, so
the cast cannot make it negative.

The prototype is then recorded (#l("u.u_ptsize = nt;")--#l("u.u_pxrw = xrw;")), the old tables are released,
and new ones built and loaded. Callers ask for a mapping before the
image itself has changed: `grow` and `sbreak` check the new sizes
before they call `expand`, and `xalloc` (#f("text.c")) asks for the text
alone, writable, while it reads the text in. Between the call and the
change the mapping may name pages which the image does not yet have,
but nothing touches them until `expand` has moved the image and built
the tables again.

#lines-to(none)
#source("/usr/sys/sys/slp.c")

#f("slp.c") is the heart of process management. It holds the procedures
by which a process gives up the processor (`sleep`, `swtch`), by which
another makes it runnable again (`wakeup`, `setrun`), the calculation of
user priorities (`setpri`), the scheduler proper (`sched`, `swapin`),
and the two procedures which create or move a process image in RAM
(`newproc`, `expand`). Apart from the C99 dressing and a few additions
for the ARM, described below, the file is v7's, and it is the clearest
place to see that the port changed the machine under the system rather
than the system itself.

Everything here turns on the pair `save` and `resume` (#f("mch.s")),
which switch between processes. `save(lab)` stores in the `label_t` `lab` the registers
which a called procedure must preserve, together with the stack pointer
and the return address, and returns zero. `resume(a, lab)` makes the
process image at page number `a` the current one, by mapping its
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
label which is used (#f("mch.s")); the comment at line #l("* The rsav (ssav) contents are interpreted in the new address space") says as much.

The declaration of `swapin` (#l("int\tswapin(struct proc *p);")) is new. `sched` (#l("if (swapin(p))")) calls it before
its definition, as `printf` calls `printn` (#f("prf.c")); no other file uses it, so the declaration is here and not in #f("systm.h").

A process sleeps on a _channel_: an address which by convention stands
for the event awaited, such as that of the buffer or inode concerned.
Processes which sleep are kept on `SQSIZE` short lists, chained through
`p_link`. `HASH` (#l("#define HASH(x)\t(( (int) x >> 5) & (SQSIZE-1))")) picks the list from the address of the
channel. The cast to `int` may now give a negative number for a kernel
address with its top bit set, but the mask removes the sign.

#lines-to("/*")

`sleep` records why (`chan`) and how urgently (`pri`) the current process
waits, puts it on the appropriate sleep list, and calls `swtch`.

Interrupts are masked by `intr_disable` (#l("s = intr_disable();", after: "rp = u.u_procp;")) (#f("mch.s")), so that no interrupt handler can call `wakeup`
while the proc entry and the list are half changed. The repeated test
of `chan` (#l("if (chan==0)", after: "rp->p_wchan = chan;")) is v7's.

#lines-to("if(pri > PZERO) {")

If `pri` is above `PZERO`, the sleep may be broken by a signal.
A signal already pending (#l("if(issig()) {")) cancels the sleep before it has begun.
Otherwise, if `sched` is waiting on `runin` for a sleeping process to
swap out (#l("if(runin != 0) {")), it is roused, since this process is now such a candidate.
After `swtch` returns, the signal test is repeated (#l("if(issig())", after: "wakeup((caddr_t)&runin);")): a signal is one
of the events which may have ended the sleep, by way of `setrun`.

#lines-to("/*", lead: true)

A signal is handled by abandoning the system call altogether.
`resume` to `u.u_qsav` with the process's own address is a non-local
goto: control reappears in `trap` as a second return from the
`save(u.u_qsav)` made there before the system call routine was entered,
and `trap` reports `EINTR`.

Note that callers of `sleep` above `PZERO` are therefore never told that
they were interrupted; any locks they hold must be such that the
abandoned system call leaves nothing inconsistent.

#lines-to("/*", lead: true, after: "}")

`wakeup` walks the one list on which processes sleeping on `chan` may
be, unlinks each such process, clears its channel, and hands it to
`setrun`. Several unrelated channels may hash to the same list, hence
the test of `p_wchan` (#l("if(p->p_wchan==chan && p->p_stat!=SZOMB) {")). Since `p_link` is reused by `setrun` to put
the process on the run queue, the successor is taken (#l("sp = slpque[i] = p->p_link;"), #l("sp = q->p_link = p->p_link;")) before
`setrun` is called.

#lines-to("/*", lead: true, after: "}")

`setrq` adds a process to the run queue `runq`, a list chained through
the same `p_link`: a process is either asleep or runnable, never both.
The search for a duplicate is purely diagnostic, as the comment admits.

`setrq` is now `static`, since only #f("slp.c") calls it; this spares it
a declaration in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand.

#lines-to("/*", lead: true, after: "}")

`setrun` is called from interrupt routines, from `wakeup`, and from
places such as `psignal` which wish to rouse a process whatever it is
waiting for. In the last case the process is still on a sleep list, and
`wakeup` of its channel (#l("if ((w = p->p_wchan)) {")) is the correct way to take it off. The
doubled parentheses at 153 are those of #f("malloc.c").

#lines-to("if(p->p_pri < curpri)")

If the newly runnable process is more urgent than the current one,
`runrun` asks for a call of `swtch` at the next opportunity, which is the
return from a trap or interrupt to user mode. If `sched` is idle (#l("if(runout != 0 && (p->p_flag&SLOAD) == 0) {"))
for want of a runnable swapped-out process, and this is one, `sched` is
woken.

#lines-to("/*", lead: true)

`setpri` computes the priority with which a user process will compete:
`PUSER`, plus a share of recent processor use (`p_cpu`, which `clock`
increments each tick and decays each second), plus the bias `p_nice`.
The result is never above 127, so that it fits in the `char` `p_pri`.

The `0377` mask (#l("p = (pp->p_cpu & 0377)/16;")) undid the sign extension of a PDP-11 `char`. On
the ARM `char` is unsigned and the mask changes nothing, but it is
harmless and is v7's.

The reader may be puzzled that `runrun` is set (#l("if(p < curpri)")) when the process
whose priority was just computed is better than `curpri`, whereas that
process may not be the current one. `clock` calls `setpri` for every
user process once a second, and it is precisely when one of these has
become more deserving than the running process that a switch is wanted.

#lines-to("/*", lead: true, after: "}")

`sched` is the endless loop of process 0, entered from `main` after
`newproc` has made process 1. It moves images between RAM and the
swap area: it chooses the runnable swapped-out process which has been
out longest (#l("for (rp = &proc[0]; rp < &proc[NPROC]; rp++)", after: "outage = -20000;")--#l("}", after: "outage = rp->p_time - (rp->p_nice-NZERO)*8;")), weighted by `p_nice`, and tries to bring it in.
If there is none, it sleeps on `runout` (#l("sleep((caddr_t)&runout, PSWP);")), to be roused by `setrun`
or by `xswap` (#f("text.c")).

If there is no room for the chosen process (#l("if (swapin(p))")), a victim is sought:
first the largest process sleeping at a priority from which a signal
could rouse it, or stopped by tracing (#l("if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) ||")); failing that, the process
which has been longest in RAM. The victim is swapped out only if the
first kind was found, or if the process to be brought in has waited 3
seconds and the victim has had 2 (#l("if (maxsize>=0 || (outage>=3 && inage>=2)) {")); otherwise `sched` sleeps on
`runin`, which `clock` wakes each second, `sleep` (#l("if(runin != 0) {")) when a
candidate appears, and `mfree` (#f("malloc.c")) when RAM is freed.

The parentheses added in (#l("if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) ||")) make explicit v7's reliance on `&&`
binding more tightly than `||`, of which `gcc` warns otherwise; the
meaning is unchanged. The same change appears throughout the system.

If the swap area has no room for the victim, `xswap` returns zero
(#l("if (xswap(p, 1, 0))")), where v7 panicked. The victim keeps its RAM, `SLOAD` is set
again (#l("p->p_flag |= SLOAD;", after: "if (xswap(p, 1, 0))")), and `sched` sleeps on `runin` as though no victim had been
found, to try again when `clock` or `sleep` wakes it. The process
waiting to come in waits longer; nothing else is disturbed.

On the PDP-11 this code was in constant use. Here RAM is ample, and
in practice the first search always fails or `swapin` succeeds; the
code is kept intact all the same, together with the swap area which
`fork` insists upon.

#lines-to("/*", lead: true, after: "sleep((caddr_t)&runin, PSWP);")

`swapin` allocates RAM for the data area and, if the process has a
shared text segment not yet in RAM, for the text as well; reads both
in; and releases the swap space. It returns zero, having undone its
allocations, if either `malloc` fails.

A text read back from the swap area is new to the instruction cache, which
may hold stale lines for the same memory; `arm_sync_icache`
(#f("mch.s")) is called on it, as in `xexpand` (#f("text.c")). The
include of #f("seg.h") (#l("#include \"../h/seg.h\"")), for `PGADDR`, is for that call. The
doubled parentheses at 305 are those of #f("malloc.c").

#lines-to("/*", lead: true, after: "}")

`qswtch` gives up the processor without sleeping: the current process
is put back on the run queue and `swtch` is called. `trap` uses it when
`runrun` is set.

#lines-to("/*", lead: true, after: "}")

`swtch` chooses the next process to run and runs it. It works in three
stages and involves, in general, three
processes: the one giving up the processor, process 0, which always
acts as an intermediary, and the one taking it over.

#lines-to("if (u.u_procp != &proc[0]) {")

Unless the caller is process 0 itself, its state is saved in
`u.u_rsav` and process 0 is resumed at `u.u_qsav`. The zero return from
`save` (#l("if (save(u.u_rsav)) {")) continues on the second branch; the nonzero return comes
much later, when this process is chosen again, and then `sureg`
re-establishes its user mappings before `swtch` returns to its caller.

Before process 0 runs, and through it another process, the floating
point registers are stored in the u-area unless that has already been
done since this process entered the kernel (#f("user.h")). The kernel
itself never touches them, so they still hold this process's values;
the next process to return to user mode loads its own.

#lines-to("/*")

The double `save` (#l("if (save(u.u_qsav)==0 && save(u.u_rsav))")) is explained by its comment. The point to grasp
is that `u.u_qsav` in process 0 marks the entrance to the search loop:
every switch passes through it by the `resume` of (#l("resume(proc[0].p_addr, u.u_qsav);")).

#lines-to("intr_disable();")

With interrupts masked, the run queue is searched for the
loaded runnable process of best (lowest) priority, and that process is
removed from the queue. If there is none, `idle` waits for an interrupt
and the search is repeated. On the PDP-11 `idle` executed `wait`; here
it unmasks the IRQ and executes `wfi`.

#lines-to("/*", after: "curpri = n;")

The incoming process is resumed at `u.u_rsav` unless it has
`SSWAP` set (#l("n = p->p_flag&SSWAP;")), in which case it is resumed at `u.u_ssav`. The flag is set
by `newproc` (#l("rpp->p_flag |= SSWAP;")), by `expand` (#l("p->p_flag |= SSWAP;")), and by `xexpand` (#f("text.c")),
all of which made an image of a process (on the swap area or in fresh
RAM) after doing `save(u.u_ssav)`. In such an image `u.u_rsav` is stale:
it was recorded by some earlier switch, or, in `expand`'s case, by the
call of `swtch` from `qswtch` (#l("qswtch();")), after the image had already been
written. Hence the explicit choice of label.

Note that the ARM `resume` masks interrupts while the mapping and
registers are changed and, like the PDP-11 version, which ended at
priority zero, unmasks them again with `intr_enable` once the new stack is in
place (#f("mch.s")).

v7 called `spl0` here, before `resume`, after `curpri` was set. The call
is gone, so that interrupts stay masked from the search through to the
point in `resume` where the new stack pointer is loaded. The reason is
the compiler. The call of `resume` is the last statement of `swtch`, and
GCC makes it a tail call: it pops `swtch`'s own stack frame, the saved
registers and the return address, and then branches to `resume`. In
process 0 that frame is not dead, for `u.u_rsav`, which `swtch` saved
in it (#l("if (save(u.u_qsav)==0 && save(u.u_rsav))")), still points at it: when process 0 is itself chosen, it
returns from `swtch` through the very words just popped. An interrupt
taken between the pop and `resume`'s masking would push its register
frame over them, and process 0 would later return through the frame's
saved status word as though it were an address. With interrupts masked
nothing can be pushed there.

#lines-to("/*", lead: true, after: "}")

`newproc` is the body of `fork`, and of the creation of process 1 by
`main`. It returns 1 in the new process and 0 in the old.

#lines-to("retry:")

A process id is chosen which is in use neither as a process id
nor as a process group, cycling below 30000. At the same time the first
empty slot of `proc` is noted. `fork` (#f("sys1.c")) has already made
sure that one exists.

#lines-to("rip = u.u_procp;")

The new entry is filled in, and the reference counts of
everything the child will share with its parent, its open files, text,
and current and root directories, are incremented.

#lines-to("/*", after: "u.u_rdir->i_count++;")

The child's image is a copy of the parent's, `u` included, made after
the parent has done `save(u.u_ssav)` (#l("if (save(u.u_ssav)) {", after: "* here's where it will resume.")). Before the copy,
`u.u_procp` is set to the child's entry (#l("u.u_procp = rpp;")), so that the copy differs
from the original in that one respect; the parent restores it (#l("u.u_procp = rip;")), and
loads its own page tables again (#l("sureg();", after: "u.u_procp = rip;")), for the reason given below.

The floating point registers are stored in the parent's u-area just
before (#l("if (u.u_fpsaved==0) {", after: "rpp->p_size = n;")--#l("}", after: "rpp->p_size = n;")), so that the copy holds them, with `u_fpsaved` set,
and the child loads them on its first return to user mode
(#f("trap.c")), whichever process has used the unit since. v7 did not
store them here, and its child took whatever the registers held when it
first ran, usually, but not always, its parent's values.

When the child is first chosen by `swtch` its `SSWAP` flag (#l("rpp->p_flag |= SSWAP;")) causes
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

#lines-to("if(a2 == NULL) {")

If there is no RAM for the copy (#l("if(a2 == NULL) {", after: "* copy.")), the parent's image is written
to the swap area as the child's image, without freeing the RAM
(`xswap` with second argument zero). `rpp->p_addr` is pointed at the
parent's RAM for the purpose, and `SIDL` keeps the parent from being
chosen for swapping in the meanwhile. While `xswap` waits for the
write, the parent sleeps and is resumed in `swtch` as the child, for
`u.u_procp` names the child's entry: the `sureg` there builds page
tables in the child's slot, mapping the parent's RAM, and loads them.
`xswap` frees them once the image is written (#f("text.c")), and the
`sureg` at (#l("sureg();", after: "u.u_procp = rip;")) points the processor back at the parent's own tables.
The value of `xswap` is not tested here: it cannot be zero, because
`fork` has just found swap space for an image of this size
(#f("sys1.c")), and nothing has slept since. Otherwise (#l("rpp->p_addr = a2;")) the image is
copied, a page at a time, by `copyseg` (#f("machdep.c")). On the PDP-11
`copyseg` had to borrow a user segmentation register to reach physical
memory; here the kernel maps all of RAM, and `PGADDR` turns a page
number into an address.

The copy is of the whole image, as in v7: the per process area, the
data, and the stack, which is no more than the program has asked for
(`getxfile`, #f("sys1.c")). A small program's image is a few pages.

#lines-to("/*", lead: true, after: "return(0);")

`expand` changes the size of the current process's image to `newsize`
pages. A shrinking image simply gives back its tail (#l("mfree(coremap, n-newsize, a1+newsize);")). A growing
one is copied into a new area (#l("for(i=0; i<n; i++)")), after which `resume` (#l("resume(a2, u.u_ssav);"))
switches to the copy, whose `save` (#l("if (save(u.u_ssav)) {", after: "mfree(coremap, n-newsize, a1+newsize);")) then returns 1. The comment's
"taking care to reset registers" is a PDP-11 relic in effect: since `u`
and the kernel stack always appear at the same virtual address, the
copy needs no adjustment, and `resume` only has to remap `u` to the new
area. The page tables of the old image are released first (#l("ptfree(p);")), and
`sureg` builds new ones for the copy (#f("ureg.c")). A shrinking image
keeps its tables: the caller has already set the new sizes with
`estabur`, whose tables no longer reach the tail given back.

If there is no RAM (#l("if(a2 == NULL) {", after: "a2 = malloc(coremap, newsize);")), the image is written to the swap area at its
old size `n` but with `p_size` already set to the new one, the old area of RAM
is freed, and the process gives up the processor with `SSWAP` set. The
floating point registers are stored in the u-area first (#l("if (u.u_fpsaved==0) {", after: "a2 = malloc(coremap, newsize);")--#l("}", after: "a2 = malloc(coremap, newsize);")),
since the copy on the swap area is the one which will come back, and
`swtch` would store them only after it had been written; v7 omitted
this. When
`sched` brings it back, `swapin` allocates the larger size, and the
process resumes at `u.u_ssav` (#l("if (save(u.u_ssav)) {", after: "mfree(coremap, n-newsize, a1+newsize);")) and returns from `expand` as if
nothing had happened. Note that until `swtch` resumes another process it
goes on running in RAM which is already free; nothing can reallocate
it in that interval, since no interrupt routine allocates RAM.

If there is no swap space either, `xswap` fails (#l("if (xswap(p, 1, n) == 0) {")), and v7 panicked.
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

#lines-to(none)
