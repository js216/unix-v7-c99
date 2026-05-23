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

struct xy;
struct val;
int	init(struct xy *p);
int	setopt(int argc, char *argv[]);
int	readin(void);
int	transpose(void);
int	scale(struct xy *p, struct val *v);
int	axes(void);
int	title(void);
int	plot(void);
int	erase(void);
int	space(int x0, int y0, int x1, int y1);
int	move(int xi, int yi);
int	closevt(void);
int	numb(float *np, int *argcp, char ***argvp);
int	limread(struct xy *p, int *argcp, char ***argvp);
int	badarg(void);
int	getfloat(float *p);
int	getstring(void);
int	copystring(int k);
int	getlim(struct xy *p, struct val *v);
int	setlim(struct xy *p);
int	setmark(int *xmark, struct xy *p);
int	submark(int *xmark, int *pxn, float x, struct xy *p);
int	conv(float xv, struct xy *p, int *ip);
int	symbol(int ix, int iy, int k);
int	point(int xi, int yi);
int	label(char *s);
int	cont(int xi, int yi);
int	line(int x0, int y0, int x1, int y1);
int	linemod(char *s);
int	axlab(int c, struct xy *p);
int	putsi(int a);
int	scanf(char *fmt, ...);
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
char *realloc(char *p, unsigned n);
char *malloc(unsigned n);

double ident(double x)
{
	return(x);
}

double
fabs(double x)
{
	return(x < 0 ? -x : x);
}
double
floor(double x)
{
	long n;
	n = x;
	if((double)n > x)
		n--;
	return(n);
}
double
ceil(double x)
{
	long n;
	n = x;
	if((double)n < x)
		n++;
	return(n);
}
double
log10(double x)
{
	double y, y2, term, sum;
	int k, i;
	if(x <= 0)
		return(-INF);
	k = 0;
	while(x >= 10) {
		x /= 10;
		k++;
	}
	while(x < 1) {
		x *= 10;
		k--;
	}
	y = (x - 1)/(x + 1);
	y2 = y*y;
	term = y;
	sum = 0;
	for(i=1; i<30; i += 2) {
		sum += term/i;
		term *= y2;
	}
	return(k + (2*sum)/2.302585092994046);
}
int
main(int argc, char *argv[])
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

int
init(struct xy *p)
{
	p->xf = ident;
	p->xmult = 1;
	return(0);
}

int
setopt(int argc, char *argv[])
{
	char *p0, *p1, *p2;
	float temp;

	xd.xlb = yd.xlb = INF;
	xd.xub = yd.xub = -INF;
	while(--argc > 0) {
		argv++;
		p0 = argv[0];
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
				while ((*p1++ = *p2++))
					;
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
			if(p0[0] == '-')
				badarg();
			if(freopen(argv[0],"r",stdin)==NULL) {
				perror(argv[0]);
				exit(1);
			}
			break;
		}
	}
	return(0);
}

int
limread(register struct xy *p, int *argcp, char ***argvp)
{
	if(*argcp>1 && (*argvp)[1][0]=='l') {
		(*argcp)--;
		(*argvp)++;
		p->xf = log10;
	}
	if(!numb(&p->xlb,argcp,argvp))
		return(0);
	p->xlbf = 1;
	if(!numb(&p->xub,argcp,argvp))
		return(0);
	p->xubf = 1;
	if(!numb(&p->xquant,argcp,argvp))
		return(0);
	p->xqf = 1;
	return(0);
}

int
numb(float *np, int *argcp, register char ***argvp)
{
	register char c;

	if(*argcp <= 1)
		return(0);
	while((c=(*argvp)[1][0]) == '+')
		(*argvp)[1]++;
	if(!(isdigit(c) || (c=='-' && (*argvp)[1][1]<'A') || c=='.'))
		return(0);
	*np = atof((*argvp)[1]);
	(*argcp)--;
	(*argvp)++;
	return(1);
}

int
readin(void)
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
			return(0);
		xx = temp;
		if(absf)
			xx[n].xv = n*dx + absbot;
		else
			if(!getfloat(&xx[n].xv))
				return(0);
		if(!getfloat(&xx[n].yv))
			return(0);
		xx[n].lblptr = -1;
		t = getstring();
		if(t>0)
			xx[n].lblptr = copystring(t);
		n++;
		if(t<0)
			return(0);
	}
}

int
transpose(void)
{
	register int i;
	float f;
	struct xy t;
	if(!transf)
		return(0);
	t = xd; xd = yd; yd = t;
	for(i= 0;i<n;i++) {
		f = xx[i].xv; xx[i].xv = xx[i].yv; xx[i].yv = f;
	}
	return(0);
}

int
copystring(int k)
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
modceil(float f, float t)
{

	t = fabs(t);
	return(ceil(f/t)*t);
}

float
modfloor(float f, float t)
{
	t = fabs(t);
	return(floor(f/t)*t);
}

int
getlim(register struct xy *p, struct val *v)
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
	return(0);
}

struct z {
	float lb,ub,mult,quant;
};
struct z setloglim(int lbf, int ubf, float lb, float ub);
struct z setlinlim(int lbf, int ubf, float xlb, float xub);

int
setlim(register struct xy *p)
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
		return(0);
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
			return(0);
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
	return(0);
}

struct z
setloglim(int lbf, int ubf, float lb, float ub)
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
setlinlim(int lbf, int ubf, float xlb, float xub)
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

int
scale(register struct xy *p, struct val *v)
{
	float edge;

	getlim(p,v);
	setlim(p);
	edge = top-bot;
	p->xa = p->xsize*edge/((*p->xf)(p->xub) - (*p->xf)(p->xlb));
	p->xbot = bot + edge*p->xoff;
	p->xtop = p->xbot + (top-bot)*p->xsize;
	p->xb = p->xbot - (*p->xf)(p->xlb)*p->xa + .5;
	return(0);
}

int
axes(void)
{
	register int i;
	int mark[50];
	int xn, yn;
	if(gridf==0)
		return(0);

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
	return(0);
}

int
setmark(int *xmark, register struct xy *p)
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
int
submark(int *xmark, int *pxn, float x, struct xy *p)
{
	if(1.001*p->xlb < x && .999*p->xub > x)
		xmark[(*pxn)++] = log10(x)*p->xa + p->xb;
	return(0);
}

int
plot(void)
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
	return(0);
}

int
conv(float xv, register struct xy *p, int *ip)
{
	long ix;
	ix = p->xa*(*p->xf)(xv*p->xmult) + p->xb;
	if(ix<p->xbot || ix>p->xtop)
		return(0);
	*ip = ix;
	return(1);
}

int
getfloat(float *p)
{
	register int i;

	i = scanf("%f",p);
	return(i==1);
}

int
getstring(void)
{
	register int i;
	char junk[20];
	i = scanf("%1s",labbuf);
	if(i==-1)
		return(-1);
	switch(*labbuf) {
	default:
		if(!isdigit(*labbuf)) {
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
symbol(int ix, int iy, int k)
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
		return((!brkf)|(k<0));
	}
}

int
title(void)
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
	return(0);
}

int
axlab(int c, struct xy *p)
{
	char buf[50];
	sprintf(buf,"%g -%s%c- %g", p->xlb/p->xmult,
		p->xf==log10?"log ":"", c, p->xub/p->xmult);
	label(buf);
	return(0);
}

int
badarg(void)
{
	fprintf(stderr,"graph: error in arguments\n");
	exit(1);
	return(0);
}
int
putsi(int a)
{
	putc(a, stdout);
	putc(a >> 8, stdout);
	return(0);
}
int
space(int x0, int y0, int x1, int y1)
{
	putc('s', stdout);
	putsi(x0);
	putsi(y0);
	putsi(x1);
	putsi(y1);
	return(0);
}
int
erase(void)
{
	putc('e', stdout);
	return(0);
}
int
move(int xi, int yi)
{
	putc('m', stdout);
	putsi(xi);
	putsi(yi);
	return(0);
}
int
cont(int xi, int yi)
{
	putc('n', stdout);
	putsi(xi);
	putsi(yi);
	return(0);
}
int
line(int x0, int y0, int x1, int y1)
{
	putc('l', stdout);
	putsi(x0);
	putsi(y0);
	putsi(x1);
	putsi(y1);
	return(0);
}
int
point(int xi, int yi)
{
	putc('p', stdout);
	putsi(xi);
	putsi(yi);
	return(0);
}
int
label(char *s)
{
	int i;
	putc('t', stdout);
	for(i=0; s[i]; i++)
		putc(s[i], stdout);
	putc('\n', stdout);
	return(0);
}
int
linemod(char *s)
{
	int i;
	putc('f', stdout);
	for(i=0; s[i]; i++)
		putc(s[i], stdout);
	putc('\n', stdout);
	return(0);
}
int
closevt(void)
{
	fflush(stdout);
	return(0);
}
