/*
 * math_helpers.c -- port-local replacements for the v7 PDP-11 assembly
 * floating-point helpers frexp11.s, ldexp11.s, modf11.s (under
 * v7/usr/src/libc/gen/).  Same prototypes the v7 libm and libc consumers
 * expect (extern double frexp(); etc.) using IEEE-754 double-precision
 * bit manipulation on ARM AAPCS.
 */

double
frexp(double value, int *eptr)
{
	union { double d; unsigned int u[2]; } u;
	int exp;

	u.d = value;
	/* IEEE-754 double, little-endian (ARM): u[1] holds sign+exp+top mantissa,
	 * u[0] holds the low mantissa bits. */
	exp = (int)((u.u[1] >> 20) & 0x7ff);
	if (value == 0.0) {
		*eptr = 0;
		return (0.0);
	}
	if (exp == 0x7ff) {
		/* +-Inf or NaN: leave value alone, no decomposition. */
		*eptr = 0;
		return (value);
	}
	*eptr = exp - 1022;
	/* Force the biased exponent to 1022 so the result lies in [0.5, 1). */
	u.u[1] = (u.u[1] & 0x800fffffU) | (1022U << 20);
	return (u.d);
}

double
ldexp(double value, int n)
{
	union { double d; unsigned int u[2]; } u;
	int exp;

	if (value == 0.0)
		return (0.0);
	u.d = value;
	exp = (int)((u.u[1] >> 20) & 0x7ff);
	if (exp == 0x7ff)
		return (value);
	exp += n;
	if (exp >= 0x7ff)
		/* Overflow: clamp to +-Inf */
		return (value < 0 ? -1e308 * 10.0 : 1e308 * 10.0);
	if (exp <= 0) {
		/* Underflow: scale by repeated halving so we get a graceful 0,
		 * rather than handling denormals here. */
		double v = value;
		while (exp <= 0) { v *= 0.5; exp++; }
		return (v);
	}
	u.u[1] = (u.u[1] & 0x800fffffU) | ((unsigned)exp << 20);
	return (u.d);
}

double
modf(double value, double *iptr)
{
	double ipart;
	long ll;

	if (value < 0.0) {
		double r = modf(-value, &ipart);
		*iptr = -ipart;
		return (-r);
	}
	if (value >= 9.2233720368547758e18) {
		/* Beyond LLONG_MAX: whole value is integral. */
		*iptr = value;
		return (0.0);
	}
	ll = (long)value;
	ipart = (double)ll;
	*iptr = ipart;
	return (value - ipart);
}
