# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

CONF ?= arm_qemu

ROOT = root/etc/init root/etc/getty root/bin/login root/bin/sh \
	root/bin/cat root/bin/echo root/bin/ls root/bin/pwd root/bin/sync \
	root/bin/arcv root/bin/rev root/bin/yes root/bin/wc root/bin/basename root/bin/sum \
	root/bin/tty root/bin/cmp root/bin/comm root/bin/cal root/bin/od \
	root/bin/tail root/bin/grep root/bin/test root/bin/look root/bin/cp \
	root/bin/rm root/bin/ln root/bin/mkdir root/bin/rmdir root/bin/mv \
	root/bin/chmod root/bin/chown root/bin/chgrp root/bin/sleep \
	root/bin/tee root/bin/touch root/bin/tr root/bin/uniq root/bin/du \
	root/bin/date root/bin/kill root/bin/nice root/bin/mknod root/bin/who \
	root/bin/mesg root/bin/time root/bin/split root/bin/checkeq \
	root/bin/calendar root/bin/tsort root/bin/file root/bin/join root/bin/col \
	root/bin/fgrep root/bin/egrep root/bin/su root/bin/newgrp root/bin/random root/bin/crypt \
	root/bin/pr root/bin/dd root/bin/stty root/bin/tabs root/bin/diff \
	root/bin/wall root/bin/write root/bin/df root/bin/clri \
	root/bin/dcheck root/bin/icheck root/bin/ncheck \
	root/bin/cb root/bin/sp root/bin/find root/bin/sort root/bin/ed \
	root/bin/1 root/bin/sed root/bin/awk root/bin/true root/bin/false \
	root/bin/nohup \
	root/bin/mount root/bin/umount \
	root/usr/lib/makekey root/usr/lib/diffh \
	root/etc/accton root/etc/update root/etc/atrun root/bin/ac root/etc/cron \
	root/bin/passwd root/bin/diff3 \
	root/bin/at root/bin/units root/bin/ptx root/bin/spline root/bin/vpr \
	root/bin/quot root/bin/dump root/bin/dumpdir \
	root/bin/restor root/bin/tk root/bin/dc root/bin/tar root/bin/tp \
	root/bin/prof root/bin/tc root/bin/graph root/bin/factor root/bin/primes \
	root/bin/expr root/bin/iostat \
	root/bin/spell root/bin/deroff root/bin/printf root/bin/chroot root/bin/mktemp root/bin/link root/bin/unlink \
	root/usr/games/fortune root/usr/games/arithmetic root/usr/games/hangman \
	root/usr/games/backgammon root/usr/games/fish root/usr/games/quiz \
	root/usr/games/wump \
	root/usr/lib/spell root/usr/lib/spellin root/usr/lib/spellout \
	root/usr/games/lib/fortunes \
	root/etc/passwd root/etc/group root/etc/ttys root/usr/dict/words root/usr/lib/units \
	root/usr/lib/crontab \
	root/usr/dict/hlista root/usr/dict/hlistb root/usr/dict/hstop \
	root/usr/dict/spellhist \
	build/auxfs.img

all:	unix root.img

unix:	sys/*.c arch/*.c arch/*.s arch/*.ld dev/*.c h/*.h conf/$(CONF)/config.mk conf/$(CONF)/conf.c
	$(MAKE) -C sys unix

# Keep the in-rootfs /unix copy small: the live kernel still loads the
# full ELF directly from qemu's -kernel arg, while dmesg only needs
# the stripped file for nlist() lookup.  Removing loadable sections keeps
# the image compact without changing symbol values used by those tools.
root/unix:	unix
	arm-none-eabi-objcopy -R .text -R .rodata -R .stack -R .ARM.attributes -R .comment unix root/unix

qemu:	unix root.img
	$(MAKE) -C sys qemu

cmd/awk/awk.g.c cmd/awk/awk.h cmd/awk/proctab.c: ;

root.img: unix root/unix Makefile tools/mkfs conf/$(CONF)/root.proto cmd/*.c cmd/sh/* cmd/sed/* cmd/awk/* cmd/dc/* cmd/tar/* cmd/tp/* v7/bin/1 v7/bin/true v7/bin/false v7/bin/nohup v7/bin/spell lib/*.c lib/*.s lib/Makefile lib/u.ld root/bin/spell root/etc/passwd root/etc/rc root/etc/ttys root/usr/dict/words root/usr/dict/hlista root/usr/dict/hlistb root/usr/dict/hstop root/usr/dict/spellhist root/usr/games/lib/fortunes root/usr/lib/units root/usr/lib/crontab tools/extract-old-ar.py build/auxfs.img
	cd lib; make
	mkdir -p build
	tools/mkfs root.img conf/$(CONF)/root.proto
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
tools/mkfs: tools/mkfs.c
	arm-linux-gnueabihf-gcc -std=c99 -Wall -Wextra -Wpedantic -Werror -static \
	    -D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32 \
	    -o tools/mkfs tools/mkfs.c

# A pocket-sized fs image holding just /a=root/etc/passwd, mounted as
# /etc/auxfs by the icheck/dcheck/ncheck mission step.  The static
# auxfs.proto declares a tiny (64 block, 32 inode) volume.
build/auxfs.img: tools/mkfs conf/$(CONF)/auxfs.proto root/etc/passwd
	mkdir -p build
	tools/mkfs build/auxfs.img conf/$(CONF)/auxfs.proto
	truncate -s 32768 build/auxfs.img

root/usr/dict/words: v7/usr/dict/words
	mkdir -p root/usr/dict
	rm -f root/usr/dict/words
	cp v7/usr/dict/words root/usr/dict/words

root/usr/dict/hlista: v7/usr/dict/hlista
	mkdir -p root/usr/dict
	rm -f root/usr/dict/hlista
	cp v7/usr/dict/hlista root/usr/dict/hlista

root/usr/dict/hlistb: v7/usr/dict/hlistb
	mkdir -p root/usr/dict
	rm -f root/usr/dict/hlistb
	cp v7/usr/dict/hlistb root/usr/dict/hlistb

root/usr/dict/hstop: v7/usr/dict/hstop
	mkdir -p root/usr/dict
	rm -f root/usr/dict/hstop
	cp v7/usr/dict/hstop root/usr/dict/hstop

root/usr/dict/spellhist: v7/usr/dict/spellhist
	mkdir -p root/usr/dict
	rm -f root/usr/dict/spellhist
	cp v7/usr/dict/spellhist root/usr/dict/spellhist

root/bin/spell: v7/bin/spell
	mkdir -p root/bin
	cp v7/bin/spell root/bin/spell
	chmod 755 root/bin/spell

root/usr/games/lib/fortunes: v7/usr/games/lib/fortunes
	mkdir -p root/usr/games/lib
	cp v7/usr/games/lib/fortunes root/usr/games/lib/fortunes

root/usr/lib/units: v7/usr/lib/units
	mkdir -p root/usr/lib
	cp v7/usr/lib/units root/usr/lib/units

root/usr/lib/crontab: v7/usr/lib/crontab
	mkdir -p root/usr/lib
	cp v7/usr/lib/crontab root/usr/lib/crontab


clean:
	cd sys; make clean
	cd lib; make clean
	rm -f unix root.img tools/mkfs
	rm -rf build
