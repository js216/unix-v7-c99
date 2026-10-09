#include <stdio.h>
#include <ctype.h>
#include <math.h>
#define	INF	1.e+37
#define	F	.25

struct xy {
	int	xlbf;	/*flag:explicit lower bound*/
	int 	xubf;	/*flag:explicit upper bound*/
	int	xqf;	/*flag:explicit quantum*/
	double (*xf)();	/*transform function, e.g. log*/
	float	xa,xb;	/*scaling coefficients*/
	float	xlb,xub;	/*lower and upper bound*/
	float	xquant;	/*quantum*/
	float	xoff;		/*screen offset fraction*/
	float	xsize;		/*screen fraction*/
	int	xbot,xtop;	/*screen coords of border*/	
	float	xmult;	/*scaling constant*/
} xd,yd;
struct val {
	float xv;
	float yv;
	int lblptr;
} *xx;

char *labs;
int labsiz;

int tick = 50;
int top = 4000;
int bot = 200;
float absbot;
int	n;
int	erasf = 1;
int	gridf = 2;
int	symbf = 0;
int	absf = 0;
int	transf;
int	brkf;
float	dx;
char	*plotsymb;

double	atof();
int	numb(), copystring(), setmark(), conv(), getfloat(), getstring(), symbol();
void	init(), setopt(), limread(), readin(), transpose(), scale(), axes(), submark(), plot(), title(), axlab(), badarg();
void	space(), erase(), move(), cont(), line(), point(), label(), linemod(), closevt();
int	scanf(char *, ...);
#define BSIZ 80
char	labbuf[BSIZ];
char	titlebuf[BSIZ];

char *modes[] = {
	"disconnected",
	"solid",
	"dotted",
	"dotdashed",
	"shortdashed",
	"longdashed"
};
int mode = 1;
char *realloc();
char *malloc();

double ident(x)
double x;
{
	return(x);
}

int
main(argc,argv)
int argc;
char *argv[];
{

	space(0,0,4096,4096);
	init(&xd);
	init(&yd);
	xd.xsize = yd.xsize = 1.;
	xx = (struct val *)malloc((unsigned)sizeof(struct val));
	labs = malloc(1);
	labs[labsiz++] = 0;
	setopt(argc,argv);
	if(erasf)
		erase();
	readin();
	transpose();
	scale(&xd,(struct val *)&xx->xv);
	scale(&yd,(struct val *)&xx->yv);
	axes();
	title();
	plot();
	move(1,1);
	closevt();
	return(0);
}

void
init(p)
struct xy *p;
{
	p->xf = ident;
	p->xmult = 1;
}

void
setopt(argc,argv)
char *argv[];
int argc;
{
	char *p1, *p2;
	float temp;

	xd.xlb = yd.xlb = INF;
	xd.xub = yd.xub = -INF;
	while(--argc > 0) {
		argv++;
again:		switch(argv[0][0]) {
		case '-':
			argv[0]++;
			goto again;
		case 'l': /* label for plot */
			p1 = titlebuf;
			if (argc>=2) {
				argv++;
				argc--;
				p2 = argv[0];
				while ((*p1++ = *p2++));
			}
			break;

		case 'd':	/*disconnected,obsolete option*/
		case 'm': /*line mode*/
			mode = 0;
			if(!numb(&temp,&argc,&argv))
				break;
			if(temp>=sizeof(modes)/sizeof(*modes))
				mode = 1;
			else if(temp>=0)
				mode = temp;
			break;

		case 'a': /*automatic abscissas*/
			absf = 1;
			dx = 1;
			if(!numb(&dx,&argc,&argv))
				break;
			if(numb(&absbot,&argc,&argv))
				absf = 2;
			break;

		case 's': /*save screen, overlay plot*/
			erasf = 0;
			break;

		case 'g': /*grid style 0 none, 1 ticks, 2 full*/
			gridf = 0;
			if(!numb(&temp,&argc,&argv))
				temp = argv[0][1]-'0';	/*for caompatibility*/
			if(temp>=0&&temp<=2)
				gridf = temp;
			break;

		case 'c': /*character(s) for plotting*/
			if(argc >= 2) {
				symbf = 1;
				plotsymb = argv[1];
				argv++;
				argc--;
			}
			break;

		case 't':	/*transpose*/
			transf = 1;
			break;
		case 'b':	/*breaks*/
			brkf = 1;
			break;
		case 'x':	/*x limits */
			limread(&xd,&argc,&argv);
			break;
		case 'y':
			limread(&yd,&argc,&argv);
			break;
		case 'h': /*set height of plot */
			if(!numb(&yd.xsize, &argc,&argv))
				badarg();
			break;
		case 'w': /*set width of plot */
			if(!numb(&xd.xsize, &argc, &argv))
				badarg();
			break;
		case 'r': /* set offset to right */
			if(!numb(&xd.xoff, &argc, &argv))
				badarg();
			break;
		case 'u': /*set offset up the screen*/
			if(!numb(&yd.xoff,&argc,&argv))
				badarg();
			break;
		default:
			badarg();
		}
	}
}

void
limread(p, argcp, argvp)
register struct xy *p;
int *argcp;
char ***argvp;
{
	if(*argcp>1 && (*argvp)[1][0]=='l') {
		(*argcp)--;
		(*argvp)++;
		p->xf = log10;
	}
	if(!numb(&p->xlb,argcp,argvp))
		return;
	p->xlbf = 1;
	if(!numb(&p->xub,argcp,argvp))
		return;
	p->xubf = 1;
	if(!numb(&p->xquant,argcp,argvp))
		return;
	p->xqf = 1;
}

int
numb(np, argcp, argvp)
int *argcp;
float *np;
register char ***argvp;
{
	register char c;

	if(*argcp <= 1)
		return(0);
	while((c=(*argvp)[1][0]) == '+')
		(*argvp)[1]++;
	if(!(isdigit(c&0377) || (c=='-'&&(*argvp)[1][1]<'A') || c=='.'))
		return(0);
	*np = atof((*argvp)[1]);
	(*argcp)--;
	(*argvp)++;
	return(1);
}

void
readin()
{
	register int t;
	struct val *temp;

	if(absf==1) {
		if(xd.xlbf)
			absbot = xd.xlb;
		else if(xd.xf==log10)
			absbot = 1;
	}
	for(;;) {
		temp = (struct val *)realloc((char*)xx,
			(unsigned)(n+1)*sizeof(struct val));
		if(temp==0)
			return;
		xx = temp;
		if(absf)
			xx[n].xv = n*dx + absbot;
		else
			if(!getfloat(&xx[n].xv))
				return;
		if(!getfloat(&xx[n].yv))
			return;
		xx[n].lblptr = -1;
		t = getstring();
		if(t>0)
			xx[n].lblptr = copystring(t);
		n++;
		if(t<0)
			return;
	}
}

void
transpose()
{
	register int i;
	float f;
	struct xy t;
	if(!transf)
		return;
	t = xd; xd = yd; yd = t;
	for(i= 0;i<n;i++) {
		f = xx[i].xv; xx[i].xv = xx[i].yv; xx[i].yv = f;
	}
}

int
copystring(k)
int k;
{
	register char *temp;
	register int i;
	int q;

	temp = realloc(labs,(unsigned)(labsiz+1+k));
	if(temp==0)
		return(0);
	labs = temp;
	q = labsiz;
	for(i=0;i<=k;i++)
		labs[labsiz++] = labbuf[i];
	return(q);
}

float
modceil(f,t)
float f,t;
{

	t = fabs(t);
	return(ceil(f/t)*t);
}

float
modfloor(f,t)
float f,t;
{
	t = fabs(t);
	return(floor(f/t)*t);
}

void
getlim(p,v)
register struct xy *p;
struct val *v;
{
	register int i;

	i = 0;
	do {
		if(!p->xlbf && p->xlb>v[i].xv)
			p->xlb = v[i].xv;
		if(!p->xubf && p->xub<v[i].xv)
			p->xub = v[i].xv;
		i++;
	} while(i < n);
}

struct z {
	float lb,ub,mult,quant;
} setloglim(), setlinlim();

void
setlim(p)
register struct xy *p;
{
	float t,delta,sign;
	struct z z;
	int mark[50];
	float lb,ub;
	int lbf,ubf;

	lb = p->xlb;
	ub = p->xub;
	delta = ub-lb;
	if(p->xqf) {
		if(delta*p->xquant <=0 )
			badarg();
		return;
	}
	sign = 1;
	lbf = p->xlbf;
	ubf = p->xubf;
	if(delta < 0) {
		sign = -1;
		t = lb;
		lb = ub;
		ub = t;
		t = lbf;
		lbf = ubf;
		ubf = t;
	}
	else if(delta == 0) {
		if(ub > 0) {
			ub = 2*ub;
			lb = 0;
		} 
		else
			if(lb < 0) {
				lb = 2*lb;
				ub = 0;
			} 
			else {
				ub = 1;
				lb = -1;
			}
	}
	if(p->xf==log10 && lb>0 && ub>lb) {
		z = setloglim(lbf,ubf,lb,ub);
		p->xlb = z.lb;
		p->xub = z.ub;
		p->xmult *= z.mult;
		p->xquant = z.quant;
		if(setmark(mark,p)<2) {
			p->xqf = lbf = ubf = 1;
			lb = z.lb; ub = z.ub;
		} else
			return;
	}
	z = setlinlim(lbf,ubf,lb,ub);
	if(sign > 0) {
		p->xlb = z.lb;
		p->xub = z.ub;
	} else {
		p->xlb = z.ub;
		p->xub = z.lb;
	}
	p->xmult *= z.mult;
	p->xquant = sign*z.quant;
}

struct z
setloglim(lbf,ubf,lb,ub)
int lbf,ubf;
float lb,ub;
{
	float r,s,t;
	struct z z;

	for(s=1; lb*s<1; s*=10) ;
	lb *= s;
	ub *= s;
	for(r=1; 10*r<=lb; r*=10) ;
	for(t=1; t<ub; t*=10) ;
	z.lb = !lbf ? r : lb;
	z.ub = !ubf ? t : ub;
	if(ub/lb<100) {
		if(!lbf) {
			if(lb >= 5*z.lb)
				z.lb *= 5;
			else if(lb >= 2*z.lb)
				z.lb *= 2;
		}
		if(!ubf) {
			if(ub*5 <= z.ub)
				z.ub /= 5;
			else if(ub*2 <= z.ub)
				z.ub /= 2;
		}
	}
	z.mult = s;
	z.quant = r;
	return(z);
}

struct z
setlinlim(lbf,ubf,xlb,xub)
int lbf,ubf;
float xlb,xub;
{
	struct z z;
	float r,s,delta;
	float ub,lb;

loop:
	ub = xub;
	lb = xlb;
	delta = ub - lb;
	/*scale up by s, a power of 10, so range (delta) exceeds 1*/
	/*find power of 10 quantum, r, such that delta/10<=r<delta*/
	r = s = 1;
	while(delta*s < 10)
		s *= 10;
	delta *= s;
	while(10*r < delta)
		r *= 10;
	lb *= s;
	ub *= s;
	/*set r=(1,2,5)*10**n so that 3-5 quanta cover range*/
	if(r>=delta/2)
		r /= 2;
	else if(r<delta/5)
		r *= 2;
	z.ub = ubf? ub: modceil(ub,r);
	z.lb = lbf? lb: modfloor(lb,r);
	if(!lbf && z.lb<=r && z.lb>0) {
		xlb = 0;
		goto loop;
	}
	else if(!ubf && z.ub>=-r && z.ub<0) {
		xub = 0;
		goto loop;
	}
	z.quant = r;
	z.mult = s;
	return(z);
}

void
scale(p,v)
register struct xy *p;
struct val *v;
{
	float edge;

	getlim(p,v);
	setlim(p);
	edge = top-bot;
	p->xa = p->xsize*edge/((*p->xf)(p->xub) - (*p->xf)(p->xlb));
	p->xbot = bot + edge*p->xoff;
	p->xtop = p->xbot + (top-bot)*p->xsize;
	p->xb = p->xbot - (*p->xf)(p->xlb)*p->xa + .5;
}

void
axes()
{
	register int i;
	int mark[50];
	int xn, yn;
	if(gridf==0)
		return;

	line(xd.xbot,yd.xbot,xd.xtop,yd.xbot);
	cont(xd.xtop,yd.xtop);
	cont(xd.xbot,yd.xtop);
	cont(xd.xbot,yd.xbot);

	xn = setmark(mark,&xd);
	for(i=0; i<xn; i++) {
		if(gridf==2)
			line(mark[i],yd.xbot,mark[i],yd.xtop);
		if(gridf==1) {
			line(mark[i],yd.xbot,mark[i],yd.xbot+tick);
			line(mark[i],yd.xtop-tick,mark[i],yd.xtop);
		}
	}
	yn = setmark(mark,&yd);
	for(i=0; i<yn; i++) {
		if(gridf==2)
			line(xd.xbot,mark[i],xd.xtop,mark[i]);
		if(gridf==1) {
			line(xd.xbot,mark[i],xd.xbot+tick,mark[i]);
			line(xd.xtop-tick,mark[i],xd.xtop,mark[i]);
		}
	}
}

int
setmark(xmark,p)
int *xmark;
register struct xy *p;
{
	int xn = 0;
	float x,xl,xu;
	float q;
	if(p->xf==log10&&!p->xqf) {
		for(x=p->xquant; x<p->xub; x*=10) {
			submark(xmark,&xn,x,p);
			if(p->xub/p->xlb<=100) {
				submark(xmark,&xn,2*x,p);
				submark(xmark,&xn,5*x,p);
			}
		}
	} else {
		xn = 0;
		q = p->xquant;
		if(q>0) {
			xl = modceil(p->xlb+q/6,q);
			xu = modfloor(p->xub-q/6,q)+q/2;
		} else {
			xl = modceil(p->xub-q/6,q);
			xu = modfloor(p->xlb+q/6,q)-q/2;
		}
		for(x=xl; x<=xu; x+=fabs(p->xquant))
			xmark[xn++] = (*p->xf)(x)*p->xa + p->xb;
	}
	return(xn);
}
void
submark(xmark,pxn,x,p)
int *xmark;
int *pxn;
float x;
struct xy *p;
{
	if(1.001*p->xlb < x && .999*p->xub > x)
		xmark[(*pxn)++] = log10(x)*p->xa + p->xb;
}

void
plot()
{
	int ix,iy;
	int i;
	int conn;

	conn = 0;
	if(mode!=0)
		linemod(modes[mode]);
	for(i=0; i<n; i++) {
		if(!conv(xx[i].xv,&xd,&ix) ||
		   !conv(xx[i].yv,&yd,&iy)) {
			conn = 0;
			continue;
		}
		if(mode!=0) {
			if(conn != 0)
				cont(ix,iy);
			else
				move(ix,iy);
			conn = 1;
		}
		conn &= symbol(ix,iy,xx[i].lblptr);
	}
	linemod(modes[1]);
}

int
conv(xv,p,ip)
float xv;
register struct xy *p;
int *ip;
{
	long ix;
	ix = p->xa*(*p->xf)(xv*p->xmult) + p->xb;
	if(ix<p->xbot || ix>p->xtop)
		return(0);
	*ip = ix;
	return(1);
}

int
getfloat(p)
float *p;
{
	register int i;

	i = scanf("%f",p);
	return(i==1);
}

int
getstring()
{
	register int i;
	char junk[20];
	i = scanf("%1s",labbuf);
	if(i==-1)
		return(-1);
	switch(*labbuf) {
	default:
		if(!isdigit(*labbuf&0377)) {
			ungetc(*labbuf,stdin);
			i = scanf("%s",labbuf);
			break;
		}
		/* fallthrough */
	case '.':
	case '+':
	case '-':
		ungetc(*labbuf,stdin);
		return(0);
	case '"':
		i = scanf("%[^\"\n]",labbuf);
		scanf("%[\"]",junk);
		break;
	}
	if(i==-1)
		return(-1);
	return(strlen(labbuf));
}


int
symbol(ix,iy,k)
int ix,iy,k;
{

	if(symbf==0&&k<0) {
		if(mode==0)
			point(ix,iy);
		return(1);
	} 
	else {
		move(ix,iy);
		label(k>=0?labs+k:plotsymb);
		move(ix,iy);
		return(!brkf|(k<0));
	}
}

void
title()
{
	move(xd.xbot,yd.xbot-60);
	if (titlebuf[0]) {
		label(titlebuf);
		label("       ");
	}
	if(erasf&&gridf) {
		axlab('x',&xd);
		label("  ");
		axlab('y',&yd);
	}
}

void
axlab(c,p)
char c;
struct xy *p;
{
	char buf[50];
	sprintf(buf,"%g -%s%c- %g", p->xlb/p->xmult,
		p->xf==log10?"log ":"", c, p->xub/p->xmult);
	label(buf);
}

void
badarg()
{
	fprintf(stderr,"graph: error in arguments\n");
	exit(1);
}
void
putsi(a)
int a;{
	putc((char)a,stdout);
	putc((char)(a>>8),stdout);
}
void
space(x0,y0,x1,y1)
int x0,y0,x1,y1;{
	putc('s',stdout);
	putsi(x0);
	putsi(y0);
	putsi(x1);
	putsi(y1);
}
void
erase(){
	putc('e',stdout);
}
void
move(xi,yi)
int xi,yi;{
	putc('m',stdout);
	putsi(xi);
	putsi(yi);
}
void
cont(xi,yi)
int xi,yi;{
	putc('n',stdout);
	putsi(xi);
	putsi(yi);
}
void
line(x0,y0,x1,y1)
int x0,y0,x1,y1;{
	putc('l',stdout);
	putsi(x0);
	putsi(y0);
	putsi(x1);
	putsi(y1);
}
void
point(xi,yi)
int xi,yi;{
	putc('p',stdout);
	putsi(xi);
	putsi(yi);
}
void
label(s)
char *s;
{
	int i;
	putc('t',stdout);
	for(i=0;s[i];)putc(s[i++],stdout);
	putc('\n',stdout);
}
void
linemod(s)
char *s;
{
	int i;
	putc('f',stdout);
	for(i=0;s[i];)putc(s[i++],stdout);
	putc('\n',stdout);
}
void
closevt(){
	fflush(stdout);
}
