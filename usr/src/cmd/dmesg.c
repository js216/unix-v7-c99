/*
 *	Suck up system messages
 */

#include <stdio.h>
#include <sys/param.h>
#include <a.out.h>

char	msgbuf[MSGBUFS];
char	*msgbufp;
int	sflg;
int	of	= -1;
#define KMSGBASE	0x7fff0000U

struct {
	char	*omsgflg;
	int	omindex;
	char	omsgbuf[MSGBUFS];
} omesg;
struct nlist nl[3] = {
	{"_msgbuf",  0, 0},
	{"_msgbufp", 0, 0}
};

int done(char *);
int pdate(void);
int readlive(int);
int
main(int argc, char **argv)
{
	int mem;
	register char *mp, *omp, *mstart;
	int samef;
	int live;

	if (argc>1 && argv[1][0] == '-') {
		sflg++;
		argc--;
		argv++;
	}
	if (sflg)
		of = open("/usr/adm/msgbuf", 2);
	read(of, (char *)&omesg, sizeof(omesg));
	lseek(of, 0L, 0);
	sflg = 0;
	nlist(argc>2? argv[2]:"/unix", nl);
	if (nl[0].n_type==0)
		done("No namelist\n");
	if ((mem = open((argc>1? argv[1]: "/dev/mem"), 0)) < 0)
		done("No mem\n");
	live = 0;
	lseek(mem, (long)nl[0].n_value, 0);
	if (read(mem, msgbuf, MSGBUFS) != MSGBUFS) {
		if (readlive(mem) < 0)
			done("Namelist mismatch\n");
		live = 1;
	}
	if (!live) {
		lseek(mem, (long)nl[1].n_value, 0);
		if (read(mem, (char *)&msgbufp, sizeof(msgbufp)) != sizeof(msgbufp)) {
			if (readlive(mem) < 0)
				done("Namelist mismatch\n");
			live = 1;
		}
	}
	if (!live &&
	    (msgbufp < (char *)nl[0].n_value || msgbufp >= (char *)nl[0].n_value+MSGBUFS)) {
		if (readlive(mem) < 0)
			done("Namelist mismatch\n");
		live = 1;
	}
	if (!live)
		msgbufp += msgbuf - (char *)nl[0].n_value;
	mstart = &msgbuf[omesg.omindex];
	omp = &omesg.omsgbuf[msgbufp-msgbuf];
	mp = msgbufp;
	samef = 1;
	do {
		if (*mp++ != *omp++) {
			mstart = msgbufp;
			samef = 0;
			pdate();
			printf("...\n");
			break;
		}
		if (mp == &msgbuf[MSGBUFS])
			mp = msgbuf;
		if (omp == &omesg.omsgbuf[MSGBUFS])
			omp = omesg.omsgbuf;
	} while (mp != mstart);
	if (samef && mstart == msgbufp)
		exit(0);
	mp = mstart;
	do {
		pdate();
		if (*mp)
			putchar(*mp);
		mp++;
		if (mp == &msgbuf[MSGBUFS])
			mp = msgbuf;
	} while (mp != msgbufp);
	done((char *)NULL);
}

int
readlive(int mem)
{
	unsigned int idx;
	lseek(mem, (long)KMSGBASE, 0);
	if (read(mem, (char *)&idx, sizeof(idx)) != sizeof(idx))
		return(-1);
	if (idx >= MSGBUFS)
		return(-1);
	if (read(mem, msgbuf, MSGBUFS) != MSGBUFS)
		return(-1);
	msgbufp = &msgbuf[idx];
	return(0);
}
int
done(char *s)
{
	register char *p, *q;

	if (s && s!=omesg.omsgflg && sflg==0) {
		pdate();
		printf(s);
	}
	omesg.omsgflg = s;
	q = omesg.omsgbuf;
	for (p = msgbuf; p < &msgbuf[MSGBUFS]; )
		*q++ = *p++;
	omesg.omindex = msgbufp - msgbuf;
	write(of, (char *)&omesg, sizeof(omesg));
	exit(s!=NULL);
	return(0);
}

int
pdate(void)
{
	extern char *ctime(long *t);
	static int firstime;
	time_t tbuf;

	if (firstime==0) {
		firstime++;
		time(&tbuf);
		printf("\n%.12s\n", ctime(&tbuf)+4);
	}
	return(0);
}
