: sh fuzz.sh [seed]: the fuzzers, for ever.  Each round has two
: phases.  In the first, three file system fuzzers, the filler which
: runs the disk out of space and inodes, random system calls, mutated
: programs, and the C library against references run at once.  In the second, the process fuzzer,
: the command checks, and more memory than RAM.
: The root file system is then checked with icheck and dcheck.  Each
: line printed is a result, a FAIL line with the seed which repeats
: it, or the summary of a round.
:
: sh fuzz.sh -b [seed]: the mode for the board, which writes nothing to the
: SD card but the inode times an idle system writes too.  It runs
: fzboard, which see.
U=/usr/local/test/utils
T=/tmp/fz
case $1 in
-b)	shift; exec $U/fzboard ${1-1}
esac
s=${1-1}
r=0
while :
do
	rm -rf $T
	mkdir $T $T/1 $T/2 $T/3 $T/sh $T/sys $T/elf $T/fill
	chmod 777 $T/sys $T/elf
	for i in 1 2 3
	do
		mkdir $T/$i/d0 $T/$i/d1
	done
	(cd $T/1; $U/fzfs $s 400) &
	(cd $T/2; $U/fzfs `expr $s + 1` 400) &
	(cd $T/3; $U/fzfs `expr $s + 2` 400) &
	(cd $T/fill; $U/fzfill `expr $s + 3` 1) &
	$U/fzsys `expr $s + 4` 40 &
	$U/fzlib `expr $s + 9` 1 &
	$U/fzelf `expr $s + 5` 80
	wait
	$U/fzproc `expr $s + 6` 10 &
	$U/fzmem `expr $s + 7` 5 80 &
	(cd $T/sh; sh $U/fzsh `expr $s + 8`)
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
	test -s /tmp/fz.x && { echo FAIL dcheck after seed $s; cat /tmp/fz.x; ps alx; }
	rm -f /tmp/fz.ic /tmp/fz.x
	r=`expr $r + 1`
	echo fuzz round $r seeds $s-`expr $s + 9` done
	s=`expr $s + 10`
done
