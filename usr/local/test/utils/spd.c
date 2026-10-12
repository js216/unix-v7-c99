#include <stdio.h>
#include <sgtty.h>

int
main(int argc, char **argv)
{
	struct sgttyb b;

	(void)argc;
	gtty(1, &b);
	b.sg_ispeed = b.sg_ospeed = atoi(argv[1]);
	stty(1, &b);
	return 0;
}
