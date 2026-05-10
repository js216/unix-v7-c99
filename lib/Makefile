CC = arm-none-eabi-gcc
CFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Werror -Wno-error=parentheses -Wno-error=dangling-else -Wno-error=misleading-indentation -Wno-error=implicit-fallthrough -Wno-error=int-to-pointer-cast -Wno-error=char-subscripts -Wno-error=sizeof-pointer-div -Wno-error=missing-braces -Wno-error=missing-field-initializers -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../include -I..
SHCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -fms-extensions -Wno-parentheses -Wno-dangling-else -Wno-implicit-int -Wno-implicit-function-declaration -Wno-return-type -Wno-return-mismatch -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-sign-compare -Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -Wno-main -Wno-array-bounds -Wno-missing-braces -Wno-type-limits -Wno-implicit-fallthrough -Wno-pedantic -fcommon -fno-builtin -ffreestanding -nostdlib -mcpu=cortex-a7 -marm -I../include -I..
EDCFLAGS = $(SHCFLAGS) -Wno-builtin-declaration-mismatch
LDFLAGS = -nostdlib -T u.ld
LDLIBS = -lgcc
LIB = crt0.o crt0c.o syscall.o compat.o v7crypt.o l3.o \
      getpwent.o getpwnam.o getpwuid.o strncat.o ttyslot.o execvp.o getenv.o \
      atoi.o atol.o index.o rindex.o isatty.o perror.o \
      strcat.o strcmp.o strcpy.o strlen.o strncmp.o strncpy.o \
      swab.o rand.o mktemp.o errlst.o ttyname.o
# lib/abs.o is intentionally excluded -- cmd/chmod.c carries its
# own `abs(void)` parser helper that would collide with the v7
# libc abs(int).  No port currently calls libc abs(); the file
# is on disk only to satisfy the original-diffs ratchet.

# v7 sh has its own internal `getenv()` (a void(void) that walks
# environ[] and registers each entry as a sh variable -- not libc
# getenv).  Keep that file out of the sh link to avoid a duplicate
# symbol clash.
SHLIB = crt0.o crt0c.o syscall.o compat.o v7crypt.o l3.o \
      getpwent.o getpwnam.o getpwuid.o strncat.o ttyslot.o execvp.o \
      atoi.o atol.o index.o rindex.o isatty.o perror.o \
      strcat.o strcmp.o strcpy.o strlen.o strncmp.o strncpy.o \
      swab.o rand.o mktemp.o errlst.o ttyname.o
ETC = init getty
BIN = login cat echo ls pwd sync rev yes wc basename sum tty cmp comm cal od tail grep test look cp rm ln mkdir rmdir mv chmod chown chgrp sleep tee touch tr uniq du date kill nice mknod who mesg time split checkeq calendar tsort file join col fgrep su newgrp random crypt pr dd stty tabs diff wall write df clri dcheck icheck ncheck cb sp find sort mount umount id
USRLIB = makekey diffh
SHSRC = args blok builtin cmd ctype error expand fault io macro main msg name print service setbrk stak string word xec
SHOBJ = args.o blok.o builtin.o cmd.o ctype.o error.o expand.o fault.o io.o macro.o main.o msg.o name.o print.o service.o setbrk.o stak.o string.o word.o xec.o

all:	$(LIB)
	mkdir -p ../root/etc ../root/bin ../root/usr/lib
	set -e; for i in $(ETC); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(LIB) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/etc/$$i; \
	done
	set -e; for i in $(BIN); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(LIB) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/bin/$$i; \
	done
	set -e; for i in $(USRLIB); do \
		$(CC) $(CFLAGS) -c ../cmd/$$i.c; \
		$(CC) $(CFLAGS) $(LDFLAGS) -o $$i.elf $(LIB) $$i.o $(LDLIBS); \
		arm-none-eabi-objcopy -O binary $$i.elf ../root/usr/lib/$$i; \
	done
	$(CC) $(EDCFLAGS) -c ../cmd/ed.c
	$(CC) $(EDCFLAGS) $(LDFLAGS) -o ed.elf $(LIB) ed.o $(LDLIBS)
	arm-none-eabi-objcopy -O binary ed.elf ../root/bin/ed
	set -e; for i in $(SHSRC); do \
		$(CC) $(SHCFLAGS) -I../cmd/sh -c ../cmd/sh/$$i.c; \
	done
	$(CC) $(SHCFLAGS) $(LDFLAGS) -o sh.elf $(SHLIB) $(SHOBJ)
	arm-none-eabi-objcopy -O binary sh.elf ../root/bin/sh

crt0.o: crt0.s
	$(CC) $(CFLAGS) -c crt0.s

crt0c.o: crt0.c
	$(CC) $(CFLAGS) -c crt0.c -o crt0c.o

v7crypt.o: crypt.c
	$(CC) $(CFLAGS) -c crypt.c -o v7crypt.o

.s.o:
	$(CC) $(CFLAGS) -c $<

.c.o:
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o *.elf ../root/etc/init ../root/etc/getty
	rm -f ../root/bin/login ../root/bin/sh ../root/bin/cat
	rm -f ../root/bin/echo ../root/bin/ls ../root/bin/pwd ../root/bin/sync
	rm -f ../root/bin/rev
	rm -f ../root/bin/yes ../root/bin/wc ../root/bin/basename ../root/bin/sum
	rm -f ../root/bin/tty ../root/bin/cmp ../root/bin/comm ../root/bin/cal
	rm -f ../root/bin/od ../root/bin/tail ../root/bin/grep ../root/bin/test
	rm -f ../root/bin/look ../root/bin/cp ../root/bin/rm ../root/bin/ln
	rm -f ../root/bin/mkdir ../root/bin/rmdir ../root/bin/mv
	rm -f ../root/bin/chmod ../root/bin/chown ../root/bin/chgrp
	rm -f ../root/bin/sleep ../root/bin/tee ../root/bin/touch ../root/bin/tr
	rm -f ../root/bin/uniq ../root/bin/du ../root/bin/date ../root/bin/kill
	rm -f ../root/bin/nice ../root/bin/mknod ../root/bin/who ../root/bin/mesg
	rm -f ../root/bin/time ../root/bin/split
	rm -f ../root/bin/checkeq ../root/bin/calendar ../root/bin/tsort
	rm -f ../root/bin/file
	rm -f ../root/bin/join
	rm -f ../root/bin/col
	rm -f ../root/bin/fgrep
	rm -f ../root/bin/su ../root/bin/newgrp
	rm -f ../root/bin/random
	rm -f ../root/bin/crypt ../root/usr/lib/makekey ../root/usr/lib/diffh
	rm -f ../root/bin/pr
	rm -f ../root/bin/dd
	rm -f ../root/bin/stty
	rm -f ../root/bin/tabs
	rm -f ../root/bin/diff
	rm -f ../root/bin/wall
	rm -f ../root/bin/write
	rm -f ../root/bin/df
	rm -f ../root/bin/clri
	rm -f ../root/bin/dcheck ../root/bin/icheck ../root/bin/ncheck
	rm -f ../root/bin/cb
	rm -f ../root/bin/sp
	rm -f ../root/bin/find
	rm -f ../root/bin/sort
	rm -f ../root/bin/ed
