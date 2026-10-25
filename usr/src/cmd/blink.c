/*
 * Blink the Odyssey's user LEDs, red, yellow, and blue, one after
 * another, each for a second, until interrupted.
 */

#include <stdio.h>

#define	AHB4ENSETR	0x50000770L
#define	GPIOC	0x50004000L
#define	GPIOH	0x50009000L
#define	MODER	0x00
#define	BSRR	0x18
#define	NLED	3

static long	port[NLED] = { GPIOH, GPIOC, GPIOH };
static int	pin[NLED] = { 2, 3, 5 };

static int
get(int mem, long a)
{
	int v;

	lseek(mem, a, 0);
	read(mem, (char *)&v, 4);
	return(v);
}

static void
put(int mem, long a, int v)
{
	lseek(mem, a, 0);
	write(mem, (char *)&v, 4);
}

static void
init_led(int mem, int n)
{
	long a;

	a = port[n]+MODER;
	put(mem, a, (get(mem, a) & ~(3<<2*pin[n])) | 1<<2*pin[n]);
}

static void
set_led(int mem, int n, int on)
{
	put(mem, port[n]+BSRR, on ? 1<<pin[n] : 1<<16<<pin[n]);
}

int
main(void)
{
	int mem, n;

	if((mem = open("/dev/mem", 2)) < 0) {
		perror("/dev/mem");
		exit(1);
	}
	put(mem, AHB4ENSETR, 1<<2 | 1<<7);
	for(n = 0; n < NLED; n++)
		init_led(mem, n);
	for(n = 0; ; n = (n+1) % NLED) {
		set_led(mem, n, 1);
		sleep(1);
		set_led(mem, n, 0);
	}
}
