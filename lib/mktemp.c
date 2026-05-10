/* Ported from v7/usr/src/libc/gen/mktemp.c.
 * K&R prototype -> C99, register dropped. */

#include "u.h"

char *
mktemp(char *as)
{
	char *s;
	unsigned int pid;
	int i;

	pid = getpid();
	s = as;
	while(*s++)
		;
	s--;
	while(*--s == 'X') {
		*s = (pid % 10) + '0';
		pid /= 10;
	}
	s++;
	i = 'a';
	while(access(as, 0) != -1) {
		if(i == 'z')
			return("/");
		*s = i++;
	}
	return(as);
}
