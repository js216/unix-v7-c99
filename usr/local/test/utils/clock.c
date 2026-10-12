#include <stdio.h>

int
main(int argc, char **argv)
{
	long long t, u;

	if (argc < 2) {
		printf("%lld\n", time((long long *)0));
		return 0;
	}
	sscanf(argv[1], "%lld", &t);
	if (argc > 2) {
		sscanf(argv[2], "%lld", &u);
		t = time((long long *)0) + t - u;
	}
	return stime(&t) < 0;
}
