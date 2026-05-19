/* printenv [VAR ...] -- print one or all environment variables.
 * Without args, lists all of environ (one per line, NAME=VALUE form).
 * With args, prints just the value of each named VAR (one per line).
 * Exit status is 0 if all named vars exist, 1 if any are missing. */

#include <stdio.h>

extern char **environ;
extern char *getenv(char *);

int
main(int argc, char *argv[])
{
	int i, rc = 0;
	char **p;

	if (argc < 2) {
		for (p = environ; *p; p++)
			puts(*p);
		exit(0);
	}
	for (i = 1; i < argc; i++) {
		char *val = getenv(argv[i]);
		if (val == 0) { rc = 1; continue; }
		puts(val);
	}
	exit(rc);
}
