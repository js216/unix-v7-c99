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
	int c, i;

	i = 0;
	while ((c = getchar()) != EOF) {
		if (c != ' ' && c != '\t' && c != '\n')
			break;
	}
	if (c == EOF)
		return(0);
	do {
		if (i < (int)sizeof(buf) - 1)
			buf[i++] = (char)c;
		c = getchar();
	} while (c != EOF && c != ' ' && c != '\t' && c != '\n');
	buf[i] = '\0';
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

static int
prime(unsigned long long n)
{
	unsigned long long p;

	if (n < 2ULL)
		return(0);
	if (n == 2ULL || n == 3ULL)
		return(1);
	if ((n % 2ULL) == 0 || (n % 3ULL) == 0)
		return(0);
	p = 5ULL;
	while (p <= n / p) {
		if ((n % p) == 0)
			return(0);
		p += 2ULL;
		if (p > n / p)
			break;
		if ((n % p) == 0)
			return(0);
		p += 4ULL;
	}
	return(1);
}

static int
print_prime(unsigned long long n)
{
	putnum(n);
	if (putchar('\n') == EOF)
		return(-1);
	if (fflush(stdout) == EOF)
		return(-1);
	return(0);
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
	} else {
		r = read_number(&n);
		if (r <= 0 || n == 0ULL) {
			if (r < 0)
				ouch();
			return(r < 0 ? 1 : 0);
		}
	}
	if (n >= MAXNUM) {
		ouch();
		return(1);
	}
	if (n <= 2ULL) {
		if (print_prime(2ULL) < 0)
			return(0);
		n = 3ULL;
	} else if ((n % 2ULL) == 0)
		n++;
	for (;;) {
		if (prime(n) && print_prime(n) < 0)
			return(0);
		n += 2ULL;
	}
}
