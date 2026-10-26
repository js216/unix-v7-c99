S = usr/sys
LIB1 = $S/sys/LIB1
LIB2 = $S/dev/LIB2
LIB1_OBJ := $(patsubst %.c,%.o,$(wildcard $S/sys/*.c))
QEMU_DRV = $S/dev/pl011.o $S/dev/virtio_blk.o
MP135_DRV = $S/dev/usart.o $S/dev/iwdg.o $S/dev/sd.o $S/dev/ddr.o $S/dev/pmic.o \
	$S/dev/etzpc.o
LIB2_OBJ := $(filter-out $(QEMU_DRV) $(MP135_DRV), \
	$(patsubst %.c,%.o,$(wildcard $S/dev/*.c)))
BOARDS = qemu mp135
KERNELS = $(BOARDS:%=$S/conf/%/unix)
SYS_OBJ = $(LIB1_OBJ) $(LIB2_OBJ) $(QEMU_DRV) $(MP135_DRV) \
	$S/conf/low.o $S/conf/mch.o $(BOARDS:%=$S/conf/%/c.o)
GEN += $S/conf/mkstm32

$(SYS_OBJ): $S/sys.mk
$(SYS_OBJ): CFLAGS += -mfloat-abi=soft
$(LIB1): $(LIB1_OBJ)
$(LIB2): $(LIB2_OBJ)
$(LIB1) $(LIB2):
	$Qrm -f $@
	$(call T,AR)$(AR) rc $@ $^

$S/conf/mkstm32: $S/conf/mkstm32.c
	$(call T,HOSTCC)$(HOSTCC) $(HOSTCFLAGS) -o $@ $<

$S/conf/%/c.o: $S/conf/c.c
	$(COMPILE.c) -I$(@D) -o $@ $<
-include $(BOARDS:%=$S/conf/%/c.d)

$S/conf/qemu/unix: $(QEMU_DRV)
$S/conf/mp135/unix: $(MP135_DRV)
$S/conf/%/unix: $S/conf/low.o $S/conf/mch.o $S/conf/%/c.o $(LIB1) \
    $(LIB2) $S/conf/%/unix.ld
	$(call T,LD)$(CC) -nostdlib -T $(@D)/unix.ld -o $@ \
	    $(filter %.o,$^) $(LIB1) $(LIB2)

all: boot/unix-mp135.stm32
boot/unix-mp135.bin: $S/conf/mp135/unix
	$(call T,OBJCOPY)$(CROSS_COMPILE)objcopy -O binary $< $@
boot/unix-mp135.stm32: boot/unix-mp135.bin $S/conf/mkstm32
	$(call T,MKSTM32)$S/conf/mkstm32 $< $@
