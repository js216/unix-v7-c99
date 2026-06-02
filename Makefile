# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

KCC = arm-none-eabi-gcc
KAS = arm-none-eabi-as
USERCC = arm-none-eabi-gcc
USERAR = arm-none-eabi-ar
USEROBJCOPY = arm-none-eabi-objcopy
HOSTCC = arm-linux-gnueabihf-gcc

BOARD ?= qemu
KFEATURES ?= -DQEMU -DPL011 -DVIRTIO
KLDSCRIPT ?= usr/sys/conf/arm_qemu.ld

CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon \
	-fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm
KCPPFLAGS = -Iusr/sys/conf/$(BOARD) $(KFEATURES)
KLDFLAGS = -nostdlib -T $(KLDSCRIPT) -Wl,-z,max-page-size=0x200

USERCPPFLAGS = -Iusr/include -Iusr/src
YACCCPPFLAGS = $(USERCPPFLAGS) -DYYSTACK_USE_ALLOCA=1
USERLDFLAGS = -nostdlib -T usr/src/libc/u.ld -Wl,-z,max-page-size=0x10
USERLDLIBS = -Lusr/src/libc -lc -lgcc
USERCRT = usr/src/libc/crt0.o usr/src/libc/crt0c.o

LIBC_CPPFLAGS = -I../../include -I../..

MKFS_CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -static \
	-D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32

CMDOBJ = usr/src/libc/cmd-$(@F).o
CMDELF = usr/src/libc/$(@F).elf
SUBDIR_CPPFLAGS = -I../../../include -I../..
SUBDIR_LDFLAGS = -nostdlib -T ../../libc/u.ld -Wl,-z,max-page-size=0x10
SUBDIR_CRT = ../../libc/crt0.o ../../libc/crt0c.o
SUBDIR_LDLIBS = -L../../libc -lc -lgcc
SUBDIR_CFLAGS_EXTRA =

define BUILD_USER_C
	$(USERCC) $(CFLAGS) $(USERCPPFLAGS) -c $< -o $(CMDOBJ)
	$(USERCC) $(CFLAGS) $(USERCPPFLAGS) $(USERLDFLAGS) -o $(CMDELF) $(USERCRT) $(CMDOBJ) $(USERLDLIBS)
	$(USEROBJCOPY) --strip-all $(CMDELF) $@
endef

all: boot/unix boot/rootfs.img

# Kernel

KCONFOBJS = $(patsubst %.c,%.o,$(wildcard usr/sys/conf/*.c))
KSYSOBJS = $(patsubst %.c,%.o,$(wildcard usr/sys/sys/*.c))
KDEVOBJS = $(patsubst %.c,%.o,$(wildcard usr/sys/dev/*.c))
KOBJS = usr/sys/conf/low.o usr/sys/conf/mch.o \
	$(KCONFOBJS) $(KSYSOBJS) $(KDEVOBJS)

KBOARDSTAMP = boot/.board-$(BOARD)

$(KBOARDSTAMP): | boot
	rm -f boot/.board-*
	touch $@

$(KOBJS): $(KBOARDSTAMP) usr/sys/conf/$(BOARD)/memmap.h

boot/unix: $(KOBJS) | boot
	$(KCC) $(CFLAGS) $(KCPPFLAGS) $(KLDFLAGS) -o $@ $^

qemu: boot/unix boot/rootfs.img
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic \
	    -kernel boot/unix -drive if=none,file=boot/rootfs.img,format=raw,id=hd0 \
	    -device virtio-blk-device,drive=hd0

# Libc

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

libc:
	cd usr/src/libc && rm -f *.o *.a *.elf && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c crt0.s && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c crt0.c -o crt0c.o && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c syscall.s && \
	    for i in $(LIBC_SYS_ASM); do \
	        $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c sys/$$i.s || exit 1; \
	    done && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c sys/exit.s -o exit_sys.o && \
	    for i in $(LIBC_SYS_C); do \
	        $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c sys/$$i.c || exit 1; \
	    done && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c sys/time.c -o time_sys.o && \
	    for i in $(LIBC_GEN_C); do \
	        $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c gen/$$i.c -o $$i.o || exit 1; \
	    done && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c stdio/popen.c -o popen.o && \
	    $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c crypt.c -o v7crypt.o && \
	    for i in $(LIBC_C); do \
	        $(USERCC) $(CFLAGS) $(LIBC_CPPFLAGS) -c $$i.c || exit 1; \
	    done && \
	    objs=; for obj in *.o; do \
	        case "$$obj" in crt0.o|crt0c.o) ;; *) objs="$$objs $$obj" ;; esac; \
	    done; \
	    $(USERAR) rc libc.a $$objs

# Userland

ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup \
	etc/passwd etc/group etc/ttys \
	usr/dict/words usr/games/lib/fortunes usr/lib/units usr/lib/crontab

ROOT_BUILT = etc/init etc/getty bin/login bin/sh \
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
	usr/games/wump

ROOT = $(ROOT_BUILT) \
	$(ROOTFS_STATIC)

SUBDIR_BINS = bin/sed bin/sh bin/dc bin/tar bin/tp bin/awk

bin/awk: SUBDIR_CFLAGS_EXTRA = -DYYSTACK_USE_ALLOCA=1 -Dmalloc=malloc -Dfree=free -I.
bin/awk: SUBDIR_LDLIBS = -L../../libc -lm -lc -lgcc

$(SUBDIR_BINS): bin/%: force-subdir usr/src/cmd/%/makefile libc | bin
	$(MAKE) -C usr/src/cmd/$* CC="$(USERCC)" \
	    CFLAGS="$(CFLAGS) $(SUBDIR_CPPFLAGS) $(SUBDIR_CFLAGS_EXTRA)" \
	    LDFLAGS="$(SUBDIR_LDFLAGS)" CRT="$(SUBDIR_CRT)" LDLIBS="$(SUBDIR_LDLIBS)"
	$(USEROBJCOPY) --strip-all usr/src/cmd/$*/$* $@

# Rootfs

boot/rootfs.img: force-root-image boot/unix etc/mkfs boot/rootfs.proto \
	nullboot .profile $(ROOT_BUILT)
	rm -f bin/bc
	set -e; for i in $(ROOT); do \
		test -e "$$i" || { echo "$$i: missing root payload"; exit 1; }; \
	done
	trap 'rm -f boot/rootfs.img.tmp' EXIT; \
	    V7_MKFS_TIME=0 etc/mkfs boot/rootfs.img.tmp boot/rootfs.proto; \
	    { read _; read fsize _; } < boot/rootfs.proto; \
	    truncate -s "$$((fsize * 512))" boot/rootfs.img.tmp; \
	    mv boot/rootfs.img.tmp boot/rootfs.img

etc/mkfs: usr/src/cmd/mkfs.c | etc
	tmpinc="$(CURDIR)/boot/mkfs-include.$$$$"; \
	    trap 'rm -rf "$$tmpinc"' EXIT; \
	    mkdir -p "$$tmpinc"; \
	    ln -s "$(CURDIR)/usr/include/sys" "$$tmpinc/sys"; \
	    $(HOSTCC) $(MKFS_CFLAGS) -I"$$tmpinc" -o $@ $<

# Generic pattern rules

.PHONY: all clean force-root-image force-subdir libc qemu
.PRECIOUS: $(ROOT)

force-root-image:

force-subdir:

boot bin etc usr/lib usr/dict usr/games usr/games/lib:
	mkdir -p $@

nullboot:
	: > $@

usr/sys/conf/%.o: usr/sys/conf/%.s
	$(KAS) -mcpu=cortex-a7 -o $@ $<

usr/sys/%.o: usr/sys/%.c
	$(KCC) $(CFLAGS) $(KCPPFLAGS) -c $< -o $@

bin/%: usr/src/cmd/%.c libc | bin
	$(BUILD_USER_C)

etc/%: usr/src/cmd/%.c libc | etc
	$(BUILD_USER_C)

usr/lib/%: usr/src/cmd/%.c libc | usr/lib
	$(BUILD_USER_C)

usr/games/%: usr/src/cmd/%.c libc | usr/games
	$(BUILD_USER_C)

bin/egrep bin/expr: bin/%: usr/src/cmd/%.y libc | bin
	set -e; gen="usr/src/libc/$*.c"; trap 'rm -f "$$gen"' EXIT; \
	    (cd usr/src/cmd && bison -y $*.y && mv y.tab.c ../libc/$*.c); \
	    $(USERCC) $(CFLAGS) $(YACCCPPFLAGS) -c "$$gen" -o $(CMDOBJ); \
	    $(USERCC) $(CFLAGS) $(YACCCPPFLAGS) $(USERLDFLAGS) -o $(CMDELF) $(USERCRT) $(CMDOBJ) $(USERLDLIBS); \
	    $(USEROBJCOPY) --strip-all $(CMDELF) $@

clean:
	rm -f $(KOBJS) boot/unix boot/rootfs.img boot/rootfs.img.tmp
	rm -f nullboot etc/mkfs
	rm -f usr/src/libc/*.o usr/src/libc/*.a usr/src/libc/*.elf
	rm -f usr/src/cmd/sed/sed usr/src/cmd/sed/*.o
	rm -f usr/src/cmd/sh/sh usr/src/cmd/sh/*.o
	rm -f usr/src/cmd/dc/dc usr/src/cmd/dc/*.o
	rm -f usr/src/cmd/tar/tar usr/src/cmd/tar/*.o
	rm -f usr/src/cmd/tp/tp usr/src/cmd/tp/*.o
	$(MAKE) -C usr/src/cmd/awk clean
