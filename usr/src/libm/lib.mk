LIBM = usr/src/libm/libm.a
LIBM_OBJ := $(patsubst %.c,%.o,$(wildcard usr/src/libm/*.c))

$(LIBM_OBJ): CPPFLAGS = -Iusr/include
$(LIBM_OBJ): usr/src/libm/lib.mk

$(LIBM): $(LIBM_OBJ)
	$Qrm -f $@
	$(call T,AR)$(AR) rc $@ $^
