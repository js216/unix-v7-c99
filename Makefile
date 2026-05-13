# SPDX-License-Identifier: MIT
# Makefile --- unix-v7-c99 build: cross-compiled kernel + V7 userland
# Copyright (c) 2026 Jakob Kastelic

ROOT = root/etc/init root/etc/getty root/bin/login root/bin/sh \
	root/bin/cat root/bin/echo root/bin/ls root/bin/pwd root/bin/sync \
	root/bin/rev root/bin/yes root/bin/wc root/bin/basename root/bin/sum \
	root/bin/tty root/bin/cmp root/bin/comm root/bin/cal root/bin/od \
	root/bin/tail root/bin/grep root/bin/test root/bin/look root/bin/cp \
	root/bin/rm root/bin/ln root/bin/mkdir root/bin/rmdir root/bin/mv \
	root/bin/chmod root/bin/chown root/bin/chgrp root/bin/sleep \
	root/bin/tee root/bin/touch root/bin/tr root/bin/uniq root/bin/du \
	root/bin/date root/bin/kill root/bin/nice root/bin/mknod root/bin/who \
	root/bin/mesg root/bin/time root/bin/split root/bin/checkeq \
	root/bin/calendar root/bin/tsort root/bin/file root/bin/join root/bin/col \
	root/bin/fgrep root/bin/su root/bin/newgrp root/bin/random root/bin/crypt \
	root/bin/pr root/bin/dd root/bin/stty root/bin/tabs root/bin/diff \
	root/bin/wall root/bin/write root/bin/df root/bin/clri \
	root/bin/dcheck root/bin/icheck root/bin/ncheck \
	root/bin/cb root/bin/sp root/bin/find root/bin/sort root/bin/ed \
	root/bin/mount root/bin/umount root/bin/id \
	root/usr/lib/makekey root/usr/lib/diffh \
	root/etc/passwd root/etc/ttys root/usr/dict/words \
	build/auxfs.img

all:	unix

unix:	root.img sys/*.c arch/*.c arch/*.s arch/*.ld dev/*.c h/*.h
	cd sys; make unix

qemu:	unix
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel unix -drive if=none,file=root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

root.img: Makefile tools/mkfs root.proto cmd/*.c cmd/sh/* lib/*.c lib/*.s lib/*.h lib/Makefile lib/u.ld root/etc/passwd root/etc/ttys build/auxfs.img
	cd lib; make
	mkdir -p build
	tools/mkfs root.img root.proto
	# v7 mkfs only writes the blocks it touches.  Pad root.img to its
	# declared filesystem size (FSIZE * BSIZE = 4096 * 512) so qemu's
	# virtio block backend can serve any sector the kernel asks for.
	truncate -s 2097152 root.img

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
	arm-linux-gnueabihf-gcc -std=c89 -static \
	    -D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32 \
	    -fms-extensions \
	    -Wno-pedantic \
	    -o tools/mkfs tools/mkfs.c

# A pocket-sized fs image holding just /a=root/etc/passwd, mounted as
# /etc/auxfs by the icheck/dcheck/ncheck mission step.  The static
# auxfs.proto declares a tiny (64 block, 32 inode) volume.
build/auxfs.img: tools/mkfs auxfs.proto root/etc/passwd
	mkdir -p build
	tools/mkfs build/auxfs.img auxfs.proto
	truncate -s 32768 build/auxfs.img

root/usr/dict/words: v7/usr/dict/words
	mkdir -p root/usr/dict
	cp v7/usr/dict/words root/usr/dict/words

clean:
	cd sys; make clean
	cd lib; make clean
	rm -f unix root.img tools/mkfs tools/minimkfs
	rm -rf build
