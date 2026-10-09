/*
 *   STM32 USART console driver (UART4 on the MP135 board)
 */
#include "../h/param.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/systm.h"


#define	UART4	0x40010000U		/* APB1 UART4 */
#define	RCC	0x50000000U		/* reset/clock controller */
#define	NCONS	1			/* one console line */
#define	OUTDELAY 4		/* slop added to ttyoutput delay characters */

#define	CR1	(*(volatile unsigned int *)(UART4+0x00))
#define	BRR	(*(volatile unsigned int *)(UART4+0x0c))
#define	ISR	(*(volatile unsigned int *)(UART4+0x1c))
#define	ICR	(*(volatile unsigned int *)(UART4+0x20))
#define	RDR	(*(volatile unsigned int *)(UART4+0x24))
#define	TDR	(*(volatile unsigned int *)(UART4+0x28))
#define	APB1ENSETR (*(volatile unsigned int *)(RCC+0x700))	/* APB1 clk set-reg */
#define	UART4CKSELR (*(volatile unsigned int *)(RCC+0x61c))	/* UART4 kernel clk sel */
#define	AHB4ENSETR (*(volatile unsigned int *)(RCC+0x770))	/* AHB4 (non-secure) clk set */
#define	GPIODEN	0x00000008U		/* AHB4ENSETR bit 3: GPIOD bus clock */
#define	GPIOD	0x50005000U		/* GPIO port D (UART4 pins) */
#define	GPIOD_MODER (*(volatile unsigned int *)(GPIOD+0x00))
#define	GPIOD_AFRL  (*(volatile unsigned int *)(GPIOD+0x20))	/* AF for pins 0-7 */
#define	GPIOD_AFRH  (*(volatile unsigned int *)(GPIOD+0x24))	/* AF for pins 8-15 */
#define	CR1_UE	0x00000001U		/* USART enable */
#define	CR1_RE	0x00000004U		/* receiver enable */
#define	CR1_TE	0x00000008U		/* transmitter enable */
#define	CR1_RXNEIE 0x00000020U		/* receive-not-empty interrupt enable */
#define	CR1_TXEIE  0x00000080U		/* transmit-empty interrupt enable */
#define	CR1_FIFOEN 0x20000000U		/* enable RX/TX FIFOs */
#define	ISR_RXNE 0x00000020U		/* read data register not empty */
#define	ISR_TXE	0x00000080U		/* transmit data register empty */
#define	ICR_ERR	0x0000000fU		/* clear PE/FE/NE/ORE error flags */
#define	UART4EN	0x00010000U		/* APB1ENSETR bit 16: UART4 bus clock */
#define	UART4SRC_HSI 0x00000002U	/* UART4CKSELR: kernel clock = HSI (64 MHz) */

struct	tty cons[NCONS];
int	usirq = 85;		/* GIC INTID of the UART4 console (SPI 53) */
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
int usstart(struct tty *tp);
int usrint(dev_t dev);
int usxint(dev_t dev);
void usputchar(char c);

void
usinit(void)
{
	AHB4ENSETR = GPIODEN;
	(void)AHB4ENSETR;			/* read-back: clock live before access */
	GPIOD_MODER = (GPIOD_MODER & ~((3U<<12)|(3U<<16))) | (2U<<12) | (2U<<16);
	GPIOD_AFRL = (GPIOD_AFRL & ~(0xfU<<24)) | (8U<<24);	/* PD6 -> AF8 */
	GPIOD_AFRH = (GPIOD_AFRH & ~(0xfU<<0))  | (8U<<0);	/* PD8 -> AF8 */

	APB1ENSETR = UART4EN;
	(void)APB1ENSETR;			/* read-back: clock live before access */
	UART4CKSELR = (UART4CKSELR & ~7U) | UART4SRC_HSI;
	CR1 = 0;
	BRR = 556;
	CR1 = CR1_FIFOEN | CR1_UE | CR1_TE | CR1_RE;
}

int
usopen(dev_t dev, int flag)
{
	register struct tty *tp;

	(void)flag;
	if(minor(dev) >= NCONS) {
		u.u_error = ENXIO;
		return(0);
	}
	tp = &cons[minor(dev)];
	tp->t_addr = (caddr_t)UART4;
	tp->t_oproc = usstart;
	if ((tp->t_state&ISOPEN) == 0) {
		tp->t_state = ISOPEN|CARR_ON;
		tp->t_flags = EVENP|ODDP|ECHO|XTABS|CRMOD;
		ttychars(tp);
	}
	CR1 |= CR1_RXNEIE;
	ttyopen(dev, tp);
	return(0);
}

int
usclose(dev_t dev, int flag)
{
	(void)flag;
	ttyclose(&cons[minor(dev)]);
	return(0);
}

int
usread(dev_t dev)
{
	ttread(&cons[minor(dev)]);
	return(0);
}

int
uswrite(dev_t dev)
{
	ttwrite(&cons[minor(dev)]);
	return(0);
}

int
usstart(struct tty *tp)
{
	register int c;

	if ((ISR & ISR_TXE) == 0)
		return(0);
	if ((c=getc(&tp->t_outq)) >= 0) {
		if (tp->t_flags&RAW)
			TDR = c & 0177;
		else if (c<=0177)
			TDR = c;
		else {
			timeout(ttrstrt, (caddr_t)tp, (c&0177) + OUTDELAY);
			tp->t_state |= TIMEOUT;
			CR1 &= ~CR1_TXEIE;
			return(0);
		}
		CR1 |= CR1_TXEIE;
	} else
		CR1 &= ~CR1_TXEIE;
	return(0);
}

int
usxint(dev_t dev)
{
	register struct tty *tp;

	tp = &cons[minor(dev)];
	ttstart(tp);
	if ((tp->t_state&ASLEEP) && tp->t_outq.c_cc<=TTLOWAT)
		wakeup((caddr_t)&tp->t_outq);
	return(0);
}

int
usrint(dev_t dev)
{
	register int c;
	register struct tty *tp;

	tp = &cons[minor(dev)];
	while (ISR & ISR_RXNE) {
		c = RDR;
		ttyinput(c, tp);
	}
	ICR = ICR_ERR;
	return(0);
}

int
usioctl(dev_t dev, int cmd, caddr_t addr, int flag)
{
	(void)flag;
	if (ttioccomm(cmd, &cons[minor(dev)], addr, dev)==0)
		u.u_error = ENOTTY;
	return(0);
}

int
usintr(void)
{
	unsigned int isr = ISR;

	if (isr & ISR_RXNE)
		usrint(0);
	if ((isr & ISR_TXE) && (CR1 & CR1_TXEIE))
		usxint(0);
	return(0);
}


void
usputchar(char c)
{
	register int timo;
	unsigned int s;

	if (c != '\0' && c != '\r' && c != 0177) {
		*msgbufp++ = c;
		if (msgbufp >= &msgbuf[MSGBUFS])
			msgbufp = msgbuf;
	}
	timo = 30000;
	while ((ISR & ISR_TXE) == 0)
		if (--timo == 0)
			break;
	if (c == 0)
		return;
	s = CR1;
	CR1 &= ~CR1_TXEIE;
	TDR = c;
	if (c == '\n')
		usputchar('\r');
	CR1 = s;
}

