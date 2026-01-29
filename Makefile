CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin
SYS_DIR = usr/sys/sys

OBJS = $(SYS_DIR)/malloc.o

$(SYS_DIR)/malloc.o: $(SYS_DIR)/malloc.c \
          usr/sys/h/map.h usr/sys/h/systm.h usr/sys/h/param.h

.c.o:
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)
