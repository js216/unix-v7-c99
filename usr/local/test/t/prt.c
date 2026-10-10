#include <stdio.h>

int profil(char *buf, int size, int offset, int scale);
unsigned short buf[4096];
volatile int x;

int
main(void)
{
	int i, n;
	long t;

	profil((char *)buf, sizeof buf, 0, 0x8000);
	t = time(0);
	while (time(0) < t + 3)
		for (i = 0; i < 1000; i++)
			x++;
	profil((char *)buf, sizeof buf, 0, 0);
	for (n = i = 0; i < 4096; i++)
		n += buf[i];
	printf("ticks %d\n", n);
	return 0;
}
