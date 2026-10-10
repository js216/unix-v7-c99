#include <stdio.h>

int
main(int argc, char **argv)
{
	long t;

	if (argc < 2) {
		printf("%ld\n", time((long *)0));
		return 0;
	}
	t = atol(argv[1]);
	return stime(&t) < 0;
}
