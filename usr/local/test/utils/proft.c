#include <stdio.h>

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
	long long t;
	int i;

	t = time(0);
	while (time(0) < t + 2)
		for (i = 0; i < 1000; i++)
			x++;
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
