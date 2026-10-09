#include <math.h>
double
frexp(double value, int *eptr)
{
	union { double d; unsigned u[2]; } x;

	*eptr = 0;
	if (value == 0)
		return(value);
	x.d = value;
	if ((x.u[1] & 0x7ff00000) == 0) {
		x.d *= 18014398509481984.0;
		*eptr = -54;
	}
	*eptr += (int)(x.u[1]>>20 & 03777) - 1022;
	x.u[1] = (x.u[1] & 0x800fffff) | 1022<<20;
	return(x.d);
}
