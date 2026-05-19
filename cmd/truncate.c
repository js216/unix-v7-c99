/* truncate -- set file size.  V7 has no ftruncate(2) syscall, so this
 * supports only the common case of truncating to 0 (or extending via
 * lseek+write for grow).  Usage:
 *   truncate -s SIZE FILE...
 * For SIZE=0, calls creat() which discards content.  For SIZE>0 on a
 * smaller file, extends with a single zero byte at SIZE-1 (creating
 * a hole).  Cannot shrink a non-empty file to a non-zero size. */

#include <stdio.h>
extern int creat(char *, int);
extern int open(char *, int);
extern int close(int);
extern long lseek(int, long, int);
extern int write(int, char *, int);
extern long atol(char *);

int
main(int argc, char *argv[])
{
	long size;
	int i, fd, rc = 0;

	if (argc < 4 || argv[1][0] != '-' || argv[1][1] != 's' ||
	    argv[1][2] != '\0') {
		fprintf(stderr, "usage: truncate -s SIZE FILE...\n");
		exit(1);
	}
	size = atol(argv[2]);
	if (size < 0) {
		fprintf(stderr, "truncate: SIZE must be non-negative\n");
		exit(1);
	}
	for (i = 3; i < argc; i++) {
		if (size == 0) {
			if ((fd = creat(argv[i], 0644)) < 0) {
				fprintf(stderr, "truncate: %s: cannot create\n", argv[i]);
				rc = 1;
				continue;
			}
			close(fd);
		} else {
			if ((fd = open(argv[i], 2)) < 0) {
				/* Create new sparse file with hole. */
				if ((fd = creat(argv[i], 0644)) < 0) {
					fprintf(stderr, "truncate: %s: cannot create\n", argv[i]);
					rc = 1;
					continue;
				}
				close(fd);
				if ((fd = open(argv[i], 2)) < 0) { rc = 1; continue; }
			}
			lseek(fd, size - 1, 0);
			{
				char zero = 0;
				write(fd, &zero, 1);
			}
			close(fd);
		}
	}
	exit(rc);
}
