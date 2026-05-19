/* chroot -- run command with NEWROOT as the root directory.  Calls the
 * v7 chroot(2) syscall (which requires root) then execs argv[2..]; with
 * no command, falls back to /bin/sh. */

#include <stdio.h>
extern int chroot(char *path);
extern int execvp(char *file, char **argv);
extern int chdir(char *path);

int
main(int argc, char *argv[])
{
	static char *shargv[] = { "sh", 0 };
	if (argc < 2) {
		fprintf(stderr, "usage: chroot newroot [cmd [args...]]\n");
		exit(2);
	}
	if (chroot(argv[1]) < 0) {
		fprintf(stderr, "chroot: %s: cannot chroot\n", argv[1]);
		exit(1);
	}
	(void)chdir("/");
	if (argc >= 3) {
		execvp(argv[2], &argv[2]);
		fprintf(stderr, "chroot: %s: exec failed\n", argv[2]);
		exit(127);
	}
	execvp("/bin/sh", shargv);
	fprintf(stderr, "chroot: /bin/sh: exec failed\n");
	exit(127);
}
