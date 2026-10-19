#include <stdio.h>

struct hdr {
	char	*lowpc;
	char	*highpc;
	int	ncount;
};

struct cnt {
	unsigned cvalue;
	long	cncall;
};

static struct cnt *cntbase, *cntnext, *cntend;

void	mcount(unsigned pc);

void
monitor(char *lowpc, char *highpc, short *buf, int bufsiz, int cntsiz)
{
	register int o;
	static short *sbuf;
	static int ssiz;

	if (lowpc == 0) {
		profil(0, 0, 0, 0);
		o = creat("mon.out", 0666);
		write(o, (char *)sbuf, ssiz<<1);
		close(o);
		return;
	}
	ssiz = bufsiz;
	((struct hdr *)buf)->lowpc = lowpc;
	((struct hdr *)buf)->highpc = highpc;
	((struct hdr *)buf)->ncount = cntsiz;
	sbuf = buf;
	cntnext = cntbase = (struct cnt *)(buf +
	    sizeof(struct hdr)/sizeof(short));
	cntend = cntbase + cntsiz;
	buf = (short *)cntend;
	bufsiz -= (buf - sbuf);
	if (bufsiz<=0)
		return;
	o = (highpc - lowpc)>>1;
	if(bufsiz < o)
		o = ((long long)bufsiz<<16) / o;
	else
		o = 0x10000;
	profil(buf, bufsiz<<1, (int)lowpc, o);
}

/*
 * Count a call of the function whose
 * entry calls __gnu_mcount_nc from pc.
 */
void
mcount(unsigned pc)
{
	register struct cnt *p;

	for (p = cntbase; p < cntnext; p++)
		if (p->cvalue == pc) {
			p->cncall++;
			return;
		}
	if (cntnext < cntend) {
		cntnext->cvalue = pc;
		cntnext->cncall = 1;
		cntnext++;
	}
}
