/*
 * Returns 1 iff file is a tty.
 *
 * Ported from v7/usr/src/libc/gen/isatty.c.  K&R prototype -> C99
 * with explicit `int` return and arg type.
 */

#include <sgtty.h>

extern int gtty(int, void *);

int
isatty(int f)
{
	struct sgttyb ttyb;

	if(gtty(f, &ttyb) < 0)
		return(0);
	return(1);
}
