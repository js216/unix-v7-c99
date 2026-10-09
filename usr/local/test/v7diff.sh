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
@@ -0,0 +1,49 @@
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
+$(CMD_OBJ): CPPFLAGS = -Iusr/include -Iusr/src
+$(CMD_OBJ): $C/cmd.mk
+$C/bc.o $C/egrep.o $C/expr.o $(AWK_OBJ): CPPFLAGS += -DYYSTACK_USE_ALLOCA=1
+$(AWK_OBJ): CPPFLAGS += -Dmalloc=malloc -Dfree=free
+
+$(CMD_BIN:%=bin/%): bin/%: $(CRT) $C/%.o $(LIBC) | bin
+	$(LINK)
+$(CMD_ETC:%=etc/%): etc/%: $(CRT) $C/%.o $(LIBC) | etc
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
+	bison --defines=$C/awk/awk.h -o $C/awk/awk.g.c $<
+$C/awk/proc: $C/awk/proc.c $C/awk/token.c $C/awk/awk.h
+	$(HOSTCC) $(HOSTCFLAGS) -o $@ $C/awk/proc.c $C/awk/token.c
+$C/awk/proctab.c: $C/awk/proc
+	$< >$@

% usr/src/games/games.mk /dev/null
@@ -0,0 +1,8 @@
+GAMES_OBJ := $(patsubst %.c,%.o,$(wildcard usr/src/games/*.c))
+GAMES = $(patsubst usr/src/games/%.o,usr/games/%,$(GAMES_OBJ))
+
+$(GAMES_OBJ): CPPFLAGS = -Iusr/include -Iusr/src
+$(GAMES_OBJ): usr/src/games/games.mk
+
+$(GAMES): usr/games/%: $(CRT) usr/src/games/%.o $(LIBC) | usr/games
+	$(LINK)

% usr/src/libc/lib.mk /dev/null
@@ -0,0 +1,17 @@
+L = usr/src/libc
+LIBC = $L/libc.a
+CRT = $L/csu/crt0.o $L/csu/crt0c.o
+LIBC_OBJ := $(addsuffix .o,$(basename $(wildcard $L/*.[cs] $L/gen/*.[cs] \
+	$L/stdio/*.[cs] $L/sys/*.[cs])))
+
+$(LIBC_OBJ) $(CRT): CPPFLAGS = -Iusr/include -Iusr
+$(LIBC_OBJ) $(CRT): $L/lib.mk
+
+$(LIBC): $(LIBC_OBJ)
+	rm -f $@
+	$(AR) rc $@ $^
+
+$L/csu/crt0.o: $L/csu/crt0.s
+	$(COMPILE.s) -o $@ $<
+$L/csu/crt0c.o: $L/csu/crt0.c
+	$(COMPILE.c) -o $@ $<

% usr/src/libm/lib.mk /dev/null
@@ -0,0 +1,9 @@
+LIBM = usr/src/libm/libm.a
+LIBM_OBJ := $(patsubst %.c,%.o,$(wildcard usr/src/libm/*.c))
+
+$(LIBM_OBJ): CPPFLAGS = -Iusr/include
+$(LIBM_OBJ): usr/src/libm/lib.mk
+
+$(LIBM): $(LIBM_OBJ)
+	rm -f $@
+	$(AR) rc $@ $^

% usr/sys/sys.mk /dev/null
@@ -0,0 +1,28 @@
+S = usr/sys
+LIB1 = $S/sys/LIB1
+LIB2 = $S/dev/LIB2
+LIB1_OBJ := $(patsubst %.c,%.o,$(wildcard $S/sys/*.c))
+LIB2_OBJ := $(patsubst %.c,%.o,$(wildcard $S/dev/*.c))
+BOARDS = qemu mp135
+KERNELS = $(BOARDS:%=$S/conf/%/unix)
+SYS_OBJ = $(LIB1_OBJ) $(LIB2_OBJ) $S/conf/low.o $S/conf/mch.o $(BOARDS:%=$S/conf/%/c.o)
+GEN += $(BOARDS:%=$S/conf/%/c.c) $(BOARDS:%=$S/conf/%/unix.ld) $S/conf/mkconf
+
+$(SYS_OBJ): $S/sys.mk
+$(LIB1): $(LIB1_OBJ)
+$(LIB2): $(LIB2_OBJ)
+$(LIB1) $(LIB2):
+	rm -f $@
+	$(AR) rc $@ $^
+
+$S/conf/mkconf: $S/conf/mkconf.c
+	$(HOSTCC) $(HOSTCFLAGS) -o $@ $<
+
+$S/conf/%/c.c $S/conf/%/unix.ld: $S/conf/%conf $S/conf/mkconf
+	mkdir -p $(@D)
+	cd $(@D) && ../mkconf <../$*conf
+
+$S/conf/%/c.o: CPPFLAGS = -I$S/conf
+
+$S/conf/%/unix: $S/conf/low.o $S/conf/mch.o $S/conf/%/c.o $(LIB1) $(LIB2) $S/conf/%/unix.ld
+	$(CC) -nostdlib -T $(@D)/unix.ld -o $@ $(filter-out %.ld,$^)

% Makefile /dev/null
@@ -0,0 +1,79 @@
+CROSS_COMPILE ?= arm-none-eabi-
+CC = $(CROSS_COMPILE)gcc
+AS = $(CROSS_COMPILE)as
+AR = $(CROSS_COMPILE)ar
+HOSTCC = arm-linux-gnueabihf-gcc
+LEX = flex
+
+CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon -fno-builtin \
+	-ffreestanding -nostdlib -mcpu=cortex-a7 -marm -Os -Wl,-N,-Ttext=0x10 \
+	-MMD -MP
+ASFLAGS = -mcpu=cortex-a7
+HOSTCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -static \
+	-D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32
+
+LINK = $(CC) $(CFLAGS) -s -o $@ $(filter %.o %.a,$^) -lgcc
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
+	bison -o $@ $<
+
+boot/unix: usr/sys/conf/qemu/unix | boot
+	cp $< $@
+
+qemu: boot/unix boot/rootfs.img
+	qemu-system-arm -machine virt -cpu cortex-a7 -nographic \
+	    -kernel boot/unix -drive if=none,file=boot/rootfs.img,format=raw,id=hd0 \
+	    -device virtio-blk-device,drive=hd0
+
+ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup \
+	etc/passwd etc/group etc/ttys \
+	usr/dict/words usr/games/lib/fortunes usr/lib/units usr/lib/crontab \
+	usr/lib/lib.b
+
+ROOT = $(CMD) $(GAMES) $(ROOTFS_STATIC)
+
+DIRS = boot bin etc usr/lib usr/dict usr/games usr/games/lib
+
+boot/rootfs.img: boot/unix etc/mkfs boot/rootfs.proto $(ROOT)
+	trap 'rm -f boot/rootfs.img.tmp' EXIT; \
+	    V7_MKFS_TIME=284774400 etc/mkfs boot/rootfs.img.tmp boot/rootfs.proto; \
+	    size=$$(awk '/^(swplo|nswap) /{n+=$$2} END{print n}' usr/sys/conf/qemuconf); \
+	    truncate -s "$$((size * 512))" boot/rootfs.img.tmp; \
+	    mv boot/rootfs.img.tmp boot/rootfs.img
+
+etc/mkfs: usr/src/cmd/mkfs.c | etc
+	tmpinc="$(CURDIR)/boot/mkfs-include.$$$$"; \
+	    trap 'rm -rf "$$tmpinc"' EXIT; \
+	    mkdir -p "$$tmpinc"; \
+	    ln -s "$(CURDIR)/usr/include/sys" "$$tmpinc/sys"; \
+	    $(HOSTCC) $(HOSTCFLAGS) -I"$$tmpinc" -o $@ $<
+
+$(DIRS):
+	mkdir -p $@
+
+$(filter-out etc/%,$(ROOTFS_STATIC)): %: usr/local/test/v7/% | $(DIRS)
+	cp $< $@
+
+clean:
+	rm -f $(OBJ) $(OBJ:.o=.d) $(GEN) $(CMD) $(GAMES)
+	rm -f $(LIBC) $(LIBM) $(LIB1) $(LIB2) $(KERNELS)
+	rm -f etc/mkfs boot/unix boot/rootfs.img boot/rootfs.img.tmp
+
+.PHONY: all clean qemu
+
+-include $(OBJ:.o=.d)

% boot/rootfs.proto /dev/null
@@ -0,0 +1,181 @@
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
+		login	---755 0 0 bin/login
+		look	---755 0 0 bin/look
+		ls	---755 0 0 bin/ls
+		mesg	---755 0 0 bin/mesg
+		mkdir	---755 0 0 bin/mkdir
+		mv	---755 0 0 bin/mv
+		ncheck	---755 0 0 bin/ncheck
+		newgrp	---755 0 0 bin/newgrp
+		nice	---755 0 0 bin/nice
+		nohup	---755 0 0 bin/nohup
+		od	---755 0 0 bin/od
+		osh	---755 0 0 bin/osh
+		passwd	---755 0 0 bin/passwd
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
+		rmdir	---755 0 0 bin/rmdir
+		sa	---755 0 0 bin/sa
+		sed	---755 0 0 bin/sed
+		sh	---755 0 0 bin/sh
+		sleep	---755 0 0 bin/sleep
+		sort	---755 0 0 bin/sort
+		sp	---755 0 0 bin/sp
+		spline	---755 0 0 bin/spline
+		split	---755 0 0 bin/split
+		stty	---755 0 0 bin/stty
+		su	---755 0 0 bin/su
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
+		mem	c--640 0 0 8 0
+		kmem	c--640 0 0 8 1
+		null	c--666 0 0 8 2
+		root	b--640 0 0 0 0
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
+		utmp	---644 0 0 /dev/null
+		dmesg	---755 0 0 etc/dmesg
+		mknod	---755 0 0 etc/mknod
+		mount	---755 0 0 etc/mount
+		umount	---755 0 0 etc/umount
+		wall	---755 0 0 etc/wall
+		$
+	tmp	d--777 0 0
+		.keep	---644 0 0 /dev/null
+		$
+	usr	d--755 0 0
+		adm	d--755 0 0
+			acct	---644 0 0 /dev/null
+			wtmp	---644 0 0 /dev/null
+			$
+		dict	d--755 0 0
+			words	---644 0 0 usr/dict/words
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
+			atrun	---755 0 0 usr/lib/atrun
+			$
+		spool	d--755 0 0
+			at	d--777 0 0
+				lasttimedone	---666 0 0 /dev/null
+				past	d--777 0 0
+					.keep	---644 0 0 /dev/null
+					$
+				$
+			$
+		$
+	unix	---644 0 0 boot/unix
+$

% etc/group

% etc/passwd

% etc/rc
@@ -5 +5 @@
-rm /etc/mtab
+rm -f /etc/mtab
@@ -7,4 +6,0 @@
-/etc/mount /dev/rp3 /usr
-rm -f /usr/spool/lpd/lock
-: /etc/accton /usr/adm/acct
-rm -f /usr/tmp/*

% etc/ttys

% usr/include/a.out.h
@@ -33,0 +34 @@
+int	nlist(char *, struct nlist *);

% usr/include/ar.h

% usr/include/ctype.h

% usr/include/dumprestor.h

% usr/include/errno.h
@@ -3,0 +4,2 @@
+#ifndef ERRNO_H
+#define ERRNO_H
@@ -40,0 +43,2 @@
+extern int errno;
+#endif

% usr/include/execargs.h
@@ -1 +1 @@
-char **execargs = (char**)(-2);
+char **execargs = (char**)(0x100000-4);

% usr/include/grp.h
@@ -0,0 +1,2 @@
+#ifndef GRP_H
+#define GRP_H
@@ -6,0 +9,6 @@
+extern struct group *getgrent(void);
+extern struct group *getgrgid(int gid);
+extern struct group *getgrnam(char *name);
+extern void setgrent(void);
+extern void endgrent(void);
+#endif

% usr/include/math.h
@@ -1,7 +1,29 @@
-extern double fabs(), floor(), ceil(), fmod(), ldexp();
-extern double sqrt(), hypot(), atof();
-extern double sin(), cos(), tan(), asin(), acos(), atan(), atan2();
-extern double exp(), log(), log10(), pow();
-extern double sinh(), cosh(), tanh();
-extern double gamma();
-extern double j0(), j1(), jn(), y0(), y1(), yn();
+extern double fabs(double x);
+extern double floor(double x);
+extern double ceil(double x);
+extern double fmod(double x, double y);
+extern double ldexp(double x, int n);
+extern double sqrt(double x);
+extern double hypot(double x, double y);
+extern double atof(char *s);
+extern double sin(double x);
+extern double cos(double x);
+extern double tan(double x);
+extern double asin(double x);
+extern double acos(double x);
+extern double atan(double x);
+extern double atan2(double y, double x);
+extern double exp(double x);
+extern double log(double x);
+extern double log10(double x);
+extern double pow(double x, double y);
+extern double sinh(double x);
+extern double cosh(double x);
+extern double tanh(double x);
+extern double gamma(double x);
+extern double j0(double x);
+extern double j1(double x);
+extern double jn(int n, double x);
+extern double y0(double x);
+extern double y1(double x);
+extern double yn(int n, double x);
@@ -9,2 +31,2 @@
-#define HUGE	1.701411733192644270e38
-#define LOGHUGE 39
+#define HUGE	1.797693134862315708e308
+#define LOGHUGE 308

% usr/include/pwd.h
@@ -0,0 +1,2 @@
+#ifndef PWD_H
+#define PWD_H
@@ -11,0 +14,6 @@
+extern struct passwd *getpwent(void);
+extern struct passwd *getpwnam(char *);
+extern struct passwd *getpwuid(int);
+extern void setpwent(void);
+extern void endpwent(void);
+#endif

% usr/include/setjmp.h
@@ -1 +1,3 @@
-typedef int jmp_buf[3];
+typedef int jmp_buf[10];
+int	setjmp(jmp_buf);
+void	longjmp(jmp_buf, int);

% usr/include/sgtty.h

% usr/include/signal.h
@@ -19,3 +19,2 @@
-int	(*signal())();
-#define	SIG_DFL	(int (*)())0
-#define	SIG_IGN	(int (*)())1
+#define	SIG_DFL	0
+#define	SIG_IGN	1

% usr/include/stdio.h
@@ -0,0 +1,3 @@
+#ifndef STDIO_H
+#define STDIO_H
+struct stat;
@@ -21,0 +25 @@
+#ifndef NULL
@@ -22,0 +27 @@
+#endif
@@ -37,5 +42,119 @@
-FILE	*fopen();
-FILE	*freopen();
-FILE	*fdopen();
-long	ftell();
-char	*fgets();
+FILE	*fopen(char *name, char *mode);
+FILE	*freopen(char *name, char *mode, FILE *f);
+FILE	*fdopen(int fd, char *mode);
+long	ftell(FILE *f);
+char	*fgets(char *s, int n, FILE *f);
+#define	O_RDONLY	0
+int syscall3(int n, int a, int b, int c);
+int read(int fd, char *buf, int n);
+int write(int fd, char *buf, int n);
+int open(char *path, int mode);
+int close(int fd);
+int creat(char *path, int mode);
+int unlink(char *path);
+int link(char *from, char *to);
+int access(char *path, int mode);
+int chdir(char *path);
+int chmod(char *path, int mode);
+int chown(char *path, int uid, int gid);
+int mknod(char *path, int mode, int dev);
+int utime(char *path, long *times);
+long lseek(int fd, long off, int whence);
+int stat(char *path, struct stat *st);
+int fstat(int fd, struct stat *st);
+int fork(void);
+int wait(int *status);
+int execve(char *path, char **argv, char **envp);
+int execv(char *path, char **argv);
+int execl(char *path, char *arg0, ...);
+int execvp(char *name, char **argv);
+int execlp(char *name, char *arg0, ...);
+void exit(int n) __attribute__((__noreturn__));
+void _exit(int n) __attribute__((__noreturn__));
+void abort(void) __attribute__((__noreturn__));
+int dup();
+int pipe(int *fd);
+int getuid(void);
+int setuid(int uid);
+int getgid(void);
+int setgid(int gid);
+int getpid(void);
+int umask(int n);
+int sync(void);
+int kill(int pid, int sig);
+int signal();
+int alarm(int n);
+int pause(void);
+int nice(int incr);
+int gtty(int fd, void *buf);
+int stty(int fd, void *buf);
+int ioctl(int fd, int cmd, char *arg);
+int mount(char *special, char *dir, int ro);
+int umount(char *special);
+struct tm;
+struct timeb;
+int time(long *t);
+int stime(long *t);
+int times();
+int ftime(struct timeb *t);
+struct tm *gmtime(long *t);
+struct tm *localtime(long *t);
+char *asctime(struct tm *t);
+char *ctime(long *t);
+int dysize(int y);
+int fclose(FILE *f);
+int fseek(FILE *f, long off, int whence);
+void rewind(FILE *f);
+void setbuf(FILE *f, char *buf);
+int fgetc(FILE *f);
+int fputc(int c, FILE *f);
+int fread(char *buf, unsigned size, unsigned n, FILE *f);
+int fwrite(char *buf, unsigned size, unsigned n, FILE *f);
+char *gets(char *buf);
+int puts();
+int fputs(char *s, FILE *f);
+int ungetc(int c, FILE *f);
+int fflush(FILE *f);
+int _filbuf(FILE *f);
+int _flsbuf(int c, FILE *f);
+int printf(char *fmt, ...);
+int fprintf(FILE *f, char *fmt, ...);
+char *sprintf(char *buf, char *fmt, ...);
+int fscanf(FILE *f, char *fmt, ...);
+int sscanf(char *str, char *fmt, ...);
+int system(char *s);
+void perror(char *s);
+int isatty(int fd);
+unsigned int sleep(unsigned n);
+char *mktemp(char *s);
+char *getenv(char *name);
+extern char **environ;
+char *getlogin(void);
+char *getpass(char *prompt);
+char *ttyname(int fd);
+char *crypt(char *key, char *salt);
+char *strncat(char *s1, char *s2, int n);
+int ttyslot(void);
+int strlen(const char *s);
+int strcmp(char *a, char *b);
+char *strcpy(char *a, char *b);
+char *strcat(char *a, char *b);
+char *strncpy(char *a, char *b, int n);
+int strncmp(char *a, char *b, int n);
+char *index(char *s, int c);
+char *rindex(char *s, int c);
+int atoi(char *s);
+long atol(char *s);
+double atof(char *s);
+void srand(unsigned int x);
+int rand(void);
+void qsort(void *base, unsigned n, int size, int (*compar)());
+char *malloc(unsigned n);
+void free(char *p);
+char *realloc(char *p, unsigned n);
+char *calloc(unsigned num, unsigned size);
+void swab(char *from, char *to, int n);
+int getargs(char **argv, int maxarg);
+long tell(int f);
+char *timezone(int zone, int dst);
+#endif

% usr/include/sys/acct.h

% usr/include/sys/dir.h
@@ -0,0 +1,2 @@
+#ifndef SYS_DIR_H
+#define SYS_DIR_H
@@ -8,0 +11 @@
+#endif

% usr/include/sys/fblk.h

% usr/include/sys/filsys.h

% usr/include/sys/ino.h

% usr/include/sys/inode.h
@@ -15 +15 @@
-struct group {
+struct mpx_group {
@@ -19 +19 @@
-	struct	group	*g_group;
+	struct	mpx_group	*g_group;
@@ -41 +41 @@
-		};
+		} u_reg;
@@ -44,2 +44,2 @@
-			struct	group	i_group;	/*  multiplexor group file */
-		};
+			struct	mpx_group	i_group;	/*  multiplexor group file */
+		} u_dev;
@@ -47,0 +48,4 @@
+#define	i_addr	u_reg.i_addr
+#define	i_lastr	u_reg.i_lastr
+#define	i_rdev	u_dev.i_rdev
+#define	i_group	u_dev.i_group

% usr/include/sys/param.h
@@ -83,2 +83,3 @@
-#define	USIZE	16		/* size of user block (*64) */
-#define	UBASE	0140000		/* abs. addr of user block */
+#define	USIZE	128		/* size of user block (*64): 8KB u-area+kstack */
+#define	UBASE	0x4F000000U	/* kernel VA window mapping the current u-area */
+#ifndef NULL
@@ -85,0 +87 @@
+#endif
@@ -94 +96 @@
-#define	CBSIZE	14		/* number of chars in a clist block */
+#define	CBSIZE	12		/* number of chars in a clist block */
@@ -120 +122 @@
-#define	major(x)	(int)(((unsigned)x>>8))
+#define	major(x)	(int)(((unsigned)x>>8)&0377)
@@ -128,0 +131 @@
+#ifndef SYS_TYPES_H
@@ -131 +134 @@
-typedef	unsigned int	ino_t;
+typedef	unsigned short	ino_t;
@@ -133 +136 @@
-typedef	int		label_t[6];	/* regs 2-7 */
+typedef	int		label_t[10];	/* regs 2-7 */
@@ -135,0 +139,2 @@
+#define	SYS_TYPES_H
+#endif

% usr/include/sys/stat.h
@@ -0,0 +1,3 @@
+#ifndef SYS_STAT_H
+#define SYS_STAT_H
+#include <sys/types.h>
@@ -28,0 +32 @@
+#endif

% usr/include/sys/timeb.h
@@ -0,0 +1,3 @@
+#ifndef SYS_TIMEB_H
+#define SYS_TIMEB_H
+#include <sys/types.h>
@@ -9,0 +13 @@
+#endif

% usr/include/sys/times.h
@@ -0,0 +1,2 @@
+#ifndef SYS_TIMES_H
+#define SYS_TIMES_H
@@ -9,0 +12 @@
+#endif

% usr/include/sys/types.h
@@ -1,7 +1,9 @@
-typedef	long       	daddr_t;  	/* disk address */
-typedef	char *     	caddr_t;  	/* core address */
-typedef	unsigned int	ino_t;     	/* i-node number */
-typedef	long       	time_t;   	/* a time */
-typedef	int        	label_t[6]; 	/* program status */
-typedef	int        	dev_t;    	/* device code */
-typedef	long       	off_t;    	/* offset in file */
+#ifndef SYS_TYPES_H
+#define SYS_TYPES_H
+typedef	long		daddr_t;	/* disk address */
+typedef	char *		caddr_t;	/* core address */
+typedef	unsigned short	ino_t;		/* i-node number */
+typedef	long		time_t;		/* a time */
+typedef	int		label_t[10];	/* program status */
+typedef	int		dev_t;		/* device code */
+typedef	long		off_t;		/* offset in file */
@@ -9 +11 @@
-#define	major(x)  	(int)(((unsigned)x>>8))
+#define	major(x)  	(int)(((unsigned)x>>8)&0377)
@@ -11,0 +14 @@
+#endif

% usr/include/time.h
@@ -0,0 +1,2 @@
+#ifndef TIME_H
+#define TIME_H
@@ -11,0 +14 @@
+#endif

% usr/include/tp_defs.h

% usr/include/utmp.h

% usr/src/cmd/ac.c
@@ -35,2 +35,4 @@
-main(argc, argv) 
-char **argv;
+int	loop(void), print(void), upall(int f), update(struct tbuf *tp, int f);
+int	among(int i), newday(void), pdate(void);
+int
+main(int argc, char **argv)
@@ -39 +41 @@
-	register i;
+	register int i;
@@ -92 +94,2 @@
-loop()
+int
+loop(void)
@@ -94 +97 @@
-	register i;
+	register int i;
@@ -100 +103 @@
-		return;
+		return(0);
@@ -104 +107 @@
-			return;
+			return(0);
@@ -108 +111 @@
-		return;
+		return(0);
@@ -125 +128 @@
-		return;
+		return(0);
@@ -134,0 +138 @@
+	return(0);
@@ -137 +141,2 @@
-print()
+int
+print(void)
@@ -157,0 +163 @@
+	return(0);
@@ -160 +166,2 @@
-upall(f)
+int
+upall(int f)
@@ -165,0 +173 @@
+	return(0);
@@ -168,2 +176,2 @@
-update(tp, f)
-struct tbuf *tp;
+int
+update(struct tbuf *tp, int f)
@@ -186 +194 @@
-		return;
+		return(0);
@@ -189 +197 @@
-		return;
+		return(0);
@@ -200,0 +209 @@
+	return(0);
@@ -203 +212,2 @@
-among(i)
+int
+among(int i)
@@ -205 +215 @@
-	register j, k;
+	register int j, k;
@@ -223 +233,2 @@
-newday()
+int
+newday(void)
@@ -227 +238 @@
-	struct tm *localtime();
+	struct tm *localtime(long *tim);
@@ -237,0 +249 @@
+	return(0);
@@ -240 +252,2 @@
-pdate()
+int
+pdate(void)
@@ -243 +256 @@
-	char *ctime();
+	char *ctime(long *);
@@ -246 +259 @@
-		return;
+		return(0);
@@ -248,0 +262 @@
+	return(0);

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
@@ -10,3 +11 @@
-struct	ar_hdr nh;
-struct
-{
+struct oar_hdr {
@@ -14 +13 @@
-	long	odate;
+	char	odate[4];
@@ -17,2 +16,2 @@
-	unsigned siz;
-} oh;
+	char	osize[2];
+};
@@ -21 +19,0 @@
-char	*mktemp();
@@ -23,0 +22 @@
+static void conv(char *fil);
@@ -26 +25 @@
-	int	magic;
+	char	magic[2];
@@ -29,2 +28,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char **argv)
@@ -32 +31,2 @@
-	register i;
+	int i;
+	char tbuf[] = "/tmp/arcXXXXX";
@@ -34 +34 @@
-	tmp = mktemp("/tmp/arcXXXXX");
+	tmp = mktemp(tbuf);
@@ -39,0 +40,36 @@
+	return 0;
+}
+static unsigned short
+getshort(char *p)
+{
+	return ((unsigned short)(unsigned char)p[0]) |
+	    ((unsigned short)(unsigned char)p[1] << 8);
+}
+static void
+putshort(char *p, unsigned short v)
+{
+	p[0] = v & 0377;
+	p[1] = (v >> 8) & 0377;
+}
+static void
+putlong(char *p, char *v)
+{
+	p[0] = v[0];
+	p[1] = v[1];
+	p[2] = v[2];
+	p[3] = v[3];
+}
+static void
+putarhdr(char *p, struct oar_hdr *oh)
+{
+	int i;
+	for(i=0; i<8; i++)
+		p[i] = oh->oname[i];
+	for(; i<14; i++)
+		p[i] = 0;
+	putlong(&p[14], oh->odate);
+	p[18] = oh->ouid;
+	p[19] = 1;
+	putshort(&p[20], 0666);
+	putshort(&p[22], getshort(oh->osize));
+	putshort(&p[24], 0);
@@ -42,2 +78,2 @@
-conv(fil)
-char *fil;
+static void
+conv(char *fil)
@@ -45 +81,3 @@
-	register unsigned i, n;
+	unsigned int i, n;
+	struct oar_hdr oh;
+	char nh[26];
@@ -59,3 +97,4 @@
-	b.magic = 0;
-	read(f, (char *)&b.magic, sizeof(b.magic));
-	if(b.magic != omag) {
+	b.magic[0] = 0;
+	b.magic[1] = 0;
+	read(f, b.magic, sizeof(b.magic));
+	if(getshort(b.magic) != omag) {
@@ -67,2 +106,2 @@
-	b.magic = ARMAG;
-	write(tf, (char *)&b.magic, sizeof(b.magic));
+	putshort(b.magic, ARMAG);
+	write(tf, b.magic, sizeof(b.magic));
@@ -73,9 +112,3 @@
-	for(i=0; i<8; i++)
-		nh.ar_name[i] = oh.oname[i];
-	nh.ar_size = oh.siz;
-	nh.ar_uid = oh.ouid;
-	nh.ar_gid = 1;
-	nh.ar_mode = 0666;
-	nh.ar_date = oh.odate;
-	n = (oh.siz+1) & ~01;
-	write(tf, (char *)&nh, sizeof(nh));
+	putarhdr(nh, &oh);
+	n = (getshort(oh.osize)+1) & ~01;
+	write(tf, nh, sizeof(nh));

% usr/src/cmd/at.c
@@ -10,0 +11 @@
+#define	utime	at_utime
@@ -55 +56 @@
-char	*prefix();
+char	*prefix(char *begin, char *full);
@@ -58,2 +59,6 @@
-main(argc, argv)
-char **argv;
+int	pclose(FILE *ptr);
+int	makeutime(char *pp), makeuday(int argc, char **argv);
+int	filename(char *dir, int y, int d, int t);
+int	onintr(int sig);
+int
+main(int argc, char **argv)
@@ -61,2 +66,2 @@
-	extern onintr();
-	register c;
+	extern int onintr(int sig);
+	register int c;
@@ -92,2 +97,2 @@
-	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
-		signal(SIGINT, onintr);
+	if ((int (*)())signal(SIGINT, (int)SIG_IGN) != (int (*)())SIG_IGN)
+		signal(SIGINT, (int)onintr);
@@ -118,2 +123,2 @@
-makeutime(pp)
-char *pp; 
+int
+makeutime(char *pp)
@@ -121 +126 @@
-	register val;
+	register int val;
@@ -127 +132 @@
-	while(isdigit(*p)) {
+	while(isdigit((unsigned char)*p)) {
@@ -138,2 +143,2 @@
-			if (isdigit(*p)) {
-				if (isdigit(p[1])) {
+			if (isdigit((unsigned char)*p)) {
+				if (isdigit((unsigned char)p[1])) {
@@ -197,0 +203 @@
+	return(0);
@@ -201,2 +207,2 @@
-makeuday(argc,argv)
-char **argv;
+int
+makeuday(int argc, char **argv)
@@ -273,2 +279 @@
-prefix(begin, full)
-char *begin, *full;
+prefix(char *begin, char *full)
@@ -277 +282 @@
-	while (c = *begin++) {
+	while ((c = *begin++)) {
@@ -288,2 +293,2 @@
-filename(dir, y, d, t)
-char *dir;
+int
+filename(char *dir, int y, int d, int t)
@@ -291 +296 @@
-	register i;
+	register int i;
@@ -297 +302 @@
-			return;
+			return(0);
@@ -301 +306,2 @@
-onintr()
+int
+onintr(int sig)
@@ -302,0 +309 @@
+	(void)sig;
@@ -304,0 +312 @@
+	return(0);

% usr/src/cmd/atrun.c
@@ -13,0 +14 @@
+int	makenowtime(void), updatetime(int t), run(char *file);
@@ -18,2 +19,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -24,0 +26 @@
+	(void)argc; (void)argv;
@@ -52 +54,2 @@
-makenowtime()
+int
+makenowtime(void)
@@ -55 +57,0 @@
-	struct tm *localtime();
@@ -62,0 +65 @@
+	return(0);
@@ -65 +68,2 @@
-updatetime(t)
+int
+updatetime(int t)
@@ -74,0 +79 @@
+	return(0);
@@ -77,2 +82,2 @@
-run(file)
-char *file;
+int
+run(char *file)
@@ -81 +86 @@
-	register pid, i;
+	register int pid, i;
@@ -85 +90 @@
-		return;
+		return(0);
@@ -96 +101 @@
-	if (pid = fork()) {
+	if ((pid = fork())) {
@@ -107,0 +113 @@
+	return(0);

% usr/src/cmd/awk/awk.def
@@ -2 +2 @@
-#define yfree free
+#define yfree(p) free((char *)(p))

% usr/src/cmd/awk/awk.g.y
@@ -0,0 +1 @@
+%define api.value.type {long}
@@ -33,0 +35,17 @@
+int	yylex(void);
+void	yyerror(char *s);
+int	startreg(void);
+long	stat3();
+long	stat2();
+long	stat4();
+long	op1();
+long	op2();
+long	op3();
+long	valtonode();
+long	makedfa();
+long	genprint(void);
+long	pa2stat();
+long	linkum();
+long	exptostat();
+long	genjump(int a);
+char	*cclenter();
@@ -41 +59 @@
-	  begin pa_stats end	{ if (errorflag==0) winner = stat3(PROGRAM, $1, $2, $3); }
+	  begin pa_stats end	{ if (errorflag==0) winner = (node *)stat3(PROGRAM, $1, $2, $3); }
@@ -48 +66 @@
-	| 	{ PUTS("empty XBEGIN"); $$ = nullstat; }
+	| 	{ PUTS("empty XBEGIN"); $$ = (long)nullstat; }
@@ -54 +72 @@
-	|	{ PUTS("empty END"); $$ = nullstat; }
+	|	{ PUTS("empty END"); $$ = (long)nullstat; }
@@ -116 +134 @@
-			{ PUTS("substr(e,e,e)"); $$ = op3(SUBSTR, $3, $5, nullstat); }
+			{ PUTS("substr(e,e,e)"); $$ = op3(SUBSTR, $3, $5, (long)nullstat); }
@@ -120 +138 @@
-			{ PUTS("split(e,e,e)"); $$ = op3(SPLIT, $3, $5, nullstat); }
+			{ PUTS("split(e,e,e)"); $$ = op3(SPLIT, $3, $5, (long)nullstat); }
@@ -154 +172 @@
-	| '{' stat_list '}'	{ PUTS("null pattern {...}"); $$ = stat2(PASTAT, nullstat, $2); }
+	| '{' stat_list '}'	{ PUTS("null pattern {...}"); $$ = stat2(PASTAT, (long)nullstat, $2); }
@@ -159 +177 @@
-	|	{ PUTS("null pa_stat"); $$ = nullstat; }
+	|	{ PUTS("null pa_stat"); $$ = (long)nullstat; }
@@ -227 +245 @@
-		{ PUTS("print list"); $$ = stat3($1, $2, nullstat, nullstat); }
+		{ PUTS("print list"); $$ = stat3($1, $2, (long)nullstat, (long)nullstat); }
@@ -231 +249 @@
-		{ PUTS("printf list"); $$ = stat3($1, $2, nullstat, nullstat); }
+		{ PUTS("printf list"); $$ = stat3($1, $2, (long)nullstat, (long)nullstat); }
@@ -233 +251 @@
-	|		{ PUTS("null simple statement"); $$ = nullstat; }
+	|		{ PUTS("null simple statement"); $$ = (long)nullstat; }
@@ -239 +257 @@
-	| if statement		{ PUTS("if stat"); $$ = stat3(IF, $1, $2, nullstat); }
+	| if statement		{ PUTS("if stat"); $$ = stat3(IF, $1, $2, (long)nullstat); }
@@ -253 +271 @@
-	|			{ PUTS("null stat list"); $$ = nullstat; }
+	|			{ PUTS("null stat list"); $$ = (long)nullstat; }
@@ -264 +282 @@
-		{ PUTS("for(e;e;e)"); $$ = stat4(FOR, $3, nullstat, $6, $9); }
+		{ PUTS("for(e;e;e)"); $$ = stat4(FOR, $3, (long)nullstat, $6, $9); }

% usr/src/cmd/awk/awk.lx.l
@@ -0,0 +1 @@
+%option noyywrap noinput nounistd
@@ -2,0 +4,5 @@
+%top{
+#include <stddef.h>
+#define	_STRING_H_
+#define	_STDLIB_H_
+}
@@ -7 +13 @@
-extern int	yylval;
+extern YYSTYPE	yylval;
@@ -8,0 +15,12 @@
+cell	*fieldadr(int n);
+void	yyerror(char *s);
+int	input(void);
+int	startreg(void);
+void	*memset(void *s, int c, unsigned int n);
+#undef	YY_INPUT
+#define	YY_INPUT(buf,result,max_size) \
+do { \
+	int c = input(); \
+	if (c == 0) result = YY_NULL; \
+	else { buf[0] = c; result = 1; } \
+} while (0)
@@ -10 +28 @@
-int	lineno	1;
+int	lineno = 1;
@@ -16 +34 @@
-#define	CADD	cbuf[clen++]=yytext[0]; if(clen>=CBUFLEN-1) {yyerror("string too long", cbuf); BEGIN A;}
+#define	CADD	cbuf[clen++]=yytext[0]; if(clen>=CBUFLEN-1) {yyerror("string too long"); BEGIN A;}
@@ -28 +46 @@
-	switch (yybgin-yysvec-1) {	/* witchcraft */
+	switch (YY_START) {	/* witchcraft */
@@ -66 +84 @@
-				yylval = lookup("$record", symtab);
+				yylval = (YYSTYPE)lookup("$record", symtab);
@@ -69 +87 @@
-				yylval = fieldadr(atoi(yytext+1));
+				yylval = (YYSTYPE)fieldadr(atoi(yytext+1));
@@ -74 +92 @@
-<A>NF		{ mustfld=1; yylval = setsymtab(yytext, NULL, 0.0, NUM, symtab); RETURN(VAR); }
+<A>NF		{ mustfld=1; yylval = (YYSTYPE)setsymtab(yytext, NULL, 0.0, NUM, symtab); RETURN(VAR); }
@@ -76 +94 @@
-		yylval = setsymtab(yytext, NULL, atof(yytext), CON|NUM, symtab); RETURN(NUMBER); }
+		yylval = (YYSTYPE)setsymtab(yytext, NULL, atof(yytext), CON|NUM, symtab); RETURN(NUMBER); }
@@ -101 +119 @@
-<A>{A}{B}*	{ yylval = setsymtab(yytext, tostring(""), 0.0, STR, symtab); RETURN(VAR); }
+<A>{A}{B}*	{ yylval = (YYSTYPE)setsymtab(yytext, tostring(""), 0.0, STR, symtab); RETURN(VAR); }
@@ -131 +149 @@
-<str>\"		{ BEGIN A; cbuf[clen]=0; yylval = setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab); RETURN(STRING); }
+<str>\"		{ BEGIN A; cbuf[clen]=0; yylval = (YYSTYPE)setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab); RETURN(STRING); }
@@ -140 +158 @@
-<chc>"]"	{ BEGIN reg; cbuf[clen]=0; yylval = tostring(cbuf);
+<chc>"]"	{ BEGIN reg; cbuf[clen]=0; yylval = (YYSTYPE)tostring(cbuf);
@@ -148 +166,2 @@
-input()
+int
+input(void)
@@ -150 +169 @@
-	register c;
+	register int c;
@@ -153,3 +172 @@
-	if (yysptr > yysbuf)
-		c = U(*--yysptr);
-	else if (yyin == NULL)
+	if (lexprog != NULL)
@@ -166 +183,2 @@
-startreg()
+int
+startreg(void)
@@ -168,0 +187 @@
+	return(0);

% usr/src/cmd/awk/b.c
@@ -3,0 +4 @@
+int error(), overflo(), penter(), follow(), first(), notin(), cfoll(), freetr();
@@ -59,0 +61 @@
+int
@@ -82,0 +85 @@
+	return(0);
@@ -84,0 +88 @@
+int
@@ -106,0 +111 @@
+	return(0);
@@ -108,2 +113 @@
-char *cclenter(p)
-register char *p;
+char *cclenter(register char *p)
@@ -111 +115 @@
-	register i, c;
+	register int i, c;
@@ -139 +143,2 @@
-overflo()
+int
+overflo(void)
@@ -141,0 +147 @@
+	return(0);
@@ -144,2 +150,2 @@
-cfoll(v)		/* enter follow set of each leaf of vertex v into foll[leaf] */
-register node *v;
+int
+cfoll(register node *v)		/* enter follow set of each leaf of vertex v into foll[leaf] */
@@ -147 +153 @@
-	register i;
+	register int i;
@@ -149 +155 @@
-	int *add();
+	int *add(int n);
@@ -173,0 +180 @@
+	return(0);
@@ -176,2 +183,3 @@
-first(p)			/* collects initially active leaves of p into setvec */
-register node *p;		/* returns 0 or 1 depending on whether p matches empty string */
+int
+first(register node *p)			/* collects initially active leaves of p into setvec */
+				/* returns 0 or 1 depending on whether p matches empty string */
@@ -179 +187 @@
-	register b;
+	register int b;
@@ -210,2 +218,2 @@
-follow(v)
-node *v;		/* collects leaves that can follow v into setvec */
+int
+follow(node *v)		/* collects leaves that can follow v into setvec */
@@ -216 +224 @@
-		return;
+		return(0);
@@ -222 +230 @@
-				return;
+				return(0);
@@ -226 +234 @@
-				return;
+				return(0);
@@ -231 +239 @@
-						return;
+						return(0);
@@ -236 +244 @@
-				return;
+				return(0);
@@ -241 +249 @@
-				return;
+				return(0);
@@ -242,0 +251 @@
+	return(0);
@@ -245,2 +254,2 @@
-member(c, s)	/* is c in s? */
-register char c, *s;
+int
+member(register char c, register char *s)	/* is c in s? */
@@ -254,4 +263,4 @@
-notin(array, n, prev)		/* is setvec in array[0] thru array[n]? */
-int **array;
-int *prev; {
-	register i, j;
+int
+notin(int **array, int n, int *prev)		/* is setvec in array[0] thru array[n]? */
+{
+	register int i, j;
@@ -272 +281 @@
-int *add(n) {		/* remember setvec */
+int *add(int n) {		/* remember setvec */
@@ -274 +283 @@
-	register i;
+	register int i;
@@ -288 +297 @@
-struct fa *cgotofn()
+struct fa *cgotofn(void)
@@ -290 +299 @@
-	register i, k;
+	register int i, k;
@@ -300 +309 @@
-	int fatab[257];
+	int fatab[2*256+1];
@@ -308,3 +317,3 @@
-	char symbol[NCHARS];
-	char isyms[NCHARS];
-	char ssyms[NCHARS];
+	char symbol[256];
+	char isyms[256];
+	char ssyms[256];
@@ -314 +323 @@
-	for (i=0; i<NCHARS; i++)  isyms[i] = symbol[i] = 0;
+	for (i=0; i<256; i++)  isyms[i] = symbol[i] = 0;
@@ -328 +337 @@
-				k = (int) right(cp);
+				k = (int) right(cp) & 0377;
@@ -347,2 +356,2 @@
-						if (isyms[*p] != 1) {
-							isyms[*p] = 1;
+						if (isyms[(unsigned char)*p] != 1) {
+							isyms[(unsigned char)*p] = 1;
@@ -389 +398 @@
-					k = (int) right(cp);
+					k = (int) right(cp) & 0377;
@@ -408,2 +417,2 @@
-							if (isyms[*p] == 0 && symbol[*p] == 0) {
-								symbol[*p] = 1;
+							if (isyms[(unsigned char)*p] == 0 && symbol[(unsigned char)*p] == 0) {
+								symbol[(unsigned char)*p] = 1;
@@ -428 +437 @@
-			symbol[c] = 0;
+			symbol[(unsigned char)c] = 0;
@@ -435 +444 @@
-					if (k == CHAR && c == (int) right(cp)
+					if ((k == CHAR && c == (int) right(cp))
@@ -437,2 +446,2 @@
-					 || k == CCL && member(c, (char *) right(cp))
-					 || k == NCCL && !member(c, (char *) right(cp))) {
+					 || (k == CCL && member(c, (char *) right(cp)))
+					 || (k == NCCL && !member(c, (char *) right(cp)))) {
@@ -507,3 +516,2 @@
-match(pfa, p)
-register struct fa *pfa;
-register char *p;
+int
+match(register struct fa *pfa, register char *p)
@@ -511 +519 @@
-	register count;
+	register int count;

% usr/src/cmd/awk/lib.c
@@ -4,0 +5 @@
+int error(), fldbld(), setclvar(), member(), isnumber(), awkdigit();
@@ -17 +18 @@
-#define	FINIT	{0, NULL, 0.0, FLD|STR}
+#define	FINIT	{0, NULL, 0.0, FLD|STR, 0}
@@ -19 +20 @@
-	{ "$record", record, 0.0, STR|FLD},
+	{ "$record", record, 0.0, STR|FLD, 0},
@@ -31 +32,2 @@
-getrec()
+int
+getrec(void)
@@ -36 +38 @@
-	register c, sep;
+	register int c, sep;
@@ -87,2 +89,2 @@
-setclvar(s)	/* set var=value from s */
-char *s;
+int
+setclvar(char *s)	/* set var=value from s */
@@ -98,0 +101 @@
+	return(0);
@@ -101 +104,2 @@
-fldbld()
+int
+fldbld(void)
@@ -158,0 +163 @@
+	return(0);
@@ -161 +166,2 @@
-recbld()
+int
+recbld(void)
@@ -167 +173 @@
-		return;
+		return(0);
@@ -171 +177 @@
-		while (*r++ = *p++)
+		while ((*r++ = *p++))
@@ -181,0 +188 @@
+	return(0);
@@ -184 +191 @@
-cell *fieldadr(n)
+cell *fieldadr(int n)
@@ -193 +200,2 @@
-yyerror(s) char *s; {
+int
+yyerror(char *s) {
@@ -195,0 +204 @@
+	return(0);
@@ -198 +207,3 @@
-error(f, s, a1, a2, a3, a4, a5, a6, a7) {
+int
+error(int f, char *s, int a1, int a2, int a3, int a4, int a5, int a6, int a7)
+{
@@ -205,0 +217 @@
+	return(0);
@@ -208 +220,3 @@
-PUTS(s) char *s; {
+int
+PUTS(char *s) {
+	(void)s;
@@ -209,0 +224 @@
+	return(0);
@@ -214,2 +229,2 @@
-isnumber(s)
-register char *s;
+int
+isnumber(register char *s)
@@ -217 +232 @@
-	register d1, d2;
+	register int d1, d2;
@@ -228 +243 @@
-	if (!isdigit(*s) && *s != '.')
+	if (!awkdigit(*s) && *s != '.')
@@ -230 +245 @@
-	if (isdigit(*s)) {
+	if (awkdigit(*s)) {
@@ -234 +249 @@
-		} while (isdigit(*s));
+		} while (awkdigit(*s));
@@ -242 +257 @@
-	if (isdigit(*s)) {
+	if (awkdigit(*s)) {
@@ -246 +261 @@
-		} while (isdigit(*s));
+		} while (awkdigit(*s));
@@ -248 +263 @@
-	if (!(d1 || point && d2))
+	if (!(d1 || (point && d2)))
@@ -254 +269 @@
-		if (!isdigit(*s))
+		if (!awkdigit(*s))
@@ -259 +274 @@
-		} while (isdigit(*s));
+		} while (awkdigit(*s));
@@ -270,0 +286,7 @@
+}
+int
+awkdigit(int c)
+{
+	if(c >= '0' && c <= '9')
+		return(1);
+	return(0);

% usr/src/cmd/awk/main.c
@@ -3,0 +4 @@
+int logit(), syminit(), run(), msgfiles(), error(), yyparse();
@@ -10 +11 @@
-extern	errorflag;	/* non-zero if any syntax errors; set by yyerror */
+extern int	errorflag;	/* non-zero if any syntax errors; set by yyerror */
@@ -15 +16,2 @@
-main(argc, argv) int argc; char *argv[]; {
+int
+main(int argc, char *argv[]) {
@@ -71 +73 @@
-		write(ansfd, &errorflag, sizeof(errorflag));
+		write(ansfd, (char *)&errorflag, sizeof(errorflag));
@@ -77 +79,2 @@
-logit(n, s) char *s[];
+int
+logit(int n, char *s[])
@@ -82,3 +85,3 @@
-		return;
-	time(tvec);
-	fprintf(f, "%-8s %s", getlogin(), ctime(tvec));
+		return(0);
+	time((long *)tvec);
+	fprintf(f, "%-8s %s", getlogin(), ctime((long *)tvec));
@@ -90 +93 @@
-		return;
+		return(0);
@@ -94 +97 @@
-		return;
+		return(0);
@@ -99,0 +103 @@
+	return(0);
@@ -102 +106,2 @@
-yywrap()
+int
+yywrap(void)
@@ -107 +112,2 @@
-msgfiles()
+int
+msgfiles(void)
@@ -134 +140 @@
-	xargv=s=svargv=malloc(n*sizeof(char *));
+	xargv=s=svargv=(char **)malloc(n*sizeof(char *));
@@ -139,0 +146 @@
+	return(0);

% usr/src/cmd/awk/parse.c
@@ -4 +4,2 @@
-node *ALLOC(n)
+int error();
+node *ALLOC(int n)
@@ -11 +12 @@
-node *exptostat(a) node *a;
+node *exptostat(node *a)
@@ -17 +18 @@
-node *node0(a)
+node *node0(int a)
@@ -24 +25 @@
-node *node1(a,b) node *b;
+node *node1(int a, node *b)
@@ -32 +33 @@
-node *node2(a,b,c) node *b, *c;
+node *node2(int a, node *b, node *c)
@@ -41 +42 @@
-node *node3(a,b,c,d) node *b, *c, *d;
+node *node3(int a, node *b, node *c, node *d)
@@ -51 +52 @@
-node *node4(a,b,c,d,e) node *b, *c, *d, *e;
+node *node4(int a, node *b, node *c, node *d, node *e)
@@ -62 +63 @@
-node *stat3(a,b,c,d) node *b, *c, *d;
+node *stat3(int a, node *b, node *c, node *d)
@@ -68 +69 @@
-node *op2(a,b,c) node *b, *c;
+node *op2(int a, node *b, node *c)
@@ -74 +75 @@
-node *op1(a,b) node *b;
+node *op1(int a, node *b)
@@ -80 +81 @@
-node *stat1(a,b) node *b;
+node *stat1(int a, node *b)
@@ -86 +87 @@
-node *op3(a,b,c,d) node *b, *c, *d;
+node *op3(int a, node *b, node *c, node *d)
@@ -92 +93 @@
-node *stat2(a,b,c) node *b, *c;
+node *stat2(int a, node *b, node *c)
@@ -98 +99 @@
-node *stat4(a,b,c,d,e) node *b, *c, *d, *e;
+node *stat4(int a, node *b, node *c, node *d, node *e)
@@ -104 +105 @@
-node *valtonode(a, b) cell *a;
+node *valtonode(cell *a, int b)
@@ -106 +107 @@
-	x = node0(a);
+	x = node0((int)a);
@@ -111 +112 @@
-node *genjump(a)
+node *genjump(int a)
@@ -117 +118 @@
-node *pa2stat(a,b,c) node *a, *b, *c;
+node *pa2stat(node *a, node *b, node *c)
@@ -123 +124 @@
-node *linkum(a,b) node *a, *b;
+node *linkum(node *a, node *b)
@@ -131 +132 @@
-node *genprint()
+node *genprint(void)

% usr/src/cmd/awk/proc.c
@@ -0,0 +1,2 @@
+#include "stdio.h"
+#include <string.h>
@@ -2 +4 @@
-#define NULL 0
+char *tokname();
@@ -7 +9 @@
-} proc[] {
+} proc[] = {
@@ -56 +58 @@
-	{ 0, ""},
+	{ 0, "", ""},
@@ -60,0 +63 @@
+int
@@ -71 +74 @@
-	printf("obj (*proctab[%d])() {\n", SIZE);
+	printf("obj (*proctab[%d])() = {\n", SIZE);
@@ -76 +79 @@
-	printf("char *printname[%d] {\n", SIZE);
+	printf("char *printname[%d] = {\n", SIZE);
@@ -81,0 +85 @@
+	return(0);

% usr/src/cmd/awk/run.c
@@ -4,0 +5 @@
+#undef NULL
@@ -5,0 +7 @@
+int error(), fldbld(), tempfree(), redirprint(), getrec(), match(), freesymtab();
@@ -24,0 +27 @@
+int
@@ -35,0 +39 @@
+	(void)printname;
@@ -62,0 +67 @@
+int n;
@@ -64,0 +70 @@
+	(void)n;
@@ -94,0 +101 @@
+int n;
@@ -97,0 +105 @@
+	(void)n;
@@ -110,0 +119 @@
+	(void)i;
@@ -126,0 +136 @@
+int n;
@@ -137 +147 @@
-	if (n==MATCH && i==1 || n==NOTMATCH && i==0)
+	if ((n==MATCH && i==1) || (n==NOTMATCH && i==0))
@@ -143,0 +154 @@
+int n;
@@ -153,0 +165 @@
+		/* fallthrough */
@@ -174,0 +187 @@
+int n;
@@ -192,0 +206 @@
+		/* fallthrough */
@@ -207,0 +222 @@
+int
@@ -210 +225 @@
-	if (!istemp(a)) return;
+	if (!istemp(a)) return(0);
@@ -212,0 +228 @@
+	return(0);
@@ -232,0 +249 @@
+int n;
@@ -236,0 +254 @@
+	(void)n;
@@ -247,0 +266 @@
+int nnn;
@@ -251,0 +271 @@
+	(void)nnn;
@@ -286,0 +307 @@
+int nnn;
@@ -289,0 +311 @@
+	(void)nnn;
@@ -381,0 +404 @@
+int n;
@@ -385,0 +409 @@
+	(void)n;
@@ -397,0 +422 @@
+int n;
@@ -399 +424 @@
-	awkfloat i,j;
+	awkfloat i,j=0;
@@ -413,0 +439 @@
+		/* fallthrough */
@@ -440,0 +467 @@
+int n;
@@ -461,0 +489 @@
+int n;
@@ -504,0 +533 @@
+int q;
@@ -508,0 +538 @@
+	(void)q;
@@ -526,0 +557 @@
+int n;
@@ -528,0 +560 @@
+	(void)n;
@@ -541,0 +574 @@
+int n;
@@ -562,0 +596 @@
+int n;
@@ -564,0 +599 @@
+	(void)n;
@@ -576,0 +612 @@
+int nnn;
@@ -583,0 +620 @@
+	(void)nnn;
@@ -612,2 +649,2 @@
-			  || sep == ' ' && (*p == '\t' || *p == '\n')
-			  || sep == '\t' && *p == '\n')
+			  || (sep == ' ' && (*p == '\t' || *p == '\n'))
+			  || (sep == '\t' && *p == '\n'))
@@ -629,0 +667 @@
+int n;
@@ -631,0 +670 @@
+	(void)n;
@@ -645,0 +685 @@
+int n;
@@ -647,0 +688 @@
+	(void)n;
@@ -664,0 +706 @@
+int n;
@@ -666,0 +709 @@
+	(void)n;
@@ -687,0 +731 @@
+int n;
@@ -691,0 +736 @@
+	(void)n;
@@ -712,0 +758 @@
+	return(true);
@@ -715,0 +762 @@
+int n;
@@ -717,0 +765 @@
+	(void)a;
@@ -740,0 +789 @@
+int n;
@@ -743 +792 @@
-	awkfloat u;
+	awkfloat u=0;
@@ -744,0 +794 @@
+	(void)n;
@@ -766,0 +817 @@
+int n;
@@ -770,0 +822 @@
+	(void)n;
@@ -792 +844 @@
-obj nullproc() {}
+obj nullproc() { obj x = {0,0,0}; return(x); }
@@ -805 +857,2 @@
-redirprint(s, a, b) char *s; node *b;
+int
+redirprint(s, a, b) char *s; int a; node *b;
@@ -831,0 +885 @@
+	return(0);

% usr/src/cmd/awk/token.c
@@ -0,0 +1 @@
+#include "stdio.h"
@@ -6,76 +7,76 @@
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
@@ -83 +84,2 @@
-ptoken(n)
+int
+ptoken(int n)
@@ -87 +89 @@
-	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-257].tnm);
+	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-FIRSTTOKEN].tnm);
@@ -89 +91 @@
-	return;
+	return(0);
@@ -92 +94 @@
-char *tokname(n)
+char *tokname(int n)
@@ -96 +98 @@
-	return(tok[n-257].tnm);
+	return(tok[n-FIRSTTOKEN].tnm);

% usr/src/cmd/awk/tran.c
@@ -18,0 +19 @@
+int error(), recbld(), checkval(), hash(), isnumber();
@@ -20 +21,2 @@
-syminit()
+int
+syminit(void)
@@ -34,0 +37 @@
+	return(0);
@@ -37 +40 @@
-cell **makesymtab()
+cell **makesymtab(void)
@@ -42 +45 @@
-	cp = (char *) malloc(MAXSYM * sizeof(cell *));
+	cp = (cell **) malloc(MAXSYM * sizeof(cell *));
@@ -50,2 +53,2 @@
-freesymtab(ap)	/* free symbol table */
-cell *ap;
+int
+freesymtab(cell *ap)	/* free symbol table */
@@ -57 +60 @@
-		return;
+		return(0);
@@ -63 +66 @@
-			free(cp);
+			free((char *)cp);
@@ -66,0 +70 @@
+	return(0);
@@ -69,5 +73 @@
-cell *setsymtab(n, s, f, t, tab)
-char *n, *s;
-awkfloat f;
-unsigned t;
-cell **tab;
+cell *setsymtab(char *n, char *s, awkfloat f, unsigned t, cell **tab)
@@ -75 +75 @@
-	register h;
+	register int h;
@@ -77 +77 @@
-	cell *lookup();
+	cell *lookup(register char *s, cell **tab);
@@ -100,2 +100,2 @@
-hash(s)	/* form hash value for string s */
-register char *s;
+int
+hash(register char *s)	/* form hash value for string s */
@@ -110,3 +110 @@
-cell *lookup(s, tab)	/* look for s in tab */
-register char *s;
-cell **tab;
+cell *lookup(register char *s, cell **tab)	/* look for s in tab */
@@ -122,3 +120 @@
-awkfloat setfval(vp, f)
-register cell *vp;
-awkfloat f;
+awkfloat setfval(register cell *vp, awkfloat f)
@@ -137,3 +133 @@
-char *setsval(vp, s)
-register cell *vp;
-char *s;
+char *setsval(register cell *vp, char *s)
@@ -155,2 +149 @@
-awkfloat getfval(vp)
-register cell *vp;
+awkfloat getfval(register cell *vp)
@@ -181,2 +174 @@
-char *getsval(vp)
-register cell *vp;
+char *getsval(register cell *vp)
@@ -205,2 +197,2 @@
-checkval(vp)
-register cell *vp;
+int
+checkval(register cell *vp)
@@ -212,0 +205 @@
+	return(0);
@@ -215,2 +208 @@
-char *tostring(s)
-register char *s;
+char *tostring(register char *s)
@@ -227,2 +219,2 @@
-yfree(a) char *a;
-{
+int
+yfree(char *a) {
@@ -230,0 +223 @@
+	return(0);
@@ -235 +228 @@
-char *ymalloc(u) unsigned u;
+char *ymalloc(unsigned u)

% usr/src/cmd/basename.c
@@ -3,2 +3,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char *argv[])
@@ -27 +27 @@
-	puts(p2, stdout);
+	puts(p2);

% usr/src/cmd/bc.y
@@ -2 +2 @@
-	int *getout();
+	void getout(void);
@@ -3,0 +4 @@
+%define api.value.type {char *}
@@ -19 +20,24 @@
-int in;
+#include <stdarg.h>
+#include <stdint.h>
+#define bundle(...) (yyval = (bundle)(__VA_ARGS__))
+char *yyval;
+char *(bundle)(int i, ...);
+void routput(char *p);
+void output(char *p);
+void conout(char *p, char *s);
+void yyerror(char *s);
+void pp(char *s);
+void tp(char *s);
+void yyinit(int argc, char *argv[]);
+char *getf(char *p);
+char *geta(char *p);
+int yylex(void);
+int cpeek(int c, int yes, int no);
+int getch(void);
+int signal(int sig, int func);
+int pipe(int *fd);
+int fork(void);
+int close(int fd);
+int dup(int fd);
+int execl(char *path, char *arg0, ...);
+FILE *in;
@@ -33 +57 @@
-int *pre, *post;
+char *pre, *post;
@@ -38 +62 @@
-		= output( $2 );
+		{ output( $2 ); }
@@ -40 +64 @@
-		={	bundle( 6,pre, $7, post ,"0",numb[lev],"Q");
+		{	bundle( 6,pre, $7, post ,"0",numb[lev],"Q");
@@ -53 +77 @@
-		={ bundle(2, $1, "ps." ); }
+		{ bundle(2, $1, "ps." ); }
@@ -55 +79 @@
-		={ bundle(1, "" ); }
+		{ bundle(1, "" ); }
@@ -57 +81 @@
-		={ bundle(3,"[",$1,"]P");}
+		{ bundle(3,"[",$1,"]P");}
@@ -59 +83 @@
-		={ bundle(3, $3, "s", $1 ); }
+		{ bundle(3, $3, "s", $1 ); }
@@ -61 +85 @@
-		={ bundle(4, $6, $3, ":", geta($1)); }
+		{ bundle(4, $6, $3, ":", geta($1)); }
@@ -63 +87 @@
-		={ bundle(6, "l", $1, $3, $2, "s", $1 ); }
+		{ bundle(6, "l", $1, $3, $2, "s", $1 ); }
@@ -65 +89 @@
-		={ bundle(8,$3, ";", geta($1), $6, $5, $3, ":", geta($1));}
+		{ bundle(8,$3, ";", geta($1), $6, $5, $3, ":", geta($1));}
@@ -67 +91 @@
-		={ bundle(2, numb[lev-bstack[bindx-1]], "Q" ); }
+		{ bundle(2, numb[lev-bstack[bindx-1]], "Q" ); }
@@ -69 +93 @@
-		= bundle(4, $3, post, numb[lev], "Q" );
+		{ bundle(4, $3, post, numb[lev], "Q" ); }
@@ -71 +95 @@
-		= bundle(4, "0", post, numb[lev], "Q" );
+		{ bundle(4, "0", post, numb[lev], "Q" ); }
@@ -73 +97 @@
-		= bundle(4,"0",post,numb[lev],"Q");
+		{ bundle(4,"0",post,numb[lev],"Q"); }
@@ -75 +99 @@
-		= bundle(2, $3, "k");
+		{ bundle(2, $3, "k"); }
@@ -77 +101 @@
-		= bundle(4,"K",$3,$2,"k");
+		{ bundle(4,"K",$3,$2,"k"); }
@@ -79 +103 @@
-		= bundle(2,$3, "i");
+		{ bundle(2,$3, "i"); }
@@ -81 +105 @@
-		= bundle(4,"I",$3,$2,"i");
+		{ bundle(4,"I",$3,$2,"i"); }
@@ -83 +107 @@
-		= bundle(2,$3,"o");
+		{ bundle(2,$3,"o"); }
@@ -85 +109 @@
-		= bundle(4,"O",$3,$2,"o");
+		{ bundle(4,"O",$3,$2,"o"); }
@@ -87 +111 @@
-		={ $$ = $2; }
+		{ $$ = $2; }
@@ -89 +113 @@
-		={ bundle(1,"fY"); }
+		{ bundle(1,"fY"); }
@@ -91 +115 @@
-		={ bundle(1,"c"); }
+		{ bundle(1,"c"); }
@@ -93 +117 @@
-		={	conout( $7, $2 );
+		{	conout( $7, $2 );
@@ -97 +121 @@
-		={	bundle(3, $6, $4, $2 );
+		{	bundle(3, $6, $4, $2 );
@@ -102 +126 @@
-		={	bundle(5, $7, $5, "s.", $3, $2 );
+		{	bundle(5, $7, $5, "s.", $3, $2 );
@@ -107 +131 @@
-		={	bundle(3,$4,"S",$2); }
+		{	bundle(3,$4,"S",$2); }
@@ -111 +135 @@
-		={ $$ = "+"; }
+		{ $$ = "+"; }
@@ -113 +137 @@
-		={ $$ = "-"; }
+		{ $$ = "-"; }
@@ -115 +139 @@
-		={ $$ = "*"; }
+		{ $$ = "*"; }
@@ -117 +141 @@
-		={ $$ = "/"; }
+		{ $$ = "/"; }
@@ -119 +143 @@
-		={ $$ = "%%"; }
+		{ $$ = "%%"; }
@@ -121 +145 @@
-		={ $$ = "^"; }
+		{ $$ = "^"; }
@@ -125 +149 @@
-		={ $$ = $3; }
+		{ $$ = $3; }
@@ -129 +153 @@
-		={ --bindx; }
+		{ --bindx; }
@@ -134 +158 @@
-		={ bundle(2, $1, $3 ); }
+		{ bundle(2, $1, $3 ); }
@@ -138 +162 @@
-		={ln++;}
+		{ln++;}
@@ -143 +167 @@
-		= bundle(3, $1, $3, "=" );
+		{ bundle(3, $1, $3, "=" ); }
@@ -145 +169 @@
-		= bundle(3, $1, $3, ">" );
+		{ bundle(3, $1, $3, ">" ); }
@@ -147 +171 @@
-		= bundle(3, $1, $3, "<" );
+		{ bundle(3, $1, $3, "<" ); }
@@ -149 +173 @@
-		= bundle(3, $1, $3, "!=" );
+		{ bundle(3, $1, $3, "!=" ); }
@@ -151 +175 @@
-		= bundle(3, $1, $3, "!>" );
+		{ bundle(3, $1, $3, "!>" ); }
@@ -153 +177 @@
-		= bundle(3, $1, $3, "!<" );
+		{ bundle(3, $1, $3, "!<" ); }
@@ -155 +179 @@
-		= bundle(2, $1, " 0!=" );
+		{ bundle(2, $1, " 0!=" ); }
@@ -159 +183 @@
-		= bundle(3, $1, $3, "+" );
+		{ bundle(3, $1, $3, "+" ); }
@@ -161 +185 @@
-		= bundle(3, $1, $3, "-" );
+		{ bundle(3, $1, $3, "-" ); }
@@ -163 +187 @@
-		= bundle(3, " 0", $2, "-" );
+		{ bundle(3, " 0", $2, "-" ); }
@@ -165 +189 @@
-		= bundle(3, $1, $3, "*" );
+		{ bundle(3, $1, $3, "*" ); }
@@ -167 +191 @@
-		= bundle(3, $1, $3, "/" );
+		{ bundle(3, $1, $3, "/" ); }
@@ -169 +193 @@
-		= bundle(3, $1, $3, "%%" );
+		{ bundle(3, $1, $3, "%%" ); }
@@ -171 +195 @@
-		= bundle(3, $1, $3, "^" );
+		{ bundle(3, $1, $3, "^" ); }
@@ -173 +197 @@
-		={ bundle(3,$3, ";", geta($1)); }
+		{ bundle(3,$3, ";", geta($1)); }
@@ -175 +199 @@
-		= bundle(4, "l", $1, "d1+s", $1 );
+		{ bundle(4, "l", $1, "d1+s", $1 ); }
@@ -177 +201 @@
-		= bundle(4, "l", $2, "1+ds", $2 );
+		{ bundle(4, "l", $2, "1+ds", $2 ); }
@@ -179 +203 @@
-		= bundle(4, "l", $2, "1-ds", $2 );
+		{ bundle(4, "l", $2, "1-ds", $2 ); }
@@ -181 +205 @@
-		= bundle(4, "l", $1, "d1-s", $1 );
+		{ bundle(4, "l", $1, "d1-s", $1 ); }
@@ -183 +207 @@
-		= bundle(7,$3,";",geta($1),"d1+",$3,":",geta($1));
+		{ bundle(7,$3,";",geta($1),"d1+",$3,":",geta($1)); }
@@ -185 +209 @@
-		= bundle(7,$4,";",geta($2),"1+d",$4,":",geta($2));
+		{ bundle(7,$4,";",geta($2),"1+d",$4,":",geta($2)); }
@@ -187 +211 @@
-		= bundle(7,$3,";",geta($1),"d1-",$3,":",geta($1));
+		{ bundle(7,$3,";",geta($1),"d1-",$3,":",geta($1)); }
@@ -189 +213 @@
-		= bundle(7,$4,";",geta($2),"1-d",$4,":",geta($2));
+		{ bundle(7,$4,";",geta($2),"1-d",$4,":",geta($2)); }
@@ -191 +215 @@
-		= bundle(1,"Kd1+k");
+		{ bundle(1,"Kd1+k"); }
@@ -193 +217 @@
-		= bundle(1,"K1+dk");
+		{ bundle(1,"K1+dk"); }
@@ -195 +219 @@
-		= bundle(1,"Kd1-k");
+		{ bundle(1,"Kd1-k"); }
@@ -197 +221 @@
-		= bundle(1,"K1-dk");
+		{ bundle(1,"K1-dk"); }
@@ -199 +223 @@
-		= bundle(1,"Id1+i");
+		{ bundle(1,"Id1+i"); }
@@ -201 +225 @@
-		= bundle(1,"I1+di");
+		{ bundle(1,"I1+di"); }
@@ -203 +227 @@
-		= bundle(1,"Id1-i");
+		{ bundle(1,"Id1-i"); }
@@ -205 +229 @@
-		= bundle(1,"I1-di");
+		{ bundle(1,"I1-di"); }
@@ -207 +231 @@
-		= bundle(1,"Od1+o");
+		{ bundle(1,"Od1+o"); }
@@ -209 +233 @@
-		= bundle(1,"O1+do");
+		{ bundle(1,"O1+do"); }
@@ -211 +235 @@
-		= bundle(1,"Od1-o");
+		{ bundle(1,"Od1-o"); }
@@ -213 +237 @@
-		= bundle(1,"O1-do");
+		{ bundle(1,"O1-do"); }
@@ -215 +239 @@
-		= bundle(4, $3, "l", getf($1), "x" );
+		{ bundle(4, $3, "l", getf($1), "x" ); }
@@ -217 +241 @@
-		= bundle(3, "l", getf($1), "x" );
+		{ bundle(3, "l", getf($1), "x" ); }
@@ -219 +243 @@
-		={ bundle(2, " ", $1 ); }
+		{ bundle(2, " ", $1 ); }
@@ -221 +245 @@
-		={ bundle(2, " .", $2 ); }
+		{ bundle(2, " .", $2 ); }
@@ -223 +247 @@
-		={ bundle(4, " ", $1, ".", $3 ); }
+		{ bundle(4, " ", $1, ".", $3 ); }
@@ -225 +249 @@
-		={ bundle(3, " ", $1, "." ); }
+		{ bundle(3, " ", $1, "." ); }
@@ -227 +251 @@
-		={ $$ = "l."; }
+		{ $$ = "l."; }
@@ -229 +253 @@
-		= { bundle(2, "l", $1 ); }
+		{ bundle(2, "l", $1 ); }
@@ -231 +255 @@
-		={ bundle(3, $3, "ds", $1 ); }
+		{ bundle(3, $3, "ds", $1 ); }
@@ -233 +257 @@
-		={ bundle(6, "l", $1, $3, $2, "ds", $1 ); }
+		{ bundle(6, "l", $1, $3, $2, "ds", $1 ); }
@@ -235 +259 @@
-		= { bundle(5,$6,"d",$3,":",geta($1)); }
+		{ bundle(5,$6,"d",$3,":",geta($1)); }
@@ -237 +261 @@
-		= { bundle(9,$3,";",geta($1),$6,$5,"d",$3,":",geta($1)); }
+		{ bundle(9,$3,";",geta($1),$6,$5,"d",$3,":",geta($1)); }
@@ -239 +263 @@
-		= bundle(2,$3,"Z");
+		{ bundle(2,$3,"Z"); }
@@ -241 +265 @@
-		= bundle(2,$3,"X");	/* must be before '(' e ')' */
+		{ bundle(2,$3,"X"); }	/* must be before '(' e ')' */
@@ -243 +267 @@
-		= { $$ = $2; }
+		{ $$ = $2; }
@@ -245 +269 @@
-		={ bundle(1, "?" ); }
+		{ bundle(1, "?" ); }
@@ -247 +271 @@
-		={ bundle(2, $3, "v" ); }
+		{ bundle(2, $3, "v" ); }
@@ -249 +273 @@
-		={ bundle(2,"L",$2); }
+		{ bundle(2,"L",$2); }
@@ -251 +275 @@
-		= bundle(2,$3,"dk");
+		{ bundle(2,$3,"dk"); }
@@ -253 +277 @@
-		= bundle(4,"K",$3,$2,"dk");
+		{ bundle(4,"K",$3,$2,"dk"); }
@@ -255 +279 @@
-		= bundle(2,$3,"di");
+		{ bundle(2,$3,"di"); }
@@ -257 +281 @@
-		= bundle(4,"I",$3,$2,"di");
+		{ bundle(4,"I",$3,$2,"di"); }
@@ -259 +283 @@
-		= bundle(2,$3,"do");
+		{ bundle(2,$3,"do"); }
@@ -261 +285 @@
-		= bundle(4,"O",$3,$2,"do");
+		{ bundle(4,"O",$3,$2,"do"); }
@@ -263 +287 @@
-		= bundle(1,"K");
+		{ bundle(1,"K"); }
@@ -265 +289 @@
-		= bundle(1,"I");
+		{ bundle(1,"I"); }
@@ -267 +291 @@
-		= bundle(1,"O");
+		{ bundle(1,"O"); }
@@ -272 +296 @@
-		= bundle(2, $1, $3 );
+		{ bundle(2, $1, $3 ); }
@@ -276 +300 @@
-		=bundle(2,"l",geta($1));
+		{ bundle(2,"l",geta($1)); }
@@ -280 +304 @@
-		={ *cp++ = '\0'; }
+		{ *cp++ = '\0'; }
@@ -284 +308 @@
-		={ $$ = cp; *cp++ = '_'; }
+		{ $$ = cp; *cp++ = '_'; }
@@ -286 +310 @@
-		={ $$ = cp; *cp++ = $1; }
+		{ $$ = cp; *cp++ = *$1; }
@@ -288 +312 @@
-		={ *cp++ = $2; }
+		{ *cp++ = *$2; }
@@ -292,2 +316,2 @@
-		={ $$ = cp; *cp++ = crs++; *cp++ = '\0';
-			if(crs == '[')crs=+3;
+		{ $$ = cp; *cp++ = crs++; *cp++ = '\0';
+			if(crs == '[')crs+=3;
@@ -302 +326 @@
-		={	$$ = getf($2);
+		{	$$ = getf($2);
@@ -312 +336 @@
-		={ pp( $1 ); }
+		{ pp( $1 ); }
@@ -314 +338 @@
-		={ pp( $3 ); }
+		{ pp( $3 ); }
@@ -318 +342 @@
-		={ tp($1); }
+		{ tp($1); }
@@ -320 +344 @@
-		={ tp($3); }
+		{ tp($3); }
@@ -324 +348 @@
-		={ $$ = geta($1); }
+		{ $$ = geta($1); }
@@ -347 +371 @@
-yylex(){
+int yylex(void){
@@ -390,2 +414,2 @@
-	if( c>= '0' && c <= '9' || c>= 'A' && c<= 'F' ){
-		yylval = c;
+	if( (c>= '0' && c <= '9') || (c>= 'A' && c<= 'F') ){
+		yylval = index("0123456789ABCDEF", c);
@@ -434 +458 @@
-cpeek( c, yes, no ){
+int cpeek( int c, int yes, int no ){
@@ -442 +466 @@
-getch(){
+int getch(void){
@@ -460,0 +485 @@
+	goto loop;
@@ -463,2 +488,2 @@
-int b_space [ b_sp_max ];
-int * b_sp_nxt = { b_space };
+char *b_space [ b_sp_max ];
+char ** b_sp_nxt = { b_space };
@@ -467,2 +492,3 @@
-bundle(a){
-	int i, *p, *q;
+char *(bundle)(int i, ...){
+	va_list p;
+	char **q;
@@ -470,2 +496 @@
-	p = &a;
-	i = *p++;
+	va_start(p, i);
@@ -473 +498 @@
-	if( bdebug ) printf("bundle %d elements at %o\n",i,  q );
+	if( bdebug ) printf("bundle %d elements at %o\n",i, (unsigned)(uintptr_t)q );
@@ -476 +501 @@
-		* b_sp_nxt++ = *p++;
+		* b_sp_nxt++ = va_arg(p, char *);
@@ -477,0 +503 @@
+	va_end(p);
@@ -479,2 +505,2 @@
-	yyval = q;
-	return( q );
+	yyval = (char *)q;
+	return( yyval );
@@ -483,3 +509,3 @@
-routput(p) int *p; {
-	if( bdebug ) printf("routput(%o)\n", p );
-	if( p >= &b_space[0] && p < &b_space[b_sp_max]){
+void routput(char *p) {
+	if( bdebug ) printf("routput(%o)\n", (unsigned)(uintptr_t)p );
+	if( (uintptr_t)p - (uintptr_t)b_space < sizeof b_space ){
@@ -487 +513,2 @@
-		while( *p != 0 ) routput( *p++ );
+		char **q = (char **)p;
+		while( *q != 0 ) routput( *q++ );
@@ -492 +519 @@
-output( p ) int *p; {
+void output( char *p ) {
@@ -501 +528 @@
-conout( p, s ) int *p; char *s; {
+void conout( char *p, char *s ) {
@@ -509 +536 @@
-yyerror( s ) char *s; {
+void yyerror( char *s ) {
@@ -520 +547 @@
-pp( s ) char *s; {
+void pp( char *s ) {
@@ -529 +556 @@
-tp( s ) char *s; { /* same as pp, but for temps */
+void tp( char *s ) { /* same as pp, but for temps */
@@ -536,2 +563,2 @@
-yyinit(argc,argv) int argc; char *argv[];{
-	signal( 2, (int(*)())1 );	/* ignore all interrupts */
+void yyinit(int argc, char *argv[]){
+	signal( 2, 1 );	/* ignore all interrupts */
@@ -547 +574 @@
-int *getout(){
+void getout(void){
@@ -550 +577 @@
-	exit();
+	exit(0);
@@ -553,2 +580,2 @@
-int *
-getf(p) char *p;{
+char *
+getf(char *p){
@@ -557,2 +584,2 @@
-int *
-geta(p) char *p;{
+char *
+geta(char *p){
@@ -562,2 +589,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -572 +599 @@
-			exit();
+			exit(0);
@@ -577 +604 @@
-			exit();
+			exit(0);
@@ -589 +616 @@
-		exit();
+		exit(0);
@@ -595,2 +622,2 @@
-	execl("/bin/dc", "dc", "-", 0);
-	execl("/usr/bin/dc", "dc", "-", 0);
+	execl("/bin/dc", "dc", "-", (char *)0);
+	execl("/usr/bin/dc", "dc", "-", (char *)0);

% usr/src/cmd/cal.c
@@ -10,2 +10,8 @@
-main(argc, argv)
-char *argv[];
+int printf(char *fmt, ...);
+void exit(int n);
+int number(char *str);
+void pstr(char *str, int n);
+void cal(int m, int y, char *p, int w);
+int jan1(int yr);
+int
+main(int argc, char *argv[])
@@ -13 +19 @@
-	register y, i, j;
+	register int y, i, j;
@@ -71,2 +77,2 @@
-number(str)
-char *str;
+int
+number(char *str)
@@ -74 +80 @@
-	register n, c;
+	register int n, c;
@@ -79 +85 @@
-	while(c = *s++) {
+	while((c = *s++)) {
@@ -87,2 +93,2 @@
-pstr(str, n)
-char *str;
+void
+pstr(char *str, int n)
@@ -90 +96 @@
-	register i;
+	register int i;
@@ -113,2 +119,2 @@
-cal(m, y, p, w)
-char *p;
+void
+cal(int m, int y, char *p, int w)
@@ -116 +122 @@
-	register d, i;
+	register int d, i;
@@ -173 +179,2 @@
-jan1(yr)
+int
+jan1(int yr)
@@ -175 +182 @@
-	register y, d;
+	register int y, d;

% usr/src/cmd/calendar.c
@@ -7,0 +8 @@
+#include <stdio.h>
@@ -27,2 +28,3 @@
-tprint(t)
-long t;
+void tprint(long t);
+void
+tprint(long t)
@@ -36 +38,2 @@
-main()
+int
+main(void)
@@ -44,0 +48 @@
+		/* FALLTHROUGH */
@@ -47,0 +52 @@
+		/* FALLTHROUGH */

% usr/src/cmd/cat.c
@@ -11,2 +11,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char *argv[])
@@ -16,2 +16,2 @@
-	register c;
-	int dev, ino = -1;
+	register int c;
+	int dev = -1, ino = -1;
@@ -42 +42 @@
-		if (fflg || (*++argv)[0]=='-' && (*argv)[1]=='\0')
+		if (fflg || ((*++argv)[0]=='-' && (*argv)[1]=='\0'))

% usr/src/cmd/cb.c
@@ -1,0 +2,10 @@
+#define	puts	cb_puts
+#define	gets	cb_gets
+int	getch(void);
+int	lookup(char **tab);
+int	gotelse(void);
+int	getnl(void);
+int	ptabs(void);
+int	comment(void);
+int	puts(void);
+int	gets(void);
@@ -39,2 +49,2 @@
-main(argc,argv) int argc;
-char argv[];
+int
+main(int argc, char *argv[])
@@ -41,0 +52,2 @@
+	(void)argc;
+	(void)argv;
@@ -155 +167 @@
-			if(iflev > 0)
+			if(iflev > 0) {
@@ -159,0 +172 @@
+			}
@@ -259,0 +273 @@
+	return(0);
@@ -261 +275,2 @@
-ptabs(){
+int
+ptabs(void){
@@ -263,0 +279 @@
+	return(0);
@@ -265 +281,2 @@
-getch(){
+int
+getch(void){
@@ -271 +288,2 @@
-puts(){
+int
+puts(void){
@@ -290,0 +309 @@
+	return(0);
@@ -292,2 +311,2 @@
-lookup(tab)
-char *tab[];
+int
+lookup(char *tab[])
@@ -307 +326,2 @@
-gets(){
+int
+gets(void){
@@ -325 +345,2 @@
-gotelse(){
+int
+gotelse(void){
@@ -329,0 +351 @@
+	return(0);
@@ -331 +353,2 @@
-getnl(){
+int
+getnl(void){
@@ -352 +375,2 @@
-comment(){
+int
+comment(void){
@@ -363,0 +388 @@
+	return(0);

% usr/src/cmd/checkeq.c
@@ -8 +8,4 @@
-main(argc, argv) char **argv; {
+void check(FILE *f);
+int
+main(int argc, char **argv)
+{
@@ -33,2 +36,2 @@
-check(f)
-FILE	*f;
+void
+check(FILE *f)

% usr/src/cmd/chgrp.c
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
@@ -49,2 +50,2 @@
-	while(c = *s++)
-		if(!isdigit(c))
+	while ((c = *s++))
+		if (!isdigit(c))

% usr/src/cmd/chmod.c
@@ -22,0 +23,5 @@
+unsigned newmode(unsigned nm);
+int abs(void);
+int who(void);
+int what(void);
+int where(int om);
@@ -24,2 +29,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -27 +32 @@
-	register i;
+	register int i;
@@ -55,2 +60,2 @@
-newmode(nm)
-unsigned nm;
+unsigned
+newmode(unsigned nm)
@@ -58 +63 @@
-	register o, m, b;
+	register int o, m, b;
@@ -65 +70 @@
-		while (o = what()) {
+		while ((o = what())) {
@@ -88 +93,2 @@
-abs()
+int
+abs(void)
@@ -90 +96 @@
-	register c, i;
+	register int c, i;
@@ -99 +105,2 @@
-who()
+int
+who(void)
@@ -101 +108 @@
-	register m;
+	register int m;
@@ -125 +132,2 @@
-what()
+int
+what(void)
@@ -136,2 +144,2 @@
-where(om)
-register om;
+int
+where(int om)
@@ -139 +147 @@
-	register m;
+	register int m;

% usr/src/cmd/chown.c
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
@@ -46,2 +47,2 @@
-isnumber(s)
-char *s;
+int
+isnumber(char *s)
@@ -49 +50 @@
-	register c;
+	register int c;
@@ -51,2 +52,2 @@
-	while(c = *s++)
-		if(!isdigit(c))
+	while ((c = *s++))
+		if (!isdigit(c))

% usr/src/cmd/clri.c
@@ -6,0 +7 @@
+#include <stdio.h>
@@ -15,0 +17 @@
+int	isnumber(char *s);
@@ -17,2 +19,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -20 +22 @@
-	register i, f;
+	register int i, f;
@@ -22 +24,2 @@
-	int j, k;
+	int j;
+	unsigned k;
@@ -70,2 +73,2 @@
-isnumber(s)
-char *s;
+int
+isnumber(char *s)
@@ -73 +76 @@
-	register c;
+	register int c;
@@ -75 +78 @@
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
+main(int argc, char *argv[])
@@ -17 +17 @@
-	register c1, c2;
+	register int c1, c2;
@@ -108,2 +108,2 @@
-long otoi(s)
-char *s;
+long
+otoi(char *s)
@@ -118 +118 @@
-	while(isdigit(*s))
+	while(isdigit((unsigned char)*s))

% usr/src/cmd/col.c
@@ -19,0 +20,6 @@
+void outc(int c);
+void store(int lno);
+void fetch(int lno);
+void emit(char *s, int lineno);
+void incr(void);
+void decr(void);
@@ -21,2 +27,2 @@
-main (argc, argv)
-	int argc; char **argv;
+int
+main (int argc, char **argv)
@@ -162,2 +168,2 @@
-outc (c)
-	register char c;
+void
+outc (register int c)
@@ -208,3 +214,2 @@
-store (lno)
-{
-	char *malloc();
+void
+store (int lno)
@@ -211,0 +217 @@
+{
@@ -223 +229,2 @@
-fetch(lno)
+void
+fetch(int lno)
@@ -236,3 +243,2 @@
-emit (s, lineno)
-	char *s;
-	int lineno;
+void
+emit (char *s, int lineno)
@@ -294 +300,2 @@
-incr()
+void
+incr(void)
@@ -308 +315,2 @@
-decr()
+void
+decr(void)

% usr/src/cmd/comm.c
@@ -11,3 +11,7 @@
-FILE *openfil();
-main(argc,argv)
-char	*argv[];
+FILE *openfil(char *s);
+int rd(FILE *file, char *buf);
+void wr(char *str, int n);
+void copy(FILE *ibuf, char *lbuf, int n);
+int compare(char *a, char *b);
+int
+main(int argc, char *argv[])
@@ -93,3 +97,2 @@
-rd(file,buf)
-FILE *file;
-char *buf;
+int
+rd(FILE *file, char *buf)
@@ -112,2 +115,2 @@
-wr(str,n)
-	char	*str;
+void
+wr(char *str, int n)
@@ -132,3 +135,2 @@
-copy(ibuf,lbuf,n)
-FILE *ibuf;
-char *lbuf;
+void
+copy(FILE *ibuf, char *lbuf, int n)
@@ -143,2 +145,2 @@
-compare(a,b)
-	char	*a,*b;
+int
+compare(char *a, char *b)
@@ -155,2 +157,2 @@
-FILE *openfil(s)
-char *s;
+FILE *
+openfil(char *s)

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
@@ -23,0 +24,2 @@
+void	slp(), ex(), init();
+int	number();
@@ -24,0 +27 @@
+int
@@ -75,0 +79 @@
+int v;
@@ -109,0 +114 @@
+void
@@ -112 +117 @@
-	register i;
+	register int i;
@@ -120,0 +126 @@
+void
@@ -136,0 +143 @@
+void
@@ -139 +146 @@
-	register i, c;
+	register int i, c;
@@ -238,0 +246 @@
+int
@@ -240 +248 @@
-register c;
+register int c;
@@ -242 +250 @@
-	register n = 0;
+	register int n = 0;

% usr/src/cmd/crypt.c
@@ -13 +12,0 @@
-char	*getpass();
@@ -15,2 +14,2 @@
-setup(pw)
-char *pw;
+void
+setup(char *pw)
@@ -68,2 +67,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -71 +70 @@
-	register i, n1, n2;
+	register int i, n1, n2;

% usr/src/cmd/date.c
@@ -9,0 +10 @@
+#include <stdio.h>
@@ -14,0 +16,2 @@
+int	gtime(void);
+int	gp(int dfault);
@@ -38,2 +41,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -94 +97,2 @@
-gtime()
+int
+gtime(void)
@@ -152 +156,2 @@
-gp(dfault)
+int
+gp(int dfault)

% usr/src/cmd/dc/dc.c
@@ -4,3 +4,7 @@
-main(argc,argv)
-int argc;
-char *argv[];
+int init(), commnds(), readc(), unreadc(), pushp(), sdump(), chsign(),
+    subt(), eqk(), binop(), dscale(), release(), log2(), print(),
+    load(), seekc(), salterwd(), putwd(), command(), cond(),
+    more(), garbage(), ospace(), redef(), tenot(), oneot(), bigot(),
+    hexot(), onintr();
+int
+main(int argc, char *argv[])
@@ -9,0 +14 @@
+	return(0);
@@ -11 +16,2 @@
-commnds(){
+int
+commnds(void){
@@ -62 +68 @@
-			sunputc(p);
+			(void)sunputc(p);
@@ -395 +401 @@
-				for(n = 0;n < PTRSZ-1;n++)sputc(q,0);
+				for(n = 0;n < (int)PTRSZ-1;n++)sputc(q,0);
@@ -577,2 +583 @@
-div(ddivd,ddivr)
-struct blk *ddivd,*ddivr;
+div(struct blk *ddivd, struct blk *ddivr)
@@ -590 +595 @@
-		errorrt("divide by 0\n");
+		{printf("divide by 0\n"); return((struct blk *)1); }
@@ -697 +702,2 @@
-dscale(){
+int
+dscale(void){
@@ -727,2 +733 @@
-removr(p,n)
-struct blk *p;
+removr(struct blk *p, int n)
@@ -756,2 +761 @@
-sqrt(p)
-struct blk *p;
+sqrt(struct blk *p)
@@ -807,2 +811 @@
-exp(base,ex)
-struct blk *base,*ex;
+exp(struct blk *base, struct blk *ex)
@@ -861,3 +864,2 @@
-init(argc,argv)
-int argc;
-char *argv[];
+int
+init(int argc, char *argv[])
@@ -867,2 +869,2 @@
-	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
-		signal(SIGINT,onintr);
+	if (signal(SIGINT, (int)SIG_IGN) != (int)SIG_IGN)
+		signal(SIGINT,(int)onintr);
@@ -918 +920 @@
-	return;
+	return(0);
@@ -919,0 +922 @@
+int
@@ -922 +925 @@
-	signal(SIGINT,onintr);
+	signal(SIGINT,(int)onintr);
@@ -928,0 +932 @@
+	return(0);
@@ -930,2 +934,2 @@
-pushp(p)
-struct blk *p;
+int
+pushp(struct blk *p)
@@ -935 +939 @@
-		return;
+		return(0);
@@ -939 +943 @@
-	return;
+	return(0);
@@ -942 +946 @@
-pop(){
+pop(void){
@@ -950 +954 @@
-readin(){
+readin(void){
@@ -998,3 +1002 @@
-add0(p,ct)
-int ct;
-struct blk *p;
+add0(struct blk *p, int ct)
@@ -1023,2 +1025 @@
-mult(p,q)
-struct blk *p,*q;
+mult(struct blk *p, struct blk *q)
@@ -1078,2 +1079,2 @@
-chsign(p)
-struct blk *p;
+int
+chsign(struct blk *p)
@@ -1110 +1111 @@
-	return;
+	return(0);
@@ -1112 +1113,2 @@
-readc(){
+int
+readc(void){
@@ -1132,0 +1135 @@
+	return(0);
@@ -1134,2 +1137,2 @@
-unreadc(c)
-char c;
+int
+unreadc(int c)
@@ -1142 +1145 @@
-	return;
+	return(0);
@@ -1144,2 +1147,2 @@
-binop(c)
-char c;
+int
+binop(int c)
@@ -1147 +1150 @@
-	register struct blk *r;
+	register struct blk *r = 0;
@@ -1164 +1167 @@
-	return;
+	return(0);
@@ -1166,2 +1169,2 @@
-print(hptr)
-struct blk *hptr;
+int
+print(struct blk *hptr)
@@ -1181 +1184 @@
-			return;
+			return(0);
@@ -1188 +1191 @@
-		return;
+		return(0);
@@ -1192 +1195 @@
-	sunputc(p);
+	(void)sunputc(p);
@@ -1200 +1203 @@
-		return;
+		return(0);
@@ -1204 +1207 @@
-		return;
+		return(0);
@@ -1208 +1211 @@
-		return;
+		return(0);
@@ -1227 +1230 @@
-		return;
+		return(0);
@@ -1243 +1246 @@
-	return;
+	return(0);
@@ -1247,2 +1250 @@
-getdec(p,sc)
-struct blk *p;
+getdec(struct blk *p, int sc)
@@ -1278,2 +1280,2 @@
-tenot(p,sc)
-struct blk *p;
+int
+tenot(struct blk *p, int sc)
@@ -1295 +1297 @@
-		return;
+		return(0);
@@ -1325 +1327 @@
-	return;
+	return(0);
@@ -1327,3 +1329,2 @@
-oneot(p,sc,ch)
-struct blk *p;
-char ch;
+int
+oneot(struct blk *p, int sc, int ch)
@@ -1344 +1345 @@
-	return;
+	return(0);
@@ -1346,2 +1347,2 @@
-hexot(p,flg)
-struct blk *p;
+int
+hexot(struct blk *p, int flg)
@@ -1349,0 +1351 @@
+	(void)flg;
@@ -1354 +1356 @@
-		return;
+		return(0);
@@ -1360 +1362 @@
-		return;
+		return(0);
@@ -1363 +1365 @@
-	return;
+	return(0);
@@ -1365,2 +1367,2 @@
-bigot(p,flg)
-struct blk *p;
+int
+bigot(struct blk *p, int flg)
@@ -1409 +1411 @@
-			sunputc(strptr);
+			(void)sunputc(strptr);
@@ -1414 +1416 @@
-	return;
+	return(0);
@@ -1417,2 +1419 @@
-add(a1,a2)
-struct blk *a1,*a2;
+add(struct blk *a1, struct blk *a2)
@@ -1463 +1464,2 @@
-eqk(){
+int
+eqk(void){
@@ -1493,2 +1495 @@
-removc(p,n)
-struct blk *p;
+removc(struct blk *p, int n)
@@ -1515,2 +1516 @@
-scalint(p)
-struct blk *p;
+scalint(struct blk *p)
@@ -1524,2 +1524 @@
-scale(p,n)
-struct blk *p;
+scale(struct blk *p, int n)
@@ -1541 +1540,2 @@
-subt(){
+int
+subt(void){
@@ -1552 +1552,2 @@
-command(){
+int
+command(void){
@@ -1555 +1556 @@
-	register (*savint)(),pid,rpid;
+	register int (*savint)(),pid,rpid;
@@ -1574 +1575 @@
-		savint = signal(SIGINT, SIG_IGN);
+		savint = (int (*)())signal(SIGINT, (int)SIG_IGN);
@@ -1576 +1577 @@
-		signal(SIGINT,savint);
+		signal(SIGINT,(int)savint);
@@ -1581,2 +1582,2 @@
-cond(c)
-char c;
+int
+cond(int c)
@@ -1585 +1586 @@
-	register char cc;
+	register signed char cc;
@@ -1589 +1590 @@
-	sunputc(p);
+	(void)sunputc(p);
@@ -1615 +1616 @@
-		(cc >0) && (c == '>' || c == NL)){
+		((cc >0) && (c == '>' || c == NL))){
@@ -1622 +1623,2 @@
-load(){
+int
+load(void){
@@ -1653 +1655 @@
-	return;
+	return(0);
@@ -1655,2 +1657,2 @@
-log2(n)
-long n;
+int
+log2(long n)
@@ -1668,2 +1670 @@
-salloc(size)
-int size;
+salloc(int size)
@@ -1688 +1689 @@
-morehd(){
+morehd(void){
@@ -1713,3 +1714 @@
-copy(hptr,size)
-struct blk *hptr;
-int size;
+copy(struct blk *hptr, int size)
@@ -1741,3 +1740,2 @@
-sdump(s1,hptr)
-char *s1;
-struct blk *hptr;
+int
+sdump(char *s1, struct blk *hptr)
@@ -1749,0 +1748 @@
+	return(0);
@@ -1751,2 +1750,2 @@
-seekc(hptr,n)
-struct blk *hptr;
+int
+seekc(struct blk *hptr, int n)
@@ -1769 +1768 @@
-		return;
+		return(0);
@@ -1773 +1772 @@
-	return;
+	return(0);
@@ -1775,3 +1774,2 @@
-salterwd(hptr,n)
-struct wblk *hptr;
-struct blk *n;
+int
+salterwd(struct wblk *hptr, struct blk *n)
@@ -1782 +1780 @@
-	return;
+	return(0);
@@ -1784,2 +1782,2 @@
-more(hptr)
-struct blk *hptr;
+int
+more(struct blk *hptr)
@@ -1804 +1802 @@
-	return;
+	return(0);
@@ -1806,2 +1804,2 @@
-ospace(s)
-char *s;
+int
+ospace(char *s)
@@ -1813,0 +1812 @@
+	return(0);
@@ -1815,2 +1814,2 @@
-garbage(s)
-char *s;
+int
+garbage(char *s)
@@ -1822,0 +1822 @@
+	(void)s;
@@ -1859,0 +1860 @@
+	return(0);
@@ -1861,2 +1862,2 @@
-redef(p)
-struct blk *p;
+int
+redef(struct blk *p)
@@ -1864 +1865 @@
-	register offset;
+	register int offset;
@@ -1881,0 +1883 @@
+	return(0);
@@ -1884,2 +1886,2 @@
-release(p)
-register struct blk *p;
+int
+release(register struct blk *p)
@@ -1891,0 +1894 @@
+	return(0);
@@ -1895,2 +1898 @@
-getwd(p)
-struct blk *p;
+getwd(struct blk *p)
@@ -1906,2 +1908,2 @@
-putwd(p, c)
-struct blk *p, *c;
+int
+putwd(struct blk *p, struct blk *c)
@@ -1914,0 +1917 @@
+	return(0);
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
@@ -21,0 +22 @@
+#define DCSCHAR(c)	((signed char)(c))
@@ -30,3 +31,3 @@
-#define sgetc(p)	(((p)->rd==(p)->wt)?EOF:*(p)->rd++)
-#define slookc(p)	(((p)->rd==(p)->wt)?EOF:*(p)->rd)
-#define sbackc(p)	(((p)->rd==(p)->beg)?EOF:*(--(p)->rd))
+#define sgetc(p)	(((p)->rd==(p)->wt)?EOF:DCSCHAR(*(p)->rd++))
+#define slookc(p)	(((p)->rd==(p)->wt)?EOF:DCSCHAR(*(p)->rd))
+#define sbackc(p)	(((p)->rd==(p)->beg)?EOF:DCSCHAR(*(--(p)->rd)))
@@ -36 +37 @@
-#define sunputc(p)	(*( (p)->rd = --(p)->wt))
+#define sunputc(p)	(DCSCHAR(*( (p)->rd = --(p)->wt)))
@@ -112 +112,0 @@
-int	(*signal())();
@@ -114 +113,0 @@
-char	*malloc();
@@ -116 +114,0 @@
-char	*realloc();

% usr/src/cmd/dcheck.c
@@ -29,0 +30,4 @@
+int	check(char *file);
+int	pass1(struct dinode *ip);
+int	pass2(struct dinode *ip);
+int	bread(daddr_t bno, char *buf, int cnt);
@@ -31,0 +36 @@
+int	l3tol(long *lp, char *cp, int n);
@@ -33,2 +38,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -36 +41 @@
-	register i;
+	register int i;
@@ -65,2 +70,2 @@
-check(file)
-char *file;
+int
+check(char *file)
@@ -68,2 +73,2 @@
-	register i;
-	register j;
+	register int i;
+	register int j;
@@ -75 +80 @@
-		return;
+			return(0);
@@ -91 +96 @@
-	for (i=0; i<=nfiles; i++)
+	for (i=0; i<=(int)nfiles; i++)
@@ -117,0 +123 @@
+	return(0);
@@ -120,2 +126,2 @@
-pass1(ip)
-register struct dinode *ip;
+int
+pass1(register struct dinode *ip)
@@ -126 +132 @@
-	register i, j;
+	register int i, j;
@@ -132 +138 @@
-		return;
+		return(0);
@@ -142 +148 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -164,0 +171 @@
+	return(0);
@@ -167,2 +174,2 @@
-pass2(ip)
-register struct dinode *ip;
+int
+pass2(register struct dinode *ip)
@@ -170 +177 @@
-	register i;
+	register int i;
@@ -174 +181 @@
-		return;
+		return(0);
@@ -176 +183 @@
-		return;
+		return(0);
@@ -178 +185 @@
-		return;
+		return(0);
@@ -184,0 +192 @@
+	return(0);
@@ -187,3 +195,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+int
+bread(daddr_t bno, char *buf, int cnt)
@@ -191 +198 @@
-	register i;
+	register int i;
@@ -198,0 +206 @@
+	return(0);
@@ -203 +211 @@
-bmap(i)
+bmap(int i)
@@ -210 +218 @@
-	if(i > NINDIR) {
+	if(i > (int)NINDIR) {

% usr/src/cmd/dd.c
@@ -21 +21 @@
-char	*sbrk();
+char	*sbrk(int);
@@ -37,0 +38,10 @@
+void	flsh(void);
+int	match(char *s);
+int	number(int big);
+void	cnull(int cc);
+void	null(int c);
+void	ascii(int cc);
+void	ebcdic(int cc);
+void	ibm(int cc);
+void	term(void);
+void	stats(void);
@@ -143,8 +153,6 @@
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
+	void (*conv)();
+	register char *ip = 0;
+	register int c;
@@ -281 +289 @@
-		signal(SIGINT, term);
+		signal(SIGINT, (int)term);
@@ -345 +353,2 @@
-flsh()
+void
+flsh(void)
@@ -347 +356 @@
-	register c;
+	register int c;
@@ -362,2 +371,2 @@
-match(s)
-char *s;
+int
+match(char *s)
@@ -380 +389,2 @@
-number(big)
+int
+number(int big)
@@ -408,0 +419 @@
+		/* fallthrough */
@@ -419 +430,2 @@
-cnull(cc)
+void
+cnull(int cc)
@@ -421 +433 @@
-	register c;
+	register int c;
@@ -431 +443,2 @@
-null(c)
+void
+null(int c)
@@ -442 +455,2 @@
-ascii(cc)
+void
+ascii(int cc)
@@ -444 +458 @@
-	register c;
+	register int c;
@@ -469 +483,2 @@
-ebcdic(cc)
+void
+ebcdic(int cc)
@@ -471 +486 @@
-	register c;
+	register int c;
@@ -498 +513,2 @@
-ibm(cc)
+void
+ibm(int cc)
@@ -500 +516 @@
-	register c;
+	register int c;
@@ -527 +543,2 @@
-term()
+void
+term(void)
@@ -534 +551,2 @@
-stats()
+void
+stats(void)

% usr/src/cmd/deroff.c
@@ -33 +33 @@
-char chars[128];  /* SPECIAL, APOS, DIGIT, or LETTER */
+char chars[256];  /* SPECIAL, APOS, DIGIT, or LETTER */
@@ -51 +51 @@
-char *calloc();
+char *calloc(unsigned num, unsigned size);
@@ -52,0 +53,15 @@
+FILE *opn(register char *p);
+int skeqn(void);
+int eof(void);
+void getfname(void);
+void backsl(void);
+char *copys(register char *s);
+void fatal(char *s, char *p);
+void work(void);
+void regline(int macline);
+void putmac(register char *s);
+void putwords(int macline);
+void comline(void);
+void macro(void);
+void tbl(void);
+void eqn(void);
@@ -55,3 +70,2 @@
-main(ac, av)
-int ac;
-char **av;
+int
+main(int ac, char **av)
@@ -62 +75,0 @@
-FILE *opn();
@@ -107 +120,2 @@
-skeqn()
+int
+skeqn(void)
@@ -109 +123 @@
-while((c = getc(infile)) != rdelim)
+while((c = getc(infile)) != rdelim) {
@@ -112,2 +126,2 @@
-	else if(c == '"')
-		while( (c = getc(infile)) != '"')
+	else if(c == '"') {
+		while( (c = getc(infile)) != '"') {
@@ -116 +130 @@
-			else if(c == '\\')
+			else if(c == '\\') {
@@ -118,0 +133,4 @@
+			}
+		}
+	}
+}
@@ -123,2 +141,2 @@
-FILE *opn(p)
-register char *p;
+FILE *
+opn(register char *p)
@@ -138 +156,2 @@
-eof()
+int
+eof(void)
@@ -158 +177,2 @@
-getfname()
+void
+getfname(void)
@@ -164 +183,0 @@
-char *copys();
@@ -192,2 +211,2 @@
-fatal(s,p)
-char *s, *p;
+void
+fatal(char *s, char *p)
@@ -200 +219,2 @@
-work()
+void
+work(void)
@@ -215,2 +235,2 @@
-regline(macline)
-int macline;
+void
+regline(int macline)
@@ -242 +262 @@
-if(line[0] != '\0')
+if(line[0] != '\0') {
@@ -249,0 +270 @@
+}
@@ -254,2 +275,2 @@
-putmac(s)
-register char *s;
+void
+putmac(register char *s)
@@ -265 +286 @@
-	if(t>s+2 && chars[ s[0] ]==LETTER && chars[ s[1] ]==LETTER)
+	if(t>s+2 && chars[(unsigned char)s[0]]==LETTER && chars[(unsigned char)s[1]]==LETTER)
@@ -276,2 +297,2 @@
-putwords(macline)	/* break into words for -w option */
-int macline;
+void
+putwords(int macline)	/* break into words for -w option */
@@ -286 +307 @@
-	while( chars[*p1] < DIGIT)
+	while( chars[(unsigned char)*p1] < DIGIT)
@@ -289 +310 @@
-	for(p = p1 ; (i=chars[*p]) != SPECIAL ; ++p)
+	for(p = p1 ; (i=chars[(unsigned char)*p]) != SPECIAL ; ++p)
@@ -293 +314 @@
-	   || (macline && nlet>2 && chars[ p1[0] ]==LETTER && chars[ p1[1] ]==LETTER) )
+	   || (macline && nlet>2 && chars[(unsigned char)p1[0]]==LETTER && chars[(unsigned char)p1[1]]==LETTER) )
@@ -308 +329,2 @@
-comline()
+void
+comline(void)
@@ -363 +385,2 @@
-macro()
+void
+macro(void)
@@ -367 +390 @@
-	while(C!='.' || C!='.' || C=='.');	/* look for  .. */
+	while(C!='.' || C!='.' || C=='.');	look for  .. */
@@ -375 +398,2 @@
-tbl()
+void
+tbl(void)
@@ -382 +406,2 @@
-eqn()
+void
+eqn(void)
@@ -425 +450,2 @@
-backsl()	/* skip over a complete backslash construction */
+void
+backsl(void)	/* skip over a complete backslash construction */
@@ -449,0 +476 @@
+		/* fallthrough */
@@ -483,2 +510,2 @@
-char *copys(s)
-register char *s;
+char *
+copys(register char *s)
@@ -491 +518 @@
-while( *t++ = *s++ )
+while( (*t++ = *s++) )

% usr/src/cmd/df.c
@@ -9,2 +9 @@
-	"/dev/rp0",
-	"/dev/rp3",
+	"/dev/root",
@@ -18 +17,4 @@
-daddr_t	alloc();
+extern int	errno;
+daddr_t	alloc(void);
+void	dfree(char *file);
+void	bread(daddr_t bno, char *buf, int cnt);
@@ -20,2 +22,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -35,2 +37,2 @@
-dfree(file)
-char *file;
+void
+dfree(char *file)
@@ -55 +57 @@
-alloc()
+alloc(void)
@@ -83,3 +85,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+void
+bread(daddr_t bno, char *buf, int cnt)
@@ -88 +88,0 @@
-	extern errno;

% usr/src/cmd/diff.c
@@ -76 +75,0 @@
-FILE *fopen();
@@ -106 +105 @@
-char *mktemp();
+char *mktemp(char *as);
@@ -107,0 +107,22 @@
+void	done(void);
+char	*talloc(int n);
+char	*ralloc(char *p, int n);
+void	noroom(void);
+void	sort(struct line *a, int n);
+void	unsort(struct line *f, int l, int *b);
+void	filename(char **pa1, char **pa2);
+void	prepare(int i, char *arg);
+void	prune(void);
+void	equiv(struct line *a, int n, struct line *b, int m, int *c);
+int	stone(int *a, int n, int *b, int *c);
+int	newcand(int x, int y, int pred);
+int	search(int *c, int k, int y);
+void	unravel(int p);
+void	check(char **argv);
+int	skipline(int f);
+void	output(char **argv);
+void	change(int a, int b, int c, int d);
+void	range(int a, int b, char *separator);
+void	fetch(long *f, int a, int b, FILE *lb, char *s);
+int	readhash(FILE *f);
+void	mesg(char *s, char *t);
@@ -109 +130,2 @@
-done()
+void
+done(void)
@@ -115 +137 @@
-char *talloc(n)
+char *talloc(int n)
@@ -117 +139 @@
-	extern char *malloc();
+	extern char *malloc(unsigned n);
@@ -122,0 +145 @@
+	return(NULL);
@@ -125,2 +148 @@
-char *ralloc(p,n)	/*compacting reallocation */
-char *p;
+char *ralloc(char *p, int n)	/*compacting reallocation */
@@ -129 +151 @@
-	char *realloc();
+	char *realloc(char *p, unsigned n);
@@ -139 +161,2 @@
-noroom()
+void
+noroom(void)
@@ -145,2 +168,2 @@
-sort(a,n)	/*shellsort CACM #201*/
-struct line *a;
+void
+sort(struct line *a, int n)	/*shellsort CACM #201*/
@@ -149 +172 @@
-	register int j,m;
+	register int j,m = 0;
@@ -163,2 +186,2 @@
-				   aim->value == ai[0].value &&
-				   aim->serial > ai[0].serial)
+				   (aim->value == ai[0].value &&
+				    aim->serial > ai[0].serial))
@@ -177,3 +200,2 @@
-unsort(f, l, b)
-struct line *f;
-int *b;
+void
+unsort(struct line *f, int l, int *b)
@@ -191,2 +213,2 @@
-filename(pa1, pa2)
-char **pa1, **pa2;
+void
+filename(char **pa1, char **pa2)
@@ -202 +224,2 @@
-		while(*b1++ = *a1++) ;
+		while((*b1++ = *a1++))
+			;
@@ -205 +228 @@
-		while(*a1++ = *a2++)
+		while((*a1++ = *a2++))
@@ -210,4 +233,4 @@
-		signal(SIGHUP,done);
-		signal(SIGINT,done);
-		signal(SIGPIPE,done);
-		signal(SIGTERM,done);
+		signal(SIGHUP,(int)done);
+		signal(SIGINT,(int)done);
+		signal(SIGPIPE,(int)done);
+		signal(SIGTERM,(int)done);
@@ -225,2 +248,2 @@
-prepare(i, arg)
-char *arg;
+void
+prepare(int i, char *arg)
@@ -229 +252 @@
-	register j,h;
+	register int j,h;
@@ -235 +258 @@
-	for(j=0; h=readhash(input[i]);) {
+	for(j=0; (h=readhash(input[i]));) {
@@ -244 +267,2 @@
-prune()
+void
+prune(void)
@@ -246 +270 @@
-	register i,j;
+	register int i,j;
@@ -261,3 +285,2 @@
-equiv(a,n,b,m,c)
-struct line *a, *b;
-int *c;
+void
+equiv(struct line *a, int n, struct line *b, int m, int *c)
@@ -289,2 +312,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -358,4 +381,2 @@
-stone(a,n,b,c)
-int *a;
-int *b;
-int *c;
+int
+stone(int *a, int n, int *b, int *c)
@@ -399 +420,2 @@
-newcand(x,y,pred)
+int
+newcand(int x, int y, int pred)
@@ -410,2 +432,2 @@
-search(c, k, y)
-int *c;
+int
+search(int *c, int k, int y)
@@ -431 +453,2 @@
-unravel(p)
+void
+unravel(int p)
@@ -448,2 +471,2 @@
-check(argv)
-char **argv;
+void
+check(char **argv)
@@ -454 +477 @@
-	char c,d;
+	int c,d;
@@ -512 +535,2 @@
-skipline(f)
+int
+skipline(int f)
@@ -514 +538 @@
-	register i;
+	register int i;
@@ -519,2 +543,2 @@
-output(argv)
-char **argv;
+void
+output(char **argv)
@@ -551 +575,2 @@
-change(a,b,c,d)
+void
+change(int a, int b, int c, int d)
@@ -572,2 +597,2 @@
-range(a,b,separator)
-char *separator;
+void
+range(int a, int b, char *separator)
@@ -581,4 +606,2 @@
-fetch(f,a,b,lb,s)
-long *f;
-FILE *lb;
-char *s;
+void
+fetch(long *f, int a, int b, FILE *lb, char *s)
@@ -602,2 +625,2 @@
-readhash(f)
-FILE *f;
+int
+readhash(FILE *f)
@@ -607,2 +630,2 @@
-	register space;
-	register t;
+	register int space;
+	register int t;
@@ -641,2 +664,2 @@
-mesg(s,t)
-char *s, *t;
+void
+mesg(char *s, char *t)

% usr/src/cmd/diff3.c
@@ -45,2 +45,11 @@
-main(argc,argv)
-char **argv;
+int readin(char *name, struct diff *dd), number(char **lc), digit(int c);
+int getchange(FILE *b), getline(FILE *b), merge(int m1, int m2);
+int separate(char *s), change(int i, struct range *rold, int dup);
+int prange(struct range *rold);
+int keep(int i, struct range *rold, struct range *rnew);
+int skip(int i, int from, char *pr);
+int duplicate(struct range *r1, struct range *r2);
+int repos(int nchar), trouble(void);
+int edit(struct diff *diff, int dup, int j), edscript(int n);
+int
+main(int argc, char **argv)
@@ -48 +57 @@
-	register i,m,n;
+	register int i,m,n;
@@ -74,0 +84 @@
+	return(0);
@@ -85,3 +95,2 @@
-readin(name,dd)
-char *name;
-struct diff *dd;
+int
+readin(char *name, struct diff *dd)
@@ -89 +98 @@
-	register i;
+	register int i;
@@ -128,2 +137,2 @@
-number(lc)
-char **lc;
+int
+number(char **lc)
@@ -131 +140 @@
-	register nn;
+	register int nn;
@@ -138 +147,2 @@
-digit(c)
+int
+digit(int c)
@@ -143,2 +153,2 @@
-getchange(b)
-FILE *b;
+int
+getchange(FILE *b)
@@ -152,2 +162,2 @@
-getline(b)
-FILE *b;
+int
+getline(FILE *b)
@@ -155,2 +165,2 @@
-	register i, c;
-	for(i=0;i<sizeof(line)-1;i++) {
+	register int i, c;
+	for(i=0;i<(int)sizeof(line)-1;i++) {
@@ -169 +179,2 @@
-merge(m1,m2)
+int
+merge(int m1, int m2)
@@ -187 +198 @@
-		if(!t2||t1&&d1->new.to < d2->new.from) {
+		if(!t2 || (t1 && d1->new.to < d2->new.from)) {
@@ -199 +210 @@
-		if(!t1||t2&&d2->new.to < d1->new.from) {
+		if(!t1 || (t2 && d2->new.to < d1->new.from)) {
@@ -265,0 +277 @@
+	return(0);
@@ -268,2 +280,2 @@
-separate(s)
-char *s;
+int
+separate(char *s)
@@ -271,0 +284 @@
+	return(0);
@@ -278,2 +291,2 @@
-change(i,rold,dup)
-struct range *rold;
+int
+change(int i, struct range *rold, int dup)
@@ -285 +298 @@
-		return;
+		return(0);
@@ -287 +300 @@
-		return;
+		return(0);
@@ -290,0 +304 @@
+	return(0);
@@ -296,2 +310,2 @@
-prange(rold)
-struct range *rold;
+int
+prange(struct range *rold)
@@ -306,0 +321 @@
+	return(0);
@@ -314,2 +329,2 @@
-keep(i,rold,rnew)
-struct range *rold, *rnew;
+int
+keep(int i, struct range *rold, struct range *rnew)
@@ -317 +332 @@
-	register delta;
+	register int delta;
@@ -318,0 +334 @@
+	(void)rold;
@@ -322,0 +339 @@
+	return(0);
@@ -329,2 +346,2 @@
-skip(i,from,pr)
-char *pr;
+int
+skip(int i, int from, char *pr)
@@ -332 +349 @@
-	register j,n;
+	register int j,n;
@@ -347,2 +364,2 @@
-duplicate(r1,r2)
-struct range *r1, *r2;
+int
+duplicate(struct range *r1, struct range *r2)
@@ -350,2 +367,2 @@
-	register c,d;
-	register nchar;
+	register int c,d;
+	register int nchar;
@@ -367 +384 @@
-				return;
+				return(0);
@@ -375 +392,2 @@
-repos(nchar)
+int
+repos(int nchar)
@@ -377 +395 @@
-	register i;
+	register int i;
@@ -379,0 +398 @@
+	return(0);
@@ -382 +401,2 @@
-trouble()
+int
+trouble(void)
@@ -385,0 +406 @@
+	return(0);
@@ -390,2 +411,2 @@
-edit(diff,dup,j)
-struct diff *diff;
+int
+edit(struct diff *diff, int dup, int j)
@@ -406 +427,2 @@
-edscript(n)
+int
+edscript(int n)
@@ -408 +430 @@
-	register j,k;
+	register int j,k;
@@ -420,0 +443 @@
+	return(0);

% usr/src/cmd/diffh.c
@@ -17,0 +18,13 @@
+char	*getl(int f, long n);
+void	clrl(int f, long n);
+void	movstr(char *s, char *t);
+int	easysynch(void);
+int	output(int a, int b);
+void	change(long a, int b, long c, int d, char *s);
+void	range(long a, int b);
+int	cmp(char *s, char *t);
+FILE	*dopen(char *f1, char *f2);
+void	progerr(char *s);
+void	error(char *s, char *t);
+int	hardsynch(void);
+int	space(int c);
@@ -20,2 +33 @@
-char *getl(f,n)
-long n;
+char *getl(int f, long n)
@@ -24,2 +36 @@
-	char *malloc();
-	register delta, nt;
+	register int delta, nt;
@@ -42 +53 @@
-		if(t==NULL)
+		if(t==NULL) {
@@ -46,0 +58 @@
+		}
@@ -55,2 +67,2 @@
-clrl(f,n)
-long n;
+void
+clrl(int f, long n)
@@ -58 +70 @@
-	register i,j;
+	register int i,j;
@@ -66,2 +78,2 @@
-movstr(s,t)
-register char *s, *t;
+void
+movstr(register char *s, register char *t)
@@ -69 +81 @@
-	while(*t++= *s++)
+	while((*t++= *s++))
@@ -73,2 +85,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -77 +89 @@
-	FILE *dopen();
+	FILE *dopen(char *f1, char *f2);
@@ -103 +115 @@
-		return;
+		return(0);
@@ -111 +123,2 @@
-easysynch()
+int
+easysynch(void)
@@ -114 +127 @@
-	register k,m;
+	register int k,m;
@@ -143 +156,2 @@
-output(a,b)
+int
+output(int a, int b)
@@ -145 +159 @@
-	register i;
+	register int i;
@@ -174,3 +188,2 @@
-change(a,b,c,d,s)
-long a,c;
-char *s;
+void
+change(long a, int b, long c, int d, char *s)
@@ -184,2 +197,2 @@
-range(a,b)
-long a;
+void
+range(long a, int b)
@@ -195,2 +208,2 @@
-cmp(s,t)
-char *s,*t;
+int
+cmp(char *s, char *t)
@@ -201,3 +214,3 @@
-		if(bflag&&isspace(*s)&&isspace(*t)) {
-			while(isspace(*++s)) ;
-			while(isspace(*++t)) ;
+		if(bflag&&space(*s)&&space(*t)) {
+			while(space(*++s)) ;
+			while(space(*++t)) ;
@@ -213,2 +226,9 @@
-FILE *dopen(f1,f2)
-char *f1,*f2;
+int
+space(int c)
+{
+	if(c==' ' || c=='\t' || c=='\n' || c=='\r' || c=='\f' || c=='\v')
+		return(1);
+	return(0);
+}
+FILE *
+dopen(char *f1, char *f2)
@@ -219 +239 @@
-	if(cmp(f1,"-")==0)
+	if(cmp(f1,"-")==0) {
@@ -223,0 +244 @@
+	}
@@ -227 +248,2 @@
-		for(bptr=b;*bptr= *f1++;bptr++) ;
+		for(bptr=b;(*bptr= *f1++);bptr++)
+			;
@@ -232 +254,2 @@
-		while(*bptr++= *f2++) ;
+		while((*bptr++= *f2++))
+			;
@@ -242,2 +265,2 @@
-progerr(s)
-char *s;
+void
+progerr(char *s)
@@ -248,2 +271,2 @@
-error(s,t)
-char *s,*t;
+void
+error(char *s, char *t)
@@ -256 +279,2 @@
-hardsynch()
+int
+hardsynch(void)

% usr/src/cmd/dmesg.c
@@ -12,0 +13 @@
+#define KMSGBASE	0x7fff0000U
@@ -20,2 +21,2 @@
-	{"_msgbuf"},
-	{"_msgbufp"}
+	{"_msgbuf",  0, 0},
+	{"_msgbufp", 0, 0}
@@ -24,2 +25,5 @@
-main(argc, argv)
-char **argv;
+int done(char *);
+int pdate(void);
+int readlive(int);
+int
+main(int argc, char **argv)
@@ -29,0 +34 @@
+	int live;
@@ -45,0 +51 @@
+	live = 0;
@@ -47,6 +53,21 @@
-	read(mem, msgbuf, MSGBUFS);
-	lseek(mem, (long)nl[1].n_value, 0);
-	read(mem, (char *)&msgbufp, sizeof(msgbufp));
-	if (msgbufp < (char *)nl[0].n_value || msgbufp >= (char *)nl[0].n_value+MSGBUFS)
-		done("Namelist mismatch\n");
-	msgbufp += msgbuf - (char *)nl[0].n_value;
+	if (read(mem, msgbuf, MSGBUFS) != MSGBUFS) {
+		if (readlive(mem) < 0)
+			done("Namelist mismatch\n");
+		live = 1;
+	}
+	if (!live) {
+		lseek(mem, (long)nl[1].n_value, 0);
+		if (read(mem, (char *)&msgbufp, sizeof(msgbufp)) != sizeof(msgbufp)) {
+			if (readlive(mem) < 0)
+				done("Namelist mismatch\n");
+			live = 1;
+		}
+	}
+	if (!live &&
+	    (msgbufp < (char *)nl[0].n_value || msgbufp >= (char *)nl[0].n_value+MSGBUFS)) {
+		if (readlive(mem) < 0)
+			done("Namelist mismatch\n");
+		live = 1;
+	}
+	if (!live)
+		msgbufp += msgbuf - (char *)nl[0].n_value;
@@ -84,2 +105,16 @@
-done(s)
-char *s;
+int
+readlive(int mem)
+{
+	unsigned int idx;
+	lseek(mem, (long)KMSGBASE, 0);
+	if (read(mem, (char *)&idx, sizeof(idx)) != sizeof(idx))
+		return(-1);
+	if (idx >= MSGBUFS)
+		return(-1);
+	if (read(mem, msgbuf, MSGBUFS) != MSGBUFS)
+		return(-1);
+	msgbufp = &msgbuf[idx];
+	return(0);
+}
+int
+done(char *s)
@@ -99,0 +135 @@
+	return(0);
@@ -102 +138,2 @@
-pdate()
+int
+pdate(void)
@@ -104,2 +141,2 @@
-	extern char *ctime();
-	static firstime;
+	extern char *ctime(long *t);
+	static int firstime;
@@ -112,0 +150 @@
+	return(0);

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
@@ -39,3 +39,3 @@
-char	*ctime();
-char	*prdate();
-long	atol();
+char	*ctime(long *t);
+char	*prdate(time_t d);
+long	atol(register char *p);
@@ -46,7 +46,15 @@
-int	mark();
-int	add();
-int	dump();
-int	tapsrec();
-int	dmpspc();
-int	dsrch();
-int	nullf();
+int	mark(struct dinode *ip);
+int	add(struct dinode *ip);
+int	dump(struct dinode *ip);
+int	tapsrec(daddr_t d);
+int	dmpspc(daddr_t *dp, int n);
+int	dsrch(daddr_t d);
+int	nullf(void);
+int	pass(int (*fn)(), short *map), otape(void);
+int	bread(daddr_t da, char *ba, int c), spclrec(void);
+int	bitmap(short *map, int typ), bmapest(short *map);
+int	CLR(register short *map), getitime(void), putitime(void);
+int	est(struct dinode *ip);
+int	indir(daddr_t d, int (*fn1)(), int (*fn2)(), int n);
+int	flusht(void), taprec(char *dp);
+int	l3tol(long *lp, char *cp, int n);
@@ -58,2 +66,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -62 +70 @@
-	register i;
+	register int i;
@@ -175,3 +183,2 @@
-pass(fn, map)
-int (*fn)();
-short *map;
+int
+pass(int (*fn)(), short *map)
@@ -179,2 +186,2 @@
-	register i, j;
-	int bits;
+	register int i, j;
+	int bits = 0;
@@ -210,0 +218 @@
+	return(0);
@@ -213,3 +221,2 @@
-icat(ip, fn1, fn2)
-struct	dinode	*ip;
-int (*fn1)(), (*fn2)();
+int
+icat(struct dinode *ip, int (*fn1)(), int (*fn2)())
@@ -217 +224 @@
-	register i;
+	register int i;
@@ -228,0 +236 @@
+	return(0);
@@ -231,3 +239,2 @@
-indir(d, fn1, fn2, n)
-daddr_t d;
-int (*fn1)(), (*fn2)();
+int
+indir(daddr_t d, int (*fn1)(), int (*fn2)(), int n)
@@ -235 +242 @@
-	register i;
+	register int i;
@@ -242 +249 @@
-		for(i=0; i<NINDIR; i++) {
+		for(i=0; i<(int)NINDIR; i++) {
@@ -249 +256 @@
-		for(i=0; i<NINDIR; i++) {
+		for(i=0; i<(int)NINDIR; i++) {
@@ -254,0 +262 @@
+	return(0);
@@ -257,2 +265,2 @@
-mark(ip)
-struct dinode *ip;
+int
+mark(struct dinode *ip)
@@ -260 +268 @@
-	register f;
+	register int f;
@@ -264 +272 @@
-		return;
+		return(0);
@@ -272 +280 @@
-			return;
+			return(0);
@@ -274,0 +283 @@
+	return(0);
@@ -277,2 +286,2 @@
-add(ip)
-struct dinode *ip;
+int
+add(struct dinode *ip)
@@ -282 +291 @@
-		return;
+		return(0);
@@ -293,0 +303 @@
+	return(0);
@@ -296,2 +306,2 @@
-dump(ip)
-struct dinode *ip;
+int
+dump(struct dinode *ip)
@@ -299 +309 @@
-	register i;
+	register int i;
@@ -312 +322 @@
-		return;
+		return(0);
@@ -314,0 +325 @@
+	return(0);
@@ -317,2 +328,2 @@
-dmpspc(dp, n)
-daddr_t *dp;
+int
+dmpspc(daddr_t *dp, int n)
@@ -320 +331 @@
-	register i, t;
+	register int i, t;
@@ -329,0 +341 @@
+	return(0);
@@ -332,2 +344,2 @@
-bitmap(map, typ)
-short *map;
+int
+bitmap(short *map, int typ)
@@ -335 +347 @@
-	register i, n;
+	register int i, n;
@@ -343 +355 @@
-		return;
+		return(0);
@@ -351,0 +364 @@
+	return(0);
@@ -354 +367,2 @@
-spclrec()
+int
+spclrec(void)
@@ -356 +370 @@
-	register i, *ip, s;
+	register int i, *ip, s;
@@ -363 +377 @@
-	for(i=0; i<BSIZE/sizeof(*ip); i++)
+	for(i=0; i<(int)(BSIZE/sizeof(*ip)); i++)
@@ -366,0 +381 @@
+	return(0);
@@ -369,2 +384,2 @@
-dsrch(d)
-daddr_t d;
+int
+dsrch(daddr_t d)
@@ -373 +388 @@
-	register i;
+	register int i;
@@ -378 +393 @@
-		return;
+		return(0);
@@ -380 +395 @@
-	for(i=0; i<DIRPB; i++) {
+	for(i=0; i<(int)DIRPB; i++) {
@@ -393 +408 @@
-			return;
+			return(0);
@@ -397,0 +413 @@
+	return(0);
@@ -400 +416,2 @@
-nullf()
+int
+nullf(void)
@@ -401,0 +419 @@
+	return(0);
@@ -404,3 +422,2 @@
-bread(da, ba, c)
-daddr_t da;
-char *ba;
+int
+bread(daddr_t da, char *ba, int c)
@@ -408 +425 @@
-	register n;
+	register int n;
@@ -413,0 +431 @@
+	return(0);
@@ -416,2 +434,2 @@
-CLR(map)
-register short *map;
+int
+CLR(register short *map)
@@ -419 +437 @@
-	register n;
+	register int n;
@@ -424,0 +443 @@
+	return(0);
@@ -432,2 +451,2 @@
-taprec(dp)
-char *dp;
+int
+taprec(char *dp)
@@ -435 +454 @@
-	register i;
+	register int i;
@@ -443,0 +463 @@
+	return(0);
@@ -446,2 +466,2 @@
-tapsrec(d)
-daddr_t d;
+int
+tapsrec(daddr_t d)
@@ -451 +471 @@
-		return;
+		return(0);
@@ -456,0 +477 @@
+	return(0);
@@ -459 +480,2 @@
-flusht()
+int
+flusht(void)
@@ -462 +484 @@
-	register i, si;
+	register int i, si;
@@ -490,0 +513 @@
+	return(0);
@@ -493 +516,2 @@
-otape()
+int
+otape(void)
@@ -504,0 +529 @@
+	return(0);
@@ -508,2 +533 @@
-prdate(d)
-time_t d;
+prdate(time_t d)
@@ -520 +544,2 @@
-getitime()
+int
+getitime(void)
@@ -522 +547 @@
-	register i, df;
+	register int i, df;
@@ -545 +570 @@
-		return;
+		return(0);
@@ -561 +586,2 @@
-putitime()
+int
+putitime(void)
@@ -563 +589 @@
-	register i, n, df;
+	register int i, n, df;
@@ -568 +594 @@
-		return;
+		return(0);
@@ -608,0 +635 @@
+	return(0);
@@ -611,2 +638,2 @@
-est(ip)
-struct dinode *ip;
+int
+est(struct dinode *ip)
@@ -623,0 +651 @@
+	return(0);
@@ -626,2 +654,2 @@
-bmapest(map)
-short *map;
+int
+bmapest(short *map)
@@ -629 +657 @@
-	register i, n;
+	register int i, n;
@@ -636 +664 @@
-		return;
+		return(0);
@@ -638,0 +667 @@
+	return(0);

% usr/src/cmd/dumpdir.c
@@ -51,2 +51,26 @@
-main(argc, argv)
-char *argv[];
+struct spcl;
+int	readhdr(struct spcl *b);
+int	checkvol(struct spcl *b, int t);
+int	pass1(void);
+int	printem(char *prefix, ino_t inum);
+int	gethead(struct spcl *buf);
+int	checktype(struct spcl *b, int t);
+int	readbits(short *m);
+int	flsh(void);
+int	getfile(ino_t n, int (*f1)(), int (*f2)(), long size);
+int	putent(char *cp);
+int	mseek(daddr_t pt);
+int	getent(char *bf);
+int	direq(char *s1, char *s2);
+int	search(ino_t inum);
+int	readtape(char *b);
+int	clearbuf(char *cp);
+int	flsht(void);
+int	copy(char *f, char *t, int s);
+int	writec(int c);
+int	readc(void);
+int	checksum(int *b);
+int	putdir(char *b);
+int	null(void);
+int
+main(int argc, char *argv[])
@@ -54 +78 @@
-	extern char *ctime();
+	extern char *ctime(long *t);
@@ -86 +110 @@
-	i = 0;
+int	i = 0;
@@ -91 +115,2 @@
-pass1()
+int
+pass1(void)
@@ -93 +118 @@
-	register i;
+	register int i;
@@ -95 +120 @@
-	int	putdir(), null();
+	int	putdir(char *b), null(void);
@@ -113 +138 @@
-			return;
+			return(0);
@@ -127,3 +152,2 @@
-printem(prefix, inum)
-char *prefix;
-ino_t	inum;
+int
+printem(char *prefix, ino_t inum)
@@ -139 +163 @@
-	return;
+	return(0);
@@ -145 +169 @@
-			return;
+			return(0);
@@ -169,4 +193,2 @@
-getfile(n, f1, f2, size)
-ino_t	n;
-int	(*f2)(), (*f1)();
-long	size;
+int
+getfile(ino_t n, int (*f1)(), int (*f2)(), long size)
@@ -174 +196 @@
-	register i;
+	register int i;
@@ -177,0 +200 @@
+	(void)n;
@@ -187 +210 @@
-			return;
+			return(0);
@@ -205 +228 @@
-				return;
+				return(0);
@@ -215,2 +238,2 @@
-readtape(b)
-char *b;
+int
+readtape(char *b)
@@ -218 +241 @@
-	register i;
+	register int i;
@@ -249 +272 @@
-			return;
+			return(0);
@@ -252,0 +276 @@
+	return(0);
@@ -255 +279,2 @@
-flsht()
+int
+flsht(void)
@@ -257,0 +283 @@
+	return(0);
@@ -260,2 +286,2 @@
-copy(f, t, s)
-register char *f, *t;
+int
+copy(register char *f, register char *t, int s)
@@ -263 +289 @@
-	register i;
+	register int i;
@@ -268,0 +295 @@
+	return(0);
@@ -271,2 +298,2 @@
-clearbuf(cp)
-register char *cp;
+int
+clearbuf(register char *cp)
@@ -274 +301 @@
-	register i;
+	register int i;
@@ -279,0 +307 @@
+	return(0);
@@ -286,2 +314,2 @@
-putent(cp)
-char	*cp;
+int
+putent(char *cp)
@@ -289 +317 @@
-	register i;
+	register int i;
@@ -291 +319 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -296 +324 @@
-			return;
+			return(0);
@@ -298 +326 @@
-	return;
+	return(0);
@@ -301,2 +329,2 @@
-getent(bf)
-register char *bf;
+int
+getent(register char *bf)
@@ -304 +332 @@
-	register i;
+	register int i;
@@ -306 +334 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -310,2 +338,2 @@
-			return;
-	return;
+			return(0);
+	return(0);
@@ -317,2 +345,2 @@
-writec(c)
-char c;
+int
+writec(int c)
@@ -319,0 +348 @@
+	char cc = c;
@@ -321 +350,2 @@
-	fwrite(&c, 1, 1, df);
+	fwrite(&cc, 1, 1, df);
+	return(0);
@@ -324 +354,2 @@
-readc()
+int
+readc(void)
@@ -332,2 +363,2 @@
-mseek(pt)
-daddr_t pt;
+int
+mseek(daddr_t pt)
@@ -335,0 +367 @@
+	return(0);
@@ -338 +370,2 @@
-flsh()
+int
+flsh(void)
@@ -340,0 +374 @@
+	return(0);
@@ -347,2 +381,2 @@
-search(inum)
-ino_t	inum;
+int
+search(ino_t inum)
@@ -350 +384 @@
-	register low, high, probe;
+	register int low, high, probe;
@@ -368,2 +402,2 @@
-direq(s1, s2)
-register char *s1, *s2;
+int
+direq(register char *s1, register char *s2)
@@ -371 +405 @@
-	register i;
+	register int i;
@@ -386,2 +420,2 @@
-gethead(buf)
-struct spcl *buf;
+int
+gethead(struct spcl *buf)
@@ -398,3 +432,2 @@
-checktype(b, t)
-struct	spcl *b;
-int	t;
+int
+checktype(struct spcl *b, int t)
@@ -406,2 +439,2 @@
-checksum(b)
-int *b;
+int
+checksum(int *b)
@@ -409 +442 @@
-	register i, j;
+	register int i, j;
@@ -423,3 +456,2 @@
-checkvol(b, t)
-struct spcl *b;
-int t;
+int
+checkvol(struct spcl *b, int t)
@@ -432,2 +464,2 @@
-readhdr(b)
-struct	spcl *b;
+int
+readhdr(struct spcl *b)
@@ -442,2 +474,2 @@
-putdir(b)
-char *b;
+int
+putdir(char *b)
@@ -446 +478 @@
-	register i;
+	register int i;
@@ -452,0 +485 @@
+	return(0);
@@ -458,2 +491,2 @@
-readbits(m)
-short	*m;
+int
+readbits(short *m)
@@ -461 +494 @@
-	register i;
+	register int i;
@@ -470,0 +504 @@
+	return(0);
@@ -473 +507 @@
-null() { ; }
+int null(void) { return(0); }

% usr/src/cmd/echo.c
@@ -3,3 +3,2 @@
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])

% usr/src/cmd/ed.c
@@ -7,0 +8,3 @@
+#define	puts	u_puts
+#include <stdio.h>
+#undef	puts
@@ -13,0 +17 @@
+#undef	EOF
@@ -101,2 +105,61 @@
-main(argc, argv)
-char **argv;
+int	commands(void);
+int	*address(void);
+void	setdot(void);
+void	setall(void);
+void	setnoaddr(void);
+void	nonzero(void);
+void	newline(void);
+void	filename(int comm);
+void	exfile(void);
+int	error(char *s);
+void	exitsh(void);
+void	rmtemp(void);
+void	fcomp(void);
+void	dechain(void);
+void	execexp(void);
+int	dosub(void);
+int	arout(void);
+int	command(int *aaddr1);
+int	advance(char *lp, char *ep);
+int	append(int (*f)(void), int *a);
+int	backref(int i, char *lp);
+int	blkio(int b, char *buf, int (*iofcn)());
+int	callunix(void);
+int	cclass(char *set, int c, int af);
+int	compile(int aeof);
+int	compsub(void);
+int	crblock(char *permp, char *buf, int nchar, long startn);
+int	crinit(char *crypt_password, char *block);
+int	delete(void);
+int	execute(int gf, int *addr);
+int	getchr(void);
+int	getcopy(void);
+int	getfile(void);
+int	getsub(void);
+int	gettty(void);
+int	global(int k);
+int	init(void);
+int	join(void);
+int	move(int cflag);
+int	onhup(int sig);
+int	onintr(int sig);
+char	*place(char *sp, char *l1, char *l2);
+int	putchr(int ac);
+int	putd(void);
+int	putfile(void);
+int	puts1(char *sp);
+int	putst(char *sp);
+int	quit(int sig);
+int	reverse(int *a1, int *a2);
+int	setwide(void);
+int	squeeze(int i);
+char	*getblock(int atl, int iof);
+int	unixcom(void);
+int	getkey(void);
+int	puts(char *s);
+int	substitute(int inglob);
+int	putline(void);
+int	rdelete(int *ad1, int *ad2);
+int	makekey(char *kp, char *km);
+int
+main(int argc, char **argv)
@@ -108,3 +171,3 @@
-	oldquit = signal(SIGQUIT, SIG_IGN);
-	oldhup = signal(SIGHUP, SIG_IGN);
-	oldintr = signal(SIGINT, SIG_IGN);
+	oldquit = (int (*)())(long)signal(SIGQUIT, SIG_IGN);
+	oldhup = (int (*)())(long)signal(SIGHUP, SIG_IGN);
+	oldintr = (int (*)())(long)signal(SIGINT, SIG_IGN);
@@ -141 +204 @@
-		while (*p2++ = *p1++)
+		while ((*p2++ = *p1++))
@@ -154 +217 @@
-	quit();
+	quit(0);
@@ -157 +220,2 @@
-commands()
+int
+commands(void)
@@ -159,2 +223,2 @@
-	int getfile(), gettty();
-	register *a1, c;
+	int getfile(void), gettty(void);
+	register int *a1, c;
@@ -203,0 +268 @@
+		/* fallthrough */
@@ -265,0 +331 @@
+		/* fallthrough */
@@ -281,0 +348 @@
+		/* fallthrough */
@@ -285 +352,2 @@
-		quit();
+		quit(0);
+		/* fallthrough */
@@ -327,0 +396 @@
+		/* fallthrough */
@@ -367 +436 @@
-		return;
+		return(0);
@@ -375 +444 @@
-address()
+address(void)
@@ -377 +446,2 @@
-	register *a1, minus, c;
+	register int *a1;
+	register int minus, c;
@@ -471 +541,2 @@
-setdot()
+void
+setdot(void)
@@ -479 +550,2 @@
-setall()
+void
+setall(void)
@@ -490 +562,2 @@
-setnoaddr()
+void
+setnoaddr(void)
@@ -496 +569,2 @@
-nonzero()
+void
+nonzero(void)
@@ -502 +576,2 @@
-newline()
+void
+newline(void)
@@ -504 +579 @@
-	register c;
+	register int c;
@@ -518 +593,2 @@
-filename(comm)
+void
+filename(int comm)
@@ -521 +597 @@
-	register c;
+	register int c;
@@ -530 +606 @@
-		while (*p2++ = *p1++)
+		while ((*p2++ = *p1++))
@@ -550 +626 @@
-		while (*p1++ = *p2++)
+		while ((*p1++ = *p2++))
@@ -555 +631,2 @@
-exfile()
+void
+exfile(void)
@@ -565 +642,2 @@
-onintr()
+int
+onintr(int sig)
@@ -566,0 +645 @@
+	(void)sig;
@@ -570,0 +650 @@
+	return 0;
@@ -573 +653,2 @@
-onhup()
+int
+onhup(int sig)
@@ -574,0 +656 @@
+	(void)sig;
@@ -585 +667,2 @@
-	quit();
+	quit(0);
+	return(0);
@@ -588,2 +671,2 @@
-error(s)
-char *s;
+int
+error(char *s)
@@ -591 +674 @@
-	register c;
+	register int c;
@@ -611,0 +695 @@
+	return(0);
@@ -614 +698,2 @@
-getchr()
+int
+getchr(void)
@@ -617 +702 @@
-	if (lastc=peekc) {
+	if ((lastc=peekc)) {
@@ -633 +718,2 @@
-gettty()
+int
+gettty(void)
@@ -635 +721 @@
-	register c;
+	register int c;
@@ -659 +745,2 @@
-getfile()
+int
+getfile(void)
@@ -661 +748 @@
-	register c;
+	register int c;
@@ -695 +782,2 @@
-putfile()
+int
+putfile(void)
@@ -699 +787 @@
-	register nib;
+	register int nib;
@@ -731,0 +820 @@
+	return(0);
@@ -734,3 +823,2 @@
-append(f, a)
-int *a;
-int (*f)();
+int
+append(int (*f)(), int *a)
@@ -738 +826 @@
-	register *a1, *a2, *rdot;
+	register int *a1, *a2, *rdot;
@@ -744 +832 @@
-		if ((dol-zero)+1 >= nlall) {
+		if ((unsigned)((dol-zero)+1) >= nlall) {
@@ -768 +856,2 @@
-callunix()
+int
+callunix(void)
@@ -770 +859 @@
-	register (*savint)(), pid, rpid;
+	register int (*savint)(), pid, rpid;
@@ -780 +869 @@
-	savint = signal(SIGINT, SIG_IGN);
+	savint = (int (*)())(long)signal(SIGINT, SIG_IGN);
@@ -784,0 +874 @@
+	return(0);
@@ -787 +877,2 @@
-quit()
+int
+quit(int sig)
@@ -788,0 +880 @@
+	(void)sig;
@@ -797 +889,2 @@
-delete()
+int
+delete(void)
@@ -802,0 +896 @@
+	return 0;
@@ -805,2 +899,2 @@
-rdelete(ad1, ad2)
-int *ad1, *ad2;
+int
+rdelete(int *ad1, int *ad2)
@@ -808 +902 @@
-	register *a1, *a2, *a3;
+	register int *a1, *a2, *a3;
@@ -821,0 +916 @@
+	return(0);
@@ -824 +919,2 @@
-gdelete()
+int
+gdelete(void)
@@ -826 +922 @@
-	register *a1, *a2, *a3;
+	register int *a1, *a2, *a3;
@@ -831 +927 @@
-			return;
+			return(0);
@@ -842,0 +939 @@
+	return(0);
@@ -846 +943 @@
-getline(tl)
+getline(int tl)
@@ -849 +946 @@
-	register nl;
+	register int nl;
@@ -855 +952 @@
-	while (*lp++ = *bp++)
+	while ((*lp++ = *bp++))
@@ -863 +960,2 @@
-putline()
+int
+putline(void)
@@ -866 +964 @@
-	register nl;
+	register int nl;
@@ -875 +973 @@
-	while (*bp = *lp++) {
+	while ((*bp = *lp++)) {
@@ -892 +990 @@
-getblock(atl, iof)
+getblock(int atl, int iof)
@@ -894,2 +992 @@
-	extern read(), write();
-	register bno, off;
+	register int bno, off;
@@ -941,3 +1038,2 @@
-blkio(b, buf, iofcn)
-char *buf;
-int (*iofcn)();
+int
+blkio(int b, char *buf, int (*iofcn)())
@@ -948,0 +1045 @@
+	return 0;
@@ -951 +1048,2 @@
-init()
+int
+init(void)
@@ -953 +1051 @@
-	register *markp;
+	register int *markp;
@@ -970,0 +1069 @@
+	return(0);
@@ -973 +1072,2 @@
-global(k)
+int
+global(int k)
@@ -976 +1076 @@
-	register c;
+	register int c;
@@ -1012 +1112 @@
-		return;
+		return(0);
@@ -1022,0 +1123 @@
+	return(0);
@@ -1025 +1126,2 @@
-join()
+int
+join(void)
@@ -1028 +1130 @@
-	register *a1;
+	register int *a1;
@@ -1033 +1135 @@
-		while (*gp = *lp++)
+		while ((*gp = *lp++))
@@ -1039 +1141 @@
-	while (*lp++ = *gp++)
+	while ((*lp++ = *gp++))
@@ -1044,0 +1147 @@
+	return(0);
@@ -1047 +1150,2 @@
-substitute(inglob)
+int
+substitute(int inglob)
@@ -1049 +1153 @@
-	register *markp, *a1, nl;
+	register int *markp, *a1, nl;
@@ -1051 +1155 @@
-	int getsub();
+	int getsub(void);
@@ -1083,0 +1188 @@
+	return(0);
@@ -1086 +1191,2 @@
-compsub()
+int
+compsub(void)
@@ -1088 +1194 @@
-	register seof, c;
+	register int seof, c;
@@ -1121 +1227,2 @@
-getsub()
+int
+getsub(void)
@@ -1128 +1235 @@
-	while (*p1++ = *p2++)
+	while ((*p1++ = *p2++))
@@ -1134 +1241,2 @@
-dosub()
+int
+dosub(void)
@@ -1144 +1252 @@
-	while (c = *rp++&0377) {
+	while ((c = *rp++&0377)) {
@@ -1158 +1266 @@
-	while (*sp++ = *lp++)
+	while ((*sp++ = *lp++))
@@ -1163 +1271 @@
-	while (*lp++ = *sp++)
+	while ((*lp++ = *sp++))
@@ -1164,0 +1273 @@
+	return(0);
@@ -1168,2 +1277 @@
-place(sp, l1, l2)
-register char *sp, *l1, *l2;
+place(register char *sp, register char *l1, register char *l2)
@@ -1180 +1288,2 @@
-move(cflag)
+int
+move(int cflag)
@@ -1183 +1292 @@
-	int getcopy();
+	int getcopy(void);
@@ -1209 +1318 @@
-			return;
+			return(0);
@@ -1220,0 +1330 @@
+	return(0);
@@ -1223,2 +1333,2 @@
-reverse(a1, a2)
-register int *a1, *a2;
+int
+reverse(register int *a1, register int *a2)
@@ -1231 +1341 @@
-			return;
+			return(0);
@@ -1237 +1347,2 @@
-getcopy()
+int
+getcopy(void)
@@ -1245 +1356,2 @@
-compile(aeof)
+int
+compile(int aeof)
@@ -1247 +1359 @@
-	register eof, c;
+	register int eof, c;
@@ -1259 +1371 @@
-		return;
+		return(0);
@@ -1277 +1389 @@
-			return;
+			return(0);
@@ -1371,0 +1484 @@
+	return(0);
@@ -1374,2 +1487,2 @@
-execute(gf, addr)
-int *addr;
+int
+execute(int gf, int *addr)
@@ -1380,2 +1493,2 @@
-		braslist[c] = 0;
-		braelist[c] = 0;
+		braslist[(unsigned char)c] = 0;
+		braelist[(unsigned char)c] = 0;
@@ -1388 +1501 @@
-		while (*p1++ = *p2++)
+		while ((*p1++ = *p2++))
@@ -1425,2 +1538,2 @@
-advance(lp, ep)
-register char *ep, *lp;
+int
+advance(register char *lp, register char *ep)
@@ -1467 +1580 @@
-		braslist[*ep++] = lp;
+		braslist[(unsigned char)*ep++] = lp;
@@ -1471 +1584 @@
-		braelist[*ep++] = lp;
+		braelist[(unsigned char)*ep++] = lp;
@@ -1532,3 +1645,2 @@
-backref(i, lp)
-register i;
-register char *lp;
+int
+backref(register int i, register char *lp)
@@ -1545,2 +1657,2 @@
-cclass(set, c, af)
-register char *set, c;
+int
+cclass(register char *set, register int c, int af)
@@ -1548 +1660 @@
-	register n;
+	register int n;
@@ -1559 +1671,2 @@
-putd()
+int
+putd(void)
@@ -1561 +1674 @@
-	register r;
+	register int r;
@@ -1567,0 +1681 @@
+	return(0);
@@ -1570,2 +1684,2 @@
-puts(sp)
-register char *sp;
+int
+puts(register char *sp)
@@ -1576,0 +1691 @@
+	return(0);
@@ -1582 +1697,2 @@
-putchr(ac)
+int
+putchr(int ac)
@@ -1585 +1701 @@
-	register c;
+	register int c;
@@ -1621 +1737 @@
-		return;
+		return(0);
@@ -1623,0 +1740 @@
+	return(0);
@@ -1625,4 +1742,2 @@
-crblock(permp, buf, nchar, startn)
-char *permp;
-char *buf;
-long startn;
+int
+crblock(char *permp, char *buf, int nchar, long startn)
@@ -1651,0 +1767 @@
+	return(0);
@@ -1654 +1770,2 @@
-getkey()
+int
+getkey(void)
@@ -1660 +1777 @@
-	register c;
+	register int c;
@@ -1662 +1779 @@
-	sig = signal(SIGINT, SIG_IGN);
+	sig = (int (*)())(long)signal(SIGINT, SIG_IGN);
@@ -1685,2 +1802,2 @@
-crinit(keyp, permp)
-char	*keyp, *permp;
+int
+crinit(char *keyp, char *permp)
@@ -1689 +1806 @@
-	register i;
+	register int i;
@@ -1748,2 +1865,2 @@
-makekey(a, b)
-char *a, *b;
+int
+makekey(char *a, char *b)
@@ -1761,0 +1879 @@
+	return(0);

% usr/src/cmd/egrep.y
@@ -20 +20 @@
-#define NCHARS 128
+#define NCHARS 256
@@ -26 +26 @@
-int line 1;
+int line = 1;
@@ -33 +33 @@
-char chars[MAXLIN];
+int chars[MAXLIN];
@@ -35 +35 @@
-int nxtchar 0;
+int nxtchar = 0;
@@ -58 +58,18 @@
-int	fname;
+char	*fname;
+int	yylex(void);
+int	yyerror(char *s);
+int	nextch(void);
+void	synerror(void);
+int	enter(int x);
+int	cclenter(int x);
+int	node(int x, int l, int r);
+int	unary(int x, int d);
+void	overflo(void);
+void	cfoll(int v);
+void	cgotofn(void);
+int	cstate(int v);
+int	member(int symb, int set, int torf);
+int	notin(int n);
+void	add(int *array, int n);
+void	follow(int v);
+void	execute(char *file);
@@ -63 +80 @@
-		={ unary(FINAL, $1);
+		{ unary(FINAL, $1);
@@ -68 +85 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -70 +87 @@
-		={ $$ = node(CAT, $2, $3); }
+		{ $$ = node(CAT, $2, $3); }
@@ -72 +89 @@
-		={ $$ = node(CAT, $2, $3); }
+		{ $$ = node(CAT, $2, $3); }
@@ -74 +91 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -77 +94 @@
-		={ $$ = enter(DOT);
+		{ $$ = enter(DOT);
@@ -81 +98 @@
-		={ $$ = enter($1); }
+		{ $$ = enter($1); }
@@ -83 +100 @@
-		={ $$ = enter(DOT); }
+		{ $$ = enter(DOT); }
@@ -85 +102 @@
-		={ $$ = cclenter(CCL); }
+		{ $$ = cclenter(CCL); }
@@ -87 +104 @@
-		={ $$ = cclenter(NCCL); }
+		{ $$ = cclenter(NCCL); }
@@ -91 +108 @@
-		={ $$ = node(OR, $1, $3); }
+		{ $$ = node(OR, $1, $3); }
@@ -93 +110 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -95 +112 @@
-		={ $$ = unary(STAR, $1); }
+		{ $$ = unary(STAR, $1); }
@@ -97 +114 @@
-		={ $$ = unary(PLUS, $1); }
+		{ $$ = unary(PLUS, $1); }
@@ -99 +116 @@
-		={ $$ = unary(QUEST, $1); }
+		{ $$ = unary(QUEST, $1); }
@@ -101 +118 @@
-		={ $$ = $2; }
+		{ $$ = $2; }
@@ -106 +123,2 @@
-yyerror(s) {
+int
+yyerror(char *s) {
@@ -108,0 +127 @@
+	return(0);
@@ -111 +130,2 @@
-yylex() {
+int
+yylex(void) {
@@ -114 +134 @@
-	register char c, d;
+	register int c, d;
@@ -156,0 +177,2 @@
+			yylval = c;
+			return (CHAR);
@@ -161,2 +183,3 @@
-nextch() {
-	register char c;
+int
+nextch(void) {
+	register int c;
@@ -166 +189 @@
-	else c = *input++;
+	else c = *input++ & 0377;
@@ -170 +193,2 @@
-synerror() {
+void
+synerror(void) {
@@ -175 +199,2 @@
-enter(x) int x; {
+int
+enter(int x) {
@@ -183,2 +208,3 @@
-cclenter(x) int x; {
-	register linno;
+int
+cclenter(int x) {
+	register int linno;
@@ -190 +216,2 @@
-node(x, l, r) {
+int
+node(int x, int l, int r) {
@@ -200 +227,2 @@
-unary(x, d) {
+int
+unary(int x, int d) {
@@ -208 +236,2 @@
-overflo() {
+void
+overflo(void) {
@@ -213,2 +242,3 @@
-cfoll(v) {
-	register i;
+void
+cfoll(int v) {
+	register int i;
@@ -227,2 +257,3 @@
-cgotofn() {
-	register c, i, k;
+void
+cgotofn(void) {
+	register int c, i, k;
@@ -321,2 +352,3 @@
-cstate(v) {
-	register b;
+int
+cstate(int v) {
+	register int b;
@@ -347,2 +379,3 @@
-member(symb, set, torf) {
-	register i, num, pos;
+int
+member(int symb, int set, int torf) {
+	register int i, num, pos;
@@ -356,2 +389,3 @@
-notin(n) {
-	register i, j, pos;
+int
+notin(int n) {
+	register int i, j, pos;
@@ -371,2 +405,3 @@
-add(array, n) int *array; {
-	register i;
+void
+add(int *array, int n) {
+	register int i;
@@ -383 +418,2 @@
-follow(v) int v; {
+void
+follow(int v) {
@@ -414,2 +450,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -490,2 +526,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -494,2 +530,2 @@
-	register cstat;
-	register ccount;
+	register int cstat;
+	register int ccount;

% usr/src/cmd/expr.y
@@ -2,0 +3 @@
+%define api.value.type {char *}
@@ -15,0 +17,20 @@
+%{
+#include <stdio.h>
+#define index expr_index
+long	atol();
+int	yylex(void);
+int	yyerror(char *s);
+char	*rel(int op, char *r1, char *r2);
+char	*arith(int op, char *r1, char *r2);
+char	*conj(int op, char *r1, char *r2);
+char	*substr(char *v, char *s, char *w);
+char	*length(char *s);
+char	*index(char *s, char *t);
+char	*match(char *s, char *p);
+int	ematch(char *s, char *p);
+void	errxx(int c);
+char	*compile(char *instring, char *ep, char *endbuf, int seof);
+int	advance(char *lp, char *ep);
+int	getrnge(char *str);
+int	ecmp(char *a, char *b, int count);
+%}
@@ -20 +41 @@
-expression:	expr NOARG = {
+expression:	expr NOARG {
@@ -27,19 +48,19 @@
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
@@ -50 +70,0 @@
-#include <stdio.h>
@@ -54 +73,0 @@
-long atol();
@@ -63 +82,2 @@
-main(argc, argv) char **argv; {
+int
+main(int argc, char **argv) {
@@ -67,0 +88 @@
+	return(0);
@@ -76 +97,2 @@
-yylex() {
+int
+yylex(void) {
@@ -78 +100 @@
-	register i;
+	register int i;
@@ -86,2 +108,2 @@
-	for(i = 0; *operator[i]; ++i)
-		if(EQL(operator[i], p))
+	for(i = 0; *operators[i]; ++i)
+		if(EQL(operators[i], p))
@@ -94,2 +116,3 @@
-char *rel(op, r1, r2) register char *r1, *r2; {
-	register i;
+char *
+rel(int op, register char *r1, register char *r2) {
+	register int i;
@@ -112 +135,2 @@
-char *arith(op, r1, r2) char *r1, *r2; {
+char *
+arith(int op, char *r1, char *r2) {
@@ -129 +153 @@
-	sprintf(rv, "%D", i1);
+	sprintf(rv, "%ld", i1);
@@ -132,2 +156,3 @@
-char *conj(op, r1, r2) char *r1, *r2; {
-	register char *rv;
+char *
+conj(int op, char *r1, char *r2) {
+	register char *rv = 0;
@@ -162,2 +187,3 @@
-char *substr(v, s, w) char *v, *s, *w; {
-register si, wi;
+char *
+substr(char *v, char *s, char *w) {
+register int si, wi;
@@ -178,2 +204,3 @@
-char *length(s) register char *s; {
-	register i = 0;
+char *
+length(register char *s) {
+	register int i = 0;
@@ -189,2 +216,3 @@
-char *index(s, t) char *s, *t; {
-	register i, j;
+char *
+index(char *s, char *t) {
+	register int i, j;
@@ -202 +230,2 @@
-char *match(s, p)
+char *
+match(char *s, char *p)
@@ -218,2 +247,2 @@
-#define RETURN(c)	return
-#define ERROR(c)	errxx(c)
+#define RETURN(c)	return(c)
+#define ERROR(c)	do { errxx(c); return(0); } while (0)
@@ -222,3 +251,2 @@
-ematch(s, p)
-char *s;
-register char *p;
+int
+ematch(char *s, register char *p)
@@ -227,2 +255 @@
-	char *compile();
-	register num;
+	register int num;
@@ -231 +258 @@
-	compile(p, expbuf, &expbuf[512], 0);
+	compile(p, expbuf, &expbuf[ESIZE], 0);
@@ -246 +273,2 @@
-errxx(c)
+void
+errxx(int c)
@@ -247,0 +276 @@
+	(void)c;
@@ -290,3 +319 @@
-compile(instring, ep, endbuf, seof)
-register char *ep;
-char *instring, *endbuf;
+compile(char *instring, register char *ep, char *endbuf, int seof)
@@ -295,2 +322,2 @@
-	register c;
-	register eof = seof;
+	register int c;
+	register int eof = seof;
@@ -457 +484 @@
-			/* Drop through to default to use \ to turn off special chars */
+			/* fallthrough */
@@ -468,2 +495,2 @@
-step(p1, p2)
-register char *p1, *p2;
+int
+step(register char *p1, register char *p2)
@@ -471 +498 @@
-	register c;
+	register int c;
@@ -500,2 +527,2 @@
-advance(lp, ep)
-register char *lp, *ep;
+int
+advance(register char *lp, register char *ep)
@@ -504 +531 @@
-	char c;
+	int c;
@@ -537 +564 @@
-		braslist[*ep++] = lp;
+		braslist[(unsigned char)*ep++] = lp;
@@ -541 +568 @@
-		braelist[*ep++] = lp;
+		braelist[(unsigned char)*ep++] = lp;
@@ -592,2 +619,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[(unsigned char)*ep];
+		ct = braelist[(unsigned char)*ep++] - bbeg;
@@ -602,2 +629,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[(unsigned char)*ep];
+		ct = braelist[(unsigned char)*ep++] - bbeg;
@@ -646,2 +673,2 @@
-getrnge(str)
-register char *str;
+int
+getrnge(register char *str)
@@ -650 +677,2 @@
-	size = *str == 255 ? 20000 : (*str &0377) - low;
+	size = (*str & 0377) == 255 ? 20000 : (*str &0377) - low;
+	return(0);
@@ -653,3 +681,2 @@
-ecmp(a, b, count)
-register char	*a, *b;
-register	count;
+int
+ecmp(register char *a, register char *b, register int count)
@@ -664 +691,2 @@
-yyerror(s)
+int
+yyerror(char *s)
@@ -668,0 +697 @@
+	return(0);

% usr/src/cmd/factor.c usr/src/cmd/factor.s
@@ -1,351 +1,151 @@
-.globl	sqrt
-exit = 1.
-read = 3.
-write = 4.
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
-
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
-
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
-
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
+#include <stdio.h>
+
+#define MAXNUM 72057594037927936ULL
+
+static int
+parse_number(char *s, unsigned long long *out)
+{
+	unsigned long long n;
+	int any;
+
+	while (*s == ' ' || *s == '\t' || *s == '\n')
+		s++;
+	n = 0;
+	any = 0;
+	while (*s >= '0' && *s <= '9') {
+		any = 1;
+		if (n > (MAXNUM - (unsigned long long)(*s - '0')) / 10ULL)
+			return(-1);
+		n = n * 10ULL + (unsigned long long)(*s - '0');
+		s++;
+	}
+	while (*s == ' ' || *s == '\t' || *s == '\n')
+		s++;
+	if (!any || *s != '\0' || n >= MAXNUM)
+		return(-1);
+	*out = n;
+	return(0);
+}
+
+static int
+read_number(unsigned long long *out)
+{
+	char buf[80];
+	int c, i, any;
+
+	i = 0;
+	any = 0;
+	while ((c = getchar()) != EOF) {
+		if (c != ' ' && c != '\t' && c != '\n')
+			break;
+	}
+	if (c == EOF)
+		return(0);
+	do {
+		any = 1;
+		if (i < (int)sizeof(buf) - 1)
+			buf[i++] = (char)c;
+		c = getchar();
+	} while (c != EOF && c != ' ' && c != '\t' && c != '\n');
+	buf[i] = '\0';
+	if (!any)
+		return(0);
+	if (parse_number(buf, out) < 0)
+		return(-1);
+	return(1);
+}
+
+static void
+putnum(unsigned long long n)
+{
+	char buf[24];
+	int i;
+
+	i = 0;
+	if (n == 0)
+		buf[i++] = '0';
+	else while (n != 0) {
+		buf[i++] = (char)('0' + (int)(n % 10ULL));
+		n /= 10ULL;
+	}
+	while (i > 0)
+		putchar(buf[--i]);
+}
+
+static void
+factor(unsigned long long n)
+{
+	unsigned long long p;
+
+	putchar('\n');
+	while ((n % 2ULL) == 0) {
+		printf("     ");
+		putnum(2ULL);
+		putchar('\n');
+		n /= 2ULL;
+	}
+	while ((n % 3ULL) == 0) {
+		printf("     ");
+		putnum(3ULL);
+		putchar('\n');
+		n /= 3ULL;
+	}
+	p = 5ULL;
+	while (p <= n / p) {
+		while ((n % p) == 0) {
+			printf("     ");
+			putnum(p);
+			putchar('\n');
+			n /= p;
+		}
+		p += 2ULL;
+		if (p > n / p)
+			break;
+		while ((n % p) == 0) {
+			printf("     ");
+			putnum(p);
+			putchar('\n');
+			n /= p;
+		}
+		p += 4ULL;
+	}
+	if (n > 1ULL) {
+		printf("     ");
+		putnum(n);
+		putchar('\n');
+	}
+}
+
+static void
+ouch(void)
+{
+	fprintf(stderr, "Ouch.\n");
+}
+
+int
+main(int argc, char **argv)
+{
+	unsigned long long n;
+	int r;
+
+	if (argc > 1) {
+		if (parse_number(argv[1], &n) < 0) {
+			ouch();
+			return(1);
+		}
+		if (n == 0ULL)
+			return(0);
+		factor(n);
+		return(0);
+	}
+	for (;;) {
+		r = read_number(&n);
+		if (r == 0 || (r > 0 && n == 0ULL))
+			return(0);
+		if (r < 0) {
+			ouch();
+			return(1);
+		}
+		factor(n);
+	}
+}

% usr/src/cmd/fgrep.c
@@ -33,2 +33,7 @@
-main(argc, argv)
-char **argv;
+void execute(char *file);
+int getargc(void);
+void cgotofn(void);
+void overflo(void);
+void cfail(void);
+int
+main(int argc, char **argv)
@@ -112,2 +117,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -117 +122 @@
-	register ccount;
+	register int ccount;
@@ -208 +213 @@
-		if (*p++ == '\n')
+		if (*p++ == '\n') {
@@ -215,0 +221 @@
+		}
@@ -225 +231,2 @@
-getargc()
+int
+getargc(void)
@@ -227 +234 @@
-	register c;
+	register int c;
@@ -235,2 +242,3 @@
-cgotofn() {
-	register c;
+void
+cgotofn(void) {
+	register int c;
@@ -298 +306,2 @@
-overflo() {
+void
+overflo(void) {
@@ -302 +311,2 @@
-cfail() {
+void
+cfail(void) {

% usr/src/cmd/file.c
@@ -23,2 +23,7 @@
-main(argc, argv)
-char **argv;
+void type(char *file);
+int lookup(char *tab[]);
+int ccom(void);
+int ascom(void);
+int english(char *bp, int n);
+int
+main(int argc, char **argv)
@@ -56,2 +61,2 @@
-type(file)
-char *file;
+void
+type(char *file)
@@ -104,0 +110 @@
+		/* fallthrough */
@@ -143 +149 @@
-		if(buf[i] <= 0)
+		if(buf[i] == 0 || buf[i] & 0200)
@@ -184 +190 @@
-		else if(buf[j] == '\n' && isalpha(buf[j+2])){
+		else if(buf[j] == '\n' && isalpha((unsigned char)buf[j+2])){
@@ -201 +207 @@
-			else if(buf[j] == '\n' && isalpha(buf[j+2])){
+			else if(buf[j] == '\n' && isalpha((unsigned char)buf[j+2])){
@@ -238 +244 @@
-		/*.... */
+		.... */
@@ -242,2 +248,2 @@
-lookup(tab)
-char *tab[];
+int
+lookup(char *tab[])
@@ -260 +266,2 @@
-ccom(){
+int
+ccom(void){
@@ -275 +282,2 @@
-ascom(){
+int
+ascom(void){
@@ -284,2 +292,2 @@
-english (bp, n)
-char *bp;
+int
+english (char *bp, int n)
@@ -295 +303 @@
-		if (bp[j]<NASC)
+		if ((bp[j]&0377)<NASC)

% usr/src/cmd/find.c
@@ -2,0 +3 @@
+#define	ctime	find_ctime
@@ -33,6 +34,3 @@
-struct	anode	*exp(),
-		*e1(),
-		*e2(),
-		*e3(),
-		*mk();
-char	*nxtarg();
+struct	anode	*exp(void), *e1(void), *e2(void), *e3(void);
+struct	anode	*mk(int (*f)(), struct anode *l, struct anode *r);
+char	*nxtarg(void);
@@ -41,3 +39,15 @@
-char *rindex();
-char *sbrk();
-main(argc, argv) char *argv[];
+char *rindex(char *sp, int c);
+char *sbrk(int);
+int	pr(char *s);
+int	descend(char *name, char *fname, struct anode *exlist);
+int	cpio(void);
+int	getunum(char *f, char *s);
+int	gmatch(char *s, char *p);
+int	scomp(int a, int b, int s);
+int	doex(int com);
+int	bwrite(short *rp, int c);
+int	chgreel(int x, int fl);
+int	amatch(char *s, char *p);
+int	umatch(char *s, char *p);
+int
+main(int argc, char *argv[])
@@ -48,0 +59 @@
+	int pclose(FILE *);
@@ -77 +88 @@
-		if(cp = rindex(Pathname, '/')) {
+		if((cp = rindex(Pathname, '/'))) {
@@ -99,2 +110,2 @@
-struct anode *exp() { /* parse ALTERNATION (-o)  */
-	int or();
+struct anode *exp(void) { /* parse ALTERNATION (-o)  */
+	int or(register struct anode *p);
@@ -111,2 +122,2 @@
-struct anode *e1() { /* parse CONCATENATION (formerly -a) */
-	int and();
+struct anode *e1(void) { /* parse CONCATENATION (formerly -a) */
+	int and(register struct anode *p);
@@ -128,2 +139,2 @@
-struct anode *e2() { /* parse NOT (!) */
-	int not();
+struct anode *e2(void) { /* parse NOT (!) */
+	int not(register struct anode *p);
@@ -141,4 +152,6 @@
-struct anode *e3() { /* parse parens and predicates */
-	int exeq(), ok(), glob(),  mtime(), atime(), ctime(), user(),
-		group(), size(), perm(), links(), print(),
-		type(), ino(), cpio(), newer();
+struct anode *e3(void) { /* parse parens and predicates */
+	int exeq(void *vp), ok(void *vp), glob(void *vp);
+	int mtime(void *vp), atime(void *vp), ctime(void *vp);
+	int user(void *vp), group(void *vp), size(void *vp), perm(void *vp);
+	int links(void *vp), print(void), type(void *vp), ino(void *vp);
+	int cpio(void), newer(void);
@@ -166 +179 @@
-		return(mk(mtime, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(mtime, (struct anode *)(long)atoi(b), (struct anode *)(long)s));
@@ -168 +181 @@
-		return(mk(atime, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(atime, (struct anode *)(long)atoi(b), (struct anode *)(long)s));
@@ -170 +183 @@
-		return(mk(ctime, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(ctime, (struct anode *)(long)atoi(b), (struct anode *)(long)s));
@@ -176 +189 @@
-				return mk(user, (struct anode *)atoi(b), (struct anode *)s);
+				return mk(user, (struct anode *)(long)atoi(b), (struct anode *)(long)s);
@@ -180 +193 @@
-		return(mk(user, (struct anode *)i, (struct anode *)s));
+		return(mk(user, (struct anode *)(long)i, (struct anode *)(long)s));
@@ -183 +196 @@
-		return(mk(ino, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(ino, (struct anode *)(long)atoi(b), (struct anode *)(long)s));
@@ -189 +202 @@
-				return mk(group, (struct anode *)atoi(b), (struct anode *)s);
+				return mk(group, (struct anode *)(long)atoi(b), (struct anode *)(long)s);
@@ -193 +206 @@
-		return(mk(group, (struct anode *)i, (struct anode *)s));
+		return(mk(group, (struct anode *)(long)i, (struct anode *)(long)s));
@@ -195 +208 @@
-		return(mk(size, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(size, (struct anode *)(long)atoi(b), (struct anode *)(long)s));
@@ -197 +210 @@
-		return(mk(links, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(links, (struct anode *)(long)atoi(b), (struct anode *)(long)s));
@@ -204 +217 @@
-		return(mk(perm, (struct anode *)i, (struct anode *)s));
+		return(mk(perm, (struct anode *)(long)i, (struct anode *)(long)s));
@@ -226 +239 @@
-			pr("find: cannot create "), pr(s), pr("\n");
+			pr("find: cannot create "), pr(b), pr("\n");
@@ -242,0 +256 @@
+	return(0);
@@ -244,3 +258 @@
-struct anode *mk(f, l, r)
-int (*f)();
-struct anode *l, *r;
+struct anode *mk(int (*f)(), struct anode *l, struct anode *r)
@@ -254,2 +266,2 @@
-char *nxtarg() { /* get next arg from command line */
-	static strikes = 0;
+char *nxtarg(void) { /* get next arg from command line */
+	static int strikes = 0;
@@ -270,2 +282,2 @@
-and(p)
-register struct anode *p;
+int
+and(register struct anode *p)
@@ -275,2 +287,2 @@
-or(p)
-register struct anode *p;
+int
+or(register struct anode *p)
@@ -280,2 +292,2 @@
-not(p)
-register struct anode *p;
+int
+not(register struct anode *p)
@@ -285,2 +297,2 @@
-glob(p)
-register struct { int f; char *pat; } *p; 
+int
+glob(void *vp)
@@ -287,0 +300 @@
+	struct { int f; char *pat; } *p = vp;
@@ -290 +303,2 @@
-print()
+int
+print(void)
@@ -295,2 +309,2 @@
-mtime(p)
-register struct { int f, t, s; } *p; 
+int
+mtime(void *vp)
@@ -297,0 +312 @@
+	struct { int f, t, s; } *p = vp;
@@ -300,2 +315,2 @@
-atime(p)
-register struct { int f, t, s; } *p; 
+int
+atime(void *vp)
@@ -302,0 +318 @@
+	struct { int f, t, s; } *p = vp;
@@ -305,2 +321,2 @@
-ctime(p)
-register struct { int f, t, s; } *p; 
+int
+ctime(void *vp)
@@ -307,0 +324 @@
+	struct { int f, t, s; } *p = vp;
@@ -310,2 +327,2 @@
-user(p)
-register struct { int f, u, s; } *p; 
+int
+user(void *vp)
@@ -312,0 +330 @@
+	struct { int f, u, s; } *p = vp;
@@ -315,2 +333,2 @@
-ino(p)
-register struct { int f, u, s; } *p;
+int
+ino(void *vp)
@@ -317,0 +336 @@
+	struct { int f, u, s; } *p = vp;
@@ -320,2 +339,2 @@
-group(p)
-register struct { int f, u; } *p; 
+int
+group(void *vp)
@@ -322,0 +342 @@
+	struct { int f, u; } *p = vp;
@@ -325,2 +345,2 @@
-links(p)
-register struct { int f, link, s; } *p; 
+int
+links(void *vp)
@@ -327,0 +348 @@
+	struct { int f, link, s; } *p = vp;
@@ -330,2 +351,2 @@
-size(p)
-register struct { int f, sz, s; } *p; 
+int
+size(void *vp)
@@ -332,0 +354 @@
+	struct { int f, sz, s; } *p = vp;
@@ -335,2 +357,2 @@
-perm(p)
-register struct { int f, per, s; } *p; 
+int
+perm(void *vp)
@@ -338 +360,2 @@
-	register i;
+	struct { int f, per, s; } *p = vp;
+	register int i;
@@ -342,2 +365,2 @@
-type(p)
-register struct { int f, per, s; } *p;
+int
+type(void *vp)
@@ -344,0 +368 @@
+	struct { int f, per, s; } *p = vp;
@@ -347,2 +371,2 @@
-exeq(p)
-register struct { int f, com; } *p;
+int
+exeq(void *vp)
@@ -349,0 +374 @@
+	struct { int f, com; } *p = vp;
@@ -353,2 +378,2 @@
-ok(p)
-struct { int f, com; } *p;
+int
+ok(void *vp)
@@ -355,0 +381 @@
+	struct { int f, com; } *p = vp;
@@ -373,2 +399 @@
-long mklong(v)
-short v[];
+long mklong(short v[])
@@ -383 +408,2 @@
-cpio()
+int
+cpio(void)
@@ -400 +426 @@
-	register ifile, ct;
+	register int ifile, ct;
@@ -402 +428 @@
-	register i;
+	register int i;
@@ -421 +447 @@
-		return;
+		return(0);
@@ -425 +451 @@
-		return;
+		return(0);
@@ -430 +456 @@
-		return;
+		return(0);
@@ -440 +466 @@
-	return;
+	return(0);
@@ -442 +468,2 @@
-newer()
+int
+newer(void)
@@ -448,3 +475,2 @@
-scomp(a, b, s) /* funny signed compare */
-register a, b;
-register char s;
+int
+scomp(register int a, register int b, register int s) /* funny signed compare */
@@ -459 +485,2 @@
-doex(com)
+int
+doex(int com)
@@ -461 +488 @@
-	register np;
+	register int np;
@@ -464 +491 @@
-	static ccode;
+	static int ccode;
@@ -467 +494 @@
-	while (na=Argv[com++]) {
+	while ((na=Argv[com++])) {
@@ -477 +504 @@
-		execvp(nargv[0], nargv, np);
+		execvp(nargv[0], nargv);
@@ -483,2 +510,3 @@
-getunum(f, s) char *f, *s; { /* find user/group name and return number */
-	register i;
+int
+getunum(char *f, char *s) { /* find user/group name and return number */
+	register int i;
@@ -486 +514 @@
-	register c;
+	register int c;
@@ -491,0 +520,2 @@
+	if(pin == NULL)
+		return(i);
@@ -515,3 +545,2 @@
-descend(name, fname, exlist)
-struct anode *exlist;
-char *name, *fname;
+int
+descend(char *name, char *fname, struct anode *exlist)
@@ -612,2 +641,2 @@
-gmatch(s, p) /* string match as in glob */
-register char *s, *p;
+int
+gmatch(register char *s, register char *p) /* string match as in glob */
@@ -619,2 +648,2 @@
-amatch(s, p)
-register char *s, *p;
+int
+amatch(register char *s, register char *p)
@@ -622 +651 @@
-	register cc;
+	register int cc;
@@ -632 +661 @@
-		while (cc = *++p) {
+		while ((cc = *++p)) {
@@ -642 +671 @@
-				k |= lc <= scc & scc <= (cc=p[1]);
+				k |= (lc <= scc) & (scc <= (cc=p[1]));
@@ -661,2 +690,2 @@
-umatch(s, p)
-register char *s, *p;
+int
+umatch(register char *s, register char *p)
@@ -670,3 +699,2 @@
-bwrite(rp, c)
-register short *rp;
-register c;
+int
+bwrite(register short *rp, register int c)
@@ -691,0 +720 @@
+	return(0);
@@ -693 +722,2 @@
-chgreel(x, fl)
+int
+chgreel(int x, int fl)
@@ -695 +725 @@
-	register f;
+	register int f;
@@ -719,2 +749,2 @@
-pr(s)
-char *s;
+int
+pr(char *s)
@@ -722,0 +753 @@
+	return(0);

% usr/src/cmd/getty.c
@@ -13,0 +14,9 @@
+int read(int fd, char *buf, int n);
+int write(int fd, char *buf, int n);
+int ioctl(int fd, int cmd, void *arg);
+int stty(int fd, void *buf);
+int execl(char *path, char *arg0, ...);
+void exit(int n);
+int getname(void);
+void puts(char *as);
+void putchr(int cc);
@@ -26 +35 @@
-	'0', 1,
+	{ '0', 1,
@@ -29 +38 @@
-	"\n\r\033;\007login: ",
+	"\n\r\033;\007login: " },
@@ -31 +40 @@
-	1, 2,
+	{ 1, 2,
@@ -34 +43 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -36 +45 @@
-	2, 3,
+	{ 2, 3,
@@ -39 +48 @@
-	"\n\r\033:\006\006\017login: ",
+	"\n\r\033:\006\006\017login: " },
@@ -41 +50 @@
-	3, '0',
+	{ 3, '0',
@@ -44 +53 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -47 +56 @@
-	'-', '-',
+	{ '-', '-',
@@ -50 +59 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -53 +62 @@
-	'1', '1',
+	{ '1', '1',
@@ -56 +65 @@
-	"\n\r\033:\006\006\017login: ",
+	"\n\r\033:\006\006\017login: " },
@@ -59 +68 @@
-	'2', '2',
+	{ '2', '2',
@@ -62 +71 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -65 +74 @@
-	'3', '5',
+	{ '3', '5',
@@ -68 +77 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -71 +80 @@
-	'5', '3',
+	{ '5', '3',
@@ -74 +83 @@
-	"\n\r\033;\007login: ",
+	"\n\r\033;\007login: " },
@@ -77 +86 @@
-	'4', '4',
+	{ '4', '4',
@@ -80 +89 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -83 +92 @@
-	'i', 'i',
+	{ 'i', 'i',
@@ -86 +95 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -89 +98 @@
-	'l', 'l',
+	{ 'l', 'l',
@@ -92 +101 @@
-	"*",
+	"*" },
@@ -94 +103 @@
-	'6', '6',
+	{ '6', '6',
@@ -97 +106 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -128,2 +137,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char *argv[])
@@ -178 +187,2 @@
-getname()
+int
+getname(void)
@@ -181 +191 @@
-	register c;
+	register int c;
@@ -222,2 +232,2 @@
-puts(as)
-char *as;
+void
+puts(char *as)
@@ -232 +242,2 @@
-putchr(cc)
+void
+putchr(int cc)

% usr/src/cmd/graph.c
@@ -43 +43,34 @@
-double	atof();
+struct xy;
+struct val;
+int	init(struct xy *p);
+int	setopt(int argc, char *argv[]);
+int	readin(void);
+int	transpose(void);
+int	scale(struct xy *p, struct val *v);
+int	axes(void);
+int	title(void);
+int	plot(void);
+int	erase(void);
+int	space(int x0, int y0, int x1, int y1);
+int	move(int xi, int yi);
+int	closevt(void);
+int	numb(float *np, int *argcp, char ***argvp);
+int	limread(struct xy *p, int *argcp, char ***argvp);
+int	badarg(void);
+int	getfloat(float *p);
+int	getstring(void);
+int	copystring(int k);
+int	getlim(struct xy *p, struct val *v);
+int	setlim(struct xy *p);
+int	setmark(int *xmark, struct xy *p);
+int	submark(int *xmark, int *pxn, float x, struct xy *p);
+int	conv(float xv, struct xy *p, int *ip);
+int	symbol(int ix, int iy, int k);
+int	point(int xi, int yi);
+int	label(char *s);
+int	cont(int xi, int yi);
+int	line(int x0, int y0, int x1, int y1);
+int	linemod(char *s);
+int	axlab(int c, struct xy *p);
+int	putsi(int a);
+int	scanf(char *fmt, ...);
@@ -57,2 +90,2 @@
-char *realloc();
-char *malloc();
+char *realloc(char *p, unsigned n);
+char *malloc(unsigned n);
@@ -60,2 +93 @@
-double ident(x)
-double x;
+double ident(double x)
@@ -66,2 +98,51 @@
-main(argc,argv)
-char *argv[];
+double
+fabs(double x)
+{
+	return(x < 0 ? -x : x);
+}
+double
+floor(double x)
+{
+	long n;
+	n = x;
+	if((double)n > x)
+		n--;
+	return(n);
+}
+double
+ceil(double x)
+{
+	long n;
+	n = x;
+	if((double)n < x)
+		n++;
+	return(n);
+}
+double
+log10(double x)
+{
+	double y, y2, term, sum;
+	int k, i;
+	if(x <= 0)
+		return(-INF);
+	k = 0;
+	while(x >= 10) {
+		x /= 10;
+		k++;
+	}
+	while(x < 1) {
+		x *= 10;
+		k--;
+	}
+	y = (x - 1)/(x + 1);
+	y2 = y*y;
+	term = y;
+	sum = 0;
+	for(i=1; i<30; i += 2) {
+		sum += term/i;
+		term *= y2;
+	}
+	return(k + (2*sum)/2.302585092994046);
+}
+int
+main(int argc, char *argv[])
@@ -92,2 +173,2 @@
-init(p)
-struct xy *p;
+int
+init(struct xy *p)
@@ -96,0 +178 @@
+	return(0);
@@ -99,2 +181,2 @@
-setopt(argc,argv)
-char *argv[];
+int
+setopt(int argc, char *argv[])
@@ -102 +184 @@
-	char *p1, *p2;
+	char *p0, *p1, *p2;
@@ -108,0 +191 @@
+		p0 = argv[0];
@@ -119 +202,2 @@
-				while (*p1++ = *p2++);
+				while ((*p1++ = *p2++))
+					;
@@ -193 +277,7 @@
-			badarg();
+			if(p0[0] == '-')
+				badarg();
+			if(freopen(argv[0],"r",stdin)==NULL) {
+				perror(argv[0]);
+				exit(1);
+			}
+			break;
@@ -195,0 +286 @@
+	return(0);
@@ -198,4 +289,2 @@
-limread(p, argcp, argvp)
-register struct xy *p;
-int *argcp;
-char ***argvp;
+int
+limread(register struct xy *p, int *argcp, char ***argvp)
@@ -209 +298 @@
-		return;
+		return(0);
@@ -212 +301 @@
-		return;
+		return(0);
@@ -215 +304 @@
-		return;
+		return(0);
@@ -216,0 +306 @@
+	return(0);
@@ -219,4 +309,2 @@
-numb(np, argcp, argvp)
-int *argcp;
-float *np;
-register char ***argvp;
+int
+numb(float *np, int *argcp, register char ***argvp)
@@ -230 +318 @@
-	if(!(isdigit(c) || c=='-'&&(*argvp)[1][1]<'A' || c=='.'))
+	if(!(isdigit((unsigned char)c) || (c=='-' && (*argvp)[1][1]<'A') || c=='.'))
@@ -238 +326,2 @@
-readin()
+int
+readin(void)
@@ -240 +329 @@
-	register t;
+	register int t;
@@ -253 +342 @@
-			return;
+			return(0);
@@ -259 +348 @@
-				return;
+				return(0);
@@ -261 +350 @@
-			return;
+			return(0);
@@ -268 +357 @@
-			return;
+			return(0);
@@ -272 +361,2 @@
-transpose()
+int
+transpose(void)
@@ -274 +364 @@
-	register i;
+	register int i;
@@ -278 +368 @@
-		return;
+		return(0);
@@ -282,0 +373 @@
+	return(0);
@@ -285 +376,2 @@
-copystring(k)
+int
+copystring(int k)
@@ -288 +380 @@
-	register i;
+	register int i;
@@ -302,2 +394 @@
-modceil(f,t)
-float f,t;
+modceil(float f, float t)
@@ -311,2 +402 @@
-modfloor(f,t)
-float f,t;
+modfloor(float f, float t)
@@ -318,3 +408,2 @@
-getlim(p,v)
-register struct xy *p;
-struct val *v;
+int
+getlim(register struct xy *p, struct val *v)
@@ -322 +411 @@
-	register i;
+	register int i;
@@ -331,0 +421 @@
+	return(0);
@@ -336 +426,3 @@
-} setloglim(), setlinlim();
+};
+struct z setloglim(int lbf, int ubf, float lb, float ub);
+struct z setlinlim(int lbf, int ubf, float xlb, float xub);
@@ -338,2 +430,2 @@
-setlim(p)
-register struct xy *p;
+int
+setlim(register struct xy *p)
@@ -353 +445 @@
-		return;
+		return(0);
@@ -392 +484 @@
-			return;
+			return(0);
@@ -403,0 +496 @@
+	return(0);
@@ -407,2 +500 @@
-setloglim(lbf,ubf,lb,ub)
-float lb,ub;
+setloglim(int lbf, int ubf, float lb, float ub)
@@ -440,3 +532 @@
-setlinlim(lbf,ubf,xlb,xub)
-int lbf,ubf;
-float xlb,xub;
+setlinlim(int lbf, int ubf, float xlb, float xub)
@@ -482,3 +572,2 @@
-scale(p,v)
-register struct xy *p;
-struct val *v;
+int
+scale(register struct xy *p, struct val *v)
@@ -494,0 +584 @@
+	return(0);
@@ -497 +587,2 @@
-axes()
+int
+axes(void)
@@ -499 +590 @@
-	register i;
+	register int i;
@@ -503 +594 @@
-		return;
+		return(0);
@@ -527,0 +619 @@
+	return(0);
@@ -530,3 +622,2 @@
-setmark(xmark,p)
-int *xmark;
-register struct xy *p;
+int
+setmark(int *xmark, register struct xy *p)
@@ -560,5 +651,2 @@
-submark(xmark,pxn,x,p)
-int *xmark;
-int *pxn;
-float x;
-struct xy *p;
+int
+submark(int *xmark, int *pxn, float x, struct xy *p)
@@ -567,0 +656 @@
+	return(0);
@@ -570 +659,2 @@
-plot()
+int
+plot(void)
@@ -594,0 +685 @@
+	return(0);
@@ -597,4 +688,2 @@
-conv(xv,p,ip)
-float xv;
-register struct xy *p;
-int *ip;
+int
+conv(float xv, register struct xy *p, int *ip)
@@ -610,2 +699,2 @@
-getfloat(p)
-float *p;
+int
+getfloat(float *p)
@@ -613 +702 @@
-	register i;
+	register int i;
@@ -619 +708,2 @@
-getstring()
+int
+getstring(void)
@@ -621 +711 @@
-	register i;
+	register int i;
@@ -628 +718 @@
-		if(!isdigit(*labbuf)) {
+		if(!isdigit((unsigned char)*labbuf)) {
@@ -632,0 +723 @@
+		/* fallthrough */
@@ -649 +740,2 @@
-symbol(ix,iy,k)
+int
+symbol(int ix, int iy, int k)
@@ -661 +753 @@
-		return(!brkf|k<0);
+		return((!brkf)|(k<0));
@@ -665 +757,2 @@
-title()
+int
+title(void)
@@ -676,0 +770 @@
+	return(0);
@@ -679,3 +773,2 @@
-axlab(c,p)
-char c;
-struct xy *p;
+int
+axlab(int c, struct xy *p)
@@ -686,0 +780 @@
+	return(0);
@@ -689 +783,2 @@
-badarg()
+int
+badarg(void)
@@ -692,0 +788,84 @@
+	return(0);
+}
+int
+putsi(int a)
+{
+	putc(a, stdout);
+	putc(a >> 8, stdout);
+	return(0);
+}
+int
+space(int x0, int y0, int x1, int y1)
+{
+	putc('s', stdout);
+	putsi(x0);
+	putsi(y0);
+	putsi(x1);
+	putsi(y1);
+	return(0);
+}
+int
+erase(void)
+{
+	putc('e', stdout);
+	return(0);
+}
+int
+move(int xi, int yi)
+{
+	putc('m', stdout);
+	putsi(xi);
+	putsi(yi);
+	return(0);
+}
+int
+cont(int xi, int yi)
+{
+	putc('n', stdout);
+	putsi(xi);
+	putsi(yi);
+	return(0);
+}
+int
+line(int x0, int y0, int x1, int y1)
+{
+	putc('l', stdout);
+	putsi(x0);
+	putsi(y0);
+	putsi(x1);
+	putsi(y1);
+	return(0);
+}
+int
+point(int xi, int yi)
+{
+	putc('p', stdout);
+	putsi(xi);
+	putsi(yi);
+	return(0);
+}
+int
+label(char *s)
+{
+	int i;
+	putc('t', stdout);
+	for(i=0; s[i]; i++)
+		putc(s[i], stdout);
+	putc('\n', stdout);
+	return(0);
+}
+int
+linemod(char *s)
+{
+	int i;
+	putc('f', stdout);
+	for(i=0; s[i]; i++)
+		putc(s[i], stdout);
+	putc('\n', stdout);
+	return(0);
+}
+int
+closevt(void)
+{
+	fflush(stdout);
+	return(0);

% usr/src/cmd/grep.c
@@ -59,2 +59,8 @@
-main(argc, argv)
-char **argv;
+void compile(char *astr);
+void execute(char *file);
+int advance(register char *lp, register char *ep);
+void succeed(char *f);
+int ecmp(char *a, char *b, int count);
+void errexit(char *s, char *f);
+int
+main(int argc, char *argv[])
@@ -119 +125 @@
-			} else if (islower(*p)) {
+			} else if (islower((unsigned char)*p)) {
@@ -121 +127 @@
-				*s++ = toupper(*p);
+				*s++ = toupper((unsigned char)*p);
@@ -145,2 +151,2 @@
-compile(astr)
-char *astr;
+void
+compile(char *astr)
@@ -148 +154 @@
-	register c;
+	register int c;
@@ -208 +214 @@
-					for (c = sp[-2]; c<*sp; c++)
+					for (c = sp[-2]&0177; c<(*sp&0177); c++)
@@ -212 +218 @@
-				ep[c>>3] |= bittab[c&07];
+				ep[(c&0177)>>3] |= bittab[c&07];
@@ -250,0 +257 @@
+			goto defchar;
@@ -262,2 +269,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -266 +273 @@
-	register c;
+	register int c;
@@ -324,2 +331,2 @@
-advance(lp, ep)
-register char *lp, *ep;
+int
+advance(register char *lp, register char *ep)
@@ -360 +367 @@
-		braslist[*ep++] = lp;
+		braslist[(unsigned char)*ep++] = lp;
@@ -364 +371 @@
-		braelist[*ep++] = lp;
+		braelist[(unsigned char)*ep++] = lp;
@@ -368,2 +375,2 @@
-		bbeg = braslist[*ep];
-		if (braelist[*ep]==0)
+		bbeg = braslist[(unsigned char)*ep];
+		if (braelist[(unsigned char)*ep]==0)
@@ -371 +378 @@
-		ct = braelist[*ep++] - bbeg;
+		ct = braelist[(unsigned char)*ep++] - bbeg;
@@ -379,2 +386,2 @@
-		bbeg = braslist[*ep];
-		if (braelist[*ep]==0)
+		bbeg = braslist[(unsigned char)*ep];
+		if (braelist[(unsigned char)*ep]==0)
@@ -382 +389 @@
-		ct = braelist[*ep++] - bbeg;
+		ct = braelist[(unsigned char)*ep++] - bbeg;
@@ -439,2 +446,2 @@
-succeed(f)
-char *f;
+void
+succeed(char *f)
@@ -442 +449 @@
-	long ftell();
+	long ftell(FILE *iop);
@@ -464,2 +471,2 @@
-ecmp(a, b, count)
-char	*a, *b;
+int
+ecmp(char *a, char *b, int count)
@@ -467 +474 @@
-	register cc = count;
+	register int cc = count;
@@ -473,2 +480,2 @@
-errexit(s, f)
-char *s, *f;
+void
+errexit(char *s, char *f)

% usr/src/cmd/icheck.c
@@ -41,2 +41,11 @@
-long	atol();
-daddr_t	alloc();
+long	atol(register char *p);
+daddr_t	alloc(void);
+int	check(char *file);
+int	pass1(struct dinode *ip);
+int	chk(daddr_t bno, char *s);
+int	duped(daddr_t bno);
+int	bfree(daddr_t bno);
+int	bread(daddr_t bno, char *buf, int cnt);
+int	bwrite(daddr_t bno, char *buf);
+int	makefree(void);
+int	l3tol(long *lp, char *cp, int n);
@@ -44 +53 @@
-char	*malloc();
+char	*malloc(unsigned n);
@@ -47,2 +56,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -50 +59 @@
-	register i;
+	register int i;
@@ -101,2 +110,2 @@
-check(file)
-char *file;
+int
+check(char *file)
@@ -104 +113 @@
-	register i, j;
+	register int i, j;
@@ -113 +122 @@
-		return;
+		return(0);
@@ -134 +143 @@
-	if (n != (unsigned)n) {
+	if (n != (long)(unsigned)n) {
@@ -149 +158 @@
-	for(i=0; i<(unsigned)n; i++)
+	for(i=0; i<(int)(unsigned)n; i++)
@@ -174 +183 @@
-		return;
+		return(0);
@@ -177 +186 @@
-	while(n = alloc()) {
+	while((n = alloc())) {
@@ -215,0 +225 @@
+	return(0);
@@ -218,2 +228,2 @@
-pass1(ip)
-register struct dinode *ip;
+int
+pass1(register struct dinode *ip)
@@ -224 +234 @@
-	register i, j;
+	register int i, j;
@@ -230 +240 @@
-		return;
+		return(0);
@@ -234 +244 @@
-		return;
+		return(0);
@@ -238 +248 @@
-		return;
+		return(0);
@@ -246 +256 @@
-		return;
+		return(0);
@@ -261 +271 @@
-		for(j=0; j<NINDIR; j++) {
+		for(j=0; j<(int)NINDIR; j++) {
@@ -273 +283 @@
-			for(k=0; k<NINDIR; k++) {
+			for(k=0; k<(int)NINDIR; k++) {
@@ -285 +295 @@
-				for(l=0; l<NINDIR; l++)
+				for(l=0; l<(int)NINDIR; l++)
@@ -292,0 +303 @@
+	return(0);
@@ -295,3 +306,2 @@
-chk(bno, s)
-daddr_t bno;
-char *s;
+int
+chk(daddr_t bno, char *s)
@@ -299 +309 @@
-	register n;
+	register int n;
@@ -315,2 +325,2 @@
-duped(bno)
-daddr_t bno;
+int
+duped(daddr_t bno)
@@ -319 +329 @@
-	register m, n;
+	register int m, n;
@@ -333 +343 @@
-alloc()
+alloc(void)
@@ -355 +365 @@
-		sblock.s_nfree = buf.df_nfree;
+		sblock.s_nfree = buf.fb.df_nfree;
@@ -363 +373 @@
-			sblock.s_free[i] = buf.df_free[i];
+			sblock.s_free[i] = buf.fb.df_free[i];
@@ -368,2 +378,2 @@
-bfree(bno)
-daddr_t bno;
+int
+bfree(daddr_t bno)
@@ -381 +391 @@
-		buf.df_nfree = sblock.s_nfree;
+		buf.fb.df_nfree = sblock.s_nfree;
@@ -383 +393 @@
-			buf.df_free[i] = sblock.s_free[i];
+			buf.fb.df_free[i] = sblock.s_free[i];
@@ -388,0 +399 @@
+	return(0);
@@ -391,3 +402,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+int
+bread(daddr_t bno, char *buf, int cnt)
@@ -395 +405 @@
-	register i;
+	register int i;
@@ -406,0 +417 @@
+	return(0);
@@ -409,3 +420,2 @@
-bwrite(bno, buf)
-daddr_t bno;
-char	*buf;
+int
+bwrite(daddr_t bno, char *buf)
@@ -416,0 +427 @@
+	return(0);
@@ -419 +430,2 @@
-makefree()
+int
+makefree(void)
@@ -423 +435 @@
-	register i, j;
+	register int i, j;
@@ -474 +486 @@
-	return;
+	return(0);

% usr/src/cmd/init.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -38 +39,14 @@
-main()
+int shutdown(void);
+int single(void);
+int runcom(void);
+int multiple(void);
+int merge(void);
+int term(struct tab *p);
+int rline(void);
+int maktty(char *lin);
+int get(void);
+int dfork(struct tab *p);
+int rmut(struct tab *p);
+void reset(void);
+int
+main(void)
@@ -40 +53,0 @@
-	int reset();
@@ -43 +56 @@
-	signal(SIGHUP, reset);
+	signal(SIGHUP, (int)reset);
@@ -50,0 +64 @@
+	return(0);
@@ -53 +67,2 @@
-shutdown()
+int
+shutdown(void)
@@ -55 +70 @@
-	register i;
+	register int i;
@@ -61 +76 @@
-	signal(SIGALRM, reset);
+	signal(SIGALRM, (int)reset);
@@ -70,0 +86 @@
+	return(0);
@@ -73 +89,2 @@
-single()
+int
+single(void)
@@ -75 +92 @@
-	register pid;
+	register int pid;
@@ -92,0 +110 @@
+	return(0);
@@ -95 +113,2 @@
-runcom()
+int
+runcom(void)
@@ -97 +116 @@
-	register pid;
+	register int pid;
@@ -108,0 +128 @@
+	return(0);
@@ -111 +131,2 @@
-multiple()
+int
+multiple(void)
@@ -114 +135 @@
-	register pid;
+	register int pid;
@@ -119 +140 @@
-			return;
+			return(0);
@@ -128,2 +149,2 @@
-term(p)
-register struct tab *p;
+int
+term(struct tab *p)
@@ -137,0 +159 @@
+	return(0);
@@ -140 +162,2 @@
-rline()
+int
+rline(void)
@@ -142 +165 @@
-	register c, i;
+	register int c, i;
@@ -174,2 +197,2 @@
-maktty(lin)
-char *lin;
+int
+maktty(char *lin)
@@ -177 +200 @@
-	register i, j;
+	register int i, j;
@@ -185,0 +209 @@
+	return(0);
@@ -188 +212,2 @@
-get()
+int
+get(void)
@@ -199 +224,2 @@
-merge()
+int
+merge(void)
@@ -202 +228 @@
-	register i;
+	register int i;
@@ -205 +231 @@
-	signal(SIGINT, merge);
+	signal(SIGINT, (int)merge);
@@ -208 +234 @@
-		return;
+		return(0);
@@ -240,0 +267 @@
+	return(0);
@@ -243,2 +270,2 @@
-dfork(p)
-struct tab *p;
+int
+dfork(struct tab *p)
@@ -246 +273 @@
-	register pid;
+	register int pid;
@@ -263,0 +291 @@
+	return(0);
@@ -266,2 +294,2 @@
-rmut(p)
-register struct tab *p;
+int
+rmut(struct tab *p)
@@ -269 +297 @@
-	register i, f;
+	register int i, f;
@@ -296,0 +325 @@
+	return(0);
@@ -299 +328,2 @@
-reset()
+void
+reset(void)

% usr/src/cmd/iostat.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -7,2 +8 @@
-struct
-{
+struct nlent {
@@ -12,4 +11,0 @@
-} nl[] = {
-	"_dk_busy", 0, 0,
-	"_io_info", 0, 0,
-	"\0\0\0\0\0\0\0\0", 0, 0
@@ -17,2 +13,11 @@
-struct
-{
+struct nlent nl[] = {
+	{"_dk_busy", 0, 0},
+	{"_io_info", 0, 0},
+	{"_dk_time", 0, 0},
+	{"_dk_numb", 0, 0},
+	{"_dk_wds",  0, 0},
+	{"_tk_nin",  0, 0},
+	{"_tk_nout", 0, 0},
+	{"\0\0\0\0\0\0\0\0", 0, 0}
+};
+struct sample {
@@ -39,2 +44,9 @@
-main(argc, argv)
-char *argv[];
+int	stats(int);
+int	stat1(int);
+int	stats2(double);
+int	stats3(double);
+int	biostats(void);
+int	atoi(char *);
+int	nlist(char *, struct nlent *);
+int
+main(int argc, char *argv[])
@@ -42,2 +54,2 @@
-	extern char *ctime();
-	register  i;
+	extern char *ctime(long *t);
+	register  int i;
@@ -49 +61 @@
-	if(nl[0].type == -1) {
+	if(nl[0].type == 0) {
@@ -90,2 +102,22 @@
-	read(mf, (char *)&s, sizeof s);
-	for(i=0; i<40; i++) {
+	read(mf, (char *)&s.busy, sizeof(s.busy));
+	if (nl[2].type != 0) {
+		lseek(mf, (long)nl[2].value, 0);
+		read(mf, (char *)s.etime, sizeof(s.etime));
+	}
+	if (nl[3].type != 0) {
+		lseek(mf, (long)nl[3].value, 0);
+		read(mf, (char *)s.numb, sizeof(s.numb));
+	}
+	if (nl[4].type != 0) {
+		lseek(mf, (long)nl[4].value, 0);
+		read(mf, (char *)s.wds, sizeof(s.wds));
+	}
+	if (nl[5].type != 0) {
+		lseek(mf, (long)nl[5].value, 0);
+		read(mf, (char *)&s.tin, sizeof(s.tin));
+	}
+	if (nl[6].type != 0) {
+		lseek(mf, (long)nl[6].value, 0);
+		read(mf, (char *)&s.tout, sizeof(s.tout));
+	}
+	for(i=0; i<32; i++) {
@@ -95,0 +128,14 @@
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
@@ -139,0 +186 @@
+	return(0);
@@ -149 +196,2 @@
-stats(dn)
+int
+stats(int dn)
@@ -151 +199 @@
-	register i;
+	register int i;
@@ -165 +213 @@
-		return;
+		return(0);
@@ -175,0 +224 @@
+	return(0);
@@ -178 +227,2 @@
-stat1(o)
+int
+stat1(int o)
@@ -180 +230 @@
-	register i;
+	register int i;
@@ -194,0 +245 @@
+	return(0);
@@ -197,2 +248,2 @@
-stats2(t)
-double t;
+int
+stats2(double t)
@@ -200 +251 @@
-	register i, j;
+	register int i, j;
@@ -206,0 +258 @@
+	return(0);
@@ -209,2 +261,2 @@
-stats3(t)
-double t;
+int
+stats3(double t)
@@ -212 +264 @@
-	register i;
+	register int i;
@@ -251,0 +304 @@
+	return(0);
@@ -254 +307,2 @@
-biostats()
+int
+biostats(void)
@@ -256 +310 @@
-register i;
+	register int i;
@@ -257,0 +312,2 @@
+	if (nl[1].type == 0)
+		return(0);
@@ -270,0 +327 @@
+	return(0);

% usr/src/cmd/join.c
@@ -25,2 +25,6 @@
-main(argc, argv)
-char *argv[];
+int input(int n);
+void output(int on1, int on2);
+void error(char *s1, char *s2, char *s3, char *s4, char *s5);
+int cmp(char *s1, char *s2);
+int
+main(int argc, char *argv[])
@@ -30,2 +34,2 @@
-	long top2, bot2;
-	long ftell();
+	long top2 = 0, bot2;
+	long ftell(FILE *iop);
@@ -88 +92 @@
-		error("usage: join [-j1 x -j2 y] [-o list] file1 file2");
+		error("usage: join [-j1 x -j2 y] [-o list] file1 file2", 0, 0, 0, 0);
@@ -96 +100 @@
-		error("can't open %s", argv[1]);
+		error("can't open %s", argv[1], 0, 0, 0);
@@ -98 +102 @@
-		error("can't open %s", argv[2]);
+		error("can't open %s", argv[2], 0, 0, 0);
@@ -105,2 +109,2 @@
-	while(n1>0 && n2>0 || aflg!=0 && n1+n2>0) {
-		if(n1>0 && n2>0 && comp()>0 || n1==0) {
+	while((n1>0 && n2>0) || (aflg!=0 && n1+n2>0)) {
+		if((n1>0 && n2>0 && comp()>0) || n1==0) {
@@ -110 +114 @@
-		} else if(n1>0 && n2>0 && comp()<0 || n2==0) {
+		} else if((n1>0 && n2>0 && comp()<0) || n2==0) {
@@ -126 +130 @@
-				} else if(n1>0 && n2>0 && comp()<0 || n2==0) {
+				} else if((n1>0 && n2>0 && comp()<0) || n2==0) {
@@ -141,0 +146 @@
+int
@@ -142,0 +148 @@
+int n;
@@ -169,0 +176 @@
+void
@@ -188,2 +195,2 @@
-			if(olistf[i]==F1 && on1<=olist[i] ||
-			   olistf[i]==F2 && on2<=olist[i] ||
+			if((olistf[i]==F1 && on1<=olist[i]) ||
+			   (olistf[i]==F2 && on2<=olist[i]) ||
@@ -201,2 +208,2 @@
-error(s1, s2, s3, s4, s5)
-char *s1;
+void
+error(char *s1, char *s2, char *s3, char *s4, char *s5)
@@ -210,2 +217,2 @@
-cmp(s1, s2)
-char *s1, *s2;
+int
+cmp(char *s1, char *s2)

% usr/src/cmd/kill.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -7,2 +8,3 @@
-main(argc, argv)
-char **argv;
+extern char *sys_errlist[];
+int
+main(int argc, char **argv)
@@ -10 +12 @@
-	register signo, pid, res;
+	register int signo, pid, res;
@@ -12,2 +14 @@
-	extern char *sys_errlist[];
-	extern errno;
+	extern int errno;

% usr/src/cmd/ln.c
@@ -8 +8 @@
-char	*rindex();
+char	*rindex(char *sp, int c);
@@ -10,2 +10,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)

% usr/src/cmd/login.c
@@ -15 +15 @@
-struct	passwd nouser = {"", "nope"};
+struct	passwd nouser = {"", "nope", 0, 0, 0, 0, 0, 0, 0};
@@ -23,7 +22,0 @@
-struct	passwd *getpwnam();
-char	*strcat();
-int	setpwent();
-char	*ttyname();
-char	*crypt();
-char	*getpass();
-char	*rindex(), *index();
@@ -30,0 +24 @@
+void	showmotd(void);
@@ -32,2 +26,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -131 +125,2 @@
-catch()
+void
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
@@ -142 +139 @@
-	signal(SIGINT, catch);
+	signal(SIGINT, (int)catch);

% usr/src/cmd/look.c
@@ -14,2 +14,5 @@
-main(argc,argv)
-char **argv;
+void canon(char *old, char *new);
+int compare(register char *s, register char *t);
+int getword(char *w);
+int
+main(int argc, char *argv[])
@@ -17 +20 @@
-	register c;
+	register int c;
@@ -44 +47 @@
-		return;
+		return(0);
@@ -87 +90 @@
-			return;
+			return(0);
@@ -91 +94 @@
-			return;
+			return(0);
@@ -111,0 +115 @@
+	return(0);
@@ -114,2 +118,2 @@
-compare(s,t)
-register char *s,*t;
+int
+compare(register char *s, register char *t)
@@ -126,2 +130,2 @@
-getword(w)
-char *w;
+int
+getword(char *w)
@@ -129 +133 @@
-	register c;
+	register int c;
@@ -142,2 +146,2 @@
-canon(old,new)
-char *old,*new;
+void
+canon(char *old, char *new)
@@ -145 +149 @@
-	register c;
+	register int c;

% usr/src/cmd/ls.c
@@ -42,4 +42,10 @@
-char	*makename();
-struct	lbuf *gstat();
-char	*ctime();
-long	nblock();
+char	*makename(char *dir, char *file);
+struct	lbuf *gstat(char *file, int argfl);
+char	*ctime(long *t);
+long	nblock(long size);
+void	pentry(struct lbuf *ap);
+int	getname(int uid, char buf[]);
+void	pmode(int aflag);
+void	select(int *pairp);
+void	readdir(char *dir);
+int	compar(struct lbuf **pp1, struct lbuf **pp2);
@@ -49,2 +55,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -58 +64 @@
-	int compar();
+	int compar(struct lbuf **pp1, struct lbuf **pp2);
@@ -146 +152 @@
-		if (ep->ltype=='d' && dflg==0 || fflg) {
+		if ((ep->ltype=='d' && dflg==0) || fflg) {
@@ -163,2 +169,2 @@
-pentry(ap)
-struct lbuf *ap;
+void
+pentry(struct lbuf *ap)
@@ -166,2 +172 @@
-	struct { char dminor, dmajor;};
-	register t;
+	register int t;
@@ -204,3 +209,2 @@
-getname(uid, buf)
-int uid;
-char buf[];
+int
+getname(int uid, char buf[])
@@ -239,2 +243 @@
-nblock(size)
-long size;
+nblock(long size)
@@ -257 +260,2 @@
-pmode(aflag)
+void
+pmode(int aflag)
@@ -266,2 +270,2 @@
-select(pairp)
-register int *pairp;
+void
+select(register int *pairp)
@@ -278,2 +282 @@
-makename(dir, file)
-char *dir, *file;
+makename(char *dir, char *file)
@@ -297,2 +300,2 @@
-readdir(dir)
-char *dir;
+void
+readdir(char *dir)
@@ -313,2 +316,2 @@
-		 || aflg==0 && dentry.d_name[0]=='.' &&  (dentry.d_name[1]=='\0'
-			|| dentry.d_name[1]=='.' && dentry.d_name[2]=='\0'))
+		 || (aflg==0 && dentry.d_name[0]=='.' && (dentry.d_name[1]=='\0'
+			|| (dentry.d_name[1]=='.' && dentry.d_name[2]=='\0'))))
@@ -328,2 +331 @@
-gstat(file, argfl)
-char *file;
+gstat(char *file, int argfl)
@@ -331 +332,0 @@
-	extern char *malloc();
@@ -400,2 +401,2 @@
-compar(pp1, pp2)
-struct lbuf **pp1, **pp2;
+int
+compar(struct lbuf **pp1, struct lbuf **pp2)

% usr/src/cmd/makekey.c
@@ -8 +8,3 @@
-char	*crypt();
+char	*crypt(char *pw, char *salt);
+int	read(int fd, char *buf, int n);
+int	write(int fd, char *buf, int n);
@@ -10 +12,2 @@
-main()
+int
+main(void)

% usr/src/cmd/mesg.c
@@ -19,2 +19,4 @@
-main(argc, argv)
-char *argv[];
+void error(char *s);
+void newmode(int m);
+int
+main(int argc, char *argv[])
@@ -44,2 +46,2 @@
-error(s)
-char *s;
+void
+error(char *s)
@@ -51 +53,2 @@
-newmode(m)
+void
+newmode(int m)

% usr/src/cmd/mkdir.c
@@ -9,2 +9 @@
-char	*strcat();
-char	*strcpy();
+void	mkdir(char *d);
@@ -12,2 +11,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -31,2 +30,2 @@
-mkdir(d)
-char *d;
+void
+mkdir(char *d)
@@ -35 +34 @@
-	register i, slash = 0;
+	register int i, slash = 0;

% usr/src/cmd/mkfs.c
@@ -8,0 +9 @@
+#define	MAXFILEBLK	(LADDR+NINDIR+(NINDIR*NINDIR))
@@ -13 +14,4 @@
-#include <a.out.h>
+#include <stdlib.h>
+#include <unistd.h>
+#include <fcntl.h>
+#include <time.h>
@@ -20,0 +25,8 @@
+int ltol3(cp, lp, n) char *cp; long *lp; int n; {
+	int i; long v;
+	for(i=0; i<n; i++) {
+		v = lp[i];
+		*cp++ = v; *cp++ = v >> 8; *cp++ = v >> 16;
+	}
+	return(0);
+}
@@ -31 +43 @@
-union {
+union fbuf_u {
@@ -34,4 +46,2 @@
-} fbuf;
-#ifndef STANDALONE
-struct exec head;
-#endif
+} fbuf_storage;
+#define fbuf fbuf_storage.fb
@@ -39 +49 @@
-union {
+union filsys_u {
@@ -42 +52,2 @@
-} filsys;
+} filsys_storage;
+#define filsys filsys_storage.fs
@@ -49,2 +60,15 @@
-long	getnum();
-daddr_t	alloc();
+struct	inode;
+long	getnum(void);
+daddr_t	alloc(void);
+void	cfile(struct inode *par);
+void	getstr(void);
+int	gmode(int c, char *s, int m0, int m1, int m2, int m3);
+void	rdfs(daddr_t bno, char *bf);
+void	wtfs(daddr_t bno, char *bf);
+void	bfree(daddr_t bno);
+void	entry(ino_t inum, char *str, int *adbc, char *db, int *aibc, daddr_t *ib);
+void	newblk(int *adbc, char *db, int *aibc, daddr_t *ib);
+int	getch(void);
+void	bflist(void);
+void	iput(struct inode *ip, int *aibc, daddr_t *ib);
+int	badblk(daddr_t bno);
@@ -52,2 +76,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -59 +83,4 @@
-	time(&utime);
+	if ((fsys = getenv("V7_MKFS_TIME")) != NULL)
+		utime = atol(fsys);
+	else
+		time(&utime);
@@ -103 +130 @@
-		for(f=0; c=proto[f]; f++) {
+		for(f=0; (c=proto[f]); f++) {
@@ -114 +141 @@
-		if(n > 65500/NIPB)
+		if((unsigned long)n > 65500/NIPB)
@@ -117 +144 @@
-		printf("isize = %D\n", n*NIPB);
+		printf("isize = %ld\n", n*NIPB);
@@ -125 +151,0 @@
-	 * and read onto block 0
@@ -130,16 +156,3 @@
-	if(f < 0) {
-		printf("%s: cannot  open init\n", string);
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
+	if(f < 0)
+		printf("%s: cannot open init\n", string);
+	else
@@ -147 +159,0 @@
-f1:
@@ -155 +166,0 @@
-f2:
@@ -175 +186 @@
-		printf("%ld/%ld: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
+		printf("%ld/%d: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
@@ -197,2 +208,2 @@
-cfile(par)
-struct inode *par;
+void
+cfile(struct inode *par)
@@ -203 +214 @@
-	daddr_t ib[NINDIR];
+	daddr_t ib[MAXFILEBLK];
@@ -235 +246 @@
-	for(i=0; i<NINDIR; i++)
+	for(i=0; (unsigned)i<MAXFILEBLK; i++)
@@ -309,2 +320,2 @@
-gmode(c, s, m0, m1, m2, m3)
-char c, *s;
+int
+gmode(int c, char *s, int m0, int m1, int m2, int m3)
@@ -312,0 +324 @@
+	int m[4] = {m0, m1, m2, m3};
@@ -316 +328 @@
-			return((&m0)[i]);
+			return(m[i]);
@@ -323 +335 @@
-getnum()
+getnum(void)
@@ -331 +343 @@
-	for(i=0; c=string[i]; i++) {
+	for(i=0; (c=string[i]) != 0; i++) {
@@ -342 +354,2 @@
-getstr()
+void
+getstr(void)
@@ -372,3 +385,2 @@
-rdfs(bno, bf)
-daddr_t bno;
-char *bf;
+void
+rdfs(daddr_t bno, char *bf)
@@ -386,3 +398,2 @@
-wtfs(bno, bf)
-daddr_t bno;
-char *bf;
+void
+wtfs(daddr_t bno, char *bf)
@@ -395 +406 @@
-		printf("write error: %D\n", bno);
+		printf("write error: %ld\n", bno);
@@ -401 +412 @@
-alloc()
+alloc(void)
@@ -421,2 +432,2 @@
-bfree(bno)
-daddr_t bno;
+void
+bfree(daddr_t bno)
@@ -437,6 +448,2 @@
-entry(inum, str, adbc, db, aibc, ib)
-ino_t inum;
-char *str;
-int *adbc, *aibc;
-char *db;
-daddr_t *ib;
+void
+entry(ino_t inum, char *str, int *adbc, char *db, int *aibc, daddr_t *ib)
@@ -456 +463 @@
-	if(*adbc >= NDIRECT)
+	if((unsigned)*adbc >= NDIRECT)
@@ -460,4 +467,2 @@
-newblk(adbc, db, aibc, ib)
-int *adbc, *aibc;
-char *db;
-daddr_t *ib;
+void
+newblk(int *adbc, char *db, int *aibc, daddr_t *ib)
@@ -467,0 +473,5 @@
+	if((unsigned)*aibc >= MAXFILEBLK) {
+		printf("indirect block full\n");
+		error = 1;
+		return;
+	}
@@ -475,5 +484,0 @@
-	if(*aibc >= NINDIR) {
-		printf("indirect block full\n");
-		error = 1;
-		*aibc = 0;
-	}
@@ -482 +487,2 @@
-getch()
+int
+getch(void)
@@ -494 +500,2 @@
-bflist()
+void
+bflist(void)
@@ -525 +532 @@
-	for(i=0; i<NINDIR; i++)
+	for(i=0; (unsigned)i<NINDIR; i++)
@@ -535 +542 @@
-		if(f < filsys.s_fsize && f >= filsys.s_isize)
+		if(f < filsys.s_fsize && f >= filsys.s_isize) {
@@ -537 +544 @@
-				if(ibc >= NINDIR) {
+				if((unsigned)ibc >= NINDIR) {
@@ -545,0 +553 @@
+		}
@@ -550,4 +558,2 @@
-iput(ip, aibc, ib)
-struct inode *ip;
-int *aibc;
-daddr_t *ib;
+void
+iput(struct inode *ip, int *aibc, daddr_t *ib)
@@ -556,2 +562,2 @@
-	daddr_t d;
-	int i;
+	daddr_t d, single[NINDIR], dbl[NINDIR];
+	int i, j, k, n;
@@ -584,4 +590,3 @@
-		for(i=0; i<*aibc; i++) {
-			if(i >= LADDR)
-				break;
-			ip->i_un.i_addr[i] = ib[i];
+		for(i=0; (unsigned)i<NINDIR; i++) {
+			single[i] = (daddr_t)0;
+			dbl[i] = (daddr_t)0;
@@ -589 +594,8 @@
-		if(*aibc >= LADDR) {
+		for(i=0; i<*aibc && i<LADDR; i++)
+			ip->i_un.i_addr[i] = ib[i];
+		if((unsigned)*aibc > LADDR) {
+			n = *aibc - LADDR;
+			if((unsigned)n > NINDIR)
+				n = (int)NINDIR;
+			for(i=0; i<n; i++)
+				single[i] = ib[LADDR+i];
@@ -591,3 +603,20 @@
-			for(i=0; i<NINDIR-LADDR; i++) {
-				ib[i] = ib[i+LADDR];
-				ib[i+LADDR] = (daddr_t)0;
+			wtfs(ip->i_un.i_addr[LADDR], (char *)single);
+		}
+		if((unsigned)*aibc > LADDR+NINDIR) {
+			n = *aibc - LADDR - NINDIR;
+			if((unsigned)n > NINDIR*NINDIR) {
+				printf("indirect block full\n");
+				error = 1;
+				n = (int)(NINDIR*NINDIR);
+			}
+			ip->i_un.i_addr[LADDR+1] = alloc();
+			k = LADDR + NINDIR;
+			for(i=0; (unsigned)i<NINDIR && n>0; i++) {
+				for(j=0; (unsigned)j<NINDIR; j++)
+					single[j] = (daddr_t)0;
+				for(j=0; (unsigned)j<NINDIR && n>0; j++) {
+					single[j] = ib[k++];
+					n--;
+				}
+				dbl[i] = alloc();
+				wtfs(dbl[i], (char *)single);
@@ -595 +624 @@
-			wtfs(ip->i_un.i_addr[LADDR], (char *)ib);
+			wtfs(ip->i_un.i_addr[LADDR+1], (char *)dbl);
@@ -596,0 +626 @@
+		/* fall through */
@@ -610,2 +640,2 @@
-badblk(bno)
-daddr_t bno;
+int
+badblk(daddr_t bno)
@@ -613,0 +644 @@
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
@@ -19,3 +19,7 @@
-char	*pname();
-char	*sprintf();
-char	*dname();
+char	*pname(register char *name);
+char	*sprintf(char *buf, char *fmt, ...);
+char	*dname(register char *name);
+int	move(char *source, char *target);
+int	mvdir(char *source, char *target);
+int	check(char *spth, ino_t dinode);
+int	chkdot(char *s);
@@ -24,2 +28,2 @@
-main(argc, argv)
-register char *argv[];
+int
+main(int argc, register char *argv[])
@@ -27 +31 @@
-	register i, r;
+	register int i, r;
@@ -53,2 +57,2 @@
-move(source, target)
-char *source, *target;
+int
+move(char *source, char *target)
@@ -56 +60 @@
-	register c, i;
+	register int c, i;
@@ -122,2 +126,2 @@
-mvdir(source, target)
-char *source, *target;
+int
+mvdir(char *source, char *target)
@@ -126 +130 @@
-	register i;
+	register int i;
@@ -229,2 +233 @@
-pname(name)
-register char *name;
+pname(register char *name)
@@ -232 +235 @@
-	register c;
+	register int c;
@@ -237 +240 @@
-	while (c = *p++ = *name++)
+	while ((c = *p++ = *name++))
@@ -247,2 +250 @@
-dname(name)
-register char *name;
+dname(register char *name)
@@ -259,3 +261,2 @@
-check(spth, dinode)
-char *spth;
-ino_t dinode;
+int
+check(char *spth, ino_t dinode)
@@ -278 +279 @@
-		if (strlen(nspth) > MAXN-2-sizeof(DOTDOT)) {
+		if (strlen(nspth) > (int)(MAXN-2-sizeof(DOTDOT))) {
@@ -288,2 +289,2 @@
-chkdot(s)
-register char *s;
+int
+chkdot(register char *s)

% usr/src/cmd/ncheck.c
@@ -37,3 +37,11 @@
-daddr_t	bmap();
-long	atol();
-struct htab *lookup();
+daddr_t	bmap(int i);
+long	atol(register char *p);
+struct htab *lookup(ino_t i, int ef);
+int	check(char *file);
+int	pass1(struct dinode *ip);
+int	pass2(struct dinode *ip);
+int	pass3(struct dinode *ip);
+int	dotname(struct direct *dp);
+int	pname(int i, int lev);
+int	bread(daddr_t bno, char *buf, int cnt);
+int	l3tol(long *lp, char *cp, int n);
@@ -41,2 +49,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -44 +52 @@
-	register i;
+	register int i;
@@ -81,2 +89,2 @@
-check(file)
-char *file;
+int
+check(char *file)
@@ -84 +92 @@
-	register i, j;
+	register int i, j;
@@ -91 +99 @@
-		return;
+		return(0);
@@ -134,0 +143 @@
+	return(0);
@@ -137,2 +146,2 @@
-pass1(ip)
-register struct dinode *ip;
+int
+pass1(register struct dinode *ip)
@@ -142 +151 @@
-			return;
+			return(0);
@@ -144 +153 @@
-		  || ip->di_mode&(ISUID|ISGID))
+		  || ip->di_mode&(ISUID|ISGID)) {
@@ -146 +155,3 @@
-			return;
+			return(0);
+		}
+		return(0);
@@ -148,0 +160 @@
+	return(0);
@@ -151,2 +163,2 @@
-pass2(ip)
-register struct dinode *ip;
+int
+pass2(register struct dinode *ip)
@@ -157 +169 @@
-	register i, j;
+	register int i, j;
@@ -164 +176 @@
-		return;
+		return(0);
@@ -174 +186 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -191,0 +204 @@
+	return(0);
@@ -194,2 +207,2 @@
-pass3(ip)
-register struct dinode *ip;
+int
+pass3(register struct dinode *ip)
@@ -200 +213 @@
-	register i, j;
+	register int i, j;
@@ -206 +219 @@
-		return;
+		return(0);
@@ -216 +229 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -240,0 +254 @@
+	return(0);
@@ -243,2 +257,2 @@
-dotname(dp)
-register struct direct *dp;
+int
+dotname(register struct direct *dp)
@@ -253,2 +267,2 @@
-pname(i, lev)
-ino_t i;
+int
+pname(int i, int lev)
@@ -259 +273 @@
-		return;
+		return(0);
@@ -262 +276 @@
-		return;
+		return(0);
@@ -266 +280 @@
-		return;
+		return(0);
@@ -269,0 +284 @@
+	return(0);
@@ -273,2 +288 @@
-lookup(i, ef)
-ino_t i;
+lookup(ino_t i, int ef)
@@ -294,3 +308,2 @@
-bread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+int
+bread(daddr_t bno, char *buf, int cnt)
@@ -298 +311 @@
-	register i;
+	register int i;
@@ -305,0 +319 @@
+	return(0);
@@ -309 +323 @@
-bmap(i)
+bmap(int i)
@@ -316 +330 @@
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
@@ -5,3 +5,3 @@
-main(argc, argv)
-int argc;
-char *argv[];
+extern char *sys_errlist[];
+int
+main(int argc, char *argv[])
@@ -10,2 +10 @@
-	extern errno;
-	extern char *sys_errlist[];
+	extern int errno;

% usr/src/cmd/od.c
@@ -14,2 +14,8 @@
-main(argc, argv)
-char **argv;
+void offset(register char *s);
+void line(long a, unsigned short *w, int n);
+void putx(unsigned n, int c);
+void cput(int c);
+void putn(long n, int b, int c);
+void pre(int n);
+int
+main(int argc, char *argv[])
@@ -18 +24 @@
-	register n, f, same;
+	register int n, f, same;
@@ -97,3 +103,2 @@
-line(a, w, n)
-long a;
-unsigned short *w;
+void
+line(long a, unsigned short *w, int n)
@@ -101 +106 @@
-	register i, f, c;
+	register int i, f, c;
@@ -120,2 +125,2 @@
-putx(n, c)
-unsigned n;
+void
+putx(unsigned n, int c)
@@ -158 +163,2 @@
-cput(c)
+void
+cput(int c)
@@ -190,2 +196,2 @@
-putn(n, b, c)
-long n;
+void
+putn(long n, int b, int c)
@@ -193 +199 @@
-	register d;
+	register int d;
@@ -205 +211,2 @@
-pre(n)
+void
+pre(int n)
@@ -213,2 +220,2 @@
-offset(s)
-register char *s;
+void
+offset(register char *s)

% usr/src/cmd/osh.c
@@ -55 +55 @@
-char	*mesg[NSIG] {
+char	*mesg[NSIG] = {
@@ -78,3 +78,34 @@
-main(c, av)
-int c;
-char **av;
+int *syntax(char **p1, char **p2);
+int execute(int *t, int *pf1, int *pf2);
+int main1(void);
+int word(void);
+int readc(void);
+int prs(char *as);
+int prn(int n);
+int prc(char ac);
+int putc(int c);
+int err(char *s, int code);
+int getc(void);
+int any(int c, char *as);
+int equal(char *s1, char *s2);
+int texec(char *f, int *at);
+int pwait(int pid, int *t);
+int *blkcpy(int **p);
+extern int read(int fd, char *buf, int n);
+extern int write(int fd, char *buf, int n);
+extern int close(int fd);
+extern int open(char *p, int f);
+extern int creat(char *p, int m);
+extern int pipe(int *pv);
+extern int dup();
+extern int fork(void);
+extern int wait(int *st);
+extern int execv(char *p, char **av);
+extern long lseek(int fd, long off, int whence);
+extern int getpid(void);
+extern int getuid(void);
+extern int chdir(char *p);
+extern int signal();
+extern void exit(int n) __attribute__((__noreturn__));
+int
+main(int c, char **av)
@@ -82,2 +113,2 @@
-	register f;
-	register char *acname, **v;
+	register int f;
+	register char **v;
@@ -93 +123,0 @@
-	acname = "<none>";
@@ -137 +167,2 @@
-main1()
+int
+main1(void)
@@ -140 +171 @@
-	register *t;
+	register int *t;
@@ -158 +189 @@
-				return;
+				return(0);
@@ -163 +194 @@
-			execute(t);
+			execute(t, 0, 0);
@@ -164,0 +196 @@
+	return(0);
@@ -167 +199,2 @@
-word()
+int
+word(void)
@@ -187 +220 @@
-				return;
+				return(0);
@@ -204 +237 @@
-		return;
+		return(0);
@@ -217 +250 @@
-			return;
+			return(0);
@@ -223,2 +256,2 @@
-tree(n)
-int n;
+int *
+tree(int n)
@@ -226 +259 @@
-	register *t;
+	register int *t;
@@ -229 +262 @@
-	treep =+ n;
+	treep += n;
@@ -238 +271,2 @@
-getc()
+int
+getc(void)
@@ -248 +282 @@
-		argp =- 10;
+		argp -= 10;
@@ -250 +284 @@
-		argp =+ 10;
+		argp += 10;
@@ -256 +290 @@
-		linep =- 10;
+		linep -= 10;
@@ -258 +292 @@
-		linep =+ 10;
+		linep += 10;
@@ -292 +326,2 @@
-readc()
+int
+readc(void)
@@ -296 +331 @@
-	register c;
+	register int c;
@@ -299 +334 @@
-		if (arginp == 1)
+		if (arginp == (char *)1)
@@ -302 +337 @@
-			arginp = 1;
+			arginp = (char *)1;
@@ -309 +344 @@
-	if((rdstat = read(0, &cc, 1)) != 1)
+	if((rdstat = read(0, &cc, 1)) != 1) {
@@ -311,0 +347 @@
+	}
@@ -323,2 +359,6 @@
-syntax(p1, p2)
-char **p1, **p2;
+int *syn1(char **p1, char **p2);
+int *syn2(char **p1, char **p2);
+int *syn3(char **p1, char **p2);
+int *syntax(char **p1, char **p2);
+int *
+syntax(char **p1, char **p2)
@@ -342,2 +382,2 @@
-syn1(p1, p2)
-char **p1, **p2;
+int *
+syn1(char **p1, char **p2)
@@ -346 +386 @@
-	register *t, *t1;
+	register int *t, *t1;
@@ -370 +410 @@
-			t[DLEF] = syn2(p1, p);
+			t[DLEF] = (int)(long)syn2(p1, p);
@@ -373,2 +413,2 @@
-				t1 = t[DLEF];
-				t1[DFLG] =| FAND|FPRS|FINT;
+				t1 = (int *)(long)t[DLEF];
+				t1[DFLG] |= FAND|FPRS|FINT;
@@ -376 +416 @@
-			t[DRIT] = syntax(p+1, p2);
+			t[DRIT] = (int)(long)syntax(p+1, p2);
@@ -392,2 +432,2 @@
-syn2(p1, p2)
-char **p1, **p2;
+int *
+syn2(char **p1, char **p2)
@@ -415,2 +455,2 @@
-			t[DLEF] = syn3(p1, p);
-			t[DRIT] = syn2(p+1, p2);
+			t[DLEF] = (int)(long)syn3(p1, p);
+			t[DRIT] = (int)(long)syn2(p+1, p2);
@@ -430,2 +470,2 @@
-syn3(p1, p2)
-char **p1, **p2;
+int *
+syn3(char **p1, char **p2)
@@ -435 +475 @@
-	register *t;
+	register int *t;
@@ -440 +480 @@
-		flg =| FPAR;
+		flg |= FPAR;
@@ -468 +508 @@
-			flg =| FCAT; else
+			flg |= FCAT; else
@@ -469,0 +510 @@
+		/* fallthrough */
@@ -483 +524 @@
-				i = *p;
+				i = (int)(long)*p;
@@ -488 +529 @@
-			o = *p;
+			o = (int)(long)*p;
@@ -501 +542 @@
-		t[DSPR] = syn1(lp, rp);
+		t[DSPR] = (int)(long)syn1(lp, rp);
@@ -510 +551 @@
-		t[l+DCOM] = p1[l];
+		t[l+DCOM] = (int)(long)p1[l];
@@ -518,3 +559,2 @@
-scan(at, f)
-int *at;
-int (*f)();
+int
+scan(int *at, int (*f)())
@@ -523 +563 @@
-	register *t;
+	register int *t;
@@ -526,2 +566,2 @@
-	while(p = *t++)
-		while(c = *p)
+	while((p = (char *)(long)*t++))
+		while((c = *p))
@@ -528,0 +569 @@
+	return(0);
@@ -531,2 +572,2 @@
-tglob(c)
-int c;
+int
+tglob(int c)
@@ -540,2 +581,2 @@
-trim(c)
-int c;
+int
+trim(int c)
@@ -547,2 +588,2 @@
-execute(t, pf1, pf2)
-int *t, *pf1, *pf2;
+int
+execute(int *t, int *pf1, int *pf2)
@@ -551 +592 @@
-	register *t1;
+	register int *t1;
@@ -553 +593,0 @@
-	extern errno;
@@ -559 +599 @@
-		cp1 = t[DCOM];
+		cp1 = (char *)(long)t[DCOM];
@@ -562 +602 @@
-				if(chdir(t[DCOM+1]) < 0)
+				if(chdir((char *)(long)t[DCOM+1]) < 0)
@@ -566 +606 @@
-			return;
+			return(0);
@@ -571 +611 @@
-				return;
+				return(0);
@@ -576 +616 @@
-			return;
+			return(0);
@@ -580 +620 @@
-				execv("/bin/login", t+DCOM);
+				execv("/bin/login", (char **)(t+DCOM));
@@ -583 +623 @@
-			return;
+			return(0);
@@ -587 +627 @@
-				execv("/bin/newgrp", t+DCOM);
+				execv("/bin/newgrp", (char **)(t+DCOM));
@@ -590 +630 @@
-			return;
+			return(0);
@@ -594 +634 @@
-			return;
+			return(0);
@@ -597 +637,2 @@
-			return;
+			return(0);
+		/* fallthrough */
@@ -606 +647 @@
-			return;
+			return(0);
@@ -618 +659 @@
-				return;
+				return(0);
@@ -621 +662 @@
-			return;
+			return(0);
@@ -625 +666 @@
-			i = open(t[DLEF], 0);
+			i = open((char *)(long)t[DLEF], 0);
@@ -627 +668 @@
-				prs(t[DLEF]);
+				prs((char *)(long)t[DLEF]);
@@ -634 +675 @@
-				i = open(t[DRIT], 1);
+				i = open((char *)(long)t[DRIT], 1);
@@ -640 +681 @@
-			i = creat(t[DRIT], 0666);
+			i = creat((char *)(long)t[DRIT], 0666);
@@ -642 +683 @@
-				prs(t[DRIT]);
+				prs((char *)(long)t[DRIT]);
@@ -672,3 +713,3 @@
-			if(t1 = t[DSPR])
-				t1[DFLG] =| f&FINT;
-			execute(t1);
+			if((t1 = (int *)(long)t[DSPR]))
+				t1[DFLG] |= f&FINT;
+			execute(t1, 0, 0);
@@ -680,2 +721,2 @@
-			t[DSPR] = "/etc/glob";
-			execv(t[DSPR], t+DSPR);
+			t[DSPR] = (int)(long)"/etc/glob";
+			execv((char *)(long)t[DSPR], (char **)(t+DSPR));
@@ -687 +728 @@
-		texec(t[DCOM], t);
+		texec((char *)(long)t[DCOM], t);
@@ -690 +731 @@
-		while(*cp1 = *cp2++)
+		while((*cp1 = *cp2++))
@@ -692,2 +733,2 @@
-		cp2 = t[DCOM];
-		while(*cp1++ = *cp2++);
+		cp2 = (char *)(long)t[DCOM];
+		while((*cp1++ = *cp2++));
@@ -696 +737 @@
-		prs(t[DCOM]);
+		prs((char *)(long)t[DCOM]);
@@ -703,2 +744,2 @@
-		t1 = t[DLEF];
-		t1[DFLG] =| FPOU | (f&(FPIN|FINT|FPRS));
+		t1 = (int *)(long)t[DLEF];
+		t1[DFLG] |= FPOU | (f&(FPIN|FINT|FPRS));
@@ -706,2 +747,2 @@
-		t1 = t[DRIT];
-		t1[DFLG] =| FPIN | (f&(FPOU|FINT|FAND|FPRS));
+		t1 = (int *)(long)t[DRIT];
+		t1[DFLG] |= FPIN | (f&(FPOU|FINT|FAND|FPRS));
@@ -709 +750 @@
-		return;
+		return(0);
@@ -713,7 +754,7 @@
-		if(t1 = t[DLEF])
-			t1[DFLG] =| f;
-		execute(t1);
-		if(t1 = t[DRIT])
-			t1[DFLG] =| f;
-		execute(t1);
-		return;
+		if((t1 = (int *)(long)t[DLEF]))
+			t1[DFLG] |= f;
+		execute(t1, 0, 0);
+		if((t1 = (int *)(long)t[DRIT]))
+			t1[DFLG] |= f;
+		execute(t1, 0, 0);
+		return(0);
@@ -721,0 +763 @@
+	return(0);
@@ -724,2 +766,2 @@
-texec(f, at)
-int *at;
+int
+texec(char *f, int *at)
@@ -727 +769 @@
-	extern errno;
+	extern int errno;
@@ -731 +773 @@
-	execv(f, t+DCOM);
+	execv(f, (char **)(t+DCOM));
@@ -734,3 +776,3 @@
-			t[DCOM] = linep;
-		t[DSPR] = "/usr/bin/osh";
-		execv(t[DSPR], t+DSPR);
+			t[DCOM] = (int)(long)linep;
+		t[DSPR] = (int)(long)"/usr/bin/osh";
+		execv((char *)(long)t[DSPR], (char **)(t+DSPR));
@@ -741 +783 @@
-		prs(t[DCOM]);
+		prs((char *)(long)t[DCOM]);
@@ -744,0 +787 @@
+	return(0);
@@ -747,3 +790,2 @@
-err(s, exitno)
-char *s;
-int exitno;
+int
+err(char *s, int exitno)
@@ -757,0 +800 @@
+	return(0);
@@ -760,2 +803,2 @@
-prs(as)
-char *as;
+int
+prs(char *as)
@@ -767,0 +811 @@
+	return(0);
@@ -770 +814,2 @@
-putc(c)
+int
+putc(int c)
@@ -775,0 +821 @@
+	return(0);
@@ -778,2 +824,2 @@
-prn(n)
-int n;
+int
+prn(int n)
@@ -781 +827 @@
-	register a;
+	register int a;
@@ -783 +829 @@
-	if (a = n/10)
+	if ((a = n/10))
@@ -785,0 +832 @@
+	return(0);
@@ -788,3 +835,2 @@
-any(c, as)
-int c;
-char *as;
+int
+any(int c, char *as)
@@ -801,2 +847,2 @@
-equal(as1, as2)
-char *as1, *as2;
+int
+equal(char *as1, char *as2)
@@ -814,2 +860,2 @@
-pwait(i, t)
-int i, *t;
+int
+pwait(int i, int *t)
@@ -817 +863 @@
-	register p, e;
+	register int p, e;
@@ -818,0 +865 @@
+	(void)t;
@@ -840 +887 @@
-		if (e || s&&stoperr)
+		if (e || (s&&stoperr))
@@ -842 +889 @@
-		errval =| (s>>8);
+		errval |= (s>>8);
@@ -843,0 +891 @@
+	return(0);

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
@@ -111,3 +105,3 @@
-	signal(SIGHUP, SIG_IGN);
-	signal(SIGINT, SIG_IGN);
-	signal(SIGQUIT, SIG_IGN);
+	signal(SIGHUP, (int)SIG_IGN);
+	signal(SIGINT, (int)SIG_IGN);
+	signal(SIGQUIT, (int)SIG_IGN);

% usr/src/cmd/pr.c
@@ -41,2 +41,2 @@
-char	*ttyname();
-char	*ctime();
+char	*ttyname(int f);
+char	*ctime(long *t);
@@ -44,2 +44,13 @@
-main(argc, argv)
-char **argv;
+void	done(void);
+void	fixtty(void);
+void	print(char *fp, char **argp);
+void	mopen(char **ap);
+void	putpage(void);
+void	nexbuf(void);
+int	tpgetc(int ai);
+int	pgetc(int i);
+void	put(int ac);
+void	putcp(int c);
+void	onintr(void);
+int
+main(int argc, char **argv)
@@ -47,2 +57,0 @@
-	int nfdone;
-	int onintr();
@@ -49,0 +59 @@
+	int nfdone;
@@ -52 +62 @@
-		signal(SIGINT, onintr);
+		signal(SIGINT, (int)onintr);
@@ -107 +117,2 @@
-done()
+void
+done(void)
@@ -115 +126,2 @@
-onintr()
+void
+onintr(void)
@@ -123 +135,2 @@
-fixtty()
+void
+fixtty(void)
@@ -135,3 +148,2 @@
-print(fp, argp)
-char *fp;
-char **argp;
+void
+print(char *fp, char **argp)
@@ -139 +150,0 @@
-	extern char *sprintf();
@@ -141 +152 @@
-	register sncol;
+	register int sncol;
@@ -195 +206 @@
-	while (mflg&&nofile || (!mflg)&&tpgetc(ncol)>0) {
+	while ((mflg&&nofile) || ((!mflg)&&tpgetc(ncol)>0)) {
@@ -218,2 +229,2 @@
-mopen(ap)
-char **ap;
+void
+mopen(char **ap)
@@ -238 +249,2 @@
-putpage()
+void
+putpage(void)
@@ -282 +294,2 @@
-nexbuf()
+void
+nexbuf(void)
@@ -305 +318,2 @@
-tpgetc(ai)
+int
+tpgetc(int ai)
@@ -340 +354,2 @@
-pgetc(i)
+int
+pgetc(int i)
@@ -372 +387,2 @@
-put(ac)
+void
+put(int ac)
@@ -418 +434,2 @@
-putcp(c)
+void
+putcp(int c)

% usr/src/cmd/primes.c usr/src/cmd/primes.s
@@ -1,355 +1,149 @@
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
+
+#define MAXNUM 72057594037927936ULL
+
+static int
+parse_number(char *s, unsigned long long *out)
+{
+	unsigned long long n;
+	int any;
+
+	while (*s == ' ' || *s == '\t' || *s == '\n')
+		s++;
+	n = 0;
+	any = 0;
+	while (*s >= '0' && *s <= '9') {
+		any = 1;
+		if (n > (MAXNUM - (unsigned long long)(*s - '0')) / 10ULL)
+			return(-1);
+		n = n * 10ULL + (unsigned long long)(*s - '0');
+		s++;
+	}
+	while (*s == ' ' || *s == '\t' || *s == '\n')
+		s++;
+	if (!any || *s != '\0' || n >= MAXNUM)
+		return(-1);
+	*out = n;
+	return(0);
+}
+
+static int
+read_number(unsigned long long *out)
+{
+	char buf[80];
+	int c, i;
+
+	i = 0;
+	while ((c = getchar()) != EOF) {
+		if (c != ' ' && c != '\t' && c != '\n')
+			break;
+	}
+	if (c == EOF)
+		return(0);
+	do {
+		if (i < (int)sizeof(buf) - 1)
+			buf[i++] = (char)c;
+		c = getchar();
+	} while (c != EOF && c != ' ' && c != '\t' && c != '\n');
+	buf[i] = '\0';
+	if (parse_number(buf, out) < 0)
+		return(-1);
+	return(1);
+}
+
+static void
+putnum(unsigned long long n)
+{
+	char buf[24];
+	int i;
+
+	i = 0;
+	if (n == 0)
+		buf[i++] = '0';
+	else while (n != 0) {
+		buf[i++] = (char)('0' + (int)(n % 10ULL));
+		n /= 10ULL;
+	}
+	while (i > 0)
+		putchar(buf[--i]);
+}
+
+static int
+prime(unsigned long long n)
+{
+	unsigned long long p;
+
+	if (n < 2ULL)
+		return(0);
+	if (n == 2ULL || n == 3ULL)
+		return(1);
+	if ((n % 2ULL) == 0 || (n % 3ULL) == 0)
+		return(0);
+	p = 5ULL;
+	while (p <= n / p) {
+		if ((n % p) == 0)
+			return(0);
+		p += 2ULL;
+		if (p > n / p)
+			break;
+		if ((n % p) == 0)
+			return(0);
+		p += 4ULL;
+	}
+	return(1);
+}
+
+static int
+print_prime(unsigned long long n)
+{
+	putnum(n);
+	if (putchar('\n') == EOF)
+		return(-1);
+	if (fflush(stdout) == EOF)
+		return(-1);
+	return(0);
+}
+
+static void
+ouch(void)
+{
+	fprintf(stderr, "Ouch.\n");
+}
+
+int
+main(int argc, char **argv)
+{
+	unsigned long long n;
+	int r;
+
+	if (argc > 1) {
+		if (parse_number(argv[1], &n) < 0) {
+			ouch();
+			return(1);
+		}
+		if (n == 0ULL)
+			return(0);
+	} else {
+		r = read_number(&n);
+		if (r <= 0 || n == 0ULL) {
+			if (r < 0)
+				ouch();
+			return(r < 0 ? 1 : 0);
+		}
+	}
+	if (n >= MAXNUM) {
+		ouch();
+		return(1);
+	}
+	if (n <= 2ULL) {
+		if (print_prime(2ULL) < 0)
+			return(0);
+		n = 3ULL;
+	} else if ((n % 2ULL) == 0)
+		n++;
+	for (;;) {
+		if (prime(n) && print_prime(n) < 0)
+			return(0);
+		n += 2ULL;
+	}
+}

% usr/src/cmd/prof.c
@@ -11,0 +12,4 @@
+int min(unsigned a, unsigned b);
+int max(unsigned a, unsigned b);
+int done(void);
+int timcmp(const void *vp1, const void *vp2), valcmp(const void *vp1, const void *vp2);
@@ -42 +46 @@
-double	ftime;
+double	ftim;
@@ -56,2 +60 @@
-main(argc, argv)
-char **argv;
+int main(int argc, char **argv)
@@ -60 +63 @@
-	int timcmp(), valcmp();
+	int timcmp(const void *, const void *), valcmp(const void *, const void *);
@@ -61,0 +65 @@
+#ifdef plot
@@ -64 +67,0 @@
-	struct cnt *cp;
@@ -65,0 +69,2 @@
+#endif
+	struct cnt *cp;
@@ -83 +88 @@
-				if(lowpc == -1)
+				if(lowpc == (unsigned)-1)
@@ -121,0 +127 @@
+#ifdef plot
@@ -122,0 +129 @@
+#endif
@@ -153,2 +160,2 @@
-		register j;
-		unsigned UNIT ccnt;
+		register int j;
+		unsigned short ccnt;
@@ -162,4 +169,4 @@
-		ftime = ccnt;
-		totime += ftime;
-		if(ftime > maxtime)
-			maxtime = ftime;
+		ftim = ccnt;
+		totime += ftim;
+		if(ftim > maxtime)
+			maxtime = ftim;
@@ -172 +179 @@
-			nl[j].time += overlap*ftime/scale;
+			nl[j].time += overlap*ftim/scale;
@@ -201 +208 @@
-		ftime = ccnt;
+		ftim = ccnt;
@@ -204 +211 @@
-		lastsx -= 2000.*ftime/totime;
+		lastsx -= 2000.*ftim/totime;
@@ -210 +217 @@
-				lastx = -ftime*2000./maxtime;
+				lastx = -ftim*2000./maxtime;
@@ -223 +230 @@
-		ftime = np->time/totime;
+		ftim = np->time/totime;
@@ -252 +259 @@
-		ftime = np->time/totime;
+		ftim = np->time/totime;
@@ -254 +261 @@
-		printf("%8.8s%6.1f%9.2f", np->name, 100*ftime, actime/60);
+		printf("%8.8s%6.1f%9.2f", np->name, 100*ftim, actime/60);
@@ -264,2 +271 @@
-min(a, b)
-unsigned a, b;
+int min(unsigned a, unsigned b)
@@ -272,2 +278 @@
-max(a, b)
-unsigned a, b;
+int max(unsigned a, unsigned b)
@@ -280,2 +285 @@
-valcmp(p1, p2)
-struct nl *p1, *p2;
+int valcmp(const void *vp1, const void *vp2)
@@ -282,0 +287 @@
+	const struct nl *p1 = vp1, *p2 = vp2;
@@ -286,2 +291 @@
-timcmp(p1, p2)
-struct nl *p1, *p2;
+int timcmp(const void *vp1, const void *vp2)
@@ -288,0 +293 @@
+	const struct nl *p1 = vp1, *p2 = vp2;
@@ -299 +304 @@
-done()
+int done(void)
@@ -308,0 +314 @@
+	return(0);

% usr/src/cmd/ps.c
@@ -8 +8,3 @@
-#include <core.h>
+#define TXTRNDSIZ 8192L
+#define stacktop(siz) (0x100000L)
+#define stackbas(siz) (0x100000L-siz)
@@ -10,2 +12,2 @@
-#include <sys/proc.h>
-#include <sys/tty.h>
+#include "../../sys/h/proc.h"
+struct tty;
@@ -13 +15,3 @@
-#include <sys/user.h>
+#include <sys/stat.h>
+#include "../../sys/h/user.h"
+#undef u
@@ -16,4 +20,4 @@
-	{ "_proc" },
-	{ "_swapdev" },
-	{ "_swplo" },
-	{ "" },
+	{ "_proc",    0, 0 },
+	{ "_swapdev", 0, 0 },
+	{ "_swplo",   0, 0 },
+	{ "",         0, 0 },
@@ -32,4 +36,7 @@
-long	lseek();
-char	*gettty();
-char	*getptr();
-char	*strncmp();
+long	lseek(int fd, long offset, int ptrname);
+char	*gettty(void);
+char	*getptr(char **adr);
+int	getdev(void);
+int	prcom(int puid);
+int	getbyte(char *adr);
+int	within(char *adr, long lbd, long ubd);
@@ -50,2 +57,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -154 +161,2 @@
-getdev()
+int
+getdev(void)
@@ -156 +163,0 @@
-#include <sys/stat.h>
@@ -157,0 +165 @@
+	register int i;
@@ -159,0 +168 @@
+	char dpath[DIRSIZ+1];
@@ -169 +178,4 @@
-		if(stat(dbuf.d_name, &sbuf) < 0)
+		for (i=0; i<DIRSIZ; i++)
+			dpath[i] = dbuf.d_name[i];
+		dpath[DIRSIZ] = '\0';
+		if(stat(dpath, &sbuf) < 0)
@@ -173 +185,2 @@
-		strcpy(devl[ndev].dname, dbuf.d_name);
+		for (i=0; i<DIRSIZ; i++)
+			devl[ndev].dname[i] = dbuf.d_name[i];
@@ -179,2 +192 @@
-		fprintf(stderr, "Can't open /dev/swap\n");
-		exit(1);
+		swap = -1;
@@ -181,0 +194 @@
+	return(0);
@@ -185,2 +198 @@
-round(a, b)
-	long		a, b;
+round(long a, long b)
@@ -199 +211,2 @@
-prcom(puid)
+int
+prcom(int puid)
@@ -201 +214 @@
-	char abuf[512];
+	int abuf[128];
@@ -234 +247 @@
-	datmap.f2 = ctob(USIZE)+(datmap.e1-datmap.b1)+addr;
+	datmap.f2 = ctob(USIZE)+datmap.b2+addr;
@@ -241 +254 @@
-			"0SWRIZT"[mproc.p_stat], puid);
+			"0SWRIZT"[(unsigned char)mproc.p_stat], puid);
@@ -304 +317 @@
-	if (read(file, abuf, sizeof(abuf)) != sizeof(abuf))
+	if (read(file, (char *)abuf, sizeof(abuf)) != sizeof(abuf))
@@ -306 +319 @@
-	for (ip = (int *)&abuf[512]-2; ip > (int *)abuf; ) {
+	for (ip = &abuf[128]-2; ip > abuf; ) {
@@ -312 +325 @@
-			for (cp1 = cp; cp1 < &abuf[512]; cp1++) {
+			for (cp1 = cp; cp1 < (char *)abuf + sizeof(abuf); cp1++) {
@@ -339 +352 @@
-gettty()
+gettty(void)
@@ -341 +354 @@
-	register i;
+	register int i;
@@ -358,2 +371 @@
-getptr(adr)
-char **adr;
+getptr(char **adr)
@@ -363 +375 @@
-	register i;
+	register unsigned int i;
@@ -373,2 +385,2 @@
-getbyte(adr)
-char *adr;
+int
+getbyte(char *adr)
@@ -395,3 +407,2 @@
-within(adr,lbd,ubd)
-char *adr;
-long lbd, ubd;
+int
+within(char *adr, long lbd, long ubd)
@@ -399 +410 @@
-	return((unsigned)adr>=lbd && (unsigned)adr<ubd);
+	return((unsigned long)adr>=(unsigned long)lbd && (unsigned long)adr<(unsigned long)ubd);

% usr/src/cmd/pstat.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -7,2 +8,8 @@
-#include <sys/conf.h>
-#include <sys/tty.h>
+#include "../../sys/h/tty.h"
+#include "../../sys/h/inode.h"
+#include "../../sys/h/text.h"
+#include "../../sys/h/proc.h"
+#include <sys/dir.h>
+#include "../../sys/h/user.h"
+#include "../../sys/h/file.h"
+#include <a.out.h>
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
@@ -45,2 +52,11 @@
-main(argc, argv)
-char **argv;
+int doinode(void);
+int dotext(void);
+int doproc(void);
+int dotty(void);
+int dousr(void);
+int dofil(void);
+int putf(int v, int n);
+int ttyprt(int n, struct tty *atp);
+int oatoi(char *s);
+int
+main(int argc, char **argv)
@@ -92 +108 @@
-	nlist(fnlist, setup);
+	nlist(fnlist, (struct nlist *)setup);
@@ -108,0 +125 @@
+	return(0);
@@ -111 +128,2 @@
-doinode()
+int
+doinode(void)
@@ -113 +130,0 @@
-#include <sys/inode.h>
@@ -148,0 +166 @@
+	return(0);
@@ -151 +169,2 @@
-putf(v, n)
+int
+putf(int v, int n)
@@ -156,0 +176 @@
+	return(0);
@@ -159 +179,2 @@
-dotext()
+int
+dotext(void)
@@ -161 +181,0 @@
-#include <sys/text.h>
@@ -164 +184 @@
-	register loc;
+	register int loc;
@@ -193,0 +214 @@
+	return(0);
@@ -196 +217,2 @@
-doproc()
+int
+doproc(void)
@@ -198 +219,0 @@
-#include <sys/proc.h>
@@ -201 +222 @@
-	register loc, np;
+	register int loc, np;
@@ -233,0 +255 @@
+	return(0);
@@ -236 +258,2 @@
-dotty()
+int
+dotty(void)
@@ -250 +273 @@
-		return;
+		return(0);
@@ -257,0 +281 @@
+	return(0);
@@ -260,2 +284,2 @@
-ttyprt(n, atp)
-struct tty *atp;
+int
+ttyprt(int n, struct tty *atp)
@@ -283,0 +308 @@
+	return(0);
@@ -286 +311,2 @@
-dousr()
+int
+dousr(void)
@@ -288,2 +313,0 @@
-#include <sys/dir.h>
-#include <sys/user.h>
@@ -295 +319 @@
-	register i;
+	register int i;
@@ -352,0 +377 @@
+	return(0);
@@ -355,2 +380,2 @@
-oatoi(s)
-char *s;
+int
+oatoi(char *s)
@@ -358 +383 @@
-	register v;
+	register int v;
@@ -366 +391,2 @@
-dofil()
+int
+dofil(void)
@@ -368 +393,0 @@
-#include <sys/file.h>
@@ -371 +396 @@
-	register nf;
+	register int nf;
@@ -392,0 +418 @@
+	return(0);

% usr/src/cmd/ptx.c
@@ -34,2 +34,3 @@
-extern char *calloc(), *mktemp();
-extern char *getline();
+extern char *calloc(unsigned num, unsigned size);
+extern char *mktemp(char *as);
+extern char *getline(void);
@@ -36,0 +38,6 @@
+int diag(char *s, char *arg), msg(char *s, char *arg);
+int storeh(int num, char *strtp), hash(char *strtp, char *endp);
+int cmpline(char *pend), getsort(void);
+int cmpword(char *cpp, char *pend, char *hpp);
+int putline(char *strt, char *end), putout(char *strt, char *end);
+int onintr(int sig);
@@ -69,3 +76,2 @@
-main(argc,argv)
-int argc;
-char **argv;
+int
+main(int argc, char **argv)
@@ -77 +83 @@
-	extern onintr();
+	extern int onintr(int sig);
@@ -82,6 +88,6 @@
-	if(signal(SIGHUP,onintr)==SIG_IGN)
-		signal(SIGHUP,SIG_IGN);
-	if(signal(SIGINT,onintr)==SIG_IGN)
-		signal(SIGINT,SIG_IGN);
-	signal(SIGPIPE,onintr);
-	signal(SIGTERM,onintr);
+	if(signal(SIGHUP,(int)onintr)==(int)SIG_IGN)
+		signal(SIGHUP,(int)SIG_IGN);
+	if(signal(SIGINT,(int)onintr)==(int)SIG_IGN)
+		signal(SIGINT,(int)SIG_IGN);
+	signal(SIGPIPE,(int)onintr);
+	signal(SIGTERM,(int)onintr);
@@ -116,0 +123 @@
+			/* fallthrough */
@@ -228 +235 @@
-	while(pend=getline())
+	while((pend=getline()))
@@ -236,0 +244 @@
+		/* fallthrough */
@@ -247 +255 @@
-	onintr();
+	onintr(0);
@@ -250,3 +258,2 @@
-msg(s,arg)
-char *s;
-char *arg;
+int
+msg(char *s, char *arg)
@@ -255 +262 @@
-	return;
+	return(0);
@@ -257,2 +264,2 @@
-diag(s,arg)
-char *s, *arg;
+int
+diag(char *s, char *arg)
@@ -262,0 +270 @@
+	return(0);
@@ -266 +274 @@
-char *getline()
+char *getline(void)
@@ -269 +277 @@
-	register c;
+	register int c;
@@ -291 +299 @@
-				while(isspace(*--linep));
+				while(isspace((unsigned char)*--linep));
@@ -302,2 +310,2 @@
-cmpline(pend)
-char *pend;
+int
+cmpline(char *pend)
@@ -312 +320 @@
-		while(pchar<pend&&!isspace(*pchar))
+		while(pchar<pend&&!isspace((unsigned char)*pchar))
@@ -316 +324 @@
-		if(isabreak(*pchar++))
+		if(isabreak((unsigned char)*pchar++))
@@ -322 +330 @@
-			if(isabreak(*pchar)) {
+			if(isabreak((unsigned char)*pchar)) {
@@ -325 +333 @@
-				while(cp = *hp++){
+				while((cp = *hp++)){
@@ -346,0 +355 @@
+	return(0);
@@ -349,2 +358,2 @@
-cmpword(cpp,pend,hpp)
-char *cpp, *pend, *hpp;
+int
+cmpword(char *cpp, char *pend, char *hpp)
@@ -356 +365 @@
-		if((isupper(c)?tolower(c):c) != *hpp++)
+		if((isupper((unsigned char)c)?tolower(c):c) != *hpp++)
@@ -363,2 +372,2 @@
-putline(strt, end)
-char *strt, *end;
+int
+putline(char *strt, char *end)
@@ -376,0 +386 @@
+	return(0);
@@ -379 +389,2 @@
-getsort()
+int
+getsort(void)
@@ -381 +392 @@
-	register c;
+	register int c;
@@ -385 +396 @@
-	char *rtrim(), *ltrim();
+	char *rtrim(char *a, char *c, int d), *ltrim(char *c, char *b, int d);
@@ -400 +411 @@
-			while(isspace(linep[-1]))
+			while(isspace((unsigned char)linep[-1]))
@@ -404 +415 @@
-				while(ref<linep&&!isspace(*ref))
+				while(ref<linep&&!isspace((unsigned char)*ref))
@@ -416 +427 @@
-			p1b = rtrim(p1a=p3b+(isspace(p3b[0])!=0),tilde,
+			p1b = rtrim(p1a=p3b+(isspace((unsigned char)p3b[0])!=0),tilde,
@@ -420 +431 @@
-			p4a = ltrim(ref,p4b=p2a-(isspace(p2a[-1])!=0),
+			p4a = ltrim(ref,p4b=p2a-(isspace((unsigned char)p2a[-1])!=0),
@@ -452,0 +464 @@
+			/* fallthrough */
@@ -456,0 +469 @@
+	return(0);
@@ -459,2 +472 @@
-char *rtrim(a,c,d)
-char *a,*c;
+char *rtrim(char *a, char *c, int d)
@@ -465 +477 @@
-		if((x==c||isspace(x[0]))&&!isspace(x[-1]))
+		if((x==c||isspace((unsigned char)x[0]))&&!isspace((unsigned char)x[-1]))
@@ -467 +479 @@
-	if(b<c&&!isspace(b[0]))
+	if(b<c&&!isspace((unsigned char)b[0]))
@@ -472,2 +484 @@
-char *ltrim(c,b,d)
-char *c,*b;
+char *ltrim(char *c, char *b, int d)
@@ -478 +489 @@
-		if(!isspace(x[0])&&(x==c||isspace(x[-1])))
+		if(!isspace((unsigned char)x[0])&&(x==c||isspace((unsigned char)x[-1])))
@@ -480 +491 @@
-	if(a>c&&!isspace(a[-1]))
+	if(a>c&&!isspace((unsigned char)a[-1]))
@@ -485,2 +496,2 @@
-putout(strt,end)
-char *strt, *end;
+int
+putout(char *strt, char *end)
@@ -494,0 +506 @@
+	return(0);
@@ -497 +509,2 @@
-onintr()
+int
+onintr(int sig)
@@ -499,0 +513 @@
+	(void)sig;
@@ -502,0 +517 @@
+	return(0);
@@ -505,2 +520,2 @@
-hash(strtp,endp)
-char *strtp, *endp;
+int
+hash(char *strtp, char *endp)
@@ -517 +532 @@
-	i = (isupper(c)?tolower(c):c);
+	i = (isupper((unsigned char)c)?tolower(c):c);
@@ -519 +534 @@
-	j = (isupper(c)?tolower(c):c);
+	j = (isupper((unsigned char)c)?tolower(c):c);
@@ -523 +538 @@
-	k = (isupper(c)?tolower(c):c);
+	k = (isupper((unsigned char)c)?tolower(c):c);
@@ -525 +540 @@
-	j = (isupper(c)?tolower(c):c);
+	j = (isupper((unsigned char)c)?tolower(c):c);
@@ -532,3 +547,2 @@
-storeh(num,strtp)
-int num;
-char *strtp;
+int
+storeh(int num, char *strtp)

% usr/src/cmd/pwd.c
@@ -17 +17,4 @@
-main()
+void prname(void);
+void cat(void);
+int
+main(void)
@@ -38 +41 @@
-				if (read(file, (char *)&dir, sizeof(dir)) < sizeof(dir)) {
+				if (read(file, (char *)&dir, sizeof(dir)) < (int)sizeof(dir)) {
@@ -45 +48 @@
-				if(read(file, (char *)&dir, sizeof(dir)) < sizeof(dir)) {
+				if(read(file, (char *)&dir, sizeof(dir)) < (int)sizeof(dir)) {
@@ -56 +59,2 @@
-prname()
+void
+prname(void)
@@ -66 +70,2 @@
-cat()
+void
+cat(void)
@@ -68 +73 @@
-	register i, j;
+	register int i, j;

% usr/src/cmd/quot.c
@@ -42,3 +42,6 @@
-struct	passwd	*getpwent();
-char	*malloc();
-char	*copy();
+char	*malloc(unsigned n);
+char	*copy(char *s);
+int	scanf(char *fmt, ...);
+int	check(char *file), acct(register struct dinode *ip);
+int	bread(unsigned bno, char *buf, int cnt);
+int	qcmp(const void *vp1, const void *vp2), report(void);
@@ -46,2 +49,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -87,2 +90,2 @@
-check(file)
-char *file;
+int
+check(char *file)
@@ -91 +94 @@
-	register c;
+	register int c;
@@ -96 +99 @@
-		return;
+		return(0);
@@ -115,0 +119 @@
+	return(0);
@@ -118,2 +122,2 @@
-acct(ip)
-register struct dinode *ip;
+int
+acct(register struct dinode *ip)
@@ -121 +125 @@
-	register n;
+	register int n;
@@ -123 +127 @@
-	static fino;
+	static int fino;
@@ -126 +130 @@
-		return;
+		return(0);
@@ -129 +133 @@
-			return;
+			return(0);
@@ -136 +140 @@
-		return;
+		return(0);
@@ -139 +143 @@
-		return;
+		return(0);
@@ -146,4 +150,4 @@
-				return;
-		if (fino > ino)
-			return;
-		if (fino<ino) {
+				return(0);
+		if (fino > (int)ino)
+			return(0);
+		if (fino<(int)ino) {
@@ -155 +159 @@
-		if (np = du[ip->di_uid].name)
+		if ((np = du[ip->di_uid].name))
@@ -167,0 +172 @@
+	return(0);
@@ -170,3 +175,2 @@
-bread(bno, buf, cnt)
-unsigned bno;
-char *buf;
+int
+bread(unsigned bno, char *buf, int cnt)
@@ -179,0 +184 @@
+	return(0);
@@ -182,2 +187,2 @@
-qcmp(p1, p2)
-register struct du *p1, *p2;
+int
+qcmp(const void *vp1, const void *vp2)
@@ -184,0 +190 @@
+	register const struct du *p1 = vp1, *p2 = vp2;
@@ -192 +198,2 @@
-report()
+int
+report(void)
@@ -194 +201 @@
-	register i;
+	register int i;
@@ -197 +204 @@
-		return;
+		return(0);
@@ -206 +213 @@
-		return;
+		return(0);
@@ -211 +218 @@
-			return;
+			return(0);
@@ -219,0 +227 @@
+	return(0);
@@ -223,2 +231 @@
-copy(s)
-char *s;
+copy(char *s)
@@ -227 +234 @@
-	register n;
+	register int n;
@@ -232 +239 @@
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
@@ -84,2 +84,44 @@
-main(argc, argv)
-char *argv[];
+struct spcl;
+struct dinode;
+int	doit(int command, int argc, char *argv[]);
+int	readhdr(struct spcl *b);
+int	checkvol(struct spcl *b, int t);
+int	pass1(void);
+int	readbits(short *m);
+int	gethead(struct spcl *buf);
+int	checktype(struct spcl *b, int t);
+int	ishead(struct spcl *buf);
+int	readtape(char *b);
+int	flsht(void);
+int	getfile(ino_t n, int (*f1)(), int (*f2)(), long size);
+int	psearch(char *n);
+int	getdino(ino_t inum, struct dinode *b);
+int	putdino(ino_t inum, struct dinode *b);
+int	itrunc(struct dinode *ip);
+int	clri(struct dinode *ip);
+int	dread(daddr_t bno, char *buf, int cnt);
+int	dwrite(daddr_t bno, char *b);
+int	rstrfile(char *b, long s);
+int	rstrskip(char *b, long s);
+int	xtrfile(char *b, long size);
+int	skip(void);
+int	checksum(int *b);
+int	putent(char *cp);
+int	putdir(char *b);
+int	null(void);
+int	copy(char *f, char *t, int s);
+int	clearbuf(char *cp);
+int	writec(int c);
+int	readc(void);
+int	mseek(daddr_t pt);
+int	getent(char *bf);
+int	direq(char *s1, char *s2);
+int	flsh(void);
+int	bfree(daddr_t bn);
+int	tloop(daddr_t bn, int f1, int f2);
+int	l3tol(), ltol3();
+daddr_t	balloc(void);
+daddr_t	bmap(daddr_t iaddr[NADDR], daddr_t bn);
+ino_t	search(ino_t inum, char *cp);
+int
+main(int argc, char *argv[])
@@ -88,2 +130,2 @@
-	char command;
-	int done();
+	char command = 0;
+	int done(void);
@@ -120,4 +162,4 @@
-		if (signal(SIGINT, done) == SIG_IGN)
-			signal(SIGINT, SIG_IGN);
-		if (signal(SIGTERM, done) == SIG_IGN)
-			signal(SIGTERM, SIG_IGN);
+		if (signal(SIGINT, (int)done) == (int)SIG_IGN)
+			signal(SIGINT, (int)SIG_IGN);
+		if (signal(SIGTERM, (int)done) == (int)SIG_IGN)
+			signal(SIGTERM, (int)SIG_IGN);
@@ -143,4 +185,2 @@
-doit(command, argc, argv)
-char	command;
-int	argc;
-char	*argv[];
+int
+doit(int command, int argc, char *argv[])
@@ -148,2 +188,2 @@
-	extern char *ctime();
-	register i, k;
+	extern char *ctime(long *t);
+	register int i, k;
@@ -152 +192 @@
-	int	xtrfile(), skip();
+	int	xtrfile(char *b, long size), skip(void);
@@ -154 +194 @@
-	int	rstrfile(), rstrskip();
+	int	rstrfile(char *b, long s), rstrskip(char *b, long s);
@@ -179 +219 @@
-		return;
+		return(0);
@@ -208 +248 @@
-			return;
+			return(0);
@@ -251 +291 @@
-					return;
+				return(0);
@@ -300 +340 @@
-			if (gets(tbf) == EOF) {
+			if (gets(tbf) == NULL) {
@@ -340 +380 @@
-				return;
+				return(0);
@@ -397,0 +438 @@
+	return(0);
@@ -405 +446,2 @@
-pass1()
+int
+pass1(void)
@@ -407 +449 @@
-	register i;
+	register int i;
@@ -409 +451 @@
-	int	putdir(), null();
+	int	putdir(char *b), null();
@@ -427 +469 @@
-			return;
+			return(0);
@@ -446,4 +488,2 @@
-getfile(n, f1, f2, size)
-ino_t	n;
-int	(*f2)(), (*f1)();
-long	size;
+int
+getfile(ino_t n, int (*f1)(), int (*f2)(), long size)
@@ -451 +491 @@
-	register i;
+	register int i;
@@ -466 +506 @@
-			return;
+			return(0);
@@ -485 +525 @@
-				return;
+				return(0);
@@ -495,2 +535,2 @@
-readtape(b)
-char *b;
+int
+readtape(char *b)
@@ -498 +538 @@
-	register i;
+	register int i;
@@ -533 +573 @@
-			return;
+			return(0);
@@ -536,0 +577 @@
+	return(0);
@@ -539 +580,2 @@
-flsht()
+int
+flsht(void)
@@ -541,0 +584 @@
+	return(0);
@@ -544,2 +587,2 @@
-copy(f, t, s)
-register char *f, *t;
+int
+copy(register char *f, register char *t, int s)
@@ -547 +590 @@
-	register i;
+	register int i;
@@ -552,0 +596 @@
+	return(0);
@@ -555,2 +599,2 @@
-clearbuf(cp)
-register char *cp;
+int
+clearbuf(register char *cp)
@@ -558 +602 @@
-	register i;
+	register int i;
@@ -563,0 +608 @@
+	return(0);
@@ -571,2 +616,2 @@
-putent(cp)
-char	*cp;
+int
+putent(char *cp)
@@ -574 +619 @@
-	register i;
+	register int i;
@@ -576 +621 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -581 +626 @@
-			return;
+			return(0);
@@ -583 +628 @@
-	return;
+	return(0);
@@ -586,2 +631,2 @@
-getent(bf)
-register char *bf;
+int
+getent(register char *bf)
@@ -589 +634 @@
-	register i;
+	register int i;
@@ -591 +636 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -595,2 +640,2 @@
-			return;
-	return;
+			return(0);
+	return(0);
@@ -602,2 +647,2 @@
-writec(c)
-char c;
+int
+writec(int c)
@@ -610,0 +656 @@
+	return(0);
@@ -613 +659,2 @@
-readc()
+int
+readc(void)
@@ -622,2 +669,2 @@
-mseek(pt)
-daddr_t pt;
+int
+mseek(daddr_t pt)
@@ -626,0 +674 @@
+	return(0);
@@ -629 +677,2 @@
-flsh()
+int
+flsh(void)
@@ -631,0 +681 @@
+	return(0);
@@ -639,3 +689 @@
-search(inum, cp)
-ino_t	inum;
-char	*cp;
+search(ino_t inum, char *cp)
@@ -643 +691 @@
-	register i;
+	register int i;
@@ -665,2 +713,2 @@
-psearch(n)
-char	*n;
+int
+psearch(char *n)
@@ -693,2 +741,2 @@
-direq(s1, s2)
-register char *s1, *s2;
+int
+direq(register char *s1, register char *s2)
@@ -696 +744 @@
-	register i;
+	register int i;
@@ -712,3 +760,2 @@
-dwrite(bno, b)
-daddr_t	bno;
-char	*b;
+int
+dwrite(daddr_t bno, char *b)
@@ -716 +763 @@
-	register i;
+	register int i;
@@ -735,0 +783 @@
+	return(0);
@@ -738,3 +786,2 @@
-dread(bno, buf, cnt)
-daddr_t bno;
-char *buf;
+int
+dread(daddr_t bno, char *buf, int cnt)
@@ -742 +789 @@
-	register i, j;
+	register int i, j;
@@ -751 +798 @@
-			return;
+			return(0);
@@ -771,0 +819 @@
+	return(0);
@@ -779,2 +827,2 @@
-clri(ip)
-struct dinode *ip;
+int
+clri(struct dinode *ip)
@@ -787,0 +836 @@
+	return(0);
@@ -793,2 +842,2 @@
-itrunc(ip)
-register struct dinode *ip;
+int
+itrunc(register struct dinode *ip)
@@ -796 +845 @@
-	register i;
+	register int i;
@@ -800 +849 @@
-		return;
+		return(0);
@@ -803 +852 @@
-		return;
+		return(0);
@@ -826,0 +876 @@
+	return(0);
@@ -829,3 +879,2 @@
-tloop(bn, f1, f2)
-daddr_t	bn;
-int	f1, f2;
+int
+tloop(daddr_t bn, int f1, int f2)
@@ -833 +882 @@
-	register i;
+	register int i;
@@ -850,0 +900 @@
+	return(0);
@@ -853,2 +903,2 @@
-bfree(bn)
-daddr_t	bn;
+int
+bfree(daddr_t bn)
@@ -856 +906 @@
-	register i;
+	register int i;
@@ -863 +913 @@
-		fbuf.df_nfree = sblock.s_nfree;
+		fbuf.frees.df_nfree = sblock.s_nfree;
@@ -865 +915 @@
-			fbuf.df_free[i] = sblock.s_free[i];
+			fbuf.frees.df_free[i] = sblock.s_free[i];
@@ -869,0 +920 @@
+	return(0);
@@ -876 +927 @@
-balloc()
+balloc(void)
@@ -879 +930 @@
-	register i;
+	register int i;
@@ -896 +947 @@
-		sblock.s_nfree = fbuf.df_nfree;
+		sblock.s_nfree = fbuf.frees.df_nfree;
@@ -898 +949 @@
-			sblock.s_free[i] = fbuf.df_free[i];
+			sblock.s_free[i] = fbuf.frees.df_free[i];
@@ -910,3 +961 @@
-bmap(iaddr, bn)
-daddr_t	iaddr[NADDR];
-daddr_t	bn;
+bmap(daddr_t iaddr[NADDR], daddr_t bn)
@@ -914 +963 @@
-	register i;
+	register int i;
@@ -976,2 +1025,2 @@
-gethead(buf)
-struct spcl *buf;
+int
+gethead(struct spcl *buf)
@@ -988,2 +1037,2 @@
-ishead(buf)
-struct spcl *buf;
+int
+ishead(struct spcl *buf)
@@ -996,3 +1045,2 @@
-checktype(b, t)
-struct	spcl *b;
-int	t;
+int
+checktype(struct spcl *b, int t)
@@ -1004,2 +1052,2 @@
-checksum(b)
-int *b;
+int
+checksum(int *b)
@@ -1007 +1055 @@
-	register i, j;
+	register int i, j;
@@ -1021,3 +1069,2 @@
-checkvol(b, t)
-struct spcl *b;
-int t;
+int
+checkvol(struct spcl *b, int t)
@@ -1030,2 +1077,2 @@
-readhdr(b)
-struct	spcl *b;
+int
+readhdr(struct spcl *b)
@@ -1045,3 +1092,2 @@
-xtrfile(b, size)
-char	*b;
-long	size;
+int
+xtrfile(char *b, long size)
@@ -1049,0 +1096 @@
+	return(0);
@@ -1052 +1099 @@
-null() {;}
+int null(void) {return(0);}
@@ -1054 +1101,2 @@
-skip()
+int
+skip(void)
@@ -1056,0 +1105 @@
+	return(0);
@@ -1061,3 +1110,2 @@
-rstrfile(b, s)
-char *b;
-long s;
+int
+rstrfile(char *b, long s)
@@ -1066,0 +1115 @@
+	(void)s;
@@ -1069,0 +1119 @@
+	return(0);
@@ -1072,3 +1122,2 @@
-rstrskip(b, s)
-char *b;
-long s;
+int
+rstrskip(char *b, long s)
@@ -1075,0 +1125 @@
+	(void)b; (void)s;
@@ -1076,0 +1127 @@
+	return(0);
@@ -1080,2 +1131,2 @@
-putdir(b)
-char *b;
+int
+putdir(char *b)
@@ -1084 +1135 @@
-	register i;
+	register int i;
@@ -1090,0 +1142 @@
+	return(0);
@@ -1097,3 +1149,2 @@
-getdino(inum, b)
-ino_t	inum;
-struct	dinode *b;
+int
+getdino(ino_t inum, struct dinode *b)
@@ -1107,0 +1159 @@
+	return(0);
@@ -1110,3 +1162,2 @@
-putdino(inum, b)
-ino_t	inum;
-struct	dinode *b;
+int
+putdino(ino_t inum, struct dinode *b)
@@ -1120,0 +1172 @@
+	return(0);
@@ -1126,2 +1178,2 @@
-readbits(m)
-short	*m;
+int
+readbits(short *m)
@@ -1129 +1181 @@
-	register i;
+	register int i;
@@ -1138,0 +1191 @@
+	return(0);
@@ -1141 +1194,2 @@
-done()
+int
+done(void)
@@ -1146,0 +1201 @@
+	return(0);

% usr/src/cmd/rev.c
@@ -9,2 +9,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char *argv[])
@@ -12 +12 @@
-	register i,c;
+	register int i,c;

% usr/src/cmd/rm.c
@@ -8 +8,5 @@
-char	*sprintf();
+char	*sprintf(char *buf, char *fmt, ...);
+void	rm(char *arg, int fflg, int rflg, int iflg, int level);
+int	dotname(char *s);
+int	rmdir(char *f, int iflg);
+int	yes(void);
@@ -10,2 +14,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -51,2 +55,2 @@
-rm(arg, fflg, rflg, iflg, level)
-char arg[];
+void
+rm(char arg[], int fflg, int rflg, int iflg, int level)
@@ -116,2 +120,2 @@
-dotname(s)
-char *s;
+int
+dotname(char *s)
@@ -119,2 +123,2 @@
-	if(s[0] == '.')
-		if(s[1] == '.')
+	if(s[0] == '.') {
+		if(s[1] == '.') {
@@ -125 +129 @@
-		else if(s[1] == '\0')
+		} else if(s[1] == '\0')
@@ -126,0 +131 @@
+	}
@@ -130,2 +135,2 @@
-rmdir(f, iflg)
-char *f;
+int
+rmdir(char *f, int iflg)
@@ -151,0 +157 @@
+	return(1);
@@ -154 +160,2 @@
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
@@ -4,0 +5 @@
+#include <pwd.h>
@@ -27 +28 @@
-struct	user {
+struct	user_acct {
@@ -31 +32 @@
-} user[256];
+} usr[256];
@@ -47 +47,0 @@
-time_t	expand();
@@ -49,2 +49,14 @@
-main(argc, argv)
-char **argv;
+time_t expand(unsigned t);
+int tcmp(struct tab *p1, struct tab *p2);
+int ncmp(struct tab *p1, struct tab *p2);
+int bcmp(struct tab *p1, struct tab *p2);
+float sum(struct tab *p);
+void doacct(char *f);
+int enter(char *np);
+void init(void);
+void strip(void);
+void printmoney(void);
+void column(double n, double a, double b, double c);
+void col(double n, double a, double m);
+int
+main(int argc, char **argv)
@@ -54,2 +65,0 @@
-	extern tcmp(), ncmp(), bcmp();
-	extern float sum();
@@ -143 +153 @@
-		return;
+		return 0;
@@ -156 +166 @@
-		for(j=0; j<NC; j++)
+		for(j=0; j<(int)NC; j++)
@@ -172 +182 @@
-		for(j=0; j<NC; j++)
+		for(j=0; j<(int)NC; j++)
@@ -183 +193 @@
-			fwrite((char *)user, sizeof(user), 1, ff);
+			fwrite((char *)usr, sizeof(usr), 1, ff);
@@ -202 +212 @@
-	qsort(tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
+	qsort((char *)tab, k, sizeof(tab[0]), nflg? ncmp: (bflg?bcmp:tcmp));
@@ -210,0 +221 @@
+	return 0;
@@ -213 +224,2 @@
-printmoney()
+void
+printmoney(void)
@@ -215,3 +227,2 @@
-	register i;
-	char buf[128];
-	register char *cp;
+	int i;
+	struct passwd *pw;
@@ -220,2 +231,3 @@
-		if (user[i].ncomm) {
-			if (getpw(i, buf)!=0)
+		if (usr[i].ncomm) {
+			pw = getpwuid(i);
+			if (pw == NULL)
@@ -223,7 +235,2 @@
-			else {
-				cp = buf;
-				while (*cp!=':' &&*cp!='\n' && *cp)
-					cp++;
-				*cp = 0;
-				printf("%-8s", buf);
-			}
+			else
+				printf("%-8s", pw->pw_name);
@@ -231 +238 @@
-			    user[i].ncomm, user[i].fctime/60);
+			    usr[i].ncomm, usr[i].fctime/60);
@@ -236,2 +243,2 @@
-column(n, a, b, c)
-double n, a, b, c;
+void
+column(double n, double a, double b, double c)
@@ -258,2 +265,2 @@
-col(n, a, m)
-double n, a, m;
+void
+col(double n, double a, double m)
@@ -272,2 +279,2 @@
-doacct(f)
-char *f;
+void
+doacct(char *f)
@@ -279,2 +286,2 @@
-	register char *cp;
-	register int c;
+	char *cp;
+	int c;
@@ -316,2 +323,2 @@
-		user[c].ncomm++;
-		user[c].fctime += x/60.;
+		usr[c].ncomm++;
+		usr[c].fctime += x/60.;
@@ -334,2 +341,2 @@
-ncmp(p1, p2)
-struct tab *p1, *p2;
+int
+ncmp(struct tab *p1, struct tab *p2)
@@ -345,2 +352,2 @@
-bcmp(p1, p2)
-struct tab *p1, *p2;
+int
+bcmp(struct tab *p1, struct tab *p2)
@@ -349 +355,0 @@
-	float sum();
@@ -365,2 +371,2 @@
-tcmp(p1, p2)
-struct tab *p1, *p2;
+int
+tcmp(struct tab *p1, struct tab *p2)
@@ -368 +373,0 @@
-	extern float sum();
@@ -386,2 +391,2 @@
-float sum(p)
-struct tab *p;
+float
+sum(struct tab *p)
@@ -397 +402,2 @@
-init()
+void
+init(void)
@@ -420 +426 @@
-	fread((char *)user, sizeof(user), 1, f);
+	fread((char *)usr, sizeof(usr), 1, f);
@@ -424,2 +430,2 @@
-enter(np)
-char *np;
+int
+enter(char *np)
@@ -429 +435 @@
-	for (i=j=0; i<NC; i++) {
+	for (i=j=0; i<(int)NC; i++) {
@@ -435 +441 @@
-	for (i=j=0; j<NC; j++) {
+	for (i=0, j=0; j<(int)NC; j++) {
@@ -441 +447 @@
-		for (j=0; j<NC; j++)
+		for (j=0; j<(int)NC; j++)
@@ -447 +453 @@
-	for (j=0; j<NC; j++)
+	for (j=0; j<(int)NC; j++)
@@ -453 +459,2 @@
-strip()
+void
+strip(void)
@@ -475,2 +482 @@
-expand(t)
-unsigned t;
+expand(unsigned t)
@@ -478 +484 @@
-	register time_t nt;
+	time_t nt;

% usr/src/cmd/sed/sed.h
@@ -35,2 +35,2 @@
-union reptr	*abuf[ABUFSIZE];
-union reptr **aptr;
+struct reptr	*abuf[ABUFSIZE];
+struct reptr **aptr;
@@ -50 +50 @@
-union reptr	*ptrend;
+struct reptr	*ptrend;
@@ -104,4 +104,4 @@
-union	reptr {
-	struct reptr1 {
-		char	*ad1;
-		char	*ad2;
+struct reptr {
+	char	*ad1;
+	char	*ad2;
+	union {
@@ -109,20 +109,9 @@
-		char	*rhs;
-		FILE	*fcode;
-		char	command;
-		char	gfl;
-		char	pfl;
-		char	inar;
-		char	negfl;
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
+		struct reptr	*lb1;
+	} u;
+	char	*rhs;
+	FILE	*fcode;
+	char	command;
+	char	gfl;
+	char	pfl;
+	char	inar;
+	char	negfl;
@@ -136,2 +125,2 @@
-	union reptr	*chain;
-	union reptr	*address;
+	struct reptr	*chain;
+	struct reptr	*address;
@@ -151 +140 @@
-union reptr	**cmpend[DEPTH];
+struct reptr	**cmpend[DEPTH];
@@ -153 +142 @@
-union reptr	*pending;
+struct reptr	*pending;

% usr/src/cmd/sed/sed0.c
@@ -3,0 +4,5 @@
+void	fcomp(void);
+void	dechain(void);
+void	execute(char *file);
+int	rline(char *lbuf);
+int	cmp(char *a, char *b);
@@ -21,2 +26,2 @@
-main(argc, argv)
-char	*argv[];
+int
+main(int argc, char *argv[])
@@ -105 +110 @@
-/*	abort();	/*DEBUG*/
+/*	abort();	DEBUG */
@@ -109 +114 @@
-	else while(--eargc >= 0) {
+	else while(--eargc >= 0)
@@ -111 +115,0 @@
-	}
@@ -115 +119,2 @@
-fcomp()
+void
+fcomp(void)
@@ -119,2 +124,2 @@
-	char	*address();
-	union reptr	*pt, *pt1;
+	char	*address(char *expbuf);
+	struct reptr	*pt, *pt1;
@@ -143 +148 @@
-/*	fprintf(stdout, "cp: %s\n", cp);	/*DEBUG*/
+/*	fprintf(stdout, "cp: %s\n", cp);	DEBUG */
@@ -210 +215 @@
-				cmpend[depth++] = &rep->lb1;
+				cmpend[depth++] = &rep->u.lb1;
@@ -261 +266 @@
-				if(lpt = search(lab)) {
+				if((lpt = search(lab))) {
@@ -290,2 +295,2 @@
-				rep->re1 = p;
-				p = text(rep->re1);
+				rep->u.re1 = p;
+				p = text(rep->u.re1);
@@ -300,2 +305,2 @@
-				rep->re1 = p;
-				p = text(rep->re1);
+				rep->u.re1 = p;
+				p = text(rep->u.re1);
@@ -314,2 +319,2 @@
-				rep->re1 = p;
-				p = text(rep->re1);
+				rep->u.re1 = p;
+				p = text(rep->u.re1);
@@ -345,2 +350,2 @@
-					if(pt = labtab->chain) {
-						while(pt1 = pt->lb1)
+					if((pt = labtab->chain)) {
+						while((pt1 = pt->u.lb1))
@@ -348 +353 @@
-						pt->lb1 = rep;
+						pt->u.lb1 = rep;
@@ -362 +367 @@
-				if(lpt = search(lab)) {
+				if((lpt = search(lab))) {
@@ -364 +369 @@
-						rep->lb1 = lpt->address;
+						rep->u.lb1 = lpt->address;
@@ -367 +372 @@
-						while(pt1 = pt->lb1)
+						while((pt1 = pt->u.lb1))
@@ -369 +374 @@
-						pt->lb1 = rep;
+						pt->u.lb1 = rep;
@@ -407,2 +412,2 @@
-				rep->re1 = p;
-				p = text(rep->re1);
+				rep->u.re1 = p;
+				p = text(rep->u.re1);
@@ -417 +422 @@
-				rep->lb1 = ptrspace;
+				rep->u.lb1 = ptrspace;
@@ -435,2 +440,2 @@
-				rep->re1 = p;
-				p = compile(rep->re1);
+				rep->u.re1 = p;
+				p = compile(rep->u.re1);
@@ -441,2 +446,2 @@
-				if(p == rep->re1) {
-					rep->re1 = op;
+				if(p == rep->u.re1) {
+					rep->u.re1 = op;
@@ -444 +449 @@
-					op = rep->re1;
+					op = rep->u.re1;
@@ -529,2 +534,2 @@
-				rep->re1 = p;
-				p = ycomp(rep->re1);
+				rep->u.re1 = p;
+				p = ycomp(rep->u.re1);
@@ -588,2 +593,2 @@
-char *compile(expbuf)
-char	*expbuf;
+char *
+compile(char *expbuf)
@@ -591 +596 @@
-	register c;
+	register int c;
@@ -719 +724 @@
-					for (c = sp[-2]; c<*sp; c++)
+					for (c = sp[-2]&0177; c<(*sp&0177); c++)
@@ -730 +735 @@
-				ep[c >> 3] |= bittab[c & 07];
+				ep[(c&0177) >> 3] |= bittab[c & 07];
@@ -749,2 +754,2 @@
-rline(lbuf)
-char	*lbuf;
+int
+rline(char *lbuf)
@@ -753 +758 @@
-	register	t;
+	register int	t;
@@ -764 +769 @@
-			while(*++p = *q++) {
+			while((*++p = *q++)) {
@@ -783 +788 @@
-		while(*++p = *q++) {
+		while((*++p = *q++)) {
@@ -816,2 +821,2 @@
-char	*address(expbuf)
-char	*expbuf;
+char	*
+address(char *expbuf)
@@ -855,2 +860,2 @@
-cmp(a, b)
-char	*a,*b;
+int
+cmp(char *a, char *b)
@@ -863 +868 @@
-	while(*++ra == *++rb)
+	while ((*++ra == *++rb))
@@ -908 +913,2 @@
-dechain()
+void
+dechain(void)
@@ -911 +917 @@
-	union reptr	*rptr, *trptr;
+	struct reptr	*rptr, *trptr;
@@ -922,2 +928,2 @@
-			while(trptr = rptr->lb1) {
-				rptr->lb1 = lptr->address;
+			while((trptr = rptr->u.lb1)) {
+				rptr->u.lb1 = lptr->address;
@@ -926 +932 @@
-			rptr->lb1 = lptr->address;
+			rptr->u.lb1 = lptr->address;
@@ -931,2 +937,2 @@
-char *ycomp(expbuf)
-char	*expbuf;
+char *
+ycomp(char *expbuf)
@@ -952,2 +958,2 @@
-		if((ep[c] = *tsp++) == '\\' && *tsp == 'n') {
-			ep[c] = '\n';
+		if((ep[(unsigned char)c] = *tsp++) == '\\' && *tsp == 'n') {
+			ep[(unsigned char)c] = '\n';
@@ -956 +962 @@
-		if(ep[c] == seof || ep[c] == '\0')
+		if(ep[(unsigned char)c] == seof || ep[(unsigned char)c] == '\0')
@@ -964,2 +970,2 @@
-		if(ep[c] == 0)
-			ep[c] = c;
+		if(ep[(unsigned char)c] == 0)
+			ep[(unsigned char)c] = c;

% usr/src/cmd/sed/sed1.c
@@ -3,0 +4,6 @@
+void	dosub(char *rhsbuf);
+void	command(struct reptr *ipc);
+void	arout(void);
+int	match(char *expbuf, int gf);
+int	advance(char *alp, char *aep);
+int	ecmp(char *a, char *b, int count);
@@ -39,2 +45,2 @@
-execute(file)
-char *file;
+void
+execute(char *file)
@@ -43 +49 @@
-	register union reptr	*ipc;
+	register struct reptr	*ipc;
@@ -136 +142 @@
-				if((ipc = ipc->lb1) == 0) {
+				if((ipc = ipc->u.lb1) == 0) {
@@ -158,2 +164,2 @@
-match(expbuf, gf)
-char	*expbuf;
+int
+match(char *expbuf, int gf)
@@ -167 +173 @@
-		while(*p1++ = *p2++);
+		while((*p1++ = *p2++));
@@ -205,2 +211,2 @@
-advance(alp, aep)
-char	*alp, *aep;
+int
+advance(char *alp, char *aep)
@@ -213 +219 @@
-/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	/*DEBUG*/
+/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	DEBUG */
@@ -248 +254 @@
-		braslist[*ep++] = lp;
+		braslist[(unsigned char)*ep++] = lp;
@@ -252 +258 @@
-		braelist[*ep++] = lp;
+		braelist[(unsigned char)*ep++] = lp;
@@ -256,2 +262,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[(unsigned char)*ep];
+		ct = braelist[(unsigned char)*ep++] - bbeg;
@@ -266,2 +272,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[(unsigned char)*ep];
+		ct = braelist[(unsigned char)*ep++] - bbeg;
@@ -286 +292 @@
-		while (*lp++ == *ep);
+		while ((*lp++ == *ep));
@@ -315 +321 @@
-			c = *(braslist[ep[1]]);
+			c = *(braslist[(unsigned char)ep[1]]);
@@ -336,2 +342,2 @@
-substitute(ipc)
-union reptr	*ipc;
+int
+substitute(struct reptr *ipc)
@@ -339 +345 @@
-	if(match(ipc->re1, 0) == 0)	return(0);
+	if(match(ipc->u.re1, 0) == 0)	return(0);
@@ -346 +352 @@
-			if(match(ipc->re1, 1) == 0) break;
+			if(match(ipc->u.re1, 1) == 0) break;
@@ -353,2 +359,2 @@
-dosub(rhsbuf)
-char	*rhsbuf;
+void
+dosub(char *rhsbuf)
@@ -364 +370 @@
-	while(c = *rp++) {
+	while((c = *rp++)) {
@@ -378 +384 @@
-	while (*sp++ = *lp++)
+	while ((*sp++ = *lp++))
@@ -384 +390 @@
-	while (*lp++ = *sp++);
+	while ((*lp++ = *sp++));
@@ -387,2 +393,2 @@
-char	*place(asp, al1, al2)
-char	*asp, *al1, *al2;
+char	*
+place(char *asp, char *al1, char *al2)
@@ -403,2 +409,2 @@
-command(ipc)
-union reptr	*ipc;
+void
+command(struct reptr *ipc)
@@ -425 +431 @@
-				for(p1 = ipc->re1; *p1; )
+				for(p1 = ipc->u.re1; *p1; )
@@ -444 +450 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -456 +462 @@
-			while(*p1++ = *p2++);
+			while((*p1++ = *p2++));
@@ -464 +470 @@
-			while(*p1++ = *p2++)
+			while((*p1++ = *p2++))
@@ -473 +479 @@
-			while(*p1++ = *p2++);
+			while((*p1++ = *p2++));
@@ -481 +487 @@
-			while(*p1++ = *p2++)
+			while((*p1++ = *p2++))
@@ -488 +494 @@
-			for(p1 = ipc->re1; *p1; )
+			for(p1 = ipc->u.re1; *p1; )
@@ -505 +511 @@
-						while(*p2++ = *p3++)
+						while((*p2++ = *p3++))
@@ -523 +529 @@
-					while(*p2++ = *p3++)
+					while((*p2++ = *p3++))
@@ -599 +605 @@
-			if(ipc->pfl && i)
+			if(ipc->pfl && i) {
@@ -606,0 +613 @@
+			}
@@ -624 +631 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -627 +634 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -631 +638 @@
-			while(*p2++ = *p1++);
+			while((*p2++ = *p1++));
@@ -637,2 +644,2 @@
-			p2 = ipc->re1;
-			while(*p1 = p2[*p1])	p1++;
+			p2 = ipc->u.re1;
+			while((*p1 = *p1 & 0200 ? *p1 : p2[(unsigned char)*p1]))	p1++;
@@ -645,2 +652 @@
-gline(addr)
-char	*addr;
+gline(char *addr)
@@ -649 +655 @@
-	register	c;
+	register int	c;
@@ -683,2 +689,2 @@
-ecmp(a, b, count)
-char	*a, *b;
+int
+ecmp(char *a, char *b, int count)
@@ -691 +697,2 @@
-arout()
+void
+arout(void)
@@ -698,2 +705 @@
-	aptr = abuf - 1;
-	while(*++aptr) {
+	for(aptr = abuf; *aptr; aptr++) {
@@ -701 +707 @@
-			for(p1 = (*aptr)->re1; *p1; )
+			for(p1 = (*aptr)->u.re1; *p1; )
@@ -705 +711 @@
-			if((fi = fopen((*aptr)->re1, "r")) == NULL)
+			if((fi = fopen((*aptr)->u.re1, "r")) == NULL)

% usr/src/cmd/sh/args.c
@@ -12 +12 @@
-PROC STRING *copyargs();
+LOCAL DOLPTR	copyargs(STRING from[], INT n);
@@ -27,3 +27 @@
-INT	options(argc,argv)
-	STRING		*argv;
-	INT		argc;
+INT	options(INT argc, STRING *argv)
@@ -68,2 +66 @@
-VOID	setargs(argi)
-	STRING		argi[];
+VOID	setargs(STRING argi[])
@@ -80,0 +78 @@
+	return(0);
@@ -83,2 +81 @@
-freeargs(blk)
-	DOLPTR		blk;
+DOLPTR freeargs(DOLPTR blk)
@@ -90 +87 @@
-	IF argblk=blk
+	IF (argblk=blk)
@@ -93 +90 @@
-		THEN	FOR argp=argblk->dolarg; Rcheat(*argp)!=ENDARGS; argp++
+		THEN	FOR argp=(STRING *)argblk->dolarg; Rcheat(*argp)!=ENDARGS; argp++
@@ -101,2 +98 @@
-LOCAL STRING *	copyargs(from, n)
-	STRING		from[];
+LOCAL DOLPTR	copyargs(STRING from[], INT n)
@@ -104 +100 @@
-	REG STRING *	np=alloc(sizeof(STRING*)*n+3*BYTESPERWORD);
+	REG DOLPTR	np=(DOLPTR)alloc(sizeof(STRING*)*n+3*BYTESPERWORD);
@@ -106 +102 @@
-	REG STRING *	pp=np;
+	REG STRING *	pp;
@@ -109,2 +105,2 @@
-	np=np->dolarg;
-	dolv=np;
+	pp=(STRING *)np->dolarg;
+	dolv=pp;
@@ -113,3 +109,3 @@
-	DO *np++ = make(*fp++) OD
-	*np++ = ENDARGS;
-	return(pp);
+	DO *pp++ = make(*fp++) OD
+	*pp++ = ENDARGS;
+	return(np);
@@ -118 +114 @@
-clearup()
+INT clearup(void)
@@ -121 +117 @@
-	WHILE argfor=freeargs(argfor) DONE
+	WHILE (argfor=freeargs(argfor)) DONE
@@ -124,0 +121 @@
+	return(0);
@@ -127 +124 @@
-DOLPTR	useargs()
+DOLPTR	useargs(void)

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
@@ -74,0 +73 @@
+	return(0);
@@ -77,2 +76 @@
-VOID	free(ap)
-	BLKPTR		ap;
+VOID	free(void *ap)
@@ -83 +81 @@
-	THEN	Lcheat((--p)->word) &= ~BUSY;
+	THEN	p--; p->word=BLK(Rcheat(p->word)&~BUSY);
@@ -84,0 +83 @@
+	return(0);

% usr/src/cmd/sh/brkincr.h

% usr/src/cmd/sh/builtin.c
@@ -1 +1 @@
-builtin()
+int builtin(void)

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
+LOCAL REGPTR	syncase(REG INT esym);
+LOCAL TREPTR	item(BOOL flag);
+LOCAL INT	skipnl(void);
+LOCAL VOID	prsym(INT sym);
+LOCAL VOID	synbad(void);
@@ -31,3 +31 @@
-TREPTR	makefork(flgs, i)
-	INT		flgs;
-	TREPTR		i;
+TREPTR	makefork(INT flgs, TREPTR i)
@@ -35,0 +34 @@
+	REG FORKPTR	f;
@@ -37,2 +36,3 @@
-	t=getstak(FORKTYPE);
-	t->forktyp=flgs|TFORK; t->forktre=i; t->forkio=0;
+	t=(TREPTR)getstak(FORKTYPE);
+	f=(FORKPTR)t;
+	f->forktyp=flgs|TFORK; f->forktre=i; f->forkio=0;
@@ -42,3 +42 @@
-LOCAL TREPTR	makelist(type,i,r)
-	INT		type;
-	TREPTR		i, r;
+LOCAL TREPTR	makelist(INT type, TREPTR i, TREPTR r)
@@ -46 +44,2 @@
-	REG TREPTR	t;
+	REG TREPTR	t = 0;
+	REG LSTPTR	l;
@@ -50,3 +49,4 @@
-	ELSE	t = getstak(LSTTYPE);
-		t->lsttyp = type;
-		t->lstlef = i; t->lstrit = r;
+	ELSE	t = (TREPTR)getstak(LSTTYPE);
+		l = (LSTPTR)t;
+		l->lsttyp = type;
+		l->lstlef = i; l->lstrit = r;
@@ -65,3 +65 @@
-TREPTR	cmd(sym,flg)
-	REG INT		sym;
-	INT		flg;
+TREPTR	cmd(REG INT sym, INT flg)
@@ -87,0 +86 @@
+		/* fallthrough */
@@ -90 +89 @@
-		IF e=cmd(sym,flg|MTFLG)
+		IF (e=cmd(sym,flg|MTFLG))
@@ -98,0 +98 @@
+		/* fallthrough */
@@ -116 +116 @@
-LOCAL TREPTR	list(flg)
+LOCAL TREPTR	list(INT flg)
@@ -134 +134 @@
-LOCAL TREPTR	term(flg)
+LOCAL TREPTR	term(INT flg)
@@ -150,2 +150 @@
-LOCAL REGPTR	syncase(esym)
-	REG INT	esym;
+LOCAL REGPTR	syncase(REG INT esym)
@@ -156 +155 @@
-	ELSE	REG REGPTR	r=getstak(REGTYPE);
+	ELSE	REG REGPTR	r=(REGPTR)getstak(REGTYPE);
@@ -189,2 +188 @@
-LOCAL TREPTR	item(flag)
-	BOOL		flag;
+LOCAL TREPTR	item(BOOL flag)
@@ -204 +202,3 @@
-		   t=getstak(SWTYPE);
+		   REG SWPTR	s;
+		   t=(TREPTR)getstak(SWTYPE);
+		   s=(SWPTR)t;
@@ -206 +206 @@
-		   t->swarg=wdarg->argval;
+		   s->swarg=wdarg->argval;
@@ -208,2 +208,2 @@
-		   t->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
-		   t->swtyp=TSW;
+		   s->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
+		   s->swtyp=TSW;
@@ -216,5 +216,7 @@
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
@@ -227,3 +229,5 @@
-		   t=getstak(FORTYPE);
-		   t->fortyp=TFOR;
-		   t->forlst=0;
+		   REG FORPTR	fr;
+		   t=(TREPTR)getstak(FORTYPE);
+		   fr=(FORPTR)t;
+		   fr->fortyp=TFOR;
+		   fr->forlst=0;
@@ -231 +235 @@
-		   t->fornam=wdarg->argval;
+		   fr->fornam=wdarg->argval;
@@ -234 +238 @@
-			t->forlst=item(0);
+			fr->forlst=(COMPTR)item(0);
@@ -241 +245 @@
-		   t->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
+		   fr->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
@@ -248,4 +252,6 @@
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
@@ -262 +268 @@
-		   p=getstak(PARTYPE);
+		   p=(PARPTR)getstak(PARTYPE);
@@ -265 +271 @@
-		   t=makefork(0,p);
+		   t=makefork(0,(TREPTR)p);
@@ -272,0 +279 @@
+		/* fallthrough */
@@ -278,0 +286 @@
+		   REG COMPTR	c;
@@ -280,3 +288,4 @@
-		   t=getstak(COMTYPE);
-		   t->comio=io; /*initial io chain*/
-		   argtail = &(t->comarg);
+		   t=(TREPTR)getstak(COMTYPE);
+		   c=(COMPTR)t;
+		   c->comio=io; /*initial io chain*/
+		   argtail = &(c->comarg);
@@ -286 +295 @@
-			THEN	argp->argnxt=argset; argset=argp;
+			THEN	argp->argnxt=(ARGPTR)argset; argset=(ARGPTR *)argp;
@@ -291 +300 @@
-			THEN t->comio=inout(t->comio);
+			THEN c->comio=inout(c->comio);
@@ -295 +304 @@
-		   t->comtyp=TCOM; t->comset=argset; *argtail=0;
+		   c->comtyp=TCOM; c->comset=(ARGPTR)argset; *argtail=0;
@@ -301 +310 @@
-	IF io=inout(io)
+	IF (io=inout(io))
@@ -308 +317 @@
-LOCAL VOID	skipnl()
+LOCAL INT	skipnl(void)
@@ -314,2 +323 @@
-LOCAL IOPTR	inout(lastio)
-	IOPTR		lastio;
+LOCAL IOPTR	inout(IOPTR lastio)
@@ -334,0 +343 @@
+		/* fallthrough */
@@ -350 +359 @@
-	iop=getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
+	iop=(IOPTR)getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
@@ -358 +367 @@
-LOCAL VOID	chkword()
+LOCAL VOID	chkword(void)
@@ -362,0 +372 @@
+	return(0);
@@ -365 +375 @@
-LOCAL VOID	chksym(sym)
+LOCAL VOID	chksym(INT sym)
@@ -370,0 +381 @@
+	return(0);
@@ -373 +384 @@
-LOCAL VOID	prsym(sym)
+LOCAL VOID	prsym(INT sym)
@@ -388,0 +400 @@
+	return(0);
@@ -391 +403 @@
-LOCAL VOID	synbad()
+LOCAL VOID	synbad(void)
@@ -405,0 +418 @@
+	return(0);

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
+#define	space(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(T_SPC))
+#define eofmeta(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(_META|T_EOF))
+#define qotchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(T_QOT))
+#define eolchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(T_EOR|T_EOF))
+#define dipchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(T_DIP))
+#define subchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(T_SUB|T_QOT))
+#define escchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(unsigned char)(c)]&(T_ESC))
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
+#define	digit(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_DIG))
+#define fngchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_FNG))
+#define dolchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_AST|T_BRC|T_DIG|T_IDC|T_SHN))
+#define defchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_DEF))
+#define setchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_SET))
+#define digchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_AST|T_DIG))
+#define	letter(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_IDC))
+#define alphanum(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(_IDCH))
+#define astchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(unsigned char)(c)]&(T_AST))

% usr/src/cmd/sh/defs.h
@@ -81,28 +81,93 @@
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
+STRING		movstr(REG STRING a, REG STRING b);
+TREPTR		cmd(REG INT sym, INT flg);
+TREPTR		makefork(INT flgs, TREPTR i);
+NAMPTR		lookup(REG STRING nam);
+VOID		setname(STRING argi, INT xp);
+VOID		setargs(STRING argi[]);
+DOLPTR		useargs(void);
+STRING		catpath(REG STRING path, STRING name);
+STRING		getpath(STRING s);
+STRING		*scan(INT argn);
+STRING		mactrim(STRING s);
+STRING		macro(STRING as);
+VOID		await(INT i);
+VOID		post(INT pcsid);
+VOID		exname(REG NAMPTR n);
+VOID		printnam(NAMPTR n);
+VOID		printflg(REG NAMPTR n);
+VOID		prs(STRING as);
+VOID		prc(INT c);
+INT		getenv(void);
+STRING		*setenv(void);
+INT		options(INT argc, STRING *argv);
+DOLPTR		freeargs(DOLPTR blk);
+INT		clearup(void);
+VOID		free(void *ap);
+INT		builtin(void);
+INT		exitset(void);
+INT		sigchk(void);
+INT		failed(STRING s1, STRING s2);
+INT		error(STRING s);
+void		exitsh(INT xno);
+void		done(void);
+void		rmtemp(IOPTR base);
+INT		expand(STRING as, INT rflg);
+INT		gmatch(REG STRING s, REG STRING p);
+INT		makearg(REG ARGPTR args);
+VOID		stdsigs(void);
+INT		ignsig(INT n);
+VOID		getsig(INT n);
+VOID		oldsigs(void);
+VOID		clrsig(INT i);
+VOID		chktrap(void);
+INT		initf(UFD fd);
+INT		estabf(REG STRING s);
+INT		push(FILE af);
+INT		pop(void);
+INT		chkpipe(INT *pv);
+INT		chkopen(STRING idf);
+INT		rename(REG INT f1, REG INT f2);
+INT		create(STRING s);
+INT		tmpfil(void);
+INT		copy(IOPTR ioparg);
+INT		subst(INT in, INT ot);
+VOID		chkpr(INT eor);
+INT		settmp(void);
+INT		Ldup(REG INT fa, REG INT fb);
+INT		syslook(STRING w, struct sysnod syswds[]);
+INT		setlist(REG ARGPTR arg, INT xp);
+INT		replace(REG STRING *a, STRING v);
+INT		dfault(NAMPTR n, STRING v);
+INT		assign(NAMPTR n, STRING v);
+INT		readvar(STRING *names);
+INT		assnum(STRING *p, INT i);
+INT		namscan(VOID (*fn)(NAMPTR));
+VOID		countnam(NAMPTR n);
+VOID		pushnam(NAMPTR n);
+INT		newline(void);
+INT		blank(void);
+INT		prp(void);
+INT		prt(L_INT t);
+INT		prn(INT n);
+INT		itos(INT n);
+INT		stoi(STRING icp);
+VOID		initio(IOPTR iop);
+INT		pathopen(REG STRING path, REG STRING name);
+VOID		execa(STRING at[]);
+INT		postclr(void);
+INT		trim(STRING at);
+INT		getarg(COMPTR ac);
+BYTPTR		setbrk(INT incr);
+VOID		tdystak(REG STKPTR x);
+INT		stakchk(void);
+INT		any(REG CHAR c, STRING s);
+INT		cf(REG STRING s1, REG STRING s2);
+INT		length(STRING as);
+INT		word(void);
+INT		nextc(INT quote);
+INT		readc(void);
+INT		execute(TREPTR argt, INT execflg, INT *pf1, INT *pf2);
+void		execexp(STRING s, UFD f);
@@ -139,9 +204,9 @@
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
@@ -150 +215 @@
-SYSTAB		reserved;
+extern SYSTAB	reserved;
@@ -158,3 +223,3 @@
-MSG		stdprompt;
-MSG		supprompt;
-MSG		profile;
+extern MSG	stdprompt;
+extern MSG	supprompt;
+extern MSG	profile;
@@ -172 +237 @@
-MSG		flagadr;
+extern MSG	flagadr;
@@ -179 +244 @@
-MSG		defpath;
+extern MSG	defpath;
@@ -182,7 +247,7 @@
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
@@ -191 +256 @@
-CHAR		tmpout[];
+extern CHAR	tmpout[];
@@ -200 +265 @@
-MSG		devnull;
+extern MSG	devnull;
@@ -240 +305 @@
-VOID		fault();
+VOID		fault(INT sig);
@@ -242,2 +307,2 @@
-STRING		trapcom[];
-BOOL		trapflg[];
+extern STRING	trapcom[];
+extern BOOL	trapflg[];
@@ -247,3 +312,3 @@
-CHAR		numbuf[];
-MSG		export;
-MSG		readonly;
+extern CHAR	numbuf[];
+extern MSG	export;
+extern MSG	readonly;
@@ -258,25 +323,25 @@
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
@@ -284 +349 @@
-address	end[];
+extern address	end[];

% usr/src/cmd/sh/dup.h

% usr/src/cmd/sh/error.c
@@ -11,0 +12,2 @@
+extern void exit(int n) __attribute__((__noreturn__));
+extern int unlink(char *p);
@@ -15 +17 @@
-exitset()
+INT exitset(void)
@@ -17,0 +20 @@
+	return(0);
@@ -20 +23 @@
-sigchk()
+INT sigchk(void)
@@ -28,0 +32 @@
+	return(0);
@@ -31,2 +35 @@
-failed(s1,s2)
-	STRING	s1, s2;
+INT failed(STRING s1, STRING s2)
@@ -38,0 +42 @@
+	return(0);
@@ -41,2 +45 @@
-error(s)
-	STRING	s;
+INT error(STRING s)
@@ -44,0 +48 @@
+	return(0);
@@ -47,2 +51,2 @@
-exitsh(xno)
-	INT	xno;
+void
+exitsh(INT xno)
@@ -65 +69 @@
-done()
+void done(void)
@@ -68 +72 @@
-	IF t=trapcom[0]
+	IF (t=trapcom[0])
@@ -76,2 +80,2 @@
-rmtemp(base)
-	IOPTR		base;
+void
+rmtemp(IOPTR base)

% usr/src/cmd/sh/expand.c
@@ -27 +27,5 @@
-PROC VOID	addg();
+LOCAL VOID	addg(STRING as1, STRING as2, STRING as3);
+extern int stat(char *p, STATBUF *s);
+extern int open(char *p, int f);
+extern int read(int fd, char *buf, int n);
+extern int close(int fd);
@@ -30,2 +34 @@
-INT	expand(as,rflg)
-	STRING		as;
+INT	expand(STRING as, INT rflg)
@@ -80 +83 @@
-		WHILE read(dirf, &entry, 16) == 16 ANDF (trapnote&SIGSET) == 0
+		WHILE read(dirf, (char *)&entry, 16) == 16 ANDF (trapnote&SIGSET) == 0
@@ -108 +111 @@
-	   WHILE c = *s
+	   WHILE (c = *s)
@@ -114,2 +117,2 @@
-gmatch(s, p)
-	REG STRING	s, p;
+INT
+gmatch(REG STRING s, REG STRING p)
@@ -120 +123 @@
-	IF scc = *s++
+	IF (scc = *s++)
@@ -125 +128 @@
-	SWITCH c = *p++ IN
+	SWITCH (c = *p++) IN
@@ -130 +133 @@
-		WHILE c = *p++
+		WHILE (c = *p++)
@@ -134 +137 @@
-			THEN	IF lc<=scc ANDF scc<=(*p++) THEN ok++ FI
+			THEN	IF lc<=scc ANDF scc<=((*p++)&STRIP) THEN ok++ FI
@@ -142,0 +146 @@
+		/* fallthrough */
@@ -156,0 +161 @@
+	return(0);
@@ -159,2 +164 @@
-LOCAL VOID	addg(as1,as2,as3)
-	STRING		as1, as2, as3;
+LOCAL VOID	addg(STRING as1, STRING as2, STRING as3)
@@ -168 +172 @@
-	WHILE c = *s1++
+	WHILE (c = *s1++)
@@ -176,2 +180,2 @@
-	WHILE *s2 = *s1++ DO s2++ OD
-	IF s1=as3
+	WHILE (*s2 = *s1++) DO s2++ OD
+	IF (s1=as3)
@@ -179 +183 @@
-		WHILE *s2++ = *++s1 DONE
+		WHILE (*s2++ = *++s1) DONE
@@ -181 +185,2 @@
-	makearg(endstak(s2));
+	makearg((ARGPTR)endstak(s2));
+	return(0);
@@ -184,2 +189 @@
-makearg(args)
-	REG STRING	args;
+INT makearg(REG ARGPTR args)
@@ -188,0 +193 @@
+	return(0);

% usr/src/cmd/sh/fault.c
@@ -11,0 +12 @@
+extern int signal(int sig, int fun);
@@ -19,2 +20,2 @@
-VOID	fault(sig)
-	REG INT		sig;
+VOID
+fault(INT sig)
@@ -24 +25 @@
-	signal(sig,fault);
+	signal(sig, (int)fault);
@@ -26 +27 @@
-	THEN	IF setbrk(brkincr) == -1
+	THEN	IF setbrk(brkincr) == (BYTPTR)-1
@@ -36,0 +38 @@
+	return(0);
@@ -39 +41,2 @@
-stdsigs()
+VOID
+stdsigs(void)
@@ -44,0 +48 @@
+	return(0);
@@ -47 +51,2 @@
-ignsig(n)
+INT
+ignsig(INT n)
@@ -57 +62,2 @@
-getsig(n)
+VOID
+getsig(INT n)
@@ -62 +68 @@
-	THEN	signal(i,fault);
+	THEN	signal(i, (int)fault);
@@ -63,0 +70 @@
+	return(0);
@@ -66 +73,2 @@
-oldsigs()
+VOID
+oldsigs(void)
@@ -79,0 +88 @@
+	return(0);
@@ -82,2 +91,2 @@
-clrsig(i)
-	INT		i;
+VOID
+clrsig(INT i)
@@ -87 +96 @@
-	THEN	signal(i,fault);
+	THEN	signal(i, (int)fault);
@@ -89,0 +99 @@
+	return(0);
@@ -92 +102,2 @@
-chktrap()
+VOID
+chktrap(void)
@@ -102 +113 @@
-		IF t=trapcom[i]
+		IF (t=trapcom[i])
@@ -108,0 +120 @@
+	return(0);

% usr/src/cmd/sh/io.c
@@ -12,0 +13,6 @@
+extern int close(int fd);
+extern int open(char *p, int f);
+extern int creat(char *p, int m);
+extern int pipe(int *pv);
+extern int dup(int f1, int f2);
+extern int write(int fd, char *buf, int n);
@@ -16,2 +22 @@
-initf(fd)
-	UFD		fd;
+INT initf(UFD fd)
@@ -21 +26,2 @@
-	f->fdes=fd; f->fsiz=((flags&(oneflg|ttyflg))==0 ? BUFSIZ : 1);
+	f->fdes=fd; f->fsiz=(fd > 2 ? BUFSIZ :
+	    ((flags&(oneflg|ttyflg))==0 ? BUFSIZ : 1));
@@ -23,0 +30 @@
+	return(0);
@@ -26,2 +33 @@
-estabf(s)
-	REG STRING	s;
+INT estabf(REG STRING s)
@@ -37,2 +43 @@
-push(af)
-	FILE		af;
+INT push(FILE af)
@@ -44,0 +50 @@
+	return(0);
@@ -47 +53 @@
-pop()
+INT pop(void)
@@ -59,2 +65 @@
-chkpipe(pv)
-	INT		*pv;
+INT chkpipe(INT *pv)
@@ -64,0 +70 @@
+	return(0);
@@ -67,2 +73,2 @@
-chkopen(idf)
-	STRING		idf;
+INT
+chkopen(STRING idf)
@@ -75,0 +82 @@
+	return(0);
@@ -78,2 +85 @@
-rename(f1,f2)
-	REG INT		f1, f2;
+INT rename(REG INT f1, REG INT f2)
@@ -85,0 +92 @@
+	return(0);
@@ -88,2 +95,2 @@
-create(s)
-	STRING		s;
+INT
+create(STRING s)
@@ -96,0 +104 @@
+	return(0);
@@ -99 +107 @@
-tmpfil()
+INT tmpfil(void)
@@ -108,2 +116 @@
-copy(ioparg)
-	IOPTR		ioparg;
+INT copy(IOPTR ioparg)
@@ -116 +123 @@
-	IF iop=ioparg
+	IF (iop=ioparg)
@@ -132,0 +140 @@
+	return(0);

% usr/src/cmd/sh/mac.h

% usr/src/cmd/sh/macro.c
@@ -12,0 +13,6 @@
+LOCAL INT	getch(CHAR endch);
+LOCAL INT	skipto(CHAR endch);
+LOCAL INT	comsubst(void);
+LOCAL INT	flush(INT ot);
+extern int close(int fd);
+extern int write(int fd, char *buf, int n);
@@ -18,2 +24 @@
-LOCAL STRING	copyto(endch)
-	REG CHAR	endch;
+LOCAL STRING	copyto(INT endch)
@@ -26,0 +32 @@
+	return(0);
@@ -29,2 +35 @@
-LOCAL	skipto(endch)
-	REG CHAR	endch;
+LOCAL INT skipto(CHAR endch)
@@ -46,0 +52 @@
+	return(0);
@@ -49,2 +55 @@
-LOCAL	getch(endch)
-	CHAR		endch;
+LOCAL INT getch(CHAR endch)
@@ -62 +67 @@
-		THEN	NAMPTR		n=NIL;
+		THEN	NAMPTR		n=(NAMPTR)NIL;
@@ -65 +70 @@
-			REG STRING	argp, v;
+			REG STRING	argp, v=0;
@@ -69 +74 @@
-			IF bra=(c==BRACE) THEN c=readc() FI
+			IF (bra=(c==BRACE)) THEN c=readc() FI
@@ -71 +76 @@
-			THEN	argp=relstak();
+			THEN	argp=(STRING)(long)relstak();
@@ -83 +88 @@
-				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (dolg=0));
+				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (STRING)(long)(dolg=0));
@@ -104 +109 @@
-				THEN	argp=relstak();
+				THEN	argp=(STRING)(long)relstak();
@@ -115 +120 @@
-				THEN	LOOP WHILE c = *v++
+				THEN	LOOP WHILE (c = *v++)
@@ -148,2 +153 @@
-STRING	macro(as)
-	STRING		as;
+STRING	macro(STRING as)
@@ -158 +162 @@
-	push(&fb); estabf(as);
+	push((FILE)&fb); estabf(as);
@@ -168 +172 @@
-LOCAL	comsubst()
+LOCAL INT comsubst(void)
@@ -197 +201 @@
-	WHILE d=readc() DO pushstak(d|quote) OD
+	WHILE (d=readc()) DO pushstak(d|quote) OD
@@ -204,0 +209 @@
+	return(0);
@@ -209,2 +214 @@
-subst(in,ot)
-	INT		in, ot;
+INT subst(INT in, INT ot)
@@ -218 +222 @@
-	WHILE c=(getch(DQUOTE)&STRIP)
+	WHILE (c=(getch(DQUOTE)&STRIP))
@@ -225,0 +230 @@
+	return(0);
@@ -228 +233 @@
-LOCAL	flush(ot)
+LOCAL INT flush(INT ot)
@@ -232,0 +238 @@
+	return(0);

% usr/src/cmd/sh/main.c
@@ -25 +25,9 @@
-PROC VOID	exfile();
+LOCAL VOID	exfile(BOOL prof);
+extern int getpid(void);
+extern int getuid(void);
+extern int gtty();
+extern int alarm(unsigned sec);
+extern int stat(char *p, struct stat *s);
+extern int close(int fd);
+extern int dup();
+extern int ioctl(int fd, int cmd, ...);
@@ -30,3 +38,2 @@
-main(c, v)
-	INT		c;
-	STRING		v[];
+int
+main(INT c, STRING v[])
@@ -85 +92 @@
-	ELSE	*execargs=dolv;	/* for `ps' cmd */
+	ELSE	*execargs=(char *)dolv;	/* for `ps' cmd */
@@ -89,0 +97 @@
+	return(0);
@@ -92,2 +100 @@
-LOCAL VOID	exfile(prof)
-BOOL		prof;
+LOCAL VOID	exfile(BOOL prof)
@@ -95 +102 @@
-	REG L_INT	mailtime = 0;
+	volatile L_INT	mailtime = 0;
@@ -122 +129 @@
-	THEN	close(input); return;
+	THEN	close(input); return(0);
@@ -146 +153 @@
-		THEN	return;
+		THEN	return(0);
@@ -149 +156 @@
-		execute(cmd(NL,MTFLG),0);
+		execute(cmd(NL,MTFLG),0,(INT *)0,(INT *)0);
@@ -154,2 +161,2 @@
-chkpr(eor)
-char eor;
+VOID
+chkpr(INT eor)
@@ -159,0 +167 @@
+	return(0);
@@ -162 +170 @@
-settmp()
+INT settmp(void)
@@ -165,0 +174 @@
+	return(0);
@@ -168,2 +177 @@
-Ldup(fa, fb)
-	REG INT		fa, fb;
+INT Ldup(REG INT fa, REG INT fb)
@@ -173,0 +182 @@
+	return(0);

% usr/src/cmd/sh/mode.h
@@ -46 +45,0 @@
-STRUCT sysnod	SYSTAB[];
@@ -55,2 +54 @@
-union { int _cheat;};
-#define Lcheat(a)	((a)._cheat)
+#define Lcheat(a)	(*(int *)&(a))
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
@@ -12 +12 @@
-PROC BOOL	chkid();
+LOCAL BOOL	chkid(STRING nam);
@@ -15,7 +15,10 @@
-NAMNOD	ps2nod	= {	NIL,		NIL,		ps2name},
-	fngnod	= {	NIL,		NIL,		fngname},
-	pathnod = {	NIL,		NIL,		pathname},
-	ifsnod	= {	NIL,		NIL,		ifsname},
-	ps1nod	= {	&pathnod,	&ps2nod,	ps1name},
-	homenod = {	&fngnod,	&ifsnod,	homename},
-	mailnod = {	&homenod,	&ps1nod,	mailname};
+LOCAL VOID	namwalk(REG NAMPTR np);
+extern int dup();
+extern long lseek(int fd, long off, int whence);
+NAMNOD	ps2nod	= {	0,		0,		ps2name,	NIL, NIL, 0},
+	fngnod	= {	0,		0,		fngname,	NIL, NIL, 0},
+	pathnod = {	0,		0,		pathname,	NIL, NIL, 0},
+	ifsnod	= {	0,		0,		ifsname,	NIL, NIL, 0},
+	ps1nod	= {	&pathnod,	&ps2nod,	ps1name,	NIL, NIL, 0},
+	homenod = {	&fngnod,	&ifsnod,	homename,	NIL, NIL, 0},
+	mailnod = {	&homenod,	&ps1nod,	mailname,	NIL, NIL, 0};
@@ -28,3 +31 @@
-syslook(w,syswds)
-	STRING		w;
-	SYSTAB		syswds;
+INT syslook(STRING w, struct sysnod syswds[])
@@ -38 +39 @@
-	WHILE s=syscan->sysnam
+	WHILE (s=syscan->sysnam)
@@ -48,3 +49 @@
-setlist(arg,xp)
-	REG ARGPTR	arg;
-	INT		xp;
+INT setlist(REG ARGPTR arg, INT xp)
@@ -60,0 +60 @@
+	return(0);
@@ -63,3 +63 @@
-VOID	setname(argi, xp)
-	STRING		argi;
-	INT		xp;
+VOID	setname(STRING argi, INT xp)
@@ -81 +79 @@
-			return;
+			return(0);
@@ -84,0 +83 @@
+	return(0);
@@ -87,3 +86,2 @@
-replace(a, v)
-	REG STRING	*a;
-	STRING		v;
+INT
+replace(REG STRING *a, STRING v)
@@ -91,0 +90 @@
+	return(0);
@@ -94,3 +93 @@
-dfault(n,v)
-	NAMPTR		n;
-	STRING		v;
+INT dfault(NAMPTR n, STRING v)
@@ -100,0 +98 @@
+	return(0);
@@ -103,3 +101 @@
-assign(n,v)
-	NAMPTR		n;
-	STRING		v;
+INT assign(NAMPTR n, STRING v)
@@ -110,0 +107 @@
+	return(0);
@@ -113,2 +110 @@
-INT	readvar(names)
-	STRING		*names;
+INT	readvar(STRING *names)
@@ -121 +117 @@
-	STKPTR		rel=relstak();
+	STKPTR		rel=(STKPTR)(long)relstak();
@@ -153,3 +149 @@
-assnum(p, i)
-	STRING		*p;
-	INT		i;
+INT assnum(STRING *p, INT i)
@@ -157,0 +152 @@
+	return(0);
@@ -160,2 +155 @@
-STRING	make(v)
-	STRING		v;
+STRING	make(STRING v)
@@ -173,2 +167 @@
-NAMPTR		lookup(nam)
-	REG STRING	nam;
+NAMPTR		lookup(REG STRING nam)
@@ -177 +170 @@
-	REG NAMPTR	*prev;
+	REG NAMPTR	*prev = 0;
@@ -194,2 +187,2 @@
-	nscan=alloc(sizeof *nscan);
-	nscan->namlft=nscan->namrgt=NIL;
+	nscan=(NAMPTR)alloc(sizeof *nscan);
+	nscan->namlft=nscan->namrgt=0;
@@ -201,2 +194 @@
-LOCAL BOOL	chkid(nam)
-	STRING		nam;
+LOCAL BOOL	chkid(STRING nam)
@@ -217,3 +209,3 @@
-LOCAL VOID (*namfn)();
-namscan(fn)
-	VOID		(*fn)();
+LOCAL VOID (*namfn)(NAMPTR);
+INT
+namscan(VOID (*fn)(NAMPTR))
@@ -222,0 +215 @@
+	return(0);
@@ -225,2 +218 @@
-LOCAL VOID	namwalk(np)
-	REG NAMPTR	np;
+LOCAL VOID	namwalk(REG NAMPTR np)
@@ -232,0 +225 @@
+	return(0);
@@ -235,2 +228 @@
-VOID	printnam(n)
-	NAMPTR		n;
+VOID	printnam(NAMPTR n)
@@ -241 +233 @@
-	IF s=n->namval
+	IF (s=n->namval)
@@ -245,0 +238 @@
+	return(0);
@@ -248,2 +241 @@
-LOCAL STRING	staknam(n)
-	REG NAMPTR	n;
+LOCAL STRING	staknam(REG NAMPTR n)
@@ -259,2 +251 @@
-VOID	exname(n)
-	REG NAMPTR	n;
+VOID	exname(REG NAMPTR n)
@@ -267,0 +259 @@
+	return(0);
@@ -270,2 +262 @@
-VOID	printflg(n)
-	REG NAMPTR		n;
+VOID	printflg(REG NAMPTR n)
@@ -281,0 +273 @@
+	return(0);
@@ -284 +276 @@
-VOID	getenv()
+INT	getenv(void)
@@ -286,0 +279 @@
+	REG STRING	s;
@@ -289 +282,6 @@
-	DO setname(*e++, N_ENVNAM) OD
+	DO	s = *e++;
+		IF any('=', s)
+		THEN	setname(s, N_ENVNAM);
+		FI
+	OD
+	return(0);
@@ -294,2 +292 @@
-VOID	countnam(n)
-	NAMPTR		n;
+VOID	countnam(NAMPTR n)
@@ -296,0 +294 @@
+	(void)n;
@@ -297,0 +296 @@
+	return(0);
@@ -302,2 +301 @@
-VOID	pushnam(n)
-	NAMPTR		n;
+VOID	pushnam(NAMPTR n)
@@ -307,0 +306 @@
+	return(0);
@@ -310 +309 @@
-STRING	*setenv()
+STRING	*setenv(void)
@@ -316 +315 @@
-	argnam = er = getstak(namec*BYTESPERWORD+BYTESPERWORD);
+	argnam = er = (STRING *)getstak(namec*BYTESPERWORD+BYTESPERWORD);

% usr/src/cmd/sh/name.h

% usr/src/cmd/sh/print.c
@@ -11,0 +12 @@
+extern int write(int fd, char *buf, int n);
@@ -17,2 +18,2 @@
-newline()
-{	prc(NL);
+INT newline(void)
+{	prc(NL); return(0);
@@ -21,2 +22,2 @@
-blank()
-{	prc(SP);
+INT blank(void)
+{	prc(SP); return(0);
@@ -25 +26 @@
-prp()
+INT prp(void)
@@ -29,0 +31 @@
+	return(0);
@@ -32,2 +34 @@
-VOID	prs(as)
-	STRING		as;
+VOID	prs(STRING as)
@@ -37 +38 @@
-	IF s=as
+	IF (s=as)
@@ -39,0 +41 @@
+	return(0);
@@ -42,2 +44 @@
-VOID	prc(c)
-	CHAR		c;
+VOID	prc(INT cc)
@@ -44,0 +46 @@
+	CHAR c = cc;
@@ -47,0 +50 @@
+	return(0);
@@ -50,2 +53 @@
-prt(t)
-	L_INT		t;
+INT prt(L_INT t)
@@ -58 +60 @@
-	IF hr=t/60
+	IF (hr=t/60)
@@ -62,0 +65 @@
+	return(0);
@@ -65,2 +68 @@
-prn(n)
-	INT		n;
+INT prn(INT n)
@@ -68,0 +71 @@
+	return(0);
@@ -71 +74 @@
-itos(n)
+INT itos(INT n)
@@ -80,0 +84 @@
+	return(0);
@@ -83,2 +87,2 @@
-stoi(icp)
-STRING	icp;
+INT
+stoi(STRING icp)
@@ -95,0 +100 @@
+	return(0);

% usr/src/cmd/sh/service.c
@@ -13 +13,10 @@
-PROC VOID	gsort();
+LOCAL VOID	gsort(STRING from[], STRING to[]);
+LOCAL STRING	execs(STRING ap, REG STRING t[]);
+LOCAL INT	split(REG STRING s);
+extern int close(int fd);
+extern int unlink(char *p);
+extern int dup();
+extern int open(char *p, int f);
+extern long lseek(int fd, long off, int whence);
+extern int execve(char *p, char **argv, char **env);
+extern int wait(int *st);
@@ -18 +27 @@
-STRING		sysmsg[];
+extern STRING	sysmsg[];
@@ -31,2 +40 @@
-VOID	initio(iop)
-	IOPTR		iop;
+VOID	initio(IOPTR iop)
@@ -35 +43 @@
-	REG INT		iof, fd;
+	REG INT		iof, fd = -1;
@@ -65,0 +74 @@
+	return(0);
@@ -68,2 +77,26 @@
-STRING	getpath(s)
-	STRING		s;
+VOID	nullio(IOPTR iop)
+{
+	REG STRING	ion;
+	REG INT		iof, fd;
+	IF iop
+	THEN	iof=iop->iofile;
+		ion=mactrim(iop->ioname);
+		IF *ion ANDF (flags&noexec)==0
+		THEN	IF iof&IODOC
+			THEN	fd=tmpfil(); close(fd); unlink(tmpout);
+			ELIF iof&IOMOV
+			THEN	;
+			ELIF (iof&IOPUT)==0
+			THEN	close(chkopen(ion));
+			ELIF flags&rshflg
+			THEN	failed(ion,restricted);
+			ELIF iof&IOAPP ANDF (fd=open(ion,1))>=0
+			THEN	lseek(fd, 0L, 2); close(fd);
+			ELSE	fd=create(ion); close(fd);
+			FI
+		FI
+		nullio(iop->ionxt);
+	FI
+	return(0);
+}
+STRING	getpath(STRING s)
@@ -80,0 +114 @@
+	return(0);
@@ -83,2 +117 @@
-INT	pathopen(path, name)
-	REG STRING	path, name;
+INT	pathopen(REG STRING path, REG STRING name)
@@ -93,3 +126 @@
-STRING	catpath(path,name)
-	REG STRING	path;
-	STRING		name;
+STRING	catpath(REG STRING path, STRING name)
@@ -112,2 +143 @@
-VOID	execa(at)
-	STRING		at[];
+VOID	execa(STRING at[])
@@ -122 +152 @@
-		WHILE path=execs(path,t) DONE
+		WHILE (path=execs(path,t)) DONE
@@ -124,0 +155 @@
+	return(0);
@@ -127,3 +158 @@
-LOCAL STRING	execs(ap,t)
-	STRING		ap;
-	REG STRING	t[];
+LOCAL STRING	execs(STRING ap, REG STRING t[])
@@ -150,0 +180 @@
+		/* fallthrough */
@@ -153,0 +184 @@
+		/* fallthrough */
@@ -156,0 +188 @@
+		/* fallthrough */
@@ -159,0 +192 @@
+		/* fallthrough */
@@ -162,0 +196 @@
+		/* fallthrough */
@@ -165,0 +200 @@
+	return(prefix);
@@ -173 +208 @@
-postclr()
+INT postclr(void)
@@ -179,0 +215 @@
+	return(0);
@@ -182,2 +218 @@
-VOID	post(pcsid)
-	INT		pcsid;
+VOID	post(INT pcsid)
@@ -194,0 +230 @@
+	return(0);
@@ -197,2 +233 @@
-VOID	await(i)
-	INT		i;
+VOID	await(INT i)
@@ -225 +260 @@
-		IF sig = w&0177
+		IF (sig = w&0177)
@@ -247,0 +283 @@
+	return(0);
@@ -252,2 +288 @@
-trim(at)
-	STRING		at;
+INT trim(STRING at)
@@ -259,2 +294,2 @@
-	IF p=at
-	THEN	WHILE c = *p
+	IF (p=at)
+	THEN	WHILE (c = *p)
@@ -263,0 +299 @@
+	return(0);
@@ -266,2 +302 @@
-STRING	mactrim(s)
-	STRING		s;
+STRING	mactrim(STRING s)
@@ -274,2 +309 @@
-STRING	*scan(argn)
-	INT		argn;
+STRING	*scan(INT argn)
@@ -277 +311 @@
-	REG ARGPTR	argp = Rcheat(gchain)&~ARGMK;
+	REG ARGPTR	argp = (ARGPTR)(long)(Rcheat(gchain)&~ARGMK);
@@ -280 +314 @@
-	comargn=getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;
+	comargn=(STRING *)getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;
@@ -284 +318 @@
-		IF argp = argp->argnxt
+		IF (argp = argp->argnxt)
@@ -292 +326 @@
-		argp = Rcheat(argp)&~ARGMK;
+		argp = (ARGPTR)(long)(Rcheat(argp)&~ARGMK);
@@ -297,2 +331 @@
-LOCAL VOID	gsort(from,to)
-	STRING		from[], to[];
+LOCAL VOID	gsort(STRING from[], STRING to[])
@@ -303 +336 @@
-	IF (n=to-from)<=1 THEN return FI
+	IF (n=to-from)<=1 THEN return(0) FI
@@ -318,0 +352 @@
+	return(0);
@@ -323,2 +357 @@
-INT	getarg(ac)
-	COMPTR		ac;
+INT	getarg(COMPTR ac)
@@ -330 +363 @@
-	IF c=ac
+	IF (c=ac)
@@ -340,2 +373 @@
-LOCAL INT	split(s)
-	REG STRING	s;
+LOCAL INT	split(REG STRING s)
@@ -343,0 +376 @@
+	REG ARGPTR	arg;
@@ -358 +391,2 @@
-		IF c=expand((argp=endstak(argp))->argval,0)
+		arg=(ARGPTR)endstak(argp);
+		IF (c=expand(arg->argval,0))
@@ -361 +395 @@
-			makearg(argp); count++;
+			makearg(arg); count++;
@@ -363 +397 @@
-		Lcheat(gchain) |= ARGMK;
+		gchain=(ARGPTR)(long)(Rcheat(gchain)|ARGMK);

% usr/src/cmd/sh/setbrk.c
@@ -12 +12,2 @@
-setbrk(incr)
+extern char *sbrk(int incr);
+BYTPTR setbrk(INT incr)

% usr/src/cmd/sh/stak.c
@@ -18,2 +18 @@
-STKPTR	getstak(asize)
-	INT		asize;
+STKPTR	getstak(INT asize)
@@ -30 +29 @@
-STKPTR	locstak()
+STKPTR	locstak(void)
@@ -43 +42 @@
-STKPTR	savstak()
+STKPTR	savstak(void)
@@ -49,2 +48 @@
-STKPTR	endstak(argp)
-	REG STRING	argp;
+STKPTR	endstak(REG STRING argp)
@@ -54 +52 @@
-	oldstak=stakbot; stakbot=staktop=round(argp,BYTESPERWORD);
+	oldstak=stakbot; stakbot=staktop=(STKPTR)round(argp,BYTESPERWORD);
@@ -58,2 +56 @@
-VOID	tdystak(x)
-	REG STKPTR 	x;
+VOID	tdystak(REG STKPTR x)
@@ -67 +64,2 @@
-	rmtemp(x);
+	rmtemp((IOPTR)x);
+	return(0);
@@ -70 +68 @@
-stakchk()
+INT stakchk(void)
@@ -74,0 +73 @@
+	return(0);
@@ -77,2 +76 @@
-STKPTR	cpystak(x)
-	STKPTR		x;
+STKPTR	cpystak(STKPTR x)

% usr/src/cmd/sh/stak.h

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
@@ -12,0 +13,3 @@
+extern int read(int fd, char *buf, int n);
+extern int close(int fd);
+LOCAL	INT readb(void);
@@ -17 +20 @@
-word()
+INT word(void)
@@ -20,0 +24 @@
+	REG ARGPTR	arg;
@@ -42,2 +46,2 @@
-		argp=endstak(argp);
-		IF !letter(argp->argval[0]) THEN wdset=0 FI
+		arg=(ARGPTR)endstak(argp);
+		IF !letter(arg->argval[0]) THEN wdset=0 FI
@@ -46 +50 @@
-		IF argp->argval[1]==0 ANDF (d=argp->argval[0], digit(d)) ANDF (c=='>' ORF c=='<')
+		IF arg->argval[1]==0 ANDF (d=arg->argval[0], digit(d)) ANDF (c=='>' ORF c=='<')
@@ -49,2 +53,2 @@
-			IF reserv==FALSE ORF (wdval=syslook(argp->argval,reserved))==0
-			THEN	wdarg=argp; wdval=0;
+			IF reserv==FALSE ORF (wdval=syslook(arg->argval,reserved))==0
+			THEN	wdarg=arg; wdval=0;
@@ -70,2 +74,2 @@
-nextc(quote)
-	CHAR		quote;
+int
+nextc(int quote)
@@ -85 +89 @@
-readc()
+INT readc(void)
@@ -116 +120 @@
-LOCAL	readb()
+LOCAL	INT readb(void)

% usr/src/cmd/sh/xec.c
@@ -12,0 +13,9 @@
+extern int chdir(char *p);
+extern int signal();
+extern int times(long *t);
+extern int umask(int m);
+extern int fork(void);
+extern int alarm(unsigned sec);
+extern int pause(void);
+extern int close(int fd);
+extern int dup();
@@ -15 +24 @@
-SYSTAB		commands;
+extern SYSTAB	commands;
@@ -22,3 +31 @@
-execute(argt, execflg, pf1, pf2)
-	TREPTR		argt;
-	INT		*pf1, *pf2;
+INT execute(TREPTR argt, INT execflg, INT *pf1, INT *pf2)
@@ -35 +42 @@
-		REG STRING	*com;
+		REG STRING	*com = 0;
@@ -43,0 +51 @@
+			COMPTR		c=(COMPTR)t;
@@ -47 +55 @@
-			IOPTR		io=t->treio;
+			IOPTR		io=c->comio;
@@ -49 +57 @@
-			argn = getarg(t);
+			argn = getarg(c);
@@ -53,2 +61,2 @@
-			IF (internal=syslook(com[0],commands)) ORF argn==0
-			THEN	setlist(t->comset, 0);
+			IF ((internal=syslook(com[0],commands)) ORF argn==0)
+			THEN	setlist(c->comset, 0);
@@ -88 +96 @@
-	
+					/* fallthrough */
@@ -136 +144 @@
-	
+					/* fallthrough */
@@ -140 +148 @@
-	
+					/* fallthrough */
@@ -178 +186 @@
-					ELIF t->comset==0
+					ELIF c->comset==0
@@ -185,0 +194 @@
+					/* fallthrough */
@@ -199 +208 @@
-					THEN	execexp(a1,&com[2]);
+					THEN	execexp(a1,(UFD)(long)&com[2]);
@@ -205 +214 @@
-                                                int c, i
+						int c, i;
@@ -222 +231 @@
-					internal=builtin(argn,com);
+					internal=builtin(); (void)argn;
@@ -231 +240 @@
-			ELIF t->treio==0
+			ELIF c->comio==0
@@ -235 +244 @@
-	
+			/* fallthrough */
@@ -292 +301 @@
-				THEN	execute(t->forktre,1);
+				THEN	execute(((FORKPTR)t)->forktre,1,(INT *)0,(INT *)0);
@@ -294 +303 @@
-				THEN	setlist(t->comset,N_EXPORT);
+				THEN	setlist(((COMPTR)t)->comset,N_EXPORT);
@@ -298,0 +308 @@
+			break;
@@ -302 +312 @@
-			execute(t->partre,execflg);
+			execute(((PARPTR)t)->partre,execflg,(INT *)0,(INT *)0);
@@ -303,0 +314 @@
+			/* fallthrough */
@@ -306,0 +318 @@
+			   REG LSTPTR	l=(LSTPTR)t;
@@ -308,2 +320,2 @@
-			   IF execute(t->lstlef, 0, pf1, pv)==0
-			   THEN	execute(t->lstrit, execflg, pv, pf2);
+			   IF execute(l->lstlef, 0, pf1, pv)==0
+			   THEN	execute(l->lstrit, execflg, pv, pf2);
@@ -316,2 +328,2 @@
-			execute(t->lstlef,0);
-			execute(t->lstrit,execflg);
+			execute(((LSTPTR)t)->lstlef,0,(INT *)0,(INT *)0);
+			execute(((LSTPTR)t)->lstrit,execflg,(INT *)0,(INT *)0);
@@ -321,2 +333,2 @@
-			IF execute(t->lstlef,0)==0
-			THEN	execute(t->lstrit,execflg);
+			IF execute(((LSTPTR)t)->lstlef,0,(INT *)0,(INT *)0)==0
+			THEN	execute(((LSTPTR)t)->lstrit,execflg,(INT *)0,(INT *)0);
@@ -327,2 +339,2 @@
-			IF execute(t->lstlef,0)!=0
-			THEN	execute(t->lstrit,execflg);
+			IF execute(((LSTPTR)t)->lstlef,0,(INT *)0,(INT *)0)!=0
+			THEN	execute(((LSTPTR)t)->lstrit,execflg,(INT *)0,(INT *)0);
@@ -334 +346,2 @@
-			   NAMPTR	n = lookup(t->fornam);
+			   REG FORPTR	f=(FORPTR)t;
+			   NAMPTR	n = lookup(f->fornam);
@@ -338 +351 @@
-			   IF t->forlst==0
+			   IF f->forlst==0
@@ -343 +356 @@
-				   trim((args=scan(getarg(t->forlst)))[0]);
+				   trim((args=scan(getarg(f->forlst)))[0]);
@@ -349,2 +362,2 @@
-				execute(t->fortre,0);
-				IF execbrk<0 THEN execbrk=0 FI
+				execute(f->fortre,0,(INT *)0,(INT *)0);
+				IF (signed char)execbrk<0 THEN execbrk=0 FI
@@ -360,0 +374 @@
+			   REG WHPTR	w=(WHPTR)t;
@@ -364,3 +378,3 @@
-			   WHILE execbrk==0 ANDF (execute(t->whtre,0)==0)==(type==TWH)
-			   DO i=execute(t->dotre,0);
-			      IF execbrk<0 THEN execbrk=0 FI
+			   WHILE execbrk==0 ANDF (execute(w->whtre,0,(INT *)0,(INT *)0)==0)==(type==TWH)
+			   DO i=execute(w->dotre,0,(INT *)0,(INT *)0);
+			      IF (signed char)execbrk<0 THEN execbrk=0 FI
@@ -374,3 +388,3 @@
-			IF execute(t->iftre,0)==0
-			THEN	execute(t->thtre,execflg);
-			ELSE	execute(t->eltre,execflg);
+			IF execute(((IFPTR)t)->iftre,0,(INT *)0,(INT *)0)==0
+			THEN	execute(((IFPTR)t)->thtre,execflg,(INT *)0,(INT *)0);
+			ELSE	execute(((IFPTR)t)->eltre,execflg,(INT *)0,(INT *)0);
@@ -382,2 +396,3 @@
-			   REG STRING	r = mactrim(t->swarg);
-			   t=t->swlst;
+			   REG SWPTR	s=(SWPTR)t;
+			   REG STRING	r = mactrim(s->swarg);
+			   t=(TREPTR)s->swlst;
@@ -385 +400,2 @@
-			   DO	ARGPTR		rex=t->regptr;
+			   DO	REG REGPTR	re=(REGPTR)t;
+				ARGPTR		rex=re->regptr;
@@ -389 +405 @@
-					THEN	execute(t->regcom,0);
+					THEN	execute(re->regcom,0,(INT *)0,(INT *)0);
@@ -394 +410 @@
-				IF t THEN t=t->regnxt FI
+				IF t THEN t=(TREPTR)re->regnxt FI
@@ -408,3 +424,2 @@
-execexp(s,f)
-	STRING		s;
-	UFD		f;
+void
+execexp(STRING s, UFD f)
@@ -415 +430 @@
-	THEN	estabf(s); fb.feval=f;
+	THEN	estabf(s); fb.feval=(STRING *)(long)f;
@@ -419 +434 @@
-	execute(cmd(NL, NLFLG|MTFLG),0);
+	execute(cmd(NL, NLFLG|MTFLG),0,(INT *)0,(INT *)0);

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
@@ -24,4 +25,4 @@
-int	cmp(), cmpa();
-int	(*compare)() = cmpa;
-char	*eol();
-int	term();
+int	cmp(char *i, char *j), cmpa(register char *pa, register char *pb);
+int	(*compare)(char *, char *) = cmpa;
+char	*eol(register char *p);
+int	term(void);
@@ -160,3 +161,3 @@
-	0,0,
-	0,-1,
-	0,0
+	{0,0},
+	{0,-1},
+	{0,0}
@@ -166,3 +167,20 @@
-char	*setfil();
-char	*sbrk();
-char	*brk();
+char	*setfil(int i);
+char	*sbrk(int);
+char	*brk(char *);
+struct	merg;
+int	copyproto(void);
+int	field(char *s, int k);
+int	diag(char *s, char *t);
+int	safeoutfil(void);
+int	sort(void);
+int	newfile(void);
+int	merge(int a, int b);
+int	oldfile(void);
+int	cant(char *f);
+int	rline(struct merg *mp);
+int	disorder(char *s, char *t);
+int	term(void);
+int	digit(int c);
+int	blank(int c);
+int	number(char **ppa);
+int	qsort(char **a, char **l);
@@ -170,2 +188,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -173 +191 @@
-	register a;
+	register int a;
@@ -239,0 +258 @@
+	ep = (char *)lspace + MEM;
@@ -245 +264 @@
-	nlines /= (5*(sizeof(char *)/sizeof(char)));
+	nlines /= (5*(sizeof(char *)));
@@ -262 +281 @@
-	signal(SIGHUP, term);
+	signal(SIGHUP, (int)term);
@@ -264,3 +283,3 @@
-		signal(SIGINT, term);
-	signal(SIGPIPE,term);
-	signal(SIGTERM,term);
+		signal(SIGINT, (int)term);
+	signal(SIGPIPE,(int)term);
+	signal(SIGTERM,(int)term);
@@ -272 +291 @@
-	for(a = mflg|cflg?0:eargc; a+N<nfiles || unsafeout&&a<eargc; a=i) {
+	for(a = (mflg|cflg)?0:eargc; a+N<nfiles || (unsafeout&&a<eargc); a=i) {
@@ -284,0 +304 @@
+	return(0);
@@ -287 +307,2 @@
-sort()
+int
+sort(void)
@@ -291 +312 @@
-	register c;
+	register int c;
@@ -341,0 +363 @@
+	return(0);
@@ -350 +372,2 @@
-merge(a,b)
+int
+merge(int a, int b)
@@ -354 +377 @@
-	register	i;
+	register int	i;
@@ -392 +415 @@
-	muflg = mflg & uflg | cflg;
+	muflg = (mflg & uflg) | cflg;
@@ -433,2 +456,2 @@
-	}
-	p = (struct merg *)lspace;
+		}
+		p = (struct merg *)lspace;
@@ -441,0 +465 @@
+	return(0);
@@ -444,2 +468,2 @@
-rline(mp)
-struct merg *mp;
+int
+rline(struct merg *mp)
@@ -450 +474 @@
-	register c;
+	register int c;
@@ -466,2 +490,2 @@
-disorder(s,t)
-char *s, *t;
+int
+disorder(char *s, char *t)
@@ -473,0 +498 @@
+	return(0);
@@ -476 +501,2 @@
-newfile()
+int
+newfile(void)
@@ -485,0 +512 @@
+	return(0);
@@ -489 +516 @@
-setfil(i)
+setfil(int i)
@@ -492 +519 @@
-	if(i < eargc)
+	if(i < eargc) {
@@ -496,0 +524 @@
+	}
@@ -503 +531,2 @@
-oldfile()
+int
+oldfile(void)
@@ -512,0 +542 @@
+	return(0);
@@ -515 +545,2 @@
-safeoutfil()
+int
+safeoutfil(void)
@@ -521 +552 @@
-		return;
+		return(0);
@@ -523 +554 @@
-		return;
+		return(0);
@@ -530,0 +562 @@
+	return(0);
@@ -533,2 +565,2 @@
-cant(f)
-char *f;
+int
+cant(char *f)
@@ -538,0 +571 @@
+	return(0);
@@ -541,2 +574,2 @@
-diag(s,t)
-char *s, *t;
+int
+diag(char *s, char *t)
@@ -547,0 +581 @@
+	return(0);
@@ -550 +584,2 @@
-term()
+int
+term(void)
@@ -552 +587 @@
-	register i;
+	register int i;
@@ -562,0 +598 @@
+	return(0);
@@ -565,2 +601,2 @@
-cmp(i, j)
-char *i, *j;
+int
+cmp(char *i, char *j)
@@ -569 +605 @@
-	char *skip();
+	char *skip(char *pp, struct field *fp, int j);
@@ -606,2 +642,2 @@
-			for(ipa = pa; ipa<la&&isdigit(*ipa); ipa++) ;
-			for(ipb = pb; ipb<lb&&isdigit(*ipb); ipb++) ;
+			for(ipa = pa; ipa<la&&digit(*ipa); ipa++) ;
+			for(ipb = pb; ipb<lb&&digit(*ipb); ipb++) ;
@@ -613 +649 @@
-					if(b = *--ipb - *--ipa)
+					if((b = *--ipb - *--ipa))
@@ -627,3 +663,3 @@
-				while(pa<la && isdigit(*pa)
-				   && pb<lb && isdigit(*pb))
-					if(a = *pb++ - *pa++)
+				while(pa<la && digit(*pa)
+				   && pb<lb && digit(*pb))
+					if((a = *pb++ - *pa++))
@@ -631 +667 @@
-			while(pa<la && isdigit(*pa))
+			while(pa<la && digit(*pa))
@@ -634 +670 @@
-			while(pb<lb && isdigit(*pb))
+			while(pb<lb && digit(*pb))
@@ -642 +678 @@
-		while(ignore[*pa])
+		while(ignore[(signed char)*pa])
@@ -644 +680 @@
-		while(ignore[*pb])
+		while(ignore[(signed char)*pb])
@@ -646 +682 @@
-		if(pa>=la || *pa=='\n')
+		if(pa>=la || *pa=='\n') {
@@ -649,0 +686 @@
+		}
@@ -652 +689 @@
-		if((sa = code[*pb++]-code[*pa++]) == 0)
+		if((sa = code[(signed char)*pb++]-code[(signed char)*pa++]) == 0)
@@ -661,2 +698,2 @@
-cmpa(pa, pb)
-register char *pa, *pb;
+int
+cmpa(register char *pa, register char *pb)
@@ -678,3 +715 @@
-skip(pp, fp, j)
-struct field *fp;
-char *pp;
+skip(char *pp, struct field *fp, int j)
@@ -682 +717 @@
-	register i;
+	register int i;
@@ -718,2 +753 @@
-eol(p)
-register char *p;
+eol(register char *p)
@@ -725 +759,2 @@
-copyproto()
+int
+copyproto(void)
@@ -727 +762 @@
-	register i;
+	register int i;
@@ -732 +767 @@
-	for(i=0; i<sizeof(proto)/sizeof(*p); i++)
+	for(i=0; i<(int)(sizeof(proto)/sizeof(*p)); i++)
@@ -733,0 +769 @@
+	return(0);
@@ -736,2 +772,2 @@
-field(s,k)
-char *s;
+int
+field(char *s, int k)
@@ -740 +776 @@
-	register d;
+	register int d;
@@ -746 +782 @@
-			return;
+			return(0);
@@ -790,0 +827 @@
+			/* fallthrough */
@@ -795,0 +833 @@
+	return(0);
@@ -798,2 +836,2 @@
-number(ppa)
-char **ppa;
+int
+number(char **ppa)
@@ -805 +843 @@
-	while(isdigit(*pa)) {
+	while(digit(*pa)) {
@@ -812 +850,9 @@
-blank(c)
+int
+digit(int c)
+{
+	if(c >= '0' && c <= '9')
+		return(1);
+	return(0);
+}
+int
+blank(int c)
@@ -822,2 +868,2 @@
-qsort(a,l)
-char **a, **l;
+int
+qsort(char **a, char **l)
@@ -836 +882 @@
-		return;
+		return(0);
@@ -896,5 +942,4 @@
-		--lp;
-		qstexc(j, lp, i);
-		j = --hp;
-	}
-}
+			--lp;
+			qstexc(j, lp, i);
+			j = --hp;
+		}
@@ -901,0 +947 @@
+	}

% usr/src/cmd/sp.c
@@ -11 +11,5 @@
-getit()
+int	getit(void);
+int	putit(int ntab);
+int	clean(void);
+int
+getit(void)
@@ -13 +17 @@
-	register c;
+	register int c;
@@ -19,0 +24 @@
+				/* fallthrough */
@@ -34 +39,2 @@
-putit(ntab)
+int
+putit(int ntab)
@@ -37,0 +44 @@
+	return(0);
@@ -39 +46,2 @@
-clean()
+int
+clean(void)
@@ -41,0 +50 @@
+	return(0);
@@ -43 +52,2 @@
-main(argc,argv) char *argv[];
+int
+main(int argc, char *argv[])

% usr/src/cmd/spline.c
@@ -141 +141,2 @@
-rhs(i){
+rhs(int i)
+{
@@ -149 +150,2 @@
-spline(){
+int
+spline(void){
@@ -205 +207 @@
-		for(j=m;j>0||i==0&&j==0;j--){	/* interpolate */
+		for(j=m;j>0||(i==0&&j==0);j--){	/* interpolate */
@@ -216 +218,4 @@
-readin() {
+int	getfloat(float *p), numb(float *np, int *argcp, char ***argvp);
+int	getlim(struct proj *p);
+int
+readin(void) {
@@ -220 +225 @@
-		if(!getfloat(&y.val[n])) break; } }
+		if(!getfloat(&y.val[n])) break; } return(0); }
@@ -222,2 +227,3 @@
-getfloat(p)
-	float *p;{
+int
+getfloat(float *p)
+{
@@ -225 +231 @@
-	register c;
+	register int c;
@@ -227 +233 @@
-	extern double atof();
+	extern double atof(char *s);
@@ -261,2 +267,2 @@
-getlim(p)
-	struct proj *p; {
+int
+getlim(struct proj *p) {
@@ -267 +273 @@
-	}
+	return(0); }
@@ -270,3 +276,4 @@
-main(argc,argv)
-	char *argv[];{
-	extern char *malloc();
+int
+main(int argc, char *argv[])
+{
+	extern char *malloc(unsigned n);
@@ -320,5 +327,4 @@
-numb(np,argcp,argvp)
-	int *argcp;
-	float *np;
-	char ***argvp;{
-	double atof();
+int
+numb(float *np, int *argcp, char ***argvp)
+{
+	double atof(char *s);
@@ -328 +334 @@
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
+	{ "0",	B0 },
+	{ "50",	B50 },
+	{ "75",	B75 },
+	{ "110",	B110 },
+	{ "134",	B134 },
+	{ "134.5",B134 },
+	{ "150",	B150 },
+	{ "200",	B200 },
+	{ "300",	B300 },
+	{ "600",	B600 },
+	{ "1200",	B1200 },
+	{ "1800",	B1800 },
+	{ "2400",	B2400 },
+	{ "4800",	B4800 },
+	{ "9600",	B9600 },
+	{ "exta",	EXTA },
+	{ "extb",	EXTB },
+	{ 0,	0 },
@@ -38,2 +38 @@
-	"even",
-	EVENP, 0,
+	{ "even",	EVENP, 0 },
@@ -41,2 +40 @@
-	"-even",
-	0, EVENP,
+	{ "-even",	0, EVENP },
@@ -44,2 +42 @@
-	"odd",
-	ODDP, 0,
+	{ "odd",	ODDP, 0 },
@@ -47,2 +44 @@
-	"-odd",
-	0, ODDP,
+	{ "-odd",	0, ODDP },
@@ -50,2 +46 @@
-	"raw",
-	RAW, 0,
+	{ "raw",	RAW, 0 },
@@ -53,2 +48 @@
-	"-raw",
-	0, RAW,
+	{ "-raw",	0, RAW },
@@ -56,2 +50 @@
-	"cooked",
-	0, RAW,
+	{ "cooked",	0, RAW },
@@ -59,2 +52 @@
-	"-nl",
-	CRMOD, 0,
+	{ "-nl",	CRMOD, 0 },
@@ -62,2 +54 @@
-	"nl",
-	0, CRMOD,
+	{ "nl",		0, CRMOD },
@@ -65,2 +56 @@
-	"echo",
-	ECHO, 0,
+	{ "echo",	ECHO, 0 },
@@ -68,2 +58 @@
-	"-echo",
-	0, ECHO,
+	{ "-echo",	0, ECHO },
@@ -71,2 +60 @@
-	"LCASE",
-	LCASE, 0,
+	{ "LCASE",	LCASE, 0 },
@@ -74,2 +62 @@
-	"lcase",
-	LCASE, 0,
+	{ "lcase",	LCASE, 0 },
@@ -77,2 +64 @@
-	"-LCASE",
-	0, LCASE,
+	{ "-LCASE",	0, LCASE },
@@ -80,2 +66 @@
-	"-lcase",
-	0, LCASE,
+	{ "-lcase",	0, LCASE },
@@ -83,2 +68 @@
-	"-tabs",
-	XTABS, 0,
+	{ "-tabs",	XTABS, 0 },
@@ -86,2 +70 @@
-	"tabs",
-	0, XTABS,
+	{ "tabs",	0, XTABS },
@@ -90,2 +73 @@
-	"cbreak",
-	CBREAK, 0,
+	{ "cbreak",	CBREAK, 0 },
@@ -93,2 +75 @@
-	"-cbreak",
-	0, CBREAK,
+	{ "-cbreak",	0, CBREAK },
@@ -96,2 +77 @@
-	"cr0",
-	CR0, CR3,
+	{ "cr0",	CR0, CR3 },
@@ -99,2 +79 @@
-	"cr1",
-	CR1, CR3,
+	{ "cr1",	CR1, CR3 },
@@ -102,2 +81 @@
-	"cr2",
-	CR2, CR3,
+	{ "cr2",	CR2, CR3 },
@@ -105,2 +83 @@
-	"cr3",
-	CR3, CR3,
+	{ "cr3",	CR3, CR3 },
@@ -108,2 +85 @@
-	"tab0",
-	TAB0, XTABS,
+	{ "tab0",	TAB0, XTABS },
@@ -111,2 +87 @@
-	"tab1",
-	TAB1, XTABS,
+	{ "tab1",	TAB1, XTABS },
@@ -114,2 +89 @@
-	"tab2",
-	TAB2, XTABS,
+	{ "tab2",	TAB2, XTABS },
@@ -117,2 +91 @@
-	"nl0",
-	NL0, NL3,
+	{ "nl0",	NL0, NL3 },
@@ -120,2 +93 @@
-	"nl1",
-	NL1, NL3,
+	{ "nl1",	NL1, NL3 },
@@ -123,2 +95 @@
-	"nl2",
-	NL2, NL3,
+	{ "nl2",	NL2, NL3 },
@@ -126,2 +97 @@
-	"nl3",
-	NL3, NL3,
+	{ "nl3",	NL3, NL3 },
@@ -129,2 +99 @@
-	"ff0",
-	FF0, FF1,
+	{ "ff0",	FF0, FF1 },
@@ -132,2 +101 @@
-	"ff1",
-	FF1, FF1,
+	{ "ff1",	FF1, FF1 },
@@ -135,2 +103 @@
-	"bs0",
-	BS0, BS1,
+	{ "bs0",	BS0, BS1 },
@@ -138,2 +105 @@
-	"bs1",
-	BS1, BS1,
+	{ "bs1",	BS1, BS1 },
@@ -141,2 +107 @@
-	"33",
-	CR1, ALLDELAY,
+	{ "33",		CR1, ALLDELAY },
@@ -144,2 +109 @@
-	"tty33",
-	CR1, ALLDELAY,
+	{ "tty33",	CR1, ALLDELAY },
@@ -147,2 +111 @@
-	"37",
-	FF1+CR2+TAB1+NL1, ALLDELAY,
+	{ "37",		FF1+CR2+TAB1+NL1, ALLDELAY },
@@ -150,2 +113 @@
-	"tty37",
-	FF1+CR2+TAB1+NL1, ALLDELAY,
+	{ "tty37",	FF1+CR2+TAB1+NL1, ALLDELAY },
@@ -153,2 +115 @@
-	"05",
-	NL2, ALLDELAY,
+	{ "05",		NL2, ALLDELAY },
@@ -156,2 +117 @@
-	"vt05",
-	NL2, ALLDELAY,
+	{ "vt05",	NL2, ALLDELAY },
@@ -159,2 +119 @@
-	"tn",
-	CR1, ALLDELAY,
+	{ "tn",		CR1, ALLDELAY },
@@ -162,2 +121 @@
-	"tn300",
-	CR1, ALLDELAY,
+	{ "tn300",	CR1, ALLDELAY },
@@ -165,2 +123 @@
-	"ti",
-	CR2, ALLDELAY,
+	{ "ti",		CR2, ALLDELAY },
@@ -168,2 +125 @@
-	"ti700",
-	CR2, ALLDELAY,
+	{ "ti700",	CR2, ALLDELAY },
@@ -171,2 +127 @@
-	"tek",
-	FF1, ALLDELAY,
+	{ "tek",	FF1, ALLDELAY },
@@ -174,2 +129,2 @@
-	0,
-	};
+	{ 0,		0, 0 },
+};
@@ -180,2 +135,6 @@
-main(argc, argv)
-char	*argv[];
+int	eq(char *string);
+void	prmodes(void);
+void	delay(int m, char *s);
+void	prspeed(char *c, int s);
+int
+main(int argc, char *argv[])
@@ -232,2 +191,2 @@
-eq(string)
-char *string;
+int
+eq(char *string)
@@ -249 +208,2 @@
-prmodes()
+void
+prmodes(void)
@@ -251 +211 @@
-	register m;
+	register int m;
@@ -258 +218 @@
-	if (mode.sg_erase < ' ')
+	if ((mode.sg_erase&0377) < ' ')
@@ -262 +222 @@
-	if (mode.sg_kill < ' ')
+	if ((mode.sg_kill&0377) < ' ')
@@ -284,2 +244,2 @@
-delay(m, s)
-char *s;
+void
+delay(int m, char *s)
@@ -296,2 +256,2 @@
-prspeed(c, s)
-char *c;
+void
+prspeed(char *c, int s)

% usr/src/cmd/su.c
@@ -4,3 +4 @@
-struct	passwd *pwd,*getpwnam();
-char	*crypt();
-char	*getpass();
+struct	passwd *pwd;
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
+main(int argc, char *argv[])
@@ -11 +11 @@
-	register i, c;
+	register int i, c;

% usr/src/cmd/sync.c
@@ -1 +1,3 @@
-main()
+void sync(void);
+int
+main(void)

% usr/src/cmd/tabs.c
@@ -44,0 +45,14 @@
+int	syslook(char *w);
+void	clear(int n);
+void	delay(int n);
+void	tabs(int n);
+void	margin(int n);
+void	escape(int c);
+void	bs(int n);
+void	nl(void);
+void	dasi450(void);
+void	tty37(void);
+void	dasi300(void);
+void	tn300(void);
+void	hp2645(void);
+void	misc(void);
@@ -46,2 +60,2 @@
-syslook(w)
-char *w;
+int
+syslook(char *w)
@@ -57,2 +71,2 @@
-main(argc,argv)
-int argc; char **argv;
+int
+main(int argc, char **argv)
@@ -99 +113,2 @@
-clear(n)
+void
+clear(int n)
@@ -106 +121,2 @@
-delay(n)
+void
+delay(int n)
@@ -111 +127,2 @@
-tabs(n)
+void
+tabs(int n)
@@ -125 +142,2 @@
-margin(n)
+void
+margin(int n)
@@ -134 +152,2 @@
-escape(c)
+void
+escape(int c)
@@ -139 +158,2 @@
-bs(n)
+void
+bs(int n)
@@ -144 +164,2 @@
-nl()
+void
+nl(void)
@@ -153 +174,2 @@
-dasi450()
+void
+dasi450(void)
@@ -163 +185,2 @@
-tty37()
+void
+tty37(void)
@@ -168 +191,2 @@
-dasi300()
+void
+dasi300(void)
@@ -173 +197,2 @@
-tn300()
+void
+tn300(void)
@@ -183 +208,2 @@
-hp2645()
+void
+hp2645(void)
@@ -191 +217,2 @@
-misc()
+void
+misc(void)

% usr/src/cmd/tail.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -18 +19 @@
-int errno;
+extern int errno;
@@ -20,2 +21,3 @@
-main(argc,argv)
-char **argv;
+int digit(int c);
+int
+main(int argc, char *argv[])
@@ -24,2 +26,2 @@
-	register i,j,k;
-	char *p;
+	register int i,j,k;
+	char *p = 0;
@@ -31 +33 @@
-	if(argc<=1 || *arg!='-'&&*arg!='+') {
+	if(argc<=1 || (*arg!='-' && *arg!='+')) {
@@ -181 +183,2 @@
-digit(c)
+int
+digit(int c)

% usr/src/cmd/tar/tar.c
@@ -7,2 +6,0 @@
-char	*sprintf();
-char	*strcat();
@@ -9,0 +8,6 @@
+int	usage(), done(), dorep(), doxtract(), dotable(), getdir(),
+	passtape(), endtape(), getwdir(), putfile(), putempty(),
+	flushtape(), readtape(), writetape(), backtape(), longt(),
+	pmode(), select(), checkdir(), onintr(), onquit(), onhup(),
+	onterm(), tomodes(), checksum(), checkw(), response(),
+	checkupdate(), prefix(), cmp(), copy();
@@ -55,3 +59,2 @@
-main(argc, argv)
-int	argc;
-char	*argv[];
+int
+main(int argc, char *argv[])
@@ -140,6 +143,6 @@
-		if (signal(SIGINT, SIG_IGN) != SIG_IGN)
-			signal(SIGINT, onintr);
-		if (signal(SIGHUP, SIG_IGN) != SIG_IGN)
-			signal(SIGHUP, onhup);
-		if (signal(SIGQUIT, SIG_IGN) != SIG_IGN)
-			signal(SIGQUIT, onquit);
+		if (signal(SIGINT, (int)SIG_IGN) != (int)SIG_IGN)
+			signal(SIGINT, (int)onintr);
+		if (signal(SIGHUP, (int)SIG_IGN) != (int)SIG_IGN)
+			signal(SIGHUP, (int)onhup);
+		if (signal(SIGQUIT, (int)SIG_IGN) != (int)SIG_IGN)
+			signal(SIGQUIT, (int)onquit);
@@ -195 +198,2 @@
-usage()
+int
+usage(void)
@@ -198,0 +203 @@
+	return(0);
@@ -201,2 +206,2 @@
-dorep(argv)
-char	*argv[];
+int
+dorep(char *argv[])
@@ -253,0 +259 @@
+	return(0);
@@ -256 +262,2 @@
-endtape()
+int
+endtape(void)
@@ -266 +273,2 @@
-getdir()
+int
+getdir(void)
@@ -273 +281 @@
-		return;
+		return(0);
@@ -289,0 +298 @@
+	return(0);
@@ -292 +301,2 @@
-passtape()
+int
+passtape(void)
@@ -298 +308 @@
-		return;
+		return(0);
@@ -304,0 +315 @@
+	return(0);
@@ -307,3 +318,2 @@
-putfile(longname, shortname)
-char *longname;
-char *shortname;
+int
+putfile(char *longname, char *shortname)
@@ -321 +331 @@
-		return;
+		return(0);
@@ -328 +338 @@
-		return;
+		return(0);
@@ -332 +342 @@
-		return;
+		return(0);
@@ -336 +346,2 @@
-		for (i = 0, cp = buf; *cp++ = longname[i++];);
+		for (i = 0, cp = buf; (*cp++ = longname[i++]);)
+			;
@@ -362 +373 @@
-		return;
+		return(0);
@@ -366 +377 @@
-		return;
+		return(0);
@@ -376 +387 @@
-		return;
+		return(0);
@@ -400 +411 @@
-			return;
+			return(0);
@@ -437,0 +449 @@
+	return(0);
@@ -442,2 +454,2 @@
-doxtract(argv)
-char	*argv[];
+int
+doxtract(char *argv[])
@@ -515,0 +528 @@
+	return(0);
@@ -518 +531,2 @@
-dotable()
+int
+dotable(void)
@@ -531,0 +546 @@
+	return(0);
@@ -534 +549,2 @@
-putempty()
+int
+putempty(void)
@@ -541,0 +558 @@
+	return(0);
@@ -544,2 +561,2 @@
-longt(st)
-register struct stat *st;
+int
+longt(register struct stat *st)
@@ -554,0 +572 @@
+	return(0);
@@ -581,2 +599,2 @@
-pmode(st)
-register struct stat *st;
+int
+pmode(register struct stat *st)
@@ -587,0 +606 @@
+	return(0);
@@ -590,3 +609,2 @@
-select(pairp, st)
-int *pairp;
-struct stat *st;
+int
+select(int *pairp, struct stat *st)
@@ -600,0 +619 @@
+	return(0);
@@ -603,2 +622,2 @@
-checkdir(name)
-register char *name;
+int
+checkdir(register char *name)
@@ -623,0 +643 @@
+	return(0);
@@ -626 +646,2 @@
-onintr()
+int
+onintr(int sig)
@@ -628 +649,2 @@
-	signal(SIGINT, SIG_IGN);
+	(void)sig;
+	signal(SIGINT, (int)SIG_IGN);
@@ -629,0 +652 @@
+	return(0);
@@ -632 +655,2 @@
-onquit()
+int
+onquit(int sig)
@@ -634 +658,2 @@
-	signal(SIGQUIT, SIG_IGN);
+	(void)sig;
+	signal(SIGQUIT, (int)SIG_IGN);
@@ -635,0 +661 @@
+	return(0);
@@ -638 +664,2 @@
-onhup()
+int
+onhup(int sig)
@@ -640 +667,2 @@
-	signal(SIGHUP, SIG_IGN);
+	(void)sig;
+	signal(SIGHUP, (int)SIG_IGN);
@@ -641,0 +670 @@
+	return(0);
@@ -644 +673,2 @@
-onterm()
+int
+onterm(int sig)
@@ -646 +676,2 @@
-	signal(SIGTERM, SIG_IGN);
+	(void)sig;
+	signal(SIGTERM, (int)SIG_IGN);
@@ -647,0 +679 @@
+	return(0);
@@ -650,2 +682,2 @@
-tomodes(sp)
-register struct stat *sp;
+int
+tomodes(register struct stat *sp)
@@ -661,0 +694 @@
+	return(0);
@@ -664 +697,2 @@
-checksum()
+int
+checksum(void)
@@ -666 +700 @@
-	register i;
+	register int i;
@@ -673 +707 @@
-		i += *cp;
+		i += (signed char)*cp;
@@ -677,2 +711,2 @@
-checkw(c, name)
-char *name;
+int
+checkw(int c, char *name)
@@ -693 +727,2 @@
-response()
+int
+response(void)
@@ -704,2 +739,2 @@
-checkupdate(arg)
-char	*arg;
+int
+checkupdate(char *arg)
@@ -710 +745 @@
-	daddr_t	lookup();
+	daddr_t	lookup(char *s);
@@ -725 +760,2 @@
-done(n)
+int
+done(int n)
@@ -728,0 +765 @@
+	return(0);
@@ -731,2 +768,2 @@
-prefix(s1, s2)
-register char *s1, *s2;
+int
+prefix(register char *s1, register char *s2)
@@ -742,2 +779,2 @@
-getwdir(s)
-char *s;
+int
+getwdir(char *s)
@@ -765,0 +803 @@
+	return(0);
@@ -771,2 +809 @@
-lookup(s)
-char *s;
+lookup(char *s)
@@ -774 +811 @@
-	register i;
+	register int i;
@@ -785,3 +822 @@
-bsrch(s, n, l, h)
-daddr_t l, h;
-char *s;
+bsrch(char *s, int n, daddr_t l, daddr_t h)
@@ -789 +824 @@
-	register i, j;
+	register int i, j;
@@ -830,2 +865,2 @@
-cmp(b, s, n)
-char *b, *s;
+int
+cmp(char *b, char *s, int n)
@@ -833 +868 @@
-	register i;
+	register int i;
@@ -846,2 +881,2 @@
-readtape(buffer)
-char *buffer;
+int
+readtape(char *buffer)
@@ -856 +891 @@
-		if ((i = read(mt, tbuf, TBLOCK*j)) < 0) {
+		if ((i = read(mt, (char *)tbuf, TBLOCK*j)) < 0) {
@@ -878 +913 @@
-	copy(buffer, &tbuf[recno++]);
+	copy(buffer, (char *)&tbuf[recno++]);
@@ -882,2 +917,2 @@
-writetape(buffer)
-char *buffer;
+int
+writetape(char *buffer)
@@ -889 +924 @@
-		if (write(mt, tbuf, TBLOCK*nblock) < 0) {
+		if (write(mt, (char *)tbuf, TBLOCK*nblock) < 0) {
@@ -895 +930 @@
-	copy(&tbuf[recno++], buffer);
+	copy((char *)&tbuf[recno++], buffer);
@@ -897 +932 @@
-		if (write(mt, tbuf, TBLOCK*nblock) < 0) {
+		if (write(mt, (char *)tbuf, TBLOCK*nblock) < 0) {
@@ -906 +941,2 @@
-backtape()
+int
+backtape(void)
@@ -911 +947 @@
-		if (read(mt, tbuf, TBLOCK*nblock) < 0) {
+		if (read(mt, (char *)tbuf, TBLOCK*nblock) < 0) {
@@ -916,0 +953 @@
+	return(0);
@@ -919 +956,2 @@
-flushtape()
+int
+flushtape(void)
@@ -921 +959,2 @@
-	write(mt, tbuf, TBLOCK*nblock);
+	write(mt, (char *)tbuf, TBLOCK*nblock);
+	return(0);
@@ -924,2 +963,2 @@
-copy(to, from)
-register char *to, *from;
+int
+copy(register char *to, register char *from)
@@ -927 +966 @@
-	register i;
+	register int i;
@@ -932,0 +972 @@
+	return(0);

% usr/src/cmd/tc.c
@@ -8 +8 @@
-#define	oput(c) if (pgskip==0) putchar(c); else;
+#define	oput(c) do { if (pgskip==0) putchar(c); } while (0)
@@ -57,3 +57,11 @@
-main(argc,argv)
-int argc;
-char **argv;
+int lig(char *x);
+int init(void);
+int ex(void);
+int kwait(void);
+int callunix(char line[]);
+int readch(void);
+int sendpt(void);
+int tcatoi(void);
+int getch(void);
+long tscale(int n);
+int main(int argc, char **argv)
@@ -61 +69 @@
-	register i, j;
+	register int i, j;
@@ -63 +71 @@
-	extern ex();
+	extern int ex(void);
@@ -70 +78 @@
-				if(i = atoi())pl = i/3;
+				if((i = tcatoi()))pl = i/3;
@@ -78 +86 @@
-				pgskip = atoi();
+				pgskip = tcatoi();
@@ -83,2 +91,2 @@
-				if(i = atoi())mpy = i;
-				if(i = atoi())div = i;
+				if((i = tcatoi()))mpy = i;
+				if((i = tcatoi()))div = i;
@@ -94,2 +102,2 @@
-	sigint = signal(SIGINT, ex);
-	sigquit = signal(SIGQUIT, SIG_IGN);
+	sigint = (int(*)())signal(SIGINT, (int)ex);
+	sigquit = (int(*)())signal(SIGQUIT, (int)SIG_IGN);
@@ -226,2 +234 @@
-lig(x)
-char *x;
+int lig(char *x)
@@ -229 +236 @@
-	register i, j;
+	register int i, j;
@@ -245,0 +253 @@
+	return(0);
@@ -247 +255 @@
-init(){
+int init(void){
@@ -261,0 +270 @@
+	return(0);
@@ -263 +272 @@
-ex(){
+int ex(void){
@@ -271,0 +281 @@
+	return(0);
@@ -273 +283 @@
-kwait(){
+int kwait(void){
@@ -275 +285 @@
-	if(pgskip) return;
+	if(pgskip) return(0);
@@ -290 +300 @@
-				pgskip = atoi() + 1;
+				pgskip = tcatoi() + 1;
@@ -298 +308,2 @@
-	else	return;
+	else	return(0);
+	return(0);
@@ -300,2 +311 @@
-callunix(line)
-char line[];
+int callunix(char line[])
@@ -305 +315 @@
-		signal(SIGINT,sigint); signal(SIGQUIT,sigquit);
+		signal(SIGINT,(int)sigint); signal(SIGQUIT,(int)sigquit);
@@ -311,2 +321,2 @@
-		return;
-	else{	signal(SIGINT, SIG_IGN); signal(SIGQUIT, SIG_IGN);
+		return(0);
+	else{	signal(SIGINT, (int)SIG_IGN); signal(SIGQUIT, (int)SIG_IGN);
@@ -314 +324 @@
-		signal(SIGINT,ex); signal(SIGQUIT,sigquit);
+		signal(SIGINT,(int)ex); signal(SIGQUIT,(int)sigquit);
@@ -315,0 +326 @@
+	return(0);
@@ -317 +328 @@
-readch(){
+int readch(void){
@@ -322 +333 @@
-sendpt(){
+int sendpt(void){
@@ -327 +338 @@
-	xb = ((xx & 03) + ((yy<<2) & 014) & 017);
+	xb = (((xx & 03) + ((yy<<2) & 014)) & 017);
@@ -343 +354 @@
-	return;
+	return(0);
@@ -345 +356 @@
-atoi()
+int tcatoi(void)
@@ -347 +358 @@
-	register i, j, acc;
+	register int i, j, acc;
@@ -350 +360,0 @@
-	long tscale();
@@ -376,2 +386 @@
-long tscale(n)
-int n;
+long tscale(int n)
@@ -379 +388 @@
-	register i, j;
+	register int i, j;
@@ -403,2 +412,2 @@
-getch(){
-	register i;
+int getch(void){
+	register int i;
@@ -414 +423 @@
-char *asctab[128] {
+char *asctab[128] = {

% usr/src/cmd/tee.c
@@ -18,2 +18,11 @@
-extern errno;
-long	lseek();
+extern int errno;
+long	lseek(int fd, long offset, int ptrname);
+int	creat(char *path, int mode);
+int	fstat(int fd, struct stat *buf);
+int	open(char *path, int mode);
+int	read(int fd, char *buf, int n);
+int	stat(char *path, struct stat *buf);
+int	write(int fd, char *buf, int n);
+int	signal(int sig, int fun);
+void	stash(int p);
+void	puts(char *s);
@@ -21,2 +30,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -24 +33 @@
-	int register r,w,p;
+	register int r,w,p;
@@ -70 +79 @@
-					return;
+					return(0);
@@ -79 +88,2 @@
-stash(p)
+void
+stash(int p)
@@ -90,2 +100,2 @@
-puts(s)
-char *s;
+void
+puts(char *s)

% usr/src/cmd/test.c
@@ -18,2 +18,12 @@
-main(argc, argv)
-char *argv[];
+char *nxtarg(int mt);
+int exp(void);
+int e1(void);
+int e2(void);
+int e3(void);
+int tio(char *a, int f);
+int ftype(char *f);
+int fsizep(char *f);
+void synbad(char *s1, char *s2);
+int length(char *s);
+int
+main(int argc, char *argv[])
@@ -32 +42 @@
-char *nxtarg(mt) {
+char *nxtarg(int mt) {
@@ -44 +54,2 @@
-exp() {
+int
+exp(void) {
@@ -53 +64,2 @@
-e1() {
+int
+e1(void) {
@@ -62 +74,2 @@
-e2() {
+int
+e2(void) {
@@ -69 +82,2 @@
-e3() {
+int
+e3(void) {
@@ -97 +111 @@
-	if(EQ(a, "-t"))
+	if(EQ(a, "-t")) {
@@ -101,0 +116 @@
+	}
@@ -136,0 +152 @@
+	return(0);
@@ -139,3 +155,2 @@
-tio(a, f)
-char *a;
-int f;
+int
+tio(char *a, int f)
@@ -152,2 +167,2 @@
-ftype(f)
-char *f;
+int
+ftype(char *f)
@@ -164,2 +179,2 @@
-fsizep(f)
-char *f;
+int
+fsizep(char *f)
@@ -173,2 +188,2 @@
-synbad(s1,s2)
-char *s1, *s2;
+void
+synbad(char *s1, char *s2)
@@ -183,2 +198,2 @@
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
+int	init(void), sendpt(int a), kwait(void), execom(void);
+int
+main(int argc, char **argv)
@@ -41,2 +41,2 @@
-	register i, j;
-	extern ex();
+	register int i, j;
+	extern int ex(void);
@@ -47 +47 @@
-				if (i = atoi(&argv[0][2]))
+				if ((i = atoi(&argv[0][2])))
@@ -49 +49 @@
-					yyll = MAXY + 1 - pl;
+				yyll = MAXY + 1 - pl;
@@ -52 +52 @@
-				if (i = atoi(&argv[0][1])) {
+				if ((i = atoi(&argv[0][1]))) {
@@ -67 +67 @@
-	signal(SIGINT, ex);
+	signal(SIGINT, (int)ex);
@@ -75,0 +76 @@
+			/* fallthrough */
@@ -150,0 +152 @@
+	return(0);
@@ -153 +155,2 @@
-init()
+int
+init(void)
@@ -168,0 +172 @@
+	return(0);
@@ -171 +175,2 @@
-ex()
+int
+ex(void)
@@ -177,0 +183 @@
+	return(0);
@@ -180 +186,2 @@
-kwait()
+int
+kwait(void)
@@ -182 +189 @@
-	register c;
+	register int c;
@@ -186 +193 @@
-		return;
+		return(0);
@@ -196,0 +204 @@
+	return(0);
@@ -199 +207,2 @@
-execom()
+int
+execom(void)
@@ -204,2 +213,2 @@
-		si = signal(SIGINT, SIG_IGN);
-		sq = signal(SIGQUIT, SIG_IGN);
+		si = (int (*)())signal(SIGINT, (int)SIG_IGN);
+		sq = (int (*)())signal(SIGQUIT, (int)SIG_IGN);
@@ -207,3 +216,3 @@
-		signal(SIGINT, si);
-		signal(SIGQUIT, sq);
-		return;
+		signal(SIGINT, (int)si);
+		signal(SIGQUIT, (int)sq);
+		return(0);
@@ -215,0 +225 @@
+	return(0);
@@ -218 +228,2 @@
-sendpt(a)
+int
+sendpt(int a)
@@ -220 +231 @@
-	register zz;
+	register int zz;
@@ -224 +235 @@
-		return;
+		return(0);
@@ -228 +239 @@
-	xb = ((xx & 03) + ((zz<<2) & 014) & 017);
+	xb = (((xx & 03) + ((zz<<2) & 014)) & 017);
@@ -247,0 +259 @@
+	return(0);

% usr/src/cmd/touch.c
@@ -2,0 +3 @@
+void touch(int force, char *name);
@@ -4,3 +5,2 @@
-main(argc,argv)
-int argc;
-char *argv[];
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

% usr/src/cmd/tp/tp0.c

% usr/src/cmd/tp/tp1.c
@@ -1,0 +2 @@
+#include <stdio.h>
@@ -3,2 +4,6 @@
-main(argc,argv)
-char **argv;
+int	optap(), setcom(), useerr(), check(), done(), encode(),
+	decode(), cmd(), cmr(), cmt(), cmx(),
+	clrdir(), clrent(), rddir(), gettape(), wrdir(), getfiles(),
+	update(), delete(), taboc(), extract(), usage();
+int
+main(int argc, char **argv)
@@ -7 +12,2 @@
-	extern cmd(), cmr(),cmx(), cmt();
+	extern int cmd(), cmr(),cmx(), cmt();
+	(void)argc;
@@ -15 +21 @@
-		while (c = *ptr++) switch(c)  {
+		while ((c = *ptr++)) switch(c)  {
@@ -62,0 +69 @@
+	return(0);
@@ -65 +72,2 @@
-optap()
+int
+optap(void)
@@ -67 +75 @@
-	extern cmr();
+	extern int cmr();
@@ -86,0 +95 @@
+	return(0);
@@ -89,2 +98,2 @@
-setcom(newcom)
-int (*newcom)();
+int
+setcom(int (*newcom)(void))
@@ -92 +101 @@
-	extern cmr();
+	extern int cmr();
@@ -95,0 +105 @@
+	return(0);
@@ -98 +108,2 @@
-useerr()
+int
+useerr(void)
@@ -101,0 +113 @@
+	return(0);
@@ -104 +116 @@
-/*/* COMMANDS */
+/* COMMANDS */
@@ -106 +118,2 @@
-cmd()
+int
+cmd(void)
@@ -108 +121 @@
-	extern delete();
+	extern int delete(void);
@@ -115,0 +129 @@
+	return(0);
@@ -118 +132,2 @@
-cmr()
+int
+cmr(void)
@@ -124,0 +140 @@
+	return(0);
@@ -127 +143,2 @@
-cmt()
+int
+cmt(void)
@@ -129 +146 @@
-	extern taboc();
+	extern int taboc(struct dent *);
@@ -136,0 +154 @@
+	return(0);
@@ -139 +157,2 @@
-cmx()
+int
+cmx(void)
@@ -141 +160 @@
-	extern extract();
+	extern int extract(struct dent *);
@@ -146,0 +166 @@
+	return(0);
@@ -148,0 +169 @@
+int
@@ -152,0 +174 @@
+	return(0);
@@ -154,0 +177 @@
+int
@@ -158,0 +182 @@
+	return(0);
@@ -160,0 +185 @@
+int
@@ -168 +193 @@
-	register n;
+	register int n;
@@ -185,0 +211 @@
+	return(0);
@@ -187,0 +214 @@
+int
@@ -194,0 +222 @@
+	return(0);

% usr/src/cmd/tp/tp2.c
@@ -6,0 +7,3 @@
+int	rseek(), wseek(), tread(), twrite(), seekerr(), swabdir(),
+	encode(), decode(), done(), bitmap(), fserr(), callout(),
+	expand(), clrent();
@@ -10 +13,2 @@
-clrdir()
+int
+clrdir(void)
@@ -12 +16 @@
-	register j, *p;
+	register int j, *p;
@@ -17,0 +22 @@
+	return(0);
@@ -20,2 +25,2 @@
-clrent(ptr)
-struct	dent *ptr;
+int
+clrent(struct dent *ptr)
@@ -23 +28 @@
-	register *p, j;
+	register int *p, j;
@@ -32 +37 @@
-			return;
+			return(0);
@@ -34,0 +40 @@
+	return(0);
@@ -38 +44,2 @@
-rddir()
+int
+rddir(void)
@@ -43 +50 @@
-	struct tent  *tptr;
+	struct tent  *tptr = &tpentry[0];
@@ -68 +75 @@
-		for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+		for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@ -92 +99 @@
-	if(sum != 0)
+	if(sum != 0) {
@@ -100 +107 @@
-			return;
+			return(0);
@@ -101,0 +109 @@
+	}
@@ -102,0 +111 @@
+	return(0);
@@ -106 +115,2 @@
-wrdir()
+int
+wrdir(void)
@@ -130 +140 @@
-		if (count == 0)  return;
+		if (count == 0)  return(0);
@@ -149 +159 @@
-				for(i=0;i<sizeof(struct tent)/sizeof(short)-1;i++)
+				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short))-1;i++)
@@ -156 +166 @@
-				for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@ -164 +174,2 @@
-tread()
+int
+tread(void)
@@ -166 +177 @@
-	register j, *ptr;
+	register int j, *ptr;
@@ -175,0 +187 @@
+	return(0);
@@ -178 +190,2 @@
-twrite()
+int
+twrite(void)
@@ -184,0 +198 @@
+	return(0);
@@ -187 +201,2 @@
-rseek(blk)
+int
+rseek(int blk)
@@ -190,0 +206 @@
+	return(0);
@@ -193 +209,2 @@
-wseek(blk)
+int
+wseek(int blk)
@@ -195 +212 @@
-	register amt, b;
+	register int amt, b;
@@ -204,0 +222 @@
+	return(0);
@@ -207 +225,2 @@
-seekerr()
+int
+seekerr(void)
@@ -210,0 +230 @@
+	return(0);
@@ -213 +233,2 @@
-verify(key)
+int
+verify(int key)
@@ -215 +236 @@
-	register c;
+	register int c;
@@ -235 +256,2 @@
-getfiles()
+int
+getfiles(void)
@@ -244,0 +267 @@
+	return(0);
@@ -248 +271,2 @@
-expand()
+int
+expand(void)
@@ -258 +282 @@
-				return;
+				return(0);
@@ -276,0 +301 @@
+int
@@ -280,0 +306 @@
+	return(0);
@@ -282,0 +309 @@
+int
@@ -295 +322 @@
-		if(mode != S_IFREG) return;
+		if(mode != S_IFREG) return(0);
@@ -316 +343 @@
-				return;
+				return(0);
@@ -318 +345 @@
-		if (verify('r') < 0)	return;
+		if (verify('r') < 0)	return(0);
@@ -330 +357 @@
-	if (verify('a') < 0)		return;
+	if (verify('a') < 0)		return(0);
@@ -338,0 +366 @@
+	return(0);
@@ -341,2 +369,2 @@
-swabdir(tp)
-register struct tent *tp;
+int
+swabdir(register struct tent *tp)
@@ -346,0 +375 @@
+	return(0);

% usr/src/cmd/tp/tp3.c
@@ -1,0 +2 @@
+#include <stdio.h>
@@ -3,2 +4,5 @@
-gettape(how)
-int (*how)();
+int	decode(), verify(), clrent(), bitmap(), maperr(), setmap(),
+	wrdir(), update1(), wseek(), twrite(), phserr(), done(),
+	rseek(), tread(), usage();
+int
+gettape(int (*how)(struct dent *))
@@ -30,0 +35 @@
+	return(0);
@@ -33,2 +38,2 @@
-delete(dd)
-struct dent *dd;
+int
+delete(struct dent *dd)
@@ -37,0 +43 @@
+	return(0);
@@ -41 +47,2 @@
-update()
+int
+update(void)
@@ -44 +51 @@
-	register b, last;
+	register int b, last;
@@ -67,0 +75 @@
+	return(0);
@@ -71 +79,2 @@
-update1()
+int
+update1(void)
@@ -74 +83 @@
-	register index;
+	register int index;
@@ -88 +97 @@
-		if ((d = id) == 0)	return;
+		if ((d = id) == 0)	return(0);
@@ -101 +110 @@
-		if (index = d->d_size % BSIZE) {
+		if ((index = d->d_size % BSIZE)) {
@@ -110,2 +119,3 @@
-phserr()
-{	printf("%s -- Phase error \n", name);  }
+int
+phserr(void)
+{	printf("%s -- Phase error \n", name); return(0);  }
@@ -113,0 +124 @@
+int
@@ -117 +128 @@
-	register count;
+	register int count;
@@ -127,0 +139 @@
+	return(0);
@@ -130,2 +142,2 @@
-setmap(d)
-register struct dent *d;
+int
+setmap(register struct dent *d)
@@ -140 +152 @@
-	if ((c += block) >= tapsiz)		maperr();
+	if ((c += block) >= (unsigned)tapsiz)		maperr();
@@ -146,0 +159 @@
+	return(0);
@@ -149 +162,2 @@
-maperr()
+int
+maperr(void)
@@ -152,0 +167 @@
+	return(0);
@@ -156 +171,2 @@
-usage()
+int
+usage(void)
@@ -158 +174 @@
-	register reg,count;
+	register int reg,count;
@@ -160 +176 @@
-	static lused;
+	static int lused;
@@ -186,0 +203 @@
+	return(0);
@@ -190,2 +207,2 @@
-taboc(dd)
-struct dent *dd;
+int
+taboc(struct dent *dd)
@@ -193,2 +210,2 @@
-	register  mode;
-	register *m;
+	register int mode;
+	register int *m;
@@ -196 +213 @@
-	int count, *localtime();
+	int count;
@@ -215 +232 @@
-		m = localtime(&dd->d_time);
+		m = (int *)localtime(&dd->d_time);
@@ -218,0 +236 @@
+	return(0);
@@ -222,2 +240,2 @@
-extract(d)
-register struct dent *d;
+int
+extract(register struct dent *d)
@@ -225 +243 @@
-	register count, id;
+	register int count, id;
@@ -227,2 +245,2 @@
-	if (d->d_size==0)	return;
-	if (verify('x') < 0)			return;
+	if (d->d_size==0)	return(0);
+	if (verify('x') < 0)			return(0);
@@ -238 +256 @@
-	if (count = d->d_size % BSIZE) {
+	if ((count = d->d_size % BSIZE)) {
@@ -243 +261 @@
-			return;
+			return(0);
@@ -247,0 +266 @@
+	return(0);

% usr/src/cmd/tp/tp_defs.h usr/include/tp_defs.h

% usr/src/cmd/tr.c
@@ -11,0 +12,2 @@
+int	next(struct string *s);
+int	nextc(struct string *s);
@@ -13,2 +15,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -16 +18 @@
-	register i;
+	register int i;
@@ -18 +20 @@
-	register c, d;
+	register int c, d;
@@ -50 +52 @@
-		while(c = next(&string1))
+		while((c = next(&string1)))
@@ -71 +73 @@
-	while(d = next(&string2))
+	while((d = next(&string2)))
@@ -81 +83 @@
-		if(c = code[c&0377]&0377)
+		if((c = code[c&0377]&0377))
@@ -88,2 +90,2 @@
-next(s)
-struct string *s;
+int
+next(struct string *s)
@@ -114,2 +116,2 @@
-nextc(s)
-struct string *s;
+int
+nextc(struct string *s)
@@ -117 +119 @@
-	register c, i, n;
+	register int c, i, n;

% usr/src/cmd/tsort.c
@@ -8,0 +9 @@
+#define index tindex
@@ -29,4 +30,9 @@
-struct nodelist *index();
-struct nodelist *findloop();
-struct nodelist *mark();
-char *malloc();
+struct nodelist *index(char *s);
+struct nodelist *findloop(void);
+struct nodelist *mark(struct nodelist *i);
+char *malloc(unsigned n);
+int present(struct nodelist *i, struct nodelist *j);
+int anypred(struct nodelist *i);
+int cmp(char *s, char *t);
+void error(char *s, char *t);
+void note(char *s, char *t);
@@ -38,2 +44,2 @@
-main(argc,argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -86,2 +92,2 @@
-present(i,j)
-struct nodelist *i, *j;
+int
+present(struct nodelist *i, struct nodelist *j)
@@ -98,2 +104,2 @@
-anypred(i)
-struct nodelist *i;
+int
+anypred(struct nodelist *i)
@@ -111,2 +117 @@
-index(s)
-register char *s;
+index(register char *s)
@@ -129 +134,2 @@
-	while(*t++ = *s++);
+	while((*t++ = *s++))
+		;
@@ -133,2 +139,2 @@
-cmp(s,t)
-register char *s, *t;
+int
+cmp(register char *s, register char *t)
@@ -145,2 +151,2 @@
-error(s,t)
-char *s, *t;
+void
+error(char *s, char *t)
@@ -152,2 +158,2 @@
-note(s,t)
-char *s,*t;
+void
+note(char *s, char *t)
@@ -162 +168 @@
-findloop()
+findloop(void)
@@ -174 +180 @@
-				error("error 1");
+				error("error 1",empty);
@@ -185 +191 @@
-				error("error 2");
+				error("error 2",empty);

% usr/src/cmd/tty.c
@@ -5 +5,4 @@
-char	*ttyname();
+char	*ttyname(int f);
+int strcmp(char *a, char *b);
+int printf(char *fmt, ...);
+void exit(int n);
@@ -7,2 +10,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char *argv[])

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

% usr/src/cmd/uniq.c
@@ -11 +11,5 @@
-char	*skip();
+char	*skip(register char *s);
+int	gline(char *buf);
+void	pline(char *buf);
+int	equal(char *b1, char *b2);
+void	printe(char *p, char *s);
@@ -13,3 +17,2 @@
-main(argc, argv)
-int argc;
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -21 +24 @@
-			if (isdigit(argv[1][1]))
+			if (isdigit((unsigned char)argv[1][1]))
@@ -65,2 +68,2 @@
-gline(buf)
-register char buf[];
+int
+gline(char buf[])
@@ -68 +71 @@
-	register c;
+	register int c;
@@ -79,2 +82,2 @@
-pline(buf)
-register char buf[];
+void
+pline(char buf[])
@@ -104,2 +107,2 @@
-equal(b1, b2)
-register char b1[], b2[];
+int
+equal(char b1[], char b2[])
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
@@ -7,3 +6,0 @@
-double	getflt();
-int	fperr();
-struct	table	*hash();
@@ -13 +10 @@
-	char	dim[NDIM];
+	signed char	dim[NDIM];
@@ -19 +16 @@
-	char	dim[NDIM];
+	signed char	dim[NDIM];
@@ -21,0 +19,7 @@
+double	getflt(void);
+int	fperr(int sig);
+struct	table	*hash(char *name);
+int	init(void), convr(struct unit *up), units(struct unit *up);
+int	pu(int u, int i, int f);
+int	lookup(char *name, struct unit *up, int den, int c);
+int	equal(char *s1, char *s2), get(void);
@@ -29,17 +33,17 @@
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
@@ -52,2 +56,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -55 +59 @@
-	register i;
+	register int i;
@@ -72 +76 @@
-	signal(8, fperr);
+	signal(8, (int)fperr);
@@ -109,2 +113,2 @@
-units(up)
-struct unit *up;
+int
+units(struct unit *up)
@@ -113 +117 @@
-	register f, i;
+	register int f, i;
@@ -126,0 +131 @@
+	return(0);
@@ -129 +134,2 @@
-pu(u, i, f)
+int
+pu(int u, int i, int f)
@@ -140 +146 @@
-			return(2);
+		return(2);
@@ -147,2 +153,2 @@
-convr(up)
-struct unit *up;
+int
+convr(struct unit *up)
@@ -151 +157 @@
-	register c;
+	register int c;
@@ -198,3 +204,2 @@
-lookup(name, up, den, c)
-char *name;
-struct unit *up;
+int
+lookup(char *name, struct unit *up, int den, int c)
@@ -204 +209 @@
-	register i;
+	register int i;
@@ -230 +235 @@
-	for(i=0; cp1 = prefix[i].pname; i++) {
+	for(i=0; (cp1 = prefix[i].pname); i++) {
@@ -252,2 +257,2 @@
-equal(s1, s2)
-char *s1, *s2;
+int
+equal(char *s1, char *s2)
@@ -265 +270,2 @@
-init()
+int
+init(void)
@@ -291 +297 @@
-		printf("%l units; %l bytes\n\n", i, cp-names);
+		printf("%d units; %d bytes\n\n", i, (int)(cp-names));
@@ -297 +303 @@
-			units(tp);
+			units((struct unit *)tp);
@@ -301 +307 @@
-		return;
+		return(0);
@@ -333 +339 @@
-	convr(lp);
+	convr((struct unit *)lp);
@@ -359 +365 @@
-getflt()
+getflt(void)
@@ -361 +367 @@
-	register c, i, dp;
+	register int c, i, dp;
@@ -415 +421,2 @@
-get()
+int
+get(void)
@@ -417 +424 @@
-	register c;
+	register int c;
@@ -419 +426 @@
-	if(c=peekc) {
+	if((c=peekc)) {
@@ -435,2 +442 @@
-hash(name)
-char *name;
+hash(char *name)
@@ -459 +465,2 @@
-fperr()
+int
+fperr(int sig)
@@ -462 +469,2 @@
-	signal(8, fperr);
+	(void)sig;
+	signal(8, (int)fperr);
@@ -463,0 +472 @@
+	return(0);

% usr/src/cmd/update.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -7,0 +9 @@
+int	dosync(void);
@@ -15 +17,2 @@
-main()
+int
+main(void)
@@ -31 +34,2 @@
-dosync()
+int
+dosync(void)
@@ -34 +38 @@
-	signal(SIGALRM, dosync);
+	signal(SIGALRM, (int)dosync);
@@ -35,0 +40 @@
+	return(0);

% usr/src/cmd/vpr.c
@@ -26 +26,2 @@
-char	*ctime();
+char	*ctime(long *t);
+int	send(void), getline(void), putline(int ff), banner(char *s);
@@ -28,2 +29,2 @@
-main(argc, argv)
-char **argv;
+int
+main(int argc, char **argv)
@@ -72 +73,2 @@
-send()
+int
+send(void)
@@ -74 +76 @@
-	register nskipped;
+	register int nskipped;
@@ -97 +99,2 @@
-getline()
+int
+getline(void)
@@ -99 +102 @@
-	register col, maxcol, c;
+	register int col, maxcol, c;
@@ -175 +178,2 @@
-putline(ff)
+int
+putline(int ff)
@@ -178,2 +182,2 @@
-	register c;
-	extern errno;
+	register int c;
+	extern int errno;
@@ -183 +187 @@
-	while (c = *lp++)
+	while ((c = *lp++))
@@ -188 +192 @@
-		ioctl(fileno(out), SETSTATE, pltmode);
+		ioctl(fileno(out), SETSTATE, (char *)pltmode);
@@ -192 +196 @@
-		ioctl(fileno(out), SETSTATE, prtmode);
+		ioctl(fileno(out), SETSTATE, (char *)prtmode);
@@ -202,0 +207 @@
+	return(0);
@@ -205,2 +210,2 @@
-banner(s)
-char *s;
+int
+banner(char *s)
@@ -232,0 +238 @@
+	return(0);
@@ -236,96 +242,96 @@
-0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, sp, */
-0010,0010,0010,0010,0010,0010,0010,0010,0000,0000,0010,0000,0000,0000,0000,0000, /*, !, */
-0024,0024,0024,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, ", */
-0000,0000,0000,0044,0044,0176,0044,0044,0176,0044,0044,0000,0000,0000,0000,0000, /*, #, */
-0000,0010,0010,0010,0076,0101,0100,0076,0001,0101,0076,0010,0010,0000,0000,0000, /*, $, */
-0000,0000,0000,0141,0142,0004,0010,0010,0020,0043,0103,0000,0000,0000,0000,0000, /*, %, */
-0000,0000,0070,0104,0110,0060,0060,0111,0106,0106,0071,0000,0000,0000,0000,0000, /*, &, */
-0004,0010,0020,0040,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, ', */
-0000,0004,0010,0020,0040,0040,0040,0040,0040,0040,0020,0010,0004,0000,0000,0000, /*, (, */
-0000,0040,0020,0010,0004,0004,0004,0004,0004,0004,0010,0020,0040,0000,0000,0000, /*, ), */
-0000,0000,0000,0010,0111,0052,0034,0177,0034,0052,0111,0010,0000,0000,0000,0000, /*, *, */
-0000,0000,0000,0000,0010,0010,0010,0177,0010,0010,0010,0000,0000,0000,0000,0000, /*, +, */
-0000,0000,0000,0000,0000,0000,0000,0000,0000,0030,0030,0010,0020,0000,0000,0000, /*, ,, */
-0000,0000,0000,0000,0000,0000,0000,0176,0000,0000,0000,0000,0000,0000,0000,0000, /*, -, */
-0000,0000,0000,0000,0000,0000,0000,0000,0000,0030,0030,0000,0000,0000,0000,0000, /*, ., */
-0000,0000,0001,0002,0004,0010,0010,0010,0020,0040,0100,0000,0000,0000,0000,0000, /*, /, */
-0000,0030,0044,0102,0102,0102,0102,0102,0102,0044,0030,0000,0000,0000,0000,0000, /*, 0, */
-0000,0010,0030,0010,0010,0010,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000, /*, 1, */
-0000,0070,0104,0004,0004,0010,0020,0040,0100,0100,0174,0000,0000,0000,0000,0000, /*, 2, */
-0000,0176,0004,0004,0010,0014,0002,0002,0002,0104,0070,0000,0000,0000,0000,0000, /*, 3, */
-0000,0004,0014,0024,0044,0104,0176,0004,0004,0004,0004,0000,0000,0000,0000,0000, /*, 4, */
-0000,0174,0100,0100,0130,0144,0002,0002,0102,0044,0030,0000,0000,0000,0000,0000, /*, 5, */
-0000,0074,0102,0100,0130,0144,0102,0102,0102,0044,0030,0000,0000,0000,0000,0000, /*, 6, */
-0000,0176,0004,0004,0010,0010,0020,0020,0040,0040,0040,0000,0000,0000,0000,0000, /*, 7, */
-0000,0034,0042,0101,0042,0076,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000, /*, 8, */
-0000,0034,0042,0101,0101,0101,0043,0036,0004,0010,0020,0040,0000,0000,0000,0000, /*, 9, */
-0000,0000,0000,0000,0000,0000,0030,0030,0000,0030,0030,0000,0000,0000,0000,0000, /*, :, */
-0000,0000,0000,0000,0000,0000,0030,0030,0000,0030,0030,0020,0040,0000,0000,0000, /*, ;, */
-0002,0004,0010,0020,0040,0100,0040,0020,0010,0004,0002,0000,0000,0000,0000,0000, /*, <, */
-0000,0000,0000,0000,0177,0000,0177,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, =, */
-0100,0040,0020,0010,0004,0002,0004,0010,0020,0040,0100,0000,0000,0000,0000,0000, /*, >, */
-0000,0030,0044,0102,0001,0002,0004,0010,0010,0000,0010,0000,0000,0000,0000,0000, /*, ?, */
-0000,0074,0102,0101,0115,0123,0121,0121,0121,0111,0046,0000,0000,0000,0000,0000, /*, @, */
-0000,0010,0024,0042,0101,0101,0177,0101,0101,0101,0101,0000,0000,0000,0000,0000, /*, A, */
-0000,0176,0101,0101,0101,0176,0101,0101,0101,0101,0176,0000,0000,0000,0000,0000, /*, B, */
-0000,0076,0101,0100,0100,0100,0100,0100,0100,0101,0076,0000,0000,0000,0000,0000, /*, C, */
-0000,0176,0101,0101,0101,0101,0101,0101,0101,0101,0176,0000,0000,0000,0000,0000, /*, D, */
-0000,0176,0100,0100,0100,0170,0100,0100,0100,0100,0177,0000,0000,0000,0000,0000, /*, E, */
-0000,0177,0100,0100,0100,0174,0100,0100,0100,0100,0100,0000,0000,0000,0000,0000, /*, F, */
-0000,0076,0101,0100,0100,0117,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000, /*, G, */
-0000,0101,0101,0101,0101,0176,0101,0101,0101,0101,0101,0000,0000,0000,0000,0000, /*, H, */
-0000,0034,0010,0010,0010,0010,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000, /*, I, */
-0000,0016,0004,0004,0004,0004,0004,0004,0104,0104,0070,0000,0000,0000,0000,0000, /*, J, */
-0000,0101,0102,0104,0110,0120,0160,0110,0104,0102,0101,0000,0000,0000,0000,0000, /*, K, */
-0000,0100,0100,0100,0100,0100,0100,0100,0100,0100,0177,0000,0000,0000,0000,0000, /*, L, */
-0000,0101,0143,0125,0111,0101,0101,0101,0101,0101,0101,0000,0000,0000,0000,0000, /*, M, */
-0000,0101,0141,0121,0111,0105,0103,0101,0101,0101,0101,0000,0000,0000,0000,0000, /*, N, */
-0000,0076,0101,0101,0101,0101,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000, /*, O, */
-0000,0176,0101,0101,0101,0176,0100,0100,0100,0100,0100,0000,0000,0000,0000,0000, /*, P, */
-0000,0076,0101,0101,0101,0101,0101,0101,0131,0105,0076,0002,0001,0000,0000,0000, /*, Q, */
-0000,0176,0101,0101,0101,0176,0104,0102,0101,0101,0101,0000,0000,0000,0000,0000, /*, R, */
-0000,0076,0101,0100,0100,0076,0001,0001,0001,0101,0076,0000,0000,0000,0000,0000, /*, S, */
-0000,0177,0010,0010,0010,0010,0010,0010,0010,0010,0010,0000,0000,0000,0000,0000, /*, T, */
-0000,0101,0101,0101,0101,0101,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000, /*, U, */
-0000,0101,0101,0101,0101,0101,0101,0101,0042,0024,0010,0000,0000,0000,0000,0000, /*, V, */
-0000,0101,0101,0101,0101,0111,0111,0125,0143,0101,0101,0000,0000,0000,0000,0000, /*, W, */
-0000,0101,0101,0042,0024,0010,0024,0042,0101,0101,0101,0000,0000,0000,0000,0000, /*, X, */
-0000,0101,0042,0024,0010,0010,0010,0010,0010,0010,0010,0000,0000,0000,0000,0000, /*, Y, */
-0000,0177,0001,0002,0004,0010,0020,0040,0100,0100,0177,0000,0000,0000,0000,0000, /*, Z, */
-0000,0034,0020,0020,0020,0020,0020,0020,0020,0020,0020,0034,0000,0000,0000,0000, /*, [, */
-0000,0000,0100,0040,0020,0010,0010,0010,0004,0002,0001,0000,0000,0000,0000,0000, /*, , \, */
-0000,0070,0010,0010,0010,0010,0010,0010,0010,0010,0010,0070,0000,0000,0000,0000, /*, ], */
-0010,0024,0042,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, ^, */
-0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0377,0000,0000, /*, _, */
-0040,0020,0010,0004,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, `, */
-0000,0000,0000,0000,0000,0074,0002,0076,0102,0102,0076,0000,0000,0000,0000,0000, /*, a, */
-0000,0100,0100,0100,0100,0174,0102,0102,0102,0102,0174,0000,0000,0000,0000,0000, /*, b, */
-0000,0000,0000,0000,0000,0074,0102,0100,0100,0102,0074,0000,0000,0000,0000,0000, /*, c, */
-0002,0002,0002,0002,0002,0076,0102,0102,0102,0102,0076,0000,0000,0000,0000,0000, /*, d, */
-0000,0000,0000,0000,0000,0074,0102,0174,0100,0102,0074,0000,0000,0000,0000,0000, /*, e, */
-0000,0016,0020,0020,0020,0176,0020,0020,0020,0020,0020,0000,0000,0000,0000,0000, /*, f, */
-0000,0000,0000,0000,0000,0076,0102,0102,0102,0102,0076,0002,0002,0102,0076,0000, /*, g, */
-0000,0100,0100,0100,0100,0174,0102,0102,0102,0102,0102,0000,0000,0000,0000,0000, /*, h, */
-0000,0000,0000,0010,0000,0030,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000, /*, i, */
-0000,0000,0000,0010,0000,0030,0010,0010,0010,0010,0010,0010,0010,0050,0020,0000, /*, j, */
-0000,0100,0100,0100,0100,0106,0110,0120,0160,0110,0106,0000,0000,0000,0000,0000, /*, k, */
-0000,0030,0010,0010,0010,0010,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000, /*, l, */
-0000,0000,0000,0000,0000,0166,0111,0111,0111,0111,0111,0000,0000,0000,0000,0000, /*, m, */
-0000,0000,0000,0000,0100,0174,0102,0102,0102,0102,0102,0000,0000,0000,0000,0000, /*, n, */
-0000,0000,0000,0000,0000,0074,0102,0102,0102,0102,0074,0000,0000,0000,0000,0000, /*, o, */
-0000,0000,0000,0000,0000,0174,0102,0102,0102,0102,0174,0100,0100,0100,0100,0000, /*, p, */
-0000,0000,0000,0000,0000,0076,0102,0102,0102,0102,0076,0002,0002,0002,0002,0000, /*, q, */
-0000,0000,0000,0000,0000,0134,0142,0100,0100,0100,0100,0000,0000,0000,0000,0000, /*, r, */
-0000,0000,0000,0000,0000,0076,0100,0074,0002,0102,0074,0000,0000,0000,0000,0000, /*, s, */
-0000,0020,0020,0020,0020,0176,0020,0020,0020,0020,0014,0000,0000,0000,0000,0000, /*, t, */
-0000,0000,0000,0000,0000,0102,0102,0102,0102,0102,0075,0000,0000,0000,0000,0000, /*, u, */
-0000,0000,0000,0000,0000,0101,0101,0101,0042,0024,0010,0000,0000,0000,0000,0000, /*, v, */
-0000,0000,0000,0000,0000,0111,0111,0111,0111,0111,0066,0000,0000,0000,0000,0000, /*, w, */
-0000,0000,0000,0000,0000,0102,0044,0030,0030,0044,0102,0000,0000,0000,0000,0000, /*, x, */
-0000,0000,0000,0000,0000,0102,0102,0102,0042,0024,0010,0020,0040,0100,0000,0000, /*, y, */
-0000,0000,0000,0000,0000,0176,0004,0010,0020,0040,0176,0000,0000,0000,0000,0000, /*, z, */
-0000,0014,0020,0020,0020,0020,0040,0020,0020,0020,0020,0014,0000,0000,0000,0000, /*, {, */
-0000,0010,0010,0010,0010,0000,0000,0010,0010,0010,0010,0000,0000,0000,0000,0000, /*, |, */
-0000,0030,0010,0010,0010,0010,0004,0010,0010,0010,0010,0030,0000,0000,0000,0000, /*, }, */
-0020,0052,0004,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000, /*, ~, */
-0000,0176,0176,0176,0176,0176,0176,0176,0176,0176,0176,0000,0000,0000,0000,0000, /*, del, */
+	{0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, sp, */
+	{0010,0010,0010,0010,0010,0010,0010,0010,0000,0000,0010,0000,0000,0000,0000,0000}, /*, !, */
+	{0024,0024,0024,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, ", */
+	{0000,0000,0000,0044,0044,0176,0044,0044,0176,0044,0044,0000,0000,0000,0000,0000}, /*, #, */
+	{0000,0010,0010,0010,0076,0101,0100,0076,0001,0101,0076,0010,0010,0000,0000,0000}, /*, $, */
+	{0000,0000,0000,0141,0142,0004,0010,0010,0020,0043,0103,0000,0000,0000,0000,0000}, /*, %, */
+	{0000,0000,0070,0104,0110,0060,0060,0111,0106,0106,0071,0000,0000,0000,0000,0000}, /*, &, */
+	{0004,0010,0020,0040,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, ', */
+	{0000,0004,0010,0020,0040,0040,0040,0040,0040,0040,0020,0010,0004,0000,0000,0000}, /*, (, */
+	{0000,0040,0020,0010,0004,0004,0004,0004,0004,0004,0010,0020,0040,0000,0000,0000}, /*, ), */
+	{0000,0000,0000,0010,0111,0052,0034,0177,0034,0052,0111,0010,0000,0000,0000,0000}, /*, *, */
+	{0000,0000,0000,0000,0010,0010,0010,0177,0010,0010,0010,0000,0000,0000,0000,0000}, /*, +, */
+	{0000,0000,0000,0000,0000,0000,0000,0000,0000,0030,0030,0010,0020,0000,0000,0000}, /*, ,, */
+	{0000,0000,0000,0000,0000,0000,0000,0176,0000,0000,0000,0000,0000,0000,0000,0000}, /*, -, */
+	{0000,0000,0000,0000,0000,0000,0000,0000,0000,0030,0030,0000,0000,0000,0000,0000}, /*, ., */
+	{0000,0000,0001,0002,0004,0010,0010,0010,0020,0040,0100,0000,0000,0000,0000,0000}, /*, /, */
+	{0000,0030,0044,0102,0102,0102,0102,0102,0102,0044,0030,0000,0000,0000,0000,0000}, /*, 0, */
+	{0000,0010,0030,0010,0010,0010,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000}, /*, 1, */
+	{0000,0070,0104,0004,0004,0010,0020,0040,0100,0100,0174,0000,0000,0000,0000,0000}, /*, 2, */
+	{0000,0176,0004,0004,0010,0014,0002,0002,0002,0104,0070,0000,0000,0000,0000,0000}, /*, 3, */
+	{0000,0004,0014,0024,0044,0104,0176,0004,0004,0004,0004,0000,0000,0000,0000,0000}, /*, 4, */
+	{0000,0174,0100,0100,0130,0144,0002,0002,0102,0044,0030,0000,0000,0000,0000,0000}, /*, 5, */
+	{0000,0074,0102,0100,0130,0144,0102,0102,0102,0044,0030,0000,0000,0000,0000,0000}, /*, 6, */
+	{0000,0176,0004,0004,0010,0010,0020,0020,0040,0040,0040,0000,0000,0000,0000,0000}, /*, 7, */
+	{0000,0034,0042,0101,0042,0076,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000}, /*, 8, */
+	{0000,0034,0042,0101,0101,0101,0043,0036,0004,0010,0020,0040,0000,0000,0000,0000}, /*, 9, */
+	{0000,0000,0000,0000,0000,0000,0030,0030,0000,0030,0030,0000,0000,0000,0000,0000}, /*, :, */
+	{0000,0000,0000,0000,0000,0000,0030,0030,0000,0030,0030,0020,0040,0000,0000,0000}, /*, ;, */
+	{0002,0004,0010,0020,0040,0100,0040,0020,0010,0004,0002,0000,0000,0000,0000,0000}, /*, <, */
+	{0000,0000,0000,0000,0177,0000,0177,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, =, */
+	{0100,0040,0020,0010,0004,0002,0004,0010,0020,0040,0100,0000,0000,0000,0000,0000}, /*, >, */
+	{0000,0030,0044,0102,0001,0002,0004,0010,0010,0000,0010,0000,0000,0000,0000,0000}, /*, ?, */
+	{0000,0074,0102,0101,0115,0123,0121,0121,0121,0111,0046,0000,0000,0000,0000,0000}, /*, @, */
+	{0000,0010,0024,0042,0101,0101,0177,0101,0101,0101,0101,0000,0000,0000,0000,0000}, /*, A, */
+	{0000,0176,0101,0101,0101,0176,0101,0101,0101,0101,0176,0000,0000,0000,0000,0000}, /*, B, */
+	{0000,0076,0101,0100,0100,0100,0100,0100,0100,0101,0076,0000,0000,0000,0000,0000}, /*, C, */
+	{0000,0176,0101,0101,0101,0101,0101,0101,0101,0101,0176,0000,0000,0000,0000,0000}, /*, D, */
+	{0000,0176,0100,0100,0100,0170,0100,0100,0100,0100,0177,0000,0000,0000,0000,0000}, /*, E, */
+	{0000,0177,0100,0100,0100,0174,0100,0100,0100,0100,0100,0000,0000,0000,0000,0000}, /*, F, */
+	{0000,0076,0101,0100,0100,0117,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000}, /*, G, */
+	{0000,0101,0101,0101,0101,0176,0101,0101,0101,0101,0101,0000,0000,0000,0000,0000}, /*, H, */
+	{0000,0034,0010,0010,0010,0010,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000}, /*, I, */
+	{0000,0016,0004,0004,0004,0004,0004,0004,0104,0104,0070,0000,0000,0000,0000,0000}, /*, J, */
+	{0000,0101,0102,0104,0110,0120,0160,0110,0104,0102,0101,0000,0000,0000,0000,0000}, /*, K, */
+	{0000,0100,0100,0100,0100,0100,0100,0100,0100,0100,0177,0000,0000,0000,0000,0000}, /*, L, */
+	{0000,0101,0143,0125,0111,0101,0101,0101,0101,0101,0101,0000,0000,0000,0000,0000}, /*, M, */
+	{0000,0101,0141,0121,0111,0105,0103,0101,0101,0101,0101,0000,0000,0000,0000,0000}, /*, N, */
+	{0000,0076,0101,0101,0101,0101,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000}, /*, O, */
+	{0000,0176,0101,0101,0101,0176,0100,0100,0100,0100,0100,0000,0000,0000,0000,0000}, /*, P, */
+	{0000,0076,0101,0101,0101,0101,0101,0101,0131,0105,0076,0002,0001,0000,0000,0000}, /*, Q, */
+	{0000,0176,0101,0101,0101,0176,0104,0102,0101,0101,0101,0000,0000,0000,0000,0000}, /*, R, */
+	{0000,0076,0101,0100,0100,0076,0001,0001,0001,0101,0076,0000,0000,0000,0000,0000}, /*, S, */
+	{0000,0177,0010,0010,0010,0010,0010,0010,0010,0010,0010,0000,0000,0000,0000,0000}, /*, T, */
+	{0000,0101,0101,0101,0101,0101,0101,0101,0101,0101,0076,0000,0000,0000,0000,0000}, /*, U, */
+	{0000,0101,0101,0101,0101,0101,0101,0101,0042,0024,0010,0000,0000,0000,0000,0000}, /*, V, */
+	{0000,0101,0101,0101,0101,0111,0111,0125,0143,0101,0101,0000,0000,0000,0000,0000}, /*, W, */
+	{0000,0101,0101,0042,0024,0010,0024,0042,0101,0101,0101,0000,0000,0000,0000,0000}, /*, X, */
+	{0000,0101,0042,0024,0010,0010,0010,0010,0010,0010,0010,0000,0000,0000,0000,0000}, /*, Y, */
+	{0000,0177,0001,0002,0004,0010,0020,0040,0100,0100,0177,0000,0000,0000,0000,0000}, /*, Z, */
+	{0000,0034,0020,0020,0020,0020,0020,0020,0020,0020,0020,0034,0000,0000,0000,0000}, /*, [, */
+	{0000,0000,0100,0040,0020,0010,0010,0010,0004,0002,0001,0000,0000,0000,0000,0000}, /*, , \, */
+	{0000,0070,0010,0010,0010,0010,0010,0010,0010,0010,0010,0070,0000,0000,0000,0000}, /*, ], */
+	{0010,0024,0042,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, ^, */
+	{0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0377,0000,0000}, /*, _, */
+	{0040,0020,0010,0004,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, `, */
+	{0000,0000,0000,0000,0000,0074,0002,0076,0102,0102,0076,0000,0000,0000,0000,0000}, /*, a, */
+	{0000,0100,0100,0100,0100,0174,0102,0102,0102,0102,0174,0000,0000,0000,0000,0000}, /*, b, */
+	{0000,0000,0000,0000,0000,0074,0102,0100,0100,0102,0074,0000,0000,0000,0000,0000}, /*, c, */
+	{0002,0002,0002,0002,0002,0076,0102,0102,0102,0102,0076,0000,0000,0000,0000,0000}, /*, d, */
+	{0000,0000,0000,0000,0000,0074,0102,0174,0100,0102,0074,0000,0000,0000,0000,0000}, /*, e, */
+	{0000,0016,0020,0020,0020,0176,0020,0020,0020,0020,0020,0000,0000,0000,0000,0000}, /*, f, */
+	{0000,0000,0000,0000,0000,0076,0102,0102,0102,0102,0076,0002,0002,0102,0076,0000}, /*, g, */
+	{0000,0100,0100,0100,0100,0174,0102,0102,0102,0102,0102,0000,0000,0000,0000,0000}, /*, h, */
+	{0000,0000,0000,0010,0000,0030,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000}, /*, i, */
+	{0000,0000,0000,0010,0000,0030,0010,0010,0010,0010,0010,0010,0010,0050,0020,0000}, /*, j, */
+	{0000,0100,0100,0100,0100,0106,0110,0120,0160,0110,0106,0000,0000,0000,0000,0000}, /*, k, */
+	{0000,0030,0010,0010,0010,0010,0010,0010,0010,0010,0034,0000,0000,0000,0000,0000}, /*, l, */
+	{0000,0000,0000,0000,0000,0166,0111,0111,0111,0111,0111,0000,0000,0000,0000,0000}, /*, m, */
+	{0000,0000,0000,0000,0100,0174,0102,0102,0102,0102,0102,0000,0000,0000,0000,0000}, /*, n, */
+	{0000,0000,0000,0000,0000,0074,0102,0102,0102,0102,0074,0000,0000,0000,0000,0000}, /*, o, */
+	{0000,0000,0000,0000,0000,0174,0102,0102,0102,0102,0174,0100,0100,0100,0100,0000}, /*, p, */
+	{0000,0000,0000,0000,0000,0076,0102,0102,0102,0102,0076,0002,0002,0002,0002,0000}, /*, q, */
+	{0000,0000,0000,0000,0000,0134,0142,0100,0100,0100,0100,0000,0000,0000,0000,0000}, /*, r, */
+	{0000,0000,0000,0000,0000,0076,0100,0074,0002,0102,0074,0000,0000,0000,0000,0000}, /*, s, */
+	{0000,0020,0020,0020,0020,0176,0020,0020,0020,0020,0014,0000,0000,0000,0000,0000}, /*, t, */
+	{0000,0000,0000,0000,0000,0102,0102,0102,0102,0102,0075,0000,0000,0000,0000,0000}, /*, u, */
+	{0000,0000,0000,0000,0000,0101,0101,0101,0042,0024,0010,0000,0000,0000,0000,0000}, /*, v, */
+	{0000,0000,0000,0000,0000,0111,0111,0111,0111,0111,0066,0000,0000,0000,0000,0000}, /*, w, */
+	{0000,0000,0000,0000,0000,0102,0044,0030,0030,0044,0102,0000,0000,0000,0000,0000}, /*, x, */
+	{0000,0000,0000,0000,0000,0102,0102,0102,0042,0024,0010,0020,0040,0100,0000,0000}, /*, y, */
+	{0000,0000,0000,0000,0000,0176,0004,0010,0020,0040,0176,0000,0000,0000,0000,0000}, /*, z, */
+	{0000,0014,0020,0020,0020,0020,0040,0020,0020,0020,0020,0014,0000,0000,0000,0000}, /*, {, */
+	{0000,0010,0010,0010,0010,0000,0000,0010,0010,0010,0010,0000,0000,0000,0000,0000}, /*, |, */
+	{0000,0030,0010,0010,0010,0010,0004,0010,0010,0010,0010,0030,0000,0000,0000,0000}, /*, }, */
+	{0020,0052,0004,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000}, /*, ~, */
+	{0000,0176,0176,0176,0176,0176,0176,0176,0176,0176,0176,0000,0000,0000,0000,0000}, /*, del, */

% usr/src/cmd/wall.c
@@ -8,2 +8 @@
-char	*strcpy();
-char	*strcat();
+void	sendmes(char *tty);
@@ -11,2 +10,2 @@
-main(argc, argv)
-char *argv[];
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
+void wcp(register char *wd, long charct, long wordct, long linect);
+int
+main(int argc, char *argv[])
@@ -69,3 +70,2 @@
-wcp(wd, charct, wordct, linect)
-register char *wd;
-long charct; long wordct; long linect;
+void
+wcp(register char *wd, long charct, long wordct, long linect)

% usr/src/cmd/who.c
@@ -13,2 +13,3 @@
-main(argc, argv)
-char **argv;
+void putline(void);
+int
+main(int argc, char **argv)
@@ -16 +17 @@
-	register char *tp, *s;
+	register char *tp = 0, *s;
@@ -55 +56,2 @@
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
@@ -23,2 +19,4 @@
-int	eof();
-int	timout();
+int	eof(void);
+int	timout(void);
+void	ex(char *bp);
+void	sigs(int sig);
@@ -27,2 +25,2 @@
-main(argc, argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -31 +29 @@
-	register i;
+	register int i;
@@ -106 +104 @@
-	signal(SIGALRM, timout);
+	signal(SIGALRM, (int)timout);
@@ -115 +113 @@
-	sigs(eof);
+	sigs((int)eof);
@@ -140 +138,2 @@
-timout()
+int
+timout(void)
@@ -144,0 +144 @@
+	return(0);
@@ -147 +147,2 @@
-eof()
+int
+eof(void)
@@ -151,0 +153 @@
+	return(0);
@@ -154,2 +156,2 @@
-ex(bp)
-char *bp;
+void
+ex(char *bp)
@@ -157 +159 @@
-	register i;
+	register int i;
@@ -166 +168 @@
-		sigs((int (*)())0);
+		sigs(0);
@@ -174 +176 @@
-	sigs(eof);
+	sigs((int)eof);
@@ -177,2 +179,2 @@
-sigs(sig)
-int (*sig)();
+void
+sigs(int sig)
@@ -180 +182 @@
-	register i;
+	register int i;

% usr/src/cmd/yes.c
@@ -1,2 +1,3 @@
-main(argc, argv)
-char **argv;
+int printf(char *fmt, ...);
+int
+main(int argc, char *argv[])

% usr/src/games/arithmetic.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -4,0 +6,2 @@
+int	getnum(char *s), random(int range), skrand(int range);
+int	score(void), getline(char *s), delete(void);
@@ -14,2 +17,2 @@
-main(argc,argv)
-char	*argv[];
+int
+main(int argc, char *argv[])
@@ -20 +23 @@
-	extern	delete();
+	extern int delete(void);
@@ -22 +25 @@
-	signal(SIGINT, delete);
+	signal(SIGINT, (int)delete);
@@ -32 +35 @@
-			while(types[dif] = argv[1][dif])
+			while((types[dif] = argv[1][dif]))
@@ -121,2 +124,2 @@
-getline(s)
-char *s;
+int
+getline(char *s)
@@ -139,0 +143 @@
+	return(0);
@@ -142,2 +146,2 @@
-getnum(s)
-char *s;
+int
+getnum(char *s)
@@ -156 +160,2 @@
-random(range)
+int
+random(int range)
@@ -161 +166,3 @@
-skrand(range){
+int
+skrand(int range)
+{
@@ -168 +175,2 @@
-score()
+int
+score(void)
@@ -175 +183 @@
-	if(rights == 0)	return;
+	if(rights == 0)	return(0);
@@ -182,0 +191 @@
+	return(0);
@@ -185 +194,2 @@
-delete()
+int
+delete(void)
@@ -192,0 +203 @@
+	return(0);

% usr/src/games/backgammon.c
@@ -15 +15,14 @@
-int red[]     {0,2,0,0,0,0,0,0,0,0,0,0,5,
+int	getstr(char *s), play(int *player, int *playee, int pos[]);
+int	nextmove(int *player, int *playee), prtmov(int k);
+int	update(int *player, int *playee, int k);
+int	piececount(int *player, int startrow, int endrow);
+int	roll(void), movegen(int *mover, int *movee);
+int	moverecord(int *mover), strategy(int *player, int *playee);
+int	eval(int *player, int *playee, int k, int *prob);
+int	instructions(void);
+int	getprob(int *player, int *playee, int start, int finish);
+int	prtbrd(void);
+int	numline(int *upcol, int *downcol, int start, int fin);
+int	colorline(int *upcol, int c1, int *downcol, int c2, int start, int fin);
+int	bg_srand(void), bg_rand(void), _look(int *p), _store(int *p, int numb);
+int red[]     = {0,2,0,0,0,0,0,0,0,0,0,0,5,
@@ -18 +31 @@
-int white[]   {0,2,0,0,0,0,0,0,0,0,0,0,5,
+int white[]   = {0,2,0,0,0,0,0,0,0,0,0,0,5,
@@ -21 +34 @@
-int probability[]{0,11,12,13,14,15,16,
+int probability[]={0,11,12,13,14,15,16,
@@ -28 +41,2 @@
-main()
+int
+main(void)
@@ -30 +44 @@
-	int t,k,n,go[5];
+	int t,k,n,go[6];
@@ -33 +47 @@
-	srand();
+	bg_srand();
@@ -57 +71 @@
-	    exit();
+	    exit(0);
@@ -94 +108 @@
-	    exit();
+	    exit(0);
@@ -99,2 +113,2 @@
-getstr(s)
-char *s;
+int
+getstr(char *s)
@@ -103,0 +118 @@
+	return(0);
@@ -106,2 +121,2 @@
-play(player,playee,pos)
-int *player,*playee,pos[];
+int
+play(int *player, int *playee, int pos[])
@@ -149,2 +164,2 @@
-nextmove(player,playee)
-int *player,*playee;
+int
+nextmove(int *player, int *playee)
@@ -170,2 +185,2 @@
-prtmov(k)
-int k;
+int
+prtmov(int k)
@@ -179,0 +195 @@
+	return(0);
@@ -181,2 +197,2 @@
-update(player,playee,k)
-int *player,*playee,k;
+int
+update(int *player, int *playee, int k)
@@ -194,0 +211 @@
+	return(0);
@@ -196,2 +213,2 @@
-piececount(player,startrow,endrow)
-int *player,startrow,endrow;
+int
+piececount(int *player, int startrow, int endrow)
@@ -202 +219 @@
-	sum=+player[startrow++];
+	sum+=player[startrow++];
@@ -205,15 +222,2 @@
-/*
-prtmovs()
-{
-	int i1,i2;
-	printf( "possible moves are\n");
-	for(i1=0;i1<imoves;i1++){
-		printf( "\n%d",i1);
-		for(i2=0;i2<4;i2++){
-			if(moves[i1].pos[i2]==NIL)break;
-			printf( "%d, %d",moves[i1].pos[i2],moves[i1].mov[i2]);
-		}
-	}
-	printf( "\n");
-}
-*/
+int
+roll(void)
@@ -221 +224,0 @@
-roll()
@@ -224,2 +227,3 @@
-	die1=(rand()>>8)%6+1;
-	die2=(rand()>>8)%6+1;
+	die1=(bg_rand()>>8)%6+1;
+	die2=(bg_rand()>>8)%6+1;
+	return(0);
@@ -228,2 +232,2 @@
-movegen(mover,movee)
-int *mover,*movee;
+int
+movegen(int *mover, int *movee)
@@ -237 +241 @@
-		if((k=25-i-die1)>0&&movee[k]>=2)
+		if((k=25-i-die1)>0&&movee[k]>=2) {
@@ -239,0 +244 @@
+		}
@@ -250 +255 @@
-			if((k=25-j-die2)>0&&movee[k]>=2)
+			if((k=25-j-die2)>0&&movee[k]>=2) {
@@ -252,0 +258 @@
+			}
@@ -268 +274 @@
-			    if((k=25-l-die1)>0&&movee[k]>=2)
+			    if((k=25-l-die1)>0&&movee[k]>=2) {
@@ -270,0 +277 @@
+			    }
@@ -281 +288 @@
-				if((k=25-m-die1)>=0&&movee[k]>=2)
+				if((k=25-m-die1)>=0&&movee[k]>=2) {
@@ -283,0 +291 @@
+				}
@@ -313,0 +322 @@
+	return(0);
@@ -315,2 +324,2 @@
-moverecord(mover)
-int *mover;
+int
+moverecord(int *mover)
@@ -326,0 +336 @@
+	    /* fallthrough */
@@ -329,0 +340 @@
+	    /* fallthrough */
@@ -332,0 +344 @@
+	    /* fallthrough */
@@ -353,0 +366 @@
+	return(0);
@@ -357,2 +370,2 @@
-strategy(player,playee)
-int *player,*playee;
+int
+strategy(int *player, int *playee)
@@ -391 +404 @@
-	return(goodmoves[(rand()>>4)%n]);
+	return(goodmoves[(bg_rand()>>4)%n]);
@@ -394,2 +407,2 @@
-eval(player,playee,k,prob)
-int *player,*playee,k,*prob;
+int
+eval(int *player, int *playee, int k, int *prob)
@@ -441 +454 @@
-		sum=+ *p++ * n;	/*remove pieces, but just barely*/
+		sum+= *p++ * n;	/*remove pieces, but just barely*/
@@ -449 +462 @@
-	    for(p=newtry;p<q;)sum=- *p++;  /*bad to be on 1st three points*/
+	    for(p=newtry;p<q;)sum-= *p++;  /*bad to be on 1st three points*/
@@ -453 +466 @@
-	    *prob=+ n*getprob(newtry,newother,6*n-5,6*n);
+	    *prob+= n*getprob(newtry,newother,6*n-5,6*n);
@@ -456 +469,2 @@
-instructions()
+int
+instructions(void)
@@ -482,0 +497 @@
+	return(0);
@@ -485,2 +500,2 @@
-getprob(player,playee,start,finish)
-int *player,*playee,start,finish;
+int
+getprob(int *player, int *playee, int start, int finish)
@@ -498 +513 @@
-		    if(playee[n]!=0)sum=+probability[k];
+		    if(playee[n]!=0)sum+=probability[k];
@@ -504 +519,2 @@
-prtbrd()
+int
+prtbrd(void)
@@ -540,0 +557 @@
+	return(0);
@@ -542,2 +559,2 @@
-numline(upcol,downcol,start,fin)
-int *upcol,*downcol,start,fin;
+int
+numline(int *upcol, int *downcol, int start, int fin)
@@ -549,0 +567 @@
+	return(0);
@@ -551,3 +569,2 @@
-colorline(upcol,c1,downcol,c2,start,fin)
-int *upcol,*downcol,start,fin;
-char c1,c2;
+int
+colorline(int *upcol, int c1, int *downcol, int c2, int start, int fin)
@@ -562,0 +580 @@
+	return(0);
@@ -565 +583 @@
-int rrno 0;
+int rrno = 0;
@@ -567,3 +585,5 @@
-srand(){
-	rrno = _look( 0x40000 );
-	_store( 0x40000, rrno+1 );
+int
+bg_srand(void){
+	rrno = _look( (int *)0x40000 );
+	_store( (int *)0x40000, rrno+1 );
+	return(0);
@@ -572,3 +592,4 @@
-rand(){
-	rrno =* 0106273;
-	rrno =+ 020202;
+int
+bg_rand(void){
+	rrno *= 0106273;
+	rrno += 020202;
@@ -578 +599,2 @@
-_look(p) int *p; {
+int
+_look(int *p) {
@@ -582 +604,2 @@
-_store( p, numb ) int *p; {
+int
+_store(int *p, int numb) {
@@ -583,0 +607 @@
+	return(0);

% usr/src/games/fish.c
@@ -14,0 +15,3 @@
+int	shuffle(), choose(), draw(), error(), empty(), mark(), deal(),
+	stats(), phand(), instruct(), game(), move(), madebook(),
+	score(), guess(), start(), hedrew(), heguessed(), myguess();
@@ -25 +28,2 @@
-shuffle(){
+int
+shuffle(void){
@@ -30 +34 @@
-	register i;
+	register int i;
@@ -38,0 +43 @@
+	return(0);
@@ -41 +46,2 @@
-choose( a, n ) char a[]; {
+int
+choose( a, n ) char a[]; int n; {
@@ -44 +50 @@
-	register j, t;
+	register int j, t;
@@ -54 +60,2 @@
-draw() {
+int
+draw(void) {
@@ -58,0 +66 @@
+int
@@ -62,0 +71 @@
+	return(0);
@@ -64,0 +74 @@
+int
@@ -66 +76 @@
-	register i;
+	register int i;
@@ -74 +84,2 @@
-mark( cd, hand ) HAND hand; {
+int
+mark( cd, hand ) int cd; HAND hand; {
@@ -84 +95,2 @@
-deal( hand, n ) HAND hand; {
+int
+deal( hand, n ) HAND hand; int n; {
@@ -87,0 +100 @@
+	return(0);
@@ -90 +103 @@
-char *cname[] {
+char *cname[] = {
@@ -107,2 +120,3 @@
-stats(){
-	register i, ct, b;
+int
+stats(void){
+	register int i, ct, b;
@@ -127,0 +142 @@
+	return(0);
@@ -129,0 +145 @@
+int
@@ -131 +147 @@
-	register i, j;
+	register int i, j;
@@ -141 +157 @@
-			register k;
+			register int k;
@@ -154,0 +171 @@
+	return(0);
@@ -157 +174,2 @@
-main( argc, argv ) char * argv[]; { 
+int
+main( argc, argv ) int argc; char * argv[]; {
@@ -159 +177 @@
-	register c;
+	register int c;
@@ -175,0 +194 @@
+	return(0);
@@ -180 +199 @@
-char *inst[] {
+char *inst[] = {
@@ -208 +227,2 @@
-instruct(){
+int
+instruct(void){
@@ -215,0 +236 @@
+	return(0);
@@ -218 +239,2 @@
-game(){
+int
+game(void){
@@ -229 +251 @@
-		register g;
+		register int g;
@@ -256 +278,2 @@
-move( hs, ht, g, v ) HAND hs, ht; {
+int
+move( hs, ht, g, v ) HAND hs, ht; int g, v; {
@@ -259 +282 @@
-	register d;
+	register int d;
@@ -315 +338,2 @@
-madebook( x ){
+int
+madebook( x ) int x; {
@@ -316,0 +341 @@
+	return(0);
@@ -319,2 +344,3 @@
-score(){
-	register my, your, i;
+int
+score(void){
+	register int my, your, i;
@@ -345,0 +372 @@
+	return(0);
@@ -350 +377,2 @@
-guess(){
+int
+guess(void){
@@ -352 +380 @@
-	register g, go;
+	register int g, go;
@@ -431,0 +460 @@
+int
@@ -432,0 +462 @@
+	(void)h;
@@ -433,0 +464 @@
+	return(0);
@@ -436 +467,2 @@
-hedrew( d ){
+int
+hedrew( d ) int d; {
@@ -437,0 +470 @@
+	return(0);
@@ -440 +473,2 @@
-heguessed( d ){
+int
+heguessed( d ) int d; {
@@ -441,0 +476 @@
+	return(0);
@@ -444 +479,2 @@
-myguess(){
+int
+myguess(void){
@@ -446 +482 @@
-	register i, lg, t;
+	register int i, lg, t;
@@ -457 +493 @@
-		try[ntry++] = i;
+		try[(unsigned char)ntry++] = i;
@@ -465 +501 @@
-		if( hehas[try[i]] ) {
+		if( hehas[(unsigned char)try[i]] ) {
@@ -474 +510 @@
-		if( haveguessed[try[i]] < lg ) lg = haveguessed[try[i]];
+		if( haveguessed[(unsigned char)try[i]] < lg ) lg = haveguessed[(unsigned char)try[i]];
@@ -480 +516 @@
-		if( haveguessed[try[i]] == lg ) try[t++] = try[i];
+		if( haveguessed[(unsigned char)try[i]] == lg ) try[t++] = try[i];

% usr/src/games/fortune.c
@@ -6 +6,2 @@
-main()
+int
+main(void)

% usr/src/games/hangman.c
@@ -8,0 +9,3 @@
+int	setup(void), startnew(void), stateout(void), getguess(void), wordout(void),
+	youwon(void), fatal(char *s), getword(void), pscore(void);
+double	frand(void);
@@ -14 +17,2 @@
-main(argc,argv) char **argv;
+int
+main(int argc, char **argv)
@@ -31 +35,2 @@
-setup()
+int
+setup(void)
@@ -34,2 +39,2 @@
-	time(tvec);
-	srand(tvec[1]+tvec[2]);
+	time((long *)tvec);
+	srand(tvec[0]);
@@ -38,0 +44 @@
+	return(0);
@@ -40 +46 @@
-double frand()
+double frand(void)
@@ -45 +51,2 @@
-startnew()
+int
+startnew(void)
@@ -55,0 +63 @@
+	return(0);
@@ -57 +65,2 @@
-stateout()
+int
+stateout(void)
@@ -63,0 +73 @@
+	return(0);
@@ -65 +75,2 @@
-getguess()
+int
+getguess(void)
@@ -92 +103 @@
-		return;
+		return(0);
@@ -95 +106 @@
-		if(word[i]=='.') return;
+		if(word[i]=='.') return(0);
@@ -98 +109 @@
-	return;
+	return(0);
@@ -100 +111,2 @@
-wordout()
+int
+wordout(void)
@@ -103,0 +116 @@
+	return(0);
@@ -105 +118,2 @@
-youwon()
+int
+youwon(void)
@@ -107,0 +122 @@
+	return(0);
@@ -109 +124,2 @@
-fatal(s) char *s;
+int
+fatal(char *s)
@@ -112,0 +129 @@
+	return(0);
@@ -114 +131,2 @@
-getword()
+int
+getword(void)
@@ -133,0 +152 @@
+	return(0);
@@ -135,2 +154,2 @@
-long int freq[]
-{	42066,	9228,	24412,	14500,	55162,
+long int freq[]={
+	42066,	9228,	24412,	14500,	55162,
@@ -143 +162,2 @@
-pscore()
+int
+pscore(void)
@@ -145,0 +166 @@
+	return(0);

% usr/src/games/quiz.c
@@ -9,0 +10,7 @@
+int	readline(void), cmp(char *u, char *v), disj(int s), string(int s);
+int	eat(int s, int c), fold(int c), publish(char *t), pub1(int s);
+int	segment(char *u, char *w[]);
+int	perm(char *u[], int m, char *v[], int n, int p[]);
+int	find(char *u[], int m), readindex(void), talloc(void);
+int	query(char *r), next(void), done(void);
+int	instruct(char *info), badinfo(void), dunno(void);
@@ -12 +19 @@
-char score[NL];
+signed char score[NL];
@@ -26 +33 @@
-char	*malloc();
+char	*malloc(unsigned n);
@@ -28 +35,2 @@
-readline()
+int
+readline(void)
@@ -31 +39 @@
-	register c;
+	register int c;
@@ -48,2 +56,2 @@
-				*line = getc(input);
-				if(*line==0377)
+				c = getc(input);
+				if(c==EOF)
@@ -51 +59 @@
-			} while(*line!='\n');
+			} while(c!='\n');
@@ -60,2 +68,2 @@
-cmp(u,v)
-char *u, *v;
+int
+cmp(char *u, char *v)
@@ -72 +80,2 @@
-disj(s)
+int
+disj(int s)
@@ -86 +95 @@
-			return(t|x&s);
+			return(t|(x&s));
@@ -111 +120,2 @@
-string(s)
+int
+string(int s)
@@ -128,0 +139 @@
+			/* fallthrough */
@@ -155,2 +166,2 @@
-eat(s,c)
-char c;
+int
+eat(int s, int c)
@@ -171,2 +182,2 @@
-fold(c)
-char c;
+int
+fold(int c)
@@ -179,2 +190,2 @@
-publish(t)
-char *t;
+int
+publish(char *t)
@@ -183,0 +195 @@
+	return(0);
@@ -186 +198,2 @@
-pub1(s)
+int
+pub1(int s)
@@ -196 +209 @@
-			return;
+			return(0);
@@ -204,0 +218 @@
+			/* fallthrough */
@@ -212,2 +226,2 @@
-segment(u,w)
-char *u, *w[];
+int
+segment(char *u, char *w[])
@@ -244,3 +258,2 @@
-perm(u,m,v,n,p)
-int p[];
-char *u[], *v[];
+int
+perm(char *u[], int m, char *v[], int n, int p[])
@@ -265,2 +278,2 @@
-find(u,m)
-char *u[];
+int
+find(char *u[], int m)
@@ -277 +290,2 @@
-readindex()
+int
+readindex(void)
@@ -287,0 +302 @@
+	return(0);
@@ -290 +305,2 @@
-talloc()
+int
+talloc(void)
@@ -294,0 +311 @@
+	return(0);
@@ -297,2 +314,2 @@
-main(argc,argv)
-char *argv[];
+int
+main(int argc, char *argv[])
@@ -300 +317 @@
-	register j;
+	register int j;
@@ -306 +323 @@
-	extern done();
+	extern int done(void);
@@ -310 +327 @@
-	inc = (int)tm&077774|01;
+	inc = ((int)tm&077774)|01;
@@ -335 +352 @@
-	signal(SIGINT, done);
+	signal(SIGINT, (int)done);
@@ -385,2 +402,2 @@
-query(r)
-char *r;
+int
+query(char *r)
@@ -404 +421,2 @@
-next()
+int
+next(void)
@@ -419 +437,2 @@
-done()
+int
+done(void)
@@ -425,0 +445 @@
+	return(0);
@@ -427,2 +447,2 @@
-instruct(info)
-char *info;
+int
+instruct(char *info)
@@ -462,0 +483 @@
+	return(0);
@@ -465 +486,2 @@
-badinfo(){
+int
+badinfo(void){
@@ -466,0 +489 @@
+	return(0);
@@ -469 +492,2 @@
-dunno()
+int
+dunno(void)
@@ -472,0 +497 @@
+	return(0);

% usr/src/games/wump.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -19 +20,3 @@
-char	*intro[]
+int	tunnel(int i), rline(void), rnum(int n), rin(void);
+int	near(struct room *ap, int ahaz), icomp(const void *p1, const void *p2);
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
+	int k, icomp(const void *, const void *);
@@ -140 +144 @@
-		qsort(&p->tunn[0], NTUNN, 2, icomp);
+		qsort(&p->tunn[0], NTUNN, sizeof(p->tunn[0]), icomp);
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
@@ -284,0 +289 @@
+	return(0);
@@ -287 +292,2 @@
-tunnel(i)
+int
+tunnel(int i)
@@ -290 +296 @@
-	register n, j;
+	register int n, j;
@@ -309 +315,2 @@
-rline()
+int
+rline(void)
@@ -317 +324 @@
-			exit();
+			exit(0);
@@ -324 +331,2 @@
-rnum(n)
+int
+rnum(int n)
@@ -326 +334 @@
-	static first[2];
+	static long first;
@@ -328,3 +336,3 @@
-	if(first[1] == 0) {
-		time(first);
-		srand((first[1]*first[0])^first[1]);
+	if(first == 0) {
+		time(&first);
+		srand(first);
@@ -335 +343,2 @@
-rin()
+int
+rin(void)
@@ -337 +346 @@
-	register n, c;
+	register int n, c;
@@ -345 +354 @@
-					exit();
+					exit(0);
@@ -356,2 +365,2 @@
-near(ap, ahaz)
-struct room *ap;
+int
+near(struct room *ap, int ahaz)
@@ -360 +369 @@
-	register haz, i;
+	register int haz, i;
@@ -370,2 +379,2 @@
-icomp(p1, p2)
-int *p1, *p2;
+int
+icomp(const void *p1, const void *p2)
@@ -374 +383 @@
-	return(*p1 - *p2);
+	return(*(const int *)p1 - *(const int *)p2);

% usr/src/libc/csu/crt0.c usr/src/libc/csu/crt0.s
@@ -1 +1,4 @@
-/ C runtime startoff
+extern int main(int argc, char **argv);
+extern void exit(int n);
+char **environ;
+int errno;
@@ -3,4 +6,9 @@
-.globl	_exit, _environ
-.globl	start
-.globl	_main
-exit = 1.
+/*
+ * Entry from crt0.s with r0 = sp, which points at the argument frame the
+ * kernel built on exec: { argc, argv[0..argc-1], 0, envp[0..], 0 }.
+ */
+void
+_startc(int *frame)
+{
+	int argc = frame[0];
+	char **argv = (char **)&frame[1];
@@ -8,29 +16,3 @@
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
+	environ = (char **)&frame[argc + 2];
+	exit(main(argc, argv));
+}

% usr/src/libc/csu/crt0.s
@@ -1,36 +1,7 @@
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
+.globl _start
+_start:
+	mov r0, sp
+	bl _startc
+	mov r7, #1
+	svc #0
+	b .

% usr/src/libc/gen/abort.c usr/src/libc/gen/abort.s
@@ -1,11 +1,6 @@
-/ C library -- abort
-
-.globl	_abort
-iot	= 4
-.globl	csv,cret
-
-_abort:
-	jsr	r5,csv
-	iot
-	clr	r0
-	jmp	cret
+extern void _exit(int n);
+void
+abort(void)
+{
+	_exit(1);
+}

% usr/src/libc/gen/atof.c
@@ -9,2 +9 @@
-atof(p)
-register char *p;
+atof(register char *p)
@@ -12 +11 @@
-	register c;
+	register int c;
@@ -13,0 +13 @@
+	double ldexp(double value, int n);
@@ -15 +14,0 @@
-	double ldexp();
@@ -17 +16 @@
-	register eexp, exp, neg, negexp, bexp;
+	register int eexp, exp, neg, negexp, bexp;

% usr/src/libc/gen/atoi.c
@@ -1,2 +1,2 @@
-atoi(p)
-register char *p;
+int
+atoi(register char *p)
@@ -15,0 +16 @@
+			/* fallthrough */

% usr/src/libc/gen/atol.c
@@ -2,2 +2 @@
-atol(p)
-register char *p;
+atol(register char *p)
@@ -16,0 +16 @@
+			/* fallthrough */

% usr/src/libc/gen/calloc.c
@@ -2,0 +3 @@
+#include <stdio.h>
@@ -4 +4,0 @@
-#define NULL 0
@@ -7,2 +7 @@
-calloc(num, size)
-unsigned num, size;
+calloc(unsigned num, unsigned size)
@@ -11 +9,0 @@
-	char *malloc();
@@ -13 +11 @@
-	register m;
+	register int m;
@@ -26,3 +24,2 @@
-cfree(p, num, size)
-char *p;
-unsigned num, size;
+void
+cfree(char *p, unsigned num, unsigned size)
@@ -29,0 +27,2 @@
+	(void)num;
+	(void)size;

% usr/src/libc/gen/crypt.c
@@ -49 +49 @@
-static	char	PC1_D[] {
+static	char	PC1_D[] = {
@@ -97,2 +97,2 @@
-setkey(key)
-char *key;
+void
+setkey(char *key)
@@ -100 +100 @@
-	register i, j, k;
+	register int i, j, k;
@@ -146 +146 @@
-static	char	e[] {
+static	char	e[] = {
@@ -162 +162 @@
-static	char	S[8][64] {
+static	char	S[] = {
@@ -208 +208 @@
-static	char	P[] {
+static	char	P[] = {
@@ -222 +222,2 @@
-static	char	L[32], R[32];
+static	char	L[64];
+#define	R	(L+32)
@@ -235,2 +236,2 @@
-encrypt(block, edflag)
-char *block;
+void
+encrypt(char *block, int edflag)
@@ -239 +240 @@
-	register t, j, k;
+	register int t, j, k;
@@ -282 +283 @@
-			k = S[j][(preS[t+0]<<5)+
+			k = S[j*64 + (preS[t+0]<<5)+
@@ -324,3 +325 @@
-crypt(pw,salt)
-char *pw;
-char *salt;
+crypt(char *pw, char *salt)
@@ -328 +327 @@
-	register i, j, c;
+	register int i, j, c;

% usr/src/libc/gen/ctime.c
@@ -30 +30 @@
- *	Thu Jan 01 00:00:00 1970n0\\
+ *	Thu Jan 01 00:00:00 1970n0\\
@@ -67,2 +67,2 @@
-	5,	333,	/* 1974: Jan 6 - last Sun. in Nov */
-	58,	303,	/* 1975: Last Sun. in Feb - last Sun in Oct */
+	{ 5,  333 },	/* 1974: Jan 6 - last Sun. in Nov */
+	{ 58, 303 },	/* 1975: Last Sun. in Feb - last Sun in Oct */
@@ -72 +72 @@
-char		*ct_numb();
+static char	*ct_numb();
@@ -76,0 +77,3 @@
+static int	sunday(register struct tm *t, register int d);
+int	dysize(int y);
+int	ftime(struct timeb *tp);
@@ -79,2 +82 @@
-ctime(t)
-long *t;
+ctime(long *t)
@@ -86,2 +88 @@
-localtime(tim)
-long *tim;
+localtime(long *tim)
@@ -91 +92 @@
-	register daylbegin, daylend;
+	register int daylbegin, daylend;
@@ -122,4 +123,2 @@
-static
-sunday(t, d)
-register struct tm *t;
-register int d;
+static int
+sunday(register struct tm *t, register int d)
@@ -133,2 +132 @@
-gmtime(tim)
-long *tim;
+gmtime(long *tim)
@@ -195,2 +193 @@
-asctime(t)
-struct tm *t;
+asctime(struct tm *t)
@@ -202 +199,2 @@
-	for (ncp = "Day Mon 00 00:00:00 1900\n"; *cp++ = *ncp++;);
+	for (ncp = "Day Mon 00 00:00:00 1900\n"; (*cp++ = *ncp++);)
+		;
@@ -227 +225,2 @@
-dysize(y)
+int
+dysize(int y)
@@ -235,2 +234 @@
-ct_numb(cp, n)
-register char *cp;
+ct_numb(register char *cp, int n)

% usr/src/libc/gen/ctype_.c
@@ -3 +3 @@
-char _ctype_[] = {
+char _ctype_[1+256] = {

% usr/src/libc/gen/cuexit.c usr/src/libc/gen/cuexit.s
@@ -1,16 +1,8 @@
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
-
+extern void _exit(int n);
+extern void _cleanup(void);
+void
+exit(int n)
+{
+	_cleanup();
+	_exit(n);
+}

% usr/src/libc/gen/ecvt.c
@@ -8 +8 @@
-char	*cvt();
+static char	*cvt(double, int, int *, int *, int);
@@ -12,3 +12 @@
-ecvt(arg, ndigits, decpt, sign)
-double arg;
-int ndigits, *decpt, *sign;
+ecvt(double arg, int ndigits, int *decpt, int *sign)
@@ -20,3 +18 @@
-fcvt(arg, ndigits, decpt, sign)
-double arg;
-int ndigits, *decpt, *sign;
+fcvt(double arg, int ndigits, int *decpt, int *sign)
@@ -28,3 +24 @@
-cvt(arg, ndigits, decpt, sign, eflag)
-double arg;
-int ndigits, *decpt, *sign;
+cvt(double arg, int ndigits, int *decpt, int *sign, int eflag)
@@ -36 +30 @@
-	double modf();
+	double modf(double value, double *iptr);

% usr/src/libc/gen/errlst.c

% usr/src/libc/gen/execvp.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -5,0 +7 @@
+#include <stdarg.h>
@@ -9,2 +11,2 @@
-char	*execat(), *getenv();
-extern	errno;
+static char	*execat(register char *s1, register char *s2, char *si);
+extern	int errno;
@@ -12,2 +14,2 @@
-execlp(name, argv)
-char *name, *argv;
+int
+execlp(char *name, char *arg0, ...)
@@ -15 +17,21 @@
-	return(execvp(name, &argv));
+	va_list ap;
+	char **argv;
+	int i, n, r;
+
+	n = 1;
+	va_start(ap, arg0);
+	while(va_arg(ap, char *) != 0)
+		n++;
+	va_end(ap);
+
+	argv = (char **)malloc((unsigned)((n+1) * sizeof(char *)));
+	if(argv == 0)
+		return(-1);
+	argv[0] = arg0;
+	va_start(ap, arg0);
+	for(i=1; i<=n; i++)
+		argv[i] = va_arg(ap, char *);
+	va_end(ap);
+	r = execvp(name, argv);
+	free((char *)argv);
+	return(r);
@@ -18,2 +40,2 @@
-execvp(name, argv)
-char *name, **argv;
+int
+execvp(char *name, char **argv)
@@ -27 +49 @@
-	register eacces = 0;
+	register int eacces = 0;
@@ -41 +63 @@
-			for (i=1; newargs[i+1]=argv[i]; i++) {
+			for (i=1; (newargs[i+1]=argv[i]); i++) {
@@ -68,3 +90 @@
-execat(s1, s2, si)
-register char *s1, *s2;
-char *si;
+execat(register char *s1, register char *s2, char *si)

% usr/src/libc/gen/frexp.c usr/src/libc/gen/frexp11.s
@@ -1,4 +1,5 @@
-/  double frexp(x, ip)
-/  double x; int *ip;
-/  returns a fractional part 1/16 <= |value| < 1
-/ and stores an exponent so x = value * 2^(*ip)
+double
+frexp(double value, int *eptr)
+{
+	union { double d; unsigned int u[2]; } u;
+	int exp;
@@ -6,11 +7,14 @@
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
+	u.d = value;
+	exp = (int)((u.u[1] >> 20) & 0x7ff);
+	if (value == 0.0) {
+		*eptr = 0;
+		return (0.0);
+	}
+	if (exp == 0x7ff) {
+		*eptr = 0;
+		return (value);
+	}
+	*eptr = exp - 1022;
+	u.u[1] = (u.u[1] & 0x800fffffU) | (1022U << 20);
+	return (u.d);
+}

% usr/src/libc/gen/getenv.c
@@ -7 +7 @@
-char	*nvmatch();
+static char	*nvmatch(register char *s1, register char *s2);
@@ -10,2 +10 @@
-getenv(name)
-register char *name;
+getenv(register char *name)
@@ -30,2 +29 @@
-nvmatch(s1, s2)
-register char *s1, *s2;
+nvmatch(register char *s1, register char *s2)

% usr/src/libc/gen/getlogin.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -1,0 +3 @@
+extern int ttyslot(void);
@@ -4,0 +7 @@
+static	char	name[9];
@@ -7 +10 @@
-getlogin()
+getlogin(void)
@@ -9 +12 @@
-	register me, uf;
+	register int me, uf;
@@ -16 +19 @@
-	lseek( uf, (long)(me*sizeof(ubuf)), 0 );
+	lseek( uf, (long)(me*(int)sizeof(ubuf)), 0 );
@@ -20,2 +23,3 @@
-	ubuf.ut_name[8] = ' ';
-	for (cp=ubuf.ut_name; *cp++!=' ';)
+	strncpy(name, ubuf.ut_name, 8);
+	name[8] = ' ';
+	for (cp=name; *cp++!=' ';)
@@ -24 +28 @@
-	return( ubuf.ut_name );
+	return(name);

% usr/src/libc/gen/index.c
@@ -9,2 +9 @@
-index(sp, c)
-register char *sp, c;
+index(register char *sp, int c)
@@ -13 +12 @@
-		if (*sp == c)
+		if (*sp == (char)c)

% usr/src/libc/gen/isatty.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -7 +8,2 @@
-isatty(f)
+int
+isatty(int f)

% usr/src/libc/gen/l3.c
@@ -4,4 +4,2 @@
-ltol3(cp, lp, n)
-char	*cp;
-long	*lp;
-int	n;
+int
+ltol3(char *cp, long *lp, int n)
@@ -9 +7 @@
-	register i;
+	register int i;
@@ -22 +19,0 @@
-		b++;
@@ -24,0 +22 @@
+		b++;
@@ -26,0 +25 @@
+	return(0);
@@ -29,4 +28,2 @@
-l3tol(lp, cp, n)
-long	*lp;
-char	*cp;
-int	n;
+int
+l3tol(long *lp, char *cp, int n)
@@ -34 +31 @@
-	register i;
+	register int i;
@@ -47 +43,0 @@
-		*a++ = 0;
@@ -49,0 +46 @@
+		*a++ = 0;
@@ -51,0 +49 @@
+	return(0);

% usr/src/libc/gen/ldexp.c usr/src/libc/gen/ldexp11.s
@@ -1,3 +1,5 @@
-/ double ldexp(number, exp)
-/ double number
-/  -- returns number * 2^exp
+double
+ldexp(double value, int n)
+{
+	union { double d; unsigned int u[2]; } u;
+	int exp;
@@ -5,27 +7,19 @@
-.globl	_ldexp
-.globl	csv, cret
-
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
+	if (value == 0.0)
+		return (0.0);
+	u.d = value;
+	exp = (int)((u.u[1] >> 20) & 0x7ff);
+	if (exp == 0x7ff)
+		return (value);
+	exp += n;
+	if (exp >= 0x7ff)
+		return (value < 0 ? -1e308 * 10.0 : 1e308 * 10.0);
+	if (exp <= 0) {
+		double v;
+		u.u[1] = (u.u[1] & 0x800fffffU) | (1U << 20);
+		v = u.d;
+		while (exp <= 0) { v *= 0.5; exp++; }
+		return (v);
+	}
+	u.u[1] = (u.u[1] & 0x800fffffU) | ((unsigned)exp << 20);
+	return (u.d);
+}

% usr/src/libc/gen/malloc.c
@@ -64,2 +64,2 @@
-	register nw;
-	static temp;	/*coroutines assume no auto*/
+	register int nw;
+	static int temp;	/*coroutines assume no auto*/
@@ -124,0 +125 @@
+void

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
@@ -1,4 +1,5 @@
-/ double modf(x, *fp)
-/ double x, *fp;
-/ return fractional part
-/ stash integer part (as double)
+double
+modf(double value, double *iptr)
+{
+	double ipart;
+	long ll;
@@ -6,10 +7,14 @@
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
+	if (value < 0.0) {
+		double r = modf(-value, &ipart);
+		*iptr = -ipart;
+		return (-r);
+	}
+	if (value >= 9.2233720368547758e18) {
+		*iptr = value;
+		return (0.0);
+	}
+	ll = (long)value;
+	ipart = (double)ll;
+	*iptr = ipart;
+	return (value - ipart);
+}

% usr/src/libc/gen/nlist.c
@@ -2,2 +1,0 @@
-int a_magic[] = {A_MAGIC1, A_MAGIC2, A_MAGIC3, A_MAGIC4, 0};
-#define SPACE 100		/* number of symbols read at a time */
@@ -5,3 +3,48 @@
-nlist(name, list)
-char *name;
-struct nlist *list;
+int	open(char *, int);
+int	close(int);
+int	read(int, char *, int);
+long	lseek(int, long, int);
+#define	ELF_NIDENT	16
+#define	ELFMAG0		0177
+#define	SHT_SYMTAB	2
+#define	SHT_NOBITS	8
+#define	SHF_EXECINSTR	4
+#define	SHN_ABS		0xfff1
+struct elfhdr {
+	unsigned char	e_ident[ELF_NIDENT];
+	unsigned short	e_type;
+	unsigned short	e_machine;
+	unsigned int	e_version;
+	unsigned int	e_entry;
+	unsigned int	e_phoff;
+	unsigned int	e_shoff;
+	unsigned int	e_flags;
+	unsigned short	e_ehsize;
+	unsigned short	e_phentsize;
+	unsigned short	e_phnum;
+	unsigned short	e_shentsize;
+	unsigned short	e_shnum;
+	unsigned short	e_shstrndx;
+};
+struct elfshdr {
+	unsigned int	sh_name;
+	unsigned int	sh_type;
+	unsigned int	sh_flags;
+	unsigned int	sh_addr;
+	unsigned int	sh_offset;
+	unsigned int	sh_size;
+	unsigned int	sh_link;
+	unsigned int	sh_info;
+	unsigned int	sh_addralign;
+	unsigned int	sh_entsize;
+};
+struct elfsym {
+	unsigned int	st_name;
+	unsigned int	st_value;
+	unsigned int	st_size;
+	unsigned char	st_info;
+	unsigned char	st_other;
+	unsigned short	st_shndx;
+};
+static int
+readn(int fd, char *buf, int n)
@@ -9,5 +52,25 @@
-	register struct nlist *p, *q;
-	int f, n, m, i;
-	long sa;
-	struct exec buf;
-	struct nlist space[SPACE];
+	int nr, total;
+	total = 0;
+	while(total < n) {
+		nr = read(fd, buf + total, n - total);
+		if(nr <= 0)
+			return(total);
+		total += nr;
+	}
+	return(total);
+}
+int
+nlist(char *name, struct nlist *list)
+{
+	struct nlist *p;
+	struct elfhdr eh;
+	struct elfshdr sh;
+	struct elfsym syms[64], *sym;
+	char strbuf[10];
+	char nb[9];
+	char *sn;
+	int f, i, j, k, n, nsyms;
+	int matched;
+	unsigned int symoff, symsz;
+	unsigned int stroff;
+	int sectype[64];
@@ -22,4 +85,3 @@
-	read(f, (char *)&buf, sizeof buf);
-	for(i=0; a_magic[i]; i++)
-		if(a_magic[i] == buf.a_magic) break;
-	if(a_magic[i] == 0){
+	if(readn(f, (char *)&eh, sizeof(eh)) != sizeof(eh)
+	    || eh.e_ident[0] != ELFMAG0 || eh.e_ident[1] != 'E'
+	    || eh.e_ident[2] != 'L' || eh.e_ident[3] != 'F') {
@@ -29,5 +91,3 @@
-	sa = buf.a_text + (long)buf.a_data;
-	if(buf.a_flag != 1) sa *= 2;
-	sa += sizeof buf;
-	lseek(f, sa, 0);
-	n = buf.a_syms;
+	symoff = 0;
+	symsz = 0;
+	stroff = 0;
@@ -35,14 +95,36 @@
-	while(n){
-		m = sizeof space;
-		if(n < sizeof space)
-			m = n;
-		read(f, (char *)space, m);
-		n -= m;
-		for(q = space; (m -= sizeof(struct nlist)) >= 0; q++) {
-			for(p = list; p->n_name[0]; p++) {
-				for(i=0;i<8;i++)
-					if(p->n_name[i] != q->n_name[i]) goto cont;
-				p->n_value = q->n_value;
-				p->n_type = q->n_type;
-				break;
-		cont:		;
+	for(i = 0; i < eh.e_shnum && i < 64; i++) {
+		lseek(f, (long)(eh.e_shoff + i * eh.e_shentsize), 0);
+		if(readn(f, (char *)&sh, sizeof(sh)) != sizeof(sh)) {
+			close(f);
+			return(-1);
+		}
+		if(sh.sh_flags & SHF_EXECINSTR)
+			sectype[i] = N_TEXT;
+		else if(sh.sh_type == SHT_NOBITS)
+			sectype[i] = N_BSS;
+		else
+			sectype[i] = N_DATA;
+		if(sh.sh_type == SHT_SYMTAB) {
+			symoff = sh.sh_offset;
+			symsz = sh.sh_size;
+			lseek(f, (long)(eh.e_shoff + sh.sh_link * eh.e_shentsize), 0);
+			if(readn(f, (char *)&sh, sizeof(sh)) != sizeof(sh)) {
+				close(f);
+				return(-1);
+			}
+			stroff = sh.sh_offset;
+		}
+	}
+	if(symoff == 0 || stroff == 0) {
+		close(f);
+		return(-1);
+	}
+	nsyms = (int)(symsz / sizeof(syms[0]));
+	for(i = 0; i < nsyms; i++) {
+		if(i % 64 == 0) {
+			n = nsyms - i < 64 ? nsyms - i : 64;
+			n *= sizeof(syms[0]);
+			lseek(f, (long)(symoff + i * sizeof(syms[0])), 0);
+			if(readn(f, (char *)syms, n) != n) {
+				close(f);
+				return(-1);
@@ -49,0 +132,35 @@
+		}
+		sym = &syms[i % 64];
+		if(sym->st_name == 0)
+			continue;
+		lseek(f, (long)(stroff + sym->st_name), 0);
+		k = readn(f, strbuf, 9);
+		if(k <= 0) {
+			close(f);
+			return(-1);
+		}
+		strbuf[k] = '\0';
+		for(p = list; p->n_name[0]; p++) {
+			for(j = 0; j < 8; j++)
+				nb[j] = p->n_name[j];
+			nb[8] = '\0';
+			sn = nb;
+			if(*sn == '_')
+				sn++;
+			matched = 1;
+			for(j = 0; sn[j]; j++)
+				if(sn[j] != strbuf[j]) {
+					matched = 0;
+					break;
+				}
+			if(!matched || strbuf[j] != '\0')
+				continue;
+			p->n_value = sym->st_value;
+			if(sym->st_shndx == SHN_ABS)
+				p->n_type = N_ABS;
+			else if(sym->st_shndx == 0 || sym->st_shndx >= 64)
+				p->n_type = N_UNDF;
+			else
+				p->n_type = sectype[sym->st_shndx];
+			if(sym->st_info >> 4)
+				p->n_type |= N_EXT;

% usr/src/libc/gen/perror.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -6,5 +7,5 @@
-int	errno;
-int	sys_nerr;
-char	*sys_errlist[];
-perror(s)
-char *s;
+extern int	errno;
+extern int	sys_nerr;
+extern char	*sys_errlist[];
+void
+perror(char *s)
@@ -13 +14 @@
-	register n;
+	register int n;

% usr/src/libc/gen/qsort.c
@@ -3,0 +4,3 @@
+static void qs1(char *a, char *l);
+static void qsexc(char *i, char *j);
+static void qstexc(char *i, char *j, char *k);
@@ -5,5 +8,2 @@
-qsort(a, n, es, fc)
-char *a;
-unsigned n;
-int es;
-int (*fc)();
+void
+qsort(void *a, unsigned n, int es, int (*fc)())
@@ -13 +13 @@
-	qs1(a, a+n*es);
+	qs1(a, (char *)a+n*es);
@@ -16,2 +16,2 @@
-static qs1(a, l)
-char *a, *l;
+static void
+qs1(char *a, char *l)
@@ -20,2 +20 @@
-	register es;
-	char **k;
+	register int es;
@@ -30 +29 @@
-	if((n=l-a) <= es)
+	if((n=l-a) <= (unsigned)es)
@@ -87,2 +86,2 @@
-static qsexc(i, j)
-char *i, *j;
+static void
+qsexc(char *i, char *j)
@@ -103,2 +102,2 @@
-static qstexc(i, j, k)
-char *i, *j, *k;
+static void
+qstexc(char *i, char *j, char *k)

% usr/src/libc/gen/rand.c
@@ -3,2 +3,2 @@
-srand(x)
-unsigned x;
+void
+srand(unsigned x)
@@ -9 +9,2 @@
-rand()
+int
+rand(void)

% usr/src/libc/gen/rindex.c
@@ -9,2 +9 @@
-rindex(sp, c)
-register char *sp, c;
+rindex(register char *sp, int c)
@@ -16 +15 @@
-		if (*sp == c)
+		if (*sp == (char)c)

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
@@ -42,0 +7,7 @@
+.globl longjmp
+longjmp:
+	ldmia r0, {r4-r11, sp, lr}
+	mov r0, r1
+	cmp r0, #0
+	moveq r0, #1
+	bx lr

% usr/src/libc/gen/sleep.c
@@ -4,0 +5,4 @@
+static void sleepx(int signo);
+int	signal();
+extern int alarm(int n);
+extern int pause(void);
@@ -6,2 +10,2 @@
-sleep(n)
-unsigned n;
+unsigned
+sleep(volatile unsigned n)
@@ -9,3 +13,2 @@
-	int sleepx();
-	unsigned altime;
-	int (*alsig)() = SIG_DFL;
+	volatile unsigned altime;
+	volatile int alsig = SIG_DFL;
@@ -14 +17 @@
-		return;
+		return(0);
@@ -19 +22 @@
-		return;
+		return(0);
@@ -29 +32 @@
-	alsig = signal(SIGALRM, sleepx);
+	alsig = signal(SIGALRM, (int)sleepx);
@@ -36,2 +39,2 @@
-static
-sleepx()
+static void
+sleepx(int signo)
@@ -38,0 +42 @@
+	(void)signo;

% usr/src/libc/gen/strcat.c
@@ -7,2 +7 @@
-strcat(s1, s2)
-register char *s1, *s2;
+strcat(register char *s1, register char *s2)
@@ -16 +15 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strcmp.c
@@ -5,2 +5,2 @@
-strcmp(s1, s2)
-register char *s1, *s2;
+int
+strcmp(register char *s1, register char *s2)

% usr/src/libc/gen/strcpy.c
@@ -7,2 +7 @@
-strcpy(s1, s2)
-register char *s1, *s2;
+strcpy(register char *s1, register char *s2)
@@ -13 +12 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strlen.c
@@ -6,2 +6,2 @@
-strlen(s)
-register char *s;
+int
+strlen(register const char *s)
@@ -9 +9 @@
-	register n;
+	register int n;

% usr/src/libc/gen/strncat.c
@@ -8,3 +8 @@
-strncat(s1, s2, n)
-register char *s1, *s2;
-register n;
+strncat(register char *s1, register char *s2, register int n)
@@ -18 +16 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strncmp.c
@@ -5,3 +5,2 @@
-strncmp(s1, s2, n)
-register char *s1, *s2;
-register n;
+int
+strncmp(register char *s1, register char *s2, register int n)

% usr/src/libc/gen/strncpy.c
@@ -7,2 +7 @@
-strncpy(s1, s2, n)
-register char *s1, *s2;
+strncpy(register char *s1, register char *s2, int n)
@@ -10 +9 @@
-	register i;
+	register int i;

% usr/src/libc/gen/stty.c
@@ -1,3 +0,0 @@
-/*
- * Writearound to old stty and gtty system calls
- */
@@ -7,5 +4 @@
-stty(fd, ap)
-struct sgtty *ap;
-{
-	return(ioctl(fd, TIOCSETP, ap));
-}
+int ioctl(int, int, char *);
@@ -13,2 +6,2 @@
-gtty(fd, ap)
-struct sgtty *ap;
+int
+stty(int fd, struct sgttyb *ap)
@@ -16 +9 @@
-	return(ioctl(fd, TIOCGETP, ap));
+	return(ioctl(fd, TIOCSETP, (char *)ap));

% usr/src/libc/gen/swab.c
@@ -6,3 +6,2 @@
-swab(pf, pt, n)
-register short *pf, *pt;
-register n;
+void
+swab(register short *pf, register short *pt, register int n)

% usr/src/libc/gen/tell.c
@@ -5 +5 @@
-long	lseek();
+extern long lseek(int, long, int);
@@ -7 +7 @@
-long tell(f)
+long tell(int f)

% usr/src/libc/gen/timezone.c
@@ -8,0 +9 @@
+#include <stdio.h>
@@ -15,7 +16,7 @@
-	4*60, "AST", "ADT",		/* Atlantic */
-	5*60, "EST", "EDT",		/* Eastern */
-	6*60, "CST", "CDT",		/* Central */
-	7*60, "MST", "MDT",		/* Mountain */
-	8*60, "PST", "PDT",		/* Pacific */
-	0, "GMT", 0,			/* Greenwich */
-	-1
+	{ 4*60, "AST", "ADT" },		/* Atlantic */
+	{ 5*60, "EST", "EDT" },		/* Eastern */
+	{ 6*60, "CST", "CDT" },		/* Central */
+	{ 7*60, "MST", "MDT" },		/* Mountain */
+	{ 8*60, "PST", "PDT" },		/* Pacific */
+	{ 0,    "GMT", 0 },		/* Greenwich */
+	{ -1,   0,     0 }
@@ -24 +25 @@
-char *timezone(zone, dst)
+char *timezone(int zone, int dst)

% usr/src/libc/gen/ttyname.c
@@ -7,0 +8 @@
+#include <stdio.h>
@@ -13,2 +14,2 @@
-char	*strcpy();
-char	*strcat();
+char	*strcpy(char *a, char *b);
+char	*strcat(char *a, char *b);
@@ -17 +18 @@
-ttyname(f)
+ttyname(int f)
@@ -23 +24 @@
-	register df;
+	register int df;

% usr/src/libc/gen/ttyslot.c
@@ -6,0 +7 @@
+#include <stdio.h>
@@ -8,3 +9,3 @@
-char	*ttyname();
-char	*getttys();
-char	*rindex();
+char	*ttyname(int f);
+static char	*getttys(int f);
+char	*rindex(char *sp, int c);
@@ -15 +16,2 @@
-ttyslot()
+int
+ttyslot(void)
@@ -18 +20 @@
-	register s, tf;
+	register int s, tf;
@@ -29 +31 @@
-	while (tp = getttys(tf)) {
+	while ((tp = getttys(tf))) {
@@ -41 +43 @@
-getttys(f)
+getttys(int f)

% usr/src/libc/memcpy.c /dev/null
@@ -0,0 +1,23 @@
+char *
+memcpy(char *d, char *s, unsigned n)
+{
+	register char *p;
+	register unsigned i;
+
+	p = d;
+	for (i = 0; i < n; i++)
+		*p++ = *s++;
+	return(d);
+}
+
+char *
+memset(char *d, int c, unsigned n)
+{
+	register char *p;
+	register unsigned i;
+
+	p = d;
+	for (i = 0; i < n; i++)
+		*p++ = (char)c;
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
@@ -3,321 +4,350 @@
-width=-8.
-formp=-10.
-rjust=-12.
-ndfnd=-14.
-ndigit=-16.
-zfill=-18.
-.globl	__doprnt
-
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
+extern void _strout(char *string, int count, int adjust, FILE *file, int fillch);
+
+static int
+sputn(char *buf, long n, int base, int upper)
+{
+	char tmp[34];
+	int len, c;
+	unsigned long u;
+	int neg;
+
+	neg = 0;
+	if (base == 10 && n < 0) {
+		neg = 1;
+		u = (unsigned long)(-n);
+	} else
+		u = (unsigned long)n;
+	len = 0;
+	if (u == 0)
+		tmp[len++] = '0';
+	else while (u) {
+		c = (int)(u % (unsigned long)base);
+		tmp[len++] = c < 10 ? c + '0'
+				    : c - 10 + (upper ? 'A' : 'a');
+		u /= (unsigned long)base;
+	}
+	if (neg)
+		tmp[len++] = '-';
+	{
+		int i;
+		for (i = 0; i < len; i++)
+			buf[i] = tmp[len - 1 - i];
+	}
+	return(len);
+}
+
+static int
+fputn(char *buf, double v, int prec, int upper)
+{
+	int len, i, neg, digit;
+	long ipart;
+	double frac, pow10;
+	union { double d; unsigned long u[2]; } u;
+
+	len = 0;
+	u.d = v;
+	{
+		unsigned long hi = u.u[1];
+		unsigned long lo = u.u[0];
+		unsigned int exp = (hi >> 20) & 0x7ff;
+		unsigned long mant_hi = hi & 0xfffff;
+		int sign = (hi >> 31) & 1;
+		if (exp == 0x7ff) {
+			if (mant_hi == 0 && lo == 0) {
+				if (sign) buf[len++] = '-';
+				buf[len++] = upper ? 'I' : 'i';
+				buf[len++] = upper ? 'N' : 'n';
+				buf[len++] = upper ? 'F' : 'f';
+			} else {
+				buf[len++] = upper ? 'N' : 'n';
+				buf[len++] = upper ? 'A' : 'a';
+				buf[len++] = upper ? 'N' : 'n';
+			}
+			return(len);
+		}
+	}
+
+	neg = 0;
+	if (v < 0.0) {
+		neg = 1;
+		v = -v;
+	}
+
+	pow10 = 1.0;
+	for (i = 0; i < prec; i++)
+		pow10 = pow10 * 10.0;
+	v = v + 0.5 / pow10;
+
+	if (v >= 2147483647.0) {
+		if (neg) buf[len++] = '-';
+		buf[len++] = 'o';
+		buf[len++] = 'v';
+		buf[len++] = 'f';
+		return(len);
+	}
+
+	ipart = (long)v;
+	frac = v - (double)ipart;
+	if (frac < 0.0)
+		frac = 0.0;
+
+	if (neg)
+		buf[len++] = '-';
+	len += sputn(buf + len, (long)ipart, 10, 0);
+	if (prec > 0) {
+		buf[len++] = '.';
+		for (i = 0; i < prec; i++) {
+			frac = frac * 10.0;
+			digit = (int)frac;
+			if (digit < 0) digit = 0;
+			if (digit > 9) digit = 9;
+			buf[len++] = (char)('0' + digit);
+			frac = frac - (double)digit;
+		}
+	}
+	return(len);
+}
+
+static int
+eputn(char *buf, double v, int prec, int upper)
+{
+	int len, i, neg, exp10, sign_e, digit;
+	long ipart;
+	double frac;
+	union { double d; unsigned long u[2]; } u;
+
+	len = 0;
+	u.d = v;
+	{
+		unsigned long hi = u.u[1];
+		unsigned long lo = u.u[0];
+		unsigned int exp = (hi >> 20) & 0x7ff;
+		unsigned long mant_hi = hi & 0xfffff;
+		int sign = (hi >> 31) & 1;
+		if (exp == 0x7ff) {
+			if (mant_hi == 0 && lo == 0) {
+				if (sign) buf[len++] = '-';
+				buf[len++] = upper ? 'I' : 'i';
+				buf[len++] = upper ? 'N' : 'n';
+				buf[len++] = upper ? 'F' : 'f';
+			} else {
+				buf[len++] = upper ? 'N' : 'n';
+				buf[len++] = upper ? 'A' : 'a';
+				buf[len++] = upper ? 'N' : 'n';
+			}
+			return(len);
+		}
+	}
+
+	neg = 0;
+	if (v < 0.0) {
+		neg = 1;
+		v = -v;
+	}
+	exp10 = 0;
+	if (v != 0.0) {
+		while (v >= 10.0) {
+			v = v / 10.0;
+			exp10++;
+			if (exp10 > 308) break;
+		}
+		while (v < 1.0) {
+			v = v * 10.0;
+			exp10--;
+			if (exp10 < -308) break;
+		}
+	}
+	{
+		double p = 1.0;
+		for (i = 0; i < prec; i++) p = p * 10.0;
+		v = v + 0.5 / p;
+		if (v >= 10.0) { v = v / 10.0; exp10++; }
+	}
+	if (neg) buf[len++] = '-';
+	ipart = (long)v;
+	if (ipart < 0) ipart = 0;
+	if (ipart > 9) ipart = 9;
+	buf[len++] = (char)('0' + ipart);
+	frac = v - (double)ipart;
+	if (frac < 0.0) frac = 0.0;
+	if (prec > 0) {
+		buf[len++] = '.';
+		for (i = 0; i < prec; i++) {
+			frac = frac * 10.0;
+			digit = (int)frac;
+			if (digit < 0) digit = 0;
+			if (digit > 9) digit = 9;
+			buf[len++] = (char)('0' + digit);
+			frac = frac - (double)digit;
+		}
+	}
+	buf[len++] = upper ? 'E' : 'e';
+	sign_e = 0;
+	if (exp10 < 0) { sign_e = 1; exp10 = -exp10; }
+	buf[len++] = sign_e ? '-' : '+';
+	if (exp10 < 10) buf[len++] = '0';
+	len += sputn(buf + len, (long)exp10, 10, 0);
+	return(len);
+}
+
+void
+_doprnt(char *fmt, va_list *argp, FILE *file)
+{
+	char numbuf[64];
+	char *p, *s;
+	int c, width, prec, fillch, ladjust, lflag, base, upper, len;
+
+	for (p = fmt; *p; p++) {
+		if (*p != '%') {
+			putc(*p, file);
+			continue;
+		}
+		p++;
+		ladjust = 0;
+		fillch = ' ';
+		if (*p == '-') { ladjust = 1; p++; }
+		if (*p == '0') { fillch = '0'; p++; }
+		width = 0;
+		while (*p >= '0' && *p <= '9')
+			width = width * 10 + *p++ - '0';
+		prec = -1;
+		if (*p == '.') {
+			p++;
+			prec = 0;
+			while (*p >= '0' && *p <= '9')
+				prec = prec * 10 + *p++ - '0';
+		}
+		lflag = 0;
+		if (*p == 'l') { lflag = 1; p++; }
+		c = *p;
+		{
+			int pad;
+
+			if (c == 's') {
+				s = va_arg(*argp, char *);
+				if (s == 0)
+					s = "(null)";
+				len = 0;
+				while (s[len] && (prec < 0 || len < prec))
+					len++;
+				pad = width - len;
+				if (pad < 0)
+					pad = 0;
+				_strout(s, len, ladjust ? pad : -pad, file, fillch);
+			} else if (c == 'c') {
+				numbuf[0] = (char)va_arg(*argp, int);
+				pad = width - 1;
+				if (pad < 0)
+					pad = 0;
+				_strout(numbuf, 1, ladjust ? pad : -pad, file, fillch);
+			} else if (c == 'd' || c == 'u' || c == 'o' || c == 'x'
+			           || c == 'X' || c == 'D' || c == 'O' || c == 'U') {
+				long lv;
+				int isupper;
+
+				isupper = (c == 'X');
+				upper = isupper;
+				if (c == 'd') base = 10;
+				else if (c == 'u' || c == 'U') base = 10;
+				else if (c == 'o' || c == 'O') base = 8;
+				else if (c == 'x' || c == 'X') base = 16;
+				else base = 10;
+				if (c == 'D' || c == 'O' || c == 'U' || c == 'X' || lflag) {
+					if (c == 'd' || c == 'D')
+						lv = va_arg(*argp, long);
+					else
+						lv = (long)va_arg(*argp, unsigned long);
+				} else if (c == 'd')
+					lv = (long)va_arg(*argp, int);
+				else
+					lv = (long)va_arg(*argp, unsigned);
+				len = sputn(numbuf, lv, base, upper);
+				if (prec > len) {
+					int i;
+					char tmp[34];
+					for (i = 0; i < len; i++)
+						tmp[i] = numbuf[i];
+					for (i = 0; i < prec - len; i++)
+						numbuf[i] = '0';
+					for (i = 0; i < len; i++)
+						numbuf[prec - len + i] = tmp[i];
+					len = prec;
+				}
+				pad = width - len;
+				if (pad < 0)
+					pad = 0;
+				_strout(numbuf, len, ladjust ? pad : -pad, file, fillch);
+			} else if (c == 'f' || c == 'F' || c == 'e' || c == 'E'
+				   || c == 'g' || c == 'G') {
+				double dv;
+				int isupper;
+
+				isupper = (c == 'F' || c == 'E' || c == 'G');
+				if (prec < 0)
+					prec = 6;
+				dv = va_arg(*argp, double);
+				if (c == 'f' || c == 'F') {
+					len = fputn(numbuf, dv, prec, isupper);
+				} else if (c == 'e' || c == 'E') {
+					len = eputn(numbuf, dv, prec, isupper);
+				} else {
+					double av = dv < 0.0 ? -dv : dv;
+					int exp10 = 0;
+					if (av != 0.0) {
+						while (av >= 10.0) {
+							av = av / 10.0;
+							exp10++;
+							if (exp10 > 308) break;
+						}
+						while (av < 1.0) {
+							av = av * 10.0;
+							exp10--;
+							if (exp10 < -308) break;
+						}
+					}
+					if (prec == 0) prec = 1;
+					if (exp10 < -4 || exp10 >= prec)
+						len = eputn(numbuf, dv, prec - 1, isupper);
+					else
+						len = fputn(numbuf, dv, prec - 1 - exp10, isupper);
+					/* Trim trailing zeros from fraction.  Stop at the
+					 * '.', then drop it too.  Walk backwards over the
+					 * mantissa portion; for %e variant, preserve the
+					 * 'e<exp>' tail. */
+					{
+						int end = len, etail = len, i;
+						char ec = isupper ? 'E' : 'e';
+						for (i = 0; i < len; i++)
+							if (numbuf[i] == ec) { end = i; break; }
+						etail = end;
+						if (end > 0) {
+							int has_dot = 0;
+							for (i = 0; i < end; i++)
+								if (numbuf[i] == '.') { has_dot = 1; break; }
+							if (has_dot) {
+								while (end > 0 && numbuf[end-1] == '0')
+									end--;
+								if (end > 0 && numbuf[end-1] == '.')
+									end--;
+							}
+						}
+						if (end != etail) {
+							int tail = len - etail;
+							for (i = 0; i < tail; i++)
+								numbuf[end + i] = numbuf[etail + i];
+							len = end + tail;
+						}
+					}
+				}
+				pad = width - len;
+				if (pad < 0)
+					pad = 0;
+				_strout(numbuf, len, ladjust ? pad : -pad, file, fillch);
+			} else if (c == '%') {
+				putc('%', file);
+			} else {
+				putc(c, file);
+			}
+		}
+	}
+}

% usr/src/libc/stdio/doscan.c
@@ -2,0 +3 @@
+#include	<stdarg.h>
@@ -13 +14,3 @@
-char	*_getccl();
+static char	*_getccl(register char *s);
+static int	_innum(int **ptr, int type, int len, int size, struct _iobuf *iop, int *eofptr);
+static int	_instr(register char *ptr, int type, int len, register struct _iobuf *iop, int *eofptr);
@@ -26,4 +29,2 @@
-_doscan(iop, fmt, argp)
-FILE *iop;
-register char *fmt;
-register int **argp;
+int
+_doscan(FILE *iop, register char *fmt, va_list *argp)
@@ -30,0 +32 @@
+	int *slot;
@@ -44,3 +46,4 @@
-		if (ch != '*')
-			ptr = argp++;
-		else
+		if (ch != '*') {
+			slot = va_arg(*argp, int *);
+			ptr = &slot;
+		} else
@@ -97,3 +100,2 @@
-_innum(ptr, type, len, size, iop, eofptr)
-int **ptr, *eofptr;
-struct _iobuf *iop;
+static int
+_innum(int **ptr, int type, int len, int size, struct _iobuf *iop, int *eofptr)
@@ -101 +103 @@
-	extern double atof();
+	extern double atof(char *s);
@@ -104 +106 @@
-	register c, base;
+	register int c, base;
@@ -135 +137 @@
-		 || base==16 && ('a'<=c && c<='f' || 'A'<=c && c<='F')) {
+		 || (base==16 && (('a'<=c && c<='f') || ('A'<=c && c<='F')))) {
@@ -205,4 +207,2 @@
-_instr(ptr, type, len, iop, eofptr)
-register char *ptr;
-register struct _iobuf *iop;
-int *eofptr;
+static int
+_instr(register char *ptr, int type, int len, register struct _iobuf *iop, int *eofptr)
@@ -210 +210 @@
-	register ch;
+	register int ch;
@@ -250,3 +250,2 @@
-char *
-_getccl(s)
-register char *s;
+static char *
+_getccl(register char *s)
@@ -254 +253 @@
-	register c, t;
+	register int c, t;

% usr/src/libc/stdio/endopen.c
@@ -2,0 +3 @@
+static int create(register char *file, int rw);
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
@@ -15 +14 @@
-	FILE *_findiop();
+	FILE *_findiop(void);
@@ -30 +29 @@
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
@@ -3 +3 @@
-char	*malloc();
+char	*malloc(unsigned n);
@@ -7,2 +7 @@
-_filbuf(iop)
-	register FILE *iop;
+_filbuf(register FILE *iop)
@@ -21 +20 @@
-			iop->_base = &smallbuf[fileno(iop)];
+			iop->_base = &smallbuf[(unsigned char)fileno(iop)];

% usr/src/libc/stdio/findiop.c
@@ -4 +4 @@
-_findiop()
+_findiop(void)

% usr/src/libc/stdio/flsbuf.c
@@ -3 +3 @@
-char	*malloc();
+char	*malloc(unsigned n);
@@ -6,3 +6 @@
-_flsbuf(c, iop)
-	int c;
-	register FILE *iop;
+_flsbuf(int c, register FILE *iop)
@@ -11 +9 @@
-	register n, rn;
+	register int n, rn;
@@ -59,2 +57 @@
-fflush(iop)
-	register FILE *iop;
+fflush(register FILE *iop)
@@ -63 +60 @@
-	register n;
+	register int n;
@@ -81 +78,2 @@
-_cleanup()
+void
+_cleanup(void)
@@ -91,2 +89 @@
-fclose(iop)
-	register FILE *iop;
+fclose(register FILE *iop)
@@ -94 +91 @@
-	register r;
+	register int r;
@@ -107,2 +104,2 @@
-	iop->_flag &=
-		~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG|_IORW);
+	iop->_flag = (char)(iop->_flag &
+		~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG|_IORW));

% usr/src/libc/stdio/fopen.c
@@ -4,2 +4 @@
-fopen(file, mode)
-	char *file, *mode;
+fopen(char *file, char *mode)
@@ -7 +6,2 @@
-	FILE *_findiop(), *_endopen();
+	FILE *_findiop(void);
+	FILE *_endopen(char *file, char *mode, register FILE *iop);

% usr/src/libc/stdio/fprintf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+extern void _doprnt(char *fmt, va_list *adx, FILE *file);
@@ -3,3 +5,2 @@
-fprintf(iop, fmt, args)
-FILE *iop;
-char *fmt;
+int
+fprintf(FILE *iop, char *fmt, ...)
@@ -7 +8,4 @@
-	_doprnt(fmt, &args, iop);
+	va_list ap;
+	va_start(ap, fmt);
+	_doprnt(fmt, &ap, iop);
+	va_end(ap);

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
@@ -8 +6 @@
-	FILE *_endopen();
+	FILE *_endopen(char *file, char *mode, register FILE *iop);

% usr/src/libc/stdio/fseek.c
@@ -7 +7 @@
-long lseek();
+long lseek(int fd, long offset, int ptrname);
@@ -9,3 +9,2 @@
-fseek(iop, offset, ptrname)
-	register FILE *iop;
-	long offset;
+int
+fseek(register FILE *iop, long offset, int ptrname)
@@ -14 +13 @@
-	long p;
+	long p = -1;

% usr/src/libc/stdio/ftell.c
@@ -7 +7 @@
-long	lseek();
+long	lseek(int fd, long offset, int ptrname);
@@ -10,2 +10 @@
-long ftell(iop)
-FILE *iop;
+long ftell(FILE *iop)
@@ -14 +13 @@
-	register adjust;
+	register int adjust;

% usr/src/libc/stdio/gcvt.c
@@ -6 +6 @@
-char	*ecvt();
+char	*ecvt(double arg, int ndigits, int *decpt, int *sign);
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

% usr/src/libc/stdio/getchar.c
@@ -8 +8,2 @@
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
@@ -15 +13,0 @@
-	int (*signal())();
@@ -22 +20 @@
-	sig = signal(SIGINT, SIG_IGN);
+	sig = (int (*)())signal(SIGINT, (int)SIG_IGN);
@@ -36 +34 @@
-	signal(SIGINT, sig);
+	signal(SIGINT, (int)sig);

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
+	i |= (unsigned)getc(iop)<<8;
+	i |= (unsigned)getc(iop)<<16;
+	return(i | (unsigned)getc(iop)<<24);

% usr/src/libc/stdio/popen.c
@@ -14 +14,2 @@
-	register myside, hisside, pid;
+	register int myside, hisside, pid;
+	int stdside;
@@ -23 +24,3 @@
-		dup2(hisside, tst(0, 1));
+		stdside = tst(0, 1);
+		close(stdside);
+		dup(hisside);
@@ -34,0 +38 @@
+int
@@ -38 +42 @@
-	register f, r, (*hstat)(), (*istat)(), (*qstat)();
+	register int f, r, (*hstat)(), (*istat)(), (*qstat)();
@@ -43,3 +47,3 @@
-	istat = signal(SIGINT, SIG_IGN);
-	qstat = signal(SIGQUIT, SIG_IGN);
-	hstat = signal(SIGHUP, SIG_IGN);
+	istat = (int (*)())signal(SIGINT, (int)SIG_IGN);
+	qstat = (int (*)())signal(SIGQUIT, (int)SIG_IGN);
+	hstat = (int (*)())signal(SIGHUP, (int)SIG_IGN);
@@ -50,3 +54,3 @@
-	signal(SIGINT, istat);
-	signal(SIGQUIT, qstat);
-	signal(SIGHUP, hstat);
+	signal(SIGINT, (int)istat);
+	signal(SIGQUIT, (int)qstat);
+	signal(SIGHUP, (int)hstat);

% usr/src/libc/stdio/printf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+extern void _doprnt(char *fmt, va_list *adx, FILE *file);
@@ -3,2 +5,2 @@
-printf(fmt, args)
-char *fmt;
+int
+printf(char *fmt, ...)
@@ -6 +8,4 @@
-	_doprnt(fmt, &args, stdout);
+	va_list ap;
+	va_start(ap, fmt);
+	_doprnt(fmt, &ap, stdout);
+	va_end(ap);

% usr/src/libc/stdio/putchar.c
@@ -8,2 +8,2 @@
-putchar(c)
-register c;
+int
+putchar(register int c)
@@ -11 +11 @@
-	putc(c, stdout);
+	return(putc(c, stdout));

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
+int
+putw(register int i, register struct _iobuf *iop)
@@ -8,0 +8,3 @@
+	putc(i>>16, iop);
+	putc(i>>24, iop);
+	return(i);

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
+int	_doscan(FILE *iop, register char *fmt, va_list *argp);
@@ -3,2 +5,2 @@
-scanf(fmt, args)
-char *fmt;
+int
+scanf(char *fmt, ...)
@@ -6 +8,6 @@
-	return(_doscan(stdin, fmt, &args));
+	va_list ap;
+	int r;
+	va_start(ap, fmt);
+	r = _doscan(stdin, fmt, &ap);
+	va_end(ap);
+	return(r);
@@ -9,3 +16,2 @@
-fscanf(iop, fmt, args)
-FILE *iop;
-char *fmt;
+int
+fscanf(FILE *iop, char *fmt, ...)
@@ -13 +19,6 @@
-	return(_doscan(iop, fmt, &args));
+	va_list ap;
+	int r;
+	va_start(ap, fmt);
+	r = _doscan(iop, fmt, &ap);
+	va_end(ap);
+	return(r);
@@ -16,3 +27,2 @@
-sscanf(str, fmt, args)
-register char *str;
-char *fmt;
+int
+sscanf(char *str, char *fmt, ...)
@@ -20,0 +31,2 @@
+	va_list ap;
+	int r;
@@ -27 +39,4 @@
-	return(_doscan(&_strbuf, fmt, &args));
+	va_start(ap, fmt);
+	r = _doscan(&_strbuf, fmt, &ap);
+	va_end(ap);
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
+extern void _doprnt(char *fmt, va_list *adx, FILE *file);
@@ -3,2 +5,2 @@
-char *sprintf(str, fmt, args)
-char *str, *fmt;
+char *
+sprintf(char *str, char *fmt, ...)
@@ -6,0 +9 @@
+	va_list ap;
@@ -11 +14,3 @@
-	_doprnt(fmt, &args, &_strbuf);
+	va_start(ap, fmt);
+	_doprnt(fmt, &ap, &_strbuf);
+	va_end(ap);

% usr/src/libc/stdio/strout.c
@@ -3,5 +3,2 @@
-_strout(string, count, adjust, file, fillch)
-register char *string;
-register count;
-int adjust;
-register struct _iobuf *file;
+void
+_strout(register char *string, register int count, int adjust, register struct _iobuf *file, int fillch)

% usr/src/libc/stdio/system.c
@@ -0,0 +1 @@
+#include	<stdio.h>
@@ -3,2 +4,2 @@
-system(s)
-char *s;
+int
+system(char *s)
@@ -13,2 +14,2 @@
-	istat = signal(SIGINT, SIG_IGN);
-	qstat = signal(SIGQUIT, SIG_IGN);
+	istat = (int (*)())signal(SIGINT, (int)SIG_IGN);
+	qstat = (int (*)())signal(SIGQUIT, (int)SIG_IGN);
@@ -19,2 +20,2 @@
-	signal(SIGINT, istat);
-	signal(SIGQUIT, qstat);
+	signal(SIGINT, (int)istat);
+	signal(SIGQUIT, (int)qstat);

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
@@ -1,5 +0,0 @@
-/ access(file, request)
-/  test ability to access file in all indicated ways
-/  1 - read
-/  2 - write
-/  4 - execute
@@ -7,3 +1,0 @@
-.globl	_access
-.globl	csv, cret
-.comm	_errno,2
@@ -11 +2,0 @@
-.access = 33.
@@ -13,14 +4,13 @@
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
+.globl access
+access:
+		mov ip, r7
+		mov r7, #33
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/acct.s
@@ -1 +0,0 @@
-/ C library -- acct
@@ -3 +1,0 @@
-/ error = acct(string);
@@ -5,3 +2,0 @@
-.globl	_acct
-.globl	cerror
-.acct = 51.
@@ -9,14 +4,13 @@
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
+.globl acct
+acct:
+		mov ip, r7
+		mov r7, #51
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/alarm.c usr/src/libc/sys/alarm.s
@@ -1 +1 @@
-/ C library - alarm
+#define S_ALARM 27
@@ -3,2 +3,3 @@
-.globl	_alarm
-.alarm = 27.
+int syscall3(int, int, int, int);
+int
+alarm(int n)
@@ -6,7 +7,3 @@
-_alarm:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.alarm
-	mov	(sp)+,r5
-	rts	pc
+{
+	return(syscall3(S_ALARM, n, 0, 0));
+}

% usr/src/libc/sys/brk.c usr/src/libc/sys/sbrk.s
@@ -1,8 +1,5 @@
-/old = sbrk(increment);
-/
-/sbrk gets increment more core, and returns a pointer
-/	to the beginning of the new core area
-/
-.globl	_sbrk, _brk
-.globl	_end, cerror
-.break = 17.
+extern char end[];
+static char *curbrk;
+int syscall3(int, int, int, int);
+int brk(char *);
+#define	S_BREAK	17
@@ -10,14 +6,0 @@
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
@@ -25,3 +8,11 @@
-/ brk(value)
-/ as described in man2.
-/ returns 0 for ok, -1 for error.
+char *
+sbrk(int n)
+{
+	char *old;
+	if(curbrk == 0)
+		curbrk = end;
+	old = curbrk;
+	if(brk(curbrk + n) < 0)
+		return((char *)-1);
+	return(old);
+}
@@ -29,12 +19,0 @@
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
@@ -42,4 +21,8 @@
-.data
-9:
-	sys	.break; 0:..
-nd:	_end
+int
+brk(char *p)
+{
+	if(syscall3(S_BREAK, (int)p, 0, 0) < 0)
+		return(-1);
+	curbrk = p;
+	return(0);
+}

% usr/src/libc/sys/chdir.s
@@ -1 +0,0 @@
-/ C library -- chdir
@@ -3 +1,0 @@
-/ error = chdir(string);
@@ -5,3 +2,0 @@
-.globl	_chdir
-.globl	cerror
-.chdir = 12.
@@ -9,14 +4,13 @@
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
+.globl chdir
+chdir:
+		mov ip, r7
+		mov r7, #12
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/chmod.s
@@ -1 +0,0 @@
-/ C library -- chmod
@@ -3 +1,0 @@
-/ error = chmod(string, mode);
@@ -5,3 +2,0 @@
-.globl	_chmod
-.globl	cerror
-.chmod = 15.
@@ -9,15 +4,13 @@
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
+.globl chmod
+chmod:
+		mov ip, r7
+		mov r7, #15
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/chown.s
@@ -1 +0,0 @@
-/ C library -- chown
@@ -3 +1,0 @@
-/ error = chown(string, owner);
@@ -5,3 +2,0 @@
-.globl	_chown,
-.globl	cerror
-.chown = 16.
@@ -9,16 +4,13 @@
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
+.globl chown
+chown:
+		mov ip, r7
+		mov r7, #16
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/chroot.s
@@ -1 +0,0 @@
-/ C library -- chroot
@@ -3 +1,0 @@
-/ error = chroot(string);
@@ -5,3 +2,0 @@
-.globl	_chroot
-.globl	cerror
-.chroot = 61.
@@ -9,14 +4,13 @@
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
+.globl chroot
+chroot:
+		mov ip, r7
+		mov r7, #61
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/close.s
@@ -1 +0,0 @@
-/ C library -- close
@@ -3 +1,0 @@
-/ error =  close(file);
@@ -5,3 +2,0 @@
-.globl	_close,
-.globl	cerror
-.close = 6.
@@ -9,11 +4,13 @@
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
+.globl close
+close:
+		mov ip, r7
+		mov r7, #6
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/creat.s
@@ -1 +0,0 @@
-/ C library -- creat
@@ -3,3 +1,0 @@
-/ file = creat(string, mode);
-/
-/ file == -1 if error
@@ -7,3 +2,0 @@
-.globl	_creat
-.globl	cerror
-.creat = 8.
@@ -11,14 +4,13 @@
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
+.globl creat
+creat:
+		mov ip, r7
+		mov r7, #8
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/dup.c usr/src/libc/sys/dup.s
@@ -1,28 +1,9 @@
-/ C library -- dup
-
-/	f = dup(of [ ,nf])
-/	f == -1 for error
-
-.globl	_dup,_dup2
-.globl	cerror
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
+#define S_DUP 41
+int syscall3(int, int, int, int);
+int
+dup(int a, int b)
+{
+	if(a & 0100)
+		return(syscall3(S_DUP, a, b, 0));
+	return(syscall3(S_DUP, a, -1, 0));
+}

% usr/src/libc/sys/execl.c usr/src/libc/sys/execl.s
@@ -1 +1,12 @@
-/ C library -- execl
+#include <stdarg.h>
+#define S_EXECE 59
+int syscall3(int, int, int, int);
+extern char **environ;
+char *malloc(unsigned nbytes);
+void free(char *ap);
+int
+execl(char *path, char *arg0, ...)
+{
+	va_list ap;
+	char **argv, *arg;
+	int i, n, r;
@@ -3,3 +14,5 @@
-/ execl(file, arg1, arg2, ... , 0);
-/
-/ environment automatically passed
+	n = 1;
+	va_start(ap, arg0);
+	while(va_arg(ap, char *) != 0)
+		n++;
+	va_end(ap);
@@ -7,17 +20,15 @@
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
+	argv = (char **)malloc((unsigned)((n+1) * sizeof(char *)));
+	if(argv == 0)
+		return(-1);
+	argv[0] = arg0;
+	va_start(ap, arg0);
+	for(i=1; i<n; i++) {
+		arg = va_arg(ap, char *);
+		argv[i] = arg;
+	}
+	va_end(ap);
+	argv[n] = 0;
+	r = syscall3(S_EXECE, (int)path, (int)argv, (int)environ);
+	free((char *)argv);
+	return(r);
+}

% usr/src/libc/sys/execv.c usr/src/libc/sys/execv.s
@@ -1,23 +1,8 @@
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
+#define S_EXECE 59
+int syscall3(int, int, int, int);
+extern char **environ;
+int
+execv(char *path, char **argv)
+{
+	return(syscall3(S_EXECE, (int)path, (int)argv, (int)environ));
+}

% usr/src/libc/sys/execve.c usr/src/libc/sys/execve.s
@@ -1,22 +1,7 @@
-/ C library -- execve
-
-/ execve(file, argv, env);
-/
-/ where argv is a vector argv[0] ... argv[x], 0
-/ last vector element must be 0
-
-.globl	_execve
-.globl	cerror
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
+#define S_EXECE 59
+int syscall3(int, int, int, int);
+int
+execve(char *path, char **argv, char **envp)
+{
+	return(syscall3(S_EXECE, (int)path, (int)argv, (int)envp));
+}

% usr/src/libc/sys/exit.s
@@ -1 +0,0 @@
-/ C library -- _exit
@@ -3,3 +1,0 @@
-/ _exit(code)
-/ code is return in r0 to system
-/ Same as plain exit, for user who want to define their own exit.
@@ -7,2 +2,0 @@
-.globl	__exit
-.exit = 1.
@@ -10,5 +3,0 @@
-__exit:
-	mov	r5,-(sp)
-	mov	sp,r5
-	mov	4(r5),r0
-	sys	.exit
@@ -15,0 +5,13 @@
+.globl _exit
+_exit:
+		mov ip, r7
+		mov r7, #1
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/fork.s
@@ -1 +0,0 @@
-/ C library -- fork
@@ -3,4 +1,0 @@
-/ pid = fork();
-/
-/ pid == 0 in child process; pid == -1 means error return
-/ in child, parents id is in par_uid if needed
@@ -8,3 +2,0 @@
-.globl	_fork, _par_uid
-.globl	cerror
-.fork = 2.
@@ -12,15 +4,13 @@
-_fork:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.fork
-		br 1f
-	bec	2f
-	jmp	cerror
-1:
-	mov	r0,_par_uid
-	clr	r0
-2:
-	mov	(sp)+,r5
-	rts	pc
-.bss
-_par_uid: .=.+2
+.globl fork
+fork:
+		mov ip, r7
+		mov r7, #2
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/fstat.s
@@ -1 +0,0 @@
-/ C library -- fstat
@@ -3 +1,0 @@
-/ error = fstat(file, statbuf);
@@ -5,3 +2,0 @@
-/ int statbuf[17] or
-/ char statbuf[34]
-/ as appropriate
@@ -9,3 +3,0 @@
-.globl	_fstat
-.globl	cerror
-.fstat = 28.
@@ -13,15 +5,13 @@
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
+.globl fstat
+fstat:
+		mov ip, r7
+		mov r7, #28
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/ftime.c usr/src/libc/sys/time.s
@@ -1 +1 @@
-/ C library -- time
+#include <sys/timeb.h>
@@ -3,35 +3,8 @@
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
+#define S_FTIME 35
+int syscall3(int, int, int, int);
+int
+ftime(struct timeb *gorpp)
+
+{
+	return(syscall3(S_FTIME, (int)gorpp, 0, 0));
+}

% usr/src/libc/sys/getgid.s
@@ -1 +0,0 @@
-/ C library -- getgid, getegid
@@ -3 +1,0 @@
-/ gid = getgid();
@@ -5,2 +2,0 @@
-.globl	_getgid
-.getgid = 47.
@@ -8,19 +4,15 @@
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
+.globl getgid
+getgid:
+	mov ip, r7
+	mov r7, #47
+	svc #0
+	mov r7, ip
+	bx lr
+.globl getegid
+getegid:
+	mov ip, r7
+	mov r7, #47
+	svc #0
+	mov r7, ip
+	mov r0, r1
+	bx lr

% usr/src/libc/sys/getpid.s
@@ -1 +0,0 @@
-/ getpid -- get process ID
@@ -3,2 +1,0 @@
-.globl	_getpid
-.getpid	= 20.
@@ -6,6 +3,20 @@
-_getpid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getpid
-	mov	(sp)+,r5
-	rts	pc
+.globl getpid
+getpid:
+	mov ip, r7
+	mov r7, #20
+	svc #0
+	mov r7, ip
+	ldr r2, =_last_ppid
+	str r1, [r2]
+	bx lr
+.globl getppid
+getppid:
+	mov ip, r7
+	mov r7, #20
+	svc #0
+	mov r7, ip
+	mov r0, r1
+	bx lr
+.data
+.globl _last_ppid
+_last_ppid: .word 0

% usr/src/libc/sys/getuid.s
@@ -1 +0,0 @@
-/ C library -- getuid, geteuid
@@ -3 +1,0 @@
-/ uid = getuid();
@@ -5,2 +2,0 @@
-.globl	_getuid
-.getuid = 24.
@@ -8,6 +3,0 @@
-_getuid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getuid
-	mov	(sp)+,r5
-	rts	pc
@@ -16,2 +5,0 @@
-/ uid = geteuid();
-/  returns effective uid
@@ -19 +6,0 @@
-.globl	_geteuid
@@ -21,7 +8,15 @@
-_geteuid:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.getuid
-	mov	r1,r0
-	mov	(sp)+,r5
-	rts	pc
+.globl getuid
+getuid:
+	mov ip, r7
+	mov r7, #24
+	svc #0
+	mov r7, ip
+	bx lr
+.globl geteuid
+geteuid:
+	mov ip, r7
+	mov r7, #24
+	svc #0
+	mov r7, ip
+	mov r0, r1
+	bx lr

% usr/src/libc/sys/gtty.c usr/src/libc/gen/stty.c
@@ -1,4 +0,0 @@
-/*
- * Writearound to old stty and gtty system calls
- */
-
@@ -6,3 +2,3 @@
-
-stty(fd, ap)
-struct sgtty *ap;
+int ioctl(int, int, char *);
+int
+gtty(int fd, struct sgttyb *ap)
@@ -10,7 +6 @@
-	return(ioctl(fd, TIOCSETP, ap));
-}
-
-gtty(fd, ap)
-struct sgtty *ap;
-{
-	return(ioctl(fd, TIOCGETP, ap));
+	return(ioctl(fd, TIOCGETP, (char *)ap));

% usr/src/libc/sys/ioctl.s
@@ -1 +0,0 @@
-/ C library -- ioctl
@@ -3,4 +1,0 @@
-/ ioctl(fdes, command, arg)
-/ struct * arg;
-/
-/ result == -1 if error
@@ -8,2 +2,0 @@
-.globl	_ioctl, cerror
-.ioctl	= 54.
@@ -11,16 +4,13 @@
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
+.globl ioctl
+ioctl:
+		mov ip, r7
+		mov r7, #54
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/kill.s
@@ -1 +0,0 @@
-/ C library -- kill
@@ -3,2 +1,0 @@
-.globl	_kill, cerror
-.kill = 37.
@@ -6,12 +2,0 @@
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
@@ -19,3 +4,13 @@
-.data
-9:
-	sys	.kill; 8:..
+.globl kill
+kill:
+		mov ip, r7
+		mov r7, #37
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/link.s
@@ -1 +0,0 @@
-/ C library -- link
@@ -3 +1,0 @@
-/ error = link(old-file, new-file);
@@ -5,3 +2,0 @@
-.globl	_link
-.globl	cerror
-.link = 9.
@@ -9,15 +4,13 @@
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
+.globl link
+link:
+		mov ip, r7
+		mov r7, #9
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/lock.s
@@ -1 +0,0 @@
-/ lock -- C library
@@ -3 +1,0 @@
-/	lock(f)
@@ -5 +2,0 @@
-.globl	_lock, cerror
@@ -7 +3,0 @@
-.lock = 53.
@@ -9,14 +5,13 @@
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
+.globl lock
+lock:
+		mov ip, r7
+		mov r7, #53
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/lseek.s
@@ -1 +0,0 @@
-/ C library -- lseek
@@ -3,3 +1,0 @@
-/ error = lseek(file, offset, ptr);
-/ long offset
-/ long lseek()
@@ -7,2 +2,0 @@
-.globl	_lseek, cerror
-.lseek	= 19.
@@ -10,17 +4,13 @@
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
+.globl lseek
+lseek:
+		mov ip, r7
+		mov r7, #19
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/mknod.s
@@ -1 +0,0 @@
-/ C library -- mknod
@@ -3 +1,0 @@
-/ error = mknod(string, mode, major.minor);
@@ -5 +2,0 @@
-.globl	_mknod, cerror
@@ -7,17 +4,13 @@
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
+.globl mknod
+mknod:
+		mov ip, r7
+		mov r7, #14
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/mount.s
@@ -1 +0,0 @@
-/ C library -- mount
@@ -3 +1,0 @@
-/ error = mount(dev, file, flag)
@@ -5,3 +2,0 @@
-.globl	_mount,
-.globl	cerror
-.mount = 21.
@@ -9,16 +4,13 @@
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
+.globl mount
+mount:
+		mov ip, r7
+		mov r7, #21
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/nice.s
@@ -1 +0,0 @@
-/ C library-- nice
@@ -3 +1,0 @@
-/ error = nice(hownice)
@@ -5,3 +2,0 @@
-.globl	_nice,
-.globl	cerror
-.nice = 34.
@@ -9,11 +4,13 @@
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
+.globl nice
+nice:
+		mov ip, r7
+		mov r7, #34
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/open.c usr/src/libc/sys/open.s
@@ -1,23 +1,7 @@
-/ C library -- open
-
-/ file = open(string, mode)
-/ file == -1 means error
-
-.globl	_open,
-.globl	cerror
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
+#define S_OPEN 5
+int syscall3(int, int, int, int);
+int
+open(char *path, int mode)
+{
+	return(syscall3(S_OPEN, (int)path, mode, 0));
+}

% usr/src/libc/sys/pause.c usr/src/libc/sys/pause.s
@@ -1,11 +1,7 @@
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
+#define S_PAUSE 29
+int syscall3(int, int, int, int);
+int
+pause(void)
+{
+	return(syscall3(S_PAUSE, 0, 0, 0));
+}

% usr/src/libc/sys/pipe.s
@@ -1 +0,0 @@
-/ pipe -- C library
@@ -3,2 +1,0 @@
-/	pipe(f)
-/	int f[2];
@@ -6 +2,0 @@
-.globl	_pipe, cerror
@@ -8 +3,0 @@
-.pipe = 42.
@@ -10,6 +5,13 @@
-_pipe:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.pipe
-	bec	1f
-	jmp	cerror
+.globl pipe
+pipe:
+		mov ip, r7
+		mov r3, r0
+		mov r7, #42
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		blt 1f
+		str r0, [r3]
+		str r1, [r3, #4]
+		mov r0, #0
+		bx lr
@@ -17,8 +19,5 @@
-	mov	r2,-(sp)
-	mov	4(r5),r2
-	mov	r0,(r2)+
-	mov	r1,(r2)
-	clr	r0
-	mov	(sp)+,r2
-	mov	(sp)+,r5
-	rts	pc
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/profil.s
@@ -1 +0,0 @@
-/ profil
@@ -3,2 +1,0 @@
-.globl	_profil
-.prof = 44.
@@ -6,13 +3,13 @@
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
+.globl profil
+profil:
+		mov ip, r7
+		mov r7, #44
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/ptrace.s
@@ -1 +0,0 @@
-/ ptrace -- C library
@@ -3 +1,0 @@
-/	result = ptrace(req, pid, addr, data);
@@ -5,2 +2,0 @@
-.ptrace = 26.
-indir = 0
@@ -8,2 +3,0 @@
-.globl	_ptrace
-.globl	cerror, _errno
@@ -11,14 +4,0 @@
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
@@ -26,3 +6,16 @@
-.data
-9:
-	sys	.ptrace; 0: .=.+6
+.globl ptrace
+ptrace:
+		push {r4, r7}
+		mov r4, r0
+		mov r0, r3
+		mov r3, r4
+		mov r7, #26
+		svc #0
+		pop {r4, r7}
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/read.s
@@ -1 +0,0 @@
-/ C library -- read
@@ -3,2 +1,0 @@
-/ nread = read(file, buffer, count);
-/ nread ==0 means eof; nread == -1 means error
@@ -6,3 +2,0 @@
-.globl	_read
-.globl	cerror
-.read = 3.
@@ -10,15 +4,13 @@
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
+.globl read
+read:
+		mov ip, r7
+		mov r7, #3
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/setgid.s
@@ -1 +0,0 @@
-/ C library -- setgid
@@ -3 +1,0 @@
-/ error = setgid(uid);
@@ -5,3 +2,0 @@
-.globl	_setgid
-.globl	cerror
-.setgid = 46.
@@ -9,11 +4,13 @@
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
+.globl setgid
+setgid:
+		mov ip, r7
+		mov r7, #46
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/setuid.s
@@ -1 +0,0 @@
-/ C library -- setuid
@@ -3 +1,0 @@
-/ error = setuid(uid);
@@ -5,3 +2,0 @@
-.globl	_setuid
-.globl	cerror
-.setuid = 23.
@@ -9,11 +4,13 @@
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
+.globl setuid
+setuid:
+		mov ip, r7
+		mov r7, #23
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/signal.s
@@ -1 +0,0 @@
-/ C library -- signal
@@ -3,4 +1,0 @@
-/ signal(n, 0); /* default action on signal(n) */
-/ signal(n, odd); /* ignore signal(n) */
-/ signal(n, label); /* goto label on signal(n) */
-/ returns old label, only one level.
@@ -8,3 +2,0 @@
-rtt	= 6
-.signal	= 48.
-.globl	_signal, cerror
@@ -12,32 +3,0 @@
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
@@ -45,22 +4,0 @@
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
@@ -68,22 +6,13 @@
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
+.globl signal
+signal:
+		mov ip, r7
+		mov r7, #48
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/stat.s
@@ -1 +0,0 @@
-/ C library -- stat
@@ -3 +1,0 @@
-/ error = stat(string, statbuf);
@@ -5,3 +2,0 @@
-.globl	_stat
-.globl	cerror
-.stat = 18.
@@ -9,15 +4,13 @@
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
+.globl stat
+stat:
+		mov ip, r7
+		mov r7, #18
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/stime.c usr/src/libc/sys/stime.s
@@ -1,19 +1,7 @@
-/ error = stime(&long)
-
-.globl	_stime
-.globl	cerror
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
+#define S_STIME 25
+int syscall3(int, int, int, int);
+int
+stime(long *t)
+{
+	return(syscall3(S_STIME, t ? (int)*t : 0, 0, 0));
+}

% usr/src/libc/sys/sync.s
@@ -1,2 +0,0 @@
-.globl	_sync
-.sync = 36.
@@ -4,6 +2,13 @@
-_sync:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.sync
-	mov	(sp)+,r5
-	rts	pc
+.globl sync
+sync:
+		mov ip, r7
+		mov r7, #36
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/time.c usr/src/libc/sys/time.s
@@ -1,37 +1,11 @@
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
+#define S_TIME 13
+int syscall3(int, int, int, int);
+int
+time(long *t)
+{
+	long now;
+	now = (long)syscall3(S_TIME, 0, 0, 0);
+	if(t)
+		*t = now;
+	return(now);
+}

% usr/src/libc/sys/times.s
@@ -1 +0,0 @@
-/ C library -- times
@@ -3,2 +1,0 @@
-.globl	_times
-.times	= 43.
@@ -6,10 +3,13 @@
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
+.globl times
+times:
+		mov ip, r7
+		mov r7, #43
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/umask.s
@@ -1 +0,0 @@
-/ C library -- umask
@@ -3 +1,0 @@
-/ omask = umask(mode);
@@ -5,3 +2,0 @@
-.globl	_umask
-.globl	cerror
-.umask = 60.
@@ -9,13 +4,13 @@
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
+.globl umask
+umask:
+		mov ip, r7
+		mov r7, #60
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/umount.s
@@ -1 +0,0 @@
-/ C library -- umount
@@ -3,5 +1,0 @@
-.globl	_umount
-.globl	cerror
-indir	= 0
-.umount = 22.
-.comm	_errno,2
@@ -9,11 +2,0 @@
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
@@ -21,3 +4,13 @@
-.data
-9:
-	sys	.umount; 0:..
+.globl umount
+umount:
+		mov ip, r7
+		mov r7, #22
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/unlink.s
@@ -1 +0,0 @@
-/ C library -- unlink
@@ -3 +1,0 @@
-/ error = unlink(string);
@@ -5,3 +2,0 @@
-.globl	_unlink,
-.globl	cerror
-.unlink = 10.
@@ -9,14 +4,13 @@
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
+.globl unlink
+unlink:
+		mov ip, r7
+		mov r7, #10
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/utime.s
@@ -1 +0,0 @@
-/ C library -- utime
@@ -3 +1,0 @@
-/ error = utime(string, timev);
@@ -5,3 +2,0 @@
-.globl	_utime
-.globl	cerror
-.utime = 30.
@@ -9,15 +4,13 @@
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
+.globl utime
+utime:
+		mov ip, r7
+		mov r7, #30
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/sys/wait.s
@@ -1 +0,0 @@
-/ C library -- wait
@@ -3,6 +1,0 @@
-/ pid = wait(0);
-/   or,
-/ pid = wait(&status);
-/
-/ pid == -1 if error
-/ status indicates fate of process, if given
@@ -10,3 +2,0 @@
-.globl	_wait
-.globl	cerror
-.wait = 7.
@@ -14,6 +4,13 @@
-_wait:
-	mov	r5,-(sp)
-	mov	sp,r5
-	sys	.wait
-	bec	1f
-	jmp	cerror
+.globl wait
+wait:
+		push {r4, lr}
+		mov r4, r0
+		mov ip, r7
+		mov r7, #7
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		blt 1f
+		cmp r4, #0
+		strne r1, [r4]
+		pop {r4, pc}
@@ -21,6 +18,5 @@
-	tst	4(r5)
-	beq	1f
-	mov	r1,*4(r5)	/ status return
-1:
-	mov	(sp)+,r5
-	rts	pc
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		pop {r4, pc}

% usr/src/libc/sys/write.s
@@ -1 +0,0 @@
-/ C library -- write
@@ -3,3 +1,0 @@
-/ nwritten = write(file, buffer, count);
-/
-/ nwritten == -1 means error
@@ -7,3 +2,0 @@
-.globl	_write
-.globl	cerror
-.write = 4.
@@ -11,15 +4,13 @@
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
+.globl write
+write:
+		mov ip, r7
+		mov r7, #4
+		svc #0
+		mov r7, ip
+		cmp r0, #0
+		bxge lr
+		rsb r1, r0, #0
+		ldr r2, =errno
+		str r1, [r2]
+		mvn r0, #0
+		bx lr

% usr/src/libc/syscall.s usr/src/libc/v6/syscall.s
@@ -1,27 +1,16 @@
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
+.globl syscall3
+syscall3:
+	mov ip, r7
+	mov r7, r0
+	mov r0, r1
+	mov r1, r2
+	mov r2, r3
+	svc #0
+	mov r7, ip
+	cmp r0, #0
+	bxge lr
+	rsb r1, r0, #0
+	ldr r2, =errno
+	str r1, [r2]
+	mvn r0, #0
+	bx lr

% usr/src/libm/asin.c

% usr/src/libm/atan.c
@@ -17 +17 @@
-double static sq2p1	 =2.414213562373095048802e0;
+static double sq2p1	 =2.414213562373095048802e0;
@@ -31,0 +32 @@
+static double satan(), xatan();

% usr/src/libm/exp.c

% usr/src/libm/fabs.c

% usr/src/libm/floor.c

% usr/src/libm/hypot.c

% usr/src/libm/j0.c
@@ -42,0 +43 @@
+static void asympt();
@@ -172 +173 @@
-static
+static void

% usr/src/libm/j1.c
@@ -42,0 +43 @@
+static void asympt();
@@ -178 +179 @@
-static
+static void

% usr/src/libm/jn.c

% usr/src/libm/log.c

% usr/src/libm/pow.c

% usr/src/libm/sin.c
@@ -18,0 +19 @@
+static double sinus();

% usr/src/libm/sinh.c
@@ -30 +30 @@
-	register sign;
+	register int sign;

% usr/src/libm/sqrt.c

% usr/src/libm/tan.c

% usr/src/libm/tanh.c

% usr/sys/conf/low.s usr/sys/conf/l.s
@@ -1,72 +1,249 @@
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
+@ Low core: exception vector table and the trap/interrupt entry stubs
+@ that build the register frame and call into C (cf. v7 conf/l.s).
+@ The machine routines the C kernel calls live in mch.s.
+
+.globl _start
+.globl vectors
+.globl run_user
+.globl return_frame
+.globl main
+USTACK = 0x000f0000
+_start:
+	cpsid if			@ mask IRQ/FIQ at reset
+
+	@ The ROM may hand off with the MMU + caches enabled; disable them so the
+	@ early MMIO/console setup runs against physical addresses, then
+	@ machine_init builds the page tables and re-enables them via mmu_on.  On
+	@ qemu the MMU is already off so these clears are a no-op -- same code.
+	mrc p15, 0, r0, c1, c0, 0	@ SCTLR
+	bic r0, r0, #(1 << 12)		@ I: instruction cache off
+	bic r0, r0, #(1 << 2)		@ C: data cache off
+	bic r0, r0, #(1 << 11)		@ Z: branch prediction off
+	bic r0, r0, #(1 << 13)		@ V: low exception vectors
+	bic r0, r0, #1			@ M: MMU off
+	mcr p15, 0, r0, c1, c0, 0
+	isb
+	mov r0, #0
+	mcr p15, 0, r0, c8, c7, 0	@ TLBIALL
+	mcr p15, 0, r0, c7, c5, 0	@ ICIALLU: invalidate I-cache
+	mcr p15, 0, r0, c7, c5, 6	@ BPIALL: invalidate branch predictor
+	dsb
+	isb
+
+	ldr sp, =stack_top
+
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
+
+	mrs r0, cpsr
+	bic r1, r0, #0x1f
+	orr r1, r1, #0xd2
+	msr cpsr_c, r1
+	ldr sp, =irq_stack_top
+	msr cpsr_c, r0
+
+	bl machine_init			@ enable MMU, map u-area window -> proc0
+	ldr sp, =0x4F002000		@ UBASE + USIZE*64: proc0 u-area stack top
+	bl main
+	dsb ish
+	isb
+	mov r0, #0
+	ldr r1, =USTACK
+	bl run_user
+halt:
+	wfi
+	b halt
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
+	cpsid i
+	sub sp, sp, #68
+	stmia sp, {r0-r12}
+	mov r0, sp
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov r3, sp
+	mov r4, lr
+	msr cpsr_c, r1
+	str r3, [r0, #52]
+	str r4, [r0, #56]
+	mov r0, lr
+	str r0, [sp, #60]
+	mrs r0, spsr
+	str r0, [sp, #64]
+	mov r0, sp
+	cpsie i
+	bl trap
+	cpsid i
+	ldr r0, [sp, #64]
+	bic r0, r0, #0x1f
+	orr r0, r0, #0x10
+	msr spsr_cxsf, r0
+	mov r0, sp
+	ldr r3, [r0, #52]
+	ldr r4, [r0, #56]
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov sp, r3
+	mov lr, r4
+	msr cpsr_c, r1
+	ldmia sp, {r0-r12}
+	ldr lr, [sp, #60]
+	add sp, sp, #68
+	movs pc, lr
+
+irq_entry:
+	sub lr, lr, #4
+	srsdb sp!, #0x13
+	cpsid if, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r12}
+	mov r5, lr			@ preserve the interrupted SVC lr (bl clobbers it)
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov r3, sp
+	mov r4, lr
+	msr cpsr_c, r1
+	str r3, [sp, #52]
+	str r4, [sp, #56]
+	mov r0, sp
+	bl clock_irq_handler
+	ldr r0, [sp, #64]		@ back to user mode with runrun set:
+	and r0, r0, #0x1f		@ give up the cpu (v7's trap 12)
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
+	ldr r3, [sp, #52]
+	ldr r4, [sp, #56]
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov sp, r3
+	mov lr, r4
+	msr cpsr_c, r1
+	mov lr, r5			@ restore the interrupted SVC lr
+	ldmia sp, {r0-r12}
+	add sp, sp, #60
+	rfeia sp!
+
+badtrap:
+	bl panictrap
+	b badtrap
+
+undef_entry:
+	sub lr, lr, #4
+	mov ip, #4
+	b user_trap_common
+pabort_entry:
+	sub lr, lr, #4
+	mov ip, #11
+	b user_trap_common
+dabort_entry:
+	sub lr, lr, #8
+	mov ip, #11
+
+user_trap_common:
+	srsdb sp!, #0x13
+	cpsid if, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r12}
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov r3, sp
+	mov r4, lr
+	msr cpsr_c, r1
+	str r3, [sp, #52]
+	str r4, [sp, #56]
+	mov r0, ip
+	mov r1, sp
+	bl user_trap_handler
+	ldr r3, [sp, #52]
+	ldr r4, [sp, #56]
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov sp, r3
+	mov lr, r4
+	msr cpsr_c, r1
+	ldmia sp, {r0-r12}
+	add sp, sp, #60
+	rfeia sp!
+
+run_user:
+	mrs r2, cpsr
+	bic r3, r2, #0x1f
+	orr r3, r3, #0x1f
+	msr cpsr_c, r3
+	mov sp, r1
+	msr cpsr_c, r2
+	mov r3, #0x10
+	msr spsr_cxsf, r3
+	mov lr, r0
+	movs pc, lr
+
+return_frame:
+	mov ip, r0
+	ldr r1, [r0, #64]
+	bic r1, r1, #0x1f
+	orr r1, r1, #0x10
+	msr spsr_cxsf, r1
+	ldr r3, [r0, #52]
+	ldr r4, [r0, #56]
+	mrs r1, cpsr
+	bic r2, r1, #0x1f
+	orr r2, r2, #0x1f
+	msr cpsr_c, r2
+	mov sp, r3
+	mov lr, r4
+	msr cpsr_c, r1
+	ldr lr, [ip, #60]
+	ldmia ip, {r0-r11}
+	ldr ip, [ip, #48]
+	movs pc, lr
+
+.section .stack
+.balign 8
+stack_bottom:
+	.space 8192
+.globl stack_top
+stack_top:
+.balign 8
+irq_stack_bottom:
+	.space 4096
+irq_stack_top:

% usr/sys/conf/mch.s
@@ -1,2 +1,4 @@
-/ machine language assist
-/ for 11/45 or 11/70 CPUs
+@ Machine routines called by the C kernel (the v7 conf/mch.s role).
+@ Low-core vectors and trap/interrupt entry live in low.s; this file holds
+@ the assembly primitives the portable kernel invokes: the context switch
+@ (save/resume), MMU enable, interrupt control, and timer accessors.
@@ -3,0 +6,3 @@
+	.syntax unified
+	.arch armv7-a
+	.text
@@ -5,83 +10,198 @@
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
-
-.data
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
+	.globl mmu_on
+	.globl dmbsy
+	.globl irq_enable
+	.globl intr_enable
+	.globl intr_disable
+	.globl intr_restore
+	.globl cntfrq_get
+	.globl cntv_tval_set
+	.globl cntv_ctl_set
+	.globl save
+	.globl resume
+	.globl dcflush
+	.globl dcclean
+
+mmu_on:
+	push {r4, r5, r6, r7, r8, r9}
+	@ Cortex-A7: set ACTLR.SMP (bit 6) before enabling the caches.  Without it
+	@ the core treats Shareable Normal memory (our cached DDR sections) as
+	@ non-coherent, so cached writes to DDR are silently dropped on eviction.
+	mrc p15, 0, r1, c1, c0, 1	@ ACTLR
+	orr r1, r1, #(1 << 6)		@ SMP: join the inner-shareable coherency domain
+	mcr p15, 0, r1, c1, c0, 1
+	isb
+	mcr p15, 0, r0, c2, c0, 0	@ TTBR0 = page table
+	mov r1, #1
+	mcr p15, 0, r1, c3, c0, 0	@ DACR: domain 0 = manager
+	mov r1, #0
+	mcr p15, 0, r1, c8, c7, 0	@ TLBIALL
+	mcr p15, 0, r1, c7, c5, 0	@ ICIALLU: invalidate I-cache
+	mcr p15, 0, r1, c7, c5, 6	@ BPIALL: invalidate branch predictor
+	@ invalidate the whole L1 data cache by set/way before enabling it
+	mov r1, #0
+	mcr p15, 2, r1, c0, c0, 0	@ CSSELR = 0 (L1 data)
+	isb
+	mrc p15, 1, r2, c0, c0, 0	@ CCSIDR
+	and r3, r2, #7
+	add r3, r3, #4			@ r3 = log2(line bytes)
+	movw r4, #0x3ff
+	and r4, r4, r2, lsr #3		@ r4 = ways - 1
+	clz r5, r4			@ r5 = way bit shift
+	movw r6, #0x7fff
+	and r6, r6, r2, lsr #13		@ r6 = sets - 1
+1:	mov r7, r4			@ r7 = way counter
+2:	lsl r8, r7, r5
+	lsl r9, r6, r3
+	orr r8, r8, r9			@ (way<<shift) | (set<<lineorder)
+	mcr p15, 0, r8, c7, c6, 2	@ DCISW: invalidate D-cache line
+	subs r7, r7, #1
+	bge 2b
+	subs r6, r6, #1
+	bge 1b
+	dsb
+	mrc p15, 0, r1, c1, c0, 0	@ SCTLR
+	orr r1, r1, #1			@ M:  MMU enable
+	orr r1, r1, #(1 << 2)		@ C:  data cache enable
+	orr r1, r1, #(1 << 12)		@ I:  instruction cache enable
+	mcr p15, 0, r1, c1, c0, 0
+	isb
+	pop {r4, r5, r6, r7, r8, r9}
+	bx lr
+
+dmbsy:
+	dmb sy
+	bx lr
+
+irq_enable:
+	cpsie i
+	bx lr
+
+intr_enable:
+	mrs r0, cpsr
+	ldr r1, =irq_ready
+	ldr r1, [r1]
+	cmp r1, #0
+	bxeq lr
+	cpsie i
+	bx lr
+
+intr_disable:
+	mrs r0, cpsr
+	cpsid i
+	bx lr
+
+intr_restore:
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
+cntv_tval_set:
+	mcr p15, 0, r0, c14, c3, 0
+	isb
+	bx lr
+
+cntv_ctl_set:
+	mcr p15, 0, r0, c14, c3, 1
+	isb
+	bx lr
+
+	.type	save, %function
+save:
+	stmia	r0, {r4-r11}
+	str	sp, [r0, #32]
+	str	lr, [r0, #36]
+	mov	r0, #0
+	bx	lr
+	.size	save, .-save
+
+@ resume(int p_addr, int *label): switch the UBASE u-area window to the
+@ new process's image (the KISA6 trick), then restore callee regs+sp+pc
+@ from label.  label is a UBASE-window VA, so after the window switch it
+@ reads the NEW process's saved context.  IRQs masked across the switch;
+@ no stack use between the remap and the sp reload.
+	.type	resume, %function
+resume:
+	cpsid	i
+	ldr	r2, =uarea_l2		@ kernel VA of the u-area L2 (PA==VA)
+	ldr	r3, =corebase		@ board COREBASE (resolved in machdep.c)
+	ldr	r3, [r3]
+	add	r3, r3, r0, lsl #6	@ CLKADDR(p_addr) = phys u-area base
+	orr	r3, r3, #0x12		@ kernel rw, UNCACHED: the window is remapped
+					@ to a new PA each switch; uncached avoids
+					@ stale cache lines aliasing the old VA
+	str	r3, [r2, #0]
+	add	r3, r3, #0x1000
+	str	r3, [r2, #4]
+	add	r3, r3, #0x1000
+	str	r3, [r2, #8]
+	add	r3, r3, #0x1000
+	str	r3, [r2, #12]
+	dsb	ish
+	mov	r3, #0
+	mcr	p15, 0, r3, c8, c7, 0	@ TLBIALL
+	dsb	ish
+	isb
+	ldmia	r1, {r4-r11}
+	ldr	sp, [r1, #32]
+	ldr	lr, [r1, #36]
+	mov	r0, #1
+	bx	lr
+	.size	resume, .-resume
+
+@ dcflush(addr, n): clean+invalidate the D-cache over [addr, addr+n) to the
+@ point of coherency, so a DMA buffer is consistent with main memory before a
+@ device reads it and after a device writes it.  Only the cache-incoherent
+@ board (SDMMC IDMA) calls this; QEMU's virtio path is coherent and never does.
+	.type	dcflush, %function
+dcflush:
+	mrc	p15, 0, r2, c0, c0, 1	@ CTR
+	lsr	r2, r2, #16
+	and	r2, r2, #0xf		@ DminLine = log2(words/line)
+	mov	r3, #4
+	lsl	r2, r3, r2		@ r2 = cache line size in bytes
+	add	r1, r0, r1		@ r1 = end address
+	sub	r3, r2, #1
+	bic	r0, r0, r3		@ align start down to a line
+1:	mcr	p15, 0, r0, c7, c14, 1	@ DCCIMVAC: clean+invalidate by MVA
+	add	r0, r0, r2
+	cmp	r0, r1
+	blo	1b
+	dsb
+	bx	lr
+	.size	dcflush, .-dcflush
+
+@ dcclean(): clean the whole L1 D-cache by set/way, which on the Cortex-A7
+@ (LoUU = 1) is the point of unification: code the kernel wrote through the
+@ D-cache becomes visible to instruction fetch (arm_sync_icache).
+	.type	dcclean, %function
+dcclean:
+	push	{r4, r5, r6, r7}
+	mov	r0, #0
+	mcr	p15, 2, r0, c0, c0, 0	@ CSSELR = 0 (L1 data)
+	isb
+	mrc	p15, 1, r0, c0, c0, 0	@ CCSIDR
+	and	r1, r0, #7
+	add	r1, r1, #4		@ r1 = log2(line bytes)
+	movw	r2, #0x3ff
+	and	r2, r2, r0, lsr #3	@ r2 = ways - 1
+	clz	r3, r2			@ r3 = way bit shift
+	movw	r4, #0x7fff
+	and	r4, r4, r0, lsr #13	@ r4 = sets - 1
+1:	mov	r5, r2			@ r5 = way counter
+2:	lsl	r6, r5, r3
+	lsl	r7, r4, r1
+	orr	r6, r6, r7		@ (way<<shift) | (set<<lineorder)
+	mcr	p15, 0, r6, c7, c10, 2	@ DCCSW: clean D-cache line
+	subs	r5, r5, #1
@@ -89 +209 @@
-	tst	(r0)+
+	subs	r4, r4, #1
@@ -91,968 +211,5 @@
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
-waitloc:
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
-
-	.endif
+	dsb
+	pop	{r4, r5, r6, r7}
+	bx	lr
+	.size	dcclean, .-dcclean
+	.ltorg

% usr/sys/conf/mkconf.c
@@ -1,0 +2,6 @@
+#include <stdlib.h>
+#include <string.h>
+
+void	puke(), subst();
+int	input(), equal(), badline();
+char	*repl();
@@ -62,0 +69 @@
+	{
@@ -71,0 +79 @@
+	},
@@ -72,0 +81 @@
+	{
@@ -81,0 +91 @@
+	},
@@ -82,0 +93 @@
+	{
@@ -91,0 +103 @@
+	},
@@ -92,0 +105 @@
+	{
@@ -101,0 +115 @@
+	},
@@ -102,0 +117 @@
+	{
@@ -111,0 +127 @@
+	},
@@ -120,0 +137 @@
+	{
@@ -129,0 +147 @@
+	},
@@ -137,0 +156 @@
+	{
@@ -146,0 +166 @@
+	},
@@ -147,0 +168 @@
+	{
@@ -156,0 +178 @@
+	},
@@ -157,0 +180 @@
+	{
@@ -166,0 +190 @@
+	},
@@ -171,0 +196 @@
+	{
@@ -180,0 +206 @@
+	},
@@ -181,0 +208 @@
+	{
@@ -190,0 +218 @@
+	},
@@ -191,0 +220 @@
+	{
@@ -200,0 +230 @@
+	},
@@ -201,0 +232 @@
+	{
@@ -210,0 +242 @@
+	},
@@ -211,0 +244 @@
+	{
@@ -220,0 +254 @@
+	},
@@ -225,0 +260 @@
+	{
@@ -234,0 +270 @@
+	},
@@ -235,0 +272 @@
+	{
@@ -244,0 +282 @@
+	},
@@ -250,0 +289 @@
+	{
@@ -259,0 +299 @@
+	},
@@ -260,0 +301 @@
+	{
@@ -269,0 +311 @@
+	},
@@ -270,0 +313 @@
+	{
@@ -279,0 +323 @@
+	},
@@ -284,0 +329 @@
+	{
@@ -293,0 +339 @@
+	},
@@ -294,0 +341 @@
+	{
@@ -303,0 +351 @@
+	},
@@ -313,0 +362 @@
+	{
@@ -322,0 +372 @@
+	},
@@ -327,0 +378 @@
+	{
@@ -336,0 +388 @@
+	},
@@ -344,0 +397 @@
+	{
@@ -353,0 +407 @@
+	},
@@ -354,0 +409 @@
+	{
@@ -363,0 +419 @@
+	},
@@ -365,64 +421 @@
-	0
-};
-
-char	*stra[] =
-{
-	"/ low core",
-	"",
-	".data",
-	"ZERO:",
-	"",
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
-	"",
-	0,
-};
-
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
@@ -447,0 +441,2 @@
+	"#include \"../h/seg.h\"",
+	"#define	DDRBSS	__attribute__((section(KTABLES_SECTION)))",
@@ -460 +455 @@
-	"	0",
+	"	{0}",
@@ -476 +471 @@
-"	0\n\
+"	{0}\n\
@@ -483 +478 @@
-int	nswap	= %l;\n\
+int	nswap	= %d;\n\
@@ -489,10 +484,3 @@
-struct	buf	buf[NBUF];\n\
-struct	file	file[NFILE];\n\
-struct	inode	inode[NINODE];\n"
-};
-
-char	*strg1a[] =
-{
-	"int	mpxchan();",
-	"int	(*ldmpx)() = mpxchan;",
-	0
+struct	buf	buf[NBUF] DDRBSS;\n\
+struct	file	file[NFILE] DDRBSS;\n\
+struct	inode	inode[NINODE] DDRBSS;\n"
@@ -503,2 +491,2 @@
-"struct	proc	proc[NPROC];\n\
-struct	text	text[NTEXT];\n\
+"struct	proc	proc[NPROC] DDRBSS;\n\
+struct	text	text[NTEXT] DDRBSS;\n\
@@ -512 +500 @@
-	"	0",
+	"	{0}",
@@ -515 +503,2 @@
-	"int	ttyopen(), ttyclose(), ttread(), ttwrite(), ttyinput(), ttstart();",
+	"int	ttyopen(), ttyclose(), ttread(), ttyinput(), ttstart();",
+	"char	*ttwrite();",
@@ -529 +518 @@
-	"	ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart, /* 0 */",
+	"	{ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart, 0, 0, 0}, /* 0 */",
@@ -535 +524 @@
-	"	pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint, /* 1 */",
+	"	{pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint, 0, 0, 0}, /* 1 */",
@@ -550,0 +540,8 @@
+char	*con = "kl";
+char	*dsk = "rk";
+int	ddr;
+unsigned long	ramb, ramn, tabb, tabn, coreb, coret, pguser, gicd, gicc;
+#define	NMAP	8
+unsigned long	mapb[NMAP], mape[NMAP];
+char	mapa[NMAP][32];
+int	nmap;
@@ -551,0 +549 @@
+int
@@ -556,2 +554 @@
-	int i, n, ev, nkl;
-	int flagf, flagb, dumpht;
+	int i;
@@ -562 +559 @@
- * pass1 -- create interrupt vectors
+ * pass1 -- create the linker script
@@ -564,46 +561,14 @@
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
+	printf("ENTRY(_start)\nMEMORY\n{\n");
+	printf("\tRAM (rwx) : ORIGIN = 0x%lx, LENGTH = 0x%lx\n", ramb, ramn);
+	if (tabn)
+		printf("\tTAB (rwx) : ORIGIN = 0x%lx, LENGTH = 0x%lx\n", tabb, tabn);
+	printf("}\nSECTIONS\n{\n");
+	printf("\t.text : { *(.text*) } > RAM\n");
+	printf("\t.rodata : { *(.rodata*) } > RAM\n");
+	printf("\t.data : { *(.data*) } > RAM\n");
+	printf("\t__bss_start = .;\n\t.bss : { *(.bss*) *(COMMON) } > RAM\n");
+	printf("\t__bss_end = .;\n\t.stack : { *(.stack) } > RAM\n");
+	printf("\t.ddrbss (NOLOAD) : ALIGN(16384) {\n");
+	printf("\t\t__ddrbss_start = .;\n\t\t*(.ddrbss*)\n");
+	printf("\t\t__ddrbss_end = .;\n\t} > %s\n}\n", tabn ? "TAB" : "RAM");
@@ -620 +585 @@
-	for (i=0; q=btab[i]; i++) {
+	for (i=0; (q=btab[i]); i++) {
@@ -627 +592 @@
-	for(i=0; q=btab[i]; i++) {
+	for(i=0; (q=btab[i]); i++) {
@@ -631 +596 @@
-			printf("%s	/* %s = %d */\n", p->coded, q, i);
+			printf("	{%s},	/* %s = %d */\n", p->coded, q, i);
@@ -640 +605 @@
-		printf("	nodev, nodev, nodev, 0, /* %s = %d */\n", q, i);
+		printf("	{nodev, nodev, nodev, 0}, /* %s = %d */\n", q, i);
@@ -652 +617 @@
-	for (i=0; q=ctab[i]; i++) {
+	for (i=0; (q=ctab[i]); i++) {
@@ -659 +624 @@
-	for(i=0; q=ctab[i]; i++) {
+	for(i=0; (q=ctab[i]); i++) {
@@ -663 +628 @@
-			printf("%s	/* %s = %d */\n", p->codee, q, i);
+			printf("	{%s},	/* %s = %d */\n", p->codee, q, i);
@@ -666 +631 @@
-		printf("	nodev, nodev, nodev, nodev, nodev, nulldev, 0, /* %s = %d */\n", q, i);
+		printf("	{nodev, nodev, nodev, nodev, nodev, nulldev, 0}, /* %s = %d */\n", q, i);
@@ -683,2 +647,0 @@
-	if (!mpx)
-		puke(strg1a);
@@ -688,13 +651,19 @@
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
+	printf("\nint\t%sintr(), %sintr();\n", con, dsk);
+	printf("extern int\t%sirq, %sirq;\n", con, dsk);
+	printf("struct\tintr\tintrtab[] =\n{\n");
+	printf("\t{&%sirq, %sintr},\n\t{&%sirq, %sintr},\n", con, con, dsk, dsk);
+	printf("\t{0, 0}\n};\n");
+	printf("\nvoid\t%sinit(void), %sinit(void), %sputchar(char);\n", con, dsk, con);
+	printf("void\tcninit(void) { %sinit(); }\n", con);
+	printf("void\tbdinit(void) { %sinit(); }\n", dsk);
+	printf("void\tputchar(char c) { %sputchar(c); }\n", con);
+	printf("\nvoid\tddrinit(void);\n");
+	printf("void\tclock_ddr_init(void) { %s}\n", ddr ? "ddrinit(); " : "");
@@ -702,0 +672 @@
+void
@@ -704,0 +675 @@
+int a;
@@ -708 +679 @@
-	while(c = *s++) {
+	while((c = *s++)) {
@@ -713,0 +685 @@
+int
@@ -726 +698 @@
-	if (count == -1 && n>0) {
+	if (count == -1) {
@@ -728 +700 @@
-		n++;
+		n = sscanf(line, "%31s%31s%ld", keyw, dev, &num) + 1;
@@ -731,0 +704,24 @@
+	if (equal(keyw, "map") && nmap < NMAP) {
+		if (sscanf(line, "%*s%lx%lx%31s", &mapb[nmap], &mape[nmap], mapa[nmap]) != 3)
+			goto badl;
+		if (equal(mapa[nmap], "kern") || equal(mapa[nmap], "dev"))
+			sprintf(mapa[nmap], "SEC_%s", equal(mapa[nmap], "kern") ? "KERN" : "DEV");
+		else
+			sprintf(mapa[nmap], "0x%lx", strtoul(mapa[nmap], 0, 16));
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
@@ -733,0 +730,2 @@
+		if (n > 2)
+			subst(q, dev);
@@ -734,0 +733,2 @@
+			if (n > 2)
+				return(1);
@@ -812,0 +813,7 @@
+	return(badline(line));
+}
+
+int
+badline(line)
+char *line;
+{
@@ -816,0 +824,42 @@
+/*
+ * Configure the driver with the given prefix for entry q
+ * (e.g. "console us", "rk sd"): rename its code strings.
+ */
+char *
+repl(s, o, n)
+char *s, *o, *n;
+{
+	char *t, *d;
+	size_t lo = strlen(o), ln = strlen(n);
+
+	t = d = malloc(strlen(s) * (ln + 1) + 1);
+	while (*s)
+		if (strncmp(s, o, lo) == 0) {
+			strcpy(d, n);
+			d += ln;
+			s += lo;
+		} else
+			*d++ = *s++;
+	*d = 0;
+	return(t);
+}
+
+void
+subst(q, n)
+struct tab *q;
+char *n;
+{
+	char *o = equal(q->name, "console") ? con : q->name;
+
+	n = strcpy(malloc(strlen(n) + 1), n);
+	q->coded = repl(q->coded, o, n);
+	q->codee = repl(q->codee, o, n);
+	q->codef = repl(q->codef, o, n);
+	q->codeg = repl(q->codeg, o, n);
+	if (equal(q->name, "console"))
+		con = n;
+	if (equal(q->name, "rk"))
+		dsk = n;
+}
+
+int

% usr/sys/conf/mp135conf usr/sys/conf/rktmconf
@@ -1 +1,2 @@
-rk
+console us
+rk sd
@@ -4 +5 @@
-swplo 4000
+swplo 10648
@@ -6 +7,10 @@
-tm
+ram 2ffe0000 20000
+tables c0000000 20000000
+core c0100000 e0000000
+gic a0021000 a0022000
+pguser 472
+map 2ff00000 30000000 kern
+map c0000000 e0000000 11402
+map 40000000 60000000 dev
+map a0000000 a0100000 dev
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
+map 40000000 48000000 kern
+map 08000000 0c000000 dev

% usr/sys/dev/bio.c
@@ -8,0 +9,13 @@
+void brelse(struct buf *bp);
+void bawrite(register struct buf *bp);
+void iowait(struct buf *bp);
+void notavail(struct buf *bp);
+void geterror(struct buf *bp);
+int incore(dev_t dev, daddr_t blkno);
+void wakeup(caddr_t chan);
+void sleep(caddr_t chan, int pri);
+int intr_enable(void);
+int intr_disable(void);
+void intr_restore(int s);
+void panic(char *s);
+void mapfree(struct buf *bp);
@@ -56,3 +69 @@
-bread(dev, blkno)
-dev_t dev;
-daddr_t blkno;
+bread(dev_t dev, daddr_t blkno)
@@ -84,3 +95 @@
-breada(dev, blkno, rablkno)
-dev_t dev;
-daddr_t blkno, rablkno;
+breada(dev_t dev, daddr_t blkno, daddr_t rablkno)
@@ -125,2 +134,2 @@
-bwrite(bp)
-register struct buf *bp;
+void
+bwrite(struct buf *bp)
@@ -128 +137 @@
-	register flag;
+	register int flag;
@@ -154,2 +163,2 @@
-bdwrite(bp)
-register struct buf *bp;
+void
+bdwrite(struct buf *bp)
@@ -171,2 +180,2 @@
-bawrite(bp)
-register struct buf *bp;
+void
+bawrite(register struct buf *bp)
@@ -182,2 +191,2 @@
-brelse(bp)
-register struct buf *bp;
+void
+brelse(struct buf *bp)
@@ -186 +195 @@
-	register s;
+	register int s;
@@ -196 +205 @@
-	s = spl6();
+	s = intr_disable();
@@ -211 +220 @@
-	splx(s);
+	intr_restore(s);
@@ -218,3 +227,2 @@
-incore(dev, blkno)
-dev_t dev;
-daddr_t blkno;
+int
+incore(dev_t dev, daddr_t blkno)
@@ -238,3 +246 @@
-getblk(dev, blkno)
-dev_t dev;
-daddr_t blkno;
+getblk(dev_t dev, daddr_t blkno)
@@ -245 +251 @@
-	register i;
+	register int i;
@@ -252 +258 @@
-	spl0();
+	intr_enable();
@@ -259 +265 @@
-		spl6();
+		intr_disable();
@@ -265 +271,2 @@
-		spl0();
+		notavail(bp);
+		intr_enable();
@@ -276 +282,0 @@
-		notavail(bp);
@@ -279 +285 @@
-	spl6();
+	intr_disable();
@@ -285,2 +291,3 @@
-	spl0();
-	notavail(bp = bfreelist.av_forw);
+	bp = bfreelist.av_forw;
+	notavail(bp);
+	intr_enable();
@@ -309 +316 @@
-geteblk()
+geteblk(void)
@@ -315 +322 @@
-	spl6();
+	intr_disable();
@@ -320 +326,0 @@
-	spl0();
@@ -322 +328,3 @@
-	notavail(bp = bfreelist.av_forw);
+	bp = bfreelist.av_forw;
+	notavail(bp);
+	intr_enable();
@@ -343,2 +351,2 @@
-iowait(bp)
-register struct buf *bp;
+void
+iowait(struct buf *bp)
@@ -347 +355 @@
-	spl6();
+	intr_disable();
@@ -350 +358 @@
-	spl0();
+	intr_enable();
@@ -358,2 +366,2 @@
-notavail(bp)
-register struct buf *bp;
+void
+notavail(struct buf *bp)
@@ -361 +369 @@
-	register s;
+	register int s;
@@ -363 +371 @@
-	s = spl6();
+	s = intr_disable();
@@ -367 +375 @@
-	splx(s);
+	intr_restore(s);
@@ -374,2 +382,2 @@
-iodone(bp)
-register struct buf *bp;
+void
+iodone(struct buf *bp)
@@ -392,2 +400,2 @@
-clrbuf(bp)
-struct buf *bp;
+void
+clrbuf(struct buf *bp)
@@ -395,2 +403,2 @@
-	register *p;
-	register c;
+	register int *p;
+	register int c;
@@ -409,2 +417,2 @@
-swap(blkno, coreaddr, count, rdflg)
-register count;
+void
+swap(daddr_t blkno, int coreaddr, int count, int rdflg)
@@ -413 +421 @@
-	register tcount;
+	register int tcount;
@@ -419 +427 @@
-	spl6();
+	intr_disable();
@@ -435 +443 @@
-		spl6();
+		intr_disable();
@@ -444 +452 @@
-	spl0();
+	intr_enable();
@@ -456,2 +464,2 @@
-bflush(dev)
-dev_t dev;
+void
+bflush(dev_t dev)
@@ -462 +470 @@
-	spl6();
+	intr_disable();
@@ -471 +479 @@
-	spl0();
+	intr_enable();
@@ -484,3 +492,2 @@
-physio(strat, bp, dev, rw)
-register struct buf *bp;
-int (*strat)();
+void
+physio(int (*strat)(), register struct buf *bp, dev_t dev, int rw)
@@ -515 +522 @@
-	    && nb < 1024-u.u_ssize)
+	    && (unsigned)nb < 1024-u.u_ssize)
@@ -517 +524 @@
-	spl6();
+	intr_disable();
@@ -528 +535 @@
-	ts = (u.u_sep? UDSA: UISA)->r[nb>>7] + (nb&0177);
+	ts = (u.u_sep? &u.u_uisa[8]: &u.u_uisa[0])[nb>>7] + (nb&0177);
@@ -536 +543 @@
-	spl6();
+	intr_disable();
@@ -542,2 +549,2 @@
-	spl0();
-	bp->b_flags &= ~(B_BUSY|B_WANTED);
+	intr_enable();
+	bp->b_flags &= ~(B_BUSY|B_WANTED|B_PHYS);
@@ -557,2 +564,2 @@
-geterror(bp)
-register struct buf *bp;
+void
+geterror(struct buf *bp)

% usr/sys/dev/mem.c
@@ -16,0 +17,4 @@
+int passc(int c);
+int cpass(void);
+int fumem(unsigned int off);
+int sumem(unsigned int off, int c);
@@ -18 +22,2 @@
-mmread(dev)
+int
+mmread(dev_t dev)
@@ -20,2 +25 @@
-	register c, bn, on;
-	int a, d;
+	register int c;
@@ -24 +28 @@
-		return;
+		return(0);
@@ -26,10 +30 @@
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
+		if ((c = fumem((unsigned int)u.u_offset)) < 0)
@@ -37,3 +31,0 @@
-		UISA->r[0] = a;
-		UISD->r[0] = d;
-		spl0();
@@ -40,0 +33 @@
+	return(0);
@@ -43 +36,2 @@
-mmwrite(dev)
+int
+mmwrite(dev_t dev)
@@ -45,2 +39,2 @@
-	register c, bn, on;
-	int a, d;
+	register int c;
+	unsigned int off;
@@ -50 +44 @@
-		return;
+		return(0);
@@ -53,2 +47 @@
-		bn = u.u_offset >> 6;
-		on = u.u_offset & 077;
+		off = (unsigned int)u.u_offset;
@@ -57,8 +50 @@
-		a = UISA->r[0];
-		d = UISD->r[0];
-		spl7();
-		UISA->r[0] = bn;
-		UISD->r[0] = 077406;
-		if(minor(dev) == 1)
-			UISA->r[0] = (ka6-6)->r[(bn>>7)&07] + (bn & 0177);
-		if (suibyte((caddr_t)on, c) < 0)
+		if (sumem(off, c) < 0)
@@ -66,3 +51,0 @@
-		UISA->r[0] = a;
-		UISD->r[0] = d;
-		spl0();
@@ -69,0 +53 @@
+	return(0);

% usr/sys/dev/partab.c

% usr/sys/dev/pl011.c usr/sys/dev/kl.c
@@ -2 +2,10 @@
- *   KL/DL-11 driver
+ *   PL011 UART console driver
+ *
+ * The console is the QEMU virt PL011.  It is a normal Unix character
+ * device: the cdevsw open/close/read/write/ioctl entries hang the line
+ * discipline (tty.c) off it, output is paced by the transmit interrupt,
+ * and input arrives on the receive interrupt -- the same model the v7
+ * kl.c console driver follows, but for PL011 hardware.  The PL011 raises
+ * a single GIC line (INTID 33); its receive and transmit causes are told
+ * apart by the masked-interrupt-status register rather than by separate
+ * PDP-11 vectors.
@@ -6 +15 @@
-#include	"../h/dir.h"
+#include "../h/dir.h"
@@ -11,27 +19,0 @@
-/* base address */
-#define	KLADDR	((struct device *)0177560)	/* console */
-#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
-#define	DLBASE	((struct device *)0175610)	/* dl-e */
-#define	NKL11	1
-#define	NDL11	0
-#define DSRDY	02
-#define	RDRENB	01
-#define	DLDELAY	4	/* Extra delay for DL's (double buff) */
-
-#define	NL1	000400
-#define	NL2	001000
-#define	CR2	020000
-#define	FF1	040000
-#define	TAB1	002000
-
-struct	tty kl11[NKL11+NDL11];
-int	klstart();
-int	ttrstrt();
-char	partab[];
-
-struct device {
-	int	rcsr;
-	int	rbuf;
-	int	tcsr;
-	int	tbuf;
-};
@@ -39,2 +21,50 @@
-klopen(dev, flag)
-dev_t dev;
+#define	PL011_BASE	0x09000000	/* QEMU virt UART0 */
+#define	NCONS	1			/* one console line */
+#define	OUTDELAY 4		/* slop added to ttyoutput delay characters */
+
+#define	UARTDR		(*(volatile unsigned int *)(PL011_BASE+0x000))
+#define	UARTFR		(*(volatile unsigned int *)(PL011_BASE+0x018))
+#define	UARTLCRH	(*(volatile unsigned int *)(PL011_BASE+0x02c))
+#define	UARTIMSC	(*(volatile unsigned int *)(PL011_BASE+0x038))
+#define	UARTMIS		(*(volatile unsigned int *)(PL011_BASE+0x040))
+#define	UARTICR		(*(volatile unsigned int *)(PL011_BASE+0x044))
+#define	TXFF	0x20		/* FR: transmit holding register full */
+#define	RXFE	0x10		/* FR: receive holding register empty */
+#define	FEN	0x10		/* LCRH: FIFO enable */
+#define	RXI	0x10		/* interrupt: receiver */
+#define	TXI	0x20		/* interrupt: transmitter */
+#define	RTI	0x40		/* interrupt: receive timeout */
+
+struct	tty kl11[NCONS];
+int	klirq = 33;		/* GIC INTID of the PL011 console (SPI 1) */
+
+extern char partab[];
+void ttyopen(dev_t dev, struct tty *tp);
+void ttyclose(struct tty *tp);
+void ttychars(struct tty *tp);
+int ttread(struct tty *tp);
+caddr_t ttwrite(struct tty *tp);
+int ttioccomm(int com, struct tty *tp, caddr_t addr, dev_t dev);
+void ttyinput(int c, struct tty *tp);
+void ttstart(struct tty *tp);
+int ttrstrt(struct tty *tp);
+void timeout(int (*fun)(), caddr_t arg, int tim);
+void wakeup(caddr_t chan);
+int getc(struct clist *p);
+int klstart(struct tty *tp);
+int klrint(dev_t dev);
+int klxint(dev_t dev);
+
+/*
+ * QEMU configures the PL011 (clock, baud, enable) before the kernel runs, so
+ * the console needs no hardware setup; klinit() exists only to satisfy the
+ * machine layer's board-agnostic early console-init hook (machine_init), which
+ * the MP135 build uses to bring UART4 up from HSI.
+ */
+void
+klinit(void)
+{
+}
+
+int
+klopen(dev_t dev, int flag)
@@ -42 +71,0 @@
-	register struct device *addr;
@@ -44 +72,0 @@
-	register d;
@@ -46,2 +74,2 @@
-	d = minor(dev);
-	if(d >= NKL11+NDL11) {
+	(void)flag;
+	if(minor(dev) >= NCONS) {
@@ -49 +77 @@
-		return;
+		return(0);
@@ -51,13 +79,2 @@
-	tp = &kl11[d];
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
+	tp = &kl11[minor(dev)];
+	tp->t_addr = (caddr_t)PL011_BASE;
@@ -67 +84 @@
-		tp->t_flags = EVENP|LCASE|ECHO|XTABS|CRMOD|CR2;
+		tp->t_flags = EVENP|ODDP|ECHO|XTABS|CRMOD;
@@ -70,2 +87,2 @@
-	addr->rcsr |= IENABLE|DSRDY|RDRENB;
-	addr->tcsr |= IENABLE;
+	UARTLCRH &= ~FEN;		/* one transmit interrupt per character */
+	UARTIMSC |= RXI|RTI;		/* enable receive interrupts */
@@ -72,0 +90 @@
+	return(0);
@@ -75,3 +93,2 @@
-klclose(dev, flag)
-dev_t dev;
-int flag;
+int
+klclose(dev_t dev, int flag)
@@ -79,4 +96,3 @@
-	register struct tty *tp;
-
-	tp = &kl11[minor(dev)];
-	ttyclose(tp);
+	(void)flag;
+	ttyclose(&kl11[minor(dev)]);
+	return(0);
@@ -85,2 +101,2 @@
-klread(dev)
-dev_t dev;
+int
+klread(dev_t dev)
@@ -88,0 +105 @@
+	return(0);
@@ -91,2 +108,2 @@
-klwrite(dev)
-dev_t dev;
+int
+klwrite(dev_t dev)
@@ -94,0 +112,31 @@
+	return(0);
+}
+
+/*
+ * Transmitter ready: hand the next queued character to the PL011.  Output
+ * delays (characters above 0177, produced by ttyoutput for slow terminals)
+ * are honored as in the v7 console driver.  The transmit interrupt is
+ * level-sensitive, so it is masked whenever the output queue drains.
+ */
+int
+klstart(struct tty *tp)
+{
+	register int c;
+
+	if (UARTFR & TXFF)
+		return(0);
+	if ((c=getc(&tp->t_outq)) >= 0) {
+		if (tp->t_flags&RAW)
+			UARTDR = c & 0177;	/* 8N1 glass tty: no parity bit */
+		else if (c<=0177)
+			UARTDR = c;
+		else {
+			timeout(ttrstrt, (caddr_t)tp, (c&0177) + OUTDELAY);
+			tp->t_state |= TIMEOUT;
+			UARTIMSC &= ~TXI;
+			return(0);
+		}
+		UARTIMSC |= TXI;
+	} else
+		UARTIMSC &= ~TXI;
+	return(0);
@@ -97,2 +145,2 @@
-klxint(dev)
-dev_t dev;
+int
+klxint(dev_t dev)
@@ -104,5 +152,3 @@
-	if (tp->t_state&ASLEEP && tp->t_outq.c_cc<=TTLOWAT)
-		if (tp->t_chan)
-			mcstart(tp->t_chan, (caddr_t)&tp->t_outq);
-		else
-			wakeup((caddr_t)&tp->t_outq);
+	if ((tp->t_state&ASLEEP) && tp->t_outq.c_cc<=TTLOWAT)
+		wakeup((caddr_t)&tp->t_outq);
+	return(0);
@@ -111,2 +157,2 @@
-klrint(dev)
-dev_t dev;
+int
+klrint(dev_t dev)
@@ -115 +160,0 @@
-	register struct device *addr;
@@ -119,4 +164,5 @@
-	addr = (struct device *)tp->t_addr;
-	c = addr->rbuf;
-	addr->rcsr |= RDRENB;
-	ttyinput(c, tp);
+	while ((UARTFR & RXFE) == 0) {
+		c = UARTDR;
+		ttyinput(c, tp);
+	}
+	return(0);
@@ -125,3 +171,2 @@
-klioctl(dev, cmd, addr, flag)
-caddr_t addr;
-dev_t dev;
+int
+klioctl(dev_t dev, int cmd, caddr_t addr, int flag)
@@ -129 +174,2 @@
-	if (ttioccom(cmd, &kl11[minor(dev)], addr, dev)==0)
+	(void)flag;
+	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
@@ -130,0 +177 @@
+	return(0);
@@ -133,2 +180,7 @@
-klstart(tp)
-register struct tty *tp;
+/*
+ * Console interrupt.  One GIC line serves the PL011; the masked-interrupt-
+ * status register says whether the receiver, transmitter, or both need
+ * service, demultiplexing into the receive/transmit halves above.
+ */
+int
+klintr(void)
@@ -136,2 +188 @@
-	register c;
-	register struct device *addr;
+	register unsigned int mis;
@@ -139,12 +190,4 @@
-	addr = (struct device *)tp->t_addr;
-	if((addr->tcsr&DONE) == 0)
-		return;
-	if ((c=getc(&tp->t_outq)) >= 0) {
-		if (tp->t_flags&RAW)
-			addr->tbuf = c;
-		else if (c<=0177)
-			addr->tbuf = c | (partab[c]&0200);
-		else {
-			timeout(ttrstrt, (caddr_t)tp, (c&0177) + DLDELAY);
-			tp->t_state |= TIMEOUT;
-		}
+	mis = UARTMIS;
+	if (mis & (RXI|RTI)) {
+		UARTICR = RXI|RTI;
+		klrint(0);
@@ -151,0 +195,5 @@
+	if (mis & TXI) {
+		UARTICR = TXI;
+		klxint(0);
+	}
+	return(0);
@@ -154 +201,0 @@
-char	*msgbufp = msgbuf;	/* Next saved printf character */
@@ -156,9 +203,7 @@
- * Print a character on console.
- * Attempts to save and restore device
- * status.
- * If the switches are 0, all
- * printing is inhibited.
- *
- * Whether or not printing is inhibited,
- * the last MSGBUFS characters
- * are saved in msgbuf for inspection later.
+ * Print a character on the console (cf. kl.c).  The last MSGBUFS characters
+ * are saved in msgbuf for inspection.  Polled with a bounded spin, and the
+ * transmit interrupt is masked around the write -- the PL011 analog of kl.c
+ * saving and clearing the DL11 control register -- so kernel printf does not
+ * collide with interrupt-driven tty output and still works before the console
+ * is open and from panic context.  The DL11's console-switch check and
+ * inter-character rubout padding have no PL011 equivalent and are dropped.
@@ -166,2 +211,2 @@
-putchar(c)
-register c;
+void
+klputchar(char c)
@@ -169 +214,2 @@
-	register s, timo;
+	register int timo;
+	unsigned int s;
@@ -173 +219 @@
-		if(msgbufp >= &msgbuf[MSGBUFS])
+		if (msgbufp >= &msgbuf[MSGBUFS])
@@ -176,5 +221,0 @@
-	/*
-	 *  If last char was a break or null, don't print
-	*/
-	if ((KLADDR->rbuf&0177) == 0)
-		return;
@@ -182,6 +223,2 @@
-	/*
-	 * Try waiting for the console tty to come ready,
-	 * otherwise give up after a reasonable time.
-	 */
-	while((KLADDR->tcsr&0200) == 0)
-		if(--timo == 0)
+	while (UARTFR & TXFF)
+		if (--timo == 0)
@@ -189 +226 @@
-	if(c == 0)
+	if (c == 0)
@@ -191,10 +228,6 @@
-	s = KLADDR->tcsr;
-	KLADDR->tcsr = 0;
-	KLADDR->tbuf = c;
-	if(c == '\n') {
-		putchar('\r');
-		putchar(0177);
-		putchar(0177);
-	}
-	putchar(0);
-	KLADDR->tcsr = s;
+	s = UARTIMSC;
+	UARTIMSC &= ~TXI;
+	UARTDR = c;
+	if (c == '\n')
+		klputchar('\r');
+	UARTIMSC = s;
@@ -201,0 +235 @@
+

% usr/sys/dev/stm32ddr.c /dev/null
@@ -0,0 +1,321 @@
+/*
+ *   STM32MP135 clock and DDR bring-up
+ *
+ * ddrinit(), configured as "ddr" in mp135conf, brings up the clocks and DDR
+ * before machine_init() (machdep.c) enables the MMU.
+ *
+ * The ROM loads this kernel (FSBL) from SD into SYSRAM and jumps to _start
+ * (conf/low.s).  Kernel runs in cached SYSRAM; user core + buffer cache live
+ * in cached DDR; peripherals + GIC are Device.  DDR3-1066 register values are
+ * verbatim from the board reference firmware (board.h).
+ */
+#include "../h/param.h"
+#include "../h/seg.h"
+
+void ddrclk(void);
+void ddr_init(void);
+
+/* RCC + DDR controller/PHY + security blocks (board reference firmware) */
+#define RCC		0x50000000U
+#define PWR		0x50001000U
+#define DDRCTRL		0x5A003000U
+#define DDRPHYC		0x5A004000U
+#define BSEC		0x5C005000U
+#define TZC		0x5C006000U
+#define R32(a)		(*(volatile unsigned int *)(a))
+
+/* RCC registers used here (offsets verified against the board headers) */
+#define RCC_OCENSETR	R32(RCC + 0x420)	/* oscillator enable (set-reg) */
+#define RCC_OCRDYR	R32(RCC + 0x428)	/* oscillator ready */
+#define HSEON		0x00000100U		/* OCENSETR/OCRDYR bit 8 */
+#define HSERDY		0x00000100U
+/* PLL2 (DDR PHY clock); fields are value-1 per the RCC encoding */
+#define RCC_RCK12SELR	R32(RCC + 0x480)	/* PLL1/2 reference clock select */
+#define RCC_PLL2CR	R32(RCC + 0x4D0)
+#define RCC_PLL2CFGR1	R32(RCC + 0x4D4)	/* DIVN[8:0], DIVM2[21:16] */
+#define RCC_PLL2CFGR2	R32(RCC + 0x4D8)	/* DIVP[6:0], DIVQ[14:8], DIVR[22:16] */
+#define RCC_PLL2FRACR	R32(RCC + 0x4DC)	/* FRACV[15:3], FRACLE[16] */
+#define PLL12SRC_HSE	0x00000001U		/* RCK12SELR PLL12SRC = HSE */
+#define PLL2_PLLON	0x00000001U
+#define PLL2_RDY	0x00000002U
+#define PLL2_DIVEN	0x00000070U		/* DIVP/Q/R output enables */
+#define PLL2_FRACLE	0x00010000U
+
+/* Bring up DRAM and its clock before machine_init() enables the MMU. */
+void
+ddrinit(void)
+{
+	ddrclk();
+	ddr_init();
+}
+
+/*
+ * DDR clock: HSE (the 24 MHz crystal) feeds PLL2, whose R output clocks the
+ * DDR PHY.  All other clocks are left as the boot ROM set them: the CPU and
+ * buses, the console UART (HSI), the SD card, and the system counter, whose
+ * frequency the ROM leaves in CNTFRQ for clkstart().
+ */
+void
+ddrclk(void)
+{
+	int timo;
+
+	/* HSE on (24 MHz crystal); wait for it to stabilize. */
+	RCC_OCENSETR = HSEON;
+	for (timo = 100000; timo > 0 && !(RCC_OCRDYR & HSERDY); timo--)
+		;
+
+	/*
+	 * PLL2 -> 533 MHz on its R output, which clocks the DDR PHY (DDR3-1066);
+	 * ddr_init() needs this running first.  Coefficients are the board's
+	 * (bootloader setup.c, HSE source, fractional): DIVM2=3 (/3), DIVN=66
+	 * (x66), FRACV=0x1400, DIVP=DIVQ=2, DIVR=1 -> VCO 533 MHz, R = 533 MHz.
+	 * We only ENABLE PLL2 and leave the AXI source on the ROM default: DDR
+	 * takes PLL2_R directly, so there is no live bus-clock switch and a wrong
+	 * value just fails ddr_init() with the console still alive.
+	 * TODO(bench, #28): the AXI-on-PLL2 speedup (a live switch -- park AXI,
+	 * reconfigure, switch back, as HAL_RCC_ClockConfig does) and PLL1 (MPU)
+	 * remain; validate PLL2 lock on the PCB.
+	 */
+	RCC_PLL2CR &= ~PLL2_PLLON;		/* disable before reconfigure */
+	for (timo = 10000; timo > 0 && (RCC_PLL2CR & PLL2_RDY); timo--)
+		;
+	RCC_RCK12SELR = (RCC_RCK12SELR & ~7U) | PLL12SRC_HSE;
+	RCC_PLL2CFGR1 = 0x00020041u;		/* DIVM2=2 (/3), DIVN=65 (x66) */
+	RCC_PLL2CFGR2 = 0x00000101u;		/* DIVP=1 (/2), DIVQ=1 (/2), DIVR=0 (/1) */
+	RCC_PLL2FRACR = 0x1400u << 3;		/* FRACV */
+	RCC_PLL2FRACR |= PLL2_FRACLE;		/* latch fractional value */
+	RCC_PLL2CR |= PLL2_DIVEN;		/* enable P/Q/R outputs */
+	RCC_PLL2CR |= PLL2_PLLON;		/* enable PLL2 */
+	for (timo = 100000; timo > 0 && !(RCC_PLL2CR & PLL2_RDY); timo--)
+		;
+}
+
+/*
+ * DDR controller (DDRCTRL @ DDRCTRL, register offset:value) and PHY (DDRPHYC)
+ * settings for the board's DDR3-1066 (1x4Gb, 533 MHz) part.  Values are the
+ * DDR_* defines from the reference bootloader's board.h; offsets are the
+ * DDRCTRL_TypeDef/DDRPHYC_TypeDef member offsets.  Terminated by off==0xFFFF.
+ */
+struct ddrreg { unsigned short off; unsigned int val; };
+
+/* DDRCTRL static + timing + address-map groups (programmed before INIT0). */
+static const struct ddrreg ddrctrl_main[] = {
+	{ 0x000, 0x00040401u },	/* MSTR */
+	{ 0x010, 0x00000010u },	/* MRCTRL0 */
+	{ 0x014, 0x00000000u },	/* MRCTRL1 */
+	{ 0x020, 0x00000000u },	/* DERATEEN */
+	{ 0x024, 0x00800000u },	/* DERATEINT */
+	{ 0x030, 0x00000000u },	/* PWRCTL */
+	{ 0x034, 0x00400010u },	/* PWRTMG */
+	{ 0x038, 0x00000000u },	/* HWLPCTL */
+	{ 0x050, 0x00210000u },	/* RFSHCTL0 */
+	{ 0x060, 0x00000000u },	/* RFSHCTL3 */
+	{ 0x0C0, 0x00000000u },	/* CRCPARCTL0 */
+	{ 0x180, 0xC2000040u },	/* ZQCTL0 */
+	{ 0x190, 0x02060105u },	/* DFITMG0 */
+	{ 0x194, 0x00000202u },	/* DFITMG1 */
+	{ 0x198, 0x07000000u },	/* DFILPCFG0 */
+	{ 0x1A0, 0xC0400003u },	/* DFIUPD0 */
+	{ 0x1A4, 0x00000000u },	/* DFIUPD1 */
+	{ 0x1A8, 0x00000000u },	/* DFIUPD2 */
+	{ 0x1C4, 0x00000000u },	/* DFIPHYMSTR */
+	{ 0x244, 0x00000001u },	/* ODTMAP */
+	{ 0x300, 0x00000000u },	/* DBG0 */
+	{ 0x304, 0x00000000u },	/* DBG1 */
+	{ 0x30C, 0x00000000u },	/* DBGCMD */
+	{ 0x36C, 0x00000000u },	/* POISONCFG */
+	{ 0x400, 0x00000010u },	/* PCCFG */
+	{ 0x064, 0x0081008Bu },	/* RFSHTMG */
+	{ 0x100, 0x121B2414u },	/* DRAMTMG0 */
+	{ 0x104, 0x000A041Cu },	/* DRAMTMG1 */
+	{ 0x108, 0x0608090Fu },	/* DRAMTMG2 */
+	{ 0x10C, 0x0050400Cu },	/* DRAMTMG3 */
+	{ 0x110, 0x08040608u },	/* DRAMTMG4 */
+	{ 0x114, 0x06060403u },	/* DRAMTMG5 */
+	{ 0x118, 0x02020002u },	/* DRAMTMG6 */
+	{ 0x11C, 0x00000202u },	/* DRAMTMG7 */
+	{ 0x120, 0x00001005u },	/* DRAMTMG8 */
+	{ 0x138, 0x000000A0u },	/* DRAMTMG14 */
+	{ 0x240, 0x06000600u },	/* ODTCFG */
+	{ 0x204, 0x00080808u },	/* ADDRMAP1 */
+	{ 0x208, 0x00000000u },	/* ADDRMAP2 */
+	{ 0x20C, 0x00000000u },	/* ADDRMAP3 */
+	{ 0x210, 0x00001F1Fu },	/* ADDRMAP4 */
+	{ 0x214, 0x07070707u },	/* ADDRMAP5 */
+	{ 0x218, 0x0F070707u },	/* ADDRMAP6 */
+	{ 0x224, 0x00000000u },	/* ADDRMAP9 */
+	{ 0x228, 0x00000000u },	/* ADDRMAP10 */
+	{ 0x22C, 0x00000000u },	/* ADDRMAP11 */
+	{ 0xFFFF, 0 }
+};
+
+/* DDRCTRL performance/QoS group (programmed after INIT0.SKIP_DRAM_INIT). */
+static const struct ddrreg ddrctrl_perf[] = {
+	{ 0x250, 0x00000F01u },	/* SCHED */
+	{ 0x254, 0x00000000u },	/* SCHED1 */
+	{ 0x25C, 0x00000001u },	/* PERFHPR1 */
+	{ 0x264, 0x04000200u },	/* PERFLPR1 */
+	{ 0x26C, 0x08000400u },	/* PERFWR1 */
+	{ 0x404, 0x00000000u },	/* PCFGR_0 */
+	{ 0x408, 0x00000000u },	/* PCFGW_0 */
+	{ 0x494, 0x00100009u },	/* PCFGQOS0_0 */
+	{ 0x498, 0x00000020u },	/* PCFGQOS1_0 */
+	{ 0x49C, 0x01100B03u },	/* PCFGWQOS0_0 */
+	{ 0x4A0, 0x01000200u },	/* PCFGWQOS1_0 */
+	{ 0xFFFF, 0 }
+};
+
+/* DDRPHYC register + timing groups (programmed after the PHY resets clear). */
+static const struct ddrreg ddrphy_regs[] = {
+	{ 0x008, 0x01442E02u },	/* PGCR */
+	{ 0x024, 0x10400812u },	/* ACIOCR */
+	{ 0x028, 0x00000C40u },	/* DXCCR */
+	{ 0x02C, 0xF200011Fu },	/* DSGCR */
+	{ 0x030, 0x0000000Bu },	/* DCR */
+	{ 0x050, 0x00010000u },	/* ODTCR */
+	{ 0x184, 0x00000038u },	/* ZQ0CR1 */
+	{ 0x1C0, 0x0000CE81u },	/* DX0GCR */
+	{ 0x200, 0x0000CE81u },	/* DX1GCR */
+	{ 0x018, 0x0022AA5Bu },	/* PTR0 */
+	{ 0x01C, 0x04841104u },	/* PTR1 */
+	{ 0x020, 0x042DA068u },	/* PTR2 */
+	{ 0x034, 0x38D488D0u },	/* DTPR0 */
+	{ 0x038, 0x098B00D8u },	/* DTPR1 */
+	{ 0x03C, 0x10023600u },	/* DTPR2 */
+	{ 0x040, 0x00000840u },	/* MR0 */
+	{ 0x044, 0x00000000u },	/* MR1 */
+	{ 0x048, 0x00000208u },	/* MR2 */
+	{ 0x04C, 0x00000000u },	/* MR3 */
+	{ 0xFFFF, 0 }
+};
+
+#define DDRC(o)		R32(DDRCTRL + (o))
+#define DPHY(o)		R32(DDRPHYC + (o))
+#define RCC_DDRITFCR	R32(RCC + 0x5C0)
+#define DDR_ALLRST	0x000FC000U	/* CAPB|AXI|CORE|DPHYAPB|DPHY|DPHYCTL rst */
+#define DDR_CLKEN	0x00000251U	/* DDRC1|DDRPHYC|DDRPHYCAPB|DDRCAPB en */
+#define DDR_PHYRST	0x000C0000U	/* DPHYRST|DPHYCTLRST */
+#define DDR_CAPBRST	0x00004000U	/* DDRCAPBRST */
+#define DDR_LATERST	0x00038000U	/* DDRCORERST|DDRCAXIRST|DPHYAPBRST */
+#define DDR_AXIDCGEN	0x00000100U
+#define DFIMISC_COMPLETE 0x00000001U	/* DDRCTRL DFIMISC.DFI_INIT_COMPLETE_EN */
+#define DDR_PIR_INIT	0x0001007FU	/* DLLSRST|DLLLOCK|ZCAL|ITMSRST|DRAMINIT|DRAMRST|ICPC|INIT */
+#define DDR_PIR_TRAIN	0x00000081U	/* QSTRN|INIT: DQS gate (data-eye) training */
+#define RFSHCTL3_DISAUREF 0x00000001U	/* RFSHCTL3.dis_auto_refresh */
+
+/*
+ * DDR3-1066 bring-up (533 MHz, 512 MB), translated from the reference
+ * bootloader's HAL_DDR_Init.  Unverifiable in QEMU (no DDR-controller model),
+ * so it is a bench candidate -- the register values/offsets above are exact,
+ * but the analog parts (PHY DLL lock, ZQ calibration, DQS training triggered
+ * by PIR and polled on PGSR.IDONE) only converge against real silicon.
+ * TODO(bench, #28): requires PLL2_R = 533 MHz from ddrclk first.  Tune on
+ * the PCB: if PGSR.IDONE or STAT.operating_mode never settles, add the SWCTL/
+ * SWSTAT sw_done handshakes the HAL wraps around quasi-dynamic writes.
+ */
+void
+ddr_init(void)
+{
+	const struct ddrreg *r;
+	int timo;
+
+	/* If the DDR I/O pads are in retention (PWR_CR3.DDRRETEN, e.g. left from a
+	 * prior low-power state), the PHY cannot drive the DRAM and init/training
+	 * fail.  Disable retention exactly as the bootloader does.  PWR_CR3 @ 0x5000100C. */
+	if (R32(0x5000100C) & (1U << 12)) {
+		R32(0x5000100C) |= (1U << 11);		/* DDRSRDIS = 1 */
+		R32(0x5000100C) &= ~(1U << 12);		/* DDRRETEN = 0 */
+	}
+
+	/* Enable the MCE + TZC peripheral clocks before touching TZC, else the
+	 * bus access to an unclocked peripheral stalls (as the bootloader does). */
+	R32(RCC + 0x780) = 0x00000002U;		/* AHB6ENSETR: MCE clock (bit 1) */
+	R32(RCC + 0x740) = 0x00000800U;		/* APB5ENSETR: TZC clock (bit 11) */
+	(void)R32(RCC + 0x740);			/* read-back: clocks live */
+
+	/* TZC: open DDR region 0 to all masters (non-secure) */
+	R32(TZC + 0x008) = 0;			/* GATE_KEEPER off */
+	R32(TZC + 0x114) = 0xFFFFFFFFU;		/* REG_ID_ACCESS0 */
+	R32(TZC + 0x110) = 0xC0000001U;		/* REG_ATTRIBUTES0 */
+	R32(TZC + 0x008) = 1;			/* GATE_KEEPER on */
+	R32(BSEC + 0x000) = 0x47FU;		/* BSEC_DENABLE: unlock debug */
+
+	/* 1. assert resets, enable DDR clocks, release PHY + APB resets */
+	RCC_DDRITFCR &= ~DDR_AXIDCGEN;		/* no clock gating during init */
+	RCC_DDRITFCR |= DDR_ALLRST;
+	RCC_DDRITFCR |= DDR_CLKEN;
+	RCC_DDRITFCR &= ~DDR_PHYRST;		/* deassert DPHY rstn + ctl_rstn */
+	RCC_DDRITFCR &= ~DDR_CAPBRST;		/* deassert presetn */
+	for (timo = 1000; timo > 0; timo--)	/* >=128 cycles for end logic */
+		;
+
+	/* 2. program the controller while the PHY is held off */
+	DDRC(0x1B0) &= ~DFIMISC_COMPLETE;	/* stop uMCTL2 before PHY ready */
+	for (r = ddrctrl_main; r->off != 0xFFFF; r++)
+		DDRC(r->off) = r->val;
+	DDRC(0x000) &= ~0x8000U;			/* DDR3: clear MSTR.DLL_OFF_MODE */
+	DDRC(0x0D0) = 0x4002004EU;		/* INIT0: skip_dram_init=0b01 (PHY inits DRAM) + cke timings */
+	for (r = ddrctrl_perf; r->off != 0xFFFF; r++)
+		DDRC(r->off) = r->val;
+
+	/* 3. release controller core/AXI and PHY APB resets */
+	RCC_DDRITFCR &= ~DDR_LATERST;
+
+	/* 4. program the PHY */
+	for (r = ddrphy_regs; r->off != 0xFFFF; r++)
+		DPHY(r->off) = r->val;
+	DPHY(0x044) &= ~0x1U;			/* DDR3: clear MR1.DE */
+
+	/* 4b. wait for the PHY's post-reset auto-init (PGSR.IDONE) BEFORE issuing
+	 * the PIR.  The reference does ddrphy_idone_wait() here; writing PIR while
+	 * the PHY is still auto-initializing corrupts the DRAM init. */
+	for (timo = 1000000; timo > 0 && !(DPHY(0x00C) & 0x1U); timo--)
+		;
+
+	/* 5. run PHY init (DLL/ZQ/ITM/DRAM init) and wait for completion */
+	DPHY(0x004) = DDR_PIR_INIT;		/* PIR */
+	for (timo = 0; timo < 20; timo++)	/* >=10 cycles before PGSR read */
+		;
+	for (timo = 1000000; timo > 0 &&
+	     !(DPHY(0x00C) & 0x1U) && !(DPHY(0x00C) & 0x3E0U); timo--)
+		;				/* poll PGSR.IDONE or error (HAL waits on IDONE) */
+
+	/* 6. signal DFI init complete (quasi-dynamic -> sw_done handshake), wait NORMAL.
+	 * SWCTL.sw_done=0, change reg, sw_done=1, wait SWSTAT.sw_done_ack -- without
+	 * this the controller ignores the change. */
+	DDRC(0x320) &= ~0x1U;			/* SWCTL.sw_done = 0 */
+	DDRC(0x1B0) |= DFIMISC_COMPLETE;
+	DDRC(0x320) |= 0x1U;			/* SWCTL.sw_done = 1 */
+	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
+		;				/* wait SWSTAT.sw_done_ack */
+	for (timo = 1000000; timo > 0 && (DDRC(0x004) & 0x7U) != 0x1U; timo--)
+		;				/* poll STAT.operating_mode == NORMAL */
+
+	/* 6b. DQS gate (data-eye) training -- without it the read data path is
+	 * uncalibrated and DDR reads stall.  Disable auto-refresh + dfi_init_complete
+	 * via the sw_done handshake (quasi-dynamic) so refresh does not corrupt the
+	 * training, run PIR=QSTRN, poll PGSR, then restore the same way. */
+	DDRC(0x320) &= ~0x1U;
+	DDRC(0x1B0) &= ~DFIMISC_COMPLETE;	/* clear dfi_init_complete_en */
+	DDRC(0x060) |= RFSHCTL3_DISAUREF;	/* RFSHCTL3: disable auto-refresh */
+	DDRC(0x320) |= 0x1U;
+	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
+		;
+	DPHY(0x004) = DDR_PIR_TRAIN;		/* PIR = QSTRN|INIT */
+	for (timo = 0; timo < 10000; timo++)	/* ~10us: let PGSR.IDONE drop before polling */
+		;
+	for (timo = 1000000; timo > 0 &&
+	     !(DPHY(0x00C) & 0x1U) && !(DPHY(0x00C) & 0x3E0U); timo--)
+		;				/* poll PGSR.IDONE or error */
+	DDRC(0x320) &= ~0x1U;
+	DDRC(0x060) = 0x00000000u;		/* RFSHCTL3: restore (auto-refresh on) */
+	DDRC(0x1B0) |= DFIMISC_COMPLETE;	/* restore dfi_init_complete_en */
+	DDRC(0x320) |= 0x1U;
+	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
+		;
+
+	/* 7. open the AXI port, restore clock gating */
+	DDRC(0x490) |= 0x1U;			/* PCTRL_0.port_en */
+	RCC_DDRITFCR |= DDR_AXIDCGEN;
+}

% usr/sys/dev/stm32sd.c usr/sys/dev/rk.c
@@ -2 +2,12 @@
- * RK disk driver
+ *   STM32 SDMMC block driver (SDMMC1 on the MP135 board)
+ *
+ * The bulk-storage block device.  Same async, interrupt-driven, queued model
+ * as rk.c / virtio_blk.c: sdstrategy() puts the buffer on sdtab and kicks the
+ * controller via sdstart(); sdstart() programs one SD block transfer through
+ * the SDMMC internal DMA and returns; the transfer-complete interrupt
+ * (sdintr) runs iodone() and starts the next queued buffer.  bio.c's iowait()
+ * sleeps on the buffer until then.
+ *
+ * Like v7's drivers it assumes working hardware: the boot ROM has just read
+ * the kernel from this card, so clocks, pins and the card (selected, in
+ * transfer state, SDHC block addressing) are used as the ROM left them.
@@ -4 +14,0 @@
-
@@ -6 +15,0 @@
-#include "../h/systm.h"
@@ -8,18 +17,64 @@
-#include "../h/conf.h"
-#include	"../h/dir.h"
-#include "../h/user.h"
-
-#define	RKADDR	((struct device *)0177400)
-#define	NRK	4
-#define	NRKBLK	4872
-
-#define	RESET	0
-#define	WCOM	2
-#define	RCOM	4
-#define	GO	01
-#define	DRESET	014
-#define	IENABLE	0100
-#define	DRY	0200
-#define	ARDY	0100
-#define	WLO	020000
-#define	CTLRDY	0200
+#include "../h/seg.h"
+
+
+void dmbsy(void);
+void iodone(struct buf *bp);
+void deverror(struct buf *bp, int o1, int o2);
+void dcflush(unsigned int addr, unsigned int n);	/* clean+invalidate D-cache (mch.s) */
+int intr_disable(void);
+void intr_restore(int s);
+void physio(int (*strat)(), struct buf *bp, dev_t dev, int rw);
+
+extern int	dk_busy;
+extern long	dk_numb[3];
+extern long	dk_wds[3];
+
+#define	SDMMC1	0x58005000U
+#define	SD(off)	(*(volatile unsigned int *)(SDMMC1 + (off)))
+#define	POWER	0x00
+#define	CLKCR	0x04
+#define	ARG	0x08
+#define	CMD	0x0c
+#define	RESP1	0x14
+#define	DTIMER	0x24
+#define	DLEN	0x28
+#define	DCTRL	0x2c
+#define	STA	0x34
+#define	ICR	0x38
+#define	MASK	0x3c
+#define	IDMACTRL 0x50
+#define	IDMABSIZE 0x54
+#define	IDMABASER 0x58
+/* CMD register fields */
+#define	CMD_WAITRESP_SHORT 0x0100U	/* short response */
+#define	CMD_CMDTRANS	0x0040U		/* command transfers data */
+#define	CMD_CPSMEN	0x1000U		/* command path state machine enable */
+/* STA bits */
+#define	STA_CCRCFAIL	0x0001U
+#define	STA_DCRCFAIL	0x0002U
+#define	STA_CTIMEOUT	0x0004U
+#define	STA_DTIMEOUT	0x0008U
+#define	STA_RXOVERR	0x0020U
+#define	STA_CMDREND	0x0040U
+#define	STA_CMDSENT	0x0080U
+#define	STA_DATAEND	0x0100U
+#define	STA_DABORT	0x0800U
+#define	STA_CMDERR	(STA_CCRCFAIL|STA_CTIMEOUT)
+#define	STA_DATERR	(STA_DCRCFAIL|STA_DTIMEOUT|STA_RXOVERR)
+#define	STA_STATIC	0x1fe00fffU	/* all clearable flags (ICR) */
+/* DCTRL bits */
+#define	DCTRL_DTEN	0x0001U
+#define	DCTRL_DTDIR	0x0002U		/* 1 = card -> controller (read) */
+#define	DCTRL_BLK512	0x0090U		/* DBLOCKSIZE = 9 (512 bytes) */
+/* IDMA */
+#define	IDMA_IDMAEN	0x0001U
+/* card commands */
+#define	READ_BLOCK	17
+#define	WRITE_BLOCK	24
+
+int	sdirq = 82;		/* GIC INTID of SDMMC1 (SPI 50) */
+struct buf sdtab;
+static struct buf *sd_cur;
+static int sd_retry;
+
+#define	SD_RETRIES	10
@@ -28 +83,3 @@
- * Monitoring device bit
+ * Issue one command.  resp is 0 (none) or CMD_WAITRESP_SHORT; data!=0
+ * marks a data-transfer command.  Returns RESP1, or -1 on command
+ * timeout/CRC error.
@@ -30,3 +87,2 @@
-#define	DK_N	1
-
-struct	device
+static int
+sd_cmd(unsigned int idx, unsigned int arg, unsigned int resp, int data)
@@ -34,7 +90 @@
-	int	rkds;
-	int	rker;
-	int	rkcs;
-	int	rkwc;
-	caddr_t	rkba;
-	int	rkda;
-};
+	register int timo;
@@ -42,2 +92,17 @@
-struct	buf	rktab;
-struct	buf	rrkbuf;
+	SD(ICR) = STA_STATIC;
+	SD(ARG) = arg;
+	SD(CMD) = idx | resp | CMD_CPSMEN | (data ? CMD_CMDTRANS : 0);
+	for (timo = 1000000; timo > 0; timo--) {
+		unsigned int s = SD(STA);
+		if (s & STA_CTIMEOUT)
+			return(-1);		/* no response from card */
+		if (resp == 0) {
+			if (s & STA_CMDSENT)
+				return(0);
+		} else if (s & STA_CCRCFAIL)
+			return(-1);
+		else if (s & STA_CMDREND)
+			return((int)SD(RESP1));
+	}
+	return(-1);
+}
@@ -45,2 +110,6 @@
-rkstrategy(bp)
-register struct buf *bp;
+/*
+ * The card is as the boot ROM left it; just make sure the controller is
+ * powered and allow the longest data timeout.
+ */
+void
+sdinit(void)
@@ -47,0 +117,4 @@
+	SD(POWER) = 0x03;
+	SD(DTIMER) = 0xffffffffU;
+	dmbsy();
+}
@@ -49,5 +122,13 @@
-	if(bp->b_flags&B_PHYS)
-		mapalloc(bp);
-	if (bp->b_blkno >= NRKBLK) {
-		bp->b_flags |= B_ERROR;
-		iodone(bp);
+/*
+ * Program one block transfer for the buffer at the head of the queue through
+ * the SDMMC internal DMA, and enable the data-done interrupt.  (cf. rkstart.)
+ */
+static void
+sdstart(void)
+{
+	register struct buf *bp;
+	unsigned int blk;
+
+	if ((bp = sdtab.b_actf) == NULL)
+		return;
+	if (sdtab.b_active)
@@ -54,0 +136,3 @@
+	if (bp != sd_cur) {
+		sd_cur = bp;
+		sd_retry = 0;
@@ -56,10 +140,21 @@
-	bp->av_forw = (struct buf *)NULL;
-	spl5();
-	if(rktab.b_actf == NULL)
-		rktab.b_actf = bp;
-	else
-		rktab.b_actl->av_forw = bp;
-	rktab.b_actl = bp;
-	if(rktab.b_active == NULL)
-		rkstart();
-	spl0();
+	sdtab.b_active++;
+	blk = (unsigned int)bp->b_blkno;
+	dcflush((unsigned int)bp->b_un.b_addr, bp->b_bcount);
+	SD(ICR) = STA_STATIC;
+	/* Match the HAL IDMA single-buffer read/write order: program the data
+	 * path (DLEN + DCTRL block size/dir, DPSM left off) first, then point the
+	 * internal DMA at the buffer and enable it, then issue the command (which
+	 * sets CMDTRANS and starts the DPSM).  IDMABSIZE is double-buffer-only and
+	 * must not be written for single-buffer transfers. */
+	SD(DCTRL) = 0;
+	SD(DLEN) = bp->b_bcount;
+	SD(DCTRL) = DCTRL_BLK512 |
+	    ((bp->b_flags & B_READ) ? DCTRL_DTDIR : 0);
+	SD(IDMABASER) = (unsigned int)bp->b_un.b_addr;
+	SD(IDMACTRL) = IDMA_IDMAEN;
+	SD(MASK) = STA_DATAEND | STA_DATERR;	/* interrupt on done/error */
+	sd_cmd((bp->b_flags & B_READ) ? READ_BLOCK : WRITE_BLOCK, blk,
+	    CMD_WAITRESP_SHORT, 1);
+	dk_busy |= 1;
+	dk_numb[0]++;
+	dk_wds[0] += bp->b_bcount>>6;
@@ -68 +163,2 @@
-rkstart()
+int
+sdstrategy(struct buf *bp)
@@ -70,4 +166 @@
-	register struct buf *bp;
-	register com;
-	daddr_t bn;
-	int dn, cn, sn;
+	int s, idle;
@@ -75,19 +168,12 @@
-	if ((bp = rktab.b_actf) == NULL)
-		return;
-	rktab.b_active++;
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
-	dk_busy |= 1<<DK_N;
-	dk_numb[DK_N] += 1;
-	com = bp->b_bcount>>6;
-	dk_wds[DK_N] += com;
+	bp->av_forw = NULL;
+	s = intr_disable();
+	if (sdtab.b_actf == NULL)
+		sdtab.b_actf = bp;
+	else
+		sdtab.b_actl->av_forw = bp;
+	sdtab.b_actl = bp;
+	idle = (sdtab.b_active == 0);
+	intr_restore(s);
+	if (idle)
+		sdstart();
+	return(0);
@@ -96 +182,6 @@
-rkintr()
+/*
+ * Transfer-complete interrupt: finish the active buffer and start the next.
+ * (cf. rkintr.)
+ */
+int
+sdintr(void)
@@ -98,0 +190 @@
+	unsigned int sta;
@@ -100,13 +192,13 @@
-	if (rktab.b_active == NULL)
-		return;
-	dk_busy &= ~(1<<DK_N);
-	bp = rktab.b_actf;
-	rktab.b_active = NULL;
-	if (RKADDR->rkcs < 0) {		/* error bit */
-		deverror(bp, RKADDR->rker, RKADDR->rkds);
-		RKADDR->rkcs = RESET|GO;
-		while((RKADDR->rkcs&CTLRDY) == 0)
-			;
-		if (++rktab.b_errcnt <= 10) {
-			rkstart();
-			return;
+	sta = SD(STA);
+	SD(ICR) = STA_STATIC;
+	SD(MASK) = 0;
+	SD(IDMACTRL) = 0;
+	if (sdtab.b_active == 0)
+		return(0);
+	dk_busy &= ~1;
+	bp = sdtab.b_actf;
+	sdtab.b_active = 0;
+	if (sta & STA_DATERR) {
+		if (sd_retry++ < SD_RETRIES) {
+			sdstart();
+			return(0);
@@ -113,0 +206 @@
+		deverror(bp, (int)sta, 0);
@@ -115,3 +208,5 @@
-	}
-	rktab.b_errcnt = 0;
-	rktab.b_actf = bp->av_forw;
+	} else if (bp->b_flags & B_READ)
+		dcflush((unsigned int)bp->b_un.b_addr, bp->b_bcount);
+	sd_cur = NULL;
+	sd_retry = 0;
+	sdtab.b_actf = bp->av_forw;
@@ -120 +215,2 @@
-	rkstart();
+	sdstart();
+	return(0);
@@ -123 +219,4 @@
-rkread(dev)
+struct	buf	rsdbuf;
+
+int
+sdread(dev)
@@ -127 +226,2 @@
-	physio(rkstrategy, &rrkbuf, dev, B_READ);
+	physio(sdstrategy, &rsdbuf, dev, B_READ);
+	return(0);
@@ -130 +230,2 @@
-rkwrite(dev)
+int
+sdwrite(dev)
@@ -134 +235,2 @@
-	physio(rkstrategy, &rrkbuf, dev, B_WRITE);
+	physio(sdstrategy, &rsdbuf, dev, B_WRITE);
+	return(0);

% usr/sys/dev/stm32usart.c usr/sys/dev/kl.c
@@ -2 +2,11 @@
- *   KL/DL-11 driver
+ *   STM32 USART console driver (UART4 on the MP135 board)
+ *
+ * Same Unix character-device/tty model as kl.c/pl011.c -- the cdevsw
+ * open/close/read/write/ioctl entries hang the line discipline (tty.c) off
+ * the console, output is paced by the transmit interrupt and input arrives
+ * on the receive interrupt.  Differs only in the hardware: an STM32 USART
+ * (UART4) instead of a PL011, one GIC line (INTID 85) demultiplexed via the
+ * interrupt/status register.  This file is built for both boards but is the
+ * live console only on the MP135 (the QEMU build uses pl011.c); its register
+ * pokes are never reached on QEMU because /dev/console there has a different
+ * major.
@@ -6 +16 @@
-#include	"../h/dir.h"
+#include "../h/dir.h"
@@ -11,27 +20,0 @@
-/* base address */
-#define	KLADDR	((struct device *)0177560)	/* console */
-#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
-#define	DLBASE	((struct device *)0175610)	/* dl-e */
-#define	NKL11	1
-#define	NDL11	0
-#define DSRDY	02
-#define	RDRENB	01
-#define	DLDELAY	4	/* Extra delay for DL's (double buff) */
-
-#define	NL1	000400
-#define	NL2	001000
-#define	CR2	020000
-#define	FF1	040000
-#define	TAB1	002000
-
-struct	tty kl11[NKL11+NDL11];
-int	klstart();
-int	ttrstrt();
-char	partab[];
-
-struct device {
-	int	rcsr;
-	int	rbuf;
-	int	tcsr;
-	int	tbuf;
-};
@@ -39,2 +22,85 @@
-klopen(dev, flag)
-dev_t dev;
+#define	UART4	0x40010000U		/* APB1 UART4 */
+#define	RCC	0x50000000U		/* reset/clock controller */
+#define	NCONS	1			/* one console line */
+#define	OUTDELAY 4		/* slop added to ttyoutput delay characters */
+
+#define	CR1	(*(volatile unsigned int *)(UART4+0x00))
+#define	BRR	(*(volatile unsigned int *)(UART4+0x0c))
+#define	ISR	(*(volatile unsigned int *)(UART4+0x1c))
+#define	ICR	(*(volatile unsigned int *)(UART4+0x20))
+#define	RDR	(*(volatile unsigned int *)(UART4+0x24))
+#define	TDR	(*(volatile unsigned int *)(UART4+0x28))
+#define	APB1ENSETR (*(volatile unsigned int *)(RCC+0x700))	/* APB1 clk set-reg */
+#define	UART4CKSELR (*(volatile unsigned int *)(RCC+0x61c))	/* UART4 kernel clk sel */
+#define	AHB4ENSETR (*(volatile unsigned int *)(RCC+0x770))	/* AHB4 (non-secure) clk set */
+#define	GPIODEN	0x00000008U		/* AHB4ENSETR bit 3: GPIOD bus clock */
+#define	GPIOD	0x50005000U		/* GPIO port D (UART4 pins) */
+#define	GPIOD_MODER (*(volatile unsigned int *)(GPIOD+0x00))
+#define	GPIOD_AFRL  (*(volatile unsigned int *)(GPIOD+0x20))	/* AF for pins 0-7 */
+#define	GPIOD_AFRH  (*(volatile unsigned int *)(GPIOD+0x24))	/* AF for pins 8-15 */
+#define	CR1_UE	0x00000001U		/* USART enable */
+#define	CR1_RE	0x00000004U		/* receiver enable */
+#define	CR1_TE	0x00000008U		/* transmitter enable */
+#define	CR1_RXNEIE 0x00000020U		/* receive-not-empty interrupt enable */
+#define	CR1_TXEIE  0x00000080U		/* transmit-empty interrupt enable */
+#define	CR1_FIFOEN 0x20000000U		/* enable RX/TX FIFOs */
+#define	ISR_RXNE 0x00000020U		/* read data register not empty */
+#define	ISR_TXE	0x00000080U		/* transmit data register empty */
+#define	ICR_ERR	0x0000000fU		/* clear PE/FE/NE/ORE error flags */
+#define	UART4EN	0x00010000U		/* APB1ENSETR bit 16: UART4 bus clock */
+#define	UART4SRC_HSI 0x00000002U	/* UART4CKSELR: kernel clock = HSI (64 MHz) */
+
+struct	tty cons[NCONS];
+int	usirq = 85;		/* GIC INTID of the UART4 console (SPI 53) */
+extern char partab[];
+void ttyopen(dev_t dev, struct tty *tp);
+void ttyclose(struct tty *tp);
+void ttychars(struct tty *tp);
+int ttread(struct tty *tp);
+caddr_t ttwrite(struct tty *tp);
+int ttioccomm(int com, struct tty *tp, caddr_t addr, dev_t dev);
+void ttyinput(int c, struct tty *tp);
+void ttstart(struct tty *tp);
+int ttrstrt(struct tty *tp);
+void timeout(int (*fun)(), caddr_t arg, int tim);
+void wakeup(caddr_t chan);
+int getc(struct clist *p);
+int usstart(struct tty *tp);
+int usrint(dev_t dev);
+int usxint(dev_t dev);
+void usputchar(char c);			/* defined below */
+
+/*
+ * Bring UART4 up for the console before the first kernel printf: enable its
+ * APB1 bus clock and select HSI (64 MHz, running at reset) as the kernel
+ * clock, then program 115200 8N1 -- BRR = 64e6/115200 = 556 (oversampling 16)
+ * -- and enable the transmitter and receiver.  Because UART4 runs off HSI, the
+ * console works at the ROM's default clocks, before clock_init() sets up the
+ * PLLs -- so even early boot and panics are visible.  Called from machine_init
+ * via the board-agnostic console hook.  Values imported from the reference
+ * bootloader (UART4 TX=PD6, RX=PD8, AF8; 115200; HSI source).
+ * GPIOD's clock is enabled through the non-secure AHB4ENSETR (RCC+0x770),
+ * matching the reference bootloader's __HAL_RCC_GPIOD_CLK_ENABLE; the secure
+ * register (0x768) leaves the port unclocked so the pin mux silently no-ops.
+ */
+void
+usinit(void)
+{
+	/* Route UART4 to its pads: PD6 (TX) and PD8 (RX) -> alternate function 8.
+	 * Without this the UART would transmit into a disconnected pin. */
+	AHB4ENSETR = GPIODEN;			/* GPIOD bus clock (set-register) */
+	(void)AHB4ENSETR;			/* read-back: clock live before access */
+	GPIOD_MODER = (GPIOD_MODER & ~((3U<<12)|(3U<<16))) | (2U<<12) | (2U<<16);
+	GPIOD_AFRL = (GPIOD_AFRL & ~(0xfU<<24)) | (8U<<24);	/* PD6 -> AF8 */
+	GPIOD_AFRH = (GPIOD_AFRH & ~(0xfU<<0))  | (8U<<0);	/* PD8 -> AF8 */
+
+	APB1ENSETR = UART4EN;			/* UART4 bus clock (set-register) */
+	(void)APB1ENSETR;			/* read-back: clock live before access */
+	UART4CKSELR = (UART4CKSELR & ~7U) | UART4SRC_HSI;
+	CR1 = 0;				/* disable before reconfigure */
+	BRR = 556;				/* 64 MHz / 115200 */
+	CR1 = CR1_FIFOEN | CR1_UE | CR1_TE | CR1_RE; /* 8N1, FIFOs, TX + RX */
+}
+
+int
+usopen(dev_t dev, int flag)
@@ -42 +107,0 @@
-	register struct device *addr;
@@ -44 +108,0 @@
-	register d;
@@ -46,2 +110,2 @@
-	d = minor(dev);
-	if(d >= NKL11+NDL11) {
+	(void)flag;
+	if(minor(dev) >= NCONS) {
@@ -49 +113 @@
-		return;
+		return(0);
@@ -51,14 +115,3 @@
-	tp = &kl11[d];
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
-	tp->t_oproc = klstart;
+	tp = &cons[minor(dev)];
+	tp->t_addr = (caddr_t)UART4;
+	tp->t_oproc = usstart;
@@ -67 +120 @@
-		tp->t_flags = EVENP|LCASE|ECHO|XTABS|CRMOD|CR2;
+		tp->t_flags = EVENP|ODDP|ECHO|XTABS|CRMOD;
@@ -70,2 +123 @@
-	addr->rcsr |= IENABLE|DSRDY|RDRENB;
-	addr->tcsr |= IENABLE;
+	CR1 |= CR1_RXNEIE;		/* enable receive interrupts */
@@ -72,0 +125 @@
+	return(0);
@@ -75,3 +128,2 @@
-klclose(dev, flag)
-dev_t dev;
-int flag;
+int
+usclose(dev_t dev, int flag)
@@ -79 +131,4 @@
-	register struct tty *tp;
+	(void)flag;
+	ttyclose(&cons[minor(dev)]);
+	return(0);
+}
@@ -81,2 +136,5 @@
-	tp = &kl11[minor(dev)];
-	ttyclose(tp);
+int
+usread(dev_t dev)
+{
+	ttread(&cons[minor(dev)]);
+	return(0);
@@ -85,2 +143,2 @@
-klread(dev)
-dev_t dev;
+int
+uswrite(dev_t dev)
@@ -88 +146,2 @@
-	ttread(&kl11[minor(dev)]);
+	ttwrite(&cons[minor(dev)]);
+	return(0);
@@ -91,2 +150,8 @@
-klwrite(dev)
-dev_t dev;
+/*
+ * Transmitter ready: hand the next queued character to UART4.  Output
+ * delays (characters above 0177) are honored as in the v7 console driver;
+ * the transmit-empty interrupt is level-sensitive, so it is masked whenever
+ * the output queue drains.
+ */
+int
+usstart(struct tty *tp)
@@ -94 +159,19 @@
-	ttwrite(&kl11[minor(dev)]);
+	register int c;
+
+	if ((ISR & ISR_TXE) == 0)
+		return(0);
+	if ((c=getc(&tp->t_outq)) >= 0) {
+		if (tp->t_flags&RAW)
+			TDR = c & 0177;	/* 8N1 glass tty: no parity bit */
+		else if (c<=0177)
+			TDR = c;
+		else {
+			timeout(ttrstrt, (caddr_t)tp, (c&0177) + OUTDELAY);
+			tp->t_state |= TIMEOUT;
+			CR1 &= ~CR1_TXEIE;
+			return(0);
+		}
+		CR1 |= CR1_TXEIE;
+	} else
+		CR1 &= ~CR1_TXEIE;
+	return(0);
@@ -97,2 +180,2 @@
-klxint(dev)
-dev_t dev;
+int
+usxint(dev_t dev)
@@ -102 +185 @@
-	tp = &kl11[minor(dev)];
+	tp = &cons[minor(dev)];
@@ -104,5 +187,3 @@
-	if (tp->t_state&ASLEEP && tp->t_outq.c_cc<=TTLOWAT)
-		if (tp->t_chan)
-			mcstart(tp->t_chan, (caddr_t)&tp->t_outq);
-		else
-			wakeup((caddr_t)&tp->t_outq);
+	if ((tp->t_state&ASLEEP) && tp->t_outq.c_cc<=TTLOWAT)
+		wakeup((caddr_t)&tp->t_outq);
+	return(0);
@@ -111,2 +192,2 @@
-klrint(dev)
-dev_t dev;
+int
+usrint(dev_t dev)
@@ -115 +195,0 @@
-	register struct device *addr;
@@ -118,5 +198,7 @@
-	tp = &kl11[minor(dev)];
-	addr = (struct device *)tp->t_addr;
-	c = addr->rbuf;
-	addr->rcsr |= RDRENB;
-	ttyinput(c, tp);
+	tp = &cons[minor(dev)];
+	while (ISR & ISR_RXNE) {
+		c = RDR;
+		ttyinput(c, tp);
+	}
+	ICR = ICR_ERR;			/* clear overrun/framing errors */
+	return(0);
@@ -125,3 +207,2 @@
-klioctl(dev, cmd, addr, flag)
-caddr_t addr;
-dev_t dev;
+int
+usioctl(dev_t dev, int cmd, caddr_t addr, int flag)
@@ -129 +210,2 @@
-	if (ttioccom(cmd, &kl11[minor(dev)], addr, dev)==0)
+	(void)flag;
+	if (ttioccomm(cmd, &cons[minor(dev)], addr, dev)==0)
@@ -130,0 +213 @@
+	return(0);
@@ -133,2 +216,7 @@
-klstart(tp)
-register struct tty *tp;
+/*
+ * Console interrupt.  One GIC line serves UART4; the interrupt/status
+ * register says whether the receiver, transmitter, or both need service,
+ * demultiplexing into the receive/transmit halves above.
+ */
+int
+usintr(void)
@@ -136,2 +224 @@
-	register c;
-	register struct device *addr;
+	unsigned int isr = ISR;
@@ -139,13 +226,5 @@
-	addr = (struct device *)tp->t_addr;
-	if((addr->tcsr&DONE) == 0)
-		return;
-	if ((c=getc(&tp->t_outq)) >= 0) {
-		if (tp->t_flags&RAW)
-			addr->tbuf = c;
-		else if (c<=0177)
-			addr->tbuf = c | (partab[c]&0200);
-		else {
-			timeout(ttrstrt, (caddr_t)tp, (c&0177) + DLDELAY);
-			tp->t_state |= TIMEOUT;
-		}
-	}
+	if (isr & ISR_RXNE)
+		usrint(0);
+	if ((isr & ISR_TXE) && (CR1 & CR1_TXEIE))
+		usxint(0);
+	return(0);
@@ -154 +233 @@
-char	*msgbufp = msgbuf;	/* Next saved printf character */
+
@@ -156,9 +235,4 @@
- * Print a character on console.
- * Attempts to save and restore device
- * status.
- * If the switches are 0, all
- * printing is inhibited.
- *
- * Whether or not printing is inhibited,
- * the last MSGBUFS characters
- * are saved in msgbuf for inspection later.
+ * Print a character on the console (cf. kl.c).  Polled with a bounded spin,
+ * the transmit interrupt masked around the write so kernel printf does not
+ * collide with interrupt-driven tty output; works before the console is open
+ * and from panic context.  The last MSGBUFS characters are saved in msgbuf.
@@ -166,2 +240,2 @@
-putchar(c)
-register c;
+void
+usputchar(char c)
@@ -169 +243,2 @@
-	register s, timo;
+	register int timo;
+	unsigned int s;
@@ -173 +248 @@
-		if(msgbufp >= &msgbuf[MSGBUFS])
+		if (msgbufp >= &msgbuf[MSGBUFS])
@@ -176,5 +250,0 @@
-	/*
-	 *  If last char was a break or null, don't print
-	*/
-	if ((KLADDR->rbuf&0177) == 0)
-		return;
@@ -182,6 +252,2 @@
-	/*
-	 * Try waiting for the console tty to come ready,
-	 * otherwise give up after a reasonable time.
-	 */
-	while((KLADDR->tcsr&0200) == 0)
-		if(--timo == 0)
+	while ((ISR & ISR_TXE) == 0)
+		if (--timo == 0)
@@ -189 +255 @@
-	if(c == 0)
+	if (c == 0)
@@ -191,10 +257,6 @@
-	s = KLADDR->tcsr;
-	KLADDR->tcsr = 0;
-	KLADDR->tbuf = c;
-	if(c == '\n') {
-		putchar('\r');
-		putchar(0177);
-		putchar(0177);
-	}
-	putchar(0);
-	KLADDR->tcsr = s;
+	s = CR1;
+	CR1 &= ~CR1_TXEIE;
+	TDR = c;
+	if (c == '\n')
+		usputchar('\r');
+	CR1 = s;
@@ -201,0 +264 @@
+

% usr/sys/dev/sys.c
@@ -11 +11,2 @@
-syopen(dev, flag)
+int
+syopen(dev_t dev, int flag)
@@ -13,0 +15 @@
+	(void)dev;
@@ -16 +18 @@
-		return;
+		return(0);
@@ -18,0 +21 @@
+	return(0);
@@ -21 +24,2 @@
-syread(dev)
+int
+syread(dev_t dev)
@@ -23,0 +28 @@
+	(void)dev;
@@ -24,0 +30 @@
+	return(0);
@@ -27 +33,2 @@
-sywrite(dev)
+int
+sywrite(dev_t dev)
@@ -29,0 +37 @@
+	(void)dev;
@@ -30,0 +39 @@
+	return(0);
@@ -33,2 +42,2 @@
-sysioctl(dev, cmd, addr, flag)
-caddr_t addr;
+int
+sysioctl(dev_t dev, int cmd, caddr_t addr, int flag)
@@ -36,0 +46 @@
+	(void)dev;
@@ -37,0 +48 @@
+	return(0);

% usr/sys/dev/tty.c
@@ -11 +10,0 @@
-#include "../h/mx.h"
@@ -17 +16 @@
-char	partab[];
+extern char	partab[];
@@ -18,0 +18,30 @@
+int intr_enable(void);
+int intr_disable(void);
+void intr_restore(int s);
+int getc(struct clist *p);
+int putc(int c, struct clist *p);
+int b_to_q(char *cp, int cc, struct clist *q);
+void sleep(caddr_t chan, int pri);
+void wakeup(caddr_t chan);
+void signal(int pgrp, int sig);
+int copyin(caddr_t f, caddr_t t, unsigned int n);
+int copyout(caddr_t f, caddr_t t, unsigned int n);
+unsigned max(unsigned a, unsigned b);
+void ttyopen(dev_t dev, struct tty *tp);
+void ttychars(struct tty *tp);
+void ttyclose(struct tty *tp);
+void stty(void);
+void gtty(void);
+void ioctl(void);
+int ttioccomm(int com, struct tty *tp, caddr_t addr, dev_t dev);
+void wflushtty(struct tty *tp);
+void flushtty(struct tty *tp);
+int canon(struct tty *tp);
+void ttyrend(struct tty *tp, char *pb, char *pe);
+void ttyinput(int c, struct tty *tp);
+void ttyblock(struct tty *tp);
+void ttyoutput(int c, struct tty *tp);
+int ttrstrt(struct tty *tp);
+void ttstart(struct tty *tp);
+int ttread(struct tty *tp);
+caddr_t ttwrite(struct tty *tp);
@@ -61,3 +90,2 @@
-ttyopen(dev, tp)
-dev_t dev;
-register struct tty *tp;
+void
+ttyopen(dev_t dev, register struct tty *tp)
@@ -84,2 +112,2 @@
-ttychars(tp)
-register struct tty *tp;
+void
+ttychars(register struct tty *tp)
@@ -100,2 +128,2 @@
-ttyclose(tp)
-register struct tty *tp;
+void
+ttyclose(register struct tty *tp)
@@ -112 +140,2 @@
-stty()
+void
+stty(void)
@@ -119 +148,2 @@
-gtty()
+void
+gtty(void)
@@ -131 +161,2 @@
-ioctl()
+void
+ioctl(void)
@@ -141 +172 @@
-	register fmt;
+	register int fmt;
@@ -167,3 +198,2 @@
-ttioccomm(com, tp, addr, dev)
-register struct tty *tp;
-caddr_t addr;
+int
+ttioccomm(int com, register struct tty *tp, caddr_t addr, dev_t dev)
@@ -194 +224 @@
-		if (t >= nldisp) {
+		if (t >= (unsigned)nldisp) {
@@ -199 +229 @@
-			(*linesw[tp->t_line].l_close)(tp);
+			(*linesw[(int)tp->t_line].l_close)(tp);
@@ -220,0 +251 @@
+		/* fallthrough */
@@ -263 +294 @@
-		(*linesw[tp->t_line].l_ioctl)(com, tp, addr);
+		(*linesw[(int)tp->t_line].l_ioctl)(com, tp, addr);
@@ -288,2 +319,2 @@
-wflushtty(tp)
-register struct tty *tp;
+void
+wflushtty(register struct tty *tp)
@@ -292 +323 @@
-	spl5();
+	intr_disable();
@@ -299 +330 @@
-	spl0();
+	intr_enable();
@@ -305,2 +336,2 @@
-flushtty(tp)
-register struct tty *tp;
+void
+flushtty(register struct tty *tp)
@@ -308 +339 @@
-	register s;
+	register int s;
@@ -314 +345 @@
-	s = spl6();
+	s = intr_disable();
@@ -322 +353 @@
-	splx(s);
+	intr_restore(s);
@@ -333,2 +364,2 @@
-canon(tp)
-register struct tty *tp;
+int
+canon(register struct tty *tp)
@@ -341,4 +372,4 @@
-	spl5();
-	while ((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0
-	    || (tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0) {
-		if ((tp->t_state&CARR_ON)==0 || tp->t_chan!=NULL) {
+	intr_disable();
+	while (((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0)
+	    || ((tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0)) {
+		if ((tp->t_state&CARR_ON)==0) {
@@ -349 +380 @@
-	spl0();
+	intr_enable();
@@ -401,3 +432,2 @@
-ttyrend(tp, pb, pe)
-register struct tty *tp;
-register char *pb, *pe;
+void
+ttyrend(register struct tty *tp, register char *pb, register char *pe)
@@ -410,3 +440 @@
-		if (tp->t_chan)
-			sdata(tp->t_chan); else
-			wakeup((caddr_t)&tp->t_rawq);
+		wakeup((caddr_t)&tp->t_rawq);
@@ -430,3 +458,2 @@
-ttyinput(c, tp)
-register c;
-register struct tty *tp;
+void
+ttyinput(register int c, register struct tty *tp)
@@ -435 +461,0 @@
-	register struct chan *cp;
@@ -466,4 +492 @@
-			if (tp->t_chan)
-				scontrol(tp->t_chan, M_SIG, c);
-			else
-				signal(tp->t_pgrp, c);
+			signal(tp->t_pgrp, c);
@@ -485,3 +508 @@
-		if ((cp=tp->t_chan)!=NULL)
-			sdata(cp); else
-			wakeup((caddr_t)&tp->t_rawq);
+		wakeup((caddr_t)&tp->t_rawq);
@@ -501,2 +522,2 @@
-ttyblock(tp)
-register struct tty *tp;
+void
+ttyblock(register struct tty *tp)
@@ -504 +525 @@
-register x;
+register int x;
@@ -526,3 +547,2 @@
-ttyoutput(c, tp)
-register c;
-register struct tty *tp;
+void
+ttyoutput(register int c, register struct tty *tp)
@@ -531 +551 @@
-	register ctype;
+	register int ctype;
@@ -595,0 +616 @@
+		/* fallthrough */
@@ -658,2 +679,2 @@
-ttrstrt(tp)
-register struct tty *tp;
+int
+ttrstrt(register struct tty *tp)
@@ -663,0 +685 @@
+	return(0);
@@ -672,2 +694,2 @@
-ttstart(tp)
-register struct tty *tp;
+void
+ttstart(register struct tty *tp)
@@ -675 +697 @@
-	register s;
+	register int s;
@@ -677 +699 @@
-	s = spl5();
+	s = intr_disable();
@@ -680 +702 @@
-	splx(s);
+	intr_restore(s);
@@ -687,2 +709,2 @@
-ttread(tp)
-register struct tty *tp;
+int
+ttread(register struct tty *tp)
@@ -704,2 +726 @@
-ttwrite(tp)
-register struct tty *tp;
+ttwrite(register struct tty *tp)
@@ -707 +728 @@
-	register c;
+	register int c;
@@ -712 +733 @@
-		spl5();
+		intr_disable();
@@ -716,2 +736,0 @@
-			if (tp->t_chan) 
-				return((caddr_t)&tp->t_outq);
@@ -720 +739 @@
-		spl0();
+		intr_enable();

% usr/sys/dev/virtio_blk.c usr/sys/dev/rk.c
@@ -1,4 +0,0 @@
-/*
- * RK disk driver
- */
-
@@ -6 +1,0 @@
-#include "../h/systm.h"
@@ -8,18 +2,0 @@
-#include "../h/conf.h"
-#include	"../h/dir.h"
-#include "../h/user.h"
-
-#define	RKADDR	((struct device *)0177400)
-#define	NRK	4
-#define	NRKBLK	4872
-
-#define	RESET	0
-#define	WCOM	2
-#define	RCOM	4
-#define	GO	01
-#define	DRESET	014
-#define	IENABLE	0100
-#define	DRY	0200
-#define	ARDY	0100
-#define	WLO	020000
-#define	CTLRDY	0200
@@ -27,4 +3,0 @@
-/*
- * Monitoring device bit
- */
-#define	DK_N	1
@@ -32,8 +5,31 @@
-struct	device
-{
-	int	rkds;
-	int	rker;
-	int	rkcs;
-	int	rkwc;
-	caddr_t	rkba;
-	int	rkda;
+void panic(char *s);
+void dmbsy(void);
+void iodone(struct buf *bp);
+void deverror(struct buf *bp, int o1, int o2);
+int intr_disable(void);
+void intr_restore(int s);
+void physio(int (*strat)(), struct buf *bp, dev_t dev, int rw);
+
+extern int	dk_busy;
+extern long	dk_numb[3];
+extern long	dk_wds[3];
+
+int	rkirq;		/* GIC INTID of the block device (0 if none) */
+
+#define	VRING_DESC_F_NEXT	1
+#define	VRING_DESC_F_WRITE	2
+#define	VIRTIO_FIRST		0x0a000000U
+#define	VIRTIO_LAST		0x0a004000U
+#define	VIRTIO_STEP		0x00000200U
+#define	VIRTIO_IRQ_BASE		48		/* QEMU virt: SPI 16 -> INTID 48 */
+#define	VIRTIO_MAGIC		0x74726976U
+#define	VIRTIO_BLK_T_IN		0
+#define	VIRTIO_BLK_T_OUT	1
+#define	VQSIZE			8
+
+struct vqdesc {
+	unsigned int	addrlo;
+	unsigned int	addrhi;
+	unsigned int	len;
+	unsigned short	flags;
+	unsigned short	next;
@@ -42,2 +38,10 @@
-struct	buf	rktab;
-struct	buf	rrkbuf;
+struct vqavail {
+	unsigned short	flags;
+	unsigned short	idx;
+	unsigned short	ring[VQSIZE];
+};
+
+struct vqused_elem {
+	unsigned int	id;
+	unsigned int	len;
+};
@@ -45,2 +49,29 @@
-rkstrategy(bp)
-register struct buf *bp;
+struct vqused {
+	unsigned short	flags;
+	unsigned short	idx;
+	struct vqused_elem ring[VQSIZE];
+};
+
+struct virtio_blk_req {
+	unsigned int	type;
+	unsigned int	reserved;
+	unsigned long long sector;
+};
+
+struct buf rktab;
+
+static volatile unsigned char virtio_vq[512] __attribute__((aligned(4096)));
+static struct virtio_blk_req virtio_vreq __attribute__((aligned(16)));
+static volatile unsigned char virtio_vstatus __attribute__((aligned(4)));
+static unsigned int virtio_vbase;
+static unsigned int virtio_lastused;
+
+#define	QDOFF	0
+#define	QAOFF	(sizeof(struct vqdesc) * VQSIZE)
+#define	QUOFF	((QAOFF + sizeof(struct vqavail) + 3) & ~3)
+#define	qdesc	((volatile struct vqdesc *)(void *)&virtio_vq[QDOFF])
+#define	qavail	(*(volatile struct vqavail *)(void *)&virtio_vq[QAOFF])
+#define	qused	(*(volatile struct vqused *)(void *)&virtio_vq[QUOFF])
+
+static unsigned int
+vmmio(unsigned int off)
@@ -49,17 +80,8 @@
-	if(bp->b_flags&B_PHYS)
-		mapalloc(bp);
-	if (bp->b_blkno >= NRKBLK) {
-		bp->b_flags |= B_ERROR;
-		iodone(bp);
-		return;
-	}
-	bp->av_forw = (struct buf *)NULL;
-	spl5();
-	if(rktab.b_actf == NULL)
-		rktab.b_actf = bp;
-	else
-		rktab.b_actl->av_forw = bp;
-	rktab.b_actl = bp;
-	if(rktab.b_active == NULL)
-		rkstart();
-	spl0();
+	return(*(volatile unsigned int *)(virtio_vbase + off));
+}
+
+static void
+vmmios(unsigned int off, unsigned int val)
+{
+
+	*(volatile unsigned int *)(virtio_vbase + off) = val;
@@ -68 +90,42 @@
-rkstart()
+void
+rkinit(void)
+{
+	unsigned int n;
+
+	for(virtio_vbase=VIRTIO_FIRST; virtio_vbase<VIRTIO_LAST;
+	    virtio_vbase+=VIRTIO_STEP)
+		if(vmmio(0) == VIRTIO_MAGIC && vmmio(8) == 2)
+			break;
+	if(virtio_vbase == VIRTIO_LAST)
+		panic("virtio");
+	vmmios(0x70, 0);
+	vmmios(0x70, 1);
+	vmmios(0x70, 3);
+	(void)vmmio(0x10);
+	vmmios(0x20, 0);
+	vmmios(0x70, 11);
+	if((vmmio(0x70) & 8) == 0)
+		panic("virtio features");
+	vmmios(0x28, 4096);
+	vmmios(0x30, 0);
+	n = vmmio(0x34);
+	if(n < VQSIZE)
+		panic("virtio queue");
+	vmmios(0x38, VQSIZE);
+	vmmios(0x3c, 4);
+	vmmios(0x40, ((unsigned int)virtio_vq) >> 12);
+	vmmios(0x70, 15);
+	virtio_lastused = 0;
+	rkirq = VIRTIO_IRQ_BASE +
+	    (virtio_vbase - VIRTIO_FIRST) / VIRTIO_STEP;
+	rktab.b_actf = NULL;
+	rktab.b_active = 0;
+}
+
+/*
+ * Program the virtqueue for the buffer at the head of the queue and notify
+ * the device.  Returns at once; completion arrives as an interrupt.
+ * (cf. v7 rk.c rkstart.)
+ */
+static void
+virtio_start(void)
@@ -71,3 +134,2 @@
-	register com;
-	daddr_t bn;
-	int dn, cn, sn;
+	unsigned short aidx;
+	unsigned int type;
@@ -75 +137 @@
-	if ((bp = rktab.b_actf) == NULL)
+	if((bp = rktab.b_actf) == NULL)
@@ -78,16 +140,31 @@
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
-	dk_busy |= 1<<DK_N;
-	dk_numb[DK_N] += 1;
-	com = bp->b_bcount>>6;
-	dk_wds[DK_N] += com;
+	type = (bp->b_flags & B_READ) ? VIRTIO_BLK_T_IN : VIRTIO_BLK_T_OUT;
+	virtio_vreq.type = type;
+	virtio_vreq.reserved = 0;
+	virtio_vreq.sector = (unsigned long long)bp->b_blkno;
+	virtio_vstatus = 0xff;
+	qdesc[0].addrlo = (unsigned int)&virtio_vreq;
+	qdesc[0].addrhi = 0;
+	qdesc[0].len = sizeof(virtio_vreq);
+	qdesc[0].flags = VRING_DESC_F_NEXT;
+	qdesc[0].next = 1;
+	qdesc[1].addrlo = (unsigned int)bp->b_un.b_addr;
+	qdesc[1].addrhi = 0;
+	qdesc[1].len = bp->b_bcount;
+	qdesc[1].flags = VRING_DESC_F_NEXT | VRING_DESC_F_WRITE;
+	if(type == VIRTIO_BLK_T_OUT)
+		qdesc[1].flags = VRING_DESC_F_NEXT;
+	qdesc[1].next = 2;
+	qdesc[2].addrlo = (unsigned int)&virtio_vstatus;
+	qdesc[2].addrhi = 0;
+	qdesc[2].len = 1;
+	qdesc[2].flags = VRING_DESC_F_WRITE;
+	qdesc[2].next = 0;
+	aidx = qavail.idx;
+	qavail.ring[aidx % VQSIZE] = 0;
+	dmbsy();
+	qavail.idx = aidx + 1;
+	dmbsy();
+	vmmios(0x50, 0);		/* QueueNotify */
+	dk_busy |= 1;
+	dk_numb[0]++;
+	dk_wds[0] += bp->b_bcount>>6;
@@ -96 +173,30 @@
-rkintr()
+/*
+ * Block-device strategy: queue the buffer and, if the controller is idle,
+ * start it.  Returns at once; bio.c's iowait() sleeps on the buffer until
+ * the completion interrupt runs iodone().  (cf. v7 rk.c rkstrategy.)
+ */
+int
+rkstrategy(struct buf *bp)
+{
+	int s;
+
+	bp->av_forw = NULL;
+	s = intr_disable();
+	if(rktab.b_actf == NULL)
+		rktab.b_actf = bp;
+	else
+		rktab.b_actl->av_forw = bp;
+	rktab.b_actl = bp;
+	if(rktab.b_active == 0)
+		virtio_start();
+	intr_restore(s);
+	return(0);
+}
+
+/*
+ * Completion interrupt (GIC INTID rkirq).  Acknowledge the device,
+ * finish the active buffer, and start the next queued one.
+ * (cf. v7 rk.c rkintr.)
+ */
+int
+rkintr(void)
@@ -98,0 +205 @@
+	unsigned int is;
@@ -100,3 +207,9 @@
-	if (rktab.b_active == NULL)
-		return;
-	dk_busy &= ~(1<<DK_N);
+	is = vmmio(0x60);		/* InterruptStatus */
+	vmmios(0x64, is);		/* InterruptACK */
+	if(rktab.b_active == 0)
+		return(0);
+	if(qused.idx == virtio_lastused)
+		return(0);
+	dmbsy();
+	virtio_lastused++;
+	dk_busy &= ~1;
@@ -104,10 +217,3 @@
-	rktab.b_active = NULL;
-	if (RKADDR->rkcs < 0) {		/* error bit */
-		deverror(bp, RKADDR->rker, RKADDR->rkds);
-		RKADDR->rkcs = RESET|GO;
-		while((RKADDR->rkcs&CTLRDY) == 0)
-			;
-		if (++rktab.b_errcnt <= 10) {
-			rkstart();
-			return;
-		}
+	rktab.b_active = 0;
+	if(virtio_vstatus != 0) {
+		deverror(bp, virtio_vstatus, 0);
@@ -116 +221,0 @@
-	rktab.b_errcnt = 0;
@@ -120 +225,2 @@
-	rkstart();
+	virtio_start();
+	return(0);
@@ -122,0 +229,3 @@
+struct	buf	rrkbuf;
+
+int
@@ -127,0 +237 @@
+	return(0);
@@ -129,0 +240 @@
+int
@@ -134,0 +246 @@
+	return(0);

% usr/sys/h/acct.h

% usr/sys/h/buf.h

% usr/sys/h/callo.h

% usr/sys/h/conf.h
@@ -47,0 +48,9 @@
+
+/*
+ * Device interrupts: GIC interrupt number (set by the driver) and handler.
+ */
+struct intr
+{
+	int	*i_irq;
+	int	(*i_fn)();
+};

% usr/sys/h/dir.h

% usr/sys/h/fblk.h

% usr/sys/h/file.h

% usr/sys/h/filsys.h

% usr/sys/h/ino.h

% usr/sys/h/inode.h
@@ -41 +41 @@
-		};
+		} u_reg;
@@ -45 +45 @@
-		};
+		} u_dev;
@@ -46,0 +47,4 @@
+#define	i_addr	u_reg.i_addr
+#define	i_lastr	u_reg.i_lastr
+#define	i_rdev	u_dev.i_rdev
+#define	i_group	u_dev.i_group

% usr/sys/h/map.h
@@ -3,2 +3,2 @@
-	short	m_size;
-	unsigned short m_addr;
+	int		m_size;		/* Armv7: 32-bit (clicks exceed 16 bits) */
+	unsigned int	m_addr;

% usr/sys/h/mount.h

% usr/sys/h/param.h
@@ -83,2 +83,2 @@
-#define	USIZE	16		/* size of user block (*64) */
-#define	UBASE	0140000		/* abs. addr of user block */
+#define	USIZE	128		/* size of user block (*64): 8KB u-area+kstack */
+#define	UBASE	0x4F000000U	/* kernel VA window mapping the current u-area */
@@ -94 +94 @@
-#define	CBSIZE	14		/* number of chars in a clist block */
+#define	CBSIZE	12		/* number of chars in a clist block */
@@ -120 +120 @@
-#define	major(x)	(int)(((unsigned)x>>8))
+#define	major(x)	(int)(((unsigned)x>>8)&0377)
@@ -131 +131 @@
-typedef	unsigned int	ino_t;
+typedef	unsigned short	ino_t;
@@ -133 +133 @@
-typedef	int		label_t[6];	/* regs 2-7 */
+typedef	int		label_t[10];	/* regs 2-7 */
@@ -144,0 +145,14 @@
+
+/*
+ * Board memory map, set in c.c from the configuration file:
+ * kernel RAM base, user core window, user page attributes, GIC.
+ * The big tables go in .ddrbss, which the linker script places.
+ */
+extern unsigned int kernbase, corebase, coretop, pguser, gicdbase, giccbase;
+#define	KERNBASE	kernbase
+#define	COREBASE	corebase
+#define	CORETOP		coretop
+#define	PG_USER		pguser
+#define	GIC_DIST_BASE	gicdbase
+#define	GIC_CPU_BASE	giccbase
+#define	KTABLES_SECTION	".ddrbss"

% usr/sys/h/proc.h
@@ -21,2 +21,2 @@
-	short	p_addr;		/* address of swappable image */
-	short	p_size;		/* size of swappable image (clicks) */
+	int	p_addr;		/* address of swappable image (Armv7: 32-bit click index) */
+	int	p_size;		/* size of swappable image (clicks) */

% usr/sys/h/reg.h
@@ -2,2 +2 @@
- * Location of the users' stored
- * registers relative to R0.
+ * Location of the users' stored registers relative to R0.
@@ -4,0 +4,5 @@
+ *
+ * Armv7: the trap frame built by svc_entry (conf/low.s) is 17 ints --
+ * r0..r12, then sp=r[13], lr=r[14], pc=r[15], cpsr=r[16].  u.u_ar0
+ * points at r[0].  PDP-11 register numbering does not apply, so these
+ * indices are the Armv7 frame slots (required for Armv7).
@@ -7,9 +11,9 @@
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
+#define	R6	(13)		/* user stack pointer */
+#define	R7	(15)		/* user program counter */
+#define	PC	(15)
+#define	RPS	(16)		/* saved cpsr */
@@ -17 +21 @@
-#define	TBIT	020		/* PS trace bit */
+#define	TBIT	0		/* no PDP-11 trace bit on Arm */

% usr/sys/h/seg.h
@@ -2 +2 @@
- * KT-11 addresses and bits.
+ * ARM user address layout and software segment bits.
@@ -5,3 +4,0 @@
-#define	UISD	((physadr)0177600)	/* first user I-space descriptor register */
-#define	UISA	((physadr)0177640)	/* first user I-space address register */
-#define	UDSA	((physadr)0177660)	/* first user D-space address register */
@@ -15,2 +12 @@
- * structure used to address
- * a sequence of integers.
+ * User virtual memory layout.
@@ -18,2 +14,35 @@
-physadr	ka6;		/* 11/40 KISA6; 11/45 KDSA6 */
-
+#define USERBASE	0x00000000U
+#define USERSIZE	0x00100000U	/* 1 MB user virtual window (VA 0..) */
+#define UENTRY		0x00000010U
+#define USTACK		0x000f0000U
+#define UARGV		0x0000f000U
+#define UARGLEN		3072
+#define UENTRY_SIGTRAMP	0x00000008U	/* below UENTRY, never loaded */
+/*
+ * Physical core window.  The kernel maps KERNBASE..CORETOP as 1 MB
+ * sections (PA==VA), so all of physical core below CORETOP is directly
+ * addressable by the kernel.  Process images are allocated from coremap as
+ * "clicks" (64 bytes) within [COREBASE, CORETOP); click c is at CLKADDR(c).
+ * Click 0 is reserved (malloc returns 0 to mean "no core").
+ */
+#define NCLICK		((CORETOP-COREBASE)>>6)		/* clicks of user core */
+#define CLKADDR(c)	((char *)(COREBASE + ((unsigned)(c) << 6)))
+/*
+ * Section/page attributes.  Normal memory (kernel, user, DDR) is Normal
+ * Write-Back/Write-Allocate, shareable -- CACHED (TEX=001,C=1,B=1,S=1) -- so
+ * the CPU runs at full speed instead of stalling on every uncached access.
+ * Device memory (MMIO) stays strongly ordered.  mmu_on() enables the L1
+ * I/D caches.  Code the kernel writes through the D-cache (exec, icode, and
+ * the image copies of fork, expand and swap-in) is made visible to
+ * instruction fetch by arm_sync_icache(), from exec and from sureg() on
+ * every switch; DMA buffers are flushed by the block driver (dcflush) on
+ * cache-incoherent hardware.
+ */
+#define SEC_KERN	0x0001140eU	/* L1 1 MB section, kernel rw, cached */
+#define SEC_DEV		0x00000c02U	/* L1 1 MB section, device (uncached) */
+#define PTE_PT		0x00000001U	/* L1 entry -> L2 coarse table */
+#define PG_RW		0x0000047eU	/* L2 small page, PL0 read/write, cached */
+#define PG_RO		0x0000046eU	/* L2 small page, PL0 read-only, cached */
+#define PG_KRW		0x0000045eU	/* L2 small page, kernel-only rw, cached */
+#define PGSHIFT		12
+#define PGSIZE		0x1000U
@@ -21 +50,5 @@
- * address to access 11/70 UNIBUS map
+ * Physical memory map, one entry per [start,end) 1 MB-section range with its
+ * L1 attribute (SEC_KERN cached, SEC_DEV device).  The board file supplies a
+ * board_map[] terminated by a zero entry; machine_init() (machdep.c) walks it
+ * to build the section table -- identical code on every board, so QEMU
+ * exercises the same machine_init() the MP135 runs.
@@ -23 +56 @@
-#define	UBMAP	((physadr)0170200)
+struct memregion { unsigned int start, end, attr; };

% usr/sys/h/stat.h

% usr/sys/h/systm.h
@@ -41,0 +42 @@
+extern	char	*msgbufp;	/* next saved printf character */
@@ -48,16 +49,42 @@
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
+dev_t	getmdev(void);
+daddr_t	bmap(struct inode *ip, daddr_t bn, int rwflg);
+void	setrun(struct proc *p);
+int	setpri(struct proc *pp);
+int	issig(void);
+unsigned min(unsigned a, unsigned b);
+int	fubyte(caddr_t addr);
+int	subyte(caddr_t addr, char c);
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
+struct file *getf(int fdes);
+struct file *falloc(void);
+int	uchar(void);
+void	free(dev_t dev, daddr_t bno);
+void	ifree(dev_t dev, ino_t ino);
+void	update(void);
+int	passc(int c);
+int	cpass(void);
+void	closef(struct file *fp);
+int	access(struct inode *ip, int mode);
+void	iput(struct inode *ip);
+void	plock(struct inode *ip);
+void	prele(struct inode *ip);
+void	readi(struct inode *ip);
+void	writei(struct inode *ip);
+int	iupdat(struct inode *ip, time_t *ta, time_t *tm);
+int	suser(void);
+int	ufalloc(void);
+void	xrele(struct inode *ip);
+void	psignal(struct proc *p, int sig);
+void	bcopy(char *f, char *t, unsigned int n);
+int	copyin(caddr_t f, caddr_t t, unsigned int n);
+int	copyout(caddr_t f, caddr_t t, unsigned int n);
@@ -80 +107 @@
-	int	(*sy_call)();		/* handler */
+	void	(*sy_call)(void);	/* handler (Armv7/C99: void(void)) */

% usr/sys/h/text.h
@@ -9,3 +9,3 @@
-	short	x_daddr;	/* disk address of segment (relative to swplo) */
-	short	x_caddr;	/* core address, if loaded */
-	short	x_size;		/* size (clicks) */
+	int	x_daddr;	/* disk address of segment (relative to swplo) */
+	int	x_caddr;	/* core address, if loaded (Armv7: 32-bit click) */
+	int	x_size;		/* size (clicks) */

% usr/sys/h/timeb.h

% usr/sys/h/tty.h
@@ -59 +59 @@
-		struct tc;
+		struct tc tc;
@@ -64 +64 @@
-#define	tun	tp->t_un
+#define	tun	tp->t_un.tc

% usr/sys/h/user.h
@@ -38 +38 @@
-		};
+		} u_pair;
@@ -41,0 +42,2 @@
+#define	r_val1	u_pair.r_val1
+#define	r_val2	u_pair.r_val2
@@ -99 +101,5 @@
-extern struct user u;
+/*
+ * The u-area lives at the base of each process's core image.  On Armv7,
+ * resume() maps the current process there, so `u` names that window.
+ */
+#define	u	(*(struct user *)UBASE)

% usr/sys/sys/acct.c
@@ -8 +7,0 @@
-#include "../h/seg.h"
@@ -14 +13,2 @@
-sysacct()
+void
+sysacct(void)
@@ -47,0 +48 @@
+int compress(time_t t);
@@ -51 +52,2 @@
-acct()
+void
+acct(void)
@@ -53 +55 @@
-	register i;
+	register int i;
@@ -60 +62 @@
-	for (i=0; i<sizeof(acctbuf.ac_comm); i++)
+	for (i=0; i<(int)sizeof(acctbuf.ac_comm); i++)
@@ -88,2 +90,2 @@
-compress(t)
-register time_t t;
+int
+compress(time_t t)
@@ -91 +93 @@
-	register exp = 0, round = 0;
+	register int exp = 0, round = 0;
@@ -113 +115,2 @@
-syslock()
+void
+syslock(void)

% usr/sys/sys/alloc.c
@@ -11,0 +12,8 @@
+void sleep(caddr_t chan, int pri);
+void wakeup(caddr_t chan);
+void prdev(char *str, dev_t dev);
+void panic(char *s);
+void brelse(struct buf *bp);
+void bwrite(struct buf *bp);
+void bflush(dev_t dev);
+void clrbuf(struct buf *bp);
@@ -13,0 +22 @@
+int badblock(register struct filsys *fp, daddr_t bn, dev_t dev);
@@ -26,2 +35 @@
-alloc(dev)
-dev_t dev;
+alloc(dev_t dev)
@@ -78,3 +86,2 @@
-free(dev, bno)
-dev_t dev;
-daddr_t bno;
+void
+free(dev_t dev, daddr_t bno)
@@ -120,4 +127,2 @@
-badblock(fp, bn, dev)
-register struct filsys *fp;
-daddr_t bn;
-dev_t dev;
+int
+badblock(register struct filsys *fp, daddr_t bn, dev_t dev)
@@ -145,2 +150 @@
-ialloc(dev)
-dev_t dev;
+ialloc(dev_t dev)
@@ -223,3 +227,2 @@
-ifree(dev, ino)
-dev_t dev;
-ino_t ino;
+void
+ifree(dev_t dev, ino_t ino)
@@ -257,2 +260 @@
-getfs(dev)
-dev_t dev;
+getfs(dev_t dev)
@@ -286 +288,2 @@
-update()
+void
+update(void)

% usr/sys/sys/clock.c
@@ -4 +3,0 @@
-#include "../h/seg.h"
@@ -8 +7,7 @@
-#include "../h/reg.h"
+#include "../h/seg.h"
+#include "../h/conf.h"
+extern void addupc(caddr_t pc, void *prof, int inc);
+int intr_disable(void);
+void intr_restore(int s);
+void wakeup(caddr_t chan);
+void panic(char *s);
@@ -28,3 +33,2 @@
-clock(dev, sp, r1, nps, r0, pc, ps)
-dev_t dev;
-caddr_t pc;
+void
+clock(dev_t dev, int sp, int r1, int nps, int r0, caddr_t pc, int ps)
@@ -35,0 +40 @@
+	(void)dev; (void)sp; (void)r1; (void)nps; (void)r0;
@@ -41 +45,0 @@
-	lks->r[0] = 0115;
@@ -47 +50,0 @@
-	display();
@@ -71 +74 @@
-	spl5();
+	intr_disable();
@@ -79 +82 @@
-		while(p2->c_func = p1->c_func) {
+		while((p2->c_func = p1->c_func) != 0) {
@@ -114 +117 @@
-		spl1();
+		intr_disable();
@@ -154,3 +157,2 @@
-timeout(fun, arg, tim)
-int (*fun)();
-caddr_t arg;
+void
+timeout(int (*fun)(), caddr_t arg, int tim)
@@ -164 +166 @@
-	s = spl7();
+	s = intr_disable();
@@ -184 +186,72 @@
-	splx(s);
+	intr_restore(s);
+}
+#define GICD_BASE	GIC_DIST_BASE	/* board-specific (param.h) */
+#define GICC_BASE	GIC_CPU_BASE
+#define GICD_CTLR	(*(volatile unsigned int *)(GICD_BASE + 0x000))
+#define GICD_ISENABLER(n) (*(volatile unsigned int *)(GICD_BASE + 0x100 + 4*(n)))
+#define GICD_IPRIORITYR(n) (*(volatile unsigned int *)(GICD_BASE + 0x400 + 4*(n)))
+#define GICC_CTLR	(*(volatile unsigned int *)(GICC_BASE + 0x000))
+#define GICC_PMR	(*(volatile unsigned int *)(GICC_BASE + 0x004))
+#define GICC_IAR	(*(volatile unsigned int *)(GICC_BASE + 0x00c))
+#define GICC_EOIR	(*(volatile unsigned int *)(GICC_BASE + 0x010))
+#define TIMER_IRQ	27
+#define TIMER_HZ	HZ
+extern unsigned int cntfrq_get(void);
+extern void cntv_tval_set(unsigned int v), cntv_ctl_set(unsigned int v);
+extern void irq_enable(void);
+extern struct intr intrtab[];	/* configured device interrupts (c.c) */
+static unsigned int timer_reload;
+int irq_ready;
+caddr_t waitloc;	/* pc of the idle wait, for cpu-time accounting */
+void addupc(caddr_t pc, void *prof, int inc) { (void)pc; (void)prof; (void)inc; }
+/*
+ * Real-time clock interrupt: acknowledge the GIC, reprime the timer, and
+ * call the v7 clock() with the trapped pc/ps.  clock() runs with IRQs
+ * masked (we are in the IRQ handler) and never lowers priority, so it is
+ * not re-entrant; preemption happens on return to user via trap()'s tail.
+ */
+void
+clock_irq_handler(int *tf)
+{
+	unsigned int iar = GICC_IAR;
+	unsigned int intid = iar & 0x3ff;
+	if(intid == 1023) return;
+	if(intid == TIMER_IRQ) {
+		int mode = tf[16] & 0x1f;
+		int usermode = (mode == 0x10) || (mode == 0x1f);
+		cntv_tval_set(timer_reload);
+		if(u.u_procp != NULL)
+			clock(0, 0, 0, 0, 0, (caddr_t)tf[15],
+			    usermode ? 0xf000 : 0);
+	} else {
+		register struct intr *ip;
+		for(ip = intrtab; ip->i_irq; ip++)
+			if(*ip->i_irq && intid == (unsigned int)*ip->i_irq)
+				(*ip->i_fn)();
+	}
+	GICC_EOIR = iar;
+}
+static void
+gicen(int irq)
+{
+	unsigned int r = irq / 4, o = (irq % 4) * 8;
+	GICD_IPRIORITYR(r) = (GICD_IPRIORITYR(r) & ~(0xffU << o)) | (0x80U << o);
+	GICD_ISENABLER(irq / 32) = 1U << (irq % 32);
+}
+void
+clkstart(void)
+{
+	register struct intr *ip;
+	if((timer_reload = cntfrq_get() / TIMER_HZ) == 0)
+		panic("no clock");
+	gicen(TIMER_IRQ);
+	for(ip = intrtab; ip->i_irq; ip++)
+		if(*ip->i_irq)
+			gicen(*ip->i_irq);
+	GICD_CTLR = 1;
+	GICC_PMR  = 0xff;
+	GICC_CTLR = 1;
+	cntv_tval_set(timer_reload);
+	cntv_ctl_set(1);
+	irq_ready = 1;
+	irq_enable();

% usr/sys/sys/fio.c
@@ -9 +9 @@
-#include "../h/reg.h"
+#include "../h/mount.h"
@@ -10,0 +11,7 @@
+void wakeup(caddr_t chan);
+void printf(char *fmt, ...);
+void fstat(void);
+void close(void);
+void dup(void);
+void seek(void);
+void read(void);
@@ -20,2 +27 @@
-getf(f)
-register int f;
+getf(register int f)
@@ -45,2 +51,2 @@
-closef(fp)
-register struct file *fp;
+void
+closef(register struct file *fp)
@@ -102,2 +108,2 @@
-openi(ip, rw)
-register struct inode *ip;
+void
+openi(register struct inode *ip, int rw)
@@ -114 +120 @@
-		if(maj >= nchrdev)
+		if(maj >= (unsigned int)nchrdev)
@@ -121 +127 @@
-		if(maj >= nblkdev)
+		if(maj >= (unsigned int)nblkdev)
@@ -144,2 +150,2 @@
-access(ip, mode)
-register struct inode *ip;
+int
+access(register struct inode *ip, int mode)
@@ -147 +153 @@
-	register m;
+	register int m;
@@ -185 +191 @@
-owner()
+owner(void)
@@ -204 +210,2 @@
-suser()
+int
+suser(void)
@@ -218 +225,2 @@
-ufalloc()
+int
+ufalloc(void)
@@ -220 +228 @@
-	register i;
+	register int i;
@@ -242 +250 @@
-falloc()
+falloc(void)
@@ -245 +253 @@
-	register i;
+	register int i;

% usr/sys/sys/iget.c
@@ -10,0 +11,12 @@
+void sleep(caddr_t chan, int pri);
+void panic(char *s);
+void printf(char *fmt, ...);
+void brelse(struct buf *bp);
+void bdwrite(struct buf *bp);
+void iexpand(register struct inode *ip, register struct dinode *dp);
+void itrunc(register struct inode *ip);
+void tloop(dev_t dev, daddr_t bn, int f1, int f2);
+void wdir(struct inode *ip);
+void iput(register struct inode *ip);
+int iupdat(register struct inode *ip, time_t *ta, time_t *tm);
+extern dev_t rootdev;
@@ -30,3 +42 @@
-iget(dev, ino)
-dev_t dev;
-ino_t ino;
+iget(dev_t dev, ino_t ino)
@@ -92,3 +102,2 @@
-iexpand(ip, dp)
-register struct inode *ip;
-register struct dinode *dp;
+void
+iexpand(register struct inode *ip, register struct dinode *dp)
@@ -109 +117,0 @@
-		*p1++ = 0;
@@ -111,0 +120 @@
+		*p1++ = 0;
@@ -122,2 +131,2 @@
-iput(ip)
-register struct inode *ip;
+void
+iput(register struct inode *ip)
@@ -149,3 +158,2 @@
-iupdat(ip, ta, tm)
-register struct inode *ip;
-time_t *ta, *tm;
+int
+iupdat(register struct inode *ip, time_t *ta, time_t *tm)
@@ -161 +169 @@
-			return;
+			return(0);
@@ -165 +173 @@
-			return;
+			return(0);
@@ -177,0 +186,2 @@
+			*p1++ = *p2++;
+			*p1++ = *p2++;
@@ -181,2 +190,0 @@
-			*p1++ = *p2++;
-			*p1++ = *p2++;
@@ -192,0 +201 @@
+	return(0);
@@ -204,2 +213,2 @@
-itrunc(ip)
-register struct inode *ip;
+void
+itrunc(register struct inode *ip)
@@ -207 +216 @@
-	register i;
+	register int i;
@@ -242,3 +251,2 @@
-tloop(dev, bn, f1, f2)
-dev_t dev;
-daddr_t bn;
+void
+tloop(dev_t dev, daddr_t bn, int f1, int f2)
@@ -246 +254 @@
-	register i;
+	register int i;
@@ -251,0 +260 @@
+	bap = NULL;
@@ -280 +289 @@
-maknode(mode)
+maknode(int mode)
@@ -305,2 +314,2 @@
-wdir(ip)
-struct inode *ip;
+void
+wdir(struct inode *ip)

% usr/sys/sys/machdep.c
@@ -3 +2,0 @@
-#include "../h/acct.h"
@@ -6 +4,0 @@
-#include "../h/inode.h"
@@ -11 +9,12 @@
-#include "../h/buf.h"
+
+void printf(char *fmt, ...);
+void panic(char *s);
+void mmu_on(unsigned int ttb);
+void dcclean(void);
+void arm_sync_icache(void);
+void cninit(void);			/* board console early init (cn driver) */
+void bdinit(void);
+void mfree(struct map *mp, int size, int a);
+extern struct memregion board_map[];	/* per-board section map (conf/<board>.c) */
+extern void clock_ddr_init(void);	/* per-board clocks + DRAM bring-up */
+extern char __bss_start[], __bss_end[];
@@ -14,3 +23,5 @@
- * Icode is the octal bootstrap
- * program executed in user mode
- * to bring up the system.
+ * Page tables.  One global L1 (TTBR0) maps the kernel and the physical
+ * core window as 1 MB sections, plus two L2 tables:
+ *   user_l2  -- user VA 0..1MB, (re)loaded by arm_sureg() per process
+ *   uarea_l2 -- the UBASE u-area window, remapped by resume() per process
+ * Only these two follow the current process; everything else is fixed.
@@ -18,15 +29,15 @@
-int	icode[] =
-{
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
-};
-int	szicode = sizeof(icode);
+/* l1 is large (16 KB) and goes to DDR on the MP135 (KTABLES_SECTION=.ddrbss);
+ * on QEMU it stays in ordinary .bss.  The two small per-process L2 tables stay
+ * in fast SYSRAM as they are rewritten on every context switch. */
+unsigned int l1[4096] __attribute__((aligned(16384), section(KTABLES_SECTION)));
+/* The page-table walk is non-cacheable, so the two per-process L2 tables must
+ * live in the same non-cacheable region as l1 (KTABLES_SECTION = DDR on the
+ * MP135): if they were in cached SYSRAM, resume()/sureg() writes would sit in
+ * the D-cache and the walk would read stale entries, leaving the u-area/user
+ * windows pointing at the previous process's core. */
+unsigned int user_l2[256] __attribute__((aligned(1024), section(KTABLES_SECTION)));
+unsigned int uarea_l2[256] __attribute__((aligned(1024), section(KTABLES_SECTION)));
+extern char __ddrbss_start[], __ddrbss_end[];	/* zeroed in machine_init */
+char	*msgbufp = msgbuf;	/* next saved printf character */
+
+#define	UPAGES	((USIZE*64)/PGSIZE)	/* pages in the u-area window */
@@ -35 +46,6 @@
- * Machine-dependent startup code
+ * Called from _start (conf/low.s) before switching to the u-area stack.
+ * Board-independent: bring up the board's clocks + DRAM, then build the L1
+ * section table from the board's memory map (board_map[], conf/<board>.c) and
+ * the two per-process L2 windows, and enable the MMU + caches.  The same code
+ * runs on every board -- only board_map[] and clock_ddr_init() differ -- so a
+ * QEMU run exercises the identical machine_init() the MP135 uses.
@@ -37 +53 @@
-startup()
+void machine_init(void)
@@ -39 +55,2 @@
-	register i;
+	struct memregion *m;
+	unsigned int pa, i;
@@ -41,3 +58,2 @@
-	/*
-	 * zero and free all of core
-	 */
+	cninit();			/* bring up the console (UART4 from HSI) early */
+	clock_ddr_init();		/* clocks + DRAM (no-op where RAM is already up) */
@@ -45,15 +61,5 @@
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
+	/* DRAM is up now, so zero the DDR-resident table section (holds l1 and
+	 * the big system tables); low.s already zeroed the SYSRAM .bss. */
+	{
+		char *p;
+		for(p = __ddrbss_start; p < __ddrbss_end; p++) *p = 0;
@@ -61,5 +67 @@
-	printf("mem = %D\n", ctob((long)maxmem));
-	if(MAXMEM < maxmem)
-		maxmem = MAXMEM;
-	mfree(swapmap, nswap, 1);
-	swplo--;
+	for(i = 0; i < 256; i++) { user_l2[i] = 0; uarea_l2[i] = 0; }
@@ -67,3 +69,24 @@
-	/*
-	 * determine clock
-	 */
+	/* physical core + device sections, from the board's memory map */
+	for(m = board_map; m->end != 0; m++)
+		for(pa = m->start; pa < m->end; pa += 0x100000U)
+			l1[pa>>20] = (pa & 0xfff00000U) | m->attr;
+
+	/* user window (VA 0..1MB) and u-area window via L2 tables */
+	l1[0] = ((unsigned int)user_l2 & 0xfffffc00U) | PTE_PT;
+	l1[UBASE>>20] = ((unsigned int)uarea_l2 & 0xfffffc00U) | PTE_PT;
+
+	/* point the u-area window at proc[0]'s u-area (clicks 64..64+USIZE).
+	 * Map it UNCACHED (0x12), the same attribute resume() uses: the window is
+	 * remapped to a different PA on every context switch, and the same physical
+	 * u-area is also visible (uncached) through the COREBASE core window, so a
+	 * cached alias here would go incoherent the moment resume() switched it. */
+	for(i = 0; i < UPAGES; i++)
+		uarea_l2[i] = ((unsigned int)CLKADDR(64) + i*PGSIZE) | 0x12U;
+
+	/* proc[0]'s u-area lives in the user core (COREBASE), not in the zeroed
+	 * .ddrbss, so clear it here: newproc() copies it to proc[1] and the kernel
+	 * reads u_ofile[]/p_textp expecting a clean (zeroed) initial u-area. */
+	{
+		char *p, *e = (char *)CLKADDR(64 + USIZE);
+		for(p = (char *)CLKADDR(64); p < e; p++) *p = 0;
+	}
@@ -71,2 +94 @@
-	UISA->r[7] = ka6->r[1]; /* io segment */
-	UISD->r[7] = 077406;
+	mmu_on((unsigned int)l1);
@@ -76,2 +98,6 @@
- * set up a physical address
- * into users virtual address space.
+ * Load the user-region page table (user_l2) for the current process.
+ * The Armv7 user layout is flat (1 MB at VA 0; binaries link at UENTRY,
+ * stack near USTACK), so the user window maps contiguously to the image
+ * clicks just above the u-area: all of it for an exec'd program, only the
+ * first page for icode.  Pages beyond the image stay unmapped.  Called
+ * from sureg() (ureg.c).
@@ -79 +105 @@
-sysphys()
+void arm_sureg(int *uisa, int *uisd, int nseg)
@@ -81,6 +107 @@
-	register i, s, d;
-	register struct a {
-		int	segno;
-		int	size;
-		int	phys;
-	} *uap;
+	unsigned int base, i, n;
@@ -88 +109,2 @@
-	if(!suser())
+	(void)uisa; (void)uisd; (void)nseg;
+	if(u.u_procp == NULL)
@@ -90,26 +112,11 @@
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
+	base = (unsigned int)CLKADDR(u.u_procp->p_addr + USIZE);
+	n = (unsigned int)(u.u_procp->p_size - USIZE) >> (PGSHIFT-6);
+	for(i = 0; i < 256; i++)
+		user_l2[i] = i < n ? ((base + i*PGSIZE) & 0xfffff000U) | PG_USER : 0;
+	__asm__ volatile(
+	    "dsb ish\n\t"
+	    "mcr p15, 0, %0, c8, c7, 0\n\t"	/* TLBIALL */
+	    "dsb ish\n\t"
+	    "isb" :: "r"(0) : "memory");
+	arm_sync_icache();	/* fork, expand or swap-in wrote its code */
+}
@@ -117,2 +124,16 @@
-bad:
-	u.u_error = EINVAL;
+/*
+ * Copy / clear one 64-byte click of physical core.  Core is directly
+ * addressable through the PA==VA kernel window, so these are plain
+ * memory operations (the v7 m40.s copyseg/clearseg role).
+ */
+void copyseg(int from, int to)
+{
+	int *s = (int *)CLKADDR(from), *d = (int *)CLKADDR(to), i;
+	for(i = 0; i < 16; i++)
+		d[i] = s[i];
+}
+void clearseg(int a)
+{
+	int *d = (int *)CLKADDR(a), i;
+	for(i = 0; i < 16; i++)
+		d[i] = 0;
@@ -122,2 +143,3 @@
- * Determine which clock is attached, and start it.
- * panic: no clock found
+ * User-space access primitives (the v7 fubyte/subyte/... role).  User VAs
+ * live in [0, USERSIZE); a bounds check keeps a bad user pointer from
+ * faulting the kernel (Armv7 has no fault-recovery path here).
@@ -125,3 +147 @@
-#define	CLOCK1	((physadr)0177546)
-#define	CLOCK2	((physadr)0172540)
-clkstart()
+static int user_range(caddr_t a, unsigned int n)
@@ -129,7 +149,44 @@
-	lks = CLOCK1;
-	if(fuiword((caddr_t)lks) == -1) {
-		lks = CLOCK2;
-		if(fuiword((caddr_t)lks) == -1)
-			panic("no clock");
-	}
-	lks->r[0] = 0115;
+	unsigned int x = (unsigned int)a;
+	return x < USERSIZE && n <= USERSIZE - x;
+}
+int fubyte(caddr_t addr)
+{
+	if(!user_range(addr, 1))
+		return(-1);
+	return *(unsigned char *)addr;
+}
+int subyte(caddr_t addr, char c)
+{
+	if(!user_range(addr, 1))
+		return(-1);
+	*(unsigned char *)addr = c;
+	return(0);
+}
+int fuword(caddr_t addr)
+{
+	if(!user_range(addr, sizeof(int)))
+		return(-1);
+	return *(int *)addr;
+}
+int suword(caddr_t addr, int v)
+{
+	if(!user_range(addr, sizeof(int)))
+		return(-1);
+	*(int *)addr = v;
+	return(0);
+}
+int copyin(caddr_t f, caddr_t t, unsigned int n)
+{
+	if(!user_range(f, n))
+		return(-1);
+	while(n--)
+		*t++ = *f++;
+	return(0);
+}
+int copyout(caddr_t f, caddr_t t, unsigned int n)
+{
+	if(!user_range(t, n))
+		return(-1);
+	while(n--)
+		*t++ = *f++;
+	return(0);
@@ -139 +196,4 @@
- * Let a process handle a signal by simulating an interrupt
+ * Let a process handle a signal by simulating an interrupt:
+ * push the whole trap frame on the user stack (8-byte aligned,
+ * as the ABI wants), and enter the handler with the signal
+ * number in r0 and lr pointing at the sigreturn trampoline.
@@ -141,2 +201,2 @@
-sendsig(p, signo)
-caddr_t p;
+void
+sendsig(caddr_t p, int signo)
@@ -146,4 +206,6 @@
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
@@ -151 +213 @@
-	u.u_ar0[RPS] &= ~TBIT;
+	u.u_ar0[14] = UENTRY_SIGTRAMP;	/* lr */
@@ -152,0 +215 @@
+	u.u_ar0[R0] = signo;
@@ -156,6 +219,3 @@
- * 11/70 routine to allocate the
- * UNIBUS map and initialize for
- * a unibus device.
- * The code here and in
- * rhstart assumes that an rh on an 11/70
- * is an rh70 and contains 22 bit addressing.
+ * The sigreturn call made by the trampoline: reload the frame
+ * sendsig pushed.  Only the condition flags of the saved cpsr
+ * are taken; trap() returns r0 and r1 from u_r.
@@ -163,4 +223,2 @@
-int	maplock;
-
-mapalloc(bp)
-register struct buf *bp;
+void
+sigreturn(void)
@@ -168 +226,2 @@
-	register i, a;
+	int f[RPS+1];
+	register int i;
@@ -170 +229,3 @@
-	if(cputype != 70)
+	if(copyin((caddr_t)u.u_ar0[R6], (caddr_t)f, sizeof(f)) < 0) {
+		u.u_signal[SIGSEG] = 0;
+		psignal(u.u_procp, SIGSEG);
@@ -172,4 +232,0 @@
-	spl6();
-	while(maplock&B_BUSY) {
-		maplock |= B_WANTED;
-		sleep((caddr_t)&maplock, PSWP+1);
@@ -177,19 +234,162 @@
-	maplock |= B_BUSY;
-	spl0();
-	bp->b_flags |= B_MAP;
-	a = bp->b_xmem;
-	for(i=16; i<32; i+=2)
-		UBMAP->r[i+1] = a;
-	for(a++; i<48; i+=2)
-		UBMAP->r[i+1] = a;
-	bp->b_xmem = 1;
-}
-
-mapfree(bp)
-struct buf *bp;
-{
-
-	bp->b_flags &= ~B_MAP;
-	if(maplock&B_WANTED)
-		wakeup((caddr_t)&maplock);
-	maplock = 0;
+	for(i = 0; i < RPS; i++)
+		u.u_ar0[i] = f[i];
+	u.u_ar0[RPS] = (u.u_ar0[RPS] & ~0xf80f0000) | (f[RPS] & 0xf80f0000);
+	u.u_r.r_val1 = f[R0];
+	u.u_r.r_val2 = f[R1];
+}
+
+/* Idle: allow interrupts, wait, then re-mask (the v7 idle() in swtch). */
+void idle(void)
+{
+	__asm__ volatile("cpsie i\n\twfi\n\tcpsid i" ::: "memory");
+}
+
+/* No VFP context is carried for user programs (soft-float ABI). */
+void savfp(void *p)
+{
+	(void)p;
+}
+void restfp(void *p)
+{
+	(void)p;
+}
+
+/*
+ * /dev/mem,/dev/kmem core access.  ps(1) and friends address two kinds of
+ * thing through /dev/mem: kernel symbols resolved from the namelist (true
+ * kernel virtual addresses, KERNBASE and up) and per-process u-areas as a
+ * bare click offset `p_addr<<6` (V7 assumed core began at physical 0).
+ * The kernel image and physical core window are identity-mapped, so a VA
+ * at or above KERNBASE is used directly; a smaller value is a core-relative
+ * click offset and is biased by COREBASE to reach the real backing page.
+ */
+#define KMSGBASE	0x7fff0000U
+
+static char *
+memaddr(unsigned int off)
+{
+	static unsigned int msgidx;
+
+	if(off >= KMSGBASE && off < KMSGBASE + sizeof(msgidx) + MSGBUFS) {
+		off -= KMSGBASE;
+		msgidx = (unsigned int)(msgbufp - msgbuf);
+		if(off < sizeof(msgidx))
+			return((char *)&msgidx + off);
+		return(&msgbuf[off - sizeof(msgidx)]);
+	}
+	if(off < KERNBASE)
+		off += COREBASE;
+	if((off >= KERNBASE && off < (unsigned int)__bss_end) ||
+	   (off >= (unsigned int)__ddrbss_start && off < (unsigned int)__ddrbss_end) ||
+	   (off >= COREBASE && off < CORETOP))
+		return((char *)off);
+	return(NULL);
+}
+
+/* The v7 fuibyte/suibyte role for /dev/mem: -1 for a bad offset. */
+int fumem(unsigned int off)
+{
+	char *a = memaddr(off);
+
+	return(a == NULL ? -1 : *a & 0377);
+}
+int sumem(unsigned int off, int c)
+{
+	char *a = memaddr(off);
+
+	if(a == NULL)
+		return(-1);
+	*a = c;
+	return(0);
+}
+
+/* No UNIBUS/buffer map on Armv7. */
+struct buf;
+void mapfree(struct buf *bp)
+{
+	(void)bp;
+}
+
+/*
+ * Icode is the bootstrap program executed in user mode to bring up the
+ * system; it execs /etc/init.  Position-independent Armv7, runs at VA 0.
+ */
+int	icode[] =
+{
+	0xe3a00024,	/* mov r0, #init */
+	0xe3a01040,	/* mov r1, #initp */
+	0xe3a02000,	/* mov r2, #0 */
+	0xe3a0700b,	/* mov r7, #exec */
+	0xef000000,	/* svc #0 */
+	0xe3a00001,	/* mov r0, #1 */
+	0xe3a07001,	/* mov r7, #exit */
+	0xef000000,	/* svc #0 */
+	0xeafffffe,	/* b . */
+	0x6374652f,	/* init: </etc/init\0> */
+	0x696e692f,
+	0x00000074,
+	0x00000000,
+	0x00000000,
+	0x00000000,
+	0x00000000,
+	0x00000024,	/* initp: init; 0 */
+	0x00000000,
+};
+int	szicode = sizeof(icode);
+
+/*
+ * Put the signal trampoline (UENTRY_SIGTRAMP, below the
+ * program) in a newly exec'd image.  sendsig points the
+ * handler's lr at it; it makes the sigreturn call.
+ */
+void
+install_sigtramp(void)
+{
+	suword((caddr_t)UENTRY_SIGTRAMP, (int)0xe3a0703fU);	/* mov r7, #63 */
+	suword((caddr_t)UENTRY_SIGTRAMP+4, (int)0xef000000U);	/* svc #0 */
+}
+
+void
+arm_sync_icache(void)
+{
+	unsigned int zero = 0;
+
+	dcclean();
+	__asm__ volatile(
+	    "dsb ish\n\t"
+	    "mcr p15, 0, %0, c7, c5, 0\n\t"	/* ICIALLU */
+	    "mcr p15, 0, %0, c7, c5, 6\n\t"	/* BPIALL */
+	    "dsb ish\n\t"
+	    "isb"
+	    :
+	    : "r"(zero)
+	    : "memory");
+}
+
+void
+panictrap(void)
+{
+	panic("trap");
+}
+
+/*
+ * Machine-dependent startup, called from main() (on the u-area stack,
+ * MMU already enabled by machine_init).  Free all user core to the
+ * coremap and report it.  proc[0]'s u-area occupies clicks 64..64+USIZE;
+ * click 0 is reserved.
+ */
+void startup(void)
+{
+	register int n;
+
+	n = (int)(NCLICK - (64 + USIZE));
+	mfree(coremap, n, 64 + USIZE);
+	mfree(swapmap, nswap, 1);
+	swplo--;
+	printf("mem = %D\n", ctob((long)n));
+	/*
+	 * A process image is bounded by the 1 MB user MMU window, not by
+	 * total core, so maxmem is the window size (estabur enforces it).
+	 */
+	maxmem = (int)(USERSIZE >> 6) + USIZE;
+	bdinit();

% usr/sys/sys/main.c
@@ -13,0 +14,13 @@
+void startup(void);
+void brelse(struct buf *bp);
+void binit(void);
+void iinit(void);
+void panic(char *s);
+void printf(char *fmt, ...);
+void clkstart(void);
+void cinit(void);
+int newproc(void);
+void expand(int newsize);
+int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
+void sched(void);
+void arm_sync_icache(void);
@@ -30 +43,2 @@
-main()
+void
+main(void)
@@ -38 +52 @@
-	proc[0].p_addr = ka6->r[0];
+	proc[0].p_addr = 64;
@@ -68,2 +82,5 @@
-		expand(USIZE + (int)btoc(szicode));
-		estabur((unsigned)0, btoc(szicode), (unsigned)0, 0, RO);
+		int dclicks = ((int)btoc(szicode) + 63) & ~63;
+		expand(USIZE + dclicks);
+		u.u_dsize = dclicks;
+		u.u_ssize = 0;
+		estabur((unsigned)0, (unsigned)dclicks, (unsigned)0, 0, RO);
@@ -70,0 +88 @@
+		arm_sync_icache();
@@ -90 +108,2 @@
-iinit()
+void
+iinit(void)
@@ -119 +138,5 @@
-char	buffers[NBUF][BSIZE+BSLOP];
+/* Each buffer must be word-aligned: the STM32 SDMMC internal DMA requires a
+ * 32-bit-aligned IDMABASER, so the per-buffer stride is rounded up to a
+ * multiple of 4 (BSIZE+BSLOP=514 would leave odd buffers 2-byte aligned and
+ * the DMA would corrupt those transfers). */
+char	buffers[NBUF][(BSIZE+BSLOP+3)&~3] __attribute__((aligned(4), section(KTABLES_SECTION)));
@@ -125 +148 @@
-binit()
+void binit(void)

% usr/sys/sys/malloc.c
@@ -3,0 +4 @@
+void wakeup(caddr_t chan);
@@ -15,2 +16,2 @@
-malloc(mp, size)
-struct map *mp;
+int
+malloc(struct map *mp, int size)
@@ -29 +30 @@
-				} while ((bp-1)->m_size = bp->m_size);
+				} while (((bp-1)->m_size = bp->m_size));
@@ -43,3 +44,2 @@
-mfree(mp, size, a)
-struct map *mp;
-register int a;
+void
+mfree(struct map *mp, int size, int a)
@@ -52 +52 @@
-		wakeup((caddr_t)&runin);	/* Wake scheduler when freeing core */
+		wakeup((caddr_t)&runin);
@@ -54,2 +54,2 @@
-	for (; bp->m_addr<=a && bp->m_size!=0; bp++);
-	if (bp>mp && (bp-1)->m_addr+(bp-1)->m_size == a) {
+	for (; bp->m_addr<=(unsigned)a && bp->m_size!=0; bp++);
+	if (bp>mp && (bp-1)->m_addr+(bp-1)->m_size == (unsigned)a) {
@@ -57 +57 @@
-		if (a+size == bp->m_addr) {
+		if ((unsigned)(a+size) == bp->m_addr) {
@@ -66 +66 @@
-		if (a+size == bp->m_addr && bp->m_size) {
+		if ((unsigned)(a+size) == bp->m_addr && bp->m_size) {
@@ -77 +77 @@
-			} while (size = t);
+			} while ((size = t));

% usr/sys/sys/nami.c
@@ -7,0 +8 @@
+void brelse(struct buf *bp);
@@ -21,2 +22 @@
-namei(func, flag)
-int (*func)();
+namei(int (*func)(void), int flag)
@@ -25 +25 @@
-	register c;
+	register int c;
@@ -206 +206,2 @@
-schar()
+int
+schar(void)
@@ -216 +217,2 @@
-uchar()
+int
+uchar(void)
@@ -218 +220 @@
-	register c;
+	register int c;

% usr/sys/sys/pipe.c
@@ -7 +7,2 @@
-#include "../h/reg.h"
+void sleep(caddr_t chan, int pri);
+void wakeup(caddr_t chan);
@@ -25 +26,2 @@
-pipe()
+void
+pipe(void)
@@ -61,2 +63,2 @@
-readp(fp)
-register struct file *fp;
+void
+readp(register struct file *fp)
@@ -116,2 +118,2 @@
-writep(fp)
-register struct file *fp;
+void
+writep(register struct file *fp)
@@ -119 +121 @@
-	register c;
+	register int c;
@@ -189,2 +191,2 @@
-plock(ip)
-register struct inode *ip;
+void
+plock(register struct inode *ip)
@@ -207,2 +209,2 @@
-prele(ip)
-register struct inode *ip;
+void
+prele(register struct inode *ip)

% usr/sys/sys/prf.c
@@ -2,2 +1,0 @@
-#include "../h/systm.h"
-#include "../h/seg.h"
@@ -5 +3,2 @@
-#include "../h/conf.h"
+#include <stdarg.h>
+void putchar(char c);
@@ -14,0 +14 @@
+void printn(long n, int b);
@@ -26,3 +26,2 @@
-printf(fmt, x1)
-register char *fmt;
-unsigned x1;
+void
+printf(char *fmt, ...)
@@ -30,2 +29,2 @@
-	register c;
-	register unsigned int *adx;
+	register int c;
+	va_list adx;
@@ -34 +33 @@
-	adx = &x1;
+	va_start(adx, fmt);
@@ -37 +36,2 @@
-		if(c == '\0')
+		if(c == '\0') {
+			va_end(adx);
@@ -38,0 +39 @@
+		}
@@ -43 +44 @@
-		printn((long)*adx, c=='o'? 8: (c=='x'? 16:10));
+		printn((long)va_arg(adx, unsigned), c=='o'? 8: (c=='x'? 16:10));
@@ -45,2 +46,2 @@
-		s = (char *)*adx;
-		while(c = *s++)
+		s = va_arg(adx, char *);
+		while((c = *s++))
@@ -49,2 +50 @@
-		printn(*(long *)adx, 10);
-		adx += (sizeof(long) / sizeof(int)) - 1;
+		printn(va_arg(adx, long), 10);
@@ -52 +51,0 @@
-	adx++;
@@ -59,2 +58,2 @@
-printn(n, b)
-long n;
+void
+printn(long n, int b)
@@ -68 +67 @@
-	if(a = n/b)
+	if((a = n/b))
@@ -79,2 +78,2 @@
-panic(s)
-char *s;
+void
+panic(char *s)
@@ -83 +81,0 @@
-	update();
@@ -86 +84 @@
-		idle();
+		;
@@ -95,3 +93,2 @@
-prdev(str, dev)
-char *str;
-dev_t dev;
+void
+prdev(char *str, dev_t dev)
@@ -110,2 +107,2 @@
-deverror(bp, o1, o2)
-register struct buf *bp;
+void
+deverror(register struct buf *bp, int o1, int o2)

% usr/sys/sys/prim.c
@@ -5,0 +6,2 @@
+int intr_disable(void);
+void intr_restore(int s);
@@ -19,2 +21,2 @@
-getc(p)
-register struct clist *p;
+int
+getc(register struct clist *p)
@@ -25 +27 @@
-	s = spl6();
+	s = intr_disable();
@@ -47 +49 @@
-	splx(s);
+	intr_restore(s);
@@ -55,3 +57,2 @@
-q_to_b(q, cp, cc)
-register struct clist *q;
-register char *cp;
+int
+q_to_b(register struct clist *q, register char *cp, int cc)
@@ -65 +66 @@
-	s = spl6();
+	s = intr_disable();
@@ -92 +93 @@
-	splx(s);
+	intr_restore(s);
@@ -102,2 +103,2 @@
-ndqb(q, flag)
-register struct clist *q;
+int
+ndqb(register struct clist *q, int flag)
@@ -105 +106 @@
-register cc;
+register int cc;
@@ -108 +109 @@
-	s = spl6();
+	s = intr_disable();
@@ -133 +134 @@
-	splx(s);
+	intr_restore(s);
@@ -143,3 +144,2 @@
-ndflush(q, cc)
-register struct clist *q;
-register cc;
+void
+ndflush(register struct clist *q, register int cc)
@@ -147 +147 @@
-register s;
+register int s;
@@ -149 +149 @@
-	s = spl6();
+	s = intr_disable();
@@ -189 +189 @@
-	splx(s);
+	intr_restore(s);
@@ -191,2 +191,2 @@
-putc(c, p)
-register struct clist *p;
+int
+putc(int c, register struct clist *p)
@@ -196 +196 @@
-	register s;
+	register int s;
@@ -198 +198 @@
-	s = spl6();
+	s = intr_disable();
@@ -201 +201 @@
-			splx(s);
+			intr_restore(s);
@@ -210 +210 @@
-			splx(s);
+			intr_restore(s);
@@ -221 +221 @@
-	splx(s);
+	intr_restore(s);
@@ -231,4 +231,2 @@
-b_to_q(cp, cc, q)
-register char *cp;
-struct clist *q;
-register int cc;
+int
+b_to_q(register char *cp, register int cc, struct clist *q)
@@ -238 +236 @@
-	register s, acc;
+	register int s, acc;
@@ -245 +243 @@
-	s = spl6();
+	s = intr_disable();
@@ -270 +268 @@
-	splx(s);
+	intr_restore(s);
@@ -278 +276,2 @@
-cinit()
+void
+cinit(void)
@@ -301,2 +300,2 @@
-getw(p)
-register struct clist *p;
+int
+getw(register struct clist *p)
@@ -312,2 +311,2 @@
-putw(c, p)
-register struct clist *p;
+int
+putw(int c, register struct clist *p)
@@ -315 +314 @@
-	register s;
+	register int s;
@@ -317 +316 @@
-	s = spl6();
+	s = intr_disable();
@@ -319 +318 @@
-		splx(s);
+		intr_restore(s);
@@ -324 +323 @@
-	splx(s);
+	intr_restore(s);

% usr/sys/sys/rdwri.c
@@ -7,0 +8,5 @@
+void clrbuf(struct buf *bp);
+void brelse(struct buf *bp);
+void bdwrite(struct buf *bp);
+void bwrite(struct buf *bp);
+extern void iomove(register caddr_t cp, register int n, int flag);
@@ -19,2 +24,2 @@
-readi(ip)
-register struct inode *ip;
+void
+readi(register struct inode *ip)
@@ -26,2 +31,2 @@
-	register on, n;
-	register type;
+	register int on, n;
+	register int type;
@@ -39 +44,2 @@
-		return((*cdevsw[major(dev)].d_read)(dev));
+		(*cdevsw[major(dev)].d_read)(dev);
+		return;
@@ -83,2 +89,2 @@
-writei(ip)
-register struct inode *ip;
+void
+writei(register struct inode *ip)
@@ -89,2 +95,2 @@
-	register n, on;
-	register type;
+	register int n, on;
+	register int type;
@@ -136,2 +142,2 @@
-max(a, b)
-unsigned a, b;
+unsigned
+max(unsigned a, unsigned b)
@@ -149,2 +155,2 @@
-min(a, b)
-unsigned a, b;
+unsigned
+min(unsigned a, unsigned b)
@@ -173,3 +179,2 @@
-iomove(cp, n, flag)
-register caddr_t cp;
-register n;
+void
+iomove(register caddr_t cp, register int n, int flag)
@@ -177 +182 @@
-	register t;
+	register int t;
@@ -186,4 +191 @@
-			if (u.u_segflg==0)
-				t = copyin(u.u_base, (caddr_t)cp, n);
-			else
-				t = copyiin(u.u_base, (caddr_t)cp, n);
+			t = copyin(u.u_base, (caddr_t)cp, n);
@@ -191,4 +193 @@
-			if (u.u_segflg==0)
-				t = copyout((caddr_t)cp, u.u_base, n);
-			else
-				t = copyiout((caddr_t)cp, u.u_base, n);
+			t = copyout((caddr_t)cp, u.u_base, n);

% usr/sys/sys/sig.c
@@ -9,0 +10,27 @@
+void sleep(caddr_t chan, int pri);
+void wakeup(caddr_t chan);
+void setrun(struct proc *p);
+int fsig(struct proc *p);
+void psignal(struct proc *p, int sig);
+int issig(void);
+int procxmt(void);
+int core(void);
+void swtch(void);
+void exit(int rv);
+void itrunc(struct inode *ip);
+void expand(int newsize);
+void copyseg(int from, int to);
+void clearseg(int a);
+int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
+int fubyte(caddr_t addr);
+int fuword(caddr_t addr);
+int suword(caddr_t addr, int v);
+struct inode *namei(int (*func)(void), int flag);
+struct inode *maknode(int mode);
+int access(struct inode *ip, int mode);
+void writei(struct inode *ip);
+void iput(struct inode *ip);
+int save(int *lp);
+void bcopy(char *from, char *to, unsigned int n);
+void sendsig(caddr_t p, int signo);
+#define	SINCR	20
@@ -39,2 +66,2 @@
-signal(pgrp, sig)
-register pgrp;
+void
+signal(register int pgrp, int sig)
@@ -55,3 +82,2 @@
-psignal(p, sig)
-register struct proc *p;
-register sig;
+void
+psignal(register struct proc *p, register int sig)
@@ -81 +107,2 @@
-issig()
+int
+issig(void)
@@ -83 +110 @@
-	register n;
+	register int n;
@@ -102 +129,2 @@
-stop()
+void
+stop(void)
@@ -120 +147,0 @@
-
@@ -128 +155,2 @@
-psig()
+void
+psig(void)
@@ -130 +158 @@
-	register n, p;
+	register int n, p;
@@ -134,4 +161,0 @@
-	if (u.u_fpsaved==0) {
-		savfp(&u.u_fps);
-		u.u_fpsaved = 1;
-	}
@@ -172,2 +196,2 @@
-fsig(p)
-struct proc *p;
+int
+fsig(struct proc *p)
@@ -175 +199 @@
-	register n, i;
+	register int n, i;
@@ -196 +220,2 @@
-core()
+int
+core(void)
@@ -200 +225 @@
-	extern schar();
+	extern int schar(void);
@@ -237,2 +262,2 @@
-grow(sp)
-unsigned sp;
+int
+grow(unsigned sp)
@@ -240 +265 @@
-	register si, i;
+	register int si, i;
@@ -242 +267 @@
-	register a;
+	register int a;
@@ -267 +292,2 @@
-ptrace()
+void
+ptrace(void)
@@ -313 +339,2 @@
-procxmt()
+int
+procxmt(void)
@@ -316 +343 @@
-	register *p;
+	register int *p;
@@ -328 +355 @@
-		if (fuibyte((caddr_t)ipc.ip_addr) == -1)
+		if (fubyte((caddr_t)ipc.ip_addr) == -1)
@@ -330 +357 @@
-		ipc.ip_data = fuiword((caddr_t)ipc.ip_addr);
+		ipc.ip_data = fuword((caddr_t)ipc.ip_addr);
@@ -345 +372 @@
-		ipc.ip_data = ((physadr)&u)->r[i>>1];
+		ipc.ip_data = *(int *)((char *)&u + i);
@@ -354,2 +381,3 @@
-		if (xp = u.u_procp->p_textp) {
-			if (xp->x_count!=1 || xp->x_iptr->i_mode&ISVTX)
+		xp = u.u_procp->p_textp;
+		if (xp != NULL) {
+			if (xp->x_count!=1 || (xp->x_iptr->i_mode&ISVTX))
@@ -360,2 +388,2 @@
-		i = suiword((caddr_t)ipc.ip_addr, 0);
-		suiword((caddr_t)ipc.ip_addr, ipc.ip_data);
+		i = suword((caddr_t)ipc.ip_addr, 0);
+		suword((caddr_t)ipc.ip_addr, ipc.ip_data);
@@ -379 +407,3 @@
-		p = (int *)&((physadr)&u)->r[i>>1];
+		if (i<0 || i+(int)sizeof(int) > ctob(USIZE))
+			goto error;
+		p = (int *)((char *)&u + i);
@@ -382,8 +411,0 @@
-		for (i=0; i<8; i++)
-			if (p == &u.u_ar0[regloc[i]])
-				goto ok;
-		if (p == &u.u_ar0[RPS]) {
-			ipc.ip_data |= 0170000;	/* assure user space */
-			ipc.ip_data &= ~0340;	/* priority 0 */
-			goto ok;
-		}
@@ -399 +420,0 @@
-		u.u_ar0[RPS] |= TBIT;
@@ -401,2 +422,5 @@
-		if ((int)ipc.ip_addr != 1)
-			u.u_ar0[PC] = (int)ipc.ip_addr;
+		if ((int)ipc.ip_addr != 1) {
+			p = u.u_ar0;
+			if (p != NULL)
+				p[PC] = (int)ipc.ip_addr;
+		}
@@ -410,0 +435 @@
+		return(1);

% usr/sys/sys/slp.c
@@ -10,0 +11,31 @@
+#include "../h/seg.h"
+#include "../h/reg.h"
+void sleep(caddr_t chan, int pri);
+void wakeup(caddr_t chan);
+void setrq(struct proc *p);
+void setrun(struct proc *p);
+int setpri(struct proc *pp);
+void sched(void);
+int swapin(struct proc *p);
+void qswtch(void);
+void swtch(void);
+int newproc(void);
+void expand(int newsize);
+int issig(void);
+int intr_enable(void);
+int intr_disable(void);
+void intr_restore(int s);
+void panic(char *s);
+void printf(char *fmt, ...);
+int save(int *lp) __attribute__((returns_twice));
+void resume(int addr, int *lp);
+void sureg(void);
+void savfp(void *p);
+void idle(void);
+int malloc(struct map *mp, int size);
+void mfree(struct map *mp, int size, int a);
+void xswap(struct proc *p, int ff, int os);
+void xlock(struct text *xp);
+void xunlock(struct text *xp);
+void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
+void copyseg(int from, int to);
@@ -13,0 +45 @@
+#define ARM_FORK_STACK_COPY 1024	/* fallback high-stack band */
@@ -27,2 +59,2 @@
-sleep(chan, pri)
-caddr_t chan;
+void
+sleep(caddr_t chan, int pri)
@@ -31 +63 @@
-	register s, h;
+	register int s, h;
@@ -34 +66 @@
-	s = spl6();
+	s = intr_disable();
@@ -50 +82 @@
-			spl0();
+			intr_enable();
@@ -53 +85 @@
-		spl0();
+		intr_enable();
@@ -62 +94 @@
-		spl0();
+		intr_enable();
@@ -65 +97 @@
-	splx(s);
+	intr_restore(s);
@@ -82,2 +114,2 @@
-wakeup(chan)
-register caddr_t chan;
+void
+wakeup(caddr_t chan)
@@ -86 +118 @@
-	register i;
+	register int i;
@@ -89 +121 @@
-	s = spl6();
+	s = intr_disable();
@@ -109 +141 @@
-	splx(s);
+	intr_restore(s);
@@ -118,2 +150,2 @@
-setrq(p)
-struct proc *p;
+void
+setrq(struct proc *p)
@@ -122 +154 @@
-	register s;
+	register int s;
@@ -124 +156 @@
-	s = spl6();
+	s = intr_disable();
@@ -133 +165 @@
-	splx(s);
+	intr_restore(s);
@@ -140,2 +172,2 @@
-setrun(p)
-register struct proc *p;
+void
+setrun(struct proc *p)
@@ -151 +183 @@
-	if (w = p->p_wchan) {
+	if ((w = p->p_wchan) != 0) {
@@ -171,2 +203,2 @@
-setpri(pp)
-register struct proc *pp;
+int
+setpri(struct proc *pp)
@@ -174 +206 @@
-	register p;
+	register int p;
@@ -202 +234,2 @@
-sched()
+void
+sched(void)
@@ -205 +238 @@
-	register outage, inage;
+	register int outage, inage;
@@ -214 +247 @@
-	spl6();
+	intr_disable();
@@ -215,0 +249 @@
+	p = NULL;
@@ -230 +264 @@
-	spl0();
+	intr_enable();
@@ -247 +281 @@
-	spl6();
+	intr_disable();
@@ -257 +291 @@
-		if (rp->p_stat==SSLEEP&&rp->p_pri>=PZERO || rp->p_stat==SSTOP) {
+		if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) || rp->p_stat==SSTOP) {
@@ -269 +303 @@
-	spl0();
+	intr_enable();
@@ -281 +315 @@
-	spl6();
+	intr_disable();
@@ -292,2 +326,2 @@
-swapin(p)
-register struct proc *p;
+int
+swapin(struct proc *p)
@@ -301 +335 @@
-	if (xp = p->p_textp) {
+	if ((xp = p->p_textp) != 0) {
@@ -329 +363,2 @@
-qswtch()
+void
+qswtch(void)
@@ -347 +382,2 @@
-swtch()
+void
+swtch(void)
@@ -349 +385 @@
-	register n;
+	register int n;
@@ -380 +416 @@
-	spl6();
+	intr_disable();
@@ -383,0 +420 @@
+	pq = NULL;
@@ -412 +449 @@
-	spl0();
+	intr_enable();
@@ -426 +463,2 @@
-newproc()
+int
+newproc(void)
@@ -429,3 +467,3 @@
-	struct proc *p, *up;
-	register struct proc *rpp, *rip;
-	register n;
+	struct proc *volatile p, *up;
+	struct proc *rpp, *rip;
+	int n;
@@ -447 +485 @@
-		if(rpp->p_stat == NULL && p==NULL)
+		if(rpp->p_stat == 0 && p==NULL)
@@ -520 +558 @@
-		 * There is core, so just copy.
+		 * Copy the u-area, live low image, and high stack.
@@ -521,0 +560 @@
+		register int low, stack;
@@ -523,2 +562,22 @@
-		while(n--)
-			copyseg(a1++, a2++);
+		low = (int)u.u_dsize;
+		stack = (int)u.u_ssize;
+		if(stack < ARM_FORK_STACK_COPY)
+			stack = ARM_FORK_STACK_COPY;
+		stack = USIZE + (int)(USERSIZE >> 6) - stack;
+		if(u.u_ar0 != NULL) {
+			unsigned usp;
+			int spclick;
+			usp = (unsigned)u.u_ar0[R6];
+			spclick = USIZE + (int)(usp >> 6);
+			if(usp < USERSIZE && spclick < stack)
+				stack = spclick;
+		}
+		if(low <= 0 || low > stack - USIZE) {
+			while(n--)
+				copyseg(a1++, a2++);
+		} else {
+			for(n = 0; n < USIZE + low; n++)
+				copyseg(a1 + n, a2 + n);
+			for(n = stack; n < rpp->p_size; n++)
+				copyseg(a1 + n, a2 + n);
+		}
@@ -545 +604,2 @@
-expand(newsize)
+void
+expand(int newsize)
@@ -547 +607 @@
-	register i, n;
+	register int i, n;
@@ -549 +609 @@
-	register a1, a2;
+	register int a1, a2;
@@ -550,0 +611,7 @@
+	/*
+	 * Armv7: a process image must start on a page boundary because the
+	 * u-area is mapped as whole pages (UBASE window).  Round the image
+	 * size up to a multiple of 64 clicks (one 4 KB page) so that coremap
+	 * allocations stay page-aligned.
+	 */
+	newsize = (newsize + 63) & ~63;

% usr/sys/sys/subr.c
@@ -3 +2,0 @@
-#include "../h/conf.h"
@@ -7,0 +7,2 @@
+void bdwrite(struct buf *bp);
+void brelse(struct buf *bp);
@@ -18,3 +19 @@
-bmap(ip, bn, rwflg)
-register struct inode *ip;
-daddr_t bn;
+bmap(register struct inode *ip, daddr_t bn, int rwflg)
@@ -22 +21 @@
-	register i;
+	register int i;
@@ -117 +116 @@
-	if(i < NINDIR-1)
+	if((unsigned)i < NINDIR-1)
@@ -128,2 +127,2 @@
-passc(c)
-register c;
+int
+passc(register int c)
@@ -131 +129,0 @@
-	register id;
@@ -133 +131 @@
-	if((id = u.u_segflg) == 1)
+	if(u.u_segflg == 1)
@@ -135,5 +133,4 @@
-	else
-		if(id?suibyte(u.u_base, c):subyte(u.u_base, c) < 0) {
-			u.u_error = EFAULT;
-			return(-1);
-		}
+	else if(subyte(u.u_base, c) < 0) {
+		u.u_error = EFAULT;
+		return(-1);
+	}
@@ -153 +150,2 @@
-cpass()
+int
+cpass(void)
@@ -155 +153 @@
-	register c, id;
+	register int c;
@@ -159 +157 @@
-	if((id = u.u_segflg) == 1)
+	if(u.u_segflg == 1)
@@ -161,5 +159,4 @@
-	else
-		if((c = id==0?fubyte(u.u_base):fuibyte(u.u_base)) < 0) {
-			u.u_error = EFAULT;
-			return(-1);
-		}
+	else if((c = fubyte(u.u_base)) < 0) {
+		u.u_error = EFAULT;
+		return(-1);
+	}
@@ -176 +173,2 @@
-nodev()
+int
+nodev(void)
@@ -179,0 +178 @@
+	return(0);
@@ -186 +185,2 @@
-nulldev()
+int
+nulldev(void)
@@ -187,0 +188 @@
+	return(0);
@@ -193,3 +194,2 @@
-bcopy(from, to, count)
-caddr_t from, to;
-register count;
+void
+bcopy(caddr_t from, caddr_t to, register unsigned int count)

% usr/sys/sys/sys1.c
@@ -12,0 +13,42 @@
+void exec(void);
+void exece(void);
+int getxfile(struct inode *ip, int nargc);
+void setregs(void);
+void rexit(void);
+void exit(int rv);
+void wait(void);
+void fork(void);
+void sbreak(void);
+int malloc(struct map *mp, int size);
+void mfree(struct map *mp, int size, int a);
+void panic(char *s);
+void printf(char *fmt, ...);
+int fuword(caddr_t addr);
+int fubyte(caddr_t addr);
+int subyte(caddr_t addr, char c);
+int suword(caddr_t addr, int v);
+int copyout(caddr_t f, caddr_t t, unsigned int n);
+void bcopy(char *from, char *to, unsigned int n);
+void xfree(void);
+void xalloc(struct inode *ip);
+int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
+void expand(int newsize);
+void clearseg(int a);
+void acct(void);
+void wakeup(caddr_t chan);
+void setrun(struct proc *p);
+void swtch(void);
+void closef(struct file *fp);
+int fsig(struct proc *p);
+void sleep(caddr_t chan, int pri);
+void psignal(struct proc *p, int sig);
+int newproc(void);
+void copyseg(int from, int to);
+void arm_sync_icache(void);
+void install_sigtramp(void);
+void readi(struct inode *ip);
+void iput(struct inode *ip);
+int access(struct inode *ip, int mode);
+void plock(struct inode *ip);
+struct inode *namei(int (*func)(void), int flag);
+int uchar(void);
@@ -22 +64,2 @@
-exec()
+void
+exec(void)
@@ -28 +71,13 @@
-exece()
+/*
+ * exece: load and run a new program image.
+ *
+ * Args/environment are collected (NUL-separated) into e_argbuf from the
+ * old user image, then -- after getxfile() builds the new image -- written
+ * as the initial stack frame (see below).  This Armv7 image has ample RAM,
+ * so no swap round-trip is needed for the arg list.  e_argbuf is a per-
+ * process kernel-stack local rather than a shared global: getxfile() sleeps
+ * on its (interrupt-driven) disk read, so a global buffer would be clobbered
+ * by a second process exec-ing concurrently (e.g. both ends of a pipe).
+ */
+void
+exece(void)
@@ -30,3 +84,0 @@
-	register nc;
-	register char *cp;
-	register struct buf *bp;
@@ -34 +86 @@
-	int na, ne, bno, ucp, ap, c;
+	register int nc, c, ap;
@@ -35,0 +88,2 @@
+	int i;
+	char e_argbuf[UARGLEN];
@@ -39,2 +92,0 @@
-	bno = 0;
-	bp = 0;
@@ -48,6 +99,0 @@
-	/*
-	 * Collect arguments on "file" in swap space.
-	 */
-	na = 0;
-	ne = 0;
-	nc = 0;
@@ -55,2 +101 @@
-	if ((bno = malloc(swapmap,(NCARGS+BSIZE-1)/BSIZE)) == 0)
-		panic("Out of swap");
+	nc = 0;
@@ -58,13 +103,3 @@
-		ap = NULL;
-		if (uap->argp) {
-			ap = fuword((caddr_t)uap->argp);
-			uap->argp++;
-		}
-		if (ap==NULL && uap->envp) {
-			uap->argp = NULL;
-			if ((ap = fuword((caddr_t)uap->envp)) == NULL)
-				break;
-			uap->envp++;
-			ne++;
-		}
-		if (ap==NULL)
+		ap = fuword((caddr_t)uap->argp);
+		uap->argp++;
+		if (ap == 0)
@@ -72,2 +107 @@
-		na++;
-		if(ap == -1)
+		if (ap == -1) {
@@ -74,0 +109,2 @@
+			goto bad;
+		}
@@ -76 +112,5 @@
-			if (nc >= NCARGS-1)
+			if ((c = fubyte((caddr_t)ap++)) < 0) {
+				u.u_error = EFAULT;
+				goto bad;
+			}
+			if (nc >= UARGLEN-2) {
@@ -78 +118,17 @@
-			if ((c = fubyte((caddr_t)ap++)) < 0)
+				goto bad;
+			}
+			e_argbuf[nc++] = c;
+		} while (c);
+	}
+	e_argbuf[nc++] = 0;		/* empty string terminates arg list */
+	if (uap->envp) for (;;) {
+		ap = fuword((caddr_t)uap->envp);
+		uap->envp++;
+		if (ap == 0)
+			break;
+		if (ap == -1) {
+			u.u_error = EFAULT;
+			goto bad;
+		}
+		do {
+			if ((c = fubyte((caddr_t)ap++)) < 0) {
@@ -80 +135,0 @@
-			if (u.u_error)
@@ -82,5 +136,0 @@
-			if ((nc&BMASK) == 0) {
-				if (bp)
-					bawrite(bp);
-				bp = getblk(swapdev, swplo+bno+(nc>>BSHIFT));
-				cp = bp->b_un.b_addr;
@@ -88,8 +138,8 @@
-			nc++;
-			*cp++ = c;
-		} while (c>0);
-	}
-	if (bp)
-		bawrite(bp);
-	bp = 0;
-	nc = (nc + NBPW-1) & ~(NBPW-1);
+			if (nc >= UARGLEN-2) {
+				u.u_error = E2BIG;
+				goto bad;
+			}
+			e_argbuf[nc++] = c;
+		} while (c);
+	}
+	e_argbuf[nc++] = 0;		/* empty string terminates env list */
@@ -100 +150 @@
-	 * copy back arglist
+	 * set SUID/SGID protections, if no tracing
@@ -103,20 +153,5 @@
-	ucp = -nc - NBPW;
-	ap = ucp - na*NBPW - 3*NBPW;
-	u.u_ar0[R6] = ap;
-	suword((caddr_t)ap, na-ne);
-	nc = 0;
-	for (;;) {
-		ap += NBPW;
-		if (na==ne) {
-			suword((caddr_t)ap, 0);
-			ap += NBPW;
-		}
-		if (--na < 0)
-			break;
-		suword((caddr_t)ap, ucp);
-		do {
-			if ((nc&BMASK) == 0) {
-				if (bp)
-					brelse(bp);
-				bp = bread(swapdev, swplo+bno+(nc>>BSHIFT));
-				cp = bp->b_un.b_addr;
+	if ((u.u_procp->p_flag&STRC)==0) {
+		if(ip->i_mode&ISUID)
+			if(u.u_uid != 0) {
+				u.u_uid = ip->i_uid;
+				u.u_procp->p_uid = ip->i_uid;
@@ -124,7 +159,62 @@
-			subyte((caddr_t)ucp++, (c = *cp++));
-			nc++;
-		} while(c&0377);
-	}
-	suword((caddr_t)ap, 0);
-	suword((caddr_t)ucp, 0);
-	setregs();
+		if(ip->i_mode&ISGID)
+			u.u_gid = ip->i_gid;
+	} else
+		psignal(u.u_procp, SIGTRC);
+	/*
+	 * Build the initial user stack frame at the top of the address space
+	 * (V7 layout): the NUL-separated string image sits at the very top,
+	 * with the argc/argv[]/0/envp[]/0 vector just below it and sp pointing
+	 * at argc.  crt0 reads the frame straight off sp.  Placing the strings
+	 * at the top is also what lets ps(1) recover a process's command line.
+	 */
+	{
+		unsigned int strbase, sp;
+		int na, ne, j, k;
+		/* leave the top word zero: ps(1) treats a non-zero top-of-stack
+		 * word as an argv pointer, so a string there would mislead it. */
+		strbase = (USERSIZE - 4U - (unsigned)nc) & ~3U;
+		for (i = 0; i < nc; i++)
+			subyte((caddr_t)(strbase + (unsigned)i), e_argbuf[i]);
+		i = 0;
+		na = 0;
+		while (e_argbuf[i]) {
+			na++;
+			while (e_argbuf[i])
+				i++;
+			i++;
+		}
+		i++;
+		ne = 0;
+		while (e_argbuf[i]) {
+			ne++;
+			while (e_argbuf[i])
+				i++;
+			i++;
+		}
+		sp = (strbase - 4U*(unsigned)(na + ne + 3)) & ~7U;
+		suword((caddr_t)sp, na);
+		i = 0;
+		j = 0;
+		while (j < na) {
+			suword((caddr_t)(sp + 4U*(unsigned)(1 + j)),
+			    (int)(strbase + (unsigned)i));
+			while (e_argbuf[i])
+				i++;
+			i++;
+			j++;
+		}
+		suword((caddr_t)(sp + 4U*(unsigned)(1 + na)), 0);
+		i++;
+		k = 0;
+		while (k < ne) {
+			suword((caddr_t)(sp + 4U*(unsigned)(1 + na + 1 + k)),
+			    (int)(strbase + (unsigned)i));
+			while (e_argbuf[i])
+				i++;
+			i++;
+			k++;
+		}
+		suword((caddr_t)(sp + 4U*(unsigned)(1 + na + 1 + ne)), 0);
+		setregs();
+		u.u_ar0[R6] = (int)sp;	/* user stack pointer */
+	}
@@ -132,4 +221,0 @@
-	if (bp)
-		brelse(bp);
-	if(bno)
-		mfree(swapmap, (NCARGS+BSIZE-1)/BSIZE, bno);
@@ -140,3 +226,2 @@
- * Read in and set up memory for executed file.
- * Zero return is normal;
- * non-zero means only the text is being replaced
+ * ELF32 header / program-header subset (the Armv7 toolchain emits ELF;
+ * this replaces the PDP-11 a.out reader).
@@ -144,8 +229,16 @@
-getxfile(ip, nargc)
-register struct inode *ip;
-{
-	register unsigned ds;
-	register sep;
-	register unsigned ts, ss;
-	register i, overlay;
-	long lsize;
+struct elf32_ehdr {
+	unsigned char e_ident[16];
+	unsigned short e_type;
+	unsigned short e_machine;
+	unsigned int e_version;
+	unsigned int e_entry;
+	unsigned int e_phoff;
+	unsigned int e_shoff;
+	unsigned int e_flags;
+	unsigned short e_ehsize;
+	unsigned short e_phentsize;
+	unsigned short e_phnum;
+	unsigned short e_shentsize;
+	unsigned short e_shnum;
+	unsigned short e_shstrndx;
+};
@@ -153,10 +246,11 @@
-	/*
-	 * read in first few bytes
-	 * of file for segment
-	 * sizes:
-	 * ux_mag = 407/410/411/405
-	 *  407 is plain executable
-	 *  410 is RO text
-	 *  411 is separated ID
-	 *  405 is overlaid text
-	 */
+struct elf32_phdr {
+	unsigned int p_type;
+	unsigned int p_offset;
+	unsigned int p_vaddr;
+	unsigned int p_paddr;
+	unsigned int p_filesz;
+	unsigned int p_memsz;
+	unsigned int p_flags;
+	unsigned int p_align;
+};
+#define	PT_LOAD	1
@@ -164,3 +258,6 @@
-	u.u_base = (caddr_t)&u.u_exdata;
-	u.u_count = sizeof(u.u_exdata);
-	u.u_offset = 0;
+static void
+readbytes(struct inode *ip, caddr_t kbuf, unsigned int off, unsigned int n)
+{
+	u.u_base = kbuf;
+	u.u_count = n;
+	u.u_offset = off;
@@ -169,0 +267,18 @@
+}
+/*
+ * Read in and set up memory for an ELF executable.
+ * The Armv7 user image is a flat 1 MB window; arm_sureg maps it, so we
+ * allocate the image, zero it, then read each PT_LOAD segment to its
+ * virtual address.  Entry goes through u_exdata.ux_entloc (used by
+ * setregs).  Zero return is normal.
+ */
+int
+getxfile(register struct inode *ip, int nargc)
+{
+	struct elf32_ehdr eh;
+	struct elf32_phdr ph;
+	register int i;
+	int n, low, stack;
+	unsigned int end, maxend;
+	(void)nargc;
+	readbytes(ip, (caddr_t)&eh, 0, sizeof(eh));
@@ -172 +287,2 @@
-	if (u.u_count!=0) {
+	if(eh.e_ident[0] != 0x7f || eh.e_ident[1] != 'E' ||
+	   eh.e_ident[2] != 'L' || eh.e_ident[3] != 'F' || eh.e_type != 2) {
@@ -176,6 +292,13 @@
-	sep = 0;
-	overlay = 0;
-	if(u.u_exdata.ux_mag == 0407) {
-		lsize = (long)u.u_exdata.ux_dsize + u.u_exdata.ux_tsize;
-		u.u_exdata.ux_dsize = lsize;
-		if (lsize != u.u_exdata.ux_dsize) {	/* check overflow */
+	/*
+	 * Find text and data sizes, and try them out for possible overflow.
+	 */
+	maxend = 0;
+	for(i = 0; i < (int)eh.e_phnum; i++) {
+		readbytes(ip, (caddr_t)&ph, eh.e_phoff + i*eh.e_phentsize,
+		    sizeof(ph));
+		if(u.u_error)
+			goto bad;
+		if(ph.p_type != PT_LOAD)
+			continue;
+		if(ph.p_vaddr >= USERSIZE || ph.p_memsz > USERSIZE - ph.p_vaddr ||
+		   ph.p_filesz > ph.p_memsz) {
@@ -185,12 +308,3 @@
-		u.u_exdata.ux_tsize = 0;
-	} else if (u.u_exdata.ux_mag == 0411)
-		sep++;
-	else if (u.u_exdata.ux_mag == 0405)
-		overlay++;
-	else if (u.u_exdata.ux_mag != 0410) {
-		u.u_error = ENOEXEC;
-		goto bad;
-	}
-	if(u.u_exdata.ux_tsize!=0 && (ip->i_flag&ITEXT)==0 && ip->i_count!=1) {
-		u.u_error = ETXTBSY;
-		goto bad;
+		end = ph.p_vaddr + ph.p_memsz;
+		if(end > maxend)
+			maxend = end;
@@ -198,0 +313,16 @@
+	u.u_prof.pr_scale = 0;
+	xfree();
+	n = USIZE + (int)(USERSIZE >> 6);
+	expand(n);
+	low = (int)btoc(maxend);
+	for(i = 0; i < low; i++)
+		clearseg(u.u_procp->p_addr + USIZE + i);
+	stack = (int)(USERSIZE >> 6) - SSIZE;
+	for(i = stack; i < (int)(USERSIZE >> 6); i++)
+		clearseg(u.u_procp->p_addr + USIZE + i);
+	u.u_tsize = 0;
+	u.u_dsize = (unsigned)low;
+	u.u_ssize = SSIZE;
+	u.u_sep = 0;
+	if(estabur(0, u.u_dsize, u.u_ssize, 0, RO))
+		goto bad;
@@ -200,3 +330 @@
-	 * find text and data sizes
-	 * try them out for possible
-	 * overflow of max sizes
+	 * Load each PT_LOAD segment to its virtual address.
@@ -204,21 +332,4 @@
-	ts = btoc(u.u_exdata.ux_tsize);
-	lsize = (long)u.u_exdata.ux_dsize + u.u_exdata.ux_bsize;
-	if (lsize != (unsigned)lsize) {
-		u.u_error = ENOMEM;
-		goto bad;
-	}
-	ds = btoc(lsize);
-	ss = SSIZE + btoc(nargc);
-	if (overlay) {
-		if (u.u_sep==0 && ctos(ts) != ctos(u.u_tsize) || nargc) {
-			u.u_error = ENOMEM;
-			goto bad;
-		}
-		ds = u.u_dsize;
-		ss = u.u_ssize;
-		sep = u.u_sep;
-		xfree();
-		xalloc(ip);
-		u.u_ar0[PC] = u.u_exdata.ux_entloc & ~01;
-	} else {
-		if(estabur(ts, ds, ss, sep, RO))
+	for(i = 0; i < (int)eh.e_phnum; i++) {
+		readbytes(ip, (caddr_t)&ph, eh.e_phoff + i*eh.e_phentsize,
+		    sizeof(ph));
+		if(u.u_error)
@@ -226,23 +337,6 @@
-	
-		/*
-		 * allocate and clear core
-		 * at this point, committed
-		 * to the new image
-		 */
-	
-		u.u_prof.pr_scale = 0;
-		xfree();
-		i = USIZE+ds+ss;
-		expand(i);
-		while(--i >= USIZE)
-			clearseg(u.u_procp->p_addr+i);
-		xalloc(ip);
-	
-		/*
-		 * read in data segment
-		 */
-	
-		estabur((unsigned)0, ds, (unsigned)0, 0, RO);
-		u.u_base = 0;
-		u.u_offset = sizeof(u.u_exdata)+u.u_exdata.ux_tsize;
-		u.u_count = u.u_exdata.ux_dsize;
+		if(ph.p_type != PT_LOAD || ph.p_filesz == 0)
+			continue;
+		u.u_base = (caddr_t)ph.p_vaddr;
+		u.u_count = ph.p_filesz;
+		u.u_offset = ph.p_offset;
+		u.u_segflg = 0;
@@ -250,19 +344,6 @@
-		/*
-		 * set SUID/SGID protections, if no tracing
-		 */
-		if ((u.u_procp->p_flag&STRC)==0) {
-			if(ip->i_mode&ISUID)
-				if(u.u_uid != 0) {
-					u.u_uid = ip->i_uid;
-					u.u_procp->p_uid = ip->i_uid;
-				}
-			if(ip->i_mode&ISGID)
-				u.u_gid = ip->i_gid;
-		} else
-			psignal(u.u_procp, SIGTRC);
-	}
-	u.u_tsize = ts;
-	u.u_dsize = ds;
-	u.u_ssize = ss;
-	u.u_sep = sep;
-	estabur(ts, ds, ss, sep, RO);
+		if(u.u_error)
+			goto bad;
+	}
+	u.u_exdata.ux_entloc = eh.e_entry;
+	install_sigtramp();
+	arm_sync_icache();
@@ -270 +351 @@
-	return(overlay);
+	return(0);
@@ -276 +357,2 @@
-setregs()
+void
+setregs(void)
@@ -280 +362 @@
-	register i;
+	register int i;
@@ -286 +368 @@
-		u.u_ar0[*cp++] = 0;
+		u.u_ar0[(int)*cp++] = 0;
@@ -296,0 +379 @@
+	u.u_acflag &= ~AFORK;
@@ -300 +382,0 @@
-	u.u_acflag &= ~AFORK;
@@ -308 +390,2 @@
-rexit()
+void
+rexit(void)
@@ -325 +408,2 @@
-exit(rv)
+void
+exit(int rv)
@@ -377 +461,2 @@
-wait()
+void
+wait(void)
@@ -379 +464 @@
-	register f;
+	register int f;
@@ -422 +507,2 @@
-fork()
+void
+fork(void)
@@ -425 +511 @@
-	register a;
+	register int a;
@@ -456 +541,0 @@
-	p1 = u.u_procp;
@@ -458 +543,2 @@
-		u.u_r.r_val1 = p1->p_pid;
+		/* child: fork() returns 0 */
+		u.u_r.r_val1 = 0;
@@ -469,2 +555 @@
-out:
-	u.u_ar0[R7] += NBPW;
+out:	;
@@ -477 +562,2 @@
-sbreak()
+void
+sbreak(void)
@@ -482 +568 @@
-	register a, n, d;
+	register int a, n, d;
@@ -497 +582,0 @@
-	n += USIZE+u.u_ssize;
@@ -500,9 +585,3 @@
-	u.u_dsize += d;
-	if(d > 0)
-		goto bigger;
-	a = u.u_procp->p_addr + n - u.u_ssize;
-	i = n;
-	n = u.u_ssize;
-	while(n--) {
-		copyseg(a-d, a);
-		a++;
+	if((unsigned)n > (USERSIZE >> 6) - u.u_ssize) {
+		u.u_error = ENOMEM;
+		return;
@@ -510,2 +588,0 @@
-	expand(i);
-	return;
@@ -513,7 +590,4 @@
-bigger:
-	expand(n);
-	a = u.u_procp->p_addr + n;
-	n = u.u_ssize;
-	while(n--) {
-		a--;
-		copyseg(a-d, a);
+	if(d > 0) {
+		a = u.u_procp->p_addr + USIZE + (int)u.u_dsize;
+		for(i = 0; i < d; i++)
+			clearseg(a + i);
@@ -521,2 +595,2 @@
-	while(d--)
-		clearseg(--a);
+	u.u_dsize += d;
+	return;

% usr/sys/sys/sys2.c
@@ -5 +4,0 @@
-#include "../h/reg.h"
@@ -8,0 +8,10 @@
+extern void readp(struct file *);
+extern void writep(struct file *);
+extern void wdir(struct inode *);
+extern void itrunc(struct inode *);
+extern void openi(struct inode *, int);
+void rdwr(int mode);
+void write(void);
+void open(void);
+void creat(void);
+void open1(struct inode *ip, int mode, int trf);
@@ -12 +21,2 @@
-read()
+void
+read(void)
@@ -20 +30,2 @@
-write()
+void
+write(void)
@@ -30,2 +41,2 @@
-rdwr(mode)
-register mode;
+void
+rdwr(register int mode)
@@ -80 +91,2 @@
-open()
+void
+open(void)
@@ -98 +110,2 @@
-creat()
+void
+creat(void)
@@ -124,3 +137,2 @@
-open1(ip, mode, trf)
-register struct inode *ip;
-register mode;
+void
+open1(register struct inode *ip, register int mode, int trf)
@@ -163 +175,2 @@
-close()
+void
+close(void)
@@ -181 +194,2 @@
-seek()
+void
+seek(void)
@@ -209 +223,2 @@
-link()
+void
+link(void)
@@ -259 +274,2 @@
-mknod()
+void
+mknod(void)
@@ -290 +306,2 @@
-saccess()
+void
+saccess(void)
@@ -292 +309 @@
-	register svuid, svgid;
+	register int svuid, svgid;

% usr/sys/sys/sys3.c
@@ -5 +4,0 @@
-#include "../h/reg.h"
@@ -13,0 +13,4 @@
+extern void xumount(dev_t);
+void brelse(struct buf *bp);
+void stat1(struct inode *ip, struct stat *ub, off_t pipeadj);
+dev_t getmdev(void);
@@ -18 +21,2 @@
-fstat()
+void
+fstat(void)
@@ -36 +40,2 @@
-stat()
+void
+stat(void)
@@ -56,4 +61,2 @@
-stat1(ip, ub, pipeadj)
-register struct inode *ip;
-struct stat *ub;
-off_t pipeadj;
+void
+stat1(register struct inode *ip, struct stat *ub, off_t pipeadj)
@@ -94 +97,2 @@
-dup()
+void
+dup(void)
@@ -101 +105 @@
-	register i, m;
+	register int i, m;
@@ -131 +135,2 @@
-smount()
+void
+smount(void)
@@ -197 +202,2 @@
-sumount()
+void
+sumount(void)
@@ -203,3 +208,0 @@
-	register struct a {
-		char	*fspec;
-	};
@@ -240 +243 @@
-getmdev()
+getmdev(void)

% usr/sys/sys/sys4.c
@@ -5 +4,0 @@
-#include "../h/reg.h"
@@ -8,0 +8,29 @@
+int intr_enable(void);
+int intr_disable(void);
+void chdirec(struct inode **ipp);
+void sleep(caddr_t chan, int pri);
+void sysacct(void);
+void stat(void);
+void saccess(void);
+void link(void);
+void mknod(void);
+void smount(void);
+void sumount(void);
+struct inode *iget(dev_t dev, ino_t ino);
+void iput(struct inode *ip);
+void umask(void);
+void getuid(void);
+void getgid(void);
+void getpid(void);
+void setuid(void);
+void setgid(void);
+void sync(void);
+void nice(void);
+void gtime(void);
+void stime(void);
+void alarm(void);
+void ftime(void);
+void times(void);
+void profil(void);
+void syslock(void);
+extern struct inode *rootdir;
@@ -17 +45,2 @@
-gtime()
+void
+gtime(void)
@@ -26 +55,2 @@
-ftime()
+void
+ftime(void)
@@ -35 +65 @@
-	spl7();
+	intr_disable();
@@ -38 +68 @@
-	spl0();
+	intr_enable();
@@ -53 +83,2 @@
-stime()
+void
+stime(void)
@@ -64 +95,2 @@
-setuid()
+void
+setuid(void)
@@ -66 +98 @@
-	register uid;
+	register int uid;
@@ -80 +112,2 @@
-getuid()
+void
+getuid(void)
@@ -87 +120,2 @@
-setgid()
+void
+setgid(void)
@@ -89 +123 @@
-	register gid;
+	register int gid;
@@ -102 +136,2 @@
-getgid()
+void
+getgid(void)
@@ -109 +144,2 @@
-getpid()
+void
+getpid(void)
@@ -115 +151,2 @@
-sync()
+void
+sync(void)
@@ -121 +158,2 @@
-nice()
+void
+nice(void)
@@ -123 +161 @@
-	register n;
+	register int n;
@@ -145 +183,2 @@
-unlink()
+void
+unlink(void)
@@ -194 +233,2 @@
-chdir()
+void
+chdir(void)
@@ -199 +239,2 @@
-chroot()
+void
+chroot(void)
@@ -205,2 +246,2 @@
-chdirec(ipp)
-register struct inode **ipp;
+void
+chdirec(register struct inode **ipp)
@@ -234 +275,2 @@
-chmod()
+void
+chmod(void)
@@ -255 +297,2 @@
-chown()
+void
+chown(void)
@@ -273 +316,2 @@
-ssig()
+void
+ssig(void)
@@ -275 +319 @@
-	register a;
+	register int a;
@@ -292 +336,2 @@
-kill()
+void
+kill(void)
@@ -295 +340 @@
-	register a;
+	register int a;
@@ -327 +372,2 @@
-times()
+void
+times(void)
@@ -338 +384,2 @@
-profil()
+void
+profil(void)
@@ -357 +404,2 @@
-alarm()
+void
+alarm(void)
@@ -360 +408 @@
-	register c;
+	register int c;
@@ -376 +424,2 @@
-pause()
+void
+pause(void)
@@ -386 +435,2 @@
-umask()
+void
+umask(void)
@@ -391 +441 @@
-	register t;
+	register int t;
@@ -403 +453,2 @@
-utime()
+void
+utime(void)

% usr/sys/sys/sysent.c
@@ -2,0 +3,29 @@
+#include "../h/dir.h"
+#include "../h/user.h"
+#include "../h/proc.h"
+#include "../h/reg.h"
+#include "../h/inode.h"
+#include "../h/file.h"
+#include "../h/tty.h"
+#include "../h/seg.h"
+void nullsys(void), nosys(void);
+void rexit(void), fork(void), read(void), write(void), open(void);
+void close(void), wait(void), creat(void), link(void), unlink(void);
+void exec(void), exece(void), chdir(void), gtime(void), mknod(void);
+void chmod(void), chown(void), sbreak(void), stat(void), seek(void);
+void getpid(void), smount(void), sumount(void), setuid(void), getuid(void);
+void stime(void), ptrace(void), alarm(void), fstat(void), pause(void);
+void utime(void), saccess(void), nice(void), ftime(void), sync(void);
+void kill(void), dup(void), pipe(void), times(void), profil(void);
+void setgid(void), getgid(void), ssig(void), sysacct(void), syslock(void);
+void umask(void), chroot(void), stty(void), gtty(void), ioctl(void);
+void sigreturn(void);
+int issig(void);
+void psig(void);
+void psignal(struct proc *p, int sig);
+int setpri(struct proc *pp);
+void qswtch(void);
+void panic(char *s);
+void printf(char *fmt, ...);
+int save(int *lp) __attribute__((returns_twice));
+void bcopy(char *from, char *to, unsigned int n);
@@ -8,0 +38,2 @@
+ * On Armv7 all arguments arrive in registers, so
+ * sy_nrarg == sy_narg for every entry.
@@ -10,54 +40,0 @@
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
@@ -67,64 +44,64 @@
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
+	{3, 3, open},			/*  5 = open */
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
+	{3, 3, chown},			/* 16 = chown */
+	{1, 1, sbreak},			/* 17 = break */
+	{2, 2, stat},			/* 18 = stat */
+	{3, 3, seek},			/* 19 = seek */
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
+	{1, 1, ftime},			/* 35 = ftime */
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
+	{0, 0, nosys},			/* 52 = set user physical addresses */
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
+	{0, 0, sigreturn}		/* 63 = sigreturn (Armv7 signal trampoline) */
@@ -131,0 +109,76 @@
+char	regloc[9] = { R0, R1, R2, R3, R4, R5, R6, R7, RPS };
+/*
+ * Called from svc_entry (conf/low.s) on a system call.  r is the 17-int
+ * trap frame; the syscall number is in r7 (Armv7 ABI), arguments in
+ * r0..r5.  Adapted from v7 trap.c case 6+USER plus the out: tail.
+ */
+void
+trap(int *r)
+{
+	register int i;
+	register struct sysent *callp;
+	u.u_fpsaved = 0;
+	u.u_ar0 = r;
+	u.u_error = 0;
+	callp = &sysent[r[7] & 077];	/* Armv7 syscall number is in r7 */
+	for(i = 0; i < callp->sy_narg && i < 6; i++)
+		u.u_arg[i] = r[i];
+	u.u_dirp = (caddr_t)u.u_arg[0];
+	/*
+	 * Default the return registers to 0.  V7 seeded r_val1 from the
+	 * incoming r0 and relied on each libc stub to `clr r0` on the
+	 * success path; this port's libc returns the raw syscall register
+	 * via syscall3, so a call that leaves r_val1 unset (access, chdir,
+	 * close, ...) must yield 0 to mean success.
+	 */
+	u.u_r.r_val1 = 0;
+	u.u_r.r_val2 = 0;
+	u.u_ap = u.u_arg;
+	if (save(u.u_qsav)) {
+		if (u.u_error == 0)
+			u.u_error = EINTR;
+	} else {
+		(*callp->sy_call)();
+	}
+	if (u.u_error)
+		r[R0] = -u.u_error;
+	else {
+		r[R0] = u.u_r.r_val1;
+		r[R1] = u.u_r.r_val2;
+	}
+	/* out: deliver signals and reschedule before returning to user */
+	if (issig())
+		psig();
+	(void)setpri(u.u_procp);
+	if (runrun)
+		qswtch();
+}
+/*
+ * Called from the undef/abort entry stubs (conf/low.s) for a hardware
+ * fault.  signo is the signal it maps to (0 from irq_entry, to give up
+ * the cpu as v7's trap 12 did); r is the trap frame.  A fault taken
+ * in kernel mode is fatal.
+ */
+void
+user_trap_handler(int signo, int *r)
+{
+	int mode = r[RPS] & 0x1f;
+	if(mode != 0x10 && mode != 0x1f) {
+		unsigned int dfar, dfsr;
+		__asm__ volatile("mrc p15,0,%0,c6,c0,0":"=r"(dfar));
+		__asm__ volatile("mrc p15,0,%0,c5,c0,0":"=r"(dfsr));
+		printf("kernel trap sig=%d pc=0x%x cpsr=0x%x dfar=0x%x dfsr=0x%x\n",
+		    signo, r[15], r[RPS], dfar, dfsr);
+		panic("kernel trap");
+	}
+	u.u_fpsaved = 0;
+	u.u_ar0 = r;
+	psignal(u.u_procp, signo);
+	if (issig())
+		psig();
+	(void)setpri(u.u_procp);
+	if (runrun)
+		qswtch();
+}
+void nosys(void)   { u.u_error = EINVAL; }
+void nullsys(void) { }

% usr/sys/sys/text.c
@@ -3 +2,0 @@
-#include "../h/map.h"
@@ -9,0 +9 @@
+#include "../h/map.h"
@@ -10,0 +11,23 @@
+struct map;
+int malloc(struct map *mp, int size);
+void mfree(struct map *mp, int size, int a);
+void panic(char *s);
+void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
+void wakeup(caddr_t chan);
+void sleep(caddr_t chan, int pri);
+extern void xlock(struct text *);
+extern void xunlock(struct text *);
+extern void xccdec(struct text *);
+extern void xuntext(struct text *);
+void xswap(register struct proc *p, int ff, int os);
+extern void xexpand(struct text *);
+extern void xfree(void);
+extern void xalloc(struct inode *);
+void readi(struct inode *ip);
+void psignal(struct proc *p, int sig);
+void printf(char *fmt, ...);
+void iput(struct inode *ip);
+void sureg(void);
+void qswtch(void);
+int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
+int save(int *lp);
@@ -22,2 +45,2 @@
-xswap(p, ff, os)
-register struct proc *p;
+void
+xswap(register struct proc *p, int ff, int os)
@@ -25 +48 @@
-	register a;
+	register int a;
@@ -50 +73,2 @@
-xfree()
+void
+xfree(void)
@@ -84,2 +108,2 @@
-xalloc(ip)
-register struct inode *ip;
+void
+xalloc(register struct inode *ip)
@@ -147,2 +171,2 @@
-xexpand(xp)
-register struct text *xp;
+void
+xexpand(register struct text *xp)
@@ -171,2 +195,2 @@
-xlock(xp)
-register struct text *xp;
+void
+xlock(register struct text *xp)
@@ -182,2 +206,2 @@
-xunlock(xp)
-register struct text *xp;
+void
+xunlock(register struct text *xp)
@@ -195,2 +219,2 @@
-xccdec(xp)
-register struct text *xp;
+void
+xccdec(register struct text *xp)
@@ -216,2 +240,2 @@
-xumount(dev)
-register dev;
+void
+xumount(register dev_t dev)
@@ -229,2 +253,2 @@
-xrele(ip)
-register struct inode *ip;
+void
+xrele(register struct inode *ip)
@@ -234 +258 @@
-	if (ip->i_flag&ITEXT==0)
+	if ((ip->i_flag&ITEXT)==0)
@@ -245,2 +269,2 @@
-xuntext(xp)
-register struct text *xp;
+void
+xuntext(register struct text *xp)

% usr/sys/sys/ureg.c
@@ -7,0 +8,2 @@
+int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
+void arm_sureg(int *uisa, int *uisd, int nseg);
@@ -15 +17,2 @@
-sureg()
+void
+sureg(void)
@@ -17,2 +20,3 @@
-	register *udp, *uap, *rdp;
-	int *rap, *limudp;
+	register int *udp, *uap, *rap;
+	int auisa[16];
+	int *limudp;
@@ -28,2 +32 @@
-	rap = (int *)UISA;
-	rdp = (int *)UISD;
+	rap = &auisa[0];
@@ -33 +36 @@
-		*rdp++ = *udp++;
+		udp++;
@@ -34,0 +38 @@
+	arm_sureg(auisa, &u.u_uisd[0], limudp - &u.u_uisd[0]);
@@ -48,2 +52,2 @@
-estabur(nt, nd, ns, sep, xrw)
-unsigned nt, nd, ns;
+int
+estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw)
@@ -51 +55,7 @@
-	register a, *ap, *dp;
+	(void)sep; (void)xrw;
+	/*
+	 * Armv7: user memory is mapped by page tables (arm_sureg), not the
+	 * PDP-11 8-segment scheme, so the per-segment limit checks and the
+	 * u_uisa/u_uisd prototype build do not apply.  Validate the total
+	 * image size against maxmem and (re)load the page tables via sureg().
+	 */
@@ -53,79 +63,3 @@
-	if(sep) {
-		if(cputype == 40)
-			goto err;
-		if(ctos(nt) > 8 || ctos(nd)+ctos(ns) > 8)
-			goto err;
-	} else
-		if(ctos(nt)+ctos(nd)+ctos(ns) > 8)
-			goto err;
-	if(nt+nd+ns+USIZE > maxmem)
-		goto err;
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
+	if((int)(nt+nd+ns+USIZE) > maxmem) {
+		u.u_error = ENOMEM;
+		return(-1);
@@ -136,3 +69,0 @@
-err:
-	u.u_error = ENOMEM;
-	return(-1);
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
