unix:	low.o mch.o conf.o qemu.o mp135.o ../sys/LIB1 ../dev/LIB2
	$(CC) -nostdlib -T $(LDSCRIPT) -o unix low.o mch.o conf.o qemu.o mp135.o ../sys/LIB1 ../dev/LIB2

all:
	cd ../sys && $(CC) -c $(CFLAGS) *.c && sh mklib && rm *.o
	cd ../dev && $(CC) -c $(CFLAGS) *.c && sh mklib && rm *.o

mch.o:	mch.s
	$(AS) $(ASFLAGS) -o mch.o mch.s

allsystems:
	mkconf <hphtconf
	make unix
	mv unix hphtunix
	mkconf <hptmconf
	make unix
	mv unix hptmunix
	mkconf <rptmconf
	make unix
	mv unix rptmunix
	mkconf <rphtconf
	make unix
	mv unix rphtunix
	mkconf <rktmconf
	make unix
	mv unix rktmunix
	mkconf <rkhtconf
	make unix
	mv unix rkhtunix
