/*
 *	ecvt converts to decimal
 *	the number of digits is specified by ndigit
 *	decpt is set to the position of the decimal point
 *	sign is set to 0 for positive, 1 for negative
 */

#include <stdio.h>
#include <math.h>
static char	*cvt(double arg, int ndigits, int *decpt, int *sign,
    int eflag);

#define	NDIG	80
char*
ecvt(double arg, int ndigits, int *decpt, int *sign)
{
	return(cvt(arg, ndigits, decpt, sign, 1));
}

char*
fcvt(double arg, int ndigits, int *decpt, int *sign)
{
	return(cvt(arg, ndigits, decpt, sign, 0));
}

/*
 * The digits are those of the exact value of arg, rounded once, to
 * nearest, ties to even.  arg is m * 2^e, which is split into an
 * integer part and a fraction of s bits, both big integers of
 * 32-bit limbs, least significant first.
 */
#define	NLIMB	40		/* 1280 bits */

typedef struct {
	int	n;
	unsigned	w[NLIMB];
} big;

static big	ip, fp;
static int	fs, ni, gi;
static char	id[320];	/* the integer part's digits, last first */

static unsigned
bdiv10(big *a)
{
	register int i;
	unsigned r, h, l;

	r = 0;
	for(i = a->n-1; i >= 0; i--) {
		h = r << 16 | a->w[i] >> 16;
		r = h % 10;
		l = r << 16 | (a->w[i] & 0xffff);
		r = l % 10;
		a->w[i] = (h / 10) << 16 | l / 10;
	}
	while(a->n > 0 && a->w[a->n-1] == 0)
		a->n--;
	return(r);
}

static void
bmul10(big *a)
{
	register int i;
	unsigned long long t;
	unsigned c;

	c = 0;
	for(i = 0; i < a->n; i++) {
		t = (unsigned long long)a->w[i]*10 + c;
		a->w[i] = t;
		c = t >> 32;
	}
	if(c)
		a->w[a->n++] = c;
}

/*
 * The next digit of the fraction: fp*10, less its bits from fs up,
 * which are the digit.
 */
static int
fdigit(void)
{
	register int q, r, d;

	if(fp.n == 0)
		return(0);
	bmul10(&fp);
	q = fs/32;
	r = fs%32;
	d = 0;
	if(q < fp.n)
		d = fp.w[q] >> r;
	if(r && q+1 < fp.n)
		d |= fp.w[q+1] << (32-r);
	if(q < fp.n) {
		fp.w[q] &= r ? (1U << r) - 1 : 0;
		fp.n = q + 1;
	}
	while(fp.n > 0 && fp.w[fp.n-1] == 0)
		fp.n--;
	return(d);
}

/*
 * The next digit of the value, the integer part's first.
 */
static int
next(void)
{
	if(gi < ni)
		return(id[ni-1-gi++]);
	return(fdigit());
}

static char*
cvt(double arg, int ndigits, int *decpt, int *sign, int eflag)
{
	register int i, k, d;
	int e, r2, sticky, up;
	unsigned long long m;
	unsigned h;
	double x;
	static char buf[NDIG];

	if (ndigits<0)
		ndigits = 0;
	if (ndigits>=NDIG-1)
		ndigits = NDIG-2;
	*sign = 0;
	if (arg<0) {
		*sign = 1;
		arg = -arg;
	}
	if (!(arg <= 1.7976931348623157e308))
		arg = 1.7976931348623157e308;
	if (arg == 0) {
		*decpt = 0;
		for (i = 0; i < ndigits && i < NDIG-1; i++)
			buf[i] = '0';
		buf[i] = '\0';
		return(buf);
	}
	x = ldexp(frexp(arg, &e), 53);
	e -= 53;
	h = x / 4294967296.0;
	m = (unsigned long long)h << 32 | (unsigned)(x - h * 4294967296.0);
	ip.n = fp.n = 0;
	fs = 0;
	if (e >= 0) {
		ip.w[0] = m;
		ip.w[1] = m >> 32;
		ip.n = 2;
		for (; e >= 32; e -= 32) {
			for (i = ip.n; i > 0; i--)
				ip.w[i] = ip.w[i-1];
			ip.w[0] = 0;
			ip.n++;
		}
		for (; e > 0; e--) {
			unsigned c = 0;
			for (i = 0; i < ip.n; i++) {
				unsigned w = ip.w[i];
				ip.w[i] = w << 1 | c;
				c = w >> 31;
			}
			if (c)
				ip.w[ip.n++] = c;
		}
	} else {
		fs = -e;
		if (fs < 64) {
			ip.w[0] = m >> fs;
			ip.w[1] = (m >> fs) >> 32;
			ip.n = 2;
			m &= (1ULL << fs) - 1;
		}
		fp.w[0] = m;
		fp.w[1] = m >> 32;
		fp.n = 2;
	}
	while (ip.n > 0 && ip.w[ip.n-1] == 0)
		ip.n--;
	while (fp.n > 0 && fp.w[fp.n-1] == 0)
		fp.n--;

	/*
	 * The digits of the integer part, then the first digit of all;
	 * leading zeros of a fraction only move the point.
	 */
	for (ni = 0; ip.n > 0; )
		id[ni++] = bdiv10(&ip);
	gi = 0;
	r2 = ni;
	d = next();
	if (ni == 0)
		for (; d == 0; d = next())
			r2--;
	*decpt = r2;
	k = ndigits;
	if (eflag == 0)
		k += r2;
	if (k < 0) {
		buf[0] = '\0';
		return(buf);
	}
	if (k > NDIG-1) {
		for (i = 0; i < NDIG-1; i++, d = next())
			buf[i] = d + '0';
		buf[NDIG-1] = '\0';
		return(buf);
	}
	for (i = 0; i < k; i++, d = next())
		buf[i] = d + '0';
	buf[k] = '\0';

	/*
	 * d is the first digit dropped; the rest is zero only if no
	 * digit of the integer part and no bit of the fraction is left.
	 */
	sticky = fp.n != 0;
	for (; gi < ni; gi++)
		if (id[ni-1-gi])
			sticky = 1;
	up = d > 5 || (d == 5 && (sticky || (k > 0 && (buf[k-1] & 1))));
	if (!up)
		return(buf);
	for (i = k-1; i >= 0 && buf[i] == '9'; i--)
		buf[i] = '0';
	if (i >= 0) {
		buf[i]++;
		return(buf);
	}
	buf[0] = '1';
	(*decpt)++;
	if (k == 0)
		buf[1] = '\0';
	else if (eflag == 0) {
		buf[k] = '0';
		buf[k+1] = '\0';
	}
	return(buf);
}
