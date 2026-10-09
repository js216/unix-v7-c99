L = usr/src/libc
LIBC = $L/libc.a
CRT = $L/csu/crt0.o
LIBC_OBJ := $(addsuffix .o,$(basename $(wildcard $L/*.[cs] $L/gen/*.[cs] \
	$L/stdio/*.[cs] $L/sys/*.[cs])))

$(LIBC_OBJ) $(CRT): CPPFLAGS = -Iusr/include -Iusr
$(LIBC_OBJ) $(CRT): $L/lib.mk

$(LIBC): $(LIBC_OBJ)
	$Qrm -f $@
	$(call T,AR)$(AR) rc $@ $^
