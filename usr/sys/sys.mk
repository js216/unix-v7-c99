S = usr/sys
LIB1 = $S/sys/LIB1
LIB2 = $S/dev/LIB2
LIB1_OBJ := $(patsubst %.c,%.o,$(wildcard $S/sys/*.c))
LIB2_OBJ := $(patsubst %.c,%.o,$(wildcard $S/dev/*.c))
BOARDS = qemu mp135
KERNELS = $(BOARDS:%=$S/conf/%/unix)
SYS_OBJ = $(LIB1_OBJ) $(LIB2_OBJ) $S/conf/low.o $S/conf/mch.o $(BOARDS:%=$S/conf/%/c.o)
GEN += $(BOARDS:%=$S/conf/%/c.c) $(BOARDS:%=$S/conf/%/unix.ld) $S/conf/mkconf

$(SYS_OBJ): $S/sys.mk
$(LIB1): $(LIB1_OBJ)
$(LIB2): $(LIB2_OBJ)
$(LIB1) $(LIB2):
	rm -f $@
	$(AR) rc $@ $^

$S/conf/mkconf: $S/conf/mkconf.c
	$(HOSTCC) $(HOSTCFLAGS) -o $@ $<

$S/conf/%/c.c $S/conf/%/unix.ld: $S/conf/%conf $S/conf/mkconf
	mkdir -p $(@D)
	cd $(@D) && ../mkconf <../$*conf

$S/conf/%/c.o: CPPFLAGS = -I$S/conf

$S/conf/%/unix: $S/conf/low.o $S/conf/mch.o $S/conf/%/c.o $(LIB1) $(LIB2) $S/conf/%/unix.ld
	$(CC) -nostdlib -T $(@D)/unix.ld -o $@ $(filter-out %.ld,$^)
