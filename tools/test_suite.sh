# /bin/test_suite --- Unified V7 functional test suite
#
# This script runs a representative set of V7 commands to verify
# kernel and userspace correctness. It is intended to produce
# identical (or nearly identical) output on Qemu and hardware.

echo "--- START: USERLAND SMOKE ---"
pwd
ls -F /bin | grep -E '^(sh|ls|cat|wc|echo)$'
cat /etc/passwd | grep root
wc -l /etc/passwd
echo "PID: OK"

echo "--- START: PIPES AND REDIRECTION ---"
echo hello | wc -c
cat /etc/passwd > /tmp/p
cmp /etc/passwd /tmp/p && echo "CMPOK"
(echo one; echo two) | tail -1
echo "PIPESOK"

echo "--- START: FILESYSTEM MUTATION ---"
mkdir /tmp/testdir
echo "hi" > /tmp/testdir/f
cat /tmp/testdir/f
ln /tmp/testdir/f /tmp/testdir/g
ls /tmp/testdir | sort
chmod 600 /tmp/testdir/f
ls -l /tmp/testdir/f | grep -q "rw-------" && echo "CHMODOK"
mv /tmp/testdir/g /tmp/testdir/h
rm /tmp/testdir/f /tmp/testdir/h
rmdir /tmp/testdir
echo "FSOK"

echo "--- START: TEXT PROCESSING ---"
grep root /etc/passwd | wc -l
tr a-z A-Z < /etc/passwd | head -1
sort /etc/passwd | uniq | wc -l
wc -l /usr/dict/words > /dev/null && echo "TEXTPROCOK"

echo "--- START: PROCESS CONTROL ---"
sleep 1 &
wait
echo "WAITOK"
(exit 7)
echo "RC=$?"
# time is a shell builtin in some sh, but V7 has /bin/time
/bin/time sleep 1 2>&1 | grep -q "real" && echo "TIMEOK"
echo "PROCOK"

echo "--- START: DD RAW I/O ---"
dd if=/etc/passwd of=/tmp/a bs=1 2>/dev/null
cmp /tmp/a /etc/passwd && echo "CMPA=0"
echo "DDOK"

echo "--- START: V7-ISMS ---"
# 14-char truncation
touch /tmp/aaaaaaaaaaaaaaa
ls /tmp/aaaaaaaaaaaaaa > /dev/null && echo "V7TRUNCOK"
rm /tmp/aaaaaaaaaaaaaa
# umask
umask 022
touch /tmp/u
ls -l /tmp/u | grep -q "rw-r--r--" && echo "V7UMASKOK"
rm /tmp/u
# $(...) literalness
echo '$(echo dollarparens)' | grep -q 'dollarparens' || echo "V7SHSYNTAXOK"
echo "V7ISMSOK"

echo "--- START: ED EDITOR ---"
ed /tmp/e <<'END'
a
one
two
three
.
2s/two/TWO/
3d
w
q
END
cat /tmp/e
rm /tmp/e
echo "EDOK"

echo "--- START: FIND SORT DIFF ---"
find /bin -type f | sort > /tmp/list1
ls /bin | sort > /tmp/list2
diff /tmp/list1 /tmp/list2 && echo "FINDSORTOK"
rm /tmp/list1 /tmp/list2

echo "--- UNIT TESTS COMPLETE ---"
