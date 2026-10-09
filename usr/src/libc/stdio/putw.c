#include	<stdio.h>

void
putw(register int i, register struct _iobuf *iop)
{
	putc(i, iop);
	putc(i>>8, iop);
	putc(i>>16, iop);
	putc(i>>24, iop);
}
