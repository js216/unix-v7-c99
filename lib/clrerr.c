#include	<stdio.h>

void
clearerr(iop)
register struct _iobuf *iop;
{
	iop->_flag &= ~(_IOERR|_IOEOF);
}
