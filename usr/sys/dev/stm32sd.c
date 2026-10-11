/*
 * RK disk driver
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"

#define	SD(off)	(*(volatile int *)(0xF0405000+(off)))
#define	NRK	4
#define	NRKBLK	458752

#define	RESET	0
#define	WCOM	24
#define	RCOM	17
#define	GO	0x1140
#define	DRESET	014
#define	IENABLE	0x800013f
#define	DRY	0200
#define	ARDY	0100
#define	WLO	020000
#define	CTLRDY	0200
#define	ARG	0x08
#define	CMD	0x0c
#define	DTIMER	0x24
#define	DLEN	0x28
#define	DCTRL	0x2c
#define	STA	0x34
#define	ICR	0x38
#define	MASK	0x3c
#define	IDMACTRL	0x50
#define	IDMABASER	0x58
#define	ERR	0x800003f
#define	DTDIR	02
#define	BLK512	0220
#define	CLEAR	0x1fe00fff

/*
 * Monitoring device bit
 */
#define	DK_N	1

void rkstart(void);
int	rkirq = 82;
struct	buf	rktab;
struct	buf	rrkbuf;
unsigned	rkoff;

void
rkinit(void)
{
	SD(DTIMER) = -1;
}

void
rkstrategy(register struct buf *bp)
{

	if (bp->b_blkno >= NRKBLK || bp->b_bcount&BMASK || (int)bp->b_un.b_addr&3) {
		bp->b_flags |= B_ERROR;
		iodone(bp);
		return;
	}
	bp->av_forw = (struct buf *)NULL;
	spl5();
	if(rktab.b_actf == NULL)
		rktab.b_actf = bp;
	else
		rktab.b_actl->av_forw = bp;
	rktab.b_actl = bp;
	if(rktab.b_active == NULL)
		rkstart();
	spl0();
}

void
rkstart(void)
{
	register struct buf *bp;
	register int com;

	if ((bp = rktab.b_actf) == NULL)
		return;
	rktab.b_active++;
	dcflush(bp->b_un.b_addr+rkoff, BSIZE);
	SD(ICR) = CLEAR;
	SD(DCTRL) = 0;
	SD(DLEN) = BSIZE;
	SD(DCTRL) = bp->b_flags&B_READ ? BLK512|DTDIR : BLK512;
	SD(IDMABASER) = vtop(bp->b_un.b_addr+rkoff);
	SD(IDMACTRL) = 1;
	SD(MASK) = IENABLE;
	SD(ARG) = bp->b_blkno+(rkoff>>BSHIFT);
	com = GO;
	if(bp->b_flags & B_READ)
		com |= RCOM; else
		com |= WCOM;
	SD(CMD) = com;
	dk_busy |= 1<<DK_N;
	dk_numb[DK_N] += 1;
	com = BSIZE>>6;
	dk_wds[DK_N] += com;
}

void
rkintr(void)
{
	register struct buf *bp;
	register int sta;

	sta = SD(STA);
	SD(ICR) = CLEAR;
	SD(MASK) = 0;
	SD(IDMACTRL) = 0;
	if (rktab.b_active == NULL)
		return;
	dk_busy &= ~(1<<DK_N);
	bp = rktab.b_actf;
	rktab.b_active = NULL;
	if (sta & ERR) {
		deverror(bp, sta, 0);
		if (++rktab.b_errcnt <= 10) {
			rkstart();
			return;
		}
		bp->b_flags |= B_ERROR;
	} else if ((rkoff += BSIZE) < bp->b_bcount) {
		rkstart();
		return;
	}
	rkoff = 0;
	if (bp->b_flags & B_READ)
		dcflush(bp->b_un.b_addr, bp->b_bcount);
	rktab.b_errcnt = 0;
	rktab.b_actf = bp->av_forw;
	bp->b_resid = 0;
	iodone(bp);
	rkstart();
}

void
rkread(dev_t dev)
{

	physio(rkstrategy, &rrkbuf, dev, B_READ);
}

void
rkwrite(dev_t dev)
{

	physio(rkstrategy, &rrkbuf, dev, B_WRITE);
}
