CROSS_COMPILE ?= arm-none-eabi-
CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
AR = $(CROSS_COMPILE)ar
HOSTCC = cc
LEX = flex

W = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wstrict-prototypes \
	-Wold-style-definition -Wmissing-prototypes
CFLAGS = $W \
	-ffreestanding -nostdlib -mcpu=cortex-a7 -marm \
	-mfloat-abi=hard -Os \
	-Wl,-z,max-page-size=4096,-Ttext=0x94 \
	-MMD -MP
ASFLAGS = -mcpu=cortex-a7 -mfpu=neon-vfpv4
HOSTCFLAGS = $W

T = $(if $V,,@printf '  %-7s %s\n' $1 $@;)
Q = $(if $V,,@)
COMPILE.c = $(call T,CC)$(CC) $(CFLAGS) $(CPPFLAGS) -c
COMPILE.s = $(call T,AS)$(AS) $(ASFLAGS)
LINK = $(call T,LD)$(CC) $(CFLAGS) -s -o $@ $(filter %.o %.a,$^) -lgcc

all: boot/unix boot/rootfs.img boot/rootfs-mp135.img

include usr/sys/sys.mk
include usr/src/libc/lib.mk
include usr/src/libm/lib.mk
include usr/src/cmd/cmd.mk
include usr/src/cmd/standalone/stand.mk
include usr/src/games/games.mk
include usr/local/test/test.mk

all: $(KERNELS)

.SECONDARY: $(GEN)

OBJ = $(SYS_OBJ) $(LIBC_OBJ) $(CRT) $(MCRT) $(LIBM_OBJ) $(CMD_OBJ) \
	$(GAMES_OBJ) $(TEST_OBJ)
$(OBJ) $(GEN): Makefile

%.c: %.y
	$(call T,YACC)bison -o $@ $<

boot/unix: usr/sys/conf/qemu/unix
	$(call T,CP)cp $< $@

qemu: boot/unix boot/qemu.img
	qemu-system-arm -machine virt -cpu cortex-a7 -m 512M \
	    -nographic \
	    -kernel boot/unix \
	    -drive if=none,file=boot/qemu.img,format=raw,id=hd0 \
	    -device virtio-blk-device,drive=hd0

boot/qemu.img: boot/rootfs.img $S/conf/qemuconf
	$(call T,CP)cp --sparse=always $< $@
	$Qtruncate -s \
	    $$(awk '/^(swplo|nswap) /{n+=$$2} END{print n*512}' \
	    $S/conf/qemuconf) $@

ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup bin/diff3 \
	etc/passwd etc/group etc/ttys etc/rc \
	usr/dict/words usr/games/lib/fortunes usr/lib/units \
	usr/lib/crontab \
	usr/lib/lib.b

ROOT = $(CMD) $(GAMES) $(ROOTFS_STATIC) $(TEST_BIN) $(TEST_IMG) \
	$(TEST_DATA)

DIRS = bin usr/lib usr/dict usr/games usr/games/lib

boot/rootfs.img: boot/unix
boot/rootfs-mp135.img: $S/conf/mp135/unix
KERN = $(filter boot/unix $S/conf/%/unix,$^)
boot/rootfs.img boot/rootfs-mp135.img: etc/mkfs boot/rootfs.proto \
    $(ROOT)
	$(call T,MKFS)sed 's| boot/unix$$| $(KERN)|' \
	    boot/rootfs.proto | \
	    V7_MKFS_TIME=284774400 etc/mkfs $@ /dev/stdin

TOINT = s/^\(typedef[[:space:]]*\)long\([[:space:]]*[a-z]*_t;\)/\1int\2/
etc/mkfs: usr/src/cmd/mkfs.c usr/include/sys/*.h Makefile
	$(call T,HOSTCC)tmpinc="$(CURDIR)/boot/mkfs-include.$$$$"; \
	    trap 'rm -rf "$$tmpinc"' EXIT; \
	    mkdir -p "$$tmpinc/sys"; \
	    for h in param ino inode filsys fblk dir; do \
		sed -e '$(TOINT)' \
		    -e 's/off_t/v7_off_t/g' -e 's/time_t/v7_time_t/g' \
		    usr/include/sys/$$h.h >"$$tmpinc/sys/$$h.h"; \
	    done; \
	    $(HOSTCC) $(HOSTCFLAGS) -I"$$tmpinc" -o $@ $<

$(DIRS):
	$Qmkdir -p $@

$(filter-out etc/% usr/lib/crontab,$(ROOTFS_STATIC)): %: \
    usr/local/test/v7/% | $(DIRS)
	$(call T,CP)cp -f $< $@

clean:
	rm -f $(OBJ) $(OBJ:.o=.d) $(GEN) $(CMD) $(GAMES) $(TEST_BIN) \
	    $(TEST_IMG)
	rm -f $(LIBC) $(LIBM) $(LIB1) $(LIB2) $(KERNELS)
	rm -f etc/mkfs boot/unix boot/rootfs.img boot/rootfs-mp135.img \
	    boot/qemu.img

.PHONY: all clean qemu
.DELETE_ON_ERROR:

-include $(patsubst %.c,%.d,$(wildcard $(OBJ:.o=.c)))
