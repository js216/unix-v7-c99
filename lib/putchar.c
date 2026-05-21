/*
 * A subroutine version of the macro putchar
 */
#include <stdio.h>

#undef putchar

int
putchar(register int c)
{
	return(putc(c, stdout));
}
