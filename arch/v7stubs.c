/*
 * Architecture stubs for the v7 buffer cache (sys/dev/bio.c).
 *
 * This file backs symbols that sys/dev/bio.c references but whose
 * V7 source we have not yet linked in: the UNIBUS map release
 * (mapfree), the sleep/wakeup/spl primitives (provided by sys/slp.c
 * in real V7), and the storage for the per-process user struct,
 * proc table, bfreelist, and bdevsw.
 *
 * They are intentionally minimal: the bio.c translation unit must
 * link, but it has no caller in this sub-step (arch/armboot.c::bio
 * still owns block I/O on hardware).  When real callers wire up,
 * these stubs are replaced by the real sys TUs.
 */

#include "../h/param.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/proto.h"

/* per-process user struct (referenced by physio() in dev/bio.c) */
struct user u;

/* head of available-buffer list */
struct buf bfreelist;

/* nulldev: V7 placeholder for unimplemented open/close on a bdevsw row */
int
nulldev(void)
{
	return 0;
}

/* block-device switch table: bdevsw[0] is the active block device for
 * this build (mp135 DDR-backed memcpy on EVB, virtio-blk on qemu).
 * The single empty trailing row terminates the table. */
#ifdef EVB
extern int mp135_strategy(struct buf *);
extern struct buf mp135_tab;
struct bdevsw bdevsw[2] = {
	{ nulldev, nulldev, mp135_strategy, &mp135_tab },
	{ 0, 0, 0, 0 }
};
#else
extern int virtio_strategy(struct buf *);
extern struct buf virtio_tab;
struct bdevsw bdevsw[2] = {
	{ nulldev, nulldev, virtio_strategy, &virtio_tab },
	{ 0, 0, 0, 0 }
};
#endif

/* UNIBUS map release: meaningless on Armv7, no-op */
void
mapfree(struct buf *bp)
{
	(void)bp;
}

/* V7 sleep/wakeup placeholders */
void
sleep(caddr_t chan, int pri)
{
	(void)chan;
	(void)pri;
}

void
wakeup(caddr_t chan)
{
	(void)chan;
}

/* V7 interrupt-priority-level primitives */
int
spl0(void)
{
	return 0;
}

int
spl6(void)
{
	return 0;
}

void
splx(int s)
{
	(void)s;
}
