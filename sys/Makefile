CC = arm-none-eabi-gcc
AS = arm-none-eabi-as

CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin -mcpu=cortex-a7 -marm -ffreestanding
LDFLAGS = -nostdlib -T ../arch/a7.ld

OBJS = malloc.o prf.o ../arch/machdep.o ../arch/armboot.o
DEVS = ../dev/pl011.o

unix: ../unix

../unix: ../arch/a7.o main.o $(OBJS) $(DEVS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

../arch/a7.o: ../arch/a7.s
	$(AS) -mcpu=cortex-a7 -o ../arch/a7.o ../arch/a7.s

malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h ../h/buf.h

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(DEVS) ../arch/a7.o main.o unix ../unix

qemu: unix
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel ../unix -drive if=none,file=../root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0
