#include <stdio.h>
#include <sys/param.h>
#include <sys/times.h>

void	tick(void), work(void);
void	(*volatile fp)(void) = tick;
volatile int x;

void
tick(void)
{
	x++;
}

void
work(void)
{
	struct tms tb;
	int i;

	do
		for (i = 0; i < 100000; i++)
			x++;
	while (times(&tb), tb.tms_utime < HZ);
}

int
main(void)
{
	int i;

	for (i = 0; i < 1000; i++)
		(*fp)();
	work();
	return 0;
}
