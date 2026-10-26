/*
	C library - ascii to floating
*/

#include <math.h>
#include <ctype.h>

/*
 * The digits are kept exactly, as a big integer of 32-bit limbs, least
 * significant first, and the result is rounded once, to the nearest
 * double, ties to even.
 */
#define	NLIMB	130		/* 4160 bits */
#define	MAXDIG	800		/* more digits only decide a tie */

typedef struct {
	int	n;
	unsigned	w[NLIMB];
} big;

static void
bmuladd(big *a, unsigned m, unsigned c)
{
	register int i;
	unsigned long long t;

	for(i = 0; i < a->n; i++) {
		t = (unsigned long long)a->w[i]*m + c;
		a->w[i] = t;
		c = t >> 32;
	}
	if(c && a->n < NLIMB)
		a->w[a->n++] = c;
}

static int
bbits(big *a)
{
	register int n;
	register unsigned w;

	if(a->n == 0)
		return(0);
	w = a->w[a->n-1];
	for(n = 0; w; n++)
		w >>= 1;
	return(32*(a->n-1) + n);
}

static void
bshl(big *a, int s)
{
	register int i, q, r;

	if(a->n == 0)
		return;
	q = s/32;
	r = s%32;
	a->w[a->n] = 0;
	for(i = a->n; i >= 0; i--)
		if(i+q < NLIMB)
			a->w[i+q] = (r && i > 0 ? a->w[i-1] >> (32-r) : 0) |
			    a->w[i] << r;
	for(i = 0; i < q; i++)
		a->w[i] = 0;
	a->n += q + 1;
	while(a->n > 0 && a->w[a->n-1] == 0)
		a->n--;
}

static int
bcmp(big *a, big *b)
{
	register int i;

	if(a->n != b->n)
		return(a->n < b->n ? -1 : 1);
	for(i = a->n-1; i >= 0; i--)
		if(a->w[i] != b->w[i])
			return(a->w[i] < b->w[i] ? -1 : 1);
	return(0);
}

static void
bsub(big *a, big *b)
{
	register int i;
	unsigned long long t;
	unsigned c;

	c = 0;
	for(i = 0; i < a->n; i++) {
		t = (unsigned long long)a->w[i] - (i < b->n ? b->w[i] : 0) - c;
		a->w[i] = t;
		c = (t >> 32) & 1;
	}
	while(a->n > 0 && a->w[a->n-1] == 0)
		a->n--;
}

static void
bpow10(big *a, int e)
{
	for(; e >= 9; e -= 9)
		bmuladd(a, 1000000000, 0);
	for(; e > 0; e--)
		bmuladd(a, 10, 0);
}

static big	num, den, t;

static void
bassign(big *d, big *s)
{
	register int i;

	d->n = s->n;
	for(i = 0; i < s->n; i++)
		d->w[i] = s->w[i];
}
static int	nd, dexp, sticky;

/*
 * One digit of the mantissa, in its fraction if frac.  Leading zeros
 * are only counted; digits beyond MAXDIG only scale, and record
 * whether any is not zero.
 */
static void
digit(int c, int frac)
{
	if (nd == 0 && c == '0') {
		if (frac)
			dexp--;
		return;
	}
	if (nd < MAXDIG) {
		bmuladd(&num, 10, c-'0');
		nd++;
		if (frac)
			dexp--;
	} else {
		if (c != '0')
			sticky = 1;
		if (!frac)
			dexp++;
	}
}

double
atof(register char *p)
{
	register int c, i;
	int eexp, neg, negexp, e2, k, prec, drop;
	unsigned long long q, m, rem, half;

	neg = 0;
	while((c = *p++) == ' ')
		;
	if (c == '-')
		neg = 1;
	else if (c=='+')
		;
	else
		--p;

	num.n = 0;
	nd = dexp = sticky = 0;
	while ((c = *p++), isdigit(c))
		digit(c, 0);
	if (c == '.')
		while ((c = *p++), isdigit(c))
			digit(c, 1);
	if (sticky) {
		bmuladd(&num, 10, 1);
		dexp--;
	}

	negexp = 1;
	eexp = 0;
	if ((c == 'E') || (c == 'e')) {
		if ((c= *p++) == '+')
			;
		else if (c=='-')
			negexp = -1;
		else
			--p;

		while ((c = *p++), isdigit(c)) {
			if (eexp < 10000)
				eexp = 10*eexp+(c-'0');
		}
		if (negexp<0)
			eexp = -eexp;
		dexp = dexp + eexp;
	}

	/*
	 * The value is num * 10^dexp, of nd digits.
	 */
	if (num.n == 0 || nd + dexp < -330)
		return(neg ? -0.0 : 0.0);
	if (nd + dexp > 310)
		return(neg ? -HUGE : HUGE);
	den.n = 1;
	den.w[0] = 1;
	if (dexp >= 0)
		bpow10(&num, dexp);
	else
		bpow10(&den, -dexp);

	/*
	 * q = num * 2^k / den, of 62 or 63 bits; sticky
	 * records a remainder.
	 */
	k = 62 - (bbits(&num) - bbits(&den));
	if (k > 0)
		bshl(&num, k);
	else if (k < 0)
		bshl(&den, -k);
	q = 0;
	for (i = 63; i >= 0; i--) {
		bassign(&t, &den);
		bshl(&t, i);
		if (bcmp(&num, &t) >= 0) {
			bsub(&num, &t);
			q |= 1ULL << i;
		}
	}
	sticky = num.n != 0;

	/*
	 * Round q to the precision of the result: 53 bits, or fewer
	 * for a subnormal.
	 */
	for (e2 = 63; !(q >> e2 & 1); e2--)
		;
	drop = e2;
	e2 -= k;
	if (e2 < -1075)
		return(neg ? -0.0 : 0.0);
	prec = e2 < -1022 ? 1075 + e2 : 53;
	drop = drop + 1 - prec;
	m = q >> drop;
	rem = q & ((1ULL << drop) - 1);
	half = 1ULL << (drop - 1);
	if (rem > half || (rem == half && (sticky || (m & 1))))
		m++;
	/*
	 * m has at most 54 bits, so its halves convert exactly.
	 */
	return(ldexp((neg ? -1.0 : 1.0) * ((double)(unsigned)(m >> 32) *
	    4294967296.0 + (double)(unsigned)m), drop - k));
}
