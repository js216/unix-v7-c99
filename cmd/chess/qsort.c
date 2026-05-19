/*
 * Local translation of v7/usr/src/games/chess/qsort.s.
 * Chess move lists are pairs of V7 ints: key, move.  In this ARM C
 * port each record is two int slots in the half-open range [from, to).
 */

#define	SIGHUP	1
#define	SIGINT	2
#define	SIGQUIT	3
#define	SIG_IGN	1

extern int	intrp;
extern int	signal(int sig, int fun);
extern int	time(long *t);
extern int	term();

void	onhup(void);

static void
swapmove(int *a, int *b)
{
	int t;

	t = a[0];
	a[0] = b[0];
	b[0] = t;
	t = a[1];
	a[1] = b[1];
	b[1] = t;
}

void
chess_qsort(int *from, int *to)
{
	int *lo, *hi;
	int *pivot;

again:
	if (to - from <= 2)
		return;

	lo = from;
	hi = to;
	pivot = from + (((to - from) / 2) & ~1);

loop:
	while (lo < pivot) {
		if (lo[0] > pivot[0])
			goto loop1;
		lo += 2;
	}

loop1:
	while (hi > pivot) {
		hi -= 2;
		if (hi[0] >= pivot[0])
			continue;
		swapmove(lo, hi);
		if (lo == pivot)
			pivot = hi;
		goto loop;
	}

	if (lo != pivot) {
		swapmove(lo, hi);
		pivot = lo;
		goto loop1;
	}

	chess_qsort(pivot + 2, to);
	to = pivot;
	goto again;
}

static int
onint()
{

	signal(SIGINT, (int)onint);
	intrp++;
	return 0;
}

void
itinit(void)
{

	if (signal(SIGHUP, SIG_IGN) != SIG_IGN)
		signal(SIGHUP, (int)onhup);
	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
		signal(SIGINT, (int)onint);
	signal(SIGQUIT, SIG_IGN);
}

void
onhup(void)
{

	signal(SIGHUP, SIG_IGN);
	signal(SIGINT, SIG_IGN);
	signal(SIGQUIT, SIG_IGN);
	term();
}

int
clock(void)
{
	static long last;
	long now;
	int elapsed;

	time(&now);
	elapsed = (int)(now - last);
	last = now;
	return elapsed;
}
