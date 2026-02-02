CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin

OBJS = malloc.o prf.o

all: $(OBJS)

malloc.o: malloc.c ../h/map.h ../h/param.h
prf.o:    prf.c ../h/param.h ../h/buf.h

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)
