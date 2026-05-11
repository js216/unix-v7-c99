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

/* Root device.  Real V7 callers (bread, mount, etc.) pass this as the
 * dev_t argument to walk bdevsw[major(rootdev)].  major(0)==0, so this
 * resolves to bdevsw[0], which is mp135_strategy on EVB and
 * virtio_strategy on qemu.  Picked up at link time by sys/main.c and
 * dev/bio.c (both #include "../h/systm.h", which declares it tentatively). */
dev_t rootdev = 0;

/* Number of block-device switch entries actually populated above.
 * Required by getblk() to range-check major(dev) before dispatching.
 * Tentatively declared in systm.h; here we give it the strong
 * initialiser the buffer cache needs. */
int nblkdev = 1;

/* Buffer-cache storage: NBUF entries each owning BSIZE+BSLOP bytes
 * of payload.  Real V7 declares `buf[]` in conf/c.c and `buffers[][]`
 * in sys/main.c's binit; we collapse both here as link-time storage.
 * `binit_stub()` below links them onto bfreelist. */
struct buf buf[NBUF];
static char buffers[NBUF][BSIZE+BSLOP];

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

/* Minimal V7-style buffer-cache init.  Mirrors sys/main.c::binit()'s
 * historic body: makes bfreelist a circular doubly-linked list with
 * every buf[] entry hung off it via av_forw/av_back, each buf pointing
 * at its BSIZE+BSLOP payload, and primes each bdevsw d_tab as an empty
 * self-loop.  Called by arch/machdep.c::startup() before the sentinel
 * bread().  This stub-side helper exists because sys/main.c's V7 binit
 * is still #if 0'd; when that body comes back online, this routine
 * goes away. */
void
binit_stub(void)
{
	struct buf *bp;
	int i;

	bfreelist.b_forw = bfreelist.b_back =
	    bfreelist.av_forw = bfreelist.av_back = &bfreelist;
	for (i = 0; i < NBUF; i++) {
		bp = &buf[i];
		bp->b_dev = (dev_t)NODEV;
		bp->b_un.b_addr = buffers[i];
		bp->b_back = &bfreelist;
		bp->b_forw = bfreelist.b_forw;
		bfreelist.b_forw->b_back = bp;
		bfreelist.b_forw = bp;
		bp->av_back = &bfreelist;
		bp->av_forw = bfreelist.av_forw;
		bfreelist.av_forw->av_back = bp;
		bfreelist.av_forw = bp;
		bp->b_flags = 0;
	}
	/* Initialise every bdevsw entry's d_tab as an empty self-loop. */
#ifdef EVB
	mp135_tab.b_forw = &mp135_tab;
	mp135_tab.b_back = &mp135_tab;
#else
	virtio_tab.b_forw = &virtio_tab;
	virtio_tab.b_back = &virtio_tab;
#endif
}

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
