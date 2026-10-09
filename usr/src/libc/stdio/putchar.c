/*
 * A subroutine version of the macro putchar
 */
#include <stdio.h>

#undef putchar
void	putchar(int c);

void
putchar(register int c)
{
	putc(c, stdout);
}
