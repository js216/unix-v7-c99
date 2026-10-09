/*
 *   KL/DL-11 driver
 */
#include "../h/param.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/systm.h"

/* base address */
#define	KLADDR	0x09000000
#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
#define	DLBASE	((struct device *)0175610)	/* dl-e */
#define	NKL11	1
#define	NDL11	0
#define DSRDY	02
#define	RDRENB	01
#define	UARTDR	(*(volatile int *)(KLADDR+0x00))
#define	UARTFR	(*(volatile int *)(KLADDR+0x18))
#define	UARTCR	(*(volatile int *)(KLADDR+0x30))
#define	UARTIMSC	(*(volatile int *)(KLADDR+0x38))
#define	UARTMIS	(*(volatile int *)(KLADDR+0x40))
#define	UARTICR	(*(volatile int *)(KLADDR+0x44))
#define	TXFF	040
#define	RXI	020
#define	TXI	040
#define	DLDELAY	4	/* Extra delay for DL's (double buff) */

#define	NL1	000400
#define	NL2	001000
#define	CR2	020000
#define	FF1	040000
#define	TAB1	002000

struct	tty kl11[NKL11+NDL11];
void	klstart(struct tty *tp);
int	klirq = 33;

struct device {
	int	rcsr;
	int	rbuf;
	int	tcsr;
	int	tbuf;
};

void
klopen(dev_t dev, int flag)
{
	register struct tty *tp;
	register int d;

	(void)flag;
	d = minor(dev);
	if(d >= NKL11+NDL11) {
		u.u_error = ENXIO;
		return;
	}
	tp = &kl11[d];
	tp->t_oproc = klstart;
	if ((tp->t_state&ISOPEN) == 0) {
		tp->t_state = ISOPEN|CARR_ON;
		tp->t_flags = EVENP|ECHO|XTABS|CRMOD;
		ttychars(tp);
	}
	UARTIMSC = RXI|TXI;
	ttyopen(dev, tp);
}

void
klclose(dev_t dev, int flag)
{
	register struct tty *tp;

	(void)flag;
	tp = &kl11[minor(dev)];
	ttyclose(tp);
}

void
klread(dev_t dev)
{
	ttread(&kl11[minor(dev)]);
}

void
klwrite(dev_t dev)
{
	ttwrite(&kl11[minor(dev)]);
}

static void
klxint(dev_t dev)
{
	register struct tty *tp;

	tp = &kl11[minor(dev)];
	ttstart(tp);
	if (tp->t_state&ASLEEP && tp->t_outq.c_cc<=TTLOWAT)
		wakeup((caddr_t)&tp->t_outq);
}

static void
klrint(dev_t dev)
{
	register int c;
	register struct tty *tp;

	tp = &kl11[minor(dev)];
	c = UARTDR;
	ttyinput(c, tp);
}

void
klioctl(dev_t dev, int cmd, caddr_t addr, int flag)
{
	(void)flag;
	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
		u.u_error = ENOTTY;
}

void
klstart(register struct tty *tp)
{
	register int c;

	if(UARTFR&TXFF)
		return;
	if ((c=getc(&tp->t_outq)) >= 0) {
		if (tp->t_flags&RAW)
			UARTDR = c;
		else if (c<=0177)
			UARTDR = c;
		else {
			timeout(ttrstrt, (caddr_t)tp, (c&0177) + DLDELAY);
			tp->t_state |= TIMEOUT;
		}
	}
}

void
klinit(void)
{
	UARTCR = 0x301;
}

void
klintr(void)
{
	if (UARTMIS&RXI)
		klrint(0);
	if (UARTMIS&TXI) {
		UARTICR = TXI;
		klxint(0);
	}
}

/*
 * Print a character on console.
 * Attempts to save and restore device
 * status.
 * If the switches are 0, all
 * printing is inhibited.
 *
 * Whether or not printing is inhibited,
 * the last MSGBUFS characters
 * are saved in msgbuf for inspection later.
 */
void
putchar(register int c)
{
	register int s, timo;

	if (c != '\0' && c != '\r' && c != 0177) {
		*msgbufp++ = c;
		if(msgbufp >= &msgbuf[MSGBUFS])
			msgbufp = msgbuf;
	}
	timo = 30000;
	/*
	 * Try waiting for the console tty to come ready,
	 * otherwise give up after a reasonable time.
	 */
	while(UARTFR&TXFF)
		if(--timo == 0)
			break;
	if(c == 0)
		return;
	s = UARTIMSC;
	UARTIMSC = 0;
	UARTDR = c;
	if(c == '\n') {
		putchar('\r');
		putchar(0177);
		putchar(0177);
	}
	putchar(0);
	UARTIMSC = s;
}
