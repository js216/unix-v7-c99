/*
 *   STM32 USART console driver (UART4 on the MP135 board)
 *
 * Same Unix character-device/tty model as kl.c/pl011.c -- the cdevsw
 * open/close/read/write/ioctl entries hang the line discipline (tty.c) off
 * the console, output is paced by the transmit interrupt and input arrives
 * on the receive interrupt.  Differs only in the hardware: an STM32 USART
 * (UART4) instead of a PL011, one GIC line (INTID 85) demultiplexed via the
 * interrupt/status register.  This file is built for both boards but is the
 * live console only on the MP135 (the QEMU build uses pl011.c); its register
 * pokes are never reached on QEMU because /dev/console there has a different
 * major.
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
#define	ISR_RXNE 0x00000020U		/* read data register not empty */
#define	ISR_TXE	0x00000080U		/* transmit data register empty */
#define	ICR_ERR	0x0000000fU		/* clear PE/FE/NE/ORE error flags */
#define	UART4EN	0x00010000U		/* APB1ENSETR bit 16: UART4 bus clock */
#define	UART4SRC_HSI 0x00000002U	/* UART4CKSELR: kernel clock = HSI (64 MHz) */

struct	tty cons[NCONS];
int	cn_irq = 85;		/* GIC INTID of the UART4 console (SPI 53) */
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
void putchar(char c);			/* defined below */

/*
 * Bring UART4 up for the console before the first kernel printf: enable its
 * APB1 bus clock and select HSI (64 MHz, running at reset) as the kernel
 * clock, then program 115200 8N1 -- BRR = 64e6/115200 = 556 (oversampling 16)
 * -- and enable the transmitter and receiver.  Because UART4 runs off HSI, the
 * console works at the ROM's default clocks, before clock_init() sets up the
 * PLLs -- so even early boot and panics are visible.  Called from machine_init
 * via the board-agnostic console hook.  Values imported from the reference
 * bootloader (UART4 TX=PD6, RX=PD8, AF8; 115200; HSI source).
 * GPIOD's clock is enabled through the non-secure AHB4ENSETR (RCC+0x770),
 * matching the reference bootloader's __HAL_RCC_GPIOD_CLK_ENABLE; the secure
 * register (0x768) leaves the port unclocked so the pin mux silently no-ops.
 */
void
cninit(void)
{
	/* Route UART4 to its pads: PD6 (TX) and PD8 (RX) -> alternate function 8.
	 * Without this the UART would transmit into a disconnected pin. */
	AHB4ENSETR = GPIODEN;			/* GPIOD bus clock (set-register) */
	(void)AHB4ENSETR;			/* read-back: clock live before access */
	GPIOD_MODER = (GPIOD_MODER & ~((3U<<12)|(3U<<16))) | (2U<<12) | (2U<<16);
	GPIOD_AFRL = (GPIOD_AFRL & ~(0xfU<<24)) | (8U<<24);	/* PD6 -> AF8 */
	GPIOD_AFRH = (GPIOD_AFRH & ~(0xfU<<0))  | (8U<<0);	/* PD8 -> AF8 */

	APB1ENSETR = UART4EN;			/* UART4 bus clock (set-register) */
	(void)APB1ENSETR;			/* read-back: clock live before access */
	UART4CKSELR = (UART4CKSELR & ~7U) | UART4SRC_HSI;
	CR1 = 0;				/* disable before reconfigure */
	BRR = 556;				/* 64 MHz / 115200 */
	CR1 = CR1_UE | CR1_TE | CR1_RE;		/* 8N1, TX + RX enabled */
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
	tp->t_addr = (caddr_t)UART4;
	tp->t_oproc = cnstart;
	if ((tp->t_state&ISOPEN) == 0) {
		tp->t_state = ISOPEN|CARR_ON;
		tp->t_flags = EVENP|ODDP|ECHO|XTABS|CRMOD;
		ttychars(tp);
	}
	CR1 |= CR1_RXNEIE;		/* enable receive interrupts */
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
 * Transmitter ready: hand the next queued character to UART4.  Output
 * delays (characters above 0177) are honored as in the v7 console driver;
 * the transmit-empty interrupt is level-sensitive, so it is masked whenever
 * the output queue drains.
 */
int
cnstart(struct tty *tp)
{
	register int c;

	if ((ISR & ISR_TXE) == 0)
		return(0);
	if ((c=getc(&tp->t_outq)) >= 0) {
		if (tp->t_flags&RAW)
			TDR = c & 0177;	/* 8N1 glass tty: no parity bit */
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
	while (ISR & ISR_RXNE) {
		c = RDR;
		ttyinput(c, tp);
	}
	ICR = ICR_ERR;			/* clear overrun/framing errors */
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
 * Console interrupt.  One GIC line serves UART4; the interrupt/status
 * register says whether the receiver, transmitter, or both need service,
 * demultiplexing into the receive/transmit halves above.
 */
int
cnintr(void)
{
	unsigned int isr = ISR;

	if (isr & ISR_RXNE)
		cnrint(0);
	if ((isr & ISR_TXE) && (CR1 & CR1_TXEIE))
		cnxint(0);
	return(0);
}

char	*msgbufp = msgbuf;	/* next saved printf character */

/*
 * Print a character on the console (cf. kl.c).  Polled with a bounded spin,
 * the transmit interrupt masked around the write so kernel printf does not
 * collide with interrupt-driven tty output; works before the console is open
 * and from panic context.  The last MSGBUFS characters are saved in msgbuf.
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
	while ((ISR & ISR_TXE) == 0)
		if (--timo == 0)
			break;
	if (c == 0)
		return;
	s = CR1;
	CR1 &= ~CR1_TXEIE;
	TDR = c;
	if (c == '\n')
		putchar('\r');
	CR1 = s;
}
