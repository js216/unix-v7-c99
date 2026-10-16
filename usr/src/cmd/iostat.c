#include <stdio.h>
#include <a.out.h>
#include <sys/param.h>
int	bflg;
int	dflg;
int	tflg;
int	iflg;
int	aflg;
int	sflg;
struct
{
	char	name[8];
	int	type;
	unsigned	value;
} nl[] = {
	{"_dk_busy", 0, 0},
	{"_io_info", 0, 0},
	{"_dk_time", 0, 0},
	{"_dk_numb", 0, 0},
	{"_dk_wds",  0, 0},
	{"_tk_nin",  0, 0},
	{"_tk_nout", 0, 0},
	{"\0\0\0\0\0\0\0\0", 0, 0}
};
struct
{
	int	busy;
	long	etime[32];
	long	numb[3];
	long	wds[3];
	long	tin;
	long	tout;
} s, s1;

struct iostat {
	int	nbuf;
	long	nread;
	long	nreada;
	long	ncache;
	long	nwrite;
	long	bufcount[NBUF];
} io_info, io_delta;
double	etime;

int	mf;

void stats(int dn), stat1(int o), stats2(double t), stats3(double t), biostats(void);
int
main(int argc, char *argv[])
{
	register  int i;
	int iter;
	double f1, f2;
	long t;

	nlist("/unix", (struct nlist *)nl);
	if(nl[0].type == 0) {
		printf("dk_busy not found in /unix namelist\n");
		exit(1);
	}
	mf = open("/dev/kmem", 0);
	if(mf < 0) {
		printf("cannot open /dev/kmem\n");
		exit(1);
	}
	iter = 0;
	while (argc>1&&argv[1][0]=='-') {
		if (argv[1][1]=='d')
			dflg++;
		else if (argv[1][1]=='s')
			sflg++;
		else if (argv[1][1]=='a')
			aflg++;
		else if (argv[1][1]=='t')
			tflg++;
		else if (argv[1][1]=='i')
			iflg++;
		else if (argv[1][1]=='b')
			bflg++;
		argc--;
		argv++;
	}
	if(argc > 2)
		iter = atoi(argv[2]);
	if (!(sflg|iflg)) {
	if(tflg)
		printf("         TTY");
	if (bflg==0)
	printf("   RF                RK                RP                  PERCENT\n");
	if(tflg)
		printf("   tin  tout");
	if (bflg==0)
	printf("   tpm  msps  mspt   tpm  msps  mspt   tpm  msps  mspt  user  nice systm  idle\n");
	}

loop:
	lseek(mf, (long)nl[0].value, 0);
	read(mf, (char *)&s.busy, sizeof(s.busy));
	lseek(mf, (long)nl[2].value, 0);
	read(mf, (char *)s.etime, sizeof(s.etime));
	lseek(mf, (long)nl[3].value, 0);
	read(mf, (char *)s.numb, sizeof(s.numb));
	lseek(mf, (long)nl[4].value, 0);
	read(mf, (char *)s.wds, sizeof(s.wds));
	lseek(mf, (long)nl[5].value, 0);
	read(mf, (char *)&s.tin, sizeof(s.tin));
	lseek(mf, (long)nl[6].value, 0);
	read(mf, (char *)&s.tout, sizeof(s.tout));
	for(i=0; i<32; i++) {
		t = s.etime[i];
		s.etime[i] -= s1.etime[i];
		s1.etime[i] = t;
	}
	for(i=0; i<3; i++) {
		t = s.numb[i];
		s.numb[i] -= s1.numb[i];
		s1.numb[i] = t;
		t = s.wds[i];
		s.wds[i] -= s1.wds[i];
		s1.wds[i] = t;
	}
	t = s.tin;
	s.tin -= s1.tin;
	s1.tin = t;
	t = s.tout;
	s.tout -= s1.tout;
	s1.tout = t;
	etime = 0;
	for(i=0; i<32; i++)
		etime += s.etime[i];
	if(etime == 0.)
		etime = 1.;
	if (bflg) {
		biostats();
		goto contin;
	}
	if (dflg) {
		long long tm;
		time(&tm);
		printf("%s", ctime(&tm));
	}
	if (aflg)
		printf("%.2f minutes total\n", etime/3600);
	if (sflg) {
		stats2(etime);
		goto contin;
	}
	if (iflg) {
		stats3(etime);
		goto contin;
	}
	etime /= 60.;
	if(tflg) {
		f1 = s.tin;
		f2 = s.tout;
		printf("%6.1f", f1/etime);
		printf("%6.1f", f2/etime);
	}
	for(i=0; i<3; i++)
		stats(i);
	for(i=0; i<4; i++)
		stat1(i*8);
	printf("\n");
contin:
	--iter;
	if(iter)
	if(argc > 1) {
		sleep(atoi(argv[1]));
		goto loop;
	}
}

/* usec per word for the various disks */
double	xf[] = {
	16.0,	/* RF */
	11.1,	/* RK03/05 */
	2.48,	/* RP06 */
};

void
stats(int dn)
{
	register int i;
	double f1, f2, f3;
	double f4, f5, f6;
	double t;

	t = 0;
	for(i=0; i<32; i++)
		if(i & (1<<dn))
			t += s.etime[i];
	f1 = t;
	f1 = f1/60.;
	f2 = s.numb[dn];
	if(f2 == 0.) {
		printf("%6.0f%6.1f%6.1f", 0.0, 0.0, 0.0);
		return;
	}
	f3 = s.wds[dn];
	f3 = f3*32.;
	f4 = xf[dn];
	f4 = f4*1.0e-6;
	f5 = f1 - f4*f3;
	f6 = f1 - f5;
	printf("%6.0f", f2*60./etime);
	printf("%6.1f", f5*1000./f2);
	printf("%6.1f", f6*1000./f2);
}

void
stat1(int o)
{
	register int i;
	double t;
	double f1, f2;

	t = 0;
	for(i=0; i<32; i++)
		t += s.etime[i];
	f1 = t;
	if(f1 == 0.)
		f1 = 1.;
	t = 0;
	for(i=0; i<8; i++)
		t += s.etime[o+i];
	f2 = t;
	printf("%6.2f", f2*100./f1);
}

void
stats2(double t)
{
	register int i, j;

	for (i=0; i<4; i++) {
		for (j=0; j<8; j++)
			printf("%6.2f\n", s.etime[8*i+j]/(t/100));
		printf("\n");
	}
}

void
stats3(double t)
{
	register int i;
	double sum;

	t /= 100;
	printf("%6.2f idle\n", s.etime[24]/t);
	sum = 0;
	for (i=0; i<8; i++)
		sum += s.etime[i];
	printf("%6.2f user\n", sum/t);
	sum = 0;
	for (i=0; i<8; i++)
		sum += s.etime[8+i];
	printf("%6.2f nice\n", sum/t);
	sum = 0;
	for (i=0; i<8; i++)
		sum += s.etime[16+i];
	printf("%6.2f system\n", sum/t);
	sum = 0;
	for (i=1; i<8; i++)
		sum += s.etime[24+i];
	printf("%6.2f IO wait\n", sum/t);
	sum = 0;
	for (i=1; i<8; i++)
		sum += s.etime[i]+s.etime[i+8]+s.etime[i+16]+s.etime[i+24];
	printf("%6.2f IO active\n", sum/t);
	sum = 0;
	for (i=0; i<32; i++)
		if (i&01)
			sum += s.etime[i];
	printf("%6.2f RF active\n", sum/t);
	sum = 0;
	for (i=0; i<32; i++)
		if (i&02)
			sum += s.etime[i];
	printf("%6.2f RK active\n", sum/t);
	sum = 0;
	for (i=0; i<32; i++)
		if (i&04)
			sum += s.etime[i];
	printf("%6.2f RP active\n", sum/t);
}

void
biostats(void)
{
register int i;

	lseek(mf,(long)nl[1].value, 0);
	read(mf, (char *)&io_info, sizeof(io_info));
	printf("%D\t%D\t%D\t%D\n",
	 io_info.nread-io_delta.nread, io_info.nreada-io_delta.nreada,
	 io_info.ncache-io_delta.ncache, io_info.nwrite-io_delta.nwrite);

	for(i=0; i<NBUF; ) {
		printf("%D\t",(long)io_info.bufcount[i]-io_delta.bufcount[i]);
		i++;
		if (i % 10 == 0)
			printf("\n");
	}
	if (i % 10)
		printf("\n");
	io_delta = io_info;
}
