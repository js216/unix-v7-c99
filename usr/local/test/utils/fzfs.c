/*
 * fzfs seed ops: random file system calls on a few names in d0 and d1,
 * each checked against a model of what the files must hold.  Offsets
 * and lengths cluster at block boundaries and at the ends of the
 * direct and indirect blocks, where the kernel changes its course.
 * Prints the seed and the operation on the first difference, and
 * exits 1; prints "fzfs ok" otherwise.
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

#define	NNAME	6
#define	NFILE	NNAME
#define	MAXSZ	200000L
#define	BLK	512L
#define	DIRECT	(10*BLK)
#define	INDIR	(DIRECT+128*BLK)

char	*name[NNAME] = { "d0/a", "d0/b", "d0/c", "d1/a", "d1/b", "d1/c" };
int	fileof[NNAME];		/* file named, or -1 */
struct	file {
	char	*data;
	long	size;
	int	nlink;
	int	ino;
} file[NFILE];
unsigned long	rs;
long	seed;
int	op;
char	buf[8200];

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(rs % n);
}

static void
fail(char *what, char *nm)
{
	printf("FAIL fzfs seed %ld op %d: %s %s\n", seed, op, what, nm);
	exit(1);
}

static long
pickoff(long size)
{
	static long edge[] = { 0, BLK, 2*BLK, DIRECT, INDIR, 4096, 8192 };
	long o;

	switch(rnd(4)) {
	case 0:
		o = size;
		break;
	case 1:
		o = edge[rnd(sizeof(edge)/sizeof(edge[0]))];
		break;
	case 2:
		o = rnd((unsigned)(size+1));
		break;
	default:
		o = rnd((unsigned)MAXSZ);
	}
	o += (long)rnd(3) - 1;
	if(o < 0)
		o = 0;
	return(o);
}

static int
picklen(void)
{
	static int len[] = { 1, 2, 511, 512, 513, 1024, 4095, 4096, 4097, 8192 };

	if(rnd(3) == 0)
		return(rnd(sizeof(buf)) + 1);
	return(len[rnd(sizeof(len)/sizeof(len[0]))]);
}

static int
newfile(void)
{
	int f;

	for(f = 0; f < NFILE; f++)
		if(file[f].nlink == 0) {
			file[f].size = 0;
			return(f);
		}
	return(-1);
}

static int
same(char *a, char *b, long n)
{
	while(n-- > 0)
		if(*a++ != *b++)
			return(0);
	return(1);
}

static void
doverify(int n)
{
	struct file *fp;
	long o;
	int fd, got;

	fp = &file[fileof[n]];
	if((fd = open(name[n], 0)) < 0)
		fail("open for verify", name[n]);
	for(o = 0; (got = read(fd, buf, sizeof(buf))) > 0; o += got)
		if(o+got > fp->size || !same(buf, fp->data+o, got))
			fail("verify data", name[n]);
	if(got < 0 || o != fp->size)
		fail("verify length", name[n]);
	close(fd);
}

static void
doread(int n)
{
	struct file *fp;
	long o;
	int fd, len, got;

	fp = &file[fileof[n]];
	if((fd = open(name[n], 0)) < 0)
		fail("open for read", name[n]);
	o = pickoff(fp->size);
	len = picklen();
	lseek(fd, o, 0);
	got = read(fd, buf, len);
	if(o >= fp->size) {
		if(got != 0)
			fail("read past end", name[n]);
	} else {
		if(got != (fp->size-o < len ? fp->size-o : len))
			fail("read count", name[n]);
		if(!same(buf, fp->data+o, got))
			fail("read data", name[n]);
	}
	close(fd);
}

static void
dowrite(int n)
{
	struct file *fp;
	long o;
	int fd, len, i;

	fp = &file[fileof[n]];
	o = pickoff(fp->size);
	len = picklen();
	if(o + len > MAXSZ)
		return;
	for(i = 0; i < len; i++)
		buf[i] = rnd(256);
	if((fd = open(name[n], 1)) < 0)
		fail("open for write", name[n]);
	lseek(fd, o, 0);
	if(write(fd, buf, len) != len)
		fail("write count", name[n]);
	close(fd);
	while(fp->size < o)
		fp->data[fp->size++] = 0;
	for(i = 0; i < len; i++)
		fp->data[o+i] = buf[i];
	if(o + len > fp->size)
		fp->size = o + len;
}

static void
docreat(int n)
{
	struct stat st;
	int fd, f;

	if((fd = creat(name[n], 0644)) < 0)
		fail("creat", name[n]);
	close(fd);
	if((f = fileof[n]) < 0) {
		if((f = newfile()) < 0)
			fail("model full", name[n]);
		file[f].nlink = 1;
		fileof[n] = f;
		if(stat(name[n], &st) < 0)
			fail("stat after creat", name[n]);
		file[f].ino = st.st_ino;
	}
	file[f].size = 0;
}

static void
dounlink(int n)
{
	if(unlink(name[n]) < 0)
		fail("unlink", name[n]);
	file[fileof[n]].nlink--;
	fileof[n] = -1;
}

static void
dolink(int n, int m)
{
	int r;

	r = link(name[n], name[m]);
	if(fileof[m] >= 0) {
		if(r >= 0)
			fail("link onto existing name", name[m]);
		return;
	}
	if(r < 0)
		fail("link", name[m]);
	fileof[m] = fileof[n];
	file[fileof[n]].nlink++;
}

static void
dostat(int n)
{
	struct stat st;
	struct file *fp;

	if(stat(name[n], &st) < 0) {
		if(fileof[n] >= 0)
			fail("stat", name[n]);
		return;
	}
	if(fileof[n] < 0)
		fail("stat of removed name", name[n]);
	fp = &file[fileof[n]];
	if(st.st_size != fp->size)
		fail("size", name[n]);
	if(st.st_nlink != fp->nlink)
		fail("link count", name[n]);
	if(st.st_ino != fp->ino)
		fail("inode number", name[n]);
}

int
main(int argc, char **argv)
{
	int n, m, nops;

	if(argc != 3) {
		printf("usage: fzfs seed ops\n");
		exit(2);
	}
	seed = atol(argv[1]);
	nops = atoi(argv[2]);
	rs = seed*2654435761UL + 1;
	for(n = 0; n < NNAME; n++) {
		fileof[n] = -1;
		unlink(name[n]);
	}
	for(n = 0; n < NFILE; n++)
		if((file[n].data = malloc((unsigned)MAXSZ)) == NULL)
			fail("malloc", "");
	for(op = 0; op < nops; op++) {
		n = rnd(NNAME);
		if(fileof[n] < 0) {
			docreat(n);
			continue;
		}
		switch(rnd(12)) {
		case 0: case 1: case 2: case 3:
			dowrite(n);
			break;
		case 4: case 5: case 6:
			doread(n);
			break;
		case 7:
			docreat(n);
			break;
		case 8:
			dounlink(n);
			break;
		case 9:
			m = rnd(NNAME);
			if(m != n)
				dolink(n, m);
			break;
		case 10:
			doverify(n);
			break;
		default:
			dostat(n);
			dostat(rnd(NNAME));
		}
	}
	for(n = 0; n < NNAME; n++)
		if(fileof[n] >= 0) {
			dostat(n);
			doverify(n);
			dounlink(n);
		}
	printf("fzfs ok\n");
	exit(0);
}
