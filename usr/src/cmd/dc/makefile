LDFLAGS =
CRT =
LDLIBS =
all:	dc

cmp:	dc
	cmp dc /bin/dc
	rm dc

cp:	dc
	cp dc /bin/dc
	rm dc

dc:	dc.c dc.h
	$(CC) $(CFLAGS) $(LDFLAGS) dc.c -o dc $(CRT) $(LDLIBS)
