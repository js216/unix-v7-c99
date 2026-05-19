double
sqrt(x)
double x;
{
	double y, last;
	int i;

	if (x <= 0.0)
		return(0.0);
	y = x;
	for (i = 0; i < 16; i++) {
		last = y;
		y = 0.5 * (y + x / y);
		if (y == last)
			break;
	}
	return(y);
}

double
exp(x)
double x;
{
	double term, sum;
	int i, neg;

	neg = 0;
	if (x < 0.0) {
		neg = 1;
		x = -x;
	}
	term = 1.0;
	sum = 1.0;
	for (i = 1; i < 40; i++) {
		term = term * x / i;
		sum += term;
		if (term == 0.0)
			break;
	}
	if (neg)
		return(1.0 / sum);
	return(sum);
}

double
log(x)
double x;
{
	double y, e, d;
	int i;

	if (x <= 0.0)
		return(0.0);
	y = 0.0;
	while (x > 2.0) {
		x /= 2.718281828459045;
		y += 1.0;
	}
	while (x < 0.5) {
		x *= 2.718281828459045;
		y -= 1.0;
	}
	for (i = 0; i < 20; i++) {
		e = exp(y);
		d = (x - e) / e;
		y += d;
		if (d < 0.0000001 && d > -0.0000001)
			break;
	}
	return(y);
}
