/*
 * Leave the secure world. The boot ROM runs the kernel in secure
 * SVC mode, where SYSRAM and the securable peripherals are its own,
 * but the SD card's DMA is a non-secure master and may not reach
 * them. So, once DDR and its TrustZone controller are set up, which
 * only the secure world may do, everything the kernel uses is opened
 * to the non-secure world: the reset and clock controller, among it
 * the reset which /etc/reset asks for; SYSRAM and every peripheral,
 * through the TrustZone protection controller (ETZPC); and the pins
 * of the GPIO ports. Every interrupt is put in group 1, the
 * non-secure group, and nsenter (mch.s) switches the processor to the
 * non-secure world, with the MMU and caches as they were.
 */
#include "../h/param.h"
#include "../h/systm.h"

#define	R(a)	(*(volatile unsigned int *)(a))
#define	SECCFGR_RCC	R(0xF0008000)
#define	APB5ENSETR	R(0xF0008740)
#define	AHB4ENSETR	R(0xF0008770)
#define	GPIO(n, o)	R(0xF000A000+0x1000*(n)+(o))
#define	SECCFGR	0x30
#define	ETZPC(o)	R(0xF0017000+(o))
#define	TZMA1_SIZE	0x04
#define	DECPROT0	0x10
#define	GICD(o)	R(0xF0000000+(o))
#define	GICC(o)	R(0xF0001000+(o))

void
etzpcinit(void)
{
	register int n;

	SECCFGR_RCC = 0;
	APB5ENSETR = 1<<13;
	(void)APB5ENSETR;
	ETZPC(TZMA1_SIZE) &= ~01777;
	for(n = 0; n < 4; n++)
		ETZPC(DECPROT0+4*n) = ~0U;
	AHB4ENSETR = 0777;
	(void)AHB4ENSETR;
	for(n = 0; n < 9; n++)
		GPIO(n, SECCFGR) = 0;
	GICD(0x000) |= 3;
	GICC(0x000) |= 3;
	GICC(0x004) = 0xFF;
	for(n = 0; n <= 5; n++) {
		GICD(0x180+4*n) = ~0U;
		GICD(0x280+4*n) = ~0U;
		GICD(0x080+4*n) = ~0U;
	}
	nsenter();
}
