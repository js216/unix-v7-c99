# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

ROOT = etc/init etc/getty bin/login bin/sh \
	bin/cat bin/echo bin/ls bin/pwd bin/sync \
	bin/arcv bin/rev bin/yes bin/wc bin/basename bin/sum \
	bin/tty bin/cmp bin/comm bin/cal bin/od \
	bin/tail bin/grep bin/test bin/look bin/cp \
	bin/rm bin/ln bin/mkdir bin/rmdir bin/mv \
	bin/chmod bin/chown bin/chgrp bin/sleep \
	bin/tee bin/touch bin/tr bin/uniq bin/du \
	bin/date bin/kill bin/nice bin/mknod bin/who \
	bin/mesg bin/time bin/split bin/checkeq \
	bin/calendar bin/tsort bin/file bin/join bin/col \
	bin/fgrep bin/egrep bin/su bin/newgrp bin/random bin/crypt \
	bin/pr bin/dd bin/stty bin/tabs bin/diff \
	bin/wall bin/write bin/df bin/clri \
	bin/dcheck bin/icheck bin/ncheck \
	bin/cb bin/sp bin/find bin/sort bin/ed \
	bin/deroff \
	bin/1 bin/sed bin/awk bin/true bin/false \
	bin/nohup \
	bin/mount bin/umount \
	usr/lib/makekey usr/lib/diffh \
	etc/accton etc/update etc/atrun bin/ac etc/cron \
	bin/passwd bin/diff3 \
	bin/at bin/units bin/ptx bin/spline bin/vpr \
	bin/quot bin/dump bin/dumpdir \
	bin/restor bin/tk bin/dc bin/tar bin/tp \
	bin/prof bin/tc bin/graph bin/factor bin/primes \
	bin/expr bin/iostat bin/pstat \
	usr/games/fortune usr/games/arithmetic usr/games/hangman \
	usr/games/backgammon usr/games/fish usr/games/quiz \
	usr/games/wump \
	usr/games/lib/fortunes \
	etc/passwd etc/group etc/ttys usr/dict/words usr/lib/units \
	usr/lib/crontab

all:	boot/unix boot/rootfs.img

KCC = arm-none-eabi-gcc
KAS = arm-none-eabi-as

# Target board: qemu (QEMU virt, default) or mp135 (custom STM32MP135 PCB).
# The V7 kernel and the shared low.s/conf.c are identical across boards (no
# conditional compilation); only the linker script and the machine-layer
# driver set differ.  conf.c references the board-independent console (cn*)
# and block (bd*) symbols; each board links exactly one driver providing them.
BOARD ?= qemu
ifeq ($(BOARD),mp135)
KLDSCRIPT = usr/sys/conf/sysram.ld
KBOARDOBJS = usr/sys/conf/mp135.o usr/sys/dev/stm32usart.o usr/sys/dev/stm32sd.o
else
KLDSCRIPT = usr/sys/conf/arm_qemu.ld
KBOARDOBJS = usr/sys/conf/qemu.o usr/sys/dev/pl011.o usr/sys/dev/virtio_blk.o
endif

KCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin \
	-fcommon -mcpu=cortex-a7 -marm -ffreestanding -Wno-clobbered -DKERNEL \
	-Iusr/sys/conf/$(BOARD)
KLDFLAGS = -nostdlib -T $(KLDSCRIPT) -Wl,-z,max-page-size=0x200
KV7OBJS = usr/sys/sys/alloc.o usr/sys/sys/subr.o usr/sys/sys/fio.o \
	usr/sys/sys/sys2.o usr/sys/sys/sys3.o usr/sys/sys/sys4.o \
	usr/sys/sys/clock.o usr/sys/sys/acct.o usr/sys/sys/ureg.o \
	usr/sys/sys/text.o usr/sys/sys/rdwri.o usr/sys/sys/sig.o \
	usr/sys/sys/slp.o usr/sys/sys/sys1.o usr/sys/sys/pipe.o \
	usr/sys/sys/sysent.o usr/sys/sys/prim.o
KOBJS = usr/sys/conf/low.o usr/sys/conf/mch.o usr/sys/sys/main.o \
	usr/sys/sys/malloc.o \
	usr/sys/sys/prf.o usr/sys/sys/iget.o usr/sys/sys/nami.o \
	usr/sys/sys/machdep.o $(KV7OBJS) usr/sys/dev/bio.o \
	usr/sys/conf/conf.o usr/sys/dev/mem.o \
	usr/sys/dev/tty.o usr/sys/dev/partab.o usr/sys/dev/sys.o \
	$(KBOARDOBJS)

boot:
	mkdir -p boot

# Every kernel object bakes in board-specific addresses from conf/<board>/
# memmap.h (chosen by the -I path), so the same .c yields different code per
# board.  This stamp's name carries $(BOARD); switching boards selects a name
# that doesn't exist yet, so its recipe runs, becomes newer than every object,
# and forces a rebuild -- no manual `make clean` needed between boards.
KBOARDSTAMP = boot/.board-$(BOARD)
$(KBOARDSTAMP): | boot
	rm -f boot/.board-*
	touch $@
$(KOBJS): $(KBOARDSTAMP) usr/sys/conf/$(BOARD)/memmap.h

boot/unix: $(KOBJS) | boot
	$(KCC) $(KCFLAGS) $(KLDFLAGS) -o $@ $^

usr/sys/conf/low.o: usr/sys/conf/low.s
	$(KAS) -mcpu=cortex-a7 -o $@ $<

usr/sys/conf/mch.o: usr/sys/conf/mch.s
	$(KAS) -mcpu=cortex-a7 -o $@ $<

usr/sys/sys/%.o: usr/sys/sys/%.c
	$(KCC) $(KCFLAGS) -c $< -o $@

usr/sys/dev/%.o: usr/sys/dev/%.c
	$(KCC) $(KCFLAGS) -c $< -o $@

usr/sys/conf/%.o: usr/sys/conf/%.c
	$(KCC) $(KCFLAGS) -c $< -o $@

qemu:	boot/unix boot/rootfs.img
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic \
	    -kernel boot/unix -drive if=none,file=boot/rootfs.img,format=raw,id=hd0 \
	    -device virtio-blk-device,drive=hd0

boot/rootfs.img: force-root-image boot/unix Makefile usr/src/tools/mkfs boot/rootfs.proto nullboot .profile usr/src/cmd/*.c usr/src/cmd/sh/* usr/src/cmd/sed/* usr/src/cmd/awk/* usr/src/cmd/dc/* usr/src/cmd/tar/* usr/src/cmd/tp/* v7/bin/1 v7/bin/true v7/bin/false v7/bin/nohup usr/src/libc/*.c usr/src/libc/*.s usr/src/libc/sys/* usr/src/libc/gen/* usr/src/libc/stdio/* usr/src/libc/u.ld
	$(MAKE) libc
	$(MAKE) userland-extra
	rm -f bin/bc
	set -e; for i in $(ROOT); do \
		test -e "$$i" || { echo "$$i: missing root payload"; exit 1; }; \
	done
	# v7 mkfs only writes the blocks it touches.  Pad rootfs.img to the
	# filesystem size declared in boot/rootfs.proto so qemu's virtio block
	# backend can serve any sector the kernel asks for.
	trap 'rm -f boot/rootfs.img.tmp' EXIT; \
	    V7_MKFS_TIME=0 usr/src/tools/mkfs boot/rootfs.img.tmp boot/rootfs.proto; \
	    fsize=$$(awk 'NR==2 {print $$1}' boot/rootfs.proto); \
	    truncate -s "$$((fsize * 512))" boot/rootfs.img.tmp; \
	    mv boot/rootfs.img.tmp boot/rootfs.img
	$(MAKE) userland-clean

USERCC = arm-none-eabi-gcc
USERAR = arm-none-eabi-ar
USEROBJCOPY = arm-none-eabi-objcopy
USERCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -Iusr/include -Iusr/src
USERAWKCFLAGS = $(USERCFLAGS) -Os -fno-asynchronous-unwind-tables -fno-unwind-tables -Dmalloc=malloc -Dfree=free -Iusr/src/cmd/awk -Wno-int-conversion -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast -Wno-implicit-function-declaration -Wno-builtin-declaration-mismatch -Wno-implicit-int -Wno-return-type -Wno-unused-function -Wno-discarded-qualifiers
USERYACCCFLAGS = $(USERCFLAGS) -DYYSTACK_USE_ALLOCA=1 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-return-type -Wno-return-mismatch -Wno-int-conversion -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast -Wno-char-subscripts -Wno-implicit-fallthrough -Wno-type-limits -Wno-unused-parameter
USERLDFLAGS = -nostdlib -T usr/src/libc/u.ld -Wl,-z,max-page-size=0x10
USERLDLIBS = -Lusr/src/libc -lc -lgcc
USERCRT = usr/src/libc/crt0.o usr/src/libc/crt0c.o
LIBC_CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon \
	-fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm \
	-I../../include -I../..
LIBC_SYS_ASM = access acct chdir chmod chown chroot close creat fork fstat \
	getgid getpid getuid ioctl kill link lock lseek mknod mount nice pipe \
	profil ptrace read setgid setuid signal stat sync times umask umount \
	unlink utime wait write
LIBC_SYS_C = alarm brk dup execv execl execve ftime gtty open pause stime \
	stty
LIBC_GEN_C = abort exit sleep
LIBC_STDIO_C = popen
LIBC_C = l3 getpwent getpwnam getpwuid strncat ttyslot execvp getenv atoi \
	atol atof index rindex isatty perror strcat strcmp strcpy strlen \
	strncmp strncpy swab rand mktemp errlst ttyname mkdir qsort calloc \
	tell timezone getlogin data ctype_ fopen freopen findiop endopen \
	filbuf flsbuf fgetc fputc fgets fputs gets puts rdwr fseek ftell \
	rew setbuf ungetc clrerr getchar putchar strout doprnt printf \
	fprintf sprintf doscan scanf malloc getpass ctime system memcpy nlist \
	math_helpers ecvt fdopen gcvt getgrent getgrgid getgrnam getw putw
AWKGEN = usr/src/cmd/awk/awk.g.c usr/src/cmd/awk/awk.h \
	usr/src/cmd/awk/awk.lx.c usr/src/cmd/awk/awk.lx.tmp.l \
	usr/src/cmd/awk/proc usr/src/cmd/awk/proc-token.o \
	usr/src/cmd/awk/proctab.c

.PHONY: force-root-image libc userland-extra userland-clean
force-root-image:

nullboot:
	: > nullboot

libc:
	cd usr/src/libc && rm -f *.o *.a *.elf && \
	    $(USERCC) $(LIBC_CFLAGS) -c crt0.s && \
	    $(USERCC) $(LIBC_CFLAGS) -c crt0.c -o crt0c.o && \
	    $(USERCC) $(LIBC_CFLAGS) -c syscall.s && \
	    for i in $(LIBC_SYS_ASM); do \
	        $(USERCC) $(LIBC_CFLAGS) -c sys/$$i.s || exit 1; \
	    done && \
	    $(USERCC) $(LIBC_CFLAGS) -c sys/exit.s -o exit_sys.o && \
	    for i in $(LIBC_SYS_C); do \
	        $(USERCC) $(LIBC_CFLAGS) -c sys/$$i.c || exit 1; \
	    done && \
	    $(USERCC) $(LIBC_CFLAGS) -c sys/time.c -o time_sys.o && \
	    for i in $(LIBC_GEN_C); do \
	        $(USERCC) $(LIBC_CFLAGS) -c gen/$$i.c -o $$i.o || exit 1; \
	    done && \
	    $(USERCC) $(LIBC_CFLAGS) -c stdio/popen.c -o popen.o && \
	    $(USERCC) $(LIBC_CFLAGS) -c crypt.c -o v7crypt.o && \
	    for i in $(LIBC_C); do \
	        $(USERCC) $(LIBC_CFLAGS) -c $$i.c || exit 1; \
	    done && \
	    objs=`ls *.o | grep -v '^crt0.o$$' | grep -v '^crt0c.o$$'`; \
	    $(USERAR) rc libc.a $$objs

userland-extra:
	mkdir -p bin usr/lib
	set -e; for i in echo date at ls pwd tabs diff diff3 wall write df clri dcheck icheck ncheck cb sp find sort grep passwd iostat ps pstat quot calendar dmesg ed factor primes umount deroff osh; do \
		cflags="$(USERCFLAGS)"; \
		if test "$$i" = grep; then cflags="$$cflags -Wno-char-subscripts"; fi; \
		$(USERCC) $$cflags -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) --strip-all usr/src/libc/$$i.elf bin/$$i; \
	done
	set -e; for i in ac arcv basename cal cat checkeq chgrp chmod chown cmp \
	    col comm cp crypt dd du dump dumpdir fgrep file graph join kill ln \
	    look mesg mkdir mknod mount mv newgrp nice od pr prof ptx random \
	    restor rev rmdir sa sleep spline split su sum sync tail tc tee test \
	    time tk touch tr tsort tty uniq units vpr wc who yes; do \
		cflags="$(USERCFLAGS)"; \
		case $$i in \
		cmp|file|graph|uniq|ptx) cflags="$$cflags -Wno-char-subscripts";; \
		tk|units) cflags="$$cflags -Wno-misleading-indentation";; \
		tee) cflags="$$cflags -Wno-implicit-function-declaration";; \
		esac; \
		$(USERCC) $$cflags -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) --strip-all usr/src/libc/$$i.elf bin/$$i; \
	done
	cp v7/bin/1 bin/1; cp v7/bin/true bin/true
	cp v7/bin/false bin/false; cp v7/bin/nohup bin/nohup
	set -e; for i in init login; do \
		$(USERCC) $(USERCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
	done
	$(USEROBJCOPY) --strip-all usr/src/libc/init.elf etc/init
	$(USEROBJCOPY) --strip-all usr/src/libc/login.elf bin/login
	$(USERCC) $(USERCFLAGS) -Wno-missing-braces -c usr/src/cmd/getty.c -o usr/src/libc/cmd-getty.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/getty.elf $(USERCRT) usr/src/libc/cmd-getty.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/getty.elf etc/getty
	set -e; for i in accton update atrun cron; do \
		$(USERCC) $(USERCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) --strip-all usr/src/libc/$$i.elf etc/$$i; \
	done
	set -e; for i in makekey diffh; do \
		$(USERCC) $(USERCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) --strip-all usr/src/libc/$$i.elf usr/lib/$$i; \
	done
	$(USERCC) $(USERCFLAGS) -Wno-dangling-else -c usr/src/cmd/rm.c -o usr/src/libc/cmd-rm.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/rm.elf $(USERCRT) usr/src/libc/cmd-rm.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/rm.elf bin/rm
	$(USERCC) $(USERCFLAGS) -Wno-missing-braces -c usr/src/cmd/stty.c -o usr/src/libc/cmd-stty.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/stty.elf $(USERCRT) usr/src/libc/cmd-stty.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/stty.elf bin/stty
	set -e; trap 'rm -f usr/src/cmd/egrep.c usr/src/cmd/expr.c' EXIT; \
	for i in egrep expr; do \
		(cd usr/src/cmd && bison -y $$i.y && mv y.tab.c $$i.c); \
		$(USERCC) $(USERYACCCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERYACCCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) --strip-all usr/src/libc/$$i.elf bin/$$i; \
	done
	set -e; for i in sed0 sed1; do \
		$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/sed -c usr/src/cmd/sed/$$i.c -o usr/src/libc/$$i.o; \
	done
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/sed.elf $(USERCRT) usr/src/libc/sed0.o usr/src/libc/sed1.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/sed.elf bin/sed
	set -e; for i in args blok builtin cmd ctype error expand fault io macro main msg name print service setbrk stak string word xec; do \
		$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/sh -c usr/src/cmd/sh/$$i.c -o usr/src/libc/sh-$$i.o; \
	done
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/sh.elf $(USERCRT) usr/src/libc/sh-*.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/sh.elf bin/sh
	$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/dc -c usr/src/cmd/dc/dc.c -o usr/src/libc/dc.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/dc.elf $(USERCRT) usr/src/libc/dc.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/dc.elf bin/dc
	$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/tar -c usr/src/cmd/tar/tar.c -o usr/src/libc/tar.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/tar.elf $(USERCRT) usr/src/libc/tar.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/tar.elf bin/tar
	set -e; for i in tp0 tp1 tp2 tp3; do \
		$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/tp -c usr/src/cmd/tp/$$i.c -o usr/src/libc/$$i.o; \
	done
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/tp.elf $(USERCRT) usr/src/libc/tp0.o usr/src/libc/tp1.o usr/src/libc/tp2.o usr/src/libc/tp3.o $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all usr/src/libc/tp.elf bin/tp
	set -e; trap 'cd "$(CURDIR)" && rm -f $(AWKGEN)' EXIT; \
	(cd usr/src/cmd/awk && bison -y -d awk.g.y && mv y.tab.c awk.g.c && mv y.tab.h awk.h); \
	(cd usr/src/cmd/awk && awk 'BEGIN { print "%option noyywrap noinput nounistd" } { if ($$0 == "%}") { print "#undef YY_INPUT"; print "#define YY_INPUT(buf,result,max_size) \\"; print "do { \\"; print "	int c = input(); \\"; print "	if (c == 0) result = YY_NULL; \\"; print "	else { buf[0] = c; result = 1; } \\"; print "} while (0)" } print }' awk.lx.l > awk.lx.tmp.l); \
	(cd usr/src/cmd/awk && perl -0pi -e 's/\tif \(yysptr > yysbuf\)\n\t\tc = U\(\*--yysptr\);\n\telse if \(yyin == NULL\)/\tif (lexprog != NULL)/' awk.lx.tmp.l); \
	(cd usr/src/cmd/awk && flex -o awk.lx.c awk.lx.tmp.l); \
	(cd usr/src/cmd/awk && sed -i '/#include <string.h>/d;/#include <stdlib.h>/d' awk.lx.c); \
	(cd usr/src/cmd/awk && sed -i '1i #include <stddef.h>' awk.lx.c); \
	(cd usr/src/cmd/awk && perl -0pi -e 's/#define ECHO [^\n]+/#define ECHO do { } while (0)/' awk.lx.c); \
	(cd usr/src/cmd/awk && perl -0pi -e 's/int\tlineno\t1;/int\tlineno = 1;/' awk.lx.c); \
	(cd usr/src/cmd/awk && perl -0pi -e 's/yybgin-yysvec-1/YY_START/g' awk.lx.c); \
	(cd usr/src/cmd/awk && cc -std=gnu89 -w -c token.c -o proc-token.o && cc -std=gnu89 -w -o proc proc.c proc-token.o && ./proc > proctab.c); \
	for i in awk.g awk.lx b main token tran lib run parse proctab; do \
		$(USERCC) $(USERAWKCFLAGS) -c usr/src/cmd/awk/$$i.c -o usr/src/libc/awk-$$i.o; \
	done; \
	$(USERCC) $(USERAWKCFLAGS) $(USERLDFLAGS) -o usr/src/libc/awk.elf $(USERCRT) usr/src/libc/awk-awk.g.o usr/src/libc/awk-awk.lx.o usr/src/libc/awk-b.o usr/src/libc/awk-main.o usr/src/libc/awk-token.o usr/src/libc/awk-tran.o usr/src/libc/awk-lib.o usr/src/libc/awk-run.o usr/src/libc/awk-parse.o usr/src/libc/awk-proctab.o -Lusr/src/libc -lm -lc -lgcc; \
	$(USEROBJCOPY) --strip-all usr/src/libc/awk.elf bin/awk

userland-clean:
	rm -f usr/src/libc/*.o usr/src/libc/*.a usr/src/libc/*.elf $(AWKGEN)

# mkfs is a v7 K&R program built as a Linux/ARM ELF (armhf glibc) so it
# can run on the host via binfmt_misc.  Building for the same word width
# as the target kernel (32-bit) avoids the daddr_t/long width hacks the
# x86_64 host build needed.  -std=c89 accepts K&R-style definitions;
# -fms-extensions allows the v7 `union { struct filsys; ... }` form so
# `filsys.s_isize` resolves through the inner struct, matching K&R
# lookup.  -D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32 keep glibc's off_t and
# time_t at 4 bytes so the project's <sys/param.h> typedefs do not
# conflict.  mkfs keeps a tiny local ltol3() because v7's lib/l3.c
# assumes PDP-11 middle-endian long byte layout, which discards the
# second byte on a straight little-endian Armv7 long.
usr/src/tools/mkfs: usr/src/tools/mkfs.c
	tmpinc="$${TMPDIR:-/tmp}/unix-v7-c99-mkfs-include.$$$$"; \
	    trap 'rm -rf "$$tmpinc"' EXIT; \
	    mkdir -p "$$tmpinc"; \
	    ln -s "$(CURDIR)/usr/include/sys" "$$tmpinc/sys"; \
	    arm-linux-gnueabihf-gcc -std=c99 -Wall -Wextra -Wpedantic -Werror -static \
	        -I"$$tmpinc" -D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32 \
	        -o usr/src/tools/mkfs usr/src/tools/mkfs.c

usr/dict/words: v7/usr/dict/words
	mkdir -p usr/dict
	rm -f usr/dict/words
	cp v7/usr/dict/words usr/dict/words

usr/games/lib/fortunes: v7/usr/games/lib/fortunes
	mkdir -p usr/games/lib
	cp v7/usr/games/lib/fortunes usr/games/lib/fortunes

usr/lib/units: v7/usr/lib/units
	mkdir -p usr/lib
	cp v7/usr/lib/units usr/lib/units

usr/lib/crontab: v7/usr/lib/crontab
	mkdir -p usr/lib
	cp v7/usr/lib/crontab usr/lib/crontab


clean:
	rm -f $(KOBJS) boot/unix boot/rootfs.img boot/rootfs.img.tmp
	rm -f nullboot usr/src/tools/mkfs $(AWKGEN)
	rm -f usr/src/libc/*.o usr/src/libc/*.a usr/src/libc/*.elf
