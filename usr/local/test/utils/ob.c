#include <stdio.h>

int
main(int argc, char **argv)
{
	int i, n, v;
	char *p;

	for (i = 1; i < argc; i++) {
		n = 1;
		p = argv[i];
		if (index(p, '*')) {
			n = atoi(p);
			p = index(p, '*') + 1;
		}
		for (v = 0; *p >= '0' && *p <= '7'; p++)
			v = v*8 + *p - '0';
		while (n-- > 0)
			putchar(v);
	}
	return 0;
}
