#define MAXINO	3000
#define BITS	8
#define MAXXTR	60
#define NCACHE	3

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

int	mt;
char	tapename[] = "/dev/rmt1";
char	*magtape = tapename;

daddr_t	seekpt;
int	ofile;
FILE	*df;
char	dirfile[] = "rstXXXXXX";

struct {
	ino_t	t_ino;
	daddr_t	t_seekpt;
} inotab[MAXINO];
int	ipos;

#define ONTAPE	1
#define XTRACTD	2
#define XINUSE	4

short	dumpmap[MSIZ];
short	clrimap[MSIZ];


int bct = NTREC+1;
char tbf[NTREC*BSIZE];

char prebuf[512];

int volno;

struct spcl;
int	readhdr(struct spcl *b);
int	checkvol(struct spcl *b, int t);
int	pass1(void);
int	printem(char *prefix, ino_t inum);
int	gethead(struct spcl *buf);
int	checktype(struct spcl *b, int t);
int	readbits(short *m);
int	flsh(void);
int	getfile(ino_t n, int (*f1)(), int (*f2)(), long size);
int	putent(char *cp);
int	mseek(daddr_t pt);
int	getent(char *bf);
int	direq(char *s1, char *s2);
int	search(ino_t inum);
int	readtape(char *b);
int	clearbuf(char *cp);
int	flsht(void);
int	copy(char *f, char *t, int s);
int	writec(int c);
int	readc(void);
int	checksum(int *b);
int	putdir(char *b);
int	null(void);

int
main(int argc, char *argv[])
{
	extern char *ctime(long *t);

	mktemp(dirfile);
	argv++;
	if (argc>=3 && *argv[0] == 'f')
		magtape = *++argv;
	df = fopen(dirfile, "w");
	if (df == NULL) {
		printf("dumpdir: %s - cannot create directory temporary\n", dirfile);
		exit(1);
	}

	if ((mt = open(magtape, 0)) < 0) {
		printf("%s: cannot open tape\n", magtape);
		exit(1);
	}
	if (readhdr(&spcl) == 0) {
		printf("Tape is not a dump tape\n");
		exit(1);
	}
	printf("Dump   date: %s", ctime(&spcl.c_date));
	printf("Dumped from: %s", ctime(&spcl.c_ddate));
	if (checkvol(&spcl, 1) == 0) {
		printf("Tape is not volume 1 of the dump\n");
		exit(1);
	}
	pass1();  /* This sets the various maps on the way by */
	freopen(dirfile, "r", df);
	strcpy(prebuf, "/");
	printem(prebuf, (ino_t) 2);
	exit(0);
}
int	i = 0;
/*
 * Read the tape, bulding up a directory structure for extraction
 * by name
 */
int
pass1(void)
{
	register int i;
	struct dinode *ip;
	int	putdir(char *b), null(void);

	while (gethead(&spcl) == 0) {
		printf("Can't find directory header!\n");
	}
	for (;;) {
		if (checktype(&spcl, TS_BITS) == 1) {
			readbits(dumpmap);
			continue;
		}
		if (checktype(&spcl, TS_CLRI) == 1) {
			readbits(clrimap);
			continue;
		}
		if (checktype(&spcl, TS_INODE) == 0) {
finish:
			flsh();
			close(mt);
			return(0);
		}
		ip = &spcl.c_dinode;
		i = ip->di_mode & IFMT;
		if (i != IFDIR) {
			goto finish;
		}
		inotab[ipos].t_ino = spcl.c_inumber;
		inotab[ipos++].t_seekpt = seekpt;
		getfile(spcl.c_inumber, putdir, null, spcl.c_dinode.di_size);
		putent("\000\000/");
	}
}

int
printem(char *prefix, ino_t inum)
{
	struct direct dir;
	register int i;

	for (i = 0; i < MAXINO; i++)
		if (inotab[i].t_ino == inum) {
			goto found;
		}
	printf("PANIC - can't find directory %d\n", inum);
	return(0);
found:
	mseek(inotab[i].t_seekpt);
	for (;;) {
		getent((char *) &dir);
		if (direq(dir.d_name, "/"))
			return(0);
		if (search(dir.d_ino) != 0 && direq(dir.d_name, ".") == 0 && direq(dir.d_name, "..") == 0) {
			int len;
			FILE *tdf;

			tdf = df;
			df = fopen(dirfile, "r");
			len = strlen(prefix);
			strncat(prefix, dir.d_name, sizeof(dir.d_name));
			strcat(prefix, "/");
			printem(prefix, dir.d_ino);
			prefix[len] = '\0';
			fclose(df);
			df = tdf;
		}
		else
			if (BIT(dir.d_ino, dumpmap))
				printf("%5d	%s%-.14s\n", dir.d_ino, prefix, dir.d_name);
	}
}
/*
 * Do the file extraction, calling the supplied functions
 * with the blocks
 */
int
getfile(ino_t n, int (*f1)(), int (*f2)(), long size)
{
	register int i;
	struct spcl addrblock;
	char buf[BSIZE];

	(void)n;
	addrblock = spcl;
	goto start;
	for (;;) {
		if (gethead(&addrblock) == 0) {
			printf("Missing address (header) block\n");
			goto eloop;
		}
		if (checktype(&addrblock, TS_ADDR) == 0) {
			spcl = addrblock;
			return(0);
		}
start:
		for (i = 0; i < addrblock.c_count; i++) {
			if (addrblock.c_addr[i]) {
				readtape(buf);
				(*f1)(buf, size > BSIZE ? (long) BSIZE : size);
			}
			else {
				clearbuf(buf);
				(*f2)(buf, size > BSIZE ? (long) BSIZE : size);
			}
			if ((size -= BSIZE) <= 0) {
eloop:
				while (gethead(&spcl) == 0)
					;
				if (checktype(&spcl, TS_ADDR) == 1)
					goto eloop;
				return(0);
			}
		}
	}
}

/*
 * Do the tape i\/o, dealling with volume changes
 * etc..
 */
int
readtape(char *b)
{
	register int i;
	struct spcl tmpbuf;

	if (bct >= NTREC) {
		for (i = 0; i < NTREC; i++)
			((struct spcl *)&tbf[i*BSIZE])->c_magic = 0;
		bct = 0;
		if ((i = read(mt, tbf, NTREC*BSIZE)) < 0) {
			exit(1);
		}
		if (i == 0) {
			bct = NTREC + 1;
			volno++;
loop:
			flsht();
			close(mt);
			printf("Mount volume %d\n", volno);
			while (getchar() != '\n')
				;
			if ((mt = open(magtape, 0)) == -1) {
				printf("Cannot open tape!\n");
			}
			if (readhdr(&tmpbuf) == 0) {
				printf("Not a dump tape.Try again\n");
				goto loop;
			}
			if (checkvol(&tmpbuf, volno) == 0) {
				printf("Wrong tape. Try again\n");
				goto loop;
			}
			readtape(b);
			return(0);
		}
	}
	copy(&tbf[(bct++*BSIZE)], b, BSIZE);
	return(0);
}

int
flsht(void)
{
	bct = NTREC+1;
	return(0);
}

int
copy(register char *f, register char *t, int s)
{
	register int i;

	i = s;
	do
		*t++ = *f++;
	while (--i);
	return(0);
}

int
clearbuf(register char *cp)
{
	register int i;

	i = BSIZE;
	do
		*cp++ = 0;
	while (--i);
	return(0);
}

/*
 * Put and get the directory entries from the compressed
 * directory file
 */
int
putent(char *cp)
{
	register int i;

	for (i = 0; i < (int)sizeof(ino_t); i++)
		writec(*cp++);
	for (i = 0; i < DIRSIZ; i++) {
		writec(*cp);
		if (*cp++ == 0)
			return(0);
	}
	return(0);
}

int
getent(register char *bf)
{
	register int i;

	for (i = 0; i < (int)sizeof(ino_t); i++)
		*bf++ = readc();
	for (i = 0; i < DIRSIZ; i++)
		if ((*bf++ = readc()) == 0)
			return(0);
	return(0);
}

/*
 * read/write te directory file
 */
int
writec(int c)
{
	char cc = c;
	seekpt++;
	fwrite(&cc, 1, 1, df);
	return(0);
}

int
readc(void)
{
	char c;

	fread(&c, 1, 1, df);
	return(c);
}

int
mseek(daddr_t pt)
{
	fseek(df, pt, 0);
	return(0);
}

int
flsh(void)
{
	fflush(df);
	return(0);
}

/*
 * search the directory inode ino
 * looking for entry cp
 */
int
search(ino_t inum)
{
	register int low, high, probe;

	low = 0;
	high = ipos-1;

	while (low != high) {
		probe = (high - low + 1)/2 + low;
/*
printf("low = %d, high = %d, probe = %d, ino = %d, inum = %d\n", low, high, probe, inum, inotab[probe].t_ino);
*/
		if (inum >= inotab[probe].t_ino)
			low = probe;
		else
			high = probe - 1;
	}
	return(inum == inotab[low].t_ino);
}

int
direq(register char *s1, register char *s2)
{
	register int i;

	for (i = 0; i < DIRSIZ; i++)
		if (*s1++ == *s2) {
			if (*s2++ == 0)
				return(1);
		} else
			return(0);
	return(1);
}

/*
 * read the tape into buf, then return whether or
 * or not it is a header block.
 */
int
gethead(struct spcl *buf)
{
	readtape((char *)buf);
	if (buf->c_magic != MAGIC || checksum((int *) buf) == 0)
		return(0);
	return(1);
}

/*
 * return whether or not the buffer contains a header block
 */
int
checktype(struct spcl *b, int t)
{
	return(b->c_type == t);
}


int
checksum(int *b)
{
	register int i, j;

	j = BSIZE/sizeof(int);
	i = 0;
	do
		i += *b++;
	while (--j);
	if (i != CHECKSUM) {
		printf("Checksum error %o\n", i);
		return(0);
	}
	return(1);
}

int
checkvol(struct spcl *b, int t)
{
	if (b->c_volume == t)
		return(1);
	return(0);
}

int
readhdr(struct spcl *b)
{
	if (gethead(b) == 0)
		return(0);
	if (checktype(b, TS_TAPE) == 0)
		return(0);
	return(1);
}

int
putdir(char *b)
{
	register struct direct *dp;
	register int i;

	for (dp = (struct direct *) b, i = 0; i < BSIZE; dp++, i += sizeof(*dp)) {
		if (dp->d_ino == 0)
			continue;
		putent((char *) dp);
	}
	return(0);
}

/*
 * read a bit mask from the tape into m.
 */
int
readbits(short *m)
{
	register int i;

	i = spcl.c_count;

	while (i--) {
		readtape((char *) m);
		m += (BSIZE/(MLEN/BITS));
	}
	while (gethead(&spcl) == 0)
		;
	return(0);
}

int null(void) { return(0); }
