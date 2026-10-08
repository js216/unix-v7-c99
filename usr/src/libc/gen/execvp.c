/*
 *	execlp(name, arg,...,0)	(like execl, but does path search)
 *	execvp(name, argv)	(like execv, but does path search)
 */
#include <stdio.h>
#include <errno.h>
#include <stdarg.h>
#define	NULL	0

static	char shell[] =	"/bin/sh";
static char	*execat(register char *s1, register char *s2, char *si);
extern	int errno;

int
execlp(char *name, char *arg0, ...)
{
	va_list ap;
	char **argv;
	int i, n, r;

	n = 1;
	va_start(ap, arg0);
	while(va_arg(ap, char *) != 0)
		n++;
	va_end(ap);

	argv = (char **)malloc((unsigned)((n+1) * sizeof(char *)));
	if(argv == 0)
		return(-1);
	argv[0] = arg0;
	va_start(ap, arg0);
	for(i=1; i<=n; i++)
		argv[i] = va_arg(ap, char *);
	va_end(ap);
	r = execvp(name, argv);
	free((char *)argv);
	return(r);
}

int
execvp(char *name, char **argv)
{
	char *pathstr;
	register char *cp;
	char fname[128];
	char *newargs[256];
	int i;
	register unsigned etxtbsy = 1;
	register int eacces = 0;

	if ((pathstr = getenv("PATH")) == NULL)
		pathstr = ":/bin:/usr/bin";
	cp = index(name, '/')? "": pathstr;

	do {
		cp = execat(cp, name, fname);
	retry:
		execv(fname, argv);
		switch(errno) {
		case ENOEXEC:
			newargs[0] = "sh";
			newargs[1] = fname;
			for (i=1; (newargs[i+1]=argv[i]); i++) {
				if (i>=254) {
					errno = E2BIG;
					return(-1);
				}
			}
			execv(shell, newargs);
			return(-1);
		case ETXTBSY:
			if (++etxtbsy > 5)
				return(-1);
			sleep(etxtbsy);
			goto retry;
		case EACCES:
			eacces++;
			break;
		case ENOMEM:
		case E2BIG:
			return(-1);
		}
	} while (cp);
	if (eacces)
		errno = EACCES;
	return(-1);
}

static char *
execat(register char *s1, register char *s2, char *si)
{
	register char *s;

	s = si;
	while (*s1 && *s1 != ':' && *s1 != '-')
		*s++ = *s1++;
	if (si != s)
		*s++ = '/';
	while (*s2)
		*s++ = *s2++;
	*s = '\0';
	return(*s1? ++s1: 0);
}
