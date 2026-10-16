/*
	computes a^b.
	uses log and exp
*/

#include	<errno.h>
#include <math.h>

double
pow(double arg1, double arg2)
{
	double temp, h;

	if(arg1 <= 0.) {
		if(arg1 == 0.) {
			if(arg2 <= 0.)
				goto domain;
			return(0.);
		}
		if(modf(arg2, &h) != 0.)
			goto domain;
		temp = exp(arg2 * log(-arg1));
		if(modf(arg2/2, &h) != 0.)
			temp = -temp;
		return(temp);
	}
	return(exp(arg2 * log(arg1)));

domain:
	errno = EDOM;
	return(0.);
}
