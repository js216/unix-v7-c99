#include <stdio.h>

/*
 * rep [-n] n s [t]: write s n times, then t, then a newline unless
 * -n; the cases' test data, which awk took a tenth of a second
 * apiece to start up and make.
 */
int
main(int argc, char **argv)
{
	int i, n, nl;

	nl = 1;
	if (argc > 1 && strcmp(argv[1], "-n") == 0) {
		nl = 0;
		argv++;
		argc--;
	}
	n = atoi(argv[1]);
	for (i = 0; i < n; i++)
		fputs(argv[2], stdout);
	if (argc > 3)
		fputs(argv[3], stdout);
	if (nl)
		putchar('\n');
	return 0;
}
