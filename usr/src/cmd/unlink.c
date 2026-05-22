/* unlink FILE -- remove FILE via the unlink(2) syscall.  POSIX-
 * mandated thin wrapper.  Unlike rm, doesn't prompt or check perms;
 * unlink(2) returns failure if FILE doesn't exist or isn't writable
 * (for the parent directory). */

#include <stdio.h>
extern int unlink(char *);

int
main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr, "usage: unlink FILE\n");
		exit(1);
	}
	if (unlink(argv[1]) < 0) {
		fprintf(stderr, "unlink: %s: failed\n", argv[1]);
		exit(1);
	}
	exit(0);
}
