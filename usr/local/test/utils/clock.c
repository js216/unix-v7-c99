#include <stdio.h>

int
main(int argc, char **argv)
{
	long long t;

	if (argc < 2) {
		printf("%lld\n", time((long long *)0));
		return 0;
	}
	sscanf(argv[1], "%lld", &t);
	return stime(&t) < 0;
}
