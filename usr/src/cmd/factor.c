#include <stdio.h>

#define	BIG	72057594037927936

char	tab[] = {
	10, 2, 4, 2, 4, 6, 2, 6, 4, 2, 4, 6, 6, 2, 6, 4,
	2, 6, 4, 6, 8, 4, 2, 4, 2, 4, 8, 6, 4, 6, 2, 4,
	6, 2, 6, 6, 4, 2, 4, 6, 2, 6, 4, 2, 4, 2, 10, 2
};
char	*arg;
long long n;

static int
getch(void)
{
	int c;

	if(arg)
		return(*arg++);
	if((c = getchar()) == EOF)
		exit(0);
	return(c);
}

static void
put(long long d)
{
	char b[20], *s;

	s = b;
	do
		*s++ = d%10 + '0';
	while(d /= 10);
	printf("     ");
	while(s > b)
		putchar(*--s);
	putchar('\n');
}

int
main(int argc, char **argv)
{
	register int c, i;
	long long d;

	if(argc >= 2)
		arg = argv[1];
	for(;;) {
		n = 0;
		while((c = getch()) == ' ' || (c >= '0' && c <= '9'))
			if(c != ' ' && n < BIG)
				n = n*10 + c - '0';
		if(n == 0)
			exit(0);
		if(n >= BIG)
			fprintf(stderr, "Ouch.\n");
		else {
			putchar('\n');
			for(d = 2, i = 3; d*d <= n; ) {
				if(n%d == 0) {
					put(d);
					n /= d;
				} else
					d += d < 17 ? 1 + (d > 2) :
					    tab[i++ % 48];
			}
			if(n != 1)
				put(n);
		}
		if(arg)
			exit(0);
	}
}
