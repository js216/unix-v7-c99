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
@@ -0,0 +1,48 @@
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
+
+$(CMD_BIN:%=bin/%): bin/%: $(CRT) $C/%.o $(LIBM) $(LIBC) | bin
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
+$(LIBC_OBJ) $(CRT): CPPFLAGS = -Iusr/include -Iusr
+$(LIBC_OBJ) $(CRT): $L/lib.mk
+
+$(LIBC): $(LIBC_OBJ)
+	rm -f $@
+	$(AR) rc $@ $^

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
@@ -0,0 +1,78 @@
+CROSS_COMPILE ?= arm-none-eabi-
+CC = $(CROSS_COMPILE)gcc
+AS = $(CROSS_COMPILE)as
+AR = $(CROSS_COMPILE)ar
+HOSTCC = arm-linux-gnueabihf-gcc
+LEX = flex
+
+CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon \
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
+	V7_MKFS_TIME=284774400 etc/mkfs $@ boot/rootfs.proto
+	truncate -s $$(awk '/^(swplo|nswap) /{n+=$$2} END{print n*512}' \
+	    usr/sys/conf/qemuconf) $@
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
+	rm -f etc/mkfs boot/unix boot/rootfs.img
+
+.PHONY: all clean qemu
+.DELETE_ON_ERROR:
+
+-include $(OBJ:.o=.d)

% boot/rootfs.proto /dev/null
@@ -0,0 +1,178 @@
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
+		swap	b--640 0 0 0 0
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
@@ -7 +6,0 @@
-/etc/mount /dev/rp3 /usr

% etc/ttys

% usr/include/a.out.h
@@ -33,0 +34 @@
+int	nlist();

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
+struct	group	*getgrent(), *getgrgid(), *getgrnam();
+void	setgrent(), endgrent();

% usr/include/math.h
@@ -9,2 +9,2 @@
-#define HUGE	1.701411733192644270e38
-#define LOGHUGE 39
+#define HUGE	1.797693134862315708e308
+#define LOGHUGE 308

% usr/include/pwd.h
@@ -11,0 +12,2 @@
+struct	passwd	*getpwent(), *getpwuid(), *getpwnam();
+void	setpwent(), endpwent();

% usr/include/setjmp.h
@@ -1 +1,2 @@
-typedef int jmp_buf[3];
+typedef int jmp_buf[10];
+int	setjmp(), longjmp();

% usr/include/sgtty.h

% usr/include/signal.h

% usr/include/stdio.h
@@ -21,0 +22 @@
+#ifndef NULL
@@ -22,0 +24 @@
+#endif
@@ -41,0 +44,24 @@
+int	read(), write(), open(), close(), creat(), unlink(), link(), access();
+int	chdir(), chmod(), chown(), mknod(), utime(), stat(), fstat(), fork();
+int	wait(), execv(), execvp(), dup(), pipe(), getuid(), setuid(), getgid();
+int	setgid(), getpid(), umask(), sync(), kill(), (*signal())(), alarm(), pause();
+int	nice(), gtty(), stty(), ioctl(), mount(), umount(), time(), stime();
+int	times(), ftime(), dysize(), fclose(), fseek(), fgetc(), fread(), fwrite();
+int	puts(), fputs(), ungetc(), fflush(), _filbuf(), _flsbuf(), system();
+int	isatty(), ttyslot(), strlen(), strcmp(), strncmp(), atoi(), rand();
+int	printf(char *, ...), fprintf(FILE *, char *, ...);
+int	fscanf(FILE *, char *, ...), sscanf(char *, char *, ...);
+int	execl(char *, char *, ...), execlp(char *, char *, ...);
+char	*sprintf(char *, char *, ...);
+void	exit() __attribute__((__noreturn__));
+void	_exit() __attribute__((__noreturn__));
+void	abort() __attribute__((__noreturn__));
+long	lseek();
+unsigned	sleep();
+double	atof();
+struct	tm *localtime();
+char	*ctime(), *gets(), *mktemp(), *getenv(), *getlogin(), *getpass();
+char	*ttyname(), *crypt(), *strncat(), *strcpy(), *strcat(), *strncpy();
+char	*index(), *rindex(), *malloc(), *realloc();
+void	rewind(), setbuf(), perror(), srand(), qsort(), free(), swab();
+extern char **environ;

% usr/include/sys/acct.h

% usr/include/sys/dir.h

% usr/include/sys/fblk.h

% usr/include/sys/filsys.h

% usr/include/sys/ino.h

% usr/include/sys/inode.h
@@ -41 +41 @@
-		};
+		} u_reg;
@@ -45 +45 @@
-		};
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
+#define	USIZE	128		/* size of user block (*64) */
+#define	UBASE	0x4F000000U	/* abs. addr of user block */
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

% usr/include/sys/timeb.h
@@ -0,0 +1 @@
+#include <sys/types.h>

% usr/include/sys/times.h

% usr/include/sys/types.h
@@ -0,0 +1,2 @@
+#ifndef SYS_TYPES_H
+#define SYS_TYPES_H
@@ -3 +5 @@
-typedef	unsigned int	ino_t;     	/* i-node number */
+typedef	unsigned short	ino_t;     	/* i-node number */
@@ -5 +7 @@
-typedef	int        	label_t[6]; 	/* program status */
+typedef	int        	label_t[10]; 	/* program status */
@@ -9 +11 @@
-#define	major(x)  	(int)(((unsigned)x>>8))
+#define	major(x)  	(int)(((unsigned)x>>8)&0377)
@@ -11,0 +14 @@
+#endif

% usr/include/time.h

% usr/include/tp_defs.h

% usr/include/utmp.h

% usr/src/cmd/ac.c
@@ -34,0 +35,4 @@
+void	update(), upall(), print(), loop();
+int	among();
+void	pdate(), newday();
+int
@@ -35,0 +40 @@
+int	argc;
@@ -39 +44 @@
-	register i;
+	register int i;
@@ -91,0 +97 @@
+void
@@ -94 +100 @@
-	register i;
+	register int i;
@@ -136,0 +143 @@
+void
@@ -159,0 +167 @@
+void
@@ -160,0 +169 @@
+int	f;
@@ -167,0 +177 @@
+void
@@ -168,0 +179 @@
+int	f;
@@ -202,0 +214 @@
+int
@@ -203,0 +216 @@
+int	i;
@@ -205 +218 @@
-	register j, k;
+	register int j, k;
@@ -222,0 +236 @@
+void
@@ -239,0 +254 @@
+void

% usr/src/cmd/accton.c
@@ -0,0 +1,2 @@
+#include <stdio.h>
+int
@@ -1,0 +4 @@
+int argc;
@@ -4 +7,2 @@
-	extern errno;
+	extern int errno;
+	int acct();

% usr/src/cmd/arcv.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -17 +18 @@
-	unsigned siz;
+	unsigned short siz;
@@ -23,0 +25 @@
+void	conv();
@@ -28,0 +31 @@
+int
@@ -29,0 +33 @@
+int argc;
@@ -32 +36 @@
-	register i;
+	register int i;
@@ -41,0 +46 @@
+void
@@ -60 +65 @@
-	read(f, (char *)&b.magic, sizeof(b.magic));
+	read(f, (char *)&b.magic, 2);
@@ -79 +84 @@
-	nh.ar_date = oh.odate;
+	nh.ar_date = (unsigned long)oh.odate<<16 | (oh.odate>>16 & 0177777);

% usr/src/cmd/at.c
@@ -10,0 +11 @@
+#define	utime	at_utime
@@ -57,0 +59,2 @@
+int makeutime(), makeuday(), filename(), pclose();
+int
@@ -58,0 +62 @@
+int argc;
@@ -61,2 +65,2 @@
-	extern onintr();
-	register c;
+	extern void onintr();
+	register int c;
@@ -117,0 +122 @@
+int
@@ -121 +126 @@
-	register val;
+	register int val;
@@ -127 +132 @@
-	while(isdigit(*p)) {
+	while(isdigit(*p&0377)) {
@@ -138,2 +143,2 @@
-			if (isdigit(*p)) {
-				if (isdigit(p[1])) {
+			if (isdigit(*p&0377)) {
+				if (isdigit(p[1]&0377)) {
@@ -146,0 +152 @@
+			break;
@@ -197,0 +204 @@
+	return(0);
@@ -200,0 +208 @@
+int
@@ -201,0 +210 @@
+int argc;
@@ -277 +286 @@
-	while (c = *begin++) {
+	while ((c = *begin++)) {
@@ -287,0 +297 @@
+int
@@ -289,0 +300 @@
+int y, d, t;
@@ -291 +302 @@
-	register i;
+	register int i;
@@ -297 +308 @@
-			return;
+			return(0);
@@ -300,0 +312 @@
+void

% usr/src/cmd/atrun.c
@@ -16,0 +17 @@
+void	makenowtime(), updatetime(), run();
@@ -18,2 +19,2 @@
-main(argc, argv)
-char **argv;
+int
+main()
@@ -51,0 +53 @@
+void
@@ -64,0 +67 @@
+void
@@ -65,0 +69 @@
+int t;
@@ -76,0 +81 @@
+void
@@ -81 +86 @@
-	register pid, i;
+	register int pid, i;
@@ -96 +101 @@
-	if (pid = fork()) {
+	if ((pid = fork())) {

% usr/src/cmd/awk/awk.def
@@ -2 +2 @@
-#define yfree free
+#define yfree(p) free((char *)(p))

% usr/src/cmd/awk/awk.g.y
@@ -29,0 +30 @@
+%left	NL SPRINTF SPLIT ',' '{' ELSE
@@ -33,0 +35,3 @@
+int	yylex(), yyerror(), stat3(), stat2(), stat4(), op1(), op2(), op3(), valtonode(), makedfa(), genprint(), pa2stat(), linkum(), exptostat(), genjump();
+void	startreg();
+char	*cclenter();
@@ -41 +45 @@
-	  begin pa_stats end	{ if (errorflag==0) winner = stat3(PROGRAM, $1, $2, $3); }
+	  begin pa_stats end	{ if (errorflag==0) winner = (node *)stat3(PROGRAM, $1, $2, $3); }
@@ -48 +52 @@
-	| 	{ PUTS("empty XBEGIN"); $$ = nullstat; }
+	| 	{ PUTS("empty XBEGIN"); $$ = (int)nullstat; }
@@ -54 +58 @@
-	|	{ PUTS("empty END"); $$ = nullstat; }
+	|	{ PUTS("empty END"); $$ = (int)nullstat; }
@@ -104 +108 @@
-	  var
+	  var %prec ASGNOP
@@ -116 +120 @@
-			{ PUTS("substr(e,e,e)"); $$ = op3(SUBSTR, $3, $5, nullstat); }
+			{ PUTS("substr(e,e,e)"); $$ = op3(SUBSTR, $3, $5, (int)nullstat); }
@@ -120 +124 @@
-			{ PUTS("split(e,e,e)"); $$ = op3(SPLIT, $3, $5, nullstat); }
+			{ PUTS("split(e,e,e)"); $$ = op3(SPLIT, $3, $5, (int)nullstat); }
@@ -138,2 +142,2 @@
-	  term		{ PUTS("term"); }
-	| expr term	{ PUTS("expr term"); $$ = op2(CAT, $1, $2); }
+	  term %prec ASGNOP	{ PUTS("term"); }
+	| expr term %prec ASGNOP	{ PUTS("expr term"); $$ = op2(CAT, $1, $2); }
@@ -145 +149 @@
-	|
+	| %prec ASGNOP
@@ -149 +153 @@
-	  pattern	{ PUTS("pattern"); $$ = stat2(PASTAT, $1, genprint()); }
+	  pattern %prec ASGNOP	{ PUTS("pattern"); $$ = stat2(PASTAT, $1, genprint()); }
@@ -151 +155 @@
-	| pattern ',' pattern		{ PUTS("srch,srch"); $$ = pa2stat($1, $3, genprint()); }
+	| pattern ',' pattern %prec ASGNOP	{ PUTS("srch,srch"); $$ = pa2stat($1, $3, genprint()); }
@@ -154 +158 @@
-	| '{' stat_list '}'	{ PUTS("null pattern {...}"); $$ = stat2(PASTAT, nullstat, $2); }
+	| '{' stat_list '}'	{ PUTS("null pattern {...}"); $$ = stat2(PASTAT, (int)nullstat, $2); }
@@ -159,2 +163,2 @@
-	|	{ PUTS("null pa_stat"); $$ = nullstat; }
-	| pa_stats pa_stat	{PUTS("pa_stats pa_stat"); $$ = linkum($1, $2); }
+	| %prec ASGNOP	{ PUTS("null pa_stat"); $$ = (int)nullstat; }
+	| pa_stats pa_stat %prec ASGNOP	{PUTS("pa_stats pa_stat"); $$ = linkum($1, $2); }
@@ -173,3 +177,3 @@
-	  expr	{ PUTS("expr"); }
-	| pe_list	{ PUTS("pe_list"); }
-	|		{ PUTS("null print_list"); $$ = valtonode(lookup("$record", symtab), CFLD); }
+	  expr %prec ASGNOP	{ PUTS("expr"); }
+	| pe_list %prec ASGNOP	{ PUTS("pe_list"); }
+	| %prec ASGNOP	{ PUTS("null print_list"); $$ = valtonode(lookup("$record", symtab), CFLD); }
@@ -179,2 +183,2 @@
-	  expr ',' expr	{$$ = linkum($1, $3); }
-	| pe_list ',' expr	{$$ = linkum($1, $3); }
+	  expr ',' expr %prec ASGNOP	{$$ = linkum($1, $3); }
+	| pe_list ',' expr %prec ASGNOP	{$$ = linkum($1, $3); }
@@ -227 +231 @@
-		{ PUTS("print list"); $$ = stat3($1, $2, nullstat, nullstat); }
+		{ PUTS("print list"); $$ = stat3($1, $2, (int)nullstat, (int)nullstat); }
@@ -231 +235 @@
-		{ PUTS("printf list"); $$ = stat3($1, $2, nullstat, nullstat); }
+		{ PUTS("printf list"); $$ = stat3($1, $2, (int)nullstat, (int)nullstat); }
@@ -233 +237 @@
-	|		{ PUTS("null simple statement"); $$ = nullstat; }
+	|		{ PUTS("null simple statement"); $$ = (int)nullstat; }
@@ -239 +243 @@
-	| if statement		{ PUTS("if stat"); $$ = stat3(IF, $1, $2, nullstat); }
+	| if statement %prec ASGNOP	{ PUTS("if stat"); $$ = stat3(IF, $1, $2, (int)nullstat); }
@@ -253 +257 @@
-	|			{ PUTS("null stat list"); $$ = nullstat; }
+	|			{ PUTS("null stat list"); $$ = (int)nullstat; }
@@ -264 +268 @@
-		{ PUTS("for(e;e;e)"); $$ = stat4(FOR, $3, nullstat, $6, $9); }
+		{ PUTS("for(e;e;e)"); $$ = stat4(FOR, $3, (int)nullstat, $6, $9); }

% usr/src/cmd/awk/awk.lx.l
@@ -0,0 +1 @@
+%option noyywrap noinput nounistd
@@ -2,0 +4,5 @@
+%top{
+#include <stddef.h>
+#define	_STRING_H_
+#define	_STDLIB_H_
+}
@@ -8,0 +15,10 @@
+cell	*fieldadr();
+int	yyerror(), input();
+void	*memset(void *s, int c, unsigned int n);
+#undef	YY_INPUT
+#define	YY_INPUT(buf,result,max_size) \
+do { \
+	int c = input(); \
+	if (c == 0) result = YY_NULL; \
+	else { buf[0] = c; result = 1; } \
+} while (0)
@@ -10 +26 @@
-int	lineno	1;
+int	lineno = 1;
@@ -28 +44 @@
-	switch (yybgin-yysvec-1) {	/* witchcraft */
+	switch (YY_START) {	/* witchcraft */
@@ -66 +82 @@
-				yylval = lookup("$record", symtab);
+				yylval = (int)lookup("$record", symtab);
@@ -69 +85 @@
-				yylval = fieldadr(atoi(yytext+1));
+				yylval = (int)fieldadr(atoi(yytext+1));
@@ -74 +90 @@
-<A>NF		{ mustfld=1; yylval = setsymtab(yytext, NULL, 0.0, NUM, symtab); RETURN(VAR); }
+<A>NF		{ mustfld=1; yylval = (int)setsymtab(yytext, NULL, 0.0, NUM, symtab); RETURN(VAR); }
@@ -76 +92 @@
-		yylval = setsymtab(yytext, NULL, atof(yytext), CON|NUM, symtab); RETURN(NUMBER); }
+		yylval = (int)setsymtab(yytext, NULL, atof(yytext), CON|NUM, symtab); RETURN(NUMBER); }
@@ -101 +117 @@
-<A>{A}{B}*	{ yylval = setsymtab(yytext, tostring(""), 0.0, STR, symtab); RETURN(VAR); }
+<A>{A}{B}*	{ yylval = (int)setsymtab(yytext, tostring(""), 0.0, STR, symtab); RETURN(VAR); }
@@ -131 +147 @@
-<str>\"		{ BEGIN A; cbuf[clen]=0; yylval = setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab); RETURN(STRING); }
+<str>\"		{ BEGIN A; cbuf[clen]=0; yylval = (int)setsymtab(cbuf, tostring(cbuf), 0.0, CON|STR, symtab); RETURN(STRING); }
@@ -140 +156 @@
-<chc>"]"	{ BEGIN reg; cbuf[clen]=0; yylval = tostring(cbuf);
+<chc>"]"	{ BEGIN reg; cbuf[clen]=0; yylval = (int)tostring(cbuf);
@@ -147,0 +164 @@
+int
@@ -150 +167 @@
-	register c;
+	register int c;
@@ -153,3 +170 @@
-	if (yysptr > yysbuf)
-		c = U(*--yysptr);
-	else if (yyin == NULL)
+	if (lexprog != NULL)
@@ -165,0 +181 @@
+void

% usr/src/cmd/awk/b.c
@@ -3,0 +4,2 @@
+int error(), first(), notin();
+void overflo(), penter(), follow(), cfoll(), freetr();
@@ -59,0 +62 @@
+void
@@ -84,0 +88 @@
+void
@@ -111 +115 @@
-	register i, c;
+	register int i, c;
@@ -138,0 +143 @@
+void
@@ -143,0 +149 @@
+void
@@ -147 +153 @@
-	register i;
+	register int i;
@@ -175,0 +182 @@
+int
@@ -179 +186 @@
-	register b;
+	register int b;
@@ -209,0 +217 @@
+void
@@ -244,0 +253 @@
+int
@@ -253,0 +263 @@
+int
@@ -255,0 +266 @@
+int n;
@@ -257 +268 @@
-	register i, j;
+	register int i, j;
@@ -272 +283 @@
-int *add(n) {		/* remember setvec */
+int *add(n) int n; {		/* remember setvec */
@@ -274 +285 @@
-	register i;
+	register int i;
@@ -290 +301 @@
-	register i, k;
+	register int i, k;
@@ -300 +311 @@
-	int fatab[257];
+	int fatab[2*256+1];
@@ -308,3 +319,3 @@
-	char symbol[NCHARS];
-	char isyms[NCHARS];
-	char ssyms[NCHARS];
+	char symbol[256];
+	char isyms[256];
+	char ssyms[256];
@@ -314 +325 @@
-	for (i=0; i<NCHARS; i++)  isyms[i] = symbol[i] = 0;
+	for (i=0; i<256; i++)  isyms[i] = symbol[i] = 0;
@@ -328 +339 @@
-				k = (int) right(cp);
+				k = (int) right(cp) & 0377;
@@ -347,2 +358,2 @@
-						if (isyms[*p] != 1) {
-							isyms[*p] = 1;
+						if (isyms[*p&0377] != 1) {
+							isyms[*p&0377] = 1;
@@ -389 +400 @@
-					k = (int) right(cp);
+					k = (int) right(cp) & 0377;
@@ -408,2 +419,2 @@
-							if (isyms[*p] == 0 && symbol[*p] == 0) {
-								symbol[*p] = 1;
+							if (isyms[*p&0377] == 0 && symbol[*p&0377] == 0) {
+								symbol[*p&0377] = 1;
@@ -428 +439 @@
-			symbol[c] = 0;
+			symbol[c&0377] = 0;
@@ -435 +446 @@
-					if (k == CHAR && c == (int) right(cp)
+					if ((k == CHAR && c == (int) right(cp))
@@ -437,2 +448,2 @@
-					 || k == CCL && member(c, (char *) right(cp))
-					 || k == NCCL && !member(c, (char *) right(cp))) {
+					 || (k == CCL && member(c, (char *) right(cp)))
+					 || (k == NCCL && !member(c, (char *) right(cp)))) {
@@ -506,0 +518 @@
+int
@@ -511 +523 @@
-	register count;
+	register int count;

% usr/src/cmd/awk/lib.c
@@ -4,0 +5,2 @@
+int error(), fldbld(), member(), isnumber();
+void setclvar();
@@ -17 +19 @@
-#define	FINIT	{0, NULL, 0.0, FLD|STR}
+#define	FINIT	{0, NULL, 0.0, FLD|STR, 0}
@@ -19 +21 @@
-	{ "$record", record, 0.0, STR|FLD},
+	{ "$record", record, 0.0, STR|FLD, 0},
@@ -30,0 +33 @@
+int
@@ -36 +39 @@
-	register c, sep;
+	register int c, sep;
@@ -86,0 +90 @@
+void
@@ -100,0 +105 @@
+int
@@ -158,0 +164 @@
+	return(0);
@@ -160,0 +167 @@
+int
@@ -167 +174 @@
-		return;
+		return(0);
@@ -171 +178 @@
-		while (*r++ = *p++)
+		while ((*r++ = *p++))
@@ -181,0 +189 @@
+	return(0);
@@ -184,0 +193 @@
+int n;
@@ -192,0 +202 @@
+int
@@ -195,0 +206 @@
+	return(0);
@@ -198 +209,2 @@
-error(f, s, a1, a2, a3, a4, a5, a6, a7) {
+int
+error(f, s, a1, a2, a3, a4, a5, a6, a7) char *s; int f, a1, a2, a3, a4, a5, a6, a7; {
@@ -205,0 +218 @@
+	return(0);
@@ -207,0 +221 @@
+void
@@ -208,0 +223 @@
+	(void)s;
@@ -213,0 +229 @@
+int
@@ -217 +233 @@
-	register d1, d2;
+	register int d1, d2;
@@ -228 +244 @@
-	if (!isdigit(*s) && *s != '.')
+	if (!isdigit(*s&0377) && *s != '.')
@@ -230 +246 @@
-	if (isdigit(*s)) {
+	if (isdigit(*s&0377)) {
@@ -234 +250 @@
-		} while (isdigit(*s));
+		} while (isdigit(*s&0377));
@@ -242 +258 @@
-	if (isdigit(*s)) {
+	if (isdigit(*s&0377)) {
@@ -246 +262 @@
-		} while (isdigit(*s));
+		} while (isdigit(*s&0377));
@@ -248 +264 @@
-	if (!(d1 || point && d2))
+	if (!(d1 || (point && d2)))
@@ -254 +270 @@
-		if (!isdigit(*s))
+		if (!isdigit(*s&0377))
@@ -259 +275 @@
-		} while (isdigit(*s));
+		} while (isdigit(*s&0377));

% usr/src/cmd/awk/main.c
@@ -3,0 +4,2 @@
+int run(), error(), yyparse();
+void logit(), msgfiles(), syminit();
@@ -10 +12 @@
-extern	errorflag;	/* non-zero if any syntax errors; set by yyerror */
+extern int	errorflag;	/* non-zero if any syntax errors; set by yyerror */
@@ -14,0 +17 @@
+int
@@ -71 +74 @@
-		write(ansfd, &errorflag, sizeof(errorflag));
+		write(ansfd, (char *)&errorflag, sizeof(errorflag));
@@ -77 +80,2 @@
-logit(n, s) char *s[];
+void
+logit(n, s) int n; char *s[];
@@ -83,2 +87,2 @@
-	time(tvec);
-	fprintf(f, "%-8s %s", getlogin(), ctime(tvec));
+	time((long *)tvec);
+	fprintf(f, "%-8s %s", getlogin(), ctime((long *)tvec));
@@ -101,0 +106 @@
+int
@@ -106,0 +112 @@
+void
@@ -134 +140 @@
-	xargv=s=svargv=malloc(n*sizeof(char *));
+	xargv=s=svargv=(char **)malloc(n*sizeof(char *));

% usr/src/cmd/awk/parse.c
@@ -4 +4,2 @@
-node *ALLOC(n)
+int error();
+node *ALLOC(int n)
@@ -17,0 +19 @@
+int a;
@@ -24 +26 @@
-node *node1(a,b) node *b;
+node *node1(int a, node *b)
@@ -32 +34 @@
-node *node2(a,b,c) node *b, *c;
+node *node2(int a, node *b, node *c)
@@ -41 +43 @@
-node *node3(a,b,c,d) node *b, *c, *d;
+node *node3(int a, node *b, node *c, node *d)
@@ -51 +53 @@
-node *node4(a,b,c,d,e) node *b, *c, *d, *e;
+node *node4(int a, node *b, node *c, node *d, node *e)
@@ -62 +64 @@
-node *stat3(a,b,c,d) node *b, *c, *d;
+node *stat3(int a, node *b, node *c, node *d)
@@ -68 +70 @@
-node *op2(a,b,c) node *b, *c;
+node *op2(int a, node *b, node *c)
@@ -74 +76 @@
-node *op1(a,b) node *b;
+node *op1(int a, node *b)
@@ -80 +82 @@
-node *stat1(a,b) node *b;
+node *stat1(int a, node *b)
@@ -86 +88 @@
-node *op3(a,b,c,d) node *b, *c, *d;
+node *op3(int a, node *b, node *c, node *d)
@@ -92 +94 @@
-node *stat2(a,b,c) node *b, *c;
+node *stat2(int a, node *b, node *c)
@@ -98 +100 @@
-node *stat4(a,b,c,d,e) node *b, *c, *d, *e;
+node *stat4(int a, node *b, node *c, node *d, node *e)
@@ -104 +106 @@
-node *valtonode(a, b) cell *a;
+node *valtonode(cell *a, int b)
@@ -111 +113 @@
-node *genjump(a)
+node *genjump(int a)

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

% usr/src/cmd/awk/run.c
@@ -5,0 +6,2 @@
+int error(), fldbld(), getrec(), match();
+void tempfree(), redirprint(), freesymtab();
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
+void
@@ -232,0 +248 @@
+int n;
@@ -236,0 +253 @@
+	(void)n;
@@ -247,0 +265 @@
+int nnn;
@@ -251,0 +270 @@
+	(void)nnn;
@@ -286,0 +306 @@
+int nnn;
@@ -289,0 +310 @@
+	(void)nnn;
@@ -348 +369 @@
-		case 'o': case 'x':
+		case 'o': case 'x': case 'c':
@@ -381,0 +403 @@
+int n;
@@ -385,0 +408 @@
+	(void)n;
@@ -397,0 +421 @@
+int n;
@@ -399 +423 @@
-	awkfloat i,j;
+	awkfloat i,j=0;
@@ -413,0 +438 @@
+		/* fallthrough */
@@ -440,0 +466 @@
+int n;
@@ -461,0 +488 @@
+int n;
@@ -504,0 +532 @@
+int q;
@@ -508,0 +537 @@
+	(void)q;
@@ -526,0 +556 @@
+int n;
@@ -528,0 +559 @@
+	(void)n;
@@ -541,0 +573 @@
+int n;
@@ -562,0 +595 @@
+int n;
@@ -564,0 +598 @@
+	(void)n;
@@ -576,0 +611 @@
+int nnn;
@@ -583,0 +619 @@
+	(void)nnn;
@@ -612,2 +648,2 @@
-			  || sep == ' ' && (*p == '\t' || *p == '\n')
-			  || sep == '\t' && *p == '\n')
+			  || (sep == ' ' && (*p == '\t' || *p == '\n'))
+			  || (sep == '\t' && *p == '\n'))
@@ -629,0 +666 @@
+int n;
@@ -631,0 +669 @@
+	(void)n;
@@ -645,0 +684 @@
+int n;
@@ -647,0 +687 @@
+	(void)n;
@@ -664,0 +705 @@
+int n;
@@ -666,0 +708 @@
+	(void)n;
@@ -687,0 +730 @@
+int n;
@@ -691,0 +735 @@
+	(void)n;
@@ -712,0 +757 @@
+	return(true);
@@ -715,0 +761 @@
+int n;
@@ -717,0 +764 @@
+	(void)a;
@@ -740,0 +788 @@
+int n;
@@ -743 +791 @@
-	awkfloat u;
+	awkfloat u=0;
@@ -744,0 +793 @@
+	(void)n;
@@ -766,0 +816 @@
+int n;
@@ -770,0 +821 @@
+	(void)n;
@@ -792 +843 @@
-obj nullproc() {}
+obj nullproc() { return(true); }
@@ -805 +856,2 @@
-redirprint(s, a, b) char *s; node *b;
+void
+redirprint(s, a, b) char *s; int a; node *b;

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
@@ -82,0 +84 @@
+void
@@ -83,0 +86 @@
+int n;
@@ -87 +90 @@
-	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-257].tnm);
+	else	if(n<LASTTOKEN) printf("lex: %s\n",tok[n-FIRSTTOKEN].tnm);
@@ -92,0 +96 @@
+int n;
@@ -96 +100 @@
-	return(tok[n-257].tnm);
+	return(tok[n-FIRSTTOKEN].tnm);

% usr/src/cmd/awk/tran.c
@@ -18,0 +19,2 @@
+int error(), recbld(), hash(), isnumber();
+void checkval();
@@ -19,0 +22 @@
+void
@@ -42 +45 @@
-	cp = (char *) malloc(MAXSYM * sizeof(cell *));
+	cp = (cell **) malloc(MAXSYM * sizeof(cell *));
@@ -49,0 +53 @@
+void
@@ -63 +67 @@
-			free(cp);
+			free((char *)cp);
@@ -75 +79 @@
-	register h;
+	register int h;
@@ -99,0 +104 @@
+int
@@ -204,0 +210 @@
+void

% usr/src/cmd/basename.c
@@ -2,0 +3 @@
+int
@@ -3,0 +5 @@
+int	argc;

% usr/src/cmd/bc.y
@@ -2 +2 @@
-	int *getout();
+	void getout();
@@ -3,0 +4 @@
+%define api.value.type {char *}
@@ -19 +20,8 @@
-int in;
+#include <stdarg.h>
+#define bundle(...) (yyval = (bundle)(__VA_ARGS__))
+char *yyval;
+char *(bundle)(int i, ...);
+void output(), conout(), yyerror(), pp(), tp();
+char *getf(), *geta();
+int yylex(), cpeek(), getch();
+FILE *in;
@@ -33 +41 @@
-int *pre, *post;
+char *pre, *post;
@@ -38 +46 @@
-		= output( $2 );
+		{ output( $2 ); }
@@ -40 +48 @@
-		={	bundle( 6,pre, $7, post ,"0",numb[lev],"Q");
+		{	bundle( 6,pre, $7, post ,"0",numb[lev],"Q");
@@ -52,2 +60,2 @@
-stat	:  e 
-		={ bundle(2, $1, "ps." ); }
+stat	:  ex 
+		{ bundle(2, $1, "ps." ); }
@@ -55 +63 @@
-		={ bundle(1, "" ); }
+		{ bundle(1, "" ); }
@@ -57 +65 @@
-		={ bundle(3,"[",$1,"]P");}
+		{ bundle(3,"[",$1,"]P");}
@@ -59 +67 @@
-		={ bundle(3, $3, "s", $1 ); }
+		{ bundle(3, $3, "s", $1 ); }
@@ -61 +69 @@
-		={ bundle(4, $6, $3, ":", geta($1)); }
+		{ bundle(4, $6, $3, ":", geta($1)); }
@@ -63 +71 @@
-		={ bundle(6, "l", $1, $3, $2, "s", $1 ); }
+		{ bundle(6, "l", $1, $3, $2, "s", $1 ); }
@@ -65 +73 @@
-		={ bundle(8,$3, ";", geta($1), $6, $5, $3, ":", geta($1));}
+		{ bundle(8,$3, ";", geta($1), $6, $5, $3, ":", geta($1));}
@@ -67 +75 @@
-		={ bundle(2, numb[lev-bstack[bindx-1]], "Q" ); }
+		{ bundle(2, numb[lev-bstack[bindx-1]], "Q" ); }
@@ -69 +77 @@
-		= bundle(4, $3, post, numb[lev], "Q" );
+		{ bundle(4, $3, post, numb[lev], "Q" ); }
@@ -71 +79 @@
-		= bundle(4, "0", post, numb[lev], "Q" );
+		{ bundle(4, "0", post, numb[lev], "Q" ); }
@@ -73 +81 @@
-		= bundle(4,"0",post,numb[lev],"Q");
+		{ bundle(4,"0",post,numb[lev],"Q"); }
@@ -75 +83 @@
-		= bundle(2, $3, "k");
+		{ bundle(2, $3, "k"); }
@@ -77 +85 @@
-		= bundle(4,"K",$3,$2,"k");
+		{ bundle(4,"K",$3,$2,"k"); }
@@ -79 +87 @@
-		= bundle(2,$3, "i");
+		{ bundle(2,$3, "i"); }
@@ -81 +89 @@
-		= bundle(4,"I",$3,$2,"i");
+		{ bundle(4,"I",$3,$2,"i"); }
@@ -83 +91 @@
-		= bundle(2,$3,"o");
+		{ bundle(2,$3,"o"); }
@@ -85 +93 @@
-		= bundle(4,"O",$3,$2,"o");
+		{ bundle(4,"O",$3,$2,"o"); }
@@ -87 +95 @@
-		={ $$ = $2; }
+		{ $$ = $2; }
@@ -89 +97 @@
-		={ bundle(1,"fY"); }
+		{ bundle(1,"fY"); }
@@ -91 +99 @@
-		={ bundle(1,"c"); }
+		{ bundle(1,"c"); }
@@ -93 +101 @@
-		={	conout( $7, $2 );
+		{	conout( $7, $2 );
@@ -97 +105 @@
-		={	bundle(3, $6, $4, $2 );
+		{	bundle(3, $6, $4, $2 );
@@ -102 +110 @@
-		={	bundle(5, $7, $5, "s.", $3, $2 );
+		{	bundle(5, $7, $5, "s.", $3, $2 );
@@ -107 +115 @@
-		={	bundle(3,$4,"S",$2); }
+		{	bundle(3,$4,"S",$2); }
@@ -111 +119 @@
-		={ $$ = "+"; }
+		{ $$ = "+"; }
@@ -113 +121 @@
-		={ $$ = "-"; }
+		{ $$ = "-"; }
@@ -115 +123 @@
-		={ $$ = "*"; }
+		{ $$ = "*"; }
@@ -117 +125 @@
-		={ $$ = "/"; }
+		{ $$ = "/"; }
@@ -119 +127 @@
-		={ $$ = "%%"; }
+		{ $$ = "%%"; }
@@ -121 +129 @@
-		={ $$ = "^"; }
+		{ $$ = "^"; }
@@ -125 +133 @@
-		={ $$ = $3; }
+		{ $$ = $3; }
@@ -129 +137 @@
-		={ --bindx; }
+		{ --bindx; }
@@ -134 +142 @@
-		={ bundle(2, $1, $3 ); }
+		{ bundle(2, $1, $3 ); }
@@ -138 +146 @@
-		={ln++;}
+		{ln++;}
@@ -143 +151 @@
-		= bundle(3, $1, $3, "=" );
+		{ bundle(3, $1, $3, "=" ); }
@@ -145 +153 @@
-		= bundle(3, $1, $3, ">" );
+		{ bundle(3, $1, $3, ">" ); }
@@ -147 +155 @@
-		= bundle(3, $1, $3, "<" );
+		{ bundle(3, $1, $3, "<" ); }
@@ -149 +157 @@
-		= bundle(3, $1, $3, "!=" );
+		{ bundle(3, $1, $3, "!=" ); }
@@ -151 +159 @@
-		= bundle(3, $1, $3, "!>" );
+		{ bundle(3, $1, $3, "!>" ); }
@@ -153 +161 @@
-		= bundle(3, $1, $3, "!<" );
+		{ bundle(3, $1, $3, "!<" ); }
@@ -155 +163 @@
-		= bundle(2, $1, " 0!=" );
+		{ bundle(2, $1, " 0!=" ); }
@@ -158,2 +166,2 @@
-e	:  e '+' e
-		= bundle(3, $1, $3, "+" );
+ex	:  e '+' e
+		{ bundle(3, $1, $3, "+" ); }
@@ -161 +169 @@
-		= bundle(3, $1, $3, "-" );
+		{ bundle(3, $1, $3, "-" ); }
@@ -163 +171 @@
-		= bundle(3, " 0", $2, "-" );
+		{ bundle(3, " 0", $2, "-" ); }
@@ -165 +173 @@
-		= bundle(3, $1, $3, "*" );
+		{ bundle(3, $1, $3, "*" ); }
@@ -167 +175 @@
-		= bundle(3, $1, $3, "/" );
+		{ bundle(3, $1, $3, "/" ); }
@@ -169 +177 @@
-		= bundle(3, $1, $3, "%%" );
+		{ bundle(3, $1, $3, "%%" ); }
@@ -171 +179 @@
-		= bundle(3, $1, $3, "^" );
+		{ bundle(3, $1, $3, "^" ); }
@@ -173 +181 @@
-		={ bundle(3,$3, ";", geta($1)); }
+		{ bundle(3,$3, ";", geta($1)); }
@@ -175 +183 @@
-		= bundle(4, "l", $1, "d1+s", $1 );
+		{ bundle(4, "l", $1, "d1+s", $1 ); }
@@ -177 +185 @@
-		= bundle(4, "l", $2, "1+ds", $2 );
+		{ bundle(4, "l", $2, "1+ds", $2 ); }
@@ -179 +187 @@
-		= bundle(4, "l", $2, "1-ds", $2 );
+		{ bundle(4, "l", $2, "1-ds", $2 ); }
@@ -181 +189 @@
-		= bundle(4, "l", $1, "d1-s", $1 );
+		{ bundle(4, "l", $1, "d1-s", $1 ); }
@@ -183 +191 @@
-		= bundle(7,$3,";",geta($1),"d1+",$3,":",geta($1));
+		{ bundle(7,$3,";",geta($1),"d1+",$3,":",geta($1)); }
@@ -185 +193 @@
-		= bundle(7,$4,";",geta($2),"1+d",$4,":",geta($2));
+		{ bundle(7,$4,";",geta($2),"1+d",$4,":",geta($2)); }
@@ -187 +195 @@
-		= bundle(7,$3,";",geta($1),"d1-",$3,":",geta($1));
+		{ bundle(7,$3,";",geta($1),"d1-",$3,":",geta($1)); }
@@ -189 +197 @@
-		= bundle(7,$4,";",geta($2),"1-d",$4,":",geta($2));
+		{ bundle(7,$4,";",geta($2),"1-d",$4,":",geta($2)); }
@@ -191 +199 @@
-		= bundle(1,"Kd1+k");
+		{ bundle(1,"Kd1+k"); }
@@ -193 +201 @@
-		= bundle(1,"K1+dk");
+		{ bundle(1,"K1+dk"); }
@@ -195 +203 @@
-		= bundle(1,"Kd1-k");
+		{ bundle(1,"Kd1-k"); }
@@ -197 +205 @@
-		= bundle(1,"K1-dk");
+		{ bundle(1,"K1-dk"); }
@@ -199 +207 @@
-		= bundle(1,"Id1+i");
+		{ bundle(1,"Id1+i"); }
@@ -201 +209 @@
-		= bundle(1,"I1+di");
+		{ bundle(1,"I1+di"); }
@@ -203 +211 @@
-		= bundle(1,"Id1-i");
+		{ bundle(1,"Id1-i"); }
@@ -205 +213 @@
-		= bundle(1,"I1-di");
+		{ bundle(1,"I1-di"); }
@@ -207 +215 @@
-		= bundle(1,"Od1+o");
+		{ bundle(1,"Od1+o"); }
@@ -209 +217 @@
-		= bundle(1,"O1+do");
+		{ bundle(1,"O1+do"); }
@@ -211 +219 @@
-		= bundle(1,"Od1-o");
+		{ bundle(1,"Od1-o"); }
@@ -213 +221 @@
-		= bundle(1,"O1-do");
+		{ bundle(1,"O1-do"); }
@@ -215 +223 @@
-		= bundle(4, $3, "l", getf($1), "x" );
+		{ bundle(4, $3, "l", getf($1), "x" ); }
@@ -217 +225 @@
-		= bundle(3, "l", getf($1), "x" );
+		{ bundle(3, "l", getf($1), "x" ); }
@@ -219 +227 @@
-		={ bundle(2, " ", $1 ); }
+		{ bundle(2, " ", $1 ); }
@@ -221 +229 @@
-		={ bundle(2, " .", $2 ); }
+		{ bundle(2, " .", $2 ); }
@@ -223 +231 @@
-		={ bundle(4, " ", $1, ".", $3 ); }
+		{ bundle(4, " ", $1, ".", $3 ); }
@@ -225 +233 @@
-		={ bundle(3, " ", $1, "." ); }
+		{ bundle(3, " ", $1, "." ); }
@@ -227 +235 @@
-		={ $$ = "l."; }
+		{ $$ = "l."; }
@@ -229,9 +237 @@
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
@@ -239 +239 @@
-		= bundle(2,$3,"Z");
+		{ bundle(2,$3,"Z"); }
@@ -241 +241 @@
-		= bundle(2,$3,"X");	/* must be before '(' e ')' */
+		{ bundle(2,$3,"X"); }	/* must be before '(' e ')' */
@@ -243 +243 @@
-		= { $$ = $2; }
+		{ $$ = $2; }
@@ -245 +245 @@
-		={ bundle(1, "?" ); }
+		{ bundle(1, "?" ); }
@@ -247 +247 @@
-		={ bundle(2, $3, "v" ); }
+		{ bundle(2, $3, "v" ); }
@@ -249 +249,18 @@
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
@@ -251 +268 @@
-		= bundle(2,$3,"dk");
+		{ bundle(2,$3,"dk"); }
@@ -253 +270 @@
-		= bundle(4,"K",$3,$2,"dk");
+		{ bundle(4,"K",$3,$2,"dk"); }
@@ -255 +272 @@
-		= bundle(2,$3,"di");
+		{ bundle(2,$3,"di"); }
@@ -257 +274 @@
-		= bundle(4,"I",$3,$2,"di");
+		{ bundle(4,"I",$3,$2,"di"); }
@@ -259 +276 @@
-		= bundle(2,$3,"do");
+		{ bundle(2,$3,"do"); }
@@ -261,7 +278 @@
-		= bundle(4,"O",$3,$2,"do");
-	| SCALE
-		= bundle(1,"K");
-	| BASE
-		= bundle(1,"I");
-	| OBASE
-		= bundle(1,"O");
+		{ bundle(4,"O",$3,$2,"do"); }
@@ -272 +283 @@
-		= bundle(2, $1, $3 );
+		{ bundle(2, $1, $3 ); }
@@ -276 +287 @@
-		=bundle(2,"l",geta($1));
+		{ bundle(2,"l",geta($1)); }
@@ -280 +291 @@
-		={ *cp++ = '\0'; }
+		{ *cp++ = '\0'; }
@@ -284 +295 @@
-		={ $$ = cp; *cp++ = '_'; }
+		{ $$ = cp; *cp++ = '_'; }
@@ -286 +297 @@
-		={ $$ = cp; *cp++ = $1; }
+		{ $$ = cp; *cp++ = *$1; }
@@ -288 +299 @@
-		={ *cp++ = $2; }
+		{ *cp++ = *$2; }
@@ -292,2 +303,2 @@
-		={ $$ = cp; *cp++ = crs++; *cp++ = '\0';
-			if(crs == '[')crs=+3;
+		{ $$ = cp; *cp++ = crs++; *cp++ = '\0';
+			if(crs == '[')crs+=3;
@@ -302 +313 @@
-		={	$$ = getf($2);
+		{	$$ = getf($2);
@@ -312 +323 @@
-		={ pp( $1 ); }
+		{ pp( $1 ); }
@@ -314 +325 @@
-		={ pp( $3 ); }
+		{ pp( $3 ); }
@@ -318 +329 @@
-		={ tp($1); }
+		{ tp($1); }
@@ -320 +331 @@
-		={ tp($3); }
+		{ tp($3); }
@@ -324 +335 @@
-		={ $$ = geta($1); }
+		{ $$ = geta($1); }
@@ -347 +358 @@
-yylex(){
+int yylex(){
@@ -390,2 +401,2 @@
-	if( c>= '0' && c <= '9' || c>= 'A' && c<= 'F' ){
-		yylval = c;
+	if( (c>= '0' && c <= '9') || (c>= 'A' && c<= 'F') ){
+		yylval = index("0123456789ABCDEF", c);
@@ -434 +445 @@
-cpeek( c, yes, no ){
+int cpeek( int c, int yes, int no ){
@@ -442 +453 @@
-getch(){
+int getch(){
@@ -460,0 +472 @@
+	goto loop;
@@ -463,2 +475,2 @@
-int b_space [ b_sp_max ];
-int * b_sp_nxt = { b_space };
+char *b_space [ b_sp_max ];
+char ** b_sp_nxt = { b_space };
@@ -467,2 +479,3 @@
-bundle(a){
-	int i, *p, *q;
+char *(bundle)(int i, ...){
+	va_list p;
+	char **q;
@@ -470,2 +483 @@
-	p = &a;
-	i = *p++;
+	va_start(p, i);
@@ -473 +485 @@
-	if( bdebug ) printf("bundle %d elements at %o\n",i,  q );
+	if( bdebug ) printf("bundle %d elements at %o\n",i, (unsigned)q );
@@ -476 +488 @@
-		* b_sp_nxt++ = *p++;
+		* b_sp_nxt++ = va_arg(p, char *);
@@ -477,0 +490 @@
+	va_end(p);
@@ -479,2 +492,2 @@
-	yyval = q;
-	return( q );
+	yyval = (char *)q;
+	return( yyval );
@@ -483,3 +496,3 @@
-routput(p) int *p; {
-	if( bdebug ) printf("routput(%o)\n", p );
-	if( p >= &b_space[0] && p < &b_space[b_sp_max]){
+void routput(p) char *p; {
+	if( bdebug ) printf("routput(%o)\n", (unsigned)p );
+	if( (char **)p >= &b_space[0] && (char **)p < &b_space[b_sp_max]){
@@ -487 +500,2 @@
-		while( *p != 0 ) routput( *p++ );
+		char **q = (char **)p;
+		while( *q != 0 ) routput( *q++ );
@@ -492 +506 @@
-output( p ) int *p; {
+void output( p ) char *p; {
@@ -501 +515 @@
-conout( p, s ) int *p; char *s; {
+void conout( p, s ) char *p; char *s; {
@@ -509 +523 @@
-yyerror( s ) char *s; {
+void yyerror( s ) char *s; {
@@ -520 +534 @@
-pp( s ) char *s; {
+void pp( s ) char *s; {
@@ -529 +543 @@
-tp( s ) char *s; { /* same as pp, but for temps */
+void tp( s ) char *s; { /* same as pp, but for temps */
@@ -536 +550 @@
-yyinit(argc,argv) int argc; char *argv[];{
+void yyinit(argc,argv) int argc; char *argv[];{
@@ -547 +561 @@
-int *getout(){
+void getout(){
@@ -550 +564 @@
-	exit();
+	exit(0);
@@ -553 +567 @@
-int *
+char *
@@ -557 +571 @@
-int *
+char *
@@ -561,0 +576 @@
+int
@@ -562,0 +578 @@
+int argc;
@@ -572 +588 @@
-			exit();
+			exit(0);
@@ -577 +593 @@
-			exit();
+			exit(0);
@@ -589 +605 @@
-		exit();
+		exit(0);

% usr/src/cmd/cal.c
@@ -9,0 +10,4 @@
+#include <stdio.h>
+int number(), jan1();
+void pstr(), cal();
+int
@@ -10,0 +15 @@
+int argc;
@@ -13 +18 @@
-	register y, i, j;
+	register int y, i, j;
@@ -70,0 +76 @@
+int
@@ -74 +80 @@
-	register n, c;
+	register int n, c;
@@ -79 +85 @@
-	while(c = *s++) {
+	while((c = *s++)) {
@@ -86,0 +93 @@
+void
@@ -88,0 +96 @@
+int n;
@@ -90 +98 @@
-	register i;
+	register int i;
@@ -112,0 +121 @@
+void
@@ -113,0 +123 @@
+int m, y, w;
@@ -116 +126 @@
-	register d, i;
+	register int d, i;
@@ -172,0 +183 @@
+int
@@ -173,0 +185 @@
+int yr;
@@ -175 +187 @@
-	register y, d;
+	register int y, d;

% usr/src/cmd/calendar.c
@@ -7,0 +8 @@
+#include <stdio.h>
@@ -26,0 +28 @@
+void
@@ -35,0 +38 @@
+int
@@ -44,0 +48 @@
+		/* FALLTHROUGH */
@@ -47,0 +52 @@
+		/* FALLTHROUGH */

% usr/src/cmd/cat.c
@@ -10,0 +11 @@
+int
@@ -11,0 +13 @@
+int argc;
@@ -16,2 +18,2 @@
-	register c;
-	int dev, ino = -1;
+	register int c;
+	int dev = -1, ino = -1;
@@ -42 +44 @@
-		if (fflg || (*++argv)[0]=='-' && (*argv)[1]=='\0')
+		if (fflg || ((*++argv)[0]=='-' && (*argv)[1]=='\0'))

% usr/src/cmd/cb.c
@@ -1,0 +2,4 @@
+#define	puts	cb_puts
+#define	gets	cb_gets
+int	getch(), lookup(), getnl(), gets();
+void	ptabs(), comment(), puts(), gotelse();
@@ -39,2 +43,2 @@
-main(argc,argv) int argc;
-char argv[];
+int
+main()
@@ -155 +159 @@
-			if(iflev > 0)
+			if(iflev > 0) {
@@ -159,0 +164 @@
+			}
@@ -260,0 +266 @@
+void
@@ -264,0 +271 @@
+int
@@ -270,0 +278 @@
+void
@@ -291,0 +300 @@
+int
@@ -306,0 +316 @@
+int
@@ -324,0 +335 @@
+void
@@ -330,0 +342 @@
+int
@@ -351,0 +364 @@
+void

% usr/src/cmd/checkeq.c
@@ -8 +8,3 @@
-main(argc, argv) char **argv; {
+void check();
+int
+main(argc, argv) int argc; char **argv; {
@@ -32,0 +35 @@
+void

% usr/src/cmd/chgrp.c
@@ -14,0 +15 @@
+int	isnumber();
@@ -15,0 +17 @@
+int
@@ -16,0 +19 @@
+int argc;
@@ -19 +22 @@
-	register c;
+	register int c;
@@ -43,0 +47 @@
+int
@@ -47 +51 @@
-	register c;
+	register int c;
@@ -49 +53 @@
-	while(c = *s++)
+	while((c = *s++))

% usr/src/cmd/chmod.c
@@ -22,0 +23 @@
+int newmode(), abs(), who(), what(), where();
@@ -23,0 +25 @@
+int
@@ -24,0 +27 @@
+int argc;
@@ -27 +30 @@
-	register i;
+	register int i;
@@ -54,0 +58 @@
+int
@@ -58 +62 @@
-	register o, m, b;
+	register int o, m, b;
@@ -65 +69 @@
-		while (o = what()) {
+		while ((o = what())) {
@@ -87,0 +92 @@
+int
@@ -90 +95 @@
-	register c, i;
+	register int c, i;
@@ -98,0 +104 @@
+int
@@ -101 +107 @@
-	register m;
+	register int m;
@@ -124,0 +131 @@
+int
@@ -135,0 +143 @@
+int
@@ -137 +145 @@
-register om;
+register int om;
@@ -139 +147 @@
-	register m;
+	register int m;

% usr/src/cmd/chown.c
@@ -15,0 +16,2 @@
+int isnumber();
+int
@@ -16,0 +19 @@
+int argc;
@@ -19 +22 @@
-	register c;
+	register int c;
@@ -45,0 +49 @@
+int
@@ -49 +53 @@
-	register c;
+	register int c;
@@ -51 +55 @@
-	while(c = *s++)
+	while((c = *s++))

% usr/src/cmd/clri.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -16,0 +18,2 @@
+int isnumber();
+int
@@ -17,0 +21 @@
+int argc;
@@ -20 +24 @@
-	register i, f;
+	register int i, f;
@@ -22 +26,2 @@
-	int j, k;
+	int j;
+	unsigned k;
@@ -69,0 +75 @@
+int
@@ -73 +79 @@
-	register c;
+	register int c;
@@ -75 +81 @@
-	while(c = *s++)
+	while((c = *s++))

% usr/src/cmd/cmp.c
@@ -13,0 +14 @@
+int
@@ -14,0 +16 @@
+int	argc;
@@ -17 +19 @@
-	register c1, c2;
+	register int c1, c2;
@@ -96 +98 @@
-	exit(2);
+	return(2);
@@ -118 +120 @@
-	while(isdigit(*s))
+	while(isdigit(*s&0377))

% usr/src/cmd/col.c
@@ -19,0 +20 @@
+void outc(), store(), fetch(), emit(), incr(), decr();
@@ -20,0 +22 @@
+int
@@ -161,0 +164 @@
+void
@@ -207,0 +211 @@
+void
@@ -208,0 +213 @@
+int lno;
@@ -222,0 +228 @@
+void
@@ -223,0 +230 @@
+int lno;
@@ -235,0 +243 @@
+void
@@ -293,0 +302 @@
+void
@@ -307,0 +317 @@
+void

% usr/src/cmd/comm.c
@@ -11,0 +12,3 @@
+int rd(), compare();
+void wr(), copy();
+int
@@ -12,0 +16 @@
+int argc;
@@ -92,0 +97 @@
+int
@@ -111,0 +117 @@
+void
@@ -113,0 +120 @@
+	int n;
@@ -131,0 +139 @@
+void
@@ -132,0 +141 @@
+int n;
@@ -142,0 +152 @@
+int

% usr/src/cmd/cp.c
@@ -11,0 +12,2 @@
+int copy();
+int
@@ -12,0 +15 @@
+int	argc;
@@ -15 +18 @@
-	register i, r;
+	register int i, r;
@@ -33,0 +37 @@
+int
@@ -52 +56 @@
-		while(*bp++ = *p2++)
+		while((*bp++ = *p2++))
@@ -56 +60 @@
-		while(*bp = *p1++)
+		while((*bp = *p1++))
@@ -73 +77 @@
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
@@ -14,0 +15 @@
+void
@@ -67,0 +69 @@
+int
@@ -68,0 +71 @@
+int argc;
@@ -71 +74 @@
-	register i, n1, n2;
+	register int i, n1, n2;

% usr/src/cmd/date.c
@@ -9,0 +10 @@
+#include <stdio.h>
@@ -14,0 +16 @@
+int	gtime(), gp();
@@ -37,0 +40 @@
+int
@@ -38,0 +42 @@
+int argc;
@@ -93,0 +98 @@
+int
@@ -151,0 +157 @@
+int
@@ -152,0 +159 @@
+int dfault;

% usr/src/cmd/dc/dc.c
@@ -3,0 +4,5 @@
+void init(), commnds(), unreadc(), pushp(), sdump(), chsign(), binop(),
+    release(), print(), load(), seekc(), salterwd(), putwd(), more(),
+    garbage(), ospace(), redef(), tenot(), oneot();
+int readc(), subt(), eqk(), dscale(), log2(), command(), cond();
+int
@@ -10,0 +16 @@
+void
@@ -62 +68 @@
-			sunputc(p);
+			(void)sunputc(p);
@@ -395 +401 @@
-				for(n = 0;n < PTRSZ-1;n++)sputc(q,0);
+				for(n = 0;n < (int)PTRSZ-1;n++)sputc(q,0);
@@ -590 +596 @@
-		errorrt("divide by 0\n");
+		{printf("divide by 0\n"); return((struct blk *)1); }
@@ -696,0 +703 @@
+int
@@ -728,0 +736 @@
+int n;
@@ -860,0 +869 @@
+void
@@ -919,0 +929 @@
+void
@@ -929,0 +940 @@
+void
@@ -1077,0 +1089 @@
+void
@@ -1111,0 +1124 @@
+int
@@ -1132,0 +1146 @@
+	return(0);
@@ -1133,0 +1148 @@
+void
@@ -1143,0 +1159 @@
+void
@@ -1147 +1163 @@
-	register struct blk *r;
+	register struct blk *r = 0;
@@ -1165,0 +1182 @@
+void
@@ -1192 +1209 @@
-	sunputc(p);
+	(void)sunputc(p);
@@ -1248,0 +1266 @@
+int sc;
@@ -1277,0 +1296 @@
+void
@@ -1279,0 +1299 @@
+int sc;
@@ -1326,0 +1347 @@
+void
@@ -1328,0 +1350 @@
+int sc;
@@ -1345,0 +1368 @@
+void
@@ -1347,0 +1371 @@
+int flg;
@@ -1348,0 +1373 @@
+	(void)flg;
@@ -1364,0 +1390 @@
+void
@@ -1366,0 +1393 @@
+int flg;
@@ -1409 +1436 @@
-			sunputc(strptr);
+			(void)sunputc(strptr);
@@ -1462,0 +1490 @@
+int
@@ -1494,0 +1523 @@
+int n;
@@ -1525,0 +1555 @@
+int n;
@@ -1540,0 +1571 @@
+int
@@ -1551,0 +1583 @@
+int
@@ -1555 +1587 @@
-	register (*savint)(),pid,rpid;
+	register int (*savint)(),pid,rpid;
@@ -1580,0 +1613 @@
+int
@@ -1585 +1618 @@
-	register char cc;
+	register signed char cc;
@@ -1589 +1622 @@
-	sunputc(p);
+	(void)sunputc(p);
@@ -1615 +1648 @@
-		(cc >0) && (c == '>' || c == NL)){
+		((cc >0) && (c == '>' || c == NL))){
@@ -1621,0 +1655 @@
+void
@@ -1654,0 +1689 @@
+int
@@ -1740,0 +1776 @@
+void
@@ -1750,0 +1787 @@
+void
@@ -1752,0 +1790 @@
+int n;
@@ -1774,0 +1813 @@
+void
@@ -1783,0 +1823 @@
+void
@@ -1805,0 +1846 @@
+void
@@ -1814,0 +1856 @@
+void
@@ -1817,0 +1860 @@
+	(void)s;
@@ -1860,0 +1904 @@
+void
@@ -1864 +1908 @@
-	register offset;
+	register int offset;
@@ -1883,0 +1928 @@
+void
@@ -1905,0 +1951 @@
+void

% usr/src/cmd/dc/dc.h
@@ -22 +22 @@
-#ifdef interdata
+#ifndef pdp11
@@ -29 +29 @@
-#ifndef interdata
+#ifdef pdp11
@@ -106,2 +106,2 @@
-int	(*outdit)();
-int	bigot(),hexot();
+void	(*outdit)();
+void	bigot(),hexot();
@@ -113 +113 @@
-int	onintr();
+void	onintr();

% usr/src/cmd/dcheck.c
@@ -29,0 +30 @@
+void	check(), pass1(), pass2(), bread();
@@ -31,0 +33 @@
+int	l3tol();
@@ -32,0 +35 @@
+int
@@ -33,0 +37 @@
+int	argc;
@@ -36 +40 @@
-	register i;
+	register int i;
@@ -64,0 +69 @@
+void
@@ -68,2 +73,2 @@
-	register i;
-	register j;
+	register int i;
+	register int j;
@@ -91 +96 @@
-	for (i=0; i<=nfiles; i++)
+	for (i=0; i<=(int)nfiles; i++)
@@ -119,0 +125 @@
+void
@@ -126 +132 @@
-	register i, j;
+	register int i, j;
@@ -142 +148 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -166,0 +173 @@
+void
@@ -170 +177 @@
-	register i;
+	register int i;
@@ -186,0 +194 @@
+void
@@ -187,0 +196 @@
+int	cnt;
@@ -191 +200 @@
-	register i;
+	register int i;
@@ -203,0 +213 @@
+int	i;
@@ -210 +220 @@
-	if(i > NINDIR) {
+	if(i > (int)NINDIR) {

% usr/src/cmd/dd.c
@@ -21,0 +22,2 @@
+void	flsh(), null(), stats(), term();
+int	match(), number();
@@ -142,0 +145 @@
+int
@@ -147,4 +150,4 @@
-	int (*conv)();
-	register char *ip;
-	register c;
-	int ebcdic(), ibm(), ascii(), null(), cnull(), term();
+	void (*conv)();
+	register char *ip = 0;
+	register int c;
+	void ebcdic(), ibm(), ascii(), null(), cnull(), term();
@@ -344,0 +348 @@
+void
@@ -347 +351 @@
-	register c;
+	register int c;
@@ -361,0 +366 @@
+int
@@ -379,0 +385 @@
+int
@@ -380,0 +387 @@
+int big;
@@ -407,0 +415 @@
+		/* fallthrough */
@@ -418,0 +427 @@
+void
@@ -419,0 +429 @@
+int cc;
@@ -421 +431 @@
-	register c;
+	register int c;
@@ -430,0 +441 @@
+void
@@ -431,0 +443 @@
+int c;
@@ -441,0 +454 @@
+void
@@ -442,0 +456 @@
+int cc;
@@ -444 +458 @@
-	register c;
+	register int c;
@@ -468,0 +483 @@
+void
@@ -469,0 +485 @@
+int cc;
@@ -471 +487 @@
-	register c;
+	register int c;
@@ -497,0 +514 @@
+void
@@ -498,0 +516 @@
+int cc;
@@ -500 +518 @@
-	register c;
+	register int c;
@@ -526,0 +545 @@
+void
@@ -533,0 +553 @@
+void

% usr/src/cmd/deroff.c
@@ -33 +33 @@
-char chars[128];  /* SPECIAL, APOS, DIGIT, or LETTER */
+char chars[256];  /* SPECIAL, APOS, DIGIT, or LETTER */
@@ -51,0 +52,2 @@
+int skeqn(), eof();
+void getfname(), backsl(), fatal(), work(), regline(), putmac(), putwords(), comline(), macro(), tbl(), eqn();
@@ -54,0 +57 @@
+int
@@ -106,0 +110 @@
+int
@@ -112 +116 @@
-	else if(c == '"')
+	else if(c == '"') {
@@ -118,0 +123 @@
+	}
@@ -137,0 +143 @@
+int
@@ -157,0 +164 @@
+void
@@ -191,0 +199 @@
+void
@@ -199,0 +208 @@
+void
@@ -214,0 +224 @@
+void
@@ -242 +252 @@
-if(line[0] != '\0')
+if(line[0] != '\0') {
@@ -249,0 +260 @@
+}
@@ -253,0 +265 @@
+void
@@ -265 +277 @@
-	if(t>s+2 && chars[ s[0] ]==LETTER && chars[ s[1] ]==LETTER)
+	if(t>s+2 && chars[ s[0]&0377 ]==LETTER && chars[ s[1]&0377 ]==LETTER)
@@ -275,0 +288 @@
+void
@@ -286 +299 @@
-	while( chars[*p1] < DIGIT)
+	while( chars[*p1&0377] < DIGIT)
@@ -289 +302 @@
-	for(p = p1 ; (i=chars[*p]) != SPECIAL ; ++p)
+	for(p = p1 ; (i=chars[*p&0377]) != SPECIAL ; ++p)
@@ -293 +306 @@
-	   || (macline && nlet>2 && chars[ p1[0] ]==LETTER && chars[ p1[1] ]==LETTER) )
+	   || (macline && nlet>2 && chars[ p1[0]&0377 ]==LETTER && chars[ p1[1]&0377 ]==LETTER) )
@@ -307,0 +321 @@
+void
@@ -362,0 +377 @@
+void
@@ -367 +382 @@
-	while(C!='.' || C!='.' || C=='.');	/* look for  .. */
+	while(C!='.' || C!='.' || C=='.');	look for  .. */
@@ -374,0 +390 @@
+void
@@ -381,0 +398 @@
+void
@@ -424,0 +442 @@
+void
@@ -448,0 +467 @@
+		/* fallthrough */
@@ -491 +510 @@
-while( *t++ = *s++ )
+while( (*t++ = *s++) )

% usr/src/cmd/df.c
@@ -9,2 +9 @@
-	"/dev/rp0",
-	"/dev/rp3",
+	"/dev/root",
@@ -18,0 +18 @@
+void	dfree(), bread();
@@ -19,0 +20 @@
+int
@@ -20,0 +22 @@
+int argc;
@@ -34,0 +37 @@
+void
@@ -82,0 +86 @@
+void
@@ -85,0 +90 @@
+int cnt;
@@ -88 +93 @@
-	extern errno;
+	extern int errno;

% usr/src/cmd/diff.c
@@ -106,0 +107,3 @@
+void done(), noroom(), sort(), unsort(), filename(), prepare(), prune(), equiv(), unravel(), check(), output(), change(), range(), fetch(), mesg();
+int stone(), newcand(), search(), skipline(), readhash();
+char *talloc(), *ralloc();
@@ -108,0 +112 @@
+void
@@ -115,0 +120 @@
+int n;
@@ -122,0 +128 @@
+	return(NULL);
@@ -125,0 +132 @@
+int n;
@@ -138,0 +146 @@
+void
@@ -144,0 +153 @@
+void
@@ -145,0 +155 @@
+int n;
@@ -149 +159 @@
-	register int j,m;
+	register int j,m = 0;
@@ -163,2 +173,2 @@
-				   aim->value == ai[0].value &&
-				   aim->serial > ai[0].serial)
+				   (aim->value == ai[0].value &&
+				   aim->serial > ai[0].serial))
@@ -176,0 +187 @@
+void
@@ -177,0 +189 @@
+int l;
@@ -190,0 +203 @@
+void
@@ -202 +215 @@
-		while(*b1++ = *a1++) ;
+		while((*b1++ = *a1++)) ;
@@ -205 +218 @@
-		while(*a1++ = *a2++)
+		while((*a1++ = *a2++))
@@ -224,0 +238 @@
+void
@@ -225,0 +240 @@
+int i;
@@ -229 +244 @@
-	register j,h;
+	register int j,h;
@@ -235 +250 @@
-	for(j=0; h=readhash(input[i]);) {
+	for(j=0; (h=readhash(input[i]));) {
@@ -243,0 +259 @@
+void
@@ -246 +262 @@
-	register i,j;
+	register int i,j;
@@ -260,0 +277 @@
+void
@@ -261,0 +279 @@
+int n, m;
@@ -288,0 +307 @@
+int
@@ -289,0 +309 @@
+int argc;
@@ -357,0 +378 @@
+int
@@ -358,0 +380 @@
+int n;
@@ -398,0 +421 @@
+int
@@ -399,0 +423 @@
+int x, y, pred;
@@ -409,0 +434 @@
+int
@@ -410,0 +436 @@
+int k, y;
@@ -430,0 +457 @@
+void
@@ -431,0 +459 @@
+int p;
@@ -447,0 +476 @@
+void
@@ -454 +483 @@
-	char c,d;
+	int c,d;
@@ -511,0 +541 @@
+int
@@ -512,0 +543 @@
+int f;
@@ -514 +545 @@
-	register i;
+	register int i;
@@ -518,0 +550 @@
+void
@@ -550,0 +583 @@
+void
@@ -551,0 +585 @@
+int a, b, c, d;
@@ -571,0 +606 @@
+void
@@ -572,0 +608 @@
+int a, b;
@@ -580,0 +617 @@
+void
@@ -581,0 +619 @@
+int a, b;
@@ -601,0 +640 @@
+int
@@ -607,2 +646,2 @@
-	register space;
-	register t;
+	register int space;
+	register int t;
@@ -640,0 +680 @@
+void

% usr/src/cmd/diff3.c
@@ -44,0 +45,3 @@
+int readin(), number(), digit(), getchange(), getline(), skip(), duplicate(), edit();
+void merge(), separate(), change(), prange(), keep(), repos(), trouble(), edscript();
+int
@@ -45,0 +49 @@
+int argc;
@@ -48 +52 @@
-	register i,m,n;
+	register int i,m,n;
@@ -84,0 +89 @@
+int
@@ -89 +94 @@
-	register i;
+	register int i;
@@ -127,0 +133 @@
+int
@@ -131 +137 @@
-	register nn;
+	register int nn;
@@ -137,0 +144 @@
+int
@@ -138,0 +146 @@
+int c;
@@ -142,0 +151 @@
+int
@@ -151,0 +161 @@
+int
@@ -155,2 +165,2 @@
-	register i, c;
-	for(i=0;i<sizeof(line)-1;i++) {
+	register int i, c;
+	for(i=0;i<(int)sizeof(line)-1;i++) {
@@ -168,0 +179 @@
+void
@@ -169,0 +181 @@
+int m1, m2;
@@ -187 +199 @@
-		if(!t2||t1&&d1->new.to < d2->new.from) {
+		if(!t2||(t1&&d1->new.to < d2->new.from)) {
@@ -199 +211 @@
-		if(!t1||t2&&d2->new.to < d1->new.from) {
+		if(!t1||(t2&&d2->new.to < d1->new.from)) {
@@ -267,0 +280 @@
+void
@@ -277,0 +291 @@
+void
@@ -278,0 +293 @@
+int i, dup;
@@ -295,0 +311 @@
+void
@@ -313,0 +330 @@
+void
@@ -314,0 +332 @@
+int i;
@@ -317 +335,2 @@
-	register delta;
+	register int delta;
+	(void)rold;
@@ -328,0 +348 @@
+int
@@ -329,0 +350 @@
+int i, from;
@@ -332 +353 @@
-	register j,n;
+	register int j,n;
@@ -346,0 +368 @@
+int
@@ -350,2 +372,2 @@
-	register c,d;
-	register nchar;
+	register int c,d;
+	register int nchar;
@@ -367 +389 @@
-				return;
+				return(0);
@@ -374,0 +397 @@
+void
@@ -375,0 +399 @@
+int nchar;
@@ -377 +401 @@
-	register i;
+	register int i;
@@ -381,0 +406 @@
+void
@@ -389,0 +415 @@
+int
@@ -390,0 +417 @@
+int dup, j;
@@ -405,0 +433 @@
+void
@@ -406,0 +435 @@
+int n;
@@ -408 +437 @@
-	register j,k;
+	register int j,k;

% usr/src/cmd/diffh.c
@@ -17,0 +18,2 @@
+int	hardsynch(), easysynch(), output(), cmp();
+void	progerr(), movstr(), error(), change(), range();
@@ -20,0 +23 @@
+int f;
@@ -25 +28 @@
-	register delta, nt;
+	register int delta, nt;
@@ -42 +45 @@
-		if(t==NULL)
+		if(t==NULL) {
@@ -46,0 +50 @@
+		}
@@ -54,0 +59 @@
+void
@@ -55,0 +61 @@
+int f;
@@ -58 +64 @@
-	register i,j;
+	register int i,j;
@@ -65,0 +72 @@
+void
@@ -69 +76 @@
-	while(*t++= *s++)
+	while((*t++= *s++))
@@ -72,0 +80 @@
+int
@@ -73,0 +82 @@
+int argc;
@@ -103 +112 @@
-		return;
+		return(0);
@@ -110,0 +120 @@
+int
@@ -114 +124 @@
-	register k,m;
+	register int k,m;
@@ -142,0 +153 @@
+int
@@ -143,0 +155 @@
+int a, b;
@@ -145 +157 @@
-	register i;
+	register int i;
@@ -173,0 +186 @@
+void
@@ -174,0 +188 @@
+int b, d;
@@ -183,0 +198 @@
+void
@@ -184,0 +200 @@
+int b;
@@ -194,0 +211 @@
+int
@@ -201,3 +218,3 @@
-		if(bflag&&isspace(*s)&&isspace(*t)) {
-			while(isspace(*++s)) ;
-			while(isspace(*++t)) ;
+		if(bflag&&isspace(*s&0377)&&isspace(*t&0377)) {
+			while(isspace(*++s&0377)) ;
+			while(isspace(*++t&0377)) ;
@@ -219 +236 @@
-	if(cmp(f1,"-")==0)
+	if(cmp(f1,"-")==0) {
@@ -223,0 +241 @@
+	}
@@ -227 +245 @@
-		for(bptr=b;*bptr= *f1++;bptr++) ;
+		for(bptr=b;(*bptr= *f1++);bptr++) ;
@@ -232 +250 @@
-		while(*bptr++= *f2++) ;
+		while((*bptr++= *f2++)) ;
@@ -241,0 +260 @@
+void
@@ -247,0 +267 @@
+void
@@ -255,0 +276 @@
+int

% usr/src/cmd/dmesg.c
@@ -20,2 +20,2 @@
-	{"_msgbuf"},
-	{"_msgbufp"}
+	{"_msgbuf",0,0},
+	{"_msgbufp",0,0}
@@ -23,0 +24,2 @@
+void done(), pdate();
+int
@@ -24,0 +27 @@
+int argc;
@@ -83,0 +87 @@
+void
@@ -101,0 +106 @@
+void
@@ -105 +110 @@
-	static firstime;
+	static int firstime;

% usr/src/cmd/du.c
@@ -20,0 +21 @@
+int
@@ -21,0 +23 @@
+int argc;
@@ -24 +26 @@
-	register	i = 1;
+	register int	i = 1;
@@ -43 +45 @@
-		if(np = rindex(name, '/')) {
+		if((np = rindex(name, '/'))) {
@@ -81 +83 @@
-		static linked = 0;
+		static int linked = 0;

% usr/src/cmd/dump.c
@@ -52,0 +53,2 @@
+int	l3tol();
+void	pass(), icat(), indir(), bitmap(), spclrec(), bread(), CLR(), taprec(), flusht(), otape(), getitime(), putitime(), est(), bmapest();
@@ -57,0 +60 @@
+int
@@ -58,0 +62 @@
+int argc;
@@ -62 +66 @@
-	register i;
+	register int i;
@@ -174,0 +179 @@
+void
@@ -179,2 +184,2 @@
-	register i, j;
-	int bits;
+	register int i, j;
+	int bits = 0;
@@ -212,0 +218 @@
+void
@@ -217 +223 @@
-	register i;
+	register int i;
@@ -230,0 +237 @@
+void
@@ -233,0 +241 @@
+int n;
@@ -235 +243 @@
-	register i;
+	register int i;
@@ -242 +250 @@
-		for(i=0; i<NINDIR; i++) {
+		for(i=0; i<(int)NINDIR; i++) {
@@ -249 +257 @@
-		for(i=0; i<NINDIR; i++) {
+		for(i=0; i<(int)NINDIR; i++) {
@@ -256,0 +265 @@
+int
@@ -260 +269 @@
-	register f;
+	register int f;
@@ -264 +273 @@
-		return;
+		return(0);
@@ -272 +281 @@
-			return;
+			return(0);
@@ -274,0 +284 @@
+	return(0);
@@ -276,0 +287 @@
+int
@@ -282 +293 @@
-		return;
+		return(0);
@@ -293,0 +305 @@
+	return(0);
@@ -295,0 +308 @@
+int
@@ -299 +312 @@
-	register i;
+	register int i;
@@ -312 +325 @@
-		return;
+		return(0);
@@ -314,0 +328 @@
+	return(0);
@@ -316,0 +331 @@
+int
@@ -318,0 +334 @@
+int n;
@@ -320 +336 @@
-	register i, t;
+	register int i, t;
@@ -329,0 +346 @@
+	return(0);
@@ -331,0 +349 @@
+void
@@ -333,0 +352 @@
+int typ;
@@ -335 +354 @@
-	register i, n;
+	register int i, n;
@@ -353,0 +373 @@
+void
@@ -356 +376 @@
-	register i, *ip, s;
+	register int i, *ip, s;
@@ -363 +383 @@
-	for(i=0; i<BSIZE/sizeof(*ip); i++)
+	for(i=0; i<(int)(BSIZE/sizeof(*ip)); i++)
@@ -368,0 +389 @@
+int
@@ -373 +394 @@
-	register i;
+	register int i;
@@ -378 +399 @@
-		return;
+		return(0);
@@ -380 +401 @@
-	for(i=0; i<DIRPB; i++) {
+	for(i=0; i<(int)DIRPB; i++) {
@@ -393 +414 @@
-			return;
+			return(0);
@@ -397,0 +419 @@
+	return(0);
@@ -399,0 +422 @@
+int
@@ -401,0 +425 @@
+	return(0);
@@ -403,0 +428 @@
+void
@@ -406,0 +432 @@
+int c;
@@ -408 +434 @@
-	register n;
+	register int n;
@@ -415,0 +442 @@
+void
@@ -419 +446 @@
-	register n;
+	register int n;
@@ -431,0 +459 @@
+void
@@ -435 +463 @@
-	register i;
+	register int i;
@@ -445,0 +474 @@
+int
@@ -451 +480 @@
-		return;
+		return(0);
@@ -456,0 +486 @@
+	return(0);
@@ -458,0 +489 @@
+void
@@ -462 +493 @@
-	register i, si;
+	register int i, si;
@@ -492,0 +524 @@
+void
@@ -519,0 +552 @@
+void
@@ -522 +555 @@
-	register i, df;
+	register int i, df;
@@ -560,0 +594 @@
+void
@@ -563 +597 @@
-	register i, n, df;
+	register int i, n, df;
@@ -610,0 +645 @@
+void
@@ -625,0 +661 @@
+void
@@ -629 +665 @@
-	register i, n;
+	register int i, n;

% usr/src/cmd/dumpdir.c
@@ -50,0 +51,3 @@
+int	readhdr(), checkvol(), gethead(), checktype(), direq(), search(), readc(), checksum();
+void	pass1(), printem(), readbits(), flsh(), getfile(), putent(), mseek(), getent(), readtape(), clearbuf(), flsht(), copy(), writec();
+int
@@ -51,0 +55 @@
+int argc;
@@ -86 +90 @@
-	i = 0;
+int	i = 0;
@@ -90,0 +95 @@
+void
@@ -93 +98 @@
-	register i;
+	register int i;
@@ -126,0 +132 @@
+void
@@ -168,0 +175 @@
+void
@@ -174 +181 @@
-	register i;
+	register int i;
@@ -177,0 +185 @@
+	(void)n;
@@ -214,0 +223 @@
+void
@@ -218 +227 @@
-	register i;
+	register int i;
@@ -254,0 +264 @@
+void
@@ -259,0 +270 @@
+void
@@ -261,0 +273 @@
+int s;
@@ -263 +275 @@
-	register i;
+	register int i;
@@ -270,0 +283 @@
+void
@@ -274 +287 @@
-	register i;
+	register int i;
@@ -285,0 +299 @@
+void
@@ -289 +303 @@
-	register i;
+	register int i;
@@ -291 +305 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -300,0 +315 @@
+void
@@ -304 +319 @@
-	register i;
+	register int i;
@@ -306 +321 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -316,0 +332 @@
+void
@@ -323,0 +340 @@
+int
@@ -331,0 +349 @@
+void
@@ -337,0 +356 @@
+void
@@ -346,0 +366 @@
+int
@@ -350 +370 @@
-	register low, high, probe;
+	register int low, high, probe;
@@ -367,0 +388 @@
+int
@@ -371 +392 @@
-	register i;
+	register int i;
@@ -385,0 +407 @@
+int
@@ -397,0 +420 @@
+int
@@ -405,0 +429 @@
+int
@@ -409 +433 @@
-	register i, j;
+	register int i, j;
@@ -422,0 +447 @@
+int
@@ -431,0 +457 @@
+int
@@ -441,0 +468 @@
+int
@@ -446 +473 @@
-	register i;
+	register int i;
@@ -452,0 +480 @@
+	return(0);
@@ -457,0 +486 @@
+void
@@ -461 +490 @@
-	register i;
+	register int i;
@@ -473 +502 @@
-null() { ; }
+int null() { return(0); }

% usr/src/cmd/echo.c
@@ -2,0 +3 @@
+int

% usr/src/cmd/ed.c
@@ -7,0 +8,3 @@
+#define	puts	u_puts
+#include <stdio.h>
+#undef	puts
@@ -13,0 +17 @@
+#undef	EOF
@@ -100,0 +105,3 @@
+void	commands(), setdot(), setall(), setnoaddr(), nonzero(), newline(), filename(), exfile(), error(), dosub(), blkio(), callunix(), compile(), crblock(), delete(), global(), init(), join(), move(), putchr(), putd(), putfile(), reverse(), puts(), substitute(), rdelete(), makekey();
+int	advance(), append(), backref(), cclass(), compsub(), crinit(), execute(), getchr(), quit(), getkey(), putline();
+int
@@ -101,0 +109 @@
+int	argc;
@@ -141 +149 @@
-		while (*p2++ = *p1++)
+		while ((*p2++ = *p1++))
@@ -156,0 +165 @@
+void
@@ -160 +169 @@
-	register *a1, c;
+	register int *a1, c;
@@ -203,0 +213 @@
+		/* fallthrough */
@@ -265,0 +276 @@
+		/* fallthrough */
@@ -281,0 +293 @@
+		/* fallthrough */
@@ -285,0 +298 @@
+		/* fallthrough */
@@ -327,0 +341 @@
+		/* fallthrough */
@@ -377 +391 @@
-	register *a1, minus, c;
+	register int *a1, minus, c;
@@ -470,0 +485 @@
+void
@@ -478,0 +494 @@
+void
@@ -489,0 +506 @@
+void
@@ -495,0 +513 @@
+void
@@ -501,0 +520 @@
+void
@@ -504 +523 @@
-	register c;
+	register int c;
@@ -517,0 +537 @@
+void
@@ -518,0 +539 @@
+int	comm;
@@ -521 +542 @@
-	register c;
+	register int c;
@@ -530 +551 @@
-		while (*p2++ = *p1++)
+		while ((*p2++ = *p1++))
@@ -550 +571 @@
-		while (*p1++ = *p2++)
+		while ((*p1++ = *p2++))
@@ -554,0 +576 @@
+void
@@ -564,0 +587 @@
+int
@@ -570,0 +594 @@
+	return 0;
@@ -572,0 +597 @@
+int
@@ -585,0 +611 @@
+	return(0);
@@ -587,0 +614 @@
+void
@@ -591 +618 @@
-	register c;
+	register int c;
@@ -613,0 +641 @@
+int
@@ -617 +645 @@
-	if (lastc=peekc) {
+	if ((lastc=peekc)) {
@@ -632,0 +661 @@
+int
@@ -635 +664 @@
-	register c;
+	register int c;
@@ -658,0 +688 @@
+int
@@ -661 +691 @@
-	register c;
+	register int c;
@@ -694,0 +725 @@
+void
@@ -699 +730 @@
-	register nib;
+	register int nib;
@@ -733,0 +765 @@
+int
@@ -738 +770 @@
-	register *a1, *a2, *rdot;
+	register int *a1, *a2, *rdot;
@@ -744 +776 @@
-		if ((dol-zero)+1 >= nlall) {
+		if ((unsigned)((dol-zero)+1) >= nlall) {
@@ -767,0 +800 @@
+void
@@ -770 +803 @@
-	register (*savint)(), pid, rpid;
+	register int (*savint)(), pid, rpid;
@@ -786,0 +820 @@
+int
@@ -794,0 +829 @@
+	return(0);
@@ -796,0 +832 @@
+void
@@ -804,0 +841 @@
+void
@@ -808 +845 @@
-	register *a1, *a2, *a3;
+	register int *a1, *a2, *a3;
@@ -823,0 +861 @@
+void
@@ -826 +864 @@
-	register *a1, *a2, *a3;
+	register int *a1, *a2, *a3;
@@ -846,0 +885 @@
+int	tl;
@@ -849 +888 @@
-	register nl;
+	register int nl;
@@ -855 +894 @@
-	while (*lp++ = *bp++)
+	while ((*lp++ = *bp++))
@@ -862,0 +902 @@
+int
@@ -866 +906 @@
-	register nl;
+	register int nl;
@@ -875 +915 @@
-	while (*bp = *lp++) {
+	while ((*bp = *lp++)) {
@@ -892,0 +933 @@
+int	atl, iof;
@@ -894,2 +935 @@
-	extern read(), write();
-	register bno, off;
+	register int bno, off;
@@ -940,0 +981 @@
+void
@@ -941,0 +983 @@
+int	b;
@@ -950,0 +993 @@
+void
@@ -953 +996 @@
-	register *markp;
+	register int *markp;
@@ -972,0 +1016 @@
+void
@@ -973,0 +1018 @@
+int	k;
@@ -976 +1021 @@
-	register c;
+	register int c;
@@ -1024,0 +1070 @@
+void
@@ -1028 +1074 @@
-	register *a1;
+	register int *a1;
@@ -1033 +1079 @@
-		while (*gp = *lp++)
+		while ((*gp = *lp++))
@@ -1039 +1085 @@
-	while (*lp++ = *gp++)
+	while ((*lp++ = *gp++))
@@ -1046,0 +1093 @@
+void
@@ -1047,0 +1095 @@
+int	inglob;
@@ -1049 +1097 @@
-	register *markp, *a1, nl;
+	register int *markp, *a1, nl;
@@ -1085,0 +1134 @@
+int
@@ -1088 +1137 @@
-	register seof, c;
+	register int seof, c;
@@ -1120,0 +1170 @@
+int
@@ -1128 +1178 @@
-	while (*p1++ = *p2++)
+	while ((*p1++ = *p2++))
@@ -1133,0 +1184 @@
+void
@@ -1144 +1195 @@
-	while (c = *rp++&0377) {
+	while ((c = *rp++&0377)) {
@@ -1158 +1209 @@
-	while (*sp++ = *lp++)
+	while ((*sp++ = *lp++))
@@ -1163 +1214 @@
-	while (*lp++ = *sp++)
+	while ((*lp++ = *sp++))
@@ -1179,0 +1231 @@
+void
@@ -1180,0 +1233 @@
+int	cflag;
@@ -1222,0 +1276 @@
+void
@@ -1236,0 +1291 @@
+int
@@ -1244,0 +1300 @@
+void
@@ -1245,0 +1302 @@
+int	aeof;
@@ -1247 +1304 @@
-	register eof, c;
+	register int eof, c;
@@ -1373,0 +1431 @@
+int
@@ -1374,0 +1433 @@
+int	gf;
@@ -1380,2 +1439,2 @@
-		braslist[c] = 0;
-		braelist[c] = 0;
+		braslist[c&0377] = 0;
+		braelist[c&0377] = 0;
@@ -1388 +1447 @@
-		while (*p1++ = *p2++)
+		while ((*p1++ = *p2++))
@@ -1424,0 +1484 @@
+int
@@ -1467 +1527 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -1471 +1531 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -1531,0 +1592 @@
+int
@@ -1533 +1594 @@
-register i;
+register int i;
@@ -1544,0 +1606 @@
+int
@@ -1545,0 +1608 @@
+int	af;
@@ -1548 +1611 @@
-	register n;
+	register int n;
@@ -1558,0 +1622 @@
+void
@@ -1561 +1625 @@
-	register r;
+	register int r;
@@ -1569,0 +1634 @@
+void
@@ -1581,0 +1647 @@
+void
@@ -1582,0 +1649 @@
+int	ac;
@@ -1585 +1652 @@
-	register c;
+	register int c;
@@ -1624,0 +1692 @@
+void
@@ -1625,0 +1694 @@
+int	nchar;
@@ -1653,0 +1723 @@
+int
@@ -1660 +1730 @@
-	register c;
+	register int c;
@@ -1684,0 +1755 @@
+int
@@ -1689 +1760 @@
-	register i;
+	register int i;
@@ -1747,0 +1819 @@
+void

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
@@ -58 +59,3 @@
-int	fname;
+char	*fname;
+int	yylex(), nextch(), enter(), cclenter(), node(), unary(), cstate(), member(), notin();
+void	yyerror(), synerror(), overflo(), add(), follow(), execute();
@@ -63 +66 @@
-		={ unary(FINAL, $1);
+		{ unary(FINAL, $1);
@@ -68 +71 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -70 +73 @@
-		={ $$ = node(CAT, $2, $3); }
+		{ $$ = node(CAT, $2, $3); }
@@ -72 +75 @@
-		={ $$ = node(CAT, $2, $3); }
+		{ $$ = node(CAT, $2, $3); }
@@ -74 +77 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -77 +80 @@
-		={ $$ = enter(DOT);
+		{ $$ = enter(DOT);
@@ -81 +84 @@
-		={ $$ = enter($1); }
+		{ $$ = enter($1); }
@@ -83 +86 @@
-		={ $$ = enter(DOT); }
+		{ $$ = enter(DOT); }
@@ -85 +88 @@
-		={ $$ = cclenter(CCL); }
+		{ $$ = cclenter(CCL); }
@@ -87 +90 @@
-		={ $$ = cclenter(NCCL); }
+		{ $$ = cclenter(NCCL); }
@@ -91 +94 @@
-		={ $$ = node(OR, $1, $3); }
+		{ $$ = node(OR, $1, $3); }
@@ -93 +96 @@
-		={ $$ = node(CAT, $1, $2); }
+		{ $$ = node(CAT, $1, $2); }
@@ -95 +98 @@
-		={ $$ = unary(STAR, $1); }
+		{ $$ = unary(STAR, $1); }
@@ -97 +100 @@
-		={ $$ = unary(PLUS, $1); }
+		{ $$ = unary(PLUS, $1); }
@@ -99 +102 @@
-		={ $$ = unary(QUEST, $1); }
+		{ $$ = unary(QUEST, $1); }
@@ -101 +104 @@
-		={ $$ = $2; }
+		{ $$ = $2; }
@@ -106 +109,2 @@
-yyerror(s) {
+void
+yyerror(s) char *s; {
@@ -110,0 +115 @@
+int
@@ -114 +119 @@
-	register char c, d;
+	register int c, d;
@@ -156,0 +162 @@
+			goto defchar;
@@ -160,0 +167 @@
+int
@@ -162 +169 @@
-	register char c;
+	register int c;
@@ -166 +173 @@
-	else c = *input++;
+	else c = *input++ & 0377;
@@ -169,0 +177 @@
+void
@@ -174,0 +183 @@
+int
@@ -182,0 +192 @@
+int
@@ -184 +194 @@
-	register linno;
+	register int linno;
@@ -190 +200,2 @@
-node(x, l, r) {
+int
+node(x, l, r) int x, l, r; {
@@ -200 +211,2 @@
-unary(x, d) {
+int
+unary(x, d) int x, d; {
@@ -207,0 +220 @@
+void
@@ -213,2 +226,3 @@
-cfoll(v) {
-	register i;
+void
+cfoll(v) int v; {
+	register int i;
@@ -226,0 +241 @@
+void
@@ -228 +243 @@
-	register c, i, k;
+	register int c, i, k;
@@ -321,2 +336,3 @@
-cstate(v) {
-	register b;
+int
+cstate(v) int v; {
+	register int b;
@@ -347,2 +363,3 @@
-member(symb, set, torf) {
-	register i, num, pos;
+int
+member(symb, set, torf) int symb, set, torf; {
+	register int i, num, pos;
@@ -356,2 +373,3 @@
-notin(n) {
-	register i, j, pos;
+int
+notin(n) int n; {
+	register int i, j, pos;
@@ -371,2 +389,3 @@
-add(array, n) int *array; {
-	register i;
+void
+add(array, n) int *array, n; {
+	register int i;
@@ -382,0 +402 @@
+void
@@ -413,0 +434 @@
+int
@@ -414,0 +436 @@
+int	argc;
@@ -489,0 +512 @@
+void
@@ -494,2 +517,2 @@
-	register cstat;
-	register ccount;
+	register int cstat;
+	register int ccount;

% usr/src/cmd/expr.y
@@ -2,0 +3 @@
+%define api.value.type {char *}
@@ -15,0 +17,8 @@
+%{
+#include <stdio.h>
+#define index expr_index
+int yylex(), ematch(), advance(), ecmp();
+void errxx(), getrnge(), yyerror();
+char *compile();
+char *rel(), *arith(), *conj(), *substr(), *length(), *index(), *match();
+%}
@@ -20 +29 @@
-expression:	expr NOARG = {
+expression:	expr NOARG {
@@ -27,19 +36,19 @@
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
@@ -63 +72,2 @@
-main(argc, argv) char **argv; {
+int
+main(argc, argv) int argc; char **argv; {
@@ -75,0 +86 @@
+int
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
+char *rel(op, r1, r2) int op; register char *r1, *r2; {
+	register int i;
@@ -112 +123 @@
-char *arith(op, r1, r2) char *r1, *r2; {
+char *arith(op, r1, r2) int op; char *r1, *r2; {
@@ -132,2 +143,2 @@
-char *conj(op, r1, r2) char *r1, *r2; {
-	register char *rv;
+char *conj(op, r1, r2) int op; char *r1, *r2; {
+	register char *rv = 0;
@@ -163 +174 @@
-register si, wi;
+register int si, wi;
@@ -179 +190 @@
-	register i = 0;
+	register int i = 0;
@@ -190 +201 @@
-	register i, j;
+	register int i, j;
@@ -202,0 +214 @@
+char *s, *p;
@@ -218,2 +230,2 @@
-#define RETURN(c)	return
-#define ERROR(c)	errxx(c)
+#define RETURN(c)	return(c)
+#define ERROR(c)	do { errxx(c); return(0); } while (0)
@@ -221,0 +234 @@
+int
@@ -228 +241 @@
-	register num;
+	register int num;
@@ -231 +244 @@
-	compile(p, expbuf, &expbuf[512], 0);
+	compile(p, expbuf, &expbuf[ESIZE], 0);
@@ -245,0 +259 @@
+void
@@ -246,0 +261 @@
+int c;
@@ -247,0 +263 @@
+	(void)c;
@@ -292,0 +309 @@
+int seof;
@@ -295,2 +312,2 @@
-	register c;
-	register eof = seof;
+	register int c;
+	register int eof = seof;
@@ -457 +474 @@
-			/* Drop through to default to use \ to turn off special chars */
+			/* fallthrough - to default to use \ to turn off special chars */
@@ -467,0 +485 @@
+int
@@ -471 +489 @@
-	register c;
+	register int c;
@@ -499,0 +518 @@
+int
@@ -537 +556 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -541 +560 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -592,2 +611,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[*ep&0377];
+		ct = braelist[*ep++&0377] - bbeg;
@@ -602,2 +621,2 @@
-		bbeg = braslist[*ep];
-		ct = braelist[*ep++] - bbeg;
+		bbeg = braslist[*ep&0377];
+		ct = braelist[*ep++&0377] - bbeg;
@@ -645,0 +665 @@
+void
@@ -650 +670 @@
-	size = *str == 255 ? 20000 : (*str &0377) - low;
+	size = (*str & 0377) == 255 ? 20000 : (*str &0377) - low;
@@ -652,0 +673 @@
+int
@@ -655 +676 @@
-register	count;
+register int	count;
@@ -663,0 +685 @@
+void
@@ -665 +687 @@
-
+char *s;

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
+#define	BIG	72057594037927936LL
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
+int
+getch()
+{
+	int c;
@@ -311,41 +18,58 @@
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
+void
+put(d)
+long long d;
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
+main(argc, argv)
+int argc;
+char **argv;
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
@@ -32,0 +33,2 @@
+int getargc(); void execute(), cgotofn(), overflo(), cfail();
+int
@@ -33,0 +36 @@
+int argc;
@@ -111,0 +115 @@
+void
@@ -117 +121 @@
-	register ccount;
+	register int ccount;
@@ -208 +212 @@
-		if (*p++ == '\n')
+		if (*p++ == '\n') {
@@ -215,0 +220 @@
+		}
@@ -224,0 +230 @@
+int
@@ -227 +233 @@
-	register c;
+	register int c;
@@ -234,0 +241 @@
+void
@@ -236 +243 @@
-	register c;
+	register int c;
@@ -297,0 +305 @@
+void
@@ -301,0 +310 @@
+void

% usr/src/cmd/file.c
@@ -22,0 +23,3 @@
+void type();
+int ccom(), ascom(), english(), lookup();
+int
@@ -23,0 +27 @@
+int argc;
@@ -55,0 +60 @@
+void
@@ -103,0 +109 @@
+		/* fallthrough */
@@ -143 +149 @@
-		if(buf[i] <= 0)
+		if(buf[i] == 0 || buf[i] & 0200)
@@ -184 +190 @@
-		else if(buf[j] == '\n' && isalpha(buf[j+2])){
+		else if(buf[j] == '\n' && isalpha(buf[j+2]&0377)){
@@ -201 +207 @@
-			else if(buf[j] == '\n' && isalpha(buf[j+2])){
+			else if(buf[j] == '\n' && isalpha(buf[j+2]&0377)){
@@ -238 +244 @@
-		/*.... */
+		.... */
@@ -241,0 +248 @@
+int
@@ -259,0 +267 @@
+int
@@ -274,0 +283 @@
+int
@@ -283,0 +293 @@
+int
@@ -285,0 +296 @@
+int n;
@@ -295 +306 @@
-		if (bp[j]<NASC)
+		if ((bp[j]&0377)<NASC)

% usr/src/cmd/find.c
@@ -2,0 +3 @@
+#define	ctime	find_ctime
@@ -42,0 +44,3 @@
+void	pr(), bwrite();
+int	descend(), cpio(), getunum(), gmatch(), scomp(), doex(), chgreel(), amatch(), umatch();
+int
@@ -43,0 +48 @@
+int	argc;
@@ -48,0 +54 @@
+	int pclose();
@@ -77 +83 @@
-		if(cp = rindex(Pathname, '/')) {
+		if((cp = rindex(Pathname, '/'))) {
@@ -166 +172 @@
-		return(mk(mtime, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(mtime, (struct anode *)atoi(b), (struct anode *)(int)s));
@@ -168 +174 @@
-		return(mk(atime, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(atime, (struct anode *)atoi(b), (struct anode *)(int)s));
@@ -170 +176 @@
-		return(mk(ctime, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(ctime, (struct anode *)atoi(b), (struct anode *)(int)s));
@@ -176 +182 @@
-				return mk(user, (struct anode *)atoi(b), (struct anode *)s);
+				return mk(user, (struct anode *)atoi(b), (struct anode *)(int)s);
@@ -180 +186 @@
-		return(mk(user, (struct anode *)i, (struct anode *)s));
+		return(mk(user, (struct anode *)i, (struct anode *)(int)s));
@@ -183 +189 @@
-		return(mk(ino, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(ino, (struct anode *)atoi(b), (struct anode *)(int)s));
@@ -189 +195 @@
-				return mk(group, (struct anode *)atoi(b), (struct anode *)s);
+				return mk(group, (struct anode *)atoi(b), (struct anode *)(int)s);
@@ -193 +199 @@
-		return(mk(group, (struct anode *)i, (struct anode *)s));
+		return(mk(group, (struct anode *)i, (struct anode *)(int)s));
@@ -195 +201 @@
-		return(mk(size, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(size, (struct anode *)atoi(b), (struct anode *)(int)s));
@@ -197 +203 @@
-		return(mk(links, (struct anode *)atoi(b), (struct anode *)s));
+		return(mk(links, (struct anode *)atoi(b), (struct anode *)(int)s));
@@ -204 +210 @@
-		return(mk(perm, (struct anode *)i, (struct anode *)s));
+		return(mk(perm, (struct anode *)i, (struct anode *)(int)s));
@@ -226 +232 @@
-			pr("find: cannot create "), pr(s), pr("\n");
+			pr("find: cannot create "), pr(b), pr("\n");
@@ -242,0 +249 @@
+	return(0);
@@ -255 +262 @@
-	static strikes = 0;
+	static int strikes = 0;
@@ -269,0 +277 @@
+int
@@ -274,0 +283 @@
+int
@@ -279,0 +289 @@
+int
@@ -284,0 +295 @@
+int
@@ -289,0 +301 @@
+int
@@ -294,0 +307 @@
+int
@@ -299,0 +313 @@
+int
@@ -304,0 +319 @@
+int
@@ -309,0 +325 @@
+int
@@ -314,0 +331 @@
+int
@@ -319,0 +337 @@
+int
@@ -324,0 +343 @@
+int
@@ -329,0 +349 @@
+int
@@ -334,0 +355 @@
+int
@@ -338 +359 @@
-	register i;
+	register int i;
@@ -341,0 +363 @@
+int
@@ -346,0 +369 @@
+int
@@ -352,0 +376 @@
+int
@@ -382,0 +407 @@
+int
@@ -400 +425 @@
-	register ifile, ct;
+	register int ifile, ct;
@@ -402 +427 @@
-	register i;
+	register int i;
@@ -421 +446 @@
-		return;
+		return(0);
@@ -425 +450 @@
-		return;
+		return(0);
@@ -430 +455 @@
-		return;
+		return(0);
@@ -440 +465 @@
-	return;
+	return(0);
@@ -441,0 +467 @@
+int
@@ -447,0 +474 @@
+int
@@ -449 +476 @@
-register a, b;
+register int a, b;
@@ -458,0 +486 @@
+int
@@ -459,0 +488 @@
+int	com;
@@ -461 +490 @@
-	register np;
+	register int np;
@@ -464 +493 @@
-	static ccode;
+	static int ccode;
@@ -467 +496 @@
-	while (na=Argv[com++]) {
+	while ((na=Argv[com++])) {
@@ -477 +506 @@
-		execvp(nargv[0], nargv, np);
+		execvp(nargv[0], nargv);
@@ -482,0 +512 @@
+int
@@ -484 +514 @@
-	register i;
+	register int i;
@@ -486 +516 @@
-	register c;
+	register int c;
@@ -491,0 +522,2 @@
+	if(pin == NULL)
+		return(i);
@@ -514,0 +547 @@
+int
@@ -611,0 +645 @@
+int
@@ -618,0 +653 @@
+int
@@ -622 +657 @@
-	register cc;
+	register int cc;
@@ -632 +667 @@
-		while (cc = *++p) {
+		while ((cc = *++p)) {
@@ -642 +677 @@
-				k |= lc <= scc & scc <= (cc=p[1]);
+				k |= (lc <= scc) & (scc <= (cc=p[1]));
@@ -660,0 +696 @@
+int
@@ -669,0 +706 @@
+void
@@ -672 +709 @@
-register c;
+register int c;
@@ -692,0 +730 @@
+int
@@ -693,0 +732,2 @@
+int	fl;
+int	x;
@@ -695 +735 @@
-	register f;
+	register int f;
@@ -718,0 +759 @@
+void

% usr/src/cmd/getty.c
@@ -7,0 +8,3 @@
+int read(), write(), ioctl(), stty(), getname();
+int execl(char *path, char *arg0, ...);
+void exit(), puts(), putchr();
@@ -26 +29 @@
-	'0', 1,
+	{ '0', 1,
@@ -29 +32 @@
-	"\n\r\033;\007login: ",
+	"\n\r\033;\007login: " },
@@ -31 +34 @@
-	1, 2,
+	{ 1, 2,
@@ -34 +37 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -36 +39 @@
-	2, 3,
+	{ 2, 3,
@@ -39 +42 @@
-	"\n\r\033:\006\006\017login: ",
+	"\n\r\033:\006\006\017login: " },
@@ -41 +44 @@
-	3, '0',
+	{ 3, '0',
@@ -44 +47 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -47 +50 @@
-	'-', '-',
+	{ '-', '-',
@@ -50 +53 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -53 +56 @@
-	'1', '1',
+	{ '1', '1',
@@ -56 +59 @@
-	"\n\r\033:\006\006\017login: ",
+	"\n\r\033:\006\006\017login: " },
@@ -59 +62 @@
-	'2', '2',
+	{ '2', '2',
@@ -62 +65 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -65 +68 @@
-	'3', '5',
+	{ '3', '5',
@@ -68 +71 @@
-	"\n\r\033;login: ",
+	"\n\r\033;login: " },
@@ -71 +74 @@
-	'5', '3',
+	{ '5', '3',
@@ -74 +77 @@
-	"\n\r\033;\007login: ",
+	"\n\r\033;\007login: " },
@@ -77 +80 @@
-	'4', '4',
+	{ '4', '4',
@@ -80 +83 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -83 +86 @@
-	'i', 'i',
+	{ 'i', 'i',
@@ -86 +89 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -89 +92 @@
-	'l', 'l',
+	{ 'l', 'l',
@@ -92 +95 @@
-	"*",
+	"*" },
@@ -94 +97 @@
-	'6', '6',
+	{ '6', '6',
@@ -97 +100 @@
-	"\n\rlogin: ",
+	"\n\rlogin: " },
@@ -127,0 +131 @@
+int
@@ -128,0 +133 @@
+int argc;
@@ -177,0 +183 @@
+int
@@ -181 +187 @@
-	register c;
+	register int c;
@@ -221,0 +228 @@
+void
@@ -231,0 +239 @@
+void
@@ -232,0 +241 @@
+int cc;

% usr/src/cmd/graph.c
@@ -43,0 +44,4 @@
+int	numb(), copystring(), setmark(), conv(), getfloat(), getstring(), symbol();
+void	init(), setopt(), limread(), readin(), transpose(), scale(), axes(), submark(), plot(), title(), axlab(), badarg();
+void	space(), erase(), move(), cont(), line(), point(), label(), linemod(), closevt();
+int	scanf(char *, ...);
@@ -65,0 +70 @@
+int
@@ -66,0 +72 @@
+int argc;
@@ -91,0 +98 @@
+void
@@ -98,0 +106 @@
+void
@@ -100,0 +109 @@
+int argc;
@@ -119 +128 @@
-				while (*p1++ = *p2++);
+				while ((*p1++ = *p2++));
@@ -197,0 +207 @@
+void
@@ -218,0 +229 @@
+int
@@ -230 +241 @@
-	if(!(isdigit(c) || c=='-'&&(*argvp)[1][1]<'A' || c=='.'))
+	if(!(isdigit(c&0377) || (c=='-'&&(*argvp)[1][1]<'A') || c=='.'))
@@ -237,0 +249 @@
+void
@@ -240 +252 @@
-	register t;
+	register int t;
@@ -271,0 +284 @@
+void
@@ -274 +287 @@
-	register i;
+	register int i;
@@ -284,0 +298 @@
+int
@@ -285,0 +300 @@
+int k;
@@ -288 +303 @@
-	register i;
+	register int i;
@@ -317,0 +333 @@
+void
@@ -322 +338 @@
-	register i;
+	register int i;
@@ -337,0 +354 @@
+void
@@ -407,0 +425 @@
+int lbf,ubf;
@@ -481,0 +500 @@
+void
@@ -496,0 +516 @@
+void
@@ -499 +519 @@
-	register i;
+	register int i;
@@ -529,0 +550 @@
+int
@@ -559,0 +581 @@
+void
@@ -569,0 +592 @@
+void
@@ -596,0 +620 @@
+int
@@ -609,0 +634 @@
+int
@@ -613 +638 @@
-	register i;
+	register int i;
@@ -618,0 +644 @@
+int
@@ -621 +647 @@
-	register i;
+	register int i;
@@ -628 +654 @@
-		if(!isdigit(*labbuf)) {
+		if(!isdigit(*labbuf&0377)) {
@@ -632,0 +659 @@
+		/* fallthrough */
@@ -648,0 +676 @@
+int
@@ -649,0 +678 @@
+int ix,iy,k;
@@ -661 +690 @@
-		return(!brkf|k<0);
+		return(!brkf|(k<0));
@@ -664,0 +694 @@
+void
@@ -678,0 +709 @@
+void
@@ -688,0 +720 @@
+void
@@ -692,0 +725,71 @@
+}
+void
+putsi(a)
+int a;{
+	putc((char)a,stdout);
+	putc((char)(a>>8),stdout);
+}
+void
+space(x0,y0,x1,y1)
+int x0,y0,x1,y1;{
+	putc('s',stdout);
+	putsi(x0);
+	putsi(y0);
+	putsi(x1);
+	putsi(y1);
+}
+void
+erase(){
+	putc('e',stdout);
+}
+void
+move(xi,yi)
+int xi,yi;{
+	putc('m',stdout);
+	putsi(xi);
+	putsi(yi);
+}
+void
+cont(xi,yi)
+int xi,yi;{
+	putc('n',stdout);
+	putsi(xi);
+	putsi(yi);
+}
+void
+line(x0,y0,x1,y1)
+int x0,y0,x1,y1;{
+	putc('l',stdout);
+	putsi(x0);
+	putsi(y0);
+	putsi(x1);
+	putsi(y1);
+}
+void
+point(xi,yi)
+int xi,yi;{
+	putc('p',stdout);
+	putsi(xi);
+	putsi(yi);
+}
+void
+label(s)
+char *s;
+{
+	int i;
+	putc('t',stdout);
+	for(i=0;s[i];)putc(s[i++],stdout);
+	putc('\n',stdout);
+}
+void
+linemod(s)
+char *s;
+{
+	int i;
+	putc('f',stdout);
+	for(i=0;s[i];)putc(s[i++],stdout);
+	putc('\n',stdout);
+}
+void
+closevt(){
+	fflush(stdout);

% usr/src/cmd/grep.c
@@ -58,0 +59,3 @@
+void	compile(), execute(), succeed(), errexit();
+int	advance(), ecmp();
+int
@@ -59,0 +63 @@
+int	argc;
@@ -119 +123 @@
-			} else if (islower(*p)) {
+			} else if (islower(*p&0377)) {
@@ -144,0 +149 @@
+void
@@ -148 +153 @@
-	register c;
+	register int c;
@@ -208 +213 @@
-					for (c = sp[-2]; c<*sp; c++)
+					for (c = sp[-2]&0177; c<(*sp&0177); c++)
@@ -212 +217 @@
-				ep[c>>3] |= bittab[c&07];
+				ep[(c&0177)>>3] |= bittab[c&07];
@@ -250,0 +256 @@
+			goto defchar;
@@ -261,0 +268 @@
+void
@@ -266 +273 @@
-	register c;
+	register int c;
@@ -323,0 +331 @@
+int
@@ -360 +368 @@
-		braslist[*ep++] = lp;
+		braslist[*ep++&0377] = lp;
@@ -364 +372 @@
-		braelist[*ep++] = lp;
+		braelist[*ep++&0377] = lp;
@@ -368,2 +376,2 @@
-		bbeg = braslist[*ep];
-		if (braelist[*ep]==0)
+		bbeg = braslist[*ep&0377];
+		if (braelist[*ep&0377]==0)
@@ -371 +379 @@
-		ct = braelist[*ep++] - bbeg;
+		ct = braelist[*ep++&0377] - bbeg;
@@ -379,2 +387,2 @@
-		bbeg = braslist[*ep];
-		if (braelist[*ep]==0)
+		bbeg = braslist[*ep&0377];
+		if (braelist[*ep&0377]==0)
@@ -382 +390 @@
-		ct = braelist[*ep++] - bbeg;
+		ct = braelist[*ep++&0377] - bbeg;
@@ -438,0 +447 @@
+void
@@ -463,0 +473 @@
+int
@@ -464,0 +475 @@
+int	count;
@@ -467 +478 @@
-	register cc = count;
+	register int cc = count;
@@ -472,0 +484 @@
+void

% usr/src/cmd/icheck.c
@@ -42,0 +43 @@
+int	l3tol(), chk(), duped(); void check(), pass1(), bread(), bwrite(), makefree();
@@ -46,0 +48 @@
+int
@@ -47,0 +50 @@
+int argc;
@@ -50 +53 @@
-	register i;
+	register int i;
@@ -100,0 +104 @@
+void
@@ -104 +108 @@
-	register i, j;
+	register int i, j;
@@ -134 +138 @@
-	if (n != (unsigned)n) {
+	if (n != (long)(unsigned)n) {
@@ -149 +153 @@
-	for(i=0; i<(unsigned)n; i++)
+	for(i=0; i<(int)(unsigned)n; i++)
@@ -177 +181 @@
-	while(n = alloc()) {
+	while((n = alloc())) {
@@ -217,0 +222 @@
+void
@@ -224 +229 @@
-	register i, j;
+	register int i, j;
@@ -261 +266 @@
-		for(j=0; j<NINDIR; j++) {
+		for(j=0; j<(int)NINDIR; j++) {
@@ -273 +278 @@
-			for(k=0; k<NINDIR; k++) {
+			for(k=0; k<(int)NINDIR; k++) {
@@ -285 +290 @@
-				for(l=0; l<NINDIR; l++)
+				for(l=0; l<(int)NINDIR; l++)
@@ -294,0 +300 @@
+int
@@ -299 +305 @@
-	register n;
+	register int n;
@@ -314,0 +321 @@
+int
@@ -319 +326 @@
-	register m, n;
+	register int m, n;
@@ -355 +362 @@
-		sblock.s_nfree = buf.df_nfree;
+		sblock.s_nfree = buf.fb.df_nfree;
@@ -363 +370 @@
-			sblock.s_free[i] = buf.df_free[i];
+			sblock.s_free[i] = buf.fb.df_free[i];
@@ -367,0 +375 @@
+void
@@ -381 +389 @@
-		buf.df_nfree = sblock.s_nfree;
+		buf.fb.df_nfree = sblock.s_nfree;
@@ -383 +391 @@
-			buf.df_free[i] = sblock.s_free[i];
+			buf.fb.df_free[i] = sblock.s_free[i];
@@ -390,0 +399 @@
+void
@@ -393,0 +403 @@
+int cnt;
@@ -395 +405 @@
-	register i;
+	register int i;
@@ -408,0 +419 @@
+void
@@ -418,0 +430 @@
+void
@@ -423 +435 @@
-	register i, j;
+	register int i, j;

% usr/src/cmd/init.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -36,0 +38,2 @@
+void	shutdown(), single(), runcom(), merge(), multiple(), term(), maktty(), dfork(), rmut(), reset();
+int	rline(), get();
@@ -37,0 +41 @@
+int
@@ -40 +43,0 @@
-	int reset();
@@ -52,0 +56 @@
+void
@@ -55 +59 @@
-	register i;
+	register int i;
@@ -72,0 +77 @@
+void
@@ -75 +80 @@
-	register pid;
+	register int pid;
@@ -94,0 +100 @@
+void
@@ -97 +103 @@
-	register pid;
+	register int pid;
@@ -110,0 +117 @@
+void
@@ -114 +121 @@
-	register pid;
+	register int pid;
@@ -127,0 +135 @@
+void
@@ -139,0 +148 @@
+int
@@ -142 +151 @@
-	register c, i;
+	register int c, i;
@@ -173,0 +183 @@
+void
@@ -177 +187 @@
-	register i, j;
+	register int i, j;
@@ -187,0 +198 @@
+int
@@ -198,0 +210 @@
+void
@@ -202 +214 @@
-	register i;
+	register int i;
@@ -242,0 +255 @@
+void
@@ -246 +259 @@
-	register pid;
+	register int pid;
@@ -265,0 +279 @@
+void
@@ -269 +283 @@
-	register i, f;
+	register int i, f;
@@ -298,0 +313 @@
+void

% usr/src/cmd/iostat.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -13,3 +14,8 @@
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
@@ -38,0 +45,3 @@
+int nlist();
+void stats(), stat1(), stats2(), stats3(), biostats();
+int
@@ -39,0 +49 @@
+int argc;
@@ -43 +53 @@
-	register  i;
+	register  int i;
@@ -49 +59 @@
-	if(nl[0].type == -1) {
+	if(nl[0].type == 0) {
@@ -90,2 +100,22 @@
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
@@ -95,0 +126,14 @@
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
@@ -148,0 +193 @@
+void
@@ -149,0 +195 @@
+int dn;
@@ -151 +197 @@
-	register i;
+	register int i;
@@ -177,0 +224 @@
+void
@@ -178,0 +226 @@
+int o;
@@ -180 +228 @@
-	register i;
+	register int i;
@@ -196,0 +245 @@
+void
@@ -200 +249 @@
-	register i, j;
+	register int i, j;
@@ -208,0 +258 @@
+void
@@ -212 +262 @@
-	register i;
+	register int i;
@@ -253,0 +304 @@
+void
@@ -256 +307 @@
-register i;
+register int i;

% usr/src/cmd/join.c
@@ -24,0 +25,3 @@
+int input(), cmp();
+void output(), error();
+int
@@ -25,0 +29 @@
+int argc;
@@ -30 +34 @@
-	long top2, bot2;
+	long top2 = 0, bot2;
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
@@ -200,0 +208 @@
+void
@@ -202 +210 @@
-char *s1;
+char *s1, *s2, *s3, *s4, *s5;
@@ -209,0 +218 @@
+int

% usr/src/cmd/kill.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -6,0 +8 @@
+int
@@ -7,0 +10 @@
+int	argc;
@@ -10 +13 @@
-	register signo, pid, res;
+	register int signo, pid, res;
@@ -13 +16 @@
-	extern errno;
+	extern int errno;

% usr/src/cmd/ln.c
@@ -9,0 +10 @@
+int
@@ -10,0 +12 @@
+int argc;

% usr/src/cmd/login.c
@@ -15 +15 @@
-struct	passwd nouser = {"", "nope"};
+struct	passwd nouser = {"", "nope", 0, 0, 0, 0, 0, 0, 0};
@@ -25 +25 @@
-int	setpwent();
+void	showmotd();
@@ -31,0 +32 @@
+int
@@ -32,0 +34 @@
+int	argc;
@@ -130,0 +133 @@
+void
@@ -136,0 +140 @@
+void
@@ -140 +144 @@
-	register c;
+	register int c;

% usr/src/cmd/look.c
@@ -12,0 +13,2 @@
+void canon();
+int compare(), getword();
@@ -13,0 +16 @@
+int
@@ -14,0 +18 @@
+int argc;
@@ -17 +21 @@
-	register c;
+	register int c;
@@ -44 +48 @@
-		return;
+		return(0);
@@ -87 +91 @@
-			return;
+			return(0);
@@ -91 +95 @@
-			return;
+			return(0);
@@ -113,0 +118 @@
+int
@@ -125,0 +131 @@
+int
@@ -129 +135 @@
-	register c;
+	register int c;
@@ -141,0 +148 @@
+void
@@ -145 +152 @@
-	register c;
+	register int c;

% usr/src/cmd/ls.c
@@ -45,0 +46,3 @@
+void	pentry();
+int	getname();
+void	pmode(), select(), readdir();
@@ -48,0 +52 @@
+int
@@ -49,0 +54 @@
+int	argc;
@@ -146 +151 @@
-		if (ep->ltype=='d' && dflg==0 || fflg) {
+		if ((ep->ltype=='d' && dflg==0) || fflg) {
@@ -162,0 +168 @@
+void
@@ -166,2 +172 @@
-	struct { char dminor, dmajor;};
-	register t;
+	register int t;
@@ -203,0 +209 @@
+int
@@ -256,0 +263 @@
+void
@@ -257,0 +265 @@
+int	aflag;
@@ -265,0 +274 @@
+void
@@ -296,0 +306 @@
+void
@@ -313,2 +323,2 @@
-		 || aflg==0 && dentry.d_name[0]=='.' &&  (dentry.d_name[1]=='\0'
-			|| dentry.d_name[1]=='.' && dentry.d_name[2]=='\0'))
+		 || (aflg==0 && dentry.d_name[0]=='.' && (dentry.d_name[1]=='\0'
+			|| (dentry.d_name[1]=='.' && dentry.d_name[2]=='\0'))))
@@ -329,0 +340 @@
+int	argfl;
@@ -399,0 +411 @@
+int

% usr/src/cmd/makekey.c
@@ -8,0 +9 @@
+int	read(), write();
@@ -9,0 +11 @@
+int

% usr/src/cmd/mesg.c
@@ -18,0 +19,2 @@
+void error(), newmode();
+int
@@ -19,0 +22 @@
+int	argc;
@@ -43,0 +47 @@
+void
@@ -50,0 +55 @@
+void
@@ -51,0 +57 @@
+int	m;

% usr/src/cmd/mkdir.c
@@ -11,0 +12,2 @@
+void mkdir();
+int
@@ -12,0 +15 @@
+int argc;
@@ -30,0 +34 @@
+void
@@ -35 +39 @@
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
@@ -20,0 +25,7 @@
+void ltol3(cp, lp, n) char *cp; long *lp; int n; {
+	int i; long v;
+	for(i=0; i<n; i++) {
+		v = lp[i];
+		*cp++ = v; *cp++ = v >> 8; *cp++ = v >> 16;
+	}
+}
@@ -34,4 +45,2 @@
-} fbuf;
-#ifndef STANDALONE
-struct exec head;
-#endif
+} fbuf_storage;
+#define fbuf fbuf_storage.fb
@@ -42 +51,2 @@
-} filsys;
+} filsys_storage;
+#define filsys filsys_storage.fs
@@ -50,0 +61,2 @@
+void	cfile(), getstr(), wtfs(), entry(), newblk(), bflist(), iput();
+int	gmode(), getch(), badblk();
@@ -51,0 +64 @@
+int
@@ -52,0 +66 @@
+int	argc;
@@ -59 +73,4 @@
-	time(&utime);
+	if ((fsys = getenv("V7_MKFS_TIME")) != NULL)
+		utime = atol(fsys);
+	else
+		time(&utime);
@@ -103 +120 @@
-		for(f=0; c=proto[f]; f++) {
+		for(f=0; (c=proto[f]); f++) {
@@ -114 +131 @@
-		if(n > 65500/NIPB)
+		if((unsigned)n > 65500/NIPB)
@@ -117 +134 @@
-		printf("isize = %D\n", n*NIPB);
+		printf("isize = %ld\n", n*NIPB);
@@ -125 +141,0 @@
-	 * and read onto block 0
@@ -130 +146 @@
-	if(f < 0) {
+	if(f < 0)
@@ -132,14 +148 @@
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
@@ -147 +149,0 @@
-f1:
@@ -155 +156,0 @@
-f2:
@@ -175 +176 @@
-		printf("%ld/%ld: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
+		printf("%ld/%d: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
@@ -196,0 +198 @@
+void
@@ -203 +205 @@
-	daddr_t ib[NINDIR];
+	daddr_t ib[MAXFILEBLK];
@@ -235 +237 @@
-	for(i=0; i<NINDIR; i++)
+	for(i=0; (unsigned)i<MAXFILEBLK; i++)
@@ -308,0 +311 @@
+int
@@ -310,0 +314 @@
+int	m0, m1, m2, m3;
@@ -312,0 +317 @@
+	int m[4] = {m0, m1, m2, m3};
@@ -316 +321 @@
-			return((&m0)[i]);
+			return(m[i]);
@@ -331 +336 @@
-	for(i=0; c=string[i]; i++) {
+	for(i=0; (c=string[i]) != 0; i++) {
@@ -341,0 +347 @@
+void
@@ -371,0 +378 @@
+void
@@ -385,0 +393 @@
+void
@@ -395 +403 @@
-		printf("write error: %D\n", bno);
+		printf("write error: %ld\n", bno);
@@ -420,0 +429 @@
+void
@@ -436,0 +446 @@
+void
@@ -456 +466 @@
-	if(*adbc >= NDIRECT)
+	if((unsigned)*adbc >= NDIRECT)
@@ -459,0 +470 @@
+void
@@ -475 +486 @@
-	if(*aibc >= NINDIR) {
+	if((unsigned)*aibc >= MAXFILEBLK) {
@@ -481,0 +493 @@
+int
@@ -493,0 +506 @@
+void
@@ -525 +538 @@
-	for(i=0; i<NINDIR; i++)
+	for(i=0; (unsigned)i<NINDIR; i++)
@@ -535 +548 @@
-		if(f < filsys.s_fsize && f >= filsys.s_isize)
+		if(f < filsys.s_fsize && f >= filsys.s_isize) {
@@ -537 +550 @@
-				if(ibc >= NINDIR) {
+				if((unsigned)ibc >= NINDIR) {
@@ -545,0 +559 @@
+		}
@@ -549,0 +564 @@
+void
@@ -556 +571 @@
-	daddr_t d;
+	daddr_t d, dbl[NINDIR];
@@ -591,3 +606,10 @@
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
@@ -595 +617 @@
-			wtfs(ip->i_un.i_addr[LADDR], (char *)ib);
+			wtfs(ip->i_un.i_addr[LADDR+1], (char *)dbl);
@@ -596,0 +619 @@
+		/* fallthrough */
@@ -609,0 +633 @@
+int
@@ -613,0 +638 @@
+	(void)bno;

% usr/src/cmd/mknod.c
@@ -0,0 +1,3 @@
+#include <stdio.h>
+int number();
+int
@@ -29,0 +33 @@
+int
@@ -36 +40 @@
-	while(c = *s++) {
+	while((c = *s++)) {

% usr/src/cmd/mount.c
@@ -10,0 +11 @@
+int
@@ -11,0 +13 @@
+int argc;

% usr/src/cmd/mv.c
@@ -20 +19,0 @@
-char	*sprintf();
@@ -21,0 +21 @@
+int	move(), mvdir(), check(), chkdot();
@@ -23,0 +24 @@
+int
@@ -24,0 +26 @@
+int argc;
@@ -27 +29 @@
-	register i, r;
+	register int i, r;
@@ -52,0 +55 @@
+int
@@ -56 +59 @@
-	register c, i;
+	register int c, i;
@@ -121,0 +125 @@
+int
@@ -126 +130 @@
-	register i;
+	register int i;
@@ -232 +236 @@
-	register c;
+	register int c;
@@ -237 +241 @@
-	while (c = *p++ = *name++)
+	while ((c = *p++ = *name++))
@@ -258,0 +263 @@
+int
@@ -278 +283 @@
-		if (strlen(nspth) > MAXN-2-sizeof(DOTDOT)) {
+		if (strlen(nspth) > (int)(MAXN-2-sizeof(DOTDOT))) {
@@ -287,0 +293 @@
+int

% usr/src/cmd/ncheck.c
@@ -39,0 +40,2 @@
+void	check(), pass1(), pass2(), pass3(), pname(), bread();
+int	dotname(), l3tol();
@@ -40,0 +43 @@
+int
@@ -41,0 +45 @@
+int	argc;
@@ -44 +48 @@
-	register i;
+	register int i;
@@ -80,0 +85 @@
+void
@@ -84 +89 @@
-	register i, j;
+	register int i, j;
@@ -136,0 +142 @@
+void
@@ -146 +152 @@
-			return;
+		return;
@@ -150,0 +157 @@
+void
@@ -157 +164 @@
-	register i, j;
+	register int i, j;
@@ -174 +181 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -193,0 +201 @@
+void
@@ -200 +208 @@
-	register i, j;
+	register int i, j;
@@ -216 +224 @@
-		for(j=0; j<NDIR; j++) {
+		for(j=0; j<(int)NDIR; j++) {
@@ -242,0 +251 @@
+int
@@ -252,0 +262 @@
+void
@@ -253,0 +264 @@
+int	lev;
@@ -274,0 +286 @@
+int	ef;
@@ -293,0 +306 @@
+void
@@ -294,0 +308 @@
+int	cnt;
@@ -298 +312 @@
-	register i;
+	register int i;
@@ -309,0 +324 @@
+int	i;
@@ -316 +331 @@
-	if(i > NINDIR) {
+	if(i > (int)NINDIR) {

% usr/src/cmd/newgrp.c
@@ -8,0 +9,2 @@
+void done();
+int
@@ -13 +15 @@
-	register i;
+	register int i;
@@ -44,0 +47 @@
+void
@@ -47 +50 @@
-	register i;
+	register int i;

% usr/src/cmd/nice.c
@@ -4,0 +5 @@
+int
@@ -10 +11 @@
-	extern errno;
+	extern int errno;

% usr/src/cmd/od.c
@@ -13,0 +14,2 @@
+void offset(), line(), putx(), cput(), putn(), pre();
+int
@@ -14,0 +17 @@
+int	argc;
@@ -18 +21 @@
-	register n, f, same;
+	register int n, f, same;
@@ -96,0 +100 @@
+void
@@ -97,0 +102 @@
+int	n;
@@ -101 +106 @@
-	register i, f, c;
+	register int i, f, c;
@@ -119,0 +125 @@
+void
@@ -120,0 +127 @@
+int	c;
@@ -157,0 +165 @@
+void
@@ -158,0 +167 @@
+int	c;
@@ -189,0 +199 @@
+void
@@ -190,0 +201,2 @@
+int	c;
+int	b;
@@ -193 +205 @@
-	register d;
+	register int d;
@@ -204,0 +217 @@
+void
@@ -205,0 +219 @@
+int	n;
@@ -212,0 +227 @@
+void

% usr/src/cmd/osh.c
@@ -55 +55 @@
-char	*mesg[NSIG] {
+char	*mesg[NSIG] = {
@@ -77,0 +78,6 @@
+int	*syntax(), *syn1(), *syn2(), *syn3(), readc(), getc(), any(), equal();
+void	main1(), word(), prs(), prn(), putc(), err(), texec(), pwait(), execute(), exit();
+int	read(), write(), close(), open(), creat(), pipe(), dup(), fork(), wait(), execv();
+int	getpid(), getuid(), chdir(), signal();
+long	lseek();
+int
@@ -82,2 +88,2 @@
-	register f;
-	register char *acname, **v;
+	register int f;
+	register char **v;
@@ -93 +98,0 @@
-	acname = "<none>";
@@ -136,0 +142 @@
+void
@@ -140 +146 @@
-	register *t;
+	register int *t;
@@ -163 +169 @@
-			execute(t);
+			execute(t, 0, 0);
@@ -166,0 +173 @@
+void
@@ -222,0 +230 @@
+int *
@@ -226 +234 @@
-	register *t;
+	register int *t;
@@ -229 +237 @@
-	treep =+ n;
+	treep += n;
@@ -237,0 +246 @@
+int
@@ -248 +257 @@
-		argp =- 10;
+		argp -= 10;
@@ -250 +259 @@
-		argp =+ 10;
+		argp += 10;
@@ -256 +265 @@
-		linep =- 10;
+		linep -= 10;
@@ -258 +267 @@
-		linep =+ 10;
+		linep += 10;
@@ -291,0 +301 @@
+int
@@ -296 +306 @@
-	register c;
+	register int c;
@@ -299 +309 @@
-		if (arginp == 1)
+		if (arginp == (char *)1)
@@ -302 +312 @@
-			arginp = 1;
+			arginp = (char *)1;
@@ -309 +319 @@
-	if((rdstat = read(0, &cc, 1)) != 1)
+	if((rdstat = read(0, &cc, 1)) != 1) {
@@ -311,0 +322 @@
+	}
@@ -322,0 +334 @@
+int *
@@ -341,0 +354 @@
+int *
@@ -346 +359 @@
-	register *t, *t1;
+	register int *t, *t1;
@@ -370 +383 @@
-			t[DLEF] = syn2(p1, p);
+			t[DLEF] = (int)syn2(p1, p);
@@ -373,2 +386,2 @@
-				t1 = t[DLEF];
-				t1[DFLG] =| FAND|FPRS|FINT;
+				t1 = (int *)t[DLEF];
+				t1[DFLG] |= FAND|FPRS|FINT;
@@ -376 +389 @@
-			t[DRIT] = syntax(p+1, p2);
+			t[DRIT] = (int)syntax(p+1, p2);
@@ -391,0 +405 @@
+int *
@@ -415,2 +429,2 @@
-			t[DLEF] = syn3(p1, p);
-			t[DRIT] = syn2(p+1, p2);
+			t[DLEF] = (int)syn3(p1, p);
+			t[DRIT] = (int)syn2(p+1, p2);
@@ -429,0 +444 @@
+int *
@@ -435 +450 @@
-	register *t;
+	register int *t;
@@ -440 +455 @@
-		flg =| FPAR;
+		flg |= FPAR;
@@ -468 +483 @@
-			flg =| FCAT; else
+			flg |= FCAT; else
@@ -469,0 +485 @@
+		/* fallthrough */
@@ -483 +499 @@
-				i = *p;
+				i = (int)*p;
@@ -488 +504 @@
-			o = *p;
+			o = (int)*p;
@@ -501 +517 @@
-		t[DSPR] = syn1(lp, rp);
+		t[DSPR] = (int)syn1(lp, rp);
@@ -510 +526 @@
-		t[l+DCOM] = p1[l];
+		t[l+DCOM] = (int)p1[l];
@@ -517,0 +534 @@
+void
@@ -523 +540 @@
-	register *t;
+	register int *t;
@@ -526,2 +543,2 @@
-	while(p = *t++)
-		while(c = *p)
+	while((p = (char *)*t++))
+		while((c = *p))
@@ -530,0 +548 @@
+int
@@ -539,0 +558 @@
+int
@@ -546,0 +566 @@
+void
@@ -551 +571 @@
-	register *t1;
+	register int *t1;
@@ -553 +572,0 @@
-	extern errno;
@@ -559 +578 @@
-		cp1 = t[DCOM];
+		cp1 = (char *)t[DCOM];
@@ -562 +581 @@
-				if(chdir(t[DCOM+1]) < 0)
+				if(chdir((char *)t[DCOM+1]) < 0)
@@ -580 +599 @@
-				execv("/bin/login", t+DCOM);
+				execv("/bin/login", (char **)(t+DCOM));
@@ -587 +606 @@
-				execv("/bin/newgrp", t+DCOM);
+				execv("/bin/newgrp", (char **)(t+DCOM));
@@ -597,0 +617 @@
+		/* fallthrough */
@@ -625 +645 @@
-			i = open(t[DLEF], 0);
+			i = open((char *)t[DLEF], 0);
@@ -627 +647 @@
-				prs(t[DLEF]);
+				prs((char *)t[DLEF]);
@@ -634 +654 @@
-				i = open(t[DRIT], 1);
+				i = open((char *)t[DRIT], 1);
@@ -640 +660 @@
-			i = creat(t[DRIT], 0666);
+			i = creat((char *)t[DRIT], 0666);
@@ -642 +662 @@
-				prs(t[DRIT]);
+				prs((char *)t[DRIT]);
@@ -672,3 +692,3 @@
-			if(t1 = t[DSPR])
-				t1[DFLG] =| f&FINT;
-			execute(t1);
+			if((t1 = (int *)t[DSPR]))
+				t1[DFLG] |= f&FINT;
+			execute(t1, 0, 0);
@@ -680,2 +700,2 @@
-			t[DSPR] = "/etc/glob";
-			execv(t[DSPR], t+DSPR);
+			t[DSPR] = (int)"/etc/glob";
+			execv((char *)t[DSPR], (char **)(t+DSPR));
@@ -687 +707 @@
-		texec(t[DCOM], t);
+		texec((char *)t[DCOM], t);
@@ -690 +710 @@
-		while(*cp1 = *cp2++)
+		while((*cp1 = *cp2++))
@@ -692,2 +712,2 @@
-		cp2 = t[DCOM];
-		while(*cp1++ = *cp2++);
+		cp2 = (char *)t[DCOM];
+		while((*cp1++ = *cp2++));
@@ -696 +716 @@
-		prs(t[DCOM]);
+		prs((char *)t[DCOM]);
@@ -698,0 +719 @@
+		/* fallthrough */
@@ -703,2 +724,2 @@
-		t1 = t[DLEF];
-		t1[DFLG] =| FPOU | (f&(FPIN|FINT|FPRS));
+		t1 = (int *)t[DLEF];
+		t1[DFLG] |= FPOU | (f&(FPIN|FINT|FPRS));
@@ -706,2 +727,2 @@
-		t1 = t[DRIT];
-		t1[DFLG] =| FPIN | (f&(FPOU|FINT|FAND|FPRS));
+		t1 = (int *)t[DRIT];
+		t1[DFLG] |= FPIN | (f&(FPOU|FINT|FAND|FPRS));
@@ -713,6 +734,6 @@
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
@@ -723,0 +745 @@
+void
@@ -724,0 +747 @@
+int	f;
@@ -727 +750 @@
-	extern errno;
+	extern int errno;
@@ -731 +754 @@
-	execv(f, t+DCOM);
+	execv(f, (char **)(t+DCOM));
@@ -734,3 +757,3 @@
-			t[DCOM] = linep;
-		t[DSPR] = "/usr/bin/osh";
-		execv(t[DSPR], t+DSPR);
+			t[DCOM] = (int)linep;
+		t[DSPR] = (int)"/usr/bin/osh";
+		execv((char *)t[DSPR], (char **)(t+DSPR));
@@ -741 +764 @@
-		prs(t[DCOM]);
+		prs((char *)t[DCOM]);
@@ -746,0 +770 @@
+void
@@ -759,0 +784 @@
+void
@@ -769,0 +795 @@
+void
@@ -770,0 +797 @@
+int	c;
@@ -777,0 +805 @@
+void
@@ -781 +809 @@
-	register a;
+	register int a;
@@ -783 +811 @@
-	if (a = n/10)
+	if ((a = n/10))
@@ -787,0 +816 @@
+int
@@ -800,0 +830 @@
+int
@@ -813,0 +844 @@
+void
@@ -817 +848 @@
-	register p, e;
+	register int p, e;
@@ -818,0 +850 @@
+	(void)t;
@@ -840 +872 @@
-		if (e || s&&stoperr)
+		if (e || (s&&stoperr))
@@ -842 +874 @@
-		errval =| (s>>8);
+		errval |= (s>>8);

% usr/src/cmd/passwd.c
@@ -14 +13,0 @@
-int	endpwent();
@@ -22,0 +22 @@
+int
@@ -23,0 +24 @@
+int argc;
@@ -75 +76 @@
-	while(c = *p++){
+	while((c = *p++)){

% usr/src/cmd/pr.c
@@ -42,0 +43 @@
+int	tpgetc(), pgetc(); void done(), fixtty(), print(), mopen(), putpage(), nexbuf(), put(), putcp();
@@ -43,0 +45 @@
+int
@@ -44,0 +47 @@
+int argc;
@@ -48 +51 @@
-	int onintr();
+	void onintr();
@@ -106,0 +110 @@
+void
@@ -114,0 +119 @@
+void
@@ -122,0 +128 @@
+void
@@ -134,0 +141 @@
+void
@@ -139 +145,0 @@
-	extern char *sprintf();
@@ -141 +147 @@
-	register sncol;
+	register int sncol;
@@ -195 +201 @@
-	while (mflg&&nofile || (!mflg)&&tpgetc(ncol)>0) {
+	while ((mflg&&nofile) || ((!mflg)&&tpgetc(ncol)>0)) {
@@ -217,0 +224 @@
+void
@@ -237,0 +245 @@
+void
@@ -281,0 +290 @@
+void
@@ -304,0 +314 @@
+int
@@ -305,0 +316 @@
+int ai;
@@ -339,0 +351 @@
+int
@@ -340,0 +353 @@
+int i;
@@ -371,0 +385 @@
+void
@@ -372,0 +387 @@
+int ac;
@@ -417,0 +433 @@
+void
@@ -418,0 +435 @@
+int c;

% usr/src/cmd/primes.c usr/src/cmd/primes.s
@@ -1,355 +1,142 @@
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
+int
+getch()
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
+long long
+getnum()
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
+void
+wrchar(c)
+int c;
+{
+	iobuf[nbuf++] = c;
+	if(nbuf >= 512) {
+		write(1, iobuf, 512);
+		nbuf = 0;
+	}
+}
+
+void
+ftoa(n)
+long long n;
+{
+	if(n >= 10)
+		ftoa(n/10);
+	wrchar((int)(n%10) + '0');
+}
+
+void
+mark(p)
+int p;
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
+main(argc, argv)
+int argc;
+char **argv;
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
@@ -54,0 +55 @@
+int	min(), max(); void done();
@@ -55,0 +57 @@
+int
@@ -56,0 +59 @@
+int argc;
@@ -61,0 +65 @@
+#ifdef plot
@@ -63,0 +68 @@
+#endif
@@ -64,0 +70 @@
+#ifdef plot
@@ -65,0 +72 @@
+#endif
@@ -83 +90 @@
-				if(lowpc == -1)
+				if(lowpc == (unsigned)-1)
@@ -121,0 +129 @@
+#ifdef plot
@@ -122,0 +131 @@
+#endif
@@ -153,2 +162,2 @@
-		register j;
-		unsigned UNIT ccnt;
+		register int j;
+		unsigned short ccnt;
@@ -162,4 +171,4 @@
-		ftime = ccnt;
-		totime += ftime;
-		if(ftime > maxtime)
-			maxtime = ftime;
+		ftim = ccnt;
+		totime += ftim;
+		if(ftim > maxtime)
+			maxtime = ftim;
@@ -172 +181 @@
-			nl[j].time += overlap*ftime/scale;
+			nl[j].time += overlap*ftim/scale;
@@ -201 +210 @@
-		ftime = ccnt;
+		ftim = ccnt;
@@ -204 +213 @@
-		lastsx -= 2000.*ftime/totime;
+		lastsx -= 2000.*ftim/totime;
@@ -210 +219 @@
-				lastx = -ftime*2000./maxtime;
+				lastx = -ftim*2000./maxtime;
@@ -223 +232 @@
-		ftime = np->time/totime;
+		ftim = np->time/totime;
@@ -252 +261 @@
-		ftime = np->time/totime;
+		ftim = np->time/totime;
@@ -254 +263 @@
-		printf("%8.8s%6.1f%9.2f", np->name, 100*ftime, actime/60);
+		printf("%8.8s%6.1f%9.2f", np->name, 100*ftim, actime/60);
@@ -263,0 +273 @@
+int
@@ -271,0 +282 @@
+int
@@ -279,0 +291 @@
+int
@@ -285,0 +298 @@
+int
@@ -298,0 +312 @@
+void

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
@@ -13 +15,2 @@
-#include <sys/user.h>
+#include "../../sys/h/user.h"
+#undef u
@@ -16,4 +19,4 @@
-	{ "_proc" },
-	{ "_swapdev" },
-	{ "_swplo" },
-	{ "" },
+	{ "_proc", 0, 0 },
+	{ "_swapdev", 0, 0 },
+	{ "_swplo", 0, 0 },
+	{ "", 0, 0 },
@@ -35 +38 @@
-char	*strncmp();
+int	prcom(), getbyte(), within(); void getdev();
@@ -49,0 +53 @@
+int
@@ -50,0 +55 @@
+int argc;
@@ -153,0 +159 @@
+void
@@ -198,0 +205 @@
+int
@@ -199,0 +207 @@
+int puid;
@@ -201 +209 @@
-	char abuf[512];
+	int abuf[128];
@@ -234 +242 @@
-	datmap.f2 = ctob(USIZE)+(datmap.e1-datmap.b1)+addr;
+	datmap.f2 = ctob(USIZE)+datmap.b2+addr;
@@ -241 +249 @@
-			"0SWRIZT"[mproc.p_stat], puid);
+			"0SWRIZT"[mproc.p_stat&0377], puid);
@@ -304 +312 @@
-	if (read(file, abuf, sizeof(abuf)) != sizeof(abuf))
+	if (read(file, (char *)abuf, sizeof(abuf)) != sizeof(abuf))
@@ -306 +314 @@
-	for (ip = (int *)&abuf[512]-2; ip > (int *)abuf; ) {
+	for (ip = &abuf[128]-2; ip > abuf; ) {
@@ -312 +320 @@
-			for (cp1 = cp; cp1 < &abuf[512]; cp1++) {
+			for (cp1 = cp; cp1 < (char *)abuf + sizeof(abuf); cp1++) {
@@ -341 +349 @@
-	register i;
+	register int i;
@@ -363 +371 @@
-	register i;
+	register unsigned i;
@@ -372,0 +381 @@
+int
@@ -394,0 +404 @@
+int
@@ -399 +409 @@
-	return((unsigned)adr>=lbd && (unsigned)adr<ubd);
+	return((long)adr>=lbd && (long)adr<ubd);

% usr/src/cmd/pstat.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -7,2 +8,7 @@
-#include <sys/conf.h>
-#include <sys/tty.h>
+#include "../../sys/h/tty.h"
+#include "../../sys/h/inode.h"
+#include "../../sys/h/text.h"
+#include "../../sys/h/proc.h"
+#include <sys/dir.h>
+#include "../../sys/h/user.h"
+#include "../../sys/h/file.h"
@@ -20 +26 @@
-	"_inode", 0, 0,
+	{"_inode", 0, 0},
@@ -22 +28 @@
-	"_text", 0, 0,
+	{"_text", 0, 0},
@@ -24 +30 @@
-	"_proc", 0, 0,
+	{"_proc", 0, 0},
@@ -26 +32 @@
-	"_dh11", 0, 0,
+	{"_dh11", 0, 0},
@@ -28 +34 @@
-	"_ndh11", 0, 0,
+	{"_ndh11", 0, 0},
@@ -30 +36 @@
-	"_kl11", 0, 0,
+	{"_kl11", 0, 0},
@@ -32,2 +38,2 @@
-	"_file", 0, 0,
-	0,
+	{"_file", 0, 0},
+	{"", 0, 0},
@@ -44,0 +51,3 @@
+int nlist(), oatoi();
+void doinode(), dotext(), doproc(), dotty(), dousr(), dofil(), putf(), ttyprt();
+int
@@ -45,0 +55 @@
+int argc;
@@ -110,0 +121 @@
+void
@@ -113 +123,0 @@
-#include <sys/inode.h>
@@ -150,0 +161 @@
+void
@@ -151,0 +163 @@
+int v, n;
@@ -158,0 +171 @@
+void
@@ -161 +173,0 @@
-#include <sys/text.h>
@@ -164 +176 @@
-	register loc;
+	register int loc;
@@ -195,0 +208 @@
+void
@@ -198 +210,0 @@
-#include <sys/proc.h>
@@ -201 +213 @@
-	register loc, np;
+	register int loc, np;
@@ -235,0 +248 @@
+void
@@ -259,0 +273 @@
+void
@@ -260,0 +275 @@
+int n;
@@ -285,0 +301 @@
+void
@@ -288,2 +303,0 @@
-#include <sys/dir.h>
-#include <sys/user.h>
@@ -295 +309 @@
-	register i;
+	register int i;
@@ -354,0 +369 @@
+int
@@ -358 +373 @@
-	register v;
+	register int v;
@@ -365,0 +381 @@
+void
@@ -368 +383,0 @@
-#include <sys/file.h>
@@ -371 +386 @@
-	register nf;
+	register int nf;

% usr/src/cmd/ptx.c
@@ -36,0 +37,2 @@
+void diag(), msg(), cmpline(), getsort(), putline(), putout(), onintr();
+int storeh(), hash(), cmpword();
@@ -41 +43 @@
-char btable[128];
+char btable[256];
@@ -68,0 +71 @@
+int
@@ -77 +80 @@
-	extern onintr();
+	extern void onintr();
@@ -116,0 +120 @@
+			/* fallthrough */
@@ -228 +232 @@
-	while(pend=getline())
+	while((pend=getline()))
@@ -236,0 +241 @@
+		/* fallthrough */
@@ -249,0 +255 @@
+void
@@ -256,0 +263 @@
+void
@@ -269 +276 @@
-	register c;
+	register int c;
@@ -291 +298 @@
-				while(isspace(*--linep));
+				while(isspace(*--linep&0377));
@@ -301,0 +309 @@
+void
@@ -312 +320 @@
-		while(pchar<pend&&!isspace(*pchar))
+		while(pchar<pend&&!isspace(*pchar&0377))
@@ -316 +324 @@
-		if(isabreak(*pchar++))
+		if(isabreak(*pchar++&0377))
@@ -322 +330 @@
-			if(isabreak(*pchar)) {
+			if(isabreak(*pchar&0377)) {
@@ -325 +333 @@
-				while(cp = *hp++){
+				while((cp = *hp++)){
@@ -348,0 +357 @@
+int
@@ -356 +365 @@
-		if((isupper(c)?tolower(c):c) != *hpp++)
+		if((isupper(c&0377)?tolower(c):c) != *hpp++)
@@ -362,0 +372 @@
+void
@@ -378,0 +389 @@
+void
@@ -381 +392 @@
-	register c;
+	register int c;
@@ -400 +411 @@
-			while(isspace(linep[-1]))
+			while(isspace(linep[-1]&0377))
@@ -404 +415 @@
-				while(ref<linep&&!isspace(*ref))
+				while(ref<linep&&!isspace(*ref&0377))
@@ -416 +427 @@
-			p1b = rtrim(p1a=p3b+(isspace(p3b[0])!=0),tilde,
+			p1b = rtrim(p1a=p3b+(isspace(p3b[0]&0377)!=0),tilde,
@@ -420 +431 @@
-			p4a = ltrim(ref,p4b=p2a-(isspace(p2a[-1])!=0),
+			p4a = ltrim(ref,p4b=p2a-(isspace(p2a[-1]&0377)!=0),
@@ -452,0 +464 @@
+			/* fallthrough */
@@ -460,0 +473 @@
+int d;
@@ -465 +478 @@
-		if((x==c||isspace(x[0]))&&!isspace(x[-1]))
+		if((x==c||isspace(x[0]&0377))&&!isspace(x[-1]&0377))
@@ -467 +480 @@
-	if(b<c&&!isspace(b[0]))
+	if(b<c&&!isspace(b[0]&0377))
@@ -473,0 +487 @@
+int d;
@@ -478 +492 @@
-		if(!isspace(x[0])&&(x==c||isspace(x[-1])))
+		if(!isspace(x[0]&0377)&&(x==c||isspace(x[-1]&0377)))
@@ -480 +494 @@
-	if(a>c&&!isspace(a[-1]))
+	if(a>c&&!isspace(a[-1]&0377))
@@ -484,0 +499 @@
+void
@@ -496,0 +512 @@
+void
@@ -504,0 +521 @@
+int
@@ -517 +534 @@
-	i = (isupper(c)?tolower(c):c);
+	i = (isupper(c&0377)?tolower(c):c);
@@ -519 +536 @@
-	j = (isupper(c)?tolower(c):c);
+	j = (isupper(c&0377)?tolower(c):c);
@@ -523 +540 @@
-	k = (isupper(c)?tolower(c):c);
+	k = (isupper(c&0377)?tolower(c):c);
@@ -525 +542 @@
-	j = (isupper(c)?tolower(c):c);
+	j = (isupper(c&0377)?tolower(c):c);
@@ -531,0 +549 @@
+int

% usr/src/cmd/pwd.c
@@ -16,0 +17,2 @@
+void prname(), cat();
+int
@@ -38 +40 @@
-				if (read(file, (char *)&dir, sizeof(dir)) < sizeof(dir)) {
+				if (read(file, (char *)&dir, sizeof(dir)) < (int)sizeof(dir)) {
@@ -45 +47 @@
-				if(read(file, (char *)&dir, sizeof(dir)) < sizeof(dir)) {
+				if(read(file, (char *)&dir, sizeof(dir)) < (int)sizeof(dir)) {
@@ -55,0 +58 @@
+void
@@ -65,0 +69 @@
+void
@@ -68 +72 @@
-	register i, j;
+	register int i, j;

% usr/src/cmd/quot.c
@@ -44,0 +45,3 @@
+int	scanf(char *fmt, ...);
+void	check(), acct(), bread(), report();
+int	qcmp();
@@ -45,0 +49 @@
+int
@@ -46,0 +51 @@
+int argc;
@@ -86,0 +92 @@
+void
@@ -91 +97 @@
-	register c;
+	register int c;
@@ -117,0 +124 @@
+void
@@ -121 +128 @@
-	register n;
+	register int n;
@@ -123 +130 @@
-	static fino;
+	static int fino;
@@ -147 +154 @@
-		if (fino > ino)
+		if (fino > (int)ino)
@@ -149 +156 @@
-		if (fino<ino) {
+		if (fino<(int)ino) {
@@ -155 +162 @@
-		if (np = du[ip->di_uid].name)
+		if ((np = du[ip->di_uid].name))
@@ -169,0 +177 @@
+void
@@ -170,0 +179 @@
+int cnt;
@@ -181,0 +191 @@
+int
@@ -191,0 +202 @@
+void
@@ -194 +205 @@
-	register i;
+	register int i;
@@ -227 +238 @@
-	register n;
+	register int n;
@@ -232 +243 @@
-	for(n=0; p[n] = s[n]; n++)
+	for(n=0; (p[n] = s[n]); n++)

% usr/src/cmd/random.c
@@ -7 +7,2 @@
-main(argc,argv) char **argv;
+int
+main(argc,argv) int argc; char **argv;

% usr/src/cmd/restor.c
@@ -83,0 +84,3 @@
+int readc(), psearch(), direq(), gethead(), ishead(), checktype(), checksum(), checkvol(), readhdr(), l3tol(), ltol3();
+void pass1(), putent(), doit(), getfile(), readtape(), flsht(), copy(), clearbuf(), writec(), flsh(), dwrite(), dread(), clri(), itrunc(), tloop(), bfree(), getdino(), putdino(), readbits();
+int
@@ -84,0 +88 @@
+int argc;
@@ -88 +92 @@
-	char command;
+	char command = 0;
@@ -142,0 +147 @@
+void
@@ -149 +154 @@
-	register i, k;
+	register int i, k;
@@ -251 +256 @@
-					return;
+				return;
@@ -300 +305 @@
-			if (gets(tbf) == EOF) {
+			if (gets(tbf) == NULL) {
@@ -404,0 +410 @@
+void
@@ -407 +413 @@
-	register i;
+	register int i;
@@ -445,0 +452 @@
+void
@@ -451 +458 @@
-	register i;
+	register int i;
@@ -494,0 +502 @@
+void
@@ -498 +506 @@
-	register i;
+	register int i;
@@ -538,0 +547 @@
+void
@@ -543,0 +553 @@
+void
@@ -544,0 +555 @@
+int s;
@@ -547 +558 @@
-	register i;
+	register int i;
@@ -554,0 +566 @@
+void
@@ -558 +570 @@
-	register i;
+	register int i;
@@ -570,0 +583 @@
+void
@@ -574 +587 @@
-	register i;
+	register int i;
@@ -576 +589 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -585,0 +599 @@
+void
@@ -589 +603 @@
-	register i;
+	register int i;
@@ -591 +605 @@
-	for (i = 0; i < sizeof(ino_t); i++)
+	for (i = 0; i < (int)sizeof(ino_t); i++)
@@ -601,0 +616 @@
+void
@@ -612,0 +628 @@
+int
@@ -621,0 +638 @@
+void
@@ -628,0 +646 @@
+void
@@ -643 +661 @@
-	register i;
+	register int i;
@@ -664,0 +683 @@
+int
@@ -692,0 +712 @@
+int
@@ -696 +716 @@
-	register i;
+	register int i;
@@ -711,0 +732 @@
+void
@@ -716 +737 @@
-	register i;
+	register int i;
@@ -737,0 +759 @@
+void
@@ -738,0 +761 @@
+int cnt;
@@ -742 +765 @@
-	register i, j;
+	register int i, j;
@@ -778,0 +802 @@
+void
@@ -792,0 +817 @@
+void
@@ -796 +821 @@
-	register i;
+	register int i;
@@ -828,0 +854 @@
+void
@@ -833 +859 @@
-	register i;
+	register int i;
@@ -852,0 +879 @@
+void
@@ -856 +883 @@
-	register i;
+	register int i;
@@ -863 +890 @@
-		fbuf.df_nfree = sblock.s_nfree;
+		fbuf.frees.df_nfree = sblock.s_nfree;
@@ -865 +892 @@
-			fbuf.df_free[i] = sblock.s_free[i];
+			fbuf.frees.df_free[i] = sblock.s_free[i];
@@ -879 +906 @@
-	register i;
+	register int i;
@@ -896 +923 @@
-		sblock.s_nfree = fbuf.df_nfree;
+		sblock.s_nfree = fbuf.frees.df_nfree;
@@ -898 +925 @@
-			sblock.s_free[i] = fbuf.df_free[i];
+			sblock.s_free[i] = fbuf.frees.df_free[i];
@@ -914 +941 @@
-	register i;
+	register int i;
@@ -975,0 +1003 @@
+int
@@ -987,0 +1016 @@
+int
@@ -995,0 +1025 @@
+int
@@ -1003,0 +1034 @@
+int
@@ -1007 +1038 @@
-	register i, j;
+	register int i, j;
@@ -1020,0 +1052 @@
+int
@@ -1029,0 +1062 @@
+int
@@ -1044,0 +1078 @@
+int
@@ -1049,0 +1084 @@
+	return(0);
@@ -1052 +1087,2 @@
-null() {;}
+int
+null() {return(0);}
@@ -1053,0 +1090 @@
+int
@@ -1056,0 +1094 @@
+	return(0);
@@ -1060,0 +1099 @@
+int
@@ -1066,0 +1106 @@
+	(void)s;
@@ -1069,0 +1110 @@
+	return(0);
@@ -1071,0 +1113 @@
+int
@@ -1075,0 +1118 @@
+	(void)b; (void)s;
@@ -1076,0 +1120 @@
+	return(0);
@@ -1079,0 +1124 @@
+int
@@ -1084 +1129 @@
-	register i;
+	register int i;
@@ -1090,0 +1136 @@
+	return(0);
@@ -1096,0 +1143 @@
+void
@@ -1109,0 +1157 @@
+void
@@ -1125,0 +1174 @@
+void
@@ -1129 +1178 @@
-	register i;
+	register int i;
@@ -1140,0 +1190 @@
+int
@@ -1146,0 +1197 @@
+	return(0);

% usr/src/cmd/rev.c
@@ -8,0 +9 @@
+int
@@ -9,0 +11 @@
+int argc;
@@ -12 +14 @@
-	register i,c;
+	register int i,c;

% usr/src/cmd/rm.c
@@ -8 +8,2 @@
-char	*sprintf();
+void	rm();
+int	dotname(), rmdir(), yes();
@@ -9,0 +11 @@
+int
@@ -10,0 +13 @@
+int	argc;
@@ -50,0 +54 @@
+void
@@ -51,0 +56,4 @@
+int	level;
+int	iflg;
+int	rflg;
+int	fflg;
@@ -115,0 +124 @@
+int
@@ -119 +128 @@
-	if(s[0] == '.')
+	if(s[0] == '.') {
@@ -126,0 +136 @@
+	}
@@ -129,0 +140 @@
+int
@@ -130,0 +142 @@
+int	iflg;
@@ -151,0 +164 @@
+	return(1);
@@ -153,0 +167 @@
+int

% usr/src/cmd/rmdir.c
@@ -13,0 +14 @@
+void	rmdir();
@@ -14,0 +16 @@
+int
@@ -28,0 +31 @@
+void

% usr/src/cmd/sa.c
@@ -9 +9 @@
-#define	NC	sizeof(acctbuf.ac_comm)
+#define	NC	(int)sizeof(acctbuf.ac_comm)
@@ -47,0 +48,2 @@
+int	tcmp(), ncmp(), bcmp(), enter(), getpw();
+void	init(), doacct(), strip(), printmoney(), column(), col();
@@ -48,0 +51 @@
+int
@@ -49,0 +53 @@
+int	argc;
@@ -54 +57,0 @@
-	extern tcmp(), ncmp(), bcmp();
@@ -143 +146 @@
-		return;
+		return 0;
@@ -212,0 +216 @@
+void
@@ -215 +219 @@
-	register i;
+	register int i;
@@ -235,0 +240 @@
+void
@@ -257,0 +263 @@
+void
@@ -271,0 +278 @@
+void
@@ -333,0 +341 @@
+int
@@ -344,0 +353 @@
+int
@@ -364,0 +374 @@
+int
@@ -396,0 +407 @@
+void
@@ -423,0 +435 @@
+int
@@ -452,0 +465 @@
+void

% usr/src/cmd/sed/sed.h
@@ -35,2 +35,2 @@
-union reptr	*abuf[ABUFSIZE];
-union reptr **aptr;
+struct reptr	*abuf[ABUFSIZE];
+struct reptr **aptr;
@@ -50 +50 @@
-union reptr	*ptrend;
+struct reptr	*ptrend;
@@ -104,2 +104 @@
-union	reptr {
-	struct reptr1 {
+struct	reptr {
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
@@ -136,2 +123,2 @@
-	union reptr	*chain;
-	union reptr	*address;
+	struct reptr	*chain;
+	struct reptr	*address;
@@ -151 +138 @@
-union reptr	**cmpend[DEPTH];
+struct reptr	**cmpend[DEPTH];
@@ -153 +140 @@
-union reptr	*pending;
+struct reptr	*pending;

% usr/src/cmd/sed/sed0.c
@@ -3,0 +4,2 @@
+void	fcomp(), dechain(), execute();
+int	rline(), cmp();
@@ -20,0 +23 @@
+int
@@ -21,0 +25 @@
+int	argc;
@@ -105 +109 @@
-/*	abort();	/*DEBUG*/
+/*	abort();	*DEBUG*/
@@ -114,0 +119 @@
+void
@@ -120 +125 @@
-	union reptr	*pt, *pt1;
+	struct reptr	*pt, *pt1;
@@ -143 +148 @@
-/*	fprintf(stdout, "cp: %s\n", cp);	/*DEBUG*/
+/*	fprintf(stdout, "cp: %s\n", cp);	*DEBUG*/
@@ -201,0 +207 @@
+				/* fallthrough */
@@ -261 +267 @@
-				if(lpt = search(lab)) {
+				if((lpt = search(lab))) {
@@ -345,2 +351,2 @@
-					if(pt = labtab->chain) {
-						while(pt1 = pt->lb1)
+					if((pt = labtab->chain)) {
+						while((pt1 = pt->lb1))
@@ -362 +368 @@
-				if(lpt = search(lab)) {
+				if((lpt = search(lab))) {
@@ -367 +373 @@
-						while(pt1 = pt->lb1)
+						while((pt1 = pt->lb1))
@@ -591 +597 @@
-	register c;
+	register int c;
@@ -719 +725 @@
-					for (c = sp[-2]; c<*sp; c++)
+					for (c = sp[-2]&0177; c<(*sp&0177); c++)
@@ -730 +736 @@
-				ep[c >> 3] |= bittab[c & 07];
+				ep[(c&0177) >> 3] |= bittab[c & 07];
@@ -748,0 +755 @@
+int
@@ -753 +760 @@
-	register	t;
+	register int	t;
@@ -764 +771 @@
-			while(*++p = *q++) {
+			while((*++p = *q++)) {
@@ -783 +790 @@
-		while(*++p = *q++) {
+		while((*++p = *q++)) {
@@ -854,0 +862 @@
+int
@@ -907,0 +916 @@
+void
@@ -911 +920 @@
-	union reptr	*rptr, *trptr;
+	struct reptr	*rptr, *trptr;
@@ -922 +931 @@
-			while(trptr = rptr->lb1) {
+			while((trptr = rptr->lb1)) {
@@ -934 +943,2 @@
-	register char	c, *ep, *tsp;
+	register int	c;
+	register char	*ep, *tsp;

% usr/src/cmd/sed/sed1.c
@@ -3,0 +4,2 @@
+void	command(), arout(), dosub();
+int	match(), advance(), ecmp();
@@ -38,0 +41 @@
+void
@@ -43 +46 @@
-	register union reptr	*ipc;
+	register struct reptr	*ipc;
@@ -157,0 +161 @@
+int
@@ -159,0 +164 @@
+int	gf;
@@ -167 +172 @@
-		while(*p1++ = *p2++);
+		while((*p1++ = *p2++));
@@ -204,0 +210 @@
+int
@@ -213 +219 @@
-/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	/*DEBUG*/
+/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	*DEBUG*/
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
@@ -315 +321 @@
-			c = *(braslist[ep[1]]);
+			c = *(braslist[(unsigned char)ep[1]]);
@@ -335,0 +342 @@
+int
@@ -337 +344 @@
-union reptr	*ipc;
+struct reptr	*ipc;
@@ -352,0 +360 @@
+void
@@ -364 +372 @@
-	while(c = *rp++) {
+	while((c = *rp++)) {
@@ -378 +386 @@
-	while (*sp++ = *lp++)
+	while ((*sp++ = *lp++))
@@ -384 +392 @@
-	while (*lp++ = *sp++);
+	while ((*lp++ = *sp++));
@@ -402,0 +411 @@
+void
@@ -404 +413 @@
-union reptr	*ipc;
+struct reptr	*ipc;
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
+			while((*p1 = *p1 & 0200 ? *p1 : p2[(unsigned char)*p1]))	p1++;
@@ -649 +660 @@
-	register	c;
+	register int	c;
@@ -682,0 +694 @@
+int
@@ -684,0 +697 @@
+int	count;
@@ -690,0 +704 @@
+void
@@ -698,2 +712 @@
-	aptr = abuf - 1;
-	while(*++aptr) {
+	for(aptr = abuf; *aptr; aptr++) {

% usr/src/cmd/sh/args.c
@@ -12 +12 @@
-PROC STRING *copyargs();
+LOCAL STRING *copyargs();
@@ -79 +79 @@
-	dolh=copyargs(argi,argn);	/* sets dolv */
+	dolh=(DOLPTR)copyargs(argi,argn);	/* sets dolv */
@@ -82,0 +83 @@
+DOLPTR
@@ -90 +91 @@
-	IF argblk=blk
+	IF (argblk=blk)
@@ -93 +94 @@
-		THEN	FOR argp=argblk->dolarg; Rcheat(*argp)!=ENDARGS; argp++
+		THEN	FOR argp=(STRING *)argblk->dolarg; Rcheat(*argp)!=ENDARGS; argp++
@@ -102,0 +104 @@
+	INT		n;
@@ -104 +106 @@
-	REG STRING *	np=alloc(sizeof(STRING*)*n+3*BYTESPERWORD);
+	REG STRING *	np=(STRING *)alloc(sizeof(STRING*)*n+3*BYTESPERWORD);
@@ -108,2 +110,2 @@
-	np->doluse=1;	/* use count */
-	np=np->dolarg;
+	((DOLPTR)np)->doluse=1;	/* use count */
+	np=(STRING *)((DOLPTR)np)->dolarg;
@@ -117,0 +120 @@
+VOID
@@ -121 +124 @@
-	WHILE argfor=freeargs(argfor) DONE
+	WHILE (argfor=freeargs(argfor)) DONE

% usr/src/cmd/sh/blok.c
@@ -37 +37 @@
-				IF ADR(q)-ADR(p) >= rbytes
+				IF (POS)(ADR(q)-ADR(p)) >= rbytes
@@ -60 +60 @@
-		rndstak=round(staktop,BYTESPERWORD);
+		rndstak=(STKPTR)round(staktop,BYTESPERWORD);
@@ -83 +83 @@
-	THEN	Lcheat((--p)->word) &= ~BUSY;
+	THEN	p--; p->word=BLK(Rcheat(p->word)&~BUSY);

% usr/src/cmd/sh/brkincr.h

% usr/src/cmd/sh/builtin.c
@@ -0,0 +1 @@
+int

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
+LOCAL IOPTR	inout();
+LOCAL VOID	chkword();
+LOCAL VOID	chksym();
+LOCAL TREPTR	term();
+LOCAL TREPTR	makelist();
+LOCAL TREPTR	list();
+LOCAL REGPTR	syncase();
+LOCAL TREPTR	item();
+LOCAL INT	skipnl();
+LOCAL VOID	prsym();
+LOCAL VOID	synbad();
@@ -35,0 +36 @@
+	REG FORKPTR	f;
@@ -37,2 +38,3 @@
-	t=getstak(FORKTYPE);
-	t->forktyp=flgs|TFORK; t->forktre=i; t->forkio=0;
+	t=(TREPTR)getstak(FORKTYPE);
+	f=(FORKPTR)t;
+	f->forktyp=flgs|TFORK; f->forktre=i; f->forkio=0;
@@ -46 +48,2 @@
-	REG TREPTR	t;
+	REG TREPTR	t = 0;
+	REG LSTPTR	l;
@@ -50,3 +53,4 @@
-	ELSE	t = getstak(LSTTYPE);
-		t->lsttyp = type;
-		t->lstlef = i; t->lstrit = r;
+	ELSE	t = (TREPTR)getstak(LSTTYPE);
+		l = (LSTPTR)t;
+		l->lsttyp = type;
+		l->lstlef = i; l->lstrit = r;
@@ -87,0 +92 @@
+		/* fallthrough */
@@ -90 +95 @@
-		IF e=cmd(sym,flg|MTFLG)
+		IF (e=cmd(sym,flg|MTFLG))
@@ -98,0 +104 @@
+		/* fallthrough */
@@ -116,0 +123 @@
+	INT		flg;
@@ -134,0 +142 @@
+	INT		flg;
@@ -156 +164 @@
-	ELSE	REG REGPTR	r=getstak(REGTYPE);
+	ELSE	REG REGPTR	r=(REGPTR)getstak(REGTYPE);
@@ -204 +212,3 @@
-		   t=getstak(SWTYPE);
+		   REG SWPTR	s;
+		   t=(TREPTR)getstak(SWTYPE);
+		   s=(SWPTR)t;
@@ -206 +216 @@
-		   t->swarg=wdarg->argval;
+		   s->swarg=wdarg->argval;
@@ -208,2 +218,2 @@
-		   t->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
-		   t->swtyp=TSW;
+		   s->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
+		   s->swtyp=TSW;
@@ -216,5 +226,7 @@
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
@@ -227,3 +239,5 @@
-		   t=getstak(FORTYPE);
-		   t->fortyp=TFOR;
-		   t->forlst=0;
+		   REG FORPTR	fr;
+		   t=(TREPTR)getstak(FORTYPE);
+		   fr=(FORPTR)t;
+		   fr->fortyp=TFOR;
+		   fr->forlst=0;
@@ -231 +245 @@
-		   t->fornam=wdarg->argval;
+		   fr->fornam=wdarg->argval;
@@ -234 +248 @@
-			t->forlst=item(0);
+			fr->forlst=(COMPTR)item(0);
@@ -241 +255 @@
-		   t->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
+		   fr->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
@@ -248,4 +262,6 @@
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
@@ -262 +278 @@
-		   p=getstak(PARTYPE);
+		   p=(PARPTR)getstak(PARTYPE);
@@ -265 +281 @@
-		   t=makefork(0,p);
+		   t=makefork(0,(TREPTR)p);
@@ -272,0 +289 @@
+		/* fallthrough */
@@ -278,0 +296 @@
+		   REG COMPTR	c;
@@ -280,3 +298,4 @@
-		   t=getstak(COMTYPE);
-		   t->comio=io; /*initial io chain*/
-		   argtail = &(t->comarg);
+		   t=(TREPTR)getstak(COMTYPE);
+		   c=(COMPTR)t;
+		   c->comio=io; /*initial io chain*/
+		   argtail = &(c->comarg);
@@ -286 +305 @@
-			THEN	argp->argnxt=argset; argset=argp;
+			THEN	argp->argnxt=(ARGPTR)argset; argset=(ARGPTR *)argp;
@@ -291 +310 @@
-			THEN t->comio=inout(t->comio);
+			THEN c->comio=inout(c->comio);
@@ -295 +314 @@
-		   t->comtyp=TCOM; t->comset=argset; *argtail=0;
+		   c->comtyp=TCOM; c->comset=(ARGPTR)argset; *argtail=0;
@@ -301 +320 @@
-	IF io=inout(io)
+	IF (io=inout(io))
@@ -308 +327 @@
-LOCAL VOID	skipnl()
+LOCAL INT	skipnl()
@@ -334,0 +354 @@
+		/* fallthrough */
@@ -350 +370 @@
-	iop=getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
+	iop=(IOPTR)getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
@@ -365,0 +386 @@
+	INT		sym;
@@ -373,0 +395 @@
+	INT		sym;

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
+#define	space(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(T_SPC))
+#define eofmeta(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(_META|T_EOF))
+#define qotchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(T_QOT))
+#define eolchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(T_EOR|T_EOF))
+#define dipchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(T_DIP))
+#define subchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(T_SUB|T_QOT))
+#define escchar(c)	(((c)&QUOTE)==0 ANDF _ctype1[(int)(c)]&(T_ESC))
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
+#define	digit(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_DIG))
+#define fngchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_FNG))
+#define dolchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_AST|T_BRC|T_DIG|T_IDC|T_SHN))
+#define defchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_DEF))
+#define setchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_SET))
+#define digchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_AST|T_DIG))
+#define	letter(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_IDC))
+#define alphanum(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(_IDCH))
+#define astchar(c)	(((c)&QUOTE)==0 ANDF _ctype2[(int)(c)]&(T_AST))

% usr/src/cmd/sh/defs.h
@@ -97 +96,0 @@
-STRING		execs();
@@ -100 +98,0 @@
-STRING		copyto();
@@ -102 +99,0 @@
-STRING		staknam();
@@ -108,0 +106,20 @@
+INT		any(), builtin(), cf(), chkopen(), create(), estabf(),
+		execute(), expand(), getarg(), gmatch(), ignsig(),
+		length(), nextc(), options(), pathopen(), pop(),
+		readc(), readvar(), stoi(), syslook(), tmpfil(), word(),
+		alarm(), chdir(), close(), creat(), dup(), execve(),
+		fork(), getpid(), getuid(), gtty(), ioctl(), open(),
+		pause(), pipe(), read(), signal(), stat(), times(),
+		umask(), unlink(), wait(), write();
+VOID		assign(), assnum(), blank(), chkpipe(), chkpr(),
+		chktrap(), clearup(), copy(), dfault(), done(), error(),
+		execa(), execexp(), exitset(), exitsh(), failed(),
+		free(), getsig(), initf(), initio(), itos(), Ldup(),
+		makearg(), namscan(), newline(), oldsigs(), postclr(),
+		prn(), prp(), prt(), push(), rename(), replace(),
+		rmtemp(), setlist(), settmp(), sigchk(), stakchk(),
+		stdsigs(), subst(), tdystak(), trim(), clrsig(), exit();
+DOLPTR		freeargs();
+BYTPTR		setbrk();
+L_INT		lseek();
+STRING		sbrk();
@@ -139,9 +156,9 @@
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
@@ -150 +167 @@
-SYSTAB		reserved;
+extern SYSTAB	reserved;
@@ -158,3 +175,3 @@
-MSG		stdprompt;
-MSG		supprompt;
-MSG		profile;
+extern MSG	stdprompt;
+extern MSG	supprompt;
+extern MSG	profile;
@@ -172 +189 @@
-MSG		flagadr;
+extern MSG	flagadr;
@@ -179 +196 @@
-MSG		defpath;
+extern MSG	defpath;
@@ -182,7 +199,7 @@
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
@@ -191 +208 @@
-CHAR		tmpout[];
+extern CHAR	tmpout[];
@@ -200 +217 @@
-MSG		devnull;
+extern MSG	devnull;
@@ -242,2 +259,2 @@
-STRING		trapcom[];
-BOOL		trapflg[];
+extern STRING	trapcom[];
+extern BOOL	trapflg[];
@@ -247,3 +264,3 @@
-CHAR		numbuf[];
-MSG		export;
-MSG		readonly;
+extern CHAR	numbuf[];
+extern MSG	export;
+extern MSG	readonly;
@@ -253 +270 @@
-BOOL		execbrk;
+INT		execbrk;
@@ -258,25 +275,25 @@
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
@@ -284 +301 @@
-address	end[];
+extern address	end[];

% usr/src/cmd/sh/dup.h

% usr/src/cmd/sh/error.c
@@ -14,0 +15 @@
+VOID
@@ -19,0 +21 @@
+VOID
@@ -30,0 +33 @@
+VOID
@@ -40,0 +44 @@
+VOID
@@ -46,0 +51 @@
+VOID
@@ -64,0 +70 @@
+VOID
@@ -68 +74 @@
-	IF t=trapcom[0]
+	IF (t=trapcom[0])
@@ -75,0 +82 @@
+VOID

% usr/src/cmd/sh/expand.c
@@ -27 +27 @@
-PROC VOID	addg();
+LOCAL VOID	addg();
@@ -31,0 +32 @@
+	INT		rflg;
@@ -108 +109 @@
-	   WHILE c = *s
+	   WHILE (c = *s)
@@ -113,0 +115 @@
+INT
@@ -120 +122 @@
-	IF scc = *s++
+	IF (scc = *s++)
@@ -130 +132 @@
-		WHILE c = *p++
+		WHILE (c = *p++)
@@ -134 +136 @@
-			THEN	IF lc<=scc ANDF scc<=(*p++) THEN ok++ FI
+			THEN	IF lc<=scc ANDF scc<=((*p++)&STRIP) THEN ok++ FI
@@ -142,0 +145 @@
+		/* fallthrough */
@@ -168 +171 @@
-	WHILE c = *s1++
+	WHILE (c = *s1++)
@@ -176,2 +179,2 @@
-	WHILE *s2 = *s1++ DO s2++ OD
-	IF s1=as3
+	WHILE (*s2 = *s1++) DO s2++ OD
+	IF (s1=as3)
@@ -179 +182 @@
-		WHILE *s2++ = *++s1 DONE
+		WHILE (*s2++ = *++s1) DONE
@@ -183,0 +187 @@
+VOID
@@ -185 +189 @@
-	REG STRING	args;
+	REG ARGPTR	args;

% usr/src/cmd/sh/fault.c
@@ -26 +26 @@
-	THEN	IF setbrk(brkincr) == -1
+	THEN	IF setbrk(brkincr) == (BYTPTR)-1
@@ -38,0 +39 @@
+VOID
@@ -46,0 +48 @@
+INT
@@ -47,0 +50 @@
+	INT		n;
@@ -56,0 +60 @@
+VOID
@@ -57,0 +62 @@
+	INT		n;
@@ -65,0 +71 @@
+VOID
@@ -81,0 +88 @@
+VOID
@@ -91,0 +99 @@
+VOID
@@ -102 +110 @@
-		IF t=trapcom[i]
+		IF (t=trapcom[i])

% usr/src/cmd/sh/io.c
@@ -15,0 +16 @@
+VOID
@@ -25,0 +27 @@
+INT
@@ -36,0 +39 @@
+VOID
@@ -46,0 +50 @@
+INT
@@ -58,0 +63 @@
+VOID
@@ -66,0 +72 @@
+INT
@@ -75,0 +82 @@
+	return(0);
@@ -77,0 +85 @@
+VOID
@@ -87,0 +96 @@
+INT
@@ -96,0 +106 @@
+	return(0);
@@ -98,0 +109 @@
+INT
@@ -107,0 +119 @@
+VOID
@@ -116 +128 @@
-	IF iop=ioparg
+	IF (iop=ioparg)

% usr/src/cmd/sh/mac.h

% usr/src/cmd/sh/macro.c
@@ -14,0 +15,2 @@
+LOCAL INT	getch();
+LOCAL VOID	comsubst(), flush();
@@ -26,0 +29 @@
+	return(0);
@@ -29 +32 @@
-LOCAL	skipto(endch)
+LOCAL VOID	skipto(endch)
@@ -49 +52 @@
-LOCAL	getch(endch)
+LOCAL INT	getch(endch)
@@ -62 +65 @@
-		THEN	NAMPTR		n=NIL;
+		THEN	NAMPTR		n=(NAMPTR)NIL;
@@ -65 +68 @@
-			REG STRING	argp, v;
+			REG STRING	argp, v=0;
@@ -69 +72 @@
-			IF bra=(c==BRACE) THEN c=readc() FI
+			IF (bra=(c==BRACE)) THEN c=readc() FI
@@ -71 +74 @@
-			THEN	argp=relstak();
+			THEN	argp=(STRING)relstak();
@@ -83 +86 @@
-				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (dolg=0));
+				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (STRING)(dolg=0));
@@ -104 +107 @@
-				THEN	argp=relstak();
+				THEN	argp=(STRING)relstak();
@@ -115 +118 @@
-				THEN	LOOP WHILE c = *v++
+				THEN	LOOP WHILE (c = *v++)
@@ -168 +171 @@
-LOCAL	comsubst()
+LOCAL VOID	comsubst()
@@ -197 +200 @@
-	WHILE d=readc() DO pushstak(d|quote) OD
+	WHILE (d=readc()) DO pushstak(d|quote) OD
@@ -208,0 +212 @@
+VOID
@@ -218 +222 @@
-	WHILE c=(getch(DQUOTE)&STRIP)
+	WHILE (c=(getch(DQUOTE)&STRIP))
@@ -228 +232,2 @@
-LOCAL	flush(ot)
+LOCAL VOID	flush(ot)
+	INT		ot;

% usr/src/cmd/sh/main.c
@@ -25 +25 @@
-PROC VOID	exfile();
+LOCAL VOID	exfile();
@@ -29,0 +30 @@
+int
@@ -85 +86 @@
-	ELSE	*execargs=dolv;	/* for `ps' cmd */
+	ELSE	*execargs=(char *)dolv;	/* for `ps' cmd */
@@ -95 +96 @@
-	REG L_INT	mailtime = 0;
+	volatile L_INT	mailtime = 0;
@@ -149 +150 @@
-		execute(cmd(NL,MTFLG),0);
+		execute(cmd(NL,MTFLG),0,0,0);
@@ -153,0 +155 @@
+VOID
@@ -161,0 +164 @@
+VOID
@@ -167,0 +171 @@
+VOID

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
+LOCAL BOOL	chkid();
+LOCAL VOID	namwalk();
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
@@ -27,0 +29 @@
+INT
@@ -38 +40 @@
-	WHILE s=syscan->sysnam
+	WHILE (s=syscan->sysnam)
@@ -47,0 +50 @@
+VOID
@@ -86,0 +90 @@
+VOID
@@ -93,0 +98 @@
+VOID
@@ -102,0 +108 @@
+VOID
@@ -121 +127 @@
-	STKPTR		rel=relstak();
+	STKPTR		rel=(STKPTR)relstak();
@@ -152,0 +159 @@
+VOID
@@ -177 +184 @@
-	REG NAMPTR	*prev;
+	REG NAMPTR	*prev = 0;
@@ -194,2 +201,2 @@
-	nscan=alloc(sizeof *nscan);
-	nscan->namlft=nscan->namrgt=NIL;
+	nscan=(NAMPTR)alloc(sizeof *nscan);
+	nscan->namlft=nscan->namrgt=0;
@@ -217,0 +225 @@
+VOID
@@ -241 +249 @@
-	IF s=n->namval
+	IF (s=n->namval)
@@ -296,0 +305 @@
+	(void)n;
@@ -316 +325 @@
-	argnam = er = getstak(namec*BYTESPERWORD+BYTESPERWORD);
+	argnam = er = (STRING *)getstak(namec*BYTESPERWORD+BYTESPERWORD);

% usr/src/cmd/sh/name.h

% usr/src/cmd/sh/print.c
@@ -16,0 +17 @@
+VOID
@@ -20,0 +22 @@
+VOID
@@ -24,0 +27 @@
+VOID
@@ -37 +40 @@
-	IF s=as
+	IF (s=as)
@@ -49,0 +53 @@
+VOID
@@ -58 +62 @@
-	IF hr=t/60
+	IF (hr=t/60)
@@ -64,0 +69 @@
+VOID
@@ -70,0 +76 @@
+VOID
@@ -71,0 +78 @@
+	INT		n;
@@ -82,0 +90 @@
+INT
@@ -95,0 +104 @@
+	return(0);

% usr/src/cmd/sh/service.c
@@ -13 +13,3 @@
-PROC VOID	gsort();
+LOCAL VOID	gsort();
+LOCAL STRING	execs();
+LOCAL INT	split();
@@ -18 +20 @@
-STRING		sysmsg[];
+extern STRING	sysmsg[];
@@ -35 +37 @@
-	REG INT		iof, fd;
+	REG INT		iof, fd = -1;
@@ -80,0 +83 @@
+	return(0);
@@ -122 +125 @@
-		WHILE path=execs(path,t) DONE
+		WHILE (path=execs(path,t)) DONE
@@ -150,0 +154 @@
+		/* fallthrough */
@@ -153,0 +158 @@
+		/* fallthrough */
@@ -156,0 +162 @@
+		/* fallthrough */
@@ -159,0 +166 @@
+		/* fallthrough */
@@ -162,0 +170 @@
+		/* fallthrough */
@@ -172,0 +181 @@
+VOID
@@ -225 +234 @@
-		IF sig = w&0177
+		IF (sig = w&0177)
@@ -251,0 +261 @@
+VOID
@@ -259,2 +269,2 @@
-	IF p=at
-	THEN	WHILE c = *p
+	IF (p=at)
+	THEN	WHILE (c = *p)
@@ -277 +287 @@
-	REG ARGPTR	argp = Rcheat(gchain)&~ARGMK;
+	REG ARGPTR	argp = (ARGPTR)(Rcheat(gchain)&~ARGMK);
@@ -280 +290 @@
-	comargn=getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;
+	comargn=(STRING *)getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;
@@ -284 +294 @@
-		IF argp = argp->argnxt
+		IF (argp = argp->argnxt)
@@ -292 +302 @@
-		argp = Rcheat(argp)&~ARGMK;
+		argp = (ARGPTR)(Rcheat(argp)&~ARGMK);
@@ -330 +340 @@
-	IF c=ac
+	IF (c=ac)
@@ -358 +368 @@
-		IF c=expand((argp=endstak(argp))->argval,0)
+		IF (c=expand(((ARGPTR)(argp=endstak(argp)))->argval,0))
@@ -363 +373 @@
-		Lcheat(gchain) |= ARGMK;
+		gchain=(ARGPTR)(Rcheat(gchain)|ARGMK);

% usr/src/cmd/sh/setbrk.c
@@ -11,0 +12 @@
+BYTPTR
@@ -12,0 +14 @@
+	INT		incr;

% usr/src/cmd/sh/stak.c
@@ -54 +54 @@
-	oldstak=stakbot; stakbot=staktop=round(argp,BYTESPERWORD);
+	oldstak=stakbot; stakbot=staktop=(STKPTR)round(argp,BYTESPERWORD);
@@ -69,0 +70 @@
+VOID

% usr/src/cmd/sh/stak.h

% usr/src/cmd/sh/string.c
@@ -19 +19 @@
-	WHILE *b++ = *a++ DONE
+	WHILE (*b++ = *a++) DONE
@@ -29 +29 @@
-	WHILE d = *s++
+	WHILE (d = *s++)
@@ -53 +53 @@
-	IF s=as THEN WHILE *s++ DONE FI
+	IF (s=as) THEN WHILE *s++ DONE FI

% usr/src/cmd/sh/sym.h

% usr/src/cmd/sh/timeout.h

% usr/src/cmd/sh/word.c
@@ -11,0 +12 @@
+LOCAL INT	readb();
@@ -16,0 +18 @@
+INT
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
@@ -69,0 +73 @@
+INT
@@ -84,0 +89 @@
+INT
@@ -116 +121 @@
-LOCAL	readb()
+LOCAL INT	readb()

% usr/src/cmd/sh/xec.c
@@ -15 +15 @@
-SYSTAB		commands;
+extern SYSTAB	commands;
@@ -21,0 +22 @@
+INT
@@ -24,0 +26 @@
+	INT		execflg;
@@ -35 +37 @@
-		REG STRING	*com;
+		REG STRING	*com = 0;
@@ -43,0 +46 @@
+			COMPTR		c=(COMPTR)t;
@@ -47 +50 @@
-			IOPTR		io=t->treio;
+			IOPTR		io=c->comio;
@@ -49 +52 @@
-			argn = getarg(t);
+			argn = getarg(c);
@@ -53,2 +56,2 @@
-			IF (internal=syslook(com[0],commands)) ORF argn==0
-			THEN	setlist(t->comset, 0);
+			IF ((internal=syslook(com[0],commands)) ORF argn==0)
+			THEN	setlist(c->comset, 0);
@@ -87,0 +91 @@
+					/* fallthrough */
@@ -135,0 +140 @@
+					/* fallthrough */
@@ -139,0 +145 @@
+					/* fallthrough */
@@ -178 +184 @@
-					ELIF t->comset==0
+					ELIF c->comset==0
@@ -185,0 +192 @@
+					/* fallthrough */
@@ -205 +212 @@
-                                                int c, i
+						int c, i;
@@ -231 +238 @@
-			ELIF t->treio==0
+			ELIF c->comio==0
@@ -234,0 +242 @@
+			/* fallthrough */
@@ -292 +300 @@
-				THEN	execute(t->forktre,1);
+				THEN	execute(((FORKPTR)t)->forktre,1,0,0);
@@ -294 +302 @@
-				THEN	setlist(t->comset,N_EXPORT);
+				THEN	setlist(((COMPTR)t)->comset,N_EXPORT);
@@ -298,0 +307 @@
+			break;
@@ -302 +311 @@
-			execute(t->partre,execflg);
+			execute(((PARPTR)t)->partre,execflg,0,0);
@@ -303,0 +313 @@
+			/* fallthrough */
@@ -306,0 +317 @@
+			   REG LSTPTR	l=(LSTPTR)t;
@@ -308,2 +319,2 @@
-			   IF execute(t->lstlef, 0, pf1, pv)==0
-			   THEN	execute(t->lstrit, execflg, pv, pf2);
+			   IF execute(l->lstlef, 0, pf1, pv)==0
+			   THEN	execute(l->lstrit, execflg, pv, pf2);
@@ -316,2 +327,2 @@
-			execute(t->lstlef,0);
-			execute(t->lstrit,execflg);
+			execute(((LSTPTR)t)->lstlef,0,0,0);
+			execute(((LSTPTR)t)->lstrit,execflg,0,0);
@@ -321,2 +332,2 @@
-			IF execute(t->lstlef,0)==0
-			THEN	execute(t->lstrit,execflg);
+			IF execute(((LSTPTR)t)->lstlef,0,0,0)==0
+			THEN	execute(((LSTPTR)t)->lstrit,execflg,0,0);
@@ -327,2 +338,2 @@
-			IF execute(t->lstlef,0)!=0
-			THEN	execute(t->lstrit,execflg);
+			IF execute(((LSTPTR)t)->lstlef,0,0,0)!=0
+			THEN	execute(((LSTPTR)t)->lstrit,execflg,0,0);
@@ -334 +345,2 @@
-			   NAMPTR	n = lookup(t->fornam);
+			   REG FORPTR	f=(FORPTR)t;
+			   NAMPTR	n = lookup(f->fornam);
@@ -338 +350 @@
-			   IF t->forlst==0
+			   IF f->forlst==0
@@ -343 +355 @@
-				   trim((args=scan(getarg(t->forlst)))[0]);
+				   trim((args=scan(getarg(f->forlst)))[0]);
@@ -349 +361 @@
-				execute(t->fortre,0);
+				execute(f->fortre,0,0,0);
@@ -360,0 +373 @@
+			   REG WHPTR	w=(WHPTR)t;
@@ -364,2 +377,2 @@
-			   WHILE execbrk==0 ANDF (execute(t->whtre,0)==0)==(type==TWH)
-			   DO i=execute(t->dotre,0);
+			   WHILE execbrk==0 ANDF (execute(w->whtre,0,0,0)==0)==(type==TWH)
+			   DO i=execute(w->dotre,0,0,0);
@@ -374,3 +387,3 @@
-			IF execute(t->iftre,0)==0
-			THEN	execute(t->thtre,execflg);
-			ELSE	execute(t->eltre,execflg);
+			IF execute(((IFPTR)t)->iftre,0,0,0)==0
+			THEN	execute(((IFPTR)t)->thtre,execflg,0,0);
+			ELSE	execute(((IFPTR)t)->eltre,execflg,0,0);
@@ -382,2 +395,3 @@
-			   REG STRING	r = mactrim(t->swarg);
-			   t=t->swlst;
+			   REG SWPTR	s=(SWPTR)t;
+			   REG STRING	r = mactrim(s->swarg);
+			   t=(TREPTR)s->swlst;
@@ -385 +399,2 @@
-			   DO	ARGPTR		rex=t->regptr;
+			   DO	REG REGPTR	re=(REGPTR)t;
+				ARGPTR		rex=re->regptr;
@@ -389 +404 @@
-					THEN	execute(t->regcom,0);
+					THEN	execute(re->regcom,0,0,0);
@@ -394 +409 @@
-				IF t THEN t=t->regnxt FI
+				IF t THEN t=(TREPTR)re->regnxt FI
@@ -407,0 +423 @@
+VOID
@@ -415 +431 @@
-	THEN	estabf(s); fb.feval=f;
+	THEN	estabf(s); fb.feval=(STRING *)f;
@@ -419 +435 @@
-	execute(cmd(NL, NLFLG|MTFLG),0);
+	execute(cmd(NL, NLFLG|MTFLG),0,0,0);

% usr/src/cmd/sleep.c
@@ -0,0 +1,2 @@
+#include <stdio.h>
+int
@@ -1,0 +4 @@
+int argc;
@@ -13 +16 @@
-	while(c = *s++) {
+	while((c = *s++)) {

% usr/src/cmd/sort.c
@@ -5,0 +6 @@
+#define	qsort	sort_qsort
@@ -27 +27,0 @@
-int	term();
@@ -160,3 +160,3 @@
-	0,0,
-	0,-1,
-	0,0
+	{0,0},
+	{0,-1},
+	{0,0}
@@ -168,0 +169,2 @@
+void	copyproto(), field(), diag(), safeoutfil(), sort(), newfile(), merge(), oldfile(), disorder(), cant(), term(), qsort();
+int	rline(), blank(), number();
@@ -169,0 +172 @@
+int
@@ -170,0 +174 @@
+int	argc;
@@ -173 +177 @@
-	register a;
+	register int a;
@@ -239,0 +244 @@
+	ep = (char *)lspace + MEM;
@@ -245 +250 @@
-	nlines /= (5*(sizeof(char *)/sizeof(char)));
+	nlines /= (5*(sizeof(char *)));
@@ -272 +277 @@
-	for(a = mflg|cflg?0:eargc; a+N<nfiles || unsafeout&&a<eargc; a=i) {
+	for(a = (mflg|cflg)?0:eargc; a+N<nfiles || (unsafeout&&a<eargc); a=i) {
@@ -286,0 +292 @@
+void
@@ -291 +297 @@
-	register c;
+	register int c;
@@ -349,0 +356 @@
+void
@@ -350,0 +358 @@
+int	a, b;
@@ -354 +362 @@
-	register	i;
+	register int	i;
@@ -392 +400 @@
-	muflg = mflg & uflg | cflg;
+	muflg = (mflg & uflg) | cflg;
@@ -443,0 +452 @@
+int
@@ -450 +459 @@
-	register c;
+	register int c;
@@ -465,0 +475 @@
+void
@@ -475,0 +486 @@
+void
@@ -489,0 +501 @@
+int	i;
@@ -492 +504 @@
-	if(i < eargc)
+	if(i < eargc) {
@@ -496,0 +509 @@
+	}
@@ -502,0 +516 @@
+void
@@ -514,0 +529 @@
+void
@@ -532,0 +548 @@
+void
@@ -540,0 +557 @@
+void
@@ -549,0 +567 @@
+void
@@ -552 +570 @@
-	register i;
+	register int i;
@@ -564,0 +583 @@
+int
@@ -606,2 +625,2 @@
-			for(ipa = pa; ipa<la&&isdigit(*ipa); ipa++) ;
-			for(ipb = pb; ipb<lb&&isdigit(*ipb); ipb++) ;
+			for(ipa = pa; ipa<la&&isdigit(*ipa&0377); ipa++) ;
+			for(ipb = pb; ipb<lb&&isdigit(*ipb&0377); ipb++) ;
@@ -613 +632 @@
-					if(b = *--ipb - *--ipa)
+					if((b = *--ipb - *--ipa))
@@ -627,3 +646,3 @@
-				while(pa<la && isdigit(*pa)
-				   && pb<lb && isdigit(*pb))
-					if(a = *pb++ - *pa++)
+				while(pa<la && isdigit(*pa&0377)
+				   && pb<lb && isdigit(*pb&0377))
+					if((a = *pb++ - *pa++))
@@ -631 +650 @@
-			while(pa<la && isdigit(*pa))
+			while(pa<la && isdigit(*pa&0377))
@@ -634 +653 @@
-			while(pb<lb && isdigit(*pb))
+			while(pb<lb && isdigit(*pb&0377))
@@ -642 +661 @@
-		while(ignore[*pa])
+		while(ignore[(signed char)*pa])
@@ -644 +663 @@
-		while(ignore[*pb])
+		while(ignore[(signed char)*pb])
@@ -646 +665 @@
-		if(pa>=la || *pa=='\n')
+		if(pa>=la || *pa=='\n') {
@@ -649,0 +669 @@
+		}
@@ -652 +672 @@
-		if((sa = code[*pb++]-code[*pa++]) == 0)
+		if((sa = code[(signed char)*pb++]-code[(signed char)*pa++]) == 0)
@@ -660,0 +681 @@
+int
@@ -680,0 +702 @@
+int	j;
@@ -682 +704 @@
-	register i;
+	register int i;
@@ -724,0 +747 @@
+void
@@ -727 +750 @@
-	register i;
+	register int i;
@@ -732 +755 @@
-	for(i=0; i<sizeof(proto)/sizeof(*p); i++)
+	for(i=0; i<(int)(sizeof(proto)/sizeof(*p)); i++)
@@ -735,0 +759 @@
+void
@@ -736,0 +761 @@
+int	k;
@@ -740 +765 @@
-	register d;
+	register int d;
@@ -790,0 +816 @@
+			/* fallthrough */
@@ -797,0 +824 @@
+int
@@ -805 +832 @@
-	while(isdigit(*pa)) {
+	while(isdigit(*pa&0377)) {
@@ -811,0 +839 @@
+int
@@ -812,0 +841 @@
+int	c;
@@ -821,0 +851 @@
+void

% usr/src/cmd/sp.c
@@ -10,0 +11 @@
+int
@@ -13 +14 @@
-	register c;
+	register int c;
@@ -19,0 +21 @@
+				/* fallthrough */
@@ -33,0 +36 @@
+void
@@ -34,0 +38 @@
+int	ntab;
@@ -38,0 +43 @@
+void
@@ -42,0 +48 @@
+int
@@ -43,0 +50 @@
+int	argc;

% usr/src/cmd/spline.c
@@ -141 +141,2 @@
-rhs(i){
+rhs(i)
+	int i;{
@@ -148,0 +150 @@
+int
@@ -205 +207 @@
-		for(j=m;j>0||i==0&&j==0;j--){	/* interpolate */
+		for(j=m;j>0||(i==0&&j==0);j--){	/* interpolate */
@@ -215,0 +218,2 @@
+int	getfloat(), numb();
+void
@@ -221,0 +226 @@
+int
@@ -225 +230 @@
-	register c;
+	register int c;
@@ -260,0 +266 @@
+void
@@ -269,0 +276 @@
+int
@@ -270,0 +278 @@
+	int argc;
@@ -319,0 +328 @@
+int
@@ -328 +337 @@
-	if(!('0'<=c&&c<='9' || c=='-' || c== '.' )) return(0);
+	if(!(('0'<=c&&c<='9') || c=='-' || c== '.' )) return(0);

% usr/src/cmd/split.c
@@ -10,0 +11 @@
+int
@@ -11,0 +13 @@
+int argc;
@@ -14 +16 @@
-	register i, c, f;
+	register int i, c, f;
@@ -56 +58 @@
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
@@ -179,0 +135,3 @@
+int	eq();
+void	prmodes(), delay(), prspeed();
+int
@@ -180,0 +139 @@
+int	argc;
@@ -231,0 +191 @@
+int
@@ -248,0 +209 @@
+void
@@ -251 +212 @@
-	register m;
+	register int m;
@@ -258 +219 @@
-	if (mode.sg_erase < ' ')
+	if ((mode.sg_erase&0377) < ' ')
@@ -262 +223 @@
-	if (mode.sg_kill < ' ')
+	if ((mode.sg_kill&0377) < ' ')
@@ -283,0 +245 @@
+void
@@ -284,0 +247 @@
+int m;
@@ -295,0 +259 @@
+void
@@ -296,0 +261 @@
+int s;

% usr/src/cmd/su.c
@@ -8,0 +9 @@
+int

% usr/src/cmd/sum.c
@@ -6,0 +7 @@
+int
@@ -7,0 +9 @@
+int argc;
@@ -11 +13 @@
-	register i, c;
+	register int i, c;

% usr/src/cmd/sync.c
@@ -0,0 +1,2 @@
+void sync();
+int

% usr/src/cmd/tabs.c
@@ -45,0 +46,2 @@
+void delay(), escape(), nl(), dasi450(), tty37(), dasi300(), tn300(), hp2645(), misc();
+int
@@ -56,0 +59 @@
+int
@@ -98,0 +102 @@
+void
@@ -99,0 +104 @@
+int n;
@@ -105,0 +111 @@
+void
@@ -106,0 +113 @@
+int n;
@@ -110,0 +118 @@
+void
@@ -111,0 +120 @@
+int n;
@@ -124,0 +134 @@
+void
@@ -125,0 +136 @@
+int n;
@@ -133,0 +145 @@
+void
@@ -134,0 +147 @@
+int c;
@@ -138,0 +152 @@
+void
@@ -139,0 +154 @@
+int n;
@@ -143,0 +159 @@
+void
@@ -152,0 +169 @@
+void
@@ -162,0 +180 @@
+void
@@ -167,0 +186 @@
+void
@@ -172,0 +192 @@
+void
@@ -182,0 +203 @@
+void
@@ -190,0 +212 @@
+void

% usr/src/cmd/tail.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -19,0 +21,2 @@
+int digit();
+int
@@ -20,0 +24 @@
+int argc;
@@ -24,2 +28,2 @@
-	register i,j,k;
-	char *p;
+	register int i,j,k;
+	char *p = 0;
@@ -31 +35 @@
-	if(argc<=1 || *arg!='-'&&*arg!='+') {
+	if(argc<=1 || (*arg!='-'&&*arg!='+')) {
@@ -180,0 +185 @@
+int
@@ -181,0 +187 @@
+int c;

% usr/src/cmd/tar/tar.c
@@ -7 +7,2 @@
-char	*sprintf();
+void	usage(), dorep(), getdir(), passtape(), putfile(), doxtract(), dotable(), putempty(), longt(), pmode(), select(), checkdir(), tomodes(), done(), getwdir(), backtape(), flushtape(), copy();
+int	endtape(), checksum(), checkw(), response(), checkupdate(), prefix(), cmp(), readtape(), writetape();
@@ -54,0 +56 @@
+int
@@ -60 +62 @@
-	int onintr(), onquit(), onhup(), onterm();
+	void onintr(), onquit(), onhup(), onterm();
@@ -194,0 +197 @@
+void
@@ -200,0 +204 @@
+void
@@ -255,0 +260 @@
+int
@@ -265,0 +271 @@
+void
@@ -291,0 +298 @@
+void
@@ -306,0 +314 @@
+void
@@ -336 +344 @@
-		for (i = 0, cp = buf; *cp++ = longname[i++];);
+		for (i = 0, cp = buf; (*cp++ = longname[i++]););
@@ -441,0 +450 @@
+void
@@ -517,0 +527 @@
+void
@@ -533,0 +544 @@
+void
@@ -543,0 +555 @@
+void
@@ -580,0 +593 @@
+void
@@ -589,0 +603 @@
+void
@@ -602,0 +617 @@
+void
@@ -625,0 +641 @@
+void
@@ -631,0 +648 @@
+void
@@ -637,0 +655 @@
+void
@@ -643,0 +662 @@
+void
@@ -649,0 +669 @@
+void
@@ -663,0 +684 @@
+int
@@ -666 +687 @@
-	register i;
+	register int i;
@@ -673 +694 @@
-		i += *cp;
+		i += (signed char)*cp;
@@ -676,0 +698 @@
+int
@@ -678,0 +701 @@
+int c;
@@ -692,0 +716 @@
+int
@@ -703,0 +728 @@
+int
@@ -724,0 +750 @@
+void
@@ -725,0 +752 @@
+int n;
@@ -730,0 +758 @@
+int
@@ -741,0 +770 @@
+void
@@ -774 +803 @@
-	register i;
+	register int i;
@@ -787,0 +817 @@
+int n;
@@ -789 +819 @@
-	register i, j;
+	register int i, j;
@@ -829,0 +860 @@
+int
@@ -831,0 +863 @@
+int n;
@@ -833 +865 @@
-	register i;
+	register int i;
@@ -845,0 +878 @@
+int
@@ -881,0 +915 @@
+int
@@ -905,0 +940 @@
+void
@@ -918,0 +954 @@
+void
@@ -923,0 +960 @@
+void
@@ -927 +964 @@
-	register i;
+	register int i;

% usr/src/cmd/tc.c
@@ -8 +8,2 @@
-#define	oput(c) if (pgskip==0) putchar(c); else;
+#define	atoi	tcatoi
+#define	oput(c) do { if (pgskip==0) putchar(c); } while (0)
@@ -56,0 +58,3 @@
+void lig(), init(), kwait(), callunix(), sendpt();
+int readch(), atoi(), getch();
+int
@@ -61 +65 @@
-	register i, j;
+	register int i, j;
@@ -63 +67 @@
-	extern ex();
+	extern void ex();
@@ -70 +74 @@
-				if(i = atoi())pl = i/3;
+				if((i = atoi()))pl = i/3;
@@ -83,2 +87,2 @@
-				if(i = atoi())mpy = i;
-				if(i = atoi())div = i;
+				if((i = atoi()))mpy = i;
+				if((i = atoi()))div = i;
@@ -225,0 +230 @@
+void
@@ -229 +234 @@
-	register i, j;
+	register int i, j;
@@ -246,0 +252 @@
+void
@@ -262,0 +269 @@
+void
@@ -272,0 +280 @@
+void
@@ -299,0 +308 @@
+void
@@ -316,0 +326 @@
+int
@@ -321,0 +332 @@
+void
@@ -327 +338 @@
-	xb = ((xx & 03) + ((yy<<2) & 014) & 017);
+	xb = (((xx & 03) + ((yy<<2) & 014)) & 017);
@@ -344,0 +356 @@
+int
@@ -347 +359 @@
-	register i, j, acc;
+	register int i, j, acc;
@@ -379 +391 @@
-	register i, j;
+	register int i, j;
@@ -402,0 +415 @@
+int
@@ -404 +417 @@
-	register i;
+	register int i;
@@ -414 +427 @@
-char *asctab[128] {
+char *asctab[128] = {

% usr/src/cmd/tee.c
@@ -18 +18 @@
-extern errno;
+extern int errno;
@@ -19,0 +20 @@
+int	fstat(), open(), creat(), stat(), read(), write();
@@ -20,0 +22,2 @@
+void stash(), puts();
+int
@@ -21,0 +25 @@
+int argc;
@@ -24 +28 @@
-	int register r,w,p;
+	register int r,w,p;
@@ -70 +74 @@
-					return;
+					return(0);
@@ -78,0 +83 @@
+void
@@ -79,0 +85 @@
+int p;
@@ -89,0 +96 @@
+void

% usr/src/cmd/test.c
@@ -17,0 +18,3 @@
+int exp(), e1(), e2(), e3(), tio(), ftype(), fsizep(), length();
+void synbad();
+int
@@ -18,0 +22 @@
+int argc;
@@ -32 +36 @@
-char *nxtarg(mt) {
+char *nxtarg(int mt) {
@@ -43,0 +48 @@
+int
@@ -52,0 +58 @@
+int
@@ -61,0 +68 @@
+int
@@ -68,0 +76 @@
+int
@@ -97 +105 @@
-	if(EQ(a, "-t"))
+	if(EQ(a, "-t")) {
@@ -101,0 +110 @@
+	}
@@ -136,0 +146 @@
+	return(0);
@@ -138,0 +149 @@
+int
@@ -151,0 +163 @@
+int
@@ -163,0 +176 @@
+int
@@ -172,0 +186 @@
+void
@@ -182,0 +197 @@
+int

% usr/src/cmd/time.c
@@ -10,0 +11,2 @@
+void printt();
+int
@@ -11,0 +14 @@
+int argc;
@@ -16 +19 @@
-	register p;
+	register int p;
@@ -52,0 +56 @@
+void
@@ -58 +62 @@
-	register i;
+	register int i;

% usr/src/cmd/tk.c
@@ -36,0 +37,2 @@
+void	init(), sendpt(), kwait(), execom();
+int
@@ -41,2 +43,2 @@
-	register i, j;
-	extern ex();
+	register int i, j;
+	extern void ex();
@@ -47 +49 @@
-				if (i = atoi(&argv[0][2]))
+				if ((i = atoi(&argv[0][2])))
@@ -49 +51 @@
-					yyll = MAXY + 1 - pl;
+				yyll = MAXY + 1 - pl;
@@ -52 +54 @@
-				if (i = atoi(&argv[0][1])) {
+				if ((i = atoi(&argv[0][1]))) {
@@ -75,0 +78 @@
+			/* fallthrough */
@@ -152,0 +156 @@
+void
@@ -170,0 +175 @@
+void
@@ -179,0 +185 @@
+void
@@ -182 +188 @@
-	register c;
+	register int c;
@@ -198,0 +205 @@
+void
@@ -217,0 +225 @@
+void
@@ -218,0 +227 @@
+int a;
@@ -220 +229 @@
-	register zz;
+	register int zz;
@@ -228 +237 @@
-	xb = ((xx & 03) + ((zz<<2) & 014) & 017);
+	xb = (((xx & 03) + ((zz<<2) & 014)) & 017);

% usr/src/cmd/touch.c
@@ -3,0 +4,2 @@
+void touch();
+int
@@ -24,0 +27 @@
+void
@@ -33 +36 @@
-if( stat(name,&stbuff) < 0)
+if( stat(name,&stbuff) < 0) {
@@ -40,0 +44 @@
+	}

% usr/src/cmd/tp/tp.h
@@ -72 +72,3 @@
-int	(*command)();
+void	(*command)();
+void	optap(), setcom(), useerr(), check(), done(), encode(), decode(), clrdir(), clrent(), rddir(), wrdir(), tread(), twrite(), rseek(), wseek(), seekerr(), getfiles(), expand(), fserr(), callout(), swabdir(), gettape(), delete(), update(), update1(), phserr(), bitmap(), setmap(), maperr(), usage(), taboc(), extract();
+int	verify();

% usr/src/cmd/tp/tp0.c

% usr/src/cmd/tp/tp1.c
@@ -1,0 +2 @@
+#include <stdio.h>
@@ -2,0 +4 @@
+int
@@ -3,0 +6 @@
+int argc;
@@ -7 +10 @@
-	extern cmd(), cmr(),cmx(), cmt();
+	extern void cmd(), cmr(),cmx(), cmt();
@@ -15 +18 @@
-		while (c = *ptr++) switch(c)  {
+		while ((c = *ptr++)) switch(c)  {
@@ -64,0 +68 @@
+void
@@ -67 +71 @@
-	extern cmr();
+	extern void cmr();
@@ -88,0 +93 @@
+void
@@ -90 +95 @@
-int (*newcom)();
+void (*newcom)();
@@ -92 +97 @@
-	extern cmr();
+	extern void cmr();
@@ -97,0 +103 @@
+void
@@ -104 +110 @@
-/*/* COMMANDS */
+/* COMMANDS */
@@ -105,0 +112 @@
+void
@@ -108 +115 @@
-	extern delete();
+	extern void delete();
@@ -117,0 +125 @@
+void
@@ -126,0 +135 @@
+void
@@ -129 +138 @@
-	extern taboc();
+	extern void taboc();
@@ -138,0 +148 @@
+void
@@ -141 +151 @@
-	extern extract();
+	extern void extract();
@@ -148,0 +159 @@
+void
@@ -154,0 +166 @@
+void
@@ -160,0 +173 @@
+void
@@ -168 +181 @@
-	register n;
+	register int n;
@@ -187,0 +201 @@
+void

% usr/src/cmd/tp/tp2.c
@@ -9,0 +10 @@
+void
@@ -12 +13 @@
-	register j, *p;
+	register int j, *p;
@@ -19,0 +21 @@
+void
@@ -23 +25 @@
-	register *p, j;
+	register int *p, j;
@@ -37,0 +40 @@
+void
@@ -43 +46 @@
-	struct tent  *tptr;
+	struct tent  *tptr = &tpentry[0];
@@ -68 +71 @@
-		for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+		for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@ -92 +95 @@
-	if(sum != 0)
+	if(sum != 0) {
@@ -101,0 +105 @@
+	}
@@ -105,0 +110 @@
+void
@@ -149 +154 @@
-				for(i=0;i<sizeof(struct tent)/sizeof(short)-1;i++)
+				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short))-1;i++)
@@ -156 +161 @@
-				for(i=0;i<sizeof(struct tent)/sizeof(short);i++)
+				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
@@ -163,0 +169 @@
+void
@@ -166 +172 @@
-	register j, *ptr;
+	register int j, *ptr;
@@ -177,0 +184 @@
+void
@@ -186,0 +194 @@
+void
@@ -187,0 +196 @@
+int blk;
@@ -192,0 +202 @@
+void
@@ -193,0 +204 @@
+int blk;
@@ -195 +206 @@
-	register amt, b;
+	register int amt, b;
@@ -206,0 +218 @@
+void
@@ -212,0 +225 @@
+int
@@ -213,0 +227 @@
+int key;
@@ -215 +229 @@
-	register c;
+	register int c;
@@ -234,0 +249 @@
+void
@@ -247,0 +263 @@
+void
@@ -276,0 +293 @@
+void
@@ -282,0 +300 @@
+void
@@ -340,0 +359 @@
+void

% usr/src/cmd/tp/tp3.c
@@ -1,0 +2 @@
+#include <stdio.h>
@@ -2,0 +4 @@
+void
@@ -4 +6 @@
-int (*how)();
+void (*how)();
@@ -32,0 +35 @@
+void
@@ -40,0 +44 @@
+void
@@ -44 +48 @@
-	register b, last;
+	register int b, last;
@@ -70,0 +75 @@
+void
@@ -74 +79 @@
-	register index;
+	register int index;
@@ -101 +106 @@
-		if (index = d->d_size % BSIZE) {
+		if ((index = d->d_size % BSIZE)) {
@@ -109,0 +115 @@
+void
@@ -113,0 +120 @@
+void
@@ -117 +124 @@
-	register count;
+	register int count;
@@ -129,0 +137 @@
+void
@@ -140 +148 @@
-	if ((c += block) >= tapsiz)		maperr();
+	if ((c += block) >= (unsigned)tapsiz)		maperr();
@@ -148,0 +157 @@
+void
@@ -155,0 +165 @@
+void
@@ -158 +168 @@
-	register reg,count;
+	register int reg,count;
@@ -160 +170 @@
-	static lused;
+	static int lused;
@@ -189,0 +200 @@
+void
@@ -193,2 +204,2 @@
-	register  mode;
-	register *m;
+	register int  mode;
+	register int *m;
@@ -196 +207 @@
-	int count, *localtime();
+	int count;
@@ -215 +226 @@
-		m = localtime(&dd->d_time);
+		m = (int *)localtime(&dd->d_time);
@@ -221,0 +233 @@
+void
@@ -225 +237 @@
-	register count, id;
+	register int count, id;
@@ -238 +250 @@
-	if (count = d->d_size % BSIZE) {
+	if ((count = d->d_size % BSIZE)) {

% usr/src/cmd/tp/tp_defs.h usr/include/tp_defs.h

% usr/src/cmd/tr.c
@@ -11,0 +12 @@
+int	next(), nextc();
@@ -12,0 +14 @@
+int
@@ -13,0 +16 @@
+int	argc;
@@ -16 +19 @@
-	register i;
+	register int i;
@@ -18 +21 @@
-	register c, d;
+	register int c, d;
@@ -50 +53 @@
-		while(c = next(&string1))
+		while((c = next(&string1)))
@@ -71 +74 @@
-	while(d = next(&string2))
+	while((d = next(&string2)))
@@ -81 +84 @@
-		if(c = code[c&0377]&0377)
+		if((c = code[c&0377]&0377))
@@ -87,0 +91 @@
+int
@@ -113,0 +118 @@
+int
@@ -117 +122 @@
-	register c, i, n;
+	register int c, i, n;

% usr/src/cmd/tsort.c
@@ -8,0 +9 @@
+#define index tindex
@@ -32,0 +34,2 @@
+int present(), anypred(), cmp();
+void error(), note();
@@ -37,0 +41 @@
+int
@@ -38,0 +43 @@
+int	argc;
@@ -85,0 +91 @@
+int
@@ -97,0 +104 @@
+int
@@ -129 +136 @@
-	while(*t++ = *s++);
+	while((*t++ = *s++));
@@ -132,0 +140 @@
+int
@@ -144,0 +153 @@
+void
@@ -151,0 +161 @@
+void
@@ -174 +184 @@
-				error("error 1");
+				error("error 1",empty);
@@ -185 +195 @@
-				error("error 2");
+				error("error 2",empty);

% usr/src/cmd/tty.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -6,0 +8 @@
+int
@@ -7,0 +10 @@
+int	argc;

% usr/src/cmd/umount.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -8,0 +10 @@
+int
@@ -9,0 +12 @@
+int argc;
@@ -43 +46 @@
-				for (p1 = mp->file; p1 < &mp->file[NAMSIZ*2];)
+				for (p1 = (char *)mp; p1 < (char *)(mp+1);)

% usr/src/cmd/uniq.c
@@ -11,0 +12,2 @@
+int	gline(), equal();
+void	pline(), printe();
@@ -12,0 +15 @@
+int
@@ -21 +24 @@
-			if (isdigit(argv[1][1]))
+			if (isdigit(argv[1][1]&0377))
@@ -64,0 +68 @@
+int
@@ -68 +72 @@
-	register c;
+	register int c;
@@ -78,0 +83 @@
+void
@@ -103,0 +109 @@
+int
@@ -123 +129 @@
-	register nf, nl;
+	register int nf, nl;
@@ -136,0 +143 @@
+void

% usr/src/cmd/units.c
@@ -8 +8,2 @@
-int	fperr();
+void	fperr(), init(), units();
+int	convr(), pu(), lookup(), equal(), get();
@@ -13 +14 @@
-	char	dim[NDIM];
+	signed char	dim[NDIM];
@@ -19 +20 @@
-	char	dim[NDIM];
+	signed char	dim[NDIM];
@@ -29,17 +30,17 @@
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
@@ -51,0 +53 @@
+int
@@ -52,0 +55 @@
+int argc;
@@ -55 +58 @@
-	register i;
+	register int i;
@@ -108,0 +112 @@
+void
@@ -113 +117 @@
-	register f, i;
+	register int f, i;
@@ -128,0 +133 @@
+int
@@ -129,0 +135 @@
+int u, i, f;
@@ -140 +146 @@
-			return(2);
+		return(2);
@@ -146,0 +153 @@
+int
@@ -151 +158 @@
-	register c;
+	register int c;
@@ -197,0 +205 @@
+int
@@ -198,0 +207 @@
+int den, c;
@@ -204 +213 @@
-	register i;
+	register int i;
@@ -230 +239 @@
-	for(i=0; cp1 = prefix[i].pname; i++) {
+	for(i=0; (cp1 = prefix[i].pname); i++) {
@@ -251,0 +261 @@
+int
@@ -264,0 +275 @@
+void
@@ -291 +302 @@
-		printf("%l units; %l bytes\n\n", i, cp-names);
+		printf("%d units; %d bytes\n\n", i, cp-names);
@@ -361 +372 @@
-	register c, i, dp;
+	register int c, i, dp;
@@ -414,0 +426 @@
+int
@@ -417 +429 @@
-	register c;
+	register int c;
@@ -419 +431 @@
-	if(c=peekc) {
+	if((c=peekc)) {
@@ -458,0 +471 @@
+void

% usr/src/cmd/update.c
@@ -6,0 +7 @@
+#include <stdio.h>
@@ -14,0 +16,2 @@
+void dosync();
+int
@@ -30,0 +34 @@
+void

% usr/src/cmd/vpr.c
@@ -24 +24 @@
-char	chrtab[][16];
+char	chrtab[];
@@ -26,0 +27 @@
+int	send(), getline(); void putline(), banner();
@@ -27,0 +29 @@
+int
@@ -28,0 +31 @@
+int argc;
@@ -71,0 +75 @@
+int
@@ -74 +78 @@
-	register nskipped;
+	register int nskipped;
@@ -96,0 +101 @@
+int
@@ -99 +104 @@
-	register col, maxcol, c;
+	register int col, maxcol, c;
@@ -174,0 +180 @@
+void
@@ -175,0 +182 @@
+int ff;
@@ -178,2 +185,2 @@
-	register c;
-	extern errno;
+	register int c;
+	extern int errno;
@@ -183 +190 @@
-	while (c = *lp++)
+	while ((c = *lp++))
@@ -204,0 +212 @@
+void
@@ -219 +227 @@
-			t = chrtab[*sp - ' '][i];
+			t = chrtab[(*sp - ' ')*16 + i];
@@ -235 +243 @@
-char	chrtab[][16] = {
+char	chrtab[] = {

% usr/src/cmd/wall.c
@@ -10,0 +11,2 @@
+void sendmes();
+int
@@ -11,0 +14 @@
+int argc;
@@ -14 +17 @@
-	register i;
+	register int i;
@@ -42,0 +46 @@
+void
@@ -46 +50 @@
-	register i;
+	register int i;

% usr/src/cmd/wc.c
@@ -4,0 +5,2 @@
+void wcp();
+int
@@ -5,0 +8 @@
+int argc;
@@ -68,0 +72 @@
+void

% usr/src/cmd/who.c
@@ -12,0 +13,2 @@
+void putline();
+int
@@ -13,0 +16 @@
+int argc;
@@ -16 +19 @@
-	register char *tp, *s;
+	register char *tp = 0, *s;
@@ -54,0 +58 @@
+void

% usr/src/cmd/write.c
@@ -23,2 +23,2 @@
-int	eof();
-int	timout();
+void	eof();
+void	timout(), ex(), sigs();
@@ -26,0 +27 @@
+int
@@ -27,0 +29 @@
+int argc;
@@ -31 +33 @@
-	register i;
+	register int i;
@@ -139,0 +142 @@
+void
@@ -146,0 +150 @@
+void
@@ -153,0 +158 @@
+void
@@ -157 +162 @@
-	register i;
+	register int i;
@@ -176,0 +182 @@
+void
@@ -180 +186 @@
-	register i;
+	register int i;

% usr/src/cmd/yes.c
@@ -0,0 +1,2 @@
+#include <stdio.h>
+int
@@ -1,0 +4 @@
+int	argc;

% usr/src/games/arithmetic.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -12,0 +14,2 @@
+int	getnum(), random(), skrand();
+void	getline(), score();
@@ -13,0 +17 @@
+int
@@ -14,0 +19 @@
+int argc;
@@ -20 +25 @@
-	extern	delete();
+	extern	void delete();
@@ -32 +37 @@
-			while(types[dif] = argv[1][dif])
+			while((types[dif] = argv[1][dif]))
@@ -120,0 +126 @@
+void
@@ -141,0 +148 @@
+int
@@ -155,0 +163 @@
+int
@@ -156,0 +165 @@
+int range;
@@ -161 +170,4 @@
-skrand(range){
+int
+skrand(range)
+int range;
+{
@@ -167,0 +180 @@
+void
@@ -184,0 +198 @@
+void

% usr/src/games/backgammon.c
@@ -4,0 +5,2 @@
+#define srand bg_srand
+#define rand bg_rand
@@ -15 +17,3 @@
-int red[]     {0,2,0,0,0,0,0,0,0,0,0,0,5,
+void getstr(), prtmov(), update(), roll(), movegen(), moverecord(), instructions(), prtbrd(), numline(), colorline(), srand(), _store();
+int play(), nextmove(), piececount(), strategy(), eval(), getprob(), rand(), _look();
+int red[]     = {0,2,0,0,0,0,0,0,0,0,0,0,5,
@@ -18 +22 @@
-int white[]   {0,2,0,0,0,0,0,0,0,0,0,0,5,
+int white[]   = {0,2,0,0,0,0,0,0,0,0,0,0,5,
@@ -21 +25 @@
-int probability[]{0,11,12,13,14,15,16,
+int probability[]={0,11,12,13,14,15,16,
@@ -27,0 +32 @@
+int
@@ -30 +35 @@
-	int t,k,n,go[5];
+	int t,k,n,go[6];
@@ -57 +62 @@
-	    exit();
+	    exit(0);
@@ -94 +99 @@
-	    exit();
+	    exit(0);
@@ -98,0 +104 @@
+void
@@ -105,0 +112 @@
+int
@@ -148,0 +156 @@
+int
@@ -169,0 +178 @@
+void
@@ -180,0 +190 @@
+void
@@ -195,0 +206 @@
+int
@@ -202 +213 @@
-	sum=+player[startrow++];
+	sum+=player[startrow++];
@@ -220,0 +232 @@
+void
@@ -227,0 +240 @@
+void
@@ -237 +250 @@
-		if((k=25-i-die1)>0&&movee[k]>=2)
+		if((k=25-i-die1)>0&&movee[k]>=2) {
@@ -239,0 +253 @@
+		}
@@ -250 +264 @@
-			if((k=25-j-die2)>0&&movee[k]>=2)
+			if((k=25-j-die2)>0&&movee[k]>=2) {
@@ -252,0 +267 @@
+			}
@@ -268 +283 @@
-			    if((k=25-l-die1)>0&&movee[k]>=2)
+			    if((k=25-l-die1)>0&&movee[k]>=2) {
@@ -270,0 +286 @@
+			    }
@@ -281 +297 @@
-				if((k=25-m-die1)>=0&&movee[k]>=2)
+				if((k=25-m-die1)>=0&&movee[k]>=2) {
@@ -283,0 +300 @@
+				}
@@ -314,0 +332 @@
+void
@@ -326,0 +345 @@
+	    /* fallthrough */
@@ -329,0 +349 @@
+	    /* fallthrough */
@@ -332,0 +353 @@
+	    /* fallthrough */
@@ -356,0 +378 @@
+int
@@ -393,0 +416 @@
+int
@@ -441 +464 @@
-		sum=+ *p++ * n;	/*remove pieces, but just barely*/
+		sum+= *p++ * n;	/*remove pieces, but just barely*/
@@ -449 +472 @@
-	    for(p=newtry;p<q;)sum=- *p++;  /*bad to be on 1st three points*/
+	    for(p=newtry;p<q;)sum-= *p++;  /*bad to be on 1st three points*/
@@ -453 +476 @@
-	    *prob=+ n*getprob(newtry,newother,6*n-5,6*n);
+	    *prob+= n*getprob(newtry,newother,6*n-5,6*n);
@@ -455,0 +479 @@
+void
@@ -484,0 +509 @@
+int
@@ -498 +523 @@
-		    if(playee[n]!=0)sum=+probability[k];
+		    if(playee[n]!=0)sum+=probability[k];
@@ -503,0 +529 @@
+void
@@ -541,0 +568 @@
+void
@@ -550,0 +578 @@
+void
@@ -565 +593 @@
-int rrno 0;
+int rrno = 0;
@@ -566,0 +595 @@
+void
@@ -571,0 +601 @@
+int
@@ -573,2 +603,2 @@
-	rrno =* 0106273;
-	rrno =+ 020202;
+	rrno *= 0106273;
+	rrno += 020202;
@@ -577,0 +608 @@
+int
@@ -582 +613,2 @@
-_store( p, numb ) int *p; {
+void
+_store( p, numb ) int *p; int numb; {

% usr/src/games/fish.c
@@ -21,0 +22,2 @@
+int	choose(), draw(), empty(), mark(), game(), move(), guess(), myguess();
+void	shuffle(), error(), score(), deal(), stats(), phand(), instruct(), madebook(), start(), hedrew(), heguessed();
@@ -24,0 +27 @@
+void
@@ -30 +33 @@
-	register i;
+	register int i;
@@ -41 +44,2 @@
-choose( a, n ) char a[]; {
+int
+choose( a, n ) char a[]; int n; {
@@ -44 +48 @@
-	register j, t;
+	register int j, t;
@@ -53,0 +58 @@
+int
@@ -58,0 +64 @@
+void
@@ -64,0 +71 @@
+int
@@ -66 +73 @@
-	register i;
+	register int i;
@@ -74 +81,2 @@
-mark( cd, hand ) HAND hand; {
+int
+mark( cd, hand ) int cd; HAND hand; {
@@ -84 +92,2 @@
-deal( hand, n ) HAND hand; {
+void
+deal( hand, n ) HAND hand; int n; {
@@ -90 +99 @@
-char *cname[] {
+char *cname[] = {
@@ -106,0 +116 @@
+void
@@ -108 +118 @@
-	register i, ct, b;
+	register int i, ct, b;
@@ -129,0 +140 @@
+void
@@ -131 +142 @@
-	register i, j;
+	register int i, j;
@@ -141 +152 @@
-			register k;
+			register int k;
@@ -157 +168,2 @@
-main( argc, argv ) char * argv[]; { 
+int
+main( argc, argv ) int argc; char * argv[]; { 
@@ -159 +171 @@
-	register c;
+	register int c;
@@ -180 +192 @@
-char *inst[] {
+char *inst[] = {
@@ -207,0 +220 @@
+void
@@ -217,0 +231 @@
+int
@@ -229 +243 @@
-		register g;
+		register int g;
@@ -256 +270,2 @@
-move( hs, ht, g, v ) HAND hs, ht; {
+int
+move( hs, ht, g, v ) HAND hs, ht; int g, v; {
@@ -259 +274 @@
-	register d;
+	register int d;
@@ -315 +330,2 @@
-madebook( x ){
+void
+madebook( x ) int x; {
@@ -318,0 +335 @@
+void
@@ -320 +337 @@
-	register my, your, i;
+	register int my, your, i;
@@ -349,0 +367 @@
+int
@@ -352 +370 @@
-	register g, go;
+	register int g, go;
@@ -431,0 +450 @@
+void
@@ -432,0 +452 @@
+	(void)h;
@@ -436 +456,2 @@
-hedrew( d ){
+void
+hedrew( d ) int d; {
@@ -440 +461,2 @@
-heguessed( d ){
+void
+heguessed( d ) int d; {
@@ -443,0 +466 @@
+int
@@ -446 +469 @@
-	register i, lg, t;
+	register int i, lg, t;
@@ -457 +480 @@
-		try[ntry++] = i;
+		try[ntry++&0377] = i;
@@ -465 +488 @@
-		if( hehas[try[i]] ) {
+		if( hehas[try[i]&0377] ) {
@@ -474 +497 @@
-		if( haveguessed[try[i]] < lg ) lg = haveguessed[try[i]];
+		if( haveguessed[try[i]&0377] < lg ) lg = haveguessed[try[i]&0377];
@@ -480 +503 @@
-		if( haveguessed[try[i]] == lg ) try[t++] = try[i];
+		if( haveguessed[try[i]&0377] == lg ) try[t++] = try[i];

% usr/src/games/fortune.c
@@ -5,0 +6 @@
+int

% usr/src/games/hangman.c
@@ -12,0 +13,2 @@
+void	setup(), fatal(), startnew(), stateout(), getguess(), wordout(), youwon(), getword(), pscore();
+double	frand();
@@ -14 +16,2 @@
-main(argc,argv) char **argv;
+int
+main(argc,argv) int argc; char **argv;
@@ -30,0 +34 @@
+void
@@ -34,2 +38,2 @@
-	time(tvec);
-	srand(tvec[1]+tvec[2]);
+	time((long *)tvec);
+	srand(tvec[0]);
@@ -44,0 +49 @@
+void
@@ -56,0 +62 @@
+void
@@ -64,0 +71 @@
+void
@@ -99,0 +107 @@
+void
@@ -104,0 +113 @@
+void
@@ -108,0 +118 @@
+void
@@ -113,0 +124 @@
+void
@@ -135 +146 @@
-long int freq[]
+long int freq[]=
@@ -142,0 +154 @@
+void

% usr/src/games/quiz.c
@@ -12 +12 @@
-char score[NL];
+signed char score[NL];
@@ -26,0 +27,2 @@
+int	disj(), string(), eat(), fold(), segment(), perm(), find(), query(), next();
+void	publish(), done(), instruct(), dunno(), pub1(), readindex(), talloc(), badinfo();
@@ -27,0 +30 @@
+int
@@ -31 +34 @@
-	register c;
+	register int c;
@@ -49 +52 @@
-				if(*line==0377)
+				if((*line&0377)==0377)
@@ -59,0 +63 @@
+int
@@ -71,0 +76 @@
+int
@@ -72,0 +78 @@
+int s;
@@ -86 +92 @@
-			return(t|x&s);
+			return(t|(x&s));
@@ -110,0 +117 @@
+int
@@ -111,0 +119 @@
+int s;
@@ -128,0 +137 @@
+			/* fallthrough */
@@ -154,0 +164 @@
+int
@@ -155,0 +166 @@
+int s;
@@ -170,0 +182 @@
+int
@@ -178,0 +191 @@
+void
@@ -185,0 +199 @@
+void
@@ -186,0 +201 @@
+int s;
@@ -204,0 +220 @@
+			/* fallthrough */
@@ -211,0 +228 @@
+int
@@ -243,0 +261 @@
+int
@@ -244,0 +263 @@
+int m, n;
@@ -264,0 +284 @@
+int
@@ -265,0 +286 @@
+int m;
@@ -276,0 +298 @@
+void
@@ -289,0 +312 @@
+void
@@ -296,0 +320 @@
+int
@@ -297,0 +322 @@
+int argc;
@@ -300 +325 @@
-	register j;
+	register int j;
@@ -306 +331 @@
-	extern done();
+	extern void done();
@@ -310 +335 @@
-	inc = (int)tm&077774|01;
+	inc = ((int)tm&077774)|01;
@@ -384,0 +410 @@
+int
@@ -403,0 +430 @@
+int
@@ -418,0 +446 @@
+void
@@ -426,0 +455 @@
+void
@@ -464,0 +494 @@
+void
@@ -468,0 +499 @@
+void

% usr/src/games/wump.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -19 +20,2 @@
-char	*intro[]
+int	tunnel(), rline(), rnum(), rin(), near();
+char	*intro[] =
@@ -94,0 +97 @@
+int
@@ -97 +100 @@
-	register i, j;
+	register int i, j;
@@ -140 +143 @@
-		qsort(&p->tunn[0], NTUNN, 2, icomp);
+		qsort(&p->tunn[0], NTUNN, sizeof(p->tunn[0]), icomp);
@@ -159 +162 @@
-			p->flag =| PIT;
+			p->flag |= PIT;
@@ -166 +169 @@
-			p->flag =| BAT;
+			p->flag |= BAT;
@@ -172 +175 @@
-	room[i].flag =| WUMP;
+	room[i].flag |= WUMP;
@@ -270 +273 @@
-	p->flag =& ~WUMP;
+	p->flag &= ~WUMP;
@@ -274 +277 @@
-	room[wloc].flag =| WUMP;
+	room[wloc].flag |= WUMP;
@@ -286,0 +290 @@
+int
@@ -287,0 +292 @@
+int i;
@@ -290 +295 @@
-	register n, j;
+	register int n, j;
@@ -308,0 +314 @@
+int
@@ -317 +323 @@
-			exit();
+			exit(0);
@@ -323,0 +330 @@
+int
@@ -324,0 +332 @@
+int n;
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
@@ -334,0 +343 @@
+int
@@ -337 +346 @@
-	register n, c;
+	register int n, c;
@@ -345 +354 @@
-					exit();
+					exit(0);
@@ -355,0 +365 @@
+int
@@ -356,0 +367 @@
+int ahaz;
@@ -360 +371 @@
-	register haz, i;
+	register int haz, i;
@@ -369,0 +381 @@
+int

% usr/src/libc/csu/crt0.s
@@ -1,36 +1,12 @@
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
+.comm	environ, 4
+.comm	errno, 4

% usr/src/libc/gen/abort.c usr/src/libc/gen/abort.s
@@ -1 +1,2 @@
-/ C library -- abort
+#include <stdio.h>
+#include <signal.h>
@@ -3,9 +4,6 @@
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
+abort()
+{
+	kill(getpid(), SIGIOT);
+	_exit(1);
+}

% usr/src/libc/gen/atof.c
@@ -12 +12 @@
-	register c;
+	register int c;
@@ -17 +17 @@
-	register eexp, exp, neg, negexp, bexp;
+	register int eexp, exp, neg, negexp, bexp;

% usr/src/libc/gen/atoi.c
@@ -0,0 +1 @@
+int
@@ -15,0 +17 @@
+			/* fallthrough */

% usr/src/libc/gen/atol.c
@@ -16,0 +17 @@
+			/* fallthrough */

% usr/src/libc/gen/calloc.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -13 +14 @@
-	register m;
+	register int m;
@@ -25,0 +27 @@
+void
@@ -29,0 +32,2 @@
+	(void)num;
+	(void)size;

% usr/src/libc/gen/crypt.c
@@ -49 +49 @@
-static	char	PC1_D[] {
+static	char	PC1_D[] = {
@@ -96,0 +97 @@
+void
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
@@ -234,0 +237 @@
+void
@@ -236,0 +240 @@
+int edflag;
@@ -239 +243 @@
-	register t, j, k;
+	register int t, j, k;
@@ -282 +286 @@
-			k = S[j][(preS[t+0]<<5)+
+			k = S[j*64 + (preS[t+0]<<5)+
@@ -328 +332 @@
-	register i, j, c;
+	register int i, j, c;

% usr/src/libc/gen/ctime.c
@@ -67,2 +67,2 @@
-	5,	333,	/* 1974: Jan 6 - last Sun. in Nov */
-	58,	303,	/* 1975: Last Sun. in Feb - last Sun in Oct */
+	{5,	333},	/* 1974: Jan 6 - last Sun. in Nov */
+	{58,	303},	/* 1975: Last Sun. in Feb - last Sun in Oct */
@@ -72 +72,3 @@
-char		*ct_numb();
+static char	*ct_numb();
+static int	sunday();
+int	ftime(), dysize();
@@ -91 +93 @@
-	register daylbegin, daylend;
+	register int daylbegin, daylend;
@@ -122 +124 @@
-static
+static int
@@ -202 +204 @@
-	for (ncp = "Day Mon 00 00:00:00 1900\n"; *cp++ = *ncp++;);
+	for (ncp = "Day Mon 00 00:00:00 1900\n"; (*cp++ = *ncp++););
@@ -226,0 +229 @@
+int
@@ -227,0 +231 @@
+int y;
@@ -236,0 +241 @@
+int n;

% usr/src/libc/gen/ctype_.c
@@ -3 +3 @@
-char _ctype_[] = {
+char _ctype_[1+256] = {

% usr/src/libc/gen/cuexit.c usr/src/libc/gen/cuexit.s
@@ -1,15 +1,2 @@
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
+void	_cleanup();
@@ -16,0 +4,7 @@
+void
+exit(n)
+int n;
+{
+	_cleanup();
+	_exit(n);
+}

% usr/src/libc/gen/ecvt.c
@@ -8 +8 @@
-char	*cvt();
+static char	*cvt();
@@ -30 +30 @@
-int ndigits, *decpt, *sign;
+int ndigits, *decpt, *sign, eflag;
@@ -48,0 +49,2 @@
+	if (!(arg <= 1.7976931348623157e308))
+		arg = 1.7976931348623157e308;
@@ -55,0 +58,3 @@
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
+static char	*execat();
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
@@ -17,0 +37 @@
+int
@@ -27 +47 @@
-	register eacces = 0;
+	register int eacces = 0;
@@ -41 +61 @@
-			for (i=1; newargs[i+1]=argv[i]; i++) {
+			for (i=1; (newargs[i+1]=argv[i]); i++) {

% usr/src/libc/gen/frexp.c usr/src/libc/gen/frexp11.s
@@ -1,4 +1,6 @@
-/  double frexp(x, ip)
-/  double x; int *ip;
-/  returns a fractional part 1/16 <= |value| < 1
-/ and stores an exponent so x = value * 2^(*ip)
+double
+frexp(value, eptr)
+double value;
+int *eptr;
+{
+	union { double d; unsigned u[2]; } x;
@@ -6,11 +8,12 @@
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
+	*eptr += (x.u[1]>>20 & 03777) - 1022;
+	x.u[1] = (x.u[1] & 0x800fffff) | 1022<<20;
+	return(x.d);
+}

% usr/src/libc/gen/getenv.c
@@ -7 +7 @@
-char	*nvmatch();
+static char	*nvmatch();

% usr/src/libc/gen/getlogin.c
@@ -0,0 +1 @@
+#include <stdio.h>
@@ -4,0 +6 @@
+static	char	name[9];
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

% usr/src/libc/gen/isatty.c
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -6,0 +8 @@
+int
@@ -7,0 +10 @@
+int f;

% usr/src/libc/gen/l3.c
@@ -3,0 +4 @@
+int
@@ -9 +10 @@
-	register i;
+	register int i;
@@ -22 +22,0 @@
-		b++;
@@ -24,0 +25 @@
+		b++;
@@ -26,0 +28 @@
+	return(0);
@@ -28,0 +31 @@
+int
@@ -34 +37 @@
-	register i;
+	register int i;
@@ -47 +49,0 @@
-		*a++ = 0;
@@ -49,0 +52 @@
+		*a++ = 0;
@@ -51,0 +55 @@
+	return(0);

% usr/src/libc/gen/ldexp.c usr/src/libc/gen/ldexp11.s
@@ -1,3 +1 @@
-/ double ldexp(number, exp)
-/ double number
-/  -- returns number * 2^exp
+#include <errno.h>
@@ -5,2 +3,7 @@
-.globl	_ldexp
-.globl	csv, cret
+double
+ldexp(value, n)
+double value;
+int n;
+{
+	union { double d; unsigned u[2]; } x;
+	register int k;
@@ -8,24 +11,12 @@
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
@@ -7 +8 @@
-	register i;
+	register int i;

% usr/src/libc/gen/modf.c usr/src/libc/gen/modf11.s
@@ -1,4 +1,6 @@
-/ double modf(x, *fp)
-/ double x, *fp;
-/ return fractional part
-/ stash integer part (as double)
+double
+modf(value, iptr)
+double value, *iptr;
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
+	e = (x.u[1]>>20 & 03777) - 1023;
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
@@ -4,0 +5 @@
+int
@@ -9,2 +10,3 @@
-	register struct nlist *p, *q;
-	int f, n, m, i;
+	register struct nlist *p;
+	register unsigned *q;
+	int f, m, i;
@@ -12,2 +14,2 @@
-	struct exec buf;
-	struct nlist space[SPACE];
+	unsigned n, buf[13], sh[10], space[4*SPACE], st;
+	char c[10];
@@ -22,4 +24,2 @@
-	read(f, (char *)&buf, sizeof buf);
-	for(i=0; a_magic[i]; i++)
-		if(a_magic[i] == buf.a_magic) break;
-	if(a_magic[i] == 0){
+	read(f, (char *)buf, sizeof buf);
+	if(buf[0] != 0x464c457f){
@@ -29,5 +29,12 @@
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
@@ -38,0 +46 @@
+		lseek(f, sa, 0);
@@ -41,9 +49,10 @@
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
@@ -5,0 +6 @@
+#include <stdio.h>
@@ -8 +9,2 @@
-char	*sys_errlist[];
+extern char	*sys_errlist[];
+void
@@ -13 +15 @@
-	register n;
+	register int n;

% usr/src/libc/gen/qsort.c
@@ -0,0 +1 @@
+static void qs1(), qsexc(), qstexc();
@@ -4,0 +6 @@
+void
@@ -16 +18 @@
-static qs1(a, l)
+static void qs1(a, l)
@@ -20,2 +22 @@
-	register es;
-	char **k;
+	register unsigned es;
@@ -87 +88 @@
-static qsexc(i, j)
+static void qsexc(i, j)
@@ -103 +104 @@
-static qstexc(i, j, k)
+static void qstexc(i, j, k)

% usr/src/libc/gen/rand.c
@@ -2,0 +3 @@
+void
@@ -8,0 +10 @@
+int

% usr/src/libc/gen/rindex.c

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
+static void sleepx();
@@ -5,0 +8 @@
+unsigned
@@ -7 +10 @@
-unsigned n;
+volatile unsigned n;
@@ -9,3 +12,2 @@
-	int sleepx();
-	unsigned altime;
-	int (*alsig)() = SIG_DFL;
+	volatile unsigned altime;
+	int (*volatile alsig)() = SIG_DFL;
@@ -14 +16 @@
-		return;
+		return(0);
@@ -19 +21 @@
-		return;
+		return(0);
@@ -36 +38 @@
-static
+static void

% usr/src/libc/gen/strcat.c
@@ -16 +16 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strcmp.c
@@ -4,0 +5 @@
+int

% usr/src/libc/gen/strcpy.c
@@ -13 +13 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strlen.c
@@ -5,0 +6 @@
+int
@@ -9 +10 @@
-	register n;
+	register int n;

% usr/src/libc/gen/strncat.c
@@ -10 +10 @@
-register n;
+register int n;
@@ -18 +18 @@
-	while (*s1++ = *s2++)
+	while ((*s1++ = *s2++))

% usr/src/libc/gen/strncmp.c
@@ -4,0 +5 @@
+int
@@ -7 +8 @@
-register n;
+register int n;

% usr/src/libc/gen/strncpy.c
@@ -8,0 +9 @@
+int n;
@@ -10 +11 @@
-	register i;
+	register int i;

% usr/src/libc/gen/stty.c
@@ -4,0 +5 @@
+#include <stdio.h>
@@ -6,0 +8 @@
+int
@@ -7,0 +10 @@
+int fd;
@@ -12,0 +16 @@
+int
@@ -13,0 +18 @@
+int fd;

% usr/src/libc/gen/swab.c
@@ -5,0 +6 @@
+void
@@ -8 +9 @@
-register n;
+register int n;

% usr/src/libc/gen/tell.c
@@ -7,0 +8 @@
+int f;

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
@@ -24,0 +26 @@
+int zone, dst;

% usr/src/libc/gen/ttyname.c
@@ -10,0 +11 @@
+#include <stdio.h>
@@ -17,0 +19 @@
+int f;
@@ -23 +25 @@
-	register df;
+	register int df;

% usr/src/libc/gen/ttyslot.c
@@ -6,0 +7 @@
+#include <stdio.h>
@@ -9 +10 @@
-char	*getttys();
+static char	*getttys();
@@ -14,0 +16 @@
+int
@@ -18 +20 @@
-	register s, tf;
+	register int s, tf;
@@ -29 +31 @@
-	while (tp = getttys(tf)) {
+	while ((tp = getttys(tf))) {
@@ -41,0 +44 @@
+int f;

% usr/src/libc/memcpy.c /dev/null
@@ -0,0 +1,27 @@
+char *
+memcpy(d, s, n)
+char *d;
+register char *s;
+register unsigned n;
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
+memset(d, c, n)
+char *d;
+int c;
+register unsigned n;
+{
+	register char *p;
+
+	p = d;
+	while (n--)
+		*p++ = c;
+	return(d);
+}

% usr/src/libc/stdio/clrerr.c
@@ -2,0 +3 @@
+void

% usr/src/libc/stdio/data.c

% usr/src/libc/stdio/doprnt.c usr/src/libc/stdio/doprnt.s
@@ -1 +1,2 @@
-/ C library -- conversions
+#include <stdio.h>
+#include <stdarg.h>
@@ -3,7 +4,2 @@
-width=-8.
-formp=-10.
-rjust=-12.
-ndfnd=-14.
-ndigit=-16.
-zfill=-18.
-.globl	__doprnt
+char	*ecvt(), *fcvt(), *gcvt();
+void	_strout();
@@ -11,313 +7,165 @@
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
+gnum(fmtp, argp)
+register char **fmtp;
+va_list *argp;
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
+_doprnt(fmt, argp, iop)
+char *fmt;
+va_list *argp;
+FILE *iop;
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
@@ -13,0 +15 @@
+int	_innum(), _instr();
@@ -25,0 +28 @@
+int
@@ -29 +32 @@
-register int **argp;
+va_list *argp;
@@ -33,0 +37 @@
+	int *slot;
@@ -44,3 +48,4 @@
-		if (ch != '*')
-			ptr = argp++;
-		else
+		if (ch != '*') {
+			slot = va_arg(*argp, int *);
+			ptr = &slot;
+		} else
@@ -96,0 +102 @@
+int
@@ -97,0 +104 @@
+int type, len, size;
@@ -104 +111 @@
-	register c, base;
+	register int c, base;
@@ -135 +142 @@
-		 || base==16 && ('a'<=c && c<='f' || 'A'<=c && c<='F')) {
+		 || (base==16 && (('a'<=c && c<='f') || ('A'<=c && c<='F')))) {
@@ -204,0 +212 @@
+int
@@ -205,0 +214 @@
+int type, len;
@@ -210 +219 @@
-	register ch;
+	register int ch;
@@ -254 +263 @@
-	register c, t;
+	register int c, t;

% usr/src/libc/stdio/endopen.c
@@ -2,0 +3 @@
+static int create();

% usr/src/libc/stdio/fdopen.c
@@ -11,0 +12 @@
+	int fd;
@@ -30 +31 @@
-		/* No break */
+		/* fallthrough */

% usr/src/libc/stdio/fgetc.c
@@ -2,0 +3 @@
+int

% usr/src/libc/stdio/fgets.c
@@ -5,0 +6 @@
+int n;
@@ -8 +9 @@
-	register c;
+	register int c = 0;

% usr/src/libc/stdio/filbuf.c
@@ -21 +21 @@
-			iop->_base = &smallbuf[fileno(iop)];
+			iop->_base = &smallbuf[(unsigned char)fileno(iop)];

% usr/src/libc/stdio/findiop.c

% usr/src/libc/stdio/flsbuf.c
@@ -11 +11 @@
-	register n, rn;
+	register int n, rn;
@@ -63 +63 @@
-	register n;
+	register int n;
@@ -80,0 +81 @@
+void
@@ -94 +95 @@
-	register r;
+	register int r;
@@ -107,2 +108,2 @@
-	iop->_flag &=
-		~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG|_IORW);
+	iop->_flag = (char)(iop->_flag &
+		~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG|_IORW));

% usr/src/libc/stdio/fopen.c

% usr/src/libc/stdio/fprintf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+void	_doprnt();
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
@@ -2,0 +3 @@
+int
@@ -3,0 +5 @@
+int c;

% usr/src/libc/stdio/fputs.c
@@ -2,0 +3 @@
+int
@@ -7,2 +8,2 @@
-	register r;
-	register c;
+	register int r = 0;
+	register int c;
@@ -10 +11 @@
-	while (c = *s++)
+	while ((c = *s++))

% usr/src/libc/stdio/freopen.c

% usr/src/libc/stdio/fseek.c
@@ -8,0 +9 @@
+int
@@ -11,0 +13 @@
+	int ptrname;
@@ -14 +16 @@
-	long p;
+	long p = -1;

% usr/src/libc/stdio/ftell.c
@@ -14 +14 @@
-	register adjust;
+	register int adjust;

% usr/src/libc/stdio/gcvt.c
@@ -10,0 +11 @@
+int ndigit;
@@ -15 +16 @@
-	register i;
+	register int i;
@@ -23,2 +24,2 @@
-	if (decpt >= 0 && decpt-ndigit > 4
-	 || decpt < 0 && decpt < -3) { /* use E-style */
+	if ((decpt >= 0 && decpt-ndigit > 4)
+	 || (decpt < 0 && decpt < -3)) { /* use E-style */
@@ -35,0 +37,4 @@
+		if (decpt >= 100) {
+			*p2++ = decpt/100 + '0';
+			decpt %= 100;
+		}

% usr/src/libc/stdio/getchar.c
@@ -7,0 +8 @@
+int

% usr/src/libc/stdio/getgrent.c
@@ -14,0 +15 @@
+void
@@ -22,0 +24 @@
+void
@@ -34 +36 @@
-register c;
+register int c;

% usr/src/libc/stdio/getgrgid.c
@@ -5 +5 @@
-register gid;
+register int gid;

% usr/src/libc/stdio/getgrnam.c
@@ -0,0 +1 @@
+#include <stdio.h>

% usr/src/libc/stdio/getpass.c
@@ -12 +12 @@
-	register c;
+	register int c;

% usr/src/libc/stdio/getpwent.c
@@ -9,0 +10 @@
+void
@@ -17,0 +19 @@
+void

% usr/src/libc/stdio/getpwnam.c
@@ -0,0 +1 @@
+#include <stdio.h>

% usr/src/libc/stdio/getpw.c
@@ -2,0 +3 @@
+int
@@ -8 +9 @@
-	register n, c;
+	register int n, c;

% usr/src/libc/stdio/getpwuid.c
@@ -5 +5 @@
-register uid;
+register int uid;

% usr/src/libc/stdio/gets.c
@@ -7 +7 @@
-	register c;
+	register int c;

% usr/src/libc/stdio/getw.c
@@ -2,0 +3 @@
+int
@@ -6 +7 @@
-	register i;
+	register unsigned i;
@@ -11 +12,3 @@
-	return(i | (getc(iop)<<8));
+	i |= getc(iop)<<8;
+	i |= getc(iop)<<16;
+	return(i | (unsigned)getc(iop)<<24);

% usr/src/libc/stdio/popen.c
@@ -6,0 +7 @@
+int	dup2();
@@ -14 +15 @@
-	register myside, hisside, pid;
+	register int myside, hisside, pid;
@@ -34,0 +36 @@
+int
@@ -38 +40 @@
-	register f, r, (*hstat)(), (*istat)(), (*qstat)();
+	register int f, r, (*hstat)(), (*istat)(), (*qstat)();

% usr/src/libc/stdio/printf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+void	_doprnt();
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
@@ -7,0 +8 @@
+int
@@ -9 +10 @@
-register c;
+register int c;
@@ -11 +12 @@
-	putc(c, stdout);
+	return(putc(c, stdout));

% usr/src/libc/stdio/puts.c
@@ -2,0 +3 @@
+int
@@ -6 +7 @@
-	register c;
+	register int c;
@@ -8 +9 @@
-	while (c = *s++)
+	while ((c = *s++))

% usr/src/libc/stdio/putw.c
@@ -2,0 +3 @@
+int
@@ -4 +5 @@
-register i;
+register int i;
@@ -8,0 +10,3 @@
+	putc(i>>16, iop);
+	putc(i>>24, iop);
+	return(i);

% usr/src/libc/stdio/rdwr.c
@@ -2,0 +3 @@
+int
@@ -8 +9 @@
-	register c;
+	register int c;
@@ -24,0 +26 @@
+int

% usr/src/libc/stdio/rew.c
@@ -2,0 +3 @@
+void

% usr/src/libc/stdio/scanf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+int	_doscan();
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
@@ -2,0 +3 @@
+void

% usr/src/libc/stdio/sprintf.c
@@ -1,0 +2,2 @@
+#include	<stdarg.h>
+void	_doprnt();
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
@@ -2,0 +3 @@
+void
@@ -5 +6 @@
-register count;
+register int count;
@@ -7,0 +9 @@
+int fillch;

% usr/src/libc/stdio/system.c
@@ -0,0 +1 @@
+#include	<stdio.h>
@@ -2,0 +4 @@
+int

% usr/src/libc/stdio/ungetc.c
@@ -2,0 +3 @@
+int
@@ -3,0 +5 @@
+int c;
@@ -8 +10 @@
-	if ((iop->_flag&_IOREAD)==0 || iop->_ptr <= iop->_base)
+	if ((iop->_flag&_IOREAD)==0 || iop->_ptr <= iop->_base) {
@@ -10 +12 @@
-			*iop->_ptr++;
+			iop->_ptr++;
@@ -12,0 +15 @@
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
+	push	{r1, lr}
+	add	r0, r1, r0
+	bl	brk
+	pop	{r1, lr}
+	cmp	r0, #0
+	movge	r0, r1
+	bx	lr
+brk:
+	push	{r0, lr}
+	mov	ip, #17
+	bl	cerror
+	pop	{r1, lr}
+	cmp	r0, #0
+	ldrge	r2, =nd
+	strge	r1, [r2]
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
@@ -1,8 +1 @@
-/ C library -- fork
-
-/ pid = fork();
-/
-/ pid == 0 in child process; pid == -1 means error return
-/ in child, parents id is in par_uid if needed
-
-.globl	_fork, _par_uid
+.globl	fork
@@ -10,17 +3,3 @@
-.fork = 2.
-
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
+fork:
+	mov	ip, #2
+	b	cerror

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
@@ -1,24 +1,11 @@
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
+	cmp	r0, #0
+	bxlt	lr
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
@@ -1,26 +1,11 @@
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
+	cmp	r0, #0
+	bxlt	lr
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
@@ -1,27 +1,18 @@
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
+.globl	syscall3, cerror
+syscall3:
+	mov	ip, r0
+	mov	r0, r1
+	mov	r1, r2
+	mov	r2, r3
+cerror:
+	push	{r7}
+	mov	r7, ip
+	svc	#0
+	pop	{r7}
+	cmp	r0, #0
+	bxge	lr
+	rsb	r1, r0, #0
+	ldr	r2, =errno
+	str	r1, [r2]
+	mvn	r0, #0
+	bx	lr

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
@@ -1,72 +1,114 @@
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
+	mov ip, #4
+	b 1f
+pabort_entry:
+	sub lr, lr, #4
+	mov ip, #11
+	b 1f
+dabort_entry:
+	sub lr, lr, #8
+	mov ip, #11
+1:
+	srsdb sp!, #0x13
+	cpsid if, #0x13
+	sub sp, sp, #60
+	stmia sp, {r0-r14}^
+	mov r0, ip
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
@@ -1,29 +1,189 @@
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
+.globl cntfrq_get, cntv_tval_set, cntv_ctl_set, save, resume, dcflush
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
+	add r3, r3, #0x1000
+	str r3, [r2, #8]
+	add r3, r3, #0x1000
+	str r3, [r2, #12]
+	dsb ish
+	mov r3, #0
+	mcr p15, 0, r3, c8, c7, 0
+	dsb ish
+	isb
+	ldmia r1, {r4-r11}
+	ldr sp, [r1, #32]
+	ldr lr, [r1, #36]
+	mov r0, #1
+	bx lr
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
@@ -32,638 +191,0 @@
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
@@ -671,386 +193 @@
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
@@ -1058 +195,8 @@
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
@@ -1,0 +2,5 @@
+#include <stdlib.h>
+#include <string.h>
+
+void	puke(), subst();
+int	input(), equal(), badline();
@@ -62,0 +68 @@
+	{
@@ -71,0 +78 @@
+	},
@@ -72,0 +80 @@
+	{
@@ -81,0 +90 @@
+	},
@@ -82,0 +92 @@
+	{
@@ -91,0 +102 @@
+	},
@@ -92,0 +104 @@
+	{
@@ -101,0 +114 @@
+	},
@@ -102,0 +116 @@
+	{
@@ -111,0 +126 @@
+	},
@@ -120,0 +136 @@
+	{
@@ -129,0 +146 @@
+	},
@@ -137,0 +155 @@
+	{
@@ -146,0 +165 @@
+	},
@@ -147,0 +167 @@
+	{
@@ -156,0 +177 @@
+	},
@@ -157,0 +179 @@
+	{
@@ -166,0 +189 @@
+	},
@@ -171,0 +195 @@
+	{
@@ -180,0 +205 @@
+	},
@@ -181,0 +207 @@
+	{
@@ -190,0 +217 @@
+	},
@@ -191,0 +219 @@
+	{
@@ -200,0 +229 @@
+	},
@@ -201,0 +231 @@
+	{
@@ -210,0 +241 @@
+	},
@@ -211,0 +243 @@
+	{
@@ -220,0 +253 @@
+	},
@@ -225,0 +259 @@
+	{
@@ -234,0 +269 @@
+	},
@@ -235,0 +271 @@
+	{
@@ -244,0 +281 @@
+	},
@@ -250,0 +288 @@
+	{
@@ -259,0 +298 @@
+	},
@@ -260,0 +300 @@
+	{
@@ -269,0 +310 @@
+	},
@@ -270,0 +312 @@
+	{
@@ -279,0 +322 @@
+	},
@@ -284,0 +328 @@
+	{
@@ -293,0 +338 @@
+	},
@@ -294,0 +340 @@
+	{
@@ -303,0 +350 @@
+	},
@@ -313,0 +361 @@
+	{
@@ -322,0 +371 @@
+	},
@@ -327,0 +377 @@
+	{
@@ -336,0 +387 @@
+	},
@@ -344,0 +396 @@
+	{
@@ -353,0 +406 @@
+	},
@@ -354,0 +408 @@
+	{
@@ -363,0 +418 @@
+	},
@@ -365,64 +420 @@
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
@@ -447,0 +440 @@
+	"#include \"../h/seg.h\"",
@@ -460 +453 @@
-	"	0",
+	"	{0}",
@@ -476 +469 @@
-"	0\n\
+"	{0}\n\
@@ -483 +476 @@
-int	nswap	= %l;\n\
+int	nswap	= %d;\n\
@@ -494,7 +486,0 @@
-char	*strg1a[] =
-{
-	"int	mpxchan();",
-	"int	(*ldmpx)() = mpxchan;",
-	0
-};
-
@@ -512 +498 @@
-	"	0",
+	"	{0}",
@@ -515 +500,0 @@
-	"int	ttyopen(), ttyclose(), ttread(), ttwrite(), ttyinput(), ttstart();",
@@ -529 +514 @@
-	"	ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart, /* 0 */",
+	"	{ttyopen, nulldev, ttread, ttwrite, nodev, ttyinput, ttstart, 0, 0, 0}, /* 0 */",
@@ -535 +520 @@
-	"	pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint, /* 1 */",
+	"	{pkopen, pkclose, pkread, pkwrite, pkioctl, pkrint, pkxint, 0, 0, 0}, /* 1 */",
@@ -550,0 +536,8 @@
+char	*con = "kl";
+char	*dsk = "rk";
+int	ddr;
+unsigned long	ramb, ramn, tabb, tabn, coreb, coret, pguser, gicd, gicc;
+#define	NMAP	8
+unsigned long	mapb[NMAP], mape[NMAP];
+char	mapa[NMAP][32];
+int	nmap;
@@ -551,0 +545 @@
+int
@@ -556,2 +550 @@
-	int i, n, ev, nkl;
-	int flagf, flagb, dumpht;
+	int i;
@@ -562 +555 @@
- * pass1 -- create interrupt vectors
+ * pass1 -- create the linker script
@@ -564,46 +557,14 @@
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
+	printf("\t__bss_end = .;\n");
+	printf("\t.ddrbss (NOLOAD) : ALIGN(16384) {\n");
+	printf("\t\t__ddrbss_start = .;\n\t\t*(.ddrbss*)\n");
+	printf("\t\t__ddrbss_end = .;\n\t} > %s\n}\n", tabn ? "TAB" : "RAM");
@@ -620 +581 @@
-	for (i=0; q=btab[i]; i++) {
+	for (i=0; (q=btab[i]); i++) {
@@ -627 +588 @@
-	for(i=0; q=btab[i]; i++) {
+	for(i=0; (q=btab[i]); i++) {
@@ -631 +592 @@
-			printf("%s	/* %s = %d */\n", p->coded, q, i);
+			printf("	{%s},	/* %s = %d */\n", p->coded, q, i);
@@ -640 +601 @@
-		printf("	nodev, nodev, nodev, 0, /* %s = %d */\n", q, i);
+		printf("	{nodev, nodev, nodev, 0}, /* %s = %d */\n", q, i);
@@ -652 +613 @@
-	for (i=0; q=ctab[i]; i++) {
+	for (i=0; (q=ctab[i]); i++) {
@@ -659 +620 @@
-	for(i=0; q=ctab[i]; i++) {
+	for(i=0; (q=ctab[i]); i++) {
@@ -663 +624 @@
-			printf("%s	/* %s = %d */\n", p->codee, q, i);
+			printf("	{%s},	/* %s = %d */\n", p->codee, q, i);
@@ -666 +627 @@
-		printf("	nodev, nodev, nodev, nodev, nodev, nulldev, 0, /* %s = %d */\n", q, i);
+		printf("	{nodev, nodev, nodev, nodev, nodev, nulldev, 0}, /* %s = %d */\n", q, i);
@@ -683,2 +643,0 @@
-	if (!mpx)
-		puke(strg1a);
@@ -688,13 +647,19 @@
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
+	printf("\nvoid\t%sinit(), %sinit(), %sputchar(char);\n", con, dsk, con);
+	printf("void\tcninit() { %sinit(); }\n", con);
+	printf("void\tbdinit() { %sinit(); }\n", dsk);
+	printf("void\tputchar(int c) { %sputchar(c); }\n", con);
+	printf("\nvoid\tddrinit();\n");
+	printf("void\tclock_ddr_init() { %s}\n", ddr ? "ddrinit(); " : "");
@@ -702,0 +668 @@
+void
@@ -704,0 +671 @@
+int a;
@@ -708 +675 @@
-	while(c = *s++) {
+	while((c = *s++)) {
@@ -713,0 +681 @@
+int
@@ -726 +694 @@
-	if (count == -1 && n>0) {
+	if (count == -1) {
@@ -728 +696 @@
-		n++;
+		n = sscanf(line, "%s%s%ld", keyw, dev, &num) + 1;
@@ -731,0 +700,24 @@
+	if (equal(keyw, "map") && nmap < NMAP) {
+		if (sscanf(line, "%*s%lx%lx%s", &mapb[nmap], &mape[nmap], mapa[nmap]) != 3)
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
@@ -733,0 +726,2 @@
+		if (n > 2)
+			subst(q, dev);
@@ -734,0 +729,2 @@
+			if (n > 2)
+				return(1);
@@ -812,0 +809,7 @@
+	return(badline(line));
+}
+
+int
+badline(line)
+char *line;
+{
@@ -816,0 +820,38 @@
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
@@ -124,0 +125 @@
+void
@@ -128 +129 @@
-	register flag;
+	register int flag;
@@ -153,0 +155 @@
+void
@@ -170,0 +173 @@
+void
@@ -181,0 +185 @@
+void
@@ -186 +190 @@
-	register s;
+	register int s;
@@ -217,0 +222 @@
+int
@@ -245 +250 @@
-	register i;
+	register int i;
@@ -342,0 +348 @@
+void
@@ -357,0 +364 @@
+void
@@ -361 +368 @@
-	register s;
+	register int s;
@@ -373,0 +381 @@
+void
@@ -391,0 +400 @@
+void
@@ -395,2 +404,2 @@
-	register *p;
-	register c;
+	register int *p;
+	register int c;
@@ -408,0 +418 @@
+void
@@ -410 +420,2 @@
-register count;
+register int count;
+int	blkno, coreaddr, rdflg;
@@ -413 +424 @@
-	register tcount;
+	register int tcount;
@@ -455,0 +467 @@
+void
@@ -483,0 +496 @@
+void
@@ -486,0 +500 @@
+int	dev, rw;
@@ -515 +529 @@
-	    && nb < 1024-u.u_ssize)
+	    && (unsigned)nb < 1024-u.u_ssize)
@@ -528 +542 @@
-	ts = (u.u_sep? UDSA: UISA)->r[nb>>7] + (nb&0177);
+	ts = (u.u_sep? &u.u_uisa[8]: &u.u_uisa[0])[nb>>7] + (nb&0177);
@@ -556,0 +571 @@
+void

% usr/sys/dev/mem.c
@@ -12,0 +13 @@
+#include "../h/systm.h"
@@ -17,0 +19 @@
+int
@@ -18,0 +21 @@
+int	dev;
@@ -20,2 +23 @@
-	register c, bn, on;
-	int a, d;
+	register int c;
@@ -24 +26 @@
-		return;
+		return(0);
@@ -26,10 +28 @@
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
@@ -37,3 +29,0 @@
-		UISA->r[0] = a;
-		UISD->r[0] = d;
-		spl0();
@@ -40,0 +31 @@
+	return(0);
@@ -42,0 +34 @@
+int
@@ -43,0 +36 @@
+int	dev;
@@ -45,2 +38 @@
-	register c, bn, on;
-	int a, d;
+	register int c;
@@ -50 +42 @@
-		return;
+		return(0);
@@ -53,2 +44,0 @@
-		bn = u.u_offset >> 6;
-		on = u.u_offset & 077;
@@ -57,8 +47 @@
-		a = UISA->r[0];
-		d = UISD->r[0];
-		spl7();
-		UISA->r[0] = bn;
-		UISD->r[0] = 077406;
-		if(minor(dev) == 1)
-			UISA->r[0] = (ka6-6)->r[(bn>>7)&07] + (bn & 0177);
-		if (suibyte((caddr_t)on, c) < 0)
+		if (sumem(u.u_offset-1, c) < 0)
@@ -66,3 +48,0 @@
-		UISA->r[0] = a;
-		UISD->r[0] = d;
-		spl0();
@@ -69,0 +50 @@
+	return(0);

% usr/sys/dev/partab.c

% usr/sys/dev/pl011.c usr/sys/dev/kl.c
@@ -12,3 +12 @@
-#define	KLADDR	((struct device *)0177560)	/* console */
-#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
-#define	DLBASE	((struct device *)0175610)	/* dl-e */
+#define	KLADDR	0x09000000
@@ -17,2 +15,8 @@
-#define DSRDY	02
-#define	RDRENB	01
+#define	UARTDR	(*(volatile int *)(KLADDR+0x00))
+#define	UARTFR	(*(volatile int *)(KLADDR+0x18))
+#define	UARTIMSC	(*(volatile int *)(KLADDR+0x38))
+#define	UARTMIS	(*(volatile int *)(KLADDR+0x40))
+#define	UARTICR	(*(volatile int *)(KLADDR+0x44))
+#define	TXFF	040
+#define	RXI	020
+#define	TXI	040
@@ -30,8 +34,4 @@
-char	partab[];
-
-struct device {
-	int	rcsr;
-	int	rbuf;
-	int	tcsr;
-	int	tbuf;
-};
+int	klirq = 33;
+int	ttread(), ttioccomm(), getc();
+void	ttyopen(), ttyclose(), ttychars(), ttyinput(), ttstart(), timeout(), wakeup();
+caddr_t	ttwrite();
@@ -38,0 +39 @@
+int
@@ -40,0 +42 @@
+int flag;
@@ -42 +43,0 @@
-	register struct device *addr;
@@ -44 +45 @@
-	register d;
+	register int d;
@@ -45,0 +47 @@
+	(void)flag;
@@ -49 +51 @@
-		return;
+		return(0);
@@ -52,12 +53,0 @@
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
@@ -67 +57 @@
-		tp->t_flags = EVENP|LCASE|ECHO|XTABS|CRMOD|CR2;
+		tp->t_flags = EVENP|ECHO|XTABS|CRMOD;
@@ -70,2 +60 @@
-	addr->rcsr |= IENABLE|DSRDY|RDRENB;
-	addr->tcsr |= IENABLE;
+	UARTIMSC = RXI|TXI;
@@ -72,0 +62 @@
+	return(0);
@@ -74,0 +65 @@
+int
@@ -80,0 +72 @@
+	(void)flag;
@@ -82,0 +75 @@
+	return(0);
@@ -84,0 +78 @@
+int
@@ -88,0 +83 @@
+	return(0);
@@ -90,0 +86 @@
+int
@@ -94,0 +91 @@
+	return(0);
@@ -96,0 +94 @@
+void
@@ -105,4 +103 @@
-		if (tp->t_chan)
-			mcstart(tp->t_chan, (caddr_t)&tp->t_outq);
-		else
-			wakeup((caddr_t)&tp->t_outq);
+		wakeup((caddr_t)&tp->t_outq);
@@ -110,0 +106 @@
+void
@@ -115 +110,0 @@
-	register struct device *addr;
@@ -119,3 +114 @@
-	addr = (struct device *)tp->t_addr;
-	c = addr->rbuf;
-	addr->rcsr |= RDRENB;
+	c = UARTDR;
@@ -124,0 +118 @@
+int
@@ -127,0 +122 @@
+int cmd, flag;
@@ -129 +124,2 @@
-	if (ttioccom(cmd, &kl11[minor(dev)], addr, dev)==0)
+	(void)flag;
+	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
@@ -130,0 +127 @@
+	return(0);
@@ -132,0 +130 @@
+int
@@ -136,2 +134 @@
-	register c;
-	register struct device *addr;
+	register int c;
@@ -139,3 +136,2 @@
-	addr = (struct device *)tp->t_addr;
-	if((addr->tcsr&DONE) == 0)
-		return;
+	if(UARTFR&TXFF)
+		return(0);
@@ -144 +140 @@
-			addr->tbuf = c;
+			UARTDR = c;
@@ -146 +142 @@
-			addr->tbuf = c | (partab[c]&0200);
+			UARTDR = c;
@@ -151,0 +148,18 @@
+	return(0);
+}
+
+void
+klinit()
+{
+}
+
+int
+klintr()
+{
+	if (UARTMIS&RXI)
+		klrint(0);
+	if (UARTMIS&TXI) {
+		UARTICR = TXI;
+		klxint(0);
+	}
+	return(0);
@@ -154 +167,0 @@
-char	*msgbufp = msgbuf;	/* Next saved printf character */
@@ -166,2 +179,2 @@
-putchar(c)
-register c;
+void
+klputchar(char c)
@@ -169 +182 @@
-	register s, timo;
+	register int s, timo;
@@ -176,5 +188,0 @@
-	/*
-	 *  If last char was a break or null, don't print
-	*/
-	if ((KLADDR->rbuf&0177) == 0)
-		return;
@@ -186 +194 @@
-	while((KLADDR->tcsr&0200) == 0)
+	while(UARTFR&TXFF)
@@ -191,3 +199,3 @@
-	s = KLADDR->tcsr;
-	KLADDR->tcsr = 0;
-	KLADDR->tbuf = c;
+	s = UARTIMSC;
+	UARTIMSC = 0;
+	UARTDR = c;
@@ -195,3 +203 @@
-		putchar('\r');
-		putchar(0177);
-		putchar(0177);
+		klputchar('\r');
@@ -199,2 +205,2 @@
-	putchar(0);
-	KLADDR->tcsr = s;
+	klputchar(0);
+	UARTIMSC = s;

% usr/sys/dev/stm32ddr.c /dev/null
@@ -0,0 +1,175 @@
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
+void
+ddrinit()
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
+	while ((DPHY(0x00C) & 0x3E1) == 0)
+		;
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
+	while ((DPHY(0x00C) & 0x3E1) == 0)
+		;
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
@@ -12,14 +12,23 @@
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
+void iodone(), deverror(), dcflush(), physio(), rkstart();
+int spl5(), splx();
+
+#define	SD(off)	(*(volatile int *)(0x58005000+(off)))
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
+
+#define	WCOM	24
+#define	RCOM	17
+#define	GO	0x1140
+#define	IENABLE	0x12a
+#define	ERR	0x2a
+#define	DTDIR	02
+#define	BLK512	0220
+#define	CLEAR	0x1fe00fff
@@ -32,11 +41,2 @@
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
-struct	buf	rktab;
+int	sdirq = 82;
+struct	buf	sdtab;
@@ -45 +45,8 @@
-rkstrategy(bp)
+void
+sdinit()
+{
+	SD(DTIMER) = -1;
+}
+
+int
+sdstrategy(bp)
@@ -47,0 +55 @@
+	int s;
@@ -49,11 +57,4 @@
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
+	bp->av_forw = NULL;
+	s = spl5();
+	if (sdtab.b_actf == NULL)
+		sdtab.b_actf = bp;
@@ -61,3 +62,3 @@
-		rktab.b_actl->av_forw = bp;
-	rktab.b_actl = bp;
-	if(rktab.b_active == NULL)
+		sdtab.b_actl->av_forw = bp;
+	sdtab.b_actl = bp;
+	if(sdtab.b_active == NULL)
@@ -65 +66,2 @@
-	spl0();
+	splx(s);
+	return(0);
@@ -67,0 +70 @@
+void
@@ -71,3 +74 @@
-	register com;
-	daddr_t bn;
-	int dn, cn, sn;
+	register int com;
@@ -75 +76 @@
-	if ((bp = rktab.b_actf) == NULL)
+	if ((bp = sdtab.b_actf) == NULL)
@@ -77,9 +78,11 @@
-	rktab.b_active++;
-	bn = bp->b_blkno;
-	dn = minor(bp->b_dev);
-	cn = bn/12;
-	sn = bn%12;
-	RKADDR->rkda = (dn<<13) | (cn<<4) | sn;
-	RKADDR->rkba = bp->b_un.b_addr;
-	RKADDR->rkwc = -(bp->b_bcount>>1);
-	com = ((bp->b_xmem&3) << 4) | IENABLE | GO;
+	sdtab.b_active++;
+	dcflush(bp->b_un.b_addr, bp->b_bcount);
+	SD(ICR) = CLEAR;
+	SD(DCTRL) = 0;
+	SD(DLEN) = bp->b_bcount;
+	SD(DCTRL) = bp->b_flags&B_READ ? BLK512|DTDIR : BLK512;
+	SD(IDMABASER) = (int)bp->b_un.b_addr;
+	SD(IDMACTRL) = 1;
+	SD(MASK) = IENABLE;
+	SD(ARG) = bp->b_blkno;
+	com = GO;
@@ -89 +92 @@
-	RKADDR->rkcs = com;
+	SD(CMD) = com;
@@ -96 +99,2 @@
-rkintr()
+int
+sdintr()
@@ -98,0 +103 @@
+	register int sta;
@@ -100,2 +105,6 @@
-	if (rktab.b_active == NULL)
-		return;
+	sta = SD(STA);
+	SD(ICR) = CLEAR;
+	SD(MASK) = 0;
+	SD(IDMACTRL) = 0;
+	if (sdtab.b_active == NULL)
+		return(0);
@@ -103,8 +112,5 @@
-	bp = rktab.b_actf;
-	rktab.b_active = NULL;
-	if (RKADDR->rkcs < 0) {		/* error bit */
-		deverror(bp, RKADDR->rker, RKADDR->rkds);
-		RKADDR->rkcs = RESET|GO;
-		while((RKADDR->rkcs&CTLRDY) == 0)
-			;
-		if (++rktab.b_errcnt <= 10) {
+	bp = sdtab.b_actf;
+	sdtab.b_active = NULL;
+	if (sta & ERR) {
+		deverror(bp, sta, 0);
+		if (++sdtab.b_errcnt <= 10) {
@@ -112 +118 @@
-			return;
+			return(0);
@@ -116,2 +122,4 @@
-	rktab.b_errcnt = 0;
-	rktab.b_actf = bp->av_forw;
+	if (bp->b_flags & B_READ)
+		dcflush(bp->b_un.b_addr, bp->b_bcount);
+	sdtab.b_errcnt = 0;
+	sdtab.b_actf = bp->av_forw;
@@ -120,0 +129 @@
+	return(0);
@@ -123 +132,2 @@
-rkread(dev)
+int
+sdread(dev)
@@ -127 +137,2 @@
-	physio(rkstrategy, &rrkbuf, dev, B_READ);
+	physio(sdstrategy, &rrkbuf, dev, B_READ);
+	return(0);
@@ -130 +141,2 @@
-rkwrite(dev)
+int
+sdwrite(dev)
@@ -134 +146,2 @@
-	physio(rkstrategy, &rrkbuf, dev, B_WRITE);
+	physio(sdstrategy, &rrkbuf, dev, B_WRITE);
+	return(0);

% usr/sys/dev/stm32usart.c usr/sys/dev/kl.c
@@ -12,3 +12,3 @@
-#define	KLADDR	((struct device *)0177560)	/* console */
-#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
-#define	DLBASE	((struct device *)0175610)	/* dl-e */
+#define	KLADDR	0x40010000
+#define	RCC	0x50000000
+#define	GPIOD	0x50005000
@@ -17,2 +17,19 @@
-#define DSRDY	02
-#define	RDRENB	01
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
@@ -28 +45 @@
-int	klstart();
+int	usstart();
@@ -30,8 +47,19 @@
-char	partab[];
-
-struct device {
-	int	rcsr;
-	int	rbuf;
-	int	tcsr;
-	int	tbuf;
-};
+int	usirq = 85;
+int	ttread(), ttioccomm(), getc();
+void	ttyopen(), ttyclose(), ttychars(), ttyinput(), ttstart(), timeout(), wakeup();
+caddr_t	ttwrite();
+
+void
+usinit()
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
@@ -39 +67,2 @@
-klopen(dev, flag)
+int
+usopen(dev, flag)
@@ -40,0 +70 @@
+int flag;
@@ -42 +71,0 @@
-	register struct device *addr;
@@ -44 +73 @@
-	register d;
+	register int d;
@@ -45,0 +75 @@
+	(void)flag;
@@ -49 +79 @@
-		return;
+		return(0);
@@ -52,13 +82 @@
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
+	tp->t_oproc = usstart;
@@ -67 +85 @@
-		tp->t_flags = EVENP|LCASE|ECHO|XTABS|CRMOD|CR2;
+		tp->t_flags = EVENP|ECHO|XTABS|CRMOD;
@@ -70,2 +88 @@
-	addr->rcsr |= IENABLE|DSRDY|RDRENB;
-	addr->tcsr |= IENABLE;
+	CR1 |= RXNEIE;
@@ -72,0 +90 @@
+	return(0);
@@ -75 +93,2 @@
-klclose(dev, flag)
+int
+usclose(dev, flag)
@@ -80,0 +100 @@
+	(void)flag;
@@ -82,0 +103 @@
+	return(0);
@@ -85 +106,2 @@
-klread(dev)
+int
+usread(dev)
@@ -88,0 +111 @@
+	return(0);
@@ -91 +114,2 @@
-klwrite(dev)
+int
+uswrite(dev)
@@ -94,0 +119 @@
+	return(0);
@@ -97 +122,2 @@
-klxint(dev)
+void
+usxint(dev)
@@ -102,0 +129 @@
+	CR1 &= ~TXEIE;
@@ -105,4 +132 @@
-		if (tp->t_chan)
-			mcstart(tp->t_chan, (caddr_t)&tp->t_outq);
-		else
-			wakeup((caddr_t)&tp->t_outq);
+		wakeup((caddr_t)&tp->t_outq);
@@ -111 +135,2 @@
-klrint(dev)
+void
+usrint(dev)
@@ -115 +139,0 @@
-	register struct device *addr;
@@ -119,3 +143,2 @@
-	addr = (struct device *)tp->t_addr;
-	c = addr->rbuf;
-	addr->rcsr |= RDRENB;
+	c = RDR;
+	ICR = 017;
@@ -125 +148,2 @@
-klioctl(dev, cmd, addr, flag)
+int
+usioctl(dev, cmd, addr, flag)
@@ -127,0 +152 @@
+int cmd, flag;
@@ -129 +154,2 @@
-	if (ttioccom(cmd, &kl11[minor(dev)], addr, dev)==0)
+	(void)flag;
+	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
@@ -130,0 +157 @@
+	return(0);
@@ -133 +160,2 @@
-klstart(tp)
+int
+usstart(tp)
@@ -136,2 +164 @@
-	register c;
-	register struct device *addr;
+	register int c;
@@ -139,3 +166,2 @@
-	addr = (struct device *)tp->t_addr;
-	if((addr->tcsr&DONE) == 0)
-		return;
+	if((ISR&TXE) == 0)
+		return(0);
@@ -144 +170 @@
-			addr->tbuf = c;
+			TDR = c;
@@ -146 +172 @@
-			addr->tbuf = c | (partab[c]&0200);
+			TDR = c;
@@ -150,0 +177 @@
+		CR1 |= TXEIE;
@@ -151,0 +179,11 @@
+	return(0);
+}
+
+int
+usintr()
+{
+	if (ISR&RXNE)
+		usrint(0);
+	if (ISR&TXE && CR1&TXEIE)
+		usxint(0);
+	return(0);
@@ -154 +191,0 @@
-char	*msgbufp = msgbuf;	/* Next saved printf character */
@@ -166,2 +203,2 @@
-putchar(c)
-register c;
+void
+usputchar(char c)
@@ -169 +206 @@
-	register s, timo;
+	register int s, timo;
@@ -176,5 +212,0 @@
-	/*
-	 *  If last char was a break or null, don't print
-	*/
-	if ((KLADDR->rbuf&0177) == 0)
-		return;
@@ -186 +218 @@
-	while((KLADDR->tcsr&0200) == 0)
+	while((ISR&TXE) == 0)
@@ -191,3 +223,3 @@
-	s = KLADDR->tcsr;
-	KLADDR->tcsr = 0;
-	KLADDR->tbuf = c;
+	s = CR1;
+	CR1 &= ~TXEIE;
+	TDR = c;
@@ -195,3 +227 @@
-		putchar('\r');
-		putchar(0177);
-		putchar(0177);
+		usputchar('\r');
@@ -199,2 +229,2 @@
-	putchar(0);
-	KLADDR->tcsr = s;
+	usputchar(0);
+	CR1 = s;

% usr/sys/dev/sys.c
@@ -10,0 +11 @@
+int
@@ -11,0 +13 @@
+int	dev, flag;
@@ -13,0 +16 @@
+	(void)dev;
@@ -16 +19 @@
-		return;
+		return(0);
@@ -18,0 +22 @@
+	return(0);
@@ -20,0 +25 @@
+int
@@ -21,0 +27 @@
+int	dev;
@@ -23,0 +30 @@
+	(void)dev;
@@ -24,0 +32 @@
+	return(0);
@@ -26,0 +35 @@
+int
@@ -27,0 +37 @@
+int	dev;
@@ -29,0 +40 @@
+	(void)dev;
@@ -30,0 +42 @@
+	return(0);
@@ -32,0 +45 @@
+int
@@ -34,0 +48 @@
+int	dev, cmd, flag;
@@ -36,0 +51 @@
+	(void)dev;
@@ -37,0 +53 @@
+	return(0);

% usr/sys/dev/tty.c
@@ -11 +10,0 @@
-#include "../h/mx.h"
@@ -17 +16 @@
-char	partab[];
+extern char	partab[];
@@ -60,0 +60 @@
+void
@@ -83,0 +84 @@
+void
@@ -99,0 +101 @@
+void
@@ -111,0 +114 @@
+void
@@ -118,0 +122 @@
+void
@@ -130,0 +135 @@
+void
@@ -141 +146 @@
-	register fmt;
+	register int fmt;
@@ -166,0 +172 @@
+int
@@ -169,0 +176 @@
+int	com, dev;
@@ -194 +201 @@
-		if (t >= nldisp) {
+		if (t >= (unsigned)nldisp) {
@@ -199 +206 @@
-			(*linesw[tp->t_line].l_close)(tp);
+			(*linesw[(int)tp->t_line].l_close)(tp);
@@ -220,0 +228 @@
+		/* fallthrough */
@@ -263 +271 @@
-		(*linesw[tp->t_line].l_ioctl)(com, tp, addr);
+		(*linesw[(int)tp->t_line].l_ioctl)(com, tp, addr);
@@ -287,0 +296 @@
+void
@@ -304,0 +314 @@
+void
@@ -308 +318 @@
-	register s;
+	register int s;
@@ -332,0 +343 @@
+int
@@ -342,2 +353,2 @@
-	while ((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0
-	    || (tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0) {
+	while (((tp->t_flags&(RAW|CBREAK))==0 && tp->t_delct==0)
+	    || ((tp->t_flags&(RAW|CBREAK))!=0 && tp->t_rawq.c_cc==0)) {
@@ -400,0 +412 @@
+void
@@ -410,2 +421,0 @@
-		if (tp->t_chan)
-			sdata(tp->t_chan); else
@@ -429,0 +440 @@
+void
@@ -431 +442 @@
-register c;
+register int c;
@@ -435 +445,0 @@
-	register struct chan *cp;
@@ -466,3 +475,0 @@
-			if (tp->t_chan)
-				scontrol(tp->t_chan, M_SIG, c);
-			else
@@ -485,3 +492 @@
-		if ((cp=tp->t_chan)!=NULL)
-			sdata(cp); else
-			wakeup((caddr_t)&tp->t_rawq);
+		wakeup((caddr_t)&tp->t_rawq);
@@ -500,0 +506 @@
+void
@@ -504 +510 @@
-register x;
+register int x;
@@ -525,0 +532 @@
+void
@@ -527 +534 @@
-register c;
+register int c;
@@ -531 +538 @@
-	register ctype;
+	register int ctype;
@@ -595,0 +603 @@
+		/* fallthrough */
@@ -657,0 +666 @@
+int
@@ -663,0 +673 @@
+	return(0);
@@ -671,0 +682 @@
+void
@@ -675 +686 @@
-	register s;
+	register int s;
@@ -686,0 +698 @@
+int
@@ -707 +719 @@
-	register c;
+	register int c;

% usr/sys/dev/virtio_blk.c usr/sys/dev/rk.c
@@ -12,14 +12,5 @@
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
+void panic(), dmbsy(), iodone(), deverror(), physio(), rkstart();
+int spl5(), splx();
+
+#define	RKADDR(off)	(*(volatile int *)(vbase+(off)))
+#define	NVQ	8
@@ -32 +23 @@
-struct	device
+struct	vring
@@ -34,6 +25,13 @@
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
+	unsigned short	uflags;
+	unsigned short	uidx;
+	int	uring[2*NVQ];
@@ -43,0 +42,29 @@
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
+
+void
+rkinit()
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
+	RKADDR(0x3c) = 4;
+	vq = (struct vring *)(((int)vqbuf+4095) & ~4095);
+	RKADDR(0x40) = (int)vq >> 12;
+	RKADDR(0x70) = 7;
+	rkirq = 48 + (vbase-0x0a000000)/0x200;
+}
@@ -44,0 +72 @@
+int
@@ -47,0 +76 @@
+	int s;
@@ -49,9 +78,2 @@
-	if(bp->b_flags&B_PHYS)
-		mapalloc(bp);
-	if (bp->b_blkno >= NRKBLK) {
-		bp->b_flags |= B_ERROR;
-		iodone(bp);
-		return;
-	}
-	bp->av_forw = (struct buf *)NULL;
-	spl5();
+	bp->av_forw = NULL;
+	s = spl5();
@@ -65 +87,2 @@
-	spl0();
+	splx(s);
+	return(0);
@@ -67,0 +91 @@
+void
@@ -71,3 +95 @@
-	register com;
-	daddr_t bn;
-	int dn, cn, sn;
+	register int com;
@@ -78,12 +100,17 @@
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
@@ -95,0 +123 @@
+int
@@ -100,2 +128,4 @@
-	if (rktab.b_active == NULL)
-		return;
+	RKADDR(0x64) = RKADDR(0x60);
+	if (rktab.b_active == NULL || vq->uidx != vq->aidx)
+		return(0);
+	dmbsy();
@@ -105,5 +135,2 @@
-	if (RKADDR->rkcs < 0) {		/* error bit */
-		deverror(bp, RKADDR->rker, RKADDR->rkds);
-		RKADDR->rkcs = RESET|GO;
-		while((RKADDR->rkcs&CTLRDY) == 0)
-			;
+	if (vstatus) {
+		deverror(bp, vstatus, 0);
@@ -112 +139 @@
-			return;
+			return(0);
@@ -120,0 +148 @@
+	return(0);
@@ -122,0 +151 @@
+int
@@ -127,0 +157 @@
+	return(0);
@@ -129,0 +160 @@
+int
@@ -134,0 +166 @@
+	return(0);

% usr/sys/h/acct.h

% usr/sys/h/buf.h

% usr/sys/h/callo.h

% usr/sys/h/conf.h
@@ -37 +37 @@
-	int	(*l_open)();
+	void	(*l_open)();
@@ -42,2 +42,2 @@
-	int	(*l_rint)();
-	int	(*l_rend)();
+	void	(*l_rint)();
+	void	(*l_rend)();
@@ -47,0 +48,6 @@
+
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
+	int	m_size;
+	int	m_addr;

% usr/sys/h/mount.h

% usr/sys/h/param.h
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
+typedef	int		label_t[10];	/* regs 2-7 */
@@ -144,0 +145,2 @@
+
+extern unsigned kernbase, corebase, coretop, pguser, gicdbase, giccbase;

% usr/sys/h/proc.h
@@ -21 +21 @@
-	short	p_addr;		/* address of swappable image */
+	int	p_addr;		/* address of swappable image */

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
@@ -23,0 +24,10 @@
+#define	USERSIZE	0x100000
+#define	UENTRY_SIGTRAMP	8
+#define	NCLICK	((coretop-corebase)>>6)
+#define	CLKADDR(c)	((char *)(corebase+((unsigned)(c)<<6)))
+#define	SEC_KERN	0x1140e
+#define	SEC_DEV	0xc02
+#define	PTE_PT	1
+#define	PGSHIFT	12
+#define	PGSIZE	4096
+struct memregion { unsigned start, end, attr; };

% usr/sys/h/stat.h

% usr/sys/h/systm.h
@@ -41,0 +42 @@
+extern	char	*msgbufp;	/* next saved printf character */
@@ -63,0 +65,31 @@
+void	acct(), addupc(), arm_sureg(), arm_sync_icache(), bawrite(),
+	bcopy(), bdinit(), bdwrite(), bflush(), binit(), brelse(), bwrite(),
+	chdirec(), cinit(), clearseg(), clkstart(), clock(), clock_ddr_init(),
+	closef(), clrbuf(), cninit(), cntv_ctl_set(), cntv_tval_set(),
+	copyseg(), deverror(), exece(), exit(), expand(), flushtty(), free(),
+	geterror(), idle(), iexpand(), ifree(), iinit(), install_sigtramp(),
+	ioctl(), iodone(), iomove(), iowait(), iput(), itrunc(), iupdat(),
+	mapfree(), mfree(), mmu_on(), notavail(), open1(), openi(), panic(),
+	physio(), plock(), prdev(), prele(), printn(), psig(), psignal(),
+	putchar(), qswtch(), rdwr(), readi(), readp(), resume(), savfp(),
+	sched(), sendsig(), setregs(), setrun(), signal(), sleep(), startup(),
+	stat1(), sureg(), swap(), swtch(), timeout(), tloop(), ttstart(),
+	ttyblock(), ttychars(), ttyclose(), ttyinput(), ttyopen(), ttyoutput(),
+	update(), wakeup(), wdir(), wflushtty(), writei(), writep(), xalloc(),
+	xccdec(), xexpand(), xfree(), xlock(), xrele(), xswap(), xumount(),
+	xunlock(), xuntext();
+int	access(), b_to_q(), badblock(), cntfrq_get(), compress(), copyin(),
+	copyout(), core(), cpass(), dfar(), dfsr(), estabur(), fsig(),
+	fubyte(), fumem(), fuword(), getc(), getxfile(), incore(), issig(),
+	malloc(), max(), min(), newproc(), passc(), procxmt(), putc(), save(),
+	setpri(), spl0(), spl1(), spl5(), spl6(), spl7(), splx(), subyte(),
+	sumem(), suser(), suword(), swapin(), ttioccomm(), ttread(), ttrstrt(),
+	ufalloc();
+caddr_t	ttwrite();
+void	printf(char *, ...);
+#define	fuibyte	fubyte
+#define	fuiword	fuword
+#define	suibyte	subyte
+#define	suiword	suword
+#define	copyiin	copyin
+#define	copyiout	copyout
@@ -80 +112 @@
-	int	(*sy_call)();		/* handler */
+	void	(*sy_call)();		/* handler */

% usr/sys/h/text.h
@@ -10 +10 @@
-	short	x_caddr;	/* core address, if loaded */
+	int	x_caddr;	/* core address, if loaded */

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
@@ -99 +103 @@
-extern struct user u;
+#define	u	(*(struct user *)UBASE)

% usr/sys/sys/acct.c
@@ -13,0 +14 @@
+void
@@ -50,0 +52 @@
+void
@@ -53 +55 @@
-	register i;
+	register int i;
@@ -60 +62 @@
-	for (i=0; i<sizeof(acctbuf.ac_comm); i++)
+	for (i=0; i<(int)sizeof(acctbuf.ac_comm); i++)
@@ -87,0 +90 @@
+int
@@ -91 +94 @@
-	register exp = 0, round = 0;
+	register int exp = 0, round = 0;
@@ -112,0 +116 @@
+void

% usr/sys/sys/alloc.c
@@ -77,0 +78 @@
+void
@@ -119,0 +121 @@
+int
@@ -222,0 +225 @@
+void
@@ -285,0 +289 @@
+void

% usr/sys/sys/clock.c
@@ -27,0 +28 @@
+void
@@ -30,0 +32 @@
+int	sp, r1, nps, r0, ps;
@@ -35,0 +38 @@
+	(void)dev; (void)sp; (void)r1; (void)nps; (void)r0;
@@ -41 +43,0 @@
-	lks->r[0] = 0115;
@@ -47 +48,0 @@
-	display();
@@ -79 +80 @@
-		while(p2->c_func = p1->c_func) {
+		while((p2->c_func = p1->c_func)) {
@@ -153,0 +155 @@
+void
@@ -156,0 +159 @@
+int	tim;
@@ -184,0 +188,19 @@
+}
+void
+addupc(pc, p, t)
+caddr_t pc;
+register unsigned *p;
+int t;
+{
+	register unsigned i;
+	short c;
+
+	i = ((unsigned long long)(((unsigned)pc-p[2])>>1) * (p[3]>>1) >> 14) & ~1;
+	if (i >= p[1])
+		return;
+	if (copyin((caddr_t)p[0]+i, (caddr_t)&c, 2) < 0) {
+		p[3] = 0;
+		return;
+	}
+	c += t;
+	copyout((caddr_t)&c, (caddr_t)p[0]+i, 2);

% usr/sys/sys/fio.c
@@ -44,0 +45 @@
+void
@@ -101,0 +103 @@
+void
@@ -103,0 +106 @@
+int	rw;
@@ -114 +117 @@
-		if(maj >= nchrdev)
+		if(maj >= (unsigned)nchrdev)
@@ -121 +124 @@
-		if(maj >= nblkdev)
+		if(maj >= (unsigned)nblkdev)
@@ -143,0 +147 @@
+int
@@ -145,0 +150 @@
+int	mode;
@@ -147 +152 @@
-	register m;
+	register int m;
@@ -203,0 +209 @@
+int
@@ -217,0 +224 @@
+int
@@ -220 +227 @@
-	register i;
+	register int i;
@@ -245 +252 @@
-	register i;
+	register int i;

% usr/sys/sys/iget.c
@@ -91,0 +92 @@
+void
@@ -109 +109,0 @@
-		*p1++ = 0;
@@ -111,0 +112 @@
+		*p1++ = 0;
@@ -121,0 +123 @@
+void
@@ -148,0 +151 @@
+void
@@ -177,0 +181,2 @@
+			*p1++ = *p2++;
+			*p1++ = *p2++;
@@ -181,2 +185,0 @@
-			*p1++ = *p2++;
-			*p1++ = *p2++;
@@ -203,0 +207 @@
+void
@@ -207 +211 @@
-	register i;
+	register int i;
@@ -241,0 +246 @@
+void
@@ -244,0 +250 @@
+int	f1, f2;
@@ -246 +252 @@
-	register i;
+	register int i;
@@ -280,0 +287 @@
+int	mode;
@@ -304,0 +312 @@
+void

% usr/sys/sys/machdep.c
@@ -11,0 +12 @@
+#include "../h/conf.h"
@@ -20,11 +21,18 @@
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
@@ -36,0 +45 @@
+void
@@ -39 +48 @@
-	register i;
+	register int i;
@@ -45,19 +54,4 @@
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
@@ -66,7 +60 @@
-
-	/*
-	 * determine clock
-	 */
-
-	UISA->r[7] = ka6->r[1]; /* io segment */
-	UISD->r[7] = 077406;
+	bdinit();
@@ -78,0 +67 @@
+void
@@ -81 +70 @@
-	register i, s, d;
+	register int i, s, d;
@@ -125,2 +114,16 @@
-#define	CLOCK1	((physadr)0177546)
-#define	CLOCK2	((physadr)0172540)
+#define	GICD(o)	(*(volatile unsigned *)(gicdbase+(o)))
+#define	GICC(o)	(*(volatile unsigned *)(giccbase+(o)))
+#define	TIMER	27
+extern struct intr intrtab[];
+unsigned	clkreload;
+int	irq_ready;
+
+void
+gicen(n)
+int n;
+{
+	*(volatile unsigned char *)(gicdbase+0x400+n) = 0x80;
+	GICD(0x100+(n>>5)*4) = 1U << (n&31);
+}
+
+void
@@ -129,7 +132,35 @@
-	lks = CLOCK1;
-	if(fuiword((caddr_t)lks) == -1) {
-		lks = CLOCK2;
-		if(fuiword((caddr_t)lks) == -1)
-			panic("no clock");
-	}
-	lks->r[0] = 0115;
+	register struct intr *ip;
+
+	if((clkreload = cntfrq_get()/HZ) == 0)
+		panic("no clock");
+	gicen(TIMER);
+	for(ip = intrtab; ip->i_irq; ip++)
+		if(*ip->i_irq)
+			gicen(*ip->i_irq);
+	GICD(0) = 1;
+	GICC(4) = 0xff;
+	GICC(0) = 1;
+	cntv_tval_set(clkreload);
+	cntv_ctl_set(1);
+	irq_ready = 1;
+	spl0();
+}
+
+void
+irq(r)
+int *r;
+{
+	register struct intr *ip;
+	register unsigned n;
+
+	n = GICC(0xc);
+	if((n&0x3ff) == TIMER) {
+		cntv_tval_set(clkreload);
+		if(u.u_procp != NULL)
+			clock(0, 0, 0, 0, 0, (caddr_t)r[PC],
+			    (r[RPS]&0x1f) == 0x10 ? UMODE : 0);
+	} else
+		for(ip = intrtab; ip->i_irq; ip++)
+			if(*ip->i_irq == (int)(n&0x3ff))
+				(*ip->i_fn)();
+	GICC(0x10) = n;
@@ -140,0 +172 @@
+void
@@ -142,0 +175 @@
+int	signo;
@@ -146,4 +179,6 @@
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
@@ -151 +186 @@
-	u.u_ar0[RPS] &= ~TBIT;
+	u.u_ar0[14] = UENTRY_SIGTRAMP;
@@ -152,0 +188 @@
+	u.u_ar0[R0] = signo;
@@ -164,0 +201 @@
+void
@@ -168 +205 @@
-	register i, a;
+	register int i, a;
@@ -187,0 +225 @@
+void
@@ -195,0 +234,206 @@
+}
+
+extern struct memregion board_map[];
+extern char __bss_end[], __ddrbss_start[], __ddrbss_end[];
+extern unsigned l1[], user_l2[], uarea_l2[];
+char	*msgbufp = msgbuf;
+
+void
+machine_init()
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
+arm_sureg()
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
+copyseg(from, to)
+int from, to;
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
+clearseg(a)
+int a;
+{
+	register int *d, i;
+
+	d = (int *)CLKADDR(a);
+	for(i = 0; i < 16; i++)
+		d[i] = 0;
+}
+
+int
+uaddr(a, n)
+caddr_t a;
+unsigned n;
+{
+	return((unsigned)a < USERSIZE && n <= USERSIZE - (unsigned)a);
+}
+
+int
+fubyte(a)
+caddr_t a;
+{
+	if(!uaddr(a, 1))
+		return(-1);
+	return(*a & 0377);
+}
+
+int
+subyte(a, c)
+caddr_t a;
+int c;
+{
+	if(!uaddr(a, 1))
+		return(-1);
+	*a = c;
+	return(0);
+}
+
+int
+fuword(a)
+caddr_t a;
+{
+	if(!uaddr(a, sizeof(int)))
+		return(-1);
+	return(*(int *)a);
+}
+
+int
+suword(a, v)
+caddr_t a;
+int v;
+{
+	if(!uaddr(a, sizeof(int)))
+		return(-1);
+	*(int *)a = v;
+	return(0);
+}
+
+int
+copyin(f, t, n)
+caddr_t f, t;
+unsigned n;
+{
+	if(!uaddr(f, n))
+		return(-1);
+	bcopy(f, t, n);
+	return(0);
+}
+
+int
+copyout(f, t, n)
+caddr_t f, t;
+unsigned n;
+{
+	if(!uaddr(t, n))
+		return(-1);
+	bcopy(f, t, n);
+	return(0);
+}
+
+void
+sigreturn()
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
+char *
+memaddr(off)
+off_t off;
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
+fumem(off)
+off_t off;
+{
+	register char *a;
+
+	if((a = memaddr(off)) == NULL)
+		return(-1);
+	return(*a & 0377);
+}
+
+int
+sumem(off, c)
+off_t off;
+int c;
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
+install_sigtramp()
+{
+	suword((caddr_t)UENTRY_SIGTRAMP, (int)0xe3a0703fU);	/* mov r7, #63 */
+	suword((caddr_t)UENTRY_SIGTRAMP+4, (int)0xef000000U);	/* svc #0 */
+}
+
+void
+panictrap()
+{
+	panic("trap");

% usr/sys/sys/main.c
@@ -29,0 +30 @@
+void
@@ -38 +39 @@
-	proc[0].p_addr = ka6->r[0];
+	proc[0].p_addr = 64;
@@ -70,0 +72 @@
+		arm_sync_icache();
@@ -89,0 +92 @@
+void
@@ -119 +122 @@
-char	buffers[NBUF][BSIZE+BSLOP];
+char	buffers[NBUF][(BSIZE+BSLOP+3)&~3];
@@ -124,0 +128 @@
+void

% usr/sys/sys/malloc.c
@@ -14,0 +15 @@
+int
@@ -16,0 +18 @@
+int	size;
@@ -29 +31 @@
-				} while ((bp-1)->m_size = bp->m_size);
+				} while (((bp-1)->m_size = bp->m_size));
@@ -42,0 +45 @@
+void
@@ -45,0 +49 @@
+int	size;
@@ -77 +81 @@
-			} while (size = t);
+			} while ((size = t));

% usr/sys/sys/nami.c
@@ -22,0 +23 @@
+int	flag;
@@ -25 +26 @@
-	register c;
+	register int c;
@@ -205,0 +207 @@
+int
@@ -215,0 +218 @@
+int
@@ -218 +221 @@
-	register c;
+	register int c;

% usr/sys/sys/pipe.c
@@ -24,0 +25 @@
+void
@@ -60,0 +62 @@
+void
@@ -115,0 +118 @@
+void
@@ -119 +122 @@
-	register c;
+	register int c;
@@ -188,0 +192 @@
+void
@@ -206,0 +211 @@
+void

% usr/sys/sys/prf.c
@@ -5,0 +6 @@
+#include <stdarg.h>
@@ -26,3 +27,2 @@
-printf(fmt, x1)
-register char *fmt;
-unsigned x1;
+void
+printf(char *fmt, ...)
@@ -30,2 +30,2 @@
-	register c;
-	register unsigned int *adx;
+	register int c;
+	va_list adx;
@@ -34 +34 @@
-	adx = &x1;
+	va_start(adx, fmt);
@@ -37 +37,2 @@
-		if(c == '\0')
+		if(c == '\0') {
+			va_end(adx);
@@ -38,0 +40 @@
+		}
@@ -43 +45 @@
-		printn((long)*adx, c=='o'? 8: (c=='x'? 16:10));
+		printn((long)va_arg(adx, unsigned), c=='o'? 8: (c=='x'? 16:10));
@@ -45,2 +47,2 @@
-		s = (char *)*adx;
-		while(c = *s++)
+		s = va_arg(adx, char *);
+		while((c = *s++))
@@ -49,2 +51 @@
-		printn(*(long *)adx, 10);
-		adx += (sizeof(long) / sizeof(int)) - 1;
+		printn(va_arg(adx, long), 10);
@@ -52 +52,0 @@
-	adx++;
@@ -58,0 +59 @@
+void
@@ -60,0 +62 @@
+int	b;
@@ -68 +70 @@
-	if(a = n/b)
+	if((a = n/b))
@@ -78,0 +81 @@
+void
@@ -94,0 +98 @@
+void
@@ -109,0 +114 @@
+void
@@ -111,0 +117 @@
+int	o1, o2;

% usr/sys/sys/prim.c
@@ -18,0 +19 @@
+int
@@ -54,0 +56 @@
+int
@@ -57,0 +60 @@
+int	cc;
@@ -101,0 +105 @@
+int
@@ -103,0 +108 @@
+int	flag;
@@ -105 +110 @@
-register cc;
+register int cc;
@@ -142,0 +148 @@
+void
@@ -145 +151 @@
-register cc;
+register int cc;
@@ -147 +153 @@
-register s;
+register int s;
@@ -190,0 +197 @@
+int
@@ -192,0 +200 @@
+int	c;
@@ -196 +204 @@
-	register s;
+	register int s;
@@ -230,0 +239 @@
+int
@@ -238 +247 @@
-	register s, acc;
+	register int s, acc;
@@ -277,0 +287 @@
+void
@@ -300,0 +311 @@
+int
@@ -311,0 +323 @@
+int
@@ -313,0 +326 @@
+int	c;
@@ -315 +328 @@
-	register s;
+	register int s;

% usr/sys/sys/rdwri.c
@@ -18,0 +19 @@
+void
@@ -26,2 +27,2 @@
-	register on, n;
-	register type;
+	register int on, n;
+	register int type;
@@ -39 +40,2 @@
-		return((*cdevsw[major(dev)].d_read)(dev));
+		(*cdevsw[major(dev)].d_read)(dev);
+		return;
@@ -82,0 +85 @@
+void
@@ -89,2 +92,2 @@
-	register n, on;
-	register type;
+	register int n, on;
+	register int type;
@@ -135,0 +139 @@
+int
@@ -148,0 +153 @@
+int
@@ -172,0 +178 @@
+void
@@ -175 +181,2 @@
-register n;
+register int n;
+int	flag;
@@ -177 +184 @@
-	register t;
+	register int t;

% usr/sys/sys/sig.c
@@ -38,0 +39 @@
+void
@@ -40 +41,2 @@
-register pgrp;
+register int pgrp;
+int	sig;
@@ -54,0 +57 @@
+void
@@ -57 +60 @@
-register sig;
+register int sig;
@@ -80,0 +84 @@
+int
@@ -83 +87 @@
-	register n;
+	register int n;
@@ -101,0 +106 @@
+void
@@ -127,0 +133 @@
+void
@@ -130 +136 @@
-	register n, p;
+	register int n, p;
@@ -171,0 +178 @@
+int
@@ -175 +182 @@
-	register n, i;
+	register int n, i;
@@ -195,0 +203 @@
+int
@@ -200 +208 @@
-	extern schar();
+	extern int schar();
@@ -236,0 +245 @@
+int
@@ -240 +249 @@
-	register si, i;
+	register int si, i;
@@ -242 +251 @@
-	register a;
+	register int a;
@@ -266,0 +276 @@
+void
@@ -312,0 +323 @@
+int
@@ -316 +327 @@
-	register *p;
+	register int *p;
@@ -345 +356 @@
-		ipc.ip_data = ((physadr)&u)->r[i>>1];
+		ipc.ip_data = ((physadr)&u)->r[i>>2];
@@ -354 +365 @@
-		if (xp = u.u_procp->p_textp) {
+		if ((xp = u.u_procp->p_textp)) {
@@ -379 +390 @@
-		p = (int *)&((physadr)&u)->r[i>>1];
+		p = (int *)&((physadr)&u)->r[i>>2];
@@ -383 +394 @@
-			if (p == &u.u_ar0[regloc[i]])
+			if (p == &u.u_ar0[regloc[i]&0377])
@@ -386 +397 @@
-			ipc.ip_data |= 0170000;	/* assure user space */
+			ipc.ip_data = (ipc.ip_data&0xf80f0000) | 020;	/* assure user space */
@@ -399 +409,0 @@
-		u.u_ar0[RPS] |= TBIT;
@@ -410,0 +421 @@
+		return(1);

% usr/sys/sys/slp.c
@@ -26,0 +27 @@
+void
@@ -28,0 +30 @@
+int	pri;
@@ -31 +33 @@
-	register s, h;
+	register int s, h;
@@ -81,0 +84 @@
+void
@@ -86 +89 @@
-	register i;
+	register int i;
@@ -117,0 +121 @@
+void
@@ -122 +126 @@
-	register s;
+	register int s;
@@ -139,0 +144 @@
+void
@@ -151 +156 @@
-	if (w = p->p_wchan) {
+	if ((w = p->p_wchan)) {
@@ -170,0 +176 @@
+int
@@ -174 +180 @@
-	register p;
+	register int p;
@@ -201,0 +208 @@
+void
@@ -205 +212 @@
-	register outage, inage;
+	register int outage, inage;
@@ -257 +264 @@
-		if (rp->p_stat==SSLEEP&&rp->p_pri>=PZERO || rp->p_stat==SSTOP) {
+		if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) || rp->p_stat==SSTOP) {
@@ -291,0 +299 @@
+int
@@ -301 +309 @@
-	if (xp = p->p_textp) {
+	if ((xp = p->p_textp)) {
@@ -328,0 +337 @@
+void
@@ -346,0 +356 @@
+void
@@ -349 +359 @@
-	register n;
+	register int n;
@@ -425,0 +436 @@
+int
@@ -431 +442 @@
-	register n;
+	register int n;
@@ -544,0 +556 @@
+void
@@ -545,0 +558 @@
+int	newsize;
@@ -547 +560 @@
-	register i, n;
+	register int i, n;
@@ -549 +562 @@
-	register a1, a2;
+	register int a1, a2;
@@ -550,0 +564 @@
+	newsize = (newsize + 63) & ~63;

% usr/sys/sys/subr.c
@@ -20,0 +21 @@
+int	rwflg;
@@ -22 +23 @@
-	register i;
+	register int i;
@@ -117 +118 @@
-	if(i < NINDIR-1)
+	if((unsigned)i < NINDIR-1)
@@ -127,0 +129 @@
+int
@@ -129 +131 @@
-register c;
+register int c;
@@ -131 +133 @@
-	register id;
+	register int id;
@@ -152,0 +155 @@
+int
@@ -155 +158 @@
-	register c, id;
+	register int c, id;
@@ -175,0 +179 @@
+int
@@ -179,0 +184 @@
+	return(0);
@@ -185,0 +191 @@
+int
@@ -187,0 +194 @@
+	return(0);
@@ -192,0 +200 @@
+void
@@ -195 +203 @@
-register count;
+register int count;

% usr/sys/sys/sys1.c
@@ -21,0 +22 @@
+void
@@ -27,0 +29 @@
+void
@@ -30,2 +32,2 @@
-	register nc;
-	register char *cp;
+	register int nc;
+	register char *cp = NULL;
@@ -103,2 +105,2 @@
-	ucp = -nc - NBPW;
-	ap = ucp - na*NBPW - 3*NBPW;
+	ucp = USERSIZE - nc - NBPW;
+	ap = (ucp - na*NBPW - 3*NBPW) & ~7;
@@ -143,0 +146 @@
+int
@@ -145,0 +149 @@
+int	nargc;
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
@@ -275,0 +281 @@
+void
@@ -280 +286 @@
-	register i;
+	register int i;
@@ -286 +292 @@
-		u.u_ar0[*cp++] = 0;
+		u.u_ar0[(int)*cp++] = 0;
@@ -307,0 +314 @@
+void
@@ -324,0 +332 @@
+void
@@ -325,0 +334 @@
+int	rv;
@@ -376,0 +386 @@
+void
@@ -379 +389 @@
-	register f;
+	register int f;
@@ -421,0 +432 @@
+void
@@ -425 +436 @@
-	register a;
+	register int a;
@@ -456 +466,0 @@
-	p1 = u.u_procp;
@@ -458 +468 @@
-		u.u_r.r_val1 = p1->p_pid;
+		u.u_r.r_val1 = 0;
@@ -469,2 +479 @@
-out:
-	u.u_ar0[R7] += NBPW;
+out:	;
@@ -476,0 +486 @@
+void
@@ -482 +492 @@
-	register a, n, d;
+	register int a, n, d;
@@ -497 +506,0 @@
-	n += USIZE+u.u_ssize;
@@ -500,9 +509,3 @@
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
@@ -510,2 +512,0 @@
-	expand(i);
-	return;
@@ -513,7 +514,4 @@
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
@@ -521,2 +519,2 @@
-	while(d--)
-		clearseg(--a);
+	u.u_dsize += d;
+	return;

% usr/sys/sys/sys2.c
@@ -11,0 +12 @@
+void
@@ -19,0 +21 @@
+void
@@ -29,0 +32 @@
+void
@@ -31 +34 @@
-register mode;
+register int mode;
@@ -79,0 +83 @@
+void
@@ -97,0 +102 @@
+void
@@ -123,0 +129 @@
+void
@@ -126 +132,2 @@
-register mode;
+register int mode;
+int	trf;
@@ -162,0 +170 @@
+void
@@ -180,0 +189 @@
+void
@@ -208,0 +218 @@
+void
@@ -258,0 +269 @@
+void
@@ -289,0 +301 @@
+void
@@ -292 +304 @@
-	register svuid, svgid;
+	register int svuid, svgid;

% usr/sys/sys/sys3.c
@@ -17,0 +18 @@
+void
@@ -35,0 +37 @@
+void
@@ -55,0 +58 @@
+void
@@ -93,0 +97 @@
+void
@@ -101 +105 @@
-	register i, m;
+	register int i, m;
@@ -130,0 +135 @@
+void
@@ -196,0 +202 @@
+void
@@ -203 +209 @@
-	register struct a {
+	struct a {

% usr/sys/sys/sys4.c
@@ -16,0 +17 @@
+void
@@ -25,0 +27 @@
+void
@@ -52,0 +55 @@
+void
@@ -63,0 +67 @@
+void
@@ -66 +70 @@
-	register uid;
+	register int uid;
@@ -79,0 +84 @@
+void
@@ -86,0 +92 @@
+void
@@ -89 +95 @@
-	register gid;
+	register int gid;
@@ -101,0 +108 @@
+void
@@ -108,0 +116 @@
+void
@@ -114,0 +123 @@
+void
@@ -120,0 +130 @@
+void
@@ -123 +133 @@
-	register n;
+	register int n;
@@ -144,0 +155 @@
+void
@@ -193,0 +205 @@
+void
@@ -198,0 +211 @@
+void
@@ -204,0 +218 @@
+void
@@ -233,0 +248 @@
+void
@@ -254,0 +270 @@
+void
@@ -272,0 +289 @@
+void
@@ -275 +292 @@
-	register a;
+	register int a;
@@ -291,0 +309 @@
+void
@@ -295 +313 @@
-	register a;
+	register int a;
@@ -326,0 +345 @@
+void
@@ -337,0 +357 @@
+void
@@ -356,0 +377 @@
+void
@@ -360 +381 @@
-	register c;
+	register int c;
@@ -375,0 +397 @@
+void
@@ -385,0 +408 @@
+void
@@ -391 +414 @@
-	register t;
+	register int t;
@@ -402,0 +426 @@
+void

% usr/sys/sys/sysent.c
@@ -2,0 +3,20 @@
+#include "../h/dir.h"
+#include "../h/user.h"
+#include "../h/proc.h"
+#include "../h/reg.h"
+#include "../h/inode.h"
+#include "../h/file.h"
+#include "../h/tty.h"
+#include "../h/seg.h"
+void nullsys(), nosys();
+void rexit(), fork(), read(), write(), open();
+void close(), wait(), creat(), link(), unlink();
+void exec(), exece(), chdir(), gtime(), mknod();
+void chmod(), chown(), sbreak(), stat(), seek();
+void getpid(), smount(), sumount(), setuid(), getuid();
+void stime(), ptrace(), alarm(), fstat(), pause();
+void utime(), saccess(), nice(), ftime(), sync();
+void kill(), dup(), pipe(), times(), profil();
+void setgid(), getgid(), ssig(), sysacct(), syslock();
+void umask(), chroot(), stty(), gtty(), ioctl();
+void sigreturn(), sysphys();
@@ -10,54 +29,0 @@
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
@@ -67,64 +33,64 @@
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
@@ -131,0 +98,54 @@
+char	regloc[9] = { R0, R1, R2, R3, R4, R5, R6, R7, RPS };
+void
+trap(int *r)
+{
+	register int i;
+	register struct sysent *callp;
+	u.u_fpsaved = 0;
+	u.u_ar0 = r;
+	u.u_error = 0;
+	callp = &sysent[r[7] & 077];
+	for(i = 0; i < callp->sy_narg && i < 6; i++)
+		u.u_arg[i] = r[i];
+	u.u_dirp = (caddr_t)u.u_arg[0];
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
+	if (issig())
+		psig();
+	curpri = setpri(u.u_procp);
+	if (runrun)
+		qswtch();
+}
+void
+user_trap_handler(int signo, int *r)
+{
+	int mode = r[RPS] & 0x1f;
+	if(mode != 0x10 && mode != 0x1f) {
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
+void nosys()   { u.u_error = EINVAL; }
+void nullsys() { }

% usr/sys/sys/text.c
@@ -21,0 +22 @@
+void
@@ -23,0 +25 @@
+int	ff, os;
@@ -25 +27 @@
-	register a;
+	register int a;
@@ -49,0 +52 @@
+void
@@ -83,0 +87 @@
+void
@@ -146,0 +151 @@
+void
@@ -170,0 +176 @@
+void
@@ -181,0 +188 @@
+void
@@ -194,0 +202 @@
+void
@@ -215,0 +224 @@
+void
@@ -217 +226 @@
-register dev;
+register int dev;
@@ -228,0 +238 @@
+void
@@ -234 +244 @@
-	if (ip->i_flag&ITEXT==0)
+	if ((ip->i_flag&ITEXT)==0)
@@ -244,0 +255 @@
+void

% usr/sys/sys/ureg.c
@@ -14,0 +15 @@
+void
@@ -17,2 +18,3 @@
-	register *udp, *uap, *rdp;
-	int *rap, *limudp;
+	register int *udp, *uap, *rap;
+	int auisa[16];
+	int *limudp;
@@ -28,2 +30 @@
-	rap = (int *)UISA;
-	rdp = (int *)UISD;
+	rap = &auisa[0];
@@ -33 +34 @@
-		*rdp++ = *udp++;
+		udp++;
@@ -34,0 +36 @@
+	arm_sureg();
@@ -47,0 +50 @@
+int
@@ -49,0 +53 @@
+int	sep, xrw;
@@ -51 +55 @@
-	register a, *ap, *dp;
+	(void)sep; (void)xrw;
@@ -53,9 +57 @@
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
@@ -63,70 +58,0 @@
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
