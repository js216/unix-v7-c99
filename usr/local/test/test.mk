TS = usr/local/test
TEST_BIN := $(patsubst $(TS)/utils/%.c,$(TS)/obj/%, \
	$(wildcard $(TS)/utils/*.c))
TEST_OBJ = $(TEST_BIN:%=%.o)
TEST_DATA := $(wildcard $(TS)/run.sh $(TS)/fuzz.sh $(TS)/cases/* \
	$(filter-out %.c,$(wildcard $(TS)/utils/*)))

$(TEST_OBJ): CPPFLAGS = -Iusr/include -Iusr/sys
$(TEST_OBJ): $(TS)/test.mk
$(TEST_OBJ): $(TS)/obj/%.o: $(TS)/utils/%.c | $(TS)/obj
	$(COMPILE.c) -o $@ $<
$(TEST_BIN): %: $(CRT) %.o $(LIBM) $(LIBC)
	$(LINK)
$(TS)/obj:
	$Qmkdir -p $@

-include $(TEST_OBJ:.o=.d)
