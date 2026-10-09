CROSS_COMPILE ?= arm-none-eabi-
CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
AR = $(CROSS_COMPILE)ar
HOSTCC = arm-linux-gnueabihf-gcc
LEX = flex

W = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wstrict-prototypes \
	-Wold-style-definition -Wmissing-prototypes
CFLAGS = $W -fcommon \
	-ffreestanding -nostdlib -mcpu=cortex-a7 -marm -Os -Wl,-N,-Ttext=0x10 \
	-MMD -MP
ASFLAGS = -mcpu=cortex-a7
HOSTCFLAGS = $W -static \
	-D_FILE_OFFSET_BITS=32 -D_TIME_BITS=32

T = $(if $V,,@printf '  %-7s %s\n' $1 $@;)
Q = $(if $V,,@)
COMPILE.c = $(call T,CC)$(CC) $(CFLAGS) $(CPPFLAGS) -c
COMPILE.s = $(call T,AS)$(AS) $(ASFLAGS)
LINK = $(call T,LD)$(CC) $(CFLAGS) -s -o $@ $(filter %.o %.a,$^) -lgcc

all: boot/unix boot/rootfs.img

include usr/sys/sys.mk
include usr/src/libc/lib.mk
include usr/src/libm/lib.mk
include usr/src/cmd/cmd.mk
include usr/src/games/games.mk

all: $(KERNELS)

.SECONDARY: $(GEN)

OBJ = $(SYS_OBJ) $(LIBC_OBJ) $(CRT) $(LIBM_OBJ) $(CMD_OBJ) $(GAMES_OBJ)
$(OBJ) $(GEN): Makefile

%.c: %.y
	$(call T,YACC)bison -o $@ $<

boot/unix: usr/sys/conf/qemu/unix
	$(call T,CP)cp $< $@

qemu: boot/unix boot/rootfs.img
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic \
	    -kernel boot/unix -drive if=none,file=boot/rootfs.img,format=raw,id=hd0 \
	    -device virtio-blk-device,drive=hd0

ROOTFS_STATIC = bin/1 bin/true bin/false bin/nohup \
	etc/passwd etc/group etc/ttys \
	usr/dict/words usr/games/lib/fortunes usr/lib/units usr/lib/crontab \
	usr/lib/lib.b

ROOT = $(CMD) $(GAMES) $(ROOTFS_STATIC)

DIRS = bin usr/lib usr/dict usr/games usr/games/lib

boot/rootfs.img: boot/unix etc/mkfs boot/rootfs.proto $(ROOT)
	$(call T,MKFS)V7_MKFS_TIME=284774400 etc/mkfs $@ boot/rootfs.proto
	$Qtruncate -s $$(awk '/^(swplo|nswap) /{n+=$$2} END{print n*512}' \
	    usr/sys/conf/qemuconf) $@

etc/mkfs: usr/src/cmd/mkfs.c
	$(call T,HOSTCC)tmpinc="$(CURDIR)/boot/mkfs-include.$$$$"; \
	    trap 'rm -rf "$$tmpinc"' EXIT; \
	    mkdir -p "$$tmpinc"; \
	    ln -s "$(CURDIR)/usr/include/sys" "$$tmpinc/sys"; \
	    $(HOSTCC) $(HOSTCFLAGS) -I"$$tmpinc" -o $@ $<

$(DIRS):
	$Qmkdir -p $@

$(filter-out etc/%,$(ROOTFS_STATIC)): %: usr/local/test/v7/% | $(DIRS)
	$(call T,CP)cp -f $< $@

clean:
	rm -f $(OBJ) $(OBJ:.o=.d) $(GEN) $(CMD) $(GAMES)
	rm -f $(LIBC) $(LIBM) $(LIB1) $(LIB2) $(KERNELS)
	rm -f etc/mkfs boot/unix boot/rootfs.img

.PHONY: all clean qemu
.DELETE_ON_ERROR:

-include $(patsubst %.c,%.d,$(wildcard $(OBJ:.o=.c)))
