/*
 * STPMIC1 power management chip, on I2C4
 */
#include "../h/param.h"
#include "../h/systm.h"

#define	R(a)	(*(volatile unsigned int *)(a))
#define	RCC(o)	R(0xF0000000+(o))
#define	GPIO(p, o)	R(0xF0002000+(p)*0x1000+(o))
#define	I2C(o)	R(0xF0C05000+(o))

static int
i2cwait(unsigned int bit)
{
	unsigned long long t;

	t = cntvct_get() + cntfrq_get()/10;
	while ((I2C(0x18) & bit) == 0)
		if (I2C(0x18) & 0x10 || cntvct_get() > t) {
			I2C(0x1C) = 0x30;
			return(-1);
		}
	return(0);
}

static int
pmic(unsigned int reg, int val)
{
	I2C(0x04) = 0x33<<1 | (val < 0 ? 1 : 2)<<16 | 1<<13 | (val < 0 ? 0 : 1<<25);
	if (i2cwait(2))
		return(-1);
	I2C(0x28) = reg;
	if (val < 0) {
		if (i2cwait(0x40))
			return(-1);
		I2C(0x04) = 0x33<<1 | 1<<10 | 1<<16 | 1<<13 | 1<<25;
		if (i2cwait(4))
			return(-1);
		val = I2C(0x24);
	} else {
		if (i2cwait(2))
			return(-1);
		I2C(0x28) = val;
	}
	if (i2cwait(0x20))
		return(-1);
	I2C(0x1C) = 0x20;
	return(val);
}

static void
pinmode(int port, int pin, int mode)
{
	GPIO(port, 0x00) = (GPIO(port, 0x00) & ~(3<<2*pin)) | mode<<2*pin;
	GPIO(port, 0x04) |= 1<<pin;
	GPIO(port, 0x20+pin/8*4) = (GPIO(port, 0x20+pin/8*4) & ~(0xF<<pin%8*4)) | 6<<pin%8*4;
}

/*
 * Power the DDR: BUCK2 at 1.35 V and VREF_DDR of the STPMIC1,
 * on I2C4. SCL is PE15; SDA is PB9 on the DK board, PB7 on
 * the Odyssey, whichever answers.
 */
void
ddrpower(void)
{
	static int sda[] = { 9, 7 };
	unsigned long long t;
	int i;

	RCC(0x770) = 0x12;
	(void)RCC(0x770);
	pinmode(4, 15, 2);
	RCC(0x604) = (RCC(0x604) & ~0x38) | 0x10;
	RCC(0x748) = 0x20;
	(void)RCC(0x748);
	I2C(0x10) = 0x10805E89;
	for (i = 0; ; i++) {
		if (i == 2)
			panic("pmic");
		pinmode(1, sda[i], 2);
		I2C(0x00) = 1;
		if (pmic(0x06, -1) >= 0)
			break;
		I2C(0x00) = 0;
		pinmode(1, sda[i], 3);
	}
	if (pmic(0x21, 30<<2 | 1) < 0 || pmic(0x24, 1) < 0)
		panic("pmic");
	t = cntvct_get() + cntfrq_get()/100;
	while (cntvct_get() < t)
		;
}
