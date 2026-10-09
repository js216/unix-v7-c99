#
/*
 *	UNIX shell
 *
 *	S. R. Bourne
 *	Bell Telephone Laboratories
 *
 */

#include	"defs.h"

BYTPTR
setbrk(incr)
	INT		incr;
{
	REG BYTPTR	a=sbrk(incr);
	brkend=a+incr;
	return(a);
}
