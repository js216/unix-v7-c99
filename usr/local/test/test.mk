TS = usr/local/test
TEST_BIN := $(patsubst $(TS)/utils/%.c,$(TS)/obj/%, \
	$(wildcard $(TS)/utils/*.c))
TEST_OBJ = $(TEST_BIN:%=%.o)
TEST_IMG = $(TS)/obj/fs.img $(TS)/obj/deep.img $(TS)/obj/many.img \
	$(TS)/obj/big.img
TEST_DATA := $(wildcard $(TS)/run.sh $(TS)/cases/* \
	$(filter-out %.c,$(wildcard $(TS)/utils/*)))

$(TEST_OBJ): CPPFLAGS = -Iusr/include -Iusr/sys
$(TEST_OBJ): $(TS)/test.mk
$(TEST_OBJ): $(TS)/obj/%.o: $(TS)/utils/%.c | $(TS)/obj
	$(COMPILE.c) -o $@ $<
PROF_BIN = $(TS)/obj/proft
$(PROF_BIN).o: CFLAGS += -pg
$(filter-out $(PROF_BIN),$(TEST_BIN)): %: $(CRT) %.o $(LIBM) $(LIBC)
	$(LINK)
$(PROF_BIN): %: $(MCRT) %.o $(LIBM) $(LIBC)
	$(call T,LD)$(CC) $(CFLAGS) -o $@ $(filter %.o %.a,$^) -lgcc
$(TS)/obj/fs.img: $(TS)/utils/fs.proto etc/mkfs etc/passwd etc/group \
    $(TS)/utils/words $(TS)/utils/long $(TS)/utils/sortin \
    $(TS)/utils/u2 | $(TS)/obj
	$(call T,MKFS)V7_MKFS_TIME=284774400 etc/mkfs $@ $< >/dev/null
$(TS)/obj/deep.img: etc/mkfs $(TS)/test.mk | $(TS)/obj
	$(call T,MKFS)awk 'BEGIN { print "/dev/null"; print "200 100"; \
	    print "d--755 0 0"; \
	    for (i = 0; i < 40; i++) \
		print "aaaaaaaaaaaaaa d--755 0 0"; \
	    for (i = 0; i <= 40; i++) print "$$" }' | \
	    V7_MKFS_TIME=284774400 etc/mkfs $@ /dev/stdin >/dev/null
$(TS)/obj/many.img: etc/mkfs $(TS)/test.mk | $(TS)/obj
	$(call T,MKFS)awk 'BEGIN { print "/dev/null"; \
	    print "5000 3010"; \
	    print "d--755 0 0"; \
	    for (i = 0; i < 3001; i++) { \
		print "d" i " d--755 0 0"; print "$$" } \
	    print "$$" }' | \
	    V7_MKFS_TIME=284774400 etc/mkfs $@ /dev/stdin >/dev/null
$(TS)/obj/big.img: etc/mkfs usr/dict/words $(TS)/test.mk | $(TS)/obj
	$(call T,MKFS)printf '%s\n' /dev/null '600 32' 'd--755 0 0' \
	    'words ---644 0 0 usr/dict/words' '$$' | \
	    V7_MKFS_TIME=284774400 etc/mkfs $@ /dev/stdin >/dev/null
$(TS)/obj:
	$Qmkdir -p $@

-include $(TEST_OBJ:.o=.d)
