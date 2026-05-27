#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"

extern void exit(int n) __attribute__((__noreturn__));
extern int unlink(char *p);
void	exitsh(INT xno);
void	rmtemp(IOPTR base);
INT	assnum(STRING *p, INT n);
void	prp(void);
void	newline(void);
void	done(void);
void	clearup(void);
void	execexp(STRING s, UFD f);

/* ========	error handling	======== */

INT exitset(void)
{
	assnum(&exitadr,exitval);
	return(0);
}

INT sigchk(void)
{
	/* Find out if it is time to go away.
	 * `trapnote' is set to SIGSET when fault is seen and
	 * no trap has been set.
	 */
	IF trapnote&SIGSET
	THEN	exitsh(SIGFAIL);
	FI
	return(0);
}

INT failed(STRING s1, STRING s2)
{
	prp(); prs(s1); 
	IF s2
	THEN	prs(colon); prs(s2);
	FI
	newline(); exitsh(ERROR);
	return(0);
}

INT error(STRING s)
{
	failed(s,NIL);
	return(0);
}

void
exitsh(INT xno)
{
	/* Arrive here from `FATAL' errors
	 *  a) exit command,
	 *  b) default trap,
	 *  c) fault with no trap set.
	 *
	 * Action is to return to command level or exit.
	 */
	exitval=xno;
	IF (flags & (forked|errflg|ttyflg)) != ttyflg
	THEN	done();
	ELSE	clearup();
		longjmp(errshell,1);
	FI
}

void done(void)
{
	REG STRING	t;
	IF (t=trapcom[0])
	THEN	trapcom[0]=0; /*should free but not long */
		execexp(t,0);
	FI
	rmtemp(0);
	exit(exitval);
}

void
rmtemp(IOPTR base)
{
	WHILE iotemp>base
	DO  unlink(iotemp->ioname);
	    iotemp=iotemp->iolst;
	OD
}
