CC = arm-none-eabi-gcc
AS = arm-none-eabi-as

CONF ?= arm_qemu

include ../conf/$(CONF)/config.mk

CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin -fcommon -mcpu=cortex-a7 -marm -ffreestanding
LDFLAGS = -nostdlib -T $(LDSCRIPT) -Wl,-z,max-page-size=0x200

V7OBJS = alloc.o subr.o fio.o sys2.o sys3.o sys4.o clock.o acct.o ureg.o text.o rdwri.o sig.o slp.o sys1.o pipe.o

OBJS = malloc.o prf.o iget.o nami.o machdep_arm.o v7stubs.o v7_bridge.o $(V7OBJS) ../arch/arm.o ../dev/bio.o ../dev/msgbuf.o $(CONF_OBJS)

unix: ../unix

../unix: ../arch/arm_asm.o main.o $(OBJS) $(DEVS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

../arch/arm_asm.o: ../arch/arm.s
	$(AS) -mcpu=cortex-a7 -o ../arch/arm_asm.o ../arch/arm.s

malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h
iget.o:   iget.c ../h/param.h ../h/systm.h ../h/mount.h ../h/dir.h ../h/user.h ../h/inode.h ../h/ino.h ../h/filsys.h ../h/buf.h
nami.o:   nami.c ../h/param.h ../h/systm.h ../h/inode.h ../h/mount.h ../h/dir.h ../h/user.h ../h/buf.h
../dev/bio.o: ../dev/bio.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h ../h/systm.h ../h/user.h ../h/dir.h
../dev/virtio_blk.o: ../dev/virtio_blk.c ../h/buf.h ../h/proto.h ../h/param.h
../arch/arm.o: ../arch/arm.c ../arch/arm.h ../h/proto.h ../h/buf.h ../h/conf.h ../h/param.h ../h/dir.h ../h/user.h
machdep_arm.o: machdep_arm.c ../arch/arm.h ../h/proto.h ../h/buf.h ../h/param.h
v7stubs.o: v7stubs.c ../h/proto.h ../h/buf.h ../h/conf.h ../h/param.h ../h/dir.h ../h/user.h
v7_bridge.o: v7_bridge.c ../arch/arm.h ../h/param.h ../h/user.h ../h/dir.h ../h/proc.h
../conf/$(CONF)/conf.o: ../conf/$(CONF)/conf.c ../h/conf.h ../h/buf.h ../h/param.h
	$(CC) $(CFLAGS) -c $< -o $@

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(DEVS) ../arch/*.o main.o unix ../unix

qemu: unix
	qemu-system-arm $(CONF_QEMU_ARGS)
