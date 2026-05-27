double
frexp(double value, int *eptr)
{
	union { double d; unsigned int u[2]; } u;
	int exp;

	u.d = value;
	exp = (int)((u.u[1] >> 20) & 0x7ff);
	if (value == 0.0) {
		*eptr = 0;
		return (0.0);
	}
	if (exp == 0x7ff) {
		*eptr = 0;
		return (value);
	}
	*eptr = exp - 1022;
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
		return (value < 0 ? -1e308 * 10.0 : 1e308 * 10.0);
	if (exp <= 0) {
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
		*iptr = value;
		return (0.0);
	}
	ll = (long)value;
	ipart = (double)ll;
	*iptr = ipart;
	return (value - ipart);
}
