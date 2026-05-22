# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

CONF ?= arm_qemu

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
	bin/expr bin/iostat \
	bin/spell bin/deroff bin/printf bin/chroot bin/mktemp bin/link bin/unlink \
	usr/games/fortune usr/games/arithmetic usr/games/hangman \
	usr/games/backgammon usr/games/fish usr/games/quiz \
	usr/games/wump \
	usr/lib/spell usr/lib/spellin usr/lib/spellout \
	usr/games/lib/fortunes \
	etc/passwd etc/group etc/ttys usr/dict/words usr/lib/units \
	usr/lib/crontab \
	usr/dict/hlista usr/dict/hlistb usr/dict/hstop \
	usr/dict/spellhist \
	etc/auxfs

all:	unix root.img

unix: usr/sys/sys/*.c usr/sys/arch/*.c usr/sys/arch/*.s usr/sys/arch/*.ld usr/sys/dev/*.c usr/sys/h/*.h usr/sys/conf/makefile usr/sys/conf/mkconf.c usr/sys/conf/$(CONF)
	$(MAKE) -C usr/sys/conf unix

qemu:	unix root.img
	$(MAKE) -C usr/sys/conf qemu

root.img: unix Makefile usr/src/tools/mkfs usr/sys/conf/root.proto usr/src/cmd/*.c usr/src/cmd/sh/* usr/src/cmd/sed/* usr/src/cmd/awk/* usr/src/cmd/dc/* usr/src/cmd/tar/* usr/src/cmd/tp/* v7/bin/1 v7/bin/true v7/bin/false v7/bin/nohup v7/bin/spell usr/src/libc/*.c usr/src/libc/*.s usr/src/libc/sys/* usr/src/libc/gen/* usr/src/libc/stdio/* usr/src/libc/Makefile usr/src/libc/u.ld bin/spell etc/passwd etc/rc etc/ttys usr/dict/words usr/dict/hlista usr/dict/hlistb usr/dict/hstop usr/dict/spellhist usr/games/lib/fortunes usr/lib/units usr/lib/crontab etc/auxfs
	$(MAKE) -C usr/src/libc
	usr/src/tools/mkfs root.img usr/sys/conf/root.proto
	# v7 mkfs only writes the blocks it touches.  Pad root.img to its
	# declared filesystem size (FSIZE * BSIZE = 16384 * 512) so qemu's
	# virtio block backend can serve any sector the kernel asks for.
	truncate -s 8388608 root.img

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
	arm-linux-gnueabihf-gcc -std=c99 -Wall -Wextra -Wpedantic -Werror -static \
	    -D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32 \
	    -o usr/src/tools/mkfs usr/src/tools/mkfs.c

# A pocket-sized fs image holding just /a=etc/passwd, mounted as
# /etc/auxfs by the icheck/dcheck/ncheck mission step.
etc/auxfs: usr/src/tools/mkfs usr/sys/conf/auxfs.proto etc/passwd
	mkdir -p etc
	usr/src/tools/mkfs etc/auxfs usr/sys/conf/auxfs.proto
	truncate -s 32768 etc/auxfs

usr/dict/words: v7/usr/dict/words
	mkdir -p usr/dict
	rm -f usr/dict/words
	cp v7/usr/dict/words usr/dict/words

usr/dict/hlista: v7/usr/dict/hlista
	mkdir -p usr/dict
	rm -f usr/dict/hlista
	cp v7/usr/dict/hlista usr/dict/hlista

usr/dict/hlistb: v7/usr/dict/hlistb
	mkdir -p usr/dict
	rm -f usr/dict/hlistb
	cp v7/usr/dict/hlistb usr/dict/hlistb

usr/dict/hstop: v7/usr/dict/hstop
	mkdir -p usr/dict
	rm -f usr/dict/hstop
	cp v7/usr/dict/hstop usr/dict/hstop

usr/dict/spellhist: v7/usr/dict/spellhist
	mkdir -p usr/dict
	rm -f usr/dict/spellhist
	cp v7/usr/dict/spellhist usr/dict/spellhist

bin/spell: v7/bin/spell
	mkdir -p bin
	cp v7/bin/spell bin/spell
	chmod 755 bin/spell

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
	$(MAKE) -C usr/sys/conf clean
	$(MAKE) -C usr/src/libc clean
	rm -f unix root.img usr/src/tools/mkfs
