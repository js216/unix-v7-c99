/*
 * fzproc seed rounds: random families of processes, each child
 * writing a stream of records into a pipe of its own, directly,
 * after an exec, or through a grandchild.  The parent reads the
 * pipes in random amounts, kills a child or closes its pipe at a
 * random record, and checks every byte against the stream the child
 * must have written, that no record is torn, and the status wait
 * returns.  Prints the seed and round on the first difference and
 * exits 1; prints "fzproc ok" otherwise.
 *	fzproc -w seed nrec	write the stream on the standard output
 */

#include <stdio.h>
#include <signal.h>

#define	MAXKID	5
#define	MAXREC	40
#define	MAXLEN	400
#define	SELF	"/usr/local/test/utils/fzproc"

enum { NONE, KILL, TERM, CLOSE };

struct	kid {
	int	pid;
	int	fd;
	long	seed;
	int	nrec;
	int	fate;
	int	at;		/* record at which fate strikes */
	int	status;
	int	got;		/* whole records received */
} kid[MAXKID];
unsigned long	rs;
long	seed;
int	round;

static unsigned
rnd(unsigned long *s, unsigned n)
{
	*s ^= *s << 13;
	*s ^= *s >> 17;
	*s ^= *s << 5;
	return(*s % n);
}

static void
fail(char *what, int k)
{
	printf("FAIL fzproc seed %ld round %d kid %d: %s\n", seed, round,
	    k, what);
	exit(1);
}

/*
 * Record r of the stream with seed s: its length, and its bytes in b.
 */
static int
record(long s, int r, char *b)
{
	unsigned long g;
	int i, n;

	g = s*2654435761UL + r*40503UL + 1;
	n = 1 + rnd(&g, MAXLEN);
	for(i = 0; i < n; i++)
		b[i] = rnd(&g, 256);
	return(n);
}

static void
writer(long s, int nrec)
{
	char b[MAXLEN];
	int r, n;

	for(r = 0; r < nrec; r++) {
		n = record(s, r, b);
		if(write(1, b, n) != n)
			exit(3);
	}
}

static int
code(long s)
{
	return((int)(s % 100));
}

/*
 * Read kid k's pipe to its end, comparing it with the stream, and
 * carry out the kid's fate when the record it names has come.
 */
static void
reader(int k)
{
	struct kid *kp;
	char want[MAXLEN], in[MAXLEN];
	int n, have, len, i;

	kp = &kid[k];
	have = 0;
	len = kp->nrec > 0 ? record(kp->seed, 0, want) : 0;
	for(;;) {
		if(kp->got == kp->at && kp->fate != NONE) {
			if(kp->fate == CLOSE) {
				close(kp->fd);
				kp->fd = -1;
				return;
			}
			kill(kp->pid, kp->fate == KILL ? SIGKILL : SIGTERM);
			kp->fate = -kp->fate;
		}
		n = 1 + rnd(&rs, MAXLEN);
		if(n > len - have && len > have)
			n = len - have;
		if((n = read(kp->fd, in, n)) < 0)
			fail("read", k);
		if(n == 0)
			break;
		if(kp->got >= kp->nrec)
			fail("more than the stream", k);
		for(i = 0; i < n; i++)
			if(in[i] != want[have+i])
				fail("wrong byte", k);
		if((have += n) == len) {
			have = 0;
			if(++kp->got < kp->nrec)
				len = record(kp->seed, kp->got, want);
		}
	}
	if(have != 0)
		fail("torn record", k);
	close(kp->fd);
	kp->fd = -1;
}

static void
child(int k, int p)
{
	struct kid *kp;
	char s[20], n[20];
	int how, pid, st;

	kp = &kid[k];
	close(1);
	dup(p);
	close(p);
	how = rnd(&rs, 3);
	if(how == 0) {
		writer(kp->seed, kp->nrec);
		exit(code(kp->seed));
	}
	if(how == 1) {
		sprintf(s, "%ld", kp->seed);
		sprintf(n, "%d", kp->nrec);
		execl(SELF, "fzproc", "-w", s, n, (char *)0);
		exit(4);
	}
	if((pid = fork()) == 0) {
		writer(kp->seed, kp->nrec);
		exit(code(kp->seed));
	}
	close(1);
	while(wait(&st) != pid)
		;
	if(st & 0177)
		kill(getpid(), st & 0177);
	exit(st>>8 & 0377);
}

static void
check(int k)
{
	struct kid *kp;
	int sig, done, st;

	kp = &kid[k];
	st = kp->status;
	sig = st & 0177;
	done = st == code(kp->seed)<<8;
	switch(kp->fate < 0 ? -kp->fate : kp->fate) {
	case NONE:
		if(!done || kp->got != kp->nrec)
			fail("status or count", k);
		break;
	case KILL:
		if(!done && sig != SIGKILL)
			fail("status after SIGKILL", k);
		break;
	case TERM:
		if(!done && sig != SIGTERM)
			fail("status after SIGTERM", k);
		break;
	case CLOSE:
		if(!done && sig != SIGPIPE)
			fail("status after close", k);
	}
}

int
main(int argc, char **argv)
{
	struct kid *kp;
	int nkid, rounds, k, p[2], pid, st, order[MAXKID];

	if(argc == 4 && strcmp(argv[1], "-w") == 0) {
		writer(atol(argv[2]), atoi(argv[3]));
		exit(code(atol(argv[2])));
	}
	if(argc != 3) {
		printf("usage: fzproc seed rounds\n");
		exit(2);
	}
	seed = atol(argv[1]);
	rounds = atoi(argv[2]);
	rs = seed*2654435761UL + 7;
	for(round = 0; round < rounds; round++) {
		nkid = 1 + rnd(&rs, MAXKID);
		for(k = 0; k < nkid; k++) {
			kp = &kid[k];
			kp->seed = rnd(&rs, 1000000);
			kp->nrec = rnd(&rs, MAXREC+1);
			kp->fate = rnd(&rs, 2) ? NONE : 1 + rnd(&rs, 3);
			kp->at = rnd(&rs, kp->nrec+1);
			kp->got = 0;
			if(pipe(p) < 0)
				fail("pipe", k);
			if((kp->pid = fork()) < 0)
				fail("fork", k);
			if(kp->pid == 0) {
				close(p[0]);
				for(st = 0; st < k; st++)
					close(kid[st].fd);
				child(k, p[1]);
			}
			close(p[1]);
			kp->fd = p[0];
		}
		for(k = 0; k < nkid; k++)
			order[k] = k;
		for(k = nkid-1; k > 0; k--) {
			pid = rnd(&rs, k+1);
			st = order[k];
			order[k] = order[pid];
			order[pid] = st;
		}
		for(k = 0; k < nkid; k++)
			reader(order[k]);
		for(k = 0; k < nkid; k++) {
			if((pid = wait(&st)) < 0)
				fail("wait", k);
			for(kp = kid; kp < &kid[nkid] && kp->pid != pid; kp++)
				;
			if(kp == &kid[nkid])
				fail("wait returned a stranger", k);
			kp->status = st;
		}
		if(wait(&st) >= 0)
			fail("child left over", nkid);
		for(k = 0; k < nkid; k++)
			check(k);
	}
	printf("fzproc ok\n");
	exit(0);
}
