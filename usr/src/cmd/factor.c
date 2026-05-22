#include <stdio.h>

#define MAXNUM 72057594037927936ULL

static int
parse_number(char *s, unsigned long long *out)
{
	unsigned long long n;
	int any;

	while (*s == ' ' || *s == '\t' || *s == '\n')
		s++;
	n = 0;
	any = 0;
	while (*s >= '0' && *s <= '9') {
		any = 1;
		if (n > (MAXNUM - (unsigned long long)(*s - '0')) / 10ULL)
			return(-1);
		n = n * 10ULL + (unsigned long long)(*s - '0');
		s++;
	}
	while (*s == ' ' || *s == '\t' || *s == '\n')
		s++;
	if (!any || *s != '\0' || n >= MAXNUM)
		return(-1);
	*out = n;
	return(0);
}

static int
read_number(unsigned long long *out)
{
	char buf[80];
	int c, i, any;

	i = 0;
	any = 0;
	while ((c = getchar()) != EOF) {
		if (c != ' ' && c != '\t' && c != '\n')
			break;
	}
	if (c == EOF)
		return(0);
	do {
		any = 1;
		if (i < (int)sizeof(buf) - 1)
			buf[i++] = (char)c;
		c = getchar();
	} while (c != EOF && c != ' ' && c != '\t' && c != '\n');
	buf[i] = '\0';
	if (!any)
		return(0);
	if (parse_number(buf, out) < 0)
		return(-1);
	return(1);
}

static void
putnum(unsigned long long n)
{
	char buf[24];
	int i;

	i = 0;
	if (n == 0)
		buf[i++] = '0';
	else while (n != 0) {
		buf[i++] = (char)('0' + (int)(n % 10ULL));
		n /= 10ULL;
	}
	while (i > 0)
		putchar(buf[--i]);
}

static void
factor(unsigned long long n)
{
	unsigned long long p;

	putchar('\n');
	while ((n % 2ULL) == 0) {
		printf("     ");
		putnum(2ULL);
		putchar('\n');
		n /= 2ULL;
	}
	while ((n % 3ULL) == 0) {
		printf("     ");
		putnum(3ULL);
		putchar('\n');
		n /= 3ULL;
	}
	p = 5ULL;
	while (p <= n / p) {
		while ((n % p) == 0) {
			printf("     ");
			putnum(p);
			putchar('\n');
			n /= p;
		}
		p += 2ULL;
		if (p > n / p)
			break;
		while ((n % p) == 0) {
			printf("     ");
			putnum(p);
			putchar('\n');
			n /= p;
		}
		p += 4ULL;
	}
	if (n > 1ULL) {
		printf("     ");
		putnum(n);
		putchar('\n');
	}
}

static void
ouch(void)
{
	fprintf(stderr, "Ouch.\n");
}

int
main(int argc, char **argv)
{
	unsigned long long n;
	int r;

	if (argc > 1) {
		if (parse_number(argv[1], &n) < 0) {
			ouch();
			return(1);
		}
		if (n == 0ULL)
			return(0);
		factor(n);
		return(0);
	}
	for (;;) {
		r = read_number(&n);
		if (r == 0 || (r > 0 && n == 0ULL))
			return(0);
		if (r < 0) {
			ouch();
			return(1);
		}
		factor(n);
	}
}
