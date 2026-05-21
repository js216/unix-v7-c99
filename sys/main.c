#include "../h/param.h"
#include "../h/systm.h"
#include "../h/conf.h"
#include "../h/buf.h"
#include "../h/proto.h"

/*
 * Initialization code.  On this port the ARM-specific cold-start path
 * (arch/a7.s -> main() -> startup() -> armboot()) drives the actual
 * boot.  The v7 PDP-11 main body (manually set up proc[0], call
 * cinit/binit/iinit, fork the init process, jump to sched()) is replaced
 * by armboot()'s scheduler + ELF loader, so main() is now just glue.
 */
void
main(void)
{
	startup();
	armboot();
}

/*
 * This is the set of buffers proper, whose heads
 * were declared in buf.h.  There can exist buffer
 * headers not pointing here that are used purely
 * as arguments to the I/O routines to describe
 * I/O to be done-- e.g. swbuf for
 * swapping.
 */
char	buffers[NBUF][BSIZE+BSLOP];

/*
 * Initialize the buffer I/O system by freeing
 * all buffers and setting all device buffer lists to empty.
 */
void binit(void)
{
	register struct buf *bp;
	register struct buf *dp;
	register int i;
	struct bdevsw *bdp;

	bfreelist.b_forw = bfreelist.b_back =
	    bfreelist.av_forw = bfreelist.av_back = &bfreelist;
	for (i=0; i<NBUF; i++) {
		bp = &buf[i];
		bp->b_dev = NODEV;
		bp->b_un.b_addr = buffers[i];
		bp->b_back = &bfreelist;
		bp->b_forw = bfreelist.b_forw;
		bfreelist.b_forw->b_back = bp;
		bfreelist.b_forw = bp;
		bp->b_flags = B_BUSY;
		brelse(bp);
	}
	for (bdp = bdevsw; bdp->d_open; bdp++) {
		dp = bdp->d_tab;
		if(dp) {
			dp->b_forw = dp;
			dp->b_back = dp;
		}
		nblkdev++;
	}
}
