#include <stdio.h>
int
main(int argc, char **argv)
{
	extern int errno;
	int acct(char *file);
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
