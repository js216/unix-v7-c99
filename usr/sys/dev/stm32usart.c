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
#define	KLADDR	0x40010000
#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
#define	DLBASE	((struct device *)0175610)	/* dl-e */
#define	RCC	0x50000000
#define	GPIOD	0x50005000
#define	NKL11	1
#define	NDL11	0
#define DSRDY	02
#define	RDRENB	01
#define	CR1	(*(volatile int *)(KLADDR+0x00))
#define	BRR	(*(volatile int *)(KLADDR+0x0c))
#define	ISR	(*(volatile int *)(KLADDR+0x1c))
#define	ICR	(*(volatile int *)(KLADDR+0x20))
#define	RDR	(*(volatile int *)(KLADDR+0x24))
#define	TDR	(*(volatile int *)(KLADDR+0x28))
#define	UART4CKSELR	(*(volatile int *)(RCC+0x61c))
#define	APB1ENSETR	(*(volatile int *)(RCC+0x700))
#define	AHB4ENSETR	(*(volatile int *)(RCC+0x770))
#define	GPIOD_MODER	(*(volatile int *)(GPIOD+0x00))
#define	GPIOD_AFRL	(*(volatile int *)(GPIOD+0x20))
#define	GPIOD_AFRH	(*(volatile int *)(GPIOD+0x24))
#define	UE	01
#define	RE	04
#define	TE	010
#define	RXNEIE	040
#define	TXEIE	0200
#define	RXNE	040
#define	TXE	0200
#define	DLDELAY	4	/* Extra delay for DL's (double buff) */

#define	NL1	000400
#define	NL2	001000
#define	CR2	020000
#define	FF1	040000
#define	TAB1	002000

struct	tty kl11[NKL11+NDL11];
void	klstart(struct tty *tp);
int	klirq = 85;

struct device {
	int	rcsr;
	int	rbuf;
	int	tcsr;
	int	tbuf;
};

void
klinit(void)
{
	AHB4ENSETR = 010;
	(void)AHB4ENSETR;
	GPIOD_MODER = (GPIOD_MODER & ~(3<<12|3<<16)) | 2<<12 | 2<<16;
	GPIOD_AFRL = (GPIOD_AFRL & ~(017<<24)) | 8<<24;
	GPIOD_AFRH = (GPIOD_AFRH & ~017) | 8;
	APB1ENSETR = 0x10000;
	(void)APB1ENSETR;
	UART4CKSELR = (UART4CKSELR & ~7) | 2;
	BRR = 556;
	CR1 = UE|TE|RE;
}

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
	CR1 |= RXNEIE;
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
	CR1 &= ~TXEIE;
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
	c = RDR;
	ICR = 017;
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

	if((ISR&TXE) == 0)
		return;
	if ((c=getc(&tp->t_outq)) >= 0) {
		if (tp->t_flags&RAW)
			TDR = c;
		else if (c<=0177)
			TDR = c;
		else {
			timeout(ttrstrt, (caddr_t)tp, (c&0177) + DLDELAY);
			tp->t_state |= TIMEOUT;
		}
		CR1 |= TXEIE;
	}
}

void
klintr(void)
{
	if (ISR&RXNE)
		klrint(0);
	if (ISR&TXE && CR1&TXEIE)
		klxint(0);
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
	while((ISR&TXE) == 0)
		if(--timo == 0)
			break;
	if(c == 0)
		return;
	s = CR1;
	CR1 &= ~TXEIE;
	TDR = c;
	if(c == '\n') {
		putchar('\r');
		putchar(0177);
		putchar(0177);
	}
	putchar(0);
	CR1 = s;
}
