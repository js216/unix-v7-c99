CC = arm-none-eabi-gcc
AS = arm-none-eabi-as

CONF ?= qemu_arm

ifeq ($(CONF),evb_arm)
LDSCRIPT = ../arch/evb.ld
DEVS    = ../dev/stm32_usart.o ../dev/mp135_blk.o
CFLAGS_EXTRA = -DEVB
else
LDSCRIPT = ../arch/a7.ld
DEVS    = ../dev/pl011.o ../dev/virtio_blk.o
CFLAGS_EXTRA =
endif

CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin -fcommon -mcpu=cortex-a7 -marm -ffreestanding $(CFLAGS_EXTRA)
LDFLAGS = -nostdlib -T $(LDSCRIPT) -Wl,-z,max-page-size=0x200

V7OBJS = alloc.o subr.o fio.o sys2.o sys3.o sys4.o clock.o acct.o ureg.o text.o rdwri.o sig.o slp.o sys1.o pipe.o

OBJS = malloc.o prf.o iget.o nami.o $(V7OBJS) ../arch/machdep.o ../arch/armboot.o ../arch/v7stubs.o ../arch/u_stub.o ../arch/u_bridge.o ../arch/swtch.o ../dev/bio.o ../dev/msgbuf.o

unix: ../unix

../unix: ../arch/a7.o main.o $(OBJS) $(DEVS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

../arch/a7.o: ../arch/a7.s
	$(AS) -mcpu=cortex-a7 -o ../arch/a7.o ../arch/a7.s

../arch/swtch.o: ../arch/swtch.s
	$(AS) -mcpu=cortex-a7 -o ../arch/swtch.o ../arch/swtch.s

malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h
iget.o:   iget.c ../h/param.h ../h/systm.h ../h/mount.h ../h/dir.h ../h/user.h ../h/inode.h ../h/ino.h ../h/filsys.h ../h/buf.h
nami.o:   nami.c ../h/param.h ../h/systm.h ../h/inode.h ../h/mount.h ../h/dir.h ../h/user.h ../h/buf.h
../dev/bio.o: ../dev/bio.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h ../h/systm.h ../h/user.h ../h/dir.h
../dev/mp135_blk.o: ../dev/mp135_blk.c ../h/buf.h ../h/proto.h ../h/param.h
../dev/virtio_blk.o: ../dev/virtio_blk.c ../h/buf.h ../h/proto.h ../h/param.h
../arch/v7stubs.o: ../arch/v7stubs.c ../h/proto.h ../h/buf.h ../h/conf.h ../h/param.h ../h/dir.h ../h/user.h
../arch/u_stub.o: ../arch/u_stub.c ../h/param.h ../h/user.h ../h/proc.h ../h/file.h ../h/text.h ../h/conf.h
../arch/u_bridge.o: ../arch/u_bridge.c ../h/param.h ../h/user.h ../h/dir.h ../h/proc.h
../arch/machdep.o: ../arch/machdep.c ../h/proto.h ../h/buf.h ../h/param.h

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(DEVS) ../arch/a7.o ../arch/swtch.o main.o unix ../unix

qemu: unix
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel ../unix -drive if=none,file=../root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0
