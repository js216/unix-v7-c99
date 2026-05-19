CC = arm-none-eabi-gcc
HOSTCC ?= cc
CFLAGS = -std=c99 -Wall -Wextra -Wpedantic \
	-Wno-parentheses -Wno-dangling-else \
	-Wno-implicit-int -Wno-implicit-function-declaration \
	-Wno-return-type -Wno-return-mismatch \
	-Wno-incompatible-pointer-types -Wno-int-conversion \
	-Wno-sign-compare -Wno-unused-function -Wno-unused-variable \
	-Wno-unused-parameter -Wno-main -Wno-array-bounds \
	-Wno-missing-braces -Wno-type-limits -Wno-implicit-fallthrough \
	-Wno-builtin-declaration-mismatch -Wno-pedantic \
	-fcommon -fno-builtin -ffreestanding -nostdlib \
	-mcpu=cortex-a7 -marm -I../../include -I../.. -I.
HOSTCFLAGS = -std=c99 -Wall -Wextra -Wpedantic -Wno-pointer-to-int-cast \
	-fno-builtin

CHESS_C = agen.c bheur.c book.c bplay.c data.c init.c io.c mater.c \
	play.c pio.c qsort.c savres.c setup.c stat.c stdin.c wheur.c \
	wmove.c bmove.c wgen.c bgen.c wplay.c att.c ctrl.c
CHESS_OBJ = $(CHESS_C:.c=.o)

.PHONY: all objects check-sort check-move check-attack check-gen clean

all: objects

objects: $(CHESS_OBJ)

check-sort: qsort_check
	./qsort_check

qsort_check: qsort.c qsort_check.c
	$(HOSTCC) $(HOSTCFLAGS) qsort.c qsort_check.c -o $@

check-move: move_check
	./move_check

move_check: wmove.c bmove.c move_check.c old.h
	$(HOSTCC) $(HOSTCFLAGS) -fcommon wmove.c bmove.c move_check.c -o $@

check-attack: attack_check
	./attack_check

attack_check: att.c ctrl.c attack_check.c old.h
	$(HOSTCC) $(HOSTCFLAGS) -fcommon att.c ctrl.c attack_check.c -o $@

check-gen: gen_check
	./gen_check

gen_check: wgen.c bgen.c gen_check.c old.h
	$(HOSTCC) $(HOSTCFLAGS) -fcommon wgen.c bgen.c gen_check.c -o $@

%.o: %.c old.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(CHESS_OBJ) qsort_check move_check attack_check gen_check
