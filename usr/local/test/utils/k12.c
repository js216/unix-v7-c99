#include <stdio.h>
#include <math.h>
#include <errno.h>

int
main(void)
{
	char t[6];
	double inf, nan;

	strcpy(t, "XXXXX");
	printf("mktemp %d\n",
	    mktemp(t) == t && t[0] >= '0' && t[0] <= '9');
	errno = 0;
	printf("pow %g %g", pow(-2., 3.), pow(-1., 1e30));
	pow(-2., .5);
	printf(" %d\n", errno == EDOM);
	inf = HUGE * 10.;
	nan = inf - inf;
	printf("nan %d %d %d\n", nan != nan, sin(inf) != sin(inf),
	    exp(nan) != exp(nan));
	return 0;
}
