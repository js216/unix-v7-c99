CC = arm-none-eabi-gcc
AR = arm-none-eabi-ar
CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../include -I..
# awk binaries: strict CFLAGS plus the -Os/unwind/define flags that keep
# the flat binary under v7 mkfs' 64KB single-file limit.  The one int<->
# pointer conversion the yacc-generated awk.g.c does (YYSTYPE=int holding
# packed node* values) is now suppressed file-locally by a #pragma in
# awk.g.c itself, so AWKCFLAGS no longer needs any -Wno-* flags.
AWKCFLAGS = $(CFLAGS) -Os -fno-asynchronous-unwind-tables -fno-unwind-tables -Dmalloc=malloc -Dfree=free -I../cmd/awk
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
      ecvt.o fdopen.o gcvt.o getgrent.o getgrgid.o getgrnam.o \
      getw.o putw.o
# math_helpers.o replaces v7's PDP-11 frexp11.s/ldexp11.s/modf11.s --
# the IEEE-754 doubles are decomposed via union bit-manipulation now
# that the host ABI is AAPCS softfloat instead of pdp11 fp.
# ecvt/fdopen/gcvt/getgrent/getgrgid/getgrnam/getw/putw are
# carried over verbatim from v7/usr/src/libc/{gen,stdio}; the only edit
# is ecvt.c gaining a file-scope static forward decl for its private
# `cvt` helper (same K&R extern-vs-static linkage fix used in libm/sin
# et al).  ctype_.c is intentionally NOT carried over: the port's
# include/ctype.h uses inline range checks rather than the v7 _ctype_
# lookup table.

# v7 sh has its own internal `getenv()` (a void(void) that walks
# environ[] and registers each entry as a sh variable -- not libc
# getenv).  Build sh's libc.a without getenv to avoid a duplicate
# symbol clash.
SHLIBOBJ = $(filter-out getenv.o,$(LIBOBJ))

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

ETC = init getty accton update atrun cron
BIN = login cat echo ls pwd sync arcv rev yes wc basename dirname sum tty cmp comm cal od head tail grep test look cp rm ln mkdir rmdir mv chmod chown chgrp sleep tee touch tr uniq du date kill nice mknod who mesg time split checkeq calendar tsort file join col fgrep egrep su newgrp random crypt pr dd stty tabs diff wall write df clri dcheck icheck ncheck cb sp find sort mount umount passwd diff3 at units spline restor tk dmesg sa ptx vpr dump dumpdir graph factor primes expr ac iostat dkstat tek printf id whoami seq xargs paste tac nl expand unexpand cut env fmt uname logname which hostname nproc chroot mktemp getopt timeout watch cksum column shuf truncate printenv link unlink fold groups pidtest sigwaittest segvtest orphantest exittest errtest stattest sigfromchild unlinkopen sigstorm prof tc
# ps/pstat/pgrep/pkill/pidof share a private build loop only so their
# objects are kept out of the BIN loop's automatic crt0/libc linking
# pattern -- the source-level flags are the project's strict CFLAGS.
PSBIN = ps pstat pgrep pkill pidof
USRLIB = makekey diffh
USRGAMES = fortune arithmetic hangman backgammon fish quiz wump
SHSRC = args blok builtin cmd ctype error expand fault io macro main msg name print service setbrk stak string word xec
SHOBJ = args.o blok.o builtin.o cmd.o ctype.o error.o expand.o fault.o io.o macro.o main.o msg.o name.o print.o service.o setbrk.o stak.o string.o word.o xec.o
LEARNSRC = learn copy dounit list makpipe maktee mem mysys selsub selunit start whatnow wrapup
LEARNOBJ = learn.o copy.o dounit.o list.o makpipe.o maktee.o mem.o mysys.o selsub.o selunit.o start.o whatnow.o wrapup.o

all:	$(CRT) libc.a libsh.a libm.a
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
	$(CC) $(CFLAGS) -c ../cmd/deroff.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o deroff.elf $(CRT) deroff.o $(LDLIBS)
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
	$(CC) $(CFLAGS) -c ../cmd/ed.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o ed.elf $(CRT) ed.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary ed.elf ../root/bin/ed
	set -e; for i in sed0 sed1; do \
		$(CC) $(CFLAGS) -I../cmd/sed -c ../cmd/sed/$$i.c; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -o sed.elf $(CRT) sed0.o sed1.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary sed.elf ../root/bin/sed
	# awk(1): generated parser/procedure-table sources are kept in
	# cmd/awk so the target build does not depend on yacc/lex.  The
	# -Os build keeps the flat binary below v7 mkfs' 64KB single-file
	# limit.  All awk sources use the same strict-C99 AWKCFLAGS now;
	# awk.g.c's one int<->pointer mismatch is scoped via a #pragma in
	# the file itself.
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
	set -e; for i in $(PSBIN); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/bin/$$i; \
	done
	set -e; for i in $(SHSRC); do \
		$(CC) $(CFLAGS) -I../cmd/sh -c ../cmd/sh/$$i.c; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -o sh.elf $(CRT) $(SHOBJ) -L. -lsh -lgcc
	arm-none-eabi-objcopy -O binary sh.elf ../root/bin/sh
	# osh(1): the v7 Thompson-shell carryover.  Pre-K&R compound-assignment
	# operators (=+, =-, =|) were mechanically rewritten to +=/-=/|= so the
	# C99 parser accepts the file; later passes added prototypes, pointer/int
	# casts at the K&R "packed pointer" sites (t[DLEF] etc.), explicit
	# fallthrough markers, and trailing return(0) in int-returning functions.
	$(CC) $(CFLAGS) -c ../cmd/osh.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o osh.elf $(CRT) osh.o $(LDLIBS)
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
		$(CC) $(CFLAGS) -I../cmd/learn -c ../cmd/learn/$$i.c; \
	done
	$(CC) $(CFLAGS) -I../cmd/learn -c ../cmd/learn/lcount.c
	$(CC) $(CFLAGS) -I../cmd/learn -c ../cmd/learn/tee.c -o lrntee.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o learn.elf $(CRT) $(LEARNOBJ) $(LDLIBS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o lcount.elf $(CRT) lcount.o $(LDLIBS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o lrntee.elf $(CRT) lrntee.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary learn.elf ../root/bin/learn
	arm-none-eabi-objcopy -O binary lcount.elf ../root/usr/lib/learn/lcount
	arm-none-eabi-objcopy -O binary lrntee.elf ../root/usr/lib/learn/tee

libc.a: $(LIBOBJ)
	rm -f libc.a
	$(AR) rcs libc.a $(LIBOBJ)

libsh.a: $(SHLIBOBJ)
	rm -f libsh.a
	$(AR) rcs libsh.a $(SHLIBOBJ)

# Pattern rule for libm.  v7 sources live under ../libm; the m_<x>.o
# names avoid colliding with similarly named sources elsewhere (e.g.
# lib/atof.c's local ldexp/etc).
m_%.o: ../libm/%.c
	$(CC) $(CFLAGS) -c $< -o $@

libm.a: $(LIBMOBJ)
	rm -f libm.a
	$(AR) rcs libm.a $(LIBMOBJ)

crt0.o: crt0.s
	$(CC) $(CFLAGS) -c crt0.s

crt0c.o: crt0.c
	$(CC) $(CFLAGS) -c crt0.c -o crt0c.o

v7crypt.o: crypt.c
	$(CC) $(CFLAGS) -c crypt.c -o v7crypt.o


.s.o:
	$(CC) $(CFLAGS) -c $<

.c.o:
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o *.elf *.a m_*.o ../root/etc/init ../root/etc/getty ../root/etc/update
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
