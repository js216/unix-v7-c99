#include <stdio.h>

int
main(argc, argv)
int argc;
char **argv;
{
	extern int errno;
	int acct();
	if (argc > 1)
		acct(argv[1]);
	else
		acct((char *)0);
	if (errno) {
		perror("accton");
		exit(1);
	}
	exit(0);
}
