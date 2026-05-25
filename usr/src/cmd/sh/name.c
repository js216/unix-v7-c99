#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"

LOCAL BOOL	chkid(STRING nam);


LOCAL VOID	namwalk(REG NAMPTR np);
VOID	countnam(NAMPTR n);
VOID	pushnam(NAMPTR n);
INT	cf(STRING s1, STRING s2);
INT	blank(void);
INT	newline(void);
INT	assign(NAMPTR n, STRING v);
INT	failed(STRING s1, STRING s2);
INT	itos(INT n);
INT	any(REG CHAR c, STRING s);
INT	push(FILE af);
INT	initf(UFD fd);
INT	pop(void);
INT	nextc(INT quote);
INT	sigchk(void);
INT	length(STRING as);
VOID	prc(INT c);
VOID	prs(STRING as);
extern int dup();
extern long lseek(int fd, long off, int whence);
extern void free(void *p);
NAMNOD	ps2nod	= {	0,		0,		ps2name,	NIL, NIL, 0},
	fngnod	= {	0,		0,		fngname,	NIL, NIL, 0},
	pathnod = {	0,		0,		pathname,	NIL, NIL, 0},
	ifsnod	= {	0,		0,		ifsname,	NIL, NIL, 0},
	ps1nod	= {	&pathnod,	&ps2nod,	ps1name,	NIL, NIL, 0},
	homenod = {	&fngnod,	&ifsnod,	homename,	NIL, NIL, 0},
	mailnod = {	&homenod,	&ps1nod,	mailname,	NIL, NIL, 0};

NAMPTR		namep = &mailnod;


/* ========	variable and string handling	======== */

INT syslook(STRING w, struct sysnod syswds[])
{
	REG CHAR	first;
	REG STRING	s;
	REG SYSPTR	syscan;

	syscan=syswds; first = *w;

	WHILE (s=syscan->sysnam)
	DO  IF first == *s
		ANDF eq(w,s)
	    THEN return(syscan->sysval);
	    FI
	    syscan++;
	OD
	return(0);
}

INT setlist(REG ARGPTR arg, INT xp)
{
	WHILE arg
	DO REG STRING	s=mactrim(arg->argval);
	   setname(s, xp);
	   arg=arg->argnxt;
	   IF flags&execpr
	   THEN prs(s);
		IF arg THEN blank(); ELSE newline(); FI
	   FI
	OD
	return(0);
}

VOID	setname(STRING argi, INT xp)
{
	REG STRING	argscan=argi;
	REG NAMPTR	n;

	IF letter(*argscan)
	THEN	WHILE alphanum(*argscan) DO argscan++ OD
		IF *argscan=='='
		THEN	*argscan = 0;
			n=lookup(argi);
			*argscan++ = '=';
			attrib(n, xp);
			IF xp&N_ENVNAM
			THEN	n->namenv = n->namval = argscan;
			ELSE	assign(n, argscan);
			FI
			return(0);
		FI
	FI
	failed(argi,notid);
	return(0);
}

INT
replace(REG STRING *a, STRING v)
{
	free(*a); *a=make(v);
	return(0);
}

INT dfault(NAMPTR n, STRING v)
{
	IF n->namval==0
	THEN	assign(n,v)
	FI
	return(0);
}

INT assign(NAMPTR n, STRING v)
{
	IF n->namflg&N_RDONLY
	THEN	failed(n->namid,wtfailed);
	ELSE	replace(&n->namval,v);
	FI
	return(0);
}

INT	readvar(STRING *names)
{
	FILEBLK		fb;
	REG FILE	f = &fb;
	REG CHAR	c;
	REG INT		rc=0;
	NAMPTR		n=lookup(*names++); /* done now to avoid storage mess */
	STKPTR		rel=(STKPTR)(long)relstak();

	push(f); initf(dup(0));
	IF lseek(0,0L,1)==-1
	THEN	f->fsiz=1;
	FI

	LOOP	c=nextc(0);
		IF (*names ANDF any(c, ifsnod.namval)) ORF eolchar(c)
		THEN	zerostak();
			assign(n,absstak(rel)); setstak(rel);
			IF *names
			THEN	n=lookup(*names++);
			ELSE	n=0;
			FI
			IF eolchar(c)
			THEN	break;
			FI
		ELSE	pushstak(c);
		FI
	POOL
	WHILE n
	DO assign(n, nullstr);
	   IF *names THEN n=lookup(*names++); ELSE n=0; FI
	OD

	IF eof THEN rc=1 FI
	lseek(0, (long)(f->fnxt-f->fend), 1);
	pop();
	return(rc);
}

INT assnum(STRING *p, INT i)
{
	itos(i); replace(p,numbuf);
	return(0);
}

STRING	make(STRING v)
{
	REG STRING	p;

	IF v
	THEN	movstr(v,p=alloc(length(v)));
		return(p);
	ELSE	return(0);
	FI
}


NAMPTR		lookup(REG STRING nam)
{
	REG NAMPTR	nscan=namep;
	REG NAMPTR	*prev = 0;
	INT		LR;

	IF !chkid(nam)
	THEN	failed(nam,notid);
	FI
	WHILE nscan
	DO	IF (LR=cf(nam,nscan->namid))==0
		THEN	return(nscan);
		ELIF LR<0
		THEN	prev = &(nscan->namlft);
		ELSE	prev = &(nscan->namrgt);
		FI
		nscan = *prev;
	OD

	/* add name node */
	nscan=(NAMPTR)alloc(sizeof *nscan);
	nscan->namlft=nscan->namrgt=0;
	nscan->namid=make(nam);
	nscan->namval=0; nscan->namflg=N_DEFAULT; nscan->namenv=0;
	return(*prev = nscan);
}

LOCAL BOOL	chkid(STRING nam)
{
	REG CHAR *	cp=nam;

	IF !letter(*cp)
	THEN	return(FALSE);
	ELSE	WHILE *++cp
		DO IF !alphanum(*cp)
		   THEN	return(FALSE);
		   FI
		OD
	FI
	return(TRUE);
}

LOCAL VOID (*namfn)(NAMPTR);
INT
namscan(VOID (*fn)(NAMPTR))
{
	namfn=fn;
	namwalk(namep);
	return(0);
}

LOCAL VOID	namwalk(REG NAMPTR np)
{
	IF np
	THEN	namwalk(np->namlft);
		(*namfn)(np);
		namwalk(np->namrgt);
	FI
	return(0);
}

VOID	printnam(NAMPTR n)
{
	REG STRING	s;

	sigchk();
	IF (s=n->namval)
	THEN	prs(n->namid);
		prc('='); prs(s);
		newline();
	FI
	return(0);
}

LOCAL STRING	staknam(REG NAMPTR n)
{
	REG STRING	p;

	p=movstr(n->namid,staktop);
	p=movstr("=",p);
	p=movstr(n->namval,p);
	return(getstak(p+1-ADR(stakbot)));
}

VOID	exname(REG NAMPTR n)
{
	IF n->namflg&N_EXPORT
	THEN	free(n->namenv);
		n->namenv = make(n->namval);
	ELSE	free(n->namval);
		n->namval = make(n->namenv);
	FI
	return(0);
}

VOID	printflg(REG NAMPTR n)
{
	IF n->namflg&N_EXPORT
	THEN	prs(export); blank();
	FI
	IF n->namflg&N_RDONLY
	THEN	prs(readonly); blank();
	FI
	IF n->namflg&(N_EXPORT|N_RDONLY)
	THEN	prs(n->namid); newline();
	FI
	return(0);
}

INT	getenv(void)
{
	REG STRING	*e=environ;
	REG STRING	s;

	WHILE *e
	DO	s = *e++;
		IF any('=', s)
		THEN	setname(s, N_ENVNAM);
		FI
	OD
	return(0);
}

LOCAL INT	namec;

VOID	countnam(NAMPTR n)
{
	(void)n;
	namec++;
	return(0);
}

LOCAL STRING 	*argnam;

VOID	pushnam(NAMPTR n)
{
	IF n->namval
	THEN	*argnam++ = staknam(n);
	FI
	return(0);
}

STRING	*setenv(void)
{
	REG STRING	*er;

	namec=0;
	namscan(countnam);
	argnam = er = (STRING *)getstak(namec*BYTESPERWORD+BYTESPERWORD);
	namscan(pushnam);
	*argnam++ = 0;
	return(er);
}
