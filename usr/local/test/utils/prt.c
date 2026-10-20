#include <stdio.h>
#include <sys/param.h>
#include <sys/times.h>

unsigned short buf[4096];
volatile int x;

int
main(void)
{
	struct tms tb;
	int i, n;

	profil((short *)buf, sizeof buf, (int)main & ~0xfff, 0x8000);
	do
		for (i = 0; i < 1000; i++)
			x++;
	while (times(&tb), tb.tms_utime < HZ/2);
	profil((short *)buf, sizeof buf, 0, 0);
	for (n = i = 0; i < 4096; i++)
		n += buf[i];
	printf("ticks %d\n", n);
	return 0;
}
