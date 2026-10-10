#include <stdio.h>

int
main(int argc, char **argv)
{
	int i, n = 0;

	for (i = 0; i < argc; i++)
		n += strlen(argv[i]);
	printf("argc %d chars %d last %s\n", argc, n, argv[argc-1]);
	return 0;
}
