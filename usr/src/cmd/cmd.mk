C = usr/src/cmd
CMD_ETC = accton cron dmesg getty init mknod mount umount update wall
CMD_USRLIB = atrun diff3 diffh makekey
CMD_DIRS = awk dc sed sh tar tp

CMD_ONE := $(sort $(filter-out mkfs,$(basename $(notdir $(wildcard $C/*.[cy])))))
CMD_BIN = $(filter-out $(CMD_ETC) $(CMD_USRLIB),$(CMD_ONE))
CMD = $(CMD_BIN:%=bin/%) $(CMD_ETC:%=etc/%) $(CMD_USRLIB:%=usr/lib/%) \
	$(CMD_DIRS:%=bin/%)

AWK_OBJ = $(addprefix $C/awk/,awk.g.o awk.lx.o b.o main.o token.o tran.o \
	lib.o run.o parse.o proctab.o)
dirobj = $(patsubst %.c,%.o,$(wildcard $C/$1/*.c))
CMD_OBJ = $(CMD_ONE:%=$C/%.o) $(AWK_OBJ) $(foreach d,dc sed sh tar tp,$(call dirobj,$d))
GEN += $(patsubst %.y,%.c,$(wildcard $C/*.y)) $C/awk/awk.g.c $C/awk/awk.h \
	$C/awk/awk.lx.c $C/awk/proc $C/awk/proctab.c

$(CMD_OBJ): CPPFLAGS = -Iusr/include
$(CMD_OBJ): $C/cmd.mk
$C/bc.o $C/egrep.o $C/expr.o $(AWK_OBJ): CPPFLAGS += -DYYSTACK_USE_ALLOCA=1

$(CMD_BIN:%=bin/%): bin/%: $(CRT) $C/%.o $(LIBM) $(LIBC) | bin
	$(LINK)
$(CMD_ETC:%=etc/%): etc/%: $(CRT) $C/%.o $(LIBC)
	$(LINK)
$(CMD_USRLIB:%=usr/lib/%): usr/lib/%: $(CRT) $C/%.o $(LIBC) | usr/lib
	$(LINK)

bin/awk: $(CRT) $(AWK_OBJ) $(LIBM) $(LIBC) | bin
	$(LINK)
bin/dc: $(CRT) $(call dirobj,dc) $(LIBC) | bin
	$(LINK)
bin/sed: $(CRT) $(call dirobj,sed) $(LIBC) | bin
	$(LINK)
bin/sh: $(CRT) $(call dirobj,sh) $(LIBC) | bin
	$(LINK)
bin/tar: $(CRT) $(call dirobj,tar) $(LIBC) | bin
	$(LINK)
bin/tp: $(CRT) $(call dirobj,tp) $(LIBC) | bin
	$(LINK)

$(AWK_OBJ): $C/awk/awk.h $C/awk/awk.def
$C/awk/awk.g.c $C/awk/awk.h &: $C/awk/awk.g.y
	$(call T,YACC)bison --defines=$C/awk/awk.h -o $C/awk/awk.g.c $<
$C/awk/proc: $C/awk/proc.c $C/awk/token.c $C/awk/awk.h $C/awk/awk.def
	$(call T,HOSTCC)$(HOSTCC) $(HOSTCFLAGS) -o $@ $C/awk/proc.c $C/awk/token.c
$C/awk/proctab.c: $C/awk/proc
	$(call T,GEN)$< >$@
$C/awk/awk.lx.c: $C/awk/awk.lx.l
	$(call T,LEX)$(LEX) -t $< | sed 's/void yynoreturn/void/;s/<string.h>/<stddef.h>/;/<stdlib.h>/d' >$@
