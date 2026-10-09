#include	<stdio.h>

int
putw(i, iop)
register int i;
register struct _iobuf *iop;
{
	putc(i, iop);
	putc(i>>8, iop);
	putc(i>>16, iop);
	putc(i>>24, iop);
	return(i);
}
