CC = arm-none-eabi-gcc
AR = arm-none-eabi-ar
CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wno-error=parentheses -Wno-error=dangling-else -Wno-error=misleading-indentation -Wno-error=implicit-fallthrough -Wno-error=int-to-pointer-cast -Wno-error=char-subscripts -Wno-error=sizeof-pointer-div -Wno-error=missing-braces -Wno-error=missing-field-initializers -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../include -I..
SHCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -fms-extensions -Wno-parentheses -Wno-dangling-else -Wno-implicit-int -Wno-implicit-function-declaration -Wno-return-type -Wno-return-mismatch -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-sign-compare -Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -Wno-main -Wno-array-bounds -Wno-missing-braces -Wno-type-limits -Wno-implicit-fallthrough -Wno-pedantic -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../include -I..
# v7 libm/libdbm sources are K&R-style with implicit-int returns and
# no-prototype function decls; build them with the same loose flags the
# shell uses.
LIBMCFLAGS = $(SHCFLAGS)
LIBDBMCFLAGS = $(SHCFLAGS) -I../libdbm
LIBMPCFLAGS = $(SHCFLAGS)
LIBPLOTCFLAGS = $(SHCFLAGS)
EDCFLAGS = $(SHCFLAGS) -Wno-builtin-declaration-mismatch
AWKCFLAGS = $(SHCFLAGS) -Os -fno-asynchronous-unwind-tables -fno-unwind-tables -Dmalloc=malloc -Dfree=free -I../cmd/awk
LDFLAGS = -nostdlib -T u.ld
LDLIBS = -L. -lc -lgcc

# crt0 is link-line head, not in libc.a (the entry symbol must come first
# and is not pulled out of an archive on demand).
CRT = crt0.o crt0c.o

# Objects packed into libc.a.  The linker pulls these in only on demand,
# so atof can finally live here without bloating every binary.
LIBOBJ = syscall.o sys.o compat.o v7crypt.o l3.o \
      getpwent.o getpwnam.o getpwuid.o strncat.o ttyslot.o execvp.o getenv.o \
      atoi.o atol.o atof.o index.o rindex.o isatty.o perror.o \
      strcat.o strcmp.o strcpy.o strlen.o strncmp.o strncpy.o \
      swab.o rand.o mktemp.o errlst.o ttyname.o mkdir.o \
      qsort.o calloc.o tell.o timezone.o getlogin.o \
      data.o fopen.o freopen.o findiop.o endopen.o filbuf.o flsbuf.o \
      fgetc.o fputc.o fgets.o fputs.o gets.o puts.o rdwr.o \
      fseek.o ftell.o rew.o setbuf.o ungetc.o clrerr.o \
      getchar.o putchar.o strout.o doprnt.o printf.o fprintf.o sprintf.o \
      doscan.o scanf.o malloc.o getpass.o ctime.o system.o memcpy.o nlist.o \
      math_helpers.o \
      ecvt.o fdopen.o gcvt.o getgrent.o getgrgid.o getgrnam.o getpw.o \
      getw.o popen.o putw.o
# math_helpers.o replaces v7's PDP-11 frexp11.s/ldexp11.s/modf11.s --
# the IEEE-754 doubles are decomposed via union bit-manipulation now
# that the host ABI is AAPCS softfloat instead of pdp11 fp.
# ecvt/fdopen/gcvt/getgrent/getgrgid/getgrnam/getpw/getw/popen/putw are
# carried over verbatim from v7/usr/src/libc/{gen,stdio}; the only edit
# is ecvt.c gaining a file-scope static forward decl for its private
# `cvt` helper (same K&R extern-vs-static linkage fix used in libm/sin
# et al).  ctype_.c is intentionally NOT carried over: the port's
# include/ctype.h uses inline range checks rather than the v7 _ctype_
# lookup table.
# lib/abs.o is intentionally excluded -- cmd/chmod.c carries its
# own `abs(void)` parser helper that would collide with the v7
# libc abs(int).  No port currently calls libc abs(); the file
# is on disk only to satisfy the original-diffs ratchet.
# lib/acct.o is intentionally excluded -- acct(2) is now a real
# syscall stub in lib/sys.s (SYS acct,51).  Keeping the old C
# no-op in libc.a would shadow the assembler entry point and
# accton(8) would silently no-op against the kernel.

# v7 sh has its own internal `getenv()` (a void(void) that walks
# environ[] and registers each entry as a sh variable -- not libc
# getenv).  Build sh's libc.a without getenv to avoid a duplicate
# symbol clash.
SHLIBOBJ = syscall.o sys.o compat.o v7crypt.o l3.o \
      getpwent.o getpwnam.o getpwuid.o strncat.o ttyslot.o execvp.o \
      atoi.o atol.o atof.o index.o rindex.o isatty.o perror.o \
      strcat.o strcmp.o strcpy.o strlen.o strncmp.o strncpy.o \
      swab.o rand.o mktemp.o errlst.o ttyname.o mkdir.o \
      qsort.o calloc.o tell.o timezone.o getlogin.o \
      data.o fopen.o freopen.o findiop.o endopen.o filbuf.o flsbuf.o \
      fgetc.o fputc.o fgets.o fputs.o gets.o puts.o rdwr.o \
      fseek.o ftell.o rew.o setbuf.o ungetc.o clrerr.o \
      getchar.o putchar.o strout.o doprnt.o printf.o fprintf.o sprintf.o \
      doscan.o scanf.o malloc.o getpass.o ctime.o system.o memcpy.o nlist.o \
      math_helpers.o \
      ecvt.o fdopen.o gcvt.o getgrent.o getgrgid.o getgrnam.o getpw.o \
      getw.o popen.o putw.o

# libm.a -- v7 math library (1166 LoC, K&R sources from v7/usr/src/libm
# carried over verbatim except for four files where the v7 K&R idiom of
# block-scope `double f();` extern decls + later `static double f(...)`
# definitions of the same symbol no longer compiles under C99's
# static/extern linkage check.  Those four (sin.c, atan.c, j0.c, j1.c)
# got file-scope `static` forward decls and lost the block-scope ones;
# no body line changed.
LIBMOBJ = m_asin.o m_atan.o m_exp.o m_fabs.o m_floor.o m_hypot.o \
      m_j0.o m_j1.o m_jn.o m_log.o m_pow.o m_sin.o m_sinh.o m_sqrt.o \
      m_tan.o m_tanh.o

# libdbm.a -- v7 ndbm precursor.  Single TU carried over verbatim.
LIBDBMOBJ = dbm.o

# libmp.a -- v7 multi-precision arithmetic.  693 LoC carried over byte-
# identical to v7/usr/src/libmp.  No source edits.
LIBMPOBJ = mp_gcd.o mp_madd.o mp_mdiv.o mp_mout.o mp_msqrt.o mp_mult.o \
      mp_pow.o mp_util.o

# libplot.a -- v7 plot(1) library, the generic (stdout-emitting) driver
# from libplot/plot.c.a.  The terminal-specific drivers (t300, t300s,
# t450, t4014, vt0) target hardware that doesn't exist on qemu virt and
# have pre-K&R initializer syntax that this port doesn't accept; they
# are not currently built.  Sources are byte-identical to v7.
LIBPLOTOBJ = pl_arc.o pl_box.o pl_circle.o pl_close.o pl_cont.o pl_dot.o \
      pl_erase.o pl_label.o pl_line.o pl_linmod.o pl_move.o pl_open.o \
      pl_point.o pl_putsi.o pl_space.o

ETC = init getty accton update atrun cron
BIN = login cat echo ls pwd sync arcv rev yes wc basename dirname sum tty cmp comm cal od head tail grep test look cp rm ln mkdir rmdir mv chmod chown chgrp sleep tee touch tr uniq du date kill nice mknod who mesg time split checkeq calendar tsort file join col fgrep egrep su newgrp random crypt pr dd stty tabs diff wall write df clri dcheck icheck ncheck cb sp find sort mount umount passwd diff3 at units spline restor tk dmesg sa ptx vpr dump dumpdir graph factor primes expr ac iostat dkstat tek printf id whoami seq xargs paste tac nl expand unexpand cut env fmt uname logname which hostname nproc chroot mktemp getopt timeout watch cksum column shuf truncate printenv link unlink fold groups pidtest sigwaittest segvtest orphantest exittest errtest
# ps and pstat both pull in h/tty.h (anonymous `struct tc;` union
# member) and h/user.h (anonymous unions/structs); both need
# -fms-extensions plus -Wno-error={pedantic,sign-compare,
# missing-field-initializers} on top of the baseline c99 flags.
# Routed through their own loop instead of $(BIN).
PSBIN = ps pstat pgrep pkill pidof
USRLIB = makekey diffh
USRGAMES = fortune arithmetic hangman backgammon fish quiz wump
SHSRC = args blok builtin cmd ctype error expand fault io macro main msg name print service setbrk stak string word xec
SHOBJ = args.o blok.o builtin.o cmd.o ctype.o error.o expand.o fault.o io.o macro.o main.o msg.o name.o print.o service.o setbrk.o stak.o string.o word.o xec.o
LEARNSRC = learn copy dounit list makpipe maktee mem mysys selsub selunit start whatnow wrapup
LEARNOBJ = learn.o copy.o dounit.o list.o makpipe.o maktee.o mem.o mysys.o selsub.o selunit.o start.o whatnow.o wrapup.o

all:	$(CRT) libc.a libsh.a libm.a libdbm.a libmp.a libplot.a
	mkdir -p ../root/etc ../root/bin ../root/usr/lib ../root/usr/games ../root/usr/lib/learn
	cp ../v7/bin/1 ../root/bin/1
	cp ../v7/bin/true ../root/bin/true
	cp ../v7/bin/false ../root/bin/false
	cp ../v7/bin/nohup ../root/bin/nohup
	cp ../v7/bin/plot ../root/bin/plot
	chmod 755 ../root/bin/1 ../root/bin/true ../root/bin/false ../root/bin/nohup ../root/bin/plot
	set -e; for i in $(ETC); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c -o cmd-$$i.o; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) cmd-$$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/etc/$$i; \
	done
	set -e; for i in $(BIN); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c -o cmd-$$i.o; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) cmd-$$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/bin/$$i; \
	done
	$(CC) $(SHCFLAGS) -c ../cmd/deroff.c
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o deroff.elf $(CRT) deroff.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary deroff.elf ../root/bin/deroff
	set -e; for i in $(USRLIB); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/usr/lib/$$i; \
	done
	set -e; for i in $(USRGAMES); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/usr/games/$$i; \
	done
	$(CC) $(EDCFLAGS) -c ../cmd/ed.c
	$(CC) $(EDCFLAGS) $(LDFLAGS) -o ed.elf $(CRT) ed.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary ed.elf ../root/bin/ed
	set -e; for i in sed0 sed1; do \
		$(CC) $(SHCFLAGS) -I../cmd/sed -c ../cmd/sed/$$i.c; \
	done
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o sed.elf $(CRT) sed0.o sed1.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary sed.elf ../root/bin/sed
	# awk(1): generated parser/procedure-table sources are kept in
	# cmd/awk so the target build does not depend on yacc/lex.  The
	# optimized build keeps the flat binary below v7 mkfs' 64KB
	# single-file limit.
	set -e; for i in awk.g awk.lx awk_math b main token tran lib run parse proctab; do \
		$(CC) $(AWKCFLAGS) -c ../cmd/awk/$$i.c; \
	done
	$(CC) $(AWKCFLAGS) $(LDFLAGS) -o awk.elf $(CRT) awk.g.o awk.lx.o awk_math.o b.o main.o token.o tran.o lib.o run.o parse.o proctab.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary awk.elf ../root/bin/awk
	# quot(1) carries its own file-scope `int acct(struct dinode *)`
	# helper that collides with the new libc syscall stub for acct(2)
	# in sys.s.  Compile quot.c with `-Dacct=quot_acct` to rename the
	# local symbol; the BIN-loop above can't carry the extra flag, so
	# quot gets its own one-off rule here.
	$(CC) $(CFLAGS) -Dacct=quot_acct -c ../cmd/quot.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o quot.elf $(CRT) quot.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary quot.elf ../root/bin/quot
	# ps/pstat need -fms-extensions for h/tty.h's anonymous
	# `struct tc;` union member and h/user.h's anonymous unions/
	# structs; the (also K&R-era) sign-compare in ps.c's within()
	# is harmless on this target.  Compile with the project's
	# baseline strict flags but those two warnings demoted.
	set -e; for i in $(PSBIN); do \
		$(CC) -std=c99 -Wall -Werror -Wno-error=parentheses -Wno-error=dangling-else -fms-extensions -Wno-error=pedantic -Wno-error=sign-compare -Wno-error=missing-field-initializers -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../include -I.. -c ../cmd/$$i.c; \
		$(CC) -std=c99 -Wall -Werror -Wno-error=parentheses -Wno-error=dangling-else -fms-extensions -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/bin/$$i; \
	done
	set -e; for i in $(SHSRC); do \
		$(CC) $(SHCFLAGS) -I../cmd/sh -c ../cmd/sh/$$i.c; \
	done
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o sh.elf $(CRT) $(SHOBJ) -L. -lsh -lgcc
	arm-none-eabi-objcopy -O binary sh.elf ../root/bin/sh
	# osh(1): the v7 Thompson-shell carryover.  It is K&R-style top to
	# bottom (implicit-int signatures, returns without prototypes, pointer-
	# vs-int comparisons) and needs the same permissive SHCFLAGS the v7 sh
	# itself rides on.  Pre-K&R compound-assignment operators (=+, =-, =|)
	# were mechanically rewritten to the +=/-=/|= forms in cmd/osh.c so the
	# C99 parser accepts the file.
	$(CC) $(SHCFLAGS) -c ../cmd/osh.c
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o osh.elf $(CRT) osh.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary osh.elf ../root/bin/osh
	$(CC) $(CFLAGS) -I../cmd/dc -c ../cmd/dc/dc.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o dc.elf $(CRT) dc.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary dc.elf ../root/bin/dc
	$(CC) $(CFLAGS) -I../cmd/tar -c ../cmd/tar/tar.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o tar.elf $(CRT) tar.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary tar.elf ../root/bin/tar
	set -e; for i in tp0 tp1 tp2 tp3; do \
		$(CC) $(CFLAGS) -I../cmd/tp -c ../cmd/tp/$$i.c; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -o tp.elf $(CRT) tp0.o tp1.o tp2.o tp3.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary tp.elf ../root/bin/tp
	set -e; for i in spell spellin spellout; do \
		$(CC) $(CFLAGS) -I../cmd/spell -c ../cmd/spell/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/usr/lib/$$i; \
	done
	set -e; for i in $(LEARNSRC); do \
		$(CC) $(SHCFLAGS) -I../cmd/learn -c ../cmd/learn/$$i.c; \
	done
	$(CC) $(SHCFLAGS) -I../cmd/learn -c ../cmd/learn/lcount.c
	$(CC) $(SHCFLAGS) -I../cmd/learn -c ../cmd/learn/tee.c -o lrntee.o
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o learn.elf $(CRT) $(LEARNOBJ) $(LDLIBS)
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o lcount.elf $(CRT) lcount.o $(LDLIBS)
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o lrntee.elf $(CRT) lrntee.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary learn.elf ../root/bin/learn
	arm-none-eabi-objcopy -O binary lcount.elf ../root/usr/lib/learn/lcount
	arm-none-eabi-objcopy -O binary lrntee.elf ../root/usr/lib/learn/tee

libc.a: $(LIBOBJ)
	rm -f libc.a
	$(AR) rcs libc.a $(LIBOBJ)

libsh.a: $(SHLIBOBJ)
	rm -f libsh.a
	$(AR) rcs libsh.a $(SHLIBOBJ)

# Pattern rules for libm and libdbm.  v7 sources live under ../libm
# and ../libdbm; the m_<x>.o names avoid colliding with similarly named
# sources elsewhere (e.g. lib/atof.c's local ldexp/etc).
m_%.o: ../libm/%.c
	$(CC) $(LIBMCFLAGS) -c $< -o $@

libm.a: $(LIBMOBJ)
	rm -f libm.a
	$(AR) rcs libm.a $(LIBMOBJ)

dbm.o: ../libdbm/dbm.c ../libdbm/dbm.h
	$(CC) $(LIBDBMCFLAGS) -c ../libdbm/dbm.c -o dbm.o

libdbm.a: $(LIBDBMOBJ)
	rm -f libdbm.a
	$(AR) rcs libdbm.a $(LIBDBMOBJ)

mp_%.o: ../libmp/%.c
	$(CC) $(LIBMPCFLAGS) -c $< -o $@

libmp.a: $(LIBMPOBJ)
	rm -f libmp.a
	$(AR) rcs libmp.a $(LIBMPOBJ)

pl_%.o: ../libplot/plot/%.c
	$(CC) $(LIBPLOTCFLAGS) -c $< -o $@

libplot.a: $(LIBPLOTOBJ)
	rm -f libplot.a
	$(AR) rcs libplot.a $(LIBPLOTOBJ)

crt0.o: crt0.s
	$(CC) $(CFLAGS) -c crt0.s

crt0c.o: crt0.c
	$(CC) $(CFLAGS) -c crt0.c -o crt0c.o

v7crypt.o: crypt.c
	$(CC) $(CFLAGS) -c crypt.c -o v7crypt.o

# l3.c is K&R-style with implicit int returns; use the looser SHCFLAGS.
l3.o: l3.c
	$(CC) $(SHCFLAGS) -c l3.c

# The v7 libc/{gen,stdio} pickups are all K&R-style.  Same treatment.
ecvt.o: ecvt.c
	$(CC) $(SHCFLAGS) -c ecvt.c
fdopen.o: fdopen.c
	$(CC) $(SHCFLAGS) -c fdopen.c
gcvt.o: gcvt.c
	$(CC) $(SHCFLAGS) -c gcvt.c
getgrent.o: getgrent.c
	$(CC) $(SHCFLAGS) -c getgrent.c
getgrgid.o: getgrgid.c
	$(CC) $(SHCFLAGS) -c getgrgid.c
getgrnam.o: getgrnam.c
	$(CC) $(SHCFLAGS) -c getgrnam.c
getpw.o: getpw.c
	$(CC) $(SHCFLAGS) -c getpw.c
getw.o: getw.c
	$(CC) $(SHCFLAGS) -c getw.c
popen.o: popen.c
	$(CC) $(SHCFLAGS) -c popen.c
putw.o: putw.c
	$(CC) $(SHCFLAGS) -c putw.c

.s.o:
	$(CC) $(CFLAGS) -c $<

.c.o:
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o *.elf *.a m_*.o mp_*.o pl_*.o dbm.o ../root/etc/init ../root/etc/getty ../root/etc/update
	rm -f ../root/bin/login ../root/bin/sh ../root/bin/cat
	rm -f ../root/bin/echo ../root/bin/ls ../root/bin/pwd ../root/bin/sync
	rm -f ../root/bin/rev
	rm -f ../root/bin/arcv
	rm -f ../root/bin/yes ../root/bin/wc ../root/bin/basename ../root/bin/sum
	rm -f ../root/bin/tty ../root/bin/cmp ../root/bin/comm ../root/bin/cal
	rm -f ../root/bin/od ../root/bin/head ../root/bin/tail ../root/bin/grep ../root/bin/test
	rm -f ../root/bin/look ../root/bin/cp ../root/bin/rm ../root/bin/ln
	rm -f ../root/bin/mkdir ../root/bin/rmdir ../root/bin/mv
	rm -f ../root/bin/chmod ../root/bin/chown ../root/bin/chgrp
	rm -f ../root/bin/sleep ../root/bin/tee ../root/bin/touch ../root/bin/tr
	rm -f ../root/bin/uniq ../root/bin/du ../root/bin/date ../root/bin/kill
	rm -f ../root/bin/nice ../root/bin/mknod ../root/bin/who ../root/bin/mesg
	rm -f ../root/bin/time ../root/bin/split
	rm -f ../root/bin/checkeq ../root/bin/calendar ../root/bin/tsort
	rm -f ../root/bin/file
	rm -f ../root/bin/join
	rm -f ../root/bin/col
	rm -f ../root/bin/fgrep ../root/bin/egrep
	rm -f ../root/bin/su ../root/bin/newgrp
	rm -f ../root/bin/passwd
	rm -f ../root/bin/random
	rm -f ../root/bin/crypt ../root/usr/lib/makekey ../root/usr/lib/diffh
	rm -f ../root/bin/pr
	rm -f ../root/bin/dd
	rm -f ../root/bin/stty
	rm -f ../root/bin/tabs
	rm -f ../root/bin/diff
	rm -f ../root/bin/wall
	rm -f ../root/bin/write
	rm -f ../root/bin/df
	rm -f ../root/bin/clri
	rm -f ../root/bin/dcheck ../root/bin/icheck ../root/bin/ncheck
	rm -f ../root/bin/cb
	rm -f ../root/bin/sp
	rm -f ../root/bin/find
	rm -f ../root/bin/sort
	rm -f ../root/bin/spell ../root/bin/deroff
	rm -f ../root/bin/ed
	rm -f ../root/bin/sed
	rm -f ../root/bin/awk
	rm -f ../root/bin/1
	rm -f ../root/bin/true ../root/bin/false
	rm -f ../root/bin/dmesg
	rm -f ../root/bin/factor ../root/bin/primes
	rm -f ../root/bin/expr
	rm -f ../root/bin/iostat
	rm -f ../root/bin/dc
	rm -f ../root/bin/tar
	rm -f ../root/bin/tp
	rm -f ../root/bin/plot ../root/bin/tek
	rm -f ../root/bin/nohup
	rm -f ../root/bin/learn ../root/usr/lib/learn/lcount ../root/usr/lib/learn/tee
