/*
 *   STM32 SDMMC block driver (SDMMC1 on the MP135 board)
 *
 * The bulk-storage block device.  Same async, interrupt-driven, queued model
 * as rk.c / virtio_blk.c: bdstrategy() puts the buffer on bdtab and kicks the
 * controller via bdstart(); bdstart() programs one SD block transfer through
 * the SDMMC internal DMA and returns; the transfer-complete interrupt
 * (bdintr) runs iodone() and starts the next queued buffer.  bio.c's iowait()
 * sleeps on the buffer until then.  This file is built only for the MP135
 * board (the QEMU build links virtio_blk.c instead).
 */
#include "../h/param.h"
#include "../h/buf.h"
#include "../h/seg.h"
void panic(char *s);
void dmbsy(void);
void iodone(struct buf *bp);
void deverror(struct buf *bp, int o1, int o2);
void dcflush(unsigned int addr, unsigned int n);	/* clean+invalidate D-cache (mch.s) */
int intr_disable(void);
void intr_restore(int s);

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
/* RCC + GPIO for SDMMC1 clock gating and pin mux */
#define	RCC	0x50000000U
#define	GPIOC	0x50004000U
#define	GPIOD	0x50005000U
#define	R32(a)	(*(volatile unsigned int *)(a))
#define	AHB4ENSETR R32(RCC + 0x770)	/* non-secure: GPIO bus clocks */
#define	AHB6ENSETR R32(RCC + 0x780)	/* SDMMC1 bus clock */
#define	GPIOCEN	0x00000004U
#define	GPIODEN	0x00000008U
#define	SDMMC1EN 0x00010000U

/* CMD register fields */
#define	CMD_WAITRESP_SHORT 0x0100U	/* short response */
#define	CMD_WAITRESP_LONG  0x0300U	/* long response */
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
#define	GO_IDLE		0
#define	ALL_SEND_CID	2
#define	SEND_RCA	3
#define	SEL_CARD	7
#define	IF_COND		8
#define	SEND_CSD	9
#define	SET_BLOCKLEN	16
#define	READ_BLOCK	17
#define	WRITE_BLOCK	24
#define	APP_CMD		55
#define	APP_OP_COND	41
#define	OCR_HCS		0x40000000U	/* host supports high capacity */
#define	OCR_VOLT	0x00ff8000U	/* 2.7-3.6 V window */

int	bd_irq = 82;		/* GIC INTID of SDMMC1 (SPI 50) */
struct buf bdtab;
static unsigned int sd_rca;	/* card relative address (<<16 for commands) */
static int sd_hc;		/* 1 = high-capacity (block addressing) */
static struct buf *bd_cur;
static int bd_retry;

#define	SD_RETRIES	3

/*
 * Issue one command.  resp is 0 (none), CMD_WAITRESP_SHORT, or
 * CMD_WAITRESP_LONG; data!=0 marks a data-transfer command.  Returns RESP1,
 * or -1 on command timeout/CRC error.
 */
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
		} else if (s & (STA_CMDREND | STA_CCRCFAIL)) {
			/* CCRCFAIL is expected for R3 (OCR) which carries no CRC;
			 * the response is still latched in RESP1, so accept it. */
			return((int)SD(RESP1));
		}
	}
	return(-1);
}

/*
 * Bring up SDMMC1 and initialize the card: CMD0 (idle), CMD8 (voltage/HC
 * probe), CMD55+ACMD41 loop (OCR + HCS, wait power-up), CMD2 (CID), CMD3
 * (RCA), CMD9 (CSD), CMD7 (select), CMD16 (512-byte blocks; SDHC ignores).
 * The bus stays 1-bit: the controller's WIDBUS must match the card's, and a
 * 4-bit transfer would need ACMD6 (SET_BUS_WIDTH) sent to the card first -- a
 * speed optimization deferred past bring-up (cf. the bootloader's
 * SD_WideBus_Enable).  1-bit is correct and sufficient to read the rootfs.
 * Sets sd_rca, sd_hc.  Panics if no card responds.
 *
 * The SDMMC1 bus clock, GPIO clocks, and pin mux (AF12: D0-D3+CK on PC8-12,
 * CMD on PD2) are configured below; the card kernel clock is PLL4, routed by
 * clock_init() (so this runs after the PLLs are up).  All imported from the
 * reference bootloader's sd.c.
 * TODO(bench, #33): validate the card-init response/timeout values, the IDMA
 * data path, and dcflush coherency against a real card on the PCB.
 */
void
bdinit(void)
{
	register int timo;
	unsigned int ocr;

	/* SDMMC1 bus clock + GPIO clocks, then pin mux to alternate function 12:
	 * data/clock D0-D3+CK on PC8..PC12, command CMD on PD2. */
	AHB4ENSETR = GPIOCEN | GPIODEN;
	AHB6ENSETR = SDMMC1EN;
	(void)AHB6ENSETR;		/* read-back: clock live before access */
	R32(GPIOC+0x00) = (R32(GPIOC+0x00) & ~0x03FF0000U) | 0x02AA0000U; /* MODER PC8-12 AF */
	R32(GPIOC+0x24) = (R32(GPIOC+0x24) & ~0x000FFFFFU) | 0x000CCCCCU; /* AFRH PC8-12 AF12 */
	R32(GPIOD+0x00) = (R32(GPIOD+0x00) & ~0x00000030U) | 0x00000020U; /* MODER PD2 AF */
	R32(GPIOD+0x20) = (R32(GPIOD+0x20) & ~0x00000F00U) | 0x00000C00U; /* AFRL PD2 AF12 */

	SD(POWER) = 0x03;		/* power on */
	SD(CLKCR) = 0x02;		/* clkdiv=2, 1-bit bus (WIDBUS=00) */
	SD(DTIMER) = 0xffffffffU;
	dmbsy();

	sd_cmd(GO_IDLE, 0, 0, 0);
	sd_cmd(IF_COND, 0x1aa, CMD_WAITRESP_SHORT, 0);	/* CMD8: 2.7-3.6V, check 0xaa */
	for (timo = 100000; timo > 0; timo--) {
		sd_cmd(APP_CMD, 0, CMD_WAITRESP_SHORT, 0);
		ocr = (unsigned int)sd_cmd(APP_OP_COND, OCR_VOLT|OCR_HCS,
		    CMD_WAITRESP_SHORT, 0);
		if (ocr & 0x80000000U)		/* card powered up */
			break;
	}
	if (timo == 0)
		panic("sd");
	sd_hc = (ocr & OCR_HCS) ? 1 : 0;
	sd_cmd(ALL_SEND_CID, 0, CMD_WAITRESP_LONG, 0);
	sd_rca = (unsigned int)sd_cmd(SEND_RCA, 0, CMD_WAITRESP_SHORT, 0)
	    & 0xffff0000U;
	sd_cmd(SEND_CSD, sd_rca, CMD_WAITRESP_LONG, 0);
	sd_cmd(SEL_CARD, sd_rca, CMD_WAITRESP_SHORT, 0);
	sd_cmd(SET_BLOCKLEN, 512, CMD_WAITRESP_SHORT, 0);	/* SDSC needs this; SDHC ignores */
	bdtab.b_actf = NULL;
	bdtab.b_active = 0;
}

/*
 * Program one block transfer for the buffer at the head of the queue through
 * the SDMMC internal DMA, and enable the data-done interrupt.  (cf. rkstart.)
 */
static void
bdstart(void)
{
	register struct buf *bp;
	unsigned int blk;

	if ((bp = bdtab.b_actf) == NULL)
		return;
	if (bdtab.b_active)
		return;
	if (bp != bd_cur) {
		bd_cur = bp;
		bd_retry = 0;
	}
	bdtab.b_active++;
	blk = sd_hc ? (unsigned int)bp->b_blkno : (unsigned int)bp->b_blkno*512;
	dcflush((unsigned int)bp->b_un.b_addr, bp->b_bcount);
	SD(ICR) = STA_STATIC;
	/* Match the HAL IDMA single-buffer read/write order: program the data
	 * path (DLEN + DCTRL block size/dir, DPSM left off) first, then point the
	 * internal DMA at the buffer and enable it, then issue the command (which
	 * sets CMDTRANS and starts the DPSM).  IDMABSIZE is double-buffer-only and
	 * must not be written for single-buffer transfers. */
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
	dk_wds[0] += bp->b_bcount / 2;
}

int
bdstrategy(struct buf *bp)
{
	int s, idle;

	bp->av_forw = NULL;
	s = intr_disable();
	if (bdtab.b_actf == NULL)
		bdtab.b_actf = bp;
	else
		bdtab.b_actl->av_forw = bp;
	bdtab.b_actl = bp;
	idle = (bdtab.b_active == 0);
	intr_restore(s);
	if (idle)
		bdstart();
	return(0);
}

/*
 * Transfer-complete interrupt: finish the active buffer and start the next.
 * (cf. rkintr.)
 */
int
bdintr(void)
{
	register struct buf *bp;
	unsigned int sta;

	sta = SD(STA);
	SD(ICR) = STA_STATIC;
	SD(MASK) = 0;
	SD(IDMACTRL) = 0;
	if (bdtab.b_active == 0)
		return(0);
	dk_busy &= ~1;
	bp = bdtab.b_actf;
	bdtab.b_active = 0;
	if (sta & STA_DATERR) {
		if (bd_retry++ < SD_RETRIES) {
			bdstart();
			return(0);
		}
		deverror(bp, (int)sta, 0);
		bp->b_flags |= B_ERROR;
	} else if (bp->b_flags & B_READ)
		dcflush((unsigned int)bp->b_un.b_addr, bp->b_bcount);
	bd_cur = NULL;
	bd_retry = 0;
	bdtab.b_actf = bp->av_forw;
	bp->b_resid = 0;
	iodone(bp);
	bdstart();
	return(0);
}
