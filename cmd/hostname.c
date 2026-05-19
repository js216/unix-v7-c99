/* hostname -- print the system's node name.  v7 had no sethostname/
 * gethostname; this port has a fixed identity baked into uname(1) too. */

#include <stdio.h>

int
main(int argc, char *argv[])
{
	(void)argc; (void)argv;
	puts("qemu");
	exit(0);
}
