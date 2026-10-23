#set page(width: 6in, height: 9in, margin: (x: 0.75in, y: 50pt), header-ascent: 18pt)
#set text(size: 10pt)
#import "defs.typ": *
#set page(numbering: "1", header: running, footer: opening-foot)
#set raw(tab-size: 8)
#show heading: set block(below: 1em)
#show heading.where(level: 1): it => { pagebreak(weak: true); v(1fr); align(center, text(size: 1.6em, it.body)); v(2fr); pagebreak(weak: true) }
#show heading.where(level: 2): it => { pagebreak(weak: true); it }
#set heading(numbering: (..n) => { let p = n.pos(); if p.len() == 2 { str(p.at(1)) } })
#show heading.where(level: 1): set heading(numbering: none)
#show heading.where(level: 3): set heading(numbering: none)
#show raw.where(block: true): set text(size: 6.8pt)

#align(center)[
  #v(4cm)
  #text(size: 24pt, weight: "bold")[#text(size: 22pt)[UNIX]#text(size: 14pt, weight: "regular", baseline: -0.45em)[#sym.dagger] Level Seven]
  #v(0.5em)
  #text(size: 16pt)[Source Code and Commentary]
  #v(2em)
  #text(size: 12pt)[Jakob Kastelic]
  #v(3cm)
]

Unix, the greatest operating system ever created, served tens of thousands of
users with a kernel that fit in under 100 kB of core. This book presents
the Seventh Edition system---its kernel, shell, library, and commands---brought
up to date with C99 to run on hardware available nowadays.

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
#show outline.entry.where(level: 2): set block(above: 1.4em)
#show outline.entry.where(level: 2): set text(weight: "bold")
#block(below: 1.2em, text(size: 1.4em, weight: "bold")[Contents])
#show outline.entry.where(level: 2): it => pad(left: -1.2em, it)
#show outline.entry.where(level: 3): it => pad(left: -1.2em, it)
#columns(2, outline(title: none))
#pagebreak()

#include "intro.typ"

= Part One: The Kernel

#include "startup.typ"

== Entering the Kernel <ch-entering>

#source("/usr/sys/h/callo.h")

The callout table holds requests of the form "call `c_func(c_arg)` after
so many clock ticks". It is kept sorted by time, and each `c_time` is
the delay relative to the entry before it, so that the clock interrupt
need only decrement the first non-zero entry (`clock`, #f("clock.c")). An
entry with a null `c_func` ends the list. In this system its only user
is the QEMU machine's console driver, which calls `timeout` to have
`ttrstrt` resume output after a delay (#f("pl011.c")).

The only change is the type of `c_func` (#l("void\t(*c_func)(caddr_t arg);\t/* routine */")). In v7 it was an `int`
function of unspecified arguments. Now it is declared as a `void`
function of one `caddr_t`, which is how `clock` calls it and what
`timeout` accepts, so that every routine placed in the table must have
exactly that type. The timeout routine `ttrstrt` (#f("tty.c")) was changed to take a `caddr_t`
for this reason.

The last line, in v7, defined the table itself, after the v7 manner,
in every file which included the header. It is now only declared, `extern` and without a size: the size, `NCALL`, is part of the
configuration (#f("param.h")), and the table is defined with it in
#f("qemu/c.c").

#lines-to(none)
#source("/usr/sys/sys/clock.c")

The file #f("clock.c") contains `clock`, the handler of the clock interrupt,
`timeout`, by which other parts of the system ask to be called back
later, and, new in this port, `addupc`, the profiling routine.

The profiling routine `addupc`, which `clock` calls before its definition at the end of the
file, is declared in #f("systm.h"), since `trap` (#f("trap.c")) calls
it too. In v7 it was an assembly routine in `mch.s`.

`SCHMAG` (#l("#define\tSCHMAG\t8/10")) is a fraction written as a bare macro: since `x*SCHMAG`
expands to `x*8/10`, the multiplication is done first and the result is
the integer 0.8`x`. It sets how fast the record of recent processor use
decays (#l("a = pp->p_cpu*SCHMAG + pp->p_nice - NZERO;")).

#lines-to("/*")

On the PDP-11 `clock` was entered from the assembler routine `call`, and
its parameters were the device number, the stack pointer, `r1`, the new
PS, `r0`, and the `pc` and `ps` of the interrupted program, words which
the hardware and `call` had left on the stack. Only the last two were
used. The caller is now `irq` (#f("machdep.c")), an ordinary C
procedure, which passes every handler in `intrtab` (#f("conf.h")) only the interrupted
`pc` and, for `ps`, the interrupted program's status register, whose mode field
`USERMODE` tests (#f("param.h")).

Sixty times a second (`HZ`), `clock` runs with interrupts masked, and must
therefore be brief. The second function in the comment's list has
lost its code.

#lines-to("/*", after: "extern caddr_t waitloc;")

On the PDP-11, v7 restarted the KW11-L line clock by writing 0115 to its status
register (`lks`), and on the larger PDP-11s then copied the console
switch register to the display lights (`display`). There are no
lights, and the `display register` comment has gone with the call.

The ARM generic timer interrupts when its counter reaches the value in
the compare register `CNTV_CVAL`, and the port restarts it, under v7's
comment, by giving it the next such value (#f("mch.s")). The variable `clkcval` holds
the deadline of the tick just taken, and the next is `clkreload`
counts later, the counter frequency divided by `HZ` (#f("machdep.c")).
Since each deadline follows from the last and not from the moment the
interrupt was taken, the time spent reaching `clock` never accumulates.
Nor is the remainder of that division lost: the frequency is not in
general a multiple of `HZ` (the QEMU machine's 62.5 MHz leaves 40
over), so
`clkrem` is gathered in `clkfrac`, and each time a whole `HZ` has
gathered, one more count is added to the deadline. Over `HZ` ticks the
deadline advances by exactly the frequency, and the clock keeps the
counter's time. Should interrupts have been masked for longer than a
tick, the new deadline is already past, the timer interrupts again at
once, and the tick is made up rather than lost.

#lines-to("/*", after: "cntv_cval_set(clkcval);")

If the callout list is not empty, the first entry whose time
has not yet expired is charged one tick. Entries already at zero are
waiting to be called, which happens next.

#lines-to("/*", lead: true, after: "p2->c_time--;")

At this point v7 went on to ask, with `BASEPRI(ps)`, whether the interrupted program
had been running at a raised processor priority, and if so put off the
calling of callouts, and the once-per-second work below, until a later
tick, so as not to run them inside some other, half-finished, interrupt
routine. The second test followed `++lbolt` below. Both tests have
gone. The clock interrupt can only be taken when the IRQ is unmasked,
which is the state that `intr_enable` gives, the ARM equivalent of
priority zero, so a clock tick never interrupts a routine which has
masked it with `intr_disable`, nor a device interrupt routine, and the
tests were always false. The names are FreeBSD's (#f("mch.s")): with
one mask bit, v7's `spl0` and `spl1` are both `intr_enable`, its
`spl5`, `spl6`, and `spl7` are all `intr_disable`, and `splx` is
`intr_restore`.

#lines-to("intr_disable();")

Every expired callout is called, in order, with its argument,
and the remainder of the list is then moved down to the front of the
table. The `spl5` which v7 called here was meant to lower the PDP-11 priority from 6
to 5, admitting other clock-level work. On the ARM the IRQ is already
masked and `intr_disable` changes nothing. The doubled parentheses at #l("while((p2->c_func = p1->c_func)) {") are those of
#f("malloc.c").

#lines-to("/*")

Every tick reaches `out`. The tick is charged to the current
process as user or system time. If the process is being profiled
(`pr_scale` non-zero), its histogram is incremented at the interrupted
`pc` by `addupc`. The field `u_prof` has been given the
structure tag `uprof` (#f("user.h")) so that `addupc` can be declared to
take a pointer to it.

The statistics for `iostat` are gathered in `dk_time` (#l("dk_time[a] = (unsigned long)dk_time[a] + 1;")): `a` is formed from the
busy bits of up to three disks (`dk_busy`, which the block drivers set
and clear), plus 8 for a user process of lowered priority, 16 for system
time, and another 8 if the processor was idle. The test for idleness is
that the interrupted `pc` is `waitloc`, the address just after the `wfi`
in `idle` (#f("mch.s")). The count is incremented as an `unsigned long`
and converted back: at 60 ticks a second a `long` overflows after about
13 months, which C99 leaves undefined, while the unsigned sum wraps.

The recent use of the processor, `p_cpu` (#l("if(++pp->p_cpu == 0)")), is incremented but not
allowed to wrap round to zero.

#lines-to("if(++lbolt >= HZ) {")

Once a second, when `lbolt` reaches `HZ`, the system's slower duties are
done: `time` is advanced, everyone waiting on `lbolt` is woken, and for
every process the time in its present state (`p_time`, used by `sched`
in #f("slp.c")) is incremented, an `alarm` (`p_clktim`) is counted down
and fires `SIGCLK` when it expires, and `p_cpu` is decayed by the factor
0.8, with the `nice` bias added. User processes have their priorities
recomputed by `setpri`. Finally `sched`, if waiting on `runin`, is
roused.

Next `runrun` is set (#l("runrun++;")), so that the current process gives up the
processor at its next return to user mode. This is what makes the
priorities just recomputed take effect against a process which computes
without pause and so never sleeps.

The call of `intr_enable` (#l("intr_enable();")), v7's `spl1`, unmasks the IRQ. On the PDP-11 it let other interrupts in
while the loop over `proc` was done. Here it does not: the interrupt
controller delivers no further interrupt until `irq` writes the end of
interrupt, after `clock` returns. Only then can one nest
(#f("machdep.c")). The decay (#l("a = pp->p_cpu*SCHMAG + pp->p_nice - NZERO;")) needs no
mask, since `p_cpu` is an `unsigned char` (#f("proc.h")). v7 masked it
with 0377 to undo the sign extension of a PDP-11 `char`.

#lines-to("/*", lead: true)

A call of `timeout` inserts an entry into the callout list. The list
is walked (#l("while(p1->c_func != 0 && p1->c_time <= t) {")--#l("}", after: "t -= p1->c_time;")), the delay of each earlier entry being subtracted from `t`,
until the place is found where the remainder is less than the next
entry's delay. The next entry's delay loses `t` (#l("p1->c_time -= t;")), since it
will now be counted after the new one. The tail of the list,
including its null terminator, is then moved up one place (#l("p2 = p1;")--#l("}", after: "p2--;")) to make room.

The table must keep one slot for the terminator, hence the comparison
with `NCALL-1` (#l("if (p1 >= &callout[NCALL-1])")). The processor priority is raised to the maximum
for the duration, since `clock` changes the same list.

The type of `fun` is now that of `c_func` (#f("callo.h")).

#lines-to("void", after: "}")

Written in C, `addupc` is new. The v7 version was a PDP-11 assembly routine in `mch.s`,
called, as this one is, from `clock` and from `trap`. Given the program
counter `pc`, a pointer `p` to the profile parameters of `u.u_prof`
(buffer base, buffer size in bytes, offset, and scale), and an
increment `t`, it adds `t` to the 16-bit counter which covers `pc`. The
assembler routine read the four members as an array of words. In C,
reading the `short *` member `pr_base` through an `unsigned *` would
break the aliasing rules of C99, so the members are named.

The index is (`pc` - offset) × scale / 65536 bytes, made even so as to
select a `short`. As in the assembler, both factors are halved first.
But the product of two 32-bit values may need 64 bits, so it is formed
as an `unsigned long long` (#l("i = (((unsigned long long)(((unsigned)pc-p->pr_off)>>1) *")). An odd byte offset is rounded up to
the next counter, as the PDP-11 code did.

#lines-to("if (copyin((caddr_t)p->pr_base+i, (caddr_t)&c, 2) < 0) {")

The counter is read and written with `copyin` and
`copyout`, two bytes at a time, since the user's buffer may be
anywhere. If it cannot be reached, the scale is cleared, which turns
profiling off.

#lines-to(none)
#source("/usr/sys/sys/sys1.c")

The file #f("sys1.c") holds the system calls which make, change, and end processes. They are
`exec` and `exece`, with their helpers `getxfile` and `setregs`, `exit`
(through `rexit`), `wait`, `fork`, and `sbreak`, which changes the size
of the data area. This is the file in which the port's
departures from the PDP-11 are most visible to user programs, because it defines the format of the executable file, the layout of the
arguments on the stack, and the convention by which `fork` tells parent
from child.

The helpers `getxfile` and `setregs` are declared (#l("void\tgetxfile(struct inode *ip, int nargc);"), #l("void\tsetregs(void);")) because they are used
before they are defined (#f("prf.c")).

#lines-to("/*")

The call `exec` is `exece` with no environment. Before anything else, `exece` checks that the
file is executable: `access` checks the permission of the caller, and
(#l("if((ip->i_mode & IFMT) != IFREG ||")--#l("}", after: "u.u_error = EACCES;")) a file must be an ordinary file with at least one of its three
execute bits set, so that the super-user, to whom `access` grants
everything, cannot execute a data file.

The initialisation of `cp` (#l("register char *cp = NULL;")) is new. It quiets the compiler, which
cannot see that `cp` is always set (at #l("cp = bp->b_un.b_addr;", after: "bp = getblk(swapdev, swplo+bno+(nc>>BSHIFT));")) before it is used.

#lines-to("/*", after: "}")

The arguments and environment strings must survive the destruction of
the old image, and are too big for the kernel stack, so they are copied
into a temporary area of `NCARGS` bytes on the swap device, one buffer
at a time (`bawrite` does not wait for the write to finish). The count `na` takes in
all the strings, `ne` those of the environment, and `nc` is the total of
their lengths. The two lists are walked as one: when `argp` runs out,
`envp` takes over.

A fault in reading either list gives `EFAULT`, and too much gives
`E2BIG`, and `bad` then releases the swap area. If the swap area has no
room for the arguments, `exec` fails with `ENOMEM` (#l("if ((bno = malloc(swapmap,(NCARGS+BSIZE-1)/BSIZE)) == 0) {")--#l("}", after: "if ((bno = malloc(swapmap,(NCARGS+BSIZE-1)/BSIZE)) == 0) {")), where v7
panicked. Nothing has been changed yet.

The new stack's size, passed to `getxfile` (#l("getxfile(ip, nc+(na+3)*NBPW);")), takes in the
strings, rounded up to a word, and the `na+3` words of the pointer
vector built below them, which hold the argument count, a pointer to
each string, and two zeros. In v7 only the strings were passed. When the vector did not fit in the
`SSIZE` pages left over, the `suword`s below the stack failed unseen,
and the program began with an argument count of zero. With 4-byte
pointers and a 4 KB `SSIZE`, some 1,360 short arguments would have
been enough.

#lines-to("/*", lead: true, after: "goto bad;")

Once `getxfile` has built the new image, the strings are copied back
from the swap area to the top of the new user stack, and a vector of
pointers to them is built below, in the form which the C start-up
routine expects.

#lines-to("ucp = USRSIZE - nc - NBPW;")

In v7 the strings were placed at `-nc - NBPW` (#l("ucp = USRSIZE - nc - NBPW;")): on the PDP-11 user
addresses were 16 bits, and a negative number named a location below the
top of the 64 KB address space. The ARM user address space is `USRSIZE`, 3 GB,
and the strings now end one word below its top. The stack pointer
(`ap`) is rounded down to a multiple of 8, since the ARM procedure call
standard requires that alignment at every call, and `crt0` calls `main`
without adjusting it.

#lines-to("suword((caddr_t)ap, na-ne);")

The new stack, from `ap` upwards, holds the argument count, the
argument pointers and a zero, the environment pointers and a zero, and
then the strings, followed by a zero word (#l("suword((caddr_t)ucp, 0);")). The `0377` mask at #l("} while(c&0377);")
is v7's. Here `c` is never negative.

#lines-to("setregs();")

Then `setregs` prepares the registers for the new program. At `bad` the
buffer and the swap area are released in every case, success included.

#lines-to("/*", lead: true)

The routine `exread` reads `count` bytes of the executable at offset
`off` into the kernel, for `getxfile`. It returns nonzero if there was
an error or the file ended first.

#lines-to("/*", lead: true, after: "return(u.u_error || u.u_count);")

The routine `getxfile` reads the header of the executable and builds the new image.
Here the port departs furthest from v7. In v7 the kernel accepted only its own
`a.out` formats, distinguished by the magic numbers which its comment
listed. This kernel accepts only ELF files, which is what the cross
compiler produces, and the comment (#l("* read in the ELF header;")--#l("* and the data")) now describes them. The
ELF loader is a deliberate exception to the port's practice of keeping
v7's formats.

#lines-to("if(exread(ip, (caddr_t)&u.u_exdata, sizeof(u.u_exdata), 0)) {")

The start of the file is read into `u.u_exdata`, whose fields are
those of the 52-byte ELF header (#f("user.h")). The read fills the
whole structure, 100 bytes, so a shorter file is refused. The two
program header slots `ph` at its end receive whatever follows the
header, and are overwritten later.

#lines-to("n = 0;")

The search which follows is new. If the file begins with the ELF magic
number, the four bytes `\177ELF` of `e_ident`
(#l("if(u.u_exdata.e_ident[0] == 0177 && u.u_exdata.e_ident[1] == 'E' &&")), the program header table is read at offset
`e_phoff`, one entry of `e_phentsize` bytes at a time
(#l("off = u.u_exdata.e_phoff + u.u_exdata.e_phentsize*i;")). The type
of each entry is read first. An entry of type `PT_LOAD`, a loadable
segment, is then read into `ph[n]`, its first 24 bytes, which hold
every field the kernel uses. The programs are linked so that the first
loadable segment is the text and the second the data (#f("Makefile")).
A file which is not ELF, or which has not exactly two loadable
segments, gives `ENOEXEC`. A third is refused (#l("if(n == 2 || exread(ip, (caddr_t)&u.u_exdata.ph[n],")) rather than
ignored, since the program would run without it. A program linked into
one writable segment, the counterpart of v7's 0407 format, is not
accepted either, since its code would lie in memory which every process
writes privately.

A malformed header is refused here too, before anything of the old
image is given up. Entries smaller than the 24 bytes read
(#l("u.u_exdata.e_phentsize >= sizeof(u.u_exdata.ph[0]))")) would
overlap. A program header which cannot be read whole refuses the file
(#l("n = 0;", after: "if(exread(ip, (caddr_t)&type, sizeof(type), off)) {")), since `ph` could still hold what the program that ran before
left there. A text segment with nothing in the file
(#l("u.u_exdata.ph[0].p_filesz == 0 ||")) would leave `xalloc` (#f("text.c")) nothing to read. A data segment with more bytes in
the file than in memory (#l("u.u_exdata.ph[1].p_filesz > u.u_exdata.ph[1].p_memsz) {")) would be read past the end of the space
reserved for it.

#lines-to("if(u.u_exdata.ph[0].p_filesz!=0 && (ip->i_flag&ITEXT)==0 &&")

A program with a text may not be executed
while some process has the file open, unless that is because it is
already running as a shared text (`ITEXT`), since the writer could
change the text under the processes which share it. The counterpart,
that a running text cannot be opened for writing, is in `access`
(#f("fio.c")).

#lines-to("/*")

Each segment is placed at its own address. The text begins at the page
holding its first address, `t0`
(#l("t0 = u.u_exdata.ph[0].p_vaddr >> PGSHIFT;")), and `ts` counts
the pages from there to the end of its bytes in the file. The data
begins at its own page, `d0`, and `ds` reaches to the end of the segment
in memory, its address plus `p_memsz`, which takes in the uninitialised
data as v7's sum of `ux_dsize` and `ux_bsize` did. A segment whose end
wraps around, which makes the unsigned sum smaller than the size, or
lies beyond the user's space is refused with `ENOMEM`
(#l("if(end < u.u_exdata.ph[0].p_filesz || end > USRSIZE)")). The
stack is given `SSIZE` pages plus room for the strings and the pointer
vector, `nargc` bytes. Then `estabur` (#f("ureg.c")) refuses segments
which overlap each other, the stack, or the signal trampoline.

In v7 the text began at address zero and the data followed it. The
programs here are linked at 0x8000 (#f("Makefile")), so nothing is
mapped below that, and a null pointer faults.

#lines-to("/*", after: "return;")

With the profiling turned off (#l("u.u_prof.pr_scale = 0;")) the old image is abandoned. As in v7, the image is
expanded to `USIZE+ds+ss` pages, its per process area and the sizes
just computed, and everything beyond the per process area is cleared
(#l("i = USIZE+ds+ss;"), #l("while(--i >= USIZE)"), #l("clearseg(u.u_procp->p_addr+i);")). The uninitialised data and the stack therefore read as
zero. The image is no larger than the program: `sbreak` and the growth
of the stack (`grow`, #f("sig.c")) enlarge it when the program asks for
more, and `fork` copies only what there is (#f("slp.c")).

#lines-to("/*", lead: true, after: "xalloc(ip);")

By now `xalloc` (#f("text.c")) has attached the text, shared with any other
process running the same file, or read it in. The data segment is now
read from the file into user space at its own address, from its file
offset, for `p_filesz` bytes, the size of the segment in the file
(#l("estabur(t0, ts, d0, ds, (unsigned)0, RO);")--#l("readi(ip);", after: "u.u_count = u.u_exdata.ph[1].p_filesz;")). In v7 the data was mapped at address zero for the purpose, and
read from just after the text in the file. Here the final mapping of
text and data serves.

#lines-to("/*", after: "readi(ip);")

The set-user-id and set-group-id bits take effect unless
the process is being traced, in which case it is stopped with `SIGTRC`
instead, so that the tracing parent can examine the new image.

#lines-to("u.u_tsize = ts;")

The sizes are recorded and the user mapping set by
`estabur`. The instructions of the new program were made visible to
instruction fetch by `xalloc` (#f("text.c")), which read them in. A segment out of range ends at `nomem`
(#l("nomem:")) with `ENOMEM`.

#lines-to("/*", lead: true)

First, `setregs` resets to the default the signals that were caught
(#l("for(rp = &u.u_signal[0]; rp < &u.u_signal[NSIG]; rp++)")--#l("*rp = 0;")), since the handlers no longer exist. Signals that were ignored
(value 1) stay ignored. Then the registers are cleared (#l("for(i = 0; i < PC; i++)")--#l("u.u_ar0[i] = 0;")). In v7 the kernel
cleared those which `regloc` names as `r0` to `r5`: on the PDP-11 every
general register but the stack pointer `r6` and the `pc` `r7`. The port
clears every general register of the ARM in the same way, `r0` to `r12`
and `lr`, all but the stack pointer, which is already set for the new
program, and the `pc`, which is set next. The new program inherits
nothing from the old. When the call returns, `trap` (#f("trap.c"))
puts `u.u_r.r_val1` and `u.u_r.r_val2` in `r0` and `r1`. The first is
zero, but the second is the caller's `r1`, the old program's argument
pointer, so it is cleared too (#l("u.u_r.r_val2 = 0;")). The `pc` is set to the entry point
with bit 0 cleared (#l("u.u_ar0[PC] = u.u_exdata.e_entry & ~01;", after: "u.u_r.r_val2 = 0;")). On the PDP-11 this ensured an even address. On the
ARM bit 0 of an entry point would select Thumb state, in which no
program here begins.

#lines-to("for(rp = (int *)&u.u_fps; rp < (int *)&u.u_fps.u_fpregs[32];)")

The floating point save area is cleared (#l("for(rp = (int *)&u.u_fps; rp < (int *)&u.u_fps.u_fpregs[32];)"), #l("*rp++ = 0;")): all 32 registers
become zero, and `FPSCR` zero selects rounding to nearest, with no
exception flags. The flag `u_fpsaved` is set (#l("u.u_fpsaved = 1;")), so that the return to user
mode loads the cleared state (#f("trap.c")). In v7 it was set only if
`exec` had happened to sleep, so that `swtch` stored the registers.
Otherwise the cleared area was never loaded, and the new program began
with the old one's floating point registers. Files marked close-on-exec are
closed, and the last component of the name of the file (left in
`u.u_dbuf` by `namei`) is kept for accounting.

#lines-to("/*", lead: true, after: "bcopy((caddr_t)u.u_dbuf, (caddr_t)u.u_comm, DIRSIZ);")

The system call is `rexit`. The kernel also calls `exit`, from
`psig` and `stop` (#f("sig.c")), with a signal number. The user's code
goes in the high byte of the status and the signal in the low, as
`wait` reports them.

The system call `exit` gives up everything the process holds: signals are all set to be
ignored, so that nothing can interrupt the exit. Files, current and root
directories, text, page tables (#f("ureg.c")), and finally core are
released. After `mfree` (#l("mfree(coremap, p->p_size, p->p_addr);")) the process goes on running on the stack within the
per-process area it has just freed. As in `expand` (#f("slp.c")), this is
safe because nothing can allocate core before `swtch` has chosen
another process.

The process becomes a zombie. Its `proc` entry keeps the exit status
and the times in `p_xstat`, `p_utime`, and `p_stime` (#f("proc.h")),
which are all that the parent will need. V7 overlaid a separate
`xproc` structure on the entry instead, which worked only while
`xproc` was no larger than `proc`. Children are handed to `init` (process 1),
which is woken in case it is waiting. Stopped children are set running
so that they can die. Finally the parent is woken, and `swtch` is
called, never to return.

#lines-to("/*", lead: true, after: "/* no return */")

A call of `wait` looks for a child which is a zombie. If it finds one, it
collects the status and times, frees the `proc` entry, and returns the
child's pid and status. A stopped, traced child is reported once, with
the signal which stopped it and the low byte 0177. If there are children
but none is ready, the parent sleeps on its own `proc` entry, which
`exit` (#l("wakeup((caddr_t)q);")) and `stop` wake, and looks again. If there are none,
`ECHILD`.

#lines-to("/*", lead: true, after: "}")

First, `fork` checks that the swap area could hold the caller's image (#l("if ((a = malloc(swapmap, ptod(u.u_procp->p_size))) == 0) {")),
finds a free `proc` entry, and counts the caller's processes. In v7 the kernel
checked for room for an image of the maximum size, `MAXMEM`, as
insurance against running out of swap space later, which is fatal
(#f("text.c")). The insurance did harm: the space must be contiguous, and a small process left on the
swap device between two large ones could leave no hole of `MAXMEM`
pages, after which no process at all could fork. The check made
here is the one `newproc` relies on: the child's image, if it must go
to the swap device, is the size of the caller's. The comment (#l("* Make sure there's enough swap space for the")) is
changed to match. The last slot of `proc` is reserved for the super-user, so that root can
still log in and kill something when the table is full.

In the child `newproc` (#f("slp.c")) returns 1 and in the parent 0, but
the user program must also be told which it is. In v7 this was done with a trick
which the port keeps. In the child `fork` returns the parent's pid
(#l("u.u_r.r_val1 = p1->p_pid;")). In the parent it advances the saved `pc` by one word (#l("u.u_ar0[PC] += NBPW;")), so
that the parent skips the instruction after the `svc`, a branch which
only the child therefore takes. `PC` is v7's `R7`, the `pc`
(#f("reg.h")), and `NBPW` is now four bytes, the size of an ARM
instruction, as it was two, the size of a PDP-11 one. The library stub
(`fork.s`) is built on it as v7's was: the parent returns the child's
pid, or -1 with `errno` set if the call failed, and the child, at the
branch, stores the parent's pid in `par_uid` and returns 0.

In the child, the times are cleared and `AFORK` marks for accounting a
process which has not yet called `exec`.

#lines-to("/*", lead: true, after: "u.u_ar0[PC] += NBPW;")

The routine `sbreak` sets the size of the data area. The new break is
converted to pages, and the data's first page, `u_pdstart`, is
subtracted (#l("n = (int)btop((unsigned)((struct a *)u.u_ap)->nsiz) -")). In v7 the data began at the first segment after the
text, and the text's segments were subtracted. The mapping routine
`estabur` must accept the new size: it refuses a data area that would
run into the stack or the signal trampoline (#f("ureg.c")).

The image is then changed with `expand`. Since the stack lies above the
data in core, it is copied down (shrinking) or up (growing), a page at
a time, by the amount of the change: when shrinking before the image is
cut, so that nothing is lost, and when growing after it is enlarged,
from the top down. The pages added to the data are cleared, so that
the program finds zeros there, as it would in new memory. The shell
relies on none of this: it grows its data only when a store beyond the
break faults (#f("sh/stak.c")), and the memory beyond the break is not
mapped until then.

#lines-to(none)
#source("/usr/sys/sys/sys4.c")

The file #f("sys4.c") collects small system calls concerned with time, user and group
identity, and signals, and a few file operations which fitted nowhere
else. Apart from the dressing of C99 it is v7's,
but for the declaration of `chdirec` (#l("void\tchdirec(struct inode **ipp);")), which `chdir` calls before
its definition, and one fix in `utime`.

Every routine here follows the pattern of a system call: the arguments
are found through `u.u_ap`, overlaid by a local structure `a` which
names them. Results go to `u.u_r`, and errors to `u.u_error`.

The system call `gtime` returns the time in seconds. The field `r_time` is a `time_t` overlaying
the pair `r_val1`, `r_val2`. On the PDP-11 the `long` filled both, and
the time came back in `r0` and `r1`. So it does again, now that a
`time_t` is 64 bits: the low word in `r_val1` and `r0`, the high word
in `r_val2` and `r1`, which is where the ARM returns a `long long` from
a function, so the library's `time` need only store the pair.

#lines-to("/*", after: "}")

The system call `ftime` returns the time with a fraction, reading it from `lbolt`, the count
of ticks within the current second. Interrupts are masked while `time`
and `lbolt` are read together, so that the clock cannot advance one
without the other between the two reads. The test at #l("if (ms > HZ) {") allowed for v7's
`clock`, which could let `lbolt` run past `HZ` when it postponed its
once-a-second work. On the ARM that never happens (#f("clock.c")). The
time zone is the one compiled into the system (#f("param.h")).

The structure returned is described in #f("timeb.h").

The system call `stime` sets the time, for the super-user only. The argument is two
words, as on the PDP-11: the library passes the 64-bit time in `r0` and
`r1`, and `trap` copies both into `u_arg` (see the table in
#f("sysent.c")). The array `u_arg` lies on an eight-byte boundary of `user`, so
the `time_t` of the structure `a` is aligned.

#lines-to("void", lead: true, after: "time = uap->time;")

Each process has a real and an effective user id, and the same for
groups. The calls `setuid` and `setgid` set them, and are permitted if the new id
is the real one, or to the super-user. A set-user-id program may thus
return to its real identity, but not the other way. The calls `getuid` and
`getgid` return the real id in `r0` and the effective in `r1`. The
library entries `geteuid` and `getegid` pick out the second. The call `getpid`
likewise returns the parent's id alongside.

#lines-to("void", lead: true, after: "u.u_r.r_val2 = u.u_procp->p_ppid;")

The call `nice` adds to `p_nice` (#f("proc.h")), the bias to the scheduling
priority which `setpri` (#f("slp.c")) applies. Only the super-user may
make it smaller, and the result is kept within 0 and `2*NZERO-1`. An
increment above `2*NZERO` is first cut to it (#l("n = (n > 2*NZERO? 2*NZERO: n) + u.u_procp->p_nice;")), so that the sum
cannot overflow. In v7 a huge increment wrapped round to a negative
sum, which the clamp then turned into the best priority of all.

#lines-to("/*", lead: true)

The system call `unlink` removes a directory entry. Called with flag 2, `namei` returns the
parent directory, locked, with the entry's inode number in
`u.u_dent.d_ino` and `u.u_offset` just beyond the entry.

#lines-to("if (pp->i_number == u.u_dent.d_ino) {")

If the entry names the directory itself, as `.` does, `iget`
would wait forever for the lock which the caller already holds. The
inode is used directly, with its count raised.

Only the super-user may remove an entry for a directory (#l("if((ip->i_mode&IFMT)==IFDIR && !suser())")), since a
careless unlink can leave the tree inconsistent. An inode on another
device must be a mounted file system's root (#l("if (ip->i_dev != pp->i_dev) {")). If the
file is a shared text in use (#l("if (ip->i_flag&ITEXT)")--#l("}", after: "u.u_error = ETXTBSY;")), `xrele` tries to free it. If it is still
in use and this is its last link, `ETXTBSY`.

The entry is cleared (#l("u.u_offset -= sizeof(struct direct);")--#l("ip->i_flag |= ICHG;", after: "ip->i_nlink--;")) by writing it back with inode number
zero. The inode loses a link, and `iput` frees it if it has none left and is
not open.

#lines-to("void")

Both `chdir` and `chroot` use `chdirec`, which replaces the inode pointed
to by `ipp`. The new directory is unlocked but keeps the reference
which `namei` took (`prele`, #f("pipe.c")). The old one is locked and released.
Only the super-user may change the root.

#lines-to("void", lead: true, after: "iput(ip);")

Both `chmod` and `chown` operate through `owner`, which returns the locked
inode only if the caller owns it or is the super-user. Only the
super-user may set the sticky bit (`ISVTX`, #f("inode.h")), which asks that a
program's text be kept on the swap area after its last user has gone. When it is removed,
`xrele` drops any text which was being kept for the file. Only the
super-user may give a file away (#l("if (!suser() || (ip = owner()) == NULL)")).

#lines-to("void", lead: true, after: "ip->i_gid = uap->gid;")

The system call behind `signal` is `ssig`. It sets the disposition of signal `a`, which is 0 for the default
action, 1 to ignore it, or the address of a handler, and returns the previous disposition. `SIGKIL` cannot be
changed. Any instance of the signal already pending is discarded (#l("u.u_procp->p_sig &= ~(1<<(a-1));")).

A call of `kill` sends a signal to a process, or (pid 0) to every process in the
caller's process group, or, for the super-user only, (pid -1) to every
process. In the last two cases processes 0 and 1, the scheduler and
`init`, are spared (#l("if(a==0 && ((p->p_pgrp!=q->p_pgrp&&priv==0) || p<=&proc[1]))")). An ordinary user may only signal their own
processes.

#lines-to("void", lead: true, after: "u.u_error = ESRCH;")

The system call `times` copies out the four times kept in #f("user.h") (`u_utime`,
`u_stime`, `u_cutime`, `u_cstime`), which are declared together so that
one `copyout` serves. The system call `profil` records the parameters of profiling, which
`clock` and `addupc` (#f("clock.c")) use. The system call `alarm` sets the number of
seconds until `SIGCLK`, which `clock` counts down, and returns the
number that were left.

#lines-to("/*", lead: true, after: "u.u_r.r_val1 = c;")

A call of `pause` sleeps on the address of `u`, on which no one ever calls
`wakeup`. The priority `PSLEP` is above `PZERO`, so a signal ends the
sleep, and `sleep` (#f("slp.c")) then does not return here at all, but
abandons the system call through `u.u_qsav`.

The system call `umask` sets the mask applied to the mode of new files and returns the
old one. The system call `utime` sets the access and modification times of a file,
through `iupdat` (#f("iget.c")), from two times in user memory. `ICHG`
makes `iupdat` stamp the change time with the present. That is the one
time which `utime` cannot set, as its comment says. If the times
cannot be fetched, v7 returned with the inode still locked, and the
next reference to the file, by any process, slept for good. The
`iput` before the return (#l("iput(ip);", after: "if (copyin((caddr_t)uap->tptr, (caddr_t)tv, sizeof(tv))) {")) is new.

#lines-to(none)
#source("/usr/sys/h/timeb.h")

The structure filled in by `ftime` (#f("sys4.c")) holds the time in seconds,
the milliseconds within the second, the local time zone in minutes west
of Greenwich, and a flag saying whether daylight saving time is
observed.

Its size has changed none the less. On the PDP-11 the four members
occupied 4, 2, 2, and 2 bytes, 10 in all. On the ARM a `time_t` is eight
bytes and must lie on an eight-byte boundary, so the compiler pads the
structure to 16 bytes, so that the next one in an array would be
aligned. The kernel
copies out `sizeof(t)` bytes and the library is compiled with the same
header, so the two agree.

#lines-to(none)
#source("/usr/sys/sys/sig.c")

The file #f("sig.c") implements signals, which UNIX of this time called
"software interrupts", and the tracing of one process by another,
which is built on them. A signal is sent by setting a bit in the
receiving process's `p_sig` (`psignal`). Nothing else happens to the
receiver until it next passes through `trap` or `user_trap_handler`
(#f("trap.c")), or wakes from an interruptible `sleep`
(#f("slp.c")). There it asks `issig` whether a signal is pending and, if
so, calls `psig` to take the action. A process thus always acts on a
signal itself, and only on its way back to user mode.

The action, chosen by `u.u_signal[n]` (#f("user.h")), is one of three.
A 0 is the default, which for most signals is to exit, sometimes with
a core image. A 1 ignores the signal. Any other value is the address of
a user procedure, the handler, which `sendsig` (#f("machdep.c")) arranges to be
called as if by an interrupt.

The routines `core` and `procxmt` are declared (#l("int\tcore(void), procxmt(void);")) since they are called before
their definitions.

#lines-to("/*")

The `ipc` structure carries one request at a time from a tracing parent
to its stopped child. The pid of the child being served is held in `ip_lock`,
so that a second parent waits its turn.

#lines-to("/*", lead: true, after: "} ipc;")

The routine `signal` sends a signal to every process of a process group. Its one caller
is the terminal input routine, for the interrupt and quit characters
(#f("tty.c")). Group 0 belongs to no terminal.

#lines-to("/*", lead: true, after: "}")

The routine `psignal` posts the signal. A signal number out of range is ignored,
and so is 0, which posts nothing, and `user_trap_handler` passes 0 when it
only wants the tail of trap processing. A process with a poor priority
is given `PUSER` (#l("if(p->p_pri > PUSER)")), so that it soon runs and sees the signal. If it
is sleeping at a priority above `PZERO` (#l("if(p->p_stat == SSLEEP && p->p_pri > PZERO)")), it is woken, and `sleep`
will abandon the system call. A process sleeping at `PZERO` or
below, typically waiting for a disk transfer, is left alone, and sees
the signal when it returns to user mode.

#lines-to("/*", lead: true, after: "}")

The routine `issig` finds the lowest-numbered pending signal which the process does
not ignore, discarding the ignored ones on the way. A traced process
(`STRC`) stops even for an ignored signal, so that the parent may see
it.

Note the test `u_signal[n]&1` (#l("if((u.u_signal[n]&1) == 0 || (p->p_flag&STRC))")). A handler's address is taken to be
even, and the value 1 the only odd one. This held on the PDP-11, where
instructions lay on word boundaries, and holds here, where the programs
are compiled as ARM code (`-marm`) whose instructions are four-byte
aligned. A function in Thumb code has an odd address, and could not be
used as a handler.

#lines-to("/*", lead: true, after: "}")

The routine `stop` puts a traced process into the `SSTOP` state, wakes its parent,
which may be waiting in `wait` (#f("sys1.c")), and gives up the processor.
When the parent's `ptrace` sets it running, `procxmt` carries out the
parent's request. The loop continues until a request lets the process
go on. If the parent is `init`, because the tracer has died, there is
no one to serve and the process exits.

Now `stop` is `static`: only #f("sig.c") calls it, and so it needs no
prototype in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand of an external function.

#lines-to("/*", lead: true, after: "}")

The routine `psig` takes the action for the signal which `issig` found.

The floating point registers are stored in the u-area first (#l("if (u.u_fpsaved==0) {")--#l("}", after: "u.u_fpsaved = 1;")),
before a debugger, a handler (`sendsig`, #f("machdep.c")), or
a core dump can need them.

#lines-to("if((p=u.u_signal[n]) != 0) {")

If a handler is set (#l("if((p=u.u_signal[n]) != 0) {")--#l("return;", after: "sendsig((caddr_t)p, n);")), it is called through `sendsig`. The
disposition is first reset to the default, so that a second signal
before the handler has re-established itself is fatal. The exceptions are
`SIGINS` and `SIGTRC`, which a debugger or an emulator of missing
instructions would want to catch repeatedly. The error `u.u_error` is cleared,
since a system call interrupted by the signal has already been
abandoned.

#lines-to("switch(n) {")

Otherwise the process exits with the signal number as its
status, and for the signals which indicate a program error, with a core
image as well. The `0200` bit tells `wait` that one was written.

#lines-to("/*", lead: true)

The routine `fsig` returns the number of the lowest pending signal. Signal `n` is
bit `n-1` of `p_sig`.

#lines-to("/*", lead: true, after: "}")

The routine `core` writes a core image to the file `core` in the current directory, first the whole per-process area, `USIZE` pages, which contains the saved registers,
then the user's memory. Before it looks the name up, it gives up unless
the effective user and group ids equal the real ones (#l("if(u.u_uid != u.u_ruid || u.u_gid != u.u_rgid)")), so that a
set-user-id or set-group-id program leaves neither an image nor a file.
In v7 only the user ids were tested, and only after `namei` and `maknode` had
found or made the file, so that a set-user-id program which crashed left
an empty `core` owned by root, of mode 0666 less the user's mask, in any
directory, even one the user could not write, and 32V moved the test first,
as here. The group test matters because the set-group-id programs are
those which read `/dev/kmem` (#f("rootfs.proto")). The file must then be
an ordinary one which the user may write. The comment above admits that
the protection is not thorough.

#lines-to("u.u_base = (caddr_t)ptob(u.u_pdstart);")

The user's memory follows in two writes, the data from its first page
and then the stack below `USRSIZE`, both through the mapping the
process already has, so that `writei` copies them from user space. v7
instead mapped the whole image as data from address zero with `estabur`,
which here would overlap the signal trampoline (#f("seg.h")). The image
holds only what the program has asked for, so a core file is the 4 KB
of the per process area followed by the program's data and its stack, a
few pages for a small program.

In v7 `schar` was declared here. It is now declared in #f("systm.h"),
and the line is deleted.

#lines-to("/*", lead: true)

The routine `grow` extends the stack downward, so that it includes the address
`sp`. A reference below the stack is a fault, and `user_trap_handler`
(#f("trap.c")) and `sendsig` (#f("machdep.c")) call `grow` to enlarge
the stack, moving it in core with `copyseg`. The faulting instruction is
then executed again.

On the PDP-11 the stack lay at the top of the 64 KB address space, so
`-ctob(u.u_ssize)` was the lowest address of the stack as an unsigned
16-bit number, and `-sp` the depth of `sp` below the top. In 32 bits
the top of the address space is `USRSIZE` (#f("param.h")), and the two
expressions become `USRSIZE-ptob(u.u_ssize)` and `USRSIZE-sp`
(#l("if(sp >= USRSIZE-ptob(u.u_ssize))")--#l("si = (USRSIZE-sp)/ptob(1) - u.u_ssize + SINCR;")). The divisor 64, the PDP-11's click in bytes, becomes
`ptob(1)`. The new stack size is the depth of `sp` in
pages, rounded down, plus `SINCR` pages of room, and `estabur` refuses it
if the stack would meet the data. The routine `expand` enlarges the image, and the
stack, which lies at the end of the image, is copied up by the number
of pages added, from the top down so that it does not overwrite
itself, and the pages freed at its bottom are cleared.

#lines-to("/*", lead: true, after: "}")

The parent's side of tracing is `ptrace`. A request of 0 (#l("if (uap->req <= 0) {")) comes from the child, which asks to be traced. Usually it does so between `fork`
and `exec`, so that the `exec` stops it (`getxfile`, #f("sys1.c")).
Otherwise the parent names a stopped child of its own. The request is
placed in `ipc`, the child is set running, and the parent sleeps until
the child has taken it (`ip_req` reaches 0) or refused it (-1). The
answer comes back in `ip_data`.

#lines-to("/*", lead: true, after: "}")

The child's side is `procxmt`, run in the child's context from `stop`,
so that the child's own address space is the one mapped. It returns 1
when the child is to resume, 0 when it is to wait for another request.

Requests 1 and 2 read a word of the child's instruction and data space.
On the ARM the two are one, and `fuiword` is merely another name for
`fuword` (#f("systm.h")).

#lines-to("/* read u */")

Request 3 reads a word of the per-process area, at a byte offset. The
offset is turned into an index of `int`s by `>>2`, where v7 had `>>1`,
since an `int` is now four bytes, not two. The limit `ptob(USIZE)` has
grown with `USIZE` (#f("param.h")).

#lines-to("/* write user I */", lead: true)

Request 4 writes a word into the program's text, to plant a breakpoint
for instance. As in v7, the text must be private: if another process
shares it, or it is sticky, the request fails. The inode loses `ITEXT`,
so that the altered text is never attached by a later `exec`, and the
text is mapped writable for the one store (`RW`, #f("seg.h")) and then
read-only again, and `XWRIT` makes sure the altered text, not the file's,
is what is swapped back in. The doubled parentheses at #l("if ((xp = u.u_procp->p_textp)) {") are those of
#f("malloc.c").

The word is stored through the data cache, and the processor fetches
instructions through its instruction cache, which may still hold the
old word. The call of `arm_sync_icache` (#f("mch.s")) which follows a
successful store is new: it cleans the word's line out of the data cache
and discards the instruction cache, so the planted instruction is the
one executed. It is given the user address, which is mapped, since the
process is the one being traced.

#lines-to("/* write user D */", lead: true)

Request 5 writes a word of data. Request 6 writes a word of the
per-process area, but only in the floating point save area, now 32 registers long
(#l("if (p >= (int *)&u.u_fps &&")), in a saved register named by `regloc`, or in the saved
status register.

The `&0377` (#l("if (p == &u.u_ar0[regloc[i]&0377])")) is new. In v7 the values of `regloc` were negative,
and the PDP-11's signed `char` gave the right index. On the ARM they are
all positive and `char` is unsigned. The mask converts the `char` to an
`int` before it is used as an index, of which the compiler would
otherwise warn, and changes nothing. Only the registers `r0` to `r5`,
the stack pointer, and the `pc` can be written, since `regloc` names no
other.

#lines-to("if (p == &u.u_ar0[PSR]) {")

A new status word must not be allowed to give the child a
privileged mode. In v7 the PDP-11 current and previous mode bits were forced to
"user" by or-ing in 0170000, and cleared the priority bits 5 to 7 on
the next line. Here one line does both: the mode field is set to user
mode, `0x10` (octal 020), and everything else is discarded, the
interrupt masks among them, except the condition flags (bits 27 to 31),
the `GE` flags (16 to 19), and the Thumb state as `sigreturn` keeps it
(#f("machdep.c")): the `T` bit (5), the `E` bit (9), and the `IT` bits
10 to 15, 25, and 26. A debugger may therefore stop a child anywhere in
Thumb code, inside an `if-then` block too, and resume it there.

#lines-to("/* set signal and continue */", lead: true)

Request 7 resumes the child, optionally at a new `pc`, with the
pending signals replaced by the one given (or none). Request 9 of v7,
handled by the same code, also set the PDP-11 trace bit (`TBIT`), so
that the child would trap again after one instruction. The ARM's status
register has no such bit, and single-stepping would need the debug
hardware, so request 9 has been removed, with the comment which
described it: it now reaches `error` like any unknown request, and
`ptrace` (#l("u.u_error = EIO;")) fails with `EIO` rather than letting the child
run on as if it had asked for request 7.

Request 8 makes the child exit. The `return` added after `exit` is
never reached. It keeps the compiler, which does not know that `exit`
does not return, from warning that control falls into the next case.

#lines-to(none)
#source("/usr/sys/h/acct.h")

The record which the kernel appends to the accounting file when a
process exits (`acct`, #f("acct.c")), and which the command `sa`
summarises.

The type `comp_t` (#l("typedef\tunsigned short comp_t;\t/* \"floating pt\": 3 bits base 8 exp, 13 bits fraction */")) packs a time into 16 bits, as a three-bit exponent of 8
and a thirteen-bit mantissa, which reaches some 17,000 million, and `compress` produces it. The user and
system times are in ticks, the elapsed time in seconds, and `ac_btime`, the
time of the `fork`, is a date in seconds.

Though no line has changed, the record has. The terminal, `ac_tty` (#l("dev_t\tac_tty;\t\t\t/* control typewriter */")), is a `dev_t`,
which is now an `int` of four bytes (#f("param.h")), where it was two on
the PDP-11. It is placed on a four-byte boundary. The start time `ac_btime` is a
`time_t`, now eight bytes, which falls on an eight-byte boundary without
padding, and the structure is padded to a multiple of eight. A record is
therefore 40 bytes, not 32.
Since `sa` is compiled with the same header, it reads the records
correctly. Accounting files from a PDP-11 could not be read.

Only declarations of `acctbuf` and `acctp` are here. The definitions are in
the configuration file which `mkconf` generates (#f("qemu/c.c")). The routine `fork` sets `AFORK` and `exec` clears it (#f("sys1.c")), and
`suser` sets `ASU` whenever the super-user's privilege is used.

#lines-to(none)
#source("/usr/sys/sys/acct.c")

The file #f("acct.c") holds process accounting and the unrelated `syslock`. The routine `compress` is
declared (#l("int\tcompress(time_t t);")) because `acct` calls it before its definition.

#lines-to("/*")

The system call `sysacct` turns accounting on, naming the file to which records are to
be appended, or off, given a null name. Only the super-user may do
either. The file must exist and be an ordinary file. Its inode is kept
in `acctp`, with the reference which `namei` took but unlocked
(`prele`), for as long as accounting is on.

#lines-to("/*", lead: true, after: "}")

The routine `exit` (#f("sys1.c")) calls `acct` after the process has closed
its files but while its `u` is still intact, and `acct` writes one record
(#f("acct.h")) at the end of the accounting file. The routine `exec` saved the command name. The user and system times are in ticks, the elapsed
time in seconds. The fields `ac_mem` and `ac_io` are always zero.

The cast at #l("for (i=0; i<(int)sizeof(acctbuf.ac_comm); i++)") is new: `sizeof` yields an unsigned value, and the
compiler warns of a comparison between it and the signed `i`.

#lines-to("siz = ip->i_size;")

If the write fails, perhaps for want of space, the file's
size is set back, so that no partial record remains. The inode is
locked throughout with `plock`, since several processes may be exiting
at once.

#lines-to("/*", lead: true)

The routine `compress` converts a count to the 16-bit `comp_t`. While the value
needs more than thirteen bits, it is divided by 8 and the exponent
raised, and `round` keeps the highest bit shifted out by the last division,
which is the half, so that the result is rounded to the nearest. If the
rounding carries into a fourteenth bit, one more division is needed.

#lines-to("/*", lead: true, after: "}")

The system call `syslock` sets or clears the flag `SULOCK` (#f("proc.h")) for the calling
process, which keeps `sched` (#f("slp.c")) from choosing it to be swapped
out. Only the super-user may use it. The routine `exit` clears the flag.

#lines-to(none)

== Disks and Shared Text <ch-disks>

#source("/usr/sys/h/text.h")

A program whose text is "pure", that is, never written, may be shared by
every process which executes it. One copy is kept in core while any of
those processes is in core, and one copy on the swap device for as long
as any of them exists. The `text` table records each such segment. A
process finds its entry through `p_textp` (#f("proc.h")).

The block number of the swap copy, counted from
`swplo`, is `x_daddr` (#l("/* disk address of segment (relative to swplo) */")). The page number of the core copy is `x_caddr` (#l("int\tx_caddr;\t/* core address, if loaded */")). The count `x_count`
(#l("char\tx_count;\t/* reference count */")) is the number of processes which use the text at all, and
`x_ccount` (#l("char\tx_ccount;\t/* number of loaded references */")) the number of those which are in core: the core copy may
be freed when the second reaches zero, the swap copy only when the first
does.

The fields `x_caddr`, `x_daddr`, and `x_size` have been widened from `short` to
`int`, for the reasons already given for `p_addr` and `p_size` in
#f("proc.h"): neither a page number, nor a block of the swap area
(#f("qemuconf")), nor the size of the largest text fits in a `short`.

The counts `x_count` and `x_ccount` are `char`s. Every process which runs a
program holds a reference to its text, so a count can reach `NPROC`,
150 (#f("param.h")). An unsigned `char`, as the ARM's is, counts to 255.

`XLOAD` (#l("#define\tXLOAD\t04\t\t/* Currently being read from file */")) says that the core copy is being read from the file and has
no counterpart on the swap device yet, and `XWRIT` (#l("#define\tXWRIT\t02\t\t/* Text written into, must swap out */")) that the swap copy
must be written when the core copy is next given up. `XLOCK` and `XWANT`
(#l("#define\tXLOCK\t010\t\t/* Being swapped in or out */"), #l("#define\tXWANT\t020\t\t/* Wanted for swapping */")) are the usual pair: a lock, and a request to be woken when it is
released.

#lines-to(none)
#source("/usr/sys/sys/text.c")

The file #f("text.c") manages the `text` table of #f("text.h"), and holds besides
the one procedure, `xswap`, by which a process image is written to the
swap device.

Every program
has a separate text segment, read-only
and shared by all the processes which run it (#f("sys1.c")), so the
text table is in use as it was on the PDP-11 for 0410 programs: a text
is read from the file once, kept in core while any process using it is
in core, and kept on the swap device while any process uses it at all.

The declaration of three procedures (#l("void\txexpand(struct text *xp), xccdec(struct text *xp),"), #l("xuntext(struct text *xp);")) is new. Each is used in
this file before its definition (#f("prf.c")), and no other file calls them. The procedures which other
files call are declared in #f("systm.h").

#lines-to("/*")

The routine `xswap` writes process `p` to the swap device. The argument `os` is the size of the
image in core. It differs from `p_size` only when `expand` (#f("slp.c"))
swaps out a process whose size has already been increased, in which case
the space allocated on the swap device is for the new size (#l("a = malloc(swapmap, ptod(p->p_size));")) while
only the old size is written (#l("swap(a, p->p_addr, os, B_WRITE);")).

#lines-to("p->p_flag |= SLOCK;")

`SLOCK` (#l("p->p_flag |= SLOCK;")) keeps `sched` from choosing the process as a victim while
the write is in progress. The process's claim on the core copy of
its text is given up (#l("xccdec(p->p_textp);")). If it was the last process in core using that
text, the core copy is freed, having first been written out if `XWRIT`
says the swap copy is stale. The core is freed (#l("if(ff)")) unless `ff` is zero,
which is the case when `newproc` makes the child's image on the swap
device from the parent's core, which the parent goes on using.

Now `p_addr` holds a swap block number and `SLOAD` is cleared, and `p_time`
restarts, since `sched` measures how long a process has been out. If
`sched` is waiting on `runout` for something to bring in, this process
is now such a thing.

The routine `swap` (#f("bio.c")) sleeps until the transfer is complete, so
that `xswap` returns only when the image is safely on the disk.

The page tables are released (#l("ptfree(p);")) after the write, not before it. They
describe the core which the image is leaving, and `sureg`
(#f("ureg.c")) builds new ones when the process is next resumed, from
`p_addr`, wherever `swapin` has put it. A process may be swapping
itself out, from `expand` or `xexpand` or, as the child, from
`newproc` (#f("slp.c")). It then sleeps in `swap`, and when it is
resumed there, `sureg` finds no tables and builds them, still for the
old core. Released before the write, those tables would have survived
it, and the process, brought back elsewhere, would have run with its
pages mapped onto core which belonged by then to other processes.

#lines-to("/*", lead: true)

To detach the current process from its text, `exit` and `exec` call `xfree`.
The lock is taken (#l("xlock(xp);", after: "if((xp=u.u_procp->p_textp) == NULL)")) only to wait for anyone else
working on the entry. It is dropped again at once (#l("xp->x_flag &= ~XLOCK;", after: "if((xp=u.u_procp->p_textp) == NULL)")), without the
wakeup which `xunlock` would give. None is needed: no other process can
have asked for the lock in the moment since `xlock` returned, for this
one has not slept in between.

If this was the last user and the text is not "sticky" (#l("if(--xp->x_count==0 && (ip->i_mode&ISVTX)==0) {")), the entry
is emptied: swap copy and core copy are freed and the inode released.
The test of `ILOCK` (#l("if (ip->i_flag&ILOCK)", after: "if(--xp->x_count==0 && (ip->i_mode&ISVTX)==0) {")) protects a caller's lock: `exec` calls `xfree`
while it holds the lock on the inode of the new program, which may be
this very inode, and `iput` ends by unlocking the inode it is given
(`prele`, #f("iget.c")). If the inode is locked, the count is merely
decremented, and the lock is left to its owner.

A sticky text (mode bit `ISVTX`, #f("inode.h")) keeps its swap copy after
the last user has gone, so that the next `exec` of the same program need
not read the file. In that case, as in the case of other users remaining,
only the in-core count is decremented (#l("xccdec(xp);")).

#lines-to("/*", lead: true, after: "}")

After the new program's header has been
read into `u.u_exdata`, `exec` calls `xalloc`. A program without a text would return at once
(#l("if(u.u_exdata.ph[0].p_filesz == 0)"), #l("return;", after: "if(u.u_exdata.ph[0].p_filesz == 0)")), but `getxfile` refuses such a program before calling
`xalloc` (#f("sys1.c")), so the test is never true.

#lines-to("for (xp = &text[0]; xp < &text[NTEXT]; xp++) {")

The table is searched both for an entry already holding the
text of inode `ip`, and for the first free entry. If the text is found,
the process becomes another user: if no other user is in core, `xexpand` brings the core
copy in from the swap device (#l("xexpand(xp);", after: "xp->x_count++;")).

#lines-to("if((xp=xp1) == NULL) {")

If the table is full, the process is killed.

#lines-to("xp->x_flag = XLOAD|XLOCK;")

Otherwise `xalloc` claims the free entry, setting `XLOAD` to show that
its contents come from the file rather than from the swap device. It
reckons the size `ts` (#l("ts = btop(u.u_exdata.ph[0].p_vaddr + u.u_exdata.ph[0].p_filesz) -")) from the page of the text's first
address, as `getxfile` does, and allocates swap space and core for the text.

#lines-to("for(i = 0; i < ts; i++)")

The core is cleared (#l("for(i = 0; i < ts; i++)"), #l("clearseg(xp->x_caddr+i);")), which v7 did not need: its text filled
the core from the first byte, but here the bottom of the first page
lies below the text's first address, and the last page may extend
beyond its end.

The user mapping is then set up with the text segment only (#l("estabur(u.u_exdata.ph[0].p_vaddr >> PGSHIFT, ts, 0, 0, 0, RW);")),
writable for the moment, and the text is read from the file into it at
its own address. `u_segflg` 2 directs `readi` to instruction space,
which on the ARM is the same as data space. The text is then made visible to instruction fetch (#l("arm_sync_icache(PGADDR(xp->x_caddr), ptob(ts));"),
`arm_sync_icache`, #f("mch.s")), a step the PDP-11, which had no
caches, did not need. `XWRIT` (#l("xp->x_flag = XWRIT;")) then ensures that the swap copy is
written when the core copy is first given up.

#lines-to("/*", lead: true)

The routine `xexpand` obtains core for a text which has none. If core is available,
the text is read in from its swap copy, unless `XLOAD` says it is about
to be read from the file instead. A copy read from swap is made visible
to instruction fetch (#l("arm_sync_icache(PGADDR(xp->x_caddr),", after: "swap(xp->x_daddr, xp->x_caddr, xp->x_size, B_READ);")) as `xalloc` does.

If not, the process makes room for itself by swapping itself out
(#l("xswap(u.u_procp, 1, 0);")), and leaves the matter to `sched`, which brings in data area and
text together (`swapin`, #f("slp.c")). The pattern is that of `expand`:
`save(u.u_ssav)` (#l("if (save(u.u_ssav)) {")) is the point to which the process returns, by way
of `SSWAP` and `swtch`, once it is back in core. It then reloads its
user mapping with `sureg` and returns. The call of `qswtch` (#l("qswtch();")) does not return.

#lines-to("/*", lead: true, after: "/* no return */")

The lock on a text entry. A call of `xlock` sleeps at `PSWP`, a priority at which
no signal can interrupt it.

#lines-to("/*", lead: true, after: "}")

The routine `xccdec` is called when a process using a text leaves core, by being
swapped out or by giving up the text. When the last such process has
gone, the core copy is freed, but first written to the swap device if
it has never been written there (`XWRIT`).

#lines-to("/*", lead: true, after: "}")

The call `umount` (#f("sys3.c")) calls `xumount`, since a file system cannot be
unmounted while a sticky text from it holds its inode. The routine `xrele` is called
when write access to a file is checked (`access`, #f("fio.c")), when the
file is unlinked, and when `chmod` clears its sticky bit (#f("sys4.c")):
a text which no process is using should not hold the inode, nor survive
a change to the file. Both pass the work to `xuntext`, which empties the
entry only if no process uses it (#l("if (xp->x_count) {")).

The test in `xrele` (#l("if ((ip->i_flag&ITEXT)==0)")) has gained parentheses. In v7 the test was
`ip->i_flag&ITEXT==0`, which C parses as `ip->i_flag & (ITEXT==0)`,
which is always zero, so that v7 never took the early return and always
searched the table. The search finds nothing for an inode without
`ITEXT`, so the bug cost only time. The port writes what was meant.

#lines-to(none)
#source("/usr/sys/h/buf.h")

Each `buf` is a header which describes a block transfer by its device
and block number, its core address, and its byte count, with the state
of the operation in `b_flags`. The data itself
lies elsewhere: for an entry of the array `buf`, which forms the buffer
cache, in the rows of `buffers` (#f("qemu/c.c")), to which `binit`
(#f("main.c")) points `b_addr`. For the headers used by `swap` and `physio`
(#f("bio.c")), in the process image being transferred.

Two lists thread the cache. The fields `b_forw` and `b_back` link every buffer to the device with which it is associated, so that `getblk` can find a
block by searching one short list, and `av_forw` and `av_back` link the
buffers which are not busy, in the order in which they were released, so
that the one least recently used is at the front. The comment (#l("/*", before: "* Each buffer in the pool is usually doubly linked into 2 lists:")--#l("*/", after: "* are in bio.c."))
states the rules.

In v7 there was a further member, `b_xmem`, for the high-order bits of the 18-
or 22-bit PDP-11 physical address, of which `b_addr` held only the low
sixteen. On the ARM `b_addr` is a full 32-bit address, and `b_xmem` is
gone. The union `b_un` (#l("union {")--#l("} b_un;")) lets the same address be used as a pointer to
whatever the block contains.

#lines-to("/*", after: "extern struct buf bfreelist;\t\t/* head of available list */")

The flags. `B_DONE` means that the contents are valid, `B_BUSY` that
some process or the driver owns the buffer, and `B_DELWRI` that the
contents are newer than the disk and must be written before the buffer
is reused. `B_AGE` puts a buffer at the front of the available list
rather than the back, so that it is reused first. `B_PHYS` marks a
transfer directly to or from a user image, and v7's comment added
"potentially using UNIBUS map", which no longer applies. The flag `B_MAP` of v7,
which recorded that the buffer held the UNIBUS map of the PDP-11/70, is
gone with the map (#f("machdep.c")). `B_TAPE` is set in the `d_tab` of a magnetic tape driver, of
which there is none. `B_PBUSY` and `B_PACK` are used by no file of
this system.

The head of a driver's lists is itself a `buf`, the `d_tab` of the
driver's `bdevsw` entry (#f("conf.h")), and the names at the end of the
file (#l("#define\tb_actf\tav_forw")--#l("#define\tb_errcnt b_resid")) rename those fields of it which serve another purpose
there: `b_actf` and `b_actl` are the head and tail of the queue of
requests, `b_active` says that the device is busy, and `b_errcnt` counts
retries. A header on that queue is linked through `av_forw`, which is
free for the purpose, since a busy buffer is not on the available list.

#lines-to(none)
#source("/usr/sys/h/conf.h")

The header #f("conf.h") declares the switches through which the rest of the system
reaches the device drivers. A device number has two parts: the major
number, which selects an entry of `bdevsw` or `cdevsw`, and so a
driver. And the minor number, which the driver interprets as it pleases.
Neither the file system nor #f("bio.c") knows any driver by name. The tables
themselves are defined in the `c.c` which `mkconf` generates for each
configuration (#f("qemu/c.c")). The comment's `conf.c` is an older
name for that file.

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
nothing and are declared `void`, and `l_read`, `l_meta`, and `l_modem`
return `int`, and `l_write` keeps v7's `char *`. A routine of the wrong
type no longer fits a slot, which is why the generated tables use
`nostrat`, `nordwr`, `noioctl`, `nolioctl`, and `nulltty` (#f("subr.c"))
where v7 used `nodev` and `nulldev` for everything.

The incomplete declarations of `struct buf` and `struct tty` (#l("struct buf;"), #l("struct tty;"))
are new. A structure first named inside a prototype is local to that
prototype, and would not be the same type as the one defined later in
#f("buf.h") or #f("tty.h"); declaring the tags first at file level makes
them so, whether or not those headers have been included.

#lines-to("struct intr", lead: true)

The structure `struct intr` is new. It is the type of `intrtab` in the generated
#f("qemu/c.c"), which pairs each interrupting device with its handler,
as the PDP-11's interrupt vectors in `l.s` did. The member `i_irq` points to the
driver's variable holding its interrupt number, rather than holding the
number itself, because a driver may learn its number only when it finds
its device: the virtio disk (#f("virtio_blk.c")) does. The handler `i_fn` is called
with the interrupted `pc` and `ps`, as every PDP-11 handler was called
with the interrupt's frame. Only `clock` (#f("clock.c")) uses them, to
charge the tick to user or system time and to profile. The device
handlers discard them. The routines `intrstart` and `irq` (#f("machdep.c")) enable
and dispatch the interrupts, the clock's among them, from the table.

#lines-to(none)
#source("/usr/sys/conf/qemu/c.c")

This file is not written by hand. The program `mkconf` (#f("mkconf.c")) reads a
short description of the machine, #f("qemuconf") for the QEMU machine,
and writes `c.c`, which holds the device switches declared in
#f("conf.h"), the choice of root and swap devices, the principal tables
of the system, and, new in this port, the facts which differ between
the QEMU machine and the MP135 machine (#f("mp135/c.c")). Everything
else in the kernel is the same for both machines. The machine is chosen
by linking with one `c.c` or the other.

In v7 the `c.c` was generated in the same way, with a companion `l.s` holding
the PDP-11 interrupt vectors. The port has no `l.s`: its interrupt
vectors are fixed (#f("low.s")), and the routing of interrupts to drivers
is the table `intrtab` at the end of this file.

The includes are v7's, with #f("seg.h") added for `struct memregion`
and the `BLK_` attributes used below, and #f("map.h"), #f("mount.h"),
and #f("callo.h") for the tables which this file now defines. The v7 copy declared every driver
routine it named, as `int nodev();` and the like. Here all of them are
declared with prototypes in #f("systm.h"), which is already included,
and the declarations are gone.

#lines-to("extern struct\tbuf\trktab;")

The block device switch. The program `mkconf` lists every block device it knows,
in a fixed order, so that a device keeps its major number whatever the
configuration: `rk` is always 0. A device which is configured gets its
driver's entry. One which is not gets an entry which fails. Only `rk` is
configured here, and the routines named `rk` are those of the virtio
disk driver (#f("virtio_blk.c")), which took v7's names so that
`mkconf`'s table could be used unchanged. On the MP135 machine the same
entry names the routines of the SD card driver, #f("sd.c"), which
took v7's names too. Each machine's kernel links only its own driver.

Note the braces around each row, without which `-Wall` warns that a
structure within an array is initialised without its own braces, and `nostrat` where v7 wrote
`nodev`: the strategy slot now has a type of its own (#f("conf.h")).
The v7 configuration also had the TU16 magnetic tape, `ht`, at major 7.

The head of the disk's queue is `rktab` (#l("extern struct\tbuf\trktab;")). In v7 the file `c.c` defined it,
and so did `rk.c`, and the loader merged the two definitions into one
common symbol. Here `c.c` only takes its address, and declares it
`extern`. The one definition is in the driver (#f("virtio_blk.c")), as
in `rk.c`.

#lines-to("struct\tcdevsw\tcdevsw[] =", lead: true)

The character device switch, in the same manner. The console (major 0),
memory (8), the raw disk (9), and the controlling terminal `tty` (17)
are configured. Of these only the disk is named in #f("qemuconf"):
`mkconf` always includes the console, memory, and `tty`. The console's
routines are named `kl`, after the PDP-11's KL11 interface, and are
those of #f("pl011.c") (on the MP135 machine, of #f("usart.c")).

The raw disk entry uses `rkread` and `rkwrite`, which call `physio`
(#f("bio.c")) with the disk's strategy routine. The `nodev` of v7 in the
`ioctl` slot becomes `noioctl`, and v7's `nulldev` in `d_stop` becomes
`nulltty`, again because the slots now have types.

#lines-to("struct\tlinesw\tlinesw[] =")

The one line discipline, that of #f("tty.c"). In v7 the row was
`ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart`, which put
`ttstart` in the seventh slot, `l_rend`, though the structure names a
later slot `l_start` for it. Nothing calls either slot for this
discipline, so the mistake was harmless. The port puts `ttstart` where
its name says. In `l_close`, `nulltty` replaces `nulldev`, and
`nolioctl` replaces `nodev` in `l_ioctl`.

#lines-to("int\trootdev\t= makedev(0, 0);")

Root, swap, and pipe devices are all minor device 0 of major device 0,
the one disk. The file system occupies its first 32768 blocks
(#f("rootfs.proto")), and the swap area is the 1048576 blocks after it,
from `swplo`. This is the arrangement of v7's own RK05 configuration,
where `swplo` was 4000 and the swap area ended at block 4872, the end
of the pack. Putting the swap area after the file system keeps it clear
of the superblock, the block which describes a file system as a whole,
in block 1.

#lines-to("struct\tbuf\tbuf[NBUF];")

The main tables of the system are defined here rather than in the files
which use them, at the sizes of #f("param.h"). In v7 this file also defined
`ldmpx`, a pointer to `mpxchan`, for its multiplexed files. The port
carries neither the multiplexor (`mx1.c`, `mx2.c`) nor its stub
`fakemx.c`, and the definition is gone.

In v7, `main.c` defined the buffers, the three maps, and the mount
table, `callo.h` the callouts, and `prim.c` the character blocks. The port defines them here too (#l("int\tbuffers[NBUF+1][(BSIZE+BSLOP+63)/64*16];")--#l("struct\tcblock\tcfree[NCLIST];")),
so that every large table is in `c.o`, which the MP135 machine's linker
script places in DDR, beyond the small SYSRAM in which its kernel runs
(#f("mp135/unix.ld")). The sizes are the same on both machines, and
`CMAPSIZ` and the other sizes of the maps are computed from them.

#lines-to("unsigned int\tcorebase, coreoff, coretop = 0x60000000;")

The rest of the file is new: the facts about the machine, taken from
lines of #f("qemuconf") which v7's format did not have.

The bounds `corebase` and `coretop` (#l("unsigned int\tcorebase, coreoff, coretop = 0x60000000;")) give, by physical address, the memory
which `startup` (#f("machdep.c")) gives to `coremap` for process images:
from the first page after the kernel, which `machine_init` stores into
`corebase`, to the end of the QEMU machine's 512 MB. The offset `coreoff`, which
`machine_init` also sets, is the distance from the physical address of
core to its kernel address (#f("seg.h")). The addresses `gicdbase` and `giccbase` (#l("unsigned int\tgicdbase = 0xf0000000, giccbase = 0xf0010000;"))
locate, by kernel address, the distributor and the processor interface
of the ARM generic interrupt controller. The attributes of a user page,
`PGUSER`, are the same on both machines and are a constant
(#f("seg.h")).

The table `board_map` (#l("struct\tmemregion\tboard_map[] =")) lists the regions which the kernel maps in 2 MB blocks
(`machine_init`, #f("machdep.c")), each with its kernel address, its physical bounds, and its attributes. They are all 512 MB of memory, at
0xc0000000, as cacheable kernel memory, and three blocks of the QEMU
machine's devices (the interrupt controller, the UART, and the virtio transports),
from 0xf0000000, as device memory which may not be executed (@ch-intro).
Since a kernel address is not a physical one, a device performing DMA
must be given the latter, which `vtop` (#f("machdep.c")) finds in this
table (#f("virtio_blk.c")).

#lines-to("extern int\tclkirq, klirq, rkirq;")

The table `intrtab` (#l("struct\tintr\tintrtab[] =")) pairs each configured interrupting device, the clock, the console, and
the disk, with its handler (`struct intr`, #f("conf.h")). The numbers are reached through pointers, since the disk driver
learns its own only when it finds the device.

The four procedures at the end are the glue by which the
machine-dependent code calls the configured drivers without naming them. The routine `cninit` sets up the console early in `machine_init`, `bdinit`
finds the disk before `main` enables the interrupts, and `clock_ddr_init`, which on
the MP135 machine starts the memory controller (#f("ddr.c")), does
nothing here, since the QEMU machine's memory needs no initialisation.
Nor does `wdinit`, which on the MP135 machine starts the watchdog
(#f("iwdg.c")): QEMU's machine has none. The routine `putchar`, the
console output of `printf` (#f("prf.c")), needs no glue: the console
driver defines it under v7's name (#f("pl011.c")).

#lines-to(none)
#source("/usr/sys/dev/virtio_blk.c")

This is the disk driver of the QEMU machine. It replaces v7's
`rk.c`, the driver for the RK05 cartridge disk, and takes over its
names (`rkstrategy`, `rkintr`, `rktab`, and so on), its configuration
entry in `mkconf` (#f("qemu/c.c")), and as much of its text as the new
device allows. The reader who compares the two files will find the same
three procedures doing the same three jobs. The routine `rkstrategy` adds a request
to the queue and starts the device if it is idle. The routine `rkstart` gives the
request at the head of the queue to the device. The routine `rkintr`, called when
the device has finished, completes that request and starts the next.
Only one request is in the device at a time. The new procedure, `rkinit`,
finds and prepares the device, which an RK11 never needed. Even v7's
heading comment (#l("* RK disk driver")) is kept, since the driver is configured as `rk`.

The device is a "virtio" block device, an interface designed for
virtual machines rather than for hardware. QEMU provides up to 32 virtio
transports, each a block of registers 0x200 bytes long, from physical
address `0x0a000000`, which the kernel maps at 0xf0400000 (#f("qemu/c.c")).
The driver uses the original ("legacy") form of the
interface. Requests are passed through a "virtqueue" in the machine's memory. It
has a table of descriptors, each giving the address and length of a
piece of memory. The driver places the first descriptor of each new
request in an "available" ring, and the device returns the requests it
has finished in a "used" ring.

#lines-to("#define\tRKADDR(off)\t(*(volatile int *)(vbase+(off)))")

The `RKADDR` of v7, the RK11's registers as a `struct device` at `0177400`,
is now (#l("#define\tRKADDR(off)\t(*(volatile int *)(vbase+(off)))")) the register at offset `off` of the transport which
`rkinit` has found, at the kernel address `vbase`. The `struct device`
is deleted. Like v7's addresses in the I/O page, which were kernel
addresses too, the driver's addresses are written into it.
`NRKBLK`, the size of a pack (#l("#define\tNRKBLK\tRKADDR(0x100)")), is now the size of the disk, which
the device gives in 512-byte sectors in the first word of its
configuration space, at offset `0x100`. The rest of v7's definitions, which nothing uses, are kept. They are `NRK`, the number of drives (#l("#define\tNRK\t4")),
and the RK11's command and status bits (#l("#define\tRESET\t0")--#l("#define\tCTLRDY\t0200")). `NVQ` (#l("#define\tNVQ\t8")) is the number of
descriptors in the virtqueue. A request needs three.

#lines-to("struct\tvring")

The structure `struct vring` (#l("struct\tvring")) lays out the virtqueue as the legacy interface
requires. Each descriptor has a
64-bit address, of which the ARM fills only the low word, a length,
flags, and the index of the next descriptor of a chain. The available
ring follows the descriptors, and the used ring begins at the next
multiple of 4096 bytes, the alignment which `rkinit` gives the device,
as the legacy interface prescribes, and `pad` (#l("char\tpad[4096-18*NVQ-4];")) fills the space between.
Each element of the used ring is a pair of words, hence `2*NVQ`. The
specification puts one more halfword after `aring`, which is not
declared, and QEMU leaves it out when it computes where the used ring
lies. Rounded up to 4096 bytes, both arrive at the same place.

The declaration of `rkstart` (#l("void rkstart(void);")) is new, needed because `rkstrategy`
calls it before its definition. The buffer `vqbuf` (#l("char\tvqbuf[sizeof(struct vring)+4095];")) is reserved with 4095
bytes to spare, so that `rkinit` can
place the virtqueue on a page boundary within it, as the legacy
interface demands. The header of a request, `vreq`, holds its type, read or write, and the sector, which counts 512-byte units, so that a block
number serves unchanged. The device's report, zero
for success, is received in `vstatus`. One of each suffices, since the driver has only one
request in the device at a time.

#lines-to("void", after: "int\trkirq;")

Before `main` enables the interrupts, `bdinit` (#f("qemu/c.c")) calls `rkinit`, which must find the device to learn its interrupt.
Each transport is examined for the magic number `virt` (as a
little-endian word) and a device type of 2, a block device. An empty
transport reports type 0.

#lines-to("RKADDR(0x70) = 1;")

The device is acknowledged and told that a driver exists, by writing 1
and then 3 to the status register (#l("RKADDR(0x70) = 1;"), #l("RKADDR(0x70) = 3;")). The
virtqueue is then described to the device (#l("RKADDR(0x28) = 4096;")--#l("RKADDR(0x40) = vtop((caddr_t)vq) >> 12;")) by the page size, the number of descriptors, the alignment of
the used ring, and the page number of the ring itself. The address rounded up to a page is `vq`, and the device needs
the physical address, which `vtop` (#f("machdep.c")) supplies. Status 7
(#l("RKADDR(0x70) = 7;")) says the driver is ready.

The interrupt of the n-th transport (#l("rkirq = 48 + (vbase-0xF0400000)/0x200;")) is shared peripheral
interrupt 16 + n of the interrupt controller, number 48 + n. The table `intrtab`
reaches `rkirq` through a pointer for that reason, and `intrstart`
(#f("machdep.c")), which enables the interrupts in the table, runs after
`rkinit`.

Several things are left as they are found. The queue selection
register is not written, since queue 0, the only one, is selected after
a reset. With `aflags` zero, the driver asks for an interrupt on each
completion. And every entry of `aring`, which names the first descriptor
of a request, is zero, which is right, since every request starts at
descriptor 0. Both lie in `vqbuf`, which is zero, being uninitialised
data.

#lines-to("void")

The strategy routine `rkstrategy` tests the request more than v7's did. A block number beyond the
end of the disk is rejected at once (#l("if (bp->b_blkno >= NRKBLK || bp->b_bcount&BMASK) {")--#l("}", after: "if (bp->b_blkno >= NRKBLK || bp->b_bcount&BMASK) {")), as v7 rejected one beyond
the end of the pack. Such requests arise: `breada` (#f("bio.c")) reads
ahead the block after the last, and without the check the device would
fail the request and `rkintr` would report and retry it ten times. A count which
is not a whole number of blocks is rejected too: the RK11 moved any
number of words, but a virtio disk moves only whole 512-byte sectors and
fails such a request, so that a raw read of 510 bytes, which `physio`
lets through as an even count, would otherwise be tried eleven times.

The call of `mapalloc` in v7, for the UNIBUS map of the PDP-11/70, is gone
with the map. The IRQ is masked with `intr_disable` and unmasked with `intr_enable`: the
routine is called at process level. During startup the unmasking lets
nothing in, since the interrupt controller stays switched off until
`intrstart` (#f("machdep.c")).

The queue is that of v7, threaded through `av_forw` and headed in
`rktab` (#f("buf.h")).

#lines-to("void", after: "}")

The routine `rkstart` gives the request at the head of the queue to the device. In v7 the driver
computed the drive, cylinder, and sector, and loaded four registers,
the last of which started the transfer; the port fills in a chain of
three descriptors: the header `vreq` (#l("vreq.type = bp->b_flags&B_READ ? 0 : 1;")--#l("vq->desc[0].next = 1;")), which the device reads;
the data (#l("vq->desc[1].addr = vtop(bp->b_un.b_addr);")--#l("vq->desc[1].next = 2;")), which the device writes on a read (flags 3, "next"
and "device writes") and reads on a write (flag 1); and the status byte
(#l("vq->desc[2].addr = vtop((caddr_t)&vstatus);")--#l("vq->desc[2].flags = 2;")), which the device writes. Each address is a physical one,
found by `vtop` (#f("machdep.c")) from the kernel's: that of a buffer
in the cache, or, for `swap` and `physio` (#f("bio.c")), that of a
process image in core, given by `PGADDR` (#f("seg.h")). Such a
transfer covers consecutive pages, which are consecutive in physical
memory too, so one descriptor serves.

The minor device number, which v7 used to choose one of four drives, is
ignored: there is one disk.

#lines-to("dmbsy();")

The barrier `dmbsy` (#f("mch.s")) ensures that the device
sees the descriptors before the incremented index of the available ring,
and the index before the write of the queue number to the notify
register, which starts the device. No cache need be cleaned for the
data, since QEMU's device reads and writes the same memory the processor
sees.

The remaining lines record the transfer for `iostat`.
The count `dk_wds` is kept in units of 32 PDP-11 words, 64 bytes, since
`iostat` multiplies it by 32. Both counts are summed as `unsigned long`,
as `dk_time` is in #f("clock.c"), so that they wrap instead of
overflowing.

#lines-to("void")

When the disk interrupts, `irq` (#f("machdep.c")) calls `rkintr`.
The interrupt is acknowledged by writing back the bits read from
the interrupt status register (#l("RKADDR(0x64) = RKADDR(0x60);")). It is ignored if no
request is outstanding or if the device has not yet returned
it in the used ring. The barrier (#l("dmbsy();", after: "if (rktab.b_active == NULL || vq->uidx != vq->aidx)")) keeps the processor from reading
`vstatus` or the data before it has seen the device's index.

#lines-to("dk_busy &= ~(1<<DK_N);")

An error is reported by a nonzero status byte. In v7 the driver reported the
RK11's error and drive status registers by `deverror` (#f("prf.c")),
then reset the controller and waited for it. The port reports the status
and has nothing to reset. After up to ten retries the request is taken
off the queue and completed by `iodone` (#f("bio.c")), and the next is
started.

#lines-to("void")

The raw disk, `cdevsw` entry 9, transfers directly between the disk and
the user's memory by way of `physio` (#f("bio.c")), using the private
header `rrkbuf`.

#lines-to(none)
#source("/usr/sys/dev/bio.c")

The file #f("bio.c") holds the buffer cache and the other routines which stand
between the rest of the system and the block device drivers. The file
system never calls a driver: it asks for a block by device and number
(`bread`, `getblk`), changes the buffer it receives, and gives it back
in one of four ways (`bwrite`, `bdwrite`, `bawrite`, `brelse`). Whether
any transfer takes place, and when, is decided here. The file also holds
`swap`, which moves process images, and `physio`, which moves data
between a device and a user's memory without passing it through the
cache.

The file is v7's but for the dressing of C99, the size of one array,
the UNIBUS map, which is gone, and the places in `swap` and `physio`
which computed PDP-11 physical addresses. The declarations (#l("int\tincore(dev_t dev, daddr_t blkno);")--#l("geterror(struct buf *bp);")) are
new: each of these procedures is called
before its definition and only within this file.

#lines-to("#define\tDISKMON\t1", lead: true)

`DISKMON` compiles in the counters of `io_info`, which `iostat` reads from `/dev/kmem`. They count reads, read-aheads,
cache hits, and writes, and `bufcount` counts how deep in the available list each buffer found in the
cache was. The counters are unsigned, so that they wrap after a long
uptime instead of overflowing. As in v7, `bufcount` has `NBUF` entries,
one for each possible depth, and `iostat` now reads as many, where v7's read
50 and printed 30 (#f("cmd/iostat.c")).

Two headers, `swbuf1` and `swbuf2`, serve `swap`, so that two transfers
of process images may be queued at once.

#lines-to("/*", after: "struct\tbuf\tswbuf2;")

The routine `bread` returns a busy buffer holding the block. If `getblk` finds that
the buffer already holds valid data (`B_DONE`), nothing more need be
done. Otherwise the strategy routine queues a read, and `iowait` sleeps until
it is complete.

#lines-to("/*", lead: true, after: "}")

When a file is read
sequentially, `readi` (#f("rdwri.c")) uses `breada`: besides the block wanted, it starts the reading of the
next one, `rablkno`, without waiting for it.

#lines-to("if (!incore(dev, blkno)) {")

If no buffer is associated with the wanted block (#l("if (!incore(dev, blkno)) {")), one is taken and
its read is started. If one is, it may be busy, and `getblk` would sleep
on it, and `incore` lets `breada` pass it by, leave `bp` null, and start the
read-ahead first. Only then (#l("return(bread(dev, blkno));")) does `bread` obtain the wanted block,
sleeping if it must. The read-ahead buffer is marked `B_ASYNC`, so that
`iodone` releases it when its transfer is done. No one waits for it.

#lines-to("/*", lead: true)

The routine `bwrite` queues a write and, unless it is asynchronous, waits for it and
releases the buffer. The flags are cleared before the write is queued,
the old value being kept in `flag`. An asynchronous write of a delayed
write block (#l("} else if (flag & B_DELWRI)")) is the case of a buffer reclaimed by `getblk` or
pushed out by `bflush`. It is marked `B_AGE`, so that when `iodone`
releases it the buffer goes to the front of the available list, to be
reused first.
Only an error in starting a plain asynchronous write can be reported
(#l("geterror(bp);", after: "bp->b_flags |= B_AGE;")), since the process which caused a delayed write may be gone.

#lines-to("/*", lead: true, after: "}")

The routine `bdwrite` marks a buffer to be written later, when it is taken for
another block or when `bflush` runs. A block which is written a little
at a time is then written once. A tape, whose blocks must be written in
order, is written at once. No tape driver is configured in this system.
The routine `bawrite` starts the write without waiting.

#lines-to("/*", lead: true, after: "bwrite(bp);")

The routine `brelse` returns a buffer to the available list. Those waiting for this
buffer, and those waiting for any buffer, are woken. A buffer whose
transfer failed is detached from its device (#l("bp->b_dev = NODEV;  /* no assoc. on error */")), so that its contents
will not be found again by `getblk`. A buffer marked `B_AGE` goes to the
head of the list, others to the tail. The head is where `getblk` takes
buffers from, so the list is in order of least recent use.

The list is changed with interrupts masked, since `iodone`, called from
an interrupt routine, may call `brelse` for an asynchronous transfer.

#lines-to("/*", lead: true, after: "}")

Whether some buffer is associated with the block, valid
or not, is what `incore` reports.

#lines-to("/*", lead: true, after: "}")

The heart of the cache is `getblk`. The major device number is
first checked (#l("if(major(dev) >= nblkdev)")) against `nblkdev`, the number of entries in `bdevsw`, which
`binit` (#f("main.c")) counts. An entry whose `d_tab` is null (#l("panic(\"devtab\");")) is a
device which is not configured.

#lines-to("for (bp=dp->b_forw; bp != dp; bp = bp->b_forw) {")

The device's list is searched for the block. If the buffer
is busy, the caller sleeps, and searches again when woken, since the
buffer may meanwhile have been given to another block. Otherwise the
buffer is taken from the available list (`notavail`). The interval
between the test of `B_BUSY` (#l("if (bp->b_flags&B_BUSY) {")) and the sleep is covered by `intr_disable`, since an interrupt could otherwise release the buffer and issue its
wakeup before the sleep began, and the sleeper would never be woken.

#lines-to("intr_disable();", after: "}")

If the block is not in the cache, the buffer at the head of the
available list is taken. If it holds a delayed write, the write is
started and the search begun again. The buffer is moved from the list of
its old device to that of the new, and given its new identity. `B_DONE` is not set, which tells `bread` that the block must be read.

#lines-to("/*", lead: true)

The routine `geteblk` obtains a buffer associated with no device. It holds the
in-core copy of a mounted file system's superblock (`iinit`,
#f("main.c"); `smount`, #f("sys3.c")), and the zeros which `readi`
returns for a hole in a file. It is placed on the list of `bfreelist`, which serves as
the device list for `NODEV`.

#lines-to("/*", lead: true, after: "}")

Until the transfer on a buffer is complete, `iowait` sleeps, and then it passes
any error to `u.u_error` (`geterror`). The routine `notavail` removes a buffer from
the available list and marks it busy.

#lines-to("/*", lead: true, after: "intr_restore(s);")

A driver's interrupt routine calls `iodone` when a transfer
finishes. It marks the buffer done, and v7 first freed the UNIBUS map if the
transfer had it, and that step is gone with the map. An asynchronous
transfer has no one waiting, so the buffer is released. Otherwise the
process waiting in `iowait`, `swap`, or `physio` is woken.

The routine `clrbuf` zeroes a buffer a word at a time, and `sizeof(int)` makes the count
128 words here, where it was 256 on the PDP-11.

#lines-to("/*", lead: true, after: "bp->b_resid = 0;")

The routine `swap` transfers `count` pages of a process image between core, at
page `coreaddr`, and the swap device, at block `blkno` of the swap area.
Its callers are `xswap` (#f("text.c")) and `swapin` (#f("slp.c")),
and sleeps until the transfer is complete.

#lines-to("bp = &swbuf1;")

Of the two swap headers, the first is used unless it is busy. The second is
taken if no one is already waiting for it, else the caller waits for
the first.

#lines-to("while (count) {")

The image is transferred (#l("while (count) {")--#l("}", after: "blkno += ptod(tcount);")) in one piece. In v7 it was broken into
pieces of at most `01700` clicks, because on the PDP-11 the byte count
of a transfer was bounded by a sixteen-bit register, and `01700` 64-byte
clicks was 61440 bytes. Here neither `b_bcount` nor either driver's
request has such a limit, so the loop is kept but always ends after one
transfer.

In v7 `b_addr` (#l("bp->b_un.b_addr = PGADDR(coreaddr);")) was set to the low sixteen bits of the physical address,
`coreaddr<<6`, and `b_xmem` to the high bits. The port uses `PGADDR`
(#f("seg.h")), which gives the kernel's address for the page, and the
driver turns it into the physical address the device needs (`vtop`,
#f("machdep.c")): the same division of labour, the address here and the
device's view of it in the driver.

The priority is raised again (#l("intr_disable();", after: "(*bdevsw[major(swapdev)].d_strategy)(bp);")) after the strategy routine, which
in v7 lowered it, before `B_DONE` is tested. The reason is that given
for `getblk`.

An error in swapping is fatal (#l("panic(\"IO err in swap\");")): a process image cannot be recovered.

#lines-to("/*", lead: true)

The routine `bflush` starts the writing of every delayed-write buffer of a device,
or of all devices. Its caller is `update` (#f("alloc.c")), which
in turn `sync`, `umount`, and `panic` call. Each write changes the available
list, so the search starts again from the head after each one.

#lines-to("/*", lead: true, after: "}")

The routine `physio` implements the raw devices, transferring directly between the
device and the user's memory, using a header which belongs to the
driver, and does as much in one transfer as the user asks for. The fields `u_base`, `u_count`, and `u_offset` describe the transfer, as
for `read` and `write`.

#lines-to("if (base&01 || u.u_count&01 || base>=base+u.u_count ||")

The checks (#l("if (base&01 || u.u_count&01 || base>=base+u.u_count ||")) are v7's, with two added. The transfer must lie within
the user's address space, below `USRSIZE`, and its offset on the
device must not be negative (#l("base+u.u_count > USRSIZE || u.u_offset < 0)")). Both `readi` and `writei` let a negative
offset through to character devices, for the sake of `/dev/kmem`
(#f("rdwri.c")). For a disk it would become a negative block number,
which the drivers' checks of `b_blkno`, signed comparisons, do not
catch.

v7 then refused a transfer which overlapped the text, which is shared
and must not be written by a device, and checked that the transfer lay
wholly in the data segment or wholly in the stack, the two parts of the
user's address space which are mapped and which lie in different places
in core. With the text and the data each at its own address, the second
check alone covers the first, and the port makes only that
(#l("if (nb >= (int)u.u_pdstart &&")--#l("goto bad;", after: "else if (nb >= (int)(btop(USRSIZE)-u.u_ssize))")). The page of the start of the transfer is
`nb` (#l("nb = base>>12;")), and the test is of the page of its last
byte. In v7 it was of the click of the byte after the transfer, so that
a transfer which ended exactly at the end of the data was refused. With
pages of 4096 bytes in place of clicks of 64, such a buffer is 64 times
as likely. v7 also masked the addresses with `01777` to keep them
within the 64 KB address space, which the test at #l("if (base&01 || u.u_count&01 || base>=base+u.u_count ||") has
already done here.

The same test finds `ts`, the transfer's first page within the image.
The data begins `USIZE` pages into the image (#f("proc.h")), and the
stack follows it. An address in the data lies `nb-u_pdstart` pages
into the data, and one in the stack lies as many pages into the stack
as it lies above the stack's lowest address.

#lines-to("/*", after: "bp->b_dev = dev;")

In v7 the physical address of the user's buffer was found by reading the user
segmentation registers (`UISA` or `UDSA`), simulating the translation
which the hardware would have made. The port adds `ts` to `p_addr`
instead (#l("bp->b_un.b_addr = PGADDR(u.u_procp->p_addr + ts) + (base&07777);")), and only after any sleep for the buffer, during
which the image may have moved. `PGADDR` converts the page number to an
address, as in `swap`, and the low twelve bits of the user's address
give the offset within the page. Each part is contiguous in core, so
the whole transfer is too.

`SLOCK` (#l("u.u_procp->p_flag |= SLOCK;")) keeps the process in core while the device transfers
into its memory: the address given to the device would be wrong if the
image were swapped out and brought back elsewhere.

#lines-to("/*", lead: true, after: "}")

The routine `geterror` passes the error of a failed transfer to the user. The
comment's last sentence was true of v7's drivers and remains so here:
neither disk driver sets `b_error`.

#lines-to(none)

== File System <ch-fs>

#source("/usr/sys/h/file.h")

A `file` structure stands between
the descriptors of one or more processes and the inode of an open file.
Each of `open`, `creat`, and `pipe` (#f("sys2.c"), #f("pipe.c")) makes a new
one, and `fork` and `dup` merely make a second descriptor point at an
existing one, and increment `f_count`. The read/write pointer is kept
here, not in the inode and not in `u`, so that processes which share a
`file` also share the position in it, as a shell and its children must
when they write in turn to the same output.

The count `f_count` (#l("short\tf_count;\t/* reference count */")) was a `char`. On the PDP-11 it was signed and could
count to 127. On the ARM `char` is unsigned and the limit was 255.
Every process forked from a shell shares its terminal's `file`, so a
process table larger than v7's 150 entries could wrap the count to
zero and free the entry while still in use. Nothing checks for
overflow, here or in v7. It is now a `short`, which counts to 32767.
On the PDP-11 and the ARM alike, `f_offset` is a `long`, but on the
PDP-11 it occupied two words, high word first, where here it is a
single word.

The union's second member, `f_chan`, and the flags `FMPX`, `FMPY`, and
`FMP` belong to v7's multiplexed files, `mx1.c` and `mx2.c`. Those files
are not part of this system, so no `file` is ever marked as a channel
and the tests of `FMP` in `rdwr`, `seek`, and `closef` always take the
ordinary path. `FKERNEL` was used by nothing even in v7.

A `file` now occupies 12 bytes rather than 8: the inode pointer has
grown to four bytes, and a byte of padding after `f_flag` puts the
`short` `f_count`, and the pointer after it, on their boundaries.

#lines-to(none)
#source("/usr/sys/h/inode.h")

The in-core inode. The table `inode` holds one entry for each file which is in use in any way, whether open,
the current or root directory of some process, being executed, mounted
on, or merely in the middle of a path being searched by `namei`. The routine `iget` (#f("iget.c")) finds or fills an entry, and
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

The 13 addresses of `NADDR` are ten direct block addresses followed by a
single, a double, and a triple indirect block, as interpreted by `bmap`
(#f("subr.c")). `NINDEX` and `struct group` belong to v7's multiplexed
files, which this system does not have (see #f("file.h")).

#lines-to("struct\tinode", after: "};")

As in v7, `i_flag` is a `char`. The count `i_count` (#l("short\ti_count;\t/* reference count */")) was one too, and could
count 127 references to an inode on the PDP-11 and 255 on the ARM. The
root directory is the current directory of most processes, so a process
table larger than v7's 150 entries could wrap its count to zero, and the
inode would be freed while in use. It is now a `short`.

A special file has no blocks, and so `i_un` is a union. For a regular
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
`u_dev`, and the macros (#l("#define\ti_addr\tu_reg.i_addr")--#l("#define\ti_rdev\tu_dev.i_rdev")) let every use keep v7's spelling:
`ip->i_un.i_addr[0]` becomes `ip->i_un.u_reg.i_addr[0]`. The
corresponding macro for `i_group` was dropped because nothing refers to
it.

#lines-to("extern struct inode inode[];\t/* The inode table itself */", lead: true)

Now `mpxip` is declared `extern`. In v7 this line was a definition, and
every file which included #f("inode.h") defined the same variable,
leaving the linker to merge the copies. C99 leaves that behaviour
undefined, and the compiler no longer allows it by default, so the
headers now only declare such variables and #f("main.c") defines each
once. In this system `mpxip` is never set, so the tests of it in
`namei` (#f("nami.c")) always fail.

#lines-to("/* flags */")

`ILOCK` and `IWANT` implement the lock on an inode: whoever finds the
inode locked sets `IWANT` and sleeps on its address, and `prele`
(#f("pipe.c")) wakes the sleepers when the lock is released. `ITEXT`
marks the inode of a program whose text is in the text table
(#f("text.c")), and which therefore may not be written. `IMOUNT` marks an inode
on which a file system is mounted, which `iget` replaces by the root of
that file system.

#lines-to("/* modes */")

The file types occupy the top four bits of `i_mode`, below them the
set-user-id, set-group-id, and sticky bits, and below those the nine
permission bits, of which only the owner's three are named. The routine `access`
(#f("fio.c")) shifts its argument to reach the group and other bits.

`IFCHR&IFBLK` is 020000, a bit common to the character and
block types and absent from the directory and regular types, and `rdwr`
and `smount` use it as a short test for "special file". The pipe code
borrows `IREAD` and `IWRITE` as flags, since a pipe's mode is never
examined for permission (#f("pipe.c")).

#lines-to(none)
#source("/usr/sys/sys/sys2.c")

The file #f("sys2.c") holds the system calls which open, close, read, write, and
position files, together with `link`, `mknod`, and `access`. They are
thin: each decodes its arguments from `u.u_ap`, finds the inode or the
`file` concerned, and passes the real work to the routines of
#f("fio.c"), #f("rdwri.c"), #f("nami.c"), and #f("iget.c"). Apart from
the C99 dressing and the two sums in `seek`, the file
is v7's.

The declaration (#l("void\trdwr(int mode), open1(struct inode *ip, int mode, int trf);")) is new. Both `rdwr` and `open1` are called before their
definitions and from no other file, so they are declared here rather
than in #f("systm.h").

#lines-to("/*", lead: true, after: "rdwr(FWRITE);")

The routine `rdwr` serves both `read` and `write`. The arguments are reached, as in
every v7 system call, through `u.u_ap`, which `trap` (#f("trap.c"))
points at `u.u_arg`, into which it has copied the caller's arguments
from r0 upward. The local structure `a` gives them names.

#lines-to("if((fp->f_flag&mode) == 0) {")

The descriptor must have been opened for the direction wanted. The
transfer is then described to `readi` and `writei` by the variables
`u_base`, `u_count`, and `u_offset` in `u`. A `u_segflg` of zero says
that `u_base` is an address in user space. A pipe has its own
discipline (#f("pipe.c")).

#lines-to("} else {")

For an ordinary file or directory the inode is locked for the duration
of the transfer, so that the reads and writes of different processes on
one file do not interleave within a call. A special file is not locked:
a read from a terminal may wait indefinitely, and the lock would stop
every other process from using the same inode, even to write to the
terminal. The test `IFCHR&IFBLK` is explained in #f("inode.h").

The offset advances by the number of bytes actually moved (#l("fp->f_un.f_offset += uap->count-u.u_count;")), which is
also the value returned (#l("u.u_r.r_val1 = uap->count-u.u_count;")).

#lines-to("/*", lead: true)

The system call `open` obtains the inode with `namei`, and `open1` does the rest.
The increment (#l("open1(ip, ++uap->rwmode, 0);")) turns the user's mode of 0, 1, or 2 into `FREAD`,
`FWRITE`, or both.

To prepare for creation, `creat` calls `namei` with flag 1. If the file does
not exist, `namei` returns `NULL` with no error, and leaves in
`u.u_pdir` the locked inode of the directory and in `u.u_offset` the
place for the new entry, and `maknode` (#f("iget.c")) then makes the file.
The sticky bit is removed from the mode (#l("ip = maknode(uap->fmode&07777&(~ISVTX));")), since only the
super-user may set it, by `chmod`. The third argument of `open1`
records which case arose: 2 for a new file, 1 for an existing one,
which must be truncated.

#lines-to("/*", lead: true, after: "open1(ip, FWRITE, 1);")

Unless the file is new, `open1` checks permission: `creat` made it with
the mode the caller asked for, and the caller must be able to write to
it whatever that mode. A directory may be opened for reading only.

#lines-to("prele(ip);")

Both `namei` and `maknode` return the inode locked, and the lock is
released now that the file's state has been checked, and the reference
count keeps the inode in the table. Then `falloc` (#f("fio.c")) finds both a
descriptor and a `file`. It leaves the descriptor in `u.u_r.r_val1`,
which is the value returned to the user, and also remembered in `i`
(#l("i = u.u_r.r_val1;")) in case `openi`, which may call a driver's open routine, should
fail. In that case the descriptor and the `file` are released by hand,
and the inode by `iput`.

#lines-to("/*", lead: true)

The system call `close` clears the descriptor and hands the `file` to `closef`
(#f("fio.c")), which does the real work only on the last close.

The system call `seek` sets the offset in the `file` absolutely, relative to its
present value, or relative to the size of the file, according to
`sbase`. A pipe has no meaningful offset. On the PDP-11 an `off_t`
occupied two argument words and the result was returned in r0 and r1
together, by way of a member `r_off` which overlaid both `r_val1` and
`r_val2`. Here an `off_t` is one word. The offset is one argument and
the result is returned in r0 alone, so `u_r` is a plain structure
(#f("user.h")). The C library's
`lseek` is built to match. The sums (#l("uap->off = (unsigned long)uap->off + fp->f_un.f_offset;"), #l("uap->off = (unsigned long)uap->off +", after: "else if(uap->sbase == 2)")) are now formed as
`unsigned long`: an offset near 2 GB plus the present one would
overflow a signed `long`, which C leaves undefined, while the unsigned
sum wraps, and converted back it gives the negative offset that
`readi` (#f("rdwri.c")) refuses.

#lines-to("/*", lead: true, after: "u.u_r.r_val1 = uap->off;")

The system call `link` makes a second name for an existing file. Only the super-user
may link a directory (#l("if((ip->i_mode&IFMT)==IFDIR && !suser())")), since a directory with two parents would
make the meaning of its ".." entry ambiguous, and a loop of directories
could never be freed. The comment explains why the inode is unlocked
before the second `namei`: the new name may lie on a path which passes
through the file itself, if it is a directory, and `namei` would then
wait forever for the lock which this process holds.

#lines-to("u.u_dirp = (caddr_t)uap->linkname;")

The first argument was put in `u.u_dirp` by `trap`, and it is pointed at the
second for a call of `namei` with flag 1. If the name exists the call
fails. Otherwise `u.u_pdir` is the directory to receive the entry,
which must be on the same device as the file, since a directory entry
holds only an inode number. The routine `wdir` (#f("iget.c")) writes the entry and also
releases `u.u_pdir`.

#lines-to("/*", lead: true)

The super-user's general means of making an inode is `mknod`: the mode
is taken as given, so it is the only way to make a special file or a
directory. The `mkdir` command, which runs as the super-user, calls
`mknod` and then `link` twice, for "." and "..". For a special file the
third argument, the device number, goes into the first block address
(#l("ip->i_un.i_rdev = (dev_t)uap->dev;")). Nothing checks that a non-special inode receives a zero there.

Note the way an error from `suser` is handled: the test at #l("if(u.u_error)", after: "if(ip != NULL) {") also
catches it, so that the `goto out` path is taken only when `ip` has been
set.

#lines-to("/*", lead: true, after: "}")

The `access` system call, `saccess`, asks whether the real rather than
the effective user could use the file in the given ways. It does so by
installing the real ids for the duration of the `namei` and the calls
of `access` (#f("fio.c")), which leave any refusal in `u.u_error`. The
caller's mode uses the bits 4, 2, and 1, which the shifts (#l("if (uap->fmode&(IREAD>>6))")--#l("if (uap->fmode&(IEXEC>>6))"))
compare with the owner's bits of `IREAD`, `IWRITE`, and `IEXEC`.

#lines-to(none)
#source("/usr/sys/sys/fio.c")

The file #f("fio.c") holds the small routines which convert a descriptor to a `file`,
allocate descriptors and `file`s, handle the last close and the first
open of a file, and test permissions. The type of the close routine and two casts are new.

The routine `getf` checks a descriptor and returns the `file` it refers to, or sets
`EBADF`. Each process has `NOFILE` descriptors, the slots of the array
`u.u_ofile`.

#lines-to("/*", lead: true, after: "}")

When a descriptor is closed, `closef` is called, whether by `close`, by
`exit`, by `exec` for a descriptor marked close-on-exec, or by `dup` when
the target descriptor is in use. Only the last reference to a `file`
does anything (#l("if (fp->f_count > 1) {")).

In v7 the close routine was declared `int (*cfunc)()` and called with a
third argument, the multiplexor channel `f_chan`, which only the
multiplexor's own routines used. The switch tables are now fully
typed (#f("conf.h")): a close routine is `void` and takes the device
and the flag only, so the variable `cp`, its assignment, and the third
argument (#l("(*cfunc)(dev, flag);")) have gone.

#lines-to("if(flag & FPIPE) {")

When either end of a pipe is closed, the two addresses on which its
reader and writer may be sleeping, `ip+2` and `ip+1`, are woken. The
`iput` which follows reduces `i_count` to one, and the survivor, finding
that it is alone, gives up (#f("pipe.c")).

#lines-to("switch(mode&IFMT) {")

A special file has a close routine, which is called only on the last
close of the device: the loop (#l("for(fp=file; fp < &file[NFILE]; fp++)")) looks for any other `file` still open
on the same inode. The count `f_count` was cleared first (#l("fp->f_count = 0;")), so that the loop
does not find the `file` being closed. The test is by inode,
not by device number: two special files with the same major and minor
numbers are closed independently. The inode has already been released
by `iput` (#l("iput(ip);", after: "wakeup((caddr_t)ip+2);")). Only its address is compared.

#lines-to("/*", lead: true)

The routine `openi` calls the open routine of a special file's driver, after
checking that the major device number is within the switch table. The number `maj`
is `unsigned` while `nchrdev` and `nblkdev` are `int`. The casts (#l("if(maj >= (unsigned)nchrdev)"),
#l("if(maj >= (unsigned)nblkdev)")) state the comparison as unsigned, which the
rules of C made it anyway, and keep the compiler from warning of a comparison between
signed and unsigned. Since the counts are small and positive, the
meaning is unchanged. Opening an ordinary file or directory needs no
action.

#lines-to("/*", lead: true, after: "}")

The result of `access` is zero if the current user may use the inode in the way
given by `mode`, which is one of the owner's bits `IREAD`, `IWRITE`, and
`IEXEC`. Otherwise it sets `u.u_error` and returns one. Most callers
ignore the result and test `u.u_error`.

Writing is refused on a file system mounted read-only, and on a program
in use as a shared text. In the latter case `xrele` (#f("text.c")) first
tries to free the text, which succeeds if it is merely kept for its
sticky bit and no process is running it.

#lines-to("if(u.u_uid == 0)")

The super-user may do anything. Whether a file with no execute bit at
all may be run is tested in `exec` (#f("sys1.c")). For anyone else the
mode is shifted to the group or other bits only when the user is not
the owner, so a file of mode 077 is closed to its owner and open to
everybody else.

#lines-to("/*", lead: true)

The common beginning of `chmod`, `chown`, and `utime`, in
#f("sys4.c"), is `owner`: it finds the named file and allows the call only to its
owner or the super-user.

The routine `suser` also sets the flag `ASU` in `u.u_acflag`, so that the accounting record
written at exit (#f("acct.c")) shows that super-user privilege was
used.

#lines-to("/*", lead: true, after: "return(0);")

The routine `ufalloc` finds the lowest free descriptor and leaves it in `u.u_r.r_val1`
as the value to be returned, and clears the per-descriptor flags in
`u_pofile`, of which the only one is close-on-exec. To that, `falloc` adds a free
`file` and links the two.

#lines-to(none)
#source("/usr/sys/sys/rdwri.c")

The file #f("rdwri.c") moves data between a file and the place described by
`u_base`, `u_count`, `u_offset`, and `u_segflg` in `u`. Both `readi` and
`writei` work a block at a time through the buffer cache (#f("bio.c")),
asking `bmap` (#f("subr.c")) where each block of the file lies, and
`iomove` copies the part of a block which is wanted. Character special
files bypass all this and go straight to their drivers. The routine `iomove` is
declared in #f("systm.h"), since #f("mem.c") calls it too.

#lines-to("/*", lead: true)

The routine `readi` refuses a negative offset, which can arise from `seek`, since
that does not check. It marks the access time as due and hands a
character device the whole request. In v7 a negative offset was refused for
every file, but a character device makes of the offset what it will,
and `/dev/kmem` and `/dev/mem` (#f("mem.c")) take it as an address: the
kernel's addresses lie above 0xc0000000, and core on the MP135 machine
too, which as a 32-bit `off_t` are negative. The test (#l("if(u.u_offset < 0 && (ip->i_mode&IFMT) != IFCHR) {", after: "if(u.u_count == 0)")) therefore
exempts character devices. Those which are disks refuse a negative
offset themselves, in `physio` (#f("bio.c")). In v7 the call read
`return((*cdevsw[major(dev)].d_read)(dev))`, returning whatever the
driver returned from a procedure whose value nobody used. Both are
`void` now, so the call and the `return` are separate statements.

#lines-to("do {")

The offset is split into a logical block number and a position within
the block, and `n` is the most that can come from this block. The function `min`,
below, compares as `unsigned`.

For a file, `n` is cut to what remains before the end of the file, and
`bmap` converts the logical block number into a block of the device, and
`dev` is now the device on which the file lies, whereas `i_rdev` (#l("dev = (dev_t)ip->i_un.i_rdev;", after: "ip->i_flag |= IACC;"))
was the device a block special file refers to. For a block special file
the logical block is the physical one, and the following block is the
obvious candidate for read-ahead.

#lines-to("if ((long)bn<0) {")

For a block which was never written, `bmap` returns −1: such a hole in a
file reads as zeros, from a cleared buffer which belongs to no device.
If the previous read of this inode ended in the block before, the
reading is taken to be sequential, and `breada` is asked to start
reading the next block, `rablock`, which `bmap` left as a side effect.
The residue `b_resid` (#l("n = min((unsigned)n, BSIZE-bp->b_resid);")) is nonzero only if the device transferred less than a
whole block, as at the end of a disk.

#lines-to("/*", lead: true)

The routine `writei` follows the same pattern, with the same test of the offset
(#l("if(u.u_offset < 0 && (ip->i_mode&IFMT) != IFCHR) {", after: "register int n, on;")). A write to a character device marks the inode as modified,
so that the times of a terminal show its last use.

#lines-to("if(n == BSIZE)")

A write of a whole block need not read the old contents first, and
`getblk` merely assigns a buffer. A partial write must read the block
so that the rest of it is preserved. The block is written with
`bdwrite` (#l("bdwrite(bp);")), which marks it dirty and releases it. It reaches the
disk when its buffer is reused or at the next `sync`. A file written a
byte at a time thus costs one disk write per block, not one per call.

Only a regular file or a directory grows (#l("if(u.u_offset > ip->i_size &&")). A block special file
has no size of its own. `IUPD` and `ICHG` are set again each time round
the loop. Once would do.

#lines-to("/*", lead: true)

As in v7, `max` and `min` take `unsigned` arguments and return `int`.
Comparing as unsigned matters in `readi` and `writei`: `u_count` is
`unsigned`, and a request for more than the largest `int` must not
appear negative.

#lines-to("/*", lead: true, after: "if(a < b)")

Between the buffer at `cp` and `u_base`, `iomove` moves `n` bytes. There
are two methods, as the comment says. If the other side is in user space
(`u_segflg` not 1) and the count and both addresses are multiples of
`NBPW`, a single `copyin` or `copyout` moves the lot. Otherwise the bytes
go one at a time through `cpass` and `passc` (#f("subr.c")), each of
which checks the user address and counts.

On the PDP-11 the test was for evenness, `NBPW` being 2, and the
machine-language routines moved words. Here `NBPW` is 4, and `copyin`
and `copyout` (#f("mch.s")) likewise move words when both addresses
and the count are multiples of it, so the test is v7's and keeps its
purpose. The comment's "even" is now to be read as a multiple of four.

A `u_segflg` of 2 meant user instruction space, which the PDP-11/45 and /70
kept apart from data space. The ARM has no such division, and
`copyiin` and `copyiout` are names for `copyin` and `copyout`, defined
as macros in #f("systm.h"), so that v7's text is unchanged here and in
`passc` and `cpass`.

The offset is advanced as an unsigned sum (#l("u.u_offset = (unsigned long)u.u_offset + n;")), as `seek` computes it
(#f("sys2.c")). A character device may be read or written at any offset
up to the largest `off_t`, and a signed sum which passes it overflows,
which C leaves undefined. The unsigned one wraps to a negative offset.

#lines-to(none)
#source("/usr/sys/sys/subr.c")

The file #f("subr.c") is a miscellany. Its chief inhabitant is `bmap`, which
defines how a file is laid out on the disk. The rest are the
byte-at-a-time transfer routines `passc` and `cpass`, the dummy entries
for the device switches, and `bcopy`.

The routine `bmap` maps the logical block `bn` of the file `ip` to a block of the
device, allocating one, together with any indirect blocks needed to
reach it, if `rwflg` is `B_WRITE` and none exists yet. When reading, a
missing block is reported as −1, which `readi` (#f("rdwri.c")) turns
into a block of zeros.

#lines-to("/*", lead: true, after: "rablock = 0;")

The first `NADDR-3`, that is ten, addresses in the inode point directly
at data blocks, so a file of up to 5120 bytes needs no indirect block.
A new block comes from `alloc` (#f("alloc.c")) already cleared, in a
buffer which is released at once with `bdwrite`: it will be written
before the buffer is reused, and in the meantime `readi` and `writei`
will find it in the cache. The read-ahead block is the next direct
address, if there is one.

The three kinds of indirect block each have their own address in the
inode, so no file ever changes form as it grows.

#lines-to("/*", lead: true, after: "}")

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

#lines-to("/*", lead: true, after: "}")

The top-level indirect block is found in the inode, or allocated.

#lines-to("/*", lead: true, after: "}")

Each pass of the loop reads one indirect block and picks out the next
address with `sh` and `NMASK`. A block allocated at a lower level is
recorded in the indirect block above it, which is then itself written
with `bdwrite`. An I/O error yields zero rather than −1.

The addresses in an indirect block are `daddr_t`s exactly as they lie in
memory, so their byte order is the ARM's: least significant byte first.
The PDP-11 stored a `long` with its high word first, so the indirect
blocks of a disk made here are not those of a PDP-11 disk, although
there are 128 to a block on both.

`NINDIR` is computed with `sizeof` and is therefore unsigned. The cast
(#l("if((unsigned)i < NINDIR-1)")) makes the comparison with the `int` `i` explicitly unsigned, as
in #f("fio.c"). Since `i` is never negative, the meaning is v7's.

#lines-to("/*", lead: true, after: "return(nb);")

The routine `passc` delivers one character to the place described by `u_base` and
`u_segflg`, and counts it. A `u_segflg` of 1 means a kernel address,
which is stored into directly. Note the conditional expression
(#l("if(id?suibyte(u.u_base, c):subyte(u.u_base, c) < 0) {")): `<` binds more tightly than `?:`, so that only `subyte`'s result
is compared with zero, while `suibyte`'s is tested for being nonzero.
Both return −1 on a fault and zero otherwise, so the two readings agree
and the line, which is v7's, works.

The return of −1 on the last character lets a driver's read routine
stop as soon as the request is satisfied. The offset is counted as an
unsigned sum (#l("u.u_offset = (unsigned long)u.u_offset + 1;", after: "if(id?suibyte(u.u_base, c):subyte(u.u_base, c) < 0) {")), as in `iomove` (#f("rdwri.c")), where the reason is
given, and `cpass` does the same (#l("u.u_offset = (unsigned long)u.u_offset + 1;", after: "if((c = id==0?fubyte(u.u_base):fuibyte(u.u_base)) < 0) {")).

#lines-to("/*", lead: true, after: "}")

The converse, fetching one character of a write, is `cpass`. The mask
(#l("return(c&0377);")) mattered on the PDP-11, where the direct fetch for a kernel
address sign-extended the `char`. On the ARM a `char` is unsigned and
`fubyte` (#f("mch.s")) already returns a value from 0 to 255, so the
mask changes nothing, but it keeps the result right for a compiler whose
`char` is signed.

#lines-to("/*", lead: true, after: "}")

The routines `nodev` and `nulldev` fill the slots of the device switches
(#f("conf.h")) for which a driver has no routine: one makes the
operation an error, the other a no-op. In v7 the same two routines,
declared without parameters, served in every slot, since the
switch tables were arrays of `int (*)()` and C did not check the
arguments. Now each slot has a prototype, and a function put in it must
have that type. Both `nodev` and `nulldev` take a device and a flag, the
arguments of an open or close routine, and so can occupy only those
slots. The parameters are unused, and each is cast to `void` to say
so. Otherwise `-Wextra` would warn of an unused parameter. The new
routines below do the same.

#lines-to("void", lead: true, after: "nulldev(dev_t dev, int flag)")

The other kinds of slot get new routines of their own, `nostrat` for a
block driver's strategy routine, `nordwr` for a character driver's read
and write, `noioctl` for its `ioctl`, `nolioctl` for a line discipline's
`ioctl`, and `nulltty` for the routines which take only a `tty`, such as
a character driver's stop routine and a line discipline's close.

#lines-to("/*", lead: true)

The routine `bcopy` copies a byte at a time. Since the loop tests after the copy, a
count of zero would run on through memory. No caller passes one.

#lines-to(none)
#source("/usr/sys/h/dir.h")

A directory is a file of 16-byte
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

#lines-to(none)
#source("/usr/sys/sys/nami.c")

The file #f("nami.c") holds `namei`, which turns a path name into an inode, and
the two routines from which it takes the name one character at a time.
Every system call that names a file calls `namei`, and so does `core`
(#f("sig.c")), which alone uses `schar`, because the name "core" is a
string in the kernel.

The interface is subtle, and is best summarised by the cases in which
`namei` returns:
- With `flag` 0, the inode of the named file, locked and with its count
  incremented, or `NULL` with `u.u_error` set;
- With `flag` 1 (create), the inode of an existing file, as for 0; or,
  if only the last component is missing and the directory may be
  written, `NULL` with no error, the locked parent directory in
  `u.u_pdir`, the name in `u.u_dbuf`, and `u.u_offset` at the slot for
  the new entry; this is what `maknode` and `wdir` (#f("iget.c")) expect;
- With `flag` 2 (delete), the locked parent directory, with the entry
  in `u.u_dent` and `u.u_offset` just past it, for `unlink`
  (#f("sys4.c")) to clear.

#lines-to("/*", after: "off_t eo;")

The search starts at the root if the name begins with a slash, the root
being the process's own (`u_rdir`, set by `chroot`) if it has one.
Otherwise at the current directory. For an inode which
is certainly in the table already, `iget` is called to lock it and count the reference
which `namei` will hold. Repeated slashes are skipped. An empty name
means the starting directory itself, which cannot be created or
removed.

#lines-to("cloop:")

Each component enters `cloop` once. The component is gathered
into `u.u_dbuf`, silently truncated to `DIRSIZ` characters and padded
with nulls, so that it can be compared with a directory entry as a
whole.

The tests of `!` belong to the multiplexor: a path such as `x!y` named a
channel of a multiplexed file. In this system `mpxip` is never set
(#f("inode.h")), so they are never true.

#lines-to("seloop:")

The directory to be searched must be a directory, and the user must
have execute permission on it, which for a directory means permission
to search. The first empty slot, for `creat`, will be recorded in `eo`.

#lines-to("eloop:")

Each pass of `eloop` examines one entry. Reaching the end of the directory
without a match is an error, except when the last component is to be
created. Then, if the directory may be written, the place for the new
entry is the first empty slot (`eo` is the offset just past it) or, if
there is none, the end of the directory. In the latter case the
directory is about to grow, and is marked as modified (#l("dp->i_flag |= IUPD|ICHG;")).

#lines-to("/*", after: "}")

At each block boundary the next block of the directory is read, through
`bmap` but not `readi`, since the entries are wanted in the buffer rather
than copied to a user. There is no read-ahead.

#lines-to("/*", after: "}")

The entry is copied into `u.u_dent` before it is compared: it is
needed there afterwards, for the inode number and, by `unlink`, for the
whole entry. The comparison is of all `DIRSIZ` bytes, which is why the
component was padded.

#lines-to("/*", after: "goto eloop;")

A match. If this is the last component and the caller wants to delete
it, the parent directory is returned, provided that it may be written.

Otherwise the search descends. The cascade of `if`s (#l("if(u.u_dent.d_ino == ROOTINO)")--#l("if(mount[i].m_dev == d) {")) handles
".." in the root directory of a mounted file system: such a root's ".."
names the root itself, inode `ROOTINO`, and the test of `d_name[1]`
tells ".." from ".", which matches the other two tests as well. The
mount table is searched, from entry 1 since entry 0 is the root file
system, for the file system on this device, and the search for ".."
starts again in the directory on which it is mounted. This is the
converse of the substitution which `iget` (#f("iget.c")) makes when it
meets an inode marked `IMOUNT`.

Note the order at (#l("iput(dp);", after: "goto seloop;"), #l("dp = iget(d, u.u_dent.d_ino);")): the directory is released before the next
inode is fetched, and `d` saves its device. Were the parent still
locked, a lookup of ".." would have `iget` wait for the lock held by
this very process.

#lines-to("/*", lead: true, after: "}")

From kernel space `schar` takes the name, and `uchar` from user space with
`fubyte` (#f("mch.s")), which returns −1 for an address outside the
user's memory. The mask in `schar` undid the sign extension of a PDP-11
`char`. On the ARM `char` is unsigned and the mask is idle.

#lines-to(none)
#source("/usr/sys/h/filsys.h")

The header #f("filsys.h") describes the super-block, block
`SUPERB`, block 1, of every file system. Block 0 is left for a bootstrap. The
i-list, the array of inodes on the disk, occupies blocks 2 up to `s_isize`−1, so that `s_isize` is in
effect the number of the first block which may hold data, and
`badblock` (#f("alloc.c")) checks block numbers against it and against
`s_fsize`. A mounted file system's super-block is kept in a buffer of
its own, found through the mount table (#f("mount.h")), and written back
by `update` when `s_fmod` says that it has changed.

Up to `NICFREE` free blocks and `NICINOD`
free inodes (#f("param.h")) are cached in `s_free` and `s_inode`, and `alloc` and `ialloc` explain how they are
replenished. The locks `s_flock` and `s_ilock` guard the two lists while a process
sleeps in the middle of changing them. They mean nothing on the disk,
and `smount` (#f("sys3.c")) clears them. The programs which examine file systems keep the fields after `s_time`,
not the kernel.

The structure is v7's but for `s_pad` (#l("char   \ts_pad[6];  \t/* reserved, zero */")), and its image on the disk
is not v7's. The compiler lays it out for the ARM: a `long` is stored
least significant byte first, where the PDP-11 put its high word first,
and it is aligned on a four-byte boundary, so that two bytes of padding
follow `s_isize` and `s_nfree`. The time `s_time`, a `time_t` of eight bytes
(#f("param.h")), must begin at a multiple of eight, 424, which the ARM
would reach by padding of its own. But `mkfs` (#f("cmd/mkfs.c")) is
compiled from these same headers by the build machine's compiler, with
their `long` types made `int` (#f("Makefile")), and a compiler which
aligns a `long long` on four, as for the Intel 386, would put `s_time`
at 420. The six bytes of `s_pad` make the hole explicit, so that the
layout is the same for every compiler. The super-block is 456 bytes
here, against 440 on the PDP-11, and a disk written by a PDP-11 could
not be mounted without conversion.

#lines-to(none)
#source("/usr/sys/h/mount.h")

The mount table has one entry for each mounted file system. The pointer `m_bufp`
points to the buffer, taken from the cache by `geteblk` and never
released while the file system is mounted, which holds its super-block.
An entry is free when `m_bufp` is null. The inode of the
directory on which the file system is mounted is `m_inodp`. Entry 0 is the root file
system, filled in by `iinit` (#f("main.c")). Its `m_inodp` is never
used. The routines `smount` and `sumount` (#f("sys3.c")) make and clear the other entries,
`getfs` (#f("alloc.c")) searches the table by device, and `iget`
(#f("iget.c")) and `namei` (#f("nami.c")) by inode, to cross a mount
point downward and upward respectively.

The changes are the word `extern` (#l("extern struct\tmount")) and the empty brackets (#l("} mount[];")). In
v7 the line defined `mount` in every file which included the header,
relying on the linker to merge the copies into one, and C99 makes that
undefined and the compiler no longer accepts it by default. The table
is now defined once, with the size `NMOUNT` which the configuration
gives it (#f("param.h")), in #f("qemu/c.c").

#lines-to(none)
#source("/usr/sys/h/ino.h")

The header #f("ino.h") is the inode as stored in the i-list on the disk, `INOPB`
to a block. The v7 inode was 64 bytes, eight to a block. It is now 128, four to
a block, to hold three times of 64 bits. The macros `itod` and `itoo`
(#f("param.h")) find the block and the position in it of inode `i`.
Inode 1 is the first of block 2, and inode 0 does not exist, a zero in a
directory entry meaning "empty".

Thirteen block addresses are packed into `di_addr`, three bytes each, the
fortieth byte being unused. A block number must therefore be less than
2²⁴, which `iupdat` (#f("iget.c")) checks. The routines `iexpand` and
`iupdat` unpack and pack them.

Up to the times the layout is the PDP-11's: four `short`s bring
`di_size` to offset 8, already a multiple of four, and the forty bytes
of addresses end at offset 52. A `time_t` is now eight bytes, aligned on
eight (#f("param.h")), so the four bytes of `di_pad` (#l("char\tdi_pad[4];\t/* reserved, zero */")) are left
before the times, which occupy offsets 56 to 79. The ARM's compiler
would leave them by itself, but one which aligns a `long long` on four
would not, and `mkfs`, compiled by the build machine's compiler, would
then make inodes of 124 bytes (see #f("filsys.h")). The array `di_spare` (#l("char\tdi_spare[48];\t/* reserved, zero */"))
fills the inode to 128 bytes, and with `di_pad` makes 52 reserved
bytes, zero on every disk: enough for a 64-bit `di_size` should files ever need
one. Nothing reads them, and `mkfs` writes them as zeros, and `clri` and
`restor` clear or copy whole inodes. The comment on `INOPB` (#l("#define\tINOPB\t4\t/* 4 inodes per block */")) has
been corrected for the new value. The byte order is not the
PDP-11's either. A `long` here is stored least significant byte
first, and the three bytes of an address are packed in the same order.
The PDP-11 kept the high word of a `long` first, and its three-byte
addresses accordingly began with bits 16 to 23. The kernel's packing in
#f("iget.c"), the private `ltol3` of `mkfs` (#f("cmd/mkfs.c")), and the
C library's `l3tol` and `ltol3`, used by the programs which examine file
systems, all follow the ARM's order.

#lines-to(none)
#source("/usr/sys/sys/sys3.c")

The file #f("sys3.c") holds `stat`, `fstat`, `dup`, `mount`, and `umount`. The declaration of `stat1` (#l("void\tstat1(struct inode *ip, struct stat *ub, off_t pipeadj);")) is
new: it is called before its definition and from no other file.

#lines-to("/*", lead: true)

Only in how they find the inode do `fstat` and `stat` differ. For a pipe,
`fstat` passes the reader's offset, so that the size reported is the
number of bytes written but not yet read.

#lines-to("/*", lead: true, after: "iput(ip);")

The routine `stat1` fills a `stat` (#f("stat.h")) and copies it to the user. The
in-core inode holds no times (#f("inode.h")), so any times which are due
are first written to the disk inode by `iupdat`, and the three times are
then read back from the disk inode itself, found with `itod` and `itoo`.

#lines-to("/*", lead: true, after: "}")

The system call `dup` returns a second descriptor for an open `file`. In v7 it is overloaded to
provide `dup2` as well: if the descriptor carries the bit 0100, the
second argument names the new descriptor, which is first closed if it
is open. The C library's `dup2` sets the bit. A `dup` of a
descriptor onto itself does nothing (#l("if (i!=uap->fdes) {")).

#lines-to("/*", lead: true, after: "}")

The system call `smount` mounts the block device named by the first argument on the
file named by the second. The routine `getmdev` checks the first, and `u.u_dirp`, which
`trap` (#f("trap.c")) set to the first argument, is then pointed at
the second for `namei`. The file mounted on must be in use by no one
else, so that no process has it open or as its current directory, and
must not be special. Nothing requires it to be a directory, though
anything else would be useless.

#lines-to("smp = NULL;")

The mount table is searched both for a free entry and for an entry for
the same device, which would make the call fail.

The device is opened, for writing unless the mount is read-only, and the
super-block is read and copied into a buffer of its own, obtained with
`geteblk` and held for as long as the file system is mounted. The cached
copy of block 1 is then released like any other. The locks are cleared,
since the copy on the disk may have been written while a list was being
changed. Finally the inode is marked `IMOUNT`, which `iget`
(#f("iget.c")) will notice from now on, and unlocked. Its reference
count stays raised until the unmount.

#lines-to("/*", lead: true)

This is `sumount`. Before the table is examined, `xumount` (#f("text.c")) gives
up the texts kept for sticky programs on the device, and `update`
(#f("alloc.c")) writes out everything modified. If any inode of the
device is still in the table, a file on it is in use and the call
fails.

The structure `a` describes the argument but is never used, since
The routine `getmdev` finds the name through `u.u_dirp`. In v7 it was declared
`register struct a { ... };`, which declares a tag but no variable, so that the
`register` applies to nothing, and the compiler warns of it. The
`register` has gone. The unused declaration is kept as v7's.

#lines-to("/*", lead: true, after: "}")

The routine `getmdev` returns the device number of a block special file, after
checking that its major number is within `bdevsw`.

#lines-to(none)
#source("/usr/sys/h/stat.h")

The header #f("stat.h") holds the structure which `stat` and
`fstat` (#f("sys3.c")) fill in, and user programs see it in `/usr/include/sys/stat.h`, a
copy of this file to which prototypes for the two calls have been added;
the `S_` names repeat the mode bits of
#f("inode.h") for their use.

The kernel and the programs are compiled for the ARM from the same
declaration, so they agree on its layout, which is not the PDP-11's:
`dev_t` is an `int` of four bytes, and two bytes of padding after
`st_gid` align `st_rdev`; the three times, `time_t`s of eight bytes
(#f("param.h")), then fall on eight-byte boundaries, so that a `stat` is
48 bytes rather than 30.

#lines-to(none)
#source("/usr/sys/sys/iget.c")

The file #f("iget.c") manages the in-core inode table (#f("inode.h")). The routine `iget` brings an inode
into it, `iput` lets it go, and `iupdat` writes it back.
The routine `itrunc` frees a file's blocks, and `maknode` and `wdir` create a file
and its directory entry. Two changes are real. The routine `iget` releases an entry whose inode
could not be read, and `iexpand` and `iupdat` pack a block address into
three bytes in a new order.

The declarations (#l("void\tiexpand(struct inode *ip, struct dinode *dp),"), #l("tloop(dev_t dev, daddr_t bn, int f1, int f2);")) are new: `iexpand` and `tloop` are used before
their definitions, and only here.

#lines-to("/*")

The routine `iget` returns the inode `ino` of the device `dev`, locked and with its
reference count incremented. Every inode that a process holds was
obtained here, by `namei` (#f("nami.c")) or `ialloc` (#f("alloc.c")),
or by `main` for the root.

#lines-to("loop:")

The table is searched for the inode. If it is present but locked, the
caller sleeps and then starts the whole search afresh, since while it
slept the entry may have been released and even reused for another
inode.

If the inode is one on which a file system is mounted, the request is
redirected to the root, `ROOTINO`, of the mounted file system, whose
device is found by searching the mount table (#f("mount.h")) for the
entry which points back at this inode. This is how a path descends
through a mount point, and `namei` handles the climb back up through "..".

Meanwhile the first free entry, one with no references, has been noted
in `oip`.

#lines-to("ip = oip;")

If the inode is not in the table, the free entry is claimed and locked,
and the block of the i-list which holds the inode is read. If the read
fails, the entry is released and `NULL` is returned. The caller finds
the error in `u.u_error`, set by the buffer routines.

The entry still holds the link count, mode, and addresses of its
previous inode, nothing yet having been read into it. In v7 a count of
zero, left by a deleted file or never set in an unused entry, made
`iput` treat the inode which could not be read as one with no links:
it would free `ino` to the super-block's list, and write a cleared
inode over it if a second attempt to read the block succeeded. Setting
the count to one (#l("ip->i_nlink = 1;", after: "if((bp->b_flags&B_ERROR) != 0) {")) first makes `iput` simply release the entry.

#lines-to("void", lead: true)

The routine `iexpand` copies the disk inode (#f("ino.h")) into the table entry,
unpacking each three-byte block address into a four-byte `daddr_t`.

The PDP-11 stored a `long` as two words, the high word first, each word
with its low byte first. In v7 the first byte of an
address was therefore copied into bits 16 to 23, a zero put into bits 24 to 31, and
the other two bytes copied into bits 0 to 15. On the ARM a `long` is stored
least significant byte first, so the port copies the three bytes into
the low three bytes of the `daddr_t` and the zero into the top one, the
zero having moved from second place to last. The disk format of the
addresses has changed with it: bits 0 to 7 come first. The program `mkfs` builds
file systems in the same order (#f("cmd/mkfs.c")).

#lines-to("/*", lead: true)

The routine `iput` releases a reference. The last reference does the real work. If
the file has no links left, `itrunc` frees its blocks, its mode is cleared to mark the disk inode
free, and `ifree` returns its number to the super-block's list (#f("alloc.c")). In either case the inode
is written back if it has changed, and the entry is cleared.

The inode is locked during this, since `itrunc` and `iupdat` may sleep
on the disk, and `prele` is called twice, once to wake any process which
waited on the dying entry, and once for every release. A file which is
unlinked while open thus survives until its last close, which is the
basis of the convention for temporary files.

#lines-to("/*", lead: true, after: "}")

The routine `iupdat` writes an in-core inode back into its block, provided that one
of the flags says it has changed and the file system is not mounted
read-only. The access and modification times are taken from the
arguments, which lets `utime` (#f("sys4.c")) set arbitrary times. The
change time is always the present. The block is released with
`bdwrite`, so the write itself is deferred.

The packing of the addresses is the reverse of `iexpand`, and has
changed in the same way: the three low bytes are copied, and it is now
the fourth byte, the most significant, which is checked. A nonzero
value there means a block number too large to record. For a
multiplexed file the addresses held other data and were exempt. Such
files do not exist here.

#lines-to("/*", lead: true, after: "}")

The routine `itrunc` frees every block of a regular file or directory, while a special
file's first address is its device number and the rest are meaningless.
The addresses are freed from the last to the first, so that the blocks
are pushed onto the free list in reverse and will be allocated again in
their original order, as the comment explains. The three indirect
addresses are handed to `tloop` with flags which give their depth.

#lines-to("void", lead: true, after: "}")

The routine `tloop` frees the blocks listed in an indirect block, recursively if
`f1` says that they are themselves indirect, and then the indirect
block itself. The buffer is released before each recursive call, and
read again afterwards, so that a deep file does not hold several
buffers at once. Since the cache usually still holds the block, the
second reading costs little.

The entries of an indirect block are read as `daddr_t`s in the ARM's
byte order, as `bmap` (#f("subr.c")) wrote them.

#lines-to("/*", lead: true)

The routine `maknode` creates a file for `creat`, `mknod`, and `core`, after a call
of `namei` with flag 1 has left the parent directory in `u.u_pdir`. The
inode is allocated on the parent's device, given the requested mode
less the bits in the process's `umask`, and entered in the directory by
`wdir`. A mode with no type makes a regular file.

#lines-to("/*", lead: true, after: "}")

The routine `wdir` writes the directory entry: the new inode number and the name
which `namei` left in `u.u_dbuf`, at the offset which `namei` left in
`u.u_offset`, through `writei` with a kernel address. If the directory
has been removed since it was searched, it has no links, and the entry
is refused. Either way the directory is released.

#lines-to(none)
#source("/usr/sys/h/fblk.h")

The header #f("fblk.h") describes the first words of a
block in the chain of free-block lists: when the super-block's list
`s_free` is full, `free` (#f("alloc.c")) writes the count and the list
into the block being freed, in this form, and starts a new list with
that block alone, and `alloc` reads them back when the list is exhausted.

The count `df_nfree` is an `int`, two bytes on the PDP-11 and four here, so that
the addresses begin at byte 4 of the block rather than byte 2. Like
the super-block and the indirect blocks, these blocks are laid out as
the ARM lays out the structure.

#lines-to(none)
#source("/usr/sys/sys/alloc.c")

The file #f("alloc.c") allocates and frees the two resources of a file system,
disk blocks and inodes, using the lists kept in the super-block
(#f("filsys.h")). It also holds `getfs`, which finds the super-block of
a mounted device, and `update`, the body of `sync`. The declaration of `badblock` (#l("int\tbadblock(struct filsys *fp, daddr_t bn, dev_t dev);")) is new:
it is called before its definition, and only here. `FBLKP` lets a buffer
be viewed as a `struct fblk` (#f("fblk.h")).

#lines-to("/*")

The free blocks of a file system form a chain of lists. The super-block
holds up to `NICFREE` free block numbers in `s_free`. The first of these
names a block which holds the previous `NICFREE` numbers, the first of
which names another such block, and so on. The first entry of the last
list is zero, which marks the end. Only the top of the chain is in
core, and both ends of the operation work on the top: `alloc` takes the
last number in `s_free`, `free` adds one there.

First, `alloc` waits while another process is refilling the list.

#lines-to("do {")

A number is taken from the list. A count out of range, or the
terminating zero, means that the file system is full. A number outside
the data area, which is what a damaged or foreign file system would
yield, is skipped, and `badblock` reports it.

#lines-to("if(fp->s_nfree <= 0) {")

If that was the last number in `s_free`, the block it names holds the
next list, which is read into the super-block before the block is handed
out, and `s_flock` makes any other `alloc` or `free` wait while the read is
in progress. The block itself then becomes the one allocated.

#lines-to("bp = getblk(dev, bno);")

The new block is given to the caller in a cleared buffer, obtained with
`getblk` since its old contents do not matter. The clearing is what
makes a new indirect block contain no addresses and a new directory
block contain only empty entries. The flag `s_fmod` tells `update` that the
super-block must be written.

On failure the count is set to zero, so that later calls fail at once.

#lines-to("/*", lead: true)

The converse is `free`. A list emptied by `alloc` at the end of the
chain is restarted with the terminating zero. If the list is full, it
is written, with its count, into the block being freed, which thereby
becomes the head of the chain, and the list starts again with that
block alone. Unlike most writes of the file system, this one is
synchronous (`bwrite`).
The flag `s_fmod` is set both at the start and at the end, though the second suffices.

The layout of the block is that of `struct fblk` on the ARM: a four-byte
count followed by `NICFREE` four-byte addresses, all in the ARM's byte
order.

#lines-to("/*", lead: true, after: "}")

The routine `badblock` checks that a block number lies between the end of the
i-list and the end of the file system.

#lines-to("/*", lead: true, after: "}")

The routine `ialloc` allocates an inode. Free inodes are handled differently from
free blocks: the super-block caches up to `NICINOD` free inode numbers,
but there is no chain. A free inode is recognised on the disk by its
mode of zero, and when the cache is empty the i-list is simply searched
for more.

#lines-to("if(fp->s_ninode > 0) {")

A number is taken from the cache, and the inode is fetched with `iget`.
Inode 1 is never allocated: v7 reserved it, and `ROOTINO`, 2, is the
root. The cache may be out of
date, since `ifree` adds numbers without any check, so the mode is
examined: if it is still zero the inode is the caller's, with its
addresses cleared. Otherwise the next number is tried. The caller fills
in the mode, which marks the inode as allocated.

#lines-to("fp->s_ilock++;")

The search of the i-list starts at block 2, inode 1. An inode which is
free on the disk may yet be in the inode table: just allocated and not
yet written back, or in the course of being released. Such inodes are
skipped. The lock `s_ilock` keeps other allocations, and `ifree`, out while the
search proceeds, since `bread` may sleep.

#lines-to("/*", lead: true)

The routine `ifree` returns an inode number to the cache, unless the cache is full
or being refilled. A number which is dropped is not lost: the next
search of the i-list will find the inode, since `iput` (#f("iget.c"))
has cleared its mode.

#lines-to("/*", lead: true, after: "}")

The routine `getfs` finds the super-block of a mounted device in the mount table
(#f("mount.h")). It also repairs nonsensical counts, so that a corrupted
super-block causes a "no space" message rather than an access beyond the
lists.

#lines-to("/*", lead: true, after: "}")

The routine `update` is called by the `sync` system call (#f("sys4.c")), by
`sumount` (#f("sys3.c")), and by `panic` (#f("prf.c")). In normal
running the program `/etc/update` calls `sync` every thirty seconds.
The lock `updlock` keeps two updates from running at once. It starts locked,
and `main` (#f("main.c")) clears it once `binit` has made the buffers,
so that a panic during startup does not walk lists which do not yet
exist. On the MP135 machine they are in DDR, which may not yet work.

Each modified super-block is stamped with the time and written: the
whole block is copied from the private buffer of the mount table into a
buffer for block 1, obtained with `getblk` since its old contents are
not wanted. A super-block whose lists are locked is
passed over until the next time, since its contents may be half
changed. Then each inode which is in use and not locked is written with
`iupdat`. The extra reference keeps `iput` from treating the call as the
last release. Finally `bflush` (#f("bio.c")) starts the writing of every
delayed-write buffer.

#lines-to(none)
#source("/usr/sys/sys/pipe.c")

Pipes are implemented in #f("pipe.c"). A pipe is an ordinary inode, allocated on
the device `pipedev` (the root device, on both machines, by the `c.c`
which `mkconf` writes) but entered in no directory, and opened twice: by
one `file` for reading and by another for writing. Data written to the pipe is appended to the file, and the reader reads
from its own offset. When the reader catches up, the file is emptied. Since the file stays
small and is soon read, its blocks normally live only in the buffer
cache, but nothing prevents them from being written to the disk.

`PIPSIZ` bounds the size of the file. Ten direct blocks hold 5120 bytes,
which is the limit of the comment. A larger pipe would need an indirect
block for every access.

#lines-to("/*", after: "#define\tPIPSIZ\t4096")

The system call `pipe` allocates the inode and two `file`s. Each `falloc` leaves its
descriptor in `u.u_r.r_val1`, so the first is saved in `r`. At the end
the read descriptor is returned in r0 and the write descriptor in r1,
by way of `r_val2`, which `trap` (#f("trap.c")) copies to the caller's
r1. The C library's `pipe` stores the two in the caller's array.

The routine `ialloc` returns the inode locked, but no `prele` follows: the
assignment to `i_flag` (#l("ip->i_flag = IACC|IUPD|ICHG;")) clears `ILOCK` along with everything else.
The reference count is 2, one for each `file`, and the link count stays
0, so that the inode and its blocks are freed by `iput` (#f("iget.c"))
when both ends are closed.

#lines-to("/*", lead: true, after: "}")

This is `readp`. The inode is locked for the whole of each operation, as the
comment says, very conservatively. If the pipe is empty, the reader
waits for data, having first unlocked the inode. A reference count
below 2 means that the write side is closed, and the read returns
nothing, which the program takes as the end of file. Otherwise the
reader marks its wait by setting `IREAD` in the mode, a bit the pipe
can spare since its mode is never checked for permission, and sleeps
on the address `ip+2`. `PPIPE` is above `PZERO`, so the sleep may be
broken by a signal.

#lines-to("/*", after: "}")

The data is read with `readi` from the reader's own offset, the one in
its `file`. If everything has been read, both the offset and the size
are set back to zero: the next write will start again at the beginning
of the file, reusing the same blocks, which are probably still in the
cache. A writer waiting for room is then woken, on `ip+1`.

#lines-to("/*", lead: true, after: "}")

The routine `writep` writes in pieces of at most `PIPSIZ` bytes, waiting between
them for the reader. What remains is counted in `c`. If the read side has
gone, the writer is sent `SIGPIPE`, which by default kills it, and the
call fails with `EPIPE`. A program which ignores the signal sees the
error.

#lines-to("/*", lead: true, after: "psignal(u.u_procp, SIGPIPE);")

A full pipe makes the writer set `IWRITE` and sleep on `ip+1` until
`readp` empties it.

#lines-to("/*", after: "}")

The write always goes at the end of the file, at `i_size`, whatever the
offset in the writer's `file`. As the comment says, a pipe which is not
full accepts a whole piece of up to `PIPSIZ` bytes, and so may grow to
almost twice `PIPSIZ`. Afterwards a waiting reader is woken.

The function `min` (#f("rdwri.c")) takes `unsigned` arguments, and the casts (#l("u.u_count = min((unsigned)c, (unsigned)PIPSIZ);"))
only make that conversion explicit. They are v7's.

#lines-to("/*", lead: true, after: "}")

The lock on an inode in general, not only for
pipes, is `plock` and `prele`: whoever finds it locked sets `IWANT` and sleeps on the inode's
address, at `PINOD`, which is below `PZERO`, so that no signal can
interrupt the wait. The routine `prele` wakes all such sleepers, and the first to
run takes the lock. The others find it locked again and go back to
sleep.

#lines-to(none)

== Character Devices <ch-chardev>

#source("/usr/sys/dev/sys.c")

The driver for `/dev/tty`, major device 17 in the
character switch of #f("qemu/c.c"), is #f("sys.c"). It drives no hardware. A process
which opens `/dev/tty` is given its controlling terminal, whatever that
happens to be, so that a routine such as `getpass` can talk
to the user even when its standard input and output have been
redirected.

The controlling terminal is recorded in `u.u_ttyp` by
`ttyopen` (#f("tty.c")) when a process with no process group opens a
terminal, and is inherited across `fork`. Each routine here ignores its
own device number, casting it to `void` to say so (#l("(void)dev;", after: "syopen(int dev, int flag)")), and calls the
corresponding routine of the real
driver with the terminal's own number, `t_dev` (#f("tty.h")), in its place, so that the real driver sees its
own minor device. A process without a controlling terminal is refused
with `ENXIO` (#l("u.u_error = ENXIO;")).

There is no close routine: the switch has `nulldev` in that slot. The
real terminal's close routine is called only when the last file open on
the terminal itself is closed, and a file open on `/dev/tty` does not
count among those.

The include of #f("systm.h") (#l("#include \"../h/systm.h\"")) is new. It holds the prototypes of
`syopen` and its companions, which `-Wmissing-prototypes` requires to be
in sight before the definitions, and against which the compiler checks them.

#lines-to("void", lead: true, after: "}")

The other three routines follow the same pattern. The routine `sysioctl` passes on
the command and its argument unchanged, so that `stty`, which acts
on its standard output, works as well when that output is `/dev/tty`.

#lines-to(none)
#source("/usr/sys/dev/mem.c")

The driver for the memory special files, major device 8, is #f("mem.c").
Through it a program such as `ps` reads the kernel's tables, and a
privileged user may inspect or patch the running system. Minor device
2, `/dev/null`, discards what is written to it and returns end of file
at once.

The lone `#` (#l("#", before: "*\tMemory special file")) dates from the time when the C compiler passed a file
through the preprocessor only if its first character was `#`. In C99
it is a null directive and does nothing.

The include of #f("systm.h") (#l("#include \"../h/systm.h\"")) is new. It declares `fumem`, `sumem`,
`devaddr`, `iomove`, `passc`, and `cpass`, and the prototypes of the
two routines here. The header #f("buf.h") (#l("#include \"../h/buf.h\"")) is included for `B_READ` and
`B_WRITE`.

#lines-to("void")

The routine `mmread` copies bytes, one at a time, from memory at the file offset
to the user, until `passc` (#f("subr.c")) reports that the request is
satisfied or `fumem` (#f("machdep.c")) finds that the offset names no
memory. The second case is an error, `ENXIO`.

In v7 the offset could not simply be dereferenced. The PDP-11 kernel had only
64 KB of address space, so for each byte `mmread` raised the priority
to 7, borrowed the first user segmentation register, set it to the
64-byte click containing the offset, fetched the byte with `fuibyte`
through that segment, and put the register back. For minor device 1 the
click was first translated through the kernel's own segmentation
registers (`ka6`), so that the offset was a kernel virtual address
rather than a physical one. The borrowing has gone: the ARM kernel maps
the kernel image and the whole of core at fixed addresses, so
`memaddr` in #f("machdep.c") need only turn the offset into one of
them, and the driver passes it the device for that purpose. The
distinction between the minor devices survives: in `/dev/mem` the
offset is a physical address, so that a process image is found at
offset `p_addr` times 4096, the size of a page. In `/dev/kmem` it is a
kernel address, so that a kernel variable is found at the address which
`nlist` reports for it. Since the two differ on both machines
(@ch-intro), `ps` reads the kernel's tables from `/dev/kmem` and the
images from `/dev/mem`, where v7's read both from `/dev/mem`, whose
offsets on the PDP-11 were the same for the kernel's data.

Both files also reach the registers of the devices which the kernel
maps, `/dev/mem` at their physical addresses and `/dev/kmem` at the
kernel's, and `devaddr` (#f("machdep.c")) turns either into a kernel
address. On the PDP-11 these were simply the top 8 KB of
the physical address space, read like memory. A device register must be
read and written whole, in one access of its own width, and a read may
itself change the device, so the bytewise loop will not do. An offset in
a device's block is therefore served a word at a time (#l("if(devaddr(dev, u.u_offset)) {", after: "mmread(int dev)")--#l("}", before: "do {")): `fkword` (#f("mch.s")) reads
each 32-bit word once, and `iomove` (#f("rdwri.c")) passes it to the
user. A 2 MB block of device space may have holes where no device
answers, and a read there aborts. Through `nofault` (#f("mch.s"))
`fkword` turns the abort into a failure, which the driver reports, where
a plain load would have panicked the kernel. The request must be word-aligned and
a whole number of words, and must stay within mapped device space. What
cannot be served so is refused with `ENXIO`. This is how the programs
which reset the board and serve its watchdog from user space reach the
watchdog's registers.

#lines-to("void", after: "}")

The converse is `mmwrite`. The routine `cpass` (#f("subr.c")) fetches the next byte
from the user and has already advanced `u.u_offset` when it returns,
hence the `-1` (#l("if (sumem(dev, u.u_offset-1, c) < 0)")). The writes are checked as the reads are: `sumem`
shares `memaddr` with `fumem`, so that a byte is stored at the address
from which a read at the same offset would fetch it, and an offset which
names no memory is refused rather than stored through. Device registers
are written a word at a time (#l("if(devaddr(dev, u.u_offset)) {", after: "u.u_count = 0;")--#l("}", before: "for(;;) {")), as they are read.

#lines-to(none)
#source("/usr/sys/sys/prim.c")

The file #f("prim.c") manages the character lists, or clists, in which the
terminal drivers queue characters on their way in and out. Apart from
the C99 dressing, only the declarations at the head of the file have
changed. What deserves attention
is that a scheme designed around the sizes of the PDP-11 works
unaltered on a machine with four-byte pointers.

A clist (#f("tty.h")) is a count and two character pointers: `c_cf` to
the first character in the queue and `c_cl` just past the last. The
characters themselves are held in a chain of `cblock`s (#f("tty.h")), each a link
followed by `CBSIZE` characters. Free blocks are chained through the
same link from `cfreelist`.

The whole scheme rests on an invariant: every `cblock` begins at an
address which is a multiple of `CROUND+1`. On the PDP-11 a block was a
two-byte link and 14 characters. Here it is a four-byte link and 12
characters (#f("param.h")), so a block is still 16 bytes long, and
`CROUND` is still 017. A character pointer whose low four bits are zero
therefore points just past the end of a block (since the first
character of a block lies at offset 4, never at offset 0), and the block
containing any character is found by clearing those four bits. No
block needs to record how full it is.

The pool `cfree` (#l("extern struct\tcblock\tcfree[];")) of `NCLIST` blocks is fixed in size. The configuration defines it and sets `NCLIST` (#f("qemu/c.c")), and only
declared here. Calls of `ndflush` with an impossible
count are counted in `cbad` (#l("int\tcbad;")), which nothing reads.

#lines-to("/*")

The routine `getc` removes and returns the first character of a queue, or −1 if it
is empty. All the procedures in the file run with the IRQ masked
(`intr_disable`, v7's `spl6`), since the queues are shared with the
interrupt routines.

The mask with `0377` (#l("c = *p->c_cf++ & 0377;")) mattered on the PDP-11, whose characters were
signed: without it the character 0377, which #f("tty.c") uses as a line
delimiter, would have been returned as −1 and mistaken for an empty
queue. On the ARM `char` is unsigned and the mask changes nothing.

When the count reaches zero (#l("if (--p->c_cc<=0) {")), the block holding the character just
taken is freed, and both pointers are cleared. Otherwise, if `c_cf` has
just stepped past the end of a block (#l("} else if (((int)p->c_cf & CROUND) == 0){")), the block is freed and
`c_cf` moves to the first character of the next. The casts of pointers
to `int` (#l("bp = (struct cblock *) ((int)bp & ~CROUND);"), #l("} else if (((int)p->c_cf & CROUND) == 0){")) were safe on the PDP-11 because both were 16 bits.
They are equally safe here, where both are 32.

#lines-to("/*", lead: true, after: "}")

The routine `q_to_b` moves up to `cc` characters from a queue to a buffer, freeing
blocks as it goes, and returns the number moved. It was used by v7's
multiplexed files (`mx2.c`), which are not part of this system. Nothing
here calls it. The v7 version returned from an empty queue with
interrupts still masked. The port restores the caller's level
first (#l("intr_restore(s);", after: "char *acp;")).

#lines-to("/*", lead: true, after: "}")

The routines `ndqb` and `ndflush` serve a driver which transmits by DMA, such as
the DH11 driver `dh.c` of v7. The first returns the number of characters which
lie contiguously in the first block of the queue, stopping, if `flag`
is `0200`, before the first delay character. The driver hands that
stretch of memory to the device, and when the transfer is done
`ndflush` removes it from the queue. The negative counts which both
accept belong to v7's packet driver (`pk1.c`, `pk2.c`), which used them
to record how many bytes it still expected. None of these drivers is
part of this system, and neither procedure is called.

#lines-to("int", after: "}", exact: true)

The routine `putc` appends a character to a queue, returning 0, or −1 if no block
is free. A new block is needed if the queue is empty (#l("if ((cp = p->c_cl) == NULL || p->c_cc < 0 ) {")), or if
`c_cl` lies just past the end of the last block (#l("} else if (((int)cp & CROUND) == 0) {")). In the second
case the free block is linked into the chain through the old block's
link before `cfreelist` is tested, so that a failure leaves the old
block's link `NULL` as before. The callers in #f("tty.c") mostly ignore
the result. A character for which there is no room is lost.

#lines-to("/*", lead: true)

The routine `b_to_q` appends `cc` characters from a buffer and returns the number
which did not fit. The routine `canon` (#f("tty.c")) uses it to move an edited line
to the canonical queue.

#lines-to("/*", lead: true, after: "}")

The routine `cinit`, which `main` calls once, builds the free list. The C compiler aligns `cfree` only as
strictly as a pointer requires, so its start is rounded up to a
16-byte boundary (#l("ccp = (ccp+CROUND) & ~CROUND;")) and as many whole blocks as fit are put on the
free list. When `cfree` was not already aligned, one block is lost.

The second loop counts the entries of `cdevsw` (#f("qemu/c.c")) up to
the terminating entry with no open routine. Every unconfigured slot is
filled with `nodev`, which is not zero, so `nchrdev` counts them too, and
`openi` (#f("fio.c")) uses it to reject an impossible major number,
and an unconfigured one fails in `nodev`.

#lines-to("/*", lead: true, after: "}")

The routines `getw` and `putw` move a 16-bit quantity, as the comment says. The
words of this machine are wider, but it does not matter. In v7 only
the multiplexed files called `putw`, to queue events and their values,
and nothing called `getw`. Here neither is used.

#lines-to(none)
#source("/usr/sys/dev/partab.c")

The table `partab` has one entry for each of
the 128 ASCII characters, and each entry carries two pieces of
information. The top bit, `0200`, is the bit which gives the character
even parity. The low bits classify the character for `ttyoutput`
(#f("tty.c")), which computes the column and the delay after it from the class. The
class is 0 for a printing character, 1 for one which does not move the
carriage, 2 for backspace, 3 for newline, 4 for tab, 5 for vertical
motion (form feed), and 6 for carriage return. Vertical tab (013) is
classed as non-printing.

The `kl.c` of v7 added the parity bit to each character as it sent it. The
port's console drivers send the character as it is (#f("pl011.c")), so
only the classification is used now. On the PDP-11 an entry with the
top bit set was a negative `char`. The table is now `unsigned char`, so
that its values, 0200 and above, need no change whether or not the
compiler's `char` is signed, and `ttyoutput` masks the entry with `077`
before using it in any case.

#lines-to(none)
#source("/usr/sys/h/tty.h")

The header #f("tty.h") declares the structures shared by the terminal drivers and
the common terminal code of #f("tty.c"), together with the modes, state
bits, and `ioctl` commands which they use.

The `clist` is the head of a character queue, whose blocks #f("prim.c") manages. The comment's "4-word blocks" remains true in a new
sense: a block is now four 32-bit words, where on the PDP-11 it was
eight 16-bit ones. A `clist` itself has grown from six bytes to twelve.

The block itself, `struct cblock` (#l("struct cblock {")--#l("};", after: "char\tc_info[CBSIZE];")), was private to #f("prim.c")
in v7. It has moved here because the pool of blocks, `cfree`, is now
defined by the configuration, at the size `NCLIST` which it gives
(#f("qemu/c.c")), and its definition must see the structure.

#lines-to("/*", lead: true, after: "};")

The special characters which v7 made settable through
`TIOCSETC` are interrupt, quit, the stop and start characters for output, end of
file, and an extra input delimiter, held in `struct tc`. The user's view of the same
six bytes is `struct tchars` in `sgtty.h`. The drivers named in the
comment are v7's. In this system the only one is the console, whose
drivers (#f("pl011.c"), #f("usart.c")) still use `kl11` as the
name of the `tty` array.

#lines-to("struct tty")

There is one `tty` for each terminal line. It contains three queues, of characters as they arrive from the device
(`t_rawq`), of lines after erase and kill processing (`t_canq`), and of
characters waiting to be sent (`t_outq`). The driver's routine to start output, which
`ttstart` (#f("tty.c")) calls, is `t_oproc`.

Several fields serve devices which this system lacks. The field `t_chan` belonged to the multiplexed files and is always `NULL`, and `t_iproc`, `t_linep`,
and `t_addr` are not used (v7's `kl.c` kept the device's address in
`t_addr`, but the console's registers are at a fixed address). The union `t_un` holds
the special characters or, when the state bit `CNTLQ` is set, a fourth
queue. Nothing here sets that bit. The new queue `t_holdq` (#l("struct\tclist t_holdq;\t/* input held by the driver */")) holds
the console's input while the raw queue cannot take it (`TTHOLD`
below), and since it belongs to the terminal, `flushtty` (#f("tty.c"))
empties it with the other queues.

Two changes were forced by C99. The procedure pointers (#l("/* routine to start output */"), #l("/* routine to start output */")) now
have prototypes, and return nothing, matching the routines stored in
them. The union (#l("union {")--#l("} t_un;")) in v7 contained `struct tc;`, a structure with
no member name. The v7 compiler kept all member names in one table and
let any of them be applied to any structure, so `tp->t_un.t_intrc`
reached the first byte of the union without further ado. C99 does not
allow this: a structure without a name declares no member at all, and
C99 has no anonymous members. The structure is therefore given the
member name `tc`, and the shorthand `tun` (#l("#define\ttun\ttp->t_un.tc")), through which every use
in #f("tty.c") is written, now includes it, so that `tun.t_intrc` is
unchanged in the source.

#lines-to("/*", after: "#define\ttun\ttp->t_un.tc")

The argument of `TIOCGETP` and `TIOCSETP` is `struct ttiocb`, which
corresponds to `struct sgttyb` in `sgtty.h`. Because `ioc_flags` is an `int`,
the structure has grown from six bytes to eight. Since the kernel and
the user programs agree on the size of `int`, nothing else follows.

#lines-to("#define\tTTIPRI\t28")

The sleep priorities `TTIPRI` and `TTOPRI` are above `PZERO`
(#f("param.h")), so a process waiting for a terminal can be interrupted
by a signal. The default erase and kill characters are still `#` and
`@`. `TTHIWAT` and `TTLOWAT` bound the output queue: a writer sleeps when
it holds more than 100 characters and is woken when it has fallen to 50.
When the raw queue exceeds `TTYHOG` characters, all the queues are
thrown away (`ttyinput`, #f("tty.c")). `TTHOLD` (#l("#define\tTTHOLD(tp)\t((tp)->t_rawq.c_cc >= TTYHOG && \\"), #l("((tp)->t_delct || (tp)->t_flags&(RAW|CBREAK)))")) is new: it is
true when the raw queue has reached `TTYHOG` and holds something the
reader can take, a complete line or, in `RAW` and `CBREAK` modes, any
character. The console's drivers then hold further input on
`t_holdq` (`ttyhold`, #f("tty.c"), and #f("pl011.c")), so that a long paste
waits instead of being lost. `TTHOLDQ` (#l("#define\tTTHOLDQ\t(NCLIST*CBSIZE/3*2)")), also new, bounds that
queue at two thirds of the characters which the `NCLIST` blocks
(#f("param.h")) can hold, the rest being left for the other queues.
`CBRK` (#l("#define\tCBRK\t(char)0377")), the default extra delimiter, is a byte of all ones, which
matches no character: input is tested against the delimiters only in
cooked mode, after its top bit has been stripped. The value is now cast
to `char`, the type of `t_brkc`, since a compiler whose `char` is signed
must otherwise change the constant 0377 to store it.

The modes are those of `stty`. `NLDELAY`, `TBDELAY`, `CRDELAY`, and
`VTDELAY` are fields which select a terminal type for the output delays
in `ttyoutput`, and `XTABS` is the value of the tab field which asks for
tabs to be expanded into spaces. `DONE` and `IENABLE` are the status
bits of a DEC serial interface. Nothing in this system uses the
definitions here. Of the state bits, `XCLUDE` and `HUPCLS` may be set by
`ioctl`, but only v7's drivers for other interfaces (`dc.c`, `dh.c`, and
`dz.c`) acted on them, and
the console's driver ignores them, and `DKCMD` to `DKLINGR` belong to the
datakit and are never set.

#lines-to("/*", after: "#define\tCNTLQ\t0100000\t\t/* interpret t_un as clist */")

The `ioctl` commands encode a letter for the class of device and a
number. The `t` commands are carried out by `ttioccomm` (#f("tty.c")),
and `FIOCLEX` and `FIONCLEX` by `ioctl` itself. Of the `d` commands,
which are the datakit's, `ttioccomm` passes `DIOCGETP` and `DIOCSETP` to
the line discipline, which here rejects them. The `x` commands are the
multiplexor's.

#lines-to(none)
#source("/usr/sys/dev/pl011.c")

The console driver of the QEMU machine is #f("pl011.c"). It
takes the place of v7's `kl.c`, the driver for the DEC KL11 and DL11
single-line serial interfaces, and it has been kept as close to
`kl.c` as the hardware allows: the file keeps `kl.c`'s comment, its
order, its procedure names (`klopen`, `klread`, `klstart`, and so on),
and its `tty` array `kl11`, so that the character switch in
#f("qemu/c.c") names the console's routines exactly as v7's did. The
MP135 machine's console driver, #f("usart.c"), defines the same names
and keeps as much of `kl.c`. Each machine's kernel
links only its own.

The hardware is an ARM PrimeCell PL011 UART. Where the KL11 had four
registers on the UNIBUS (receiver status and data, transmitter status
and data), the PL011 has a single data register `UARTDR` for both
directions, a flag register `UARTFR` which tells whether the
transmitter has room, and three interrupt registers, the mask (`UARTIMSC`), the masked status
(`UARTMIS`), and the clear register (`UARTICR`). The KL11 held one character in each direction. The PL011
has a receive and a transmit buffer ("FIFO") of 16 or more characters
each, disabled after reset, and the driver enables them (#l("UARTLCRH = 0160;")). Then the
UART goes on taking in characters while the processor is busy
elsewhere, with interrupts masked or in another interrupt, and the driver moves several characters at each interrupt, as typing
ahead at speed, or a paste into the console, needs.

#lines-to("/* base address */")

`KLADDR` (#l("#define\tKLADDR\t0xF0200000")), the console's address, is no longer a pointer to a
`struct device` but the kernel address at which the kernel maps the
UART, `0xf0200000`. Its physical address is `0x09000000`
(#f("qemuconf")). The register macros (#l("#define\tUARTDR\t(*(volatile int *)(KLADDR+0x00))")--#l("#define\tUARTICR\t(*(volatile int *)(KLADDR+0x44))")) are built on it.
Each is `volatile`, since a read of `UARTDR` removes a character from
the receiver and a write sends one, and `UARTLCRH` is the line control
register. `RXFE` and `TXFF` (#l("#define\tRXFE\t020"), #l("#define\tTXFF\t040")) are the flags "receive FIFO empty"
and "transmit FIFO full", and `RXI`, `TXI`, and `RTI` are the receive,
transmit, and receive timeout interrupt bits.

 `KLBASE` and `DLBASE`, the addresses of
further KL11s and DL11s, the receiver bits `DSRDY` and `RDRENB`, and
the delay bits `NL1` to `TAB1` are no longer used (of the delay bits v7
used only `CR2`, in `klopen`). They remain because they still compile. `DLDELAY` is still added to
every output delay (#l("timeout(ttrstrt, (caddr_t)tp, (c&0177) + DLDELAY);")).

#lines-to("struct\ttty kl11[NKL11+NDL11];")

The declarations of `ttrstrt` and `partab` have gone: the first is in
#f("systm.h") with a prototype, and the second is no longer used here.
Since `klread` now calls `klrint` before its definition, it is declared (#l("static void\tklrint(dev_t dev);")).
The variable `klirq` (#l("int\tklirq = 33;")) holds the console's interrupt number at the
interrupt controller, which `intrtab` (#f("qemu/c.c")) reaches through a pointer, and
33 is shared peripheral interrupt 1, to which QEMU wires the UART.
In v7, `struct device` described the KL11's registers. It is now unused.

#lines-to("void", after: "};")

The routine `klopen` no longer computes the device's address and stores it in
`t_addr`: there is only one line, and its registers are at a fixed
address. Where `kl.c` set the interrupt enable bits in the receiver and
transmitter status registers, `klopen` unmasks the receive, transmit,
and receive timeout interrupts in `UARTIMSC` (#l("UARTIMSC = RXI|TXI|RTI;")).

The default modes differ from v7's, which assumed an upper case terminal
(`LCASE`) needing a delay after carriage return (`CR2`). The port
leaves both out. With `LCASE` the console prints every letter in upper
case and the shell's `|` as `\!`, since `ttyoutput` (#f("tty.c"))
maps them for a terminal that has no lower case. With `CR2` each
carriage return is followed by a delay of 10 ticks, which with
`DLDELAY` makes 14 ticks, 0.23 seconds at 60 Hz, and a listing of a
hundred lines would take some 25 seconds to print. Without them lower case passes
unchanged in both directions and output runs at the speed of the line.
`EVENP` remains, although nothing here generates parity.

#lines-to("void", lead: true, after: "}")

Unchanged from v7 are `klclose` and `klwrite`. As in v7, closing the console does
not disable its receiver interrupt, so characters typed while it is
closed still go to `ttyinput` and accumulate in the raw queue.

Part of `klread` is new. When the raw queue holds `TTYHOG` characters
and a complete line, `klrint` (#l("klrint(dev_t dev)")) puts what follows on `t_holdq`
(#f("tty.h")) instead, by way of `ttyhold` (#f("tty.c")), and when
that too is full it stops taking characters and masks the receive interrupts.
The characters then wait in the UART's FIFO and, beyond it, in QEMU,
which passes the UART no more than the FIFO holds and leaves the rest
with the host. A paste of any length thus arrives whole, where v7 threw
away everything typed once `TTYHOG` was passed. The hold ends in `klread`:
before the reader takes a line, it moves what it can from
`t_holdq` to the raw queue (`ttyunhold`, #f("tty.c")), unmasks the interrupts,
and calls `klrint` itself (#l("UARTIMSC |= RXI|RTI;"), #l("klrint(dev);")), with the IRQ masked, to empty the FIFO as
far as the queues allow, and then reads. A reader can never
wait on a held line, since input is held only while there is a line to
read.

The interrupt, quit, stop, and start characters are never held:
`ttyhold` hands them to `ttyinput` at once, and an interrupt or a quit
discards `t_holdq` along with the other queues (`flushtty`), as it
discards what was typed ahead in v7. So does every other flush, such as a change of modes by `stty`, which
`getpass` also makes, or the last close at logout, so that nothing typed ahead is left for the next
reader. So a DEL typed behind a held paste stops a program
which is not reading its terminal, such as one in a loop, at once. Only
behind more than `t_holdq` can take does it wait, in the FIFO, for the
reader to catch up.

#lines-to("static void")

In v7, `klxint` and `klrint` were reached through separate interrupt
vectors, whose processor status words carried the minor device number.
Here they are called from `klintr` below, with minor device 0, and
`klrint` also from `klread`. Both are `static`.

The routine `klxint` restarts output and wakes a writer once the queue has drained
to `TTLOWAT`. In v7 it first asked whether the line was attached to a
multiplexed file (`t_chan`), and if so called `mcstart` in `mx2.c`.
Those files are not part of this system and the test has gone.

The routine `klrint` reads characters from `UARTDR` and hands each to `ttyhold`
(#f("tty.c")) until the receive FIFO is empty (#l("while((UARTFR&RXFE) == 0) {")), or until `t_holdq`
is full (`TTHOLDQ`, #f("tty.h")). It then masks the receive interrupts
and leaves the rest in the FIFO (#l("if(tp->t_holdq.c_cc >= TTHOLDQ) {")--#l("}", after: "UARTIMSC &= ~(RXI|RTI);")), for `klread` to collect. The KL11 interrupted for every
character and had to be told (`RDRENB`) to receive another. The PL011
receives continuously, and interrupts when its FIFO is half full, or,
with fewer characters waiting, when no new one has arrived for 32 bit
times, the receive timeout. The routine `klintr` treats the two alike. Emptying the
FIFO at each interrupt leaves it the most room for what follows, and
also clears both interrupts. The bits above the character which the
PL011 returns, flags for framing, parity, break, and overrun errors,
are removed with the mask in `ttyinput` (#f("tty.c")).

#lines-to("void", lead: true)

The routine `klioctl` hands the commands to the common code. The `kl.c` of v7 called it
`ttioccom`, with one `m`, although #f("tty.c") defines `ttioccomm`. The
PDP-11 loader kept only eight characters of a symbol, counting the
underscore which the compiler prefixed to every external name, so to it
the two spellings were the same name. Here the misspelling would be an
undefined symbol, and is corrected.

#lines-to("void", lead: true, after: "}")

The routine `klstart` moves characters from the output queue into the transmit
FIFO until the FIFO is full or the queue empty. The KL11 took one
character at a time, when its `DONE` bit said the transmitter had room,
and interrupted when it had sent it. The PL011 with its FIFO interrupts
only when the contents fall to the trigger level, half the FIFO, from
above, so `klstart` must fill it: a single character, below that level,
would never raise the interrupt, and output would stop. A character
above `0177` is a delay: `ttrstrt` is scheduled to start output again
when it has passed, and the filling stops (#l("return;", after: "tp->t_state |= TIMEOUT;")).

In v7 the parity bit from `partab` was added to each ordinary character
(`c | (partab[c]&0200)`). The port sends the character as it is. The
UART is set for eight data bits without parity (`klinit`), as terminal
emulators expect, so the parity bit reaches the
terminal as part of the character: with it, the shell's prompt `#`,
which has odd parity, is printed as `£`. In `RAW` mode all eight bits
are sent, as `kl.c` did.

#lines-to("void", lead: true, after: "}")

Two procedures are new. The routine `cninit` (#f("qemu/c.c")) calls the
first, `klinit`, early in `machine_init` (#f("machdep.c")). It sets
`UARTLCRH` to `0160`, eight data bits (bits 5 and 6) with the FIFOs
enabled (bit 4), and then `UARTCR` to `0x301`, which enables the UART
(bit 0), its transmitter (bit 8), and its receiver (bit 9). The line
control register must be written while the UART is disabled. The reset value leaves the UART
disabled, and QEMU transmits regardless, but logs each character as a
guest error, and a real PL011 would send nothing.

The console's entry in `intrtab` is `klintr`, called by `irq`
(#f("machdep.c")) when the interrupt controller reports interrupt 33.
The one interrupt serves both directions, so the masked status is
examined to decide which of v7's two handlers to call, the receive
timeout counting as a receive interrupt (#l("if (UARTMIS&(RXI|RTI))")). The transmit interrupt
is raised when the transmit FIFO has drained to its trigger level, and
is cleared explicitly (#l("UARTICR = TXI;")), before `klxint` refills the FIFO.

#lines-to("/*", lead: true)

The console output of `printf` (#f("prf.c")) is `putchar`. It polls
the transmitter, bypassing the `tty` structure and its queues, and is
`kl.c`'s, with the PL011's registers in place of the KL11's. Every
character but null, carriage return, and delete is first copied into
the circular buffer `msgbuf`. The pointer `msgbufp`, which v7 defined
in `kl.c` just above `putchar`, is now defined in #f("machdep.c").

The procedure waits a bounded time for the transmitter to have room.
In v7 the wait was bounded by counting 30000 turns of the loop, some thirty
character times on the PDP-11. A count of turns means nothing on a
processor many times faster: a Cortex-A7 at 1 GHz makes them in about
one character time at 115200 baud, and the end of a panic message would
be lost. The port bounds the wait by time instead, setting `timo` to the
value which the generic timer's counter, read by `cntvct_get`
(#f("mch.s")), will reach one clock tick later, `1/HZ` second or some
190 character times, and the loop gives up when the counter gets there.

The console's interrupts are masked while the character is written, as
v7 cleared the transmitter status register, and the old mask is
restored at the end. A newline is followed by a carriage return, and in v7
then by two deletes, which gave a mechanical terminal time to return
its carriage. They are gone, since no terminal here needs the time, and
they would arrive among the output. The final call with 0 only waits
until the transmitter has room again, which with the FIFO no longer
means that the last character has left.

The v7 version also gave up printing if the last character
received was a null or a break. That test has gone: on the PL011 it
could not be made without reading `UARTDR`, which would remove a
character from the receive queue and so steal it from the input. The comment
about the console switches was already stale in v7.

#lines-to(none)
#source("/usr/sys/dev/tty.c")

The file #f("tty.c") holds the code common to all terminals: what a driver such
as #f("pl011.c") does not need to know about. Under it lie the device
routines, which move single characters to and from the hardware. Above
it, the `read`, `write`, and `ioctl` system calls. Between them it
implements v7's one line discipline, discipline 0 of `linesw` (#f("qemu/c.c")). It does erase and kill processing, echoing, the interrupt,
quit, stop, and start characters, the expansion of tabs, the mapping of
newline to carriage return and line feed, the conventions for upper
case terminals, and the delays which slow terminals need.

Its procedures fall into two halves. The "top half" runs on behalf of a
process, in `read`, `write`, `open`, `close`, and `ioctl`, and may sleep.
The "bottom half", `ttyinput` and `ttstart` with what they call, is
reached from the driver's interrupt routine and may not. The queues of
the `tty` (#f("tty.h")) lie between the two, and the top half masks the
IRQ with `intr_disable` (#f("mch.s")) whenever it examines them, where
v7 raised the priority with `spl5`.

In v7 `mx.h` was included here for the multiplexed files (`mx1.c` and
`mx2.c`). They are not part of this system, so the include, and the
three places below which handed characters or signals to a multiplexed
channel, have gone. The tests of `t_chan` which remain (#l("if ((tp->t_state&CARR_ON)==0 || tp->t_chan!=NULL) {"), #l("if (tp->t_chan)")) still
compile, and always find it `NULL`.

The table `partab` (#l("extern unsigned char\tpartab[];")) is now declared `extern`, and `unsigned` as in
#f("partab.c"). In v7 `char partab[];` at file
level was taken as a reference to the array in #f("partab.c"). In C99
it is a tentative definition, which would give this file an array of
its own. The four procedures declared at (#l("void\twflushtty(struct tty *tp), flushtty(struct tty *tp),"), #l("ttyblock(struct tty *tp), ttyoutput(int c, struct tty *tp);")) are used before they
are defined, and only in this file.

#lines-to("/*", lead: true, after: "ttyblock(struct tty *tp), ttyoutput(int c, struct tty *tp);")

For a character preceded by a backslash, `canon` uses `maptab`.
A non-zero entry is the character which the pair stands for on an upper case terminal. Thus `\(` stands for `{`, `\!` for `|`, and `\a` (typed as
`\A`, since such a terminal's input is folded to lower case) for a real
capital. The routine `canon` makes an escaped erase or kill character, whatever it has been
set to, stand for itself (#l("if (c==tp->t_erase || c==tp->t_kill)"), #l("mc = c;")).
The table is consulted only outside `RAW` mode, in which `ttyinput` cuts
every character to seven bits. But a change of modes by `TIOCSETN`,
which keeps the raw queue, can leave eight-bit characters typed in
`RAW` mode for `canon` to find. The v7 table had 128 entries, and an
escaped one was then looked up beyond its end. The port gives it 256
(#l("char\tmaptab[256] ={")), the upper half zero, so that such a character stands for
itself.

#lines-to("/*", lead: true, after: "#define\tq4\ttp->t_un.t_ctlq")

The driver's open routine calls `ttyopen`. If the opening process
belongs to no process group, as a process descended from `init` does
until it opens a terminal, this terminal becomes its controlling
terminal, recorded in `u` for #f("sys.c"), and the process joins the
terminal's group. The process id of the first process to join the group names it, normally the child which `init` forks for the line
and which opens it before becoming `getty`. And it is to this group that `ttyinput` sends interrupts and quits.

On the last close, `ttyclose` dissolves the group and waits
for output to drain before discarding everything else.

#lines-to("/*", lead: true, after: "tp->t_state = 0;")

The older system calls, kept for programs
written before `ioctl`, are `stty` and `gtty`. Each rearranges its arguments in `u.u_arg` into those of an
`ioctl` with the command `TIOCSETP` or `TIOCGETP`, and calls `ioctl`.

The system call `ioctl` itself deals with the two commands which concern the file
descriptor rather than the device, setting or clearing close on exec,
and passes everything else to the character device's `ioctl` routine.

#lines-to("/*", lead: true, after: "(*cdevsw[major(dev)].d_ioctl)(dev, uap->cmd, uap->cmarg, fp->f_flag);")

The routine `ttioccomm` performs the commands common to all terminals. A driver's
`ioctl` routine calls it, and reports `ENOTTY` if it returns zero.

The command `TIOCSETD` changes the line discipline. Since `t` is unsigned, a negative
number fails the test against `nldisp`, which is 1 here. The cast
(#l("if (t >= (unsigned)nldisp) {")) is new. It makes explicit the conversion of `nldisp` to unsigned
which C performs in any case (#f("fio.c")). Likewise `t_line`, a `char`, is
now converted to `int` (201, and again at #l("(*linesw[(int)tp->t_line].l_ioctl)(com, tp, addr);")) before it subscripts
`linesw`: a `char` subscript draws a warning, since `char` is signed on
some machines.

In v7 `addr` was passed as a third argument to the discipline's open routine
(#l("(*linesw[t].l_open)(dev, tp);")). No open routine in v7 or here takes one, and with a prototype for
`l_open` (#f("conf.h")) the call must match it, so the argument has
gone.

#lines-to("/*", after: "tp->t_line = t;")

`TIOCSETP` waits for output to drain and discards input before the new
modes are installed, and `TIOCSETN` installs them at once. The comment
(#l("/* fallthrough */", after: "case TIOCSETP:")) is new: it tells the compiler, which otherwise warns, that falling
from one case into the next is intended.

`TIOCSETC` and `TIOCGETC` copy the special characters as a block,
the six bytes of `struct tc`, through the shorthand `tun`.

#lines-to("/*", lead: true, after: "return(0);")

With the IRQ masked, `wflushtty` waits until the driver has sent every character
of the output queue, then flushes the queues. The driver's transmit interrupt ends the sleep on `t_outq` (`klxint`, #f("pl011.c")),
which wakes a sleeper when `ASLEEP` is set and the queue has drained to
`TTLOWAT`.

The routine `flushtty` throws away the contents of all three queues and wakes
anyone waiting for them. It now also empties `t_holdq` (#f("tty.h")),
the input which the console's driver holds back (`ttyhold` below), lest
it be read after the flush. The driver's `d_stop` routine is called to
abandon output in progress. The console needs none, and its entry is
`nulltty` (#f("subr.c")).

#lines-to("/*", lead: true, after: "intr_restore(s);")

The routine `canon` moves one line from the raw queue to the canonical queue,
which `ttread` then copies to the user. In the normal mode it waits
until the raw queue holds at least one complete line, which `ttyinput`
marks by appending a delimiter and counting it in `t_delct`. In `RAW`
or `CBREAK` mode it waits for any character at all. If the line is not open,
`CARR_ON` is clear and `canon` returns zero at once.

Since only this file calls `canon`, it is now `static`, which spares
it a declaration in #f("systm.h"), which `-Wmissing-prototypes` would
otherwise demand.

The parentheses in the condition (#l("while (((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0)"), #l("|| ((tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0)) {")) are new, as in #f("slp.c"). The early `return` of v7 (#l("return(0);", after: "if ((tp->t_state&CARR_ON)==0 || tp->t_chan!=NULL) {")) left the processor at `spl5`,
and so kept every interrupt, the clock's among them, masked until the
process next returned to user mode. A call of `intr_enable` (#l("intr_enable();", after: "if ((tp->t_state&CARR_ON)==0 || tp->t_chan!=NULL) {")) now unmasks them
first, as the normal path does after the loop.

#lines-to("loop:")

The line is assembled in `canonb` (#f("systm.h")), starting at its
third byte, so that `bp[-1]` and `bp[-2]` can always be examined: the
two bytes before the line remain zero. An erase removes the last
character, a kill restarts the line, and the end of file character is
dropped, so that one typed at the start of a line yields a read of no
bytes. After a backslash, `maptab` is consulted. If the pair is to be
replaced, `bp` steps back over the backslash, unless the backslash was
itself escaped. The delimiter `0377` cannot be mistaken for a
character typed in the normal mode, in which `ttyinput` keeps only seven
bits. Only one typed in `RAW` mode and left in the queue by `TIOCSETN`
could be.

When the queue has emptied below a fifth of `TTYHOG`, a terminal which
was told to stop sending (`TBLOCK`, see `ttyblock`) is sent the start
character.

#lines-to("/*", lead: true)

The routine `ttyrend` accepts a block of input at once, from a driver which receives
by DMA. No driver here does so, and the slot `l_rend` of `linesw` is
empty, and v7's `mkconf` had in fact put `ttstart` in that slot, one place
too early, and it now occupies `l_start`. In v7 the raw case began by
handing the block to a multiplexed channel, if there was one. The
`else` has gone, which is why the `wakeup` (#l("wakeup((caddr_t)&tp->t_rawq);", after: "b_to_q(pb, pe-pb, &tp->t_rawq);")) is indented as it is.

#lines-to("/*", lead: true, after: "}")

The driver's receive interrupt calls `ttyinput` with each
character. They are counted in `tk_nin` for the statistics of `iostat`, summed as
an `unsigned long` so that it wraps instead of overflowing. The
mask with `0377` (#l("c &= 0377;")) keeps the character proper: a UART may return
error flags above it.

In the normal mode the character is cut to seven bits and the special
characters act at once. The stop and start characters suspend and
resume output. In v7 any other character resumed output too. That is
now done by `ttyhold` below, as the character arrives, and two lines
after the test of the stop character (#l("if (c==tun.t_stopc)", after: "if (c==tun.t_startc) {")) are gone. The interrupt and quit characters flush the queues and
send `SIGINT` or `SIGQUIT` to every process in the terminal's group by
`signal` (#f("sig.c")), and v7 first offered the signal to a multiplexed
channel, and the indentation of the call (#l("signal(tp->t_pgrp, c);")) is a remnant of the
`else` which followed.

The raw queue is discarded entirely if it has grown beyond `TTYHOG`,
on the theory that nobody is reading it. The console's drivers hold
input back before that point while the queue holds a complete line
(`TTHOLD`, #f("tty.h"), and `ttyhold` below), so here the queue is now
discarded only when it holds a line longer than `TTYHOG`, which no
reader could take whole anyway. Otherwise the character is
appended. At the end of a line, or for any character in `RAW` or
`CBREAK` mode, readers are woken, and in the normal mode a delimiter
is appended too, counted only if `putc` succeeded. Finally the
character is echoed, a kill being followed by a newline, and output
started. The echo goes through `ttyoutput` at interrupt level, which
is why `ttyoutput` must never sleep.

#lines-to("/*", after: "}")

The console's drivers use the new `ttyhold` and `ttyunhold` to
hold input which the raw queue cannot take (#f("pl011.c")). Each
character received goes to `ttyhold`. First, any character but stop
and start resumes output stopped by the stop character, in any mode
but `RAW`, as v7's `ttyinput` did on its arrival. Doing it here, and
not when a held character finally reaches `ttyinput`, keeps the order
in which the user typed: a held character typed before a stop must not
resume output after it. Then, while `TTHOLD` (#f("tty.h")) is true, or
`t_holdq` already holds characters, which must keep their order, the
character is put on `t_holdq`, unless it is one of the four which act at once, interrupt, quit, stop,
or start, in any mode but `RAW`, where
no character is special. Those go to `ttyinput` straight away, so that
a terminal held behind a paste can still be interrupted or its output
stopped. An interrupt or a quit empties `t_holdq` too, through
`flushtty`. Called by the driver's read routine, `ttyunhold` moves
characters from `t_holdq` to `ttyinput` until the raw queue is held
again or `t_holdq` is empty.

#lines-to("/*", lead: true, after: "ttyinput(getc(&tp->t_holdq), tp);")

In `TANDEM` mode, served by `ttyblock`, the terminal is a machine
that obeys the stop and start characters itself. When the raw and canonical
queues together hold half of `TTYHOG`, the stop character is sent to
it.

#lines-to("/*", after: "}")

The routine `ttyoutput` puts one character on the output queue, transformed as the
modes require, and counts it in `tk_nout`, unsigned as `tk_nin` is. In
`RAW` mode it goes unchanged. Otherwise a tab may be
expanded into spaces by recursive calls; for an upper case terminal,
the characters which it cannot print are replaced by a backslash and a
substitute, and lower case letters by capitals; and with `CRMOD` a
newline is preceded by a carriage return.

#lines-to("/*", after: "ttyoutput('\\r', tp);")

The rest of `ttyoutput` maintains `t_col`, the column of the carriage,
and computes the delay which should follow the character. The class of
the character comes from `partab` (#f("partab.c")), and the terminal's
type from fields of `t_flags`. A delay of `c` clock ticks is queued as
the character `c|0200`, which the driver recognises as a delay rather
than a character to send (`klstart`, #f("pl011.c")). Since ordinary
characters were cut to seven bits above, there is no confusion.

For the tab of a Model 37 teletype, the delay `1 - (*colp | ~07)` is
one more than the number of columns to the next tab stop, and a delay
below 5 ticks is dropped. Though `t_col` is a plain `char`, signed or not as
the compiler chooses, it is promoted to `int` before the `|`, which
with `~07` sets every bit above the low three, so the result depends
on those three alone and is the same either way. The comment at (#l("/* fallthrough */", after: "case 0:"))
is new, as at (#l("/* fallthrough */", after: "case TIOCSETP:")).

#lines-to("/*", after: "putc(c|0200, &tp->t_outq);")

When a delay has expired, the clock calls `ttrstrt`, which clears
`TIMEOUT` and restarts output. It now takes the `caddr_t` which
`timeout` (#f("clock.c")) passes to it, and converts it to the `tty`
pointer that v7 declared directly as its parameter: `timeout`'s
prototype admits only procedures taking a `caddr_t`.

The routine `ttstart` calls the driver's start routine, unless output is stopped,
delayed, or already in progress.

#lines-to("/*", after: "intr_restore(s);")

The line discipline's read and write
routines, which the driver's own routines call, are `ttread` and `ttwrite`. The first copies the
canonical queue to the user, refilling it with `canon` when it is
empty. Its result, the number of characters still waiting, served the
multiplexed files and is ignored here.

The routine `ttwrite` passes each character from the user to `ttyoutput`. When more
than `TTHIWAT` characters are queued it starts output and sleeps,
until the transmit interrupt wakes it at `TTLOWAT`. For a multiplexed line it
would instead return the address to wait on (#l("if (tp->t_chan)"), #l("return((caddr_t)&tp->t_outq);")). Since `t_chan`
is always `NULL`, it returns `NULL`.

#lines-to(none)

== More Drivers <ch-drivers>

#source("/usr/sys/conf/qemuconf")

The file #f("qemuconf") describes the QEMU machine to `mkconf`
(#f("mkconf.c")), which reads it on its standard input and writes
#f("qemu/c.c") and #f("qemu/unix.ld"). The first five lines are in v7's
own format, and could have come from v7's `rktmconf`. A line holding
only a device name (`rk`) configures one such device. The names `root` and `swap` give the device and minor device of the root file system and of the swap area, and `swplo` and `nswap` give the first block and the length of
the swap area. The `rktmconf` of v7 put the swap area at block 4000 of the
RK05. Here it starts at block 32768, just after the root file system
of 16 MB (#f("rootfs.proto")). In v7 it had 872 blocks, 436 KB, which held
several of its largest images. Here it holds 1048576 blocks,
512 MB, as much as the memory, so that whatever the memory holds can be
swapped out, with room besides for the copies of shared texts and for
the argument lists of `exec`. In v7 a magnetic tape, `tm`, was also configured, of which this system has
none.

The console, `mem`, and `tty` are not named, since `mkconf` configures
them unasked.

#lines-to("ram c0000000 40000000 4000000")

The remaining lines are new, and describe the machine rather than its
devices. The sizes of the kernel's tables are v7's constants, the same
for both machines (#f("param.h")). All the numbers are hexadecimal, without the `0x`.

The entry `ram` gives the kernel address at which the kernel is linked, the
physical address at which it is loaded, and the length of the region:
the first 64 MB of the QEMU machine's memory, at `0x40000000`, far more than the
kernel needs, linked at 0xc0000000 (@ch-intro). The difference of the
two addresses must be a multiple of 2 MB, the size of the blocks by
which #f("low.s") maps the kernel. The entry `core` gives the physical end of the
memory which holds process images: the end of the 512 MB with which
QEMU is started. Core begins at the first page after the kernel, which
`machine_init` (#f("machdep.c")) finds from the linker's symbols, so the
start is not stated here. The entry `gic` gives the kernel addresses of the
interrupt controller's distributor and processor interface.

Each `map` line names a kernel address, a range of physical addresses
which the kernel maps there in blocks of 2 MB, and the attributes of the
block entries, copied into #f("qemu/c.c") as written. `BLK_KERN` and
`BLK_DEV` are defined in #f("seg.h"). The first line covers all 512 MB
of memory, kernel and core alike. The others map a block each for the interrupt controller, the UART, and
the virtio transports. The devices which QEMU puts between them are not mapped.

#lines-to(none)
#source("/usr/sys/conf/mp135conf")

The configuration of the MP135 machine, in the format of
#f("qemuconf"). The devices, root, and swap are the same: one disk,
configured as `rk` although it is an SD card driven by #f("sd.c"),
holding the root file system and, after it, the swap area. The console
is one of the chip's serial ports, driven by #f("usart.c").

#lines-to("ram c01e0000 2ffe0000 20000")

The memory of the MP135 machine is in two pieces which are not
contiguous. The kernel runs in the 128 KB of on-chip SYSRAM at
`0x2ffe0000` (@ch-intro). This is `ram`, linked at 0xc01e0000, so that the difference is a multiple of 2 MB. Process
images, and anything else too large for SYSRAM, live in the 512 MB of
external DDR memory at `0xc0000000`, which the kernel maps 2 MB higher,
at 0xc0200000, just above the block of SYSRAM (@ch-intro).

Only this configuration uses the keyword `tables`. It names a second
region for the linker, by kernel address, physical address, and
length, into which `mkconf` places the section `.ddrbss`. It holds the table `kl3u` reserved in
#f("mch.s") and the tables of the configuration, which SYSRAM cannot spare. It takes the
start of DDR, and core, which `machine_init` (#f("machdep.c")) begins at
the first page after it, the rest of it, and `core` gives its physical end.

The attributes of DDR (#l("map c0200000 c0000000 e0000000 BLK_KERN")) are the QEMU machine's: all of DDR is
normal memory, cached write-back, like the kernel itself in SYSRAM
(#l("map c0000000 2fe00000 30000000 BLK_KERN")), and so are user pages (`PGUSER`, #f("seg.h")). The 2 MB block of SYSRAM also covers
the reserved addresses below it, which nothing reads. The one party
which does not see the
processor's data cache is the SD card's DMA controller, which moves
process images during swapping and raw I/O, and the buffers of the
buffer cache. The disk driver therefore cleans and invalidates the
cache over every transfer before it, and invalidates it after a read
(`dcflush`, `dcinval`, #f("sd.c")), so that the device reads what
the processor wrote and the processor does not afterwards find stale
lines. The buffers of the buffer cache occupy whole cache lines of
their own (#f("main.c")).

The other maps are a 2 MB block each of the peripherals which the
drivers use, at successive kernel addresses from `0xf0000000`. They are the reset and clock controller with the power controller and the GPIO ports
(#l("map f0000000 50000000 50200000 BLK_DEV")); the SD card controller (#l("map f0200000 58000000 58200000 BLK_DEV")); the DDR controller with its PHY
(#l("map f0400000 5a000000 5a200000 BLK_DEV")); the interrupt controller (#l("map f0600000 a0000000 a0200000 BLK_DEV")), which on this chip lies apart from
them, and whose two parts the `gic` line (#l("gic f0621000 f0622000")) names within that block;
the TrustZone controller of the DDR (#l("map f0800000 5c000000 5c200000 BLK_DEV")); and the block of I2C4 and of USART2, the console (#l("map f0a00000 4c000000 4c200000 BLK_DEV"), #f("pmic.c"), #f("usart.c")). Each driver
names its registers by these kernel addresses. The block of the DDR
controller also holds the watchdog IWDG2 (#f("iwdg.c")).

The line `ddr` asks for `ddrinit` (#f("ddr.c")) to be called
early in `machine_init` (#f("machdep.c")), before DDR is mapped or the
tables in it are touched. The last line, `iwdg`, asks for the watchdog
to be started (`iwdgstart`, #f("iwdg.c")) as soon as the devices are mapped.

#lines-to(none)
#source("/usr/sys/conf/mkconf.c")

The program `mkconf` configures a kernel. It reads a
description of the installation (#f("qemuconf"), #f("mp135conf")) and
writes the files which differ from one installation to another. In v7 `mkconf` wrote three files. The file `c.c` held the device
switches and tables, `l.s` the PDP-11's interrupt vectors and the
assembler stubs which led from each vector to its C handler, and
`mch0.s` a few assembler definitions which chose the tape on which the
system would dump core after a crash.
This one writes `c.c`, as before (#f("qemu/c.c")), and a linker script,
`unix.ld` (#f("qemu/unix.ld")).

The port keeps v7's program and its device table, and changes it in
four ways. The pass which wrote `l.s` is gone, since the ARM's vectors
are fixed (#f("low.s")) and interrupts are routed by a table in `c.c`.
So is the pass which wrote `mch0.s`, since there is no crash dump. A new
first pass writes the linker script. The configuration has new
keywords for the facts about the machine, and `c.c` gets a new tail which records the facts. Lastly, the
strings which `mkconf` copies into `c.c` have been made acceptable to a
C99 compiler.

The program `mkconf` runs on the host, not on the target, and is compiled as strict
C99 like the rest. The header `<string.h>` (#l("#include <string.h>")) declares `strcmp`, which v7 used
undeclared. The prototypes (#l("void\tpuke(char **s);"), #l("int\tinput(void), equal(char *a, char *b), badline(char *line);")) are needed because the procedures are
used before they are defined.

 `CHAR`, `BLOCK`, `ROOT`, `SWAP`, and
`PIPE` are still used. `INTR`, `EVEN`, and `KL` controlled the layout of
the vectors in `l.s`, and are now inert.

#lines-to("char\t*btab[] =")

The order of the names in `btab` and `ctab` is the order of the entries
in `bdevsw` and `cdevsw`: the index of a name is its major device
number. A device which is not configured still occupies its place, so
that the numbers never change, and the special files on the disk remain
valid whatever the configuration.

#lines-to("struct tab")

Each `struct tab` describes one kind of device by its name, the number
of such devices configured (`count`), the address of its interrupt
vector on the PDP-11 (`address`), its flags, and seven strings. The
count is negative for those which are always present and may not be
configured. The first three, `codea`,
`codeb`, and `codec`, are PDP-11 assembler, the vector and the stubs for
`l.s`, and are no longer used, while `coded` and `codee` are the device's
entries in `bdevsw` and `cdevsw`, and `codef` and `codeg` any
declarations which those entries need, written into `c.c` before the
switch.

Every entry of the table now has its own braces, which C99 compilers
expect (`-Wmissing-braces`), and v7 initialised the array of structures as
one flat list.

The console's entry and that of `mem` are changed in their `cdevsw`
strings and their declarations. Each slot of a switch now has a type of
its own (#f("conf.h")), so v7's `nodev` in the `ioctl` slot becomes
`noioctl` and its `nulldev` in the `d_stop` slot becomes `nulltty`. The
declarations, such as `int klopen(), klclose(), ...`, are now empty
strings: every driver routine is declared with a prototype in
#f("systm.h"), which `c.c` includes, and v7's old-style declarations
would conflict with them.

#lines-to("{", lead: true, after: "\"nulldev, nulldev, mmread, mmwrite, noioctl, nulltty, 0, \",")

The entries for devices which no configuration of this system names
are unchanged but for their braces. Their declarations remain in v7's
style, and their drivers do not exist. To configure one would produce a
`c.c` which neither compiles cleanly nor links. The entries for the
clock and for memory parity never contributed anything but vectors, and
are now without effect.

#lines-to("{", after: "\"int\ttcstrategy(), tcclose();\\nstruct\tbuf\ttctab;\",")

The `rk` entry has the same changes as the console's. Its block
declaration was `int rkstrategy();` and a definition of `rktab`, the
head of the disk's queue, which the disk driver also defined, and v7's
loader merged the two as a common symbol. Now `rkstrategy` is declared
in #f("systm.h"), and `rktab` is declared `extern`, so that the driver's
definition (#f("virtio_blk.c"), #f("sd.c")) is the only one. Both
machines' disk drivers took v7's `rk` names, so this one entry serves
for each.

#lines-to("{", after: "},")

The rest of v7's table is unchanged but for braces, except for `tty`,
the controlling terminal, whose `d_stop` slot becomes `nulltty`. The terminating `0` of v7
is now `{0}`.

#lines-to("char\t*stre[] =", lead: true)

The array `stre` heads `c.c` with its includes, which v7 followed with
declarations of `nulldev` and `nodev`. Those are in #f("systm.h"), and the include of #f("seg.h"), which defines
`struct memregion` and the block attributes used at the end of
`c.c`, and by those of #f("map.h"), #f("mount.h"), and #f("callo.h"),
for the tables which `strg3` (#l("char\tstrg3[] =")) defines.

#lines-to("char\t*stre1[] =", lead: true)

The remaining text of `c.c`. Where v7 wrote a bare `0` after the last entry
of each switch, the port writes `{0}`, again for the braces. In `strg`,
v7 printed `nswap` with `%l`, which is not a conversion of C99's
`printf`: the compiler rejects it, and the host's library prints `%;`
in place of the number. Since `nswap` is an `int`, the port uses `%d`.

The v7 version had one more array here, `strg1a`, which defined `ldmpx`, a pointer
to `mpxchan` used by the multiplexed files, unless the configuration
said `mpx`. The multiplexor is not part of this system, and the array is
gone. The declarations of the line discipline routines, before `strj`,
are gone for the same reason as the drivers'. The discipline's row
is changed as described under #f("qemu/c.c"): it has braces, typed
null routines, and `ttstart` in the slot `l_start`, where v7 had put it
in `l_rend`. The row for the packet driver `pk` (`strk`), which a
`pack` line would add, gets braces and zeros for the three slots v7
omitted. Its declarations (`stri`) are v7's.

The new array `strg3` defines the tables which v7 defined elsewhere, at the sizes of its `param.h`, namely the buffers, the maps, the mount
table, the callouts, and the character blocks (#f("qemu/c.c")). The buffers have
one row more than `NBUF`, of a whole number of 64-byte cache lines,
for `binit` to align them (#f("main.c")).

#lines-to("int\tpack;", lead: true)

The variables of v7 come first, followed by new ones (#l("int\tddr;")--#l("int\tnmap;")) which hold the description of the machine. They give whether DDR must be started (`ddr`); the kernel address,
physical origin, and length of the kernel's memory (`ramv`, `ramb`,
`ramn`) and of the region for its tables (`tabv`, `tabb`, `tabn`); the
top of core (`coret`); the addresses of the interrupt
controller; and up to `NMAP` regions to be mapped, each with its kernel
address and its attributes kept as text. `NMAP` is 9, the number of
`map` lines in #f("mp135conf"), the configuration with the most. The length of `mapa`'s strings is that of
an input line, so that no token can overflow it. The v7 version declared `pack`
twice (#l("int\tpack;", after: "\"\\t    0, 0, 0}, /* 1 */\","), #l("int\tpack;", after: "int\tnswap = 872;")), which C permits for a variable without an initialiser.

#lines-to("int", after: "int\tnmap;")

The configuration is read in one go, and then the outputs are written,
each by redirecting the standard output with `freopen`.

The first pass, which in v7 wrote `l.s`, now writes the linker script.
The kernel's text, read-only data, initialised data, and uninitialised
data (`.bss`) are placed one after another in `RAM`, at the kernel
addresses which the `ram` line gives. Each is given, with `AT`, a load
address, which the ELF file records as the physical address of its
segment: the kernel address less the difference of the two, so that
the image is loaded where the 2 MB blocks of #f("low.s") will find it.
The symbols `__bss_start` and `__bss_end` tell `low.s` what to clear, and
`__bss_start` is aligned to a word, since the clearing is done a word at
a time before the MMU is on, when an unaligned store faults. The section
`.ddrbss` holds the large tables. It is aligned to 4 KB, which a table
requires, is not loaded (`NOLOAD`), and `machine_init` (#f("machdep.c")) clears it once memory is ready. It is placed in the `tables`
region if the configuration has one, as on the MP135 machine, and otherwise in
`RAM`. With a `tables` region it also takes the uninitialised data of
`c.o`, the tables of the system, which `EXCLUDE_FILE` keeps out of
`.bss` (#l("if (tabn)", after: "ramn);")--#l("\"{ *(.text*) } > RAM\\n\", ramv-ramb);")\, and #f("mp135/unix.ld")).

The entry point is named: `start`, the physical address of `_start`.
QEMU, which loads the ELF file itself, jumps to the entry point with
the MMU off, so the kernel address would not do. On the MP135 machine
the kernel's first byte, at the start of SYSRAM, is `_start` too. Between the regions and the sections the
symbol `u` is set to `0xFFE00000`, the value of `UBASE` (#f("param.h")),
as v7's `mch.s` set `_u`, and `mkconf` is a program of the build machine
and does not include the kernel's headers, so the address is written
out here, and the two must agree.

#lines-to("/*", after: "tabn ? \"TAB\" : \"RAM\");")

The second pass writes `c.c`. The assignments within the
tests of the `for` loops (#l("for (i=0; (q=btab[i]); i++) {"), #l("for(i=0; (q=btab[i]); i++) {"), #l("for (i=0; (q=ctab[i]); i++) {"), #l("for(i=0; (q=ctab[i]); i++) {")) have the doubled
parentheses of #f("malloc.c"). Each
configured row is now enclosed in braces. A device which is not
configured gets a row of routines which fail: v7 wrote `nodev` in every
slot, but the slots now have types of their own, so a block device's
strategy slot gets `nostrat`, and a character device's read and write
slots `nordwr`, its `ioctl` slot `noioctl`, and its `d_stop` slot
`nulltty` (#f("conf.h")).

#lines-to("if (pack) {")

The line disciplines, root, swap, and pipe devices, and the tables
follow, and after them `strg3` adds the rest of the tables.

#lines-to("printf(\"\\nunsigned int\\tcorebase, coreoff, coretop = 0x%lx;\\n\",")

The tail of `c.c` is new. It defines the machine's top of core and the
addresses of the interrupt controller, which #f("machdep.c")
and #f("seg.h") use, and `corebase` and `coreoff` without a value, for
`machine_init` (#f("machdep.c")) to set; `board_map`, the regions to map,
each with its kernel address, whose attributes are copied as written in
the configuration, so that it may name `BLK_KERN` and `BLK_DEV`; and
`intrtab`, which pairs the
console's and the disk's interrupt numbers with their handlers.

Last come four small procedures by which the machine-dependent code
starts the configured drivers without naming them, `cninit`, `bdinit`,
`clock_ddr_init`, which calls `ddrinit` only if the configuration
said `ddr`, and `wdinit`, which calls `iwdgstart` only if it said
`iwdg`. The names they call, like those in `intrtab`, are fixed:
every machine's drivers use v7's `kl` and `rk` names, and only one
machine's drivers are linked into a kernel.

In v7, `main` ended by writing `mch0.s`, which set `HTDUMP` or `TUDUMP`
according to whether a TU16 tape was configured, so that the core dump
routine in `mch.s` knew where to write. There is no dump routine in
this system, and the pass is gone.

#lines-to("void", lead: true)

The routine `puke` writes a list of lines. In v7 it took a second argument, which each
line could use as a `printf` argument. No line used it, and it is gone.

#lines-to("int", lead: true)

The routine `input` reads one line of the configuration. The arrays `keyw` and `dev`
were 32 characters long in v7, while a line may be 99. Since `%s` copies
a whole word, a long word overflowed them. They are now as long as the
line.

The v7 version first scanned the line for an optional count, a keyword, a device,
and a number, and if no count was found, took the count as 1 and
added one to the number of fields converted. The test `n>0` shows
that v7's `sscanf` went on to the later conversions when the leading
number was missing, and so it did: v7's `_doscan` has no exit on a
failed conversion. C99's `sscanf`, which is the host's here, stops at
the first failure and returns 0, so the port scans the line a second
time without the count.

The keywords which describe the machine are recognised first (#l("if (equal(keyw, \"map\")) {")--#l("}", after: "iwdg++;")).
Their numbers are read in hexadecimal. A new procedure, `badline`, reports a malformed line with v7's message which returns 1, so that
reading continues. A tenth `map` line stops `mkconf` with an exit
status of 1 (#l("fprintf(stderr, \"Too many maps\\n\");")--#l("exit(1);")), and with it the build. A
kernel built without the mapping would fault at the first touch of the
device, before its console could say why.

#lines-to("for(q=table; q->name; q++)")

A device name adds to that device's
count, subject to the checks that a fixed device is not configured and
that a device whose vector has a fixed address is configured only
once. The addresses in the table are the PDP-11's octal vector
addresses written as decimal numbers. From 300 on lie the floating
vectors, allotted in turn, so that several devices of a kind could be
configured. The other keywords set the swap area, the root, swap,
and pipe devices, and the options `pack` and `mpx`, and `mpx` is now
accepted and ignored.

#lines-to("int", lead: true)

The routine `badline` is the end of v7's `input`, made a procedure so that the new
keywords can use it in an expression. Unchanged from v7 is `equal`.

#lines-to(none)
#source("/usr/sys/conf/mp135/c.c")

The configuration of the MP135 machine, written by `mkconf`
(#f("mkconf.c")) from #f("mp135conf"). Since the two configurations
name the same devices, root, and swap, and give the tables the same
sizes, the first 85 lines are identical to those of #f("qemu/c.c"), to
whose commentary the reader is referred.
The routines behind the names are different: `kl` is now the serial
console driver #f("usart.c"), and `rk` the SD card driver #f("sd.c").

#lines-to("unsigned int\tcorebase, coreoff, coretop = 0xe0000000;")

The tables defined above lie in DDR, which #f("mp135/unix.ld")
arranges. Process images occupy DDR from the first page after them to
its end, physical address `0xe0000000` (#l("unsigned int\tcorebase, coreoff, coretop = 0xe0000000;")). The interrupt controller
is the Cortex-A7's own, at physical `0xa0021000` and `0xa0022000`, which
the kernel reaches at `0xf0621000` and `0xf0622000` (#l("unsigned int\tgicdbase = 0xf0621000, giccbase = 0xf0622000;")).

The table `board_map` maps eight regions. The kernel's 2 MB block, which
contains SYSRAM, is at 0xc0000000, cached, and DDR is just above it,
cached likewise. Six blocks of peripherals follow from 0xf0000000
(@ch-intro).

#lines-to("extern int\tclkirq, klirq, rkirq;", lead: true)

The table `intrtab` is the same as the QEMU machine's, though the numbers behind `klirq` and
`rkirq` differ (71 and 82, #f("usart.c"), #f("sd.c")). The glue differs
in `clock_ddr_init`, which here calls `ddrinit` (#f("ddr.c")), and in
`wdinit`, which calls `iwdgstart` (#f("iwdg.c")), since the
configuration names `ddr` and `iwdg`.

#lines-to(none)
#source("/usr/sys/dev/usart.c")

The console driver of the MP135 machine. Like #f("pl011.c") on the QEMU
machine, it is v7's `kl.c` with a different device under it, and it
keeps `kl.c`'s comment, order, names, and `tty` array `kl11`, so that
the switch entry `klopen, klclose, klread, klwrite, klioctl` in
#f("mp135/c.c") is v7's. Where the two drivers make the same change to
`kl.c`, as in the default modes in `klopen`, the hold of input in
`klread` and `klrint`, and the bounded wait in `putchar`, the commentary
on #f("pl011.c") applies.

The device is USART2, one of the chip's USARTs ("universal synchronous
asynchronous receiver transmitter"), used here as a plain serial line at
115200 baud. Its registers differ from both the KL11's and the PL011's.
There is one control register `CR1`, holding the enables of the unit,
transmitter, and receiver and of the interrupts; a baud rate register
`BRR`; an interrupt and status register `ISR`; a register `ICR` for
clearing error flags; and separate registers for received (`RDR`) and
transmitted (`TDR`) data.

#lines-to("/* base address */")

`KLADDR` is the kernel address of USART2, physical `0x4c001000`, in the
2 MB block which it shares with I2C4 (#f("mp135conf")). `RCC` is the chip's reset and clock controller, by its kernel address,
and `GPIO` a register of a port of general purpose pins.
`APB6ENSETR` and `UART12CKSELR` are the registers of `RCC` which
enable USART2's clock and choose its source. The bits of
`CR1` are those for the enables. `RXNE` and `TXE` are the status bits
in `ISR`, which with the FIFOs enabled mean "receive FIFO not empty"
and "transmit FIFO not full". The unused definitions of `kl.c` stay, as
they do in #f("pl011.c").

#lines-to("struct\ttty kl11[NKL11+NDL11];")

The variable `klirq` holds the console's interrupt number for `intrtab`
(#f("mp135/c.c")), 71, which is shared peripheral interrupt 39 of the
interrupt controller.

#lines-to("/*", after: "int\tklirq = 71;")

The routine `pinuart` gives one pin to the USART. It enables the clock of
the pin's port, sets the pin's mode to 2, alternate function, and
selects its alternate function in the low or high alternate function
register (`0x20`, `0x24`), four bits per pin. The routine `klinit` is called by `cninit` (#f("mp135/c.c")) early
in `machine_init` (#f("machdep.c")). The kernel otherwise takes the
clocks as the boot ROM left them, but the USART is given a clock of its
own choosing so that its speed does not depend on that state. It is
given its pins (#l("pinuart(5, 13, 7);"), #l("pinuart(3, 15, 1);")), PF13 to transmit and PD15 to receive, which the
board brings out on its 40-pin header. Its clock is enabled on its
bus, and HSI, the internal 64 MHz oscillator, which runs from reset,
becomes its kernel clock (value 2 in bits 3--5 of `UART12CKSELR`). `BRR` divides that clock to 115200 baud, since 64000000/115200 is
555.6. Lastly the unit, the transmitter, and the receiver are
enabled, and with them the FIFOs (`FIFOEN`), which hold several
characters in each direction where the KL11 held one. A character then
waits in the FIFO, not lost, while the processor has interrupts masked
for longer than one character time, 87 microseconds at this speed.
`FIFOEN` may only be changed while the unit is disabled, and so is
written with the enable. Every other bit of `CR1` is written as zero,
which gives eight data bits and no parity.

The registers which enable clocks are of a "set" kind: a one sets the
corresponding bit, and a zero leaves it alone. Each write is followed
by a read of the same register (#l("(void)AHB4ENSETR;"), #l("(void)APB6ENSETR;")), which does not complete until
the write has, so that the clock is running before the device it feeds
is touched.

#lines-to("void", after: "CR1 = FIFOEN|UE|TE|RE;")

The routines `klopen`, `klclose`, `klread`, and `klwrite` are those of #f("pl011.c"),
except that the receiver interrupt is enabled by setting `RXNEIE` in
`CR1` (#l("CR1 |= RXNEIE;", after: "ttychars(tp);")), and `klread` ends a hold of the input by setting it again. The
transmitter interrupt is not enabled here, for the reason given under
`klxint`.

#lines-to("static void", after: "klwrite(dev_t dev)")

The routine `klxint` turns off the transmitter interrupt (#l("CR1 &= ~TXEIE;", after: "klxint(dev_t dev)")) before calling
`ttstart`, which will turn it on again if it sends a character. The
PL011, like the KL11, raises its transmit interrupt once, when a
character has gone. The USART's `TXE` is a condition, not an event: it
is set whenever the transmit FIFO has room, and while both it and
`TXEIE` are set the interrupt remains asserted. With nothing more to
send, an enabled interrupt would be taken again the moment it was
returned from.

The routine `klrint` takes characters from `RDR` for as long as `RXNE` says the
receive FIFO holds one (#l("while(ISR&RXNE) {")), and hands each to `ttyhold`, unless
`t_holdq` is full, when it clears `RXNEIE` and leaves the characters
where they are, as #f("pl011.c") explains. The interrupt is a
condition too, asserted while any character waits, so the loop takes
the first character and any which arrive behind it, and the PL011's
receive timeout has no counterpart here. Writing 017 to `ICR` (#l("ICR = 017;")) then clears the error
flags for parity, framing, noise, and overrun. An overrun in
particular, with `RXNEIE` set, would otherwise hold the interrupt
asserted for good.

A paste longer than `t_holdq` can take fares less well than under QEMU.
Once `t_holdq` is full the characters gather in the receive FIFO, but
nothing tells the sender to stop. The driver connects only the receive
and transmit pins, so there are no flow control lines, and the console
does not use `TANDEM`. When the FIFO is full, the next character to
arrive sets the overrun flag and is lost, as is every one after it
until `klread` takes input again.

#lines-to("void", after: "ICR = 017;")

The routine `klioctl` is that of #f("pl011.c"), with v7's misspelling `ttioccom`
corrected.

#lines-to("void", after: "u.u_error = ENOTTY;")

The routine `klstart` sends the next character if the transmit FIFO has room, or
arranges a delay. One character at each interrupt suffices, since the
interrupt is asserted again as long as the FIFO has room. `TXEIE` is set (#l("CR1 |= TXEIE;", after: "tp->t_state |= TIMEOUT;"))
whenever something was taken from the queue, so that the interrupt
follows when the character has gone. For a delay nothing has been
written, `TXE` stays set, and the interrupt comes at once. The routine `klxint` then calls
`ttstart`, which finds the `TIMEOUT` state set and returns, and the
interrupt stays disabled until `ttrstrt` restarts output.

#lines-to("void", after: "CR1 |= TXEIE;")

The routine `klintr` is the entry in `intrtab`, called by `irq` (#f("machdep.c")). It
calls one or both of the handlers. The test of `TXEIE` (#l("if (ISR&TXE && CR1&TXEIE)")) is needed
because `TXE` is set nearly always, and an interrupt from the receiver
must not be taken for one from the transmitter.

#lines-to("/*", after: "klxint(0);")

The routine `putchar` uses `ISR`, `TDR`, and `CR1` in place of the KL11's
registers. Where `kl.c` cleared the transmitter status register, and
with it the interrupt enable, this clears `TXEIE` alone, since the
receiver's enable lives in the same register and must be kept. At the
end `TXEIE` alone is set again (#l("if(s&TXEIE || kl11[0].t_outq.c_cc)")), and only if it was set at the start or
characters wait in the output queue. Restoring the whole register, as
`kl.c` did, would lose an echo. The receive interrupt stays enabled
meanwhile, and an echo may pass through `klstart`, which sets `TXEIE`,
between the reading of `CR1` and the end. A restored copy would clear
that bit again, and leave the queue unsent until something else called
`ttstart`. If output was in progress, `TXEIE` comes back set and the
transmit FIFO has room, and the interrupt which follows restarts it.

#lines-to(none)
#source("/usr/sys/dev/iwdg.c")

The chip's independent watchdog IWDG2 counts down from a reload value
on a clock of its own, and resets the chip when it reaches zero, unless
it has been fed, which reloads the count. The MP135 machine has no other
means of resetting itself, and without one a kernel which stopped on
the board would stay stopped until someone pressed its reset button.

The routine `iwdgstart` is called by `wdinit` (#f("mp135/c.c")) at the start of
`machine_init` (#f("machdep.c")), as soon as the device registers are
mapped and before the console is set up. It enables the watchdog's
clock on its bus and reads the register back. The key register
`KR` then takes commands. The value `0xCCCC` starts the watchdog, `0x5555` unlocks the
prescaler `PR` and the reload register `RLR`, and `0xAAAA` feeds it,
loading the new values. A prescaler of 6 divides the watchdog's
32 kHz clock by 256, and a reload of 4095 then gives about 33 seconds.

Once started, the watchdog runs until the chip resets, and nothing in
the kernel feeds it. That is done by the program `wdog` (#f("cmd/wdog.c")), which `init`
starts (#f("cmd/init.c")), so that the board stays up only while processes
run. A kernel which panics, stops with interrupts masked, or never
reaches user space resets the board, which then waits in its boot ROM
for a new image.

#lines-to(none)
#source("/usr/sys/dev/sd.c")

The disk of the MP135 machine is its SD card, and this is its driver.
Like #f("virtio_blk.c") on the QEMU machine, it replaces v7's `rk.c` and takes over its names, its configuration entry, and its shape, with a queue headed in `rktab`, `rkstrategy` to add a request, `rkstart` to give the
head of the queue to the device, `rkintr` to finish it and start the
next, and `rkread` and `rkwrite` for the raw disk. It is closer to
`rk.c` than the virtio driver, because the device is closer to an RK11:
it is given a command and the address of a buffer, moves the data by
DMA, and interrupts when done.

The controller is SDMMC1. Its command path sends a command to the
card, with a 32-bit argument, and receives the card's response. Its
data path moves blocks between the card and the controller, and the
controller's own DMA engine, the "IDMA", moves them between the
controller and memory. The commands are those of the SD card
specification, known by number. The boot ROM leaves the card as it was
unless it booted from it, so the driver brings it up itself, as the ROM
would.

#lines-to("#define\tSD(off)\t(*(volatile int *)(0xF0205000+(off)))")

`SD` names a register of the controller by its offset, `RCC` one of the
reset and clock controller, and `GPIO` one of a port of general purpose
pins (port A is 0), all by their kernel addresses (#f("mp135conf")).
`NRK` and the RK11's bits are kept although unused, as in
#f("virtio_blk.c"); a few of the names are given new values. `WCOM` and
`RCOM` (#l("#define\tWCOM\t25"), #l("#define\tRCOM\t18")) are the commands which write and read many blocks, 25
and 18, which go on until the card is told to stop. `GO` holds the bits
of the command register which start a command with data. They are `CPSMEN` (`0x1000`), which
enables the command path, a short response (`0x100`), and `CMDTRANS`
(`0x40`), which starts the data path with the command. `STOP` starts command 12, which stops the card, with a
short response and `CMDSTOP` (`0x80`), which tells the data path that
it ends the transfer. `IENABLE` (#l("#define\tIENABLE\t0x800013f")) is the interrupt mask. It enables command and data CRC failures, command
and data timeouts, transmit underrun, and receive overrun (`0x3f`), the
end of the data (`0x100`), and an IDMA transfer error (`0x8000000`). `ERR` (#l("#define\tERR\t0x800003f")) is the same set without
the end of data.

The register offsets (#l("#define\tPOWER\t0x00")--#l("#define\tIDMABASER\t0x58")) follow, for power, clock, argument, command,
the first of four response registers, the receive FIFO, the data
timer, length, and control, status, interrupt clear, interrupt mask,
and the IDMA's control and address. In the data control register,
`BLK512` (#l("#define\tBLK512\t0220")) sets the block size to 2#super[9] bytes and `DTDIR` the
direction from card to controller. `CLEAR` has a bit for every flag
that the interrupt clear register clears. Then come the status bits for response received, end of data, receive
FIFO empty, `CMDERR`, a
command's CRC failure or timeout; `BUSYD0`, the card holding its first
data line low while it writes, and `BUSYD0END`, the end of that.
`WIDE` (#l("#define\tWIDE\t(1<<14)")) selects four data lines. `MAXIO` (#l("#define\tMAXIO\t0x1000000")) is the most one
command moves, 16 MB: the data length register has 25 bits.

#lines-to("/*", lead: true)

The interrupt number `rkirq` is 82, shared peripheral interrupt 50, to which the chip wires
SDMMC1. The variable `rkoff` is the offset within
the current request of the part being transferred, and `rkn` that
part's length, and `rkstop` and `rksta` carry `rkintr` through the end of a
transfer. The variable `nrkblk` holds the number of blocks on the card, `rca` the
card's address on its bus, and `rkbyte` says that the card counts in
bytes rather than blocks.

#lines-to("static void")

The routine `rkdelay` waits a number of microseconds by the generic timer.

Used to bring the card up, `rkcmd` sends a command and waits for it to
finish, polling. The response kind (8--9 of the command register) is
none (0), short (1), short without a CRC (2), or long (3). It waits for
a response or a CRC failure (`0101`) if one is expected, else for the
command to be sent (`0200`), and panics if the command times out (`04`)
or takes over a tenth of a second, or if a CRC fails where one is
expected: command 41's response, and the long responses, carry none
the controller can check.

#lines-to("/*", after: "panic(\"sd card crc\");")

The routine `bdinit` (#f("mp135/c.c")) calls `rkinit` from `main`, before
`intrstart`. It enables the clocks of GPIO ports C and D (`014`, bits 2
and 3), and puts PC8 to PC12, the four data lines and the clock, and
PD2, the command line, on alternate function 12, SDMMC1, at medium
speed. It chooses HSI, the internal 64 MHz oscillator, as the
controller's kernel clock (`0x648`, value 3), enables the controller's
clock on its bus (`0x780`, bit 16), and pulses its reset (`0x6f0` sets
it, `0x6f4` clears it). The card is first clocked at 400 kHz, the most
it need accept before it is identified: `CLKCR` 80 divides the 64 MHz
by twice that. Power is turned on (`POWER` 3), and a millisecond allowed
for the card's start.

Then the standard sequence. Command 0 resets the card. Command 8 offers
2.7--3.6 V with the check pattern `0xaa` (`0x1aa`), which a card of
version 2 echoes. Command 41, an application command and so preceded by
command 55, asks the card to start, saying that the host takes high
capacity cards (bit 30) and giving the voltage window (bits 15--23). It
is repeated, up to a second, until the card reports itself ready (bit
31, the sign of `RESP1`). Bit 30 of the same response, `CCS`, is set by
a high capacity card, which counts in blocks. An older card counts in
bytes (`rkbyte`). Command 2 reads the card's identification, which is
not wanted, and command 3 has the card publish its address (the high
half of the response).

Command 9 reads the card-specific data, `CSD`, 128 bits across the four
response registers, the most significant in `RESP1`. Its top two bits
give its version. In version 2, used by high capacity cards, the size
is (`C_SIZE`+1) × 512 KB, `C_SIZE` being bits 48--69. In blocks, 1024
times as many. In version 1 the size in bytes is (`C_SIZE`+1) shifted
left by `C_SIZE_MULT`+2 and by `READ_BL_LEN`, with `C_SIZE` bits
62--73, `C_SIZE_MULT` bits 47--49, and `READ_BL_LEN` bits 80--83. The
shift less 9 gives blocks. The routine `rkstrategy` refuses any block beyond the
card's end.

Command 7 selects the card, application command 6 sets its bus to four
lines (argument 2), and the controller follows with four lines and a divider of 2, 16 MHz. The data timeout is set to its largest value, so
that a slow card is waited for. A card may take far longer to finish a
write than a read.

Last, command 6 with data (`0100`, `CMDTRANS`) switches the card to
high speed: argument `0x80fffff1` sets function group 1 to function 1
and leaves the others (`f`). The card answers with 64 bytes of status,
which are read word by word from the receive FIFO, without DMA, after
the data path is set for one 64-byte block (`0140`, block size
2#super[6]) from the card. If all 16 words came and function group 1
now reports function 1 (the low four bits of the status's 17th byte,
first in word 4), the card has switched. Eight clocks later the divider
becomes 1, and the card runs at 32 MHz.

#lines-to("void", after: "}")

The routine `rkstrategy` tests the request more than v7's did. A block
number beyond the card is rejected, as v7 rejected one beyond the end
of the pack, and so is a request whose count is not a whole number of
blocks or whose buffer is not on a word boundary, neither of which the
card and the IDMA can do: the IDMA's address register ignores the two
low bits. The buffer cache and the swap area always move whole blocks
from aligned addresses, so these two tests can fail only for raw I/O,
which `physio` (#f("bio.c")) lets through with an even address and
count. The call of `mapalloc` in v7 is gone, as in #f("virtio_blk.c").

#lines-to("/*")

The routine `rkstart` gives the rest of the request at the head of the queue, from
`rkoff`, up to `MAXIO` bytes, to one command. In v7 it converted the block
number into the drive, cylinder, and sector of the RK05 and loaded four
registers. Here the minor device is ignored, since there is one card,
and the block number is the argument of the command, multiplied by 512
for a card which counts in bytes. A write is preceded by application
command 23, which tells the card how many blocks follow, so that it can
erase them before they arrive.

The cache is cleaned and invalidated over the buffer (#l("dcflush(bp->b_un.b_addr+rkoff, rkn);")) by
`dcflush` (#f("mch.s")), which writes any modified lines to memory and
discards them. The IDMA reads and writes memory directly, without
seeing the processor's data cache: before a write the data must be in
memory, and before a read no modified line may be left to overwrite
the incoming data later. Both the buffer cache and the process images,
which swapping and raw I/O transfer directly, lie in DDR, which is
cached (#f("mp135conf")).

The device is then programmed in the order the controller requires. The old flags are cleared, the data path is stopped and given the
length and the block size and direction, the IDMA is given the
buffer's physical address, which `vtop` (#f("machdep.c")) finds from
the kernel's, and enabled, the interrupts are unmasked, and the
argument is set. Writing the command register (#l("SD(CMD) = com;")) starts the
transfer. The counts for `iostat` are summed as `unsigned long`,
as in #f("virtio_blk.c").

#lines-to("void", after: "}")

The routine `irq` (#f("machdep.c")) calls `rkintr` at the end of the data or
on an error, and, since a command of many blocks must be stopped, works
in up to three steps. At the first interrupt it stops the IDMA, keeps
the status, and sends command 12, unmasking only the interrupts of its
response, its failure, and the end of busy. At the second, if the card
is still writing (`BUSYD0`), it waits for the third, at the end of
busy. As in v7, an interrupt for which no request is active is ignored.

On an error, of the transfer or of command 12, `deverror` (#f("prf.c")) reports the status and the same part retried, up to v7's ten
times. In v7 the driver also reset the RK11 and waited for it to be ready. There is
no reset here. On success the next part of the request is started if
there is one (#l("} else if ((rkoff += rkn) < bp->b_bcount) {")), and the request is otherwise complete. After a
read, the cache is invalidated once more over the whole buffer (#l("dcinval(bp->b_un.b_addr, bp->b_bcount);")),
so that any line which the processor may have fetched while the
transfer was under way is discarded. Nothing is written back: a line
written back now would overwrite the new data. The lines were clean at
the start (#l("dcflush(bp->b_un.b_addr+rkoff, rkn);")), and the buffers of the buffer cache share no line with
a neighbour (#f("main.c")). A raw transfer may share its first and last
lines with the rest of the process's memory, but the process sleeps
until the transfer is done, and nothing else writes there.

#lines-to("void", after: "}")



#lines-to(none)
#source("/usr/sys/dev/ddr.c")

This file is not a driver in v7's sense: it has no switch entry and no
special file, and its one procedure, `ddrinit`, is called once, early
in `machine_init` (#f("machdep.c")), through `clock_ddr_init`
(#f("mp135/c.c")), and never again. Its job is to make the DDR memory
of the MP135 machine usable. Nothing like it existed in v7, since a PDP-11's
core was ready when the machine was switched on.

The boot ROM of the MP135 machine brings up only the chip's SYSRAM, in
which the kernel runs. The 512 MB of DDR3L memory are dead until a memory controller and its physical interface ("PHY")
have been clocked, configured, and trained to the particular chips.
This is normally the work of a first-stage boot loader, and here the
kernel is the first stage. The page tables, the core, and all the
processes are in DDR (#f("mp135conf")), so the work must be done before
anything else touches it, and `machine_init` calls `ddrinit` immediately
after the device registers are mapped and the console is set up, before
it maps the DDR, clears `.ddrbss`, and builds the table of the u-area.
The registers are named by their kernel addresses, those of the blocks
which #f("mp135conf") maps. The work cannot be left to a user program:
the kernel, its page tables, and the first processes would then all
have to fit in SYSRAM, and they do not.

This is also one of the places where the kernel changes the chip's
clocks. The others enable the clocks of the SD card's controller and
pins (`rkinit`, #f("sd.c")) and of the bus to the power controller
(`ddrpower`, #f("pmic.c")). Elsewhere they are taken as the ROM left
them, but the DDR needs a clock of a particular frequency which the ROM
does not provide.

The register values are those of the maker's reference firmware for its
own board, the STM32MP135F-DK, for DDR3 at 533 MHz (DDR3-1066). They
suit the memory chip of this board as well, a Kingston D2516EC4BXGGB. Unlike the other drivers, this one names
its registers by their offsets and gives no names to the bits. The
values below are explained in the text.

#lines-to("static unsigned int ddrc[] = {")

The table `ddrc` is a list of pairs, register offset and value, for the memory
controller, ended by `0xFFFF`. In turn they set the type and width of the memory (`MSTR`, at offset 0); the mode register access, derating,
power saving, and refresh controls (`0x10`--`0x60`); the parity and
CRC control (`0xc0`); the impedance
calibration (`0x180`); the timing of the interface to the PHY, the "DFI"
(`0x190`--`0x1c4`); on-die termination (`0x244`); debugging and the port
configuration (`0x300`--`0x400`); the refresh timing (`0x64`); the
timings of the DRAM itself, the `DRAMTMG` registers (`0x100`--`0x138`),
and the timing of on-die termination (`0x240`); the mapping of address bits to bank, row, and column (`0x204`--`0x22c`);
`INIT0` (`0xd0`), whose value says, among other things, that the PHY
and not the controller will initialise the DRAM; and the scheduling and
quality of service of the port (`0x250`--`0x4a0`). The order is that of
the reference firmware.

#lines-to("static unsigned int dphy[] = {", lead: true)

The table `dphy` does the same for the PHY. It sets its general configuration, I/O and
data lane settings (`0x8`--`0x200`), its timing (`0x18`--`0x3c`), and the
values of the four DDR3 mode registers, `MR0` to `MR3` (`0x40`--`0x4c`),
which the PHY writes into the DRAM when it initialises it.

#lines-to("static void")

The routine `pgwait` waits for the PHY to finish a piece of work which `PIR` has
started. The PHY's general status register `PGSR` (`0xc`) reports the
end in bit 0, or a failure of the impedance calibration, of the initialisation of the
DRAM, or of the training in one of the error bits `0x3e0`. Either ends the wait (#l("while (((s = DPHY(0x00C)) & 0x3E1) == 0)"), #l(";", after: "while (((s = DPHY(0x00C)) & 0x3E1) == 0)")). A failure leaves the
memory unusable, and the kernel cannot run without it, so the status
is printed and the system stops with a panic (#l("if (s & 0x3E0) {")--#l("}", after: "panic(\"ddr\");")). The status is
printed first because `panic` (#f("prf.c")) calls `update`, which the
buffer cache, not yet set up, might keep from returning.

#lines-to("void")

First the memory's power is turned on (114, `ddrpower`, #f("pmic.c")),
and then its clock. PLL2 clocks the DDR from its R output, but the boot
ROM also runs the system's AXI bus from PLL2's P output, so while PLL2
is stopped the bus is moved to HSI, the internal 64 MHz oscillator: the
bus clock's selector (`0x544`) is set to 0, and its bit 31 waited for,
which says that the switch is done (#l("RCC(0x544) = 0;")--#l(";", after: "RCC(0x544) = 0;")). PLL2 is then stopped,
with its three outputs (bits 4--6), and waited for (#l("RCC(0x4D0) &= ~0x71;")--#l(";", after: "while (RCC(0x4D0) & 2)")).

PLL2 shares its reference with PLL1, which clocks the processor and so
cannot be stopped. The reference is therefore left as the ROM chose it,
and only its divider is set to suit. From HSE, the external 24 MHz
crystal (the source field of `0x480` nonzero), it divides by 3, and from HSI by 8. Either way the reference is 8 MHz. It is
multiplied by 66 plus a fraction of 5120/8192, which gives 533 MHz,
and the R output divides that by 1 (#l("RCC(0x4D4) = RCC(0x480)&3 ? 0x00020041 : 0x00070041;")--#l("RCC(0x4DC) |= 0x10000;")). The outputs and the PLL
are then enabled, the PLL waited for until it is locked, and the bus
returned to PLL2's P output (selector value 2, #l("RCC(0x544) = 2;")--#l(";", after: "RCC(0x544) = 2;")).

#lines-to("if (R(0xF000100C) & 0x1000) {")

If a previous low power mode left the DDR pads in retention (bit 12 of
the power controller's `PWR_CR3`, physical address `0x5000100c`, which
lies in the block of the reset and clock controller and so at
`0xf000100c`), the PHY could not drive the memory. Retention is turned
off (#l("if (R(0xF000100C) & 0x1000) {")--#l("}", after: "R(0xF000100C) &= ~0x1000;")).

The TrustZone address space controller, `TZC`, at physical `0x5c006000`
and mapped at `0xf0806000` (#f("mp135conf")), guards DDR. It filters
every access by its address and by the security state of the bus
master. Its clock, and that of the memory
encryption unit beside it, are enabled (#l("RCC(0x780) = 2;")--#l("(void)RCC(0x740);")). Then, with its
filter disabled, region 0, which covers the whole of DDR, is opened to
reading and writing by every master (#l("R(0xF0806008) = 0;")--#l("R(0xF0806008) = 1;")). The SD card's DMA
controller is one of the masters which must reach it.

#lines-to("DDRITFCR &= ~0x100;")

The controller is now started up, following the sequence in the
reference firmware. Through `DDRITFCR`, the RCC's register for the DDR
interface, automatic clock gating is turned off for the duration (#l("DDRITFCR &= ~0x100;"));
all the resets of the controller and PHY are asserted (#l("DDRITFCR |= 0xFC000;")); their
clocks are enabled (#l("DDRITFCR |= 0x251;")); and the resets of the PHY and of the
controller's register interface are released (#l("DDRITFCR &= ~0xC0000;"), #l("DDRITFCR &= ~0x4000;")). The loop
(#l("for (i = 0; i < 10000; i++)", after: "DDRITFCR &= ~0x4000;")) waits for the logic to settle. Its body reads a register, which
the compiler must do, since an empty delay loop is removed by an
optimising compiler.

#lines-to("DDRC(0x1B0) &= ~1;")

The controller is told not to consider the PHY ready (`DFIMISC`,
#l("DDRC(0x1B0) &= ~1;", after: "DDRITFCR &= ~0x4000;")), and is programmed from `ddrc`. The remaining resets, of the
controller's core, its AXI port, and the PHY's register interface, are
released (#l("DDRITFCR &= ~0x38000;")), and the PHY is programmed from `dphy`. The PHY
performs some initialisation of its own on leaving reset. Its general
status register `PGSR` (`0xc`) reports the end of it in bit 0, and that
is awaited (#l("while ((DPHY(0x00C) & 1) == 0)")).

#lines-to("DPHY(0x004) = 0x1007F;")

Writing `0x1007f` to the PHY's initialisation register `PIR` (#l("DPHY(0x004) = 0x1007F;"))
asks it to reset and lock its DLLs, calibrate the output impedance,
reset the memory and run its initialisation sequence, and to report
completion to the controller only when all of this is done (bit 16). After a short delay, which
lets the previous completion flag drop, `pgwait` (#l("pgwait();", after: "DPHY(0x004) = 0x1007F;")) waits for the
work to be done, or stops the system if it has failed.

The controller is then told that the PHY is ready. `DFIMISC` is one
of the controller's "quasi-dynamic" registers, which may be changed
only between a clear and a set of `sw_done` in `SWCTL` (`0x320`). The
controller acknowledges in `SWSTAT` (`0x324`). Once the change is
acknowledged, the controller brings the memory to normal operation,
which `STAT` (`0x4`) reports as mode 1 (#l("while ((DDRC(0x004) & 7) != 1)")).

#lines-to("DDRC(0x320) &= ~1;", after: ";")

Finally the PHY is trained. It must learn when, relative to its own
clock, the strobe which accompanies data read from the memory is valid
("DQS gate training"). Without this, reads do not work. During the
training the controller must not issue refresh commands, so, by the
same handshake, automatic refresh is turned off (#l("DDRC(0x060) |= 1;")) and the
controller again told that the PHY is not ready. `PIR` is set to
`0x81` (#l("DPHY(0x004) = 0x81;")), which runs the training, and `pgwait` (#l("pgwait();", after: "DPHY(0x004) = 0x81;")) waits for its completion, as before. Refresh is turned back on and the PHY declared ready
(#l("DDRC(0x320) &= ~1;", after: "DPHY(0x004) = 0x81;")--#l(";", after: "DDRC(0x060) = 0;")).

The controller's AXI port, through which the processor and the DMA
controllers reach memory, is enabled (#l("DDRC(0x490) |= 1;")), and clock gating is
restored (#l("DDRITFCR |= 0x100;")). DDR may now be used.

#lines-to(none)

= Part Two: The Shell

== User Space <ch-user>

#source("/usr/sys/dev/pmic.c")

The DDR memory needs power before `ddrinit` (#f("ddr.c")) can start
it, and on the MP135 machine the power comes from a separate chip, the
STPMIC1 power management controller, whose regulators are set over an
I2C bus. The boot ROM leaves the DDR's two supplies off: `BUCK2`, which
gives the memory its 1.35 V, and `VREF_DDR`, its reference voltage.
The one routine here, `ddrpower`, turns them on, and `ddrinit` calls it
first.

`RCC` and `GPIO` (#l("#define\tRCC(o)\tR(0xF0000000+(o))"), #l("#define\tGPIO(p, o)\tR(0xF0002000+(p)*0x1000+(o))")) are the reset and clock controller and the
general purpose I/O ports, by their kernel addresses, as in #f("sd.c"), and
`I2C` is the controller of the chip's fourth I2C bus, I2C4, at offset
`0x5000` in the block which #f("mp135conf") maps at `0xf0a00000`.

#lines-to("static int")

The routine `i2cwait` waits up to a tenth of a second for a bit of the controller's
interrupt and status register (`0x18`) to be set. If instead the PMIC
did not acknowledge (`NACKF`, `0x10`), or the time runs out, it clears
that flag and the stop flag (`0x30` to the clear register, `0x1c`) and
fails.

The routine `pmic` reads (`val` negative) or writes one register of the PMIC, whose
address on the bus is `0x33`. Control register 2 (`0x04`) starts a transfer. It holds the address, shifted left one place as the register wants
it; the number of bytes, one for a read, which first sends just the
register number, and two for a write, number and value (bits 16--23);
the start bit (13); and for a write the "autoend" bit (25), with which
the controller sends the stop condition itself. Each byte is written to
the transmit register (`0x28`) once the transmit flag (2) asks for it.
A read, once the register number has gone (transfer complete, `0x40`),
restarts the transfer in the read direction (bit 10) for one byte with
autoend, and takes it from the receive register (`0x24`) when the
receive flag (4) is set. Either way it waits for the stop (`0x20`),
clears it, and returns the value.

#lines-to("static void", lead: true)

The routine `pinmode` enables the clock of the pin's port and reads the
register back, so that the clock runs before the port is touched. It
then gives the pin its mode (2, alternate function) in the mode register, makes it open-drain
in the output type register (`0x04`), as I2C requires, and selects
alternate function 6, I2C4, in the low or high alternate function
register (`0x20`, `0x24`), four bits per pin.

#lines-to("/*")

The routine `ddrpower` puts PE15, the clock line SCL, on I2C4; chooses
HSI, the internal 64 MHz oscillator, as I2C4's kernel clock (`0x604`,
value 2 in bits 3--5); and enables I2C4's clock (`0x748`, bit 5). The
timing register (`0x10`) divides the 64 MHz by 2, giving steps of
31.25 ns, and holds SCL low for 138 steps and high for 95, a bus clock
of somewhat over 100 kHz, with the hold and setup delays the
controller's documentation gives for that clock.

The data line SDA is pin PB7 (#l("pinmode(1, 7, 2);")), and the controller is then
enabled.

The PMIC is then told to set `BUCK2` to 1.35 V and turn it on (register
`0x21`: voltage code 30 in bits 2--7, enable bit 0) and to turn on
`VREF_DDR` (register `0x24`, bit 0). If it does not answer, the system
cannot go on, and panics. A hundredth of a second is allowed
for the voltages to settle before `ddrinit` starts the memory.

#lines-to(none)
#source("/usr/src/libc/csu/crt0.s")

Every C program begins here. The linker puts `crt0.o` first, ahead of the
program's own objects and the library, and its `_start` is the entry
point which the linker writes into the ELF header and `exece`
(#f("sys1.c")) loads into the saved `pc`. The routine finds the arguments and the environment which `exece` left
on the stack, calls `main` with them, and passes the value which `main`
returns to `exit`. It also holds the definition of `environ`, the environment
which the library shares with every program.

The file is a rewrite of v7's PDP-11 `crt0.s`. Even the names have
changed. The PDP-11 C compiler
prefixed an underscore to every external name, so that v7's `_main`,
`_exit`, and `_environ` were C's `main`, `exit`, and `environ`, and the
entry point, being no C name, was `start`. The ARM compiler adds no
prefix, so the names lose their underscores, and the entry point is
called `_start` because that is the symbol which the GNU linker takes for
the entry by default.

On entry the stack pointer addresses the block that `exece` built, of the argument count, the
argument pointers and a zero, the environment pointers and a zero, and
the strings. The code loads `argc` (#l("ldr\tr0, [sp]")) into `r0`,
`argv` (#l("add\tr1, sp, #4")), the address of the word above it, into `r1`, and the
environment pointer (#l("add\tr2, r1, r0, lsl #2"), #l("add\tr2, r2, #4")), `argc` + 1 words above `argv`, into `r2`.
This is the ARM procedure call standard: the first four arguments of a
call travel in `r0` to `r3`, so `main(argc, argv, envp)` finds its three
arguments ready. The environment pointer is also stored in `environ`
(#l("ldr\tr3, =environ"), #l("str\tr2, [r3]")), where the `exec` stubs `execl` and `execv` (and through them
`execvp`, #f("gen/execvp.c")), and `getenv`, find it.

The v7 version had to work harder. Its C passed arguments on the stack, so the
routine made room for two extra words below `argc` and copied in `argc`,
`argv`, and the environment pointer, in the order in which `main`
expected to find them. And it found the environment by searching
`argv` for its terminating zero, then compared the address so reached
with that of the first string: if the two met, the stack had no
environment list at all, and `environ` was made to point at the final zero instead.
The port's `exece` always supplies both lists, and the address is
computed directly. Two more PDP-11 instructions are gone. The first, `setd`, put
the floating point unit into double precision mode. The ARM's unit has
no such mode, for each instruction names its precision, and `exec` has
already cleared its status register (#f("sys1.c")). The second, `clr -2(r0)`, cleared the word just below the
first string, which v7's `exece` had already set to zero. The port's
start-up does not touch the block at all.

The stack pointer is not adjusted before the call. The standard
requires it to be a multiple of 8 at every call, and `exece` rounds it
so (#f("sys1.c")).

The return value of `main` stays in `r0`, which is where `exit` (#l("bl\texit")) wants
its argument, whereas v7 had to move it onto the stack. The routine `exit` flushes the
standard I/O buffers and calls `_exit`, which does not return. As in
v7, the call of `exit` is followed by a bare `exit` system call (#l("mov\tr7, #1"),
#l("svc\t#0", after: "mov\tr7, #1")), in case `exit` should come back: the call number 1 is put in `r7`
and `svc` traps, as in `cerror` (#f("libc/syscall.s")).

#lines-to(".comm\tenviron, 4")

`.comm` reserves a word of `bss` for `environ`, as v7's `crt0.s` did
with a two byte word in `.bss`. As in v7, `errno` is defined with the
routine which sets it (#f("libc/syscall.s")).

The v7 file ended by reserving two bytes at the start of `.data`. In a
program with separate instruction and data spaces, data location 0
would otherwise have held a variable, whose address would then compare
equal to a null pointer. The port's programs are linked at `0x8000`
(#f("Makefile")), so no object of the program can lie at address 0, and
the padding is gone.

#lines-to(none)
#source("/usr/src/libc/csu/mcrt0.s")

The file `mcrt0.o` takes the place of `crt0.o` in a program to be profiled, one
compiled with `-pg` and linked with this file first. It starts as
#f("csu/crt0.s") does (#l("ldr\tr0, [sp]")--#l("str\tr2, [r3]")), and keeps `argc`, `argv`, and the
environment in registers which survive calls (#l("mov\tr4, r0", after: "str\tr2, [r3]")--#l("mov\tr6, r2")). It then
obtains, with `sbrk`, a buffer for `monitor` (#f("gen/mon.c")), of six halfwords of header, four for each of `CBUFS` call counts, and a
histogram of one halfword for every eight bytes of the program's text,
from `eprol`, the end of this file, to `etext`, which the linker defines
(#l("ldr\tr0, =etext")--#l("bl\tsbrk")). That is v7's density: one counter for every two
instructions. A fifth argument goes on the stack, which is kept a
multiple of 8 (#l("mov\tip, #CBUFS"), #l("str\tip, [sp, #-8]!")). If there is no room, a message is written and
the program ends (#l("nospace:")--#l("bl\t_exit", after: "mov\tr0, #1")).

This file defines `exit` (#l("exit:")--#l("bl\t_exit", after: "mov\tr0, #0")), so that the library's
(#f("gen/cuexit.c")) is not loaded: it flushes the standard I/O
buffers, calls `monitor` with a null address to stop the sampling and
write `mon.out`, and ends the process. The v7 file did the same.

The v7 compiler made each function call `mcount` with the address of a
word of its own, in which `mcount` kept a pointer to the function's
counter, so that the counter was found at once. GCC's `-pg` instead
makes each function begin by pushing its return address and calling
`__gnu_mcount_nc` (#l("__gnu_mcount_nc:")--#l("bx\tip")), whose return address then lies within the
function. The routine saves the argument registers, passes that
address to `mcount`, and returns to the function with its own return
address restored from the stack.

#lines-to(none)
#source("/usr/src/libc/gen/mon.c")

The routine `monitor` is v7's, for 32-bit words. Called with a range of text
addresses, a buffer, its size in halfwords, and a number of call
counters, it lays out the buffer as `mon.out` will hold it, with the header `hdr`,
the counters `cnt`, and the histogram (#l("((struct hdr *)buf)->lowpc = lowpc;")--#l("bufsiz -= (buf - sbuf);")), the layout which
`prof` reads (#f("cmd/prof.c")). It then asks the kernel through
`profil` to count the program counter into the histogram at each clock
tick. The scale is a fraction of 0x10000 by which the offset of the
program counter from the start of the range is multiplied to index the
histogram (`addupc`, #f("clock.c")): 0x10000 gives a counter to every
two bytes, and a smaller histogram a proportionally coarser one
(#l("if(bufsiz < o)")--#l("profil(buf, bufsiz<<1, (int)lowpc, o);")). Called with a null address, `monitor` stops the counting and
writes the whole buffer to `mon.out` (#l("if (lowpc == 0) {")--#l("}", after: "close(o);")).

New in this file, `mcount` counts a call of the function from which
`__gnu_mcount_nc` (#f("csu/mcrt0.s")) passes an address. Lacking v7's
per-function word, it searches the counters filled so far for the
address, and takes a new one if it is not there and one is free
(#l("mcount(unsigned pc)")--#l("}", after: "cntnext++;")). A program with a few hundred functions is profiled at the cost
of that search on every call.

#lines-to(none)
#source("/usr/src/libc/gen/cuexit.c")

The routine `exit` flushes the program's output streams, through `_cleanup`
(#f("stdio/flsbuf.c")), and ends the process with `_exit`, the system
call. Where v7 used a few lines of assembler, the port uses C.

#lines-to(none)
#source("/usr/src/libc/gen/abort.c")

The routine `abort` ends the program with a core image by sending itself `SIGIOT`.
In v7 it executed the PDP-11's `iot` instruction, whose trap the kernel turned
into that signal. The ARM has no such instruction, and `kill` reaches
the same end.

#lines-to(none)
#source("/usr/src/libc/syscall.s")

This short routine is where every system call made by a C program
enters the kernel. Each library stub, such as `read` in
#f("sys/read.s"), loads its call number into `ip` and branches here;
`cerror` makes the call and turns the kernel's reply into the C
convention, a result or -1 with the error number in `errno`. Only
`fork` makes its call itself, since the kernel returns to its parent
and its child at different places (#f("sys1.c")).

The file corresponds to nothing in v7 of the same name and content.
In v7, `syscall.s`, a compatibility routine of its library, was a
routine `syscall(n, r0, r1, a1, ...)` which built a `sys` instruction
for call `n` at run time, and has no counterpart here. What this file
does replace is v7's
`cerror.s`, together with the `sys` instruction which each v7 stub
contained. The name `cerror` is v7's. Its job has grown.

On the PDP-11 a system call was the instruction `sys n`, a trap whose
low bits held the call number. Arguments came partly in `r0` and partly
in the words following the instruction, which the kernel fetched from
user space and stepped over (#f("trap.c")). The kernel reported failure
by setting the carry bit in the saved processor status, with the error
number in `r0`. Each stub therefore tested the carry with `bec`
(branch if carry clear) after the trap and, on an error, jumped to
`cerror`, which stored `r0` in `errno`, loaded -1, unwound the stub's
`r5` frame, and returned to the stub's caller.

The ARM has `svc`, which takes an exception to the kernel's `svc_entry`
(#f("low.s")). There the user registers and status are saved, and `trap`
(#f("trap.c")) is called with a pointer to them. The 24-bit immediate
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
still holds the return address in the stub's caller. The routine `cerror` saves the
caller's `r7` on the stack (#l("push\t{r7}")), moves the number into it (#l("mov\tr7, ip")), traps (#l("svc\t#0")),
and restores it (#l("pop\t{r7}")).

The register `ip` is also the one which the linker may use in a
veneer, a few instructions it inserts when a branch cannot reach its
target. An ARM branch reaches 32 MB either way, and a program here is
less than 1 MB, so no veneer is ever placed between a stub and `cerror`.

Note too that the push of one word leaves the stack pointer misaligned
by 4 while the call is in progress. Nothing is called meanwhile. And if
a signal is delivered on the way back to user mode, `sendsig`
(#f("machdep.c")) rounds the handler's stack down to a multiple of 8.

#lines-to("bxcc\tlr")

As v7's kernel did, `trap` reports failure by setting the carry bit in
the saved status, which `svc_entry` restores to the `CPSR` on the way
back, with the error number in `r0`. A successful call clears the carry
and returns its result in `r0`, with a second value in `r1`. Every
other register comes back as it was. If the carry is clear, `r0` is
returned to the caller unchanged (#l("bxcc\tlr")), with `bxcc`: a return through the
link register, executed only if the carry is clear, the ARM's form of
v7's `bec`. Otherwise `r0` is stored in `errno` (#l("ldr\tr2, =errno"), #l("str\tr0, [r2]")) and -1 returned
(#l("mvn\tr0, #0"), #l("bx\tlr")), and `mvn r0, #0` loads the complement of zero, which is -1.

Neither the stores nor the return disturb the flags, so the carry
reaches the caller of `cerror`. Stubs whose calls return two values, or
store results through a pointer, such as `pipe`, `wait`, and `sbrk`,
call `cerror` with `bl` instead, and test the carry themselves on its
return. Since the error is not in the value, a call may succeed with any
result, an offset from `lseek` beyond 2 GB or a `time` after January
2038 among them.

#lines-to(".comm\terrno, 4")

This file reserves `errno` (#l(".comm\terrno, 4")), a word of `bss`, as v7's `cerror.s`
reserved `_errno`. Every program which makes a system call links this
file, and the C files of the library declare `errno` `extern`, so this
is its one definition. That matters: were `perror.c` to define `errno`
too, as v7's did, the linker would resolve the common symbol by pulling
`perror.o`, and `sys_errlist` with it, into every program which made a
system call.

#lines-to(none)
#source("/usr/src/libc/sys/read.s")

The stub `read` stands for the fifty or so stubs in the library's `sys`
directory, one file per system call. Most are just these
three instructions with a different number: the number of the call in
the table `sysent` (#f("sysent.c")), here 3, is loaded into `ip`, and
`cerror` (#f("libc/syscall.s")) does the rest. The three arguments of
`read(fd, buf, count)` arrive in `r0`, `r1`, and `r2`, which is where
`trap` will look for them, and they are not touched. Because the stub
branches rather than calls, `cerror` returns straight to the caller of
`read`.

In v7, `read.s` ran to two dozen lines, and the difference is instructive.
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
gone. `.globl cerror` is v7's line. The GNU assembler would in any case
treat an undefined name as external.

#lines-to(none)
#source("/usr/src/libc/sys/signal.s")

A call `signal(n, func)` sets the action to be taken on signal `n`, which is 0 for the default, 1
to ignore the signal, or the address of a function to be called. It returns the previous action. In the port it is an ordinary
stub, call 48, identical in form to `read` (#f("sys/read.s")). The
kernel's `ssig` (#f("sys4.c")) checks the signal number, rejecting 0,
anything not below `NSIG`, and `SIGKIL`, and exchanges `func` with
`u.u_signal[n]`.

In v7, `signal.s` ran to nearly ninety lines, because on the PDP-11 a C function
could not be the target of a signal directly. When a signal was caught
v7's `sendsig` pushed the processor status and the program counter onto
the user stack and started the process at the handler's address, as an
interrupt would. The code there had to preserve every register and end
with `rtt`, the instruction which pops both words back. A C function
was free to change `r0`, `r1`, and the condition codes, and ended with
`rts`. So the library
interposed a vector of its own. For each signal there was an entry in
`tvect`, a `jsr r0` to common code which saved `r0` to `r4`, computed the
signal number from the address of the entry, called the user's function
through the table `dvect` with the number as its argument, restored the
registers, and executed `rtt`. The routine `signal` stored the user's function in
`dvect[n]` and gave the kernel the address of `tvect`'s entry for `n`
instead, unless the action was 0 or odd. Because the kernel's previous
value was then the address of a `tvect` entry, `signal` returned the
old `dvect[n]` instead, unless the kernel's value was odd, meaning
ignored. It also checked `n` against `NSIG` itself before indexing its
tables, and failed with `EINVAL`, error 22, if the number was out of range.

All of that work has moved into the kernel, which saves the
interrupted registers, calls the handler as an ordinary C function with
the signal number as its argument, and restores the registers when it
returns (`sendsig`, #f("machdep.c")). The handler is thus a real C
function of one argument, which is why the handlers in `init` (#f("cmd/init.c")) and
elsewhere now take an `int`, and why `signal.h` declares
`void (*signal(int sig, void (*func)(int sig)))(int sig)`.

Since the kernel holds the user's own function, the value it returns
is the previous action as the user set it, and no translation is
needed. A signal's action lasts for one delivery: when a signal other than `SIGINS` or `SIGTRC` is caught,
`psig` (#f("sig.c")) resets the action to the default before calling
`sendsig`, so a handler which wishes to catch the next one must call
`signal` again.

The convention that an odd action means "ignore" survives
only because no handler can have an odd address. On the PDP-11
instructions were at even addresses. On the ARM an odd function address
denotes Thumb code. Every program here is compiled with `-marm`, so
every function which could be a handler lies on a word boundary.

#lines-to(none)
#source("/usr/src/libc/sys/fork.s")

The one stub which makes its call itself is `fork`, since the kernel
returns from it to two places (#f("sys1.c")): the child resumes at the
instruction after the `svc`, the branch to 1 (#l("b\t1f")), and the parent one
instruction further on (#l("pop\t{r7}", after: "b\t1f")), where the carry bit tells it whether the
call failed. Each gets the other's process id in `r0`. The parent
returns it. The child stores it in `par_uid`, as v7's did, and returns
0. The register `r7` is saved and restored as in `cerror`
(#f("libc/syscall.s")), on both paths.

#lines-to(none)
#source("/usr/src/libc/sys/pipe.s")

The stub `pipe` gets two descriptors back, in `r0` and `r1`, and must store them
into the array whose address the caller passed in `r0`. The stub saves
that address and its return address on the stack and calls `cerror`
with `bl`, so that `cerror` returns here (#l("push\t{r0, lr}")--#l("bl\tcerror")). If the carry is set,
`cerror` has already stored the error and loaded $-1$, and the stub
returns that (#l("bxcs\tlr")). Otherwise it stores the two descriptors and returns
0 (#l("stmia\tr2, {r0, r1}")--#l("bx\tlr")). The stubs `wait` and `time` work the same way.

#lines-to(none)
#source("/usr/src/libc/sys/wait.s")

The stub `wait` returns the id of a child that has exited, and, if the caller
gave a pointer, stores the child's status, which the kernel returns in
`r1`, through it (#l("cmp\tr2, #0")--#l("strne\tr1, [r2]")).

#lines-to(none)
#source("/usr/src/libc/sys/execl.s")

A call `execl(file, arg0, arg1, ..., 0)` passes its arguments to `exece` as an
array, with the environment. The array is already almost in memory: by
the procedure call standard `arg0` to `arg2` arrive in `r1` to `r3`, and
any further arguments on the stack, in order, just above the stack
pointer. Pushing `r1` to `r3` (#l("push\t{r1, r2, r3}")) puts the first three directly below
the rest, so that the stack pointer is then the address of the whole
list, which becomes the second argument (#l("mov\tr1, sp")), and `environ` is the third
(#l("ldr\tr2, =environ")--#l("ldr\tr2, [r2]")). The call returns only if it fails, when the stub pops the three
words and returns $-1$. The v7 version built the same list from its stack frame.

#lines-to(none)
#source("/usr/src/libc/sys/execv.s")

A call `execv(file, argv)` already has its file and argument list in `r0` and
`r1`. The stub adds `environ` as the third argument (#l("ldr\tr2, =environ")--#l("ldr\tr2, [r2]")) and makes the
call `exece`, 59, through `cerror`.

#lines-to(none)
#source("/usr/src/libc/sys/dup.s")

The stub `dup` duplicates a descriptor, and `dup2(f, nf)` makes `nf` a copy of `f`.
It is the same call, `dup`, with the bit `0100` set in the first
argument to say that the second is given (#l("orr\tr0, r0, #64")), which the kernel tests
(#f("sys3.c")). The v7 stub set the bit the same way.

#lines-to(none)
#source("/usr/src/libc/sys/lseek.s")

The call `lseek` needs only a plain stub: its three arguments, a descriptor, a `long`
offset, and the origin, arrive in `r0` to `r2`, where the kernel takes
them. On the PDP-11 the `long` took two words, and v7's stub had to
place three words after its `sys` instruction.

#lines-to(none)
#source("/usr/src/libc/sys/ptrace.s")

A call `ptrace(req, pid, addr, data)` lets a parent read and write a stopped
child's memory and registers. The kernel takes the data word in `r0`
and the request last, as v7's PDP-11 call did, so the stub exchanges
`r0` and `r3` through `ip` (#l("mov\tip, r0")--#l("mov\tr3, ip")) before the call. It first clears
`errno` (#l("push\t{r0}")--#l("pop\t{r0}")), so that a caller reading a word can tell a word of $-1$
from a failure by testing `errno`: `cerror` stores `errno` only when
the call fails. Every argument register is in use, so `r0` is lent to
the store and taken back from the stack.

#lines-to(none)
#source("/usr/src/libc/sys/sbrk.s")

The stub `brk` sets the end of the program's data, the break, to an address,
and `sbrk` moves it by an amount and returns the old end, the start of
the new space. The library keeps the break in `nd`, starting at `end`,
the end of the program's uninitialised data, which the linker defines.
The stub `sbrk` now first rounds the old break up to a multiple of eight bytes
(#l("add\tr1, r1, #7")--#l("bic\tr1, r1, #7")), so that the space it returns is aligned for any type, as the
ARM's `double`s and the `ldrd` and `strd` instructions require. The
PDP-11 needed no more than an even address. Only if the call succeeded does `brk` record the new break
(#l("ldrcc\tr2, =nd")--#l("strcc\tr1, [r2]")).

#lines-to(none)
#source("/usr/src/libc/sys/time.s")

The stub `time` returns the time as the port's 64-bit `time_t`, which the kernel
returns in `r0` and `r1` together (#f("sys4.c")). The procedure call
standard returns a `long long` in that pair, so the stub need not move
it. If the caller passed a pointer, both words are stored through it
(#l("cmp\tr2, #0")--#l("stmne\tr2, {r0, r1}")). The stub `ftime` is plain.

#lines-to(none)
#source("/usr/src/libc/sys/stime.s")

A call `stime(tp)` sets the time, for the super-user only (#f("sys4.c")). The
caller passes a pointer to a 64-bit `time_t`. The stub loads both words
into `r0` and `r1` (#l("ldm\tr0, {r0, r1}")), where the kernel takes the argument.

#lines-to(none)
#source("/usr/src/libc/sys/getuid.s")

The kernel's `getuid` returns the real user id in `r0` and the
effective one in `r1` (#f("sys4.c")). The stub `getuid` returns the first, and
`geteuid` makes the same call and returns the second (#l("geteuid:")--#l("pop\t{pc}")).

#lines-to(none)
#source("/usr/src/libc/sys/getgid.s")

The stubs `getgid` and `getegid` do the same for the group ids.

#lines-to(none)
#source("/usr/src/cmd/init.c")

Process 1 is `init`. The routine `main` (#f("main.c")) makes it with `newproc`,
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

Every orphan also passes to `init`. When a process exits, `exit`
(#f("sys1.c")) makes process 1 the parent of its children, so `init`'s
`wait` collects them too. Most of its loops simply discard the ones it
does not recognise.

Two signals steer it. A hangup, `kill -1 1` from the super-user,
makes it kill everything and return to single-user mode. An interrupt,
`kill -2 1`, makes it read `/etc/ttys` again, so that terminals can be
enabled and disabled without a reboot.

The file includes `stdio.h` (#l("#include <stdio.h>")),
although `init` uses no standard I/O, because the port's `stdio.h`
(#f("stdio.h")) carries the prototypes of the library's system call
stubs, `fork`, `execl`, `alarm`, and the rest, and C99 does not allow a
function to be called without a declaration. For the same reason the
functions of the file are declared before use (#l("void\tshutdown(void), watchdog(void), single(void), runcom(void), merge(int sig),")--#l("int\trline(void), get(void);")), and v7 relied on
their being implicitly `int`. Elsewhere `register i` has become
`register int i`, since C99 has no implicit `int`.

`ALL` and `EVER` (#l("#define\tALL\tp = &itab[0]; p < &itab[TABSIZ]; p++"), #l("#define\tEVER\t;;")) supply the control part of a `for` statement,
so that loops may be written `for(ALL)` and `for(EVER)`. The table `itab` holds one entry per active terminal, with the line name, the `getty`
table character, and the process id of the process serving it, 0 if
none.

#lines-to("int", after: "int\trline(void), get(void);")

The outer loop is `main`: kill everything, restart the feeder of the
watchdog, run a single-user shell, run `/etc/rc`, read `/etc/ttys` and start the `getty`s, then wait for
children until `wait` fails. The call fails only when `init` has no
children at all. Since a dead `getty` is at once replaced, that happens
only when no terminal is served: none is enabled in `/etc/ttys`, or
`fork` failed for each. Then `multiple` returns, and the cycle starts again from the shutdown.

The `setjmp` (#l("setjmp(sjbuf);")) marks the point to which `reset` (#l("void", after: "lseek(f, (long)0, 2);")) returns when a
hangup arrives. In v7, `reset` was declared locally (deleted), as a
function returning `int`. It is now declared at #l("rmut(struct tab *p), reset(int sig);") as a `void` function
of the signal number, the form which `signal` requires (#f("sys/signal.s")).

Every call of `merge` passes an argument (#l("merge(0);")) because the routine doubles as the
handler for `SIGINT`, and a handler receives the signal number, and v7
called it with none.

#lines-to("void", lead: true)

The routine `shutdown` clears the table, killing any process it names, and then
kills every other process. From the super-user, `kill(-1, SIGKILL)` (#l("kill(-1, SIGKILL);"))
sends the signal to every process but 0 and 1 (`kill`, #f("sys4.c")).
Then `init` waits for all its children. Should some child fail to die
(a process sleeping in the kernel at a priority below `PZERO` does not
see signals), the alarm set at #l("alarm(60);") fires after a minute, `reset` jumps
back to the `setjmp`, and the shutdown begins again. Finally the file
descriptors are closed, so that the next stage starts clean.

#lines-to("/*", after: "close(i);")

The routine `watchdog` starts `/etc/wdog` (#f("cmd/wdog.c")), which feeds the
MP135 machine's watchdog (#f("iwdg.c")). The shutdown has just killed
it with every other process, and the board would reset 33 seconds
later. It is started here, not in `/etc/rc`, because single-user mode
runs no `rc`, and the board must stay up there too. The child runs
`wdog` with the name `wdog` (`wdog+5` skips `/etc/`), and exits if the
program is missing. On the QEMU machine `wdog` finds no watchdog and exits
at once.

#lines-to("void", lead: true, after: "}")

The routine `single` forks a shell on the console and waits for it to finish. The
child opens `/dev/console` for reading and writing. It gets descriptor 0,
since all are closed, and the two `dup`s give 1 and 2. As this is the
child's first terminal, `ttyopen` (#f("tty.c")) makes it the leader of a
process group belonging to the console, so that the interrupt and quit
characters typed there reach the shell and its children. The `init` process itself
never opens a terminal. Its process group is 0, and no character typed
on any terminal can signal it.

The shell is called with the name `-` (#l("execl(shell, minus, (char *)0);")). A name beginning with `-`
tells the shell (#f("sh/main.c")) that it is a login shell, so it reads
`.profile` in its current directory, here the root. The super-user is
not asked for a password, since whoever holds the console holds the
machine. When this shell ends, normally by an end-of-file typed on the
console, the system goes multi-user.

#lines-to("void", lead: true, after: "}")

The routine `runcom` runs `/etc/rc` with the shell and waits for it. The child's
standard input, output, and error are the root directory, opened for
reading (#l("open(\"/\", 0);")), so that the commands of `/etc/rc` have no terminal and
must name `/dev/console` explicitly if they wish to be heard, as
#f("rc") does.

#lines-to("void", lead: true, after: "}")

In `multiple`, `init` spends nearly all its time. It waits for any
child to die. If the child served a terminal, `rmut` records the logout and `dfork` forks a new `getty`. An entry with `pid` -1
is one for which `fork` failed in `dfork` (#l("p->pid = pid;")). It is retried whenever
any child dies.

#lines-to("void", lead: true, after: "}")

The routine `term` ends the service of one table entry.

#lines-to("int", lead: true)

The routine `rline` reads one line of `/etc/ttys` into the structure `line`. A line
is a flag character, `1` if the terminal is to be served and `0` if not,
the character naming the `getty` table, and the terminal's name of up
to seven characters, the rest being discarded. A line whose terminal
cannot be both read and written (#l("if(access(tty, 06) < 0)")), or which is malformed, is treated
as disabled. Only at the end of the file does `rline` return 0.

#lines-to("void", lead: true)

The routine `maktty` builds the terminal's path name in `tty`, and `get` reads one
character, mapping the newline to 0 and end of file to -1.

The variable `b` (#l("char b;")) is a `char`, which C leaves signed or unsigned as the
compiler chooses. Where it is signed, as on the PDP-11, a byte with its
top bit set would be returned negative and end the file early. The mask
(#l("return(b&0377);")) returns every byte as a positive number, whatever the compiler.

#lines-to("void", lead: true, after: "}")

The routine `merge` brings `itab` into line with `/etc/ttys`. It first empties
`/etc/utmp` (#l("close(creat(utmp, 0644));")), the list of users logged in, and re-arms itself as
the handler for `SIGINT`: the kernel resets a caught signal to its
default when it is delivered (`psig`, #f("sig.c")), and a second
interrupt would otherwise kill `init`, and with it the system.

The table is then rearranged in place. The pointer `q` marks the end of the entries
already matched. For each enabled line of the file, the table is
searched from the start for an entry with the same name, an empty entry
matching anything (#l("if(p->line[0] != 0)")). The entry found, if it lies at or beyond `q`,
is exchanged with the one at `q`, the process id moving with its line
and `q`'s old line moving to the slot vacated, and `q` advances. An
entry found below `q` is a duplicate line in the file and is ignored.
When the file is exhausted, the entries from `q` onwards are for
terminals no longer enabled, and `term` kills their processes. Any
entry which has a line but no process, a newly enabled terminal, is
given a `getty`.

#lines-to("void", lead: true, after: "}")

The routine `dfork` forks the process which will serve a terminal. In the child,
the signals which `init` catches are reset to the default (they would
be reset by `exec` in any case, but `chown` and `open` come first). The
terminal is given back to the super-user, with mode 0622, writable by
all so that `write` can reach it, and `login` will give it to the
user. Opening it (#l("open(tty, 2);")) makes the child the leader of the terminal's
process group, as in `single`. In v7 the open of a dial-up
line slept until the modem reported a call, so that this is where an
idle line's process waited. The console drivers (#f("pl011.c"),
#f("usart.c")) have no modem control, and the open returns at
once.

The child runs `getty` with the name `-` and one argument, the table
character from `/etc/ttys`, which is borrowed from the `tty` buffer
(#l("tty[0] = p->comn;"), #l("tty[1] = 0;")).

#lines-to("void", lead: true, after: "}")

The routine `rmut` records that the user of a line has gone. In `/etc/utmp` the
entry for the line, if any, has its name cleared and its time set to
now. To `/usr/adm/wtmp`, the history of logins, a record with the line
name and an empty user name is appended, and `login` writes the matching
record with the user's name. Either file is skipped if it cannot be
opened, so the history is kept only if `/usr/adm/wtmp` has been
created.

The `utmp` structure is two arrays of 8 characters and a time of 8
bytes, 24 bytes in all, where v7's time was a `long` and the structure
20 bytes. The files are therefore not in v7's format.

#lines-to("void", lead: true, after: "}")

The routine `reset` abandons whatever `init` was doing and returns to `main`.
On the ARM, `sendsig` (#f("machdep.c")) has placed the
interrupted registers on the user stack and called `reset` with the link
register pointing at the trampoline. Then `longjmp` (#f("gen/setjmp.s"))
restores the registers saved by `setjmp`, including the stack pointer,
so the trampoline is never reached and `sigreturn` never called. The
saved frame is simply left behind in the part of the stack being
discarded. The kernel keeps nothing on behalf of the handler, so
nothing needs to be undone.

#lines-to(none)
#source("/usr/src/cmd/getty.c")

On every enabled terminal, `init` (#f("cmd/init.c")) runs `getty`.
It arrives with the terminal open as descriptors 0, 1,
and 2, and one argument, the character which `/etc/ttys` (#f("ttys"))
gave for the line. It makes the terminal usable. It chooses a speed and a set of modes,
prints the `login:` prompt, reads the user's name, and executes `login` (#f("cmd/login.c")) with it. On a dial-up line
the speed of the caller's terminal was not known in advance, and
`getty` found it by trial: if what arrived could not be a name, it
switched to the next speed of a cycle and prompted again.

The `#` on line #l("#", before: "* getty -- adapt to terminal speed on dialup, and call login") is a relic of earlier compilers, which ran the
preprocessor only on a file whose first character was `#`.

The declarations at #l("int read(int fd, char *buf, int n), write(int fd, char *buf, int n);")--#l("void exit(int status), puts(char *as), putchr(int cc);") are new. C99 requires a declaration of every
function before it is called, and v7 had none here. This program cannot take
them from `stdio.h` (#f("stdio.h")), as the other commands do, because it
defines a `puts` of its own (#l("puts(char *as)")) which differs from the library's, so
it declares the system calls it uses itself. The header
`sgtty.h` declares `stty`.

The structure `tchars` (#l("struct tchars tchars = { '\\177', '\\034', '\\021', '\\023', '\\004', '\\377' };")) sets the special characters, interrupt (DEL), quit
(FS, control-backslash), start and stop output (DC1 and DC3, control-Q
and control-S), end of file (EOT, control-D), and the additional
delimiter, 0377, meaning none. On the PDP-11 `'\377'` in a `char` was -1,
on the ARM it is 255. In either case it can never equal an input
character, since `ttyinput` (#f("tty.c")) strips the top bit from every
character unless the terminal is in raw mode.

#lines-to("struct\ttab {")

Each entry of `itab` describes one attempt by its own name, the name of
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

#lines-to("/* table '-' -- Console TTY 110 */")

The remaining tables. Most name themselves as successor, so that a
line given one of them never changes speed. The console of the port is
the entry `14console` in `/etc/ttys`: enabled, with table `'4'`, the
"Console Decwriter", whose modes ask for carriage return mapping and
tab expansion on output. The speeds of any table are irrelevant here.
The file `tty.c` records them, but the console drivers never use them: the QEMU
machine's UART has no speed to set, and the MP135 machine's driver
fixes its speed at 115200 baud (#f("usart.c")), just as the KL11
console of the PDP-11 had a speed set by jumpers rather than by the
system.

#lines-to("#define\tNITAB\tsizeof itab/sizeof itab[0]", lead: true)

The array `name` (#l("char\tname[16];")) receives the name which `getname` reads, and `crmod`,
`upper`, and `lower` record what it learns about the terminal on the
way.

The v7 version had here `partab`, a table of parity bits for the ASCII characters,
which `putchr` used to send every character with even parity, since in
raw mode the kernel adds none. The console drivers send eight data bits
without parity (#f("pl011.c")), and a terminal emulator takes the eighth
bit as part of the character, so the parity bit would garble the
prompt: the `g` of `login:`, which has an odd number of one bits, would
arrive as `ç`. The table and its use are removed.

#lines-to("int", after: "int\tlower;")

The routine `main` chooses the first table from its argument, and with none it uses
`'0'`. For a line of type `'3'`, a Bell 212 modem which can answer at
300 or 1200 bits per second, the current speed decides between the two
cycles (#l("case '3':\t\t/* adapt to connect speed (212) */")--#l("break;", after: "tname = '3';")).

#lines-to("for (;;) {")

The loop. The modes and speeds of the chosen table are set with
`TIOCSETP`, the special characters with `TIOCSETC`, and the prompt is
written. If `getname` returns 1, a name has been read: the erase and
kill characters are set to v7's `#` and `@`, the final modes adjusted
by what `getname` learnt about the terminal, and `login` executed with
the name as its argument. The call `stty`, which is `ioctl` with `TIOCSETP`, sets the modes. Otherwise the next table is tried.

The list of arguments to `execl` (#l("execl(\"/bin/login\", \"login\", name, (char *)0);")) ends with `(char *)0`, where v7
wrote a plain 0. The function is variadic, so the compiler does not
convert the argument to the pointer which `execl` takes it to be. An
`int` 0 works only because an `int` and a pointer are the same size, two
bytes on the PDP-11 and four on the ARM, and C leaves the call
undefined. Every such list in the system now ends with the cast.

#lines-to("int", lead: true)

The routine `getname` reads the name one character at a time, with the parity bit
removed (#l("if ((c = cs&0177) == 0)")). A NUL means that the character was not received
properly, which is what a terminal sending at a different speed, or a
break, produces, and `getname` returns 0, and `main` moves to the next
table. End of file or EOT ends `getty`, and `init` starts another.

Since the terminal is in raw mode, `getname` echoes each character
itself (#l("putchr(cs);")), and does its own erasing (`#`) and killing (`@`). It also
learns about the terminal: if the name was ended by a carriage return,
the terminal needs `CRMOD`. If it contains upper case letters, they are
converted to lower case, and unless lower case letters appeared as well
the terminal is assumed to have no lower case, so `LCASE` will be set.
A space becomes an underscore, since `login` reads the name as a single
word.

The test of `np` (#l("if (c=='\\r' || c=='\\n' || np >= &name[15])")) stops the loop when 15 characters have been
stored, leaving room in `name` for the null which `*np = 0` (#l("*np = 0;"))
stores. The v7 version stopped at 16, and the null went one byte beyond the end of
`name`.

#lines-to("void", lead: true)

The program's own `puts` writes a string without the newline which the library's
`puts` adds, and `putchr` writes a single character, now as it is.

#lines-to(none)
#source("/usr/src/cmd/login.c")

The program `login` turns the process which `init` (#f("cmd/init.c")) forked for a
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
set-user-id root (#f("rootfs.proto")).

The entry `nouser` (#l("struct\tpasswd nouser = {\"\", \"nope\", 0, 0, 0, 0, 0, 0, 0};")) stands in for a name which is not in the
password file. Its encrypted password "nope" is not one which `crypt`
can produce, so no password matches it, and an intruder cannot tell a
wrong name from a wrong password. The v7 version initialized only its first two
members. The remaining seven are now given explicitly, as zeros. The
reason is the warning flags: `-Wextra` includes
`-Wmissing-field-initializers`, which, with `-Werror`, rejects a
structure initializer shorter than the structure. The values are those
C supplied in any case.

The v7 version declared the library functions it used (`getpwnam`, `crypt`,
`getpass`, and so on) at the head of the file (deleted). In the port they are
declared, with prototypes, in `pwd.h` and `stdio.h` (#f("stdio.h")), and
the old declarations would conflict with them. Since `showmotd` is called before its definition, it is declared
(#l("void\tshowmotd(void);")). The variable `environ` (#l("extern\tchar **environ;")) is
defined in #f("csu/crt0.s").

#lines-to("int")

The process allows itself a minute (#l("alarm(60);")): if no one has logged in by
then, `SIGALRM`, whose default action is to exit, ends it, and `init`
starts a new `getty`. Interrupt and quit are ignored, so that the
typing of either cannot be used to escape from `login` with the
privileges of the super-user.

The three calls of `nice` (#l("nice(-100);")--#l("nice(0);")) restore the normal scheduling
priority, whatever the process inherited. A call `nice(-100)` lowers `p_nice`
to its minimum of 0, a change only the super-user may make, and
`nice(20)` raises it to `NZERO` (#f("param.h")), the default. An argument of 0
changes nothing.

The erase and kill characters are set to `#` and `@` (#l("gtty(0, &ttyb);")--#l("stty(0, &ttyb);")), and any
descriptors beyond the standard three are closed. The routine `ttyname` finds the
terminal's name by searching `/dev` for the device which descriptor 0
is open on.

#lines-to("loop:")

The name is read here unless it came as an argument. It is the place to
which a failed attempt returns. The name is cut to the 8 characters of
`ut_name` (#f("cmd/init.c")), and a space becomes an underscore, as in
`getty`.

#lines-to("setpwent();")

The password file is searched with `getpwnam`, which reads it with the
routines of #f("stdio/getpwent.c"). If the user has a password, one is
read without echo by `getpass` (#f("stdio/getpass.c")) and encrypted with
`crypt` (#f("gen/crypt.c")), using as salt the first two characters of the
stored encryption. The result is compared with the stored encryption.
The password itself is never stored. Finally the process moves to the
user's home directory.

#lines-to("time(&utmp.ut_time);")

The login is recorded. The routine `ttyslot` returns the number of the terminal's
line in `/etc/ttys`, counting from 1, and that numbers the user's
record in `/etc/utmp`, and `init`'s `rmut` will clear it at logout. The
same record is appended to `/usr/adm/wtmp`. The line name stored is
the terminal's name with `/dev/` removed (#l("SCPYN(utmp.ut_line, index(ttyn+1, '/')+1);")).

#lines-to("chown(ttyn, pwd->pw_uid, pwd->pw_gid);")

The terminal is given to the user (#l("chown(ttyn, pwd->pw_uid, pwd->pw_gid);")), and then the group and the user
id are changed, in that order, since after `setuid` the process would no
longer be allowed `setgid`. From here on the process is the user's.

The environment is replaced by `envinit` (#l("environ = envinit;")), which holds `HOME`, completed from the password entry (#l("strncat(homedir, pwd->pw_dir, sizeof(homedir)-6);")), and `PATH`. The string `minusnam` becomes `-` followed by
the last component of the shell's name, so that `/bin/sh` is called
`-sh` and reads the user's `.profile` (#f("sh/main.c")). The file mode
creation mask is set to 02, so that new files are not writable by
users outside the file's group.

The message of the day is shown, then a note if the user's mailbox is
not empty, and the shell is executed with `execlp` (#f("gen/execvp.c")),
interrupt and quit restored to the default first. If it cannot be
executed, the process exits, and `init` starts a new `getty`. As in
`getty` (#f("cmd/getty.c")), the argument list of `execlp` (#l("execlp(pwd->pw_shell, minusnam, (char *)0);")) now
ends with `(char *)0`, not an `int` 0.

#lines-to("int\tstopmotd;", lead: true)

The routine `showmotd` copies `/etc/motd` to the terminal, and an interrupt stops
the copy. The interrupt handler `catch` is now `static`, since nothing
outside this file uses it, and the port compiles with
`-Wmissing-prototypes`, which asks for a prototype in a header for every
function that is not. It takes the signal number, as every handler now
does (#f("sys/signal.s")), and ignores it.

#lines-to(none)
#source("/usr/src/libc/stdio/getpass.c")

The routine `getpass` prints a prompt and reads a password of up to eight
characters with echo turned off. Its chief user is `login` (#f("cmd/login.c")),
and `su`, `passwd`, `newgrp`, and `crypt` are others.

It reads from `/dev/tty`, the process's controlling terminal, even if
the standard input has been redirected. The special file's driver, #f("sys.c"), passes the request to the terminal recorded in
`u.u_ttyp` when the process group was formed (`ttyopen`, #f("tty.c")). If
the process has no terminal the open fails and the standard input is
used instead. The stream is made unbuffered (#l("setbuf(fi, (char *)NULL);")) so that nothing beyond
the password's newline is consumed. Interrupts are ignored while echo
is off, since a program killed at that moment would leave the terminal
silent.

The echo is turned off by clearing `ECHO` in the terminal's modes with
`gtty` and `stty`, and the old modes are put back afterwards. The prompt
and the newline which the user's return did not echo are written on
the standard error. Only eight characters are kept, since `crypt`
(#f("gen/crypt.c")) uses no more. The rest of the line is read and
discarded. The password is returned in a static buffer, which the next
call overwrites.

The v7 version declared `signal` locally (deleted) as a function returning a
pointer to a function returning `int`, and `sig` to match. The header `signal.h`
now declares `signal` with a prototype, and handlers are functions of
one `int` returning nothing (#f("sys/signal.s")), so `sig` (#l("void (*sig)(int sig);")) has that
type and the local declaration of `signal` would conflict with the
header's.

#lines-to(none)
#source("/usr/src/libc/stdio/getpwent.c")

These routines read the password file, `/etc/passwd` (#f("passwd")), one
entry at a time. The routine `getpwent` returns the next entry as a `struct passwd`
(declared in `pwd.h`), `setpwent` rewinds the file, opening it if
necessary, and `endpwent` closes it. The routines `getpwnam` and `getpwuid`, in files of
their own, call `setpwent`, then `getpwent` until they find the name
or user id wanted, and then `endpwent`. The program `login` (#f("cmd/login.c")) uses `getpwnam`.

The file is v7's with prototype definitions, and `setpwent` and `endpwent`,
which return no value, are now `void` where v7 left them implicitly
`int`.

#lines-to("static char *", lead: true)

An entry is a line of seven fields separated by colons. They are the name, the encrypted password, the user and group ids, a comment field (by
convention the user's full name, `pw_gecos`), the home directory, and
the shell. A field may be empty. An empty password means that none is
asked for, and an empty shell means `/bin/sh`.

The line is read into the static buffer `line`, and the fields are
not copied: `pwskip` replaces each colon by a NUL and returns the
address of the next field, so that the members of the structure point
into `line`. The final field is cut at the newline (#l("while(*p && *p != '\\n') p++;"), #l("*p = '\\0';")). The
numbers are converted with `atoi`. The fields `pw_quota` and `pw_comment` are not
in the file at all and are set to 0 and the empty string.

Every call reuses the same `line` and the same `passwd`, so the next call destroys the result of one. A caller which needs
two entries at once must copy the first. And, since `fgets` (#l("p = fgets(line, BUFSIZ, pwf);")) reads at
most `BUFSIZ` − 1 characters, a longer line would be split and its tail
read as an entry of its own. A password file has no such lines.

#lines-to(none)

== Reading Commands <ch-reading>

#source("/usr/src/libc/stdio/getpwuid.c")

The routine `getpwuid` finds a user's entry in the password file by id, reading
it through `getpwent` from the start and closing it again, so that each
call is independent, and `getpwnam`, which finds it by name, is the same
loop with `strcmp`. The entry returned is
`getpwent`'s static one, overwritten by the next call.

#lines-to(none)
#source("/usr/src/libc/stdio/getgrent.c")

The routine `getgrent` reads `/etc/group` an entry at a time, as `getpwent` reads
the password file: the line is cut at its colons by `grskip`, which
replaces each separator with a null, and the members, separated by
commas, become a null-terminated array of pointers into the line.
The routine `setgrent` rewinds the file and `endgrent` closes it.

#lines-to(none)
#source("/usr/src/libc/stdio/getgrgid.c")

The routines `getgrgid` and `getgrnam` find a group by id or by name, as
`getpwuid` finds a user.

#lines-to(none)
#source("/usr/src/libc/stdio/getgrnam.c")

Again with `strcmp`, `getgrnam` searches by name.

#lines-to(none)
#source("/usr/src/libc/stdio/getpw.c")

The older interface, `getpw`, copies into the caller's buffer the
whole line of the password file for a user id, and returns 0 if it
found one. It now stores at most `BUFSIZ` bytes of a line (#l("if(bp < buf+BUFSIZ-1)")--#l("*bp++ = c;")), and
moves on to the next line when one has too few fields (#l("if(c == '\\0')", after: "while(--n)")--#l("goto next;", after: "while((c = *bp++) != ':') {")): the
line has had its newline replaced by a null (#l("*bp++ = '\\0';")), but v7 then tested
for a newline, and on a short line read on past the null into the rest
of the buffer. The id now stops growing before it overflows (#l("if(n < 100000000)")--#l("n = n*10+c-'0';")).

#lines-to(none)
#source("/usr/src/libc/gen/getlogin.c")

The routine `getlogin` returns the name under which the user logged in on the
terminal of the process, from the entry of `/etc/utmp` that `ttyslot`
gives for it, or 0 if there is none. The name field has eight bytes and
no null when full, and v7 ended it by writing a blank into its ninth byte,
which is the first of the next field, then searched for that blank. It
now copies the name into an array of its own with room for the ninth
byte (#l("static\tchar\tname[9];"), #l("strncpy(name, ubuf.ut_name, 8);")--#l("*--cp = '\\0';")).

#lines-to(none)
#source("/usr/src/cmd/sh/defs.h")

The shell is an ordinary user program, `/bin/sh`, but it is the one
through which nearly everything else is run, and it occupies this and
the next two sections. Its work divides into three parts. It reads
characters and assembles them into words (#f("sh/io.c"), #f("sh/word.c")). It parses the words into a tree of commands, built by `cmd`
(#f("sh/cmd.c")). Then it walks the tree, forking, redirecting, and
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

Every source file of the shell includes #f("sh/defs.h"), which
includes most of the other headers in turn. The lone `#` on the first
line of each file is a relic: early C compilers ran the preprocessor
only on a file whose first character was `#`. To C99 it is an empty
directive.

The first definitions are the codes with which the shell exits after an
error (`SIGFLG` is or-ed into the status of a command killed by a
signal), and the node types of the command tree. A node's type is in
its low four bits (`COMMSK`). The bits above qualify a fork node. They say to print the process id
(`FPRS`), to ignore interrupts (`FINT`), not to wait (`FAMP`), and to
connect or close a pipe (`FPIN`, `FPOU`, `FPCL`).

#lines-to("/* execute table */")

The codes of the built-in commands, which `syslook` (#f("sh/name.c"))
finds in the table `commands` (#f("sh/msg.c")) and `execute` switches
on.

`INIO` and `OTIO` (#l("#define INIO 10"), #l("#define OTIO 11")) are the descriptors to which the shell moves
its own input and output (#f("sh/main.c")), so that they are out of the
way of the descriptors 0 to 9 which a user may redirect (`USERIO`). An
I/O node's `iofile` holds the descriptor in its low four bits
(`IOUFD`) and the kind of redirection above them.

#lines-to("/* result type declarations */", lead: true)

In v7 this block declared, without arguments, a selection of the
functions (#l("ADDRESS\t\talloc(POS nbytes);")--#l("STRING\t\t*setenv(void);")), chiefly those which returned something other than
`int`. Every other function,
and every system call, was declared implicitly by its first call. C99
has no implicit declarations. The port gives each of v7's declarations
a prototype and adds the rest (#l("INT\t\tany(CHAR c, STRING s), builtin(void),")--#l("STRING\t\tsbrk(int incr);")): every function the shell
shares between its files, and the system calls it makes. The system
calls are declared here, because the shell cannot include the port's
`stdio.h`, which carries their prototypes (#f("stdio.h")): that file
defines `FILE`, `BUFSIZ`, and `EOF`, which the shell defines for
itself, differently (#f("sh/mode.h"), #f("sh/mac.h")). The calls `gtty`, `stat`,
and `signal` are not in the list. Their declarations come from
`sgtty.h`, `sys/stat.h`, and `signal.h`.

Four v7 declarations are gone. The first, `expr`, of type `REAL`, was declared and
never defined. The other three, `execs`, `copyto`, and `staknam`, are `LOCAL` (that is,
`static`) in their own files, and C99 does not allow a `static`
definition to follow a declaration with external linkage. They are
declared, or simply defined before their first use, in their own files.

The name `alloc` (#l("#define alloc malloc")) stands for `malloc`. The shell's own allocator
(#f("sh/blok.c")) is therefore the program's `malloc`, and the library's
(#f("gen/malloc.c")) is never loaded. The routine `free` takes `void *`, where v7's
took a `BLKPTR`: its callers pass a `STRING`, a `DOLPTR`, or a
`BLKPTR`, and only a `void *` parameter accepts them all without a
cast.

#lines-to("#define attrib(n,f)\t(n->namflg |= f)", lead: true)

The macro `round(a,b)` rounds the address `a` up to a multiple of `b`, a power of
two. It converts the pointer to `int` and returns an `int`, which works
because on the ARM, as on the PDP-11, the two are the same size. Where
the result is wanted as a pointer, the callers in #f("sh/stak.c") and
#f("sh/blok.c") now cast it back, as C99 requires. The header defines `assert`
away.

From here on most of the lines declare variables. In v7 they were
written without `extern`: each was a tentative definition in every file
that included #f("sh/defs.h"), and the loader merged the copies into a
single "common" symbol. C99 permits one definition only, and the port
is not compiled with `-fcommon`, which would restore the merging, so
the header now declares them `extern`. Those which v7 defined nowhere
else are now defined in #f("sh/main.c").

#lines-to("/* string constants */", lead: true)

The `MSG` strings are defined in #f("sh/msg.c"). The `NAMNOD`s, the
nodes for the shell's built-in variables, in #f("sh/name.c").
The variable `standin` (#l("extern FILE\t\tstandin;")) is the current input file, of which `input` and `eof`
name two fields.

The flags record the options set with `set` or on the command line,
together with some internal state. The flag `ttyflg` (#l("#define\t\tttyflg\t040")) marks an interactive shell, `forked` a shell process which is a child of the shell proper,
`waiting` a shell idle at its prompt, and `prompt` that a prompt is to
be printed.

#lines-to("/* error exits from various parts of shell */", lead: true)

The jump buffers `subshell` and `errshell` are the targets of the shell's two non-local
jumps, both set in #f("sh/main.c"). The variable `brkincr` is the amount by which the
data segment is extended (#f("sh/stak.c")).

The include of `signal.h` (#l("#include\t<signal.h>")) is new. It supplies the prototype of `signal`, and
`SIG_IGN`, with which #f("sh/fault.c") now tests whether a signal was
ignored, where v7 compared the result of `signal` with 1. The handler `fault` is
declared with the signal number it receives, so that it has the type
which `signal` expects of a handler.

#lines-to("/* name tree and words */", lead: true)

In v7, `execbrk` (#l("extern INT\t\texecbrk;")) was a `BOOL`, that is a `char`. The command `continue` sets it to
`-loopcnt`, and the loops of #f("sh/xec.c") test
`execbrk<0`. A PDP-11 `char` was signed and held the negative value. An
ARM `char` is unsigned, so the test would never succeed. It is now an
`INT`.

As in v7, `notfound` is declared twice (#l("extern MSG\tnotfound;", after: "extern MSG\tnospace;"), #l("extern MSG\tnotfound;", after: "extern MSG\tbadexec;")). The symbol `end` (#l("extern address\tend[];")) is the
address which the loader assigns to the end of the program's
uninitialised data. The shell's heap begins there.

#lines-to(none)
#source("/usr/src/cmd/sh/mode.h")

The header #f("sh/mode.h") names the shell's types and lays out its data
structures, chief among them the nodes of the command tree.

`BYTESPERWORD` (#l("#define BYTESPERWORD\t(sizeof(char *))")) is the unit to which the shell aligns everything it
allocates. The v7 code already wrote it as `sizeof(char *)`, so it is 4 on the
ARM without change, where it was 2 on the PDP-11. The stack, the heap,
and the space `word` reserves for a link (#f("sh/word.c")) all follow
it.

 `BOOL` is a `char`, and the shell's `TRUE` is
`-1` (#f("sh/mac.h")). Since an ARM `char` is unsigned, a `BOOL` set to
`TRUE` holds 255. Nothing compares a `BOOL` with `TRUE`, so the
difference is never seen. The one variable whose sign mattered,
`execbrk`, has become an `INT` (#f("sh/defs.h")).

`VOID` was `int` in v7, for a compiler without `void`. It is now `void`,
so that a function declared `VOID` returns nothing and the compiler can
say so. `REAL` survives, though nothing uses it.

#lines-to("STRUCT stat\tSTATBUF;\t/* defined in /usr/sys/stat.h */")

Each structure gets a typedef for itself or for a pointer to it.
The v7 header also typedef'd `SYSTAB` here (deleted), as an array of
`struct sysnod`, before that structure was defined, and C99 does not allow an array
of an incomplete type, and the line has moved below the definition
(#l("STRUCT sysnod\tSYSTAB[];")).

#lines-to("/* the following nonsense is required", lead: true)

The "cheats" convert a pointer to an `int`, so that the shell can set
and clear a flag in its low bit (#f("sh/blok.c"), #f("sh/service.c")).
`Rcheat` is a cast, and depends only on an `int` being as wide as a
pointer, which holds on the ARM. `Lcheat` gave an lvalue, through the
member `_cheat` of the union v7 declared at this point (deleted): v7's
compiler kept all member names in one table and let `.` apply any of
them to any lvalue. That declaration declares nothing, and C99 rejects
it. Its two uses violated
the aliasing rules of C99, writing a pointer through an `int` lvalue,
and have been rewritten as plain assignments with `Rcheat`. The macro
stays, unused.

The union `address` gathers the pointer types, so that `end`
(#f("sh/defs.h")) can be declared as an array of it.

#lines-to("/* heap storage */", lead: true)

The v7 header defined `struct void` here (deleted), a structure with one member,
apparently so that `void` could appear in a declaration where the
compiler had no such type. In C99 `void` is a keyword, and the line is
an error.

A heap block (`struct blk`) is a single word: a pointer to the next
block, the user's data following it (#f("sh/blok.c")).

Each `struct fileblk` is an input file, with its descriptor, line number,
end-of-file flag, the size of a read, pointers to the next character
and to the end of the characters buffered, a list of further strings to be read in turn (`feval`), and
a link to the input it interrupted (`fstak`). The shell's `BUFSIZ` is 64,
not the library's 512. A `struct filehdr` is the same with a buffer of
one byte, used when the input is a string in memory and needs no
buffer.

A `sysnod` pairs a name with a code. The tables `reserved` and `commands`
(#f("sh/msg.c")) consist of these, ended by a null name.

#lines-to("/* this node is a proforma for those that follow */")

The nodes of the tree. Every node but a `regnod` begins with its `INT`
type, so that a `TREPTR` can stand for any of them until the type has
been examined, and
#f("sh/xec.c") then converts the pointer to the specific kind. The fork
and command nodes, like `struct trenod`, follow the type with an I/O
list, which is how `item` can attach redirections to a fork node
through `treio` (#f("sh/cmd.c")). A `comnod` is a simple command, with its
arguments and the assignments which precede it; `ifnod`, `whnod`,
`fornod`, and `swnod` are the compound commands; a `regnod` is one arm
of a `case`; a `lstnod` joins two commands with `;`, `&&`, `||`, or a
pipe; a `parnod` holds a parenthesised command; a `forknod` asks
`execute` to fork. The structures `argnod` and `dolnod` are headers: the text of the
argument or parameter list follows in the same block.

The `...TYPE` macros give the size of each node for `getstak`.

#lines-to(none)
#source("/usr/src/cmd/sh/mac.h")

Bourne wrote the shell, and later the debugger `adb`, in a C disguised
as Algol 68, and #f("sh/mac.h") is the disguise. Each keyword expands to the punctuation of the C statement it replaces.
Thus `IF c THEN s FI` becomes `if( c ){ s ;}`, `WHILE c DO s OD` becomes `while( c ){ s ;}`,
and `REP s PER c DONE` is a `do`-`while` loop. `LOOP ... POOL` is a loop
without a test, left by `break` or `return`. The brackets of each
construct are supplied by its keywords, so a body of several statements
needs no braces, and an `ELIF` chain needs no nesting.
`SWITCH x IN ... ENDSW` frames a `switch`. The cases inside are written in plain C.

`FI` and `OD` supply a semicolon. A statement before them may
omit its own, and the shell's sources often do (`IF x THEN y=0 FI`).

`LOCAL` is `static`, and `PROC` (for `extern`) is no longer used: the
port declares the shell's local functions `LOCAL` before their
definitions (#f("sh/cmd.c")), where v7 declared them `PROC`.



#lines-to("#define SKIP\t;", lead: true)

`TRUE` is `-1`, all bits set, and `EOF` is 0: the shell's own end of
file is a null character, unrelated to the `EOF` of `stdio.h`.
`QUOTE` (#l("#define QUOTE\t0200")) is the bit the shell sets in a character to mark it quoted
(#f("sh/word.c")). The characters it reads are ASCII, and this bit is
otherwise unused. `STRIP` removes it again.

#lines-to(none)
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



#lines-to(none)
#source("/usr/src/cmd/sh/ctype.h")

The shell classifies characters by two tables of its own,
`_ctype1` and `_ctype2` (#f("sh/ctype.c")), rather than by the library's
`ctype.h`. Each entry is a set of bits. The first table serves the lexical analysis of #f("sh/word.c"). It marks blanks (`T_SPC`), the characters
which end a word (`T_MET`, `T_DIP`, `T_EOR`, `T_EOF`), quotes, and the
characters which a backslash may escape. The second serves the
parameters of #f("sh/macro.c"): digits, the letters and underscore that
make an identifier (`T_IDC`), the special parameters such as `$#` and
`$?` (`T_SHN`), and the operators of `${...}`, such as `-` and `=`.
The `_XXX` names give the class of each individual character, for use
in the tables.

#lines-to("extern unsigned char\t_ctype1[];")

Each test checks first that the character does not carry the quote bit
(#f("sh/mac.h")), since a quoted character never has a special meaning.
Only then is the table consulted. As the comment warns, the macros
evaluate their argument twice.

The v7 code subscripted the tables with `c` itself. The port masks it with
`0377`. The argument is often a `char`, and GCC warns of a subscript of
type `char` (`-Wchar-subscripts`), because a signed `char` may be
negative. The port treats every warning as an error. The mask makes the
subscript an `int`. It does not change a character's value, and the
quote test has already excluded the values above 0177, so the subscript
stays within the 128 entries of the table. The declarations of the tables have become `extern`
(#l("extern unsigned char\t_ctype1[];"), #l("extern unsigned char\t_ctype2[];")). In v7 they were tentative definitions in every file. They are
also `unsigned char` now, as in #f("sh/ctype.c").

#lines-to(none)
#source("/usr/src/cmd/sh/ctype.c")

The two tables of character classes, laid out one row for each eight
ASCII codes. Two things have changed (#l("unsigned char\t_ctype1[] = {"), #l("unsigned char\t_ctype2[] = {")). C99 requires the `=` before each
initialiser, which v7's compiler did not yet, and the type is now
`unsigned char`. Some classes, such as `_LQU`, include the
bit `0200` (#f("sh/ctype.h")), which a signed `char` cannot hold
without a change of value. As `unsigned char` the tables are the same
whichever kind of `char` the compiler has.

In the first table, note that the null character is `_EOF`, the
shell's end of file, and that only space, tab, and newline separate
words. The characters `&;<>|` (`T_DIP`) and `()^` (`T_MET`) end a word
too.

#lines-to("unsigned char\t_ctype2[] = {", lead: true)

In the second, the capitals, small letters, and underscore make
identifiers, and `@` and `*` are both `T_AST`, the parameters which stand
for all the positional arguments.

#lines-to(none)
#source("/usr/src/cmd/sh/brkincr.h")

The initial and largest amounts, in bytes, by which `locstak`
(#f("sh/stak.c")) extends the shell's data segment.

#lines-to(none)
#source("/usr/src/cmd/sh/stak.h")

The shell manages its memory itself, in two regions which share the
data segment above `end`. At the bottom is a heap (#f("sh/blok.c")),
from which `alloc` hands out blocks of any size which live until they
are freed: the variables' nodes and values, and the lists of
positional parameters. Immediately above the heap lies the
"stack" (#f("sh/stak.c")), which holds the words as they are read, the parse tree, and the
expanded arguments, everything that lives no longer than one command. Allocation from the stack costs an addition, and
nothing on it is ever freed singly. At the top of its command loop the
shell simply resets the stack to its base (`tdystak`, #f("sh/main.c")).

Of the four pointers which describe the stack, `stakbas` is its base and `brkend`
the current end of the data segment. Items already allocated lie
between `stakbas` and `stakbot`. The item being built runs from
`stakbot` to `staktop`. A string of unknown length, such as a word, is built with `locstak`, which
makes sure there is room, then `pushstak` for each character, then `endstak` or `fixstak`, which ends the string and
makes it a permanent item.

The heap grows upward into the stack. When it does, `addblok` copies
the item under construction to a new place above the heap
(#f("sh/blok.c")), so that a pointer into it becomes stale. Code that
may call `alloc` in the middle of building an item, such as a variable
lookup during substitution, therefore keeps an offset from `stakbot`
(`relstak`) and converts it back afterwards (`absstak`, `setstak`), as
the first comment explains.

The declarations of these pointers, and of `stakbsy` (#f("sh/stak.c")),
are `extern` (#l("extern BLKPTR\t\tstakbsy;")--#l("extern STKPTR\t\tstaktop;")). They are defined in #f("sh/stak.c"). The functions have prototypes.

#lines-to(none)
#source("/usr/src/cmd/sh/stak.c")

The procedures of the stack described in #f("sh/stak.h").

The definitions of `stakbsy`, `stakbas`, `brkend`, and `staktop`
(#l("BLKPTR\t\tstakbsy;"), #l("STKPTR\t\tstakbas, brkend, staktop;")) are new. In v7 the tentative definitions in
#f("sh/stak.h") served (#f("sh/defs.h")). The pointer `stakbot` starts at `nullstr`, an empty string, so
that it is a valid pointer before `main` has set up storage.

#lines-to("/* ========\tstorage allocation\t======== */", lead: true)

The routine `getstak` allocates an item of known size, such as a tree node. The
size is rounded up to `BYTESPERWORD`, so that the next item, and every
node, begins on a four byte boundary. Nothing checks that the
item fits below `brkend`. That is the business of `locstak`, below,
and of a signal.

#lines-to("STKPTR\tlocstak(void)", lead: true)

The routine `locstak` begins an item of unknown size. If fewer than `BRKINCR`
bytes remain between `stakbot` and the end of the data segment, it
extends the segment by `brkincr` with `setbrk` (#f("sh/setbrk.c")), and
increases `brkincr` by 256, up to `BRKMAX`, so that a shell which keeps
needing room asks for it in larger pieces.

One call is not a guarantee: a long word may outgrow the space while it
is being pushed, one character at a time, and nothing tests for that.
On the PDP-11 the store beyond the end of the segment caused a memory
fault, `SIGSEGV`, which the shell catches, and `fault` (#f("sh/fault.c"))
extends the segment by `brkincr` and returns. Before sending the
signal, v7's `trap` had called `backup`, which undid the side effects of
the failed instruction on the registers, so that the instruction was
executed again when the handler returned, and this time succeeded. The
shell thus grew on demand, at the cost of depending on the machine's
ability to restart an instruction after a fault.

The ARM restarts an instruction after a data abort without help: the
registers are left as they were before it, and the saved program
counter addresses it (#f("low.s")). The kernel maps a process's data
in whole pages, up to the page which holds its break (#f("ureg.c")), so
a store past the end of that page faults here as a store past the
break did on the PDP-11, and the shell grows in the same way.

#lines-to("STKPTR\tsavstak(void)", lead: true)

The routine `savstak` returns the current position, for a later `tdystak`.
The routine `endstak` ends the item at `argp` with a null, makes it permanent, and
starts the next item at the following word boundary. The cast of
`round`'s result to `STKPTR` (#l("oldstak=stakbot;", after: "*argp++=0;")) is new: `round` yields an `int`, and
C99 does not convert an integer to a pointer without one.

#lines-to("VOID\ttdystak(REG STKPTR x)", lead: true)

The routine `tdystak` returns the stack to the position `x`. Blocks on the chain
`stakbsy` are parts of the stack that `addblok` turned into heap blocks
(#f("sh/blok.c")), and those that lie above `x` are freed. The position `x` may lie
below the present base, if the stack has moved since it was saved, and
`max` then keeps the new base. The routine `rmtemp` (#f("sh/error.c")) removes the
temporary files made since `x`, which it recognises because their I/O
nodes were also allocated on the stack, above `x`. The cast of `x` to
`IOPTR` (#l("rmtemp((IOPTR)x);")) is new, to match the prototype.

#lines-to("VOID", lead: true, after: "}")

Called from the command loop, `stakchk` gives back data space when
more than two increments of it lie above the stack's base, and `sbreak`
(#f("sys1.c")) returns to core, and unmaps, any whole page so freed.

The routine `cpystak` copies a string to a new item.

#lines-to(none)
#source("/usr/src/cmd/sh/blok.c")

The heap. The arena is a circular list of blocks, each beginning with
one word (`struct blk`, #f("sh/mode.h")) which points to the next block.
The size of a block is the distance to its successor. Because every
block begins on a word boundary, the low bit of the pointer is free,
and `BUSY` in it marks the block as in use. The last block, `bloktop`,
is a header only, which points back to the first, at `end`, with
`BUSY` set so that it is never merged.

The macro `busy` reads the bit through `Rcheat`, a cast of the pointer to `int`
(#f("sh/mode.h")). On the PDP-11 a pointer was a 16 bit word and on the
ARM it is a 32 bit one, but on both machines it fits an `int`, which is
all the cast needs.

#lines-to("ADDRESS\talloc(POS nbytes)", lead: true)

The routine `alloc` (which is the program's `malloc`, #f("sh/defs.h")) looks for a
free block of at least `rbytes`, the request plus the header, rounded
to a word. The search starts at `blokp`, where the last one ended, and
goes round the circle: first fit, as the comment says. Adjacent free
blocks are merged as they are met (#l("THEN\tWHILE !busy(q = p->word) DO p->word = q->word OD")). A block larger than needed is
split, and the remainder, from `blokp` up, stays free. The counter `c`
lets the search pass the wrap from `bloktop` back to `end` only once.
If nothing is found, `addblok` enlarges the arena and the search starts
again.

The cast to `POS` in the comparison (#l("IF (POS)(ADR(q)-ADR(p)) >= rbytes")) is new. The difference of two
pointers is signed and `rbytes` unsigned. The comparison was unsigned
in v7 too, and the cast only says so (#f("fio.c")).

#lines-to("VOID\taddblok(POS reqd)", lead: true)

The routine `addblok` adds at least `reqd` bytes to the top of the arena, which
means moving the stack, since the stack lies directly above
`bloktop`. If there are items on the stack, the stack, up to the end of
the item under construction, becomes a busy block of the heap: the old
`bloktop` now points past it, and its first word, the one just below
`stakbas`, links it into the chain `stakbsy`, so that `tdystak`
(#f("sh/stak.c")) can free it later. The arena then grows by `reqd`
plus `brkincr`, with the bits of `brkincr-1` cleared: more than `reqd`,
and a multiple of `brkincr` when that is a power of two. Since
`locstak` raises `brkincr` in steps of 256, it often is not, but the
growth is always a multiple of 256. The new `bloktop` points back to
`end`, busy (#l("bloktop->word=BLK(ADR(end)+1);")). Finally the item under construction is copied to the
new base of the stack, two words above `bloktop`, one for the
`bloktop` header and one to serve as the `stakbsy` link when the stack
next turns into a block.

The items already on the stack thus keep their addresses. Only the
current item moves, which is why #f("sh/stak.h") warns about pointers
into it. The routine `addblok` does not itself extend the data segment.
The stores into the new space fault, and `fault`
extends it (#f("sh/stak.c")). The cast of `round`'s result (#l("rndstak=(STKPTR)round(staktop,BYTESPERWORD);")) is new, as in
#f("sh/stak.c").

#lines-to("VOID\tfree(void *ap)", lead: true)

The routine `free` clears the busy bit of the block's header, the word before
`ap`. Pointers at or above `bloktop` are ignored. Such a value lies on
the stack, or among the arguments and environment strings which `exec`
placed at the top of memory, and the callers (`freeargs`, for one, in
#f("sh/args.c")) free values without asking where they came from.

The argument is `void *`, where v7 had `BLKPTR`, so that the callers
may pass pointers of their several types (#f("sh/defs.h")). The v7 version cleared the bit in place
through `Lcheat`, writing the pointer through an `int` lvalue. That
breaks the aliasing rules of C99, under which the optimiser may assume
that a store to an `int` does not change a pointer. The port reads the
pointer, clears the bit, and stores it back (#l("THEN\tp--; p->word=BLK(Rcheat(p->word)&~BUSY);")).

#lines-to("#ifdef DEBUG", lead: true)

The routine `chkbptr` checks the arena when the shell is compiled with `DEBUG`,
which it never is. It is left as v7 wrote it, in the old style, and
would not compile under C99.

#lines-to(none)
#source("/usr/src/cmd/sh/setbrk.c")

The routine `setbrk` moves the end of the data segment by `incr` bytes, which may
be negative, and records the new end in `brkend`. It returns the old
end, or `-1` cast to a pointer if the kernel refused. The routine `fault` (#f("sh/fault.c")) tests
for that, now by comparing with `(BYTPTR)-1`, where v7, whose `setbrk` returned an `int`, compared with `-1`. The v7 code set
`brkend` even after a refusal, to `incr` bytes beyond that `-1`, an
address of nothing reached by arithmetic which C99 leaves undefined.
The port keeps the old end then (#l("IF a!=(BYTPTR)-1 THEN brkend=a+incr FI")). The routine `sbrk` is the library's (`sbrk.s`), which calls the `break`
system call, `sbreak` in #f("sys1.c").

The return type `BYTPTR` (#l("BYTPTR")) is new. The v7 code left `setbrk` to default to
`int`, though it returns a pointer, and declared it nowhere. On the
PDP-11 a pointer and an `int` were the same size, and returning one as
the other did no harm. The port declares it in #f("sh/defs.h"), with
the type of the value it actually returns.

#lines-to(none)
#source("/usr/src/cmd/sh/main.c")

The routine `main` sets up the shell's storage, signals, and variables, decides
where commands are to come from, and calls `exfile`, which reads and
executes them until the end of the input.

`<sys/param.h>` (#l("#include\t<sys/param.h>")) replaces v7's `<sys/types.h>`: it carries the
same type definitions, which may not be given twice, and also
`USRSIZE`, which `execargs.h` needs.

The definitions at #l("INT\t\tioset, dolc, wdval, wdnum, wdset, serial, peekc, flags;")--#l("BOOL\t\treserv, trapnote;") are new. They are the variables which
#f("sh/defs.h") declares; in v7 the header itself defined them, in
every file, and the loader merged the copies. The header `execargs.h` (#l("#include\t<execargs.h>")) defines
the pointer `execargs`.

The port declares `exfile` `LOCAL`, where v7 declared it `PROC`, that is
`extern`, and then defined it `LOCAL`. C99 forbids a `static`
definition after a declaration with external linkage.

#lines-to("int")

The storage is set up first: `stdsigs` (#f("sh/fault.c")) arranges,
among other things, to catch `SIGSEGV`, by which the shell grows its
data segment (#f("sh/stak.c")); `setbrk` gives the shell its first
`BRKINCR` bytes; and `addblok` makes the first heap block and places
the stack above it (#f("sh/blok.c")). Only then can anything be
allocated. The routine `getenv` (#f("sh/name.c")) turns the environment into shell
variables.

The test for a restricted shell, by the letter `r` in the shell's name,
was commented out in v7 already, so `rflag` stays `ttyflg`, and a
restricted shell can only be had with the option `-r`.

The routine `options` (#f("sh/args.c")) processes the flags and returns the number
of arguments left. If there is no file name among them, or the flag
`-s` was given, commands are read from the standard input (`stdflg`), and
`dolv` and `dolc` are left describing the positional parameters, with
`dolv[0]` the name of the shell or of the command file, `$0`.

#lines-to("/* return here for shell file execution */")

The shell returns to `subshell` when it is asked to
run a command file without execute format. The routine `execs` (#f("sh/service.c"))
finds that `exec` fails with `ENOEXEC`, opens the file as the shell's
input, sets the new arguments, and jumps here, in the child process
which was to have executed it. The shell then starts afresh, from the
setting of `$#`, `$0`, `$$`, and the temporary file names, but skips
the profile.

`$0`, `cmdadr`, is a copy of `dolv[0]` (#l("cmdadr=make(dolv[0]);")), which also names the
shell in its error messages. The v7 version kept the pointer itself. For a command
file, `dolv` lies in a block which `setargs` (#f("sh/args.c")) made, and
which the next `set` with arguments frees, strings and all, and `cmdadr`
then pointed into freed storage, and a script which gave `set` the
names in `/bin`, by command substitution, reported its next error under
an empty or garbled name.
The copy is never freed.

The profile is read only by a login shell, which `login` (#f("cmd/login.c")) starts with a `-` before its
name. While it is read, `exfile` is given `ttyflg` as `prof`. See
below. A command string given with `-c` is set up as the input by
`estabf` (#f("sh/io.c")). Otherwise the input is the standard input or
the named file. The shell then makes `comdiv` non-null, so that a later
`set -c` is not taken as a command string (`options`, #f("sh/args.c")).
The v7 code wrote `comdiv--`, a decrement of the null pointer, which C99 leaves
undefined. The port points it at `minus`, the string `-`, instead (#l("comdiv=minus;")).

On re-entry for a command file (#l("ELSE\t*execargs=(char *)dolv;\t/* for `ps' cmd */")), the shell stores `dolv` through
`execargs`, at the top of its user stack. That word is where `ps`
looks for the arguments of a process, and the store makes the command
file appear there under its own name. In v7 `execargs` was
`(char **)-2`, the last word of the PDP-11's 64 KB address space. In
the port it is `USRSIZE-4`, the last word below the end of the 3 GB
user address space, which `exec` leaves zero. The cast of `dolv` to `char *` is new: v7 stored a
`char **` where a `char *` belongs without one.

#lines-to("LOCAL VOID\texfile(BOOL prof)", lead: true)

The routine `exfile` moves the input and output descriptors to `INIO` and `OTIO`,
out of the way of the descriptors a user may redirect, and sets them to
be closed on `exec` (`Ldup`, below).

The shell is interactive if `-i` was given, or if input and output are
both terminals, as `gtty` succeeding shows. An interactive shell sets
the prompts and ignores `SIGTERM` (`KILL` in #f("sh/defs.h") is 15).
A `struct stat` for the mail check below, `statb` serves here only as
a buffer for `gtty`, and the port casts its address to the type that
`gtty`'s prototype demands.

Errors return to `errshell`, through `exitsh` (#f("sh/error.c")), but
only in an interactive shell. Any other exits. That is why the profile
is read with `ttyflg` set in `flags` (from `prof`, #l("ELSE\tflags |= prof; flags &= ~prompt;")): an error in
the profile comes back here, and `exfile` returns, abandoning the
profile but not the shell.

The variable `mailtime` is `volatile`, where v7 had `register`. It is changed after
the `setjmp` (#l("IF setjmp(errshell) ANDF prof")) and used after a `longjmp` to it, and C99 leaves the
value of such a variable indeterminate unless it is `volatile`. It is
also a `long long` rather than v7's `L_INT`, a `long`, so that it holds
a 64-bit `st_mtime` whole: cut to 32 bits, a time after 2038 would never
again compare equal, and the shell would announce mail at every prompt.

#lines-to("/* error return here */")

The command loop. A call `tdystak(0)` discards everything left on the stack by
the last command, and `stakchk` gives back any surplus memory
(#f("sh/stak.c")). An interactive shell then reports new mail, judged by
a change in the time of the last modification of the file named in
`$MAIL`, and prints `PS1`. A call `alarm(TIMEOUT)` would end a shell left idle
too long. Here `TIMEOUT` is 0 (#f("sh/timeout.h")), so no alarm is set.

The routine `readc` reads the first character of the command, which is pushed back
into `peekc`, so that `eof` can be tested before parsing begins. The routine `cmd`
(#f("sh/cmd.c")) then parses one command, up to a newline, and
`execute` (#f("sh/xec.c")) runs it. The v7 code called `execute` with two
arguments, leaving the two pipe arguments undefined. The prototype
demands all four, and the port passes zeros. The option `-t`
(`oneflg`) ends the shell after one command.

#lines-to("VOID", lead: true)

The routine `chkpr` prints the secondary prompt, `PS2`, when a command continues on
a further line. The routine `settmp` makes the prefix of the names of temporary
files from the process id. The id is copied to `tmpout[TMPNAM]`, which is
the `-` (#f("sh/defs.h")), so that the prefix is `/tmp/sh` followed by
the id, and `tmpnam` marks its end, where `tmpfil`
(#f("sh/io.c")) appends a serial number. In v7 the serial number
followed the id directly, so that the fifth temporary file of process
123 and the thirty-fifth of process 12 were both `/tmp/sh1234`, and
one shell could truncate the here document which another was writing or
reading. The port puts a `-` after the id (#l("tmpnam=movstr(minus,movstr(numbuf,&tmpout[TMPNAM]));")). The array `tmpout` grows from 20
bytes to 24 (#l("CHAR\t\ttmpout[24] = \"/tmp/sh-\";")) to hold `/tmp/sh`, an id of up to five digits, the
`-`, a serial number of up to ten, now that an `INT` has 32 bits, and
the null.

The routine `Ldup` moves descriptor `fa` to `fb` and sets close-on-exec on it. The v7 code
wrote `dup(fa|DUPFLG, fb)`: the `dup` system call took the second
descriptor as an extra argument when the flag `DUPFLG` (#f("sh/dup.h"))
was or-ed into the first. The library's `dup2` does exactly that, and,
unlike `dup`, has a prototype with two arguments.

#lines-to(none)
#source("/usr/src/cmd/sh/io.c")

The shell's input is a stack of `fileblk`s (#f("sh/mode.h")), of which
`standin` is the top, and `readc` (#f("sh/word.c")) takes characters from it.
This file sets up and changes the input, opens and creates files on
behalf of the rest of the shell, and copies here documents.

The routine `initf` makes descriptor `fd` the source of `standin`. An interactive
shell, or one run with `-t`, reads one character at a time, a size of
1. Any other reads 64 bytes. Reading a byte at a time, the shell never
takes more than the command it is about to run: what follows, typed
ahead or left in the input, belongs to the commands it starts or, with
`-t`, to whatever reads the input after the shell.

#lines-to("INT", lead: true)

The routine `estabf` makes the string `s` the input, with no file behind it
(`fdes` is -1). The end, `fend`, is placed after the terminating null,
since `length` (#f("sh/string.c")) counts it, and `readc` sees the null and
then finds the input exhausted. A null `s`, which `readc`
(#f("sh/word.c")) passes at the end of the strings given to `eval`, is
its own end (#l("f->fend=(f->fnxt=s) ? s+length(s) : s;")), and v7 added the zero which `length` returns for it to the
null pointer, which C99 leaves undefined. The routines `push` and `pop` stack and unstack
inputs, for `eval` and `.` (`execexp`, #f("sh/xec.c")), the `read`
command (#f("sh/name.c")), and the substitutions of #f("sh/macro.c").

#lines-to("VOID", lead: true, after: "FI")

The routines `chkopen` and `create` open a file or report failure. The routine `failed`
(#f("sh/error.c")) does not return, but the compiler, which cannot
know that, warns of a function that may end without returning a value.
The port adds `return(0)` (#l("return(0);", after: "THEN\tfailed(idf,badopen);"), #l("return(0);", after: "THEN\tfailed(s,badcreate);")). The routine `rename` moves a descriptor, by
`dup2`, where v7 used `dup` with `DUPFLG` (see `Ldup` in
#f("sh/main.c")). The routine `tmpfil` makes a fresh temporary file, named from the
prefix made by `settmp` and a serial number.

#lines-to("/* set by trim */", lead: true)

The routine `copy` reads the here documents named in the list `ioparg` (they were
collected in `iopend` by `inout`, #f("sh/cmd.c"), and are read once the
command line is complete). The list was built backwards, so `copy`
first recurses to its end, and the documents are read in the order in
which they were named. Each is copied line by line to a temporary
file, until a line equal to the terminating word. The I/O node is
changed to name the file, and joined to the chain `iotemp`, so that the
file is removed after the command. The text is read with `nextc`,
which handles `\` escapes, unless the terminating word contained
quotes. Then `trim` (#f("sh/service.c")) sets `nosubst`, and the text is
read raw and marked not to undergo substitution.

The variable `nosubst` (#l("extern BOOL\tnosubst;")) is now declared `extern`. The v7 code defined it both here and
in #f("sh/service.c"), which worked only because the loader merged the
two. The doubled parentheses at #l("IF (iop=ioparg)") are those of #f("malloc.c").

#lines-to(none)
#source("/usr/src/cmd/sh/word.c")

The lexical analyser. The routine `word` reads the next word or symbol and leaves its code in `wdval` (#f("sh/sym.h")). The code is 0 for an
ordinary word, whose text is in `wdarg`, a reserved word's code if one
is acceptable here, or else the character, or doubled character, which
ends a word.

The declaration of `readb` (#l("LOCAL INT\treadb(void);")) is new. The v7 code called it before its
definition and let it be declared implicitly, which C99 does not
allow.

#lines-to("INT")

An ordinary word is built on the stack as a `struct argnod`, ready to
be linked into an argument list: `locstak` begins an item, and the text
starts one word in (#l("REG CHAR\t*argp=locstak()+BYTESPERWORD;")), leaving room for the link `argnxt`. That the
offset is `BYTESPERWORD` and the link a pointer agree on the ARM as on
the PDP-11, since `BYTESPERWORD` is the size of a pointer
(#f("sh/mode.h")).

Quoting is recorded in the characters themselves. Within `'...'`, every
character has the quote bit or-ed in, and the whole is enclosed in
double quotes. Within double quotes or backquotes, `nextc` sets the bit on
escaped characters only, since parameters and commands are still to be
substituted there (#f("sh/macro.c")). A quoted character fails every
test of #f("sh/ctype.h"), and so cannot end the word. The routine `trim` removes the quote bits once substitution is done. On the PDP-11 a `char`
with the quote bit set was negative, on the ARM it is not. Nothing here
depends on which.

The variable `wdset` notes a word of the form `name=value`, which is an assignment if
`name` is an identifier. A single digit followed by `<` or `>` is not a
word but the descriptor of a redirection: `word` calls itself to read
the operator, and leaves the digit in `wdnum`. Otherwise, when the
parser has set `reserv`, the word is looked up among the reserved
words.

The v7 code used `argp`, a `char *`, as a pointer to the `argnod` as well, which
its compiler permitted. C99 does not, and each use of `argp` as an
`argnod` now casts it to `ARGPTR` (#l("IF !letter(((ARGPTR)argp)->argval[0]) THEN wdset=0 FI")--#l("THEN\twdarg=(ARGPTR)argp; wdval=0;")).

#lines-to("ELIF dipchar(c)")

A character which ends a word is a symbol in itself. If it is one of
`&;<>|` (`dipchar`) and is doubled, it becomes the doubled symbol.
Otherwise the second character is pushed back. The null character,
which `readc` returns at the end of the input, becomes `EOFSYM`. At the
end of a line, any here documents named on it are read (`copy`,
#f("sh/io.c")), since their text begins on the next line.

#lines-to("INT", lead: true)

The routine `nextc` deals with the backslash. Before a newline it joins the lines,
printing the secondary prompt. Inside double quotes, where `quote` is
the quote character, a backslash is kept, and the following character
pushed back, unless that character is the quote itself or one of the
characters `escchar` allows. Anywhere else the next character is taken
quoted.

#lines-to("INT", lead: true, after: "}")

The routine `readc` returns the next character of the input. A character pushed
back in `peekc` comes first. The assignment to the `char` `c` drops
`MARK`. Then come characters left in the buffer. A null in the buffer
ends a string set up by `estabf`. If the input has a list of further
strings (`feval`, set by `execexp` in #f("sh/xec.c") for the
arguments of `eval`), the next is begun,
separated by a space. `-v` (`readpr`) echoes the input as it is read,
and the line count `flin` serves the messages of #f("sh/cmd.c").
When the buffer is empty, `readb` refills it. At the end of a file the
descriptor is closed and `EOF`, the null character, is returned
from then on.

#lines-to("LOCAL INT\treadb(void)", lead: true)

The routine `readb` reads again when a read is interrupted by a signal which has
a trap set (`trapnote`). A signal without a trap (`SIGSET`) is instead
treated as an error by `sigchk` (#f("sh/error.c")), which ends the
shell or, if it is interactive, abandons the command. The return type
`INT` is a mechanical addition.

#lines-to(none)
#source("/usr/src/cmd/sh/cmd.c")

The parser. It is written by recursive descent, one procedure to each rule of the grammar given in the comments. They are `cmd` for a sequence of commands, `list` for commands joined by `&&` and `||`, `term` for a
pipeline, and `item` for a single command, simple or compound. Each
calls `word` (#f("sh/word.c")) for the next symbol, which it finds in
`wdval`, and returns a tree of the nodes of #f("sh/mode.h"), allocated
on the stack with `getstak`. The tree lasts until the command loop of
#f("sh/main.c") resets the stack, after `execute` has run it.

The parser keeps one symbol of lookahead, in `wdval`. A procedure is
entered with the first symbol of its phrase already read, or reads it
itself, according to the flag `NLFLG`. And it returns with the symbol
after the phrase in `wdval`. Reserved words are recognised only where a
command may begin, which the parser announces by incrementing `reserv`
before it calls `word`, and `word` clears it again.

The procedures of the file are declared `LOCAL` at the top (#l("LOCAL IOPTR\tinout(IOPTR lastio);")--#l("LOCAL VOID\tsynbad(void);")),
where v7 declared them `PROC`, that is `extern`, and defined them
`LOCAL`, a contradiction C99 does not allow. The routine `skipnl` was declared
`VOID`, but returns `wdval`, and `item` uses the result (#l("IF skipnl()==INSYM")). With
`VOID` now `void` it is declared, and defined, `INT`.

#lines-to("TREPTR\tmakefork(INT flgs, TREPTR i)")

The routines `makefork` and `makelist` make the two commonest nodes. The v7 code declared the
local `t` in each as a `TREPTR` and assigned the fields of a fork or
list node through it, which its compiler allowed for any structure
pointer. The port declares `t` as the pointer it is, and converts it to
`TREPTR` on return. The routine `getstak` returns a `STKPTR`, a `char *`, and each
call of it now has a cast to the type of node wanted, as C99 requires.
In `item` below, where v7's `t` must stay a `TREPTR` for the code after
the `switch`, each use of a field casts `t` to the node's own type
instead.

The routine `makelist` initialises `t` to 0. The routine `synbad` never returns, but the
compiler cannot know it, and would otherwise warn that `t` may be
returned unset.

#lines-to("/*", lead: true)

The routine `cmd` parses a list, then looks at what ended it. A newline, when
`NLFLG` allows one, is treated as `;`. An `&` makes the list into a
fork node which is not waited for (`FAMP`), ignores interrupts (`FINT`),
and has its process id printed (`FPRS`). Then, like `;`, it may be
followed by a further command, parsed by a recursive call. The argument `sym` is the
symbol the caller expects to end the command, such as `fi` or `)`, and
`chksym` insists on it.

The comments `/* fallthrough */` (#l("/* fallthrough */", after: "ELSE\tsynbad();"), #l("/* fallthrough */", after: "THEN\tbreak;")) are new, and tell GCC that the
missing `break` is intended. It warns of one otherwise. The doubled
parentheses at #l("IF (e=cmd(sym,flg|MTFLG))") are those of #f("malloc.c").

#lines-to("/*", lead: true, after: "}")

The routines `list` and `term` make the left-to-right chains of `&&`, `||`, and the
pipe. A pipeline becomes a `TFIL` node over two fork nodes: the left
writes the pipe (`FPOU`), the right reads it and closes it in the shell
(`FPIN|FPCL`). `^` is an older spelling of `|`. Since the right side is
parsed by a recursive call, a long pipeline nests to the right.

#lines-to("LOCAL REGPTR\tsyncase(REG INT esym)", lead: true)

The routine `syncase` parses the arms of a `case` until `esac`, or `}`: each arm is
a list of patterns separated by `|`, then `)`, a command list, and `;;`.
The patterns are chained by reusing the words' own `argnxt` links.

#lines-to("/*", lead: true)

The routine `item` parses one command. A simple command may begin with
redirections, so when `flag` allows, `inout` collects them first.

#lines-to("case CASYM:")

The compound commands. Each allocates its node and fills it by calling
`cmd` with the symbol which must end each part. The parser handles `elif` by
treating it as the start of a nested `if`, with `wdval` set to `IFSYM`
and `item` called again. The nested `if` consumes the `fi`, and the
outer returns at once (#l("IF w==EFSYM THEN return(t) FI")).

#lines-to("case FORSYM:", lead: true)

A `for` takes a name, an optional `in` with its list of words, which is
parsed as a simple command and stored as a `COMPTR` (#l("((FORPTR)t)->forlst=(COMPTR)item(0);")), then a
`do ... done` or a `{ ... }`. The cast of the result of `item` is new.
The loops `while` and `until` share a node, distinguished by type. A brace group
is no node at all, but just its command list. A parenthesised command
is a `TPAR` node inside a fork node, so that it is run in a subshell.

#lines-to("default:", lead: true)

The simple command. Words are taken until a symbol appears. Each is
either an assignment, chained on `argset`, or an argument, appended to
the list through `argtail`. Assignments are recognised only before the
first argument, unless the option `-k` (`keyflg`) is set. Redirections
may be interleaved with the words. The variable `argset` is declared as a pointer to
`ARGPTR`, though it holds an `ARGPTR`, and v7 assigned between the two types
freely, and the port casts (#l("THEN\targp->argnxt=(ARGPTR)argset;"), #l("((COMPTR)t)->comtyp=TCOM;")).

If no command begins here (`default`), but redirections were found, a
command without words is made, and the case falls through (267, with
the new comment). After a compound command, redirections may follow
(#l("reserv++; word();")). They wrap the command in a fork node, through whose `treio` they
are applied. The parentheses around the assignment (#l("IF (io=inout(io))")) are new.

#lines-to("LOCAL INT\tskipnl(void)", lead: true)

The routine `skipnl` reads symbols until one is not a newline, prompting with
`PS2` for each.

#lines-to("LOCAL IOPTR\tinout(IOPTR lastio)", lead: true)

The routine `inout` parses one redirection, and recursively those that follow. The
descriptor, if one was given before the operator, is in `wdnum`. The
kind of redirection is or-ed above it (#f("sh/defs.h")). A `<<`
document is also put on `iopend`, to be read at the end of the line
(#f("sh/word.c")). `<&` and `>&` are distinguished by reading one more
character directly, and `<>` gives read and write. The `>` case falls
through into the `<` case to make that test (329, with the new
comment).

#lines-to("LOCAL VOID\tchkword(void)", lead: true)

The routine `chkword` requires an ordinary word, and `chksym` requires the symbol
`sym`, or one of several reserved words or-ed together: when both
`sym` and `wdval` are reserved words, `x` is their common bits, and
equals `wdval` only if all of `wdval`'s bits are in `sym`
(#f("sh/sym.h")).

#lines-to("LOCAL VOID\tprsym(INT sym)", lead: true)

The routine `synbad` reports a syntax error, naming the offending symbol through
`prsym`, with the line number when the shell is not interactive, and
leaves through `exitsh` (#f("sh/error.c")).

#lines-to(none)
#source("/usr/src/cmd/sh/msg.c")

The shell's strings, gathered in one file so that each is stored once.
A `MSG` is an array of `char`, so each name stands for the address of
its text. Nothing uses `version`, which records the version of the
shell in the binary. The default `PATH` (#l("MSG\tdefpath\t\t= \":/bin:/usr/bin\";")) searches the current
directory first.

#lines-to("/* tables */", lead: true)

The table `reserved` pairs each reserved word with its code from #f("sh/sym.h"),
and `word` (#f("sh/word.c")) searches it with `syslook` (#f("sh/name.c")).
The table `sysmsg` gives, for each signal number, the message printed when a
command dies of it (#f("sh/service.c")). The entries for interrupt and
broken pipe are null, since a user who interrupts a command, or a
command whose reader has gone, needs no message. The table ends at
"Signal 16" (#l("\"Signal 16\",")), the last of the sixteen signals
(#f("param.h")). The table `commands` holds the
built-in commands, with their codes from #f("sh/defs.h").
The entry for `[`, `SYSTST`, is commented out.

The other changes are the `=` before the initialisers of the three
tables (#l("SYSTAB reserved = {"), #l("STRING\tsysmsg[] = {"), #l("SYSTAB\tcommands = {")), which v7's compiler did not require.

#lines-to(none)

== Running Commands <ch-running>

#source("/usr/src/cmd/sh/dup.h")

`DUPFLG` is the flag which v7's `dup` system call recognised in its
first argument: or-ed into the descriptor, it made `dup` take a second
argument and move the descriptor to that number, as `dup2` does on later
systems. The files #f("sh/main.c") and #f("sh/io.c") still include the file, but
call the library's `dup2` instead (`Ldup` and `rename`), so that the
call agrees with a prototype of two arguments. The definition is now
used nowhere.

#lines-to(none)
#source("/usr/src/cmd/sh/timeout.h")

`TIMEOUT` is the number of seconds an interactive shell may sit at its
prompt before it gives up. The command loop of #f("sh/main.c") calls
`alarm(TIMEOUT)` before each read, and `fault` (#f("sh/fault.c"))
ends the shell if the alarm arrives while it is still waiting. With the
value 0 the call cancels any alarm instead, and an idle shell
waits indefinitely. A site which wanted the feature changed this file.

#lines-to(none)
#source("/usr/src/cmd/sh/xec.c")

The routine `execute` walks a command tree made by `cmd` (#f("sh/cmd.c")) and does
what it says. It is recursive: each kind of node calls `execute` on its
parts, and the value returned is the exit status of the last command
run, which the conditional nodes test. Most of the shell's work with the
kernel happens here or in the routines of #f("sh/service.c") that it calls. It uses `fork` (#f("sys1.c")) to make a process for a command, `pipe`
(#f("pipe.c")) to connect two, `exece` (#f("sys1.c")) to run a program,
and `wait` (#f("sys1.c")) to collect its status.

The v7 code called `execute` with only two arguments when no pipe was involved,
leaving `pf1` and `pf2` undefined, which its compiler allowed. With a prototype every call must
pass four, and the port passes zeros throughout the file.

The table of built-in commands, `commands` (#l("extern SYSTAB\tcommands;")), is defined in
#f("sh/msg.c"); the declaration is now `extern`, where v7's tentative
definition relied on the loader to merge it with the real one
(#f("sh/defs.h")).

#lines-to("INT")

The flag `execflg` is set when the command is the last thing the current process
has to do. A simple command may then be executed by `exec` without a
`fork` first (#l("IF execflg ANDF (treeflgs&(FAMP|FPOU))==0")), since there is nothing to come back to.

The variable `sav` and the call of `tdystak` (#l("tdystak(sav);")) bracket the whole routine: whatever the
command allocated on the stack, its expanded arguments in particular,
is discarded when it ends. A nonzero `execbrk` (#l("IF (t=argt) ANDF execbrk==0")) means that `break`
or `continue` is unwinding the loops, and every command until the
enclosing loop is reached is skipped by this test.

The port initialises `com` (#l("REG STRING\t*com = 0;")). It is set only in the `TCOM`
case, and used after the fall into `TFORK` only when the type is `TCOM`, and
GCC cannot follow the correlation and would warn that it might be used
unset.

#lines-to("SWITCH type IN")

A simple command. The routine `getarg` expands its words, substitutes parameters, and generates file names, and `scan` gathers the results into
an argument vector `com` (#f("sh/service.c")). The expansion builds the
global chain `gchain`, which is saved and restored around it because
expanding a word may itself execute a command, by command substitution
(#f("sh/macro.c")), and so re-enter `execute`.

The parser wraps a simple command in a fork node only for
`&` or a pipeline. Otherwise the decision to fork is made here, after
expansion, for only now can the shell tell whether the name is one of
its own commands (`syslook`). The assignments which precede a built-in
command, or stand alone, are made in the shell itself (#l("THEN\tsetlist(c->comset, 0);")). Those
before a program are made in the child for that program only (#l("THEN\tsetlist(((COMPTR)t)->comset,")).
The option `-x` (`execpr`) prints the expanded command.

The port names the node through `c`, a `COMPTR`, where v7 used the
generic `t` for every field. In particular v7 read the I/O list of a
command node as `t->treio`. It is now `c->comio`, the same word, since
both structures put it after the type (#f("sh/mode.h")).

A command of assignments alone, such as ``x=`date` ``, has no words,
and `com[0]` is then a null pointer. v7 passed it to `syslook`
regardless, which read location 0, harmless on the PDP-11. Here
nothing is mapped at address 0 (#f("sys1.c")), so the port tests
`argn` first (#l("IF argn==0 ORF")), and `syslook` is called only for
a command with a name. `internal` is set to 0 at its declaration
(#l("INT\t\targn, internal=0;")), since the compiler cannot see that it
is used only when `argn` is nonzero.

#lines-to("SWITCH internal IN")

The built-in commands. `.` reads commands from a file in the current
shell by way of `execexp` (#l("execexp(STRING s, UFD f)")). The command `times` prints the user and system
times of the shell's children, which the kernel accumulates in
`u_cutime` and `u_cstime` (`times`, #f("sys4.c")), and `prt` converts ticks
to hours, minutes, and seconds assuming 60 to the second, which is still `HZ`
(#f("param.h")). The kernel copies out four `time_t`s, so the array
`t` (#l("long long\tt[4]; times(t);")) is of `long long`. As v7's `L_INT`, a `long`, it would hold
only half of what is copied into it, and the rest would overwrite the
stack.

The commands `break` and `continue` work through `execbrk`. A `continue` sets it to
`-loopcnt`, a negative value which the loops below reset to zero after
each pass of the body. A `break` sets it to the positive `loopcnt`, and
`break n` sets `breakcnt` as well, which each loop on the way out
decrements, so that `n` loops are left. This is why `execbrk` must hold a
negative number, and is no longer a `char` (#f("sh/defs.h")).

The v7 code let the `exit` case fall through into the next, harmless since
`exitsh` never returns. GCC warns of a fall through between cases
without a comment to say it is meant. The port ends the case with
`break` (#l("break;", after: "exitsh(a1?stoi(a1):oldexit);")), which states the intent better.

#lines-to("case SYSTRAP:", lead: true)

Given a command and signal numbers, `trap` stores the command in
`trapcom` and catches the signals. An empty command ignores them
instead. If the first argument is a number, there is no command, and
the listed traps are removed. Without arguments the traps are listed.
The mechanism is in #f("sh/fault.c").

#lines-to("case SYSEXEC:", lead: true)

The command `exec` applies its redirections to the shell itself (#l("initio(io); ioset=0; io=0;")). With no
command, that is all. Otherwise it falls into `login` (and `newgrp`,
which has the same code): the shell marks itself `forked`, so that an
error now ends it rather than returning to the prompt, restores the
signals it inherited (`oldsigs`), and executes the command in its own
process. If the `exec` fails, `done` ends the shell. The comment
`/* fallthrough */` (#l("/* fallthrough */", after: "IF a1==0 THEN break FI")) is new and silences GCC. The `break` after
`done` (#l("break;", after: "oldsigs(); execa(com); done();")) is new for the reason given for `exit`.

The command `wait` calls `await(-1)`, which collects children until there are none
left (#f("sh/service.c")).

#lines-to("/*", lead: true, after: "break;")

The `test` command was meant to be built in, but v7 left it commented
out, and `test` is a separate program.

Given arguments, `set` processes options and replaces the positional
parameters. Without, and without assignments, it lists the variables.
The commands `readonly` and `export` share code, with `exitval` borrowed to hold the
attribute until it is reset (#l("exitval=0;")). The comment at #l("/* fallthrough */", after: "exitval=N_RDONLY;") is new.

The command `eval` runs its arguments as commands with `execexp`. The second
parameter of `execexp` is declared `UFD`, an `int`, but serves two
purposes: a file descriptor when the first is null, otherwise the
address of the list of further arguments. The v7 code passed the address
without a cast, and C99 requires one each way, here and at #l("THEN\testabf(s); fb.feval=(STRING *)f;"), and the
conversion is exact because an `int` and a pointer are both 32 bits on
the ARM, as both were 16 on the PDP-11.

#lines-to("case SYSUMASK:")

Someone other than Bourne added `umask` to the shell later, writing
plain C with spaces for indentation instead of the macros of
#f("sh/mac.h"); the port keeps it as it is. In v7 the declaration at
209 lacked its semicolon, a syntax error, and the port adds it.

#lines-to("default:")

The routine `builtin` (#f("sh/builtin.c")) is a hook for local built-in commands,
and returns zero. The v7 code passed it `argn` and `com`, which its definition
ignored. It is now declared without parameters and called without
arguments.

A built-in command may not be redirected, except `exec` and `:`, which
cleared `io` above. After a built-in, `chktrap` runs the traps raised meanwhile. A command with no words and no redirections consisted only
of assignments, and is finished. The remaining cases, a program to run
or redirections with no command, fall through (239, new comment) to be
forked.

#lines-to("case TFORK:")

The fork. No process is made if `execflg` says this is the last
command of the present process, unless the node is to run in the
background (`FAMP`) or write into a pipe (`FPOU`): in either case the
shell must go on to do something else. If `fork` fails, because the
process table is full, the shell waits ten seconds with `alarm` and `pause` and
tries again. An interrupt meanwhile ends the attempt through `sigchk`.

Only the zero or nonzero value of `fork` is used. As in v7, the kernel
returns the parent's pid in the child, and the library's stub turns it
into 0 (#f("sys1.c")).

The parent prints the child's pid for `&` in an interactive shell, and
closes its copy of the pipe once the reading end of a pipeline has been
forked (`FPCL`). It then waits (`await`) for an ordinary command,
records (`post`) the writer of a pipe, to be waited for together with
the reader at the end of the pipeline, or, for `&`, stores the pid in
`$!` and does not wait at all.

#lines-to("ELSE\t/* this is the forked branch (child) of execute */", lead: true)

The child. It is marked `forked`, forgets its parent's temporary files
and children, and makes temporary names of its own (`settmp`,
#f("sh/main.c")). The routine `oldsigs` (#f("sh/fault.c")) restores the signals to
their state on entry, except those which a `trap` set to be ignored. A
command run with `&` ignores interrupt and quit (#l("THEN\tsignal(INTR,SIG_IGN);")), and, unless its
standard input was otherwise set, reads `/dev/null`, so that it cannot
compete with the terminal. Ignored signals stay ignored across `exec`
(`setregs`, #f("sys1.c")). This is all the protection v7 gives the
terminal against a background command.
The v7 code wrote `signal(INTR,1)`. The port uses `SIG_IGN`, which
`signal.h` defines as the pointer the prototype of `signal` expects.

The pipe ends are moved to the standard input or output with `rename`
(#f("sh/io.c")), and the unused end is closed: a reader sees the end of
a pipe only when every descriptor for its writing end has been closed
(`readp`, #f("pipe.c")), and a stray copy in the reader itself would
hang it. Then the node's redirections are applied, after those defaults,
so that they win.

A subtree, from a parenthesised command, an `&`, or a pipeline, is run
by a recursive `execute` with `execflg` set, so that its last command
is executed without a further fork. The routine `execa` executes a simple command. Either way `done` ends the child if control comes back.

The `break` (#l("break;", after: "execa(com);")) is new. In v7 the `TFORK` case ended without one,
since both branches leave by `break` or `done`, and control passed into
`TPAR` in appearance only.

#lines-to("case TPAR:")

A parenthesised command runs in a child made by the enclosing fork
node. Its diagnostic output, `output`, is a private copy of descriptor
2 made by `exfile` (#f("sh/main.c")). It is replaced by a fresh copy of
the present descriptor 2, so that a redirection of the standard error
around the parentheses applies to the subshell's own messages too. The
`break` (#l("break;", after: "execute(((PARPTR)t)->partre,execflg,0,0);")) is new, as at #l("break;", after: "execa(com);").

#lines-to("case TFIL:")

A pipeline. A pipe is made, and the left side is run with it as `pf2`,
its output. The right side is then run with it as `pf1`, its input,
and with the original `pf2`, so that a longer pipeline, which nests to
the right, passes its last output through. The left side is a fork node
with `FPOU`, so `execute` returns as soon as it has been forked, and
the right side, which has `FPCL`, closes the pipe in the shell and
waits for both. The pipe is made only now, when it is needed, so that
the shell holds at most one at a time. The variable `l` (#l("REG LSTPTR\tl=(LSTPTR)t;")) is the port's typed
pointer, as `c` above.

#lines-to("case TLST:")

The lists are joined by `;`, `&&`, and `||`. Only the right side of each inherits
`execflg`, since the left must return to the shell.

#lines-to("case TFOR:")

Next comes `for`. Without `in`, the loop runs over the positional parameters, and
`useargs` (#f("sh/args.c")) increments their use count, so that a `set`
in the body does not free them while the loop is using them, and
`freeargs` releases them at the end. With `in`, the list is expanded as
for a command. The routine `scan` leaves the first word of its result untrimmed
(#f("sh/service.c")), and `trim` here removes its quoting.

The variable `loopcnt` counts the loops entered, for `break` and `continue`. On
leaving, `breakcnt` is decremented and becomes the new `execbrk`, which
stops the next loop out if more remain to be broken.

#lines-to("case TWH:")

The loops `while` and `until` differ in one comparison: the body is run while the
status of the condition, compared with zero, agrees with the type. The
exit status is that of the last pass of the body, or zero if there was
none.

#lines-to("case TSW:")

Then comes `case`. The word is expanded and its quoting removed. Each pattern of
each arm is expanded in turn and matched with `gmatch`
(#f("sh/expand.c")). Characters quoted in the pattern still carry the
quote bit and match only themselves. Failing that, the pattern is
trimmed and compared as a plain string. The first arm with a match is
run and the search ends. The typed pointers `s` and `re` are the port's,
and the `TREPTR` casts (#l("t=(TREPTR)s->swlst;"), #l("IF t THEN t=(TREPTR)re->regnxt FI")) are needed because v7 used `t` to walk
the list of `regnod`s, which have no type field at all.

After any command, `exitset` (#f("sh/error.c")) copies the status into
`$?`.

#lines-to("VOID", lead: true)

The routine `execexp` executes a string, for `eval` and for traps, or the contents
of an open file, for `.`. A new input block is pushed on the input
stack (#f("sh/io.c")), the whole input is parsed by one call of `cmd`,
with newlines taken as `;`, and only then executed. A file read with
`.` is therefore parsed completely before any of it runs.

#lines-to(none)
#source("/usr/src/cmd/sh/service.c")

With these routines `execute` (#f("sh/xec.c")) does its detailed work.
They redirect, search `$PATH` and execute a program, wait for
children, and convert a command's words into an argument vector.

The three `LOCAL` declarations (#l("LOCAL VOID\tgsort(STRING from[], STRING to[]);")--#l("LOCAL INT\tsplit(STRING s);")) are new in this form. The v7 code
declared `gsort` `PROC`, that is `extern`, and `execs` in
#f("sh/defs.h"), and then defined both `LOCAL`; `split` it did not
declare at all, and its first use in `getarg` declared it implicitly as
an external function. C99 forbids a `static` definition after a
declaration with external linkage, and has no implicit declarations.

The port now declares `errno` and `sysmsg` `extern`. They are defined in the
C library and in #f("sh/msg.c"). In v7 these lines were tentative
definitions, merged by the loader with the real ones, which C99 does not
allow (#f("sh/defs.h")). The error numbers are defined here by hand, as
in v7, rather than taken from `errno.h`.

#lines-to("VOID\tinitio(IOPTR iop)")

The routine `initio` applies a list of redirections, in order, to the present
process. A here document has already been copied to a temporary file
when its line was read (#f("sh/io.c")), and `subst` (#f("sh/macro.c")) copies it again,
substituting parameters, into a second temporary file, which is opened
for reading and at once unlinked, so that it vanishes when closed. A
document whose terminating word was quoted has lost `IODOC` in `copy`,
and its first file is opened as it is. `<&`
and `>&` duplicate a descriptor, or with `-` close it. The others open
or create the named file. The new descriptor is moved to the one being
redirected by `rename` (#f("sh/io.c")). A restricted shell may not
redirect output.

The port initialises `fd` to -1 (#l("REG INT\t\tiof, fd = -1;")). On the path through
`failed` (#l("THEN\tfailed(ion,restricted);")) it is never assigned, but GCC cannot know that `failed`
does not return, and would warn that `fd` might be used unset.

#lines-to("STRING\tgetpath(STRING s)", lead: true)

The routine `getpath` returns the list of directories to search for a command: the
empty string, meaning the name itself, if the name contains `/`. Else
`$PATH`, or the default `:/bin:/usr/bin` (#f("sh/msg.c")), whose
empty first entry stands for the current directory. The statement `return(0)`
(#l("return(0);")) is new. It is never reached, since the one path which arrives
there passes through `failed`, and v7 let control run off the end of the
function, of which GCC warns.

The routine `pathopen` opens a file found by the search, for `.` and for the
profile (#f("sh/main.c")). The routine `catpath` builds
on the stack the next candidate, the first directory of `path` joined to
`name`, and returns the rest of the list, or 0 when it is exhausted.

#lines-to("LOCAL STRING\txecmsg;")

The routine `execa` tries each directory in turn. Before the first `exec` the
exported variables are marked (`exname`) and the environment is built
(`setenv`, #f("sh/name.c")). The doubled parentheses at #l("WHILE (path=execs(path,t)) DONE") are those
of #f("malloc.c").

The routine `execs` calls `execve` (`exece` in #f("sys1.c")). If it returns at all,
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
`ENOMEM`, `E2BIG`, and `ETXTBSY`, the last returned for a program which
some process has open for writing (`getxfile`, #f("sys1.c")), end the
search with a message.

The comments `/* fallthrough */` are new. GCC warns of a case which
runs into the next without one. After `longjmp` and `failed` control
does not in fact pass, and only the last, from `default` into
`ENOENT`, is a fall through in earnest.

#lines-to("/* for processes to be waited for */", lead: true)

The shell remembers in `pwlist` the children it intends to wait for.
The routine `post` adds one, overwriting the last slot if the table is full, and
`postclr` empties it, in a newly forked child.

#lines-to("VOID\tawait(INT i)")

The routine `await` posts `i` and then calls `wait` until every posted child has
been collected. Each pid returned is struck from the list. A child
which was never posted, such as a background command that has finished
meanwhile, is reaped all the same, and its status is counted with the
rest. For the command `wait`, `await(-1)` posts -1, which only the
-1 returned by `wait` when no children remain can strike out. It thus
waits for all children.

The status is as `wait` delivers it (#f("sys1.c")), with the exit code in the high byte, and in the low byte the number of the signal which
killed the process, with 0200 if a core image was written, or 0177 if it
is stopped under trace. A death by signal is reported, by the message in
`sysmsg`, preceded by the pid unless the process was the one awaited
by an interactive shell. A newline follows, even for the signals
which have no message, so that after an interrupt typed at the
terminal the prompt begins a fresh line. The v7 code printed it for `SIGPIPE`
as well. The port does not (#l("IF sig != SIGPIPE THEN newline() FI")). A writer in a pipeline such as
`ls | sed 1q` dies of `SIGPIPE` or finishes first as the scheduling
happens to fall, and the blank line would come and go with it.
The status kept, `rc`, is the first nonzero one collected,
a signal being marked with `SIGFLG`. With the option `-e` any failure
ends the shell. The parentheses at #l("IF (sig = w&0177)") are new.

#lines-to("BOOL\t\tnosubst;")

The routine `trim` strips the quote bit, 0200, which #f("sh/macro.c") sets on
quoted characters, and records in `nosubst` whether any was found.
This file defines `nosubst`, which v7 defined in #f("sh/io.c") as well. The
parentheses at #l("IF (p=at)") and #l("THEN\tWHILE (c = *p)") are new.

The routine `mactrim` substitutes parameters in a word and removes its quoting.

#lines-to("STRING\t*scan(INT argn)")

The routine `scan` makes the argument vector. The words are on `gchain` in reverse
order, so the vector is filled from its end. The low bit of a link,
`ARGMK`, marks the end of the group of names which one pattern
generated. The routine `gsort` sorts each group as it is completed, and the
words otherwise keep their order. Every word but the last taken, which
is `com[0]`, is trimmed here.

The flag bit is cleared and set by casting the pointer to an `int`
(`Rcheat`, #f("sh/mode.h")). C99 needs a cast back to a pointer (#l("REG ARGPTR\targp = (ARGPTR)(Rcheat(gchain)&~ARGMK);"),
#l("argp = (ARGPTR)(Rcheat(argp)&~ARGMK);")), and another on the result of `getstak` (#l("comargn=(STRING *)getstak(BYTESPERWORD*argn+BYTESPERWORD);")).

#lines-to("LOCAL VOID\tgsort(STRING from[], STRING to[])")

The routine `gsort` is a Shell sort, by `cf` (#f("sh/string.c")), with gaps each
one less than a power of two, decreasing to 1.

#lines-to("/* Argument list generation */")

The routine `getarg` expands each word of a command and returns the number of
arguments it produced.

The routine `split` divides the result of substitution at the characters of
`$IFS`. Each field is pushed on the stack with room for a link before
it, so that it forms an `argnod` (#f("sh/mode.h")), and is offered to
`expand` (#f("sh/expand.c")), which puts the file names a pattern
matches on `gchain`. If there are none, the field itself goes on the
chain (`makearg`). Either way the head of the chain is then marked as
the end of a group, for `scan`.

The pointer `argp` is a `STRING`, and v7 took `->argval` from it directly. The port
casts it to `ARGPTR` (#l("IF (c=expand(((ARGPTR)(argp=endstak(argp)))->argval,0))"), #l("makearg((ARGPTR)argp); count++;")). The v7 code set the mark with `Lcheat`, storing
into the pointer through an `int` lvalue, which C99's rules of aliasing
do not allow. It is now an assignment (#l("gchain=(ARGPTR)(Rcheat(gchain)|ARGMK);")).

#lines-to(none)
#source("/usr/src/cmd/sh/fault.c")

The shell's handling of signals. Two tables are indexed by signal
number: `trapcom` holds the command set by `trap` for each signal, and
`trapflg` its state. `SIGMOD` (#f("sh/defs.h")) records that the shell
has changed the signal's disposition from the one it inherited, and
`TRAPSET` and `SIGSET` that the signal has arrived, with or without a
trap. Signal 0 stands for the exit of the shell (`done`,
#f("sh/error.c")).

The handler does next to nothing at the moment of the signal. It only
sets flags, which the shell examines at safe points. The routine `sigchk` (#f("sh/error.c")) looks before and after each command, `chktrap` after a
built-in or a child, and the input routines while a command is read.

#lines-to("VOID\tfault(REG INT sig)")

The handler `fault` first catches the signal again. The kernel resets a caught
signal to its default before calling the handler (`psig`, #f("sig.c")),
so a second interrupt arriving before this line would kill the shell.

`MEMF` is `SIGSEGV`, the means by which v7's shell grew its data
segment. When a store beyond the break faulted, the PDP-11 kernel undid
the effects of the faulting instruction on the registers (`backup`)
before it sent the signal, so that the instruction was executed again
on return from the handler, and `fault` had meanwhile extended the segment
with `setbrk`, and the second attempt succeeded (#f("sh/stak.c")). The
comparison with `(BYTPTR)-1` is new: `setbrk` returns a pointer
(#f("sh/setbrk.c")), and C99 does not compare one with the integer -1.

On the ARM the trick works unchanged: a data abort leaves the saved
`pc` at the faulting instruction (#f("low.s")), so that returning from
the handler retries it, and the kernel maps the data only up to the
break (#f("ureg.c")). A wild reference which extending the break cannot
cure faults again and again, each time extending the break, until
`sbreak` refuses to grow the data further (`estabur`, #f("ureg.c")),
whereupon `error` reports `nospace`.

`ALARM` ends a shell which is waiting at its prompt
(#f("sh/timeout.h")). Other alarms, such as the one with which a failed
`fork` is retried (#f("sh/xec.c")), only interrupt a `pause`. Any other
signal is noted, as a trap to be run or as a reason to abandon the
command.

#lines-to("VOID", after: "}")

The routine `stdsigs` sets up the signals for the main shell. Quit is ignored, interrupt is caught, and so are `SIGSEGV`, for the growth of the data
segment, and the alarm.

The routine `ignsig` ignores a signal and returns 1 if it was already ignored. A
signal the shell inherited as ignored, as an interrupt is in a command
run with `&`, is left so: `getsig` catches a signal only if the shell
itself changed it, or it was not ignored on entry. Hence a `trap` cannot
revive an interrupt in a background shell.

The v7 code asked whether the old disposition was 1 by testing its low bit
(#l("IF (s=signal(i=n,SIG_IGN)==SIG_IGN)==0")), which a function address, being even on the PDP-11, had clear. The
port compares with `SIG_IGN` instead, since C99 allows no arithmetic on
a pointer to a function.

#lines-to("VOID", after: "THEN\tsignal(i,fault);")

A child calls `oldsigs` before it runs a command, and the
shell does before `exec`. The routine `clrsig` forgets every trap, except one
that `trap` set to be ignored, with an empty command, and pending
signals are discarded. A signal the shell had changed is caught once
more by `fault`, which serves a child that goes on running shell code,
such as a parenthesised command. At `exec` the kernel resets caught
signals to their defaults and leaves ignored ones alone (`setregs`,
#f("sys1.c")). A program therefore receives the signals as the shell
inherited them, except those ignored by `trap ''`.

The routine `clrsig` frees the trap's command, and `free` of a null pointer is harmless in this allocator
(#f("sh/blok.c")).

#lines-to("VOID", after: "trapflg[i] &= ~SIGMOD;")

The routine `chktrap` runs the traps of the signals which have arrived since the
last call, preserving `$?` across them. The parentheses at #l("IF (t=trapcom[i])") are new.

#lines-to(none)
#source("/usr/src/cmd/sh/builtin.c")

The routine `builtin` is called by `execute` (#f("sh/xec.c")) for a command name
which is not in the table of built-in commands, and returns zero: no
further commands are built in. It is a place for an installation to add
its own. The v7 file held only the function, with its type left to
default to `int`. The port includes #f("sh/defs.h"), so that the
definition is preceded by the prototype which `-Wmissing-prototypes`
demands, and declares the function without parameters, and v7's caller
passed two arguments which the definition never declared.

#lines-to(none)
#source("/usr/src/cmd/sh/error.c")

The shell stops after an error, after a signal, or at the end.

The routine `exitset` copies the exit status into the variable `$?`. Called
before and after every command, `sigchk` abandons the command if a signal
for which no trap is set has arrived (`fault`, #f("sh/fault.c")). The
status is then `SIGFAIL`.

#lines-to("VOID", after: "FI")

The routine `failed` prints a message, prefixed by the name of the shell or
command file when the shell is not interactive (`prp`, #f("sh/print.c")), and ends the
command with the status `ERROR`. Neither it nor `error` returns. The
compiler is not told so, which is why some callers in
#f("sh/io.c"), #f("sh/service.c"), and #f("sh/print.c") carry
statements that are never reached, to quiet its warnings.

#lines-to("VOID", after: "failed(s,NIL);")

The routine `exitsh` decides between ending the shell and abandoning the command.
Only an interactive shell (`ttyflg`), which is neither a forked child
nor running with `-e` (`errflg`), survives an error: `clearup`
(#f("sh/args.c")) discards the pending input files and `for` lists, and
`longjmp` returns to `errshell` in `exfile` (#f("sh/main.c")), which
reads the next command. Anything else exits through `done`.

#lines-to("VOID", after: "}")

The routine `done` runs the trap set on signal 0, the shell's exit, clearing it
first so that an error within it does not run it again, removes the
temporary files, and exits. The parentheses at #l("IF (t=trapcom[0])") are new.

The routine `rmtemp` unlinks the temporary files made since `base`, which hold
here documents. The I/O nodes naming them are chained through `iolst`
from `iotemp` (`copy`, #f("sh/io.c")). Being allocated on the stack, they lie at higher
addresses the later they were made, so a comparison of addresses finds
those newer than `base` (`tdystak`, #f("sh/stak.c")). The routine `done` passes
0 and removes them all.

#lines-to(none)

== Words and Variables <ch-words>

#source("/usr/src/cmd/sh/name.h")

The header #f("sh/name.h") describes a shell variable. Each is a `namnod`, and the
nodes form a binary tree ordered by name (`lookup`, #f("sh/name.c")). The fields `namlft` and `namrgt` are the two subtrees, `namid` the name, `namval`
the present value, and `namenv` the value which the variable had in the
environment, or will be given in the environment of the next program
(`exname`). A variable which has never been set has a null `namval`,
which is not the same as an empty one.

The flags in `namflg` mark a variable as read-only (`N_RDONLY`), as
exported (`N_EXPORT`), or as having come from the environment
(`N_ENVNAM`). `N_ENVPOS` is not used anywhere in the shell. The highest
flag, `0100000`, was the sign bit of a PDP-11 `int`. In the thirty-two
bit `INT` of the ARM it is an ordinary bit, and nothing compares
`namflg` with zero except through a mask.

#lines-to(none)
#source("/usr/src/cmd/sh/name.c")

The shell's variables. They live in a binary tree of `namnod`s
(#f("sh/name.h")), searched and extended by `lookup`. Names and values
are copies on the heap (#f("sh/blok.c")), made by `make`. The file also
holds the two conversions between the variables and the environment. The routine `getenv` turns
the environment the shell was given into variables, and `setenv` builds the environment of a program
about to be executed.

The declarations of `chkid` and `namwalk` (#l("LOCAL BOOL\tchkid(STRING nam);"), #l("LOCAL VOID\tnamwalk(NAMPTR np);")) are needed because
both are called before they are defined, and v7 declared `chkid` with
`PROC`, meaning `extern`, and `namwalk` not at all. Both are `LOCAL`,
that is `static`, as their definitions are.

The tree starts with the seven variables which the shell itself
consults, already linked as a balanced tree with `MAIL` at its root and
`FILEMATCH`, `HOME`, and `IFS` to the left, `PATH`, `PS1`, and `PS2` to
the right, in alphabetical order. Their names are strings of
#f("sh/msg.c"). The v7 code initialised only the first three fields and wrote
the null links as `NIL`, which is `(char *)0` (#f("sh/mode.h")). C99
does not convert a `char *` to a `NAMPTR` without a cast, so the links
are now plain zeros, and the three fields left to default are given
explicitly, since `-Wextra` warns of a structure initialiser which
omits fields.

#lines-to("/* ========\tvariable and string handling\t======== */")

The routine `syslook` finds a word in a table of `sysnod`s, terminated by a null
name: the reserved words and the built-in commands (#f("sh/msg.c")).
The first characters are compared before `eq` is called, which spares a
procedure call for most entries. It returns zero for a word not in the
table, which is why no code in either table is zero.

#lines-to("VOID", lead: true)

The routine `setlist` makes the assignments of a list of words, each of the form
`name=value`. Each is substituted and unquoted by `mactrim`
(#f("sh/service.c")) and handed to `setname` with the attributes `xp`.
With `-x` the assignments are printed as they are made. The routine `execute`
(#f("sh/xec.c")) calls it with zero for assignments made in the shell,
and with `N_EXPORT` for those which precede a command and are made in
the child just before the command is executed.

#lines-to("VOID\tsetname(STRING argi, INT xp)", lead: true)

The routine `setname` splits `name=value` at the `=`, which it replaces by a null
for the duration of `lookup`. A word whose name is not an identifier is
reported with `failed` (#f("sh/error.c")).

For a variable from the environment (`N_ENVNAM`) the value is not
copied: `namval` and `namenv` both point into the environment string
itself. That string lies at the top of the user stack, where `exece`
(#f("sys1.c")) placed it, above the heap. When such a value is later
replaced, `free` is called on it all the same, and `free` ignores any
address above `bloktop` (#f("sh/blok.c")), and the call does no harm.

#lines-to("VOID", lead: true, after: "}")

The routine `assign` refuses to change a read-only variable, and `dfault` sets a
variable only if it has no value, and `main` uses it to give `PS1`,
`PS2`, and `IFS` their defaults (#f("sh/main.c")).

#lines-to("INT\treadvar(STRING *names)", lead: true)

The built-in command `read` is `readvar`. It reads one line of the
standard input and assigns its fields, separated by characters of
`$IFS`, to the named variables in turn. The last variable named takes
the remainder of the line. Missing fields leave the variables empty.

The first variable is looked up (#l("NAMPTR\t\tn=lookup(*names++); /* done now to avoid storage mess */")) before anything is placed on the
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
The command `read` must not consume more than the line, or the commands which
follow it in a script read from the same descriptor would lose their
input. If the descriptor can be repositioned, the buffer is filled as
`initf` chose. If it cannot, as for a pipe, `lseek` fails, and `fsiz`
is set to one, so that `readb` reads a single character at a time. A
terminal can be repositioned, to no effect, but no read from it returns
more than a line.

#lines-to("LOOP\tc=nextc(0);")

The routine `nextc` (#f("sh/word.c")) applies the backslash convention. At the end,
the unread part of the buffer is given back by seeking backwards over
it (#l("lseek(0, (long)(f->fnxt-f->fend), 1);")): the duplicate shares its offset with descriptor 0 (`dup`,
#f("sys3.c")), so the next reader of the standard input starts just
after the line. The return value is 1 at the end of the file, which is
how a loop of `read` terminates.

#lines-to("VOID", lead: true)

The routine `assnum` stores a number as the value of one of the shell's special
parameters, such as `$#` and `$?`, which are kept as strings
(`dolladr`, `exitadr`). The routine `make` copies a string to the heap, and since `length`
(#f("sh/string.c")) counts the terminating null, the copy has room
for it.

#lines-to("NAMPTR\t\tlookup(REG STRING nam)", lead: true)

The routine `lookup` finds the node of a name, or makes one. It descends the tree,
comparing with `cf`, keeping in `prev` the address of the link it
followed. When it falls off the tree, a new node is stored through
`prev`. The tree is never rebalanced, nor are nodes ever removed: v7
has no `unset`. The routine `failed` reports a name which is not an identifier before
the search.

The port initialises `prev` to zero (#l("REG NAMPTR\t*prev = 0;")). The loop always runs
at least once, since `namep` is never null, and so always sets `prev`
before the store at #l("return(*prev = nscan);")\, and GCC cannot see this and would warn that it
might be used unset. The cast of `alloc`'s result to `NAMPTR` (#l("nscan=(NAMPTR)alloc(sizeof *nscan);")) is
new: `alloc` returns an `ADDRESS`, a `char *` (#f("sh/defs.h")), which
C99 does not assign to another pointer type without a cast.

#lines-to("LOCAL BOOL\tchkid(STRING nam)", lead: true)

The routine `chkid` accepts an identifier, a letter followed by letters and digits
(#f("sh/ctype.h"). The underscore is a letter there).

#lines-to("LOCAL VOID (*namfn)(NAMPTR n);", lead: true)

The routine `namscan` applies a function to every variable, by an in-order walk of
the tree, so that `set` and `export` list the variables in alphabetical
order. The function is passed to `namwalk` through the static `namfn`
rather than as an argument, which saves a word on each level of the
recursion. The prototypes of `namfn` and of `namscan`'s parameter are
new.

#lines-to("VOID\tprintnam(NAMPTR n)", lead: true)

The routine `printnam` prints `name=value` for `set`, and `sigchk` (#f("sh/error.c"))
lets an interrupt stop a long listing. The routine `staknam` builds the same string
on the stack for the environment. It assumes that no item is being
built, so that `staktop` equals `stakbot`, and then takes the string as
an item with `getstak`. The v7 code declared `staknam` in #f("sh/defs.h") as
well. Now its definition, which precedes its one use, is its only
declaration (#f("sh/defs.h")).

#lines-to("VOID\texname(REG NAMPTR n)", lead: true)

The child applies `exname` to every variable just before a
program is executed (`execa`, #f("sh/service.c")). For an exported
variable it copies the present value into `namenv`. For any other it
does the reverse, resetting `namval` to `namenv`. Since `setenv` then
passes on `namval`, the new program receives the present value of every
exported variable and the original value of every variable inherited
from the environment, but nothing set only in the shell. In v7 a
variable from the environment is passed on whether or not it is
exported. Only a change to it needs `export`. Since this happens in the
child, the shell's own values are not disturbed.

Without arguments, `export` and `readonly` use `printflg`.

#lines-to("VOID\tgetenv(void)", lead: true)

The routine `getenv` makes a variable of each entry of `environ`, which `crt0`
(#f("csu/crt0.s")) set from the arguments of `main`. It has nothing to
do with the C library's `getenv`, which looks up a single name, and
`setenv` likewise has nothing to do with any library function. An entry which does not have the form
`name=value` with an identifier for its name is fatal: `setname`
reports it, and since the flags are not yet set, `exitsh` ends the
shell (#f("sh/error.c")).

#lines-to("LOCAL INT\tnamec;", lead: true)

The routine `setenv` builds the environment for `execve` in two passes over the
tree: the first counts the variables, the second pushes a pointer to a
`name=value` string for each one which has a value. The vector, with
its terminating zero, is allocated on the stack (#l("argnam = er =")), and the count
includes variables without a value, so it may be a little larger than
needed. The cast of `getstak`'s result (#l("argnam = er =")) is new, as `getstak`
returns a `char *`.

The port makes `countnam` and `pushnam` `LOCAL`. In v7 they had external
linkage, though nothing outside this file used them. With
`-Wmissing-prototypes` an external function must have a declaration in
scope before its definition, and making them `static` was the simpler
remedy. `(void)n` tells the compiler that `countnam` ignores its
argument.

#lines-to(none)
#source("/usr/src/cmd/sh/macro.c")

Substitution. The routine `macro` takes a word as `word` left it (#f("sh/word.c"))
and returns a new string in which each `$` parameter has been replaced
by its value and each command between backquotes by its output, and
from which the double quotes have been removed. The characters which
must not be interpreted further, because they were quoted, carry the
quote bit, 0200, for the benefit of `split`, `expand`, and `trim`
(#f("sh/service.c"), #f("sh/expand.c")). The same machinery,
entered through `subst`, substitutes in the text of a here document.

The technique is to make the word the shell's input. The routine `macro` pushes a
file block whose source is the string (`estabf`, #f("sh/io.c")), and
`getch` reads it with `readc`, as though it were being typed. A
parameter's name, a default value in braces, and a command in
backquotes are thus all read by the same means, at any depth of
nesting, and the result is built on the stack.

The variable `quote` is either zero or `QUOTE`, according as a double quote is open,
and is or-ed into every character copied, and `quoted` counts the double
quotes seen. The declarations of `getch`, `comsubst`, and `flush`
(#l("LOCAL INT\tgetch(CHAR endch);"), #l("LOCAL VOID\tcomsubst(void), flush(INT ot);")) are new: they are `LOCAL` functions called before their
definitions, which C99 does not allow without a declaration.

#lines-to("LOCAL VOID\tcopyto(REG CHAR endch)", lead: true)

The routine `copyto` copies characters, substituted by `getch`, to the stack until
`endch` or the end of the input. It is used with `}` for the word of
`${name-word}`, and with a null to copy a whole string. The v7 code declared it
to return a `STRING`, though it returns nothing and no caller uses a
value. It is now `VOID`.

#lines-to("LOCAL VOID\tskipto(REG CHAR endch)", lead: true)

The routine `skipto` passes over the word of a `${...}` that is not to be used,
without substituting it. It must still recognise quotes and nested
braces, so that a `}` within them does not end the word too soon.

#lines-to("LOCAL INT\tgetch(CHAR endch)", lead: true)

The routine `getch` returns the next character of the result. Any character other
than `$`, a backquote, or a double quote (`subchar`, #f("sh/ctype.h"))
is returned as it is. The single quote is not among them: `word` has
already set the quote bit on everything between single quotes, and such
characters fail every test of #f("sh/ctype.h").

#lines-to("IF d==DOLLAR")

A `$` begins a substitution only if the next character could begin a
parameter (`dolchar`). Otherwise it is pushed back and the `$` is
returned (#l("ELSE\tpeekc=c|MARK;")). After an optional brace, there are three kinds of
parameter.

A name is collected on the stack and looked up. Since `lookup` may
allocate, which can move the stack (#f("sh/stak.h")), its start is kept
as an offset, `argp`, and turned back into an address by `absstak`.
The v7 code assigned the integer `relstak()` to the `STRING` `argp` directly.
The port casts it (#l("THEN\targp=(STRING)relstak();", after: "IF letter(c)"), #l("THEN\targp=(STRING)relstak();", after: "THEN\tIF c!='}'")). The character which ended the name is
pushed back into `peekc`, with `MARK` so that even a null is seen as
present (#f("sh/word.c")).

A digit names a positional parameter: `$0` is the name of the shell or
script, `cmdadr`, and `$1` to `$9` are taken from `dolv`, or are unset
beyond `dolc` (#f("sh/args.c")). `$*` and `$@` (the two characters of
`astchar`) are treated as `$1`, with `dolg` set so that the remaining
parameters will follow. In the conditional expression of line #l("v=((c==0) ? cmdadr : (c<=dolc) ?") v7
mixed a pointer and an integer, the value of `dolg=0`, in the two arms.
C99 requires a pointer in both arms unless the integer is a constant
zero, which an assignment is not. The cast to `STRING` is new.

The special parameters `$$`, `$!`, `$#`, `$?`, and `$-` are strings
kept up to date by the code which changes them (`assnum`,
#f("sh/name.c"); `options`, #f("sh/args.c")), so that substitution
needs no conversion.

In v7, `n` was initialised to `NIL` (#l("THEN\tNAMPTR\t\tn=0;")). `NIL` is `(char *)0`
(#f("sh/mode.h")), which C99 does not assign to a `NAMPTR`. It is now
zero. The port initialises `v` (#l("REG STRING\targp, v=0;")). Every path assigns it or
leaves by `error`, but `error` is an ordinary function, not declared
to return never, and GCC would warn that `v` might be used unset. The
parentheses at #l("IF (bra=(c==BRACE)) THEN c=readc() FI") are new.

#lines-to("c = readc();")

Within braces, the name may be followed by `-`, `=`, `?`, or `+` and a
word (`defchar` also accepts the closing brace). The word is wanted if
the parameter is unset, except after `+`, where it is wanted only if
the parameter is set; the exclusive or of line #l("THEN\targp=(STRING)relstak();", after: "THEN\tIF c!='}'") (`NEQ` is `^`,
#f("sh/mac.h")) expresses exactly this. A wanted word is copied, with
substitution, straight onto the stack at the place where the result is
being built, and so becomes part of the result without further ado;
`argp` remembers where it began. An unwanted word is skipped.

Without braces, the character after the parameter belongs to the text
and is pushed back.

#lines-to("IF v")

If the parameter is set, its value is pushed, unless `+` has supplied a
word instead. For `$*` and `$@` the loop continues through every
positional parameter, with a space between each two. The two differ
only within double quotes, and only in that space: for `"$*"` it is
quoted, so that the whole is a single word, while for `"$@"` it is not,
so that `split` will divide the result into one word per parameter, the
characters of each parameter remaining quoted. This is the whole of the
difference between the two in v7. The parentheses at #l("THEN\tLOOP WHILE (c = *v++)") are new.

If the parameter is unset, `?` prints the word, or a standard message,
and abandons the command by way of `failed`, and `=` assigns the word to the
variable, which must therefore be a name and not a digit. For `-` the
copied word is already in place. An unset parameter with no word is an
error only under `set -u` (`setflg`).

Every substitution ends by going back to `retry`: the value has been
pushed directly, and `getch` returns the next character after it.

#lines-to("ELIF d==endch")

A backquote starts a command substitution. A double quote toggles
`quote` and is itself dropped, unless it is the character the caller
is looking for. The routine `subst` makes use of this exception.

#lines-to("STRING\tmacro(STRING as)", lead: true)

The routine `macro` saves and restores `quote` and `quoted`, sets the word up as
input, and copies it whole with `copyto(0)`. A word which consisted of
double quotes and nothing more, such as `""`, would leave an empty
result, and `split` drops empty fields (#f("sh/service.c")). A single
`QUOTE` character is therefore pushed (#l("IF quoted ANDF (stakbot==staktop) THEN pushstak((char)QUOTE) FI")): it is not a separator, and
`trim` later reduces it to the empty string, so that the word survives
as an empty argument. The cast to `char` is new: `QUOTE` is 0200, which
a compiler whose `char` is signed must change to store, and the cast
says that the byte, not the number, is meant.

The input block is a `FILEHDR` rather than a `FILEBLK`, the same
structure without the buffer, which is all a string needs, since
`estabf` points the input directly at the string (#f("sh/mode.h")).
The routine `push` takes a `FILE`, a pointer to a `fileblk`, and v7 passed the address
of the `filehdr` as it was, and C99 requires the cast (#l("push((FILE)&fb); estabf(as);")).

#lines-to("LOCAL VOID\tcomsubst(void)", lead: true)

The routine `comsubst` runs the command between backquotes and substitutes its
output. The part of the result built so far is first made a permanent
item with `fixstak`, and `savptr` remembers it. The text of the command
is read up to the closing backquote into a new item. The routine `trim` removes the quote bits which `word` set on its escaped characters, and the text is pushed as a new input string.

#lines-to("BEGIN", after: "END")

The routine `cmd` parses the whole string (#f("sh/cmd.c")) and wrapped in a
fork node whose output is a pipe (`FPOU`). As the comment says, the pipe
is made only after the command has been parsed. A syntax error leaves by
a jump to the command loop, and in that case no descriptors are left
open. The input block, which held the string, is then pointed at the
reading end of the pipe (`initf`, #f("sh/io.c")). The routine `execute`
(#f("sh/xec.c")) forks the child, which runs the command with its
standard output on the pipe, records its process id with `post`, and,
because of `FPOU`, returns at once. The shell closes its copy of the
writing end, without which it would never see the end of the output
(`readp`, #f("pipe.c")).

The parse tree, which lay on the stack above `savptr`, is no longer needed in the shell, and `tdystak` discards it. The partial result
saved at `savptr` is copied back into place as the current item, and
the output of the command is appended to it, a character at a time,
through `readc`. Only after the end of the output does the shell wait
for the child (`await`, #f("sh/service.c")). The order matters: a pipe
holds at most `PIPSIZ` bytes (#f("pipe.c")), and a child with more to
say would block forever if the shell waited for it first. Trailing
newlines are then removed from the result, and `pop` restores the
input. The routine `readc` closed the reading end of the pipe when it met the end of the output (#f("sh/word.c")).

The parentheses at #l("WHILE (d=readc()) DO pushstak(d|quote) OD") are new.

#lines-to("#define CPYSIZ\t512", lead: true)

The routine `subst` copies a here document from the descriptor `in` to `ot`,
substituting parameters and commands (`initio`, #f("sh/service.c")).
It calls `getch` with `DQUOTE` as the character it wants, so that a
double quote is returned as an ordinary character and quoting is never
switched on: within a here document `$` and backquotes are
interpreted but double quotes are not. The quote bits are stripped
from the result, which is written in pieces of `CPYSIZ` bytes from the
stack. With `-x` the substituted text is shown on the diagnostic output
as well. The parentheses at #l("WHILE (c=(getch(DQUOTE)&STRIP))") are new.

#lines-to(none)
#source("/usr/src/cmd/sh/expand.c")

File name generation. The routine `split` (#f("sh/service.c")) offers each field of
a substituted word to `expand`, which, if the field contains an
unquoted `*`, `?`, or `[`, replaces it by the names of the existing
files which match, and returns their number. If it returns zero, the
field stands for itself. The routine `gmatch` does the matching, for `expand` and
for the patterns of `case` (#f("sh/xec.c")).

The v7 library has no routine to read a directory. A program which wants
the names in one opens the directory and reads it as an ordinary file,
in entries of 16 bytes: an inode number and a name of at most 14
characters, not terminated by a null when it is 14 long (#f("dir.h")).
The shell defines `DIRSIZ` as 15 before it includes `sys/dir.h` (#l("#define DIRSIZ 15")),
whose `#ifndef` then leaves it alone, so that `entry` has a fifteenth
character after the name. The reads (#l("WHILE read(dirf, (char *)&entry, 16) == 16 ANDF")) fill only the first 16 bytes
of the structure. The fifteenth character, cleared once at line #l("s=cs=as; entry.d_name[DIRSIZ-1]=0; /* to end the string */"),
stays zero and terminates every name.

The declaration of `addg` (#l("LOCAL VOID\taddg(STRING as1, STRING as2, STRING as3);")) was `PROC`, that is `extern`, in v7. It
is now `LOCAL`, to agree with the definition, and has a prototype.

#lines-to("INT\texpand(STRING as, INT rflg)", lead: true)

The field is first scanned for a metacharacter (`fngchar`,
#f("sh/ctype.h")). Quoted characters carry the quote bit and fail the
test, so a quoted `*` is never a pattern. A field without a
metacharacter is returned at once with zero, except in a recursive call
for the remainder of a pattern (`rflg`, below): there a remaining
component such as the `x` of `*/x` must still be looked up, so that
only names which exist are produced.

A non-zero `trapnote&SIGSET` (#l("IF trapnote&SIGSET THEN return(0); FI")) means that an interrupt has arrived without a
trap. The expansion is abandoned, and `sigchk` will deal with it.

#lines-to("LOOP\tIF cs==s", lead: true)

The pattern is divided at the last `/` before the first metacharacter:
`s` becomes the directory to search, `cs` the component to match.
The `/` is overwritten by a null, so that `s` is a string by itself, or
`s` becomes `/` if the pattern began there, or the empty string if the
pattern contained no `/` before the metacharacter. An empty name refers
to the current directory (`namei`, #f("nami.c")). The directory is
examined with `stat` and opened for reading. The v7 code took only a descriptor
above 0 as success. With the standard input closed, `open` returns 0,
and the pattern then matched nothing and the directory stayed open as
the standard input of later commands. The port accepts 0 (#l("ANDF (dirf=open(s,0))>=0")).

The null which divided the two is then replaced by `0200` (#l("IF *cs==0 THEN *cs++=(char)0200 FI")), a
character which is not a null but whose seven bits are zero, and `cs`
moves past it. The value is cast to `char`, as `QUOTE` is in
#f("sh/macro.c"). The directory part thus remains distinguishable for
`addg`, which stops at it, while the word as a whole stays one string,
to be repaired at the end.

#lines-to("IF dir")

If the component is followed by further components, as in `*/*.c`, the
pattern is cut again at the next `/` (`rescan`), and the matches of
this level are collected on a chain of their own, `gchain` being set to
zero for the purpose.

The directory is read entry by entry. An entry with a zero inode number
is empty. A name beginning with `.` is matched only by a component
which itself begins with `.`. This keeps `.` and `..`, and the files
which users choose to hide, out of the expansion of `*`. Each name that
matches is added to the chain by `addg`. The cast of `&entry` to
`char *` (#l("WHILE read(dirf, (char *)&entry, 16) == 16 ANDF")) is new: `read` has a prototype (#f("sh/defs.h")), and C99
does not convert a pointer to a structure to a `char *` without a cast.

In the rescan case, each path just made, a directory name followed by
the rest of the pattern, is expanded in turn by a recursive call with
`rflg` set, and the results are added to the original chain `schain`.
The paths of the intermediate level are abandoned on the stack, to be
freed with the rest of the command. The count returned is that of the
final names.

#lines-to("BEGIN", lead: true)

The original word is repaired, every character whose seven bits are
zero becoming `/` again. The routine `split` may yet use the word itself, when
nothing matched. The names are not sorted here, and `scan` sorts each
group of names as it builds the argument list (#f("sh/service.c")).
The parentheses at #l("WHILE (c = *s)") are new.

#lines-to("INT", lead: true)

The routine `gmatch` matches the string `s` against the pattern `p`, recursively,
one character of each at a time. It knows nothing of `/` or of a
leading `.`, and `expand` applies it to one component at a time.

A character of the string whose seven bits are zero, the lone `QUOTE`
which `macro` leaves for an empty quoted word (#f("sh/macro.c")), is
made `0200`, so that it is not taken for the end of the string.

In a class `[...]`, a character matches itself and `a-z` matches the
range, and `lc`, the previous character, starts at a value no character can
reach, so that a leading `-` matches nothing. Each character of the
pattern is compared with its quote bit stripped. In v7 the upper bound
of a range was not: in `[a-'c']`, the quoted `c` is `0343`, and on the
ARM, where `char` is unsigned, every character from `a` upward would
fall within the range, while on the PDP-11, where it was negative, none
did. The port masks it with `STRIP` (#l("THEN\tIF lc<=scc ANDF")), like the others. The v7 shell has no negated class.

#lines-to("default:", lead: true)

An ordinary character must equal the character of the string. Quoted,
it still matches only itself, after `STRIP`. If it does, the case falls
into that of `?`, which matches any one character. The comment
`/* fallthrough */` (#l("/* fallthrough */")) is new, and tells GCC that the fall is
intended. A `*` at the end of the pattern matches whatever remains.
Elsewhere every suffix of the string, including the empty one, is tried
against the rest of the pattern. The end of the pattern matches only
the end of the string.

#lines-to("LOCAL VOID\taddg(STRING as1, STRING as2, STRING as3)", lead: true)

The routine `addg` builds a new argument on the stack, leaving room for the link
before it (`argnod`, #f("sh/mode.h")): the directory part up to the
`0200` marker, with a `/` in its place; the matched name; and, if there
is a rescan, a `/` and the rest of the pattern. The routine `makearg` puts it on
`gchain`. The cast of `endstak`'s result to `ARGPTR` (#l("makearg((ARGPTR)endstak(s2));")) is new.

#lines-to("VOID", lead: true)

The v7 code declared the parameter of `makearg` as a `STRING` and applied
`->argnxt` to it, which its compiler allowed. It is now an `ARGPTR`.

#lines-to(none)
#source("/usr/src/cmd/sh/args.c")

The options and the positional parameters. The routine `options` interprets the
flags given to the shell on its command line (#f("sh/main.c")) or to
`set` (#f("sh/xec.c")). The positional parameters `$1`, `$2`, ... are
kept in a vector on the heap, `dolv`, of which `dolc` counts the
members after `$0`. A `for` loop without `in` iterates over this vector
while its body may replace it with `set`, and the use counts of this
file let the two coexist.

The declaration of `copyargs` (#l("LOCAL STRING *copyargs(STRING from[], INT n);")) was `PROC`, that is `extern`, in v7.
It is now `LOCAL`, to agree with the definition, and has a prototype.

The parallel tables `flagchar` and `flagval` hold the option letters and
their bits in `flags` (#f("sh/defs.h")). The variable `flagadr` holds the string
`$-`, the letters of the options in force. It has room for all ten
letters and the null, and v7 gave it ten bytes, so that with every option
set the null was stored one byte past its end.

#lines-to("/* ========\toption handling\t======== */")

If the first argument begins with `-`, each of its letters is looked up
in `flagchar` and its bit set. `-x` and `-v` are first cleared (#l("flags &= ~(execpr|readpr);")), so
that `set -` turns both off. No other option can be turned off once it
is on. `-c` takes the next argument as the command string, `comdiv`,
and only once (#f("sh/main.c")). Each argument consumed is removed by
moving `argv[0]` up one place over it (#l("argp[1]=argp[0]; argp++; argc--;"), #l("argp[1]=argp[0]; argc--;")), so that the caller
finds `$0` followed by what is left, and the new count is returned. The routine `failed` reports an unknown letter (#f("sh/error.c")).

#lines-to("/* set up $- */", lead: true)

`$-` is then rebuilt from the flags.

#lines-to("VOID\tsetargs(STRING argi[])", lead: true)

The routine `setargs` makes a vector of new positional parameters, from the
arguments of `set`, or from those of a command file run by
`execs` (#f("sh/service.c")). The old vector `dolh` is released first:
`freeargs` frees it only if no `for` loop is using it.

The end of an argument vector is a null pointer, `ENDARGS`, and
`Rcheat` (#f("sh/mode.h")) converts the pointer to an `int` for the
comparison, a habit of the shell's which costs nothing on a machine
whose pointers fit in an `int`.

The cast of `copyargs`' result to `DOLPTR` (#l("dolh=(DOLPTR)copyargs(argi,argn);\t/* sets dolv */")) is new.

#lines-to("DOLPTR", lead: true)

The routine `freeargs` drops one reference to a parameter block and returns the
next block on the chain `argfor`. When the count reaches zero the
strings and the block are freed. The parentheses at #l("IF (argblk=blk)") are new, and
the cast at #l("THEN	FOR argp=(STRING *)argblk->dolarg;") is new.

#lines-to("LOCAL STRING *\tcopyargs(STRING from[], INT n)", lead: true)

The vector of parameters is a `dolnod` (#f("sh/mode.h")), with a link `dolnxt`, a use count `doluse`, and then the strings themselves,
starting at `dolarg`, which is declared as an array of one `char`,
a placeholder for the start of a variable-length array of `STRING`s.
Since it follows two words, it is suitably aligned for pointers on both
machines. The routine `copyargs` allocates the two words of the header, `n`
pointers, and one more word for `ENDARGS`, which accounts for the
`3*BYTESPERWORD`. Each string is copied with `make`. The routine then points `dolv`
at the first string, so that `dolv[1]` is `$1`. The function returns
the address of the block as a `STRING *`, which is how `np` was
allocated.

The v7 code treated `np`, a `STRING *`, as a `DOLPTR` where it suited it,
writing `np->doluse` and `np->dolarg` and assigning the result to
`dolh`. Its compiler allowed `->` on any pointer, and any pointer to be
assigned to any other. C99 allows neither, and the port casts between
the two types at each such place (#l("dolh=(DOLPTR)copyargs(argi,argn);\t/* sets dolv */"), #l("((DOLPTR)np)->doluse=1;\t/* use count */"), #l("np=(STRING *)((DOLPTR)np)->dolarg;")), as it does where a
`char *` becomes a `STRING *` (#l("THEN\tFOR argp=(STRING *)argblk->dolarg;"), #l("REG STRING *\tnp=(STRING *)alloc(sizeof(STRING*)*n+")). The layout is unchanged.

#lines-to("VOID", lead: true)

The shell calls `clearup` after an error (`exitsh`, #f("sh/error.c")) and
before a command file is run (`execs`): it releases the parameter
blocks held by `for` loops which will never finish, and pops every
input file, closing their descriptors.

Called by `for` (#f("sh/xec.c")), `useargs` adds a reference to the
present parameters and links them on `argfor`. If the body of the loop
then does `set`, `setargs` replaces `dolh`, but the old block survives
with the loop's reference until the loop ends and calls `freeargs`.
The parentheses at #l("WHILE (argfor=freeargs(argfor)) DONE") are new.

The test at #l("IF dolh!=argfor THEN dolh->dolnxt=argfor FI") is new. A `for` without a list inside another such loop
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

#lines-to(none)
#source("/usr/src/cmd/sh/print.c")

The shell's output routines, and its conversions between numbers and
strings. The shell does not use the standard I/O library
(#f("stdio.h")), whose buffers and code it does not need. Every message
is written directly with `write` to `output`, the shell's diagnostic
descriptor, a copy of descriptor 2 (#f("sh/main.c")).

The buffer `numbuf` holds the result of `itos`. The routine `prp` begins a diagnostic: a shell
which does not prompt, because it is not interactive, names itself
(`cmdadr`, which is `$0`) before the message, so that the user can tell
which script failed.

#lines-to("VOID\tprs(STRING as)", lead: true)

The routine `prs` writes a string. The routine `length` (#f("sh/string.c")) counts the
terminating null, hence the `-1`. The routine `prc` writes a single character, and
ignores a null. The parentheses at #l("IF (s=as)") are new.

#lines-to("VOID", lead: true, after: "THEN\twrite(output,&c,1);")

The routine `prt` prints a time given in ticks, for `times` (#f("sh/xec.c")),
rounded to the nearest second, as hours, minutes, and seconds. The
divisor 60 is the clock rate of v7's PDP-11, which `HZ` (#f("param.h"))
keeps on the ARM, so the figures remain correct. The parentheses at #l("IF (hr=t/60)")
are new.

#lines-to("VOID", lead: true, after: "}")

The routine `itos` converts a number to decimal, without leading zeros, by dividing
by powers of ten in turn, down to 10, and `pr` turns true at the first
nonzero digit. The number is taken as unsigned (`POS`). On the PDP-11
an unsigned `int` stopped at 65535, and v7 began at 10000, with room in
`numbuf` for five digits and the null. On the ARM an `INT` has up to
ten digits, so the division begins at 1000000000 (#l("FOR i=1000000000; i!=1; i/=10")) and `numbuf` (#l("CHAR\t\tnumbuf[11];"))
has room for ten and the null. With v7's figures a number of 100000 or
more put a character other than a digit in the first place: a syntax
error at line 100002 of a command file was reported at line `:0002`.

#lines-to("INT", lead: true)

The routine `stoi` converts a string of digits, for `exit`, `break`, and `trap`,
and for the descriptor in a redirection such as `>&2`
(#f("sh/service.c")). A string that does not begin with a digit is reported as a bad
number. The test `r>=0` stops the conversion when the number
overflows. The v7 code relied on the overflow wrapping to a negative value, as
it did on the PDP-11. In C99 the overflow of a signed integer is
undefined, and the test could not be counted on. The step (#l("DO r = r <= ((INT)(~0u>>1) - (c - '0'))/10 ? r*10 + c - '0' :")) now
asks first whether one more digit fits: `(INT)(~0u>>1)` is the largest
`INT`, and a value `r` may take the digit if `r*10` plus it does not
exceed that, that is, if `r` is at most the largest less the digit,
divided by ten. If not, `r` is set to -1, which ends the loop and
reports the bad number as before. Nothing ever overflows.

The statement `return(0)` (#l("return(0);")) is new. The routine `failed` never returns, but nothing tells the
compiler so (the port does not use GNU's `noreturn` attribute), and
without it control appears to reach the end of a function which returns
a value, of which GCC warns.

#lines-to(none)
#source("/usr/src/cmd/sh/string.c")

Four string routines, used throughout the shell in place of those of
the C library.

The routine `movstr` copies `a` to `b` and returns the address of the null it
stored, not of the start, so that copies may be chained, each
continuing where the last ended, and `staknam` (#f("sh/name.c")) builds
`name=value` with three calls in a row. The parentheses at #l("WHILE (*b++ = *a++) DONE") are new.

#lines-to("INT\tany(REG CHAR c, STRING s)", lead: true)

The routine `any` tells whether `c` occurs in `s`. When `split` (#f("sh/service.c"))
asks whether a character is one of `$IFS`, a quoted character still
carries the quote bit and so equals none of them: this is how a quoted
blank is kept within a word. The parentheses at #l("WHILE (d = *s++)") are new.

The routine `cf` compares two strings and returns zero if they are equal, or the
difference of the first two characters that differ, whose sign gives
their order. It orders the variables' tree (`lookup`, #f("sh/name.c")),
and the generated file names (`gsort`, #f("sh/service.c")), and through
the macro `eq` (#f("sh/defs.h")) it serves every test of equality.
Since `char` was signed on the PDP-11 and is unsigned on the ARM, a
character with its top bit set sorted before all of ASCII there and
sorts after it here. Names of variables are ASCII, so only a file name
containing such a byte can show the difference.

#lines-to("INT\tlength(STRING as)", lead: true)

The routine `length` returns the size of a string including its terminating null,
which is the number of bytes needed to copy it (`make`,
#f("sh/name.c")), and one more than the number to write (`prs`,
#f("sh/print.c")). It returns zero for a null pointer. The parentheses
at #l("IF (s=as) THEN WHILE *s++ DONE FI") are new.

#lines-to(none)

= Part Three: The Library

== Headers <ch-headers>

#source("/usr/include/stdio.h")

The standard input-output package is the part of the library which
nearly every command uses, and #f("stdio.h") is its interface. The
package interposes a buffer between the program and the system calls
`read` and `write` (#f("rdwri.c")), so that a program which takes or
gives one character at a time pays for a system call only once per
`BUFSIZ` characters. `BUFSIZ` (#l("#define\tBUFSIZ\t512")) is 512, the size of a disk block, so
that a full buffer is one transfer for the buffer cache (#f("bio.c")).

A stream is an entry of the array `_iob`, of which there are `_NFILE`
(#l("#define\t_NFILE\t20")), the same number as the open files a process may have (`NOFILE`,
#f("param.h")). Each entry holds a pointer to the next character in the
buffer (`_ptr`), a count (`_cnt`) of the characters which remain to be
read from the buffer or the room which remains for writing, the address
of the buffer (`_base`), the flags, and the file descriptor. The test
`ifndef FILE` (#l("# ifndef FILE")) lets a program declare the structure in its own way.
None in this system does. The storage for `_iob` and for the buffers of
the standard input and output is in `data.c`, which initialises the first
three entries.

The fields `_flag` and `_file` are `char`. On the PDP-11 `char` was
signed and on the ARM it is unsigned. `_file` never exceeds 0177, and
the flags fit in eight bits, and `_IORW` (0200) makes `_flag` negative on
the PDP-11, but the flags are only ever tested and changed by masks, on
which the sign has no effect.

#lines-to("#define\t_IOREAD\t01", lead: true)

The flags. `_IOREAD` and `_IOWRT` record the direction, and `_IORW` marks a
stream opened for both (mode `"r+"` and the like), on which the first operation decides the direction and `fseek` changes
it.
`_IONBF` means unbuffered, `_IOMYBUF` that the buffer was obtained from
`malloc` and must be freed, `_IOSTRG` that the "file" is a string in
memory (`sprintf` and `sscanf`), and `_IOEOF` and `_IOERR` record the
conditions which `feof` and `ferror` report.

The macros `getc` and `putc` (#l("#define\tgetc(p)\t\t(--(p)->_cnt>=0? *(p)->_ptr++&0377:_filbuf(p))"), #l("#define putc(x,p) (--(p)->_cnt>=0? ((int)(*(p)->_ptr++=(unsigned)(x))):_flsbuf((unsigned)(x),p))")) are the heart of the package. Each
decrements the count; while the count stays non-negative it simply
takes or stores a character at `_ptr`, and only when the buffer is
exhausted does it call `_filbuf` or `_flsbuf` (#f("stdio/filbuf.c"),
#f("stdio/flsbuf.c")) to refill or empty it. The macro `getc` masks the character
with `0377`, so that a byte of 0377 is not mistaken for `EOF`; this was
essential with the PDP-11's signed `char` and is harmless with the ARM's
unsigned one. Likewise `putc` yields the stored character as the
unsigned value of a `char`.

#lines-to("FILE\t*fopen(char *file, char *mode);", lead: true)

In v7 the header declared only the five functions which return
something other than an `int`, which K&R C assumed for anything
undeclared. Every other function, and every system call, was simply
called. C99 forbids a call to an undeclared function, and the port is
compiled with `-Wstrict-prototypes` and `-Wmissing-prototypes`, so every
function must be declared with a prototype before it is used or
defined. The v7 system had no `unistd.h`, `stdlib.h`, or `string.h` in which such
declarations belong, and nearly every program includes #f("stdio.h"), so the prototypes of the whole library are collected here. They cover the stdio functions, the system call stubs (`read`, `fork`, `kill`, and so on),
the string routines, `malloc` and its relatives, the time conversions,
and the rest. The declarations of `stat`, `times`, `ftime`, `gtty`, and
`stty` are instead kept beside their structures in their own headers,
and `signal` in `signal.h`.

The routines `time`, `stime`, `utime`, `localtime`, `gmtime`, and `ctime` (#l("utime(char *file, long long *timep);"), #l("stime(long long *tp);"),
#l("long long\ttime(long long *tloc);"), #l("struct\ttm *localtime(long long *tim), *gmtime(long long *tim);"), #l("char\t*ctime(long long *t), *asctime(struct tm *t), *gets(char *s);")) take or return a `long long`, where v7's took a `long`:
`long long` is the port's `time_t` (#f("param.h")), which the header
cannot name, since it is defined in `<sys/types.h>`, which many
programs do not include. The routine `time` has a line of its own (#l("long long\ttime(long long *tloc);")) for its
result type.

The argument and result types are v7's own, not those of later
standards. The routine `sprintf` (#l("char\t*sprintf(char *str, char *fmt, ...);")) returns its first argument, a `char *`;
`malloc` (#l("char\t*malloc(unsigned n), *realloc(char *p, unsigned n);")) returns `char *` and takes an `unsigned`; `index` and
`rindex` (#l("char\t*index(char *sp, char c), *rindex(char *sp, char c);")) take the character as a `char`; `sleep` and `putw` (#l("void\tsleep(unsigned n), putw(int i, FILE *iop);"))
return nothing, as their v7 definitions did. The routine `ioctl` (#l("int\tsync(void), kill(int pid, int sig), alarm(unsigned sec),")) takes a
`void *` because its callers pass a pointer to whichever structure the
request needs. The routines `exit`, `_exit`, and `abort` (#l("void\texit(int status), _exit(int status), abort(void),")) are declared as plain
`void` functions, since the `noreturn` attribute is not C99. The
variadic functions, `printf` and `scanf` and their relatives and `execl`
and `execlp` (#l("int\tprintf(char *fmt, ...), fprintf(FILE *iop, char *fmt, ...);")--#l("char\t*sprintf(char *str, char *fmt, ...);")), are declared with `...`. Their definitions use
`stdarg.h` (#f("stdio/printf.c")).

The routines `profil` and `monitor` (#l("void\tprofil(short *buf, int bufsiz, int offset, int scale);"), #l("void\tmonitor(char *lowpc, char *highpc, short *buf, int bufsiz,")), which v7 left undeclared, start and
stop the kernel's sampling of the program counter and keep the counts
of a profiled program (#f("gen/mon.c")).

The variable `environ` (#l("extern char **environ;")) is defined in #f("csu/crt0.s"), and the declaration lets the
`exec` routines and `getenv` find it.

#lines-to(none)
#source("/usr/include/sys/types.h")

The header #f("sys/types.h") names the types in which the system's interfaces are
written, for programs, which include it before the other headers of
`<sys/>`. The kernel defines the same types in #f("param.h"). Three
have changed from v7. The type `time_t` is the port's 64-bit time (#l("typedef\tlong long\ttime_t;   \t/* a time */")). The type `ino_t`
is written `unsigned short` (#l("typedef\tunsigned short\tino_t;     \t/* i-node number */")), the 16 bits which v7's `unsigned int`
was on the PDP-11 and which an inode number in a directory entry
holds. The type `label_t`, the registers that `save` and `resume` keep
(#f("mch.s")), has ten words, for `r4` to `r11`, the stack pointer, and
the link register (#l("typedef\tint        \tlabel_t[10]; \t/* program status */")), where v7 kept six.

#lines-to(none)
#source("/usr/include/sys/param.h")

The header #f("sys/param.h") is the kernel's #f("param.h") for programs that read
kernel structures, such as `ps` and `pstat`, which must agree with the
kernel on the sizes of its tables. It is the same file but for one
guard: `NULL` is defined only if not already defined (#l("#ifndef NULL")--#l("#endif")), since a
program may include `<stdio.h>`, which defines it too, before it. The
kernel includes no `<stdio.h>`, and its copy needs no guard.

#lines-to(none)
#source("/usr/include/sys/stat.h")

The calls `stat` and `fstat` return a `struct stat`, the parts of an inode
a program may see (#f("sys2.c")). The mode bits give the file's type,
in the field `S_IFMT`, and its permissions. The kernel's copy
(#f("stat.h")) is the same but for the last line (#l("int\tstat(char *name, struct stat *buf),")), which declares
the two calls for programs.

#lines-to(none)
#source("/usr/include/sys/times.h")

The call `times` fills a `struct tms` with the user and system time of the
process and of its waited-for children, in clock ticks
(#f("sys4.c")). The fields are `time_t`s, and so 64 bits wide. The
declaration of `times` (#l("int\ttimes(struct tms *buf);")) is new, since every program calling it
includes this header.

#lines-to(none)
#source("/usr/include/sys/timeb.h")

The call `ftime` gives the time with its milliseconds, and the local time zone
in minutes west of Greenwich and whether daylight saving time applies,
as `TIMEZONE` and `DSTFLAG` set them in #f("param.h"). The command `date` and the
library's `ctime` use it. Its declaration (#l("int\tftime(struct timeb *tp);")) is added here, as for
`times`.

#lines-to(none)
#source("/usr/include/time.h")

In the `struct tm`, which `localtime` and `gmtime` (#f("gen/ctime.c")) fill in,
the year is counted from 1900 and kept modulo 10000.

#lines-to(none)

#source("/usr/include/errno.h")

The error numbers which a failing system call leaves in `errno` are
v7's and the kernel's (#f("user.h")). The one addition is the
declaration of `errno` itself (#l("extern int errno;")). The v7 system left each program to declare it,
and the libraries defined it in every file which set it, relying on the
loader to merge the copies. Here it is defined once, in
#f("libc/syscall.s").

#lines-to(none)

#source("/usr/include/signal.h")

The routine `signal` is
declared with its prototype: it takes a signal number and a function
taking the signal number, and returns the previous such function. The v7 declaration
`int (*signal())()` gave handlers no parameters and an `int` result.
`SIG_DFL` and `SIG_IGN` are cast to the same type. The signals beyond 15
have no names.

#lines-to(none)

#source("/usr/include/setjmp.h")

A `jmp_buf` holds what `setjmp` (#f("gen/setjmp.s")) saves, the registers `r4` to `r11`, the stack pointer, and the return address, ten words,
and the floating point registers `d8` to `d15`, which the ARM's calling
convention also asks a function to preserve, sixteen words more. The three words of v7
held the PDP-11's frame pointer, stack pointer, and return
address. The prototypes are new.

#lines-to(none)

#source("/usr/include/sgtty.h")

The terminal modes, kept in `struct sgttyb` by `gtty` and `stty`, are
v7's, with the ioctl requests of #f("tty.c") and #f("tty.h"). The
prototypes of `gtty` and `stty` (#l("int\tgtty(int fd, struct sgttyb *ap),")) are new.

#lines-to(none)

#source("/usr/include/ctype.h")

The classifying macros look a character up in `_ctype_`
(#f("gen/ctype_.c")), indexed from its second entry so that `EOF`, $-1$,
finds the first. Each argument is now masked to a byte (#l("#define\tisalpha(c)\t((_ctype_+1)[(c)&0377]&(_U|_L))")--#l("#define iscntrl(c)\t((_ctype_+1)[(c)&0377]&_C)")), so
that a character above 127 indexes inside the table, which now has
room for 256. On the PDP-11 such a `char` was negative and indexed
before it. As in v7, `toupper` and `tolower` do no test: they are
only for a character known to be of the right case.

#lines-to(none)
#source("/usr/include/math.h")

The mathematical routines of `libm` are declared with prototypes, and
The header adds `modf` and `frexp`, which are in the C library (#l("extern double modf(double value, double *iptr),")). It declares `fmod`
and `gamma` because v7's header declared them, although
neither v7's `libm` nor this one supplies them.

`HUGE` is the largest IEEE double, which the ARM's floating point
represents, and v7's value was the largest number of the PDP-11's format.
`LOGHUGE` is its decimal exponent.

#lines-to(none)

#source("/usr/include/pwd.h")

The fields of a line of `/etc/passwd` (#f("passwd")), as
#f("stdio/getpwent.c") unpacks them. The prototypes of the routines which read
the file (#l("struct\tpasswd\t*getpwent(void), *getpwuid(int uid),"), #l("void\tsetpwent(void), endpwent(void);")) are new.

#lines-to(none)

#source("/usr/include/grp.h")

The fields of a line of `/etc/group` (#f("group")). The members are an
array of names ended by a null pointer. The prototypes (#l("struct\tgroup\t*getgrent(void), *getgrgid(int gid),"), #l("void\tsetgrent(void), endgrent(void);")) are new.

#lines-to(none)

#source("/usr/include/utmp.h")

`/etc/utmp` holds one such record for each terminal on which a user is
logged in, and `/usr/adm/wtmp` a record for each login and logout.
When `ut_line` and `ut_name` are full they are not terminated, so
programs copy and compare them with a length (#f("cmd/wall.c")). The
time has 64 bits (`types.h`), which makes the record 24 bytes. It is
therefore not v7's format.

#lines-to(none)

#source("/usr/include/a.out.h")

The PDP-11's executable format, the `a.out` header, no longer
describes any program on the system, whose executables are ELF files
(#f("sys1.c")). Nothing uses `struct exec` or its magic numbers now.
The header is kept for `struct nlist`, through which `nlist`
(#f("gen/nlist.c")) returns the addresses of named kernel symbols to
`ps`, `pstat`, and `iostat`, and `nlist`'s declaration (#l("int\tnlist(char *name, struct nlist *list);")) is new.

#lines-to(none)
#source("/usr/include/ar.h")

The header of each member of an archive, as `ar` writes and `ld` would
read it. The member's date is a `long long` (#l("long long\tar_date;")), the port's `time_t`,
so the archive format is no longer v7's, and `arcv` (#f("cmd/arcv.c"))
converts an archive of the older kinds, filling in the wider date.

#lines-to(none)
#source("/usr/include/execargs.h")

The shell stores a pointer to its arguments at the top of its stack,
through `execargs` (#f("sh/main.c")), so that `ps` can show what
script a shell is running. On the PDP-11 the top word was at $-2$, the
last two bytes of the 64 KB address space. Here the user's space ends
at `USRSIZE` (#f("param.h")), and the top word is four bytes below it.

#lines-to(none)
#source("/usr/include/dumprestor.h")

The programs `dump`, `restor`, and `dumpdir` share the format of a dump tape: each
record begins with a `spcl` header of type `TS_TAPE`, `TS_INODE`, and
so on, carrying the inode it describes and a map of which of its blocks
follow. The header is v7's. The dates in it and in `idates`, the record
of past dumps in `/etc/ddate`, are `time_t`s and so 64 bits wide, which
changes the format along with the inode (#f("ino.h")).

#lines-to(none)
#source("/usr/include/tp_defs.h")

This header defines the defaults of `tp` (#f("tp/tp0.c")), so that each
installation could change them. They are the magnetic tape and DECtape
devices, the default flag, and the two boot programs which `tp` wrote
at the start of a tape. The header is v7's. The system has no tape
drive, so the device names matter only to a tape file named on the
command line.

#lines-to(none)

== Standard I/O <ch-stdio>

#source("/usr/src/libc/stdio/filbuf.c")

The macro `getc` calls `_filbuf` (#f("stdio.h")) when the buffer of an
input stream is empty. It refills the buffer with one `read` and
returns the first character, or `EOF`.

A stream opened for both reading and writing becomes a reading stream
(#l("if (iop->_flag & _IORW)", after: "static char smallbuf[_NFILE];")). A stream not open for reading, or a string being read by
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
file, or -1 on error. The count is decremented at once (#l("if (--iop->_cnt < 0) {")) for the
character about to be returned, so the two failures arrive as -1 and
-2. The first sets `_IOEOF`, the second `_IOERR`. A read-write stream at
its end drops `_IOREAD`, so that the next `putc` may turn it round.

The macro `fileno` yields the `char` `_file`, and GCC objects to a `char` used as
a subscript (`-Wchar-subscripts`, part of `-Wall`), since a signed
`char` could index before the array. The mask `0377` (#l("iop->_base = &smallbuf[fileno(iop)&0377];")) is
the port's: it makes the index an `int` and non-negative whatever the
signedness of `char`, which the port does not leave to a compiler
option. The return (#l("return(*iop->_ptr++ & 0377);")) masks the character in the same way as `getc`.
The local declaration of `malloc` in v7 is gone, since #f("stdio.h") now declares
it.

#lines-to(none)
#source("/usr/src/libc/stdio/flsbuf.c")

This is the output half of the package. The routine `putc`
(#f("stdio.h")) calls `_flsbuf` when the buffer is full, `fflush`
writes out what has been collected, `exit` calls `_cleanup`, and
`fclose` closes a stream.

`_flsbuf` is entered with the character `c` that would not fit. A
read-write stream becomes a writing stream and forgets any end of file.
An unbuffered stream writes the character alone, with its count left at
zero so that every `putc` comes here again.

A stream without a buffer gets one at its first character. The
standard output is treated specially: if it is a terminal it is made
unbuffered, so that output appears as it is produced, and otherwise it
uses the static `_sobuf` of `data.c`. Other streams get `BUFSIZ` bytes
from `malloc`, or become unbuffered if there are none. With a buffer in
hand, whatever it holds is written (#l("} else if((rn = n = iop->_ptr - base) > 0) {")--#l("}", after: "n = write(fileno(iop), base, n);")), and `c` becomes the first
character of the emptied buffer, with room for `BUFSIZ`-1 more. Note
that the standard error is unbuffered from the start (`data.c`), so
that diagnostics are never held back.

The count `rn` is the number of bytes meant to be written and `n` the number
written. Any difference is an error. The copy `c1` (#l("c1 = c;")) exists because `write`
needs the address of a byte, and `c` is an `int`.

#lines-to("int", lead: true, after: "}")

The routine `fflush` writes the contents of the buffer of a buffered output stream
and resets the pointer and count. It does nothing to an unbuffered
stream or to one being read.

#lines-to("/*", lead: true)

`_cleanup` closes every stream, and so flushes every buffer, when the
program calls `exit` (`cuexit.c`, whose `exit` calls `_cleanup` and then
`_exit`). A program which ends with `_exit`, as a child of `fork` usually
should, leaves its buffers unwritten. A buffer inherited from the parent
would otherwise be written twice. `_cleanup` gains `void` in both its
return and its argument list, as the prototype requires.

#lines-to("int", lead: true)

The routine `fclose` flushes and closes the file, then frees and forgets a buffer
obtained from `malloc`, and forgets the one-byte buffer of an
unbuffered stream. A static buffer, from `data.c` or `setbuf`, stays
attached for the next use of the stream. A string stream is
left alone, since it has no file. Finally every flag is cleared.

The cast (#l("(char)~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|")) is new. The complement of all eight flags is the `int`
`~0377`, -256, and GCC, seeing that `_flag & -256` must be zero for any
`char` `_flag`, warns that the conversion back to `char` changes the
value (`-Woverflow`). With `-Werror` the warning is fatal. Casting the
mask to `char` makes it 0 before the `&=`, which states the same effect
without the conversion, and keeps v7's `&=`.

#lines-to(none)
#source("/usr/src/libc/stdio/data.c")

The file `data.c` defines the table of streams, `_iob`, with its first three entries set up. The standard input has the static buffer `_sibuf`. The standard output
is given `_sobuf` when it is first written if it is not a terminal
(#f("stdio/flsbuf.c")), and the standard error is unbuffered. The
entry `_lastbuf` marks the end of the table.

#lines-to(none)
#source("/usr/src/libc/stdio/findiop.c")

`_findiop` finds a free entry in `_iob` for `fopen` and `fdopen`, one
which is neither reading nor writing, or returns null when all
`_NFILE` are in use.

#lines-to(none)
#source("/usr/src/libc/stdio/rdwr.c")

The routines `fread` and `fwrite` move `count` items of `size` bytes, a byte at a
time through `getc` and `putc`, and return the number of whole items
moved.

#lines-to(none)
#source("/usr/src/libc/stdio/getchar.c")

Although `getchar` is a macro in `<stdio.h>`, this file defines it also as a
function, for a program that takes its address or undefines the macro.
The functions `putchar`, `fgetc`, and `fputc` do the same for their macros. The
function `putchar` now returns nothing, as it was always used.

#lines-to(none)
#source("/usr/src/libc/stdio/putchar.c")

The function `putchar` writes a character on the standard output through `putc`.

#lines-to(none)
#source("/usr/src/libc/stdio/fgetc.c")

As a function, `getc` is `fgetc`.

#lines-to(none)
#source("/usr/src/libc/stdio/fputc.c")

As a function, `putc` is `fputc`.

#lines-to(none)
#source("/usr/src/libc/stdio/gets.c")

The routine `gets` reads a line from the standard input into the caller's array,
replacing the newline with a null. Nothing tells it how big the array
is, so a long line overruns it, and `fgets` (#f("stdio/fgets.c")), which
takes the size, is the safe form.

#lines-to(none)
#source("/usr/src/libc/stdio/puts.c")

The routine `puts` writes a string and a newline on the standard output.

#lines-to(none)
#source("/usr/src/libc/stdio/fputs.c")

The routine `fputs` writes a string, without a newline, on a stream, and returns
what the last `putc` returned. The result is now initialised (#l("register int r = 0;")), so
that an empty string returns 0, where v7 returned whatever the register
held.

#lines-to(none)
#source("/usr/src/libc/stdio/getw.c")

The routines `getw` and `putw` read and write an `int` as binary, least significant
byte first. An `int` is now four bytes (#l("i |= getc(iop)<<8;")--#l("return(i | (unsigned)getc(iop)<<24);")), where the PDP-11's
was two, and `getw` returns $-1$ at end of file, which a stored $-1$ cannot
be told from without `feof`.

#lines-to(none)
#source("/usr/src/libc/stdio/putw.c")

The routine `putw` writes the four bytes of an `int` (#l("putc(i, iop);")--#l("putc(i>>24, iop);")).

#lines-to(none)
#source("/usr/src/libc/stdio/strout.c")

`_strout` writes a field for `_doprnt` (#f("stdio/doprnt.c")): `count`
characters of `string`, padded with `fillch` to the left when `adjust`
is negative and to the right when positive. With zeros, a leading minus
sign is written before the padding.

#lines-to(none)
#source("/usr/src/libc/stdio/clrerr.c")

The routine `clearerr` clears a stream's error and end-of-file flags.

#lines-to(none)
#source("/usr/src/libc/stdio/rew.c")

The routine `rewind` returns a stream to the start of its file, flushing any
output and discarding any input buffered, and clearing the flags. A
stream open for both reading and writing may then do either.

#lines-to(none)
#source("/usr/src/libc/stdio/fopen.c")

The routine `fopen` opens the named file as a stream. It is split in two. The routine `_findiop` (`findiop.c`) finds a free entry of `_iob` (#f("stdio.h")), one with
none of `_IOREAD`, `_IOWRT`, and `_IORW` set, and `_endopen`
(#f("stdio/endopen.c")) opens the file and fills the entry in.
The routine `freopen` shares `_endopen`, giving it the stream it has just closed
instead of a new one. If every entry is in use `_findiop` returns
`NULL`, which `_endopen` passes on.

The local declarations of `_findiop` and `_endopen` in v7 are gone, since
#f("stdio.h") declares both.

#lines-to(none)
#source("/usr/src/libc/stdio/endopen.c")

`_endopen` does the work of `fopen` and `freopen`
(#f("stdio/fopen.c")). The mode is a string: its first character is
`r`, `w`, or `a`, and a `+` after it asks for reading and writing both.
Mode `w` creates or truncates the file. Mode `a` opens it for writing,
creating it only if it does not exist (`ENOENT`), and seeks to its end.
The seek is made once, so a program which seeks elsewhere and writes
will not have its output appended. Mode `r` opens an existing file. The
`open` modes 0, 1, and 2 are read, write, and both (`open1`,
#f("sys2.c")).

The variable `errno` is examined (#l("if (errno == ENOENT)")) only after a failure. If
the `open` fails for another reason, or the `create` fails too,
`lseek` is applied to -1, fails harmlessly, and the failure is reported
below (#l("if (f < 0)")).

The stream is then set up with an empty buffer, the file descriptor,
and the direction. A buffer is not allocated here. The first `getc` or
`putc` does that (#f("stdio/filbuf.c"), #f("stdio/flsbuf.c")).

The static declaration of `create` (#l("static int create(char *file, int rw);")) is new. The routine `create` is defined
after its first use, which K&R C allowed by assuming an `int` function, and
C99 requires a declaration first, and v7's `static` on the definition
must then be repeated on the declaration.

#lines-to("static int", lead: true, after: "}")

The routine `create` makes the file with mode 0666, which the process's `umask`
reduces. The call `creat` opens the file only for writing, so a stream for mode
`w+` must close it and open it again for both.

#lines-to(none)
#source("/usr/src/libc/stdio/fdopen.c")

The routine `fdopen` makes a stream of a file descriptor which is already open,
typically one end of a pipe (`popen`, #f("stdio/popen.c")). As the
comment says, the system offers no way to ask how a descriptor was
opened, so the caller must state the mode again. Mode `a` seeks to the
end of the file before falling into the case for `w`.

The comment on the fall-through (#l("/* fallthrough */")) has been reworded. GCC warns of a
`case` which runs into the next one (`-Wimplicit-fallthrough`, part of
`-Wextra`) unless a comment of a recognised form, such as
"fallthrough", marks it as intended, and v7's "No break" is not one of
them. The local declaration of `_findiop` in v7 is gone, since #f("stdio.h") now
declares it.

#lines-to(none)
#source("/usr/src/libc/stdio/freopen.c")

The routine `freopen` closes a stream and opens a file on the same entry of
`_iob`, through `_endopen` (#f("stdio/endopen.c")). It is how a program
attaches its standard input or output to a named file.

#lines-to(none)
#source("/usr/src/libc/stdio/setbuf.c")

The routine `setbuf` gives a stream a buffer of the caller's, which must hold
`BUFSIZ` bytes, or makes the stream unbuffered if the buffer is `NULL`.
A buffer which the package had obtained from `malloc` is freed first.
The count is set to zero, so that the next `getc` or `putc` goes
through `_filbuf` or `_flsbuf`, which find the buffer in place and use
it. A program should call `setbuf` before it uses the stream, or
characters already in the old buffer are lost.

#lines-to(none)
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
and each `double` four. The routine `printf(fmt, args)` was declared with one
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

The v7 conversion `%r`, which took the next argument as the address of a
further format and argument list and continued from there, depended on
walking memory in exactly this way, and has no counterpart.

The routine `gnum` reads a field width or precision: a decimal number, or `*`, which
takes the value from the argument list as v7's did.

#lines-to("void", lead: true, after: "}")

The literal text up to the next `%` is passed to `_strout` in one
piece. The buffer `buf` must hold the longest conversion: a `%f` of the largest
`double`, about 1.8e308, needs 309 digits before the point, and the
precision is limited to 70 (#l("if (ndigit > 70)")), so 400 bytes suffice. The v7 buffer was
128 bytes, enough when the largest PDP-11 number was about 1.7e38.

#lines-to("rjust = 0;")

A `-` asks for the result to be left-justified in its field. The
variable which records it is called `rjust`, after v7's assembly
variable of the same name and meaning. A leading `0` in the width asks
for zeros instead of spaces as padding. A precision is recorded with
`ndfnd` set, so that a precision of zero can be told from none. As in
v7's `gnum`, `ndfnd` is set only if digits or `*` follow the `.` (#l("s = ++fmt;")--#l("ndfnd = fmt > s;")): `%.s` prints the whole string and `%.f` six decimals, as if no
precision had been given. The pointer `s` marks the place, and is free until the
conversion sets it.

In v7 a long argument was asked for by a capital letter, `%D`, `%O`,
`%X`, or `%U`, or by `l` (or `L`) before the lower-case letter, and `%l`
followed by anything else meant `%u`, and the following character is
not consumed. All of this is kept (#l("case 'l':")--#l("}", before: "base = 10;")). The distinction matters
less than it did: `int` and `long` are both 32 bits here, while on the
PDP-11 a `long` was two words of the argument list.

The flag `ll` is new (#l("ll = 0;"), #l("if ((ll = *fmt == 'l'))"), #l("fmt++;", after: "if ((ll = *fmt == 'l'))")): a second `l`, as in `%lld` or `%llo`, asks
for a `long long`, the type of the 64-bit `time_t` (#f("param.h")),
which `tar` writes into its headers in octal and `pstat` prints.

#lines-to("base = 10;")

A signed conversion takes an `int`, a `long`, or a `long long` and
converts it to `unsigned long long`. If it was negative a `-` is stored and the magnitude
taken by unsigned negation, which is correct even for the most negative
value.

#lines-to("case 'o':")

The unsigned conversions, and the common code for all integers. The
digits are generated backwards, from the least significant, into the
far end of `buf`, then copied forward to follow any sign. Like v7, the port prints
`%X` in lower case like `%x`. A precision on an
integer has v7's meaning, not the later one: if it is nonzero, and so
is the number, a `0` is placed before the digits (#l("if (ndigit && u)")). The PDP-11 had
no instruction to divide a 32-bit number, so `doprnt.s` divided the two
words separately by a method it credits to Keith Davis. Here `%` and
`/` on an `unsigned long long` serve, by way of the compiler's routine
for 64-bit division, since the Cortex-A7 divides only 32 bits in one
instruction.

#lines-to("case 'e':")

The floating conversions take a `double`, the type to which a `float`
argument is always promoted. The precision, the number of digits after
the point, is 6 by default, and is limited to 70 for the sake
of `buf`. `%g` is wholly the business of `gcvt`.

`%e` asks `ecvt` for one digit more than the precision and lays them out
as a digit, the point, the rest, and the exponent. If the first digit
is `0` the value was zero, and the exponent is adjusted to print as
`+00`. The exponent of an IEEE `double` reaches 308, and is printed in
three digits from 100 up (#l("if (decpt >= 100) {")), and `fltpr.s` had to provide only two,
since the PDP-11's exponent did not exceed 38.

`%f` asks `fcvt` for the given number of digits after the point. A value
below 1 begins with `0`. The digits before the point come from the
buffer, but `fcvt` returns no more than 79 digits in all, and runs out
when the digits before the point and the precision together need more.
The tests of `*s` (#l("*p++ = *s? *s++: '0';"), #l("*p++ = decpt++ < 0 ||")) then supply zeros in their place. A `double` carries only about seventeen
significant decimal digits, so nothing of value is lost.

#lines-to("case 'c':")

`%c` stores the character unless it is the null character. `%s`
takes the string, or `"(null)"` for a null pointer, which v7 also
printed, and uses at most the precision's worth of it. Neither is ever
padded with zeros. For `%s` the result is not copied into
`buf`, and `s` and `p` bracket the string itself.

#lines-to("default:")

Any other character is printed as itself, which is how `%%` prints a
percent sign. Then the padding is computed: `c` is the number of fill
characters, given to `_strout` as negative for padding on the left and
positive for padding on the right. `_strout` takes care that a minus
sign precedes the zeros of a zero-filled number.

#lines-to(none)
#source("/usr/src/libc/stdio/printf.c")

The routine `printf` formats its arguments on the standard output by way of
`_doprnt` (#f("stdio/doprnt.c")), and reports whether the stream has
suffered an error.

In v7, `printf` was declared as taking one argument after the format,
`args`, and passed `&args` to `_doprnt`: on the PDP-11 the remaining
arguments followed `args` in memory, and the assembly `_doprnt` walked
along them. Under the ARM procedure call standard the first arguments
are in registers, and this no longer works. The port therefore makes `printf` a
variadic function in the C99 manner. The macro `va_start` (#l("va_start(args, fmt);")) sets `args` to the
first argument after `fmt`, `_doprnt` is given its address so that
everything it takes with `va_arg` is taken from the one list, and
`va_end` (#l("va_end(args);")) ends the use of the list, as C99 requires of every
`va_start`.

The declaration of `_doprnt` (#l("void\t_doprnt(char *fmt, va_list *argp, FILE *iop);")) is local to the files which call it,
as `_doprnt` is internal to the library and #f("stdio.h") does not
declare it, and `stdarg.h` (#l("#include\t<stdarg.h>")) is needed for the type `va_list`.

#lines-to(none)
#source("/usr/src/libc/stdio/fprintf.c")

The routine `fprintf` is `printf` (#f("stdio/printf.c")) with the stream given
explicitly. The changes from v7 are those made to `printf`, a variadic definition, a
`va_list` whose address is passed to `_doprnt` (#f("stdio/doprnt.c")),
and a local declaration of `_doprnt`.

#lines-to(none)
#source("/usr/src/libc/stdio/sprintf.c")

The routine `sprintf` formats into the string `str` instead of a file. It does so by
making a stream of the string: a `_iobuf` on its own stack whose pointer
addresses `str` and whose flags say that it is written (`_IOWRT`) and is
a string (`_IOSTRG`). `_doprnt` (#f("stdio/doprnt.c")) then writes on it
with `putc` like any other stream, and a final `putc` adds the null
character. The count of 32767, the largest `int` of the PDP-11, is
simply a number which no output is expected to reach, and `putc` will call
`_flsbuf` only when it runs out, and the caller must in any case
provide a big enough string. The other fields of `_strbuf` are never
used and are left unset.

The routine `sprintf` returns `str`, not the number of characters, which
#f("stdio.h") declares accordingly. The changes from v7 are those made
to `printf` (#f("stdio/printf.c")).

#lines-to(none)
#source("/usr/src/libc/stdio/doscan.c")

`_doscan` is the engine of `scanf`, `fscanf`, and `sscanf`
(#f("stdio/scanf.c")), as `_doprnt` is of `printf`. It reads characters
from the stream as the format directs, converts them, and stores the
results through the pointers which follow the format. It returns the
number of items stored, or -1 if the input ended before anything could
be matched.

Unlike `_doprnt` the file was C in v7, so the port's changes are
modest. Three of them repair faults in v7's code, one replaces the way
the arguments were found, and one adds `ll`.

`_sctab` (#l("char\t_sctab[256] = {")) classifies characters: `SPC` marks the white space which
separates fields, and `STP` is set afresh for each `%[` conversion to
mark the characters which stop it. The v7 table had 128 entries, but it
was indexed by the result of `getc`, which may be anything from 0 to
0377, and in `_getccl` by bytes of the format, which on the PDP-11
could be negative. Input with the eighth bit set read beyond the table,
and a `%[` set with such characters wrote beyond it. The table now has
256 entries, one for each value of a byte. Only the first 64 are
written out. The rest are zero.

The prototypes (#l("int\t_doscan(FILE *iop, char *fmt, va_list *argp);")--#l("int\t_instr(char *ptr, int type, int len, FILE *iop, int *eofptr);")) are new. `_doscan`, `_innum`, and `_instr` are
external, so `-Wmissing-prototypes` requires each to be declared before
its definition, and `_innum` calls `_instr`, defined after it. The header #f("stdio.h")
does not declare these internal routines.

#lines-to("int", lead: true, after: "};")

The main loop. A `%` introduces a conversion, `%%` matches a percent
sign, white space in the format skips any amount of white space in the
input, and any other character must match the next input character
exactly, or the scan ends.

After the `%` comes an optional `*`, which suppresses the assignment,
then an optional field width, which defaults to 30000, in effect
unlimited; then `l` for long or `h` for short; then the conversion
letter. A capital letter means long, as in `printf`, so `%D` and `%E`
are `%ld` and `%le`. The flag `ll`, with its size `LLONG` (#l("#define\tLLONG\t3"), #l("if (ch=='l') {", before: "size = LLONG;")--#l("}", after: "size = LLONG;")), is new:
`%llo` reads the 64-bit `time_t` back from a header of `tar`. A `%[`
reads the character class at once with `_getccl`.

In v7, `argp` was a pointer into the PDP-11 argument list, and `ptr` was
set at once to the address of the next argument (`ptr = argp++`), or to
0 if the assignment was suppressed, and `_innum` then stored through it as
through a pointer to a pointer of the appropriate type, `**(float **)ptr`
and the like. Now `ptr` is set to `fmt` (#l("ptr = fmt;")), which is used only as a
value known not to be null, to record that an argument is to be taken.

#lines-to("if (ptr) {")

The argument itself is taken here (#l("if (ptr) {")--#l("}", after: "ptr = (char *)va_arg(*argp, int *);")), once the conversion letter
and the size are known, with `va_arg` and the type which the caller really passed, `char *` for strings and characters, `float *` or
`double *` for the floating conversions, and `short *`, `int *`,
`long *`, or `long long *` for integers. The pointer is converted to `char *` for
`_innum`, which converts it back. Fetching every argument as an `int **`,
as v7 in effect did, is undefined in C99 (7.15.1.1): under the ARM
procedure call standard all these pointers happen to be passed alike,
but the compiler is entitled to assume otherwise.

`_innum` handles every conversion, passing strings on to `_instr`. If
it stored something, and an argument was supplied for it, the count of
matches goes up. If the input ended, the scan ends.

#lines-to("int", lead: true)

`_innum` converts a number. The field width is first cut to 62
characters (#l("if (len > 62)")), since the characters of the field are copied into
`numbuf`, of 64 bytes, for `atof`. With v7's default width of 30000 a
long enough number overflowed the stack. 62 leaves room for the null
character and for the one extra byte stored with an exponent's `e`
(#l("*np++ = c;", after: "expseen++;")), which takes two bytes of `numbuf` for one character of the
count. Leading white space is skipped, and a sign noted.

#lines-to("for ( ; --len>=0; *np++ = c, c = getc(iop)) {")

Digits are accumulated in `lcval`, now an `unsigned long long`, as
they are read, by shifts for octal and hexadecimal, and for decimal by
`((lcval<<2) + lcval)<<1`, which is ten times `lcval` without a
multiplication, a saving on the PDP-11. The field may hold 62 digits,
far more than 64 bits take, and v7's `long` overflowed, which C99 leaves
undefined for a signed type. Unsigned, the value wraps round, and the
negation of a negative number (#l("lcval = -lcval;")) is defined too. A floating number
is accumulated in the same way, uselessly,
but its characters are also kept in `numbuf`. A point is accepted only
in a floating conversion, and an exponent only after a digit has been
seen. The parentheses at #l("|| (base==16 &&") are new, as in #f("slp.c").

#lines-to("if (negflg)")

The character which ended the number is put back with `ungetc`, unless
it was `EOF`, which `*eofptr` reports. Nothing is stored if no
characters were taken or the assignment was suppressed. Otherwise the
value is stored according to the scale and size, now through a pointer
of the right type (#l("case (FLOAT<<4) | SHORT:")--#l("break;", after: "*(long long *)ptr = lcval;")) rather than v7's double indirection. The
conversion of a large unsigned value to a signed type is
implementation-defined, not undefined: GCC keeps the low bits. A
`float` is produced by converting the `double` from `atof`, and v7's
declaration of `atof` has gone to #f("stdio.h").

#lines-to("int", lead: true)

`_instr` reads a string (`%s`), a character class (`%[`), or
characters (`%c`, by default one). A string first skips white space.
Then it stops at white space, a class stops at a character marked `STP`,
and `%c` stops only when the count is exhausted. Only a `%c` is stored
without a null character. The pointer `ptr` may be null for a suppressed
assignment, in which case the characters are read and discarded.

The first `getc` is masked with `0377` (#l("while (_sctab[(ch = getc(iop))&0377] & ignstp)")) for the enlarged table.
`EOF`, -1, then indexes entry 0377, which is harmless: the loop stops at
`EOF` in any case, and the second loop (#l("while (ch!=EOF && (_sctab[ch]&ignstp)==0) {")) tests for `EOF` before it
indexes the table.

#lines-to("char *", lead: true)

`_getccl` builds the stop set for `%[`. A class beginning with `^`
names the characters which stop the scan. Otherwise it names those which
do not. The loop sets or clears `STP` in all 256 entries, then flips it
for each character up to the `]`.

The loop at (#l("while ((c = *s++&0377) != ']') {")) has been rewritten. The v7 code masked the byte with `0177`
only for the comparison with `]` and indexed the table with the
unmasked, possibly negative, value. The byte is now taken with `0377`
once, and used as it is. The v7 code also stored each byte with `c++` and then
tested `c==0` for the end of the format, which therefore never succeeded
once it had been incremented, and an unterminated `%[abc` ran on past
the end of the format. The test is now made before the byte is entered,
and `_getccl` returns a pointer to the null character, at which
`_doscan` stops.

#lines-to(none)
#source("/usr/src/libc/stdio/scanf.c")

There are three entries to `_doscan` (#f("stdio/doscan.c")). The
routine `scanf` reads the standard input, `fscanf` a given stream, and
`sscanf` a string.

The routine `sscanf` makes a stream of the string, as `sprintf` does (#f("stdio/sprintf.c")), but for reading. It sets
`_IOREAD` and `_IOSTRG`, points the buffer and pointer at the string,
and sets the count to its length, so
that `getc` takes its characters in turn. When the count runs out,
`getc` calls `_filbuf`, which returns `EOF` at once for a string
(#f("stdio/filbuf.c")), and `ungetc` can put a character back because the
buffer is the string itself.

In v7 each of the three was defined with a single argument `args`
after the format, whose address was passed on as that of the argument
list, since the PDP-11 laid the remaining arguments after it in memory. Each is now
a variadic function which hands `_doscan` the address of a `va_list`,
for the reasons given under `printf` (#f("stdio/printf.c")). Because
`va_end` must follow the scan, the result is kept in `r` and returned
afterwards. `_doscan` is declared locally (#l("int\t_doscan(FILE *iop, char *fmt, va_list *argp);")), being internal to the
library.

#lines-to(none)
#source("/usr/src/libc/stdio/popen.c")

The routine `popen` runs a command with its standard input or output connected to
the calling program by a pipe, and returns a stream for the other end, and
`pclose` closes the stream and waits for the command to finish.

The mode is `"r"` if the caller will read the command's output, `"w"` if
it will write the command's input. The macro `tst` (#l("#define\ttst(a,b)\t(*mode == 'r'? (b) : (a))")) chooses between its two
arguments by the mode, and so decides which end of the pipe the caller
keeps (`myside`) and which the child gets (`hisside`). The child closes
the caller's end, moves its own end to descriptor 0 or 1 with `dup2`,
and executes the command with `sh -c`. `_exit` (#l("_exit(1);")), not `exit`, ends a child whose `execl` fails,
so that the parent's stdio buffers, copied by `fork`, are not flushed a
second time.

As in v7, `dup2` has no system call of its own: the library's `dup2`
(`dup.s`) makes the call `dup` with 0100 added to the first descriptor,
and the kernel's `dup` (#f("sys3.c")) then takes the second argument as
the descriptor wanted, closing it first if it is open.

The terminating 0 of `execl`'s arguments (#l("execl(\"/bin/sh\", \"sh\", \"-c\", cmd, (char *)0);")) is cast to `char *`, as
in #f("cmd/getty.c"). The routine `execl` (`execl.s`)
is one of the few places where the PDP-11's way with arguments survives:
it pushes `r1` to `r3` just below any arguments which the caller
stacked, so that the arguments after the name lie in memory as a vector
ended by the 0, and hands the address of that vector to `exece`
(#f("sys1.c")) as `argv`.

The parent records the child's process id under the descriptor of its
end of the pipe, in `popen_pid`, which has one entry for each of the 20
descriptors a process may have (`NOFILE`, #f("param.h")).

#lines-to("int", lead: true, after: "}")

The routine `pclose` closes the stream, which sends an end of file to a command
reading from it, and waits for the child whose process id was recorded
for the descriptor. Other children which end meanwhile are reaped and
forgotten, as in `system` (#f("stdio/system.c")). Interrupt, quit, and
hangup are ignored during the wait, so that a signal meant for the
command, which shares the terminal, does not also kill the caller.

The three saved actions are now pointers to functions of one `int`
returning nothing (#l("register void (*hstat)(int sig), (*istat)(int sig),")), the type with which `signal.h` declares
`signal` (#f("sys/signal.s")), and v7 declared them, in one declaration
with the `int`s `f` and `r`, as pointers to functions returning `int`.

#lines-to(none)
#source("/usr/src/libc/stdio/system.c")

The routine `system` runs a command line through the shell and waits for it,
returning its status as `wait` reports it: the exit code shifted left
eight bits, or, if a signal ended the command, the signal's number in
the low byte. If the shell cannot be executed the child exits with
127.

The parent ignores interrupt and quit while it waits, so that a
character typed at the terminal to stop the command stops only the
command. The previous actions are restored afterwards. Any other child
which ends during the wait is collected and lost. The signals
are ignored only after the `fork`, so the child has the caller's
actions, which the shell then adjusts for itself.

The include of #f("stdio.h") (#l("#include\t<stdio.h>")) is new: v7's `system.c` included only
`signal.h`, and called `fork`, `execl`, `_exit`, and `wait` without
declarations, which C99 does not allow. The saved actions are now
pointers to functions of one `int` returning nothing (#l("register void (*istat)(int sig), (*qstat)(int sig);")), the type of
handler which `signal` takes and returns (#f("sys/signal.s")), and v7's were
pointers to functions returning `int`. The `execl` (#l("execl(\"/bin/sh\", \"sh\", \"-c\", s, (char *)0);")) ends with
`(char *)0`, as in #f("cmd/getty.c").

#lines-to(none)
#source("/usr/src/libc/stdio/fseek.c")

The routine `fseek` moves the position of a stream. A stream being read keeps a
buffer of characters ahead of the file's own position, so a seek within
what the buffer holds is done by moving `_ptr` alone (#l("if (!(iop->_flag&_IORW) && c > 0 && p <= c")--#l("}", after: "return(0);")). The variable `p` is
then the distance from the current point: for a seek relative to the
start (`ptrname` 0), the file's position less what remains in the
buffer is subtracted, and for one relative to the current point the
characters still in the buffer are taken off the offset. Any other seek
discards the buffer and calls `lseek`. A stream being written is first
flushed.

The port now initialises `p` to -1 (#l("long p = -1;")). In v7 a stream opened neither for
reading nor writing returned whatever `p` held. It now fails. The v7
declaration of `lseek` is gone, since #f("stdio.h") declares it.

#lines-to(none)

#source("/usr/src/libc/stdio/fgets.c")

The routine `fgets` reads characters into `s` until a newline, which it keeps, or
until `n-1` characters have been read, and terminates the string. It
returns `NULL` only when end of file comes before any character.

The port now initialises `c` (#l("register int c = 0;")). When `n` is 1 the loop reads nothing, and
v7 then tested an uninitialised `c` (#l("if (c<0 && cs==s)")). The call now returns an empty
string.

#lines-to(none)

#source("/usr/src/libc/stdio/ftell.c")

The routine `ftell` returns the position of a stream: the file's own position,
taken with an `lseek` of zero, adjusted by what the buffer holds. For a
stream being read the characters not yet taken from the buffer are
subtracted. For one being written those placed in the buffer but not
yet written are added. The declaration of `lseek` is gone, as in
#f("stdio/fseek.c").

#lines-to(none)

#source("/usr/src/libc/stdio/ungetc.c")

The routine `ungetc` pushes one character back into a stream being read, so that
the next `getc` returns it. It steps `_ptr` back over the character just
read and counts it again. On a stream whose buffer is empty and at its
start, `_ptr` is first moved up one place, so that the step back stays
within the buffer.

The character is now stored only if it differs from the one already
there (#l("if (*--iop->_ptr != c)"), #l("*iop->_ptr = c;")). The routine `sscanf` (#f("stdio/scanf.c")) reads from the caller's string
itself, which may be a string literal, and `doscan` pushes back the
character it has just read, and v7 wrote it back all the same, which C99
leaves undefined for a literal. The v7 expression `*iop->_ptr++` (#l("iop->_ptr++;")) fetched a
character it did not use. The port only moves the pointer, and the
`if` gains braces, both for warnings.

#lines-to(none)

#source("/usr/src/libc/stdio/gcvt.c")

The routine `gcvt` converts a number to the shortest of its `%e` and `%f` forms,
for `%g` in #f("stdio/doprnt.c"). The routine `ecvt` (#f("gen/ecvt.c")) gives `ndigit` digits
and the position of the decimal point. Trailing zeros are dropped, and
the E-style form is chosen when the point lies more than four places
beyond the digits or more than three before them.

The exponent may now have three digits (#l("if (decpt >= 100) {")--#l("}", after: "decpt %= 100;")). The PDP-11's largest
number was about $10^38$, so v7 printed two. An IEEE double reaches
$10^308$. The doubled parentheses (#l("if ((decpt >= 0 && decpt-ndigit > 4)"), #l("|| (decpt < 0 && decpt < -3)) { /* use E-style */")) are those of #f("malloc.c"),
and #f("stdio.h") declares `ecvt`.

#lines-to(none)


== General Routines <ch-gen>

#source("/usr/src/libc/gen/malloc.c")

The storage allocator of user programs. It should not be confused with
the kernel's `malloc` (#f("malloc.c")), which hands out pages of core
and blocks of swap space from a resource map and keeps no record within
the space itself. This one manages a single arena of memory obtained
from the system with `sbrk`, which moves the end of the process's data
segment (`sbreak`, #f("sys1.c")), and keeps its bookkeeping inside the
arena, in a word before each block.

The file has three repairs. It serves stdio for its buffers
(#f("stdio/filbuf.c")) and most commands which need tables of variable
size. The shell, which has an allocator of its own (#f("sh/blok.c")),
does not use it.

The debugging code (#l("#ifdef debug", after: "#include <stdio.h>")--#l("#endif", after: "abort();"), 172--189) is compiled only if `debug` is
defined, which it never is, and has been left in v7's K&R form. The
include of #f("stdio.h") (#l("#include <stdio.h>")) is new: it supplies the prototypes of
`malloc`, `free`, `realloc`, and `sbrk`, the last of which v7 declared
locally (deleted). It also defines `NULL` as 0, which line #l("#define NULL 0") then
defines again in the same words, as C99 allows.

`GRANULE` (#l("/*\tavoid break bug */")--#l("#endif", after: "#define GRANULE 0")) is used only in the test at (#l("if((unsigned)q+(temp+GRANULE)*WORD < (unsigned)q) {")), where on the
PDP-11 it kept a margin of 64 words below the top of the 64 KB address
space when the arena grew. The comment does not say what the "break
bug" was. The port does not define `pdp11`, so the
margin is zero.

#lines-to("/*\tC storage allocator")

The comment describes the arena. It is a circular list of blocks, each
beginning with a pointer to the next. The size of a block is not
recorded but implied by the distance to its successor. Whether a block
is in use is recorded in the lowest bit of the pointer which begins it,
the `BUSY` bit, which `testbusy`, `setbusy`, and `clearbusy` examine and
change by converting the pointer to `INT`, here `int`, which on the ARM
is as wide as a pointer. Any gap in the arena, memory which `sbrk`
returned but which did not adjoin the arena's previous top, is made a
block permanently marked busy.

`ALIGN` and `NALIGN` exist so that an implementation may make `WORD`
larger, for the sake of a type with stricter alignment, and the port
uses them so. The ARM procedure call standard requires eight-byte
alignment for a `double` and a `long long`, and code compiled to the
standard may rely on it, so `double` replaces v7's `int` (#l("#define ALIGN double")).

The arena is measured in units of `union store`, whose size `WORD` is
that of its largest member: two bytes on the PDP-11, and now eight,
the size of the `double`. Every block therefore starts on an eight byte
boundary, provided the arena does. The static `allocs` is aligned for
its `double` member. The break begins at the symbol `end`, which the
linker aligns to four bytes only, so `sbrk` (`sbrk.s`) rounds the break
up to a multiple of eight before it extends it. Since the low bits of
every block's address are zero, the lowest is free to serve as `BUSY`.
The cost of the alignment is four or eight bytes a block: four in the
pointer word, and up to four more in rounding the data to eight bytes.

The array `allocs` (#l("static\tunion store allocs[2];\t/*initial arena*/")) is the initial arena of two words, `allocp` is the point
at which the next search starts, `alloct` is the last block, an empty
one whose pointer leads back to the first, and `allocx` holds a word
which `malloc` overwrote, for the benefit of `realloc`.

#lines-to("char *")

The routine `malloc` first makes the initial arena on its first call: two blocks,
each pointing to the other and marked busy, so that the search has a
circle to travel round. A request of `nbytes` needs `nw` words: the
data rounded up to whole words, and one more for the pointer.

The test at (#l("if(nbytes > (~0u>>1) - BLOCK - 2*WORD)")) is new. The routine computes `nw` in `unsigned` arithmetic, and
a request near the largest `unsigned` wrapped round to a small number,
so that a huge request was given a tiny block. A request of two
gigabytes or more also reached `sbrk`, whose argument is an `int`, as a
negative increment. No request so large can be met in any case, and the
limit is chosen so that neither calculation can overflow below it.

#lines-to("for(p=allocp; ; ) {")

The search, first-fit and circular, starts at `allocp`. At each free
block it first merges the free blocks which follow it (#l("while(!testbusy((q=p->ptr)->ptr)) {")--#l("}", after: "p->ptr = q->ptr;")). This is
the only place where free blocks are joined. If the merged block is
large enough, it is taken. The pointer `q` is always beyond `p` there,
since the search does not wrap within a merge.

The variable `temp` counts the passes over the top of the arena. When it has passed
`alloct` twice without finding space, the arena must grow. It is a
static, for the reason given in its comment (#l("static int temp;\t/*coroutines assume no auto*/")).

The test (#l("if(q-p >= nw)")) was v7's `q>=p+nw && p+nw>=p`. The second half guarded
against `p+nw` passing the top of the PDP-11's address space and
wrapping to a small address, and C leaves such an overflow undefined, and a
compiler may assume that it does not happen and discard the test. The
difference `q-p` of two pointers into the arena is computed instead,
which is defined and expresses the same thing.

#lines-to("temp = ((nw+BLOCK/WORD)/(BLOCK/WORD))*(BLOCK/WORD);")

To grow the arena, enough is asked for to satisfy the request, rounded
up to a multiple of `BLOCK` (1024 bytes), so that small requests do not
each cost a system call. The old top block is pointed at the new space,
and marked busy if the new space does not adjoin it, so that the gap is
never allocated. The last word of the new space becomes the new top,
pointing back to `allocs`. The search then resumes, and the merging step
joins the new space to any free block before it.

The test at (#l("if((unsigned)q+(temp+GRANULE)*WORD < (unsigned)q) {")) was v7's `q+temp+GRANULE < q`, a check that the new
top would not wrap round the end of the address space, which again
depends on pointer overflow. It is now made on the addresses converted
to `unsigned`, where wrapping is defined.

#lines-to("found:")

A block found to be large enough is split if it is larger than needed:
the remainder becomes a free block, and `allocp` is left at it so that
the next search starts there. Writing the remainder's pointer destroys
a word of the old contents of the block, which is kept in `allocx`. The
block taken is marked busy, and the address after its pointer word is
returned.

#lines-to("/*\tfreeing strategy tuned for LIFO allocation", lead: true)

The routine `free` clears the busy bit and nothing more. The block is not joined to
its neighbours here. That waits for the next search. Setting `allocp` to
the freed block makes the next `malloc` look there first, which suits a
program which frees what it has just allocated.

#lines-to("/*\trealloc(p, nbytes) reallocates a block obtained from malloc()", lead: true)

The routine `realloc` changes the size of a block, moving it if necessary. It
honours a v7 promise which later allocators do not: the block may be one
freed since the last call of `malloc`. It frees the block if it is busy,
calls `malloc`, and copies the old contents if the result is elsewhere.
Since `free` changes nothing but the busy bit, the old contents survive
the call of `malloc`, with one exception: if `malloc` chose a block
starting below the old one and overlapping it, it may have split that
block and written a pointer into the old data. That word is restored
from `allocx` (#l("if(q<p && q+nw>=p)")). The copy runs upwards, so that it is safe when the
new block lies below the old.

The parameter is now `char *ap`, as the prototype in #f("stdio.h") says,
and is converted to `p` (#l("register union store *p = (union store *)ap;", after: "realloc(char *ap, unsigned nbytes)")), and v7 declared the parameter itself as
`union store *`, which was possible only because nothing checked the
caller's argument against it.

The debugging routine `allock` follows.

#lines-to(none)
#source("/usr/src/libc/gen/calloc.c")

The routine `calloc` allocates space for `num` items of `size` bytes with `malloc`
and clears it, an `int` at a time, and `cfree` frees it. The size arguments
of `cfree` are now named and unused (#l("(void)num;")--#l("(void)size;")), where v7 left them out of
the parameter list.

#lines-to(none)
#source("/usr/src/libc/gen/ctime.c")

The system keeps time as a single `time_t`, the number of seconds since
the beginning of 1970, Greenwich time: the kernel's `time`, advanced by
`clock` (#f("clock.c")) and read and set by the system calls `time`,
`stime`, and `ftime` (#f("sys4.c")). The routines here turn such a
number into a calendar date and a printable string. Their best known users are `date` and
`ls -l`.

In v7, `time_t` was a `long`, 32 bits on the ARM as on the PDP-11, and
signed, and the count ran out early in 2038. It is now a `long long`
(#f("param.h")): the routines take a pointer to a `time_t` (#l("ctime(time_t *t)"), #l("localtime(time_t *tim)"),
#l("gmtime(time_t *tim)")) where v7's took a pointer to `long`, and `copyt`, `hms`, and `day`
(#l("time_t copyt;"), #l("time_t hms, day, cyc;")), which hold a time or a number of days, are widened with it, and
`cyc` (#l("time_t hms, day, cyc;")) is new.

The comment's mention of a call to "the system" refers to `ftime`, which
returns, besides the time, the local time zone in minutes west of
Greenwich and a flag saying whether daylight saving time applies. Both
are constants compiled into the kernel, `TIMEZONE` and `DSTFLAG`
(#f("param.h")), so that every program on the machine agrees on them.
Like v7, the port is distributed for Eastern time.

#lines-to("#include <time.h>", lead: true)

The table `dmsize` gives the lengths of the months, and `gmtime` changes February to 29
temporarily in a leap year. The table `daytab` records the two years
in which American daylight saving time followed emergency rules after
the oil crisis of 1973.

The braces around each entry of `daytab` (#l("{5,\t333},\t/* 1974: Jan 6 - last Sun. in Nov */"), #l("{58,\t303},\t/* 1975: Last Sun. in Feb - last Sun in Oct */")) are new: v7 relied on
the elision of braces in the initialiser of an array of structures,
which is legal C but draws `-Wmissing-braces`, part of `-Wall`.

The v7 file declared `gmtime`, `localtime`, `ctime`, and `asctime` here, and also
a `ct_num`, which was never defined or used. The public routines are
now declared, with prototypes, in #f("stdio.h"), which is included for
the purpose (#l("#include <stdio.h>")). Because `ct_numb` and `sunday` are used before they are
defined, they need declarations of their own (#l("static char\t*ct_numb(char *cp, int n);"), #l("static int\tsunday(struct tm *t, int d);")), static like
the definitions.

The routine `ctime` is the composition of `localtime` (#l("localtime(time_t *tim)")) and
`asctime` (#l("asctime(struct tm *t)")).

#lines-to("struct tm *", lead: true)

The routine `localtime` subtracts the zone's offset from the time, breaks the result
into its parts with `gmtime`, and then decides whether daylight saving
time is in force: by default from 2 a.m. on the last Sunday in April to
1 a.m. on the last Sunday in October, which was the American rule from
1967 to 1986. If so, an hour is added and the parts computed again.
Since 2007 the American rule has been different, so the time printed
here is an hour wrong for some weeks of each year, in March and April
and around the start of November.

The subtraction (#l("copyt = (unsigned long long)*tim - (long)systime.timezone*60;")) and the addition (#l("copyt = (unsigned long long)copyt + 1*60*60;")) are done in
`unsigned long long`, and the result converted back: a time within hours of the
largest or smallest `time_t` would otherwise overflow a signed
`long long`, which C leaves undefined. The unsigned arithmetic wraps
instead, and only such an absurd time is affected.

#lines-to("/*", lead: true)

The routine `sunday` finds the last Sunday on or before a given day of the year,
using the day of the week known for the current day. Its comment, v7's,
says "on or after", but the subtraction can only move back. So 119, the
last day of April in an ordinary year, yields the last Sunday in April. Days from the
end of February onwards (day 58) are moved one later in a leap year.
Since `dysize` takes the whole year, 1900 is added to `tm_year`, which
counts from 1900 (#l("d += dysize(t->tm_year+1900) - 365;")), and v7 passed `tm_year` itself.

#lines-to("struct tm *", lead: true)

The routine `gmtime` divides the time into days and seconds within the day,
correcting for a negative time, which is a moment before 1970. The
days are then divided into whole cycles of 400 years, 146,097 days
each, in `cyc`, and the days left over, fewer than one cycle (#l("cyc = day / 146097;"),
#l("day %= 146097;")). The Gregorian calendar repeats itself after 400 years, to the
day of the week, since 146,097 is a multiple of seven. So the date
within the cycle is that of the same date 400 years earlier or later.
The v7 code had no such step, and with a 32-bit time needed none: the loops
below ran at most 68 times. A 64-bit time reaches some 290 billion
years, and any owner can set a file's times so far (`utime`,
#f("sys4.c")); the loops would then take hours over a single `ls -l`. The
hours, minutes, and seconds are stored through `tp`, which walks the
first members of `struct tm` as though it were an array of `int`. This
depends on the members being consecutive `int`s, which they are on the
ARM as on the PDP-11.

The day of the week is computed from the day count plus 7340036, a
number which is 4 more than a multiple of seven (1 January 1970 was a
Thursday, day 4) and large enough to keep the sum positive for any
day after the twentieth millennium before 1970, which, since the day
count is now less than one cycle from 1970, is every day.

The year is found by subtracting the lengths of whole years, at most
400 of them. The v7 code counted `d1` from 70, the year less 1900, and `date`
called `dysize` with the whole year, 1970 and on. Only v7's rule, a
leap year every fourth year, gave the same answer for both, and it
fails first in 2100. Now `d1` counts whole years from 1970 (#l("if (day>=0) for(d1=1970; day >= dysize(d1); d1++)")--#l("day += dysize(d1-1);")),
and `dysize` (#l("dysize(int y)")) follows the Gregorian calendar. The field `tm_year` is the
year less 1900, as before (#l("xtime.tm_year = (d1 + cyc%25*400 + 10000) % 10000 - 1900;")), but the year is first reduced modulo
10,000, which is 25 cycles, so that it lies between 0 and 9999 and
fits the four digits of `asctime`. The furthest years of a 64-bit time
would not even fit an `int`. Being a whole number of cycles, the reduction leaves
the month, the day, and the day of the week exact.

#lines-to("char *", lead: true)

The routine `asctime` produces the fixed format of 26 characters, newline and null
included. A template is copied into `cbuf`, and the names and the
numbers are written over it. The routine `ct_numb` writes a number in two
character positions after skipping one. The hours, minutes, and
seconds are passed with 100 added, so that they keep a leading zero,
and the day of the month without, so that it gets a leading space.

The year is printed as its last two digits after the template's
`19`. For a year of 2000 or later v7 changed the `19` to `20`, which
was right until 2099. The two digits of the century are now computed
from the year (#l("cp[1] = (t->tm_year+1900)/1000%10 + '0';"), #l("cp[2] = (t->tm_year+1900)/100%10 + '0';")), and the last two digits too (#l("cp = ct_numb(cp, (t->tm_year+1900)%100+100);")), for every
year from 0 to 9999, which is all `gmtime` produces, and v7's `tm_year+100`
fails before 1900. Reading a year as two digits, `date` now
takes one below 70 to be in the twenty-first century, and v7's took it to
be in the twentieth.

The routine `dysize` gives the number of days in a year, 366 in a leap year, which
in the Gregorian calendar is every fourth year except the centuries,
of which only every fourth is one, and 365 otherwise. The v7 code tested only
the first condition, which agrees with the full rule from 1901 to 2099.

The doubled parentheses in the copy loop (#l("for (ncp = \"Day Mon 00 00:00:00 1900\\n\"; (*cp++ = *ncp++););")) are those of #f("malloc.c").

#lines-to(none)
#source("/usr/src/libc/gen/timezone.c")

The routine `timezone` names a time zone given its offset west of Greenwich in
minutes and whether summer time is in effect, for `ctime`'s callers
such as `date`: the zones of North America by their letters, otherwise
in the form `GMT+h:mm`. The entries of the table are now braced
(#l("{4*60, \"AST\", \"ADT\"},\t\t/* Atlantic */")--#l("{-1, 0, 0}")), as C99 asks.

#lines-to(none)
#source("/usr/src/libc/gen/atof.c")

The routine `atof` converts a decimal number in characters, with an optional sign,
point, and exponent, to a `double`. Its users are `scanf`, for its floating
conversions (#f("stdio/doscan.c")), `awk`, `graph`, and `spline`.
Leading blanks are skipped, though not tabs. The conversion stops at the
first character which cannot continue the number.

#lines-to("exp = 0;")

The digits are accumulated as an integer in the `double` `fl`, the point
being remembered as a decimal exponent `exp`, which is decremented for
each digit after the point. Once `fl` reaches 2 to the power 56 (#l("double big = 72057594037927936.;  /*2^56*/")), further
digits before the point only increment `exp`, and further digits after
it are ignored. The limit is the 56-bit fraction of the PDP-11's
`double`, the most digits it could hold exactly. The ARM's IEEE `double`
has a fraction of 53 bits, so digits accumulated between 2 to the
power 53 and 2 to the power 56 are rounded. The effect is confined to the last
bit or two of the result, and v7's constant has been kept.

#lines-to("negexp = 1;")

The explicit exponent is added to `exp`. Its digits are accumulated
only while it is below 10000 (#l("if (eexp < 10000)")), a test the port has added: v7 let
`eexp` grow without limit, and a long enough string of digits overflowed
the `int`, which C leaves undefined. Ten thousand is far beyond any
exponent which can make a difference, since the result is already zero
or infinite long before.

#lines-to("if(fl == 0 || (nd+exp*negexp) < -LOGHUGE){", lead: true)

The scaling. Multiplying by a power of ten is done as multiplying by
the same power of five and then of two. The power of five is computed by
repeated squaring. The power of two is applied with `ldexp`, which only
changes the exponent of the `double` and is therefore exact. (`ldexp` is
`ldexp.c`, the port's C replacement for v7's PDP-11 assembly
`ldexp11.s`.)

A number whose magnitude is below 10 to the power -`LOGHUGE` becomes
zero at once (#l("if(fl == 0 || (nd+exp*negexp) < -LOGHUGE){")). `LOGHUGE`, in `math.h`, was 39 on the PDP-11, whose
largest `double` was about 1.7e38. It is 308 for the IEEE `double`.

The test `fl == 0` (#l("if(fl == 0 || (nd+exp*negexp) < -LOGHUGE){")) is new. A zero mantissa with a large exponent,
such as `0e500`, made `flexp` infinite, and zero times infinity is not
a number. Such input now takes the path to zero directly. The PDP-11 of v7
had no infinities, and this case could not arise. The local declaration
of `ldexp` has gone, `math.h` now declaring it with a prototype.

#lines-to(none)
#source("/usr/src/libc/gen/atoi.c")

The routines `atoi` and `atol` convert a decimal string, with optional blanks and
sign, to an `int` or a `long`. The value is now accumulated unsigned
(#l("register unsigned n;")), so that too many digits wrap instead of overflowing, which C leaves
undefined for signed numbers.

#lines-to(none)
#source("/usr/src/libc/gen/atol.c")

For a `long`, `atol` does what `atoi` does, likewise accumulating unsigned (#l("unsigned long n;")).

#lines-to(none)
#source("/usr/src/libc/gen/ecvt.c")

The routines `ecvt` and `fcvt` convert a `double` to a string of decimal digits,
reporting the position of the decimal point in `*decpt` and the sign in
`*sign`, and leaving the placing of the point, the sign, and any
exponent to the caller. The first produces `ndigits` significant digits, and
`fcvt` produces as many digits as are needed for `ndigits` of them to
follow the point. They serve `_doprnt` for `%e` and `%f`
(#f("stdio/doprnt.c")) and `gcvt` for `%g`. The result is in a static
buffer which the next call overwrites.

The includes and the static declaration of `cvt` (#l("#include <stdio.h>")--#l("int eflag);")) are new:
#f("stdio.h") holds the prototypes of `ecvt` and `fcvt`, and `math.h`
that of `modf`, which v7 declared locally, and `cvt` is used before it is
defined.

#lines-to("static char*")

The routine `cvt` does the work for both, `eflag` telling them apart. The number of
digits is kept within the buffer of `NDIG` bytes, and the sign is
recorded and removed. The variable `r2` will count the position of the decimal point.

#lines-to("if (!(arg <= 1.7976931348623157e308))")

The test at (#l("if (!(arg <= 1.7976931348623157e308))")) is new. It replaces an infinity, or a NaN, which the
IEEE arithmetic of the ARM can produce and the PDP-11's could not, by
the largest finite `double`. Without it, the loop at (#l("while (fi != 0) {")) would never
end for an infinity, since dividing an infinity by ten leaves it
infinite.

A call of `modf` splits the number into its integer part `fi` and its fraction.
The digits of the integer part are produced from the right by dividing
by ten and taking the remainder, `fj` being the fraction of `fi/10`. The
`.03` makes up for the inexactness of that fraction, which may fall
just short of a tenth of the digit. The digits are built backwards from
the end of `buf` and then moved to its start. A number below 1 instead
yields its leading zeros as a negative `r2`: it is multiplied by ten,
and `r2` decremented, as long as the product stays below 1.

The loop at (#l("for (; fi >= 1e40; r2 += 10)")--#l("modf(fi, &fi);")) is new. The largest PDP-11 number, about 1.7e38,
had 39 digits before the point, and these always fitted in the 80 bytes
of `buf`. An IEEE `double` may have 309, and the digits, built
backwards from the end, would run off the front of the buffer for any
number of 1e80 or more. Numbers of 1e40 or more are therefore divided by
1e10 until they are smaller, `r2` counting ten places for each
division, and the fraction which the division leaves is discarded
(#l("modf(fi, &fi);")). At most 40 digits are thus produced. The rest are lost, but a
`double` has only about seventeen significant decimal digits, and the
digits which follow are supplied as zeros by the fraction loop below
(the fraction of so large a number being zero) or by `_doprnt`.

#lines-to("p1 = &buf[ndigits];")

The pointer `p1` marks the position one past the last digit wanted: `ndigits` from
the start for `ecvt`, `ndigits` past the point for `fcvt`. If that lies
before the start, as for a small number with too few places asked of
`fcvt`, the result is empty. Otherwise digits of the fraction are
produced, by repeated multiplication by ten, until there is one beyond
the last wanted, the buffer being full at worst. In the latter case the
result is returned unrounded, `NDIG`-1 digits long.

#lines-to("p = p1;")

The extra digit rounds the result: 5 is added to it and the carry is
propagated leftwards. A carry out of the first digit, as when 9.99 is
rounded to two digits, makes that digit `1`, moves the point one place
right, and in `fcvt`'s case adds a digit at the end. The rounding digit
itself is then cut off by the null character.

#lines-to(none)
#source("/usr/src/libc/gen/frexp.c")

The routine `frexp` splits a number into a fraction between one half and one and a
power of two. The v7 version was four instructions of the PDP-11's floating-point
unit. The ARM's has nothing like them, so the port takes the IEEE double
apart. Its high word, on this little-endian machine the second, holds
the sign, an 11-bit exponent biased by 1023, and the top 20 bits of the
fraction. The routine reads the exponent (#l("*eptr += (int)(x.u[1]>>20 & 03777) - 1022;")) and replaces it by 1022, the
exponent of a number in $[1/2, 1)$ (#l("x.u[1] = (x.u[1] & 0x800fffff) | 1022<<20;")). A denormal number, with an
exponent field of zero, is first scaled by $2^54$ to make it normal
(#l("if ((x.u[1] & 0x7ff00000) == 0) {")--#l("}", after: "*eptr = -54;")).

#lines-to(none)
#source("/usr/src/libc/gen/ldexp.c")

The routine `ldexp` multiplies a number by a power of two. The port builds the
power as a double directly, with the exponent field set and the
fraction zero (#l("x.u[0] = 0;")--#l("x.u[1] = (k+1023) << 20;")), and multiplies. A power beyond the range of a
double is applied in steps of at most $2^1000$ (#l("for (; n; n -= k) {")--#l("k = n > 1000? 1000: n < -1000? -1000: n;")). An overflowing result becomes the largest double of the right sign, and
`errno` set to `ERANGE` (#l("if (value > 1.7976931348623157e308 ||")--#l("}", after: "0? -1.7976931348623157e308: 1.7976931348623157e308;")), as v7's did.

#lines-to(none)
#source("/usr/src/libc/gen/modf.c")

The routine `modf` splits a number into its integer and fractional parts, both
with the number's sign. The port clears the bits of the fraction which
lie below the binary point, given by the exponent (#l("e = (int)(x.u[1]>>20 & 03777) - 1023;")--#l("x.u[0] &= ~(0xffffffff>>(e-20));")): all of them
for a number below one, none for a number of 52 or more bits. The
fractional part is the difference (#l("return(value - x.d);")).

#lines-to(none)
#source("/usr/src/libc/gen/qsort.c")

The routine `qsort` sorts an array of `n` elements of `es` bytes each, in place,
using the caller's function `fc` to compare two elements, and `fc` returns a
negative number, zero, or a positive number as the first is less than,
equal to, or greater than the second. Among its users are `ls`, `quot`, and
`sa`.

The comparison function and the element size are kept in statics, so
that the recursive `qs1` need not pass them on, and `qsort` is therefore not
reentrant, which no program here requires.

The include of #f("stdio.h") (#l("#include <stdio.h>")), which declares `qsort`, and the
static declarations of the three helpers (#l("static void qs1(char *a, char *l), qsexc(char *i, char *j),"), #l("qstexc(char *i, char *j, char *k);")), which are used before
they are defined, are new. The comparison function `qscmp` is now
declared with the types of its arguments (#l("static int\t(*qscmp)(char *p1, char *p2);")), as #f("stdio.h") declares
`fc`.

#lines-to("static void qs1(char *a, char *l)", lead: true, after: "}")

The routine `qs1` sorts the elements from `a` up to, but not including, `l`. It is a quicksort which partitions three ways, into elements less than
the pivot, elements equal to it, and elements greater. The equal elements gather
in a block from `lp` to `hp` in the middle, which takes no further part,
so that an array with many equal keys does not degrade the sort.

The pivot is the middle element. The routine computes `n` so that `a+n` is the
address of an element, not merely the middle byte.

The size `es` (#l("register unsigned es;")) is now `unsigned`, like `n`, so that `n <= es` (#l("if((n=l-a) <= es)")) compares
two unsigned numbers (#f("fio.c")). No result changes, since `es` is
positive. The unused variable `k` of v7 has been deleted.

#lines-to("for(;;) {")

The index `i` moves up from the left and `j` down from the right. An element
found equal to the pivot block on either side is exchanged into it,
extending the block by one. An element less than the pivot stays where
it is on the left, and one greater on the right. When `i` has stopped
at a greater element and `j` at a lesser one, the two are exchanged. If
one side has run into the block while the other holds an element of the
wrong kind, `qstexc` rotates three elements: the misplaced element is
put on its proper side of the block, and the block moves one place
towards the side still being scanned.

#lines-to("if(i == lp) {", lead: true, after: "j -= es;")

When both scans have reached the block, the array is partitioned. The
smaller part is sorted by a recursive call and the larger by going back
to `start` with new bounds. Recursion is thus confined to the smaller
part, so the depth of the stack grows only as the logarithm of `n`.

#lines-to("static void qsexc(char *i, char *j)", lead: true)

The routine `qsexc` exchanges two elements and `qstexc` rotates three, a byte at a
time. Both now return `void`, as nothing uses a result.

#lines-to(none)
#source("/usr/src/libc/gen/crypt.c")

The routine `crypt` is the one-way function with which passwords are protected. The
password file (`/etc/passwd`) holds not the password but the result of
`crypt` applied to it, and `login` (#f("cmd/login.c")) and `su` encrypt what
the user types and compare the results, and `passwd` stores the result
for a new password. The function is built on the Data Encryption
Standard (DES), which the file implements in full and also offers
directly as `setkey` and `encrypt`.

The implementation favours clarity over speed: every bit of the key, of
the block, and of the intermediate values occupies a `char` of its own,
holding 0 or 1, and every permutation of the standard is a loop over a
table of bit positions, numbered from 1 as in the standard.

The include of #f("stdio.h") (#l("#include <stdio.h>")), for the prototypes of `setkey`,
`encrypt`, and `crypt`, is new.

#lines-to("/*", lead: true, after: "33, 1,41, 9,49,17,57,25,")

The tables for the key schedule. Of the 64 bits of a DES key, 56 are
used, in two halves `C` and `D` of 28 bits. The tables `PC1_C` and `PC1_D` drop the eight parity bits. `KS` holds the sixteen 48-bit subkeys.

The initialiser of `PC1_D` (#l("static\tchar\tPC1_D[] = {")) lacked its `=` in v7, a form left from
the earliest C which v7's compiler still accepted, and C99 does not. Other
tables below had the same form and have had the same change.

#lines-to("void", lead: true)

The routine `setkey` takes a key of 64 bits, one to a `char`, and computes the
sixteen subkeys: `C` and `D` are rotated left by one or two places for
each round, as `shifts` directs, and `PC2_C` and `PC2_D` select 48 of
their 56 bits.

#lines-to("/*", lead: true, after: "KS[i][j+24] = D[PC2_D[j]-28-1];")

The tables for the rounds. `E` expands the 32 bits of the right half to
48. It is a copy of `e`, because `crypt` alters it for each salt. `S`
holds the eight selection functions, each a table of 64 entries.

The v7 code declared `S` as `char S[8][64]` but initialised it with a single list
of 512 numbers, relying on the elision of the inner braces. That is
legal C, but draws `-Wmissing-braces`, part of `-Wall`, which `-Werror`
makes fatal. The table is now one-dimensional (#l("static\tchar\tS[] = {")), and the index in
`encrypt` is computed as `j*64 + ...` (#l("k = S[j*64 + (preS[t+0]<<5)+")) to match. The order of the
entries in memory, and so the result, is unchanged.

The arrays `L` and `R` are the two halves of the block. The v7 code declared them as two
arrays of 32, but `encrypt` indexes `L` with the positions of the
initial and final permutations, which run up to 64, and so assumed that
`R` followed `L` in memory. C makes no such promise, and GCC's analysis
reports the indexing as out of bounds. `L` now has 64 entries, and `R` is defined as its second
half (#l("static\tchar\tL[64];"), #l("#define\tR\t(L+32)")).

#lines-to("/*", after: "static\tchar\tpreS[48];")

The routine `encrypt` enciphers the 64-bit block in place, or deciphers it if
`edflag` is nonzero, which only reverses the order in which the
subkeys are used. Each of the sixteen rounds computes a new right half
as the old left half exclusive-or a function of the old right half and
the subkey, and the old right half becomes the new left half. The
function expands the right half with `E`, adds the subkey, reduces each
group of six bits to four through a selection function, and permutes
the result with `P`. The comment at (#l("* The indexing into the selection functions")) remarks on the peculiar order
of the bits in the index of `S`: the first and last bits of each group
of six choose one of the four rows of 16 entries, as the standard has
it, and the middle four the column.

#lines-to("char *", lead: true)

The routine `crypt` makes a key of the first eight characters of the password, seven
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

#lines-to(none)
#source("/usr/src/libc/gen/sleep.c")

The routine `sleep` suspends the process for a number of seconds with `alarm` and
`pause`, keeping any alarm the caller had set: if that alarm is due
first, `sleep` ends then, and otherwise it sets the caller's alarm again
for what remains. The handler leaves through `longjmp` back into
`sleep`. The variables which change between `setjmp` and `longjmp` are
now `volatile` (#l("sleep(volatile unsigned n)")--#l("void (*volatile alsig)(int sig) = SIG_DFL;")), since C promises their values after the jump
only then. On the PDP-11 v7's compiler kept them in memory anyway.

#lines-to(none)
#source("/usr/src/libc/gen/execvp.c")

The routines `execvp` and `execlp` are `execv` and `execl` with the search which the
shell makes for a command: if the name contains no `/`, each directory
named in the environment variable `PATH` is tried in turn. A file which
is not an executable program is taken to be a shell script and run with
`/bin/sh`. Programs which run other programs by name, such as `nice`,
`time`, and `find`, use these instead of duplicating the shell's
search.

The includes of #f("stdio.h") and `stdarg.h` (#l("#include <stdio.h>"), #l("#include <stdarg.h>")) are new: the first
declares `getenv`, `index`, `strlen`, `execv`, and `sleep`, which v7
called undeclared or declared here. The routine `execlp` needs the second.
The routine `execat` has a static declaration, since it is used before it is
defined, and `errno` (#l("extern\tint errno;")) is declared `int` explicitly, C99 having no
implicit `int`. `NULL` is defined (#l("#define\tNULL\t0")) before #f("stdio.h") is included, as in
v7. The header defines it again in the same way, which C99 permits.

#lines-to("int")

The routine `execlp` turns its arguments into a vector for `execvp`. The v7 version
was a single line, `execvp(name, &argv)`: it named its first argument
after the name `argv` and passed its address, which on the PDP-11 was
the address of an array of all the arguments, laid out on the stack one
after another and ended by the caller's 0. Under the ARM procedure call
standard the first arguments arrive in registers, and the address of a
parameter is the address of a copy which the compiler has made
somewhere, with no promise about what follows it. The v7 line would work
only when the compiler happened to spill the registers in order.

The routine `execlp` now walks its arguments twice with `va_arg`: once to count them,
`n` starting at 2 for `arg0` and the terminating null pointer, and once
to copy them into `argv`, a variable length array, a C99 feature, on
the stack. The library's `execl` (`execl.s`) solves the same problem in
assembly, by pushing `r1` to `r3` beneath the stacked arguments so that
they form a vector after all, and C offers no way to do that.

#lines-to("int", lead: true, after: "}")

The routine `execvp` takes the search path from the environment, or uses
`:/bin:/usr/bin`, whose empty first element stands for the current
directory. A name containing `/` is not searched for: `cp` is then the
empty string, and `execat` produces the name unchanged.

In v7, `fname`, the name being tried, was a fixed array of 128 bytes, and
`execat` copied into it without a check, so that a long element of
`PATH` or a long name overflowed it. It is now a variable length array
(#l("char fname[strlen(pathstr)+strlen(name)+2];")) sized for the whole of `PATH` plus the name, a `/`, and the null
character, which is more than the longest element can need. Its
declaration had to move below the statements which find `pathstr`.

#lines-to("do {")

For each directory `execv` is tried, and returns only if it fails, and
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

The doubled parentheses in the copying loop (#l("for (i=1; (newargs[i+1]=argv[i]); i++) {")) are those of #f("malloc.c").

#lines-to("static char *", lead: true)

The routine `execat` builds the name from the next element of the path,
a `/` if the element was not empty, and the name. It returns a pointer to the
element after, or 0 at the end of the path. An element ends at a `:`
(#l("while (*s1 && *s1 != ':')")). The v7 code ended it at a `-` as well, for a reason the code does not
record, and so could not find a command in a directory such as
`/usr/local-bin`, which it took for two directories, `/usr/local` and
`bin`. The `-` is now part of the name, as it is for `sh`
(#f("sh/service.c")).

#lines-to(none)
#source("/usr/src/libc/gen/setjmp.s")

The routines `setjmp` and `longjmp` give C a non-local goto. A call `setjmp(env)` records
the state of the calling procedure in `env` and returns 0. A later
`longjmp(env, val)`, from any procedure called by it, however deeply,
abandons the procedures in between and makes that `setjmp` return a
second time, with the value `val`. The editor `ed` and the shell (`error`,
#f("sh/error.c")) use the pair to return to the command loop after an
error, and `init` (#f("cmd/init.c")) to return to its main loop. They are
the user's counterpart of the kernel's `save` and `resume`
(#f("mch.s")), and the ARM versions are nearly the same code.

The file replaces v7's PDP-11 `setjmp.s`, which depended on the frame
conventions of the PDP-11 C compiler. There every procedure began by
calling `csv`, which pushed `r5`, the frame pointer, and the register
variables `r4` to `r2`, and ended by jumping to `cret`, which restored
them. In v7, `setjmp` saved only three words, `r5`, the stack pointer, and the return address, which is why `jmp_buf` (`setjmp.h`) was an array
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
procedure call standard requires a procedure to preserve for its caller, `r4` to `r11`, the
stack pointer, and the link register, which
holds the return address. It is the same set of ten words that `save`
stores in a `label_t` (#f("param.h")), and for the same reason. Any call may destroy `r0` to
`r3` and `ip`, so no caller of `setjmp`
expects them to survive it. The standard adds, for programs compiled
for hard floating point (#f("Makefile")), the floating point registers
`d8` to `d15`, which `vstmia` stores after the ten words (#l("vstmia r0, {d8-d15}")). The type `jmp_buf`
now has 26 `int`s to match: the ten words and eight `double`s. The
floating point status register `FPSCR` is not saved: under the standard
its rounding mode and exception flags belong to the whole program, not
to a procedure, and a `longjmp` leaves them as they are.

The routine `longjmp` reloads the ten words and the eight registers, which restores the stack pointer of
`setjmp`'s caller and discards every frame below it, and returns
through the saved link register as though from `setjmp`. The value is
`val`, unless that is 0, in which case it is 1, so that the
caller can always tell the second return from the first, and `movs` (#l("movs r0, r1"))
sets the condition codes as it copies, saving a separate comparison.

One consequence differs from v7. The registers are restored to their
values at the time of the `setjmp`, so a register variable of the
caller which changed between the `setjmp` and the `longjmp` reverts,
while a variable kept in memory does not. C leaves the value of such a
variable indeterminate after the `longjmp` unless it is declared
`volatile`, which allows both behaviours. Unlike `resume`, `longjmp`
changes no mapping: the process's address space is the same before
and after.

#lines-to(none)


#source("/usr/src/libc/gen/getenv.c")

The environment is an array of strings of the form `name=value`, ended
by a null pointer, which `exec` (#f("sys1.c")) copies onto the new
stack after the arguments, and #f("csu/crt0.s") leaves its address in
`environ`. The routine `getenv` returns the value of the variable it is asked for,
or `NULL`.

The routine `nvmatch` compares the two strings until they differ. Reaching an `=`
in both while still equal means `s1` is itself a `name=value` string
whose name matches. Reaching the end of `s1` just as `s2` reaches its
`=` means the bare name matches. In either case the value starts after
the `=` in `s2`.

The include of #f("stdio.h") (#l("#include <stdio.h>")), which declares `getenv`, is new, and
`nvmatch` is static and declared with its parameters (#l("static char\t*nvmatch(char *s1, char *s2);")), since it is
used before it is defined.

#lines-to(none)

#source("/usr/src/libc/gen/ttyname.c")

The routine `ttyname` finds the name of the terminal open on descriptor `f`. A
terminal is a character special file, and its name is found by reading
`/dev` as a file of directory entries (#f("dir.h")) and looking for an
entry with the same i-number. Since `/dev` may hold entries for other
file systems' i-numbers only by accident, each candidate is checked with
`stat`, which must give the same device and i-number. The name is
returned in a static buffer, overwritten by the next call.

The name in a directory entry has `DIRSIZ` characters and no null when
it uses all of them, so the port appends it with `strncat` (#l("strncat(rbuf, db.d_name, DIRSIZ);")), which
copies at most `DIRSIZ` characters and terminates the result, and v7's
`strcat` would have run on past the entry. The header #f("stdio.h") (#l("#include <stdio.h>")) replaces
v7's declarations of `strcpy` and `strcat`.

#lines-to(none)

#source("/usr/src/libc/gen/isatty.c")

The routine `isatty` says whether a descriptor is a terminal, by asking for its
modes with `gtty`, which fails for anything else.

#lines-to(none)
#source("/usr/src/libc/gen/stty.c")

The routines `stty` and `gtty` set and get a terminal's modes. They were system
calls of the sixth edition, and v7 made them library routines over `ioctl`,
which this file keeps. The parameter is now the `struct sgttyb` of
`<sgtty.h>` (#l("stty(int fd, struct sgttyb *ap)"), #l("gtty(int fd, struct sgttyb *ap)")), where v7 named a structure that did not exist.

#lines-to(none)
#source("/usr/src/libc/gen/ttyslot.c")

The routine `ttyslot` gives the slot in `/etc/utmp` of the terminal of the process,
the number of its line in `/etc/ttys`, from the name `ttyname` finds for
the standard input, output, or error. The routine `getttys` reads a line of
`/etc/ttys` and returns the name after its two leading characters,
which are flags for `init`. The v7 code tested the length of the line only after
storing a character, so a line of more than 32 characters was stored one
byte past the end of `line`, and returned without a terminating null.
The test is now made on the last byte (#l("if (*lp =='\\n' || lp == &line[31]) {")), which ends the name.

#lines-to(none)
#source("/usr/src/libc/gen/nlist.c")

The routine `nlist` looks up names in the symbol table of an executable file, for
`ps`, `pstat`, `iostat`, and `dmesg`, which read the kernel through
#f("mem.c") at the addresses it finds in `/unix`. The caller gives an
array of `struct nlist` (`a.out.h`) ended by an empty name. Each
entry found receives its value, and the others are left zero.

The v7 version read an a.out header, whose symbol table followed the text and data.
The port's files are ELF, so `nlist` is rewritten around ELF's layout.
The first 52 bytes, the ELF header, are read into `buf` as words. The
magic number is the word 0x464c457f, the bytes `\177ELF` in the ARM's
order (#l("if(buf[0] != 0x464c457f){")). Word 8 is the offset of the section headers, and the low
half of word 12 their number. Each 40-byte section header is read into
`sh` (#l("read(f, (char *)sh, sizeof sh);", after: "lseek(f, buf[8] + i*40, 0);")) until one of type 2, the symbol table, is found: its offset
and size go to `sa` and `n`, and `sh[6]` names the section that holds
its strings, whose offset and size are kept in `st` and `ss` (#l("st = sh[4];"), #l("ss = sh[5];")). The
string section is then read whole into `strs`
(#l("if(n == 0 || (strs = malloc(ss + 1)) == NULL) {")--#l("strs[read(f, strs, ss) > 0 ? ss : 0] = 0;")). The kernel's is under 3 KB, and reading
each name with a seek and a read of its own made `nlist` most of the
time `ps` takes.

#lines-to("while(n){", lead: true)

The symbols are read `SPACE` at a time. Each is 16 bytes: the offset of
its name in the string section, then its value. ELF names lack the
leading underscore which v7's compiler gave every external name, and
which the callers' tables keep (`_proc`, `_swapdev`), so the first eight
characters of the name are copied after an underscore (#l("c[0] = '_';")--#l("c[9] = 0;")) and
compared with `strncmp`, as v7 compared eight characters. Every match is
given the type `N_EXT|N_DATA`, since the callers use only the value.

The symbols are read with a separate `lseek` each time (#l("lseek(f, sa, 0);")), since the
read of the strings has moved the file offset.

#lines-to(none)

#source("/usr/src/libc/gen/tell.c")

The routine `tell` returns the current offset of a descriptor, by an `lseek` that
moves nowhere.

#lines-to(none)
#source("/usr/src/libc/gen/strcmp.c")

The string routines of v7 are each a loop of a line or two over
pointers, in the style the PDP-11's autoincrement addressing favoured.
The header #f("stdio.h") now declares all of them, and each file includes it for
the prototype of the routine it defines.

The routine `strcmp` compares two strings and returns the difference of the first
pair of characters which differ. The characters are now masked with
`0377` (#l("return((*s1&0377) - (*--s2&0377));")), so that the order of two strings depends only on their
bytes: a character above 0177 compares greater than any ASCII one
whether or not the compiler's `char` is signed. The PDP-11 compiler of v7
had a signed `char`, so v7 ordered such characters first. Nothing in the
system depends on that order.

#lines-to(none)

#source("/usr/src/libc/gen/strcpy.c")

The routine `strcpy` copies `s2`, with its null, to `s1` and returns `s1`. The
doubled parentheses around the assignment used as a condition (#l("while ((*s1++ = *s2++))")) are
those of #f("malloc.c").

#lines-to(none)

#source("/usr/src/libc/gen/strlen.c")

The routine `strlen` counts the characters before the null.

#lines-to(none)

#source("/usr/src/libc/gen/strcat.c")

The routine `strcat` finds the end of `s1`, steps back over the null (#l("--s1;")), and
copies `s2` there.

#lines-to(none)

#source("/usr/src/libc/gen/strncmp.c")

The routines `strncmp`, `strncpy`, and `strncat` are the forms of `strcmp`,
`strcpy`, and `strcat` limited to `n` characters. The first now
compares the differing bytes as unsigned (#l("return(n<0 ? 0 : (*s1&0377) - (*--s2&0377));")), as `strcmp` does, so
that the order does not depend on the signedness of `char`.

#lines-to(none)
#source("/usr/src/libc/gen/strncpy.c")

The routine `strncpy` copies at most `n` characters and pads the rest of the `n`
with nulls. When the source is `n` long or longer the result has no
null at all, which is the form of the fixed fields of directory
entries and of `utmp`.

#lines-to(none)
#source("/usr/src/libc/gen/strncat.c")

The routine `strncat` appends at most `n` characters and always a null.

#lines-to(none)
#source("/usr/src/libc/gen/index.c")

The routine `index` returns a pointer to the first occurrence of a character in a
string, or null. The null that ends the string counts, so that
`index(s, 0)` finds the end. Its partner `rindex` returns the last occurrence.

#lines-to(none)
#source("/usr/src/libc/gen/rindex.c")

The routine `rindex` scans the whole string, remembering the last match (#l("r = NULL;")--#l("} while (*sp++);")).

#lines-to(none)
#source("/usr/src/libc/memcpy.c")

The routines `memcpy` and `memset` copy and fill memory a byte at a time. They have
no v7 original: the compiler may call them for itself, to copy a
structure or clear a large local array, even in code that asks for no
library (#f("libc/lib.mk")), so the library must have them. They are
written as plain loops.

#lines-to(none)
#source("/usr/src/libc/aeabi.s")

The compiler turns 64-bit division, and the conversion of a `long long`
to `double` or `float`, into calls of these four routines, whose names
and conventions the ARM's run-time ABI fixes. They take their arguments
and return their results in the core registers, even under the hard
floating-point convention. The compiler's own library, `libgcc`, has
them too, but its build for these flags is Thumb code, which every
signal handler would then have to allow for (`sendsig`,
#f("machdep.c")). With these, every instruction of a user program is
ARM code from this tree.

When both high words are zero, `__aeabi_uldivmod` divides with the
processor's own `udiv` (#l("udiv\tip, r0, r2")) and finds the remainder
with `mls`. Otherwise it divides a bit at a time, in 64 steps of shift
and trial subtraction (#l("2:")--#l("bne\t2b")). The dividend shifts out
of the top of `r1:r0` into the remainder in `r5:r4`, and each quotient
bit shifts in at the bottom of `r1:r0`. The remainder cannot overflow
when it shifts: before the step which brings in bit _k_ of the dividend,
it is less than the bits above _k_, so it never reaches 2#super[63].

#lines-to("@ Signed:", lead: true)

The signed `__aeabi_ldivmod` divides the magnitudes. The quotient is
negative when the signs differ, and the remainder takes the sign of the
dividend, as C requires of `/` and `%`. Each sign is kept as a mask
of all ones or all zeros (#l("asr\tr4, r1, #31"), #l("asr\tip, r3, #31")).
An exclusive or with the mask followed by a subtraction of it negates a
64-bit number when the mask is all ones and leaves it alone when the
mask is zero.

#lines-to("@ r1:r0 -> double", lead: true)

The routine `__aeabi_l2d` converts the low word as unsigned and the high word as
signed, and adds the high one times 2#super[32]
(#l("vmla.f64\td1, d2, d0", after: "__aeabi_l2d:")). The product is
exact, so the sum is rounded only once, and the result is the nearest
`double`.

#lines-to("@ r1:r0 -> float", lead: true)

A `float` has 24 bits of precision. A conversion through a `double`
would round twice when the magnitude needs more than 53 bits: first to
53 bits, which can land exactly halfway between two `float`s, and then
to 24, which rounds such a tie to even although the true value lay
above it. So `__aeabi_l2f` works on the magnitude and, when it is
2#super[53] or more (#l("cmp\tr1, #0x200000")), folds the low 11 bits
into bit 11 (#l("lsls\tr2, r0, #21")--#l("orrne\tr0, r0, #0x800")).
The value then fits a `double` exactly, and bit 11 still tells the
final rounding whether anything lay below. The sign goes back on at
the end.

#lines-to(none)
#source("/usr/src/libc/gen/swab.c")

The routine `swab` swaps the bytes of each pair, for moving 16-bit data between
machines of the two byte orders, as `tp` and `dd` do. The v7 version swapped through
`int` pointers, an `int` being 16 bits. It now works on bytes (#l("n /= 2;")--#l("}", after: "*pt++ = c;")),
since the port's `int` is 32 bits, and the pairs must stay 16 bits.

#lines-to(none)
#source("/usr/src/libc/gen/ctype_.c")

The table `_ctype_` classifies characters for the macros of `<ctype.h>`. Each entry holds bits for upper and lower case, digit, space, punctuation,
control, and hexadecimal digit. The first entry is for `EOF`, and the
macros index from the second. The table now has room for 256
characters (#l("char _ctype_[1+256] = {")), since the macros now mask their argument to a byte. The
entries beyond 127 are zero, so that no character with the top bit set
belongs to any class. The v7 table stopped at 127, and a negative `char`
indexed before it.

#lines-to(none)
#source("/usr/src/libc/gen/rand.c")

The routine `rand` is a linear congruential generator, returning 15 bits of the
state, and `srand` sets the state. The state is now an `unsigned long`
(#l("static\tunsigned long\trandx = 1;")), so that the multiplication wraps, which C promises only for
unsigned numbers. The sequence is v7's.

#lines-to(none)
#source("/usr/src/libc/gen/perror.c")

The routine `perror` writes its argument, a colon, and the message for the error in
`errno` on the standard error, with `write` rather than through stdio,
so that it works whatever state the program's buffers are in. The
messages are the array of #f("gen/errlst.c").

The v7 code declared `errno`, `sys_nerr`, and `sys_errlist` without `extern`,
which made each a tentative definition merged by the loader with the
real one, and C99 requires a single definition, so the declarations are
`extern` (#l("extern int\terrno;")--#l("extern char\t*sys_errlist[];")). The routine `perror` returns `void`.

#lines-to(none)

#source("/usr/src/libc/gen/errlst.c")

The message for each error number, in the order of `errno.h`
(#f("errno.h")), and their count, `sys_nerr`, for #f("gen/perror.c") and for
programs which print the message themselves.

#lines-to(none)

#source("/usr/src/libc/gen/mktemp.c")

The routine `mktemp` turns a name ending in `X`s into the name of a file which does
not exist: the process id replaces the `X`s, so that two
processes choose different names, and if the name is taken anyway the
first `X`'s place is given the letters `a` to `y` in turn.

The `X`s are now found by looking back from the end only as far as the
start of the name (#l("while (s > as && s[-1] == 'X') {")). The v7 code stepped back while it saw an `X`, and a name
which was all `X`s took it before the start of the array.

#lines-to(none)

#source("/usr/src/libc/gen/l3.c")

An inode holds its thirteen block addresses in three bytes each
(#f("ino.h")), and `l3tol` and `ltol3` convert them to and from `long`s
for #f("iget.c") and the file system programs. A `long` on the PDP-11
was two words, the high word first, and each word had its low byte
first, so v7 skipped the most significant byte in the middle of each
group. The ARM keeps a `long`'s bytes in order from the least
significant, so the three low bytes are the first three and the fourth
is skipped (#l("b++;", before: "l3tol(long *lp, char *cp, int n)")) or zeroed at the end, in the branch after `#else`. The on-disk order of the
three bytes is therefore the ARM's, which `mkfs` (#f("cmd/mkfs.c")), built
for the host, shares.

#lines-to(none)

#source("/usr/src/libm/sqrt.c")

The routine `sqrt` takes the square root by Newton's method. First `frexp` splits the
argument into a fraction and a power of two. The exponent is made even
by doubling the fraction, so that half of it is the exponent of the
root, and `0.5*(1.0+x)` is a first guess for the root of the fraction.
The guess is scaled by the halved exponent, 30 bits at a time while it
is large so that the shifts of `1L` stay within a `long`, and five
iterations of `temp = (temp + arg/temp)/2` then reach the precision of
a `double`. A negative argument sets `errno` to `EDOM` and returns zero.

The v7 library defined `errno` in every file that set it, and declared `frexp`
itself. Here `errno` is defined once, in #f("libc/syscall.s"),
and declared by `errno.h`, and `frexp` by #f("math.h"), which is now
included (#l("#include <math.h>")).

#lines-to(none)

#source("/usr/src/libm/log.c")

The routine `log` reduces its argument with `frexp` to a fraction between
$sqrt(2)/2$ and $sqrt(2)$ and a power of two, and evaluates a rational
approximation in `z = (x-1)/(x+1)`, whose coefficients come from Hart
and Cheney's tables. The power of two adds `exp` times $ln 2$. The routine `log10`
divides by $ln 10$. An argument that is not positive sets `errno` to
`EDOM` and returns `-HUGE`.

The changes are those of #f("libm/sqrt.c"): the headers declare `errno` and `frexp`, not the file.

#lines-to(none)

#source("/usr/src/libm/exp.c")

The routine `exp` computes $e^x$ as $2^(x log_2 e)$: the integer part of the
exponent goes to `ldexp`, and $2^f$ for the fraction comes from a
rational approximation, again from Hart and Cheney. Arguments beyond
`maxf` give zero or `HUGE` with `ERANGE`.

A NaN argument is now returned at once (#l("if(arg != arg)"), #l("return(arg);")). The PDP-11 had no NaN,
and v7 went on to convert `floor(arg)` to `int`, which for a NaN C99
leaves undefined. The header `errno.h` declares `errno`, as in #f("libm/sqrt.c").

#lines-to(none)

#source("/usr/src/libm/sin.c")

The routines `sin` and `cos` share `sinus`, which reduces the argument to a quarter
period: `x` is measured in quarter turns, its integer part selects the
quadrant, and the fraction goes to a polynomial ratio. Below 32764
quarter turns the integer part fits an `int`. Above, `modf` takes it, so
that a large argument does not overflow.

An infinity or NaN now gives NaN at once (#l("if(x - x != 0)"), #l("return(x - x);")): both make `x - x`
non-zero, and either would have reached the conversion of the quadrant
to `int` with no value in range. The prototypes replace v7's local
declarations of `sinus` and `modf`.

#lines-to(none)

#source("/usr/src/libm/atan.c")

The routines `atan` and `atan2` reduce their arguments to the range from 0 to
$sqrt(2) - 1$ and use a polynomial ratio there. A call `atan2(y, x)` picks the
quadrant from the signs of its arguments, and handles a zero or
negligible `x` with `(arg1+arg2)==arg1`, so that it never divides by
zero.

The declaration `double static` (#l("static double sq2p1\t =2.414213562373095048802e0;")) is rewritten `static double`, the order C99
requires of new code, and the inner routines are static and declared
with prototypes (#l("static double satan(double arg), xatan(double arg);")).

#lines-to(none)

#source("/usr/src/libm/pow.c")

The routine `pow` raises `arg1` to the power `arg2` as `exp(arg2*log(arg1))`. A
negative base is allowed only with an integral exponent, and the sign of
the result follows its parity.

The v7 code tested the exponent by converting it to a `long`, which C99 leaves
undefined for an exponent outside the range of `long`. Now `modf` tests
it at any magnitude (#l("if(modf(arg2, &h) != 0.)")): an exponent is integral if its fractional part
is zero, and odd if half of it is not (#l("if(modf(arg2/2, &h) != 0.)")).

#lines-to(none)

#source("/usr/src/libm/floor.c")

The routine `floor` takes the integer part with `modf`, which truncates towards
zero, and moves a negative number with a fraction down by one. The routine `ceil` is
`-floor(-d)`. The include of #f("math.h") replaces v7's declaration of
`modf`.

#lines-to(none)


= Part Four: The Commands

== Classic Programs <ch-classic>

#source("/usr/src/libm/fabs.c")

The routine `fabs` returns the absolute value of a double.

#lines-to(none)
#source("/usr/src/libm/asin.c")

The routines `asin` and `acos` are computed from `atan` (#f("libm/atan.c")) and
`sqrt`: $"asin" x = "atan"(x / sqrt(1 - x^2))$, with the complementary
form near 1 where that quotient loses accuracy (#l("if(arg > 0.7)")--#l("temp = atan(arg/temp);")). An argument
outside $[-1, 1]$ sets `errno` to `EDOM`.

#lines-to(none)
#source("/usr/src/libm/tan.c")

The routine `tan` reduces its argument to an octant by multiplying by $4/pi$ and
taking the fraction with `modf`, then evaluates a rational
approximation from Hart and Cheney's collection, the source of most of
the library's coefficients. In two octants it returns the reciprocal,
and `HUGE` with `ERANGE` where the tangent is infinite. The v7 file
defined `errno` again. It now uses the library's one definition
(#f("libc/syscall.s")), whose reason the commentary there gives.

#lines-to(none)
#source("/usr/src/libm/sinh.c")

The routine `sinh` uses a rational approximation for small arguments, where the
difference of exponentials would lose accuracy, and `exp` beyond. For
arguments above 21 the smaller exponential no longer matters and the
larger is halved alone. The routine `cosh` uses `exp` throughout.

#lines-to(none)
#source("/usr/src/libm/tanh.c")

The routine `tanh` is `sinh` over `cosh`, except above 21, where it is $plus.minus 1$
to the precision of a double and the quotients would overflow.

#lines-to(none)
#source("/usr/src/libm/hypot.c")

The routine `hypot` computes $sqrt(a^2 + b^2)$ without overflowing for large
arguments, by dividing by the larger first. The routine `cabs`, the absolute value of a complex number, calls it.

#lines-to(none)
#source("/usr/src/libm/j0.c")

The routines `j0` and `y0` are the Bessel functions of order zero of the first and
second kinds. Below 8 each is a rational approximation in $x^2$, `y0`
adding a multiple of $J_0(x) log x$. Above, `asympt` computes the two
amplitude functions of the asymptotic form, and the result is their
combination with a sine and a cosine. The coefficients are from Hart
and Cheney. The v7 files defined `errno` here too, as in `tan`, and in `j1` and `jn` did the
same.

#lines-to(none)
#source("/usr/src/libm/j1.c")

The routines `j1` and `y1` are the Bessel functions of order one, built in the same
way as `j0` and `y0`.

#lines-to(none)
#source("/usr/src/libm/jn.c")

The routines `jn` and `yn` give the Bessel functions of any integer order. Both `yn` and,
for an order below the argument, `jn` recur forwards from the functions
of orders 0 and 1. Forward recurrence is unstable for `jn` when the
order exceeds the argument, so it then evaluates a continued fraction
for the ratio of consecutive orders and recurs backwards, scaling the
result by `j0` (#l("recurs:")--#l("return(t*j0(x)/b);")).

#lines-to(none)
#source("/usr/src/cmd/ed.c")

The editor of v7 is `ed`, and the program in this book in which its
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
conditions, such as `while ((*p2++ = *p1++))` (#l("while ((*p2++ = *p1++))", after: "p2 = savedfile;")), have gained the
doubled parentheses of #f("malloc.c").

The include of `stdio.h` (#l("#include <stdio.h>")) is new. The editor uses no standard I/O at all, but in the port
the header carries the prototypes of the system call stubs (#f("stdio.h")).
With it, v7's own `#define EOF -1` (deleted after 13) has gone, since
the header defines `EOF` with the same value. The `#define NULL 0` (#l("#define\tNULL\t0"))
is v7's, and since it repeats the header's definition exactly, C allows
it to stand.

The codes `CBRA` to `CBACK` (#l("#define\tCBRA\t1")--#l("#define\tCBACK\t14")) are the instructions of the
compiled expressions, discussed with `compile`. `NBRA` limits an
expression to five `\(...\)` groups.

#lines-to("char\tQ[]\t= \"\";")

The state of the editor. The pointers `zero`, `dot`, and `dol` point into the array of line pointers, `zero` at its start, an element which stands for the
nonexistent line 0, `dol` at the last line, and `dot` at the current
one. Line `n` is `zero[n]`. The pointers `addr1` and `addr2` are the addresses given
to the current command. The count `nlall` (#l("unsigned nlall = 128;")) is the number of elements
allocated, and is enlarged as the file grows.

The temporary file is `tfile`, `tline` the position in it at which the
next line will be written, and `ibuff` and `obuff` the two block
buffers, holding blocks `iblock` and `oblock`. The array `names` holds the marks
set by the `k` command, `globp` the text of a `g` command while it is
being executed, and `linebuf` the line being worked on.

The pointers `oldhup` and `oldquit` (#l("void\t(*oldhup)(int sig);")--#l("void\t(*oldquit)(int sig);")) are now pointers to `void` functions of
the signal number, which is what `signal` returns in the port
(#f("sys/signal.s")). The local declarations of `lseek`, `mktemp`,
`malloc`, and `realloc` have gone, since #f("stdio.h") declares them.
The prototypes (#l("int\t*address(void);")--#l("int\tgetcopy(void);")) cover every procedure, since in this file
nearly every one is used before its definition. The name of the
temporary file, `tfname` (#l("char\ttfname[] = \"/tmp/eXXXXX\";")), is now an array holding the template
which `mktemp` fills in, and v7 passed `mktemp` the string constant itself,
which the PDP-11 compiler put in writable data, but which is now part
of the read-only text, where `mktemp`'s stores fault.

#lines-to("int", after: "int\tgetcopy(void);")

The routine `main` sets up the signals. The test of `SIGTERM` (#l("if ((int)signal(SIGTERM, SIG_IGN) == 0)")) installs
`quit` only if the signal was not already ignored, and `SIG_DFL` is 0. The
tests at (#l("if (((int)oldintr&01) == 0)")) and (#l("if (((int)oldhup&01) == 0)")) are the same in another form: `SIG_IGN` is 1,
so the low bit of the old action is set only if the signal was being
ignored, as it is for a command run in the background. These casts
from a function pointer to `int` lose nothing on the ARM, whose
pointers and `int`s are both 32 bits.

A file named as an argument is read by placing `r` in `globp`, as
though it had been typed as the first command. The array of line
pointers is allocated, the temporary file named, and `setjmp` marks
the place to which `error` will return after each mistake, and `mktemp` (#l("mktemp(tfname);"))
fills in the array `tfname`. The routine `quit` now
takes the signal number, being also a handler, and the direct call
passes 0. The v7 code declared the three handlers inside `main`, as functions
returning `int`. The prototypes above replace that declaration, and
`oldintr` (#l("void (*oldintr)(int sig);")) has the type of a handler.

#lines-to("void", after: "}")

The main loop is `commands`. It first collects up to two addresses,
separated by `,` or `;`. A `;` also sets `dot` to the first address,
so that the second is reckoned from it. When only one address is
given, both `addr1` and `addr2` are set to it. The local declaration
of `getfile` and `gettty` at the head of `commands` in v7 has gone, as the
prototypes cover them.

#lines-to("case 'a':")

The commands themselves. Most call `setdot`, `setall`, `setnoaddr`, or
`nonzero` to supply default addresses or reject wrong ones, then
`newline` to check that nothing follows, and then do their work.

Five comments `/* fallthrough */` are new (#l("/* fallthrough */", after: "c = 'e';"), #l("/* fallthrough */", after: "case 'l':"), #l("/* fallthrough */", after: "case 'Q':"), #l("/* fallthrough */", before: "case 'r':"), #l("/* fallthrough */", after: "wrapp++;")).
Each marks a case which runs on into the next, and `-Wextra`
warns of such a fall-through unless it is marked. The one at (#l("/* fallthrough */", before: "case 'r':"))
follows a call of `quit`, which in fact never returns: it exits, or
reports an error and jumps back to `main`. The compiler is not told
this, and the comment satisfies it.

Some cases show the representation at work. A mark (#l("names[c-'a'] = *addr2 & ~01;")) records the
line pointer itself, not the line number, with its low bit cleared, so
that a mark follows its line however lines are added or deleted before
it. The search for a mark (#l("for (a1=zero; a1<=dol; a1++)", after: "case '\\'':")) compares pointers. The command `u` (#l("if ((*addr2&~01) != subnewa)")) undoes the
last substitution by putting back the line pointer which it replaced,
`subolda`. The old text is still in the temporary file, since nothing
there is ever overwritten. The v7 code masked the line number which `=` reports
with `077777` (#l("count = addr2-zero;")), a relic of the PDP-11's 16-bit `int` which
limited the report to 32767. The mask is gone, and `=` reports any
number of lines.

#lines-to("int *")

The routine `address` parses one address, a number, `.`, `$`, a mark, or a pattern
between `/` or `?`, followed by any number of `+` and `-` offsets. A
pattern is compiled and the lines searched forwards or backwards from
`dot`, wrapping round at the ends, until a match is found or the search
returns to `dot`.

#lines-to("void")

The address checks, and `newline`, which accepts a trailing `p` or `l`
to print the result. The routine `filename` reads a file name after the command
letter, or supplies the remembered one, `savedfile`. The first name
given, or any given to `e` or `f`, is remembered.

#lines-to("void", after: ";")

The handler `onintr` answers an interrupt with "?" by way of `error`, so that an
interrupted command is abandoned and the editor waits for the next.
When the terminal hangs up, `onhup` saves the buffer in `ed.hup`.

The routine `error` prints "?" and its argument, discards the rest of the input
line, and jumps back to `main`. The `lseek` of the standard input to
its end (#l("lseek(0, (long)0, 2);")) matters when `ed` reads its commands from a file: one
mistake abandons the rest of the script, rather than running the
following commands on a buffer in an unknown state.

#lines-to("int")

The routine `getchr` reads one character, from `peekc` if a character has been
pushed back, from `globp` during a global command, and otherwise from
the standard input, one byte per `read`. Reading unbuffered is
deliberate: when `!` runs the shell, the shell reads its command from
the same input, and must find it there, not in `ed`'s buffer.

The routine `gettty` reads a line of text for `a`, `i`, and `c`, ending at a line
holding only ".". The routine `getfile` reads a line of a file, through `genbuf`.
Characters with the top bit set are refused, except that a buffer
containing them is first passed to `crblock` for decryption under `-x`.

#lines-to("void")

The routine `putfile` writes lines `addr1` to `addr2` to the file `io`, gathering
them in `genbuf` and encrypting each block first under `-x`. The variable `count`
totals the characters, which `exfile` prints.

#lines-to("int", after: "}")

The routine `append` adds lines after `a`, taking them one at a time from the
procedure `f` (`gettty`, `getfile`, `getsub`, or `getcopy`) until it
returns `EOF`. Each line is written to the temporary file by `putline`,
and its pointer is inserted after `dot` by moving the pointers above it
up by one.

When the array is full it is enlarged by 512 elements. The `free`
before `realloc` (#l("free((char *)zero);")) relies on v7's `realloc` accepting a block freed
since the last `malloc` (#f("gen/malloc.c")), as `cron` and `diff` do
(#f("cmd/cron.c")). Since the array may move, `dot` and `dol` are
adjusted. Any other pointer into it held by a caller is the caller's
problem, which `substitute` and `move` solve by comparing `zero` before
and after. The cast `(int)nlall` (#l("if ((dol-zero)+1 >= (int)nlall) {")) is new: `nlall` is `unsigned`,
and the comparison with a signed difference of pointers draws a
warning from `-Wextra`.

#lines-to("void")

The routine `callunix` runs `sh -t`, which reads one line of input, the rest of the
`!` command, executes it, and exits. Its `execl` (#l("execl(\"/bin/sh\", \"sh\", \"-t\", (char *)0);")) ends with
`(char *)0`, as in #f("cmd/getty.c"). The variable `savint` now has the type of a
signal handler, and `pid` is declared separately, since it is not a
function pointer. The routine `quit` refuses to leave a modified buffer once,
unless `vflag` is clear. A second `q` succeeds.

#lines-to("void", after: "exit(0);")

The routine `rdelete` removes the pointers of the deleted lines by moving the rest
down. The text stays in the temporary file. Used for the
common case `g/.../d`, `gdelete` compacts the array in one pass over the lines
marked by `global`, instead of one call of `rdelete`, and so one pass,
per line. It is now `static`, since nothing calls it before its
definition, and `-Wmissing-prototypes` asks no prototype of a static
procedure.

#lines-to("char *")

Here is the representation of a line pointer. The temporary file is
written only at its end, and each line is stored there as a
null-terminated string. The offset `tline` counts the file in units of two bytes,
and a line occupies a whole number of four-byte units (#l("tline += (((lp-linebuf)+03)>>1)&~1;")), so that a
pointer is always even. Its low bit is free, and `global` uses it to
mark lines. Of the remaining bits, bits 1 to 7 give the offset within
a block of 512 bytes, in four-byte units, and the bits above them the
block number.

The routine `getline` copies a line into `linebuf`, continuing at the start of the
next block (`tl += 0400`) when a line runs over the end of one.
The routine `putline` stores `linebuf` at `tline` and returns its pointer. A
newline within the text, as a substitution can produce, ends the line
and leaves `linebp` at the rest, for `getsub` to collect.

The v7 editor kept a pointer in the sixteen bits of a PDP-11 `int`: the block
number had eight, and the temporary file at most 255 blocks, about
130 KB, at which `getblock` reported `TMP`. On the ARM `int` has 32 bits,
and the masks which held the arithmetic to sixteen are gone: `tline`
advances by an even number (#l("tline += (((lp-linebuf)+03)>>1)&~1;")), and the block number is the whole of
the pointer above bit 7 (#l("bno = atl>>8;")). A file of tens of thousands of lines now
fits. The temporary file may grow until the disk is full, when a write
fails and `blkio` reports `TMP` instead.

#lines-to("char *", after: "}")

The routine `getblock` returns the address in a buffer of the byte at `atl`, and in
`nleft` the number of bytes from there to the end of the block. Two
buffers serve: `ibuff` for reading and `obuff` for writing. Since the
file is written only at its end, the block being written is always the
last, and `obuff` holds it until writing moves to a new block. Reading
may wander anywhere, and `ibuff` is refilled as needed, written back first
if a write has gone into it (`ichanged`), which happens when the block
being read is also the one at the end. Under `-x` the temporary file is
encrypted too, with its own key.

The v7 code declared `read` and `write` here as external functions returning
`int`. They are now declared in #f("stdio.h"), with `char *` buffers,
which is the type of `iofcn` in `blkio`'s prototype, so that either may
be passed to it.

#lines-to("void", after: "error(T);")

The routine `init` empties the buffer. It makes a fresh temporary file, created with mode
0600 and opened for reading and writing, sets `tline` to 2, and clears the marks and the buffers.

#lines-to("void", after: "}")

The routine `global` reads the command list of `g` or `v` into `globuf`, then marks,
in the low bit of each line pointer, the lines which match (or for `v`
do not). It then repeatedly finds the first marked line, clears its
mark, makes it `dot`, and runs `commands` with `globp` pointing at the
command list. When the list is exhausted, `getchr` returns `EOF`, and
`commands` returns (#l("case EOF:")). The search starts again from `zero` each
time, because the commands may have added, deleted, or moved lines.
The marks travel with the pointers.

#lines-to("void", after: "}")

The routine `join` concatenates lines `addr1` to `addr2` in `genbuf`, writes the
result as a new line, and deletes the rest.

#lines-to("void", after: "}")

The routine `substitute` applies `s` to each line in range which matches, and `dosub`
builds the new line in `genbuf` from the part before the match, the
replacement, and the part after, and copies it back to `linebuf`. With
the `g` suffix, matching resumes after the previous match
(`execute(1, ...)`). The new line is written, its pointer replaces the
old one, and marks on the old line are moved to the new. If the
replacement contained escaped newlines, `putline` stopped at the first,
and `append` with `getsub` adds the remainder as further lines.

The routine `compsub` reads the replacement. An escaped character is stored with
its top bit set, which is how `dosub` tells `\&` and `\1` from `&` and
`1`, and `ed` refuses characters with the top bit set in its text, so the
bit is free for the purpose. The `&0377` at (#l("while ((c = *rp++&0377)) {")), v7's, kept such a
character positive where `char` was signed. The local declaration of
`getsub` has been removed, as the prototype now precedes it.

#lines-to("void", after: "return(sp);")

The routine `move` implements `m` and, with `cflag`, `t`, which first appends a
copy of the lines at the end of the buffer and then moves the copy. A
move of a block of line pointers to another place is a rotation of the
segment between them, done with three reversals in place: reversing
each part and then the whole leaves the two parts exchanged. No text
is copied, and no extra memory is needed. The local declaration of
`getcopy` has been removed.

#lines-to("void", after: "return(0);")

The routine `compile` translates a regular expression, read through `getchr` up to
the delimiter `aeof`, into `expbuf`. An empty expression reuses the
previous one. Each item becomes a code followed by its operand, if any. The code
`CCHR` takes the character, `CDOT` nothing, `CCL` or `NCCL` a class,
`CBRA` and `CKET` the number of a group, and `CBACK` the number of the
group referred to. `$` is `CDOL` only at the end, and `^`
sets `circfl` only at the start.

The pointer `lastep` is the address of the last item compiled, so that a `*` can
be applied to it after the fact, by setting `STAR` in its code. The
codes of items which may be starred are even, so that the closure of
each has the odd code next above it.

A class is stored as its count, followed by the characters
themselves. A range `a-z` is expanded into every character between its
ends. The program `grep` stores a class as a bit map instead (#f("cmd/grep.c")).

#lines-to("int", after: "}")

The routine `execute` tries the compiled expression on line `addr`, or, when `gf`
is set, on the rest of the current line after the previous match, for
the `g` suffix of `s`. The pointers `loc1` and `loc2` receive the beginning and end
of the match. The pointer `locs` records where the resumed search started, so that
a closure cannot match an empty string there a second time and repeat
the substitution forever. As in `grep`, if the expression begins with
a literal character, `advance` is tried only where that character
occurs.

The masks `&0377` (#l("braslist[c&0377] = 0;"), #l("braelist[c&0377] = 0;")) are new: `c` is a `char`, and a
subscript of that type draws a warning from `-Wall`.

#lines-to("int", after: "}")

The matcher is `advance`. It walks the compiled expression and the line
together, each code testing and consuming characters, and returns 1 at
`CEOF`, leaving `loc2` at the end of the match. A closure first takes as
many characters as will match (`CCHR|STAR` and the others), and then,
at `star`, gives them back one at a time, calling `advance`
recursively on the rest of the expression from each point, until the
rest matches or nothing is left to give back. The match found is
therefore the leftmost, and the longest which allows the rest to
match. This backtracking is the whole of the algorithm, and it is what
`grep` copied.

A closure of a back reference (#l("case CBACK|STAR:")) gives back whole copies of the
group. If no number of copies will do, the match fails (#l("return(0);", after: "lp -= braelist[i] - braslist[i];")), as in
`grep`'s copy of the case. The v7 code had `continue` here, which went on
matching the rest of the expression from `lp`, by then before the point
where the closure began, so that `/\(ab\)\1*a/` matched the line `ab`.

The masks `&0377` (#l("braslist[*ep++&0377] = lp;"), #l("braelist[*ep++&0377] = lp;")) are new, for the same reason as in
`execute`.

#lines-to("int", after: "}")

The routine `backref` compares the text of a group with the line, and `cclass` searches
a class's list for a character. The null at the end of the line matches
no class, negated or not.

#lines-to("void")

The output routines. The routine `putchr` collects characters in `line` and writes
it when a newline arrives or 64 characters have gathered. Under `l` it
shows a tab as `>` struck over `-`, a backspace as `<` struck over `-`,
and other control characters as a backslash and two octal digits, and
folds long lines.

The editor defines its own `puts`, which takes the place of the library's.
It now returns `int` with the value 0, to agree with the declaration of
`puts` in #f("stdio.h"). The v7 version returned nothing.

#lines-to("void", after: "linp = lp;")

The encryption of `-x` and `x`. The key is read with echo turned off
(`getkey`), and passed with two characters of salt to
`/usr/lib/makekey`, which turns it into 13 characters by way of the
password-encryption routine of #f("gen/crypt.c"). The routine `crinit` derives from
them three permutations of the 256 byte values, the tables of a rotor machine, a scrambler `t1`, its inverse `t2`, and
a self-inverse reflector `t3`. The routine `crblock` passes each byte through the scrambler, the
reflector, and back through the inverse, with the rotor positions
`n1` and `n2` stepping on with each byte of the file like the wheels
of a counter, so that
encryption and decryption are the same operation. This is the cipher
of the `crypt` command. For the temporary file, `makekey` at the end
mixes the time and the process id into the key, so that each session's
file is encrypted differently. The `execl` calls (#l("execl(\"/usr/lib/makekey\", \"-\", (char *)0);"), #l("execl(\"/lib/makekey\", \"-\", (char *)0);")) end with
`(char *)0`, as in #f("cmd/getty.c").

The signal handler pointer in `getkey` (#l("void (*sig)(int sig);")) has the new type of a
handler. The variable `t` in `makekey` (#l("long long t;")) is now a `long long`, the 64-bit time
which `time` stores (#f("param.h")). As before, only its low 32 bits
reach the key. The variable `seed` in `crinit` (#l("unsigned long seed;")) is now `unsigned long`, as in
the `crypt` command: multiplied by thirteen characters, it overflows 32
bits within a few steps, which is undefined for v7's signed `long`. The
unsigned product wraps round to the same bits, and the cast at #l("random = (long)seed % 65521;")
keeps v7's signed remainder, so that a file encrypted by `crypt` can
still be read with `ed -x`.

#lines-to(none)
#source("/usr/src/cmd/grep.c")

The program `grep` prints the lines of its files which match a regular expression.
Its name is the editor's command `g/re/p`, and its regular-expression
code is the editor's (#f("cmd/ed.c")), lifted out and adapted to a
program which reads a string from its argument list instead of a
terminal, and which needs to know only whether a line matches, not
where. The reader who has followed `compile`, `execute`, and `advance`
in `ed` will find the same three procedures here, with the same codes
and the same recursive treatment of the closure `*`. The differences
are noted below as they occur.

The `&0377` masks on subscripts of type `char`
(#l("} else if (islower(*p&0377)) {"), #l("braslist[*ep++&0377] = lp;")--#l("ct = braelist[*ep++&0377] - bbeg;", after: "case CBACK|STAR:")) are new: such a subscript draws a warning from `-Wall`,
and the mask makes it an `int`. On the PDP-11, where `char` was signed,
v7's `islower(*p)` (#l("} else if (islower(*p&0377)) {")) would have indexed the character table with a
negative number for a byte with the top bit set. On the ARM `char` is
unsigned and the masks change no value.

#lines-to("void\tcompile(char *astr), execute(char *file), succeed(char *f);")

The codes (#l("#define\tCBRA\t1")--#l("#define\tCBACK\t18")) are `ed`'s, with one difference: `CBACK` is 18
where `ed` has 14. `STAR` is or'ed into a code to mark a closure. The
codes of the items which may be starred are even, so that each closure
has the odd code next above its item's. `NCCL` is defined but never
used, since a negated class is
compiled as an ordinary class with its bits inverted.

The buffers are larger than `ed`'s: `ESIZE` 256 against 128, and nine
bracketed subexpressions (`NBRA`) against five. The table `bittab` gives the bit
for each of the eight positions within a byte. It is now
`unsigned char` (#l("unsigned char\tbittab[] = {")), since the last of them, 128, is not a value a signed `char`
can hold.

The routine `main` collects the flags. With `-y`, each lower-case letter outside
brackets is replaced by a class matching both cases, so that `abc`
becomes `[Aa][Bb][Cc]`. Text within brackets is copied as it stands.
The exit status is 0 if anything matched, 1 if nothing did, and 2 for
an error.

#lines-to("void", after: "}")

The routine `compile` translates the pattern into `expbuf`. As in `ed`, `lastep`
remembers the start of the last item compiled, so that a following
`*` can set `STAR` in its code. A `*` at the start, or after `\(` or
`\)`, is an ordinary character. A `^` is recognized only at the start
(#l("if (*sp == '^') {")), and sets `circf`. A `$` only at the end (#l("if (*sp != '\\0')")). The editor reads the
pattern a character at a time through `getchr` up to a delimiter, and
an empty pattern there means "the previous one", and `grep` simply takes a
string ending in a null.

#lines-to("case '[':")

Character classes are where the two programs part company. The editor
stores a class as a count followed by the characters themselves,
expanding a range such as `a-z` into all its members, and `cclass`
searches the list for each character of the line. The program `grep` stores a map
of 16 bytes, one bit for each of the 128 seven-bit characters, so that
testing a character costs one index and one mask (#l("c = *lp++ & 0177;", after: "case CCL:")--#l("if(ep[c>>3] & bittab[c & 07]) {")), and a
range costs no more space than a single character. A negated class has
every bit inverted, except the bit for the null byte (#l("ep[0] &= 0376;")), which must
never match: it marks the end of the line.

The masks `&0177` in (#l("for (c = sp[-2]&0177;")) and (#l("ep[(c&0177)>>3] |= bittab[c&07];")) are new. Each character of the
class set the bit `c`, and a character with its top bit set would have
set a bit beyond the 16 bytes, in whatever followed in `expbuf`. The
matcher looks only at the low seven bits of each character of the line
(#l("c = *lp++ & 0177;", after: "case CCL:")), so the compiler now does the same with the members of a class
and the ends of a range.

#lines-to("case '\\\\':")

Parentheses `\(` and `\)` compile to `CBRA` and `CKET` with the number
of the subexpression, and `\1` to `\9` to `CBACK`. Unlike `ed`, `grep`
checks at compile time that at least that many subexpressions have
been closed (#l("if((c -= '1') >= closed)")). Any other escaped character stands for
itself.

The `goto defchar` (#l("goto defchar;", after: "*ep++ = CBACK;")) is new. The v7 code fell through from the escape case
into the default case below. The jump says so explicitly, which
`-Wextra`'s warning about implicit fall-through demands.

#lines-to("void")

The routine `execute` reads each line into `linebuf` and tries the expression at
each position in turn. A line longer than the buffer is cut, and its
remainder is read as the next line. With `circf` the match is tried
only at the start. If the expression begins with a literal character,
`advance` is called only where that character occurs. This is `ed`'s
`execute` without the bookkeeping: `ed` must record in `loc1` and
`loc2` where the match lies, for the substitute command, and carries a
flag for matches resumed in the middle of a line.

#lines-to("int")

The routine `advance` matches the expression at `ep` against the line at `lp`,
returning 1 for a match. Each code consumes one character or tests a
position. `CEOF`, the end of the expression, is success whatever
remains of the line, since a match need not extend to its end.

#lines-to("case CBRA:")

`CBRA` and `CKET` record where a subexpression began and ended, and
`CBACK` compares the text so recorded with the line. A back reference
under `*` matches the text as many times as it can, then gives back one
copy at a time until the rest of the expression matches. Note the
`return(0)` (#l("return(0);", after: "lp -= ct;")) when no number of copies will do. In v7, `ed` ended the
same case with `continue`, which went on to match the rest of the
expression from a point before the repetition started, and `grep`'s version
is the correct one, and `ed` now has it too (#f("cmd/ed.c")).

#lines-to("case CDOT|STAR:")

The closures. Each first consumes as many characters as it can,
leaving `curlp` at the start of the run and `lp` one beyond its end.
Then, at `star`, it tries the rest of the expression from each
possible end of the run in turn, longest first, so that the match found
is the leftmost-longest one which allows the remainder to match.

Here `grep` is more careful than `ed`. If the run is empty (#l("if(--lp == curlp) {")), it
carries on without a recursive call. If the next item is a literal
character, it tries only the ends at which that character follows,
which saves a call of `advance` for each position that cannot succeed.
The loop of `ed` instead calls `advance` at every position, but stops at
`locs` (#f("cmd/ed.c")), which `grep` does not need.

#lines-to("void")

The routine `succeed` prints a matching line, preceded as the flags require by the
file name, the block number (counted in `BSIZE` units of 512 bytes from
#f("param.h")), and the line number. With `-c` it only counts; with
`-l` it prints the name of the file and seeks to its end, so that the
next read ends the file at once. The call `printf("%D")` (#l("printf(\"%D\\n\", tln);")) is v7's form for
a `long`, which the port's `printf` still accepts
(#f("stdio/doprnt.c")). The local declaration of `ftell` in v7's `succeed`
has gone, since #f("stdio.h") declares it.

#lines-to(none)
#source("/usr/src/cmd/diff.c")

The program `diff` reports the differences between two files as the smallest set of
lines to be deleted from the first and added from the second, in the
form of `ed` commands. Finding that set is the problem of the longest
common subsequence: the lines common to both files, in order, of which
there are as many as possible. Every line not in it is a change.

The method is the one published by J. W. Hunt and M. D. McIlroy in 1976
as a Bell Laboratories technical report, "An Algorithm for Differential
File Comparison", which credits Harold Stone with its central idea. The
procedure which carries it out is accordingly named `stone`. The long
comment at the head of the file is the authors' own summary. The plan
is as follows.

First each line is reduced to a hash value (`readhash`), so that both
files can be held in memory as arrays of integers, and matching lines
are thereafter found by comparing numbers. A common prefix and suffix
are set aside (`prune`), since they belong to every longest common
subsequence. The lines of each file are sorted by hash value, and the
sorted arrays are merged (`equiv`). This gathers the lines of the second
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

The lone `#` (#l("#", before: "/*\tdiff - differential file comparison")) is the same relic as in #f("mem.c").

#lines-to("#include <stdio.h>")

The macros `low` and `high` split a `long` into 16-bit halves for the hash.
Each `struct line` holds a line's serial number and hash value. The comments
"overlaid on" (#l("int *class;\t/*will be overlaid on file[0]*/")--#l("long *ixnew;\t/*will be overlaid on file[1]*/")) refer to the reuse of memory described under
`main`.

The declarations of `fopen` and `mktemp` in v7 are gone, since the port's
#f("stdio.h") declares both. The prototypes (#l("void noroom(void), unravel(int p), check(char **argv),")--#l("int search(int *c, int k, int y), skipline(int f), readhash(FILE *f);")) are for the
procedures used before their definitions. Those defined before use
have been made `static` instead, which spares them a prototype.

#lines-to("static void")

The routine `done` is also the handler for the signals caught while a temporary
file exists, and now takes the signal number. The direct calls of it
pass 0. The routine `talloc` gains a `return(p)` (#l("return(p);", before: "static char *ralloc(char *p,int n)\t/*compacting reallocation */")) after `noroom`, which
never returns, though the compiler is not told so, and would otherwise
warn that control reaches the end of a function which returns a value, and
`p` is null there. The local declarations of `malloc` in `talloc` and
`realloc` in `ralloc` have gone, since #f("stdio.h") declares both.

The routine `ralloc` is a "compacting reallocation". It frees the block, frees
`dummy`, and allocates `dummy` again. The block `dummy` was the first
allocated (#l("dummy = malloc(1);", after: "mesg(\"arg count\",empty);")), so it lies low in the arena. The `free` of v7 leaves the
allocator's search pointer at the block just freed, `malloc(1)` takes
that block again and leaves the pointer just beyond it, and the
`malloc` inside `realloc` therefore starts searching from near the
bottom of the arena (#f("gen/malloc.c")). The block is moved to the lowest place
which will hold it, and the arena is kept compact. Like `cron`'s use
(#f("cmd/cron.c")), it relies on `realloc` of a freed block.

#lines-to("static void", after: "}")

The routine `sort` is a Shell sort, ordering by hash value and, among equal values,
by serial number, so that each equivalence class ends up with its lines
in their order in the file. The test for "wraparound" (#l("if(aim < ai)")) guarded
against a pointer passing the top of the PDP-11's 64 KB address space.
It can no longer succeed.

Three changes. The port now initializes `m` (#l("register int i,j,m = 0;")): for an empty file the first
loop does not run, and v7 then halved an undefined `m`, which the
compiler's analysis at `-Os` reports. The inner loop counts with an
index `i` (#l("for(i = j; i > 0; i -= m) {"), #l("ai = &a[i];")), where v7 stepped the pointer `ai` down by `m`
until it was no longer above `a`. The last step took `ai` below the
start of the array, and C defines neither such a pointer nor its
comparison. The index may go below zero freely. The parentheses at #l("(aim->value == ai[0].value &&")
and #l("aim->serial > ai[0].serial))") are new, as in #f("slp.c").

The routine `unsort` uses the serial numbers to put the class indices of the first
file back into the file's own order.

#lines-to("static void", after: "free((char *)a);")

If one argument is a directory, the file of the same base name within
it is meant. The v7 code built that name in 100 bytes, whatever the lengths of
the two names. The port allocates what the directory, the `/`, the
other argument, and the null need (#l("b1 = *pa1 = malloc(strlen(a1)+strlen(a2)+2);")), the whole of the other
argument being copied before its base name is moved down. An argument
`-` names the standard input, which is copied
to a temporary file, since `diff` reads each file more than once. The routine `mktemp` (#l("*pa1 = tempfile = mktemp(tempname);")) makes its name in the array `tempname` (#l("char tempname[] = \"/tmp/dXXXXX\";")), which is
new: v7 passed the string constant, which is now in read-only text,
where `mktemp` cannot write.

The routine `prepare` reads a file, storing one hash per line from index 1 up, and
grows the array by one element per line with `ralloc`.

#lines-to("static void", after: "fclose(input[i]);")

The routine `prune` counts the identical lines at the start and at the end of the
two files, and renumbers the lines in between from 1, and `sfile` and
`slen` describe these middles, on which the expensive part works.

The routine `equiv` walks the two sorted arrays together. Each line of the first
file has its hash replaced by the position in the sorted second file of
the first line of equal hash, or 0 if there is none. Then the serial
numbers of the sorted second file are copied into `member`: the
equivalence classes, each listing its lines in increasing order, are
simply concatenated, and the first element of each class is negated to
mark its start. A final -1 stops the scan of the last class.

#lines-to("int")

Next comes `main`. Memory is reused as soon as it is free: `member` is written
over the array of the second file, and `class` over that of the first,
each then shrunk with `ralloc`, since an `int` takes no more room than
the `struct line` it replaces. The comment's estimate of six words per
line was made for the PDP-11. With four-byte `int`s and `long`s the
proportions are much the same.

#lines-to("int", after: "}")

The heart of the program is `stone`. A k-candidate is a match `(x, y)`,
line `x` of the first file with line `y` of the second, which ends a
common subsequence of length `k` of the lines considered so far, and
whose `y` is the smallest possible for that length. The array `c`
(`klist`) holds in `c[k]` the index in `clist` of the current
k-candidate for each length. Their `y`s strictly increase with `k`,
since a subsequence of length `k` contains one of length `k-1` ending
earlier. Each candidate also records in `pred` the candidate of length
`k-1` it extends, so that the whole subsequence can be recovered.

The lines `i` of the first file are taken in order. For each, the
members `y` of its class are taken in increasing order. The routine `search` finds,
by bisection, the length `l` of the shortest candidate whose `y` is at
least `y`. If that candidate's `y` equals `y`, nothing is gained.
Otherwise `(i, y)` extends the candidate of length `l-1` to a common
subsequence of length `l` ending lower in the second file than the
present one, and replaces it (#l("c[l] = newcand(i,y,oldc);", after: "tc = c[l];")). If `l` exceeds every length so far,
the table grows by one (#l("c[l] = newcand(i,y,oldc);", after: "oldl = l;")--#l("break;", after: "k++;")), and the rest of the class, whose
`y`s are larger, cannot do better.

The subtle part is `oldc`. Several members of the same class may
replace entries during one line `i`, at increasing lengths. The
predecessor of a new candidate must come from an earlier line of the
first file, so when `l` is one more than the length just replaced,
the predecessor must be the candidate which was there before the
replacement, saved in `tc` (#l("tc = c[l];"), #l("oldc = tc;")), not the new one, whose `x` is
`i` itself. Likewise a `y` no greater than the `y` of that saved
predecessor (#l("if(y <= clist[oldc].y)")) cannot extend it, and is passed over. `continue` in a `do`-`while` goes to the test (#l("} while((y=b[++j]) > 0);")), which advances to
the next member of the class.

#lines-to("int", after: "}")

The routine `newcand` adds a candidate to `clist`, a store from which nothing is
ever removed, growing it by one element at a time. The routine `search` first tries
the commonest case, a `y` beyond every candidate.

The routine `unravel` builds `J`. The prefix lines match themselves, the suffix
lines their counterparts, and the rest are filled in by following
`pred` back from the longest candidate.

#lines-to("/* check does double duty:")

The routine `check` reads both files again, line by line in step with `J`. Each
pair of lines which `J` claims to match is compared character by
character. With `-b`, runs of blanks compare equal. A pair which
differs owes its match to equal hashes alone, and the match is
dropped, a "jackpot". What remains is a common subsequence, but
perhaps not a longest one, so that a line may be reported as changed
which a true match would have kept. The comment at the head of the file
accepts this. At
the same time the byte offset of the end of every line is recorded in
`ixold` and `ixnew`, so that `fetch` can later seek straight to any
line.

The variables `c` and `d` (#l("int c,d;")) are now `int`, where v7 had `char`, for two reasons.
The macro `isspace` indexes a table, and a `char` subscript draws
a warning from `-Wall`. And on the ARM, whose `char` is unsigned, the
`EOF` returned by `getc` would become 255, which with `-b` indexes
`isspace`'s table beyond its end. The PDP-11's signed `char` kept it
-1, as the `int` now does.

#lines-to("void", after: "}")

The routine `output` scans `J` for runs of unmatched lines and reports each run as
a `change`: lines `a` to `b` of the first file are replaced by lines `c`
to `d` of the second. An empty first range means an addition, an empty
second range a deletion. The sentinels `J[0]` and `J[m+1]` (#l("J[0] = 0;")--#l("J[m+1] = len[1]+1;"))
spare the loops tests for the ends. With `-e` the commands form an
`ed` script, and are produced from the end of the file backwards, so
that the line numbers in each command are not disturbed by the
commands already applied. `-f` gives the same commands in forward
order and a different form, for reading, not for `ed`.

#lines-to("/* hashing has the effect of")

The routine `readhash` computes a line's hash: each character is added to an
`unsigned long` after a shift of seven bits more than the last, taken
modulo 16, and the two 16-bit halves are then folded together. With
`-b`, blanks are not hashed, and a run of them counts only as the gap
of one shift. The routine returns 0 at the end of the file, and a line
never hashes to 0: the sum starts at 1, so that after the fold the
halves can never cancel. A last line without a newline is dropped, as
in v7.

The sum in v7 was a signed `long` (#l("unsigned long sum;")). A line of some 2,000 bytes of
`0377`, or of some 5,000 letters, overflows it, which C99 leaves undefined. And where the sum wrapped to
a negative number, `high` shifted its sign in, and the halves could
cancel after all. 16,384 `@` characters sum to `0xFFFF0001`, which
folds to 0, and `diff` took the line for the end of the file and
compared nothing after it. Unsigned, the sum wraps round and `high`
brings in zeros, so the halves cancel only if the whole sum has wrapped
to exactly 0. A line built for the purpose could still do that, and the
first fold then adds one (#l("sum = low(sum) + high(sum) + (sum == 0);")). A first fold of 1 to
131070 cannot fold to 0.

On the PDP-11 the result was reduced to a 16-bit `int`. On the ARM the
sum of the two `short` halves is kept in 32 bits. Two results which
differ by 65536, and which the PDP-11 would have reduced to the same
value, now stay distinct. Otherwise only the values change.

#lines-to(none)
#source("/usr/src/cmd/ps.c")

The program `ps` reports on processes, and it has no system call to ask. It reads
the kernel's process table directly: `nlist` finds the address of
`proc` in the symbol table of `/unix`, and the table is read from
`/dev/kmem` at that address. For each process it then reads the
process's `user` structure, which lies in the process image
(#f("user.h")), from memory if the process is loaded and from the swap
area if not, and from the image it digs out the arguments with which
the program was started. Every structure involved, `proc`
(#f("proc.h")), `user`, and the layout of the image, is the kernel's
private business, and `ps` must be compiled against the kernel's own
headers and must agree with it exactly. The mechanism shared with
`dmesg`, `nlist` on the ELF `/unix` and kernel addresses as offsets in
`/dev/kmem`, is described in #f("cmd/dmesg.c").

`/dev/mem`, `/dev/kmem`, and `/dev/swap` may be read only by root and
group `sys`, and `ps` is set-group-id `sys` (#f("rootfs.proto")), so
that it works for every user. In v7 the files could be read by
anyone.

The v7 program included `<core.h>`, which described the PDP-11 core image, for the
three macros `TXTRNDSIZ`, `stacktop`, and `stackbas`. The port has no
such header, and the macros are defined here (#l("#define stacktop(siz) (USRSIZE)"), #l("#define stackbas(siz) (USRSIZE-siz)")), with the top of
the stack at `USRSIZE`, the end of the 3 GB user address space
(#f("param.h")), where the PDP-11's was at `0x10000`, the end of its
64 KB address space. The macros are expanded only where they are used,
after `<sys/param.h>` (#l("#include <sys/param.h>")) has defined `USRSIZE`.
The argument `siz` of `stacktop` was unused in v7 too.

The headers `proc.h` and `user.h` come from the kernel's own directory (#l("#include \"../../sys/h/proc.h\""),
#l("#include \"../../sys/h/user.h\"")), since the port installs neither in `/usr/include/sys`. The v7 program also
included `<sys/tty.h>`, of which `ps` uses nothing, and `u_ttyp` is only a
pointer to a `struct tty`, which C permits without the structure's
definition. The program's own variable `u` (#l("struct\tuser u;")), into which it reads a
`user` structure from memory or swap, agrees with the `extern`
declaration of #f("user.h"). The members of `nl` are initialized in
full, since a partial initializer draws a warning from `-Wextra`.

#lines-to("struct\tproc mproc;", lead: true)

The v7 program declared `lseek` and, wrongly, `strncmp` returning `char *`. Both are
now declared in #f("stdio.h"), and these lines have gone. The procedures
of the file are declared with prototypes instead (#l("char\t*gettty(void);")--#l("void\tgetdev(void);")).

A device name is now `DIRSIZ+1` bytes (#l("char\tdname[DIRSIZ+1];")), for the terminating null
which a directory entry of the full `DIRSIZ` characters lacks (see
`getdev` below).

#lines-to("int", after: "char\t*coref;")

The options are letters in the first argument, in any combination, `a` for all users' processes, `x` for those without a terminal, `l` for
the long listing, `t` followed by a terminal name, `v` for the
children's times, `k` to read a core image of memory from
`/usr/sys/core` instead of the live system, and a number for a single
process. A `t` at the end of the letters names no terminal, and v7 then
tested the first character of the name through the null `tptr`, which
the port first checks (#l("if (tptr && *tptr == '?')")), and `ps t` means `ps a`.

#lines-to("bbreak:")

A namelist named on the command line could make `ps` read and print
any part of the kernel's memory, so `ps` then gives up group `sys`
(#l("nlist(argc>2? argv[2]:\"/unix\", nl);")--#l("if (nl[0].n_type==0) {"), #f("rootfs.proto")) and runs with the user's own
permissions.

The program opens two files (#l("coref = \"/dev/kmem\";")--#l("swmem = open(kflg? coref: \"/dev/mem\", 0);")). The kernel's variables are read from
`/dev/kmem` (`mem`), at their kernel addresses, and the process images
from `/dev/mem` (`swmem`), at their physical ones. With `k`, both come
from the core file. The v7 program opened `/dev/mem` twice, for the same two
purposes, since on the PDP-11 a kernel address of its data was also a
physical one. The kernel's addresses differ from the physical ones on
both machines here (@ch-intro), and the two files do the translating
(#f("mem.c")).

First the program reads two kernel variables. The variable `swapdev` is read into
`nl[1].n_value` and never used, since the swap area is reached through
the file `/dev/swap`, and `swplo`, the first block of the swap area on its
device, is needed to find a swapped image. Then it seeks to `proc` and
reads `NPROC` entries in turn, one `struct proc` at a time. As in v7,
`NPROC` is a number in the program's #f("param.h"), which must agree
with the kernel's.

A slot with `p_stat` zero is unused. Processes of the super-user which
have no process group, that is, which never opened a terminal, such
as process 0, are shown only with `x`.

#lines-to("void", lead: true)

The routine `getdev` builds a table of the character special files in `/dev`, by
name and device number, so that a terminal can later be named from the
device number recorded in a `user` structure. It reads the directory
as a plain file, one `struct direct` (#f("dir.h")) at a time.

A name which fills all `DIRSIZ` bytes of an entry has no terminating
null. The v7 code passed `d_name` straight to `stat` and copied it with `strcpy`,
reading past the entry and writing a byte past `dname`. The port copies
it with `strncpy` into the larger `dname`, whose last byte remains
zero, and passes the copy to `stat`. The copy is made before the type
is known, and a slot which is not a character device is simply
overwritten by the next. The loop also stops at the 256 entries the
table holds (#l("while (ndev < 256 &&")), where v7 had no limit.

#lines-to("struct map {", lead: true)

The map `datmap` describes how
user addresses map onto the image, as a debugger's map would: addresses
from `b1` to `e1` lie at file offset `f1` plus the distance from `b1`,
and those from `b2` to `e2` at `f2` plus the distance from `b2`. Its
members are now `unsigned long`, since the stack lies above 0x80000000,
and a physical offset in `/dev/mem` may too, where a `long` would turn
negative.

#lines-to("int", after: "int\tfile;")

The routine `prcom` handles one process. If it is loaded (`SLOAD`), its image is at
`p_addr` pages in `/dev/mem`. In the port, as on the PDP-11, `p_addr`
is a physical page number (#f("proc.h")), so `ptob` of it, v7's `ctob`
of the click number, gives the physical address, the offset in
`/dev/mem`. It is
computed as an `unsigned long`, and `addr` is one, for the reason just
given. If the process is swapped out, `p_addr` is a block number in the swap area,
and `swplo` is added. The `user` structure is at the start of the image
in both cases.

The maps follow from the shape of the image, which is v7's on the ARM
too (#f("machdep.c")): the `USIZE` pages of the `user` area, then the
data, then the stack, packed together. The stack segment, at the top of
the address space, follows the data in the image. The bound `f2` (#l("datmap.f2 = ptob(USIZE)+(datmap.e1-datmap.b1)+addr;")) is
accordingly the end of the data, `datmap.e1-datmap.b1` past the `user`
area. The data map begins at the data's first page
(#l("datmap.b1 = ptob(u.u_pdstart);")), which `exec` records in
`u_pdstart` (#f("user.h")). The text is not in the image, and is not
mapped.

#lines-to("tp = gettty();")

The fields of the line. The mask `&0377` (#l("\"0SWRIZT\"[mproc.p_stat&0377], puid);")) is new. The field `p_stat` is a
`char`, and an array subscript of type `char` draws a warning from
`-Wall`. The mask makes it an `int`, and on the PDP-11, where `char`
was signed, it would also have kept the subscript positive. The
formats were made for the PDP-11, and three fields of the long listing
are widened for 32-bit values (#l("printf(\" F S UID   PID  PPID CPU PRI NICE    ADDR   SZ       \""), #l("printf(\"%6u%4d%4d%5d%8o%5d\", mproc.p_ppid,"), #l("printf(\"%12o\", (unsigned)mproc.p_wchan);"), #l("printf(\"            \");")): `ADDR`, the page
number in octal, from six digits to eight, since the 512 MB of the
MP135 machine's memory reaches page 917504, 03400000; `SZ` from four
columns to five, since a large image is thousands of blocks, which
v7's `%4d` would run into the address; and
`WCHAN`, a kernel address in octal, from seven columns to twelve, room
for eleven digits and a space. The field `p_wchan` is a pointer, and `%o` takes an
`unsigned`. Passing the pointer as it stands, as v7 did, is undefined,
so it is converted (#l("printf(\"%12o\", (unsigned)mproc.p_wchan);")). `SZ` is the image in blocks of 512 bytes:
v7 converted its 64-byte clicks with `(p_size+7)>>3`, and the port with
`ptod` (#f("param.h")), which serves 4096-byte pages. The times
assume `HZ` of 60, which holds (#f("param.h")).

#lines-to("/* look for sh special */")

The arguments are sought in the last 512 bytes of the image, the top of
the stack. First the last word below `USRSIZE` is examined: `exec` leaves
it zero, but the shell, when it runs a command file, stores there a
pointer to its own argument list (`execargs`, #f("sh/main.c")), so that
`ps` shows the name of the command file rather than `sh`. The pointers
and the strings are fetched one byte at a time through `getptr` and
`getbyte`, which apply `datmap`.

#lines-to("lseek(file, addr, 0);", lead: true)

Otherwise the strings themselves are found. The system call `exec` (#f("sys1.c")) puts
the argument and environment strings at the top of the stack, preceded
by the vector of pointers, which ends with a zero word. The scan goes
backwards from near the end for a word which is zero or -1, takes the
strings which follow it, turns nulls into spaces and unprintable
characters into `?`, and stops at the first `=`, which begins the
environment, cutting back to the preceding space.

The v7 code declared `abuf` as 512 `char`s and walked it with an `int` pointer
through casts. It is now 128 `int`s, and the casts in the loop have
gone. Reading a `char` array through an `int` pointer is undefined in
C99, which allows an object to be accessed only through its own type or
as characters, and nothing guarantees that a `char` array is aligned
for `int` accesses. The present compiler happens to place v7's array
on a word boundary, but nothing requires it to. An `int` array may be
read as characters, as the rest of the loop does.

#lines-to("char *", lead: true)

The routine `gettty` names the terminal by searching the table of `getdev` for the
device number of the controlling terminal, dropping the prefix "tty".
The `user` structure holds only a pointer to the terminal's `tty`
(#f("tty.h")), so `gettty` reads the device number from
the kernel's memory at that address
(#l("lseek(mem, (long)&u.u_ttyp->t_dev, 0);")). It puts the offset of
`mem` back afterwards, since the caller is part way through reading the
process table from the same descriptor.

#lines-to("char *", lead: true, after: "}")

The routine `getptr` assembles a pointer from the image byte by byte, through
`getbyte`. Its counter is now `unsigned`, so that the comparison with
`sizeof` is between unsigned values. The routine `getbyte`
finds the offset of a user address through the two maps and reads one
byte. An address in neither map reads as zero.

The v7 `within` compared `(unsigned)adr` with the `long` bounds. On the
PDP-11 the 16-bit `unsigned` was promoted to a 32-bit `long` and the
comparison was exact. On the ARM `unsigned` and `long` are both 32 bits,
and the user addresses reach 0xc0000000, which a `long` cannot hold.
The bounds are therefore `unsigned long`, and the address is cast to
`unsigned long` too, so that the comparison is exact again.

#lines-to(none)
#source("/usr/src/cmd/dmesg.c")

Everything the kernel prints with `printf` (#f("prf.c")) passes through
the console driver's `putchar`, which keeps a copy of each character in
the circular buffer `msgbuf`, 128 bytes (`MSGBUFS`) long, with
`msgbufp` pointing at the next place to be written (#f("pl011.c"),
#f("usart.c")). The
buffer is defined in #f("main.c") and the pointer in #f("machdep.c").
The program `dmesg` copies the two out of the running kernel and prints the
buffer, oldest character first, so that messages which went to the
console while nobody watched can still be read.

It does so as `ps` does, and as any v7 program which inspects the
kernel must. The routine `nlist` looks the names up in the symbol table of the
kernel's file, `/unix`, to learn their addresses, and the program then
reads memory at those addresses through `/dev/kmem`. Both halves needed
work in the port, though none of it is in this file. In v7, `nlist` read
the symbol table of an `a.out` file. The port's kernel, like its
programs (#f("sys1.c")), is an ELF file (#f("Makefile")), installed as
`/unix` in the image (#f("rootfs.proto")), and the port's `nlist`
(`nlist.c`, in the C library) finds the ELF symbol table instead, compares only the first eight characters
that `struct nlist` (in `a.out.h`) has room for, and puts back the
leading underscore with which the PDP-11 C compiler prefixed every
external name and which ELF compilers do not add. So `"_msgbuf"` (#l("{\"_msgbuf\",0,0},"))
still finds `msgbuf`. On the other side, an offset in `/dev/kmem` is a
kernel address (`memaddr`, #f("machdep.c"), and #f("mem.c")), so that the
value `nlist` reports can be used directly as the offset for `lseek`,
although, above 0xc0000000, it is a negative `off_t` (#f("rdwri.c")).
In v7, `dmesg` read `/dev/mem`, whose offsets on the PDP-11 were the same
for the kernel's data. Here the default file is `/dev/kmem`.

With the flag `-`, the program keeps in `/usr/adm/msgbuf` a copy of the
buffer as it was last seen, and prints only what has been added since.
The crontab runs it so every ten minutes, appending to
`/usr/adm/messages` (#f("cmd/cron.c")). The image provides both files,
owned by `daemon`, and makes `dmesg` set-group-id `sys`, the group
which may read `/dev/kmem` (#f("rootfs.proto")), since `cron` runs the
program as `daemon`. Without `/usr/adm/msgbuf` the `open` (#l("of = open(\"/usr/adm/msgbuf\", 2);")) would
fail, the `read` and `write` on descriptor -1 would fail harmlessly, the saved state would be all
zeros, and the whole buffer would be printed each time.

The members `n_type` and `n_value` of `nl` (#l("struct nlist nl[3] = {")--#l("};")) are now given
explicitly, since a partial initializer draws a warning from
`-Wextra`. The third element, all zeros, ends the list for `nlist`.
The routines `done` and `pdate` are declared before `main` (#l("void done(char *s), pdate(void);")), which uses them.
The pointer `msgbufp` now starts at `msgbuf` (#l("char\t*msgbufp = msgbuf;")). The routine `done` records `msgbufp - msgbuf`
for the next run, and when the program gave up before it had found the
kernel's pointer, v7 subtracted from `msgbuf` a null pointer or the
kernel's address, which C leaves undefined, and the next run took the
result as an index into the buffer.

#lines-to("void done(char *s), pdate(void);")

A file named on the command line, a core file or a namelist, makes the
program give up group `sys` first (#l("if (argc>1)")--#l("setgid(getgid());")), as in #f("cmd/ps.c").
The two `read`s copy the buffer and the pointer. The check at (#l("if ((n -= nl[0].n_value) >= MSGBUFS)")) is the
only defence against a `/unix` which is not the running kernel: if the
pointer read at the address given for `msgbufp` does not lie within the
address given for `msgbuf`, the names belong to some other system. Its
offset in the kernel's buffer then places `msgbufp` in the program's
copy (#l("msgbufp = msgbuf + n;")). The v7 code read the pointer into `msgbufp` and compared and
subtracted it as a pointer, though it points into no object of the
program's. The pointer is now read as the `unsigned` `n` (#l("unsigned n = 0;")), and the
offset is an unsigned difference, which also makes the two tests of
v7 one.

#lines-to("mstart = &msgbuf[omesg.omindex];")

The comparison decides where printing begins. The program sets `mstart` to the
position recorded on the last run, and the copy is compared with the
saved buffer from the present write position round to `mstart`. That
stretch is the part of the old text which should not have been
overwritten since. If it is unchanged, the new text is the stretch from
`mstart` to `msgbufp`. If nothing at all is new, the program exits
silently. If it differs, the kernel has written more than a whole
buffer in the meantime, messages have been lost, and the program prints
"..." and the entire buffer, starting at `msgbufp`, the oldest
character. Null bytes, the part of the buffer never yet written, are
skipped.

#lines-to("void", lead: true)

The routine `done` records the present buffer, its index, and the message which
ended the run, and exits. The message is not printed if it is the one
recorded last time: the test (#l("if (s && s!=omesg.omsgflg && sflg==0) {")) compares the pointers, which works
because the same program, run again, places the same string at the same
address. A complaint such as "No mem" therefore appears once in the
log, not every ten minutes. The flag `sflg` was cleared at (#l("sflg = 0;")), so the test of
it is always true.

The routine `pdate` heads the output with the date, once, before the first thing
printed. The routine `ctime` is now declared in #f("stdio.h"), and v7's local
declaration of it has been removed, and `firstime` has gained its `int`.

#lines-to(none)
#source("/usr/src/cmd/cron.c")

The program `cron` runs commands at stated times. Started by #f("rc"), it
never stops. Once a minute it compares the time with each line of the
table `/usr/lib/crontab`, and starts the commands whose times have
come. The image's table runs `dmesg` (#f("cmd/dmesg.c")) every ten
minutes and `atrun`, which starts the jobs queued by `at`, every five.
The v7 table had a third entry, which ran `/usr/bin/calendar` once a day
to mail each user their reminders. With no mail, the command and its
helper `/usr/lib/calendar` are gone, and the entry with them. Since the
commands run as
the user `daemon` (#l("setuid(1);")), the first entry works only because `dmesg` is
set-group-id `sys`, the group which may read `/dev/kmem`, and
`/usr/adm/messages` and `/usr/adm/msgbuf` belong to `daemon`
(#f("rootfs.proto")).

The design is a loop which keeps its own idea of the minute, `itime`,
advancing it by exactly 60 seconds each time round and sleeping until
the real time catches up. A minute is therefore never skipped, even if
the machine was busy, and never examined twice.

The declarations of `localtime`, `malloc`, and `realloc` (deleted after
#l("struct\ttm *loct;")) are now in #f("stdio.h"). The procedures are declared at (#l("void\tslp(void), ex(char *s), init(void);")--#l("char\t*cmp(char *p, int v);")):
those used before their definitions need it (#f("prf.c")), and `cmp`,
which v7 declared inside `main`, is declared at file scope so that
`-Wmissing-prototypes` sees the declaration before the definition.

#lines-to("int", after: "char\t*cmp(char *p, int v);")

A call `setuid(1)` makes the program, and so every command it runs, the
pseudo-user `daemon` of #f("passwd"), so that the table cannot be used
to do anything as root. The parent returns to #f("rc"). The `freopen`s
of "/" put the standard output and error on the root directory, opened
for reading: the descriptors are occupied, and anything a command
writes to them without a redirection fails harmlessly. The standard
input is closed again (#l("fclose(stdin);", after: "itime -= localtime(&itime)->tm_sec;")), and `init` opens it on the table whenever it is read.

The time `itime` starts at the beginning of the current minute.

#lines-to("for (;; itime+=60, slp()) {")

The table is read again only when its time of last modification
(`st_mtime`) is later than that of the copy last read, held in
`filetime`. Each minute thus costs one `stat`, and an edited table takes
effect within a minute, without a signal to `cron` or a restart.

The time `filetime` starts at zero, and the test is a strict "greater than". A
table dated zero is therefore never read at all, and `list`, still null,
is then scanned at (#l("for(cp = list; *cp != EOS;) {")). The image therefore dates every file 284774400
seconds, 10 January 1979, the date of v7's own files (#f("Makefile"),
#f("cmd/mkfs.c")), and the table is read on the first pass. The same
test means that a table replaced by an older file is ignored until it
is touched.

For each entry, `cmp` checks the five fields in order against the
minute, hour, day of the month, month (made 1 to 12 at (#l("loct->tm_mon++;\t\t /* 1-12 for month */")), since
`localtime` counts from 0), and day of the week. It counts failures in
`flag`. If all match, the command, which follows the fields, is run.
The `slp` before it (#l("slp();")) makes sure the minute has really come, and the
`while` at (#l("while(*cp++ != 0)")) skips to the end of the command.

#lines-to("char *", lead: true)

The routine `init` compiles each field into a code and its operands. The codes are
100 to 104, and every number is less than 100 (`number`, #l("if (n>=100)")), so a code
cannot be mistaken for a value. `EXACT` is followed by the value, `ANY`
by nothing, `LIST` by the values and a closing `LIST`, `RANGE` by the
two bounds. The routine `cmp` returns the position of the next field. The code
after the `switch` (#l("if(cp[-1] != v)")) is never reached, since `init` writes no other
code.

#lines-to("void", lead: true)

If `itime` is still in the future, `slp` sleeps until it.

The routine `ex` forks twice. The child forks again and exits at once, so that
`cron`'s `wait` returns immediately. The grandchild, now an orphan,
belongs to `init` (#f("cmd/init.c")), which collects it when it ends.
Thus `cron` never waits for a command, and leaves no zombies. The
command is given to the shell with `-c`, with its standard input on
"/". The `execl` (#l("execl(\"/bin/sh\", \"sh\", \"-c\", s, (char *)0);")) ends with `(char *)0`, as in #f("cmd/getty.c").

#lines-to("void", lead: true, after: "exit(0);")

The routine `init` reads the table into `list`, which starts with 512 bytes. The v7 code
grew it by 512 whenever fewer than 100 bytes remained at the start of a
line, a margin which was no guarantee: a command line longer than about
100 characters, started near the end, wrote past the block. Now the
length of each line is measured first (#l("pos = ftell(stdin);")--#l("fseek(stdin, pos, 0);")): the line is read to
its end and the file positioned back at its start with `fseek`, which
the table, an ordinary file, allows. The compiled form of a line is
never longer than the line itself and two bytes more, the newline and
the null which end the command, and the two `EOS` codes need no more,
so `i` counts from 2. If that does not fit, the list grows by the
length and another 512 bytes (#l("listsize += i+LISTS;")).

The calls of `free` before `realloc` (#l("free(list);", after: "if (list) {"), #l("free(list);", after: "olist = list;")) rely on a promise of
v7's allocator: `realloc` accepts a block freed since the last `malloc`,
and still finds its contents there (#f("gen/malloc.c")). Since `realloc`
frees a busy block itself, the explicit `free` changes nothing. At
(#l("list = realloc(list, LISTS);")) any copying of the old contents is wasted, since the list is about
to be rebuilt.

#lines-to("ocp = cp;")

A line is parsed field by field. A field is `*`, a number, a list of
numbers separated by commas, or a range `a-b`, followed by a blank. A
line with any other field, or which ends before the command, is
dropped (`ignore`), and parsing resumes on the next line. In the
command, `%` stands for a newline, so that one table entry can hold
several lines for the shell. The command is stored with a newline and a
null. At the end of the file two `EOS` codes are written, the first of
which ends the scan at (#l("for(cp = list; *cp != EOS;) {")).

#lines-to("int", lead: true)

The routine `number` reads decimal digits and pushes back the first non-digit.

#lines-to(none)
#source("/usr/src/cmd/update.c")

The kernel does not write a modified buffer at once. The routine `bdwrite`
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

The `#include <stdio.h>` (#l("#include <stdio.h>")) is new: in the port that header declares
the system call stubs `fork`, `close`, `open`, `sync`, `alarm`, and
`pause`, and `exit` (#f("stdio.h")), which C99 will not let the program
call undeclared.

#lines-to("void dosync(int sig);")

The parent returns at once, so that #f("rc") goes on to its next line,
and the child closes the standard files, which belong to the console.
The descriptors 0, 1, and 2 so freed are the ones the three `open`s
receive. The call `dosync(0)` performs the first `sync` and arms the
alarm. After that the process does nothing but `pause` until a signal
arrives.

Because `dosync` is used in `main` before
its definition, it is declared first (#l("void dosync(int sig);")). The v7 code called it with no argument. It is a signal handler
and now takes the signal number, as the prototype of `signal` in
`signal.h` requires (#f("sys/signal.s")), so the direct call passes 0.

#lines-to("void", lead: true, after: "}")

Each `SIGALRM` runs `dosync`, which calls `sync` and then sets the alarm
again. The `signal` call is repeated every time because a v7 signal
reverts to its default action when it is caught (`psig`, #f("sig.c")). A
second alarm finding the default action in place would kill the process.
The clock routine's once-a-second work serves `alarm`
(#f("clock.c")), which decrements `p_clktim` and sends the signal when it
reaches zero.

The thirty-second `sync` also keeps the date on the disk. The routine `update`
(#f("alloc.c")) stamps each modified super-block with the current
`time` before writing it, and `iinit` (#f("main.c")) takes the time of
day at boot from the root file system's `s_time`, since the kernel
reads no battery-backed clock on either machine. A newly booted system
therefore starts from the last moment at which `update` found the
super-block modified, at most thirty seconds after the last allocation
or release of a block or inode, rather than from the 10 January 1979 of
the image (#f("Makefile")). A system which has changed nothing on its
disk leaves `s_time` alone, since the stamp is written only together with a
modified super-block.

#lines-to(none)
#source("/usr/src/cmd/mkdir.c")

The v7 kernel has no system call to make a directory. A directory is an inode of
type `IFDIR` whose contents are entries of the form described in
#f("dir.h"), and the kernel's only means of creating such an inode is
`mknod` (#f("sys2.c")), which takes the mode as given and is reserved
to the super-user. The new directory is then empty: it lacks even the
entries "." and "..", which the kernel does not supply, but which
`namei` (#f("nami.c")) expects to find, since apart from one test for
".." at the root of a mounted file system it looks them up as ordinary
names. The program `mkdir` adds them with two calls of `link`, and `link` too
refuses a directory to anyone but the super-user
(#f("sys2.c")). These restrictions protect the shape of the tree: a
directory linked into two places, or one without a correct "..", would
confuse `namei` and the programs which walk the file system.

The program is therefore installed set-user-id to root, mode 4755, as
on v7's distribution tape (#f("rootfs.proto")), and does its own
checking on behalf of the real user.

The signals which might stop the program are ignored (#l("signal(SIGHUP, SIG_IGN);")--#l("signal(SIGTERM, SIG_IGN);")) so that
it cannot be interrupted between the `mknod` and the second `link`, which
would leave a directory without its "..".

The declarations of `strcat` and `strcpy` (deleted after 8) are gone,
since #f("stdio.h") declares the string routines with prototypes. The routine `mkdir` is declared before `main` (#l("void mkdir(char *d);"))
because `main` calls it first.

#lines-to("void", lead: true, after: "}")

The parent of the new directory is its name up to the last slash,
followed by ".". For a name with no slash, it is "." itself. A call of `access`
asks with the real user and group ids whether the parent may be written
(`saccess`, #f("sys2.c")). In a set-user-id program this was the whole
of the permission check, since the effective id was root's and every
later call would succeed. The call of `strncpy` (#l("strncpy(pname, d, slash);")) leaves `pname`
unterminated, and the `strcpy` which follows supplies the terminator.

The v7 program gave `pname` and `dname` 128 bytes each and never checked a name
against them, although the kernel imposes no limit on the length of a
path. A longer name overran them on the stack of a program running as
root. The two arrays are now sized by the name itself (#l("char pname[strlen(d)+2], dname[strlen(d)+4];")), as C99's
variable length arrays allow: `pname` holds at most the name and "."
and a null, `dname` the name and "/.." and a null, so every copy fits.

#lines-to("if ((mknod(d, 040777, 0)) < 0) {")

A call of `mknod` makes the inode with mode 040777, from which `maknode`
(#f("iget.c")) removes the bits of the creator's `umask`. Its link count
is one, for the entry in the parent. A call of `chown` gives it to the real user,
since otherwise it would belong to root, the effective user of a
set-user-id `mkdir`.

The first `link` makes the entry "." in the new directory, naming the
directory itself, and raises its count to two. The second makes ".."
name the parent, which raises the parent's count. If the first fails,
the entry in the parent is removed and the inode, its count back to
zero, is freed when the last reference goes.

If the second link fails, the assignment at (#l("dname[strlen(dname)-1] = '\\0';")) removes the last "."
of `dname`, so that `unlink` removes the entry "." made a moment
before, and `unlink(d)` then removes the entry in the parent. The v7 line
lacked the `-1`: it stored a null byte over the null byte already
there, `unlink` was applied to the ".." which was never made, and the
directory was left with a count of one, from its own ".", and no name,
an inode lost until `icheck` or `clri` attended to it.

#lines-to(none)

#source("/usr/src/games/wump.c")

The program `wump` is the game of Hunt the Wumpus, which came to Unix from the
People's Computer Company's newsletter. The cave is twenty rooms, each
joined to three others. Three rooms hold pits and three hold bats, and
the wumpus sleeps in one. The instructions, which say the rest, are
printed with `printf` in turn, each line given the number of rooms or of
tunnels as an argument, which only lines 3 and 4 use (#l("printf(intro[i], i&1? NROOM: NTUNN);")).

The prototypes (#l("int\ttunnel(int i), rline(void), rnum(int n), rin(void);"), #l("int\tnear(struct room *ap, int ahaz), icomp(char *p1, char *p2);")) are new.

#lines-to("int", after: "int\ttchar;")

The cave is built in two passes. The first strings all twenty rooms
into a single chain through their first two tunnels, so that every room
can be reached. The second fills the remaining tunnels with `tunnel`,
which picks a random room with a free tunnel and joins the two. A cave
in which a room leads to itself, or twice to the same room, is thrown
away and built again (#l("if(p->tunn[j] == i)")--#l("goto init;", after: "if(p->tunn[j] == p->tunn[k])")). Each room's tunnels are sorted for
printing, with `qsort` (#f("gen/qsort.c")), whose element size is now
`sizeof(p->tunn[0])`, four bytes, where v7 wrote 2.

The hazards and the player are then placed at random, the player in an
empty room. The `=|` and `=&` of v7's source, the assignment operators
of early C which v7's compiler still accepted, are written `|=` and
`&=`.

#lines-to("/*", after: "break;")

Each turn reports the room, kills the player in a pit or with the
wumpus, and moves the player at random if a bat is there. The warnings look at
the rooms one tunnel away, and for the wumpus two. A move must be along
a tunnel. An arrow follows the list of rooms given, as far as five, but
where the next room is not joined to the arrow's room it goes down a
random tunnel instead (#l("ranarw:")--#l("goto ranarw;")). A shot, or entering the wumpus's
room, wakes the wumpus, which moves along one of its tunnels or, one
time in four, stays.

#lines-to("int", lead: true)

The routine `rline` reads a line and returns its first non-blank character, leaving
the character that ended the word in `tchar`, so that `m 5` on one line
needs no second prompt. At end of input the game now exits, and v7 tested
for a null character, which `getchar` never returns, and so looped at
end of file. The routine `rin` reads a room number and returns 0 for anything else.
Its digits now stop accumulating above 1000, so that a long number
cannot overflow.

The routine `rnum` returns a random number below `n`. The generator is seeded from
the time on the first call, and v7 kept the time in two words and mixed
them, and the port keeps it in a `long long`.

#lines-to(none)

#source("/usr/src/games/fortune.c")

The program `fortune` prints one line chosen at random from
`/usr/games/lib/fortunes`, reading the file only once: the `n`th line
replaces the line kept so far with probability $1/n$, so that when the
file ends every line has had the same chance of being the one kept.
The routine `rand` returns numbers below 32768, which is why the test compares with
`32768./p`. The generator is seeded from the process id and the time.

The time is now a `long long` (#l("long long t;")), as `time` returns it
(`types.h`). Its two halves are still mixed into the seed by adding
the high bits to the low. A missing file is still reported with v7's
joke message.

#lines-to(none)

#source("/usr/src/cmd/echo.c")

The command `echo` writes its arguments separated by blanks and ended by a newline,
which a first argument `-n` suppresses. The shell has no built-in
`echo`, so every `echo` in a script runs this program.

#lines-to(none)

#source("/usr/src/cmd/cal.c")

The program `cal` prints the calendar of a month, or of a whole year, of the
Gregorian calendar as it was adopted in Britain and its colonies, so
that September 1752 lacks eleven days. Each month is drawn into a
character array, seven columns of three characters for each of six
weeks, and the year's form draws three months side by side into rows of
72 characters (#l("cal(i+1, y, string, 72);")--#l("cal(i+3, y, string+46, 72);")).

The prototypes (#l("int number(char *str), jan1(int yr);"), #l("void pstr(char *str, int n), cal(int m, int y, char *p, int w);")) are new, since `main` uses the procedures before
their definitions.

#lines-to("int", lead: true, after: "printf(\"Bad argument\\n\");")

The routine `number` converts an argument, returning 0 for anything that is not a
number. It now also returns 0 once the number exceeds four digits (#l("if(c<'0' || c>'9' || n>9999)")),
so that a long argument does not overflow, and `main` refuses any year
above 9999. The routine `pstr` turns the nulls of a row into blanks, cuts the
trailing blanks, and prints it.

#lines-to("char\tmon[] = {", lead: true)

The routine `cal` fills in one month. The day of the week of 1 January comes from
`jan1`, and the length of the year from the difference between two such
days: one day means 365, two days 366, and anything else is 1752, whose
September loses eleven days after the 2nd (#l("if(i==3 && mon[m]==19) {")--#l("}", after: "mon[m] += 11;")). The routine `jan1` counts one
day for each year and one for each leap year, takes away the Gregorian
centuries after 1800, and adds three for the days lost in 1752.

#lines-to(none)

#source("/usr/src/cmd/date.c")

The command `date` prints the date and time, or with an argument `yymmddhhmm[.ss]`
sets them, and `-u` works in Greenwich time. Setting the clock appends two
records to `/usr/adm/wtmp`, with the names `|` and `{` and the times
before and after the change, so that `ac` can correct the connect times
which span it.

The variable `timbuf` is a `time_t` (#l("time_t\ttimbuf;")), now 64 bits (`types.h`), and v7's
declarations of the time routines give way to #f("stdio.h") and
#f("time.h"). The time zone of `ftime` (#f("timeb.h")) is in minutes
west of Greenwich.

#lines-to("int", lead: true, after: "exit(rc);")

The routine `gtime` reverses the argument and takes its digits two at a time from
the end, seconds first, with `gp`. A field which is not given keeps the
current day, month, or year. It then counts the days from 1970,
including the leap days which `dysize` (#f("gen/ctime.c")) reports.

Two-digit years below 70 now mean the years from 2000 (#l("if(year < 70)"), #l("year += 100;")), so
that the clock can be set to dates up to 2069, and v7's `date`, whose time
ended in 2038, read every year as 19`yy`. A field that is not a pair of
digits makes `gp` return -1, which the range tests reject, and a
negative year (#l("if( year<0 || month<1 || month>12 ||")) is now one of them. Before, `date x101010000` set
the clock to 1999.

#lines-to(none)

#source("/usr/src/cmd/factor.c")

The program `factor` prints the prime factors of its argument, or of each number on
its input, one per line. In v7, `factor` was PDP-11 assembler which did
its arithmetic in the FP11's floating point, whose 56-bit fraction
bounded the numbers it accepted. The port's is written in C, with
`long long` arithmetic and the same bound, `BIG`, $2^56$. A larger
number is refused with v7's "Ouch."

The trial divisors are 2, 3, 5, 7, 11, 13, and then the numbers which
share no factor with 210, $2 dot 3 dot 5 dot 7$. The table `tab` holds the 48
gaps between such numbers around one period of 210, and `i` starts at
3, so that from 17 on the divisor steps through the cycle (#l("d += d < 17 ? 1 + (d > 2) :")). Each
divisor is tried while its square does not exceed what is left. What
remains at the end is itself prime.

The digits are accumulated only while `n` is below `BIG` (#l("if(c != ' ' && n < BIG)")), so that a
long argument cannot overflow, and `put` prints a `long long` without
`printf`, with the five spaces of v7's output.

#lines-to(none)

#source("/usr/src/cmd/primes.c")

The program `primes` prints the primes from its argument upwards, for ever. Like
#f("cmd/factor.c") it was PDP-11 assembler in v7, using the FP11, and is
rewritten in C with `long long` arithmetic and the same bound, $2^56$.

Primes below 100 come from the table `pt`. Beyond that `primes` sieves
8000 numbers at a time, starting at the odd number `nn`: `table` has one
bit for each number of the window, and `mark` sets the bits of the
multiples of `p` within it, starting from the first multiple at or
above `nn` (#l("off = nn/p*p - nn;")--#l("off += p;")). Every divisor up to the square root of the window's
end is used, 3, 5, 7, and then the numbers prime to 210, in the cycle of
gaps `factab` of #f("cmd/factor.c"). The odd numbers whose bits stay clear
are prime and are printed (#l("for(i = 0; i < TSIZ8; i += 2) {")--#l("}", after: "nn += 2;")), and the window moves on.

Output goes through a 512-byte buffer, written with `write`, and the
input is read with `read` a character at a time, as the assembler did.
Numbers are converted to decimal by the recursive `ftoa`.

#lines-to(none)

#source("/usr/src/cmd/units.c")

The program `units` converts quantities between units: asked "you have" and "you
want", it prints the factors which take one to the other. A unit is a
`factor` and ten exponents, one for each of the fundamental dimensions
(length, mass, time, and so on) which `/usr/lib/units` defines. Two
units are conformable when their exponents agree.

The exponents are now `signed char` (#l("signed char\tdim[NDIM];")). Every inverse unit has
negative ones, and the ARM's `char` is unsigned, so v7's plain `char`
would have made a second of $-1$ into 255. A table entry now contains a
`struct unit` (#l("struct\tunit u;")) where v7 repeated its two members and passed the
entry, cast, wherever a unit was wanted: C99 does not allow an object to
be used as a different structure type even when the first members agree,
so `units(&tp->u)` and `convr(&lp->u)` pass the member itself. The
prefixes' initialisers gain the braces of each entry, for
`-Wmissing-braces`.

#lines-to("void\tunits(struct unit *up);")

The routine `main` reads the table with `init` and then converts in a loop. Before
printing, the two factors are checked with `fpbad`: the PDP-11's
floating point trapped on overflow and underflow, which `fperr` counted
in `fperrc`, but the ARM's hard floating point raises no signal, so a
result that is zero or not finite now reports "underflow or overflow"
instead of printing an infinity.

#lines-to("void", lead: true, after: "}")

The program prints a unit as its factor and the names of its dimensions,
those with negative exponents after a `/`. The routine `convr` reads a quantity, a
number and then names separated by blanks, `-`, or `/`, a digit after a
name being its power, and `lookup` multiplies or divides it by each.
A name not in the table is tried again without each prefix that it
starts with, and then without a final `s`. A name longer than 19
characters is now cut short instead of overrunning `name` (#l("*cp++ = c;", after: "if(cp < &name[19])")), and the
end of the input (`c == 0`) ends the quantity, so that a table without a
final newline cannot make `convr` loop.

#lines-to("static int", lead: true)

The routine `init` reads `/usr/lib/units`: each line defines a name as a quantity of
other units, and the first ten lines make `m`, `kg`, `sec`, and the
rest the fundamental dimensions, by defining them as `*a*` to `*j*`,
the names `init` gives the ten dimensions before it reads the file
(#l("np = cp;", after: "for(i=0; i<NDIM; i++) {")--#l("lp = hash(\"\");")). Lines starting with `/` are comments. The names are kept in `names`, and the table is a hash table
of 601 entries probed in sequence. Running out of either now stops
`units` with "too many units" (#l("printf(\"too many units\\n\");")), and v7 wrote past the arrays.

#lines-to("double", lead: true)

The routine `getflt` reads a number, with an optional fraction and exponent, and `a|b`
means `a` divided by `b`. The exponent's digits now stop accumulating
at five (#l("i = i*10 + c-'0';")). The routine `get` returns the next character, or 0 at the end of the
table. At the end of the standard input `units` exits.

#lines-to(none)

#source("/usr/src/cmd/yes.c")

The command `yes` repeats its argument, or `y`, for ever, for commands which ask
for confirmation. The suite also uses it as a process which runs until
it is killed. The program now includes #f("stdio.h") for `printf`.

#lines-to(none)

#source("/usr/src/cmd/sleep.c")

The command `sleep` suspends itself for the number of seconds in its argument,
with the library's `sleep`.

The count is now `unsigned` (#l("unsigned c, n;")), so that a long string of digits wraps
instead of overflowing, as `sleep` takes an `unsigned` anyway. A missing
argument or a character that is not a digit now exits with status 1, and
v7 printed the message and exited with 0, as if it had slept.

#lines-to(none)

#source("/usr/src/cmd/basename.c")

The command `basename` prints the last component of a path name, and with a second
argument removes that suffix from it, as in ``cc `basename f .c`.o``.
The pointer `p2` is left just after the last `/`, and the suffix is compared from
its end backwards and cut off if it matches.

The v7 code called `puts` with a second argument, `stdout`, which its `puts`
ignored. The call is now `puts(p2)` (#l("puts(p2);")).

#lines-to(none)

#source("/usr/src/cmd/osh.c")

The program `osh` is the shell of the Sixth Edition, which v7 kept beside the
Bourne shell of Part Two for old scripts. It is a few hundred lines against the Bourne shell's thousands. It has no variables but the positional parameters `$0` to `$9` and `$$`, no control flow but `goto` (a separate
command), and wild cards left to a separate program, `/etc/glob`, which
v7 did not include. Its source is old C: v7 still compiled `=+` and
`=|` for `+=` and `|=`, and the parse tree kept pointers in `int`s. The
port writes the assignment operators in the modern order, and makes
every conversion between pointer and `int` an explicit cast, which is
exact on the ARM, whose `int` and pointers have 32 bits.

The flags describe a command in the tree, `FAND` for one run in the background, `FPIN` and `FPOU` for the ends of a pipe, `FPAR` for a
command in parentheses, `FINT` for one which must ignore interrupts,
and `FPRS` for one whose process id is printed. A tree node is a few `int`s holding its type, the input and output file names (`DLEF`, `DRIT`), the
flags, and for a command its words from `DCOM`. `NSIG` is redefined to
the sixteen signals `mesg` names, one fewer than #f("signal.h") gives.

#lines-to("int", after: "void\texecute(int *t, int *pf1, int *pf2);")

The routine `main` closes stray descriptors, makes `$$` from the process id (now
taking each digit before dividing, 99, 100, where v7 divided first and
so gave a tenth of the id), and
takes `-c` for a command from the argument, `-t` for a single line, or a
file to read. A login shell (`-` in `argv[0]`) ignores QUIT, and
INTR unless it was already ignored. The `int` conversion of the
previous handler (#l("f = (int)signal(INTR, SIG_IGN);")) tests whether it was `SIG_IGN`, where v7 compared
it with the number 1.

The routine `main1` reads one line into words and executes its tree. A syntax
error found deep in the parse returns through `jmpbuf`.

#lines-to("void", lead: true, after: "execute(t, 0, 0);")

The routine `word` collects one word. Characters inside quotes, and those escaped
with `\`, carry the bit `QUOTE`, 0200, so that they are not taken as
special, and `trim` takes it away before the command runs. A quoted string
which runs past the end of the line buffer is now refused like any
other overflow (#l("if(linep > elinep) {", after: "while((c=readc()) != c1) {")--#l("}", after: "while(c != '\\n')")), and v7 wrote past `line`.

The routine `getc` returns the next character, expanding `$n` and `$$` from a
saved pointer `dolp`, and `readc` reads the input itself, from the `-c`
argument or one character at a time. The redefinitions of `getc` and
`putc`, the shell's own, are why #f("stdio.h")'s macros are undefined
(#l("#undef\tgetc"), #l("#undef\tputc")).

#lines-to("/*", lead: true)

The parser works on the array of words, by recursive descent. The routine `syn1` splits at `;`, `&`, and newline, `syn2` at `|` or `^`, and `syn3` takes
a simple command or a parenthesised list with its redirections. Each
returns a tree node allocated from `trebuf` by `tree`, which escapes
through `jmpbuf` when the buffer is full.

#lines-to("static void", lead: true)

The routine `execute` runs a tree. The commands `chdir`, `shift`, `login`, `newgrp`, `wait`, and `:` are
built in. Others fork, redirect, and execute:
a word with `[`, `?`, or `*` hands the command to `/etc/glob`, which v7
did not ship either, so such a command fails here as there. The command
is tried as given, in `/bin`, and in `/usr/bin`, the name being built
in a buffer allocated to its length (#l("if((linep = malloc(strlen((char *)t[DCOM])+10)) == 0)")), and v7 built it in the line
buffer. The shell `/bin/osh` itself runs a file which is not an executable, as a script (#l("t[DSPR] = (int)\"/bin/osh\";")), and v7 named `/usr/bin/osh`, which did not exist.

#lines-to("void", lead: true, after: "return;")

The routine `pwait` waits for a child and reports one which a signal killed,
`(s>>8)|e` being the exit status the script returns. The routine `prn` prints a
process id in decimal.

#lines-to(none)

#source("/usr/src/games/arithmetic.c")

The game `arithmetic` drills sums. Its arguments choose the operations, any of
`+-x/`, and a range of numbers, 10 unless given. Every twenty problems,
and on an interrupt, it prints the score and the time taken. A problem
answered wrongly is added to the pool, so that it is more likely to
come again (#l("left[range] = left[i];"), #l("right[range++] = right[j];")), and `skrand` favours numbers near the middle of
the range.

The operations are now copied with a limit of nine (#l("for(k = 0; dif < 9 && (types[dif] = argv[1][k]);")), and from
`argv[1][k]` rather than `argv[1][dif]`: v7 indexed the argument by the
count of operations so far, so a second argument such as `x` after `+-`
read past its end. A range below 2 with division is refused (#l("for(k = 0; k < dif; k++)")--#l("}", after: "printf(\"Range is too small.\\n\");")),
since every divisor would be zero and the search for one at 99 would not
end. The routine `getline` stops at end of input, which v7 tested by looking for a
null character that never comes, and no longer steps before its buffer
on a blank line (#l("while(rs > s && *--rs == ' ')")). The routine `getnum` stops accumulating above 100000. The
times are `long long`, as `time` returns them.

#lines-to(none)

#source("/usr/src/games/hangman.c")

The game `hangman` picks a random word from the dictionary and lets the player
guess its letters, seven wrong guesses being allowed. The word is found
by seeking to a random byte of the file, skipping the partial word
there, and taking the next word of at least seven lower-case letters,
hyphens removed. The score is the average number of errors per word, a
lost word counting two more.

The v7 game seeded the generator with `tvec[1]+tvec[2]`, the second word of the
time and a word beyond the end of the array. The time is now a single
`long long` (#l("{\tlong long tvec;")--#l("srand(tvec);")). The dictionary's words are read with a width of
127 (#l("fscanf(dict,\"%127s\\n\",buf);"), #l("if(fscanf(dict,\"%127s\\n\",wbuf)==EOF)")), so that a long line cannot overrun the buffers, and words
longer than 25 letters are skipped (#l("if(i<MINLEN || i>25) goto loop;")), since `word` holds 25. The
guess is read with `fgets` in place of `gets` (#l("if(fgets(gbuf,sizeof gbuf,stdin)==NULL)")), and a dictionary
with no usable word now stops the game with "no words" (#l("{\tif(n++) fatal(\"no words\");")) instead of
searching it for ever.

#lines-to(none)

#source("/usr/src/games/quiz.c")

The game `quiz` asks questions from a file of facts and checks the answers. The
index, `/usr/games/quiz.k/index`, names a file for each subject and the
kinds of fact it holds, such as `state:capital`. Asked for two of them,
`quiz` reads the file and asks one kind of fact and expects the other.
A fact is a pattern, in which `[...]` encloses something optional, `{...}`
groups, and `|` separates alternatives, so that an answer may be given
in more than one way.

The array `score` is now `signed char` (#l("signed char score[NL];")), since in the `-t` mode a question
answered wrongly scores $-1$ and comes again, and the ARM's plain
`char` cannot hold it. The buffer `line` has room for `NC` characters and two more
(#l("char response[100];")). The prototypes (#l("int\treadline(void), cmp(char *u, char *v), disj(int s),")--#l("void\tpub1(int s), readindex(void), talloc(void), badinfo(void);")) are new.

The routine `readline` reads a line of the file, dropping repeated blanks and
joining a line ended by `\`, and `nc` counts the characters read, which
`readindex` uses as the offset of each line. It no longer steps its
pointer before the start of `line` to drop a leading blank: the loop is
now a `while` which advances only past characters it keeps. The test
for end of file masks the character (#l("if((*line&0377)==0377)")), since the ARM's `char` makes
0377 a positive number.

#lines-to("char *eu;", lead: true)

The routine `cmp` matches an answer against a pattern, and `disj` tries the
alternatives in turn, `string` a sequence of characters and bracketed
parts, and `eat` a single character, compared without regard to case by
`fold`. Each returns 1 for a match, 0 for none, and 2 for a malformed
pattern. With `s` zero they only skip over the pattern. The `|` in
`t|(x&s)` (#l("return(t|(x&s));")) gains parentheses, which change nothing, for a warning.

#lines-to("void", lead: true)

The routine `publish` prints the first of a pattern's alternatives, and `segment` splits
a line at its colons into `w`, each part now limited to `SL` characters
(#l("while(*s!=':'&&*s!='\\n'&&s-u<SL) {")), and `talloc` gives each part two more bytes, for the escape which
a part may end with (#l("tmp[i] = malloc(SL+2);")). The routine `perm` finds, for each kind of fact asked
for, the field of an index line which matches it, and `find` the index
line for which all match.

#lines-to("int", lead: true, after: "tmp[i] = malloc(SL+2);")

The routine `main` reads the index, finds the subject, and then asks questions from
it in a random order until interrupted. More than `NF` arguments are now
refused (#l("if(argc>NF+1 || find(&argv[1],argc-1)==0)")), since `select` has `NF` entries. A subject file with no
facts in it now stops `quiz` with "I don't know about that" (#l("if(na==0)")), and v7
went on to compute a question number modulo zero. A fact longer than
`NC` characters is cut there (#l("for(j=0;j<z&&j<NC;j++)")). The time is a `long long`, and the
increment for the generator takes its low bits, with parentheses
which make the order of `&` and `|` explicit (#l("inc = ((int)tm&077774)|01;")).

#lines-to("int", lead: true, after: "}")

The routine `query` reads an answer with `read`, a character at a time, dropping
repeated blanks. Characters beyond the size of `response` are now
dropped (#l("if((*t==' '&&(t==r||t[-1]==' ')) ||")), and end of input ends the game. The routine `next` picks the next
question with a linear congruential generator, skipping those already
answered.

#lines-to(none)

#source("/usr/src/games/fish.c")

The game `fish` plays Go Fish against the player. A hand is an array of
thirteen counts, one for each rank, and four of a rank make a book,
which scores. The program's own guesses come from `myguess`, which in
the professional mode, asked for at the start, remembers what the
player has asked for, since the player must hold it, and otherwise picks the
rank asked about longest ago. Without it the guess is random.

The source is v7's, in its own layout, with prototypes (#l("int\tchoose(char a[], int n), draw(void), empty(HAND h),")--#l("void\thedrew(int d), heguessed(int d);")) and
declarations in the modern style. The changes which are not mechanical
are three. The player's input now ends the game at end of file: `guess`
exits on `EOF` and the loops which skip the rest of a line stop there
too, where v7 read for ever. The ranks kept in the `char` array `try`
are masked with `0377` before they index `hehas` and `haveguessed`
(#l("}", after: "goto gotguess;")--#l("if( t <= 0 ) error( \"bad guessing loop\" );")), so that the program behaves the same whatever the
signedness of `char`. With ranks from 1 to 13 the masks change no
value. And `mark` (#l("mark( HAND hand, int cd ){")) takes the hand first, as every call passes it.
The v7 game defined it as `mark(cd, hand)`, the reverse of its calls. On the
PDP-11, where a pointer and an `int` were passed alike, `hand[cd]` still
reached the right count, since `a[i]` is `*(a+i)` whichever of the two
is the address, but the test against `NOMORE` looked at the address
instead of the card.

#lines-to(none)

#source("/usr/src/games/backgammon.c")

The game `backgammon` plays the game against the user, who plays red. The
program chooses its moves by generating all those the dice allow
(`movegen`), scoring each with a weighted evaluation of the position
(`strategy`, `eval`), and taking the best, at one of three levels of
skill. It keeps its own random-number generator, seeded from the time, and the preprocessor renames `srand` (#l("#define srand bg_srand")), since the library's has
another type.

The moves typed are read into an array that now has room for the end
marker after five of them (#l("int t,k,n,go[6];")), and `getstr` now stops at the end of its
100-byte buffer and at end of input (#l("char *e = s+99;")--#l("}", after: "if(s<e)s++;")), where v7 overran the
buffer and read for ever. An empty answer, for which `sscanf` returns
$-1$, no longer indexes before the array (#l("if(n<0)n=0;")), and `sum=+` becomes
`sum+=` (#l("sum+=player[startrow++];")): the old spelling of `+=` would now assign a positive
value. The initialisers without `=` (#l("int red[]     = {0,2,0,0,0,0,0,0,0,0,0,0,5,")--#l("int imoves;")) are written in C99's form,
and the braces added to `movegen` mark statements v7's indentation
already showed.

#lines-to(none)

== Files and Directories <ch-files>

#source("/usr/src/cmd/ls.c")

The command `ls` lists files and the contents of directories. Each name to be
listed gets an `lbuf` (#l("struct lbuf {")--#l("};")), allocated by `gstat` and kept, by
pointer, in `flist`. The list is sorted with `qsort` and printed by
`pentry`. A name given as an argument keeps its pointer in `namep`, a
name read from a directory its 14 characters in `lname`, and the flag
`ISARG` says which half of the union is in use. The time of the entry is
a `time_t` (#l("time_t\tlmtime;"), #l("time_t\tyear;")), so that the comparison with six months ago in
`pentry` and the sort by time hold for times past 2038.

The routine `main` reads the options and lists the arguments, or the current
directory. The v7 code made its default list with `argv = &dotp - 1`, the address
of a pointer before a single variable, which C does not promise to
exist, and `dotp` is now an array whose second element is `"."` (#l("char\t*dotp[]\t= { 0, \".\" };"), #l("argv = dotp;")).
The arguments are sorted, the files among them printed, and each
directory read and its entries sorted and printed after them, and `compar`
puts directories given as arguments last unless `-d` is set.

#lines-to("void", lead: true, after: "exit(0);")

The routine `pentry` prints one entry. The i-number, kept as a `short`, is printed
through `ino_t` (#l("printf(\"%5u \", (ino_t)p->lnum);")), so that one above 32767 is not shown negative.
The routine `getname` looks up a user or group id in the password or group file,
remembering the last one found. It now stores at most 15 characters of
the name (#l("if (j==0 && i < 15)")), since `tbuf` holds 16, and v7 copied the whole field. The
modes come from the tables `m1` to `m9`: each gives the number of bits
to test, then pairs of a bit and the character it prints, and the
character for none of them.

#lines-to("char *", lead: true)

The routine `makename` joins a directory name and an entry name. Its buffer now has
room for the longest name `exec` can pass as an argument, `NCARGS`, with
a slash, an entry name, and a null (#l("static char dfile[NCARGS+DIRSIZ+2];")), and v7's held 100 characters,
which a long argument overran. The routine `readdir` reads a directory a `direct`
at a time, skipping empty slots and, without `-a`, `.` and `..`. It now
ends the copied name with a null (#l("ep->ln.lname[j] = 0;")), since a 14-character name has
none in the directory. The routine `gstat` makes the `lbuf`, calling `stat` only
when the options need what it returns. After `NFILES` entries it reuses
the last slot and says once that there are too many.

#lines-to(none)

#source("/usr/src/cmd/cp.c")

The command `cp` copies a file, or several into a directory, `BSIZE` bytes at a
time. A copy into a directory takes the source's last component, and a
copy of a file onto itself is refused by comparing device and i-number.
The new file is created with the source's mode.

The name built in a directory is now allocated to its length (#l("if ((bp = malloc(strlen(from) + strlen(to) + 2)) ==")--#l("}", after: "fprintf(stderr, \"cp: out of memory\\n\");")), and
v7 built it in `iobuf`, the 512-byte buffer of the copy, which a long
directory overran.

#lines-to(none)

#source("/usr/src/cmd/mv.c")

The command `mv` renames a file, moves files into a directory, or renames a
directory. There is no system call to rename: `mv` links the new name
and unlinks the old, and when the two names are on different devices,
so that `link` fails, it runs `cp` and removes the original. Only the
super-user may link or unlink a directory (#f("sys2.c"),
#f("sys4.c")), so `mv` is
set-user-id root, and `main` gives up that privilege at once unless the
source is a directory (#l("setuid(getuid());")).

The routine `move` handles a file. The name built inside a target directory is now
an array sized to the two names (#l("char\tbuf[strlen(target)+strlen(source)+2];")), and v7 used `MAXN`, 100 bytes, and
overran it with long names. A target which is not writable is replaced
only if the user, at a terminal, answers `y`.

#lines-to("int", lead: true, after: "return(0);")

The routine `mvdir` renames a directory, after checks for which the privilege is
needed: the user must be able to write both parents and the directory
itself, and the move must stay on one device. It now refuses either
name if it does not fit in `MAXN` (#l("if (strlen(source) >= MAXN || strlen(target) >= MAXN) {")--#l("}", after: "if (strlen(source) >= MAXN || strlen(target) >= MAXN) {")), and checks the length of
the built name exactly (#l("if (strlen(target)+strlen(dname(source)) > MAXN-2) {")), where v7 assumed that the last component
was at most `DIRSIZ` long, which a name given by the user need not be.
A directory which changes parent must also have its `..` relinked
(#l("strcpy(dst, target);")--#l("}", after: "if (link(pname(source), dst) >= 0)")), and v7 built that name with `strcat` onto `dst`, which held
whatever the stack held, and the copy is now `strcpy` (#l("strcpy(dst, target);")). The routine `check`
walks up from the new parent through `..` to the root, refusing to
move a directory under itself, and `chkdot` refuses names containing
`..`, which would defeat that walk.

#lines-to(none)

#source("/usr/src/cmd/ln.c")

The command `ln` makes a new link to a file: under the name given, or with the
same last component inside a directory given as the second argument.
Linking a directory needs `-f`, and even then only the super-user's
`link` succeeds (#f("sys2.c")).

The name built in a directory is now allocated to its length (#l("sprintf(name = malloc(strlen(arg2)+strlen(np)+2),")), and v7
built it in a 100-byte array, which a long name overran.

#lines-to(none)

#source("/usr/src/cmd/rm.c")

The command `rm` removes files. A file the user cannot write is removed only after
a `y`, unless `-f` is given or the input is not a terminal, and `-i` asks
about every file. With `-r`, a directory is emptied by `rm` calling
itself on each entry, and then removed by running `rmdir`, since only
the super-user may unlink a directory and `rmdir` is set-user-id root.

The name of an entry is now built in an array sized to the directory's
name (#l("char name[strlen(arg)+16];")), and v7's held 100 characters. And `rm` now closes the directory
while it removes each entry, then reopens it and seeks back to where
it was (#l("off = lseek(d, 0L, 1);")--#l("lseek(d, off, 0);")): v7 kept it open, so that each level of the tree held a
descriptor, and a tree deeper than `NOFILE`, 20, stopped the removal.

The routine `rmdir` returns 1 for a failure (#l("return(status != 0);")), where v7 returned the status
from `wait`. That status is the exit code times 256, and since `main`
adds the results into its own exit code, which keeps only the low
eight bits, a single failure in v7 left `rm` exiting with 0.

#lines-to(none)

#source("/usr/src/cmd/rmdir.c")

The command `rmdir` removes empty directories. A directory has three links, its name in the parent, its own `.`, and
its `..` to the parent. The command
checks that the directory is not the current one and holds nothing but
those two entries, then unlinks `..`, `.`, and the name, in that order.
Only the super-user may unlink a directory, so `rmdir` is set-user-id
root, and checks itself that the user may write the parent: `access`
judges by the real user id.

The name is now copied into an array sized to it, with room for the
`/..` appended later (#l("char\t*np, name[strlen(d)+4];")), and v7's held 500 characters. Now `np` points
past the last slash (#l("else")--#l("np++;")), so that `a/.` and `a/..` are refused by
the test at #l("if(!strcmp(np, \".\") || !strcmp(np, \"..\")) {")\, and v7 left it on the slash, and the test saw `/.`, which it
did not match. And a missing `.` or `..` is now recognised by `errno`
being `ENOENT` (#l("/* name/. non-existent */"), #l("/* name/.. non-existent */")): v7 took any failure of `access` for absence,
so that a `..` it could not reach skipped the check of permission and
was unlinked.

#lines-to(none)

#source("/usr/src/cmd/find.c")

The command `find` walks the trees named by its first arguments and evaluates, for
each file, the expression made of the rest. The expression is compiled
first into a tree of `anode`s (#l("struct anode {")--#l("} Node[100];")): each holds the function which
evaluates it and two operands. In v7 every predicate read the same node
through a structure of its own, `{ int f, t, s; }` for `-mtime` and the
like. Here there is the one structure, and a predicate's number and
sign are stored in the pointer fields `L` and `R`, converted to
pointers and back (#l("return(mk(mtime, (struct anode *)atoi(b), (struct anode *)s));"), #l("return(scomp(AGE(Statb.st_mtime), (int)p->L, (int)p->R));")). `Node` holds 100 nodes, and `mk` now
says so when an expression needs more (#l("if(Nn >= 100) {")--#l("}", after: "pr(\"find: too many predicates\\n\");")), and v7 wrote past the
array.

The command `find` returns to the directory it started from, `Home`, before each
path, and runs commands from there. `Home` and `Pathname` now hold 4096
characters (#l("char\tPathname[4096];"), #l("char\tHome[4096];")), where v7 had 128 and 200, and `main` refuses a
path which does not fit (#l("if(strlen(Argv[Pi]) >= (int)sizeof Pathname) {")--#l("}", after: "pr(\"\\n\");")). It also now copes with `pwd` failing
to run (#l("if((pwd = popen(\"pwd\", \"r\"))) {")--#l("*cp = '\\0';", after: "if((cp = rindex(Home, '\\n')))")), where v7 cut the last character off whatever it had.
The preprocessor renames `ctime` (#l("#define\tctime\tfind_ctime")), since the predicate would
otherwise clash with the library's `ctime`, which the headers declare.

#lines-to("/* compile time functions:  priority is  exp()<e1()<e2()<e3()  */", lead: true)

The expression is parsed by recursive descent, with `exp` for `-o`, `e1`
for concatenation, which means "and", `e2` for `!`, and `e3` for
parentheses and the predicates. The routine `nxtarg` hands out the arguments, and
returns an empty string, three times at most, once they run out. `-perm`
now stops reading digits once the mode has more than twelve bits
(#l("for(i=0; *b && (unsigned)i <= 07777; ++b) {")), so that a long argument does not overflow `i`.

#lines-to("/* execution time functions */", lead: true)

The functions after the parse evaluate the nodes against `Statb`, the
status of the current file. A time predicate compares the file's age in
days with its argument: the age is computed by `AGE` (#l("#define AGE(t)\t(int)((time_t)((unsigned long long)Now - (t)) / A_DAY)")) in unsigned
arithmetic, so that a time far in the past or future cannot overflow
the subtraction, which C leaves undefined for signed numbers. The routine `scomp`
compares with a sign: `+n` means more than `n`, `-n` less than `n`.
The negation is now made in `long long` (#l("return(a < (b * -1LL));")), so that it cannot
overflow either.

`-cpio` writes the files found to an archive in `cpio`'s format. The
modification time in its header is now four 16-bit halves, most
significant first (#l("unsigned short\th_mtime[4];"), #l("for(i = 0; i < 4; i++)")--#l("(unsigned long long)Statb.st_mtime >> (48-16*i);")), where v7 had two: the port's
`time_t` is 64 bits. The archives are therefore not v7's. The system
has no `cpio` command to read them. A name longer than the header's 256 bytes
is now refused (#l("if(strlen(Pathname) >= (int)sizeof hdr.h_name) {")--#l("}", after: "pr(\"find: cannot copy \"), pr(Pathname), pr(\"\\n\");")) instead of overrunning `h_name`.

#lines-to("int", lead: true, after: "return(a == b);")

The routine `doex` runs the command of `-exec` or `-ok`, with `{}` replaced by the
path. It now refuses more than 49 arguments (#l("if(np >= 49) {")--#l("}", after: "pr(\"find: too many arguments\\n\");")), the size of
`nargv`. The routine `getunum` finds a name in the password or group file. The
name and number it reads now stop at the 20 bytes of `str`
(#l("while((*sp = c = getc(pin)) != ':') {")--#l("c != EOF && sp < &str[19]) sp++;")). The routine `descend` evaluates the expression on a file and, for a
directory, on each entry in it, a block of 32 entries at a time,
changing into the directory to keep the names short. It keeps a
directory open while it descends only if the descriptor is a low one
(#l("if(dir > 10) {")), so that a deep tree does not run out of them. It now refuses to
descend when a further name would not fit in `Pathname` (#l("if(endofname+DIRSIZ+1 >= &Pathname[sizeof Pathname]) {")--#l("}", after: "pr(\"find: path too long-- \"), pr(name), pr(\"\\n\");")).

The routines `gmatch` and `amatch` match a name against a pattern in the manner of
the shell. The characters are now taken as unsigned (#l("scc = *s & 0377;")--#l("(scc <= (cc=p[1]&0377));")), so that
the comparisons of ranges hold whatever the signedness of `char`.
The routine `chgreel` asks, on `/dev/tty`, for another output device when a write
fails. It now gives up if `/dev/tty` cannot be opened or read (#l("if(devtty == NULL || fgets(str, 20, devtty) == NULL)")).

#lines-to(none)

#source("/usr/src/cmd/od.c")

The command `od` dumps a file in octal, decimal, hexadecimal, bytes, or
characters, eight 16-bit words to a line, each line headed by its
offset. A line equal to the one before is printed once, and the run of
equal lines after it as a single `*`. Each format is a bit in `conv`,
and `line` prints one row for each bit set, in the order of the bits.
The routine `offset` reads the starting point, `+` followed by a number which is
octal, hexadecimal with `x`, or decimal with a point, and in blocks with
`b`.

The offset is now an `unsigned long` (#l("unsigned long\taddr;"), #l("putn(unsigned long n, int b, int c)", after: "putn((long)c, 8, 3);"), #l("unsigned long a;")), so that it prints
correctly at 2 GB and beyond, where v7's `long` turned negative. And
`line` now stops after the seven bits which name formats (#l("for(c=1; c&0177; c<<=1) {")), and v7 shifted
`c` until it became zero, which with a 16-bit `int` happened after
sixteen shifts, but with a 32-bit `int` reaches the sign bit, where a
further shift is undefined.

#lines-to(none)

#source("/usr/src/cmd/cat.c")

The command `cat` copies its files, or its input, to its output, and `-` names the
input, and `-u` makes the output unbuffered. Before copying a file
`cat` compares its device and i-number with those of the output, and
refuses to copy a file onto itself, which would grow for ever.

The port now initialises `dev` to $-1$ like `ino` (#l("int dev = -1, ino = -1;")). The v7 code left it undefined
when the output is a terminal or a disk, for which the comparison is
not made, and then compared each input with it all the same.

#lines-to(none)

#source("/usr/src/cmd/tee.c")

The command `tee` copies its input to its output and to each file named, `-a`
appending instead of truncating. When the output or a file is a
terminal or a pipe, `t` is set, and `tee` passes on what it has as soon
as a read returns, instead of waiting to fill 512 bytes, and writes it
in pieces of 16 bytes. Otherwise output to a terminal would lag behind
the input.

A file is now checked by `fstat` on the descriptor just opened (#l("if(fstat(openf[n-1],&buf)>=0) {")), and
v7 called `stat` on the name, so that a file which existed but could not
be opened passed the check and kept $-1$ as its descriptor. The preprocessor renames the function which writes messages (#l("#define\tputs\ttee_puts")),
since `<stdio.h>` declares a `puts` of its own.

#lines-to(none)

#source("/usr/src/cmd/tar/tar.c")

The command `tar` writes files to an archive, and lists or extracts them again.
The archive was meant for magnetic tape, by default `/dev/mt1`, but
`f` names any file, `-` the standard input or output. Each file is a
header block of 512 bytes, `hblock` (#l("union hblock {")--#l("} dblock, tbuf[NBLOCK];")), followed by its
contents rounded up to whole blocks. Two empty blocks end the archive.
The header holds the file's name, mode, owners, size, and time as
ASCII octal numbers, so that an archive is the same whatever the byte
order of the machine which made it. A block is read or written in
records of `nblock` blocks, 20 at most.

The routine `main` reads the key. The letter `c` creates, `r` appends, `u` appends only files
newer than their copies in the archive, `x` extracts, and `t` lists, and
`v` reports each file, `w` asks about each, `m` leaves the extracted
files with the present time, and `l` reports links it could not find.

#lines-to("void", lead: true, after: "fprintf(stderr, \"tar: usage  tar -{txru}[cvfblm] [tapefile] [blocksize] file1 file2...\\n\");")

The routine `dorep` adds files. Without `c` it first reads to the end of the
archive. For `u` it writes each name and time to a temporary file,
sorted, which `checkupdate` searches later. The command's buffer is now
initialised (#l("char buf[200] = \"\";")) before the `strcat`s which `sprintf` then overwrites, and
The v7 code appended to whatever the stack held. The routine `dorep` changes into the
directory of each argument and passes the last component to
`putfile`. When the directory cannot be entered it now passes the
whole name instead (#l("cp = chdir(*argv) < 0 ? *argv : cp2 + 1;")), where v7 carried on in the wrong directory.
The current directory, read through `pwd` into `wdir`, now has 512
bytes (#l("char wdir[512];")) where v7 had 60.

The routine `getdir` reads a header and converts its fields. The time is now read
as a `long long` (#l("sscanf(dblock.dbuf.mtime, \"%llo\", &sp->st_mtime);")), the port's `time_t`. A header whose size is
negative or does not fit a `long` is treated as damaged (#l("if (chksum != checksum() || sp->st_size < 0 ||")), and the
two names are now ended with a null (#l("dblock.dbuf.name[NAMSIZ-1] = dblock.dbuf.linkname[NAMSIZ-1] =")), since a name of 100
characters fills its field and has none, and v7 read on into the next
field. The time written to the temporary file stops at the field's 12
characters (#l("fprintf(tfile, \"%s %.12s\\n\", dblock.dbuf.name,")) for the same reason.

#lines-to("void", lead: true, after: "readtape(buf);")

The routine `putfile` writes one file, or, for a directory, calls itself on each
entry, closing the directory meanwhile and reopening it at the entry
after, as `rm` does. A directory whose name will not fit in a header is
now refused, and one which cannot be entered is reported (#l("if (strlen(longname) >= NAMSIZ) {")--#l("}", after: "fprintf(stderr, \"tar: %s: cannot search\\n\",")), and
v7 called `chdir` without looking at the result, and then wrote the
entries of the wrong directory under the right names. A file with more
than one link is written in full only the first time. Afterwards a
header with `linkflag` set names the first copy.

#lines-to("void", lead: true, after: "}")

The routine `doxtract` extracts the files named, or all, making the directories
on their paths with `mkdir` (`checkdir`), and gives each file its
owners and, unless `m`, its time from the archive. The routine `dotable` lists the
archive, in the manner of `ls -l` with `v`.

#lines-to("#define\tSUID\t04000", lead: true)

The routine `tomodes` fills a header from a file's status. The time field holds 11
octal digits, 33 bits, so a 64-bit time is now kept within that range
(#l("t = sp->st_mtime;")--#l("sprintf(dblock.dbuf.mtime, \"%11llo \", (unsigned long long)t);")): a time before 1970 is written as 0 and one past the year
2242 as the largest the field holds. The routine `checksum` adds the bytes of the
header, with the field for the checksum itself taken as spaces. The
bytes are now added as `signed char` (#l("i += (signed char)*cp;")): v7's PDP-11 compiler made
`char` signed, and the sum must be the same as v7's for archives to
pass between the systems, whatever the port's compiler makes of
`char`.

#lines-to("int", lead: true, after: "return(i);")

The routine `response` now stops at end of input (#l("while (getchar() != '\\n' && !feof(stdin));")), where v7 read for ever.
The routine `getwdir` reads the current directory through a pipe from `pwd`. It now
reads up to the 512 bytes of the buffer and fails cleanly when no
newline comes (#l("for (i = read(pipdes[0], s, 512); i > 0 && *s != '\\n'; i--)")--#l("}", after: "fprintf(stderr, \"tar: cannot find current directory\\n\");")), where v7 read 50 bytes into a 60-byte buffer
and then searched for a newline which might not be there.

The routines `lookup` and `bsrch` binary-search the sorted temporary file for a
name, reading a window of `N` bytes around the middle of the range and
taking the first whole line in it. A line is a name of up to 100
characters, a space, and 12 digits of time, so `N` is now 256 (#l("#define\tN\t256")),
which holds the end of one line and the whole of the next, and v7's 200
could not. The routine `readtape` now treats end of file as an error (#l("if ((i = read(mt, (char *)tbuf, TBLOCK*j)) <= 0) {")), where
v7 went on with whatever was in its buffer.

#lines-to(none)

#source("/usr/src/cmd/file.c")

The command `file` guesses what kind of file each argument is, or each name listed
in the file given with `-f`. Special files and directories are told by
their mode. Anything else by its first 512 bytes. A known magic number
in the first word marks an executable or an archive. Otherwise `type`
looks for the marks of C, Fortran, assembler, and `roff` text by
keyword (`lookup`), past comments (`ccom`, `ascom`), and finally
decides between data, commands, English, and other text. The routine `english`
judges by the frequencies of letters and the spacing of punctuation.

The buffer is now an array of `int`s (#l("int ibuf[129];")--#l("#define buf ((char *)ibuf)")), so that its first word
may be read as an `int`, which v7 did by casting a `char` array that
need not be aligned for one. It has room for a null after the data
read (#l("buf[in] = 0;")), which stops the scans that look for a character before
the end. The port's executables are ELF files, whose first four bytes
are `0x7f` and `ELF`. Read as a little-endian `int` they are
`0x464c457f` (#l("case 0x464c457f:")), and are reported as executable. The PDP-11's magic
numbers are kept.

Bytes with the top bit set are now tested for as such (#l("if(buf[i] == 0 || buf[i] & 0200)")), and
masked before they index a table or reach `isalpha` (#l("else if((j < 0 || buf[j] == '\\n') &&"), #l("else if(buf[j] == '\\n' &&"), #l("if ((bp[j]&0377)<NASC)")), and
v7 relied on `char` being signed, so that `buf[i] <= 0` caught them.
The test for `roff` input now also accepts a request at the very start
of the file (#l("else if((j < 0 || buf[j] == '\\n') &&")), where v7 looked at the byte before the buffer.
A name read with `-f` loses its last character only when that is a
newline (#l("if (l>0 && p[l-1]=='\\n')")), `file -f` exits with 0, and a failed read is reported as
such (#l("if(in <= 0){")--#l("printf(in? \"cannot read\\n\": \"empty\\n\");")).

#lines-to(none)

#source("/usr/src/cmd/cmp.c")

The command `cmp` compares two files byte by byte. It reports the first difference
by byte and line, or with `-l` every differing byte with both values in
octal, or with `-s` nothing but its exit status, 0 for equal files, 1 for
different ones, and 2 for trouble. Optional offsets, decimal or,
with a leading zero, octal, skip the start of either file.

The routine `otoi` now accumulates in an `unsigned long` (#l("unsigned long v;")), so that an offset
too large for a `long` wraps instead of overflowing, which C leaves
undefined for signed numbers. And the character given to `isdigit` is
masked to a byte (#l("while(isdigit(*s&0377))")), since a negative `char` is not a valid argument.

#lines-to(none)

#source("/usr/src/cmd/touch.c")

The command `touch` sets a file's modification time to now, by reading its first
byte and writing it back, since v7 has no system call for that alone
except `utime`. An empty file is recreated instead. `-c` forbids
creating files that do not exist.

#lines-to(none)

#source("/usr/src/cmd/tp/tp.h")

The command `tp` saves files on DECtape or magnetic tape and restores them, the
predecessor of `tar`. Unlike `tar`'s, its tape begins with a directory:
block 0 holds a bootstrap, then come `ndentb` blocks of entries, each a
`tent` (#l("extern struct \ttent\t{ /* Structure of a tape directory block */")--#l("}\ttpentry[TPB];")) of 64 bytes giving a file's name, mode, owners, size,
time, and the tape block where its contents start. In core the
directory is the array `dir` of `dent`s, with the names packed into
memory obtained from `sbrk`, and a bit map, `map`, of the blocks in
use guides the placing of new files. DECtape could be read and written
at any block, so files are added, replaced, and deleted in place. A
magnetic tape is always written whole.

The time in `tent` is now a `long long` (#l("long long\ttime;")), the port's `time_t`, and
`unused` shrinks from eight `short`s to six (#l("short\tunused[6];")), so that an entry
keeps its 64 bytes and a block still holds eight. A tape is therefore
not v7's, but `tp` reads its own. The buffer `name` has room for twice `NAMELEN`
(#l("extern char\tname[2*NAMELEN];")): a directory's name, already checked to fit, has an entry's name
appended to it before that is checked in turn.

#lines-to(none)

#source("/usr/src/cmd/tp/tp_defs.h")

The header `tp_defs.h` gives the names of the tape devices, the default flags,
and the bootstrap programs which `wrdir` copies to block 0. The digit
of a unit is patched into the device names by `main`.

#lines-to(none)

#source("/usr/src/cmd/tp/tp0.c")

The file `tp0.c` defines the variables which #f("tp/tp.h") declares. In v7 the
header defined them, and every file which included it defined them
again, which the PDP-11's loader merged but C99 does not allow.

#lines-to(none)

#source("/usr/src/cmd/tp/tp1.c")

The routine `main` reads the key, a unit number, `f` for a named file, `m` for
magnetic tape instead of DECtape, and one command, which `setcom`
installs in `command`: `r` replaces or adds (the default), `u` does so
only for files newer than their copies, `d` deletes, `x` extracts, and
`t` lists. The command `c` starts with an empty directory, and `v`, `w`, and `i`
ask for reports, questions, and the ignoring of errors. The routine `optap` opens
the tape and sets its size and number of directory entries.

The commands are short: each reads the directory or starts a fresh
one, applies a function to the entries named (`gettape`) or adds the
files named (`getfiles`), and writes the directory back. The routine `encode`
stores a name in the packed area, growing it with `sbrk`. It now
measures the name without reading past the 32 bytes of a tape entry
(#l("for(n=0; n<NAMELEN && pname[n]; n++)")--#l(";")), which need not end with a null, and refuses a name of 32
characters (#l("if(n >= NAMELEN) {")), which would leave none when written back, and v7 called
`strlen` and allowed 32.

#lines-to(none)

#source("/usr/src/cmd/tp/tp2.c")

The pointer `lastd` is the last entry in use. When the directory is empty it now
points at the first entry (#l("lastd = dir;")), and `clrent` walks it back over cleared
entries (#l("if (ptr == lastd)")--#l(";")), and v7 made it a null pointer, from which the loops
`while (++d <= lastd)` and `lastd + 1` computed addresses C does not
define, and its `clrent` tested the entry after the one cleared.

The routine `rddir` reads the directory. The sum of the 32 `short`s of a valid
entry is zero. If any is not, the tape may come from a machine of the
other byte order, and `rddir` tries again with the bytes of each entry
swapped (`fls`). Now `tptr` starts at the first entry of the block
already read (#l("struct tent  *tptr = &tpentry[0];")), since a count of entries taken from the tape need
not be a multiple of eight. The routine `wrdir` writes the bootstrap and the
directory, recording the number of entries in the bootstrap block's
last word and making each entry's checksum.

#lines-to("void", lead: true, after: "} while (--count % TPB);")

The routines `tread` and `twrite` move a block, and `wseek` positions the tape,
reading a byte first when the move is long, which on DECtape made the
drive run there at speed. The routine `verify` asks about a file under `w`. It now
stops at end of input (#l("if (c == EOF || (c == 'n' && getchar() == '\\n'))"), #l("while (getchar() != '\\n' && !feof(stdin));")), where v7 read for ever. The routines `getfiles`
and `expand` walk the files named, and `callout` enters each ordinary
file in the directory. The name given is now copied with its length
limited (#l("strncpy(name, *parg++, 2*NAMELEN-1);")), each entry's name ended with a null (#l("strncpy(p0, direct.d_name, DIRSIZ);")--#l("p0[DIRSIZ] = 0;")), and a
path too long for a tape entry refused before it is used (#l("if (strlen(name) >= NAMELEN) {")--#l("}", after: "printf(\"Pathname too long - %s\\nFile ignored\\n\", name);")), and
v7 copied all three with `strcpy` into buffers of 32 bytes.

#lines-to(none)

#source("/usr/src/cmd/tp/tp3.c")

The routine `gettape` applies `delete`, `extract`, or `taboc` to each entry named,
or to all. The routine `update` finds for each new file the first run of free
blocks long enough in the bit map, writes the directory, and
`update1` then copies the files to the tape in the order of their
addresses, so that the tape moves one way. The routine `usage` counts the entries
and blocks in use.

The routine `taboc` lists an entry. The time is now taken apart through the `tm`
structure which `localtime` returns (#l("register struct tm *m;"), #l("m = localtime(&dd->d_time);")--#l("m->tm_mday,m->tm_hour,m->tm_min);")), and v7 declared
`localtime` as returning an array of `int`s and indexed it, which
relied on the structure's layout.

#lines-to(none)

== Text Tools <ch-text>

#source("/usr/src/cmd/arcv.c")

The command `arcv` converts archives of the sixth edition, whose magic number was
`0177555`, to v7's format, `ARMAG` in `<ar.h>`, in place through a
temporary file: each old member header, a name, a date, the owner, the
mode, and a 16-bit size, becomes a new `ar_hdr`. The old archive was a
PDP-11 file, so its fields are read in that machine's layout: the magic
as two bytes (#l("read(f, (char *)&b.magic, 2);")), the size as an `unsigned short` (#l("unsigned short siz;")), and the date
as a `long` whose two halves the PDP-11 stored the more significant
first, which are now exchanged (#l("nh.ar_date = (unsigned long)oh.odate<<16 |")). The temporary file's name is now
an array (#l("char\ttmp[] = \"/tmp/arcXXXXX\";")), into which `mktemp` writes.

#lines-to(none)
#source("/usr/src/cmd/sort.c")

The command `sort` sorts lines, or merges files already sorted (`-m`), or checks
that a file is sorted (`-c`). It reads as many lines as fit in its
memory, sorts their pointers with its own quicksort, and writes each
such run to a temporary file. It then merges the runs, `N`, seven, at a
time, until one remains, which goes to the output. Keys are described
by `+m.n -m.n` pairs, each with options of its own, and kept in
`fields`, and `fields[0]` holds the options which apply to the whole line.
The translation tables `fold`, `nofold`, `nonprint`, and `dict` map a
character to the value it sorts by, or say whether to ignore it.

The tables were indexed by `char`, which on the PDP-11 was signed, so
each key keeps a pointer to the middle of its table (#l("nofold+128,")--#l("zero+128,")), and
the comparison indexes with a value from $-128$ to 127. The tables are
now `unsigned char`, which their values above 127 need, and the
comparisons convert each byte to `signed char` before indexing (#l("while(ignore[(signed char)*pa])"),
#l("while(ignore[(signed char)*pb])"), #l("if((sa = code[(signed char)*pb++] -")), so that the same entries are found whatever the port's
compiler makes of `char`. The preprocessor renames `qsort` (#l("#define\tqsort\tsort_qsort")),
since the library's `qsort`, with another interface, is declared by the
headers.

#lines-to("int", after: "char\t*skip(char *pp, struct field *fp, int j);")

The routine `main` gathers the options and keys, then lets each key with no options
of its own inherit those of the whole line. It takes all the memory it
can get, up to `MEM` beyond the present break, for the pointers and the
text of the lines. It now starts from the break as it stands (#l("lspace = (int *)sbrk(0);")--#l("ep = (char *)lspace + MEM;")),
where v7 started from `end`, the end of the program's data, which lies
below anything the library has already allocated. The name of the
temporary file is now allocated to the length of the directory, which
`-T` may give (#l("sprintf(filep=file=malloc(strlen(*dirs)+16),")), and v7's array held 30 characters.

The routine `sort` reads the lines of all the inputs into a run, and writes each
run sorted. A line longer than the space left now loses its end (#l("if(cp < tend)")),
where v7 wrote past the space, and `tend` marks its last byte (#l("tend = ep - 1;")).

#lines-to("struct merg", lead: true)

The routine `merge` merges files: each has a line buffer in `merg`, the buffers are
kept ordered by their current lines, and the least is written and
replaced by its file's next line. For `-u`, a line equal to the one
written before is dropped, by comparing it with a copy kept in a spare
buffer. With only one file left, v7 compared with the buffer below the
first, which does not exist, and the copy is now used then too
(#l("if(i == 1)", after: "muflg = (mflg & uflg) | cflg;")--#l("muflg |= uflg;")).

The routine `setfil` names an input or a temporary file. The temporaries end in two
letters which count them. The routine `safeoutfil` notices, for `-m -o`, that the
output is also an input, in which case even the last merge goes to a
temporary file first. It now starts its search at the first input when
there are fewer than `N` (#l("for(i=eargc>N?eargc-N:0;i<eargc;i++) { /*-N is suff., not nec.*/")), and v7 started `N` before the last, which
with fewer inputs indexed before the array.

#lines-to("int", after: "exit(error);")

The routine `cmp` compares two lines key by key, and `cmpa` compares whole lines when
there are no keys, or to break a tie. A numeric key is compared as a
decimal number with optional sign and fraction, digit by digit, so that
there is no limit on its size. Now `cmpa` compares bytes as unsigned
(#l("(*pb&0377) > (*pa&0377) ? fields[0].rflg:")), as the tables of `cmp` order them.

The routine `skip` finds the start or end of a key, `m` fields and then `n`
characters along. The routine `field` reads the options and positions of a key. The
position after a point is now stored explicitly in `n` (#l("(d? p->n: p->m)[k] = number(&s);")), and v7 wrote
it at an offset from `m` computed from the layout of the structure.
The routine `number` now saturates (#l("n = n <= 214748363? n*10 + *pa - '0': 0x7fffffff;")) instead of overflowing, and `copyproto`
copies the prototype key by structure assignment (#l("fields[nfields] = proto;")), where v7
copied it as an array of `int`s.

#lines-to(none)

#source("/usr/src/cmd/uniq.c")

The command `uniq` copies its input, dropping each line equal to the one before.
With `-u` it prints only lines which are not repeated, `-d` only one copy of
those which are, and `-c` precedes each line by the number of times it
occurs. `-n` ignores the first `n` fields of each line in the
comparison, and `+n` the first `n` characters after them. The two
buffers hold the current line and the next.

The routine `gline` now stops storing at the end of its 1000-byte buffer (#l("char *e = &buf[999];"), #l("if(buf < e)")),
dropping the rest of a longer line, where v7 wrote past it.

#lines-to(none)

#source("/usr/src/cmd/comm.c")

The command `comm` reads two sorted files and prints three columns, of the lines only in the first, those only in
the second, and those in both. The flags
`-1`, `-2`, and `-3` suppress columns. The columns are made by leading
tabs, `ldr`, and suppressing a column shortens the leaders of the
columns to its right by writing nulls into them. They are now arrays
(#l("static char t1[] = \"\\t\", t2[] = \"\\t\\t\";")), and v7 wrote into string constants, which C does not allow.

The routine `compare` decides which line comes first. It no longer starts its
pointers one byte before the lines (#l("ra = a;")--#l("rb = b;")), an address which need
not exist, and it compares the bytes as unsigned (#l("if((*ra&0377) < (*--rb&0377))\treturn(1);")), the order in
which `sort` puts them.

#lines-to(none)

#source("/usr/src/cmd/join.c")

The command `join` joins two files sorted on a common field: for each pair of
lines whose join fields are equal it prints the field and the rest of
both lines, or the fields listed with `-o`. `-a` also prints the
unpaired lines of a file, `-e` gives the text for an empty field, and
`-t` the separator. When several lines of the second file share a key,
`main` remembers where the run began, `bot2`, and seeks back there for
each line of the first file with the same key, so that every pairing is
printed.

The routine `input` splits a line into at most `NFLD` fields. It now reports a line
with more (#l("if (pp >= &ppi[n][NFLD])")--#l("error(\"too many fields\", \"\");")), where v7 wrote past `ppi`; it no longer steps
past the null that ends a line without a newline (#l("*bp = '\\0';\t/* mark end by overwriting blank */")--#l("bp++;", after: "if (c != '\\0')")), which v7's
own comment admitted it did; and it fills the unused pointers with
empty strings (#l("while (pp < &ppi[n][NFLD])")--#l("*pp++ = \"\";")), where v7 set only the next one to null, so
that a short line left `output` printing a field from the line before
or a null pointer. The field numbers given with `-o` and `-j` are now
checked against `NFLD` (#l("if (--olist[i] < 0 || olist[i] >= NFLD)\t/* 0 origin */")--#l("error(\"bad field number\", \"\");", after: "if (--olist[i] < 0 || olist[i] >= NFLD)\t/* 0 origin */"), #l("if (j1 < 0 || j1 >= NFLD || j2 < 0 || j2 >= NFLD)")--#l("error(\"bad field number\", \"\");", after: "if (j1 < 0 || j1 >= NFLD || j2 < 0 || j2 >= NFLD)")), and `-o` and `-j` no longer
read past the last argument (#l("for (no = 0; no < 2*NFLD && argc > 2; no++) {"), #l("if (argc < 3)")--#l("break;", after: "if (argc < 3)")). Now `top2` starts at zero (#l("long top2 = 0, bot2;")).

#lines-to(none)

#source("/usr/src/cmd/tr.c")

The command `tr` copies its input, replacing each character of the first string by
the corresponding one of the second, which is extended with its last
character. `-d` deletes the characters of the first string instead,
`-s` squeezes runs of a character of the second string to one, and
The flag `-c` takes the complement of the first string. A range is written `a-b`, and
`\nnn` an octal code. The routine `main` builds `code`, the translation of every
character, then filters the input through it. Null bytes are dropped.

The routine `nextc` takes the next character of a string, with escapes. At the end
of a string it now backs up to the null (#l("if(c==0) --s->p;")), where v7 also wrote a
null there, into the argument or, for a missing string, into the
constant `""`. The routine `next` expands ranges. A `-` at the end of a string is
now taken literally once (#l("if(s->max==0) {")--#l("}", after: "if(s->max==0) {")), where v7 backed up onto it and
returned it again for ever.

#lines-to(none)

#source("/usr/src/cmd/tail.c")

The command `tail` copies the end of a file, from a given distance before the end
(`-n`) or after the start (`+n`), counted in lines, blocks, or
characters, and `r` prints the lines in reverse order. From the start it
skips by reading, or for a disk file by seeking. From the end it seeks
to `LBIN-1` bytes before the end when it can, and otherwise reads the
whole input round a circular buffer of `LBIN` bytes, whose last
4096 bytes are all it can show. Then it walks back from the end of
what it has kept, counting newlines.

The count is now kept from overflowing (#l("n = n <= 214748363? n*10 + *arg - '0': 0x7fffffff;"), #l("n = n < 4194304? n<<9: 0x7fffffff;")): it saturates at the
largest `long`, where v7 multiplied on regardless, which C leaves
undefined. The port initialises `p` (#l("char *p = 0;")), since a count of zero lines writes
from it without having read anything.

#lines-to(none)

#source("/usr/src/cmd/wc.c")

The command `wc` counts the lines, words, and characters of its files, or of its
input, and their totals. A word is a maximal run of printing
characters other than space. A control character other than newline,
space, or tab neither starts nor ends one. An option such as `-lw`
chooses the counts printed, and their order.

#lines-to(none)

#source("/usr/src/cmd/pr.c")

The command `pr` prints files in pages of `length` lines, 66 by default, each
headed by the file's time, its name, and the page number, and
optionally in several columns (`-n`), or several files side by side
(`-m`). While it prints to a terminal it makes the terminal writable
only by its owner (`fixtty`), so that messages from `write` do not
break up the pages, and restores the mode when done or interrupted.

#lines-to("void", lead: true, after: "chmod(tty, 0600);")

The routine `print` prints one file. For columns, the text of a whole page must be
read before its first line can be printed, so `nexbuf` reads the file
into `buffer`, used circularly, ending what it has with the mark
`0375`, or `0376` at the end of the file, and `tpgetc` takes a column's next
character, and `colp` points at the start of each column. The number of
columns is now at least one (#l("if (ncol < 1)")--#l("ncol = 1;")): with `-0`, or `-m` and no file
that could be opened, v7 divided the width by zero. The header is now
cut to 80 characters (#l("sprintf(linebuf,")), since the line is built in a buffer of 150
bytes, which v7 overran with a long name given with `-h`.

The routine `put` turns runs of spaces back into tabs where that is shorter, and
`putcp` discards everything before the first page asked for with
`+n`.

#lines-to(none)

#source("/usr/src/cmd/sed/sed.h")

The command `sed` edits a stream: it applies a script of `ed`-like commands to
each line of its input in turn. The script is compiled first, by
#f("sed/sed0.c"), into an array of `reptr`s, one per command, each with
its addresses and regular expression, compiled into `respace`, a
pointer `lb1` for branches and blocks, the right-hand side of a
substitution, a file to write to, and the command's code (#l("#define ACOM\t01")--#l("#define XCOM\t033")) and
flags. Then #f("sed/sed1.c") runs it. The buffer `linebuf` is the pattern space and
`holdsp` the hold space.

In v7 `reptr` was a union of two structures alike in all but the type
of `lb1`, a `char *` in one and a pointer to the union in the other.
The program used whichever suited. It is now the one structure
(#l("extern struct\treptr {")--#l("} ptrspace[PTRSIZE], *rep;")), with `lb1` a pointer to it. The names of the files for `w`
now have room for a whole line (#l("extern char\tfname[12][LBSIZE];")), as `text` copies them, where v7
gave them 40 bytes. `RESIZE` is twice v7's (#l("#define RESIZE\t10000")). The reason is given
with `main`. As with `tp`, the variables are now defined once, in
#f("sed/sed0.c"), and only declared here.

#lines-to(none)

#source("/usr/src/cmd/sed/sed0.c")

The routine `main` reads the options. The option `-n` suppresses the automatic printing of each line, `-e` gives a line of script, and `-f` a file of script. With
neither, the first argument is the script. It then resolves the
labels and runs the script over each file named, or the input.

The pointer `reend` marks the end of the space for compiled expressions and text.
The routine `fcomp` compares the next free byte with it before it compiles an
address or a right-hand side, not while it does so, and one regular
expression may take `ESIZE` bytes and one text a whole line, and v7 put
`reend` at the end of `respace`, so that the last thing compiled could
run past it. It is now that much short of the end (#l("reend = &respace[RESIZE-LBSIZE-ESIZE-32];")), and `RESIZE`
was doubled to keep the room which v7 had. `-f` with no file now stops
`sed` (#l("if(eargc-- <= 0 || eargv[1] == 0)\texit(2);")), where v7 opened a null name.

#lines-to("void", after: "}")

The routine `fcomp` compiles the script, a line at a time, read by `rline`. For
each command it compiles up to two addresses, then the command itself:
`{` and `}` nest through `cmpend`, now refusing more than `DEPTH` levels
(#l("if(depth >= DEPTH) {")--#l("}", after: "\"Too many {'s\\n\");")), where v7 wrote past the array; `:` defines a label and `b`
and `t` refer to one, which `dechain` resolves once all are known;
`a`, `i`, `c`, and `r` take a text; `s` a regular expression, a
right-hand side, and flags; `w` a file, opened at once; and `y` two
strings, compiled by `ycomp` into a table of 128 characters.

#lines-to("char\t*compsub(char *rhsbuf)")

The routine `compsub` compiles a right-hand side, with `\n` for the subexpressions
and `&` for the whole match. The routine `compile` compiles a regular expression
into the codes of #f("sed/sed.h"), as `ed` does. It now refuses an
expression with no delimiter at all (#l("if(seof == '\\0')", after: "char\tbracket[NBRA], *bracketp;")--#l("return(badp);", after: "char\tbracket[NBRA], *bracketp;")), which v7 compiled by
taking the null at the end of the line as the delimiter. A null within
an expression now ends it as an error (#l("case '\\0':")--#l("return(badp);", after: "case '\\n':")), where v7 skipped it
and went on reading past the end of the line. Character classes are
bit maps of 128 bits, and the characters entered in them, and the ends
of ranges, are now masked to seven bits (#l("for (c = sp[-2]&0177;"), #l("ep[(c&0177) >> 3] |= bittab[c & 07];")), so that a byte with
the top bit set cannot index outside the map.

#lines-to("static void")

The routine `rline` reads a line of script, from the argument of `-e` or from the
file, joining lines that end with a backslash. It now stores each
character before it advances (#l("p = lbuf;")--#l("*p = '\\0';")), where v7 started its pointer
one byte before the buffer, an address C does not promise. And it now
stops with "Line too long" at the end of `linebuf` (#l("static void")--#l("}", after: "fprintf(stderr, \"Line too long\\n\");")), where v7
wrote on past it. The routine `address` reads a line number, now saturating (#l("while(*rcp >= '0' && *rcp <= '9') {")--#l("}", after: "rcp++;")),
a `$`, or a regular expression. The routine `cmp` likewise no longer starts before
its strings (#l("ra = a;")--#l("if(ra[-1] == '\\0')\treturn(0);")). The routine `text` copies the text of `a`, `i`, `c`, and
`r`, removing escapes. The routine `search` finds a label, and `dechain` links each
branch to its label and each `{` to its `}`. The routine `ycomp` now refuses a `y`
with no delimiter (#l("if(seof == '\\0')", after: "char\t*sp;")--#l("return(badp);", after: "char\t*sp;")) and stops at the end of the line (#l("if(*tsp == '\\n' || *tsp == '\\0')")),
where v7 read on past it.

#lines-to(none)

#source("/usr/src/cmd/sed/sed1.c")

The routine `execute` runs the script over one file. For each line read by `gline`
into the pattern space it walks the commands, deciding for each whether
its addresses select the line. A command with two addresses is "in
range", `inar`, from a line matching the first to one matching the
second. A line number in an address is an index into `tlno`, now
masked to a byte (#l("c = p2[1]&0377;"), #l("c = p1[1]&0377;")), since it is stored in a `char`. Unless `-n`
was given or the line deleted, the pattern space is printed at the end,
followed by any text queued by `a` and `r`.

#lines-to("int", after: "delflag = 0;")

The routines `match` and `advance` match a compiled expression, as in `ed`. Several
loops which walked back through the line now stop at its start (#l("if(lp - curlp < ct)\tbreak;"),
#l("} while(lp > curlp && lp--);", before: "if(*ep == CBACK) {"), #l("} while(lp > curlp && lp--);", after: "c = *(braslist[ep[1]&0377]);"), #l("} while (lp > curlp && lp--);")), where v7 stepped the pointer one byte before it, an
address C does not define. A repeated back-reference to an empty
subexpression now matches at once (#l("if(ct == 0)")--#l("continue;", after: "if(ct == 0)")), where v7 looped for ever
advancing by nothing. And an empty match at the point where the last
match ended is now refused (#l("if(lp == locs)", after: "case CEOF:")--#l("return(0);", after: "case CEOF:")), as the loops of `star` already
refused it, so that `s/x*/y/g` cannot match there twice. The numbers of
subexpressions are masked to a byte before they index (#l("braslist[*ep++&0377] = lp;")--#l("ct = braelist[*ep++&0377] - bbeg;", after: "case CBACK|STAR:")).

#lines-to("static int")

The routine `substitute` replaces a match, or every match with `g`, by building
the new line in `genbuf` with `dosub` and `place`. A line which grows
past `LBSIZE` now stops `sed` with "Output line too long" (#l("*sp++ = c&0177;")--#l("fprintf(stderr, \"Output line too long.\\n\");", after: "while ((*sp++ = *lp++))"),
#l("*sp++ = *l1++;")--#l("exit(2);", after: "*sp++ = *l1++;")); v7 printed that and carried on writing past the buffer.

The routine `command` performs a command. The commands `a` and `r` queue their text in `abuf`.
When more than `ABUFSIZE` are queued, the last is now overwritten
(#l("aptr--;", after: "fprintf(stderr, \"Too many appends after line %ld\\n\","), #l("aptr--;", after: "fprintf(stderr, \"Too many reads after line%ld\\n\",")) instead of the array overrun. `G` and `H` append one space
to the other after a newline. They now check the room before writing
the newline as well as the characters (#l("if(p1 < lbend)", after: "p1 = spend;")--#l("spend = p1;"), #l("if(p1 < hend)")--#l("hspend = p1;")). `N` does
the same (#l("if(spend < lbend)")--#l("*spend++ = '\\n';")). The command `l` prints a line with its control characters
made visible, now taking bytes as unsigned (#l("if((*p1&0377) >= 040) {")). The command `y` now leaves bytes
with the top bit set as they are (#l("while((*p1 = *p1 & 0200 ? *p1 :")), where v7 used them to index
its table of 128 characters with a negative number.

#lines-to("char\t*", after: "break;")

The routine `gline` reads a line from the input, a block at a time. At the end of
the last file it sets `dolflag`, so that `$` matches the line just
read. A failed read is now treated as an empty block (#l("c = 0;")), where v7
set the end of its buffer from the $-1$ which `read` returned. The routine `arout`
writes the queued text after the line, and no longer starts its
pointer before `abuf` (#l("for(aptr = abuf; *aptr; aptr++) {")).

#lines-to(none)

#source("/usr/src/cmd/tsort.c")

The command `tsort` reads pairs of names, each meaning that the first comes before
the second, and prints the names in an order consistent with all the
pairs. Each name is a `nodelist` with the list of its immediate
predecessors. The program repeatedly prints a live node with no live
predecessor and kills it. When none is left but live nodes remain,
there is a cycle, and `findloop` walks back along predecessors until a
node repeats, prints the cycle, and lets the walk continue from it.
The preprocessor renames `index` (#l("#define index tindex")), since the library has an
`index` of its own.

The names are now read into buffers of 512 bytes with their length
limited (#l("char precedes[512], follows[512];"), #l("x = fscanf(input,\"%511s%511s\",precedes, follows);")), where v7 read with `%s` into 50 bytes and overran
them with a long name. And a failed `malloc` for an edge is now
reported (#l("if(t==NULL)")--#l("error(\"too many items\",empty);", after: "if(t==NULL)")).

#lines-to(none)

#source("/usr/src/cmd/rev.c")

The command `rev` copies its files, or its input, reversing the characters of each
line. A line longer than `N`, 256 characters, is reversed in pieces of
that length.

#lines-to(none)

#source("/usr/src/cmd/split.c")

The command `split` cuts a file into pieces of `count` lines, 1000 by default,
named by the output name, `x` by default, followed by `aa`, `ab`, and
so on. The name is now allocated to fit the output name given (#l("fname = malloc(strlen(ofil)+3);")),
where v7 built it in an array of 100 bytes. A count of zero is now
refused (#l("if((count = atoi(argv[i]+1)) == 0) {")--#l("}", after: "fprintf(stderr,\"bad count\\n\");")): v7 then wrote a first piece of one line, since the
loop over lines runs its body at least once, and then a second, empty
name for each further line.

#lines-to(none)

#source("/usr/src/cmd/random.c")

The command `random` copies each line of its input with probability $1/n$, $n$
being the argument, 2 by default, and exits with a random number below
$n$, which a shell script can test, and `-e` only sets the exit status, and
`-r` leaves the output unbuffered. The lines are now copied a character
at a time (#l("{\tif((i = getchar()) == EOF) break;")--#l("if(r) putchar('\\n');")), where v7 read each with `gets` into a fixed buffer.
And the exit status is now computed only when $n$ fits in an `int`
(#l("exit(fract < 2147483648.? (int)(rand()/MAXINT*fract): 0);")), since converting a larger number is undefined. The seed is taken
from the 64-bit time (#l("long long tvec;"), #l("time(&tvec);")--#l("srand((int)tvec);")).

#lines-to(none)
#source("/usr/src/cmd/sum.c")

The command `sum` prints a 16-bit checksum of each file and its size in blocks of
`BUFSIZ`, 512 bytes. Before each byte is added the sum is rotated
right by one bit, so that the order of the bytes matters.

#lines-to(none)

#source("/usr/src/cmd/look.c")

The command `look` prints the lines of a sorted file which begin with a given
string, by default from the dictionary `/usr/dict/words`, folding case
and ignoring punctuation. It binary-searches the file by seeking:
`mid` is moved to the start of the next line, and the range narrowed
until it can be scanned. The routine `canon` reduces a string to the form compared,
dropping all but letters and digits with `-d` and folding upper case
with `-f`, and `-t` ends the key at a given character.

The key is now reduced in place in the argument (#l("canon(argv[1],key = argv[1]);")), which `canon`
can only shorten, where v7 copied it into an array of 50 bytes, and
The routine `getword` stops storing at the end of `entry` (#l("if(w < &entry[sizeof entry - 1])")). The routine `compare` now
compares bytes as unsigned (#l("(*s&0377)<(*t&0377)? -2:")), the order of `sort`. And `puts` is
called with its one argument (#l("puts(entry);", after: "while(ftell(dfile)<top) {"), #l("puts(entry);", after: "while(getword(entry)) {")), and v7 passed `stdout` as well,
which the function ignored.

#lines-to(none)

#source("/usr/src/cmd/col.c")

The command `col` filters out reverse line feeds, so that the output of `nroff`
with multi-column text or tables can go to a device which cannot move
the paper backwards. It keeps the last `PL` half-lines in core, in
`page`, assembling the current one in `lbuff`, and writes each
half-line out once nothing can come back to it. The escapes `ESC 7`,
`ESC 8`, and `ESC 9` move a full or half line up, or a half line
down, and `-f` keeps forward half-lines in the output. A character placed
where another stands is overstruck with a backspace unless `-b` is
given, and characters between `SO` and `SI` are marked with `GREEK`,
the top bit, so that the shifts can be put back on output. `-x` stops
`emit` turning runs of spaces into tabs.

The routine `outc` now drops a character which would make the line longer than
`lbuff` (#l("if (strlen(lbuff) + cp + 3 >= LINELN)")--#l("return;")), and v7 assembled the line without looking at its
length. Though `nroff` is not part of this system, `col` serves any text
that uses the same escapes.

#lines-to(none)

#source("/usr/src/cmd/ptx.c")

The command `ptx` makes a permuted index: each line of the input appears once for
each significant word in it, rotated so that the word comes first, and
the result is sorted and laid out for `troff` as `.xx` lines with four
fields, the text before and after the word, either side of a gutter.
Words in the ignore file, by default `/usr/lib/eign`, are skipped, or
with `-o` only the words in the given file are used, and `-b` names the
characters which break words.

The routine `main` reads the word list into a buffer and a hash table, `hasht`,
whose search wraps round and stops only at an empty slot, and `storeh` now
refuses the last slot (#l("if(++nh >= MAXT)")--#l("return(1);", after: "if(++nh >= MAXT)")), so that one is always empty, where v7
filled the table and the search could go round for ever. An empty word,
between two adjacent breaks, is no longer stored (#l("if(bufp > strtbufp &&")). The break table
now has 256 entries (#l("char btable[256];")), since `getc` returns bytes up to 255 and v7's
128 were overrun by a break file with such a byte. The bytes of the
text are masked before they index it (#l("if(isabreak(*pchar++&0377))"), #l("if(isabreak(*pchar&0377)) {")). The options which take
an argument no longer read past the last one (#l("if(argc > 2) {")--#l("if(argc>2) {")), and a width
which leaves no room for the gap is refused (#l("if(gap < 0 || gap > LMAX || llen < gap+2)")--#l("diag(\"Wrong width\",empty);")).

The routine `cmpline` writes, for each word kept, the rotated line to a temporary
file, with `TILDE` marking where the line originally began, and
`/bin/sort` sorts it. The file's name is now an array (#l("char sortfile[] = \"/tmp/ptxsXXXXX\";\t/* output of sort program */")), into which
`mktemp` writes, and v7 passed it a string constant. An exec of `sort`
that fails is now reported (#l("diag(\"Cannot exec\", SORT);")).

#lines-to("void", lead: true, after: "return(0);")

The routine `getsort` reads the sorted lines and lays out each in the four fields,
trimming at word boundaries with `rtrim` and `ltrim` and marking
truncation with `/`. The buffer `line` now has room for twice `LMAX` (#l("char line[2*LMAX+4];")), since
each `"` is doubled for `troff`, and both copies are checked against
its end (#l("if(linep < &line[sizeof line - 2])", after: "/* put double \" for \"  */")--#l("*linep++ = c;", before: "char *b,*x;")), as `getline` now leaves room for the newline (#l("endlinep= line + mlen - 1;")).
The handler `onintr` removes the temporary file. It now exits with 0 when called at
the normal end (#l("exit(sig != 0);")), where v7 always exited with 1.

#lines-to(none)

#source("/usr/src/cmd/deroff.c")

The command `deroff` strips the requests, macros, escapes, equations, and tables
of `troff`, `eqn`, and `tbl` from text, leaving the words, so that
they can be checked for spelling or counted, and `-w` prints one word per
line. All input goes through the macro `C` (#l("#define C ( (c=getc(infile)) == EOF ? eof() : ((c==ldelim)&&(filesp==files) ? skeqn() : c) )")), which also skips
equations between the delimiters which `eqn`'s `delim` sets. The routine `work`
reads a line at a time: a line beginning with `.` or `'` is a request,
handled by `comline`, which follows `.so` and `.nx` into other files,
skips macro definitions and the bodies of `.EQ` and `.TS`, and keeps
the arguments of a few macros. Other lines go to `regline`, which drops
the backslash constructions through `backsl`.

The class table `chars` now has 256 entries (#l("char chars[256];  /* SPECIAL, APOS, DIGIT, or LETTER */")), and bytes are masked
before they index it (#l("if(t>s+2 && chars[ s[0]&0377 ]==LETTER &&"), #l("while( chars[*p1&0377] < DIGIT)")--#l("chars[ p1[1]&0377 ]==LETTER) )")), where v7's 128 entries were
indexed by `char`s that could be negative. The routine `regline` now stops filling
`line` at its end (#l("if(lp >= &line[sizeof line-2])")--#l("--lp;", after: "if(lp >= &line[sizeof line-2])")), dropping the rest of a long line, and v7 wrote
past it. The name of a file to include now has 256 bytes (#l("char fname[256];")), and the
nesting of included files stops with a message at the 15 that `files`
holds (#l("if( fname[0] && filesp == &files[14] )")--#l("fatal(\"Too many nested files at %s\\n\", fname);")), and v7 had 50 bytes for the name and no check of the
depth. And `\s` at the very start of a line no longer backs `lp` up
before `line` (#l("if(lp > line)")--#l("--lp;", after: "if(lp > line)")).

#lines-to(none)

#source("/usr/src/cmd/checkeq.c")

The command `checkeq` checks text for `eqn`. It reports unbalanced `.EQ` and `.EN` lines,
delimiters set with `delim` and left unclosed, and equations spread over several lines, each with its line number. It is
v7's, with prototypes.

#lines-to(none)
#source("/usr/src/cmd/cb.c")

The C beautifier, `cb`, reads C on its input and writes it indented by
its nesting, one statement to a line, with `else` and `case` placed
conventionally. Comments and strings are copied as they are. It works
on characters, not on a parse of the language, keeping the depths of
braces, parentheses, and `if`s in small arrays and the text of the
current statement in `string`.

The arrays of levels now have 20 entries, and `string` 1000 bytes
(#l("int\tslevel[20];")--#l("char\tstring[1000];")), where v7 had 10 and 200, and each is now checked: nesting
deeper, or a statement longer, now stops `cb` with a message
(`toodeep`), where v7 wrote past the arrays. And a closing
brace without an opening one no longer makes the level negative (#l("if(clevel > 0)clevel--;")).
End of input now writes what is pending and stops (#l("if(lastchar == EOF){")--#l("}", after: "exit(0);")), where the
loops which skip to a semicolon or parenthesis went on reading `EOF`
for ever. The preprocessor renames the program's own `puts` and `gets`
(#l("#define\tputs\tcb_puts")--#l("#define\tgets\tcb_gets")), since `<stdio.h>` declares the library's.

#lines-to(none)
#source("/usr/src/cmd/sp.c")

The program `sp` saves paper by printing short lines several to a line, each
starting at a tab stop, as long as they fit in the width given, 80 by
default. The routine `getit` reads a line, measuring it with its tabs expanded both
where it began and where it would go. It now stops at the end of its
256-byte buffer (#l("for(i=0;i<(int)sizeof buf;i++)")), treating a longer line as ending there, where v7
read on past it. The absolute value of a negative width is now taken
unsigned (#l("if(i<0) i= -(unsigned)i;")), so that the most negative `int` does not overflow.

#lines-to(none)
#source("/usr/src/cmd/vpr.c")

The command `vpr` printed files on a Versatec electrostatic printer through
`/dev/vp0`, with an optional banner of large letters, and charged the
pages to `/usr/adm/vpacct`. The port has no such printer or driver, so
`vpr` stops at once with "Can't open printer". It is kept as part of
v7. Overstruck characters, which the printer could not print, are
gathered into a second line printed over the first. The banner's
letters come from `chrtab`, sixteen bytes of dots per character. The v7 code
declared it as an array of 16-byte rows whose size was given only by
the later definition, which C does not allow. It is now a flat array of
`unsigned char`, indexed by character and row (#l("unsigned char\tchrtab[];"), #l("t = chrtab[(*sp - ' ')*16 + i];"), #l("unsigned char\tchrtab[] = {")). The time
of the banner is a `long long` (#l("long long timeb;")).

#lines-to(none)
#source("/usr/src/cmd/tk.c")

The command `tk` shows text, such as the output of `nroff`, on a Tektronix 4014
storage-tube terminal, in one column or several across the screen.
Each character is placed by the terminal's graphics mode, `sendpt`
sending only the parts of the address that changed, and the
reverse and half-line motions of `nroff` are honoured. When the screen
is full `tk` waits for a newline from `/dev/tty`, and `!` there runs a
shell command. Apart from prototypes and a signal handler's argument it
is v7's. The shell it runs on `!` now ends the child if it cannot be
executed (#l("{", after: "sendpt(int a)")), where v7's child went on running `tk`.

#lines-to(none)
#source("/usr/src/cmd/tc.c")

The command `tc` simulates the C/A/T phototypesetter on the Tektronix 4014: it
reads `troff`'s output for the typesetter, a stream of escapes, size
and font changes, and character codes, and draws each character at
its place, in the size and font asked for as nearly as the terminal
can. Pages are shown one at a time, waiting at the end of each as `tk`
does. The program's own `atoi`, which reads a number from its input, is renamed with the preprocessor (#l("#define\tatoi\ttcatoi")), and `oput` loses the trailing `else`
which made it a statement that swallowed the next `else` (#l("#define\toput(c) if (pgskip==0) putchar(c)")).

The reply typed at the end of a page now stops at the end of its
buffer (#l("while((c=readch())&&(c!='\\n')) if(bptr<&buf[127]) *bptr++=c;")), a character with no entry in the tables is now skipped
(#l("if(k && *k!='\\0'){")), and a number read from the input stops growing before it
overflows (#l("if(acc >= 100000)continue;")), and v7 overran the buffer, followed a null pointer, and
overflowed.

#lines-to(none)
#source("/usr/src/cmd/graph.c")

The command `graph` draws a graph of pairs of numbers read from its input, with
axes, grid, labels, and a title, scaled to fit or as the options say,
on linear or logarithmic axes. It writes the device-independent plot
format of v7, which filters such as `tek` turned into drawing on a terminal. It writes a letter for each operation, `m` to move, `n` to continue a
line, `t` for a label, followed by 16-bit coordinates, low byte first.
In v7 the routines that wrote it, `space`, `move`, `line`, and the
rest, came from the plotting library, `-lplot`. That library is not
part of this system, so the few `graph` needs are now defined at its
end (#l("}", after: "exit(1);")--#l("}", after: "fflush(stdout);")).

Since the format's coordinates are 16-bit, every coordinate now goes
through `fix` (#l("}", after: "return(x < -32768? -32768: x < 32767? (int)x: 32767);")--#l("main(int argc, char *argv[])")), which clamps it to that range, where v7's
conversion of a large `float` to `int` was undefined. The routine `conv` now
computes in `double` and tests the range so that a NaN falls outside
(#l("double ix;")--#l("*ip = ix;")). The title and labels are now read with their lengths
limited (#l("while ((*p1++ = *p2++) &&"), #l("i = scanf(\"%79s\",labbuf);")--#l("scanf(\"%19[\\\"]\",junk);")), the table of tick marks stops at its 50 entries
(#l("for(x=xl; x<=xu && xn<50; x+=fabs(p->xquant))"), #l("if(*pxn < 50 && 1.001*p->xlb < x && .999*p->xub > x)")), and the first value structure is cleared by `calloc` (#l("xx = (struct val *)calloc(1, (unsigned)sizeof(struct val));")).

#lines-to(none)
#source("/usr/src/cmd/spline.c")

The command `spline` reads pairs of numbers and writes, for `graph`, a smooth curve
through them: a cubic spline, whose second derivatives come from a
tridiagonal system of equations, with a choice of end conditions, or a
periodic one with `-p`. The routine `rhs` gives the right-hand side of the system
for point `i`. For the periodic spline the last point wraps round to
the first, through `i_`. The v7 code used `i_` for the differences of `y` but
`i` for those of `x` in the same quotient (#l("return(6*((y.val[i_+1]-y.val[i_])/(x.val[i_+1]-x.val[i_]) -")), so that at the last
point it divided the wrong difference and read past the data. Both now
use `i_`. The number of points interpolated between two given ones is
now computed in `double` and kept within range (#l("dm = 1.001*(hi1>0?ni:-ni)*hi1/(x.ub-x.lb);")--#l("m = dm >= 1 && dm < 2e9? dm: 1;")), and the
buffer for a number has room for the null after its 30 characters
(#l("getfloat(float *p){")).

#lines-to(none)
#source("/usr/src/cmd/diff3.c")

The command `diff3` compares three versions of a file. It does not compare them
itself: it reads two reports from `diff`, of the first file against
the third and of the second against the third, and the three files,
and prints the places where they differ, marked by which of them
disagrees, or with `-e` an `ed` script that folds the differences
between the second and third files into the first. The command a user
types is v7's shell script `/bin/diff3`, which runs the two `diff`s
into temporary files and then this program, which lives in
`/usr/lib`.

The routine `readin` reads the line numbers of each change in a report into an
array of `diff`s, and adds one more entry after the last, giving the
positions at the end. The arrays now have room for that entry (#l("struct diff d13[NC+1];")--#l("struct diff de[NC+1];")):
v7 refused more than `NC` changes but then wrote the extra entry past
the end of a full array, and wrote one before the start of an empty
one, which is now skipped (#l("if(i>0) {")--#l("}", after: "dd[i].new.from = dd[i-1].new.to;")). A report which cannot be opened
is now reported (#l("if((fp[0] = fopen(name,\"r\")) == NULL) {")--#l("}", after: "fprintf(stderr,\"diff3: can't open %s\\n\",name);")), and an unreadable one makes `diff3` exit
with 1 rather than 0 (#l("exit(1);", after: "fprintf(stderr,\"diff3: too many changes\\n\");")). The routine `number` now stops growing before it
overflows (#l("while(digit(**lc)) {")--#l("}", after: "(*lc)++;")).

The routine `getline` reads a line, keeping as much of it as `line` holds. It now
reads a long line to its end and returns its whole length (#l("for(i=j=0;;i++) {")--#l("return(0);", after: "if(j<(int)sizeof(line)-2)")),
since the caller counts bytes to position itself in the files, and v7
returned a long line in pieces of 255 characters, which threw the
counts of lines out.

The routine `merge` walks the two lists of changes together, matching the parts of
each that concern the same lines of the third file, and calls `change`
and `edit` to report them, and `duplicate` notices when the first two files
were changed alike.

#lines-to(none)

#source("/usr/src/cmd/diffh.c")

The "half-hearted" `diff`, `diffh`, is what `diff -h` runs
(#f("cmd/diff.c")) for files too large for the real algorithm. It keeps
only a window of `RANGE` lines of each file in core, and after a
difference looks for the next place where `C`, three, lines agree in
both: `easysynch` tries cheaply, `hardsynch` searches the whole window.
It cannot find the shortest set of changes, and gives up on changes
longer than the window, but it needs little memory.

The test for an option now checks that there is an argument (#l("if(argc>1 && *argv[1]=='-') {")). The
character given to `isspace` is masked to a byte (#l("if(bflag&&isspace(*s&0377)&&isspace(*t&0377)) {")--#l("while(isspace(*++t&0377)) ;")), since a
negative `char` is not a valid argument. When a file is given as a
directory, `dopen` builds the name of the file in it in a buffer which
now has 512 bytes and is checked first (#l("char b[512],*bptr,*eptr;")--#l("while((*bptr++= *f2++)) ;")), and v7 built it in 100
bytes without looking.

#lines-to(none)

#source("/usr/src/cmd/fgrep.c")

The command `fgrep` searches for any of a set of fixed strings, given as an
argument, one to a line, or in a file with `-f`. It builds from them
the automaton of Aho and Corasick: `cgotofn` makes a tree of the words,
in which a state is a list of `words` entries linked through `link`,
one for each character that can follow, and `cfail` adds to every
state a failure link, the state for the longest proper suffix of what
has been matched that is also a prefix of some word. The routine `execute` then
runs the input through the automaton once, never backing up, and
prints each line in which some word ends. The options are those of
`grep`. Its messages now name it rather than `egrep` (#l("fprintf(stderr, \"fgrep: unknown flag\\n\");"), #l("fprintf(stderr, \"fgrep: can't open %s\\n\",", after: "if (wordf==NULL) {")), from
which it was adapted.

The words are now read as unsigned bytes (#l("if ((c = wordf ? getc(wordf) : *argptr++ & 0377) == '\\0')"), #l("loop:\tif ((s->inp & 0377) == c) {")), so that a word
with bytes above 127 can match. In `execute`, an empty entry, whose
character is a null, no longer matches a null in the input (#l("if (*p && c->inp == *p) {", after: "nstate:"), #l("if (*p && c->inp == *p) {", after: "istate:")).

#lines-to("void", after: "return(c);")

The routine `cfail` computes the failure links breadth first, with a circular
queue. The v7 version was wrong in two ways. To find where a state fails
to, it tried only the alternatives of one state, and when none matched
it stopped, leaving the link at the start instead of following the
failure links further. And after finding one it left the loop with
`continue`, so that the other alternatives of the state being processed
got no links at all. Both made `fgrep` miss matches of words which
overlap others. The search now follows the failure links until a match
or the start (#l("floop:\tfor (t = state? state: w; t != 0 && t->inp != c;")--#l("}", after: "goto floop;")), and sets the link on every entry of the new
state (#l("qloop:\tq->fail = t->nst;")--#l("if ((q = q->link) != 0) goto qloop;")), all of which share it. The queue now has a slot for
every state (#l("#define QSIZE MAXSIZ")), where v7's 400 overflowed for large word lists, and
its wrapping is simpler (#l("if (++rear == &queue[QSIZE])")--#l("if (rear == front) overflo();")).

#lines-to(none)

#source("/usr/src/cmd/crypt.c")

The command `crypt` enciphers its input with a key, by a machine on the lines of
the Enigma with one rotor, `t1`, its inverse `t2`, and a reflector,
`t3`. Since the reflector pairs each position with another, the same
key deciphers what it enciphered. The rotor steps once per byte, and a
second rotor position, `n2`, once per 256 bytes. The routine `setup` turns the key
into 13 characters by running `makekey`, the password-hashing program,
through a pipe, and from them seeds a generator which shuffles `t1` and
pairs the positions of `t3`.

The seed is now unsigned (#l("unsigned long seed;")), so that its arithmetic wraps instead of
overflowing. It is converted to `long` before the remainder (#l("random = (long)seed % 65521;")), which
then gives v7's values, so that a file enciphered under v7 deciphers
here. The routine `setup` now waits for `makekey` itself (#l("while ((i = wait((int *)NULL)) != pid && i != -1)")--#l(";")), where v7 took
whatever child `wait` returned first.

#lines-to(none)

== Little Languages <ch-lang>

#source("/usr/src/cmd/test.c")

The command `test` evaluates an expression made of its arguments and exits with 0
if it is true, 1 if false, and 255 for a malformed one. It is how the
shell's `if` and `while` test files and strings. Called as `[`, it
requires a closing `]`. The expression is parsed by recursive descent as it is evaluated, with `exp` for `-o`, `e1` for `-a`, `e2` for `!`, and
`e3` for parentheses and the primaries, which test files (`-r`, `-w`,
`-f`, `-d`, `-s`), terminals (`-t`), strings (`-z`, `-n`, `=`, `!=`),
and integers (`-eq` and the like, with `-l` giving a string's length).
`EQ` (#l("#define EQ(a,b)\t((tmp=a)==0?0:(strcmp(tmp,b)==0))")) treats a missing argument as unequal to anything.

#lines-to(none)

#source("/usr/src/cmd/expr.y")

The command `expr` evaluates an expression given as its arguments, one token to
an argument, and prints the result. It is how the shell does
arithmetic. Its grammar is written for `yacc`, which makes from it the
parser `yyparse`. The operators, in rising precedence, are `|` and `&`,
the comparisons, `+` and `-`, `*`, `/`, and `%`, and `:`, which matches a
regular expression, and `substr`, `length`, `index`, and `match` are
prefix functions. Every value is a string, and the exit status is 1
when the result is zero or empty. The actions are now written without
the `=` before the brace (#l("expression:\texpr NOARG {")--#l("| INDEX expr expr { $$ = index($2, $3); }")), an old form of `yacc`'s which
`bison`, the parser generator the build uses, does not accept.

#lines-to("/*\texpression command */")

The routine `yylex` returns each argument as a token: an operator from the table,
or a string. The preprocessor renames `index` (#l("#define index expr_index")), since the
library has an `index` of its own, and the table, `operators`, no
longer has the name of the C++ keyword `operator`.

The routine `rel` compares as numbers when both operands are integers, else as
strings. Several of v7's errors are corrected here: `<=` returned
`i>=0`, the result of `>=` (#l("case LEQ: i = i<=0; break;")); a negative right operand was not
taken as a number (#l("if(ematch(r1, \"-*[0-9]*$\") && ematch(r2, \"-*[0-9]*$\"))")); and the comparison subtracted the two numbers,
which can overflow, where it now compares them (#l("i = atol(r1) < atol(r2)? -1: atol(r1) > atol(r2);")). The routine `arith` likewise
now accepts negative operands (#l("if(!(ematch(r1, \"-*[0-9]*$\") && ematch(r2, \"-*[0-9]*$\")))")), reports division by zero (#l("if(i2 == 0 && (op == DIV || op == REM))")--#l("yyerror(\"division by zero\");")),
and computes in `long long`, reporting a result which does not fit in a
`long` (#l("long long i1, i2;"), #l("if((long)i1 != i1)")--#l("yyerror(\"overflow\");")), and v7 let the machine trap or wrap. The routine `substr` now
treats a position or length of zero or less as nothing (#l("while(--si > 0) if(*v) ++v;"), #l("while(wi-- > 0) if(*v) ++v;")), and
returns a copy of the substring (#l("wi = v - res;")--#l("return v;")), where v7 wrote a null into
the argument itself.

#lines-to("#define INIT\tregister char *sp = instring;")

The regular expressions are those of `ed`, compiled by `compile` and
matched by `advance`, with `\{m,n\}` for repetition. The routine `ematch` keeps
the text matched by `\(...\)` in `Mstring`, now allocated to its length
(#l("strncpy(Mstring[0] = malloc(num + 1), p, num);")), where v7 copied it into 128 bytes. `RETURN` and `ERROR` (#l("#define RETURN(c)\treturn(c)")--#l("#define ERROR(c)\treturn(errxx(c), (char *)0)"))
now return values, as `compile` requires. The routine `compile` now checks its room
one byte early (#l("if (ep >= endbuf - 1)")), since a code may take two; refuses an unclosed
`\(` (#l("if (bracketp != bracket)")--#l("ERROR(42);", after: "if (bracketp != bracket)")), an unended class (#l("if(c == '\\0' || c == '\\n')", after: "neg = 1;")--#l("ERROR(49);", after: "neg = 1;"), #l("if(c == '\\0' || c == '\\n')", after: "PLACE('-');")--#l("ERROR(49);", after: "PLACE('-');")), and a `\{`
after anything but a single character (#l("if(*lastep < CCHR ||")--#l("ERROR(44);", after: "*lastep > (CCL|STAR) || *lastep & 2)")); and stops reading a
count once it is too large (#l("} while(((c = GETC()) != '\\\\') &&")). Characters entered in a class are
masked to seven bits (#l("#define PLACE(c)\tep[(c & 0177) >> 3] |= bittab[c & 07]")), and subexpression numbers masked to a byte
before they index (#l("braslist[*ep++&0377] = lp;")--#l("if(ct == 0)")), where the `char` might be negative. A
repeated back-reference to an empty subexpression now matches at once
(#l("if(ct == 0)")--#l("continue;", after: "if(ct == 0)")) instead of looping for ever, and `getrnge` compares the
marker for "no upper bound" as unsigned (#l("size = (*str & 0377) == 255 ? 20000 : (*str &0377) - low;")).

#lines-to(none)

#source("/usr/src/cmd/bc.y")

The command `bc` is a calculator with a language like C's. It has variables, arrays, and
functions named by single letters, `if`, `while`, and `for`, and
numbers of any size and scale. It does no arithmetic itself. It is a
compiler from that language to the language of `dc` (#f("dc/dc.c")):
`main` starts `dc` with a pipe to its input, and the parser translates
each statement into `dc`'s postfix commands as soon as it is complete.
Each grammar action builds its translation with `bundle`, which gathers
pointers to strings, or to earlier bundles, into `b_space`, and `output`
then prints the tree. A function's body becomes a string stored in a
`dc` register, `if` and `while` bodies become strings executed
conditionally, named by the characters `crs` hands out, and `break`
and `return` leave them with `dc`'s `Q`.

The grammar is now free of conflicts. In v7 a statement could be any
expression, `e`, including an assignment, which the statement rules
also covered, so the parser generator met two ways to read `a=1`, and
v7's `yacc` settled them by the order of the rules. Expressions without assignment are now `ex`
(#l("ex\t:  e '+' e")), assignments are added to make `e` (#l("e\t:  ex")--#l(";", after: "{ bundle(4,\"O\",$3,$2,\"do\"); }")), and a statement is
`ex`, whose value is printed, or one of the assignment statements,
whose value is not (#l("stat\t:  ex")--#l("geta($1));}")). A `break` outside a loop is now an error
(#l("|  _BREAK")--#l("else bundle(2, numb[lev-bstack[bindx-1]], \"Q\" ); }")), where v7 indexed `bstack` with $-1$. The actions are written
without the `=` before the brace, as for `expr`.

#lines-to("ex\t:  e '+' e", lead: true)

Values on the parser's stack are now `char *` (#l("#define YYSTYPE char *")). A digit is a pointer
to its character in a string of the sixteen digits (#l("yylval = index(\"0123456789ABCDEF\", c);")), where v7 put
the character itself in an `int` and stored that, and `constant` now copies
the character it points to (#l("{ $$ = cp; *cp++ = *$1; }"), #l("{ *cp++ = *$2; }")). The remainder operator is `"%"`
(#l("{ bundle(3, $1, $3, \"%\" ); }")): the strings are now printed with `printf("%s", ...)` (#l("else printf( \"%s\", p );\t /* character string */")),
where v7 used each string as its own format, so that a `%` had to be
doubled and any `%` in a quoted string misprinted. `CRS` now stops at
the 14 nested levels which `bstack` and `numb` can hold (#l("if(crs >= 0241 || lev >= 14){")), and
`crs+=3` replaces `crs=+3` (#l("if(crs == '[')crs+=3;")), the old spelling of `+=` which would
now mean an assignment of 3.

#lines-to("# define error 256")

The routine `yylex` reads characters through `getch`, looking ahead one character
for the two-character operators and recognising a keyword by its first
two letters. It now stops before the code buffer `cary` overflows
(#l("if(cp >= &cary[990]){yyerror(\"program too big\");")--#l("}", after: "if(cp >= &cary[990]){yyerror(\"program too big\");")). The routine `getch` reads the files named and then the standard input.
A file which cannot be opened is now skipped (#l("goto loop;", before: "# define b_sp_max 3000")), where v7 fell off
the end of the function and returned whatever was in the register.

The routine `bundle` now takes its arguments through `<stdarg.h>` (#l("char *(bundle)(int i, ...){")--#l("}", after: "return( yyval );")), and v7
took the address of its first argument and walked up the stack, which
worked only with the PDP-11's way of passing arguments. A macro of the
same name (#l("#define bundle(...) (yyval = (bundle)(__VA_ARGS__))")) also stores the result in `yyval`, as v7's function
did. The routine `routput` tells a bundle from a string by whether it points into
`b_space`.

#lines-to(none)

#source("/usr/src/cmd/dc/dc.h")

The command `dc` is a desk calculator for numbers of unlimited size and scale,
with a stack, registers, and strings that can be executed as programs, and
`bc` (#f("cmd/bc.y")) is a compiler into its language. Every number and
string lives in a `blk` (#l("struct blk {")--#l("};", after: "char\t*last;")), a growable byte buffer with a read
and a write pointer, managed by `salloc`, `copy`, and `release` and the
`s` macros (#l("#define length(p) ((p)->wt-(p)->beg)")--#l("#define zero(p)\tfor(pp=(p)->beg;pp<(p)->last;)*pp++='\\0'")). A number is a sequence of base-100 digits, least
significant first, each in a byte. A negative number is kept as its
complement, so that its last digit is $-1$. On the stack a number
carries one more byte after its digits, its scale, the number of
decimal digits after the point. Registers are a symbol table of `sym`s
(#l("struct\tsym {")--#l("struct\tsym *sptr,*sfree;")), one list for each byte that names a register, so that `S`
and `L` can stack values in a register. A register also holds an
array, as a block of pointers to blocks.

Reading a digit back must give a negative value for the complement's
last byte, so the macros `sgetc`, `slookc`, and `sbackc` extend the
sign of the byte by hand (#l("#ifndef pdp11")--#l("#endif", after: "#define sbackc(p)\t( ((p)->rd==(p)->beg) ? EOF :( ((*(--(p)->rd) & NEGBYTE) != 0) ? (*(p)->rd | MASK): *(p)->rd ))")). The v7 code used those versions only for the
Interdata, and on the PDP-11 relied on `char` being signed. They are
now used everywhere but the PDP-11 (#l("#ifndef pdp11"), #l("#ifdef pdp11")), since the port's compiler
makes `char` unsigned. The variable `savk`, which holds a scale, is now an `int`
(#l("int\tsavk;")).

#lines-to(none)

#source("/usr/src/cmd/dc/dc.c")

The interpreter is `commnds`: it reads a character at a time, through
`readc`, and acts on it. Digits, with an optional point and underscore
for a negative sign, push a number; `+ - * / % ^ v` do arithmetic on
the top of the stack; `p`, `f`, and `P` print; `s`, `l`, `S`, and `L`
store and load registers, `:` and `;` array elements; `k`, `i`, and `o`
set the scale and the input and output bases; `[...]` pushes a string,
`x` executes one, and `<`, `>`, and `=` execute a register's string
conditionally; `!` runs a shell command and `q` quits.

Several of the commands are corrected here. The output base, read from
a number by `o`, now stops growing before it overflows a `long` (#l("while(sfbeg(q) == 0 &&")).
`S`, `s`, `:`, and `L` took an entry from the free list of symbols and
only then checked whether the list was empty, through the null pointer
it had just followed. The check now comes first (#l("if(sfree == 0)goto sempty;", after: "error(\"save: args\\n\");"), #l("if(sfree == 0)goto sempty;", after: "0)release(q);"), #l("if(sfree == 0)goto sempty;", after: "case ':':")). A new
array register now starts as one null pointer (#l("q = salloc(PTRSZ);")--#l("putwd(q, (struct blk *)0);")), and clearing
an array skips the null entries in it (#l("while(sfeof(p) == 0)", after: "error(\"save:args\\n\");")--#l("0)release(q);")), where v7 released
them. The test of an index against an array's length is now made in
signed arithmetic (#l("if(length(p) < (c+1)*(int)PTRSZ){"), #l("if(length(p) >= (c+1)*(int)PTRSZ){")), and v7 subtracted `PTRSZ`, an unsigned size,
so that the comparison was unsigned and a short array looked long
enough. An element never stored now loads as the number zero (#l("q = salloc(1);", after: "q = copy(s,length(s));")--#l("sputc(q,0);", after: "q = copy(s,length(s));")),
where v7 pushed a block holding a null pointer. And `x` and `?` now
check the depth of nested strings before they go deeper (#l("case 'x':")--#l("((*readptr)->rd == (*readptr)->wt))"),
#l("else{", after: "if(p != 0)rewind(p);")--#l("continue;", after: "if((c = readc()) != '\\n')unreadc(c);")); v7 compared after incrementing, and in one path not at all,
so that deep recursion wrote past `readstk`. The command `x` reuses the slot of a
string it has finished, so that a string which ends by executing
another, as a loop does, does not grow the stack.

#lines-to("div(struct blk *ddivd, struct blk *ddivr)")

The routine `div` divides by long division in base 100, estimating each quotient
digit from the leading digits and correcting it. Division by zero now
prints its message and gives zero (#l("if(length(ddivr) == 0){")--#l("}", after: "rem = salloc(0);")), and v7 returned the integer 1
in place of a pointer to a number. The routines `dscale` and `removr` handle the
scales, `sqrt` takes a square root by Newton's method, and `exp`
raises to a power by repeated squaring.

#lines-to("init(int argc, char *argv[])")

The routine `init` sets up the stack, the free list of symbols, and the constants.
The free list now ends at the last entry (#l("while(sptr < &symlst[TBLSZ-1]){")), where v7 linked that to
the entry past the array. The routine `readin` reads a number from the input,
`add0` appends zeros, `mult` multiplies, and `chsign` complements. In
`readc`, v7 tested `readptr != &readptr[0]`, which is always true. The
test is now against `readstk` (#l("if(readptr != &readstk[0]){")), so that at the bottom of the
stack of strings `readc` reads from the input as intended, and the
function now returns a value at its end (#l("return(0);", after: "exit(0);")).

#lines-to("print(struct blk *hptr)")

The routine `print` prints a number in the output base, using `tenot` for base ten,
`hexot` and `bigot` for others, breaking lines at `ll` characters.

#lines-to("add(struct blk *a1, struct blk *a2)")

The routine `add` adds two numbers digit by digit with carry, and `eqk` brings two
numbers to the same scale. The routine `command` runs a shell command for `!`. The
line is now kept within its buffer (#l("while((c = readc()) != '\\n')", after: "*sl++ = c;")--#l("}", after: "printf(\"command too long\\n\");")), where v7 copied it
without a limit. The routine `cond` executes a register for the comparisons, and
`load` loads one. The routine `log2` finds the position of a number's top bit. It
now shifts up to bit 30 and stops (#l("while(n < 0x40000000L){")--#l("}", after: "i--;")), where v7 shifted until
the number went negative, an overflow C does not define.

#lines-to("salloc(int size)")

The rest manages storage. The routine `salloc` allocates a block and its header. The routine `more` doubles a block
when it fills, `garbage` reclaims, and `copy` makes a copy of a given size. The routine `nalloc` now takes both the number of
bytes to copy and the size to allocate (#l("nalloc(register char *p, unsigned n, unsigned nbytes)")--#l("}", after: "*q++ = *p++;")), and `copy` copies
only the length of the original (#l("sz = length(hptr);")--#l("ptr = nalloc(hptr->beg, sz, (unsigned)size);")): v7 copied the full new
size, reading past the end of a smaller block. The routines `getwd`, `putwd`, and
`lookwd` handle arrays, whose words are pointers.

#lines-to(none)

#source("/usr/src/cmd/egrep.y")

The command `egrep` searches for lines matching a full regular expression, with
alternation `|`, grouping, and the operators `*`, `+`, and `?`. The
expression is parsed by a `yacc` grammar into a tree, and from the
tree `cgotofn` builds a deterministic automaton directly, by the method
of following positions: each state is a set of positions in the
expression, `cfoll` computes for each position the positions which can
follow it, and the automaton's transitions are made lazily, a state at
a time, as the input needs them, `NSTATES` at most. The routine `execute` then
runs each line through the automaton once, never backing up, so the
time is linear in the input. The options are those of `grep`.

The automaton's table now has 256 columns (#l("#define NCHARS 256")): `execute` indexes it
with each input byte made positive (#l("cstat = gotofn[cstat][*p&0377];\t/* all input chars made positive */")), and v7's 128 columns let a
byte above 127 read the next state's row. For the same reason `chars`,
which holds the characters of the classes and their counts, is now an
array of `int`s (#l("int chars[MAXLIN];")), and `nextch` returns bytes unsigned (#l("else c = *input++ & 0377;")). The
grammar's last conflict, which `bison` would report, is resolved by
declaring a precedence for `error` (#l("%left error")). The checks for a full state table and position array
were one short, and now leave room for the entry about to be written
(#l("if (n >= NSTATES-1) overflo();"), #l("add(int *array, int n) {")). An escaped character now jumps to `defchar` (#l("goto defchar;", after: "if ((c = nextch()) == '\\0') synerror();")) instead
of falling into it, and the old initialisations without `=` (#l("int line = 1;"), #l("int nxtchar = 0;"))
are written in C99's form.

#lines-to(none)

#source("/usr/src/cmd/awk/awk.g.y")

The command `awk` is a language for scanning text: a program is a list of patterns,
each with an action, and every input line is split into fields and
matched against every pattern, the action running for each that
matches. It is built of several parts. The lexical analyser,
#f("awk/awk.lx.l"), and this grammar, for `lex` and `yacc`, turn the
program into a tree of `node`s, built by the functions of
#f("awk/parse.c"). The file #f("awk/run.c") interprets the tree, through the
table `proctab` of functions for each operator, which the program
#f("awk/proc.c") generates at build time. The file #f("awk/tran.c") keeps the
variables in symbol tables, #f("awk/lib.c") reads records and splits
them into fields, and #f("awk/b.c") compiles regular expressions into
automata. The declarations shared by all are in #f("awk/awk.def").

The values on `yacc`'s stack are `int`s, and pointers to nodes pass
through them. In v7 the functions which build nodes were declared to
return `int`, so that nothing was converted. They now return `node *`
and take `node *` arguments, and macros of the same names (#l("#define\tN\t(node *)")--#l("#define\tnullstat\t(int)nullstat"))
convert the grammar's `int`s to pointers and back, which on the port,
where the two have the same size, preserves them.

The grammar is now free of conflicts. The v7 grammar left `yacc` to resolve them
by its defaults, and `bison` reports each. The precedences added to
the declarations (#l("%left\tNL SPRINTF SPLIT ',' '{' ELSE")) and the `%prec ASGNOP` on several rules
(#l("var %prec ASGNOP")--#l("{ PUTS(\"if stat\"); $$ = stat3(IF, $1, $2, nullstat); }")) settle each the way those defaults did, so that programs
parse as before.

#lines-to(none)

#source("/usr/src/cmd/awk/awk.lx.l")

The lexical analyser recognises `awk`'s tokens. It has start states for
ordinary text (`A`), strings (`str`), character classes (`chc`), and
regular expressions (`reg`), which `startreg` enters when the grammar
sees a `/` that begins one. A name becomes a variable in the symbol
table at once, and a number or string a constant, so that the token's
value is a pointer to its `cell`. As in the grammar, it passes through
`yylval`, an `int` (#l("yylval = (int)lookup(\"$record\", symtab);")--#l("RETURN(STRING); }")).

The analyser is now written for `flex`, which takes the place of v7's
`lex`. The scanner generator `flex` does its own buffering and calls `YY_INPUT` (#l("#define\tYY_INPUT(buf,result,max_size) \\")--#l("} while (0)")) for
more, which is made to call `input` a character at a time, so that
`input` no longer handles pushed-back characters (#l("int", after: "<chc>.\t\t{ CADD; }")--#l("}", after: "return(c);")). Its start
state is read with `YY_START` (#l("switch (YY_START) {\t/* witchcraft */")), where v7 computed it from `lex`'s
internal tables, as its comment admits. The program text given as an
argument is read as unsigned bytes (#l("c = *lexprog++&0377;")), and so is a one-character
token (#l("<A>.\t\t{ yylval = yytext[0]&0377; RETURN(yylval); }")). The escapes in strings and classes now go through `CADD`
(#l("<str>\"\\\\\\\"\"\t{ yytext[0]='\"'; CADD; }")--#l("<chc>\"\\\\\"\"]\"\t{ yytext[0]=']'; CADD; }")), which checks the length of `cbuf`, where v7 stored them
without a check.

#lines-to(none)

#source("/usr/src/cmd/awk/main.c")

The routine `main` reads the options. The option `-f` names a file of program, `-F` the field
separator, and otherwise the first argument is the program. The rest
are the files to read. It then parses the program and, if there were
no errors, runs it. The v7 routine `logit` appended each use of `awk` to a file of its
author's, if the file exists. It now takes the time in a `long long`
(#l("long long tvec;")), the port's `time_t`, where v7 used an array of two `int`s. The
option `-i` and `msgfiles` let `awk` be driven as a server, reading the
names of the files for each run from a descriptor.

#lines-to(none)

#source("/usr/src/cmd/awk/b.c")

The file `b.c` compiles a regular expression, already parsed by the grammar
into a tree, into a deterministic automaton, by the method of
following positions that `egrep` uses. The routine `makedfa` puts `.*` in front, so
that the expression may match anywhere, and a `FINAL` node at the end, and
`penter` numbers the leaves, `cfoll` computes the follow set of each,
and `cgotofn` builds the states, each the set of positions that may be
active, with their transitions packed as pairs of a character and a
state. The routine `match` runs a string through the automaton.

The routine `penter` now stops at `MAXLIN` leaves (#l("if (line >= MAXLIN-1)")--#l("overflo();", after: "if (line >= MAXLIN-1)")), and `cclenter`, which
expands the ranges of a class, at `MAXLIN` characters (#l("if (i >= MAXLIN)", after: "while (c < (*p&0377)) {")--#l("overflo();", after: "chars[i++] = c;")), and v7
wrote past both arrays. The ranges are now compared as unsigned bytes
(#l("c = chars[i-1]&0377;")--#l("while (c < (*p&0377)) {")). The tables of symbols in `cgotofn` now have a slot for each
of the 256 bytes, and the table of transitions room for a pair for each
(#l("int fatab[2*256+1];"), #l("char symbol[256];")--#l("char ssyms[256];")). Bytes are masked before they index them (#l("k = (int) right(cp) & 0377;", after: "dprintf(\"i = %d, spinit = %d, curpos = %d\\n\", i, spinit, curpos);")--#l("symbol[c&0377] = 0;")).
The v7 code sized them for 128 characters and indexed them with `char`s that
could be negative. The check for a full table of states was one short
(#l("if (n >= NSTATES-1) {")). And the states are freed except the first (#l("if (i > 0)")--#l("xfree(state[i]);\t/* free state[i] */")), whose set
is the follow set of the first leaf, which `freetr` frees later, and v7
freed it twice.

#lines-to(none)

#source("/usr/src/cmd/awk/lib.c")

The routine `getrec` reads the next record from the input files, taking an
argument of the form `var=value` as an assignment instead of a file.
The record separator `RS` is a newline by default. An empty `RS` makes
records of paragraphs, separated by blank lines. The routine `fldbld` splits the
record into the fields `$1` to `$NF`, kept in `fldtab`, on blanks or on
the single character `FS`. It is called only when a field is used.
After a field is assigned, `recbld` rebuilds `$0` from the fields.

The routine `getrec` now checks the length of the record before each character it
stores (#l("if (rr >= record+RECSIZE-3)")--#l("\"long\", record);")), and v7 checked once the record was complete, after any
overrun. Now `recbld` stops at the end of `fldtab` and of `record`
(#l("for (i = 1; i <= *NF && i < MAXFLD; i++) {")--#l("if (r >= record+RECSIZE)")), and `fieldadr` refuses a negative field number (#l("if (n < 0 || n >= MAXFLD)")),
where v7 indexed before the array.

A field beyond `NF` is an empty string (#l("#define\tFINIT\t{0, \"\", 0.0, FLD|STR, 0}"),
#l("fldtab[j].sval = \"\";")). v7 left a null pointer there, which read as an
empty string only because location 0 of a PDP-11 program could be
read. Here nothing is mapped at 0 (#f("sys1.c")), and `$2` of a
one-field record would fault.

The routine `error` takes a variable list of arguments (#l("void", after: "errorflag = 2;")--#l("va_end(a);")), passed on to
the library's `_doprnt`, and v7 declared seven arguments, used or not, and
relied on the PDP-11's passing them all on the stack. The routine `isnumber`
decides whether a string looks like a number.

#lines-to(none)

#source("/usr/src/cmd/awk/run.c")

The file `run.c` interprets the tree. The routine `execute` walks a list of statements,
calling for each node the function which `proctab` gives for its
operator. Every such function takes the node's operands and returns
an `obj`, a cell with a type that says whether it is a value, a truth
value, or a jump for `next`, `exit`, `break`, or `continue`. Values
computed along the way live in temporary cells, which `tempfree`
releases. The routine `program` runs the `BEGIN` actions, then the patterns for
each record, then the `END` actions. It no longer frees the last
temporary a second time after its loop (#l("tempfree(x);", after: "if (isexit(x)) break;")--#l("}", after: "if (isexit(x)) break;")), and v7 freed it again, or,
with no input, freed a value it had never set.

#lines-to("obj array(node **a, int n)")

The routine `array` finds an element, creating it, in the array's own symbol
table. The routine `matchop` matches a string against a regular expression's
automaton. It now matches before it frees the temporary which holds the
string (#l("i = match((struct fa *)a[1], s);")), where v7 matched a string it had already freed. The routines `substr`
and `sindex` free their temporaries only once their strings are done
with (#l("y = gettemp();")--#l("return(y);", after: "y.optr->tval = STR;"), #l("tempfree(x);", after: "setfval(z.optr, (awkfloat) (p1 - s1 + 1));")--#l("tempfree(y);", after: "setfval(z.optr, (awkfloat) (p1 - s1 + 1));")). Now `substr` returns a copy of any length
(#l("y.optr->sval = p = tostring(s + m - 1);")--#l("tempfree(x);", after: "y.optr->tval = STR;")), where v7 built the result in 100 bytes. The routine `indirect`, which
gives the field `$n`, and `substr` convert their numbers through `ftol`
(#l("m = ftol(getfval(x.optr));"), #l("m = ftol(getfval(y.optr));"), #l("n = ftol(getfval(y.optr));")), which saturates instead of overflowing.

#lines-to("}", after: "return(z);")

The routine `format` carries out a `printf` format with the program's values. It
now grows its buffer as it writes (#l("static char *room(char **bp, int *np, char *p, int k)")--#l("}", after: "return(*bp + i);"), 340, 388, 401), where v7
wrote into a fixed `RECSIZE` bytes. It refuses a format item too long
for `fmt` before copying past it (#l("for (t=fmt; (*t++ = *s) != '\\0'; s++) {")--#l("if (*s >= 'a' && *s <= 'z' && *s != 'l')")), refuses a `*` width and a
width over 100000 (#l("for (w = 0, t = fmt; *t != '\\0'; t++)")--#l("w += t - fmt;")), whose effect on the length could not be
bounded, and passes `%c` an integer (#l("case 'o': case 'x': case 'c':")), as C requires.

#lines-to("obj arith(node **a, int n)")

The routines `arith`, `incrdecr`, and `assign` do the arithmetic. The remainder is
now `i - j*ipart(i/j)` (#l("setfval(z.optr, i-j*ipart(i/j));"), #l("setfval(x.optr, xf - yf*ipart(xf/yf));")), where v7 converted the quotient to
`long`, which overflows for large ones. The routine `cat` concatenates, `pastat`
runs a pattern and its action, and `dopa2` handles the range patterns
`p1, p2`, keeping in `pairstack` which ranges are open. The routine `aprintf` now
prints a string as an argument of `%s` (#l("printf(\"%s\", x.optr->sval);")), where v7 used it as the
format itself.

#lines-to("obj split(node **a, int nnn)")

The routine `split` splits a string into an array. It now works on a copy of the
string and builds each piece in a copy of it (#l("s = os = tostring(getsval(x.optr));")--#l("temp = tostring(s);"), #l("xfree(temp);")--#l("xfree(os);")), where
v7 built the pieces in 100 bytes and could be splitting the very value
it was replacing. The element's name has room for any `int` (#l("char *t, *temp, *os, num[12];")).
The control statements are `ifstat`, `whilestat`, `forstat`, and
`instat`, and `instat`, the `for (i in a)` loop, now returns a value
(#l("return(true);", after: "vp->tval = STR;")), as `nullproc` does (#l("obj nullproc(node **a, int n) { (void)a; (void)n; return(true); }")), where v7 fell off the end of the
function. The routine `fncn` gives the built-in functions, and `int` now uses `ipart`
(#l("u = ipart(getfval(x.optr));")). The statement `print` checks the length of the line before it adds each field
and separator (#l("if (strlen(s) + strlen(getsval(y.optr)) +")--#l("\"string %.20s ... too long to print\", s);")), where v7 checked once the line was built,
after any overrun. The routine `redirprint` writes to a file or a pipe, keeping
them open in `files`. It now skips slots that hold no file (#l("if (files[i].fname != NULL &&")).

#lines-to(none)

#source("/usr/src/cmd/awk/tran.c")

The file `tran.c` keeps the variables. A symbol table is an array of `MAXSYM`
hash chains of `cell`s, and `symtab` holds the program's variables, and
each array is a table of its own. The routine `syminit` enters the built-in
variables `FS`, `RS`, `NR`, and the rest. A cell holds a string, a
number, or both, as its `tval` says: `getfval` and `getsval` convert on
demand and remember the result, and `setfval` and `setsval` invalidate
the other form.

The routine `freesymtab` now reads each cell's successor before freeing the cell
(#l("for (cp = tp[i]; cp != NULL; cp = np) {")--#l("np = cp->nextval;")), where v7 read it from the freed cell. Now `setsval` copies the
new string before freeing the old (#l("t = tostring(s);")--#l("return(vp->sval = t);")), so that a cell can be set
from its own value. The routine `hash` adds the bytes unsigned (#l("hashval += *s++ & 0377;")).

The routine `getsval` prints a number with `%.20g` when it is an integer, else in
the format `OFMT`. The test of "integer" converted the number to
`long`, which C leaves undefined when the number is out of range. It now
goes through `ftol` (#l("if (ftol(vp->fval)==vp->fval)"), #l("long ftol(awkfloat f)")--#l("}", after: "return((long)f);")), which converts saturating, and
`ipart` (#l("awkfloat ipart(awkfloat f)")--#l("}", after: "return(i);")) takes the integer part of a number for the function
`int` without any conversion.

#lines-to(none)

#source("/usr/src/cmd/awk/awk.def")

The header `awk.def` declares what the parts share: the built-in variables, which
are pointers into their cells; the `cell` (#l("typedef struct val {\t/* general value during processing */")--#l("} cell;")), holding a name, a
string, a number, and the type bits of #l("extern cell\t*nfloc;\t\t/* NF */")--#l("#define FLD\t04\t/* FLD means don't free string space */")\; the `obj` that every
operator returns (#l("typedef struct {")--#l("} obj;")); and the `node` of the tree (#l("struct nd {")--#l("typedef struct nd node;")), whose
operands follow it in an array allocated to the right length. The macros
of #l("extern int\tpairstack[], paircnt;")--#l("#define istemp(n)\t(n.otype == OCELL && n.osub == CTEMP)") classify nodes and results.

All the functions of the parts are now declared here with their
prototypes (#l("awkfloat setfval(cell *vp, awkfloat f), getfval(cell *vp);")--#l("char\t*tostring(char *s), *tokname(int n), *cclenter(char *p);"), #l("obj\tnullproc(node **a, int n);")--#l("void\tstartreg(void), ptoken(int n);")), where v7 declared the few that did not
return `int`. And `PA2NUM`, the number of range patterns, moves here
from #f("awk/run.c") (#l("#define PA2NUM\t29")), since #f("awk/parse.c") now checks it.
The macro `yfree` takes any pointer (#l("#define yfree(p) free((char *)(p))")).

#lines-to(none)

#source("/usr/src/cmd/awk/token.c")

The file `token.c` gives the names of the tokens, for debugging output and for
the table which #f("awk/proc.c") generates. The numbers must be those
of the header the parser generator writes: `bison` numbers the tokens
from 258, where v7's `yacc` started at 257, so every entry moves up by
one (#l("{\"FATAL\", 260},")--#l("};")), and `ptoken` and `tokname` index from `FIRSTTOKEN` (#l("tok[n-FIRSTTOKEN].tnm);"),
#l("return(tok[n-FIRSTTOKEN].tnm);")), not from a number written in.

#lines-to(none)

#source("/usr/src/cmd/awk/parse.c")

The file `parse.c` builds the nodes of the tree, for the actions of the grammar.
The routines `node0` to `node4` allocate a node with that many operands. The `stat`
functions make statements and the `op` functions expressions. A value,
a variable's cell, is stored as a node whose type is `NVALUE` and whose
first operand is the cell. The routine `pa2stat` makes a range pattern and gives it
a slot in `pairstack`. It now refuses more than `PA2NUM` (#l("if (paircnt >= PA2NUM)")--#l("error(FATAL, \"too many range patterns\");")),
where v7 counted on without a check.

#lines-to(none)

#source("/usr/src/cmd/awk/proc.c")

The program `proc.c` is not part of `awk`. It is compiled and run on the build
machine, and writes `proctab.c`. There the table `proctab` gives for each token
the function that `execute` calls, and `printname` the operator's text
for debugging. Tokens with no function get `nullproc`.
The table now has the prototype of its functions (#l("printf(\"obj (*proctab[%d])(node **a, int n) = {\\n\", SIZE);")), which
#f("awk/awk.def") declares, so the generator no longer writes
declarations of them. It writes its initialisers with `=` (#l("printf(\"obj (*proctab[%d])(node **a, int n) = {\\n\", SIZE);"), #l("printf(\"char *printname[%d] = {\\n\", SIZE);")),
and an empty string where a token has no printed name (#l("printf(\"/*%s*/\\t\\\"%s\\\",\\n\",tokname(i+FIRSTTOKEN),")), where v7
printed a null pointer.

#lines-to(none)

= Part Five: Administration

== Users and Privilege <ch-users>

#source("/usr/src/cmd/su.c")

The command `su` makes the user another user, by default the super-user, after
asking for that user's password, unless there is none or the caller is
already the super-user. It is set-user-id root, so that it can call
`setgid` and `setuid` (#f("sys4.c")) for the new ids, and then runs
the user's shell. In the environment it changes the shell's prompt
`PS1` to `# `, as a reminder.

#lines-to(none)

#source("/usr/src/cmd/passwd.c")

The command `passwd` changes a password. The user must give the old one, unless
it is the super-user. The new one must mix kinds of characters or be
long, though after two refusals any is accepted. The new password is
encrypted with `crypt` and a salt of two characters taken from the
time and the process id. The command is set-user-id root, so that it can
write `/etc/passwd`: it copies the file to `/etc/ptmp`, whose existence
also serves as a lock, with the user's entry changed, and copies it
back.

The time is now taken into a `long long` (#l("long long salt;")), the port's `time_t`. And
`passwd` now removes the temporary file and exits with 0 after copying
it back (#l("unlink(temp);", after: "while((u=read(fi,buf,sizeof(buf))) > 0) write(fo,buf,u);")--#l("exit(0);")), and v7 fell into the code after, which removed it and
exited with 1, so that a successful change reported failure.

#lines-to(none)

#source("/usr/src/cmd/makekey.c")

The program `makekey` reads ten bytes, an eight-character key and a two-character
salt, and writes the thirteen characters of `crypt` (#f("gen/crypt.c"))
applied to them. It lets programs such as `crypt` (#f("cmd/crypt.c"))
use the password-hashing function without loading it, and the cost of
the hash, a large part of a second on the PDP-11, made searching for
keys slow. The buffers are now cleared first (#l("char key[8] = {0};")--#l("char salt[2] = {0};")), so that a short
input gives a defined key.

#lines-to(none)
#source("/usr/src/cmd/chmod.c")

The command `chmod` changes the modes of files, given either as an octal number or
symbolically: who (`u`, `g`, `o`, or `a`), an operation (`+`, `-`, or
`=`), and permissions, either letters or the copy of another class's
bits (`u`, `g`, `o`), with several clauses separated by commas. Without
a who, the clause applies to all classes except the bits masked by the
user's `umask`. The routine `newmode` parses the mode afresh for each file, since a
symbolic mode is relative to the file's own. The octal number is now
gathered in an `unsigned` (#l("register unsigned i;")), so that a long string of digits wraps
instead of overflowing.

#lines-to(none)

#source("/usr/src/cmd/who.c")

The command `who` lists the users logged in, from `/etc/utmp`, which `init` and `login` keep, one entry per terminal, with the user's name, the
terminal, and the time of login. With two arguments, as in `who am i`,
it prints the entry of the terminal on its standard input. The name
and terminal fields of a `utmp` are eight bytes with no null when full,
so the terminal is now compared with `strncmp` (#l("if (strncmp(utmp.ut_line, tp,")) and the name from
the password file copied with `strncpy` (#l("strncpy(utmp.ut_name, pw?pw->pw_name: \"?\",")), where v7 used `strcmp`
and `strcpy`, which ran past the fields.

#lines-to(none)

#source("/usr/src/cmd/write.c")

The command `write` copies lines typed by the user to another user's terminal,
found in `/etc/utmp`, after a heading that names the writer. A line
beginning with `!` is run as a shell command instead, and end of file
writes `EOF` and stops. The target's terminal must be writable by
others, which `mesg` controls. Opening it is given five seconds
(`timout`), since the open of a terminal can wait for a carrier. The
`utmp` fields of eight bytes are now compared and copied with their
lengths bounded (#l("strncat(histty, histtya, sizeof histty - 6);"), #l("if (strncmp(ubuf.ut_line, mytty,"), #l("strncat(histty, ubuf.ut_line,")), and the user's name printed as an argument
of `%s` (#l("printf(\"%s\", him);")), where v7 used it as a format. The buffer of a line now has
room for the null which `ex` needs after 128 characters (#l("char buf[129];")).

#lines-to(none)

#source("/usr/src/cmd/mesg.c")

The command `mesg` allows or forbids messages from `write` by setting the mode of
the user's terminal to 0622 or 0600. With no argument it reports the
current state. Its exit status is 0 when messages are allowed. It now
reports a standard error that is not a terminal (#l("if(tty == NULL || stat(tty, &sbuf) < 0) error(\"cannot stat\");")), where v7 called
`stat` with the null pointer `ttyname` returned.

#lines-to(none)

#source("/usr/src/cmd/at.c")

The command `at` arranges for commands to be run later. It reads the time, such as
`3pm` or `0815`, and a day, as a month and day of the month or a day of
the week, optionally `week` for a week later, and writes the commands,
from its input or a file, into a file in `/usr/spool/at` whose name
encodes the year, the day of the year, and the time, for `atrun`
(#f("cmd/atrun.c")) to find. Before the commands it writes a `cd` to the
current directory and the current environment, so that they run as
they would have run now. Times are kept in "grains" of hours times 100
plus minutes.

The year in the file's name is now taken modulo 100 (#l("filename(THISDAY, uyear%100, uday, utime);")): `tm_year`
counts from 1900, and from 2000 on it has three digits, which would
break the fixed format of the name that `atrun` reads. The routine `makeutime` now
stops reading digits once the time is past a day (#l("while(isdigit(*p) && val < DAY) {")), so that a long
string cannot overflow it. The routine `filename`, which adds a number to the name
to make it unique, now gives up after the hundred numbers there are
(#l("for (i=0; i < 100*53; i += 53) {")--#l("exit(1);", after: "fprintf(stderr, \"at: too many jobs queued for this time\\n\");")), and v7 searched for ever once all were taken. The time is taken
into a `long long` (#l("long long tm;")), and the variable `utime` is renamed by the
preprocessor (#l("#define\tutime\tat_utime")), since the library has a function of that name.

#lines-to(none)

#source("/usr/src/cmd/atrun.c")

The program `atrun` runs the jobs which `at` has queued, and `cron` starts it every
few minutes. It reads `/usr/spool/at`, and for each file whose time has
come it forks a child which moves the file to `past`, takes on the ids
of the file's owner, and runs the file with the shell, removing it
afterwards. The program is set-user-id root, so that it can take on any
user's ids.

The year is now taken modulo 100 (#l("nowyear = tp->tm_year%100;")), as `at` writes it. The job's
group now comes from its owner's entry in the password file (#l("if (stat(file, &stbuf) == -1 ||")--#l("setgid(pw->pw_gid);")),
where v7 used the group of the spool file. The spool directory is
writable by everyone, so its files' groups can be chosen by whoever
makes them. A user in a privileged group, such as `sys`, which may read
the memory and disk special files (#f("rootfs.proto")), could give a
job that group and have it run with it later, as anyone could who
could write such a file there.

#lines-to(none)

#source("/usr/src/cmd/newgrp.c")

The command `newgrp` changes the user's group to one named in `/etc/group` of which
the user is a member, or any to `other`. A group with a password asks
for it if the user has none. It is set-user-id root, so that it can call
`setgid`, and `done` gives the privilege up and replaces itself with a new
shell, which runs in the new group.

#lines-to(none)

#source("/usr/src/cmd/chown.c")

The command `chown` changes the owner of files, given by name or number, keeping
their group. The `chown` system call is for the super-user only
(#f("sys4.c")), so in practice only the super-user can use the command.


#lines-to(none)

#source("/usr/src/cmd/chgrp.c")

The command `chgrp` changes the group of files, keeping their owner, through the
same system call as `chown`, and so likewise only for the super-user.


#lines-to(none)

#source("/usr/src/cmd/wall.c")

The command `wall` writes a message to every logged-in user's terminal, as found
in `/etc/utmp`, forking a child for each terminal so that one which
blocks does not hold up the rest. It is meant for the super-user, whose
writes are not stopped by a terminal's mode. The message is now read
only up to the size of `mesg` (#l("while(msize < (int)sizeof mesg &&")), and the terminal's name appended
with its length bounded (#l("strncat(t, tty, sizeof utmp[0].ut_line);")), where v7 overran both.

#lines-to(none)

#source("/usr/src/cmd/kill.c")

The command `kill` sends a signal, by default `SIGTERM`, to each process named by
its id. The kernel allows it only to the processes of the same user,
or any for the super-user (#f("sys4.c")). A process id is now printed
as signed (#l("printf(\"%d: %s\\n\", pid, sys_errlist[errno]);")), as `int`s are. The program is otherwise v7's.

#lines-to(none)

#source("/usr/src/cmd/nice.c")

The command `nice` runs a command with its priority lowered, by 10 or by the
amount given. Only the super-user may give a negative amount, which
raises the priority.

#lines-to(none)

#source("/usr/src/cmd/stty.c")

The command `stty` sets the modes of the terminal on its standard output, or with
no arguments prints them. The tables `speeds` and `modes` give, for
each word it accepts, the baud rate, or the bits of `sg_flags` to set
and to clear, and `erase` and `kill` take the next argument as the
character, with `^` for a control character. The flags and their
meanings are those of the terminal driver (#f("tty.c")). The tables'
entries are now braced (#l("{\"0\",\tB0},")--#l("{0},", after: "{\"tek\", FF1, ALLDELAY},")), as C99 asks of an array of
structures.

The program now refuses `erase` and `kill` with no character after them
(#l("if (argc > 1 && eq(\"erase\")) {"), #l("if (argc > 1 && eq(\"kill\")) {")), where v7 read the null pointer that ends `argv`. The
characters are compared as unsigned (#l("if ((mode.sg_erase&0377) < ' ')"), #l("if ((mode.sg_kill&0377) < ' ')")), so that one above 127
is not shown as a control character, and a speed outside the table is
shown as 0 (#l("fprintf(stderr,\"%s%d baud\\n\", c, (unsigned)s < 16? speed[s]: 0);")), where v7 indexed past it.

#lines-to(none)

#source("/usr/src/cmd/tabs.c")

The command `tabs` sets the hardware tab stops of a terminal every eight columns,
and with them the left margin unless `-n` is given, by sending the
escape sequences of the terminal named: the DASI 300 and 450, the
Teletype 37, the GE TermiNet, and the Hewlett-Packard 2645, terminals
of v7's time. Padding characters give a slow terminal time to clear its
old stops. With no name it guesses the terminal from the modes and
speed the driver has for it (#l("default:")--#l("}", after: "tty37();")). For two of them it first turns
off the driver's delays. The terminal modes it reads are now cleared
first (#l("struct sgttyb tb = {0};"), #l("struct sgttyb t = {0};", after: "dasi450(void)"), #l("struct sgttyb t = {0};", after: "tn300(void)")), so that when the input is not a terminal and
`gtty` fails, the guess and `stty` do not use whatever the stack held.

#lines-to(none)
#source("/usr/src/cmd/tty.c")

The command `tty` prints the name of the terminal on its standard input, found by
`ttyname`, or with `-s` only sets the exit status to say whether there
is one.

#lines-to(none)

#source("/usr/src/cmd/pwd.c")

The command `pwd` prints the current directory. The system keeps no name for it,
so `pwd` climbs: it finds the current directory's entry in `..` by its
i-number, changes to `..`, and repeats until it reaches the root,
prepending each name to `name`. Where `..` is on another device, the
mounted directory's i-number says nothing about the entry in the
directory it is mounted on, so `pwd` must `stat` each entry there and
compare devices as well.

The buffer `name` now has 4096 bytes (#l("char\tname[4096];")), where v7 had 512. A directory entry's
name has no null when it is 14 characters long, so it is now copied to
`dname`, which has room for one, before `stat` or `cat` uses it (#l("char\tdname[DIRSIZ+1];"),
#l("stat(strncpy(dname, dir.d_name, DIRSIZ),"), #l("strncpy(dname, dir.d_name, DIRSIZ);")); v7 used the entry itself and ran on into whatever followed.
The test of each `read` now compares with the size of an entry
converted to `int` (#l("if (read(file, (char *)&dir,"), #l("if(read(file, (char *)&dir,")): v7 compared the `int` result with the
`unsigned` size, so that a failure, $-1$, became a large unsigned
number and passed the test.

#lines-to(none)

== Accounting and Status <ch-acct>

#source("/usr/src/cmd/ac.c")

The command `ac` adds up connect time from `/usr/adm/wtmp`, the log of logins and
logouts which `init` and `login` append to. It adds in total, per user with
`-p`, or per day with `-d`, optionally for named users only. A record
names a terminal and a user, or no user for a logout. The time between
a login on a terminal and the next record for the terminal is charged
to the user. Records whose terminal is `|` and `}` mark the old and new
times of a change of the date, by which the open sessions are shifted.
The array `tbuf` holds the state of each terminal, numbered from the last two
digits of its name, and `ubuf` the total for each user. At the end a
pseudo-record logs everyone out at the present time.

The times are now `time_t` (#l("time_t\tttime;"), #l("time_t\tdtime;")--#l("time_t\tlastime;"), #l("time_t t, t1;"), #l("time_t ttime;"), #l("time_t x;")), the port's 64
bits. When `ubuf` is full, `update` now charges further users to its
last entry (#l("for (up=ubuf; up < &ubuf[USIZE-1]; up++) {")), where v7's search ran past the end of the array.

#lines-to(none)

#source("/usr/src/cmd/sa.c")

The command `sa` summarises the process accounting file `/usr/adm/acct`, to which
the kernel appends a record for every process that exits while accounting is on (#f("acct.c")), with its command name, user, and times.
The program totals the records by command in the hash table `tab`, and by
user in `user`. It lumps commands run once, or with odd characters in
their names, into `***other`, and with `-s` saves the totals in
`/usr/adm/savacct` and `/usr/adm/usracct`, which later runs start
from (`init`), so that the large file can be truncated. The options
choose the sorting and what is printed. The routine `expand` unpacks the kernel's
compressed times: a 13-bit mantissa times 8 to the power of a 3-bit
exponent.

The routine `enter` hashes the command name, all `NC` bytes of it. The names it is
given for the merged entries are now arrays of that size (#l("char\tother[NC] = \"***other\", junk[NC] = \"**junk**\";"), #l("junkp = enter(other);"),
#l("j = enter(junk);")); v7 passed string constants of nine bytes, from which the hash
read one byte more. The hash is now computed unsigned (#l("for (h=j=0; j<NC; j++) {")--#l("h = h*7 + (np[j]&0377);")) where
v7 negated a sum that might have overflowed, and a full table now stops
`sa` with a message (#l("for (k=0, i=h%size; tab[i].name[0]; i = (i+1)%size) {")--#l("}", after: "exit(1);")) instead of a search for ever. Merging
into `***other` now skips that entry itself (#l("if(i == junkp)")--#l("continue;", after: "if(i == junkp)")), which v7 could
add to itself and then empty.

The routine `printmoney` now finds a user's name with `getpwuid` (#l("if ((pw = getpwuid(i)) == NULL)")), and v7 used
`getpw`, which copies the whole line of the password file, up to
`BUFSIZ` bytes, into the caller's buffer, here of 128. The comparison
functions for `qsort` take `char *` arguments, as its declaration
requires (#l("int", after: "tsys += x;")--#l("struct tab *p1 = (struct tab *)q1, *p2 = (struct tab *)q2;", after: "tcmp(char *q1, char *q2)")). Times are `time_t` (#l("time_t x;")).

#lines-to(none)

#source("/usr/src/cmd/pstat.c")

The command `pstat` prints the kernel's tables of in-core inodes (`-i`), texts
(`-x`), processes (`-p`), terminals (`-t`), open files (`-f`), and a
process's `user` structure given its address (`-u`). It looks up the
tables' addresses in the symbol table of `/unix` with `nlist`, and
reads them from the memory special files. It is set-group-id `sys`,
the group that may read those (#f("rootfs.proto")).

The tables are now read from `/dev/kmem` (#l("char\t*fcore\t= \"/dev/kmem\";")), by kernel address. On
the PDP-11 the kernel's data lay at the same addresses in physical
memory, so v7 read `/dev/mem`. Here the kernel runs at its own virtual
addresses. A `user` structure, found by its physical page, is still
read from `/dev/mem` (#l("char\t*fmem\t= \"/dev/mem\";"), #l("lseek(fm, ptob(ubase), 0);")--#l("read(fm, (char *)&xu, sizeof(xu));")), now converting the page number
with `ptob` where v7 shifted it by the PDP-11's 64-byte click. When the
memory is taken from a file named as an argument, `pstat` now first
gives up the group `sys` (#l("if (argc>0) {")--#l("}", after: "setgid(getgid());")), so that it cannot be used to read
any file the group may read.

The kernel's structures are taken from the kernel's own headers
(#l("#include \"../../sys/h/tty.h\"")--#l("#include \"../../sys/h/file.h\"")), since several, such as `user.h`, differ from what the library's
copies give to ordinary programs. The routine `nlist` marks a symbol it did not
find with a type of 0 (#l("if (setup[SINODE].type == 0) {"), #l("if (setup[SNDH].type == 0)")), as the port's `nlist` for ELF files
does, where v7's used $-1$. The number of terminal lines read from the
kernel is kept within the array (#l("if ((unsigned)ndh > 48)")--#l("ndh = 48;")). In `dousr`, the PDP-11's
segmentation registers give way to the sizes of the process's
segments (#l("printf(\"pdir %.1o\\n\", (unsigned)up->u_pdir);")--#l("up->u_pssize, up->u_pxrw);")), and the times, now `long long`, are printed as
such (#l("printf(\"\\ntimes %lld %lld\\n\", up->u_utime/60, up->u_stime/60);")--#l("printf(\"ctimes %lld %lld\\n\", up->u_cutime/60, up->u_cstime/60);")).

#lines-to(none)

#source("/usr/src/cmd/iostat.c")

The command `iostat` reports the kernel's instrumentation, repeatedly at an
interval if asked. At each clock tick the kernel adds one to the entry
of `dk_time` indexed by the set of disks busy and the state of the
processor, so that the 32 entries give the ticks spent in each
combination. The disk drivers count their transfers and words in
`dk_numb` and `dk_wds`, and the terminal handler its characters in
`tk_nin` and `tk_nout` (#f("clock.c"), #f("tty.c")). The command reads these from
`/dev/kmem` at the addresses `nlist` finds in `/unix`, takes the
differences from the previous reading, and prints per-second rates,
times per seek and per transfer, and the share of time in user mode,
`nice`, the system, and idle. With `-b` it prints the buffer cache's
counts from `io_info`.

The v7 program found only the address of `dk_busy` and read all the counters as one
block from there, relying on the PDP-11 kernel's placing them together
in that order, and then took the differences of 40 `long`s starting at
`etime`, running on through the structure into the counters after it.
Each counter is now looked up by its own name (#l("{\"_dk_busy\", 0, 0},")--#l("{\"\\0\\0\\0\\0\\0\\0\\0\\0\", 0, 0}")) and read from its
own address (#l("lseek(mf, (long)nl[0].value, 0);")--#l("read(mf, (char *)&s.tout, sizeof(s.tout));")), and the differences are taken counter by
counter (#l("for(i=0; i<32; i++) {")--#l("for(i=0; i<32; i++)", after: "etime = 0;")). The loader of the port's kernel promises no order.
The sums are now kept in `double` (#l("double t;", after: "double f4, f5, f6;"), #l("double t;", after: "stat1(int o)")), the times of each reading
in `long long` (#l("long long tm;")), and the table of buffers has `NBUF` entries
(#l("long\tbufcount[NBUF];"), #l("for(i=0; i<NBUF; ) {")), where v7 wrote 50 and printed 30.

#lines-to(none)

#source("/usr/src/cmd/accton.c")

The command `accton` turns process accounting on, into the file named, or off with
no argument, through the `acct` system call, which only the super-user
may make (#f("acct.c")).

#lines-to(none)

#source("/usr/src/cmd/time.c")

The command `time` runs a command and prints the real time it took and the user
and system time of its processes, which `times` reports for the
children waited for. Times are in ticks of a sixtieth of a second. The
real time, measured with `time` in seconds, is multiplied up to match.
The routine `printt` prints a number of ticks as hours, minutes, seconds, and
tenths, without leading zeros, dividing by the bases in `quant`.

#lines-to(none)

== Maintaining File Systems <ch-fsmaint>

#source("/usr/src/cmd/prof.c")

The command `prof` prints an execution profile. A program to be profiled is
compiled with `-pg` and linked with #f("csu/mcrt0.s") in place of
`crt0.o`. When it exits it leaves `mon.out`, written by `monitor` (#f("gen/mon.c")). It holds a header giving the range of addresses watched, the
call counts, and a histogram of where the program counter was found at
each clock tick. From that file and the program's symbol table `prof`
estimates the time spent in each function and the number of calls.

The v7 program read the symbol table of the PDP-11's `a.out` format. The port's
programs are ELF files, and `prof` now finds the table as `nlist`
does (#f("gen/nlist.c")): the ELF header is read into `eh` (#l("if (fread((char *)eh, sizeof eh, 1, nfile) != 1 ||")), and
the section headers are searched from the last for the symbol table,
type 2, whose offset and size go to `sa` and `n`, and whose string
table's offset to `st` (#l("n = sa = st = 0;")--#l("}", before: "if((pfile = fopen(\"mon.out\",\"r\")) == NULL) {")). A short or damaged file ends the
search rather than leaving `sh` unread.

Each 16-byte symbol is then read into `sym` (#l("for (nname = 0; n >= sizeof sym; n -= sizeof sym,")--#l("}", after: "nname++;")). Its last word
holds the type, the binding, and the section. A symbol is taken if it
names a function or nothing in particular, which is what an assembler
label is (#l("if ((sym[3]&017) > 2 || (sym[3]>>16) == 0 ||")), is global unless `-a` asks for local ones too (#l("if (aflg==0 && (sym[3]&0360) != 020)")),
and lies in a section of instructions, flag 4 (#l("fseek(nfile, eh[8] + (sym[3]>>16)*40, 0);")--#l("continue;", after: "(sh[2]&4) == 0)")). The ARM's
mapping symbols, `$a` for instructions and `$d` for data, are skipped
(#l("if (npe->name[0] == '$')")). The v7 program took only the eight characters an `a.out` name held. Names
of up to fifteen are now kept (#l("char\tname[16];"), #l("npe->name[fread(npe->name, 1, sizeof npe->name - 1,")), and the table is printed in a
column that wide (#l("printf(\"           name %%time  cumsecs  #call  ms/call\\n\");"), #l("printf(\"%15.15s%6.1f%9.2f\", np->name, 100*ftim,")). C names in ELF have no leading underscore.

The v7 program credited a call count to a function whose address lay within ten
units below the counted address, the distance from the entry of a
PDP-11 function to its call of `mcount`. The count now goes to the
function containing the address, the last whose entry is not above it,
found after the table is sorted by address (#l("qsort((char *)nl, nname, sizeof(struct nl), valcmp);")--#l("}", after: "np->ncall = cp->cncall;")). Empty slots of
the count table are passed over.

The program is otherwise v7's, made safe on any input: the header of
`mon.out` is checked as it is read (#l("if (fread((char *)&h, sizeof(struct hdr), 1, pfile) != 1 ||")--#l("}", after: "fprintf(stderr, \"mon.out: bad format\\n\");")), and the addresses, which
v7 converted by subtracting null pointers, are divided by the size of a
counting unit (#l("lowpc = (unsigned)h.lowpc/sizeof(UNIT);")--#l("highpc = (unsigned)h.highpc/sizeof(UNIT);")). The variable `ftime` is renamed `ftim` (#l("double\tftim;")),
since the library's `ftime` is declared in the headers. The plotting
code, which used a library this system lacks, is left out by
`#ifdef plot`.

#lines-to(none)
#source("/usr/src/cmd/icheck.c")

The command `icheck` checks the consistency of the blocks of a file system. It
reads every inode, and for each block an inode claims, directly or
through the indirect blocks, marks it in the bit map `bmap`, reporting
a block outside the file system as bad and one already marked as a
duplicate. It then walks the free list, checking its blocks the same
way. A block neither claimed nor free is missing. With `-b` it reports
every use of the blocks listed. With `-s` it ignores the old free list
and builds a new one from the blocks not claimed, which is the usual
repair for a damaged free list.

The free list is now followed for at most as many blocks as the file
system has (#l("while(nfree < sblock.s_fsize && (n = alloc())) {")), so that a list which loops back on itself ends, and v7
followed it for ever. The total of used blocks now adds the
triple-indirect count (#l("n = ndirect + nindir + niindir + niiindir;")), where v7 added the double-indirect count
twice and left the triple out. `-b` no longer reads past the last
argument (#l("for(i=0; i<NB && argc>1; i++) {")), and `blist` has room for the $-1$ that ends it after a
full list (#l("daddr_t\tblist[NB+1];")). The offset of a block is now computed unsigned
(#l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);", after: "bread(daddr_t bno, char *buf, int cnt)"), #l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);", after: "buf[i] = 0;")), so that it does not overflow for blocks beyond 2 GB, and
a failed read clears the bytes asked for (#l("for(i=0; i<cnt; i++)")), where v7 cleared one
block, too few for a read of the inodes and too many for the
superblock. A free-list block is read through a union that names the
structure, `fb` (#l("union {", after: "daddr_t bno;")--#l("} buf;", after: "daddr_t bno;")), since C99 has no unnamed members.

#lines-to(none)

#source("/usr/src/cmd/dcheck.c")

The command `dcheck` checks the directories of a file system against the inodes'
link counts. The first pass reads every directory and counts, in
`ecount`, the entries that name each inode. The second compares each
count with the inode's `di_nlink` and reports those that differ. An
entry naming an inode out of range is reported as bad, and with `-i`
every entry naming one of the listed inodes is reported. The counts are
kept in bytes, held at 255 once they reach it.

The routine `bmap` now refuses the first block index beyond the single indirect
block (#l("if(i >= (int)NINDIR) {")), where v7's test let one through, reading an entry past the
end of `ibuf`. The other changes are those of `icheck`: `-i` stops at the
last argument and `ilist` has room for its terminator (#l("ino_t\tilist[NB+1];"), #l("for(i=0; i<NB && argc>1; i++) {")), a
block's offset is computed unsigned (#l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);")), and a failed read clears the
bytes asked for (#l("for(i=0; i<cnt; i++)")).

#lines-to(none)

#source("/usr/src/cmd/ncheck.c")

The command `ncheck` prints the path names of inodes, by reading the file system
directly: the first pass enters every directory in the hash table
`htab`; the second records for each directory the name and parent of
every subdirectory in it; the third prints, for each entry naming one
of the inodes asked for, or any with `-a` and `-i`, its path, which
`pname` builds by following the parents up to the root. With `-s` it
lists only special files and set-id files, which is a check of
security: they are collected into `ilist` in the first pass.

`-s` now stops collecting one short of the end of `ilist` (#l("if (sflg==0 || nxfile>=NB-1)")), which
needs a zero after the last inode, and `-i` stops at the last argument
(#l("for(i=0; i<NB && argc>1; i++) {")), and v7 could fill the list with no terminator. The changes to `bmap`
and `bread` are those of `dcheck` (#l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);")--#l("if(i >= (int)NINDIR) {")).

#lines-to(none)

#source("/usr/src/cmd/df.c")

The command `df` prints the number of free blocks of each file system named, by
default the root, `/dev/root`, where v7 listed its own machine's disks.
It counts by walking the free list from the superblock as the kernel's
`alloc` would (#f("alloc.c")), without changing anything. It now stops
when the count exceeds the file system's size (#l("if(++i > sblock.s_fsize) {")--#l("}", after: "break;")), so that a free
list which loops ends, and exits with 1 after a read error (#l("exit(1);")). The
offset of a block is computed unsigned (#l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);")), as in `icheck`.

#lines-to(none)

#source("/usr/src/cmd/du.c")

The command `du` prints the number of blocks used by each directory under the
names given, and with `-a` by each file. With `-s` only the totals. It
walks the tree as `find` does, changing into each directory. A file
with several links is counted once: `ml` remembers up to `ML` such
files by device and i-number.

The search of `ml` now stops at the entries in use (#l("for(i = 0; i < linked; ++i) {")), where v7 also
looked at the next, unset one. The path now has 4096 bytes (#l("char\tpath[4096], name[4096];")), and both
a name given and one built in the walk are checked against it (#l("if(!Noarg && strlen(argv[i]) >= (int)sizeof path) {")--#l("continue;", after: "argv[i]);"),
#l("return 0;", after: "if(chdir(fname) == -1)")--#l("goto ret;", after: "fprintf(stderr, \"--name too long < %s >\\n\", np);")), where v7 had 256 bytes and no checks. An empty name no
longer makes `du` look at the byte before it (#l("if(c1 > np && *(c1-1) == '/')")).

#lines-to(none)

#source("/usr/src/cmd/mount.c")

The command `mount` mounts a file system on a directory, read-only if a third
argument is given, through the `mount` system call (#f("sys3.c")), and
records it in `/etc/mtab` by the last component of the special file's
name. With no arguments it lists the table. The table is only a record
kept for people: the kernel keeps its own, and `/etc/mtab` can disagree
with it after a crash.

#lines-to(none)

#source("/usr/src/cmd/dump.c")

The command `dump` copies a file system to tape, in full or incrementally: a dump
of level _n_ holds the files changed since the last dump of a lower
level, whose date it finds in `/etc/ddate` (`getitime`) and, with `u`,
records its own (`putitime`). It works in passes over the inodes, read
straight from the disk. Pass I marks in `nodmap` the files changed
since that date and in `dirmap` all directories. Pass II, repeated
until nothing changes, keeps only the directories which lead to a marked file. Pass III writes the directories and pass IV the files. On
the tape each file is a header record, a `spcl` with the inode and a
map of which of its blocks follow, then the blocks. The format is that
of `<dumprestor.h>`, and `restor` and `dumpdir` read it.

The options' arguments are now checked: a density of zero is refused
(#l("if(density <= 0) {")--#l("}", after: "printf(\"bad density\\n\");")), which v7 divided by later, and a tape size is held within
what a `long` can hold once multiplied (#l("if(tsize > 0x7fffffffL/(12L*10L))")--#l("tsize = 0x7fffffffL/(12L*10L);")). The defaults still
name v7's disk and tape.

#lines-to("void", lead: true, after: "}")

The routine `pass` applies a function to every inode selected by a map, and `icat` and
`indir` walk a file's blocks, through the indirect blocks, calling one
function per block and another per array of addresses. The routine `bitmap` writes
a map to tape, and `spclrec` writes a header record, with a checksum
that makes the record's words sum to `CHECKSUM`. The sum is now
unsigned (#l("register unsigned i, *ip, s;")), so that it wraps instead of overflowing. The
headers hold times as the port's 64-bit `time_t`, so its tapes are not
v7's.

#lines-to("void", after: "return(p);")

The routines `getitime` and `putitime` read and update `/etc/ddate`, which holds an
`idates` for each file system and level. The names are now compared
and copied at most `DIRSIZ` characters, and the copy ended with a null
(#l("for(i=0; i<DIRSIZ; i++) {", after: "if(i != sizeof(idbuf)) {"), #l("for(i=0; i<DIRSIZ; i++) {", after: "goto l3;"), #l("for(i=0; i<DIRSIZ; i++) {", after: "lseek(df, (long)n*sizeof(idbuf), 0);")--#l("idbuf.id_name[i] = '\\0';")), where v7 went on until it met a null. The routine `putitime`
now rewrites the entry for the same file system and level in place
(#l("n--;", after: "if(idbuf.id_incno != incno)")), and v7 counted that entry too, and so wrote the new one after it,
over the next entry or at the end of the file.

#lines-to(none)

#source("/usr/src/cmd/restor.c")

The command `restor` reads tapes written by `dump`. With `t` it prints the dates
of a dump; with `x` it extracts the files named, finding them by path
in the directories on the tape; with `r` it restores a whole dump onto
a file system, which must have been made fresh with `mkfs` for a full
dump, the incremental dumps then following in order; `R` starts at a
later volume. Restoring writes the inodes and blocks directly on the
disk, so that a file gets the same i-number it had, and directories
need not be rebuilt.

The routine `main` now refuses `f` without a tape name and `r` without a file
system (#l("if (argc-- <= 0)")--#l("goto usage;", after: "if (argc-- <= 0)"), #l("if ((command == 'r' || command == 'R') && argc <= 0)")--#l("goto usage;", after: "if ((command == 'r' || command == 'R') && argc <= 0)")), where v7 read past the arguments. The
temporary file for `x` is removed at once once opened (#l("unlink(dirfile);", after: "df = open(dirfile, 2);")), so that
it does not survive an interruption, and v7 removed it at the end.

#lines-to("void", lead: true, after: "doit('r', 1, 0);")

The routine `doit` carries out the command. The answers read from the terminal are
now read with `fgets`, limited to the buffer (#l("if (fgets(tbf, sizeof tbf, stdin) == NULL)", after: "printf(\"Mount desired tape volume: Specify volume #: \");"), #l("if (fgets(tbf, sizeof tbf, stdin) == NULL) {")), and the end of
input stops `restor` where v7 waited for ever for a newline (#l("while ((i = getchar()) != '\\n')", after: "*argv);")--#l("exit(1);", after: "*argv);")).
So it does when `readtape` asks for the next volume (#l("while ((i = getchar()) != '\\n')", after: "printf(\"Mount volume %d\\n\", volno);")--#l("exit(1);", after: "printf(\"Mount volume %d\\n\", volno);")).

#lines-to("/*")

For `x`, `pass1` reads the directories from the tape into a temporary
file, recording where each begins in `inotab`, now refusing more than
`MAXINO` of them (#l("if (ipos >= MAXINO) {")--#l("}", after: "printf(\"Too many directories\\n\");")), where v7 wrote past the table. The routine `getfile`
reads a file's blocks from the tape, calling one function for each
block present and another for each hole. The count of blocks taken from
a header is now kept within the header's map (#l("for (i = 0; i < addrblock.c_count && i < BSIZE; i++) {")). The routine `psearch` follows
a path through the directories by `search`. It now starts each
component at the component itself (#l("cp1 = cp;")), where v7 started one byte in,
so that an empty component, from a path ending in a slash, began past
the end of the name.

#lines-to("/*", after: "return(1);")

For `r`, the file system is written through a small cache of blocks.
The routine `clri` clears an inode by assigning an empty one (#l("static struct dinode zino;")--#l("*ip = zino;")), where v7
cleared it as an array of `int`s, and `itrunc` and `tloop` free a file's
blocks, and `bfree` and `alloc` keep the free list as the kernel does
(#f("alloc.c")). Now `alloc` checks that the count of free blocks is in
range before it indexes with it (#l("if(sblock.s_nfree <= 0 || sblock.s_nfree > NICFREE ||")--#l("(bno=sblock.s_free[--sblock.s_nfree]) == 0) {")), and `bfree` that it is not
negative (#l("if((unsigned)sblock.s_nfree >= NICFREE) {")). The offsets of blocks are computed unsigned (#l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);", before: "if(write(fi, b, BSIZE) != BSIZE) {"),
#l("lseek(fi, (long)((unsigned long)bno*BSIZE), 0);", before: "if (read(fi, cache[j].c_block, BSIZE) != BSIZE) {")). A free-list block is read through a union which names its
structure, `frees`, since C99 has no unnamed members.

#lines-to("/*", after: "nb = nnb;")

The routines `gethead`, `ishead`, `checktype`, `checksum`, `checkvol`, and
`readhdr` read and check the header records, and `xtrfile`, `skip`, `rstrfile`,
`rstrskip`, and `putdir` are the functions which `getfile` calls.
The routine `readbits` reads a map from the tape. A count of blocks larger than the
map is now reduced to its size (#l("if ((unsigned)i > MSIZ/(BSIZE/sizeof(short)))")--#l("i = MSIZ/(BSIZE/sizeof(short));")), where v7 read past it.

#lines-to(none)

#source("/usr/src/cmd/clri.c")

The command `clri` clears inodes, given by number, by writing zeros over them on
the special file. It is the last resort for an inode which the file
system's checks find damaged. The blocks it held must then be recovered
with `icheck -s`. Every number is checked, and its block read, before
any is cleared. The size of an inode comes from the structure (#l("#define ISIZE\t(sizeof(struct dinode))")), so
that the port's inodes of 128 bytes are cleared whole. The indices are
now `unsigned` (#l("unsigned j, k;")), as the inode number is. The program is otherwise
v7's.

#lines-to(none)

#source("/usr/src/cmd/umount.c")

The command `umount` unmounts a file system and removes it from `/etc/mtab`. When
the table is left empty, the search for its last entry now stops at the
start (#l("while (mp > mtab &&")), where v7 went on before the array. The entry is cleared
through a pointer to the whole structure (#l("for (p1 = (char *)mp;")), where v7 indexed `file`
past its end into `spec`, which C does not allow.

#lines-to(none)

#source("/usr/src/cmd/sync.c")

The command `sync` makes the system call of that name, which starts the writing of every
modified buffer, inode, and superblock to the disks (#f("sys4.c"),
#f("alloc.c")). It
is typed before the machine is stopped, and `update`, run from `rc`, does
the same every 30 seconds.

#lines-to(none)
#source("/usr/src/cmd/mknod.c")

The command `mknod` makes a special file with the given major and minor device
numbers, which only the super-user may do (#f("sys2.c")). A device number
holds each in a byte, so `number` now refuses values over 255 (#l("if(c<'0' || c>'9' || n > 255)"), #l("return(n > 255? -1: n);")),
which v7 let spill into the other byte. A failure now makes `mknod` exit
with 1 (#l("exit(1);", after: "perror(\"mknod\");"), #l("exit(1);", after: "printf(\"usage: mknod name b/c major minor\\n\");")), where v7 exited with 0 after reporting it, and with
whatever was left in a register after the usage message.

#lines-to(none)

#source("/usr/src/cmd/dd.c")

The command `dd` copies a file with the block sizes and conversions asked for. It takes input and output block sizes, records to skip on input and to seek
past on output, a count of records, and conversions between ASCII and
the EBCDIC of IBM's machines, of case, and of byte order, with `noerror`
and `sync` for reading damaged tapes. The tables `etoa`, `atoe`, and
`atoibm` (#l("char\t*op;")--#l("};", after: "0247,0250,0251,0300,0117,0320,0241,0007,")) give the character codes, now `unsigned char`, since
they hold values above 127. It reads records into `ibuf` and moves the
bytes one at a time through the conversion function into `obuf`. With
`bs` and no conversion it writes each record as read.

`BIG`, the largest argument, is now that of a 32-bit `int` (#l("#define\tBIG\t2147483647")), where
v7's was that of a 16-bit one. Errors in the arguments and in opening
the files now make `dd` exit with 1 (#l("exit(1);", after: "fprintf(stderr,\"bad arg: %s\\n\", string);")--#l("exit(1);", after: "fprintf(stderr, \"not enough memory\\n\");")), where v7 exited with 0, and
`term` passes on a status (#l("term(int sig)")--#l("}", after: "exit(sig);")), 1 after an error of reading or
writing and the signal's number after an interrupt. The routine `skip` now stops at
the end of the input (#l("if(read(ibf, ibuf, ibs) <= 0)")--#l("break;")), where v7 went on reading nothing for
the rest of the count. The option `skip` reads its way past the records,
so that skipping far into a large input takes as long as copying it.

#lines-to("int", lead: true, after: "obc = 0;")

The routine `number` reads a size, with `k`, `b`, and `w` for units of 1024, 512,
and 2 bytes, and `x` for a product. It now works in `long long` and
stops at the limit (#l("long long n;")--#l("switch(n < big? *cs++: '\\0') {")), so that an overflow is reported instead
of wrapping. A "word" is now two bytes (#l("n *= 2;")), the 16-bit word of the
tapes `dd` was made for, and v7 multiplied by `sizeof(int)`, which on the
PDP-11 was the same but on the port would be four.

#lines-to(none)

#source("/usr/src/cmd/dumpdir.c")

The command `dumpdir` lists the files on a dump tape with their i-numbers, by
reading the directories from the tape, as `restor x` does, into a
temporary file, and then walking them from the root, printing every
file the dump holds. Much of it is `restor`'s code.

The temporary file is now opened twice, once for writing and once for
reading, and removed at once (#l("df = fopen(dirfile, \"w\");")--#l("unlink(dirfile);")), so that it does not outlive the
program. The routine `printem` walks a directory and calls itself for each
subdirectory. It now remembers its place in the one reading stream and
seeks back to it after the call (#l("long pos;")--#l("mseek(pos);")), where v7 opened the file
afresh for every level and so ran out of streams in a deep tree. A path
too long for `prebuf` is now reported instead of overrunning it
(#l("if (len + DIRSIZ + 2 > (int)sizeof(prebuf)) {")--#l("}", after: "prefix, dir.d_name);")). As in `restor`, the table of directories, the count of
blocks in a header, and the size of a map are now checked (#l("goto finish;")--#l("printf(\"Too many directories\\n\");"),
#l("for (i = 0; i < addrblock.c_count && i < BSIZE; i++) {"), #l("if ((unsigned)i > MSIZ/(BSIZE/sizeof(short)))")--#l("i = MSIZ/(BSIZE/sizeof(short));")), and the end of input stops the wait for a new volume
(#l("while ((i = getchar()) != '\\n')")--#l("exit(1);", after: "if (i == EOF)")).

#lines-to(none)

#source("/usr/src/cmd/quot.c")

The command `quot` reports how many blocks each user owns on a file system, read
straight from the inodes, largest first, and `-f` adds the number of files,
`-c` instead counts files by size, and `-n` reads a list of i-numbers,
such as `ncheck` prints, and prints each file's owner before the
line. The default file system names v7's disk. The array `du` is indexed by user
id while counting and sorted for the report.

The routine `check` now puts `du` back into the order of user ids and clears the
counts before each file system (#l("for (i=0; i<NUID; i++) {", after: "printf(\"%s:\\n\", file);")--#l("overflow = 0;")): v7 counted the second file
system into a table already sorted by the first, so that its blocks
went to the wrong users and on top of the first's totals. An inode with
a negative size is now ignored (#l("if ((ip->di_mode&IFMT) == 0 || ip->di_size < 0)")), the number of blocks is computed
without first adding to the size (#l("n = ip->di_size/BSIZE + (ip->di_size%BSIZE != 0);"), #l("du[ip->di_uid].blocks += ip->di_size/BSIZE +")), which could overflow, and
a user id is checked as unsigned (#l("if (n<0 || n>=NUID)"), #l("if ((unsigned)ip->di_uid >= NUID)")). With `-n`, the copying of
the rest of a line now stops at the end of the input (#l("while (n!=EOF) {")--#l("}", after: "n = getchar();")), where
The v7 program printed the value of `EOF` as a character. The routine `qcmp` compares users
with no name as having an empty one (#l("return(strcmp(p1->name? p1->name: \"\", p2->name? p2->name: \"\"));")), where v7 passed a null
pointer to `strcmp`.

#lines-to(none)

== Building the System <ch-build>

#source("/Makefile")

The v7 system was built on itself, by a collection of shell scripts and small
makefiles, one per directory: `conf/makefile` linked the kernel from
the archives `LIB1` and `LIB2` which the `mklib` scripts of `sys` and
`dev` had made; `compall` and `mklib` compiled and archived the C
library and the mathematical library; `cmake` compiled the commands
one at a time, each by its own line of shell, and the larger commands
(`sh`, `awk`, `dc`, and the rest) had makefiles of their own. None of
these is used. The port is built on another machine, by one `make`,
from this file and the fragments it includes, #f("sys.mk") for the kernel, #f("libc/lib.mk"), #f("libm/lib.mk"), #f("cmd/cmd.mk"),
#f("games/games.mk"), and `test.mk` for the regression tests. A single `make` sees the whole graph of
dependencies, so that a changed header recompiles exactly the files
which include it, a new `libc.a` relinks exactly the programs which use
it, a parallel build gives the same result as a serial one, and a
second `make` finds nothing to do. There is no compiler on the target
system. Everything which runs there is compiled here.

The tools. `CROSS_COMPILE` is the prefix, in the manner of Linux's makefiles, of
the cross compiler for the target, a bare-metal ARM toolchain. `HOSTCC` compiles
the three programs which run during the build rather than on the target, `mkconf` (#f("mkconf.c")), `mkfs`
(#f("cmd/mkfs.c")), and the `proc` of `awk` (#f("cmd/cmd.mk")). It is the build machine's own
compiler, `cc`, and the programs it makes run there directly, so the
build needs no more than a cross compiler for the target and the
host's ordinary tools. The scanner generator `flex` takes the place of v7's `lex`.

#lines-to("W = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wstrict-prototypes \\", lead: true)

`W` is the set of warnings, shared by the target and the host programs.
Every file is compiled as strict C99 (`-std=c99 -Wpedantic`), and
`-Werror` makes every warning an error, so the build is free of
warnings or does not finish. The last three options insist on full prototypes. They forbid old-style
definitions, empty parameter lists, and an external function without a
prior declaration.

The flags for the target (`CFLAGS`). `-ffreestanding` tells the compiler
that there is no hosted C library behind the program. Among other
things it implies `-fno-builtin`, so that calls of `printf` or `strcpy`
remain calls of the port's own library rather than being replaced by
code the compiler supplies. `-nostdlib` keeps the
toolchain's own start-up file and libraries out of every link.
`-mcpu=cortex-a7 -marm` selects the processor of both machines, and the
ARM instruction set rather than Thumb.

`-mfloat-abi=hard` makes the programs compute with the floating point
unit, the VFPv4 with the Advanced SIMD extension that `-mcpu=cortex-a7`
implies, and pass `double` arguments and results in its registers. Of
the ARM's three conventions, `soft` computes with library routines in
the integer registers; `softfp` uses the unit, but passes a `double` in
a pair of integer registers, so that its code can be linked with `soft`
code; and `hard` uses the unit and its registers for both. The value `hard` is
chosen because every program on the system is built here from source,
so there is no older code to be linked with, and a value stays in the
register it was computed in, with no moves at each call and return. The
kernel computes nothing in floating point, and the compiler must not use
the unit's registers for anything else either, since they hold the
state of the current user process, and #f("sys.mk") gives the kernel
`-mfloat-abi=soft`. `ASFLAGS` names the unit, `-mfpu=neon-vfpv4`, so that
the assembler accepts the floating point instructions of #f("low.s"),
#f("mch.s"), and `setjmp` (#f("gen/setjmp.s")); it marks no calling
convention in the objects, which therefore link with code of either
kind. `-Os` optimizes for size, and v7
compiled with `cc -O`, and the text of the MP135 machine's kernel, its
code and constants, is 41,711 bytes with `-Os` against 48,850 with
`-O`, which matters on the MP135 machine, where the whole kernel must
fit in the 128 KB of SYSRAM (#f("mp135/unix.ld")).

`-Wl,-z,max-page-size=4096` is an option for the linker,
which the compiler ignores when it only compiles. It applies to the
link of every user program (#l("LINK = $(call T,LD)$(CC) $(CFLAGS) -s -o $@ $(filter %.o %.a,$^)")), never to the kernel, which is linked by
its own line in #f("sys.mk"). The linker makes a program two loadable segments, the text, with the
read-only constants, readable and executable, and the data, readable and
writable. This is the ELF
counterpart of v7's 0410 file: `exec` (#f("sys1.c")) maps the first
read-only and shares it among all the processes running the program,
each segment at its own address. The linker's default places the text
at `0x8000`, so that nothing is mapped at address 0 and a null pointer
faults. The option sets the page size the linker assumes to 4096
bytes, the ARM's. Without it the linker assumes 64 KB pages: it then
starts the text segment at address 0, so that page 0 is mapped and
holds the ELF headers, and it pads every file by up to 32 KB to keep
each segment's offset in the file congruent to its address. With it,
the headers take one page of the file, which is not loaded, and the
data begins on a page of its own above the text, so that the two can
be mapped with different permissions. `-MMD -MP` make the
compiler write, beside each object, a file of its header dependencies
(#l("-include $(patsubst %.c,%.d,$(wildcard $(OBJ:.o=.c)))")).

`HOSTCFLAGS` are the warnings alone: the host programs are compiled
as any other program of the build machine.

#lines-to("T = $(if $V,,@printf '  %-7s %s\\n' $1 $@;)", lead: true)

`T` and `Q` shorten the output. `T` prints the name of a tool and the
target in place of the whole command, and `Q` silences commands which
are only housekeeping. With `V=1` on the command line both are empty
and every command is shown. `COMPILE.c` and `COMPILE.s` are the
variables used by `make`'s built-in rules, so redefining them is enough
for every object in the tree to be compiled in place by those rules.

`LINK` links a user program from the objects and archives among its
prerequisites, in the order given there, `crt0.o` first, then the program, then
`libm.a` and `libc.a`. `-s` strips the symbol table, as
v7's `cc -s` did. The compiler's helper routines, the 64-bit division
and the conversions of `long long` to floating point, come from the C
library (#f("libc/aeabi.s")), not from the compiler's own library.

#lines-to("all: boot/unix boot/rootfs.img boot/rootfs-mp135.img", lead: true)

The default goal is `all`: the QEMU machine's kernel and the root file system
images of both machines, and, after the fragments are read (#l("all: $(KERNELS)")), the
kernels of both machines, whose names `KERNELS` only #f("sys.mk")
supplies.

`GEN` collects the generated sources, among them the `c.c` and
`unix.ld` of each machine and the output of `bison`. `.SECONDARY` keeps
`make` from deleting them as intermediate files once the objects are
made. Every object and generated file depends on the `Makefile`
itself (#l("$(OBJ) $(GEN): Makefile")), and every object on its own fragment as well, so that a
change of flags or of a rule remakes everything it could affect.

The fragments (#l("include usr/sys/sys.mk")--#l("include usr/local/test/test.mk")) build the parts of the system, the kernels (#f("sys.mk")), the two libraries, the commands, the games, and the
regression tests, whose fragment `test.mk` compiles the test programs
and makes the small file system on which the tests run the file system
checkers. The tests themselves run on the target, from
`/usr/local/test`.

#lines-to("%.c: %.y", lead: true)

The parser generator `bison` replaces v7's `yacc`. It is run as itself, not in its POSIX
mode, since the grammars use both v7's `%term` and some of `bison`'s
own declarations.

The file `boot/unix` is a copy of the QEMU machine's kernel, which `make qemu` boots. QEMU
loads the ELF file at its link address and starts it at its entry,
`_start` (#f("low.s")). The disk is the root image, on a virtio block
device (#f("virtio_blk.c")), and the console is the QEMU machine's UART
on the standard input and output. `-m 512M` gives the machine the 512 MB of
memory which #f("qemuconf") describes, and QEMU's default is 128 MB.

#lines-to("boot/qemu.img: boot/rootfs.img $S/conf/qemuconf", lead: true)

The disk which `make qemu` gives the machine is not the root image
itself but a copy of it, `boot/qemu.img`, so the image stays as `mkfs`
made it. The copy is extended to the end of the swap area, whose first
block and length `awk` reads from #f("qemuconf"), since QEMU will not
read or write a block beyond the end of the file. The swap area is
512 MB, but `cp --sparse=always` and `truncate` store nothing on the
host for the blocks never written. The copy is made again only when the
image or the configuration changes, so what one session writes on its
disk is there for the next.

#lines-to("ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup bin/diff3 \\", lead: true)

The tree is built in place, and the programs are made where they will lie in the target's file system, such as `bin/cat`, `etc/init`,
`usr/games/fortune`. The prototype file names them relative to the top
of the tree (#f("rootfs.proto")), and `mkfs` is run from there.
`ROOTFS_STATIC` lists the files of the image which are not compiled. They are the shell scripts `1`, `true`, `false`, and `nohup`, the files of
#f("rc"), #f("ttys"), #f("passwd"), and #f("group"), and data such as
the dictionary, the fortunes, `bc`'s library, and `cron`'s table. All
but the files of `etc` and the table `usr/lib/crontab` are copied from
the v7 tree (#l("$(filter-out etc/% usr/lib/crontab,$(ROOTFS_STATIC)): %: \\")). The image also holds the regression tests, in
`/usr/local/test`: the test scripts and the data files from the
repository, and the programs and the file system image which
`test.mk` makes.

Each machine has an image of its own, which differs from the other only
in `/unix`: `boot/rootfs.img` for the QEMU machine, and
`boot/rootfs-mp135.img` for the MP135 machine. Each holds only the
root file system, and the MP135 machine's swap area is the part of its
card beyond it (#f("mp135conf")). The first two lines name each
image's kernel, which `filter` picks out again from
the prerequisites (`$^`) in the recipe. The prototype names the kernel
as `boot/unix`, the copy of the QEMU machine's kernel, and `sed` puts the machine's own
kernel in its place, and passes the prototype to `mkfs` on its standard
input, which `mkfs` reads as the file `/dev/stdin`. For the QEMU
machine the substitution changes nothing.

An image is rebuilt whenever its kernel, `mkfs`, the prototype, or any
file in it changes. `V7_MKFS_TIME` gives `mkfs` the time to stamp on
every file and on the super-block: 284774400 seconds, 10 January 1979,
the date of the files on v7's own distribution tape. Two things depend
on it. Like v7's, `cron` never reads a crontab dated zero, and would
go on using the empty list it had not read. And the kernel takes its
first idea of the date from the super-block of the root file system
(`iinit`, #f("main.c")).

#lines-to("TOINT = s/^\\(typedef[[:space:]]*\\)long\\([[:space:]]*[a-z]*_t;\\)/\\1int\\2/", lead: true)

The program `mkfs` must include the port's `<sys/param.h>`, `<sys/filsys.h>`, and
the rest, but the host's `<stdio.h>`, `<stdlib.h>`, and `<fcntl.h>`.
`-Iusr/include` would also bring in v7's `<stdio.h>`. Instead a
temporary directory is made, holding copies of the six headers `mkfs`
needs, and put on the search path, and `$$$$`, which reaches the shell as
`$$`, makes its name unique, and the `trap` removes it however the
compile ends.

The copies are not exact. The program `mkfs` writes super-blocks, inodes, and free
lists as structures, which the kernel must read as the ARM lays them
out: least significant byte first, `int` and `long` four bytes,
`long long` eight bytes on an eight-byte boundary. A 64-bit host agrees in
everything but `long`, which there is eight bytes, so `sed` turns each
`typedef long` into `typedef int`, the same four bytes on every host, and
`daddr_t` and `off_t` are the types it changes. The host's own headers
also define an `off_t` and a `time_t`, and C99 forbids a second
definition of a type name, so the port's two are renamed in the
copies. The program itself keeps the host's `time_t`, which `time`
fills, and assigns it to the port's in the inodes and the super-block.
Since `mkfs` is not one of the objects whose dependencies the compiler
records, its headers and the `Makefile` are named as prerequisites
explicitly: a `mkfs` built from stale headers would write a file system
which the kernel misreads.

#lines-to("$(DIRS):", lead: true)

The directories of the image which hold built programs or copied files,
and the copying of the files from the v7 tree. The directory `etc` is left out: its
files are kept in the repository, where the image expects them. So is
`usr/lib/crontab`, v7's table without its last line (#f("cmd/cron.c")). The copy with `cp -f`
replaces a previous copy, which is read-only like its original.

#lines-to("clean:", lead: true)

The target `clean` removes everything the build has made except the copied files
and their directories. The special target `.DELETE_ON_ERROR` removes a target whose
command fails, so that a half-written image or object is never taken
for a finished one, and `mkfs` can therefore write the image in place.

The dependency files are read only for sources which still exist (#l("-include $(patsubst %.c,%.d,$(wildcard $(OBJ:.o=.c)))")).
When a file in C is replaced by one in assembler, its old `.d` file
still names the `.c` file as a prerequisite of the object, and `make`
would otherwise stop for want of a rule to make it.

#lines-to(none)
#source("/usr/sys/sys.mk")

The fragment #f("sys.mk") builds the kernels. It replaces v7's `conf/makefile` and
the two `mklib` scripts, and follows their plan. The files of `sys` are archived as `LIB1`, those of `dev` as `LIB2`, and a kernel is linked
from the machine-language files and the configuration followed by the
two archives, so that only the procedures which something calls are
taken from them. The compiler makes the objects with `-Os` and the common `CFLAGS`. The kernel sources need no
search path, since they name their headers relative to themselves, as
`"../h/param.h"`.

`LIB1_OBJ` is every C file of `sys`. The drivers which belong to one
machine only are kept out of `LIB2`, the UART and the disk of the QEMU machine (#f("pl011.c"), #f("virtio_blk.c")), and those of the MP135
machine (#f("usart.c"), #f("iwdg.c"), #f("sd.c"), #f("ddr.c"), #f("pmic.c")). The two sets
take the same v7 names, such as `klopen` and `rkstrategy`, and so could
not share one archive. Each kernel is instead linked with its own
machine's drivers (#l("$S/conf/qemu/unix: $(QEMU_DRV)"), #l("$S/conf/mp135/unix: $(MP135_DRV)")). `SYS_OBJ` names every kernel object, so that
the `Makefile` can make them all depend on itself.

In v7, `conf/makefile` had a target `allsystems`, which ran `mkconf` and
`make` once for each of six configurations and renamed each `unix`
in turn. Here `BOARDS` lists the two configurations, and each kernel is
made in a directory of its own, `conf/qemu/unix` and `conf/mp135/unix`,
so that both are built by one `make`.

#lines-to("$(SYS_OBJ): $S/sys.mk")

Every kernel object depends on #f("sys.mk") (#l("$(SYS_OBJ): $S/sys.mk")), and is compiled with
`-mfloat-abi=soft` (#l("$(SYS_OBJ): CFLAGS += -mfloat-abi=soft")), which overrides the `hard` of the common
`CFLAGS`: the compiler then uses no floating point instruction or
register in the kernel, and the registers are left to the user
processes (#f("Makefile")).

The archives are remade from scratch each time, since `ar rc` would
keep a member which had been deleted from the sources. In v7, `mklib`
named the members one by one, in a fixed order, and GNU `ar` writes an index
of the symbols, and the order no longer matters.

#lines-to("$S/conf/mkconf: $S/conf/mkconf.c", lead: true)

The configurator `mkconf` is a host program, built with the host compiler and the strict
flags. It is run in the directory which is to receive its
output, reading the configuration on its standard input, and v7's
`conf` held one `c.c` at a time, which is why `allsystems` had to
build its kernels one after the other. A pattern rule with two targets
is made by one run of its recipe, which suits `mkconf`, since it writes
`c.c` and `unix.ld` together.

The file `c.c` lies one directory deeper than v7's, but `mkconf` still writes
v7's `#include "../h/param.h"`. The search path `-I$S/conf` (#l("$S/conf/%/c.o: CPPFLAGS = -I$S/conf")) lets
`"../h/..."` be found from `conf`.

The program `mkstm32` is another host program, built the same way. It is described
below.

#lines-to("$S/conf/qemu/unix: $(QEMU_DRV)")

The link. In place of v7's
`ld -X -i l.o mch.o c.o ../sys/LIB1 ../dev/LIB2`, the compiler driver links `low.o`, `mch.o`, `c.o`, and
the machine's drivers, then the two archives, with no start-up file or
library of the toolchain's (`-nostdlib`) and with the machine's linker
script (#f("qemu/unix.ld")). `-i`, which gave the PDP-11 kernel separate
instruction and data spaces, has no meaning on the ARM, and `-X`, which
kept the local symbols, is not needed, since the GNU linker keeps them
unless told otherwise. The kernel is not stripped:
`ps`, `pstat`, and `iostat` look up the addresses of kernel variables
in the symbol table of `/unix`. The object `low.o` comes first, so that its
`_start` is the first instruction of the text, at the origin of `RAM`.

#lines-to("all: boot/unix-mp135.stm32")

The MP135 machine's boot ROM does not load an ELF file. It loads an
image with a header of its own, 512 bytes long, from the SD card or
over USB, into SYSRAM, and jumps into it. The program `objcopy` therefore turns the
kernel into the bare bytes of its loaded sections, `unix-mp135.bin`,
and `mkstm32`, a host program kept in `conf` (#f("mkstm32.c")), puts
the header in front, making `unix-mp135.stm32`, which `all` includes.

#lines-to(none)
#source("/usr/src/libc/lib.mk")

The fragment #f("libc/lib.mk") builds the C library, `libc.a`, and the start-up files
`crt0.o` (#f("csu/crt0.s")), which every program is linked with first,
and `mcrt0.o` (#f("csu/mcrt0.s")), which takes its place in a program
to be profiled. Neither is a member of the library. It replaces v7's `compall`,
a list of `cc -c -O` commands, one per source file, and `mklib`, a
single `ar` command naming every object. Here the members are simply
all the C and assembler files of the library's four directories. They
are the top, which holds `syscall.s` (#f("libc/syscall.s")) and
`memcpy.c`, `gen`, `stdio`, and `sys`, the system call stubs, one per call as in
v7 (#f("sys/read.s")). The file `memcpy.c` has no v7 original. It defines
`memcpy` and `memset`, which GCC may call, even in freestanding code,
to copy or clear a structure. As in #f("sys.mk"), the archive is
remade from nothing, and its order does not matter.

The search path puts the port's `usr/include` ahead of the toolchain's
headers, so that `<stdio.h>` and the rest are v7's, while `<stdarg.h>`,
which v7 did not have, comes from the compiler.

#lines-to(none)
#source("/usr/src/libm/lib.mk")

The fragment #f("libm/lib.mk") builds the mathematical library, `libm.a`, from every
C file of `libm`, in place of v7's `compall` and `mklib` for the same
directory. The functions are v7's, in C, and v7's own `libm` already had no
assembler. Commands are linked with it before `libc.a`
(#f("cmd/cmd.mk")), since its functions call `frexp`, `ldexp`, and
`modf` from the C library.

#lines-to(none)
#source("/usr/src/cmd/cmd.mk")

The fragment #f("cmd/cmd.mk") builds the commands. In v7 this was the work of
`cmake`, a shell script with a line for each command, giving its
compiler options and the directory in which it was installed, and of
the makefiles in the directories of the larger commands. Here the
single-file commands need no line each: every C or `yacc` file in
`cmd` is a command (#l("CMD_ONE := $(sort $(filter-out mkfs, \\")), and it is installed in `/bin` unless it is one
of those which v7's `cmake` put elsewhere. `CMD_ETC` and `CMD_USRLIB`
are those exceptions, `/etc` and `/usr/lib`. `CMD_DIRS` are the
commands of several files, each in a directory of its own.

The fragment leaves out `mkfs` (#l("CMD_ONE := $(sort $(filter-out mkfs, \\")): it is compiled for the build machine by the
`Makefile` (#f("Makefile")), and the target has no copy. In v7, `cmake`
also distinguished commands linked with `-n`, shared pure text, from
those linked with `-i`, separate instruction and data, which needed
the larger address space. Every program here is linked the same way.

#lines-to("AWK_OBJ = $(addprefix $C/awk/,awk.g.o awk.lx.o b.o main.o token.o \\", lead: true)

The objects. The objects of `awk` are listed by hand, because three of its objects come
from generated sources and one of its C files, `proc.c`, is not part of
`awk` at all. The other directories contribute all their C files.
`GEN` names the files which `bison`, `flex`, and `awk`'s `proc` write,
and `proc` itself.

#lines-to("$(CMD_OBJ): CPPFLAGS = -Iusr/include", lead: true)

Commands are compiled with v7's headers ahead of the toolchain's.

`YYSTACK_USE_ALLOCA` (#l("$C/bc.o $C/egrep.o $C/expr.o $(AWK_OBJ): \\")) is for the four parsers which `bison`
writes. With it, the parser grows its stack with the compiler's built-in
`alloca`. Without it, it calls `malloc` and `free`, and, finding no
`<stdlib.h>`, declares them itself, with types which need not agree
with those of v7's library.

#lines-to("$(CMD_BIN:%=bin/%): bin/%: $(CRT) $C/%.o $(LIBM) $(LIBC) | bin", lead: true)

The links. Each command is linked from `crt0.o`, its own object, and the
libraries, by `LINK` (#f("Makefile")). The commands of `/bin` all get
`libm.a`, which only those calling its functions take anything from, and
`graph` is one. A command's directory is an order-only prerequisite,
after the `|`: it must exist before the link, but its date, which
changes whenever a file is added to it, must not make every command in
it out of date.

#lines-to("$(AWK_OBJ): $C/awk/awk.h $C/awk/awk.def", lead: true)

Then comes `awk`. The parser generator `bison` writes the parser and, with `--defines`, the header of
token numbers (`awk.h`), as v7's `yacc -d` wrote `y.tab.h`. The `&:`
says that one run makes both. The program `proc` is run during the build:
compiled with the token numbers of `awk.h`, it writes `proctab.c`, the table of the
procedures which evaluate each kind of node. Being run here,
the host compiler compiles it, without v7's headers, with
`token.c`, whose table of token names it uses. Both include `awk.h` and
`awk.def`, and are recompiled when either changes.

The program `flex` writes the lexical analyser, and `sed` edits it on its
way out. The scanner generator `flex` marks its `yy_fatal_error` as a function which never
returns, but the function ends with a call of `exit`, which v7's headers
do not declare in that way, and the compiler rejects the combination.
The attribute is dropped. The generated file includes `<string.h>` and
`<stdlib.h>`, which v7 did not have and which would bring in the
toolchain's declarations, and `<stddef.h>` is included instead, for
`size_t`.

#lines-to(none)
#source("/usr/src/games/games.mk")

The fragment #f("games/games.mk") builds the games, each from a single C file of
`usr/src/games`, and links them with the C library into `/usr/games`.
There was no script for them in v7. Its `games` directory held only the sources.
The games use v7's headers and nothing else from the tree, and none of
them needs `libm.a`. The `chess` of v7, a directory of files partly in PDP-11 assembler, is not
among them.

#lines-to(none)
#source("/usr/sys/conf/qemu/unix.ld")

The linker script #f("qemu/unix.ld") is the one for the QEMU machine's kernel. The program `mkconf` (#f("mkconf.c")) writes it from the `ram` line of
#f("qemuconf"), in the pass which in v7 wrote `l.s`, and is used by the
link in #f("sys.mk").

The v7 kernel needed no script. Its kernel was linked with `ld -i`: instruction
and data in two separate spaces of 64 KB, each beginning at address
zero, with `l.s`, the interrupt vectors, at the bottom. The loader
defined `_etext`, `_edata`, and `_end`, and the start-up code in
`mch.s` used them to move the text to its resting place above the data
and to clear the memory from `_edata` to `_end`, before it turned on the
memory management unit. The ARM kernel is one image, linked at the
kernel address at which it runs, 0xc0000000 (@ch-intro), and loaded at
the physical address which that address maps to. There is nothing to
move.

`MEMORY` declares the one region, `RAM`: the first 64 MB of the QEMU
machine's memory, by its kernel address. The kernel takes only its start. Process
images are kept in the `core` above it (#f("qemuconf")), which the
linker is not told about.

The symbol `u` (#l("u = 0xFFE00000;")) is the per process data area, at `UBASE` (#f("param.h")): the
assignment defines the symbol which #f("user.h") declares, as v7's
`_u = 140000` did in `mch.s`. Its address lies outside `RAM`, in the
top 2 MB which `machine_init` (#f("machdep.c")) maps through `kl3u`.

The symbol `start` (#l("start = _start - 0x80000000;")) is the physical address of `_start`, and the entry point
(#l("ENTRY(start)")): QEMU loads the file itself, and begins execution at the entry
point with the MMU off, so it must be given the physical address. The
first input file is `low.o` (#f("sys.mk")), so `_start` (#f("low.s")) is
the first instruction of the image.

#lines-to("SECTIONS")

The kernel's text, read-only data, and initialised data follow one
another from the origin of `RAM`. `AT` gives each section its load
address, the kernel address less 0x80000000, which the ELF file
records as the physical address of its segment and QEMU loads it at,
0x40000000 onwards.

`__bss_start` and `__bss_end` bound the uninitialised data, and play the
part of v7's `_edata` and `_end`: `_start` clears the memory between
them, a word at a time, before it calls any C. That is done with the
memory management unit off, when the processor faults on a store to an
unaligned word, hence the `ALIGN(4)`. `*(COMMON)` would collect
tentative definitions left as common symbols, and GCC makes them only when
asked with `-fcommon`, which the port does not use, so it collects
nothing.

#lines-to(".ddrbss (NOLOAD) : ALIGN(4096) {")

`.ddrbss` holds the table `kl3u` reserved in #f("mch.s"), which must
lie on a 4 KB boundary. `NOLOAD` makes it like `.bss`: it occupies
memory but nothing in the file. It is cleared, not by `_start`, but by
`machine_init` (#f("machdep.c")), between the symbols `__ddrbss_start`
and `__ddrbss_end`. On the QEMU machine the distinction serves nothing,
and the section simply follows `.bss` in `RAM`. It exists for the MP135
machine (#f("mp135/unix.ld")), where the table lies in a memory which cannot be
written until `machine_init` has started it.

#lines-to(none)
#source("/usr/sys/conf/mp135/unix.ld")

The MP135 machine's linker script, #f("mp135/unix.ld"), comes from `mkconf`, which reads #f("mp135conf"). It differs from #f("qemu/unix.ld") in its two
regions, in the difference between kernel and physical addresses, and
in where it puts `.ddrbss` and what it puts there, and `u` and `start` are
defined in the same way.

`RAM` is the 128 KB of on-chip SYSRAM, at physical `0x2ffe0000`, in
which the kernel runs, by its kernel address 0xc01e0000.
The text, data, and `.bss` of the kernel must all fit there. The linker
reports an overflow of the region, so a kernel which has outgrown SYSRAM
fails to link rather than to boot. `TAB` is the DDR memory, at
physical `0xc0000000` and kernel address 0xc0200000, which holds the
table `kl3u` in `.ddrbss`, at its very start, and after it the tables
of the configuration, and `core` follows them (#f("mp135conf")). The first
byte of the text, at the start of SYSRAM, is `_start`. From this ELF
file the build makes the image which the boot ROM loads, with the
ROM's header in front (#f("sys.mk")).

Here the separation of `.ddrbss` from `.bss` matters. The DDR is dead
until `ddrinit` (#f("ddr.c")) has started it, so `_start`
(#f("low.s")) may clear only `.bss`, in SYSRAM, and `machine_init`
(#f("machdep.c")) clears `.ddrbss` after the DDR is running. `NOLOAD`
gives the section no contents in the file, so that nothing has to be
loaded into DDR before it is running.

The tables of the configuration, from `buf` to `cfree`
(#f("mp135/c.c")), are the uninitialised data of `c.o`. At the sizes
which #f("mp135conf") gives them they take some three quarters of a
megabyte, six times SYSRAM, so `EXCLUDE_FILE` (#l(".bss : AT(ADDR(.bss) - 0x90200000) {")) keeps them out of
`.bss`, and the pattern `*/c.o` (#l("*/c.o(.bss* COMMON)")) puts them into `.ddrbss` after
`kl3u`. Nothing in `c.o`'s uninitialised data is used before
`machine_init` has started the DDR and cleared the section: `corebase`
and `coreoff` are set only after that.

#lines-to(none)
#source("/usr/sys/conf/mkstm32.c")

The program #f("mkstm32.c") puts the boot ROM's header on the MP135 machine's
kernel (#f("sys.mk")). Like `mkconf`, it runs on the build machine,
never on the target.

The header is that of the chip's documentation, version 2 (#l("memcpy(hdr, \"STM2\", 4);")--#l("put4(hdr+132, 512 - 128);")). It holds the magic `STM2`; 64 bytes of signature, left zero, since the chip is
not set to demand one; the checksum (#l("put4(hdr+68, sum);")), the sum of the image's bytes
(#l("sum = 0;")--#l("sum += img[i];")), which the ROM recomputes; the version (#l("hdr[74] = 2;")); the image's
length (#l("put4(hdr+76, n);")); the entry point and the load address (#l("put4(hdr+80, SYSRAM);"), #l("put4(hdr+88, SYSRAM);")), both the
start of SYSRAM, `0x2ffe0000` (#l("#define\tSYSRAM\t0x2ffe0000UL")), where `_start` lies
(#f("mp135/unix.ld")); and flag bit 31 with a length of 384 (#l("put4(hdr+100, 1UL << 31);"), #l("put4(hdr+104, 512 - 128);")),
which say that an extension header follows and fills the rest of the
512 bytes: a padding header (#l("memcpy(hdr+128, \"ST\\377\\377\", 4);"), #l("put4(hdr+132, 512 - 128);")), `ST` followed by two bytes of
`0xff`, of the same length. Every other byte is zero, since `hdr` is
external and so starts out cleared.

The fields are little-endian, and `put4` (#l("static void")--#l("}", after: "p[3] = v >> 24;")) stores them a byte at
a time, so that the header does not depend on the byte order of the
build machine. An image longer than SYSRAM less the header (#l("#define\tMAXIMG\t(128*1024L - 512)")) is
refused (#l("if (n > MAXIMG) {")--#l("}", after: "argv[1]);")): `img` has room for one byte more than that, so that
`fread` shows a longer file by filling it.

#lines-to(none)
#source("/usr/src/cmd/standalone/stand.mk")

The fragment `stand.mk` builds `sdwrite` (#f("standalone/sdwrite.c")), the one
program for the MP135 machine which runs on the bare chip, without the
system. It is compiled with the cross compiler but none of the system's
headers, start-up file, or library (`-ffreestanding -nostdlib`), for
the processor in ARM state, with floating point done in software
(#l("SAFLAGS = $W -ffreestanding -nostdlib -mcpu=cortex-a7 -marm \\")--#l("-Wl,-N,--section-start=.start=0x2ffe0000,-Ttext=0x2ffe0100")). With the memory management unit off, all memory is treated as
device memory, where an unaligned access faults, so the compiler is
told not to make any (`-mno-unaligned-access`). The section `.start`
is placed at the start of SYSRAM, where the boot ROM loads an image,
so that the entry point is the first instruction, and the text follows
it (#l("-Wl,-N,--section-start=.start=0x2ffe0000,-Ttext=0x2ffe0100")), and `-N` makes text and data one writable segment, as a program
without memory management has no use for more. `-Os` keeps it small,
since the ROM loads at most 128 KB less its header.
`-fno-tree-loop-distribute-patterns` stops the compiler from replacing
the program's copying loops by calls of `memcpy`, which there is no
library to supply. The programs `objcopy` and `mkstm32` (#f("mkstm32.c")) then make
the ROM's image, as for the kernel (#l("boot/sdwrite.bin: $(STAND)/sdwrite")--#l("$(call T,MKSTM32)$S/conf/mkstm32 $< $@")).

#lines-to(none)
#source("/usr/src/cmd/standalone/sdwrite.c")

The program `sdwrite` writes an image, such as the root file system, onto the SD
card of the MP135 machine, and reads the card back to check it. The
boot ROM's USB loader loads it into SYSRAM from the build machine
(#f("dfu.py")), and it then presents itself on USB as a serial
port, of the class CDC-ACM, which takes four commands as lines of text. The command `i` reports the card's size in blocks, `w` _lba_ _n_ takes _n_ bytes and
writes them from block _lba_, `r` _lba_ _n_ sends _n_ bytes read from
there, and `x` resets the chip. The comment at the head shows the use
from a shell on the build machine. It starts the chip's independent
watchdog and feeds it at each command, so that the chip resets itself,
and the ROM is ready to load again, 33 seconds after the last one.

The registers are those of the chip's USB OTG controller, a Synopsys
design which can be either end of a USB link, and of `sd.c`
(#f("sd.c")), at their physical addresses, since there is no memory
management here. `_start` (#l("__asm__(")--#l(");")) turns on the instruction cache,
sets a stack at the top of SYSRAM, clears the uninitialised data, and
calls `main`, and `now` reads the processor's counter, which runs at
64 MHz, and `delay` waits on it.

#lines-to("/*", after: "}")

The USB side is a minimal CDC-ACM device, polled rather than driven by
interrupts. Its descriptors (#l("static const unsigned char devdesc[18] = {")--#l("static unsigned char coding[7] = { 0x00, 0xc2, 0x01, 0x00, 0, 0, 8 };")) are the data with which a
USB device describes itself to the host, in the layout the USB and CDC
specifications fix. The routine `dosetup` answers the host's control
requests. It sets the address, gives the descriptors with the bulk
endpoints' packet size set to what the bus speed allows, configures
the endpoints, and answers the class's requests for the line coding
and the control lines. On the request which sets the control lines it
reports carrier (`carrier`), for a host which waits for it. The routine `usbpoll` services a reset of the bus, the end of enumeration, packets in the
receive FIFO, and transfers completed on endpoint 0. A data packet from
the host is taken into `rxbuf` at once, so that a control packet
behind it is not held up, and the endpoint takes no more until
`usbtake` has used it.

The routine `usbsend` sends a buffer, a packet at a time as the transmit FIFO has
room, and gives up after a second if the host has stopped taking
packets. It then calls `epabort` (#l("static int", after: "* the next transfer starts clean.")--#l("}", after: "R(DIEPINT(1)) = R(DIEPINT(1));")), which sets the endpoint to
answer the host with NAK, disables it, and empties its FIFO. Without
that, the abandoned packet stayed in the FIFO and the reply to the next
command arrived behind it, as 512 bytes of stale card data.

#lines-to("/*", after: "say(buf+i);")

The routine `sdinit` brings the card up as `rkinit` does (#f("sd.c")). It sets up the pins, the clock at 400 kHz, identification, the size from the CSD, selection,
four data lines, and high speed if the card offers it. Unlike the
kernel's driver, `sdwrite` moves data by the CPU, not by DMA, through
the controller's FIFO, eight words at a time with `ldm` and `stm` while
the FIFO has room, so that the card's clock can run without the FIFO
starving. The routines `sdwrite` and `sdread` move a whole request with one
multi-block command, `CMD25` or `CMD18`, through `ring`, a buffer of
64 KB between the card and USB, each side waiting while it is empty or
full, and `sdstop` ends the command with `CMD12` and, after a write, waits
until the card has finished programming. A read sends each 16 KB as the
host takes it, and gives up if the host takes nothing for a second. The
program reading on the build machine must keep up: Linux's terminal
layer, behind the serial port, discards what it cannot hold when its
reader falls far behind, without telling either end.

#lines-to("static unsigned")

The routine `main` starts the watchdog, initialises the card and USB, and serves
commands: the routine `getln` reads a line, and `w` and `r` are refused unless
the card answered and the request is whole blocks within it.

#lines-to(none)
#source("/usr/local/mp135/dfu.py")

The script `dfu.py` runs on the build machine and loads an image made by
`mkstm32` (#f("mkstm32.c")), the kernel or `sdwrite`, into the MP135
machine through its boot ROM. Started with no bootable storage, or
reset to it, the ROM presents itself on USB as a device of the DFU
class (vendor 0x0483, product 0xdf11), with two alternate settings:
alternate 0 is the first-stage boot loader's slot, which takes up to
128 KB, and alternate 1 a virtual one whose upload reports the
_phase_, what the ROM expects next. The program needs the `pyusb`
module.

The routine `load` resets the device's USB port to bring it to a known state, and
checks that the phase is 1, a first-stage image (#l("ph = phase(d)", after: "time.sleep(0.5)")--#l("sys.exit('phase %s, not FSBL' % ph.hex())")). It then sends
the image in blocks of 1024 bytes, the transfer size the ROM declares,
each a `DNLOAD` request numbered by its block (#l("for n, i in enumerate(range(0, len(img), 1024)):")--#l("sys.exit('block %d: status %d state %d' % (n, st, state))")). After each block
`wait` polls `GETSTATUS` until the state is 5, ready for the next, or
2, idle (#l("def wait(d, what):")--#l("sys.exit('%s: stuck in state %d' % (what, state))")): state 4, busy, is not done, and a block sent while
the ROM is busy can leave it stuck in that state for good. An empty
`DNLOAD` ends the download (#l("d.ctrl_transfer(0x21, 1, 0, 0, None)")). The ROM then checks the header and
checksum. If it accepts the image the phase reads 0 (#l("ph = phase(d)", after: "st, state = wait(d, 'manifest')")--#l("sys.exit('not accepted')")), and only
then does `DETACH` (#l("d.ctrl_transfer(0x21, 0, 1000, 0, None)")) tell it to run the image. A `DETACH` sent to a
ROM which had not accepted the image left the chip with its USB off and
no watchdog running, to be revived only by its reset button. The program
refuses rather than risk that.

#lines-to(none)
#source("/usr/src/cmd/mkfs.c")

The program `mkfs` makes an empty file system, or, given a prototype file, one
already populated with directories, files, and special files. In v7 it
was an ordinary command, kept in `/etc`, which the administrator ran on
the PDP-11 against a disk partition. Here it never runs on the target:
it is compiled by the `Makefile` (#f("Makefile")) for the build
machine, where it writes the images of the root file system,
`boot/rootfs.img` and `boot/rootfs-mp135.img`, from #f("rootfs.proto"), taking the files from the
tree in which the system was built.

Since the image must be read by the ARM kernel, `mkfs` must lay out
every structure exactly as the kernel does. It does so by being compiled
from the port's own headers, copied with every `long` type made an
`int` (#f("Makefile")), so that on a 64-bit build machine
the super-block (#f("filsys.h")), the inodes (#f("ino.h")),
the free-list blocks (#f("fblk.h")), the directory entries
(#f("dir.h")), and the indirect blocks all come out with the ARM's
sizes, alignment, and byte order, without a line of conversion. The changes from v7 are therefore few, those needed to compile it as a
program of the host, those of strict C99, the packing of block
addresses, a bigger limit on the size of a file, and the loss of the
bootstrap block.

`NIPB`, `NINDIR`, and `NDIRECT` are the numbers of inodes, block
addresses, and directory entries in a block, 4, 128, and 32. `MAXFILEBLK`
(#l("#define\tMAXFILEBLK\t(LADDR+NINDIR+(NINDIR*NINDIR))")) is new: the largest number of blocks a file may have when ten are
addressed directly, 128 through the indirect block, and 128 times 128
through the double indirect block. The macro `itoo` gives the position of an inode in
its block, to go with the `itod` of #f("param.h"). Like it, it is now
for four inodes to a block, masking with 3 where v7 masked with 7.

The headers of the host's library (#l("#include <stdlib.h>")--#l("#include <time.h>")) replace v7's `<a.out.h>`,
which was needed for the bootstrap, and `<stdio.h>` too is the host's. The
headers of `<sys/...>` are the port's. The `Makefile` arranges for them
to be found without v7's `<stdio.h>`.

#lines-to("static void")

The routine `ltol3` packs `n` block addresses, each held in a `daddr_t`, into three
bytes apiece, the form they take in an inode on the disk
(#f("ino.h")). The v7 program took it from the C library. That library is not
available to a program of the host, and v7's version was in any case
written for the PDP-11, which stores the high half of a `long` first:
it copied the bytes at offsets 0, 2, and 3 of the `long`. On the ARM
those would be bits 0 to 7, 16 to 23, and 24 to 31, and bits 8 to 15
would be lost. The private version takes the bits by shifting, least
significant byte first, which is the order in which `iexpand`
(#f("iget.c")) unpacks them. It is `static`, being defined before its
one use.

#lines-to("time_t\tutime;")

The global variables. The array `buf` is a scratch block, and `fbuf` and `filsys` are
unions of a structure with a block-sized array, so that `wtfs` and
`rdfs`, which always transfer a whole block, never run off the end of
the structure. The v7 code then referred to the structure's members as though
they belonged to the union, as in `filsys.s_fsize`. Early C compilers
allowed it, since member names were global, but C99 does not. The two
`#define`s (#l("#define fbuf fbuf.fb"), #l("#define filsys filsys.fs")) turn every such use into a reference through the
member, `filsys.fs.s_fsize`, while the unions keep their v7 names: a
macro is not expanded again within its own expansion. The v7
`struct exec head`, the header of the bootstrap program, is gone with the bootstrap.

#lines-to("int", lead: true, after: "int\tgetch(void), badblk(daddr_t bno);")

Next comes `main`. The time stamped on every file and on the super-block is taken
from the environment variable `V7_MKFS_TIME` if it is set, so that the
build gives the same image every time, and every file the date of the
v7 distribution (#f("Makefile")). The variable `fsys` serves as a temporary for the
purpose before it receives its proper value.

The arguments are the file to be written and the prototype. Under
`STANDALONE`, never defined in this system, v7 could build `mkfs` as a
program for the bare machine, asking for its arguments on the console.
That code is kept but never compiled.

#lines-to("if(fin == NULL) {")

If the second argument is not a file which can be opened, it must be a
number, the size of an empty file system in blocks, with one inode for
every 25 blocks, up to the limit of 65500 inodes which a two-byte
`ino_t` allows. The casts here and below to `unsigned` make explicit
that an `int` or a `long` is compared with a value of type `size_t`,
which the `sizeof` in `NIPB` gives, as an unsigned number
(#f("fio.c")). The v7 program printed a `long` with its own
`%D`, and C99 spells it `%ld`. The doubled parentheses at #l("for(f=0; (c=proto[f]); f++) {"), and in
`getnum` at #l("for(i=0; (c=string[i]); i++) {"), are those of #f("malloc.c").

#lines-to("#ifndef STANDALONE", lead: true)

From a prototype, the first word names a bootstrap program. The v7 program copied
its text and data into block 0, which the PDP-11's boot ROMs read to
start the system. QEMU loads the kernel from its ELF file, and reads no
bootstrap from the disk. The prototype names `/dev/null`, and the file
is opened only to be closed again. The `else` and the blank
line which follow (#l("else", after: "printf(\"%s: cannot  open init\\n\", string);")) are what is left of v7's code around the
deleted lines, as is the comment, which has lost its second line.

The next two words are the size of the file system in blocks and the
number of inodes.

#lines-to("f3:")

The fields `s_m` and `s_n` describe the interleaving of the free list, three and
500 unless the command line says otherwise (see `bflist`). The i-list
is cleared, the free list built, the files made by `cfile`, and the
super-block written last, since `alloc` and `bfree` keep it up to date
as they go. In the message for a bad ratio, `s_isize - 2` is an `int`,
since `s_isize` is an `unsigned short`, and the format is corrected to
`%d`. The field `s_fsize` is a `daddr_t`, an `int` in the copied headers, and is
cast to the `long` which `%ld` expects. So is `bno` in the messages of
`rdfs` and `wtfs`.

#lines-to("void", lead: true)

The routine `cfile` makes one file, from the next entry of the prototype, and, if
the file is a directory, all the files within it, by calling itself.
The entry begins with the mode, as in `d--755`, made of the type, a `u`
for set-user-id, a `g` for set-group-id, and three octal digits. Then the
owner and the group. The file is assembled in the kernel's in-core
inode structure (#f("inode.h")), which `mkfs` uses as a convenient
container.

The array `ib` holds the numbers of the file's blocks as they are allocated, and
now has room for `MAXFILEBLK` of them, not `NINDIR`. It lies on the
stack and takes 66 KB in every level of the recursion, which on the
host is of no consequence.

#lines-to("case IFREG:", lead: true)

A regular file is copied from the named file a block at a time, each
block written as soon as it is full (`newblk`). A special file's
address field holds its major and minor device numbers. A directory
receives its entries `.` and `..`, and then one entry for each name up
to the `$` which ends it, each followed by the description of the file
to which it refers. The inode number in the entry is `ino+1`, the
number which `cfile` will give that file. The first call, with `par`
zero, makes the root, whose `..` is itself.

#lines-to("int", lead: true)

The routine `gmode` translates a character of the mode by its position in `s`. The v7 code
returned `(&m0)[i]`, taking the four arguments `m0` to `m3` to lie one
after another on the stack, as they did on the PDP-11. The ARM passes
the first four arguments of a call in registers and only the rest on
the stack, so the four are copied into an array (#l("int m[4] = {m0, m1, m2, m3};")).

#lines-to("long", lead: true)

The routines `getnum` and `getstr` read a number and a word of the prototype. A `:`
begins a comment which runs to the end of the line.

#lines-to("static void", lead: true)

The routines `rdfs` and `wtfs` read and write block `bno` of the image, through the
host's `lseek`, `read`, and `write`. Now `rdfs` is `static`: nothing
calls it before its definition, so it needs no separate declaration,
which `-Wmissing-prototypes` would demand of an external function.
Called first by `main`, `wtfs` is declared at (#l("void\tcfile(struct inode *par), getstr(void),")). Its message (#l("printf(\"write error: %ld\\n\", (long)bno);"))
had v7's `%D`, now `%ld`, which `rdfs` already used.

#lines-to("daddr_t", lead: true)

The routines `alloc` and `bfree` take blocks from the free list and return them to it
exactly as the kernel's `alloc` and `free` do (#f("alloc.c")):
the super-block holds up to `NICFREE` free blocks, and when it is
exhausted or full, the list is read from or written to the block at
hand. The routine `bfree` is `static` for the same reason as `rdfs`.

#lines-to("void", lead: true)

The routine `entry` adds a directory entry to the directory's current block and,
when the block is full, writes it with `newblk`, which allocates and
writes a block of the current file, records its number in `ib`, and
clears the buffer. The v7 program reported "indirect block full" when `ib` held
`NINDIR` numbers. The limit is now `MAXFILEBLK`, but the message is
v7's.

#lines-to("int", lead: true, after: "*aibc = 0;")

The routine `getch` reads the prototype, or, for an empty file system, the string
in `charp` which describes its root directory.

#lines-to("void", lead: true)

The routine `bflist` builds the free list, and makes inode 1, which holds the bad
blocks of the disk, and `badblk` reports none, so it is empty. The root is
therefore inode 2, as the kernel expects (`ROOTINO`, #f("param.h")).

The blocks are freed in an interleaved order: each group of `s_n`
blocks is freed in the order given by `adr`, which takes every
`s_m`-th block. Since the list is a stack, consecutive allocations then
fall `s_m` blocks apart, which on a rotating disk gave the processor
time to ask for the next block before it passed under the head. The
order is harmless on an SD card or a file. Block 0 is freed first and
so lies at the bottom of the stack, where `alloc` takes it as the sign
that no space is left.

The braces added around the inner `if` (#l("if(f < filsys.s_fsize && f >= filsys.s_isize) {")--#l("}", after: "bfree(f);")) only make explicit
that the `else` belongs to it, as it always did. Without them GCC warns
of an ambiguous `else`.

#lines-to("void", lead: true, after: "}")

The routine `iput` writes a file's inode into the i-list. If the i-list is full, it
is the prototype's fault, and an error is reported. All three times are
the time of the build.

#lines-to("switch(ip->i_mode&IFMT) {")

The block addresses. The first `LADDR` (ten) are copied into the inode.
If there are ten or more, an indirect block is allocated and written
straight from `ib`, starting at `ib[LADDR]`. A file of exactly ten
blocks thus gets an indirect block of zeros. The v7 program stopped
there: it moved the remaining numbers down to the start of `ib` and
wrote them, so no file could exceed `NINDIR` blocks, 64 KB. The kernel
itself, installed as `/unix`, and the dictionary are larger than that, so the
port adds a double indirect block (#l("if((unsigned)*aibc > LADDR+NINDIR) {")--#l("}", after: "wtfs(ip->i_un.i_addr[LADDR+1], (char *)dbl);")): it allocates as many
indirect blocks as the file needs, each written from the next 128
entries of `ib`, and writes their numbers into a block of its own,
addressed by `i_addr[11]`. This is the layout the kernel's `bmap`
(#f("subr.c")) follows. Each entry of the double indirect array `dbl`
which the file does not need is set to zero.

The block addresses of all files, and the device numbers of special
files, are then packed into the disk inode by `ltol3`. The comment at
(#l("/* fallthrough */")) tells GCC that the fall into the next case is intended, which it
would otherwise warn about.

#lines-to("int", lead: true)

The routine `badblk` says that no block is bad, and v7 left its parameter unused.

#lines-to(none)
#source("/boot/rootfs.proto")

The prototype #f("rootfs.proto") is the one from which `mkfs` (#f("cmd/mkfs.c"))
makes the root file system, the only file system of the port. The v7 system was
distributed as an image of a whole disk. A site which made a new file
system from a prototype did so on the PDP-11 itself. Here the image is
made on the build machine, every time the system is built
(#f("Makefile")).

 The first word names the program to be written
into block 0 as a bootstrap: here `/dev/null`, since QEMU loads the
kernel from its ELF file, and nothing is written for the MP135
machine's boot ROM (@ch-intro).
The second line gives the size of the file system, 32768 blocks of 512
bytes, 16 MB, and the number of inodes, 1024, one for each 16 KB, four
to a block, and `mkfs` gives the i-list blocks 2 to 257. The system's files and its tests
take some 5 MB of it. The rest is room for the users. The size is bounded by
nothing but the configuration: three-byte block addresses
(#f("ino.h")) reach 8 GB. The swap area follows on the same disk, from
block 32768 (#f("qemuconf")). Then comes the root directory, described like every other file by its mode, as `d--755`, its owner,
and its group.

#lines-to("bin\td--755 0 0")

Within a directory, each line names an entry and describes the file:
the mode, the owner and the group, and, for a regular file, the file
on the build machine from which its contents are copied, relative to
the top of the tree. A `$` ends the directory. Since `mkfs` cannot make
links, so `[`, which `test` recognizes as its own
name, is a second copy of it. `1` is one of v7's shell scripts, like
`true`, `false`, and `nohup`, and `osh` is the old shell.

Every file is owned by root but two in `/usr/adm` and the three home
directories below. A `u` in the second
place of a mode sets the set-user-id bit. It is given to the programs
which were set-user-id root in v7's distribution, because they must act as the super-user whoever runs them. They are
`login`, `mkdir`, `mv`, `newgrp`, `passwd`, `rmdir`, and `su` here, and
`atrun` in `/usr/lib`. A `g` in
the third place sets the set-group-id bit. The commands `df`, `iostat`, `ps`, and
`pstat` here, and `dmesg` in `/etc`, belong to group `sys` (2,
#f("group")) and are set-group-id, so that they may read the memory and
disk special files below, which only that group may read, and `exec` gives
the process the file's group (`getxfile`, #f("sys1.c")). The v7 system made the
special files readable by anyone instead, and these programs plain.
The commands `dmesg`, `ps`, and `pstat` also accept a core file or a namelist named
on the command line, and each gives up the group with
`setgid(getgid())` before it uses one (#f("cmd/ps.c"),
#f("cmd/dmesg.c")); otherwise any user could read `/dev/rrk0` or
`/dev/mem` through them. Nor can a user stop one of them with a signal
which dumps core and read the image, with whatever it had read from
`/dev/kmem`, in the core file: `core` (#f("sig.c")) makes no file at all
for a process whose user or group was changed by `exec`.

#lines-to("dev\td--755 0 0")

The special files. Each gives a type (`b` or `c`), and the major and
minor device numbers (#f("qemu/c.c")). The console is character device 0, `mem`, `kmem`, and `null` are minor devices 0, 1,
and 2 of device 8 (#f("mem.c")), and `tty` is device 17. The commands `ps`,
`pstat`, `iostat`, and `dmesg` read the kernel's tables through `kmem`,
and `ps` reads process images through `mem` (#f("mem.c")), and `cron` runs
`dmesg` as `daemon` (#f("cmd/cron.c")). The files `root` and `swap` are the same
block device, the one disk, since the swap area lies on it beyond the
file system, and `ps` reads `/dev/swap` for the images of processes which
are swapped out, and `df` reads the free list of `/dev/root`. The file `rrk0` is
the raw disk, character device 9 (#f("virtio_blk.c")), the same disk
read without the buffer cache, and v7's makefile made a raw node beside
every block one. All five belong to group `sys` and have mode 640, so
that besides root only the set-group-id programs above may read them,
and no one but root may write them. In v7, `/dev/makefile` made them
readable by anyone, mode 644, which let any user read every file on
the disk and every process's memory. There are no other terminals, so the
lines of `/etc/ttys` which name them are all disabled (#f("ttys")).

#lines-to("etc\td--755 0 0")

`/etc` holds the programs which v7 installed there, and its data:
#f("passwd"), #f("group"), #f("ttys"), the command file #f("rc"), and
`ddate`, an empty file in which `dump` records the dates of dumps. Two
programs are the MP135 machine's own, and work through the device registers of `/dev/mem` (#f("mem.c")). The program `wdog` feeds the chip's
independent watchdog every 10 seconds, so that the board
resets itself some 33 seconds after the system stops, and `reset` syncs the
disks and resets the board at once, through the reset controller. The
first is started by `init` (#f("cmd/init.c")), the second by hand. On the
QEMU machine the registers are not there, and the programs exit or fail.
The files `mtab` and `utmp` are not made here: `mount` writes the first when it
mounts something, and #f("rc") empties the second, creating it on the
first boot.

#lines-to("tmp\td--777 0 0")

`/tmp` may be written by anyone. Under `/usr`, `adm` holds three empty
files. The files `messages` and `msgbuf` belong to `daemon`, so that `dmesg`, run
by `cron` as `daemon` every ten minutes (#f("cmd/cron.c")), can append the
kernel's new messages to the first and keep its copy of the message
buffer in the second, and `/usr/adm` itself may be written only by root.
The file `wtmp` exists because `login` and `init` add their records to it only
if it exists; then the dictionary, the games and their fortunes, and the
programs and data of `/usr/lib`, among them `bc`'s library `lib.b` and
the table of `units`; and the spool directory of `at`, with the file in
which `atrun` keeps the time of its last run and the directory `past`
into which it moves each job while it runs. There is no `/usr/bin`.
`/usr/local/test` holds the regression tests, which are run on the system itself. They are `run.sh`, the test scripts in `cases`, each with its
expected output, and in `utils` the programs and data files which the
tests use, and `fs.img`, a small file system on which they run the file
system checkers, and `deep.img`, a chain of 40 directories, gives `dump`
and `dumpdir` a tree deeper than their tables, and `big.img` holds one file large
enough to need a double indirect block.

The home directories which #f("passwd") gives the users `dmr`, `sys`, and
`uucp` are here, the last in `/usr/lib`, owned by each user
and that user's group. The command `login` changes to the home directory and refuses a user
whose directory does not exist, so without it `dmr` could not log in, and
`sys` and `uucp` cannot log in at all (#f("passwd")), but keep the
directories v7 gave them.

#lines-to("unix\t---644 0 0 boot/unix")

`/unix` is the kernel of the machine whose image this is: `boot/unix`,
the QEMU machine's kernel, as written here, or the MP135 machine's, which the `Makefile`
puts in its place for that machine's image (#f("Makefile")). It is not
booted from here, since neither machine loads its kernel from the file
system. It is there for its symbol table, which `ps`, `pstat`, and
`iostat` read, and which must therefore be that of the running kernel.

#lines-to(none)
#source("/etc/rc")

The command file #f("rc") is the one which `init` (#f("cmd/init.c")) gives to
the shell when the system comes up, and waits for before it starts the
terminals. Its standard input, output, and error are the root
directory, opened for reading, so whatever is to be seen must be sent
to `/dev/console` explicitly, as the notice and the date are. It
removes the table of mounted file systems, since nothing is mounted
yet, and empties `/etc/utmp`, the record of who is logged in, creating
it on the first boot. It clears the temporary directories, and starts
`update` (#f("cmd/update.c")), which calls `sync` every thirty seconds,
and `cron` (#f("cmd/cron.c")). The line beginning with `:` is a comment,
which leaves accounting off.

The file is v7's, less one line: v7 mounted `/usr` from a second disk
partition, `/dev/rp3`, of which this system has none. The lines for the
printer's lock and `/usr/tmp`, which do not exist here, are kept, since
they do no harm. Since nothing here creates `/etc/mtab`, the `rm`
complains on every boot that it does not exist. The complaint is lost,
since the standard error cannot be written.

#lines-to(none)
#source("/etc/ttys")

The program `init` (#f("cmd/init.c")) reads it to
learn which terminals to serve: on each line the first character is
`1` if a `getty` is to be run on the terminal and `0` if not, the
second chooses the table with which `getty` (#f("cmd/getty.c")) begins,
and the rest is the terminal's name in `/dev`. Only the console is
enabled, with table `4`, that of v7's console DECwriter. The 32 lines
`tty00` to `tty31` name the further terminal lines of a v7
installation. They are disabled here, and since the image has no such
special files (#f("rootfs.proto")), `init` would treat them as disabled
even if they were enabled. A line may be enabled while the system runs
by editing the file and sending `init` an interrupt, `kill -2 1`.

#lines-to(none)
#source("/etc/passwd")

The file #f("passwd") is v7's, but for two passwords. Each line describes one user, in fields separated by colons. They are the login name, the encrypted password, the
user and group ids, a comment, the home directory, and the program to
run in place of the shell, `/bin/sh` if the field is empty. The command `login`
(#f("cmd/login.c")) finds a user by `getpwnam`, which reads the file
through `getpwent` (#f("stdio/getpwent.c")), and compares the
encryption by `crypt` (#f("gen/crypt.c")) of what is typed with the
second field. The user `root` keeps the password of the v7 distribution.
The `x` of `daemon` is not a value `crypt` can produce, so no one can log in
by that name or become `daemon` with `su`. The v7 file gave `sys` and `bin` no
password. Here they have `daemon`'s `x`, since group `sys` may read the
memory and disk special files (#f("rootfs.proto")), and `bin` may join
that group with `newgrp` (#f("group")), so that any user could have
read them through `su sys`. The accounts remain, and own their files.
The users `dmr` and `uucp` have no password, and `dmr` can log in, but the login
program of `uucp`, `/usr/lib/uucico`, is not in the image.

#lines-to(none)
#source("/etc/group")

Each line names a group, gives its
password (none here), its group id, and the users who may join it with
`newgrp`. The commands `ls -lg` and `find -group` read it themselves to translate
between names and numbers, and `chgrp` and `newgrp` use `getgrnam` and its
companions from the C library. The users of #f("passwd") have group ids 1 to 4, so that `root` and
`daemon` belong to `other`. There is no group 0, though most files of
the image have group id 0 (#f("rootfs.proto")), and `ls -lg` therefore
shows those files' group as a number. The memory and disk special
files, and the programs which read them, have group `sys`.

#lines-to(none)
#source("/usr/src/cmd/wdog.c")

The program `wdog` keeps the MP135 machine alive. The kernel starts the
chip's independent watchdog, IWDG2, at boot (#f("iwdg.c")), and `wdog`
feeds it every 10 seconds from a signal handler. Should the system
stop, the watchdog resets the chip some 33 seconds after the last feed.
The registers are reached through `/dev/mem` (#f("mem.c")), a word at a
time, as device registers require. The routine `get` reads one and `put` writes one.

The program detaches itself with `fork` and closes its standard files,
and only then opens `/dev/mem`. The order matters, since `init`
(#f("cmd/init.c")) starts it with no files open, and the open would
otherwise return descriptor 0 and the close would take it away. The
reload register must read back the kernel's `0xfff` (#l("if((mem = open(\"/dev/mem\", 2)) < 0 || get(IWDG+8) != 0xfff)")). On the
QEMU machine the address lies in memory, where a write would succeed
as well, so only the value read back tells that a watchdog is present. Without one, `wdog` exits. Each feed writes `0xaaaa` to the key register.
Nothing stops the watchdog once started but a reset, so killing `wdog`
makes the chip reset itself 33 seconds later.

#lines-to(none)
#source("/usr/src/cmd/reset.c")

The program `reset` writes the disks' buffers out with `sync` and resets the chip
at once, by setting the system reset bit of the reset controller,
`RCC_MP_GRSTCSETR`, through `/dev/mem`. It returns only if the write
fails.

#lines-to(none)

= Part Six: Testing

== The Test Harness <ch-harness>

The system is tested on itself. The root file system carries a suite of
regression tests in `/usr/local/test`. Each test, or _case_, is a shell script in `cases`, with the output it must produce in a file of the same
name ending in `.exp`, and, where some of the output legitimately varies
from run to run (process ids, clock ticks, times of day, kernel
addresses), a `sed` script ending in `.sed` which replaces the varying
parts with fixed words before the comparison. A case uses the ordinary
commands, and, where no command reaches what it wants to test, a small
program of its own from `utils`. The build machine boots the system
under the QEMU machine, or loads it into the MP135 machine, and types
`/usr/local/test/run.sh` at the shell's prompt. Nothing else is needed,
since the cases and their programs were placed on the file system when
it was made (#f("rootfs.proto")).

The programs fall into two groups. Some are helpers, which write a
forged file, print a field that no command shows, or start a command
in a way the shell cannot. They are described in this chapter. The
others each exercise one mechanism of the kernel, often at its edges,
and are the subject of the next.

#source("/usr/local/test/run.sh")

The script `run.sh` runs the cases named as its arguments, or, with none, every
file in `cases` whose name has no dot, that is, every case but none of
the `.exp` and `.sed` files (#l("case $# in")--#l("esac", after: "0)\tset `ls | grep -v '\\.'`")). Each case runs under `sh`, with its
standard output and standard error together, through its `.sed` if it
has one, into `cmp`, which compares it with the expected output
(#l("if test -f $n.sed")--#l("(cmp - $n.exp 2>&1; cat >/dev/null)`", after: "else\td=`sh $n 2>&1 | tee /tmp/run.out |")). Once `cmp` has found a difference it exits. The `cat` behind
it then reads the rest of the output, so that a failing case still runs
to its end and cannot overlap the next. A case passes when `cmp` prints
nothing (#l("case \"$d\" in")--#l("pass=`expr $pass + 1`;;")). The program `tee` keeps a copy of the output in
`/tmp/run.out`, and for a failing case the first 20 lines of its
difference from the expected output are shown
(#l("diff $n.exp /tmp/run.out | sed 20q")), so that a failure which
does not recur can still be diagnosed. With `tee` in the pipeline the
case still writes into a pipe, as it would without it. The exit status is not used, since the status `sh`
gives a pipeline is that of the first of its processes it reaps, which
depends on timing. The counts are kept with `expr`, as v7's shell has
no arithmetic of its own.

#lines-to(none)
#source("/usr/local/test/test.mk")

The build's fragment for the suite is `test.mk` (#f("Makefile")). Every
C file in `utils` becomes a program in `obj` (#l("TEST_BIN := $(patsubst $(TS)/utils/%.c,$(TS)/obj/%, \\")), and every other file
there, with `run.sh` and the cases, is data for the file system (#l("TEST_IMG = $(TS)/obj/fs.img $(TS)/obj/deep.img $(TS)/obj/big.img")). The
programs are compiled with `usr/sys` on the search path as well as
`usr/include` (#l("$(TEST_OBJ): CPPFLAGS = -Iusr/include -Iusr/sys")), so that a test can include the kernel's own headers,
such as `h/user.h`, to find a register in a stopped process's saved
frame. They are linked as the commands are, except `proft`, which is
compiled with `-pg` and linked with `mcrt0.o` (#f("csu/mcrt0.s")), and
not stripped, since `prof` needs its symbols (#l("PROF_BIN = $(TS)/obj/proft")--#l("$(call T,LD)$(CC) $(CFLAGS) -o $@ $(filter %.o %.a,$^)")).

The program `mkfs` makes three small file systems for the tests of the
file-system commands. They are `fs.img`, from the prototype `fs.proto`, with a
few files of known content (#l("$(TS)/obj/fs.img: $(TS)/utils/fs.proto etc/mkfs etc/passwd etc/group \\")--#l("$(call T,MKFS)V7_MKFS_TIME=284774400 etc/mkfs $@ $< >/dev/null")); `deep.img`, a chain of 40
directories (#l("$(TS)/obj/deep.img: etc/mkfs $(TS)/test.mk | $(TS)/obj")--#l("V7_MKFS_TIME=284774400 etc/mkfs $@ /dev/stdin >/dev/null", after: "for (i = 0; i <= 40; i++) print \"$$\" }' | \\")); and
`big.img`, holding a copy of the dictionary, which gives `icheck` a file
with a double indirect block (#l("$(TS)/obj/big.img: etc/mkfs usr/dict/words $(TS)/test.mk | $(TS)/obj")--#l("V7_MKFS_TIME=284774400 etc/mkfs $@ /dev/stdin >/dev/null", after: "'words ---644 0 0 usr/dict/words' '$$' | \\")). `V7_MKFS_TIME` fixes the time `mkfs` stamps on
every inode, so that the images, and the cases' outputs, are the same at
every build.

#lines-to(none)
#source("/usr/local/test/utils/argt.c")

The utility `argt` prints how many arguments it received, their total length, and
the last. The `exec` case runs it with the names in `/bin` repeated
until the list reaches the limit `NCARGS` of 5120 bytes (#f("param.h")),
and once past it, when the shell reports the list too long.

#lines-to(none)
#source("/usr/local/test/utils/ob.c")

The utility `ob` writes bytes given in octal, each optionally repeated, `n*v`, on
its standard output. The cases use it to forge damaged files, a `mon.out` with an impossible count for `prof`, a file system with a
corrupted superblock for the checkers, and an accounting record for
`sa`.

#lines-to(none)
#source("/usr/local/test/utils/pidf.c")

The utility `pidf` writes its process id into a file, then executes the command
named after it. The process keeps its id across `exec`, so a case can
start a command in the middle of a pipeline and still send it a
signal, which is how the interrupt tests reach `ed`, `sort`, and `yes`.

#lines-to(none)
#source("/usr/local/test/utils/waitf.c")

The utility `waitf` waits until each file named exists and is not
empty, which is how a case waits for `pidf` to have written its file.
It looks before it first sleeps, so a file already written costs
nothing, where the shell's loop of `test` and `sleep 1` forked twice
for each look. Between looks it sleeps a second (#l("sleep(1);")). A
busy loop would gain nothing: the clock reschedules only once a second
(#f("clock.c")), so the process being waited for could not run before
then anyway. It gives up after 30 seconds.

#lines-to(none)
#source("/usr/local/test/utils/nap.c")

The utility `nap` returns once it has been charged with three clock ticks,
about 50 ms when it runs alone, longer while others run. A case polls
with it where the condition is not a file, as `intr` does while it
waits for `ed` to answer.

#lines-to(none)
#source("/usr/local/test/utils/endblk.c")

The utility `endblk` writes a marked block at block `n` of a disk, the
last block of the swap area in the `ddend` case, and reads it back. It
seeks there directly, where `dd` would step through every block before
it. Nothing is read past that block: the QEMU machine's disk ends there,
but the MP135 machine's card goes on.

#lines-to(none)
#source("/usr/local/test/utils/rep.c")

The utility `rep` writes a string a given number of times, then an
optional tail and a newline, unless `-n` is given. The cases make most
of their long lines with it, for the buffer limits they test, and `awk`,
which made them before, took a tenth of a second to start each time.

#lines-to(none)
#source("/usr/local/test/utils/settime.c")

The utility `settime` sets a file's access and modification times to a
given number of seconds ago with `utime`. A case uses it to order files
by time without sleeping between making them, since times count whole
seconds. It also gives `find -newer` a reference which is certainly
older than the case's files. The image's own files will not do, since
`mkfs` stamps them all with one time and the clock starts there at
boot, so a case run in the first seconds makes files in the same
second.

#lines-to(none)
#source("/usr/local/test/utils/fmode.c")

The utility `fmode` prints a file's permission bits in octal, so that a case can
save the mode of the console before changing it, and restore it after.

#lines-to(none)
#source("/usr/local/test/utils/spd.c")

The utility `spd` sets the speed of the terminal on its standard output by `gtty`
and `stty`, so that `stty`'s report of a speed can be checked.

#lines-to(none)
#source("/usr/local/test/utils/ut.c")

The utility `ut` sets a file's access and modification times by `utime`, from two
numbers given in seconds, and prints the modification time with
`ctime`. The `r5f` case gives it times in 2100 and 2400, beyond what a
32-bit `time_t` could hold, to check that the 64-bit times pass through
the system call, the inode, and the library's calendar unharmed.

#lines-to(none)
#source("/usr/local/test/utils/cpt.c")

The utility `cpt` reads the header which `find -cpio` writes and prints the file's
name and time. The modification time is kept in four 16-bit halves,
most significant first (#l("unsigned short\th_mtime[4];"), #l("u = 0;")--#l("t = u;")), the port's widening of the two
halves of v7's format, so that a time after 2106 survives.

#lines-to(none)
#source("/usr/local/test/utils/dit.c")

The utility `dit` reads, and with a third argument rewrites, the times of one inode
in a file-system image, found as the kernel finds it, by `itod` and
`itoo` (#f("param.h")). A test image cannot be mounted, there being no
way to treat a file as a disk, so `time64` plants a time after 2038 in
one with `dit`, dumps the image, and restores it to see the time come
back.

#lines-to(none)
#source("/usr/local/test/utils/tt.c")

The utility `tt` checks the library's corners and prints `PASS` or `FAIL` for each. It tries `sscanf` with characters above 127, an unterminated `%[`, a number of
150 digits, and every conversion (#l("n = sscanf(\"\\351abc def\", \"%s %s\", buf, b2);")--#l("ck(\"o x F\", n == 3 && x == 15 && y == 255 && d == 150.0);")); `malloc` refusing sizes it
cannot meet and reusing freed space (#l("ck(\"malloc huge\",")--#l("ck(\"malloc reuse\", q != 0);")); `atof` at the extremes of
the exponent (#l("ck(\"atof huge\", atof(\"1e99999999999\") > 1e308);")--#l("atof(\"1.5e3\") == 1500 && atof(\"-2.25\") == -2.25);")); `modf` and `frexp`, including a denormal number
(#l("d = modf(-3.75, &ip);")--#l("ck(\"frexp denormal\", x == -1029 && d >= 0.5 && d < 1);")); `swab` in place (#l("strcpy(sw, \"abcdef\");")--#l("ck(\"swab\", strcmp(buf, \"2143\") == 0);")); and `rand`'s sequence (#l("srand(1);")--#l("printf(\"rand %d %d %d\\n\", x, y, rand());")). It
ends by calling itself through `execvp` with a `PATH` whose first
directory is 300 characters long (#l("strcpy(path, \"PATH=\");")--#l("execvp(\"tt\", av);")), which `execvp` must skip.

#lines-to(none)
#source("/usr/local/test/utils/k12.c")

The utility `k12` checks three things from the mathematics library and its neighbours. It checks that `mktemp` puts the process id into the name, that `pow`
raises a negative number to an integral power and reports `EDOM` for a
fractional one, and that a NaN, made from infinity minus infinity,
compares unequal to itself and passes through `sin` and `exp`.

#lines-to(none)

== Probing the Kernel <ch-probe>

The programs of this chapter each exercise one part of the kernel, as
a user program sees it, usually at its edges: what `exec` refuses, what
a fault leaves in the registers, which addresses a system call may
touch. Several were written to pin down a bug, and stay to keep it
fixed.

#source("/usr/local/test/utils/forkt.c")

The system call `fork` returns in two processes from one system call. The kernel
resumes the child at the instruction after `svc`, and the parent one
instruction later (#f("sys1.c")), each with the other's process id in
`r0`. The routine `sfork` (#l("__asm__(")--#l("\"\t.ltorg\\n\");")) makes the call directly: the child takes the
branch after `svc` to `1:` and records what it received in `rawchild`.
The parent skips the branch and records `rawpar`. The routine `main` checks that
the child received its parent's id and the parent a new, larger one
(#l("me = getpid();")--#l("(st>>8) == 3 ? \"yes\" : \"no\", rawpar > me ? \"yes\" : \"no\");")), then repeats the check through the library's `fork`, which
leaves the parent's id in `par_uid` (#f("sys/fork.s")).

#lines-to(none)
#source("/usr/local/test/utils/regs.c")

A process starts life after `exec` with its registers cleared, so that
nothing of the old program leaks into the new. The utility `regs` checks this. Its
child asks to be traced and executes the program again from `xexec`
(#l("\"xexec:\\n\"")--#l("\"\tsvc #0\\n\"", after: "\"\tmov r7, #1\\n\"")), which first loads every register with a recognisable pattern.
The `exec` stops the traced child, and the parent reads the saved
registers of its frame through `ptrace`, finding the frame by the
pointer `u_ar0` in the child's `user` structure (#l("off = (int)&((struct user *)0)->u_ar0;")--#l("off = ar0 - UBASE;")), and prints any
that is not zero. The stack pointer, which `exec` sets, is passed over
(#l("for (i = 0; i < PC; i++) {")--#l("}", after: "printf(\"r%d = %x\\n\", i, r);")). A request `ptrace` does not know fails with `EIO` (#l("errno = 0;")--#l("printf(\"ptrace 9: %d errno %d\\n\", r, errno);")).

#lines-to(none)
#source("/usr/local/test/utils/ptt.c")

The utility `ptt` exercises `ptrace`'s reading and writing. The child stops itself
with a signal. The parent reads a word of its data (#l("printf(\"glob %d\\n\", ptrace(2, pid, &glob, 0));")), writes $-1$
there and reads it back with `errno` set beforehand, which the stub
must clear (#l("ptrace(5, pid, &glob, -1);")--#l("printf(\"neg %d errno %d\\n\", r, errno);"), #f("sys/ptrace.s")), and reads `r0` and `pc` from
the saved frame (#l("r = ptrace(3, pid, (int *)(off + R0*4), 0);"), #l("printf(\"r0 %d pcok %d\\n\", r,")). It may write `r0` (#l("printf(\"w %d\\n\", ptrace(6, pid, (int *)(off + R0*4), 40));")) but not `r9` (#l("printf(\"wr9 %d\\n\", ptrace(6, pid, (int *)(off + 9*4), 1));")):
only `r0`--`r5`, the stack pointer, the program counter, the processor
status, and the floating point registers are writable
(#f("sig.c")). A status written with every bit set comes back with the
mode forced to user and the privileged bits cleared (#l("ptrace(6, pid, (int *)(off + PSR*4), -1);")--#l("printf(\"rps %x\\n\", ptrace(3, pid, (int *)(off + PSR*4), 0));", after: "printf(\"wps %d\\n\", ptrace(6, pid, (int *)(off + PSR*4), 0x1df));")). The child
then resumes with the 40 written into its `r0` and a `glob` of 2, and
exits with their sum, 42.

#lines-to(none)
#source("/usr/local/test/utils/ptw.c")

A traced process's text can be written, for a debugger's breakpoints,
although text is otherwise read-only and shared. The utility `ptw` runs a copy of
itself under trace, so that its text is shared with no one else, and
stops it in `main`. It reads the first word of `f`, `mov r0, #1`, and
replaces the function with `mov r0, #2; bx lr` (#l("printf(\"before %x\\n\", ptrace(1, pid, fa, 0));")--#l("printf(\"after %x\\n\", ptrace(1, pid, fa, 0));")). The child has
already called `f` once, so it exits with 10 × 1 + 2, which shows both
that the write took effect and that the instruction cache was made to
see it (#f("sig.c")).

#lines-to(none)
#source("/usr/local/test/utils/r12.c")

The utility `r12` checks that a fault preserves every register of the interrupted
program, including `r12`, which the entries in #f("low.s") once
clobbered before saving it. An undefined instruction and a load from an
unmapped address are each executed with a known value in `r12`
(#l("__asm__ volatile(\"mov r12, %1\\n\\t.word 0xe7f000f0\\n\\t\"")--#l(": \"=r\"(out) : \"r\"(0x1234a5a5) : \"r0\", \"r12\");")). The handlers, written in assembly so as not to disturb it,
record the signal, and for the load step the saved `pc` past the
faulting instruction (#l("\"skip:\\n\"")--#l("\"\tbx lr\\n\"", after: "\"\tstr r1, [sp, #60]\\n\"")), at its place in the signal frame. The
value printed afterwards must be the one loaded.

#lines-to(none)
#source("/usr/local/test/utils/r5h.c")

User programs may be compiled to the ARM's 16-bit Thumb instructions,
and the kernel must then resume them correctly. The routine `tsig` (#l("\"tsig:\\n\"")--#l("\"\tpop {r4, r7, pc}\\n\"")) makes
the `kill` system call from inside an `IT` block, Thumb's way of making
instructions conditional: when the kernel returns, the block's state
must carry on, so that the `movne` after `svceq` is skipped and the
result is 0. The routine `tudf` (#l("\"tudf:\\n\"")--#l("\"\tbx lr\\n\"")) executes Thumb's undefined instructions of
both widths, each of which must raise `SIGILL` and be stepped over.
A 64-bit division, done by a library routine, runs while alarms
interrupt it (#l("signal(SIGALRM, tick);")--#l("printf(\"ldiv: hits %d\\n\", hits);")). With arguments, `r5h` gives `utime` an invalid
address and checks, by a `stat` from a child, that the failure did not
leave the file's inode locked (#l("if (argc > 2) {")--#l("return 0;", after: "wait(&st) < 0 ? \"inode locked\" : \"stat done\");")).

#lines-to(none)
#source("/usr/local/test/utils/r5i.c")

The routine `tsig4` (#l("\"tsig4:\\n\"")--#l("\"\tpop {r4, r7, pc}\\n\"")) is `tsig` with a four-instruction `IT` block, whose
condition changes after the `svc`. Only the `addeq` must take effect.
The rest of the program checks the library's `sscanf` with numbers too
large for their type, and `printf`'s zero precisions (#l("sscanf(\"99999999999999999999\", \"%lld\", &ll);")--#l("\"abc\", 1, \"abc\", 1.25);")). With
arguments it reports how many executables map page 0, that is, have a
first loadable segment beginning below 4096 (#l("static int")--#l("}", after: "return r;")). The programs are
linked at 0x8000 (#f("Makefile")), so that in every one a null pointer
faults.

#lines-to(none)
#source("/usr/local/test/utils/r5t.c")

The call `phys`, v7's way of mapping physical memory into a process, is a
PDP-11 facility which the port refuses with `EINVAL` (#l("errno = 0;", after: "int i, bad, r;")--#l("printf(\"phys: %d errno %d\\n\", r, errno);"),
`nosys`, #f("sysent.c")). The routine `malloc` must return blocks aligned to 8 bytes, as
the ARM's `double`s require, whatever sizes are asked for and freed
(#l("bad = 0;")--#l("printf(\"malloc: %d of 64 blocks misaligned\\n\", bad);")). Signal 16, the highest, is delivered, and 17 is refused
(#l("signal(16, catch);")--#l("printf(\"signal 17: %d errno %d\\n\", r, errno);")), since `NSIG` is 17 (#f("param.h")).

#lines-to(none)
#source("/usr/local/test/utils/elft.c")

The utility `elft` reads an executable, `/bin/echo` in the `exec` case, and writes
six damaged copies of it, each of which `exec` must refuse with
`ENOEXEC` while the process goes on (#l("static void")--#l("}", after: "unlink(name);")). The routine `phdr` finds the program
headers of the two loadable segments (#l("static unsigned *")--#l("}", after: "return (unsigned *)&buf[off];")). The copies are the ELF
header alone, with no segments (#l("try(\"short\", 52);")); a data segment whose size in the
file exceeds its size in memory (#l("save = d[4];")--#l("d[4] = save;")); a wrong magic number
(#l("buf[1] = 'X';")--#l("buf[1] = 'E';")); program header entries smaller than the fields the
kernel reads (#l("*(short *)&buf[42] = 16;")--#l("*(short *)&buf[42] = 32;")); a third loadable segment, a copy of
the data's header added to the table (#l("p = (unsigned *)&buf[*(unsigned *)&buf[28] + 32 * *(short *)&buf[44]];")--#l("*(short *)&buf[44] -= 1;")); and a text segment with
nothing in the file (#l("t[2] = 4096;")--#l("try(\"notext\", len);")). These are `getxfile`'s checks
(#f("sys1.c")). Last, a child stores through a null pointer
(#l("*(volatile int *)0 = 1;")). Nothing is mapped at address 0, so the
child dies of `SIGSEG` and leaves a core image, status 139.

#lines-to(none)
#source("/usr/local/test/utils/bigm.c")

The utility `bigm` makes a process large in each of the three ways the kernel lets
it grow. A 3 MB array on the stack grows the stack by faults, page by
page (#l("static int")--#l("}", after: "return s;")); 8 MB of uninitialised data come with the image, and their
end lies above 8 MB (#l("for (i = 0; i < sizeof(big); i += 4096)", after: "printf(\"stack pages %d\\n\", stk());")--#l("(unsigned)&big[sizeof(big)-1] >= 8*1024*1024);")); `sbrk` adds 16 MB to the data (#l("p = sbrk(16*1024*1024);")--#l("printf(\"sbrk pages %d\\n\", s);")).
Every page is written and read back. A further `sbrk` of 1 GB must
fail, since it asks for more than the memory (#l("printf(\"beyond memory %d\\n\", sbrk(1024*1024*1024) == (char *)-1);")).

#lines-to(none)
#source("/usr/local/test/utils/stkt.c")

The utility `stkt` recurses 400 levels deep with 1000 bytes of stack at each, and
sends itself a signal at every level (#l("int", after: "signal(sig, catch);")--#l("}", after: "return f(n - 1) + buf[n % 1000];")), so that signals are
delivered while the stack is being extended, onto the new pages. The
sum of the buffers and the count of 401 signals must come out right.

#lines-to(none)
#source("/usr/local/test/utils/memt.c")

A system call given an address the process does not own fails with
`EFAULT` rather than touching it. The utility `memt` passes `read` and `write` an
address in the gap between data and stack, and one in the kernel's
space (#l("fd = open(\"/etc/passwd\", 0);")--#l("printf(\"write gap: %d errno %d\\n\", r, errno);")), then valid buffers on the stack and in the data
(#l("r = read(fd, local, 16);")--#l("printf(\"read data: %d\\n\", r);")). With an argument it stores into the gap itself, and dies of
a memory fault, leaving a core image (#l("if (argc > 1)"), #l("*(int *)0x80000 = 1;")).

#lines-to(none)
#source("/usr/local/test/utils/clock.c")

The utility `clock` prints the time in seconds or, given a time, sets it with
`stime`. Given two, it sets the clock forward by their difference
(#l("sscanf(argv[1], \"%lld\", &t);")--#l("return stime(&t) < 0;")). Cases that move the date far into the future, to 2038 and
beyond, use it to note the time first and to put it back after.

#lines-to(none)
#source("/usr/local/test/utils/prt.c")

The utility `prt` profiles itself with `profil` (#f("sys4.c")) until it has used a
tenth of a second of processor time, with a histogram of 4096 counters
and a scale of a half from the page of `main`, where its text begins,
and prints the number of ticks counted (#l("profil((short *)buf, sizeof buf, (int)main & ~0xfff, 0x8000);")--#l("printf(\"ticks %d\\n\", n);")). The case's `.sed`
replaces the number, which varies, but the line shows that the clock
reached `addupc` (#f("clock.c")).

#lines-to(none)
#source("/usr/local/test/utils/prs.c")

The utility `prs` profiles itself while it spends its time in system calls, then
reports the ticks counted and its user and system times from `times`
(#l("profil((short *)buf, sizeof buf, (int)main & ~0xfff, 0x8000);")--#l("(long)tb.tms_stime);")). A tick taken in the kernel is charged as system time and does
not reach the histogram, since `clock` profiles only a program counter
interrupted in user mode.

#lines-to(none)
#source("/usr/local/test/utils/proft.c")

The profiled program of the `prof` case is `proft`. It calls `tick` a
thousand times through a pointer, which the compiler cannot inline
away (#l("for (i = 0; i < 1000; i++)", after: "main(void)"), #l("(*fp)();")), and spends a second of its own user time in `work` (#l("void", after: "tick(void)")--#l("}", after: "while (times(&tb), tb.tms_utime < HZ);")), so that
`prof` must report a thousand calls of `tick`, one of `work`, and most
of the time in `work`. The bound is user time, not the time of day,
so that a host which starves QEMU still leaves `work` a second of
clock ticks to be sampled in.

#lines-to(none)
#source("/usr/local/test/utils/physt.c")

The utility `physt` reads a block of the root disk through the raw device, into a
buffer in the data and one on the stack, and compares both with the
block read through the buffered device (#l("fd = open(\"/dev/rrk0\", 0);")--#l("i == 512 ? \"same\" : \"differ\");")). Raw transfers go
straight between the disk and the user's memory (`physio`,
#f("bio.c")), so the address must lie wholly within the process: a
buffer in the gap fails, as does one that crosses the end of the data,
while one ending exactly there succeeds (#l("errno = 0;", after: "i == 512 ? \"same\" : \"differ\");")--#l("printf(\"at end of data: %d errno %d\\n\", r2, errno);")). A negative offset
fails too (#l("errno = 0;", after: "printf(\"at end of data: %d errno %d\\n\", r2, errno);")--#l("printf(\"negative offset: %d errno %d\\n\", r1, errno);")).

#lines-to(none)
#source("/usr/local/test/utils/kcmp.c")

The utility `kcmp` compares the text of the running kernel, read through
`/dev/kmem` at the address its ELF section header gives, with the text
in `/unix`, a block at a time (#l("u = open(\"/unix\", 0);")--#l("}", after: "if (i >= 0)")). The commands `ps`, `pstat`, and `iostat` find
the kernel's tables by the symbols of `/unix`, so the file must be the
kernel that is running. The `kimage` case checks that it is.

#lines-to(none)
#source("/usr/local/test/utils/kmt.c")

The utility `kmt` reads the kernel's memory as the status commands do. The process
table must lie above the user's address space (#l("printf(\"proc above USRSIZE %d\\n\", nl[0].n_value >= USRSIZE);")). The process finds
its own entry in it (#l("pid = getpid();")--#l("printf(\"found self %d\\n\", i < NPROC);")), and reads its `user` structure twice,
through `/dev/kmem` at `UBASE` and through `/dev/mem` at the physical
address of its u-area, which must agree (#l("pa = ptob((unsigned long)pr.p_addr);")--#l("uk.u_procp == um.u_procp);")). `/dev/mem` has no
memory at the virtual address `UBASE`, and `/dev/kmem` none below the
kernel (#l("lseek(m, (long)UBASE, 0);")--#l("printf(\"kmem below the kernel %d\\n\", read(k, (char *)&uk, 4));")) (#f("mem.c")).

#lines-to(none)
#source("/usr/local/test/utils/r5r.c")

The utility `r5r` has two uses. Its `pw` mode fills a buffer of `BUFSIZ` + 1 bytes for
`getpw`, with a guard area behind it that must stay zero (#l("if (argc == 3 && strcmp(argv[1], \"pw\") == 0) {")--#l("return 0;")),
since `getpw` once copied a long line past the end of its caller's
buffer. Its `ch` mode runs a program
inside a `chroot`, so that `write` and `wall` can be tested against a
private `/etc/utmp` and private terminals (#l("if (argc >= 4 && strcmp(argv[1], \"ch\") == 0) {")--#l("}", after: "printf(\"cannot exec %s\\n\", argv[3]);")).

#lines-to(none)
#source("/usr/local/test/utils/fpt.c")

The utility `fpt` tests the vector floating point unit, whose state, thirty-two
`double` registers and the status and control register `FPSCR`, the
kernel saves for each process (#f("user.h")). Its argument selects a
test. The routine `ieee` (#l("static void", after: "__builtin_arm_set_fpscr(__builtin_arm_get_fpscr() & ~FLAGS);")--#l("}", after: "__builtin_arm_set_fpscr(0);")) prints the bit patterns of IEEE results, the
exception flags each sets, and `1/10` rounded in each of the four
rounding modes. The routine `fork` (#l("static void", after: "n ? \"found\" : \"missing\");")--#l("}", after: "printf(\"parent fpscr %08x %s\\n\", CTL(__builtin_arm_get_fpscr()),")) checks that the child inherits the
parent's rounding mode and registers, and that `exec` resets the mode
(#l("case 'e':")--#l("break;", after: "printf(\"exec fpscr %08x\\n\", __builtin_arm_get_fpscr());")).

The routine `switch` (#l("static void", after: "return(pid);")--#l("}", after: "printf(\"parent %s %d\\n\", bad ? \"bad\" : \"ok\", bad);")) runs two processes, each in its own rounding mode,
that hand a byte back and forth through pipes 500 times, while a third
reads the raw disk to keep interrupts coming. Each checks after every
exchange that its registers and mode are its own. The routine `sig` (#l("static void", after: "got++;")--#l("}", after: "__builtin_arm_get_fpscr() & 0x07ffffffU);"))
lets a signal handler change the mode and the registers in the middle
of a computation, once by the process's own `kill` and many times from
another process, and the computation must not notice. The routines `core` and
`rcore` (#l("static void", after: "__builtin_arm_get_fpscr() & 0x07ffffffU);")--#l("}", after: "n ? \"found\" : \"missing\");")) check that a core image holds the floating point
state.

#lines-to(none)
