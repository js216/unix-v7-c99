/*
 * fzlib seed rounds: the C library against references and invariants.
 * Each round draws, from the seed, a run of malloc, free, and realloc
 * whose live blocks must keep their contents; integers printed with
 * sprintf and read back with atoi, atol, and a parser of its own;
 * doubles printed with %e, %f, and %g and read back with atof, which
 * with 17 digits must give back every bit; ldexp, frexp, modf, floor,
 * and ceil against exact references, and sqrt, exp, log, sin, and cos
 * against identities they must hold to a few units in the last place;
 * scanf reading back what sprintf wrote; arrays sorted by qsort, which must come out ordered and a permutation;
 * strings compared, copied, and searched against naive versions; and
 * times broken down by gmtime against a conversion of its own.  It
 * writes no file.  Prints the seed, round, and check on the first
 * difference and exits 1; prints "fzlib ok" otherwise.
 */

#include <stdio.h>
#include <sys/types.h>
#include <time.h>
#include <math.h>

#define	NLIVE	150
#define	NSORT	1500

unsigned long	rs;
long	seed;
int	round;
char	*what;
char	b1[600], b2[600], b3[1300], b4[1300];

static unsigned
rnd(unsigned n)
{
	rs ^= rs << 13;
	rs ^= rs >> 17;
	rs ^= rs << 5;
	return(n ? rs % n : (unsigned)rs);
}

static void
fail(char *detail)
{
	printf("FAIL fzlib seed %ld round %d %s: %s\n", seed, round, what,
	    detail);
	exit(1);
}

/*
 * malloc: blocks of every size, each filled with bytes made from its
 * number, checked whole before it is freed or reallocated and at
 * random moments, so that an overlap or a lost byte shows.
 */
char	*blk[NLIVE];
unsigned	bsz[NLIVE], bid[NLIVE];

static int
pat(unsigned id, unsigned i)
{
	return((id*31 + i*7 + (i>>8)) & 0377);
}

static unsigned
pickmsize(void)
{
	switch(rnd(8)) {
	case 0:
		return(rnd(5));
	case 1: case 2: case 3:
		return(rnd(64));
	case 4: case 5:
		return(rnd(1100));
	case 6:
		return(1020 + rnd(10));
	default:
		return(rnd(40000));
	}
}

static void
mfill(int k, unsigned from)
{
	unsigned i;

	for(i = from; i < bsz[k]; i++)
		blk[k][i] = pat(bid[k], i);
}

static void
mcheck(int k, unsigned n)
{
	unsigned i;

	for(i = 0; i < n; i++)
		if((blk[k][i] & 0377) != pat(bid[k], i))
			fail("a block lost its contents");
}

static void
fzmalloc(int nops)
{
	int op, k, j;
	unsigned n, id;
	char *p;

	what = "malloc";
	id = 1;
	for(op = 0; op < nops; op++) {
		k = rnd(NLIVE);
		switch(rnd(3)) {
		case 0:
			if(blk[k]) {
				mcheck(k, bsz[k]);
				free(blk[k]);
				blk[k] = NULL;
			}
			break;
		case 1:
			if(blk[k] == NULL) {
				n = pickmsize();
				if((p = malloc(n)) == NULL)
					fail("malloc gave NULL");
				if((unsigned)p & 3)
					fail("malloc gave an unaligned block");
				blk[k] = p;
				bsz[k] = n;
				bid[k] = id++;
				mfill(k, 0);
			}
			break;
		default:
			if(blk[k]) {
				n = pickmsize();
				mcheck(k, bsz[k]);
				if((p = realloc(blk[k], n)) == NULL)
					fail("realloc gave NULL");
				blk[k] = p;
				mcheck(k, n < bsz[k] ? n : bsz[k]);
				j = bsz[k];
				bsz[k] = n;
				if(n > (unsigned)j)
					mfill(k, j);
			}
		}
		if(rnd(50) == 0)
			for(j = 0; j < NLIVE; j++)
				if(blk[j])
					mcheck(j, bsz[j]);
	}
	for(k = 0; k < NLIVE; k++)
		if(blk[k]) {
			mcheck(k, bsz[k]);
			free(blk[k]);
			blk[k] = NULL;
		}
}

/*
 * Integers: every sign, edge, and width, through sprintf and back.
 */
static unsigned
pickint(void)
{
	static unsigned edge[] = { 0, 1, 9, 10, 99, 100, 0x7fffffff,
		0x80000000, 0x80000001, 0xffffffff, 1000000000, 4294967295U,
		07777777777, 0x10000, 65535 };

	switch(rnd(4)) {
	case 0:
		return(edge[rnd(sizeof(edge)/sizeof(edge[0]))] + rnd(3) - 1);
	case 1:
		return(rnd(1000) - 500);
	default:
		return(rnd(0) >> rnd(32));
	}
}

static unsigned long
parse(char *s, int base)
{
	unsigned long v;
	int c;

	v = 0;
	while(*s == ' ' || *s == '0')
		s++;
	for(; (c = *s); s++) {
		if(c >= '0' && c <= '9')
			c -= '0';
		else if(c >= 'a' && c <= 'f')
			c -= 'a' - 10;
		else if(c >= 'A' && c <= 'F')
			c -= 'A' - 10;
		else
			break;
		v = v*base + c;
	}
	return(v);
}

static void
fzint(int ncase)
{
	int i, w;
	unsigned u;
	int n;

	what = "integers";
	for(i = 0; i < ncase; i++) {
		u = pickint();
		n = (int)u;
		sprintf(b1, "%d", n);
		if(atoi(b1) != n)
			fail(b1);
		if(atol(b1) != (long)n)
			fail(b1);
		sprintf(b1, "%ld", (long)n);
		if(atol(b1) != (long)n)
			fail(b1);
		sprintf(b1, "%u", u);
		if(parse(b1, 10) != u)
			fail(b1);
		sprintf(b1, "%o", u);
		if(parse(b1, 8) != u)
			fail(b1);
		sprintf(b1, "%x", u);
		if(parse(b1, 16) != u)
			fail(b1);
		sprintf(b1, "%X", u);
		if(parse(b1, 16) != u)
			fail(b1);
		w = rnd(20);
		sprintf(b1, "%*d", w, n);
		sprintf(b2, "%d", n);
		if((int)strlen(b1) != ((int)strlen(b2) > w ? (int)strlen(b2) : w) ||
		    atoi(b1) != n)
			fail(b1);
		sprintf(b1, "%-*d|", w, n);
		if(atoi(b1) != n || strlen(b1) < strlen(b2) + 1)
			fail(b1);
		if(n >= 0) {
			sprintf(b4, "%%0%dd", w);
			sprintf(b1, b4, n);
			if(parse(b1, 10) != (unsigned)n)
				fail(b1);
		}
	}
}

/*
 * Doubles: printed and read back, within the error a 17-digit or
 * shorter decimal allows.
 */
static double
pickdouble(void)
{
	double x, s;
	int e;

	x = (double)rnd(0) / 4294967296.0 + (double)rnd(0) / 18446744073709551616.0;
	e = rnd(4) == 0 ? (int)rnd(581) - 290 : (int)rnd(41) - 20;
	s = 1.0;
	while(e > 0) {
		s *= 10.0;
		e--;
	}
	while(e < 0) {
		s /= 10.0;
		e++;
	}
	x *= s;
	return(rnd(2) ? -x : x);
}

static double
ten(int p)
{
	double t;

	for(t = 1.0; p > 0; p--)
		t *= 10.0;
	return(t);
}

static double
dabs(double x)
{
	return(x < 0 ? -x : x);
}

static void
near(double x, double y, double rel, char *s)
{
	union { double d; unsigned w[2]; } ux, uy;
	char m[700];

	if(dabs(y - x) > dabs(x) * rel + 1e-300) {
		ux.d = x;
		uy.d = y;
		sprintf(m, "%s read back as %.17e, bits %08x%08x for %08x%08x",
		    s, y, uy.w[1], uy.w[0], ux.w[1], ux.w[0]);
		fail(m);
	}
}

static void
fzdouble(int ncase)
{
	int i, p;
	double x;

	what = "doubles";
	for(i = 0; i < ncase; i++) {
		x = pickdouble();
		sprintf(b3, "%.17e", x);
		near(x, atof(b3), 1e-15, b3);
		p = 1 + rnd(15);
		sprintf(b3, "%.*e", p, x);
		near(x, atof(b3), 0.50001 / ten(p) + 1e-15, b3);
		sprintf(b3, "%.*g", p, x);
		near(x, atof(b3), 0.50001 / ten(p - 1) + 1e-15, b3);
		if(dabs(x) < 1e15 && dabs(x) > 1e-5) {
			sprintf(b3, "%.6f", x);
			if(dabs(atof(b3) - x) > 5.0001e-7 + dabs(x) * 1e-15)
				fail(b3);
		}
	}
}

/*
 * Exact floating point: any bit pattern but infinity and NaN, a
 * quarter of them subnormal, and for ldexp also numbers scaled to
 * land near the subnormal range.  ref is m * 2^n rounded once, to
 * nearest, ties to even, or the largest double where ldexp clamps.
 */
typedef union {
	double	d;
	unsigned	w[2];
} bits;

static double
pickbits(void)
{
	bits u;

	u.w[0] = rnd(0);
	u.w[1] = rnd(0);
	switch(rnd(4)) {
	case 0:
		u.w[1] &= 0x800fffff;
		break;
	case 1:
		u.w[1] = (u.w[1] & 0x800fffff) | (1003 + rnd(41)) << 20;
		break;
	}
	if((u.w[1] & 0x7ff00000) == 0x7ff00000)
		u.w[1] &= 0xffefffff;
	return(u.d);
}

static void
same(double x, double y, char *s)
{
	bits ux, uy;
	char m[700];

	ux.d = x;
	uy.d = y;
	if(ux.w[0] != uy.w[0] || ux.w[1] != uy.w[1]) {
		sprintf(m, "%s: bits %08x%08x, not %08x%08x", s, uy.w[1],
		    uy.w[0], ux.w[1], ux.w[0]);
		fail(m);
	}
}

static double
ref(double x, int n)
{
	bits u;
	unsigned long long m, r, half;
	int e, p, sh;

	u.d = x;
	e = u.w[1] >> 20 & 03777;
	m = (unsigned long long)(u.w[1] & 0xfffff) << 32 | u.w[0];
	if(m == 0 && e == 0)
		return(x);
	if(e)
		m |= 1ULL << 52;
	else
		e = 1;
	e += n - 1075;
	for(p = 52; !(m >> p & 1); p--)
		;
	u.w[1] &= 0x80000000;
	u.w[0] = 0;
	if(e + p > 1023)
		return(x < 0 ? -1.7976931348623157e308 :
		    1.7976931348623157e308);
	if(e + p >= -1022) {
		m = (m << (52 - p) & ((1ULL << 52) - 1)) |
		    (unsigned long long)(e + p + 1023) << 52;
	} else if(e >= -1074) {
		m <<= e + 1074;
	} else {
		sh = -1074 - e;
		if(sh > 54)
			m = 0;
		else {
			r = m & ((1ULL << sh) - 1);
			half = 1ULL << (sh - 1);
			m >>= sh;
			if(r > half || (r == half && (m & 1)))
				m++;
		}
	}
	u.w[1] |= m >> 32;
	u.w[0] = m;
	return(u.d);
}

static int
integral(double x)
{
	bits u;
	int e;

	u.d = x;
	e = (int)(u.w[1] >> 20 & 03777) - 1023;
	if(e < 0)
		return(x == 0);
	if(e >= 52)
		return(1);
	if(e >= 20)
		return((u.w[0] & (0xffffffffU >> (e - 20))) == 0);
	return(u.w[0] == 0 && (u.w[1] & (0xfffff >> e)) == 0);
}

static void
fzfloat(int ncase)
{
	int i, n, e;
	double x, y, f;
	char m[100];

	for(i = 0; i < ncase; i++) {
		x = pickbits();
		what = "round trip";
		sprintf(b3, "%.16e", x);
		same(x, atof(b3), b3);
		what = "ldexp";
		switch(rnd(3)) {
		case 0:
			n = (int)rnd(301) - 150;
			y = x;
			break;
		case 1:
			n = (int)rnd(4401) - 2200;
			y = x;
			break;
		default:
			y = ref(frexp(x, &e), -(int)rnd(80));
			n = -980 - (int)rnd(100);
		}
		sprintf(m, "%.17e, %d", y, n);
		same(ref(y, n), ldexp(y, n), m);
		what = "frexp";
		f = frexp(x, &e);
		sprintf(m, "%.17e to %.17e, %d", x, f, e);
		if(x != 0 && (dabs(f) < 0.5 || dabs(f) >= 1))
			fail(m);
		same(x, ref(f, e), m);
		what = "modf";
		f = modf(x, &y);
		sprintf(m, "%.17e to %.17e, %.17e", x, y, f);
		if(!integral(y) || dabs(f) >= 1 || y + f != x ||
		    (f != 0 && (f < 0) != (x < 0)))
			fail(m);
		what = "floor";
		y = floor(x);
		sprintf(m, "%.17e to %.17e", x, y);
		if(!integral(y) || y > x || (y != x && y + 1 <= x))
			fail(m);
		what = "ceil";
		y = ceil(x);
		sprintf(m, "%.17e to %.17e", x, y);
		if(!integral(y) || y < x || (y != x && y - 1 >= x))
			fail(m);
		x = dabs(x);
		if(x < 1e-300 || x > 1e300)
			continue;
		what = "sqrt";
		y = sqrt(x);
		sprintf(m, "%.17e to %.17e", x, y);
		if(dabs(y*y - x) > x * 6.7e-16)
			fail(m);
		x = (double)rnd(0) / 4294967296.0 * 1400 - 700;
		what = "exp, log";
		y = log(exp(x));
		sprintf(m, "%.17e to %.17e", x, y);
		if(dabs(y - x) > 1e-14 * (dabs(x) + 1))
			fail(m);
		x = (double)rnd(0) / 4294967296.0 * 2000 - 1000;
		what = "sin, cos";
		y = sin(x)*sin(x) + cos(x)*cos(x);
		sprintf(m, "%.17e to %.17e", x, y);
		if(dabs(y - 1) > 1e-14)
			fail(m);
	}
}

/*
 * scanf: what sprintf wrote, with random white space between, must
 * read back to the same values and count, for integers of every
 * size and base, numbers in fields of fixed width, doubles bit for
 * bit, words, characters, and character classes.
 */
static char	*sep[] = { " ", "  ", "\t", "\n", " \t\n " };

static unsigned long long
pickll(void)
{
	unsigned long long v;

	v = (unsigned long long)rnd(0) << 32 | rnd(0);
	return(rnd(2) ? v >> rnd(64) : v);
}

static void
scanint(void)
{
	int i, n, k, d, d2;
	unsigned u, u2, pw;
	long l, l2;
	long long ll, ll2;
	short h, h2;

	what = "scanf integers";
	d = pickint();
	u = pickint();
	l = pickint();
	ll = pickll();
	h = pickint();
	k = rnd(5);
	sprintf(b3, "%s%d%s%o%s%x%s%ld%s%lld%s%d", sep[rnd(5)], d, sep[k],
	    u, sep[rnd(5)], u, sep[rnd(5)], l, sep[rnd(5)], ll,
	    sep[rnd(5)], h);
	d2 = l2 = h2 = 0;
	u2 = 0;
	ll2 = 0;
	n = sscanf(b3, "%d%o", &d2, &u2);
	if(n != 2 || d2 != d || u2 != u)
		fail(b3);
	u2 = 0;
	n = sscanf(b3, "%*d %*o %x %ld %lld %hd", &u2, &l2, &ll2, &h2);
	if(n != 4 || u2 != u || l2 != l || ll2 != ll || h2 != h)
		fail(b3);
	n = sscanf(b3, "%D", &l2);
	if(n != 1 || l2 != d)
		fail(b3);

	what = "scanf widths";
	k = 1 + rnd(9);
	for(i = 0, pw = 1; i < k; i++)
		pw *= 10;
	b3[0] = '\0';
	for(i = 0; i < 4; i++) {
		sprintf(b4, "%%0%du", k);
		sprintf(b3 + strlen(b3), b4, rnd(pw));
	}
	sprintf(b4, "%%%du%%%du%%%du%%%du", k, k, k, k);
	{
		unsigned v[4];
		char *p;

		if(sscanf(b3, b4, &v[0], &v[1], &v[2], &v[3]) != 4)
			fail(b3);
		for(i = 0, p = b3; i < 4; i++, p += k) {
			strncpy(b1, p, k);
			b1[k] = '\0';
			if(parse(b1, 10) != v[i])
				fail(b3);
		}
	}
}

static void
scanfloat(void)
{
	double x, y;
	float f;
	int n;

	what = "scanf doubles";
	x = pickbits();
	sprintf(b3, "%s%.16e%s", sep[rnd(5)], x, sep[rnd(5)]);
	y = 0;
	n = sscanf(b3, rnd(2) ? "%lf" : "%E", &y);
	if(n != 1)
		fail(b3);
	same(x, y, b3);
	x = pickdouble();
	sprintf(b3, "%.9e", x);
	n = sscanf(b3, "%f", &f);
	if(n != 1 || f != (float)atof(b3))
		fail(b3);
}

static void
scanstr(void)
{
	char w[6][40], r[6][40], c[50];
	int i, j, n, k;

	what = "scanf words";
	b3[0] = '\0';
	for(i = 0; i < 6; i++) {
		n = 1 + rnd(30);
		for(j = 0; j < n; j++)
			w[i][j] = '!' + rnd(94);
		w[i][n] = '\0';
		strcat(b3, sep[rnd(5)]);
		strcat(b3, w[i]);
	}
	n = sscanf(b3, "%s %s %*s %s%s %s", r[0], r[1], r[3], r[4], r[5]);
	if(n != 5 || strcmp(r[0], w[0]) || strcmp(r[1], w[1]) ||
	    strcmp(r[3], w[3]) || strcmp(r[4], w[4]) || strcmp(r[5], w[5]))
		fail(b3);
	k = 1 + rnd(8);
	sprintf(b4, "%%%ds", k);
	if(sscanf(b3, b4, r[0]) != 1 || strncmp(r[0], w[0], k) ||
	    (int)strlen(r[0]) != ((int)strlen(w[0]) < k ?
	    (int)strlen(w[0]) : k))
		fail(b3);

	what = "scanf characters";
	k = 1 + rnd(40);
	if((int)strlen(b3) < k)
		k = strlen(b3);
	sprintf(b4, "%%%dc", k);
	for(i = 0; i < 50; i++)
		c[i] = 1;
	if(sscanf(b3, b4, c) != 1 || strncmp(c, b3, k) || c[k] != 1)
		fail(b3);

	what = "scanf classes";
	for(i = 0; i < 30; i++)
		b1[i] = 'a' + rnd(6);
	b1[i] = '\0';
	k = 1 + rnd(29);
	b1[k] = 'x';
	if(sscanf(b1, "%[abcdef]x%[^q]", r[0], r[1]) != (k < 29 ? 2 : 1) ||
	    strncmp(r[0], b1, k) || r[0][k] != '\0' ||
	    (k < 29 && strcmp(r[1], b1 + k + 1)))
		fail(b1);
}

static void
fzscan(int ncase)
{
	int i, d;

	for(i = 0; i < ncase; i++) {
		scanint();
		scanfloat();
		scanstr();
	}
	what = "scanf end";
	d = 7;
	if(sscanf("", "%d", &d) != -1 || sscanf(" \t\n", "%d", &d) != -1 ||
	    sscanf("x", "%d", &d) != 0 || d != 7)
		fail("empty input");
}

/*
 * qsort: arrays of one, four, and twelve bytes, with many equal
 * keys; the result must be ordered and hold the same elements.
 */
char	sa[NSORT*12], sb[NSORT*12];
int	es;

static void
mcopy(char *d, char *s, int n)
{
	while(n-- > 0)
		*d++ = *s++;
}

static int
cmpk(char *p, char *q)
{
	int i;

	for(i = 0; i < es; i++)
		if(p[i] != q[i])
			return((p[i] & 0377) - (q[i] & 0377));
	return(0);
}

static void
fzsort(int ncase)
{
	int i, j, k, n, range;
	char t[12];

	what = "qsort";
	for(k = 0; k < ncase; k++) {
		es = rnd(3) == 0 ? 1 : rnd(2) ? 4 : 12;
		n = rnd(4) ? rnd(40) : rnd(NSORT + 1);
		range = 1 + rnd(rnd(2) ? 5 : 256);
		for(i = 0; i < n*es; i++)
			sa[i] = sb[i] = rnd(range);
		qsort(sa, n, es, cmpk);
		for(i = 1; i < n; i++)
			if(cmpk(sa + (i-1)*es, sa + i*es) > 0)
				fail("out of order");
		for(i = 1; i < n; i++)
			for(j = i; j > 0 && cmpk(sb + (j-1)*es, sb + j*es) > 0; j--) {
				mcopy(t, sb + j*es, es);
				mcopy(sb + j*es, sb + (j-1)*es, es);
				mcopy(sb + (j-1)*es, t, es);
			}
		for(i = 0; i < n*es; i++)
			if(sa[i] != sb[i])
				fail("not a permutation");
	}
}

/*
 * Strings, against naive versions.
 */
static void
randstr(char *s, int max)
{
	int n, i;

	n = rnd(4) ? rnd(12) : rnd(max);
	for(i = 0; i < n; i++)
		s[i] = "aab\377 z"[rnd(6)];
	s[n] = 0;
}

static int
sgn(int x)
{
	return(x < 0 ? -1 : x > 0);
}

static int
nstrcmp(char *p, char *q, int n)
{
	for(; n > 0; n--, p++, q++)
		if(*p != *q || *p == 0)
			return(*p - *q);
	return(0);
}

static void
fzstr(int ncase)
{
	int i, k, n;
	char *p;

	what = "strings";
	for(k = 0; k < ncase; k++) {
		randstr(b1, 500);
		if(rnd(3) == 0) {
			strcpy(b2, b1);
			randstr(b2 + rnd(strlen(b1) + 1), 50);
		} else
			randstr(b2, 500);
		for(n = 0; b1[n]; n++)
			;
		if((int)strlen(b1) != n)
			fail("strlen");
		if(sgn(strcmp(b1, b2)) != sgn(nstrcmp(b1, b2, 100000)))
			fail("strcmp");
		n = rnd(30);
		if(sgn(strncmp(b1, b2, n)) != sgn(nstrcmp(b1, b2, n)))
			fail("strncmp");
		strcpy(b3, b1);
		if(strcmp(b3, b1) != 0)
			fail("strcpy");
		strcat(b3, b2);
		if((int)strlen(b3) != (int)(strlen(b1) + strlen(b2)) ||
		    strncmp(b3 + strlen(b1), b2, 1000) != 0)
			fail("strcat");
		for(i = 0; i < 40; i++)
			b4[i] = 'x';
		n = rnd(40);
		strncpy(b4, b1, n);
		for(i = 0; i < n; i++)
			if(b4[i] != (i < (int)strlen(b1) ? b1[i] : 0))
				fail("strncpy");
		if(b4[n] != 'x')
			fail("strncpy wrote past n");
		strcpy(b3, b2);
		n = rnd(30);
		strncat(b3, b1, n);
		i = (int)strlen(b1) < n ? (int)strlen(b1) : n;
		if((int)strlen(b3) != (int)strlen(b2) + i ||
		    nstrcmp(b3, b2, strlen(b2)) != 0 ||
		    nstrcmp(b3 + strlen(b2), b1, i) != 0)
			fail("strncat");
		p = index(b1, 'b');
		for(i = 0; b1[i] && b1[i] != 'b'; i++)
			;
		if(p != (b1[i] ? b1 + i : NULL))
			fail("index");
		p = rindex(b1, 'a');
		for(i = strlen(b1) - 1; i >= 0 && b1[i] != 'a'; i--)
			;
		if(p != (i >= 0 ? b1 + i : NULL))
			fail("rindex");
	}
}

/*
 * gmtime, for any second of the years 1 to 9999, against the civil
 * calendar computed from the day number.
 */
static void
fztime(int ncase)
{
	struct tm *tm;
	time_t t, z, d, s;
	long long y, m, doy, era, yoe, mp;
	int k;

	what = "gmtime";
	for(k = 0; k < ncase; k++) {
		switch(rnd(3)) {
		case 0:
			t = (time_t)(rnd(0) & 0x7fffffff);
			break;
		case 1:
			t = -(time_t)rnd(0) * rnd(14);
			break;
		default:
			t = (time_t)(((unsigned long long)rnd(0) << 32 | rnd(0)) %
			    (253402300800ULL + 62135596800ULL)) - 62135596800LL;
		}
		d = t / 86400;
		s = t % 86400;
		if(s < 0) {
			s += 86400;
			d--;
		}
		z = d + 719468;
		era = (z >= 0 ? z : z - 146096) / 146097;
		doy = z - era * 146097;
		yoe = (doy - doy/1460 + doy/36524 - doy/146096) / 365;
		y = yoe + era * 400;
		doy = doy - (365*yoe + yoe/4 - yoe/100);
		mp = (5*doy + 2) / 153;
		m = mp < 10 ? mp + 3 : mp - 9;
		if(m <= 2)
			y++;
		tm = gmtime(&t);
		sprintf(b1, "t=%s%ld*1e9+%ld", t < 0 ? "-" : "",
		    (long)((t < 0 ? -t : t) / 1000000000),
		    (long)((t < 0 ? -t : t) % 1000000000));
		if(tm->tm_sec != s%60 || tm->tm_min != s/60%60 ||
		    tm->tm_hour != s/3600)
			fail(b1);
		if(tm->tm_year + 1900 != y || tm->tm_mon + 1 != m ||
		    tm->tm_mday != doy - (153*mp + 2)/5 + 1)
			fail(b1);
		if(tm->tm_wday != (int)(((d % 7) + 11) % 7))
			fail(b1);
	}
}

int
main(int argc, char **argv)
{
	int rounds;

	if(argc != 3) {
		printf("usage: fzlib seed rounds\n");
		exit(2);
	}
	seed = atol(argv[1]);
	rounds = atoi(argv[2]);
	rs = seed*2654435761UL + 23;
	for(round = 0; round < rounds; round++) {
		fzmalloc(3000);
		fzint(300);
		fzdouble(300);
		fzfloat(300);
		fzscan(300);
		fzsort(30);
		fzstr(300);
		fztime(300);
	}
	printf("fzlib ok\n");
	exit(0);
}
