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
#define	NKL11	1
#define	NDL11	0
#define	UARTDR	(*(volatile int *)(KLADDR+0x00))
#define	UARTFR	(*(volatile int *)(KLADDR+0x18))
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
int	klstart();
int	ttrstrt();
int	klirq = 33;
int	ttread(), ttioccomm(), getc();
void	ttyopen(), ttyclose(), ttychars(), ttyinput(), ttstart(), timeout(), wakeup();
caddr_t	ttwrite();

int
klopen(dev, flag)
dev_t dev;
int flag;
{
	register struct tty *tp;
	register int d;

	(void)flag;
	d = minor(dev);
	if(d >= NKL11+NDL11) {
		u.u_error = ENXIO;
		return(0);
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
	return(0);
}

int
klclose(dev, flag)
dev_t dev;
int flag;
{
	register struct tty *tp;

	(void)flag;
	tp = &kl11[minor(dev)];
	ttyclose(tp);
	return(0);
}

int
klread(dev)
dev_t dev;
{
	ttread(&kl11[minor(dev)]);
	return(0);
}

int
klwrite(dev)
dev_t dev;
{
	ttwrite(&kl11[minor(dev)]);
	return(0);
}

void
klxint(dev)
dev_t dev;
{
	register struct tty *tp;

	tp = &kl11[minor(dev)];
	ttstart(tp);
	if (tp->t_state&ASLEEP && tp->t_outq.c_cc<=TTLOWAT)
		wakeup((caddr_t)&tp->t_outq);
}

void
klrint(dev)
dev_t dev;
{
	register int c;
	register struct tty *tp;

	tp = &kl11[minor(dev)];
	c = UARTDR;
	ttyinput(c, tp);
}

int
klioctl(dev, cmd, addr, flag)
caddr_t addr;
dev_t dev;
int cmd, flag;
{
	(void)flag;
	if (ttioccomm(cmd, &kl11[minor(dev)], addr, dev)==0)
		u.u_error = ENOTTY;
	return(0);
}

int
klstart(tp)
register struct tty *tp;
{
	register int c;

	if(UARTFR&TXFF)
		return(0);
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
	return(0);
}

void
klinit()
{
}

int
klintr()
{
	if (UARTMIS&RXI)
		klrint(0);
	if (UARTMIS&TXI) {
		UARTICR = TXI;
		klxint(0);
	}
	return(0);
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
klputchar(char c)
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
		klputchar('\r');
	}
	klputchar(0);
	UARTIMSC = s;
}
