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
	bin/spell \
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

unix: usr/sys/sys/*.c usr/sys/dev/*.c usr/sys/h/*.h usr/sys/conf/*.s usr/sys/conf/makefile usr/sys/conf/mkconf.c usr/sys/conf/$(CONF)
	$(MAKE) -C usr/sys/conf unix

qemu:	unix root.img
	$(MAKE) -C usr/sys/conf qemu

root.img: force-root-image unix Makefile usr/src/tools/mkfs usr/sys/conf/root.proto nullboot .profile usr/src/cmd/*.c usr/src/cmd/sh/* usr/src/cmd/sed/* usr/src/cmd/awk/* usr/src/cmd/dc/* usr/src/cmd/tar/* usr/src/cmd/tp/* v7/bin/1 v7/bin/true v7/bin/false v7/bin/nohup v7/bin/spell usr/src/libc/*.c usr/src/libc/*.s usr/src/libc/sys/* usr/src/libc/gen/* usr/src/libc/stdio/* usr/src/libc/compall usr/src/libc/mklib usr/src/libc/u.ld
	cd usr/src/libc && sh compall && sh mklib
	$(MAKE) userland-extra
	rm -f bin/bc
	set -e; for i in $(ROOT); do \
		test -e "$$i" || { echo "$$i: missing root payload"; exit 1; }; \
	done
	# v7 mkfs only writes the blocks it touches.  Pad root.img to its
	# declared filesystem size (FSIZE * BSIZE = 16384 * 512) so qemu's
	# virtio block backend can serve any sector the kernel asks for.
	trap 'rm -f root.img.tmp' EXIT; \
	    usr/src/tools/mkfs root.img.tmp usr/sys/conf/root.proto; \
	    truncate -s 8388608 root.img.tmp; \
	    mv root.img.tmp root.img
	$(MAKE) userland-clean

USERCC = arm-none-eabi-gcc
USEROBJCOPY = arm-none-eabi-objcopy
USERCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -Iusr/include -Iusr/src
USERAWKCFLAGS = $(USERCFLAGS) -Os -fno-asynchronous-unwind-tables -fno-unwind-tables -Dmalloc=malloc -Dfree=free -Iusr/src/cmd/awk -Wno-int-conversion -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast -Wno-implicit-function-declaration -Wno-builtin-declaration-mismatch -Wno-implicit-int -Wno-return-type -Wno-unused-function -Wno-discarded-qualifiers
USERYACCCFLAGS = $(USERCFLAGS) -DYYSTACK_USE_ALLOCA=1 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-return-type -Wno-return-mismatch -Wno-int-conversion -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast -Wno-char-subscripts -Wno-implicit-fallthrough -Wno-type-limits -Wno-unused-parameter
USERLDFLAGS = -nostdlib -T usr/src/libc/u.ld
USERLDLIBS = -Lusr/src/libc -lc -lgcc
USERCRT = usr/src/libc/crt0.o usr/src/libc/crt0c.o
AWKGEN = usr/src/cmd/awk/awk.g.c usr/src/cmd/awk/awk.h \
	usr/src/cmd/awk/awk.lx.c usr/src/cmd/awk/awk.lx.tmp.l \
	usr/src/cmd/awk/proc usr/src/cmd/awk/proc-token.o \
	usr/src/cmd/awk/proctab.c

.PHONY: force-root-image userland-extra userland-clean
force-root-image:

nullboot:
	: > nullboot

userland-extra:
	mkdir -p bin usr/lib
	set -e; for i in echo date at ls pwd tabs diff diff3 wall write df clri dcheck icheck ncheck cb sp find sort grep passwd iostat ps pstat quot calendar dmesg ed factor primes umount deroff osh; do \
		cflags="$(USERCFLAGS)"; \
		if test "$$i" = grep; then cflags="$$cflags -Wno-char-subscripts"; fi; \
		$(USERCC) $$cflags -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) -O binary usr/src/libc/$$i.elf bin/$$i; \
	done
	set -e; for i in init login; do \
		$(USERCC) $(USERCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
	done
	$(USEROBJCOPY) -O binary usr/src/libc/init.elf etc/init
	$(USEROBJCOPY) -O binary usr/src/libc/login.elf bin/login
	$(USERCC) $(USERCFLAGS) -Wno-missing-braces -c usr/src/cmd/getty.c -o usr/src/libc/cmd-getty.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/getty.elf $(USERCRT) usr/src/libc/cmd-getty.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/getty.elf etc/getty
	set -e; for i in accton update atrun cron; do \
		$(USERCC) $(USERCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) -O binary usr/src/libc/$$i.elf etc/$$i; \
	done
	set -e; for i in makekey diffh; do \
		$(USERCC) $(USERCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) -O binary usr/src/libc/$$i.elf usr/lib/$$i; \
	done
	$(USERCC) $(USERCFLAGS) -Wno-dangling-else -c usr/src/cmd/rm.c -o usr/src/libc/cmd-rm.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/rm.elf $(USERCRT) usr/src/libc/cmd-rm.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/rm.elf bin/rm
	$(USERCC) $(USERCFLAGS) -Wno-missing-braces -c usr/src/cmd/stty.c -o usr/src/libc/cmd-stty.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/stty.elf $(USERCRT) usr/src/libc/cmd-stty.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/stty.elf bin/stty
	set -e; trap 'rm -f usr/src/cmd/egrep.c usr/src/cmd/expr.c' EXIT; \
	for i in egrep expr; do \
		(cd usr/src/cmd && bison -y $$i.y && mv y.tab.c $$i.c); \
		$(USERCC) $(USERYACCCFLAGS) -c usr/src/cmd/$$i.c -o usr/src/libc/cmd-$$i.o; \
		$(USERCC) $(USERYACCCFLAGS) $(USERLDFLAGS) -o usr/src/libc/$$i.elf $(USERCRT) usr/src/libc/cmd-$$i.o $(USERLDLIBS); \
		$(USEROBJCOPY) -O binary usr/src/libc/$$i.elf bin/$$i; \
	done
	set -e; for i in sed0 sed1; do \
		$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/sed -c usr/src/cmd/sed/$$i.c -o usr/src/libc/$$i.o; \
	done
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/sed.elf $(USERCRT) usr/src/libc/sed0.o usr/src/libc/sed1.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/sed.elf bin/sed
	set -e; for i in args blok builtin cmd ctype error expand fault io macro main msg name print service setbrk stak string word xec; do \
		$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/sh -c usr/src/cmd/sh/$$i.c -o usr/src/libc/sh-$$i.o; \
	done
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/sh.elf $(USERCRT) usr/src/libc/sh-*.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/sh.elf bin/sh
	$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/dc -c usr/src/cmd/dc/dc.c -o usr/src/libc/dc.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/dc.elf $(USERCRT) usr/src/libc/dc.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/dc.elf bin/dc
	$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/tar -c usr/src/cmd/tar/tar.c -o usr/src/libc/tar.o
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/tar.elf $(USERCRT) usr/src/libc/tar.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/tar.elf bin/tar
	set -e; for i in tp0 tp1 tp2 tp3; do \
		$(USERCC) $(USERCFLAGS) -Iusr/src/cmd/tp -c usr/src/cmd/tp/$$i.c -o usr/src/libc/$$i.o; \
	done
	$(USERCC) $(USERCFLAGS) $(USERLDFLAGS) -o usr/src/libc/tp.elf $(USERCRT) usr/src/libc/tp0.o usr/src/libc/tp1.o usr/src/libc/tp2.o usr/src/libc/tp3.o $(USERLDLIBS)
	$(USEROBJCOPY) -O binary usr/src/libc/tp.elf bin/tp
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
	$(USEROBJCOPY) -O binary usr/src/libc/awk.elf bin/awk

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
	cd usr/src/libc && ./compall clean
	rm -f unix root.img root.img.tmp nullboot usr/src/tools/mkfs $(AWKGEN)
