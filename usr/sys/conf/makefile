unix:	low.o mch.o c.o ../sys/LIB1 ../dev/LIB2
	$(CC) -nostdlib -T unix.ld -o unix low.o mch.o c.o ../sys/LIB1 ../dev/LIB2

all:
	cd ../sys && $(CC) -c $(CFLAGS) *.c && sh mklib && rm *.o
	cd ../dev && $(CC) -c $(CFLAGS) *.c && sh mklib && rm *.o

mch.o:	mch.s
	$(AS) $(ASFLAGS) -o mch.o mch.s

allsystems:
	./mkconf <qemuconf
	make unix
	mv unix qemuunix
	./mkconf <mp135conf
	make unix
	mv unix mp135unix
