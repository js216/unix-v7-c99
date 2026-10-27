#import "defs.typ": *

== Startup and Processes <ch-startup>

This chapter follows the kernel from its first instruction to its
first process, through the tables and routines which set up memory,
start the machine, and create and switch processes.

#source("/usr/sys/h/map.h")

A resource map is a list of the free areas of some resource. Each
element gives the size of one area and the address of its first unit,
both measured in whatever unit suits the resource. The system keeps
two such lists, for the swap area and for the pages set aside at boot
for user page tables (`NPTAB`, #f("param.h")), and both are managed by
the two procedures `malloc` and `mfree` of #f("malloc.c"). The page tables are measured in
pages of 4096~bytes, the unit in which the MMU maps memory, and the
swap area in 512-byte disk blocks. RAM itself is not kept in a map,
but handed out a page at a time, by `pgalloc` in the same file.

#lines-to("extern struct map swapmap[];", lead: true)

The maps themselves follow: `swapmap` for the swap area, and, new in
the port, `ptmap` for the pages of user page tables (#f("ureg.c")).
In v7 a third, `coremap`, listed the free RAM.

#lines-to(none)
#source("/usr/sys/sys/malloc.c")

This file holds the two procedures which manage a resource map
(#f("map.h")), `malloc`, which takes an area out of the free list, and `mfree`, which
puts one back, and the port's allocator of RAM, a page at a time, with
the page maps built from it.
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
  leaves zeros behind it, and `mfree` depends on this when it lengthens the
  list.

Neither procedure checks for the end of the array, so the arrays must
be large enough never to overflow. A map can hold no more free areas
than there are allocated areas between them, plus one, and it needs one
entry more for the sentinel. `SMAPSIZ` and `PMAPSIZ` (#f("param.h")) are computed from this bound, and the
configuration gives the maps those sizes
(#f("c.c")).

#lines-to("int")

The routine `malloc` uses the "first fit" rule: it takes the first area in the list
which is large enough, and allocates from its low end. The search (#l("for (bp=mp; bp->m_size; bp++) {"))
stops at the sentinel, whose size is zero.

#lines-to("a = bp->m_addr;")

The request is carved off the front of the area (#l("a = bp->m_addr;")--#l("bp->m_addr += size;")). The entry
remains, describing what is left.

If nothing is left (#l("if ((bp->m_size -= size) == 0) {")), the entry must go. Every following
entry, up to and including the sentinel, is moved down one place.
Notice that the loop copies the address before it tests the size, and
that the test is the value of the size just copied, not a comparison.
The loop stops after it has copied the sentinel's zero. The old slot of
the sentinel keeps its own zero, which is the fourth rule above.

#lines-to("return(a);")

The address is returned (#l("return(a);")). Zero (#l("return(0);", after: "malloc(struct map *mp, int size)")) means failure. This is safe only because no free area ever
begins at address zero. For the page tables, the addresses are physical page numbers, and neither machine
has RAM at address zero. For swap, `startup` (#f("machdep.c")) frees the
map starting at block 1, and decrements `swplo`, the first block of the
swap area on its device, to compensate. So block zero of the swap area
is never named.

#lines-to("for (bp = mp; bp->m_addr<=a && bp->m_size!=0; bp++);")

The loop with the empty body (#l("for (bp = mp; bp->m_addr<=a && bp->m_size!=0; bp++);")) steps `bp` forward past every area
which begins at or below `a`. At its end, `bp` points to the first area
above the one being returned, or to the sentinel. The new area belongs
just before `bp`.

There are now four cases. If the area being returned begins where the
previous area ends (#l("if (bp>mp && (bp-1)->m_addr+(bp-1)->m_size == a) {")--#l("(bp-1)->m_size += size;")), the previous entry simply grows.

If it now also reaches the next area (#l("if (a+size == bp->m_addr) {")--#l("}", after: "(bp-1)->m_size = bp->m_size;")), the two entries become
one: the previous entry absorbs the next, and the rest of the list,
sentinel included, moves down one place. As in `malloc`, the slot
vacated at the end keeps its zero size. If `bp` is the sentinel, its
address is meaningless, and the test at line #l("if (a+size == bp->m_addr) {") may succeed by chance.
It then adds a zero size and the loop does not run, so no harm is done.

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

A zero `size` (#l("} else if (size) {")) changes nothing. It is tested only in this last case, since in the others adding zero is harmless.

#lines-to("/*", lead: true)

RAM is not kept in a resource map. After boot every piece of RAM the
kernel takes is a single page: a process's image and a text are lists
of pages, and the u-area is one page (`USIZE`, #f("param.h")). A map of
single pages could split into as many entries as there are free
pages, so the free pages are kept instead on a stack, `pgstk`, an array
of their numbers, which `startup` (#f("machdep.c")) makes large enough
for all of RAM and fills. Taking a page and giving one back cost one
step each, and a free page is never written while it is free. That
matters to `exit`, which gives back the u-area page on which it is
still running.

Giving back a page may let the scheduler bring in a process which is
waiting on disk. If `sched` (#f("slp.c")) has gone to sleep for want of
RAM (`runin` set), it is woken (#l("if (runin) {")). The kernel is not preempted,
so `sched` cannot look at the stack before `pgfree` returns.

#lines-to("/*", lead: true, after: "int\t*pgstk;")

A page map lists the pages of a process's image, or of a text, in
order. Two levels suffice. The root page holds the numbers of up to
`NPM`, 1024, list pages, and each list page the numbers of 1024 pages,
so one map reaches 4~GB, more than all of RAM. A map of $n$ entries
has its root and the list pages of entries 0 to $n-1$, and nothing
more, so the map of no entries is no page at all, 0. The routine
`mapent` finds an entry through the root, by the kernel addresses of
the two pages (`PGADDR`, #f("seg.h")).

#lines-to("/*", lead: true, after: "#define\tNPM")

The routine `mapneed` counts the pages which growing a map takes: one for each new
entry, one for each list page begun, and the root if the map was
empty. Every caller compares it with `npgfree` before it changes
anything, so that a growth never stops halfway.

#lines-to("/*", lead: true, after: "mapneed(int n0, int n1)")

The routine `mapalloc` checks the count itself as well (#l("if (mapneed(n0, n1) > npgfree)")). It takes the root if
the map had none, and clears it, and a list page whenever an entry
begins one (#l("if (i%NPM == 0) {", after: "mapalloc(int *mp, int n0, int n1)")). The new pages are not cleared. Whoever grows a map
fills or clears the pages itself.

#lines-to("/*", lead: true, after: "mapalloc(int *mp, int n0, int n1)")

The routine `mapfree` gives the pages back from the end: each entry's page, then
the list page when the entry was its first, and at last the root, when
no entry is left.

#lines-to("/*", lead: true, after: "mapfree(int *mp, int n0, int n1)")

The routine `maprot` moves pages within an image without copying them. It turns the
entries from `a` to `c` around, so that those from `b` come first, by
three reversals: of `a` to `b`, of `b` to `c`, and of the whole. A call
of `brk` and the growth of the stack use it to move the stack past
pages added or taken away at the end of the image (#f("sys1.c"),
#f("sig.c")).

#lines-to(none)
#source("/usr/sys/sys/prf.c")

The kernel's means of speaking to the operator. The routine `printf` writes
directly to the console, one character at a time, without buffering
and without interrupts. It is used at startup, for hardware errors, and
for the last words of a dying system. It serves `panic`, `prdev`, and
`deverror`, and in turn calls `printn` for numbers and
`putchar` for each character.

The QEMU machine's `putchar` is in #f("pl011.c"), the MP135 machine's
in #f("usart.c"). Both keep a copy of everything printed
in `msgbuf` and follow a newline with a carriage return. Each waits, at
most a tick, for the transmitter to have room, and writes the character
with the transmitter interrupt masked.

#lines-to("/*")

The variable `panicstr` is set by `panic` and read by nothing in the system. It
exists so that whoever examines RAM after a crash can find the
message, even if the console printed nothing.

#lines-to("/*", lead: true, after: "char\t*panicstr;")

The comment promises `%d`, `%u`, `%o`, `%x`, `%s`, and `%D`. There is no
`%c` and no field width. An unrecognised conversion is printed as written (#l("} else {")--#l("}", after: "putchar('%');")), and a `%` at
the very end of the format ends it (#l("c = *fmt++;")--#l("}", after: "c = *fmt++;")). In v7, `printf` dropped the
first silently, leaving its argument to the next conversion, and read
past the terminating null on the second.

The conversion `%D` (#l("} else if (c == 'D') {")) prints a `long`, which here has the same 32~bits as an `int`,
so `%D` and `%d` print the same.

The other numeric conversions fetch their argument as `unsigned` (#l("printn(va_arg(adx, unsigned),")).
The v7 code converted it to `long`, which on the PDP-11 widened 16~bits to 32
and could never produce a negative value. So `%d` of $-1$ printed 65535,
which is what the comment means by "`%d` (==`%u`)". Here `unsigned` and
`long` are the same size, and the conversion would turn any value of
$2^31$ or more negative: a kernel address such as `0xc0101234` would
print as `-3FEFEDCC`. The cast is gone and `printn` takes an
`unsigned long`, so the value arrives intact. Printed with `%d`, $-1$ appears as 4294967295, as
the comment promises.

#lines-to("/*", lead: true, after: "}")

The routine `printn` produces the digits of `n` in base `b` by printing the higher
digits, `n/b`, recursively, and then the lowest. The recursion ends
because each call divides by at least 8. A 32-bit number has at most
eleven octal digits.

The number is unsigned, as the comment (#l("* Print an unsigned integer in base b.")) says, so v7's
test for a negative `n` is gone. The sign of a `%D` argument is printed
by `printf` instead (#l("l = va_arg(adx, long);")--#l("printn(l, 10);")). It negates the value as `unsigned long`,
so that even $-2^31$ comes out right.

#lines-to("/*", lead: true, after: "}")

A call of `panic` is the system's response to a state it cannot repair. It
records the message, writes out what it can, prints, and stops.

First `update` (#l("update();"), #f("alloc.c")) writes the super-blocks, the modified
inodes, and the delayed-write buffers to disk, so that as little as
possible of the file systems is lost. If the panic arose in the disk
code itself, this may not succeed, and if `update` was already running
when the panic came, its lock `updlock` makes it return at once.
The lock is held from the start (#f("main.c")), and `main` releases it only once `binit` has built the buffers. Until then `update` would walk
a free list not yet linked.

#lines-to("for(;;)")

The system does not halt but idles for ever. On the PDP-11, `idle`
(#f("mch.s")) was a `wait` instruction at processor
priority zero. On ARM it enables interrupts with `cpsie i`, waits for
one with `wfi`, and disables them again. Interrupts therefore continue
to be taken: transfers already under way, including those started by
`update`, complete, and the clock keeps running. The only way out is
to restart the machine.

#lines-to("/*", lead: true)

The routine `prdev` reports a problem with a device, giving its major and minor
numbers. It is used mainly by the file system code in #f("alloc.c"),
for a full or corrupted file system.

#lines-to("/*", lead: true, after: "}")

A disk driver whose transfer has failed calls `deverror`. The
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
(#l("extern unsigned corebase, coretop, coreoff;")), but defines the constants and simple types upon
which the remainder of the system is built. As elsewhere in UNIX,
defined constants are written in upper case only.

The file falls into six parts, the tunable parameters, the priorities,
the signals, the "fundamental constants", some conversion macros and
types, and finally a few machine-dependent definitions.

These are the parameters which an installation may reasonably alter.
Most of them fix the dimensions of tables which are allocated
statically, once and for all, when the system is built. Among them are
`NBUF` for the buffer cache, `NINODE` for the inodes held in RAM,
`NFILE` for the open file table, and `NPROC` for the process table. Doubling `NPROC`
costs space in every system, whether the processes exist or not.

No constant limits the size of a process. An image may grow to all of
the free memory, `maxmem` pages, which `startup` (#f("machdep.c"))
counts at boot.

The disk holds the root file system, and after it the swap area. The
administrator decides how big each one is. The second line of
`boot/rootfs.proto` gives the size of the root file system in blocks
and its number of inodes, and `mkfs` reads it. The configuration
(#f("c.c")) gives the block where swap starts,
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

`SMAPSIZ` and `PMAPSIZ` (#l("#define\tSMAPSIZ\t(2*NPROC+NTEXT+2)\t/* swap allocation area size */")--#l("#define\tPMAPSIZ\t(NPROC+2)\t/* size of page table allocation area */")) are the sizes of the two
resource maps (#f("map.h")). They are derived from a bound on the number of free areas. Each free area of a map lies between
two allocated ones, so the free areas number at most one more than the
allocated areas, and the map needs one entry more for its sentinel
(#f("malloc.c")). The swap area holds at most an image for each
process and a copy of each text, `NPROC+NTEXT` areas. The size allows
for `NPROC` more, a margin kept from v7, whose `exec` also put each
argument list there. The pool of user page tables
(#l("#define\tNPTAB")) is allocated with the second map, `ptmap` (#f("ureg.c")). Each
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
which uses it, so heavy sharing of a large text can exhaust the pool, and
`ptbuild` then kills the process with "out of page tables".

`HZ` (#l("#define\tHZ\t60\t\t/* Ticks/second of the clock */")) is the number of clock interrupts per second. The PDP-11 took
its clock from the mains frequency. Here the ARM generic timer is
programmed to interrupt `HZ` times each second (`clkstart`, #f("machdep.c")).

The local time zone (#l("#define\tTIMEZONE (5*60)\t\t/* Minutes westward from Greenwich */"), #l("#define\tDSTFLAG\t1\t\t/* Daylight Saving Time applies in this locality */")) is compiled into the system. This is why
`date` reports Eastern time unless the kernel is rebuilt.

#lines-to("/*", after: "#define\tNCARGS\t5120\t\t/* # characters in exec arglist */")

Priorities for processes which `sleep`. The lower the value, the more
urgent the process: `PSWP` is the most urgent of all. A process which
sleeps at a priority of `PZERO` or less cannot be disturbed by a
signal. One which sleeps above `PZERO` may be, and will then return
from the system call prematurely. The reader will find this
distinction tested in `sleep` (#f("slp.c")).

#lines-to("/*", after: "#define\tPUSER\t50")

`NSIG` (#l("#define\tNSIG\t17")) is one more than the number of signals, since signal
zero means "no signal". The pending signals of a process are kept as
bits in `p_sig` (#f("proc.h")), and the comment's limit of sixteen is
that of a PDP-11 word. The field is now an `int`, but the sixteen
signals are kept, since the shell's tables and the programs which name
signals expect them. Fifteen have names, and the sixteenth may be sent,
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

The conversion macros `ptob` and `btop` (#l("#define\tptob(x)"), #l("#define\tbtop(x)")) convert pages of
4096~bytes to bytes and back, rounding up, both as `unsigned`, since
physical addresses on the MP135 machine exceed the largest `int`. The macro `ptod` (#l("#define\tptod(x)\t((x)<<3)")) converts
pages to 512-byte disk blocks.

The macros `itod` and `itoo` (#l("#define\titod(x)\t(daddr_t)((((unsigned)x+7)>>2))"), #l("#define\titoo(x)\t(int)((x+7)&03)")) find inode `x` on the disk: the block of the
i-list which holds it, and its place in the block. An inode is 128
bytes, four to a block (#f("ino.h")), so the macros shift by 2 and mask
with 3. Inodes are numbered from 1 and the i-list begins at block 2, so
the addend, `2*INOPB-1`, which is 7, puts inode 1 in the first place of
block 2.

#lines-to("typedef\tstruct { int r[1]; } *\tphysadr;")

The type `label_t` (#l("typedef\tint\t\tlabel_t[10];\t/* regs 4-11, sp, lr */")) has ten words, for the registers which `save` (#f("mch.s")) stores, r4 to r11, the stack pointer, and the link
register.

A `time_t` (#l("typedef\tlong long\ttime_t;")) is a `long long`, a signed count of 64~bits, where v7's
was a `long`. On the PDP-11 and on the ARM alike a `long` is 32~bits,
and a signed count of seconds since 1970 in 32~bits ends on 19 January
2038, and 64~bits last for some 292 thousand million years. The ARM
aligns a `long long` on eight bytes, so every structure which holds a `time_t` is laid out anew. These are
the inode on the disk (#f("ino.h")), the
super-block (#f("filsys.h")), `stat` (#f("stat.h")), `user` and `proc` (#f("user.h"), #f("proc.h")), and the records of accounting, of the
login history, and of the archive formats which the commands keep.

#lines-to("/*")

`USERMODE` (#l("#define\tUSERMODE(ps)")) tells whether the interrupted program was in user
mode, from the mode bits of its status register, which `irq`
(#f("machdep.c")) passes to `clock` (#f("clock.c")).

#lines-to("extern unsigned corebase, coretop, coreoff;")

The declarations of variables. The value which differs between the
two machines, the end of RAM (`coretop`), is defined by the
configuration (#f("c.c"), #f("qemu/mach.h")). Where RAM
begins (`corebase`) and how far its kernel addresses lie from its
physical ones (`coreoff`) are computed by `machine_init` (#f("machdep.c")).

#lines-to(none)
#source("/usr/sys/h/systm.h")

#f("systm.h") is the kernel's collection of global variables and,
in the port, of declarations for the procedures which more than one
file calls. In v7 it held only the former, together with a handful of
function declarations, mostly for routines which return pointers.
Every other routine was declared implicitly by its first
call. Strict C99 has no implicit declarations, so the file has grown
from 81~lines to 311, nearly all of the growth being one long list.

#lines-to("extern\tint\tmpid;\t\t\t/* last process id given out */", lead: true)

The scheduler `sched` and `swtch` (#f("slp.c")) communicate through the
flags `runin`, `runout`, and `runrun`
(#l("extern\tchar\trunin;")--#l("extern\tchar\trunrun;")). The array `regloc` (#l("extern\tchar\tregloc[];\t/* locs. of saved user registers (trap.c) */")) is defined in
#f("trap.c").

The pointer `msgbufp` (#l("extern\tchar\t*msgbufp;\t/* next place in msgbuf */")) is the place in `msgbuf` where the next character
goes. Both console drivers append to the buffer, so it is defined in
#f("machdep.c").

The clock's variables (#l("extern\tunsigned long long clkcval;\t/* when the clock is next due */"), #l("extern\tunsigned clkreload;\t\t/* counts per tick */")) are set up by `clkstart` (#f("machdep.c")).
On each tick `clock` (#f("clock.c")) adds `clkreload`, the timer's
frequency divided by `HZ`, to the deadline `clkcval`. It also adds the
remainder of that division, `clkrem`, to `clkfrac`, and lengthens a
tick by one count whenever `clkfrac` reaches `HZ`, so that each second
lasts exactly the timer's frequency. The variables `l1tab` and
`l1pa` (#l("extern\tunsigned long long *l1tab;\t/* user first-level tables */"), #l("extern\tunsigned l1pa;\t\t/* their physical address */")) locate the first-level page tables of the processes,
one for each slot of the process table. The first gives their kernel
address, and the second the physical address which the hardware needs.
The tables are taken from RAM by `startup` (#f("machdep.c")) and filled
by `sureg` (#f("ureg.c")).

#lines-to("dev_t getmdev(void);", lead: true)

#lines-to("struct clist; struct map; struct text; struct tty; struct uprof;")

Each procedure which is called from another file, or before its definition, is declared once
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
v7 as returning `int`, by default. The handlers return nothing. Their
results go back to the user through `u.u_r`. It is now a pointer to a
`void` function of no arguments, and every handler is defined so.

#lines-to(none)
#source("/usr/sys/h/seg.h")

In v7, #f("seg.h") held the addresses of the PDP-11 memory management
registers (the KT-11 unit) and the bits of a segment descriptor. The
PDP-11 divided each address space into eight segments of up to 8~KB. Each was described by a pair of registers, an address register, giving the
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
always mapped `RW`. The page entries' other bits are `PGUSER` (#l("#define\tPGUSER")).

#lines-to("#define\tSIGTRAMP")

`SIGTRAMP` (#l("#define\tSIGTRAMP")) is the user address of the signal trampoline,
one read-only page which `startup` (#f("machdep.c")) fills at boot and
`ptbuild` (#f("ureg.c")) maps into every process. It is page 1, below
the programs' text at 0x8000 (#f("Makefile")), and `sigpage`
(#l("extern int sigpage;")) is its physical page.

`PGADDR` (#l("#define\tPGADDR(c)\t((char *)(((unsigned)(c)<<12)+coreoff))")) converts a page number into a kernel address.

#lines-to("#define\tBLK_KERN\t0x701ULL")

The remainder are constants of the ARM's long-descriptor tables
(#f("low.s")), used by `machine_init` (#f("machdep.c")), by `sureg`
(#f("ureg.c")), and by the table of regions in each machine's
#f("qemu/mach.h"). Each entry is 64~bits, of which the attributes occupy
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

`BLK_DEV` (#l("#define\tBLK_DEV\t0x60000000000405ULL")) describes device registers. The devices are mapped by pages
(`kmap`, #f("machdep.c")), and `PTE_TAB` turns the same bits into a page entry:

- attribute index 1, device memory, which is neither cached nor
  touched speculatively,
- the same permission and access flag,
- in the top word, the "execute never" bits for both privileged and
  user mode (bits 53 and 54), which keep the processor from fetching
  instructions from device memory, even speculatively, as the
  architecture requires.

Its shareability is
ignored. Both kinds of entry are reached only through the kernel's
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
both machines. `PGSHIFT` and `PGSIZE` (#l("#define\tPGSHIFT\t12"), #l("#define\tPGSIZE\t4096")) describe the 4~KB page, the unit of the user mapping. `DEVBASE` (#l("#define\tDEVBASE")) is the
kernel address of the 2~MB in which the registers of every device
are mapped, a page each, through the third-level table `kl3d` (#l("extern unsigned long long kl2[], kl3u[], kl3d[], bootl1[];")). `BLKSHIFT` and
`L1SHIFT` (#l("#define\tBLKSHIFT"), #l("#define\tL1SHIFT")) give the reach of an entry of a
second-level and of a first-level table, 2~MB and 1~GB, and `NPTE`
(#l("#define\tNPTE")) the number of entries in a table. The type `struct memregion` (#l("struct memregion { unsigned va, start, end; unsigned long long attr; };")) is that of
the table `board_map`, which #f("c.c") defines from the rows in the
machine's #f("qemu/mach.h"). Each entry is a range of
physical addresses, the kernel address at which it is to be mapped, and
the descriptor bits to use.

#lines-to(none)
#source("/usr/sys/conf/low.s")

#f("low.s") takes the place of v7's `l.s`, the "low core" file. On the
PDP-11, `l.s` filled the bottom of physical memory with the interrupt vectors, a new PC and PS for each trap and each
device. It also supplied, for every device, a two-instruction stub which entered the common routine
`call` with the address of the C handler. It was generated anew by
v7's `mkconf` for each configuration. None of that survives. The ARM has eight exception
vectors, and only one of them serves all devices. The interrupt
controller (GIC) is asked which device interrupted, and `irq`
(#f("machdep.c")) looks the answer up in `intrtab` (#f("c.c")). So #f("low.s") is the same for both machines. It holds what in v7 was split between `l.s` and the start of `mch.s`, the reset code (v7's `start`), the vectors, and the
assembler `trap` and `call` routines which build the register frame for
C.

A few ARM facts are needed throughout. The processor is always in one
of several modes, named by the low five bits of the program status register `cpsr`, user (`0x10`), IRQ (`0x12`), supervisor or SVC
(`0x13`), abort (`0x17`), undefined (`0x1b`), and system (`0x1f`). The
kernel runs in SVC mode, which plays the part of the PDP-11's kernel
mode. Each exception enters its own mode, and each mode except system
has private ("banked") copies of `sp` (`r13`) and `lr` (`r14`), and a
saved program status register `spsr`, into which the hardware copies
`cpsr` at the exception. The return address goes into the new mode's
`lr`. Bit 7 of `cpsr` (`I`) masks interrupts and bit 6 (`F`) the fast
interrupts, and `cpsid` sets and `cpsie` clears them. The registers `r0` to
`r12` are shared by all modes (apart from `r8` to `r12` in the unused FIQ
mode). Coprocessor 15 (`p15`), reached by `mrc` (read) and `mcr` (write),
holds the system control registers for the MMU, the caches, and the
like.

_Calling Convention._ Assembly language and C meet under the ARM
Procedure Call Standard (AAPCS). The first four arguments of a function
are passed in `r0` to `r3`, and its result is returned in `r0`. A
function may change `r0` to `r3`, `ip` (`r12`), and `lr`, but must
preserve `r4` to `r11` and `sp`. The instruction `bl` calls a function, leaving the
return address in `lr`, and `bx lr` returns.

The processor arrives at `_start` (#l("_start:")) from the boot loader in SVC mode.
Interrupts and fast interrupts are masked at once (#l("cpsid if", after: "_start:")), the analogue of
v7's `spl 7` state at the start.

The system control register `SCTLR` is then read, and five bits are cleared, those of the instruction cache (bit 12), the data cache (2), branch
prediction (11), "high vectors" (13), which would place the vectors at
`0xffff0000`, and the MMU itself (0). The instruction `isb` makes sure that the following instructions are fetched under the
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
later (#l("mcr p15, 0, r9, c7, c6, 2")). A `dsb` then waits for these operations to finish.

#lines-to("adr r4, _start")

The instruction `adr` (#l("adr r4, _start")) forms the address of `_start` from the PC, and so yields
where the kernel actually is. The literal `=_start` (#l("ldr r0, =_start", after: "adr r4, _start")) is the address
at which it was linked. Their difference, kept in `r4`, turns any
kernel address into a physical one.

#lines-to("ldr r0, =__bss_start")

The `bss` area is cleared, a word at a time, at its physical address. The bounds are symbols defined by the
linker script. The boot stack and the boot translation tables lie in
the area being cleared. This is harmless, since nothing has yet been
put in them.

#lines-to("ldr r5, =kl2")

The MMU is used in its "long-descriptor" format. Its tables have 8-byte entries. A first-level entry maps a gigabyte, a
second-level entry two megabytes, and a third-level entry a page. An
entry at either of the first two levels may map its whole range
directly, as a "block", instead of pointing to a table of the next
level.
The format can divide the address space between two tables, one for
the low addresses and one for the high, which the short-descriptor
format of the earlier ARMs cannot do at a three-gigabyte boundary. That
is why it is used. The kernel's table `kl2` (#l("kl2:")) is a second-level
table of 512~entries, which together map the gigabyte from 0xc0000000.

Here `kl2` receives one entry, for the 2~MB from `_start`, which points
to the third-level table `kl3k` (#l("kl3k:")), and `kl3k` receives the pages which
hold the kernel itself, from `_start` to the end of `bss`. The register
`r0` runs over their kernel addresses, `r1` is the end, and `ip` holds
each entry: the page's physical address, the kernel address plus `r4`,
or'ed with `BLK_KERN` (#at("/usr/sys/h/seg.h", "#define\tBLK_KERN")) and with `PTE_TAB`, which marks an entry of
the third level as a page. The index in the table, the nine bits above
the offset in the page, is taken by `ubfx`. The upper word of each
entry stays zero, since `bss` has just been cleared.

Pages are used rather than blocks of 2~MB because on the MP135 machine
the kernel lies in SYSRAM, at 0X2FFE0000, which is not at the same
place in its block as the kernel address 0xc0000000 is in its own, so
no block could map it. The QEMU machine's kernel could be mapped by a
block, but the same code serves both. The kernel must lie within the
2~MB which one table covers, which the linker scripts check
(#f("qemu/unix.ld")).

#lines-to("ldr r6, =bootl1")

The first-level table `bootl1` (#l("bootl1:")) serves the low addresses
and has a single entry: the gigabyte which contains the kernel's physical
address is mapped onto itself. When the MMU is turned on, the next
instructions are still fetched at physical addresses, and this mapping
keeps them in place, and `machine_init` removes it.

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
sets less one (`r7`). The count of leading zeros of `r3`, in `ip`, is
the shift which puts a way number into the top bits of a word.

#lines-to("1:\tmov r8, r3")

A line of the data cache is found by its set and its way: the cache is
divided into sets, and each set holds one line from each of its ways.
`DCISW` (`c7, c6, 2`, #l("mcr p15, 0, r9, c7, c6, 2")) discards the line named by its operand, which
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
`kl2`, and `r2` is still zero, the upper word.

#lines-to("isb")

In `SCTLR`, the MMU (bit 0), the data cache (2), and the instruction
cache (12) are turned on together. The load of the PC (#l("ldr pc, =1f"))
then jumps from the physical address, where the identity mapping kept
execution going, to the kernel address of the next line.

#lines-to("ldr sp, =stack_top")

A provisional stack, at the start of the kernel's `bss` (#l(".balign 8")--#l("stack_top:")),
serves until the u-area of process 0 can be mapped.

The vector base address register `VBAR` is loaded with the address of
`vectors` (#l("vectors:")), the table through which the processor takes
exceptions. The table must be aligned on 32~bytes (#l(".balign 32")).

#lines-to("mrc p15, 0, r0, c1, c0, 2")

The floating point unit, VFPv4 with the Advanced SIMD extension (NEON)
on both machines, is off at reset. It is reached as coprocessors 10 and
11, and the coprocessor access control register `CPACR` (#l("mrc p15, 0, r0, c1, c0, 2")--#l("mcr p15, 0, r0, c1, c0, 2")) opens
both to privileged and user mode. After the `isb` (#l("isb", after: "mcr p15, 0, r0, c1, c0, 2")), which makes this
and the new `VBAR` take effect, the enable bit of the floating point
exception register `FPEXC` (bit 30) is set (#l("mov r0, #(1 << 30)"), #l("vmsr fpexc, r0")). The unit is left
on for good. User programs execute its instructions directly. The kernel
is compiled without them (#f("sys.mk")), so the floating point registers always hold
the state of the current process, which `savfp` and `restfp`
(#f("mch.s")) move to and from its u-area.

#lines-to("bl machine_init")

Then `machine_init` (#f("machdep.c")) does the rest, in order:

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

Next `main` (#f("main.c")) is called (#l("bl main")). Process 0, the swapper, never
returns from it. It ends in `sched`. Process 1, which will become init,
does return here. It is made by `newproc` as a copy of process 0, kernel
stack included, so it continues from the same point in `main`, which copies
`icode` to user address 0 for it and returns.

#lines-to("mov r0, #0x10")

_Return to User Mode._ The register `spsr` is set to `0x10`, user mode
with both interrupt masks clear, `lr` to 0, and `movs pc, lr` copies
`spsr` into `cpsr` while it jumps: the standard ARM return from an
exception. No user stack pointer is set: `icode` needs none,
and the `exec` it performs gives `/etc/init` its own.

#lines-to(".balign 32", lead: true)

_Exception Vectors._ Each entry is an instruction, not an address, and
is executed in the mode which the exception selects. Here each is a
branch.

#lines-to("svc_entry:", lead: true)

_System Call Entry._ The processor arrives in SVC mode with
interrupts masked, `lr` holding the address after the `svc` and `spsr`
the user's `cpsr`. The task is to lay down on the kernel stack a frame
of all the user's registers, in the order which #f("reg.h") describes,
and to hand its address to C.

First `srsdb sp!, #0x13` (#l("srsdb sp!, #0x13", after: "svc_entry:")), "store return state", pushes `lr` and `spsr`
onto the stack of the mode named (SVC), and updates that stack pointer.
Room is then made for fifteen words, and `stmia sp, {r0-r14}^`
stores `r0` to `r14`. Without the `^`, a store-multiple instruction
such as `stmia sp, {r0-r12}` stores the registers of the current mode,
so in SVC mode it would store `sp_svc` and `lr_svc` for `r13` and
`r14`. With the `^`, and `pc` not in the list, it stores the *user*
mode's banked `sp` and `lr` instead, without a change of mode. The
architecture forbids writeback with this form, hence the separate `sub`.

#lines-to("mov r0, sp")

The frame is thus seventeen words, `r0`--`r12` at 0 to 48, the user `sp`
at 52, the user `lr` at 56, the return PC at 60, and the saved status at
64. This is why `SP`, `PC`, and `PSR` in #f("reg.h") are 13, 15, and 16:
`u.u_ar0[SP]` is the user stack pointer, `u.u_ar0[PC]` the PC.

Then `trap` (#f("trap.c")) is called (#l("bl trap")) with one argument, the address
of the frame of saved registers just built, which `mov r0, sp` (#l("mov r0, sp", after: "svc_entry:"))
puts in `r0`, the register for a function's first argument. It
keeps the address in `u.u_ar0`, through which the system calls reach the user's
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
frame goes at the top of the u-area. If it came from the kernel, the
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

The routine `irq` (#f("machdep.c")) asks the GIC for the interrupt number,
and calls `clock` or the device handler.

#lines-to("mov lr, r5")

If the interrupted program was in user mode (the mode field of
the saved status, at offset 64, is `0x10`) and `runrun` is set, meaning
a process with a better priority is ready to run (#f("slp.c"),
#f("clock.c")), the current process must give up the processor before
it returns. The code then jumps to the call of `user_trap_handler`
which the traps below use (#l("1:", after: "mrc p15, 0, r2, c6, c0, 0")), with signal 0 and address 0
(#l("mov r0, #0", after: "ldr r0, =runrun"), #l("mov r2, #0", after: "ldr r0, =runrun")). Signal 0 posts nothing, so the handler does only what it does at the end of every trap. It takes any pending signal (`issig`, `psig`),
recomputes the priority (`setpri`), and gives up the processor
(`qswtch`). Otherwise the frame is unloaded at once (#l("2:", after: "bl user_trap_handler")). Without this
test a process which never made a system call would never be
preempted, nor see a signal.

#lines-to("badtrap:", lead: true)

The two vectors which should never be used lead to `badtrap`. It
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
instruction was 16~bits long, and `user_trap_handler` (#f("trap.c"))
adds the other two for a 32-bit one.
An undefined instruction yields signal 4 (`SIGINS`), either abort
signal 11 (`SIGSEG`).

The save is repeated, rather than shared by all three, because no register is free to carry the signal number to a common
save. The registers `r0` to `r12` are the user's until they have been stored, and the banked `sp`
and `lr` of the abort and undefined modes are left behind by the change
to SVC mode.

The frame is built exactly as for an interrupt (#l("srsdb sp!, #0x13", after: "undef_entry:")--#l("stmia sp, {r0-r14}^", after: "undef_entry:"), #l("srsdb sp!, #0x13", after: "pabort_entry:")--#l("stmia sp, {r0-r14}^", after: "pabort_entry:"),
#l("srsdb sp!, #0x13", after: "sub lr, lr, #8")--#l("stmia sp, {r0-r14}^", after: "sub lr, lr, #8")). Only then is the signal number loaded, into `r0` (#l("mov r0, #SIGINS"),
#l("mov r0, #SIGSEG", after: "pabort_entry:"), #l("mov r0, #SIGSEG", after: "sub lr, lr, #8")), and `user_trap_handler` receives the signal, the frame, and in
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
there at once, by the common return (#l("rfeia sp!")), without calling C. The
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

The routine `user_trap_handler` runs with interrupts enabled (#l("cpsie i", after: "mov r1, sp")). The work it may do, the copying of a grown stack or the
writing of a core image, would otherwise hold off the clock and the
console for its whole length. Unlike v7, the call made for `runrun` also runs with
interrupts enabled: the interrupt has been acknowledged (#f("machdep.c")), and a further one
nests on the SVC stack as it would over any other kernel code.
Interrupts are masked again before the frame is unloaded (#l("cpsid i", after: "bl user_trap_handler")), since
the saved state must not be disturbed between the `ldmia` and the
`rfeia`.

#lines-to("2:")

_Common Return._ The instruction `ldmia ... ^` (#l("ldmia sp, {r0-r14}^")), without the PC in the list, loads the User mode
registers, as the `stmia` stored them. Then `rfeia sp!` (#l("rfeia sp!")),
"return from exception", pops the PC and the saved status together into
`pc` and `cpsr`, so the mode, the interrupt mask, and the condition flags
of the interrupted program are restored with its PC in one step.

#lines-to(".bss", lead: true)

_Boot Stack and Tables._ The boot stack, one page, is used only until
`_start` moves the stack pointer to the u-area (#l("mov sp, r0")). The deepest chain
of calls from `machine_init`, through a `panic` and its `printf`, needs
under 700~bytes, and a fault taken during boot under 1.4~KB.
Interrupts stay masked until long after the switch, so none lands on
this stack. The kernel's
second-level table `kl2` stays in use after boot. It must be aligned on
4~KB, and so must the third-level table `kl3k` which follows it. On the
QEMU machine `machine_init` replaces the entry which points to `kl3k`
with a block of RAM, and the table falls out of use. On the MP135
machine it maps the kernel for good. The first-level table `bootl1` holds the boot identity
mapping. It needs 32-byte alignment and follows `kl3k`.

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

_Memory Barrier._ The routine `dmbsy` is a data memory barrier: every memory access before it is
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
(bit 7 of `cpsr`). It is cleared by `intr_enable` (#l("intr_enable:")) and set by `intr_disable`
(#l("intr_disable:")). Every interrupt handler runs with interrupts masked.

The routine `intr_disable` returns the previous `cpsr` in `r0` (#l("mrs r0, cpsr")), so that
`s = intr_disable(); ... intr_restore(s);` puts back the caller's
state. In the value it is given, `intr_restore` (#l("intr_restore:")) looks only at
the `I` bit.

#lines-to("cntfrq_get:", lead: true)

_Generic Timer._ With these routines `clkstart` (#f("machdep.c")) and
`clock` (#f("clock.c")) produce an interrupt every `1/HZ`
second, a sixtieth (`HZ`, #f("param.h")), and the console's `putchar`
(#f("pl011.c"), #f("usart.c")) times its wait with `cntvct_get`.
The first, `cntfrq_get`, reads `CNTFRQ`, the counter frequency.

#lines-to("cntvct_get:", lead: true)

The routine `cntvct_get` reads `CNTVCT`, the 64-bit time counter that increases at
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

The timer's compare register is loaded by `cntv_cval_set` from the
`unsigned long long` argument, passed in the same two registers. The
timer interrupts once the count reaches it. The `isb` makes the new
setting take effect before the routine returns.

#lines-to("cntv_ctl_set:", lead: true)

The timer's control register is written by `cntv_ctl_set`: 1 enables it, with
the interrupt unmasked. Again the `isb` makes the setting take effect
before the routine returns.

#lines-to("save:", lead: true)

_Process Switching._<mch-switch> The routines `save` and `resume` are the means by
which the kernel passes the processor from one process to another. The
first records where the current process is, and the second makes
another process current and continues it from the point its own `save` recorded. Which
process runs next is decided elsewhere, by `swtch` (#f("slp.c")). These
two routines only carry the decision out. A process also uses them to
jump back to an earlier point of its own, to abandon an interrupted
system call or to continue after `expand` has moved it.

The call `save(lab)` records in `lab` (a `label_t`, #f("param.h")) the registers
which a function must preserve, `r4` to `r11` and `sp`, together with
the return address in `lr`, ten words in all, and returns 0.

#lines-to("resume:", lead: true)

The call `resume(p_addr, lab)` maps the u-area of process `p_addr` at `UBASE` in
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
to, so it may for a while still find the old entry. The barrier `dsb` (#l("dsb ish", after: "1:	str r3, [r2], #8")) waits
until the buffer has drained. Similarly, the TLB, the MMU's own cache of translations, may still hold
the old translation of `UBASE`, and `TLBIMVAA` discards it, page by page (#l("ldr r3, =u")--#l("bne 1b", after: "1:\tmcr p15, 0, r3, c8, c7, 3")). The
second `dsb` and the `isb` (#l("dsb ish", after: "1:	mcr p15, 0, r3, c8, c7, 3"), #l("isb", after: "1:\tmcr p15, 0, r3, c8, c7, 3")) wait until the discard has taken
effect.

The user part of the address space, below 0xc0000000 (`USRSIZE`,
#f("param.h")), still maps the old process. It is switched by `sureg` (#f("ureg.c"))
after the switch is complete.

#lines-to("ldmia r1, {r4-r11}")

Usually `swtch` (#f("slp.c")) calls `resume(p->p_addr, u.u_rsav)`. The second
argument is the address of `u.u_rsav`, which lies at a fixed place in
the page at `UBASE`. Before the switch, that place holds the old
process's saved registers. After the switch, the same place holds the
new process's, since the new process's u-area now appears at `UBASE`.
Only after the switch does `resume` read `lab` (#l("ldmia r1, {r4-r11}")--#l("ldr r2, [r1, #36]")), so it gets the new
process's registers, the ones it saved there with `save(u.u_rsav)` when
it last gave up the processor.

From the stores (#l("1:	str r3, [r2], #8")) until `sp` is reloaded (#l("ldr sp, [r1, #32]")), `sp` still holds
the old process's stack address, but `UBASE` now shows the new
process's u-area. Anything pushed there would overwrite the new
process's kernel stack. So the routine uses no stack, and interrupts,
which would push a frame, stay masked. Once the new stack is in place,
`intr_enable` (#l("bl intr_enable")) unmasks them. This is a call, which
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

The routine `arm_sync_icache` makes instructions just written to memory
visible to instruction fetch. The kernel must call it whenever it writes instructions that will be executed, such as a text read in from a file or back
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

All three routines call `dline`. The line size differs between
processors, so it reads it from the cache type register `CTR`. It
rounds the start down to a line boundary, and returns the end of the
range in `r1`. The callers keep their return address in `r12` across
the call, which overwrites `lr`.

#lines-to("tlbflush:")

_Translation Tables._ The routine `tlbflush` invalidates the whole TLB (`TLBIALL`) and the branch
predictor. It is called by `machine_init` (#f("machdep.c")) after a
change to the kernel's own mapping.

#lines-to("ttbset:")

The call `ttbset(a)` makes the first-level table at physical address `a` the
user's. `TTBR0` is 64~bits wide in the long format, and is loaded from
two registers (#l("mcrr p15, 0, r0, r1, c2")). The upper one, zero, holds the address space
identifier, so every process runs with identifier 0. Each TLB entry is
either global, belonging to every address space, or tagged with the
identifier of one. The kernel's pages are global and the user's are
not, so discarding the entries of identifier 0 (`TLBIASID`, #l("mcr p15, 0, r1, c8, c7, 2"))
removes the old process's translations and keeps the kernel's. The
branch predictor, which remembers branch targets in the old mapping, is
discarded too. The caches are left alone, since they do not depend on
the mapping. The first `dsb` makes sure that `sureg`'s stores to the
new tables have left the store buffer, and the tables need no cleaning,
since the MMU reads them through the data cache. The routine `sureg`
(#f("ureg.c")) calls `ttbset` at every process switch, and whenever it has rebuilt the
current process's tables.

#lines-to("fubyte:")

_User Memory._ These routines move data between the kernel and the
current user process. The ARM's `ldrt` and `strt`, and their byte forms,
load and store with the permissions of user mode even when the kernel
executes them. A user address which is not mapped, or which only the
kernel may touch, therefore faults.

The routines `fubyte` and `fuword` return the byte or word at a user address, or -1, and
`subyte` and `suword` store one, and return 0 or -1. The byte is loaded
without sign extension, whatever the signedness of `char`. The loaded
value goes first into `r1` (#l("ldrbt r1, [r0]"), #l("ldrt r1, [r0]")): a load which wrote back to its
own base register would be unpredictable, and `ldrt` and `strt` always
write back. The v7 code distinguished `fuibyte` from `fubyte`, instruction space
from data space, and #f("systm.h") makes the former names aliases of these.

#lines-to("copyin:")

The routines `copyin(from, to, n)` and `copyout` move `n` bytes from a
user address to a kernel one, and back, and return 0, or -1 if any user
reference faults. They move words when both addresses and the count
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
than at the faulting instruction. That code clears `nofault` and returns
-1. A routine which completes clears it at `uok` (#l("uok:")) and returns its
value. The routines `fkbyte`, `skbyte`, `fkword`, and `skword`
(#l("fkbyte:")--#l("b uok", after: "skword:")) use the same guard for kernel addresses, which the
memory special files may name in a block with nothing behind it
(`mapaddr`, #f("machdep.c")). Only these routines set `nofault`, so any other fault in the
kernel is still a `panic`. The code at `uerr` finds the address of `nofault` still
in `r3`, since the abort restores the registers as they were at the
fault.

#lines-to("idle:")

_Idle._ The routine `idle` waits for an interrupt. It is called by `swtch` with
interrupts masked, and `wfi` ("wait for interrupt") halts the processor until an interrupt
is pending, even a masked one. Then `cpsie i` lets it be taken at once,
so the PC it saves is always that of `waitpc` (#l("waitpc:	cpsid i")). The variable
`waitloc` (#l("waitloc:"), #l(".word waitpc")) holds that address, and `clock` (#f("clock.c")) compares it with
the interrupted PC to count the time spent idle.

#lines-to("savfp:")

_Floating Point._ The routines `savfp` and `restfp` store and load the floating
point state of the current process. On the ARM the state is the status
and control register `FPSCR`, which holds the rounding mode and the
cumulative exception flags, and the 32 double registers `d0` to `d31`,
which the processor's vector instructions (Advanced SIMD) also use.
The instructions `vmrs` and `vmsr` move `FPSCR`, and `vstmia` and `vldmia` move sixteen
registers each, the most one instruction allows. The layout is that of `u_fps` (#f("user.h")), with `FPSCR` in the first word, and the registers
from byte 8, where the alignment of a `double` puts them. Both machines
have the unit (#f("low.s")), and `FPEXC` needs no saving, since the
unit stays enabled. The Cortex-A7's unit takes no trap on an arithmetic
exception, so `SIGFPT` is never sent, and a program finds what happened
in the cumulative flags of `FPSCR`.

#lines-to("dfar:")

_Fault Registers._ The routines `dfar` and `dfsr` return the data fault address and status registers,
which describe the last data abort. They are printed by `user_trap_handler`
(#f("trap.c")) before it panics on a fault in kernel mode.

#lines-to("/*", after: "dfsr:")

_Leaving the Secure World._ The boot ROM of the MP135 machine starts the
kernel in the secure world, and `etzpcinit` (#f("etzpc.c")) calls
`nsenter` (#l("nsenter:")) to leave it once the memory and the devices have been
made non-secure. The processor keeps two copies of most of its system
registers, one for each world, and the non-secure world starts with
its MMU off, its caches off, and no vectors. Rather than set the
machine up a second time, `nsenter` enters the monitor, the mode
between the two worlds, which copies the secure world's settings into
the non-secure copies.

First the data caches are cleaned and invalidated by set and way, at
level 1 and at level 2 (#l("3:\tmcr p15, 2, r11, c0, c0, 0")--#l("blo 3b")), as #f("low.s") invalidated level 1 at boot,
with `DCCISW` (#l("mcr p15, 0, r9, c7, c14, 2")) in place of `DCISW`. A cache line remembers the world
which filled it, and the non-secure world does not hit a secure line,
so anything modified must be in memory before the switch. `NSACR`
(#l("mrc p15, 0, r0, c1, c1, 2")--#l("mcr p15, 0, r0, c1, c1, 2")) lets the non-secure world use coprocessors 10 and 11, the
floating-point unit. `MVBAR` (#l("mcr p15, 0, r0, c12, c0, 1")) gives the monitor its vectors, and `smc`
(#l("smc #0")) enters it. Back in the non-secure world, `nsenter` discards the
TLB, the instruction cache, and the branch predictor, which hold nothing
of that world yet, and returns.

#lines-to(".balign 32", after: "pop {r4-r11, pc}")

The monitor's vectors (#l("monvec:")) are all loops but that of `smc`. The
monitor needs no stack.

#lines-to("monsmc:")

The handler `monsmc` reads the secure copies of `SCTLR`, `TTBCR`, `TTBR0`,
`TTBR1`, `MAIR0`, and `VBAR`, sets the bit `NS` of the secure configuration
register `SCR` (#l("orr r8, r8, #1")), after which the monitor's accesses reach the
non-secure copies, and writes them there, `SCTLR` last, which turns the
non-secure MMU and caches on with the same tables (#l("mcr p15, 0, r1, c2, c0, 2", after: "orr r8, r8, #1")--#l("mcr p15, 0, r0, c1, c0, 0", after: "orr r8, r8, #1")). The monitor itself still
runs on the secure tables. The return (#l("movs pc, lr")) restores the caller's `cpsr`
from the monitor's `spsr`, SVC mode with interrupts masked, and with
`NS` set the processor is then non-secure.

#lines-to(".data")

The variable `waitloc` holds the address of `waitpc`, and `nofault` is
zero except while a user reference is made.

#lines-to(".balign 4096", after: "nofault:")

The u-area is switched by `resume` through the page table `kl3u`.
The kernel's own table maps RAM in whole 2~MB blocks, but a u-area is
one page, anywhere in RAM. So the 2~MB block at `UBASE` gets a
third-level table, which maps page by page. Of its 512~entries only the
first `USIZE` are used. The rest stay invalid, so that a stray
reference beyond the u-area faults. The table is hooked by `machine_init`
into the last entry of `kl2` (#f("low.s")). Like every table of the long
format, it is aligned on 4~KB. Like the rest of the `bss`, it is
cleared by `_start` (#f("low.s")).

#lines-to("kl3d:")

The device registers are mapped the same way, a page each, through
`kl3d`, which `kmap` (#f("machdep.c")) fills and hooks into the entry
of `kl2` for `DEVBASE` (#f("seg.h")). A device's registers seldom begin
on a 2~MB boundary, and by pages each device can lie at the same kernel
address on both machines, whatever its physical address.

#lines-to(none)
#source("/usr/sys/h/reg.h")

When a process enters the kernel, by a system call, an interrupt, or an
exception, its registers are saved on its kernel stack, which lies in
its u-area (#f("user.h")), and `u.u_ar0` is
set to point at the saved `r0`. The header #f("reg.h") gives the position of every
other saved register as an index from that point, so that the kernel
may write `u.u_ar0[SP]` for the user's stack pointer without knowing how
the frame was built.

The frame is built by #f("low.s") in the order of the registers:
`r0` to `r12` at indices 0 to 12 (#l("#define\tR0\t(0)")--#l("#define\tR12\t(12)")), the user's `sp` and `lr` at 13 and
14 (#l("#define\tSP\t(13)"), #l("#define\tLR\t(14)")), the return address at 15 (#l("#define\tPC\t(15)")), and the saved status
register `spsr` at 16 (#l("#define\tPSR\t(16)")). Every register has a name, so that code such as
`trap` (#f("trap.c")) writes `r[R7]` for the register which holds the
system call number, not a bare index.

#lines-to(none)

#source("/usr/sys/sys/trap.c")

What remains of v7's trap handling is in #f("trap.c"). It holds `regloc`, a much
reduced `trap` which handles only system calls, `user_trap_handler`,
which handles every other exception, and the two dummy calls `nosys`
and `nullsys`. The headers #f("dir.h") and #f("user.h") are included for `u`, and
#f("reg.h") for the register indices. `EBIT` (7), the carry bit of the
saved status register, has the bit's position in the ARM's `CPSR`.

#lines-to("/*")

The table `regloc` maps the PDP-11 register numbers 0 to 7, and the status word,
onto indices in the saved frame (#f("reg.h")). The system call `ptrace` uses it. It
comes from v7's `trap.c`.

#lines-to("void")

The `svc` entry in #f("low.s") calls `trap` with a pointer to
the frame of saved registers, with interrupts enabled. It is v7's
system call case, taken out of the switch over trap types, with the
differences which follow.

#lines-to("r[PSR] &= ~EBIT;")

The carry bit is cleared (#l("r[PSR] &= ~EBIT;")), as v7 cleared it on entry. It is set
again below if the call fails.

The call number (#l("callp = &sysent[r[R7] & 077];")) is not fetched from the low six bits of the
`sys` instruction in user memory, but taken from the register `r7`,
where the library stub has put it (`R7` is the ARM `r7`, and the PDP-11's `R7`, its `pc`, is `PC`
here). This is the convention of ARM Linux. A number
greater than 63 is reduced modulo 64.

The `sy_narg` arguments are copied from `r0` upwards (#l("for(i = 0; i < callp->sy_narg; i++)"), #l("u.u_arg[i] = r[i];")). In v7 the kernel
found its register arguments through `regloc`, and then advanced the
saved `pc` past any inline arguments. There are none here, so the saved
`pc` already addresses the instruction after the `svc`. No entry of the
table asks for more than 4 arguments, within the 5 words of `u_arg`
(#f("user.h")).

Number 0, `indir`, executed the `sys` instruction at an address given
inline, with that instruction's inline arguments. There being no inline
arguments, it is reduced to `nullsys`, and `trap` no longer has the special
case for it.

The second return value is preset to the user's `r1` (#l("u.u_r.r_val2 = r[R1];")).
The first is preset to zero (#l("u.u_r.r_val1 = 0;")), where v7 preset it to the user's
`r0`. The library stubs of v7 cleared `r0` themselves after a call which
returns no value, such as `close` or `chdir`. Here every stub returns
`r0` as the kernel leaves it (#f("libc/syscall.s")), and the preset makes
such a call return zero rather than its first argument.

#lines-to("if (save(u.u_qsav)) {")

The `save` of `u.u_qsav` provides the point to
which `sleep` (#f("slp.c")) returns when a signal interrupts a system
call, and in that event the call fails with `EINTR`.

An error (#l("if (u.u_error) {")--#l("}", after: "r[R1] = u.u_r.r_val2;")) sets the carry bit in the
saved status register, and the error number is returned in `r0`. The
library's `cerror` (#f("libc/syscall.s")) tests the carry, stores `r0` in
`errno`, and returns -1. Since the error is not encoded in `r0`, a
successful call may return any value, a `time` after January 2038
among them.

#lines-to("if (issig())")

The common tail of v7's `trap` follows (#l("if (issig())", after: "r[R1] = u.u_r.r_val2;")--#l("qswtch();", after: "r[R1] = u.u_r.r_val2;")): any pending signal is acted
upon, the process's priority is recomputed, and if a more deserving
process is waiting the processor is given up.

If the process is being profiled (#l("syst = u.u_stime;"), #l("if(u.u_prof.pr_scale)"), #l("addupc((caddr_t)r[PC], &u.u_prof,")), the system time spent
in the call, the ticks which `clock` added to `u_stime` meanwhile, is
charged to the user's `pc`, which is the instruction after the `svc`, and
`clock` (#f("clock.c")) charges only ticks in user mode, so without this
a program which spends its time in system calls would show nothing.
The `pc`, which v7 received as a parameter, is taken from the frame.

Finally the floating point registers are loaded from the
u-area if anything since the entry (#l("u.u_fpsaved = 0;", after: "syst = u.u_stime;")) stored them there (#l("if (u.u_fpsaved)", after: "(int)(u.u_stime-syst));"), #l("restfp(&u.u_fps);", after: "(int)(u.u_stime-syst));")): a
switch to another process, a signal, `fork`, or `exec`, which sets
`u_fpsaved` itself after clearing the saved registers (#f("sys1.c")). If
nothing did, the registers still hold the process's own values, and
nothing need be done.

#lines-to("void")

The routine `user_trap_handler` handles the rest of v7's `trap`: the exceptions
other than `svc`, and the preemption check after an interrupt. It is
called from #f("low.s") with a signal number, the saved frame, and, for
a data abort, the address which could not be reached.

If the exception was not taken in user mode (`0x10`, #l("{", after: "user_trap_handler(int signo, int *r, unsigned a)")--#l("signo, r[PC], r[PSR], dfar(), dfsr());")), the
kernel itself has faulted, and the system panics, after printing the
faulting address and its cause from the coprocessor registers `DFAR`
and `DFSR`. In v7 the PDP-11 equivalents were printed. A fault in one of the
routines which reach user memory never arrives here: #f("low.s") sends
it back to the routine through `nofault` (#f("mch.s")).

#lines-to("u.u_fpsaved = 0;")

An undefined instruction in Thumb code (the `T` bit, `0x20`, of the
saved status) leaves the saved PC two bytes past the start of the
instruction (#f("low.s")). The top five bits of the instruction's first
halfword, read with `fubyte` from its upper byte, tell whether it is 32
bits long (`0xe8` and above). If so, the PC is moved past the second
halfword (#l("if(signo == SIGINS && r[PSR]&0x20 &&"), #l("r[PC] += 2;")), so that a handler which returns resumes at the next
instruction, not in the middle of this one. Such code comes only from
the C compiler's support library (#f("machdep.c") has more on Thumb
state).

The signal is then posted to the current process and
the same tail as in `trap` is run, the loading of the floating point
registers included (#l("if (u.u_fpsaved)", after: "psignal(u.u_procp, signo);"), #l("restfp(&u.u_fps);", after: "psignal(u.u_procp, signo);")). A signal number of zero is passed by
the interrupt entry, when `runrun` is set. Nothing is posted then
(#l("if(signo && (signo != SIGSEG || a+256 < (unsigned)r[SP] ||")), and the call serves only to reach the tail, as v7's type 12 trap
did.

The exception is the one which v7's `trap` also made for a segmentation
fault: if the stack can grow to cover the fault, it is grown and no
signal is sent (#l("if(signo && (signo != SIGSEG || a+256 < (unsigned)r[SP] ||")--#l("psignal(u.u_procp, signo);")), and the process resumes at the faulting
instruction, which this time succeeds. In v7 the stack was grown to cover the
stack pointer, which on the PDP-11 had already been decremented when a
push faulted. On the ARM a store multiple which pushes registers leaves
`sp` unchanged when it faults, so the address of the fault is used
instead. Only a fault close below the stack pointer, or above it, is
taken for a stack reference: 256 bytes, twice the most that one
instruction can store below `sp`, the 16 double registers of a `vpush`. A fault
further down, in the gap between the data and the stack, is a wild
reference, or the shell asking for more memory (#f("sh/fault.c")), and
gets its signal. A prefetch abort passes zero for the address, which
never qualifies.

Most of v7's cases have no counterpart. An undefined instruction gives
`SIGINS` and both kinds of abort `SIGSEG` (#f("low.s")). A breakpoint
instruction also arrives as a prefetch abort, and gives `SIGSEG`, not
`SIGTRC`. There are no `iot` and `emt` instructions, no floating point
exceptions, and no parity registers.

#lines-to("/*", lead: true)

A call of `nosys` fails with `EINVAL`, and `nullsys` does nothing.

#lines-to(none)

#source("/usr/sys/sys/sysent.c")

The file #f("sysent.c") holds the table of system calls, and nothing else.
In v7 every system call routine was declared here as an `int` function, and
#f("systm.h") now declares them all with prototypes, as `void`
functions of no arguments, `nosys` and `nullsys` among them.

#lines-to("/*")

The table is indexed by system call number. Each entry gives the number
of arguments, the number of them passed in registers, and the routine.
The entries are now in braces, as C99 asks of an array of structures.
Entry 52, `phys`, mapped physical memory into a process on the PDP-11
and is now `nosys`.

On the PDP-11 a system call was the instruction `sys n`, and its
arguments were passed partly in registers and partly as words following
the instruction in the program text: `sy_nrarg`, the second column, was
the number which came in `r0` and `r1`, and the rest were fetched from
the instruction stream. On the ARM all arguments come in registers, so
the two columns are now equal and the counts have been corrected for
the 32-bit word:

- Call 19, `seek` (#l("{3, 3, seek},\t\t\t/* 19 = seek; now 3 args */")), took four words, since its offset was a two-word `long`;
  now it takes three. The call `stime` (#l("{2, 2, stime},\t\t\t/* 25 = stime */")) keeps v7's two: the `time_t` it
  receives is now 64 bits, two ARM words, as the PDP-11's `long` was
  two of its own.
- No arguments are given to `tell` (#l("{0, 0, nosys},\t\t\t/* 40 = tell (obsolete) */")), which is `nosys` in any case.

Two slots have changed their routine. Slot 56, the multiplexor
`mpxchan`, was in v7 either the real multiplexed file system or the
stub in `fakemx.c`, which failed with `EINVAL`. Neither is part of the
port, and `nosys` gives the same result. Slot 63, which v7 reserved
"for internal use", is now `sigreturn`, by which a signal handler
returns (`sendsig`, #f("machdep.c")).

#lines-to(none)
#source("/usr/sys/sys/main.c")

#f("main.c") holds `main`, which the kernel runs once, as it brings
itself up, and the two routines it calls to initialise the file system
and the buffer cache, `iinit` and `binit`.

#lines-to("void", after: "*/")

_Memory._ The call of `startup` (#l("startup();")) divides the RAM which follows the u-area of
process 0. First come the processes' first-level page tables, then a
pool of pages for their other tables (`ptmap`). Everything above, up to
the top of RAM given by the configuration (`coretop`), goes onto the
stack of free pages (#f("malloc.c")), from which processes take their memory.

#lines-to("/*")

_Process 0._ The field `p_addr` of process 0 (#l("proc[0].p_addr = btop(corebase);")) is the page at which its u-area
begins: the first page of RAM, `corebase`, which `machine_init` has
mapped at `UBASE`. The remaining fields
(#l("proc[0].p_size = USIZE;")--#l("u.u_cmask = CMASK;")) say that the process occupies only its
`USIZE` pages, is runnable, is in RAM, and is a system process, which is
never swapped. The field `u_procp` links `u` and `proc[0]`.

#lines-to("/*", after: "u.u_cmask = CMASK;")

_Interrupts._ The timer is programmed to interrupt `HZ` times a second by `clkstart`
(#l("clkstart();")). Then `bdinit` (#l("bdinit();")), which the
configuration (#f("c.c")) defines to call the disk driver's
`rkinit`, starts the disk. It comes before `intrstart`, because the QEMU
machine's `virtio` driver learns its interrupt number only when it
probes the device (#f("virtio_blk.c")). The configured interrupts are
then enabled and unmasked by `intrstart` (#l("intrstart();"),
#f("machdep.c")). From here on interrupts are taken.
This matters to `iinit`, which reads the root's super-block from the
disk and sleeps until the disk's interrupt reports the block. The routine `cinit`
(#at("/usr/sys/sys/prim.c", "cinit(void)")) links the character blocks
of the terminal queues into their free list.

The root directory (`rootdir`) and the current directory of process 0 are obtained as
separate references to the root inode. Each `iget` returns it locked,
and the lock is released at once (#l("rootdir->i_flag &= ~ILOCK;"), #l("u.u_cdir->i_flag &= ~ILOCK;")).

#lines-to("/*", after: "u.u_rdir = NULL;")

_Process 1._ The call of `newproc` (#l("if(newproc()) {")) makes process 1 as a copy of process 0 and returns zero
to the parent, which falls through to `sched` (#l("sched();")) and never comes back.
Process 1 eventually resumes in `newproc` with a value of one, and
takes the branch.

#lines-to("expand(USIZE + (int)btop(szicode));")

The image is first enlarged to hold `icode`: `btop(szicode)` is 1,
so the image becomes the u-area and one page.
Then `estabur` (#f("ureg.c")) checks the size and calls `sureg`, which
maps the page into the user window at virtual address 0, and
`copyout` writes `icode` (#f("machdep.c")) through that mapping, to
user address 0.

A call of `arm_sync_icache` (#l("arm_sync_icache(PGADDR(imgpage(u.u_procp, USIZE)),")) makes the
instructions just written visible to instruction fetch (#f("mch.s")). It
is given the kernel address (`PGADDR`) of the image's page after the
u-area (`imgpage`, #f("slp.c")), not user address 0. The
two name the same physical page, and the routine works through the
kernel's mapping of RAM.

#lines-to("/*")

Then `main` returns to `_start` (#at("/usr/sys/conf/low.s", "_start:")), which enters user
mode at address 0, where `main` has copied `icode`. Process 1 begins to
execute it.

#lines-to("/*", lead: true, after: "}")

_Root File System._ The root device is opened by `iinit`, which reads its super-block (block
1, `SUPERB`). It copies the super-block into a buffer of its own (`geteblk`,
#at("/usr/sys/dev/bio.c", "geteblk(void)")), and records that buffer and the root device as the first
entry of the mount table (#at("/usr/sys/h/mount.h", "extern struct\tmount")), the table which pairs each mounted
device with the buffer holding its super-block. The kernel keeps the
super-block of every mounted file system in memory for as long as it
stays mounted. Free blocks and inodes are taken from its lists by `alloc`
(#at("/usr/sys/sys/alloc.c", "alloc(dev_t dev)")), and it is written back by `update` (#at("/usr/sys/sys/alloc.c", "update(void)")). The root is never
unmounted, so its buffer is never released. The super-block's time of
last modification becomes the initial time of day, until `date` or
`stime` corrects it.

#lines-to("/*", lead: true, after: "}")

_Buffer Cache._ The buffers of the buffer cache (see _Disk I/O_,
page #pageref(<sec-disk>)) each hold one disk
block. Each buffer has a header, a `struct buf` (#f("buf.h")), which
records the device and the block it holds, and `binit` (#l("binit(void)")) pairs
each header with its buffer. The buffers themselves are rows which
`startup` took from core (#f("machdep.c")), to which `buffers`
(#f("buf.h")) points, and `NBUF`
(#at("/usr/sys/h/param.h", "#define\tNBUF")) gives their number. Each
buffer occupies whole cache lines of its own, as the SD card driver
requires (#f("sd.c")). So a row is rounded up to whole
64-byte lines, sixteen `int`s each. The routine `binit` links every
buffer into the free list through `brelse`, and gives each header its
row (#l("bp->b_un.b_addr = (caddr_t)buffers[i];")).

#lines-to("for (bdp = bdevsw; bdp->d_open; bdp++) {")

Each block device's queue (`d_tab`) is then made an empty circular
list, and the block devices are counted in `nblkdev`. The scan of
`bdevsw` ends at the first entry without an open routine, the null
entry with which #f("c.c") closes the table.

#lines-to(none)
#source("/usr/sys/sys/machdep.c")

#f("machdep.c") holds the machine-dependent code which can be written
in C. Its first half starts the system, sets up the interrupts and
handles them, and delivers signals. Its second half builds the
kernel's page tables, copies and clears pages, returns from a signal,
and serves `/dev/mem` and `/dev/kmem`. The address space which this
code builds is described in the Introduction (see _The Address Space_,
page #pageref(<sec-addr>), and _Translation Tables_, page
#pageref(<sec-tables>)).

#lines-to("/*")

_Bootstrap Program._ The first user program is `icode`, which `main` (#f("main.c")) copies
to user address 0 of process 1. It is ten words of ARM code, assembled
by hand into hexadecimal.

#lines-to("0xe3a0001c,\t/* mov r0, #init */")

The first four words perform `exec("/etc/init", initp)`. The two
arguments, the name of the file and its argument vector, go in `r0`
and `r1`, and the system call number, 11, goes in `r7`. Then `svc`
enters the kernel, where system call 11 is `exec` (#f("sys1.c")).
Should the `exec` fail, the program loops on the branch to itself (#l("0xeafffffe,\t/* b . */")),
and the system goes no further.

#lines-to("0x0000001c,\t/* initp: init; 0 */")

The argument vector `{init, 0}` (`initp`) follows at offset `0x14`,
and then the string `/etc/init`, stored little-endian, at `0x1c`. Because the program is loaded at address 0, its own
offsets serve as addresses, and both fit the 8-bit immediate field of
`mov`.

#lines-to("/*", lead: true)

_Memory._ The routine `machine_init` (#l("machine_init(void)")) has set `corebase`
to the physical address of the first page after the kernel and its
tables, and the configuration (#f("c.c")) gives `coretop`. Both
are physical addresses, because the kernel counts RAM in physical
pages.
The macro `btop` divides each address by the page size to give the
page number.

#lines-to("i = btop(corebase) + USIZE;")

RAM begins with the `USIZE` pages of the u-area of process 0 (see
`main`). Three reservations follow it. The first-level user tables,
32~bytes for each slot of the process table, take the next pages
(#l("l1tab = (unsigned long long *)PGADDR(i);")--#l("i += btop(32*NPROC);")).
Their kernel address, through which `sureg` writes them, is `l1tab`,
and `l1pa` is the physical one, which `TTBR0` needs (#l("l1pa = ptob(")).
They are cleared, so that every process starts with an empty address
space. The next `NPTAB` pages (#l("mfree(ptmap, NPTAB, i);"),
#l("i += NPTAB;")) are the pool from which `ptbuild` (#f("ureg.c")) takes
the lower tables, freed into `ptmap`.

#lines-to("sigpage = i++;")

One page then holds the signal trampoline (#l("sigpage = i++;")--#l("arm_sync_icache((caddr_t)t, 8);")). It is
cleared, so that nothing of the kernel shows through it, and given two
instructions, `mov r7, #63` and `svc #0`, which make the system call
`sigreturn`. The copy is then made visible to instruction fetch.
Every process maps this one page read-only at `SIGTRAMP` (#f("seg.h")).

The buffers of the buffer cache are taken from core next
(#l("buffers = (int (*)[(BSIZE+BSLOP+63)/64*16])PGADDR(i);")--#l("i += btop(NBUF*sizeof(*buffers));")), rather than being a table of the kernel, since
the SD card's DMA cannot reach all the on-chip RAM in which the MP135
machine's kernel lies, and reaches DDR. The rows begin on a page, and
so each on a cache line, which the SD card driver needs (#f("sd.c")).
One more page, `physpg`, is the one through which raw I/O moves data
(`physio`, #f("bio.c")).

#lines-to("/*", lead: true, after: "physpg = i++;")

The rest of RAM is freed. The stack of free pages (#f("malloc.c")) comes first
(#l("pgstk = (int *)PGADDR(i);")--#l("i += btop((btop(coretop) - i) * sizeof(int));")), one word for each page after it, and then every page
above it is pushed onto it (#l("for(a = btop(coretop)-1; a >= i; a--)")--#l("pgstk[npgfree++] = a;")), from the top down, so that
the low pages are handed out first. Memory
is cleared where it is used. The routine `machine_init` clears the area
of process 0, and `exec` (#f("sys1.c")) clears each image it builds.
The variable `maxmem` (#l("maxmem = npgfree;")) is the amount of RAM left, which is printed
(#l("printf(\"mem = ")). The routine `estabur` (#f("ureg.c")) refuses any
image larger.

#lines-to("mfree(swapmap, nswap, 1);")

The swap area is freed into `swapmap` from block 1 rather than 0
(#l("mfree(swapmap, nswap, 1);")), because `malloc` returns 0 when it
fails. So `swplo` is lowered by one to compensate (#l("swplo--;")).

#lines-to("static void", lead: true)

_Interrupts._ Every device interrupt reaches
the processor through a single line from the Generic Interrupt
Controller (GIC), whose distributor and processor interface
registers are reached through `GICD` and `GICC` (#l("#define\tGICD(o)\t(*(volatile unsigned *)(0xF0000000+(o)))"), #l("#define\tGICC(o)\t(*(volatile unsigned *)(0xF0001000+(o)))")),
at the offsets named after them. Both machines map them at these
kernel addresses (#f("qemu/mach.h"), #f("mp135/mach.h")). The clock is the processor's own
generic timer. Its interrupt, 27 (`clkirq`, #l("int\tclkirq = 27;")), is the
virtual timer's private interrupt. Each core has its own private
interrupts, numbered 16 to 31, which no other core sees.

The table `intrtab` (#f("conf.h"), #f("c.c")) pairs each configured
interrupt with the routine to call.

The routine `gicen` (#l("gicen(int n)")) gives interrupt `n` a middling priority (0x80) in the
distributor's byte-per-interrupt priority array (`IPRIORITYR`), then
sets its bit in the set-enable registers (`ISENABLER`).

#lines-to("void")

First `clkstart` reads `CNTFRQ` (#l("if((clkreload = cntfrq_get()/HZ) == 0)")), which gives the frequency of the
system counter. The variable `clkreload` is the number of its counts in `1/HZ`
second, and `clkrem` (#l("clkrem = cntfrq_get()%HZ;")) what the division leaves over, which
`clock` (#f("clock.c")) adds in so that the ticks keep exact time. A
frequency below `HZ` (the register is set by firmware) is the one
remaining way to "find no clock".

It then sets the timer's first deadline, `clkreload` counts after the
present value of the counter, and starts the timer (#l("cntv_cval_set(clkcval = cntvct_get() + clkreload);"), #l("cntv_ctl_set(1);")). The
deadline is kept in `clkcval` (#l("unsigned long long clkcval;")), from which `clock` computes the next.

#lines-to("/*", after: "cntv_ctl_set(1);")

The routine `intrstart` sets up interrupt handling. First it disables every
interrupt the distributor has, writing ones to all of its clear-enable
registers `ICENABLER`, of which `TYPER` gives the number less one
(#l("for(i = 0; i <= (int)(GICD(TYPER)&037); i++)")--#l("GICD(ICENABLER+4*i) = ~0U;")). The boot ROM may have left some of them enabled, such
as USB's after a boot over USB, and the kernel has no handler for
them. Then it enables every
configured interrupt whose number is known, the timer's among them
(#l("for(ip = intrtab; ip->i_irq; ip++)", after: "intrstart(void)")--#l("gicen(*ip->i_irq);")). Then it enables the distributor, lets interrupts of every
priority through the processor interface (`PMR`, the priority mask),
and enables the interface (#l("GICD(DCTLR) = 1;")--#l("GICC(CCTLR) = 1;")). Only then does it unmask
interrupts (#l("intr_enable();", after: "intrstart(void)")). No driver unmasks them before this, so
the controller's state until then does not matter.

#lines-to("void", lead: true, after: "intr_enable();")

The routine `irq` is called from `irq_entry` (#f("low.s")) with a
pointer to the saved registers of the interrupted program, in the
layout of #f("reg.h"), and with interrupts masked (see _Interrupt
Handling_, page #pageref(<sec-intr>)).

Reading the acknowledge register (`IAR`, #l("n = GICC(IAR);")) yields the number of
the highest priority pending interrupt, in its low ten bits, and marks
it active.

The routine whose number matches is called (#l("for(ip = intrtab; ip->i_irq; ip++)", after: "n = GICC(IAR);")--#l("(*ip->i_fn)((caddr_t)r[PC], r[PSR]);")) with the
interrupted program counter and status. The timer's routine is `clock`
(#f("clock.c")), which sets the next deadline and uses the two values to
charge the tick to the user or the system. The device routines ignore
them. Process 0 is set up before `main` calls `intrstart`, so `clock`
always finds a current process. A spurious interrupt (1023) matches
nothing.

Writing the same number to the end-of-interrupt register (`EOIR`,
#l("GICC(EOIR) = n;")) tells the GIC that the interrupt has been
handled, so that it may deliver the next one.

#lines-to("/*", lead: true, after: "GICC(EOIR) = n;")

_Kernel Map._ The table `board_map` (#f("seg.h")) comes from the
configuration (#f("c.c"), #f("qemu/mach.h"), #f("mp135/mach.h")). It holds the regions
to be mapped, each with its
kernel address, its physical bounds, and the attribute bits of its block
descriptors. The linker script defines `__bss_end`
(#l("extern char _start[], __bss_end[];")), the end of the kernel. On the MP135 machine the
whole kernel, its tables included, runs from SYSRAM, and on the QEMU
machine from the start of RAM. The tables `kl2`, `kl3u`, `kl3d`, and `bootl1` (#f("seg.h")) are reserved in
#f("low.s") and #f("mch.s").

The routine `kmap` (#l("kmap(unsigned long long attr)")) enters the regions of `board_map` whose
attributes are `attr` into the kernel's tables, each address at its
distance `v` from the physical one. The devices go into
`kl3d` a page at a time (#l("kl3d[PTX(v+a)] = a | attr | PTE_TAB;")), and `kl3d` into the entry of `kl2` for
`DEVBASE` (#l("kl2[BLX(DEVBASE)] = vtop((caddr_t)kl3d) | PTE_TAB;")). Memory goes into `kl2` 2~MB at a time (#l("kl2[BLX(v+a)] = a | attr;")). The
macros `PTX` and `BLX` (#l("#define\tPTX(va)"), #l("#define\tBLX(va)")) give the entry for a kernel address in a third-level
table, bits 12 to 20, and in `kl2`, its 2~MB block within the top
gigabyte, bits 21 to 29. The attributes are
defined in #f("seg.h"). A region of memory which does not begin on a block, the
MP135 machine's SYSRAM, is left alone (#l("else if((m->start & ((1U<<BLKSHIFT)-1)) == 0)")), since no block can map it,
and the pages in which `_start` mapped the kernel go on doing so
(#f("low.s")). Afterwards `kmap` calls `tlbflush` (#f("mch.s")),
because an entry may change. On the QEMU machine the entry for the
kernel changes from the table of `_start` to a block of RAM.

The routine `vtop` (#l("vtop(caddr_t va)")) is the inverse of the kernel's mapping. It finds the
region of RAM which holds a kernel address, and returns the physical
address. A device which reads or writes memory by itself (the virtio
disk of the QEMU machine, the SD card controller of the MP135 machine) must be
given physical addresses, and its driver calls `vtop` on each buffer.
A device region has no RAM behind it, and an
address found in no region is an error.

#lines-to("caddr_t")

The routine `machine_init` is called from `_start` (#f("low.s")), running at its
kernel address on a small stack in the bss, with only the kernel image
mapped. It first maps the device registers and, on the MP135 machine, starts
the watchdog (`wdinit`, #f("iwdg.c")). From then on a kernel which
stops resets the board within 33 seconds, even one which stops before
its console works. It then initialises the
console (#l("kmap(BLK_DEV);")--#l("cninit();")), so that `printf` and `panic` work from here on.
It leaves the GIC as QEMU or the boot ROM left it, since the interrupts
stay masked in `cpsr` until `intrstart` has set the controller up.

On the MP135 machine it then has the PMIC power the DDR memory
(#f("pmic.c")) and starts the DDR controller (#f("ddr.c")), and
`clock_ddr_init` is empty on the QEMU machine. Next `nsinit` (#l("nsinit();")) leaves the
secure world on the MP135 machine (#f("etzpc.c")). It must come after the
DDR is started, since the DDR's TrustZone controller accepts its
settings only from the secure world, and it is empty on the QEMU
machine, which has no secure world. Only then does it map
memory (#l("kmap(BLK_KERN);")), the DDR memory among it, since a mapping of RAM which
does not yet work would invite the processor to touch it
speculatively.

Core begins at `corebase`, which the configuration starts at
`COREBASE`, the first byte of the machine's RAM (#f("qemu/mach.h")). If the kernel
lies in that RAM, as on the QEMU machine, core begins instead at the
first page after it (#l("a = ptob(btop(vtop(__bss_end)));")--#l("corebase = a;")). On the MP135 machine, whose kernel runs
from SYSRAM, core is the whole of DDR. The offset `coreoff` (#l("coreoff = m->va - m->start;")) is the
difference between the kernel and physical addresses of the region of
`board_map` which holds core (#l("for(m = board_map; m->end != 0; m++)", after: "corebase = a;")). On the QEMU machine core lies in two
regions, the kernel's block and RAM, and the last, RAM at 0xc0200000,
gives the offset, as on the MP135 machine. The macro `PGADDR` (#f("seg.h")) adds it to
turn a page into a kernel address.

The `USIZE` pages of the per process data area of process 0, the first
of RAM, are entered in `kl3u` at `UBASE` (#l("for(a = 0; a < USIZE; a++)"), #l("kl3u[a] = (corebase + ptob(a)) | BLK_KERN | PTE_TAB;")), with the attributes
of a kernel page, as in `resume` (#f("mch.s")). Then `kl3u` is hooked
into the entry of `kl2` for `UBASE` (#l("kl2[(UBASE>>BLKSHIFT) & (NPTE-1)] = vtop((caddr_t)kl3u) | PTE_TAB;")), the last, which covers the top
2~MB of the address space, where no region of `board_map` reaches. The
identity mapping of `bootl1` (#f("low.s")) is removed (#l("bootl1[vtop(_start)>>L1SHIFT] = 0;")). From
here on nothing below `USRSIZE` is mapped but the user's. The area of
process 0 is then cleared (#l("for(p = (char *)UBASE; p < (char *)UBASE + ptob(USIZE); p++)"), #l("*p = 0;", after: "for(p = (char *)UBASE; p < (char *)UBASE + ptob(USIZE); p++)")).

The address returned (#l("return((caddr_t)UBASE + ptob(USIZE));")) is the top of the u-area, where #f("low.s")
puts the kernel stack.

#lines-to("void", lead: true)

_Pages._ The routines `copyseg` and `clearseg` copy and clear one page,
1024 words.

#lines-to("/*", lead: true, after: "d[i] = 0;")

_Memory Files._ The routine `mapaddr` (#l("mapaddr(int dev, off_t off, unsigned long long attr)")) turns an offset of a
memory special file (#f("mem.c")) into the kernel address of the same
byte, within a region of `board_map` whose attributes are `attr`. For
`/dev/mem` (minor 0) the offset is a physical address, and for
`/dev/kmem` (minor 1) a kernel address (#l("base = minor(dev) == 0 ? m->start : m->va;")). The routine `memaddr`
serves memory, any region of attributes `BLK_KERN`, and for `/dev/kmem`
also the u-area of the current process at `UBASE`
(#l("if(minor(dev) == 1 && (unsigned)off - UBASE < ptob(USIZE))")). The routine `devaddr` serves the device
registers, the `BLK_DEV` regions, which #f("mem.c") reads and writes a
whole aligned word at a time, since the registers take no narrower
access.

The routines `fumem` and `sumem` fetch and store one byte through
`fkbyte` and `skbyte` (#f("mch.s")), which turn an abort into -1 by way
of `nofault`. A region of memory is mapped in 2~MB blocks, part of
which may have no memory behind it, and a device's page may have holes
where no register answers. Without the guard a read
there would panic the kernel. Both return -1 for an offset in no
region, and the driver sets `ENXIO`.

#lines-to("m = (PSR+1)*sizeof(int);")

_Signals._ The routine `sendsig` makes the process call the signal
handler at `p` when it next returns to user mode (see _Signals_, page
#pageref(<sec-signals>)).

The variable `n` (#l("n = (u.u_ar0[SP] - m - sizeof(u.u_fps)) & ~7;")) is the user stack pointer less the size of the frame,
rounded down to a multiple of 8 as the ARM calling convention requires.
The frame is the registers, `m` bytes (#l("m = (PSR+1)*sizeof(int);")), 17~words, which are `r0` to `r15`
and the status register, followed by `u.u_fps` (#f("user.h")), where
`psig` (#f("sig.c")) has just stored the floating point registers.

First `grow` (#f("sig.c")) is asked to extend the stack to cover the
frame (#l("grow(n);")), because the stack holds only what the process
has used so far, and the frame may lie below it. The frame is then copied
out (#l("if(copyout((caddr_t)u.u_ar0, (caddr_t)n, m) < 0 ||")--#l("}", after: "copyout((caddr_t)&u.u_fps, (caddr_t)(n+m),")), the registers and then the floating point state, with
`copyout` (#f("mch.s")), which fails if any part of it lies outside the
process's memory. If the frame cannot be written,
the process is sent `SIGSEG`, with its handler first reset to the
default so that it is not caught in turn.

#lines-to("u.u_ar0[SP] = n;")

The stack pointer is then lowered past the frame. The link register,
`u_ar0[LR]`, is set to the
trampoline at `SIGTRAMP` (#f("seg.h")). The program counter (`PC`) is
set to the handler, and `r0` to the signal number, the handler's
argument. The Thumb state is cleared in the saved status
(#l("u.u_ar0[PSR] &= ~")). That is the `T` bit (5), the `IT` bits (10 to 15, 25,
and 26), which make the next instructions of a Thumb `if-then` block
conditional, and the `E` bit (9), big-endian data. Every program built
here is ARM code, but one may contain Thumb code of its own, and the
handler, ARM code, must be entered in ARM state with no `if-then`
block pending.

When the handler returns, it returns to the trampoline, with the stack
pointer at the frame, and the trampoline issues `sigreturn` (#l("sigreturn(void)")).

#lines-to("void", lead: true, after: "u.u_ar0[PSR] &= ~TBITS;")

_Signal Return._ System call 63, `sigreturn`, undoes `sendsig`. The
trampoline calls it when the handler returns, and at that point the
user stack pointer addresses the frame which `sendsig` wrote.

#lines-to("a = (caddr_t)u.u_ar0[SP];")

The frame is copied back in through `copyin`, which fails unless the
frame lies in the process's memory. That happens if the handler has
moved the stack pointer, or if a program calls `sigreturn` without a
signal, and the process then gets `SIGSEG`. The floating point part
goes straight to `u.u_fps`, and setting `u_fpsaved`
(#l("u.u_fpsaved = 1;")) makes `trap` load it into the hardware on the
return to user mode (#f("user.h")).

#lines-to("for(i = 0; i < PSR; i++)")

The frame lies in user memory, so the program can change it before
`sigreturn` reads it back. Any value of `FPSCR` is harmless, since it
holds only the user's own modes and flags. The saved `CPSR` is another
matter. Only the bits a user may set (`UBITS`, #f("param.h")) are
taken, and the mode is set to user mode (#l("u.u_ar0[PSR] = ")). The
process continues where the signal interrupted it, with the condition
flags it had, since it may have been between a comparison and a
conditional branch.

#lines-to("u.u_r.r_val1 = f[R0];")

The routine `trap` (#f("trap.c")) will store `r_val1` and `r_val2` into
`r0` and `r1` as the results of this system call. Setting them to the
saved values makes the return restore those two registers too.

#lines-to("void", lead: true, after: "u.u_r.r_val2 = f[R1];")

_Unexpected Traps._ The vector table's reserved entry and the FIQ entry
should never be taken. Both go to `badtrap` (#f("low.s")), which calls
`panictrap`.

#lines-to(none)
#source("/usr/sys/h/proc.h")

A process is represented in two places. Its `proc` structure, one
element of the array `proc` (#l("extern struct proc proc[];\t/* the proc table itself */")), stays in RAM throughout the life
of the process and holds what the system must know about it even
when the rest of it is on the swap device: whether it is in memory,
where it is, why it sleeps, and the information that scheduling and
signals need. The rest of the process state, the `user` structure
(#f("user.h"), which is discussed in the next section, page
#pageref(label("user.h"))), lives at the bottom of the process's memory image, the u-area, data,
and stack which `p_addr` and `p_map` locate (see _The Address Space_, page
#pageref(<sec-addr>)), and is swapped with it.

#lines-to("char\tp_pri;")

_Scheduling._ The scheduling priority `p_pri` (#l("char\tp_pri;\t\t/* priority, negative is high */")) is recomputed by `setpri`
(#f("slp.c")) from `p_cpu` and `p_nice`, or set by `sleep` to the
priority given for the event. A smaller value is more urgent, so the
comment's "negative is high" means more urgent than any positive
value. Both `p_time` and `p_cpu` stop at 255, so that a process which
has run long is penalised no further.

#lines-to("int\tp_sig;")

_Signals._ The field `p_sig` (#l("int\tp_sig;\t\t/* signals pending to this process */")) is the set of pending signals, one bit each, the bit for
signal _n_ being 1 shifted left _n_-1.

#lines-to("int\tp_addr;")

_Memory._ The fields `p_addr` (#l("int\tp_addr;\t\t/* u-area page, or image on swap */")), `p_size` (#l("int\tp_size;\t\t/* size of swappable image (pages) */")), and `p_map` (#l("int\tp_map;\t\t/* page map of the image in core */")) locate the image. When `SLOAD` is set,
`p_addr` is the page of the u-area, a page number, the physical address divided by 4096
(`PGADDR`, #f("seg.h")), and the data and stack pages may lie anywhere
in RAM: the page map `p_map` lists them in order (#f("malloc.c")). Otherwise `p_addr` is a block number on the swap
device, where the whole image lies in order, and `p_map` is 0. The size
is in pages in both cases, and includes the `USIZE` pages of the
u-area, which come first.

An image larger than `maxmem`, the free RAM, is refused by `estabur`
(#f("ureg.c")).

#lines-to("int\tp_ptab;")

The fields `p_ptab` and `p_nptab` (#l("int\tp_ptab;\t\t/* user page tables (page) */"), #l("int\tp_nptab;\t/* their number, 0 if none */")) are the first page and the number
of the pages of user page tables which the process holds while it is in
RAM, taken from the pool by `sureg` and given back by `ptfree`
(#f("ureg.c")). The count is zero while the process has none, as after
it has been swapped out or created, or its image has changed.

#lines-to("caddr_t p_wchan;")

_Waiting._ A sleeping process waits on the address in `p_wchan` (#l("caddr_t p_wchan;\t/* event process is awaiting */")).
The routine `wakeup` (#f("slp.c")) compares it with its argument. The field `p_textp` (#l("struct text *p_textp;\t/* pointer to text structure */")) points to the
shared text segment, which every program has (#f("text.c")). Only
process 0, and process 1 while it runs `icode` (#f("machdep.c")), have no
text segment. The runnable processes are chained through `p_link` (#l("struct proc *p_link;\t/* linked list of running processes */"))
into the list headed by `runq` (#f("systm.h")). The routine `setrq` (#f("slp.c")) adds a
process to it, and `swtch` searches it for the most urgent one that is
in RAM. The seconds of an `alarm` are counted down in `p_clktim` (#l("unsigned\tp_clktim;")).

_Zombies._ When a process exits, its image is released, but its `proc`
entry lingers in the `SZOMB` state until the parent collects it with
`wait` (#f("sys1.c")). The entry then carries the exit status and the
times used, in `p_xstat`, `p_utime`, and `p_stime` (#l("short\tp_xstat;"), #l("time_t\tp_utime;"), #l("time_t\tp_stime;")), which `exit` sets.

#lines-to("/* stat codes */")

_States._ The field `p_stat` (#l("char\tp_stat;")) takes one of these values, and a
zero entry is free. `SWAIT` is a leftover from the Sixth Edition and
is never set. A sleeping process is `SSLEEP` whatever its priority, and
`p_pri` tells the kinds apart. `SIDL`, which v7's `newproc` set while
it wrote a child's image to the swap area, is no longer used (#f("slp.c")), and `SZOMB` covers the time
between `exit` and the parent's `wait`.

#lines-to("/* flag codes */")

_Flags._ The field `p_flag` (#l("char\tp_flag;")) is a set of these bits. `SLOAD` says that the process's image is in RAM, so that `p_addr` is a
page number and not a swap block. It is set for process 0 by `main`,
for each new process by `newproc`, and on swapping in by `swapin`
(#f("slp.c")). It is cleared when the image is written to the swap area
(`xswap`, #f("text.c")). `SSYS`
marks process 0, so that `sched` can pass over it in the same test as
locked processes
(#at("/usr/sys/sys/slp.c", "|| (rp->p_flag&(SSYS|SLOCK|SULOCK|SLOAD))!=SLOAD)")).
`SLOCK` keeps a process in RAM while an operation needs its image to
stay where it is. It is set and cleared around swapping the process
out, reading in its text, and a transfer by `physio` directly to or
from its image.
`SSWAP` marks a process whose image was written to the swap area from
the middle of `newproc`, `expand`, or `xexpand`, so that `swtch` (#f("slp.c"))
resumes it through `u_ssav` rather than `u_rsav`. `SULOCK` holds a
process in RAM at the user's request, through the `lock` system call
(`syslock`, #f("acct.c")). `STRC` and `SWTED` serve `ptrace`.

#lines-to(none)
#source("/usr/sys/h/user.h")

The `user` structure is the second half of the description of a
process, the half that can be swapped. It lies at the start of the
process's u-area, `USIZE` pages (#f("param.h")), and the process's
kernel stack fills the rest (see _The Address Space_, page
#pageref(<sec-addr>)). Only the u-area of the current process is
addressable, always at `UBASE`. The kernel names it `u`
(#l("extern struct user u;")), which the linker script places at that
address (#f("qemu/unix.ld"), #f("mp135/unix.ld")). To switch processes
is, at bottom, to change which u-area appears there.

#lines-to("#define\tEXCLOSE", lead: true)

`EXCLOSE` (#l("#define\tEXCLOSE\t01")) is the bit of `u_pofile` (#l("char\tu_pofile[NOFILE];\t/* per-process flags of open files */")) which marks a file to be
closed by `exec`.

#lines-to("struct\tuser")

A label (`label_t`, #f("param.h")) is the set of registers which `save`
stores and `resume` reloads, much like a `setjmp` buffer. Reloading it
makes the original call of `save` return a second time (see _Process
Switching_, page #pageref(<mch-switch>)). The label `u_rsav` (#l("label_t\tu_rsav;\t\t\t/* save info when exchanging stacks */")) holds the registers saved by `save` (#f("mch.s")) when the
process gives up the processor in `swtch` (#f("slp.c")), and restored by
`resume` (#f("mch.s")). The type `label_t` has ten words, for r4 to r11, the stack pointer, and
the link register. Since `save` is called as an
ordinary function, its caller has already set aside anything it needs
from the other registers, so `save` keeps only those which the ARM
procedure call standard requires a called function to preserve (see
_The ARM Processor_, page #pageref(<sec-arm>)).

The structure `u_fps` (#l("int\tu_fper;\t\t\t/* FP error register */")--#l("} u_fps;")) holds the state of the floating point unit
while the process is not using it, the status register `FPSCR` in
`u_fpsr` and the 32 registers in `u_fpregs`. The flag `u_fpsaved` says
that the hardware registers have been stored there and must be
reloaded before the return to user mode.

#lines-to("char\tu_segflg;\t\t/* IO flag: 0:user D; 1:system; 2:user I */")

The flag `u_segflg` (#l("char\tu_segflg;\t\t/* IO flag: 0:user D; 1:system; 2:user I */")) tells `iomove` (#f("rdwri.c")) and its relatives where
`u_base` points. Usually it points into the user's memory. But the
kernel sometimes reads or writes a file for itself, into its own memory. Thus `exec` reads a program's headers, `namei` reads directories,
and a core dump writes out the u-area. Then `u_segflg` is 1. The values
0 and 2, user data and user text, mean the same, since the I-space
routines are aliases of the D-space ones (#f("systm.h")). The error number that a system call returns is kept
in `u_error`. The four user and group ids follow, effective and real.
The pointer `u_procp` (#l("struct proc *u_procp;\t\t/* pointer to proc structure */")) links back to the process's `proc` entry, and `u_ap`
points to the arguments of the current system call, which `trap` has
copied into `u_arg` (#f("trap.c")).

The structure `u_r` (#l("struct {\t\t\t/* syscall return values */")) holds the one or two values that a
system call returns, in `r0` and `r1`.

#lines-to("caddr_t\tu_base;\t\t\t/* base address for IO */")

The parameters of an I/O transfer, `u_base`, `u_count`, and
`u_offset`, are kept here so that every layer of the transfer can reach
them without their being passed as arguments: the system call, `readi`
and `writei` (#f("rdwri.c")), `iomove`, and the drivers. After them come
the current and root directories, and the working storage of `namei` (#f("nami.c")), the current component of the path name, a pointer into
the name, a copy of the directory entry, and the parent directory. They
are kept here, not on `namei`'s stack, because the callers of `namei` go
on using them: `wdir` (#f("iget.c")) writes the new directory entry from
them.

#lines-to("unsigned u_ptstart, u_pdstart;")

When a process's image is laid out, `estabur` (#f("ureg.c")) records
its shape here without building any tables: the first pages of the
text and the data (#l("unsigned u_ptstart, u_pdstart;")), the access rights of the text
(#l("int\tu_pxrw;")), `RO` except while `xalloc` (#f("text.c"))
reads the text in or `ptrace` (#f("sig.c")) writes into it for a
debugger, and the sizes, in pages, of the text, the data, and the
stack, `u_tsize`, `u_dsize`, and `u_ssize`
(#l("unsigned u_tsize;")--#l("unsigned u_ssize;")). The routine `sureg` builds the
page tables from them later, wherever the image then lies in RAM. v7
kept a separate _prototype_ of the segmentation registers, `u_uisa`
and `u_uisd`, since the PDP-11's registers had to be loaded from it at
every switch. Here the tables stay in RAM while the process does, and
are rebuilt from the shape alone. The
table of open files, indexed by file descriptor, is `u_ofile`
(#l("struct file *u_ofile[NOFILE];")). The array `u_arg`
(#l("int\tu_arg[")) receives the arguments of a system call from the
saved registers r0 to r3.

#lines-to("label_t\tu_qsav;\t\t\t/* label variable for quits and interrupts */")

The label `u_qsav` (#l("label_t\tu_qsav;")) lets a system call be
abandoned. The routine `trap` (#f("trap.c")) saves it as each call
begins. When a signal interrupts a sleep, `sleep` (#f("slp.c")) resumes
there instead of returning, and `trap` ends the call with `EINTR`. A
third label, `u_ssav`, serves `expand` (#f("slp.c")) and the swapping
code, which may need to resume a process at the point where its image
was copied. The array `u_signal` (#l("int\tu_signal[NSIG];")) holds, for
each signal, zero for the default action, one to ignore it, or the
address of a catching routine, which fits since an `int` holds an
address on the ARM. The four times are counted in clock ticks.

#lines-to("int\t*u_ar0;")

The pointer `u_ar0` (#l("int\t*u_ar0;\t\t\t/* address of users saved R0 */")) points to the user's registers as saved on the kernel
stack on entry to the system. The frame in the port holds r0 to r14,
the program counter, and the status register, and #f("reg.h") gives the
index of each in the frame. The other places where registers are saved
are listed in the Introduction (see _Saved State_, page
#pageref(<sec-saved>)).

#lines-to("struct uprof {")

The structure `u_prof` holds the parameters of the `profil` system call.

#lines-to("struct tty *u_ttyp;")

The controlling terminal is named by `u_ttyp` (#l("struct tty *u_ttyp;\t\t/* controlling tty pointer */")), whose `t_dev` gives its
device (#f("tty.h")).

#lines-to("struct {\t\t\t/* header of executable file */")

The structure `u_exdata` (#l("struct {\t\t\t/* header of executable file */")) is the header of the program being executed, read by
`getxfile` (#f("sys1.c")). In v7 it was the eight-word `a.out` header.
The executables here are in ELF, the Executable and Linkable Format,
and the first 52 bytes of the structure are the ELF file header, with
the ELF names. The kernel reads the four identifying bytes of
`e_ident` (#l("unsigned char e_ident[16];")), `\x7fELF`, the entry point `e_entry`
(#l("unsigned e_entry;")), and the offset, entry size, and number of the program
headers, `e_phoff`, `e_phentsize`, and `e_phnum` (#l("unsigned e_phoff;"),
#l("unsigned short e_ehsize, e_phentsize, e_phnum;")).

The array `ph` (#l("struct {", after: "unsigned short e_shentsize, e_shnum, e_shstrndx;")--#l("} ph[2];\t\t/* text and data segments */")) then receives two program headers, or rather their
first six fields, the type, file offset, virtual address, physical
address, size in the file, and size in memory. The routine `getxfile`
fills it with the two loadable segments of the program, the text,
read-only and executable, and the data. The remaining two fields of a
program header are not needed. `PT_LOAD` (#l("#define\tPT_LOAD\t1")) is the type of a
loadable segment.

#lines-to("char\tu_comm[DIRSIZ];")

The field `u_comm` (#l("char\tu_comm[DIRSIZ];")) holds the program's
file name, without its directory, for accounting and `ps`. The time the
process started is `u_start`. The flags in `u_acflag` (#f("acct.h"))
record whether it forked without calling `exec` (`AFORK`) and whether
it used the super-user's privileges (`ASU`). Both go into its
accounting record when it exits (#f("acct.c")). The file creation mask
`u_cmask` (#l("short\tu_cmask;")) holds the permission bits to be
removed from the mode of every file the process creates. It is set by
the `umask` system call and inherited by children, so a shell can keep,
say, other users' write permission off every new file.

The kernel stack begins at the top of the u-area, `UBASE` plus `USIZE`
pages, which `machine_init` returns and #f("low.s") loads into the
stack pointer, and grows down towards the structure. Nothing but the
size of the u-area keeps it from reaching the structure.

#lines-to("extern struct user u;", lead: true)

The structure `u` is declared external (#l("extern struct user u;")).
Its address, `UBASE` (#f("param.h")), comes from one line of the linker
script (#f("qemu/unix.ld"), #f("mp135/unix.ld")),
so every reference to `u` is to that fixed address. Why `UBASE` lies
where it does is told in the Introduction (see _The Address Space_,
page #pageref(<sec-addr>)).

#lines-to("/* u_error codes */")

The error numbers which a system call may return in `u_error`. On an
error, `trap` (#f("trap.c")) sets the carry bit of the saved status and
puts the number in `r0`. The library's system call stub, `cerror`
(#f("libc/syscall.s")), tests the carry after `svc`, stores `r0` in
`errno`, and returns -1.

#lines-to(none)
#source("/usr/sys/sys/ureg.c")

The routines of #f("ureg.c") control a process's user address space.
Their names come from v7, where they set the PDP-11's user segmentation
registers. The name `estabur` means "establish user registers", and
`sureg` means "set user registers". Here they build and load page
tables. Whenever an image is created or changes size, by `exec`
(`getxfile`, #f("sys1.c")), by `brk` (`sbreak`), by the growth of the
stack (`grow`, #f("sig.c")), or by `expand` (#f("slp.c")), its new shape
is passed to `estabur`. The routine checks that the segments lie in the
address space apart from each other and that the image fits in
`maxmem`, records it in the process's `user` structure (see
#f("user.h"), page #pageref(label("user.h"))), discards
the old page tables, and calls `sureg`. The routine `sureg` points the
MMU at the process's tables, first building them from the recorded shape if
the process has none. It is called whenever the image may have changed, by `estabur`, by `newproc` and `expand` (#f("slp.c")), by `xexpand`
(#f("text.c")), by `sbreak` and `grow` (#f("sys1.c"), #f("sig.c")), and when `swtch` (#f("slp.c")) resumes a process.

The tables form a tree in RAM (see _Translation Tables_, page
#pageref(<sec-tables>)). Each process has its own tree for the lower
three gigabytes, and the kernel has one tree for the top gigabyte,
shared by all processes. A process's tree begins with a first-level
table of four entries, each covering a gigabyte. Below it, for each
gigabyte in use, is a second-level table of 512~entries, each covering
2~MB, and for each 2~MB in use, a third-level table of 512~page entries.
The first-level tables live in `l1tab` (#l("unsigned long long *l1tab;"),
#l("unsigned l1pa;")), one for each slot of the process table, set aside
by `startup` (#f("machdep.c")). The tables below them are pages from
the pool `ptmap`, and the process's `proc` entry records which
(`p_ptab` and `p_nptab`, #f("proc.h")). They are kept while the
process's image stays as it is, so a switch only points `TTBR0` at the
process's first-level table.

#lines-to("/*")

A `urange` (#l("struct urange {")) describes a segment to be mapped by its first page,
its number of pages, the page map which lists its pages and the entry
of the first, or, with no map, its first page itself, and its access
bits.

#lines-to("/*", lead: true, after: "};")

The routine `upage` gives the page of entry `i` of a range. The range without a map
is the trampoline's one page. A range with a map may reach past the
entries the map yet holds, `nent`: `sbreak` and `grow` record the new
sizes with `estabur`, which builds the tables at once, before `expand`
has added the pages (#f("sys1.c"), #f("sig.c")). Such an entry is left unmapped (#l("return(0);", after: "upage(register struct urange *rp, unsigned i, int nent)")), and
the caller builds the tables again once the pages are there.

#lines-to("/*", lead: true, after: "upage(register struct urange *rp, unsigned i, int nent)")

The routine `ptbuild` makes the tables of the current process `p`. It
lists up to four ranges (#l("nr = 0;")--#l("nent[nr-1] = 1;")), each with the number of entries its map holds, `nent`. The text's
pages are those of the shared text segment's page map, if there is one, and carry the text's access rights,
`u_pxrw`. The data and the stack are the process's own pages,
listed in its page map, the data from entry 0 and the stack from entry
`u_dsize`, and are read and write. The fourth is
the one read-only page of the signal trampoline (`sigpage`,
#f("machdep.c")). The ranges are then sorted by address, their counts with them (#l("for(i = 1; i < (int)nr; i++)")--#l("nent[j-1] = a;")).

A first pass counts the tables needed (#l("n = 0;", after: "r[j-1] = t;")). Each gigabyte a range touches
needs a second-level table, and each 2~MB block a third-level one.
Since the ranges are sorted and apart, a new gigabyte or block shows as
a change from the last one seen, and the pass steps a block at a time
(#l("for(pg = rp->va; pg < rp->va+rp->n; pg = (pg|(NPTE-1)) + 1)")). The text, the data, and the trampoline of a
small program share one block, so it needs four tables in all,
two for the low gigabyte and two for the stack's.

The pages are taken from the pool as one run (#l("if((a = malloc(ptmap, n)) == 0) {")). If the pool is
exhausted, the process is killed, as `xalloc` (#f("text.c")) kills one
for which no `text` entry remains. Its first-level table stays empty,
so that any reference to its address space faults. With `NPTAB`
(#f("param.h")) pages, this happens only when many large processes are in
RAM at once.

The run is cleared, and a second pass, in the same order, takes the
tables from it as they are first needed. It enters each second-level
table in the first-level table and each third-level table in its
second-level table (#l("l1[gb] = ptob(a) | PTE_TAB;"), #l("l2[blk & (NPTE-1)] = ptob(a) | PTE_TAB;")), and each page in its third-level
table with the range's access bits (#l("l3[pg & (NPTE-1)] = ptob(pa) | PGUSER | rp->ap;")), passing over a page which the map does
not yet hold (#l("if((pa = upage(rp, pg - rp->va, nent[rp-r])) == 0)")). An entry which points to a
table holds its physical address and the type `PTE_TAB` (#f("seg.h")).
The attributes other than the access rights are `PGUSER` (#f("seg.h")),
among them "not global", which lets `ttbset` (#f("mch.s")) discard the
user's translations alone.

#lines-to("/*", lead: true, after: "}")

The routine `ptfree` returns a process's tables to the pool and empties its
first-level table. It is called whenever the tables no longer describe the image, by
`estabur` when the shape changes, by `sbreak` and `grow`
(#f("sys1.c"), #f("sig.c")) when the image's pages change, by `xswap` (#f("text.c")) when it
leaves RAM, and by `exit` (#f("sys1.c")). The first-level table is
emptied even when there were no tables, so that a slot of the process
table always begins with an empty address space.

#lines-to("/*", lead: true, after: "}")

The routine `sureg` builds the tables of the current process if it has none, and
loads them with `ttbset` (#f("mch.s")), which also discards the
previous process's translations. At a process switch, the usual case,
the tables already exist and only `TTBR0` changes. After the process
has been created, swapped in, or moved, or its sizes have changed, they
are built afresh. A text in RAM never moves while a process which uses
it is in RAM, so the tables of a process need never change because of
another.

#lines-to("/*", lead: true, after: "}")

The routine `apart` (#l("apart(unsigned a, unsigned n, unsigned b, unsigned m)")) says whether two ranges of pages have none in
common. An empty range has none in common with anything.

#lines-to("/*", lead: true, after: "}")

The routine `estabur` checks a new shape before it records it. Each
segment must lie below `USRSIZE` (#l("if(nt > top || ts > top-nt || nd > top || ds > top-nd || ns > top)")), tested so that no sum can wrap.
The text, the data, the stack, which ends at `USRSIZE`, and the
trampoline's page at `SIGTRAMP` (#f("seg.h")) must all be apart
(#l("if(!apart(ts, nt, ds, nd) || !apart(ts, nt, ss, ns) ||")--#l("!apart(ds, nd, tr, 1) || !apart(ss, ns, tr, 1))")). And the image, with its per process data area and the pages of its
page maps, and of its text's, must not exceed `maxmem` (#l("if(USIZE + mapneed(0, nd+ns) + mapneed(0, nt) > (int)maxmem)")), so that the
swapper can always bring it back in once it has made room. In v7 the checks were others. It refused separate
instruction and data spaces on a PDP-11 without them, and required the
segments to fit its eight segmentation registers, the text and data from
address 0 and the stack at the top. Here each segment lies where its
program asks (`getxfile`, #f("sys1.c")).

The shape is then recorded (#l("u.u_ptstart = ts;")--#l("u.u_pxrw = xrw;")), the old tables are released,
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
another makes it runnable again (`wakeup`, `setrun`), the calculation
of the priority of a process running in user mode (`setpri`), which
rises with its recent use of the processor and its `nice` value, as
distinct from the fixed priority a process is given when it sleeps in
the kernel, the scheduler proper (`sched`, `swapin`), and the two
procedures which create or grow a process image in RAM (`newproc`,
`expand`).
How they work together is described in the Introduction (see
_Scheduling and Swapping_, page #pageref(<sec-sched>)). The commentary follows the file, `sleep` and `wakeup`, then `setrun` and `setpri`,
then `sched` and `swapin`, then `swtch`, and last `newproc` and
`expand`.

#lines-to("#define SQSIZE", lead: true)

Sleeping processes are kept in `slpque`
(#l("struct proc *slpque[SQSIZE];")), an array of `SQSIZE` list heads
(#l("#define SQSIZE")), each heading a list chained through `p_link`.
`HASH` (#l("#define HASH(x)")) picks the list for a channel. It drops
the low five bits of the address, which differ little between nearby
objects, and keeps the next six, since `SQSIZE` is 64.

#lines-to("/*")

_Sleep and Wakeup._ A process sleeps on a _channel_, an address that stands for the event
awaited. No table defines the channels. By convention a channel is the
address of the object concerned, such as a buffer being read, a locked
inode, or `lbolt` for the clock's once-a-second tick. As the comment
warns, a process may return from `sleep` while what it waited for is
still not available. The routine `wakeup` wakes every process sleeping
on the channel, and the first to run may take the buffer or inode the
others wanted. So callers sleep in a loop, and test their condition
again each time they wake.

#lines-to("void")

A process calls `sleep` itself, in the kernel, when a system call must
wait for something. It records the channel (`chan`) and the priority at
which to run again (`pri`), puts itself on the list which `HASH` picks
for the channel, and calls `swtch` to give the processor to another
process until `wakeup` makes it runnable.

#lines-to("s = intr_disable();", after: "sleep(caddr_t chan, int pri)")

Interrupts are masked from #l("s = intr_disable();", after: "rp = u.u_procp;")
to #l("intr_enable();", before: "if(runin != 0) {") (#f("mch.s")), so that no interrupt routine can
call `wakeup` (#l("wakeup(register caddr_t chan)")), which makes the
sleepers on a channel runnable, while the process's entry and the list
are half changed.

#lines-to("if(pri > PZERO) {")

If `pri` is numerically greater than `PZERO`, a less urgent wait, the
sleep may be broken by a signal.
A signal already pending (#l("if(issig()) {")) cancels the sleep before it has begun.
Otherwise, if the swapper is waiting (#l("if(runin != 0) {")), it is
woken. The swapper is `sched`, the loop in which process 0 runs
(#l("sched(void)")). It waits on `runin` when a process on the swap
area is ready to come in but no process in RAM can be swapped out to
make room. This process, now asleep, may be such a candidate.
After `swtch` returns, the signal test is repeated (#l("if(issig())", after: "wakeup((caddr_t)&runin);")): a signal is one
of the events which may have ended the sleep, by way of `setrun`.

#lines-to("/*", lead: true)

A signal is handled by abandoning the system call altogether. Just
before `trap` called the system call routine, it called
`save(u.u_qsav)` (#at("/usr/sys/sys/trap.c", "if (save(u.u_qsav)) {")), and that call returned 0. Resuming at
`u_qsav` makes the same call of `save` return again, now with 1, so
`trap` knows that the call was interrupted and returns `EINTR` (see
_Saved State_, page #pageref(<sec-saved>)). This way the kernel can
abandon a system call from any depth of nested routines at once,
without every routine on the way having to check for a signal and pass
an error back. What `trap` does is described with #f("trap.c"), page
#pageref(label("trap.c")).

The jump back to `trap` skips whatever the routines on the way would
have done after `sleep` returned. So a process which sleeps at such a
priority must hold no lock that only that skipped code would release.
The pipe code, for example, releases its inode before it sleeps
(#f("pipe.c")).

The kernel has these locks. Masking interrupts with `intr_disable` and
`intr_restore` (#f("mch.s")) protects data which interrupt routines
share, and is never held across a sleep. An inode is locked by its
`ILOCK` bit, set by `iget` and `plock` and cleared by `prele` and
`iput` (#f("iget.c"), #f("pipe.c")). A buffer is locked by `B_BUSY`,
set by `getblk` and cleared by `brelse` (#f("bio.c")). A shared text is
locked by `XLOCK` while it is swapped in or out (`xlock`, `xunlock`,
#f("text.c")). A mounted file system's super-block has two locks,
`s_flock` while its list of free blocks changes and `s_ilock` while its
list of free inodes changes (#f("filsys.h"), #f("alloc.c")). And
`updlock` (#f("alloc.c")) lets only one `sync` run at a time. Every one
of these but the first is a flag, which works only on one processor
(see _Multiprocessing_, page #pageref(<sec-mp>)).

#lines-to("/*", lead: true, after: "}")

The routine `wakeup` is called by whatever makes an awaited event
happen. An interrupt routine calls it when a transfer ends (`iodone`,
#at("/usr/sys/dev/bio.c", "iodone(register struct buf *bp)")), the code which releases a lock calls it (`prele`,
#at("/usr/sys/sys/pipe.c", "prele(register struct inode *ip)"), and `brelse`, #at("/usr/sys/dev/bio.c", "brelse(register struct buf *bp)")), `clock` calls it once a
second for `lbolt` (#at("/usr/sys/sys/clock.c", "wakeup((caddr_t)&lbolt);")), and `exit` calls it for a waiting
parent (#at("/usr/sys/sys/sys1.c", "wakeup((caddr_t)q);")). It walks the list which `HASH` picks for
`chan`. The hash is not one-to-one. Several channels may share a list,
so `wakeup` tests each process's channel
(#l("if(p->p_wchan==chan && p->p_stat!=SZOMB) {")). Each process found
is removed from the list, its channel is cleared, and it is handed to
`setrun` (#l("setrun(register struct proc *p)")).

#lines-to("if (q == NULL)")

Removing a process from a list chained in one direction means making
whatever pointed to it point to its successor instead. If the process
is the first on the list, that is the head, `slpque[i]`
(#l("sp = slpque[i] = p->p_link;")). Otherwise it is the `p_link` of the
process before it, which the loop keeps in `q`
(#l("sp = q->p_link = p->p_link;")). The successor is saved in `sp`
first, because `setrun` will reuse `p_link`.

#lines-to("/*", lead: true, after: "}")

_The Run Queue._ There is a single run queue, `runq`, of every runnable
process, in no particular order. The routine `swtch` searches it for
the most urgent process in RAM, so a process must be on it to be run.
The routine `setrq` adds a process to it. It is called by `setrun`
(#l("setrq(p);", after: "setrun(register struct proc *p)")), which `wakeup` calls for each process it wakes,
by `qswtch` when the current process gives up the processor but stays
runnable (#l("setrq(u.u_procp);")), and by `newproc` for a new child
(#l("setrq(rpp);")). The queue is chained through `p_link`, the same
field which chains the sleep lists, since a process is either asleep or
runnable, never both.

Before adding the process, `setrq` searches the queue for it and prints
"proc on q" if it is already there. In a correct kernel that cannot
happen. If it did, adding it again would make the list loop back on
itself, and `swtch` would never finish its search. The search guards
against a bug elsewhere in the kernel. The comment invites the loop's
removal. Berkeley removed it with the list itself, when 4BSD replaced
the single list by 32 queues ordered by priority, so that `swtch` no
longer had to search every runnable
process.#footnote[4BSD (November 1980), `sys/sys/locore.s`, routines
`Setrq` and `Remrq`: "whichqs tells which of the 32 queues qs have
processes in them." 3BSD (1979) still has the single `runq` and the
"proc on q" check in `slp.c`. Both trees are in The Unix Heritage
Society's archive, #link("https://www.tuhs.org/cgi-bin/utree.pl?file=4BSD/usr/src/sys/sys/locore.s")[`tuhs.org`].]

#lines-to("/*", lead: true, after: "}")

The routine `setrun` (#l("setrun(register struct proc *p)")) makes a process runnable. It is
called by `wakeup`, by interrupt routines, and by routines such as
`psignal` (#at("/usr/sys/sys/sig.c", "psignal(register struct proc *p")), which must rouse a process whatever it is
waiting for. A process found still asleep is on one of the sleep lists,
and `setrun` then calls `wakeup` on its channel to take it off
(#l("if ((w = p->p_wchan)) {")), and that call of `wakeup` comes back to `setrun`.

The channel is copied into `w` before it is tested, because `setrun`
may run with interrupts unmasked. An interrupt between the test and the
call could run `wakeup` for the same channel, which clears `p_wchan`,
and `setrun` would then call `wakeup` with a null channel. The panic
(#l("panic(\"Running a dead proc\");")) catches a call for a free or zombie entry of the
process table, which happens only through a bug elsewhere in the
kernel.

The comment's "swapped in if necessary" refers to the last lines
(#l("if(runout != 0 && (p->p_flag&SLOAD) == 0) {")). The routine `setrun` does not swap the process in itself. If
the swapper is waiting for a runnable process which is out of RAM, and
this process is one, `setrun` wakes it, and `sched` swaps the process
in. The channel here is `&runout`. Any address can be a channel, and
the swapper's flag doubles as the address it sleeps on.

#lines-to("if(p->p_pri < curpri)")

The variable `curpri` (#f("main.c")) holds the priority of the running
process. The routine `swtch` sets it when it chooses a process
(#l("curpri = n;")), and `trap` sets it on each return to user mode
(#at("/usr/sys/sys/trap.c", "curpri = setpri(u.u_procp);", after: "trap(int *r)")). If the process just made runnable is more urgent
(#l("if(p->p_pri < curpri)")), `setrun` sets the flag `runrun`. A flag does nothing by
itself. It is tested on the way back to user mode, either from a system
call or fault, in `trap` (#at("/usr/sys/sys/trap.c", "if (runrun)", after: "trap(int *r)")), or from an interrupt, in
`irq_entry` (#at("/usr/sys/conf/low.s", "ldr r0, =runrun")). Where it is set, the current process
gives up the processor through `qswtch`. A process in the kernel is
never preempted, so the switch waits until it is about to return to
user mode.

#lines-to("/*", lead: true)

_Priorities._ The routine `setpri` computes the priority of a process
running in user mode. It is called by `trap` on every return to user
mode, and once a second by `clock` for every process
(#at("/usr/sys/sys/clock.c", "setpri(pp);")). The priority is `PUSER` (#f("param.h")), plus a share of
recent processor use (`p_cpu`, which `clock` increments each tick,
#at("/usr/sys/sys/clock.c", "if(++pp->p_cpu == 0)"), and decays each second, #at("/usr/sys/sys/clock.c", "pp->p_cpu = a;")), plus the
bias `p_nice` (#at("/usr/sys/h/proc.h", "char\tp_nice;")). It is capped so that it is never more
than 127, and so fits in the `char` `p_pri` (#at("/usr/sys/h/proc.h", "char\tp_pri;")). A process which has used the
processor much thus becomes less urgent, and `swtch` prefers the
others.

The routine `setpri` also sets `runrun` when the priority it has
computed is more urgent than `curpri` (#l("if(p < curpri)")). Since `clock` calls
it once a second for every process, a process which has become more
urgent than the running one causes a switch.

#lines-to("/*", lead: true, after: "}")

_Swapping._ Process 0 spends the rest of its life in `sched`, the
swapper. The routine `main` calls it last (#at("/usr/sys/sys/main.c", "sched();")), once it has made
process 1, because `sched` never returns. The swapper brings runnable
processes in from the swap area, and swaps other processes out only
when RAM is short. With 512~MB of RAM that never happens here in
practice, and `sched` sleeps. The comment's "once per second" is
`clock`, which wakes the swapper each second if it is waiting
(#at("/usr/sys/sys/clock.c", "if(runin!=0) {")).

#lines-to("loop:")

Of the runnable processes on the swap area, `sched` picks the one which
has been out longest. Each unit of `p_nice` counts as eight seconds
less waiting, so a process which has been niced waits longer to come
back in. The starting value, -20000 (#l("outage = -20000;")), is lower than any process
can score, and so marks that none was found.

#lines-to("/*", after: "outage = -20000;")

If there is none, `sched` sleeps on `runout` (#l("sleep((caddr_t)&runout, PSWP);")), to be woken by
`setrun` or by `xswap` (#f("text.c")).

#lines-to("/*", after: "if (outage == -20000) {")

The routine `swapin` brings the process in if RAM has room for it.

#lines-to("/*", after: "if (swapin(p))")

If RAM has no room (#l("if (swapin(p))")), `sched` looks for a process to swap out
in its place. It prefers the largest process which is sleeping at a
priority that a signal could break, or which is stopped by tracing
(#l("if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) ||")). Failing that, it takes the process which has been in RAM
longest, counting `p_nice` once more. It passes over a process whose
image no hole of the swap map would hold (#l("if (!swapfits(rp->p_size))")), since an image
goes to the swap area in one piece. With images of hundreds of
megabytes, small ones left between them can cut the free swap into
holes too short for any, and v7, whose images were at most 64~KB,
panicked in `xswap` instead.

#lines-to("/*", after: "inage = rp->p_time+rp->p_nice-NZERO;")

A process taken under the second rule
is swapped out only if the process waiting to come in has been out for
3 seconds and the process to go out has been in for 2
(#l("if (maxsize>=0 || (outage>=3 && inage>=2)) {")). These waits keep a process which has just come in from
being swapped out again at once.#footnote[The same two thresholds are
already in the Fifth Edition's `sched` (1974), as
`if(n < 3) goto sloop;` and `if(n < 2) goto sloop;`, and in the Sixth (1975). The
Seventh (1979) rewrote the test as it stands here. Berkeley's 3BSD
(1979), which added paging, replaced them by 5 and 5 in its
`vmsched.c`, with the remark that these "are not really times but
priorities". Sources at
#link("https://www.tuhs.org/cgi-bin/utree.pl?file=V5/usr/sys/ken/slp.c")[`tuhs.org`].]
Otherwise `sched` sleeps on `runin`. It is woken by `clock` each
second, by `sleep` when a process goes to sleep and so may become a
candidate (#l("if(runin != 0) {")), and by `pgfree` (#f("malloc.c")) when RAM is
freed.

#lines-to("/*", lead: true, after: "sleep((caddr_t)&runin, PSWP);")

The routine `swapfits` says whether one hole of the swap map holds an
image of `n` pages.

#lines-to("/*", lead: true, after: "swapfits(int n)")

The routine `roomfor` says whether the current process may grow to
`newsize` pages, with `tn` pages of text to bring in as well. Either
the free core holds the growth (#l("if (mapneed(n-USIZE, newsize-USIZE) + tn <= npgfree)")), or the image can be
swapped out to make room (#l("return(swapfits(newsize));")). The callers of `expand`, `sbreak`
and `getxfile` (#f("sys1.c")) and `grow` (#f("sig.c")), ask it first and fail
when it says no, so that the swap which `expand` falls back on always
finds its hole.

#lines-to("/*", lead: true, after: "roomfor(int newsize, int tn)")

The routine `imgpage` gives the page at index `i` of the image of a process in
RAM: the u-area's at `p_addr`, then those which its map lists. The
routines which go through an image page by page use it, so that the
u-area needs no entry in the map.

#lines-to("/*", lead: true, after: "imgpage(register struct proc *p, int i)")

The routine `swapin` is called by `sched` (#l("if (swapin(p))")) to bring the chosen
process into RAM. It locks the text first, since whether the text
needs RAM depends on its count of users in RAM, `x_ccount`, which the
lock holds steady. It then counts every page the process will take,
and its text too if no user of the text is in RAM, the pages of their
maps included (#l("need = USIZE + mapneed(0, p->p_size-USIZE);")--#l("need += mapneed(0, xp->x_size);")), and gives up if fewer are free. All the
pages are taken before anything is read, because each read sleeps, and
another process could take pages meanwhile.#footnote[The Sixth Edition's `swapin`
(1975) allocated text and data as one piece. The Seventh split them,
with a comment asking that the larger be taken first, for the first
fit rule of `malloc`. In 32V (1979), the VAX port, memory is allocated
page by page (`memall`), as here, and the order no longer matters.
Sources at #link("https://www.tuhs.org/cgi-bin/utree.pl?file=V6/usr/sys/ken/slp.c")[`tuhs.org`].]

#lines-to("if (xp) {", after: "need += mapneed(0, xp->x_size);")

The text is read in only if no process using it is in RAM
(#l("if (xp->x_ccount==0) {")), by `xread` (#f("text.c")), which also makes instruction
fetch see the new instructions.

#lines-to("a = p->p_addr;", after: "xunlock(xp);")

Last the image is read in, the u-area into its new page and the rest
into the pages of the new map, a run of consecutive pages at a time
(`mapswap`, #f("bio.c")). Its swap space is freed, and the process is
marked as in RAM, with `p_time` reset, so that `sched` does not choose
it to go out again at once.

#lines-to("/*", lead: true, after: "}")

_Preemption._ The routine `qswtch` gives up the processor without
sleeping. It puts the current process back on the run queue and calls
`swtch`, so that the process, which is still runnable, can be chosen
again later. A process which merely must give way cannot call `sleep`,
since it waits for nothing. Three routines call `qswtch`. The routine
`trap` calls it on the way back to user mode when `runrun` is set
(#at("/usr/sys/sys/trap.c", "qswtch();", after: "trap(int *r)")), which is how a process gives way to a more urgent
one. And `expand` (#l("qswtch();")) and `xexpand` (#at("/usr/sys/sys/text.c", "qswtch();")) call
it after writing the process to the swap area, so that it is brought
back in.

#lines-to("/*", lead: true, after: "}")

_Switching._ The routine `swtch` chooses the next process to run and
runs it. In general three processes take part. The process giving up
the processor resumes process 0, and process 0 chooses the next process
and resumes it (see _Saved State_, page #pageref(<sec-saved>), for the labels
involved).

#lines-to("if (u.u_procp != &proc[0]) {")

Unless the caller is process 0 itself, its state is saved in
`u.u_rsav` and process 0 is resumed at `u.u_qsav`. The zero return from
`save` (#l("if (save(u.u_rsav)) {")) continues on the second branch. The nonzero return comes
much later, when this process is chosen again, and then `sureg`
re-establishes its user mappings before `swtch` returns to its caller.

Before process 0 runs, and through it another process, the floating
point registers are stored in the u-area unless that has already been
done since this process entered the kernel (#f("user.h")). The kernel
itself never touches them, so they still hold this process's values.
The next process to return to user mode loads its own.

#lines-to("/*")

Process 0's `u_qsav` marks the entrance to the search loop
(#l("if (save(u.u_qsav)==0 && save(u.u_rsav))")), and every switch passes through it by the `resume`
at #l("resume(proc[0].p_addr, u.u_qsav);").

#lines-to("intr_disable();")

With interrupts masked, `swtch` searches the run queue for the loaded
runnable process of best (lowest) priority and removes it from the
queue. If there is none, `idle` (#f("mch.s")) waits for an interrupt,
and the search starts again.

#lines-to("/*", after: "curpri = n;")

`swtch` resumes the incoming process at `u.u_rsav`, or at `u.u_ssav`
if it has `SSWAP` set (#l("n = p->p_flag&SSWAP;")). `newproc` (#l("rpp->p_flag |= SSWAP;")), `expand` (#l("p->p_flag |= SSWAP;")), and `xexpand` (#f("text.c"))
set the flag. Each of them made an image of a process, on the swap
area or in fresh RAM, after doing `save(u.u_ssav)`. In such an image `u.u_rsav` is stale:
it was recorded by some earlier switch, or, in `expand`'s case, by the
call of `swtch` from `qswtch` (#l("qswtch();")), after the image had already been
written. Hence `swtch` chooses the label itself.

`resume` masks interrupts while it changes the mapping and the
registers, and unmasks them with `intr_enable` once the new stack is
in place (#f("mch.s")).

The v7 code called `spl0` here, before `resume`, after `curpri` was set. The call
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

_Process Creation._ The routine `newproc` is the body of `fork`, and of the creation of process 1 by
`main`. It returns 1 in the new process and 0 in the old.

#lines-to("retry:")

`newproc` chooses a process id which is in use neither as a process id
nor as a process group, cycling below 30000. At the same time it notes
the first empty slot of `proc`. The system call `fork` (#f("sys1.c")) has already made
sure that one exists.

#lines-to("rip = u.u_procp;")

`newproc` fills in the new entry and increments the reference counts
of the open files, the text, and the current and root directories,
which the child shares with its parent.

#lines-to("/*", after: "u.u_rdir->i_count++;")

The child's image is a copy of the parent's, `u` included, made after
the parent has done `save(u.u_ssav)` (#l("if (save(u.u_ssav)) {", after: "* here's where it will resume.")). Before the copy,
`newproc` sets `u.u_procp` to the child's entry (#l("u.u_procp = rpp;")), so that the copy differs
from the original in that one respect. The parent then restores it (#l("u.u_procp = rip;")) and
loads its own page tables again (#l("sureg();", after: "u.u_procp = rip;")), since the copy may have left the
processor on tables in the child's slot.

`newproc` stores the floating point registers in the parent's u-area just
before the copy (#l("if (u.u_fpsaved==0) {", after: "rpp->p_size = n;")--#l("}", after: "rpp->p_size = n;")), so that the copy holds them, with `u_fpsaved` set,
and the child loads them on its first return to user mode
(#f("trap.c")), whichever process has used the unit since. The v7 code did not
store them here, and its child took whatever the registers held when it
first ran, usually, but not always, its parent's values.

When the child is first chosen by `swtch` its `SSWAP` flag (#l("rpp->p_flag |= SSWAP;")) causes
it to be resumed at `u.u_ssav`. Its `save` returns 1, and `newproc`
returns 1 to `fork`. The child's kernel stack, being part of `u`, is
copied with the rest, and since `u` always appears at the same virtual
address the stack pointer in the label remains valid. The child has no
page tables yet, since `exit` or `xswap` released those of the slot's
previous occupant. The `sureg` which follows its `save` builds them
(#f("ureg.c")).

A word on C. The compiler does not know that `save` may return twice,
since it is declared as an ordinary function. This is safe because, in
every use in this file, the second return reads no local variable: it
calls `sureg` and returns a constant. The registers which the callers
higher up the stack expect to find preserved were pushed on that stack
before `save` was reached, and are still there when it returns again.

#lines-to("rpp->p_addr = a2 = pgalloc();")

The child gets a u-area page and a map of its own (#l("rpp->p_addr = a2 = pgalloc();")--#l("mapalloc(&rpp->p_map, 0, n-USIZE);")),
from the RAM which `fork` has found free (#f("sys1.c")). Nothing between
that test and the copy sleeps, so no other process can take the pages
meanwhile. When the RAM was short, v7's `newproc` wrote the parent's
image to the swap area as the child's. Here `fork` fails instead, and
`xswap` has lost the flag which kept the parent's RAM for that
(#f("text.c")). Then `copyseg` (#f("machdep.c")) copies the image a page at
a time, into pages which need not follow one another. On the PDP-11 `copyseg` had to borrow a user segmentation
register to reach physical memory. Here the kernel maps all of RAM,
and `PGADDR` turns a page number into an address.

The copy takes the whole image, the per process area, the data, and the
stack, which is no more than the program has asked for (`getxfile`,
#f("sys1.c")). A small program's image is a few pages.

#lines-to("/*", lead: true, after: "return(0);")

_Growth._ The routine `expand` changes the size of the current process's image to `newsize`
pages, and since the image is a list of pages, it never copies. A shrinking image gives back the pages at its end
(#l("mapfree(&p->p_map, newsize-USIZE, n-USIZE);")). A growing one gets new pages at its end (#l("if(mapalloc(&p->p_map, n-USIZE, newsize-USIZE)) {")),
and everything the image held stays in its pages. Where the new pages
belong, after the data or below the stack, the caller arranges by
turning map entries around, and it then builds the page tables again
(`sbreak`, #f("sys1.c"), `grow`, #f("sig.c")). In v7 a growing image was
copied whole into a larger area, and a process which grew a page at a
time was copied each time.

If there is no RAM, `xswap` writes the image to the swap area at its
old size `n`, with `p_size` already set to the new one, and frees the
old RAM, and the process gives up the processor with `SSWAP` set.
`expand` first stores the floating point registers in the u-area (#l("if (u.u_fpsaved==0) {", after: "if(mapalloc(&p->p_map, n-USIZE, newsize-USIZE)) {")--#l("u.u_fpsaved = 1;", after: "if(mapalloc(&p->p_map, n-USIZE, newsize-USIZE)) {")),
since the copy on the swap area is the one which will come back, and
`swtch` would store them only after it had been written. v7 omitted
this. When
`sched` brings it back, `swapin` allocates the larger size, and the
process resumes at `u.u_ssav` (#l("if (save(u.u_ssav)) {", after: "if(mapalloc(&p->p_map, n-USIZE, newsize-USIZE)) {")) and returns from `expand` as if
nothing had happened. Until `swtch` resumes another process, the
process goes on running in RAM which is already free. Nothing can
reallocate it in that interval, since no interrupt routine allocates
RAM.

#lines-to(none)
