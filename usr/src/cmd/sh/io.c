#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"
#include	"dup.h"

extern int close(int fd);
extern int open(char *p, int f);
extern int creat(char *p, int m);
extern int pipe(int *pv);
extern int dup(int f1, int f2);
extern int write(int fd, char *buf, int n);
INT	length(STRING as);
INT	itos(INT n);
INT	chkpr(CHAR c);
INT	readc(void);
INT	nextc(INT quote);
INT	failed(STRING s1, STRING s2);
INT	error(STRING s);
INT	tmpfil(void);
INT	create(STRING s);
INT	cf(STRING s1, STRING s2);
STRING	mactrim(STRING s);

/* ========	input output and file copying ======== */

INT initf(UFD fd)
{
	REG FILE	f=standin;

	f->fdes=fd; f->fsiz=(fd > 2 ? BUFSIZ :
	    ((flags&(oneflg|ttyflg))==0 ? BUFSIZ : 1));
	f->fnxt=f->fend=f->fbuf; f->feval=0; f->flin=1;
	f->feof=FALSE;
	return(0);
}

INT estabf(REG STRING s)
{
	REG FILE	f;

	(f=standin)->fdes = -1;
	f->fend=length(s)+(f->fnxt=s);
	f->flin=1;
	return(f->feof=(s==0));
}

INT push(FILE af)
{
	REG FILE	f;

	(f=af)->fstak=standin;
	f->feof=0; f->feval=0;
	standin=f;
	return(0);
}

INT pop(void)
{
	REG FILE	f;

	IF (f=standin)->fstak
	THEN	IF f->fdes>=0 THEN close(f->fdes) FI
		standin=f->fstak;
		return(TRUE);
	ELSE	return(FALSE);
	FI
}

INT chkpipe(INT *pv)
{
	IF pipe(pv)<0 ORF pv[INPIPE]<0 ORF pv[OTPIPE]<0
	THEN	error(piperr);
	FI
	return(0);
}

INT
chkopen(STRING idf)
{
	REG INT		rc;

	IF (rc=open(idf,0))<0
	THEN	failed(idf,badopen);
	ELSE	return(rc);
	FI
	return(0);
}

INT rename(REG INT f1, REG INT f2)
{
	IF f1!=f2
	THEN	dup(f1|DUPFLG, f2);
		close(f1);
		IF f2==0 THEN ioset|=1 FI
	FI
	return(0);
}

INT
create(STRING s)
{
	REG INT		rc;

	IF (rc=creat(s,0666))<0
	THEN	failed(s,badcreate);
	ELSE	return(rc);
	FI
	return(0);
}

INT tmpfil(void)
{
	itos(serial++); movstr(numbuf,tmpnam);
	return(create(tmpout));
}

/* set by trim */
BOOL		nosubst;

INT copy(IOPTR ioparg)
{
	CHAR		c, *ends;
	REG CHAR	*cline, *clinep;
	INT		fd;
	REG IOPTR	iop;

	IF (iop=ioparg)
	THEN	copy(iop->iolst);
		ends=mactrim(iop->ioname); IF nosubst THEN iop->iofile &= ~IODOC FI
		fd=tmpfil();
		iop->ioname=cpystak(tmpout);
		iop->iolst=iotemp; iotemp=iop;
		cline=locstak();

		LOOP	clinep=cline; chkpr(NL);
			WHILE (c = (nosubst ? readc() :  nextc(*ends)),  !eolchar(c)) DO *clinep++ = c OD
			*clinep=0;
			IF eof ORF eq(cline,ends) THEN break FI
			*clinep++=NL;
			write(fd,cline,clinep-cline);
		POOL
		close(fd);
	FI
	return(0);
}
