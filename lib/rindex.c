/*
 * Return the ptr in sp at which the character c last appears;
 * NULL if not found.
 *
 * Ported from v7/usr/src/libc/gen/rindex.c.
 */

#define NULL 0

char *
rindex(char *sp, int c)
{
	char *r;

	r = NULL;
	do {
		if(*sp == c)
			r = sp;
	} while(*sp++);
	return(r);
}
