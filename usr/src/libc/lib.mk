L = usr/src/libc
LIBC = $L/libc.a
CRT = $L/csu/crt0.o $L/csu/crt0c.o
LIBC_OBJ := $(addsuffix .o,$(basename $(wildcard $L/*.[cs] $L/gen/*.[cs] \
	$L/stdio/*.[cs] $L/sys/*.[cs])))

$(LIBC_OBJ) $(CRT): CPPFLAGS = -Iusr/include -Iusr
$(LIBC_OBJ) $(CRT): $L/lib.mk

$(LIBC): $(LIBC_OBJ)
	rm -f $@
	$(AR) rc $@ $^

$L/csu/crt0.o: $L/csu/crt0.s
	$(COMPILE.s) -o $@ $<
$L/csu/crt0c.o: $L/csu/crt0.c
	$(COMPILE.c) -o $@ $<
