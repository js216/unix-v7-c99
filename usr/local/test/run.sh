cd /usr/local/test/cases
case $# in
0)	set `ls | grep -v '\.'`
esac
pass=0
fail=0
for n
do
	if test -f $n.sed
	then	d=`sh $n 2>&1 | sed -f $n.sed | tee /tmp/run.out |
		    (cmp - $n.exp 2>&1; cat >/dev/null)`
	else	d=`sh $n 2>&1 | tee /tmp/run.out |
		    (cmp - $n.exp 2>&1; cat >/dev/null)`
	fi
	case "$d" in
	"")	echo PASS $n
		pass=`expr $pass + 1`;;
	*)	echo FAIL $n
		diff $n.exp /tmp/run.out | sed 20q
		fail=`expr $fail + 1`
	esac
	rm -f /tmp/run.out
done
echo run.sh: $pass passed, $fail failed
