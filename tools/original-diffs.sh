#!/bin/sh
# Print "diff <v7-path> <port-path>" before each hunk so the
# ratchet verifier can attribute insertions/deletions per pair.
diff() { echo "diff $1 $2"; command diff "$1" "$2"; }

diff v7/usr/src/cmd/echo.c cmd/echo.c
diff v7/usr/src/cmd/cat.c cmd/cat.c
diff v7/usr/src/cmd/sync.c cmd/sync.c
diff v7/usr/src/cmd/rev.c cmd/rev.c
diff v7/usr/src/cmd/yes.c cmd/yes.c
diff v7/usr/src/cmd/wc.c cmd/wc.c
diff v7/usr/src/cmd/basename.c cmd/basename.c
diff v7/usr/src/cmd/sum.c cmd/sum.c
diff v7/usr/src/cmd/tty.c cmd/tty.c
diff v7/usr/src/cmd/cmp.c cmd/cmp.c
diff v7/usr/src/cmd/pwd.c cmd/pwd.c
diff v7/usr/src/cmd/comm.c cmd/comm.c
diff v7/usr/src/cmd/cal.c cmd/cal.c
diff v7/usr/src/cmd/od.c cmd/od.c
diff v7/usr/src/cmd/tail.c cmd/tail.c
diff v7/usr/src/cmd/grep.c cmd/grep.c
diff v7/usr/src/cmd/test.c cmd/test.c
diff v7/usr/src/cmd/look.c cmd/look.c
diff v7/usr/src/cmd/cp.c cmd/cp.c
diff v7/usr/src/cmd/rm.c cmd/rm.c
diff v7/usr/src/cmd/ln.c cmd/ln.c
diff v7/usr/src/cmd/mkdir.c cmd/mkdir.c
diff v7/usr/src/cmd/rmdir.c cmd/rmdir.c
diff v7/usr/src/cmd/mv.c cmd/mv.c
diff v7/usr/src/cmd/chmod.c cmd/chmod.c
diff v7/usr/src/cmd/chown.c cmd/chown.c
diff v7/usr/src/cmd/chgrp.c cmd/chgrp.c
diff v7/usr/src/cmd/sleep.c cmd/sleep.c
diff v7/usr/src/cmd/tee.c cmd/tee.c
diff v7/usr/src/cmd/touch.c cmd/touch.c
diff v7/usr/src/cmd/tr.c cmd/tr.c
diff v7/usr/src/cmd/uniq.c cmd/uniq.c
diff v7/usr/src/cmd/du.c cmd/du.c
diff v7/usr/src/cmd/date.c cmd/date.c
diff v7/usr/src/cmd/kill.c cmd/kill.c
diff v7/usr/src/cmd/nice.c cmd/nice.c
diff v7/usr/src/cmd/mknod.c cmd/mknod.c
diff v7/usr/src/cmd/who.c cmd/who.c
diff v7/usr/src/cmd/mesg.c cmd/mesg.c
diff v7/usr/src/cmd/time.c cmd/time.c
diff v7/usr/src/cmd/split.c cmd/split.c
diff v7/usr/src/cmd/checkeq.c cmd/checkeq.c
diff v7/usr/src/cmd/calendar.c cmd/calendar.c
diff v7/usr/src/cmd/tsort.c cmd/tsort.c
diff v7/usr/src/cmd/file.c cmd/file.c
diff v7/usr/src/cmd/join.c cmd/join.c
diff v7/usr/src/cmd/col.c cmd/col.c
diff v7/usr/src/cmd/fgrep.c cmd/fgrep.c
diff v7/usr/src/cmd/su.c cmd/su.c
diff v7/usr/src/cmd/newgrp.c cmd/newgrp.c
diff v7/usr/src/cmd/random.c cmd/random.c
diff v7/usr/src/cmd/crypt.c cmd/crypt.c
diff v7/usr/src/cmd/makekey.c cmd/makekey.c
diff v7/usr/src/cmd/diffh.c cmd/diffh.c
diff v7/usr/src/cmd/pr.c cmd/pr.c
diff v7/usr/src/cmd/dd.c cmd/dd.c
diff v7/usr/src/cmd/stty.c cmd/stty.c
diff v7/usr/src/cmd/tabs.c cmd/tabs.c
diff v7/usr/src/cmd/diff.c cmd/diff.c
diff v7/usr/src/cmd/wall.c cmd/wall.c
diff v7/usr/src/cmd/write.c cmd/write.c
diff v7/usr/src/cmd/df.c cmd/df.c
diff v7/usr/src/cmd/clri.c cmd/clri.c
diff v7/usr/src/cmd/dcheck.c cmd/dcheck.c
diff v7/usr/src/cmd/icheck.c cmd/icheck.c
diff v7/usr/src/cmd/ncheck.c cmd/ncheck.c
diff v7/usr/src/cmd/cb.c cmd/cb.c
diff v7/usr/src/cmd/sp.c cmd/sp.c
diff v7/usr/src/cmd/find.c cmd/find.c
diff v7/usr/src/cmd/sort.c cmd/sort.c
diff v7/usr/src/cmd/ed.c cmd/ed.c
diff v7/usr/src/libc/gen/crypt.c lib/crypt.c
diff v7/usr/src/libc/gen/l3.c lib/l3.c
diff v7/usr/include/sys/param.h include/sys/param.h
diff v7/usr/include/sys/inode.h include/sys/inode.h
diff v7/usr/include/sys/filsys.h include/sys/filsys.h
diff v7/usr/include/sys/fblk.h include/sys/fblk.h
diff v7/usr/include/sys/ino.h include/sys/ino.h
diff v7/usr/include/sgtty.h include/sgtty.h
diff v7/usr/sys/h/acct.h h/acct.h
diff v7/usr/sys/h/callo.h h/callo.h
diff v7/usr/sys/h/conf.h h/conf.h
diff v7/usr/sys/h/fblk.h h/fblk.h
diff v7/usr/sys/h/file.h h/file.h
diff v7/usr/sys/h/filsys.h h/filsys.h
diff v7/usr/sys/h/ino.h h/ino.h
diff v7/usr/sys/h/mount.h h/mount.h
diff v7/usr/sys/h/mpx.h h/mpx.h
diff v7/usr/sys/h/mx.h h/mx.h
diff v7/usr/sys/h/pack.h h/pack.h
diff v7/usr/sys/h/pk.h h/pk.h
diff v7/usr/sys/h/prim.h h/prim.h
diff v7/usr/sys/h/pwd.h h/pwd.h
diff v7/usr/sys/h/reg.h h/reg.h
diff v7/usr/sys/h/seg.h h/seg.h
diff v7/usr/sys/h/smallparam.h h/smallparam.h
diff v7/usr/sys/h/stat.h h/stat.h
diff v7/usr/sys/h/systm.h h/systm.h
diff v7/usr/sys/h/text.h h/text.h
diff v7/usr/sys/h/timeb.h h/timeb.h
diff v7/usr/sys/h/tty.h h/tty.h
diff v7/usr/sys/h/types.h h/types.h
diff v7/usr/sys/sys/acct.c sys/acct.c
diff v7/usr/sys/sys/alloc.c sys/alloc.c
diff v7/usr/sys/sys/clock.c sys/clock.c
diff v7/usr/sys/sys/fakemx.c sys/fakemx.c
diff v7/usr/sys/sys/fio.c sys/fio.c
diff v7/usr/sys/sys/iget.c sys/iget.c
diff v7/usr/sys/sys/machdep.c sys/machdep.c
diff v7/usr/sys/sys/nami.c sys/nami.c
diff v7/usr/sys/sys/pipe.c sys/pipe.c
diff v7/usr/sys/sys/rdwri.c sys/rdwri.c
diff v7/usr/sys/sys/sig.c sys/sig.c
diff v7/usr/sys/sys/subr.c sys/subr.c
diff v7/usr/sys/sys/sys1.c sys/sys1.c
diff v7/usr/sys/sys/sys2.c sys/sys2.c
diff v7/usr/sys/sys/sys3.c sys/sys3.c
diff v7/usr/sys/sys/sys4.c sys/sys4.c
diff v7/usr/sys/sys/sysent.c sys/sysent.c
diff v7/usr/sys/sys/text.c sys/text.c
diff v7/usr/sys/sys/trap.c sys/trap.c
diff v7/usr/sys/sys/ureg.c sys/ureg.c
diff v7/usr/sys/dev/bio.c dev/bio.c
diff v7/usr/sys/dev/cat.c dev/cat.c
diff v7/usr/sys/dev/dc.c dev/dc.c
diff v7/usr/sys/dev/dh.c dev/dh.c
diff v7/usr/sys/dev/dhdm.c dev/dhdm.c
diff v7/usr/sys/dev/dhfdm.c dev/dhfdm.c
diff v7/usr/sys/dev/dkleave.c dev/dkleave.c
diff v7/usr/sys/dev/dn.c dev/dn.c
diff v7/usr/sys/dev/dsort.c dev/dsort.c
diff v7/usr/sys/dev/du.c dev/du.c
diff v7/usr/sys/dev/dz.c dev/dz.c
diff v7/usr/sys/dev/hp.c dev/hp.c
diff v7/usr/sys/dev/ht.c dev/ht.c
diff v7/usr/sys/dev/kl.c dev/kl.c
diff v7/usr/sys/dev/mem.c dev/mem.c
diff v7/usr/sys/dev/mx1.c dev/mx1.c
diff v7/usr/sys/dev/mx2.c dev/mx2.c
diff v7/usr/sys/dev/partab.c dev/partab.c
diff v7/usr/sys/dev/pk0.c dev/pk0.c
diff v7/usr/sys/dev/pk1.c dev/pk1.c
diff v7/usr/sys/dev/pk2.c dev/pk2.c
diff v7/usr/sys/dev/pk3.c dev/pk3.c
diff v7/usr/sys/dev/rf.c dev/rf.c
diff v7/usr/sys/dev/rk.c dev/rk.c
diff v7/usr/sys/dev/rl.c dev/rl.c
diff v7/usr/sys/dev/rp.c dev/rp.c
diff v7/usr/sys/dev/sys.c dev/sys.c
diff v7/usr/sys/dev/tc.c dev/tc.c
diff v7/usr/sys/dev/tm.c dev/tm.c
diff v7/usr/sys/dev/tty.c dev/tty.c
diff v7/usr/sys/dev/vp.c dev/vp.c
diff v7/usr/sys/dev/vs.c dev/vs.c

# cmd/ (added by the iter-2 ratchet seeding)
diff v7/usr/src/cmd/getty.c cmd/getty.c
diff v7/usr/src/cmd/init.c cmd/init.c
diff v7/usr/src/cmd/login.c cmd/login.c
diff v7/usr/src/cmd/ls.c cmd/ls.c
diff v7/usr/src/cmd/sh/args.c cmd/sh/args.c
diff v7/usr/src/cmd/sh/blok.c cmd/sh/blok.c
diff v7/usr/src/cmd/sh/brkincr.h cmd/sh/brkincr.h
diff v7/usr/src/cmd/sh/builtin.c cmd/sh/builtin.c
diff v7/usr/src/cmd/sh/cmd.c cmd/sh/cmd.c
diff v7/usr/src/cmd/sh/ctype.c cmd/sh/ctype.c
diff v7/usr/src/cmd/sh/ctype.h cmd/sh/ctype.h
diff v7/usr/src/cmd/sh/defs.h cmd/sh/defs.h
diff v7/usr/src/cmd/sh/dup.h cmd/sh/dup.h
diff v7/usr/src/cmd/sh/error.c cmd/sh/error.c
diff v7/usr/src/cmd/sh/expand.c cmd/sh/expand.c
diff v7/usr/src/cmd/sh/fault.c cmd/sh/fault.c
diff v7/usr/src/cmd/sh/io.c cmd/sh/io.c
diff v7/usr/src/cmd/sh/mac.h cmd/sh/mac.h
diff v7/usr/src/cmd/sh/macro.c cmd/sh/macro.c
diff v7/usr/src/cmd/sh/main.c cmd/sh/main.c
diff v7/usr/src/cmd/sh/mode.h cmd/sh/mode.h
diff v7/usr/src/cmd/sh/msg.c cmd/sh/msg.c
diff v7/usr/src/cmd/sh/name.c cmd/sh/name.c
diff v7/usr/src/cmd/sh/name.h cmd/sh/name.h
diff v7/usr/src/cmd/sh/print.c cmd/sh/print.c
diff v7/usr/src/cmd/sh/service.c cmd/sh/service.c
diff v7/usr/src/cmd/sh/setbrk.c cmd/sh/setbrk.c
diff v7/usr/src/cmd/sh/stak.c cmd/sh/stak.c
diff v7/usr/src/cmd/sh/stak.h cmd/sh/stak.h
diff v7/usr/src/cmd/sh/string.c cmd/sh/string.c
diff v7/usr/src/cmd/sh/sym.h cmd/sh/sym.h
diff v7/usr/src/cmd/sh/timeout.h cmd/sh/timeout.h
diff v7/usr/src/cmd/sh/word.c cmd/sh/word.c
diff v7/usr/src/cmd/sh/xec.c cmd/sh/xec.c

# conf/ (added by the iter-2 ratchet seeding)
diff v7/usr/sys/conf/c.c conf/c.c
diff v7/usr/src/libc/stdio/putchar.c conf/putchar.c

# h/ (added by the iter-2 ratchet seeding)
diff v7/usr/sys/h/buf.h h/buf.h
diff v7/usr/sys/h/dir.h h/dir.h
diff v7/usr/sys/h/inode.h h/inode.h
diff v7/usr/sys/h/map.h h/map.h
diff v7/usr/sys/h/param.h h/param.h
diff v7/usr/sys/h/proc.h h/proc.h
diff v7/usr/sys/h/user.h h/user.h

# include/ (added by the iter-2 ratchet seeding)
diff v7/usr/include/ctype.h include/ctype.h
diff v7/usr/include/errno.h include/errno.h
diff v7/usr/include/execargs.h include/execargs.h
diff v7/usr/include/grp.h include/grp.h
diff v7/usr/include/pwd.h include/pwd.h
diff v7/usr/include/setjmp.h include/setjmp.h
diff v7/usr/include/signal.h include/signal.h
diff v7/usr/include/stdio.h include/stdio.h
diff v7/usr/include/sys/dir.h include/sys/dir.h
diff v7/usr/include/sys/stat.h include/sys/stat.h
diff v7/usr/include/sys/timeb.h include/sys/timeb.h
diff v7/usr/include/sys/times.h include/sys/times.h
diff v7/usr/include/sys/types.h include/sys/types.h
diff v7/usr/include/time.h include/time.h
diff v7/usr/include/utmp.h include/utmp.h

# lib/ (added by the iter-2 ratchet seeding)
diff v7/usr/src/libc/csu/crt0.s lib/crt0.s
diff v7/usr/src/libc/v6/syscall.s lib/syscall.s

# sys/ (added by the iter-2 ratchet seeding)
diff v7/usr/sys/sys/main.c sys/main.c
diff v7/usr/sys/sys/malloc.c sys/malloc.c
diff v7/usr/sys/sys/prf.c sys/prf.c
diff v7/usr/sys/sys/prim.c sys/prim.c
diff v7/usr/sys/sys/slp.c sys/slp.c

# tools/ (added by the iter-2 ratchet seeding)
diff v7/usr/src/cmd/mkfs.c tools/mkfs.c

# cmd/ (added by the mount/umount userland)
diff v7/usr/src/cmd/mount.c cmd/mount.c
diff v7/usr/src/cmd/umount.c cmd/umount.c

# lib/ (real ports of v7's libc/stdio + libc/gen helpers)
diff v7/usr/src/libc/stdio/getpwent.c lib/getpwent.c
diff v7/usr/src/libc/stdio/getpwnam.c lib/getpwnam.c
diff v7/usr/src/libc/stdio/getpwuid.c lib/getpwuid.c
diff v7/usr/src/libc/gen/strncat.c lib/strncat.c
diff v7/usr/src/libc/gen/ttyslot.c lib/ttyslot.c
diff v7/usr/src/libc/gen/execvp.c lib/execvp.c
diff v7/usr/src/libc/gen/getenv.c lib/getenv.c
diff v7/usr/src/libc/gen/atoi.c lib/atoi.c
diff v7/usr/src/libc/gen/atol.c lib/atol.c
diff v7/usr/src/libc/gen/abs.c lib/abs.c
diff v7/usr/src/libc/gen/index.c lib/index.c
diff v7/usr/src/libc/gen/rindex.c lib/rindex.c
diff v7/usr/src/libc/gen/strcat.c lib/strcat.c
diff v7/usr/src/libc/gen/strcmp.c lib/strcmp.c
diff v7/usr/src/libc/gen/strcpy.c lib/strcpy.c
diff v7/usr/src/libc/gen/strlen.c lib/strlen.c
diff v7/usr/src/libc/gen/strncmp.c lib/strncmp.c
diff v7/usr/src/libc/gen/strncpy.c lib/strncpy.c
diff v7/usr/src/libc/gen/isatty.c lib/isatty.c
diff v7/usr/src/libc/gen/perror.c lib/perror.c
diff v7/usr/src/libc/gen/swab.c lib/swab.c
diff v7/usr/src/libc/gen/rand.c lib/rand.c
diff v7/usr/src/libc/gen/mktemp.c lib/mktemp.c
diff v7/usr/src/libc/gen/errlst.c lib/errlst.c
diff v7/usr/src/libc/gen/ttyname.c lib/ttyname.c

# include/ (real port of v7's errno.h, with a small port-side
# helper-prototype block at the bottom; see file comment).
diff v7/usr/include/errno.h include/errno.h
exit 0
