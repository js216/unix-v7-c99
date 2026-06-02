CFLAGS=-O
YFLAGS=-d
LDFLAGS =
CRT =
LDLIBS = -lm
YACC = bison -y
LEX = flex
HOSTCC = cc
HOSTCFLAGS = -std=gnu89 -w

all:	awk

cp:	awk
	cp awk /bin/awk
	rm *.o awk.h proc awk proctab.c y.tab.h

cmp:	awk
	cmp awk /bin/awk
	rm *.o awk.h proc awk proctab.c y.tab.h

FILES=awk.lx.o b.o main.o token.o tran.o lib.o run.o parse.o proctab.o 
SOURCE=awk.def awk.g.y awk.lx.l b.c lib.c main.c parse.c proctab.c \
	proc.c\
	run.c token.c tran.c
GEN=awk.g.c awk.h awk.lx.c proc proc-token.o proctab.c

awk:	$(FILES) awk.g.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o awk $(CRT) awk.g.o $(FILES) $(LDLIBS)

awk.g.c awk.h:	awk.g.y
	$(YACC) $(YFLAGS) awk.g.y
	mv y.tab.c awk.g.c
	mv y.tab.h awk.h

awk.g.o:	awk.g.c awk.h awk.def
	$(CC) $(CFLAGS) -c awk.g.c

$(FILES):	awk.h awk.def

awk.lx.c:	awk.lx.l
	$(LEX) -o awk.lx.c awk.lx.l

src:	$(SOURCE) test.a tokenscript makefile
	cp $? /usr/src/cmd/awk
	touch src

profile:	awk.g.o $(FILES)
	$(CC) -p $(CFLAGS) awk.g.o $(FILES) $(LDLIBS)

find:
	egrep -n "$(PAT)" *.[ylhc] awk.def

list:
	-pr $(SOURCE) makefile

lint:
	lint -spu b.c main.c token.c tran.c run.c lib.c parse.c -lm |\
		egrep -v '^(error|free|malloc)'

proctab.c:	proc
	./proc > proctab.c
proc:	awk.h proc.c token.c
	$(HOSTCC) $(HOSTCFLAGS) -c token.c -o proc-token.o
	$(HOSTCC) $(HOSTCFLAGS) -o proc proc.c proc-token.o
clean:
	rm -f awk *.o $(GEN) y.tab.c y.tab.h
