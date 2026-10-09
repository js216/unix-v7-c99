#define	NI	16
#define	DIRPB	(BSIZE/sizeof(struct direct))

#include <stdio.h>
#include <sys/param.h>
#include <sys/inode.h>
#include <sys/ino.h>
#include <sys/fblk.h>
#include <sys/filsys.h>
#include <sys/dir.h>
#include <dumprestor.h>

#define	MWORD(m,i) (m[(unsigned)(i-1)/MLEN])
#define	MBIT(i)	(1<<((unsigned)(i-1)%MLEN))
#define	BIS(i,w)	(MWORD(w,i) |=  MBIT(i))
#define	BIC(i,w)	(MWORD(w,i) &= ~MBIT(i))
#define	BIT(i,w)	(MWORD(w,i) & MBIT(i))

struct	filsys	sblock;
struct	dinode	itab[INOPB*NI];
short	clrmap[MSIZ];
short	dirmap[MSIZ];
short	nodmap[MSIZ];

char	*disk;
char	*tape;
char	*increm;
char	incno;
int	uflag;
int	fi;
int	to;
ino_t	ino;
int	nsubdir;
int	ntape;
int	nadded;
int	dadded;
int	density = 160;

char	*prdate(time_t d);
int	fi;
long	tsize;
long	esize;
long	asize;
void	mark(struct dinode *ip);
void	add(struct dinode *ip);
void	dump(struct dinode *ip);
void	tapsrec(daddr_t d);
void	dmpspc(daddr_t *dp, int n);
void	dsrch(daddr_t d);
void	nullf(daddr_t *dp, int n);
void	pass(void (*fn)(struct dinode *ip), short *map);
void	indir(daddr_t d, void (*fn1)(daddr_t d),
	void (*fn2)(daddr_t *dp, int n), int n);
void	bitmap(short *map, int typ), spclrec(void);
void	bread(daddr_t da, char *ba, int c), CLR(short *map), taprec(char *dp);
void	flusht(void), otape(void), getitime(void), putitime(void);
void	est(struct dinode *ip), bmapest(short *map);

#define	HOUR	(60L*60L)
#define	DAY	(24L*HOUR)
#define	YEAR	(365L*DAY)

int
main(int argc, char *argv[])
{
	char *arg;
	register int i;

	time(&spcl.c_date);

	tsize = 2300L*12L*10L;
	tape = "/dev/rmt1";
	disk = "/dev/rrp3";
	increm = "/etc/ddate";
	incno = '9';
	uflag = 0;
	arg = "u";
	if(argc > 1) {
		argv++;
		argc--;
		arg = *argv;
	}
	while(*arg)
	switch (*arg++) {

	case 'f':
		if(argc > 1) {
			argv++;
			argc--;
			tape = *argv;
		}
		break;

	case 'd':
		if (argc > 1) {
			argv++;
			argc--;
			density = atoi(*argv)/10;
		}
		break;

	case 's':
		if(argc > 1) {
			argv++;
			argc--;
			tsize = atol(*argv);
			tsize *= 12L*10L;
		}
		break;

	case '0':
	case '1':
	case '2':
	case '3':
	case '4':
	case '5':
	case '6':
	case '7':
	case '8':
	case '9':
		incno = arg[-1];
		break;

	case 'u':
		uflag++;
		break;

	default:
		printf("bad key '%c%'\n", arg[-1]);
		exit(1);
	}
	if(argc > 1) {
		argv++;
		argc--;
		disk = *argv;
	}

	getitime();
	printf("     date = %s\n", prdate(spcl.c_date));
	printf("dump date = %s\n", prdate(spcl.c_ddate));
	printf("dumping %s to %s\n", disk, tape);
	fi = open(disk, 0);
	if(fi < 0) {
		printf("dump: cannot open %s\n", disk);
		exit(1);
	}
	otape();
	printf("I\n");
	esize = 0;
	CLR(clrmap);
	CLR(dirmap);
	CLR(nodmap);

	pass(mark, (short *)NULL);
	do {
		printf("II\n");
		nadded = 0;
		pass(add, dirmap);
	} while(nadded);

	bmapest(clrmap);
	bmapest(nodmap);
	printf("estimated %ld tape blocks on %d tape(s)\n",
		esize, 0);

	printf("III\n");
	bitmap(clrmap, TS_CLRI);
	pass(dump, dirmap);
	printf("IV\n");
	pass(dump, nodmap);
	putitime();
	printf("DONE\n");
	spcl.c_type = TS_END;
	for(i=0; i<NTREC; i++)
		spclrec();
	printf("%ld tape blocks on %d tape(s)\n",
		spcl.c_tapea, spcl.c_volume);
}

void
pass(void (*fn)(struct dinode *ip), short *map)
{
	register int i, j;
	int bits = 0;
	ino_t mino;
	daddr_t d;

	sync();
	bread((daddr_t)1, (char *)&sblock, sizeof(sblock));
	mino = (sblock.s_isize-2) * INOPB;
	ino = 0;
	for(i=2;; i+=NI) {
		if(ino >= mino)
			break;
		d = (unsigned)i;
		for(j=0; j<INOPB*NI; j++) {
			if(ino >= mino)
				break;
			if((ino % MLEN) == 0) {
				bits = ~0;
				if(map != NULL)
					bits = *map++;
			}
			ino++;
			if(bits & 1) {
				if(d != 0) {
					bread(d, (char *)itab, sizeof(itab));
					d = 0;
				}
				(*fn)(&itab[j]);
			}
			bits >>= 1;
		}
	}
}

static void
icat(struct dinode *ip, void (*fn1)(daddr_t d),
	void (*fn2)(daddr_t *dp, int n))
{
	register int i;
	daddr_t d[NADDR];

	l3tol(&d[0], &ip->di_addr[0], NADDR);
	(*fn2)(d, NADDR-3);
	for(i=0; i<NADDR; i++) {
		if(d[i] != 0) {
			if(i < NADDR-3)
				(*fn1)(d[i]); else
				indir(d[i], fn1, fn2, i-(NADDR-3));
		}
	}
}

void
indir(daddr_t d, void (*fn1)(daddr_t d),
	void (*fn2)(daddr_t *dp, int n), int n)
{
	register unsigned i;
	daddr_t	idblk[NINDIR];

	bread(d, (char *)idblk, sizeof(idblk));
	if(n <= 0) {
		spcl.c_type = TS_ADDR;
		(*fn2)(idblk, NINDIR);
		for(i=0; i<NINDIR; i++) {
			d = idblk[i];
			if(d != 0)
				(*fn1)(d);
		}
	} else {
		n--;
		for(i=0; i<NINDIR; i++) {
			d = idblk[i];
			if(d != 0)
				indir(d, fn1, fn2, n);
		}
	}
}

void
mark(struct dinode *ip)
{
	register int f;

	f = ip->di_mode & IFMT;
	if(f == 0)
		return;
	BIS(ino, clrmap);
	if(f == IFDIR)
		BIS(ino, dirmap);
	if(ip->di_mtime >= spcl.c_ddate ||
	   ip->di_ctime >= spcl.c_ddate) {
		BIS(ino, nodmap);
		if (f != IFREG)
			return;
		est(ip);
	}
}

void
add(struct dinode *ip)
{

	if(BIT(ino, nodmap))
		return;
	nsubdir = 0;
	dadded = 0;
	icat(ip, dsrch, nullf);
	if(dadded) {
		BIS(ino, nodmap);
		est(ip);
		nadded++;
	}
	if(nsubdir == 0)
		if(!BIT(ino, nodmap))
			BIC(ino, dirmap);
}

void
dump(struct dinode *ip)
{
	register int i;

	if(ntape) {
		ntape = 0;
		bitmap(nodmap, TS_BITS);
	}
	BIC(ino, nodmap);
	spcl.c_dinode = *ip;
	spcl.c_type = TS_INODE;
	spcl.c_count = 0;
	i = ip->di_mode & IFMT;
	if(i != IFDIR && i != IFREG) {
		spclrec();
		return;
	}
	icat(ip, tapsrec, dmpspc);
}

void
dmpspc(daddr_t *dp, int n)
{
	register int i, t;

	spcl.c_count = n;
	for(i=0; i<n; i++) {
		t = 0;
		if(dp[i] != 0)
			t++;
		spcl.c_addr[i] = t;
	}
	spclrec();
}

void
bitmap(short *map, int typ)
{
	register int i, n;
	char *cp;

	n = -1;
	for(i=0; i<MSIZ; i++)
		if(map[i])
			n = i;
	if(n < 0)
		return;
	spcl.c_type = typ;
	spcl.c_count = (n*sizeof(map[0]) + BSIZE)/BSIZE;
	spclrec();
	cp = (char *)map;
	for(i=0; i<spcl.c_count; i++) {
		taprec(cp);
		cp += BSIZE;
	}
}

void
spclrec(void)
{
	register unsigned i, *ip, s;

	spcl.c_inumber = ino;
	spcl.c_magic = MAGIC;
	spcl.c_checksum = 0;
	ip = (unsigned *)&spcl;
	s = 0;
	for(i=0; i<BSIZE/sizeof(*ip); i++)
		s += *ip++;
	spcl.c_checksum = CHECKSUM - s;
	taprec((char *)&spcl);
}

void
dsrch(daddr_t d)
{
	register char *cp;
	register unsigned i;
	register ino_t in;
	struct direct dblk[DIRPB];

	if(dadded)
		return;
	bread(d, (char *)dblk, sizeof(dblk));
	for(i=0; i<DIRPB; i++) {
		in = dblk[i].d_ino;
		if(in == 0)
			continue;
		cp = dblk[i].d_name;
		if(cp[0] == '.') {
			if(cp[1] == '\0')
				continue;
			if(cp[1] == '.' && cp[2] == '\0')
				continue;
		}
		if(BIT(in, nodmap)) {
			dadded++;
			return;
		}
		if(BIT(in, dirmap))
			nsubdir++;
	}
}

void
nullf(daddr_t *dp, int n)
{
	(void)dp;
	(void)n;
}

void
bread(daddr_t da, char *ba, int c)
{
	register int n;

	lseek(fi, da*512, 0);
	n = read(fi, ba, c);
	if(n != c)
		printf("asked %d; got %d\n", c, n);
}

void
CLR(register short *map)
{
	register int n;

	n = MSIZ;
	do
		*map++ = 0;
	while(--n);
}


char	tblock[NTREC][BSIZE];
daddr_t	tdaddr[NTREC];
int	trecno;

void
taprec(char *dp)
{
	register int i;

	for(i=0; i<BSIZE; i++)
		tblock[trecno][i] = *dp++;
	tdaddr[trecno] = 0;
	trecno++;
	spcl.c_tapea++;
	if(trecno >= NTREC)
		flusht();
}

void
tapsrec(daddr_t d)
{

	if(d == 0)
		return;
	tdaddr[trecno] = d;
	trecno++;
	spcl.c_tapea++;
	if(trecno >= NTREC)
		flusht();
}

void
flusht(void)
{
	char place[100];
	register int i, si;
	daddr_t d;

	while(trecno < NTREC)
		tdaddr[trecno++] = 1;

loop:
	d = 0;
	for(i=0; i<NTREC; i++)
		if(tdaddr[i] != 0)
		if(d == 0 || tdaddr[i] < d) {
			si = i;
			d = tdaddr[i];
		}
	if(d != 0) {
		bread(d, tblock[si], BSIZE);
		tdaddr[si] = 0;
		goto loop;
	}
	trecno = 0;
	write(to, tblock[0], sizeof(tblock));
	asize += sizeof(tblock)/density;
	asize += 7;
	if(asize > tsize) {
		close(to);
		printf("change tapes\n");
		read(0, place, sizeof(place));
		otape();
	}
}

void
otape(void)
{
	to = creat(tape, 0666);
	if(to < 0) {
		printf("dump: cannot create %s\n", tape);
		exit(1);
	}
	asize = 0;
	ntape++;
	spcl.c_volume++;
	spcl.c_type = TS_TAPE;
	spclrec();
}

char *
prdate(time_t d)
{
	char *p;

	if(d == 0)
		return("the epoch");
	p = ctime(&d);
	p[24] = 0;
	return(p);
}

void
getitime(void)
{
	register int i, df;
	struct idates idbuf;
	char *fname;

	fname = disk;
l1:
	for(i=0; fname[i]; i++)
		if(fname[i] == '/') {
			fname += i+1;
			goto l1;
		}

	spcl.c_ddate = 0;
	df = open(increm, 0);
	if(df < 0) {
		printf("cannot open %s\n", increm);
		exit(1);
	}

l2:
	i = read(df, (char *)&idbuf, sizeof(idbuf));
	if(i != sizeof(idbuf)) {
		close(df);
		return;
	}
	for(i=0;; i++) {
		if(fname[i] != idbuf.id_name[i])
			goto l2;
		if(fname[i] == '\0')
			break;
	}
	if(idbuf.id_incno >= incno)
		goto l2;
	if(idbuf.id_ddate <= spcl.c_ddate)
		goto l2;
	spcl.c_ddate = idbuf.id_ddate;
	goto l2;
}

void
putitime(void)
{
	register int i, n, df;
	struct idates idbuf;
	char *fname;

	if(uflag == 0)
		return;
	fname = disk;
l1:
	for(i=0; fname[i]; i++)
		if(fname[i] == '/') {
			fname += i+1;
			goto l1;
		}

	spcl.c_ddate = 0;
	df = open(increm, 2);
	if(df < 0) {
		printf("cannot open %s\n", increm);
		exit(1);
	}
	n = 0;
l2:
	i = read(df, (char *)&idbuf, sizeof(idbuf));
	if(i != sizeof(idbuf))
		goto l3;
	n++;
	for(i=0;; i++) {
		if(fname[i] != idbuf.id_name[i])
			goto l2;
		if(fname[i] == '\0')
			break;
	}
	if(idbuf.id_incno != incno)
		goto l2;
l3:
	lseek(df, (long)n*sizeof(idbuf), 0);
	for(i=0;; i++) {
		idbuf.id_name[i] = fname[i];
		if(fname[i] == '\0')
			break;
	}
	idbuf.id_incno = incno;
	idbuf.id_ddate = spcl.c_date;
	write(df, (char *)&idbuf, sizeof(idbuf));
	close(df);
	printf("level %c dump on %s\n", incno, prdate(spcl.c_date));
}

void
est(struct dinode *ip)
{
	long s;

	esize++;
	s = (ip->di_size + BSIZE-1) / BSIZE;
	esize += s;
	if(s > NADDR-3) {
		s -= NADDR-3;
		s = (s + (BSIZE/sizeof(daddr_t))-1) / (BSIZE/sizeof(daddr_t));
		esize += s;
	}
}

void
bmapest(short *map)
{
	register int i, n;

	n = -1;
	for(i=0; i<MSIZ; i++)
		if(map[i])
			n = i;
	if(n < 0)
		return;
	esize++;
	esize += (n + (BSIZE/sizeof(short))-1) / (BSIZE/sizeof(short));
}
