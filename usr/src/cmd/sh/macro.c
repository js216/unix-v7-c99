#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"
#include	"sym.h"

LOCAL INT	getch(CHAR endch);
LOCAL INT	skipto(CHAR endch);
LOCAL INT	comsubst(void);
LOCAL INT	flush(INT ot);
INT	error(STRING s);
INT	readc(void);
INT	failed(STRING s1, STRING s2);
INT	assign(NAMPTR n, STRING v);
INT	push(FILE af);
INT	pop(void);
INT	estabf(REG STRING s);
INT	trim(STRING at);
INT	chkpipe(INT *pv);
INT	initf(UFD fd);
INT	execute(TREPTR argt, INT execflg, INT *pf1, INT *pf2);
INT	tdystak(REG STKPTR x);
INT	await(INT i);
extern int close(int fd);
extern int write(int fd, char *buf, int n);

LOCAL CHAR	quote;	/* used locally */
LOCAL CHAR	quoted;	/* used locally */



LOCAL STRING	copyto(INT endch)
{
	REG CHAR	c;

	WHILE (c=getch(endch))!=endch ANDF c
	DO pushstak(c|quote) OD
	zerostak();
	IF c!=endch THEN error(badsub) FI
	return(0);
}

LOCAL INT skipto(CHAR endch)
{
	/* skip chars up to } */
	REG CHAR	c;
	WHILE (c=readc()) ANDF c!=endch
	DO	SWITCH c IN

		case SQUOTE:	skipto(SQUOTE); break;

		case DQUOTE:	skipto(DQUOTE); break;

		case DOLLAR:	IF readc()==BRACE
				THEN	skipto('}');
				FI
		ENDSW
	OD
	IF c!=endch THEN error(badsub) FI
	return(0);
}

LOCAL INT getch(CHAR endch)
{
	REG CHAR	d;

retry:
	d=readc();
	IF !subchar(d)
	THEN	return(d);
	FI
	IF d==DOLLAR
	THEN	REG INT	c;
		IF (c=readc(), dolchar(c))
		THEN	NAMPTR		n=(NAMPTR)NIL;
			INT		dolg=0;
			BOOL		bra;
			REG STRING	argp, v;
			CHAR		idb[2];
			STRING		id=idb;

			IF (bra=(c==BRACE)) THEN c=readc() FI
			IF letter(c)
			THEN	argp=(STRING)(long)relstak();
				WHILE alphanum(c) DO pushstak(c); c=readc() OD
				zerostak();
				n=lookup(absstak(argp)); setstak(argp);
				v = n->namval; id = n->namid;
				peekc = c|MARK;;
			ELIF digchar(c)
			THEN	*id=c; idb[1]=0;
				IF astchar(c)
				THEN	dolg=1; c='1';
				FI
				c -= '0';
				v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (STRING)(long)(dolg=0));
			ELIF c=='$'
			THEN	v=pidadr;
			ELIF c=='!'
			THEN	v=pcsadr;
			ELIF c=='#'
			THEN	v=dolladr;
			ELIF c=='?'
			THEN	v=exitadr;
			ELIF c=='-'
			THEN	v=flagadr;
			ELIF bra THEN error(badsub);
			ELSE	goto retry;
			FI
			c = readc();
			IF !defchar(c) ANDF bra
			THEN	error(badsub);
			FI
			argp=0;
			IF bra
			THEN	IF c!='}'
				THEN	argp=(STRING)(long)relstak();
					IF (v==0)NEQ(setchar(c))
					THEN	copyto('}');
					ELSE	skipto('}');
					FI
					argp=absstak(argp);
				FI
			ELSE	peekc = c|MARK; c = 0;
			FI
			IF v
			THEN	IF c!='+'
				THEN	LOOP WHILE (c = *v++)
					     DO pushstak(c|quote); OD
					     IF dolg==0 ORF (++dolg>dolc)
					     THEN break;
					     ELSE v=dolv[dolg]; pushstak(SP|(*id=='*' ? quote : 0));
					     FI
					POOL
				FI
			ELIF argp
			THEN	IF c=='?'
				THEN	failed(id,*argp?argp:badparam);
				ELIF c=='='
				THEN	IF n
					THEN	assign(n,argp);
					ELSE	error(badsub);
					FI
				FI
			ELIF flags&setflg
			THEN	failed(id,badparam);
			FI
			goto retry;
		ELSE	peekc=c|MARK;
		FI
	ELIF d==endch
	THEN	return(d);
	ELIF d==SQUOTE
	THEN	comsubst(); goto retry;
	ELIF d==DQUOTE
	THEN	quoted++; quote^=QUOTE; goto retry;
	FI
	return(d);
}

STRING	macro(STRING as)
{
	/* Strip "" and do $ substitution
	 * Leaves result on top of stack
	 */
	REG BOOL	savqu =quoted;
	REG CHAR	savq = quote;
	FILEHDR		fb;

	push((FILE)&fb); estabf(as);
	usestak();
	quote=0; quoted=0;
	copyto(0);
	pop();
	IF quoted ANDF (stakbot==staktop) THEN pushstak(QUOTE) FI
	quote=savq; quoted=savqu;
	return(fixstak());
}

LOCAL INT comsubst(void)
{
	/* command substn */
	FILEBLK		cb;
	REG CHAR	d;
	REG STKPTR	savptr = fixstak();

	usestak();
	WHILE (d=readc())!=SQUOTE ANDF d
	DO pushstak(d) OD

	BEGIN
	   REG STRING	argc;
	   trim(argc=fixstak());
	   push(&cb); estabf(argc);
	END
	BEGIN
	   REG TREPTR	t = makefork(FPOU,cmd(EOFSYM,MTFLG|NLFLG));
	   INT		pv[2];

	   /* this is done like this so that the pipe
	    * is open only when needed
	    */
	   chkpipe(pv);
	   initf(pv[INPIPE]);
	   execute(t, 0, 0, pv);
	   close(pv[OTPIPE]);
	END
	tdystak(savptr); staktop=movstr(savptr,stakbot);
	WHILE (d=readc()) DO pushstak(d|quote) OD
	await(0);
	WHILE stakbot!=staktop
	DO	IF (*--staktop&STRIP)!=NL
		THEN	++staktop; break;
		FI
	OD
	pop();
	return(0);
}

#define CPYSIZ	512

INT subst(INT in, INT ot)
{
	REG CHAR	c;
	FILEBLK		fb;
	REG INT		count=CPYSIZ;

	push(&fb); initf(in);
	/* DQUOTE used to stop it from quoting */
	WHILE (c=(getch(DQUOTE)&STRIP))
	DO pushstak(c);
	   IF --count == 0
	   THEN	flush(ot); count=CPYSIZ;
	   FI
	OD
	flush(ot);
	pop();
	return(0);
}

LOCAL INT flush(INT ot)
{
	write(ot,stakbot,staktop-stakbot);
	IF flags&execpr THEN write(output,stakbot,staktop-stakbot) FI
	staktop=stakbot;
	return(0);
}
