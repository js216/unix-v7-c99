CFLAGS=-n -s -O
LDFLAGS =
CRT =
LDLIBS =

all:	tp
	rm *.o

cp:	tp
	cp tp /bin/tp
	rm *.o tp

cmp:	tp
	cmp tp /bin/tp
	rm *.o tp

tp:	tp0.o tp1.o tp2.o tp3.o
	$(CC) $(CFLAGS) $(LDFLAGS) tp0.o tp1.o tp2.o tp3.o -o tp $(CRT) $(LDLIBS)

tp0.c tp1.c tp2.c tp3.c: tp.h
