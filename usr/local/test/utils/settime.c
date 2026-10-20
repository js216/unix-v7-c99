#include <stdio.h>

/*
 * settime file n: set the file's access and modification times to n
 * seconds ago, so that a case can order files by time without
 * sleeping between making them.
 */
int
main(int argc, char **argv)
{
	long long t[2];

	(void)argc;
	t[0] = t[1] = time((long long *)0) - atoi(argv[2]);
	return utime(argv[1], t) < 0;
}
