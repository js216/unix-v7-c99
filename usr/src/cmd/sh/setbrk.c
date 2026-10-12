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
setbrk(INT incr)
{
	REG BYTPTR	a=sbrk(incr);
	IF a!=(BYTPTR)-1 THEN brkend=a+incr FI
	return(a);
}
