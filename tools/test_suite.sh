: /bin/test_suite
:
echo "LS"
ls /
ls /etc
ls /tmp
ls /usr
ls /usr/lib
ls /usr/dict

echo "CD"
pwd
cd /tmp
pwd
cd /etc
pwd
cd /

echo "FILES"
echo data > /tmp/a
ls -l /tmp/a
cat /tmp/a
wc /tmp/a
cp /tmp/a /tmp/b
ls /tmp/a /tmp/b
mv /tmp/b /tmp/c
ls /tmp/c
chmod 644 /tmp/c
ls -l /tmp/c
chown root /tmp/c
chgrp 0 /tmp/c
file /tmp/a
du /tmp/a
sum /tmp/a
basename /usr/lib/diffh
rm /tmp/a /tmp/c

echo "MKDIR LN"
mkdir /tmp/d
ls -la /tmp
rmdir /tmp/d
ln /etc/passwd /tmp/pwlink
ls -li /etc/passwd /tmp/pwlink
rm /tmp/pwlink

echo "TEXT"
echo abcde | rev
echo ABC | tr A-Z a-z
echo aaa | uniq
echo abc | sum
echo abc | od -c
head /etc/passwd
tail /etc/passwd
grep root /etc/passwd
fgrep root /etc/passwd
sort /etc/passwd
look ro /usr/dict/words
echo abc | tee /tmp/teeout
cat /tmp/teeout
rm /tmp/teeout
sed s/x/y/ /etc/passwd
awk 1 /etc/passwd

echo "COMPARE"
cmp /etc/passwd /etc/passwd
diff /etc/passwd /etc/passwd
echo "a 1" > /tmp/j1
echo "a x" > /tmp/j2
join /tmp/j1 /tmp/j2
echo "a b" | tsort
rm /tmp/j1 /tmp/j2

echo "META"
ls -i /etc/passwd
ls -l /
tty
who
id
mesg

echo "CONVERT"
echo "hello world more" | sp
echo "main(){i=0;}" | cb
echo abc | dd count=1
echo hi | col
echo abc | pr

echo "PROC"
sleep 1 &
echo $!
wait
nice echo niced
sync
sleep 100 &
echo $!
kill $!
wait
ps
env
true
false

echo "VARS"
echo $$
echo $HOME
echo $PATH
echo $0
echo $?
sh -c 'echo $1 $2' x A B

echo "TEST"
test -f /etc/passwd
echo $?
test -d /etc
echo $?
test -f /nonexistent
echo $?
test -r /etc/passwd
echo $?

echo "FOR"
for i in 1 2 3
do
echo loop $i
done

echo "CASE"
case foo in
foo) echo matched;;
bar) echo bar;;
esac

echo "IF"
if test -f /etc/passwd
then
echo passwd_exists
fi

echo "EXPAND"
echo `echo backtick`
echo 'single quote'
echo "double quote"
expr 1 + 2

echo "GLOB"
ls /etc/p*
ls /b??

echo "ED"
ed /tmp/edtest << EOF
a
hello
world
.
w
q
EOF
cat /tmp/edtest
rm /tmp/edtest

echo "FIND"
find /usr/lib -print

echo "CAL"
cal 1 1970
cal 12 1969

echo "DF"
df

echo "UNIT TESTS COMPLETE"
