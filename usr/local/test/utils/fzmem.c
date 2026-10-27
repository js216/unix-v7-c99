/*
 * fzmem seed nproc mb [-s]: more memory than RAM.  nproc processes each
 * take between 3mb/4 and mb megabytes of data with sbrk and fill it
 * with a pattern of their own, so that together they need more than
 * the machine has and the swapper must move them out and back in.
 * Each then checks its memory, grows its stack by recursion up to
 * 2 MB deep, checking every frame, changes part of it, forks a child
 * which checks the copy, shrinks or grows itself, and checks again,
 * for several passes, yielding between them so that the others run.
 * Every word must hold what was last written.  With -s, the processes
 * fork one at a time, taking turns at a pipe, so that at most one copy
 * is made at once, and the most that they can need together is little
 * more than (nproc+1)*mb.  Prints the seed and the first bad word and
 * exits 1; prints "fzmem ok" otherwise.
 */

#include <stdio.h>

int	brk(char *addr);

#define	MB	(1024L*1024L)
#define	NPASS	4
#define	PG	1024		/* words in a page */

long	seed;
unsigned	*base;
long	nw;			/* words in use */
unsigned	gen;		/* generation of the pattern */
int	lk[2] = { -1, -1 };	/* the turn to fork, with -s */

static unsigned
rnd(unsigned long *s, unsigned n)
{
	*s ^= *s << 13;
	*s ^= *s >> 17;
	*s ^= *s << 5;
	return(n ? *s % n : (unsigned)*s);
}

static unsigned
pat(long i, unsigned g)
{
	unsigned long h;

	h = (unsigned long)i*2654435761UL ^ (unsigned long)seed*40503UL ^
	    g*97UL;
	h ^= h >> 15;
	return((unsigned)h);
}

static void
fail(char *who, long i, unsigned g)
{
	printf("FAIL fzmem seed %ld %s pid %d word %ld of %ld: %x, not %x\n",
	    seed, who, getpid(), i, nw, base[i], pat(i, g));
	exit(1);
}

/*
 * Fill the words from a to b with generation g; every page gets its
 * first and last word, and a stride of others.
 */
static void
fill(long a, long b, unsigned g)
{
	long i;

	for(i = (a+60)/61*61; i < b; i += 61)
		base[i] = pat(i, g);
	for(i = a - a%PG; i < b; i += PG) {
		if(i >= a)
			base[i] = pat(i, g);
		if(i+PG-1 < b)
			base[i+PG-1] = pat(i+PG-1, g);
	}
}

static void
check(char *who, long a, long b, unsigned g)
{
	long i;

	for(i = (a+60)/61*61; i < b; i += 61)
		if(base[i] != pat(i, g))
			fail(who, i, g);
	for(i = a - a%PG; i < b; i += PG) {
		if(i >= a && base[i] != pat(i, g))
			fail(who, i, g);
		if(i+PG-1 < b && base[i+PG-1] != pat(i+PG-1, g))
			fail(who, i+PG-1, g);
	}
}

/*
 * Recurse n deep, each frame a kilobyte of a pattern of its own, so
 * that the stack grows a page at a time below a live stack; every
 * frame must hold its pattern when the calls below it return.
 */
static unsigned
deep(int n, unsigned h)
{
	volatile unsigned v[256];
	register int i;
	unsigned r;

	for(i = 0; i < 256; i++)
		v[i] = h*31 + i;
	r = n > 0? deep(n-1, h*2654435761U + n): h;
	for(i = 0; i < 256; i++)
		if(v[i] != h*31 + i) {
			printf("FAIL fzmem seed %ld: stack frame %d word %d\n",
			    seed, n, i);
			exit(1);
		}
	return(r ^ v[n&255]);
}

static void
worker(int k, long mb)
{
	unsigned long s;
	long size, more;
	int pass, pid, st;
	char *p;

	s = seed*2654435761UL + k*7919UL + 1;
	seed = seed*100 + k;
	size = (mb*3/4 + rnd(&s, (unsigned)(mb/4 + 1))) * MB;
	if((p = sbrk(0)) == (char *)-1)
		exit(3);
	p = (char *)(((unsigned)p + 4095) & ~4095U);
	if(brk(p + size) < 0) {
		printf("fzmem: pid %d cannot have %ld MB\n", getpid(), size/MB);
		exit(0);
	}
	base = (unsigned *)p;
	nw = size/4;
	gen = 1;
	fill(0, nw, gen);
	for(pass = 0; pass < NPASS; pass++) {
		sleep(1);
		check("after sleep", 0, nw, gen);
		deep(rnd(&s, 2048), (unsigned)seed + pass);
		check("after recursion", 0, nw, gen);
		gen++;
		fill(0, nw/2, gen);
		fill(nw/2, nw, gen);
		if(lk[0] >= 0 && read(lk[0], (char *)&st, 1) != 1)
			exit(3);
		if((pid = fork()) < 0) {
			printf("fzmem: pid %d cannot fork\n", getpid());
			if(lk[1] >= 0)
				write(lk[1], (char *)&st, 1);
			continue;
		}
		if(pid == 0) {
			check("child", 0, nw, gen);
			gen++;
			fill(0, nw, gen);
			check("child after fill", 0, nw, gen);
			exit(0);
		}
		while(wait(&st) != pid)
			;
		if(lk[1] >= 0)
			write(lk[1], "", 1);
		if(st != 0) {
			printf("FAIL fzmem seed %ld: child %d status %o\n",
			    seed, pid, st);
			exit(1);
		}
		check("parent after fork", 0, nw, gen);
		more = (long)rnd(&s, 16) * MB - 8*MB;
		if(size + more > MB && brk(p + size + more) == 0) {
			size += more;
			if(more < 0)
				nw = size/4;
			else {
				gen++;
				fill(0, size/4, gen);
				nw = size/4;
			}
		}
		check("after brk", 0, nw, gen);
	}
	exit(0);
}

int
main(int argc, char **argv)
{
	int k, n, st, bad, pid;
	long mb;

	if(argc != 4 && (argc != 5 || strcmp(argv[4], "-s") != 0)) {
		printf("usage: fzmem seed nproc mb [-s]\n");
		exit(2);
	}
	if(argc == 5 && (pipe(lk) < 0 || write(lk[1], "", 1) != 1)) {
		printf("fzmem: no pipe\n");
		exit(2);
	}
	seed = atol(argv[1]);
	n = atoi(argv[2]);
	mb = atol(argv[3]);
	for(k = 0; k < n; k++)
		if(fork() == 0)
			worker(k, mb);
	bad = 0;
	while((pid = wait(&st)) >= 0)
		if(st != 0) {
			printf("FAIL fzmem seed %ld: pid %d status %o\n",
			    seed, pid, st);
			bad = 1;
		}
	if(!bad)
		printf("fzmem ok\n");
	exit(bad);
}
