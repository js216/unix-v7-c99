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

CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wno-error=pedantic -fms-extensions -fno-builtin -fcommon -mcpu=cortex-a7 -marm -ffreestanding $(CFLAGS_EXTRA)
LDFLAGS = -nostdlib -T $(LDSCRIPT) -Wl,-z,max-page-size=0x200

# V7-CFLAGS: looser flags for the historic K&R-style sys/*.c files so the
# strict -Werror build doesn't reject implicit-int returns and missing
# prototypes.  These TUs are linked alongside arch/armboot.c's syscall
# emulators -- armboot still drives the live trap path, but having the
# real V7 implementations resident sets up a future routing layer.
V7_CFLAGS = -std=c99 -Wno-implicit-int -Wno-implicit-function-declaration -Wno-return-type -Wno-return-mismatch -Wno-builtin-declaration-mismatch -Wno-pedantic -fms-extensions -fno-builtin -fcommon -mcpu=cortex-a7 -marm -ffreestanding $(CFLAGS_EXTRA)

V7OBJS = prim.o alloc.o subr.o fio.o sys2.o sys3.o sys4.o clock.o acct.o ureg.o text.o rdwri.o sig.o slp.o sys1.o pipe.o

OBJS = malloc.o prf.o iget.o nami.o $(V7OBJS) ../arch/machdep.o ../arch/armboot.o ../arch/v7stubs.o ../arch/u_stub.o ../arch/u_bridge.o ../arch/swtch.o ../dev/bio.o ../dev/mp135_blk.o ../dev/virtio_blk.o ../dev/msgbuf.o

unix: ../unix

../unix: ../arch/a7.o main.o $(OBJS) $(DEVS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

../arch/a7.o: ../arch/a7.s
	$(AS) -mcpu=cortex-a7 -o ../arch/a7.o ../arch/a7.s

../arch/swtch.o: ../arch/swtch.s
	$(AS) -mcpu=cortex-a7 -o ../arch/swtch.o ../arch/swtch.s

malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h ../h/buf.h
iget.o:   iget.c ../h/param.h ../h/systm.h ../h/mount.h ../h/dir.h ../h/user.h ../h/inode.h ../h/ino.h ../h/filsys.h ../h/conf.h ../h/buf.h
	$(CC) $(V7_CFLAGS) -c $< -o $@
nami.o:   nami.c ../h/param.h ../h/systm.h ../h/inode.h ../h/mount.h ../h/dir.h ../h/user.h ../h/buf.h
	$(CC) $(V7_CFLAGS) -c $< -o $@
../dev/bio.o: ../dev/bio.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h ../h/systm.h ../h/user.h ../h/proc.h ../h/seg.h ../h/dir.h
../dev/mp135_blk.o: ../dev/mp135_blk.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h
../dev/virtio_blk.o: ../dev/virtio_blk.c ../h/buf.h ../h/conf.h ../h/proto.h ../h/param.h
../arch/v7stubs.o: ../arch/v7stubs.c ../h/proto.h ../h/buf.h ../h/conf.h ../h/param.h ../h/dir.h ../h/user.h ../h/proc.h
../arch/u_stub.o: ../arch/u_stub.c ../h/param.h ../h/user.h ../h/proc.h ../h/file.h ../h/callo.h ../h/text.h
	$(CC) $(V7_CFLAGS) -c $< -o $@
../arch/u_bridge.o: ../arch/u_bridge.c ../h/param.h ../h/user.h ../h/dir.h ../h/proc.h
	$(CC) $(V7_CFLAGS) -c $< -o $@
../arch/machdep.o: ../arch/machdep.c ../h/proto.h ../h/buf.h ../h/param.h

# v7 K&R sys/*.c TUs: use the looser V7_CFLAGS so implicit-int returns
# and missing prototypes don't fail the build.
#
# subr.o renames bmap/bcopy/nulldev so arch/v7stubs.o's strong versions
# (with the ARM-specific iexpand byte-order unpacking) remain the
# link-time bindings used by the live nami.c path.  The renamed-out
# copies stay in the image as future hookup targets; no caller yet
# references them.
subr.o:  subr.c
	$(CC) $(V7_CFLAGS) -c $< -o subr.tmp.o
	arm-none-eabi-objcopy \
	    --redefine-sym bcopy=bcopy_v7 \
	    --redefine-sym nulldev=nulldev_v7 \
	    --redefine-sym nodev=nodev_v7 \
	    subr.tmp.o $@
	rm -f subr.tmp.o
alloc.o: alloc.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
prim.o:  prim.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
fio.o:   fio.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
sys2.o:  sys2.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
sys3.o:  sys3.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
sys4.o:  sys4.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
text.o:  text.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
clock.o: clock.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
acct.o:  acct.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
ureg.o:  ureg.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
rdwri.o: rdwri.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
sig.o:   sig.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
slp.o:   slp.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
sys1.o:  sys1.c
	$(CC) $(V7_CFLAGS) -c $< -o $@
# pipe.c is linked but its plock/prele are weakened so v7stubs.c's strong
# eager-clear stubs win at link time.  pipe.c's internal readp/writep call
# sites resolve to the strong global plock/prele symbols, dodging the
# real-sleep spin loop that has no scheduler to wake it.
pipe.o:  pipe.c
	$(CC) $(V7_CFLAGS) -c $< -o pipe.tmp.o
	arm-none-eabi-objcopy \
	    --weaken-symbol plock \
	    --weaken-symbol prele \
	    pipe.tmp.o $@
	rm -f pipe.tmp.o

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(DEVS) ../arch/a7.o ../arch/swtch.o main.o iget.o nami.o unix ../unix ../dev/bio.o ../dev/mp135_blk.o ../dev/virtio_blk.o ../arch/v7stubs.o ../arch/u_stub.o ../arch/u_bridge.o $(V7OBJS)

qemu: unix
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel ../unix -drive if=none,file=../root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0
