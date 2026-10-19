/*
 *  Print execution profile
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

typedef	short UNIT;		/* unit of profiling */

struct stat stbuf;
struct	nl {
	char	name[16];
	unsigned value;
	float	time;
	long	ncall;
};

struct hdr {
	UNIT	*lowpc;
	UNIT	*highpc;
	int	ncount;
};

struct nl nl[1200];

struct cnt {
	unsigned cvalue;
	long	cncall;
} cbuf[350];

FILE	*pfile, *nfile;
unsigned highpc;
unsigned lowpc;
double	ransca;
double	ranoff;
unsigned pcl;
unsigned pch;
unsigned bufs;
int	nname;
double	ftim;
double	actime;
double	totime;
double	maxtime;
double	scale;
double	lastx;
double	lasty;
struct nl *np;
struct nl *npe;
int	aflg;
int	vflg;
int	lflg;

int	min(unsigned a, unsigned b), max(unsigned a, unsigned b);
int	timcmp(char *a, char *b), valcmp(char *a, char *b);
void	done(void);
int
main(int argc, char **argv)
{
	char *namfil;
	int i, overlap;
#ifdef plot
	long pfpos;
	double lastsx;
	double tx, ty;
#endif
	struct cnt *cp;
	unsigned eh[13], sh[10], sym[4];
	long sa, st;
	unsigned n;
	struct hdr h;

	lowpc = -1;
	highpc = -1;
	argv++;
	namfil = "a.out";
	while (argc>1) {
		if (**argv == '-') {
			if (*++*argv == 'l')
				lflg++;
			if (**argv == 'a')
				aflg = 040;
			if(**argv == 'v')
				vflg++;
			if(**argv >= '0' && **argv <= '9') {
				i = atoi(*argv);
				if(lowpc == (unsigned)-1)
					lowpc = i;
				else
					highpc = i;
			}
		} else
			namfil = *argv;
		argc--;
		argv++;
	}
	if (lowpc >= 100)
		lowpc = 0;
	if(highpc <= lowpc || highpc > 100)
		highpc = 100;
	ransca = 100./(highpc-lowpc);
	ranoff = 2040. + 40.8*lowpc*ransca;
	if((nfile=fopen(namfil,"r"))==NULL) {
		fprintf(stderr, "%s: not found\n", namfil);
		done();
	}
	if (fread((char *)eh, sizeof eh, 1, nfile) != 1 || eh[0] != 0x464c457f) {
		fprintf(stderr, "%s: bad format\n", namfil);
		done();
	}
	n = sa = st = 0;
	for (i = eh[12]&0xffff; --i >= 0 && n == 0; ) {
		fseek(nfile, eh[8] + i*40, 0);
		if (fread((char *)sh, sizeof sh, 1, nfile) != 1)
			break;
		if (sh[1] == 2) {
			sa = sh[4];
			n = sh[5];
			fseek(nfile, eh[8] + sh[6]*40, 0);
			if (fread((char *)sh, sizeof sh, 1, nfile) != 1)
				n = 0;
			st = sh[4];
		}
	}
	if((pfile = fopen("mon.out","r")) == NULL) {
		fprintf(stderr, "No mon.out\n");
		done();
	}
	fstat(fileno(pfile), &stbuf);
	if (fread((char *)&h, sizeof(struct hdr), 1, pfile) != 1 ||
	    (unsigned)h.ncount > 350 || (unsigned)h.highpc <= (unsigned)h.lowpc) {
		fprintf(stderr, "mon.out: bad format\n");
		done();
	}
	lowpc = (unsigned)h.lowpc/sizeof(UNIT);
	highpc = (unsigned)h.highpc/sizeof(UNIT);
	bufs = stbuf.st_size - sizeof(struct hdr) - h.ncount*sizeof(struct cnt);
	fread((char *)cbuf, sizeof(struct cnt), h.ncount, pfile);
#ifdef plot
	pfpos = ftell(pfile);
#endif
	npe = nl;
	for (nname = 0; n >= sizeof sym; n -= sizeof sym, sa += sizeof sym) {
		fseek(nfile, sa, 0);
		if (npe >= &nl[1199] || fread((char *)sym, sizeof sym, 1, nfile) != 1)
			break;
		if ((sym[3]&017) > 2 || (sym[3]>>16) == 0 || (sym[3]>>16) >= (eh[12]&0xffff))
			continue;
		if (aflg==0 && (sym[3]&0360) != 020)
			continue;
		fseek(nfile, eh[8] + (sym[3]>>16)*40, 0);
		if (fread((char *)sh, sizeof sh, 1, nfile) != 1 || (sh[2]&4) == 0)
			continue;
		fseek(nfile, st + sym[0], 0);
		npe->name[fread(npe->name, 1, sizeof npe->name - 1, nfile)] = 0;
		if (npe->name[0] == '$')
			continue;
		npe->value = sym[1]/sizeof(UNIT);
		npe++;
		nname++;
	}
	if (nname == 0) {
		fprintf(stderr, "%s: no symbols\n", namfil);
		done();
	}
	npe->value = -1;
	npe++;
	qsort((char *)nl, nname, sizeof(struct nl), valcmp);
	for (cp = cbuf; cp < &cbuf[h.ncount]; cp++) {
		if (cp->cvalue == 0)
			continue;
		for (np = nl; np[1].value <= cp->cvalue/sizeof(UNIT); np++)
			;
		if (np->value <= cp->cvalue/sizeof(UNIT))
			np->ncall = cp->cncall;
	}
	scale = highpc - lowpc;
	scale /= bufs/sizeof(UNIT);
	for(i=0;;i++) {
		register int j;
		unsigned short ccnt;
		fread((char *)&ccnt, sizeof(ccnt), 1, pfile);
		if(feof(pfile))
			break;
		if (ccnt == 0)
			continue;
		pcl = lowpc + scale*i;
		pch = lowpc + scale*(i+1);
		ftim = ccnt;
		totime += ftim;
		if(ftim > maxtime)
			maxtime = ftim;
		for (j=0; j<nname; j++) {
			if (pch < nl[j].value)
				break;
			if (pcl >= nl[j+1].value)
				continue;
			overlap=(min(pch,nl[j+1].value)-max(pcl,nl[j].value));
			nl[j].time += overlap*ftim/scale;
		}
	}
	if (totime==0.0) {
		fprintf(stderr, "No time accumulated\n");
		done();
	}
#ifdef plot
	if(!vflg)
		goto print;
	openpl();
	erase();
	space(-2048, -2048, 2048, 2048);
	line(-2040, -2040, -2040, 2040);
	line(0, 2040, 0, -2040);
	for(i=0; i<11; i++)
		line(-2040, 2040-i*408, 0, 2040-i*408);
	lastx = 0.;
	lasty = ranoff;
	scale = (4080.*ransca)/(bufs/sizeof(UNIT));
	fclose(pfile);	/*to turn off eof*/
	pfile = fopen("mon.out", "r");
	fseek(pfile, pfpos, 0);
	lastsx = 0.0;
	for(;;) {
		unsigned UNIT ccnt;
		fread((char *)&ccnt, sizeof(ccnt), 1, pfile);
		if(feof(pfile))
			break;
		ftim = ccnt;
		tx = lastsx;
		ty = lasty;
		lastsx -= 2000.*ftim/totime;
		lasty -= scale;
		if(lasty >= -2040. && ty <= 2040.) {
			line((int)tx, (int)ty, (int)lastsx, (int)lasty);
			if (ccnt!=0 || lastx!=0.0) {
				tx = lastx;
				lastx = -ftim*2000./maxtime;
				ty += scale/2;
				line(0, (int)ty, (int)tx, (int)ty);
			}
		}
	}
	scale = (4080.*ransca)/(highpc-lowpc);
	lastx = 50.;
	for(np = nl; np<npe;  np++) {
		if(np->value < lowpc)
			continue;
		if(np->value >= highpc)
			continue;
		ftim = np->time/totime;
		lasty = ranoff - (np->value - lowpc)*scale;
		if(lasty >= -2040. && lasty <= 2040.) {
			char bufl[8+3], *namp;
			register j;
			line(0, (int)lasty, 50, (int)lasty);
			line((int)(lastx-50),(int)lasty,(int)lastx,(int)lasty);
			point((int)(lastx+30), (int)(lasty+10));
			namp = bufl;
			for(j=0; j<8; j++)
				if(np->name[j] != '_')
					*namp++ = np->name[j];
			*namp++ = '\n';
			*namp++ = 0;
			label(bufl);
		}
		lastx += 500.;
		if(lastx > 2000.)
			lastx = 50.;
	}
	done();

print:
#endif
	actime = 0;
	printf("           name %%time  cumsecs  #call  ms/call\n");
	if (!lflg)
		qsort((char *)nl, nname, sizeof(struct nl), timcmp);
	for (np = nl; np<npe-1; np++) {
		ftim = np->time/totime;
		actime += np->time;
		printf("%15.15s%6.1f%9.2f", np->name, 100*ftim, actime/60);
		if(np->ncall!=0) {
			printf("%6ld", np->ncall);
			printf(" %7.2f\n", np->time/(np->ncall*.06));
		} else
			printf("\n");
	}
	done();
}

int
min(unsigned a, unsigned b)
{
	if (a<b)
		return(a);
	return(b);
}

int
max(unsigned a, unsigned b)
{
	if (a>b)
		return(a);
	return(b);
}

int
valcmp(char *a, char *b)
{
	struct nl *p1 = (struct nl *)a, *p2 = (struct nl *)b;
	return(p1->value - p2->value);
}

int
timcmp(char *a, char *b)
{
	struct nl *p1 = (struct nl *)a, *p2 = (struct nl *)b;
	float d;

	d = p2->time - p1->time;
	if (d > 0.0)
		return(1);
	if (d < 0.0)
		return(-1);
	return(0);
}

void
done(void)
{

#ifdef plot
	if(vflg) {
		point(0, -2040);
		closepl();
	}
#endif
	exit(0);
}
