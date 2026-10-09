#include <stdio.h>
/*
 * Return the ptr in sp at which the character c appears;
 * NULL if not found
 */

#define	NULL	0

char *
index(register char *sp, register char c)
{
	do {
		if (*sp == c)
			return(sp);
	} while (*sp++);
	return(NULL);
}
