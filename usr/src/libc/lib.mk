L = usr/src/libc
LIBC = $L/libc.a
CRT = $L/csu/crt0.o
MCRT = $L/csu/mcrt0.o
LIBC_OBJ := $(addsuffix .o,$(basename $(wildcard $L/*.[cs] $L/gen/*.[cs] \
	$L/stdio/*.[cs] $L/sys/*.[cs])))

$(LIBC_OBJ) $(CRT) $(MCRT): CPPFLAGS = -Iusr/include
$(LIBC_OBJ) $(CRT) $(MCRT): $L/lib.mk

$(LIBC): $(LIBC_OBJ)
	$Qrm -f $@
	$(call T,AR)$(AR) rc $@ $^
