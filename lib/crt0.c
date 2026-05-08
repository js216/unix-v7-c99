#include "u.h"

extern int main(int argc, char **argv);

static char *argv[32];

void
_startc(void)
{
	int argc;

	argc = getargs(argv, 32);
	(void)main(argc, argv);
}
