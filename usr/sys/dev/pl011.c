/*
 *   PL011 UART console driver
 *
 * The console is the QEMU virt PL011.  It is a normal Unix character
 * device: the cdevsw open/close/read/write/ioctl entries hang the line
 * discipline (tty.c) off it, output is paced by the transmit interrupt,
 * and input arrives on the receive interrupt -- the same model the v7
 * kl.c console driver follows, but for PL011 hardware.  The PL011 raises
 * a single GIC line (INTID 33); its receive and transmit causes are told
 * apart by the masked-interrupt-status register rather than by separate
 * PDP-11 vectors.
 */
#include "../h/param.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/systm.h"

#ifdef PL011

#define	PL011_BASE	0x09000000	/* QEMU virt UART0 */
#define	NCONS	1			/* one console line */
#define	OUTDELAY 4		/* slop added to ttyoutput delay characters */

#define	UARTDR		(*(volatile unsigned int *)(PL011_BASE+0x000))
#define	UARTFR		(*(volatile unsigned int *)(PL011_BASE+0x018))
#define	UARTLCRH	(*(volatile unsigned int *)(PL011_BASE+0x02c))
#define	UARTIMSC	(*(volatile unsigned int *)(PL011_BASE+0x038))
#define	UARTMIS		(*(volatile unsigned int *)(PL011_BASE+0x040))
#define	UARTICR		(*(volatile unsigned int *)(PL011_BASE+0x044))
#define	TXFF	0x20		/* FR: transmit holding register full */
#define	RXFE	0x10		/* FR: receive holding register empty */
#define	FEN	0x10		/* LCRH: FIFO enable */
#define	RXI	0x10		/* interrupt: receiver */
#define	TXI	0x20		/* interrupt: transmitter */
#define	RTI	0x40		/* interrupt: receive timeout */

struct	tty cons[NCONS];
char	*msgbufp = msgbuf;	/* next saved printf character */
int	cn_irq = 33;		/* GIC INTID of the PL011 console (SPI 1) */

extern char partab[];
void ttyopen(dev_t dev, struct tty *tp);
void ttyclose(struct tty *tp);
void ttychars(struct tty *tp);
int ttread(struct tty *tp);
caddr_t ttwrite(struct tty *tp);
int ttioccomm(int com, struct tty *tp, caddr_t addr, dev_t dev);
void ttyinput(int c, struct tty *tp);
void ttstart(struct tty *tp);
int ttrstrt(struct tty *tp);
void timeout(int (*fun)(), caddr_t arg, int tim);
void wakeup(caddr_t chan);
int getc(struct clist *p);
int cnstart(struct tty *tp);
int cnrint(dev_t dev);
int cnxint(dev_t dev);

/*
 * QEMU configures the PL011 (clock, baud, enable) before the kernel runs, so
 * the console needs no hardware setup; cninit() exists only to satisfy the
 * machine layer's board-agnostic early console-init hook (machine_init), which
 * the MP135 build uses to bring UART4 up from HSI.
 */
void
cninit(void)
{
}

int
cnopen(dev_t dev, int flag)
{
	register struct tty *tp;

	(void)flag;
	if(minor(dev) >= NCONS) {
		u.u_error = ENXIO;
		return(0);
	}
	tp = &cons[minor(dev)];
	tp->t_addr = (caddr_t)PL011_BASE;
	tp->t_oproc = cnstart;
	if ((tp->t_state&ISOPEN) == 0) {
		tp->t_state = ISOPEN|CARR_ON;
		tp->t_flags = EVENP|ODDP|ECHO|XTABS|CRMOD;
		ttychars(tp);
	}
	UARTLCRH &= ~FEN;		/* one transmit interrupt per character */
	UARTIMSC |= RXI|RTI;		/* enable receive interrupts */
	ttyopen(dev, tp);
	return(0);
}

int
cnclose(dev_t dev, int flag)
{
	(void)flag;
	ttyclose(&cons[minor(dev)]);
	return(0);
}

int
cnread(dev_t dev)
{
	ttread(&cons[minor(dev)]);
	return(0);
}

int
cnwrite(dev_t dev)
{
	ttwrite(&cons[minor(dev)]);
	return(0);
}

/*
 * Transmitter ready: hand the next queued character to the PL011.  Output
 * delays (characters above 0177, produced by ttyoutput for slow terminals)
 * are honored as in the v7 console driver.  The transmit interrupt is
 * level-sensitive, so it is masked whenever the output queue drains.
 */
int
cnstart(struct tty *tp)
{
	register int c;

	if (UARTFR & TXFF)
		return(0);
	if ((c=getc(&tp->t_outq)) >= 0) {
		if (tp->t_flags&RAW)
			UARTDR = c & 0177;	/* 8N1 glass tty: no parity bit */
		else if (c<=0177)
			UARTDR = c;
		else {
			timeout(ttrstrt, (caddr_t)tp, (c&0177) + OUTDELAY);
			tp->t_state |= TIMEOUT;
			UARTIMSC &= ~TXI;
			return(0);
		}
		UARTIMSC |= TXI;
	} else
		UARTIMSC &= ~TXI;
	return(0);
}

int
cnxint(dev_t dev)
{
	register struct tty *tp;

	tp = &cons[minor(dev)];
	ttstart(tp);
	if ((tp->t_state&ASLEEP) && tp->t_outq.c_cc<=TTLOWAT)
		wakeup((caddr_t)&tp->t_outq);
	return(0);
}

int
cnrint(dev_t dev)
{
	register int c;
	register struct tty *tp;

	tp = &cons[minor(dev)];
	while ((UARTFR & RXFE) == 0) {
		c = UARTDR;
		ttyinput(c, tp);
	}
	return(0);
}

int
cnioctl(dev_t dev, int cmd, caddr_t addr, int flag)
{
	(void)flag;
	if (ttioccomm(cmd, &cons[minor(dev)], addr, dev)==0)
		u.u_error = ENOTTY;
	return(0);
}

/*
 * Console interrupt.  One GIC line serves the PL011; the masked-interrupt-
 * status register says whether the receiver, transmitter, or both need
 * service, demultiplexing into the receive/transmit halves above.
 */
int
cnintr(void)
{
	register unsigned int mis;

	mis = UARTMIS;
	if (mis & (RXI|RTI)) {
		UARTICR = RXI|RTI;
		cnrint(0);
	}
	if (mis & TXI) {
		UARTICR = TXI;
		cnxint(0);
	}
	return(0);
}

/*
 * Print a character on the console (cf. kl.c).  The last MSGBUFS characters
 * are saved in msgbuf for inspection.  Polled with a bounded spin, and the
 * transmit interrupt is masked around the write -- the PL011 analog of kl.c
 * saving and clearing the DL11 control register -- so kernel printf does not
 * collide with interrupt-driven tty output and still works before the console
 * is open and from panic context.  The DL11's console-switch check and
 * inter-character rubout padding have no PL011 equivalent and are dropped.
 */
void
putchar(char c)
{
	register int timo;
	unsigned int s;

	if (c != '\0' && c != '\r' && c != 0177) {
		*msgbufp++ = c;
		if (msgbufp >= &msgbuf[MSGBUFS])
			msgbufp = msgbuf;
	}
	timo = 30000;
	while (UARTFR & TXFF)
		if (--timo == 0)
			break;
	if (c == 0)
		return;
	s = UARTIMSC;
	UARTIMSC &= ~TXI;
	UARTDR = c;
	if (c == '\n')
		putchar('\r');
	UARTIMSC = s;
}

#endif
