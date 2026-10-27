/*
 * fzarg seed rounds: exec with random arguments and environments.
 * Each case makes a list of strings of random bytes, of a total size
 * at random, near the limit of NCARGS-1 bytes, or past it, which
 * crosses the page at 4096 where exec collects them, splits it between
 * the arguments and the environment, and execs this program with it,
 * the case's seed in the last environment string, so that the new
 * image can make the list again and compare.  Some cases pass a null
 * argument list, which also drops the environment, or a bad pointer.
 * The status tells whether exec failed with the error it must, or ran
 * and found every string it was given.  Memory may run short beside
 * fzmem, so a case which fails for want of it is tried again.  Prints
 * the seed, round, and case of the first difference and exits 1;
 * prints "fzarg ok" otherwise.  In the new image, file 9 is open.
 */

#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#define	LIMIT	5119		/* bytes exec takes, NCARGS-1 */
#define	MAXSTR	6200
#define	NCASE	200
#define	SELF	"/usr/local/test/utils/fzarg"
#define	TAG	"FZARG="

extern int errno;
extern char **environ;
unsigned long	rs;
long	seed;
int	round, ncase;
char	pool[2*MAXSTR + 64];
char	*str[MAXSTR + 2];
int	nstr, na, bad, nullarg;
char	tag[40];

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(rs % n);
}

/*
 * Make case c's strings: str[0..na) the arguments, str[na..nstr) the
 * environment, the tag last.  Returns their size with the nulls.
 */
static int
make(long c)
{
	register char *p;
	register int i, n;
	int total, left, cap;

	rs = c*2654435761UL + 17;
	switch(rnd(4)) {
	case 0:
		total = rnd(200);
		break;
	case 1:
		total = LIMIT - 4 + rnd(9);
		break;
	case 2:
		total = 4096 - 8 + rnd(17);
		break;
	default:
		total = rnd(MAXSTR);
	}
	switch(rnd(4)) {
	case 0:
		cap = 1;
		break;
	case 1:
		cap = 8;
		break;
	case 2:
		cap = 300;
		break;
	default:
		cap = MAXSTR;
	}
	sprintf(tag, "%s%ld", TAG, c);
	if(total < (int)strlen(tag) + 1)
		total = strlen(tag) + 1;
	left = total - (strlen(tag) + 1);
	p = pool;
	nstr = 0;
	while(left > 0) {
		n = 1 + rnd(left < cap ? left : cap);
		str[nstr++] = p;
		for(i = 0; i < n - 1; i++)
			*p++ = 1 + rnd(255);
		*p++ = 0;
		left -= n;
	}
	na = rnd(nstr + 1);
	str[nstr++] = tag;
	nullarg = rnd(20) == 0;
	bad = rnd(10) == 0 ? (int)rnd(nstr + 1) : -1;
	return(total);
}

/*
 * The new image: is it what case c was given?
 */
static int
child(int argc, char **argv)
{
	register int i, ne;
	long c;

	for(ne = 0; environ[ne]; ne++)
		;
	if(ne == 0)
		return(argc != 0);
	if(strncmp(environ[ne-1], TAG, strlen(TAG)) != 0)
		return(1);
	c = atol(environ[ne-1] + strlen(TAG));
	make(c);
	if(nullarg || bad >= 0 || argc != na || ne != nstr - na)
		return(1);
	for(i = 0; i < argc; i++)
		if(strcmp(argv[i], str[i]) != 0)
			return(1);
	for(i = 0; i < ne; i++)
		if(strcmp(environ[i], str[na + i]) != 0)
			return(1);
	return(0);
}

static void
fail(char *what, long c, int status)
{
	printf("FAIL fzarg seed %ld round %d case %d (%ld): %s, status %#o\n",
	    seed, round, ncase, c, what, status);
	exit(1);
}

/*
 * Run case c; its status
 */
static int
try(long c)
{
	char *av[MAXSTR + 3], *ev[MAXSTR + 3];
	int pid, status, i, j;

	make(c);
	for(i = 0, j = 0; i < na; i++)
		av[j++] = i == bad ? (char *)-1 : str[i];
	av[j] = 0;
	for(j = 0; i < nstr; i++)
		ev[j++] = i == bad ? (char *)-1 : str[i];
	ev[j] = 0;
	fflush(stdout);
	if((pid = fork()) == 0) {
		if((i = open("/dev/null", 0)) < 0 || dup2(i, 9) < 0)
			_exit(99);
		if(bad == nstr)
			execve(SELF, (char **)-1, ev);
		else
			execve(SELF, nullarg ? (char **)0 : av, ev);
		_exit(100 + errno);
	}
	if(pid < 0)
		fail("cannot fork", c, 0);
	while(wait(&status) != pid)
		;
	return(status);
}

int
main(int argc, char **argv)
{
	struct stat sb;
	int rounds, total, before, want, status, t, i;
	long c;

	if(fstat(9, &sb) == 0)
		exit(child(argc, argv));
	if(argc != 3) {
		printf("usage: fzarg seed rounds\n");
		exit(2);
	}
	seed = atol(argv[1]);
	rounds = atoi(argv[2]);
	for(round = 0; round < rounds; round++)
		for(ncase = 0; ncase < NCASE; ncase++) {
			c = (seed*rounds + round)*NCASE + ncase;
			total = make(c);
			want = 0;
			if(nullarg && bad < nstr)
				total = 0;
			else if(bad >= 0) {
				for(before = 0, i = 0; i < bad && bad < nstr; i++)
					before += strlen(str[i]) + 1;
				want = 100 + (before >= LIMIT ? E2BIG : EFAULT);
			}
			if(want == 0 && total > LIMIT)
				want = 100 + E2BIG;
			for(t = 0; t < 20; t++) {
				status = try(c);
				if(status != (100 + ENOMEM) << 8)
					break;
				sleep(1);
			}
			if(status != want << 8)
				fail(want ? "exec did not fail as it must" :
				    "exec gave the wrong strings", c, status);
		}
	printf("fzarg ok\n");
	exit(0);
}
