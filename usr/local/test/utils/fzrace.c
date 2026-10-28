/*
 * fzrace seed nproc rounds: processes racing on shared names.  In each
 * round nproc processes each make NOP random calls on a few names in
 * the current directory: creat, open, link, unlink, write, read, and
 * stat, and now and then sync, whose disk writes make the caller sleep,
 * so that the others run in the middle of their calls.  Every write
 * is one record of 512 bytes at an offset which is a multiple of 512,
 * telling its own offset and a checksum, so every record read must be
 * whole: all zeros, a hole, or a record written there, never a torn
 * one.  What the calls leave behind is checked
 * afterwards by icheck, dcheck, and fzkern.  Prints the seed, process,
 * and call of the first bad record and exits 1; prints "fzrace ok"
 * otherwise.
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

#define	NNAME	6
#define	NREC	24		/* records a file may hold */
#define	NFD	4
#define	NOP	3000
#define	MAGIC	0x52414345

struct	rec {
	unsigned	magic;
	unsigned	off;
	unsigned	pid;
	unsigned	seq;
	unsigned	word[123];
	unsigned	sum;
};

unsigned long	rs;
long	seed;
int	me, op;
char	name[NNAME][4] = { "r0", "r1", "r2", "r3", "r4", "r5" };

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(rs % n);
}

static unsigned
sum(struct rec *r)
{
	register unsigned *p, s;

	s = 0;
	for(p = (unsigned *)r; p < &r->sum; p++)
		s = s*31 + *p;
	return(s);
}

static void
fail(char *what, int fd, unsigned off)
{
	printf("FAIL fzrace seed %ld proc %d call %d: %s, fd %d offset %u\n",
	    seed, me, op, what, fd, off);
	exit(1);
}

/*
 * A record read at off must be all zeros or whole
 */
static void
check(struct rec *r, int fd, unsigned off)
{
	register unsigned *p;

	if(r->magic == 0) {
		for(p = (unsigned *)r; p <= &r->sum; p++)
			if(*p)
				fail("record torn after a zero magic", fd, off);
		return;
	}
	if(r->magic != MAGIC)
		fail("bad magic", fd, off);
	if(r->off != off)
		fail("record at the wrong offset", fd, off);
	if(r->sum != sum(r))
		fail("bad checksum", fd, off);
}

static void
racer(void)
{
	struct rec r;
	struct stat sb;
	int fd[NFD], i, k, m;
	unsigned off, seq;

	rs = seed*2654435761UL + me*7919UL + 1;
	for(i = 0; i < NFD; i++)
		fd[i] = -1;
	seq = 0;
	for(op = 0; op < NOP; op++) {
		k = rnd(NFD);
		if(rnd(50) == 0)
			sync();
		switch(rnd(10)) {
		case 0:
			if(fd[k] >= 0)
				close(fd[k]);
			fd[k] = creat(name[rnd(NNAME)], 0666);
			break;
		case 1:
		case 2:
			if(fd[k] >= 0)
				close(fd[k]);
			fd[k] = open(name[rnd(NNAME)], 2);
			break;
		case 3:
			link(name[rnd(NNAME)], name[rnd(NNAME)]);
			break;
		case 4:
			unlink(name[rnd(NNAME)]);
			break;
		case 5:
		case 6:
			if(fd[k] < 0)
				break;
			off = 512 * rnd(NREC);
			r.magic = MAGIC;
			r.off = off;
			r.pid = getpid();
			r.seq = seq++;
			for(i = 0; i < 123; i++)
				r.word[i] = rnd(0x7fffffff);
			r.sum = sum(&r);
			if(lseek(fd[k], (long)off, 0) >= 0)
				write(fd[k], (char *)&r, 512);
			break;
		case 7:
		case 8:
			if(fd[k] < 0)
				break;
			off = 512 * rnd(NREC);
			if(lseek(fd[k], (long)off, 0) < 0)
				break;
			m = read(fd[k], (char *)&r, 512);
			if(m == 512)
				check(&r, k, off);
			else if(m > 0)
				fail("part of a record read", k, off);
			break;
		default:
			if(stat(name[rnd(NNAME)], &sb) == 0 && sb.st_size%512)
				fail("size not a whole number of records", -1,
				    (unsigned)sb.st_size);
		}
	}
	exit(0);
}

int
main(int argc, char **argv)
{
	int nproc, rounds, k, st, bad, pid;

	if(argc != 4) {
		printf("usage: fzrace seed nproc rounds\n");
		exit(2);
	}
	seed = atol(argv[1]);
	nproc = atoi(argv[2]);
	rounds = atoi(argv[3]);
	bad = 0;
	for(; rounds > 0 && !bad; rounds--, seed++) {
		for(k = 0; k < NNAME; k++)
			unlink(name[k]);
		for(k = 0; k < nproc; k++)
			if((pid = fork()) == 0) {
				me = k;
				racer();
			} else if(pid < 0)
				printf("fzrace: cannot fork\n");
		while((pid = wait(&st)) >= 0)
			if(st != 0)
				bad = 1;
	}
	for(k = 0; k < NNAME; k++)
		unlink(name[k]);
	if(!bad)
		printf("fzrace ok\n");
	exit(bad);
}
