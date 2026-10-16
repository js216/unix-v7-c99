/*
 * Start the STM32MP1's watchdog, IWDG2, and feed it every 10 seconds.
 * Should this stop, the board resets after 33 seconds.
 */

#include <signal.h>
#include <stdio.h>

#define	APB4ENSETR	0x50000728L
#define	IWDG	0x5a002000L

int	mem;

void	put(long a, int v);

void
put(long a, int v)
{
	lseek(mem, a, 0);
	write(mem, (char *)&v, 4);
}

void feed(int sig);
int
main(void)
{
	if((mem = open("/dev/mem", 1)) < 0) {
		perror("/dev/mem");
		exit(1);
	}
	if(fork())
		exit(0);
	close(0);
	close(1);
	close(2);
	put(APB4ENSETR, 1<<15);
	put(IWDG, 0xcccc);
	put(IWDG, 0x5555);
	put(IWDG+4, 6);
	put(IWDG+8, 0xfff);
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
