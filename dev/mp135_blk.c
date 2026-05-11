/*
 * STM32MP135 EVB block-device strategy routine.
 *
 * The bootloader's `load_sd` / `two` preamble stages root.img into
 * DDR at 0xC4400000 before jumping into the kernel.  Until a real
 * SD/eMMC driver lands (see "Real V7 SD/eMMC block driver" section
 * of missions/v7-real-kernel.md), this strategy routine satisfies
 * V7 block I/O by memcpy'ing between the V7 buffer cache and that
 * DDR window.  Writes mutate the DDR-resident image (no persistence
 * back to SD); harmless because no kernel caller writes through
 * bdevsw[0] in this sub-step.
 *
 * Behavior mirrors arch/armboot.c::bio() on EVB byte-for-byte so
 * that when a real V7 caller of bread() eventually lands, the data
 * returned is the same as today.
 */

#include "../h/param.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include "../h/proto.h"

/* Per-device buffer-list head.  bdevsw[].d_tab points here; V7
 * strategy routines hang their I/O active queue from this struct
 * buf.  Empty/unused in this sub-step. */
struct buf mp135_tab;

int
mp135_strategy(struct buf *bp)
{
	volatile unsigned char *ddr;
	unsigned int n;
	char *src, *dst;

	ddr = (volatile unsigned char *)(0xC4400000U +
	    (unsigned int)bp->b_blkno * (unsigned int)BSIZE);
	n = bp->b_bcount;
	if(bp->b_flags & B_READ) {
		src = (char *)ddr;
		dst = bp->b_un.b_addr;
	} else {
		src = bp->b_un.b_addr;
		dst = (char *)ddr;
	}
	while(n--)
		*dst++ = *src++;
	bp->b_resid = 0;
	iodone(bp);
	return 0;
}
