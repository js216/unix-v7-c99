/*
 * RK disk driver
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"

#define	SD(off)	(*(volatile int *)(0xF0205000+(off)))
#define	RCC(off)	(*(volatile int *)(0xF0000000+(off)))
#define	GPIO(p, off)	(*(volatile int *)(0xF0002000+(p)*0x1000+(off)))
#define	NRK	4

#define	RESET	0
#define	WCOM	25
#define	RCOM	18
#define	GO	0x1140
#define	STOP	0x118c
#define	DRESET	014
#define	IENABLE	0x800013f
#define	DRY	0200
#define	ARDY	0100
#define	WLO	020000
#define	CTLRDY	0200
#define	POWER	0x00
#define	CLKCR	0x04
#define	ARG	0x08
#define	CMD	0x0c
#define	RESP1	0x14
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
#define	CMDREND	0100
#define	CMDERR	05
#define	BUSYD0	(1<<20)
#define	BUSYD0END	(1<<21)
#define	WIDE	(1<<14)
#define	MAXIO	0x1000000

/*
 * Monitoring device bit
 */
#define	DK_N	1

void rkstart(void);
int	rkirq = 82;
struct	buf	rktab;
struct	buf	rrkbuf;
unsigned	rkoff;
static unsigned	rkn, rkstop, rksta;
daddr_t	nrkblk;
static unsigned	rca, rkbyte;

static void
rkdelay(unsigned us)
{
	unsigned long long t;

	t = cntvct_get() + cntfrq_get()/1000000*us;
	while (cntvct_get() < t)
		;
}

/*
 * Send a command and wait for it;
 * the response is in RESP1-4.
 */
static void
rkcmd(int com, unsigned arg, int resp)
{
	register int sta;
	unsigned long long t;

	SD(ICR) = CLEAR;
	SD(ARG) = arg;
	SD(CMD) = com | resp<<8 | 0x1000;
	t = cntvct_get() + cntfrq_get()/10;
	do {
		sta = SD(STA);
		if (cntvct_get() > t || sta&04)
			panic("sd card");
	} while ((sta & (resp ? 0101 : 0200)) == 0);
	if (sta&01 && com != 41 && resp != 3)
		panic("sd card crc");
}

/*
 * Bring the card up as the boot ROM would have:
 * pins, a 400 kHz clock, identification, the size
 * from the CSD, selection, then 16 MHz.
 */
void
rkinit(void)
{
	register int i, n;
	unsigned c;

	RCC(0x770) = 014;
	for (i = 8; i <= 12; i++) {
		GPIO(2, 0x00) = (GPIO(2, 0x00) & ~(3<<2*i)) | 2<<2*i;
		GPIO(2, 0x08) |= 1<<2*i;
		GPIO(2, 0x24) = (GPIO(2, 0x24) & ~(0xF<<(i-8)*4)) | 12<<(i-8)*4;
	}
	GPIO(3, 0x00) = (GPIO(3, 0x00) & ~(3<<4)) | 2<<4;
	GPIO(3, 0x08) |= 1<<4;
	GPIO(3, 0x20) = (GPIO(3, 0x20) & ~(0xF<<8)) | 12<<8;
	RCC(0x648) = (RCC(0x648) & ~7) | 3;
	RCC(0x780) = 1<<16;
	RCC(0x6F0) = 1<<16;
	RCC(0x6F4) = 1<<16;
	SD(CLKCR) = 80;
	SD(POWER) = 3;
	rkdelay(1000);
	rkcmd(0, 0, 0);
	rkcmd(8, 0x1AA, 1);
	for (n = 0; ; n++) {
		if (n == 1000)
			panic("sd card");
		rkcmd(55, 0, 1);
		rkcmd(41, 0x40FF8000, 2);
		if (SD(RESP1) < 0)
			break;
		rkdelay(1000);
	}
	rkbyte = (SD(RESP1) & 0x40000000) == 0;
	rkcmd(2, 0, 3);
	rkcmd(3, 0, 1);
	rca = SD(RESP1) & 0xFFFF0000;
	rkcmd(9, rca, 3);
	if ((unsigned)SD(RESP1)>>30 == 1)
		nrkblk = ((SD(RESP1+4)&077)<<16 | (unsigned)SD(RESP1+8)>>16) * 1024 + 1024;
	else {
		c = (SD(RESP1+4)&01777)<<2 | (unsigned)SD(RESP1+8)>>30;
		nrkblk = (c+1) << (((SD(RESP1+8)>>15)&7) + 2 + ((SD(RESP1+4)>>16)&017) - 9);
	}
	rkcmd(7, rca, 1);
	rkcmd(55, rca, 1);
	rkcmd(6, 2, 1);
	SD(CLKCR) = 2 | WIDE;
	SD(DTIMER) = -1;
}

void
rkstrategy(register struct buf *bp)
{

	if (bp->b_blkno >= nrkblk || bp->b_bcount&BMASK || (int)bp->b_un.b_addr&3) {
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

/*
 * One command moves the rest of the buffer, up to MAXIO
 * bytes; CMD12 then stops the card.
 */
void
rkstart(void)
{
	register struct buf *bp;
	register int com;

	if ((bp = rktab.b_actf) == NULL)
		return;
	rktab.b_active++;
	rkn = bp->b_bcount - rkoff;
	if (rkn > MAXIO)
		rkn = MAXIO;
	rkstop = 0;
	dcflush(bp->b_un.b_addr+rkoff, rkn);
	SD(ICR) = CLEAR;
	SD(DCTRL) = 0;
	SD(DLEN) = rkn;
	SD(DCTRL) = bp->b_flags&B_READ ? BLK512|DTDIR : BLK512;
	SD(IDMABASER) = vtop(bp->b_un.b_addr+rkoff);
	SD(IDMACTRL) = 1;
	SD(MASK) = IENABLE;
	SD(ARG) = (bp->b_blkno+(rkoff>>BSHIFT)) << (rkbyte ? BSHIFT : 0);
	com = GO;
	if(bp->b_flags & B_READ)
		com |= RCOM; else
		com |= WCOM;
	SD(CMD) = com;
	dk_busy |= 1<<DK_N;
	dk_numb[DK_N] = (unsigned long)dk_numb[DK_N] + 1;
	dk_wds[DK_N] = (unsigned long)dk_wds[DK_N] + (rkn>>6);
}

void
rkintr(void)
{
	register struct buf *bp;
	register int sta;

	sta = SD(STA);
	SD(ICR) = CLEAR;
	if (rktab.b_active == NULL) {
		SD(MASK) = 0;
		return;
	}
	if (rkstop == 0) {
		SD(IDMACTRL) = 0;
		rksta = sta;
		rkstop = 1;
		SD(MASK) = CMDREND|CMDERR|BUSYD0END;
		SD(ARG) = 0;
		SD(CMD) = STOP;
		return;
	}
	if (rkstop == 1 && (sta&CMDERR) == 0 && SD(STA)&BUSYD0) {
		rkstop = 2;
		SD(MASK) = BUSYD0END;
		return;
	}
	SD(MASK) = 0;
	if (sta&CMDERR)
		rksta |= sta;
	sta = rksta;
	dk_busy &= ~(1<<DK_N);
	bp = rktab.b_actf;
	rktab.b_active = NULL;
	if (sta & (ERR|CMDERR)) {
		deverror(bp, sta, 0);
		if (++rktab.b_errcnt <= 10) {
			rkstart();
			return;
		}
		bp->b_flags |= B_ERROR;
	} else if ((rkoff += rkn) < bp->b_bcount) {
		rkstart();
		return;
	}
	rkoff = 0;
	if (bp->b_flags & B_READ)
		dcinval(bp->b_un.b_addr, bp->b_bcount);
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
