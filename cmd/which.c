/* which -- locate a command in PATH.  Prints the first executable
 * match for each argument; exits non-zero if any are unfound. */

#include <stdio.h>
extern char *getenv(char *);
extern int access(char *, int);

static int
locate(char *name)
{
	static char buf[256];
	char *path, *p, *q;
	int n;

	/* If the name contains a slash, treat it as a path literal. */
	for (p = name; *p; p++) {
		if (*p == '/') {
			if (access(name, 1) == 0) {
				puts(name);
				return 0;
			}
			return 1;
		}
	}
	path = getenv("PATH");
	if (path == 0 || *path == '\0')
		path = "/bin:/usr/bin";
	p = path;
	while (*p) {
		q = buf;
		n = 0;
		while (*p && *p != ':' && n < (int)sizeof(buf) - 2) {
			*q++ = *p++;
			n++;
		}
		if (n == 0) { *q++ = '.'; n = 1; }
		if (q[-1] != '/') *q++ = '/';
		{ char *r = name; while (*r && n < (int)sizeof(buf) - 1) { *q++ = *r++; n++; } }
		*q = '\0';
		if (access(buf, 1) == 0) {
			puts(buf);
			return 0;
		}
		if (*p == ':') p++;
	}
	return 1;
}

int
main(int argc, char *argv[])
{
	int i, status = 0;
	if (argc < 2) {
		fprintf(stderr, "usage: which name ...\n");
		exit(2);
	}
	for (i = 1; i < argc; i++)
		if (locate(argv[i]) != 0) {
			fprintf(stderr, "which: %s: not found\n", argv[i]);
			status = 1;
		}
	exit(status);
}
