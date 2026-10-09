#include <stdio.h>
int
main(argc, argv)
int	argc;
char **argv;
{
	for (;;)
		printf("%s\n", argc>1? argv[1]: "y");
}
