#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"

extern INT setbrk(INT n);
extern void free(void *p);
extern void rmtemp(IOPTR base);

STKPTR		stakbot=nullstr;



/* ========	storage allocation	======== */

STKPTR	getstak(INT asize)
{	/* allocate requested stack */
	REG STKPTR	oldstak;
	REG INT		size;

	size=round(asize,BYTESPERWORD);
	oldstak=stakbot;
	staktop = stakbot += size;
	return(oldstak);
}

STKPTR	locstak(void)
{	/* set up stack for local use
	 * should be followed by `endstak'
	 */
	IF brkend-stakbot<BRKINCR
	THEN	setbrk(brkincr);
		IF brkincr < BRKMAX
		THEN	brkincr += 256;
		FI
	FI
	return(stakbot);
}

STKPTR	savstak(void)
{
	assert(staktop==stakbot);
	return(stakbot);
}

STKPTR	endstak(REG STRING argp)
{	/* tidy up after `locstak' */
	REG STKPTR	oldstak;
	*argp++=0;
	oldstak=stakbot; stakbot=staktop=(STKPTR)round(argp,BYTESPERWORD);
	return(oldstak);
}

VOID	tdystak(REG STKPTR x)
{
	/* try to bring stack back to x */
	WHILE ADR(stakbsy)>ADR(x)
	DO free(stakbsy);
	   stakbsy = stakbsy->word;
	OD
	staktop=stakbot=max(ADR(x),ADR(stakbas));
	rmtemp((IOPTR)x);
	return(0);
}

INT stakchk(void)
{
	IF (brkend-stakbas)>BRKINCR+BRKINCR
	THEN	setbrk(-BRKINCR);
	FI
	return(0);
}

STKPTR	cpystak(STKPTR x)
{
	return(endstak(movstr(x,locstak())));
}
