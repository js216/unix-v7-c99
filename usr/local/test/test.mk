TS = usr/local/test
TEST_BIN := $(patsubst $(TS)/utils/%.c,$(TS)/obj/%,$(wildcard $(TS)/utils/*.c))
TEST_OBJ = $(TEST_BIN:%=%.o)
TEST_IMG = $(TS)/obj/fs.img
TEST_DATA := $(wildcard $(TS)/run.sh $(TS)/cases/* $(filter-out %.c,$(wildcard $(TS)/utils/*)))

$(TEST_OBJ): CPPFLAGS = -Iusr/include -Iusr/sys
$(TEST_OBJ): $(TS)/test.mk
$(TEST_OBJ): $(TS)/obj/%.o: $(TS)/utils/%.c | $(TS)/obj
	$(COMPILE.c) -o $@ $<
$(TEST_BIN): %: $(CRT) %.o $(LIBM) $(LIBC)
	$(LINK)
$(TEST_IMG): $(TS)/utils/fs.proto etc/mkfs etc/passwd etc/group \
    $(TS)/utils/words $(TS)/utils/long $(TS)/utils/sortin $(TS)/utils/u2 | $(TS)/obj
	$(call T,MKFS)V7_MKFS_TIME=284774400 etc/mkfs $@ $< >/dev/null
$(TS)/obj:
	$Qmkdir -p $@
