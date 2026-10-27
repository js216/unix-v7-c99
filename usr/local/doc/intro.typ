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
#show figure.caption: set align(left)

== Introduction <ch-intro>

This book describes Unix v7 ported to run on these two machines:

*The QEMU machine* is the `virt` machine of the QEMU emulator, configured with a single ARM Cortex-A7 processor and 512~MB of
RAM at address 0X40000000, an ARM Generic Interrupt Controller (GIC)
version 2 at 0X08000000, the ARM generic timer, an ARM PL011 UART at
0X09000000 as the console, and, as the disk, a virtio block device,
found among the virtio "MMIO" slots at 0X0A000000. QEMU loads the
kernel into RAM itself and starts it at its entry point.

*The MP135 machine* is Seeed Studio's Odyssey-STM32MP135D, a small
board built around STMicroelectronics' STM32MP135D system-on-chip. The chip
contains one ARM Cortex-A7 processor and 168~KB of on-chip RAM. Of
this, 128~KB is the system RAM (SYSRAM) at 0X2FFE0000, which holds the
kernel, and 32~KB in three banks, SRAM1--3, follows it. (The port uses neither SRAM1--3 nor the 8~KB of backup SRAM.) The board adds 512~MB of DDR3L
memory, at 0XC0000000, and an SD card slot. The console is one of the
chip's serial ports, USART2 at 0X4C001000, whose pins the board brings
out on its 40-pin header. The "disk" is the SD card, on the SDMMC1 controller at
0X58005000, and the interrupt controller is again a GIC version 2, at
0XA0021000. The kernel also uses the chip's reset and clock controller
(RCC), its power controller (PWR), its general purpose pins (GPIO), its
DDR controller, its TrustZone address space controller (TZC), which
guards the DDR memory, its TrustZone protection controller (ETZPC), which
decides which world (secure or non-secure) may use each peripheral and SYSRAM, its independent watchdog (IWDG2), and, over the chip's I2C4 bus, the board's
STPMIC1 power management chip. The boot ROM loads the kernel
from the SD card into SYSRAM and starts it in the secure world.

One kernel source serves both machines. The dozen lines which differ
are collected in each machine's header (#f("qemu/mach.h"),
#f("mp135/mach.h")), included in the configuration of device tables and
the memory map (#f("c.c")).

=== The ARM Processor <sec-arm>

The Cortex-A7 implements the ARMv7-A architecture. It has sixteen
32-bit registers, `r0` to `r15`. Three have a special use and a second name:

- `r13` is the stack pointer `sp`,
- `r14` is the link register `lr`, which receives the return address
  of a function call, and
- `r15` is the program counter `pc`.

The current program status register `cpsr` (@fig-cpsr) holds the
condition flags `N`, `Z`, `C`, and `V`, for negative, zero, carry, and
overflow (set by arithmetic instructions). It also holds two interrupt masks,
`I` for ordinary interrupts (IRQ) and `F` for fast ones (FIQ), and the
processor mode in its low five bits.

#diagram({
  let small(t) = text(size: 7pt, t)
  let num(t) = text(size: 5.5pt, str(t))
  let fld(lo, hi, body, used: false) = stack(dir: ttb, spacing: 2pt,
    if lo == hi { align(center, num(hi)) } else {
      pad(x: 1.5pt, grid(columns: (1fr, 1fr), align(left, num(hi)), align(right, num(lo)))) },
    rect(width: 100%, inset: (x: 0pt, y: 4pt), stroke: 0.6pt,
      fill: if used { none } else { luma(220) }, align(center, small(body))))
  grid(columns: (1fr,) * 5 + (2fr, 1fr, 4fr, 4fr, 6fr) + (1fr,) * 5 + (5fr,),
    fld(31, 31, used: true)[`N`], fld(30, 30, used: true)[`Z`],
    fld(29, 29, used: true)[`C`], fld(28, 28, used: true)[`V`],
    fld(27, 27)[`Q`], fld(25, 26)[`IT`], fld(24, 24)[`J`], fld(20, 23)[--],
    fld(16, 19)[`GE`], fld(10, 15)[`IT`], fld(9, 9)[`E`], fld(8, 8)[`A`],
    fld(7, 7, used: true)[`I`], fld(6, 6, used: true)[`F`], fld(5, 5)[`T`],
    fld(0, 4, used: true)[`M`],
  )
}, [The current program status register `cpsr`: the condition flags, the
interrupt masks `I` and `F`, and the mode `M`. The port does not use the
other fields, shaded: `Q`, the sticky saturation flag, `IT`, the state of a
Thumb if-then block, `J` and `T`, which select the Jazelle and Thumb
instruction sets, `GE`, the flags of the SIMD instructions, `E`, the
order of bytes in data, and `A`, the mask of asynchronous aborts. Bits
20 to 23 are reserved.]) <fig-cpsr>

_Processor Modes._ The mode decides what a program may do. User programs run in user mode
(USR, mode bits `10000`), which can reach neither the kernel's memory
nor the system control registers. The kernel runs in supervisor mode (SVC, `10011`). Each kind
of exception has a mode of its own:

- IRQ (`10010`) for interrupts,
- abort (ABT, `10111`) for memory faults, and
- undefined (UND, `11011`) for an instruction the processor does not
  know.

When an exception
occurs, the processor puts the return address in the new mode's `lr`
and the interrupted `cpsr` in the new mode's saved status register
`spsr`. It then sets the mode bits of `cpsr` to the exception's mode,
masks IRQ by setting `I`, and jumps to that exception's entry in the
vector table (@tab-vectors). The vector base register `VBAR` (#at("/usr/sys/conf/low.s", "mcr p15, 0, r0, c12, c0, 0")) is used to tell the processor where the vector block is located.

_Banked Registers._ Each of these modes has its own copy of `sp` and `lr`, called banked
registers (@tab-regs), and its own `spsr`. The other registers, `r0`
to `r12`, are shared by all modes, except the fast interrupt mode (FIQ,
`10001`, not used in this Unix port). Exception entry does not change
the interrupted program's `sp` and `lr`. It changes only which banked
copy is visible.

_Exception Entry._ The exception handler must save `r0` to `r12` itself before it uses
them, to maintain the illusion that the user program is the only one
running. Each exception handler in #f("low.s") first stores its own mode's `lr`, the
return address, and `spsr`, the interrupted status, on the kernel
stack, with the instruction `srsdb` ("store return state, decrement
before"). The special store instruction
`stmia sp, {r0-r14}^`
(#at("/usr/sys/conf/low.s", "stmia sp, {r0-r14}^", after: "svc_entry:")) is used to save the user's registers on the
kernel stack, below what `srsdb` has stored there (in the layout of
#f("reg.h")).

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

#btable(columns: (auto, auto, auto, 1fr), align: (center, left, left, left), caption: [The exception vectors],
  table.header(top, [*Offset*], [*Exception*], [*Mode*], [*The kernel's handler*], mid),
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

_Coprocessors._ The ARM architecture lets a processor be extended by up to sixteen
"coprocessors", numbered 0 to 15, which are specialized interfaces to configure the processor extensions and system control. The floating-point unit is coprocessors 10 and 11. Number
15, the system control coprocessor, is the processor's own control
interface, built into the core, and holds the system control registers.
A system control register is reached only by the instructions `mrc`,
which reads it into a general register, and `mcr`, which writes it, or
`mrrc` and `mcrr` for a 64-bit register and a pair of general
registers.

_Control Registers._ The port uses `SCTLR`, of which it uses the bits
that turn the MMU and the caches on and off
(#at("/usr/sys/conf/low.s", "mcr p15, 0, r0, c1, c0, 0", after: "mcrr p15, 1, r5, r2, c2")); `TTBR0`, `TTBR1`,
`TTBCR`, and `MAIR0`, which describe the translation tables and the
kinds of memory (#atr("/usr/sys/conf/low.s", "mcr p15, 0, r0, c10, c2, 0", "mcrr p15, 1, r5, r2, c2"),
and Translation Tables, page #pageref(<sec-tables>));
`VBAR`, to give the address of the vector table
(#at("/usr/sys/conf/low.s", "mcr p15, 0, r0, c12, c0, 0")); `DFAR` and `DFSR`,
which give the address and cause of a data abort
(#ats("/usr/sys/conf/mch.s", "mrc p15, 0, r0, c6, c0, 0", "mrc p15, 0, r0, c5, c0, 0")); `CPACR`, which lets
programs use the floating-point unit (#at("/usr/sys/conf/low.s", "mcr p15, 0, r0, c1, c0, 2")); the registers of the
generic timer, `CNTFRQ`, `CNTVCT`, `CNTV_CVAL`, and `CNTV_CTL`
(#atr("/usr/sys/conf/mch.s", "mrc p15, 0, r0, c14, c0, 0", "mcr p15, 0, r0, c14, c3, 1")).

_Cache and TLB Maintenance._ The maintenance operations are writes to
registers of their own: `TLBIMVAA`, `TLBIALL`, and `TLBIASID` for the TLB
(#ats("/usr/sys/conf/mch.s", "1:\tmcr p15, 0, r3, c8, c7, 3", "mcr p15, 0, r0, c8, c7, 0", "mcr p15, 0, r1, c8, c7, 2")), `ICIALLU` and `BPIALL` for the instruction
cache and the branch predictor (#at("/usr/sys/conf/mch.s", "mcr p15, 0, r0, c7, c5, 0")), and `DCISW`, `DCIMVAC`,
`DCCIMVAC`, and `DCCMVAU` for the data cache
(#at("/usr/sys/conf/low.s", "mcr p15, 0, r9, c7, c6, 2"), and #ats("/usr/sys/conf/mch.s", "1:\tmcr p15, 0, r0, c7, c6, 1",
"1:\tmcr p15, 0, r0, c7, c14, 1", "1:\tmcr p15, 0, r0, c7, c11, 1")).

_Calling Convention._ A function call follows a fixed convention for the registers: the first
four arguments travel in `r0` to `r3`, and any further ones on the
stack; the result returns in `r0`. A called function may change
`r0` to `r3`, `r12`, `lr`, and the condition flags of `cpsr`, but must
preserve `r4` to `r11` and `sp`. It returns to the address in `lr`,
either directly, with `bx lr`, or, if it calls other functions, by
loading the `lr` it saved into `pc` as it restores the other registers
from the call stack. (The `spsr` is not a part of the convention.
Compiled code never reads or writes it, and only the exception entries
and exits of #f("low.s") do.)

_Memory Order._ The processor does not necessarily perform memory accesses one at a
time in program order. The Cortex-A7 issues its instructions in order,
but its load-store unit, which carries out every access to memory, need
not complete them in order. A store waits in a _store buffer_ before it
reaches the data cache, and loads may overtake it. The processor,
however, is not the only entity to access the memory. Other devices,
such as the MMU, may not see the stores yet. In order to restore the
order, the barrier `dmb` orders the accesses before it before those after it, and `dsb` waits
until they have all completed. An `isb` makes the processor fetch the
following instructions afresh, so that a change to a system register
takes effect.

=== The Boot Process

QEMU loads the kernel into RAM and starts it, and on the MP135 machine
the boot ROM loads it into SYSRAM. Either way the kernel starts at
`_start` (#at("/usr/sys/conf/low.s", "_start:")), in SVC mode, at its physical address, with the
MMU off. From there the system comes up in these steps:

#[#set enum(numbering: "1.a.")
+ First `_start` masks interrupts, turns off the MMU and the caches,
  discards the contents of the TLB, the caches, and the branch
  predictor, and clears the kernel's `bss`. It builds the boot tables, which map the
  kernel at its _kernel address_, the virtual address at which it is
  linked to run (The Address Space, page #pageref(<sec-addr>)), and
  also at its physical address, by an _identity mapping_, so that the
  code goes on running when the MMU is turned on. It turns the MMU on,
  jumps to the kernel address, sets up a small boot stack, installs the
  exception vectors, enables the floating point unit, and calls
  `machine_init`.
+ Then `machine_init` (#at("/usr/sys/sys/machdep.c", "machine_init(")) maps the device registers and starts the console,
  so that `printf` and `panic` work from then on. On the MP135 machine
  it then powers the DDR memory and starts its controller, and leaves
  the secure world, making SYSRAM and the devices non-secure first
  (#f("etzpc.c")). Only then does it map the rest of RAM. Then
  it maps the u-area of process 0,
  removes the identity mapping, and returns the top of that u-area to
  `_start`, as the stack for `main`.
+ Back in `_start`, the stack pointer is moved to the top of the
  u-area, and `main` is called (#at("/usr/sys/sys/main.c", "main(")). The `user` structure lies at
  the bottom of the u-area, and the kernel stack grows down from its
  top towards it. From then on the kernel runs on the kernel stack in
  the current process's u-area. Each process has a kernel stack of its
  own there, apart from the stack of its user program.
+ Next `main` calls `startup` (#at("/usr/sys/sys/machdep.c", "startup(")), which
  sets aside physical pages for the processes' translation tables, 32 bytes of
  first-level table for each process in `l1tab`, then `NPTAB` pages in
  `ptmap` (#at("/usr/sys/sys/machdep.c", "mfree(ptmap, NPTAB, i);")), from which each process's tables of the second and third
  levels are allocated. It puts every other free page of RAM on the
  stack of free pages, and enters the swap area in the swap map. The running code
  becomes process 0 (#at("/usr/sys/sys/main.c", "proc[0].p_addr = btop(corebase);")).
+ Next `clkstart` (#at("/usr/sys/sys/machdep.c", "clkstart(")) programs the timer, and `intrstart`
  (#at("/usr/sys/sys/machdep.c", "intrstart(")) enables the interrupts and unmasks them. Then `main` initialises the character
  lists, the small blocks in which a terminal's input and output wait
  (Terminal I/O, page #pageref(<sec-tty>)), and the buffer cache (Disk
  I/O, page #pageref(<sec-disk>)), reads the super-block of the root
  file system, and sets the root directory to be the current directory.
+ Next `main` calls `newproc` (#at("/usr/sys/sys/slp.c", "newproc(")) to make process 1 as a copy of
  process 0, and `newproc` returns in _both_ of them.
  + In process 0, `newproc` returns 0, and `main` calls `sched`, in
    which process 0 stays forever as the swapper (Scheduling and
    Swapping, page #pageref(<sec-sched>)).
  + In process 1, `newproc` returns 1. Then `main` gives the new
    process a page of user memory, copies into it `icode` (a few
    instructions of machine code, #at("/usr/sys/sys/machdep.c", "int\ticode[] =")), and returns from
    `main`. The return reaches `_start` again, which enters user mode at
    address 0, where `main` copied `icode`, in process 1.
+ The program `icode` makes one system call, `exec("/etc/init")`.
  From here the `init` process is an ordinary process running an
  ordinary program.
]

The first program, `init` (#f("cmd/init.c")), starts a shell on the
console, in single-user mode. When that shell exits, `init` runs the
start-up script `/etc/rc`, which starts `update` and `cron`
(#f("cmd/update.c"), #f("cmd/cron.c")), and then starts a `getty`
(#f("cmd/getty.c")) on each terminal listed in `/etc/ttys`, which waits
for a user to log in. Its process number is always 1, and it is the
parent of every login shell, through `getty` and `login`. Every
process whose parent exits is given to `init` as its child, and `init`
waits for them all. Nothing in the kernel stops `init` from dying, and
no panic follows if it does. But then nothing collects the exit status
of an orphan, which stays in the process table as a zombie, and no
`getty` is started again, so once the last login shell exits, no one
can log in.

During the boot, what the MMU maps changes three times.

- With `_start`'s MMU off, nothing is mapped, and every address is
  physical.
- With `_start`'s MMU on, the kernel image is mapped at its kernel
  address, and the same memory at its physical address (the identity
  mapping, `bootl1`).
- After `machine_init`, all of RAM and the devices are mapped, and the
  u-area of process 0 at `UBASE`. The identity mapping is gone.
- After `newproc`, process 1's own tables are added, with one page of
  user memory holding `icode`.

=== The Address Space <sec-addr>

The user's address space is the lower three gigabytes, while the
kernel occupies the top one. User mode cannot touch the kernel's
gigabyte, because every entry of the kernel's translation tables leaves
clear the bit (`AP[1]`) which allows access from user mode, and the MMU
faults any access from user mode which an entry does not allow
(`BLK_KERN`, #f("seg.h")).

#btable(columns: (auto, 1fr, 1fr), caption: [The address space], pl: std.top,
  table.header(top, [*Virtual address*], [*QEMU machine*], [*MP135 machine*], mid),
  [0x00000000], table.cell(colspan: 2)[not mapped, except `icode` in process 1],
  [0x00001000], table.cell(colspan: 2)[the signal trampoline],
  [0x00008000], table.cell(colspan: 2)[text],
  [next page], table.cell(colspan: 2)[data and `bss`, growing upward],
  [0xbfffffff], table.cell(colspan: 2)[stack, growing downward],
  [0xc0000000], [RAM 0X40000000--0X401FFFFF: kernel], [SYSRAM 0X2FFE0000: kernel],
  [0xc0200000], [RAM 0X40000000--0X5FFFFFFF: free after the kernel], [DDR 0XC0000000--0XDFFFFFFF: free RAM],
  [0xf0000000], [GIC distributor 0X08000000], [GIC distributor 0XA0021000],
  [0xf0001000], [GIC CPU interface 0X08010000], [GIC CPU interface 0XA0022000],
  [0xf0003000], [UART 0X09000000], [USART2 0X4C001000],
  [0xf0004000], [virtio 0X0A000000], [SDMMC1 0X58005000],
  [0xf0008000], [], [RCC, PWR, GPIO 0X50000000],
  [0xf0013000], [], [IWDG2, DDR controller, PHY 0X5A002000],
  [0xf0016000], [], [TZC, ETZPC 0X5C006000],
  [0xf0018000], [], [I2C4 0X4C005000],
  [0xffe00000], table.cell(colspan: 2)[`u`, the current process's u-area],
  bot,
) <tab-addr>

The kernel's gigabyte maps the 512~MB of RAM at 0xc0200000 on both
machines, so the kernel can
reach any page of memory at a fixed distance from its physical address
(`PGADDR`, #f("seg.h")). The kernel's own text, data, and `bss` lie
where it was linked, starting at 0xc0000000 on both machines. On
the QEMU machine they occupy the start of RAM, which therefore appears
at 0xc0200000 as well. On the MP135 machine
they lie in SYSRAM (#f("mp135/unix.ld")). The kernel's stack is the kernel
stack in the u-area, described below. The device registers follow from
0xf0000000, a page or a few for each device. The devices which both
machines have, the interrupt controller, the console, and the disk,
lie at the same kernel addresses on both. The devices are mapped only in the kernel's gigabyte, so
a user program reaches a device only via #box(`/dev/mem`) or through the
device driver. The file #box(`/dev/mem`) is the memory by physical address, and #box(`/dev/kmem`) the
same by kernel address (#f("mem.c")). Neither is mapped anywhere
itself: the driver finds the kernel address of each offset in the map
of regions (#f("c.c")). A program such
as `ps` or `pstat` (#f("cmd/ps.c"), #f("cmd/pstat.c")) reads the kernel's tables through #box(`/dev/kmem`), at the
addresses which it finds in the symbol table of #box(`/unix`). These are
kernel addresses, so without #box(`/dev/kmem`) the program would have to
know how each machine maps them to physical memory.

At the top of the kernel's gigabyte, at 0xffe00000, lies the u-area of the current process: its `user`
structure (#f("user.h")) and its kernel stack. Every process's u-area
appears at the same virtual address, `UBASE`, so the kernel refers to it simply
as `u`, which the linker script places there (#at("/usr/sys/conf/qemu/unix.ld", "u = 0xFFE00000;")). A process switch simply changes the translation table entry that
determines which process's u-area is mapped there.

Below the text nothing is mapped except the one page of the signal
trampoline, at 0x1000, so a null pointer faults. In the user space,
each segment lies at the address its program was linked for. The text
begins at 0x8000, the GNU linker's default for ARM, which leaves room
below it for the trampoline, and the data on a later page, so that it
can be writable while the text is not. The kernel reaches the current
process's memory with the instructions `ldrt` and `strt`, which load
and store as though from user mode (#f("mch.s")). The MMU then checks
the access against the user's entries, so an address which the user
may not touch faults, as it would in the user's program, instead of
reaching the kernel's memory.

=== Translation Tables <sec-tables>

The MMU translates addresses through tables in memory. The port uses
the long-descriptor format, which allows 64-bit entries, physical
addresses of up to 40 bits, and kinds of memory named through `MAIR0`,
with three levels. An entry of the first level covers 1~GB, of the second 2~MB, and of the third a page
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

For example, a program which reads the byte at address `0x00012345`
makes the MMU take entry 0 of the process's first-level table, which
points to a second-level table. Entry 0 of that points to a third-level
table, and entry `0x12` of that gives the physical page. The byte is
byte `0x345` of that page. An address that the tables do not map, or a store to a read-only page,
raises a data abort (#at("/usr/sys/conf/low.s", "dabort_entry:")). If the address lies just below the
user's stack, the kernel grows the stack (#at("/usr/sys/sys/trap.c", "grow(a) == 0))")) and the instruction runs
again. Otherwise the process is sent the signal `SIGSEG`, which by
default ends it with a core image, a copy of its memory written to the
file `core` in its current directory.

The processor has two table base registers. `TTBR0` translates the
user's three gigabytes and `TTBR1` the kernel's top one, while `TTBCR`
sets the boundary between the two regions (#at("/usr/sys/conf/low.s", "mcr p15, 0, r0, c2, c0, 2")). The kernel's half is described once,
for all processes, and each process has tables of its own for the
lower half (@fig-tree), so that a process switch changes only `TTBR0`.

#diagram(grid(columns: 7, column-gutter: 4pt, row-gutter: 6pt,
  align: horizon,
  bx[`TTBR0`], ar, bx(w: 2.1cm)[first level, one per process], ar,
    bx(w: 2.4cm)[second level], ar, bx(w: 2.1cm)[third level: text, data, and stack pages],
  bx[`TTBR1`], grid.cell(colspan: 3, ar), bx(w: 2.4cm)[`kl2`: 2~MB blocks of RAM], ar,
    bx(w: 2.1cm)[`kl3u`, `kl3d`: the u-area page, the device pages],
), [The user's tables, above, and the kernel's, below]) <fig-tree>

Each process's own tables are built from a _prototype_, a description
of its address space kept in its `user` structure (#at("/usr/sys/h/user.h", "unsigned u_ptstart, u_pdstart;")): where its text and
data begin and how many pages each has, how many pages of stack end at
the top of the user's space, and whether the text may be written. The
text and data come from the program's file. The data segment holds the
program's initialised data, then its `bss`, which `exec` clears to
zeros, and then whatever `sbrk` (#f("sys/sbrk.s"), `sbreak` in #at("/usr/sys/sys/sys1.c", "sbreak(void)")) adds for the heap as the
program grows. The
sizes are recorded into the prototype by `estabur`
(#at("/usr/sys/sys/ureg.c", "estabur(")), and the tables are built from
the recorded values by `sureg` (#at("/usr/sys/sys/ureg.c", "sureg(void)")), which `estabur` calls at once,
and which runs again whenever the process is switched in, building the
tables anew if they were discarded, as when the process is swapped back
in. The text pages are mapped read-only and the data and stack pages
writable, all with user access. The one exception is `exec`, which maps
the text writable while it reads the text in from the file
(#at("/usr/sys/sys/text.c", "estabur(u.u_exdata.ph[0].p_vaddr >> PGSHIFT, ts, 0, 0, 0, RW);")), and read-only again before the program runs. Finally `ttbset` (#at("/usr/sys/conf/mch.s", "ttbset:")) loads `TTBR0` with the address of the process's newly created first-level
table.

=== Interrupt Handling <sec-intr>

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

Each device's interrupt line goes to the Generic Interrupt Controller
(GIC). The GIC passes the most urgent pending interrupt to the processor
as an IRQ. If interrupts are not masked, an interrupt goes through these
steps:

+ The processor lets the instruction it is executing finish, then
  enters IRQ mode, keeping the address of the next instruction in
  `lr_irq` and the interrupted `cpsr` in `spsr_irq`, and jumps to the
  IRQ entry of the vector table (#at("/usr/sys/conf/low.s", "b irq_entry")).
+ Then `irq_entry` (#at("/usr/sys/conf/low.s", "irq_entry:")) pushes the interrupted program's `pc` and `cpsr` onto the
  SVC stack, which is the current process's kernel stack, and changes to
  SVC mode with interrupts masked. It then saves the remaining registers
  on the same stack, and so builds a frame of all the interrupted
  program's registers (#at("/usr/sys/h/reg.h", "#define\tR0\t(0)")). The frame goes on the stack, not in a fixed
  place in the `user` structure, because the kernel itself may be
  interrupted, and a second frame must not overwrite the first.
+ Next `irq_entry` calls `irq` (#at("/usr/sys/sys/machdep.c", "irq(")) with the address of the
  frame.
+ Then `irq` reads the interrupt's number from the GIC, looks it up in
  `intrtab`, in the configuration (#at("/usr/sys/conf/c.c", "struct\tintr\tintrtab[] =")),
  and calls the routine found there with the interrupted program counter
  and status.
+ Then `irq` tells the GIC that the interrupt is done, so that the GIC will
  deliver another.
+ If the interrupt came from user mode and a process of better priority
  is now ready to run (`runrun`), `irq_entry` calls `user_trap_handler`
  (#f("trap.c")), which switches processes, as at the end of every trap.
+ Finally `irq_entry` unloads the frame, and the interrupted program continues
  where it stopped.

For example, when a key is pressed at the QEMU machine's console, the
UART interrupts. Then `irq` finds the UART's number in `intrtab` and calls
`klintr` (#at("/usr/sys/dev/pl011.c", "klintr(")), which reads the character and passes it to the
terminal code. That code wakes the process waiting for
the line, which will run when the scheduler chooses it.

The timer's routine is `clock` (#at("/usr/sys/sys/clock.c", "clock(")), which runs sixty times a
second. It sets the timer's next deadline, calls the routines which drivers
have asked, with `timeout`, to be called at this tick, charges the tick to the current process, and once a second
recomputes the priorities of all processes and wakes the swapper.

A driver that must act after a delay, such as the terminal code
waiting out a carriage return, calls `timeout` (#at("/usr/sys/sys/clock.c", "timeout(")) with a
routine, an argument, and a number of ticks. The timeouts are kept in
the table `callout`, sorted by time, each entry holding the ticks
after the one before it. So `clock` need only count down the first
entry, and calls each routine whose count reaches zero.

=== System Calls <sec-syscalls>

A program makes a system call through a routine of the C library, such
as `read` (#at("/usr/src/libc/sys/read.s", "read:")). The call goes through these steps:

+ The library routine puts the number of the call in register `r12`
  (which the assembler also names `ip`) and jumps to `cerror`
  (#at("/usr/src/libc/syscall.s", "cerror:")). The call's arguments are already in `r0` to `r3`, where C
  put them, and `r12` is the one register which a function may change
  without saving that is not an argument. Every library routine jumps
  to the same `cerror`, so that the `svc` and the test of its result
  exist only once. (In v7 each routine made the trap itself and jumped to
  `cerror` only on an error, hence the name.)
+ Then `cerror` saves `r7`, which a function must preserve, moves the
  number to `r7`, and executes `svc #0`. The kernel takes the number in
  `r7`, as Linux on the ARM does, which leaves `r0` to `r6` for
  arguments. The `svc`
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
+ Next `trap` delivers any pending signal (Signals, page #pageref(<sec-signals>)), recomputes the process's
  priority, and gives up the processor if a better process is ready
  (Scheduling and Swapping, page #pageref(<sec-sched>)).
+ Back in `svc_entry`, interrupts are masked while the frame is unloaded, so that the user's
  registers receive the results, and the return to the instruction after
  the `svc` restores the user's saved status, in which interrupts are
  unmasked.
+ Finally `cerror` tests the carry flag. If it is clear, it returns the result.
  If it is set, it stores the error number in `errno` and returns -1.

For example, `read(fd, buf, n)` arrives with the file descriptor in
`r0`, the buffer's address in `r1`, and the count in `r2`, and with 3,
the number of `read`, in `r7`. Entry 3 of `sysent` says three arguments
and the routine `read` (#at("/usr/sys/sys/sys2.c", "read(")). When it returns, the saved `r0`
holds the number of bytes read, and the carry flag is clear. If `fd`
was not open, the saved `r0` holds `EBADF` instead, the carry flag is
set, and the library returns -1 with `errno` set to `EBADF`. The carry
flag is needed because `r0` alone cannot tell them apart: `EBADF` is 9,
and so is a count of nine bytes read. The table has 64~entries, and `trap` takes the call's number
modulo 64, so that no number, however large, indexes beyond the table. Unused entries hold `nosys` (#at("/usr/sys/sys/trap.c", "nosys(")), which fails the
call with `EINVAL`.

The frame's address is kept by `trap` in `u.u_ar0`, through which a
system call can reach the user's registers. The routines take no
arguments of their own, and find them in `u.u_arg`.

A system call may sleep, waiting for a key to be pressed, say. If a signal arrives meanwhile, the sleep is abandoned: `sleep`
(#f("slp.c")) returns, through `resume` (#at("/usr/sys/conf/mch.s", "resume:")), to the point which `trap`
recorded in `u.u_qsav` before it called the routine, and the call fails
with the error `EINTR`.

=== Scheduling and Swapping <sec-sched>

A process waits by calling `sleep` (#at("/usr/sys/sys/slp.c", "sleep(caddr_t")) with an address, the
event it waits for, and a priority (@tab-pri). Then `sleep` marks the process asleep
and calls `swtch` to run another. The process that later causes the
event, or an interrupt routine, calls `wakeup` with the same address,
which makes every process sleeping on it runnable, and each must
check, when it runs again, that what it waited for is still there.

The routine `swtch` (#at("/usr/sys/sys/slp.c", "swtch(void)")) decides which process runs (@fig-states). It searches the runnable processes
in memory for the one of best priority, and switches to it. If there is
none, it calls `idle` (#at("/usr/sys/conf/mch.s", "idle:")), which halts the processor waiting for an
interrupt, and searches again. A process's priority depends on its
recent use of the processor, which `clock` (#at("/usr/sys/sys/clock.c", "clock(")) counts and
decays once a second, and on its `nice` value (`setpri`). A process that has waited on an
event gets the better priority given in the call of `sleep`. The priority given to `sleep` says how urgently the process must run
once the event has happened. Lower numbers are better (@tab-pri;
#at("/usr/sys/h/param.h", "#define\tPSWP\t0"), #at("/usr/sys/h/tty.h", "#define\tTTIPRI\t28")).

A user process's priority is `PUSER`, plus its recent use of the
processor divided by 16, plus its `nice` value (`setpri`, #at("/usr/sys/sys/slp.c", "setpri(register struct proc *pp)")).
The use, `p_cpu`, grows by one each tick the process runs, and once a
second `clock` multiplies it by 0.8.

#diagram(grid(columns: 5, column-gutter: 4pt, row-gutter: 4pt,
  align: center + horizon,
  bx(w: 1.7cm)[ready], [#lab[`swtch`] #ar], bx(w: 1.7cm)[running], [#lab[`sleep`] #ar], bx(w: 1.7cm)[asleep],
  grid.cell(colspan: 5)[#al #lab[`wakeup` makes it ready again] #al],
  [#lab[`sched`] $arrow.t.b$], [], [#ad #lab[`exit`]], [], [],
  bx(w: 1.7cm)[swapped out], [], bx(w: 1.7cm)[zombie], [], [],
), [The states of a process]) <fig-states>

The switch itself is done by `save` and `resume` (#at("/usr/sys/conf/mch.s", "resume:")). The first, `save`,
records the registers a function must preserve, the stack pointer, and
the return address, in the current u-area. The second, `resume`, maps
another
process's u-area at `UBASE`, and reloads the registers that process
saved there when it last ran. The new process then continues in
`swtch`, returning from it into whatever had called `swtch`. Since the
u-area holds the kernel stack, mapping a different one changes the
whole kernel state of the process at once.

A process gives up the processor in two ways. It sleeps, waiting for
an event. Or it is preempted: the flag `runrun` is set when a process
of better priority becomes runnable, and once a second by `clock`. The
kernel tests the flag only on the way back to user mode, after a trap,
a system call, or an interrupt from user mode. So a process running in
the kernel is never preempted. It keeps the processor until it sleeps
or returns to user mode. That is why the kernel needs no locks against
other processes, only masked interrupts against interrupt routines.

#btable(columns: (auto, auto, 1fr), align: left, caption: [Sleep priorities],
  table.header(top, [*Name*], [*Value*], [*Waiting for*], mid),
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
parent's open files, current directory, and text. Then the parent's image, its
u-area, data, and stack, is copied: into free memory if there is room,
or else to the swap area, from which the swapper will bring the child
in. In the parent `newproc` returns 0, and in the child 1. The system call `fork` and its library routine (#f("sys/fork.s")) turn
the two returns into the child's process number in the parent and 0 in
the child.

A process's image is a list of pages (@tab-image): the u-area, then
the data, then the stack. The pages may lie anywhere in physical
memory. The u-area's page is `p_addr`, and the process's page map lists
the others in order (#f("malloc.c")). The text is a separate list, shared by every
process running the same program (`xalloc`, #f("text.c")). Memory is
handed out a page at a time, from a stack of the free pages (`pgalloc`).

#btable(columns: (auto, 1fr, 1fr), caption: [A process's image in RAM, and where each part is seen],
  table.header(top, [*Part*], [*In RAM*], [*Seen at*], mid),
  [u-area], [one page, `p_addr`], [`UBASE`, by the kernel only],
  [data], [the first pages of the page map], [the page after the text],
  [stack], [the rest of the page map], [just below 0xc0000000],
    [text], [the pages of its own map, shared], [0x8000],
  [trampoline], [one page, shared by all], [0x1000],
  bot,
) <tab-image>

The program a process runs can be replaced by `exec` (#at("/usr/sys/sys/sys1.c", "exec(")). It reads
the program's ELF headers and copies the arguments and
the environment to two pages of core, since the old
image, which holds them, is about to go. It then releases the old text,
and finds the new one in the text table if another process is running
the same program, or reads it in from the file. It grows or shrinks
the image to the sizes the headers give, reads in the data, clears the
`bss`, and builds the new stack with the arguments on it. Finally it
sets the program counter to the program's entry point, and resets the
signals the old program had caught.

A process changes its size in two ways. A call of `brk` asks for more or less
data in the heap, and the stack grows when a program touches an address just below
it. The data abort handler (#f("trap.c")) sees such a fault and calls
`grow` (#at("/usr/sys/sys/sig.c", "grow(")), and the faulting instruction is executed again. Both
use `expand` (#at("/usr/sys/sys/slp.c", "expand(")), which adds pages at the end of the image or takes them away, without
copying the image, or swaps the process out if no page is free,
and `estabur` (#at("/usr/sys/sys/ureg.c", "estabur(")), which records the new sizes for the
tables. Turning entries of the page map around then moves the stack
past the pages added or taken away (`maprot`, #f("malloc.c")).

A process ends with `exit` (#at("/usr/sys/sys/sys1.c", "exit(int")). It closes its files,
releases its text and its memory, and becomes a zombie, which keeps
only its process table entry, with its exit status and times, until
its parent collects them with `wait`. A process whose parent dies is
given to process 1, `init`, which waits for it in turn. It goes to
`init` rather than to its grandparent, which never asked for it and
may never wait for it.

=== Signals <sec-signals>

A signal is an event sent to a process, such as a key like interrupt or
quit at its terminal, a fault in its program, an alarm, or a `kill`
from another process. The kernel posts it with `psignal`
(#at("/usr/sys/sys/sig.c", "psignal(register struct proc *p, register int sig)")), which sets a bit in the process's table entry and, if
the process sleeps at an interruptible priority, wakes it.

#btable(columns: (auto, auto, 1fr, auto), align: left, caption: [The signals],
  table.header(top, [*No.*], [*Name*], [*Sent when*], [*Default*], mid),
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
  table.header(top, [*What*], [*Saved by*], [*Kept in*], [*Restored by*], mid),
  [user registers at entry], [every trap and interrupt (#f("low.s"))], [frame on the kernel stack], [the common return (#f("low.s"))],
  [kernel registers at a switch], [`save` in `swtch`], [`u_rsav`], [`resume` in `swtch`],
  [the start of a system call], [`save` in `trap`], [`u_qsav`], [`resume` in `sleep`, on a signal],
  [the point of a copy], [`save` in `newproc`, `expand`, `xexpand`], [`u_ssav`], [`resume` in `swtch`, under `SSWAP`],
  [floating point registers], [`swtch`, `newproc`, `expand`, `psig`], [`u_fps`], [the return to user mode],
  [user registers for a handler], [`sendsig`], [frame on the user stack], [`sigreturn`],
  bot,
) <tab-saved>

Every entry to the kernel from user mode, by a system call, an
interrupt, or a fault, saves all of the user's registers on the kernel
stack in the u-area (#at("/usr/sys/h/reg.h", "#define\tR0\t(0)")). The kernel finds them through
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
process's image was copied, for a new process or to the swap area,
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
switch, `bdevsw` (#f("c.c")), a table which holds each driver's
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

=== Terminal I/O <sec-tty>

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
  table.header(top, [*Character*], [*Default*], [*Effect*], mid),
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

Each machine has one console driver, for the PL011 UART on the QEMU
machine (#f("pl011.c")), and for a USART on the MP135 machine
(#f("usart.c")). Each device sends and receives characters through a
small FIFO, and interrupts when there is room to send or something to
read. Both drivers present the same interface to `tty.c`. The kernel's own messages,
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
  table.header(top, [*Assumption*], [*Where*], [*With two processors*], mid),
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
a free inode and `pgalloc` (#f("malloc.c")) a free page. On
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
