CC = arm-none-eabi-gcc
AS = arm-none-eabi-as

CONF ?= arm_qemu
VPATH = ../sys
CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin -fcommon -mcpu=cortex-a7 -marm -ffreestanding

LDFLAGS = -nostdlib -T l.s -Wl,-z,max-page-size=0x200
DEVS = ../dev/pl011.o ../dev/virtio_blk.o

QEMU_ARGS = -machine virt -cpu cortex-a7 -nographic \
	-kernel ../../../unix -drive if=none,file=../../../root.img,format=raw,id=hd0 \
	-device virtio-blk-device,drive=hd0
V7OBJS = alloc.o subr.o fio.o sys2.o sys3.o sys4.o clock.o acct.o ureg.o text.o rdwri.o sig.o slp.o sys1.o pipe.o
OBJS = malloc.o prf.o iget.o nami.o machdep.o $(V7OBJS) ../dev/bio.o ../dev/msgbuf.o c.o
unix: ../../../unix
../../../unix: mch.o main.o $(OBJS) $(DEVS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
mch.o: mch.s
	$(AS) -mcpu=cortex-a7 -o mch.o mch.s
malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h
iget.o:   iget.c ../h/param.h ../h/systm.h ../h/mount.h ../h/dir.h ../h/user.h ../h/inode.h ../h/ino.h ../h/filsys.h ../h/buf.h
nami.o:   nami.c ../h/param.h ../h/systm.h ../h/inode.h ../h/mount.h ../h/dir.h ../h/user.h ../h/buf.h
../dev/bio.o: ../dev/bio.c ../h/buf.h ../h/conf.h ../h/param.h ../h/systm.h ../h/user.h ../h/dir.h
../dev/virtio_blk.o: ../dev/virtio_blk.c ../h/buf.h ../h/param.h
machdep.o: machdep.c ../h/seg.h ../h/buf.h ../h/param.h
c.c: mkconf $(CONF)
	./mkconf <$(CONF) >c.c
mkconf: mkconf.c
	cc -std=gnu89 -w -o mkconf mkconf.c
c.o: c.c ../h/conf.h ../h/buf.h ../h/param.h
.c.o:
	$(CC) $(CFLAGS) -c $< -o $@
clean:
	rm -f $(OBJS) $(DEVS) mch.o main.o unix ../../../unix c.c mkconf
qemu: unix
	qemu-system-arm $(QEMU_ARGS)
