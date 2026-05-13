/*
 * Returns 1 iff file is a tty
 */

#include "u.h"
#include <sgtty.h>

int
isatty(f)
int f;
{
	struct sgttyb ttyb;

	if (gtty(f, &ttyb) < 0)
		return(0);
	return(1);
}
