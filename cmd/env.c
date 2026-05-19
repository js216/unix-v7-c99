/* env -- print environment, or run a command with modified env.  V7
 * didn't ship env; this is the basic POSIX form:
 *   env                     -- print all env vars
 *   env name=val ... [cmd]  -- set, then either print or exec
 *   env -i ...              -- start with empty env */

#include <stdio.h>

extern char **environ;
extern int execvp(char *file, char **argv);
extern void exit(int);
extern char *getenv(char *name);
static int strncmp_local(char *a, char *b, int n);

static int
has_eq(char *s)
{
	while (*s) {
		if (*s == '=') return 1;
		s++;
	}
	return 0;
}

int
main(int argc, char *argv[])
{
	static char *newenv[256];
	int nenv = 0;
	int empty = 0;
	int i, start = 1;
	char **p;

	if (start < argc && argv[start][0] == '-' && argv[start][1] == 'i' &&
	    argv[start][2] == '\0') {
		empty = 1;
		start++;
	}
	if (!empty) {
		for (p = environ; *p && nenv < 255; p++)
			newenv[nenv++] = *p;
	}
	while (start < argc && has_eq(argv[start])) {
		char *eq = argv[start];
		char *name = eq;
		int namelen = 0;
		while (*eq && *eq != '=') { eq++; namelen++; }
		/* Remove any prior binding with this name. */
		int j;
		for (j = 0; j < nenv; ) {
			if (strncmp_local(newenv[j], name, namelen) == 0 &&
			    newenv[j][namelen] == '=') {
				newenv[j] = newenv[nenv - 1];
				nenv--;
			} else j++;
		}
		if (nenv < 255)
			newenv[nenv++] = argv[start];
		start++;
	}
	newenv[nenv] = (char *)0;

	if (start >= argc) {
		for (i = 0; i < nenv; i++)
			printf("%s\n", newenv[i]);
		exit(0);
	}
	environ = newenv;
	execvp(argv[start], &argv[start]);
	fprintf(stderr, "env: %s: cannot execute\n", argv[start]);
	exit(127);
}

/* Local strncmp -- libc has one but linking it via stdio is fine; this
 * keeps the dependency obvious. */
static int
strncmp_local(char *a, char *b, int n)
{
	while (n--) {
		if (*a != *b) return (unsigned char)*a - (unsigned char)*b;
		if (!*a) return 0;
		a++; b++;
	}
	return 0;
}
