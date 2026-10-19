extern double fabs(double arg), floor(double d), ceil(double d);
extern double fmod(double x, double y), ldexp(double value, int n);
extern double sqrt(double arg), hypot(double a, double b),
    atof(char *p);
extern double sin(double arg), cos(double arg), tan(double arg);
extern double asin(double arg), acos(double arg), atan(double arg);
extern double atan2(double arg1, double arg2);
extern double exp(double arg), log(double arg), log10(double arg);
extern double pow(double arg1, double arg2);
extern double sinh(double arg), cosh(double arg), tanh(double arg);
extern double gamma(double arg);
extern double j0(double arg), j1(double arg), jn(int n, double x);
extern double y0(double arg), y1(double arg), yn(int n, double x);
extern double modf(double value, double *iptr),
    frexp(double value, int *eptr);

#define HUGE	1.797693134862315708e308
#define LOGHUGE 308
