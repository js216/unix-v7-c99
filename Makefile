# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

CONF ?= qemu_arm

LEARN_FILE_NAMES = L0 L0.1a L0.1b L0.1c L0.1d L1.1a L1.2a L1.2b \
	L10.1a L10.2a L10.2b L10.3a L10.3b L10.3c L10.3d \
	L11.1a L11.2a L11.2b L11.3a L11.3b L11.3c \
	L12.1a L12.2a L12.2b L12.2c L12.3a L12.3b L12.3c \
	L13.1a L13.1b L13.1c L13.1d L13.1e L13.1f L13.1g \
	L2.1a L2.2a L2.2b L3.1a L3.2a L3.2b L3.3a L3.3b \
	L4.1a L4.2a L4.2b L4.3a L4.3b L4.3c \
	L5.1a L5.1b L5.1c L5.1d L5.1e \
	L6.1a L6.1b L6.1c L6.1d L6.1e L6.2a L6.2b \
	L7.1a L7.2a L7.2b L7.3a L7.3b L7.3c \
	L8.1a L8.2a L8.2b L8.2c L9.1a L9.2a L9.2b L9.2c
LEARN_FILES = $(addprefix root/usr/lib/learn/files/,$(LEARN_FILE_NAMES))
LEARN_MOREFILE_NAMES = L0 L0.1a L0.1b L0.1c L0.1d L0.1e L0.1f L0.1g \
	L1.1a L1.1b L1.1c L1.1d L2.1a L2.1b L2.1c L2.1d L2.1e L2.1f \
	L3.1a L3.1b L3.1c L3.1d L3.1e L3.1f L3.1g \
	L4.1a L4.1b L4.1c L4.1d L4.1e L4.1f L4.1g L4.2a \
	L5.1a L5.1b L5.1c L5.1d L5.1e \
	L6.1a L6.1b L6.1c L6.1d L6.1e L6.2e L7.1a
LEARN_MOREFILES = $(addprefix root/usr/lib/learn/morefiles/,$(LEARN_MOREFILE_NAMES))

ROOT = root/etc/init root/etc/getty root/bin/login root/bin/sh \
	root/bin/cat root/bin/echo root/bin/ls root/bin/pwd root/bin/sync \
	root/bin/arcv root/bin/rev root/bin/yes root/bin/wc root/bin/basename root/bin/dirname root/bin/sum \
	root/bin/tty root/bin/cmp root/bin/comm root/bin/cal root/bin/od \
	root/bin/head root/bin/tail root/bin/grep root/bin/test root/bin/look root/bin/cp \
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
	root/bin/expr root/bin/iostat root/bin/dkstat root/bin/plot root/bin/tek \
	root/bin/spell root/bin/deroff root/bin/printf root/bin/id root/bin/whoami root/bin/seq root/bin/xargs root/bin/paste root/bin/tac root/bin/nl root/bin/expand root/bin/unexpand root/bin/cut root/bin/env root/bin/fmt root/bin/uname root/bin/logname root/bin/which root/bin/hostname root/bin/nproc root/bin/chroot root/bin/mktemp root/bin/getopt root/bin/pgrep root/bin/pkill root/bin/timeout root/bin/watch root/bin/pidof root/bin/cksum root/bin/column root/bin/shuf root/bin/truncate root/bin/printenv root/bin/link root/bin/unlink root/bin/fold root/bin/groups \
	root/bin/learn root/usr/lib/learn/tee root/usr/lib/learn/lcount \
	root/usr/games/fortune root/usr/games/arithmetic root/usr/games/hangman \
	root/usr/games/backgammon root/usr/games/fish root/usr/games/quiz \
	root/usr/games/wump \
	root/usr/lib/spell root/usr/lib/spellin root/usr/lib/spellout \
	root/usr/games/lib/fortunes \
	root/etc/passwd root/etc/group root/etc/ttys root/usr/dict/words root/usr/lib/units \
	root/usr/lib/crontab \
	root/usr/dict/hlista root/usr/dict/hlistb root/usr/dict/hstop \
	root/usr/dict/spellhist \
	root/usr/lib/learn/Linfo root/usr/lib/learn/Xinfo $(LEARN_FILES) $(LEARN_MOREFILES) \
	build/auxfs.img

all:	unix root.img

unix:	sys/*.c arch/*.c arch/*.s arch/*.ld dev/*.c h/*.h
	cd sys; make unix

# Keep the in-rootfs /unix copy small: the live kernel still loads the
# full ELF directly from qemu's -kernel arg, while dmesg only needs
# the stripped file for nlist() lookup.  Removing loadable sections keeps
# the image compact without changing symbol values used by those tools.
root/unix:	unix
	arm-none-eabi-objcopy -R .text -R .rodata -R .stack -R .ARM.attributes -R .comment unix root/unix

qemu:	unix root.img
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel unix -drive if=none,file=root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

cmd/awk/awk.g.c cmd/awk/awk.h cmd/awk/proctab.c: ;

root.img: unix root/unix Makefile tools/mkfs conf/$(CONF)/root.proto cmd/*.c cmd/sh/* cmd/sed/* cmd/awk/* cmd/dc/* cmd/tar/* cmd/tp/* cmd/learn/* v7/bin/1 v7/bin/true v7/bin/false v7/bin/nohup v7/bin/plot v7/bin/spell cmd/spell/spell.sh lib/*.c lib/*.s lib/Makefile lib/u.ld root/bin/spell root/etc/passwd root/etc/rc root/etc/ttys root/usr/dict/words root/usr/dict/hlista root/usr/dict/hlistb root/usr/dict/hstop root/usr/dict/spellhist root/usr/games/lib/fortunes root/usr/lib/units root/usr/lib/crontab root/usr/lib/learn/Linfo root/usr/lib/learn/Xinfo tools/extract-old-ar.py $(LEARN_FILES) $(LEARN_MOREFILES) build/auxfs.img
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

root/bin/spell: v7/bin/spell cmd/spell/spell.sh
	mkdir -p root/bin
	cp cmd/spell/spell.sh root/bin/spell
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

root/usr/lib/learn/Linfo: v7/usr/lib/learn/Linfo
	mkdir -p root/usr/lib/learn
	cp v7/usr/lib/learn/Linfo root/usr/lib/learn/Linfo

root/usr/lib/learn/Xinfo: v7/usr/lib/learn/Xinfo
	mkdir -p root/usr/lib/learn
	cp v7/usr/lib/learn/Xinfo root/usr/lib/learn/Xinfo

$(LEARN_FILES): v7/usr/lib/learn/files.a tools/extract-old-ar.py
	mkdir -p root/usr/lib/learn/files
	python3 tools/extract-old-ar.py v7/usr/lib/learn/files.a root/usr/lib/learn/files

$(LEARN_MOREFILES): v7/usr/lib/learn/morefiles.a tools/extract-old-ar.py
	mkdir -p root/usr/lib/learn/morefiles
	python3 tools/extract-old-ar.py v7/usr/lib/learn/morefiles.a root/usr/lib/learn/morefiles

clean:
	cd sys; make clean
	cd lib; make clean
	rm -f unix root.img tools/mkfs
	rm -rf build
