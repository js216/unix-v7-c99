/*
 * Console on the USB OTG port, as a CDC-ACM device, for a
 * board reached only by USB. The PHY and clocks are as the
 * boot ROM left them after loading the kernel over USB.
 */
#include "../h/param.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/systm.h"

#define	OTGADDR	0xF0C00000
#define	R(o)	(*(volatile unsigned *)(OTGADDR+(o)))
#define	FIFO(n)	R(0x1000+(n)*0x1000)
#define	GOTGCTL	R(0x000)
#define	GAHBCFG	R(0x008)
#define	GUSBCFG	R(0x00c)
#define	GRSTCTL	R(0x010)
#define	GINTSTS	R(0x014)
#define	GINTMSK	R(0x018)
#define	GRXSTSP	R(0x020)
#define	GRXFSIZ	R(0x024)
#define	DIEPTXF0	R(0x028)
#define	GCCFG	R(0x038)
#define	DIEPTXF(n)	R(0x100+(n)*4)
#define	DCFG	R(0x800)
#define	DCTL	R(0x804)
#define	DSTS	R(0x808)
#define	DIEPMSK	R(0x810)
#define	DOEPMSK	R(0x814)
#define	DAINTMSK	R(0x81c)
#define	DIEPCTL(n)	R(0x900+(n)*0x20)
#define	DIEPINT(n)	R(0x908+(n)*0x20)
#define	DIEPTSIZ(n)	R(0x910+(n)*0x20)
#define	DOEPCTL(n)	R(0xb00+(n)*0x20)
#define	DOEPINT(n)	R(0xb08+(n)*0x20)
#define	DOEPTSIZ(n)	R(0xb10+(n)*0x20)
#define	PCGCCTL	R(0xe00)

#define	EPENA	(1U<<31)
#define	SNAK	(1U<<27)
#define	CNAK	(1U<<26)
#define	SD0PID	(1U<<28)
#define	STALL	(1U<<21)
#define	USBAEP	(1U<<15)
#define	XFRC	01
#define	STUP	010
#define	RXFLVL	(1U<<4)
#define	USBRST	(1U<<12)
#define	ENUMDNE	(1U<<13)
#define	SDIS	02
#define	NOUT	511

struct	tty kl11[1];
void	klstart(struct tty *tp);
static void	klrint(void), klflush(void);
static int	usbpoll(void);
int	klirq = 128;
extern struct cblock	*cfreelist;

static unsigned char setup[8], ep0buf[64], rxbuf[512], out[NOUT];
static unsigned rxlen, rxpos, outlen, bulkmps = 512, ep0len;
static int config, inbusy, dtr;

static const unsigned char devdesc[18] = {
	18, 1, 0x00, 0x02, 2, 0, 0, 64, 0x09, 0x12, 0x01, 0x00,
	0x00, 0x01, 1, 2, 0, 1
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

static const unsigned char lang[4] = { 4, 3, 0x09, 0x04 };
static unsigned char linecoding[7] = { 0x00, 0xc2, 0x01, 0x00, 0, 0, 8 };

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
		FIFO(ep) = w;
	}
}

static void
fiforead(unsigned char *p, unsigned n, unsigned max)
{
	register unsigned i, w;

	for (i = 0; i < n; i += 4) {
		w = FIFO(0);
		if (i < max)
			p[i] = w;
		if (i+1 < max)
			p[i+1] = w >> 8;
		if (i+2 < max)
			p[i+2] = w >> 16;
		if (i+3 < max)
			p[i+3] = w >> 24;
	}
}

static void
ep0out(void)
{
	DOEPTSIZ(0) = 3U<<29 | 1U<<19 | 64;
	DOEPCTL(0) |= EPENA|CNAK;
}

static const unsigned char *ep0p;
static unsigned ep0n;
static int ep0zlp;

static void
ep0next(void)
{
	register unsigned n;

	n = ep0n < 64 ? ep0n : 64;
	DIEPTSIZ(0) = 1U<<19 | n;
	DIEPCTL(0) |= EPENA|CNAK;
	fifowrite(0, ep0p, n);
	ep0p += n;
	ep0n -= n;
	if (n < 64)
		ep0zlp = 0;
}

static void
ep0in(const unsigned char *p, unsigned n)
{
	unsigned want;

	want = setup[6] | setup[7]<<8;
	if (n > want)
		n = want;
	ep0p = p;
	ep0n = n;
	ep0zlp = n < want;
	ep0next();
	ep0out();
}

static void
ep0stall(void)
{
	DIEPCTL(0) |= STALL;
	DOEPCTL(0) |= STALL;
	ep0out();
}

static void
rxarm(void)
{
	DOEPTSIZ(1) = 1U<<19 | bulkmps;
	DOEPCTL(1) |= EPENA|CNAK;
}

static void
dosetup(void)
{
	unsigned char buf[32];
	register unsigned type, req, val, i;
	static const char prod[] = "unix";

	type = setup[0];
	req = setup[1];
	val = setup[2] | setup[3]<<8;
	if ((type&0x60) == 0x20) {
		if (req == 0x20 && (type&0x80) == 0) {
			ep0len = 7;
			ep0out();
		} else if (req == 0x21 && type&0x80)
			ep0in(linecoding, 7);
		else if (req == 0x22 || req == 0x23) {
			if (req == 0x22)
				dtr = val&1;
			ep0in(0, 0);
		} else
			ep0stall();
		return;
	}
	switch (req) {
	case 0:
		buf[0] = type == 0x80;
		buf[1] = 0;
		ep0in(buf, 2);
		return;
	case 1:
	case 3:
	case 11:
		ep0in(0, 0);
		return;
	case 5:
		DCFG = (DCFG & ~(0177U<<4)) | (val&0177)<<4;
		ep0in(0, 0);
		return;
	case 6:
		switch (val>>8) {
		case 1:
			ep0in(devdesc, 18);
			return;
		case 2:
			for (i = 0; i < sizeof cfgdesc; i += cfgdesc[i])
				if (cfgdesc[i+1] == 5 && cfgdesc[i+3] == 2) {
					cfgdesc[i+4] = bulkmps;
					cfgdesc[i+5] = bulkmps >> 8;
				}
			ep0in(cfgdesc, sizeof cfgdesc);
			return;
		case 3:
			if ((val&0xff) == 0) {
				ep0in(lang, 4);
				return;
			}
			if ((val&0xff) <= 2) {
				for (i = 0; prod[i]; i++) {
					buf[2+2*i] = prod[i];
					buf[3+2*i] = 0;
				}
				buf[0] = 2+2*i;
				buf[1] = 3;
				ep0in(buf, buf[0]);
				return;
			}
		}
		ep0stall();
		return;
	case 8:
		buf[0] = config;
		ep0in(buf, 1);
		return;
	case 9:
		config = val&0xff;
		if (config) {
			DIEPCTL(1) = USBAEP | 2U<<18 | 1U<<22 | SD0PID | bulkmps;
			DOEPCTL(1) = USBAEP | 2U<<18 | SD0PID | bulkmps;
			DIEPCTL(2) = USBAEP | 3U<<18 | 2U<<22 | SD0PID | 16;
			inbusy = 0;
			rxlen = rxpos = 0;
			rxarm();
		}
		ep0in(0, 0);
		return;
	case 10:
		buf[0] = 0;
		ep0in(buf, 1);
		return;
	}
	ep0stall();
}

static void
busreset(void)
{
	register int i;

	for (i = 0; i < 4; i++) {
		if (i) {
			DOEPCTL(i) = SNAK;
			DIEPCTL(i) = 0;
		}
		DIEPINT(i) = 0xffff;
		DOEPINT(i) = 0xffff;
	}
	DCFG &= ~(0177U<<4);
	config = dtr = inbusy = 0;
	GRSTCTL = 1U<<5 | 0x10U<<6;
	while (GRSTCTL & 1U<<5)
		;
	ep0out();
}

static void
txflush(void)
{
	if (!config || inbusy || outlen == 0)
		return;
	DIEPTSIZ(1) = (outlen+bulkmps-1)/bulkmps << 19 | outlen;
	DIEPCTL(1) |= EPENA|CNAK;
	fifowrite(1, out, outlen);
	outlen = 0;
	inbusy = 1;
}

static void
klflush(void)
{
	unsigned long long timo;

	timo = cntvct_get() + cntfrq_get()/HZ;
	do
		usbpoll();
	while (inbusy && cntvct_get() < timo);
	txflush();
}

/*
 * Service the controller: called from the interrupt
 * and, with interrupts off, by putchar.
 */
static int
usbpoll(void)
{
	register unsigned s, st, ep, n, k;
	int done;

	done = 0;
	s = GINTSTS;
	if (s & USBRST) {
		GINTSTS = USBRST;
		busreset();
	}
	if (s & ENUMDNE) {
		GINTSTS = ENUMDNE;
		bulkmps = ((DSTS>>1)&3) == 0 ? 512 : 64;
		DIEPCTL(0) &= ~3U;
		DCTL |= 1U<<8;
	}
	while (GINTSTS & RXFLVL) {
		st = GRXSTSP;
		ep = st & 017;
		n = (st>>4) & 03777;
		k = (st>>17) & 017;
		if (k == 6)
			fiforead(setup, n, 8);
		else if (k == 2 && ep == 0)
			fiforead(ep0buf, n, sizeof ep0buf);
		else if (k == 2 && ep == 1) {
			fiforead(rxbuf, n, sizeof rxbuf);
			rxlen = n;
			rxpos = 0;
		} else
			fiforead(0, n, 0);
	}
	st = DOEPINT(0);
	if (st & STUP) {
		DOEPINT(0) = STUP|XFRC|060;
		dosetup();
	} else if (st & XFRC) {
		DOEPINT(0) = XFRC|060;
		if (ep0len) {
			for (n = 0; n < 7; n++)
				linecoding[n] = ep0buf[n];
			ep0len = 0;
			ep0in(0, 0);
		} else
			ep0out();
	}
	if (DIEPINT(0) & XFRC) {
		DIEPINT(0) = XFRC;
		if (ep0n || ep0zlp)
			ep0next();
	}
	if (DIEPINT(1) & XFRC) {
		DIEPINT(1) = XFRC;
		inbusy = 0;
		done = 1;
	}
	st = DOEPINT(1);
	if (st & XFRC) {
		DOEPINT(1) = st;
		if (rxlen == 0)
			rxarm();
	}
	return(done);
}

void
klinit(void)
{
	register int i;
	unsigned long long t;

	DCTL |= SDIS;
	t = cntvct_get() + cntfrq_get()/5;
	while (cntvct_get() < t)
		;
	while ((GRSTCTL & 1U<<31) == 0)
		;
	GRSTCTL = 1;
	while (GRSTCTL & 1)
		;
	GAHBCFG = 0;
	GUSBCFG = (GUSBCFG & ~(1U<<29|1U<<30|017U<<10)) | 1U<<30 | 9U<<10;
	t = cntvct_get() + cntfrq_get()/20;
	while (cntvct_get() < t)
		;
	GCCFG &= ~(1U<<21);
	GOTGCTL |= 1U<<6 | 1U<<7;
	PCGCCTL = 0;
	DCFG = 0;
	GRXFSIZ = 0x100;
	DIEPTXF0 = 0x40U<<16 | 0x100;
	DIEPTXF(1) = 0x100U<<16 | 0x140;
	DIEPTXF(2) = 0x20U<<16 | 0x240;
	GRSTCTL = 1U<<5 | 0x10U<<6;
	while (GRSTCTL & 1U<<5)
		;
	GRSTCTL = 1U<<4;
	while (GRSTCTL & 1U<<4)
		;
	for (i = 0; i < 4; i++) {
		DIEPCTL(i) = 0;
		DOEPCTL(i) = 0;
		DIEPINT(i) = 0xffff;
		DOEPINT(i) = 0xffff;
	}
	DIEPMSK = XFRC;
	DOEPMSK = XFRC|STUP;
	DAINTMSK = 0x30003;
	GINTMSK = RXFLVL | USBRST | ENUMDNE | 1U<<18 | 1U<<19;
	GINTSTS = 0xffffffff;
	DCTL &= ~SDIS;
	t = cntvct_get() + 10*cntfrq_get();
	while (!(config && dtr) && cntvct_get() < t)
		usbpoll();
	t = cntvct_get() + cntfrq_get()/5;
	while (cntvct_get() < t)
		usbpoll();
	GAHBCFG = 1;
}

void
klopen(dev_t dev, int flag)
{
	register struct tty *tp;

	(void)flag;
	if (minor(dev) != 0) {
		u.u_error = ENXIO;
		return;
	}
	tp = &kl11[0];
	tp->t_oproc = klstart;
	if ((tp->t_state&ISOPEN) == 0) {
		tp->t_state = ISOPEN|CARR_ON;
		tp->t_flags = EVENP|ECHO|XTABS|CRMOD;
		ttychars(tp);
	}
	ttyopen(dev, tp);
}

void
klclose(dev_t dev, int flag)
{
	(void)flag;
	ttyclose(&kl11[minor(dev)]);
}

void
klread(dev_t dev)
{
	register int s;

	s = spl5();
	ttyunhold(&kl11[0]);
	klrint();
	splx(s);
	ttread(&kl11[minor(dev)]);
}

void
klwrite(dev_t dev)
{
	ttwrite(&kl11[minor(dev)]);
}

void
klioctl(dev_t dev, int cmd, caddr_t addr, int flag)
{
	(void)flag;
	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
		u.u_error = ENOTTY;
}

static void
klrint(void)
{
	register struct tty *tp;

	tp = &kl11[0];
	if (rxlen == 0)
		return;
	while (rxpos < rxlen) {
		if (tp->t_holdq.c_cc >= TTHOLDQ || cfreelist == NULL ||
		    cfreelist->c_next == NULL)
			return;
		ttyhold(rxbuf[rxpos++], tp);
	}
	rxlen = rxpos = 0;
	if (config)
		rxarm();
}

void
klstart(register struct tty *tp)
{
	register int c;

	if (inbusy || !config)
		return;
	while (outlen < NOUT && (c = getc(&tp->t_outq)) >= 0)
		out[outlen++] = c;
	txflush();
}

void
klintr(void)
{
	register struct tty *tp;

	tp = &kl11[0];
	if (usbpoll()) {
		if (outlen)
			txflush();
		else if (tp->t_state&ISOPEN) {
			ttstart(tp);
			if (tp->t_state&ASLEEP && tp->t_outq.c_cc<=TTLOWAT)
				wakeup((caddr_t)&tp->t_outq);
		}
	}
	klrint();
}

/*
 * Print a character on console.
 * The last MSGBUFS characters
 * are saved in msgbuf for inspection later.
 */
void
putchar(register int c)
{
	register int s;

	if (c != '\0' && c != '\r' && c != 0177) {
		*msgbufp++ = c;
		if(msgbufp >= &msgbuf[MSGBUFS])
			msgbufp = msgbuf;
	}
	if (c == 0 || !config)
		return;
	s = spl7();
	if (outlen >= NOUT-1)
		klflush();
	if (c == '\n')
		out[outlen++] = '\r';
	out[outlen++] = c;
	if (c == '\n')
		klflush();
	splx(s);
}
