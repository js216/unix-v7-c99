#include	<stdio.h>

void
clearerr(register struct _iobuf *iop)
{
	iop->_flag &= ~(_IOERR|_IOEOF);
}
