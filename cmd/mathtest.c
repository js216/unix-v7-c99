/* mathtest.c -- port-local smoke test for libm.  Prints sqrt(2), sin(pi/4),
 * and exp(1) to four decimal places using the v7 libm functions linked
 * via -lm. */
#include <stdio.h>

double sqrt(double);
double sin(double);
double exp(double);

static void
printd(char *name, double v)
{
	long whole, frac;
	int neg = 0;

	if (v < 0) { neg = 1; v = -v; }
	whole = (long)v;
	frac = (long)((v - (double)whole) * 10000.0 + 0.5);
	if (frac >= 10000) { whole++; frac -= 10000; }
	printf("%s = %s%ld.%04ld\n", name, neg ? "-" : "", whole, frac);
}

int
main(int argc, char *argv[])
{
	(void)argc; (void)argv;
	printd("sqrt(2)", sqrt(2.0));
	printd("sin(pi/4)", sin(0.7853981633974483));
	printd("exp(1)", exp(1.0));
	return 0;
}
