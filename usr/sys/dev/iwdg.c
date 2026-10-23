/*
 * Independent watchdog IWDG2, which resets the board 33 seconds
 * after it was last fed. The kernel starts it before anything
 * else, so that a kernel which stops early still resets; only
 * /etc/wdog feeds it, so that the board stays up only while
 * processes run.
 */
#include "../h/param.h"
#include "../h/systm.h"

#define	R(a)	(*(volatile unsigned int *)(a))
#define	APB4ENSETR	R(0xF0000728)
#define	IWDG(o)	R(0xF0402000+(o))
#define	KR	IWDG(0x00)
#define	PR	IWDG(0x04)
#define	RLR	IWDG(0x08)

void
iwdgstart(void)
{
	APB4ENSETR = 1<<15;
	(void)APB4ENSETR;
	KR = 0xCCCC;
	KR = 0x5555;
	PR = 6;
	RLR = 0xFFF;
	KR = 0xAAAA;
}
