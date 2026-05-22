CC = arm-none-eabi-gcc
AR = arm-none-eabi-ar
ROOT = ../../..
CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../../include -I../..
# awk binaries: strict CFLAGS plus the -Os/unwind/define flags that keep
# the flat binary under v7 mkfs' 64KB single-file limit.  The one int<->
# pointer conversions in yacc-generated awk.g.c are build-only noise:
# the generated source is removed again after awk is linked.
AWKCFLAGS = $(CFLAGS) -Os -fno-asynchronous-unwind-tables -fno-unwind-tables -Dmalloc=malloc -Dfree=free -I../cmd/awk -Wno-int-conversion -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast -Wno-implicit-function-declaration -Wno-builtin-declaration-mismatch -Wno-implicit-int -Wno-return-type -Wno-unused-function -Wno-discarded-qualifiers
LDFLAGS = -nostdlib -T u.ld
LDLIBS = -L. -lc -lgcc

# crt0 is link-line head, not in libc.a (the entry symbol must come first
# and is not pulled out of an archive on demand).
CRT = crt0.o crt0c.o

# Objects packed into libc.a.  The linker pulls these in only on demand,
# so atof can finally live here without bloating every binary.
SYSOBJ = access.o acct.o alarm.o brk.o chdir.o chmod.o chown.o chroot.o \
      close.o creat.o dup.o execv.o execl.o execve.o exit_sys.o fork.o \
      fstat.o ftime.o getgid.o getpid.o getuid.o gtty.o ioctl.o kill.o \
      link.o lock.o lseek.o mknod.o mount.o nice.o open.o pause.o pipe.o \
      profil.o ptrace.o read.o setgid.o setuid.o signal.o \
      stat.o stime.o stty.o sync.o time_sys.o times.o umask.o umount.o \
      unlink.o utime.o wait.o write.o
GENOBJ = abort.o exit.o sleep.o popen.o

LIBOBJ = syscall.o $(SYSOBJ) $(GENOBJ) v7crypt.o l3.o \
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

# v7 usr/doc/regen says single-file commands are rebuilt through
# /usr/src/cmd/cmake; subdirectory commands use their own makefiles.
# This cross build cannot execute cmake directly because it names the
# native v7 cc/as/yacc toolchain, but it does use cmd/cmake as the
# inventory for ordinary command names.
CMAKE = ../cmd/cmake
ETC = init getty accton update atrun cron
BIN = login cat echo ls pwd sync arcv rev yes wc basename sum tty cmp comm cal od tail grep test look cp rm ln mkdir rmdir mv chmod chown chgrp sleep tee touch tr uniq du date kill nice mknod who mesg time split checkeq calendar tsort file join col fgrep egrep su newgrp random crypt pr dd stty tabs diff wall write df clri dcheck icheck ncheck cb sp find sort mount umount passwd diff3 at units spline restor tk dmesg sa ptx vpr dump dumpdir graph factor primes expr ac iostat printf chroot mktemp link unlink prof tc
# ps/pstat share a private build loop only so their
# objects are kept out of the BIN loop's automatic crt0/libc linking
# pattern -- the source-level flags are the project's strict CFLAGS.
PSBIN = ps pstat
USRLIB = makekey diffh
USRGAMES = fortune arithmetic hangman backgammon fish quiz wump
SHSRC = args blok builtin cmd ctype error expand fault io macro main msg name print service setbrk stak string word xec
SHOBJ = args.o blok.o builtin.o cmd.o ctype.o error.o expand.o fault.o io.o macro.o main.o msg.o name.o print.o service.o setbrk.o stak.o string.o word.o xec.o
CMAKE_CMDS = $(filter-out awk chroot dc link mktemp printf sed sh spell tar tp unlink,$(ETC) $(BIN) $(USRLIB) $(PSBIN))

all:	check-cmake $(CRT) libc.a libsh.a libm.a
	mkdir -p $(ROOT)/etc $(ROOT)/bin $(ROOT)/usr/lib $(ROOT)/usr/games
	cp $(ROOT)/v7/bin/1 $(ROOT)/bin/1
	cp $(ROOT)/v7/bin/true $(ROOT)/bin/true
	cp $(ROOT)/v7/bin/false $(ROOT)/bin/false
	cp $(ROOT)/v7/bin/nohup $(ROOT)/bin/nohup
	chmod 755 $(ROOT)/bin/1 $(ROOT)/bin/true $(ROOT)/bin/false $(ROOT)/bin/nohup
	set -e; for i in $(ETC); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c -o cmd-$$i.o; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) cmd-$$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf $(ROOT)/etc/$$i; \
	done
	set -e; for i in $(BIN); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c -o cmd-$$i.o; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) cmd-$$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf $(ROOT)/bin/$$i; \
	done
	$(CC) $(CFLAGS) -c ../cmd/deroff.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o deroff.elf $(CRT) deroff.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary deroff.elf $(ROOT)/bin/deroff
	set -e; for i in $(USRLIB); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf $(ROOT)/usr/lib/$$i; \
	done
	set -e; for i in $(USRGAMES); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf $(ROOT)/usr/games/$$i; \
	done
	$(CC) $(CFLAGS) -c ../cmd/ed.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o ed.elf $(CRT) ed.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary ed.elf $(ROOT)/bin/ed
	set -e; for i in sed0 sed1; do \
		$(CC) $(CFLAGS) -I../cmd/sed -c ../cmd/sed/$$i.c; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -o sed.elf $(CRT) sed0.o sed1.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary sed.elf $(ROOT)/bin/sed
	# awk(1): follow v7's awk/makefile pattern: generate parser,
	# lexer, and proctab, link awk, then remove generated sources.
	cd ../cmd/awk && bison -y -d awk.g.y && mv y.tab.c awk.g.c && mv y.tab.h awk.h
	cd ../cmd/awk && flex -o awk.lx.c awk.lx.l
	cd ../cmd/awk && sed -i '/#include <string.h>/d;/#include <stdlib.h>/d' awk.lx.c
	cd ../cmd/awk && sed -i '1i #include <stddef.h>' awk.lx.c
	cd ../cmd/awk && perl -0pi -e 's/#define ECHO [^\n]+/#define ECHO do { } while (0)/' awk.lx.c
	cd ../cmd/awk && cc -std=gnu89 -w -c token.c -o proc-token.o && cc -std=gnu89 -w -o proc proc.c proc-token.o && ./proc > proctab.c && rm -f proc proc-token.o
	set -e; for i in awk.g awk.lx b main token tran lib run parse proctab; do \
		$(CC) $(AWKCFLAGS) -c ../cmd/awk/$$i.c; \
	done
	$(CC) $(AWKCFLAGS) $(LDFLAGS) -o awk.elf $(CRT) awk.g.o awk.lx.o b.o main.o token.o tran.o lib.o run.o parse.o proctab.o -L. -lm -lc -lgcc
	arm-none-eabi-objcopy -O binary awk.elf $(ROOT)/bin/awk
	rm -f ../cmd/awk/awk.g.c ../cmd/awk/awk.h ../cmd/awk/awk.lx.c ../cmd/awk/proctab.c
	# quot(1) carries its own file-scope `int acct(struct dinode *)`
	# helper that collides with the new libc syscall stub for acct(2)
	# in sys.s.  Compile quot.c with `-Dacct=quot_acct` to rename the
	# local symbol; the BIN-loop above can't carry the extra flag, so
	# quot gets its own one-off rule here.
	$(CC) $(CFLAGS) -Dacct=quot_acct -c ../cmd/quot.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o quot.elf $(CRT) quot.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary quot.elf $(ROOT)/bin/quot
	set -e; for i in $(PSBIN); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf $(ROOT)/bin/$$i; \
	done
	set -e; for i in $(SHSRC); do \
		$(CC) $(CFLAGS) -I../cmd/sh -c ../cmd/sh/$$i.c; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -o sh.elf $(CRT) $(SHOBJ) -L. -lsh -lgcc
	arm-none-eabi-objcopy -O binary sh.elf $(ROOT)/bin/sh
	# osh(1): the v7 Thompson-shell carryover.  Pre-K&R compound-assignment
	# operators (=+, =-, =|) were mechanically rewritten to +=/-=/|= so the
	# C99 parser accepts the file; later passes added prototypes, pointer/int
	# casts at the K&R "packed pointer" sites (t[DLEF] etc.), explicit
	# fallthrough markers, and trailing return(0) in int-returning functions.
	$(CC) $(CFLAGS) -c ../cmd/osh.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o osh.elf $(CRT) osh.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary osh.elf $(ROOT)/bin/osh
	$(CC) $(CFLAGS) -I../cmd/dc -c ../cmd/dc/dc.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o dc.elf $(CRT) dc.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary dc.elf $(ROOT)/bin/dc
	$(CC) $(CFLAGS) -I../cmd/tar -c ../cmd/tar/tar.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o tar.elf $(CRT) tar.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary tar.elf $(ROOT)/bin/tar
	set -e; for i in tp0 tp1 tp2 tp3; do \
		$(CC) $(CFLAGS) -I../cmd/tp -c ../cmd/tp/$$i.c; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -o tp.elf $(CRT) tp0.o tp1.o tp2.o tp3.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary tp.elf $(ROOT)/bin/tp
	set -e; for i in spell spellin spellout; do \
		$(CC) $(CFLAGS) -I../cmd/spell -c ../cmd/spell/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(CRT) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf $(ROOT)/usr/lib/$$i; \
	done

check-cmake:
	@set -e; for i in $(CMAKE_CMDS); do \
		grep -q "^[	 ]*$$i)" $(CMAKE) || { echo "missing $$i in $(CMAKE)"; exit 1; }; \
	done

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

exit_sys.o: sys/exit.s
	$(CC) $(CFLAGS) -c sys/exit.s -o exit_sys.o

time_sys.o: sys/time.c
	$(CC) $(CFLAGS) -c sys/time.c -o time_sys.o

abort.o: gen/abort.c
	$(CC) $(CFLAGS) -c gen/abort.c -o abort.o

exit.o: gen/exit.c
	$(CC) $(CFLAGS) -c gen/exit.c -o exit.o

sleep.o: gen/sleep.c
	$(CC) $(CFLAGS) -c gen/sleep.c -o sleep.o

popen.o: stdio/popen.c
	$(CC) $(CFLAGS) -c stdio/popen.c -o popen.o

%.o: sys/%.s
	$(CC) $(CFLAGS) -c $< -o $@

%.o: sys/%.c
	$(CC) $(CFLAGS) -c $< -o $@


.s.o:
	$(CC) $(CFLAGS) -c $<

.c.o:
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o *.elf *.a m_*.o $(ROOT)/etc/init $(ROOT)/etc/getty $(ROOT)/etc/update
	rm -f $(ROOT)/bin/login $(ROOT)/bin/sh $(ROOT)/bin/cat
	rm -f $(ROOT)/bin/echo $(ROOT)/bin/ls $(ROOT)/bin/pwd $(ROOT)/bin/sync
	rm -f $(ROOT)/bin/rev
	rm -f $(ROOT)/bin/arcv
	rm -f $(ROOT)/bin/yes $(ROOT)/bin/wc $(ROOT)/bin/basename $(ROOT)/bin/sum
	rm -f $(ROOT)/bin/tty $(ROOT)/bin/cmp $(ROOT)/bin/comm $(ROOT)/bin/cal
	rm -f $(ROOT)/bin/od $(ROOT)/bin/head $(ROOT)/bin/tail $(ROOT)/bin/grep $(ROOT)/bin/test
	rm -f $(ROOT)/bin/look $(ROOT)/bin/cp $(ROOT)/bin/rm $(ROOT)/bin/ln
	rm -f $(ROOT)/bin/mkdir $(ROOT)/bin/rmdir $(ROOT)/bin/mv
	rm -f $(ROOT)/bin/chmod $(ROOT)/bin/chown $(ROOT)/bin/chgrp
	rm -f $(ROOT)/bin/sleep $(ROOT)/bin/tee $(ROOT)/bin/touch $(ROOT)/bin/tr
	rm -f $(ROOT)/bin/uniq $(ROOT)/bin/du $(ROOT)/bin/date $(ROOT)/bin/kill
	rm -f $(ROOT)/bin/nice $(ROOT)/bin/mknod $(ROOT)/bin/who $(ROOT)/bin/mesg
	rm -f $(ROOT)/bin/time $(ROOT)/bin/split
	rm -f $(ROOT)/bin/checkeq $(ROOT)/bin/calendar $(ROOT)/bin/tsort
	rm -f $(ROOT)/bin/file
	rm -f $(ROOT)/bin/join
	rm -f $(ROOT)/bin/col
	rm -f $(ROOT)/bin/fgrep $(ROOT)/bin/egrep
	rm -f $(ROOT)/bin/su $(ROOT)/bin/newgrp
	rm -f $(ROOT)/bin/passwd
	rm -f $(ROOT)/bin/random
	rm -f $(ROOT)/bin/crypt $(ROOT)/usr/lib/makekey $(ROOT)/usr/lib/diffh
	rm -f $(ROOT)/bin/pr
	rm -f $(ROOT)/bin/dd
	rm -f $(ROOT)/bin/stty
	rm -f $(ROOT)/bin/tabs
	rm -f $(ROOT)/bin/diff
	rm -f $(ROOT)/bin/wall
	rm -f $(ROOT)/bin/write
	rm -f $(ROOT)/bin/df
	rm -f $(ROOT)/bin/clri
	rm -f $(ROOT)/bin/dcheck $(ROOT)/bin/icheck $(ROOT)/bin/ncheck
	rm -f $(ROOT)/bin/cb
	rm -f $(ROOT)/bin/sp
	rm -f $(ROOT)/bin/find
	rm -f $(ROOT)/bin/sort
	rm -f $(ROOT)/bin/spell $(ROOT)/bin/deroff
	rm -f $(ROOT)/bin/ed
	rm -f $(ROOT)/bin/sed
	rm -f $(ROOT)/bin/awk
	rm -f $(ROOT)/bin/1
	rm -f $(ROOT)/bin/true $(ROOT)/bin/false
	rm -f $(ROOT)/bin/dmesg
	rm -f $(ROOT)/bin/factor $(ROOT)/bin/primes
	rm -f $(ROOT)/bin/expr
	rm -f $(ROOT)/bin/iostat
	rm -f $(ROOT)/bin/dc
	rm -f $(ROOT)/bin/tar
	rm -f $(ROOT)/bin/tp
	rm -f $(ROOT)/bin/nohup
