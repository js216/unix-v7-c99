cd /usr/local/test/cases
case $# in
0)	set `ls | grep -v '\.'`
esac
pass=0
fail=0
for n
do
	if test -f $n.sed
	then	d=`sh $n 2>&1 | sed -f $n.sed | (cmp - $n.exp 2>&1; cat >/dev/null)`
	else	d=`sh $n 2>&1 | (cmp - $n.exp 2>&1; cat >/dev/null)`
	fi
	case "$d" in
	"")	echo PASS $n
		pass=`expr $pass + 1`;;
	*)	echo FAIL $n
		fail=`expr $fail + 1`
	esac
done
echo run.sh: $pass passed, $fail failed
