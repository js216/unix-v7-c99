/* nproc -- print number of available processing units.  This port has
 * one HZ-driven cooperative scheduler on a single core, so always 1. */

#include <stdio.h>

int
main(int argc, char *argv[])
{
	(void)argc; (void)argv;
	puts("1");
	exit(0);
}
