/*
 *   KL/DL-11 driver
 */
#include "../h/param.h"
#include "../h/conf.h"
#include	"../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/systm.h"
#include "../h/board.h"

/* base address */
#if CONSOLE == 2
#define	KLADDR	0xF0C01000	/* USART2 */
#define	CLKENR	(RCC+0x748)	/* RCC_MP_APB6ENSETR */
#define	CLKEN	02
#define	CKSELR	(RCC+0x614)	/* RCC_UART12CKSELR */
#define	CKSEL	3		/* shift of the USART2 field */
#define	IRQ	71
#else
#define	KLADDR	0xF0A10000	/* UART4 */
#define	CLKENR	(RCC+0x700)	/* RCC_MP_APB1ENSETR */
#define	CLKEN	0x10000
#define	CKSELR	(RCC+0x61c)	/* RCC_UART4CKSELR */
#define	CKSEL	0
#define	IRQ	85
#endif
#define	KLBASE	((struct device *)0176500)	/* kl and dl11-a */
#define	DLBASE	((struct device *)0175610)	/* dl-e */
#define	RCC	0xF0000000
#define	GPIO(p, o)	(*(volatile int *)(0xF0002000+(p)*0x1000+(o)))
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
#define	R(a)	(*(volatile int *)(a))
#define	AHB4ENSETR	R(RCC+0x770)
#define	UE	01
#define	RE	04
#define	TE	010
#define	RXNEIE	040
#define	TXEIE	0200
#define	RXNE	040
#define	TXE	0200
#define	FIFOEN	04000000000
#define	DLDELAY	4	/* Extra delay for DL's (double buff) */

#define	NL1	000400
#define	NL2	001000
#define	CR2	020000
#define	FF1	040000
#define	TAB1	002000

struct	tty kl11[NKL11+NDL11];
void	klstart(struct tty *tp);
static void	klrint(dev_t dev);
int	klirq = IRQ;

struct device {
	int	rcsr;
	int	rbuf;
	int	tcsr;
	int	tbuf;
};

/*
 * Give a pin to the console's UART.
 */
static void
pinuart(int port, int pin, int af)
{
	AHB4ENSETR = 1<<port;
	(void)AHB4ENSETR;
	GPIO(port, 0x00) = (GPIO(port, 0x00) & ~(3<<2*pin)) |
	    2<<2*pin;
	GPIO(port, 0x20+pin/8*4) = (GPIO(port, 0x20+pin/8*4) &
	    ~(017<<pin%8*4)) | af<<pin%8*4;
}

void
klinit(void)
{
	pinuart(CONS_TX);
	pinuart(CONS_RX);
	R(CLKENR) = CLKEN;
	(void)R(CLKENR);
	R(CKSELR) = (R(CKSELR) & ~(7<<CKSEL)) | 2<<CKSEL;
	BRR = 556;
	CR1 = FIFOEN|UE|TE|RE;
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
	register int s;

	s = intr_disable();
	ttyunhold(&kl11[minor(dev)]);
	CR1 |= RXNEIE;
	klrint(dev);
	intr_restore(s);
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
	while(ISR&RXNE) {
		if(tp->t_holdq.c_cc >= TTHOLDQ) {
			CR1 &= ~RXNEIE;
			break;
		}
		c = RDR;
		ttyhold(c, tp);
	}
	ICR = 017;
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
klintr(caddr_t pc, int ps)
{
	(void)pc; (void)ps;
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
	register int s;
	unsigned long long timo;

	if (c != '\0' && c != '\r' && c != 0177) {
		*msgbufp++ = c;
		if(msgbufp >= &msgbuf[MSGBUFS])
			msgbufp = msgbuf;
	}
	timo = cntvct_get() + cntfrq_get()/HZ;
	/*
	 * Try waiting for the console tty to come ready,
	 * otherwise give up after a reasonable time.
	 */
	while((ISR&TXE) == 0)
		if(cntvct_get() >= timo)
			break;
	if(c == 0)
		return;
	s = CR1;
	CR1 &= ~TXEIE;
	TDR = c;
	if(c == '\n') {
		putchar('\r');
	}
	putchar(0);
	if(s&TXEIE || kl11[0].t_outq.c_cc)
		CR1 |= TXEIE;
}
