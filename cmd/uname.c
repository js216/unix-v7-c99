/* uname -- print system information.  V7 had no uname syscall; this
 * port has fixed identity so the values are baked in.  Flags follow
 * POSIX: -s (sysname), -n (node), -r (release), -v (version),
 * -m (machine), -a (all). */

#include <stdio.h>

#define SYSNAME  "UNIX"
#define NODENAME "qemu"
#define RELEASE  "7"
#define VERSION  "v7-c99"
#define MACHINE  "arm"

int
main(int argc, char *argv[])
{
	int s = 0, n = 0, r = 0, v = 0, m = 0;
	int any = 0;
	int i;
	char *p;

	for (i = 1; i < argc; i++) {
		if (argv[i][0] != '-' || argv[i][1] == '\0') {
			fprintf(stderr, "uname: bad arg %s\n", argv[i]);
			exit(1);
		}
		for (p = argv[i] + 1; *p; p++) {
			switch (*p) {
			case 'a': s = n = r = v = m = 1; break;
			case 's': s = 1; break;
			case 'n': n = 1; break;
			case 'r': r = 1; break;
			case 'v': v = 1; break;
			case 'm': m = 1; break;
			default:
				fprintf(stderr, "uname: unknown flag -%c\n", *p);
				exit(1);
			}
		}
	}
	if (!s && !n && !r && !v && !m)
		s = 1;
	if (s) { fputs(SYSNAME, stdout); any = 1; }
	if (n) { if (any) putchar(' '); fputs(NODENAME, stdout); any = 1; }
	if (r) { if (any) putchar(' '); fputs(RELEASE, stdout); any = 1; }
	if (v) { if (any) putchar(' '); fputs(VERSION, stdout); any = 1; }
	if (m) { if (any) putchar(' '); fputs(MACHINE, stdout); any = 1; }
	putchar('\n');
	exit(0);
}
