#include "awk.def"
#include	"math.h"
#define RECSIZE 512
#include "awk.h"
#include "stdio.h"
void tempfree(obj a), redirprint(char *s, int a, node *b);
char *format(char *s, node *a);
obj gettemp(void), arrayel(node *a, obj b);

#define FILENUM	10
struct
{
	FILE *fp;
	char *fname;
} files[FILENUM];

extern obj execute(node *u), nodetoobj(node *a);
int pairstack[PA2NUM], paircnt;
node *winner = (node *)NULL;
#define MAXTMP 20
cell tmps[MAXTMP];
static cell nullval ={0,0,0.0,NUM,0};
obj	true	={ OBOOL, BTRUE, 0 };
obj	false	={ OBOOL, BFALSE, 0 };

int
run(void)
{
	return(execute(winner).otype);
}

obj execute(node *u)
{
	register obj (*proc)(node **a, int n);
	obj x;
	node *a;
	extern char *printname[];
	(void)printname;

	if (u==(node *)NULL)
		return(true);
	for (a = u; ; a = a->nnext) {
		if (cantexec(a))
			return(nodetoobj(a));
		if (a->ntype==NPA2)
			proc=dopa2;
		else {
			if (notlegal(a->nobj))
				error(FATAL, "illegal statement %o",
				    a->nobj);
			proc = proctab[a->nobj-FIRSTTOKEN];
		}
		x = (*proc)(a->narg,a->nobj);
		if (isfld(x)) fldbld();
		if (isexpr(a))
			return(x);
		/* a statement, goto next statement */
		if (isjump(x))
			return(x);
		if (a->nnext == (node *)NULL)
			return(x);
		tempfree(x);
	}
}

obj program(node **a, int n)
{
	obj x;
	(void)n;

	if (a[0] != NULL) {
		x = execute(a[0]);
		if (isexit(x))
			return(true);
		if (isjump(x))
			error(FATAL, "unexpected break, continue or next");
		tempfree(x);
	}
	while (getrec()) {
		recloc->tval &= ~NUM;
		recloc->tval |= STR;
		++nrloc->fval;
		nrloc->tval &= ~STR;
		nrloc->tval |= NUM;
		x = execute(a[1]);
		if (isexit(x)) break;
		tempfree(x);
	}
	if (a[2] != NULL) {
		x = execute(a[2]);
		if (isbreak(x) || isnext(x) || iscont(x))
			error(FATAL, "unexpected break, continue or next");
		tempfree(x);
	}
	return(true);
}

obj array(node **a, int n)
{
	obj x, y;
	(void)n;

	x = execute(a[1]);
	y = arrayel(a[0], x);
	tempfree(x);
	return(y);
}

obj arrayel(node *a, obj b)
{
	char *s;
	cell *x;
	obj y;

	s = getsval(b.optr);
	x = (cell *) a;
	if (!(x->tval&ARR)) {
		xfree(x->sval);
		x->tval &= ~STR;
		x->tval |= ARR;
		x->sval = (char *) makesymtab();
	}
	y.optr = setsymtab(s, tostring(""), 0.0, STR, (cell **)x->sval);
	y.otype = OCELL;
	y.osub = CVAR;
	return(y);
}

obj matchop(node **a, int n)
{
	obj x;
	char *s;
	int i;

	x = execute(a[0]);
	if (isstr(x)) s = x.optr->sval;
	else	s = getsval(x.optr);
	i = match((struct fa *)a[1], s);
	tempfree(x);
	if ((n==MATCH && i==1) || (n==NOTMATCH && i==0))
		return(true);
	else
		return(false);
}

obj boolop(node **a, int n)
{
	obj x, y;
	int i;

	x = execute(a[0]);
	i = istrue(x);
	tempfree(x);
	switch (n) {
	default:
		error(FATAL, "unknown boolean operator %d", n);
		/* fallthrough */
	case BOR:
		if (i) return(true);
		y = execute(a[1]);
		i = istrue(y);
		tempfree(y);
		if (i) return(true);
		else return(false);
	case AND:
		if ( !i ) return(false);
		y = execute(a[1]);
		i = istrue(y);
		tempfree(y);
		if (i) return(true);
		else return(false);
	case NOT:
		if (i) return(false);
		else return(true);
	}
}

obj relop(node **a, int n)
{
	int i;
	obj x, y;
	awkfloat j;

	x = execute(a[0]);
	y = execute(a[1]);
	if (x.optr->tval&NUM && y.optr->tval&NUM) {
		j = x.optr->fval - y.optr->fval;
		i = j<0? -1: (j>0? 1: 0);
	} else {
		i = strcmp(getsval(x.optr), getsval(y.optr));
	}
	tempfree(x);
	tempfree(y);
	switch (n) {
	default:
		error(FATAL, "unknown relational operator %d", n);
		/* fallthrough */
	case LT:	if (i<0) return(true);
			else return(false);
	case LE:	if (i<=0) return(true);
			else return(false);
	case NE:	if (i!=0) return(true);
			else return(false);
	case EQ:	if (i==0) return(true);
			else return(false);
	case GE:	if (i>=0) return(true);
			else return(false);
	case GT:	if (i>0) return(true);
			else return(false);
	}
}

void
tempfree(obj a)
{
	if (!istemp(a)) return;
	xfree(a.optr->sval);
	a.optr->tval = 0;
}

obj gettemp(void)
{
	int i;
	obj x;

	for (i=0; i<MAXTMP; i++)
		if (tmps[i].tval==0)
			break;
	if (i==MAXTMP)
		error(FATAL, "out of temporaries in gettemp");
	x.optr = &tmps[i];
	tmps[i] = nullval;
	x.otype = OCELL;
	x.osub = CTEMP;
	return(x);
}

obj indirect(node **a, int n)
{
	obj x;
	int m;
	(void)n;

	x = execute(a[0]);
	m = ftol(getfval(x.optr));
	tempfree(x);
	x.optr = fieldadr(m);
	x.otype = OCELL;
	x.osub = CFLD;
	return(x);
}

obj substr(node **a, int nnn)
{
	char *s, *p;
	obj x, y;
	int k, m, n;
	(void)nnn;

	x = execute(a[0]);
	s = getsval(x.optr);
	k = strlen(s) + 1;
	y = execute(a[1]);
	m = ftol(getfval(y.optr));
	if (m <= 0)
		m = 1;
	else if (m > k)
		m = k;
	tempfree(y);
	if (a[2] != nullstat) {
		y = execute(a[2]);
		n = ftol(getfval(y.optr));
		tempfree(y);
	}
	else
		n = k - 1;
	if (n < 0)
		n = 0;
	else if (n > k - m)
		n = k - m;
	dprintf("substr: m=%d, n=%d, s=%s\n", m, n, s);
	y = gettemp();
	y.optr->sval = p = tostring(s + m - 1);
	p[n] = '\0';
	y.optr->tval = STR;
	tempfree(x);
	return(y);
}

obj sindex(node **a, int nnn)
{
	obj x, y, z;
	char *s1, *s2, *p1, *p2, *q;
	(void)nnn;

	x = execute(a[0]);
	s1 = getsval(x.optr);
	y = execute(a[1]);
	s2 = getsval(y.optr);

	z = gettemp();
	for (p1 = s1; *p1 != '\0'; p1++) {
		for (q=p1, p2=s2; *p2 != '\0' && *q == *p2; q++, p2++)
			;
		if (*p2 == '\0') {
			/* origin 1 */
			setfval(z.optr, (awkfloat) (p1 - s1 + 1));
			break;
		}
	}
	tempfree(x);
	tempfree(y);
	return(z);
}

static char *room(char **bp, int *np, char *p, int k)
{
	int i;

	i = p - *bp;
	if (i + k < *np)
		return(p);
	*np = i + k + RECSIZE;
	if ((*bp = realloc(*bp, *np)) == NULL)
		error(FATAL, "out of space in format");
	return(*bp + i);
}

char *format(char *s, node *a)
{
	char *buf, *p, fmt[100], *t, *os;
	obj x;
	int flag = 0, n, w;
	awkfloat xf;

	os = s;
	n = RECSIZE;
	p = buf = (char *)malloc(n);
	while (*s) {
		p = room(&buf, &n, p, 2);
		if (*s != '%') {
			*p++ = *s++;
			continue;
		}
		if (*(s+1) == '%') {
			*p++ = '%';
			s += 2;
			continue;
		}
		for (t=fmt; (*t++ = *s) != '\0'; s++) {
			if (t >= fmt + sizeof fmt - 2)
				error(FATAL,
				    "format item %.20s... too long",
				    os);
			if (*s >= 'a' && *s <= 'z' && *s != 'l')
				break;
		}
		*t = '\0';
		for (w = 0, t = fmt; *t != '\0'; t++)
			if (*t == '*' ||
			    (*t >= '0' && *t <= '9' &&
			    (w = 10*w + *t - '0') > 100000))
				error(FATAL, "bad format item %.20s...",
				    os);
		w += t - fmt;
		switch (*s) {
		case 'f': case 'e': case 'g':
			flag = 1;
			break;
		case 'd':
			flag = 2;
			if(*(s-1) == 'l') break;
			*(t-1) = 'l';
			*t = 'd';
			*++t = '\0';
			break;
		case 'o': case 'x': case 'c':
			flag = *(s-1)=='l' ? 2 : 3;
			break;
		case 's':
			flag = 4;
			break;
		default:
			flag = 0;
			break;
		}
		if (flag == 0) {
			p = room(&buf, &n, p, w + 1);
			sprintf(p, "%s", fmt);
			p += strlen(p);
			continue;
		}
		if (a == NULL)
			error(FATAL, "not enough arguments in printf(%s)", os);
		x = execute(a);
		a = a->nnext;
		if (flag != 4)	/* watch out for converting to numbers! */
			xf = getfval(x.optr);
		else
			t = x.optr->sval==NULL ? "" : getsval(x.optr);
		p = room(&buf, &n, p, w + (flag==4 ? strlen(t) : 400));
		if (flag==1) sprintf(p, fmt, xf);
		else if (flag==2) sprintf(p, fmt, ftol(xf));
		else if (flag==3) sprintf(p, fmt, (int)ftol(xf));
		else if (flag==4) sprintf(p, fmt, t);
		tempfree(x);
		p += strlen(p);
		s++;
	}
	*p = '\0';
	return(buf);
}

obj asprintf(node **a, int n)
{
	obj x;
	node *y;
	char *s;
	(void)n;

	y = a[0]->nnext;
	x = execute(a[0]);
	s = format(getsval(x.optr), y);
	tempfree(x);
	x = gettemp();
	x.optr->sval = s;
	x.optr->tval = STR;
	return(x);
}

obj arith(node **a, int n)
{
	awkfloat i,j=0;
	obj x,y,z;

	x = execute(a[0]);
	i = getfval(x.optr);
	tempfree(x);
	if (n != UMINUS) {
		y = execute(a[1]);
		j = getfval(y.optr);
		tempfree(y);
	}
	z = gettemp();
	switch (n) {
	default:
		error(FATAL, "illegal arithmetic operator %d", n);
		/* fallthrough */
	case ADD:
		setfval(z.optr, i+j);
		break;
	case MINUS:
		setfval(z.optr, i-j);
		break;
	case MULT:
		setfval(z.optr, i*j);
		break;
	case DIVIDE:
		if (j == 0)
			error(FATAL, "division by zero");
		setfval(z.optr, i/j);
		break;
	case MOD:
		if (j == 0)
			error(FATAL, "division by zero");
		setfval(z.optr, i-j*ipart(i/j));
		break;
	case UMINUS:
		setfval(z.optr, -i);
		break;
	}
	return(z);
}

obj incrdecr(node **a, int n)
{
	obj x, z;
	int k;
	awkfloat xf;

	x = execute(a[0]);
	xf = getfval(x.optr);
	k = (n == PREINCR || n == POSTINCR) ? 1 : -1;
	if (n == PREINCR || n == PREDECR) {
		setfval(x.optr, xf + k);
		return(x);
	}
	z = gettemp();
	setfval(z.optr, xf);
	setfval(x.optr, xf + k);
	tempfree(x);
	return(z);
}


obj assign(node **a, int n)
{
	obj x, y;
	awkfloat xf, yf;

	x = execute(a[0]);
	y = execute(a[1]);
	if (n == ASSIGN) {	/* ordinary assignment */
		if (y.optr->tval&STR) setsval(x.optr, y.optr->sval);
		if (y.optr->tval&NUM) setfval(x.optr, y.optr->fval);
		tempfree(y);
		return(x);
	}
	xf = getfval(x.optr);
	yf = getfval(y.optr);
	switch (n) {
	case ADDEQ:
		setfval(x.optr, xf + yf);
		break;
	case SUBEQ:
		setfval(x.optr, xf - yf);
		break;
	case MULTEQ:
		setfval(x.optr, xf * yf);
		break;
	case DIVEQ:
		if (yf == 0)
			error(FATAL, "division by zero");
		setfval(x.optr, xf / yf);
		break;
	case MODEQ:
		if (yf == 0)
			error(FATAL, "division by zero");
		setfval(x.optr, xf - yf*ipart(xf/yf));
		break;
	default:
		error(FATAL, "illegal assignment operator %d", n);
		break;
	}
	tempfree(y);
	return(x);
}

obj cat(node **a, int q)
{
	obj x,y,z;
	int n;
	char *s;
	(void)q;

	x = execute(a[0]);
	y = execute(a[1]);
	getsval(x.optr);
	getsval(y.optr);
	n = strlen(x.optr->sval) + strlen(y.optr->sval);
	s = (char *)malloc(n+1);
	strcpy(s, x.optr->sval);
	strcat(s, y.optr->sval);
	tempfree(y);
	z = gettemp();
	z.optr->sval = s;
	z.optr->tval = STR;
	tempfree(x);
	return(z);
}

obj pastat(node **a, int n)
{
	obj x;
	(void)n;

	if (a[0]==nullstat)
		x = true;
	else
		x = execute(a[0]);
	if (istrue(x)) {
		tempfree(x);
		x = execute(a[1]);
	}
	return(x);
}

obj dopa2(node **a, int n)
{
	obj x;

	if (pairstack[n]==0) {
		x = execute(a[0]);
		if (istrue(x))
			pairstack[n] = 1;
		tempfree(x);
	}
	if (pairstack[n] == 1) {
		x = execute(a[1]);
		if (istrue(x))
			pairstack[n] = 0;
		tempfree(x);
		x = execute(a[2]);
		return(x);
	}
	return(false);
}

obj aprintf(node **a, int n)
{
	obj x;
	(void)n;

	x = asprintf(a,n);
	if (a[1]==NULL) {
		printf("%s", x.optr->sval);
		tempfree(x);
		return(true);
	}
	redirprint(x.optr->sval, (int)a[1], a[2]);
	return(x);
}

obj split(node **a, int nnn)
{
	obj x;
	cell *ap;
	register char *s, *p;
	char *t, *temp, *os, num[12];
	register int sep;
	int n;
	(void)nnn;

	x = execute(a[0]);
	s = os = tostring(getsval(x.optr));
	temp = tostring(s);
	tempfree(x);
	if (a[2] == nullstat)
		sep = **FS;
	else {
		x = execute(a[2]);
		sep = getsval(x.optr)[0];
		tempfree(x);
	}
	n = 0;
	ap = (cell *) a[1];
	freesymtab(ap);
	dprintf("split: s=|%s|, a=%s, sep=|%c|\n", s, ap->nval, sep);
	ap->tval &= ~STR;
	ap->tval |= ARR;
	ap->sval = (char *) makesymtab();
	/* here we go */
	for (;;) {
		if (sep == ' ')
			while (*s == ' ' || *s == '\t' || *s == '\n')
				s++;
		if (*s == '\0')
			break;
		n++;
		for (p=s, t=temp; (*t = *p) != '\0'; p++, t++)
			if (*p == sep
			  || (sep == ' ' && (*p == '\t' || *p == '\n'))
			  || (sep == '\t' && *p == '\n'))
				break;
		*t = '\0';
		dprintf("n=%d, s=|%s|, temp=|%s|\n", n, s, temp);
		sprintf(num, "%d", n);
		setsymtab(num, tostring(temp), 0.0, STR,
		    (cell **)ap->sval);
		if (*p == '\0')	/* all done */
			break;
		s = p + 1;
	}
	xfree(temp);
	xfree(os);
	x = gettemp();
	x.optr->tval = NUM;
	x.optr->fval = n;
	return(x);
}

obj ifstat(node **a, int n)
{
	obj x;
	(void)n;

	x = execute(a[0]);
	if (istrue(x)) {
		tempfree(x);
		x = execute(a[1]);
	}
	else if (a[2] != nullstat) {
		tempfree(x);
		x = execute(a[2]);
	}
	return(x);
}

obj whilestat(node **a, int n)
{
	obj x;
	(void)n;

	for (;;) {
		x = execute(a[0]);
		if (!istrue(x)) return(x);
		tempfree(x);
		x = execute(a[1]);
		if (isbreak(x)) {
			x = true;
			return(x);
		}
		if (isnext(x) || isexit(x))
			return(x);
		tempfree(x);
	}
}

obj forstat(node **a, int n)
{
	obj x;
	(void)n;

	tempfree(execute(a[0]));
	for (;;) {
		if (a[1]!=nullstat) {
			x = execute(a[1]);
			if (!istrue(x)) return(x);
			else tempfree(x);
		}
		x = execute(a[3]);
		if (isbreak(x)) {	/* turn off break */
			x = true;
			return(x);
		}
		if (isnext(x) || isexit(x))
			return(x);
		tempfree(x);
		tempfree(execute(a[2]));
	}
}

obj instat(node **a, int n)
{
	cell *vp, *arrayp, *cp, **tp;
	obj x;
	int i;
	(void)n;

	vp = (cell *) a[0];
	arrayp = (cell *) a[1];
	if (!(arrayp->tval & ARR))
		error(FATAL, "%s is not an array", arrayp->nval);
	tp = (cell **) arrayp->sval;
	for (i = 0; i < MAXSYM; i++) {	/* this routine knows too much */
		for (cp = tp[i]; cp != NULL; cp = cp->nextval) {
			xfree(vp->sval);
			vp->sval = tostring(cp->nval);
			vp->tval = STR;
			x = execute(a[2]);
			if (isbreak(x)) {
				x = true;
				return(x);
			}
			if (isnext(x) || isexit(x))
				return(x);
			tempfree(x);
		}
	}
	return(true);
}

obj jump(node **a, int n)
{
	obj x;
	(void)a;

	x.otype = OJUMP;
	switch (n) {
	default:
		error(FATAL, "illegal jump type %d", n);
		break;
	case EXIT:
		x.osub = JEXIT;
		break;
	case NEXT:
		x.osub = JNEXT;
		break;
	case BREAK:
		x.osub = JBREAK;
		break;
	case CONTINUE:
		x.osub = JCONT;
		break;
	}
	return(x);
}

obj fncn(node **a, int n)
{
	obj x;
	awkfloat u=0;
	int t;
	(void)n;

	t = (int) a[0];
	x = execute(a[1]);
	if (t == FLENGTH)
		u = (awkfloat) strlen(getsval(x.optr));
	else if (t == FLOG)
		u = log(getfval(x.optr));
	else if (t == FINT)
		u = ipart(getfval(x.optr));
	else if (t == FEXP)
		u = exp(getfval(x.optr));
	else if (t == FSQRT)
		u = sqrt(getfval(x.optr));
	else
		error(FATAL, "illegal function type %d", t);
	tempfree(x);
	x = gettemp();
	setfval(x.optr, u);
	return(x);
}

obj print(node **a, int n)
{
	register node *x;
	obj y;
	char s[RECSIZE];
	(void)n;

	s[0] = '\0';
	for (x=a[0]; x!=NULL; x=x->nnext) {
		y = execute(x);
		if (strlen(s) + strlen(getsval(y.optr)) +
		    strlen(x->nnext==NULL ? *ORS : *OFS) >= RECSIZE)
			error(FATAL,
			    "string %.20s ... too long to print", s);
		strcat(s, getsval(y.optr));
		tempfree(y);
		if (x->nnext==NULL)
			strcat(s, *ORS);
		else
			strcat(s, *OFS);
	}
	if (a[1]==nullstat) {
		printf("%s", s);
		return(true);
	}
	redirprint(s, (int)a[1], a[2]);
	return(false);
}

obj nullproc(node **a, int n) { (void)a; (void)n; return(true); }

obj nodetoobj(node *a)
{
	obj x;

	x.optr = (cell *) a->nobj;
	x.otype = OCELL;
	x.osub = a->subtype;
	if (isfld(x)) fldbld();
	return(x);
}

void
redirprint(char *s, int a, node *b)
{
	register int i;
	obj x;

	x = execute(b);
	getsval(x.optr);
	for (i=0; i<FILENUM; i++)
		if (files[i].fname != NULL &&
		    strcmp(x.optr->sval, files[i].fname) == 0)
			goto doit;
	for (i=0; i<FILENUM; i++)
		if (files[i].fp == 0)
			break;
	if (i >= FILENUM)
		error(FATAL, "too many output files %d", i);
	if (a == '|')	/* a pipe! */
		files[i].fp = popen(x.optr->sval, "w");
	else if (a == APPEND)
		files[i].fp = fopen(x.optr->sval, "a");
	else
		files[i].fp = fopen(x.optr->sval, "w");
	if (files[i].fp == NULL)
		error(FATAL, "can't open file %s", x.optr->sval);
	files[i].fname = tostring(x.optr->sval);
doit:
	fprintf(files[i].fp, "%s", s);
	tempfree(x);
}
