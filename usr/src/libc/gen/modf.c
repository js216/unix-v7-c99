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
