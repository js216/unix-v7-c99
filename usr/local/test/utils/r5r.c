#include <stdio.h>

struct {
	char buf[BUFSIZ+1];
	char canary[1000];
} pw;

int
main(int argc, char **argv)
{
	int i, r;

	if (argc == 3 && strcmp(argv[1], "pw") == 0) {
		for (i = 0; i < (int)sizeof pw.buf; i++)
			pw.buf[i] = ':';
		r = getpw(atoi(argv[2]), pw.buf);
		for (i = 0;
		    i < (int)sizeof pw.canary && pw.canary[i] == 0; i++)
			;
		printf("getpw %d canary %s: %.20s\n", r,
		    i == (int)sizeof pw.canary ? "kept" : "hit",
		        r ? "" : pw.buf);
		return 0;
	}
	if (argc >= 4 && strcmp(argv[1], "ch") == 0) {
		if (chroot(argv[2]) < 0 || chdir("/") < 0) {
			printf("cannot chroot %s\n", argv[2]);
			return 1;
		}
		execv(argv[3], argv + 3);
		printf("cannot exec %s\n", argv[3]);
		return 1;
	}
	printf("usage: r5r pw uid | ch dir prog [arg...]\n");
	return 1;
}
