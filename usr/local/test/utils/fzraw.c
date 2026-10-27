/*
 * fzraw seed rounds: raw reads against the block device.  Each round
 * reads random runs of blocks of the root file system through the raw
 * disk, /dev/rrk2, into a buffer at a random even place, so that a
 * transfer crosses pages of the image, which physio moves one page
 * at a time, and compares them with the same blocks read through the
 * buffer cache, /dev/root.  The other fuzzers change the file system
 * meanwhile, so each try reads the run through the cache, syncs, reads
 * it raw, and reads it through the cache again.  The raw read must
 * agree with the first if the two through the cache agree; if they do
 * not, the run changed, and the try proves nothing.  A difference
 * counts only if three tries show it, and a run which changes in every
 * one of MAXTRY tries is passed over.  It writes nothing.  Prints the
 * seed, round, and run of the first difference and exits 1; prints
 * "fzraw ok" otherwise.
 */

#include <stdio.h>

#define	NBLK	32768		/* the root file system */
#define	MAXBLK	26		/* the longest run, more than three pages */
#define	NCASE	200
#define	MAXTRY	50

unsigned long	rs;
long	seed;
int	round, raw, blk;
char	rbuf[4096 + 512*MAXBLK], abuf[512*MAXBLK], bbuf[512*MAXBLK];

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(rs % n);
}

static void
fail(char *what, long b, unsigned off, unsigned n)
{
	printf("FAIL fzraw seed %ld round %d: %s, block %ld, %u bytes at %u\n",
	    seed, round, what, b, n, off);
	exit(1);
}

static void
cread(char *buf, long b, unsigned off, unsigned n)
{
	if(lseek(blk, b*512, 0) < 0 || read(blk, buf, n) != (int)n)
		fail("block read", b, off, n);
}

static int
differ(char *p, char *q, unsigned n)
{
	while(n-- > 0)
		if(*p++ != *q++)
			return(1);
	return(0);
}

/*
 * One try: 1 if the run reads the same both ways, 0 if the raw read
 * differs from two reads through the cache which agree, and -1 if
 * those differ
 */
static int
same(long b, unsigned off, unsigned n)
{
	register char *p;

	p = rbuf + off;
	cread(abuf, b, off, n);
	sync();
	if(lseek(raw, b*512, 0) < 0 || read(raw, p, n) != (int)n)
		fail("raw read", b, off, n);
	cread(bbuf, b, off, n);
	if(differ(abuf, bbuf, n))
		return(-1);
	return(!differ(p, abuf, n));
}

int
main(int argc, char **argv)
{
	int rounds, i, t, u, r;
	long b;
	unsigned off, n;

	if(argc != 3) {
		printf("usage: fzraw seed rounds\n");
		exit(2);
	}
	seed = atol(argv[1]);
	rounds = atoi(argv[2]);
	rs = seed*2654435761UL + 31;
	if((raw = open("/dev/rrk2", 0)) < 0 || (blk = open("/dev/root", 0)) < 0) {
		printf("fzraw: cannot open the disk\n");
		exit(2);
	}
	for(round = 0; round < rounds; round++)
		for(i = 0; i < NCASE; i++) {
			n = 512 * (1 + rnd(MAXBLK));
			b = rnd(NBLK - MAXBLK);
			off = 2 * rnd(2048);
			t = 0;
			for(u = 0; u < MAXTRY && t < 3; u++)
				if((r = same(b, off, n)) == 1)
					break;
				else if(r == 0)
					t++;
			if(t == 3)
				fail("raw and block differ", b, off, n);
		}
	printf("fzraw ok\n");
	exit(0);
}
