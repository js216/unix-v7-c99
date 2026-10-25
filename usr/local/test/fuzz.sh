: sh fuzz.sh [seed]: the fuzzers, for ever.  Each round runs three
: file system fuzzers at once, in directories of their own, beside the
: process fuzzer and the command checks, then checks the root file
: system with icheck and dcheck.  Each line printed is a result, a FAIL
: line with the seed which repeats it, or the summary of a round.
U=/usr/local/test/utils
T=/tmp/fz
s=${1-1}
r=0
while :
do
	rm -rf $T
	mkdir $T $T/1 $T/2 $T/3 $T/sh
	for i in 1 2 3
	do
		mkdir $T/$i/d0 $T/$i/d1
	done
	(cd $T/1; $U/fzfs $s 300) &
	(cd $T/2; $U/fzfs `expr $s + 1` 300) &
	(cd $T/3; $U/fzfs `expr $s + 2` 300) &
	$U/fzproc `expr $s + 3` 10 &
	(cd $T/sh; sh $U/fzsh `expr $s + 4`)
	wait
	cd /
	rm -rf $T
	sync
	icheck /dev/root >/tmp/fz.ic 2>&1
	sed -e 1d -e '/^files /d' -e '/^used /d' -e '/^free /d' \
	    -e '/^missing *0$/d' /tmp/fz.ic >/tmp/fz.x
	test -s /tmp/fz.x && { echo FAIL icheck after seed $s; cat /tmp/fz.x; }
	dcheck /dev/root >/tmp/fz.ic 2>&1
	sed -e 1d -e '/^ *entries *link cnt$/d' /tmp/fz.ic >/tmp/fz.x
	test -s /tmp/fz.x && { echo FAIL dcheck after seed $s; cat /tmp/fz.x; }
	rm -f /tmp/fz.ic /tmp/fz.x
	r=`expr $r + 1`
	echo fuzz round $r seeds $s-`expr $s + 4` done
	s=`expr $s + 5`
done
