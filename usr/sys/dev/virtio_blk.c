/*
 * RK disk driver
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"

#define	RKADDR(off)	(*(volatile int *)(vbase+(off)))
#define	NRK	4
#define	NRKBLK	4872

#define	RESET	0
#define	WCOM	2
#define	RCOM	4
#define	GO	01
#define	DRESET	014
#define	IENABLE	0100
#define	DRY	0200
#define	ARDY	0100
#define	WLO	020000
#define	CTLRDY	0200
#define	NVQ	8

/*
 * Monitoring device bit
 */
#define	DK_N	1

struct	vring
{
	struct {
		int	addr;
		int	addrhi;
		int	len;
		short	flags;
		short	next;
	} desc[NVQ];
	unsigned short	aflags;
	unsigned short	aidx;
	unsigned short	aring[NVQ];
	unsigned short	uflags;
	unsigned short	uidx;
	int	uring[2*NVQ];
};

void rkstart(void);
struct	buf	rktab;
struct	buf	rrkbuf;
volatile struct vring *vq;
char	vqbuf[sizeof(struct vring)+4095];
struct {
	int	type;
	int	reserved;
	long long	sector;
} vreq;
volatile char	vstatus;
int	vbase;
int	rkirq;

void
rkinit(void)
{
	for(vbase=0x0a000000; vbase<0x0a004000; vbase+=0x200)
		if(RKADDR(0) == 0x74726976 && RKADDR(8) == 2)
			break;
	if(vbase == 0x0a004000)
		panic("virtio");
	RKADDR(0x70) = 1;
	RKADDR(0x70) = 3;
	RKADDR(0x28) = 4096;
	RKADDR(0x38) = NVQ;
	RKADDR(0x3c) = 4;
	vq = (struct vring *)(((int)vqbuf+4095) & ~4095);
	RKADDR(0x40) = (int)vq >> 12;
	RKADDR(0x70) = 7;
	rkirq = 48 + (vbase-0x0a000000)/0x200;
}

void
rkstrategy(register struct buf *bp)
{

	if(bp->b_flags&B_PHYS)
		mapalloc(bp);
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
	vreq.type = bp->b_flags&B_READ ? 0 : 1;
	vreq.sector = bp->b_blkno;
	vq->desc[0].addr = (int)&vreq;
	vq->desc[0].len = sizeof(vreq);
	vq->desc[0].flags = 1;
	vq->desc[0].next = 1;
	vq->desc[1].addr = (int)bp->b_un.b_addr;
	vq->desc[1].len = bp->b_bcount;
	vq->desc[1].flags = bp->b_flags&B_READ ? 3 : 1;
	vq->desc[1].next = 2;
	vq->desc[2].addr = (int)&vstatus;
	vq->desc[2].len = 1;
	vq->desc[2].flags = 2;
	dmbsy();
	vq->aidx++;
	dmbsy();
	RKADDR(0x50) = 0;
	dk_busy |= 1<<DK_N;
	dk_numb[DK_N] += 1;
	com = bp->b_bcount>>6;
	dk_wds[DK_N] += com;
}

void
rkintr(void)
{
	register struct buf *bp;

	RKADDR(0x64) = RKADDR(0x60);
	if (rktab.b_active == NULL || vq->uidx != vq->aidx)
		return;
	dmbsy();
	dk_busy &= ~(1<<DK_N);
	bp = rktab.b_actf;
	rktab.b_active = NULL;
	if (vstatus) {
		deverror(bp, vstatus, 0);
		if (++rktab.b_errcnt <= 10) {
			rkstart();
			return;
		}
		bp->b_flags |= B_ERROR;
	}
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
