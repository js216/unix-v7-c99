/*
 * A subroutine version of the macro getchar.
 */
#include <stdio.h>

#undef getchar
int	getchar(void);

int
getchar(void)
{
	return(getc(stdin));
}
