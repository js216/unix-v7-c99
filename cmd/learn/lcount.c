#include "stdio.h"

int
main(void)	/* count lines in something */
{
	register int n, c;

	n = 0;
	while ((c = getchar()) != EOF)
		if (c == '\n')
			n++;
	printf("%d\n", n);
	return 0;
}
