: /bin/test_suite --- Unified V7 functional test suite
:
echo "--- START: USERLAND SMOKE ---"
pwd
ls /bin
cat /etc/passwd
wc /etc/passwd
echo "PID: OK"

echo "--- START: PIPES AND REDIRECTION ---"
echo hello | wc -c
cat /etc/passwd | grep root
echo "PIPESOK"

echo "--- START: TEXT PROCESSING ---"
grep root /etc/passwd
sort /etc/passwd
wc /usr/dict/words
echo "TEXTPROCOK"

echo "--- START: PROCESS CONTROL ---"
sleep 1 &
wait
echo "WAITOK"
echo "PROCOK"

echo "--- UNIT TESTS COMPLETE ---"
