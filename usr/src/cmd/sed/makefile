CFLAGS = -n -O
LDFLAGS =
CRT =
LDLIBS =

all:	sed
	:

cp:	all
	cp sed /bin
	rm sed *.o

cmp:	all
	cmp sed /bin/sed
	rm sed *.o

sed:	sed0.o sed1.o; $(CC) $(CFLAGS) $(LDFLAGS) -o sed $(CRT) *.o $(LDLIBS)

sed0.o: sed0.c sed.h
sed1.o: sed1.c sed.h
