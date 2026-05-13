: /bin/test_suite --- Unified V7 functional test suite
:
echo "USERLAND SMOKE"
pwd
ls /bin/cal
cat /etc/passwd
wc /etc/passwd

echo "MAKING DIRECTORIES AND FILES"
cd /
mkdir home
cd home
touch file
ls -l file

echo "PIPES AND REDIRECTION"
echo hello | wc -c
cat /etc/passwd | grep root

echo "TEXT PROCESSING"
grep root /etc/passwd
sort /etc/passwd
wc /usr/dict/words

echo "PROCESS CONTROL"
sleep 1 &
wait

echo "UNIT TESTS COMPLETE"
