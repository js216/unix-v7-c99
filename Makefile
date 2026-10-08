# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

CROSS_COMPILE ?= arm-none-eabi-
CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
HOSTCC = arm-linux-gnueabihf-gcc

CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon -fno-builtin \
	-ffreestanding -nostdlib -mcpu=cortex-a7 -marm -Wl,-N,-Ttext=0x10

LIBC = usr/src/libc/libc.a
CRT = usr/src/libc/crt0.o usr/src/libc/crt0c.o

HOSTCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -static \
	-D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32

all: boot/unix boot/rootfs.img

# Kernels: like v7, conf/makefile recompiles all of sys and dev (about 2 s)
# and builds one kernel per configuration file, mkconf making each c.c.

KERNELS = usr/sys/conf/qemuunix usr/sys/conf/mp135unix

$(KERNELS) &: usr/sys/conf/mkconf usr/sys/conf/qemuconf usr/sys/conf/mp135conf \
	    $(filter-out usr/sys/conf/c.c,$(wildcard usr/sys/*/*.[chs])) \
	    usr/sys/sys/mklib usr/sys/dev/mklib usr/sys/conf/makefile Makefile
	$(MAKE) -C usr/sys/conf all allsystems CC="$(CC)" AS="$(AS)" \
	    CFLAGS="$(CFLAGS)" ASFLAGS=-mcpu=cortex-a7

usr/sys/conf/mkconf: usr/sys/conf/mkconf.c
	$(HOSTCC) $(HOSTCFLAGS) -o $@ $<

boot/unix: usr/sys/conf/qemuunix | boot
	cp $< $@

qemu: boot/unix boot/rootfs.img
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic \
	    -kernel boot/unix -drive if=none,file=boot/rootfs.img,format=raw,id=hd0 \
	    -device virtio-blk-device,drive=hd0

# Libc

$(LIBC) $(CRT): Makefile $(wildcard usr/src/libc/*.[cs] usr/src/libc/*/*.[cs] \
	    usr/include/*.h usr/include/sys/*.h) usr/src/libc/compall usr/src/libc/mklib
	cd usr/src/libc && rm -f *.o libc.a && \
	    CC="$(CC)" CFLAGS="$(CFLAGS) -I../../include -I../.." sh -e compall && \
	    sh -e mklib && rm *.o && \
	    $(CC) $(CFLAGS) -c csu/crt0.s && \
	    $(CC) $(CFLAGS) -I../../include -c csu/crt0.c -o crt0c.o

# Commands: cmake builds one and installs it where v7 did.

CMAKE = cd usr/src/cmd && ROOT=../../.. YACC="bison -y" LIBS="-L../libc -lc -lgcc" \
	CC="$(CC) $(CFLAGS) -I../../include -I.. ../libc/crt0.o ../libc/crt0c.o" \
	sh cmake -cp

ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup \
	etc/passwd etc/group etc/ttys \
	usr/dict/words usr/games/lib/fortunes usr/lib/units usr/lib/crontab \
	usr/lib/lib.b

ROOT_BUILT = etc/init etc/getty bin/login bin/sh bin/cat bin/echo bin/ls \
	bin/pwd bin/sync bin/arcv bin/rev bin/yes bin/wc bin/basename \
	bin/sum bin/tty bin/cmp bin/comm bin/cal bin/od bin/tail \
	bin/grep bin/test bin/look bin/cp bin/rm bin/ln bin/mkdir \
	bin/rmdir bin/mv bin/chmod bin/chown bin/chgrp bin/sleep bin/tee \
	bin/touch bin/tr bin/uniq bin/du bin/date bin/kill bin/nice \
	etc/mknod bin/who bin/mesg bin/time bin/split bin/checkeq \
	usr/lib/calendar bin/tsort bin/file bin/join bin/col bin/fgrep \
	bin/egrep bin/su bin/newgrp bin/random bin/crypt bin/pr bin/dd \
	bin/stty bin/tabs bin/diff etc/wall bin/write bin/df bin/clri \
	bin/dcheck bin/icheck bin/ncheck bin/cb bin/sp bin/find bin/sort \
	bin/ed bin/deroff bin/1 bin/sed bin/awk bin/true bin/false \
	bin/nohup etc/mount etc/umount usr/lib/makekey usr/lib/diffh \
	etc/accton etc/update usr/lib/atrun bin/ac etc/cron bin/passwd \
	usr/lib/diff3 bin/at bin/units bin/ptx bin/spline bin/vpr \
	bin/quot bin/dump bin/dumpdir bin/restor bin/tk bin/dc bin/tar \
	bin/tp bin/prof bin/tc bin/graph bin/factor bin/primes bin/expr \
	bin/iostat bin/pstat bin/ps etc/dmesg bin/osh bin/sa bin/bc \
	usr/games/fortune usr/games/arithmetic usr/games/hangman \
	usr/games/backgammon usr/games/fish usr/games/quiz \
	usr/games/wump

ROOT = $(ROOT_BUILT) \
	$(ROOTFS_STATIC)

DIRS = boot bin etc usr/lib usr/dict usr/games usr/games/lib

bin/%: usr/src/cmd/%.c $(LIBC) $(CRT) Makefile | $(DIRS)
	$(CMAKE) $(<F)
	test $@ -nt $<

etc/%: usr/src/cmd/%.c $(LIBC) $(CRT) Makefile | $(DIRS)
	$(CMAKE) $(<F)
	test $@ -nt $<

usr/lib/%: usr/src/cmd/%.c $(LIBC) $(CRT) Makefile | $(DIRS)
	$(CMAKE) $(<F)
	test $@ -nt $<

bin/%: usr/src/cmd/%.y $(LIBC) $(CRT) Makefile | $(DIRS)
	$(CMAKE) $(<F)
	test $@ -nt $<

usr/games/%: usr/src/games/%.c $(LIBC) $(CRT) Makefile | $(DIRS)
	$(CC) $(CFLAGS) -Iusr/include -Iusr/src -s -o $@ \
	    $(CRT) $< -Lusr/src/libc -lc -lgcc

SUBDIR_BINS = bin/sed bin/sh bin/dc bin/tar bin/tp bin/awk
SUBDIR_CFLAGS_EXTRA =
SUBDIR_LDLIBS = -L../../libc -lc -lgcc

bin/awk: SUBDIR_CFLAGS_EXTRA = -DYYSTACK_USE_ALLOCA=1 -Dmalloc=malloc -Dfree=free -I.
bin/awk: SUBDIR_LDLIBS = -L../../libc -lm -lc -lgcc

$(SUBDIR_BINS): bin/%: force $(LIBC) $(CRT) Makefile | bin
	cd usr/src/cmd/$* && { test $* -nt ../../../Makefile || rm -f *.o; } && \
	    { test $* -nt ../../libc/libc.a || rm -f $*; }
	$(MAKE) -C usr/src/cmd/$* CC="$(CC)" \
	    CFLAGS="$(CFLAGS) -I../../../include -I../.. $(SUBDIR_CFLAGS_EXTRA)" \
	    LDFLAGS=-s CRT="../../libc/crt0.o ../../libc/crt0c.o" \
	    LDLIBS="$(SUBDIR_LDLIBS)"
	cmp -s usr/src/cmd/$*/$* $@ || cp usr/src/cmd/$*/$* $@

# Rootfs

boot/rootfs.img: boot/unix etc/mkfs boot/rootfs.proto $(ROOT)
	trap 'rm -f boot/rootfs.img.tmp' EXIT; \
	    V7_MKFS_TIME=0 etc/mkfs boot/rootfs.img.tmp boot/rootfs.proto; \
	    size=$$(awk '/^(swplo|nswap) /{n+=$$2} END{print n}' usr/sys/conf/qemuconf); \
	    truncate -s "$$((size * 512))" boot/rootfs.img.tmp; \
	    mv boot/rootfs.img.tmp boot/rootfs.img

etc/mkfs: usr/src/cmd/mkfs.c | etc
	tmpinc="$(CURDIR)/boot/mkfs-include.$$$$"; \
	    trap 'rm -rf "$$tmpinc"' EXIT; \
	    mkdir -p "$$tmpinc"; \
	    ln -s "$(CURDIR)/usr/include/sys" "$$tmpinc/sys"; \
	    $(HOSTCC) $(HOSTCFLAGS) -I"$$tmpinc" -o $@ $<

.PHONY: all clean force qemu
.PRECIOUS: $(ROOT)

force:

$(DIRS):
	mkdir -p $@

$(filter-out etc/%,$(ROOTFS_STATIC)): %: usr/local/test/v7/% | $(DIRS)
	cp $< $@

$(filter etc/%,$(ROOTFS_STATIC)): ;

clean:
	rm -f usr/sys/conf/*.o usr/sys/conf/c.c usr/sys/conf/unix.ld usr/sys/conf/mkconf
	rm -f $(KERNELS) usr/sys/sys/LIB1 usr/sys/dev/LIB2
	rm -f boot/unix boot/rootfs.img boot/rootfs.img.tmp
	rm -f etc/mkfs usr/src/libc/*.o $(LIBC)
	for d in sed sh dc tar tp; do rm -f usr/src/cmd/$$d/$$d usr/src/cmd/$$d/*.o; done
	$(MAKE) -C usr/src/cmd/awk clean
