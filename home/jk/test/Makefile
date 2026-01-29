CFLAGS  = -std=c99 -Wall -Wextra -Wpedantic -Werror -fno-builtin
SYS_DIR = ../../../usr/sys/sys

OBJS = test_malloc.o

test_malloc.o: test_malloc.c $(SYS_DIR)/malloc.o

.c.o:
	$(CC) $(CFLAGS) -I ../../../usr/sys/sys $^ -o $@

clean:
	rm -f $(OBJS)
