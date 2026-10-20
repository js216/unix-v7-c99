#import "defs.typ": *

#let bx(body, w: auto, h: auto) = rect(width: w, height: h, inset: 3pt,
  stroke: 0.5pt, align(center + horizon, text(size: 7.5pt, body)))
#let ar = $arrow.r$
#let al = $arrow.l$
#let ad = $arrow.b$
#let au = $arrow.t$
#let lab(t) = text(size: 7.5pt, t)
#let diagram(body, caption, pl: auto) = figure(body, kind: "diagram",
  supplement: [Figure], caption: caption, placement: pl)
#let btable(columns: auto, align: left, caption: none, pl: auto, ..cells) = figure(
  kind: table, supplement: [Table], placement: pl,
  caption: figure.caption(position: top, caption),
  table(columns: columns, stroke: none,
    align: if type(align) == alignment and align.y == none { align + std.top } else { align },
    inset: (x: 4pt, y: 3pt), ..cells))
#let top = table.hline(stroke: 1pt)
#let mid = table.hline(stroke: 0.5pt)
#let bot = table.hline(stroke: 1pt)
#set place(clearance: 1.8em)
#show figure.caption: set text(size: 8.5pt)

== Introduction <ch-intro>

This book describes Unix v7 ported to run on these two machines:

*The QEMU machine* is the `virt` machine of the QEMU emulator, configured with a single ARM Cortex-A7 processor and 512~MB of
RAM at address 0x40000000, an ARM Generic Interrupt Controller (GIC)
version 2 at 0x08000000, the ARM generic timer, an ARM PL011 UART at
0x09000000 as the console, and, as the disk, a virtio block device,
found among the virtio "MMIO" slots at 0x0a000000. QEMU loads the
kernel into RAM itself and starts it at its entry point.

*The MP135 machine* is STMicroelectronics' STM32MP135F-DK, a small
board built around the company's STM32MP135F system-on-chip. The chip
contains one ARM Cortex-A7 processor and 128~KB
of on-chip RAM (SYSRAM) at 0x2ffe0000. The board adds 512~MB of DDR3L
memory, at 0xc0000000, and an SD card slot. The console is the chip's
USB OTG controller at 0x49000000, which appears to the host as a serial
device. The disk is the SD card, on the SDMMC1 controller at
0x58005000, and the interrupt controller is again a GIC version 2, at
0xa0021000. The kernel also uses the chip's reset and clock controller
(RCC), its power controller (PWR), its general purpose pins (GPIO), its
DDR controller, its TrustZone address space controller (TZC), which
guards the DDR memory, and, over the chip's I2C4 bus, the board's
STPMIC1 power management chip.

#btable(columns: (auto, 1fr, 1fr), caption: [The two machines],
  table.header(top, [], [*QEMU machine*], [*MP135 machine*], mid),
  [processor], table.cell(colspan: 2)[Cortex-A7, with the generic timer, on both],
  [interrupts], table.cell(colspan: 2)[GIC version 2, on both],
  [memory], [512~MB of RAM], [128~KB of SYSRAM, 512~MB of DDR],
  [console], [PL011 UART], [USB OTG, a serial device to the host],
  [disk], [virtio block device], [SD card on SDMMC1],
  [boot], [QEMU loads the kernel], [the ROM receives it by USB DFU],
  [also], [--], [PMIC, DDR controller, TZC, RCC],
  bot,
) <tab-machines>

The MP135 kernel is linked to run in SYSRAM. The build puts in front of
it the 512-byte header which the boot ROM requires (`mkstm32.c`, giving
`boot/unix-mp135.stm32`). The ROM, booted from USB, receives that image
through its DFU protocol (`dfu.py`) and starts it. Once running, the
kernel must power the DDR memory (#f("pmic.c")) and start its
controller (#f("ddr.c")) before it can use it.

The two machines have the same processor, interrupt controller, and
timer (@tab-machines), so the code for traps, interrupts, the MMU, and the clock is the
same for both. They differ in four ways: where memory lies, the
console, the disk, and the DDR memory of the MP135 machine, which the
kernel must start itself. Each difference is confined to a driver or
to the configuration.

One kernel source serves both machines. What differs is collected in
each machine's configuration (#f("qemuconf"), #f("mp135conf")), which
`mkconf` (#f("mkconf.c")) turns into a C file of device tables and
memory map (#f("qemu/c.c")).

The two machines serve different purposes. The QEMU machine is where
the system is built and tested: it starts in a second, and the test
suite runs on it, as it does on the board. The MP135 machine shows that the system runs on real
hardware, which brings what an emulator hides: a boot ROM with its own
rules, memory that must be started before it can be used, and caches
which devices do not see.

Throughout the book, "the QEMU machine" and "the MP135 machine" mean
these two, and a statement which names neither applies to both. Where the two differ, the text names the machine. The
board has more devices than the kernel uses, such as its Ethernet and
display, and the kernel leaves them as the boot ROM left them.

=== The ARM Processor <sec-arm>

The Cortex-A7 implements the ARMv7-A architecture. It has sixteen
32-bit registers, `r0` to `r15`. Three have a special use and a second
name: `r13` is the stack pointer `sp`, `r14` the link register `lr`,
which receives the return address of a call, and `r15` the program
counter `pc`. The current program status register `cpsr` holds the
condition flags, the two interrupt masks `I` and `F`, and the processor
mode.

The mode decides what a program may do. User programs run in user mode,
which cannot reach the kernel's memory or the system registers. The
kernel runs in supervisor (SVC) mode. Each kind of exception has a mode
of its own: IRQ for interrupts, abort for memory faults, and undefined
for an instruction the processor does not know. When an exception
occurs, the processor saves the `pc` and `cpsr` of the interrupted
program, enters the exception's mode, and jumps to that exception's
entry in the vector table.

Each of these modes has its own copy of `sp` and `lr`, called banked
registers (@tab-regs), and its own saved status register `spsr`, which receives the
interrupted `cpsr`. The other registers, `r0` to `r12`, are shared by
all modes, except the fast interrupt mode, which the system does not
use. So an exception changes the stack pointer and link register
at once, without touching the interrupted program's, and the entry code
must save `r0` to `r12` itself before it uses them. A special form of
the store-multiple instruction stores the user mode's `sp` and `lr`
from any other mode, and the kernel uses it to save a complete picture
of the user's registers.

#btable(columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr), align: center + horizon, caption: [The registers which each mode sees],
  table.header(top, [], [*User*], [*SVC*], [*IRQ*], [*Abort*], [*Undef.*], mid),
  [`r0`--`r12`], table.cell(colspan: 5)[shared by all modes],
  [`r13`, `sp`], [`sp`], [`sp_svc`], [`sp_irq`], [`sp_abt`], [`sp_und`],
  [`r14`, `lr`], [`lr`], [`lr_svc`], [`lr_irq`], [`lr_abt`], [`lr_und`],
  [`r15`, `pc`], table.cell(colspan: 5)[shared],
  [`cpsr`], table.cell(colspan: 5)[shared],
  [`spsr`], [--], [`spsr_svc`], [`spsr_irq`], [`spsr_abt`], [`spsr_und`],
  bot,
) <tab-regs>

The vector table (#f("low.s")) holds one instruction for each kind of
exception, at a fixed offset from its start (@tab-vectors).

#btable(columns: (auto, auto, auto, 1fr), align: (center, left, left, left), caption: [The exception vectors],
  table.header(top, [*offset*], [*exception*], [*mode*], [*the kernel's handler*], mid),
  [0x00], [reset], [SVC], [`_start`],
  [0x04], [undefined instruction], [undefined], [`undef_entry`: signal `SIGINS`],
  [0x08], [`svc`, a system call], [SVC], [`svc_entry`],
  [0x0c], [prefetch abort], [abort], [`pabort_entry`: signal `SIGSEG`],
  [0x10], [data abort], [abort], [`dabort_entry`: grow the stack, or `SIGSEG`],
  [0x14], [reserved], [--], [`badtrap`: panic],
  [0x18], [IRQ], [IRQ], [`irq_entry`],
  [0x1c], [fast interrupt], [FIQ], [`badtrap`: panic],
  bot,
) <tab-vectors>

The system control registers lie in coprocessor 15, reached by `mrc` and `mcr`.

C and assembly language call each other by the ARM Procedure Call
Standard (AAPCS). The first four arguments travel in `r0` to `r3`, and
the result returns in `r0`. A
called function may change `r0` to `r3`, `r12`, and `lr`, but must
preserve `r4` to `r11` and `sp`.

The processor does not perform memory accesses one at a time in program
order. A store waits in a store buffer before it reaches the data
cache, and loads may overtake it. The processor's own program always
sees its own stores, but other observers may not: the MMU, which reads
page tables from memory by itself, and devices which reach memory by
DMA. Barrier instructions restore the order where it matters. The
barrier `dmb` orders the accesses before it before those after it, and `dsb` waits
until they have all completed. An `isb` makes the processor fetch the
following instructions afresh, so that a change to a system register
takes effect.

=== The Address Space <sec-addr>

The user's address space is the lower three gigabytes, and the
kernel's the top one, which user mode cannot touch. @tab-addr shows
what lies where on each machine.

#btable(columns: (auto, 1fr, 1fr), caption: [The address space], pl: bottom,
  table.header(top, [*Address*], [*QEMU machine*], [*MP135 machine*], mid),
  [0x00000000], table.cell(colspan: 2)[zeros; signal trampoline at 8],
  [0x00000094], table.cell(colspan: 2)[text, with the ELF headers below it],
  [next page], table.cell(colspan: 2)[data and `bss`, growing upward],
  [0xbfffffff], table.cell(colspan: 2)[stack, growing downward],
  [0xc0000000], [RAM 0x40000000--0x5fffffff: kernel, then free RAM], [SYSRAM block 0x2fe00000; kernel at 0xc01e0000],
  [0xc0200000], [(RAM, continued)], [DDR 0xc0000000--0xdfffffff: tables, then free RAM],
  [0xf0000000], [GIC 0x08000000], [RCC, PWR, GPIO 0x50000000],
  [0xf0200000], [UART 0x09000000], [SDMMC1 0x58005000],
  [0xf0400000], [virtio 0x0a000000], [DDR controller 0x5a003000],
  [0xf0600000], [], [GIC 0xa0021000],
  [0xf0800000], [], [TZC 0x5c006000],
  [0xf0a00000], [], [USB OTG 0x49000000],
  [0xf0c00000], [], [I2C4 0x4c005000],
  [0xffe00000], table.cell(colspan: 2)[`u`, the current process's u-area],
  bot,
) <tab-addr>

A gigabyte holds all of RAM, 512~MB on either machine, the
device registers, and the u-area, with room to spare.

The kernel's gigabyte maps all of RAM at its start, so the kernel can
reach any page of memory at a fixed distance from its physical address
(`PGADDR`, #f("seg.h")). The device registers follow, one 2~MB block
each, and each device keeps its offset within its block: the MP135's
GIC, at 0xa0021000, is reached at 0xf0621000. In the same way SYSRAM, at
0x2ffe0000, lies 0x1e0000 into its block, and so the MP135 kernel runs
at 0xc01e0000. The devices are mapped only in the kernel's gigabyte, so
a user program reaches a device only through its driver. 

At the top lies the u-area of the current process: its `user`
structure (#f("user.h")) and its kernel stack. Every process's u-area
appears at the same address, `UBASE`, so the kernel refers to it simply
as `u`. A process switch changes which process's u-area is mapped
there.

In the user's space, each segment lies at the address its program was
linked for. The text begins at 0x8000, and the data on a later page, so
that it can be writable while the text is not. Below the text nothing
is mapped but the one page of the signal trampoline, at 0x1000, so a
null pointer faults. The kernel reaches the current
process's memory with the instructions `ldrt` and `strt`, which load
and store with the user's permissions (#f("mch.s")).

Kernel and physical addresses differ, and three places convert between
them. The kernel reaches a page of RAM through `PGADDR` (#at("/usr/sys/h/seg.h", "#define\tPGADDR")),
which adds the fixed distance `coreoff`. A driver must give a device
the physical address of a buffer, since a device sees physical memory,
and finds it with `vtop` (#at("/usr/sys/sys/machdep.c", "vtop(")). And `/dev/mem` and
`/dev/kmem` (#f("mem.c")) take their offsets as physical and kernel
addresses respectively.

A process's image in RAM is its u-area, `USIZE` pages at `p_addr`,
then its data, then its stack, packed together (@fig-image). The
tables spread these pages over the address space, with a gap which is
not mapped between the data and the stack. Each grows towards the
other, and each growth enlarges the image in RAM (`expand`). The gap
costs nothing, since tables exist only where something is mapped. The
text is shared, and lies in RAM on its own. The u-area takes the first
pages of its 2~MB block, since the kernel stack grows down from the
end of the u-area, which at the top of the address space would be
address 0.

#diagram(grid(columns: (auto, 2.4cm, 2.4cm, 2.4cm), row-gutter: 3pt,
  align: center + horizon,
  lab[RAM, from `p_addr`], bx(w: 100%)[u-area], bx(w: 100%)[data], bx(w: 100%)[stack],
  [], ad, ad, ad,
  lab[address space], lab[`UBASE`, 0xffe00000], lab[after the text],
    lab[up to 0xc0000000],
), [A process image in RAM and in the address space], pl: std.top) <fig-image>

=== Translation Tables <sec-tables>

The MMU translates addresses through tables in memory. The port uses
the long-descriptor format, with three levels: an entry of the first
level covers 1~GB, one of the second 2~MB, and one of the third a page
of 4096~bytes. An entry either maps its whole range as one block, or
points to a table of the next level. @fig-bits shows which bits of a
user address select the entry at each level.

#diagram({
  let small(t) = text(size: 7.5pt, t)
  let fld(lo, hi, body) = stack(dir: ttb, spacing: 2pt,
    pad(x: 2pt, grid(columns: (1fr, 1fr),
      align(left, text(size: 6.5pt)[#hi]), align(right, text(size: 6.5pt)[#lo]))),
    rect(width: 100%, inset: 4pt, stroke: 0.6pt, align(center, small(body))))
  let c(t) = align(center, small(t))
  grid(columns: (4fr, 9fr, 9fr, 12fr), row-gutter: 5pt,
    fld(30, 31)[index], fld(21, 29)[index], fld(12, 20)[index],
      fld(0, 11)[offset],
    c[0], c[0], c[`0x12`], c[`0x345`],
    ..range(4).map(_ => align(center, $arrow.b$)),
    c[first-level\ entry], c[second-level entry],
      c[third-level entry:\ the page], c[byte within\ the page],
  )
}, [How the MMU divides a user address, here `0x00012345`]) <fig-bits>

The processor has two table base registers. `TTBR0` translates the
user's three gigabytes, and `TTBR1` the kernel's top one, as `TTBCR`
divides them (#at("/usr/sys/conf/low.s", "mcr p15, 0, r0, c2, c0, 2")). So the kernel's half is described once,
for all processes, and each process has tables of its own for the
lower half (@fig-tree). A process switch changes only `TTBR0`.

#diagram(grid(columns: 7, column-gutter: 4pt, row-gutter: 6pt,
  align: horizon,
  bx[`TTBR0`], ar, bx(w: 2.1cm)[first level, one per process], ar,
    bx(w: 1.8cm)[second level], ar, bx(w: 2.1cm)[third level: text, data, and stack pages],
  bx[`TTBR1`], ar, bx(w: 2.1cm)[`kl2`: 2~MB blocks of RAM and devices], ar,
    bx(w: 1.8cm)[last entry: `kl3u`], ar, bx(w: 2.1cm)[the u-area page at `UBASE`],
), [The user's tables, above, and the kernel's, below]) <fig-tree>

The kernel's tables are built at boot. First `_start` (#at("/usr/sys/conf/low.s", "_start:")) maps the
kernel through `kl2`, a second-level table of 2~MB blocks, and adds a
temporary identity mapping, `bootl1`, so that the code keeps running at
its physical address while the MMU is turned on. Then `machine_init`
(#f("machdep.c")) maps all of RAM and the devices in `kl2`, maps
the u-area of process 0 through `kl3u`, a third-level table for the
top 2~MB, and removes the identity mapping. The kernel's tables do not
change after that, except for the entries of `kl3u`, which `resume`
(#f("mch.s")) rewrites at each switch to show the new process's
u-area.

Each process's own tables are built from a prototype. The sizes of the
text, data, and stack are recorded by `estabur` (#f("ureg.c")), and
the tables are built from them by `sureg` when they are needed. The text pages are mapped
read-only and the data and stack pages writable, all with user access.
Finally `ttbset` (#at("/usr/sys/conf/mch.s", "ttbset:")) loads `TTBR0` with the process's first-level
table.

For example, a program which loads from address `0x00012345` makes the
MMU take entry 0 of the process's first-level table, which points to a
second-level table. Entry 0 of that points to a third-level table, and
entry `0x12` of that gives the physical page. The load reads byte
`0x345` of that page.

An address that the tables do not map, or a store to a read-only page,
raises a data abort (#f("low.s")). If the address lies just below the
user's stack, the kernel grows the stack and the instruction runs
again. Otherwise the process is sent the signal `SIGSEG`, which by
default ends it with a core image.

The MMU keeps recent translations in a cache of its own, the TLB. Every entry is either
global, valid in every address space, or tagged with an address space
identifier. The kernel's entries are global and the user's are not, and
every process uses identifier 0. Global entries let the kernel's
translations survive a process switch, so the kernel's own addresses
need no new table walk after each switch. When `ttbset` changes the
user's tables, it discards the entries of identifier 0 and keeps the
kernel's.
When `resume` changes `kl3u`, it discards the translations of `UBASE`
alone.

Two ordering rules follow from the store buffer. A store to a table must complete, by `dsb`, before the MMU can see it, and a discard of translations must complete, by `dsb` and `isb`, before an access which depends on it.

=== The Boot Process

QEMU loads the kernel into RAM and starts it, and on the MP135 machine
the boot ROM loads it into SYSRAM. Either way the kernel starts at
`_start` (#at("/usr/sys/conf/low.s", "_start:")), in SVC mode, at its physical address, with the
MMU off. From there the system comes up in these steps (@fig-boot):

+ First `_start` masks interrupts, turns off the MMU and the caches, discards
  whatever the TLB, the caches, and the branch predictor hold, and
  clears the kernel's `bss`. It builds the boot tables, turns the MMU
  on, and jumps to the kernel's virtual address. It sets up a small boot
  stack, installs the exception vectors, enables the floating point
  unit, and calls `machine_init` (#at("/usr/sys/sys/machdep.c", "machine_init(")).
+ Then `machine_init` maps the device registers, switches the interrupt
  controller off, and starts the console, so that `printf` and `panic`
  work from then on. On the MP135 machine it then powers the DDR memory
  and starts its controller. Only then does it map the rest of RAM,
  clear the part of the kernel which lies in DDR, map the u-area of
  process 0, and remove the identity mapping. It returns the top of
  that u-area.
+ Back in `_start`, the stack pointer is moved to the top of the
  u-area, and `main` is called (#at("/usr/sys/sys/main.c", "main(")). From then on the kernel stack is always the
  current process's.
+ Next `startup` (#at("/usr/sys/sys/machdep.c", "startup(")) puts
  every free page of RAM in the core map, sets aside pages for the
  processes' tables, and enters the swap area in the swap map. The running code becomes process 0.
+ Next `clkstart` (#at("/usr/sys/sys/machdep.c", "clkstart(")) programs the timer, and `intrstart`
  (#at("/usr/sys/sys/machdep.c", "intrstart(")) enables the interrupts and unmasks them. Then `main` initialises the character
  lists and the buffer cache, reads the super-block of the root file
  system, and makes the root directory the current one.
+ Next `main` calls `newproc` (#at("/usr/sys/sys/slp.c", "newproc(")) to make process 1 as a copy of
  process 0. In process 0, `newproc` returns 0, and `main` calls
  `sched`, in which process 0 stays forever as the swapper (Scheduling
  and Swapping).
+ In process 1, `newproc` returns 1. Then `main` gives the new process a page
  of user memory, copies into it `icode`, a few instructions of machine
  code (#f("machdep.c")), and returns. The return reaches `_start`
  again, which enters user mode at address 0, in process 1.
+ The program `icode` makes one system call, `exec("/etc/init")`. From here the
  system is an ordinary process running an ordinary program.

#diagram(grid(columns: 9, column-gutter: 3pt, row-gutter: 5pt,
  align: center + horizon,
  bx[`_start`], ar, bx[`machine_init`], ar, bx[`main`], ar, bx[`newproc`],
    ar, bx[process 0: `sched`],
  [], [], [], [], [], [], ad, [], [],
  [], [], [], [], bx[`/etc/init`], al, bx[process 1: `icode`], [], [],
), [From reset to `init`]) <fig-boot>

What the MMU maps changes three times on the way (@tab-boot).

#btable(columns: (auto, 1fr), align: left, caption: [The mappings during boot],
  table.header(top, [*stage*], [*what is mapped*], mid),
  [`_start`, MMU off], [nothing: every address is physical],
  [`_start`, MMU on], [the kernel image at its kernel address, and the same memory at its physical address (`bootl1`)],
  [after `machine_init`], [all of RAM and the devices, the u-area of process 0 at `UBASE`; the identity mapping is gone],
  [after `newproc`], [also process 1's own tables, with one page of user memory holding `icode`],
  bot,
) <tab-boot>

Each stage relies on the one before. While `machine_init` runs, only the
kernel image is mapped, so it may not touch any other memory until it
has mapped it.

The first program, `init` (#f("cmd/init.c")), starts a shell on the console, with no
other users, so that the administrator can check the file systems
before anyone else uses them. When that shell exits, `init` runs the
start-up script `/etc/rc`, which starts `update` and `cron`, and then
starts a `getty` on each terminal listed in `/etc/ttys`, which waits for
a user to log in. If `init` ever dies, the system cannot continue, since
every process descends from it. Its process number is always 1, and it
is the parent of every login shell, through `getty` and `login`.

=== Interrupt Handling <sec-intr>

Each device's interrupt line goes to the Generic Interrupt Controller
(GIC). The GIC passes the most urgent pending interrupt to the processor
as an IRQ. If interrupts are not masked, an interrupt goes through these
steps:

+ The processor stops the program it was running, enters IRQ mode, and
  jumps to the IRQ entry of the vector table (#f("low.s")).
+ Then `irq_entry` pushes the interrupted program's `pc` and `cpsr` onto the
  SVC stack, which is the current process's kernel stack, and changes to
  SVC mode with interrupts masked. It then saves the remaining registers
  on the same stack, and so builds a frame of all the interrupted
  program's registers (#f("reg.h"), @tab-frame).
+ Next `irq_entry` calls `irq` (#at("/usr/sys/sys/machdep.c", "irq(")) with the address of the
  frame.
+ Then `irq` reads the interrupt's number from the GIC, looks it up in
  `intrtab`, which the configuration generates (#f("qemu/c.c")),
  and calls the routine found there with the interrupted program counter
  and status.
+ Then `irq` tells the GIC that the interrupt is done, so that the GIC will
  deliver another.
+ If the interrupt came from user mode and a process of better priority
  is now ready to run (`runrun`), `irq_entry` calls `user_trap_handler`
  (#f("trap.c")), which switches processes, as at the end of every trap.
+ Finally `irq_entry` unloads the frame, and the interrupted program continues
  where it stopped.

#btable(columns: 6, align: center, caption: [The frame on the kernel stack, at `u.u_ar0` (#f("reg.h"))],
  table.header(top, [*offset*], [0--48], [52], [56], [60], [64], mid),
  [*word*], [`r0`--`r12`], [user `sp`], [user `lr`], [`pc`], [status],
  bot,
) <tab-frame>

For example, when a key is pressed at the QEMU machine's console, the
UART interrupts. Then `irq` finds the UART's number in `intrtab` and calls
`klintr` (#at("/usr/sys/dev/pl011.c", "klintr(")), which reads the character and passes it to the
terminal code (Terminal I/O). That code wakes the process waiting for
the line, which will run when the scheduler chooses it.

The timer's routine is `clock` (#at("/usr/sys/sys/clock.c", "clock(")), which runs sixty times a
second. It sets the timer's next deadline, runs the timeouts that are
due, charges the tick to the current process, and once a second
recomputes the priorities of all processes and wakes the swapper.

Interrupts nest only in a limited way. While one interrupt routine
runs, the GIC delivers no other, even if the routine unmasks
interrupts. Once `irq` has told the GIC that the interrupt is done,
another may be taken before the first frame is unloaded. Its frame
then goes below the first on the same stack, and is unloaded first.

If the kernel was interrupted, the new frame simply lies below whatever
the kernel had on its stack. 

A driver that must act after a delay, such as the terminal code
waiting out a carriage return, calls `timeout` (#at("/usr/sys/sys/clock.c", "timeout(")) with a
routine, an argument, and a number of ticks. The timeouts are kept in
the table `callout`, sorted by time, each entry holding the ticks
after the one before it. So `clock` need only count down the first
entry, and calls each routine whose count reaches zero.

The interrupts are enabled in one place, by `intrstart`
(#at("/usr/sys/sys/machdep.c", "intrstart(")), which gives each interrupt listed in `intrtab` a priority and enables it in
the GIC, then enables the GIC itself. Until then the GIC is off, and no
interrupt can arrive, however early a driver unmasks interrupts. The kernel masks interrupts where an
interrupt routine could disturb what it is doing, with `intr_disable`
and `intr_restore` (#at("/usr/sys/conf/mch.s", "intr_restore:")). The ARM has one interrupt mask, so
interrupts are on or off, with no priorities as on the PDP-11. An
interrupt routine runs on whatever process's kernel stack is current,
so it must never sleep. It may only wake processes, by `wakeup`
(#f("slp.c")), and leave the rest of the work to them.

=== System Calls <sec-syscalls>

A program makes a system call through a routine of the C library, such
as `read` (#at("/usr/src/libc/sys/read.s", "read:")). The call goes through these steps
(@fig-syscall):

+ The library routine puts the number of the call in register `ip` and
  jumps to `cerror` (#at("/usr/src/libc/syscall.s", "cerror:")). The call's arguments are
  already in `r0` to `r3`, where C put them.
+ Then `cerror` moves the number to `r7` and executes `svc #0`. The `svc`
  instruction raises an exception, and the processor enters SVC mode at
  the system call entry of the vector table.
+ The entry code, `svc_entry` (#at("/usr/sys/conf/low.s", "svc_entry:")), saves the user's registers as a frame on the
  process's kernel stack, unmasks interrupts, and calls `trap`
  (#f("trap.c")) with the address of the frame.
+ Then `trap` takes the call's number from the saved `r7` and finds the call
  in the table `sysent` (#at("/usr/sys/sys/sysent.c", "struct sysent sysent")), which gives the number of
  arguments and the routine that implements the call. It copies the
  arguments into `u.u_arg` and calls the routine.
+ The routine leaves its result in `u.u_r`, or an error number in
  `u.u_error`.
+ On return, `trap` writes the result into the saved `r0` and `r1`. If the call
  failed, it writes the error number into the saved `r0` instead, and
  sets the carry flag in the saved status.
+ Next `trap` delivers any pending signal (Signals), recomputes the process's
  priority, and gives up the processor if a better process is ready
  (Scheduling and Swapping), as every return to user mode does.
+ Back in `svc_entry`, interrupts are masked and the frame unloaded, so that the user's
  registers receive the results, and returns to the instruction after
  the `svc`.
+ Finally `cerror` tests the carry flag. If it is clear, it returns the result.
  If it is set, it stores the error number in `errno` and returns -1.

#diagram(grid(columns: 7, column-gutter: 3pt, row-gutter: 5pt,
  align: horizon,
  lab[user], bx[`read`], ar, bx[`cerror`], ar, bx[`svc #0`], [],
  [], [], [], [], [], ad, [],
  lab[kernel], bx[routine], al, bx[`sysent`], al, bx[`svc_entry`, `trap`], [],
), [The path of a system call into the kernel]) <fig-syscall>

For example, `read(fd, buf, n)` arrives with the file descriptor in
`r0`, the buffer's address in `r1`, and the count in `r2`, and with 3,
the number of `read`, in `r7`. Entry 3 of `sysent` says three arguments
and the routine `read` (#at("/usr/sys/sys/sys2.c", "read(")). When it returns, the saved `r0`
holds the number of bytes read, and the carry flag is clear. If `fd`
was not open, the saved `r0` holds `EBADF` instead, the carry flag is
set, and the library returns -1 with `errno` set to `EBADF`. The table has 64~entries, and `trap` takes the call's number
modulo 64. Unused entries hold `nosys` (#at("/usr/sys/sys/trap.c", "nosys(")), which fails the
call with `EINVAL`.

The carry flag lets one register carry either a result or an error. A
result may be any value, even a negative one such as the offset which
`lseek` returns, so no value of `r0` could be set aside to mean
failure. Some calls return two values, in `r0` and `r1`: `pipe` returns
both of its file descriptors, and `fork` returns a process number in
`r0` and, in `r1`, whether the process is the child.

The one call which does not return to the instruction after its `svc`
is `exec`. When it succeeds, it has replaced the saved program counter
and stack pointer in the frame with the new program's, so the return
from `trap` enters the new program at its first instruction.

The frame's address is kept by `trap` in `u.u_ar0`, through which a
system call can reach the user's registers. The routines take no
arguments of their own, and find them in `u.u_arg`.

A system call may sleep, waiting for a key to be pressed, say. If a signal arrives meanwhile, the sleep is abandoned: `sleep`
(#f("slp.c")) returns, through `resume`, to the point which `trap`
recorded in `u.u_qsav` before it called the routine, and the call fails
with the error `EINTR`.

A system call runs on the process's own kernel stack, in the process's
own u-area, so it may sleep without disturbing any other process. That
is what lets the kernel be written as ordinary C code which simply
waits when it must.

=== Scheduling and Swapping <sec-sched>

A process waits by calling `sleep` (#at("/usr/sys/sys/slp.c", "sleep(caddr_t")) with an address, the
event it waits for, and a priority. Then `sleep` marks the process asleep
and calls `swtch` to run another. The process that later causes the
event, or an interrupt routine, calls `wakeup` with the same address,
which makes every process sleeping on it runnable, and each must
check, when it runs again, that what it waited for is still there.

The routine `swtch` decides which process runs (@fig-states). It searches the runnable processes
in memory for the one of best priority, and switches to it. If there is
none, it calls `idle` (#at("/usr/sys/conf/mch.s", "idle:")), which halts the processor until an
interrupt, and searches again. A process's priority depends on its
recent use of the processor, which `clock` (#at("/usr/sys/sys/clock.c", "clock(")) counts and
decays once a second, and on its `nice` value (`setpri`). A process that has waited on an
event gets the better priority given in the call of `sleep`. 

#diagram(grid(columns: 5, column-gutter: 4pt, row-gutter: 4pt,
  align: center + horizon,
  bx(w: 1.7cm)[ready], [#lab[`swtch`] #ar], bx(w: 1.7cm)[running], [#lab[`sleep`] #ar], bx(w: 1.7cm)[asleep],
  grid.cell(colspan: 5)[#al #lab[`wakeup` makes it ready again] #al],
  [#lab[`sched`] $arrow.t.b$], [], [#ad #lab[`exit`]], [], [],
  bx(w: 1.7cm)[swapped out], [], bx(w: 1.7cm)[zombie], [], [],
), [The states of a process, and the routines which move it between them]) <fig-states>

The switch itself is done by `save` and `resume` (#at("/usr/sys/conf/mch.s", "resume:")). The first, `save`,
records the registers a function must preserve, the stack pointer, and
the return address, in the current u-area. The second, `resume`, maps
another
process's u-area at `UBASE`, and reloads the registers that process
saved there when it last ran. The new process then continues in
`swtch`, returning from it into whatever had called `swtch`. Since the
u-area holds the kernel stack, mapping a different one changes the
whole kernel state of the process at once. The user's tables follow
when the new process returns toward user mode (`sureg`, #f("ureg.c")).

A process gives up the processor in two ways. It sleeps, waiting for
an event. Or it is preempted: the flag `runrun` is set when a process
of better priority becomes runnable, and once a second by `clock`. The
kernel tests the flag only on the way back to user mode, after a trap,
a system call, or an interrupt from user mode. So a process running in
the kernel is never preempted. It keeps the processor until it sleeps
or returns to user mode. That is why the kernel needs no locks against
other processes, only masked interrupts against interrupt routines.

The priority given to `sleep` says how urgently the process must run
once the event has happened. Lower numbers are better (@tab-pri;
#f("param.h"), #f("tty.h")).

#btable(columns: (auto, auto, 1fr), align: left, caption: [Sleep priorities],
  table.header(top, [*name*], [*value*], [*waiting for*], mid),
  [`PSWP`], [0], [the swapper's own work],
  [`PINOD`], [10], [an inode],
  [`PRIBIO`], [20], [a disk buffer],
  [`PZERO`], [25], [the boundary: better priorities ignore signals],
  [`PPIPE`], [26], [a pipe],
  [`TTIPRI`, `TTOPRI`], [28, 29], [terminal input, terminal output],
  [`PWAIT`], [30], [a child to exit],
  [`PSLEP`], [40], [the alarm clock of `sleep`],
  [`PUSER`], [50], [the base of user priorities],
  bot,
) <tab-pri>

A user process's priority is `PUSER`, plus its recent use of the
processor divided by 16, plus its `nice` value (`setpri`, #f("slp.c")).
The use, `p_cpu`, grows by one each tick the process runs, and once a
second `clock` multiplies it by 8/10.

Process 0 is the swapper. It runs `sched` (#at("/usr/sys/sys/slp.c", "sched(")) forever. When a
runnable process has been swapped out to disk, `sched` looks for room
in memory to swap it back in. If there is none, it chooses a process to
swap out: preferably a large one asleep at low priority, otherwise one
that has been in memory long enough. Then it writes that process's
image to the swap area and frees its memory.

=== Process Creation

A new process is made by `fork` (#at("/usr/sys/sys/sys1.c", "fork(")) as a copy of the caller,
through `newproc` (#at("/usr/sys/sys/slp.c", "newproc(")), which takes a free entry in the
process table and fills it from the parent's. The child shares the
parent's open files and current directory, whose reference counts go
up, and its text, which is never copied. Then the parent's image, its
u-area, data, and stack, is copied: into free memory if there is room,
or else to the swap area, from which the swapper will bring the child
in. In the parent, `newproc` returns 0. The child first runs when
`swtch` resumes it, at the point where the copy was taken, and there
`newproc` returns 1. The system call `fork` and its library routine (#f("sys/fork.s")) turn
the two returns into the child's process number in the parent and 0 in
the child.

The data and stack must be copied, since both processes continue and
write to them. The text, which neither may write, is the one part they
can share. Copying a large image takes time, and the shell usually
does it only to call `exec` in the child at once. 

A process's image in memory is one contiguous piece (@tab-image): the u-area, then
the data, then the stack. The text is a separate piece, shared by every
process running the same program (`xalloc`, #f("text.c")). Each piece
is taken from the core map, a list of free pieces of memory
(#f("malloc.c")). The process's tables translate the user's addresses
to these pieces (Translation Tables). 

#btable(columns: (auto, 1fr, 1fr), caption: [A process's image in RAM, and where each part is seen],
  table.header(top, [*part*], [*in RAM*], [*seen at*], mid),
  [u-area], [the start of the image], [`UBASE`, by the kernel only],
  [data], [after the u-area], [the page after the text],
  [stack], [after the data], [just below 0xc0000000],
    [text], [a separate piece, shared], [0x8000],
  [trampoline], [one page, shared by all], [0x1000],
  bot,
) <tab-image>

The program a process runs is replaced by `exec` (#at("/usr/sys/sys/sys1.c", "exec(")). It reads
the program's ELF headers and checks them. It copies the arguments and
the environment to a temporary area in the swap space, since the old
image, which holds them, is about to go. It then releases the old text,
and finds the new one in the text table if another process is running
the same program, or reads it in from the file. It grows or shrinks
the image to the sizes the headers give, reads in the data, clears the
`bss`, and builds the new stack with the arguments on it. Finally it
sets the program counter to the program's entry point, and resets the
signals the old program had caught.

Instructions read in from a file pass through the data cache, which
the instruction fetch does not see. So whenever the kernel writes
instructions, a text, `icode`, the signal trampoline, or a word stored
by a debugger, it must call `arm_sync_icache` (#at("/usr/sys/conf/mch.s", "arm_sync_icache:")). The call
writes the new instructions out of the data cache and discards the
instruction cache, so that the processor fetches the new instructions.

A process changes its size in two ways. A call of `brk` asks for more or less
data, and the stack grows when a program touches an address just below
it. The data abort handler (#f("trap.c")) sees such a fault and calls
`grow` (#at("/usr/sys/sys/sig.c", "grow(")), and the faulting instruction is executed again. Both
use `expand` (#at("/usr/sys/sys/slp.c", "expand(")), which takes a larger piece of memory and
copies the image into it, or swaps the process out if there is none,
and `estabur` (#at("/usr/sys/sys/ureg.c", "estabur(")), which records the new sizes for the
tables.

A process ends with `exit` (#at("/usr/sys/sys/sys1.c", "exit(int")). It closes its files,
releases its text and its memory, and becomes a zombie, which keeps
only its process table entry, with its exit status and times, until
its parent collects them with `wait`. A process whose parent dies is
given to process 1, `init`, which waits for it in turn. 

The text table (#f("text.h")) keeps one entry for each program being
run. It counts the processes that share the text, and how many of them
are in memory. The text is read in when the first process runs it, and
freed when the last one exits, unless the program file has the sticky
bit, which keeps its text on the swap area for the next run. A program
file cannot be written while its text is in use, nor run while it is
open for writing: the attempt fails with `ETXTBSY`.

=== Signals <sec-signals>

A signal is an event sent to a process: a key such as interrupt or
quit at its terminal, a fault in its program, an alarm, or a `kill`
from another process. The kernel posts it with `psignal`
(#f("sig.c")), which sets a bit in the process's table entry and, if
the process sleeps at an interruptible priority, wakes it.

#btable(columns: (auto, auto, 1fr, auto), align: left, caption: [The signals],
  table.header(top, [*no.*], [*name*], [*sent when*], [*default*], mid),
  [1], [`SIGHUP`], [the terminal hangs up], [exit],
  [2], [`SIGINT`], [the interrupt key, DEL], [exit],
  [3], [`SIGQUIT`], [the quit key, control-backslash], [core],
  [4], [`SIGINS`], [an illegal instruction], [core],
  [5], [`SIGTRC`], [a trace or breakpoint], [core],
  [9], [`SIGKIL`], [`kill -9`; cannot be caught or ignored], [exit],
  [11], [`SIGSEG`], [a memory fault], [core],
  [6--8, 10, 12], [`SIGIOT`, `SIGEMT`, \ `SIGFPT`, `SIGBUS`, \ `SIGSYS`], [PDP-11 traps; this kernel sends them only by `kill`], [core],
  [13], [`SIGPIPE`], [a write to a pipe with no reader], [exit],
  [14], [`SIGCLK`], [the alarm clock], [exit],
  [15], [`SIGTRM`], [`kill`, by default], [exit],
  bot,
) <tab-signals>

Whether a sleep is interruptible is decided by its priority, given in
the call of `sleep` (#at("/usr/sys/sys/slp.c", "sleep(caddr_t")). A process that waits for something
which is sure to happen soon, such as a disk transfer, sleeps at a
priority of `PZERO` or better (#f("param.h")), and a signal does not
wake it. A process that
waits for something which may never happen, such as a key at a
terminal or the death of a child, sleeps at a worse priority, and a
signal ends its wait.

A process acts on its signals only on the way back to user mode. Every
trap, system call, and interrupt from user mode ends with a call of
`issig` (#at("/usr/sys/sys/sig.c", "issig(")), and if a signal is pending, with `psig`. So a signal takes effect at the next return to user mode.

For each signal a process has asked either to take the default action,
to ignore it, or to catch it with a handler (`ssig`).

To catch a signal, the kernel makes the process call its handler:

+ First `sendsig` (#at("/usr/sys/sys/machdep.c", "sendsig(")) copies the user's saved registers and
  floating point state onto the user's stack, below the current stack
  pointer (@fig-sigstack).
+ Then `sendsig` changes the saved registers in the frame. The stack pointer
  is set to below the copy, the program counter to the handler, `r0` to
  the signal number, and the link register to
  the signal trampoline at user address 0x1000 (`SIGTRAMP`, #f("seg.h")).
+ The frame is unloaded, and the process continues, not where it was
  interrupted, but at the first instruction of its handler.
+ The handler, an ordinary C function, returns through its link register
  to address 0x1000.
+ There `startup` (#at("/usr/sys/sys/machdep.c", "startup(")) has put two instructions, `mov r7, #63`
  and `svc #0`, the system call `sigreturn`, into one page which every
  process maps.
+ The system call `sigreturn` reads the copy back from the user's stack into the frame.
  When the frame is unloaded, the program continues where the signal
  interrupted it, with all its registers as they were.

#diagram(grid(columns: 2, column-gutter: 6pt, row-gutter: 0pt,
  align: horizon,
  bx(w: 4cm)[the interrupted program's stack], lab[higher addresses],
  bx(w: 4cm)[floating point state], [],
  bx(w: 4cm)[saved registers, 17~words], lab[$al$ stack pointer at the handler's entry],
  bx(w: 4cm)[the handler's own frames], lab[lower addresses],
), [The user's stack while a handler runs]) <fig-sigstack>

@tab-signals lists the signals, and what each does by default
(#f("param.h")).

A caught signal reverts to its default when it is delivered, except
for the illegal instruction and trace signals.

=== Saved State <sec-saved>

The registers of a process are saved in six places, each for its own
purpose (@tab-saved). Most of the trap, switch, and signal code is
about putting registers into one of them and taking them out again.

#btable(columns: (1.25fr, 1fr, 1fr, 1fr), align: left, caption: [Where registers are saved], pl: bottom,
  table.header(top, [*what*], [*saved by*], [*kept in*], [*restored by*], mid),
  [user registers at entry], [every trap and interrupt (#f("low.s"))], [frame on the kernel stack], [the common return (#f("low.s"))],
  [kernel registers at a switch], [`save` in `swtch`], [`u_rsav`], [`resume` in `swtch`],
  [the start of a system call], [`save` in `trap`], [`u_qsav`], [`resume` in `sleep`, on a signal],
  [the point of a copy], [`save` in `newproc`, `expand`, `xswap`], [`u_ssav`], [`resume` in `swtch`, under `SSWAP`],
  [floating point registers], [`swtch`, `newproc`, `expand`, `psig`], [`u_fps`], [the return to user mode],
  [user registers for a handler], [`sendsig`], [frame on the user stack], [`sigreturn`],
  bot,
) <tab-saved>

Every entry to the kernel from user mode, by a system call, an
interrupt, or a fault, saves all of the user's registers on the kernel
stack in the u-area (@tab-frame, page #pageref(<tab-frame>)). The kernel finds them through
`u_ar0` (#f("user.h")), and a system call returns its results by
changing them. When the kernel itself is interrupted, a frame of the
same form is saved below whatever the kernel had on its stack, and
holds the kernel's registers instead.

A label holds only the registers which a called function must
preserve, `r4` to `r11`, `sp`, and `lr` (`label_t`, #f("param.h")). The
routine `save` stores them and returns 0. Later `resume` reloads them,
and the original call of `save` returns a second time, with 1. The
stack pointer is among them, and the kernel stack lies in the u-area,
so `resume` also maps the u-area of the process whose label it loads.
Three labels serve three purposes. The label `u_rsav` records where a
process stopped in `swtch`, and is where it continues when chosen
again. The label `u_qsav` records where `trap` began a system call.
When a signal ends a wait, `sleep` resumes there, and the call returns
`EINTR`. Process 0 uses its own `u_qsav` as the entry to the search
loop of `swtch`. The label `u_ssav` records the point at which a
process's image was copied, to a new place in RAM or to the swap area,
and the flag `SSWAP` makes `swtch` resume the process there instead of
at `u_rsav`.

A process switch shows the labels at work. The running process calls
`swtch` (#at("/usr/sys/sys/slp.c", "swtch(void)")), whose `save` into `u_rsav` returns 0, and `swtch`
then resumes process 0 at its `u_qsav`. Process 0 chooses the next
process and resumes it at its `u_rsav`. There that process's own
earlier `save` returns 1, and its `swtch` returns to the caller, which
carries on as if the call had just been made.

The floating point registers are not saved on every entry. They stay
in the hardware while the process is in the kernel, and are stored in
`u_fps` (#f("user.h")) only when another process may take the unit or
the u-area may be copied. The flag `u_fpsaved` then makes the return to
user mode load them again.

To run a signal handler, `sendsig` copies the frame of user registers
and the floating point registers to the user's stack, and points the
frame at the handler (see _Signals_, page #pageref(<sec-signals>)). When the handler
returns, `sigreturn` copies them back. This is the only saved state
which lies in user memory, where the program can change it, so
`sigreturn` checks what it takes back.

A process may have state in several of these places at once. A process
asleep in a read from a terminal has the frame of its user registers,
`u_qsav` from the start of the read, and `u_rsav` from the point in
`swtch` where it gave up the processor.

=== Disk I/O <sec-disk>

Programs read and write files in bytes, but the disk moves blocks of
512~bytes. Between the two lies the buffer cache (#f("bio.c")), a pool
of buffers in memory, each holding one disk block. The routines `readi` and `writei`
(#f("rdwri.c")) translate a position in a file into a block of the
disk, by `bmap` (#at("/usr/sys/sys/subr.c", "bmap(")), and move bytes between the user and a
buffer.

A block is asked for with `bread` (@fig-disk). If a buffer already holds it, no disk
transfer is needed. Otherwise `getblk` takes the buffer least recently
used, and `bread` asks the disk driver to fill it. The driver's
strategy routine (`rkstrategy`) puts the request on the driver's queue
and starts the disk if it is idle. The process then sleeps on the
buffer.

When the transfer ends, the disk interrupts. The driver's interrupt
routine (`rkintr`) marks the buffer done by `iodone`, which wakes the
sleeping process, and starts the next request on the queue. The process
returns from `bread` with the block.

#diagram(grid(columns: 9, column-gutter: 3pt, align: horizon,
  bx[`bread`], ar, bx[cache], ar, bx[`rkstrategy`], ar, bx[disk], ar, bx[`rkintr`, `iodone`],
), [A block read which misses the cache. On a hit, `bread` returns at once], pl: bottom) <fig-disk>

A buffer in use is marked busy, and taken off the list of free
buffers, a doubly linked list through the buffers' `av_forw` and
`av_back` (#at("/usr/sys/h/buf.h", "struct\tbuf *av_back")), so that no other process can reuse it. A process that wants a
busy buffer marks it wanted and sleeps on it. The routine `brelse` puts the buffer
back on the free list, at the end, so the free list is in order of last
use, and wakes any process that wanted it. For a file read in order,
`readi` also starts reading
the next block of a file ahead, with `breada`, so that a program
reading a file in order usually finds its next block already there.

For example, when `cat` reads a file of three blocks from the start,
the first `bread` misses the cache, and the process sleeps until the
disk has delivered the block. Meanwhile `breada` has asked for the
second block, so the second read finds it in the cache, or already on
its way. A second `cat` of the same file soon after finds all three
blocks in the cache, and never waits for the disk.

A failed transfer marks the buffer in error, and the system call which
asked for the block fails with `EIO` (`geterror`, #f("bio.c")). A write
may also be started without waiting for it, by `bawrite`, when the
kernel knows that the block is complete, as `exec` does when it saves
a program's arguments on the swap area.

Writes usually go only to the buffer. The routine `bdwrite` marks the buffer dirty
and leaves it in the cache, since the next write often goes to the same
block. A dirty buffer is written to the disk when it is about to be
reused for another block, and whenever `sync` writes out all of them,
which `/etc/update` (#f("cmd/update.c")) asks for every 30~seconds.

Each machine has one disk driver, with the same entry points on both:
the virtio block driver on the QEMU machine (#f("virtio_blk.c")), and
the SD card driver on the MP135 machine (#f("sd.c")). Both are called
`rk` in the configuration, the name of the disk they replace. The swap
area lies on the same disk, after the root file system, and swapping
goes through the same driver, with a buffer of its own. The kernel
finds a disk's driver by its major device number in the block device
switch, `bdevsw` (#f("qemu/c.c")), a table which holds each driver's
open, close, and strategy routines and its queue.

Raw I/O bypasses the cache. A program which reads the disk's raw
device transfers directly between the disk and its own memory
(`physio`, #f("bio.c")). The process is locked in memory while the
transfer runs.

The SD card controller reaches memory by DMA, which does not see the
data cache. So before a transfer the driver writes the buffer's lines
out of the cache (`dcflush`, #f("mch.s")), and after a read it discards
them (`dcinval`), so that the processor sees what the controller wrote.
Discarding is safe only for whole lines of the cache, and the buffers
are aligned on cache lines for that reason (#f("main.c")). QEMU does not
model the cache, so on the QEMU machine the device sees every store,
and none of this is needed.

=== Terminal I/O

A terminal sends and receives characters one at a time, and the
kernel keeps them in character lists (#f("prim.c")): queues built of
small blocks taken from a common pool. Each terminal has three (@fig-tty). The raw
queue holds characters as they arrive. The canonical queue holds
complete lines, after erase and kill have been applied. The output queue
holds characters on their way to the terminal (#f("tty.h")).

#diagram(grid(columns: 7, column-gutter: 3pt, row-gutter: 6pt,
  align: horizon,
  bx[receive interrupt], ar, bx[raw queue], ar, bx[canonical queue], ar, bx[`ttread`],
  bx[transmit interrupt], al, bx[output queue], al, bx[`ttyoutput`], al, bx[`ttwrite`],
), [The three queues of a terminal], pl: bottom) <fig-tty>

When a character arrives, the driver's receive interrupt passes it to
`ttyhold` (#at("/usr/sys/dev/tty.c", "ttyhold(")), which hands it to the line discipline,
`ttyinput`, or keeps it in a hold queue while the raw queue is full.
The line discipline handles the special
characters at once: interrupt and quit send a signal to every process
of the terminal (Signals), and the stop and start characters halt and
resume output. It echoes the character, if echo is on, and puts it in
the raw queue. When a newline arrives, it wakes the processes reading
from the terminal.

A reading process gets its input from `ttread` (#at("/usr/sys/dev/tty.c", "ttread(")). In the
normal mode it waits for a complete line, applies erase and kill as it
moves the line to the canonical queue (`canon`), and returns at most
one line. In raw mode it returns characters as they come, without
interpretation. The system calls `stty` and `gtty` set the mode and the special
characters (#f("sgtty.h")).

The special characters are set by `stty`, and start as @tab-tty
shows (#f("tty.h")).

#btable(columns: (auto, auto, 1fr), align: left, caption: [The terminal's special characters],
  table.header(top, [*character*], [*default*], [*effect*], mid),
  [erase], [`#`], [deletes the last character of the line],
  [kill], [`@`], [deletes the whole line],
  [end of file], [control-D], [ends the line without a newline; at its start, a read returns 0],
  [interrupt], [DEL], [sends `SIGINT` to the terminal's processes],
  [quit], [control-backslash], [sends `SIGQUIT`],
  [stop, start], [control-S, control-Q], [halt and resume output],
  bot,
) <tab-tty>

A writing process's output goes to the output queue through `ttwrite`
and `ttyoutput`, which expands tabs and turns a newline into a carriage
return and a line feed where the terminal needs it. The driver's start
routine sends characters from the queue. Each transmitter interrupt
sends the next. When the queue holds more than a high water mark, the
writer sleeps until it drains below a low one, so a fast program
cannot fill all of memory with output.

Each terminal is described by a `tty` structure (#f("tty.h")), which
the driver owns and the line discipline uses. It holds the queues, the
mode set by `stty` (`t_flags`), the erase and kill characters, the
terminal's process group (`t_pgrp`), and the column which the output
has reached, which tab expansion needs (`t_col`). It also holds the
driver's start routine (`t_oproc`), through which `tty.c` asks the
driver for more output without knowing which device it is.

Each machine has one console driver: the PL011 UART on the QEMU machine
(#f("pl011.c")), and the USB serial device on the MP135 machine
(#f("otg.c")). The UART sends and receives one character at a time,
with an interrupt for each. The USB device moves packets: the driver
gathers output characters into a packet and sends it to the host, and
hands each character of an arriving packet to the line discipline. Both
present the same interface to `tty.c`. The kernel's own messages,
`printf` and `panic`, bypass the queues and write to the console
directly, by `putchar`, so that they work even when interrupts are
off.

A terminal belongs to a process group. The first terminal a process
opens, when it has none, becomes its controlling terminal. Its
signals go to every process which shares it, which is how an interrupt
typed at the keyboard stops the whole of a pipeline.

=== Multiprocessing <sec-mp>

Both machines have one processor, and the kernel relies on it. At any
moment at most one process runs in the kernel, and it keeps the
processor until it sleeps or returns to user mode. A process in the
kernel is never preempted. Only an interrupt can run in between, and
the kernel guards against interrupts by masking them. These two facts
are the kernel's whole means of mutual exclusion. A second processor
would break both, in the places which @tab-mp lists.

#btable(columns: (auto, 1fr, 1fr), align: left, caption: [What the kernel assumes of one processor], pl: bottom,
  table.header(top, [*assumption*], [*where*], [*with two processors*], mid),
  [masking excludes], [character lists, buffers, callouts, run queue], [a spin lock for each],
  [no preemption], [free entries of the tables], [a lock around each search],
  [flag locks], [`ILOCK`, `B_BUSY`], [an indivisible test and set],
  [one current process], [`u` at `UBASE`, `kl3u`], [a u-area mapping for each processor],
  [one scheduler], [`runrun`, `curpri`, the run queue], [scheduling under a lock],
  [local maintenance], [TLB and caches], [operations broadcast to all],
  bot,
) <tab-mp>

Code which changes a list that an interrupt routine also changes masks
interrupts around the change, with `intr_disable` and `intr_restore`
(#at("/usr/sys/conf/mch.s", "intr_restore:")). The character lists (#at("/usr/sys/sys/prim.c", "getc(register struct clist *p)")), the buffer lists
(#at("/usr/sys/dev/bio.c", "getblk(dev_t dev, daddr_t blkno)")), the callout table (#at("/usr/sys/sys/clock.c", "timeout(void (*fun)")), and the run queue
(#at("/usr/sys/sys/slp.c", "setrq(struct proc *p)")) are all guarded this way. Masking holds off the
interrupts of the processor that masks them, and nothing else. A
second processor could change the same list at the same moment.

Code which needs no protection from interrupts needs none at all,
because no other process runs until this one sleeps. When `falloc`
(#at("/usr/sys/sys/fio.c", "falloc(void)")) finds a free entry in the file table, the entry stays
free until `falloc` takes it. The same holds when `iget` (#at("/usr/sys/sys/iget.c", "iget(dev_t dev, ino_t ino)")) takes
a free inode and `malloc` (#f("malloc.c")) a piece of the core map. On
two processors, two processes could find the same free entry and both
take it.

Where a lock must last across a sleep, the kernel uses a flag. An inode
is locked by its `ILOCK` bit, and a buffer by `B_BUSY`. The routine
`plock` (#at("/usr/sys/sys/pipe.c", "plock(register struct inode *ip)")) shows the pattern. It sleeps while the flag is set,
and then sets it. The test and the set are two steps, and the lock
holds only because no other process runs between them. On a
multiprocessor they must be one indivisible operation, such as the
ARM's `ldrex` and `strex` provide.

The current process is a single thing. Its u-area always lies at
`UBASE`, and the kernel reaches it as `u` (see _The Address Space_,
page #pageref(<sec-addr>)). Two processors would run two processes at once,
each with its own u-area at `UBASE`, and so each with its own `kl3u`.
The scheduler's state is single too. The flags `runrun` and `curpri`
and the run queue (#f("slp.c")) describe one processor, and `swtch`
chooses a process on the assumption that no other processor is
choosing.

The routines which discard translations and maintain the caches
(#f("mch.s")) act on the processor which runs them. A second processor
would keep its own stale translations and cache lines unless the
operations were broadcast to it.
