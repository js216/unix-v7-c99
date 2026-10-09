#include <stdio.h>
#include <math.h>

#define	BIG	72057594037927935LL
#define	TABSIZ	1000
#define	TSIZ8	8000

long long pt[] = {
	2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43,
	47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97
};
int	factab[] = {
	10, 2, 4, 2, 4, 6, 2, 6,
	4, 2, 4, 6, 6, 2, 6, 4,
	2, 6, 4, 6, 8, 4, 2, 4,
	2, 4, 8, 6, 4, 6, 2, 4,
	6, 2, 6, 6, 4, 2, 4, 6,
	2, 6, 4, 2, 4, 2, 10, 2
};
char	table[TABSIZ];
char	iobuf[512];
int	nbuf;
char	*arg;
long long nn;

static int
getch(void)
{
	char c;

	if(arg)
		return(*arg++);
	if(read(0, &c, 1) != 1)
		exit(0);
	return(c);
}

static long long
getnum(void)
{
	register int c;
	long long n;

	n = 0;
	for(;;) {
		c = getch();
		if(c == ' ')
			continue;
		if(c < '0' || c > '9')
			return(n);
		if(n < BIG)
			n = n*10 + c-'0';
	}
}

static void
wrchar(int c)
{
	iobuf[nbuf++] = c;
	if(nbuf >= 512) {
		write(1, iobuf, 512);
		nbuf = 0;
	}
}

static void
ftoa(long long n)
{
	if(n >= 10)
		ftoa(n/10);
	wrchar((int)(n%10) + '0');
}

static void
mark(int p)
{
	long long off;

	off = nn/p*p - nn;
	if(off < 0)
		off += p;
	for(; off < TSIZ8; off += p)
		table[off>>3] |= 1<<(off&7);
}

int
main(int argc, char **argv)
{
	register int i, f, p;
	long long n;
	double v;

	if(argc > 1)
		arg = argv[1];
	while((n = getnum()) >= BIG) {
		write(2, "Ouch.\n", 6);
		if(arg)
			exit(1);
	}
	if(n == 0)
		exit(0);
	if(n < 100) {
		for(i = 0; i < 25 && pt[i] < n; i++)
			;
		if(i < 25) {
			for(; i < 25; i++) {
				ftoa(pt[i]);
				wrchar('\n');
			}
			n = 100;
		}
	}
	nn = n/2*2 + 1;
	for(;;) {
		for(i = 0; i < TABSIZ; i++)
			table[i] = 0;
		v = sqrt((double)(nn+TSIZ8));
		mark(3);
		mark(5);
		mark(7);
		p = 11;
		f = 1;
		do {
			mark(p);
			p += factab[f++];
			if(f >= 48)
				f = 0;
		} while(p <= v);
		for(i = 0; i < TSIZ8; i += 2) {
			if((table[i>>3] & 1<<(i&7)) == 0) {
				ftoa(nn);
				wrchar('\n');
			}
			nn += 2;
		}
	}
}
