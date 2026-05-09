/* Minimal getenv + environ.
 *
 * The v7 libc getenv walks `environ[]`, looking for `name=`.  This
 * port keeps the algorithm but admits that the kernel does not yet
 * thread an envp through fork/exec, so the default `environ`
 * starts empty and getenv returns NULL until something installs
 * a proper environment. */

#include "u.h"

#define	NULL	0

static char *empty[] = { 0 };
char **environ = empty;

char *
getenv(char *name)
{
	char **p;
	char *q;
	int n;

	n = strlen(name);
	for(p = environ; *p != NULL; p++) {
		q = *p;
		if(strncmp(q, name, n) == 0 && q[n] == '=')
			return(q + n + 1);
	}
	return(NULL);
}

/* errno: each cmd .c file in V7 declares `int errno;` (tentative),
 * and the linker coalesces them under -fcommon.  Provide a libc-side
 * tentative definition for binaries that don't already carry one
 * (e.g. /etc/init, /etc/getty whose mains never read errno). */
int errno;
