SYSDIR = ../../../usr/sys/sys
CFLAGS = -std=c99 -Wall -Wextra -pedantic -Werror -fno-builtin -I$(SYSDIR)

TEST = test_malloc
OBJS = putchar.o test_malloc.o

all: unix $(TEST)

unix:
	$(MAKE) -C $(SYSDIR)

test_malloc: test_malloc.c putchar.o $(SYSDIR)/malloc.o $(SYSDIR)/prf.o

clean:
	$(MAKE) -C $(SYSDIR) clean
	rm -f $(OBJS)
	rm -f $(TEST)
