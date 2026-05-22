/* link FILE1 FILE2  -- create a hard link FILE2 pointing at FILE1.
 * POSIX-mandated thin wrapper over the link(2) syscall.  Differs from
 * ln(1) in that it takes exactly two args and never resolves the
 * target as a directory. */

#include <stdio.h>
extern int link(char *, char *);

int
main(int argc, char *argv[])
{
	if (argc != 3) {
		fprintf(stderr, "usage: link FILE1 FILE2\n");
		exit(1);
	}
	if (link(argv[1], argv[2]) < 0) {
		fprintf(stderr, "link: %s -> %s: failed\n", argv[1], argv[2]);
		exit(1);
	}
	exit(0);
}
