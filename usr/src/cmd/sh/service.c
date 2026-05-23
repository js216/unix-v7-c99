#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"


PROC VOID	gsort(STRING from[], STRING to[]);
LOCAL STRING	execs(STRING ap, REG STRING t[]);
LOCAL INT	split(REG STRING s);
INT	subst(INT in, INT ot);
INT	chkopen(STRING idf);
INT	tmpfil(void);
INT	stoi(STRING icp);
INT	failed(STRING s1, STRING s2);
INT	create(STRING s);
INT	rename(REG INT f1, REG INT f2);
INT	cf(STRING s1, STRING s2);
INT	any(REG CHAR c, STRING s);
INT	namscan(VOID (*fn)(NAMPTR));
INT	trim(STRING at);
INT	sigchk(void);
INT	clearup(void);
INT	execexp(STRING t, INT in);
INT	done(void);
INT	setargs(STRING argi[]);
INT	exitsh(INT xno);
INT	exitset(void);
INT	expand(STRING as, INT rflg);
INT	makearg(REG ARGPTR args);
STRING	*setenv(void);
VOID	exname(REG NAMPTR n);
VOID	prc(INT c);
VOID	prs(STRING as);
VOID	prn(INT n);
VOID	prp(void);
VOID	newline(void);
VOID	blank(void);
extern int close(int fd);
extern int unlink(char *p);
extern int dup();
extern int open(char *p, int f);
extern long lseek(int fd, long off, int whence);
extern int execve(char *p, char **argv, char **env);
extern int wait(int *st);

#define ARGMK	01

INT		errno;
extern STRING	sysmsg[];

/* fault handling */
#define ENOMEM	12
#define ENOEXEC 8
#define E2BIG	7
#define ENOENT	2
#define ETXTBSY 26



/* service routines for `execute' */

VOID	initio(IOPTR iop)
{
	REG STRING	ion;
	REG INT		iof, fd;

	IF iop
	THEN	iof=iop->iofile;
		ion=mactrim(iop->ioname);
		IF *ion ANDF (flags&noexec)==0
		THEN	IF iof&IODOC
			THEN	subst(chkopen(ion),(fd=tmpfil()));
				close(fd); fd=chkopen(tmpout); unlink(tmpout);
			ELIF iof&IOMOV
			THEN	IF eq(minus,ion)
				THEN	fd = -1;
					close(iof&IOUFD);
				ELIF (fd=stoi(ion))>=USERIO
				THEN	failed(ion,badfile);
				ELSE	fd=dup(fd);
				FI
			ELIF (iof&IOPUT)==0
			THEN	fd=chkopen(ion);
			ELIF flags&rshflg
			THEN	failed(ion,restricted);
			ELIF iof&IOAPP ANDF (fd=open(ion,1))>=0
			THEN	lseek(fd, 0L, 2);
			ELSE	fd=create(ion);
			FI
			IF fd>=0
			THEN	rename(fd,iof&IOUFD);
			FI
		FI
		initio(iop->ionxt);
	FI
	return(0);
}

VOID	nullio(IOPTR iop)
{
	REG STRING	ion;
	REG INT		iof, fd;
	IF iop
	THEN	iof=iop->iofile;
		ion=mactrim(iop->ioname);
		IF *ion ANDF (flags&noexec)==0
		THEN	IF iof&IODOC
			THEN	fd=tmpfil(); close(fd); unlink(tmpout);
			ELIF iof&IOMOV
			THEN	;
			ELIF (iof&IOPUT)==0
			THEN	close(chkopen(ion));
			ELIF flags&rshflg
			THEN	failed(ion,restricted);
			ELIF iof&IOAPP ANDF (fd=open(ion,1))>=0
			THEN	lseek(fd, 0L, 2); close(fd);
			ELSE	fd=create(ion); close(fd);
			FI
		FI
		nullio(iop->ionxt);
	FI
	return(0);
}
STRING	getpath(STRING s)
{
	REG STRING	path;
	IF any('/',s)
	THEN	IF flags&rshflg
		THEN	failed(s, restricted);
		ELSE	return(nullstr);
		FI
	ELIF (path = pathnod.namval)==0
	THEN	return(defpath);
	ELSE	return(cpystak(path));
	FI
	return(0);
}

INT	pathopen(REG STRING path, REG STRING name)
{
	REG UFD		f;

	REP path=catpath(path,name);
	PER (f=open(curstak(),0))<0 ANDF path DONE
	return(f);
}

STRING	catpath(REG STRING path, STRING name)
{
	/* leaves result on top of stack */
	REG STRING	scanp = path,
			argp = locstak();

	WHILE *scanp ANDF *scanp!=COLON DO *argp++ = *scanp++ OD
	IF scanp!=path THEN *argp++='/' FI
	IF *scanp==COLON THEN scanp++ FI
	path=(*scanp ? scanp : 0); scanp=name;
	WHILE (*argp++ = *scanp++) DONE
	return(path);
}

LOCAL STRING	xecmsg;
LOCAL STRING	*xecenv;

VOID	execa(STRING at[])
{
	REG STRING	path;
	REG STRING	*t = at;

	IF (flags&noexec)==0
	THEN	xecmsg=notfound; path=getpath(*t);
		namscan(exname);
		xecenv=setenv();
		WHILE (path=execs(path,t)) DONE
		failed(*t,xecmsg);
	FI
	return(0);
}

LOCAL STRING	execs(STRING ap, REG STRING t[])
{
	REG STRING	p, prefix;

	prefix=catpath(ap,t[0]);
	trim(p=curstak());

	sigchk();
	execve(p, &t[0] ,xecenv);
	SWITCH errno IN

	    case ENOEXEC:
		flags=0;
		comdiv=0; ioset=0;
		clearup(); /* remove open files and for loop junk */
		IF input THEN close(input) FI
		close(output); output=2;
		input=chkopen(p);

		/* set up new args */
		setargs(t);
		execexp(0,input);
		done();
		/* fallthrough */

	    case ENOMEM:
		failed(p,toobig);
		/* fallthrough */

	    case E2BIG:
		failed(p,arglist);
		/* fallthrough */

	    case ETXTBSY:
		failed(p,txtbsy);
		/* fallthrough */

	    default:
		xecmsg=badexec;
		/* fallthrough */
	    case ENOENT:
		return(prefix);
	ENDSW
	return(prefix);
}

/* for processes to be waited for */
#define MAXP 20
LOCAL INT	pwlist[MAXP];
LOCAL INT	pwc;

INT postclr(void)
{
	REG INT		*pw = pwlist;

	WHILE pw <= &pwlist[pwc]
	DO *pw++ = 0 OD
	pwc=0;
	return(0);
}

VOID	post(INT pcsid)
{
	REG INT		*pw = pwlist;

	IF pcsid
	THEN	WHILE *pw DO pw++ OD
		IF pwc >= MAXP-1
		THEN	pw--;
		ELSE	pwc++;
		FI
		*pw = pcsid;
	FI
	return(0);
}

VOID	await(INT i)
{
	INT		rc=0, wx=0;
	INT		w;
	INT		ipwc = pwc;

	post(i);
	WHILE pwc
	DO	REG INT		p;
		REG INT		sig;
		INT		w_hi;

		BEGIN
		   REG INT	*pw=pwlist;
		   p=wait(&w);
		   WHILE pw <= &pwlist[ipwc]
		   DO IF *pw==p
		      THEN *pw=0; pwc--;
		      ELSE pw++;
		      FI
		   OD
		END

		IF p == -1 THEN continue FI

		w_hi = (w>>8)&LOBYTE;

		IF (sig = w&0177)
		THEN	IF sig == 0177	/* ptrace! return */
			THEN	prs("ptrace: ");
				sig = w_hi;
			FI
			IF sysmsg[sig]
			THEN	IF i!=p ORF (flags&prompt)==0 THEN prp(); prn(p); blank() FI
				prs(sysmsg[sig]);
				IF w&0200 THEN prs(coredump) FI
			FI
			newline();
		FI

		IF rc==0
		THEN	rc = (sig ? sig|SIGFLG : w_hi);
		FI
		wx |= w;
	OD

	IF wx ANDF flags&errflg
	THEN	exitsh(rc);
	FI
	exitval=rc; exitset();
	return(0);
}

BOOL		nosubst;

INT trim(STRING at)
{
	REG STRING	p;
	REG CHAR	c;
	REG CHAR	q=0;

	IF (p=at)
	THEN	WHILE (c = *p)
		DO *p++=c&STRIP; q |= c OD
	FI
	nosubst=q&QUOTE;
	return(0);
}

STRING	mactrim(STRING s)
{
	REG STRING	t=macro(s);
	trim(t);
	return(t);
}

STRING	*scan(INT argn)
{
	REG ARGPTR	argp = (ARGPTR)(long)(Rcheat(gchain)&~ARGMK);
	REG STRING	*comargn, *comargm;

	comargn=(STRING *)getstak(BYTESPERWORD*argn+BYTESPERWORD); comargm = comargn += argn; *comargn = ENDARGS;

	WHILE argp
	DO	*--comargn = argp->argval;
		IF (argp = argp->argnxt)
		THEN trim(*comargn);
		FI
		IF argp==0 ORF Rcheat(argp)&ARGMK
		THEN	gsort(comargn,comargm);
			comargm = comargn;
		FI
		/* Lcheat(argp) &= ~ARGMK; */
		argp = (ARGPTR)(long)(Rcheat(argp)&~ARGMK);
	OD
	return(comargn);
}

LOCAL VOID	gsort(STRING from[], STRING to[])
{
	INT		k, m, n;
	REG INT		i, j;

	IF (n=to-from)<=1 THEN return(0) FI

	FOR j=1; j<=n; j*=2 DONE

	FOR m=2*j-1; m/=2;
	DO  k=n-m;
	    FOR j=0; j<k; j++
	    DO	FOR i=j; i>=0; i-=m
		DO  REG STRING *fromi; fromi = &from[i];
		    IF cf(fromi[m],fromi[0])>0
		    THEN break;
		    ELSE STRING s; s=fromi[m]; fromi[m]=fromi[0]; fromi[0]=s;
		    FI
		OD
	    OD
	OD
	return(0);
}

/* Argument list generation */

INT	getarg(COMPTR ac)
{
	REG ARGPTR	argp;
	REG INT		count=0;
	REG COMPTR	c;

	IF (c=ac)
	THEN	argp=c->comarg;
		WHILE argp
		DO	count += split(macro(argp->argval));
			argp=argp->argnxt;
		OD
	FI
	return(count);
}

LOCAL INT	split(REG STRING s)
{
	REG STRING	argp;
	REG ARGPTR	arg;
	REG INT		c;
	INT		count=0;

	LOOP	sigchk(); argp=locstak()+BYTESPERWORD;
		WHILE (c = *s++, !any(c,ifsnod.namval) && c)
		DO *argp++ = c OD
		IF argp==staktop+BYTESPERWORD
		THEN	IF c
			THEN	continue;
			ELSE	return(count);
			FI
		ELIF c==0
		THEN	s--;
		FI
		arg=(ARGPTR)endstak(argp);
		IF (c=expand(arg->argval,0))
		THEN	count += c;
		ELSE	/* assign(&fngnod, argp->argval); */
			makearg(arg); count++;
		FI
		Lcheat(gchain) |= ARGMK;
	POOL
}
