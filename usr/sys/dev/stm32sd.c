/*
 * RK disk driver
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"

void rkstart(void);

#define	SD(off)	(*(volatile int *)(0x58005000+(off)))
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

#define	WCOM	24
#define	RCOM	17
#define	GO	0x1140
#define	IENABLE	0x12a
#define	ERR	0x2a
#define	DTDIR	02
#define	BLK512	0220
#define	CLEAR	0x1fe00fff

/*
 * Monitoring device bit
 */
#define	DK_N	1

int	sdirq = 82;
struct	buf	sdtab;
struct	buf	rrkbuf;

void
sdinit(void)
{
	SD(DTIMER) = -1;
}

void
sdstrategy(register struct buf *bp)
{
	int s;

	bp->av_forw = NULL;
	s = spl5();
	if (sdtab.b_actf == NULL)
		sdtab.b_actf = bp;
	else
		sdtab.b_actl->av_forw = bp;
	sdtab.b_actl = bp;
	if(sdtab.b_active == NULL)
		rkstart();
	splx(s);
}

void
rkstart(void)
{
	register struct buf *bp;
	register int com;

	if ((bp = sdtab.b_actf) == NULL)
		return;
	sdtab.b_active++;
	dcflush(bp->b_un.b_addr, bp->b_bcount);
	SD(ICR) = CLEAR;
	SD(DCTRL) = 0;
	SD(DLEN) = bp->b_bcount;
	SD(DCTRL) = bp->b_flags&B_READ ? BLK512|DTDIR : BLK512;
	SD(IDMABASER) = (int)bp->b_un.b_addr;
	SD(IDMACTRL) = 1;
	SD(MASK) = IENABLE;
	SD(ARG) = bp->b_blkno;
	com = GO;
	if(bp->b_flags & B_READ)
		com |= RCOM; else
		com |= WCOM;
	SD(CMD) = com;
	dk_busy |= 1<<DK_N;
	dk_numb[DK_N] += 1;
	com = bp->b_bcount>>6;
	dk_wds[DK_N] += com;
}

void
sdintr(void)
{
	register struct buf *bp;
	register int sta;

	sta = SD(STA);
	SD(ICR) = CLEAR;
	SD(MASK) = 0;
	SD(IDMACTRL) = 0;
	if (sdtab.b_active == NULL)
		return;
	dk_busy &= ~(1<<DK_N);
	bp = sdtab.b_actf;
	sdtab.b_active = NULL;
	if (sta & ERR) {
		deverror(bp, sta, 0);
		if (++sdtab.b_errcnt <= 10) {
			rkstart();
			return;
		}
		bp->b_flags |= B_ERROR;
	}
	if (bp->b_flags & B_READ)
		dcflush(bp->b_un.b_addr, bp->b_bcount);
	sdtab.b_errcnt = 0;
	sdtab.b_actf = bp->av_forw;
	bp->b_resid = 0;
	iodone(bp);
	rkstart();
}

void
sdread(dev_t dev)
{

	physio(sdstrategy, &rrkbuf, dev, B_READ);
}

void
sdwrite(dev_t dev)
{

	physio(sdstrategy, &rrkbuf, dev, B_WRITE);
}
