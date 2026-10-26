#include <errno.h>
#include <math.h>

double
ldexp(double value, int n)
{
	union { double d; unsigned u[2]; } x, p;
	int e;

	if (value == 0)
		return(value);
	x.d = frexp(value, &e);
	if (n > 2200)
		n = 2200;
	if (n < -2200)
		n = -2200;
	e += n;
	if (e > 1024) {
		errno = ERANGE;
		return(value <
		    0? -1.7976931348623157e308: 1.7976931348623157e308);
	}
	if (e >= -1021) {
		x.u[1] = (x.u[1] & 0x800fffff) | (e+1022) << 20;
		return(x.d);
	}
	if (e < -1074)
		return(x.d * 0.0);
	p.u[0] = p.u[1] = 0;
	if (e+1074 < 32)
		p.u[0] = 1U << (e+1074);
	else
		p.u[1] = 1U << (e+1074-32);
	return(x.d * p.d);
}
