STAND = usr/src/cmd/standalone
SAFLAGS = $W -ffreestanding -nostdlib -mcpu=cortex-a7 -marm \
	-mfloat-abi=soft \
	-mno-unaligned-access -Os -fno-tree-loop-distribute-patterns \
	-Wl,-N,--section-start=.start=0x2ffe0000,-Ttext=0x2ffe0100

all: boot/sdwrite.stm32

$(STAND)/sdwrite: $(STAND)/sdwrite.c $(STAND)/stand.mk
	$(call T,LD)$(CC) $(SAFLAGS) -o $@ $<

boot/sdwrite.bin: $(STAND)/sdwrite
	$(call T,OBJCOPY)$(CROSS_COMPILE)objcopy -O binary $< $@

boot/sdwrite.stm32: boot/sdwrite.bin $S/conf/mkstm32
	$(call T,MKSTM32)$S/conf/mkstm32 $< $@
