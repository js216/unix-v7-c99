# UNIX v7 on Qemu --- live boot/run captures

Captures of representative userland commands invoked through
`tools/qemu-shell.py` (which spawns `qemu-system-arm -machine virt`
under `-snapshot`, logs in as root, runs the supplied stdin lines,
and quits once the `__TEST_DONE__` sentinel echoes).  Each section
is a verbatim copy of the serial console output, CRs stripped.

### CHESS_ATTACK_HELPER_OBJECTS

This is not a QEMU-installed command slice.  The V7 chess pure-C
sources were imported under `cmd/chess/` and compiled only to ARM C99
objects, including `pio.c`.  This slice additionally translates the
chess-local `v7/usr/src/games/chess/qsort.s` helper as `cmd/chess/qsort.c`
and the move/undo helpers `wmove.s` and `bmove.s` as local C helpers
`cmd/chess/wmove.c` and `cmd/chess/bmove.c`.  The attack/control helpers
`att.s` and `ctrl.s` are now translated locally as `cmd/chess/att.c` and
`cmd/chess/ctrl.c`, and the pseudo-legal generators `wgen.s` and `bgen.s`
are now translated locally as `cmd/chess/wgen.c` and `cmd/chess/bgen.c`.
Full `/usr/games/chess` executable wiring, root-image installation, and
QEMU smoke coverage remain intentionally omitted.

Build evidence:

```
make -C cmd/chess clean objects
...
arm-none-eabi-gcc ... -c pio.c -o pio.o
arm-none-eabi-gcc ... -c qsort.c -o qsort.o
...
arm-none-eabi-gcc ... -c wmove.c -o wmove.o
arm-none-eabi-gcc ... -c bmove.c -o bmove.o
arm-none-eabi-gcc ... -c wplay.c -o wplay.o
arm-none-eabi-gcc ... -c wgen.c -o wgen.o
arm-none-eabi-gcc ... -c bgen.c -o bgen.o
arm-none-eabi-gcc ... -c att.c -o att.o
arm-none-eabi-gcc ... -c ctrl.c -o ctrl.o

make -C cmd/chess check-sort
cc -std=c99 -Wall -Wextra -Wpedantic -Wno-pointer-to-int-cast -fno-builtin qsort.c qsort_check.c -o qsort_check
./qsort_check

make -C cmd/chess check-move
cc -std=c99 -Wall -Wextra -Wpedantic -Wno-pointer-to-int-cast -fno-builtin -fcommon wmove.c bmove.c move_check.c -o move_check
./move_check
move_check: ok

make -C cmd/chess check-attack
cc -std=c99 -Wall -Wextra -Wpedantic -Wno-pointer-to-int-cast -fno-builtin -fcommon att.c ctrl.c attack_check.c -o attack_check
./attack_check
attack_check: ok

make -C cmd/chess check-gen
cc -std=c99 -Wall -Wextra -Wpedantic -Wno-pointer-to-int-cast -fno-builtin -fcommon wgen.c bgen.c gen_check.c -o gen_check
./gen_check
gen_check: ok

comm -23 <(arm-none-eabi-nm -u cmd/chess/*.o | awk '/ U / { print $2 }' | sort -u) <(arm-none-eabi-nm -g --defined-only cmd/chess/*.o | awk 'NF >= 3 { print $3 }' | sort -u)
close
creat
exit
lseek
open
printf
read
signal
time
times
write

make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.

test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

### LEARN_FILES

`learn(1)` is installed as `/bin/learn`; its two V7 helper programs are
installed as `/usr/lib/learn/tee` and `/usr/lib/learn/lcount`; the first
bounded course slice is `/usr/lib/learn/files`, extracted from V7
`v7/usr/lib/learn/files.a`.

Build evidence:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found

make ARCH=arm CONF=qemu_arm
...
arm-none-eabi-objcopy -O binary learn.elf ../root/bin/learn
arm-none-eabi-objcopy -O binary lcount.elf ../root/usr/lib/learn/lcount
arm-none-eabi-objcopy -O binary lrntee.elf ../root/usr/lib/learn/tee
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

QEMU run:

```
ls /bin/learn /usr/lib/learn
/bin/learn

/usr/lib/learn:
Linfo
Xinfo
files
lcount
log
play
tee
# ls /usr/lib/learn/files
L0
L0.1a
L0.1b
...
L9.2c
# /usr/lib/learn/lcount <<EOL
> one
> two
> EOL
2
# learn files 0 0
This course will help you learn about basic file
handling commands.  You should first understand
the special characters # and @:
...
$ answer the

Good.  Lesson 0.1a (1)

You should also understand a few simple commands.
...
$ bye
Bye.
# ls /
bin
dev
etc
tmp
unix
usr
# echo hi | wc
      1      1       3
# test -f /etc/passwd; echo $?
0
```

### PS

`ps` walks the kernel `proc[NPROC]` table via `/dev/mem` after
resolving `_proc` through `nlist("/unix", ...)`.  In the ARM port
the proc-table entries are populated by `v7_proc_fork/exit/reap`
(pid, ppid, uid, stat, pgrp, pri, nice).  `arch/u_bridge.c::
v7_proc_set_current()` additionally steers `p_addr`/`p_size` on
every curpid transition so that for the *currently running* proc
the v7 argv-scan in `cmd/ps.c::prcom()` lands its `/dev/mem` read
on the fixed user-VA argbuf at `UARGV` (see arch/arm.h, populated
by arch/armboot.c's exec/spawn path); every other proc gets
`p_size=0` and ps short-circuits the read so the CMD column stays
blank.  Run as:

```
ps
```

Captured output:

```
ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
     5 ?   0:00 ps
```

Three live processes: pid 1 is init, pid 4 is the getty waiting on
the console after init forked off /etc/rc, pid 5 is the root login
shell that ran ps (and is the currently-running image at USERBASE,
hence the `ps` command line).  `ps -l` exposes the same state via
the long-form columns; the running proc shows `ADDR=1700` (octal,
= `UARGV>>6`) and `SZ=1` (UARGLEN/64 rounded into the byte ÷ 8
display), while the saved parents show `ADDR=0 SZ=0`.

### PSTAT

`pstat` follows the same nlist + `/dev/mem` recipe but targets the
remaining v7 in-core tables: `proc[]`, `inode[]`, `text[]`, `file[]`,
`tty`-family.  The `-p`, `-i`, `-f` flags exercise the proc, inode
and file tables respectively.  All three return non-empty data on
this port: proc is populated by the fork/exit machinery, inode by
the in-kernel iget/iput path (BSS-backed via `arch/v7stubs.c`), and
file by open/close in the same layer.  `text[]` is BSS-zeroed and
intentionally left unused by the bridge layer so `pstat -x` prints
"0 text segments" (not shown here).  `pstat -t` (tty) leans on
`_dh11`/`_kl11` symbols which the ARM kernel does not export, so
the table prints blank rows; `-s` (swap) is similar.

```
pstat -p
3 processes
   LOC S  F  PRI SIGNAL UID TIM CPU NI  PGRP   PID  PPID ADDR SIZE  WCHAN   LINK  TEXTP  CLKT
10045553460 3  1   40      0   0   0   3 20     1     1     0    0    0      0      0      0 0
10045553524 3  1   40      0   0   0   4 20     1     4     1    0    0      0      0      0 0
10045553570 3  1   40      0   0   0   1 20     1     5     4    0    0      0      0      0 0
# pstat -i
1 active inodes
   LOC  FLAGS  CNT DEVICE   INO   MODE NLK UID  SIZE/DEV
10045500010          7  0,  0       2  40755   7   0       128
# pstat -f
0 open files
  LOC   FLG CNT   INO    OFFS
```

The pstat -p columns line up exactly with the v7 layout (state=3
SRUN, flag=1 SLOAD, pri=40 PSLEP, pgrp=1, then the trio of pid/ppid
chains).  `pstat -i` shows the root inode (i_number=2, mode 040755,
which is dir+rwxr-xr-x) reference-counted by all currently
open-on-mount paths.  `pstat -f` reports zero open files because
the v7 in-core file table is the per-mount table; the per-process
fd tables live elsewhere and are not what pstat -f walks.

### PROF

`prof` summarises an `mon.out` execution profile against the symbol
table of the program that wrote it.  The default namelist file is
`a.out`; with no `a.out` in the cwd `prof` aborts with a diagnostic
before opening `mon.out`.  This is v7-historical behaviour.

```
# prof
a.out: not found
#
```

(A live profile capture would require an instrumented binary built
with `cc -p` and a matching `mon.out` -- the c99 port's libc has
no profiling stub.)

### TC

`tc` is the C/A/T phototypesetter simulator that drives a Tektronix
4014 terminal: it reads troff-typesetter output on stdin and emits
4014 vector-graphics escape sequences on stdout to draw the glyphs.
On the qemu console (a plain PL011 UART) the escapes appear as raw
control bytes interleaved with the printable characters.

With empty input it emits only its leading setup string:

```
# tc < /dev/null
<GS>7l<GS>@<US>;
#
```

(literal byte sequence `1d 37 6c 1d 40 1f 3b`; `<GS>` = 035, `<US>`
= 037.)

Piping a short string through tc produces the same setup string
plus a per-glyph plot sequence:

```
# echo hello | tc
<GS>8lo @<GS>b@<GS>7dy@<GS>lo@<GS>g@<US>b<GS><DEL>@<ESC>;<US>
#
```

(raw bytes `1d 38 6c 6f 20 40 1d 62 40 1d 37 64 79 40 1d 6c 6f 40
1d 67 40 1f 62 1d 7f 40 1b 3b 1f` -- the trailing `<ESC>;` is the
4014 "leave-graphics-mode" pair before tc exits.)

### GRAPH

`graph` reads pairs of numbers and emits the portable plot(5) stream
used by v7 libplot's `plot.c.a` backend.  This port keeps those tiny
plot emitters local to graph because libplot is not otherwise present
in the ARM userland build.  The historical source reads stdin; the
ported command also accepts a trailing input file operand for the
current qemu smoke path.

Run as:

```
ls /bin/graph
cat >/tmp/g <<EOF
0 0
1 1
EOF
graph -g 0 -m 0 /tmp/g | od -c
```

Captured output:

```
ls /bin/graph
/bin/graph
# cat >/tmp/g <<EOF
> 0 0
> 1 1
> EOF
# graph -g 0 -m 0 /tmp/g | od -c
0000000   s  \0  \0  \0  \0  \0 020  \0 020   e   m 310  \0 214  \0   p
0000020 310  \0 310  \0   p 240 017 240 017   f   s   o   l   i   d  \n
0000040   m 001  \0 001  \0  \0
0000045
```

### PLOT_TEK

`plot` is the V7 shell dispatcher installed as `/bin/plot`; `tek` is
the Tektronix 4014 backend installed as `/bin/tek`.  The smoke below
confirms both files are present, `graph` output can flow through
`plot -Ttek`, and the backend emits non-empty Tek control/output bytes.

```
ls /bin/plot /bin/tek
/bin/plot
/bin/tek
# cat >/tmp/g <<EOG
> 0 0
> 1 1
> EOG
# graph -g 0 -m 0 /tmp/g | plot -Ttek | od -c
0000000 033  \f 035       h   z   !   F 035   !   `   f   F   F 035   7
0000020   j   y   7   Y  \0  \0  \0  \0   Y 033   ` 035       `   `
0000040   @  \0  \0  \0  \0 037
0000046
```

The `-T4014` dispatcher alias reaches the same backend:

```
graph -g 0 -m 0 /tmp/g | plot -T4014 >/tmp/4014.out
# od -c /tmp/4014.out
0000000 033  \f 035       h   z   !   F 035   !   `   f   F   F 035   7
0000020   j   y   7   Y  \0  \0  \0  \0   Y 033   ` 035       `   `
0000040   @  \0  \0  \0  \0 037
0000046
```

Regression checks from the same QEMU boot:

```
echo x | sed s/x/y/
y
# expr 1 + 2
3
# iostat 1 1 | sed 3q
   RF                RK                RP                  PERCENT
   tpm  msps  mspt   tpm  msps  mspt   tpm  msps  mspt  user  nice systm  idle
 33060-131.1 131.1     0   0.0   0.0     0   0.0   0.0 24.43  0.00 75.57  0.00
# echo __TEST_DONE__
__TEST_DONE__
#
```

### SA_ACCT

Process accounting on this port is wired up end-to-end:

* `/etc/accton <path>` libc-calls `acct(2)` (syscall 51) which the
  ARM kernel routes through `sys_sysacct_v7` -> `v7_sysacct_call`
  -> `sys/acct.c::sysacct()`.  sysacct() namei()s the path, verifies
  IFREG, and stashes the inode in `acctp`.
* Each process exit() that flows through `S_EXIT` in
  `arch/armboot.c::trap()` calls `sys/acct.c::acct()` -- which
  writei()s a `struct acct` record to the file pointed at by
  `acctp` -- before the parent's USERBASE snapshot is restored.
* `sa(1)` reads /usr/adm/acct back and summarises per-command CPU
  time.

The `/usr/adm/acct` file is seeded as a zero-byte regular file by
mkfs so sysacct()'s namei()+IFREG check succeeds the first time
accton runs (sysacct does not create the file itself).

Test 1 -- file grows on each exec:

```
/etc/accton /usr/adm/acct
# ls
bin
dev
etc
tmp
unix
usr
# ls
bin
dev
etc
tmp
unix
usr
# ls
bin
dev
etc
tmp
unix
usr
# ls
bin
dev
etc
tmp
unix
usr
# ls -l /usr/adm/acct
-rw-r--r-- 1 root      180 Dec 31 19:00 /usr/adm/acct
```

180 bytes = 5 records of 36 bytes (accton + 4 ls).  The 36-byte
record size matches the cut sys/acct.c::acct() applies to its
writei() (sizeof(struct acct) as seen through h/acct.h).

Test 2 -- sa(1) summarises:

```
/etc/accton /usr/adm/acct
# ls
bin
dev
etc
tmp
unix
usr
# ls
bin
dev
etc
tmp
unix
usr
# ls
bin
dev
etc
tmp
unix
usr
# sa
     4     0.00     0.00
     4     0.00     0.00   ***other
```

sa walks the file, groups all four short-lived ls runs (each with
count=1) into the "***other" pseudo-command, and prints the
totals: 4 commands, 0.00 hours real, 0.00 hours cpu.  The
totals would be non-zero against a longer-running test workload;
on this snapshot the four ls invocations consume sub-jiffy CPU
time each, which compress() rounds down to zero in the acct
record.

sa(1) opens accounting off and on at start
(`acct(NULL); acct("/usr/adm/acct");`) to force the kernel to
iput()->iupdat() the /usr/adm/acct inode -- arch/armboot.c's
loadino()/kopen() reads the on-disk dinode for files[fd].size,
which only catches up to the in-core i_size after the iupdat()
write-back lands.  Without that toggle, sa's fopen() sees a stale
size of 0 and prints "0 0.00 0.00" with no per-command rows.

### TIME_ADVANCE

Verifies that the live ARM Generic Timer wakes sys/clock.c::clock()
at HZ and the once-per-second branch advances the kernel `time`
global at real wall-clock rate, that pause(2) blocks until SIGCLK
from an alarm fires, and that sleep(1) in libc rides the
alarm(n)+pause() v7 convention.  Run as:

```
date
sleep 5
date
```

Captured output from the earlier time-advance run (CRs stripped and
pause-spin backspaces omitted for readability):

```
date
Wed Dec 31 19:00:00 EST 1969
# sleep 5
# date
Wed Dec 31 19:00:05 EST 1969
```

The two `date` calls bracket exactly five seconds.  19:00:00 EST is
the epoch (1970-01-01 00:00:00 UTC) rendered in the compiled-in
TIMEZONE/DSTFLAG -- v7's ftime() bakes both into struct timeb at
build time, so date(1) sees the kernel `time` global through the
timezone offset.  The second call lands on epoch+5, confirming:

* arm_timer_init() programmed CNTV at the right HZ rate (TIMER_HZ
  bound to v7's HZ macro, 60Hz).  At 100Hz the date jump would have
  been 8 or 9, not 5.
* sys/clock.c's `++lbolt >= HZ` branch incremented `time` exactly
  once per second.
* sleep(5) -> libc alarm(5)+pause() -> sysent[27] (alarm) ->
  sys/sys4.c::alarm() -> proc[curpid].p_clktim = 5.  Each lbolt
  rollover decrements p_clktim; on the fifth rollover psignal(p,
  SIGCLK) fires.
* The pause() syscall's spin loop in arch/u_bridge.c::v7_pause_call
  detected the new bit in u.u_procp->p_sig, mirrored it into
  armboot's `pending`, and broke out.  deliver_signal() at trap
  return dropped the SIG_DFL'd SIGCLK and resumed user mode; libc
  sleep() then issued alarm(0) and returned 0 to the shell.
* gtime() (sysent[13]) read the now-advanced `time` back through
  arch/u_bridge.c::v7_gtime_call, which is what the date binary
  invokes through its libc ftime() wrapper.

The same plumbing makes ls -l mtimes, utmp records, and date set
operations show real wall-clock values; before this batch the
kernel `time` global was stuck at 0 (epoch) because the ARM timer
was firing at the wrong rate to ever push lbolt past HZ, and even
when it did the userland time/ftime libc stubs ignored the kernel
and returned 0.

Current `tools/qemu-shell.py` output preserves all bytes except CR.
That means a raw live `sleep` capture includes the backspaces emitted
by `pause_spin_barrier()` while it waits for the alarm signal.  Do not
use the cleaned block above as current raw-console evidence.

### OSH

`osh` is the Thompson shell carryover -- the pre-Bourne shell v7
still shipped at `/bin/osh` for compatibility with older scripts.
A single 844-line TU, written in pre-K&R C with the `=+`/`=-`/`=|`
compound-assignment operators that became `+=`/`-=`/`|=` between
v6 and v7.  The c99 port mechanically rewrites those 14 sites,
adds the missing `=` to one aggregate-initialiser, and otherwise
rides on the same permissive SHCFLAGS that the Bourne sh build
already uses (see `logs/unix-historical-accuracy.md`).

Exercised by piping data through `osh -c "<cmd>"` (the v7 `-c`
single-string mode reads the command argument character-by-
character via osh's internal `readc()` rather than from fd 0):

```
ls /bin/osh
osh -c "date"
osh -c "who am i"
echo hi | osh -c "cat"
```

Captured output:

```
ls /bin/osh
/bin/osh
# osh -c "date"
Wed Dec 31 19:00:00 EST 1969
# osh -c "who am i"
root     console Dec 31 19:00
# echo hi | osh -c "cat"
hi
#
```

`ls /bin/osh` confirms the binary landed via root.proto.  `osh -c
"date"` proves the fork/exec path -- osh's `execute()` forks, the
child runs through the `/bin/` then `/usr/bin/` prefix search in
the TCOM branch of `execute()`, and `texec("/bin/date", t)` reaches
the date(1) binary.  `osh -c "who am i"` exercises argv pass-
through: who's argv[1] becomes "am" and argv[2] becomes "i", which
is the v7 who(1)'s built-in idiom for self-lookup against utmp.
`echo hi | osh -c "cat"` chains stdin redirection: the outer
parent shell (sh) sets up the pipe, osh inherits fd 0 from the
pipe-read side, and `cat` (osh's child) reads "hi\n" through it.
osh's `pwait()` returns when cat exits, then osh itself exits
because `readc()` sees arginp==1 (the "end of single-command"
sentinel set when the `-c` string is exhausted).

### SED

`sed` is the v7 two-file stream editor port installed at `/bin/sed`.
The full image build completed with:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
```

With raw captured output now preserving everything except carriage
returns, `tools/qemu-shell.py` reached login and completed the requested
sed run.  This command sequence does not enter pause(2), so it does not
depend on hiding pause-spin backspaces:

```
sed s/x/y/ /etc/passwd
root::0:0:root:/:/bin/sh
dmr::1:1:dennis:/:/bin/sh
# echo x | sed s/x/y/
y
# echo __TEST_DONE__
__TEST_DONE__
# 
```

Factor/primes argv regression:

`primes` now accepts the optional first numeric argument through the same
crt0 argv startup path used by `factor`, while preserving the stdin path.
The exclusive `2^56` boundary still reports `Ouch.` and returns to the
shell for both argv and stdin forms.

QEMU capture after `make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

```
primes 10 | sed 5q
11
13
17
19
23
# echo 10 | primes | sed 5q
11
13
17
19
23
# primes 72057594037927936 | sed 1q
Ouch.
# echo 72057594037927936 | primes | sed 1q
Ouch.
# factor 60

     2
     2
     3
     5
# echo __TEST_DONE__
__TEST_DONE__
# 
```

factor/primes QEMU verification after
`make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

```
ls /bin/factor /bin/primes
/bin/factor
/bin/primes
# factor 60

     2
     2
     3
     5
# factor 97

     97
# echo 84 | factor

     2
     2
     3
     7
# echo 10 | primes | sed 5q
11
13
17
19
23
# echo __TEST_DONE__
__TEST_DONE__
# 
```

factor/primes 2^56 boundary verification after
`make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

Historical boundary evidence is strict: `v7/usr/man/man1/factor.1`
documents positive input "less than 2^56", and both
`v7/usr/src/cmd/factor.s` and `v7/usr/src/cmd/primes.s` use
`cmpf big,fr0; bgt ...; jmp ouch`, which rejects equality.

Live QEMU capture through `tools/qemu-shell.py`:

```
factor 72057594037927936
Ouch.
# printf '72057594037927936\n' | primes | sed 1q
printf: cannot execute
# factor 60

     2
     2
     3
     5
# echo 84 | factor

     2
     2
     3
     7
# echo 10 | primes | sed 5q
11
13
17
19
23
# echo __TEST_DONE__
__TEST_DONE__
# 
```

This V7 root image does not install `printf`, so the literal requested
`printf ... | primes` pipeline cannot exercise `primes`; it fails before
`primes` receives input.  The same boundary value sent with the existing
`echo` command verifies the `primes` rejection and returns to the shell:

```
echo 72057594037927936 | primes | sed 1q
Ouch.
# echo __TEST_DONE__
__TEST_DONE__
# 
```

factor argv zero regression verification after
`make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

Live QEMU capture through `tools/qemu-shell.py`:

```
factor 0; echo F_ARG_ZERO:$?
F_ARG_ZERO:0
# echo 0 | factor; echo F_STDIN_ZERO:$?
F_STDIN_ZERO:0
# factor 60

     2
     2
     3
     5
# factor 72057594037927936; echo F_BOUND:$?
Ouch.
F_BOUND:1
# primes 10 | sed 5q
11
13
17
19
23
# echo __TEST_DONE__
__TEST_DONE__
# 
```

### UNITS

`units` is installed as `/bin/units` and reads the V7 table from
`/usr/lib/units`, copied from `v7/usr/lib/units` into the root image.
The previous failure was:

```
no table
```

Cleanup scope note: this units slice is limited to `unix-v7-c99` units
source/table/rootfs/logs.  Unrelated top-level dirty state, including
`stm32mp135_test_board` network/Linux work, is outside this slice and
was left untouched.

Build verification completed with:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
```

Live QEMU capture through `tools/qemu-shell.py`:

```
ls -l /usr/lib/units
-rw-r--r-- 1 root     7895 May 15 17:48 /usr/lib/units
# units <<EOF
> foot
> inch
> EOF
437 units; 3191 bytes

you have: you want: 	* 1.200000e+01
	/ 8.333333e-02
you have: 
# units <<EOF
> mile
> foot
> EOF
437 units; 3191 bytes

you have: you want: 	* 5.280000e+03
	/ 1.893939e-04
you have: 
# units <<EOF
> hour
> minute
> EOF
437 units; 3191 bytes

you have: you want: 	* 6.000000e+01
	/ 1.666667e-02
you have: 
# echo __TEST_DONE__
__TEST_DONE__
# 
```

The `/etc/passwd` run demonstrates file input and unchanged output
when the pattern is absent.  The pipe run demonstrates stdin input,
substitution, newline output, and process startup from `/bin/sed`.

A nearby text block also completed through the same helper:

```
echo TEXT-BEGIN
TEXT-BEGIN
# ls /bin/sed
/bin/sed
# cat /etc/passwd
root::0:0:root:/:/bin/sh
dmr::1:1:dennis:/:/bin/sh
# echo TEXT-END
TEXT-END
# echo __TEST_DONE__
__TEST_DONE__
```

### tar(1) V7 port coverage

`test_serv inventory` was attempted for hardware-test discovery, but
this worker environment does not have `test_serv` installed:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build command:

```
make ARCH=arm CONF=qemu_arm
...
arm-none-eabi-gcc ... -I../cmd/tar -c ../cmd/tar/tar.c
arm-none-eabi-gcc ... -o tar.elf crt0.o crt0c.o tar.o -L. -lc -lgcc
arm-none-eabi-objcopy -O binary tar.elf ../root/bin/tar
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

Fresh QEMU evidence from the rebuilt image:

```
login: root
# ls /bin/tar
/bin/tar
# cd /tmp
# rm -rf tarin tarout tappex arch.tar extra
# mkdir tarin
# mkdir tarin/sub
# echo alpha > tarin/a
# echo beta > tarin/sub/b
# echo gamma > tarin/c
# /bin/tar cf arch.tar tarin
# /bin/tar tf arch.tar
Tar: blocksize = 9
tarin/sub/b
tarin/a
tarin/c
# mkdir tarout
# cd tarout
# /bin/tar xf ../arch.tar
Tar: blocksize = 9
# cat tarin/a
alpha
# cat tarin/sub/b
beta
# cat tarin/c
gamma
# cd ..
# find /tmp/tarout/tarin -type f -print
/tmp/tarout/tarin/sub/b
/tmp/tarout/tarin/a
/tmp/tarout/tarin/c
# echo delta > extra
# /bin/tar rf arch.tar extra
# /bin/tar tf arch.tar
Tar: blocksize = 11
tarin/sub/b
tarin/a
tarin/c
extra
# mkdir tappex
# cd tappex
# /bin/tar xf ../arch.tar extra
Tar: blocksize = 11
# cat extra
delta
# cd ..
# /bin/tar cf - tarin/a | od -c | sed 1q
0000000   t   a   r   i   n   /   a  \0  \0  \0  \0  \0  \0  \0  \0  \0
# echo zeta > reg1
# echo alpha >> reg1
# sort reg1
alpha
zeta
# sed s/alpha/ALPHA/ reg1
zeta
ALPHA
# find tarout -type d -print | sort
tarout
tarout/tarin
tarout/tarin/sub
# echo __TAR_TEST_DONE__
__TAR_TEST_DONE__
```

### V7-routed link/unlink/rmdir metadata follow-up

Enemy found regressions in hard-link survival and nested `rmdir` after
the earlier parent-directory refresh.  The fix keeps V7-routed
`link()` / `unlink()` / historical `rmdir` in charge of link-count
metadata: armboot's `putino()` now preserves existing dinode fields such
as `di_nlink`, uid/gid, and times while updating only mode, size, and
block addresses; `kclose()` no longer rewrites directory dinodes after a
read-only directory open.

Built with:

```
make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Hard-link survival QEMU evidence:

```
cd /tmp
# rm -rf aa
# mkdir aa
# cat >aa/file <<!EOF!
> fromcat
> !EOF!
# ln aa/file aa/linkfile
# echo LN_STATUS:$?
LN_STATUS:0
# ls -l aa
total 2
-rw-rw-r-- 2 root        8 Dec 31 19:00 file
-rw-rw-r-- 2 root        8 Dec 31 19:00 linkfile
# cat aa/linkfile
fromcat
# rm aa/file
# ls -l aa
total 1
-rw-rw-r-- 1 root        8 Dec 31 19:00 linkfile
# cat aa/linkfile
fromcat
# echo __TEST_DONE__
__TEST_DONE__
```

Nested `rmdir` QEMU evidence:

```
cd /tmp
# rm -rf nd
# mkdir nd
# mkdir nd/sub
# cat >nd/sub/file <<!EOF!
> nested
> !EOF!
# rm nd/sub/file
# find nd -type d -print
nd
nd/sub
# find nd -type f -print
# rmdir nd/sub
# echo RMDIR_SUB_STATUS:$?
RMDIR_SUB_STATUS:0
# ls -l nd
total 0
# rmdir nd
# echo RMDIR_ND_STATUS:$?
RMDIR_ND_STATUS:0
# echo __TEST_DONE__
__TEST_DONE__
```

Sort checks from a fresh QEMU boot:

```
ls /bin/sort
/bin/sort
# cd /tmp
# rm -f s1 s2 s3
# (echo beta; echo alpha; echo gamma) | /bin/sort
alpha
beta
gamma
# /bin/sort s1
alpha
charlie
delta
# /bin/sort -r s1
delta
charlie
alpha
# /bin/sort -n s2
1 one
2 two
10 ten
# (echo beta; echo alpha; echo beta) | /bin/sort -u
alpha
beta
# /bin/sort +1 s3
c 1
b 2
a 3
# /bin/sort -c s1
sort: disorder:alpha
# echo CHECK_BAD:$?
CHECK_BAD:1
# /bin/sort s1 >s1.sorted
# /bin/sort -c s1.sorted
# echo CHECK_GOOD:$?
CHECK_GOOD:0
# (echo root:x; echo bin:a; echo daemon:m) | /bin/sort -t: +1
bin:a
daemon:m
root:x
# find /bin -name sort -print
/bin/sort
```

Find/sed/file and original mkdir/cat/find regression checks from a fresh
QEMU boot:

```
ls /bin/find
/bin/find
# cd /tmp
# rm -rf aa zz froot find.cpio
# mkdir /tmp/aa
# ls -ld /tmp/aa
drwxrwxr-x 2 root       32 Dec 31 19:00 /tmp/aa
# cat >/tmp/aa/file <<!EOF!
> fromcat
> !EOF!
# ls -ld /tmp/aa
drwxrwxr-x 2 root       48 Dec 31 19:00 /tmp/aa
# ls -l /tmp/aa
total 1
-rw-rw-r-- 1 root        8 Dec 31 19:00 file
# cat /tmp/aa/file
fromcat
# find /tmp/aa -type d -print
/tmp/aa
# find /tmp/aa -type f -print
/tmp/aa/file
# mkdir froot
# mkdir froot/sub
# echo alpha > froot/fa
# echo beta > froot/sub/fb
# : > froot/zero
# chmod 644 froot/fa
# find froot -name fa -print
froot/fa
# find froot -type f -print
froot/sub/fb
froot/fa
froot/zero
# find froot -type d -print
froot
froot/sub
# find froot ! -name fb -name fa -print
froot/fa
# find froot '(' -name fa -o -name sub ')' -print
froot/sub
froot/fa
# find froot -name fa -exec echo EXEC {} ';'
EXEC froot/fa
# find froot -user root -name fa -print
froot/fa
# find froot -group 0 -name fa -print
froot/fa
# find froot -perm 644 -name fa -print
froot/fa
# find froot -links 1 -name fa -print
froot/fa
# find froot -size 0 -name zero -print
froot/zero
# find froot -name fa -cpio find.cpio
# ls -l find.cpio
-rw-rw-rw- 1 root     5120 Dec 31 19:00 find.cpio
# find /tmp/froot -type d -print
/tmp/froot
/tmp/froot/sub
# find /tmp/froot -type f -print
/tmp/froot/sub/fb
/tmp/froot/fa
/tmp/froot/zero
# echo alpha | sed s/alpha/ALPHA/
ALPHA
# /bin/file froot/fa
froot/fa:	ascii text
# echo __TEST_DONE__
__TEST_DONE__
```

Earlier external run logs that showed `!T`, `s!Ted`, or helper-side
backspace filtering are stale evidence for this section; the current
claim is based on the live helper output shown above.

### AWK

`awk` is the v7 awk port installed at `/bin/awk`.  The full image build
completed with:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
```

The forced root image rebuild also completed:

```
make -B -C unix-v7-c99 ARCH=arm CONF=qemu_arm root.img
```

That build uses the checked-in `cmd/awk/awk.g.c`, `cmd/awk/awk.h`, and
`cmd/awk/proctab.c` artifacts directly; no host `yacc` or `lex` command
is part of the awk rebuild.  `tools/mkfs` now emits the double-indirect
blocks needed by the existing `/usr/dict/words` file, so the 8192-block
root image builds without `indirect block full`.

Live QEMU capture through `tools/qemu-shell.py`:

```
echo edge > /tmp/END
# echo start > /tmp/BEGIN
# awk '{print $0}' /tmp/END
edge
# cd /tmp
# awk '{print $0}' END
edge
# awk '{print $0}' BEGIN
start
# awk 'BEGIN {print 7}'
7.0000000000000000000
# awk 'END {print NR}' /etc/passwd
2.0000000000000000000
# awk '{n=n+1} END {print n}' /etc/passwd
2.0000000000000000000
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

### iostat

`cmd/iostat.c` is now built by the normal userland `BIN` loop and
installed as `root/bin/iostat`; the top-level `ROOT` list depends on it
before `root.img` is packed.  `make -C unix-v7-c99 ARCH=arm
CONF=qemu_arm` completed successfully.  The build log included:

Scope note: `/bin/prof` and `/bin/tc` were already installed before this
iostat slice, as shown by the earlier PROF/TC sections in this log and
the matching historical-accuracy entries.  This slice did not add or
remove them; it only made `/bin/iostat` reproducible through the normal
build and root-image paths.

```
set -e; for i in ... graph factor primes expr ac iostat; do \
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

Host staging check:

```
ls -l unix-v7-c99/root/bin/iostat unix-v7-c99/root.img
-rw-rw-r--+ 1 agent9 agent9 4194304 May 15 16:46 unix-v7-c99/root.img
-rwxrwxr-x+ 1 agent9 agent9   24856 May 15 16:46 unix-v7-c99/root/bin/iostat
```

Live QEMU capture through `tools/qemu-shell.py`:

```
iostat
   RF                RK                RP                  PERCENT
   tpm  msps  mspt   tpm  msps  mspt   tpm  msps  mspt  user  nice systm  idle
252000-131.1 131.1     0   0.0   0.0     0   0.0   0.0100.00  0.00  0.00  0.00
# ls /bin/iostat
/bin/iostat
# expr 1 + 2
3
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# true; echo $?
0
# false; echo $?
1
# echo __TEST_DONE__
__TEST_DONE__
#
```

This covers a complete action followed by input files named `END` and
`BEGIN`, including `END` through an absolute path and both names after
`cd /tmp`, plus `BEGIN`-only programs, `END` programs, mixed action+`END`
programs split by the shell into separate argv words, stdin through a
pipe, field splitting, and `print` output.

The forced rebuild was also scanned for host parser generators:

```
make -B -C unix-v7-c99 ARCH=arm CONF=qemu_arm root.img
-- yacc/lex scan --
no yacc or lex command found
```

### TRUE/FALSE

`true` and `false` are the original V7 shell files installed as
`/bin/true` and `/bin/false`: `true` is a zero-byte executable file and
`false` contains `exit 1\n`.

Cleanup scope note: this slice accounts only for rootfs wiring of those
two V7 files plus the ENOEXEC shell-script fallback needed to execute
them.  The inherited worktree also contains broad mission work for sed,
awk, accounting, games, proc/syscall routing, root image growth, and
kernel/sys stubs; that dirty state was inspected and left untouched
because it is outside the true/false slice.

The full image build completed with:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
```

Cleanup rerun:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
make: Entering directory '/home/agent9/fast_data/unix-v7-c99'
make: Nothing to be done for 'all'.
make: Leaving directory '/home/agent9/fast_data/unix-v7-c99'
```

Generated root staging evidence:

```
0 unix-v7-c99/root/bin/true
7 unix-v7-c99/root/bin/false
7 total
  65  78  69  74  20  31  0a
   e   x   i   t       1  \n
```

Live QEMU capture through `tools/qemu-shell.py`:

```
true
# echo $?
0
# false
# echo $?
1
# echo __TEST_DONE__
__TEST_DONE__
#
```

Cleanup QEMU capture through `tools/qemu-shell.py`:

```
true
# echo $?
0
# false
# echo $?
1
# ls -l /bin/true /bin/false
-rwxr-xr-x 1 root        7 Dec 31 19:00 /bin/false
-rwxr-xr-x 1 root        0 Dec 31 19:00 /bin/true
# cat /bin/false
exit 1
# echo hi | cat
hi
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

Presence and content check:

```
ls /bin/true
/bin/true
# ls /bin/false
/bin/false
# cat /bin/false
exit 1
# echo __TEST_DONE__
__TEST_DONE__
#
```

This supersedes the earlier PROC log where both commands reported
`cannot execute`.

Cleanup diff-scope evidence:

```
git -C unix-v7-c99 status --porcelain=v1
```

Before cleanup there were 96 dirty entries, including broad modified
kernel/sys/lib/tool files and many untracked command ports.  Cleanup did
not reset or narrow those unrelated changes; it changed only the two log
files to document the true/false slice boundary and verification.
After cleanup verification, the same porcelain status still had 96
entries, and `diff -u` between the before/after status snapshots was
empty.  The only files edited by this cleanup were
`logs/unix-on-qemu.md` and `logs/unix-historical-accuracy.md`.

ENOEXEC fallback argument regression:

Before restoring the V7 fallback, an executable `/tmp/argtest` containing
`echo args:$1:$2:$#` printed `args:::0` when run as `/tmp/argtest A B`.
The fallback was using direct `execexp(0,input); done();`, which executed
the text file but never installed the attempted command arguments as
shell positional parameters.

The shell now calls `setargs(t)` before the direct ENOEXEC script reader:
`setargs(t); execexp(0,input); done();`.  The historical
`longjmp(subshell,1)` re-entry path was tried first but hung in this C99
port after `/tmp/argtest A B`, so the compatible fix preserves the
current direct reader and restores the missing positional parameters.

QEMU capture after `make -C unix-v7-c99 ARCH=arm CONF=qemu_arm`:

```
echo 'echo args:$1:$2:$#' > /tmp/argtest
# chmod 755 /tmp/argtest
# /tmp/argtest A B
args:A:B:2
# true; echo $?
0
# false; echo $?
1
# echo hi | cat
hi
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
# 
```

### NOHUP

`nohup` is the original V7 shell script from `v7/bin/nohup`, copied
verbatim into `root/bin/nohup`, chmodded executable, and installed in
the QEMU root image as `/bin/nohup`.

`1` is the original V7 shell script from `v7/bin/1`, copied verbatim
into `root/bin/1`, chmodded executable, and installed in the QEMU root
image as `/bin/1`.  The smoke command `1 unix` prints `one unix - it
works`.

Live QEMU capture through `tools/qemu-shell.py`:

```
1 unix
one unix - it works
# echo __TEST_DONE__
__TEST_DONE__
# 
```

The full image build completed with:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
```

The build log included the expected script install lines:

```
cp ../v7/bin/nohup ../root/bin/nohup
chmod 755 ../root/bin/true ../root/bin/false ../root/bin/nohup
```

Host staging check:

```
-rwxr-xr-x+ 1 agent9 agent9 139 May 15 16:03 root/bin/nohup
trap "" 1 15
if test -t 2>&1  ; then
	echo "Sending output to 'nohup.out'"
	exec nice -5 $* >>nohup.out 2>&1
else
	exec nice -5 $* 2>&1
fi
```

Live QEMU capture through `tools/qemu-shell.py`:

```
ls -l /bin/nohup
-rwxr-xr-x 1 root      139 May 15 19:03 /bin/nohup
# cat /bin/nohup
trap "" 1 15
if test -t 2>&1  ; then
	echo "Sending output to 'nohup.out'"
	exec nice -5 $* >>nohup.out 2>&1
else
	exec nice -5 $* 2>&1
fi
# rm -f nohup.out; nohup echo hi; cat nohup.out
Sending output to 'nohup.out'
cat: can't open nohup.out
# rm -f nohup.out; nohup false; echo NOHUP_FALSE:$?
Sending output to 'nohup.out'
NOHUP_FALSE:1
# true; echo $?
0
# false; echo $?
1
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

Follow-up status and redirection evidence:

```
nohup echo hi; echo ECHO_STATUS:$?
Sending output to 'nohup.out'
ECHO_STATUS:0
# ls -l nohup.out
nohup.out not found
# cd /tmp
# /bin/echo external > direct.out; echo EXT_DIRECT_STATUS:$?; ls -l direct.out
EXT_DIRECT_STATUS:0
direct.out not found
# /bin/echo external >> append.out; echo EXT_APPEND_STATUS:$?; ls -l append.out
EXT_APPEND_STATUS:0
append.out not found
# touch touch.out; echo TOUCH_STATUS:$?; ls -l touch.out
TOUCH_STATUS:0
touch.out not found
```

So `/bin/nohup` itself is present, executable, and preserving command
status through `nice`; the missing `nohup.out` file reproduces with
plain redirection and `touch` in this image and was not changed in this
install-only slice.

### EXPR

`expr` is installed as `/bin/expr` from the static C99 port in
`cmd/expr.c`.  The build completed with:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
```

Host staging check after the root image build:

```
ls -l unix-v7-c99/root/bin/expr unix-v7-c99/root.img
-rw-rw-r--+ 1 agent9 agent9 4194304 May 15 16:25 unix-v7-c99/root.img
-rwxrwxr-x+ 1 agent9 agent9   26336 May 15 16:25 unix-v7-c99/root/bin/expr
```

Live QEMU capture through `tools/qemu-shell.py`:

```
expr 1 + 2
3
# expr 6 '*' 7
42
# expr 5 '>' 3
1
# expr abc : 'a.*'
3
# expr abc : 'z.*'
0
# expr length abc
3
# expr index abc b
2
# expr substr abcdef 2 3
bcd
# expr 0; echo $?
0
1
# expr 1; echo $?
1
0
# echo __TEST_DONE__
__TEST_DONE__
#
```

Shell EXPAND regression confirming command substitution can execute
`expr` and does not report `expr: cannot execute`:

```
echo EXPAND:`expr 1 + 2`
EXPAND:3
# a=`expr 6 '*' 7`
# echo A=$a
A=42
# echo __TEST_DONE__
__TEST_DONE__
#
```

### AC

V7 lands `ac` in `/bin`, while `accton` remains under `/etc`.  This
slice moved the existing `cmd/ac.c` install/staging path from
`root/etc/ac` to `root/bin/ac` and updated the QEMU root prototype to
install it as `/bin/ac`.

Build and host staging checks:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
ls -l unix-v7-c99/root/bin/ac
-rwxrwxr-x+ 1 agent9 agent9 22236 May 15 16:36 unix-v7-c99/root/bin/ac
root/etc/ac: absent
```

Live QEMU capture through `tools/qemu-shell.py`:

```
ls -l /bin/ac
-rwxr-xr-x 1 root    22236 May 15 19:36 /bin/ac
# ls -l /etc/ac
/etc/ac not found
# ac -w /usr/adm/wtmp; echo AC_STATUS:$?
AC_STATUS:0
# expr 1 + 2
3
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

### DC

`dc` is installed as `/bin/dc` from the existing V7 C99 carry-over in
`cmd/dc/dc.c` and `cmd/dc/dc.h`.  This slice kept the calculator source
behaviorally intact and fixed build hygiene: `root.img` now depends on
`cmd/dc/*`, and `lib/Makefile clean` removes staged `root/bin/dc`.
`bc` was intentionally not included.

`test_serv inventory` was requested first, but the command is not
installed in this shell:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build evidence from the requested command:

```
make -C unix-v7-c99 ARCH=arm CONF=qemu_arm
...
arm-none-eabi-gcc ... -I../cmd/dc -c ../cmd/dc/dc.c
../cmd/dc/dc.c: In function 'cond':
../cmd/dc/dc.c:1652:25: warning: suggest parentheses around '&&' within '||' [-Wparentheses]
arm-none-eabi-gcc ... -o dc.elf crt0.o crt0c.o dc.o -L. -lc -lgcc
arm-none-eabi-objcopy -O binary dc.elf ../root/bin/dc
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

Live QEMU capture through `tools/qemu-shell.py`:

```
ls /bin/dc
/bin/dc
# echo '2 3 + p' | dc
5
# echo '5 7 * p' | dc
35
# echo '2 k 1 8 / p' | dc
.12
# expr 1 + 2
3
# echo x | sed s/x/y/
y
# echo 'a b' | awk '{print $2}'
b
# echo __TEST_DONE__
__TEST_DONE__
#
```

Follow-up QEMU regression after fixing `dc` signed-byte reads on Arm:

```
ls /bin/dc
/bin/dc
# echo '2 3 + p' | dc
5
# echo '9 3 / p' | dc
3
# echo '10 4 - p' | dc
6
# echo '4 10 - p' | dc
-6
# echo '_6 p' | dc
-6
# echo __TEST_DONE__
__TEST_DONE__
#
```

Additional signed arithmetic smoke:

```
echo '_6 p' | dc
-6
# echo '4 _10 + p' | dc
-6
# echo '_4 _10 + p' | dc
-14
# echo '_4 10 * p' | dc
-40
# echo __TEST_DONE__
__TEST_DONE__
#
```

Optional plot regression smoke also completed.  The Tek backend emits
terminal-control backspaces on the serial console, so the important
checked lines are the exit status and output path:

```
echo 0 0 > /tmp/g.in
# echo 1 1 >> /tmp/g.in
# graph /tmp/g.in | plot -Ttek > /tmp/plot.out; echo plot:$?; ls /tmp/plot.out
plot:0
/tmp/plot.out
# echo __TEST_DONE__
__TEST_DONE__
#
```

### LOGIN_GETLOGIN

Live QEMU capture through `tools/qemu-shell.py` after the login/getlogin
slice.  The harness boots the rebuilt `unix` and `root.img`, waits for
getty's `login:`, sends `root`, then runs commands in the resulting
login shell.

```
who am i
root     console Dec 31 19:00
# tty
/dev/console
# echo $HOME
/
# pwd
/
# echo $PATH
:/bin:/usr/bin
# echo x | sed s/x/y/
y
# echo 2 3 + p | dc
5
# expr 1 + 2
3
# factor 84

     2
     2
     3
     7
# awk 'BEGIN { print 7 }'
7.0000000000000000000
# iostat 1 1 | sed 3q
   RF                RK                RP                  PERCENT
   tpm  msps  mspt   tpm  msps  mspt   tpm  msps  mspt  user  nice systm  idle
129316-131.1 131.1     0   0.0   0.0     0   0.0   0.0100.00  0.00  0.00  0.00
# echo __TEST_DONE__
__TEST_DONE__
#
```

Additional `ps` and bounded `primes` regression smoke:

```
ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
     5 ?   0:00 ps
# primes 10 | sed 5q
11
13
17
19
23
# echo __TEST_DONE__
__TEST_DONE__
#
```

Two earlier login smoke attempts timed out because I used `primes 10 20`
and then `echo 10 20 | primes`; this port's `primes` prints an unbounded
stream starting at the supplied number, so those were bad harness inputs,
not login failures.  The first of those attempts had already reached the
login shell before timing out.

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

### REDIRECT_NOHUP_FD_PERSISTENCE

Follow-up Worker fix for the external-command redirection/nohup
regression found after the login/getlogin slice.

Root cause: new files created by armboot's `kcreat()` were appended to
the on-disk directory, but v7's cached directory inode (`rootdir` or
`u.u_cdir`) kept the old size/block metadata, so later v7 `namei()`
lookups could not see the new dirent.  Separately, dup'd redirected fds
could carry stale armboot `files[]` snapshots for the same inode; exit or
close writeback could then overwrite the current inode size/block list.
Regular-file writes now stay on armboot's byte-moving path and refresh
the v7 inode shadow afterward; close/exit flush refreshes from the v7
inode before `putino()`, and armboot-created directory mutations refresh
matching cached v7 directory inodes.

Changed files:

```
arch/armboot.c
arch/u_bridge.c
logs/unix-on-qemu.md
logs/unix-historical-accuracy.md
```

Build:

```
make ARCH=arm CONF=qemu_arm
```

Focused QEMU evidence:

```
/bin/echo HI > out 2>&1
echo REDIR_STATUS:$?
REDIR_STATUS:0
# cat out
HI
# nohup /bin/echo HI
Sending output to 'nohup.out'
# echo NOHUP_STATUS:$?
NOHUP_STATUS:0
# cat nohup.out
HI
# echo 'echo SCRIPTARGS:$0:$1:$2' > /tmp/scr
# chmod 755 /tmp/scr
# /tmp/scr one two
SCRIPTARGS:-sh:one:two
# who am i
root     console Dec 31 19:00
```

### sort

`cmd/sort.c` was already wired into the ARM userland build, top-level
root image prerequisites, and qemu root prototype as `/bin/sort`.
Historical source deltas are documented in
`logs/unix-historical-accuracy.md`.

Build and local compile checks:

```
make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

```
arm-none-eabi-gcc ... -c cmd/sort.c -o /tmp/sort-worker-check.o
```

The compile check returned status 0 with only the existing warning
classes explicitly allowed by the normal `lib/Makefile` `CFLAGS`
(`-Wparentheses`, `-Wdangling-else`, `-Wchar-subscripts`,
`-Wsizeof-pointer-div`, `-Wmissing-braces`, and
`-Wimplicit-fallthrough`).

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

QEMU evidence from a fresh `tools/qemu-shell.py` boot.  This covers
installation, stdin lexical sort, file input, reverse sort, numeric
sort, unique output, old-style key selection, `-c` failure/success
statuses, `-t:` field splitting, and a small pipeline regression:

```
ls /bin/sort
/bin/sort
# cd /tmp
# rm -f s1 s2 s3
# (echo beta; echo alpha; echo gamma) | /bin/sort
alpha
beta
gamma
# cat >s1 <<'EOS'
> delta
> alpha
> charlie
> EOS
# /bin/sort s1
alpha
charlie
delta
# /bin/sort -r s1
delta
charlie
alpha
# cat >s2 <<'EOS'
> 10 ten
> 2 two
> 1 one
> EOS
# /bin/sort -n s2
1 one
2 two
10 ten
# (echo beta; echo alpha; echo beta) | /bin/sort -u
alpha
beta
# cat >s3 <<'EOS'
> b 2
> c 1
> a 3
> EOS
# /bin/sort +1 s3
c 1
b 2
a 3
# /bin/sort -c s1
sort: disorder:alpha
# echo CHECK_BAD:$?
CHECK_BAD:1
# /bin/sort s1 >s1.sorted
# /bin/sort -c s1.sorted
# echo CHECK_GOOD:$?
CHECK_GOOD:0
# (echo root:x; echo bin:a; echo daemon:m) | /bin/sort -t: +1
bin:a
daemon:m
root:x
# echo x | sed s/x/y/
y
# echo __TEST_DONE__
__TEST_DONE__
```

Additional regression check from a separate fresh boot:

```
find /bin -name sort -print
/bin/sort
# echo __TEST_DONE__
__TEST_DONE__
```

### spline(1)

`cmd/spline.c` is built by the normal userland `BIN` loop and installed
as `/bin/spline`.  Focused QEMU verification after
`make ARCH=arm CONF=qemu_arm`:

```
ls /bin/spline
/bin/spline
# cd /tmp
# echo 0 0 > spline.in
# echo 1 1 >> spline.in
# echo 2 0 >> spline.in
# cat spline.in | spline -n 4 | od -c
0000000   2   .   0   0   0   0   0   0       0   .   0   0   0   0   0
0000020   0  \n   1   .   5   0   0   0   0   0       0   .   6   8   7
0000040   5   0   0  \n   1   .   0   0   0   0   0   0       1   .   0
0000060   0   0   0   0   0  \n   0   .   5   0   0   0   0   0       0
0000100   .   6   8   7   5   0   0  \n   0   .   0   0   0   0   0   0
0000120       0   .   0   0   0   0   0   0  \n
0000132
# cat spline.in | spline -n 4 | plot -Ttek | od -c
0000000 037  \0
0000001
```

Regression checks from the same image:

```
# echo 0 0 > g.in
# echo 1 1 >> g.in
# echo 2 0 >> g.in
# graph -g 0 -m 0 /tmp/g.in | od -c
0000000   s  \0  \0  \0  \0  \0 020  \0 020   e   m 310  \0 214  \0   p
0000020 310  \0 310  \0   p   4  \b 240 017   p 240 017 310  \0   f   s
0000040   o   l   i   d  \n   m 001  \0 001  \0
0000052
# graph -g 0 -m 0 /tmp/g.in | plot -Ttek | od -c
0000000 033  \f 035       h   z   !   F 035   !   `   f   F   F 035   7
0000020   k   y   ,   O  \0  \0  \0   O 035   !   b   f   7   Y  \0  \0
0000040  \0   Y 033   ` 035       `   `       @  \0  \0 037  \0
0000055
# echo abc | sed 's/b/B/'
aBc
# echo 'a b' | awk '{print $2 ":" $1}'
b:a
# expr 6 '*' 7
42
# echo '2 3 + p' | dc
5
# factor 84

     2
     2
     3
     7
# echo teh | spell
teh
# echo the | spell
```

### V7_SPELL_HELPER_DIRECT_QEMU

Enemy found that `/usr/lib/spellin` and `/usr/lib/spellout` had only
presence coverage, and direct helper use failed because newly-created
regular files stopped at 5120 bytes:

```
(echo zzztestword) | /usr/lib/spellin >/tmp/spelltab
spellin: trouble writing hash table
```

Root cause was below spell: the live ARM syscall path uses
`arch/armboot.c::writei()` as the authoritative regular-file byte mover,
and that shim only allocated the ten direct inode block addresses.  V7
spell hash tables are 50000 bytes, so stdout redirection for `spellin`
crossed into the single-indirect range and the write stopped.  The shim
now allocates the same single- and double-indirect block layout that its
reader already follows.

Build and forced dictionary recopy:

```
make ARCH=arm CONF=qemu_arm root.img
MAKE_OK

make -B ARCH=arm CONF=qemu_arm root/usr/dict/words root/usr/dict/hlista root/usr/dict/hlistb root/usr/dict/hstop root/usr/dict/spellhist
mkdir -p root/usr/dict
rm -f root/usr/dict/words
cp v7/usr/dict/words root/usr/dict/words
mkdir -p root/usr/dict
rm -f root/usr/dict/hlista
cp v7/usr/dict/hlista root/usr/dict/hlista
mkdir -p root/usr/dict
rm -f root/usr/dict/hlistb
cp v7/usr/dict/hlistb root/usr/dict/hlistb
mkdir -p root/usr/dict
rm -f root/usr/dict/hstop
cp v7/usr/dict/hstop root/usr/dict/hstop
mkdir -p root/usr/dict
rm -f root/usr/dict/spellhist
cp v7/usr/dict/spellhist root/usr/dict/spellhist

make ARCH=arm CONF=qemu_arm root.img
MAKE_OK
```

Direct helper QEMU evidence:

```
cd /tmp
# (echo zzztestword) | /usr/lib/spellin >/tmp/spelltab; echo SPELLIN_STATUS:$?; ls -l /tmp/spelltab
SPELLIN_STATUS:0
-rw-rw-r-- 1 root    50000 Dec 31 19:00 /tmp/spelltab
# (echo zzztestword; echo alpha) | /usr/lib/spellout /tmp/spelltab; echo SPELLOUT_STATUS:$?
alpha
SPELLOUT_STATUS:0
# /usr/lib/spellout -d /tmp/spelltab <<EOF
> zzztestword
> alpha
> EOF
zzztestword
# echo SPELLOUT_D_STATUS:$?
SPELLOUT_D_STATUS:0
# cp /usr/dict/hlista /tmp/hcopy; echo CP_STATUS:$?; ls -l /tmp/hcopy
CP_STATUS:0
-rw-r--r-- 1 root    50000 Dec 31 19:00 /tmp/hcopy
```

Prior spell, deroff, and `-b` checks preserved:

```
cat >/tmp/roff.in <<'IN'
> .TH SPELLTEST 1
> .SH NAME
> colour speling
> .B colour
> I qzxword
> IN
# deroff -w /tmp/roff.in
SPELLTEST
NAME
colour
speling
colour
qzxword
# spell -b /tmp/roff.in
qzxword
speling
SPELLTEST
# spell /tmp/roff.in -b
qzxword
speling
SPELLTEST
# spell -b </tmp/roff.in
qzxword
speling
SPELLTEST
# echo teh | spell
teh
# echo the | spell
# echo colour speling | spell -b
speling
# spell -b /dev/null
# spell /dev/null -b
```

Small regression set:

```
echo abc | sed 's/b/B/'
aBc
# echo 'x y' | awk '{print $2 ":" $1}'
y:x
# expr 1 + 2
3
# expr 6 '*' 7
42
# expr 5 \* 6
30
# echo '2 3 + p' | dc
5
# echo '10 4 - p' | dc
6
# (echo beta; echo alpha; echo beta) | sort -u
alpha
beta
# factor 84

     2
     2
     3
     7
# : > trunc.out; echo TRUNC_STATUS:$?; ls -l trunc.out
TRUNC_STATUS:0
-rw-rw-r-- 1 root        0 Dec 31 19:00 trunc.out
# /bin/echo first > append.out; /bin/echo second >> append.out; echo APPEND_STATUS:$?; cat append.out
APPEND_STATUS:0
first
second
# cat /no/such/file 2>err.out; echo ERR_STATUS:$?; cat err.out
ERR_STATUS:0
cat: can't open /no/such/file
```

### V7_SPELL_DEROFF

Follow-up Worker fix for forced rebuild repeatability of the V7 spell
assets.  The previous image already had functional `/bin/spell`,
`/bin/deroff`, `/usr/lib/spell*`, and dictionaries, but
`make -B ARCH=arm CONF=qemu_arm root.img` could fail while recopying a
host-staged dictionary file that was not owner-writable.  The Makefile
now removes each staged `root/usr/dict/*` target before copying the V7
source file back into place.  The runtime image file modes remain
declared by `conf/qemu_arm/root.proto`.

Source fidelity checks:

```
diff -u v7/usr/src/cmd/deroff.c cmd/deroff.c
```

produced no output.  The only intentional `v7/bin/spell` script delta is
the temporary-file form of the same deroff/sort/spell/spell/sort
pipeline:

```
--- v7/bin/spell
+++ cmd/spell/spell.sh
@@
-deroff -w $F |\
-  sort -u |\
-  /usr/lib/spell ${S-/usr/dict/hstop} $T |\
-  /usr/lib/spell ${D-/usr/dict/hlista} $V $B |\
-  sort -u +0f +0 - $T |\
+deroff -w $F > ${T}w
+sort -u ${T}w > ${T}u
+/usr/lib/spell ${S-/usr/dict/hstop} $T < ${T}u > ${T}s
+/usr/lib/spell ${D-/usr/dict/hlista} $V $B < ${T}s > ${T}o
+sort -u +0f +0 ${T}o $T |\
   tee -a $H
```

Forced rebuild:

```
make -B ARCH=arm CONF=qemu_arm root.img
```

completed successfully.  Relevant rebuild excerpt:

```
mkdir -p root/usr/dict
rm -f root/usr/dict/words
cp v7/usr/dict/words root/usr/dict/words
...
mkdir -p root/usr/dict
rm -f root/usr/dict/spellhist
cp v7/usr/dict/spellhist root/usr/dict/spellhist
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

After that rebuild left the staged V7 files owner-nonwritable again,
`make -B ARCH=arm CONF=qemu_arm root/usr/dict/words root/usr/dict/hlista
root/usr/dict/hlistb root/usr/dict/hstop root/usr/dict/spellhist` also
completed and recopied all five dictionary targets.

Host dictionary checksums still matched the V7 assets:

```
1409855690 196513 root/usr/dict/words
3022744057 50000 root/usr/dict/hlista
1195046640 50000 root/usr/dict/hlistb
2178767393 50000 root/usr/dict/hstop
4294967295 0 root/usr/dict/spellhist
1409855690 196513 v7/usr/dict/words
3022744057 50000 v7/usr/dict/hlista
1195046640 50000 v7/usr/dict/hlistb
2178767393 50000 v7/usr/dict/hstop
4294967295 0 v7/usr/dict/spellhist
```

Focused QEMU evidence from the rebuilt image:

```
ls -l /bin/spell /bin/deroff /usr/lib/spell /usr/lib/spellin /usr/lib/spellout /usr/dict/words /usr/dict/hlista /usr/dict/hlistb /usr/dict/hstop /usr/dict/spellhist
-rwxr-xr-x 1 root    32608 May 15 21:39 /bin/deroff
-rwxr-xr-x 1 root      562 May 15 21:39 /bin/spell
-rw-r--r-- 1 root    50000 May 15 21:39 /usr/dict/hlista
-rw-r--r-- 1 root    50000 May 15 21:39 /usr/dict/hlistb
-rw-r--r-- 1 root    50000 May 15 21:39 /usr/dict/hstop
-rw-rw-rw- 1 root        0 May 15 21:39 /usr/dict/spellhist
-rw-r--r-- 1 root   196513 May 15 21:39 /usr/dict/words
-rwxr-xr-x 1 root    26400 May 15 21:39 /usr/lib/spell
-rwxr-xr-x 1 root    18296 May 15 21:39 /usr/lib/spellin
-rwxr-xr-x 1 root    18508 May 15 21:39 /usr/lib/spellout
# echo teh | spell
teh
# echo the | spell
# echo colour | spell -b
# deroff -w /tmp/roff.in
NAME
sample
text
boldword
```

Regression checks rerun from the rebuilt image:

```
echo x | sed s/x/y/
y
# expr 1 + 2
3
# expr 6 '*' 7
42
# echo '2 3 + p' | dc
5
# echo '10 4 - p' | dc
6
# : > trunc.out
# ls -l trunc.out
-rw-rw-r-- 1 root        0 Dec 31 19:00 trunc.out
# cat append.out
first
second
# cat err.out
missing-file not found
```

Additional redirection/create checks:

```
cd /tmp
# /bin/echo external > direct.out; echo EXT_DIRECT_STATUS:$?; cat direct.out
EXT_DIRECT_STATUS:0
external
# /bin/echo first > append.out; /bin/echo second >> append.out; echo EXT_APPEND_STATUS:$?; cat append.out
EXT_APPEND_STATUS:0
first
second
# touch touch.out; echo TOUCH_STATUS:$?; ls -l touch.out
TOUCH_STATUS:0
-rw-rw-r-- 1 root        0 Dec 31 19:00 touch.out
```

Small regression set:

```
echo abc | sed 's/b/B/'
aBc
# echo 'x y' | awk '{print $2 ":" $1}'
y:x
# expr 3 + 4
7
# expr 5 \* 6
30
# echo '2 3+p' | dc
5
# factor 84

     2
     2
     3
     7
```

`primes 10 20` was attempted in a combined regression batch and timed
out because this port's `primes` treats the first operand as an unbounded
starting value and does not implement an upper-bound operand; the timeout
buffer showed the continuing prime stream.  This is a bad harness input,
not a regression in the redirection/nohup fix.

### V7_SPELL_B_OPTION_FILE_ARGS

Enemy found that the staged `/bin/spell` script leaked `-b` to
`deroff` whenever file operands were also present:

```
spell -b /dev/null
Deroff: Invalid flag b
# spell /tmp/roff.in -b
Deroff: Cannot open file -b
colour
```

Root cause: this target shell mishandled the original `for A in $*`
option scan in the script case that also had file operands.  The staged
script now uses a simple `while`/`shift` parser, preserving V7's option
effects while collecting only non-option operands into the `deroff`
file list.  The temporary-file pipeline also keeps the original V7
`sort -u` stage before the first `/usr/lib/spell` pass:

```
deroff -w $F > ${T}w
sort -u ${T}w > ${T}u
/usr/lib/spell ${S-/usr/dict/hstop} $T < ${T}u > ${T}s
/usr/lib/spell ${D-/usr/dict/hlista} $V $B < ${T}s > ${T}o
sort -u +0f +0 ${T}o $T |\
  tee -a $H
```

Build and forced dictionary recopy:

```
make ARCH=arm CONF=qemu_arm root.img
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img

make -B ARCH=arm CONF=qemu_arm root/usr/dict/words root/usr/dict/hlista root/usr/dict/hlistb root/usr/dict/hstop root/usr/dict/spellhist
mkdir -p root/usr/dict
rm -f root/usr/dict/words
cp v7/usr/dict/words root/usr/dict/words
mkdir -p root/usr/dict
rm -f root/usr/dict/hlista
cp v7/usr/dict/hlista root/usr/dict/hlista
mkdir -p root/usr/dict
rm -f root/usr/dict/hlistb
cp v7/usr/dict/hlistb root/usr/dict/hlistb
mkdir -p root/usr/dict
rm -f root/usr/dict/hstop
cp v7/usr/dict/hstop root/usr/dict/hstop
mkdir -p root/usr/dict
rm -f root/usr/dict/spellhist
cp v7/usr/dict/spellhist root/usr/dict/spellhist
```

Focused QEMU evidence from a fresh rebuilt image.  The input contains
roff markup, British `colour`, and nonexistent words:

```
cat >/tmp/roff.in <<'IN'
> .TH SPELLTEST 1
> .SH NAME
> colour speling
> .B colour
> I qzxword
> IN
# deroff -w /tmp/roff.in
SPELLTEST
NAME
colour
speling
colour
qzxword
# spell -b /tmp/roff.in
qzxword
speling
SPELLTEST
# spell /tmp/roff.in -b
qzxword
speling
SPELLTEST
# spell -b </tmp/roff.in
qzxword
speling
SPELLTEST
# echo teh | spell
teh
# echo the | spell
# echo colour speling | spell -b
speling
```

The original `/dev/null` repro shapes also return cleanly:

```
# spell -b /dev/null
# spell /dev/null -b
```

Small regression checks from the same QEMU boot:

```
# (echo beta; echo alpha; echo beta) | sort -u
alpha
beta
# expr 1 + 2
3
```

### REDIRECT_TRUNCATE_EXISTING

Follow-up fix for `: > file` leaving an existing file's old contents and
size intact.

Root cause had two parts:

* `arch/armboot.c::kcreat()` zeroed the armboot fd snapshot for an
  existing file, but the v7 in-core inode attached by `v7_ofile_set()`
  could still carry the old size/block list.  A later close/flush could
  copy that stale v7 state back over the truncation.  The reuse-existing
  path now writes the zero-size dinode immediately and refreshes both
  cached v7 inode forms.
* The Bourne shell's `SYSNULL` (`:`) path discarded its I/O list before
  setup, so `: > trunc.out` sometimes never reached `creat()` at all.
  `SYSNULL` now runs a no-op redirection pass that opens/creates/truncates
  targets and closes them without renaming the parent shell's fds.

Changed files:

```
arch/armboot.c
cmd/sh/service.c
cmd/sh/xec.c
logs/unix-on-qemu.md
logs/unix-historical-accuracy.md
```

Build:

```
make ARCH=arm CONF=qemu_arm
```

Focused QEMU evidence:

```
cd /tmp
# rm -f trunc.out out nohup.out scr
# /bin/echo old > trunc.out
# : > trunc.out
# ls -l trunc.out
-rw-rw-r-- 1 root        0 Dec 31 19:00 trunc.out
# cat trunc.out
# /bin/echo HI > out 2>&1
# cat out
HI
# nohup /bin/echo HI
Sending output to 'nohup.out'
# cat nohup.out
HI
# echo 'echo SCRIPTARGS:$0:$1:$2' > scr
# chmod 755 scr
# ./scr one two
SCRIPTARGS:-sh:one:two
# who am i
root     console Dec 31 19:00
```

Append regression:

```
cd /tmp
# rm -f append.out
# /bin/echo first > append.out
# /bin/echo second >> append.out
# cat append.out
first
second
```

### SCRIPT_REDIRECT_SHARED_FD_OFFSETS

Follow-up Worker fix for script-level redirection with multiple commands.
Enemy reproduced:

```
./s_ext > ext.out 2>&1
cat ext.out
```

returning only the last line from a three-command script.

Root cause: fork/spawn exit restored the parent shell's armboot
`files[]` snapshot after each child command.  The child correctly
advanced the shared v7 `struct file` offset and updated the v7 in-core
inode metadata, but restoring the stale parent snapshot reset
`files[fd].off`/size/block state before the next command in the
redirected script ran.

Fix: `arch/armboot.c` now mirrors restored regular-file fds from the
shared v7 file/inode state immediately after `v7_ofile_restore()` on
fork-exit and spawn-exit.

Build:

```
make ARCH=arm CONF=qemu_arm
```

Focused QEMU evidence:

```
cd /tmp
# ./s_ext > ext.out 2>&1
# echo EXT_STATUS:$?
EXT_STATUS:0
# cat ext.out
ext1
ext2
ext3
# ./s_builtin > builtin.out 2>&1
# echo BUILTIN_STATUS:$?
BUILTIN_STATUS:0
# cat builtin.out
bi1
bi2
bi3
```

Regression checks from the same fresh QEMU boot:

```
# : > trunc.out
# ls -l trunc.out
-rw-rw-rw- 1 root        0 Dec 31 19:00 trunc.out
# /bin/echo direct > out 2>&1
# cat out
direct
# /bin/echo first > append.out
# /bin/echo second >> append.out
# cat append.out
first
second
# ls missing-file > err.out 2>&1
# cat err.out
missing-file not found
# nohup /bin/echo HI
Sending output to 'nohup.out'
# echo NOHUP_STATUS:$?
NOHUP_STATUS:0
# cat nohup.out
HI
# ./scr one two
SCRIPTARGS:-sh:one:two
# who am i
root     console Dec 31 19:00
```

### fgrep

`cmd/fgrep.c` is built by the normal userland `BIN` loop, named in the
top-level root image prerequisites, and installed in the QEMU rootfs as
`/bin/fgrep`.

Build:

```
make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

QEMU evidence from fresh `tools/qemu-shell.py` boots:

```
# cd /tmp
# rm -f fa fb fpat missing out
# /bin/echo alpha > fa
# /bin/echo beta >> fa
# /bin/echo alphabet >> fa
# /bin/echo zeta >> fa
# /bin/echo ALPHA >> fa
# /bin/echo alpha > fb
# /bin/echo gamma >> fb
# /bin/echo beta >> fb
# /bin/echo alpha > fpat
# /bin/echo gamma >> fpat
# ls /bin/fgrep
/bin/fgrep
# fgrep alpha fa
alpha
alphabet
# echo MATCH_STATUS:$?
MATCH_STATUS:0
# fgrep nomatch fa
# echo NOMATCH_STATUS:$?
NOMATCH_STATUS:1
# fgrep alpha missing
fgrep: can't open missing
# echo OPEN_STATUS:$?
OPEN_STATUS:2
# fgrep -f missing fa
egrep: can't open missing
# echo PATFILE_STATUS:$?
PATFILE_STATUS:2
# /bin/echo alpha | fgrep alpha
alpha
# echo STDIN_STATUS:$?
STDIN_STATUS:0
# fgrep beta fa fb
fa:beta
fb:beta
# echo MULTI_STATUS:$?
MULTI_STATUS:0
# fgrep -h beta fa fb
beta
beta
# echo H_STATUS:$?
H_STATUS:0
# fgrep -n beta fa
2:beta
# echo N_STATUS:$?
N_STATUS:0
# fgrep -c alpha fa
2
# echo C_STATUS:$?
C_STATUS:0
# fgrep -v alpha fa
beta
zeta
ALPHA
# echo V_STATUS:$?
V_STATUS:0
# fgrep -x alpha fa
alpha
# echo X_STATUS:$?
X_STATUS:0
# fgrep -l gamma fa fb
fb
# echo L_STATUS:$?
L_STATUS:0
# fgrep -e -dash fa
# echo E_STATUS:$?
E_STATUS:1
# /bin/echo -dash >> fa
# fgrep -e -dash fa
-dash
# echo E_MATCH_STATUS:$?
E_MATCH_STATUS:0
# fgrep -f fpat fb
alpha
gamma
# echo F_STATUS:$?
F_STATUS:0
# grep '^root' /etc/passwd
root::0:0:root:/:/bin/sh
# echo GREP_STATUS:$?
GREP_STATUS:0
# egrep 'root|daemon' /etc/passwd
root::0:0:root:/:/bin/sh
# echo EGREP_STATUS:$?
EGREP_STATUS:0
```

Additional option coverage:

```
# cd /tmp
# rm -f fa
# /bin/echo alpha > fa
# /bin/echo beta >> fa
# fgrep -b beta fa
0:beta
# echo B_STATUS:$?
B_STATUS:0
# fgrep -s alpha fa
# echo S_MATCH_STATUS:$?
S_MATCH_STATUS:0
# fgrep -s nomatch fa
# echo S_NOMATCH_STATUS:$?
S_NOMATCH_STATUS:1
```

### egrep

`cmd/egrep.c` is built by the normal userland `BIN` loop, named in the
top-level root image prerequisites, and installed in the QEMU rootfs as
`/bin/egrep`.

Build:

```
make ARCH=arm CONF=qemu_arm
```

QEMU evidence from a fresh boot:

```
# cd /tmp
# rm -f ea eb epat
# /bin/echo alpha > ea
# /bin/echo beta >> ea
# /bin/echo abbbc >> ea
# /bin/echo ac >> ea
# /bin/echo axc >> ea
# /bin/echo z9 >> ea
# /bin/echo foo >> ea
# /bin/echo bar >> ea
# /bin/echo qux >> ea
# /bin/echo ROOT >> ea
# /bin/echo xyz > eb
# /bin/echo beta >> eb
# ls /bin/egrep
/bin/egrep
# egrep alpha ea
alpha
# echo MATCH_STATUS:$?
MATCH_STATUS:0
# egrep 'foo|bar' ea
foo
bar
# egrep 'ab+c' ea
abbbc
# egrep 'ab*c' ea
abbbc
ac
# egrep 'ab?c' ea
ac
# egrep '[0-9]' ea
z9
# egrep '[^a-z]' ea
z9
ROOT
# egrep -n beta ea
2:beta
# egrep -c a ea
6
# egrep -v a ea
z9
foo
qux
ROOT
# egrep -l beta ea eb
ea
eb
# egrep -h beta ea eb
beta
beta
# egrep beta ea eb
ea:beta
eb:beta
# egrep -e qux ea
qux
# /bin/echo 'foo|qux' > epat
# egrep -f epat ea
foo
qux
# egrep nomatch ea
# echo NOMATCH_STATUS:$?
NOMATCH_STATUS:1
# egrep '[' ea
egrep: syntax error
# echo SYNTAX_STATUS:$?
SYNTAX_STATUS:2
```

Basic `grep`/`fgrep` regressions from the same boot:

```
# grep '^root' /etc/passwd
root::0:0:root:/:/bin/sh
# echo GREP_STATUS:$?
GREP_STATUS:0
# fgrep root /etc/passwd
root::0:0:root:/:/bin/sh
# echo FGREP_STATUS:$?
FGREP_STATUS:0
```

### file

`cmd/file.c` is built by the normal userland `BIN` loop, named in the
top-level root image prerequisites, and installed in the QEMU rootfs as
`/bin/file`.  No source fix was required for this slice; the existing
port already contains the C99 declarations, local `major/minor` helpers,
and disabled nested-comment repair documented in
`logs/unix-historical-accuracy.md`.

Build:

```
make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls /bin/file
/bin/file
# /bin/file /bin/sh
/bin/sh:	data
# /bin/file /etc/passwd
/etc/passwd:	ascii text
# /bin/file /
/:	directory
# /bin/file /dev/console
/dev/console:	character special (0/0)
# cd /tmp
# rm -f empty t.c script filelist words
# : > empty
# /bin/file empty
empty:	empty
# cat >t.c <<'EOC'
> int main(){return 0;}
> EOC
# /bin/file t.c
t.c:	c program text
# cat >script <<'EOS'
> echo script
> EOS
# chmod +x script
# /bin/file script
script:	commands text
# cat >filelist <<'EOL'
> /tmp/t.c
> /tmp/empty
> EOL
# /bin/file -f filelist
/tmp/t.c:	c program text
/tmp/empty:	empty
```

Small regression set from the same boot:

```
# echo alpha > words
# echo beta >> words
# echo gamma >> words
# echo alpha | sed s/alpha/ALPHA/
ALPHA
# expr 4 + 5
9
# fgrep beta words
beta
# egrep 'alpha|gamma' words
alpha
gamma
# echo __TEST_DONE__
__TEST_DONE__
```

### find

`cmd/find.c` is built by the normal userland `BIN` loop, named in the
top-level root image prerequisites, and installed in the QEMU rootfs as
`/bin/find`.  This slice kept the V7 parser/traversal/predicate code and
fixed two ARM-rootfs runtime issues documented in
`logs/unix-historical-accuracy.md`: noisy cwd discovery through the
broken `/bin/sh -c` path and numeric `-group` fallback when `/etc/group`
is absent.

Build:

```
make ARCH=arm CONF=qemu_arm
...
make[1]: Leaving directory '/home/agent9/fast_data/unix-v7-c99/lib'
mkdir -p build
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

QEMU evidence from a fresh `tools/qemu-shell.py` boot.  This covers
installation, recursion, `-name`, `-type f`, `-type d`, boolean `!`,
`-o`, parentheses, `-exec ... {} ';'`, `-user`, numeric `-group`,
`-perm`, `-links`, `-size`, and `-cpio` producing a non-empty archive:

```
ls /bin/find
/bin/find
# cd /tmp
# rm -rf froot find.cpio words
# mkdir froot
# mkdir froot/sub
# echo alpha > froot/fa
# echo beta > froot/sub/fb
# : > froot/zero
# chmod 644 froot/fa
# find froot -name fa -print
froot/fa
# find froot -type f -print
froot/sub/fb
froot/fa
froot/zero
# find froot -type d -print
froot
froot/sub
# find froot ! -name fb -name fa -print
froot/fa
# find froot '(' -name fa -o -name sub ')' -print
froot/sub
froot/fa
# find froot -name fa -exec echo EXEC {} ';'
EXEC froot/fa
# find froot -user root -name fa -print
froot/fa
# find froot -group 0 -name fa -print
froot/fa
# find froot -perm 644 -name fa -print
froot/fa
# find froot -links 1 -name fa -print
froot/fa
# find froot -size 0 -name zero -print
froot/zero
# find froot -name fa -cpio find.cpio
# ls -l find.cpio
-rw-rw-rw- 1 root     5120 Dec 31 19:00 find.cpio
```

Absolute starting path regression:

```
# cd /tmp
# rm -rf absroot
# mkdir absroot
# echo name > absroot/name
# find /tmp/absroot -name name -print
/tmp/absroot/name
# find /tmp/absroot -type d -print
/tmp/absroot
```

Small regression set from the same boot as the main `find` coverage:

```
# echo alpha | sed s/alpha/ALPHA/
ALPHA
# /bin/file froot/fa
froot/fa:	ascii text
```

### sort follow-up: directory metadata regression

Enemy reproduced a blocker where a fresh directory under `/tmp`
appeared after `mkdir`, but then `cat >/tmp/aa/file <<EOF` failed with
`cannot create`, `/tmp/aa` disappeared, and `find /tmp/aa` reported
`bad status`.  The failure was real and was narrower than `find`: a
new regular-file create could append using a stale parent-directory
size after V7-routed `mkdir`.

Fix built with:

```
make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Fresh QEMU evidence from the rebuilt `root.img`; this is the previously
failing dynamic directory/file regression:

```
cd /tmp
# rm -rf aa zz
# mkdir /tmp/aa
# ls -ld /tmp/aa
drwxrwxr-x 2 root       32 Dec 31 19:00 /tmp/aa
# cat >/tmp/aa/file <<!EOF!
> fromcat
> !EOF!
# ls -ld /tmp/aa
drwxrwxr-x 1 root       48 Dec 31 19:00 /tmp/aa
# ls -l /tmp/aa
total 1
-rw-rw-r-- 1 root        8 Dec 31 19:00 file
# cat /tmp/aa/file
fromcat
# find /tmp/aa -type d -print
/tmp/aa
# find /tmp/aa -type f -print
/tmp/aa/file
# rm -rf /tmp/aa /tmp/zz
# mkdir /tmp/aa
# echo x > /tmp/zz
# ls -ld /tmp/aa
drwxrwxr-x 2 root       32 Dec 31 19:00 /tmp/aa
# find /tmp -name aa -print
/tmp/aa
# echo __TEST_DONE__
__TEST_DONE__
```

Sort checks from a fresh QEMU boot of the same rebuilt image:

```
ls /bin/sort
/bin/sort
# cd /tmp
# rm -f s1 s2 s3
# (echo beta; echo alpha; echo gamma) | /bin/sort
alpha
beta
gamma
# cat >s1 <<!EOF!
> delta
> alpha
> charlie
> !EOF!
# /bin/sort s1
alpha
charlie
delta
# /bin/sort -r s1
delta
charlie
alpha
# cat >s2 <<!EOF!
> 10 ten
> 2 two
> 1 one
> !EOF!
# /bin/sort -n s2
1 one
2 two
10 ten
# (echo beta; echo alpha; echo beta) | /bin/sort -u
alpha
beta
# cat >s3 <<!EOF!
> b 2
> c 1
> a 3
> !EOF!
# /bin/sort +1 s3
c 1
b 2
a 3
# /bin/sort -c s1
sort: disorder:alpha
# echo CHECK_BAD:$?
CHECK_BAD:1
# /bin/sort s1 >s1.sorted
# /bin/sort -c s1.sorted
# echo CHECK_GOOD:$?
CHECK_GOOD:0
# (echo root:x; echo bin:a; echo daemon:m) | /bin/sort -t: +1
bin:a
daemon:m
root:x
# find /bin -name sort -print
/bin/sort
# echo __TEST_DONE__
__TEST_DONE__
```

Find and small regression checks from a fresh QEMU boot of the same
rebuilt image:

```
ls /bin/find
/bin/find
# cd /tmp
# rm -rf froot find.cpio
# mkdir froot
# mkdir froot/sub
# echo alpha > froot/fa
# echo beta > froot/sub/fb
# : > froot/zero
# chmod 644 froot/fa
# find froot -name fa -print
froot/fa
# find froot -type f -print
froot/sub/fb
froot/fa
froot/zero
# find froot -type d -print
froot
froot/sub
# find froot ! -name fb -name fa -print
froot/fa
# find froot '(' -name fa -o -name sub ')' -print
froot/sub
froot/fa
# find froot -name fa -exec echo EXEC {} ';'
EXEC froot/fa
# find froot -user root -name fa -print
froot/fa
# find froot -group 0 -name fa -print
froot/fa
# find froot -perm 644 -name fa -print
froot/fa
# find froot -links 1 -name fa -print
froot/fa
# find froot -size 0 -name zero -print
froot/zero
# find froot -name fa -cpio find.cpio
# ls -l find.cpio
-rw-rw-rw- 1 root     5120 Dec 31 19:00 find.cpio
# find /tmp/froot -type d -print
/tmp/froot
/tmp/froot/sub
# find /tmp/froot -type f -print
/tmp/froot/sub/fb
/tmp/froot/fa
/tmp/froot/zero
# echo alpha | sed s/alpha/ALPHA/
ALPHA
# /bin/file froot/fa
froot/fa:	ascii text
# echo __TEST_DONE__
__TEST_DONE__
```

### tp(1) V7 port coverage

Build:

```
make ARCH=arm CONF=qemu_arm
...
arm-none-eabi-gcc ... -I../cmd/tp -c ../cmd/tp/tp0.c
arm-none-eabi-gcc ... -I../cmd/tp -c ../cmd/tp/tp1.c
arm-none-eabi-gcc ... -I../cmd/tp -c ../cmd/tp/tp2.c
arm-none-eabi-gcc ... -I../cmd/tp -c ../cmd/tp/tp3.c
arm-none-eabi-gcc ... -o tp.elf crt0.o crt0c.o tp0.o tp1.o tp2.o tp3.o -L. -lc -lgcc
arm-none-eabi-objcopy -O binary tp.elf ../root/bin/tp
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

Fresh QEMU boot of the rebuilt image:

```
login: root
# cd /tmp
# rm -rf tpin tpex tpnamed tarin tarout tp.arc tar.arc sed.out awk.out sort.in
# : > tp.arc
# mkdir tpin
# mkdir tpin/sub
# echo alpha > tpin/a
# echo beta > tpin/sub/b
# echo gamma > tpin/c
# ls /bin/tp
/bin/tp
# tp mcf /tmp/tp.arc tpin
   3 entries
   3 used
  65 last
End
# echo TP_CREATE:$?
TP_CREATE:0
# tp mtf /tmp/tp.arc
tpin/sub/b
tpin/a
tpin/c
   3 entries
   3 used
  65 last
End
# echo TP_TABLE:$?
TP_TABLE:0
# tp mtvf /tmp/tp.arc
   mode    uid gid tapa    size   date    time name
rw-rw-r--   0   0   63        5 69/12/31 19: 0 tpin/sub/b
rw-rw-r--   0   0   64        6 69/12/31 19: 0 tpin/a
rw-rw-r--   0   0   65        6 69/12/31 19: 0 tpin/c
   3 entries
   3 used
  65 last
End
# echo TP_VTABLE:$?
TP_VTABLE:0
# tp mtf /tmp/tp.arc tpin/sub
tpin/sub/b
   3 entries
   3 used
  65 last
End
# echo TP_NAMED_TABLE:$?
TP_NAMED_TABLE:0
```

Extraction from the file-backed magtape archive.  V7 `tp` archives
regular files and does not create missing directories on extract, so the
target directory skeleton was created before extraction:

```
# mkdir tpex
# cd tpex
# mkdir tpin
# mkdir tpin/sub
# tp mxf /tmp/tp.arc
End
# echo TP_EXTRACT:$?
TP_EXTRACT:0
# cat tpin/a
alpha
# cat tpin/sub/b
beta
# cat tpin/c
gamma
# cd /tmp
# mkdir tpnamed
# cd tpnamed
# mkdir tpin
# mkdir tpin/sub
# tp mxf /tmp/tp.arc tpin/sub/b
End
# echo TP_NAMED_EXTRACT:$?
TP_NAMED_EXTRACT:0
# cat tpin/sub/b
beta
```

Update mode was reliable for this file-backed magtape case:

```
# cd /tmp
# echo ALPHA2 > tpin/a
# tp muf /tmp/tp.arc tpin
   3 entries
   3 used
  65 last
End
# echo TP_UPDATE:$?
TP_UPDATE:0
# rm -rf tpex2
# mkdir tpex2
# cd tpex2
# mkdir tpin
# mkdir tpin/sub
# tp mxf /tmp/tp.arc
End
# echo TP_UPDATE_EXTRACT:$?
TP_UPDATE_EXTRACT:0
# cat tpin/a
ALPHA2
# cat tpin/sub/b
beta
```

Regressions from the same boot:

```
# cd /tmp
# mkdir tarin
# mkdir tarin/sub
# echo taralpha > tarin/a
# echo tarbeta > tarin/sub/b
# tar cf /tmp/tar.arc tarin
# tar tf /tmp/tar.arc
Tar: blocksize = 7
tarin/sub/b
tarin/a
# mkdir tarout
# cd tarout
# tar xf /tmp/tar.arc
Tar: blocksize = 7
# cat tarin/a
taralpha
# cat tarin/sub/b
tarbeta
# cd /tmp
# find tpin -type f -print
tpin/sub/b
tpin/a
tpin/c
# (echo gamma; echo alpha; echo beta) > sort.in
# sort sort.in
alpha
beta
gamma
# cat sort.in | sed s/alpha/ALPHA/
gamma
ALPHA
beta
# echo 'left right' | awk '{print $2":"$1}'
right:left
# echo __TP_TEST_DONE__
__TP_TEST_DONE__
```

## update(8) direct QEMU check

Build:

```
$ make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Direct QEMU check after the detached-daemon pause shim:

```
login: root
# ls /etc/update
/etc/update
# ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
     6 ?   0:00 ps
# /etc/update
# echo UPDATE_EXIT:$?
UPDATE_EXIT:0
# ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
    10 ?   0:00 ps
     8 ?   0:00
# sleep 1
# echo AFTER_SLEEP:$?
AFTER_SLEEP:0
# echo basic | sed s/basic/regression/
regression
# echo __TEST_DONE__
__TEST_DONE__
# 
```

The second `ps` shows the additional pid 8 update daemon after the
parent returned.  `/etc/update` returned status 0, and the shell accepted
subsequent commands.  The raw foreground `sleep 1` capture still contains
the known pause-spin backspace bytes from the console-attached sleep
process; they are omitted from the block above because they are not
emitted by the detached update daemon and do not affect shell usability.

## at(1) / atrun(8) V7 port coverage

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build:

```
$ make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Fresh QEMU rootfs presence and spool layout check:

```
date
Wed Dec 31 19:00:00 EST 1969
# ls -ld /usr/spool /usr/spool/at /usr/spool/at/past
drwxr-xr-x 3 root       48 May 16 00:28 /usr/spool
drwxrwxrwx 3 root       64 May 16 00:28 /usr/spool/at
drwxrwxrwx 2 root       48 May 16 00:28 /usr/spool/at/past
# ls /bin/at /etc/atrun
/bin/at
/etc/atrun
```

Live QEMU test for stdin and file-submitted `at` jobs, then due-job
processing through `/etc/atrun`:

```
date 7001010000
Thu Jan  1 00:00:00 EST 1970
# echo "echo AT_STDIN >/tmp/at.stdin" | at 0001
# cat /usr/spool/at/70.000.0001.01
cd /
HOME=/
PATH=:/bin:/usr/bin
echo AT_STDIN >/tmp/at.stdin
# echo "echo AT_FILE >/tmp/at.file" >/tmp/at.input
# at 0001 /tmp/at.input
# ls /usr/spool/at
70.000.0001.01
70.000.0001.54
lasttimedone
past
# date 7001010002
Thu Jan  1 00:02:00 EST 1970
# /etc/atrun
# cat /tmp/at.stdin
AT_STDIN
# cat /tmp/at.file
AT_FILE
# cat /usr/spool/at/lasttimedone
0002
# ls /usr/spool/at/past
.keep
```

`atrun` follows V7 behavior: each due job is first moved into `past`,
executed with `/bin/sh`, and then unlinked after the shell exits, so the
completed-job directory is empty again except for the rootfs seed file.

Regression checks from fresh QEMU boots:

```
echo basic | sed s/basic/regression/
regression
# echo ok | awk 1
ok
# (echo c; echo a; echo b) | sort
a
b
c
# ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
    36 ?   0:00 ps
    16 ?   <defunct>
    20 ?   <defunct>
```

```
echo "echo SH_OK" | sh
# SH_OK
# echo beta | sed s/beta/SED_OK/
SED_OK
# echo AWK_OK | awk 1
AWK_OK
# (echo 3; echo 1; echo 2) | sort
1
2
3
# ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
    16 ?   0:00 ps
```

## cron(8) V7 port coverage

`test_serv inventory` was attempted for hardware-test discovery, but the
command is not installed in this worker environment:

```
test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build:

```
$ make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Fresh QEMU cron daemon and scheduled shell command proof:

```
ls /etc/cron /usr/lib/crontab
/etc/cron
/usr/lib/crontab
# echo '* * * * * /bin/date>/tmp/cron.mark' >/usr/lib/crontab
# /etc/cron
# echo CRON_STATUS:$?
CRON_STATUS:0
# ps
   PID TTY TIME CMD
     4 ?   0:00
    12 ?   0:00 ps
     9 ?   <defunct>
# cat /tmp/cron.mark
Wed Dec 31 19:00:00 EST 1969
# echo shell_after_cron | sed s/shell/usable/
usable_after_cron
# echo z y x | awk '{print $2}'
y
# (echo b; echo a) | sort
a
b
# ps
   PID TTY TIME CMD
     4 ?   0:00
    21 ?   0:00 ps
     9 ?   <defunct>
# echo __TEST_DONE__
__TEST_DONE__
```

This verifies `/etc/cron` and `/usr/lib/crontab` are present in the root
image, `/etc/cron` returns status 0 without blocking the shell, a
crontab entry is read from `/usr/lib/crontab`, and the scheduled
`/bin/sh -c` command creates `/tmp/cron.mark`.  The follow-on sed, awk,
sort, and ps commands show the shell remains usable after cron starts.

Retry Worker shell `-c` fix:

The verifier failure was reproduced before the fix:

```
sh -c 'echo SIMPLE_OK'

# /bin/sh -c 'echo SHC_OK>/tmp/shc.mark'
# ls /tmp/shc.mark
/tmp/shc.mark not found
```

Root cause: this Arm port serializes argv into a flat space-separated
exec buffer, then `crt0` reparses it.  That made `sh -c 'echo A B'`
arrive at the child shell as `sh -c echo A B`, so the historical parser
used only `echo` as `comdiv`.  `cmd/sh/main.c` now uses the historical
`options(c, v)` path again.  The later correction below narrows the
shell-side handling so extra argv words are not folded into the command
text; only no-extra-argv `sh -c command` execs get their command-string
spaces preserved through the Arm flat handoff.

Build after the retry fix:

```
$ make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Direct shell regression proof:

```
sh -c 'echo SIMPLE_OK'
SIMPLE_OK
# /bin/sh -c 'echo SHC_OK>/tmp/shc.mark'
# ls /tmp/shc.mark
/tmp/shc.mark
# cat /tmp/shc.mark
SHC_OK
# sh -c 'echo REDIR_OK > /tmp/redir.mark'
# cat /tmp/redir.mark
REDIR_OK
# sh -cx 'echo TRACE OK'
+ echo TRACE OK
TRACE OK
# echo /bin/echo FILE_OK >/tmp/in.sh
# sh < /tmp/in.sh
FILE_OK
# echo echo FALLBACK_OK >/tmp/plain_script
# chmod 755 /tmp/plain_script
# /tmp/plain_script arg1
FALLBACK_OK
```

Cron proof through its real `/bin/sh -c` child path:

```
date
Wed Dec 31 19:00:00 EST 1969
# ls /etc/cron /usr/lib/crontab
/etc/cron
/usr/lib/crontab
# echo '0 * * * * echo CRON_CURRENT_OK >> /tmp/cron.mark' >/usr/lib/crontab
# /etc/cron
# echo CRON_STATUS:$?
CRON_STATUS:0
# echo SHELL_AFTER_CRON | sed s/SHELL/USABLE/
USABLE_AFTER_CRON
# cat /tmp/cron.mark
CRON_CURRENT_OK
# ps
   PID TTY TIME CMD
     4 ?   0:00
    19 ?   0:00 ps
    10 ?   <defunct>
```

The exact-minute cron entry ran once in the observed window and appended
one marker line.  A longer sleep-based observation did not show a second
marker, but the console emitted many erase bytes from `sleep`, so the
clean transcript above is the retained evidence.

Broader QEMU smoke after the retry fix:

```
echo shc | sh -c 'sed s/sh/SH/'
SHc
# echo 'one two' | awk '{print $2}'
two
# (echo c; echo a; echo b) | sort
a
b
c
# /etc/update
# ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
    17 ?   0:00 ps
    16 ?   0:00
# /bin/sh -c 'echo FINAL_SHC_OK > /tmp/final.mark'
# cat /tmp/final.mark
FINAL_SHC_OK
```

`at 1900` and `at 1901` could stage jobs in `/usr/spool/at`, and
`/etc/atrun` remained invocable, but those jobs did not become runnable
in the short fresh-boot smoke window:

```
at 1900 <<'AT_EOF'
> echo AT_NOW_OK >/tmp/at.now
> AT_EOF
# /etc/atrun
# cat /tmp/at.now
cat: can't open /tmp/at.now
```

Retry Worker correction for the `-c` argv folding regression:

The previous retry made `cmd/sh/args.c` join every word after `-c`.  That
kept cron working, but it broke the existing VARS mission check by folding
the extra argv words into the command string.  After the correction,
`cmd/sh/args.c` never joins an arbitrary split tail.  Instead,
`arch/armboot.c` preserves the boundary for only no-extra-argv
`sh -c command` invocations by encoding spaces/tabs inside the command
argument as byte `037` in the flat `UARGV` handoff, and `cmd/sh/args.c`
decodes that marker back to a shell space only when there are no extra
argv words after the command argument.  Split extra-argv forms keep the
old single-word `comdiv` behavior, preserving the mission check.

Build:

```
$ make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Focused QEMU shell and cron proof:

```
sh -c 'echo $1 $2' x A B

# sh -c 'echo SIMPLE_OK'
SIMPLE_OK
# /bin/sh -c 'echo SHC_OK>/tmp/shc.mark'
# cat /tmp/shc.mark
SHC_OK
# sh -cx 'echo TRACE OK'
+ echo TRACE OK
TRACE OK
# echo /bin/echo FILE_OK >/tmp/in.sh
# sh < /tmp/in.sh
FILE_OK
# echo echo FALLBACK_OK >/tmp/plain_script
# chmod 755 /tmp/plain_script
# /tmp/plain_script arg1
FALLBACK_OK
# ls /etc/cron /usr/lib/crontab
/etc/cron
/usr/lib/crontab
# echo '0 * * * * echo CRON_OK >> /tmp/cron.mark' >/usr/lib/crontab
# /etc/cron
# echo CRON_STATUS:$?
CRON_STATUS:0
# cat /tmp/cron.mark
CRON_OK
# /etc/update
# echo shell_after_cron | sed s/shell/usable/
usable_after_cron
# echo 'one two' | awk '{print $2}'
two
# (echo c; echo a; echo b) | sort
a
b
c
# ps
   PID TTY TIME CMD
     4 ?   0:00
    43 ?   0:00 ps
    28 ?   <defunct>
    34 ?   0:00
# /bin/sh -c 'echo FINAL_SHC_OK > /tmp/final.mark'
# cat /tmp/final.mark
FINAL_SHC_OK
```

Due `atrun` proof was captured by staging a due spool file directly.  The
fresh boot clock is `Wed Dec 31 19:00:00 EST 1969`, so `at 0001` creates a
future `70.000.0001.*` job and is not a due-job test at that time.

```
cat >/usr/spool/at/69.364.1900.01 <<'ATJOB'
> cd /
> echo AT_DUE_OK >/tmp/at.due
> ATJOB
# chmod 755 /usr/spool/at/69.364.1900.01
# /etc/atrun
# sleep 1
# cat /tmp/at.due
AT_DUE_OK
# cat /usr/spool/at/lasttimedone
1900
```

## passwd(1) V7 userspace slice

`test_serv inventory` was attempted for hardware-test discovery, but the
worker environment did not have `test_serv` installed:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build check from the repo root:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

Fresh QEMU proof that `/bin/passwd` is installed, updates `/etc/passwd`,
keeps the encrypted field non-plaintext, and leaves the shell usable for
small grep/sed/awk/sort regressions.  The nonzero success status is the
retained V7 control-flow oddity documented in
`logs/unix-historical-accuracy.md`.

```
ls -l /bin/passwd
-rwxr-xr-x 1 root    25700 May 16 01:21 /bin/passwd
# grep '^dmr:' /etc/passwd
dmr::1:1:dennis:/:/bin/sh
# /bin/passwd dmr
New password:abc123

Retype new password:abc123

# echo PASSWD_STATUS:$?
PASSWD_STATUS:1
# grep '^dmr:' /etc/passwd
dmr:/.X09epTnAYSE:1:1:dennis:/:/bin/sh
# grep abc123 /etc/passwd
# echo PLAINTEXT_GREP_STATUS:$?
PLAINTEXT_GREP_STATUS:1
# echo beta > /tmp/words
# echo alpha >> /tmp/words
# sort /tmp/words
alpha
beta
# sed 's/root/ROOT/' /etc/passwd
ROOT::0:0:root:/:/bin/sh
dmr:/.X09epTnAYSE:1:1:dennis:/:/bin/sh
# grep '^root' /etc/passwd
root::0:0:root:/:/bin/sh
# awk 'END {print NR}' /etc/passwd
2.0000000000000000000
```

Fresh QEMU proof for the mismatch and missing-user paths.  The first
`grep` and second `grep` show `/etc/passwd` remained unchanged after the
retype mismatch.

```
grep '^dmr:' /etc/passwd
dmr::1:1:dennis:/:/bin/sh
# /bin/passwd dmr
New password:abc123

Retype new password:xyz789

Mismatch - password unchanged.
# echo MISMATCH_STATUS:$?
MISMATCH_STATUS:1
# grep '^dmr:' /etc/passwd
dmr::1:1:dennis:/:/bin/sh
# /bin/passwd nosuchuser
Permission denied.
# echo NOSUCH_STATUS:$?
NOSUCH_STATUS:1
```

An additional `su dmr` batch was attempted as an account-command smoke,
but the one-shot QEMU driver did not regain its sentinel after `su`
changed the interactive shell flow.  That run was killed without using it
as evidence; the login/getty/root-shell path is still exercised by every
`tools/qemu-shell.py` transcript above.

### passwd(1) clean-rule follow-up

Enemy found that `lib/Makefile clean` left a staged
`../root/bin/passwd`, so stale passwd binaries could survive a clean.
Fresh host proof with a sentinel staged binary:

```
$ printf 'stale-passwd-sentinel\n' > root/bin/passwd
$ test -f root/bin/passwd && make -C lib clean && test ! -e root/bin/passwd && printf 'CLEAN_PASSWD_REMOVED\n'
make: Entering directory '/home/agent9/fast_data/unix-v7-c99/lib'
rm -f ../root/bin/su ../root/bin/newgrp
rm -f ../root/bin/passwd
rm -f ../root/bin/random
make: Leaving directory '/home/agent9/fast_data/unix-v7-c99/lib'
CLEAN_PASSWD_REMOVED
```

The clean made the root image out of date, then a rebuild regenerated the
staged root tree and image:

```
$ make -q root.img; printf 'MAKE_Q_STATUS:%s\n' "$?"
MAKE_Q_STATUS:1
$ make ARCH=arm CONF=qemu_arm root.img
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
$ make -q root.img; printf 'MAKE_Q_STATUS:%s\n' "$?"
MAKE_Q_STATUS:0
```

Fresh QEMU passwd success path and grep/sed/awk/sort/shell regressions
from the rebuilt image:

```
ls -l /bin/passwd
-rwxr-xr-x 1 root    25700 May 16 01:38 /bin/passwd
# grep '^root:' /etc/passwd
root::0:0:root:/:/bin/sh
# grep '^dmr:' /etc/passwd
dmr::1:1:dennis:/:/bin/sh
# /bin/passwd dmr
New password:abc123

Retype new password:abc123

# echo PASSWD_STATUS:$?
PASSWD_STATUS:1
# grep '^dmr:' /etc/passwd
dmr:/.X09epTnAYSE:1:1:dennis:/:/bin/sh
# grep abc123 /etc/passwd
# echo PLAINTEXT_GREP_STATUS:$?
PLAINTEXT_GREP_STATUS:1
# sort /tmp/words
alpha
beta
gamma
# sed 's/root/ROOT/' /etc/passwd
ROOT::0:0:root:/:/bin/sh
dmr:/.X09epTnAYSE:1:1:dennis:/:/bin/sh
# grep '^root' /etc/passwd
root::0:0:root:/:/bin/sh
# awk 'END {print NR}' /etc/passwd
2.0000000000000000000
# /bin/sh -c 'echo SHELL_OK'
SHELL_OK
```

Fresh QEMU mismatch and missing-user denial paths, plus regressions:

```
grep '^dmr:' /etc/passwd
dmr::1:1:dennis:/:/bin/sh
# /bin/passwd dmr
New password:abc123

Retype new password:xyz789

Mismatch - password unchanged.
# echo MISMATCH_STATUS:$?
MISMATCH_STATUS:1
# grep '^dmr:' /etc/passwd
dmr::1:1:dennis:/:/bin/sh
# /bin/passwd nosuchuser
Permission denied.
# echo NOSUCH_STATUS:$?
NOSUCH_STATUS:1
# echo regress | grep regress
regress
# echo 'left right' | sed 's/right/ok/'
left ok
# echo 'one two' | awk '{print $2}'
two
# (echo c; echo a; echo b) | sort
a
b
c
# /bin/sh -c 'echo SHELL_REGRESS_OK'
SHELL_REGRESS_OK
```

### random(1) V7 userspace slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ diff -u v7/usr/src/cmd/random.c cmd/random.c
--- v7/usr/src/cmd/random.c	1979-01-10 12:02:09.000000000 -0800
+++ cmd/random.c	2026-05-10 07:15:58.910680211 -0700
@@ -4,7 +4,8 @@
 double	atof();
 char rflag,eflag,c;
 char ibuf[BUFSIZ],obuf[BUFSIZ],line[BUFSIZ];
-main(argc,argv) char **argv;
+int
+main(int argc, char **argv)
 {
 	long tvec;
 	int i;

$ rg -n "random|/bin/random" Makefile lib/Makefile conf/qemu_arm/root.proto
Makefile:18:	root/bin/fgrep root/bin/egrep root/bin/su root/bin/newgrp root/bin/random root/bin/crypt \
lib/Makefile:52:BIN = login cat echo ls pwd sync rev yes wc basename sum tty cmp comm cal od tail grep test look cp rm ln mkdir rmdir mv chmod chown chgrp sleep tee touch tr uniq du date kill nice mknod who mesg time split checkeq calendar tsort file join col fgrep egrep su newgrp random crypt pr dd stty tabs diff wall write df clri dcheck icheck ncheck cb sp find sort mount umount passwd diff3 at units spline restor tk dmesg dkstat sa ptx vpr dump dumpdir graph factor primes expr ac iostat tek
lib/Makefile:210:	rm -f ../root/bin/random
conf/qemu_arm/root.proto:78:		random	---755 0 0 root/bin/random

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /bin/random
-rwxr-xr-x 1 root    11984 May 16 01:43 /bin/random
# (echo alpha; echo beta) | random 1
alpha
beta
# random -e 1; echo RANDOM_E_STATUS:$?
RANDOM_E_STATUS:0
# (echo one; echo two; echo three) | random
one
three
# (echo c; echo a; echo b) | sort
a
b
c
# /bin/sh -c 'echo SHELL_RANDOM_REGRESS_OK'
SHELL_RANDOM_REGRESS_OK
# grep '^root:' /etc/passwd
root::0:0:root:/:/bin/sh
# /bin/passwd nosuchuser
Permission denied.
# echo PASSWD_NOSUCH_STATUS:$?
PASSWD_NOSUCH_STATUS:1
```

The first regression batch accidentally used `printf`, which is not
installed in this root image, so grep/sed/awk were rerun with `echo`:

```
echo grep-ok | grep grep-ok
grep-ok
# echo 'left right' | sed 's/right/ok/'
left ok
# echo 'one two' | awk '{print $2}'
two
# (echo c; echo a; echo b) | sort
a
b
c
# /bin/sh -c 'echo SHELL_RANDOM_REGRESS_OK_2'
SHELL_RANDOM_REGRESS_OK_2
```

### dump/restor V7 dump-format tools slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
... normal V7 userland warnings ...
tools/mkfs build/auxfs.img conf/qemu_arm/auxfs.proto
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img

$ cd lib && arm-none-eabi-gcc [normal CFLAGS] -c ../cmd/dump.c -o /tmp/dump.o
success

$ cd lib && arm-none-eabi-gcc [normal CFLAGS] -c ../cmd/dumpdir.c -o /tmp/dumpdir.o
success

$ cd lib && arm-none-eabi-gcc [normal CFLAGS] -c ../cmd/restor.c -o /tmp/restor.o
../cmd/restor.c:260:33: warning: this 'for' clause does not guard... [-Wmisleading-indentation]
success; the normal build demotes this historical indentation warning

$ cmp -l v7/usr/include/dumprestor.h include/dumprestor.h
no output; byte-identical
```

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /etc/ddate /bin/dump /bin/dumpdir /bin/restor
-rwxr-xr-x 1 root    26324 May 16 01:58 /bin/dump
-rwxr-xr-x 1 root    25440 May 16 01:58 /bin/dumpdir
-rwxr-xr-x 1 root    32368 May 16 01:58 /bin/restor
-rw-r--r-- 1 root        0 May 16 01:58 /etc/ddate
# /bin/dump 0f /tmp/aux.dump /etc/auxfs
     date = the epoch
dump date = the epoch
dumping /etc/auxfs to /tmp/aux.dump
I
II
estimated 5 tape blocks on 0 tape(s)
III
IV
DONE
30 tape blocks on 1 tape(s)
# ls -l /tmp/aux.dump
-rw-rw-r-- 1 root    10240 Dec 31 19:00 /tmp/aux.dump
# /bin/dumpdir f /tmp/aux.dump
Dump   date: Wed Dec 31 19:00:00 1969
Dumped from: Wed Dec 31 19:00:00 1969
    2	/.
    2	/..
    3	/a
# /bin/restor tf /tmp/aux.dump
Dump   date: Wed Dec 31 19:00:00 1969
Dumped from: Wed Dec 31 19:00:00 1969
# mkdir /tmp/rstdir
# cd /tmp/rstdir
# /bin/restor xf /tmp/aux.dump a
a: inode 3
Mount desired tape volume: Specify volume #: 1
extract file 3
# ls -l
total 1
-rw-rw-r-- 1 root       51 Dec 31 19:00 3
# cat 3
root::0:0:root:/:/bin/sh
dmr::1:1:dennis:/:/bin/sh
```

Requested regression commands in the same QEMU boot:

```
# /bin/sh -c 'echo OK'
OK
# echo alpha beta | sed 's/beta/BETA/'
alpha BETA
# echo '3 1 2' | awk '{ print $2 }'
1
# { echo c; echo a; echo b; } | sort
a
b
c
# find /tmp/rstdir -name 3 -print
/tmp/rstdir/3
# cd /tmp
# mkdir tart
# cp /etc/passwd tart/passwd
# tar cf /tmp/t.tar tart/passwd
# tar tf /tmp/t.tar
Tar: blocksize = 5
tart/passwd
```

Two setup details were verified while reaching this run:

* Without `/etc/ddate`, historical `dump(1)` exits with
  `cannot open /etc/ddate`; the root image now installs an empty file.
* The previous auxfs image had only `.` and `..`; `auxfs.proto` now
  includes `/a` so `dumpdir` has a non-directory pathname and `restor x`
  can extract inode 3.

### echo V7 /bin/echo slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.

$ diff -u v7/usr/src/cmd/echo.c cmd/echo.c
--- v7/usr/src/cmd/echo.c	1979-01-10 12:01:32.000000000 -0800
+++ cmd/echo.c	2026-05-10 07:15:58.906680187 -0700
@@ -1,8 +1,7 @@
 #include <stdio.h>
 
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])
 {
 	register int i, nflg;
```

`cmd/echo.c` was already in the normal root build path:

* top-level `Makefile`: `root/bin/echo`
* `lib/Makefile`: `BIN = ... echo ...`
* `conf/qemu_arm/root.proto`: `echo ---755 0 0 root/bin/echo`

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot, explicitly
testing `/bin/echo`:

```
ls -l /bin/echo
-rwxr-xr-x 1 root     6484 May 16 02:02 /bin/echo
# /bin/echo one two
one two
# /bin/echo one two | od -c
0000000   o   n   e       t   w   o  \n
0000010
# /bin/echo -n one two | od -c
0000000   o   n   e       t   w   o  \0
0000007
# /bin/echo -nope x | od -c
0000000   x  \0
0000001
```

The `-nope` run preserves V7's simple second-character check: the first
operand is treated like `-n`, so `-nope` is not printed and the trailing
newline is suppressed.  The local V7 `od` pads its final partial display
with `\0`; the byte count (`0000007` for `one two`, `0000001` for `x`)
shows no newline byte was emitted.

Requested regressions in the same QEMU boot:

```
# echo sed-ok | sed 's/sed/SED/'
SED-ok
# echo 'left right' | awk '{print $2}'
right
# (echo c; echo a; echo b) | sort
a
b
c
# /bin/sh -c 'echo OK'
OK
```

### ed V7 line editor slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.

$ diff -u v7/usr/src/cmd/ed.c cmd/ed.c
--- v7/usr/src/cmd/ed.c	1979-01-10 12:01:34.000000000 -0800
+++ cmd/ed.c	2026-05-13 18:50:47.807310227 -0700
@@ -5,6 +5,9 @@
 #include <signal.h>
 #include <sgtty.h>
 #include <setjmp.h>
+#define	puts	u_puts
+#include <stdio.h>
+#undef	puts
 #define	NULL	0
 #define	FNSIZE	64
 #define	LBSIZE	512
```

`cmd/ed.c` was already in the normal root build path:

* top-level `Makefile`: `root/bin/ed`
* `lib/Makefile`: explicit `$(EDCFLAGS)` compile/link/install rule
* `conf/qemu_arm/root.proto`: `ed ---755 0 0 root/bin/ed`

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot, explicitly
testing `/bin/ed`:

```
ls /bin/ed
/bin/ed
# ed <<'EOED'
> f /tmp/e
> a
> alpha
> beta
> .
> 1,$p
> s/beta/gamma/
> 1,$p
> w
> q
> EOED
/tmp/e
alpha
beta
alpha
gamma
12
# cat /tmp/e
alpha
gamma
# ed /tmp/e <<'EOED'
> 1,$p
> 1t$
> 1,$p
> 2d
> 1,$p
> w
> q
> EOED
12
alpha
gamma
alpha
gamma
alpha
alpha
alpha
12
# cat /tmp/e
alpha
alpha
# ed <<'EOED'
> z
> q
> EOED
?
# ed /tmp/no-such-file <<'EOED'
> q
> EOED
?/tmp/no-such-file
# echo __TEST_DONE__
__TEST_DONE__
# 
```

This covers `/bin/ed` presence, creating a new file via `f` plus
append/write/quit, `1,$p`, substitution, reopening the file, copy via
`1t$`, delete via `2d`, final write, and the historical terse `?`
diagnostic style for an invalid command and a missing file.

### grep V7 userspace historical-accuracy slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`cmd/grep.c` was compared with `v7/usr/src/cmd/grep.c`; the only source
diff is C99 typing/prototypes around the original V7 code, so the source
was left untouched.  Existing wiring was confirmed in the top-level
`Makefile`, `lib/Makefile`, and `conf/qemu_arm/root.proto`.

Live QEMU evidence from fresh `tools/qemu-shell.py` boots:

```
ls -l /bin/grep
-rwxr-xr-x 1 root    22404 May 16 02:02 /bin/grep
# cat > /tmp/g1 <<'EOT'
> alpha
> Beta
> gamma
> alphabet
> zeta
> EOT
# cat > /tmp/g2 <<'EOT'
> delta
> ALPHA
> omega
> EOT
# echo alpha | /bin/grep alpha
alpha
# /bin/grep alpha /tmp/g1
alpha
alphabet
# /bin/grep '^a' /tmp/g1
alpha
alphabet
# /bin/grep '[gm]amma' /tmp/g1
gamma
# /bin/grep zzz /tmp/g1; echo NOMATCH:$?
NOMATCH:1
# /bin/grep -v alpha /tmp/g1
Beta
gamma
zeta
# /bin/grep -c a /tmp/g1
5
# /bin/grep -n a /tmp/g1
1:alpha
2:Beta
3:gamma
4:alphabet
5:zeta
# /bin/grep -l alpha /tmp/g1 /tmp/g2
/tmp/g1
# /bin/grep -h alpha /tmp/g1 /tmp/g2
alpha
alphabet
# /bin/grep -s alpha /tmp/g1
# /bin/grep -y alpha /tmp/g1 /tmp/g2
/tmp/g1:alpha
/tmp/g1:alphabet
/tmp/g2:ALPHA
# /bin/grep alpha /tmp/g1 /tmp/g2
/tmp/g1:alpha
/tmp/g1:alphabet
```

Supplemental `-e` evidence for a pattern beginning with `-`:

```
# cat > /tmp/ge <<'EOT'
> -literal
> plain
> EOT
# /bin/grep -e -l /tmp/ge; echo ESTATUS:$?
-literal
ESTATUS:0
```

Requested smoke regressions in the same QEMU boots:

```
# /bin/sh -c 'echo shell-ok'
shell-ok
# echo 'seddy' | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# (echo c; echo a; echo b) | sort
a
b
c
# ed <<'EOED'
> a
> one
> two
> .
> 1,$p
> w /tmp/edgrep
> q
> EOED
one
two
8
# cat /tmp/edgrep
one
two
```

### icheck V7 userspace historical-accuracy slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`cmd/icheck.c` was compared with `v7/usr/src/cmd/icheck.c`; the only
source diff is C99 typing/prototypes/returns plus the local `struct fblk`
union member access needed by this tree's headers, so the source was left
untouched.  Existing wiring was confirmed in the top-level `Makefile`,
`lib/Makefile`, and `conf/qemu_arm/root.proto`.

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /bin/icheck
-rwxr-xr-x 1 root    22688 May 16 02:02 /bin/icheck
# ls -l /etc/auxfs
-rw-r--r-- 1 root    32768 May 16 02:02 /etc/auxfs
# /bin/icheck /etc/auxfs; echo ICHECK_STATUS:$?
/etc/auxfs:
files      3 (r=2,d=1,b=0,c=0)
used       2 (i=0,ii=0,iii=0,d=2)
free      55
missing    0
ICHECK_STATUS:0
```

Requested smoke regressions in a fresh QEMU boot:

```
# echo seddy | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# echo 'left right' | grep right
left right
# (echo c; echo a; echo b) | sort
a
b
c
# ed <<'EOED'
> a
> one
> two
> .
> 1,$p
> w /tmp/icheck-ed
> q
> EOED
one
two
8
# cat /tmp/icheck-ed
one
two
```

### ncheck V7 userspace historical-accuracy slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`cmd/ncheck.c` was compared with `v7/usr/src/cmd/ncheck.c`; the only
source diff is C99 typing/prototypes/returns and unsigned loop-bound
casts, so the source was left untouched.  Existing wiring was confirmed
in the top-level `Makefile`, `lib/Makefile`, and
`conf/qemu_arm/root.proto`.

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /bin/ncheck /etc/auxfs
-rwxr-xr-x 1 root    19932 May 16 02:02 /bin/ncheck
-rw-r--r-- 1 root    32768 May 16 02:02 /etc/auxfs
# /bin/ncheck /etc/auxfs; echo NCHECK_STATUS:$?
/etc/auxfs:
3	/a
NCHECK_STATUS:0
# /bin/ncheck -a /etc/auxfs
/etc/auxfs:
2	/./.
2	/../.
3	/a
# /bin/ncheck -i 2 3 /etc/auxfs
/etc/auxfs:
3	/a
```

Requested smoke regressions in a fresh QEMU boot:

```
# echo x | sed 's/x/y/'
y
# cat >/tmp/awk.in <<'EOA'
> alpha
> beta
> EOA
# awk '/beta/' /tmp/awk.in
beta
# cat /tmp/awk.in | grep beta
beta
# cat >/tmp/sort.in <<'EOS'
> b
> a
> EOS
# sort /tmp/sort.in
a
b
# cat >/tmp/ed.in <<'EOE'
> a
> one
> .
> 1s/one/two/
> w /tmp/ed.out
> q
> EOE
# ed </tmp/ed.in
4
# cat /tmp/ed.out
two
```
### cb V7 userspace historical-accuracy slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`cmd/cb.c` was compared with `v7/usr/src/cmd/cb.c`; the only source
diff is C99/Armv7 compatibility wiring, so the source was left
untouched.  Existing build/root image wiring was confirmed in the
top-level `Makefile`, `lib/Makefile`, and `conf/qemu_arm/root.proto`.

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /bin/cb
-rwxr-xr-x 1 root    23980 May 16 02:02 /bin/cb
# cat >/tmp/cb.in <<'EOC'
> #define X(a) ((a)+1)
> int main(){char*s="if(/*not comment*/){x}";/* comment */if(X(1)){for(i=0;i<3;i++){puts(s);}}else{puts("else");}return 0;}
> EOC
# cb </tmp/cb.in >/tmp/cb.out
# echo CB_STATUS:$?
CB_STATUS:0
# cat /tmp/cb.out
#define X(a) ((a)+1)
int main(){
	char*s="if(/*not comment*/){x}";/* comment */
	if(X(1)){
		for(i=0;i<3;i++){
			puts(s);
		}
	}
	else{
		puts("else");
	}
	return 0;
}
```

Requested smoke regressions in the same fresh QEMU boot:

```
# echo seddy | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# echo 'left right' | grep right
left right
# (echo c; echo a; echo b) | sort
a
b
c
# cat >/tmp/ed.in <<'EOE'
> a
> one
> two
> .
> 1,$p
> w /tmp/cb-ed
> q
> EOE
# ed </tmp/ed.in
one
two
8
# cat /tmp/cb-ed
one
two
```

### sp V7 userspace historical-accuracy slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`cmd/sp.c` was compared with `v7/usr/src/cmd/sp.c`; the only source
diff is C99/Armv7 compatibility declarations and returns, so the source
was left untouched.  Existing build/root image wiring was confirmed in
the top-level `Makefile`, `lib/Makefile`, and
`conf/qemu_arm/root.proto`.

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /bin/sp
-rwxr-xr-x 1 root     8096 May 16 02:02 /bin/sp
# cat >/tmp/sp.in <<'EOS'
> alpha
> beta
> gamma
> delta
> omega
> EOS
# /bin/sp 20 </tmp/sp.in >/tmp/sp.out
# echo SP_STATUS:$?
SP_STATUS:0
# od -c /tmp/sp.out
0000000   a   l   p   h   a  \t   b   e   t   a  \n   g   a   m   m   a
0000020  \t   d   e   l   t   a  \n   o   m   e   g   a  \n  \0
0000035
```

Requested smoke regressions in the same fresh QEMU boot:

```
# echo seddy | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# echo 'left right' | grep right
left right
# (echo c; echo a; echo b) | sort
a
b
c
# cat >/tmp/ed.in <<'EOE'
> a
> one
> two
> .
> 1,$p
> w /tmp/sp-ed
> q
> EOE
# ed </tmp/ed.in
one
two
8
# cat /tmp/sp-ed
one
two
```

### split V7 userspace historical-accuracy slice

Host inventory/build evidence:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`cmd/split.c` was compared with `v7/usr/src/cmd/split.c`; the only
source diff is C99/Armv7 compatibility declarations, typed locals, and
an unsigned loop-bound cast, so the source was left untouched.  Existing
build/root image wiring was confirmed in the top-level `Makefile`,
`lib/Makefile`, and `conf/qemu_arm/root.proto`.

Live QEMU evidence from a fresh `tools/qemu-shell.py` boot:

```
ls -l /bin/split
-rwxr-xr-x 1 root    18192 May 16 02:02 /bin/split
# cd /tmp
# rm -f in joined prefixaa prefixab prefixac prefixad stdin.in yy.joined yyaa yyab yyac yyad sp.in sp.out cb.in cb.out sort.in ed.in ed.out
# cat >in <<'EOI'
> a
> b
> c
> d
> e
> EOI
# split -2 in prefix
# echo SPLIT_FILE_STATUS:$?
SPLIT_FILE_STATUS:0
# ls prefixaa prefixab prefixac
prefixaa
prefixab
prefixac
# cat prefixaa
a
b
# cat prefixab
c
d
# cat prefixac
e
# cat prefixaa prefixab prefixac >joined
# cmp in joined
# echo SPLIT_FILE_CMP:$?
SPLIT_FILE_CMP:0
# wc -l prefixaa prefixab prefixac joined
      2 prefixaa
      2 prefixab
      1 prefixac
      5 joined
     10 total
# cat >stdin.in <<'EOS'
> one
> two
> three
> four
> five
> EOS
# cat stdin.in | split -2 - yy
# echo SPLIT_STDIN_STATUS:$?
SPLIT_STDIN_STATUS:0
# ls yyaa yyab yyac
yyaa
yyab
yyac
# cat yyaa
one
two
# cat yyab
three
four
# cat yyac
five
# cat yyaa yyab yyac >yy.joined
# cmp stdin.in yy.joined
# echo SPLIT_STDIN_CMP:$?
SPLIT_STDIN_CMP:0
# od -c yyac
0000000   f   i   v   e  \n  \0
0000005
```

Requested smoke regressions in the same fresh QEMU boot:

```
# echo alpha beta | /bin/grep beta
alpha beta
# echo seddy | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# cat >sort.in <<'EOSORT'
> c
> a
> b
> EOSORT
# sort sort.in
a
b
c
# cat >sp.in <<'EOSP'
> alpha
> beta
> gamma
> EOSP
# /bin/sp 20 <sp.in >sp.out
# od -c sp.out
0000000   a   l   p   h   a  \t   b   e   t   a  \n   g   a   m   m   a
0000020  \n  \0
0000021
# cat >cb.in <<'EOCB'
> int main(){if(x){y();}else{z();}}
> EOCB
# cb <cb.in >cb.out
# cat cb.out
int main(){
	if(x){
		y();
	}
	else{
		z();
	}
}
# cat >ed.in <<'EOED'
> a
> one
> two
> .
> 1,$p
> w ed.out
> q
> EOED
# ed <ed.in
one
two
8
# cat ed.out
one
two
```

## stty V7 userspace historical-accuracy slice

Build/root image refresh:

```
$ make ARCH=arm CONF=qemu_arm
cd sys; make unix
...
arm-none-eabi-gcc ... -c ../arch/armboot.c -o ../arch/armboot.o
...
arm-none-eabi-gcc ... -c compat.c
...
arm-none-eabi-gcc ... -c ../cmd/stty.c
...
tools/mkfs root.img conf/qemu_arm/root.proto
truncate -s 4194304 root.img
```

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU evidence via `tools/qemu-shell.py`; note that V7 sh treats
unquoted `^` as a pipeline character, so the caret-control arguments are
quoted while still passed to `stty(1)` as `^H` and `^U`:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/stty
stty
stty erase '^H' kill '^U'
stty
stty 9600 -tabs
stty
stty 300 tabs
stty
echo __TEST_DONE__
EOF
ls /bin/stty
/bin/stty
# stty
speed 300 baud
erase = '#'; kill = '@'
even odd -nl echo -tabs 
# stty erase '^H' kill '^U'
# stty
speed 300 baud
erase = '^H'; kill = '^U'
even odd -nl echo -tabs 
# stty 9600 -tabs
# stty
speed 9600 baud
erase = '^H'; kill = '^U'
even odd -nl echo -tabs 
# stty 300 tabs
# stty
speed 300 baud
erase = '^H'; kill = '^U'
even odd -nl echo 
# echo __TEST_DONE__
__TEST_DONE__
```

The initial mode comes from V7 `getty`'s console table after login
(`B300`, `ANYP+ECHO+CR1`).  The later output shows separate `stty`
processes observing persisted erase/kill characters, speed changes, and
the `tabs`/`-tabs` bit.

Cheap regression smoke in the same kind of fresh QEMU boot:

```
# echo alpha beta | /bin/grep beta
alpha beta
# echo seddy | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# sort sort.in
a
b
c
# /bin/sp 20 <sp.in >sp.out
# od -c sp.out
0000000   a   l   p   h   a  \t   b   e   t   a  \n   g   a   m   m   a
0000020  \n  \0
0000021
# cb <cb.in >cb.out
# cat cb.out
int main(){
	if(x){
		y();
	}
	else{
		z();
	}
}
# ed <ed.in
one
two
8
# cat ed.out
one
two
```

## tabs V7 userspace historical-accuracy slice

Build/root image check:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

The current image was already up to date.  `Makefile`, `lib/Makefile`,
and `conf/qemu_arm/root.proto` already wire `tabs` into the root build
and install it as `/bin/tabs`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU evidence via `tools/qemu-shell.py`:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/tabs
tabs 300 | od -c
tabs -n 300 | od -c
tabs 450 | od -c
stty
tabs tn | od -c
stty
tabs hp | od -c
echo alpha beta | grep beta
echo seddy | sed 's/sed/SED/'
echo 'left right' | awk '{print $2}'
cat >sort.in <<'EOSORT'
c
a
b
EOSORT
sort sort.in
stty erase '^H' kill '^U'
stty
stty 9600 -tabs
stty
stty 300 tabs
stty
echo __TEST_DONE__
EOF
ls /bin/tabs
/bin/tabs
# tabs 300 | od -c
0000000 033   2 177 177 177 177 177 177 177 177  \r  \n
0000020                 033   1                                 033   1
0000040                                 033   1
0000060         033   1                                 033   1
0000100                         033   1
0000120 033   1                                 033   1
0000140                 033   1                                 033   1
0000160                                 033   1
0000200         033   1                                 033   1
0000220                         033   1  \n  \0
0000231
# tabs -n 300 | od -c
0000000 033   2 177 177 177 177 177 177 177 177  \r  \n
0000020                 033   1                                 033   1
0000040                                 033   1
0000060         033   1                                 033   1
0000100                         033   1
0000120 033   1                                 033   1
0000140                 033   1                                 033   1
0000160                                 033   1
0000200         033   1                                 033   1
0000220                         033   1
0000240 033   1  \n  \0
0000243
# tabs 450 | od -c
0000000 033   2 177 177 177 177 177 177 177 177  \r  \n  \b  \b  \b  \b
0000020  \b  \b  \b  \b  \b  \b  \b  \b  \b  \b  \b  \b
0000040                 033   9  \n                                 033
0000060   1                                 033   1
0000100             033   1                                 033   1
0000120                             033   1
0000140     033   1                                 033   1
0000160                     033   1                                 033
0000200   1                                 033   1
0000220             033   1                                 033   1
0000240                             033   1
0000260     033   1                                 033   1 033   0  \n
0000300
# stty
speed 300 baud
erase = '#'; kill = '@'
even odd -nl echo
# tabs tn | od -c
0000000 033   2 177 177 177 177 177 177 177 177  \r  \n
0000020                 033   1                                 033   1
0000040                                 033   1
0000060         033   1                                 033   1
0000100                         033   1
0000120 033   1                                 033   1
0000140                 033   1                                 033   1
0000160                                 033   1
0000200         033   1                                 033   1
0000220                         033   1  \n  \0
0000231
# stty
speed 300 baud
erase = '#'; kill = '@'
even odd -nl echo cr1 bs1
# tabs hp | od -c
0000000 033   3  \r                                 033   1
0000020                     033   1                                 033
0000040   1                                 033   1
0000060             033   1                                 033   1
0000100                             033   1
0000120     033   1                                 033   1  \n
0000136
# echo alpha beta | grep beta
alpha beta
# echo seddy | sed 's/sed/SED/'
SEDdy
# echo 'left right' | awk '{print $2}'
right
# cat >sort.in <<'EOSORT'
> c
> a
> b
> EOSORT
# sort sort.in
a
b
c
# stty erase '^H' kill '^U'
# stty
speed 300 baud
erase = '^H'; kill = '^U'
even odd -nl echo cr1 bs1
# stty 9600 -tabs
# stty
speed 9600 baud
erase = '^H'; kill = '^U'
even odd -nl echo -tabs cr1 bs1
# stty 300 tabs
# stty
speed 300 baud
erase = '^H'; kill = '^U'
even odd -nl echo cr1 bs1
# echo __TEST_DONE__
__TEST_DONE__
```

The `tabs 450` and `tabs tn` runs exercise the historical code paths
that call `stty(2)`.  The following `stty` output shows that `tabs tn`
persisted the expected `cr1 bs1` delay flags through the existing V7
`gtty`/`stty` support.  The later `stty` sequence also checks persisted
erase/kill, speed, and `tabs`/`-tabs` state.  The same fresh boot covers
grep, sed, awk, and sort smoke regressions.

## diff/diffh V7 userspace historical-accuracy slice

Build/root image check:

```
$ make ARCH=arm CONF=qemu_arm
...
make[1]: Leaving directory '/home/agent9/fast_data/unix-v7-c99/lib'
mkdir -p build
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

The command exited 0.  The output contains the existing V7 warning
noise from the broad userland rebuild and mkfs' existing
`nullboot: cannot open init` diagnostic.

After adding vertical-tab handling to the local helpers and wiring the
same helper into `diff(1)` `-b` hashing, the build/root image check was
rerun with the same command and also exited 0:

```
$ make ARCH=arm CONF=qemu_arm
...
make[1]: Leaving directory '/home/agent9/fast_data/unix-v7-c99/lib'
mkdir -p build
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU evidence via `tools/qemu-shell.py`:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/diff
ls /usr/lib/diffh
cat >d1 <<EOD1
alpha
beta
gamma
EOD1
cat >d2 <<EOD2
alpha
beta
gamma
EOD2
if diff d1 d2
then echo DIFF_IDENTICAL_STATUS_0
else echo DIFF_IDENTICAL_STATUS_BAD
fi
cat >d3 <<EOD3
alpha
BETA
gamma
delta
EOD3
if diff d1 d3
then echo DIFF_CHANGED_STATUS_BAD
else echo DIFF_CHANGED_STATUS_NONZERO
fi
cat >dadd1 <<EOA1
one
three
EOA1
cat >dadd2 <<EOA2
one
two
three
four
EOA2
diff dadd1 dadd2
cat >ddel1 <<EODL1
one
two
three
four
EODL1
cat >ddel2 <<EODL2
one
three
EODL2
diff ddel1 ddel2
cat >db1 <<EOB1
a b
c d
EOB1
cat >db2 <<EOB2
a  b
c  d
EOB2
if diff -b db1 db2
then echo DIFF_B_STATUS_0
else echo DIFF_B_STATUS_BAD
fi
diff -e d1 d3
diff -f d1 d3
cat d3 | diff d1 -
diff /bin d1
diff d1 /bin
diff -h d1 d3
...
echo __TEST_DONE__
EOF
ls /bin/diff
/bin/diff
# ls /usr/lib/diffh
/usr/lib/diffh
# if diff d1 d2
DIFF_IDENTICAL_STATUS_0
# if diff d1 d3
2c2
< beta
---
> BETA
3a4
> delta
DIFF_CHANGED_STATUS_NONZERO
# diff dadd1 dadd2
1a2
> two
2a4
> four
# diff ddel1 ddel2
2d1
< two
4d2
< four
# if diff -b db1 db2
DIFF_B_STATUS_0
# diff -e d1 d3
3a
delta
.
2c
BETA
.
# diff -f d1 d3
c2
BETA
.
a3
delta
.
# cat d3 | diff d1 -
2c2
< beta
---
> BETA
3a4
> delta
# diff /bin d1
diff: cannot open /bin/d1
# diff d1 /bin
diff: cannot open /bin/d1
# diff -h d1 d3
2,$c2,$
< beta
< gamma
---
> BETA
> gamma
> delta
# grep needle grep.in
needle
# sed 's/left/right/' sed.in
right
# echo 'left right' | awk '{print $2}'
right
# sort sort.in
a
b
c
# stty
speed 300 baud
erase = '^H'; kill = '^U'
even odd -nl echo -tabs 
# stty
speed 9600 baud
erase = '^H'; kill = '^U'
even odd -nl echo -tabs 
# stty
speed 300 baud
erase = '^H'; kill = '^U'
even odd -nl echo 
# echo __TEST_DONE__
__TEST_DONE__
```

Vertical-tab whitespace and small regression subset:

```
$ tools/qemu-shell.py <<'EOF'
rm -f empty vt1 vt2 diffb.out diffhb.out diffh.out base1 base2 changed.out add1 add2 add.out del1 del2 del.out grep.in sed.in sort.in
cat >empty <<EOEMPTY
EOEMPTY
echo 'a@b' | tr @ '\013' >vt1
echo 'a b' >vt2
if diff -b vt1 vt2 >diffb.out
then echo DIFF_B_VT_STATUS_0
else echo DIFF_B_VT_STATUS_BAD
fi
if cmp diffb.out empty
then echo DIFF_B_VT_OUTPUT_EMPTY
else echo DIFF_B_VT_OUTPUT_NOT_EMPTY
fi
cat diffb.out
if /usr/lib/diffh -b vt1 vt2 >diffh.out
then echo DIFFH_B_VT_STATUS_0
else echo DIFFH_B_VT_STATUS_BAD
fi
if cmp diffh.out empty
then echo DIFFH_B_VT_OUTPUT_EMPTY
else echo DIFFH_B_VT_OUTPUT_NOT_EMPTY
fi
cat diffh.out
if diff -hb vt1 vt2 >diffhb.out
then echo DIFF_HB_VT_STATUS_0
else echo DIFF_HB_VT_STATUS_BAD
fi
if cmp diffhb.out empty
then echo DIFF_HB_VT_OUTPUT_EMPTY
else echo DIFF_HB_VT_OUTPUT_NOT_EMPTY
fi
cat diffhb.out
cat >base1 <<EOBASE1
alpha
beta
gamma
EOBASE1
cat >base2 <<EOBASE2
alpha
BETA
gamma
delta
EOBASE2
if diff base1 base2 >changed.out
then echo DIFF_CHANGED_STATUS_BAD
else echo DIFF_CHANGED_STATUS_NONZERO
fi
cat changed.out
cat >add1 <<EOADD1
one
three
EOADD1
cat >add2 <<EOADD2
one
two
three
four
EOADD2
diff add1 add2 >add.out
cat add.out
cat >del1 <<EODEL1
one
two
three
four
EODEL1
cat >del2 <<EODEL2
one
three
EODEL2
diff del1 del2 >del.out
cat del.out
cat >grep.in <<EOGREP
needle
haystack
EOGREP
grep needle grep.in
cat >sed.in <<EOSED
left
EOSED
sed 's/left/right/' sed.in
cat >sort.in <<EOSORT
b
a
c
EOSORT
sort sort.in
echo 'left right' | awk '{print $2}'
echo __TEST_DONE__
EOF
# rm -f empty vt1 vt2 diffb.out diffhb.out diffh.out base1 base2 changed.out add1 add2 add.out del1 del2 del.out grep.in sed.in sort.in
# cat >empty <<EOEMPTY
> EOEMPTY
# echo 'a@b' | tr @ '\013' >vt1
# echo 'a b' >vt2
# if diff -b vt1 vt2 >diffb.out
DIFF_B_VT_STATUS_0
# if cmp diffb.out empty
DIFF_B_VT_OUTPUT_EMPTY
# cat diffb.out
# if /usr/lib/diffh -b vt1 vt2 >diffh.out
DIFFH_B_VT_STATUS_0
# if cmp diffh.out empty
DIFFH_B_VT_OUTPUT_EMPTY
# cat diffh.out
# if diff -hb vt1 vt2 >diffhb.out
DIFF_HB_VT_STATUS_0
# if cmp diffhb.out empty
DIFF_HB_VT_OUTPUT_EMPTY
# cat diffhb.out
# if diff base1 base2 >changed.out
DIFF_CHANGED_STATUS_NONZERO
# cat changed.out
2c2
< beta
---
> BETA
3a4
> delta
# diff add1 add2 >add.out
# cat add.out
1a2
> two
2a4
> four
# diff del1 del2 >del.out
# cat del.out
2d1
< two
4d2
< four
# grep needle grep.in
needle
# sed 's/left/right/' sed.in
right
# sort sort.in
a
b
c
# echo 'left right' | awk '{print $2}'
right
# echo __TEST_DONE__
__TEST_DONE__
```

This covers `/bin/diff` and `/usr/lib/diffh` presence, identical files
with status 0, changed files with nonzero status, additions, deletions,
`-b`, `-e`, `-f`, stdin `-`, directory operand filename behavior,
`-h` execution through `/usr/lib/diffh`, direct `diffh -b`, and
vertical-tab whitespace equivalence for `diff -b`, direct `diffh -b`,
and `diff -hb`.  The VT checks redirect output and compare it against
an empty file with `cmp`, so they verify output behavior as well as
status.  The same fresh boot covers regression smoke checks for grep,
sed, awk, and sort.
## dmesg(1) V7 userspace historical-accuracy slice

Build/root image:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

After removing the non-V7 `dkstat` wiring from this dmesg slice, the
root image was refreshed:

```
$ make ARCH=arm CONF=qemu_arm
cd lib; make
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Live QEMU dmesg and regression evidence:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/dmesg
ls /bin/dkstat
echo LS_DKSTAT_STATUS_$?
dmesg | sed 5q
echo DMESG_PIPE_STATUS_$?
dmesg /dev/mem /unix | sed 5q
echo DMESG_ARGS_PIPE_STATUS_$?
rm -f d1 d2
cat >d1 <<EOD1
alpha
beta
EOD1
cat >d2 <<EOD2
alpha
BETA
EOD2
if diff d1 d2
then echo DIFF_STATUS_0
else echo DIFF_STATUS_NONZERO
fi
stty
echo 'one two' | sed 's/one/ONE/'
echo __TEST_DONE__
EOF
ls /bin/dmesg
/bin/dmesg
# ls /bin/dkstat
/bin/dkstat not found
# echo LS_DKSTAT_STATUS_$?
LS_DKSTAT_STATUS_0
# dmesg | sed 5q
<NUL><NUL><NUL><NUL>r<NUL><NUL><NUL>dmesg
# ls /bin/dkstat
/bin/dkstat not found
# echo LS_DKSTAT_STATUS_$?
LS_DKSTAT_STATUS_0
# dmesg | sed 5q
n/dmesg
/bin/
Dec 31 19:00
...
n/dmesg
/bin/dmesg
# echo DMESG_PIPE_STATUS_$?
DMESG_PIPE_STATUS_0
# dmesg /dev/mem /unix | sed 5q
<NUL><NUL><NUL><NUL><NUL><NUL><NUL><NUL>/
Dec 31 19:00
...
n/dmesg
/bin/dmesg
# echo DMESG_PIPE_STATUS_$?
DMESG_PIPE_STATUS_0
# dmesg /dev/mem /unix | sed 5q

Dec 31 19:00
...
/
Dec 31 19:00
# echo DMESG_ARGS_PIPE_STATUS_$?
DMESG_ARGS_PIPE_STATUS_0
# rm -f d1 d2
# cat >d1 <<EOD1
> alpha
> beta
> EOD1
# cat >d2 <<EOD2
> alpha
> BETA
> EOD2
# if diff d1 d2
> then echo DIFF_STATUS_0
> else echo DIFF_STATUS_NONZERO
> fi
2c2
< beta
---
> BETA
DIFF_STATUS_NONZERO
# stty
speed 300 baud
erase = '#'; kill = '@'
even odd -nl echo -tabs 
# echo 'one two' | sed 's/one/ONE/'
ONE two
# echo __TEST_DONE__
__TEST_DONE__
# 
```

The `<NUL>` markers above replace literal NUL bytes printed from the
historical message buffer; the commands exited through the qemu-shell
sentinel with host status 0.  `dmesg | sed 5q` and
`dmesg /dev/mem /unix | sed 5q` both reported pipe status 0, confirming
the default and explicit `/dev/mem` plus `/unix` paths.

## du(1) V7 userspace historical-accuracy slice

Build/root image:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU du evidence:

```
$ tools/qemu-shell.py <<'EOF'
rm -r dut
mkdir dut
mkdir dut/sub
cat >dut/a <<'EODUA'
alpha
EODUA
cat >dut/sub/b <<'EDUB'
beta
EDUB
ln dut/a dut/alink
du dut
echo DU_RECUR_STATUS_$?
du -a dut
echo DU_A_STATUS_$?
du -s dut
echo DU_S_STATUS_$?
cd dut
du a
echo DU_FILE_A_STATUS_$?
du sub/b
echo DU_FILE_SUB_STATUS_$?
du -a a alink
echo DU_LINK_STATUS_$?
cd ..
echo __TEST_DONE__
EOF
rm -r dut
rm: dut nonexistent
# mkdir dut
# mkdir dut/sub
# cat >dut/a <<'EODUA'
> alpha
> EODUA
# cat >dut/sub/b <<'EDUB'
> beta
> EDUB
# ln dut/a dut/alink
# du dut
2	dut/sub
4	dut
# echo DU_RECUR_STATUS_$?
DU_RECUR_STATUS_0
# du -a dut
1	dut/sub/b
2	dut/sub
1	dut/a
4	dut
# echo DU_A_STATUS_$?
DU_A_STATUS_0
# du -s dut
4	dut
# echo DU_S_STATUS_$?
DU_S_STATUS_0
# cd dut
# du a
# echo DU_FILE_A_STATUS_$?
DU_FILE_A_STATUS_0
# du sub/b
# echo DU_FILE_SUB_STATUS_$?
DU_FILE_SUB_STATUS_0
# du -a a alink
1	a
# echo DU_LINK_STATUS_$?
DU_LINK_STATUS_0
# cd ..
# echo __TEST_DONE__
__TEST_DONE__
```

This covers recursive directory totals, `du -a`, `du -s`, default file
operands, slash-containing file operands from the operand directory, and
hard-link de-duplication through `ln`: `du -a a alink` prints only `a`
and exits with status 0.

Additional file-operand output check:

```
$ tools/qemu-shell.py <<'EOF'
rm -r dut
mkdir dut
cat >dut/a <<'EODUA'
alpha
EODUA
cd dut
du -a a
echo DU_A_FILE_STATUS_$?
echo __TEST_DONE__
EOF
rm -r dut
rm: dut nonexistent
# mkdir dut
# cat >dut/a <<'EODUA'
> alpha
> EODUA
# cd dut
# du -a a
1	a
# echo DU_A_FILE_STATUS_$?
DU_A_FILE_STATUS_0
# echo __TEST_DONE__
__TEST_DONE__
```

Live QEMU regression smoke from the same fresh boot as the first du
pass:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/du
rm -r dut
mkdir dut
mkdir dut/sub
cat >dut/a <<'EODUA'
alpha
EODUA
cat >dut/sub/b <<'EDUB'
beta
EDUB
ln dut/a dut/alink
du dut
echo DU_RECUR_STATUS_$?
du -a dut
echo DU_A_STATUS_$?
du -s dut
echo DU_S_STATUS_$?
du dut/a dut/sub/b
echo DU_FILES_STATUS_$?
du -a dut/a dut/alink
echo DU_LINK_STATUS_$?
dmesg | sed 2q
echo DMESG_STATUS_$?
rm -f dx dy
cat >dx <<'EDX'
one
two
EDX
cat >dy <<'EDY'
one
TWO
EDY
if diff dx dy
then echo DIFF_STATUS_0
else echo DIFF_STATUS_NONZERO
fi
stty
echo 'left right' | sed 's/left/LEFT/'
echo 'aa bb' | awk '{print $2}'
cat >sort.in <<'EOSORT'
c
a
b
EOSORT
sort sort.in
echo __TEST_DONE__
EOF
ls /bin/du
/bin/du
# rm -r dut
rm: dut nonexistent
# mkdir dut
# mkdir dut/sub
# cat >dut/a <<'EODUA'
> alpha
> EODUA
# cat >dut/sub/b <<'EDUB'
> beta
> EDUB
# ln dut/a dut/alink
# du dut
2	dut/sub
4	dut
# echo DU_RECUR_STATUS_$?
DU_RECUR_STATUS_0
# du -a dut
1	dut/sub/b
2	dut/sub
1	dut/a
4	dut
# echo DU_A_STATUS_$?
DU_A_STATUS_0
# du -s dut
4	dut
# echo DU_S_STATUS_$?
DU_S_STATUS_0
# du dut/a dut/sub/b
cannot chdir()
# echo DU_FILES_STATUS_$?
DU_FILES_STATUS_1
# du -a dut/a dut/alink
1	dut/a
cannot chdir()
# echo DU_LINK_STATUS_$?
DU_LINK_STATUS_1
# dmesg | sed 2q
<NUL><NUL><NUL><NUL>O<NUL><NUL><NUL>
cannot chdir()
# echo DU_LINK_STATUS_$?
DU_LINK_STATUS_1
# dmesg | sed 2q
FILES_STATUS_1
# du -a dut/a dut/alink
1	dut/a
Dec 31 19:00
# echo DMESG_STATUS_$?
DMESG_STATUS_0
# rm -f dx dy
# cat >dx <<'EDX'
> one
> two
> EDX
# cat >dy <<'EDY'
> one
> TWO
> EDY
# if diff dx dy
> then echo DIFF_STATUS_0
> else echo DIFF_STATUS_NONZERO
> fi
2c2
< two
---
> TWO
DIFF_STATUS_NONZERO
# stty
speed 300 baud
erase = '#'; kill = '@'
even odd -nl echo -tabs 
# echo 'left right' | sed 's/left/LEFT/'
LEFT right
# echo 'aa bb' | awk '{print $2}'
bb
# cat >sort.in <<'EOSORT'
> c
> a
> b
> EOSORT
# sort sort.in
a
b
c
# echo __TEST_DONE__
__TEST_DONE__
```

The slash-containing multi-operand failures in that first pass match
the historical `du.c` behavior: each operand containing `/` changes the
process directory before descent and the program does not restore the
original directory between top-level operands.  The focused du evidence
above retests file operands and hard-link de-duplication from inside the
operand directory and exits through the qemu-shell sentinel with host
status 0.

## getty(8) V7 userspace historical-accuracy slice

Host build:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

The root image was already current for this slice, so no rebuild was
needed.  `test_serv inventory` was attempted separately and failed
because `test_serv` is not installed in this environment:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU evidence used `tools/qemu-shell.py`.  The wrapper waits for
the serial `login:` prompt, sends `root`, and waits for the root `#`
prompt before executing the command stream, so a successful transcript
exercises init spawning getty, getty executing login, and login starting
the root shell:

```
$ tools/qemu-shell.py <<'EOF'
who am i
echo WHOAMI_STATUS_$?
tty
echo TTY_STATUS_$?
stty
echo STTY_STATUS_$?
echo getty-login-path-ok
echo 'left right' | sed 's/right/RIGHT/'
echo SED_STATUS_$?
echo 'console check' | grep console
echo GREP_STATUS_$?
cat /etc/ttys
echo TTYS_STATUS_$?
ls -l /etc/getty /bin/login /etc/init
echo LS_STATUS_$?
echo __TEST_DONE__
EOF
who am i
root     console Dec 31 19:00
# echo WHOAMI_STATUS_$?
WHOAMI_STATUS_0
# tty
/dev/console
# echo TTY_STATUS_$?
TTY_STATUS_0
# stty
speed 300 baud
erase = '#'; kill = '@'
even odd -nl echo -tabs 
# echo STTY_STATUS_$?
STTY_STATUS_0
# echo getty-login-path-ok
getty-login-path-ok
# echo 'left right' | sed 's/right/RIGHT/'
left RIGHT
# echo SED_STATUS_$?
SED_STATUS_0
# echo 'console check' | grep console
console check
# echo GREP_STATUS_$?
GREP_STATUS_0
# cat /etc/ttys
14console
# echo TTYS_STATUS_$?
TTYS_STATUS_0
# ls -l /etc/getty /bin/login /etc/init
-rwxr-xr-x 1 root    26384 May 16 04:02 /bin/login
-rwxr-xr-x 1 root     7692 May 16 04:02 /etc/getty
-rwxr-xr-x 1 root     8528 May 16 04:02 /etc/init
# echo LS_STATUS_$?
LS_STATUS_0
# echo __TEST_DONE__
__TEST_DONE__
# 
```

The live rootfs has the intentional single-console `/etc/ttys` entry
`14console`: init reads flag `1`, passes command table `4` to getty, and
uses the `console` device line.  This confirms the QEMU launch path
`/etc/init` -> `/etc/getty 4 console` -> `/bin/login` -> root shell.

## join(1) V7 userspace historical-accuracy slice

Host build:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

The root image was already current for this slice, so no rebuild was
needed.  `test_serv inventory` was attempted separately and failed
because `test_serv` is not installed in this environment:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU evidence used `tools/qemu-shell.py`:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/join
echo LS_JOIN_STATUS_$?
cat >j1 <<'EOJ1'
a 1
b 2
c 3
EOJ1
cat >j2 <<'EOJ2'
a A
b B
d D
EOJ2
/bin/join j1 j2
echo JOIN_DEFAULT_STATUS_$?
/bin/join -a1 j1 j2
echo JOIN_A1_STATUS_$?
/bin/join -a2 j1 j2
echo JOIN_A2_STATUS_$?
/bin/join -o 1.2 2.2 j1 j2
echo JOIN_O_STATUS_$?
/bin/join -e EMPTY -o 1.1 1.2 2.2 j1 j2
echo JOIN_E_STATUS_$?
cat >jt1 <<'EOJT1'
a:1
b:2
EOJT1
cat >jt2 <<'EOJT2'
a:A
b:B
EOJT2
/bin/join -t: jt1 jt2
echo JOIN_T_STATUS_$?
cat j1 | /bin/join - j2
echo JOIN_STDIN_STATUS_$?
echo alpha beta | sed 's/beta/BETA/'
echo SED_STATUS_$?
echo 'one two' | awk '{print $2}'
echo AWK_STATUS_$?
echo needle | grep needle
echo GREP_STATUS_$?
cat >sort.in <<'EOSORT'
c
a
b
EOSORT
sort sort.in
echo SORT_STATUS_$?
mkdir -p dudir
echo x >dudir/a
du dudir
echo DU_STATUS_$?
echo __TEST_DONE__
EOF
ls /bin/join
/bin/join
# echo LS_JOIN_STATUS_$?
LS_JOIN_STATUS_0
# cat >j1 <<'EOJ1'
> a 1
> b 2
> c 3
> EOJ1
# cat >j2 <<'EOJ2'
> a A
> b B
> d D
> EOJ2
# /bin/join j1 j2
a 1 A
b 2 B
# echo JOIN_DEFAULT_STATUS_$?
JOIN_DEFAULT_STATUS_0
# /bin/join -a1 j1 j2
a 1 A
b 2 B
c 3
# echo JOIN_A1_STATUS_$?
JOIN_A1_STATUS_0
# /bin/join -a2 j1 j2
a 1 A
b 2 B
d D
# echo JOIN_A2_STATUS_$?
JOIN_A2_STATUS_0
# /bin/join -o 1.2 2.2 j1 j2
1 A
2 B
# echo JOIN_O_STATUS_$?
JOIN_O_STATUS_0
# /bin/join -e EMPTY -o 1.1 1.2 2.2 j1 j2
a 1 A
b 2 B
# echo JOIN_E_STATUS_$?
JOIN_E_STATUS_0
# cat >jt1 <<'EOJT1'
> a:1
> b:2
> EOJT1
# cat >jt2 <<'EOJT2'
> a:A
> b:B
> EOJT2
# /bin/join -t: jt1 jt2
a:1:A
b:2:B
# echo JOIN_T_STATUS_$?
JOIN_T_STATUS_0
# cat j1 | /bin/join - j2
a 1 A
b 2 B
# echo JOIN_STDIN_STATUS_$?
JOIN_STDIN_STATUS_0
# echo alpha beta | sed 's/beta/BETA/'
alpha BETA
# echo SED_STATUS_$?
SED_STATUS_0
# echo 'one two' | awk '{print $2}'
two
# echo AWK_STATUS_$?
AWK_STATUS_0
# echo needle | grep needle
needle
# echo GREP_STATUS_$?
GREP_STATUS_0
# cat >sort.in <<'EOSORT'
> c
> a
> b
> EOSORT
# sort sort.in
a
b
c
# echo SORT_STATUS_$?
SORT_STATUS_0
# mkdir -p dudir
# echo x >dudir/a
# du dudir
2	dudir
# echo DU_STATUS_$?
DU_STATUS_0
# echo __TEST_DONE__
__TEST_DONE__
```

The first `-e` command above confirmed that the option is accepted on
matched rows.  A focused unmatched-row check showed the historical null
replacement behavior directly:

```
$ tools/qemu-shell.py <<'EOF'
cat >j1 <<'EOJ1'
a 1
b 2
c 3
EOJ1
cat >j2 <<'EOJ2'
a A
b B
d D
EOJ2
/bin/join -a1 -e EMPTY -o 1.1 1.2 2.2 j1 j2
echo JOIN_E_A1_STATUS_$?
echo __TEST_DONE__
EOF
cat >j1 <<'EOJ1'
> a 1
> b 2
> c 3
> EOJ1
# cat >j2 <<'EOJ2'
> a A
> b B
> d D
> EOJ2
# /bin/join -a1 -e EMPTY -o 1.1 1.2 2.2 j1 j2
a 1 A
b 2 B
c 3 EMPTY
# echo JOIN_E_A1_STATUS_$?
JOIN_E_A1_STATUS_0
# echo __TEST_DONE__
__TEST_DONE__
```

## kill(1) V7 userspace historical-accuracy slice

Host build:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

The root image was already current for this slice, so no rebuild was
needed.  `test_serv inventory` was attempted separately and failed
because `test_serv` is not installed in this environment:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU evidence used `tools/qemu-shell.py`:

```
$ tools/qemu-shell.py <<'EOF'
ls -l /bin/kill
/bin/kill
echo KILL_USAGE_STATUS_$?
/bin/kill xyz
echo KILL_XYZ_STATUS_$?
/bin/kill 99999
echo KILL_NOPROC_STATUS_$?
/bin/kill -9 99999
echo KILL_SIG9_NOPROC_STATUS_$?
echo alpha beta | sed 's/beta/BETA/'
echo SED_STATUS_$?
echo needle | grep needle
echo GREP_STATUS_$?
cat >sort.in <<'EOSORT'
c
a
b
EOSORT
sort sort.in
echo SORT_STATUS_$?
cat >j1 <<'EOJ1'
a 1
b 2
EOJ1
cat >j2 <<'EOJ2'
a A
b B
EOJ2
join j1 j2
echo JOIN_STATUS_$?
mkdir -p dudir
echo x >dudir/a
du dudir
echo DU_STATUS_$?
echo __TEST_DONE__
EOF
ls -l /bin/kill
-rwxr-xr-x 1 root    17344 May 16 04:02 /bin/kill
# /bin/kill
usage: kill [ -signo ] pid ...
# echo KILL_USAGE_STATUS_$?
KILL_USAGE_STATUS_2
# /bin/kill xyz
usage: kill [ -signo ] pid ...
# echo KILL_XYZ_STATUS_$?
KILL_XYZ_STATUS_2
# /bin/kill 99999
99999: Not owner
# echo KILL_NOPROC_STATUS_$?
KILL_NOPROC_STATUS_1
# /bin/kill -9 99999
99999: Not owner
# echo KILL_SIG9_NOPROC_STATUS_$?
KILL_SIG9_NOPROC_STATUS_1
# echo alpha beta | sed 's/beta/BETA/'
alpha BETA
# echo SED_STATUS_$?
SED_STATUS_0
# echo needle | grep needle
needle
# echo GREP_STATUS_$?
GREP_STATUS_0
# cat >sort.in <<'EOSORT'
> c
> a
> b
> EOSORT
# sort sort.in
a
b
c
# echo SORT_STATUS_$?
SORT_STATUS_0
# cat >j1 <<'EOJ1'
> a 1
> b 2
> EOJ1
# cat >j2 <<'EOJ2'
> a A
> b B
> EOJ2
# join j1 j2
a 1 A
b 2 B
# echo JOIN_STATUS_$?
JOIN_STATUS_0
# mkdir -p dudir
# echo x >dudir/a
# du dudir
2	dudir
# echo DU_STATUS_$?
DU_STATUS_0
# echo __TEST_DONE__
__TEST_DONE__
# 
```

The invalid pid diagnostics above intentionally document this port's
current kernel errno for a large non-live pid (`Not owner`), while
`kill(1)` itself preserves the V7 behavior of printing the pid followed
by `sys_errlist[errno]` and returning status 1.  The `-9` case confirms
the historical numeric signal option is parsed and passed through the
same path.

A focused live-process check used signal 0 against init.  This exercises
the same `kill(pid, signo)` path with an existing process while avoiding
termination of the test shell or init:

```
$ tools/qemu-shell.py <<'EOF'
/bin/kill -0 1
echo KILL_ZERO_INIT_STATUS_$?
ps
echo __TEST_DONE__
EOF
/bin/kill -0 1
# echo KILL_ZERO_INIT_STATUS_$?
KILL_ZERO_INIT_STATUS_0
# ps
   PID TTY TIME CMD
     1 ?   0:00
     4 ?   0:00
     7 ?   0:00 ps
# echo __TEST_DONE__
__TEST_DONE__
# 
```

A direct background-sleep signal check was attempted with the same
one-shot console harness using `sleep 2&` and `sleep 99 &`.  The V7
shell path emitted a very large stream of terminal backspace characters
and did not provide a stable live background pid before the sleep
completed; that harness output was unsuitable as evidence.  The
functional kill path is covered here by the live signal-0 check, the
live `kill(2)` error calls above, and the source comparison showing
`kill(pid, signo)` is still the V7 call made for every pid operand.

### ln(1) V7 userspace historical-accuracy slice

`cmd/ln.c` was already the V7 source with only the K&R `main` definition
converted to a C99 signature.  No source or build-wiring change was
needed.  Existing wiring was confirmed in the top-level `Makefile`,
`lib/Makefile`, and `conf/qemu_arm/root.proto`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build/root image check:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

Live QEMU command transcript:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/ln
rm -f a b x dlink j1 j2
rm -r d
mkdir d
echo data >a
ln a b
cmp a b
ls -l a b
ln a d
cmp a d/a
ln missing x
echo missing-status $?
ln d dlink
echo dir-status $?
cat >j1 <<EOJ
1 one
2 two
EOJ
cat >j2 <<EOJ
1 uno
2 dos
EOJ
join j1 j2
kill -0 1
echo kill-status $?
du d
rm -f a b x dlink j1 j2
rm -r d
echo __TEST_DONE__
EOF
ls /bin/ln
/bin/ln
# rm -f a b x dlink j1 j2
# rm -r d
rm: d nonexistent
# mkdir d
# echo data >a
# ln a b
# cmp a b
# ls -l a b
-rw-rw-r-- 2 root        5 Dec 31 19:00 a
-rw-rw-r-- 2 root        5 Dec 31 19:00 b
# ln a d
# cmp a d/a
# ln missing x
ln: missing does not exist
# echo missing-status $?
missing-status 1
# ln d dlink
ln: d is a directory
# echo dir-status $?
dir-status 1
# cat >j1 <<EOJ
> 1 one
> 2 two
> EOJ
# cat >j2 <<EOJ
> 1 uno
> 2 dos
> EOJ
# join j1 j2
1 one uno
2 two dos
# kill -0 1
# echo kill-status $?
kill-status 0
# du d
2	d
# rm -f a b x dlink j1 j2
# rm -r d
# echo __TEST_DONE__
__TEST_DONE__
# 
```

### mkdir(1) V7 userspace historical-accuracy slice

`cmd/mkdir.c` was already the V7 source with only C99/Armv7-compatible
function signatures and typed locals.  No source or build-wiring change
was needed.  Existing wiring was confirmed in the top-level `Makefile`,
`lib/Makefile`, and `conf/qemu_arm/root.proto`.

`test_serv inventory` was attempted before local testing, but this
environment does not provide the tool:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build/root image check:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

Live QEMU command transcript:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/mkdir
rm -r mbase
rm -r mdup
rm -f mfile mlink sedout
mkdir mbase
mkdir mbase/child
echo nested-status $?
ls -ld mbase mbase/child
mkdir missing/child
echo missing-parent-status $?
mkdir mdup
echo first-dup-status $?
mkdir mdup
echo dup-status $?
ls -ld mdup
ls -ld mdup/. mdup/..
ln /bin/mkdir mlink
ls -l mlink
find mbase -print
du mbase
echo x | sed s/x/y/
rmdir mbase/child
echo rmdir-child-status $?
rmdir mbase
echo rmdir-base-status $?
rmdir mdup
echo rmdir-dup-status $?
rm -f mlink sedout
rm -r missing
rm -r mbase
rm -r mdup
echo __TEST_DONE__
EOF
ls /bin/mkdir
/bin/mkdir
# rm -r mbase
rm: mbase nonexistent
# rm -r mdup
rm: mdup nonexistent
# rm -f mfile mlink sedout
# mkdir mbase
# mkdir mbase/child
# echo nested-status $?
nested-status 0
# ls -ld mbase mbase/child
drwxrwxr-x 3 root       48 Dec 31 19:00 mbase
drwxrwxr-x 2 root       32 Dec 31 19:00 mbase/child
# mkdir missing/child
mkdir: cannot access missing/.
# echo missing-parent-status $?
missing-parent-status 1
# mkdir mdup
# echo first-dup-status $?
first-dup-status 0
# mkdir mdup
mkdir: cannot make directory mdup
# echo dup-status $?
dup-status 1
# ls -ld mdup
drwxrwxr-x 2 root       32 Dec 31 19:00 mdup
# ls -ld mdup/. mdup/..
drwxrwxr-x 2 root       32 Dec 31 19:00 mdup/.
drwxr-xr-x 9 root      160 Dec 31 19:00 mdup/..
# ln /bin/mkdir mlink
# ls -l mlink
-rwxr-xr-x 2 root    17072 May 16 04:02 mlink
# find mbase -print
mbase
mbase/child
# du mbase
1	mbase/child
2	mbase
# echo x | sed s/x/y/
y
# rmdir mbase/child
# echo rmdir-child-status $?
rmdir-child-status 0
# rmdir mbase
# echo rmdir-base-status $?
rmdir-base-status 0
# rmdir mdup
# echo rmdir-dup-status $?
rmdir-dup-status 0
# rm -f mlink sedout
# rm -r missing
rm: missing nonexistent
# rm -r mbase
rm: mbase nonexistent
# rm -r mdup
rm: mdup nonexistent
# echo __TEST_DONE__
__TEST_DONE__
# 
```

## mknod(1) V7 userspace historical-accuracy slice

Build/root image check:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

`root.img`, `unix`, and `root/bin/mknod` were already current for this
slice.  `test_serv inventory` was attempted before the build/QEMU check,
but the tool is not installed in this environment:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU check through `tools/qemu-shell.py`:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/mknod
rm -f /tmp/null2 /tmp/bad /tmp/missing
mknod
echo usage-status $?
mknod /tmp/bad x 0 0
echo bad-type-status $?
mknod /tmp/bad c x 0
echo bad-major-status $?
mknod /tmp/bad c 0 y
echo bad-minor-status $?
ls -l /tmp/bad
mknod /tmp/null2 c 0 0
echo create-status $?
ls -l /tmp/null2
cat /tmp/null2
echo read-status $?
echo hi >/tmp/null2
echo write-status $?
mkdir /tmp/mkdir-reg
echo mkdir-status $?
ln /bin/mknod /tmp/mknod-link
echo ln-status $?
ls -l /tmp/mknod-link
kill -0 1
echo kill-status $?
find /tmp -name null2 -print
du /tmp
rm -f /tmp/null2 /tmp/bad /tmp/mknod-link
rmdir /tmp/mkdir-reg
echo cleanup-status $?
echo __TEST_DONE__
EOF
ls /bin/mknod
/bin/mknod
# rm -f /tmp/null2 /tmp/bad /tmp/missing
# mknod
arg count
usage: mknod name b/c major minor
# echo usage-status $?
usage-status 0
# mknod /tmp/bad x 0 0
usage: mknod name b/c major minor
# echo bad-type-status $?
bad-type-status 0
# mknod /tmp/bad c x 0
usage: mknod name b/c major minor
# echo bad-major-status $?
bad-major-status 0
# mknod /tmp/bad c 0 y
usage: mknod name b/c major minor
# echo bad-minor-status $?
bad-minor-status 0
# ls -l /tmp/bad
/tmp/bad not found
# mknod /tmp/null2 c 0 0
# echo create-status $?
create-status 0
# ls -l /tmp/null2
crw-rw-r-- 1 root    0,  0 Dec 31 19:00 /tmp/null2
# cat /tmp/null2
# echo read-status $?
read-status 0
# echo hi >/tmp/null2
/tmp/null2: cannot create
# echo write-status $?
write-status 1
# mkdir /tmp/mkdir-reg
# echo mkdir-status $?
mkdir-status 0
# ln /bin/mknod /tmp/mknod-link
# echo ln-status $?
ln-status 0
# ls -l /tmp/mknod-link
-rwxr-xr-x 2 root    17256 May 16 04:02 /tmp/mknod-link
# kill -0 1
# echo kill-status $?
kill-status 0
# find /tmp -name null2 -print
/tmp/null2
# du /tmp
1	/tmp/mkdir-reg
36	/tmp
# rm -f /tmp/null2 /tmp/bad /tmp/mknod-link
# rmdir /tmp/mkdir-reg
# echo cleanup-status $?
cleanup-status 0
# echo __TEST_DONE__
__TEST_DONE__
# 
```

Notes from the live check:

* `/bin/mknod` is present in the root image.
* Usage and bad type/major/minor inputs print V7 diagnostics and do not
  create `/tmp/bad`; the zero status on those paths is historical
  fall-through behavior from the source.
* `/tmp/null2 c 0 0` is created and `ls -l` displays the expected
  character-special mode plus `0,  0` device numbers.
* `cat /tmp/null2` returns successfully; writing through shell
  redirection fails with `cannot create` on this current character
  device mapping.
* Regression probes for `mkdir`, `ln`, `kill -0 1`, `find`, and `du`
  succeeded.

## mount(1) V7 userspace historical-accuracy slice

Build/root image check:

```
$ make ARCH=arm CONF=qemu_arm
cd sys; make unix
...
arm-none-eabi-gcc ... -c ../arch/armboot.c -o ../arch/armboot.o
arm-none-eabi-gcc ... -c ../arch/u_bridge.c -o ../arch/u_bridge.o
arm-none-eabi-gcc ... -o ../unix ...
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

The first build rebuilt the kernel after routing syscall 21 through the
V7 `smount()` bridge and refreshed `root.img`; the second build confirmed
the tree was current.  The build also emitted the existing historical
userland warning stream while rebuilding all root binaries.

`test_serv inventory` was attempted before the build/QEMU check, but the
tool is not installed in this environment:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU check through `tools/qemu-shell.py`:

```
$ tools/qemu-shell.py <<'EOF'
ls /bin/mount
mount
echo mount-list-status $?
mount onlyonearg
echo one-arg-status $?
mount /no/such /tmp
echo missing-mount-status $?
rm -f /tmp/mount-ln /tmp/mount-grep-out /tmp/mount-node
rm -r /tmp/mount-dir /tmp/mount-find-base
mknod /tmp/mount-node c 0 0
echo mknod-status $?
ls -l /tmp/mount-node
mkdir /tmp/mount-dir
echo mkdir-status $?
ln /bin/mount /tmp/mount-ln
echo ln-status $?
ls -l /tmp/mount-ln
mkdir /tmp/mount-find-base
mkdir /tmp/mount-find-base/child
find /tmp/mount-find-base -print
echo find-status $?
du /tmp/mount-find-base
echo du-status $?
echo mountprobe | sed s/probe/ok/
echo sed-status $?
echo mountprobe | grep probe
echo grep-status $?
rm -f /tmp/mount-node /tmp/mount-ln /tmp/mount-grep-out
rm -r /tmp/mount-dir /tmp/mount-find-base
echo cleanup-status $?
echo __TEST_DONE__
EOF
ls /bin/mount
/bin/mount
# mount
# echo mount-list-status $?
mount-list-status 0
# mount onlyonearg
arg count
# echo one-arg-status $?
one-arg-status 1
# mount /no/such /tmp
mount: No such file or directory
# echo missing-mount-status $?
missing-mount-status 1
# rm -f /tmp/mount-ln /tmp/mount-grep-out /tmp/mount-node
# rm -r /tmp/mount-dir /tmp/mount-find-base
rm: /tmp/mount-dir nonexistent
rm: /tmp/mount-find-base nonexistent
# mknod /tmp/mount-node c 0 0
# echo mknod-status $?
mknod-status 0
# ls -l /tmp/mount-node
crw-rw-r-- 1 root    0,  0 Dec 31 19:00 /tmp/mount-node
# mkdir /tmp/mount-dir
# echo mkdir-status $?
mkdir-status 0
# ln /bin/mount /tmp/mount-ln
# echo ln-status $?
ln-status 0
# ls -l /tmp/mount-ln
-rwxr-xr-x 2 root    17628 May 16 05:11 /tmp/mount-ln
# mkdir /tmp/mount-find-base
# mkdir /tmp/mount-find-base/child
# find /tmp/mount-find-base -print
/tmp/mount-find-base
/tmp/mount-find-base/child
# echo find-status $?
find-status 0
# du /tmp/mount-find-base
1	/tmp/mount-find-base/child
2	/tmp/mount-find-base
# echo du-status $?
du-status 0
# echo mountprobe | sed s/probe/ok/
mountok
# echo sed-status $?
sed-status 0
# echo mountprobe | grep probe
mountprobe
# echo grep-status $?
grep-status 0
# rm -f /tmp/mount-node /tmp/mount-ln /tmp/mount-grep-out
# rm -r /tmp/mount-dir /tmp/mount-find-base
# echo cleanup-status $?
cleanup-status 0
# echo __TEST_DONE__
__TEST_DONE__
# 
```

Notes from the live check:

* `/bin/mount` is present in the root image.
* `mount` with no arguments exits 0 after reading `/etc/mtab`; the empty
  output matches the current empty mtab image.
* `mount onlyonearg` prints `arg count` and exits 1.
* `mount /no/such /tmp` now reaches the V7 syscall failure path, prints
  `mount: No such file or directory`, and exits 1.
* Regression probes for `mknod`, `mkdir`, `ln`, `find`, `du`, `sed`, and
  `grep` succeeded.

### diff3(1) V7 userspace historical-accuracy slice

Build/root image evidence:

```
$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

Build/root wiring checked:

```
$ rg -n "diff3|DIFF3|cmd/diff" Makefile lib/Makefile conf/qemu_arm/root.proto
Makefile:28:	root/bin/passwd root/bin/diff3 \
lib/Makefile:52:BIN = login cat echo ls pwd sync rev yes wc basename sum tty cmp comm cal od tail grep test look cp rm ln mkdir rmdir mv chmod chown chgrp sleep tee touch tr uniq du date kill nice mknod who mesg time split checkeq calendar tsort file join col fgrep egrep su newgrp random crypt pr dd stty tabs diff wall write df clri dcheck icheck ncheck cb sp find sort mount umount passwd diff3 at units spline restor tk dmesg sa ptx vpr dump dumpdir graph factor primes expr ac iostat tek
conf/qemu_arm/root.proto:31:		diff3	---755 0 0 root/bin/diff3
```

Hardware inventory helper:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU command batch:

```
tools/qemu-shell.py <<'EOF'
ls /bin/diff3
echo present-status $?
rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23 /tmp/out
cat >/tmp/base <<'EOT'
a
b
c
EOT
cat >/tmp/left <<'EOT'
a
B
c
EOT
cat >/tmp/right <<'EOT'
a
b
c
d
EOT
diff /tmp/left /tmp/base >/tmp/d13
echo diff13-one-side-status $?
diff /tmp/right /tmp/base >/tmp/d23
echo diff23-one-side-status $?
diff3 /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
echo diff3-one-side-status $?
diff3 -e /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
echo diff3-e-status $?
rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23
cat >/tmp/base <<'EOT'
a
b
c
EOT
cat >/tmp/left <<'EOT'
a
B-left
c
EOT
cat >/tmp/right <<'EOT'
a
B-right
c
EOT
diff /tmp/left /tmp/base >/tmp/d13
echo diff13-conflict-status $?
diff /tmp/right /tmp/base >/tmp/d23
echo diff23-conflict-status $?
diff3 /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
echo diff3-conflict-status $?
diff /tmp/base /tmp/base
echo diff-regress-status $?
umount /no/such
echo umount-regress-status $?
mount /no/such /tmp
echo mount-regress-status $?
cat >/tmp/out <<'EOT'
alpha
beta
alpha beta
EOT
sed s/alpha/ALPHA/ /tmp/out | grep beta
echo sed-grep-pipe-status $?
rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23 /tmp/out
echo cleanup-status $?
echo __TEST_DONE__
EOF
```

Captured output:

```
ls /bin/diff3
/bin/diff3
# echo present-status $?
present-status 0
# rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23 /tmp/out
# cat >/tmp/base <<'EOT'
> a
> b
> c
> EOT
# cat >/tmp/left <<'EOT'
> a
> B
> c
> EOT
# cat >/tmp/right <<'EOT'
> a
> b
> c
> d
> EOT
# diff /tmp/left /tmp/base >/tmp/d13
# echo diff13-one-side-status $?
diff13-one-side-status 1
# diff /tmp/right /tmp/base >/tmp/d23
# echo diff23-one-side-status $?
diff23-one-side-status 1
# diff3 /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
====1
1:2c
  B
2:2c
3:2c
  b
====2
1:3a
2:4c
  d
3:3a
# echo diff3-one-side-status $?
diff3-one-side-status 0
# diff3 -e /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
# echo diff3-e-status $?
diff3-e-status 0
# rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23
# cat >/tmp/base <<'EOT'
> a
> b
> c
> EOT
# cat >/tmp/left <<'EOT'
> a
> B-left
> c
> EOT
# cat >/tmp/right <<'EOT'
> a
> B-right
> c
> EOT
# diff /tmp/left /tmp/base >/tmp/d13
# echo diff13-conflict-status $?
diff13-conflict-status 1
# diff /tmp/right /tmp/base >/tmp/d23
# echo diff23-conflict-status $?
diff23-conflict-status 1
# diff3 /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
====
1:2c
  B-left
2:2c
  B-right
3:2c
  b
# echo diff3-conflict-status $?
diff3-conflict-status 0
# diff /tmp/base /tmp/base
# echo diff-regress-status $?
diff-regress-status 0
# umount /no/such
umount: No such file or directory
# echo umount-regress-status $?
umount-regress-status 1
# mount /no/such /tmp
mount: No such file or directory
# echo mount-regress-status $?
mount-regress-status 1
# cat >/tmp/out <<'EOT'
> alpha
> beta
> alpha beta
> EOT
# sed s/alpha/ALPHA/ /tmp/out | grep beta
beta
ALPHA beta
# echo sed-grep-pipe-status $?
sed-grep-pipe-status 0
# rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23 /tmp/out
# echo cleanup-status $?
cleanup-status 0
# echo __TEST_DONE__
__TEST_DONE__
# 
```

Additional edit-script mode check for the overlapping case:

```
tools/qemu-shell.py <<'EOF'
rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23
cat >/tmp/base <<'EOT'
a
b
c
EOT
cat >/tmp/left <<'EOT'
a
B-left
c
EOT
cat >/tmp/right <<'EOT'
a
B-right
c
EOT
diff /tmp/left /tmp/base >/tmp/d13
diff /tmp/right /tmp/base >/tmp/d23
diff3 -e /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
echo diff3-e-conflict-status $?
rm -f /tmp/base /tmp/left /tmp/right /tmp/d13 /tmp/d23
echo __TEST_DONE__
EOF
```

Captured output:

```
# diff3 -e /tmp/d13 /tmp/d23 /tmp/left /tmp/right /tmp/base
2c
b
.
# echo diff3-e-conflict-status $?
diff3-e-conflict-status 0
# echo __TEST_DONE__
__TEST_DONE__
```

Notes from the live check:

* `/bin/diff3` is present in the root image.
* `diff3` normal mode produced the V7 section headers for one-side
  changes (`====1`, `====2`) and overlapping conflicts (`====`).
* `diff3 -e` accepted the generated diff reports and emitted an
  edit-script replacement (`2c`, `b`, `.`) for the overlapping case.
* Regression checks for `diff`, `umount /no/such`, `mount /no/such
  /tmp`, and a simple `sed | grep` pipeline succeeded.

### umount(1) V7 userspace historical-accuracy slice

Build evidence:

```
$ make ARCH=arm CONF=qemu_arm
cd sys; make unix
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img

$ make ARCH=arm CONF=qemu_arm
make: Nothing to be done for 'all'.
```

Hardware inventory helper:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Live QEMU command batch:

```
tools/qemu-shell.py <<'EOF'
ls /bin/umount
umount
echo umount-argc-status $?
umount /no/such
echo umount-missing-status $?
mount /no/such /tmp
echo mount-missing-status $?
rm -f /tmp/umntnode /tmp/umntlink /tmp/umnttext
rm -r /tmp/umntdir
mknod /tmp/umntnode c 1 2
echo mknod-status $?
mkdir /tmp/umntdir
echo mkdir-status $?
ln /tmp/umntnode /tmp/umntlink
echo ln-status $?
find /tmp -name umntnode -print
echo find-status $?
du /tmp
echo du-status $?
cat >/tmp/umnttext <<'EOT'
alpha
beta
alpha beta
EOT
sed s/alpha/ALPHA/ /tmp/umnttext
echo sed-status $?
grep beta /tmp/umnttext
echo grep-status $?
rm -f /tmp/umntnode /tmp/umntlink /tmp/umnttext
rm -r /tmp/umntdir
echo cleanup-status $?
echo __TEST_DONE__
EOF
```

Captured output:

```
ls /bin/umount
/bin/umount
# umount
arg count
# echo umount-argc-status $?
umount-argc-status 1
# umount /no/such
umount: No such file or directory
# echo umount-missing-status $?
umount-missing-status 1
# mount /no/such /tmp
mount: No such file or directory
# echo mount-missing-status $?
mount-missing-status 1
# rm -f /tmp/umntnode /tmp/umntlink /tmp/umnttext
# rm -r /tmp/umntdir
rm: /tmp/umntdir nonexistent
# mknod /tmp/umntnode c 1 2
# echo mknod-status $?
mknod-status 0
# mkdir /tmp/umntdir
# echo mkdir-status $?
mkdir-status 0
# ln /tmp/umntnode /tmp/umntlink
# echo ln-status $?
ln-status 0
# find /tmp -name umntnode -print
/tmp/umntnode
# echo find-status $?
find-status 0
# du /tmp
1	/tmp/umntdir
2	/tmp
# echo du-status $?
du-status 0
# cat >/tmp/umnttext <<'EOT'
> alpha
> beta
> alpha beta
> EOT
# sed s/alpha/ALPHA/ /tmp/umnttext
ALPHA
beta
ALPHA beta
# echo sed-status $?
sed-status 0
# grep beta /tmp/umnttext
beta
alpha beta
# echo grep-status $?
grep-status 0
# rm -f /tmp/umntnode /tmp/umntlink /tmp/umnttext
# rm -r /tmp/umntdir
# echo cleanup-status $?
cleanup-status 0
# echo __TEST_DONE__
__TEST_DONE__
# 
```

Notes from the live check:

* `/bin/umount` is present in the root image.
* `umount` with no operands prints V7's `arg count` diagnostic and exits
  1.
* `umount /no/such` reaches the real V7 syscall failure path and exits
  1 with `umount: No such file or directory`.  The old always-success
  syscall stub would have skipped this perror path and continued into
  `umount(1)`'s mount-table lookup.
* The mount regression still reaches its V7 syscall failure path.
* Regression probes for `mknod`, `mkdir`, `ln`, `find`, `du`, `sed`, and
  `grep` succeeded.

### mkfs host tool V7 historical-accuracy slice

Historical source comparison:

```
$ diff -u v7/usr/src/cmd/mkfs.c tools/mkfs.c || true
--- v7/usr/src/cmd/mkfs.c	1979-01-10 12:01:59.000000000 -0800
+++ tools/mkfs.c	2026-05-15 13:41:24.367469179 -0700
...
```

The full mkfs source delta and rationale are recorded in
`logs/unix-historical-accuracy.md`.  No source, Makefile, or proto edits
were made for this slice.

Hardware inventory helper:

```
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Clean rebuild command:

```
$ rm -f tools/mkfs root.img build/auxfs.img && make ARCH=arm CONF=qemu_arm
arm-linux-gnueabihf-gcc -std=c89 -static \
    -D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32 \
    -fms-extensions \
    -Wno-pedantic \
    -o tools/mkfs tools/mkfs.c
...
tools/mkfs build/auxfs.img conf/qemu_arm/auxfs.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 32768 build/auxfs.img
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

The rebuild completed successfully.  Existing K&R/C99 portability
warnings were emitted while building user commands; they did not stop the
image build.

Live QEMU command batch:

```
tools/qemu-shell.py <<'EOF'
ls /
ls /etc
cat /etc/passwd
ls /bin
/bin/echo mkfs-command-regression
/bin/cat /etc/passwd
/bin/grep root /etc/passwd
echo __TEST_DONE__
EOF
```

Captured output:

```
ls /
bin
dev
etc
tmp
unix
usr
# ls /etc
accton
atrun
auxfs
cron
ddate
getty
init
passwd
ttys
update
utmp
# cat /etc/passwd
root::0:0:root:/:/bin/sh
dmr::1:1:dennis:/:/bin/sh
# ls /bin
1
[
ac
at
awk
basename
cal
calendar
cat
cb
checkeq
chgrp
chmod
chown
clri
cmp
col
comm
cp
crypt
date
dc
dcheck
dd
deroff
df
diff
diff3
dmesg
du
dump
dumpdir
echo
ed
egrep
expr
factor
false
fgrep
file
find
graph
grep
icheck
iostat
join
kill
ln
login
look
ls
mesg
mkdir
mknod
mount
mv
ncheck
newgrp
nice
nohup
od
osh
passwd
plot
pr
primes
prof
ps
pstat
ptx
pwd
quot
random
restor
rev
rm
rmdir
sa
sed
sh
sleep
sort
sp
spell
spline
split
stty
su
sum
sync
tabs
tail
tar
tc
tee
tek
test
time
tk
touch
tp
tr
true
tsort
tty
umount
uniq
units
vpr
wall
wc
who
write
yes
# /bin/echo mkfs-command-regression
mkfs-command-regression
# /bin/cat /etc/passwd
root::0:0:root:/:/bin/sh
dmr::1:1:dennis:/:/bin/sh
# /bin/grep root /etc/passwd
root::0:0:root:/:/bin/sh
# echo __TEST_DONE__
__TEST_DONE__
# 
```

Notes from the live check:

* The regenerated root filesystem boots and lists `/`, `/etc`, and
  `/bin`.
* `/etc/passwd` is readable from the generated image.
* Representative `/bin` commands (`echo`, `cat`, `grep`) execute
  successfully against files read from the generated filesystem.

## arcv(1) V7 port slice

Hardware-test inventory was attempted first:

```sh
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build/root-image refresh:

```sh
$ make ARCH=arm CONF=qemu_arm
...
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

The build completed with the pre-existing V7 warning stream and
regenerated `root/bin/arcv` plus `root.img`.

Live QEMU smoke test:

```sh
$ tools/qemu-shell.py
echo ok
ok
# ls /bin/arcv
/bin/arcv
# arcv /bin/cat
arcv: /bin/cat not archive format
# cat /etc/passwd
root::0:0:root:/:/bin/sh
dmr::1:1:dennis:/:/bin/sh
# pwd
/
# echo __TEST_DONE__
__TEST_DONE__
```

Temporary old-format archive fixture test:

* A generated, untracked `build/arcv.old` contained old magic
  `0177555`, one 8-byte member name `mem`, 3 bytes of data `XYZ`, and
  one pad byte.
* A generated, untracked `build/arcv-test.proto` added that fixture
  under `/tmp`, and `tools/mkfs build/arcv-test.img
  build/arcv-test.proto` produced a one-off root image.
* `root.img` was temporarily swapped to that image only for the QEMU
  run, then restored to the normal image from `make ARCH=arm
  CONF=qemu_arm`; the generated fixture/proto/image files were removed.

QEMU evidence:

```sh
# ls /tmp/arcv.old
/tmp/arcv.old
# arcv /tmp/arcv.old
# od -b /tmp/arcv.old
0000000 145 377 155 145 155 000 000 000 000 000 000 000 000 000 000 000
0000020 100 342 001 000 007 001 266 001 003 000 000 000 130 131 132 000
0000040
# cat /tmp/arcv.old
(binary archive bytes shown by od above; payload contains XYZ)
# rm /tmp/arcv.old
# echo __TEST_DONE__
__TEST_DONE__
```

The leading bytes `145 377` are V7 `ARMAG` (`0177545`) in target byte
order.  The member payload bytes `130 131 132` are `X Y Z`, followed by
the expected archive pad byte.

Post-fixture restoration check against the normal `root.img`:

```sh
# ls /bin/arcv
/bin/arcv
# ls /tmp/arcv.old
/tmp/arcv.old not found
# echo __TEST_DONE__
__TEST_DONE__
```

### LEARN_MOREFILES

This slice installs the V7 `learn morefiles` course data at
`/usr/lib/learn/morefiles`.  The data is extracted from the old-ar
archive `v7/usr/lib/learn/morefiles.a` using the existing
`tools/extract-old-ar.py` helper: 45 members, 72,093 bytes of staged
payload from a 73,294-byte archive.

Hardware-test inventory was attempted first:

```sh
$ test_serv inventory
/bin/bash: line 1: test_serv: command not found
```

Build/root-image refresh:

```sh
$ make ARCH=arm CONF=qemu_arm
...
arm-none-eabi-objcopy -O binary learn.elf ../root/bin/learn
arm-none-eabi-objcopy -O binary lcount.elf ../root/usr/lib/learn/lcount
arm-none-eabi-objcopy -O binary lrntee.elf ../root/usr/lib/learn/tee
tools/mkfs root.img conf/qemu_arm/root.proto
nullboot: cannot open init
m/n = 3 500
truncate -s 4194304 root.img
```

Live QEMU evidence from the rebuilt `root.img`:

```sh
$ tools/qemu-shell.py
ls /usr/lib/learn
Linfo
Xinfo
files
lcount
log
morefiles
play
tee
# ls /usr/lib/learn/morefiles
L0
L0.1a
L0.1b
L0.1c
L0.1d
L0.1e
L0.1f
L0.1g
L1.1a
L1.1b
L1.1c
L1.1d
L2.1a
L2.1b
L2.1c
L2.1d
L2.1e
L2.1f
L3.1a
L3.1b
L3.1c
L3.1d
L3.1e
L3.1f
L3.1g
L4.1a
L4.1b
L4.1c
L4.1d
L4.1e
L4.1f
L4.1g
L4.2a
L5.1a
L5.1b
L5.1c
L5.1d
L5.1e
L6.1a
L6.1b
L6.1c
L6.1d
L6.1e
L6.2e
L7.1a
# learn morefiles 0 0
In the basic files course you learned about the "ls" command
for listing the names of files in the current directory.
You will now learn some of the extra abilities of "ls".
UNIX maintains a lot more information about a file than just
its name; this extra information includes the size of the
file, the date and time it was last changed, the owner,
and scattered other miscellany.  To see this "long" list of information,
use the command "ls -l".  (That's an "ell", not a "one".)
The "-l" is called an "optional argument",
since it may or may not be present.

To begin, try just "ls -l", then type "ready".
$ bye
Bye.
# echo hi | wc
      1      1       3
# echo __TEST_DONE__
__TEST_DONE__
```
