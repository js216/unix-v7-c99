#include <stdio.h>

char big[8*1024*1024];
char *sbrk(int incr);

static int
stk(void)
{
	volatile char a[3*1024*1024];
	unsigned i;
	int s;

	for (i = 0; i < sizeof(a); i += 4096)
		a[i] = 1;
	s = 0;
	for (i = 0; i < sizeof(a); i += 4096)
		s += a[i];
	return s;
}

int
main(void)
{
	unsigned i;
	int s;
	char *p;

	printf("stack pages %d\n", stk());
	for (i = 0; i < sizeof(big); i += 4096)
		big[i] = i >> 12;
	s = 0;
	for (i = 0; i < sizeof(big); i += 4096)
		s += big[i] == (char)(i >> 12);
	printf("bss pages %d, end above 8 MB %d\n", s,
		(unsigned)&big[sizeof(big)-1] >= 8*1024*1024);
	p = sbrk(16*1024*1024);
	for (i = 0; i < 16*1024*1024; i += 4096)
		p[i] = i >> 12;
	s = 0;
	for (i = 0; i < 16*1024*1024; i += 4096)
		s += p[i] == (char)(i >> 12);
	printf("sbrk pages %d\n", s);
	printf("beyond memory %d\n", sbrk(1024*1024*1024) == (char *)-1);
	return 0;
}
