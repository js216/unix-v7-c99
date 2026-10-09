#include	<stdio.h>

int
fputs(s, iop)
register char *s;
register FILE *iop;
{
	register int r = 0;
	register int c;

	while ((c = *s++))
		r = putc(c, iop);
	return(r);
}
