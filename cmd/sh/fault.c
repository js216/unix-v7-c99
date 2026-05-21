#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"

extern int signal(int sig, int fun);
extern void execexp(STRING t, INT in);
extern void error(STRING s);
extern void done(void);
extern INT setbrk(INT n);
extern void exitset(void);
extern void free(void *p);

VOID	stdsigs(void);
INT	ignsig(INT n);
VOID	getsig(INT n);
VOID	oldsigs(void);
VOID	clrsig(INT i);
VOID	chktrap(void);
VOID	fault(INT sig);


STRING		trapcom[MAXTRAP];
BOOL		trapflg[MAXTRAP];

/* ========	fault handling routines	   ======== */


VOID
fault(INT sig)
{
	REG INT		flag;

	signal(sig, (int)fault);
	IF sig==MEMF
	THEN	IF setbrk(brkincr) == -1
		THEN	error(nospace);
		FI
	ELIF sig==ALARM
	THEN	IF flags&waiting
		THEN	done();
		FI
	ELSE	flag = (trapcom[sig] ? TRAPSET : SIGSET);
		trapnote |= flag;
		trapflg[sig] |= flag;
	FI
	return(0);
}

VOID
stdsigs(void)
{
	ignsig(QUIT);
	getsig(INTR);
	getsig(MEMF);
	getsig(ALARM);
	return(0);
}

INT
ignsig(INT n)
{
	REG INT		s, i;

	IF (s=signal(i=n,1)&01)==0
	THEN	trapflg[i] |= SIGMOD;
	FI
	return(s);
}

VOID
getsig(INT n)
{
	REG INT		i;

	IF trapflg[i=n]&SIGMOD ORF ignsig(i)==0
	THEN	signal(i, (int)fault);
	FI
	return(0);
}

VOID
oldsigs(void)
{
	REG INT		i;
	REG STRING	t;

	i=MAXTRAP;
	WHILE i--
	DO  t=trapcom[i];
	    IF t==0 ORF *t
	    THEN clrsig(i);
	    FI
	    trapflg[i]=0;
	OD
	trapnote=0;
	return(0);
}

VOID
clrsig(INT i)
{
	free(trapcom[i]); trapcom[i]=0;
	IF trapflg[i]&SIGMOD
	THEN	signal(i, (int)fault);
		trapflg[i] &= ~SIGMOD;
	FI
	return(0);
}

VOID
chktrap(void)
{
	/* check for traps */
	REG INT		i=MAXTRAP;
	REG STRING	t;

	trapnote &= ~TRAPSET;
	WHILE --i
	DO IF trapflg[i]&TRAPSET
	   THEN trapflg[i] &= ~TRAPSET;
		IF (t=trapcom[i])
		THEN	INT	savxit=exitval;
			execexp(t,0);
			exitval=savxit; exitset();
		FI
	   FI
	OD
	return(0);
}
