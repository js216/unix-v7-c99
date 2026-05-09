/*
 * Return the ptr in sp at which the character c appears;
 * NULL if not found.
 *
 * Ported from v7/usr/src/libc/gen/index.c.  K&R prototype -> C99,
 * register dropped, char promoted to int in the second arg per
 * C99 default argument promotion.
 */

#define	NULL	0

char *
index(char *sp, int c)
{
	do {
		if(*sp == c)
			return(sp);
	} while(*sp++);
	return(NULL);
}
