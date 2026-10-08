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
