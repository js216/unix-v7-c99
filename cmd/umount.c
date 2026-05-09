/*
 * umount - detach a V7 filesystem mounted at a directory.
 */
#include "../lib/u.h"

int
main(int argc, char **argv)
{
	int rc;

	if(argc != 2) {
		puts("usage: umount special");
		return(1);
	}
	rc = syscall3(S_UMOUNT, (int)argv[1], 0, 0);
	if(rc < 0) {
		puts("umount: failed");
		return(1);
	}
	return(0);
}
