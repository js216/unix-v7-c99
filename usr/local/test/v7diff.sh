#!/bin/sh
# Each repo file (tracked, or untracked and not ignored) is under an X
# entry, or has a "% file [v7file]" entry whose diff -U0 hunks turn
# v7file (default file; /dev/null if new) into it.
# Score: wc -c.  Usage: sh v7diff.sh [-u], from any directory of the repo.
X='
.gitignore
LICENSE
README
usr/local
'
: <<\EOF

% usr/src/cmd/cmd.mk /dev/null
@@ -0,0 +1,50 @@
+C = usr/src/cmd
+CMD_ETC = accton cron dmesg getty init mknod mount umount update wall
+CMD_USRLIB = atrun calendar diff3 diffh makekey
+CMD_DIRS = awk dc sed sh tar tp
+
+CMD_ONE := $(sort $(filter-out mkfs,$(basename $(notdir $(wildcard $C/*.[cy])))))
+CMD_BIN = $(filter-out $(CMD_ETC) $(CMD_USRLIB),$(CMD_ONE))
+CMD = $(CMD_BIN:%=bin/%) $(CMD_ETC:%=etc/%) $(CMD_USRLIB:%=usr/lib/%) \
+	$(CMD_DIRS:%=bin/%)
+
+AWK_OBJ = $(addprefix $C/awk/,awk.g.o awk.lx.o b.o main.o token.o tran.o \
+	lib.o run.o parse.o proctab.o)
+dirobj = $(patsubst %.c,%.o,$(wildcard $C/$1/*.c))
+CMD_OBJ = $(CMD_ONE:%=$C/%.o) $(AWK_OBJ) $(foreach d,dc sed sh tar tp,$(call dirobj,$d))
+GEN += $(patsubst %.y,%.c,$(wildcard $C/*.y)) $C/awk/awk.g.c $C/awk/awk.h \
+	$C/awk/awk.lx.c $C/awk/proc $C/awk/proctab.c
+
+$(CMD_OBJ): CPPFLAGS = -Iusr/include
+$(CMD_OBJ): $C/cmd.mk
+$C/bc.o $C/egrep.o $C/expr.o $(AWK_OBJ): CPPFLAGS += -DYYSTACK_USE_ALLOCA=1
+
+$(CMD_BIN:%=bin/%): bin/%: $(CRT) $C/%.o $(LIBM) $(LIBC) | bin
+	$(LINK)
+$(CMD_ETC:%=etc/%): etc/%: $(CRT) $C/%.o $(LIBC)
+	$(LINK)
+$(CMD_USRLIB:%=usr/lib/%): usr/lib/%: $(CRT) $C/%.o $(LIBC) | usr/lib
+	$(LINK)
+
+bin/awk: $(CRT) $(AWK_OBJ) $(LIBM) $(LIBC) | bin
+	$(LINK)
+bin/dc: $(CRT) $(call dirobj,dc) $(LIBC) | bin
+	$(LINK)
+bin/sed: $(CRT) $(call dirobj,sed) $(LIBC) | bin
+	$(LINK)
+bin/sh: $(CRT) $(call dirobj,sh) $(LIBC) | bin
+	$(LINK)
+bin/tar: $(CRT) $(call dirobj,tar) $(LIBC) | bin
+	$(LINK)
+bin/tp: $(CRT) $(call dirobj,tp) $(LIBC) | bin
+	$(LINK)
+
+$(AWK_OBJ): $C/awk/awk.h $C/awk/awk.def
+$C/awk/awk.g.c $C/awk/awk.h &: $C/awk/awk.g.y
+	$(call T,YACC)bison --defines=$C/awk/awk.h -o $C/awk/awk.g.c $<
+$C/awk/proc: $C/awk/proc.c $C/awk/token.c $C/awk/awk.h $C/awk/awk.def
+	$(call T,HOSTCC)$(HOSTCC) $(HOSTCFLAGS) -o $@ $C/awk/proc.c $C/awk/token.c
+$C/awk/proctab.c: $C/awk/proc
+	$(call T,GEN)$< >$@
+$C/awk/awk.lx.c: $C/awk/awk.lx.l
+	$(call T,LEX)$(LEX) -t $< | sed 's/void yynoreturn/void/;s/<string.h>/<stddef.h>/;/<stdlib.h>/d' >$@

% usr/src/games/games.mk /dev/null
@@ -0,0 +1,8 @@
+GAMES_OBJ := $(patsubst %.c,%.o,$(wildcard usr/src/games/*.c))
+GAMES = $(patsubst usr/src/games/%.o,usr/games/%,$(GAMES_OBJ))
+
+$(GAMES_OBJ): CPPFLAGS = -Iusr/include
+$(GAMES_OBJ): usr/src/games/games.mk
+
+$(GAMES): usr/games/%: $(CRT) usr/src/games/%.o $(LIBC) | usr/games
+	$(LINK)

% usr/src/libc/lib.mk /dev/null
@@ -0,0 +1,12 @@
+L = usr/src/libc
+LIBC = $L/libc.a
+CRT = $L/csu/crt0.o
+LIBC_OBJ := $(addsuffix .o,$(basename $(wildcard $L/*.[cs] $L/gen/*.[cs] \
+	$L/stdio/*.[cs] $L/sys/*.[cs])))
+
+$(LIBC_OBJ) $(CRT): CPPFLAGS = -Iusr/include
+$(LIBC_OBJ) $(CRT): $L/lib.mk
+
+$(LIBC): $(LIBC_OBJ)
+	$Qrm -f $@
+	$(call T,AR)$(AR) rc $@ $^

% usr/src/libm/lib.mk /dev/null
@@ -0,0 +1,9 @@
+LIBM = usr/src/libm/libm.a
+LIBM_OBJ := $(patsubst %.c,%.o,$(wildcard usr/src/libm/*.c))
+
+$(LIBM_OBJ): CPPFLAGS = -Iusr/include
+$(LIBM_OBJ): usr/src/libm/lib.mk
+
+$(LIBM): $(LIBM_OBJ)
+	$Qrm -f $@
+	$(call T,AR)$(AR) rc $@ $^

% usr/sys/sys.mk /dev/null
@@ -0,0 +1,32 @@
+S = usr/sys
+LIB1 = $S/sys/LIB1
+LIB2 = $S/dev/LIB2
+LIB1_OBJ := $(patsubst %.c,%.o,$(wildcard $S/sys/*.c))
+QEMU_DRV = $S/dev/pl011.o $S/dev/virtio_blk.o
+MP135_DRV = $S/dev/stm32usart.o $S/dev/stm32sd.o $S/dev/stm32ddr.o
+LIB2_OBJ := $(filter-out $(QEMU_DRV) $(MP135_DRV),$(patsubst %.c,%.o,$(wildcard $S/dev/*.c)))
+BOARDS = qemu mp135
+KERNELS = $(BOARDS:%=$S/conf/%/unix)
+SYS_OBJ = $(LIB1_OBJ) $(LIB2_OBJ) $(QEMU_DRV) $(MP135_DRV) $S/conf/low.o $S/conf/mch.o $(BOARDS:%=$S/conf/%/c.o)
+GEN += $(BOARDS:%=$S/conf/%/c.c) $(BOARDS:%=$S/conf/%/unix.ld) $S/conf/mkconf
+
+$(SYS_OBJ): $S/sys.mk
+$(LIB1): $(LIB1_OBJ)
+$(LIB2): $(LIB2_OBJ)
+$(LIB1) $(LIB2):
+	$Qrm -f $@
+	$(call T,AR)$(AR) rc $@ $^
+
+$S/conf/mkconf: $S/conf/mkconf.c
+	$(call T,HOSTCC)$(HOSTCC) $(HOSTCFLAGS) -o $@ $<
+
+$S/conf/%/c.c $S/conf/%/unix.ld: $S/conf/%conf $S/conf/mkconf
+	$Qmkdir -p $(@D)
+	$(call T,MKCONF)cd $(@D) && ../mkconf <../$*conf
+
+$S/conf/%/c.o: CPPFLAGS = -I$S/conf
+
+$S/conf/qemu/unix: $(QEMU_DRV)
+$S/conf/mp135/unix: $(MP135_DRV)
+$S/conf/%/unix: $S/conf/low.o $S/conf/mch.o $S/conf/%/c.o $(LIB1) $(LIB2) $S/conf/%/unix.ld
+	$(call T,LD)$(CC) -nostdlib -T $(@D)/unix.ld -o $@ $(filter %.o,$^) $(LIB1) $(LIB2)

% Makefile /dev/null
@@ -0,0 +1,84 @@
+CROSS_COMPILE ?= arm-none-eabi-
+CC = $(CROSS_COMPILE)gcc
+AS = $(CROSS_COMPILE)as
+AR = $(CROSS_COMPILE)ar
+HOSTCC = arm-linux-gnueabihf-gcc
+LEX = flex
+
+W = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wstrict-prototypes \
+	-Wold-style-definition -Wmissing-prototypes
+CFLAGS = $W \
+	-ffreestanding -nostdlib -mcpu=cortex-a7 -marm -Os -Wl,-N,-Ttext=0x10 \
+	-MMD -MP
+ASFLAGS = -mcpu=cortex-a7
+HOSTCFLAGS = $W -static \
+	-D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32
+
+T = $(if $V,,@printf '  %-7s %s\n' $1 $@;)
+Q = $(if $V,,@)
+COMPILE.c = $(call T,CC)$(CC) $(CFLAGS) $(CPPFLAGS) -c
+COMPILE.s = $(call T,AS)$(AS) $(ASFLAGS)
+LINK = $(call T,LD)$(CC) $(CFLAGS) -s -o $@ $(filter %.o %.a,$^) -lgcc
+
+all: boot/unix boot/rootfs.img
+
+include usr/sys/sys.mk
+include usr/src/libc/lib.mk
+include usr/src/libm/lib.mk
+include usr/src/cmd/cmd.mk
+include usr/src/games/games.mk
+
+all: $(KERNELS)
+
+.SECONDARY: $(GEN)
+
+OBJ = $(SYS_OBJ) $(LIBC_OBJ) $(CRT) $(LIBM_OBJ) $(CMD_OBJ) $(GAMES_OBJ)
+$(OBJ) $(GEN): Makefile
+
+%.c: %.y
+	$(call T,YACC)bison -o $@ $<
+
+boot/unix: usr/sys/conf/qemu/unix
+	$(call T,CP)cp $< $@
+
+qemu: boot/unix boot/rootfs.img
+	qemu-system-arm -machine virt -cpu cortex-a7 -nographic \
+	    -kernel boot/unix -drive if=none,file=boot/rootfs.img,format=raw,id=hd0 \
+	    -device virtio-blk-device,drive=hd0
+
+ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup \
+	etc/passwd etc/group etc/ttys etc/rc \
+	usr/dict/words usr/games/lib/fortunes usr/lib/units usr/lib/crontab \
+	usr/lib/lib.b
+
+ROOT = $(CMD) $(GAMES) $(ROOTFS_STATIC)
+
+DIRS = bin usr/lib usr/dict usr/games usr/games/lib
+
+boot/rootfs.img: boot/unix etc/mkfs boot/rootfs.proto $(ROOT)
+	$(call T,MKFS)V7_MKFS_TIME=284774400 etc/mkfs $@ boot/rootfs.proto
+	$Qtruncate -s $$(awk '/^(swplo|nswap) /{n+=$$2} END{print n*512}' \
+	    usr/sys/conf/qemuconf) $@
+
+etc/mkfs: usr/src/cmd/mkfs.c usr/include/sys/*.h Makefile
+	$(call T,HOSTCC)tmpinc="$(CURDIR)/boot/mkfs-include.$$$$"; \
+	    trap 'rm -rf "$$tmpinc"' EXIT; \
+	    mkdir -p "$$tmpinc"; \
+	    ln -s "$(CURDIR)/usr/include/sys" "$$tmpinc/sys"; \
+	    $(HOSTCC) $(HOSTCFLAGS) -I"$$tmpinc" -o $@ $<
+
+$(DIRS):
+	$Qmkdir -p $@
+
+$(filter-out etc/%,$(ROOTFS_STATIC)): %: usr/local/test/v7/% | $(DIRS)
+	$(call T,CP)cp -f $< $@
+
+clean:
+	rm -f $(OBJ) $(OBJ:.o=.d) $(GEN) $(CMD) $(GAMES)
+	rm -f $(LIBC) $(LIBM) $(LIB1) $(LIB2) $(KERNELS)
+	rm -f etc/mkfs boot/unix boot/rootfs.img
+
+.PHONY: all clean qemu
+.DELETE_ON_ERROR:
+
+-include $(patsubst %.c,%.d,$(wildcard $(OBJ:.o=.c)))

% boot/rootfs.proto /dev/null
@@ -0,0 +1,187 @@
+/dev/null
+10648 2048
+d--755 0 0
+	bin	d--755 0 0
+		1	---755 0 0 bin/1
+		[	---755 0 0 bin/test
+		ac	---755 0 0 bin/ac
+		at	---755 0 0 bin/at
+		arcv	---755 0 0 bin/arcv
+		awk	---755 0 0 bin/awk
+		basename	---755 0 0 bin/basename
+		bc	---755 0 0 bin/bc
+		cal	---755 0 0 bin/cal
+		cat	---755 0 0 bin/cat
+		cb	---755 0 0 bin/cb
+		checkeq	---755 0 0 bin/checkeq
+		chgrp	---755 0 0 bin/chgrp
+		chmod	---755 0 0 bin/chmod
+		chown	---755 0 0 bin/chown
+		clri	---755 0 0 bin/clri
+		cmp	---755 0 0 bin/cmp
+		col	---755 0 0 bin/col
+		comm	---755 0 0 bin/comm
+		cp	---755 0 0 bin/cp
+		crypt	---755 0 0 bin/crypt
+		date	---755 0 0 bin/date
+		dc	---755 0 0 bin/dc
+		dcheck	---755 0 0 bin/dcheck
+		dd	---755 0 0 bin/dd
+		df	---755 0 0 bin/df
+		diff	---755 0 0 bin/diff
+		deroff	---755 0 0 bin/deroff
+		du	---755 0 0 bin/du
+		dump	---755 0 0 bin/dump
+		dumpdir	---755 0 0 bin/dumpdir
+		echo	---755 0 0 bin/echo
+		ed	---755 0 0 bin/ed
+		egrep	---755 0 0 bin/egrep
+		expr	---755 0 0 bin/expr
+		fgrep	---755 0 0 bin/fgrep
+		file	---755 0 0 bin/file
+		factor	---755 0 0 bin/factor
+		find	---755 0 0 bin/find
+		false	---755 0 0 bin/false
+		grep	---755 0 0 bin/grep
+		graph	---755 0 0 bin/graph
+		icheck	---755 0 0 bin/icheck
+		iostat	---755 0 0 bin/iostat
+		join	---755 0 0 bin/join
+		kill	---755 0 0 bin/kill
+		ln	---755 0 0 bin/ln
+		login	-u-755 0 0 bin/login
+		look	---755 0 0 bin/look
+		ls	---755 0 0 bin/ls
+		mesg	---755 0 0 bin/mesg
+		mkdir	-u-755 0 0 bin/mkdir
+		mv	-u-755 0 0 bin/mv
+		ncheck	---755 0 0 bin/ncheck
+		newgrp	-u-755 0 0 bin/newgrp
+		nice	---755 0 0 bin/nice
+		nohup	---755 0 0 bin/nohup
+		od	---755 0 0 bin/od
+		osh	---755 0 0 bin/osh
+		passwd	-u-755 0 0 bin/passwd
+		pr	---755 0 0 bin/pr
+		primes	---755 0 0 bin/primes
+		prof	---755 0 0 bin/prof
+		ps	---755 0 0 bin/ps
+		pstat	---755 0 0 bin/pstat
+		ptx	---755 0 0 bin/ptx
+		pwd	---755 0 0 bin/pwd
+		quot	---755 0 0 bin/quot
+		random	---755 0 0 bin/random
+		restor	---755 0 0 bin/restor
+		rev	---755 0 0 bin/rev
+		rm	---755 0 0 bin/rm
+		rmdir	-u-755 0 0 bin/rmdir
+		sa	---755 0 0 bin/sa
+		sed	---755 0 0 bin/sed
+		sh	---755 0 0 bin/sh
+		sleep	---755 0 0 bin/sleep
+		sort	---755 0 0 bin/sort
+		sp	---755 0 0 bin/sp
+		spline	---755 0 0 bin/spline
+		split	---755 0 0 bin/split
+		stty	---755 0 0 bin/stty
+		su	-u-755 0 0 bin/su
+		sum	---755 0 0 bin/sum
+		sync	---755 0 0 bin/sync
+		tabs	---755 0 0 bin/tabs
+		tail	---755 0 0 bin/tail
+		tar	---755 0 0 bin/tar
+		tc	---755 0 0 bin/tc
+		tee	---755 0 0 bin/tee
+		test	---755 0 0 bin/test
+		time	---755 0 0 bin/time
+		tk	---755 0 0 bin/tk
+		touch	---755 0 0 bin/touch
+		tp	---755 0 0 bin/tp
+		tr	---755 0 0 bin/tr
+		true	---755 0 0 bin/true
+		tsort	---755 0 0 bin/tsort
+		tty	---755 0 0 bin/tty
+		uniq	---755 0 0 bin/uniq
+		units	---755 0 0 bin/units
+		vpr	---755 0 0 bin/vpr
+		wc	---755 0 0 bin/wc
+		who	---755 0 0 bin/who
+		write	---755 0 0 bin/write
+		yes	---755 0 0 bin/yes
+		$
+	dev	d--755 0 0
+		console	c--644 0 0 0 0
+		mem	c--644 0 0 8 0
+		kmem	c--640 0 0 8 1
+		null	c--666 0 0 8 2
+		root	b--644 0 0 0 0
+		rrk0	c--644 0 0 9 0
+		swap	b--644 0 0 0 0
+		tty	c--666 0 0 17 0
+		$
+	etc	d--755 0 0
+		accton	---755 0 0 etc/accton
+		cron	---755 0 0 etc/cron
+		ddate	---644 0 0 /dev/null
+		getty	---755 0 0 etc/getty
+		init	---755 0 0 etc/init
+		passwd	---644 0 0 etc/passwd
+		group	---644 0 0 etc/group
+		rc	---755 0 0 etc/rc
+		ttys	---644 0 0 etc/ttys
+		update	---755 0 0 etc/update
+		dmesg	---755 0 0 etc/dmesg
+		mknod	---755 0 0 etc/mknod
+		mount	---755 0 0 etc/mount
+		umount	---755 0 0 etc/umount
+		wall	---755 0 0 etc/wall
+		$
+	tmp	d--777 0 0
+		$
+	usr	d--755 0 0
+		adm	d--755 0 0
+			messages	---644 1 1 /dev/null
+			msgbuf	---644 1 1 /dev/null
+			wtmp	---644 0 0 /dev/null
+			$
+		dict	d--755 0 0
+			words	---644 0 0 usr/dict/words
+			$
+		dmr	d--755 7 3
+			$
+		games	d--755 0 0
+			arithmetic	---755 0 0 usr/games/arithmetic
+			backgammon	---755 0 0 usr/games/backgammon
+			fish	---755 0 0 usr/games/fish
+			fortune	---755 0 0 usr/games/fortune
+			hangman	---755 0 0 usr/games/hangman
+			lib	d--755 0 0
+				fortunes	---644 0 0 usr/games/lib/fortunes
+				$
+			quiz	---755 0 0 usr/games/quiz
+			wump	---755 0 0 usr/games/wump
+			$
+		lib	d--755 0 0
+			crontab	---644 0 0 usr/lib/crontab
+			diffh	---755 0 0 usr/lib/diffh
+			lib.b	---644 0 0 usr/lib/lib.b
+			makekey	---755 0 0 usr/lib/makekey
+			units	---644 0 0 usr/lib/units
+			calendar	---755 0 0 usr/lib/calendar
+			diff3	---755 0 0 usr/lib/diff3
+			atrun	-u-755 0 0 usr/lib/atrun
+			uucp	d--755 4 4
+				$
+			$
+		spool	d--755 0 0
+			at	d--777 0 0
+				lasttimedone	---666 0 0 /dev/null
+				past	d--777 0 0
+					$
+				$
+			$
+		sys	d--755 2 2
+			$
+		$
+	unix	---644 0 0 boot/unix
+$

% etc/group

% etc/passwd

% etc/rc
@@ -7 +6,0 @@
-/etc/mount /dev/rp3 /usr

% etc/ttys

% usr/include/a.out.h
@@ -33,0 +34 @@
+int	nlist(char *name, struct nlist *list);

% usr/include/ar.h

% usr/include/ctype.h

% usr/include/dumprestor.h

% usr/include/errno.h
@@ -40,0 +41 @@
+extern int errno;

% usr/include/execargs.h
@@ -1 +1 @@
-char **execargs = (char**)(-2);
+char **execargs = (char**)(0x100000-4);

% usr/include/grp.h
@@ -6,0 +7,2 @@
+struct	group	*getgrent(void), *getgrgid(int gid), *getgrnam(char *name);
+void	setgrent(void), endgrent(void);

% usr/include/math.h
@@ -1,7 +1,13 @@
-extern double fabs(), floor(), ceil(), fmod(), ldexp();
-extern double sqrt(), hypot(), atof();
-extern double sin(), cos(), tan(), asin(), acos(), atan(), atan2();
-extern double exp(), log(), log10(), pow();
-extern double sinh(), cosh(), tanh();
-extern double gamma();
-extern double j0(), j1(), jn(), y0(), y1(), yn();
+extern double fabs(double arg), floor(double d), ceil(double d);
+extern double fmod(double x, double y), ldexp(double value, int n);
+extern double sqrt(double arg), hypot(double a, double b), atof(char *p);
+extern double sin(double arg), cos(double arg), tan(double arg);
+extern double asin(double arg), acos(double arg), atan(double arg);
+extern double atan2(double arg1, double arg2);
+extern double exp(double arg), log(double arg), log10(double arg);
+extern double pow(double arg1, double arg2);
+extern double sinh(double arg), cosh(double arg), tanh(double arg);
+extern double gamma(double arg);
+extern double j0(double arg), j1(double arg), jn(int n, double x);
+extern double y0(double arg), y1(double arg), yn(int n, double x);
+extern double modf(double value, double *iptr), frexp(double value, int *eptr);
@@ -9,2 +15,2 @@
-#define HUGE	1.701411733192644270e38
-#define LOGHUGE 39
+#define HUGE	1.797693134862315708e308
+#define LOGHUGE 308

% usr/include/pwd.h
@@ -11,0 +12,2 @@
+struct	passwd	*getpwent(void), *getpwuid(int uid), *getpwnam(char *name);
+void	setpwent(void), endpwent(void);

% usr/include/setjmp.h
@@ -1 +1,2 @@
-typedef int jmp_buf[3];
+typedef int jmp_buf[10];
+int	setjmp(jmp_buf env), longjmp(jmp_buf env, int val);

% usr/include/sgtty.h
@@ -116,0 +117 @@
+int	gtty(int fd, struct sgttyb *ap), stty(int fd, struct sgttyb *ap);

% usr/include/signal.h
@@ -1 +1 @@
-#define NSIG 17
+#define NSIG 32
@@ -19,3 +19,3 @@
-int	(*signal())();
-#define	SIG_DFL	(int (*)())0
-#define	SIG_IGN	(int (*)())1
+void	(*signal(int sig, void (*func)(int sig)))(int sig);
+#define	SIG_DFL	(void (*)(int))0
+#define	SIG_IGN	(void (*)(int))1

% usr/include/stdio.h
@@ -37,5 +37,63 @@
-FILE	*fopen();
-FILE	*freopen();
-FILE	*fdopen();
-long	ftell();
-char	*fgets();
+FILE	*fopen(char *file, char *mode);
+FILE	*freopen(char *file, char *mode, FILE *iop);
+FILE	*fdopen(int fd, char *mode);
+long	ftell(FILE *iop);
+char	*fgets(char *s, int n, FILE *iop);
+FILE	*popen(char *cmd, char *mode), *_findiop(void);
+FILE	*_endopen(char *file, char *mode, FILE *iop);
+int	read(int fd, char *buf, int n), write(int fd, char *buf, int n);
+int	open(char *name, int mode), close(int fd), creat(char *name, int mode);
+int	unlink(char *name), link(char *name1, char *name2);
+int	access(char *name, int mode), chdir(char *dir), chroot(char *dir);
+int	chmod(char *name, int mode), chown(char *name, int owner, int group);
+int	mknod(char *name, int mode, int addr), utime(char *file, long *timep);
+int	fork(void), wait(int *status), execv(char *name, char **argv);
+int	execve(char *name, char **argv, char **envp);
+int	execvp(char *name, char **argv), dup(int fd), dup2(int fd, int fd2);
+int	pipe(int *fd), getuid(void), getgid(void);
+int	setuid(int uid), setgid(int gid), getpid(void), umask(int mask);
+int	sync(void), kill(int pid, int sig), alarm(unsigned sec), pause(void);
+int	nice(int incr), ioctl(int fd, int req, void *argp), stime(long *tp);
+int	mount(char *spec, char *dir, int ro), umount(char *spec);
+int	dysize(int y), fclose(FILE *iop), fseek(FILE *iop, long off, int ptr);
+int	fgetc(FILE *iop), fputc(int c, FILE *iop), getw(FILE *iop);
+int	pclose(FILE *iop), getpw(int uid, char *buf);
+int	fread(char *ptr, unsigned size, unsigned count, FILE *iop);
+int	fwrite(char *ptr, unsigned size, unsigned count, FILE *iop);
+int	puts(char *s), fputs(char *s, FILE *iop), ungetc(int c, FILE *iop);
+int	fflush(FILE *iop), _filbuf(FILE *iop), _flsbuf(int c, FILE *iop);
+int	system(char *s), isatty(int fd), ttyslot(void), strlen(char *s);
+int	strcmp(char *s1, char *s2), strncmp(char *s1, char *s2, int n);
+int	atoi(char *p), rand(void);
+int	printf(char *fmt, ...), fprintf(FILE *iop, char *fmt, ...);
+int	scanf(char *fmt, ...), fscanf(FILE *iop, char *fmt, ...);
+int	sscanf(char *str, char *fmt, ...);
+int	execl(char *name, char *arg0, ...), execlp(char *name, char *arg0, ...);
+char	*sprintf(char *str, char *fmt, ...);
+void	exit(int status), _exit(int status), abort(void), _cleanup(void);
+long	lseek(int fd, long off, int ptr), time(long *tloc), tell(int fd);
+long	atol(char *p);
+void	sleep(unsigned n), putw(int i, FILE *iop);
+double	atof(char *p);
+struct	tm *localtime(long *tim), *gmtime(long *tim);
+char	*ctime(long *t), *asctime(struct tm *t), *gets(char *s);
+char	*mktemp(char *as), *getenv(char *name), *getlogin(void);
+char	*getpass(char *prompt), *ttyname(int fd), *crypt(char *pw, char *salt);
+char	*strncat(char *s1, char *s2, int n), *strcpy(char *s1, char *s2);
+char	*strcat(char *s1, char *s2), *strncpy(char *s1, char *s2, int n);
+char	*index(char *sp, char c), *rindex(char *sp, char c);
+char	*malloc(unsigned n), *realloc(char *p, unsigned n);
+char	*calloc(unsigned num, unsigned size), *sbrk(int incr);
+char	*ecvt(double arg, int ndigits, int *decpt, int *sign);
+char	*fcvt(double arg, int ndigits, int *decpt, int *sign);
+char	*gcvt(double number, int ndigit, char *buf);
+char	*timezone(int zone, int dst);
+void	rewind(FILE *iop), setbuf(FILE *iop, char *buf), clearerr(FILE *iop);
+void	perror(char *s), srand(unsigned x), free(char *p);
+void	qsort(char *a, unsigned n, int es, int (*fc)(char *p1, char *p2));
+void	swab(char *from, char *to, int n);
+void	cfree(char *p, unsigned num, unsigned size);
+void	setkey(char *key), encrypt(char *block, int edflag);
+void	ltol3(char *cp, long *lp, int n), l3tol(long *lp, char *cp, int n);
+void	_strout(char *s, int count, int adjust, FILE *iop, int fillch);
+extern char **environ;

% usr/include/sys/acct.h

% usr/include/sys/dir.h

% usr/include/sys/fblk.h

% usr/include/sys/filsys.h

% usr/include/sys/ino.h

% usr/include/sys/inode.h
@@ -29 +29 @@
-	char	i_count;	/* reference count */
+	short	i_count;	/* reference count */
@@ -41 +41 @@
-		};
+		} u_reg;
@@ -45 +45 @@
-		};
+		} u_dev;
@@ -46,0 +47,3 @@
+#define	i_addr	u_reg.i_addr
+#define	i_lastr	u_reg.i_lastr
+#define	i_rdev	u_dev.i_rdev
@@ -51 +54 @@
-struct inode *mpxip;		/* mpx virtual inode */
+extern struct inode *mpxip;		/* mpx virtual inode */

% usr/include/sys/param.h
@@ -48 +48 @@
-#define	NSIG	17
+#define	NSIG	32
@@ -50 +50 @@
- * No more than 16 signals (1-16) because they are
+ * No more than 31 signals (1-31) because they are
@@ -83,2 +83,3 @@
-#define	USIZE	16		/* size of user block (*64) */
-#define	UBASE	0140000		/* abs. addr of user block */
+#define	USIZE	128		/* size of user block (*64) */
+#define	UBASE	0x4F000000U	/* abs. addr of user block */
+#ifndef NULL
@@ -85,0 +87 @@
+#endif
@@ -94 +96 @@
-#define	CBSIZE	14		/* number of chars in a clist block */
+#define	CBSIZE	12		/* number of chars in a clist block */
@@ -131 +133 @@
-typedef	unsigned int	ino_t;
+typedef	unsigned short	ino_t;
@@ -133 +135 @@
-typedef	int		label_t[6];	/* regs 2-7 */
+typedef	int		label_t[10];	/* regs 4-11, sp, lr */
@@ -144,0 +147,2 @@
+
+extern unsigned kernbase, corebase, coretop, pguser, gicdbase, giccbase;

% usr/include/sys/stat.h
@@ -28,0 +29 @@
+int	stat(char *name, struct stat *buf), fstat(int fd, struct stat *buf);

% usr/include/sys/timeb.h
@@ -9,0 +10 @@
+int	ftime(struct timeb *tp);

% usr/include/sys/times.h
@@ -9,0 +10 @@
+int	times(struct tms *buf);

% usr/include/sys/types.h
@@ -3 +3 @@
-typedef	unsigned int	ino_t;     	/* i-node number */
+typedef	unsigned short	ino_t;     	/* i-node number */
@@ -5 +5 @@
-typedef	int        	label_t[6]; 	/* program status */
+typedef	int        	label_t[10]; 	/* program status */

% usr/include/time.h

% usr/include/tp_defs.h

% usr/include/utmp.h

% usr/src/cmd/ac.c
@@ -35,2 +35,5 @@
-main(argc, argv) 
-char **argv;
+void	update(struct tbuf *tp, int f), upall(int f), print(void), loop(void);
+int	among(int i);
+void	pdate(void), newday(void);
+int
+main(int argc, char **argv)
@@ -39 +42 @@
-	register i;
+	register int i;
@@ -92 +95,2 @@
-loop()
+void
+loop(void)
@@ -94 +98 @@
-	register i;
+	register int i;
@@ -137 +141,2 @@
-print()
+void
+print(void)
@@ -160 +165,2 @@
-upall(f)
+void
+upall(int f)
@@ -168,2 +174,2 @@
-update(tp, f)
-struct tbuf *tp;
+void
+update(struct tbuf *tp, int f)
@@ -203 +209,2 @@
-among(i)
+int
+among(int i)
@@ -205 +212 @@
-	register j, k;
+	register int j, k;
@@ -223 +230,2 @@
-newday()
+void
+newday(void)
@@ -227 +234,0 @@
-	struct tm *localtime();
@@ -240 +247,2 @@
-pdate()
+void
+pdate(void)
@@ -243 +250,0 @@
-	char *ctime();

% usr/src/cmd/accton.c
@@ -1,2 +1,3 @@
-main(argc, argv)
-char **argv;
+#include <stdio.h>
+int
+main(int argc, char **argv)
@@ -4 +5,2 @@
-	extern errno;
+	extern int errno;
+	int acct(char *file);

% usr/src/cmd/arcv.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -17 +18 @@
-	unsigned siz;
+	unsigned short siz;
@@ -21 +22 @@
-char	*mktemp();
+void	conv(char *fil);
@@ -29,2 +30,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -32 +33 @@
-	register i;
+	register int i;
@@ -42,2 +43,2 @@
-conv(fil)
-char *fil;
+void
+conv(char *fil)
@@ -60 +61 @@
-	read(f, (char *)&b.magic, sizeof(b.magic));
+	read(f, (char *)&b.magic, 2);
@@ -79 +80 @@
-	nh.ar_date = oh.odate;
+	nh.ar_date = (unsigned long)oh.odate<<16 | (oh.odate>>16 & 0177777);

% usr/src/cmd/at.c
@@ -10,0 +11 @@
+#define	utime	at_utime
@@ -54,3 +55,2 @@
-char	**environ;
-char	*prefix();
-FILE	*popen();
+extern char	**environ;
+char	*prefix(char *begin, char *full);
@@ -58,2 +58,4 @@
-main(argc, argv)
-char **argv;
+void makeutime(char *pp), filename(char *dir, int y, int d, int t), onintr(int sig);
+int makeuday(int argc, char **argv);
+int
+main(int argc, char **argv)
@@ -61,2 +63 @@
-	extern onintr();
-	register c;
+	register int c;
@@ -118,2 +119,2 @@
-makeutime(pp)
-char *pp; 
+void
+makeutime(char *pp)
@@ -121 +122 @@
-	register val;
+	register int val;
@@ -127 +128 @@
-	while(isdigit(*p)) {
+	while(isdigit(*p&0377)) {
@@ -138,2 +139,2 @@
-			if (isdigit(*p)) {
-				if (isdigit(p[1])) {
+			if (isdigit(*p&0377)) {
+				if (isdigit(p[1]&0377)) {
@@ -146,0 +148 @@
+			break;
@@ -201,2 +203,2 @@
-makeuday(argc,argv)
-char **argv;
+int
+makeuday(int argc, char **argv)
@@ -211 +213 @@
-	struct tm *detail, *localtime();
+	struct tm *detail;
@@ -273,2 +275 @@
-prefix(begin, full)
-char *begin, *full;
+prefix(char *begin, char *full)
@@ -277 +278 @@
-	while (c = *begin++) {
+	while ((c = *begin++)) {
@@ -288,2 +289,2 @@
-filename(dir, y, d, t)
-char *dir;
+void
+filename(char *dir, int y, int d, int t)
@@ -291 +292 @@
-	register i;
+	register int i;
@@ -301 +302,2 @@
-onintr()
+void
+onintr(int sig)
@@ -302,0 +305 @@
+	(void)sig;

% usr/src/cmd/atrun.c
@@ -16,0 +17 @@
+void	makenowtime(void), updatetime(int t), run(char *file);
@@ -18,2 +19,2 @@
-main(argc, argv)
-char **argv;
+int
+main(void)
@@ -52 +53,2 @@
-makenowtime()
+void
+makenowtime(void)
@@ -55 +56,0 @@
-	struct tm *localtime();
@@ -65 +66,2 @@
-updatetime(t)
+void
+updatetime(int t)
@@ -77,2 +79,2 @@
-run(file)
-char *file;
+void
+run(char *file)
@@ -81 +83 @@
-	register pid, i;
+	register int pid, i;
@@ -96 +98 @@
-	if (pid = fork()) {
+	if ((pid = fork())) {

% usr/src/cmd/awk/awk.def
@@ -2 +2 @@
-#define yfree free
+#define yfree(p) free((char *)(p))
@@ -34 +34,2 @@
-cell	*setsymtab(), *lookup(), **makesymtab();
+cell	*setsymtab(char *n, char *s, awkfloat f, unsigned t, cell **tab);
+cell	*lookup(char *s, cell **tab), **makesymtab(void), *fieldadr(int n);
@@ -46,4 +47,3 @@
-awkfloat setfval(), getfval();
-char	*setsval(), *getsval();
-char	*tostring(), *tokname(), *malloc();
-double	log(), sqrt(), exp(), atof();
+awkfloat setfval(cell *vp, awkfloat f), getfval(cell *vp);
+char	*setsval(cell *vp, char *s), *getsval(cell *vp);
+char	*tostring(char *s), *tokname(int n), *cclenter(char *p);
@@ -105 +105 @@
-extern obj	(*proctab[])();
+extern obj	(*proctab[])(node **a, int n);
@@ -122,2 +122,22 @@
-obj	nullproc();
-obj	relop();
+obj	nullproc(node **a, int n);
+obj	relop(node **a, int n);
+obj	program(node **a, int n), array(node **a, int n), matchop(node **a, int n);
+obj	boolop(node **a, int n), indirect(node **a, int n), substr(node **a, int n);
+obj	sindex(node **a, int n), asprintf(node **a, int n), arith(node **a, int n);
+obj	incrdecr(node **a, int n), assign(node **a, int n), cat(node **a, int n);
+obj	pastat(node **a, int n), dopa2(node **a, int n), aprintf(node **a, int n);
+obj	split(node **a, int n), ifstat(node **a, int n), whilestat(node **a, int n);
+obj	forstat(node **a, int n), instat(node **a, int n), jump(node **a, int n);
+obj	fncn(node **a, int n), print(node **a, int n);
+node	*exptostat(node *a), *stat2(int a, node *b, node *c), *op1(int a, node *b);
+node	*stat3(int a, node *b, node *c, node *d), *op2(int a, node *b, node *c);
+node	*stat4(int a, node *b, node *c, node *d, node *e), *genjump(int a);
+node	*op3(int a, node *b, node *c, node *d), *valtonode(cell *a, int b);
+node	*pa2stat(node *a, node *b, node *c), *linkum(node *a, node *b);
+node	*genprint(void), *stat1(int a, node *b);
+struct	fa *makedfa(node *p);
+int	match(struct fa *pfa, char *p), member(char c, char *s), getrec(void);
+int	isnumber(char *s), yylex(void), run(void);
+void	error(int f, char *s, ...), yyerror(char *s), PUTS(char *s);
+void	fldbld(void), recbld(void), syminit(void), freesymtab(cell *ap);
+void	startreg(void), ptoken(int n);

% usr/src/cmd/awk/awk.g.y
@@ -29,0 +30 @@
+%left	NL SPRINTF SPLIT ',' '{' ELSE
@@ -33,0 +35,15 @@
+#define	N	(node *)
+#define	stat2(a, b, c)	(int)stat2(a, N(b), N(c))
+#define	stat3(a, b, c, d)	(int)stat3(a, N(b), N(c), N(d))
+#define	stat4(a, b, c, d, e)	(int)stat4(a, N(b), N(c), N(d), N(e))
+#define	op1(a, b)	(int)op1(a, N(b))
+#define	op2(a, b, c)	(int)op2(a, N(b), N(c))
+#define	op3(a, b, c, d)	(int)op3(a, N(b), N(c), N(d))
+#define	valtonode(a, b)	(int)valtonode((cell *)(a), b)
+#define	makedfa(p)	makedfa(N(p))
+#define	pa2stat(a, b, c)	(int)pa2stat(N(a), N(b), N(c))
+#define	linkum(a, b)	(int)linkum(N(a), N(b))
+#define	exptostat(a)	(int)exptostat(N(a))
+#define	genjump(a)	(int)genjump(a)
+#define	cclenter(p)	cclenter((char *)(p))
+#define	nullstat	(int)nullstat
@@ -41 +57 @@
-	  begin pa_stats end	{ if (errorflag==0) winner = stat3(PROGRAM, $1, $2, $3); }
+	  begin pa_stats end	{ if (errorflag==0) winner = (node *)stat3(PROGRAM, $1, $2, $3); }
@@ -104 +120 @@
-	  var
+	  var %prec ASGNOP
@@ -138,2 +154,2 @@
-	  term		{ PUTS("term"); }
-	| expr term	{ PUTS("expr term"); $$ = op2(CAT, $1, $2); }
+	  term %prec ASGNOP	{ PUTS("term"); }
+	| expr term %prec ASGNOP	{ PUTS("expr term"); $$ = op2(CAT, $1, $2); }
@@ -145 +161 @@
-	|
+	| %prec ASGNOP
@@ -149 +165 @@
-	  pattern	{ PUTS("pattern"); $$ = stat2(PASTAT, $1, genprint()); }
+	  pattern %prec ASGNOP	{ PUTS("pattern"); $$ = stat2(PASTAT, $1, genprint()); }
@@ -151 +167 @@
-	| pattern ',' pattern		{ PUTS("srch,srch"); $$ = pa2stat($1, $3, genprint()); }
+	| pattern ',' pattern %prec ASGNOP	{ PUTS("srch,srch"); $$ = pa2stat($1, $3, genprint()); }
@@ -159,2 +175,2 @@
-	|	{ PUTS("null pa_stat"); $$ = nullstat; }
-	| pa_stats pa_stat	{PUTS("pa_stats pa_stat"); $$ = linkum($1, $2); }
+	| %prec ASGNOP	{ PUTS("null pa_stat"); $$ = nullstat; }
+	| pa_stats pa_stat %prec ASGNOP	{PUTS("pa_stats pa_stat"); $$ = linkum($1, $2); }
@@ -173,3 +189,3 @@
-	  expr	{ PUTS("expr"); }
-	| pe_list	{ PUTS("pe_list"); }
-	|		{ PUTS("null print_list"); $$ = valtonode(lookup("$record", symtab), CFLD); }
+	  expr %prec ASGNOP	{ PUTS("expr"); }
+	| pe_list %prec ASGNOP	{ PUTS("pe_list"); }
+	| %prec ASGNOP	{ PUTS("null print_list"); $$ = valtonode(lookup("$record", symtab), CFLD); }
@@ -179,2 +195,2 @@
-	  expr ',' expr	{$$ = linkum($1, $3); }
-	| pe_list ',' expr	{$$ = linkum($1, $3); }
+	  expr ',' expr %prec ASGNOP	{$$ = linkum($1, $3); }
+	| pe_list ',' expr %prec ASGNOP	{$$ = linkum($1, $3); }
@@ -239 +255 @@
-	| if statement		{ PUTS("if stat"); $$ = stat3(IF, $1, $2, nullstat); }
+	| if statement %prec ASGNOP	{ PUTS("if stat"); $$ = stat3(IF, $1, $2, nullstat); }

% usr/src/cmd/awk/awk.lx.l
@@ -0,0 +1 @@
+%option noinput nounistd noyy_scan_string
@@ -8,0 +10,8 @@
+int	input(void);
+void	*memset(void *s, int c, unsigned int n);
+#define	YY_INPUT(buf,result,max_size) \
+do { \
+	int c = input(); \
+	if (c == 0) result = YY_NULL; \
+	else { buf[0] = c; result = 1; } \
+} while (0)
@@ -10 +19 @@
-int	lineno	1;
+int	lineno = 1;
@@ -16 +25 @@
-#define	CADD	cbuf[clen++]=yytext[0]; if(clen>=CBUFLEN-1) {yyerror("string too long", cbuf); BEGIN A;}
+#define	CADD	cbuf[clen++]=yytext[0]; if(clen>=CBUFLEN-1) {yyerror("string too long"); BEGIN A;}
@@ -28 +37 @@
-	switch (yybgin-yysvec-1) {	/* witchcraft */
+	switch (YY_START) {	/* witchcraft */
@@ -66 +75 @@
-				yylval = lookup("$record", symtab);
+				yylval = (int)lookup("$record", symtab);
@@ -69 +78 @@
-				yylval = fieldadr(atoi(yytext+1));
+				yylval = (int)fieldadr(atoi(yytext+1));
@@ -74 +83 @@
-<A>NF		{ mustfld=1; yylval = setsymtab(yytext, NULL, 0.0, NUM, symtab); RETURN(VAR); }
+<A>NF		{ mustfld=1; yylval = (int)setsymtab(yytext, NULL, 0.0, NUM, symtab); RETURN(VAR); }
@@ -76 +85 @@
-		yylval = setsymtab(yytext, NULL, atof(yytext), CON|NUM, symtab); RETURN(NUMBER); }
+		yylval = (int)setsymtab(yytext, NULL, atof(yytext), CON|NUM, symtab); RETURN(NUMBER); }
@@ -101 +110 @@
-<A>{A}{B}*	{ yylval = setsymtab(yytext, tostring(""), 0.0, STR, symtab); RETURN(VAR); }
+<A>{A}{B}*	{ yylval = (int)setsymtab(yytext, tostring(""), 0.0, STR, symtab); RETURN(VAR); }
@@ -131 +140 @@
-<str>\"		{ BEGIN A; cbuf[clen]=0; yylval = setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab); RETURN(STRING); }
+<str>\"		{ BEGIN A; cbuf[clen]=0; yylval = (int)setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab); RETURN(STRING); }
@@ -140 +149 @@
-<chc>"]"	{ BEGIN reg; cbuf[clen]=0; yylval = tostring(cbuf);
+<chc>"]"	{ BEGIN reg; cbuf[clen]=0; yylval = (int)tostring(cbuf);
@@ -148 +157,2 @@
-input()
+int
+input(void)
@@ -150 +160 @@
-	register c;
+	register int c;
@@ -153,4 +163,2 @@
-	if (yysptr > yysbuf)
-		c = U(*--yysptr);
-	else if (yyin == NULL)
-		c = *lexprog++;
+	if (lexprog != NULL)
+		c = *lexprog++&0377;
@@ -166 +174,2 @@
-startreg()
+void
+startreg(void)

% usr/src/cmd/awk/b.c
@@ -3,0 +4,2 @@
+int first(node *p), notin(int **array, int n, int *prev), *add(int n);
+void overflo(void), penter(node *p), follow(node *v), cfoll(node *v), freetr(node *p);
@@ -5,2 +7 @@
-extern node *op2();
-extern struct fa *cgotofn();
+extern struct fa *cgotofn(void);
@@ -41,2 +42 @@
-struct fa *makedfa(p)	/* returns dfa for tree pointed to by p */
-node *p;
+struct fa *makedfa(node *p)	/* returns dfa for tree pointed to by p */
@@ -60,2 +60,2 @@
-penter(p)	/* set up parent pointers and leaf indices */
-node *p;
+void
+penter(node *p)	/* set up parent pointers and leaf indices */
@@ -85,2 +85,2 @@
-freetr(p)	/* free parse tree and follow sets */
-node *p;
+void
+freetr(node *p)	/* free parse tree and follow sets */
@@ -108,2 +108 @@
-char *cclenter(p)
-register char *p;
+char *cclenter(register char *p)
@@ -111 +110 @@
-	register i, c;
+	register int i, c;
@@ -139 +138,2 @@
-overflo()
+void
+overflo(void)
@@ -144,2 +144,2 @@
-cfoll(v)		/* enter follow set of each leaf of vertex v into foll[leaf] */
-register node *v;
+void
+cfoll(register node *v)		/* enter follow set of each leaf of vertex v into foll[leaf] */
@@ -147 +147 @@
-	register i;
+	register int i;
@@ -149 +148,0 @@
-	int *add();
@@ -176,2 +175,3 @@
-first(p)			/* collects initially active leaves of p into setvec */
-register node *p;		/* returns 0 or 1 depending on whether p matches empty string */
+int
+first(register node *p)			/* collects initially active leaves of p into setvec */
+				/* returns 0 or 1 depending on whether p matches empty string */
@@ -179 +179 @@
-	register b;
+	register int b;
@@ -210,2 +210,2 @@
-follow(v)
-node *v;		/* collects leaves that can follow v into setvec */
+void
+follow(node *v)		/* collects leaves that can follow v into setvec */
@@ -245,2 +245,2 @@
-member(c, s)	/* is c in s? */
-register char c, *s;
+int
+member(register char c, register char *s)	/* is c in s? */
@@ -254,4 +254,3 @@
-notin(array, n, prev)		/* is setvec in array[0] thru array[n]? */
-int **array;
-int *prev; {
-	register i, j;
+int
+notin(int **array, int n, int *prev) {		/* is setvec in array[0] thru array[n]? */
+	register int i, j;
@@ -272 +271 @@
-int *add(n) {		/* remember setvec */
+int *add(int n) {		/* remember setvec */
@@ -274 +273 @@
-	register i;
+	register int i;
@@ -288 +287 @@
-struct fa *cgotofn()
+struct fa *cgotofn(void)
@@ -290 +289 @@
-	register i, k;
+	register int i, k;
@@ -300 +299 @@
-	int fatab[257];
+	int fatab[2*256+1];
@@ -308,3 +307,3 @@
-	char symbol[NCHARS];
-	char isyms[NCHARS];
-	char ssyms[NCHARS];
+	char symbol[256];
+	char isyms[256];
+	char ssyms[256];
@@ -314 +313 @@
-	for (i=0; i<NCHARS; i++)  isyms[i] = symbol[i] = 0;
+	for (i=0; i<256; i++)  isyms[i] = symbol[i] = 0;
@@ -328 +327 @@
-				k = (int) right(cp);
+				k = (int) right(cp) & 0377;
@@ -347,2 +346,2 @@
-						if (isyms[*p] != 1) {
-							isyms[*p] = 1;
+						if (isyms[*p&0377] != 1) {
+							isyms[*p&0377] = 1;
@@ -389 +388 @@
-					k = (int) right(cp);
+					k = (int) right(cp) & 0377;
@@ -408,2 +407,2 @@
-							if (isyms[*p] == 0 && symbol[*p] == 0) {
-								symbol[*p] = 1;
+							if (isyms[*p&0377] == 0 && symbol[*p&0377] == 0) {
+								symbol[*p&0377] = 1;
@@ -428 +427 @@
-			symbol[c] = 0;
+			symbol[c&0377] = 0;
@@ -435 +434 @@
-					if (k == CHAR && c == (int) right(cp)
+					if ((k == CHAR && c == (int) right(cp))
@@ -437,2 +436,2 @@
-					 || k == CCL && member(c, (char *) right(cp))
-					 || k == NCCL && !member(c, (char *) right(cp))) {
+					 || (k == CCL && member(c, (char *) right(cp)))
+					 || (k == NCCL && !member(c, (char *) right(cp)))) {
@@ -507,3 +506,2 @@
-match(pfa, p)
-register struct fa *pfa;
-register char *p;
+int
+match(register struct fa *pfa, register char *p)
@@ -511 +509 @@
-	register count;
+	register int count;

% usr/src/cmd/awk/lib.c
@@ -4,0 +5,2 @@
+#include <stdarg.h>
+void setclvar(char *s), _doprnt(char *fmt, va_list *argp, FILE *iop);
@@ -17 +19 @@
-#define	FINIT	{0, NULL, 0.0, FLD|STR}
+#define	FINIT	{0, NULL, 0.0, FLD|STR, 0}
@@ -19 +21 @@
-	{ "$record", record, 0.0, STR|FLD},
+	{ "$record", record, 0.0, STR|FLD, 0},
@@ -31 +33,2 @@
-getrec()
+int
+getrec(void)
@@ -36 +39 @@
-	register c, sep;
+	register int c, sep;
@@ -87,2 +90,2 @@
-setclvar(s)	/* set var=value from s */
-char *s;
+void
+setclvar(char *s)	/* set var=value from s */
@@ -101 +104,2 @@
-fldbld()
+void
+fldbld(void)
@@ -161 +165,2 @@
-recbld()
+void
+recbld(void)
@@ -171 +176 @@
-		while (*r++ = *p++)
+		while ((*r++ = *p++))
@@ -184 +189 @@
-cell *fieldadr(n)
+cell *fieldadr(int n)
@@ -193 +198,2 @@
-yyerror(s) char *s; {
+void
+yyerror(char *s) {
@@ -198 +204,3 @@
-error(f, s, a1, a2, a3, a4, a5, a6, a7) {
+void
+error(int f, char *s, ...) {
+	va_list a;
@@ -200 +208,3 @@
-	fprintf(stderr, s, a1, a2, a3, a4, a5, a6, a7);
+	va_start(a, s);
+	_doprnt(s, &a, stderr);
+	va_end(a);
@@ -208 +218,3 @@
-PUTS(s) char *s; {
+void
+PUTS(char *s) {
+	(void)s;
@@ -214,2 +226,2 @@
-isnumber(s)
-register char *s;
+int
+isnumber(register char *s)
@@ -217 +229 @@
-	register d1, d2;
+	register int d1, d2;
@@ -228 +240 @@
-	if (!isdigit(*s) && *s != '.')
+	if (!isdigit(*s&0377) && *s != '.')
@@ -230 +242 @@
-	if (isdigit(*s)) {
+	if (isdigit(*s&0377)) {
@@ -234 +246 @@
-		} while (isdigit(*s));
+		} while (isdigit(*s&0377));
@@ -242 +254 @@
-	if (isdigit(*s)) {
+	if (isdigit(*s&0377)) {
@@ -246 +258 @@
-		} while (isdigit(*s));
+		} while (isdigit(*s&0377));
@@ -248 +260 @@
-	if (!(d1 || point && d2))
+	if (!(d1 || (point && d2)))
@@ -254 +266 @@
-		if (!isdigit(*s))
+		if (!isdigit(*s&0377))
@@ -259 +271 @@
-		} while (isdigit(*s));
+		} while (isdigit(*s&0377));

% usr/src/cmd/awk/main.c
@@ -3,0 +4,2 @@
+int yywrap(void);
+void logit(int n, char *s[]), msgfiles(void);
@@ -10 +12 @@
-extern	errorflag;	/* non-zero if any syntax errors; set by yyerror */
+extern int	errorflag;	/* non-zero if any syntax errors; set by yyerror */
@@ -15 +17,2 @@
-main(argc, argv) int argc; char *argv[]; {
+int
+main(int argc, char *argv[]) {
@@ -71 +74 @@
-		write(ansfd, &errorflag, sizeof(errorflag));
+		write(ansfd, (char *)&errorflag, sizeof(errorflag));
@@ -77 +80,2 @@
-logit(n, s) char *s[];
+void
+logit(int n, char *s[])
@@ -83,2 +87,2 @@
-	time(tvec);
-	fprintf(f, "%-8s %s", getlogin(), ctime(tvec));
+	time((long *)tvec);
+	fprintf(f, "%-8s %s", getlogin(), ctime((long *)tvec));
@@ -102 +106,2 @@
-yywrap()
+int
+yywrap(void)
@@ -107 +112,2 @@
-msgfiles()
+void
+msgfiles(void)
@@ -134 +140 @@
-	xargv=s=svargv=malloc(n*sizeof(char *));
+	xargv=s=svargv=(char **)malloc(n*sizeof(char *));

% usr/src/cmd/awk/parse.c
@@ -4 +4 @@
-node *ALLOC(n)
+static node *ALLOC(int n)
@@ -11 +11 @@
-node *exptostat(a) node *a;
+node *exptostat(node *a)
@@ -17 +17 @@
-node *node0(a)
+static node *node0(int a)
@@ -24 +24 @@
-node *node1(a,b) node *b;
+static node *node1(int a, node *b)
@@ -32 +32 @@
-node *node2(a,b,c) node *b, *c;
+static node *node2(int a, node *b, node *c)
@@ -41 +41 @@
-node *node3(a,b,c,d) node *b, *c, *d;
+static node *node3(int a, node *b, node *c, node *d)
@@ -51 +51 @@
-node *node4(a,b,c,d,e) node *b, *c, *d, *e;
+static node *node4(int a, node *b, node *c, node *d, node *e)
@@ -62 +62 @@
-node *stat3(a,b,c,d) node *b, *c, *d;
+node *stat3(int a, node *b, node *c, node *d)
@@ -68 +68 @@
-node *op2(a,b,c) node *b, *c;
+node *op2(int a, node *b, node *c)
@@ -74 +74 @@
-node *op1(a,b) node *b;
+node *op1(int a, node *b)
@@ -80 +80 @@
-node *stat1(a,b) node *b;
+node *stat1(int a, node *b)
@@ -86 +86 @@
-node *op3(a,b,c,d) node *b, *c, *d;
+node *op3(int a, node *b, node *c, node *d)
@@ -92 +92 @@
-node *stat2(a,b,c) node *b, *c;
+node *stat2(int a, node *b, node *c)
@@ -98 +98 @@
-node *stat4(a,b,c,d,e) node *b, *c, *d, *e;
+node *stat4(int a, node *b, node *c, node *d, node *e)
@@ -104 +104 @@
-node *valtonode(a, b) cell *a;
+node *valtonode(cell *a, int b)
@@ -106 +106 @@
-	x = node0(a);
+	x = node0((int)a);
@@ -111 +111 @@
-node *genjump(a)
+node *genjump(int a)
@@ -117 +117 @@
-node *pa2stat(a,b,c) node *a, *b, *c;
+node *pa2stat(node *a, node *b, node *c)
@@ -123 +123 @@
-node *linkum(a,b) node *a, *b;
+node *linkum(node *a, node *b)
@@ -131 +131 @@
-node *genprint()
+node *genprint(void)

% usr/src/cmd/awk/proc.c
@@ -0,0 +1 @@
+#include "stdio.h"
@@ -2 +3 @@
-#define NULL 0
+#include "awk.def"
@@ -7 +8 @@
-} proc[] {
+} proc[] = {
@@ -56 +57 @@
-	{ 0, ""},
+	{ 0, "", ""},
@@ -61 +62,2 @@
-main()
+int
+main(void)
@@ -65,4 +66,0 @@
-	printf("obj nullproc();\n");
-	for(p=proc;p->token!=0;p++)
-		if(p==proc || strcmp(p->name, (p-1)->name))
-			printf("extern obj %s();\n",p->name);
@@ -71 +69 @@
-	printf("obj (*proctab[%d])() {\n", SIZE);
+	printf("obj (*proctab[%d])(node **a, int n) = {\n", SIZE);
@@ -76 +74 @@
-	printf("char *printname[%d] {\n", SIZE);
+	printf("char *printname[%d] = {\n", SIZE);

% usr/src/cmd/awk/run.c
@@ -5,0 +6,3 @@
+void tempfree(obj a), redirprint(char *s, int a, node *b);
+char *format(char *s, node *a);
+obj gettemp(void), arrayel(node *a, obj b);
@@ -13 +15,0 @@
-FILE *popen();
@@ -15 +17 @@
-extern obj execute(), nodetoobj(), fieldel(), dopa2();
+extern obj execute(node *u), nodetoobj(node *a);
@@ -25 +27,2 @@
-run()
+int
+run(void)
@@ -30 +33 @@
-obj execute(u) node *u;
+obj execute(node *u)
@@ -32 +35 @@
-	register obj (*proc)();
+	register obj (*proc)(node **a, int n);
@@ -35,0 +39 @@
+	(void)printname;
@@ -62 +66 @@
-obj program(a, n) node **a;
+obj program(node **a, int n)
@@ -64,0 +69 @@
+	(void)n;
@@ -94 +99 @@
-obj array(a,n) node **a;
+obj array(node **a, int n)
@@ -97 +102 @@
-	extern obj arrayel();
+	(void)n;
@@ -105 +110 @@
-obj arrayel(a,b) node *a; obj b;
+obj arrayel(node *a, obj b)
@@ -109 +113,0 @@
-	int i;
@@ -120 +124 @@
-	y.optr = setsymtab(s, tostring(""), 0.0, STR, x->sval);
+	y.optr = setsymtab(s, tostring(""), 0.0, STR, (cell **)x->sval);
@@ -126 +130 @@
-obj matchop(a,n) node **a;
+obj matchop(node **a, int n)
@@ -136,2 +140,2 @@
-	i = match(a[1], s);
-	if (n==MATCH && i==1 || n==NOTMATCH && i==0)
+	i = match((struct fa *)a[1], s);
+	if ((n==MATCH && i==1) || (n==NOTMATCH && i==0))
@@ -143 +147 @@
-obj boolop(a,n) node **a;
+obj boolop(node **a, int n)
@@ -153,0 +158 @@
+		/* fallthrough */
@@ -174 +179 @@
-obj relop(a,n) node **a;
+obj relop(node **a, int n)
@@ -192,0 +198 @@
+		/* fallthrough */
@@ -208 +214,2 @@
-tempfree(a) obj a;
+void
+tempfree(obj a)
@@ -215 +222 @@
-obj gettemp()
+obj gettemp(void)
@@ -232 +239 @@
-obj indirect(a,n) node **a;
+obj indirect(node **a, int n)
@@ -236 +243 @@
-	cell *fieldadr();
+	(void)n;
@@ -247 +254 @@
-obj substr(a, nnn) node **a;
+obj substr(node **a, int nnn)
@@ -251,0 +259 @@
+	(void)nnn;
@@ -286 +294 @@
-obj sindex(a, nnn) node **a;
+obj sindex(node **a, int nnn)
@@ -289,0 +298 @@
+	(void)nnn;
@@ -311 +320 @@
-char *format(s,a) char *s; node *a;
+char *format(char *s, node *a)
@@ -348 +357 @@
-		case 'o': case 'x':
+		case 'o': case 'x': case 'c':
@@ -381 +390 @@
-obj asprintf(a,n) node **a;
+obj asprintf(node **a, int n)
@@ -385,0 +395 @@
+	(void)n;
@@ -397 +407 @@
-obj arith(a,n) node **a;
+obj arith(node **a, int n)
@@ -399 +409 @@
-	awkfloat i,j;
+	awkfloat i,j=0;
@@ -413,0 +424 @@
+		/* fallthrough */
@@ -440 +451 @@
-obj incrdecr(a, n) node **a;
+obj incrdecr(node **a, int n)
@@ -461 +472 @@
-obj assign(a,n) node **a;
+obj assign(node **a, int n)
@@ -504 +515 @@
-obj cat(a,q) node **a;
+obj cat(node **a, int q)
@@ -508,0 +520 @@
+	(void)q;
@@ -526 +538 @@
-obj pastat(a,n) node **a;
+obj pastat(node **a, int n)
@@ -528,0 +541 @@
+	(void)n;
@@ -541 +554 @@
-obj dopa2(a,n) node **a;
+obj dopa2(node **a, int n)
@@ -562 +575 @@
-obj aprintf(a,n) node **a;
+obj aprintf(node **a, int n)
@@ -564,0 +578 @@
+	(void)n;
@@ -576 +590 @@
-obj split(a,nnn) node **a;
+obj split(node **a, int nnn)
@@ -583,0 +598 @@
+	(void)nnn;
@@ -612,2 +627,2 @@
-			  || sep == ' ' && (*p == '\t' || *p == '\n')
-			  || sep == '\t' && *p == '\n')
+			  || (sep == ' ' && (*p == '\t' || *p == '\n'))
+			  || (sep == '\t' && *p == '\n'))
@@ -618 +633 @@
-		setsymtab(num, tostring(temp), 0.0, STR, ap->sval);
+		setsymtab(num, tostring(temp), 0.0, STR, (cell **)ap->sval);
@@ -629 +644 @@
-obj ifstat(a,n) node **a;
+obj ifstat(node **a, int n)
@@ -631,0 +647 @@
+	(void)n;
@@ -645 +661 @@
-obj whilestat(a,n) node **a;
+obj whilestat(node **a, int n)
@@ -647,0 +664 @@
+	(void)n;
@@ -664 +681 @@
-obj forstat(a,n) node **a;
+obj forstat(node **a, int n)
@@ -666,0 +684 @@
+	(void)n;
@@ -687 +705 @@
-obj instat(a, n) node **a;
+obj instat(node **a, int n)
@@ -691,0 +710 @@
+	(void)n;
@@ -712,0 +732 @@
+	return(true);
@@ -715 +735 @@
-obj jump(a,n) node **a;
+obj jump(node **a, int n)
@@ -717,0 +738 @@
+	(void)a;
@@ -740 +761 @@
-obj fncn(a,n) node **a;
+obj fncn(node **a, int n)
@@ -743 +764 @@
-	awkfloat u;
+	awkfloat u=0;
@@ -744,0 +766 @@
+	(void)n;
@@ -766 +788 @@
-obj print(a,n) node **a;
+obj print(node **a, int n)
@@ -770,0 +793 @@
+	(void)n;
@@ -792 +815 @@
-obj nullproc() {}
+obj nullproc(node **a, int n) { (void)a; (void)n; return(true); }
@@ -794 +817 @@
-obj nodetoobj(a) node *a;
+obj nodetoobj(node *a)
@@ -805 +828,2 @@
-redirprint(s, a, b) char *s; node *b;
+void
+redirprint(char *s, int a, node *b)

% usr/src/cmd/awk/token.c
@@ -0,0 +1,2 @@
+#include "stdio.h"
+#include "awk.def"
@@ -6,76 +8,76 @@
-"FIRSTTOKEN", 257,
-"FINAL", 258,
-"FATAL", 259,
-"LT", 260,
-"LE", 261,
-"GT", 262,
-"GE", 263,
-"EQ", 264,
-"NE", 265,
-"MATCH", 266,
-"NOTMATCH", 267,
-"APPEND", 268,
-"ADD", 269,
-"MINUS", 270,
-"MULT", 271,
-"DIVIDE", 272,
-"MOD", 273,
-"UMINUS", 274,
-"ASSIGN", 275,
-"ADDEQ", 276,
-"SUBEQ", 277,
-"MULTEQ", 278,
-"DIVEQ", 279,
-"MODEQ", 280,
-"JUMP", 281,
-"XBEGIN", 282,
-"XEND", 283,
-"NL", 284,
-"PRINT", 285,
-"PRINTF", 286,
-"SPRINTF", 287,
-"SPLIT", 288,
-"IF", 289,
-"ELSE", 290,
-"WHILE", 291,
-"FOR", 292,
-"IN", 293,
-"NEXT", 294,
-"EXIT", 295,
-"BREAK", 296,
-"CONTINUE", 297,
-"PROGRAM", 298,
-"PASTAT", 299,
-"PASTAT2", 300,
-"ASGNOP", 301,
-"BOR", 302,
-"AND", 303,
-"NOT", 304,
-"NUMBER", 305,
-"VAR", 306,
-"ARRAY", 307,
-"FNCN", 308,
-"SUBSTR", 309,
-"LSUBSTR", 310,
-"INDEX", 311,
-"RELOP", 312,
-"MATCHOP", 313,
-"OR", 314,
-"STRING", 315,
-"DOT", 316,
-"CCL", 317,
-"NCCL", 318,
-"CHAR", 319,
-"CAT", 320,
-"STAR", 321,
-"PLUS", 322,
-"QUEST", 323,
-"POSTINCR", 324,
-"PREINCR", 325,
-"POSTDECR", 326,
-"PREDECR", 327,
-"INCR", 328,
-"DECR", 329,
-"FIELD", 330,
-"INDIRECT", 331,
-"LASTTOKEN", 332,
+{"FIRSTTOKEN", 258},
+{"FINAL", 259},
+{"FATAL", 260},
+{"LT", 261},
+{"LE", 262},
+{"GT", 263},
+{"GE", 264},
+{"EQ", 265},
+{"NE", 266},
+{"MATCH", 267},
+{"NOTMATCH", 268},
+{"APPEND", 269},
+{"ADD", 270},
+{"MINUS", 271},
+{"MULT", 272},
+{"DIVIDE", 273},
+{"MOD", 274},
+{"UMINUS", 275},
+{"ASSIGN", 276},
+{"ADDEQ", 277},
+{"SUBEQ", 278},
+{"MULTEQ", 279},
+{"DIVEQ", 280},
+{"MODEQ", 281},
+{"JUMP", 282},
+{"XBEGIN", 283},
+{"XEND", 284},
+{"NL", 285},
+{"PRINT", 286},
+{"PRINTF", 287},
+{"SPRINTF", 288},
+{"SPLIT", 289},
+{"IF", 290},
+{"ELSE", 291},
+{"WHILE", 292},
+{"FOR", 293},
+{"IN", 294},
+{"NEXT", 295},
+{"EXIT", 296},
+{"BREAK", 297},
+{"CONTINUE", 298},
+{"PROGRAM", 299},
+{"PASTAT", 300},
+{"PASTAT2", 301},
+{"ASGNOP", 302},
+{"BOR", 303},
+{"AND", 304},
+{"NOT", 305},
+{"NUMBER", 306},
+{"VAR", 307},
+{"ARRAY", 308},
+{"FNCN", 309},
+{"SUBSTR", 310},
+{"LSUBSTR", 311},
+{"INDEX", 312},
+{"RELOP", 313},
+{"MATCHOP", 314},
+{"OR", 315},
+{"STRING", 316},
+{"DOT", 317},
+{"CCL", 318},
+{"NCCL", 319},
+{"CHAR", 320},
+{"CAT", 321},
+{"STAR", 322},
+{"PLUS", 323},
+{"QUEST", 324},
+{"POSTINCR", 325},
+{"PREINCR", 326},
+{"POSTDECR", 327},
+{"PREDECR", 328},
+{"INCR", 329},
+{"DECR", 330},
+{"FIELD", 331},
+{"INDIRECT", 332},
+{"LASTTOKEN", 333},
@@ -83 +85,2 @@
-ptoken(n)
+void
+ptoken(int n)
@@ -87 +90 @@
-	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-257].tnm);
+	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-FIRSTTOKEN].tnm);
@@ -92 +95 @@
-char *tokname(n)
+char *tokname(int n)
@@ -96 +99 @@
-	return(tok[n-257].tnm);
+	return(tok[n-FIRSTTOKEN].tnm);

% usr/src/cmd/awk/tran.c
@@ -18,0 +19,2 @@
+int hash(char *s);
+void checkval(cell *vp);
@@ -20 +22,2 @@
-syminit()
+void
+syminit(void)
@@ -37 +40 @@
-cell **makesymtab()
+cell **makesymtab(void)
@@ -42 +45 @@
-	cp = (char *) malloc(MAXSYM * sizeof(cell *));
+	cp = (cell **) malloc(MAXSYM * sizeof(cell *));
@@ -50,2 +53,2 @@
-freesymtab(ap)	/* free symbol table */
-cell *ap;
+void
+freesymtab(cell *ap)	/* free symbol table */
@@ -63 +66 @@
-			free(cp);
+			free((char *)cp);
@@ -69,5 +72 @@
-cell *setsymtab(n, s, f, t, tab)
-char *n, *s;
-awkfloat f;
-unsigned t;
-cell **tab;
+cell *setsymtab(char *n, char *s, awkfloat f, unsigned t, cell **tab)
@@ -75 +74 @@
-	register h;
+	register int h;
@@ -77 +75,0 @@
-	cell *lookup();
@@ -100,2 +98,2 @@
-hash(s)	/* form hash value for string s */
-register char *s;
+int
+hash(register char *s)	/* form hash value for string s */
@@ -110,3 +108 @@
-cell *lookup(s, tab)	/* look for s in tab */
-register char *s;
-cell **tab;
+cell *lookup(register char *s, cell **tab)	/* look for s in tab */
@@ -122,3 +118 @@
-awkfloat setfval(vp, f)
-register cell *vp;
-awkfloat f;
+awkfloat setfval(register cell *vp, awkfloat f)
@@ -137,3 +131 @@
-char *setsval(vp, s)
-register cell *vp;
-char *s;
+char *setsval(register cell *vp, char *s)
@@ -155,2 +147 @@
-awkfloat getfval(vp)
-register cell *vp;
+awkfloat getfval(register cell *vp)
@@ -158 +148,0 @@
-	awkfloat atof();
@@ -181,2 +171 @@
-char *getsval(vp)
-register cell *vp;
+char *getsval(register cell *vp)
@@ -205,2 +194,2 @@
-checkval(vp)
-register cell *vp;
+void
+checkval(register cell *vp)
@@ -215,2 +204 @@
-char *tostring(s)
-register char *s;
+char *tostring(register char *s)

% usr/src/cmd/basename.c
@@ -3,2 +3,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -27 +27 @@
-	puts(p2, stdout);
+	puts(p2);

% usr/src/cmd/bc.y
@@ -2 +2,2 @@
-	int *getout();
+	void getout(void);
+#define YYSTYPE char *
@@ -19 +20,9 @@
-int in;
+#include <signal.h>
+#include <stdarg.h>
+#define bundle(...) (yyval = (bundle)(__VA_ARGS__))
+char *yyval;
+char *(bundle)(int i, ...);
+void output(char *p), conout(char *p, char *s), yyerror(char *s), pp(char *s), tp(char *s);
+char *getf(char *p), *geta(char *p);
+int yylex(void), cpeek(int c, int yes, int no), getch(void);
+FILE *in;
@@ -33 +42 @@
-int *pre, *post;
+char *pre, *post;
@@ -38 +47 @@
-		= output( $2 );
+		{ output( $2 ); }
@@ -40 +49 @@
-		={	bundle( 6,pre, $7, post ,"0",numb[lev],"Q");
+		{	bundle( 6,pre, $7, post ,"0",numb[lev],"Q");
@@ -52,2 +61,2 @@
-stat	:  e 
-		={ bundle(2, $1, "ps." ); }
+stat	:  ex 
+		{ bundle(2, $1, "ps." ); }
@@ -55 +64 @@
-		={ bundle(1, "" ); }
+		{ bundle(1, "" ); }
@@ -57 +66 @@
-		={ bundle(3,"[",$1,"]P");}
+		{ bundle(3,"[",$1,"]P");}
@@ -59 +68 @@
-		={ bundle(3, $3, "s", $1 ); }
+		{ bundle(3, $3, "s", $1 ); }
@@ -61 +70 @@
-		={ bundle(4, $6, $3, ":", geta($1)); }
+		{ bundle(4, $6, $3, ":", geta($1)); }
@@ -63 +72 @@
-		={ bundle(6, "l", $1, $3, $2, "s", $1 ); }
+		{ bundle(6, "l", $1, $3, $2, "s", $1 ); }
@@ -65 +74 @@
-		={ bundle(8,$3, ";", geta($1), $6, $5, $3, ":", geta($1));}
+		{ bundle(8,$3, ";", geta($1), $6, $5, $3, ":", geta($1));}
@@ -67 +76 @@
-		={ bundle(2, numb[lev-bstack[bindx-1]], "Q" ); }
+		{ bundle(2, numb[lev-bstack[bindx-1]], "Q" ); }
@@ -69 +78 @@
-		= bundle(4, $3, post, numb[lev], "Q" );
+		{ bundle(4, $3, post, numb[lev], "Q" ); }
@@ -71 +80 @@
-		= bundle(4, "0", post, numb[lev], "Q" );
+		{ bundle(4, "0", post, numb[lev], "Q" ); }
@@ -73 +82 @@
-		= bundle(4,"0",post,numb[lev],"Q");
+		{ bundle(4,"0",post,numb[lev],"Q"); }
@@ -75 +84 @@
-		= bundle(2, $3, "k");
+		{ bundle(2, $3, "k"); }
@@ -77 +86 @@
-		= bundle(4,"K",$3,$2,"k");
+		{ bundle(4,"K",$3,$2,"k"); }
@@ -79 +88 @@
-		= bundle(2,$3, "i");
+		{ bundle(2,$3, "i"); }
@@ -81 +90 @@
-		= bundle(4,"I",$3,$2,"i");
+		{ bundle(4,"I",$3,$2,"i"); }
@@ -83 +92 @@
-		= bundle(2,$3,"o");
+		{ bundle(2,$3,"o"); }
@@ -85 +94 @@
-		= bundle(4,"O",$3,$2,"o");
+		{ bundle(4,"O",$3,$2,"o"); }
@@ -87 +96 @@
-		={ $$ = $2; }
+		{ $$ = $2; }
@@ -89 +98 @@
-		={ bundle(1,"fY"); }
+		{ bundle(1,"fY"); }
@@ -91 +100 @@
-		={ bundle(1,"c"); }
+		{ bundle(1,"c"); }
@@ -93 +102 @@
-		={	conout( $7, $2 );
+		{	conout( $7, $2 );
@@ -97 +106 @@
-		={	bundle(3, $6, $4, $2 );
+		{	bundle(3, $6, $4, $2 );
@@ -102 +111 @@
-		={	bundle(5, $7, $5, "s.", $3, $2 );
+		{	bundle(5, $7, $5, "s.", $3, $2 );
@@ -107 +116 @@
-		={	bundle(3,$4,"S",$2); }
+		{	bundle(3,$4,"S",$2); }
@@ -111 +120 @@
-		={ $$ = "+"; }
+		{ $$ = "+"; }
@@ -113 +122 @@
-		={ $$ = "-"; }
+		{ $$ = "-"; }
@@ -115 +124 @@
-		={ $$ = "*"; }
+		{ $$ = "*"; }
@@ -117 +126 @@
-		={ $$ = "/"; }
+		{ $$ = "/"; }
@@ -119 +128 @@
-		={ $$ = "%%"; }
+		{ $$ = "%%"; }
@@ -121 +130 @@
-		={ $$ = "^"; }
+		{ $$ = "^"; }
@@ -125 +134 @@
-		={ $$ = $3; }
+		{ $$ = $3; }
@@ -129 +138 @@
-		={ --bindx; }
+		{ --bindx; }
@@ -134 +143 @@
-		={ bundle(2, $1, $3 ); }
+		{ bundle(2, $1, $3 ); }
@@ -138 +147 @@
-		={ln++;}
+		{ln++;}
@@ -143 +152 @@
-		= bundle(3, $1, $3, "=" );
+		{ bundle(3, $1, $3, "=" ); }
@@ -145 +154 @@
-		= bundle(3, $1, $3, ">" );
+		{ bundle(3, $1, $3, ">" ); }
@@ -147 +156 @@
-		= bundle(3, $1, $3, "<" );
+		{ bundle(3, $1, $3, "<" ); }
@@ -149 +158 @@
-		= bundle(3, $1, $3, "!=" );
+		{ bundle(3, $1, $3, "!=" ); }
@@ -151 +160 @@
-		= bundle(3, $1, $3, "!>" );
+		{ bundle(3, $1, $3, "!>" ); }
@@ -153 +162 @@
-		= bundle(3, $1, $3, "!<" );
+		{ bundle(3, $1, $3, "!<" ); }
@@ -155 +164 @@
-		= bundle(2, $1, " 0!=" );
+		{ bundle(2, $1, " 0!=" ); }
@@ -158,2 +167,2 @@
-e	:  e '+' e
-		= bundle(3, $1, $3, "+" );
+ex	:  e '+' e
+		{ bundle(3, $1, $3, "+" ); }
@@ -161 +170 @@
-		= bundle(3, $1, $3, "-" );
+		{ bundle(3, $1, $3, "-" ); }
@@ -163 +172 @@
-		= bundle(3, " 0", $2, "-" );
+		{ bundle(3, " 0", $2, "-" ); }
@@ -165 +174 @@
-		= bundle(3, $1, $3, "*" );
+		{ bundle(3, $1, $3, "*" ); }
@@ -167 +176 @@
-		= bundle(3, $1, $3, "/" );
+		{ bundle(3, $1, $3, "/" ); }
@@ -169 +178 @@
-		= bundle(3, $1, $3, "%%" );
+		{ bundle(3, $1, $3, "%%" ); }
@@ -171 +180 @@
-		= bundle(3, $1, $3, "^" );
+		{ bundle(3, $1, $3, "^" ); }
@@ -173 +182 @@
-		={ bundle(3,$3, ";", geta($1)); }
+		{ bundle(3,$3, ";", geta($1)); }
@@ -175 +184 @@
-		= bundle(4, "l", $1, "d1+s", $1 );
+		{ bundle(4, "l", $1, "d1+s", $1 ); }
@@ -177 +186 @@
-		= bundle(4, "l", $2, "1+ds", $2 );
+		{ bundle(4, "l", $2, "1+ds", $2 ); }
@@ -179 +188 @@
-		= bundle(4, "l", $2, "1-ds", $2 );
+		{ bundle(4, "l", $2, "1-ds", $2 ); }
@@ -181 +190 @@
-		= bundle(4, "l", $1, "d1-s", $1 );
+		{ bundle(4, "l", $1, "d1-s", $1 ); }
@@ -183 +192 @@
-		= bundle(7,$3,";",geta($1),"d1+",$3,":",geta($1));
+		{ bundle(7,$3,";",geta($1),"d1+",$3,":",geta($1)); }
@@ -185 +194 @@
-		= bundle(7,$4,";",geta($2),"1+d",$4,":",geta($2));
+		{ bundle(7,$4,";",geta($2),"1+d",$4,":",geta($2)); }
@@ -187 +196 @@
-		= bundle(7,$3,";",geta($1),"d1-",$3,":",geta($1));
+		{ bundle(7,$3,";",geta($1),"d1-",$3,":",geta($1)); }
@@ -189 +198 @@
-		= bundle(7,$4,";",geta($2),"1-d",$4,":",geta($2));
+		{ bundle(7,$4,";",geta($2),"1-d",$4,":",geta($2)); }
@@ -191 +200 @@
-		= bundle(1,"Kd1+k");
+		{ bundle(1,"Kd1+k"); }
@@ -193 +202 @@
-		= bundle(1,"K1+dk");
+		{ bundle(1,"K1+dk"); }
@@ -195 +204 @@
-		= bundle(1,"Kd1-k");
+		{ bundle(1,"Kd1-k"); }
@@ -197 +206 @@
-		= bundle(1,"K1-dk");
+		{ bundle(1,"K1-dk"); }
@@ -199 +208 @@
-		= bundle(1,"Id1+i");
+		{ bundle(1,"Id1+i"); }
@@ -201 +210 @@
-		= bundle(1,"I1+di");
+		{ bundle(1,"I1+di"); }
@@ -203 +212 @@
-		= bundle(1,"Id1-i");
+		{ bundle(1,"Id1-i"); }
@@ -205 +214 @@
-		= bundle(1,"I1-di");
+		{ bundle(1,"I1-di"); }
@@ -207 +216 @@
-		= bundle(1,"Od1+o");
+		{ bundle(1,"Od1+o"); }
@@ -209 +218 @@
-		= bundle(1,"O1+do");
+		{ bundle(1,"O1+do"); }
@@ -211 +220 @@
-		= bundle(1,"Od1-o");
+		{ bundle(1,"Od1-o"); }
@@ -213 +222 @@
-		= bundle(1,"O1-do");
+		{ bundle(1,"O1-do"); }
@@ -215 +224 @@
-		= bundle(4, $3, "l", getf($1), "x" );
+		{ bundle(4, $3, "l", getf($1), "x" ); }
@@ -217 +226 @@
-		= bundle(3, "l", getf($1), "x" );
+		{ bundle(3, "l", getf($1), "x" ); }
@@ -219 +228 @@
-		={ bundle(2, " ", $1 ); }
+		{ bundle(2, " ", $1 ); }
@@ -221 +230 @@
-		={ bundle(2, " .", $2 ); }
+		{ bundle(2, " .", $2 ); }
@@ -223 +232 @@
-		={ bundle(4, " ", $1, ".", $3 ); }
+		{ bundle(4, " ", $1, ".", $3 ); }
@@ -225 +234 @@
-		={ bundle(3, " ", $1, "." ); }
+		{ bundle(3, " ", $1, "." ); }
@@ -227 +236 @@
-		={ $$ = "l."; }
+		{ $$ = "l."; }
@@ -229,9 +238 @@
-		= { bundle(2, "l", $1 ); }
-	|  LETTER '=' e
-		={ bundle(3, $3, "ds", $1 ); }
-	|  LETTER EQOP e	%prec '='
-		={ bundle(6, "l", $1, $3, $2, "ds", $1 ); }
-	| LETTER '[' e ']' '=' e
-		= { bundle(5,$6,"d",$3,":",geta($1)); }
-	| LETTER '[' e ']' EQOP e
-		= { bundle(9,$3,";",geta($1),$6,$5,"d",$3,":",geta($1)); }
+		{ bundle(2, "l", $1 ); }
@@ -239 +240 @@
-		= bundle(2,$3,"Z");
+		{ bundle(2,$3,"Z"); }
@@ -241 +242 @@
-		= bundle(2,$3,"X");	/* must be before '(' e ')' */
+		{ bundle(2,$3,"X"); }	/* must be before '(' e ')' */
@@ -243 +244 @@
-		= { $$ = $2; }
+		{ $$ = $2; }
@@ -245 +246 @@
-		={ bundle(1, "?" ); }
+		{ bundle(1, "?" ); }
@@ -247 +248 @@
-		={ bundle(2, $3, "v" ); }
+		{ bundle(2, $3, "v" ); }
@@ -249 +250,18 @@
-		={ bundle(2,"L",$2); }
+		{ bundle(2,"L",$2); }
+	| SCALE
+		{ bundle(1,"K"); }
+	| BASE
+		{ bundle(1,"I"); }
+	| OBASE
+		{ bundle(1,"O"); }
+	;
+
+e	:  ex
+	|  LETTER '=' e
+		{ bundle(3, $3, "ds", $1 ); }
+	|  LETTER EQOP e	%prec '='
+		{ bundle(6, "l", $1, $3, $2, "ds", $1 ); }
+	| LETTER '[' e ']' '=' e
+		{ bundle(5,$6,"d",$3,":",geta($1)); }
+	| LETTER '[' e ']' EQOP e	%prec '='
+		{ bundle(9,$3,";",geta($1),$6,$5,"d",$3,":",geta($1)); }
@@ -251 +269 @@
-		= bundle(2,$3,"dk");
+		{ bundle(2,$3,"dk"); }
@@ -253 +271 @@
-		= bundle(4,"K",$3,$2,"dk");
+		{ bundle(4,"K",$3,$2,"dk"); }
@@ -255 +273 @@
-		= bundle(2,$3,"di");
+		{ bundle(2,$3,"di"); }
@@ -257 +275 @@
-		= bundle(4,"I",$3,$2,"di");
+		{ bundle(4,"I",$3,$2,"di"); }
@@ -259 +277 @@
-		= bundle(2,$3,"do");
+		{ bundle(2,$3,"do"); }
@@ -261,7 +279 @@
-		= bundle(4,"O",$3,$2,"do");
-	| SCALE
-		= bundle(1,"K");
-	| BASE
-		= bundle(1,"I");
-	| OBASE
-		= bundle(1,"O");
+		{ bundle(4,"O",$3,$2,"do"); }
@@ -272 +284 @@
-		= bundle(2, $1, $3 );
+		{ bundle(2, $1, $3 ); }
@@ -276 +288 @@
-		=bundle(2,"l",geta($1));
+		{ bundle(2,"l",geta($1)); }
@@ -280 +292 @@
-		={ *cp++ = '\0'; }
+		{ *cp++ = '\0'; }
@@ -284 +296 @@
-		={ $$ = cp; *cp++ = '_'; }
+		{ $$ = cp; *cp++ = '_'; }
@@ -286 +298 @@
-		={ $$ = cp; *cp++ = $1; }
+		{ $$ = cp; *cp++ = *$1; }
@@ -288 +300 @@
-		={ *cp++ = $2; }
+		{ *cp++ = *$2; }
@@ -292,2 +304,2 @@
-		={ $$ = cp; *cp++ = crs++; *cp++ = '\0';
-			if(crs == '[')crs=+3;
+		{ $$ = cp; *cp++ = crs++; *cp++ = '\0';
+			if(crs == '[')crs+=3;
@@ -302 +314 @@
-		={	$$ = getf($2);
+		{	$$ = getf($2);
@@ -312 +324 @@
-		={ pp( $1 ); }
+		{ pp( $1 ); }
@@ -314 +326 @@
-		={ pp( $3 ); }
+		{ pp( $3 ); }
@@ -318 +330 @@
-		={ tp($1); }
+		{ tp($1); }
@@ -320 +332 @@
-		={ tp($3); }
+		{ tp($3); }
@@ -324 +336 @@
-		={ $$ = geta($1); }
+		{ $$ = geta($1); }
@@ -347 +359 @@
-yylex(){
+int yylex(void){
@@ -390,2 +402,2 @@
-	if( c>= '0' && c <= '9' || c>= 'A' && c<= 'F' ){
-		yylval = c;
+	if( (c>= '0' && c <= '9') || (c>= 'A' && c<= 'F') ){
+		yylval = index("0123456789ABCDEF", c);
@@ -434 +446 @@
-cpeek( c, yes, no ){
+int cpeek( int c, int yes, int no ){
@@ -442 +454 @@
-getch(){
+int getch(void){
@@ -445 +457 @@
-	ch = (peekc < 0) ? getc(in) : peekc;
+	ch = (peekc < 0) ? in == NULL ? EOF : getc(in) : peekc;
@@ -454 +466 @@
-	fclose(in);
+	if(in != NULL)fclose(in);
@@ -460,0 +473 @@
+	goto loop;
@@ -463,2 +476,2 @@
-int b_space [ b_sp_max ];
-int * b_sp_nxt = { b_space };
+char *b_space [ b_sp_max ];
+char ** b_sp_nxt = { b_space };
@@ -467,2 +480,3 @@
-bundle(a){
-	int i, *p, *q;
+char *(bundle)(int i, ...){
+	va_list p;
+	char **q;
@@ -470,2 +484 @@
-	p = &a;
-	i = *p++;
+	va_start(p, i);
@@ -473 +486 @@
-	if( bdebug ) printf("bundle %d elements at %o\n",i,  q );
+	if( bdebug ) printf("bundle %d elements at %o\n",i, (unsigned)q );
@@ -476 +489 @@
-		* b_sp_nxt++ = *p++;
+		* b_sp_nxt++ = va_arg(p, char *);
@@ -477,0 +491 @@
+	va_end(p);
@@ -479,2 +493,2 @@
-	yyval = q;
-	return( q );
+	yyval = (char *)q;
+	return( yyval );
@@ -483,3 +497,3 @@
-routput(p) int *p; {
-	if( bdebug ) printf("routput(%o)\n", p );
-	if( p >= &b_space[0] && p < &b_space[b_sp_max]){
+static void routput(char *p){
+	if( bdebug ) printf("routput(%o)\n", (unsigned)p );
+	if( (char **)p >= &b_space[0] && (char **)p < &b_space[b_sp_max]){
@@ -487 +501,2 @@
-		while( *p != 0 ) routput( *p++ );
+		char **q = (char **)p;
+		while( *q != 0 ) routput( *q++ );
@@ -492 +507 @@
-output( p ) int *p; {
+void output( char *p ){
@@ -501 +516 @@
-conout( p, s ) int *p; char *s; {
+void conout( char *p, char *s ){
@@ -509 +524 @@
-yyerror( s ) char *s; {
+void yyerror( char *s ){
@@ -520 +535 @@
-pp( s ) char *s; {
+void pp( char *s ){
@@ -529 +544 @@
-tp( s ) char *s; { /* same as pp, but for temps */
+void tp( char *s ){ /* same as pp, but for temps */
@@ -536,2 +551,2 @@
-yyinit(argc,argv) int argc; char *argv[];{
-	signal( 2, (int(*)())1 );	/* ignore all interrupts */
+static void yyinit(int argc,char *argv[]){
+	signal( 2, SIG_IGN );	/* ignore all interrupts */
@@ -547 +562 @@
-int *getout(){
+void getout(void){
@@ -550 +565 @@
-	exit();
+	exit(0);
@@ -553,2 +568,2 @@
-int *
-getf(p) char *p;{
+char *
+getf(char *p){
@@ -557,2 +572,2 @@
-int *
-geta(p) char *p;{
+char *
+geta(char *p){
@@ -562,2 +577,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -572 +587 @@
-			exit();
+			exit(0);
@@ -577 +592 @@
-			exit();
+			exit(0);
@@ -589 +604 @@
-		exit();
+		exit(0);

% usr/src/cmd/cal.c
@@ -10,2 +10,5 @@
-main(argc, argv)
-char *argv[];
+#include <stdio.h>
+int number(char *str), jan1(int yr);
+void pstr(char *str, int n), cal(int m, int y, char *p, int w);
+int
+main(int argc, char *argv[])
@@ -13 +16 @@
-	register y, i, j;
+	register int y, i, j;
@@ -71,2 +74,2 @@
-number(str)
-char *str;
+int
+number(char *str)
@@ -74 +77 @@
-	register n, c;
+	register int n, c;
@@ -79 +82 @@
-	while(c = *s++) {
+	while((c = *s++)) {
@@ -87,2 +90,2 @@
-pstr(str, n)
-char *str;
+void
+pstr(char *str, int n)
@@ -90 +93 @@
-	register i;
+	register int i;
@@ -113,2 +116,2 @@
-cal(m, y, p, w)
-char *p;
+void
+cal(int m, int y, char *p, int w)
@@ -116 +119 @@
-	register d, i;
+	register int d, i;
@@ -173 +176,2 @@
-jan1(yr)
+int
+jan1(int yr)
@@ -175 +179 @@
-	register y, d;
+	register int y, d;

% usr/src/cmd/calendar.c
@@ -7,0 +8 @@
+#include <stdio.h>
@@ -25 +25,0 @@
-struct tm *localtime();
@@ -27,2 +27,2 @@
-tprint(t)
-long t;
+static void
+tprint(long t)
@@ -36 +36,2 @@
-main()
+int
+main(void)
@@ -44,0 +46 @@
+		/* FALLTHROUGH */
@@ -47,0 +50 @@
+		/* FALLTHROUGH */

% usr/src/cmd/cat.c
@@ -11,2 +11,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -16,2 +16,2 @@
-	register c;
-	int dev, ino = -1;
+	register int c;
+	int dev = -1, ino = -1;
@@ -42 +42 @@
-		if (fflg || (*++argv)[0]=='-' && (*argv)[1]=='\0')
+		if (fflg || ((*++argv)[0]=='-' && (*argv)[1]=='\0'))

% usr/src/cmd/cb.c
@@ -1,0 +2,4 @@
+#define	puts	cb_puts
+#define	gets	cb_gets
+int	getch(void), lookup(char *tab[]), getnl(void), gets(void);
+void	ptabs(void), comment(void), puts(void), gotelse(void);
@@ -39,2 +43,2 @@
-main(argc,argv) int argc;
-char argv[];
+int
+main(void)
@@ -155 +159 @@
-			if(iflev > 0)
+			if(iflev > 0) {
@@ -159,0 +164 @@
+			}
@@ -261 +266,2 @@
-ptabs(){
+void
+ptabs(void){
@@ -265 +271,2 @@
-getch(){
+int
+getch(void){
@@ -271 +278,2 @@
-puts(){
+void
+puts(void){
@@ -292,2 +300,2 @@
-lookup(tab)
-char *tab[];
+int
+lookup(char *tab[])
@@ -307 +315,2 @@
-gets(){
+int
+gets(void){
@@ -325 +334,2 @@
-gotelse(){
+void
+gotelse(void){
@@ -331 +341,2 @@
-getnl(){
+int
+getnl(void){
@@ -352 +363,2 @@
-comment(){
+void
+comment(void){

% usr/src/cmd/checkeq.c
@@ -8 +8,3 @@
-main(argc, argv) char **argv; {
+void check(FILE *f);
+int
+main(int argc, char **argv) {
@@ -33,2 +35,2 @@
-check(f)
-FILE	*f;
+void
+check(FILE *f)

% usr/src/cmd/chgrp.c
@@ -11 +11 @@
-struct	group	*gr,*getgrnam();
+struct	group	*gr;
@@ -14,0 +15 @@
+int	isnumber(char *s);
@@ -16,2 +17,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -19 +20 @@
-	register c;
+	register int c;
@@ -44,2 +45,2 @@
-isnumber(s)
-char *s;
+int
+isnumber(char *s)
@@ -47 +48 @@
-	register c;
+	register int c;
@@ -49 +50 @@
-	while(c = *s++)
+	while((c = *s++))

% usr/src/cmd/chmod.c
@@ -22,0 +23 @@
+int newmode(unsigned nm), abs(void), who(void), what(void), where(int om);
@@ -24,2 +25,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -27 +28 @@
-	register i;
+	register int i;
@@ -55,2 +56,2 @@
-newmode(nm)
-unsigned nm;
+int
+newmode(unsigned nm)
@@ -58 +59 @@
-	register o, m, b;
+	register int o, m, b;
@@ -65 +66 @@
-		while (o = what()) {
+		while ((o = what())) {
@@ -88 +89,2 @@
-abs()
+int
+abs(void)
@@ -90 +92 @@
-	register c, i;
+	register int c, i;
@@ -99 +101,2 @@
-who()
+int
+who(void)
@@ -101 +104 @@
-	register m;
+	register int m;
@@ -125 +128,2 @@
-what()
+int
+what(void)
@@ -136,2 +140,2 @@
-where(om)
-register om;
+int
+where(register int om)
@@ -139 +143 @@
-	register m;
+	register int m;

% usr/src/cmd/chown.c
@@ -11 +11 @@
-struct	passwd	*pwd,*getpwnam();
+struct	passwd	*pwd;
@@ -16,2 +16,3 @@
-main(argc, argv)
-char *argv[];
+int isnumber(char *s);
+int
+main(int argc, char *argv[])
@@ -19 +20 @@
-	register c;
+	register int c;
@@ -46,2 +47,2 @@
-isnumber(s)
-char *s;
+int
+isnumber(char *s)
@@ -49 +50 @@
-	register c;
+	register int c;
@@ -51 +52 @@
-	while(c = *s++)
+	while((c = *s++))

% usr/src/cmd/clri.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -17,2 +18,3 @@
-main(argc, argv)
-char *argv[];
+int isnumber(char *s);
+int
+main(int argc, char *argv[])
@@ -20 +22 @@
-	register i, f;
+	register int i, f;
@@ -22 +24 @@
-	int j, k;
+	unsigned j, k;
@@ -70,2 +72,2 @@
-isnumber(s)
-char *s;
+int
+isnumber(char *s)
@@ -73 +75 @@
-	register c;
+	register int c;
@@ -75 +77 @@
-	while(c = *s++)
+	while((c = *s++))

% usr/src/cmd/cmp.c
@@ -12 +12 @@
-long	otoi();
+long	otoi(char *s);
@@ -14,2 +14,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -17 +17 @@
-	register c1, c2;
+	register int c1, c2;
@@ -96 +96 @@
-	exit(2);
+	return(2);
@@ -108,2 +108 @@
-long otoi(s)
-char *s;
+long otoi(char *s)
@@ -118 +117 @@
-	while(isdigit(*s))
+	while(isdigit(*s&0377))

% usr/src/cmd/col.c
@@ -19 +19,2 @@
-char *strcpy();
+void outc(char c), emit(char *s, int lineno);
+void incr(void), decr(void);
@@ -21,2 +22,2 @@
-main (argc, argv)
-	int argc; char **argv;
+int
+main (int argc, char **argv)
@@ -162,2 +163,2 @@
-outc (c)
-	register char c;
+void
+outc (register char c)
@@ -208 +209,2 @@
-store (lno)
+static void
+store (int lno)
@@ -210 +211,0 @@
-	char *malloc();
@@ -223 +224,2 @@
-fetch(lno)
+static void
+fetch(int lno)
@@ -236,3 +238,2 @@
-emit (s, lineno)
-	char *s;
-	int lineno;
+void
+emit (char *s, int lineno)
@@ -294 +295,2 @@
-incr()
+void
+incr(void)
@@ -308 +310,2 @@
-decr()
+void
+decr(void)

% usr/src/cmd/comm.c
@@ -11,3 +11,5 @@
-FILE *openfil();
-main(argc,argv)
-char	*argv[];
+FILE *openfil(char *s);
+int rd(FILE *file,char *buf), compare(char *a,char *b);
+void wr(char *str,int n), copy(FILE *ibuf,char *lbuf,int n);
+int
+main(int argc,char *argv[])
@@ -93,3 +95,2 @@
-rd(file,buf)
-FILE *file;
-char *buf;
+int
+rd(FILE *file,char *buf)
@@ -112,2 +113,2 @@
-wr(str,n)
-	char	*str;
+void
+wr(char *str,int n)
@@ -132,3 +133,2 @@
-copy(ibuf,lbuf,n)
-FILE *ibuf;
-char *lbuf;
+void
+copy(FILE *ibuf,char *lbuf,int n)
@@ -143,2 +143,2 @@
-compare(a,b)
-	char	*a,*b;
+int
+compare(char *a,char *b)
@@ -155,2 +155 @@
-FILE *openfil(s)
-char *s;
+FILE *openfil(char *s)

% usr/src/cmd/cp.c
@@ -12,2 +12,3 @@
-main(argc, argv)
-char *argv[];
+int copy(char *from, char *to);
+int
+main(int argc, char *argv[])
@@ -15 +16 @@
-	register i, r;
+	register int i, r;
@@ -34,2 +35,2 @@
-copy(from, to)
-char *from, *to;
+int
+copy(char *from, char *to)
@@ -52 +53 @@
-		while(*bp++ = *p2++)
+		while((*bp++ = *p2++))
@@ -56 +57 @@
-		while(*bp = *p1++)
+		while((*bp = *p1++))
@@ -73 +74 @@
-	while(n = read(fold,  iobuf,  BSIZE)) {
+	while((n = read(fold,  iobuf,  BSIZE))) {

% usr/src/cmd/cron.c
@@ -18,3 +17,0 @@
-struct	tm *localtime();
-char	*malloc();
-char	*realloc();
@@ -23,0 +21,3 @@
+void	slp(void), ex(char *s), init(void);
+int	number(int c);
+char	*cmp(char *p, int v);
@@ -25 +25,2 @@
-main()
+int
+main(void)
@@ -28 +28,0 @@
-	char *cmp();
@@ -74,2 +74 @@
-cmp(p, v)
-char *p;
+cmp(char *p, int v)
@@ -110 +109,2 @@
-slp()
+void
+slp(void)
@@ -112 +112 @@
-	register i;
+	register int i;
@@ -121,2 +121,2 @@
-ex(s)
-char *s;
+void
+ex(char *s)
@@ -137 +137,2 @@
-init()
+void
+init(void)
@@ -139 +140 @@
-	register i, c;
+	register int i, c;
@@ -142,0 +144 @@
+	long pos;
@@ -154 +156,5 @@
-	if(cp > list+listsize-100) {
+	pos = ftell(stdin);
+	for(i = 2; (c = getchar()) != EOF && c != '\n'; i++)
+		;
+	fseek(stdin, pos, 0);
+	if(cp+i > list+listsize) {
@@ -156 +162 @@
-		listsize += LISTS;
+		listsize += i+LISTS;
@@ -239,2 +245,2 @@
-number(c)
-register c;
+int
+number(register int c)
@@ -242 +248 @@
-	register n = 0;
+	register int n = 0;

% usr/src/cmd/crypt.c
@@ -13 +12,0 @@
-char	*getpass();
@@ -15,2 +14,2 @@
-setup(pw)
-char *pw;
+static void
+setup(char *pw)
@@ -18 +17 @@
-	int ic, i, k, temp, pf[2];
+	int ic, i, k, temp, pf[2], pid;
@@ -21 +20 @@
-	long seed;
+	unsigned long seed;
@@ -29 +28 @@
-	if (fork()==0) {
+	if ((pid = fork())==0) {
@@ -39 +38,2 @@
-	wait((int *)NULL);
+	while ((i = wait((int *)NULL)) != pid && i != -1)
+		;
@@ -51 +51 @@
-		random = seed % 65521;
+		random = (long)seed % 65521;
@@ -68,2 +68,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -71 +71 @@
-	register i, n1, n2;
+	register int i, n1, n2;

% usr/src/cmd/date.c
@@ -9,0 +10 @@
+#include <stdio.h>
@@ -14 +15 @@
-char	*timezone();
+int	gtime(void), gp(int dfault);
@@ -33,4 +33,0 @@
-char	*ctime();
-char	*asctime();
-struct	tm *localtime();
-struct	tm *gmtime();
@@ -38,2 +35,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -94 +91,2 @@
-gtime()
+int
+gtime(void)
@@ -122,0 +121,2 @@
+	if(year < 70)
+		year += 100;
@@ -152 +152,2 @@
-gp(dfault)
+int
+gp(int dfault)

% usr/src/cmd/dc/dc.c
@@ -4,3 +4,12 @@
-main(argc,argv)
-int argc;
-char *argv[];
+void init(int argc, char *argv[]), commnds(void), unreadc(char c),
+    pushp(struct blk *p), sdump(char *s1, struct blk *hptr),
+    chsign(struct blk *p), binop(char c), release(struct blk *p),
+    print(struct blk *hptr), load(void), seekc(struct blk *hptr, int n),
+    salterwd(struct wblk *hptr, struct blk *n), putwd(struct blk *p, struct blk *c),
+    more(struct blk *hptr), garbage(char *s), ospace(char *s),
+    redef(struct blk *p), tenot(struct blk *p, int sc),
+    oneot(struct blk *p, int sc, char ch);
+int readc(void), subt(void), eqk(void), dscale(void), log2(long n),
+    command(void), cond(char c);
+int
+main(int argc, char *argv[])
@@ -11 +20,2 @@
-commnds(){
+void
+commnds(void){
@@ -62 +72 @@
-			sunputc(p);
+			(void)sunputc(p);
@@ -395 +405 @@
-				for(n = 0;n < PTRSZ-1;n++)sputc(q,0);
+				for(n = 0;n < (int)PTRSZ-1;n++)sputc(q,0);
@@ -488 +498 @@
-			salterwd(p,s);
+			salterwd((struct wblk *)p,s);
@@ -577,2 +587 @@
-div(ddivd,ddivr)
-struct blk *ddivd,*ddivr;
+div(struct blk *ddivd, struct blk *ddivr)
@@ -589,2 +598,3 @@
-		pushp(ddivr);
-		errorrt("divide by 0\n");
+		printf("divide by 0\n");
+		rem = salloc(0);
+		return(p);
@@ -697 +707,2 @@
-dscale(){
+int
+dscale(void){
@@ -727,2 +738 @@
-removr(p,n)
-struct blk *p;
+removr(struct blk *p, int n)
@@ -756,2 +766 @@
-sqrt(p)
-struct blk *p;
+sqrt(struct blk *p)
@@ -807,2 +816 @@
-exp(base,ex)
-struct blk *base,*ex;
+exp(struct blk *base, struct blk *ex)
@@ -861,3 +869,2 @@
-init(argc,argv)
-int argc;
-char *argv[];
+void
+init(int argc, char *argv[])
@@ -920 +927,3 @@
-onintr(){
+void
+onintr(int sig){
+	(void)sig;
@@ -930,2 +939,2 @@
-pushp(p)
-struct blk *p;
+void
+pushp(struct blk *p)
@@ -942 +951 @@
-pop(){
+pop(void){
@@ -950 +959 @@
-readin(){
+readin(void){
@@ -998,3 +1007 @@
-add0(p,ct)
-int ct;
-struct blk *p;
+add0(struct blk *p, int ct)
@@ -1023,2 +1030 @@
-mult(p,q)
-struct blk *p,*q;
+mult(struct blk *p, struct blk *q)
@@ -1078,2 +1084,2 @@
-chsign(p)
-struct blk *p;
+void
+chsign(struct blk *p)
@@ -1112 +1118,2 @@
-readc(){
+int
+readc(void){
@@ -1122 +1129 @@
-	if(readptr != &readptr[0]){
+	if(readptr != &readstk[0]){
@@ -1132,0 +1140 @@
+	return(0);
@@ -1134,2 +1142,2 @@
-unreadc(c)
-char c;
+void
+unreadc(char c)
@@ -1144,2 +1152,2 @@
-binop(c)
-char c;
+void
+binop(char c)
@@ -1147 +1155 @@
-	register struct blk *r;
+	register struct blk *r = 0;
@@ -1166,2 +1174,2 @@
-print(hptr)
-struct blk *hptr;
+void
+print(struct blk *hptr)
@@ -1192 +1200 @@
-	sunputc(p);
+	(void)sunputc(p);
@@ -1247,2 +1255 @@
-getdec(p,sc)
-struct blk *p;
+getdec(struct blk *p, int sc)
@@ -1278,2 +1285,2 @@
-tenot(p,sc)
-struct blk *p;
+void
+tenot(struct blk *p, int sc)
@@ -1327,3 +1334,2 @@
-oneot(p,sc,ch)
-struct blk *p;
-char ch;
+void
+oneot(struct blk *p, int sc, char ch)
@@ -1346,2 +1352,2 @@
-hexot(p,flg)
-struct blk *p;
+void
+hexot(struct blk *p, int flg)
@@ -1348,0 +1355 @@
+	(void)flg;
@@ -1365,2 +1372,2 @@
-bigot(p,flg)
-struct blk *p;
+void
+bigot(struct blk *p, int flg)
@@ -1409 +1416 @@
-			sunputc(strptr);
+			(void)sunputc(strptr);
@@ -1417,2 +1424 @@
-add(a1,a2)
-struct blk *a1,*a2;
+add(struct blk *a1, struct blk *a2)
@@ -1463 +1469,2 @@
-eqk(){
+int
+eqk(void){
@@ -1493,2 +1500 @@
-removc(p,n)
-struct blk *p;
+removc(struct blk *p, int n)
@@ -1515,2 +1521 @@
-scalint(p)
-struct blk *p;
+scalint(struct blk *p)
@@ -1524,2 +1529 @@
-scale(p,n)
-struct blk *p;
+scale(struct blk *p, int n)
@@ -1541 +1545,2 @@
-subt(){
+int
+subt(void){
@@ -1552 +1557,2 @@
-command(){
+int
+command(void){
@@ -1555 +1561,2 @@
-	register (*savint)(),pid,rpid;
+	register void (*savint)(int sig);
+	register int pid,rpid;
@@ -1581,2 +1588,2 @@
-cond(c)
-char c;
+int
+cond(char c)
@@ -1585 +1592 @@
-	register char cc;
+	register int cc;
@@ -1589 +1596 @@
-	sunputc(p);
+	(void)sunputc(p);
@@ -1615 +1622 @@
-		(cc >0) && (c == '>' || c == NL)){
+		((cc >0) && (c == '>' || c == NL))){
@@ -1622 +1629,2 @@
-load(){
+void
+load(void){
@@ -1655,2 +1663,2 @@
-log2(n)
-long n;
+int
+log2(long n)
@@ -1668,2 +1676 @@
-salloc(size)
-int size;
+salloc(int size)
@@ -1688 +1695 @@
-morehd(){
+morehd(void){
@@ -1713,3 +1720 @@
-copy(hptr,size)
-struct blk *hptr;
-int size;
+copy(struct blk *hptr, int size)
@@ -1741,3 +1746,2 @@
-sdump(s1,hptr)
-char *s1;
-struct blk *hptr;
+void
+sdump(char *s1, struct blk *hptr)
@@ -1751,2 +1755,2 @@
-seekc(hptr,n)
-struct blk *hptr;
+void
+seekc(struct blk *hptr, int n)
@@ -1775,3 +1779,2 @@
-salterwd(hptr,n)
-struct wblk *hptr;
-struct blk *n;
+void
+salterwd(struct wblk *hptr, struct blk *n)
@@ -1779 +1782 @@
-	if(hptr->rdw == hptr->lastw)more(hptr);
+	if(hptr->rdw == hptr->lastw)more((struct blk *)hptr);
@@ -1784,2 +1787,2 @@
-more(hptr)
-struct blk *hptr;
+void
+more(struct blk *hptr)
@@ -1806,2 +1809,2 @@
-ospace(s)
-char *s;
+void
+ospace(char *s)
@@ -1815,2 +1818,2 @@
-garbage(s)
-char *s;
+void
+garbage(char *s)
@@ -1817,0 +1821 @@
+	(void)s;
@@ -1861,2 +1865,2 @@
-redef(p)
-struct blk *p;
+void
+redef(struct blk *p)
@@ -1864 +1868 @@
-	register offset;
+	register int offset;
@@ -1884,2 +1888,2 @@
-release(p)
-register struct blk *p;
+void
+release(register struct blk *p)
@@ -1895,2 +1899 @@
-getwd(p)
-struct blk *p;
+getwd(struct blk *p)
@@ -1906,2 +1909,2 @@
-putwd(p, c)
-struct blk *p, *c;
+void
+putwd(struct blk *p, struct blk *c)
@@ -1918,2 +1921 @@
-lookwd(p)
-struct blk *p;
+lookwd(struct blk *p)
@@ -1929,3 +1931 @@
-nalloc(p,nbytes)
-register char *p;
-unsigned nbytes;
+nalloc(register char *p, unsigned nbytes)
@@ -1933 +1932,0 @@
-	char *malloc();

% usr/src/cmd/dc/dc.h
@@ -22 +22 @@
-#ifdef interdata
+#ifndef pdp11
@@ -29 +29 @@
-#ifndef interdata
+#ifdef pdp11
@@ -53,4 +53,4 @@
-struct	blk *getwd();
-struct	blk *lookwd();
-struct	blk *getdec();
-struct	blk *morehd();
+struct	blk *getwd(struct blk *p);
+struct	blk *lookwd(struct blk *p);
+struct	blk *getdec(struct blk *p, int sc);
+struct	blk *morehd(void);
@@ -78,8 +78,10 @@
-struct	blk *pop(),*readin(),*add0(),*mult();
-struct	blk *scalint();
-struct	blk *removc();
-struct	blk *add(),*div(),*removr();
-struct	blk *exp();
-struct	blk *sqrt();
-struct	blk *salloc(),*copy();
-struct	blk *scale();
+struct	blk *pop(void),*readin(void),*add0(struct blk *p, int ct),
+	*mult(struct blk *p, struct blk *q);
+struct	blk *scalint(struct blk *p);
+struct	blk *removc(struct blk *p, int n);
+struct	blk *add(struct blk *a1, struct blk *a2),
+	*div(struct blk *ddivd, struct blk *ddivr),*removr(struct blk *p, int n);
+struct	blk *exp(struct blk *base, struct blk *ex);
+struct	blk *sqrt(struct blk *p);
+struct	blk *salloc(int size),*copy(struct blk *hptr, int size);
+struct	blk *scale(struct blk *p, int n);
@@ -106,2 +108,2 @@
-int	(*outdit)();
-int	bigot(),hexot();
+void	(*outdit)(struct blk *p, int flg);
+void	bigot(struct blk *p, int flg),hexot(struct blk *p, int flg);
@@ -112,5 +114,2 @@
-int	(*signal())();
-int	onintr();
-char	*malloc();
-char	*nalloc();
-char	*realloc();
+void	onintr(int sig);
+char	*nalloc(char *p, unsigned nbytes);

% usr/src/cmd/dcheck.c
@@ -29,3 +29,3 @@
-daddr_t	bmap();
-long	atol();
-char	*malloc();
+daddr_t	bmap(int i);
+void	check(char *file), pass1(struct dinode *ip), pass2(struct dinode *ip);
+void	bread(daddr_t bno, char *buf, int cnt);
@@ -33,2 +33,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -36 +36 @@
-	register i;
+	register int i;
@@ -65,2 +65,2 @@
-check(file)
-char *file;
+void
+check(char *file)
@@ -68,2 +68,2 @@
-	register i;
-	register j;
+	register int i;
+	register int j;
@@ -91 +91 @@
-	for (i=0; i<=nfiles; i++)
+	for (i=0; i<=(int)nfiles; i++)
@@ -120,2 +120,2 @@
-pass1(ip)
-register struct dinode *ip;
+void
+pass1(register struct dinode *ip)
@@ -126 +126 @@
-	register i, j;
+	register int i, j;
@@ -142 +142 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -167,2 +167,2 @@
-pass2(ip)
-register struct dinode *ip;
+void
+pass2(register struct dinode *ip)
@@ -170 +170 @@
-	register i;
+	register int i;
@@ -187,3 +187,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+void
+bread(daddr_t bno, char *buf, int cnt)
@@ -191 +190 @@
-	register i;
+	register int i;
@@ -203 +202 @@
-bmap(i)
+bmap(int i)
@@ -210 +209 @@
-	if(i > NINDIR) {
+	if(i >= (int)NINDIR) {

% usr/src/cmd/dd.c
@@ -21 +21,3 @@
-char	*sbrk();
+void	flsh(void), null(int c), stats(void), term(int sig), cnull(int cc);
+void	ascii(int cc), ebcdic(int cc), ibm(int cc);
+int	match(char *s), number(int big);
@@ -143,8 +145,6 @@
-main(argc, argv)
-int	argc;
-char	**argv;
-{
-	int (*conv)();
-	register char *ip;
-	register c;
-	int ebcdic(), ibm(), ascii(), null(), cnull(), term();
+int
+main(int argc, char **argv)
+{
+	void (*conv)(int c);
+	register char *ip = 0;
+	register int c;
@@ -304 +304 @@
-				term();
+				term(0);
@@ -314 +314 @@
-			term();
+			term(0);
@@ -345 +345,2 @@
-flsh()
+void
+flsh(void)
@@ -347 +348 @@
-	register c;
+	register int c;
@@ -356 +357 @@
-			term();
+			term(0);
@@ -362,2 +363,2 @@
-match(s)
-char *s;
+int
+match(char *s)
@@ -380 +381,2 @@
-number(big)
+int
+number(int big)
@@ -397 +399 @@
-		n *= sizeof(int);
+		n *= 2;
@@ -407,0 +410 @@
+		/* fallthrough */
@@ -419 +422,2 @@
-cnull(cc)
+void
+cnull(int cc)
@@ -421 +425 @@
-	register c;
+	register int c;
@@ -431 +435,2 @@
-null(c)
+void
+null(int c)
@@ -442 +447,2 @@
-ascii(cc)
+void
+ascii(int cc)
@@ -444 +450 @@
-	register c;
+	register int c;
@@ -469 +475,2 @@
-ebcdic(cc)
+void
+ebcdic(int cc)
@@ -471 +478 @@
-	register c;
+	register int c;
@@ -498 +505,2 @@
-ibm(cc)
+void
+ibm(int cc)
@@ -500 +508 @@
-	register c;
+	register int c;
@@ -527 +535,2 @@
-term()
+void
+term(int sig)
@@ -528,0 +538 @@
+	(void)sig;
@@ -534 +544,2 @@
-stats()
+void
+stats(void)

% usr/src/cmd/deroff.c
@@ -33 +33 @@
-char chars[128];  /* SPECIAL, APOS, DIGIT, or LETTER */
+char chars[256];  /* SPECIAL, APOS, DIGIT, or LETTER */
@@ -51 +51,5 @@
-char *calloc();
+FILE *opn(char *p);
+char *copys(char *s);
+int skeqn(void), eof(void);
+void backsl(void), fatal(char *s, char *p), work(void), regline(int macline);
+void putmac(char *s), putwords(int macline), comline(void), macro(void), tbl(void), eqn(void);
@@ -55,3 +59,2 @@
-main(ac, av)
-int ac;
-char **av;
+int
+main(int ac, char **av)
@@ -62 +64,0 @@
-FILE *opn();
@@ -107 +109,2 @@
-skeqn()
+int
+skeqn(void)
@@ -112 +115 @@
-	else if(c == '"')
+	else if(c == '"') {
@@ -118,0 +122 @@
+	}
@@ -123,2 +127 @@
-FILE *opn(p)
-register char *p;
+FILE *opn(register char *p)
@@ -138 +141,2 @@
-eof()
+int
+eof(void)
@@ -158 +162,2 @@
-getfname()
+static void
+getfname(void)
@@ -164 +168,0 @@
-char *copys();
@@ -192,2 +196,2 @@
-fatal(s,p)
-char *s, *p;
+void
+fatal(char *s,char *p)
@@ -200 +204,2 @@
-work()
+void
+work(void)
@@ -215,2 +220,2 @@
-regline(macline)
-int macline;
+void
+regline(int macline)
@@ -242 +247 @@
-if(line[0] != '\0')
+if(line[0] != '\0') {
@@ -249,0 +255 @@
+}
@@ -254,2 +260,2 @@
-putmac(s)
-register char *s;
+void
+putmac(register char *s)
@@ -265 +271 @@
-	if(t>s+2 && chars[ s[0] ]==LETTER && chars[ s[1] ]==LETTER)
+	if(t>s+2 && chars[ s[0]&0377 ]==LETTER && chars[ s[1]&0377 ]==LETTER)
@@ -276,2 +282,2 @@
-putwords(macline)	/* break into words for -w option */
-int macline;
+void
+putwords(int macline)	/* break into words for -w option */
@@ -286 +292 @@
-	while( chars[*p1] < DIGIT)
+	while( chars[*p1&0377] < DIGIT)
@@ -289 +295 @@
-	for(p = p1 ; (i=chars[*p]) != SPECIAL ; ++p)
+	for(p = p1 ; (i=chars[*p&0377]) != SPECIAL ; ++p)
@@ -293 +299 @@
-	   || (macline && nlet>2 && chars[ p1[0] ]==LETTER && chars[ p1[1] ]==LETTER) )
+	   || (macline && nlet>2 && chars[ p1[0]&0377 ]==LETTER && chars[ p1[1]&0377 ]==LETTER) )
@@ -308 +314,2 @@
-comline()
+void
+comline(void)
@@ -363 +370,2 @@
-macro()
+void
+macro(void)
@@ -367 +375 @@
-	while(C!='.' || C!='.' || C=='.');	/* look for  .. */
+	while(C!='.' || C!='.' || C=='.');	look for  .. */
@@ -375 +383,2 @@
-tbl()
+void
+tbl(void)
@@ -382 +391,2 @@
-eqn()
+void
+eqn(void)
@@ -425 +435,2 @@
-backsl()	/* skip over a complete backslash construction */
+void
+backsl(void)	/* skip over a complete backslash construction */
@@ -448,0 +460 @@
+		/* fallthrough */
@@ -483,2 +495 @@
-char *copys(s)
-register char *s;
+char *copys(register char *s)
@@ -491 +502 @@
-while( *t++ = *s++ )
+while( (*t++ = *s++) )

% usr/src/cmd/df.c
@@ -9,2 +9 @@
-	"/dev/rp0",
-	"/dev/rp3",
+	"/dev/root",
@@ -18 +17,2 @@
-daddr_t	alloc();
+daddr_t	alloc(void);
+void	dfree(char *file), bread(daddr_t bno, char *buf, int cnt);
@@ -20,2 +20,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -35,2 +35,2 @@
-dfree(file)
-char *file;
+void
+dfree(char *file)
@@ -55 +55 @@
-alloc()
+alloc(void)
@@ -83,3 +83,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+void
+bread(daddr_t bno, char *buf, int cnt)
@@ -88 +87 @@
-	extern errno;
+	extern int errno;

% usr/src/cmd/diff.c
@@ -76 +75,0 @@
-FILE *fopen();
@@ -106 +105,5 @@
-char *mktemp();
+void noroom(void), unravel(int p), check(char **argv), output(char **argv);
+void change(int a,int b,int c,int d), range(int a,int b,char *separator);
+void fetch(long *f,int a,int b,FILE *lb,char *s), mesg(char *s,char *t);
+int stone(int *a,int n,int *b,int *c), newcand(int x,int y,int pred);
+int search(int *c, int k, int y), skipline(int f), readhash(FILE *f);
@@ -109 +112,2 @@
-done()
+static void
+done(int sig)
@@ -110,0 +115 @@
+	(void)sig;
@@ -115 +120 @@
-char *talloc(n)
+static char *talloc(int n)
@@ -117 +121,0 @@
-	extern char *malloc();
@@ -122,0 +127 @@
+	return(p);
@@ -125,2 +130 @@
-char *ralloc(p,n)	/*compacting reallocation */
-char *p;
+static char *ralloc(char *p,int n)	/*compacting reallocation */
@@ -129 +132,0 @@
-	char *realloc();
@@ -139 +142,2 @@
-noroom()
+void
+noroom(void)
@@ -142 +146 @@
-	done();
+	done(0);
@@ -145,2 +149,2 @@
-sort(a,n)	/*shellsort CACM #201*/
-struct line *a;
+static void
+sort(struct line *a,int n)	/*shellsort CACM #201*/
@@ -149 +153 @@
-	register int j,m;
+	register int j,m = 0;
@@ -163,2 +167,2 @@
-				   aim->value == ai[0].value &&
-				   aim->serial > ai[0].serial)
+				   (aim->value == ai[0].value &&
+				   aim->serial > ai[0].serial))
@@ -177,3 +181,2 @@
-unsort(f, l, b)
-struct line *f;
-int *b;
+static void
+unsort(struct line *f, int l, int *b)
@@ -191,2 +194,2 @@
-filename(pa1, pa2)
-char **pa1, **pa2;
+static void
+filename(char **pa1, char **pa2)
@@ -202 +205 @@
-		while(*b1++ = *a1++) ;
+		while((*b1++ = *a1++)) ;
@@ -205 +208 @@
-		while(*a1++ = *a2++)
+		while((*a1++ = *a2++))
@@ -217 +220 @@
-			done();
+			done(0);
@@ -225,2 +228,2 @@
-prepare(i, arg)
-char *arg;
+static void
+prepare(int i, char *arg)
@@ -229 +232 @@
-	register j,h;
+	register int j,h;
@@ -232 +235 @@
-		done();
+		done(0);
@@ -235 +238 @@
-	for(j=0; h=readhash(input[i]);) {
+	for(j=0; (h=readhash(input[i]));) {
@@ -244 +247,2 @@
-prune()
+static void
+prune(void)
@@ -246 +250 @@
-	register i,j;
+	register int i,j;
@@ -261,3 +265,2 @@
-equiv(a,n,b,m,c)
-struct line *a, *b;
-int *c;
+static void
+equiv(struct line *a,int n,struct line *b,int m,int *c)
@@ -289,2 +292,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -313 +316 @@
-				done();
+				done(0);
@@ -319 +322 @@
-		done();
+		done(0);
@@ -355 +358 @@
-	done();
+	done(0);
@@ -358,4 +361,2 @@
-stone(a,n,b,c)
-int *a;
-int *b;
-int *c;
+int
+stone(int *a,int n,int *b,int *c)
@@ -399 +400,2 @@
-newcand(x,y,pred)
+int
+newcand(int x,int y,int pred)
@@ -410,2 +412,2 @@
-search(c, k, y)
-int *c;
+int
+search(int *c, int k, int y)
@@ -431 +433,2 @@
-unravel(p)
+void
+unravel(int p)
@@ -448,2 +451,2 @@
-check(argv)
-char **argv;
+void
+check(char **argv)
@@ -454 +457 @@
-	char c,d;
+	int c,d;
@@ -512 +515,2 @@
-skipline(f)
+int
+skipline(int f)
@@ -514 +518 @@
-	register i;
+	register int i;
@@ -519,2 +523,2 @@
-output(argv)
-char **argv;
+void
+output(char **argv)
@@ -551 +555,2 @@
-change(a,b,c,d)
+void
+change(int a,int b,int c,int d)
@@ -572,2 +577,2 @@
-range(a,b,separator)
-char *separator;
+void
+range(int a,int b,char *separator)
@@ -581,4 +586,2 @@
-fetch(f,a,b,lb,s)
-long *f;
-FILE *lb;
-char *s;
+void
+fetch(long *f,int a,int b,FILE *lb,char *s)
@@ -602,2 +605,2 @@
-readhash(f)
-FILE *f;
+int
+readhash(FILE *f)
@@ -607,2 +610,2 @@
-	register space;
-	register t;
+	register int space;
+	register int t;
@@ -641,2 +644,2 @@
-mesg(s,t)
-char *s, *t;
+void
+mesg(char *s,char *t)

% usr/src/cmd/diff3.c
@@ -45,2 +45,10 @@
-main(argc,argv)
-char **argv;
+int readin(char *name, struct diff *dd), number(char **lc), digit(int c);
+int getchange(FILE *b), getline(FILE *b), skip(int i, int from, char *pr);
+int duplicate(struct range *r1, struct range *r2);
+int edit(struct diff *diff, int dup, int j);
+void merge(int m1, int m2), separate(char *s), prange(struct range *rold);
+void change(int i, struct range *rold, int dup), repos(int nchar);
+void keep(int i, struct range *rold, struct range *rnew);
+void trouble(void), edscript(int n);
+int
+main(int argc, char **argv)
@@ -48 +56 @@
-	register i,m,n;
+	register int i,m,n;
@@ -85,3 +93,2 @@
-readin(name,dd)
-char *name;
-struct diff *dd;
+int
+readin(char *name, struct diff *dd)
@@ -89 +96 @@
-	register i;
+	register int i;
@@ -128,2 +135,2 @@
-number(lc)
-char **lc;
+int
+number(char **lc)
@@ -131 +138 @@
-	register nn;
+	register int nn;
@@ -138 +145,2 @@
-digit(c)
+int
+digit(int c)
@@ -143,2 +151,2 @@
-getchange(b)
-FILE *b;
+int
+getchange(FILE *b)
@@ -152,2 +160,2 @@
-getline(b)
-FILE *b;
+int
+getline(FILE *b)
@@ -155,2 +163,2 @@
-	register i, c;
-	for(i=0;i<sizeof(line)-1;i++) {
+	register int i, c;
+	for(i=0;i<(int)sizeof(line)-1;i++) {
@@ -169 +177,2 @@
-merge(m1,m2)
+void
+merge(int m1, int m2)
@@ -187 +196 @@
-		if(!t2||t1&&d1->new.to < d2->new.from) {
+		if(!t2||(t1&&d1->new.to < d2->new.from)) {
@@ -199 +208 @@
-		if(!t1||t2&&d2->new.to < d1->new.from) {
+		if(!t1||(t2&&d2->new.to < d1->new.from)) {
@@ -268,2 +277,2 @@
-separate(s)
-char *s;
+void
+separate(char *s)
@@ -278,2 +287,2 @@
-change(i,rold,dup)
-struct range *rold;
+void
+change(int i, struct range *rold, int dup)
@@ -296,2 +305,2 @@
-prange(rold)
-struct range *rold;
+void
+prange(struct range *rold)
@@ -314,2 +323,2 @@
-keep(i,rold,rnew)
-struct range *rold, *rnew;
+void
+keep(int i, struct range *rold, struct range *rnew)
@@ -317 +326,2 @@
-	register delta;
+	register int delta;
+	(void)rold;
@@ -329,2 +339,2 @@
-skip(i,from,pr)
-char *pr;
+int
+skip(int i, int from, char *pr)
@@ -332 +342 @@
-	register j,n;
+	register int j,n;
@@ -347,2 +357,2 @@
-duplicate(r1,r2)
-struct range *r1, *r2;
+int
+duplicate(struct range *r1, struct range *r2)
@@ -350,2 +360,2 @@
-	register c,d;
-	register nchar;
+	register int c,d;
+	register int nchar;
@@ -367 +377 @@
-				return;
+				return(0);
@@ -375 +385,2 @@
-repos(nchar)
+void
+repos(int nchar)
@@ -377 +388 @@
-	register i;
+	register int i;
@@ -382 +393,2 @@
-trouble()
+void
+trouble(void)
@@ -390,2 +402,2 @@
-edit(diff,dup,j)
-struct diff *diff;
+int
+edit(struct diff *diff, int dup, int j)
@@ -406 +418,2 @@
-edscript(n)
+void
+edscript(int n)
@@ -408 +421 @@
-	register j,k;
+	register int j,k;

% usr/src/cmd/diffh.c
@@ -17,0 +18,4 @@
+int	hardsynch(void), easysynch(void), output(int a, int b), cmp(char *s, char *t);
+void	progerr(char *s), movstr(char *s, char *t), error(char *s, char *t);
+void	change(long a, int b, long c, int d, char *s), range(long a, int b);
+FILE	*dopen(char *f1, char *f2);
@@ -20,2 +24 @@
-char *getl(f,n)
-long n;
+static char *getl(int f, long n)
@@ -24,2 +27 @@
-	char *malloc();
-	register delta, nt;
+	register int delta, nt;
@@ -42 +44 @@
-		if(t==NULL)
+		if(t==NULL) {
@@ -46,0 +49 @@
+		}
@@ -55,2 +58,2 @@
-clrl(f,n)
-long n;
+static void
+clrl(int f, long n)
@@ -58 +61 @@
-	register i,j;
+	register int i,j;
@@ -66,2 +69,2 @@
-movstr(s,t)
-register char *s, *t;
+void
+movstr(register char *s, register char *t)
@@ -69 +72 @@
-	while(*t++= *s++)
+	while((*t++= *s++))
@@ -73,2 +76,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -77 +79,0 @@
-	FILE *dopen();
@@ -103 +105 @@
-		return;
+		return(0);
@@ -111 +113,2 @@
-easysynch()
+int
+easysynch(void)
@@ -114 +117 @@
-	register k,m;
+	register int k,m;
@@ -143 +146,2 @@
-output(a,b)
+int
+output(int a, int b)
@@ -145 +149 @@
-	register i;
+	register int i;
@@ -174,3 +178,2 @@
-change(a,b,c,d,s)
-long a,c;
-char *s;
+void
+change(long a, int b, long c, int d, char *s)
@@ -184,2 +187,2 @@
-range(a,b)
-long a;
+void
+range(long a, int b)
@@ -195,2 +198,2 @@
-cmp(s,t)
-char *s,*t;
+int
+cmp(char *s, char *t)
@@ -201,3 +204,3 @@
-		if(bflag&&isspace(*s)&&isspace(*t)) {
-			while(isspace(*++s)) ;
-			while(isspace(*++t)) ;
+		if(bflag&&isspace(*s&0377)&&isspace(*t&0377)) {
+			while(isspace(*++s&0377)) ;
+			while(isspace(*++t&0377)) ;
@@ -213,2 +216 @@
-FILE *dopen(f1,f2)
-char *f1,*f2;
+FILE *dopen(char *f1, char *f2)
@@ -219 +221 @@
-	if(cmp(f1,"-")==0)
+	if(cmp(f1,"-")==0) {
@@ -223,0 +226 @@
+	}
@@ -227 +230 @@
-		for(bptr=b;*bptr= *f1++;bptr++) ;
+		for(bptr=b;(*bptr= *f1++);bptr++) ;
@@ -232 +235 @@
-		while(*bptr++= *f2++) ;
+		while((*bptr++= *f2++)) ;
@@ -242,2 +245,2 @@
-progerr(s)
-char *s;
+void
+progerr(char *s)
@@ -248,2 +251,2 @@
-error(s,t)
-char *s,*t;
+void
+error(char *s, char *t)
@@ -256 +259,2 @@
-hardsynch()
+int
+hardsynch(void)

% usr/src/cmd/dmesg.c
@@ -20,2 +20,2 @@
-	{"_msgbuf"},
-	{"_msgbufp"}
+	{"_msgbuf",0,0},
+	{"_msgbufp",0,0}
@@ -24,2 +24,3 @@
-main(argc, argv)
-char **argv;
+void done(char *s), pdate(void);
+int
+main(int argc, char **argv)
@@ -84,2 +85,2 @@
-done(s)
-char *s;
+void
+done(char *s)
@@ -102 +103,2 @@
-pdate()
+void
+pdate(void)
@@ -104,2 +106 @@
-	extern char *ctime();
-	static firstime;
+	static int firstime;

% usr/src/cmd/du.c
@@ -17,3 +17 @@
-long	descend();
-char	*rindex();
-char	*strcpy();
+long	descend(char *np, char *fname);
@@ -21,2 +19,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -24 +22 @@
-	register	i = 1;
+	register int	i = 1;
@@ -43 +41 @@
-		if(np = rindex(name, '/')) {
+		if((np = rindex(name, '/'))) {
@@ -60,2 +58 @@
-descend(np, fname)
-char *np, *fname;
+descend(char *np, char *fname)
@@ -81 +78 @@
-		static linked = 0;
+		static int linked = 0;

% usr/src/cmd/dump.c
@@ -39,3 +39 @@
-char	*ctime();
-char	*prdate();
-long	atol();
+char	*prdate(time_t d);
@@ -46,7 +44,14 @@
-int	mark();
-int	add();
-int	dump();
-int	tapsrec();
-int	dmpspc();
-int	dsrch();
-int	nullf();
+void	mark(struct dinode *ip);
+void	add(struct dinode *ip);
+void	dump(struct dinode *ip);
+void	tapsrec(daddr_t d);
+void	dmpspc(daddr_t *dp, int n);
+void	dsrch(daddr_t d);
+void	nullf(daddr_t *dp, int n);
+void	pass(void (*fn)(struct dinode *ip), short *map);
+void	indir(daddr_t d, void (*fn1)(daddr_t d),
+	void (*fn2)(daddr_t *dp, int n), int n);
+void	bitmap(short *map, int typ), spclrec(void);
+void	bread(daddr_t da, char *ba, int c), CLR(short *map), taprec(char *dp);
+void	flusht(void), otape(void), getitime(void), putitime(void);
+void	est(struct dinode *ip), bmapest(short *map);
@@ -58,2 +63,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -62 +67 @@
-	register i;
+	register int i;
@@ -175,3 +180,2 @@
-pass(fn, map)
-int (*fn)();
-short *map;
+void
+pass(void (*fn)(struct dinode *ip), short *map)
@@ -179,2 +183,2 @@
-	register i, j;
-	int bits;
+	register int i, j;
+	int bits = 0;
@@ -213,3 +217,3 @@
-icat(ip, fn1, fn2)
-struct	dinode	*ip;
-int (*fn1)(), (*fn2)();
+static void
+icat(struct dinode *ip, void (*fn1)(daddr_t d),
+	void (*fn2)(daddr_t *dp, int n))
@@ -217 +221 @@
-	register i;
+	register int i;
@@ -231,3 +235,3 @@
-indir(d, fn1, fn2, n)
-daddr_t d;
-int (*fn1)(), (*fn2)();
+void
+indir(daddr_t d, void (*fn1)(daddr_t d),
+	void (*fn2)(daddr_t *dp, int n), int n)
@@ -235 +239 @@
-	register i;
+	register unsigned i;
@@ -257,2 +261,2 @@
-mark(ip)
-struct dinode *ip;
+void
+mark(struct dinode *ip)
@@ -260 +264 @@
-	register f;
+	register int f;
@@ -277,2 +281,2 @@
-add(ip)
-struct dinode *ip;
+void
+add(struct dinode *ip)
@@ -296,2 +300,2 @@
-dump(ip)
-struct dinode *ip;
+void
+dump(struct dinode *ip)
@@ -299 +303 @@
-	register i;
+	register int i;
@@ -317,2 +321,2 @@
-dmpspc(dp, n)
-daddr_t *dp;
+void
+dmpspc(daddr_t *dp, int n)
@@ -320 +324 @@
-	register i, t;
+	register int i, t;
@@ -332,2 +336,2 @@
-bitmap(map, typ)
-short *map;
+void
+bitmap(short *map, int typ)
@@ -335 +339 @@
-	register i, n;
+	register int i, n;
@@ -354 +358,2 @@
-spclrec()
+void
+spclrec(void)
@@ -356 +361 @@
-	register i, *ip, s;
+	register unsigned i, *ip, s;
@@ -361 +366 @@
-	ip = (int *)&spcl;
+	ip = (unsigned *)&spcl;
@@ -369,2 +374,2 @@
-dsrch(d)
-daddr_t d;
+void
+dsrch(daddr_t d)
@@ -373 +378 @@
-	register i;
+	register unsigned i;
@@ -400 +405,2 @@
-nullf()
+void
+nullf(daddr_t *dp, int n)
@@ -401,0 +408,2 @@
+	(void)dp;
+	(void)n;
@@ -404,3 +412,2 @@
-bread(da, ba, c)
-daddr_t da;
-char *ba;
+void
+bread(daddr_t da, char *ba, int c)
@@ -408 +415 @@
-	register n;
+	register int n;
@@ -416,2 +423,2 @@
-CLR(map)
-register short *map;
+void
+CLR(register short *map)
@@ -419 +426 @@
-	register n;
+	register int n;
@@ -432,2 +439,2 @@
-taprec(dp)
-char *dp;
+void
+taprec(char *dp)
@@ -435 +442 @@
-	register i;
+	register int i;
@@ -446,2 +453,2 @@
-tapsrec(d)
-daddr_t d;
+void
+tapsrec(daddr_t d)
@@ -459 +466,2 @@
-flusht()
+void
+flusht(void)
@@ -462 +470 @@
-	register i, si;
+	register int i, si;
@@ -493 +501,2 @@
-otape()
+void
+otape(void)
@@ -508,2 +517 @@
-prdate(d)
-time_t d;
+prdate(time_t d)
@@ -520 +528,2 @@
-getitime()
+void
+getitime(void)
@@ -522 +531 @@
-	register i, df;
+	register int i, df;
@@ -561 +570,2 @@
-putitime()
+void
+putitime(void)
@@ -563 +573 @@
-	register i, n, df;
+	register int i, n, df;
@@ -611,2 +621,2 @@
-est(ip)
-struct dinode *ip;
+void
+est(struct dinode *ip)
@@ -626,2 +636,2 @@
-bmapest(map)
-short *map;
+void
+bmapest(short *map)
@@ -629 +639 @@
-	register i, n;
+	register int i, n;

% usr/src/cmd/dumpdir.c
@@ -51,2 +51,13 @@
-main(argc, argv)
-char *argv[];
+int	readhdr(struct spcl *b), checkvol(struct spcl *b, int t);
+int	gethead(struct spcl *buf), checktype(struct spcl *b, int t);
+int	direq(char *s1, char *s2), search(ino_t inum), readc(void);
+int	checksum(int *b);
+void	pass1(void), printem(char *prefix, ino_t inum), readbits(short *m);
+void	flsh(void), putent(char *cp), mseek(daddr_t pt), getent(char *bf);
+void	getfile(ino_t n, void (*f1)(char *b, long size),
+	void (*f2)(char *b, long size), long size);
+void	readtape(char *b), clearbuf(char *cp), flsht(void);
+void	copy(char *f, char *t, int s), writec(char c);
+void	putdir(char *b, long size), null(char *b, long size);
+int
+main(int argc, char *argv[])
@@ -54,2 +64,0 @@
-	extern char *ctime();
-
@@ -86 +95 @@
-	i = 0;
+int	i = 0;
@@ -91 +100,2 @@
-pass1()
+void
+pass1(void)
@@ -93 +103 @@
-	register i;
+	register int i;
@@ -95 +104,0 @@
-	int	putdir(), null();
@@ -127,3 +136,2 @@
-printem(prefix, inum)
-char *prefix;
-ino_t	inum;
+void
+printem(char *prefix, ino_t inum)
@@ -169,4 +177,3 @@
-getfile(n, f1, f2, size)
-ino_t	n;
-int	(*f2)(), (*f1)();
-long	size;
+void
+getfile(ino_t n, void (*f1)(char *b, long size),
+	void (*f2)(char *b, long size), long size)
@@ -174 +181 @@
-	register i;
+	register int i;
@@ -177,0 +185 @@
+	(void)n;
@@ -215,2 +223,2 @@
-readtape(b)
-char *b;
+void
+readtape(char *b)
@@ -218 +226 @@
-	register i;
+	register int i;
@@ -255 +263,2 @@
-flsht()
+void
+flsht(void)
@@ -260,2 +269,2 @@
-copy(f, t, s)
-register char *f, *t;
+void
+copy(register char *f, register char *t, int s)
@@ -263 +272 @@
-	register i;
+	register int i;
@@ -271,2 +280,2 @@
-clearbuf(cp)
-register char *cp;
+void
+clearbuf(register char *cp)
@@ -274 +283 @@
-	register i;
+	register int i;
@@ -286,2 +295,2 @@
-putent(cp)
-char	*cp;
+void
+putent(char *cp)
@@ -289 +298 @@
-	register i;
+	register int i;
@@ -291 +300 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -301,2 +310,2 @@
-getent(bf)
-register char *bf;
+void
+getent(register char *bf)
@@ -304 +313 @@
-	register i;
+	register int i;
@@ -306 +315 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -317,2 +326,2 @@
-writec(c)
-char c;
+void
+writec(char c)
@@ -324 +333,2 @@
-readc()
+int
+readc(void)
@@ -332,2 +342,2 @@
-mseek(pt)
-daddr_t pt;
+void
+mseek(daddr_t pt)
@@ -338 +348,2 @@
-flsh()
+void
+flsh(void)
@@ -347,2 +358,2 @@
-search(inum)
-ino_t	inum;
+int
+search(ino_t inum)
@@ -350 +361 @@
-	register low, high, probe;
+	register int low, high, probe;
@@ -368,2 +379,2 @@
-direq(s1, s2)
-register char *s1, *s2;
+int
+direq(register char *s1, register char *s2)
@@ -371 +382 @@
-	register i;
+	register int i;
@@ -386,2 +397,2 @@
-gethead(buf)
-struct spcl *buf;
+int
+gethead(struct spcl *buf)
@@ -398,3 +409,2 @@
-checktype(b, t)
-struct	spcl *b;
-int	t;
+int
+checktype(struct spcl *b, int t)
@@ -406,2 +416,2 @@
-checksum(b)
-int *b;
+int
+checksum(int *b)
@@ -409 +419 @@
-	register i, j;
+	register unsigned i, j;
@@ -423,3 +433,2 @@
-checkvol(b, t)
-struct spcl *b;
-int t;
+int
+checkvol(struct spcl *b, int t)
@@ -432,2 +441,2 @@
-readhdr(b)
-struct	spcl *b;
+int
+readhdr(struct spcl *b)
@@ -442,2 +451,2 @@
-putdir(b)
-char *b;
+void
+putdir(char *b, long size)
@@ -446 +455 @@
-	register i;
+	register int i;
@@ -447,0 +457 @@
+	(void)size;
@@ -458,2 +468,2 @@
-readbits(m)
-short	*m;
+void
+readbits(short *m)
@@ -461 +471 @@
-	register i;
+	register int i;
@@ -473 +483 @@
-null() { ; }
+void null(char *b, long size) { (void)b; (void)size; }

% usr/src/cmd/echo.c
@@ -3,3 +3,2 @@
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])

% usr/src/cmd/ed.c
@@ -7,0 +8 @@
+#include <stdio.h>
@@ -14 +14,0 @@
-#define	EOF	-1
@@ -54,3 +54,2 @@
-long	lseek();
-int	(*oldhup)();
-int	(*oldquit)();
+void	(*oldhup)(int sig);
+void	(*oldquit)(int sig);
@@ -92,7 +91,4 @@
-int	*address();
-char	*getline();
-char	*getblock();
-char	*place();
-char	*mktemp();
-char	*malloc();
-char	*realloc();
+int	*address(void);
+char	*getline(int tl);
+char	*getblock(int atl, int iof);
+char	*place(char *sp, char *l1, char *l2);
@@ -101,2 +97,16 @@
-main(argc, argv)
-char **argv;
+void	commands(void), setdot(void), setall(void), setnoaddr(void), nonzero(void);
+void	newline(void), filename(int comm), exfile(void), error(char *s), dosub(void);
+void	blkio(int b, char *buf, int (*iofcn)(int fd, char *buf, int n));
+void	callunix(void), compile(int aeof), delete(void), global(int k), init(void);
+void	join(void), move(int cflag), putchr(int ac), putd(void), putfile(void);
+void	reverse(int *a1, int *a2), substitute(int inglob);
+void	crblock(char *permp, char *buf, int nchar, long startn);
+void	rdelete(int *ad1, int *ad2), makekey(char *a, char *b);
+void	onintr(int sig), onhup(int sig), quit(int sig);
+int	advance(char *lp, char *ep), append(int (*f)(void), int *a);
+int	backref(int i, char *lp), cclass(char *set, char c, int af), compsub(void);
+int	crinit(char *keyp, char *permp), execute(int gf, int *addr), getchr(void);
+int	getkey(void), putline(void), getfile(void), gettty(void), getsub(void);
+int	getcopy(void);
+int
+main(int argc, char **argv)
@@ -105,2 +115 @@
-	extern int onintr(), quit(), onhup();
-	int (*oldintr)();
+	void (*oldintr)(int sig);
@@ -141 +150 @@
-		while (*p2++ = *p1++)
+		while ((*p2++ = *p1++))
@@ -154 +163 @@
-	quit();
+	quit(0);
@@ -157 +166,2 @@
-commands()
+void
+commands(void)
@@ -159,2 +169 @@
-	int getfile(), gettty();
-	register *a1, c;
+	register int *a1, c;
@@ -203,0 +213 @@
+		/* fallthrough */
@@ -265,0 +276 @@
+		/* fallthrough */
@@ -281,0 +293 @@
+		/* fallthrough */
@@ -285 +297,2 @@
-		quit();
+		quit(0);
+		/* fallthrough */
@@ -327,0 +341 @@
+		/* fallthrough */
@@ -357 +371 @@
-		count = (addr2-zero)&077777;
+		count = addr2-zero;
@@ -375 +389 @@
-address()
+address(void)
@@ -377 +391 @@
-	register *a1, minus, c;
+	register int *a1, minus, c;
@@ -471 +485,2 @@
-setdot()
+void
+setdot(void)
@@ -479 +494,2 @@
-setall()
+void
+setall(void)
@@ -490 +506,2 @@
-setnoaddr()
+void
+setnoaddr(void)
@@ -496 +513,2 @@
-nonzero()
+void
+nonzero(void)
@@ -502 +520,2 @@
-newline()
+void
+newline(void)
@@ -504 +523 @@
-	register c;
+	register int c;
@@ -518 +537,2 @@
-filename(comm)
+void
+filename(int comm)
@@ -521 +541 @@
-	register c;
+	register int c;
@@ -530 +550 @@
-		while (*p2++ = *p1++)
+		while ((*p2++ = *p1++))
@@ -550 +570 @@
-		while (*p1++ = *p2++)
+		while ((*p1++ = *p2++))
@@ -555 +575,2 @@
-exfile()
+void
+exfile(void)
@@ -565 +586,2 @@
-onintr()
+void
+onintr(int sig)
@@ -566,0 +589 @@
+	(void)sig;
@@ -573 +596,2 @@
-onhup()
+void
+onhup(int sig)
@@ -574,0 +599 @@
+	(void)sig;
@@ -585 +610 @@
-	quit();
+	quit(0);
@@ -588,2 +613,2 @@
-error(s)
-char *s;
+void
+error(char *s)
@@ -591 +616 @@
-	register c;
+	register int c;
@@ -614 +639,2 @@
-getchr()
+int
+getchr(void)
@@ -617 +643 @@
-	if (lastc=peekc) {
+	if ((lastc=peekc)) {
@@ -633 +659,2 @@
-gettty()
+int
+gettty(void)
@@ -635 +662 @@
-	register c;
+	register int c;
@@ -659 +686,2 @@
-getfile()
+int
+getfile(void)
@@ -661 +689 @@
-	register c;
+	register int c;
@@ -695 +723,2 @@
-putfile()
+void
+putfile(void)
@@ -699 +728 @@
-	register nib;
+	register int nib;
@@ -734,3 +763,2 @@
-append(f, a)
-int *a;
-int (*f)();
+int
+append(int (*f)(void), int *a)
@@ -738 +766 @@
-	register *a1, *a2, *rdot;
+	register int *a1, *a2, *rdot;
@@ -744 +772 @@
-		if ((dol-zero)+1 >= nlall) {
+		if ((dol-zero)+1 >= (int)nlall) {
@@ -768 +796,2 @@
-callunix()
+void
+callunix(void)
@@ -770 +799,2 @@
-	register (*savint)(), pid, rpid;
+	register void (*savint)(int sig);
+	register int pid, rpid;
@@ -787 +817,2 @@
-quit()
+void
+quit(int sig)
@@ -788,0 +820 @@
+	(void)sig;
@@ -797 +829,2 @@
-delete()
+void
+delete(void)
@@ -805,2 +838,2 @@
-rdelete(ad1, ad2)
-int *ad1, *ad2;
+void
+rdelete(int *ad1, int *ad2)
@@ -808 +841 @@
-	register *a1, *a2, *a3;
+	register int *a1, *a2, *a3;
@@ -824 +857,2 @@
-gdelete()
+static void
+gdelete(void)
@@ -826 +860 @@
-	register *a1, *a2, *a3;
+	register int *a1, *a2, *a3;
@@ -846 +880 @@
-getline(tl)
+getline(int tl)
@@ -849 +883 @@
-	register nl;
+	register int nl;
@@ -855 +889 @@
-	while (*lp++ = *bp++)
+	while ((*lp++ = *bp++))
@@ -863 +897,2 @@
-putline()
+int
+putline(void)
@@ -866 +901 @@
-	register nl;
+	register int nl;
@@ -875 +910 @@
-	while (*bp = *lp++) {
+	while ((*bp = *lp++)) {
@@ -887 +922 @@
-	tline += (((lp-linebuf)+03)>>1)&077776;
+	tline += (((lp-linebuf)+03)>>1)&~1;
@@ -892 +927 @@
-getblock(atl, iof)
+getblock(int atl, int iof)
@@ -894,2 +929 @@
-	extern read(), write();
-	register bno, off;
+	register int bno, off;
@@ -899 +933 @@
-	bno = (atl>>8)&0377;
+	bno = atl>>8;
@@ -901,4 +934,0 @@
-	if (bno >= 255) {
-		lastc = '\n';
-		error(T);
-	}
@@ -941,3 +971,2 @@
-blkio(b, buf, iofcn)
-char *buf;
-int (*iofcn)();
+void
+blkio(int b, char *buf, int (*iofcn)(int fd, char *buf, int n))
@@ -951 +980,2 @@
-init()
+void
+init(void)
@@ -953 +983 @@
-	register *markp;
+	register int *markp;
@@ -973 +1003,2 @@
-global(k)
+void
+global(int k)
@@ -976 +1007 @@
-	register c;
+	register int c;
@@ -1025 +1056,2 @@
-join()
+void
+join(void)
@@ -1028 +1060 @@
-	register *a1;
+	register int *a1;
@@ -1033 +1065 @@
-		while (*gp = *lp++)
+		while ((*gp = *lp++))
@@ -1039 +1071 @@
-	while (*lp++ = *gp++)
+	while ((*lp++ = *gp++))
@@ -1047 +1079,2 @@
-substitute(inglob)
+void
+substitute(int inglob)
@@ -1049 +1082 @@
-	register *markp, *a1, nl;
+	register int *markp, *a1, nl;
@@ -1051 +1083,0 @@
-	int getsub();
@@ -1086 +1118,2 @@
-compsub()
+int
+compsub(void)
@@ -1088 +1121 @@
-	register seof, c;
+	register int seof, c;
@@ -1121 +1154,2 @@
-getsub()
+int
+getsub(void)
@@ -1128 +1162 @@
-	while (*p1++ = *p2++)
+	while ((*p1++ = *p2++))
@@ -1134 +1168,2 @@
-dosub()
+void
+dosub(void)
@@ -1144 +1179 @@
-	while (c = *rp++&0377) {
+	while ((c = *rp++&0377)) {
@@ -1158 +1193 @@
-	while (*sp++ = *lp++)
+	while ((*sp++ = *lp++))
@@ -1163 +1198 @@
-	while (*lp++ = *sp++)
+	while ((*lp++ = *sp++))
@@ -1168,2 +1203 @@
-place(sp, l1, l2)
-register char *sp, *l1, *l2;
+place(register char *sp, register char *l1, register char *l2)
@@ -1180 +1214,2 @@
-move(cflag)
+void
+move(int cflag)
@@ -1183 +1217,0 @@
-	int getcopy();
@@ -1223,2 +1257,2 @@
-reverse(a1, a2)
-register int *a1, *a2;
+void
+reverse(register int *a1, register int *a2)
@@ -1237 +1271,2 @@
-getcopy()
+int
+getcopy(void)
@@ -1245 +1280,2 @@
-compile(aeof)
+void
+compile(int aeof)
@@ -1247 +1283 @@
-	register eof, c;
+	register int eof, c;
@@ -1374,2 +1410,2 @@
-execute(gf, addr)
-int *addr;
+int
+execute(int gf, int *addr)
@@ -1380,2 +1416,2 @@
-		braslist[c] = 0;
-		braelist[c] = 0;
+		braslist[c&0377] = 0;
+		braelist[c&0377] = 0;
@@ -1388 +1424 @@
-		while (*p1++ = *p2++)
+		while ((*p1++ = *p2++))
@@ -1425,2 +1461,2 @@
-advance(lp, ep)
-register char *ep, *lp;
+int
+advance(register char *lp, register char *ep)
@@ -1467 +1503 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -1471 +1507 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -1494 +1530 @@
-		continue;
+		return(0);
@@ -1532,3 +1568,2 @@
-backref(i, lp)
-register i;
-register char *lp;
+int
+backref(register int i, register char *lp)
@@ -1545,2 +1580,2 @@
-cclass(set, c, af)
-register char *set, c;
+int
+cclass(register char *set, register char c, int af)
@@ -1548 +1583 @@
-	register n;
+	register int n;
@@ -1559 +1594,2 @@
-putd()
+void
+putd(void)
@@ -1561 +1597 @@
-	register r;
+	register int r;
@@ -1570,2 +1606,2 @@
-puts(sp)
-register char *sp;
+int
+puts(register char *sp)
@@ -1576,0 +1613 @@
+	return(0);
@@ -1582 +1619,2 @@
-putchr(ac)
+void
+putchr(int ac)
@@ -1585 +1623 @@
-	register c;
+	register int c;
@@ -1625,4 +1663,2 @@
-crblock(permp, buf, nchar, startn)
-char *permp;
-char *buf;
-long startn;
+void
+crblock(char *permp, char *buf, int nchar, long startn)
@@ -1654 +1690,2 @@
-getkey()
+int
+getkey(void)
@@ -1658 +1695 @@
-	int (*sig)();
+	void (*sig)(int sig);
@@ -1660 +1697 @@
-	register c;
+	register int c;
@@ -1685,2 +1722,2 @@
-crinit(keyp, permp)
-char	*keyp, *permp;
+int
+crinit(char *keyp, char *permp)
@@ -1689 +1726 @@
-	register i;
+	register int i;
@@ -1748,2 +1785,2 @@
-makekey(a, b)
-char *a, *b;
+void
+makekey(char *a, char *b)

% usr/src/cmd/egrep.y
@@ -13,0 +14 @@
+%left error
@@ -20 +21 @@
-#define NCHARS 128
+#define NCHARS 256
@@ -26 +27 @@
-int line 1;
+int line = 1;
@@ -33 +34 @@
-char chars[MAXLIN];
+int chars[MAXLIN];
@@ -35 +36 @@
-int nxtchar 0;
+int nxtchar = 0;
@@ -58 +59,5 @@
-int	fname;
+char	*fname;
+int	yylex(void), nextch(void), enter(int x), cclenter(int x), node(int x, int l, int r);
+int	unary(int x, int d), cstate(int v), member(int symb, int set, int torf), notin(int n);
+void	yyerror(char *s), synerror(void), overflo(void), add(int *array, int n);
+void	follow(int v), execute(char *file);
@@ -63 +68 @@
-		={ unary(FINAL, $1);
+		{ unary(FINAL, $1);
@@ -68 +73 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -70 +75 @@
-		={ $$ = node(CAT, $2, $3); }
+		{ $$ = node(CAT, $2, $3); }
@@ -72 +77 @@
-		={ $$ = node(CAT, $2, $3); }
+		{ $$ = node(CAT, $2, $3); }
@@ -74 +79 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -77 +82 @@
-		={ $$ = enter(DOT);
+		{ $$ = enter(DOT);
@@ -81 +86 @@
-		={ $$ = enter($1); }
+		{ $$ = enter($1); }
@@ -83 +88 @@
-		={ $$ = enter(DOT); }
+		{ $$ = enter(DOT); }
@@ -85 +90 @@
-		={ $$ = cclenter(CCL); }
+		{ $$ = cclenter(CCL); }
@@ -87 +92 @@
-		={ $$ = cclenter(NCCL); }
+		{ $$ = cclenter(NCCL); }
@@ -91 +96 @@
-		={ $$ = node(OR, $1, $3); }
+		{ $$ = node(OR, $1, $3); }
@@ -93 +98 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -95 +100 @@
-		={ $$ = unary(STAR, $1); }
+		{ $$ = unary(STAR, $1); }
@@ -97 +102 @@
-		={ $$ = unary(PLUS, $1); }
+		{ $$ = unary(PLUS, $1); }
@@ -99 +104 @@
-		={ $$ = unary(QUEST, $1); }
+		{ $$ = unary(QUEST, $1); }
@@ -101 +106 @@
-		={ $$ = $2; }
+		{ $$ = $2; }
@@ -106 +111,2 @@
-yyerror(s) {
+void
+yyerror(char *s) {
@@ -111 +117,2 @@
-yylex() {
+int
+yylex(void) {
@@ -114 +121 @@
-	register char c, d;
+	register int c, d;
@@ -156,0 +164 @@
+			goto defchar;
@@ -161,2 +169,3 @@
-nextch() {
-	register char c;
+int
+nextch(void) {
+	register int c;
@@ -166 +175 @@
-	else c = *input++;
+	else c = *input++ & 0377;
@@ -170 +179,2 @@
-synerror() {
+void
+synerror(void) {
@@ -175 +185,2 @@
-enter(x) int x; {
+int
+enter(int x) {
@@ -183,2 +194,3 @@
-cclenter(x) int x; {
-	register linno;
+int
+cclenter(int x) {
+	register int linno;
@@ -190 +202,2 @@
-node(x, l, r) {
+int
+node(int x, int l, int r) {
@@ -200 +213,2 @@
-unary(x, d) {
+int
+unary(int x, int d) {
@@ -208 +222,2 @@
-overflo() {
+void
+overflo(void) {
@@ -213,2 +228,3 @@
-cfoll(v) {
-	register i;
+static void
+cfoll(int v) {
+	register int i;
@@ -227,2 +243,3 @@
-cgotofn() {
-	register c, i, k;
+static void
+cgotofn(void) {
+	register int c, i, k;
@@ -321,2 +338,3 @@
-cstate(v) {
-	register b;
+int
+cstate(int v) {
+	register int b;
@@ -347,2 +365,3 @@
-member(symb, set, torf) {
-	register i, num, pos;
+int
+member(int symb, int set, int torf) {
+	register int i, num, pos;
@@ -356,2 +375,3 @@
-notin(n) {
-	register i, j, pos;
+int
+notin(int n) {
+	register int i, j, pos;
@@ -371,2 +391,3 @@
-add(array, n) int *array; {
-	register i;
+void
+add(int *array, int n) {
+	register int i;
@@ -383 +404,2 @@
-follow(v) int v; {
+void
+follow(int v) {
@@ -414,2 +436,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -490,2 +512,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -494,2 +516,2 @@
-	register cstat;
-	register ccount;
+	register int cstat;
+	register int ccount;

% usr/src/cmd/expr.y
@@ -15,0 +16,12 @@
+%{
+#include <stdio.h>
+#define YYSTYPE char *
+#define index expr_index
+int yylex(void), ematch(char *s, char *p), step(char *p1, char *p2);
+int advance(char *lp, char *ep), ecmp(char *a, char *b, int count);
+void errxx(int c), getrnge(char *str), yyerror(char *s);
+char *compile(char *instring, char *ep, char *endbuf, int seof);
+char *rel(int op, char *r1, char *r2), *arith(int op, char *r1, char *r2);
+char *conj(int op, char *r1, char *r2), *substr(char *v, char *s, char *w);
+char *length(char *s), *index(char *s, char *t), *match(char *s, char *p);
+%}
@@ -20 +32 @@
-expression:	expr NOARG = {
+expression:	expr NOARG {
@@ -27,19 +39,19 @@
-expr:	'(' expr ')' = { $$ = $2; }
-	| expr OR expr   = { $$ = conj(OR, $1, $3); }
-	| expr AND expr   = { $$ = conj(AND, $1, $3); }
-	| expr EQ expr   = { $$ = rel(EQ, $1, $3); }
-	| expr GT expr   = { $$ = rel(GT, $1, $3); }
-	| expr GEQ expr   = { $$ = rel(GEQ, $1, $3); }
-	| expr LT expr   = { $$ = rel(LT, $1, $3); }
-	| expr LEQ expr   = { $$ = rel(LEQ, $1, $3); }
-	| expr NEQ expr   = { $$ = rel(NEQ, $1, $3); }
-	| expr ADD expr   = { $$ = arith(ADD, $1, $3); }
-	| expr SUBT expr   = { $$ = arith(SUBT, $1, $3); }
-	| expr MULT expr   = { $$ = arith(MULT, $1, $3); }
-	| expr DIV expr   = { $$ = arith(DIV, $1, $3); }
-	| expr REM expr   = { $$ = arith(REM, $1, $3); }
-	| expr MCH expr	 = { $$ = match($1, $3); }
-	| MATCH expr expr = { $$ = match($2, $3); }
-	| SUBSTR expr expr expr = { $$ = substr($2, $3, $4); }
-	| LENGTH expr       = { $$ = length($2); }
-	| INDEX expr expr = { $$ = index($2, $3); }
+expr:	'(' expr ')' { $$ = $2; }
+	| expr OR expr   { $$ = conj(OR, $1, $3); }
+	| expr AND expr   { $$ = conj(AND, $1, $3); }
+	| expr EQ expr   { $$ = rel(EQ, $1, $3); }
+	| expr GT expr   { $$ = rel(GT, $1, $3); }
+	| expr GEQ expr   { $$ = rel(GEQ, $1, $3); }
+	| expr LT expr   { $$ = rel(LT, $1, $3); }
+	| expr LEQ expr   { $$ = rel(LEQ, $1, $3); }
+	| expr NEQ expr   { $$ = rel(NEQ, $1, $3); }
+	| expr ADD expr   { $$ = arith(ADD, $1, $3); }
+	| expr SUBT expr   { $$ = arith(SUBT, $1, $3); }
+	| expr MULT expr   { $$ = arith(MULT, $1, $3); }
+	| expr DIV expr   { $$ = arith(DIV, $1, $3); }
+	| expr REM expr   { $$ = arith(REM, $1, $3); }
+	| expr MCH expr	 { $$ = match($1, $3); }
+	| MATCH expr expr { $$ = match($2, $3); }
+	| SUBSTR expr expr expr { $$ = substr($2, $3, $4); }
+	| LENGTH expr       { $$ = length($2); }
+	| INDEX expr expr { $$ = index($2, $3); }
@@ -50 +61,0 @@
-#include <stdio.h>
@@ -54 +64,0 @@
-long atol();
@@ -60 +69,0 @@
-char *malloc();
@@ -63 +72,2 @@
-main(argc, argv) char **argv; {
+int
+main(int argc, char **argv) {
@@ -76 +86,2 @@
-yylex() {
+int
+yylex(void) {
@@ -78 +89 @@
-	register i;
+	register int i;
@@ -86,2 +97,2 @@
-	for(i = 0; *operator[i]; ++i)
-		if(EQL(operator[i], p))
+	for(i = 0; *operators[i]; ++i)
+		if(EQL(operators[i], p))
@@ -94,2 +105,2 @@
-char *rel(op, r1, r2) register char *r1, *r2; {
-	register i;
+char *rel(int op, register char *r1, register char *r2) {
+	register int i;
@@ -112 +123 @@
-char *arith(op, r1, r2) char *r1, *r2; {
+char *arith(int op, char *r1, char *r2) {
@@ -132,2 +143,2 @@
-char *conj(op, r1, r2) char *r1, *r2; {
-	register char *rv;
+char *conj(int op, char *r1, char *r2) {
+	register char *rv = 0;
@@ -162,2 +173,2 @@
-char *substr(v, s, w) char *v, *s, *w; {
-register si, wi;
+char *substr(char *v, char *s, char *w) {
+register int si, wi;
@@ -178,2 +189,2 @@
-char *length(s) register char *s; {
-	register i = 0;
+char *length(register char *s) {
+	register int i = 0;
@@ -189,2 +200,2 @@
-char *index(s, t) char *s, *t; {
-	register i, j;
+char *index(char *s, char *t) {
+	register int i, j;
@@ -202 +213 @@
-char *match(s, p)
+char *match(char *s, char *p)
@@ -218,2 +229,2 @@
-#define RETURN(c)	return
-#define ERROR(c)	errxx(c)
+#define RETURN(c)	return(c)
+#define ERROR(c)	return(errxx(c), (char *)0)
@@ -222,3 +233,2 @@
-ematch(s, p)
-char *s;
-register char *p;
+int
+ematch(char *s, register char *p)
@@ -227,2 +237 @@
-	char *compile();
-	register num;
+	register int num;
@@ -231 +240 @@
-	compile(p, expbuf, &expbuf[512], 0);
+	compile(p, expbuf, &expbuf[ESIZE], 0);
@@ -246 +255,2 @@
-errxx(c)
+void
+errxx(int c)
@@ -247,0 +258 @@
+	(void)c;
@@ -290,3 +301 @@
-compile(instring, ep, endbuf, seof)
-register char *ep;
-char *instring, *endbuf;
+compile(char *instring, register char *ep, char *endbuf, int seof)
@@ -295,2 +304,2 @@
-	register c;
-	register eof = seof;
+	register int c;
+	register int eof = seof;
@@ -322,0 +332,2 @@
+			if (bracketp != bracket)
+				ERROR(42);
@@ -457,0 +469 @@
+			/* fallthrough */
@@ -468,2 +480,2 @@
-step(p1, p2)
-register char *p1, *p2;
+int
+step(register char *p1, register char *p2)
@@ -471 +483 @@
-	register c;
+	register int c;
@@ -500,2 +512,2 @@
-advance(lp, ep)
-register char *lp, *ep;
+int
+advance(register char *lp, register char *ep)
@@ -537 +549 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -541 +553 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -592,2 +604,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[*ep&0377];
+		ct = braelist[*ep++&0377] - bbeg;
@@ -602,2 +614,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[*ep&0377];
+		ct = braelist[*ep++&0377] - bbeg;
@@ -646,2 +658,2 @@
-getrnge(str)
-register char *str;
+void
+getrnge(register char *str)
@@ -650 +662 @@
-	size = *str == 255 ? 20000 : (*str &0377) - low;
+	size = (*str & 0377) == 255 ? 20000 : (*str &0377) - low;
@@ -653,3 +665,2 @@
-ecmp(a, b, count)
-register char	*a, *b;
-register	count;
+int
+ecmp(register char *a, register char *b, register int count)
@@ -664,2 +675,2 @@
-yyerror(s)
-
+void
+yyerror(char *s)

% usr/src/cmd/factor.c usr/src/cmd/factor.s
@@ -1,7 +1 @@
-.globl	sqrt
-exit = 1.
-read = 3.
-write = 4.
-ldfps = 170100^tst
-/
-	ldfps	$240
+#include <stdio.h>
@@ -9,75 +3 @@
-	clr	argflg
-	cmp	(sp)+,$2
-	blt	begin
-	tst	(sp)+
-	mov	(sp),r2
-	jsr	r5,atof; getch1
-	inc	argflg
-	br	begin1
-begin:
-	tst	argflg
-	beq 9f; sys exit; 9:
-	jsr	r5,atof; getch
-begin1:
-	tstf	fr0
-	cfcc
-	bpl 9f; jmp ouch; 9:
-	bne 9f; sys exit; 9:
-	cmpf	big,fr0
-	cfcc
-	bgt 9f; jmp ouch; 9:
-/
-	movf	fr0,n
-	jsr	pc,sqrt
-	movf	fr0,v
-	mov	$1,r0
-	sys	write; nl; 1
-/
-	movf	$one,fr0
-	movf	fr0,fr4
-/
-	movf	n,fr0
-	movf	$two,fr1
-	jsr	r5,xt
-/
-	movf	n,fr0
-	movif	$3,fr1
-	jsr	r5,xt
-/
-	movf	n,fr0
-	movif	$5,fr1
-	jsr	r5,xt
-/
-	movf	n,fr0
-	movif	$7,fr1
-	jsr	r5,xt
-/
-	movf	n,fr0
-	movif	$11.,fr1
-	jsr	r5,xt
-/
-	movf	n,fr0
-	movif	$13.,fr1
-	jsr	r5,xt
-/
-	movf	n,fr0
-	movif	$17.,fr1
-	mov	$tab+6,r4
-	jsr	pc,xx
-	jmp	begin
-/
-xt:
-	movf	fr0,fr2
-	divf	fr1,fr2
-	modf	$one,fr2
-	movf	fr3,fr2
-	mulf	fr1,fr2
-	cmpf	fr2,fr0
-	cfcc
-	beq	hit2
-	rts	r5
-/
-/
-out1:
-	mov	$tab,r4
-	br	in1
+#define	BIG	72057594037927936
@@ -85,134 +5,7 @@
-out2:
-	modf	fr4,fr2
-	cfcc
-	bne 9f; mov $xx0,-(sp); jmp hit; 9:
-	br	in2
-xx:
-	mov	(r4)+,kazoo
-xx0:
-	mov	$kazoo,r0
-	mov	$100.,r1
-	clr	r2
-	mov	$gorp,r3
-	mov	$gorp+6,r5
-xx1:
-	movf	fr0,fr2
-	divf	fr1,fr2
-	cmp	r4,$tabend
-	bhis	out1
-in1:
-	movf	fr2,(r3)
-	bit	r2,(r5)
-	beq	out2
-in2:
-kazoo	=.+2
-	addf	$kazoo,fr1
-	mov	(r4)+,(r0)
-	sob	r1,xx1
-	mov	$100.,r1
-	mov	$127.,r2
-	cmpf	v,fr1
-	cfcc
-	bge	xx1
-	cmpf	$one,fr0
-	cfcc
-	beq	1f
-	mov	$1,r0
-	sys	write; sp5; 5
-	movf	n,fr0
-	jsr	r5,ftoa; wrchar
-	mov	$1,r0
-	sys	write; nl; 1
-1:
-	rts	pc
-/
-/
-/
-hit2:
-	movf	fr1,t
-	movf	fr3,n
-	movf	fr3,fr0
-	jsr	pc,sqrt
-	movf	fr0,v
-	mov	$1,r0
-	sys	write; sp5; 5
-	movf	t,fr0
-	jsr	r5,ftoa; wrchar
-	mov	$1,r0
-	sys	write; nl; 1
-	movf	n,fr0
-	movf	t,fr1
-	cmp	r4,$tab
-	bne	1f
-	mov	$tabend,r4
-1:
-	mov	-(r4),kazoo
-	jmp	xt
-/
-hit:
-	movf	fr1,t
-	movf	fr3,n
-	movf	fr3,fr0
-	jsr	pc,sqrt
-	movf	fr0,v
-	mov	$1,r0
-	sys	write; sp5; 5
-	movf	t,fr0
-	jsr	r5,ftoa; wrchar
-	mov	$1,r0
-	sys	write; nl; 1
-	movf	n,fr0
-	movf	t,fr1
-	mov	$kazoo,r0
-	rts	pc
-/
-/
-/	get one character from the console.
-/	called from atof.
-/
-getch:
-	clr	r0
-	sys	read; ch; 1
-	bec 9f; sys exit; 9:
-	tst r0; bne 9f; sys exit; 9:
-	mov	ch,r0
-	rts	r5
-/
-/
-/	get one character form the argument string.
-getch1:
-	movb	(r2)+,r0
-	rts	r5
-/
-/	write one character on the console
-/	called from ftoa.
-/
-wrchar:
-	mov	r0,ch
-	mov	$1,r0
-	sys	write; ch; 1
-	rts	r5
-/
-/
-/	read and convert a line from the console into fr0.
-/
-atof:
-	mov	r1,-(sp)
-	movif	$10.,r3
-	clrf	r0
-1:
-	jsr	r5,*(r5)
-	sub	$'0,r0
-	cmp	r0,$9.
-	bhi	2f
-	mulf	r3,r0
-	movif	r0,r1
-	addf	r1,r0
-	br	1b
-2:
-	cmp	r0,$' -'0
-	beq	1b
-/
-	mov	(sp)+,r1
-	tst	(r5)+
-	rts	r5
+char	tab[] = {
+	10, 2, 4, 2, 4, 6, 2, 6, 4, 2, 4, 6, 6, 2, 6, 4,
+	2, 6, 4, 6, 8, 4, 2, 4, 2, 4, 8, 6, 4, 6, 2, 4,
+	6, 2, 6, 6, 4, 2, 4, 6, 2, 6, 4, 2, 4, 2, 10, 2
+};
+char	*arg;
+long long n;
@@ -220,90 +13,4 @@
-/
-/
-/
-/
-ftoa:
-	mov	$ebuf,r2
-1:
-	modf	tenth,fr0
-	movf	fr0,fr2
-	movf	fr1,fr0
-	addf	$epsilon,fr2
-	modf	$ten,fr2
-	movfi	fr3,r0
-	movb	r0,-(r2)
-	tstf	fr0
-	cfcc
-	bne	1b
-1:
-	movb	(r2)+,r0
-	add	$60,r0
-	jsr	r5,*(r5)
-	cmp	r2,$ebuf
-	blo	1b
-	tst	(r5)+
-	rts	r5
-/
-epsilon = 037114
-tenth:	037314; 146314; 146314; 146315
-	.bss
-buf:	.=.+18.
-ebuf:
-	.text
-/
-/
-/
-/	complain about a number which the program
-/	is unable to digest
-ouch:
-	mov	$2,r0
-	sys	write; 1f; 2f-1f
-	jmp	begin
-/
-1:	<Ouch.\n>
-2:	.even
-/
-/
-one	= 40200
-two	= 40400
-four	= 40600
-ten	= 41040
-/
-	.data
-big:	056177; 177777; 177777; 177777
-nl:	<\n>
-sp5:	<     >
-	.even
-/
-tab:
-	41040; 40400; 40600; 40400; 40600; 40700; 40400; 40700
-	40600; 40400; 40600; 40700; 40700; 40400; 40700; 40600
-	40400; 40700; 40600; 40700; 41000; 40600; 40400; 40600
-	40400; 40600; 41000; 40700; 40600; 40700; 40400; 40600
-	40700; 40400; 40700; 40700; 40600; 40400; 40600; 40700
-	40400; 40700; 40600; 40400; 40600; 40400; 41040; 40400
-tabend:
-/
-	.bss
-ch:	.=.+2
-t:	.=.+8
-n:	.=.+8
-v:	.=.+8
-gorp:	.=.+8
-argflg:	.=.+2
-	.text
-ldfps = 170100^tst
-stfps = 170200^tst
-/
-/	sqrt replaces the f.p. number in fr0 by its
-/	square root.  newton's method
-/
-.globl	sqrt, _sqrt
-/
-/
-_sqrt:
-	mov	r5,-(sp)
-	mov	sp,r5
-	movf	4(r5),fr0
-	jsr	pc,sqrt
-	mov	(sp)+,r5
-	rts	pc
+static int
+getch(void)
+{
+	int c;
@@ -311,41 +18,55 @@
-sqrt:
-	tstf	fr0
-	cfcc
-	bne	1f
-	clc
-	rts	pc		/sqrt(0)
-1:
-	bgt	1f
-	clrf	fr0
-	sec
-	rts	pc		/ sqrt(-a)
-1:
-	mov	r0,-(sp)
-	stfps	-(sp)
-	mov	(sp),r0
-	bic	$!200,r0		/ retain mode
-	ldfps	r0
-	movf	fr1,-(sp)
-	movf	fr2,-(sp)
-/
-	movf	fr0,fr1
-	movf	fr0,-(sp)
-	asr	(sp)
-	add	$20100,(sp)
-	movf	(sp)+,fr0	/initial guess
-	mov	$4,r0
-1:
-	movf	fr1,fr2
-	divf	fr0,fr2
-	addf	fr2,fr0
-	mulf	$half,fr0	/ x = (x+a/x)/2
-	sob	r0,1b
-2:
-	movf	(sp)+,fr2
-	movf	(sp)+,fr1
-	ldfps	(sp)+
-	mov	(sp)+,r0
-	clc
-	rts	pc
-/
-half	= 40000
+	if(arg)
+		return(*arg++);
+	if((c = getchar()) == EOF)
+		exit(0);
+	return(c);
+}
+
+static void
+put(long long d)
+{
+	char b[20], *s;
+
+	s = b;
+	do
+		*s++ = d%10 + '0';
+	while(d /= 10);
+	printf("     ");
+	while(s > b)
+		putchar(*--s);
+	putchar('\n');
+}
+
+int
+main(int argc, char **argv)
+{
+	register int c, i;
+	long long d;
+
+	if(argc >= 2)
+		arg = argv[1];
+	for(;;) {
+		n = 0;
+		while((c = getch()) == ' ' || (c >= '0' && c <= '9'))
+			if(c != ' ' && n < BIG)
+				n = n*10 + c - '0';
+		if(n == 0)
+			exit(0);
+		if(n >= BIG)
+			fprintf(stderr, "Ouch.\n");
+		else {
+			putchar('\n');
+			for(d = 2, i = 3; d*d <= n; ) {
+				if(n%d == 0) {
+					put(d);
+					n /= d;
+				} else
+					d += d < 17 ? 1 + (d > 2) : tab[i++ % 48];
+			}
+			if(n != 1)
+				put(n);
+		}
+		if(arg)
+			exit(0);
+	}
+}

% usr/src/cmd/fgrep.c
@@ -33,2 +33,3 @@
-main(argc, argv)
-char **argv;
+void execute(char *file), cgotofn(void), overflo(void), cfail(void);
+int
+main(int argc, char **argv)
@@ -112,2 +113,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -117 +118 @@
-	register ccount;
+	register int ccount;
@@ -208 +209 @@
-		if (*p++ == '\n')
+		if (*p++ == '\n') {
@@ -215,0 +217 @@
+		}
@@ -225 +227,2 @@
-getargc()
+static int
+getargc(void)
@@ -227 +230 @@
-	register c;
+	register int c;
@@ -235,2 +238,3 @@
-cgotofn() {
-	register c;
+void
+cgotofn(void) {
+	register int c;
@@ -298 +302,2 @@
-overflo() {
+void
+overflo(void) {
@@ -302 +307,2 @@
-cfail() {
+void
+cfail(void) {

% usr/src/cmd/file.c
@@ -23,2 +23,4 @@
-main(argc, argv)
-char **argv;
+void type(char *file);
+int ccom(void), ascom(void), english(char *bp, int n), lookup(char *tab[]);
+int
+main(int argc, char **argv)
@@ -56,2 +58,2 @@
-type(file)
-char *file;
+void
+type(char *file)
@@ -103,0 +106 @@
+		/* fallthrough */
@@ -143 +146 @@
-		if(buf[i] <= 0)
+		if(buf[i] == 0 || buf[i] & 0200)
@@ -184 +187 @@
-		else if(buf[j] == '\n' && isalpha(buf[j+2])){
+		else if((j < 0 || buf[j] == '\n') && isalpha(buf[j+2]&0377)){
@@ -201 +204 @@
-			else if(buf[j] == '\n' && isalpha(buf[j+2])){
+			else if(buf[j] == '\n' && isalpha(buf[j+2]&0377)){
@@ -238 +241 @@
-		/*.... */
+		.... */
@@ -242,2 +245,2 @@
-lookup(tab)
-char *tab[];
+int
+lookup(char *tab[])
@@ -260 +263,2 @@
-ccom(){
+int
+ccom(void){
@@ -275 +279,2 @@
-ascom(){
+int
+ascom(void){
@@ -284,2 +289,2 @@
-english (bp, n)
-char *bp;
+int
+english (char *bp, int n)
@@ -295 +300 @@
-		if (bp[j]<NASC)
+		if ((bp[j]&0377)<NASC)

% usr/src/cmd/find.c
@@ -2,0 +3 @@
+#define	ctime	find_ctime
@@ -13 +14 @@
-	int (*F)();
+	int (*F)(struct anode *p);
@@ -33,6 +34,6 @@
-struct	anode	*exp(),
-		*e1(),
-		*e2(),
-		*e3(),
-		*mk();
-char	*nxtarg();
+struct	anode	*exp(void),
+		*e1(void),
+		*e2(void),
+		*e3(void),
+		*mk(int (*f)(struct anode *p), struct anode *l, struct anode *r);
+char	*nxtarg(void);
@@ -41,3 +42,13 @@
-char *rindex();
-char *sbrk();
-main(argc, argv) char *argv[];
+void	pr(char *s), bwrite(short *rp, int c);
+int	descend(char *name, char *fname, struct anode *exlist);
+int	getunum(char *f, char *s), gmatch(char *s, char *p), scomp(int a, int b, char s);
+int	doex(int com), chgreel(int x, int fl), amatch(char *s, char *p), umatch(char *s, char *p);
+int	and(struct anode *p), or(struct anode *p), not(struct anode *p);
+int	exeq(struct anode *p), ok(struct anode *p), glob(struct anode *p);
+int	mtime(struct anode *p), atime(struct anode *p), ctime(struct anode *p);
+int	user(struct anode *p), group(struct anode *p), size(struct anode *p);
+int	perm(struct anode *p), links(struct anode *p), print(struct anode *p);
+int	type(struct anode *p), ino(struct anode *p), cpio(struct anode *p);
+int	newer(struct anode *p);
+int
+main(int argc, char *argv[])
@@ -48 +59 @@
-	FILE *pwd, *popen();
+	FILE *pwd;
@@ -77 +88 @@
-		if(cp = rindex(Pathname, '/')) {
+		if((cp = rindex(Pathname, '/'))) {
@@ -92 +103 @@
-		cpio();
+		cpio(0);
@@ -99,2 +110 @@
-struct anode *exp() { /* parse ALTERNATION (-o)  */
-	int or();
+struct anode *exp(void) { /* parse ALTERNATION (-o)  */
@@ -111,2 +121 @@
-struct anode *e1() { /* parse CONCATENATION (formerly -a) */
-	int and();
+struct anode *e1(void) { /* parse CONCATENATION (formerly -a) */
@@ -128,2 +137 @@
-struct anode *e2() { /* parse NOT (!) */
-	int not();
+struct anode *e2(void) { /* parse NOT (!) */
@@ -141,4 +149 @@
-struct anode *e3() { /* parse parens and predicates */
-	int exeq(), ok(), glob(),  mtime(), atime(), ctime(), user(),
-		group(), size(), perm(), links(), print(),
-		type(), ino(), cpio(), newer();
+struct anode *e3(void) { /* parse parens and predicates */
@@ -147 +152,2 @@
-	register char *a, *b, s;
+	register char *a, *b;
+	register int s;
@@ -226 +232 @@
-			pr("find: cannot create "), pr(s), pr("\n");
+			pr("find: cannot create "), pr(b), pr("\n");
@@ -242,0 +249 @@
+	return(0);
@@ -244,3 +251 @@
-struct anode *mk(f, l, r)
-int (*f)();
-struct anode *l, *r;
+struct anode *mk(int (*f)(struct anode *p), struct anode *l, struct anode *r)
@@ -254,2 +259,2 @@
-char *nxtarg() { /* get next arg from command line */
-	static strikes = 0;
+char *nxtarg(void) { /* get next arg from command line */
+	static int strikes = 0;
@@ -270,2 +275,2 @@
-and(p)
-register struct anode *p;
+int
+and(register struct anode *p)
@@ -275,2 +280,2 @@
-or(p)
-register struct anode *p;
+int
+or(register struct anode *p)
@@ -280,2 +285,2 @@
-not(p)
-register struct anode *p;
+int
+not(register struct anode *p)
@@ -285,2 +290,2 @@
-glob(p)
-register struct { int f; char *pat; } *p; 
+int
+glob(register struct anode *p)
@@ -288 +293 @@
-	return(gmatch(Fname, p->pat));
+	return(gmatch(Fname, (char *)p->L));
@@ -290 +295,2 @@
-print()
+int
+print(struct anode *p)
@@ -291,0 +298 @@
+	(void)p;
@@ -295,2 +302,2 @@
-mtime(p)
-register struct { int f, t, s; } *p; 
+int
+mtime(register struct anode *p)
@@ -298 +305 @@
-	return(scomp((int)((Now - Statb.st_mtime) / A_DAY), p->t, p->s));
+	return(scomp((int)((Now - Statb.st_mtime) / A_DAY), (int)p->L, (int)p->R));
@@ -300,2 +307,2 @@
-atime(p)
-register struct { int f, t, s; } *p; 
+int
+atime(register struct anode *p)
@@ -303 +310 @@
-	return(scomp((int)((Now - Statb.st_atime) / A_DAY), p->t, p->s));
+	return(scomp((int)((Now - Statb.st_atime) / A_DAY), (int)p->L, (int)p->R));
@@ -305,2 +312,2 @@
-ctime(p)
-register struct { int f, t, s; } *p; 
+int
+ctime(register struct anode *p)
@@ -308 +315 @@
-	return(scomp((int)((Now - Statb.st_ctime) / A_DAY), p->t, p->s));
+	return(scomp((int)((Now - Statb.st_ctime) / A_DAY), (int)p->L, (int)p->R));
@@ -310,2 +317,2 @@
-user(p)
-register struct { int f, u, s; } *p; 
+int
+user(register struct anode *p)
@@ -313 +320 @@
-	return(scomp(Statb.st_uid, p->u, p->s));
+	return(scomp(Statb.st_uid, (int)p->L, (int)p->R));
@@ -315,2 +322,2 @@
-ino(p)
-register struct { int f, u, s; } *p;
+int
+ino(register struct anode *p)
@@ -318 +325 @@
-	return(scomp((int)Statb.st_ino, p->u, p->s));
+	return(scomp((int)Statb.st_ino, (int)p->L, (int)p->R));
@@ -320,2 +327,2 @@
-group(p)
-register struct { int f, u; } *p; 
+int
+group(register struct anode *p)
@@ -323 +330 @@
-	return(p->u == Statb.st_gid);
+	return((int)p->L == Statb.st_gid);
@@ -325,2 +332,2 @@
-links(p)
-register struct { int f, link, s; } *p; 
+int
+links(register struct anode *p)
@@ -328 +335 @@
-	return(scomp(Statb.st_nlink, p->link, p->s));
+	return(scomp(Statb.st_nlink, (int)p->L, (int)p->R));
@@ -330,2 +337,2 @@
-size(p)
-register struct { int f, sz, s; } *p; 
+int
+size(register struct anode *p)
@@ -333 +340 @@
-	return(scomp((int)((Statb.st_size+511)>>9), p->sz, p->s));
+	return(scomp((int)((Statb.st_size+511)>>9), (int)p->L, (int)p->R));
@@ -335,2 +342,2 @@
-perm(p)
-register struct { int f, per, s; } *p; 
+int
+perm(register struct anode *p)
@@ -338,3 +345,3 @@
-	register i;
-	i = (p->s=='-') ? p->per : 07777; /* '-' means only arg bits */
-	return((Statb.st_mode & i & 07777) == p->per);
+	register int i;
+	i = ((int)p->R=='-') ? (int)p->L : 07777; /* '-' means only arg bits */
+	return((Statb.st_mode & i & 07777) == (int)p->L);
@@ -342,2 +349,2 @@
-type(p)
-register struct { int f, per, s; } *p;
+int
+type(register struct anode *p)
@@ -345 +352 @@
-	return((Statb.st_mode&S_IFMT)==p->per);
+	return((Statb.st_mode&S_IFMT)==(int)p->L);
@@ -347,2 +354,2 @@
-exeq(p)
-register struct { int f, com; } *p;
+int
+exeq(register struct anode *p)
@@ -351 +358 @@
-	return(doex(p->com));
+	return(doex((int)p->L));
@@ -353,2 +360,2 @@
-ok(p)
-struct { int f, com; } *p;
+int
+ok(struct anode *p)
@@ -359 +366 @@
-	pr("< "), pr(Argv[p->com]), pr(" ... "), pr(Pathname), pr(" >?   ");
+	pr("< "), pr(Argv[(int)p->L]), pr(" ... "), pr(Pathname), pr(" >?   ");
@@ -367 +374 @@
-	if(yes) return(doex(p->com));
+	if(yes) return(doex((int)p->L));
@@ -373,2 +380 @@
-long mklong(v)
-short v[];
+static long mklong(short v[])
@@ -383 +389,2 @@
-cpio()
+int
+cpio(struct anode *p)
@@ -400 +407 @@
-	register ifile, ct;
+	register int ifile, ct;
@@ -402 +409 @@
-	register i;
+	register int i;
@@ -403,0 +411 @@
+	(void)p;
@@ -421 +429 @@
-		return;
+		return(0);
@@ -425 +433 @@
-		return;
+		return(0);
@@ -430 +438 @@
-		return;
+		return(0);
@@ -440 +448 @@
-	return;
+	return(0);
@@ -442 +450,2 @@
-newer()
+int
+newer(struct anode *p)
@@ -443,0 +453 @@
+	(void)p;
@@ -448,3 +458,2 @@
-scomp(a, b, s) /* funny signed compare */
-register a, b;
-register char s;
+int
+scomp(register int a, register int b, register char s) /* funny signed compare */
@@ -459 +468,2 @@
-doex(com)
+int
+doex(int com)
@@ -461 +471 @@
-	register np;
+	register int np;
@@ -464 +474 @@
-	static ccode;
+	static int ccode;
@@ -467 +477 @@
-	while (na=Argv[com++]) {
+	while ((na=Argv[com++])) {
@@ -477 +487 @@
-		execvp(nargv[0], nargv, np);
+		execvp(nargv[0], nargv);
@@ -483,2 +493,3 @@
-getunum(f, s) char *f, *s; { /* find user/group name and return number */
-	register i;
+int
+getunum(char *f, char *s) { /* find user/group name and return number */
+	register int i;
@@ -486 +497 @@
-	register c;
+	register int c;
@@ -491,0 +503,2 @@
+	if(pin == NULL)
+		return(i);
@@ -496 +509 @@
-			while((c = *sp++ = getc(pin)) != ':')
+			while((*sp++ = c = getc(pin)) != ':')
@@ -503 +516 @@
-				while((*sp = getc(pin)) != ':') sp++;
+				while((*sp = c = getc(pin)) != ':' && c != EOF && sp < &str[19]) sp++;
@@ -515,3 +528,2 @@
-descend(name, fname, exlist)
-struct anode *exlist;
-char *name, *fname;
+int
+descend(char *name, char *fname, struct anode *exlist)
@@ -612,2 +624,2 @@
-gmatch(s, p) /* string match as in glob */
-register char *s, *p;
+int
+gmatch(register char *s, register char *p) /* string match as in glob */
@@ -619,2 +631,2 @@
-amatch(s, p)
-register char *s, *p;
+int
+amatch(register char *s, register char *p)
@@ -622 +634 @@
-	register cc;
+	register int cc;
@@ -632 +644 @@
-		while (cc = *++p) {
+		while ((cc = *++p)) {
@@ -642 +654 @@
-				k |= lc <= scc & scc <= (cc=p[1]);
+				k |= (lc <= scc) & (scc <= (cc=p[1]));
@@ -661,2 +673,2 @@
-umatch(s, p)
-register char *s, *p;
+int
+umatch(register char *s, register char *p)
@@ -670,3 +682,2 @@
-bwrite(rp, c)
-register short *rp;
-register c;
+void
+bwrite(register short *rp, register int c)
@@ -693 +704,2 @@
-chgreel(x, fl)
+int
+chgreel(int x, int fl)
@@ -695 +707 @@
-	register f;
+	register int f;
@@ -719,2 +731,2 @@
-pr(s)
-char *s;
+void
+pr(char *s)

% usr/src/cmd/getty.c
@@ -7,0 +8,4 @@
+int read(int fd, char *buf, int n), write(int fd, char *buf, int n);
+int ioctl(int fd, int req, void *argp), getname(void);
+int execl(char *name, char *arg0, ...);
+void exit(int status), puts(char *as), putchr(int cc);
@@ -26 +30 @@
-	'0', 1,
+	{ '0', 1,
@@ -29 +33 @@
-	"\n\r\033;\007login: ",
+	"\n\r\033;\007login: " },
@@ -31 +35 @@
-	1, 2,
+	{ 1, 2,
@@ -34 +38 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -36 +40 @@
-	2, 3,
+	{ 2, 3,
@@ -39 +43 @@
-	"\n\r\033:\006\006\017login: ",
+	"\n\r\033:\006\006\017login: " },
@@ -41 +45 @@
-	3, '0',
+	{ 3, '0',
@@ -44 +48 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -47 +51 @@
-	'-', '-',
+	{ '-', '-',
@@ -50 +54 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -53 +57 @@
-	'1', '1',
+	{ '1', '1',
@@ -56 +60 @@
-	"\n\r\033:\006\006\017login: ",
+	"\n\r\033:\006\006\017login: " },
@@ -59 +63 @@
-	'2', '2',
+	{ '2', '2',
@@ -62 +66 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -65 +69 @@
-	'3', '5',
+	{ '3', '5',
@@ -68 +72 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -71 +75 @@
-	'5', '3',
+	{ '5', '3',
@@ -74 +78 @@
-	"\n\r\033;\007login: ",
+	"\n\r\033;\007login: " },
@@ -77 +81 @@
-	'4', '4',
+	{ '4', '4',
@@ -80 +84 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -83 +87 @@
-	'i', 'i',
+	{ 'i', 'i',
@@ -86 +90 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -89 +93 @@
-	'l', 'l',
+	{ 'l', 'l',
@@ -92 +96 @@
-	"*",
+	"*" },
@@ -94 +98 @@
-	'6', '6',
+	{ '6', '6',
@@ -97 +101 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -109,21 +113,2 @@
-char partab[] = {
-	0001,0201,0201,0001,0201,0001,0001,0201,
-	0202,0004,0003,0205,0005,0206,0201,0001,
-	0201,0001,0001,0201,0001,0201,0201,0001,
-	0001,0201,0201,0001,0201,0001,0001,0201,
-	0200,0000,0000,0200,0000,0200,0200,0000,
-	0000,0200,0200,0000,0200,0000,0000,0200,
-	0000,0200,0200,0000,0200,0000,0000,0200,
-	0200,0000,0000,0200,0000,0200,0200,0000,
-	0200,0000,0000,0200,0000,0200,0200,0000,
-	0000,0200,0200,0000,0200,0000,0000,0200,
-	0000,0200,0200,0000,0200,0000,0000,0200,
-	0200,0000,0000,0200,0000,0200,0200,0000,
-	0000,0200,0200,0000,0200,0000,0000,0200,
-	0200,0000,0000,0200,0000,0200,0200,0000,
-	0200,0000,0000,0200,0000,0200,0200,0000,
-	0000,0200,0200,0000,0200,0000,0000,0201
-};
-
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -178 +163,2 @@
-getname()
+int
+getname(void)
@@ -181 +167 @@
-	register c;
+	register int c;
@@ -195 +181 @@
-		if (c=='\r' || c=='\n' || np >= &name[16])
+		if (c=='\r' || c=='\n' || np >= &name[15])
@@ -222,2 +208,2 @@
-puts(as)
-char *as;
+void
+puts(char *as)
@@ -232 +218,2 @@
-putchr(cc)
+void
+putchr(int cc)
@@ -236 +222,0 @@
-	c |= partab[c&0177] & 0200;

% usr/src/cmd/graph.c
@@ -11 +11 @@
-	double (*xf)();	/*transform function, e.g. log*/
+	double (*xf)(double x);	/*transform function, e.g. log*/
@@ -43 +43,12 @@
-double	atof();
+int	numb(float *np, int *argcp, char ***argvp), copystring(int k);
+int	setmark(int *xmark, struct xy *p), conv(float xv, struct xy *p, int *ip);
+int	getfloat(float *p), getstring(void), symbol(int ix, int iy, int k);
+void	init(struct xy *p), setopt(int argc, char *argv[]);
+void	limread(struct xy *p, int *argcp, char ***argvp), readin(void);
+void	transpose(void), scale(struct xy *p, struct val *v), axes(void);
+void	submark(int *xmark, int *pxn, float x, struct xy *p), plot(void);
+void	title(void), axlab(char c, struct xy *p), badarg(void);
+void	space(int x0, int y0, int x1, int y1), erase(void);
+void	move(int xi, int yi), cont(int xi, int yi);
+void	line(int x0, int y0, int x1, int y1), point(int xi, int yi);
+void	label(char *s), linemod(char *s), closevt(void);
@@ -57,2 +67,0 @@
-char *realloc();
-char *malloc();
@@ -60,2 +69 @@
-double ident(x)
-double x;
+static double ident(double x)
@@ -66,2 +74,2 @@
-main(argc,argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -92,2 +100,2 @@
-init(p)
-struct xy *p;
+void
+init(struct xy *p)
@@ -99,2 +107,2 @@
-setopt(argc,argv)
-char *argv[];
+void
+setopt(int argc, char *argv[])
@@ -119 +127 @@
-				while (*p1++ = *p2++);
+				while ((*p1++ = *p2++));
@@ -198,4 +206,2 @@
-limread(p, argcp, argvp)
-register struct xy *p;
-int *argcp;
-char ***argvp;
+void
+limread(register struct xy *p, int *argcp, char ***argvp)
@@ -219,4 +225,2 @@
-numb(np, argcp, argvp)
-int *argcp;
-float *np;
-register char ***argvp;
+int
+numb(float *np, int *argcp, register char ***argvp)
@@ -230 +234 @@
-	if(!(isdigit(c) || c=='-'&&(*argvp)[1][1]<'A' || c=='.'))
+	if(!(isdigit(c&0377) || (c=='-'&&(*argvp)[1][1]<'A') || c=='.'))
@@ -238 +242,2 @@
-readin()
+void
+readin(void)
@@ -240 +245 @@
-	register t;
+	register int t;
@@ -272 +277,2 @@
-transpose()
+void
+transpose(void)
@@ -274 +280 @@
-	register i;
+	register int i;
@@ -285 +291,2 @@
-copystring(k)
+int
+copystring(int k)
@@ -288 +295 @@
-	register i;
+	register int i;
@@ -301,3 +308,2 @@
-float
-modceil(f,t)
-float f,t;
+static float
+modceil(float f, float t)
@@ -310,3 +316,2 @@
-float
-modfloor(f,t)
-float f,t;
+static float
+modfloor(float f, float t)
@@ -318,3 +323,2 @@
-getlim(p,v)
-register struct xy *p;
-struct val *v;
+static void
+getlim(register struct xy *p, struct val *v)
@@ -322 +326 @@
-	register i;
+	register int i;
@@ -336 +340,2 @@
-} setloglim(), setlinlim();
+} setloglim(int lbf, int ubf, float lb, float ub),
+	setlinlim(int lbf, int ubf, float xlb, float xub);
@@ -338,2 +343,2 @@
-setlim(p)
-register struct xy *p;
+static void
+setlim(register struct xy *p)
@@ -407,2 +412 @@
-setloglim(lbf,ubf,lb,ub)
-float lb,ub;
+setloglim(int lbf, int ubf, float lb, float ub)
@@ -440,3 +444 @@
-setlinlim(lbf,ubf,xlb,xub)
-int lbf,ubf;
-float xlb,xub;
+setlinlim(int lbf, int ubf, float xlb, float xub)
@@ -482,3 +484,2 @@
-scale(p,v)
-register struct xy *p;
-struct val *v;
+void
+scale(register struct xy *p, struct val *v)
@@ -497 +498,2 @@
-axes()
+void
+axes(void)
@@ -499 +501 @@
-	register i;
+	register int i;
@@ -530,3 +532,2 @@
-setmark(xmark,p)
-int *xmark;
-register struct xy *p;
+int
+setmark(int *xmark, register struct xy *p)
@@ -560,5 +561,2 @@
-submark(xmark,pxn,x,p)
-int *xmark;
-int *pxn;
-float x;
-struct xy *p;
+void
+submark(int *xmark, int *pxn, float x, struct xy *p)
@@ -570 +568,2 @@
-plot()
+void
+plot(void)
@@ -597,4 +596,2 @@
-conv(xv,p,ip)
-float xv;
-register struct xy *p;
-int *ip;
+int
+conv(float xv, register struct xy *p, int *ip)
@@ -610,2 +607,2 @@
-getfloat(p)
-float *p;
+int
+getfloat(float *p)
@@ -613 +610 @@
-	register i;
+	register int i;
@@ -619 +616,2 @@
-getstring()
+int
+getstring(void)
@@ -621 +619 @@
-	register i;
+	register int i;
@@ -628 +626 @@
-		if(!isdigit(*labbuf)) {
+		if(!isdigit(*labbuf&0377)) {
@@ -632,0 +631 @@
+		/* fallthrough */
@@ -649 +648,2 @@
-symbol(ix,iy,k)
+int
+symbol(int ix, int iy, int k)
@@ -661 +661 @@
-		return(!brkf|k<0);
+		return(!brkf|(k<0));
@@ -665 +665,2 @@
-title()
+void
+title(void)
@@ -679,3 +680,2 @@
-axlab(c,p)
-char c;
-struct xy *p;
+void
+axlab(char c, struct xy *p)
@@ -689 +689,2 @@
-badarg()
+void
+badarg(void)
@@ -692,0 +694,63 @@
+}
+static void
+putsi(int a){
+	putc((char)a,stdout);
+	putc((char)(a>>8),stdout);
+}
+void
+space(int x0, int y0, int x1, int y1){
+	putc('s',stdout);
+	putsi(x0);
+	putsi(y0);
+	putsi(x1);
+	putsi(y1);
+}
+void
+erase(void){
+	putc('e',stdout);
+}
+void
+move(int xi, int yi){
+	putc('m',stdout);
+	putsi(xi);
+	putsi(yi);
+}
+void
+cont(int xi, int yi){
+	putc('n',stdout);
+	putsi(xi);
+	putsi(yi);
+}
+void
+line(int x0, int y0, int x1, int y1){
+	putc('l',stdout);
+	putsi(x0);
+	putsi(y0);
+	putsi(x1);
+	putsi(y1);
+}
+void
+point(int xi, int yi){
+	putc('p',stdout);
+	putsi(xi);
+	putsi(yi);
+}
+void
+label(char *s)
+{
+	int i;
+	putc('t',stdout);
+	for(i=0;s[i];)putc(s[i++],stdout);
+	putc('\n',stdout);
+}
+void
+linemod(char *s)
+{
+	int i;
+	putc('f',stdout);
+	for(i=0;s[i];)putc(s[i++],stdout);
+	putc('\n',stdout);
+}
+void
+closevt(void){
+	fflush(stdout);

% usr/src/cmd/grep.c
@@ -59,2 +59,5 @@
-main(argc, argv)
-char **argv;
+void	compile(char *astr), execute(char *file), succeed(char *f);
+void	errexit(char *s, char *f);
+int	advance(char *lp, char *ep), ecmp(char *a, char *b, int count);
+int
+main(int argc, char **argv)
@@ -119 +122 @@
-			} else if (islower(*p)) {
+			} else if (islower(*p&0377)) {
@@ -145,2 +148,2 @@
-compile(astr)
-char *astr;
+void
+compile(char *astr)
@@ -148 +151 @@
-	register c;
+	register int c;
@@ -208 +211 @@
-					for (c = sp[-2]; c<*sp; c++)
+					for (c = sp[-2]&0177; c<(*sp&0177); c++)
@@ -212 +215 @@
-				ep[c>>3] |= bittab[c&07];
+				ep[(c&0177)>>3] |= bittab[c&07];
@@ -250,0 +254 @@
+			goto defchar;
@@ -262,2 +266,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -266 +270 @@
-	register c;
+	register int c;
@@ -324,2 +328,2 @@
-advance(lp, ep)
-register char *lp, *ep;
+int
+advance(register char *lp, register char *ep)
@@ -360 +364 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -364 +368 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -368,2 +372,2 @@
-		bbeg = braslist[*ep];
-		if (braelist[*ep]==0)
+		bbeg = braslist[*ep&0377];
+		if (braelist[*ep&0377]==0)
@@ -371 +375 @@
-		ct = braelist[*ep++] - bbeg;
+		ct = braelist[*ep++&0377] - bbeg;
@@ -379,2 +383,2 @@
-		bbeg = braslist[*ep];
-		if (braelist[*ep]==0)
+		bbeg = braslist[*ep&0377];
+		if (braelist[*ep&0377]==0)
@@ -382 +386 @@
-		ct = braelist[*ep++] - bbeg;
+		ct = braelist[*ep++&0377] - bbeg;
@@ -439,2 +443,2 @@
-succeed(f)
-char *f;
+void
+succeed(char *f)
@@ -442 +445,0 @@
-	long ftell();
@@ -464,2 +467,2 @@
-ecmp(a, b, count)
-char	*a, *b;
+int
+ecmp(char *a, char *b, int count)
@@ -467 +470 @@
-	register cc = count;
+	register int cc = count;
@@ -473,2 +476,2 @@
-errexit(s, f)
-char *s, *f;
+void
+errexit(char *s, char *f)

% usr/src/cmd/icheck.c
@@ -41,5 +41,5 @@
-long	atol();
-daddr_t	alloc();
-#ifndef STANDALONE
-char	*malloc();
-#endif
+daddr_t	alloc(void);
+int	chk(daddr_t bno, char *s), duped(daddr_t bno);
+void	check(char *file), pass1(struct dinode *ip);
+void	bread(daddr_t bno, char *buf, int cnt), bwrite(daddr_t bno, char *buf);
+void	makefree(void);
@@ -47,2 +47,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -50 +50 @@
-	register i;
+	register int i;
@@ -101,2 +101,2 @@
-check(file)
-char *file;
+void
+check(char *file)
@@ -104 +104 @@
-	register i, j;
+	register int i, j;
@@ -134 +134 @@
-	if (n != (unsigned)n) {
+	if (n != (long)(unsigned)n) {
@@ -149 +149 @@
-	for(i=0; i<(unsigned)n; i++)
+	for(i=0; i<n; i++)
@@ -177 +177 @@
-	while(n = alloc()) {
+	while((n = alloc())) {
@@ -218,2 +218,2 @@
-pass1(ip)
-register struct dinode *ip;
+void
+pass1(register struct dinode *ip)
@@ -224 +224 @@
-	register i, j;
+	register int i, j;
@@ -261 +261 @@
-		for(j=0; j<NINDIR; j++) {
+		for(j=0; j<(int)NINDIR; j++) {
@@ -273 +273 @@
-			for(k=0; k<NINDIR; k++) {
+			for(k=0; k<(int)NINDIR; k++) {
@@ -285 +285 @@
-				for(l=0; l<NINDIR; l++)
+				for(l=0; l<(int)NINDIR; l++)
@@ -295,3 +295,2 @@
-chk(bno, s)
-daddr_t bno;
-char *s;
+int
+chk(daddr_t bno, char *s)
@@ -299 +298 @@
-	register n;
+	register int n;
@@ -315,2 +314,2 @@
-duped(bno)
-daddr_t bno;
+int
+duped(daddr_t bno)
@@ -319 +318 @@
-	register m, n;
+	register int m, n;
@@ -333 +332 @@
-alloc()
+alloc(void)
@@ -355 +354 @@
-		sblock.s_nfree = buf.df_nfree;
+		sblock.s_nfree = buf.fb.df_nfree;
@@ -363 +362 @@
-			sblock.s_free[i] = buf.df_free[i];
+			sblock.s_free[i] = buf.fb.df_free[i];
@@ -368,2 +367,2 @@
-bfree(bno)
-daddr_t bno;
+static void
+bfree(daddr_t bno)
@@ -381 +380 @@
-		buf.df_nfree = sblock.s_nfree;
+		buf.fb.df_nfree = sblock.s_nfree;
@@ -383 +382 @@
-			buf.df_free[i] = sblock.s_free[i];
+			buf.fb.df_free[i] = sblock.s_free[i];
@@ -391,3 +390,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+void
+bread(daddr_t bno, char *buf, int cnt)
@@ -395 +393 @@
-	register i;
+	register int i;
@@ -409,3 +407,2 @@
-bwrite(bno, buf)
-daddr_t bno;
-char	*buf;
+void
+bwrite(daddr_t bno, char *buf)
@@ -419 +416,2 @@
-makefree()
+void
+makefree(void)
@@ -423 +421 @@
-	register i, j;
+	register int i, j;

% usr/src/cmd/init.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -36,0 +38,3 @@
+void	shutdown(void), single(void), runcom(void), merge(int sig), multiple(void);
+void	term(struct tab *p), maktty(char *lin), dfork(struct tab *p), rmut(struct tab *p), reset(int sig);
+int	rline(void), get(void);
@@ -38 +42,2 @@
-main()
+int
+main(void)
@@ -40 +44,0 @@
-	int reset();
@@ -48 +52 @@
-		merge();
+		merge(0);
@@ -53 +57,2 @@
-shutdown()
+void
+shutdown(void)
@@ -55 +60 @@
-	register i;
+	register int i;
@@ -73 +78,2 @@
-single()
+void
+single(void)
@@ -75 +81 @@
-	register pid;
+	register int pid;
@@ -95 +101,2 @@
-runcom()
+void
+runcom(void)
@@ -97 +104 @@
-	register pid;
+	register int pid;
@@ -111 +118,2 @@
-multiple()
+void
+multiple(void)
@@ -114 +122 @@
-	register pid;
+	register int pid;
@@ -128,2 +136,2 @@
-term(p)
-register struct tab *p;
+void
+term(register struct tab *p)
@@ -140 +148,2 @@
-rline()
+int
+rline(void)
@@ -142 +151 @@
-	register c, i;
+	register int c, i;
@@ -174,2 +183,2 @@
-maktty(lin)
-char *lin;
+void
+maktty(char *lin)
@@ -177 +186 @@
-	register i, j;
+	register int i, j;
@@ -188 +197,2 @@
-get()
+int
+get(void)
@@ -199 +209,2 @@
-merge()
+void
+merge(int sig)
@@ -202 +213,2 @@
-	register i;
+	register int i;
+	(void)sig;
@@ -243,2 +255,2 @@
-dfork(p)
-struct tab *p;
+void
+dfork(struct tab *p)
@@ -246 +258 @@
-	register pid;
+	register int pid;
@@ -266,2 +278,2 @@
-rmut(p)
-register struct tab *p;
+void
+rmut(register struct tab *p)
@@ -269 +281 @@
-	register i, f;
+	register int i, f;
@@ -299 +311,2 @@
-reset()
+void
+reset(int sig)
@@ -300,0 +314 @@
+	(void)sig;

% usr/src/cmd/iostat.c
@@ -0,0 +1,2 @@
+#include <stdio.h>
+#include <a.out.h>
@@ -13,3 +15,8 @@
-	"_dk_busy", 0, 0,
-	"_io_info", 0, 0,
-	"\0\0\0\0\0\0\0\0", 0, 0
+	{"_dk_busy", 0, 0},
+	{"_io_info", 0, 0},
+	{"_dk_time", 0, 0},
+	{"_dk_numb", 0, 0},
+	{"_dk_wds",  0, 0},
+	{"_tk_nin",  0, 0},
+	{"_tk_nout", 0, 0},
+	{"\0\0\0\0\0\0\0\0", 0, 0}
@@ -39,2 +46,3 @@
-main(argc, argv)
-char *argv[];
+void stats(int dn), stat1(int o), stats2(double t), stats3(double t), biostats(void);
+int
+main(int argc, char *argv[])
@@ -42,2 +50 @@
-	extern char *ctime();
-	register  i;
+	register  int i;
@@ -48,2 +55,2 @@
-	nlist("/unix", nl);
-	if(nl[0].type == -1) {
+	nlist("/unix", (struct nlist *)nl);
+	if(nl[0].type == 0) {
@@ -90,2 +97,12 @@
-	read(mf, (char *)&s, sizeof s);
-	for(i=0; i<40; i++) {
+	read(mf, (char *)&s.busy, sizeof(s.busy));
+	lseek(mf, (long)nl[2].value, 0);
+	read(mf, (char *)s.etime, sizeof(s.etime));
+	lseek(mf, (long)nl[3].value, 0);
+	read(mf, (char *)s.numb, sizeof(s.numb));
+	lseek(mf, (long)nl[4].value, 0);
+	read(mf, (char *)s.wds, sizeof(s.wds));
+	lseek(mf, (long)nl[5].value, 0);
+	read(mf, (char *)&s.tin, sizeof(s.tin));
+	lseek(mf, (long)nl[6].value, 0);
+	read(mf, (char *)&s.tout, sizeof(s.tout));
+	for(i=0; i<32; i++) {
@@ -95,0 +113,14 @@
+	for(i=0; i<3; i++) {
+		t = s.numb[i];
+		s.numb[i] -= s1.numb[i];
+		s1.numb[i] = t;
+		t = s.wds[i];
+		s.wds[i] -= s1.wds[i];
+		s1.wds[i] = t;
+	}
+	t = s.tin;
+	s.tin -= s1.tin;
+	s1.tin = t;
+	t = s.tout;
+	s.tout -= s1.tout;
+	s1.tout = t;
@@ -149 +180,2 @@
-stats(dn)
+void
+stats(int dn)
@@ -151 +183 @@
-	register i;
+	register int i;
@@ -178 +210,2 @@
-stat1(o)
+void
+stat1(int o)
@@ -180 +213 @@
-	register i;
+	register int i;
@@ -197,2 +230,2 @@
-stats2(t)
-double t;
+void
+stats2(double t)
@@ -200 +233 @@
-	register i, j;
+	register int i, j;
@@ -209,2 +242,2 @@
-stats3(t)
-double t;
+void
+stats3(double t)
@@ -212 +245 @@
-	register i;
+	register int i;
@@ -254 +287,2 @@
-biostats()
+void
+biostats(void)
@@ -256 +290 @@
-register i;
+register int i;

% usr/src/cmd/join.c
@@ -25,2 +25,4 @@
-main(argc, argv)
-char *argv[];
+int input(int n), cmp(char *s1, char *s2);
+void output(int on1, int on2), error(char *s1, char *s2);
+int
+main(int argc, char *argv[])
@@ -30,2 +32 @@
-	long top2, bot2;
-	long ftell();
+	long top2 = 0, bot2;
@@ -88 +89 @@
-		error("usage: join [-j1 x -j2 y] [-o list] file1 file2");
+		error("usage: join [-j1 x -j2 y] [-o list] file1 file2", "");
@@ -105,2 +106,2 @@
-	while(n1>0 && n2>0 || aflg!=0 && n1+n2>0) {
-		if(n1>0 && n2>0 && comp()>0 || n1==0) {
+	while((n1>0 && n2>0) || (aflg!=0 && n1+n2>0)) {
+		if((n1>0 && n2>0 && comp()>0) || n1==0) {
@@ -110 +111 @@
-		} else if(n1>0 && n2>0 && comp()<0 || n2==0) {
+		} else if((n1>0 && n2>0 && comp()<0) || n2==0) {
@@ -126 +127 @@
-				} else if(n1>0 && n2>0 && comp()<0 || n2==0) {
+				} else if((n1>0 && n2>0 && comp()<0) || n2==0) {
@@ -142 +143,2 @@
-input(n)		/* get input line and split into fields */
+int
+input(int n)		/* get input line and split into fields */
@@ -170,2 +172,2 @@
-output(on1, on2)	/* print items from olist */
-int on1, on2;
+void
+output(int on1, int on2)	/* print items from olist */
@@ -188,2 +190,2 @@
-			if(olistf[i]==F1 && on1<=olist[i] ||
-			   olistf[i]==F2 && on2<=olist[i] ||
+			if((olistf[i]==F1 && on1<=olist[i]) ||
+			   (olistf[i]==F2 && on2<=olist[i]) ||
@@ -201,2 +203,2 @@
-error(s1, s2, s3, s4, s5)
-char *s1;
+void
+error(char *s1, char *s2)
@@ -205 +207 @@
-	fprintf(stderr, s1, s2, s3, s4, s5);
+	fprintf(stderr, s1, s2);
@@ -210,2 +212,2 @@
-cmp(s1, s2)
-char *s1, *s2;
+int
+cmp(char *s1, char *s2)

% usr/src/cmd/kill.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -7,2 +8,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -10 +11 @@
-	register signo, pid, res;
+	register int signo, pid, res;
@@ -13 +14 @@
-	extern errno;
+	extern int errno;

% usr/src/cmd/ln.c
@@ -8 +7,0 @@
-char	*rindex();
@@ -10,2 +9,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)

% usr/src/cmd/login.c
@@ -15 +15 @@
-struct	passwd nouser = {"", "nope"};
+struct	passwd nouser = {"", "nope", 0, 0, 0, 0, 0, 0, 0};
@@ -23,7 +23 @@
-struct	passwd *getpwnam();
-char	*strcat();
-int	setpwent();
-char	*ttyname();
-char	*crypt();
-char	*getpass();
-char	*rindex(), *index();
+void	showmotd(void);
@@ -32,2 +26,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -131 +125,2 @@
-catch()
+static void
+catch(int sig)
@@ -132,0 +128 @@
+	(void)sig;
@@ -137 +133,2 @@
-showmotd()
+void
+showmotd(void)
@@ -140 +137 @@
-	register c;
+	register int c;

% usr/src/cmd/look.c
@@ -14,2 +14,4 @@
-main(argc,argv)
-char **argv;
+void canon(char *old, char *new);
+int compare(char *s, char *t), getword(char *w);
+int
+main(int argc, char **argv)
@@ -17 +19 @@
-	register c;
+	register int c;
@@ -44 +46 @@
-		return;
+		return(0);
@@ -87 +89 @@
-			return;
+			return(0);
@@ -91 +93 @@
-			return;
+			return(0);
@@ -94 +96 @@
-			puts(entry,stdout);
+			puts(entry);
@@ -107 +109 @@
-			puts(entry,stdout);
+			puts(entry);
@@ -114,2 +116,2 @@
-compare(s,t)
-register char *s,*t;
+int
+compare(register char *s, register char *t)
@@ -126,2 +128,2 @@
-getword(w)
-char *w;
+int
+getword(char *w)
@@ -129 +131 @@
-	register c;
+	register int c;
@@ -142,2 +144,2 @@
-canon(old,new)
-char *old,*new;
+void
+canon(char *old, char *new)
@@ -145 +147 @@
-	register c;
+	register int c;

% usr/src/cmd/ls.c
@@ -42,4 +42,6 @@
-char	*makename();
-struct	lbuf *gstat();
-char	*ctime();
-long	nblock();
+char	*makename(char *dir, char *file);
+struct	lbuf *gstat(char *file, int argfl);
+long	nblock(long size);
+void	pentry(struct lbuf *ap);
+int	getname(int uid, char buf[]), compar(char *pp1, char *pp2);
+void	pmode(int aflag), select(int *pairp), readdir(char *dir);
@@ -49,2 +51,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -58 +59,0 @@
-	int compar();
@@ -142 +143 @@
-	qsort(firstp, lastp - firstp, sizeof *lastp, compar);
+	qsort((char *)firstp, lastp - firstp, sizeof *lastp, compar);
@@ -146 +147 @@
-		if (ep->ltype=='d' && dflg==0 || fflg) {
+		if ((ep->ltype=='d' && dflg==0) || fflg) {
@@ -152 +153 @@
-				qsort(slastp,lastp - slastp,sizeof *lastp,compar);
+				qsort((char *)slastp,lastp - slastp,sizeof *lastp,compar);
@@ -163,2 +164,2 @@
-pentry(ap)
-struct lbuf *ap;
+void
+pentry(struct lbuf *ap)
@@ -166,2 +167 @@
-	struct { char dminor, dmajor;};
-	register t;
+	register int t;
@@ -204,3 +204,2 @@
-getname(uid, buf)
-int uid;
-char buf[];
+int
+getname(int uid, char buf[])
@@ -239,2 +238 @@
-nblock(size)
-long size;
+nblock(long size)
@@ -257 +255,2 @@
-pmode(aflag)
+void
+pmode(int aflag)
@@ -266,2 +265,2 @@
-select(pairp)
-register int *pairp;
+void
+select(register int *pairp)
@@ -278,2 +277 @@
-makename(dir, file)
-char *dir, *file;
+makename(char *dir, char *file)
@@ -297,2 +295,2 @@
-readdir(dir)
-char *dir;
+void
+readdir(char *dir)
@@ -313,2 +311,2 @@
-		 || aflg==0 && dentry.d_name[0]=='.' &&  (dentry.d_name[1]=='\0'
-			|| dentry.d_name[1]=='.' && dentry.d_name[2]=='\0'))
+		 || (aflg==0 && dentry.d_name[0]=='.' && (dentry.d_name[1]=='\0'
+			|| (dentry.d_name[1]=='.' && dentry.d_name[2]=='\0'))))
@@ -328,2 +326 @@
-gstat(file, argfl)
-char *file;
+gstat(char *file, int argfl)
@@ -331 +327,0 @@
-	extern char *malloc();
@@ -400,2 +396,2 @@
-compar(pp1, pp2)
-struct lbuf **pp1, **pp2;
+int
+compar(char *pp1, char *pp2)
@@ -405,2 +401,2 @@
-	p1 = *pp1;
-	p2 = *pp2;
+	p1 = *(struct lbuf **)pp1;
+	p2 = *(struct lbuf **)pp2;

% usr/src/cmd/makekey.c
@@ -8 +8 @@
-char	*crypt();
+#include <stdio.h>
@@ -10 +10,2 @@
-main()
+int
+main(void)

% usr/src/cmd/mesg.c
@@ -17 +16,0 @@
-char *ttyname();
@@ -19,2 +18,3 @@
-main(argc, argv)
-char *argv[];
+void error(char *s), newmode(int m);
+int
+main(int argc, char *argv[])
@@ -44,2 +44,2 @@
-error(s)
-char *s;
+void
+error(char *s)
@@ -51 +51,2 @@
-newmode(m)
+void
+newmode(int m)

% usr/src/cmd/mkdir.c
@@ -9,2 +8,0 @@
-char	*strcat();
-char	*strcpy();
@@ -12,2 +10,3 @@
-main(argc, argv)
-char *argv[];
+void mkdir(char *d);
+int
+main(int argc, char *argv[])
@@ -31,2 +30,2 @@
-mkdir(d)
-char *d;
+void
+mkdir(char *d)
@@ -34,2 +33,2 @@
-	char pname[128], dname[128];
-	register i, slash = 0;
+	char pname[strlen(d)+2], dname[strlen(d)+4];
+	register int i, slash = 0;
@@ -66 +65 @@
-		dname[strlen(dname)] = '\0';
+		dname[strlen(dname)-1] = '\0';

% usr/src/cmd/mkfs.c
@@ -8,0 +9 @@
+#define	MAXFILEBLK	(LADDR+NINDIR+(NINDIR*NINDIR))
@@ -13 +14,4 @@
-#include <a.out.h>
+#include <stdlib.h>
+#include <unistd.h>
+#include <fcntl.h>
+#include <time.h>
@@ -20,0 +25,10 @@
+static void
+ltol3(char *cp, long *lp, int n)
+{
+	int i;
+	long v;
+	for(i=0; i<n; i++) {
+		v = lp[i];
+		*cp++ = v; *cp++ = v >> 8; *cp++ = v >> 16;
+	}
+}
@@ -35,3 +49 @@
-#ifndef STANDALONE
-struct exec head;
-#endif
+#define fbuf fbuf.fb
@@ -42,0 +55 @@
+#define filsys filsys.fs
@@ -49,2 +62,8 @@
-long	getnum();
-daddr_t	alloc();
+long	getnum(void);
+daddr_t	alloc(void);
+void	cfile(struct inode *par), getstr(void), wtfs(daddr_t bno, char *bf);
+void	entry(ino_t inum, char *str, int *adbc, char *db, int *aibc, daddr_t *ib);
+void	newblk(int *adbc, char *db, int *aibc, daddr_t *ib), bflist(void);
+void	iput(struct inode *ip, int *aibc, daddr_t *ib);
+int	gmode(char c, char *s, int m0, int m1, int m2, int m3);
+int	getch(void), badblk(daddr_t bno);
@@ -52,2 +71,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -59 +78,4 @@
-	time(&utime);
+	if ((fsys = getenv("V7_MKFS_TIME")) != NULL)
+		utime = atol(fsys);
+	else
+		time(&utime);
@@ -103 +125 @@
-		for(f=0; c=proto[f]; f++) {
+		for(f=0; (c=proto[f]); f++) {
@@ -114 +136 @@
-		if(n > 65500/NIPB)
+		if((unsigned)n > 65500/NIPB)
@@ -117 +139 @@
-		printf("isize = %D\n", n*NIPB);
+		printf("isize = %ld\n", n*NIPB);
@@ -125 +146,0 @@
-	 * and read onto block 0
@@ -130 +151 @@
-	if(f < 0) {
+	if(f < 0)
@@ -132,14 +153 @@
-		goto f2;
-	}
-	read(f, (char *)&head, sizeof head);
-	if(head.a_magic != A_MAGIC1) {
-		printf("%s: bad format\n", string);
-		goto f1;
-	}
-	c = head.a_text + head.a_data;
-	if(c > BSIZE) {
-		printf("%s: too big\n", string);
-		goto f1;
-	}
-	read(f, buf, c);
-	wtfs((long)0, buf);
+	else
@@ -147 +154,0 @@
-f1:
@@ -155 +161,0 @@
-f2:
@@ -175 +181 @@
-		printf("%ld/%ld: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
+		printf("%ld/%d: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
@@ -197,2 +203,2 @@
-cfile(par)
-struct inode *par;
+void
+cfile(struct inode *par)
@@ -203 +209 @@
-	daddr_t ib[NINDIR];
+	daddr_t ib[MAXFILEBLK];
@@ -235 +241 @@
-	for(i=0; i<NINDIR; i++)
+	for(i=0; (unsigned)i<MAXFILEBLK; i++)
@@ -309,2 +315,2 @@
-gmode(c, s, m0, m1, m2, m3)
-char c, *s;
+int
+gmode(char c, char *s, int m0, int m1, int m2, int m3)
@@ -312,0 +319 @@
+	int m[4] = {m0, m1, m2, m3};
@@ -316 +323 @@
-			return((&m0)[i]);
+			return(m[i]);
@@ -323 +330 @@
-getnum()
+getnum(void)
@@ -331 +338 @@
-	for(i=0; c=string[i]; i++) {
+	for(i=0; (c=string[i]); i++) {
@@ -342 +349,2 @@
-getstr()
+void
+getstr(void)
@@ -372,3 +380,2 @@
-rdfs(bno, bf)
-daddr_t bno;
-char *bf;
+static void
+rdfs(daddr_t bno, char *bf)
@@ -386,3 +393,2 @@
-wtfs(bno, bf)
-daddr_t bno;
-char *bf;
+void
+wtfs(daddr_t bno, char *bf)
@@ -395 +401 @@
-		printf("write error: %D\n", bno);
+		printf("write error: %ld\n", bno);
@@ -401 +407 @@
-alloc()
+alloc(void)
@@ -421,2 +427,2 @@
-bfree(bno)
-daddr_t bno;
+static void
+bfree(daddr_t bno)
@@ -437,6 +443,2 @@
-entry(inum, str, adbc, db, aibc, ib)
-ino_t inum;
-char *str;
-int *adbc, *aibc;
-char *db;
-daddr_t *ib;
+void
+entry(ino_t inum, char *str, int *adbc, char *db, int *aibc, daddr_t *ib)
@@ -456 +458 @@
-	if(*adbc >= NDIRECT)
+	if((unsigned)*adbc >= NDIRECT)
@@ -460,4 +462,2 @@
-newblk(adbc, db, aibc, ib)
-int *adbc, *aibc;
-char *db;
-daddr_t *ib;
+void
+newblk(int *adbc, char *db, int *aibc, daddr_t *ib)
@@ -475 +475 @@
-	if(*aibc >= NINDIR) {
+	if((unsigned)*aibc >= MAXFILEBLK) {
@@ -482 +482,2 @@
-getch()
+int
+getch(void)
@@ -494 +495,2 @@
-bflist()
+void
+bflist(void)
@@ -525 +527 @@
-	for(i=0; i<NINDIR; i++)
+	for(i=0; (unsigned)i<NINDIR; i++)
@@ -535 +537 @@
-		if(f < filsys.s_fsize && f >= filsys.s_isize)
+		if(f < filsys.s_fsize && f >= filsys.s_isize) {
@@ -537 +539 @@
-				if(ibc >= NINDIR) {
+				if((unsigned)ibc >= NINDIR) {
@@ -545,0 +548 @@
+		}
@@ -550,4 +553,2 @@
-iput(ip, aibc, ib)
-struct inode *ip;
-int *aibc;
-daddr_t *ib;
+void
+iput(struct inode *ip, int *aibc, daddr_t *ib)
@@ -556 +557 @@
-	daddr_t d;
+	daddr_t d, dbl[NINDIR];
@@ -591,3 +592,10 @@
-			for(i=0; i<NINDIR-LADDR; i++) {
-				ib[i] = ib[i+LADDR];
-				ib[i+LADDR] = (daddr_t)0;
+			wtfs(ip->i_un.i_addr[LADDR], (char *)&ib[LADDR]);
+		}
+		if((unsigned)*aibc > LADDR+NINDIR) {
+			ip->i_un.i_addr[LADDR+1] = alloc();
+			for(i=0; (unsigned)i<NINDIR; i++) {
+				dbl[i] = 0;
+				if((unsigned)*aibc > LADDR+NINDIR+i*NINDIR) {
+					dbl[i] = alloc();
+					wtfs(dbl[i], (char *)&ib[LADDR+NINDIR+i*NINDIR]);
+				}
@@ -595 +603 @@
-			wtfs(ip->i_un.i_addr[LADDR], (char *)ib);
+			wtfs(ip->i_un.i_addr[LADDR+1], (char *)dbl);
@@ -596,0 +605 @@
+		/* fallthrough */
@@ -610,2 +619,2 @@
-badblk(bno)
-daddr_t bno;
+int
+badblk(daddr_t bno)
@@ -613,0 +623 @@
+	(void)bno;

% usr/src/cmd/mknod.c
@@ -1,3 +1,4 @@
-main(argc, argv)
-int argc;
-char **argv;
+#include <stdio.h>
+int number(char *s);
+int
+main(int argc, char **argv)
@@ -30,2 +31,2 @@
-number(s)
-char *s;
+int
+number(char *s)
@@ -36 +37 @@
-	while(c = *s++) {
+	while((c = *s++)) {

% usr/src/cmd/mount.c
@@ -11,2 +11,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)

% usr/src/cmd/mv.c
@@ -19,3 +19,4 @@
-char	*pname();
-char	*sprintf();
-char	*dname();
+char	*pname(char *name);
+char	*dname(char *name);
+int	move(char *source, char *target), mvdir(char *source, char *target);
+int	check(char *spth, ino_t dinode), chkdot(char *s);
@@ -24,2 +25,2 @@
-main(argc, argv)
-register char *argv[];
+int
+main(int argc, register char *argv[])
@@ -27 +28 @@
-	register i, r;
+	register int i, r;
@@ -53,2 +54,2 @@
-move(source, target)
-char *source, *target;
+int
+move(char *source, char *target)
@@ -56 +57 @@
-	register c, i;
+	register int c, i;
@@ -122,2 +123,2 @@
-mvdir(source, target)
-char *source, *target;
+int
+mvdir(char *source, char *target)
@@ -126 +127 @@
-	register i;
+	register int i;
@@ -229,2 +230 @@
-pname(name)
-register char *name;
+pname(register char *name)
@@ -232 +232 @@
-	register c;
+	register int c;
@@ -237 +237 @@
-	while (c = *p++ = *name++)
+	while ((c = *p++ = *name++))
@@ -247,2 +247 @@
-dname(name)
-register char *name;
+dname(register char *name)
@@ -259,3 +258,2 @@
-check(spth, dinode)
-char *spth;
-ino_t dinode;
+int
+check(char *spth, ino_t dinode)
@@ -278 +276 @@
-		if (strlen(nspth) > MAXN-2-sizeof(DOTDOT)) {
+		if (strlen(nspth) > MAXN-2-(int)sizeof(DOTDOT)) {
@@ -288,2 +286,2 @@
-chkdot(s)
-register char *s;
+int
+chkdot(register char *s)

% usr/src/cmd/ncheck.c
@@ -37,3 +37,6 @@
-daddr_t	bmap();
-long	atol();
-struct htab *lookup();
+daddr_t	bmap(int i);
+struct htab *lookup(ino_t i, int ef);
+void	check(char *file), pass1(struct dinode *ip), pass2(struct dinode *ip);
+void	pass3(struct dinode *ip), pname(ino_t i, int lev);
+void	bread(daddr_t bno, char *buf, int cnt);
+int	dotname(struct direct *dp);
@@ -41,2 +44,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -44 +47 @@
-	register i;
+	register int i;
@@ -81,2 +84,2 @@
-check(file)
-char *file;
+void
+check(char *file)
@@ -84 +87 @@
-	register i, j;
+	register int i, j;
@@ -137,2 +140,2 @@
-pass1(ip)
-register struct dinode *ip;
+void
+pass1(register struct dinode *ip)
@@ -146 +149 @@
-			return;
+		return;
@@ -151,2 +154,2 @@
-pass2(ip)
-register struct dinode *ip;
+void
+pass2(register struct dinode *ip)
@@ -157 +160 @@
-	register i, j;
+	register int i, j;
@@ -174 +177 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -194,2 +197,2 @@
-pass3(ip)
-register struct dinode *ip;
+void
+pass3(register struct dinode *ip)
@@ -200 +203 @@
-	register i, j;
+	register int i, j;
@@ -216 +219 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -243,2 +246,2 @@
-dotname(dp)
-register struct direct *dp;
+int
+dotname(register struct direct *dp)
@@ -253,2 +256,2 @@
-pname(i, lev)
-ino_t i;
+void
+pname(ino_t i, int lev)
@@ -273,2 +276 @@
-lookup(i, ef)
-ino_t i;
+lookup(ino_t i, int ef)
@@ -294,3 +296,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+void
+bread(daddr_t bno, char *buf, int cnt)
@@ -298 +299 @@
-	register i;
+	register int i;
@@ -309 +310 @@
-bmap(i)
+bmap(int i)
@@ -316 +317 @@
-	if(i > NINDIR) {
+	if(i > (int)NINDIR) {

% usr/src/cmd/newgrp.c
@@ -5,3 +5,2 @@
-struct	group	*getgrnam(), *grp;
-struct	passwd	*getpwuid(), *pwd;
-char	*getpass(), *crypt();
+struct	group	*grp;
+struct	passwd	*pwd;
@@ -9,3 +8,3 @@
-main(argc,argv)
-int	argc;
-char	**argv;
+void done(void);
+int
+main(int argc, char **argv)
@@ -13 +12 @@
-	register i;
+	register int i;
@@ -45 +44,2 @@
-done()
+void
+done(void)
@@ -47 +47 @@
-	register i;
+	register int i;

% usr/src/cmd/nice.c
@@ -5,3 +5,2 @@
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -10 +9 @@
-	extern errno;
+	extern int errno;

% usr/src/cmd/od.c
@@ -14,2 +14,4 @@
-main(argc, argv)
-char **argv;
+void offset(char *s), line(long a, unsigned short *w, int n);
+void putx(unsigned n, int c), cput(int c), putn(long n, int b, int c), pre(int n);
+int
+main(int argc, char **argv)
@@ -18 +20 @@
-	register n, f, same;
+	register int n, f, same;
@@ -97,3 +99,2 @@
-line(a, w, n)
-long a;
-unsigned short *w;
+void
+line(long a, unsigned short *w, int n)
@@ -101 +102 @@
-	register i, f, c;
+	register int i, f, c;
@@ -104 +105 @@
-	for(c=1; c; c<<=1) {
+	for(c=1; c&0177; c<<=1) {
@@ -120,2 +121,2 @@
-putx(n, c)
-unsigned n;
+void
+putx(unsigned n, int c)
@@ -158 +159,2 @@
-cput(c)
+void
+cput(int c)
@@ -190,2 +192,2 @@
-putn(n, b, c)
-long n;
+void
+putn(long n, int b, int c)
@@ -193 +195 @@
-	register d;
+	register int d;
@@ -205 +207,2 @@
-pre(n)
+void
+pre(int n)
@@ -213,2 +216,2 @@
-offset(s)
-register char *s;
+void
+offset(register char *s)

% usr/src/cmd/osh.c
@@ -4,0 +5,4 @@
+#include <signal.h>
+#include <stdio.h>
+#undef	getc
+#undef	putc
@@ -48 +52 @@
-char	uid;
+int	uid;
@@ -53,0 +58 @@
+#undef	NSIG
@@ -55 +60 @@
-char	*mesg[NSIG] {
+char	*mesg[NSIG] = {
@@ -78,3 +83,8 @@
-main(c, av)
-int c;
-char **av;
+int	*syntax(char **p1, char **p2), *syn1(char **p1, char **p2);
+int	*syn2(char **p1, char **p2), *syn3(char **p1, char **p2);
+int	readc(void), getc(void), any(int c, char *as), equal(char *as1, char *as2);
+void	main1(void), word(void), prs(char *as), prn(int n), putc(int c);
+void	err(char *s, int exitno), texec(char *f, int *at), pwait(int i, int *t);
+void	execute(int *t, int *pf1, int *pf2);
+int
+main(int c, char **av)
@@ -82,2 +92,2 @@
-	register f;
-	register char *acname, **v;
+	register int f;
+	register char **v;
@@ -93 +102,0 @@
-	acname = "<none>";
@@ -121,2 +130,2 @@
-		signal(QUIT, 1);
-		f = signal(INTR, 1);
+		signal(QUIT, SIG_IGN);
+		f = (int)signal(INTR, SIG_IGN);
@@ -137 +146,2 @@
-main1()
+void
+main1(void)
@@ -140 +150 @@
-	register *t;
+	register int *t;
@@ -163 +173 @@
-			execute(t);
+			execute(t, 0, 0);
@@ -167 +177,2 @@
-word()
+void
+word(void)
@@ -223,2 +234,2 @@
-tree(n)
-int n;
+static int *
+tree(int n)
@@ -226 +237 @@
-	register *t;
+	register int *t;
@@ -229 +240 @@
-	treep =+ n;
+	treep += n;
@@ -238 +249,2 @@
-getc()
+int
+getc(void)
@@ -248 +260 @@
-		argp =- 10;
+		argp -= 10;
@@ -250 +262 @@
-		argp =+ 10;
+		argp += 10;
@@ -256 +268 @@
-		linep =- 10;
+		linep -= 10;
@@ -258 +270 @@
-		linep =+ 10;
+		linep += 10;
@@ -292 +304,2 @@
-readc()
+int
+readc(void)
@@ -296 +309 @@
-	register c;
+	register int c;
@@ -299 +312 @@
-		if (arginp == 1)
+		if (arginp == (char *)1)
@@ -302 +315 @@
-			arginp = 1;
+			arginp = (char *)1;
@@ -309 +322 @@
-	if((rdstat = read(0, &cc, 1)) != 1)
+	if((rdstat = read(0, &cc, 1)) != 1) {
@@ -311,0 +325 @@
+	}
@@ -323,2 +337,2 @@
-syntax(p1, p2)
-char **p1, **p2;
+int *
+syntax(char **p1, char **p2)
@@ -342,2 +356,2 @@
-syn1(p1, p2)
-char **p1, **p2;
+int *
+syn1(char **p1, char **p2)
@@ -346 +360 @@
-	register *t, *t1;
+	register int *t, *t1;
@@ -370 +384 @@
-			t[DLEF] = syn2(p1, p);
+			t[DLEF] = (int)syn2(p1, p);
@@ -373,2 +387,2 @@
-				t1 = t[DLEF];
-				t1[DFLG] =| FAND|FPRS|FINT;
+				t1 = (int *)t[DLEF];
+				t1[DFLG] |= FAND|FPRS|FINT;
@@ -376 +390 @@
-			t[DRIT] = syntax(p+1, p2);
+			t[DRIT] = (int)syntax(p+1, p2);
@@ -392,2 +406,2 @@
-syn2(p1, p2)
-char **p1, **p2;
+int *
+syn2(char **p1, char **p2)
@@ -415,2 +429,2 @@
-			t[DLEF] = syn3(p1, p);
-			t[DRIT] = syn2(p+1, p2);
+			t[DLEF] = (int)syn3(p1, p);
+			t[DRIT] = (int)syn2(p+1, p2);
@@ -430,2 +444,2 @@
-syn3(p1, p2)
-char **p1, **p2;
+int *
+syn3(char **p1, char **p2)
@@ -435 +449 @@
-	register *t;
+	register int *t;
@@ -440 +454 @@
-		flg =| FPAR;
+		flg |= FPAR;
@@ -468 +482 @@
-			flg =| FCAT; else
+			flg |= FCAT; else
@@ -469,0 +484 @@
+		/* fallthrough */
@@ -483 +498 @@
-				i = *p;
+				i = (int)*p;
@@ -488 +503 @@
-			o = *p;
+			o = (int)*p;
@@ -501 +516 @@
-		t[DSPR] = syn1(lp, rp);
+		t[DSPR] = (int)syn1(lp, rp);
@@ -510 +525 @@
-		t[l+DCOM] = p1[l];
+		t[l+DCOM] = (int)p1[l];
@@ -518,3 +533,2 @@
-scan(at, f)
-int *at;
-int (*f)();
+static void
+scan(int *at, int (*f)(int c))
@@ -523 +537 @@
-	register *t;
+	register int *t;
@@ -526,2 +540,2 @@
-	while(p = *t++)
-		while(c = *p)
+	while((p = (char *)*t++))
+		while((c = *p))
@@ -531,2 +545,2 @@
-tglob(c)
-int c;
+static int
+tglob(int c)
@@ -540,2 +554,2 @@
-trim(c)
-int c;
+static int
+trim(int c)
@@ -547,2 +561,2 @@
-execute(t, pf1, pf2)
-int *t, *pf1, *pf2;
+void
+execute(int *t, int *pf1, int *pf2)
@@ -551 +565 @@
-	register *t1;
+	register int *t1;
@@ -553 +566,0 @@
-	extern errno;
@@ -559 +572 @@
-		cp1 = t[DCOM];
+		cp1 = (char *)t[DCOM];
@@ -562 +575 @@
-				if(chdir(t[DCOM+1]) < 0)
+				if(chdir((char *)t[DCOM+1]) < 0)
@@ -580 +593 @@
-				execv("/bin/login", t+DCOM);
+				execv("/bin/login", (char **)(t+DCOM));
@@ -587 +600 @@
-				execv("/bin/newgrp", t+DCOM);
+				execv("/bin/newgrp", (char **)(t+DCOM));
@@ -597,0 +611 @@
+		/* fallthrough */
@@ -625 +639 @@
-			i = open(t[DLEF], 0);
+			i = open((char *)t[DLEF], 0);
@@ -627 +641 @@
-				prs(t[DLEF]);
+				prs((char *)t[DLEF]);
@@ -634 +648 @@
-				i = open(t[DRIT], 1);
+				i = open((char *)t[DRIT], 1);
@@ -640 +654 @@
-			i = creat(t[DRIT], 0666);
+			i = creat((char *)t[DRIT], 0666);
@@ -642 +656 @@
-				prs(t[DRIT]);
+				prs((char *)t[DRIT]);
@@ -668,2 +682,2 @@
-			signal(INTR, 0);
-			signal(QUIT, 0);
+			signal(INTR, SIG_DFL);
+			signal(QUIT, SIG_DFL);
@@ -672,3 +686,3 @@
-			if(t1 = t[DSPR])
-				t1[DFLG] =| f&FINT;
-			execute(t1);
+			if((t1 = (int *)t[DSPR]))
+				t1[DFLG] |= f&FINT;
+			execute(t1, 0, 0);
@@ -680,2 +694,2 @@
-			t[DSPR] = "/etc/glob";
-			execv(t[DSPR], t+DSPR);
+			t[DSPR] = (int)"/etc/glob";
+			execv((char *)t[DSPR], (char **)(t+DSPR));
@@ -687 +701 @@
-		texec(t[DCOM], t);
+		texec((char *)t[DCOM], t);
@@ -690 +704 @@
-		while(*cp1 = *cp2++)
+		while((*cp1 = *cp2++))
@@ -692,2 +706,2 @@
-		cp2 = t[DCOM];
-		while(*cp1++ = *cp2++);
+		cp2 = (char *)t[DCOM];
+		while((*cp1++ = *cp2++));
@@ -696 +710 @@
-		prs(t[DCOM]);
+		prs((char *)t[DCOM]);
@@ -698,0 +713 @@
+		/* fallthrough */
@@ -703,2 +718,2 @@
-		t1 = t[DLEF];
-		t1[DFLG] =| FPOU | (f&(FPIN|FINT|FPRS));
+		t1 = (int *)t[DLEF];
+		t1[DFLG] |= FPOU | (f&(FPIN|FINT|FPRS));
@@ -706,2 +721,2 @@
-		t1 = t[DRIT];
-		t1[DFLG] =| FPIN | (f&(FPOU|FINT|FAND|FPRS));
+		t1 = (int *)t[DRIT];
+		t1[DFLG] |= FPIN | (f&(FPOU|FINT|FAND|FPRS));
@@ -713,6 +728,6 @@
-		if(t1 = t[DLEF])
-			t1[DFLG] =| f;
-		execute(t1);
-		if(t1 = t[DRIT])
-			t1[DFLG] =| f;
-		execute(t1);
+		if((t1 = (int *)t[DLEF]))
+			t1[DFLG] |= f;
+		execute(t1, 0, 0);
+		if((t1 = (int *)t[DRIT]))
+			t1[DFLG] |= f;
+		execute(t1, 0, 0);
@@ -724,2 +739,2 @@
-texec(f, at)
-int *at;
+void
+texec(char *f, int *at)
@@ -727 +742 @@
-	extern errno;
+	extern int errno;
@@ -731 +746 @@
-	execv(f, t+DCOM);
+	execv(f, (char **)(t+DCOM));
@@ -734,3 +749,3 @@
-			t[DCOM] = linep;
-		t[DSPR] = "/usr/bin/osh";
-		execv(t[DSPR], t+DSPR);
+			t[DCOM] = (int)linep;
+		t[DSPR] = (int)"/usr/bin/osh";
+		execv((char *)t[DSPR], (char **)(t+DSPR));
@@ -741 +756 @@
-		prs(t[DCOM]);
+		prs((char *)t[DCOM]);
@@ -747,3 +762,2 @@
-err(s, exitno)
-char *s;
-int exitno;
+void
+err(char *s, int exitno)
@@ -760,2 +774,2 @@
-prs(as)
-char *as;
+void
+prs(char *as)
@@ -770 +784,2 @@
-putc(c)
+void
+putc(int c)
@@ -778,2 +793,2 @@
-prn(n)
-int n;
+void
+prn(int n)
@@ -781 +796 @@
-	register a;
+	register int a;
@@ -783 +798 @@
-	if (a = n/10)
+	if ((a = n/10))
@@ -788,3 +803,2 @@
-any(c, as)
-int c;
-char *as;
+int
+any(int c, char *as)
@@ -801,2 +815,2 @@
-equal(as1, as2)
-char *as1, *as2;
+int
+equal(char *as1, char *as2)
@@ -814,2 +828,2 @@
-pwait(i, t)
-int i, *t;
+void
+pwait(int i, int *t)
@@ -817 +831 @@
-	register p, e;
+	register int p, e;
@@ -818,0 +833 @@
+	(void)t;
@@ -840 +855 @@
-		if (e || s&&stoperr)
+		if (e || (s&&stoperr))
@@ -842 +857 @@
-		errval =| (s>>8);
+		errval |= (s>>8);

% usr/src/cmd/passwd.c
@@ -13,6 +12,0 @@
-struct	passwd *getpwent();
-int	endpwent();
-char	*strcpy();
-char	*crypt();
-char	*getpass();
-char	*getlogin();
@@ -23,2 +17,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -75 +69 @@
-	while(c = *p++){
+	while((c = *p++)){

% usr/src/cmd/pr.c
@@ -41,2 +41,3 @@
-char	*ttyname();
-char	*ctime();
+int	tpgetc(int ai), pgetc(int i);
+void	done(void), onintr(int sig), fixtty(void), print(char *fp, char **argp);
+void	mopen(char **ap), putpage(void), nexbuf(void), put(int ac), putcp(int c);
@@ -44,2 +45,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -48 +48,0 @@
-	int onintr();
@@ -107 +107,2 @@
-done()
+void
+done(void)
@@ -115 +116,2 @@
-onintr()
+void
+onintr(int sig)
@@ -117,0 +120 @@
+	(void)sig;
@@ -123 +126,2 @@
-fixtty()
+void
+fixtty(void)
@@ -135,3 +139,2 @@
-print(fp, argp)
-char *fp;
-char **argp;
+void
+print(char *fp, char **argp)
@@ -139 +141,0 @@
-	extern char *sprintf();
@@ -141 +143 @@
-	register sncol;
+	register int sncol;
@@ -195 +197 @@
-	while (mflg&&nofile || (!mflg)&&tpgetc(ncol)>0) {
+	while ((mflg&&nofile) || ((!mflg)&&tpgetc(ncol)>0)) {
@@ -218,2 +220,2 @@
-mopen(ap)
-char **ap;
+void
+mopen(char **ap)
@@ -238 +240,2 @@
-putpage()
+void
+putpage(void)
@@ -282 +285,2 @@
-nexbuf()
+void
+nexbuf(void)
@@ -305 +309,2 @@
-tpgetc(ai)
+int
+tpgetc(int ai)
@@ -340 +345,2 @@
-pgetc(i)
+int
+pgetc(int i)
@@ -372 +378,2 @@
-put(ac)
+void
+put(int ac)
@@ -418 +425,2 @@
-putcp(c)
+void
+putcp(int c)

% usr/src/cmd/primes.c usr/src/cmd/primes.s
@@ -1,355 +1,137 @@
-ldfps = 170100^tst
-/
-	ldfps	$240
-
-	clr	argflg
-	cmp	(sp)+,$2
-	blt	begin
-	tst	(sp)+
-	mov	(sp),r2
-	jsr	r5,atof; getch1
-	inc	argflg
-	br	begin1
-begin:
-	tst	argflg
-	beq 9f; sys exit; 9:
-	jsr	r5,atof; getch
-begin1:
-	tstf	fr0
-	cfcc
-	bpl 9f; jmp ouch; 9:
-	bne 9f; sys exit; 9:
-	cmpf	big,fr0
-	cfcc
-	bgt 9f; jmp ouch; 9:
-/
-	movf	$f100,fr1
-	cmpf	fr0,fr1
-	cfcc
-	bge	1f
-	mov	$pt,r3
-3:
-	cmp	r3,$ptend
-	bhis	1f
-	movif	(r3)+,fr1
-	cmpf	fr1,fr0
-	cfcc
-	blt	3b
-	tst	-(r3)
-3:
-	movif	(r3),fr0
-	jsr	r5,ftoa; wrchar
-	mov	$'\n,r0
-	jsr	r5,wrchar
-	tst	(r3)+
-	cmp	r3,$ptend
-	blo	3b
-	movf	$f100,fr0
-/
-1:
-	divf	$two,fr0
-	modf	$one,fr0
-	movf	fr1,fr0
-	mulf	$two,fr0
-	addf	$one,fr0
-	movif	$tsiz8,fr1
-	movf	fr1,fr5
-	movf	fr0,nn
-/
-/
-/
-/	clear the sieve table
-/
-2:
-	mov	$table,r3
-3:
-	cmp	r3,$table+tabsiz
-	bhis	3f
-	clrb	(r3)+
-	br	3b
-/
-/	run the sieve
-/
-3:
-	movf	nn,fr0
-	addf	fr5,fr0
-	jsr	r5,sqrt
-	movf	fr0,v
-/
-	movf	nn,fr0
-	movif	$3.,fr1
-	jsr	pc,5f
-	movif	$5.,fr1
-	jsr	pc,5f
-	movif	$7.,fr1
-	jsr	pc,5f
-	movif	$11.,fr1
-	mov	$factab+2,r4
-4:
-	jsr	pc,5f
-	mov	(r4)+,kazoo
-kazoo	=.+2
-	addf	$kazoo,fr1
-	cmp	r4,$ftabend
-	blo	3f
-	mov	$factab,r4
-3:
-	cmpf	v,fr1
-	cfcc
-	bge	4b
-	br	1f
-/
-/
-5:
-	movf	fr0,fr2
-	divf	fr1,fr2
-	modf	$one,fr2
-	mulf	fr1,fr3
-	subf	fr0,fr3
-	cfcc
-	bpl	3f
-	addf	fr1,fr3
-3:
-	cmpf	fr5,fr3
-	cfcc
-	ble	3f
-	movfi	fr3,r0
-	ashc	$-3.,r0
-	ash	$-13.,r1
-	bic	$177770,r1
-	bisb	bittab(r1),table(r0)
-	addf	fr1,fr3
-	br	3b
-3:
-	rts	pc
-/
-/
-/	get one character form the argument string.
-getch1:
-	movb	(r2)+,r0
-	rts	r5
-/
-/	now get the primes from the table
-/	and print them.
-/
-1:
-/
-	movf	nn,fr0
-	clr	r3
-	br	4f
-/
-1:
-	inc	r3
-	inc	r3
-	cmp	r3,$tsiz8
-	bge	2b
-/
-4:
-/
-	jsr	pc,prime
-	bec	3f
-	movf	nn,fr0
-	jsr	r5,ftoa; wrchar
-	mov	$'\n,r0
-	jsr	r5,wrchar
-3:
-	movf	nn,fr0
-	addf	$two,fr0
-	movf	fr0,nn
-	br	1b
-/
-/
-/
-/
-prime:
-	mov	r3,r4
-	ashc	$-3.,r4
-	ash	$-13.,r5
-	bic	$177770,r5
-	bitb	bittab(r5),table(r4)
-	bne	1f
-	sec
-1:
-	rts	pc
-/
-/
-/
-/
-one	= 40200
-half	= 40000
-opower	= 34400
-power	= 44000
-f100	= 41710
-/
-/	get one character from the console.
-/	called from atof.
-/
-getch:
-	clr	r0
-	sys	read; ch; 1
-	bec 9f; sys exit; 9:
-	tst r0; bne 9f; sys exit; 9:
-	mov	ch,r0
-	rts	r5
-/
-/
-/	write one character on the console
-/	called from ftoa.
-/
-wrchar:
-	tst	iobuf
-	bne	1f
-	mov	$iobuf+2,iobuf
-1:
-	movb	r0,*iobuf
-	inc	iobuf
-	cmp	iobuf,$iobuf+514.
-	blo	1f
-	mov	$1,r0
-	sys	write; iobuf+2; 512.
-	mov	$iobuf+2,iobuf
-1:
-	rts	r5
-/
-	.bss
-iobuf:	.=.+518.
-	.text
-/
-/
-/	read and convert a line from the console into fr0.
-/
-atof:
-	mov	r1,-(sp)
-	movif	$10.,r3
-	clrf	r0
-1:
-	jsr	r5,*(r5)
-	sub	$'0,r0
-	cmp	r0,$9.
-	bhi	2f
-	mulf	r3,r0
-	movif	r0,r1
-	addf	r1,r0
-	br	1b
-2:
-	cmp	r0,$' -'0
-	beq	1b
-/
-	mov	(sp)+,r1
-	tst	(r5)+
-	rts	r5
-/
-/
-ftoa:
-	mov	$ebuf,r2
-1:
-	movf	fr0,fr1
-	divf	$ten,fr1
-	movf	fr1,fr2
-	modf	$one,fr2
-	movf	fr3,-(sp)
-	mulf	$ten,fr3
-	negf	fr3
-	addf	fr0,fr3
-	movfi	fr3,-(r2)
-	movf	(sp)+,fr0
-	tstf	fr0
-	cfcc
-	bne	1b
-1:
-	mov	(r2)+,r0
-	add	$60,r0
-	jsr	r5,*(r5)
-	cmp	r2,$ebuf
-	blo	1b
-	tst	(r5)+
-	rts	r5
-/
-/
-/
-/	replace the f.p. number in fr0 by its square root
-/
-sqrt:
-	movf	r0,r1		/ a
-	tstf	fr0
-	cfcc
-	beq	2f
-	bgt	1f
-	sec
-	rts	r5		/ sqrt(-a)
-1:
-	seti
-	movf	fr0,-(sp)
-	asr	(sp)
-	add	$20100,(sp)
-	movf	(sp)+,fr0
-	movif	$2,r3		/ constant 2
-	mov	$4,r0
-1:
-	movf	r1,r2
-	divf	r0,r2
-	addf	r2,r0
-	divf	r3,r0		/ x = (x+a/x)/2
-	dec	r0
-	bgt	1b
-2:
-	clc
-	rts	r5
-/
-/
-buf:	.=.+38.
-ebuf:
-/
-/
-/
-/	complain about a number which the program
-/	is unable to digest
-ouch:
-	mov	$2,r0
-	sys	write; 1f; 2f-1f
-	jmp	begin
-/
-1:	<Ouch.\n>
-2:	.even
-/
-/
-one	= 40200
-two	= 40400
-four	= 40600
-six	= 40700
-ten	= 41040
-/
-	.data
-bittab:	.byte	1, 2, 4, 10, 20, 40, 100, 200
-big:	056177; 177777; 177777; 177777
-/
-pt:	2.; 3.; 5.; 7.; 11.; 13.; 17.; 19.; 23.; 29.; 31.; 37.; 41.; 43.
-	47.; 53.; 59.; 61.; 67.; 71.; 73.; 79.; 83.; 89.; 97.
-ptend:
-nl:	<\n>
-sp5:	<     >
-	.even
-/
-/
-factab:
-	41040; 40400; 40600; 40400; 40600; 40700; 40400; 40700
-	40600; 40400; 40600; 40700; 40700; 40400; 40700; 40600
-	40400; 40700; 40600; 40700; 41000; 40600; 40400; 40600
-	40400; 40600; 41000; 40700; 40600; 40700; 40400; 40600
-	40700; 40400; 40700; 40700; 40600; 40400; 40600; 40700
-	40400; 40700; 40600; 40400; 40600; 40400; 41040; 40400
-ftabend:
-/
-	.bss
-ch:	.=.+2
-t:	.=.+8
-n:	.=.+8
-v:	.=.+8
-nn:	.=.+8
-place:	.=.+8
-/
-tabsiz	= 1000.
-tsiz8	= 8000.
-table:	.=.+tabsiz
-argflg:	.=.+2
-	.text
+#include <stdio.h>
+#include <math.h>
+
+#define	BIG	72057594037927935LL
+#define	TABSIZ	1000
+#define	TSIZ8	8000
+
+long long pt[] = {
+	2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43,
+	47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97
+};
+int	factab[] = {
+	10, 2, 4, 2, 4, 6, 2, 6,
+	4, 2, 4, 6, 6, 2, 6, 4,
+	2, 6, 4, 6, 8, 4, 2, 4,
+	2, 4, 8, 6, 4, 6, 2, 4,
+	6, 2, 6, 6, 4, 2, 4, 6,
+	2, 6, 4, 2, 4, 2, 10, 2
+};
+char	table[TABSIZ];
+char	iobuf[512];
+int	nbuf;
+char	*arg;
+long long nn;
+
+static int
+getch(void)
+{
+	char c;
+
+	if(arg)
+		return(*arg++);
+	if(read(0, &c, 1) != 1)
+		exit(0);
+	return(c);
+}
+
+static long long
+getnum(void)
+{
+	register int c;
+	long long n;
+
+	n = 0;
+	for(;;) {
+		c = getch();
+		if(c == ' ')
+			continue;
+		if(c < '0' || c > '9')
+			return(n);
+		if(n < BIG)
+			n = n*10 + c-'0';
+	}
+}
+
+static void
+wrchar(int c)
+{
+	iobuf[nbuf++] = c;
+	if(nbuf >= 512) {
+		write(1, iobuf, 512);
+		nbuf = 0;
+	}
+}
+
+static void
+ftoa(long long n)
+{
+	if(n >= 10)
+		ftoa(n/10);
+	wrchar((int)(n%10) + '0');
+}
+
+static void
+mark(int p)
+{
+	long long off;
+
+	off = nn/p*p - nn;
+	if(off < 0)
+		off += p;
+	for(; off < TSIZ8; off += p)
+		table[off>>3] |= 1<<(off&7);
+}
+
+int
+main(int argc, char **argv)
+{
+	register int i, f, p;
+	long long n;
+	double v;
+
+	if(argc > 1)
+		arg = argv[1];
+	while((n = getnum()) >= BIG) {
+		write(2, "Ouch.\n", 6);
+		if(arg)
+			exit(1);
+	}
+	if(n == 0)
+		exit(0);
+	if(n < 100) {
+		for(i = 0; i < 25 && pt[i] < n; i++)
+			;
+		if(i < 25) {
+			for(; i < 25; i++) {
+				ftoa(pt[i]);
+				wrchar('\n');
+			}
+			n = 100;
+		}
+	}
+	nn = n/2*2 + 1;
+	for(;;) {
+		for(i = 0; i < TABSIZ; i++)
+			table[i] = 0;
+		v = sqrt((double)(nn+TSIZ8));
+		mark(3);
+		mark(5);
+		mark(7);
+		p = 11;
+		f = 1;
+		do {
+			mark(p);
+			p += factab[f++];
+			if(f >= 48)
+				f = 0;
+		} while(p <= v);
+		for(i = 0; i < TSIZ8; i += 2) {
+			if((table[i>>3] & 1<<(i&7)) == 0) {
+				ftoa(nn);
+				wrchar('\n');
+			}
+			nn += 2;
+		}
+	}
+}

% usr/src/cmd/prof.c
@@ -42 +42 @@
-double	ftime;
+double	ftim;
@@ -56,2 +56,5 @@
-main(argc, argv)
-char **argv;
+int	min(unsigned a, unsigned b), max(unsigned a, unsigned b);
+int	timcmp(char *a, char *b), valcmp(char *a, char *b);
+void	done(void);
+int
+main(int argc, char **argv)
@@ -60 +62,0 @@
-	int timcmp(), valcmp();
@@ -61,0 +64 @@
+#ifdef plot
@@ -64 +66,0 @@
-	struct cnt *cp;
@@ -65,0 +68,2 @@
+#endif
+	struct cnt *cp;
@@ -83 +87 @@
-				if(lowpc == -1)
+				if(lowpc == (unsigned)-1)
@@ -118,2 +122,2 @@
-	lowpc = h.lowpc - (UNIT *)0;
-	highpc = h.highpc - (UNIT *)0;
+	lowpc = (unsigned)h.lowpc/sizeof(UNIT);
+	highpc = (unsigned)h.highpc/sizeof(UNIT);
@@ -121,0 +126 @@
+#ifdef plot
@@ -122,0 +128 @@
+#endif
@@ -149 +155 @@
-	qsort(nl, nname, sizeof(struct nl), valcmp);
+	qsort((char *)nl, nname, sizeof(struct nl), valcmp);
@@ -153,2 +159,2 @@
-		register j;
-		unsigned UNIT ccnt;
+		register int j;
+		unsigned short ccnt;
@@ -162,4 +168,4 @@
-		ftime = ccnt;
-		totime += ftime;
-		if(ftime > maxtime)
-			maxtime = ftime;
+		ftim = ccnt;
+		totime += ftim;
+		if(ftim > maxtime)
+			maxtime = ftim;
@@ -172 +178 @@
-			nl[j].time += overlap*ftime/scale;
+			nl[j].time += overlap*ftim/scale;
@@ -201 +207 @@
-		ftime = ccnt;
+		ftim = ccnt;
@@ -204 +210 @@
-		lastsx -= 2000.*ftime/totime;
+		lastsx -= 2000.*ftim/totime;
@@ -210 +216 @@
-				lastx = -ftime*2000./maxtime;
+				lastx = -ftim*2000./maxtime;
@@ -223 +229 @@
-		ftime = np->time/totime;
+		ftim = np->time/totime;
@@ -250 +256 @@
-		qsort(nl, nname, sizeof(struct nl), timcmp);
+		qsort((char *)nl, nname, sizeof(struct nl), timcmp);
@@ -252 +258 @@
-		ftime = np->time/totime;
+		ftim = np->time/totime;
@@ -254 +260 @@
-		printf("%8.8s%6.1f%9.2f", np->name, 100*ftime, actime/60);
+		printf("%8.8s%6.1f%9.2f", np->name, 100*ftim, actime/60);
@@ -264,2 +270,2 @@
-min(a, b)
-unsigned a, b;
+int
+min(unsigned a, unsigned b)
@@ -272,2 +278,2 @@
-max(a, b)
-unsigned a, b;
+int
+max(unsigned a, unsigned b)
@@ -280,2 +286,2 @@
-valcmp(p1, p2)
-struct nl *p1, *p2;
+int
+valcmp(char *a, char *b)
@@ -282,0 +289 @@
+	struct nl *p1 = (struct nl *)a, *p2 = (struct nl *)b;
@@ -286,2 +293,2 @@
-timcmp(p1, p2)
-struct nl *p1, *p2;
+int
+timcmp(char *a, char *b)
@@ -288,0 +296 @@
+	struct nl *p1 = (struct nl *)a, *p2 = (struct nl *)b;
@@ -299 +307,2 @@
-done()
+void
+done(void)

% usr/src/cmd/ps.c
@@ -8 +8,3 @@
-#include <core.h>
+#define TXTRNDSIZ 8192L
+#define stacktop(siz) (0x100000L)
+#define stackbas(siz) (0x100000L-siz)
@@ -10,2 +12 @@
-#include <sys/proc.h>
-#include <sys/tty.h>
+#include "../../sys/h/proc.h"
@@ -13 +14 @@
-#include <sys/user.h>
+#include "../../sys/h/user.h"
@@ -16,4 +17,4 @@
-	{ "_proc" },
-	{ "_swapdev" },
-	{ "_swplo" },
-	{ "" },
+	{ "_proc", 0, 0 },
+	{ "_swapdev", 0, 0 },
+	{ "_swplo", 0, 0 },
+	{ "", 0, 0 },
@@ -32,4 +33,4 @@
-long	lseek();
-char	*gettty();
-char	*getptr();
-char	*strncmp();
+char	*gettty(void);
+char	*getptr(char **adr);
+int	prcom(int puid), getbyte(char *adr), within(char *adr, long lbd, long ubd);
+void	getdev(void);
@@ -44 +45 @@
-	char	dname[DIRSIZ];
+	char	dname[DIRSIZ+1];
@@ -50,2 +51,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -134 +135 @@
-	printf(" F S UID   PID  PPID CPU PRI NICE  ADDR  SZ  WCHAN TTY TIME CMD\n"); else
+	printf(" F S UID   PID  PPID CPU PRI NICE    ADDR   SZ       WCHAN TTY TIME CMD\n"); else
@@ -154 +155,2 @@
-getdev()
+void
+getdev(void)
@@ -166 +168 @@
-	while (fread((char *)&dbuf, sizeof(dbuf), 1, df) == 1) {
+	while (ndev < 256 && fread((char *)&dbuf, sizeof(dbuf), 1, df) == 1) {
@@ -169 +171,2 @@
-		if(stat(dbuf.d_name, &sbuf) < 0)
+		strncpy(devl[ndev].dname, dbuf.d_name, DIRSIZ);
+		if(stat(devl[ndev].dname, &sbuf) < 0)
@@ -173 +175,0 @@
-		strcpy(devl[ndev].dname, dbuf.d_name);
@@ -184,3 +186,2 @@
-long
-round(a, b)
-	long		a, b;
+static long
+round(long a, long b)
@@ -199 +200,2 @@
-prcom(puid)
+int
+prcom(int puid)
@@ -201 +203 @@
-	char abuf[512];
+	int abuf[128];
@@ -234 +236 @@
-	datmap.f2 = ctob(USIZE)+(datmap.e1-datmap.b1)+addr;
+	datmap.f2 = ctob(USIZE)+datmap.b2+addr;
@@ -241 +243 @@
-			"0SWRIZT"[mproc.p_stat], puid);
+			"0SWRIZT"[mproc.p_stat&0377], puid);
@@ -245 +247 @@
-		printf("%6u%4d%4d%5d%6o%4d", mproc.p_ppid, mproc.p_cpu&0377,
+		printf("%6u%4d%4d%5d%8o%5d", mproc.p_ppid, mproc.p_cpu&0377,
@@ -250 +252 @@
-			printf("%7o", mproc.p_wchan);
+			printf("%12o", mproc.p_wchan);
@@ -252 +254 @@
-			printf("       ");
+			printf("            ");
@@ -304 +306 @@
-	if (read(file, abuf, sizeof(abuf)) != sizeof(abuf))
+	if (read(file, (char *)abuf, sizeof(abuf)) != sizeof(abuf))
@@ -306 +308 @@
-	for (ip = (int *)&abuf[512]-2; ip > (int *)abuf; ) {
+	for (ip = &abuf[128]-2; ip > abuf; ) {
@@ -312 +314 @@
-			for (cp1 = cp; cp1 < &abuf[512]; cp1++) {
+			for (cp1 = cp; cp1 < (char *)abuf + sizeof(abuf); cp1++) {
@@ -339 +341 @@
-gettty()
+gettty(void)
@@ -341 +343 @@
-	register i;
+	register int i;
@@ -358,2 +360 @@
-getptr(adr)
-char **adr;
+getptr(char **adr)
@@ -363 +364 @@
-	register i;
+	register unsigned i;
@@ -373,2 +374,2 @@
-getbyte(adr)
-char *adr;
+int
+getbyte(char *adr)
@@ -395,3 +396,2 @@
-within(adr,lbd,ubd)
-char *adr;
-long lbd, ubd;
+int
+within(char *adr, long lbd, long ubd)
@@ -399 +399 @@
-	return((unsigned)adr>=lbd && (unsigned)adr<ubd);
+	return((long)adr>=lbd && (long)adr<ubd);

% usr/src/cmd/pstat.c
@@ -5,0 +6,2 @@
+#include <stdio.h>
+#include <a.out.h>
@@ -7,2 +9,7 @@
-#include <sys/conf.h>
-#include <sys/tty.h>
+#include "../../sys/h/tty.h"
+#include <sys/inode.h>
+#include "../../sys/h/text.h"
+#include "../../sys/h/proc.h"
+#include <sys/dir.h>
+#include "../../sys/h/user.h"
+#include "../../sys/h/file.h"
@@ -20 +27 @@
-	"_inode", 0, 0,
+	{"_inode", 0, 0},
@@ -22 +29 @@
-	"_text", 0, 0,
+	{"_text", 0, 0},
@@ -24 +31 @@
-	"_proc", 0, 0,
+	{"_proc", 0, 0},
@@ -26 +33 @@
-	"_dh11", 0, 0,
+	{"_dh11", 0, 0},
@@ -28 +35 @@
-	"_ndh11", 0, 0,
+	{"_ndh11", 0, 0},
@@ -30 +37 @@
-	"_kl11", 0, 0,
+	{"_kl11", 0, 0},
@@ -32,2 +39,2 @@
-	"_file", 0, 0,
-	0,
+	{"_file", 0, 0},
+	{"", 0, 0},
@@ -45,2 +52,5 @@
-main(argc, argv)
-char **argv;
+int oatoi(char *s);
+void doinode(void), dotext(void), doproc(void), dotty(void), dousr(void), dofil(void);
+void putf(int v, int n), ttyprt(int n, struct tty *atp);
+int
+main(int argc, char **argv)
@@ -92,2 +102,2 @@
-	nlist(fnlist, setup);
-	if (setup[SINODE].type == -1) {
+	nlist(fnlist, (struct nlist *)setup);
+	if (setup[SINODE].type == 0) {
@@ -111 +121,2 @@
-doinode()
+void
+doinode(void)
@@ -113 +123,0 @@
-#include <sys/inode.h>
@@ -137 +147 @@
-		printf("%4d", ip->i_count&0377);
+		printf("%4d", ip->i_count);
@@ -151 +161,2 @@
-putf(v, n)
+void
+putf(int v, int n)
@@ -159 +170,2 @@
-dotext()
+void
+dotext(void)
@@ -161 +172,0 @@
-#include <sys/text.h>
@@ -164 +175 @@
-	register loc;
+	register int loc;
@@ -196 +207,2 @@
-doproc()
+void
+doproc(void)
@@ -198 +209,0 @@
-#include <sys/proc.h>
@@ -201 +212 @@
-	register loc, np;
+	register int loc, np;
@@ -236 +247,2 @@
-dotty()
+void
+dotty(void)
@@ -249 +261 @@
-	if (setup[SNDH].type == -1)
+	if (setup[SNDH].type == 0)
@@ -260,2 +272,2 @@
-ttyprt(n, atp)
-struct tty *atp;
+void
+ttyprt(int n, struct tty *atp)
@@ -286 +298,2 @@
-dousr()
+void
+dousr(void)
@@ -288,2 +300,0 @@
-#include <sys/dir.h>
-#include <sys/user.h>
@@ -295 +306 @@
-	register i;
+	register int i;
@@ -355,2 +366,2 @@
-oatoi(s)
-char *s;
+int
+oatoi(char *s)
@@ -358 +369 @@
-	register v;
+	register int v;
@@ -366 +377,2 @@
-dofil()
+void
+dofil(void)
@@ -368 +379,0 @@
-#include <sys/file.h>
@@ -371 +382 @@
-	register nf;
+	register int nf;
@@ -389 +400 @@
-		printf("%4d", mask(fp->f_count));
+		printf("%4d", fp->f_count);

% usr/src/cmd/ptx.c
@@ -34,2 +34,7 @@
-extern char *calloc(), *mktemp();
-extern char *getline();
+extern char *getline(void);
+void diag(char *s,char *arg), msg(char *s,char *arg), cmpline(char *pend);
+void getsort(void), putline(char *strt, char *end), putout(char *strt,char *end);
+void onintr(int sig);
+int storeh(int num,char *strtp), hash(char *strtp,char *endp);
+int cmpword(char *cpp,char *pend,char *hpp);
+char *rtrim(char *a,char *c,int d), *ltrim(char *c,char *b,int d);
@@ -41 +46 @@
-char btable[128];
+char btable[256];
@@ -69,3 +74,2 @@
-main(argc,argv)
-int argc;
-char **argv;
+int
+main(int argc,char **argv)
@@ -77 +80,0 @@
-	extern onintr();
@@ -116,0 +120 @@
+			/* fallthrough */
@@ -228 +232 @@
-	while(pend=getline())
+	while((pend=getline()))
@@ -236,0 +241 @@
+		/* fallthrough */
@@ -247 +252 @@
-	onintr();
+	onintr(0);
@@ -250,3 +255,2 @@
-msg(s,arg)
-char *s;
-char *arg;
+void
+msg(char *s,char *arg)
@@ -257,2 +261,2 @@
-diag(s,arg)
-char *s, *arg;
+void
+diag(char *s,char *arg)
@@ -266 +270 @@
-char *getline()
+char *getline(void)
@@ -269 +273 @@
-	register c;
+	register int c;
@@ -291 +295 @@
-				while(isspace(*--linep));
+				while(isspace(*--linep&0377));
@@ -302,2 +306,2 @@
-cmpline(pend)
-char *pend;
+void
+cmpline(char *pend)
@@ -312 +316 @@
-		while(pchar<pend&&!isspace(*pchar))
+		while(pchar<pend&&!isspace(*pchar&0377))
@@ -316 +320 @@
-		if(isabreak(*pchar++))
+		if(isabreak(*pchar++&0377))
@@ -322 +326 @@
-			if(isabreak(*pchar)) {
+			if(isabreak(*pchar&0377)) {
@@ -325 +329 @@
-				while(cp = *hp++){
+				while((cp = *hp++)){
@@ -349,2 +353,2 @@
-cmpword(cpp,pend,hpp)
-char *cpp, *pend, *hpp;
+int
+cmpword(char *cpp,char *pend,char *hpp)
@@ -356 +360 @@
-		if((isupper(c)?tolower(c):c) != *hpp++)
+		if((isupper(c&0377)?tolower(c):c) != *hpp++)
@@ -363,2 +367,2 @@
-putline(strt, end)
-char *strt, *end;
+void
+putline(char *strt, char *end)
@@ -379 +383,2 @@
-getsort()
+void
+getsort(void)
@@ -381 +386 @@
-	register c;
+	register int c;
@@ -385 +389,0 @@
-	char *rtrim(), *ltrim();
@@ -400 +404 @@
-			while(isspace(linep[-1]))
+			while(isspace(linep[-1]&0377))
@@ -404 +408 @@
-				while(ref<linep&&!isspace(*ref))
+				while(ref<linep&&!isspace(*ref&0377))
@@ -416 +420 @@
-			p1b = rtrim(p1a=p3b+(isspace(p3b[0])!=0),tilde,
+			p1b = rtrim(p1a=p3b+(isspace(p3b[0]&0377)!=0),tilde,
@@ -420 +424 @@
-			p4a = ltrim(ref,p4b=p2a-(isspace(p2a[-1])!=0),
+			p4a = ltrim(ref,p4b=p2a-(isspace(p2a[-1]&0377)!=0),
@@ -452,0 +457 @@
+			/* fallthrough */
@@ -459,2 +464 @@
-char *rtrim(a,c,d)
-char *a,*c;
+char *rtrim(char *a,char *c,int d)
@@ -465 +469 @@
-		if((x==c||isspace(x[0]))&&!isspace(x[-1]))
+		if((x==c||isspace(x[0]&0377))&&!isspace(x[-1]&0377))
@@ -467 +471 @@
-	if(b<c&&!isspace(b[0]))
+	if(b<c&&!isspace(b[0]&0377))
@@ -472,2 +476 @@
-char *ltrim(c,b,d)
-char *c,*b;
+char *ltrim(char *c,char *b,int d)
@@ -478 +481 @@
-		if(!isspace(x[0])&&(x==c||isspace(x[-1])))
+		if(!isspace(x[0]&0377)&&(x==c||isspace(x[-1]&0377)))
@@ -480 +483 @@
-	if(a>c&&!isspace(a[-1]))
+	if(a>c&&!isspace(a[-1]&0377))
@@ -485,2 +488,2 @@
-putout(strt,end)
-char *strt, *end;
+void
+putout(char *strt,char *end)
@@ -497 +500,2 @@
-onintr()
+void
+onintr(int sig)
@@ -498,0 +503 @@
+	(void)sig;
@@ -505,2 +510,2 @@
-hash(strtp,endp)
-char *strtp, *endp;
+int
+hash(char *strtp,char *endp)
@@ -517 +522 @@
-	i = (isupper(c)?tolower(c):c);
+	i = (isupper(c&0377)?tolower(c):c);
@@ -519 +524 @@
-	j = (isupper(c)?tolower(c):c);
+	j = (isupper(c&0377)?tolower(c):c);
@@ -523 +528 @@
-	k = (isupper(c)?tolower(c):c);
+	k = (isupper(c&0377)?tolower(c):c);
@@ -525 +530 @@
-	j = (isupper(c)?tolower(c):c);
+	j = (isupper(c&0377)?tolower(c):c);
@@ -532,3 +537,2 @@
-storeh(num,strtp)
-int num;
-char *strtp;
+int
+storeh(int num,char *strtp)

% usr/src/cmd/pwd.c
@@ -17 +17,3 @@
-main()
+void prname(void), cat(void);
+int
+main(void)
@@ -38 +40 @@
-				if (read(file, (char *)&dir, sizeof(dir)) < sizeof(dir)) {
+				if (read(file, (char *)&dir, sizeof(dir)) < (int)sizeof(dir)) {
@@ -45 +47 @@
-				if(read(file, (char *)&dir, sizeof(dir)) < sizeof(dir)) {
+				if(read(file, (char *)&dir, sizeof(dir)) < (int)sizeof(dir)) {
@@ -56 +58,2 @@
-prname()
+void
+prname(void)
@@ -66 +69,2 @@
-cat()
+void
+cat(void)
@@ -68 +72 @@
-	register i, j;
+	register int i, j;

% usr/src/cmd/quot.c
@@ -42,3 +42,3 @@
-struct	passwd	*getpwent();
-char	*malloc();
-char	*copy();
+char	*copy(char *s);
+void	check(char *file), acct(struct dinode *ip);
+void	bread(unsigned bno, char *buf, int cnt), report(void);
@@ -46,2 +46,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -87,2 +87,2 @@
-check(file)
-char *file;
+void
+check(char *file)
@@ -91 +91 @@
-	register c;
+	register int c;
@@ -118,2 +118,2 @@
-acct(ip)
-register struct dinode *ip;
+void
+acct(register struct dinode *ip)
@@ -121 +121 @@
-	register n;
+	register int n;
@@ -123 +123 @@
-	static fino;
+	static int fino;
@@ -147 +147 @@
-		if (fino > ino)
+		if (fino > (int)ino)
@@ -149 +149 @@
-		if (fino<ino) {
+		if (fino<(int)ino) {
@@ -155 +155 @@
-		if (np = du[ip->di_uid].name)
+		if ((np = du[ip->di_uid].name))
@@ -170,3 +170,2 @@
-bread(bno, buf, cnt)
-unsigned bno;
-char *buf;
+void
+bread(unsigned bno, char *buf, int cnt)
@@ -182,2 +181,2 @@
-qcmp(p1, p2)
-register struct du *p1, *p2;
+static int
+qcmp(char *a, char *b)
@@ -184,0 +184 @@
+	register struct du *p1 = (struct du *)a, *p2 = (struct du *)b;
@@ -192 +192,2 @@
-report()
+void
+report(void)
@@ -194 +195 @@
-	register i;
+	register int i;
@@ -208 +209 @@
-	qsort(du, NUID, sizeof(du[0]), qcmp);
+	qsort((char *)du, NUID, sizeof(du[0]), qcmp);
@@ -223,2 +224 @@
-copy(s)
-char *s;
+copy(char *s)
@@ -227 +227 @@
-	register n;
+	register int n;
@@ -232 +232 @@
-	for(n=0; p[n] = s[n]; n++)
+	for(n=0; (p[n] = s[n]); n++)

% usr/src/cmd/random.c
@@ -4 +3,0 @@
-double	atof();
@@ -7 +6,2 @@
-main(argc,argv) char **argv;
+int
+main(int argc, char **argv)

% usr/src/cmd/restor.c
@@ -84,2 +84,13 @@
-main(argc, argv)
-char *argv[];
+int readc(void), psearch(char *n), direq(char *s1, char *s2), gethead(struct spcl *buf);
+int ishead(struct spcl *buf), checktype(struct spcl *b, int t), checksum(int *b);
+int checkvol(struct spcl *b, int t), readhdr(struct spcl *b);
+void pass1(void), putent(char *cp), doit(char command, int argc, char *argv[]);
+void getfile(ino_t n, void (*f1)(char *b, long size), void (*f2)(char *b, long size), long size);
+void readtape(char *b), flsht(void), copy(char *f, char *t, int s), clearbuf(char *cp);
+void writec(char c), flsh(void), dwrite(daddr_t bno, char *b), dread(daddr_t bno, char *buf, int cnt);
+void clri(struct dinode *ip), itrunc(struct dinode *ip), tloop(daddr_t bn, int f1, int f2);
+void bfree(daddr_t bn), getdino(ino_t inum, struct dinode *b), putdino(ino_t inum, struct dinode *b);
+void readbits(short *m), xtrfile(char *b, long size), null(char *b, long size), skip(char *b, long size);
+void rstrfile(char *b, long s), rstrskip(char *b, long s), putdir(char *b, long size), done(int sig);
+int
+main(int argc, char *argv[])
@@ -88,2 +99 @@
-	char command;
-	int done();
+	char command = 0;
@@ -143,4 +153,2 @@
-doit(command, argc, argv)
-char	command;
-int	argc;
-char	*argv[];
+void
+doit(char command, int argc, char *argv[])
@@ -148,2 +156 @@
-	extern char *ctime();
-	register i, k;
+	register int i, k;
@@ -151,4 +157,0 @@
-#ifndef STANDALONE
-	int	xtrfile(), skip();
-#endif
-	int	rstrfile(), rstrskip();
@@ -251 +254 @@
-					return;
+				return;
@@ -300 +303 @@
-			if (gets(tbf) == EOF) {
+			if (gets(tbf) == NULL) {
@@ -405 +408,2 @@
-pass1()
+void
+pass1(void)
@@ -407 +411 @@
-	register i;
+	register int i;
@@ -409 +412,0 @@
-	int	putdir(), null();
@@ -446,4 +449,2 @@
-getfile(n, f1, f2, size)
-ino_t	n;
-int	(*f2)(), (*f1)();
-long	size;
+void
+getfile(ino_t n, void (*f1)(char *b, long size), void (*f2)(char *b, long size), long size)
@@ -451 +452 @@
-	register i;
+	register int i;
@@ -495,2 +496,2 @@
-readtape(b)
-char *b;
+void
+readtape(char *b)
@@ -498 +499 @@
-	register i;
+	register int i;
@@ -539 +540,2 @@
-flsht()
+void
+flsht(void)
@@ -544,2 +546,2 @@
-copy(f, t, s)
-register char *f, *t;
+void
+copy(register char *f, register char *t, int s)
@@ -547 +549 @@
-	register i;
+	register int i;
@@ -555,2 +557,2 @@
-clearbuf(cp)
-register char *cp;
+void
+clearbuf(register char *cp)
@@ -558 +560 @@
-	register i;
+	register int i;
@@ -571,2 +573,2 @@
-putent(cp)
-char	*cp;
+void
+putent(char *cp)
@@ -574 +576 @@
-	register i;
+	register int i;
@@ -576 +578 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -586,2 +588,2 @@
-getent(bf)
-register char *bf;
+static void
+getent(register char *bf)
@@ -589 +591 @@
-	register i;
+	register int i;
@@ -591 +593 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -602,2 +604,2 @@
-writec(c)
-char c;
+void
+writec(char c)
@@ -613 +615,2 @@
-readc()
+int
+readc(void)
@@ -622,2 +625,2 @@
-mseek(pt)
-daddr_t pt;
+static void
+mseek(daddr_t pt)
@@ -629 +632,2 @@
-flsh()
+void
+flsh(void)
@@ -638,4 +642,2 @@
-ino_t
-search(inum, cp)
-ino_t	inum;
-char	*cp;
+static ino_t
+search(ino_t inum, char *cp)
@@ -643 +645 @@
-	register i;
+	register int i;
@@ -665,2 +667,2 @@
-psearch(n)
-char	*n;
+int
+psearch(char *n)
@@ -693,2 +695,2 @@
-direq(s1, s2)
-register char *s1, *s2;
+int
+direq(register char *s1, register char *s2)
@@ -696 +698 @@
-	register i;
+	register int i;
@@ -712,3 +714,2 @@
-dwrite(bno, b)
-daddr_t	bno;
-char	*b;
+void
+dwrite(daddr_t bno, char *b)
@@ -716 +717 @@
-	register i;
+	register int i;
@@ -738,3 +739,2 @@
-dread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+void
+dread(daddr_t bno, char *buf, int cnt)
@@ -742 +742 @@
-	register i, j;
+	register int i, j;
@@ -779,2 +779,2 @@
-clri(ip)
-struct dinode *ip;
+void
+clri(struct dinode *ip)
@@ -793,2 +793,2 @@
-itrunc(ip)
-register struct dinode *ip;
+void
+itrunc(register struct dinode *ip)
@@ -796 +796 @@
-	register i;
+	register int i;
@@ -829,3 +829,2 @@
-tloop(bn, f1, f2)
-daddr_t	bn;
-int	f1, f2;
+void
+tloop(daddr_t bn, int f1, int f2)
@@ -833 +832 @@
-	register i;
+	register int i;
@@ -853,2 +852,2 @@
-bfree(bn)
-daddr_t	bn;
+void
+bfree(daddr_t bn)
@@ -856 +855 @@
-	register i;
+	register int i;
@@ -863 +862 @@
-		fbuf.df_nfree = sblock.s_nfree;
+		fbuf.frees.df_nfree = sblock.s_nfree;
@@ -865 +864 @@
-			fbuf.df_free[i] = sblock.s_free[i];
+			fbuf.frees.df_free[i] = sblock.s_free[i];
@@ -875,2 +874,2 @@
-daddr_t
-balloc()
+static daddr_t
+balloc(void)
@@ -879 +878 @@
-	register i;
+	register int i;
@@ -896 +895 @@
-		sblock.s_nfree = fbuf.df_nfree;
+		sblock.s_nfree = fbuf.frees.df_nfree;
@@ -898 +897 @@
-			sblock.s_free[i] = fbuf.df_free[i];
+			sblock.s_free[i] = fbuf.frees.df_free[i];
@@ -909,4 +908,2 @@
-daddr_t
-bmap(iaddr, bn)
-daddr_t	iaddr[NADDR];
-daddr_t	bn;
+static daddr_t
+bmap(daddr_t iaddr[NADDR], daddr_t bn)
@@ -914 +911 @@
-	register i;
+	register int i;
@@ -976,2 +973,2 @@
-gethead(buf)
-struct spcl *buf;
+int
+gethead(struct spcl *buf)
@@ -988,2 +985,2 @@
-ishead(buf)
-struct spcl *buf;
+int
+ishead(struct spcl *buf)
@@ -996,3 +993,2 @@
-checktype(b, t)
-struct	spcl *b;
-int	t;
+int
+checktype(struct	spcl *b, int t)
@@ -1004,2 +1000,2 @@
-checksum(b)
-int *b;
+int
+checksum(int *b)
@@ -1007 +1003 @@
-	register i, j;
+	register unsigned i, j;
@@ -1021,3 +1017,2 @@
-checkvol(b, t)
-struct spcl *b;
-int t;
+int
+checkvol(struct spcl *b, int t)
@@ -1030,2 +1025,2 @@
-readhdr(b)
-struct	spcl *b;
+int
+readhdr(struct	spcl *b)
@@ -1045,3 +1040,2 @@
-xtrfile(b, size)
-char	*b;
-long	size;
+void
+xtrfile(char *b, long size)
@@ -1052 +1046,2 @@
-null() {;}
+void
+null(char *b, long size) {(void)b; (void)size;}
@@ -1054 +1049,2 @@
-skip()
+void
+skip(char *b, long size)
@@ -1055,0 +1052 @@
+	(void)b; (void)size;
@@ -1061,3 +1058,2 @@
-rstrfile(b, s)
-char *b;
-long s;
+void
+rstrfile(char *b, long s)
@@ -1066,0 +1063 @@
+	(void)s;
@@ -1072,3 +1069,2 @@
-rstrskip(b, s)
-char *b;
-long s;
+void
+rstrskip(char *b, long s)
@@ -1075,0 +1072 @@
+	(void)b; (void)s;
@@ -1080,2 +1077,2 @@
-putdir(b)
-char *b;
+void
+putdir(char *b, long size)
@@ -1084 +1081 @@
-	register i;
+	register int i;
@@ -1085,0 +1083 @@
+	(void)size;
@@ -1097,3 +1095,2 @@
-getdino(inum, b)
-ino_t	inum;
-struct	dinode *b;
+void
+getdino(ino_t inum, struct	dinode *b)
@@ -1110,3 +1107,2 @@
-putdino(inum, b)
-ino_t	inum;
-struct	dinode *b;
+void
+putdino(ino_t inum, struct	dinode *b)
@@ -1126,2 +1122,2 @@
-readbits(m)
-short	*m;
+void
+readbits(short *m)
@@ -1129 +1125 @@
-	register i;
+	register int i;
@@ -1141 +1137,2 @@
-done()
+void
+done(int sig)
@@ -1142,0 +1140 @@
+	(void)sig;

% usr/src/cmd/rev.c
@@ -9,2 +9,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -12 +12 @@
-	register i,c;
+	register int i,c;

% usr/src/cmd/rm.c
@@ -8 +8,2 @@
-char	*sprintf();
+void	rm(char arg[], int fflg, int rflg, int iflg, int level);
+int	dotname(char *s), rmdir(char *f, int iflg), yes(void);
@@ -10,2 +11,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -51,2 +52,2 @@
-rm(arg, fflg, rflg, iflg, level)
-char arg[];
+void
+rm(char arg[], int fflg, int rflg, int iflg, int level)
@@ -116,2 +117,2 @@
-dotname(s)
-char *s;
+int
+dotname(char *s)
@@ -119 +120 @@
-	if(s[0] == '.')
+	if(s[0] == '.') {
@@ -126,0 +128 @@
+	}
@@ -130,2 +132,2 @@
-rmdir(f, iflg)
-char *f;
+int
+rmdir(char *f, int iflg)
@@ -151,0 +154 @@
+	return(1);
@@ -154 +157,2 @@
-yes()
+int
+yes(void)

% usr/src/cmd/rmdir.c
@@ -11,3 +11 @@
-char	*rindex();
-char	*strcat();
-char	*strcpy();
+void	rmdir(char *d);
@@ -15,3 +13,2 @@
-main(argc,argv)
-int argc;
-char **argv;
+int
+main(int argc, char **argv)
@@ -29,2 +26,2 @@
-rmdir(d)
-char *d;
+void
+rmdir(char *d)

% usr/src/cmd/sa.c
@@ -9 +9 @@
-#define	NC	sizeof(acctbuf.ac_comm)
+#define	NC	(int)sizeof(acctbuf.ac_comm)
@@ -47 +47,6 @@
-time_t	expand();
+time_t	expand(unsigned t);
+int	tcmp(char *q1, char *q2), ncmp(char *q1, char *q2), bcmp(char *q1, char *q2);
+int	enter(char *np);
+float	sum(struct tab *p);
+void	init(void), doacct(char *f), strip(void), printmoney(void);
+void	column(double n, double a, double b, double c), col(double n, double a, double m);
@@ -49,2 +54,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -54,2 +58,0 @@
-	extern tcmp(), ncmp(), bcmp();
-	extern float sum();
@@ -143 +146 @@
-		return;
+		return(0);
@@ -202 +205 @@
-	qsort(tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
+	qsort((char *)tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
@@ -213 +216,2 @@
-printmoney()
+void
+printmoney(void)
@@ -215 +219 @@
-	register i;
+	register int i;
@@ -236,2 +240,2 @@
-column(n, a, b, c)
-double n, a, b, c;
+void
+column(double n, double a, double b, double c)
@@ -258,2 +262,2 @@
-col(n, a, m)
-double n, a, m;
+void
+col(double n, double a, double m)
@@ -272,2 +276,2 @@
-doacct(f)
-char *f;
+void
+doacct(char *f)
@@ -334,2 +338,2 @@
-ncmp(p1, p2)
-struct tab *p1, *p2;
+int
+ncmp(char *q1, char *q2)
@@ -336,0 +341 @@
+	struct tab *p1 = (struct tab *)q1, *p2 = (struct tab *)q2;
@@ -339 +344 @@
-		return(tcmp(p1, p2));
+		return(tcmp(q1, q2));
@@ -345,2 +350,2 @@
-bcmp(p1, p2)
-struct tab *p1, *p2;
+int
+bcmp(char *q1, char *q2)
@@ -347,0 +353 @@
+	struct tab *p1 = (struct tab *)q1, *p2 = (struct tab *)q2;
@@ -349 +354,0 @@
-	float sum();
@@ -365,2 +370,2 @@
-tcmp(p1, p2)
-struct tab *p1, *p2;
+int
+tcmp(char *q1, char *q2)
@@ -368 +373 @@
-	extern float sum();
+	struct tab *p1 = (struct tab *)q1, *p2 = (struct tab *)q2;
@@ -386,2 +391 @@
-float sum(p)
-struct tab *p;
+float sum(struct tab *p)
@@ -397 +401,2 @@
-init()
+void
+init(void)
@@ -424,2 +429,2 @@
-enter(np)
-char *np;
+int
+enter(char *np)
@@ -453 +458,2 @@
-strip()
+void
+strip(void)
@@ -475,2 +481 @@
-expand(t)
-unsigned t;
+expand(unsigned t)

% usr/src/cmd/sed/sed.h
@@ -34,37 +34,37 @@
-FILE	*fin;
-union reptr	*abuf[ABUFSIZE];
-union reptr **aptr;
-char	*lastre;
-char	ibuf[512];
-char	*cbp;
-char	*ebp;
-char	genbuf[LBSIZE];
-char	*loc1;
-char	*loc2;
-char	*locs;
-char	seof;
-char	*reend;
-char	*lbend;
-char	*hend;
-char	*lcomend;
-union reptr	*ptrend;
-int	eflag;
-int	dolflag;
-int	sflag;
-int	jflag;
-int	numbra;
-int	delflag;
-long	lnum;
-char	linebuf[LBSIZE+1];
-char	holdsp[LBSIZE+1];
-char	*spend;
-char	*hspend;
-int	nflag;
-int	gflag;
-char	*braelist[NBRA];
-char	*braslist[NBRA];
-long	tlno[NLINES];
-int	nlno;
-char	fname[12][40];
-FILE	*fcode[12];
-int	nfiles;
+extern FILE	*fin;
+extern struct reptr	*abuf[ABUFSIZE];
+extern struct reptr **aptr;
+extern char	*lastre;
+extern char	ibuf[512];
+extern char	*cbp;
+extern char	*ebp;
+extern char	genbuf[LBSIZE];
+extern char	*loc1;
+extern char	*loc2;
+extern char	*locs;
+extern char	seof;
+extern char	*reend;
+extern char	*lbend;
+extern char	*hend;
+extern char	*lcomend;
+extern struct reptr	*ptrend;
+extern int	eflag;
+extern int	dolflag;
+extern int	sflag;
+extern int	jflag;
+extern int	numbra;
+extern int	delflag;
+extern long	lnum;
+extern char	linebuf[LBSIZE+1];
+extern char	holdsp[LBSIZE+1];
+extern char	*spend;
+extern char	*hspend;
+extern int	nflag;
+extern int	gflag;
+extern char	*braelist[NBRA];
+extern char	*braslist[NBRA];
+extern long	tlno[NLINES];
+extern int	nlno;
+extern char	fname[12][40];
+extern FILE	*fcode[12];
+extern int	nfiles;
@@ -100,3 +100,3 @@
-char	*cp;
-char	*reend;
-char	*lbend;
+extern char	*cp;
+extern char	*reend;
+extern char	*lbend;
@@ -104,2 +104 @@
-union	reptr {
-	struct reptr1 {
+extern struct	reptr {
@@ -108,0 +108 @@
+		struct reptr	*lb1;
@@ -116,13 +115,0 @@
-	};
-	struct reptr2 {
-		char	*ad1;
-		char	*ad2;
-		union reptr	*lb1;
-		char	*rhs;
-		FILE	*fcode;
-		char	command;
-		char	gfl;
-		char	pfl;
-		char	inar;
-		char	negfl;
-	};
@@ -132 +119 @@
-char	respace[RESIZE];
+extern char	respace[RESIZE];
@@ -134 +121 @@
-struct label {
+extern struct label {
@@ -136,2 +123,2 @@
-	union reptr	*chain;
-	union reptr	*address;
+	struct reptr	*chain;
+	struct reptr	*address;
@@ -140,2 +127,2 @@
-struct label	*lab;
-struct label	*labend;
+extern struct label	*lab;
+extern struct label	*labend;
@@ -143,2 +130,2 @@
-int	f;
-int	depth;
+extern int	f;
+extern int	depth;
@@ -146,2 +133,2 @@
-int	eargc;
-char	**eargv;
+extern int	eargc;
+extern char	**eargv;
@@ -151,14 +138,15 @@
-union reptr	**cmpend[DEPTH];
-int	depth;
-union reptr	*pending;
-char	*badp;
-char	bad;
-char	*compile();
-char	*ycomp();
-char	*address();
-char	*text();
-char	*compsub();
-struct label	*search();
-char	*gline();
-char	*place();
-char	compfl;
+extern struct reptr	**cmpend[DEPTH];
+extern int	depth;
+extern struct reptr	*pending;
+extern char	*badp;
+extern char	bad;
+char	*compile(char *expbuf);
+char	*ycomp(char *expbuf);
+char	*address(char *expbuf);
+char	*text(char *textbuf);
+char	*compsub(char *rhsbuf);
+struct label	*search(struct label *ptr);
+char	*gline(char *addr);
+char	*place(char *asp, char *al1, char *al2);
+void	execute(char *file);
+extern char	compfl;

% usr/src/cmd/sed/sed0.c
@@ -3,0 +4,13 @@
+void	fcomp(void), dechain(void);
+int	rline(char *lbuf), cmp(char *a, char *b);
+FILE	*fin, *fcode[12];
+struct reptr	*abuf[ABUFSIZE], **aptr, *ptrend, ptrspace[PTRSIZE], *rep;
+struct reptr	**cmpend[DEPTH], *pending;
+struct label	ltab[LABSIZE], *lab, *labend;
+char	*lastre, ibuf[512], *cbp, *ebp, genbuf[LBSIZE], *loc1, *loc2, *locs;
+char	seof, *reend, *lbend, *hend, *lcomend, linebuf[LBSIZE+1];
+char	holdsp[LBSIZE+1], *spend, *hspend, *braelist[NBRA], *braslist[NBRA];
+char	fname[12][40], *cp, respace[RESIZE], **eargv, *badp, bad, compfl;
+int	eflag, dolflag, sflag, jflag, numbra, delflag, nflag, gflag, nlno;
+int	nfiles, f, depth, eargc;
+long	lnum, tlno[NLINES];
@@ -21,2 +34,2 @@
-main(argc, argv)
-char	*argv[];
+int
+main(int argc, char *argv[])
@@ -105 +118 @@
-/*	abort();	/*DEBUG*/
+/*	abort();	*DEBUG*/
@@ -115 +128,2 @@
-fcomp()
+void
+fcomp(void)
@@ -119,2 +133 @@
-	char	*address();
-	union reptr	*pt, *pt1;
+	struct reptr	*pt, *pt1;
@@ -143 +156 @@
-/*	fprintf(stdout, "cp: %s\n", cp);	/*DEBUG*/
+/*	fprintf(stdout, "cp: %s\n", cp);	*DEBUG*/
@@ -201,0 +215 @@
+				/* fallthrough */
@@ -261 +275 @@
-				if(lpt = search(lab)) {
+				if((lpt = search(lab))) {
@@ -345,2 +359,2 @@
-					if(pt = labtab->chain) {
-						while(pt1 = pt->lb1)
+					if((pt = labtab->chain)) {
+						while((pt1 = pt->lb1))
@@ -362 +376 @@
-				if(lpt = search(lab)) {
+				if((lpt = search(lab))) {
@@ -367 +381 @@
-						while(pt1 = pt->lb1)
+						while((pt1 = pt->lb1))
@@ -561,2 +575 @@
-char	*compsub(rhsbuf)
-char	*rhsbuf;
+char	*compsub(char *rhsbuf)
@@ -588,2 +601 @@
-char *compile(expbuf)
-char	*expbuf;
+char *compile(char *expbuf)
@@ -591 +603 @@
-	register c;
+	register int c;
@@ -719 +731 @@
-					for (c = sp[-2]; c<*sp; c++)
+					for (c = sp[-2]&0177; c<(*sp&0177); c++)
@@ -730 +742 @@
-				ep[c >> 3] |= bittab[c & 07];
+				ep[(c&0177) >> 3] |= bittab[c & 07];
@@ -749,2 +761,2 @@
-rline(lbuf)
-char	*lbuf;
+int
+rline(char *lbuf)
@@ -753 +765 @@
-	register	t;
+	register int	t;
@@ -764 +776 @@
-			while(*++p = *q++) {
+			while((*++p = *q++)) {
@@ -783 +795 @@
-		while(*++p = *q++) {
+		while((*++p = *q++)) {
@@ -816,2 +828 @@
-char	*address(expbuf)
-char	*expbuf;
+char	*address(char *expbuf)
@@ -855,2 +866,2 @@
-cmp(a, b)
-char	*a,*b;
+int
+cmp(char *a, char *b)
@@ -868,2 +879 @@
-char	*text(textbuf)
-char	*textbuf;
+char	*text(char *textbuf)
@@ -892,2 +902 @@
-struct label	*search(ptr)
-struct label	*ptr;
+struct label	*search(struct label *ptr)
@@ -908 +917,2 @@
-dechain()
+void
+dechain(void)
@@ -911 +921 @@
-	union reptr	*rptr, *trptr;
+	struct reptr	*rptr, *trptr;
@@ -922 +932 @@
-			while(trptr = rptr->lb1) {
+			while((trptr = rptr->lb1)) {
@@ -931,2 +941 @@
-char *ycomp(expbuf)
-char	*expbuf;
+char *ycomp(char *expbuf)
@@ -934 +943,2 @@
-	register char	c, *ep, *tsp;
+	register int	c;
+	register char	*ep, *tsp;

% usr/src/cmd/sed/sed1.c
@@ -3,0 +4,3 @@
+void	command(struct reptr *ipc), arout(void), dosub(char *rhsbuf);
+int	match(char *expbuf, int gf), advance(char *alp, char *aep),
+	ecmp(char *a, char *b, int count);
@@ -39,2 +42,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -43 +46 @@
-	register union reptr	*ipc;
+	register struct reptr	*ipc;
@@ -158,2 +161,2 @@
-match(expbuf, gf)
-char	*expbuf;
+int
+match(char *expbuf, int gf)
@@ -167 +170 @@
-		while(*p1++ = *p2++);
+		while((*p1++ = *p2++));
@@ -205,2 +208,2 @@
-advance(alp, aep)
-char	*alp, *aep;
+int
+advance(char *alp, char *aep)
@@ -213 +216 @@
-/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	/*DEBUG*/
+/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	*DEBUG*/
@@ -235,0 +239,2 @@
+		if(lp == locs)
+			return(0);
@@ -248 +253 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -252 +257 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -256,2 +261,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[*ep&0377];
+		ct = braelist[*ep++&0377] - bbeg;
@@ -266,2 +271,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[*ep&0377];
+		ct = braelist[*ep++&0377] - bbeg;
@@ -315 +320 @@
-			c = *(braslist[ep[1]]);
+			c = *(braslist[ep[1]&0377]);
@@ -336,2 +341,2 @@
-substitute(ipc)
-union reptr	*ipc;
+static int
+substitute(struct reptr *ipc)
@@ -353,2 +358,2 @@
-dosub(rhsbuf)
-char	*rhsbuf;
+void
+dosub(char *rhsbuf)
@@ -364 +369 @@
-	while(c = *rp++) {
+	while((c = *rp++)) {
@@ -373 +378 @@
-		if (sp >= &genbuf[LBSIZE])
+		if (sp >= &genbuf[LBSIZE]) {
@@ -374,0 +380,2 @@
+			exit(2);
+		}
@@ -378 +385 @@
-	while (*sp++ = *lp++)
+	while ((*sp++ = *lp++))
@@ -380,0 +388 @@
+			exit(2);
@@ -384 +392 @@
-	while (*lp++ = *sp++);
+	while ((*lp++ = *sp++));
@@ -387,2 +395 @@
-char	*place(asp, al1, al2)
-char	*asp, *al1, *al2;
+char	*place(char *asp, char *al1, char *al2)
@@ -397 +404 @@
-		if (sp >= &genbuf[LBSIZE])
+		if (sp >= &genbuf[LBSIZE]) {
@@ -398,0 +406,2 @@
+			exit(2);
+		}
@@ -403,2 +412,2 @@
-command(ipc)
-union reptr	*ipc;
+void
+command(struct reptr *ipc)
@@ -444 +453 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -456 +465 @@
-			while(*p1++ = *p2++);
+			while((*p1++ = *p2++));
@@ -464 +473 @@
-			while(*p1++ = *p2++)
+			while((*p1++ = *p2++))
@@ -473 +482 @@
-			while(*p1++ = *p2++);
+			while((*p1++ = *p2++));
@@ -481 +490 @@
-			while(*p1++ = *p2++)
+			while((*p1++ = *p2++))
@@ -505 +514 @@
-						while(*p2++ = *p3++)
+						while((*p2++ = *p3++))
@@ -523 +532 @@
-					while(*p2++ = *p3++)
+					while((*p2++ = *p3++))
@@ -585,0 +595 @@
+			/* fallthrough */
@@ -599 +609 @@
-			if(ipc->pfl && i)
+			if(ipc->pfl && i) {
@@ -606,0 +617 @@
+			}
@@ -624 +635 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -627 +638 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -631 +642 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -638 +649 @@
-			while(*p1 = p2[*p1])	p1++;
+			while((*p1 = *p1 & 0200 ? *p1 : p2[*p1&0377]))	p1++;
@@ -645,2 +656 @@
-gline(addr)
-char	*addr;
+gline(char *addr)
@@ -649 +659 @@
-	register	c;
+	register int	c;
@@ -683,2 +693,2 @@
-ecmp(a, b, count)
-char	*a, *b;
+int
+ecmp(char *a, char *b, int count)
@@ -691 +701,2 @@
-arout()
+void
+arout(void)
@@ -698,2 +709 @@
-	aptr = abuf - 1;
-	while(*++aptr) {
+	for(aptr = abuf; *aptr; aptr++) {

% usr/src/cmd/sh/args.c
@@ -12 +12 @@
-PROC STRING *copyargs();
+LOCAL STRING *copyargs(STRING from[], INT n);
@@ -15 +15 @@
-CHAR	flagadr[10];
+CHAR	flagadr[11];
@@ -27,3 +27 @@
-INT	options(argc,argv)
-	STRING		*argv;
-	INT		argc;
+INT	options(INT argc, STRING *argv)
@@ -68,2 +66 @@
-VOID	setargs(argi)
-	STRING		argi[];
+VOID	setargs(STRING argi[])
@@ -79 +76 @@
-	dolh=copyargs(argi,argn);	/* sets dolv */
+	dolh=(DOLPTR)copyargs(argi,argn);	/* sets dolv */
@@ -83,2 +80,2 @@
-freeargs(blk)
-	DOLPTR		blk;
+DOLPTR
+freeargs(DOLPTR blk)
@@ -90 +87 @@
-	IF argblk=blk
+	IF (argblk=blk)
@@ -93 +90 @@
-		THEN	FOR argp=argblk->dolarg; Rcheat(*argp)!=ENDARGS; argp++
+		THEN	FOR argp=(STRING *)argblk->dolarg; Rcheat(*argp)!=ENDARGS; argp++
@@ -101,2 +98 @@
-LOCAL STRING *	copyargs(from, n)
-	STRING		from[];
+LOCAL STRING *	copyargs(STRING from[], INT n)
@@ -104 +100 @@
-	REG STRING *	np=alloc(sizeof(STRING*)*n+3*BYTESPERWORD);
+	REG STRING *	np=(STRING *)alloc(sizeof(STRING*)*n+3*BYTESPERWORD);
@@ -108,2 +104,2 @@
-	np->doluse=1;	/* use count */
-	np=np->dolarg;
+	((DOLPTR)np)->doluse=1;	/* use count */
+	np=(STRING *)((DOLPTR)np)->dolarg;
@@ -118 +114,2 @@
-clearup()
+VOID
+clearup(void)
@@ -121 +118 @@
-	WHILE argfor=freeargs(argfor) DONE
+	WHILE (argfor=freeargs(argfor)) DONE
@@ -127 +124 @@
-DOLPTR	useargs()
+DOLPTR	useargs(void)
@@ -131 +128 @@
-		dolh->dolnxt=argfor;
+		IF dolh!=argfor THEN dolh->dolnxt=argfor FI

% usr/src/cmd/sh/blok.c
@@ -27,2 +27 @@
-ADDRESS	alloc(nbytes)
-	POS		nbytes;
+ADDRESS	alloc(POS nbytes)
@@ -37 +36 @@
-				IF ADR(q)-ADR(p) >= rbytes
+				IF (POS)(ADR(q)-ADR(p)) >= rbytes
@@ -52,2 +51 @@
-VOID	addblok(reqd)
-	POS		reqd;
+VOID	addblok(POS reqd)
@@ -60 +58 @@
-		rndstak=round(staktop,BYTESPERWORD);
+		rndstak=(STKPTR)round(staktop,BYTESPERWORD);
@@ -77,2 +75 @@
-VOID	free(ap)
-	BLKPTR		ap;
+VOID	free(void *ap)
@@ -83 +80 @@
-	THEN	Lcheat((--p)->word) &= ~BUSY;
+	THEN	p--; p->word=BLK(Rcheat(p->word)&~BUSY);

% usr/src/cmd/sh/brkincr.h

% usr/src/cmd/sh/builtin.c
@@ -1 +1,3 @@
-builtin()
+#include	"defs.h"
+int
+builtin(void)

% usr/src/cmd/sh/cmd.c
@@ -13,11 +13,11 @@
-PROC IOPTR	inout();
-PROC VOID	chkword();
-PROC VOID	chksym();
-PROC TREPTR	term();
-PROC TREPTR	makelist();
-PROC TREPTR	list();
-PROC REGPTR	syncase();
-PROC TREPTR	item();
-PROC VOID	skipnl();
-PROC VOID	prsym();
-PROC VOID	synbad();
+LOCAL IOPTR	inout(IOPTR lastio);
+LOCAL VOID	chkword(void);
+LOCAL VOID	chksym(INT sym);
+LOCAL TREPTR	term(INT flg);
+LOCAL TREPTR	makelist(INT type, TREPTR i, TREPTR r);
+LOCAL TREPTR	list(INT flg);
+LOCAL REGPTR	syncase(INT esym);
+LOCAL TREPTR	item(BOOL flag);
+LOCAL INT	skipnl(void);
+LOCAL VOID	prsym(INT sym);
+LOCAL VOID	synbad(void);
@@ -31,3 +31 @@
-TREPTR	makefork(flgs, i)
-	INT		flgs;
-	TREPTR		i;
+TREPTR	makefork(INT flgs, TREPTR i)
@@ -35 +33 @@
-	REG TREPTR	t;
+	REG FORKPTR	t;
@@ -37 +35 @@
-	t=getstak(FORKTYPE);
+	t=(FORKPTR)getstak(FORKTYPE);
@@ -39 +37 @@
-	return(t);
+	return((TREPTR)t);
@@ -42,3 +40 @@
-LOCAL TREPTR	makelist(type,i,r)
-	INT		type;
-	TREPTR		i, r;
+LOCAL TREPTR	makelist(INT type, TREPTR i, TREPTR r)
@@ -46 +42 @@
-	REG TREPTR	t;
+	REG LSTPTR	t = 0;
@@ -50 +46 @@
-	ELSE	t = getstak(LSTTYPE);
+	ELSE	t = (LSTPTR)getstak(LSTTYPE);
@@ -54 +50 @@
-	return(t);
+	return((TREPTR)t);
@@ -65,3 +61 @@
-TREPTR	cmd(sym,flg)
-	REG INT		sym;
-	INT		flg;
+TREPTR	cmd(REG INT sym, INT flg)
@@ -87,0 +82 @@
+		/* fallthrough */
@@ -90 +85 @@
-		IF e=cmd(sym,flg|MTFLG)
+		IF (e=cmd(sym,flg|MTFLG))
@@ -98,0 +94 @@
+		/* fallthrough */
@@ -116 +112 @@
-LOCAL TREPTR	list(flg)
+LOCAL TREPTR	list(INT flg)
@@ -134 +130 @@
-LOCAL TREPTR	term(flg)
+LOCAL TREPTR	term(INT flg)
@@ -150,2 +146 @@
-LOCAL REGPTR	syncase(esym)
-	REG INT	esym;
+LOCAL REGPTR	syncase(REG INT esym)
@@ -156 +151 @@
-	ELSE	REG REGPTR	r=getstak(REGTYPE);
+	ELSE	REG REGPTR	r=(REGPTR)getstak(REGTYPE);
@@ -189,2 +184 @@
-LOCAL TREPTR	item(flag)
-	BOOL		flag;
+LOCAL TREPTR	item(BOOL flag)
@@ -204 +198,3 @@
-		   t=getstak(SWTYPE);
+		   REG SWPTR	s;
+		   t=(TREPTR)getstak(SWTYPE);
+		   s=(SWPTR)t;
@@ -206 +202 @@
-		   t->swarg=wdarg->argval;
+		   s->swarg=wdarg->argval;
@@ -208,2 +204,2 @@
-		   t->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
-		   t->swtyp=TSW;
+		   s->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
+		   s->swtyp=TSW;
@@ -216,5 +212,7 @@
-		   t=getstak(IFTYPE);
-		   t->iftyp=TIF;
-		   t->iftre=cmd(THSYM,NLFLG);
-		   t->thtre=cmd(ELSYM|FISYM|EFSYM,NLFLG);
-		   t->eltre=((w=wdval)==ELSYM ? cmd(FISYM,NLFLG) : (w==EFSYM ? (wdval=IFSYM, item(0)) : 0));
+		   REG IFPTR	it;
+		   t=(TREPTR)getstak(IFTYPE);
+		   it=(IFPTR)t;
+		   it->iftyp=TIF;
+		   it->iftre=cmd(THSYM,NLFLG);
+		   it->thtre=cmd(ELSYM|FISYM|EFSYM,NLFLG);
+		   it->eltre=((w=wdval)==ELSYM ? cmd(FISYM,NLFLG) : (w==EFSYM ? (wdval=IFSYM, item(0)) : 0));
@@ -227,3 +225,5 @@
-		   t=getstak(FORTYPE);
-		   t->fortyp=TFOR;
-		   t->forlst=0;
+		   REG FORPTR	fr;
+		   t=(TREPTR)getstak(FORTYPE);
+		   fr=(FORPTR)t;
+		   fr->fortyp=TFOR;
+		   fr->forlst=0;
@@ -231 +231 @@
-		   t->fornam=wdarg->argval;
+		   fr->fornam=wdarg->argval;
@@ -234 +234 @@
-			t->forlst=item(0);
+			fr->forlst=(COMPTR)item(0);
@@ -241 +241 @@
-		   t->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
+		   fr->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
@@ -248,4 +248,6 @@
-		   t=getstak(WHTYPE);
-		   t->whtyp=(wdval==WHSYM ? TWH : TUN);
-		   t->whtre = cmd(DOSYM,NLFLG);
-		   t->dotre = cmd(ODSYM,NLFLG);
+		   REG WHPTR	wh;
+		   t=(TREPTR)getstak(WHTYPE);
+		   wh=(WHPTR)t;
+		   wh->whtyp=(wdval==WHSYM ? TWH : TUN);
+		   wh->whtre = cmd(DOSYM,NLFLG);
+		   wh->dotre = cmd(ODSYM,NLFLG);
@@ -262 +264 @@
-		   p=getstak(PARTYPE);
+		   p=(PARPTR)getstak(PARTYPE);
@@ -265 +267 @@
-		   t=makefork(0,p);
+		   t=makefork(0,(TREPTR)p);
@@ -272,0 +275 @@
+		/* fallthrough */
@@ -278,0 +282 @@
+		   REG COMPTR	c;
@@ -280,3 +284,4 @@
-		   t=getstak(COMTYPE);
-		   t->comio=io; /*initial io chain*/
-		   argtail = &(t->comarg);
+		   t=(TREPTR)getstak(COMTYPE);
+		   c=(COMPTR)t;
+		   c->comio=io; /*initial io chain*/
+		   argtail = &(c->comarg);
@@ -286 +291 @@
-			THEN	argp->argnxt=argset; argset=argp;
+			THEN	argp->argnxt=(ARGPTR)argset; argset=(ARGPTR *)argp;
@@ -291 +296 @@
-			THEN t->comio=inout(t->comio);
+			THEN c->comio=inout(c->comio);
@@ -295 +300 @@
-		   t->comtyp=TCOM; t->comset=argset; *argtail=0;
+		   c->comtyp=TCOM; c->comset=(ARGPTR)argset; *argtail=0;
@@ -301 +306 @@
-	IF io=inout(io)
+	IF (io=inout(io))
@@ -308 +313 @@
-LOCAL VOID	skipnl()
+LOCAL INT	skipnl(void)
@@ -314,2 +319 @@
-LOCAL IOPTR	inout(lastio)
-	IOPTR		lastio;
+LOCAL IOPTR	inout(IOPTR lastio)
@@ -334,0 +339 @@
+		/* fallthrough */
@@ -350 +355 @@
-	iop=getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
+	iop=(IOPTR)getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
@@ -358 +363 @@
-LOCAL VOID	chkword()
+LOCAL VOID	chkword(void)
@@ -365 +370 @@
-LOCAL VOID	chksym(sym)
+LOCAL VOID	chksym(INT sym)
@@ -373 +378 @@
-LOCAL VOID	prsym(sym)
+LOCAL VOID	prsym(INT sym)
@@ -391 +396 @@
-LOCAL VOID	synbad()
+LOCAL VOID	synbad(void)

% usr/src/cmd/sh/ctype.c
@@ -12 +12 @@
-char	_ctype1[] {
+char	_ctype1[] = {
@@ -61 +61 @@
-char	_ctype2[] {
+char	_ctype2[] = {

% usr/src/cmd/sh/ctype.h
@@ -69 +69 @@
-char	_ctype1[];
+extern char	_ctype1[];
@@ -72,7 +72,7 @@
-#define	space(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(T_SPC))
-#define eofmeta(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(_META|T_EOF))
-#define qotchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(T_QOT))
-#define eolchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(T_EOR|T_EOF))
-#define dipchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(T_DIP))
-#define subchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(T_SUB|T_QOT))
-#define escchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c]&(T_ESC))
+#define	space(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(T_SPC))
+#define eofmeta(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(_META|T_EOF))
+#define qotchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(T_QOT))
+#define eolchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(T_EOR|T_EOF))
+#define dipchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(T_DIP))
+#define subchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(T_SUB|T_QOT))
+#define escchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[c&0377]&(T_ESC))
@@ -80 +80 @@
-char	_ctype2[];
+extern char	_ctype2[];
@@ -82,9 +82,9 @@
-#define	digit(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_DIG))
-#define fngchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_FNG))
-#define dolchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_AST|T_BRC|T_DIG|T_IDC|T_SHN))
-#define defchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_DEF))
-#define setchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_SET))
-#define digchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_AST|T_DIG))
-#define	letter(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_IDC))
-#define alphanum(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(_IDCH))
-#define astchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c]&(T_AST))
+#define	digit(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_DIG))
+#define fngchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_FNG))
+#define dolchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_AST|T_BRC|T_DIG|T_IDC|T_SHN))
+#define defchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_DEF))
+#define setchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_SET))
+#define digchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_AST|T_DIG))
+#define	letter(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_IDC))
+#define alphanum(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(_IDCH))
+#define astchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[c&0377]&(T_AST))

% usr/src/cmd/sh/defs.h
@@ -81,28 +81,59 @@
-ADDRESS		alloc();
-VOID		addblok();
-STRING		make();
-STRING		movstr();
-TREPTR		cmd();
-TREPTR		makefork();
-NAMPTR		lookup();
-VOID		setname();
-VOID		setargs();
-DOLPTR		useargs();
-REAL		expr();
-STRING		catpath();
-STRING		getpath();
-STRING		*scan();
-STRING		mactrim();
-STRING		macro();
-STRING		execs();
-VOID		await();
-VOID		post();
-STRING		copyto();
-VOID		exname();
-STRING		staknam();
-VOID		printnam();
-VOID		printflg();
-VOID		prs();
-VOID		prc();
-VOID		getenv();
-STRING		*setenv();
+ADDRESS		alloc(POS nbytes);
+VOID		addblok(POS reqd);
+STRING		make(STRING v);
+STRING		movstr(STRING a, STRING b);
+TREPTR		cmd(INT sym, INT flg);
+TREPTR		makefork(INT flgs, TREPTR i);
+NAMPTR		lookup(STRING nam);
+VOID		setname(STRING argi, INT xp);
+VOID		setargs(STRING argi[]);
+DOLPTR		useargs(void);
+STRING		catpath(STRING path, STRING name);
+STRING		getpath(STRING s);
+STRING		*scan(INT argn);
+STRING		mactrim(STRING s);
+STRING		macro(STRING as);
+VOID		await(INT i);
+VOID		post(INT pcsid);
+VOID		exname(NAMPTR n);
+VOID		printnam(NAMPTR n);
+VOID		printflg(NAMPTR n);
+VOID		prs(STRING as);
+VOID		prc(CHAR c);
+VOID		getenv(void);
+STRING		*setenv(void);
+INT		any(CHAR c, STRING s), builtin(void), cf(STRING s1, STRING s2),
+		chkopen(STRING idf), create(STRING s), estabf(STRING s),
+		execute(TREPTR argt, INT execflg, INT *pf1, INT *pf2),
+		expand(STRING as, INT rflg), getarg(COMPTR ac),
+		gmatch(STRING s, STRING p), ignsig(INT n), length(STRING as),
+		nextc(CHAR quote), options(INT argc, STRING *argv),
+		pathopen(STRING path, STRING name), pop(void), readc(void),
+		readvar(STRING *names), stoi(STRING icp),
+		syslook(STRING w, SYSTAB syswds), tmpfil(void), word(void),
+		alarm(unsigned sec), chdir(char *dir), close(int fd),
+		creat(char *name, int mode), dup(int fd), dup2(int fd, int fd2),
+		execve(char *name, char **argv, char **envp), fork(void),
+		getpid(void), getuid(void), ioctl(int fd, int req, void *argp),
+		open(char *name, int mode), pause(void), pipe(int *fd),
+		read(int fd, char *buf, int n), times(L_INT *t),
+		umask(int mask), unlink(char *name), wait(int *status),
+		write(int fd, char *buf, int n);
+VOID		assign(NAMPTR n, STRING v), assnum(STRING *p, INT i),
+		blank(void), chkpipe(INT *pv), chkpr(char eor), chktrap(void),
+		clearup(void), copy(IOPTR ioparg), dfault(NAMPTR n, STRING v),
+		done(void), error(STRING s), execa(STRING at[]),
+		execexp(STRING s, UFD f), exitset(void), exitsh(INT xno),
+		failed(STRING s1, STRING s2), free(void *ap), getsig(INT n),
+		initf(UFD fd), initio(IOPTR iop), itos(INT n),
+		Ldup(INT fa, INT fb), makearg(ARGPTR args),
+		namscan(VOID (*fn)(NAMPTR n)), newline(void), oldsigs(void),
+		postclr(void), prn(INT n), prp(void), prt(L_INT t),
+		push(FILE af), rename(INT f1, INT f2), replace(STRING *a, STRING v),
+		rmtemp(IOPTR base), setlist(ARGPTR arg, INT xp), settmp(void),
+		sigchk(void), stakchk(void), stdsigs(void), subst(INT in, INT ot),
+		tdystak(STKPTR x), trim(STRING at), clrsig(INT i), exit(int status);
+DOLPTR		freeargs(DOLPTR blk);
+BYTPTR		setbrk(INT incr);
+L_INT		lseek(int fd, long off, int ptr);
+STRING		sbrk(int incr);
@@ -118,4 +149,4 @@
-UFD		output;
-INT		ioset;
-IOPTR		iotemp;		/* files to be deleted sometime */
-IOPTR		iopend;		/* documents waiting to be read at NL */
+extern UFD		output;
+extern INT		ioset;
+extern IOPTR		iotemp;		/* files to be deleted sometime */
+extern IOPTR		iopend;		/* documents waiting to be read at NL */
@@ -124,4 +155,4 @@
-INT		dolc;
-STRING		*dolv;
-DOLPTR		argfor;
-ARGPTR		gchain;
+extern INT		dolc;
+extern STRING		*dolv;
+extern DOLPTR		argfor;
+extern ARGPTR		gchain;
@@ -139,9 +170,9 @@
-MSG		atline;
-MSG		readmsg;
-MSG		colon;
-MSG		minus;
-MSG		nullstr;
-MSG		sptbnl;
-MSG		unexpected;
-MSG		endoffile;
-MSG		synmsg;
+extern MSG	atline;
+extern MSG	readmsg;
+extern MSG	colon;
+extern MSG	minus;
+extern MSG	nullstr;
+extern MSG	sptbnl;
+extern MSG	unexpected;
+extern MSG	endoffile;
+extern MSG	synmsg;
@@ -150,6 +181,6 @@
-SYSTAB		reserved;
-INT		wdval;
-INT		wdnum;
-ARGPTR		wdarg;
-INT		wdset;
-BOOL		reserv;
+extern SYSTAB	reserved;
+extern INT		wdval;
+extern INT		wdnum;
+extern ARGPTR		wdarg;
+extern INT		wdset;
+extern BOOL		reserv;
@@ -158,3 +189,3 @@
-MSG		stdprompt;
-MSG		supprompt;
-MSG		profile;
+extern MSG	stdprompt;
+extern MSG	supprompt;
+extern MSG	profile;
@@ -163,7 +194,7 @@
-NAMNOD		fngnod;
-NAMNOD		ifsnod;
-NAMNOD		homenod;
-NAMNOD		mailnod;
-NAMNOD		pathnod;
-NAMNOD		ps1nod;
-NAMNOD		ps2nod;
+extern NAMNOD		fngnod;
+extern NAMNOD		ifsnod;
+extern NAMNOD		homenod;
+extern NAMNOD		mailnod;
+extern NAMNOD		pathnod;
+extern NAMNOD		ps1nod;
+extern NAMNOD		ps2nod;
@@ -172,6 +203,6 @@
-MSG		flagadr;
-STRING		cmdadr;
-STRING		exitadr;
-STRING		dolladr;
-STRING		pcsadr;
-STRING		pidadr;
+extern MSG	flagadr;
+extern STRING		cmdadr;
+extern STRING		exitadr;
+extern STRING		dolladr;
+extern STRING		pcsadr;
+extern STRING		pidadr;
@@ -179 +210 @@
-MSG		defpath;
+extern MSG	defpath;
@@ -182,7 +213,7 @@
-MSG		mailname;
-MSG		homename;
-MSG		pathname;
-MSG		fngname;
-MSG		ifsname;
-MSG		ps1name;
-MSG		ps2name;
+extern MSG	mailname;
+extern MSG	homename;
+extern MSG	pathname;
+extern MSG	fngname;
+extern MSG	ifsname;
+extern MSG	ps1name;
+extern MSG	ps2name;
@@ -191,3 +222,3 @@
-CHAR		tmpout[];
-STRING		tmpnam;
-INT		serial;
+extern CHAR	tmpout[];
+extern STRING		tmpnam;
+extern INT		serial;
@@ -195 +226 @@
-FILE		standin;
+extern FILE		standin;
@@ -198,3 +229,3 @@
-INT		peekc;
-STRING		comdiv;
-MSG		devnull;
+extern INT		peekc;
+extern STRING		comdiv;
+extern MSG	devnull;
@@ -217 +248 @@
-INT		flags;
+extern INT		flags;
@@ -221,2 +252,2 @@
-jmp_buf		subshell;
-jmp_buf		errshell;
+extern jmp_buf		subshell;
+extern jmp_buf		errshell;
@@ -226 +257,2 @@
-POS		brkincr;
+#include	<signal.h>
+extern POS		brkincr;
@@ -240,4 +272,4 @@
-VOID		fault();
-BOOL		trapnote;
-STRING		trapcom[];
-BOOL		trapflg[];
+VOID		fault(INT sig);
+extern BOOL		trapnote;
+extern STRING	trapcom[];
+extern BOOL	trapflg[];
@@ -246,4 +278,4 @@
-STRING		*environ;
-CHAR		numbuf[];
-MSG		export;
-MSG		readonly;
+extern STRING		*environ;
+extern CHAR	numbuf[];
+extern MSG	export;
+extern MSG	readonly;
@@ -252,4 +284,4 @@
-INT		exitval;
-BOOL		execbrk;
-INT		loopcnt;
-INT		breakcnt;
+extern INT		exitval;
+extern INT		execbrk;
+extern INT		loopcnt;
+extern INT		breakcnt;
@@ -258,25 +290,25 @@
-MSG		mailmsg;
-MSG		coredump;
-MSG		badopt;
-MSG		badparam;
-MSG		badsub;
-MSG		nospace;
-MSG		notfound;
-MSG		badtrap;
-MSG		baddir;
-MSG		badshift;
-MSG		illegal;
-MSG		restricted;
-MSG		execpmsg;
-MSG		notid;
-MSG		wtfailed;
-MSG		badcreate;
-MSG		piperr;
-MSG		badopen;
-MSG		badnum;
-MSG		arglist;
-MSG		txtbsy;
-MSG		toobig;
-MSG		badexec;
-MSG		notfound;
-MSG		badfile;
+extern MSG	mailmsg;
+extern MSG	coredump;
+extern MSG	badopt;
+extern MSG	badparam;
+extern MSG	badsub;
+extern MSG	nospace;
+extern MSG	notfound;
+extern MSG	badtrap;
+extern MSG	baddir;
+extern MSG	badshift;
+extern MSG	illegal;
+extern MSG	restricted;
+extern MSG	execpmsg;
+extern MSG	notid;
+extern MSG	wtfailed;
+extern MSG	badcreate;
+extern MSG	piperr;
+extern MSG	badopen;
+extern MSG	badnum;
+extern MSG	arglist;
+extern MSG	txtbsy;
+extern MSG	toobig;
+extern MSG	badexec;
+extern MSG	notfound;
+extern MSG	badfile;
@@ -284 +316 @@
-address	end[];
+extern address	end[];

% usr/src/cmd/sh/dup.h

% usr/src/cmd/sh/error.c
@@ -15 +15,2 @@
-exitset()
+VOID
+exitset(void)
@@ -20 +21,2 @@
-sigchk()
+VOID
+sigchk(void)
@@ -31,2 +33,2 @@
-failed(s1,s2)
-	STRING	s1, s2;
+VOID
+failed(STRING s1, STRING s2)
@@ -41,2 +43,2 @@
-error(s)
-	STRING	s;
+VOID
+error(STRING s)
@@ -47,2 +49,2 @@
-exitsh(xno)
-	INT	xno;
+VOID
+exitsh(INT xno)
@@ -65 +67,2 @@
-done()
+VOID
+done(void)
@@ -68 +71 @@
-	IF t=trapcom[0]
+	IF (t=trapcom[0])
@@ -76,2 +79,2 @@
-rmtemp(base)
-	IOPTR		base;
+VOID
+rmtemp(IOPTR base)

% usr/src/cmd/sh/expand.c
@@ -27 +27 @@
-PROC VOID	addg();
+LOCAL VOID	addg(STRING as1, STRING as2, STRING as3);
@@ -30,2 +30 @@
-INT	expand(as,rflg)
-	STRING		as;
+INT	expand(STRING as, INT rflg)
@@ -80 +79 @@
-		WHILE read(dirf, &entry, 16) == 16 ANDF (trapnote&SIGSET) == 0
+		WHILE read(dirf, (char *)&entry, 16) == 16 ANDF (trapnote&SIGSET) == 0
@@ -108 +107 @@
-	   WHILE c = *s
+	   WHILE (c = *s)
@@ -114,2 +113,2 @@
-gmatch(s, p)
-	REG STRING	s, p;
+INT
+gmatch(REG STRING s, REG STRING p)
@@ -120 +119 @@
-	IF scc = *s++
+	IF (scc = *s++)
@@ -130 +129 @@
-		WHILE c = *p++
+		WHILE (c = *p++)
@@ -134 +133 @@
-			THEN	IF lc<=scc ANDF scc<=(*p++) THEN ok++ FI
+			THEN	IF lc<=scc ANDF scc<=((*p++)&STRIP) THEN ok++ FI
@@ -142,0 +142 @@
+		/* fallthrough */
@@ -159,2 +159 @@
-LOCAL VOID	addg(as1,as2,as3)
-	STRING		as1, as2, as3;
+LOCAL VOID	addg(STRING as1, STRING as2, STRING as3)
@@ -168 +167 @@
-	WHILE c = *s1++
+	WHILE (c = *s1++)
@@ -176,2 +175,2 @@
-	WHILE *s2 = *s1++ DO s2++ OD
-	IF s1=as3
+	WHILE (*s2 = *s1++) DO s2++ OD
+	IF (s1=as3)
@@ -179 +178 @@
-		WHILE *s2++ = *++s1 DONE
+		WHILE (*s2++ = *++s1) DONE
@@ -181 +180 @@
-	makearg(endstak(s2));
+	makearg((ARGPTR)endstak(s2));
@@ -184,2 +183,2 @@
-makearg(args)
-	REG STRING	args;
+VOID
+makearg(REG ARGPTR args)

% usr/src/cmd/sh/fault.c
@@ -19,2 +19 @@
-VOID	fault(sig)
-	REG INT		sig;
+VOID	fault(REG INT sig)
@@ -26 +25 @@
-	THEN	IF setbrk(brkincr) == -1
+	THEN	IF setbrk(brkincr) == (BYTPTR)-1
@@ -39 +38,2 @@
-stdsigs()
+VOID
+stdsigs(void)
@@ -47 +47,2 @@
-ignsig(n)
+INT
+ignsig(INT n)
@@ -51 +52 @@
-	IF (s=signal(i=n,1)&01)==0
+	IF (s=signal(i=n,SIG_IGN)==SIG_IGN)==0
@@ -57 +58,2 @@
-getsig(n)
+VOID
+getsig(INT n)
@@ -66 +68,2 @@
-oldsigs()
+VOID
+oldsigs(void)
@@ -82,2 +85,2 @@
-clrsig(i)
-	INT		i;
+VOID
+clrsig(INT i)
@@ -92 +95,2 @@
-chktrap()
+VOID
+chktrap(void)
@@ -102 +106 @@
-		IF t=trapcom[i]
+		IF (t=trapcom[i])

% usr/src/cmd/sh/io.c
@@ -16,2 +16,2 @@
-initf(fd)
-	UFD		fd;
+VOID
+initf(UFD fd)
@@ -26,2 +26,2 @@
-estabf(s)
-	REG STRING	s;
+INT
+estabf(REG STRING s)
@@ -37,2 +37,2 @@
-push(af)
-	FILE		af;
+VOID
+push(FILE af)
@@ -47 +47,2 @@
-pop()
+INT
+pop(void)
@@ -59,2 +60,2 @@
-chkpipe(pv)
-	INT		*pv;
+VOID
+chkpipe(INT *pv)
@@ -67,2 +68,2 @@
-chkopen(idf)
-	STRING		idf;
+INT
+chkopen(STRING idf)
@@ -75,0 +77 @@
+	return(0);
@@ -78,2 +80,2 @@
-rename(f1,f2)
-	REG INT		f1, f2;
+VOID
+rename(REG INT f1, REG INT f2)
@@ -82 +84 @@
-	THEN	dup(f1|DUPFLG, f2);
+	THEN	dup2(f1, f2);
@@ -88,2 +90,2 @@
-create(s)
-	STRING		s;
+INT
+create(STRING s)
@@ -96,0 +99 @@
+	return(0);
@@ -99 +102,2 @@
-tmpfil()
+INT
+tmpfil(void)
@@ -106 +110 @@
-BOOL		nosubst;
+extern BOOL	nosubst;
@@ -108,2 +112,2 @@
-copy(ioparg)
-	IOPTR		ioparg;
+VOID
+copy(IOPTR ioparg)
@@ -116 +120 @@
-	IF iop=ioparg
+	IF (iop=ioparg)

% usr/src/cmd/sh/mac.h

% usr/src/cmd/sh/macro.c
@@ -14,0 +15,2 @@
+LOCAL INT	getch(CHAR endch);
+LOCAL VOID	comsubst(void), flush(INT ot);
@@ -18,2 +20 @@
-LOCAL STRING	copyto(endch)
-	REG CHAR	endch;
+LOCAL VOID	copyto(REG CHAR endch)
@@ -29,2 +30 @@
-LOCAL	skipto(endch)
-	REG CHAR	endch;
+LOCAL VOID	skipto(REG CHAR endch)
@@ -49,2 +49 @@
-LOCAL	getch(endch)
-	CHAR		endch;
+LOCAL INT	getch(CHAR endch)
@@ -62 +61 @@
-		THEN	NAMPTR		n=NIL;
+		THEN	NAMPTR		n=0;
@@ -65 +64 @@
-			REG STRING	argp, v;
+			REG STRING	argp, v=0;
@@ -69 +68 @@
-			IF bra=(c==BRACE) THEN c=readc() FI
+			IF (bra=(c==BRACE)) THEN c=readc() FI
@@ -71 +70 @@
-			THEN	argp=relstak();
+			THEN	argp=(STRING)relstak();
@@ -83 +82 @@
-				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (dolg=0));
+				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (STRING)(dolg=0));
@@ -104 +103 @@
-				THEN	argp=relstak();
+				THEN	argp=(STRING)relstak();
@@ -115 +114 @@
-				THEN	LOOP WHILE c = *v++
+				THEN	LOOP WHILE (c = *v++)
@@ -148,2 +147 @@
-STRING	macro(as)
-	STRING		as;
+STRING	macro(STRING as)
@@ -158 +156 @@
-	push(&fb); estabf(as);
+	push((FILE)&fb); estabf(as);
@@ -168 +166 @@
-LOCAL	comsubst()
+LOCAL VOID	comsubst(void)
@@ -197 +195 @@
-	WHILE d=readc() DO pushstak(d|quote) OD
+	WHILE (d=readc()) DO pushstak(d|quote) OD
@@ -209,2 +207,2 @@
-subst(in,ot)
-	INT		in, ot;
+VOID
+subst(INT in, INT ot)
@@ -218 +216 @@
-	WHILE c=(getch(DQUOTE)&STRIP)
+	WHILE (c=(getch(DQUOTE)&STRIP))
@@ -228 +226 @@
-LOCAL	flush(ot)
+LOCAL VOID	flush(INT ot)

% usr/src/cmd/sh/main.c
@@ -22,0 +23,8 @@
+INT		ioset, dolc, wdval, wdnum, wdset, serial, peekc, flags;
+INT		exitval, execbrk, loopcnt, breakcnt;
+IOPTR		iotemp, iopend;
+STRING		*dolv, cmdadr, exitadr, dolladr, pcsadr, pidadr, tmpnam, comdiv;
+DOLPTR		argfor;
+ARGPTR		gchain, wdarg;
+BOOL		reserv, trapnote;
+jmp_buf		subshell, errshell;
@@ -25 +33 @@
-PROC VOID	exfile();
+LOCAL VOID	exfile(BOOL prof);
@@ -30,3 +38,2 @@
-main(c, v)
-	INT		c;
-	STRING		v[];
+int
+main(INT c, STRING v[])
@@ -85 +92 @@
-	ELSE	*execargs=dolv;	/* for `ps' cmd */
+	ELSE	*execargs=(char *)dolv;	/* for `ps' cmd */
@@ -92,2 +99 @@
-LOCAL VOID	exfile(prof)
-BOOL		prof;
+LOCAL VOID	exfile(BOOL prof)
@@ -95 +101 @@
-	REG L_INT	mailtime = 0;
+	volatile L_INT	mailtime = 0;
@@ -114 +120 @@
-	IF (flags&intflg) ORF ((flags&oneflg)==0 ANDF gtty(output,&statb)==0 ANDF gtty(input,&statb)==0)
+	IF (flags&intflg) ORF ((flags&oneflg)==0 ANDF gtty(output,(struct sgttyb *)&statb)==0 ANDF gtty(input,(struct sgttyb *)&statb)==0)
@@ -149 +155 @@
-		execute(cmd(NL,MTFLG),0);
+		execute(cmd(NL,MTFLG),0,0,0);
@@ -154,2 +160,2 @@
-chkpr(eor)
-char eor;
+VOID
+chkpr(char eor)
@@ -162 +168,2 @@
-settmp()
+VOID
+settmp(void)
@@ -168,2 +175,2 @@
-Ldup(fa, fb)
-	REG INT		fa, fb;
+VOID
+Ldup(REG INT fa, REG INT fb)
@@ -171 +178 @@
-	dup(fa|DUPFLG, fb);
+	dup2(fa, fb);

% usr/src/cmd/sh/mode.h
@@ -16 +16 @@
-TYPE int	VOID;
+TYPE void	VOID;
@@ -46 +45,0 @@
-STRUCT sysnod	SYSTAB[];
@@ -55 +53,0 @@
-union { int _cheat;};
@@ -75,2 +72,0 @@
-/* for functions that do not return values */
-struct void {INT vvvvvvvv;};
@@ -113,0 +110 @@
+STRUCT sysnod	SYSTAB[];

% usr/src/cmd/sh/msg.c
@@ -70 +70 @@
-SYSTAB reserved {
+SYSTAB reserved = {
@@ -89 +89 @@
-STRING	sysmsg[] {
+STRING	sysmsg[] = {
@@ -111 +111 @@
-SYSTAB	commands {
+SYSTAB	commands = {

% usr/src/cmd/sh/name.c
@@ -12 +12,2 @@
-PROC BOOL	chkid();
+LOCAL BOOL	chkid(STRING nam);
+LOCAL VOID	namwalk(NAMPTR np);
@@ -15,7 +16,7 @@
-NAMNOD	ps2nod	= {	NIL,		NIL,		ps2name},
-	fngnod	= {	NIL,		NIL,		fngname},
-	pathnod = {	NIL,		NIL,		pathname},
-	ifsnod	= {	NIL,		NIL,		ifsname},
-	ps1nod	= {	&pathnod,	&ps2nod,	ps1name},
-	homenod = {	&fngnod,	&ifsnod,	homename},
-	mailnod = {	&homenod,	&ps1nod,	mailname};
+NAMNOD	ps2nod	= {	0,		0,		ps2name,0,0,0},
+	fngnod	= {	0,		0,		fngname,0,0,0},
+	pathnod = {	0,		0,		pathname,0,0,0},
+	ifsnod	= {	0,		0,		ifsname,0,0,0},
+	ps1nod	= {	&pathnod,	&ps2nod,	ps1name,0,0,0},
+	homenod = {	&fngnod,	&ifsnod,	homename,0,0,0},
+	mailnod = {	&homenod,	&ps1nod,	mailname,0,0,0};
@@ -28,3 +29,2 @@
-syslook(w,syswds)
-	STRING		w;
-	SYSTAB		syswds;
+INT
+syslook(STRING w, SYSTAB syswds)
@@ -38 +38 @@
-	WHILE s=syscan->sysnam
+	WHILE (s=syscan->sysnam)
@@ -48,3 +48,2 @@
-setlist(arg,xp)
-	REG ARGPTR	arg;
-	INT		xp;
+VOID
+setlist(REG ARGPTR arg, INT xp)
@@ -63,3 +62 @@
-VOID	setname(argi, xp)
-	STRING		argi;
-	INT		xp;
+VOID	setname(STRING argi, INT xp)
@@ -87,3 +84,2 @@
-replace(a, v)
-	REG STRING	*a;
-	STRING		v;
+VOID
+replace(REG STRING *a, STRING v)
@@ -94,3 +90,2 @@
-dfault(n,v)
-	NAMPTR		n;
-	STRING		v;
+VOID
+dfault(NAMPTR n, STRING v)
@@ -103,3 +98,2 @@
-assign(n,v)
-	NAMPTR		n;
-	STRING		v;
+VOID
+assign(NAMPTR n, STRING v)
@@ -113,2 +107 @@
-INT	readvar(names)
-	STRING		*names;
+INT	readvar(STRING *names)
@@ -121 +114 @@
-	STKPTR		rel=relstak();
+	STKPTR		rel=(STKPTR)relstak();
@@ -153,3 +146,2 @@
-assnum(p, i)
-	STRING		*p;
-	INT		i;
+VOID
+assnum(STRING *p, INT i)
@@ -160,2 +152 @@
-STRING	make(v)
-	STRING		v;
+STRING	make(STRING v)
@@ -173,2 +164 @@
-NAMPTR		lookup(nam)
-	REG STRING	nam;
+NAMPTR		lookup(REG STRING nam)
@@ -177 +167 @@
-	REG NAMPTR	*prev;
+	REG NAMPTR	*prev = 0;
@@ -194,2 +184,2 @@
-	nscan=alloc(sizeof *nscan);
-	nscan->namlft=nscan->namrgt=NIL;
+	nscan=(NAMPTR)alloc(sizeof *nscan);
+	nscan->namlft=nscan->namrgt=0;
@@ -201,2 +191 @@
-LOCAL BOOL	chkid(nam)
-	STRING		nam;
+LOCAL BOOL	chkid(STRING nam)
@@ -217,3 +206,3 @@
-LOCAL VOID (*namfn)();
-namscan(fn)
-	VOID		(*fn)();
+LOCAL VOID (*namfn)(NAMPTR n);
+VOID
+namscan(VOID (*fn)(NAMPTR n))
@@ -225,2 +214 @@
-LOCAL VOID	namwalk(np)
-	REG NAMPTR	np;
+LOCAL VOID	namwalk(REG NAMPTR np)
@@ -235,2 +223 @@
-VOID	printnam(n)
-	NAMPTR		n;
+VOID	printnam(NAMPTR n)
@@ -241 +228 @@
-	IF s=n->namval
+	IF (s=n->namval)
@@ -248,2 +235 @@
-LOCAL STRING	staknam(n)
-	REG NAMPTR	n;
+LOCAL STRING	staknam(REG NAMPTR n)
@@ -259,2 +245 @@
-VOID	exname(n)
-	REG NAMPTR	n;
+VOID	exname(REG NAMPTR n)
@@ -270,2 +255 @@
-VOID	printflg(n)
-	REG NAMPTR		n;
+VOID	printflg(REG NAMPTR n)
@@ -284 +268 @@
-VOID	getenv()
+VOID	getenv(void)
@@ -294,2 +278 @@
-VOID	countnam(n)
-	NAMPTR		n;
+LOCAL VOID	countnam(NAMPTR n)
@@ -296,0 +280 @@
+	(void)n;
@@ -302,2 +286 @@
-VOID	pushnam(n)
-	NAMPTR		n;
+LOCAL VOID	pushnam(NAMPTR n)
@@ -310 +293 @@
-STRING	*setenv()
+STRING	*setenv(void)
@@ -316 +299 @@
-	argnam = er = getstak(namec*BYTESPERWORD+BYTESPERWORD);
+	argnam = er = (STRING *)getstak(namec*BYTESPERWORD+BYTESPERWORD);

% usr/src/cmd/sh/name.h

% usr/src/cmd/sh/print.c
@@ -12 +12 @@
-CHAR		numbuf[6];
+CHAR		numbuf[11];
@@ -17 +17,2 @@
-newline()
+VOID
+newline(void)
@@ -21 +22,2 @@
-blank()
+VOID
+blank(void)
@@ -25 +27,2 @@
-prp()
+VOID
+prp(void)
@@ -32,2 +35 @@
-VOID	prs(as)
-	STRING		as;
+VOID	prs(STRING as)
@@ -37 +39 @@
-	IF s=as
+	IF (s=as)
@@ -42,2 +44 @@
-VOID	prc(c)
-	CHAR		c;
+VOID	prc(CHAR c)
@@ -50,2 +51,2 @@
-prt(t)
-	L_INT		t;
+VOID
+prt(L_INT t)
@@ -58 +59 @@
-	IF hr=t/60
+	IF (hr=t/60)
@@ -65,2 +66,2 @@
-prn(n)
-	INT		n;
+VOID
+prn(INT n)
@@ -71 +72,2 @@
-itos(n)
+VOID
+itos(INT n)
@@ -75 +77 @@
-	FOR i=10000; i!=1; i/=10
+	FOR i=1000000000; i!=1; i/=10
@@ -83,2 +85,2 @@
-stoi(icp)
-STRING	icp;
+INT
+stoi(STRING icp)
@@ -91 +93 @@
-	DO r = r*10 + c - '0'; cp++ OD
+	DO r = r <= ((INT)(~0u>>1) - (c - '0'))/10 ? r*10 + c - '0' : -1; cp++ OD
@@ -95,0 +98 @@
+	return(0);

% usr/src/cmd/sh/service.c
@@ -13 +13,3 @@
-PROC VOID	gsort();
+LOCAL VOID	gsort(STRING from[], STRING to[]);
+LOCAL STRING	execs(STRING ap, STRING t[]);
+LOCAL INT	split(STRING s);
@@ -17,2 +19,2 @@
-INT		errno;
-STRING		sysmsg[];
+extern INT	errno;
+extern STRING	sysmsg[];
@@ -31,2 +33 @@
-VOID	initio(iop)
-	IOPTR		iop;
+VOID	initio(IOPTR iop)
@@ -35 +36 @@
-	REG INT		iof, fd;
+	REG INT		iof, fd = -1;
@@ -68,2 +69 @@
-STRING	getpath(s)
-	STRING		s;
+STRING	getpath(STRING s)
@@ -80,0 +81 @@
+	return(0);
@@ -83,2 +84 @@
-INT	pathopen(path, name)
-	REG STRING	path, name;
+INT	pathopen(REG STRING path, REG STRING name)
@@ -93,3 +93 @@
-STRING	catpath(path,name)
-	REG STRING	path;
-	STRING		name;
+STRING	catpath(REG STRING path, STRING name)
@@ -112,2 +110 @@
-VOID	execa(at)
-	STRING		at[];
+VOID	execa(STRING at[])
@@ -122 +119 @@
-		WHILE path=execs(path,t) DONE
+		WHILE (path=execs(path,t)) DONE
@@ -127,3 +124 @@
-LOCAL STRING	execs(ap,t)
-	STRING		ap;
-	REG STRING	t[];
+LOCAL STRING	execs(STRING ap, REG STRING t[])
@@ -150,0 +146 @@
+		/* fallthrough */
@@ -153,0 +150 @@
+		/* fallthrough */
@@ -156,0 +154 @@
+		/* fallthrough */
@@ -159,0 +158 @@
+		/* fallthrough */
@@ -162,0 +162 @@
+		/* fallthrough */
@@ -173 +173,2 @@
-postclr()
+VOID
+postclr(void)
@@ -182,2 +183 @@
-VOID	post(pcsid)
-	INT		pcsid;
+VOID	post(INT pcsid)
@@ -197,2 +197 @@
-VOID	await(i)
-	INT		i;
+VOID	await(INT i)
@@ -225 +224 @@
-		IF sig = w&0177
+		IF (sig = w&0177)
@@ -252,2 +251,2 @@
-trim(at)
-	STRING		at;
+VOID
+trim(STRING at)
@@ -259,2 +258,2 @@
-	IF p=at
-	THEN	WHILE c = *p
+	IF (p=at)
+	THEN	WHILE (c = *p)
@@ -266,2 +265 @@
-STRING	mactrim(s)
-	STRING		s;
+STRING	mactrim(STRING s)
@@ -274,2 +272 @@
-STRING	*scan(argn)
-	INT		argn;
+STRING	*scan(INT argn)
@@ -277 +274 @@
-	REG ARGPTR	argp = Rcheat(gchain)&~ARGMK;
+	REG ARGPTR	argp = (ARGPTR)(Rcheat(gchain)&~ARGMK);
@@ -280 +277 @@
-	comargn=getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;
+	comargn=(STRING *)getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;
@@ -284 +281 @@
-		IF argp = argp->argnxt
+		IF (argp = argp->argnxt)
@@ -292 +289 @@
-		argp = Rcheat(argp)&~ARGMK;
+		argp = (ARGPTR)(Rcheat(argp)&~ARGMK);
@@ -297,2 +294 @@
-LOCAL VOID	gsort(from,to)
-	STRING		from[], to[];
+LOCAL VOID	gsort(STRING from[], STRING to[])
@@ -323,2 +319 @@
-INT	getarg(ac)
-	COMPTR		ac;
+INT	getarg(COMPTR ac)
@@ -330 +325 @@
-	IF c=ac
+	IF (c=ac)
@@ -340,2 +335 @@
-LOCAL INT	split(s)
-	REG STRING	s;
+LOCAL INT	split(REG STRING s)
@@ -358 +352 @@
-		IF c=expand((argp=endstak(argp))->argval,0)
+		IF (c=expand(((ARGPTR)(argp=endstak(argp)))->argval,0))
@@ -361 +355 @@
-			makearg(argp); count++;
+			makearg((ARGPTR)argp); count++;
@@ -363 +357 @@
-		Lcheat(gchain) |= ARGMK;
+		gchain=(ARGPTR)(Rcheat(gchain)|ARGMK);

% usr/src/cmd/sh/setbrk.c
@@ -12 +12,2 @@
-setbrk(incr)
+BYTPTR
+setbrk(INT incr)

% usr/src/cmd/sh/stak.c
@@ -12,0 +13,2 @@
+BLKPTR		stakbsy;
+STKPTR		stakbas, brkend, staktop;
@@ -18,2 +20 @@
-STKPTR	getstak(asize)
-	INT		asize;
+STKPTR	getstak(INT asize)
@@ -30 +31 @@
-STKPTR	locstak()
+STKPTR	locstak(void)
@@ -43 +44 @@
-STKPTR	savstak()
+STKPTR	savstak(void)
@@ -49,2 +50 @@
-STKPTR	endstak(argp)
-	REG STRING	argp;
+STKPTR	endstak(REG STRING argp)
@@ -54 +54 @@
-	oldstak=stakbot; stakbot=staktop=round(argp,BYTESPERWORD);
+	oldstak=stakbot; stakbot=staktop=(STKPTR)round(argp,BYTESPERWORD);
@@ -58,2 +58 @@
-VOID	tdystak(x)
-	REG STKPTR 	x;
+VOID	tdystak(REG STKPTR x)
@@ -67 +66 @@
-	rmtemp(x);
+	rmtemp((IOPTR)x);
@@ -70 +69,2 @@
-stakchk()
+VOID
+stakchk(void)
@@ -77,2 +77 @@
-STKPTR	cpystak(x)
-	STKPTR		x;
+STKPTR	cpystak(STKPTR x)

% usr/src/cmd/sh/stak.h
@@ -37 +37 @@
-STKPTR		locstak();
+STKPTR		locstak(void);
@@ -47 +47 @@
-STKPTR		endstak();
+STKPTR		endstak(STRING argp);
@@ -52 +52 @@
-STKPTR		cpystak();
+STKPTR		cpystak(STKPTR x);
@@ -55 +55 @@
-STKPTR		getstak();
+STKPTR		getstak(INT asize);
@@ -61 +61 @@
-BLKPTR		stakbsy;
+extern BLKPTR		stakbsy;
@@ -64 +64 @@
-STKPTR		stakbas;
+extern STKPTR		stakbas;
@@ -67 +67 @@
-STKPTR		brkend;
+extern STKPTR		brkend;
@@ -70 +70 @@
-STKPTR		stakbot;
+extern STKPTR		stakbot;
@@ -73 +73 @@
-STKPTR		staktop;
+extern STKPTR		staktop;
@@ -76 +76 @@
-STKPTR		savstak();
+STKPTR		savstak(void);

% usr/src/cmd/sh/string.c
@@ -16,2 +16 @@
-STRING	movstr(a,b)
-	REG STRING	a, b;
+STRING	movstr(REG STRING a, REG STRING b)
@@ -19 +18 @@
-	WHILE *b++ = *a++ DONE
+	WHILE (*b++ = *a++) DONE
@@ -23,3 +22 @@
-INT	any(c,s)
-	REG CHAR	c;
-	STRING		s;
+INT	any(REG CHAR c, STRING s)
@@ -29 +26 @@
-	WHILE d = *s++
+	WHILE (d = *s++)
@@ -37,2 +34 @@
-INT	cf(s1, s2)
-	REG STRING s1, s2;
+INT	cf(REG STRING s1, REG STRING s2)
@@ -48,2 +44 @@
-INT	length(as)
-	STRING as;
+INT	length(STRING as)
@@ -53 +48 @@
-	IF s=as THEN WHILE *s++ DONE FI
+	IF (s=as) THEN WHILE *s++ DONE FI

% usr/src/cmd/sh/sym.h

% usr/src/cmd/sh/timeout.h

% usr/src/cmd/sh/word.c
@@ -11,0 +12 @@
+LOCAL INT	readb(void);
@@ -17 +18,2 @@
-word()
+INT
+word(void)
@@ -20,0 +23 @@
+	REG ARGPTR	arg;
@@ -42,2 +45,2 @@
-		argp=endstak(argp);
-		IF !letter(argp->argval[0]) THEN wdset=0 FI
+		arg=(ARGPTR)endstak(argp);
+		IF !letter(arg->argval[0]) THEN wdset=0 FI
@@ -46 +49 @@
-		IF argp->argval[1]==0 ANDF (d=argp->argval[0], digit(d)) ANDF (c=='>' ORF c=='<')
+		IF arg->argval[1]==0 ANDF (d=arg->argval[0], digit(d)) ANDF (c=='>' ORF c=='<')
@@ -49,2 +52,2 @@
-			IF reserv==FALSE ORF (wdval=syslook(argp->argval,reserved))==0
-			THEN	wdarg=argp; wdval=0;
+			IF reserv==FALSE ORF (wdval=syslook(arg->argval,reserved))==0
+			THEN	wdarg=arg; wdval=0;
@@ -70,2 +73,2 @@
-nextc(quote)
-	CHAR		quote;
+INT
+nextc(CHAR quote)
@@ -85 +88,2 @@
-readc()
+INT
+readc(void)
@@ -116 +120 @@
-LOCAL	readb()
+LOCAL INT	readb(void)

% usr/src/cmd/sh/xec.c
@@ -15 +15 @@
-SYSTAB		commands;
+extern SYSTAB	commands;
@@ -22,3 +22,2 @@
-execute(argt, execflg, pf1, pf2)
-	TREPTR		argt;
-	INT		*pf1, *pf2;
+INT
+execute(TREPTR argt, INT execflg, INT *pf1, INT *pf2)
@@ -35 +34 @@
-		REG STRING	*com;
+		REG STRING	*com = 0;
@@ -43,0 +43 @@
+			COMPTR		c=(COMPTR)t;
@@ -47 +47 @@
-			IOPTR		io=t->treio;
+			IOPTR		io=c->comio;
@@ -49 +49 @@
-			argn = getarg(t);
+			argn = getarg(c);
@@ -53,2 +53,2 @@
-			IF (internal=syslook(com[0],commands)) ORF argn==0
-			THEN	setlist(t->comset, 0);
+			IF ((internal=syslook(com[0],commands)) ORF argn==0)
+			THEN	setlist(c->comset, 0);
@@ -87,0 +88 @@
+					break;
@@ -135,0 +137 @@
+					/* fallthrough */
@@ -139,0 +142 @@
+					break;
@@ -178 +181 @@
-					ELIF t->comset==0
+					ELIF c->comset==0
@@ -185,0 +189 @@
+					/* fallthrough */
@@ -199 +203 @@
-					THEN	execexp(a1,&com[2]);
+					THEN	execexp(a1,(UFD)&com[2]);
@@ -205 +209 @@
-                                                int c, i
+                                                int c, i;
@@ -222 +226 @@
-					internal=builtin(argn,com);
+					internal=builtin();
@@ -231 +235 @@
-			ELIF t->treio==0
+			ELIF c->comio==0
@@ -234,0 +239 @@
+			/* fallthrough */
@@ -271 +276 @@
-				THEN	signal(INTR,1); signal(QUIT,1);
+				THEN	signal(INTR,SIG_IGN); signal(QUIT,SIG_IGN);
@@ -292 +297 @@
-				THEN	execute(t->forktre,1);
+				THEN	execute(((FORKPTR)t)->forktre,1,0,0);
@@ -294 +299 @@
-				THEN	setlist(t->comset,N_EXPORT);
+				THEN	setlist(((COMPTR)t)->comset,N_EXPORT);
@@ -298,0 +304 @@
+			break;
@@ -302 +308 @@
-			execute(t->partre,execflg);
+			execute(((PARPTR)t)->partre,execflg,0,0);
@@ -303,0 +310 @@
+			break;
@@ -306,0 +314 @@
+			   REG LSTPTR	l=(LSTPTR)t;
@@ -308,2 +316,2 @@
-			   IF execute(t->lstlef, 0, pf1, pv)==0
-			   THEN	execute(t->lstrit, execflg, pv, pf2);
+			   IF execute(l->lstlef, 0, pf1, pv)==0
+			   THEN	execute(l->lstrit, execflg, pv, pf2);
@@ -316,2 +324,2 @@
-			execute(t->lstlef,0);
-			execute(t->lstrit,execflg);
+			execute(((LSTPTR)t)->lstlef,0,0,0);
+			execute(((LSTPTR)t)->lstrit,execflg,0,0);
@@ -321,2 +329,2 @@
-			IF execute(t->lstlef,0)==0
-			THEN	execute(t->lstrit,execflg);
+			IF execute(((LSTPTR)t)->lstlef,0,0,0)==0
+			THEN	execute(((LSTPTR)t)->lstrit,execflg,0,0);
@@ -327,2 +335,2 @@
-			IF execute(t->lstlef,0)!=0
-			THEN	execute(t->lstrit,execflg);
+			IF execute(((LSTPTR)t)->lstlef,0,0,0)!=0
+			THEN	execute(((LSTPTR)t)->lstrit,execflg,0,0);
@@ -334 +342,2 @@
-			   NAMPTR	n = lookup(t->fornam);
+			   REG FORPTR	f=(FORPTR)t;
+			   NAMPTR	n = lookup(f->fornam);
@@ -338 +347 @@
-			   IF t->forlst==0
+			   IF f->forlst==0
@@ -343 +352 @@
-				   trim((args=scan(getarg(t->forlst)))[0]);
+				   trim((args=scan(getarg(f->forlst)))[0]);
@@ -349 +358 @@
-				execute(t->fortre,0);
+				execute(f->fortre,0,0,0);
@@ -360,0 +370 @@
+			   REG WHPTR	w=(WHPTR)t;
@@ -364,2 +374,2 @@
-			   WHILE execbrk==0 ANDF (execute(t->whtre,0)==0)==(type==TWH)
-			   DO i=execute(t->dotre,0);
+			   WHILE execbrk==0 ANDF (execute(w->whtre,0,0,0)==0)==(type==TWH)
+			   DO i=execute(w->dotre,0,0,0);
@@ -374,3 +384,3 @@
-			IF execute(t->iftre,0)==0
-			THEN	execute(t->thtre,execflg);
-			ELSE	execute(t->eltre,execflg);
+			IF execute(((IFPTR)t)->iftre,0,0,0)==0
+			THEN	execute(((IFPTR)t)->thtre,execflg,0,0);
+			ELSE	execute(((IFPTR)t)->eltre,execflg,0,0);
@@ -382,2 +392,3 @@
-			   REG STRING	r = mactrim(t->swarg);
-			   t=t->swlst;
+			   REG SWPTR	s=(SWPTR)t;
+			   REG STRING	r = mactrim(s->swarg);
+			   t=(TREPTR)s->swlst;
@@ -385 +396,2 @@
-			   DO	ARGPTR		rex=t->regptr;
+			   DO	REG REGPTR	re=(REGPTR)t;
+				ARGPTR		rex=re->regptr;
@@ -389 +401 @@
-					THEN	execute(t->regcom,0);
+					THEN	execute(re->regcom,0,0,0);
@@ -394 +406 @@
-				IF t THEN t=t->regnxt FI
+				IF t THEN t=(TREPTR)re->regnxt FI
@@ -408,3 +420,2 @@
-execexp(s,f)
-	STRING		s;
-	UFD		f;
+VOID
+execexp(STRING s, UFD f)
@@ -415 +426 @@
-	THEN	estabf(s); fb.feval=f;
+	THEN	estabf(s); fb.feval=(STRING *)f;
@@ -419 +430 @@
-	execute(cmd(NL, NLFLG|MTFLG),0);
+	execute(cmd(NL, NLFLG|MTFLG),0,0,0);

% usr/src/cmd/sleep.c
@@ -1,2 +1,3 @@
-main(argc, argv)
-char **argv;
+#include <stdio.h>
+int
+main(int argc, char **argv)
@@ -13 +14 @@
-	while(c = *s++) {
+	while((c = *s++)) {

% usr/src/cmd/sort.c
@@ -5,0 +6 @@
+#define	qsort	sort_qsort
@@ -24,4 +25,3 @@
-int	cmp(), cmpa();
-int	(*compare)() = cmpa;
-char	*eol();
-int	term();
+int	cmp(char *i, char *j), cmpa(char *pa, char *pb);
+int	(*compare)(char *a, char *b) = cmpa;
+char	*eol(char *p);
@@ -160,3 +160,3 @@
-	0,0,
-	0,-1,
-	0,0
+	{0,0},
+	{0,-1},
+	{0,0}
@@ -166,3 +166,8 @@
-char	*setfil();
-char	*sbrk();
-char	*brk();
+char	*setfil(int i);
+char	*brk(char *addr);
+void	copyproto(void), field(char *s, int k), diag(char *s, char *t);
+void	safeoutfil(void), sort(void), newfile(void), merge(int a, int b);
+void	oldfile(void), disorder(char *s, char *t), cant(char *f), term(int sig);
+void	qsort(char **a, char **l);
+int	blank(int c), number(char **ppa);
+char	*skip(char *pp, struct field *fp, int j);
@@ -170,2 +175,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -173 +178 @@
-	register a;
+	register int a;
@@ -239,0 +245 @@
+	ep = (char *)lspace + MEM;
@@ -245 +251 @@
-	nlines /= (5*(sizeof(char *)/sizeof(char)));
+	nlines /= (5*(sizeof(char *)));
@@ -272 +278 @@
-	for(a = mflg|cflg?0:eargc; a+N<nfiles || unsafeout&&a<eargc; a=i) {
+	for(a = mflg|cflg?0:eargc; a+N<nfiles || (unsafeout&&a<eargc); a=i) {
@@ -284 +290 @@
-	term();
+	term(0);
@@ -287 +293,2 @@
-sort()
+void
+sort(void)
@@ -291 +298 @@
-	register c;
+	register int c;
@@ -350 +357,3 @@
-merge(a,b)
+int	rline(struct merg *mp);
+void
+merge(int a, int b)
@@ -354 +363 @@
-	register	i;
+	register int	i;
@@ -392 +401 @@
-	muflg = mflg & uflg | cflg;
+	muflg = (mflg & uflg) | cflg;
@@ -444,2 +453,2 @@
-rline(mp)
-struct merg *mp;
+int
+rline(struct merg *mp)
@@ -450 +459 @@
-	register c;
+	register int c;
@@ -466,2 +475,2 @@
-disorder(s,t)
-char *s, *t;
+void
+disorder(char *s, char *t)
@@ -473 +482 @@
-	term();
+	term(0);
@@ -476 +485,2 @@
-newfile()
+void
+newfile(void)
@@ -483 +493 @@
-		term();
+		term(0);
@@ -489 +499 @@
-setfil(i)
+setfil(int i)
@@ -492 +502 @@
-	if(i < eargc)
+	if(i < eargc) {
@@ -496,0 +507 @@
+	}
@@ -503 +514,2 @@
-oldfile()
+void
+oldfile(void)
@@ -509 +521 @@
-			term();
+			term(0);
@@ -515 +527,2 @@
-safeoutfil()
+void
+safeoutfil(void)
@@ -533,2 +546,2 @@
-cant(f)
-char *f;
+void
+cant(char *f)
@@ -538 +551 @@
-	term();
+	term(0);
@@ -541,2 +554,2 @@
-diag(s,t)
-char *s, *t;
+void
+diag(char *s, char *t)
@@ -550 +563,2 @@
-term()
+void
+term(int sig)
@@ -552 +566,2 @@
-	register i;
+	register int i;
+	(void)sig;
@@ -565,2 +580,2 @@
-cmp(i, j)
-char *i, *j;
+int
+cmp(char *i, char *j)
@@ -569 +583,0 @@
-	char *skip();
@@ -606,2 +620,2 @@
-			for(ipa = pa; ipa<la&&isdigit(*ipa); ipa++) ;
-			for(ipb = pb; ipb<lb&&isdigit(*ipb); ipb++) ;
+			for(ipa = pa; ipa<la&&isdigit(*ipa&0377); ipa++) ;
+			for(ipb = pb; ipb<lb&&isdigit(*ipb&0377); ipb++) ;
@@ -613 +627 @@
-					if(b = *--ipb - *--ipa)
+					if((b = *--ipb - *--ipa))
@@ -627,3 +641,3 @@
-				while(pa<la && isdigit(*pa)
-				   && pb<lb && isdigit(*pb))
-					if(a = *pb++ - *pa++)
+				while(pa<la && isdigit(*pa&0377)
+				   && pb<lb && isdigit(*pb&0377))
+					if((a = *pb++ - *pa++))
@@ -631 +645 @@
-			while(pa<la && isdigit(*pa))
+			while(pa<la && isdigit(*pa&0377))
@@ -634 +648 @@
-			while(pb<lb && isdigit(*pb))
+			while(pb<lb && isdigit(*pb&0377))
@@ -642 +656 @@
-		while(ignore[*pa])
+		while(ignore[(signed char)*pa])
@@ -644 +658 @@
-		while(ignore[*pb])
+		while(ignore[(signed char)*pb])
@@ -646 +660 @@
-		if(pa>=la || *pa=='\n')
+		if(pa>=la || *pa=='\n') {
@@ -649,0 +664 @@
+		}
@@ -652 +667 @@
-		if((sa = code[*pb++]-code[*pa++]) == 0)
+		if((sa = code[(signed char)*pb++]-code[(signed char)*pa++]) == 0)
@@ -661,2 +676,2 @@
-cmpa(pa, pb)
-register char *pa, *pb;
+int
+cmpa(register char *pa, register char *pb)
@@ -678,3 +693 @@
-skip(pp, fp, j)
-struct field *fp;
-char *pp;
+skip(char *pp, struct field *fp, int j)
@@ -682 +695 @@
-	register i;
+	register int i;
@@ -718,2 +731 @@
-eol(p)
-register char *p;
+eol(register char *p)
@@ -725 +737,2 @@
-copyproto()
+void
+copyproto(void)
@@ -727 +740 @@
-	register i;
+	register int i;
@@ -732 +745 @@
-	for(i=0; i<sizeof(proto)/sizeof(*p); i++)
+	for(i=0; i<(int)(sizeof(proto)/sizeof(*p)); i++)
@@ -736,2 +749,2 @@
-field(s,k)
-char *s;
+void
+field(char *s, int k)
@@ -740 +753 @@
-	register d;
+	register int d;
@@ -790,0 +804 @@
+			/* fallthrough */
@@ -798,2 +812,2 @@
-number(ppa)
-char **ppa;
+int
+number(char **ppa)
@@ -805 +819 @@
-	while(isdigit(*pa)) {
+	while(isdigit(*pa&0377)) {
@@ -812 +826,2 @@
-blank(c)
+int
+blank(int c)
@@ -822,2 +837,2 @@
-qsort(a,l)
-char **a, **l;
+void
+qsort(char **a, char **l)

% usr/src/cmd/sp.c
@@ -11 +11,2 @@
-getit()
+static int
+getit(void)
@@ -13 +14 @@
-	register c;
+	register int c;
@@ -15 +16 @@
-	for(i=0;;i++)
+	for(i=0;i<(int)sizeof buf;i++)
@@ -19,0 +21 @@
+				/* fallthrough */
@@ -32,0 +35,2 @@
+	alen=i;
+	return(i);
@@ -34 +38,2 @@
-putit(ntab)
+static void
+putit(int ntab)
@@ -39 +44,2 @@
-clean()
+static void
+clean(void)
@@ -43 +49,2 @@
-main(argc,argv) char *argv[];
+int
+main(int argc, char *argv[])

% usr/src/cmd/spline.c
@@ -140,2 +140,2 @@
-float
-rhs(i){
+static float
+rhs(int i){
@@ -149 +149,2 @@
-spline(){
+static int
+spline(void){
@@ -205 +206 @@
-		for(j=m;j>0||i==0&&j==0;j--){	/* interpolate */
+		for(j=m;j>0||(i==0&&j==0);j--){	/* interpolate */
@@ -216 +217,3 @@
-readin() {
+int	getfloat(float *p), numb(float *np, int *argcp, char ***argvp);
+static void
+readin(void) {
@@ -222,2 +225,2 @@
-getfloat(p)
-	float *p;{
+int
+getfloat(float *p){
@@ -225 +228 @@
-	register c;
+	register int c;
@@ -227 +229,0 @@
-	extern double atof();
@@ -261,2 +263,2 @@
-getlim(p)
-	struct proj *p; {
+static void
+getlim(struct proj *p) {
@@ -270,3 +272,2 @@
-main(argc,argv)
-	char *argv[];{
-	extern char *malloc();
+int
+main(int argc, char *argv[]){
@@ -320,5 +321,2 @@
-numb(np,argcp,argvp)
-	int *argcp;
-	float *np;
-	char ***argvp;{
-	double atof();
+int
+numb(float *np, int *argcp, char ***argvp){
@@ -328 +326 @@
-	if(!('0'<=c&&c<='9' || c=='-' || c== '.' )) return(0);
+	if(!(('0'<=c&&c<='9') || c=='-' || c== '.' )) return(0);

% usr/src/cmd/split.c
@@ -11,2 +11,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -14 +14 @@
-	register i, c, f;
+	register int i, c, f;
@@ -56 +56 @@
-	for(i=0; i<count; i++)
+	for(i=0; (unsigned)i<count; i++)

% usr/src/cmd/stty.c
@@ -13,18 +13,18 @@
-	"0",	B0,
-	"50",	B50,
-	"75",	B75,
-	"110",	B110,
-	"134",	B134,
-	"134.5",B134,
-	"150",	B150,
-	"200",	B200,
-	"300",	B300,
-	"600",	B600,
-	"1200",	B1200,
-	"1800",	B1800,
-	"2400",	B2400,
-	"4800",	B4800,
-	"9600",	B9600,
-	"exta",	EXTA,
-	"extb",	EXTB,
-	0,
+	{"0",	B0},
+	{"50",	B50},
+	{"75",	B75},
+	{"110",	B110},
+	{"134",	B134},
+	{"134.5",B134},
+	{"150",	B150},
+	{"200",	B200},
+	{"300",	B300},
+	{"600",	B600},
+	{"1200",	B1200},
+	{"1800",	B1800},
+	{"2400",	B2400},
+	{"4800",	B4800},
+	{"9600",	B9600},
+	{"exta",	EXTA},
+	{"extb",	EXTB},
+	{0},
@@ -38,2 +38 @@
-	"even",
-	EVENP, 0,
+	{"even", EVENP, 0},
@@ -41,2 +40 @@
-	"-even",
-	0, EVENP,
+	{"-even", 0, EVENP},
@@ -44,2 +42 @@
-	"odd",
-	ODDP, 0,
+	{"odd", ODDP, 0},
@@ -47,2 +44 @@
-	"-odd",
-	0, ODDP,
+	{"-odd", 0, ODDP},
@@ -50,2 +46 @@
-	"raw",
-	RAW, 0,
+	{"raw", RAW, 0},
@@ -53,2 +48 @@
-	"-raw",
-	0, RAW,
+	{"-raw", 0, RAW},
@@ -56,2 +50 @@
-	"cooked",
-	0, RAW,
+	{"cooked", 0, RAW},
@@ -59,2 +52 @@
-	"-nl",
-	CRMOD, 0,
+	{"-nl", CRMOD, 0},
@@ -62,2 +54 @@
-	"nl",
-	0, CRMOD,
+	{"nl", 0, CRMOD},
@@ -65,2 +56 @@
-	"echo",
-	ECHO, 0,
+	{"echo", ECHO, 0},
@@ -68,2 +58 @@
-	"-echo",
-	0, ECHO,
+	{"-echo", 0, ECHO},
@@ -71,2 +60 @@
-	"LCASE",
-	LCASE, 0,
+	{"LCASE", LCASE, 0},
@@ -74,2 +62 @@
-	"lcase",
-	LCASE, 0,
+	{"lcase", LCASE, 0},
@@ -77,2 +64 @@
-	"-LCASE",
-	0, LCASE,
+	{"-LCASE", 0, LCASE},
@@ -80,2 +66 @@
-	"-lcase",
-	0, LCASE,
+	{"-lcase", 0, LCASE},
@@ -83,2 +68 @@
-	"-tabs",
-	XTABS, 0,
+	{"-tabs", XTABS, 0},
@@ -86,2 +70 @@
-	"tabs",
-	0, XTABS,
+	{"tabs", 0, XTABS},
@@ -90,2 +73 @@
-	"cbreak",
-	CBREAK, 0,
+	{"cbreak", CBREAK, 0},
@@ -93,2 +75 @@
-	"-cbreak",
-	0, CBREAK,
+	{"-cbreak", 0, CBREAK},
@@ -96,2 +77 @@
-	"cr0",
-	CR0, CR3,
+	{"cr0", CR0, CR3},
@@ -99,2 +79 @@
-	"cr1",
-	CR1, CR3,
+	{"cr1", CR1, CR3},
@@ -102,2 +81 @@
-	"cr2",
-	CR2, CR3,
+	{"cr2", CR2, CR3},
@@ -105,2 +83 @@
-	"cr3",
-	CR3, CR3,
+	{"cr3", CR3, CR3},
@@ -108,2 +85 @@
-	"tab0",
-	TAB0, XTABS,
+	{"tab0", TAB0, XTABS},
@@ -111,2 +87 @@
-	"tab1",
-	TAB1, XTABS,
+	{"tab1", TAB1, XTABS},
@@ -114,2 +89 @@
-	"tab2",
-	TAB2, XTABS,
+	{"tab2", TAB2, XTABS},
@@ -117,2 +91 @@
-	"nl0",
-	NL0, NL3,
+	{"nl0", NL0, NL3},
@@ -120,2 +93 @@
-	"nl1",
-	NL1, NL3,
+	{"nl1", NL1, NL3},
@@ -123,2 +95 @@
-	"nl2",
-	NL2, NL3,
+	{"nl2", NL2, NL3},
@@ -126,2 +97 @@
-	"nl3",
-	NL3, NL3,
+	{"nl3", NL3, NL3},
@@ -129,2 +99 @@
-	"ff0",
-	FF0, FF1,
+	{"ff0", FF0, FF1},
@@ -132,2 +101 @@
-	"ff1",
-	FF1, FF1,
+	{"ff1", FF1, FF1},
@@ -135,2 +103 @@
-	"bs0",
-	BS0, BS1,
+	{"bs0", BS0, BS1},
@@ -138,2 +105 @@
-	"bs1",
-	BS1, BS1,
+	{"bs1", BS1, BS1},
@@ -141,2 +107 @@
-	"33",
-	CR1, ALLDELAY,
+	{"33", CR1, ALLDELAY},
@@ -144,2 +109 @@
-	"tty33",
-	CR1, ALLDELAY,
+	{"tty33", CR1, ALLDELAY},
@@ -147,2 +111 @@
-	"37",
-	FF1+CR2+TAB1+NL1, ALLDELAY,
+	{"37", FF1+CR2+TAB1+NL1, ALLDELAY},
@@ -150,2 +113 @@
-	"tty37",
-	FF1+CR2+TAB1+NL1, ALLDELAY,
+	{"tty37", FF1+CR2+TAB1+NL1, ALLDELAY},
@@ -153,2 +115 @@
-	"05",
-	NL2, ALLDELAY,
+	{"05", NL2, ALLDELAY},
@@ -156,2 +117 @@
-	"vt05",
-	NL2, ALLDELAY,
+	{"vt05", NL2, ALLDELAY},
@@ -159,2 +119 @@
-	"tn",
-	CR1, ALLDELAY,
+	{"tn", CR1, ALLDELAY},
@@ -162,2 +121 @@
-	"tn300",
-	CR1, ALLDELAY,
+	{"tn300", CR1, ALLDELAY},
@@ -165,2 +123 @@
-	"ti",
-	CR2, ALLDELAY,
+	{"ti", CR2, ALLDELAY},
@@ -168,2 +125 @@
-	"ti700",
-	CR2, ALLDELAY,
+	{"ti700", CR2, ALLDELAY},
@@ -171,2 +127 @@
-	"tek",
-	FF1, ALLDELAY,
+	{"tek", FF1, ALLDELAY},
@@ -174 +129 @@
-	0,
+	{0},
@@ -180,2 +135,4 @@
-main(argc, argv)
-char	*argv[];
+int	eq(char *string);
+void	prmodes(void), delay(int m, char *s), prspeed(char *c, int s);
+int
+main(int argc, char *argv[])
@@ -232,2 +189,2 @@
-eq(string)
-char *string;
+int
+eq(char *string)
@@ -249 +206,2 @@
-prmodes()
+void
+prmodes(void)
@@ -251 +209 @@
-	register m;
+	register int m;
@@ -258 +216 @@
-	if (mode.sg_erase < ' ')
+	if ((mode.sg_erase&0377) < ' ')
@@ -262 +220 @@
-	if (mode.sg_kill < ' ')
+	if ((mode.sg_kill&0377) < ' ')
@@ -284,2 +242,2 @@
-delay(m, s)
-char *s;
+void
+delay(int m, char *s)
@@ -296,2 +254,2 @@
-prspeed(c, s)
-char *c;
+void
+prspeed(char *c, int s)

% usr/src/cmd/su.c
@@ -4,4 +4,2 @@
-struct	passwd *pwd,*getpwnam();
-char	*crypt();
-char	*getpass();
-char	**environ;
+struct	passwd *pwd;
+extern char	**environ;
@@ -9,3 +7,2 @@
-main(argc,argv)
-int	argc;
-char	**argv;
+int
+main(int argc, char **argv)

% usr/src/cmd/sum.c
@@ -7,2 +7,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -11 +11 @@
-	register i, c;
+	register int i, c;

% usr/src/cmd/sync.c
@@ -1 +1,3 @@
-main()
+#include <stdio.h>
+int
+main(void)

% usr/src/cmd/tabs.c
@@ -46,2 +46,4 @@
-syslook(w)
-char *w;
+void delay(int n), escape(int c), nl(void);
+void dasi450(void), tty37(void), dasi300(void), tn300(void), hp2645(void), misc(void);
+static int
+syslook(char *w)
@@ -57,2 +59,2 @@
-main(argc,argv)
-int argc; char **argv;
+int
+main(int argc,char **argv)
@@ -99 +101,2 @@
-clear(n)
+static void
+clear(int n)
@@ -106 +109,2 @@
-delay(n)
+void
+delay(int n)
@@ -111 +115,2 @@
-tabs(n)
+static void
+tabs(int n)
@@ -125 +130,2 @@
-margin(n)
+static void
+margin(int n)
@@ -134 +140,2 @@
-escape(c)
+void
+escape(int c)
@@ -139 +146,2 @@
-bs(n)
+static void
+bs(int n)
@@ -144 +152,2 @@
-nl()
+void
+nl(void)
@@ -153 +162,2 @@
-dasi450()
+void
+dasi450(void)
@@ -163 +173,2 @@
-tty37()
+void
+tty37(void)
@@ -168 +179,2 @@
-dasi300()
+void
+dasi300(void)
@@ -173 +185,2 @@
-tn300()
+void
+tn300(void)
@@ -183 +196,2 @@
-hp2645()
+void
+hp2645(void)
@@ -191 +205,2 @@
-misc()
+void
+misc(void)

% usr/src/cmd/tail.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -18 +18,0 @@
-int errno;
@@ -20,2 +20,3 @@
-main(argc,argv)
-char **argv;
+int digit(int c);
+int
+main(int argc, char **argv)
@@ -24,2 +25,2 @@
-	register i,j,k;
-	char *p;
+	register int i,j,k;
+	char *p = 0;
@@ -31 +32 @@
-	if(argc<=1 || *arg!='-'&&*arg!='+') {
+	if(argc<=1 || (*arg!='-'&&*arg!='+')) {
@@ -181 +182,2 @@
-digit(c)
+int
+digit(int c)

% usr/src/cmd/tar/tar.c
@@ -7,3 +7,3 @@
-char	*sprintf();
-char	*strcat();
-daddr_t	bsrch();
+void	usage(void), dorep(char *argv[]), getdir(void), passtape(void), putfile(char *longname, char *shortname), doxtract(char *argv[]), dotable(void), putempty(void), longt(struct stat *st), pmode(struct stat *st), select(int *pairp, struct stat *st), checkdir(char *name), tomodes(struct stat *sp), done(int n), getwdir(char *s), backtape(void), flushtape(void), copy(char *to, char *from), onintr(int sig), onquit(int sig), onhup(int sig), onterm(int sig);
+int	endtape(void), checksum(void), checkw(int c, char *name), response(void), checkupdate(char *arg), prefix(char *s1, char *s2), cmp(char *b, char *s, int n), readtape(char *buffer), writetape(char *buffer);
+daddr_t	bsrch(char *s, int n, daddr_t l, daddr_t h), lookup(char *s);
@@ -53 +52,0 @@
-char	*malloc();
@@ -55,3 +54,2 @@
-main(argc, argv)
-int	argc;
-char	*argv[];
+int
+main(int argc, char *argv[])
@@ -60 +57,0 @@
-	int onintr(), onquit(), onhup(), onterm();
@@ -195 +192,2 @@
-usage()
+void
+usage(void)
@@ -201,2 +199,2 @@
-dorep(argv)
-char	*argv[];
+void
+dorep(char *argv[])
@@ -256 +254,2 @@
-endtape()
+int
+endtape(void)
@@ -266 +265,2 @@
-getdir()
+void
+getdir(void)
@@ -292 +292,2 @@
-passtape()
+void
+passtape(void)
@@ -307,3 +308,2 @@
-putfile(longname, shortname)
-char *longname;
-char *shortname;
+void
+putfile(char *longname, char *shortname)
@@ -336 +336 @@
-		for (i = 0, cp = buf; *cp++ = longname[i++];);
+		for (i = 0, cp = buf; (*cp++ = longname[i++]););
@@ -442,2 +442,2 @@
-doxtract(argv)
-char	*argv[];
+void
+doxtract(char *argv[])
@@ -518 +518,2 @@
-dotable()
+void
+dotable(void)
@@ -534 +535,2 @@
-putempty()
+void
+putempty(void)
@@ -544,2 +546,2 @@
-longt(st)
-register struct stat *st;
+void
+longt(register struct stat *st)
@@ -548 +549,0 @@
-	char *ctime();
@@ -581,2 +582,2 @@
-pmode(st)
-register struct stat *st;
+void
+pmode(register struct stat *st)
@@ -590,3 +591,2 @@
-select(pairp, st)
-int *pairp;
-struct stat *st;
+void
+select(int *pairp, struct stat *st)
@@ -603,2 +603,2 @@
-checkdir(name)
-register char *name;
+void
+checkdir(register char *name)
@@ -626 +626,2 @@
-onintr()
+void
+onintr(int sig)
@@ -627,0 +629 @@
+	(void)sig;
@@ -632 +634,2 @@
-onquit()
+void
+onquit(int sig)
@@ -633,0 +637 @@
+	(void)sig;
@@ -638 +642,2 @@
-onhup()
+void
+onhup(int sig)
@@ -639,0 +645 @@
+	(void)sig;
@@ -644 +650,2 @@
-onterm()
+void
+onterm(int sig)
@@ -645,0 +653 @@
+	(void)sig;
@@ -650,2 +658,2 @@
-tomodes(sp)
-register struct stat *sp;
+void
+tomodes(register struct stat *sp)
@@ -664 +672,2 @@
-checksum()
+int
+checksum(void)
@@ -666 +675 @@
-	register i;
+	register int i;
@@ -673 +682 @@
-		i += *cp;
+		i += (signed char)*cp;
@@ -677,2 +686,2 @@
-checkw(c, name)
-char *name;
+int
+checkw(int c, char *name)
@@ -693 +702,2 @@
-response()
+int
+response(void)
@@ -699 +709 @@
-		while (getchar() != '\n');
+		while (getchar() != '\n' && !feof(stdin));
@@ -704,2 +714,2 @@
-checkupdate(arg)
-char	*arg;
+int
+checkupdate(char *arg)
@@ -710 +719,0 @@
-	daddr_t	lookup();
@@ -725 +734,2 @@
-done(n)
+void
+done(int n)
@@ -731,2 +741,2 @@
-prefix(s1, s2)
-register char *s1, *s2;
+int
+prefix(register char *s1, register char *s2)
@@ -742,2 +752,2 @@
-getwdir(s)
-char *s;
+void
+getwdir(char *s)
@@ -771,2 +781 @@
-lookup(s)
-char *s;
+lookup(char *s)
@@ -774 +783 @@
-	register i;
+	register int i;
@@ -785,3 +794 @@
-bsrch(s, n, l, h)
-daddr_t l, h;
-char *s;
+bsrch(char *s, int n, daddr_t l, daddr_t h)
@@ -789 +796 @@
-	register i, j;
+	register int i, j;
@@ -830,2 +837,2 @@
-cmp(b, s, n)
-char *b, *s;
+int
+cmp(char *b, char *s, int n)
@@ -833 +840 @@
-	register i;
+	register int i;
@@ -846,2 +853,2 @@
-readtape(buffer)
-char *buffer;
+int
+readtape(char *buffer)
@@ -856 +863 @@
-		if ((i = read(mt, tbuf, TBLOCK*j)) < 0) {
+		if ((i = read(mt, (char *)tbuf, TBLOCK*j)) < 0) {
@@ -878 +885 @@
-	copy(buffer, &tbuf[recno++]);
+	copy(buffer, (char *)&tbuf[recno++]);
@@ -882,2 +889,2 @@
-writetape(buffer)
-char *buffer;
+int
+writetape(char *buffer)
@@ -889 +896 @@
-		if (write(mt, tbuf, TBLOCK*nblock) < 0) {
+		if (write(mt, (char *)tbuf, TBLOCK*nblock) < 0) {
@@ -895 +902 @@
-	copy(&tbuf[recno++], buffer);
+	copy((char *)&tbuf[recno++], buffer);
@@ -897 +904 @@
-		if (write(mt, tbuf, TBLOCK*nblock) < 0) {
+		if (write(mt, (char *)tbuf, TBLOCK*nblock) < 0) {
@@ -906 +913,2 @@
-backtape()
+void
+backtape(void)
@@ -911 +919 @@
-		if (read(mt, tbuf, TBLOCK*nblock) < 0) {
+		if (read(mt, (char *)tbuf, TBLOCK*nblock) < 0) {
@@ -919 +927,2 @@
-flushtape()
+void
+flushtape(void)
@@ -921 +930 @@
-	write(mt, tbuf, TBLOCK*nblock);
+	write(mt, (char *)tbuf, TBLOCK*nblock);
@@ -924,2 +933,2 @@
-copy(to, from)
-register char *to, *from;
+void
+copy(register char *to, register char *from)
@@ -927 +936 @@
-	register i;
+	register int i;

% usr/src/cmd/tc.c
@@ -8 +8,2 @@
-#define	oput(c) if (pgskip==0) putchar(c); else;
+#define	atoi	tcatoi
+#define	oput(c) if (pgskip==0) putchar(c)
@@ -54,2 +55,2 @@
-int	(*sigint)();
-int	(*sigquit)();
+void	(*sigint)(int sig);
+void	(*sigquit)(int sig);
@@ -57,3 +58,6 @@
-main(argc,argv)
-int argc;
-char **argv;
+void lig(char *x), init(void), kwait(void), callunix(char line[]), sendpt(void);
+void ex(int sig);
+long tscale(int n);
+int readch(void), atoi(void), getch(void);
+int
+main(int argc, char **argv)
@@ -61 +65 @@
-	register i, j;
+	register int i, j;
@@ -63 +66,0 @@
-	extern ex();
@@ -70 +73 @@
-				if(i = atoi())pl = i/3;
+				if((i = atoi()))pl = i/3;
@@ -83,2 +86,2 @@
-				if(i = atoi())mpy = i;
-				if(i = atoi())div = i;
+				if((i = atoi()))mpy = i;
+				if((i = atoi()))div = i;
@@ -224 +227 @@
-	ex();
+	ex(0);
@@ -226,2 +229,2 @@
-lig(x)
-char *x;
+void
+lig(char *x)
@@ -229 +232 @@
-	register i, j;
+	register int i, j;
@@ -247 +250,2 @@
-init(){
+void
+init(void){
@@ -263 +267,3 @@
-ex(){
+void
+ex(int sig){
+	(void)sig;
@@ -273 +279,2 @@
-kwait(){
+void
+kwait(void){
@@ -297 +304 @@
-	else if (c==0) ex();
+	else if (c==0) ex(0);
@@ -300,2 +307,2 @@
-callunix(line)
-char line[];
+void
+callunix(char line[])
@@ -317 +324,2 @@
-readch(){
+int
+readch(void){
@@ -322 +330,2 @@
-sendpt(){
+void
+sendpt(void){
@@ -327 +336 @@
-	xb = ((xx & 03) + ((yy<<2) & 014) & 017);
+	xb = (((xx & 03) + ((yy<<2) & 014)) & 017);
@@ -345 +354,2 @@
-atoi()
+int
+atoi(void)
@@ -347 +357 @@
-	register i, j, acc;
+	register int i, j, acc;
@@ -350 +359,0 @@
-	long tscale();
@@ -376,2 +385 @@
-long tscale(n)
-int n;
+long tscale(int n)
@@ -379 +387 @@
-	register i, j;
+	register int i, j;
@@ -403,2 +411,3 @@
-getch(){
-	register i;
+int
+getch(void){
+	register int i;
@@ -414 +423 @@
-char *asctab[128] {
+char *asctab[128] = {

% usr/src/cmd/tee.c
@@ -18,2 +18,2 @@
-extern errno;
-long	lseek();
+#include <stdio.h>
+#define	puts	tee_puts
@@ -21,2 +21,3 @@
-main(argc,argv)
-char **argv;
+void stash(int p), puts(char *s);
+int
+main(int argc,char **argv)
@@ -24 +25 @@
-	int register r,w,p;
+	register int r,w,p;
@@ -70 +71 @@
-					return;
+					return(0);
@@ -79 +80,2 @@
-stash(p)
+void
+stash(int p)
@@ -90,2 +92,2 @@
-puts(s)
-char *s;
+void
+puts(char *s)

% usr/src/cmd/test.c
@@ -18,2 +18,5 @@
-main(argc, argv)
-char *argv[];
+int exp(void), e1(void), e2(void), e3(void), tio(char *a, int f);
+int ftype(char *f), fsizep(char *f), length(char *s);
+void synbad(char *s1, char *s2);
+int
+main(int argc, char *argv[])
@@ -32 +35 @@
-char *nxtarg(mt) {
+static char *nxtarg(int mt) {
@@ -44 +47,2 @@
-exp() {
+int
+exp(void) {
@@ -53 +57,2 @@
-e1() {
+int
+e1(void) {
@@ -62 +67,2 @@
-e2() {
+int
+e2(void) {
@@ -69 +75,2 @@
-e3() {
+int
+e3(void) {
@@ -97 +104 @@
-	if(EQ(a, "-t"))
+	if(EQ(a, "-t")) {
@@ -101,0 +109 @@
+	}
@@ -136,0 +145 @@
+	return(0);
@@ -139,3 +148,2 @@
-tio(a, f)
-char *a;
-int f;
+int
+tio(char *a, int f)
@@ -152,2 +160,2 @@
-ftype(f)
-char *f;
+int
+ftype(char *f)
@@ -164,2 +172,2 @@
-fsizep(f)
-char *f;
+int
+fsizep(char *f)
@@ -173,2 +181,2 @@
-synbad(s1,s2)
-char *s1, *s2;
+void
+synbad(char *s1,char *s2)
@@ -183,2 +191,2 @@
-length(s)
-	char *s;
+int
+length(char *s)

% usr/src/cmd/time.c
@@ -11,2 +11,3 @@
-main(argc, argv)
-char **argv;
+void printt(char *s, long a);
+int
+main(int argc, char **argv)
@@ -16 +17 @@
-	register p;
+	register int p;
@@ -53,3 +54,2 @@
-printt(s, a)
-char *s;
-long a;
+void
+printt(char *s, long a)
@@ -58 +58 @@
-	register i;
+	register int i;

% usr/src/cmd/tk.c
@@ -37,3 +37,3 @@
-main(argc, argv)
-int argc;
-char **argv;
+void	init(void), sendpt(int a), kwait(void), execom(void), ex(int sig);
+int
+main(int argc, char **argv)
@@ -41,2 +41 @@
-	register i, j;
-	extern ex();
+	register int i, j;
@@ -47 +46 @@
-				if (i = atoi(&argv[0][2]))
+				if ((i = atoi(&argv[0][2])))
@@ -49 +48 @@
-					yyll = MAXY + 1 - pl;
+				yyll = MAXY + 1 - pl;
@@ -52 +51 @@
-				if (i = atoi(&argv[0][1])) {
+				if ((i = atoi(&argv[0][1]))) {
@@ -75,0 +75 @@
+			/* fallthrough */
@@ -150 +150 @@
-	ex();
+	ex(0);
@@ -153 +153,2 @@
-init()
+void
+init(void)
@@ -171 +172,2 @@
-ex()
+void
+ex(int sig)
@@ -172,0 +175 @@
+	(void)sig;
@@ -180 +183,2 @@
-kwait()
+void
+kwait(void)
@@ -182 +186 @@
-	register c;
+	register int c;
@@ -195 +199 @@
-			ex();
+			ex(0);
@@ -199 +203,2 @@
-execom()
+void
+execom(void)
@@ -201 +206 @@
-	int (*si)(), (*sq)();
+	void (*si)(int sig), (*sq)(int sig);
@@ -218 +223,2 @@
-sendpt(a)
+void
+sendpt(int a)
@@ -220 +226 @@
-	register zz;
+	register int zz;
@@ -228 +234 @@
-	xb = ((xx & 03) + ((zz<<2) & 014) & 017);
+	xb = (((xx & 03) + ((zz<<2) & 014)) & 017);

% usr/src/cmd/touch.c
@@ -4,3 +4,3 @@
-main(argc,argv)
-int argc;
-char *argv[];
+void touch(int force, char *name);
+int
+main(int argc, char *argv[])
@@ -25,3 +25,2 @@
-touch(force, name)
-int force;
-char *name;
+void
+touch(int force, char *name)
@@ -33 +32 @@
-if( stat(name,&stbuff) < 0)
+if( stat(name,&stbuff) < 0) {
@@ -40,0 +40 @@
+	}

% usr/src/cmd/tp/tp.h
@@ -25 +25 @@
-struct 	tent	{	/* Structure of a tape directory block */
+extern struct 	tent	{	/* Structure of a tape directory block */
@@ -39 +39 @@
-struct	dent {	/* in core version of tent with "unused" removed
+extern struct	dent {	/* in core version of tent with "unused" removed
@@ -52,3 +52,3 @@
-char	map[MAPSIZE];
-char	name[NAMELEN];
-char	name1[NAMELEN];
+extern char	map[MAPSIZE];
+extern char	name[NAMELEN];
+extern char	name1[NAMELEN];
@@ -57 +57 @@
-char	*tname;
+extern char	*tname;
@@ -61,12 +61,11 @@
-int	narg, rnarg;
-char	**parg;
-int	wseeka,rseeka;
-int	tapsiz;
-int	fio;
-short	ndirent, ndentb;
-struct	dent	*edir;
-struct	dent *lastd;		/* for improvement */
-char	*sbrk();
-char	*strcpy();
-long	lseek();
-int	(*command)();
+extern int	narg, rnarg;
+extern char	**parg;
+extern int	wseeka,rseeka;
+extern int	tapsiz;
+extern int	fio;
+extern short	ndirent, ndentb;
+extern struct	dent	*edir;
+extern struct	dent *lastd;		/* for improvement */
+extern void	(*command)(void);
+void	optap(void), setcom(void (*newcom)(void)), useerr(void), check(void), done(void), encode(char *pname, struct dent *dptr), decode(char *pname, struct dent *dptr), clrdir(void), clrent(struct dent *ptr), rddir(void), wrdir(void), tread(void), twrite(void), rseek(int blk), wseek(int blk), seekerr(void), getfiles(void), expand(void), fserr(void), callout(void), swabdir(struct tent *tp), gettape(void (*how)(struct dent *d)), delete(struct dent *dd), update(void), update1(void), phserr(void), bitmap(void), setmap(struct dent *d), maperr(void), usage(void), taboc(struct dent *dd), extract(struct dent *d), cmd(void), cmr(void), cmx(void), cmt(void);
+int	verify(int key);
@@ -74,3 +73,3 @@
-char	*nameblk;
-char	*top;
-char	*nptr;
+extern char	*nameblk;
+extern char	*top;
+extern char	*nptr;

% usr/src/cmd/tp/tp0.c
@@ -2,0 +3,7 @@
+struct	tent	tpentry[TPB];
+struct	dent	dir[MDIRENT], *edir, *lastd;
+char	map[MAPSIZE], name[NAMELEN], name1[NAMELEN], *tname, **parg;
+char	*nameblk, *top, *nptr;
+int	narg, rnarg, wseeka, rseeka, tapsiz, fio;
+short	ndirent, ndentb;
+void	(*command)(void);

% usr/src/cmd/tp/tp1.c
@@ -1,0 +2 @@
+#include <stdio.h>
@@ -3,2 +4,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -7 +7,0 @@
-	extern cmd(), cmr(),cmx(), cmt();
@@ -15 +15 @@
-		while (c = *ptr++) switch(c)  {
+		while ((c = *ptr++)) switch(c)  {
@@ -65 +65,2 @@
-optap()
+void
+optap(void)
@@ -67 +67,0 @@
-	extern cmr();
@@ -89,2 +89,2 @@
-setcom(newcom)
-int (*newcom)();
+void
+setcom(void (*newcom)(void))
@@ -92 +91,0 @@
-	extern cmr();
@@ -98 +97,2 @@
-useerr()
+void
+useerr(void)
@@ -104 +104 @@
-/*/* COMMANDS */
+/* COMMANDS */
@@ -106 +106,2 @@
-cmd()
+void
+cmd(void)
@@ -108 +108,0 @@
-	extern delete();
@@ -118 +118,2 @@
-cmr()
+void
+cmr(void)
@@ -127 +128,2 @@
-cmt()
+void
+cmt(void)
@@ -129 +130,0 @@
-	extern taboc();
@@ -139 +140,2 @@
-cmx()
+void
+cmx(void)
@@ -141 +142,0 @@
-	extern extract();
@@ -149 +150,2 @@
-check()
+void
+check(void)
@@ -155 +157,2 @@
-done()
+void
+done(void)
@@ -161 +164,2 @@
-encode(pname,dptr)	/* pname points to the pathname
+void
+encode(char *pname, struct dent *dptr)	/* pname points to the pathname
@@ -164,2 +167,0 @@
-char	*pname;
-struct	dent *dptr;
@@ -168 +170 @@
-	register n;
+	register int n;
@@ -188 +190,2 @@
-decode(pname,dptr)	/* dptr points to the dir entry
+void
+decode(char *pname, struct dent *dptr)	/* dptr points to the dir entry
@@ -190,2 +192,0 @@
-char	*pname;
-struct	dent *dptr;

% usr/src/cmd/tp/tp2.c
@@ -10 +10,2 @@
-clrdir()
+void
+clrdir(void)
@@ -12 +13 @@
-	register j, *p;
+	register int j, *p;
@@ -20,2 +21,2 @@
-clrent(ptr)
-struct	dent *ptr;
+void
+clrent(struct dent *ptr)
@@ -23 +24 @@
-	register *p, j;
+	register int *p, j;
@@ -38 +39,2 @@
-rddir()
+void
+rddir(void)
@@ -43 +45 @@
-	struct tent  *tptr;
+	struct tent  *tptr = &tpentry[0];
@@ -68 +70 @@
-		for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+		for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@ -92 +94 @@
-	if(sum != 0)
+	if(sum != 0) {
@@ -101,0 +104 @@
+	}
@@ -106 +109,2 @@
-wrdir()
+void
+wrdir(void)
@@ -149 +153 @@
-				for(i=0;i<sizeof(struct tent)/sizeof(short)-1;i++)
+				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short))-1;i++)
@@ -156 +160 @@
-				for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@ -164 +168,2 @@
-tread()
+void
+tread(void)
@@ -166 +171 @@
-	register j, *ptr;
+	register int j, *ptr;
@@ -178 +183,2 @@
-twrite()
+void
+twrite(void)
@@ -187 +193,2 @@
-rseek(blk)
+void
+rseek(int blk)
@@ -193 +200,2 @@
-wseek(blk)
+void
+wseek(int blk)
@@ -195 +203 @@
-	register amt, b;
+	register int amt, b;
@@ -207 +215,2 @@
-seekerr()
+void
+seekerr(void)
@@ -213 +222,2 @@
-verify(key)
+int
+verify(int key)
@@ -215 +225 @@
-	register c;
+	register int c;
@@ -225 +235 @@
-	if (c == 'n' && getchar() == '\n')
+	if (c == EOF || (c == 'n' && getchar() == '\n'))
@@ -231 +241 @@
-	while (getchar() != '\n');
+	while (getchar() != '\n' && !feof(stdin));
@@ -235 +245,2 @@
-getfiles()
+void
+getfiles(void)
@@ -248 +259,2 @@
-expand()
+void
+expand(void)
@@ -277 +289,2 @@
-fserr()
+void
+fserr(void)
@@ -283 +296,2 @@
-callout()
+void
+callout(void)
@@ -341,2 +355,2 @@
-swabdir(tp)
-register struct tent *tp;
+void
+swabdir(register struct tent *tp)

% usr/src/cmd/tp/tp3.c
@@ -1,0 +2 @@
+#include <stdio.h>
@@ -3,2 +4,2 @@
-gettape(how)
-int (*how)();
+void
+gettape(void (*how)(struct dent *d))
@@ -33,2 +34,2 @@
-delete(dd)
-struct dent *dd;
+void
+delete(struct dent *dd)
@@ -41 +42,2 @@
-update()
+void
+update(void)
@@ -44 +46 @@
-	register b, last;
+	register int b, last;
@@ -71 +73,2 @@
-update1()
+void
+update1(void)
@@ -74 +77 @@
-	register index;
+	register int index;
@@ -101 +104 @@
-		if (index = d->d_size % BSIZE) {
+		if ((index = d->d_size % BSIZE)) {
@@ -110 +113,2 @@
-phserr()
+void
+phserr(void)
@@ -114 +118,2 @@
-bitmap()	/* place old files in the map */
+void
+bitmap(void)	/* place old files in the map */
@@ -117 +122 @@
-	register count;
+	register int count;
@@ -130,2 +135,2 @@
-setmap(d)
-register struct dent *d;
+void
+setmap(register struct dent *d)
@@ -140 +145 @@
-	if ((c += block) >= tapsiz)		maperr();
+	if ((c += block) >= (unsigned)tapsiz)		maperr();
@@ -149 +154,2 @@
-maperr()
+void
+maperr(void)
@@ -156 +162,2 @@
-usage()
+void
+usage(void)
@@ -158 +165 @@
-	register reg,count;
+	register int reg,count;
@@ -160 +167 @@
-	static lused;
+	static int lused;
@@ -190,2 +197,2 @@
-taboc(dd)
-struct dent *dd;
+void
+taboc(struct dent *dd)
@@ -193,2 +200,2 @@
-	register  mode;
-	register *m;
+	register int  mode;
+	register int *m;
@@ -196 +203 @@
-	int count, *localtime();
+	int count;
@@ -215 +222 @@
-		m = localtime(&dd->d_time);
+		m = (int *)localtime(&dd->d_time);
@@ -222,2 +229,2 @@
-extract(d)
-register struct dent *d;
+void
+extract(register struct dent *d)
@@ -225 +232 @@
-	register count, id;
+	register int count, id;
@@ -238 +245 @@
-	if (count = d->d_size % BSIZE) {
+	if ((count = d->d_size % BSIZE)) {

% usr/src/cmd/tp/tp_defs.h usr/include/tp_defs.h

% usr/src/cmd/tr.c
@@ -13,2 +13,3 @@
-main(argc,argv)
-char **argv;
+int	next(struct string *s), nextc(struct string *s);
+int
+main(int argc, char **argv)
@@ -16 +17 @@
-	register i;
+	register int i;
@@ -18 +19 @@
-	register c, d;
+	register int c, d;
@@ -50 +51 @@
-		while(c = next(&string1))
+		while((c = next(&string1)))
@@ -71 +72 @@
-	while(d = next(&string2))
+	while((d = next(&string2)))
@@ -81 +82 @@
-		if(c = code[c&0377]&0377)
+		if((c = code[c&0377]&0377))
@@ -88,2 +89,2 @@
-next(s)
-struct string *s;
+int
+next(struct string *s)
@@ -114,2 +115,2 @@
-nextc(s)
-struct string *s;
+int
+nextc(struct string *s)
@@ -117 +118 @@
-	register c, i, n;
+	register int c, i, n;

% usr/src/cmd/tsort.c
@@ -8,0 +9 @@
+#define index tindex
@@ -29,4 +30,5 @@
-struct nodelist *index();
-struct nodelist *findloop();
-struct nodelist *mark();
-char *malloc();
+struct nodelist *index(char *s);
+struct nodelist *findloop(void);
+int present(struct nodelist *i, struct nodelist *j), anypred(struct nodelist *i);
+int cmp(char *s, char *t);
+void error(char *s, char *t), note(char *s, char *t);
@@ -38,2 +40,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -86,2 +88,2 @@
-present(i,j)
-struct nodelist *i, *j;
+int
+present(struct nodelist *i, struct nodelist *j)
@@ -98,2 +100,2 @@
-anypred(i)
-struct nodelist *i;
+int
+anypred(struct nodelist *i)
@@ -111,2 +113 @@
-index(s)
-register char *s;
+index(register char *s)
@@ -129 +130 @@
-	while(*t++ = *s++);
+	while((*t++ = *s++));
@@ -133,2 +134,2 @@
-cmp(s,t)
-register char *s, *t;
+int
+cmp(register char *s, register char *t)
@@ -145,2 +146,2 @@
-error(s,t)
-char *s, *t;
+void
+error(char *s, char *t)
@@ -152,2 +153,2 @@
-note(s,t)
-char *s,*t;
+void
+note(char *s, char *t)
@@ -162 +163 @@
-findloop()
+findloop(void)
@@ -174 +175 @@
-				error("error 1");
+				error("error 1",empty);
@@ -185 +186 @@
-				error("error 2");
+				error("error 2",empty);

% usr/src/cmd/tty.c
@@ -5 +5 @@
-char	*ttyname();
+#include <stdio.h>
@@ -7,2 +7,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)

% usr/src/cmd/umount.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -9,2 +10,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -43 +44 @@
-				for (p1 = mp->file; p1 < &mp->file[NAMSIZ*2];)
+				for (p1 = (char *)mp; p1 < (char *)(mp+1);)
@@ -46 +47 @@
-				while ((--mp)->file[0] == 0);
+				while (mp > mtab && (--mp)->file[0] == 0);

% usr/src/cmd/uniq.c
@@ -11 +11,3 @@
-char	*skip();
+char	*skip(char *s);
+int	gline(char buf[]), equal(char b1[], char b2[]);
+void	pline(char buf[]), printe(char *p, char *s);
@@ -13,3 +15,2 @@
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -21 +22 @@
-			if (isdigit(argv[1][1]))
+			if (isdigit(argv[1][1]&0377))
@@ -65,2 +66,2 @@
-gline(buf)
-register char buf[];
+int
+gline(register char buf[])
@@ -68 +69,2 @@
-	register c;
+	register int c;
+	char *e = &buf[999];
@@ -73 +75,2 @@
-		*buf++ = c;
+		if(buf < e)
+			*buf++ = c;
@@ -79,2 +82,2 @@
-pline(buf)
-register char buf[];
+void
+pline(register char buf[])
@@ -104,2 +107,2 @@
-equal(b1, b2)
-register char b1[], b2[];
+int
+equal(register char b1[], register char b2[])
@@ -120,2 +123 @@
-skip(s)
-register char *s;
+skip(register char *s)
@@ -123 +125 @@
-	register nf, nl;
+	register int nf, nl;
@@ -137,2 +139,2 @@
-printe(p,s)
-char *p,*s;
+void
+printe(char *p, char *s)

% usr/src/cmd/units.c
@@ -1,0 +2 @@
+#include <signal.h>
@@ -7,3 +8,4 @@
-double	getflt();
-int	fperr();
-struct	table	*hash();
+double	getflt(void);
+void	fperr(int sig), init(void);
+int	pu(int u, int i, int f), get(void);
+struct	table	*hash(char *name);
@@ -13 +15 @@
-	char	dim[NDIM];
+	signed char	dim[NDIM];
@@ -19 +21 @@
-	char	dim[NDIM];
+	signed char	dim[NDIM];
@@ -29,17 +31,17 @@
-	1e-18,	"atto",
-	1e-15,	"femto",
-	1e-12,	"pico",
-	1e-9,	"nano",
-	1e-6,	"micro",
-	1e-3,	"milli",
-	1e-2,	"centi",
-	1e-1,	"deci",
-	1e1,	"deka",
-	1e2,	"hecta",
-	1e2,	"hecto",
-	1e3,	"kilo",
-	1e6,	"mega",
-	1e6,	"meg",
-	1e9,	"giga",
-	1e12,	"tera",
-	0.0,	0
+	{1e-18,	"atto"},
+	{1e-15,	"femto"},
+	{1e-12,	"pico"},
+	{1e-9,	"nano"},
+	{1e-6,	"micro"},
+	{1e-3,	"milli"},
+	{1e-2,	"centi"},
+	{1e-1,	"deci"},
+	{1e1,	"deka"},
+	{1e2,	"hecta"},
+	{1e2,	"hecto"},
+	{1e3,	"kilo"},
+	{1e6,	"mega"},
+	{1e6,	"meg"},
+	{1e9,	"giga"},
+	{1e12,	"tera"},
+	{0.0,	0}
@@ -52,2 +54,4 @@
-main(argc, argv)
-char *argv[];
+void	units(struct unit *up);
+int	convr(struct unit *up), lookup(char *name, struct unit *up, int den, int c);
+int
+main(int argc, char *argv[])
@@ -55 +59 @@
-	register i;
+	register int i;
@@ -109,2 +113,2 @@
-units(up)
-struct unit *up;
+void
+units(struct unit *up)
@@ -113 +117 @@
-	register f, i;
+	register int f, i;
@@ -129 +133,2 @@
-pu(u, i, f)
+int
+pu(int u, int i, int f)
@@ -140 +145 @@
-			return(2);
+		return(2);
@@ -147,2 +152,2 @@
-convr(up)
-struct unit *up;
+int
+convr(struct unit *up)
@@ -151 +156 @@
-	register c;
+	register int c;
@@ -198,3 +203,2 @@
-lookup(name, up, den, c)
-char *name;
-struct unit *up;
+int
+lookup(char *name, struct unit *up, int den, int c)
@@ -204 +208 @@
-	register i;
+	register int i;
@@ -230 +234 @@
-	for(i=0; cp1 = prefix[i].pname; i++) {
+	for(i=0; (cp1 = prefix[i].pname); i++) {
@@ -252,2 +256,2 @@
-equal(s1, s2)
-char *s1, *s2;
+static int
+equal(char *s1, char *s2)
@@ -265 +269,2 @@
-init()
+void
+init(void)
@@ -291 +296 @@
-		printf("%l units; %l bytes\n\n", i, cp-names);
+		printf("%d units; %d bytes\n\n", i, cp-names);
@@ -297 +302 @@
-			units(tp);
+			units((struct unit *)tp);
@@ -333 +338 @@
-	convr(lp);
+	convr((struct unit *)lp);
@@ -359 +364 @@
-getflt()
+getflt(void)
@@ -361 +366 @@
-	register c, i, dp;
+	register int c, i, dp;
@@ -415 +420,2 @@
-get()
+int
+get(void)
@@ -417 +423 @@
-	register c;
+	register int c;
@@ -419 +425 @@
-	if(c=peekc) {
+	if((c=peekc)) {
@@ -435,2 +441 @@
-hash(name)
-char *name;
+hash(char *name)
@@ -459 +464,2 @@
-fperr()
+void
+fperr(int sig)
@@ -460,0 +467 @@
+	(void)sig;

% usr/src/cmd/update.c
@@ -6,0 +7 @@
+#include <stdio.h>
@@ -15 +16,3 @@
-main()
+void dosync(int sig);
+int
+main(void)
@@ -26 +29 @@
-	dosync();
+	dosync(0);
@@ -31 +34,2 @@
-dosync()
+void
+dosync(int sig)
@@ -32,0 +37 @@
+	(void)sig;

% usr/src/cmd/vpr.c
@@ -24 +24 @@
-char	chrtab[][16];
+char	chrtab[];
@@ -26 +26 @@
-char	*ctime();
+int	send(void), getline(void); void putline(int ff), banner(char *s);
@@ -28,2 +28,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -72 +72,2 @@
-send()
+int
+send(void)
@@ -74 +75 @@
-	register nskipped;
+	register int nskipped;
@@ -97 +98,2 @@
-getline()
+int
+getline(void)
@@ -99 +101 @@
-	register col, maxcol, c;
+	register int col, maxcol, c;
@@ -175 +177,2 @@
-putline(ff)
+void
+putline(int ff)
@@ -178,2 +181,2 @@
-	register c;
-	extern errno;
+	register int c;
+	extern int errno;
@@ -183 +186 @@
-	while (c = *lp++)
+	while ((c = *lp++))
@@ -205,2 +208,2 @@
-banner(s)
-char *s;
+void
+banner(char *s)
@@ -219 +222 @@
-			t = chrtab[*sp - ' '][i];
+			t = chrtab[(*sp - ' ')*16 + i];
@@ -235 +238 @@
-char	chrtab[][16] = {
+char	chrtab[] = {

% usr/src/cmd/wall.c
@@ -8,2 +7,0 @@
-char	*strcpy();
-char	*strcat();
@@ -11,2 +9,3 @@
-main(argc, argv)
-char *argv[];
+void sendmes(char *tty);
+int
+main(int argc, char *argv[])
@@ -14 +13 @@
-	register i;
+	register int i;
@@ -43,2 +42,2 @@
-sendmes(tty)
-char *tty;
+void
+sendmes(char *tty)
@@ -46 +45 @@
-	register i;
+	register int i;

% usr/src/cmd/wc.c
@@ -5,2 +5,3 @@
-main(argc, argv)
-char **argv;
+void wcp(char *wd, long charct, long wordct, long linect);
+int
+main(int argc, char **argv)
@@ -69,3 +70,2 @@
-wcp(wd, charct, wordct, linect)
-register char *wd;
-long charct; long wordct; long linect;
+void
+wcp(register char *wd, long charct, long wordct, long linect)

% usr/src/cmd/who.c
@@ -10 +9,0 @@
-struct passwd *getpwuid();
@@ -12,3 +11,3 @@
-char *ttyname(), *rindex(), *ctime(), *strcpy(), *index();
-main(argc, argv)
-char **argv;
+void putline(void);
+int
+main(int argc, char **argv)
@@ -55 +54,2 @@
-putline()
+void
+putline(void)

% usr/src/cmd/write.c
@@ -11,2 +10,0 @@
-char	*strcat();
-char	*strcpy();
@@ -20,2 +17,0 @@
-char	*ttyname();
-char	*rindex(), *index();
@@ -23,2 +19,2 @@
-int	eof();
-int	timout();
+void	eof(int sig);
+void	timout(int sig), ex(char *bp), sigs(void (*sig)(int sig));
@@ -27,2 +23,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -31 +27 @@
-	register i;
+	register int i;
@@ -126 +122 @@
-			eof();
+			eof(0);
@@ -140 +136,2 @@
-timout()
+void
+timout(int sig)
@@ -142,0 +140 @@
+	(void)sig;
@@ -147 +145,2 @@
-eof()
+void
+eof(int sig)
@@ -149,0 +149 @@
+	(void)sig;
@@ -154,2 +154,2 @@
-ex(bp)
-char *bp;
+void
+ex(char *bp)
@@ -157 +157 @@
-	register i;
+	register int i;
@@ -166 +166 @@
-		sigs((int (*)())0);
+		sigs(SIG_DFL);
@@ -177,2 +177,2 @@
-sigs(sig)
-int (*sig)();
+void
+sigs(void (*sig)(int sig))
@@ -180 +180 @@
-	register i;
+	register int i;

% usr/src/cmd/yes.c
@@ -1,2 +1,3 @@
-main(argc, argv)
-char **argv;
+#include <stdio.h>
+int
+main(int argc, char **argv)

% usr/src/games/arithmetic.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -12,0 +14,2 @@
+int	getnum(char *s), random(int range), skrand(int range);
+void	getline(char *s), score(void), delete(int sig);
@@ -14,2 +17,2 @@
-main(argc,argv)
-char	*argv[];
+int
+main(int argc, char *argv[])
@@ -20 +22,0 @@
-	extern	delete();
@@ -32 +34 @@
-			while(types[dif] = argv[1][dif])
+			while((types[dif] = argv[1][dif]))
@@ -121,2 +123,2 @@
-getline(s)
-char *s;
+void
+getline(char *s)
@@ -142,2 +144,2 @@
-getnum(s)
-char *s;
+int
+getnum(char *s)
@@ -156 +158,2 @@
-random(range)
+int
+random(int range)
@@ -161 +164,2 @@
-skrand(range){
+int
+skrand(int range){
@@ -168 +172,2 @@
-score()
+void
+score(void)
@@ -185 +190,2 @@
-delete()
+void
+delete(int sig)
@@ -186,0 +193 @@
+	(void)sig;

% usr/src/games/backgammon.c
@@ -4,0 +5 @@
+#define srand bg_srand
@@ -15 +16,10 @@
-int red[]     {0,2,0,0,0,0,0,0,0,0,0,0,5,
+void getstr(char *s), prtmov(int k), update(int *player, int *playee, int k), roll(void);
+void movegen(int *mover, int *movee), moverecord(int *mover), instructions(void);
+void prtbrd(void), numline(int *upcol, int *downcol, int start, int fin), srand(void);
+void colorline(int *upcol, char c1, int *downcol, char c2, int start, int fin);
+void _store(int *p, int numb);
+int play(int *player, int *playee, int pos[]), nextmove(int *player, int *playee);
+int piececount(int *player, int startrow, int endrow), _look(int *p);
+int strategy(int *player, int *playee), eval(int *player, int *playee, int k, int *prob);
+int getprob(int *player, int *playee, int start, int finish);
+int red[]     = {0,2,0,0,0,0,0,0,0,0,0,0,5,
@@ -18 +28 @@
-int white[]   {0,2,0,0,0,0,0,0,0,0,0,0,5,
+int white[]   = {0,2,0,0,0,0,0,0,0,0,0,0,5,
@@ -21 +31 @@
-int probability[]{0,11,12,13,14,15,16,
+int probability[]={0,11,12,13,14,15,16,
@@ -28 +38,2 @@
-main()
+int
+main(void)
@@ -30 +41 @@
-	int t,k,n,go[5];
+	int t,k,n,go[6];
@@ -57 +68 @@
-	    exit();
+	    exit(0);
@@ -94 +105 @@
-	    exit();
+	    exit(0);
@@ -99,2 +110,2 @@
-getstr(s)
-char *s;
+void
+getstr(char *s)
@@ -102 +113,6 @@
-	while((*s=getchar())!='\n')s++;
+	char *e = s+99;
+
+	while((*s=getchar())!='\n'){
+		if(feof(stdin))exit(0);
+		if(s<e)s++;
+	}
@@ -106,2 +122,2 @@
-play(player,playee,pos)
-int *player,*playee,pos[];
+int
+play(int *player, int *playee, int pos[])
@@ -149,2 +165,2 @@
-nextmove(player,playee)
-int *player,*playee;
+int
+nextmove(int *player, int *playee)
@@ -170,2 +186,2 @@
-prtmov(k)
-int k;
+void
+prtmov(int k)
@@ -181,2 +197,2 @@
-update(player,playee,k)
-int *player,*playee,k;
+void
+update(int *player, int *playee, int k)
@@ -196,2 +212,2 @@
-piececount(player,startrow,endrow)
-int *player,startrow,endrow;
+int
+piececount(int *player, int startrow, int endrow)
@@ -202 +218 @@
-	sum=+player[startrow++];
+	sum+=player[startrow++];
@@ -221 +237,2 @@
-roll()
+void
+roll(void)
@@ -228,2 +245,2 @@
-movegen(mover,movee)
-int *mover,*movee;
+void
+movegen(int *mover, int *movee)
@@ -237 +254 @@
-		if((k=25-i-die1)>0&&movee[k]>=2)
+		if((k=25-i-die1)>0&&movee[k]>=2) {
@@ -239,0 +257 @@
+		}
@@ -250 +268 @@
-			if((k=25-j-die2)>0&&movee[k]>=2)
+			if((k=25-j-die2)>0&&movee[k]>=2) {
@@ -252,0 +271 @@
+			}
@@ -268 +287 @@
-			    if((k=25-l-die1)>0&&movee[k]>=2)
+			    if((k=25-l-die1)>0&&movee[k]>=2) {
@@ -270,0 +290 @@
+			    }
@@ -281 +301 @@
-				if((k=25-m-die1)>=0&&movee[k]>=2)
+				if((k=25-m-die1)>=0&&movee[k]>=2) {
@@ -283,0 +304 @@
+				}
@@ -315,2 +336,2 @@
-moverecord(mover)
-int *mover;
+void
+moverecord(int *mover)
@@ -326,0 +348 @@
+	    /* fallthrough */
@@ -329,0 +352 @@
+	    /* fallthrough */
@@ -332,0 +356 @@
+	    /* fallthrough */
@@ -357,2 +381,2 @@
-strategy(player,playee)
-int *player,*playee;
+int
+strategy(int *player, int *playee)
@@ -394,2 +418,2 @@
-eval(player,playee,k,prob)
-int *player,*playee,k,*prob;
+int
+eval(int *player, int *playee, int k, int *prob)
@@ -441 +465 @@
-		sum=+ *p++ * n;	/*remove pieces, but just barely*/
+		sum+= *p++ * n;	/*remove pieces, but just barely*/
@@ -449 +473 @@
-	    for(p=newtry;p<q;)sum=- *p++;  /*bad to be on 1st three points*/
+	    for(p=newtry;p<q;)sum-= *p++;  /*bad to be on 1st three points*/
@@ -453 +477 @@
-	    *prob=+ n*getprob(newtry,newother,6*n-5,6*n);
+	    *prob+= n*getprob(newtry,newother,6*n-5,6*n);
@@ -456 +480,2 @@
-instructions()
+void
+instructions(void)
@@ -485,2 +510,2 @@
-getprob(player,playee,start,finish)
-int *player,*playee,start,finish;
+int
+getprob(int *player, int *playee, int start, int finish)
@@ -498 +523 @@
-		    if(playee[n]!=0)sum=+probability[k];
+		    if(playee[n]!=0)sum+=probability[k];
@@ -504 +529,2 @@
-prtbrd()
+void
+prtbrd(void)
@@ -542,2 +568,2 @@
-numline(upcol,downcol,start,fin)
-int *upcol,*downcol,start,fin;
+void
+numline(int *upcol, int *downcol, int start, int fin)
@@ -551,3 +577,2 @@
-colorline(upcol,c1,downcol,c2,start,fin)
-int *upcol,*downcol,start,fin;
-char c1,c2;
+void
+colorline(int *upcol, char c1, int *downcol, char c2, int start, int fin)
@@ -565 +590 @@
-int rrno 0;
+unsigned rrno = 0;
@@ -567,3 +592,3 @@
-srand(){
-	rrno = _look( 0x40000 );
-	_store( 0x40000, rrno+1 );
+void
+srand(void){
+	rrno = time((long *)0);
@@ -572,3 +597,4 @@
-rand(){
-	rrno =* 0106273;
-	rrno =+ 020202;
+int
+rand(void){
+	rrno *= 0106273;
+	rrno += 020202;
@@ -578 +604,2 @@
-_look(p) int *p; {
+int
+_look(int *p) {
@@ -582 +609,2 @@
-_store( p, numb ) int *p; {
+void
+_store( int *p, int numb ){

% usr/src/games/fish.c
@@ -21,0 +22,5 @@
+int	choose(char a[], int n), draw(void), empty(HAND h), mark(HAND hand, int cd);
+int	game(void), move(HAND hs, HAND ht, int g, int v), guess(void), myguess(void);
+void	shuffle(void), error(char *s), score(void), deal(HAND hand, int n), stats(void);
+void	phand(HAND h), instruct(void), madebook(int x), start(HAND h);
+void	hedrew(int d), heguessed(int d);
@@ -25 +30,2 @@
-shuffle(){
+void
+shuffle(void){
@@ -30 +36 @@
-	register i;
+	register int i;
@@ -41 +47,2 @@
-choose( a, n ) char a[]; {
+int
+choose( char a[], int n ){
@@ -44 +51 @@
-	register j, t;
+	register int j, t;
@@ -54 +61,2 @@
-draw() {
+int
+draw(void) {
@@ -59 +67,2 @@
-error( s ) char *s; {
+void
+error( char *s ){
@@ -65,2 +74,3 @@
-empty( h ) HAND h; {
-	register i;
+int
+empty( HAND h ){
+	register int i;
@@ -74 +84,2 @@
-mark( cd, hand ) HAND hand; {
+int
+mark( HAND hand, int cd ){
@@ -84 +95,2 @@
-deal( hand, n ) HAND hand; {
+void
+deal( HAND hand, int n ){
@@ -90 +102 @@
-char *cname[] {
+char *cname[] = {
@@ -107,2 +119,3 @@
-stats(){
-	register i, ct, b;
+void
+stats(void){
+	register int i, ct, b;
@@ -130,2 +143,3 @@
-phand( h ) HAND h; {
-	register i, j;
+void
+phand( HAND h ){
+	register int i, j;
@@ -141 +155 @@
-			register k;
+			register int k;
@@ -157 +171,2 @@
-main( argc, argv ) char * argv[]; { 
+int
+main( int argc, char * argv[] ){ 
@@ -159 +174 @@
-	register c;
+	register int c;
@@ -180 +195 @@
-char *inst[] {
+char *inst[] = {
@@ -208 +223,2 @@
-instruct(){
+void
+instruct(void){
@@ -218 +234,2 @@
-game(){
+int
+game(void){
@@ -229 +246 @@
-		register g;
+		register int g;
@@ -256 +273,2 @@
-move( hs, ht, g, v ) HAND hs, ht; {
+int
+move( HAND hs, HAND ht, int g, int v ){
@@ -259 +277 @@
-	register d;
+	register int d;
@@ -315 +333,2 @@
-madebook( x ){
+void
+madebook( int x ){
@@ -319,2 +338,3 @@
-score(){
-	register my, your, i;
+void
+score(void){
+	register int my, your, i;
@@ -350 +370,2 @@
-guess(){
+int
+guess(void){
@@ -352 +373 @@
-	register g, go;
+	register int g, go;
@@ -427 +448 @@
-char ntry;
+int ntry;
@@ -432 +453,3 @@
-start( h ) HAND h; {
+void
+start( HAND h ){
+	(void)h;
@@ -436 +459,2 @@
-hedrew( d ){
+void
+hedrew( int d ){
@@ -440 +464,2 @@
-heguessed( d ){
+void
+heguessed( int d ){
@@ -444 +469,2 @@
-myguess(){
+int
+myguess(void){
@@ -446 +472 @@
-	register i, lg, t;
+	register int i, lg, t;
@@ -465 +491 @@
-		if( hehas[try[i]] ) {
+		if( hehas[try[i]&0377] ) {
@@ -474 +500 @@
-		if( haveguessed[try[i]] < lg ) lg = haveguessed[try[i]];
+		if( haveguessed[try[i]&0377] < lg ) lg = haveguessed[try[i]&0377];
@@ -480 +506 @@
-		if( haveguessed[try[i]] == lg ) try[t++] = try[i];
+		if( haveguessed[try[i]&0377] == lg ) try[t++] = try[i];

% usr/src/games/fortune.c
@@ -6 +6,2 @@
-main()
+int
+main(void)

% usr/src/games/hangman.c
@@ -12,0 +13,3 @@
+void	setup(void), fatal(char *s), startnew(void), stateout(void), getguess(void);
+void	wordout(void), youwon(void), getword(void), pscore(void);
+double	frand(void);
@@ -14 +17,2 @@
-main(argc,argv) char **argv;
+int
+main(int argc, char **argv)
@@ -31 +35,2 @@
-setup()
+void
+setup(void)
@@ -34,2 +39,2 @@
-	time(tvec);
-	srand(tvec[1]+tvec[2]);
+	time((long *)tvec);
+	srand(tvec[0]);
@@ -40 +45 @@
-double frand()
+double frand(void)
@@ -45 +50,2 @@
-startnew()
+void
+startnew(void)
@@ -57 +63,2 @@
-stateout()
+void
+stateout(void)
@@ -65 +72,2 @@
-getguess()
+void
+getguess(void)
@@ -100 +108,2 @@
-wordout()
+void
+wordout(void)
@@ -105 +114,2 @@
-youwon()
+void
+youwon(void)
@@ -109 +119,2 @@
-fatal(s) char *s;
+void
+fatal(char *s)
@@ -114 +125,2 @@
-getword()
+void
+getword(void)
@@ -135 +147 @@
-long int freq[]
+long int freq[]=
@@ -143 +155,2 @@
-pscore()
+void
+pscore(void)

% usr/src/games/quiz.c
@@ -12 +12 @@
-char score[NL];
+signed char score[NL];
@@ -26 +26,6 @@
-char	*malloc();
+int	readline(void), cmp(char *u, char *v), disj(int s), string(int s);
+int	eat(int s, char c), fold(char c), segment(char *u, char *w[]);
+int	perm(char *u[], int m, char *v[], int n, int p[]), find(char *u[], int m);
+int	query(char *r), next(void);
+void	publish(char *t), done(int sig), instruct(char *info), dunno(void);
+void	pub1(int s), readindex(void), talloc(void), badinfo(void);
@@ -28 +33,2 @@
-readline()
+int
+readline(void)
@@ -31 +37 @@
-	register c;
+	register int c;
@@ -49 +55 @@
-				if(*line==0377)
+				if((*line&0377)==0377)
@@ -60,2 +66,2 @@
-cmp(u,v)
-char *u, *v;
+int
+cmp(char *u, char *v)
@@ -72 +78,2 @@
-disj(s)
+int
+disj(int s)
@@ -86 +93 @@
-			return(t|x&s);
+			return(t|(x&s));
@@ -111 +118,2 @@
-string(s)
+int
+string(int s)
@@ -128,0 +137 @@
+			/* fallthrough */
@@ -155,2 +164,2 @@
-eat(s,c)
-char c;
+int
+eat(int s, char c)
@@ -171,2 +180,2 @@
-fold(c)
-char c;
+int
+fold(char c)
@@ -179,2 +188,2 @@
-publish(t)
-char *t;
+void
+publish(char *t)
@@ -186 +195,2 @@
-pub1(s)
+void
+pub1(int s)
@@ -204,0 +215 @@
+			/* fallthrough */
@@ -212,2 +223,2 @@
-segment(u,w)
-char *u, *w[];
+int
+segment(char *u, char *w[])
@@ -244,3 +255,2 @@
-perm(u,m,v,n,p)
-int p[];
-char *u[], *v[];
+int
+perm(char *u[], int m, char *v[], int n, int p[])
@@ -265,2 +275,2 @@
-find(u,m)
-char *u[];
+int
+find(char *u[], int m)
@@ -277 +287,2 @@
-readindex()
+void
+readindex(void)
@@ -290 +301,2 @@
-talloc()
+void
+talloc(void)
@@ -297,2 +309,2 @@
-main(argc,argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -300 +312 @@
-	register j;
+	register int j;
@@ -306 +317,0 @@
-	extern done();
@@ -310 +321 @@
-	inc = (int)tm&077774|01;
+	inc = ((int)tm&077774)|01;
@@ -385,2 +396,2 @@
-query(r)
-char *r;
+int
+query(char *r)
@@ -391 +402 @@
-			done();
+			done(0);
@@ -404 +415,2 @@
-next()
+int
+next(void)
@@ -413 +425 @@
-			if(flag) done();
+			if(flag) done(0);
@@ -419 +431,2 @@
-done()
+void
+done(int sig)
@@ -420,0 +434 @@
+	(void)sig;
@@ -427,2 +441,2 @@
-instruct(info)
-char *info;
+void
+instruct(char *info)
@@ -465 +479,2 @@
-badinfo(){
+void
+badinfo(void){
@@ -469 +484,2 @@
-dunno()
+void
+dunno(void)

% usr/src/games/wump.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -19 +20,3 @@
-char	*intro[]
+int	tunnel(int i), rline(void), rnum(int n), rin(void);
+int	near(struct room *ap, int ahaz), icomp(char *p1, char *p2);
+char	*intro[] =
@@ -95 +98,2 @@
-main()
+int
+main(void)
@@ -97 +101 @@
-	register i, j;
+	register int i, j;
@@ -99 +103 @@
-	int k, icomp();
+	int k;
@@ -140 +144 @@
-		qsort(&p->tunn[0], NTUNN, 2, icomp);
+		qsort((char *)&p->tunn[0], NTUNN, sizeof(p->tunn[0]), icomp);
@@ -159 +163 @@
-			p->flag =| PIT;
+			p->flag |= PIT;
@@ -166 +170 @@
-			p->flag =| BAT;
+			p->flag |= BAT;
@@ -172 +176 @@
-	room[i].flag =| WUMP;
+	room[i].flag |= WUMP;
@@ -270 +274 @@
-	p->flag =& ~WUMP;
+	p->flag &= ~WUMP;
@@ -274 +278 @@
-	room[wloc].flag =| WUMP;
+	room[wloc].flag |= WUMP;
@@ -287 +291,2 @@
-tunnel(i)
+int
+tunnel(int i)
@@ -290 +295 @@
-	register n, j;
+	register int n, j;
@@ -309 +314,2 @@
-rline()
+int
+rline(void)
@@ -317 +323 @@
-			exit();
+			exit(0);
@@ -324 +330,2 @@
-rnum(n)
+int
+rnum(int n)
@@ -326 +333 @@
-	static first[2];
+	static long first;
@@ -328,3 +335,3 @@
-	if(first[1] == 0) {
-		time(first);
-		srand((first[1]*first[0])^first[1]);
+	if(first == 0) {
+		time(&first);
+		srand(first);
@@ -335 +342,2 @@
-rin()
+int
+rin(void)
@@ -337 +345 @@
-	register n, c;
+	register int n, c;
@@ -345 +353 @@
-					exit();
+					exit(0);
@@ -356,2 +364,2 @@
-near(ap, ahaz)
-struct room *ap;
+int
+near(struct room *ap, int ahaz)
@@ -360 +368 @@
-	register haz, i;
+	register int haz, i;
@@ -370,2 +378,2 @@
-icomp(p1, p2)
-int *p1, *p2;
+int
+icomp(char *p1, char *p2)
@@ -374 +382 @@
-	return(*p1 - *p2);
+	return(*(int *)p1 - *(int *)p2);

% usr/src/libc/csu/crt0.s
@@ -1,36 +1,13 @@
-/ C runtime startoff
-
-.globl	_exit, _environ
-.globl	start
-.globl	_main
-exit = 1.
-
-start:
-	setd
-	mov	2(sp),r0
-	clr	-2(r0)
-	mov	sp,r0
-	sub	$4,sp
-	mov	4(sp),(sp)
-	tst	(r0)+
-	mov	r0,2(sp)
-1:
-	tst	(r0)+
-	bne	1b
-	cmp	r0,*2(sp)
-	blo	1f
-	tst	-(r0)
-1:
-	mov	r0,4(sp)
-	mov	r0,_environ
-	jsr	pc,_main
-	cmp	(sp)+,(sp)+
-	mov	r0,(sp)
-	jsr	pc,*$_exit
-	sys	exit
-
-.bss
-_environ:
-	.=.+2
-.data
-	.=.+2		/ loc 0 for I/D; null ptr points here.
+.globl	_start
+_start:
+	ldr	r0, [sp]
+	add	r1, sp, #4
+	add	r2, r1, r0, lsl #2
+	add	r2, r2, #4
+	ldr	r3, =environ
+	str	r2, [r3]
+	bl	main
+	bl	exit
+	mov	r7, #1
+	svc	#0
+.comm	environ, 4

% usr/src/libc/gen/abort.c usr/src/libc/gen/abort.s
@@ -1 +1,2 @@
-/ C library -- abort
+#include <stdio.h>
+#include <signal.h>
@@ -3,9 +4,5 @@
-.globl	_abort
-iot	= 4
-.globl	csv,cret
-
-_abort:
-	jsr	r5,csv
-	iot
-	clr	r0
-	jmp	cret
+void
+abort(void)
+{
+	kill(getpid(), SIGIOT);
+}

% usr/src/libc/gen/atof.c
@@ -9,2 +9 @@
-atof(p)
-register char *p;
+atof(register char *p)
@@ -12 +11 @@
-	register c;
+	register int c;
@@ -15 +13,0 @@
-	double ldexp();
@@ -17 +15 @@
-	register eexp, exp, neg, negexp, bexp;
+	register int eexp, exp, neg, negexp, bexp;
@@ -61 +59,2 @@
-			eexp = 10*eexp+(c-'0');
+			if (eexp < 10000)
+				eexp = 10*eexp+(c-'0');
@@ -75 +74 @@
-	if((nd+exp*negexp) < -LOGHUGE){
+	if(fl == 0 || (nd+exp*negexp) < -LOGHUGE){

% usr/src/libc/gen/atoi.c
@@ -1,2 +1,3 @@
-atoi(p)
-register char *p;
+#include <stdio.h>
+int
+atoi(register char *p)
@@ -15,0 +17 @@
+			/* fallthrough */

% usr/src/libc/gen/atol.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -2,2 +3 @@
-atol(p)
-register char *p;
+atol(register char *p)
@@ -16,0 +17 @@
+			/* fallthrough */

% usr/src/libc/gen/calloc.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -7,2 +8 @@
-calloc(num, size)
-unsigned num, size;
+calloc(unsigned num, unsigned size)
@@ -11 +10,0 @@
-	char *malloc();
@@ -13 +12 @@
-	register m;
+	register int m;
@@ -26,3 +25,2 @@
-cfree(p, num, size)
-char *p;
-unsigned num, size;
+void
+cfree(char *p, unsigned num, unsigned size)
@@ -29,0 +28,2 @@
+	(void)num;
+	(void)size;

% usr/src/libc/gen/crypt.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -49 +50 @@
-static	char	PC1_D[] {
+static	char	PC1_D[] = {
@@ -97,2 +98,2 @@
-setkey(key)
-char *key;
+void
+setkey(char *key)
@@ -100 +101 @@
-	register i, j, k;
+	register int i, j, k;
@@ -146 +147 @@
-static	char	e[] {
+static	char	e[] = {
@@ -162 +163 @@
-static	char	S[8][64] {
+static	char	S[] = {
@@ -208 +209 @@
-static	char	P[] {
+static	char	P[] = {
@@ -222 +223,2 @@
-static	char	L[32], R[32];
+static	char	L[64];
+#define	R	(L+32)
@@ -235,2 +237,2 @@
-encrypt(block, edflag)
-char *block;
+void
+encrypt(char *block, int edflag)
@@ -239 +241 @@
-	register t, j, k;
+	register int t, j, k;
@@ -282 +284 @@
-			k = S[j][(preS[t+0]<<5)+
+			k = S[j*64 + (preS[t+0]<<5)+
@@ -324,3 +326 @@
-crypt(pw,salt)
-char *pw;
-char *salt;
+crypt(char *pw, char *salt)
@@ -328 +328 @@
-	register i, j, c;
+	register int i, j, c;

% usr/src/libc/gen/ctime.c
@@ -39,0 +40 @@
+#include <stdio.h>
@@ -67,2 +68,2 @@
-	5,	333,	/* 1974: Jan 6 - last Sun. in Nov */
-	58,	303,	/* 1975: Last Sun. in Feb - last Sun in Oct */
+	{5,	333},	/* 1974: Jan 6 - last Sun. in Nov */
+	{58,	303},	/* 1975: Last Sun. in Feb - last Sun in Oct */
@@ -71,6 +72,2 @@
-struct tm	*gmtime();
-char		*ct_numb();
-struct tm	*localtime();
-char	*ctime();
-char	*ct_num();
-char	*asctime();
+static char	*ct_numb(char *cp, int n);
+static int	sunday(struct tm *t, int d);
@@ -79,2 +76 @@
-ctime(t)
-long *t;
+ctime(long *t)
@@ -86,2 +82 @@
-localtime(tim)
-long *tim;
+localtime(long *tim)
@@ -91 +86 @@
-	register daylbegin, daylend;
+	register int daylbegin, daylend;
@@ -122,4 +117,2 @@
-static
-sunday(t, d)
-register struct tm *t;
-register int d;
+static int
+sunday(register struct tm *t, register int d)
@@ -133,2 +126 @@
-gmtime(tim)
-long *tim;
+gmtime(long *tim)
@@ -195,2 +187 @@
-asctime(t)
-struct tm *t;
+asctime(struct tm *t)
@@ -202 +193 @@
-	for (ncp = "Day Mon 00 00:00:00 1900\n"; *cp++ = *ncp++;);
+	for (ncp = "Day Mon 00 00:00:00 1900\n"; (*cp++ = *ncp++););
@@ -227 +218,2 @@
-dysize(y)
+int
+dysize(int y)
@@ -235,2 +227 @@
-ct_numb(cp, n)
-register char *cp;
+ct_numb(register char *cp, int n)

% usr/src/libc/gen/ctype_.c
@@ -3 +3 @@
-char _ctype_[] = {
+char _ctype_[1+256] = {

% usr/src/libc/gen/cuexit.c usr/src/libc/gen/cuexit.s
@@ -1,15 +1 @@
-/ C library -- exit
-
-/ exit(code)
-/ code is return in r0 to system
-
-.globl	_exit
-.globl	__cleanup
-exit = 1
-
-_exit:
-	mov	r5,-(sp)
-	mov	sp,r5
-	jsr	pc,__cleanup
-	mov	4(r5),r0
-	sys	exit
+#include <stdio.h>
@@ -16,0 +3,6 @@
+void
+exit(int n)
+{
+	_cleanup();
+	_exit(n);
+}

% usr/src/libc/gen/ecvt.c
@@ -8 +8,3 @@
-char	*cvt();
+#include <stdio.h>
+#include <math.h>
+static char	*cvt(double arg, int ndigits, int *decpt, int *sign, int eflag);
@@ -12,3 +14 @@
-ecvt(arg, ndigits, decpt, sign)
-double arg;
-int ndigits, *decpt, *sign;
+ecvt(double arg, int ndigits, int *decpt, int *sign)
@@ -20,3 +20 @@
-fcvt(arg, ndigits, decpt, sign)
-double arg;
-int ndigits, *decpt, *sign;
+fcvt(double arg, int ndigits, int *decpt, int *sign)
@@ -28,3 +26 @@
-cvt(arg, ndigits, decpt, sign, eflag)
-double arg;
-int ndigits, *decpt, *sign;
+cvt(double arg, int ndigits, int *decpt, int *sign, int eflag)
@@ -36 +31,0 @@
-	double modf();
@@ -48,0 +44,2 @@
+	if (!(arg <= 1.7976931348623157e308))
+		arg = 1.7976931348623157e308;
@@ -55,0 +53,3 @@
+		for (; fi >= 1e40; r2 += 10)
+			fi /= 1e10;
+		modf(fi, &fi);

% usr/src/libc/gen/errlst.c

% usr/src/libc/gen/execvp.c
@@ -6,0 +7,2 @@
+#include <stdio.h>
+#include <stdarg.h>
@@ -9,2 +11,2 @@
-char	*execat(), *getenv();
-extern	errno;
+static char	*execat(char *s1, char *s2, char *si);
+extern	int errno;
@@ -12,2 +14,2 @@
-execlp(name, argv)
-char *name, *argv;
+int
+execlp(char *name, char *arg0, ...)
@@ -15 +17,18 @@
-	return(execvp(name, &argv));
+	va_list ap;
+	int n;
+
+	n = 2;
+	va_start(ap, arg0);
+	while(va_arg(ap, char *) != 0)
+		n++;
+	va_end(ap);
+	{
+	char *argv[n];
+
+	argv[0] = arg0;
+	va_start(ap, arg0);
+	for(n=1; (argv[n] = va_arg(ap, char *)); n++)
+		;
+	va_end(ap);
+	return(execvp(name, argv));
+	}
@@ -18,2 +37,2 @@
-execvp(name, argv)
-char *name, **argv;
+int
+execvp(char *name, char **argv)
@@ -23 +41,0 @@
-	char fname[128];
@@ -27 +45 @@
-	register eacces = 0;
+	register int eacces = 0;
@@ -31,0 +50 @@
+	char fname[strlen(pathstr)+strlen(name)+2];
@@ -41 +60 @@
-			for (i=1; newargs[i+1]=argv[i]; i++) {
+			for (i=1; (newargs[i+1]=argv[i]); i++) {
@@ -68,3 +87 @@
-execat(s1, s2, si)
-register char *s1, *s2;
-char *si;
+execat(register char *s1, register char *s2, char *si)
@@ -75 +92 @@
-	while (*s1 && *s1 != ':' && *s1 != '-')
+	while (*s1 && *s1 != ':')

% usr/src/libc/gen/frexp.c usr/src/libc/gen/frexp11.s
@@ -1,4 +1,5 @@
-/  double frexp(x, ip)
-/  double x; int *ip;
-/  returns a fractional part 1/16 <= |value| < 1
-/ and stores an exponent so x = value * 2^(*ip)
+#include <math.h>
+double
+frexp(double value, int *eptr)
+{
+	union { double d; unsigned u[2]; } x;
@@ -6,11 +7,12 @@
-.globl	_frexp
-.globl	csv, cret
-
-_frexp:
-	jsr	r5,csv
-	movf	4(r5),fr0
-	movei	fr0,r0
-	clr	r1
-	movie	r1,fr0
-	mov	r0,*12.(r5)
-	jmp	cret
+	*eptr = 0;
+	if (value == 0)
+		return(value);
+	x.d = value;
+	if ((x.u[1] & 0x7ff00000) == 0) {
+		x.d *= 18014398509481984.0;
+		*eptr = -54;
+	}
+	*eptr += (int)(x.u[1]>>20 & 03777) - 1022;
+	x.u[1] = (x.u[1] & 0x800fffff) | 1022<<20;
+	return(x.d);
+}

% usr/src/libc/gen/getenv.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -7 +8 @@
-char	*nvmatch();
+static char	*nvmatch(char *s1, char *s2);
@@ -10,2 +11 @@
-getenv(name)
-register char *name;
+getenv(register char *name)
@@ -30,2 +30 @@
-nvmatch(s1, s2)
-register char *s1, *s2;
+nvmatch(register char *s1, register char *s2)

% usr/src/libc/gen/getlogin.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -4,0 +6 @@
+static	char	name[9];
@@ -7 +9 @@
-getlogin()
+getlogin(void)
@@ -9 +11 @@
-	register me, uf;
+	register int me, uf;
@@ -20,2 +22,3 @@
-	ubuf.ut_name[8] = ' ';
-	for (cp=ubuf.ut_name; *cp++!=' ';)
+	strncpy(name, ubuf.ut_name, 8);
+	name[8] = ' ';
+	for (cp=name; *cp++!=' ';)
@@ -24 +27 @@
-	return( ubuf.ut_name );
+	return(name);

% usr/src/libc/gen/index.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -9,2 +10 @@
-index(sp, c)
-register char *sp, c;
+index(register char *sp, register char c)

% usr/src/libc/gen/isatty.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -7 +8,2 @@
-isatty(f)
+int
+isatty(int f)

% usr/src/libc/gen/l3.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -4,4 +5,2 @@
-ltol3(cp, lp, n)
-char	*cp;
-long	*lp;
-int	n;
+void
+ltol3(char *cp, long *lp, int n)
@@ -9 +8 @@
-	register i;
+	register int i;
@@ -22 +20,0 @@
-		b++;
@@ -24,0 +23 @@
+		b++;
@@ -29,4 +28,2 @@
-l3tol(lp, cp, n)
-long	*lp;
-char	*cp;
-int	n;
+void
+l3tol(long *lp, char *cp, int n)
@@ -34 +31 @@
-	register i;
+	register int i;
@@ -47 +43,0 @@
-		*a++ = 0;
@@ -49,0 +46 @@
+		*a++ = 0;

% usr/src/libc/gen/ldexp.c usr/src/libc/gen/ldexp11.s
@@ -1,3 +1,2 @@
-/ double ldexp(number, exp)
-/ double number
-/  -- returns number * 2^exp
+#include <errno.h>
+#include <math.h>
@@ -5,2 +4,5 @@
-.globl	_ldexp
-.globl	csv, cret
+double
+ldexp(double value, int n)
+{
+	union { double d; unsigned u[2]; } x;
+	register int k;
@@ -8,24 +10,12 @@
-ERANGE = 34.
-
-_ldexp:
-	jsr	r5,csv
-	movf	4(r5),fr0
-	movei	fr0,r0
-	add	12.(r5),r0
-	movie	r0,fr0
-	cfcc
-	bvc	1f
-	bmi	2f
-	movf	huge,fr0
-	br	3f
-2:
-	movf	huge,fr0
-	negf	fr0
-3:
-	mov	$ERANGE,_errno
-1:
-	jmp	cret
-
-	.comm	_errno,2
-	.data
-huge:	077777; 0177776; 0177777; 0177777
+	x.u[0] = 0;
+	for (; n; n -= k) {
+		k = n > 1000? 1000: n < -1000? -1000: n;
+		x.u[1] = (k+1023) << 20;
+		value *= x.d;
+	}
+	if (value > 1.7976931348623157e308 || value < -1.7976931348623157e308) {
+		errno = ERANGE;
+		value = value < 0? -1.7976931348623157e308: 1.7976931348623157e308;
+	}
+	return(value);
+}

% usr/src/libc/gen/malloc.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -38 +39 @@
-#define ALIGN int
+#define ALIGN double
@@ -57 +57,0 @@
-char	*sbrk();
@@ -60,2 +60 @@
-malloc(nbytes)
-unsigned nbytes;
+malloc(unsigned nbytes)
@@ -64,2 +63,2 @@
-	register nw;
-	static temp;	/*coroutines assume no auto*/
+	register int nw;
+	static int temp;	/*coroutines assume no auto*/
@@ -72,0 +72,2 @@
+	if(nbytes > (~0u>>1) - BLOCK - 2*WORD)
+		return(NULL);
@@ -83 +84 @@
-				if(q>=p+nw && p+nw>=p)
+				if(q-p >= nw)
@@ -98 +99 @@
-		if(q+temp+GRANULE < q) {
+		if((unsigned)q+(temp+GRANULE)*WORD < (unsigned)q) {
@@ -125,2 +126,2 @@
-free(ap)
-register char *ap;
+void
+free(register char *ap)
@@ -145,3 +146 @@
-realloc(p, nbytes)
-register union store *p;
-unsigned nbytes;
+realloc(char *ap, unsigned nbytes)
@@ -148,0 +148 @@
+	register union store *p = (union store *)ap;

% usr/src/libc/gen/mktemp.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -2,2 +3 @@
-mktemp(as)
-char *as;
+mktemp(char *as)
@@ -7 +7 @@
-	register i;
+	register int i;

% usr/src/libc/gen/modf.c usr/src/libc/gen/modf11.s
@@ -1,4 +1,6 @@
-/ double modf(x, *fp)
-/ double x, *fp;
-/ return fractional part
-/ stash integer part (as double)
+#include <math.h>
+double
+modf(double value, double *iptr)
+{
+	union { double d; unsigned u[2]; } x;
+	register int e;
@@ -6,10 +8,13 @@
-.globl	_modf
-.globl	csv, cret
-one	= 040200
-
-_modf:
-	jsr	r5,csv
-	movf	4(r5),fr0
-	modf	$one,fr0
-	movf	fr1,*12.(r5)
-	jmp	cret
+	x.d = value;
+	e = (int)(x.u[1]>>20 & 03777) - 1023;
+	if (e < 0) {
+		x.u[1] &= 0x80000000;
+		x.u[0] = 0;
+	} else if (e < 20) {
+		x.u[1] &= ~(0xfffff>>e);
+		x.u[0] = 0;
+	} else if (e < 52)
+		x.u[0] &= ~(0xffffffff>>(e-20));
+	*iptr = x.d;
+	return(value - x.d);
+}

% usr/src/libc/gen/nlist.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -2 +2,0 @@
-int a_magic[] = {A_MAGIC1, A_MAGIC2, A_MAGIC3, A_MAGIC4, 0};
@@ -5,3 +5,2 @@
-nlist(name, list)
-char *name;
-struct nlist *list;
+int
+nlist(char *name, struct nlist *list)
@@ -9,2 +8,3 @@
-	register struct nlist *p, *q;
-	int f, n, m, i;
+	register struct nlist *p;
+	register unsigned *q;
+	int f, m, i;
@@ -12,2 +12,2 @@
-	struct exec buf;
-	struct nlist space[SPACE];
+	unsigned n, buf[13], sh[10], space[4*SPACE], st;
+	char c[10];
@@ -22,4 +22,2 @@
-	read(f, (char *)&buf, sizeof buf);
-	for(i=0; a_magic[i]; i++)
-		if(a_magic[i] == buf.a_magic) break;
-	if(a_magic[i] == 0){
+	read(f, (char *)buf, sizeof buf);
+	if(buf[0] != 0x464c457f){
@@ -29,5 +27,12 @@
-	sa = buf.a_text + (long)buf.a_data;
-	if(buf.a_flag != 1) sa *= 2;
-	sa += sizeof buf;
-	lseek(f, sa, 0);
-	n = buf.a_syms;
+	n = st = 0;
+	for(i = buf[12]&0xffff; --i >= 0 && n == 0; ) {
+		lseek(f, buf[8] + i*40, 0);
+		read(f, (char *)sh, sizeof sh);
+		if(sh[1] == 2) {
+			sa = sh[4];
+			n = sh[5];
+			lseek(f, buf[8] + sh[6]*40, 0);
+			read(f, (char *)sh, sizeof sh);
+			st = sh[4];
+		}
+	}
@@ -38,0 +44 @@
+		lseek(f, sa, 0);
@@ -41,9 +47,10 @@
-		for(q = space; (m -= sizeof(struct nlist)) >= 0; q++) {
-			for(p = list; p->n_name[0]; p++) {
-				for(i=0;i<8;i++)
-					if(p->n_name[i] != q->n_name[i]) goto cont;
-				p->n_value = q->n_value;
-				p->n_type = q->n_type;
-				break;
-		cont:		;
-			}
+		sa += m;
+		for(q = space; (m -= 16) >= 0; q += 4) {
+			c[0] = '_';
+			lseek(f, st + q[0], 0);
+			c[read(f, c+1, 8) + 1] = 0;
+			for(p = list; p->n_name[0]; p++)
+				if(strncmp(p->n_name, c, 8) == 0) {
+					p->n_value = q[1];
+					p->n_type = N_EXT|N_DATA;
+				}

% usr/src/libc/gen/perror.c
@@ -6,5 +6,6 @@
-int	errno;
-int	sys_nerr;
-char	*sys_errlist[];
-perror(s)
-char *s;
+#include <stdio.h>
+extern int	errno;
+extern int	sys_nerr;
+extern char	*sys_errlist[];
+void
+perror(char *s)
@@ -13 +14 @@
-	register n;
+	register int n;

% usr/src/libc/gen/qsort.c
@@ -0,0 +1,3 @@
+#include <stdio.h>
+static void qs1(char *a, char *l), qsexc(char *i, char *j),
+	qstexc(char *i, char *j, char *k);
@@ -2 +5 @@
-static int	(*qscmp)();
+static int	(*qscmp)(char *p1, char *p2);
@@ -5,5 +8,2 @@
-qsort(a, n, es, fc)
-char *a;
-unsigned n;
-int es;
-int (*fc)();
+void
+qsort(char *a, unsigned n, int es, int (*fc)(char *p1, char *p2))
@@ -16,2 +16 @@
-static qs1(a, l)
-char *a, *l;
+static void qs1(char *a, char *l)
@@ -20,2 +19 @@
-	register es;
-	char **k;
+	register unsigned es;
@@ -87,2 +85 @@
-static qsexc(i, j)
-char *i, *j;
+static void qsexc(char *i, char *j)
@@ -103,2 +100 @@
-static qstexc(i, j, k)
-char *i, *j, *k;
+static void qstexc(char *i, char *j, char *k)

% usr/src/libc/gen/rand.c
@@ -1 +1,2 @@
-static	long	randx = 1;
+#include <stdio.h>
+static	unsigned long	randx = 1;
@@ -3,2 +4,2 @@
-srand(x)
-unsigned x;
+void
+srand(unsigned x)
@@ -9 +10,2 @@
-rand()
+int
+rand(void)

% usr/src/libc/gen/rindex.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -9,2 +10 @@
-rindex(sp, c)
-register char *sp, c;
+rindex(register char *sp, register char c)

% usr/src/libc/gen/setjmp.s
@@ -1,41 +1,5 @@
-/ C library -- setjmp, longjmp
-
-/	longjmp(a,v)
-/ will generate a "return(v)" from
-/ the last call to
-/	setjmp(a)
-/ by restoring sp, r5, pc from `a'
-/ and doing a return.
-/
-
-.globl	_setjmp
-.globl	_longjmp
-.globl	csv, cret
-
-_setjmp:
-	mov	2(sp),r0
-	mov	r5,(r0)+
-	mov	sp,(r0)+
-	mov	(sp),(r0)
-	clr	r0
-	rts	pc
-
-_longjmp:
-	jsr	r5,csv
-	mov	4(r5),r1
-	mov	6(r5),r0
-	bne	1f
-	mov	$1,r0
-1:
-	cmp	(r5),(r1)
-	beq	1f
-	mov	(r5),r5
-	bne	1b
-/ panic -- r2-r4 lost
-	mov	(r1)+,r5
-	mov	(r1)+,sp
-	mov	(r1),(sp)
-	rts	pc
-1:
-	mov	4(r1),2(r5)
-	jmp	cret
+.globl setjmp
+setjmp:
+	stmia r0, {r4-r11, sp, lr}
+	mov r0, #0
+	bx lr
@@ -42,0 +7,6 @@
+.globl longjmp
+longjmp:
+	ldmia r0, {r4-r11, sp, lr}
+	movs r0, r1
+	moveq r0, #1
+	bx lr

% usr/src/libc/gen/sleep.c
@@ -2,0 +3 @@
+#include <stdio.h>
@@ -4,0 +6 @@
+static void sleepx(int sig);
@@ -6,2 +8,2 @@
-sleep(n)
-unsigned n;
+void
+sleep(volatile unsigned n)
@@ -9,3 +11,2 @@
-	int sleepx();
-	unsigned altime;
-	int (*alsig)() = SIG_DFL;
+	volatile unsigned altime;
+	void (*volatile alsig)(int sig) = SIG_DFL;
@@ -36,2 +37,2 @@
-static
-sleepx()
+static void
+sleepx(int sig)
@@ -38,0 +40 @@
+	(void)sig;

% usr/src/libc/gen/strcat.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -7,2 +8 @@
-strcat(s1, s2)
-register char *s1, *s2;
+strcat(register char *s1, register char *s2)
@@ -16 +16 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strcmp.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -5,2 +6,2 @@
-strcmp(s1, s2)
-register char *s1, *s2;
+int
+strcmp(register char *s1, register char *s2)

% usr/src/libc/gen/strcpy.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -7,2 +8 @@
-strcpy(s1, s2)
-register char *s1, *s2;
+strcpy(register char *s1, register char *s2)
@@ -13 +13 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strlen.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -6,2 +7,2 @@
-strlen(s)
-register char *s;
+int
+strlen(register char *s)
@@ -9 +10 @@
-	register n;
+	register int n;

% usr/src/libc/gen/strncat.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -8,3 +9 @@
-strncat(s1, s2, n)
-register char *s1, *s2;
-register n;
+strncat(register char *s1, register char *s2, register int n)
@@ -18 +17 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strncmp.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -5,3 +6,2 @@
-strncmp(s1, s2, n)
-register char *s1, *s2;
-register n;
+int
+strncmp(register char *s1, register char *s2, register int n)

% usr/src/libc/gen/strncpy.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -7,2 +8 @@
-strncpy(s1, s2, n)
-register char *s1, *s2;
+strncpy(register char *s1, register char *s2, int n)
@@ -10 +10 @@
-	register i;
+	register int i;

% usr/src/libc/gen/stty.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -7,2 +8,2 @@
-stty(fd, ap)
-struct sgtty *ap;
+int
+stty(int fd, struct sgttyb *ap)
@@ -13,2 +14,2 @@
-gtty(fd, ap)
-struct sgtty *ap;
+int
+gtty(int fd, struct sgttyb *ap)

% usr/src/libc/gen/swab.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -6,3 +7,2 @@
-swab(pf, pt, n)
-register short *pf, *pt;
-register n;
+void
+swab(register char *pf, register char *pt, register int n)
@@ -9,0 +10 @@
+	register int c;
@@ -13,2 +14,3 @@
-		*pt++ = (*pf << 8) + ((*pf >> 8) & 0377);
-		pf++;
+		c = *pf++;
+		*pt++ = *pf++;
+		*pt++ = c;

% usr/src/libc/gen/tell.c
@@ -5 +5 @@
-long	lseek();
+#include <stdio.h>
@@ -7 +7 @@
-long tell(f)
+long tell(int f)

% usr/src/libc/gen/timezone.c
@@ -9,0 +10 @@
+#include <stdio.h>
@@ -15,7 +16,7 @@
-	4*60, "AST", "ADT",		/* Atlantic */
-	5*60, "EST", "EDT",		/* Eastern */
-	6*60, "CST", "CDT",		/* Central */
-	7*60, "MST", "MDT",		/* Mountain */
-	8*60, "PST", "PDT",		/* Pacific */
-	0, "GMT", 0,			/* Greenwich */
-	-1
+	{4*60, "AST", "ADT"},		/* Atlantic */
+	{5*60, "EST", "EDT"},		/* Eastern */
+	{6*60, "CST", "CDT"},		/* Central */
+	{7*60, "MST", "MDT"},		/* Mountain */
+	{8*60, "PST", "PDT"},		/* Pacific */
+	{0, "GMT", 0},			/* Greenwich */
+	{-1, 0, 0}
@@ -24 +25 @@
-char *timezone(zone, dst)
+char *timezone(int zone, int dst)

% usr/src/libc/gen/ttyname.c
@@ -10,0 +11 @@
+#include <stdio.h>
@@ -13,2 +13,0 @@
-char	*strcpy();
-char	*strcat();
@@ -17 +16 @@
-ttyname(f)
+ttyname(int f)
@@ -23 +22 @@
-	register df;
+	register int df;

% usr/src/libc/gen/ttyslot.c
@@ -6,0 +7 @@
+#include <stdio.h>
@@ -8,3 +9 @@
-char	*ttyname();
-char	*getttys();
-char	*rindex();
+static char	*getttys(int f);
@@ -15 +14,2 @@
-ttyslot()
+int
+ttyslot(void)
@@ -18 +18 @@
-	register s, tf;
+	register int s, tf;
@@ -29 +29 @@
-	while (tp = getttys(tf)) {
+	while ((tp = getttys(tf))) {
@@ -41 +41 @@
-getttys(f)
+getttys(int f)

% usr/src/libc/memcpy.c /dev/null
@@ -0,0 +1,23 @@
+char	*memcpy(char *d, char *s, unsigned n);
+char	*memset(char *d, int c, unsigned n);
+char *
+memcpy(char *d, register char *s, register unsigned n)
+{
+	register char *p;
+
+	p = d;
+	while (n--)
+		*p++ = *s++;
+	return(d);
+}
+
+char *
+memset(char *d, int c, register unsigned n)
+{
+	register char *p;
+
+	p = d;
+	while (n--)
+		*p++ = c;
+	return(d);
+}

% usr/src/libc/stdio/clrerr.c
@@ -3,2 +3,2 @@
-clearerr(iop)
-register struct _iobuf *iop;
+void
+clearerr(register struct _iobuf *iop)

% usr/src/libc/stdio/data.c

% usr/src/libc/stdio/doprnt.c usr/src/libc/stdio/doprnt.s
@@ -1 +1,2 @@
-/ C library -- conversions
+#include <stdio.h>
+#include <stdarg.h>
@@ -3,7 +4 @@
-width=-8.
-formp=-10.
-rjust=-12.
-ndfnd=-14.
-ndigit=-16.
-zfill=-18.
-.globl	__doprnt
+void	_doprnt(char *fmt, va_list *argp, FILE *iop);
@@ -11,313 +6,160 @@
-.globl	pfloat
-.globl	pscien
-.globl	pgen
-
-.globl	__strout
-.globl	csv
-.globl	cret
-
-__doprnt:
-	jsr	r5,csv
-	sub	$128.+12.,sp
-	mov	4(r5),formp(r5)		/ format
-	mov	6(r5),r4
-loop:
-	mov	sp,r3
-	mov	formp(r5),r1
-2:
-	movb	(r1)+,r2
-	beq	2f
-	cmp	r2,$'%
-	beq	2f
-	movb	r2,(r3)+
-	br	2b
-2:
-	mov	r1,formp(r5)
-	cmp	r3,sp
-	beq	2f
-	mov	sp,r0
-	mov	8(r5),-(sp)
-	clr	-(sp)
-	mov	r3,-(sp)
-	sub	r0,(sp)
-	mov	r0,-(sp)
-	jsr	pc,__strout
-	add	$8,sp
-2:
-	tst	r2
-	bne	2f
-	jmp	cret
-2:
-	mov	sp,r3
-2:
-	clr	rjust(r5)
-	clr	ndigit(r5)
-	mov	$' ,zfill(r5)
-	cmpb	*formp(r5),$'-
-	bne	2f
-	inc	formp(r5)
-	inc	rjust(r5)
-2:
-	cmpb	*formp(r5),$'0
-	bne	2f
-	mov	$'0,zfill(r5)
-2:
-	jsr	r3,gnum
-	mov	r1,width(r5)
-	clr	ndfnd(r5)
-	cmp	r0,$'.
-	bne	1f
-	jsr	r3,gnum
-	mov	r1,ndigit(r5)
-1:
-	mov	$swtab,r1
-1:
-	mov	(r1)+,r2
-	bne	2f
-	movb	r0,(r3)+
-	jmp	prbuf
-2:
-	cmp	r0,(r1)+
-	bne	1b
-	jmp	(r2)
-	.data
-swtab:
-	decimal;	'd
-	octal;		'o
-	hex;		'x
-	float;		'f
-	scien;		'e
-	general;	'g
-	charac;		'c
-	string;		's
-	longorunsg;	'l
-	longorunsg;	'L
-	unsigned;	'u
-	remote;		'r
-	long;		'D
-	loct;		'O
-	lhex;		'X
-	lunsigned;	'U
-	0;  0
-	.text
-
-general:
-	mov	ndigit(r5),r0
-	mov	ndfnd(r5),r2
-	jsr	pc,pgen
-	jbr	prbuf
-
-longorunsg:
-	movb	*formp(r5),r0
-	inc	formp(r5)
-	cmp	r0,$'o
-	beq	loct
-	cmp	r0,$'x
-	beq	lhex
-	cmp	r0,$'d
-	beq	long
-	cmp	r0,$'u
-	beq	lunsigned
-	dec	formp(r5)
-	br	unsigned
-
-octal:
-	clr	r0
-	br	1f
-loct:
-	mov	(r4)+,r0
-1:
-	mov	$8.,r2
-	br	2f
-
-hex:
-	clr	r0
-	br	1f
-
-lhex:
-	mov	(r4)+,r0
-1:
-	mov	$16.,r2
-2:
-	mov	(r4)+,r1
-	br	compute
-
-decimal:
-	mov	(r4)+,r1
-	sxt	r0
-	bmi	3f
-	br	2f
-
-unsigned:
-	clr	r0
-	br	1f
-
-long:
-	mov	(r4)+,r0
-	bge	1f
-	mov	(r4)+,r1
-3:
-	neg	r0
-	neg	r1
-	sbc	r0
-	movb	$'-,(r3)+
-	br	2f
-
-lunsigned:
-	mov	(r4)+,r0
-1:
-	mov	(r4)+,r1
-2:
-	mov	$10.,r2
-
-/
-/ Algorithm courtesy Keith Davis
-/
-compute:
-	mov	r5,-(sp)
-	mov	r4,-(sp)
-	mov	r0,r4
-	mov	ndigit(r5),r0
-	mov	r1,r5
-	ashc	$0,r4
-	beq	1f
-	tst	r0
-	beq	1f
-	movb	$'0,(r3)+
-1:
-	jsr	pc,1f
-	mov	(sp)+,r4
-	mov	(sp)+,r5
-	br	prbuf
-
-1:
-	clr	r0
-	mov	r4,r1
-	beq	2f
-	div	r2,r0
-	mov	r0,r4
-	mov	r1,r0
-2:
-	mov	r5,r1
-	asl	r2
-	div	r2,r0
-	asr	r2
-	asl	r0
-	cmp	r2,r1
-	bgt	2f
-	sub	r2,r1
-	inc	r0
-2:
-	mov	r1,-(sp)
-	mov	r0,r5
-	bne	2f
-	tst	r4
-	beq	1f
-2:
-	jsr	pc,1b
-1:
-	mov	(sp)+,r0
-	add	$'0,r0
-	cmp	r0,$'9
-	ble	1f
-	add	$'a-'0-10.,r0
-1:
-	movb	r0,(r3)+
-	rts	pc
-	
-charac:
-	mov	$' ,zfill(r5)
-	mov	(r4)+,r0
-	bic	$!377,r0
-	beq	prbuf
-	movb	r0,(r3)+
-	br	prbuf
-
-string:
-	mov	$' ,zfill(r5)
-	mov	ndigit(r5),r1
-	mov	(r4),r2
-	mov	r2,r3
-	bne	1f
-	mov	$nulstr,r2
-	mov	r2,r3
-	mov	r2,(r4)
-1:
-	tstb	(r2)+
-	beq	1f
-	inc	r3
-	sob	r1,1b
-1:
-	mov	(r4)+,r2
-	br	prstr
-
-float:
-	mov	ndigit(r5),r0
-	mov	ndfnd(r5),r2
-	jsr	pc,pfloat
-	br	prbuf
-
-scien:
-	mov	ndigit(r5),r0
-	inc	r0
-	tst	ndfnd(r5)
-	bne	1f
-	mov	$7,r0
-1:
-	mov	pc,r2
-	jsr	pc,pscien
-	br	prbuf
-
-remote:
-	mov	(r4)+,r4
-	mov	(r4)+,formp(r5)
-	jmp	loop
-
-prbuf:
-	mov	sp,r2
-prstr:
-	sub	r2,r3
-	mov	width(r5),r1
-	sub	r3,r1
-	bge	1f
-	clr	r1
-1:
-	tst	rjust(r5)
-	bne	1f
-	neg	r1
-1:
-	mov	zfill(r5),-(sp)
-	mov	8(r5),-(sp)
-	mov	r1,-(sp)
-	mov	r3,-(sp)
-	mov	r2,-(sp)
-	jsr	pc,__strout
-	add	$10.,sp
-	jmp	loop
-
-gnum:
-	clr	ndfnd(r5)
-	clr	r1
-1:
-	movb	*formp(r5),r0
-	inc	formp(r5)
-	sub	$'0,r0
-	cmp	r0,$'*-'0
-	bne	2f
-	mov	(r4)+,r0
-	br	3f
-2:
-	cmp	r0,$9.
-	bhi	1f
-3:
-	inc	ndfnd(r5)
-	mul	$10.,r1
-	add	r0,r1
-	br	1b
-1:
-	add	$'0,r0
-	rts	r3
-
-.data
-nulstr:
-	<(null)\0>
+static int
+gnum(register char **fmtp, va_list *argp)
+{
+	register int n;
+
+	if (**fmtp == '*') {
+		(*fmtp)++;
+		return(va_arg(*argp, int));
+	}
+	for (n = 0; **fmtp >= '0' && **fmtp <= '9'; )
+		n = n*10 + *(*fmtp)++ - '0';
+	return(n);
+}
+
+void
+_doprnt(char *fmt, va_list *argp, FILE *iop)
+{
+	char buf[400];
+	register char *p, *s;
+	register int c;
+	int width, ndigit, ndfnd, rjust, zfill, base, decpt, sign;
+	unsigned long u;
+
+	for (;;) {
+		for (s = fmt; *fmt && *fmt != '%'; fmt++)
+			;
+		if (fmt > s)
+			_strout(s, fmt-s, 0, iop, ' ');
+		if (*fmt++ == '\0')
+			return;
+		rjust = 0;
+		zfill = ' ';
+		if (*fmt == '-') {
+			fmt++;
+			rjust++;
+		}
+		if (*fmt == '0')
+			zfill = '0';
+		width = gnum(&fmt, argp);
+		ndigit = ndfnd = 0;
+		if (*fmt == '.') {
+			fmt++;
+			ndigit = gnum(&fmt, argp);
+			ndfnd++;
+		}
+		p = s = buf;
+		switch (c = *fmt++) {
+		case 'l':
+		case 'L':
+			switch (c = *fmt++) {
+			case 'd': c = 'D'; break;
+			case 'o': c = 'O'; break;
+			case 'x': c = 'X'; break;
+			case 'u': c = 'U'; break;
+			default: fmt--; c = 'u';
+			}
+		}
+		base = 10;
+		switch (c) {
+		case '\0':
+			return;
+		case 'd':
+		case 'D':
+			u = c=='d'? va_arg(*argp, int): va_arg(*argp, long);
+			if ((long)u < 0) {
+				*p++ = '-';
+				u = -u;
+			}
+			goto num;
+		case 'o':
+		case 'O':
+			base = 8;
+			goto unum;
+		case 'x':
+		case 'X':
+			base = 16;
+			/* fallthrough */
+		case 'u':
+		case 'U':
+		unum:
+			u = c>='a'? va_arg(*argp, unsigned): va_arg(*argp, unsigned long);
+		num:
+			if (ndigit && u)
+				*p++ = '0';
+			s = &buf[sizeof buf];
+			do
+				*--s = "0123456789abcdef"[u%base];
+			while (u /= base);
+			while (s < &buf[sizeof buf])
+				*p++ = *s++;
+			s = buf;
+			break;
+		case 'e':
+		case 'f':
+		case 'g':
+			if (!ndfnd)
+				ndigit = 6;
+			if (ndigit > 70)
+				ndigit = 70;
+			if (c == 'g') {
+				gcvt(va_arg(*argp, double), ndigit, buf);
+				while (*p)
+					p++;
+				break;
+			}
+			s = (c=='e'? ecvt: fcvt)(va_arg(*argp, double), ndigit+(c=='e'), &decpt, &sign);
+			if (sign)
+				*p++ = '-';
+			if (c == 'e') {
+				if (*s == '0')
+					decpt++;
+				*p++ = *s++;
+				*p++ = '.';
+				for (c = ndigit; c > 0; c--)
+					*p++ = *s++;
+				*p++ = 'e';
+				if (--decpt < 0) {
+					*p++ = '-';
+					decpt = -decpt;
+				} else
+					*p++ = '+';
+				if (decpt >= 100) {
+					*p++ = decpt/100 + '0';
+					decpt %= 100;
+				}
+				*p++ = decpt/10 + '0';
+				*p++ = decpt%10 + '0';
+			} else {
+				if (decpt <= 0)
+					*p++ = '0';
+				for (c = decpt; c > 0; c--)
+					*p++ = *s? *s++: '0';
+				if (ndigit)
+					*p++ = '.';
+				for (c = ndigit; c > 0; c--)
+					*p++ = decpt++ < 0 || !*s? '0': *s++;
+			}
+			s = buf;
+			break;
+		case 'c':
+			zfill = ' ';
+			if ((*p = va_arg(*argp, int)) != 0)
+				p++;
+			break;
+		case 's':
+			zfill = ' ';
+			if ((s = p = va_arg(*argp, char *)) == 0)
+				s = p = "(null)";
+			while (*p && (!ndfnd || ndigit-- > 0))
+				p++;
+			break;
+		default:
+			*p++ = c;
+		}
+		c = width - (p - s);
+		if (c < 0)
+			c = 0;
+		_strout(s, p - s, rjust? c: -c, iop, zfill);
+	}
+}

% usr/src/libc/stdio/doscan.c
@@ -2,0 +3 @@
+#include	<stdarg.h>
@@ -13 +14,4 @@
-char	*_getccl();
+int	_doscan(FILE *iop, char *fmt, va_list *argp);
+char	*_getccl(char *s);
+int	_innum(char *ptr, int type, int len, int size, FILE *iop, int *eofptr);
+int	_instr(char *ptr, int type, int len, FILE *iop, int *eofptr);
@@ -15 +19 @@
-char	_sctab[128] = {
+char	_sctab[256] = {
@@ -26,4 +30,2 @@
-_doscan(iop, fmt, argp)
-FILE *iop;
-register char *fmt;
-register int **argp;
+int
+_doscan(FILE *iop, register char *fmt, va_list *argp)
@@ -33 +35,2 @@
-	int **ptr, fileended, size;
+	char *ptr;
+	int fileended, size;
@@ -45 +48 @@
-			ptr = argp++;
+			ptr = fmt;
@@ -69,0 +73,13 @@
+		if (ptr) {
+			if (ch=='c' || ch=='s' || ch=='[')
+				ptr = va_arg(*argp, char *);
+			else if (ch=='e' || ch=='f')
+				ptr = size==LONG? (char *)va_arg(*argp, double *):
+				    (char *)va_arg(*argp, float *);
+			else if (size==LONG)
+				ptr = (char *)va_arg(*argp, long *);
+			else if (size==SHORT)
+				ptr = (char *)va_arg(*argp, short *);
+			else
+				ptr = (char *)va_arg(*argp, int *);
+		}
@@ -97,3 +113,2 @@
-_innum(ptr, type, len, size, iop, eofptr)
-int **ptr, *eofptr;
-struct _iobuf *iop;
+int
+_innum(char *ptr, int type, int len, int size, struct _iobuf *iop, int *eofptr)
@@ -101 +115,0 @@
-	extern double atof();
@@ -104 +118 @@
-	register c, base;
+	register int c, base;
@@ -109 +123,3 @@
-		return(_instr(ptr? *(char **)ptr: (char *)NULL, type, len, iop, eofptr));
+		return(_instr(ptr, type, len, iop, eofptr));
+	if (len > 62)
+		len = 62;
@@ -135 +151 @@
-		 || base==16 && ('a'<=c && c<='f' || 'A'<=c && c<='F')) {
+		 || (base==16 && (('a'<=c && c<='f') || ('A'<=c && c<='F')))) {
@@ -183 +199 @@
-		**(float **)ptr = atof(numbuf);
+		*(float *)ptr = atof(numbuf);
@@ -187 +203 @@
-		**(double **)ptr = atof(numbuf);
+		*(double *)ptr = atof(numbuf);
@@ -191 +207 @@
-		**(short **)ptr = lcval;
+		*(short *)ptr = lcval;
@@ -195 +211 @@
-		**(int **)ptr = lcval;
+		*(int *)ptr = lcval;
@@ -199 +215 @@
-		**(long **)ptr = lcval;
+		*(long *)ptr = lcval;
@@ -205,4 +221,3 @@
-_instr(ptr, type, len, iop, eofptr)
-register char *ptr;
-register struct _iobuf *iop;
-int *eofptr;
+int
+_instr(register char *ptr, int type, int len, register struct _iobuf *iop,
+    int *eofptr)
@@ -210 +225 @@
-	register ch;
+	register int ch;
@@ -221 +236 @@
-	while (_sctab[ch = getc(iop)] & ignstp)
+	while (_sctab[(ch = getc(iop))&0377] & ignstp)
@@ -251,2 +266 @@
-_getccl(s)
-register char *s;
+_getccl(register char *s)
@@ -254 +268 @@
-	register c, t;
+	register int c, t;
@@ -261 +275 @@
-	for (c = 0; c < 128; c++)
+	for (c = 0; c < 256; c++)
@@ -266,5 +280 @@
-	while (((c = *s++)&0177) != ']') {
-		if (t)
-			_sctab[c++] |= STP;
-		else
-			_sctab[c++] &= ~STP;
+	while ((c = *s++&0377) != ']') {
@@ -272,0 +283,4 @@
+		if (t)
+			_sctab[c] |= STP;
+		else
+			_sctab[c] &= ~STP;

% usr/src/libc/stdio/endopen.c
@@ -2,0 +3 @@
+static int create(char *file, int rw);
@@ -5,3 +6 @@
-_endopen(file, mode, iop)
-	char *file, *mode;
-	register FILE *iop;
+_endopen(char *file, char *mode, register FILE *iop)
@@ -56,3 +55 @@
-create(file, rw)
-	register char *file;
-	int rw;
+create(register char *file, int rw)

% usr/src/libc/stdio/fdopen.c
@@ -11,2 +11 @@
-fdopen(fd, mode)
-	register char *mode;
+fdopen(int fd, register char *mode)
@@ -15 +13,0 @@
-	FILE *_findiop();
@@ -30 +28 @@
-		/* No break */
+		/* fallthrough */

% usr/src/libc/stdio/fgetc.c
@@ -3,2 +3,2 @@
-fgetc(fp)
-FILE *fp;
+int
+fgetc(FILE *fp)

% usr/src/libc/stdio/fgets.c
@@ -4,3 +4 @@
-fgets(s, n, iop)
-char *s;
-register FILE *iop;
+fgets(char *s, int n, register FILE *iop)
@@ -8 +6 @@
-	register c;
+	register int c = 0;

% usr/src/libc/stdio/filbuf.c
@@ -3 +2,0 @@
-char	*malloc();
@@ -7,2 +6 @@
-_filbuf(iop)
-	register FILE *iop;
+_filbuf(register FILE *iop)
@@ -21 +19 @@
-			iop->_base = &smallbuf[fileno(iop)];
+			iop->_base = &smallbuf[fileno(iop)&0377];

% usr/src/libc/stdio/findiop.c
@@ -4 +4 @@
-_findiop()
+_findiop(void)

% usr/src/libc/stdio/flsbuf.c
@@ -3 +2,0 @@
-char	*malloc();
@@ -6,3 +5 @@
-_flsbuf(c, iop)
-	int c;
-	register FILE *iop;
+_flsbuf(int c, register FILE *iop)
@@ -11 +8 @@
-	register n, rn;
+	register int n, rn;
@@ -59,2 +56 @@
-fflush(iop)
-	register FILE *iop;
+fflush(register FILE *iop)
@@ -63 +59 @@
-	register n;
+	register int n;
@@ -81 +77,2 @@
-_cleanup()
+void
+_cleanup(void)
@@ -91,2 +88 @@
-fclose(iop)
-	register FILE *iop;
+fclose(register FILE *iop)
@@ -94 +90 @@
-	register r;
+	register int r;
@@ -108 +104 @@
-		~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG|_IORW);
+		(char)~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG|_IORW);

% usr/src/libc/stdio/fopen.c
@@ -4,2 +4 @@
-fopen(file, mode)
-	char *file, *mode;
+fopen(char *file, char *mode)
@@ -7,2 +5,0 @@
-	FILE *_findiop(), *_endopen();
-

% usr/src/libc/stdio/fprintf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+void	_doprnt(char *fmt, va_list *argp, FILE *iop);
@@ -3,3 +5,2 @@
-fprintf(iop, fmt, args)
-FILE *iop;
-char *fmt;
+int
+fprintf(FILE *iop, char *fmt, ...)
@@ -6,0 +8,2 @@
+	va_list args;
+	va_start(args, fmt);
@@ -7,0 +11 @@
+	va_end(args);

% usr/src/libc/stdio/fputc.c
@@ -3,2 +3,2 @@
-fputc(c, fp)
-FILE *fp;
+int
+fputc(int c, FILE *fp)

% usr/src/libc/stdio/fputs.c
@@ -3,3 +3,2 @@
-fputs(s, iop)
-register char *s;
-register FILE *iop;
+int
+fputs(register char *s, register FILE *iop)
@@ -7,2 +6,2 @@
-	register r;
-	register c;
+	register int r = 0;
+	register int c;
@@ -10 +9 @@
-	while (c = *s++)
+	while ((c = *s++))

% usr/src/libc/stdio/freopen.c
@@ -4,3 +4 @@
-freopen(file, mode, iop)
-	char *file, *mode;
-	register FILE *iop;
+freopen(char *file, char *mode, register FILE *iop)
@@ -8,2 +5,0 @@
-	FILE *_endopen();
-

% usr/src/libc/stdio/fseek.c
@@ -7 +6,0 @@
-long lseek();
@@ -9,3 +8,2 @@
-fseek(iop, offset, ptrname)
-	register FILE *iop;
-	long offset;
+int
+fseek(register FILE *iop, long offset, int ptrname)
@@ -14 +12 @@
-	long p;
+	long p = -1;

% usr/src/libc/stdio/ftell.c
@@ -7 +6,0 @@
-long	lseek();
@@ -10,2 +9 @@
-long ftell(iop)
-FILE *iop;
+long ftell(FILE *iop)
@@ -14 +12 @@
-	register adjust;
+	register int adjust;

% usr/src/libc/stdio/gcvt.c
@@ -6 +6 @@
-char	*ecvt();
+#include <stdio.h>
@@ -9,3 +9 @@
-gcvt(number, ndigit, buf)
-double number;
-char *buf;
+gcvt(double number, int ndigit, char *buf)
@@ -15 +13 @@
-	register i;
+	register int i;
@@ -23,2 +21,2 @@
-	if (decpt >= 0 && decpt-ndigit > 4
-	 || decpt < 0 && decpt < -3) { /* use E-style */
+	if ((decpt >= 0 && decpt-ndigit > 4)
+	 || (decpt < 0 && decpt < -3)) { /* use E-style */
@@ -35,0 +34,4 @@
+		if (decpt >= 100) {
+			*p2++ = decpt/100 + '0';
+			decpt %= 100;
+		}

% usr/src/libc/stdio/getchar.c
@@ -6,0 +7 @@
+int	getchar(void);
@@ -8 +9,2 @@
-getchar()
+int
+getchar(void)

% usr/src/libc/stdio/getgrent.c
@@ -15 +15,2 @@
-setgrent()
+void
+setgrent(void)
@@ -23 +24,2 @@
-endgrent()
+void
+endgrent(void)
@@ -32,3 +34 @@
-grskip(p,c)
-register char *p;
-register c;
+grskip(register char *p, register int c)
@@ -42 +42 @@
-getgrent()
+getgrent(void)

% usr/src/libc/stdio/getgrgid.c
@@ -4,2 +4 @@
-getgrgid(gid)
-register gid;
+getgrgid(register int gid)
@@ -8 +6,0 @@
-	struct group *getgrent();

% usr/src/libc/stdio/getgrnam.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -4,2 +5 @@
-getgrnam(name)
-register char *name;
+getgrnam(register char *name)
@@ -8 +7,0 @@
-	struct group *getgrent();

% usr/src/libc/stdio/getpass.c
@@ -6,2 +6 @@
-getpass(prompt)
-char *prompt;
+getpass(char *prompt)
@@ -12 +11 @@
-	register c;
+	register int c;
@@ -15,2 +14 @@
-	int (*signal())();
-	int (*sig)();
+	void (*sig)(int sig);

% usr/src/libc/stdio/getpwent.c
@@ -10 +10,2 @@
-setpwent()
+void
+setpwent(void)
@@ -18 +19,2 @@
-endpwent()
+void
+endpwent(void)
@@ -27,2 +29 @@
-pwskip(p)
-register char *p;
+pwskip(register char *p)
@@ -37 +38 @@
-getpwent()
+getpwent(void)

% usr/src/libc/stdio/getpwnam.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -4,2 +5 @@
-getpwnam(name)
-char *name;
+getpwnam(char *name)
@@ -8 +7,0 @@
-	struct passwd *getpwent();

% usr/src/libc/stdio/getpw.c
@@ -3,3 +3,2 @@
-getpw(uid, buf)
-int uid;
-char buf[];
+int
+getpw(int uid, char buf[])
@@ -8 +7 @@
-	register n, c;
+	register int n, c;

% usr/src/libc/stdio/getpwuid.c
@@ -4,2 +4 @@
-getpwuid(uid)
-register uid;
+getpwuid(register int uid)
@@ -8 +6,0 @@
-	struct passwd *getpwent();

% usr/src/libc/stdio/gets.c
@@ -4,2 +4 @@
-gets(s)
-char *s;
+gets(char *s)
@@ -7 +6 @@
-	register c;
+	register int c;

% usr/src/libc/stdio/getw.c
@@ -3,2 +3,2 @@
-getw(iop)
-register struct _iobuf *iop;
+int
+getw(register struct _iobuf *iop)
@@ -6 +6 @@
-	register i;
+	register unsigned i;
@@ -11 +11,3 @@
-	return(i | (getc(iop)<<8));
+	i |= getc(iop)<<8;
+	i |= getc(iop)<<16;
+	return(i | (unsigned)getc(iop)<<24);

% usr/src/libc/stdio/popen.c
@@ -9,3 +9 @@
-popen(cmd,mode)
-char	*cmd;
-char	*mode;
+popen(char *cmd, char *mode)
@@ -14 +12 @@
-	register myside, hisside, pid;
+	register int myside, hisside, pid;
@@ -35,2 +33,2 @@
-pclose(ptr)
-FILE *ptr;
+int
+pclose(FILE *ptr)
@@ -38 +36,2 @@
-	register f, r, (*hstat)(), (*istat)(), (*qstat)();
+	register int f, r;
+	register void (*hstat)(int sig), (*istat)(int sig), (*qstat)(int sig);

% usr/src/libc/stdio/printf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+void	_doprnt(char *fmt, va_list *argp, FILE *iop);
@@ -3,2 +5,2 @@
-printf(fmt, args)
-char *fmt;
+int
+printf(char *fmt, ...)
@@ -5,0 +8,2 @@
+	va_list args;
+	va_start(args, fmt);
@@ -6,0 +11 @@
+	va_end(args);

% usr/src/libc/stdio/putchar.c
@@ -6,0 +7 @@
+void	putchar(int c);
@@ -8,2 +9,2 @@
-putchar(c)
-register c;
+void
+putchar(register int c)

% usr/src/libc/stdio/puts.c
@@ -3,2 +3,2 @@
-puts(s)
-register char *s;
+int
+puts(register char *s)
@@ -6 +6 @@
-	register c;
+	register int c;
@@ -8 +8 @@
-	while (c = *s++)
+	while ((c = *s++))

% usr/src/libc/stdio/putw.c
@@ -3,3 +3,2 @@
-putw(i, iop)
-register i;
-register struct _iobuf *iop;
+void
+putw(register int i, register struct _iobuf *iop)
@@ -8,0 +8,2 @@
+	putc(i>>16, iop);
+	putc(i>>24, iop);

% usr/src/libc/stdio/rdwr.c
@@ -3,4 +3,2 @@
-fread(ptr, size, count, iop)
-unsigned size, count;
-register char *ptr;
-register FILE *iop;
+int
+fread(register char *ptr, unsigned size, unsigned count, register FILE *iop)
@@ -8 +6 @@
-	register c;
+	register int c;
@@ -25,4 +23,2 @@
-fwrite(ptr, size, count, iop)
-unsigned size, count;
-register char *ptr;
-register FILE *iop;
+int
+fwrite(register char *ptr, unsigned size, unsigned count, register FILE *iop)

% usr/src/libc/stdio/rew.c
@@ -3,2 +3,2 @@
-rewind(iop)
-	register struct _iobuf *iop;
+void
+rewind(register struct _iobuf *iop)

% usr/src/libc/stdio/scanf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+int	_doscan(FILE *iop, char *fmt, va_list *argp);
@@ -3,2 +5,2 @@
-scanf(fmt, args)
-char *fmt;
+int
+scanf(char *fmt, ...)
@@ -6 +8,6 @@
-	return(_doscan(stdin, fmt, &args));
+	va_list args;
+	int r;
+	va_start(args, fmt);
+	r = _doscan(stdin, fmt, &args);
+	va_end(args);
+	return(r);
@@ -9,3 +16,2 @@
-fscanf(iop, fmt, args)
-FILE *iop;
-char *fmt;
+int
+fscanf(FILE *iop, char *fmt, ...)
@@ -13 +19,6 @@
-	return(_doscan(iop, fmt, &args));
+	va_list args;
+	int r;
+	va_start(args, fmt);
+	r = _doscan(iop, fmt, &args);
+	va_end(args);
+	return(r);
@@ -16,3 +27,2 @@
-sscanf(str, fmt, args)
-register char *str;
-char *fmt;
+int
+sscanf(register char *str, char *fmt, ...)
@@ -19,0 +30,2 @@
+	va_list args;
+	int r;
@@ -27 +39,4 @@
-	return(_doscan(&_strbuf, fmt, &args));
+	va_start(args, fmt);
+	r = _doscan(&_strbuf, fmt, &args);
+	va_end(args);
+	return(r);

% usr/src/libc/stdio/setbuf.c
@@ -3,3 +3,2 @@
-setbuf(iop, buf)
-register struct _iobuf *iop;
-char *buf;
+void
+setbuf(register struct _iobuf *iop, char *buf)

% usr/src/libc/stdio/sprintf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+void	_doprnt(char *fmt, va_list *argp, FILE *iop);
@@ -3,2 +5 @@
-char *sprintf(str, fmt, args)
-char *str, *fmt;
+char *sprintf(char *str, char *fmt, ...)
@@ -5,0 +7 @@
+	va_list args;
@@ -10,0 +13 @@
+	va_start(args, fmt);
@@ -11,0 +15 @@
+	va_end(args);

% usr/src/libc/stdio/strout.c
@@ -3,5 +3,3 @@
-_strout(string, count, adjust, file, fillch)
-register char *string;
-register count;
-int adjust;
-register struct _iobuf *file;
+void
+_strout(register char *string, register int count, int adjust,
+    register struct _iobuf *file, int fillch)

% usr/src/libc/stdio/system.c
@@ -0,0 +1 @@
+#include	<stdio.h>
@@ -3,2 +4,2 @@
-system(s)
-char *s;
+int
+system(char *s)
@@ -7 +8 @@
-	register int (*istat)(), (*qstat)();
+	register void (*istat)(int sig), (*qstat)(int sig);

% usr/src/libc/stdio/ungetc.c
@@ -3,2 +3,2 @@
-ungetc(c, iop)
-register FILE *iop;
+int
+ungetc(int c, register FILE *iop)
@@ -8 +8 @@
-	if ((iop->_flag&_IOREAD)==0 || iop->_ptr <= iop->_base)
+	if ((iop->_flag&_IOREAD)==0 || iop->_ptr <= iop->_base) {
@@ -10 +10 @@
-			*iop->_ptr++;
+			iop->_ptr++;
@@ -12,0 +13 @@
+	}

% usr/src/libc/sys/access.s
@@ -1,26 +1,4 @@
-/ access(file, request)
-/  test ability to access file in all indicated ways
-/  1 - read
-/  2 - write
-/  4 - execute
-
-.globl	_access
-.globl	csv, cret
-.comm	_errno,2
-
-.access = 33.
-
-_access:
-	jsr	r5,csv
-	mov	4(r5),0f+2
-	mov	6(r5),0f+4
-	clr	r0
-	sys	0; 0f
-.data
-0:	sys	.access; ..; ..
-.text
-	bec	1f
-	mov	r0,_errno
-	mov	$-1,r0
-1:
-	jmp	cret
+.globl	access
+access:
+	mov	ip, #33
+	b	cerror

% usr/src/libc/sys/acct.s
@@ -1,5 +1 @@
-/ C library -- acct
-
-/ error = acct(string);
-
-.globl	_acct
+.globl	acct
@@ -7,16 +3,3 @@
-.acct = 51.
-
-_acct:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.acct; 0:..
+acct:
+	mov	ip, #51
+	b	cerror

% usr/src/libc/sys/alarm.s
@@ -1,12 +1,4 @@
-/ C library - alarm
-
-.globl	_alarm
-.alarm = 27.
-
-_alarm:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.alarm
-	mov	(sp)+,r5
-	rts	pc
+.globl	alarm
+alarm:
+	mov	ip, #27
+	b	cerror

% usr/src/libc/sys/sbrk.s
@@ -1,40 +1,20 @@
-/old = sbrk(increment);
-/
-/sbrk gets increment more core, and returns a pointer
-/	to the beginning of the new core area
-/
-.globl	_sbrk, _brk
-.globl	_end, cerror
-.break = 17.
-
-_sbrk:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	beq	1f
-	add	nd,0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	nd,r0
-	add	4(r5),nd
-	mov	(sp)+,r5
-	rts	pc
-
-/ brk(value)
-/ as described in man2.
-/ returns 0 for ok, -1 for error.
-
-_brk:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	4(r5),nd
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
+.globl	sbrk, brk
+sbrk:
+	ldr	r2, =nd
+	ldr	r1, [r2]
+	add	r1, r1, #7
+	bic	r1, r1, #7
+	push	{r1, lr}
+	add	r0, r1, r0
+	bl	brk
+	pop	{r1, lr}
+	movcc	r0, r1
+	bx	lr
+brk:
+	push	{r0, lr}
+	mov	ip, #17
+	bl	cerror
+	pop	{r1, lr}
+	ldrcc	r2, =nd
+	strcc	r1, [r2]
+	bx	lr
@@ -43,3 +23 @@
-9:
-	sys	.break; 0:..
-nd:	_end
+nd:	.word	end

% usr/src/libc/sys/chdir.s
@@ -1,5 +1 @@
-/ C library -- chdir
-
-/ error = chdir(string);
-
-.globl	_chdir
+.globl	chdir
@@ -7,16 +3,3 @@
-.chdir = 12.
-
-_chdir:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.chdir; 0:..
+chdir:
+	mov	ip, #12
+	b	cerror

% usr/src/libc/sys/chmod.s
@@ -1,5 +1 @@
-/ C library -- chmod
-
-/ error = chmod(string, mode);
-
-.globl	_chmod
+.globl	chmod
@@ -7,17 +3,3 @@
-.chmod = 15.
-
-_chmod:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.chmod; 0:..; ..
+chmod:
+	mov	ip, #15
+	b	cerror

% usr/src/libc/sys/chown.s
@@ -1,5 +1 @@
-/ C library -- chown
-
-/ error = chown(string, owner);
-
-.globl	_chown,
+.globl	chown
@@ -7,18 +3,3 @@
-.chown = 16.
-
-_chown:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	mov	8(r5),0f+4
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.chown; 0:..; ..; ..
+chown:
+	mov	ip, #16
+	b	cerror

% usr/src/libc/sys/chroot.s
@@ -1,5 +1 @@
-/ C library -- chroot
-
-/ error = chroot(string);
-
-.globl	_chroot
+.globl	chroot
@@ -7,16 +3,3 @@
-.chroot = 61.
-
-_chroot:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.chroot; 0:..
+chroot:
+	mov	ip, #61
+	b	cerror

% usr/src/libc/sys/close.s
@@ -1,5 +1 @@
-/ C library -- close
-
-/ error =  close(file);
-
-.globl	_close,
+.globl	close
@@ -7,13 +3,3 @@
-.close = 6.
-
-_close:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.close
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
+close:
+	mov	ip, #6
+	b	cerror

% usr/src/libc/sys/creat.s
@@ -1,7 +1 @@
-/ C library -- creat
-
-/ file = creat(string, mode);
-/
-/ file == -1 if error
-
-.globl	_creat
+.globl	creat
@@ -9,16 +3,3 @@
-.creat = 8.
-
-_creat:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.creat; 0:..; ..
+creat:
+	mov	ip, #8
+	b	cerror

% usr/src/libc/sys/dup.s
@@ -1,6 +1 @@
-/ C library -- dup
-
-/	f = dup(of [ ,nf])
-/	f == -1 for error
-
-.globl	_dup,_dup2
+.globl	dup, dup2
@@ -8,21 +3,5 @@
-.dup = 41.
-
-_dup2:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	bis	$100,r0
-	br	1f
-
-_dup:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-1:
-	mov	6(r5),r1
-	sys	.dup
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
+dup2:
+	orr	r0, r0, #64
+dup:
+	mov	ip, #41
+	b	cerror

% usr/src/libc/sys/execl.s
@@ -1,23 +1,12 @@
-/ C library -- execl
-
-/ execl(file, arg1, arg2, ... , 0);
-/
-/ environment automatically passed
-
-.globl	_execl
-.globl	cerror, _environ
-.exece	= 59.
-
-_execl:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	r5,r0
-	add	$6,r0
-	mov	r0,0f+2
-	mov	_environ,0f+4
-	sys	0; 9f
-	jmp	cerror
-.data
-9:
-	sys	.exece; 0:..; ..; ..
+.globl	execl
+execl:
+	push	{r1, r2, r3}
+	mov	r1, sp
+	ldr	r2, =environ
+	ldr	r2, [r2]
+	mov	ip, #59
+	push	{lr}
+	bl	cerror
+	pop	{lr}
+	add	sp, sp, #12
+	bx	lr

% usr/src/libc/sys/execv.s
@@ -1,23 +1,6 @@
-/ C library -- execv
-
-/ execv(file, argv);
-/
-/ where argv is a vector argv[0] ... argv[x], 0
-/ last vector element must be 0
-/ environment passed automatically
-
-.globl	_execv,
-.globl	cerror, _environ
-.exece	= 59.
-
-_execv:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	mov	_environ,0f+4
-	sys	0; 9f
-	jmp	cerror
-.data
-9:
-	sys	.exece; 0:..; ..; ..
+.globl	execv
+execv:
+	ldr	r2, =environ
+	ldr	r2, [r2]
+	mov	ip, #59
+	b	cerror

% usr/src/libc/sys/execve.s
@@ -1,8 +1 @@
-/ C library -- execve
-
-/ execve(file, argv, env);
-/
-/ where argv is a vector argv[0] ... argv[x], 0
-/ last vector element must be 0
-
-.globl	_execve
+.globl	execve
@@ -10,13 +3,3 @@
-.exece	= 59.
-
-_execve:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	mov	8(r5),0f+4
-	sys	0; 9f
-	jmp	cerror
-.data
-9:
-	sys	.exece; 0:..; ..; ..
+execve:
+	mov	ip, #59
+	b	cerror

% usr/src/libc/sys/exit.s
@@ -1,15 +1,4 @@
-/ C library -- _exit
-
-/ _exit(code)
-/ code is return in r0 to system
-/ Same as plain exit, for user who want to define their own exit.
-
-.globl	__exit
-.exit = 1.
-
-__exit:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.exit
-
+.globl	_exit
+_exit:
+	mov	ip, #1
+	b	cerror

% usr/src/libc/sys/fork.s
@@ -1,18 +1,12 @@
-/ C library -- fork
-
-/ pid = fork();
-/
-/ pid == 0 in child process; pid == -1 means error return
-/ in child, parents id is in par_uid if needed
-
-.globl	_fork, _par_uid
-.globl	cerror
-.fork = 2.
-
-_fork:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.fork
-		br 1f
-	bec	2f
-	jmp	cerror
+.globl	fork, par_uid
+fork:
+	push	{r7}
+	mov	r7, #2
+	svc	#0
+	b	1f
+	pop	{r7}
+	bxcc	lr
+	ldr	r2, =errno
+	str	r0, [r2]
+	mvn	r0, #0
+	bx	lr
@@ -20,7 +14,6 @@
-	mov	r0,_par_uid
-	clr	r0
-2:
-	mov	(sp)+,r5
-	rts	pc
-.bss
-_par_uid: .=.+2
+	pop	{r7}
+	ldr	r1, =par_uid
+	str	r0, [r1]
+	mov	r0, #0
+	bx	lr
+.comm	par_uid, 4

% usr/src/libc/sys/fstat.s
@@ -1,9 +1 @@
-/ C library -- fstat
-
-/ error = fstat(file, statbuf);
-
-/ int statbuf[17] or
-/ char statbuf[34]
-/ as appropriate
-
-.globl	_fstat
+.globl	fstat
@@ -11,17 +3,3 @@
-.fstat = 28.
-
-_fstat:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	mov	6(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.fstat; 0:..
+fstat:
+	mov	ip, #28
+	b	cerror

% usr/src/libc/sys/getgid.s
@@ -1,26 +1,9 @@
-/ C library -- getgid, getegid
-
-/ gid = getgid();
-
-.globl	_getgid
-.getgid = 47.
-
-_getgid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getgid
-	mov	(sp)+,r5
-	rts	pc
-
-/ gid = getegid();
-/ returns effective gid
-
-.globl	_getegid
-
-_getegid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getgid
-	mov	r1,r0
-	mov	(sp)+,r5
-	rts	pc
+.globl	getgid, getegid
+getgid:
+	mov	ip, #47
+	b	cerror
+getegid:
+	push	{lr}
+	bl	getgid
+	mov	r0, r1
+	pop	{pc}

% usr/src/libc/sys/getpid.s
@@ -1,11 +1,4 @@
-/ getpid -- get process ID
-
-.globl	_getpid
-.getpid	= 20.
-
-_getpid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getpid
-	mov	(sp)+,r5
-	rts	pc
+.globl	getpid
+getpid:
+	mov	ip, #20
+	b	cerror

% usr/src/libc/sys/getuid.s
@@ -1,27 +1,9 @@
-/ C library -- getuid, geteuid
-
-/ uid = getuid();
-
-.globl	_getuid
-.getuid = 24.
-
-_getuid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getuid
-	mov	(sp)+,r5
-	rts	pc
-
-
-/ uid = geteuid();
-/  returns effective uid
-
-.globl	_geteuid
-
-_geteuid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getuid
-	mov	r1,r0
-	mov	(sp)+,r5
-	rts	pc
+.globl	getuid, geteuid
+getuid:
+	mov	ip, #24
+	b	cerror
+geteuid:
+	push	{lr}
+	bl	getuid
+	mov	r0, r1
+	pop	{pc}

% usr/src/libc/sys/ioctl.s
@@ -1,26 +1,4 @@
-/ C library -- ioctl
-
-/ ioctl(fdes, command, arg)
-/ struct * arg;
-/
-/ result == -1 if error
-
-.globl	_ioctl, cerror
-.ioctl	= 54.
-
-_ioctl:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	mov	8(r5),0f+4
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	clr	r0
-	rts	pc
-.data
-9:
-	sys	.ioctl; 0:..; ..; ..
+.globl	ioctl
+ioctl:
+	mov	ip, #54
+	b	cerror

% usr/src/libc/sys/kill.s
@@ -1,21 +1,4 @@
-/ C library -- kill
-
-.globl	_kill, cerror
-.kill = 37.
-
-_kill:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(sp),r0
-	mov	6(sp),8f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-
-.data
-9:
-	sys	.kill; 8:..
+.globl	kill
+kill:
+	mov	ip, #37
+	b	cerror

% usr/src/libc/sys/link.s
@@ -1,5 +1 @@
-/ C library -- link
-
-/ error = link(old-file, new-file);
-
-.globl	_link
+.globl	link
@@ -7,17 +3,3 @@
-.link = 9.
-
-_link:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.link; 0:..; ..
+link:
+	mov	ip, #9
+	b	cerror

% usr/src/libc/sys/lock.s
@@ -1,22 +1,4 @@
-/ lock -- C library
-
-/	lock(f)
-
-.globl	_lock, cerror
-
-.lock = 53.
-
-_lock:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	.data
-9:
-	sys	.lock; 0:..
-	.text
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
+.globl	lock
+lock:
+	mov	ip, #53
+	b	cerror

% usr/src/libc/sys/lseek.s
@@ -1,26 +1,4 @@
-/ C library -- lseek
-
-/ error = lseek(file, offset, ptr);
-/ long offset
-/ long lseek()
-
-.globl	_lseek, cerror
-.lseek	= 19.
-
-_lseek:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	mov	6(r5),0f
-	mov	8(r5),0f+2
-	mov	10.(r5),0f+4
-	sys	0; 9f
-	bec	1f
-	mov	$1,r1
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.lseek; 0:..; ..; ..
+.globl	lseek
+lseek:
+	mov	ip, #19
+	b	cerror

% usr/src/libc/sys/mknod.s
@@ -1,23 +1,4 @@
-/ C library -- mknod
-
-/ error = mknod(string, mode, major.minor);
-
-.globl	_mknod, cerror
-
-.mknod = 14.
-_mknod:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	mov	8(r5),0f+4
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.mknod; 0:..; ..; ..
+.globl	mknod
+mknod:
+	mov	ip, #14
+	b	cerror

% usr/src/libc/sys/mount.s
@@ -1,5 +1 @@
-/ C library -- mount
-
-/ error = mount(dev, file, flag)
-
-.globl	_mount,
+.globl	mount
@@ -7,18 +3,3 @@
-.mount = 21.
-
-_mount:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(sp),0f
-	mov	6(sp),0f+2
-	mov	8(sp),0f+4
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.mount; 0:..; ..; ..
+mount:
+	mov	ip, #21
+	b	cerror

% usr/src/libc/sys/nice.s
@@ -1,5 +1 @@
-/ C library-- nice
-
-/ error = nice(hownice)
-
-.globl	_nice,
+.globl	nice
@@ -7,13 +3,3 @@
-.nice = 34.
-
-_nice:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(sp),r0
-	sys	.nice
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
+nice:
+	mov	ip, #34
+	b	cerror

% usr/src/libc/sys/open.s
@@ -1,6 +1 @@
-/ C library -- open
-
-/ file = open(string, mode)
-/ file == -1 means error
-
-.globl	_open,
+.globl	open
@@ -8,16 +3,3 @@
-.open = 5.
-
-_open:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.open; 0:..; ..
+open:
+	mov	ip, #5
+	b	cerror

% usr/src/libc/sys/pause.s
@@ -1,11 +1,4 @@
-/ C library - pause
-
-.globl	_pause
-.pause = 29.
-
-_pause:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.pause
-	mov	(sp)+,r5
-	rts	pc
+.globl	pause
+pause:
+	mov	ip, #29
+	b	cerror

% usr/src/libc/sys/pipe.s
@@ -1,24 +1,10 @@
-/ pipe -- C library
-
-/	pipe(f)
-/	int f[2];
-
-.globl	_pipe, cerror
-
-.pipe = 42.
-
-_pipe:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.pipe
-	bec	1f
-	jmp	cerror
-1:
-	mov	r2,-(sp)
-	mov	4(r5),r2
-	mov	r0,(r2)+
-	mov	r1,(r2)
-	clr	r0
-	mov	(sp)+,r2
-	mov	(sp)+,r5
-	rts	pc
+.globl	pipe
+pipe:
+	push	{r0, lr}
+	mov	ip, #42
+	bl	cerror
+	pop	{r2, lr}
+	bxcs	lr
+	stmia	r2, {r0, r1}
+	mov	r0, #0
+	bx	lr

% usr/src/libc/sys/profil.s
@@ -1,18 +1,4 @@
-/ profil
-
-.globl	_profil
-.prof = 44.
-
-_profil:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	mov	10(r5),0f+4
-	mov	12(r5),0f+6
-	sys	0; 9f
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.prof; 0:..; ..; ..; ..
+.globl	profil
+profil:
+	mov	ip, #44
+	b	cerror

% usr/src/libc/sys/ptrace.s
@@ -1,28 +1,7 @@
-/ ptrace -- C library
-
-/	result = ptrace(req, pid, addr, data);
-
-.ptrace = 26.
-indir = 0
-
-.globl	_ptrace
-.globl	cerror, _errno
-
-_ptrace:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4.(r5),0f+4
-	mov	6.(r5),0f+0
-	mov	8.(r5),0f+2
-	mov	10.(r5),r0
-	clr	_errno
-	sys	indir; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-
-.data
-9:
-	sys	.ptrace; 0: .=.+6
+.globl	ptrace
+ptrace:
+	mov	ip, r0
+	mov	r0, r3
+	mov	r3, ip
+	mov	ip, #26
+	b	cerror

% usr/src/libc/sys/read.s
@@ -1,6 +1 @@
-/ C library -- read
-
-/ nread = read(file, buffer, count);
-/ nread ==0 means eof; nread == -1 means error
-
-.globl	_read
+.globl	read
@@ -8,17 +3,3 @@
-.read = 3.
-
-_read:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	mov	6(r5),0f
-	mov	8(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.read; 0:..; ..
+read:
+	mov	ip, #3
+	b	cerror

% usr/src/libc/sys/setgid.s
@@ -1,5 +1 @@
-/ C library -- setgid
-
-/ error = setgid(uid);
-
-.globl	_setgid
+.globl	setgid
@@ -7,13 +3,3 @@
-.setgid = 46.
-
-_setgid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.setgid
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
+setgid:
+	mov	ip, #46
+	b	cerror

% usr/src/libc/sys/setuid.s
@@ -1,5 +1 @@
-/ C library -- setuid
-
-/ error = setuid(uid);
-
-.globl	_setuid
+.globl	setuid
@@ -7,13 +3,3 @@
-.setuid = 23.
-
-_setuid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.setuid
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
+setuid:
+	mov	ip, #23
+	b	cerror

% usr/src/libc/sys/signal.s
@@ -1,89 +1,4 @@
-/ C library -- signal
-
-/ signal(n, 0); /* default action on signal(n) */
-/ signal(n, odd); /* ignore signal(n) */
-/ signal(n, label); /* goto label on signal(n) */
-/ returns old label, only one level.
-
-rtt	= 6
-.signal	= 48.
-.globl	_signal, cerror
-
-_signal:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r1
-	cmp	r1,$NSIG
-	bhis	2f
-	mov	6(r5),r0
-	mov	r1,0f
-	asl	r1
-	mov	dvect(r1),-(sp)
-	mov	r0,dvect(r1)
-	mov	r0,0f+2
-	beq	1f
-	bit	$1,r0
-	bne	1f
-	asl	r1
-	add	$tvect,r1
-	mov	r1,0f+2
-1:
-	sys	0; 9f
-	bes	3f
-	bit	$1,r0
-	beq	1f
-	mov	r0,(sp)
-1:
-	mov	(sp)+,r0
-	mov	(sp)+,r5
-	rts	pc
-2:
-	mov	$22.,r0		/ EINVAL
-3:
-	jmp	cerror
-
-NSIG = 0
-tvect:
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-	jsr	r0,1f; NSIG=NSIG+1
-
-1:
-	mov	r1,-(sp)
-	mov	r2,-(sp)
-	mov	r3,-(sp)
-	mov	r4,-(sp)
-	sub	$tvect+4,r0
-	asr	r0
-	mov	r0,-(sp)
-	asr	(sp)
-	jsr	pc,*dvect(r0)
-	tst	(sp)+
-	mov	(sp)+,r4
-	mov	(sp)+,r3
-	mov	(sp)+,r2
-	mov	(sp)+,r1
-	mov	(sp)+,r0
-	rtt
-.data
-9:
-	sys	.signal; 0:..; ..
-.bss
-dvect:	.=.+[NSIG*2]
+.globl	signal
+signal:
+	mov	ip, #48
+	b	cerror

% usr/src/libc/sys/stat.s
@@ -1,5 +1 @@
-/ C library -- stat
-
-/ error = stat(string, statbuf);
-
-.globl	_stat
+.globl	stat
@@ -7,17 +3,3 @@
-.stat = 18.
-
-_stat:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.stat; 0:..; ..
+stat:
+	mov	ip, #18
+	b	cerror

% usr/src/libc/sys/stime.s
@@ -1,3 +1 @@
-/ error = stime(&long)
-
-.globl	_stime
+.globl	stime
@@ -5,15 +3,4 @@
-.stime = 25.
-
-_stime:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(sp),r1
-	mov	(r1)+,r0
-	mov	(r1),r1
-	sys	.stime
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
+stime:
+	ldr	r0, [r0]
+	mov	ip, #25
+	b	cerror

% usr/src/libc/sys/sync.s
@@ -1,9 +1,4 @@
-.globl	_sync
-.sync = 36.
-
-_sync:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.sync
-	mov	(sp)+,r5
-	rts	pc
+.globl	sync
+sync:
+	mov	ip, #36
+	b	cerror

% usr/src/libc/sys/time.s
@@ -1,37 +1,12 @@
-/ C library -- time
-
-/ tvec = time(tvec);
-/
-/ tvec[0], tvec[1] contain the time
-
-.globl	_time
-.time = 13.
-
-
-_time:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.time
-	mov	r2,-(sp)
-	mov	4(r5),r2
-	beq	1f
-	mov	r0,(r2)+
-	mov	r1,(r2)+
-1:
-	mov	(sp)+,r2
-	mov	(sp)+,r5
-	rts	pc
-
-.globl	_ftime
-.ftime	= 35.
-
-_ftime:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	.data
-9:	sys	.ftime; 0:..
-	.text
-	mov	(sp)+,r5
-	rts	pc
+.globl	time, ftime
+time:
+	push	{r0, lr}
+	mov	ip, #13
+	bl	cerror
+	pop	{r1, lr}
+	cmp	r1, #0
+	strne	r0, [r1]
+	bx	lr
+ftime:
+	mov	ip, #35
+	b	cerror

% usr/src/libc/sys/times.s
@@ -1,15 +1,4 @@
-/ C library -- times
-
-.globl	_times
-.times	= 43.
-
-_times:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.times; 0:..
+.globl	times
+times:
+	mov	ip, #43
+	b	cerror

% usr/src/libc/sys/umask.s
@@ -1,5 +1 @@
-/ C library -- umask
-
-/ omask = umask(mode);
-
-.globl	_umask
+.globl	umask
@@ -7,15 +3,3 @@
-.umask = 60.
-
-_umask:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.umask; 0:..
+umask:
+	mov	ip, #60
+	b	cerror

% usr/src/libc/sys/umount.s
@@ -1,3 +1 @@
-/ C library -- umount
-
-.globl	_umount
+.globl	umount
@@ -5,19 +3,3 @@
-indir	= 0
-.umount = 22.
-.comm	_errno,2
-
-_umount:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(sp),0f
-	sys	indir; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-
-.data
-9:
-	sys	.umount; 0:..
+umount:
+	mov	ip, #22
+	b	cerror

% usr/src/libc/sys/unlink.s
@@ -1,5 +1 @@
-/ C library -- unlink
-
-/ error = unlink(string);
-
-.globl	_unlink,
+.globl	unlink
@@ -7,16 +3,3 @@
-.unlink = 10.
-
-_unlink:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.unlink; 0:..
+unlink:
+	mov	ip, #10
+	b	cerror

% usr/src/libc/sys/utime.s
@@ -1,5 +1 @@
-/ C library -- utime
-
-/ error = utime(string, timev);
-
-.globl	_utime
+.globl	utime
@@ -7,17 +3,3 @@
-.utime = 30.
-
-_utime:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),0f
-	mov	6(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	clr	r0
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.utime; 0:..; ..
+utime:
+	mov	ip, #30
+	b	cerror

% usr/src/libc/sys/wait.s
@@ -1,26 +1,10 @@
-/ C library -- wait
-
-/ pid = wait(0);
-/   or,
-/ pid = wait(&status);
-/
-/ pid == -1 if error
-/ status indicates fate of process, if given
-
-.globl	_wait
-.globl	cerror
-.wait = 7.
-
-_wait:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.wait
-	bec	1f
-	jmp	cerror
-1:
-	tst	4(r5)
-	beq	1f
-	mov	r1,*4(r5)	/ status return
-1:
-	mov	(sp)+,r5
-	rts	pc
+.globl	wait
+wait:
+	push	{r0, lr}
+	mov	ip, #7
+	bl	cerror
+	pop	{r2, lr}
+	bxcs	lr
+	cmp	r2, #0
+	strne	r1, [r2]
+	bx	lr

% usr/src/libc/sys/write.s
@@ -1,7 +1 @@
-/ C library -- write
-
-/ nwritten = write(file, buffer, count);
-/
-/ nwritten == -1 means error
-
-.globl	_write
+.globl	write
@@ -9,17 +3,3 @@
-.write = 4.
-
-_write:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	mov	6(r5),0f
-	mov	8(r5),0f+2
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	mov	(sp)+,r5
-	rts	pc
-.data
-9:
-	sys	.write; 0:..; ..
+write:
+	mov	ip, #4
+	b	cerror

% usr/src/libc/syscall.s usr/src/libc/v6/syscall.s
@@ -1,27 +1,12 @@
-/ syscall
-
-.globl	_syscall,csv,cret,cerror
-_syscall:
-	jsr	r5,csv
-	mov	r5,r2
-	add	$04,r2
-	mov	$9f,r3
-	mov	(r2)+,r0
-	bic	$!0377,r0
-	bis	$sys,r0
-	mov	r0,(r3)+
-	mov	(r2)+,r0
-	mov	(r2)+,r1
-	mov	(r2)+,(r3)+
-	mov	(r2)+,(r3)+
-	mov	(r2)+,(r3)+
-	mov	(r2)+,(r3)+
-	mov	(r2)+,(r3)+
-	sys	0; 9f
-	bec	1f
-	jmp	cerror
-1:
-	jmp	cret
-
-	.data
-9:	.=.+12.
+.globl	cerror
+cerror:
+	push	{r7}
+	mov	r7, ip
+	svc	#0
+	pop	{r7}
+	bxcc	lr
+	ldr	r2, =errno
+	str	r0, [r2]
+	mvn	r0, #0
+	bx	lr
+.comm	errno, 4

% usr/src/libm/asin.c
@@ -9,3 +9 @@
-int errno;
-double atan();
-double sqrt();
+#include <math.h>
@@ -15 +13 @@
-asin(arg) double arg; {
+asin(double arg) {
@@ -40 +38 @@
-acos(arg) double arg; {
+acos(double arg) {

% usr/src/libm/atan.c
@@ -17 +17 @@
-double static sq2p1	 =2.414213562373095048802e0;
+static double sq2p1	 =2.414213562373095048802e0;
@@ -31,0 +32,2 @@
+#include <math.h>
+static double satan(double arg), xatan(double arg);
@@ -39,2 +41 @@
-atan(arg)
-double arg;
+atan(double arg)
@@ -42 +42,0 @@
-	double satan();
@@ -57,2 +57 @@
-atan2(arg1,arg2)
-double arg1,arg2;
+atan2(double arg1, double arg2)
@@ -60 +58,0 @@
-	double satan();
@@ -82,2 +80 @@
-satan(arg)
-double arg;
+satan(double arg)
@@ -85 +81,0 @@
-	double	xatan();
@@ -101,2 +97 @@
-xatan(arg)
-double arg;
+xatan(double arg)

% usr/src/libm/exp.c
@@ -11 +10,0 @@
-int	errno;
@@ -23,2 +22 @@
-exp(arg)
-double arg;
+exp(double arg)

% usr/src/libm/fabs.c
@@ -0,0 +1 @@
+#include <math.h>
@@ -2,2 +3 @@
-fabs(arg)
-double arg;
+fabs(double arg)

% usr/src/libm/floor.c
@@ -6 +6 @@
-double	modf();
+#include <math.h>
@@ -9,2 +9 @@
-floor(d)
-double d;
+floor(double d)
@@ -26,2 +25 @@
-ceil(d)
-double d;
+ceil(double d)

% usr/src/libm/hypot.c
@@ -6 +6 @@
-double sqrt();
+#include <math.h>
@@ -8,2 +8 @@
-hypot(a,b)
-double a,b;
+hypot(double a, double b)
@@ -32,0 +32 @@
+double	cabs(struct complex arg);
@@ -35,2 +35 @@
-cabs(arg)
-struct complex arg;
+cabs(struct complex arg)
@@ -38 +36,0 @@
-	double hypot();

% usr/src/libm/j0.c
@@ -43 +43 @@
-int	errno;
+static void asympt(double arg);
@@ -129 +129 @@
-j0(arg) double arg;{
+j0(double arg){
@@ -131 +130,0 @@
-	double sin(), cos(), sqrt();
@@ -149 +148 @@
-y0(arg) double arg;{
+y0(double arg){
@@ -151 +149,0 @@
-	double sin(), cos(), sqrt(), log(), j0();
@@ -172,2 +170,2 @@
-static
-asympt(arg) double arg;{
+static void
+asympt(double arg){

% usr/src/libm/j1.c
@@ -43 +43 @@
-int	errno;
+static void asympt(double arg);
@@ -131 +131 @@
-j1(arg) double arg;{
+j1(double arg){
@@ -133 +132,0 @@
-	double sin(), cos(), sqrt();
@@ -154 +153 @@
-y1(arg) double arg;{
+y1(double arg){
@@ -156 +154,0 @@
-	double sin(), cos(), sqrt(), log(), j1();
@@ -178,2 +176,2 @@
-static
-asympt(arg) double arg;{
+static void
+asympt(double arg){

% usr/src/libm/jn.c
@@ -36 +35,0 @@
-int	errno;
@@ -39 +38 @@
-jn(n,x) int n; double x;{
+jn(int n, double x){
@@ -43 +41,0 @@
-	double j0(), j1();
@@ -81 +79 @@
-yn(n,x) int n; double x;{
+yn(int n, double x){
@@ -85 +82,0 @@
-	double y0(), y1();

% usr/src/libm/log.c
@@ -13,2 +12,0 @@
-int	errno;
-double	frexp();
@@ -27,2 +25 @@
-log(arg)
-double arg;
+log(double arg)
@@ -57,2 +54 @@
-log10(arg)
-double arg;
+log10(double arg)

% usr/src/libm/pow.c
@@ -7,2 +7 @@
-int errno;
-double log(), exp();
+#include <math.h>
@@ -11,2 +10 @@
-pow(arg1,arg2)
-double arg1, arg2;
+pow(double arg1, double arg2)

% usr/src/libm/sin.c
@@ -18,0 +19,2 @@
+#include <math.h>
+static double sinus(double arg, int quad);
@@ -20,2 +22 @@
-cos(arg)
-double arg;
+cos(double arg)
@@ -23 +23,0 @@
-	double sinus();
@@ -30,2 +30 @@
-sin(arg)
-double arg;
+sin(double arg)
@@ -33 +31,0 @@
-	double sinus();
@@ -38,3 +36 @@
-sinus(arg, quad)
-double arg;
-int quad;
+sinus(double arg, int quad)
@@ -42 +37,0 @@
-	double modf();

% usr/src/libm/sinh.c
@@ -15 +15 @@
-double	exp();
+#include <math.h>
@@ -26,2 +26 @@
-sinh(arg)
-double arg;
+sinh(double arg)
@@ -30 +29 @@
-	register sign;
+	register int sign;
@@ -57,2 +56 @@
-cosh(arg)
-double arg;
+cosh(double arg)

% usr/src/libm/sqrt.c
@@ -10,2 +10 @@
-int errno;
-double frexp();
+#include <math.h>
@@ -14,2 +13 @@
-sqrt(arg)
-double arg;
+sqrt(double arg)

% usr/src/libm/tan.c
@@ -11 +10,0 @@
-int	errno;
@@ -23,2 +22 @@
-tan(arg)
-double arg;
+tan(double arg)
@@ -26 +23,0 @@
-	double modf();

% usr/src/libm/tanh.c
@@ -9 +9 @@
-double sinh(), cosh();
+#include <math.h>
@@ -12,2 +12 @@
-tanh(arg)
-double arg;
+tanh(double arg)

% usr/sys/conf/low.s usr/sys/conf/l.s
@@ -1,72 +1,117 @@
-/ low core
-
-.data
-ZERO:
-
-br4 = 200
-br5 = 240
-br6 = 300
-br7 = 340
-
-. = ZERO+0
-	br	1f
-	4
-
-/ trap vectors
-	trap; br7+0.		/ bus error
-	trap; br7+1.		/ illegal instruction
-	trap; br7+2.		/ bpt-trace trap
-	trap; br7+3.		/ iot trap
-	trap; br7+4.		/ power fail
-	trap; br7+5.		/ emulator trap
-	start;br7+6.		/ system  (overlaid by 'trap')
-
-. = ZERO+40
-.globl	start, dump
-1:	jmp	start
-	jmp	dump
-
-
-. = ZERO+60
-	klin; br4
-	klou; br4
-
-. = ZERO+100
-	kwlp; br6
-	kwlp; br6
-
-. = ZERO+114
-	trap; br7+7.		/ 11/70 parity
-
-. = ZERO+220
-	rkio; br5
-
-. = ZERO+224
-	htio; br5
-
-. = ZERO+240
-	trap; br7+7.		/ programmed interrupt
-	trap; br7+8.		/ floating point
-	trap; br7+9.		/ segmentation violation
-
-//////////////////////////////////////////////////////
-/		interface code to C
-//////////////////////////////////////////////////////
-
-.text
-.globl	call, trap
-
-.globl	_klrint
-klin:	jsr	r0,call; jmp _klrint
-.globl	_klxint
-klou:	jsr	r0,call; jmp _klxint
-
-.globl	_clock
-kwlp:	jsr	r0,call; jmp _clock
-
-
-.globl	_rkintr
-rkio:	jsr	r0,call; jmp _rkintr
-
-.globl	_htintr
-htio:	jsr	r0,call; jmp _htintr
+.globl _start
+_start:
+	cpsid if
+	mrc p15, 0, r0, c1, c0, 0
+	bic r0, r0, #(1 << 12)
+	bic r0, r0, #(1 << 2)
+	bic r0, r0, #(1 << 11)
+	bic r0, r0, #(1 << 13)
+	bic r0, r0, #1
+	mcr p15, 0, r0, c1, c0, 0
+	isb
+	mov r0, #0
+	mcr p15, 0, r0, c8, c7, 0
+	mcr p15, 0, r0, c7, c5, 0
+	mcr p15, 0, r0, c7, c5, 6
+	dsb
+	isb
+	ldr sp, =stack_top
+	ldr r0, =vectors
+	mcr p15, 0, r0, c12, c0, 0
+	isb
+	ldr r1, =__bss_end
+	ldr r0, =__bss_start
+	mov r2, #0
+1:
+	cmp r0, r1
+	strlo r2, [r0], #4
+	blo 1b
+	bl machine_init
+	ldr sp, =0x4F002000
+	bl main
+	mov r0, #0x10
+	msr spsr_cxsf, r0
+	mov lr, #0
+	movs pc, lr
+
+.balign 32
+vectors:
+	b _start
+	b undef_entry
+	b svc_entry
+	b pabort_entry
+	b dabort_entry
+	b badtrap
+	b irq_entry
+	b badtrap
+
+svc_entry:
+	srsdb sp!, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r14}^
+	mov r0, sp
+	cpsie i
+	bl trap
+	cpsid i
+	b 2f
+
+irq_entry:
+	sub lr, lr, #4
+	srsdb sp!, #0x13
+	cpsid if, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r14}^
+	mov r5, lr
+	mov r0, sp
+	bl irq
+	ldr r0, [sp, #64]
+	and r0, r0, #0x1f
+	cmp r0, #0x10
+	bne 1f
+	ldr r0, =runrun
+	ldrb r0, [r0]
+	cmp r0, #0
+	beq 1f
+	mov r0, #0
+	mov r1, sp
+	bl user_trap_handler
+	cpsid i
+1:
+	mov lr, r5
+	b 2f
+
+badtrap:
+	bl panictrap
+	b badtrap
+
+undef_entry:
+	sub lr, lr, #4
+	srsdb sp!, #0x13
+	cpsid if, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r14}^
+	mov r0, #4
+	b 1f
+pabort_entry:
+	sub lr, lr, #4
+	b 3f
+dabort_entry:
+	sub lr, lr, #8
+3:
+	srsdb sp!, #0x13
+	cpsid if, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r14}^
+	mov r0, #11
+1:
+	mov r1, sp
+	bl user_trap_handler
+2:
+	ldmia sp, {r0-r14}^
+	add sp, sp, #60
+	rfeia sp!
+
+.bss
+.balign 8
+	.space 8192
+stack_top:

% usr/sys/conf/mch.s
@@ -1,29 +1,191 @@
-/ machine language assist
-/ for 11/45 or 11/70 CPUs
-
-
-/ non-UNIX instructions
-mfpi	= 6500^tst
-stst	= 170300^tst
-mtpi	= 6600^tst
-mfpd	= 106500^tst
-mtpd	= 106600^tst
-spl	= 230
-ldfps	= 170100^tst
-stfps	= 170200^tst
-wait	= 1
-rtt	= 6
-reset	= 5
-
-.PROFIL	= 0
-HIPRI	= 340
-HIGH	= 7
-	.if	.PROFIL
-HIGH	= 6
-HIPRI	= 300
-	.endif
-
-/ Mag tape dump
-/ save registers in low core and
-/ write all core onto mag tape.
-/ entry is thru 44 abs
+.globl mmu_on, dmbsy, spl0, spl1, spl5, spl6, spl7, splx
+.globl cntfrq_get, cntvct_get, cntv_cval_set, cntv_ctl_set, save, resume, dcflush
+.globl arm_sync_icache, idle, waitloc, savfp, dfar, dfsr
+.globl l1, user_l2, uarea_l2
+
+mmu_on:
+	push {r4, r5, r6, r7, r8, r9}
+	mrc p15, 0, r1, c1, c0, 1
+	orr r1, r1, #(1 << 6)
+	mcr p15, 0, r1, c1, c0, 1
+	isb
+	mcr p15, 0, r0, c2, c0, 0
+	mov r1, #1
+	mcr p15, 0, r1, c3, c0, 0
+	mov r1, #0
+	mcr p15, 2, r1, c0, c0, 0
+	isb
+	mrc p15, 1, r2, c0, c0, 0
+	and r3, r2, #7
+	add r3, r3, #4
+	movw r4, #0x3ff
+	and r4, r4, r2, lsr #3
+	clz r5, r4
+	movw r6, #0x7fff
+	and r6, r6, r2, lsr #13
+1:	mov r7, r4
+2:	lsl r8, r7, r5
+	lsl r9, r6, r3
+	orr r8, r8, r9
+	mcr p15, 0, r8, c7, c6, 2
+	subs r7, r7, #1
+	bge 2b
+	subs r6, r6, #1
+	bge 1b
+	dsb
+	mrc p15, 0, r1, c1, c0, 0
+	orr r1, r1, #1
+	orr r1, r1, #(1 << 2)
+	orr r1, r1, #(1 << 12)
+	mcr p15, 0, r1, c1, c0, 0
+	isb
+	pop {r4, r5, r6, r7, r8, r9}
+	bx lr
+
+dmbsy:
+	dmb sy
+	bx lr
+
+spl0:
+spl1:
+	mrs r0, cpsr
+	ldr r1, =irq_ready
+	ldr r1, [r1]
+	cmp r1, #0
+	bxeq lr
+	cpsie i
+	bx lr
+
+spl5:
+spl6:
+spl7:
+	mrs r0, cpsr
+	cpsid i
+	bx lr
+
+splx:
+	tst r0, #0x80
+	bne 1f
+	ldr r1, =irq_ready
+	ldr r1, [r1]
+	cmp r1, #0
+	bxeq lr
+	cpsie i
+	bx lr
+1:
+	cpsid i
+	bx lr
+
+cntfrq_get:
+	mrc p15, 0, r0, c14, c0, 0
+	bx lr
+
+cntvct_get:
+	isb
+	mrrc p15, 1, r0, r1, c14
+	bx lr
+
+cntv_cval_set:
+	mcrr p15, 3, r0, r1, c14
+	isb
+	bx lr
+
+cntv_ctl_set:
+	mcr p15, 0, r0, c14, c3, 1
+	isb
+	bx lr
+
+save:
+	stmia r0, {r4-r11}
+	str sp, [r0, #32]
+	str lr, [r0, #36]
+	mov r0, #0
+	bx lr
+
+resume:
+	cpsid i
+	ldr r2, =uarea_l2
+	ldr r3, =corebase
+	ldr r3, [r3]
+	add r3, r3, r0, lsl #6
+	orr r3, r3, #0x12
+	str r3, [r2, #0]
+	add r3, r3, #0x1000
+	str r3, [r2, #4]
+	dsb ish
+	mov r3, #0
+	mcr p15, 0, r3, c8, c7, 0
+	dsb ish
+	isb
+	ldmia r1, {r4-r11}
+	ldr sp, [r1, #32]
+	ldr r2, [r1, #36]
+	bl spl0
+	mov r0, #1
+	bx r2
+
+dcflush:
+	mrc p15, 0, r2, c0, c0, 1
+	lsr r2, r2, #16
+	and r2, r2, #0xf
+	mov r3, #4
+	lsl r2, r3, r2
+	add r1, r0, r1
+	sub r3, r2, #1
+	bic r0, r0, r3
+1:	mcr p15, 0, r0, c7, c14, 1
+	add r0, r0, r2
+	cmp r0, r1
+	blo 1b
+	dsb
+	bx lr
+
+arm_sync_icache:
+	mov r0, #0
+	dsb ish
+	mcr p15, 0, r0, c8, c7, 0
+	dsb ish
+	isb
+	push {r4, r5, r6, r7}
+	mcr p15, 2, r0, c0, c0, 0
+	isb
+	mrc p15, 1, r0, c0, c0, 0
+	and r1, r0, #7
+	add r1, r1, #4
+	movw r2, #0x3ff
+	and r2, r2, r0, lsr #3
+	clz r3, r2
+	movw r4, #0x7fff
+	and r4, r4, r0, lsr #13
+1:	mov r5, r2
+2:	lsl r6, r5, r3
+	lsl r7, r4, r1
+	orr r6, r6, r7
+	mcr p15, 0, r6, c7, c10, 2
+	subs r5, r5, #1
+	bge 2b
+	subs r4, r4, #1
+	bge 1b
+	pop {r4, r5, r6, r7}
+	mov r0, #0
+	dsb ish
+	mcr p15, 0, r0, c7, c5, 0
+	mcr p15, 0, r0, c7, c5, 6
+	dsb ish
+	isb
+	bx lr
+
+idle:
+	cpsie i
+	wfi
+1:	cpsid i
+savfp:
+	bx lr
+
+dfar:
+	mrc p15, 0, r0, c6, c0, 0
+	bx lr
+
+dfsr:
+	mrc p15, 0, r0, c5, c0, 0
+	bx lr
@@ -32,638 +193,0 @@
-.globl	dump
-dump:
-
-/ save regs r0,r1,r2,r3,r4,r5,r6,KIA6
-/ starting at abs location 4
-
-	mov	r0,4
-	mov	$6,r0
-	mov	r1,(r0)+
-	mov	r2,(r0)+
-	mov	r3,(r0)+
-	mov	r4,(r0)+
-	mov	r5,(r0)+
-	mov	sp,(r0)+
-	mov	KDSA6,(r0)+
-
-/ dump all of core (ie to first mt error)
-/ onto mag tape. (9 track or 7 track 'binary')
-
-.if HTDUMP
-	mov	$HTCS1,r0
-	mov	$40,*$HTCS2
-	mov	$2300,*$HTTC
-	clr	*$HTBA
-	mov	$1,(r0)
-1:
-	mov	$-512.,*$HTFC
-	mov	$-256.,*$HTWC
-	movb	$61,(r0)
-2:
-	tstb	(r0)
-	bge	2b
-	bit	$1,(r0)
-	bne	2b
-	bit	$40000,(r0)
-	beq	1b
-	mov	$27,(r0)
-.endif
-HT	= 0172440
-HTCS1	= HT+0
-HTWC	= HT+2
-HTBA	= HT+4
-HTFC	= HT+6
-HTCS2	= HT+10
-HTTC	= HT+32
-
-MTC = 172522
-.if TUDUMP
-	mov	$MTC,r0
-	mov	$60004,(r0)+
-	clr	2(r0)
-1:
-	mov	$-512.,(r0)
-	inc	-(r0)
-2:
-	tstb	(r0)
-	bge	2b
-	tst	(r0)+
-	bge	1b
-	reset
-
-/ end of file and loop
-
-	mov	$60007,-(r0)
-.endif
-	br	.
-
-.text
-.globl	start, _end, _edata, _etext, _main
-
-/ 11/45 and 11/70 startup.
-/ entry is thru 0 abs.
-/ since core is shuffled,
-/ this code can be executed but once
-
-start:
-	bit	$1,SSR0
-	beq	1f
-	mov	$trap,34
-	mov	$trap,0
-	mov	$340+15.,2
-	bit	$20,SSR3
-	beq	9f
-	mov	$70.,_cputype
-	mov	$3,*$MSCR
-9:
-	clr	PS
-	br	9f
-1:
-	inc	$-1
-	bne	.
-	reset
-/ Set loc. 0 to trap to system, in case of
-/ hardware glitch
-	mov	$trap,0		/ in case of bad trap through 0
-	mov	$340+15.,2	/ high pri, trap type 15
-	clr	PS
-
-/ set KI0 to physical 0
-
-	mov	$77406,r3
-	mov	$KISA0,r0
-	mov	$KISD0,r1
-	clr	(r0)+
-	mov	r3,(r1)+
-
-/ set KI1-6 to eventual text resting place
-
-	mov	$_end+63.,r2
-	ash	$-6,r2
-	bic	$!1777,r2
-1:
-	mov	r2,(r0)+
-	mov	r3,(r1)+
-	add	$200,r2
-	cmp	r0,$KISA7
-	blos	1b
-
-/ set KI7 to IO seg for escape
-
-	mov	$IO,-(r0)
-
-/ set KD0-7 to physical
-
-	mov	$KDSA0,r0
-	mov	$KDSD0,r1
-	clr	r2
-1:
-	mov	r2,(r0)+
-	mov	r3,(r1)+
-	add	$200,r2
-	cmp	r0,$KDSA7
-	blos	1b
-
-/ initialization
-/ get a temp (1-word) stack
-/ turn on segmentation
-/ copy text to I space
-/ clear bss in D space
-
-	mov	$stk+2,sp
-	mov	$65,SSR3		/ 22-bit, map, K+U sep
-	bit	$20,SSR3
-	beq	1f
-	mov	$70.,_cputype
-	mov	$3,*$MSCR		/ Disable UNIBUS traps, non-fatal traps
-1:
-	inc	SSR0
-	mov	$_etext+100,r2
-	mov	$_edata+100,r1
-	add	$_etext-8192.,r1
-1:
-	mov	-(r1),-(sp)
-	mtpi	-(r2)
-	cmp	r1,$_edata
-	bhi	1b
-1:
-	clr	(r1)+
-	cmp	r1,$_end
-	blo	1b
-
-/ use KI escape to set KD7 to IO seg
-/ set KD6 to first available core
-/ If profiling, snag supervisor registers.
-
-	mov	$IO,-(sp)
-	mtpi	*$KDSA7
-9:
-	mov	$_etext-8192.+63.,r2
-	ash	$-6,r2
-	bic	$!1777,r2
-	add	KISA1,r2
-	.if	.PROFIL
-	mov	r2,SISA2
-	mov	r2,_proloc
-	mov	$77406,SISD2
-	add	$200,r2
-	mov	r2,SISA2+2
-	mov	$77406,SISD2+2
-	add	$200,r2
-	.endif
-	mov	r2,KDSA6
-
-/ Turn off write permission on kernel text
-/ Take stuff above data out of address space
-
-	mov	$KISD0,r0
-1:
-	mov	$77402,(r0)+
-	cmp	r0,$KISD7
-	blos	1b
-
-	mov	$_end+63.,r0
-	ash	$-6,r0
-	bic	$!1777,r0
-	mov	$KDSD0,r1
-1:
-	cmp	r0,$200
-	bge	2f
-	dec	r0
-	bge	4f
-	clr	(r1)
-	br	3f
-4:
-	movb	r0,1(r1)
-	br	3f
-2:
-	movb	$177,1(r1)
-3:
-	tst	(r1)+
-	sub	$200,r0
-	cmp	r1,$KDSD5
-	blos	1b
-
-/ set up supervisor D registers
-
-9:
-	mov	$6,SISD0
-	mov	$6,SISD1
-
-/ set up real sp
-/ clear user block
-/ test for floating point hardware
-
-	mov	$_u+[usize*64.],sp
-	mov	$1f,nofault
-	setd			/ jump to 1f if this traps
-	inc	fpp
-1:
-	clr	nofault
-	mov	$_u,r0
-1:
-	clr	(r0)+
-	cmp	r0,sp
-	blo	1b
-	.if	.PROFIL
-	mov	$40000,r0
-	mov	$10000,PS	/ prev = super
-1:
-	clr	-(sp)
-	mtpi	(r0)+
-	cmp	r0,$100000
-	blo	1b
-	jsr	pc,_isprof
-	.endif
-
-/ set up previous mode and call main
-/ on return, enter user mode at 0R
-
-	mov	$30000,PS
-	jsr	pc,_main
-	mov	$170000,-(sp)
-	clr	-(sp)
-	rtt
-
-.globl	_rkboot, _rpboot
-_rkboot:
-	jmp	*$173000
-
-_rpboot:
-	jmp	*$173006
-
-
-.globl	trap, call
-.globl	_trap
-
-/ all traps and interrupts are
-/ vectored thru this routine.
-
-trap:
-	mov	PS,saveps
-	tst	nofault
-	bne	1f
-	mov	SSR0,ssr
-	mov	SSR1,ssr+2
-	mov	SSR2,ssr+4
-	mov	$1,SSR0
-	jsr	r0,call1; jmp _trap
-	/ no return
-1:
-	mov	$1,SSR0
-	mov	nofault,(sp)
-	rtt
-.text
-
-.globl	_runrun
-call1:
-	mov	saveps,-(sp)
-	spl	0
-	br	1f
-
-call:
-	mov	PS,-(sp)
-1:
-	mov	r1,-(sp)
-	mfpd	sp
-	mov	4(sp),-(sp)
-	bic	$!37,(sp)
-	bit	$30000,PS
-	beq	1f
-	jsr	pc,(r0)+
-	tstb	_runrun
-	beq	2f
-	mov	$12.,(sp)		/ trap 12 is give up cpu
-	jsr	pc,_trap
-2:
-	tst	(sp)+
-	mtpd	sp
-	br	2f
-1:
-	bis	$30000,PS
-	jsr	pc,(r0)+
-	cmp	(sp)+,(sp)+
-2:
-	mov	(sp)+,r1
-	tst	(sp)+
-	mov	(sp)+,r0
-	rtt
-
-.globl	_savfp
-_savfp:
-	tst	fpp
-	beq	9f		/ No FP hardware
-	mov	2(sp),r1
-	stfps	(r1)+
-	setd
-	movf	fr0,(r1)+
-	movf	fr1,(r1)+
-	movf	fr2,(r1)+
-	movf	fr3,(r1)+
-	movf	fr4,fr0
-	movf	fr0,(r1)+
-	movf	fr5,fr0
-	movf	fr0,(r1)+
-9:
-	rts	pc
-
-.globl	_restfp
-_restfp:
-	tst	fpp
-	beq	9f
-	mov	2(sp),r1
-	mov	r1,r0
-	setd
-	add	$8.+2.,r1
-	movf	(r1)+,fr1
-	movf	(r1)+,fr2
-	movf	(r1)+,fr3
-	movf	(r1)+,fr0
-	movf	fr0,fr4
-	movf	(r1)+,fr0
-	movf	fr0,fr5
-	movf	2(r0),fr0
-	ldfps	(r0)
-9:
-	rts	pc
-
-.globl	_stst
-_stst:
-	tst	fpp
-	beq	9f
-	stst	r0
-	mov	r0,*2(sp)
-9:
-	rts	pc
-
-.globl	_addupc
-_addupc:
-	mov	r2,-(sp)
-	mov	6(sp),r2	/ base of prof with base,leng,off,scale
-	mov	4(sp),r0	/ pc
-	sub	4(r2),r0	/ offset
-	clc
-	ror	r0
-	mov	6(r2),r1
-	clc
-	ror	r1
-	mul	r1,r0		/ scale
-	ashc	$-14.,r0
-	inc	r1
-	bic	$1,r1
-	cmp	r1,2(r2)	/ length
-	bhis	1f
-	add	(r2),r1		/ base
-	mov	nofault,-(sp)
-	mov	$2f,nofault
-	mfpd	(r1)
-	add	12.(sp),(sp)
-	mtpd	(r1)
-	br	3f
-2:
-	clr	6(r2)
-3:
-	mov	(sp)+,nofault
-1:
-	mov	(sp)+,r2
-	rts	pc
-
-.globl	_display
-_display:
-	dec	dispdly
-	bge	2f
-	clr	dispdly
-	mov	PS,-(sp)
-	mov	$HIPRI,PS
-	mov	CSW,r1
-	bit	$1,r1
-	beq	1f
-	bis	$30000,PS
-	dec	r1
-1:
-	jsr	pc,fuword
-	mov	r0,CSW
-	mov	(sp)+,PS
-	cmp	r0,$-1
-	bne	2f
-	mov	$120.,dispdly		/ 2 sec delay after CSW fault
-2:
-	rts	pc
-
-.globl	_backup
-.globl	_regloc
-_backup:
-	mov	2(sp),r0
-	movb	ssr+2,r1
-	jsr	pc,1f
-	movb	ssr+3,r1
-	jsr	pc,1f
-	movb	_regloc+7,r1
-	asl	r1
-	add	r0,r1
-	mov	ssr+4,(r1)
-	clr	r0
-2:
-	rts	pc
-1:
-	mov	r1,-(sp)
-	asr	(sp)
-	asr	(sp)
-	asr	(sp)
-	bic	$!7,r1
-	movb	_regloc(r1),r1
-	asl	r1
-	add	r0,r1
-	sub	(sp)+,(r1)
-	rts	pc
-
-
-.globl	_fubyte, _subyte
-.globl	_fuword, _suword
-.globl	_fuibyte, _suibyte
-.globl	_fuiword, _suiword
-_fuibyte:
-	mov	2(sp),r1
-	bic	$1,r1
-	jsr	pc,giword
-	br	2f
-
-_fubyte:
-	mov	2(sp),r1
-	bic	$1,r1
-	jsr	pc,gword
-
-2:
-	cmp	r1,2(sp)
-	beq	1f
-	swab	r0
-1:
-	bic	$!377,r0
-	rts	pc
-
-_suibyte:
-	mov	2(sp),r1
-	bic	$1,r1
-	jsr	pc,giword
-	mov	r0,-(sp)
-	cmp	r1,4(sp)
-	beq	1f
-	movb	6(sp),1(sp)
-	br	2f
-1:
-	movb	6(sp),(sp)
-2:
-	mov	(sp)+,r0
-	jsr	pc,piword
-	clr	r0
-	rts	pc
-
-_subyte:
-	mov	2(sp),r1
-	bic	$1,r1
-	jsr	pc,gword
-	mov	r0,-(sp)
-	cmp	r1,4(sp)
-	beq	1f
-	movb	6(sp),1(sp)
-	br	2f
-1:
-	movb	6(sp),(sp)
-2:
-	mov	(sp)+,r0
-	jsr	pc,pword
-	clr	r0
-	rts	pc
-
-_fuiword:
-	mov	2(sp),r1
-fuiword:
-	jsr	pc,giword
-	rts	pc
-
-_fuword:
-	mov	2(sp),r1
-fuword:
-	jsr	pc,gword
-	rts	pc
-
-giword:
-	mov	PS,-(sp)
-	spl	HIGH
-	mov	nofault,-(sp)
-	mov	$err,nofault
-	mfpi	(r1)
-	mov	(sp)+,r0
-	br	1f
-
-gword:
-	mov	PS,-(sp)
-	spl	HIGH
-	mov	nofault,-(sp)
-	mov	$err,nofault
-	mfpd	(r1)
-	mov	(sp)+,r0
-	br	1f
-
-_suiword:
-	mov	2(sp),r1
-	mov	4(sp),r0
-suiword:
-	jsr	pc,piword
-	rts	pc
-
-_suword:
-	mov	2(sp),r1
-	mov	4(sp),r0
-suword:
-	jsr	pc,pword
-	rts	pc
-
-piword:
-	mov	PS,-(sp)
-	spl	HIGH
-	mov	nofault,-(sp)
-	mov	$err,nofault
-	mov	r0,-(sp)
-	mtpi	(r1)
-	br	1f
-
-pword:
-	mov	PS,-(sp)
-	spl	HIGH
-	mov	nofault,-(sp)
-	mov	$err,nofault
-	mov	r0,-(sp)
-	mtpd	(r1)
-1:
-	mov	(sp)+,nofault
-	mov	(sp)+,PS
-	rts	pc
-
-err:
-	mov	(sp)+,nofault
-	mov	(sp)+,PS
-	tst	(sp)+
-	mov	$-1,r0
-	rts	pc
-
-.globl	_copyin, _copyout
-.globl	_copyiin, _copyiout
-_copyiin:
-	jsr	pc,copsu
-1:
-	mfpi	(r0)+
-	mov	(sp)+,(r1)+
-	sob	r2,1b
-	br	2f
-
-_copyin:
-	jsr	pc,copsu
-1:
-	mfpd	(r0)+
-	mov	(sp)+,(r1)+
-	sob	r2,1b
-	br	2f
-
-_copyiout:
-	jsr	pc,copsu
-1:
-	mov	(r0)+,-(sp)
-	mtpi	(r1)+
-	sob	r2,1b
-	br	2f
-
-_copyout:
-	jsr	pc,copsu
-1:
-	mov	(r0)+,-(sp)
-	mtpd	(r1)+
-	sob	r2,1b
-2:
-	mov	(sp)+,nofault
-	mov	(sp)+,r2
-	clr	r0
-	rts	pc
-
-copsu:
-	mov	(sp)+,r0
-	mov	r2,-(sp)
-	mov	nofault,-(sp)
-	mov	r0,-(sp)
-	mov	10(sp),r0
-	mov	12(sp),r1
-	mov	14(sp),r2
-	asr	r2
-	mov	$1f,nofault
-	rts	pc
-
-1:
-	mov	(sp)+,nofault
-	mov	(sp)+,r2
-	mov	$-1,r0
-	rts	pc
-
-.globl	_idle, _waitloc
-_idle:
-	mov	PS,-(sp)
-	spl	0
-	wait
@@ -671,386 +195 @@
-	mov	(sp)+,PS
-	rts	pc
-
-	.data
-_waitloc:
-	waitloc
-	.text
-
-.globl	_save
-_save:
-	mov	(sp)+,r1
-	mov	(sp),r0
-	mov	r2,(r0)+
-	mov	r3,(r0)+
-	mov	r4,(r0)+
-	mov	r5,(r0)+
-	mov	sp,(r0)+
-	mov	r1,(r0)+
-	clr	r0
-	jmp	(r1)
-
-	.globl	_resume
-_resume:
-	mov	2(sp),r0		/ new process
-	mov	4(sp),r1		/ new stack
-	spl	7
-	mov	r0,KDSA6		/ In new process
-	mov	(r1)+,r2
-	mov	(r1)+,r3
-	mov	(r1)+,r4
-	mov	(r1)+,r5
-	mov	(r1)+,sp
-	mov	$1,r0
-	spl	0
-	jmp	*(r1)+
-
-.globl	_spl0, _spl1, _spl4, _spl5, _spl6, _spl7, _splx
-_spl0:
-	mov	PS,r0
-	spl	0
-	rts	pc
-
-_spl1:
-	mov	PS,r0
-	spl	1
-	rts	pc
-
-_spl4:
-	mov	PS,r0
-	spl	4
-	rts	pc
-
-_spl5:
-	mov	PS,r0
-	spl	5
-	rts	pc
-
-_spl6:
-	mov	PS,r0
-	spl	6
-	rts	pc
-
-_spl7:
-	mov	PS,r0
-	spl	HIGH
-	rts	pc
-
-_splx:
-	mov	2(sp),PS
-	rts	pc
-
-.globl	_copyseg
-_copyseg:
-	mov	PS,-(sp)
-	mov	4(sp),SISA0
-	mov	6(sp),SISA1
-	mov	$10000+HIPRI,PS
-	mov	r2,-(sp)
-	clr	r0
-	mov	$8192.,r1
-	mov	$32.,r2
-1:
-	mfpd	(r0)+
-	mtpd	(r1)+
-	sob	r2,1b
-	mov	(sp)+,r2
-	mov	(sp)+,PS
-	rts	pc
-
-.globl	_clearseg
-_clearseg:
-	mov	PS,-(sp)
-	mov	4(sp),SISA0
-	mov	$10000+HIPRI,PS
-	clr	r0
-	mov	$32.,r1
-1:
-	clr	-(sp)
-	mtpd	(r0)+
-	sob	r1,1b
-	mov	(sp)+,PS
-	rts	pc
-
-/ Long quotient
-
-	.globl	ldiv
-ldiv:
-	jsr	r5,csv
-	mov	10.(r5),r3
-	sxt	r4
-	bpl	1f
-	neg	r3
-1:
-	cmp	r4,8.(r5)
-	bne	hardldiv
-	mov	6.(r5),r2
-	mov	4.(r5),r1
-	bge	1f
-	neg	r1
-	neg	r2
-	sbc	r1
-	com	r4
-1:
-	mov	r4,-(sp)
-	clr	r0
-	div	r3,r0
-	mov	r0,r4		/high quotient
-	mov	r1,r0
-	mov	r2,r1
-	div	r3,r0
-	bvc	1f
-	sub	r3,r0		/ this is the clever part
-	div	r3,r0
-	tst	r1
-	sxt	r1
-	add	r1,r0		/ cannot overflow!
-1:
-	mov	r0,r1
-	mov	r4,r0
-	tst	(sp)+
-	bpl	9f
-	neg	r0
-	neg	r1
-	sbc	r0
-9:
-	jmp	cret
-
-hardldiv:
-	4
-
-/ Long remainder
-
-	.globl	lrem
-lrem:
-	jsr	r5,csv
-	mov	10.(r5),r3
-	sxt	r4
-	bpl	1f
-	neg	r3
-1:
-	cmp	r4,8.(r5)
-	bne	hardlrem
-	mov	6.(r5),r2
-	mov	4.(r5),r1
-	mov	r1,r4
-	bge	1f
-	neg	r1
-	neg	r2
-	sbc	r1
-1:
-	clr	r0
-	div	r3,r0
-	mov	r1,r0
-	mov	r2,r1
-	div	r3,r0
-	bvc	1f
-	sub	r3,r0
-	div	r3,r0
-	tst	r1
-	beq	9f
-	add	r3,r1
-1:
-	tst	r4
-	bpl	9f
-	neg	r1
-9:
-	sxt	r0
-	jmp	cret
-
-/ The divisor is known to be >= 2^15.  Only 16 cycles are
-/ needed to get a remainder.
-hardlrem:
-	4
-
-/.globl	lmul
-/lmul:
-/	mov	r2,-(sp)
-/	mov	r3,-(sp)
-/	mov	8(sp),r2
-/	sxt	r1
-/	sub	6(sp),r1
-/	mov	12.(sp),r0
-/	sxt	r3
-/	sub	10.(sp),r3
-/	mul	r0,r1
-/	mul	r2,r3
-/	add	r1,r3
-/	mul	r2,r0
-/	sub	r3,r0
-/	mov	(sp)+,r3
-/	mov	(sp)+,r2
-/	rts	pc
-
-.globl	csv
-csv:
-	mov	r5,r0
-	mov	sp,r5
-	mov	r4,-(sp)
-	mov	r3,-(sp)
-	mov	r2,-(sp)
-	jsr	pc,(r0)
-
-.globl	cret
-cret:
-	mov	r5,r2
-	mov	-(r2),r4
-	mov	-(r2),r3
-	mov	-(r2),r2
-	mov	r5,sp
-	mov	(sp)+,r5
-	rts	pc
-
-.globl	_u
-_u	= 140000
-usize	= 16.
-
-CSW	= 177570
-PS	= 177776
-SSR0	= 177572
-SSR1	= 177574
-SSR2	= 177576
-SSR3	= 172516
-KISA0	= 172340
-KISA1	= 172342
-KISA7	= 172356
-KISD0	= 172300
-KISD7	= 172316
-KDSA0	= 172360
-KDSA6	= 172374
-KDSA7	= 172376
-KDSD0	= 172320
-KDSD5	= 172332
-SISA0	= 172240
-SISA1	= 172242
-SISA2	= 172244
-SISD0	= 172200
-SISD1	= 172202
-SISD2	= 172204
-MSCR	= 017777746	/ 11/70 memory control register
-IO	= 177600
-
-SWR	= 177570
-.data
-.globl	_ka6
-.globl	_cputype
-
-_ka6:	KDSA6
-_cputype:45.
-stk:	0
-
-.bss
-nofault:.=.+2
-fpp:	.=.+2
-ssr:	.=.+6
-dispdly:.=.+2
-saveps:	.=.+2
-
-.text
-/ system profiler
-/  Expects to have a KW11-P in addition to the line-frequency
-/  clock, and it should be set to BR7.
-/  Uses supervisor I space register 2&3 (40000-100000)
-/  to maintain the profile.
-
-	.if	.PROFIL
-CCSB	= 172542
-CCSR	= 172540
-
-.globl	_sprof, _xprobuf, _probsiz, _mode
-_probsiz = 37777
-
-_isprof:
-	mov	$1f,nofault
-	mov	$_sprof,104	/ interrupt
-	mov	$340,106	/ pri
-	mov	$100.,CCSB	/ count set = 100
-	mov	$113,CCSR	/ count down, 10kHz, repeat
-1:
-	clr	nofault
-	rts	pc
-
-_sprof:
-	mov	r0,-(sp)
-	mov	PS,r0
-	ash	$-10.,r0
-	bic	$!14,r0
-	add	$1,_mode+2(r0)
-	adc	_mode(r0)
-	cmp	r0,$14		/ user
-	beq	done
-	mov	2(sp),r0	/ pc
-	asr	r0
-	asr	r0
-	bic	$140001,r0
-	cmp	r0,$_probsiz
-	blo	1f
-	inc	_outside
-	br	done
-1:
-	mov	$10340,PS		/ prev = super
-	mfpi	40000(r0)
-	inc	(sp)
-	mtpi	40000(r0)
-	bne	done
-	mov	r1,-(sp)
-	mov	$_xprobuf,r1
-2:
-	cmp	(r1)+,r0
-	bne	3f
-	inc	(r1)
-	br	4f
-3:
-	tst	(r1)+
-	bne	2b
-	sub	$4,r1
-	mov	r0,(r1)+
-	mov	$1,(r1)+
-4:
-	mov	(sp)+,r1
-done:
-	mov	(sp)+,r0
-	mov	$113,CCSR
-	rtt
-
-/ count subroutine calls during profiling
-/  of the system.
-
-.globl	mcount, _profcnts, _profsize
-
-.bss
-_profcnts:
-	.=.+[6*340.]
-
-.globl countbase
-.data
-countbase:
-	_profcnts
-_profsize:
-	340.
-.text
-
-mcount:
-	mov	(r0),r1
-	bne	1f
-	mov	countbase,r1
-	beq	2f
-	add	$6,countbase
-	cmp	countbase,$_profcnts+[6*340.]
-	blo	3f
-	clr	countbase
-	rts	pc
-3:
-	mov	(sp),(r1)+
-	mov	r1,(r0)
-1:
-	inc	2(r1)
-	bne	2f
-	inc	(r1)
-2:
-	rts	pc
-
-.bss
-_xprobuf:.=.+512.
-_proloc:.=.+2
-_mode:	.=.+16.
-_outside: .=.+2
+	.word 1b
@@ -1058 +197,8 @@
-	.endif
+.section .ddrbss,"aw",%nobits
+.balign 16384
+l1:
+	.space 16384
+user_l2:
+	.space 1024
+uarea_l2:
+	.space 1024

% usr/sys/conf/mkconf.c
@@ -1,0 +2,4 @@
+#include <string.h>
+
+void	puke(char **s);
+int	input(void), equal(char *a, char *b), badline(char *line);
@@ -62,0 +67 @@
+	{
@@ -69 +74,2 @@
-	"	klopen, klclose, klread, klwrite, klioctl, nulldev, 0,",
+	"	klopen, klclose, klread, klwrite, klioctl, nulltty, 0,",
+	"",
@@ -71 +77 @@
-	"int	klopen(), klclose(), klread(), klwrite(), klioctl();",
+	},
@@ -72,0 +79 @@
+	{
@@ -79 +86,2 @@
-	"	nulldev, nulldev, mmread, mmwrite, nodev, nulldev, 0, ",
+	"	nulldev, nulldev, mmread, mmwrite, noioctl, nulltty, 0, ",
+	"",
@@ -81 +89 @@
-	"int	mmread(), mmwrite();",
+	},
@@ -82,0 +91 @@
+	{
@@ -91,0 +101 @@
+	},
@@ -92,0 +103 @@
+	{
@@ -101,0 +113 @@
+	},
@@ -102,0 +115 @@
+	{
@@ -111,0 +125 @@
+	},
@@ -120,0 +135 @@
+	{
@@ -129,0 +145 @@
+	},
@@ -137,0 +154 @@
+	{
@@ -146,0 +164 @@
+	},
@@ -147,0 +166 @@
+	{
@@ -156,0 +176 @@
+	},
@@ -157,0 +178 @@
+	{
@@ -166,0 +188 @@
+	},
@@ -171,0 +194 @@
+	{
@@ -180,0 +204 @@
+	},
@@ -181,0 +206 @@
+	{
@@ -188,3 +213,4 @@
-	"	nulldev, nulldev, rkread, rkwrite, nodev, nulldev, 0,",
-	"int	rkstrategy();\nstruct	buf	rktab;",
-	"int	rkread(), rkwrite();",
+	"	nulldev, nulldev, rkread, rkwrite, noioctl, nulltty, 0,",
+	"extern struct	buf	rktab;",
+	"",
+	},
@@ -191,0 +218 @@
+	{
@@ -200,0 +228 @@
+	},
@@ -201,0 +230 @@
+	{
@@ -210,0 +240 @@
+	},
@@ -211,0 +242 @@
+	{
@@ -220,0 +252 @@
+	},
@@ -225,0 +258 @@
+	{
@@ -234,0 +268 @@
+	},
@@ -235,0 +270 @@
+	{
@@ -244,0 +280 @@
+	},
@@ -250,0 +287 @@
+	{
@@ -259,0 +297 @@
+	},
@@ -260,0 +299 @@
+	{
@@ -269,0 +309 @@
+	},
@@ -270,0 +311 @@
+	{
@@ -279,0 +321 @@
+	},
@@ -284,0 +327 @@
+	{
@@ -293,0 +337 @@
+	},
@@ -294,0 +339 @@
+	{
@@ -303,0 +349 @@
+	},
@@ -313,0 +360 @@
+	{
@@ -322,0 +370 @@
+	},
@@ -327,0 +376 @@
+	{
@@ -336,0 +386 @@
+	},
@@ -344,0 +395 @@
+	{
@@ -353,0 +405 @@
+	},
@@ -354,0 +407 @@
+	{
@@ -361,13 +414 @@
-	"	syopen, nulldev, syread, sywrite, sysioctl, nulldev, 0,",
-	"",
-	"int	syopen(), syread(), sywrite(), sysioctl();",
-
-	0
-};
-
-char	*stra[] =
-{
-	"/ low core",
-	"",
-	".data",
-	"ZERO:",
+	"	syopen, nulldev, syread, sywrite, sysioctl, nulltty, 0,",
@@ -375,22 +415,0 @@
-	"br4 = 200",
-	"br5 = 240",
-	"br6 = 300",
-	"br7 = 340",
-	"",
-	". = ZERO+0",
-	"	br	1f",
-	"	4",
-	"",
-	"/ trap vectors",
-	"	trap; br7+0.		/ bus error",
-	"	trap; br7+1.		/ illegal instruction",
-	"	trap; br7+2.		/ bpt-trace trap",
-	"	trap; br7+3.		/ iot trap",
-	"	trap; br7+4.		/ power fail",
-	"	trap; br7+5.		/ emulator trap",
-	"	start;br7+6.		/ system  (overlaid by 'trap')",
-	"",
-	". = ZERO+40",
-	".globl	start, dump",
-	"1:	jmp	start",
-	"	jmp	dump",
@@ -398,2 +417 @@
-	0,
-};
+	},
@@ -401,28 +419 @@
-char	*strb[] =
-{
-	"",
-	". = ZERO+240",
-	"	trap; br7+7.		/ programmed interrupt",
-	"	trap; br7+8.		/ floating point",
-	"	trap; br7+9.		/ segmentation violation",
-	0
-};
-
-char	*strc[] =
-{
-	"",
-	"/ floating vectors",
-	". = ZERO+300",
-	0,
-};
-
-char	*strd[] =
-{
-	"",
-	"//////////////////////////////////////////////////////",
-	"/		interface code to C",
-	"//////////////////////////////////////////////////////",
-	"",
-	".text",
-	".globl	call, trap",
-	0
+	{0}
@@ -446,2 +437 @@
-	"int	nulldev();",
-	"int	nodev();",
+	"#include \"../h/seg.h\"",
@@ -460 +450 @@
-	"	0",
+	"	{0}",
@@ -476 +466 @@
-"	0\n\
+"	{0}\n\
@@ -483 +473 @@
-int	nswap	= %l;\n\
+int	nswap	= %d;\n\
@@ -494,7 +483,0 @@
-char	*strg1a[] =
-{
-	"int	mpxchan();",
-	"int	(*ldmpx)() = mpxchan;",
-	0
-};
-
@@ -512 +495 @@
-	"	0",
+	"	{0}",
@@ -515 +497,0 @@
-	"int	ttyopen(), ttyclose(), ttread(), ttwrite(), ttyinput(), ttstart();",
@@ -529 +511 @@
-	"	ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart, /* 0 */",
+	"	{ttyopen, nulltty, ttread, ttwrite, nolioctl, ttyinput, 0, 0, ttstart, 0}, /* 0 */",
@@ -535 +517 @@
-	"	pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint, /* 1 */",
+	"	{pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint, 0, 0, 0}, /* 1 */",
@@ -550,0 +533,6 @@
+int	ddr;
+unsigned long	ramb, ramn, tabb, tabn, coreb, coret, pguser, gicd, gicc;
+#define	NMAP	8
+unsigned long	mapb[NMAP], mape[NMAP];
+char	mapa[NMAP][100];
+int	nmap;
@@ -552 +540,2 @@
-main()
+int
+main(void)
@@ -556,2 +545 @@
-	int i, n, ev, nkl;
-	int flagf, flagb, dumpht;
+	int i;
@@ -562 +550 @@
- * pass1 -- create interrupt vectors
+ * pass1 -- create linker script
@@ -564,46 +552,14 @@
-	nkl = 0;
-	flagf = flagb = 1;
-	freopen("l.s", "w", stdout);
-	puke(stra);
-	ev = 0;
-	for(p=table; p->name; p++)
-	if(p->count != 0 && p->key & INTR) {
-		if(p->address>240 && flagb) {
-			flagb = 0;
-			puke(strb);
-		}
-		if(p->address >= 300) {
-			if(flagf) {
-				ev = 0;
-				flagf = 0;
-				puke(strc);
-			}
-			if(p->key & EVEN && ev & 07) {
-				printf("	.=.+4\n");
-				ev += 4;
-			}
-			printf("/%s %o\n", p->name, 0300+ev);
-		} else
-			printf("\n. = ZERO+%d\n", p->address);
-		n = p->count;
-		if(n < 0)
-			n = -n;
-		for(i=0; i<n; i++) {
-			if(p->key & KL) {
-				printf(p->codea, nkl, nkl);
-				nkl++;
-			} else
-				printf(p->codea, i, i);
-			if (p->address<300)
-				fprintf(stderr, "%s at %d\n", p->name, p->address+4*i);
-			else
-				fprintf(stderr, "%s at %o\n", p->name, 0300+ev);
-			ev += p->address - 300;
-		}
-	}
-	if(flagb)
-		puke(strb);
-	puke(strd);
-	for(p=table; p->name; p++)
-	if(p->count != 0 && p->key & INTR)
-		printf("\n%s%s", p->codeb, p->codec);
+	freopen("unix.ld", "w", stdout);
+	printf("MEMORY\n{\n");
+	printf("\tRAM (rwx) : ORIGIN = 0x%lx, LENGTH = 0x%lx\n", ramb, ramn);
+	if (tabn)
+		printf("\tTAB (rwx) : ORIGIN = 0x%lx, LENGTH = 0x%lx\n", tabb, tabn);
+	printf("}\nu = 0x4F000000;\nSECTIONS\n{\n");
+	printf("\t.text : { *(.text*) } > RAM\n");
+	printf("\t.rodata : { *(.rodata*) } > RAM\n");
+	printf("\t.data : { *(.data*) } > RAM\n");
+	printf("\t. = ALIGN(4);\n\t__bss_start = .;\n\t.bss : { *(.bss*) *(COMMON) } > RAM\n");
+	printf("\t__bss_end = .;\n");
+	printf("\t.ddrbss (NOLOAD) : ALIGN(16384) {\n");
+	printf("\t\t__ddrbss_start = .;\n\t\t*(.ddrbss*)\n");
+	printf("\t\t__ddrbss_end = .;\n\t} > %s\n}\n", tabn ? "TAB" : "RAM");
@@ -620 +576 @@
-	for (i=0; q=btab[i]; i++) {
+	for (i=0; (q=btab[i]); i++) {
@@ -627 +583 @@
-	for(i=0; q=btab[i]; i++) {
+	for(i=0; (q=btab[i]); i++) {
@@ -631 +587 @@
-			printf("%s	/* %s = %d */\n", p->coded, q, i);
+			printf("	{%s},	/* %s = %d */\n", p->coded, q, i);
@@ -640 +596 @@
-		printf("	nodev, nodev, nodev, 0, /* %s = %d */\n", q, i);
+		printf("	{nodev, nodev, nostrat, 0}, /* %s = %d */\n", q, i);
@@ -652 +608 @@
-	for (i=0; q=ctab[i]; i++) {
+	for (i=0; (q=ctab[i]); i++) {
@@ -659 +615 @@
-	for(i=0; q=ctab[i]; i++) {
+	for(i=0; (q=ctab[i]); i++) {
@@ -663 +619 @@
-			printf("%s	/* %s = %d */\n", p->codee, q, i);
+			printf("	{%s},	/* %s = %d */\n", p->codee, q, i);
@@ -666 +622 @@
-		printf("	nodev, nodev, nodev, nodev, nodev, nulldev, 0, /* %s = %d */\n", q, i);
+		printf("	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* %s = %d */\n", q, i);
@@ -683,2 +638,0 @@
-	if (!mpx)
-		puke(strg1a);
@@ -688,13 +642,15 @@
-	freopen("mch0.s", "w", stdout);
-	dumpht = 0;
-	for (i=0; table[i].name; i++) {
-		if (equal(table[i].name, "ht") && table[i].count)
-			dumpht = 1;
-	}
-	if (dumpht) {
-		printf("HTDUMP = 1\n");
-		printf("TUDUMP = 0\n");
-	} else {
-		printf("HTDUMP = 0\n");
-		printf("TUDUMP = 1\n");
-	}
+	printf("\nunsigned int\tkernbase = 0x%lx;\n", ramb);
+	printf("unsigned int\tcorebase = 0x%lx, coretop = 0x%lx;\n", coreb, coret);
+	printf("unsigned int\tpguser = 0x%lx;\n", pguser);
+	printf("unsigned int\tgicdbase = 0x%lx, giccbase = 0x%lx;\n", gicd, gicc);
+	printf("\nstruct\tmemregion\tboard_map[] =\n{\n");
+	for (i=0; i<nmap; i++)
+		printf("\t{0x%lx, 0x%lx, %s},\n", mapb[i], mape[i], mapa[i]);
+	printf("\t{0, 0, 0}\n};\n");
+	printf("\nextern int\tklirq, rkirq;\n");
+	printf("struct\tintr\tintrtab[] =\n{\n");
+	printf("\t{&klirq, klintr},\n\t{&rkirq, rkintr},\n");
+	printf("\t{0, 0}\n};\n");
+	printf("\nvoid\tcninit(void) { klinit(); }\n");
+	printf("void\tbdinit(void) { rkinit(); }\n");
+	printf("void\tclock_ddr_init(void) { %s}\n", ddr ? "ddrinit(); " : "");
@@ -703,2 +659,2 @@
-puke(s, a)
-char **s;
+void
+puke(char **s)
@@ -708,2 +664,2 @@
-	while(c = *s++) {
-		printf(c, a);
+	while((c = *s++)) {
+		printf(c);
@@ -714 +670,2 @@
-input()
+int
+input(void)
@@ -720 +677 @@
-	char keyw[32], dev[32];
+	char keyw[100], dev[100];
@@ -726 +683 @@
-	if (count == -1 && n>0) {
+	if (count == -1) {
@@ -728 +685 @@
-		n++;
+		n = sscanf(line, "%s%s%ld", keyw, dev, &num) + 1;
@@ -731,0 +689,20 @@
+	if (equal(keyw, "map") && nmap < NMAP) {
+		if (sscanf(line, "%*s%lx%lx%s", &mapb[nmap], &mape[nmap], mapa[nmap]) != 3)
+			goto badl;
+		nmap++;
+		return(1);
+	}
+	if (equal(keyw, "ram"))
+		return(sscanf(line, "%*s%lx%lx", &ramb, &ramn) == 2 || badline(line));
+	if (equal(keyw, "tables"))
+		return(sscanf(line, "%*s%lx%lx", &tabb, &tabn) == 2 || badline(line));
+	if (equal(keyw, "core"))
+		return(sscanf(line, "%*s%lx%lx", &coreb, &coret) == 2 || badline(line));
+	if (equal(keyw, "gic"))
+		return(sscanf(line, "%*s%lx%lx", &gicd, &gicc) == 2 || badline(line));
+	if (equal(keyw, "pguser"))
+		return(sscanf(line, "%*s%lx", &pguser) == 1 || badline(line));
+	if (equal(keyw, "ddr")) {
+		ddr++;
+		return(1);
+	}
@@ -812,0 +790,6 @@
+	return(badline(line));
+}
+
+int
+badline(char *line)
+{
@@ -817,2 +800,2 @@
-equal(a, b)
-char *a, *b;
+int
+equal(char *a, char *b)

% usr/sys/conf/mp135conf usr/sys/conf/rktmconf
@@ -4 +4 @@
-swplo 4000
+swplo 10648
@@ -6 +6,10 @@
-tm
+ram 2ffe0000 20000
+tables c0000000 20000000
+core c0100000 e0000000
+gic a0021000 a0022000
+pguser 472
+map 2ff00000 30000000 SEC_KERN
+map c0000000 e0000000 0x11402
+map 40000000 60000000 SEC_DEV
+map a0000000 a0100000 SEC_DEV
+ddr

% usr/sys/conf/qemuconf usr/sys/conf/rktmconf
@@ -4 +4 @@
-swplo 4000
+swplo 10648
@@ -6 +6,6 @@
-tm
+ram 40000000 4000000
+core 44000000 48000000
+gic 08000000 08010000
+pguser 47e
+map 40000000 48000000 SEC_KERN
+map 08000000 0c000000 SEC_DEV

% usr/sys/dev/bio.c
@@ -8,0 +9,3 @@
+int	incore(dev_t dev, daddr_t blkno);
+void	iowait(struct buf *bp), notavail(struct buf *bp),
+	geterror(struct buf *bp);
@@ -56,3 +59 @@
-bread(dev, blkno)
-dev_t dev;
-daddr_t blkno;
+bread(dev_t dev, daddr_t blkno)
@@ -84,3 +85 @@
-breada(dev, blkno, rablkno)
-dev_t dev;
-daddr_t blkno, rablkno;
+breada(dev_t dev, daddr_t blkno, daddr_t rablkno)
@@ -125,2 +124,2 @@
-bwrite(bp)
-register struct buf *bp;
+void
+bwrite(register struct buf *bp)
@@ -128 +127 @@
-	register flag;
+	register int flag;
@@ -154,2 +153,2 @@
-bdwrite(bp)
-register struct buf *bp;
+void
+bdwrite(register struct buf *bp)
@@ -171,2 +170,2 @@
-bawrite(bp)
-register struct buf *bp;
+void
+bawrite(register struct buf *bp)
@@ -182,2 +181,2 @@
-brelse(bp)
-register struct buf *bp;
+void
+brelse(register struct buf *bp)
@@ -186 +185 @@
-	register s;
+	register int s;
@@ -218,3 +217,2 @@
-incore(dev, blkno)
-dev_t dev;
-daddr_t blkno;
+int
+incore(dev_t dev, daddr_t blkno)
@@ -238,3 +236 @@
-getblk(dev, blkno)
-dev_t dev;
-daddr_t blkno;
+getblk(dev_t dev, daddr_t blkno)
@@ -245 +241 @@
-	register i;
+	register int i;
@@ -309 +305 @@
-geteblk()
+geteblk(void)
@@ -343,2 +339,2 @@
-iowait(bp)
-register struct buf *bp;
+void
+iowait(register struct buf *bp)
@@ -358,2 +354,2 @@
-notavail(bp)
-register struct buf *bp;
+void
+notavail(register struct buf *bp)
@@ -361 +357 @@
-	register s;
+	register int s;
@@ -374,2 +370,2 @@
-iodone(bp)
-register struct buf *bp;
+void
+iodone(register struct buf *bp)
@@ -392,2 +388,2 @@
-clrbuf(bp)
-struct buf *bp;
+void
+clrbuf(struct buf *bp)
@@ -395,2 +391,2 @@
-	register *p;
-	register c;
+	register int *p;
+	register int c;
@@ -409,2 +405,2 @@
-swap(blkno, coreaddr, count, rdflg)
-register count;
+void
+swap(int blkno, int coreaddr, register int count, int rdflg)
@@ -413 +409 @@
-	register tcount;
+	register int tcount;
@@ -432 +428 @@
-		bp->b_un.b_addr = (caddr_t)(coreaddr<<6);
+		bp->b_un.b_addr = CLKADDR(coreaddr);
@@ -456,2 +452,2 @@
-bflush(dev)
-dev_t dev;
+void
+bflush(dev_t dev)
@@ -484,3 +480,2 @@
-physio(strat, bp, dev, rw)
-register struct buf *bp;
-int (*strat)();
+void
+physio(void (*strat)(struct buf *bp), register struct buf *bp, int dev, int rw)
@@ -496 +491,2 @@
-	if (base&01 || u.u_count&01 || base>=base+u.u_count)
+	if (base&01 || u.u_count&01 || base>=base+u.u_count ||
+	    base+u.u_count > USERSIZE)
@@ -501 +497 @@
-	nb = (base>>6) & 01777;
+	nb = base>>6;
@@ -508,9 +503,0 @@
-	/*
-	 * Check that transfer is either entirely in the
-	 * data or in the stack: that is, either
-	 * the end is in the data or the start is in the stack
-	 * (remember wraparound was already checked).
-	 */
-	if ((((base+u.u_count)>>6)&01777) >= ts+u.u_dsize
-	    && nb < 1024-u.u_ssize)
-		goto bad;
@@ -528,2 +515,2 @@
-	ts = (u.u_sep? UDSA: UISA)->r[nb>>7] + (nb&0177);
-	bp->b_un.b_addr = (caddr_t)((ts<<6) + (base&077));
+	ts = u.u_procp->p_addr + USIZE + nb;
+	bp->b_un.b_addr = CLKADDR(ts) + (base&077);
@@ -557,2 +544,2 @@
-geterror(bp)
-register struct buf *bp;
+void
+geterror(register struct buf *bp)

% usr/sys/dev/mem.c
@@ -12,0 +13 @@
+#include "../h/systm.h"
@@ -18 +19,2 @@
-mmread(dev)
+void
+mmread(int dev)
@@ -20,2 +22 @@
-	register c, bn, on;
-	int a, d;
+	register int c;
@@ -26,10 +27 @@
-		bn = u.u_offset >> 6;
-		on = u.u_offset & 077;
-		a = UISA->r[0];
-		d = UISD->r[0];
-		spl7();
-		UISA->r[0] = bn;
-		UISD->r[0] = 077406;
-		if(minor(dev) == 1)
-			UISA->r[0] = (ka6-6)->r[(bn>>7)&07] + (bn & 0177);
-		if ((c = fuibyte((caddr_t)on)) < 0)
+		if ((c = fumem(u.u_offset)) < 0)
@@ -37,3 +28,0 @@
-		UISA->r[0] = a;
-		UISD->r[0] = d;
-		spl0();
@@ -43 +32,2 @@
-mmwrite(dev)
+void
+mmwrite(int dev)
@@ -45,2 +35 @@
-	register c, bn, on;
-	int a, d;
+	register int c;
@@ -53,2 +41,0 @@
-		bn = u.u_offset >> 6;
-		on = u.u_offset & 077;
@@ -57,8 +44 @@
-		a = UISA->r[0];
-		d = UISD->r[0];
-		spl7();
-		UISA->r[0] = bn;
-		UISD->r[0] = 077406;
-		if(minor(dev) == 1)
-			UISA->r[0] = (ka6-6)->r[(bn>>7)&07] + (bn & 0177);
-		if (suibyte((caddr_t)on, c) < 0)
+		if (sumem(u.u_offset-1, c) < 0)
@@ -66,3 +45,0 @@
-		UISA->r[0] = a;
-		UISD->r[0] = d;
-		spl0();

% usr/sys/dev/partab.c

% usr/sys/dev/pl011.c usr/sys/dev/kl.c
@@ -12 +12 @@
-#define	KLADDR	((struct device *)0177560)	/* console */
+#define	KLADDR	0x09000000
@@ -18,0 +19,9 @@
+#define	UARTDR	(*(volatile int *)(KLADDR+0x00))
+#define	UARTFR	(*(volatile int *)(KLADDR+0x18))
+#define	UARTCR	(*(volatile int *)(KLADDR+0x30))
+#define	UARTIMSC	(*(volatile int *)(KLADDR+0x38))
+#define	UARTMIS	(*(volatile int *)(KLADDR+0x40))
+#define	UARTICR	(*(volatile int *)(KLADDR+0x44))
+#define	TXFF	040
+#define	RXI	020
+#define	TXI	040
@@ -28,3 +37,2 @@
-int	klstart();
-int	ttrstrt();
-char	partab[];
+void	klstart(struct tty *tp);
+int	klirq = 33;
@@ -39,2 +47,2 @@
-klopen(dev, flag)
-dev_t dev;
+void
+klopen(dev_t dev, int flag)
@@ -42 +49,0 @@
-	register struct device *addr;
@@ -44 +51 @@
-	register d;
+	register int d;
@@ -45,0 +53 @@
+	(void)flag;
@@ -52,12 +59,0 @@
-	/*
-	 * set up minor 0 to address KLADDR
-	 * set up minor 1 thru NKL11-1 to address from KLBASE
-	 * set up minor NKL11 on to address from DLBASE
-	 */
-	if(d == 0)
-		addr = KLADDR;
-	else if(d < NKL11)
-		addr = KLBASE + (d-1);
-	else
-		addr = DLBASE + (d-NKL11);
-	tp->t_addr = (caddr_t)addr;
@@ -67 +63 @@
-		tp->t_flags = EVENP|LCASE|ECHO|XTABS|CRMOD|CR2;
+		tp->t_flags = EVENP|ECHO|XTABS|CRMOD;
@@ -70,2 +66 @@
-	addr->rcsr |= IENABLE|DSRDY|RDRENB;
-	addr->tcsr |= IENABLE;
+	UARTIMSC = RXI|TXI;
@@ -75,3 +70,2 @@
-klclose(dev, flag)
-dev_t dev;
-int flag;
+void
+klclose(dev_t dev, int flag)
@@ -80,0 +75 @@
+	(void)flag;
@@ -85,2 +80,2 @@
-klread(dev)
-dev_t dev;
+void
+klread(dev_t dev)
@@ -91,2 +86,2 @@
-klwrite(dev)
-dev_t dev;
+void
+klwrite(dev_t dev)
@@ -97,2 +92,2 @@
-klxint(dev)
-dev_t dev;
+static void
+klxint(dev_t dev)
@@ -105,4 +100 @@
-		if (tp->t_chan)
-			mcstart(tp->t_chan, (caddr_t)&tp->t_outq);
-		else
-			wakeup((caddr_t)&tp->t_outq);
+		wakeup((caddr_t)&tp->t_outq);
@@ -111,2 +103,2 @@
-klrint(dev)
-dev_t dev;
+static void
+klrint(dev_t dev)
@@ -115 +106,0 @@
-	register struct device *addr;
@@ -119,3 +110 @@
-	addr = (struct device *)tp->t_addr;
-	c = addr->rbuf;
-	addr->rcsr |= RDRENB;
+	c = UARTDR;
@@ -125,3 +114,2 @@
-klioctl(dev, cmd, addr, flag)
-caddr_t addr;
-dev_t dev;
+void
+klioctl(dev_t dev, int cmd, caddr_t addr, int flag)
@@ -129 +117,2 @@
-	if (ttioccom(cmd, &kl11[minor(dev)], addr, dev)==0)
+	(void)flag;
+	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
@@ -133,2 +122,2 @@
-klstart(tp)
-register struct tty *tp;
+void
+klstart(register struct tty *tp)
@@ -136,2 +125 @@
-	register c;
-	register struct device *addr;
+	register int c;
@@ -139,2 +127 @@
-	addr = (struct device *)tp->t_addr;
-	if((addr->tcsr&DONE) == 0)
+	if(UARTFR&TXFF)
@@ -144 +131 @@
-			addr->tbuf = c;
+			UARTDR = c;
@@ -146 +133 @@
-			addr->tbuf = c | (partab[c]&0200);
+			UARTDR = c;
@@ -154 +141,17 @@
-char	*msgbufp = msgbuf;	/* Next saved printf character */
+void
+klinit(void)
+{
+	UARTCR = 0x301;
+}
+
+void
+klintr(void)
+{
+	if (UARTMIS&RXI)
+		klrint(0);
+	if (UARTMIS&TXI) {
+		UARTICR = TXI;
+		klxint(0);
+	}
+}
+
@@ -166,2 +169,2 @@
-putchar(c)
-register c;
+void
+putchar(register int c)
@@ -169 +172,2 @@
-	register s, timo;
+	register int s;
+	unsigned long long timo;
@@ -176,6 +180 @@
-	/*
-	 *  If last char was a break or null, don't print
-	*/
-	if ((KLADDR->rbuf&0177) == 0)
-		return;
-	timo = 30000;
+	timo = cntvct_get() + cntfrq_get()/HZ;
@@ -186,2 +185,2 @@
-	while((KLADDR->tcsr&0200) == 0)
-		if(--timo == 0)
+	while(UARTFR&TXFF)
+		if(cntvct_get() >= timo)
@@ -191,3 +190,3 @@
-	s = KLADDR->tcsr;
-	KLADDR->tcsr = 0;
-	KLADDR->tbuf = c;
+	s = UARTIMSC;
+	UARTIMSC = 0;
+	UARTDR = c;
@@ -196,2 +194,0 @@
-		putchar(0177);
-		putchar(0177);
@@ -200 +197 @@
-	KLADDR->tcsr = s;
+	UARTIMSC = s;

% usr/sys/dev/stm32ddr.c /dev/null
@@ -0,0 +1,189 @@
+#include "../h/param.h"
+#include "../h/systm.h"
+
+#define	R(a)	(*(volatile unsigned int *)(a))
+#define	RCC(o)	R(0x50000000+(o))
+#define	DDRC(o)	R(0x5A003000+(o))
+#define	DPHY(o)	R(0x5A004000+(o))
+#define	DDRITFCR	RCC(0x5C0)
+
+static unsigned int ddrc[] = {
+	0x000, 0x00040401,
+	0x010, 0x00000010,
+	0x014, 0x00000000,
+	0x020, 0x00000000,
+	0x024, 0x00800000,
+	0x030, 0x00000000,
+	0x034, 0x00400010,
+	0x038, 0x00000000,
+	0x050, 0x00210000,
+	0x060, 0x00000000,
+	0x0C0, 0x00000000,
+	0x180, 0xC2000040,
+	0x190, 0x02060105,
+	0x194, 0x00000202,
+	0x198, 0x07000000,
+	0x1A0, 0xC0400003,
+	0x1A4, 0x00000000,
+	0x1A8, 0x00000000,
+	0x1C4, 0x00000000,
+	0x244, 0x00000001,
+	0x300, 0x00000000,
+	0x304, 0x00000000,
+	0x30C, 0x00000000,
+	0x36C, 0x00000000,
+	0x400, 0x00000010,
+	0x064, 0x0081008B,
+	0x100, 0x121B2414,
+	0x104, 0x000A041C,
+	0x108, 0x0608090F,
+	0x10C, 0x0050400C,
+	0x110, 0x08040608,
+	0x114, 0x06060403,
+	0x118, 0x02020002,
+	0x11C, 0x00000202,
+	0x120, 0x00001005,
+	0x138, 0x000000A0,
+	0x240, 0x06000600,
+	0x204, 0x00080808,
+	0x208, 0x00000000,
+	0x20C, 0x00000000,
+	0x210, 0x00001F1F,
+	0x214, 0x07070707,
+	0x218, 0x0F070707,
+	0x224, 0x00000000,
+	0x228, 0x00000000,
+	0x22C, 0x00000000,
+	0x0D0, 0x4002004E,
+	0x250, 0x00000F01,
+	0x254, 0x00000000,
+	0x25C, 0x00000001,
+	0x264, 0x04000200,
+	0x26C, 0x08000400,
+	0x404, 0x00000000,
+	0x408, 0x00000000,
+	0x494, 0x00100009,
+	0x498, 0x00000020,
+	0x49C, 0x01100B03,
+	0x4A0, 0x01000200,
+	0xFFFF
+};
+
+static unsigned int dphy[] = {
+	0x008, 0x01442E02,
+	0x024, 0x10400812,
+	0x028, 0x00000C40,
+	0x02C, 0xF200011F,
+	0x030, 0x0000000B,
+	0x050, 0x00010000,
+	0x184, 0x00000038,
+	0x1C0, 0x0000CE81,
+	0x200, 0x0000CE81,
+	0x018, 0x0022AA5B,
+	0x01C, 0x04841104,
+	0x020, 0x042DA068,
+	0x034, 0x38D488D0,
+	0x038, 0x098B00D8,
+	0x03C, 0x10023600,
+	0x040, 0x00000840,
+	0x044, 0x00000000,
+	0x048, 0x00000208,
+	0x04C, 0x00000000,
+	0xFFFF
+};
+
+static void
+pgwait(void)
+{
+	unsigned int s;
+
+	while (((s = DPHY(0x00C)) & 0x3E1) == 0)
+		;
+	if (s & 0x3E0) {
+		printf("PGSR %x\n", s);
+		panic("ddr");
+	}
+}
+
+void
+ddrinit(void)
+{
+	unsigned int *r;
+	int i;
+
+	RCC(0x420) = 0x100;
+	while ((RCC(0x428) & 0x100) == 0)
+		;
+	RCC(0x4D0) &= ~1;
+	while (RCC(0x4D0) & 2)
+		;
+	RCC(0x480) = (RCC(0x480) & ~7) | 1;
+	RCC(0x4D4) = 0x00020041;
+	RCC(0x4D8) = 0x00000101;
+	RCC(0x4DC) = 0x1400 << 3;
+	RCC(0x4DC) |= 0x10000;
+	RCC(0x4D0) |= 0x70;
+	RCC(0x4D0) |= 1;
+	while ((RCC(0x4D0) & 2) == 0)
+		;
+
+	if (R(0x5000100C) & 0x1000) {
+		R(0x5000100C) |= 0x800;
+		R(0x5000100C) &= ~0x1000;
+	}
+	RCC(0x780) = 2;
+	RCC(0x740) = 0x800;
+	(void)RCC(0x740);
+	R(0x5C006008) = 0;
+	R(0x5C006114) = 0xFFFFFFFF;
+	R(0x5C006110) = 0xC0000001;
+	R(0x5C006008) = 1;
+
+	DDRITFCR &= ~0x100;
+	DDRITFCR |= 0xFC000;
+	DDRITFCR |= 0x251;
+	DDRITFCR &= ~0xC0000;
+	DDRITFCR &= ~0x4000;
+	for (i = 0; i < 10000; i++)
+		(void)DDRITFCR;
+	DDRC(0x1B0) &= ~1;
+	for (r = ddrc; *r != 0xFFFF; r += 2)
+		DDRC(r[0]) = r[1];
+	DDRITFCR &= ~0x38000;
+	for (r = dphy; *r != 0xFFFF; r += 2)
+		DPHY(r[0]) = r[1];
+	while ((DPHY(0x00C) & 1) == 0)
+		;
+
+	DPHY(0x004) = 0x1007F;
+	for (i = 0; i < 10000; i++)
+		(void)DDRITFCR;
+	pgwait();
+	DDRC(0x320) &= ~1;
+	DDRC(0x1B0) |= 1;
+	DDRC(0x320) |= 1;
+	while ((DDRC(0x324) & 1) == 0)
+		;
+	while ((DDRC(0x004) & 7) != 1)
+		;
+
+	DDRC(0x320) &= ~1;
+	DDRC(0x1B0) &= ~1;
+	DDRC(0x060) |= 1;
+	DDRC(0x320) |= 1;
+	while ((DDRC(0x324) & 1) == 0)
+		;
+	DPHY(0x004) = 0x81;
+	for (i = 0; i < 10000; i++)
+		(void)DDRITFCR;
+	pgwait();
+	DDRC(0x320) &= ~1;
+	DDRC(0x060) = 0;
+	DDRC(0x1B0) |= 1;
+	DDRC(0x320) |= 1;
+	while ((DDRC(0x324) & 1) == 0)
+		;
+
+	DDRC(0x490) |= 1;
+	DDRITFCR |= 0x100;
+}

% usr/sys/dev/stm32sd.c usr/sys/dev/rk.c
@@ -12 +12 @@
-#define	RKADDR	((struct device *)0177400)
+#define	SD(off)	(*(volatile int *)(0x58005000+(off)))
@@ -14 +14 @@
-#define	NRKBLK	4872
+#define	NRKBLK	11520
@@ -17,3 +17,3 @@
-#define	WCOM	2
-#define	RCOM	4
-#define	GO	01
+#define	WCOM	24
+#define	RCOM	17
+#define	GO	0x1140
@@ -21 +21 @@
-#define	IENABLE	0100
+#define	IENABLE	0x800013f
@@ -25,0 +26,14 @@
+#define	ARG	0x08
+#define	CMD	0x0c
+#define	DTIMER	0x24
+#define	DLEN	0x28
+#define	DCTRL	0x2c
+#define	STA	0x34
+#define	ICR	0x38
+#define	MASK	0x3c
+#define	IDMACTRL	0x50
+#define	IDMABASER	0x58
+#define	ERR	0x800003f
+#define	DTDIR	02
+#define	BLK512	0220
+#define	CLEAR	0x1fe00fff
@@ -32,10 +46,2 @@
-struct	device
-{
-	int	rkds;
-	int	rker;
-	int	rkcs;
-	int	rkwc;
-	caddr_t	rkba;
-	int	rkda;
-};
-
+void rkstart(void);
+int	rkirq = 82;
@@ -43,0 +50 @@
+unsigned	rkoff;
@@ -45,2 +52,8 @@
-rkstrategy(bp)
-register struct buf *bp;
+void
+rkinit(void)
+{
+	SD(DTIMER) = -1;
+}
+
+void
+rkstrategy(register struct buf *bp)
@@ -51 +64 @@
-	if (bp->b_blkno >= NRKBLK) {
+	if (bp->b_blkno >= NRKBLK || bp->b_bcount&BMASK || (int)bp->b_un.b_addr&3) {
@@ -68 +81,2 @@
-rkstart()
+void
+rkstart(void)
@@ -71,3 +85 @@
-	register com;
-	daddr_t bn;
-	int dn, cn, sn;
+	register int com;
@@ -78,8 +90,10 @@
-	bn = bp->b_blkno;
-	dn = minor(bp->b_dev);
-	cn = bn/12;
-	sn = bn%12;
-	RKADDR->rkda = (dn<<13) | (cn<<4) | sn;
-	RKADDR->rkba = bp->b_un.b_addr;
-	RKADDR->rkwc = -(bp->b_bcount>>1);
-	com = ((bp->b_xmem&3) << 4) | IENABLE | GO;
+	dcflush(bp->b_un.b_addr+rkoff, BSIZE);
+	SD(ICR) = CLEAR;
+	SD(DCTRL) = 0;
+	SD(DLEN) = BSIZE;
+	SD(DCTRL) = bp->b_flags&B_READ ? BLK512|DTDIR : BLK512;
+	SD(IDMABASER) = (int)bp->b_un.b_addr+rkoff;
+	SD(IDMACTRL) = 1;
+	SD(MASK) = IENABLE;
+	SD(ARG) = bp->b_blkno+(rkoff>>BSHIFT);
+	com = GO;
@@ -89 +103 @@
-	RKADDR->rkcs = com;
+	SD(CMD) = com;
@@ -92 +106 @@
-	com = bp->b_bcount>>6;
+	com = BSIZE>>6;
@@ -96 +110,2 @@
-rkintr()
+void
+rkintr(void)
@@ -98,0 +114 @@
+	register int sta;
@@ -99,0 +116,4 @@
+	sta = SD(STA);
+	SD(ICR) = CLEAR;
+	SD(MASK) = 0;
+	SD(IDMACTRL) = 0;
@@ -105,5 +125,2 @@
-	if (RKADDR->rkcs < 0) {		/* error bit */
-		deverror(bp, RKADDR->rker, RKADDR->rkds);
-		RKADDR->rkcs = RESET|GO;
-		while((RKADDR->rkcs&CTLRDY) == 0)
-			;
+	if (sta & ERR) {
+		deverror(bp, sta, 0);
@@ -114,0 +132,3 @@
+	} else if ((rkoff += BSIZE) < bp->b_bcount) {
+		rkstart();
+		return;
@@ -115,0 +136,3 @@
+	rkoff = 0;
+	if (bp->b_flags & B_READ)
+		dcflush(bp->b_un.b_addr, bp->b_bcount);
@@ -123,2 +146,2 @@
-rkread(dev)
-dev_t dev;
+void
+rkread(dev_t dev)
@@ -130,2 +153,2 @@
-rkwrite(dev)
-dev_t dev;
+void
+rkwrite(dev_t dev)

% usr/sys/dev/stm32usart.c usr/sys/dev/kl.c
@@ -12 +12 @@
-#define	KLADDR	((struct device *)0177560)	/* console */
+#define	KLADDR	0x40010000
@@ -14,0 +15,2 @@
+#define	RCC	0x50000000
+#define	GPIOD	0x50005000
@@ -18,0 +21,19 @@
+#define	CR1	(*(volatile int *)(KLADDR+0x00))
+#define	BRR	(*(volatile int *)(KLADDR+0x0c))
+#define	ISR	(*(volatile int *)(KLADDR+0x1c))
+#define	ICR	(*(volatile int *)(KLADDR+0x20))
+#define	RDR	(*(volatile int *)(KLADDR+0x24))
+#define	TDR	(*(volatile int *)(KLADDR+0x28))
+#define	UART4CKSELR	(*(volatile int *)(RCC+0x61c))
+#define	APB1ENSETR	(*(volatile int *)(RCC+0x700))
+#define	AHB4ENSETR	(*(volatile int *)(RCC+0x770))
+#define	GPIOD_MODER	(*(volatile int *)(GPIOD+0x00))
+#define	GPIOD_AFRL	(*(volatile int *)(GPIOD+0x20))
+#define	GPIOD_AFRH	(*(volatile int *)(GPIOD+0x24))
+#define	UE	01
+#define	RE	04
+#define	TE	010
+#define	RXNEIE	040
+#define	TXEIE	0200
+#define	RXNE	040
+#define	TXE	0200
@@ -28,3 +49,2 @@
-int	klstart();
-int	ttrstrt();
-char	partab[];
+void	klstart(struct tty *tp);
+int	klirq = 85;
@@ -39,2 +59,17 @@
-klopen(dev, flag)
-dev_t dev;
+void
+klinit(void)
+{
+	AHB4ENSETR = 010;
+	(void)AHB4ENSETR;
+	GPIOD_MODER = (GPIOD_MODER & ~(3<<12|3<<16)) | 2<<12 | 2<<16;
+	GPIOD_AFRL = (GPIOD_AFRL & ~(017<<24)) | 8<<24;
+	GPIOD_AFRH = (GPIOD_AFRH & ~017) | 8;
+	APB1ENSETR = 0x10000;
+	(void)APB1ENSETR;
+	UART4CKSELR = (UART4CKSELR & ~7) | 2;
+	BRR = 556;
+	CR1 = UE|TE|RE;
+}
+
+void
+klopen(dev_t dev, int flag)
@@ -42 +76,0 @@
-	register struct device *addr;
@@ -44 +78 @@
-	register d;
+	register int d;
@@ -45,0 +80 @@
+	(void)flag;
@@ -52,12 +86,0 @@
-	/*
-	 * set up minor 0 to address KLADDR
-	 * set up minor 1 thru NKL11-1 to address from KLBASE
-	 * set up minor NKL11 on to address from DLBASE
-	 */
-	if(d == 0)
-		addr = KLADDR;
-	else if(d < NKL11)
-		addr = KLBASE + (d-1);
-	else
-		addr = DLBASE + (d-NKL11);
-	tp->t_addr = (caddr_t)addr;
@@ -67 +90 @@
-		tp->t_flags = EVENP|LCASE|ECHO|XTABS|CRMOD|CR2;
+		tp->t_flags = EVENP|ECHO|XTABS|CRMOD;
@@ -70,2 +93 @@
-	addr->rcsr |= IENABLE|DSRDY|RDRENB;
-	addr->tcsr |= IENABLE;
+	CR1 |= RXNEIE;
@@ -75,3 +97,2 @@
-klclose(dev, flag)
-dev_t dev;
-int flag;
+void
+klclose(dev_t dev, int flag)
@@ -80,0 +102 @@
+	(void)flag;
@@ -85,2 +107,2 @@
-klread(dev)
-dev_t dev;
+void
+klread(dev_t dev)
@@ -91,2 +113,2 @@
-klwrite(dev)
-dev_t dev;
+void
+klwrite(dev_t dev)
@@ -97,2 +119,2 @@
-klxint(dev)
-dev_t dev;
+static void
+klxint(dev_t dev)
@@ -102,0 +125 @@
+	CR1 &= ~TXEIE;
@@ -105,4 +128 @@
-		if (tp->t_chan)
-			mcstart(tp->t_chan, (caddr_t)&tp->t_outq);
-		else
-			wakeup((caddr_t)&tp->t_outq);
+		wakeup((caddr_t)&tp->t_outq);
@@ -111,2 +131,2 @@
-klrint(dev)
-dev_t dev;
+static void
+klrint(dev_t dev)
@@ -115 +134,0 @@
-	register struct device *addr;
@@ -119,3 +138,2 @@
-	addr = (struct device *)tp->t_addr;
-	c = addr->rbuf;
-	addr->rcsr |= RDRENB;
+	c = RDR;
+	ICR = 017;
@@ -125,3 +143,2 @@
-klioctl(dev, cmd, addr, flag)
-caddr_t addr;
-dev_t dev;
+void
+klioctl(dev_t dev, int cmd, caddr_t addr, int flag)
@@ -129 +146,2 @@
-	if (ttioccom(cmd, &kl11[minor(dev)], addr, dev)==0)
+	(void)flag;
+	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
@@ -133,2 +151,2 @@
-klstart(tp)
-register struct tty *tp;
+void
+klstart(register struct tty *tp)
@@ -136,2 +154 @@
-	register c;
-	register struct device *addr;
+	register int c;
@@ -139,2 +156 @@
-	addr = (struct device *)tp->t_addr;
-	if((addr->tcsr&DONE) == 0)
+	if((ISR&TXE) == 0)
@@ -144 +160 @@
-			addr->tbuf = c;
+			TDR = c;
@@ -146 +162 @@
-			addr->tbuf = c | (partab[c]&0200);
+			TDR = c;
@@ -150,0 +167 @@
+		CR1 |= TXEIE;
@@ -154 +171,9 @@
-char	*msgbufp = msgbuf;	/* Next saved printf character */
+void
+klintr(void)
+{
+	if (ISR&RXNE)
+		klrint(0);
+	if (ISR&TXE && CR1&TXEIE)
+		klxint(0);
+}
+
@@ -166,2 +191,2 @@
-putchar(c)
-register c;
+void
+putchar(register int c)
@@ -169 +194,2 @@
-	register s, timo;
+	register int s;
+	unsigned long long timo;
@@ -176,6 +202 @@
-	/*
-	 *  If last char was a break or null, don't print
-	*/
-	if ((KLADDR->rbuf&0177) == 0)
-		return;
-	timo = 30000;
+	timo = cntvct_get() + cntfrq_get()/HZ;
@@ -186,2 +207,2 @@
-	while((KLADDR->tcsr&0200) == 0)
-		if(--timo == 0)
+	while((ISR&TXE) == 0)
+		if(cntvct_get() >= timo)
@@ -191,3 +212,3 @@
-	s = KLADDR->tcsr;
-	KLADDR->tcsr = 0;
-	KLADDR->tbuf = c;
+	s = CR1;
+	CR1 &= ~TXEIE;
+	TDR = c;
@@ -196,2 +216,0 @@
-		putchar(0177);
-		putchar(0177);
@@ -200 +219 @@
-	KLADDR->tcsr = s;
+	CR1 = s;

% usr/sys/dev/sys.c
@@ -4,0 +5 @@
+#include "../h/systm.h"
@@ -11 +12,2 @@
-syopen(dev, flag)
+void
+syopen(int dev, int flag)
@@ -13,0 +16 @@
+	(void)dev;
@@ -21 +24,2 @@
-syread(dev)
+void
+syread(int dev)
@@ -23,0 +28 @@
+	(void)dev;
@@ -27 +32,2 @@
-sywrite(dev)
+void
+sywrite(int dev)
@@ -29,0 +36 @@
+	(void)dev;
@@ -33,2 +40,2 @@
-sysioctl(dev, cmd, addr, flag)
-caddr_t addr;
+void
+sysioctl(int dev, int cmd, caddr_t addr, int flag)
@@ -36,0 +44 @@
+	(void)dev;

% usr/sys/dev/tty.c
@@ -11 +10,0 @@
-#include "../h/mx.h"
@@ -17 +16,3 @@
-char	partab[];
+extern char	partab[];
+void	wflushtty(struct tty *tp), flushtty(struct tty *tp),
+	ttyblock(struct tty *tp), ttyoutput(int c, struct tty *tp);
@@ -61,3 +62,2 @@
-ttyopen(dev, tp)
-dev_t dev;
-register struct tty *tp;
+void
+ttyopen(dev_t dev, register struct tty *tp)
@@ -84,2 +84,2 @@
-ttychars(tp)
-register struct tty *tp;
+void
+ttychars(register struct tty *tp)
@@ -100,2 +100,2 @@
-ttyclose(tp)
-register struct tty *tp;
+void
+ttyclose(register struct tty *tp)
@@ -112 +112,2 @@
-stty()
+void
+stty(void)
@@ -119 +120,2 @@
-gtty()
+void
+gtty(void)
@@ -131 +133,2 @@
-ioctl()
+void
+ioctl(void)
@@ -141 +144 @@
-	register fmt;
+	register int fmt;
@@ -167,3 +170,2 @@
-ttioccomm(com, tp, addr, dev)
-register struct tty *tp;
-caddr_t addr;
+int
+ttioccomm(int com, register struct tty *tp, caddr_t addr, int dev)
@@ -194 +196 @@
-		if (t >= nldisp) {
+		if (t >= (unsigned)nldisp) {
@@ -199 +201 @@
-			(*linesw[tp->t_line].l_close)(tp);
+			(*linesw[(int)tp->t_line].l_close)(tp);
@@ -201 +203 @@
-			(*linesw[t].l_open)(dev, tp, addr);
+			(*linesw[t].l_open)(dev, tp);
@@ -220,0 +223 @@
+		/* fallthrough */
@@ -263 +266 @@
-		(*linesw[tp->t_line].l_ioctl)(com, tp, addr);
+		(*linesw[(int)tp->t_line].l_ioctl)(com, tp, addr);
@@ -288,2 +291,2 @@
-wflushtty(tp)
-register struct tty *tp;
+void
+wflushtty(register struct tty *tp)
@@ -305,2 +308,2 @@
-flushtty(tp)
-register struct tty *tp;
+void
+flushtty(register struct tty *tp)
@@ -308 +311 @@
-	register s;
+	register int s;
@@ -333,2 +336,2 @@
-canon(tp)
-register struct tty *tp;
+static int
+canon(register struct tty *tp)
@@ -342,2 +345,2 @@
-	while ((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0
-	    || (tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0) {
+	while (((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0)
+	    || ((tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0)) {
@@ -344,0 +348 @@
+			spl0();
@@ -401,3 +405,2 @@
-ttyrend(tp, pb, pe)
-register struct tty *tp;
-register char *pb, *pe;
+void
+ttyrend(register struct tty *tp, register char *pb, register char *pe)
@@ -410,2 +412,0 @@
-		if (tp->t_chan)
-			sdata(tp->t_chan); else
@@ -430,3 +431,2 @@
-ttyinput(c, tp)
-register c;
-register struct tty *tp;
+void
+ttyinput(register int c, register struct tty *tp)
@@ -435 +434,0 @@
-	register struct chan *cp;
@@ -466,3 +464,0 @@
-			if (tp->t_chan)
-				scontrol(tp->t_chan, M_SIG, c);
-			else
@@ -485,3 +481 @@
-		if ((cp=tp->t_chan)!=NULL)
-			sdata(cp); else
-			wakeup((caddr_t)&tp->t_rawq);
+		wakeup((caddr_t)&tp->t_rawq);
@@ -501,2 +495,2 @@
-ttyblock(tp)
-register struct tty *tp;
+void
+ttyblock(register struct tty *tp)
@@ -504 +498 @@
-register x;
+register int x;
@@ -526,3 +520,2 @@
-ttyoutput(c, tp)
-register c;
-register struct tty *tp;
+void
+ttyoutput(register int c, register struct tty *tp)
@@ -531 +524 @@
-	register ctype;
+	register int ctype;
@@ -595,0 +589 @@
+		/* fallthrough */
@@ -658,2 +652,2 @@
-ttrstrt(tp)
-register struct tty *tp;
+void
+ttrstrt(caddr_t arg)
@@ -660,0 +655 @@
+	register struct tty *tp = (struct tty *)arg;
@@ -672,2 +667,2 @@
-ttstart(tp)
-register struct tty *tp;
+void
+ttstart(register struct tty *tp)
@@ -675 +670 @@
-	register s;
+	register int s;
@@ -687,2 +682,2 @@
-ttread(tp)
-register struct tty *tp;
+int
+ttread(register struct tty *tp)
@@ -704,2 +699 @@
-ttwrite(tp)
-register struct tty *tp;
+ttwrite(register struct tty *tp)
@@ -707 +701 @@
-	register c;
+	register int c;

% usr/sys/dev/virtio_blk.c usr/sys/dev/rk.c
@@ -12 +12 @@
-#define	RKADDR	((struct device *)0177400)
+#define	RKADDR(off)	(*(volatile int *)(vbase+(off)))
@@ -14 +14 @@
-#define	NRKBLK	4872
+#define	NRKBLK	RKADDR(0x100)
@@ -25,0 +26 @@
+#define	NVQ	8
@@ -32 +33 @@
-struct	device
+struct	vring
@@ -34,6 +35,14 @@
-	int	rkds;
-	int	rker;
-	int	rkcs;
-	int	rkwc;
-	caddr_t	rkba;
-	int	rkda;
+	struct {
+		int	addr;
+		int	addrhi;
+		int	len;
+		short	flags;
+		short	next;
+	} desc[NVQ];
+	unsigned short	aflags;
+	unsigned short	aidx;
+	unsigned short	aring[NVQ];
+	char	pad[4096-18*NVQ-4];
+	unsigned short	uflags;
+	unsigned short	uidx;
+	int	uring[2*NVQ];
@@ -41,0 +51 @@
+void rkstart(void);
@@ -43,0 +54,10 @@
+volatile struct vring *vq;
+char	vqbuf[sizeof(struct vring)+4095];
+struct {
+	int	type;
+	int	reserved;
+	long long	sector;
+} vreq;
+volatile char	vstatus;
+int	vbase;
+int	rkirq;
@@ -45,2 +65,21 @@
-rkstrategy(bp)
-register struct buf *bp;
+void
+rkinit(void)
+{
+	for(vbase=0x0a000000; vbase<0x0a004000; vbase+=0x200)
+		if(RKADDR(0) == 0x74726976 && RKADDR(8) == 2)
+			break;
+	if(vbase == 0x0a004000)
+		panic("virtio");
+	RKADDR(0x70) = 1;
+	RKADDR(0x70) = 3;
+	RKADDR(0x28) = 4096;
+	RKADDR(0x38) = NVQ;
+	RKADDR(0x3c) = 4096;
+	vq = (struct vring *)(((int)vqbuf+4095) & ~4095);
+	RKADDR(0x40) = (int)vq >> 12;
+	RKADDR(0x70) = 7;
+	rkirq = 48 + (vbase-0x0a000000)/0x200;
+}
+
+void
+rkstrategy(register struct buf *bp)
@@ -68 +107,2 @@
-rkstart()
+void
+rkstart(void)
@@ -71,3 +111 @@
-	register com;
-	daddr_t bn;
-	int dn, cn, sn;
+	register int com;
@@ -78,12 +116,17 @@
-	bn = bp->b_blkno;
-	dn = minor(bp->b_dev);
-	cn = bn/12;
-	sn = bn%12;
-	RKADDR->rkda = (dn<<13) | (cn<<4) | sn;
-	RKADDR->rkba = bp->b_un.b_addr;
-	RKADDR->rkwc = -(bp->b_bcount>>1);
-	com = ((bp->b_xmem&3) << 4) | IENABLE | GO;
-	if(bp->b_flags & B_READ)
-		com |= RCOM; else
-		com |= WCOM;
-	RKADDR->rkcs = com;
+	vreq.type = bp->b_flags&B_READ ? 0 : 1;
+	vreq.sector = bp->b_blkno;
+	vq->desc[0].addr = (int)&vreq;
+	vq->desc[0].len = sizeof(vreq);
+	vq->desc[0].flags = 1;
+	vq->desc[0].next = 1;
+	vq->desc[1].addr = (int)bp->b_un.b_addr;
+	vq->desc[1].len = bp->b_bcount;
+	vq->desc[1].flags = bp->b_flags&B_READ ? 3 : 1;
+	vq->desc[1].next = 2;
+	vq->desc[2].addr = (int)&vstatus;
+	vq->desc[2].len = 1;
+	vq->desc[2].flags = 2;
+	dmbsy();
+	vq->aidx++;
+	dmbsy();
+	RKADDR(0x50) = 0;
@@ -96 +139,2 @@
-rkintr()
+void
+rkintr(void)
@@ -100 +144,2 @@
-	if (rktab.b_active == NULL)
+	RKADDR(0x64) = RKADDR(0x60);
+	if (rktab.b_active == NULL || vq->uidx != vq->aidx)
@@ -101,0 +147 @@
+	dmbsy();
@@ -105,5 +151,2 @@
-	if (RKADDR->rkcs < 0) {		/* error bit */
-		deverror(bp, RKADDR->rker, RKADDR->rkds);
-		RKADDR->rkcs = RESET|GO;
-		while((RKADDR->rkcs&CTLRDY) == 0)
-			;
+	if (vstatus) {
+		deverror(bp, vstatus, 0);
@@ -123,2 +166,2 @@
-rkread(dev)
-dev_t dev;
+void
+rkread(dev_t dev)
@@ -130,2 +173,2 @@
-rkwrite(dev)
-dev_t dev;
+void
+rkwrite(dev_t dev)

% usr/sys/h/acct.h

% usr/sys/h/buf.h

% usr/sys/h/callo.h
@@ -15 +15 @@
-	int	(*c_func)();	/* routine */
+	void	(*c_func)(caddr_t arg);	/* routine */

% usr/sys/h/conf.h
@@ -9,0 +10,2 @@
+struct buf;
+struct tty;
@@ -12,3 +14,3 @@
-	int	(*d_open)();
-	int	(*d_close)();
-	int	(*d_strategy)();
+	void	(*d_open)(dev_t dev, int flag);
+	void	(*d_close)(dev_t dev, int flag);
+	void	(*d_strategy)(struct buf *bp);
@@ -23,6 +25,6 @@
-	int	(*d_open)();
-	int	(*d_close)();
-	int	(*d_read)();
-	int	(*d_write)();
-	int	(*d_ioctl)();
-	int	(*d_stop)();
+	void	(*d_open)(dev_t dev, int flag);
+	void	(*d_close)(dev_t dev, int flag);
+	void	(*d_read)(dev_t dev);
+	void	(*d_write)(dev_t dev);
+	void	(*d_ioctl)(dev_t dev, int cmd, caddr_t addr, int flag);
+	void	(*d_stop)(struct tty *tp);
@@ -37,10 +39,10 @@
-	int	(*l_open)();
-	int	(*l_close)();
-	int	(*l_read)();
-	char	*(*l_write)();
-	int	(*l_ioctl)();
-	int	(*l_rint)();
-	int	(*l_rend)();
-	int	(*l_meta)();
-	int	(*l_start)();
-	int	(*l_modem)();
+	void	(*l_open)(dev_t dev, struct tty *tp);
+	void	(*l_close)(struct tty *tp);
+	int	(*l_read)(struct tty *tp);
+	char	*(*l_write)(struct tty *tp);
+	void	(*l_ioctl)(int cmd, struct tty *tp, caddr_t addr);
+	void	(*l_rint)(int c, struct tty *tp);
+	void	(*l_rend)(struct tty *tp, char *pb, char *pe);
+	int	(*l_meta)(struct tty *tp);
+	void	(*l_start)(struct tty *tp);
+	int	(*l_modem)(struct tty *tp);
@@ -47,0 +50,6 @@
+
+struct intr
+{
+	int	*i_irq;
+	void	(*i_fn)(void);
+};

% usr/sys/h/dir.h

% usr/sys/h/fblk.h

% usr/sys/h/file.h
@@ -11 +11 @@
-	char	f_count;	/* reference count */
+	short	f_count;	/* reference count */

% usr/sys/h/filsys.h

% usr/sys/h/ino.h

% usr/sys/h/inode.h
@@ -29 +29 @@
-	char	i_count;	/* reference count */
+	short	i_count;	/* reference count */
@@ -41 +41 @@
-		};
+		} u_reg;
@@ -45 +45 @@
-		};
+		} u_dev;
@@ -46,0 +47,3 @@
+#define	i_addr	u_reg.i_addr
+#define	i_lastr	u_reg.i_lastr
+#define	i_rdev	u_dev.i_rdev
@@ -51 +54 @@
-struct inode *mpxip;		/* mpx virtual inode */
+extern struct inode *mpxip;		/* mpx virtual inode */

% usr/sys/h/map.h
@@ -3,2 +3,2 @@
-	short	m_size;
-	unsigned short m_addr;
+	int	m_size;
+	int	m_addr;
@@ -7,2 +7,2 @@
-struct map coremap[CMAPSIZ];	/* space for core allocation */
-struct map swapmap[SMAPSIZ];	/* space for swap allocation */
+extern struct map coremap[CMAPSIZ];	/* space for core allocation */
+extern struct map swapmap[SMAPSIZ];	/* space for swap allocation */

% usr/sys/h/mount.h
@@ -6 +6 @@
-struct	mount
+extern struct	mount

% usr/sys/h/param.h
@@ -48 +48 @@
-#define	NSIG	17
+#define	NSIG	32
@@ -50 +50 @@
- * No more than 16 signals (1-16) because they are
+ * No more than 31 signals (1-31) because they are
@@ -83,2 +83,2 @@
-#define	USIZE	16		/* size of user block (*64) */
-#define	UBASE	0140000		/* abs. addr of user block */
+#define	USIZE	128		/* size of user block (*64) */
+#define	UBASE	0x4F000000U	/* abs. addr of user block */
@@ -94 +94 @@
-#define	CBSIZE	14		/* number of chars in a clist block */
+#define	CBSIZE	12		/* number of chars in a clist block */
@@ -131 +131 @@
-typedef	unsigned int	ino_t;
+typedef	unsigned short	ino_t;
@@ -133 +133 @@
-typedef	int		label_t[6];	/* regs 2-7 */
+typedef	int		label_t[10];	/* regs 4-11, sp, lr */
@@ -144,0 +145,2 @@
+
+extern unsigned kernbase, corebase, coretop, pguser, gicdbase, giccbase;

% usr/sys/h/proc.h
@@ -16 +16 @@
-	short	p_sig;		/* signals pending to this process */
+	int	p_sig;		/* signals pending to this process */
@@ -21 +21 @@
-	short	p_addr;		/* address of swappable image */
+	int	p_addr;		/* address of swappable image */
@@ -61 +61 @@
-	short	xp_sig;		/* signals pending to this process */
+	int	xp_sig;		/* signals pending to this process */

% usr/sys/h/reg.h
@@ -7,9 +7,9 @@
-#define	R1	(-2)
-#define	R2	(-9)
-#define	R3	(-8)
-#define	R4	(-7)
-#define	R5	(-6)
-#define	R6	(-3)
-#define	R7	(1)
-#define	PC	(1)
-#define	RPS	(2)
+#define	R1	(1)
+#define	R2	(2)
+#define	R3	(3)
+#define	R4	(4)
+#define	R5	(5)
+#define	R6	(13)
+#define	R7	(15)
+#define	PC	(15)
+#define	RPS	(16)

% usr/sys/h/seg.h
@@ -18 +18 @@
-physadr	ka6;		/* 11/40 KISA6; 11/45 KDSA6 */
+extern physadr	ka6;		/* 11/40 KISA6; 11/45 KDSA6 */
@@ -23,0 +24,10 @@
+#define	USERSIZE	0x100000
+#define	UENTRY_SIGTRAMP	8
+#define	NCLICK	((coretop-corebase)>>6)
+#define	CLKADDR(c)	((char *)(corebase+((unsigned)(c)<<6)))
+#define	SEC_KERN	0x1140e
+#define	SEC_DEV	0x412
+#define	PTE_PT	1
+#define	PGSHIFT	12
+#define	PGSIZE	4096
+struct memregion { unsigned start, end, attr; };

% usr/sys/h/stat.h

% usr/sys/h/systm.h
@@ -6,6 +6,6 @@
-char	canonb[CANBSIZ];	/* buffer for erase and kill (#@) */
-struct inode *rootdir;		/* pointer to inode of root directory */
-struct proc *runq;		/* head of linked list of running processes */
-int	cputype;		/* type of cpu =40, 45, or 70 */
-int	lbolt;			/* time of day in 60th not in time */
-time_t	time;			/* time in sec from 1970 */
+extern	char	canonb[CANBSIZ];	/* buffer for erase and kill (#@) */
+extern	struct inode *rootdir;		/* pointer to inode of root directory */
+extern	struct proc *runq;		/* head of linked list of running processes */
+extern	int	cputype;		/* type of cpu =40, 45, or 70 */
+extern	int	lbolt;			/* time of day in 60th not in time */
+extern	time_t	time;			/* time in sec from 1970 */
@@ -21 +21 @@
-int	nblkdev;
+extern	int	nblkdev;
@@ -27 +27 @@
-int	nchrdev;
+extern	int	nchrdev;
@@ -29,16 +29,17 @@
-int	mpid;			/* generic for unique process id's */
-char	runin;			/* scheduling flag */
-char	runout;			/* scheduling flag */
-char	runrun;			/* scheduling flag */
-char	curpri;			/* more scheduling */
-int	maxmem;			/* actual max memory per process */
-physadr	lks;			/* pointer to clock device */
-daddr_t	swplo;			/* block number of swap space */
-int	nswap;			/* size of swap space */
-int	updlock;		/* lock for sync */
-daddr_t	rablock;		/* block to be read ahead */
-extern	char	regloc[];	/* locs. of saved user registers (trap.c) */
-char	msgbuf[MSGBUFS];	/* saved "printf" characters */
-dev_t	rootdev;		/* device of the root */
-dev_t	swapdev;		/* swapping device */
-dev_t	pipedev;		/* pipe device */
+extern	int	mpid;			/* generic for unique process id's */
+extern	char	runin;			/* scheduling flag */
+extern	char	runout;			/* scheduling flag */
+extern	char	runrun;			/* scheduling flag */
+extern	char	curpri;			/* more scheduling */
+extern	int	maxmem;			/* actual max memory per process */
+extern	physadr	lks;			/* pointer to clock device */
+extern	daddr_t	swplo;			/* block number of swap space */
+extern	int	nswap;			/* size of swap space */
+extern	int	updlock;		/* lock for sync */
+extern	daddr_t	rablock;		/* block to be read ahead */
+extern	char	regloc[];	/* locs. of saved user registers (sysent.c) */
+extern	char	msgbuf[MSGBUFS];	/* saved "printf" characters */
+extern	char	*msgbufp;
+extern	dev_t	rootdev;		/* device of the root */
+extern	dev_t	swapdev;		/* swapping device */
+extern	dev_t	pipedev;		/* pipe device */
@@ -46,0 +48,2 @@
+extern	unsigned long long clkcval;	/* when the clock is next due */
+extern	unsigned clkreload, clkrem, clkfrac;
@@ -48,16 +51,108 @@
-dev_t getmdev();
-daddr_t	bmap();
-struct inode *ialloc();
-struct inode *iget();
-struct inode *owner();
-struct inode *maknode();
-struct inode *namei();
-struct buf *alloc();
-struct buf *getblk();
-struct buf *geteblk();
-struct buf *bread();
-struct buf *breada();
-struct filsys *getfs();
-struct file *getf();
-struct file *falloc();
-int	uchar();
+dev_t getmdev(void);
+daddr_t	bmap(struct inode *ip, daddr_t bn, int rwflg);
+struct inode *ialloc(dev_t dev);
+struct inode *iget(dev_t dev, ino_t ino);
+struct inode *owner(void);
+struct inode *maknode(int mode);
+struct inode *namei(int (*func)(void), int flag);
+struct buf *alloc(dev_t dev);
+struct buf *getblk(dev_t dev, daddr_t blkno);
+struct buf *geteblk(void);
+struct buf *bread(dev_t dev, daddr_t blkno);
+struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
+struct filsys *getfs(dev_t dev);
+struct file *getf(int f);
+struct file *falloc(void);
+int	uchar(void);
+struct clist; struct map; struct text; struct tty; struct uprof;
+void	acct(void), addupc(caddr_t pc, struct uprof *p, int t),
+	alarm(void), arm_sureg(void), arm_sync_icache(void),
+	bawrite(struct buf *bp), bcopy(caddr_t from, caddr_t to, int count),
+	bdinit(void), bdwrite(struct buf *bp), bflush(dev_t dev),
+	brelse(struct buf *bp), bwrite(struct buf *bp), chdir(void),
+	chmod(void), chown(void), chroot(void), cinit(void), clearseg(int a),
+	clkstart(void),
+	clock(caddr_t pc, int ps),
+	clock_ddr_init(void), close(void), closef(struct file *fp),
+	clrbuf(struct buf *bp), cninit(void), cntv_ctl_set(int c),
+	cntv_cval_set(unsigned long long c), copyseg(int from, int to),
+	creat(void),
+	dcflush(caddr_t a, unsigned n), ddrinit(void),
+	deverror(struct buf *bp, int o1, int o2), dmbsy(void), dup(void),
+	exec(void), exece(void), exit(int rv), expand(int newsize), fork(void),
+	free(dev_t dev, daddr_t bno), fstat(void), ftime(void), getgid(void),
+	getpid(void), getuid(void), gtime(void), gtty(void), idle(void),
+	ifree(dev_t dev, ino_t ino), install_sigtramp(void),
+	iodone(struct buf *bp), ioctl(void), iput(struct inode *ip),
+	irq(int *r), itrunc(struct inode *ip),
+	iupdat(struct inode *ip, time_t *ta, time_t *tm), kill(void),
+	klclose(dev_t dev, int flag), klinit(void), klintr(void),
+	klioctl(dev_t dev, int cmd, caddr_t addr, int flag),
+	klopen(dev_t dev, int flag), klread(dev_t dev),
+	klwrite(dev_t dev), link(void), machine_init(void),
+	mapalloc(struct buf *bp), mapfree(struct buf *bp),
+	mfree(struct map *mp, int size, int a), mknod(void), mmread(int dev),
+	mmu_on(unsigned *l1), mmwrite(int dev),
+	ndflush(struct clist *q, int cc), nice(void),
+	nodev(dev_t dev, int flag),
+	nolioctl(int cmd, struct tty *tp, caddr_t addr),
+	noioctl(dev_t dev, int cmd, caddr_t addr, int flag), nordwr(dev_t dev),
+	nostrat(struct buf *bp), nulldev(dev_t dev, int flag),
+	nulltty(struct tty *tp), open(void), openi(struct inode *ip, int rw),
+	panic(char *s), panictrap(void), pause(void),
+	physio(void (*strat)(struct buf *bp), struct buf *bp, int dev, int rw),
+	pipe(void), plock(struct inode *ip), prdev(char *str, dev_t dev),
+	prele(struct inode *ip), profil(void), psig(void),
+	psignal(struct proc *p, int sig), ptrace(void), putchar(int c),
+	qswtch(void), read(void), readi(struct inode *ip),
+	readp(struct file *fp), resume(int a, label_t lab), rexit(void),
+	rkinit(void), rkintr(void), rkread(dev_t dev),
+	rkstrategy(struct buf *bp), rkwrite(dev_t dev), saccess(void),
+	savfp(void *fps), sbreak(void), sched(void), seek(void),
+	sendsig(caddr_t p, int signo),
+	setgid(void), setrun(struct proc *p), setuid(void), sigreturn(void),
+	signal(int pgrp, int sig), sleep(caddr_t chan, int pri), smount(void),
+	spl0(void), spl1(void), splx(int s), ssig(void), startup(void),
+	stat(void), stime(void), stty(void), sumount(void), sureg(void),
+	swap(int blkno, int coreaddr, int count, int rdflg), swtch(void),
+	sync(void), syopen(int dev, int flag), syread(int dev), sysacct(void),
+	sysioctl(int dev, int cmd, caddr_t addr, int flag), syslock(void),
+	sysphys(void), sywrite(int dev),
+	timeout(void (*fun)(caddr_t arg), caddr_t arg, int tim), times(void),
+	trap(int *r), ttrstrt(caddr_t arg), ttstart(struct tty *tp),
+	ttychars(struct tty *tp), ttyclose(struct tty *tp),
+	ttyinput(int c, struct tty *tp), ttyopen(dev_t dev, struct tty *tp),
+	ttyrend(struct tty *tp, char *pb, char *pe), umask(void), unlink(void),
+	update(void), user_trap_handler(int signo, int *r), utime(void),
+	wait(void), wakeup(caddr_t chan), wdir(struct inode *ip), write(void),
+	writei(struct inode *ip), writep(struct file *fp),
+	xalloc(struct inode *ip), xfree(void), xlock(struct text *xp),
+	xrele(struct inode *ip), xswap(struct proc *p, int ff, int os),
+	xumount(int dev), xunlock(struct text *xp);
+int	access(struct inode *ip, int mode),
+	b_to_q(char *cp, int cc, struct clist *q), cntfrq_get(void),
+	copyin(caddr_t f, caddr_t t, unsigned n),
+	copyout(caddr_t f, caddr_t t, unsigned n), cpass(void), dfar(void),
+	dfsr(void),
+	estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw),
+	fsig(struct proc *p), fubyte(caddr_t a), fumem(off_t off),
+	fuword(caddr_t a), getc(struct clist *p), getw(struct clist *p),
+	grow(unsigned sp), issig(void), malloc(struct map *mp, int size),
+	max(unsigned a, unsigned b), min(unsigned a, unsigned b),
+	ndqb(struct clist *q, int flag), newproc(void), passc(int c),
+	putc(int c, struct clist *p), putw(int c, struct clist *p),
+	q_to_b(struct clist *q, char *cp, int cc), save(label_t lab),
+	schar(void), setpri(struct proc *pp), spl5(void), spl6(void),
+	spl7(void), subyte(caddr_t a, int c), sumem(off_t off, int c),
+	suser(void), suword(caddr_t a, int v),
+	ttioccomm(int com, struct tty *tp, caddr_t addr, int dev),
+	ttread(struct tty *tp), ufalloc(void);
+caddr_t	ttwrite(struct tty *tp);
+unsigned long long cntvct_get(void);
+void	printf(char *fmt, ...);
+#define	fuibyte	fubyte
+#define	fuiword	fuword
+#define	suibyte	subyte
+#define	suiword	suword
+#define	copyiin	copyin
+#define	copyiout	copyout
@@ -67,6 +162,6 @@
-int	dk_busy;
-long	dk_time[32];
-long	dk_numb[3];
-long	dk_wds[3];
-long	tk_nin;
-long	tk_nout;
+extern	int	dk_busy;
+extern	long	dk_time[32];
+extern	long	dk_numb[3];
+extern	long	dk_wds[3];
+extern	long	tk_nin;
+extern	long	tk_nout;
@@ -80 +175 @@
-	int	(*sy_call)();		/* handler */
+	void	(*sy_call)(void);	/* handler */

% usr/sys/h/text.h
@@ -10 +10 @@
-	short	x_caddr;	/* core address, if loaded */
+	int	x_caddr;	/* core address, if loaded */

% usr/sys/h/timeb.h

% usr/sys/h/tty.h
@@ -41,2 +41,2 @@
-	int	(* t_oproc)();	/* routine to start output */
-	int	(* t_iproc)();	/* routine to start input */
+	void	(* t_oproc)(struct tty *tp);	/* routine to start output */
+	void	(* t_iproc)(struct tty *tp);	/* routine to start input */
@@ -59 +59 @@
-		struct tc;
+		struct tc tc;
@@ -64 +64 @@
-#define	tun	tp->t_un
+#define	tun	tp->t_un.tc

% usr/sys/h/user.h
@@ -9 +9 @@
- * loc 140000; contains the system
+ * loc 0x4F000000; contains the system
@@ -38 +38 @@
-		};
+		} u_pair;
@@ -41,0 +42,2 @@
+#define	r_val1	u_pair.r_val1
+#define	r_val2	u_pair.r_val2
@@ -67 +69 @@
-	struct {			/* profile arguments */
+	struct uprof {			/* profile arguments */
@@ -80,3 +82 @@
-		unsigned ux_dsize;	/* data size */
-		unsigned ux_bsize;	/* bss size */
-		unsigned ux_ssize;	/* symbol table size */
+		int	ux_x[4];
@@ -84,2 +84,6 @@
-		unsigned ux_unused;
-		unsigned ux_relflg;
+		unsigned ux_phoff;
+		int	ux_y[3];
+		short	ux_phnum, ux_z[3];
+		unsigned ux_type, ux_off, ux_addr, ux_paddr;
+		unsigned ux_dsize;	/* data size */
+		unsigned ux_msize;

% usr/sys/sys/acct.c
@@ -8,0 +9 @@
+int	compress(time_t t);
@@ -14 +15,2 @@
-sysacct()
+void
+sysacct(void)
@@ -51 +53,2 @@
-acct()
+void
+acct(void)
@@ -53 +56 @@
-	register i;
+	register int i;
@@ -60 +63 @@
-	for (i=0; i<sizeof(acctbuf.ac_comm); i++)
+	for (i=0; i<(int)sizeof(acctbuf.ac_comm); i++)
@@ -88,2 +91,2 @@
-compress(t)
-register time_t t;
+int
+compress(register time_t t)
@@ -91 +94 @@
-	register exp = 0, round = 0;
+	register int exp = 0, round = 0;
@@ -113 +116,2 @@
-syslock()
+void
+syslock(void)

% usr/sys/sys/alloc.c
@@ -11,0 +12 @@
+int	badblock(struct filsys *fp, daddr_t bn, dev_t dev);
@@ -26,2 +27 @@
-alloc(dev)
-dev_t dev;
+alloc(dev_t dev)
@@ -78,3 +78,2 @@
-free(dev, bno)
-dev_t dev;
-daddr_t bno;
+void
+free(dev_t dev, daddr_t bno)
@@ -120,4 +119,2 @@
-badblock(fp, bn, dev)
-register struct filsys *fp;
-daddr_t bn;
-dev_t dev;
+int
+badblock(register struct filsys *fp, daddr_t bn, dev_t dev)
@@ -145,2 +142 @@
-ialloc(dev)
-dev_t dev;
+ialloc(dev_t dev)
@@ -223,3 +219,2 @@
-ifree(dev, ino)
-dev_t dev;
-ino_t ino;
+void
+ifree(dev_t dev, ino_t ino)
@@ -257,2 +252 @@
-getfs(dev)
-dev_t dev;
+getfs(dev_t dev)
@@ -286 +280,2 @@
-update()
+void
+update(void)

% usr/sys/sys/clock.c
@@ -28,3 +28,2 @@
-clock(dev, sp, r1, nps, r0, pc, ps)
-dev_t dev;
-caddr_t pc;
+void
+clock(caddr_t pc, int ps)
@@ -41,5 +40,6 @@
-	lks->r[0] = 0115;
-
-	/*
-	 * display register
-	 */
+	clkcval += clkreload;
+	if((clkfrac += clkrem) >= HZ) {
+		clkfrac -= HZ;
+		clkcval++;
+	}
+	cntv_cval_set(clkcval);
@@ -47 +46,0 @@
-	display();
@@ -79 +78 @@
-		while(p2->c_func = p1->c_func) {
+		while((p2->c_func = p1->c_func)) {
@@ -154,3 +153,2 @@
-timeout(fun, arg, tim)
-int (*fun)();
-caddr_t arg;
+void
+timeout(void (*fun)(caddr_t arg), caddr_t arg, int tim)
@@ -184,0 +183,16 @@
+}
+void
+addupc(caddr_t pc, register struct uprof *p, int t)
+{
+	register unsigned i;
+	short c;
+
+	i = (((unsigned long long)(((unsigned)pc-p->pr_off)>>1) * (p->pr_scale>>1) >> 14) + 1) & ~1;
+	if (i >= p->pr_size)
+		return;
+	if (copyin((caddr_t)p->pr_base+i, (caddr_t)&c, 2) < 0) {
+		p->pr_scale = 0;
+		return;
+	}
+	c += t;
+	copyout((caddr_t)&c, (caddr_t)p->pr_base+i, 2);

% usr/sys/sys/fio.c
@@ -20,2 +20 @@
-getf(f)
-register int f;
+getf(register int f)
@@ -45,2 +44,2 @@
-closef(fp)
-register struct file *fp;
+void
+closef(register struct file *fp)
@@ -51,2 +50 @@
-	register int (*cfunc)();
-	struct chan *cp;
+	register void (*cfunc)(dev_t dev, int flag);
@@ -62 +59,0 @@
-	cp = fp->f_un.f_chan;
@@ -94 +91 @@
-	(*cfunc)(dev, flag, cp);
+	(*cfunc)(dev, flag);
@@ -102,2 +99,2 @@
-openi(ip, rw)
-register struct inode *ip;
+void
+openi(register struct inode *ip, int rw)
@@ -114 +111 @@
-		if(maj >= nchrdev)
+		if(maj >= (unsigned)nchrdev)
@@ -121 +118 @@
-		if(maj >= nblkdev)
+		if(maj >= (unsigned)nblkdev)
@@ -144,2 +141,2 @@
-access(ip, mode)
-register struct inode *ip;
+int
+access(register struct inode *ip, int mode)
@@ -147 +144 @@
-	register m;
+	register int m;
@@ -185 +182 @@
-owner()
+owner(void)
@@ -204 +201,2 @@
-suser()
+int
+suser(void)
@@ -218 +216,2 @@
-ufalloc()
+int
+ufalloc(void)
@@ -220 +219 @@
-	register i;
+	register int i;
@@ -242 +241 @@
-falloc()
+falloc(void)
@@ -245 +244 @@
-	register i;
+	register int i;

% usr/sys/sys/iget.c
@@ -10,0 +11,2 @@
+void	iexpand(struct inode *ip, struct dinode *dp),
+	tloop(dev_t dev, daddr_t bn, int f1, int f2);
@@ -30,3 +32 @@
-iget(dev, ino)
-dev_t dev;
-ino_t ino;
+iget(dev_t dev, ino_t ino)
@@ -92,3 +92,2 @@
-iexpand(ip, dp)
-register struct inode *ip;
-register struct dinode *dp;
+void
+iexpand(register struct inode *ip, register struct dinode *dp)
@@ -109 +107,0 @@
-		*p1++ = 0;
@@ -111,0 +110 @@
+		*p1++ = 0;
@@ -122,2 +121,2 @@
-iput(ip)
-register struct inode *ip;
+void
+iput(register struct inode *ip)
@@ -149,3 +148,2 @@
-iupdat(ip, ta, tm)
-register struct inode *ip;
-time_t *ta, *tm;
+void
+iupdat(register struct inode *ip, time_t *ta, time_t *tm)
@@ -177,0 +176,2 @@
+			*p1++ = *p2++;
+			*p1++ = *p2++;
@@ -181,2 +180,0 @@
-			*p1++ = *p2++;
-			*p1++ = *p2++;
@@ -204,2 +202,2 @@
-itrunc(ip)
-register struct inode *ip;
+void
+itrunc(register struct inode *ip)
@@ -207 +205 @@
-	register i;
+	register int i;
@@ -242,3 +240,2 @@
-tloop(dev, bn, f1, f2)
-dev_t dev;
-daddr_t bn;
+void
+tloop(dev_t dev, daddr_t bn, int f1, int f2)
@@ -246 +243 @@
-	register i;
+	register int i;
@@ -280 +277 @@
-maknode(mode)
+maknode(int mode)
@@ -305,2 +302,2 @@
-wdir(ip)
-struct inode *ip;
+void
+wdir(struct inode *ip)

% usr/sys/sys/machdep.c
@@ -11,0 +12 @@
+#include "../h/conf.h"
@@ -14 +15 @@
- * Icode is the octal bootstrap
+ * Icode is the hex bootstrap
@@ -20,11 +21,10 @@
-	0104413,	/* sys exec; init; initp */
-	0000014,
-	0000010,
-	0000777,	/* br . */
-	0000014,	/* initp: init; 0 */
-	0000000,
-	0062457,	/* init: </etc/init\0> */
-	0061564,
-	0064457,
-	0064556,
-	0000164,
+	0xe3a0001c,	/* mov r0, #init */
+	0xe3a01014,	/* mov r1, #initp */
+	0xe3a0700b,	/* mov r7, #exec */
+	0xef000000,	/* svc #0 */
+	0xeafffffe,	/* b . */
+	0x0000001c,	/* initp: init; 0 */
+	0x00000000,
+	0x6374652f,	/* init: </etc/init\0> */
+	0x696e692f,
+	0x00000074,
@@ -37 +37,2 @@
-startup()
+void
+startup(void)
@@ -39 +40 @@
-	register i;
+	register int i;
@@ -45,19 +46,4 @@
-	i = ka6->r[0] + USIZE;
-	UISD->r[0] = 077406;
-	for(;;) {
-		UISA->r[0] = i;
-		if(fuibyte((caddr_t)0) < 0)
-			break;
-		clearseg(i);
-		maxmem++;
-		mfree(coremap, 1, i);
-		i++;
-	}
-	if(cputype == 70)
-	for(i=0; i<62; i+=2) {
-		UBMAP->r[i] = i<<12;
-		UBMAP->r[i+1] = 0;
-	}
-	printf("mem = %D\n", ctob((long)maxmem));
-	if(MAXMEM < maxmem)
-		maxmem = MAXMEM;
+	i = NCLICK - (64+USIZE);
+	mfree(coremap, i, 64+USIZE);
+	maxmem = (USERSIZE>>6) + USIZE;
+	printf("mem = %D\n", ctob((long)i));
@@ -66,7 +52 @@
-
-	/*
-	 * determine clock
-	 */
-
-	UISA->r[7] = ka6->r[1]; /* io segment */
-	UISD->r[7] = 077406;
+	bdinit();
@@ -79 +59,2 @@
-sysphys()
+void
+sysphys(void)
@@ -81,6 +61,0 @@
-	register i, s, d;
-	register struct a {
-		int	segno;
-		int	size;
-		int	phys;
-	} *uap;
@@ -90,28 +64,0 @@
-	uap = (struct a *)u.u_ap;
-	i = uap->segno;
-	if(i < 0 || i >= 8)
-		goto bad;
-	s = uap->size;
-	if(s < 0 || s > 128)
-		goto bad;
-	d = u.u_uisd[i+8];
-	if(d != 0 && (d&ABS) == 0)
-		goto bad;
-	u.u_uisd[i+8] = 0;
-	u.u_uisa[i+8] = 0;
-	if(!u.u_sep) {
-		u.u_uisd[i] = 0;
-		u.u_uisa[i] = 0;
-	}
-	if(s) {
-		u.u_uisd[i+8] = ((s-1)<<8) | RW|ABS;
-		u.u_uisa[i+8] = uap->phys;
-		if(!u.u_sep) {
-			u.u_uisa[i] = u.u_uisa[i+8];
-			u.u_uisd[i] = u.u_uisd[i+8];
-		}
-	}
-	sureg();
-	return;
-
-bad:
@@ -125,11 +72,50 @@
-#define	CLOCK1	((physadr)0177546)
-#define	CLOCK2	((physadr)0172540)
-clkstart()
-{
-	lks = CLOCK1;
-	if(fuiword((caddr_t)lks) == -1) {
-		lks = CLOCK2;
-		if(fuiword((caddr_t)lks) == -1)
-			panic("no clock");
-	}
-	lks->r[0] = 0115;
+#define	GICD(o)	(*(volatile unsigned *)(gicdbase+(o)))
+#define	GICC(o)	(*(volatile unsigned *)(giccbase+(o)))
+#define	TIMER	27
+extern struct intr intrtab[];
+unsigned long long clkcval;
+unsigned	clkreload, clkrem, clkfrac;
+int	irq_ready;
+
+static void
+gicen(int n)
+{
+	*(volatile unsigned char *)(gicdbase+0x400+n) = 0x80;
+	GICD(0x100+(n>>5)*4) = 1U << (n&31);
+}
+
+void
+clkstart(void)
+{
+	register struct intr *ip;
+
+	if((clkreload = cntfrq_get()/HZ) == 0)
+		panic("no clock");
+	clkrem = cntfrq_get()%HZ;
+	gicen(TIMER);
+	for(ip = intrtab; ip->i_irq; ip++)
+		if(*ip->i_irq)
+			gicen(*ip->i_irq);
+	GICD(0) = 1;
+	GICC(4) = 0xff;
+	GICC(0) = 1;
+	cntv_cval_set(clkcval = cntvct_get() + clkreload);
+	cntv_ctl_set(1);
+	irq_ready = 1;
+	spl0();
+}
+
+void
+irq(int *r)
+{
+	register struct intr *ip;
+	register unsigned n;
+
+	n = GICC(0xc);
+	if((n&0x3ff) == TIMER)
+		clock((caddr_t)r[PC], (r[RPS]&0x1f) == 0x10 ? UMODE : 0);
+	else
+		for(ip = intrtab; ip->i_irq; ip++)
+			if(*ip->i_irq == (int)(n&0x3ff))
+				(*ip->i_fn)();
+	GICC(0x10) = n;
@@ -141,2 +127,2 @@
-sendsig(p, signo)
-caddr_t p;
+void
+sendsig(caddr_t p, int signo)
@@ -146,4 +132,6 @@
-	n = u.u_ar0[R6] - 4;
-	grow(n);
-	suword((caddr_t)n+2, u.u_ar0[RPS]);
-	suword((caddr_t)n, u.u_ar0[R7]);
+	n = (u.u_ar0[R6] - (RPS+1)*sizeof(int)) & ~7;
+	if(copyout((caddr_t)u.u_ar0, (caddr_t)n, (RPS+1)*sizeof(int)) < 0) {
+		u.u_signal[SIGSEG] = 0;
+		psignal(u.u_procp, SIGSEG);
+		return;
+	}
@@ -151 +139 @@
-	u.u_ar0[RPS] &= ~TBIT;
+	u.u_ar0[14] = UENTRY_SIGTRAMP;
@@ -152,0 +141 @@
+	u.u_ar0[R0] = signo;
@@ -165,2 +154,2 @@
-mapalloc(bp)
-register struct buf *bp;
+void
+mapalloc(register struct buf *bp)
@@ -168 +157 @@
-	register i, a;
+	register int i, a;
@@ -188,2 +177,2 @@
-mapfree(bp)
-struct buf *bp;
+void
+mapfree(struct buf *bp)
@@ -195,0 +185,204 @@
+}
+
+extern struct memregion board_map[];
+extern char __bss_end[], __ddrbss_start[], __ddrbss_end[];
+extern unsigned l1[], user_l2[], uarea_l2[];
+char	*msgbufp = msgbuf;
+
+void
+machine_init(void)
+{
+	register struct memregion *m;
+	register unsigned a;
+	register char *p;
+
+	cninit();
+	clock_ddr_init();
+	for(p = __ddrbss_start; p < __ddrbss_end; p++)
+		*p = 0;
+	for(m = board_map; m->end != 0; m++)
+		for(a = m->start; a < m->end; a += 0x100000)
+			l1[a>>20] = (a&0xfff00000) | m->attr;
+	l1[0] = (unsigned)user_l2 | PTE_PT;
+	l1[UBASE>>20] = (unsigned)uarea_l2 | PTE_PT;
+	for(a = 0; a < USIZE*64/PGSIZE; a++)
+		uarea_l2[a] = ((unsigned)CLKADDR(64) + a*PGSIZE) | 0x12;
+	for(p = CLKADDR(64); p < CLKADDR(64+USIZE); p++)
+		*p = 0;
+	mmu_on(l1);
+}
+
+void
+arm_sureg(void)
+{
+	register unsigned i, n, base;
+
+	if(u.u_procp == NULL)
+		return;
+	base = (unsigned)CLKADDR(u.u_procp->p_addr + USIZE);
+	n = (u.u_procp->p_size - USIZE) >> (PGSHIFT-6);
+	for(i = 0; i < 256; i++)
+		user_l2[i] = i < n ? (base + i*PGSIZE) | pguser : 0;
+	arm_sync_icache();
+}
+
+void
+copyseg(int from, int to)
+{
+	register int *s, *d, i;
+
+	s = (int *)CLKADDR(from);
+	d = (int *)CLKADDR(to);
+	for(i = 0; i < 16; i++)
+		d[i] = s[i];
+}
+
+void
+clearseg(int a)
+{
+	register int *d, i;
+
+	d = (int *)CLKADDR(a);
+	for(i = 0; i < 16; i++)
+		d[i] = 0;
+}
+
+static int
+uaddr(caddr_t a, unsigned n)
+{
+	return((unsigned)a < USERSIZE && n <= USERSIZE - (unsigned)a);
+}
+
+int
+fubyte(caddr_t a)
+{
+	if(!uaddr(a, 1))
+		return(-1);
+	return(*a & 0377);
+}
+
+int
+subyte(caddr_t a, int c)
+{
+	if(!uaddr(a, 1))
+		return(-1);
+	*a = c;
+	return(0);
+}
+
+int
+fuword(caddr_t a)
+{
+	if(!uaddr(a, sizeof(int)))
+		return(-1);
+	return(*(int *)a);
+}
+
+int
+suword(caddr_t a, int v)
+{
+	if(!uaddr(a, sizeof(int)))
+		return(-1);
+	*(int *)a = v;
+	return(0);
+}
+
+static void
+ucopy(caddr_t f, caddr_t t, unsigned n)
+{
+	register int *fp, *tp;
+
+	if((((unsigned)f|(unsigned)t|n) & (NBPW-1)) != 0) {
+		if(n)
+			bcopy(f, t, n);
+		return;
+	}
+	fp = (int *)f;
+	tp = (int *)t;
+	for(n /= NBPW; n; n--)
+		*tp++ = *fp++;
+}
+
+int
+copyin(caddr_t f, caddr_t t, unsigned n)
+{
+	if(!uaddr(f, n))
+		return(-1);
+	ucopy(f, t, n);
+	return(0);
+}
+
+int
+copyout(caddr_t f, caddr_t t, unsigned n)
+{
+	if(!uaddr(t, n))
+		return(-1);
+	ucopy(f, t, n);
+	return(0);
+}
+
+void
+sigreturn(void)
+{
+	int f[RPS+1];
+	register int i;
+
+	if(copyin((caddr_t)u.u_ar0[R6], (caddr_t)f, sizeof(f)) < 0) {
+		u.u_signal[SIGSEG] = 0;
+		psignal(u.u_procp, SIGSEG);
+		return;
+	}
+	for(i = 0; i < RPS; i++)
+		u.u_ar0[i] = f[i];
+	u.u_ar0[RPS] = (u.u_ar0[RPS] & ~0xf80f0000) | (f[RPS] & 0xf80f0000);
+	u.u_r.r_val1 = f[R0];
+	u.u_r.r_val2 = f[R1];
+}
+
+static char *
+memaddr(off_t off)
+{
+	register unsigned a;
+
+	a = off;
+	if(a < kernbase)
+		a += corebase;
+	if((a >= kernbase && a < (unsigned)__bss_end) ||
+	   (a >= (unsigned)__ddrbss_start && a < (unsigned)__ddrbss_end) ||
+	   (a >= corebase && a < coretop))
+		return((char *)a);
+	return(NULL);
+}
+
+int
+fumem(off_t off)
+{
+	register char *a;
+
+	if((a = memaddr(off)) == NULL)
+		return(-1);
+	return(*a & 0377);
+}
+
+int
+sumem(off_t off, int c)
+{
+	register char *a;
+
+	if((a = memaddr(off)) == NULL)
+		return(-1);
+	*a = c;
+	return(0);
+}
+
+void
+install_sigtramp(void)
+{
+	suword((caddr_t)UENTRY_SIGTRAMP, (int)0xe3a0703fU);	/* mov r7, #63 */
+	suword((caddr_t)UENTRY_SIGTRAMP+4, (int)0xef000000U);	/* svc #0 */
+}
+
+void
+panictrap(void)
+{
+	panic("trap");

% usr/sys/sys/main.c
@@ -12,0 +13,28 @@
+void	iinit(void), binit(void);
+char	canonb[CANBSIZ];
+struct inode *rootdir;
+struct proc *runq;
+int	cputype;
+int	lbolt;
+time_t	time;
+int	nblkdev;
+int	nchrdev;
+int	mpid;
+char	runin;
+char	runout;
+char	runrun;
+char	curpri;
+int	maxmem;
+int	updlock;
+daddr_t	rablock;
+char	msgbuf[MSGBUFS];
+int	dk_busy;
+long	dk_time[32];
+long	dk_numb[3];
+long	dk_wds[3];
+long	tk_nin;
+long	tk_nout;
+struct map coremap[CMAPSIZ];
+struct map swapmap[SMAPSIZ];
+struct mount mount[NMOUNT];
+struct inode *mpxip;
@@ -30 +58,2 @@
-main()
+void
+main(void)
@@ -38 +67 @@
-	proc[0].p_addr = ka6->r[0];
+	proc[0].p_addr = 64;
@@ -70,0 +100 @@
+		arm_sync_icache();
@@ -90 +120,2 @@
-iinit()
+void
+iinit(void)
@@ -119 +150 @@
-char	buffers[NBUF][BSIZE+BSLOP];
+int	buffers[NBUF][(BSIZE+BSLOP+3)/4];
@@ -125 +156,2 @@
-binit()
+void
+binit(void)
@@ -137 +169 @@
-		bp->b_un.b_addr = buffers[i];
+		bp->b_un.b_addr = (caddr_t)buffers[i];

% usr/sys/sys/malloc.c
@@ -15,2 +15,2 @@
-malloc(mp, size)
-struct map *mp;
+int
+malloc(struct map *mp, int size)
@@ -29 +29 @@
-				} while ((bp-1)->m_size = bp->m_size);
+				} while (((bp-1)->m_size = bp->m_size));
@@ -43,3 +43,2 @@
-mfree(mp, size, a)
-struct map *mp;
-register int a;
+void
+mfree(struct map *mp, int size, register int a)
@@ -77 +76 @@
-			} while (size = t);
+			} while ((size = t));

% usr/sys/sys/nami.c
@@ -21,2 +21 @@
-namei(func, flag)
-int (*func)();
+namei(int (*func)(void), int flag)
@@ -25 +24 @@
-	register c;
+	register int c;
@@ -206 +205,2 @@
-schar()
+int
+schar(void)
@@ -216 +216,2 @@
-uchar()
+int
+uchar(void)
@@ -218 +219 @@
-	register c;
+	register int c;

% usr/sys/sys/pipe.c
@@ -25 +25,2 @@
-pipe()
+void
+pipe(void)
@@ -61,2 +62,2 @@
-readp(fp)
-register struct file *fp;
+void
+readp(register struct file *fp)
@@ -116,2 +117,2 @@
-writep(fp)
-register struct file *fp;
+void
+writep(register struct file *fp)
@@ -119 +120 @@
-	register c;
+	register int c;
@@ -189,2 +190,2 @@
-plock(ip)
-register struct inode *ip;
+void
+plock(register struct inode *ip)
@@ -207,2 +208,2 @@
-prele(ip)
-register struct inode *ip;
+void
+prele(register struct inode *ip)

% usr/sys/sys/prf.c
@@ -5,0 +6,2 @@
+#include <stdarg.h>
+void	printn(unsigned long n, int b);
@@ -26,3 +28,2 @@
-printf(fmt, x1)
-register char *fmt;
-unsigned x1;
+void
+printf(char *fmt, ...)
@@ -30,2 +31,2 @@
-	register c;
-	register unsigned int *adx;
+	register int c;
+	va_list adx;
@@ -34 +35 @@
-	adx = &x1;
+	va_start(adx, fmt);
@@ -37 +38,2 @@
-		if(c == '\0')
+		if(c == '\0') {
+			va_end(adx);
@@ -38,0 +41 @@
+		}
@@ -43 +46 @@
-		printn((long)*adx, c=='o'? 8: (c=='x'? 16:10));
+		printn(va_arg(adx, unsigned), c=='o'? 8: (c=='x'? 16:10));
@@ -45,2 +48,2 @@
-		s = (char *)*adx;
-		while(c = *s++)
+		s = va_arg(adx, char *);
+		while((c = *s++))
@@ -49,2 +52 @@
-		printn(*(long *)adx, 10);
-		adx += (sizeof(long) / sizeof(int)) - 1;
+		printn(va_arg(adx, long), 10);
@@ -52 +53,0 @@
-	adx++;
@@ -59,2 +60,2 @@
-printn(n, b)
-long n;
+void
+printn(unsigned long n, int b)
@@ -64,5 +65 @@
-	if (n<0) {	/* shouldn't happen */
-		putchar('-');
-		n = -n;
-	}
-	if(a = n/b)
+	if((a = n/b))
@@ -79,2 +76,2 @@
-panic(s)
-char *s;
+void
+panic(char *s)
@@ -95,3 +92,2 @@
-prdev(str, dev)
-char *str;
-dev_t dev;
+void
+prdev(char *str, dev_t dev)
@@ -110,2 +106,2 @@
-deverror(bp, o1, o2)
-register struct buf *bp;
+void
+deverror(register struct buf *bp, int o1, int o2)

% usr/sys/sys/prim.c
@@ -19,2 +19,2 @@
-getc(p)
-register struct clist *p;
+int
+getc(register struct clist *p)
@@ -55,3 +55,2 @@
-q_to_b(q, cp, cc)
-register struct clist *q;
-register char *cp;
+int
+q_to_b(register struct clist *q, register char *cp, int cc)
@@ -102,2 +101,2 @@
-ndqb(q, flag)
-register struct clist *q;
+int
+ndqb(register struct clist *q, int flag)
@@ -105 +104 @@
-register cc;
+register int cc;
@@ -143,3 +142,2 @@
-ndflush(q, cc)
-register struct clist *q;
-register cc;
+void
+ndflush(register struct clist *q, register int cc)
@@ -147 +145 @@
-register s;
+register int s;
@@ -191,2 +189,2 @@
-putc(c, p)
-register struct clist *p;
+int
+putc(int c, register struct clist *p)
@@ -196 +194 @@
-	register s;
+	register int s;
@@ -231,4 +229,2 @@
-b_to_q(cp, cc, q)
-register char *cp;
-struct clist *q;
-register int cc;
+int
+b_to_q(register char *cp, register int cc, struct clist *q)
@@ -238 +234 @@
-	register s, acc;
+	register int s, acc;
@@ -278 +274,2 @@
-cinit()
+void
+cinit(void)
@@ -301,2 +298,2 @@
-getw(p)
-register struct clist *p;
+int
+getw(register struct clist *p)
@@ -312,2 +309,2 @@
-putw(c, p)
-register struct clist *p;
+int
+putw(int c, register struct clist *p)
@@ -315 +312 @@
-	register s;
+	register int s;

% usr/sys/sys/rdwri.c
@@ -7,0 +8 @@
+void	iomove(caddr_t cp, int n, int flag);
@@ -19,2 +20,2 @@
-readi(ip)
-register struct inode *ip;
+void
+readi(register struct inode *ip)
@@ -26,2 +27,2 @@
-	register on, n;
-	register type;
+	register int on, n;
+	register int type;
@@ -39 +40,2 @@
-		return((*cdevsw[major(dev)].d_read)(dev));
+		(*cdevsw[major(dev)].d_read)(dev);
+		return;
@@ -83,2 +85,2 @@
-writei(ip)
-register struct inode *ip;
+void
+writei(register struct inode *ip)
@@ -89,2 +91,2 @@
-	register n, on;
-	register type;
+	register int n, on;
+	register int type;
@@ -136,2 +138,2 @@
-max(a, b)
-unsigned a, b;
+int
+max(unsigned a, unsigned b)
@@ -149,2 +151,2 @@
-min(a, b)
-unsigned a, b;
+int
+min(unsigned a, unsigned b)
@@ -173,3 +175,2 @@
-iomove(cp, n, flag)
-register caddr_t cp;
-register n;
+void
+iomove(register caddr_t cp, register int n, int flag)
@@ -177 +178 @@
-	register t;
+	register int t;

% usr/sys/sys/sig.c
@@ -9,0 +10 @@
+int	core(void), procxmt(void);
@@ -39,2 +40,2 @@
-signal(pgrp, sig)
-register pgrp;
+void
+signal(register int pgrp, int sig)
@@ -55,3 +56,2 @@
-psignal(p, sig)
-register struct proc *p;
-register sig;
+void
+psignal(register struct proc *p, register int sig)
@@ -81 +81,2 @@
-issig()
+int
+issig(void)
@@ -83 +84 @@
-	register n;
+	register int n;
@@ -102 +103,2 @@
-stop()
+static void
+stop(void)
@@ -128 +130,2 @@
-psig()
+void
+psig(void)
@@ -130 +133 @@
-	register n, p;
+	register int n, p;
@@ -172,2 +175,2 @@
-fsig(p)
-struct proc *p;
+int
+fsig(struct proc *p)
@@ -175 +178 @@
-	register n, i;
+	register int n, i;
@@ -196 +199,2 @@
-core()
+int
+core(void)
@@ -200 +203,0 @@
-	extern schar();
@@ -237,2 +240,2 @@
-grow(sp)
-unsigned sp;
+int
+grow(unsigned sp)
@@ -240 +243 @@
-	register si, i;
+	register int si, i;
@@ -242 +245 @@
-	register a;
+	register int a;
@@ -267 +270,2 @@
-ptrace()
+void
+ptrace(void)
@@ -313 +317,2 @@
-procxmt()
+int
+procxmt(void)
@@ -316 +321 @@
-	register *p;
+	register int *p;
@@ -345 +350 @@
-		ipc.ip_data = ((physadr)&u)->r[i>>1];
+		ipc.ip_data = ((physadr)&u)->r[i>>2];
@@ -354 +359 @@
-		if (xp = u.u_procp->p_textp) {
+		if ((xp = u.u_procp->p_textp)) {
@@ -379 +384 @@
-		p = (int *)&((physadr)&u)->r[i>>1];
+		p = (int *)&((physadr)&u)->r[i>>2];
@@ -383 +388 @@
-			if (p == &u.u_ar0[regloc[i]])
+			if (p == &u.u_ar0[regloc[i]&0377])
@@ -386 +391 @@
-			ipc.ip_data |= 0170000;	/* assure user space */
+			ipc.ip_data = (ipc.ip_data&0xf80f0000) | 020;	/* assure user space */
@@ -397,3 +401,0 @@
-	/*  one version causes a trace-trap */
-	case 9:
-		u.u_ar0[RPS] |= TBIT;
@@ -410,0 +413 @@
+		return(1);

% usr/sys/sys/slp.c
@@ -10,0 +11 @@
+int	swapin(struct proc *p);
@@ -27,2 +28,2 @@
-sleep(chan, pri)
-caddr_t chan;
+void
+sleep(caddr_t chan, int pri)
@@ -31 +32 @@
-	register s, h;
+	register int s, h;
@@ -82,2 +83,2 @@
-wakeup(chan)
-register caddr_t chan;
+void
+wakeup(register caddr_t chan)
@@ -86 +87 @@
-	register i;
+	register int i;
@@ -118,2 +119,2 @@
-setrq(p)
-struct proc *p;
+static void
+setrq(struct proc *p)
@@ -122 +123 @@
-	register s;
+	register int s;
@@ -140,2 +141,2 @@
-setrun(p)
-register struct proc *p;
+void
+setrun(register struct proc *p)
@@ -151 +152 @@
-	if (w = p->p_wchan) {
+	if ((w = p->p_wchan)) {
@@ -171,2 +172,2 @@
-setpri(pp)
-register struct proc *pp;
+int
+setpri(register struct proc *pp)
@@ -174 +175 @@
-	register p;
+	register int p;
@@ -202 +203,2 @@
-sched()
+void
+sched(void)
@@ -205 +207 @@
-	register outage, inage;
+	register int outage, inage;
@@ -257 +259 @@
-		if (rp->p_stat==SSLEEP&&rp->p_pri>=PZERO || rp->p_stat==SSTOP) {
+		if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) || rp->p_stat==SSTOP) {
@@ -292,2 +294,2 @@
-swapin(p)
-register struct proc *p;
+int
+swapin(register struct proc *p)
@@ -301 +303 @@
-	if (xp = p->p_textp) {
+	if ((xp = p->p_textp)) {
@@ -329 +331,2 @@
-qswtch()
+void
+qswtch(void)
@@ -347 +350,2 @@
-swtch()
+void
+swtch(void)
@@ -349 +353 @@
-	register n;
+	register int n;
@@ -426 +430,2 @@
-newproc()
+int
+newproc(void)
@@ -431 +436 @@
-	register n;
+	register int n;
@@ -545 +550,2 @@
-expand(newsize)
+void
+expand(int newsize)
@@ -547 +553 @@
-	register i, n;
+	register int i, n;
@@ -549 +555 @@
-	register a1, a2;
+	register int a1, a2;
@@ -550,0 +557 @@
+	newsize = (newsize + 63) & ~63;

% usr/sys/sys/subr.c
@@ -18,3 +18 @@
-bmap(ip, bn, rwflg)
-register struct inode *ip;
-daddr_t bn;
+bmap(register struct inode *ip, daddr_t bn, int rwflg)
@@ -22 +20 @@
-	register i;
+	register int i;
@@ -117 +115 @@
-	if(i < NINDIR-1)
+	if((unsigned)i < NINDIR-1)
@@ -128,2 +126,2 @@
-passc(c)
-register c;
+int
+passc(register int c)
@@ -131 +129 @@
-	register id;
+	register int id;
@@ -153 +151,2 @@
-cpass()
+int
+cpass(void)
@@ -155 +154 @@
-	register c, id;
+	register int c, id;
@@ -176 +175,2 @@
-nodev()
+void
+nodev(dev_t dev, int flag)
@@ -178,0 +179 @@
+	(void)dev; (void)flag;
@@ -186 +187,2 @@
-nulldev()
+void
+nulldev(dev_t dev, int flag)
@@ -187,0 +190,39 @@
+	(void)dev; (void)flag;
+}
+
+void
+nostrat(struct buf *bp)
+{
+
+	(void)bp;
+	u.u_error = ENODEV;
+}
+
+void
+nordwr(dev_t dev)
+{
+
+	(void)dev;
+	u.u_error = ENODEV;
+}
+
+void
+noioctl(dev_t dev, int cmd, caddr_t addr, int flag)
+{
+
+	(void)dev; (void)cmd; (void)addr; (void)flag;
+	u.u_error = ENODEV;
+}
+
+void
+nolioctl(int cmd, struct tty *tp, caddr_t addr)
+{
+
+	(void)cmd; (void)tp; (void)addr;
+	u.u_error = ENODEV;
+}
+
+void
+nulltty(struct tty *tp)
+{
+	(void)tp;
@@ -193,3 +234,2 @@
-bcopy(from, to, count)
-caddr_t from, to;
-register count;
+void
+bcopy(caddr_t from, caddr_t to, register int count)

% usr/sys/sys/sys1.c
@@ -11,0 +12,2 @@
+int	getxfile(struct inode *ip, int nargc);
+void	setregs(void);
@@ -22 +24,2 @@
-exec()
+void
+exec(void)
@@ -28 +31,2 @@
-exece()
+void
+exece(void)
@@ -30,2 +34,2 @@
-	register nc;
-	register char *cp;
+	register int nc;
+	register char *cp = NULL;
@@ -103,2 +107,2 @@
-	ucp = -nc - NBPW;
-	ap = ucp - na*NBPW - 3*NBPW;
+	ucp = USERSIZE - nc - NBPW;
+	ap = (ucp - na*NBPW - 3*NBPW) & ~7;
@@ -144,2 +148,2 @@
-getxfile(ip, nargc)
-register struct inode *ip;
+int
+getxfile(register struct inode *ip, int nargc)
@@ -148 +152 @@
-	register sep;
+	register int sep;
@@ -150 +154 @@
-	register i, overlay;
+	register int i, overlay;
@@ -178,13 +182,11 @@
-	if(u.u_exdata.ux_mag == 0407) {
-		lsize = (long)u.u_exdata.ux_dsize + u.u_exdata.ux_tsize;
-		u.u_exdata.ux_dsize = lsize;
-		if (lsize != u.u_exdata.ux_dsize) {	/* check overflow */
-			u.u_error = ENOMEM;
-			goto bad;
-		}
-		u.u_exdata.ux_tsize = 0;
-	} else if (u.u_exdata.ux_mag == 0411)
-		sep++;
-	else if (u.u_exdata.ux_mag == 0405)
-		overlay++;
-	else if (u.u_exdata.ux_mag != 0410) {
+	for(i = 0; u.u_exdata.ux_mag == 0x464c457f && i < u.u_exdata.ux_phnum; i++) {
+		u.u_base = (caddr_t)&u.u_exdata.ux_type;
+		u.u_count = 24;
+		u.u_offset = u.u_exdata.ux_phoff + 32*i;
+		u.u_segflg = 1;
+		readi(ip);
+		u.u_segflg = 0;
+		if(u.u_exdata.ux_type == 1)
+			break;
+	}
+	if(u.u_exdata.ux_mag != 0x464c457f || i == u.u_exdata.ux_phnum) {
@@ -193,0 +196 @@
+	u.u_exdata.ux_tsize = 0;
@@ -205,2 +208,2 @@
-	lsize = (long)u.u_exdata.ux_dsize + u.u_exdata.ux_bsize;
-	if (lsize != (unsigned)lsize) {
+	lsize = (long)u.u_exdata.ux_addr + u.u_exdata.ux_msize;
+	if ((unsigned)lsize < u.u_exdata.ux_msize) {
@@ -213 +216 @@
-		if (u.u_sep==0 && ctos(ts) != ctos(u.u_tsize) || nargc) {
+		if ((u.u_sep==0 && ctos(ts) != ctos(u.u_tsize)) || nargc) {
@@ -235 +238 @@
-		i = USIZE+ds+ss;
+		i = USIZE+(USERSIZE>>6);
@@ -246,2 +249,2 @@
-		u.u_base = 0;
-		u.u_offset = sizeof(u.u_exdata)+u.u_exdata.ux_tsize;
+		u.u_base = (caddr_t)u.u_exdata.ux_addr;
+		u.u_offset = u.u_exdata.ux_off;
@@ -268,0 +272,2 @@
+	install_sigtramp();
+	arm_sync_icache();
@@ -276 +281,2 @@
-setregs()
+void
+setregs(void)
@@ -279,2 +285 @@
-	register char *cp;
-	register i;
+	register int i;
@@ -285,2 +290,4 @@
-	for(cp = &regloc[0]; cp < &regloc[6];)
-		u.u_ar0[*cp++] = 0;
+	for(i = 0; i < PC; i++)
+		if(i != R6)
+			u.u_ar0[i] = 0;
+	u.u_r.r_val2 = 0;
@@ -308 +315,2 @@
-rexit()
+void
+rexit(void)
@@ -325 +333,2 @@
-exit(rv)
+void
+exit(int rv)
@@ -377 +386,2 @@
-wait()
+void
+wait(void)
@@ -379 +389 @@
-	register f;
+	register int f;
@@ -422 +432,2 @@
-fork()
+void
+fork(void)
@@ -425 +436 @@
-	register a;
+	register int a;
@@ -477 +488,2 @@
-sbreak()
+void
+sbreak(void)
@@ -482,2 +494 @@
-	register a, n, d;
-	int i;
+	register int n, d;
@@ -501,22 +511,0 @@
-	if(d > 0)
-		goto bigger;
-	a = u.u_procp->p_addr + n - u.u_ssize;
-	i = n;
-	n = u.u_ssize;
-	while(n--) {
-		copyseg(a-d, a);
-		a++;
-	}
-	expand(i);
-	return;
-
-bigger:
-	expand(n);
-	a = u.u_procp->p_addr + n;
-	n = u.u_ssize;
-	while(n--) {
-		a--;
-		copyseg(a-d, a);
-	}
-	while(d--)
-		clearseg(--a);

% usr/sys/sys/sys2.c
@@ -7,0 +8 @@
+void	rdwr(int mode), open1(struct inode *ip, int mode, int trf);
@@ -12 +13,2 @@
-read()
+void
+read(void)
@@ -20 +22,2 @@
-write()
+void
+write(void)
@@ -30,2 +33,2 @@
-rdwr(mode)
-register mode;
+void
+rdwr(register int mode)
@@ -80 +83,2 @@
-open()
+void
+open(void)
@@ -98 +102,2 @@
-creat()
+void
+creat(void)
@@ -124,3 +129,2 @@
-open1(ip, mode, trf)
-register struct inode *ip;
-register mode;
+void
+open1(register struct inode *ip, register int mode, int trf)
@@ -163 +167,2 @@
-close()
+void
+close(void)
@@ -181 +186,2 @@
-seek()
+void
+seek(void)
@@ -209 +215,2 @@
-link()
+void
+link(void)
@@ -259 +266,2 @@
-mknod()
+void
+mknod(void)
@@ -290 +298,2 @@
-saccess()
+void
+saccess(void)
@@ -292 +301 @@
-	register svuid, svgid;
+	register int svuid, svgid;

% usr/sys/sys/sys3.c
@@ -13,0 +14 @@
+void	stat1(struct inode *ip, struct stat *ub, off_t pipeadj);
@@ -18 +19,2 @@
-fstat()
+void
+fstat(void)
@@ -36 +38,2 @@
-stat()
+void
+stat(void)
@@ -56,4 +59,2 @@
-stat1(ip, ub, pipeadj)
-register struct inode *ip;
-struct stat *ub;
-off_t pipeadj;
+void
+stat1(register struct inode *ip, struct stat *ub, off_t pipeadj)
@@ -94 +95,2 @@
-dup()
+void
+dup(void)
@@ -101 +103 @@
-	register i, m;
+	register int i, m;
@@ -131 +133,2 @@
-smount()
+void
+smount(void)
@@ -197 +200,2 @@
-sumount()
+void
+sumount(void)
@@ -203 +207 @@
-	register struct a {
+	struct a {
@@ -240 +244 @@
-getmdev()
+getmdev(void)

% usr/sys/sys/sys4.c
@@ -8,0 +9 @@
+void	chdirec(struct inode **ipp);
@@ -17 +18,2 @@
-gtime()
+void
+gtime(void)
@@ -26 +28,2 @@
-ftime()
+void
+ftime(void)
@@ -53 +56,2 @@
-stime()
+void
+stime(void)
@@ -64 +68,2 @@
-setuid()
+void
+setuid(void)
@@ -66 +71 @@
-	register uid;
+	register int uid;
@@ -80 +85,2 @@
-getuid()
+void
+getuid(void)
@@ -87 +93,2 @@
-setgid()
+void
+setgid(void)
@@ -89 +96 @@
-	register gid;
+	register int gid;
@@ -102 +109,2 @@
-getgid()
+void
+getgid(void)
@@ -109 +117,2 @@
-getpid()
+void
+getpid(void)
@@ -115 +124,2 @@
-sync()
+void
+sync(void)
@@ -121 +131,2 @@
-nice()
+void
+nice(void)
@@ -123 +134 @@
-	register n;
+	register int n;
@@ -145 +156,2 @@
-unlink()
+void
+unlink(void)
@@ -194 +206,2 @@
-chdir()
+void
+chdir(void)
@@ -199 +212,2 @@
-chroot()
+void
+chroot(void)
@@ -205,2 +219,2 @@
-chdirec(ipp)
-register struct inode **ipp;
+void
+chdirec(register struct inode **ipp)
@@ -234 +248,2 @@
-chmod()
+void
+chmod(void)
@@ -255 +270,2 @@
-chown()
+void
+chown(void)
@@ -273 +289,2 @@
-ssig()
+void
+ssig(void)
@@ -275 +292 @@
-	register a;
+	register int a;
@@ -292 +309,2 @@
-kill()
+void
+kill(void)
@@ -295 +313 @@
-	register a;
+	register int a;
@@ -327 +345,2 @@
-times()
+void
+times(void)
@@ -338 +357,2 @@
-profil()
+void
+profil(void)
@@ -357 +377,2 @@
-alarm()
+void
+alarm(void)
@@ -360 +381 @@
-	register c;
+	register int c;
@@ -376 +397,2 @@
-pause()
+void
+pause(void)
@@ -386 +408,2 @@
-umask()
+void
+umask(void)
@@ -391 +414 @@
-	register t;
+	register int t;
@@ -403 +426,2 @@
-utime()
+void
+utime(void)

% usr/sys/sys/sysent.c
@@ -2,0 +3,6 @@
+#include "../h/dir.h"
+#include "../h/user.h"
+#include "../h/reg.h"
+#define	EBIT	0x20000000	/* user error bit in PS: C-bit */
+static void nullsys(void) { }
+static void nosys(void) { u.u_error = EINVAL; }
@@ -10,54 +15,0 @@
-int	alarm();
-int	mpxchan();
-int	chdir();
-int	chmod();
-int	chown();
-int	chroot();
-int	close();
-int	creat();
-int	dup();
-int	exec();
-int	exece();
-int	fork();
-int	fstat();
-int	getgid();
-int	getpid();
-int	getuid();
-int	gtime();
-int	gtty();
-int	ioctl();
-int	kill();
-int	link();
-int	mknod();
-int	nice();
-int	nosys();
-int	nullsys();
-int	open();
-int	pause();
-int	pipe();
-int	profil();
-int	ptrace();
-int	read();
-int	rexit();
-int	saccess();
-int	sbreak();
-int	seek();
-int	setgid();
-int	setuid();
-int	smount();
-int	ssig();
-int	stat();
-int	stime();
-int	stty();
-int	sumount();
-int	ftime();
-int	sync();
-int	sysacct();
-int	syslock();
-int	sysphys();
-int	times();
-int	umask();
-int	unlink();
-int	utime();
-int	wait();
-int	write();
@@ -67,64 +19,64 @@
-	0, 0, nullsys,			/*  0 = indir */
-	1, 1, rexit,			/*  1 = exit */
-	0, 0, fork,			/*  2 = fork */
-	3, 1, read,			/*  3 = read */
-	3, 1, write,			/*  4 = write */
-	2, 0, open,			/*  5 = open */
-	1, 1, close,			/*  6 = close */
-	0, 0, wait,			/*  7 = wait */
-	2, 0, creat,			/*  8 = creat */
-	2, 0, link,			/*  9 = link */
-	1, 0, unlink,			/* 10 = unlink */
-	2, 0, exec,			/* 11 = exec */
-	1, 0, chdir,			/* 12 = chdir */
-	0, 0, gtime,			/* 13 = time */
-	3, 0, mknod,			/* 14 = mknod */
-	2, 0, chmod,			/* 15 = chmod */
-	3, 0, chown,			/* 16 = chown; now 3 args */
-	1, 0, sbreak,			/* 17 = break */
-	2, 0, stat,			/* 18 = stat */
-	4, 1, seek,			/* 19 = seek; now 3 args */
-	0, 0, getpid,			/* 20 = getpid */
-	3, 0, smount,			/* 21 = mount */
-	1, 0, sumount,			/* 22 = umount */
-	1, 1, setuid,			/* 23 = setuid */
-	0, 0, getuid,			/* 24 = getuid */
-	2, 2, stime,			/* 25 = stime */
-	4, 1, ptrace,			/* 26 = ptrace */
-	1, 1, alarm,			/* 27 = alarm */
-	2, 1, fstat,			/* 28 = fstat */
-	0, 0, pause,			/* 29 = pause */
-	2, 0, utime,			/* 30 = utime */
-	2, 1, stty,			/* 31 = stty */
-	2, 1, gtty,			/* 32 = gtty */
-	2, 0, saccess,			/* 33 = access */
-	1, 1, nice,			/* 34 = nice */
-	1, 0, ftime,			/* 35 = ftime; formerly sleep */
-	0, 0, sync,			/* 36 = sync */
-	2, 1, kill,			/* 37 = kill */
-	0, 0, nullsys,			/* 38 = switch; inoperative */
-	0, 0, nullsys,			/* 39 = setpgrp (not in yet) */
-	1, 1, nosys,			/* 40 = tell (obsolete) */
-	2, 2, dup,			/* 41 = dup */
-	0, 0, pipe,			/* 42 = pipe */
-	1, 0, times,			/* 43 = times */
-	4, 0, profil,			/* 44 = prof */
-	0, 0, nosys,			/* 45 = unused */
-	1, 1, setgid,			/* 46 = setgid */
-	0, 0, getgid,			/* 47 = getgid */
-	2, 0, ssig,			/* 48 = sig */
-	0, 0, nosys,			/* 49 = reserved for USG */
-	0, 0, nosys,			/* 50 = reserved for USG */
-	1, 0, sysacct,			/* 51 = turn acct off/on */
-	3, 0, sysphys,			/* 52 = set user physical addresses */
-	1, 0, syslock,			/* 53 = lock user in core */
-	3, 0, ioctl,			/* 54 = ioctl */
-	0, 0, nosys,			/* 55 = readwrite (in abeyance) */
-	4, 0, mpxchan,			/* 56 = creat mpx comm channel */
-	0, 0, nosys,			/* 57 = reserved for USG */
-	0, 0, nosys,			/* 58 = reserved for USG */
-	3, 0, exece,			/* 59 = exece */
-	1, 0, umask,			/* 60 = umask */
-	1, 0, chroot,			/* 61 = chroot */
-	0, 0, nosys,			/* 62 = x */
-	0, 0, nosys			/* 63 = used internally */
+	{0, 0, nullsys},		/*  0 = indir */
+	{1, 1, rexit},			/*  1 = exit */
+	{0, 0, fork},			/*  2 = fork */
+	{3, 3, read},			/*  3 = read */
+	{3, 3, write},			/*  4 = write */
+	{2, 2, open},			/*  5 = open */
+	{1, 1, close},			/*  6 = close */
+	{0, 0, wait},			/*  7 = wait */
+	{2, 2, creat},			/*  8 = creat */
+	{2, 2, link},			/*  9 = link */
+	{1, 1, unlink},			/* 10 = unlink */
+	{2, 2, exec},			/* 11 = exec */
+	{1, 1, chdir},			/* 12 = chdir */
+	{0, 0, gtime},			/* 13 = time */
+	{3, 3, mknod},			/* 14 = mknod */
+	{2, 2, chmod},			/* 15 = chmod */
+	{3, 3, chown},			/* 16 = chown; now 3 args */
+	{1, 1, sbreak},			/* 17 = break */
+	{2, 2, stat},			/* 18 = stat */
+	{3, 3, seek},			/* 19 = seek; now 3 args */
+	{0, 0, getpid},			/* 20 = getpid */
+	{3, 3, smount},			/* 21 = mount */
+	{1, 1, sumount},		/* 22 = umount */
+	{1, 1, setuid},			/* 23 = setuid */
+	{0, 0, getuid},			/* 24 = getuid */
+	{1, 1, stime},			/* 25 = stime */
+	{4, 4, ptrace},			/* 26 = ptrace */
+	{1, 1, alarm},			/* 27 = alarm */
+	{2, 2, fstat},			/* 28 = fstat */
+	{0, 0, pause},			/* 29 = pause */
+	{2, 2, utime},			/* 30 = utime */
+	{2, 2, stty},			/* 31 = stty */
+	{2, 2, gtty},			/* 32 = gtty */
+	{2, 2, saccess},		/* 33 = access */
+	{1, 1, nice},			/* 34 = nice */
+	{1, 1, ftime},			/* 35 = ftime; formerly sleep */
+	{0, 0, sync},			/* 36 = sync */
+	{2, 2, kill},			/* 37 = kill */
+	{0, 0, nullsys},		/* 38 = switch; inoperative */
+	{0, 0, nullsys},		/* 39 = setpgrp (not in yet) */
+	{0, 0, nosys},			/* 40 = tell (obsolete) */
+	{2, 2, dup},			/* 41 = dup */
+	{0, 0, pipe},			/* 42 = pipe */
+	{1, 1, times},			/* 43 = times */
+	{4, 4, profil},			/* 44 = prof */
+	{0, 0, nosys},			/* 45 = unused */
+	{1, 1, setgid},			/* 46 = setgid */
+	{0, 0, getgid},			/* 47 = getgid */
+	{2, 2, ssig},			/* 48 = sig */
+	{0, 0, nosys},			/* 49 = reserved for USG */
+	{0, 0, nosys},			/* 50 = reserved for USG */
+	{1, 1, sysacct},		/* 51 = turn acct off/on */
+	{3, 3, sysphys},		/* 52 = set user physical addresses */
+	{1, 1, syslock},		/* 53 = lock user in core */
+	{3, 3, ioctl},			/* 54 = ioctl */
+	{0, 0, nosys},			/* 55 = readwrite (in abeyance) */
+	{0, 0, nosys},			/* 56 = creat mpx comm channel */
+	{0, 0, nosys},			/* 57 = reserved for USG */
+	{0, 0, nosys},			/* 58 = reserved for USG */
+	{3, 3, exece},			/* 59 = exece */
+	{1, 1, umask},			/* 60 = umask */
+	{1, 1, chroot},			/* 61 = chroot */
+	{0, 0, nosys},			/* 62 = x */
+	{0, 0, sigreturn}		/* 63 = sigreturn */
@@ -131,0 +84,58 @@
+char	regloc[9] = { R0, R1, R2, R3, R4, R5, R6, R7, RPS };
+void
+trap(int *r)
+{
+	register int i;
+	register struct sysent *callp;
+	time_t syst;
+
+	syst = u.u_stime;
+	u.u_fpsaved = 0;
+	u.u_ar0 = r;
+	u.u_error = 0;
+	r[RPS] &= ~EBIT;
+	callp = &sysent[r[7] & 077];
+	for(i = 0; i < callp->sy_narg; i++)
+		u.u_arg[i] = r[i];
+	u.u_dirp = (caddr_t)u.u_arg[0];
+	u.u_r.r_val1 = 0;
+	u.u_r.r_val2 = r[R1];
+	u.u_ap = u.u_arg;
+	if (save(u.u_qsav)) {
+		if (u.u_error == 0)
+			u.u_error = EINTR;
+	} else {
+		(*callp->sy_call)();
+	}
+	if (u.u_error) {
+		r[RPS] |= EBIT;
+		r[R0] = u.u_error;
+	} else {
+		r[R0] = u.u_r.r_val1;
+		r[R1] = u.u_r.r_val2;
+	}
+	if (issig())
+		psig();
+	curpri = setpri(u.u_procp);
+	if (runrun)
+		qswtch();
+	if(u.u_prof.pr_scale)
+		addupc((caddr_t)r[PC], &u.u_prof, (int)(u.u_stime-syst));
+}
+void
+user_trap_handler(int signo, int *r)
+{
+	if((r[RPS] & 0x1f) != 0x10) {
+		printf("kernel trap sig=%d pc=0x%x cpsr=0x%x dfar=0x%x dfsr=0x%x\n",
+		    signo, r[15], r[RPS], dfar(), dfsr());
+		panic("kernel trap");
+	}
+	u.u_fpsaved = 0;
+	u.u_ar0 = r;
+	psignal(u.u_procp, signo);
+	if (issig())
+		psig();
+	curpri = setpri(u.u_procp);
+	if (runrun)
+		qswtch();
+}

% usr/sys/sys/text.c
@@ -10,0 +11,2 @@
+void	xexpand(struct text *xp), xccdec(struct text *xp),
+	xuntext(struct text *xp);
@@ -22,2 +24,2 @@
-xswap(p, ff, os)
-register struct proc *p;
+void
+xswap(register struct proc *p, int ff, int os)
@@ -25 +27 @@
-	register a;
+	register int a;
@@ -50 +52,2 @@
-xfree()
+void
+xfree(void)
@@ -84,2 +87,2 @@
-xalloc(ip)
-register struct inode *ip;
+void
+xalloc(register struct inode *ip)
@@ -147,2 +150,2 @@
-xexpand(xp)
-register struct text *xp;
+void
+xexpand(register struct text *xp)
@@ -171,2 +174,2 @@
-xlock(xp)
-register struct text *xp;
+void
+xlock(register struct text *xp)
@@ -182,2 +185,2 @@
-xunlock(xp)
-register struct text *xp;
+void
+xunlock(register struct text *xp)
@@ -195,2 +198,2 @@
-xccdec(xp)
-register struct text *xp;
+void
+xccdec(register struct text *xp)
@@ -216,2 +219,2 @@
-xumount(dev)
-register dev;
+void
+xumount(register int dev)
@@ -229,2 +232,2 @@
-xrele(ip)
-register struct inode *ip;
+void
+xrele(register struct inode *ip)
@@ -234 +237 @@
-	if (ip->i_flag&ITEXT==0)
+	if ((ip->i_flag&ITEXT)==0)
@@ -245,2 +248,2 @@
-xuntext(xp)
-register struct text *xp;
+void
+xuntext(register struct text *xp)

% usr/sys/sys/ureg.c
@@ -15 +15,2 @@
-sureg()
+void
+sureg(void)
@@ -17 +18,2 @@
-	register *udp, *uap, *rdp;
+	register int *udp, *uap, *rdp;
+	int auisa[16], auisd[16];
@@ -28,2 +30,2 @@
-	rap = (int *)UISA;
-	rdp = (int *)UISD;
+	rap = auisa;
+	rdp = auisd;
@@ -34,0 +37 @@
+	arm_sureg();
@@ -48,2 +51,2 @@
-estabur(nt, nd, ns, sep, xrw)
-unsigned nt, nd, ns;
+int
+estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw)
@@ -51 +54 @@
-	register a, *ap, *dp;
+	(void)sep; (void)xrw;
@@ -53,9 +56 @@
-	if(sep) {
-		if(cputype == 40)
-			goto err;
-		if(ctos(nt) > 8 || ctos(nd)+ctos(ns) > 8)
-			goto err;
-	} else
-		if(ctos(nt)+ctos(nd)+ctos(ns) > 8)
-			goto err;
-	if(nt+nd+ns+USIZE > maxmem)
+	if((int)(nt+nd+ns+USIZE) > maxmem)
@@ -63,70 +57,0 @@
-	a = 0;
-	ap = &u.u_uisa[0];
-	dp = &u.u_uisd[0];
-	while(nt >= 128) {
-		*dp++ = (127<<8) | xrw|TX;
-		*ap++ = a;
-		a += 128;
-		nt -= 128;
-	}
-	if(nt) {
-		*dp++ = ((nt-1)<<8) | xrw|TX;
-		*ap++ = a;
-	}
-	if(sep)
-	while(ap < &u.u_uisa[8]) {
-		*ap++ = 0;
-		*dp++ = 0;
-	}
-	a = USIZE;
-	while(nd >= 128) {
-		*dp++ = (127<<8) | RW;
-		*ap++ = a;
-		a += 128;
-		nd -= 128;
-	}
-	if(nd) {
-		*dp++ = ((nd-1)<<8) | RW;
-		*ap++ = a;
-		a += nd;
-	}
-	while(ap < &u.u_uisa[8]) {
-		if(*dp &ABS) {
-			dp++;
-			ap++;
-			continue;
-		}
-		*dp++ = 0;
-		*ap++ = 0;
-	}
-	if(sep)
-	while(ap < &u.u_uisa[16]) {
-		if(*dp & ABS) {
-			dp++;
-			ap++;
-			continue;
-		}
-		*dp++ = 0;
-		*ap++ = 0;
-	}
-	a += ns;
-	while(ns >= 128) {
-		a -= 128;
-		ns -= 128;
-		*--dp = (127<<8) | RW;
-		*--ap = a;
-	}
-	if(ns) {
-		*--dp = ((128-ns)<<8) | RW | ED;
-		*--ap = a-128;
-	}
-	if(!sep) {
-		ap = &u.u_uisa[0];
-		dp = &u.u_uisa[8];
-		while(ap < &u.u_uisa[8])
-			*dp++ = *ap++;
-		ap = &u.u_uisd[0];
-		dp = &u.u_uisd[8];
-		while(ap < &u.u_uisd[8])
-			*dp++ = *ap++;
-	}
EOF
# How the check works.  One awk pass reads the entries above.  For each
# entry it loads the v7 file, applies the hunks (each - line must match the
# v7 line it deletes), compares the result with the repo file and records
# the file name in $T/h.  Then the set of entries must equal the set of
# repo files less what X excludes: an X entry excludes itself and
# everything under it.  With -u, every entry's hunks are first
# regenerated with diff -U0 from its header line.
export LC_ALL=C
S=$(cd "$(dirname "$0")" && pwd)/${0##*/}
cd "$(dirname "$S")" && cd "$(git rev-parse --show-toplevel)" || exit 1
V=${V7:-usr/local/test/v7}
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' 0
if [ "$1" = -u ]; then
	{ sed '/^: <<\\EOF$/q' "$S"
	grep '^% ' "$S" | while read -r h f s; do
		printf '\n%% %s%s\n' "$f" "${s:+ $s}"
		case $s in '') s=$V/$f;; /*) ;; *) s=$V/$s;; esac
		diff -U0 "$s" "$f" | sed 1,2d
	done
	sed -n '/^EOF$/,$p' "$S"; } >"$T/u" && cat "$T/u" >"$S" && rm -rf "$T" && exec sh "$S"
	exit 1
fi
: >"$T/h"
awk -v V="$V" -v H="$T/h" '
function load(path, a,   n, l, r) {
	split("", a)
	n = 0
	while ((r = getline l < path) > 0)
		a[++n] = l
	close(path)
	return r < 0 ? -1 : n
}
function fail(m) {
	if (!bad[f]++)
		print f ": " m
}
function finish(   m, i) {
	if (f == "")
		return
	while (p <= n0)
		r[++k] = o[p++]
	if ((m = load(f, c)) < 0)
		fail("not in repo")
	else if (m != k)
		fail("diff does not match")
	else
		for (i = 1; i <= k; i++)
			if (c[i] != r[i]) {
				fail("diff does not match")
				break
			}
	f = ""
}
$0 == ": <<\\EOF" { on = 1; next }
!on { next }
$0 == "EOF" { finish(); exit }
/^% / {
	finish()
	f = $2
	src = NF < 3 ? V "/" f : $3 == "/dev/null" ? $3 : V "/" $3
	split("", r); k = 0; p = 1
	if ((n0 = load(src, o)) < 0)
		fail("no v7 file " src)
	print f > H
	next
}
/^$/ || /^\\/ { next }
f == "" { print "stray line " NR ": " $0; exit 1 }
/^@@ / {
	split(substr($2, 2), a, ",")
	end = ("2" in a) && a[2] == 0 ? a[1] : a[1] - 1
	if (end < p - 1)
		fail("hunks out of order")
	while (p <= end)
		r[++k] = o[p++]
	next
}
/^-/ {
	if (p > n0 || o[p] != substr($0, 2))
		fail("diff does not match")
	p++
	next
}
/^\+/ { r[++k] = substr($0, 2); next }
{ fail("bad line " NR) }
' "$S" >"$T/e" || { cat "$T/e"; exit 1; }
git ls-files -co --exclude-standard | awk -v X="$X" '
BEGIN { n = split(X, x, "\n") }
{ for (i = 1; i <= n; i++)
	if (x[i] != "" && ($0 == x[i] || index($0, x[i] "/") == 1))
		next
  print }' | sort >"$T/n"
sort "$T/h" >"$T/hs"
uniq -d "$T/hs" | sed 's/$/: listed twice/' >>"$T/e"
uniq "$T/hs" | comm -23 - "$T/n" | sed 's/$/: listed but not in repo, or excluded/' >>"$T/e"
uniq "$T/hs" | comm -13 - "$T/n" | sed 's/$/: neither diffed nor excluded/' >>"$T/e"
cat "$T/e"
[ -s "$T/e" ] && exit 1
echo "ok: $(wc -c <"$S") bytes"
