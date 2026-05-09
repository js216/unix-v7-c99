/* Ported from v7/usr/src/libc/gen/execvp.c.
 * K&R prototypes -> C99, register dropped, type widening:
 * v7's bare `int errno;` becomes `extern int errno;`. Algorithm
 * (PATH walk + ENOEXEC -> /bin/sh fallback + ETXTBSY retry +
 * EACCES coalescing) is unchanged.
 */
#include "u.h"
#include <errno.h>

#define	NULL	0

static char shell[] = "/bin/sh";

static char *
execat(char *s1, char *s2, char *si)
{
	char *s;

	s = si;
	while(*s1 && *s1 != ':' && *s1 != '-')
		*s++ = *s1++;
	if(si != s)
		*s++ = '/';
	while(*s2)
		*s++ = *s2++;
	*s = '\0';
	return(*s1 ? ++s1 : 0);
}

int
execvp(char *name, char **argv)
{
	char *pathstr;
	char *cp;
	char fname[128];
	char *newargs[256];
	int i;
	unsigned int etxtbsy = 1;
	int eacces = 0;

	if((pathstr = getenv("PATH")) == NULL)
		pathstr = ":/bin:/usr/bin";
	cp = index(name, '/') ? "" : pathstr;

	do {
		cp = execat(cp, name, fname);
	retry:
		(void)execv(fname, argv);
		switch(errno) {
		case ENOEXEC:
			newargs[0] = "sh";
			newargs[1] = fname;
			for(i = 1; (newargs[i+1] = argv[i]) != 0; i++) {
				if(i >= 254) {
					errno = E2BIG;
					return(-1);
				}
			}
			(void)execv(shell, newargs);
			return(-1);
		case ETXTBSY:
			if(++etxtbsy > 5)
				return(-1);
			(void)sleep((int)etxtbsy);
			goto retry;
		case EACCES:
			eacces++;
			break;
		case ENOMEM:
		case E2BIG:
			return(-1);
		}
	} while(cp);
	if(eacces)
		errno = EACCES;
	return(-1);
}

int
execlp(char *name, char *arg0, ...)
{
	return(execvp(name, &arg0));
}
