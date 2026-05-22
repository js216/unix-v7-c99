#include	<stdio.h>

int
putw(register int i, register struct _iobuf *iop)
{
	putc(i, iop);
	putc(i>>8, iop);
	return(i);
}
