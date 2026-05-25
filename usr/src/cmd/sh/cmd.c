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

LOCAL IOPTR	inout(IOPTR lastio);
LOCAL VOID	chkword(void);
LOCAL VOID	chksym(INT sym);
LOCAL TREPTR	term(INT flg);
LOCAL TREPTR	makelist(INT type, TREPTR i, TREPTR r);
LOCAL TREPTR	list(INT flg);
LOCAL REGPTR	syncase(REG INT esym);
LOCAL TREPTR	item(BOOL flag);
LOCAL INT	skipnl(void);
LOCAL VOID	prsym(INT sym);
LOCAL VOID	synbad(void);
INT	word(void);
INT	nextc(INT quote);
VOID	chkpr(CHAR c);
VOID	prc(INT c);
VOID	prs(STRING as);
VOID	prn(INT n);
VOID	prp(void);
VOID	newline(void);
VOID	exitsh(INT xno);


/* ========	command line decoding	========*/




TREPTR	makefork(INT flgs, TREPTR i)
{
	REG TREPTR	t;
	REG FORKPTR	f;

	t=(TREPTR)getstak(FORKTYPE);
	f=(FORKPTR)t;
	f->forktyp=flgs|TFORK; f->forktre=i; f->forkio=0;
	return(t);
}

LOCAL TREPTR	makelist(INT type, TREPTR i, TREPTR r)
{
	REG TREPTR	t = 0;
	REG LSTPTR	l;

	IF i==0 ORF r==0
	THEN	synbad();
	ELSE	t = (TREPTR)getstak(LSTTYPE);
		l = (LSTPTR)t;
		l->lsttyp = type;
		l->lstlef = i; l->lstrit = r;
	FI
	return(t);
}

/*
 * cmd
 *	empty
 *	list
 *	list & [ cmd ]
 *	list [ ; cmd ]
 */

TREPTR	cmd(REG INT sym, INT flg)
{
	REG TREPTR	i, e;

	i = list(flg);

	IF wdval==NL
	THEN	IF flg&NLFLG
		THEN	wdval=';'; chkpr(NL);
		FI
	ELIF i==0 ANDF (flg&MTFLG)==0
	THEN	synbad();
	FI

	SWITCH wdval IN

	    case '&':
		IF i
		THEN	i = makefork(FINT|FPRS|FAMP, i);
		ELSE	synbad();
		FI
		/* fallthrough */

	    case ';':
		IF (e=cmd(sym,flg|MTFLG))
		THEN	i=makelist(TLST, i, e);
		FI
		break;

	    case EOFSYM:
		IF sym==NL
		THEN	break;
		FI
		/* fallthrough */

	    default:
		IF sym
		THEN	chksym(sym);
		FI

	ENDSW
	return(i);
}

/*
 * list
 *	term
 *	list && term
 *	list || term
 */

LOCAL TREPTR	list(INT flg)
{
	REG TREPTR	r;
	REG INT		b;

	r = term(flg);
	WHILE r ANDF ((b=(wdval==ANDFSYM)) ORF wdval==ORFSYM)
	DO	r = makelist((b ? TAND : TORF), r, term(NLFLG));
	OD
	return(r);
}

/*
 * term
 *	item
 *	item |^ term
 */

LOCAL TREPTR	term(INT flg)
{
	REG TREPTR	t;

	reserv++;
	IF flg&NLFLG
	THEN	skipnl();
	ELSE	word();
	FI

	IF (t=item(TRUE)) ANDF (wdval=='^' ORF wdval=='|')
	THEN	return(makelist(TFIL, makefork(FPOU,t), makefork(FPIN|FPCL,term(NLFLG))));
	ELSE	return(t);
	FI
}

LOCAL REGPTR	syncase(REG INT esym)
{
	skipnl();
	IF wdval==esym
	THEN	return(0);
	ELSE	REG REGPTR	r=(REGPTR)getstak(REGTYPE);
		r->regptr=0;
		LOOP wdarg->argnxt=r->regptr;
		     r->regptr=wdarg;
		     IF wdval ORF ( word()!=')' ANDF wdval!='|' )
		     THEN synbad();
		     FI
		     IF wdval=='|'
		     THEN word();
		     ELSE break;
		     FI
		POOL
		r->regcom=cmd(0,NLFLG|MTFLG);
		IF wdval==ECSYM
		THEN	r->regnxt=syncase(esym);
		ELSE	chksym(esym);
			r->regnxt=0;
		FI
		return(r);
	FI
}

/*
 * item
 *
 *	( cmd ) [ < in  ] [ > out ]
 *	word word* [ < in ] [ > out ]
 *	if ... then ... else ... fi
 *	for ... while ... do ... done
 *	case ... in ... esac
 *	begin ... end
 */

LOCAL TREPTR	item(BOOL flag)
{
	REG TREPTR	t;
	REG IOPTR	io;

	IF flag
	THEN	io=inout((IOPTR)0);
	ELSE	io=0;
	FI

	SWITCH wdval IN

	    case CASYM:
		BEGIN
		   REG SWPTR	s;
		   t=(TREPTR)getstak(SWTYPE);
		   s=(SWPTR)t;
		   chkword();
		   s->swarg=wdarg->argval;
		   skipnl(); chksym(INSYM|BRSYM);
		   s->swlst=syncase(wdval==INSYM?ESSYM:KTSYM);
		   s->swtyp=TSW;
		   break;
		END

	    case IFSYM:
		BEGIN
		   REG INT	w;
		   REG IFPTR	it;
		   t=(TREPTR)getstak(IFTYPE);
		   it=(IFPTR)t;
		   it->iftyp=TIF;
		   it->iftre=cmd(THSYM,NLFLG);
		   it->thtre=cmd(ELSYM|FISYM|EFSYM,NLFLG);
		   it->eltre=((w=wdval)==ELSYM ? cmd(FISYM,NLFLG) : (w==EFSYM ? (wdval=IFSYM, item(0)) : 0));
		   IF w==EFSYM THEN return(t) FI
		   break;
		END

	    case FORSYM:
		BEGIN
		   REG FORPTR	fr;
		   t=(TREPTR)getstak(FORTYPE);
		   fr=(FORPTR)t;
		   fr->fortyp=TFOR;
		   fr->forlst=0;
		   chkword();
		   fr->fornam=wdarg->argval;
		   IF skipnl()==INSYM
		   THEN	chkword();
			fr->forlst=(COMPTR)item(0);
			IF wdval!=NL ANDF wdval!=';'
			THEN	synbad();
			FI
			chkpr(wdval); skipnl();
		   FI
		   chksym(DOSYM|BRSYM);
		   fr->fortre=cmd(wdval==DOSYM?ODSYM:KTSYM,NLFLG);
		   break;
		END

	    case WHSYM:
	    case UNSYM:
		BEGIN
		   REG WHPTR	wh;
		   t=(TREPTR)getstak(WHTYPE);
		   wh=(WHPTR)t;
		   wh->whtyp=(wdval==WHSYM ? TWH : TUN);
		   wh->whtre = cmd(DOSYM,NLFLG);
		   wh->dotre = cmd(ODSYM,NLFLG);
		   break;
		END

	    case BRSYM:
		t=cmd(KTSYM,NLFLG);
		break;

	    case '(':
		BEGIN
		   REG PARPTR	 p;
		   p=(PARPTR)getstak(PARTYPE);
		   p->partre=cmd(')',NLFLG);
		   p->partyp=TPAR;
		   t=makefork(0,(TREPTR)p);
		   break;
		END

	    default:
		IF io==0
		THEN	return(0);
		FI
		/* fallthrough */

	    case 0:
		BEGIN
		   REG ARGPTR	argp;
		   REG ARGPTR	*argtail;
		   REG ARGPTR	*argset=0;
		   REG COMPTR	c;
		   INT		keywd=1;
		   t=(TREPTR)getstak(COMTYPE);
		   c=(COMPTR)t;
		   c->comio=io; /*initial io chain*/
		   argtail = &(c->comarg);
		   WHILE wdval==0
		   DO	argp = wdarg;
			IF wdset ANDF keywd
			THEN	argp->argnxt=(ARGPTR)argset; argset=(ARGPTR *)argp;
			ELSE	*argtail=argp; argtail = &(argp->argnxt); keywd=flags&keyflg;
			FI
			word();
			IF flag
			THEN c->comio=inout(c->comio);
			FI
		   OD

		   c->comtyp=TCOM; c->comset=(ARGPTR)argset; *argtail=0;
		   return(t);
		END

	ENDSW
	reserv++; word();
	IF (io=inout(io))
	THEN	t=makefork(0,t); t->treio=io;
	FI
	return(t);
}


LOCAL INT	skipnl(void)
{
	WHILE (reserv++, word()==NL) DO chkpr(NL) OD
	return(wdval);
}

LOCAL IOPTR	inout(IOPTR lastio)
{
	REG INT		iof;
	REG IOPTR	iop;
	REG CHAR	c;

	iof=wdnum;

	SWITCH wdval IN

	    case DOCSYM:
		iof |= IODOC; break;

	    case APPSYM:
	    case '>':
		IF wdnum==0 THEN iof |= 1 FI
		iof |= IOPUT;
		IF wdval==APPSYM
		THEN	iof |= IOAPP; break;
		FI
		/* fallthrough */

	    case '<':
		IF (c=nextc(0))=='&'
		THEN	iof |= IOMOV;
		ELIF c=='>'
		THEN	iof |= IORDW;
		ELSE	peekc=c|MARK;
		FI
		break;

	    default:
		return(lastio);
	ENDSW

	chkword();
	iop=(IOPTR)getstak(IOTYPE); iop->ioname=wdarg->argval; iop->iofile=iof;
	IF iof&IODOC
	THEN iop->iolst=iopend; iopend=iop;
	FI
	word(); iop->ionxt=inout(lastio);
	return(iop);
}

LOCAL VOID	chkword(void)
{
	IF word()
	THEN	synbad();
	FI
	return(0);
}

LOCAL VOID	chksym(INT sym)
{
	REG INT		x = sym&wdval;
	IF ((x&SYMFLG) ? x : sym) != wdval
	THEN	synbad();
	FI
	return(0);
}

LOCAL VOID	prsym(INT sym)
{
	IF sym&SYMFLG
	THEN	REG SYSPTR	sp=reserved;
		WHILE sp->sysval
			ANDF sp->sysval!=sym
		DO sp++ OD
		prs(sp->sysnam);
	ELIF sym==EOFSYM
	THEN	prs(endoffile);
	ELSE	IF sym&SYMREP THEN prc(sym) FI
		IF sym==NL
		THEN	prs("newline");
		ELSE	prc(sym);
		FI
	FI
	return(0);
}

LOCAL VOID	synbad(void)
{
	prp(); prs(synmsg);
	IF (flags&ttyflg)==0
	THEN	prs(atline); prn(standin->flin);
	FI
	prs(colon);
	prc(LQ);
	IF wdval
	THEN	prsym(wdval);
	ELSE	prs(wdarg->argval);
	FI
	prc(RQ); prs(unexpected);
	newline();
	exitsh(SYNBAD);
	return(0);
}
