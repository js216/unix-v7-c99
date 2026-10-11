#include <stdio.h>

char	*av[5200];

int
main(int argc, char **argv)
{
	int i, n;

	(void)argc;
	n = atoi(argv[1]);
	av[0] = argv[2];
	for (i = 1; i < n; i++)
		av[i] = "";
	av[n] = 0;
	execv(argv[2], av);
	printf("exec failed\n");
	return 1;
}
