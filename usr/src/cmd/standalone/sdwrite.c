/*
 * Standalone SD card writer for the STM32MP135,
 * loaded through the boot ROM's USB DFU mode.
 * It presents a CDC-ACM serial port and obeys:
 *	i		card size in blocks
 *	w lba n		take n bytes, write them from block lba
 *	r lba n		send n bytes read from block lba
 *	x		reset the board
 * The watchdog resets the board 33 s after the last command.
 * From the host's shell:
 *	stty -F /dev/ttyACM0 raw -echo; exec 3<>/dev/ttyACM0
 *	printf 'w 0 %d\r' `stat -c %s img` >&3; cat img >&3; head -1 <&3
 *	printf 'r 0 %d\r' `stat -c %s img` >&3; head -c `stat -c %s img` <&3 | cmp - img
 */

#define	R(a)	(*(volatile unsigned *)(a))

#define	RCC	0x50000000
#define	GPIOC	0x50004000
#define	GPIOD	0x50005000
#define	SD	0x58005000
#define	OTG	0x49000000
#define	IWDG	0x5a002000

#define	POWER	(SD+0x00)
#define	CLKCR	(SD+0x04)
#define	ARG	(SD+0x08)
#define	CMD	(SD+0x0c)
#define	RESP1	(SD+0x14)
#define	DTIMER	(SD+0x24)
#define	DLEN	(SD+0x28)
#define	DCTRL	(SD+0x2c)
#define	STA	(SD+0x34)
#define	ICR	(SD+0x38)
#define	SDFIFO	(SD+0x80)

#define	CCRCFAIL	01
#define	CTIMEOUT	04
#define	DERR	072
#define	CMDREND	0100
#define	CMDSENT	0200
#define	DATAEND	0400
#define	TXFIFOHE	(1<<14)
#define	RXFIFOHF	(1<<15)
#define	RXFIFOE	(1<<19)
#define	BUSYD0	(1<<20)
#define	CLEAR	0x1fe00fff
#define	CPSMEN	(1<<12)
#define	TRANS	0100
#define	STOP	0200
#define	HWFC	(1<<17)
#define	WIDE	(1<<14)

#define	GRSTCTL	(OTG+0x010)
#define	GINTSTS	(OTG+0x014)
#define	GRXSTSR	(OTG+0x01c)
#define	GRXSTSP	(OTG+0x020)
#define	DCFG	(OTG+0x800)
#define	DCTL	(OTG+0x804)
#define	DSTS	(OTG+0x808)
#define	DIEPCTL(n)	(OTG+0x900+(n)*0x20)
#define	DIEPINT(n)	(OTG+0x908+(n)*0x20)
#define	DIEPTSIZ(n)	(OTG+0x910+(n)*0x20)
#define	DTXFSTS(n)	(OTG+0x918+(n)*0x20)
#define	DOEPCTL(n)	(OTG+0xb00+(n)*0x20)
#define	DOEPINT(n)	(OTG+0xb08+(n)*0x20)
#define	DOEPTSIZ(n)	(OTG+0xb10+(n)*0x20)
#define	FIFO(n)	(OTG+0x1000+(n)*0x1000)

#define	EPENA	(1U<<31)
#define	SNAK	(1U<<27)
#define	CNAK	(1U<<26)
#define	SD0PID	(1U<<28)
#define	STALL	(1U<<21)
#define	USBAEP	(1U<<15)
#define	XFRC	01
#define	EPDISD	02
#define	INEPNE	0100
#define	EPDIS	(1U<<30)
#define	TXFFLSH	(1U<<5)
#define	STUP	010
#define	RXFLVL	(1U<<4)
#define	USBRST	(1U<<12)
#define	ENUMDNE	(1U<<13)
#define	SDIS	02

#define	NRING	(64*1024)

void	main(void);
void	reset(void);

static unsigned	ring[NRING/4], rxbuf[128];
static unsigned char	setup[8], ep0buf[64], line[80];
static unsigned	rca, nblk, mps = 512, ep0len, rxn;
static int	config, rxready;

static const unsigned char devdesc[18] = {
	18, 1, 0x00, 0x02, 2, 0, 0, 64, 0x09, 0x12, 0x02, 0x00,
	0x00, 0x01, 0, 0, 0, 1
};

static unsigned char cfgdesc[67] = {
	9, 2, 67, 0, 2, 1, 0, 0xc0, 1,
	9, 4, 0, 0, 1, 2, 2, 0, 0,
	5, 0x24, 0, 0x10, 0x01,
	5, 0x24, 1, 0, 1,
	4, 0x24, 2, 2,
	5, 0x24, 6, 0, 1,
	7, 5, 0x82, 3, 16, 0, 8,
	9, 4, 1, 0, 2, 10, 0, 0, 0,
	7, 5, 0x01, 2, 0x00, 0x02, 0,
	7, 5, 0x81, 2, 0x00, 0x02, 0
};

static unsigned char coding[7] = { 0x00, 0xc2, 0x01, 0x00, 0, 0, 8 };

__asm__(
	".section .start, \"ax\"\n"
	".globl _start\n"
"_start:\n"
	"cpsid if\n"
	"ldr sp, =0x30000000\n"
	"mrc p15, 0, r0, c1, c0, 0\n"
	"orr r0, r0, #(1 << 12)\n"
	"mov r1, #0\n"
	"mcr p15, 0, r1, c7, c5, 0\n"
	"mcr p15, 0, r0, c1, c0, 0\n"
	"isb\n"
	"ldr r0, =__bss_start__\n"
	"ldr r1, =__bss_end__\n"
	"mov r2, #0\n"
"1:	cmp r0, r1\n"
	"strlo r2, [r0], #4\n"
	"blo 1b\n"
	"bl main\n"
	".text\n"
);

static unsigned
now(void)
{
	unsigned lo, hi;

	__asm__ volatile("mrrc p15, 0, %0, %1, c14" : "=r"(lo), "=r"(hi));
	return(lo);
}

static void
delay(unsigned us)
{
	unsigned t;

	t = now();
	while (now() - t < us*64)
		;
}

static void
kick(void)
{
	R(IWDG) = 0xaaaa;
}

void
reset(void)
{
	R(RCC+0x114) = 1;
	for (;;)
		;
}

/*
 * USB: one CDC-ACM device, polled.
 */
static void
fifowrite(int ep, const unsigned char *p, unsigned n)
{
	register unsigned i, w;

	for (i = 0; i < n; i += 4) {
		w = p[i];
		if (i+1 < n)
			w |= p[i+1] << 8;
		if (i+2 < n)
			w |= p[i+2] << 16;
		if (i+3 < n)
			w |= (unsigned)p[i+3] << 24;
		R(FIFO(ep)) = w;
	}
}

static void
fiforead(unsigned char *p, unsigned n)
{
	register unsigned i, w;

	for (i = 0; i < n; i += 4) {
		w = R(FIFO(0));
		if (p == 0)
			continue;
		p[i] = w;
		if (i+1 < n)
			p[i+1] = w >> 8;
		if (i+2 < n)
			p[i+2] = w >> 16;
		if (i+3 < n)
			p[i+3] = w >> 24;
	}
}

static void
ep0out(void)
{
	R(DOEPTSIZ(0)) = 3U<<29 | 1U<<19 | 64;
	R(DOEPCTL(0)) |= EPENA|CNAK;
}

static void
ep0in(const unsigned char *p, unsigned n)
{
	unsigned want;

	want = setup[6] | setup[7]<<8;
	if (n > want)
		n = want;
	R(DIEPTSIZ(0)) = (n == 0 ? 1U : (n+63)/64)<<19 | n;
	R(DIEPCTL(0)) |= EPENA|CNAK;
	fifowrite(0, p, n);
	ep0out();
}

static void
rxarm(void)
{
	R(DOEPTSIZ(1)) = 1U<<19 | mps;
	R(DOEPCTL(1)) |= EPENA|CNAK;
	rxready = 0;
}

/*
 * Tell the host the line has carrier, so that an open
 * which waits for it can finish.
 */
static void
carrier(void)
{
	static const unsigned char state[10] = { 0xa1, 0x20, 0, 0, 0, 0, 2, 0, 3, 0 };

	if (R(DIEPCTL(2)) & EPENA)
		return;
	R(DIEPTSIZ(2)) = 1U<<19 | 10;
	R(DIEPCTL(2)) |= EPENA|CNAK;
	fifowrite(2, state, 10);
}

static void
dosetup(void)
{
	unsigned char buf[4];
	register unsigned type, req, val, i;

	type = setup[0];
	req = setup[1];
	val = setup[2] | setup[3]<<8;
	if ((type&0x60) == 0x20) {
		if (req == 0x20) {
			ep0len = 7;
			ep0out();
		} else if (req == 0x21)
			ep0in(coding, 7);
		else
			ep0in(0, 0);
		if (req == 0x22 && config)
			carrier();
		return;
	}
	switch (req) {
	case 5:
		R(DCFG) = (R(DCFG) & ~(0177U<<4)) | (val&0177)<<4;
		ep0in(0, 0);
		return;
	case 6:
		if (val>>8 == 1) {
			ep0in(devdesc, 18);
			return;
		}
		if (val>>8 == 2) {
			for (i = 0; i < sizeof cfgdesc; i += cfgdesc[i])
				if (cfgdesc[i+1] == 5 && cfgdesc[i+3] == 2) {
					cfgdesc[i+4] = mps;
					cfgdesc[i+5] = mps>>8;
				}
			ep0in(cfgdesc, sizeof cfgdesc);
			return;
		}
		break;
	case 9:
		config = val&0xff;
		R(DIEPCTL(1)) = USBAEP | 2U<<18 | 1U<<22 | SD0PID | mps;
		R(DOEPCTL(1)) = USBAEP | 2U<<18 | SD0PID | mps;
		R(DIEPCTL(2)) = USBAEP | 3U<<18 | 2U<<22 | SD0PID | 16;
		rxarm();
		ep0in(0, 0);
		return;
	case 0:
	case 8:
	case 10:
		buf[0] = req == 8 ? config : type == 0x80;
		buf[1] = 0;
		ep0in(buf, req == 0 ? 2 : 1);
		return;
	case 1:
	case 3:
	case 11:
		ep0in(0, 0);
		return;
	}
	R(DIEPCTL(0)) |= STALL;
	R(DOEPCTL(0)) |= STALL;
	ep0out();
}

/*
 * Service the controller.  An OUT packet on the data
 * endpoint goes into rxbuf at once, so that SETUP packets
 * behind it in the FIFO are not held up; rxready says one
 * is waiting, rxn its size.  The endpoint takes no more
 * until it has been used.
 */
static void
usbpoll(void)
{
	register unsigned s, st, n, k;
	int i;

	s = R(GINTSTS);
	if (s & USBRST) {
		R(GINTSTS) = USBRST;
		for (i = 1; i < 4; i++) {
			R(DOEPCTL(i)) = SNAK;
			R(DIEPCTL(i)) = 0;
		}
		R(DCFG) &= ~(0177U<<4);
		config = 0;
		ep0out();
	}
	if (s & ENUMDNE) {
		R(GINTSTS) = ENUMDNE;
		mps = ((R(DSTS)>>1)&3) == 0 ? 512 : 64;
		R(DIEPCTL(0)) &= ~3U;
		R(DCTL) |= 1U<<8;
	}
	while (R(GINTSTS) & RXFLVL) {
		st = R(GRXSTSP);
		n = (st>>4) & 03777;
		k = (st>>17) & 017;
		if (k == 2 && (st&017) == 1) {
			for (i = 0; i < (int)n; i += 4)
				rxbuf[i/4] = R(FIFO(0));
			rxready = 1;
			rxn = n;
		} else if (k == 6)
			fiforead(setup, n);
		else if (k == 2)
			fiforead(ep0buf, n);
		else
			fiforead(0, n);
	}
	st = R(DOEPINT(0));
	if (st & STUP) {
		R(DOEPINT(0)) = STUP|XFRC|060;
		dosetup();
	} else if (st & XFRC) {
		R(DOEPINT(0)) = XFRC|060;
		if (ep0len) {
			for (n = 0; n < 7; n++)
				coding[n] = ep0buf[n];
			ep0len = 0;
			ep0in(0, 0);
		} else
			ep0out();
	}
	R(DIEPINT(0)) = R(DIEPINT(0));
	st = R(DOEPINT(1));
	if (st & XFRC)
		R(DOEPINT(1)) = st;
}

/*
 * Take the waiting OUT packet, rxn bytes, into p;
 * then accept the next.
 */
static void
usbtake(unsigned *p)
{
	register unsigned i;

	for (i = 0; i < rxn; i += 4)
		*p++ = rxbuf[i/4];
	rxarm();
}

/*
 * Give up a transfer the host has stopped taking:
 * disable the endpoint and empty its FIFO, so that
 * the next transfer starts clean.
 */
static int
epabort(void)
{
	if (R(DIEPCTL(1)) & EPENA) {
		R(DIEPCTL(1)) |= SNAK;
		while ((R(DIEPINT(1)) & INEPNE) == 0)
			;
		R(DIEPCTL(1)) |= EPDIS|SNAK;
		while ((R(DIEPINT(1)) & EPDISD) == 0)
			;
	}
	R(GRSTCTL) = TXFFLSH | 1U<<6;
	while (R(GRSTCTL) & TXFFLSH)
		;
	R(DIEPINT(1)) = R(DIEPINT(1));
	return(-1);
}

/*
 * Send n bytes, a packet at a time as the
 * transmit FIFO has room for it.
 */
static int
usbsend(const unsigned char *p, unsigned n)
{
	register unsigned i, k;
	unsigned t;

	R(DIEPTSIZ(1)) = (n == 0 ? 1 : (n+mps-1)/mps)<<19 | n;
	R(DIEPCTL(1)) |= EPENA|CNAK;
	t = now();
	for (i = 0; i < n; i += k) {
		k = n-i < mps ? n-i : mps;
		while ((R(DTXFSTS(1)) & 0xffff) < (k+3)/4)
			if (now() - t > 64000000)
				return(epabort());
		fifowrite(1, p+i, k);
	}
	while ((R(DIEPINT(1)) & XFRC) == 0)
		if (now() - t > 64000000)
			return(epabort());
		else
			usbpoll();
	R(DIEPINT(1)) = XFRC;
	return(0);
}

static void
usbinit(void)
{
	int i;

	R(DCTL) |= SDIS;
	delay(200000);
	while ((R(GRSTCTL) & 1U<<31) == 0)
		;
	R(GRSTCTL) = 1;
	while (R(GRSTCTL) & 1)
		;
	R(OTG+0x008) = 0;
	R(OTG+0x00c) = (R(OTG+0x00c) & ~(1U<<29|1U<<30|017U<<10)) | 1U<<30 | 9U<<10;
	delay(50000);
	R(OTG+0x038) &= ~(1U<<21);
	R(OTG+0x000) |= 1U<<6 | 1U<<7;
	R(OTG+0xe00) = 0;
	R(DCFG) = 0;
	R(OTG+0x024) = 0x300;
	R(OTG+0x028) = 0x40U<<16 | 0x300;
	R(OTG+0x104) = 0x80U<<16 | 0x340;
	R(OTG+0x108) = 0x20U<<16 | 0x3c0;
	R(GRSTCTL) = 1U<<5 | 0x10U<<6;
	while (R(GRSTCTL) & 1U<<5)
		;
	R(GRSTCTL) = 1U<<4;
	while (R(GRSTCTL) & 1U<<4)
		;
	for (i = 0; i < 4; i++) {
		R(DIEPCTL(i)) = 0;
		R(DOEPCTL(i)) = 0;
		R(DIEPINT(i)) = 0xffff;
		R(DOEPINT(i)) = 0xffff;
	}
	R(OTG+0x018) = 0;
	R(GINTSTS) = 0xffffffff;
	R(DCTL) &= ~SDIS;
}

static void
say(const char *s)
{
	register int n;

	for (n = 0; s[n]; n++)
		;
	(void)usbsend((const unsigned char *)s, n);
}

static void
putn(unsigned v)
{
	char buf[12];
	register int i;

	i = sizeof buf - 1;
	buf[i] = 0;
	do
		buf[--i] = '0' + v%10;
	while (v /= 10);
	say(buf+i);
}

/*
 * The SD card.
 */
static int
sdcmd(unsigned com, unsigned arg, int resp)
{
	register unsigned sta, t;

	R(ICR) = CLEAR;
	R(ARG) = arg;
	R(CMD) = com | resp<<8 | CPSMEN;
	t = now();
	do {
		sta = R(STA);
		if (sta & CTIMEOUT || now() - t > 6400000)
			return(-1);
	} while ((sta & (resp ? CMDREND|CCRCFAIL : CMDSENT)) == 0);
	if (sta & CCRCFAIL && resp == 1 && (com&077) != 41)
		return(-1);
	return(0);
}

static int
sdinit(void)
{
	register int i;
	unsigned buf[16], c;

	R(RCC+0x770) = 014;
	for (i = 8; i <= 12; i++) {
		R(GPIOC+0x00) = (R(GPIOC+0x00) & ~(3U<<2*i)) | 2U<<2*i;
		R(GPIOC+0x08) |= 1U<<2*i;
		R(GPIOC+0x24) = (R(GPIOC+0x24) & ~(0xfU<<(i-8)*4)) | 12U<<(i-8)*4;
	}
	R(GPIOD+0x00) = (R(GPIOD+0x00) & ~(3U<<4)) | 2U<<4;
	R(GPIOD+0x08) |= 1U<<4;
	R(GPIOD+0x20) = (R(GPIOD+0x20) & ~(0xfU<<8)) | 12U<<8;
	R(RCC+0x648) = (R(RCC+0x648) & ~7U) | 3;
	R(RCC+0x780) = 1U<<16;
	R(RCC+0x6f0) = 1U<<16;
	R(RCC+0x6f4) = 1U<<16;
	R(CLKCR) = 80 | HWFC;
	R(POWER) = 3;
	delay(1000);
	if (sdcmd(0, 0, 0) || sdcmd(8, 0x1aa, 1))
		return(-1);
	for (i = 0; ; i++) {
		if (i == 1000 || sdcmd(55, 0, 1) || sdcmd(41, 0x40ff8000, 2))
			return(-1);
		if (R(RESP1) & 1U<<31)
			break;
		delay(1000);
	}
	if ((R(RESP1) & 1U<<30) == 0)
		return(-1);
	if (sdcmd(2, 0, 3) || sdcmd(3, 0, 1))
		return(-1);
	rca = R(RESP1) & 0xffff0000;
	if (sdcmd(9, rca, 3))
		return(-1);
	nblk = (((R(RESP1+4)&077)<<16 | R(RESP1+8)>>16) + 1) * 1024;
	if (sdcmd(7, rca, 1) || sdcmd(55, rca, 1) || sdcmd(6, 2, 1))
		return(-1);
	R(CLKCR) = 2 | WIDE | HWFC;
	R(DTIMER) = 0xffffffff;
	R(DCTRL) = 0;
	R(DLEN) = 64;
	R(DCTRL) = 6<<4 | 2;
	if (sdcmd(6|TRANS, 0x80fffff1, 1))
		return(-1);
	for (i = 0; i < 16; ) {
		c = R(STA);
		if ((c & RXFIFOE) == 0)
			buf[i++] = R(SDFIFO);
		else if (c & (DATAEND|DERR))
			break;
	}
	if (i == 16 && (buf[4] & 0xf) == 1) {
		delay(1000);
		R(CLKCR) = 1 | WIDE | HWFC;
	}
	return(0);
}

static void
sdstop(int wr)
{
	sdcmd(12|STOP, 0, 1);
	while (R(STA) & BUSYD0)
		;
	if (wr)
		while (sdcmd(13, rca, 1) == 0 && (R(RESP1)>>9 & 017) != 4)
			;
}

/*
 * Write n bytes from USB to the card at block bn.
 * The ring holds what has come in and not gone out;
 * both sides stall the other when it is empty or full.
 */
static int
sdwrite(unsigned bn, unsigned n)
{
	register unsigned in, out, sta;
	unsigned left, t;

	if (sdcmd(55, rca, 1) || sdcmd(23, n/512, 1))
		return(-1);
	R(DCTRL) = 0;
	R(DLEN) = n;
	R(DCTRL) = 9<<4;
	if (sdcmd(25|TRANS, bn, 1))
		return(-1);
	in = out = 0;
	left = n;
	t = now();
	for (;;) {
		usbpoll();
		if (rxready && left && in - out <= NRING - 512) {
			usbtake(&ring[(in%NRING)/4]);
			in += rxn;
			left = left > rxn ? left - rxn : 0;
			t = now();
			kick();
		}
		sta = R(STA);
		if (sta & DERR)
			break;
		while (in - out >= 32 && (sta = R(STA)) & TXFIFOHE) {
			register unsigned *p = &ring[(out%NRING)/4];
			__asm__ volatile("ldm %0, {r4-r11}\n\tstm %1, {r4-r11}"
			    : : "r"(p), "r"(SDFIFO)
			    : "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "memory");
			out += 32;
		}
		if (sta & DATAEND)
			break;
		if (now() - t > 640000000)
			break;
	}
	sta = R(STA);
	sdstop(1);
	return(sta & DATAEND && (sta & DERR) == 0 ? 0 : -1);
}

/*
 * Send n bytes read from block bn to USB.
 */
static int
sdread(unsigned bn, unsigned n)
{
	register unsigned in, out, sta, k;
	unsigned t;

	R(DCTRL) = 0;
	R(DLEN) = n;
	R(DCTRL) = 9<<4 | 2;
	if (sdcmd(18|TRANS, bn, 1))
		return(-1);
	in = out = 0;
	t = now();
	while (out < n) {
		sta = R(STA);
		if (sta & DERR || now() - t > 640000000)
			break;
		while (in - out <= NRING - 32 && (sta = R(STA)) & RXFIFOHF) {
			register unsigned *p = &ring[(in%NRING)/4];
			__asm__ volatile("ldm %1, {r4-r11}\n\tstm %0, {r4-r11}"
			    : : "r"(p), "r"(SDFIFO)
			    : "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "memory");
			in += 32;
		}
		if (sta & DATAEND && in < n)
			while (in < n && (R(STA) & RXFIFOE) == 0) {
				ring[(in%NRING)/4] = R(SDFIFO);
				in += 4;
			}
		k = in - out;
		if (k >= 16384 || (k && in >= n)) {
			if (k > 16384)
				k = 16384;
			if (k > NRING - out%NRING)
				k = NRING - out%NRING;
			if (usbsend((unsigned char *)ring + out%NRING, k))
				break;
			out += k;
			t = now();
			kick();
		}
	}
	if (out == n && n%mps == 0)
		(void)usbsend(0, 0);
	sdstop(0);
	return(out == n ? 0 : -1);
}

static unsigned
num(unsigned char **pp)
{
	register unsigned char *p;
	register unsigned n;

	p = *pp;
	while (*p == ' ')
		p++;
	for (n = 0; *p >= '0' && *p <= '9'; p++)
		n = n*10 + *p - '0';
	*pp = p;
	return(n);
}

static int
getln(void)
{
	unsigned buf[128];
	register unsigned i, n;

	n = 0;
	for (;;) {
		usbpoll();
		if (!rxready)
			continue;
		usbtake(buf);
		for (i = 0; i < rxn; i++) {
			if (((unsigned char *)buf)[i] == '\r' || ((unsigned char *)buf)[i] == '\n') {
				line[n] = 0;
				return(n);
			}
			if (n < sizeof line - 1)
				line[n++] = ((unsigned char *)buf)[i];
		}
	}
}

void
main(void)
{
	unsigned char *p;
	unsigned bn, n;
	int e;

	R(RCC+0x728) = 1U<<15;
	R(IWDG) = 0xcccc;
	R(IWDG) = 0x5555;
	R(IWDG+4) = 6;
	R(IWDG+8) = 0xfff;
	kick();
	e = sdinit();
	usbinit();
	for (;;) {
		if (getln() == 0)
			continue;
		kick();
		p = line+1;
		switch (line[0]) {
		case 'i':
			if (e) {
				say("no card\n");
				break;
			}
			say("blocks ");
			putn(nblk);
			say("\n");
			break;
		case 'w':
		case 'r':
			bn = num(&p);
			n = num(&p);
			if (e || n == 0 || n%512 || bn + n/512 > nblk) {
				say("?\n");
				break;
			}
			if (line[0] == 'w')
				say(sdwrite(bn, n) ? "error\n" : "ok\n");
			else if (sdread(bn, n))
				say("error\n");
			break;
		case 'x':
			reset();
			break;
		default:
			say("?\n");
		}
	}
}
