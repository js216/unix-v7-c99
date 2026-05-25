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

void	execexp(STRING s, UFD f);
INT	sigchk(void);
INT	getarg(COMPTR ac);
INT	syslook(STRING w, struct sysnod syswds[]);
INT	setlist(REG ARGPTR arg, INT xp);
VOID	prn(INT n);
INT	blank(void);
INT	newline(void);
INT	prt(L_INT t);
INT	pathopen(REG STRING path, REG STRING name);
INT	failed(STRING s1, STRING s2);
INT	exitsh(INT xno);
INT	stoi(STRING icp);
INT	clrsig(INT i);
INT	getsig(INT n);
INT	ignsig(INT n);
INT	error(STRING s);
INT	chktrap(void);
INT	oldsigs(void);
VOID	execa(STRING at[]);
INT	done(void);
INT	postclr(void);
INT	settmp(void);
INT	chkpipe(INT *pv);
INT	rename(REG INT f1, REG INT f2);
INT	chkopen(STRING idf);
VOID	initio(IOPTR iop);
INT	assnum(STRING *p, INT n);
INT	assign(NAMPTR n, STRING v);
INT	readvar(STRING *names);
INT	options(INT argc, STRING *argv);
INT	replace(REG STRING *a, STRING v);
DOLPTR	freeargs(DOLPTR blk);
INT	gmatch(REG STRING s, REG STRING p);
INT	cf(STRING s1, STRING s2);
INT	exitset(void);
INT	namscan(VOID (*fn)(NAMPTR));
INT	push(FILE af);
INT	pop(void);
INT	initf(UFD fd);
INT	estabf(REG STRING s);
INT	trim(STRING at);
INT	tdystak(REG STKPTR x);
INT	builtin(void);
extern int chdir(char *p);
extern int signal();
extern int times(long *t);
extern int umask(int m);
extern int fork(void);
extern int alarm(unsigned sec);
extern int pause(void);
extern int close(int fd);
extern int dup();
LOCAL INT	parent;

extern SYSTAB	commands;



/* ========	command execution	========*/


INT execute(TREPTR argt, INT execflg, INT *pf1, INT *pf2)
{
	/* `stakbot' is preserved by this routine */
	REG TREPTR	t;
	STKPTR		sav=savstak();

	sigchk();

	IF (t=argt) ANDF execbrk==0
	THEN	REG INT		treeflgs;
		INT		oldexit, type;
		REG STRING	*com;

		treeflgs = t->tretyp; type = treeflgs&COMMSK;
		oldexit=exitval; exitval=0;

		SWITCH type IN

		case TCOM:
			BEGIN
			COMPTR		c=(COMPTR)t;
			STRING		a1;
			INT		argn, internal;
			ARGPTR		schain=gchain;
			IOPTR		io=c->comio;
			gchain=0;
			argn = getarg(c);
			com=scan(argn);
			a1=com[1]; gchain=schain;

			IF ((internal=syslook(com[0],commands)) ORF argn==0)
			THEN	setlist(c->comset, 0);
			FI

			IF argn ANDF (flags&noexec)==0
			THEN	/* print command if execpr */
				IF flags&execpr
				THEN	argn=0;	prs(execpmsg);
					WHILE com[argn]!=ENDARGS
					DO prs(com[argn++]); blank() OD
					newline();
				FI

				SWITCH internal IN

				case SYSDOT:
					IF a1
					THEN	REG INT		f;
	
						IF (f=pathopen(getpath(a1), a1)) < 0
						THEN failed(a1,notfound);
						ELSE execexp(0,f);
						FI
					FI
					break;
	
				case SYSTIMES:
					{
					L_INT	t[4]; times(t);
					prt(t[2]); blank(); prt(t[3]); newline();
					}
					break;
	
				case SYSEXIT:
					exitsh(a1?stoi(a1):oldexit);
					/* fallthrough */
				case SYSNULL:
					io=0;
					break;
	
				case SYSCONT:
					execbrk = -loopcnt; break;
	
				case SYSBREAK:
					IF (execbrk=loopcnt) ANDF a1
					THEN breakcnt=stoi(a1);
					FI
					break;
	
				case SYSTRAP:
					IF a1
					THEN	BOOL	clear;
						IF (clear=digit(*a1))==0
						THEN	++com;
						FI
						WHILE *++com
						DO INT	i;
						   IF (i=stoi(*com))>=MAXTRAP ORF i<MINTRAP
						   THEN	failed(*com,badtrap);
						   ELIF clear
						   THEN	clrsig(i);
						   ELSE	replace(&trapcom[i],a1);
							IF *a1
							THEN	getsig(i);
							ELSE	ignsig(i);
							FI
						   FI
						OD
					ELSE	/* print out current traps */
						INT		i;
	
						FOR i=0; i<MAXTRAP; i++
						DO IF trapcom[i]
						   THEN	prn(i); prs(colon); prs(trapcom[i]); newline();
						   FI
						OD
					FI
					break;
	
				case SYSEXEC:
					com++;
					initio(io); ioset=0; io=0;
					IF a1==0 THEN break FI
					/* fallthrough */
				case SYSLOGIN:
					flags |= forked;
					oldsigs(); execa(com); done();
					/* fallthrough */
				case SYSCD:
					IF flags&rshflg
					THEN	failed(com[0],restricted);
					ELIF (a1==0 ANDF (a1=homenod.namval)==0) ORF chdir(a1)<0
					THEN	failed(a1,baddir);
					FI
					break;
	
				case SYSSHFT:
					IF dolc<1
					THEN	error(badshift);
					ELSE	dolv++; dolc--;
					FI
					assnum(&dolladr, dolc);
					break;
	
				case SYSWAIT:
					await(-1);
					break;
	
				case SYSREAD:
					exitval=readvar(&com[1]);
					break;

/*
				case SYSTST:
					exitval=testcmd(com);
					break;
*/

				case SYSSET:
					IF a1
					THEN	INT	argc;
						argc = options(argn,com);
						IF argc>1
						THEN	setargs(com+argn-argc);
						FI
					ELIF c->comset==0
					THEN	/*scan name chain and print*/
						namscan(printnam);
					FI
					break;
	
				case SYSRDONLY:
					exitval=N_RDONLY;
					/* fallthrough */
				case SYSXPORT:
					IF exitval==0 THEN exitval=N_EXPORT; FI
	
					IF a1
					THEN	WHILE *++com
						DO attrib(lookup(*com), exitval) OD
					ELSE	namscan(printflg);
					FI
					exitval=0;
					break;
	
				case SYSEVAL:
					IF a1
					THEN	execexp(a1,(UFD)(long)&com[2]);
					FI
					break;

                                case SYSUMASK:
                                        if (a1) {
						int c, i;
                                                i = 0;
                                                while ((c = *a1++) >= '0' &&
                                                        c <= '7')
                                                        i = (i << 3) + c - '0';
                                                umask(i);
                                        } else {
                                                int i, j;
                                                umask(i = umask(0));
                                                prc('0');
                                                for (j = 6; j >= 0; j -= 3)
                                                        prc(((i>>j)&07) + '0');
                                                newline();
                                        }
                                        break;
	
				default:
					internal=builtin(); (void)argn;
	
				ENDSW

				IF internal
				THEN	IF io THEN error(illegal) FI
					chktrap();
					break;
				FI
			ELIF c->comio==0
			THEN	break;
			FI
			END
			/* fallthrough */
		case TFORK:
			IF execflg ANDF (treeflgs&(FAMP|FPOU))==0
			THEN	parent=0;
			ELSE	WHILE (parent=fork()) == -1
				DO sigchk(); alarm(10); pause() OD
			FI

			IF parent
			THEN	/* This is the parent branch of fork;    */
				/* it may or may not wait for the child. */
				IF treeflgs&FPRS ANDF flags&ttyflg
				THEN	prn(parent); newline();
				FI
				IF treeflgs&FPCL THEN closepipe(pf1) FI
				IF (treeflgs&(FAMP|FPOU))==0
				THEN	await(parent);
				ELIF (treeflgs&FAMP)==0
				THEN	post(parent);
				ELSE	assnum(&pcsadr, parent);
				FI

				chktrap();
				break;


			ELSE	/* this is the forked branch (child) of execute */
				flags |= forked; iotemp=0;
				postclr();
				settmp();

				/* Turn off INTR and QUIT if `FINT'  */
				/* Reset ramaining signals to parent */
				/* except for those `lost' by trap   */
				oldsigs();
				IF treeflgs&FINT
				THEN	signal(INTR,1); signal(QUIT,1);
				FI

				/* pipe in or out */
				IF treeflgs&FPIN
				THEN	rename(pf1[INPIPE],0);
					close(pf1[OTPIPE]);
				FI
				IF treeflgs&FPOU
				THEN	rename(pf2[OTPIPE],1);
					close(pf2[INPIPE]);
				FI

				/* default std input for & */
				IF treeflgs&FINT ANDF ioset==0
				THEN	rename(chkopen(devnull),0);
				FI

				/* io redirection */
				initio(t->treio);
				IF type!=TCOM
				THEN	execute(((FORKPTR)t)->forktre,1,(INT *)0,(INT *)0);
				ELIF com[0]!=ENDARGS
				THEN	setlist(((COMPTR)t)->comset,N_EXPORT);
					execa(com);
				FI
				done();
			FI
			break;

		case TPAR:
			rename(dup(2),output);
			execute(((PARPTR)t)->partre,execflg,(INT *)0,(INT *)0);
			done();
			/* fallthrough */

		case TFIL:
			BEGIN
			   REG LSTPTR	l=(LSTPTR)t;
			   INT pv[2]; chkpipe(pv);
			   IF execute(l->lstlef, 0, pf1, pv)==0
			   THEN	execute(l->lstrit, execflg, pv, pf2);
			   ELSE	closepipe(pv);
			   FI
			END
			break;

		case TLST:
			execute(((LSTPTR)t)->lstlef,0,(INT *)0,(INT *)0);
			execute(((LSTPTR)t)->lstrit,execflg,(INT *)0,(INT *)0);
			break;

		case TAND:
			IF execute(((LSTPTR)t)->lstlef,0,(INT *)0,(INT *)0)==0
			THEN	execute(((LSTPTR)t)->lstrit,execflg,(INT *)0,(INT *)0);
			FI
			break;

		case TORF:
			IF execute(((LSTPTR)t)->lstlef,0,(INT *)0,(INT *)0)!=0
			THEN	execute(((LSTPTR)t)->lstrit,execflg,(INT *)0,(INT *)0);
			FI
			break;

		case TFOR:
			BEGIN
			   REG FORPTR	f=(FORPTR)t;
			   NAMPTR	n = lookup(f->fornam);
			   STRING	*args;
			   DOLPTR	argsav=0;

			   IF f->forlst==0
			   THEN    args=dolv+1;
				   argsav=useargs();
			   ELSE	   ARGPTR	schain=gchain;
				   gchain=0;
				   trim((args=scan(getarg(f->forlst)))[0]);
				   gchain=schain;
			   FI
			   loopcnt++;
			   WHILE *args!=ENDARGS ANDF execbrk==0
			   DO	assign(n,*args++);
				execute(f->fortre,0,(INT *)0,(INT *)0);
				IF (signed char)execbrk<0 THEN execbrk=0 FI
			   OD
			   IF breakcnt THEN breakcnt-- FI
			   execbrk=breakcnt; loopcnt--;
			   argfor=freeargs(argsav);
			END
			break;

		case TWH:
		case TUN:
			BEGIN
			   REG WHPTR	w=(WHPTR)t;
			   INT		i=0;

			   loopcnt++;
			   WHILE execbrk==0 ANDF (execute(w->whtre,0,(INT *)0,(INT *)0)==0)==(type==TWH)
			   DO i=execute(w->dotre,0,(INT *)0,(INT *)0);
			      IF (signed char)execbrk<0 THEN execbrk=0 FI
			   OD
			   IF breakcnt THEN breakcnt-- FI
			   execbrk=breakcnt; loopcnt--; exitval=i;
			END
			break;

		case TIF:
			IF execute(((IFPTR)t)->iftre,0,(INT *)0,(INT *)0)==0
			THEN	execute(((IFPTR)t)->thtre,execflg,(INT *)0,(INT *)0);
			ELSE	execute(((IFPTR)t)->eltre,execflg,(INT *)0,(INT *)0);
			FI
			break;

		case TSW:
			BEGIN
			   REG SWPTR	s=(SWPTR)t;
			   REG STRING	r = mactrim(s->swarg);
			   t=(TREPTR)s->swlst;
			   WHILE t
			   DO	REG REGPTR	re=(REGPTR)t;
				ARGPTR		rex=re->regptr;
				WHILE rex
				DO	REG STRING	s;
					IF gmatch(r,s=macro(rex->argval)) ORF (trim(s), eq(r,s))
					THEN	execute(re->regcom,0,(INT *)0,(INT *)0);
						t=0; break;
					ELSE	rex=rex->argnxt;
					FI
				OD
				IF t THEN t=(TREPTR)re->regnxt FI
			   OD
			END
			break;
		ENDSW
		exitset();
	FI

	sigchk();
	tdystak(sav);
	return(exitval);
}


void
execexp(STRING s, UFD f)
{
	FILEBLK		fb;
	push(&fb);
	IF s
	THEN	estabf(s); fb.feval=(STRING *)(long)f;
	ELIF f>=0
	THEN	initf(f);
	FI
	execute(cmd(NL, NLFLG|MTFLG),0,(INT *)0,(INT *)0);
	pop();
}
