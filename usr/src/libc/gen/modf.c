#include <math.h>
double
modf(double value, double *iptr)
{
	union { double d; unsigned u[2]; } x;
	register int e;

	x.d = value;
	e = (int)(x.u[1]>>20 & 03777) - 1023;
	if (e < 0) {
		x.u[1] &= 0x80000000;
		x.u[0] = 0;
	} else if (e < 20) {
		x.u[1] &= ~(0xfffff>>e);
		x.u[0] = 0;
	} else if (e < 52)
		x.u[0] &= ~(0xffffffff>>(e-20));
	*iptr = x.d;
	return(value - x.d);
}
