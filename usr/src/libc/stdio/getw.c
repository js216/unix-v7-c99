#include	<stdio.h>

int
getw(register struct _iobuf *iop)
{
	register int i;

	i = getc(iop);
	if (iop->_flag&_IOEOF)
		return(-1);
	return(i | (getc(iop)<<8));
}
