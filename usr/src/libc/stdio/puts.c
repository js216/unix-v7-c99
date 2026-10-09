#include	<stdio.h>

int
puts(register char *s)
{
	register int c;

	while ((c = *s++))
		putchar(c);
	return(putchar('\n'));
}
