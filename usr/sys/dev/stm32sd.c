/*
 *   STM32 SDMMC block driver (SDMMC1 on the MP135 board)
 */
#include "../h/param.h"
#include "../h/buf.h"
#include "../h/seg.h"


void dmbsy(void);
void iodone(struct buf *bp);
void deverror(struct buf *bp, int o1, int o2);
void dcflush(unsigned int addr, unsigned int n);	/* clean+invalidate D-cache (mch.s) */
int intr_disable(void);
void intr_restore(int s);
void physio(int (*strat)(), struct buf *bp, dev_t dev, int rw);

extern int	dk_busy;
extern long	dk_numb[3];
extern long	dk_wds[3];

#define	SDMMC1	0x58005000U
#define	SD(off)	(*(volatile unsigned int *)(SDMMC1 + (off)))
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
#define	IDMACTRL 0x50
#define	IDMABSIZE 0x54
#define	IDMABASER 0x58
/* CMD register fields */
#define	CMD_WAITRESP_SHORT 0x0100U	/* short response */
#define	CMD_CMDTRANS	0x0040U		/* command transfers data */
#define	CMD_CPSMEN	0x1000U		/* command path state machine enable */
/* STA bits */
#define	STA_CCRCFAIL	0x0001U
#define	STA_DCRCFAIL	0x0002U
#define	STA_CTIMEOUT	0x0004U
#define	STA_DTIMEOUT	0x0008U
#define	STA_RXOVERR	0x0020U
#define	STA_CMDREND	0x0040U
#define	STA_CMDSENT	0x0080U
#define	STA_DATAEND	0x0100U
#define	STA_DABORT	0x0800U
#define	STA_CMDERR	(STA_CCRCFAIL|STA_CTIMEOUT)
#define	STA_DATERR	(STA_DCRCFAIL|STA_DTIMEOUT|STA_RXOVERR)
#define	STA_STATIC	0x1fe00fffU	/* all clearable flags (ICR) */
/* DCTRL bits */
#define	DCTRL_DTEN	0x0001U
#define	DCTRL_DTDIR	0x0002U		/* 1 = card -> controller (read) */
#define	DCTRL_BLK512	0x0090U		/* DBLOCKSIZE = 9 (512 bytes) */
/* IDMA */
#define	IDMA_IDMAEN	0x0001U
/* card commands */
#define	READ_BLOCK	17
#define	WRITE_BLOCK	24

int	sdirq = 82;		/* GIC INTID of SDMMC1 (SPI 50) */
struct buf sdtab;
static struct buf *sd_cur;
static int sd_retry;

#define	SD_RETRIES	10

static int
sd_cmd(unsigned int idx, unsigned int arg, unsigned int resp, int data)
{
	register int timo;

	SD(ICR) = STA_STATIC;
	SD(ARG) = arg;
	SD(CMD) = idx | resp | CMD_CPSMEN | (data ? CMD_CMDTRANS : 0);
	for (timo = 1000000; timo > 0; timo--) {
		unsigned int s = SD(STA);
		if (s & STA_CTIMEOUT)
			return(-1);		/* no response from card */
		if (resp == 0) {
			if (s & STA_CMDSENT)
				return(0);
		} else if (s & STA_CCRCFAIL)
			return(-1);
		else if (s & STA_CMDREND)
			return((int)SD(RESP1));
	}
	return(-1);
}

void
sdinit(void)
{
	SD(POWER) = 0x03;
	SD(DTIMER) = 0xffffffffU;
	dmbsy();
}

static void
sdstart(void)
{
	register struct buf *bp;
	unsigned int blk;

	if ((bp = sdtab.b_actf) == NULL)
		return;
	if (sdtab.b_active)
		return;
	if (bp != sd_cur) {
		sd_cur = bp;
		sd_retry = 0;
	}
	sdtab.b_active++;
	blk = (unsigned int)bp->b_blkno;
	dcflush((unsigned int)bp->b_un.b_addr, bp->b_bcount);
	SD(ICR) = STA_STATIC;
	SD(DCTRL) = 0;
	SD(DLEN) = bp->b_bcount;
	SD(DCTRL) = DCTRL_BLK512 |
	    ((bp->b_flags & B_READ) ? DCTRL_DTDIR : 0);
	SD(IDMABASER) = (unsigned int)bp->b_un.b_addr;
	SD(IDMACTRL) = IDMA_IDMAEN;
	SD(MASK) = STA_DATAEND | STA_DATERR;	/* interrupt on done/error */
	sd_cmd((bp->b_flags & B_READ) ? READ_BLOCK : WRITE_BLOCK, blk,
	    CMD_WAITRESP_SHORT, 1);
	dk_busy |= 1;
	dk_numb[0]++;
	dk_wds[0] += bp->b_bcount>>6;
}

int
sdstrategy(struct buf *bp)
{
	int s, idle;

	bp->av_forw = NULL;
	s = intr_disable();
	if (sdtab.b_actf == NULL)
		sdtab.b_actf = bp;
	else
		sdtab.b_actl->av_forw = bp;
	sdtab.b_actl = bp;
	idle = (sdtab.b_active == 0);
	intr_restore(s);
	if (idle)
		sdstart();
	return(0);
}

int
sdintr(void)
{
	register struct buf *bp;
	unsigned int sta;

	sta = SD(STA);
	SD(ICR) = STA_STATIC;
	SD(MASK) = 0;
	SD(IDMACTRL) = 0;
	if (sdtab.b_active == 0)
		return(0);
	dk_busy &= ~1;
	bp = sdtab.b_actf;
	sdtab.b_active = 0;
	if (sta & STA_DATERR) {
		if (sd_retry++ < SD_RETRIES) {
			sdstart();
			return(0);
		}
		deverror(bp, (int)sta, 0);
		bp->b_flags |= B_ERROR;
	} else if (bp->b_flags & B_READ)
		dcflush((unsigned int)bp->b_un.b_addr, bp->b_bcount);
	sd_cur = NULL;
	sd_retry = 0;
	sdtab.b_actf = bp->av_forw;
	bp->b_resid = 0;
	iodone(bp);
	sdstart();
	return(0);
}

struct	buf	rsdbuf;

int
sdread(dev)
dev_t dev;
{

	physio(sdstrategy, &rsdbuf, dev, B_READ);
	return(0);
}

int
sdwrite(dev)
dev_t dev;
{

	physio(sdstrategy, &rsdbuf, dev, B_WRITE);
	return(0);
}
