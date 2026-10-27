/*
 * fzraw seed rounds: raw reads against the block device.  Each round
 * reads random runs of blocks of the root file system through the raw
 * disk, /dev/rrk2, into a buffer at a random even place, so that a
 * transfer crosses pages of the image, which physio moves one page
 * at a time, and compares them with the same blocks read through the
 * buffer cache, /dev/root.  The other fuzzers change the file system
 * meanwhile, so a difference counts only if it stays after a sync,
 * three times.  It writes nothing.  Prints the seed, round, and run
 * of the first difference and exits 1; prints "fzraw ok" otherwise.
 */

#include <stdio.h>

#define	NBLK	32768		/* the root file system */
#define	MAXBLK	26		/* the longest run, more than three pages */
#define	NCASE	200

unsigned long	rs;
long	seed;
int	round, raw, blk;
char	rbuf[4096 + 512*MAXBLK], bbuf[512*MAXBLK];

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

/*
 * 1 if the run reads the same both ways, 0 if not
 */
static int
same(long b, unsigned off, unsigned n)
{
	register char *p;
	register unsigned i;

	p = rbuf + off;
	if(lseek(raw, b*512, 0) < 0 || read(raw, p, n) != (int)n)
		fail("raw read", b, off, n);
	if(lseek(blk, b*512, 0) < 0 || read(blk, bbuf, n) != (int)n)
		fail("block read", b, off, n);
	for(i = 0; i < n; i++)
		if(p[i] != bbuf[i])
			return(0);
	return(1);
}

int
main(int argc, char **argv)
{
	int rounds, i, t;
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
			for(t = 0; t < 3 && !same(b, off, n); t++)
				sync();
			if(t == 3)
				fail("raw and block differ", b, off, n);
		}
	printf("fzraw ok\n");
	exit(0);
}
