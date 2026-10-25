/*
 * Feed the STM32MP1's watchdog, IWDG2, every 10 seconds; the kernel
 * starts it at boot, and init starts wdog. Should this stop, the
 * board resets 33 seconds after the last feed. Unless the reload
 * register holds the kernel's 0xfff, there is no watchdog, as on
 * QEMU, and wdog exits at once.
 */

#include <signal.h>
#include <stdio.h>

#define	IWDG	0x5a002000L

int	mem;

int	get(long a);
int	put(long a, int v);

int
get(long a)
{
	int v;

	lseek(mem, a, 0);
	if(read(mem, (char *)&v, 4) != 4)
		return(-1);
	return(v);
}

int
put(long a, int v)
{
	lseek(mem, a, 0);
	return(write(mem, (char *)&v, 4));
}

void feed(int sig);
int
main(void)
{
	if(fork())
		exit(0);
	close(0);
	close(1);
	close(2);
	if((mem = open("/dev/mem", 2)) < 0 || get(IWDG+8) != 0xfff)
		exit(0);
	feed(0);
	for(;;)
		pause();
}

void
feed(int sig)
{
	(void)sig;
	put(IWDG, 0xaaaa);
	signal(SIGALRM, feed);
	alarm(10);
}
