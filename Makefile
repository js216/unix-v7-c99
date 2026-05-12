ROOT = root/etc/init root/etc/getty root/bin/login root/bin/sh \
	root/bin/cat root/bin/echo root/bin/ls root/bin/pwd root/bin/sync \
	root/bin/rev root/bin/yes root/bin/wc root/bin/basename root/bin/sum \
	root/bin/tty root/bin/cmp root/bin/comm root/bin/cal root/bin/od \
	root/bin/tail root/bin/grep root/bin/test root/bin/look root/bin/cp \
	root/bin/rm root/bin/ln root/bin/mkdir root/bin/rmdir root/bin/mv \
	root/bin/chmod root/bin/chown root/bin/chgrp root/bin/sleep \
	root/bin/tee root/bin/touch root/bin/tr root/bin/uniq root/bin/du \
	root/bin/date root/bin/kill root/bin/nice root/bin/mknod root/bin/who \
	root/bin/mesg root/bin/time root/bin/split root/bin/checkeq \
	root/bin/calendar root/bin/tsort root/bin/file root/bin/join root/bin/col \
	root/bin/fgrep root/bin/su root/bin/newgrp root/bin/random root/bin/crypt \
	root/bin/pr root/bin/dd root/bin/stty root/bin/tabs root/bin/diff \
	root/bin/wall root/bin/write root/bin/df root/bin/clri \
	root/bin/dcheck root/bin/icheck root/bin/ncheck \
	root/bin/cb root/bin/sp root/bin/find root/bin/sort root/bin/ed \
	root/bin/mount root/bin/umount root/bin/id \
	root/bin/test_suite \
	root/usr/lib/makekey root/usr/lib/diffh \
	root/etc/passwd root/etc/ttys root/usr/dict/words \
	build/auxfs.img

all:	unix

unix:	root.img sys/*.c arch/*.c arch/*.s arch/*.ld dev/*.c h/*.h
	cd sys; make unix

qemu:	unix
	qemu-system-arm -machine virt -cpu cortex-a7 -nographic -kernel unix -drive if=none,file=root.img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

root.img: Makefile tools/mkfs cmd/*.c cmd/sh/* lib/*.c lib/*.s lib/*.h lib/Makefile lib/u.ld root/etc/passwd root/etc/ttys build/auxfs.img
	cd lib; make
	tools/mkfs root.img \
	/etc/init=root/etc/init /etc/getty=root/etc/getty \
	/etc/auxfs=build/auxfs.img \
	/bin/mount=root/bin/mount /bin/umount=root/bin/umount /bin/id=root/bin/id \
	/bin/test_suite=tools/test_suite.sh \
	/bin/login=root/bin/login /bin/sh=root/bin/sh \
	/bin/cat=root/bin/cat /bin/echo=root/bin/echo \
	/bin/ls=root/bin/ls /bin/pwd=root/bin/pwd /bin/sync=root/bin/sync \
	/bin/rev=root/bin/rev /bin/yes=root/bin/yes /bin/wc=root/bin/wc \
	/bin/basename=root/bin/basename /bin/sum=root/bin/sum \
	/bin/tty=root/bin/tty /bin/cmp=root/bin/cmp /bin/comm=root/bin/comm \
	/bin/cal=root/bin/cal /bin/od=root/bin/od /bin/tail=root/bin/tail \
	/bin/grep=root/bin/grep /bin/test=root/bin/test /bin/[=root/bin/test \
	/bin/look=root/bin/look /bin/cp=root/bin/cp /bin/rm=root/bin/rm \
	/bin/ln=root/bin/ln /bin/mkdir=root/bin/mkdir /bin/rmdir=root/bin/rmdir \
	/bin/mv=root/bin/mv \
	/bin/chmod=root/bin/chmod /bin/chown=root/bin/chown /bin/chgrp=root/bin/chgrp \
	/bin/sleep=root/bin/sleep /bin/tee=root/bin/tee /bin/touch=root/bin/touch \
	/bin/tr=root/bin/tr /bin/uniq=root/bin/uniq /bin/du=root/bin/du \
	/bin/date=root/bin/date /bin/kill=root/bin/kill /bin/nice=root/bin/nice \
	/bin/mknod=root/bin/mknod /bin/who=root/bin/who /bin/mesg=root/bin/mesg \
	/bin/time=root/bin/time /bin/split=root/bin/split \
	/bin/checkeq=root/bin/checkeq /bin/calendar=root/bin/calendar \
	/bin/tsort=root/bin/tsort /bin/file=root/bin/file /bin/join=root/bin/join \
	/bin/col=root/bin/col /bin/fgrep=root/bin/fgrep \
	/bin/su=root/bin/su /bin/newgrp=root/bin/newgrp /bin/random=root/bin/random \
	/bin/crypt=root/bin/crypt /bin/pr=root/bin/pr /bin/dd=root/bin/dd \
	/bin/stty=root/bin/stty /bin/tabs=root/bin/tabs /bin/diff=root/bin/diff \
	/bin/wall=root/bin/wall /bin/write=root/bin/write /bin/df=root/bin/df \
	/bin/clri=root/bin/clri /bin/dcheck=root/bin/dcheck \
	/bin/icheck=root/bin/icheck /bin/ncheck=root/bin/ncheck \
	/bin/cb=root/bin/cb /bin/sp=root/bin/sp /bin/find=root/bin/find \
	/bin/sort=root/bin/sort /bin/ed=root/bin/ed \
	/usr/lib/makekey=root/usr/lib/makekey /usr/lib/diffh=root/usr/lib/diffh \
	/etc/passwd=root/etc/passwd /etc/ttys=root/etc/ttys \
	/etc/utmp=/dev/null \
	/dev/null=/dev/null \
	/usr/dict/words=root/usr/dict/words \
	/tmp/.keep=/dev/null

tools/mkfs: tools/mkfs.c
	cc -std=c99 -Wall -Wextra -Wpedantic -Werror -o tools/mkfs tools/mkfs.c

# A pocket-sized mkfs builds the /etc/auxfs filesystem-in-a-file used
# by the icheck/dcheck/ncheck mission step; FSSIZE/ISIZE are dialed
# down so the embedded image fits inside the host-built root.img
# without exhausting its 4096-block budget.
tools/minimkfs: tools/mkfs.c
	cc -std=c99 -Wall -Wextra -Wpedantic -Werror \
	    -DFSSIZE=64 -DISIZE=2 -DMAXINO=16 -DMAXBLK=64 \
	    -o tools/minimkfs tools/mkfs.c

build/auxfs.img: tools/minimkfs root/etc/passwd
	mkdir -p build
	tools/minimkfs build/auxfs.img /a=root/etc/passwd

root/usr/dict/words: v7/usr/dict/words
	mkdir -p root/usr/dict
	cp v7/usr/dict/words root/usr/dict/words

clean:
	cd sys; make clean
	cd lib; make clean
	rm -f unix root.img tools/mkfs
