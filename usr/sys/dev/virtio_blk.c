/*
 * RK disk driver
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"

void panic(), dmbsy(), iodone(), deverror(), physio(), rkstart();
int spl5(), splx();

#define	RKADDR(off)	(*(volatile int *)(vbase+(off)))
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
rkinit()
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

int
rkstrategy(bp)
register struct buf *bp;
{
	int s;

	bp->av_forw = NULL;
	s = spl5();
	if(rktab.b_actf == NULL)
		rktab.b_actf = bp;
	else
		rktab.b_actl->av_forw = bp;
	rktab.b_actl = bp;
	if(rktab.b_active == NULL)
		rkstart();
	splx(s);
	return(0);
}

void
rkstart()
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

int
rkintr()
{
	register struct buf *bp;

	RKADDR(0x64) = RKADDR(0x60);
	if (rktab.b_active == NULL || vq->uidx != vq->aidx)
		return(0);
	dmbsy();
	dk_busy &= ~(1<<DK_N);
	bp = rktab.b_actf;
	rktab.b_active = NULL;
	if (vstatus) {
		deverror(bp, vstatus, 0);
		if (++rktab.b_errcnt <= 10) {
			rkstart();
			return(0);
		}
		bp->b_flags |= B_ERROR;
	}
	rktab.b_errcnt = 0;
	rktab.b_actf = bp->av_forw;
	bp->b_resid = 0;
	iodone(bp);
	rkstart();
	return(0);
}

int
rkread(dev)
dev_t dev;
{

	physio(rkstrategy, &rrkbuf, dev, B_READ);
	return(0);
}

int
rkwrite(dev)
dev_t dev;
{

	physio(rkstrategy, &rrkbuf, dev, B_WRITE);
	return(0);
}
