CC = arm-none-eabi-gcc
AS = arm-none-eabi-as

CONF ?= qemu_arm

ifeq ($(CONF),evb_arm)
LDSCRIPT = ../arch/evb.ld
DEVS    = ../dev/stm32_usart.o
CFLAGS_EXTRA = -DEVB
else
LDSCRIPT = ../arch/a7.ld
DEVS    = ../dev/pl011.o
CFLAGS_EXTRA =
endif

CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin -fcommon -mcpu=cortex-a7 -marm -ffreestanding $(CFLAGS_EXTRA)
LDFLAGS = -nostdlib -T $(LDSCRIPT)

OBJS = malloc.o prf.o iget.o nami.o ../arch/machdep.o ../arch/armboot.o ../arch/v7stubs.o ../dev/bio.o ../dev/mp135_blk.o ../dev/virtio_blk.o

unix: ../unix

../unix: ../arch/a7.o main.o $(OBJS) $(DEVS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

../arch/a7.o: ../arch/a7.s
	$(AS) -mcpu=cortex-a7 -o ../arch/a7.o ../arch/a7.s

malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h ../h/buf.h
iget.o:   iget.c ../h/param.h ../h/systm.h ../h/mount.h ../h/dir.h ../h/user.h ../h/inode.h ../h/ino.h ../h/filsys.h ../h/conf.h ../h/buf.h
nami.o:   nami.c ../h/param.h ../h/systm.h ../h/inode.h ../h/mount.h ../h/dir.h ../h/user.h ../h/buf.h
../dev/bio.o: ../dev/bio.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h ../h/systm.h ../h/user.h ../h/proc.h ../h/seg.h ../h/dir.h
../dev/mp135_blk.o: ../dev/mp135_blk.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h
../dev/virtio_blk.o: ../dev/virtio_blk.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h
../arch/v7stubs.o: ../arch/v7stubs.c ../h/proto.h ../h/buf.h ../h/conf.h ../h/param.h ../h/dir.h ../h/user.h ../h/proc.h
../arch/machdep.o: ../arch/machdep.c ../h/proto.h ../h/buf.h ../h/param.h

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(DEVS) ../arch/a7.o main.o iget.o nami.o unix ../unix ../dev/bio.o ../dev/mp135_blk.o ../dev/virtio_blk.o ../arch/v7stubs.o

qemu: unix
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel ../unix -drive if=none,file=../root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0
