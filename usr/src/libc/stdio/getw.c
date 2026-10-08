#include	<stdio.h>

int
getw(register struct _iobuf *iop)
{
	register unsigned i;

	i = getc(iop);
	if (iop->_flag&_IOEOF)
		return(-1);
	i |= (unsigned)getc(iop)<<8;
	i |= (unsigned)getc(iop)<<16;
	return(i | (unsigned)getc(iop)<<24);
}
