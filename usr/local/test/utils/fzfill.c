/*
 * fzfill seed rounds: run the disk out of space, then out of
 * inodes, hold it there a moment while the other fuzzers work, and
 * free it all again.  Every failure must be ENOSPC, and what was
 * written must read back.  Works in the current directory.  Prints
 * "fzfill ok", or the seed and round of a failure and exits 1.
 */

#include <stdio.h>
#include <errno.h>

#define	CHUNK	16384
#define	MAXFILES	3000

unsigned long	rs;
long	seed;
int	round;
char	buf[CHUNK], back[CHUNK];

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(rs % n);
}

static void
fail(char *what)
{
	printf("FAIL fzfill seed %ld round %d: %s (errno %d)\n", seed, round,
	    what, errno);
	exit(1);
}

int
main(int argc, char **argv)
{
	char nm[20];
	long total, got;
	int fd, i, n, k, nfile, rounds;

	if(argc != 3) {
		printf("usage: fzfill seed rounds\n");
		exit(2);
	}
	seed = atol(argv[1]);
	rounds = atoi(argv[2]);
	rs = seed*2654435761UL + 17;
	for(round = 0; round < rounds; round++) {
		for(i = 0; i < CHUNK; i++)
			buf[i] = rnd(256);
		if((fd = creat("big", 0644)) < 0)
			fail("creat big");
		total = 0;
		for(;;) {
			n = 1 + rnd(CHUNK);
			errno = 0;
			if((k = write(fd, buf, n)) != n) {
				if(errno != ENOSPC)
					fail("write which is not ENOSPC");
				break;
			}
			total += n;
		}
		close(fd);
		if((fd = open("big", 0)) < 0)
			fail("open big");
		got = 0;
		while((n = read(fd, back, CHUNK)) > 0)
			got += n;
		close(fd);
		if(got < total)
			fail("big lost what was written");
		for(nfile = 0; nfile < MAXFILES; nfile++) {
			sprintf(nm, "f%d", nfile);
			errno = 0;
			if((fd = creat(nm, 0644)) < 0) {
				if(errno != ENOSPC && errno != ENFILE)
					fail("creat which is not ENOSPC");
				break;
			}
			close(fd);
		}
		sleep(1 + rnd(2));
		for(i = 0; i < nfile; i++) {
			sprintf(nm, "f%d", i);
			if(unlink(nm) < 0)
				fail("unlink a small file");
		}
		if(unlink("big") < 0)
			fail("unlink big");
		sleep(1);
	}
	printf("fzfill ok\n");
	exit(0);
}
