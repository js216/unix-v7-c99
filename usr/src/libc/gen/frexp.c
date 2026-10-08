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
