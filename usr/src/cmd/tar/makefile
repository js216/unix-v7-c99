V6LIB=/usr/src/libc/v6
CFLAGS=-O
LDFLAGS =
CRT =
LDLIBS =

all:	tar

cp:	all
	cp tar /bin
	rm -f tar *.o

cmp:	all
	cmp tar /bin/tar
	rm -f tar *.o

tar:	tar.c
	$(CC) $(CFLAGS) $(LDFLAGS) tar.c -o tar $(CRT) $(LDLIBS)

v6tar:	tar.o access.o chown.o execl.o ftime.o gtty.o lseek.o stat.o syscall.o time.o
	$(CC) $(CFLAGS) $(LDFLAGS) *.o -o v6tar $(LDLIBS)

access.o:	$(V6LIB)/access.c
	$(CC) $(CFLAGS) -c $?

chown.o:	$(V6LIB)/chown.c
	$(CC) $(CFLAGS) -c $?

execl.o:	$(V6LIB)/execl.c
	$(CC) $(CFLAGS) -c $?

ftime.o:	$(V6LIB)/ftime.c
	$(CC) $(CFLAGS) -c $?

gtty.o:	$(V6LIB)/gtty.c
	$(CC) $(CFLAGS) -c $?

lseek.o:	$(V6LIB)/lseek.c
	$(CC) $(CFLAGS) -c $?

stat.o:	$(V6LIB)/stat.c
	$(CC) $(CFLAGS) -c $?

syscall.o:	$(V6LIB)/syscall.s
	$(CC) $(CFLAGS) -c $?

time.o:	$(V6LIB)/time.s
	$(CC) $(CFLAGS) -c $?
