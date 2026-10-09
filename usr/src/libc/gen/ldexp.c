#include <errno.h>
#include <math.h>

double
ldexp(double value, int n)
{
	union { double d; unsigned u[2]; } x;
	register int k;

	x.u[0] = 0;
	for (; n; n -= k) {
		k = n > 1000? 1000: n < -1000? -1000: n;
		x.u[1] = (k+1023) << 20;
		value *= x.d;
	}
	if (value > 1.7976931348623157e308 || value < -1.7976931348623157e308) {
		errno = ERANGE;
		value = value < 0? -1.7976931348623157e308: 1.7976931348623157e308;
	}
	return(value);
}
