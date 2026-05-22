/* mktemp -- create a unique temporary file or directory.
 *   mktemp                  -> /tmp/tmp.XXXXXX
 *   mktemp TEMPLATE         -> TEMPLATE has trailing XXXXXX replaced
 *   mktemp -d [TEMPLATE]    -> create directory instead of file
 * Prints the resulting name.  libc's mktemp() picks the suffix; mkdir()
 * is a libc helper (v7 lacks the syscall) that runs the mknod+link
 * dance from cmd/mkdir.c. */

#include <stdio.h>
extern char *mktemp(char *);
extern int mkdir(char *path, int mode);
extern int creat(char *path, int mode);
extern int close(int fd);

int
main(int argc, char *argv[])
{
	static char buf[256];
	char *src;
	int i, dflag = 0, start = 1;
	int fd;

	if (start < argc && argv[start][0] == '-' && argv[start][1] == 'd' &&
	    argv[start][2] == '\0') {
		dflag = 1;
		start++;
	}
	src = (start < argc) ? argv[start] : "/tmp/tmp.XXXXXX";
	for (i = 0; src[i] && i < (int)sizeof(buf) - 1; i++) buf[i] = src[i];
	buf[i] = '\0';

	if (mktemp(buf) == 0 || buf[0] == '\0') {
		fprintf(stderr, "mktemp: cannot generate unique name\n");
		exit(1);
	}
	if (dflag) {
		if (mkdir(buf, 0700) < 0) {
			fprintf(stderr, "mktemp: %s: cannot mkdir\n", buf);
			exit(1);
		}
	} else {
		if ((fd = creat(buf, 0600)) < 0) {
			fprintf(stderr, "mktemp: %s: cannot create\n", buf);
			exit(1);
		}
		close(fd);
	}
	puts(buf);
	exit(0);
}
