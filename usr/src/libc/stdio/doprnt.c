#include <stdio.h>
#include <stdarg.h>

extern void _strout(char *string, int count, int adjust, FILE *file, int fillch);

static int
sputn(char *buf, long n, int base, int upper)
{
	char tmp[34];
	int len, c;
	unsigned long u;
	int neg;

	neg = 0;
	if (base == 10 && n < 0) {
		neg = 1;
		u = (unsigned long)(-n);
	} else
		u = (unsigned long)n;
	len = 0;
	if (u == 0)
		tmp[len++] = '0';
	else while (u) {
		c = (int)(u % (unsigned long)base);
		tmp[len++] = c < 10 ? c + '0'
				    : c - 10 + (upper ? 'A' : 'a');
		u /= (unsigned long)base;
	}
	if (neg)
		tmp[len++] = '-';
	{
		int i;
		for (i = 0; i < len; i++)
			buf[i] = tmp[len - 1 - i];
	}
	return(len);
}

static int
fputn(char *buf, double v, int prec, int upper)
{
	int len, i, neg, digit;
	long ipart;
	double frac, pow10;
	union { double d; unsigned long u[2]; } u;

	len = 0;
	u.d = v;
	{
		unsigned long hi = u.u[1];
		unsigned long lo = u.u[0];
		unsigned int exp = (hi >> 20) & 0x7ff;
		unsigned long mant_hi = hi & 0xfffff;
		int sign = (hi >> 31) & 1;
		if (exp == 0x7ff) {
			if (mant_hi == 0 && lo == 0) {
				if (sign) buf[len++] = '-';
				buf[len++] = upper ? 'I' : 'i';
				buf[len++] = upper ? 'N' : 'n';
				buf[len++] = upper ? 'F' : 'f';
			} else {
				buf[len++] = upper ? 'N' : 'n';
				buf[len++] = upper ? 'A' : 'a';
				buf[len++] = upper ? 'N' : 'n';
			}
			return(len);
		}
	}

	neg = 0;
	if (v < 0.0) {
		neg = 1;
		v = -v;
	}

	pow10 = 1.0;
	for (i = 0; i < prec; i++)
		pow10 = pow10 * 10.0;
	v = v + 0.5 / pow10;

	if (v >= 2147483647.0) {
		if (neg) buf[len++] = '-';
		buf[len++] = 'o';
		buf[len++] = 'v';
		buf[len++] = 'f';
		return(len);
	}

	ipart = (long)v;
	frac = v - (double)ipart;
	if (frac < 0.0)
		frac = 0.0;

	if (neg)
		buf[len++] = '-';
	len += sputn(buf + len, (long)ipart, 10, 0);
	if (prec > 0) {
		buf[len++] = '.';
		for (i = 0; i < prec; i++) {
			frac = frac * 10.0;
			digit = (int)frac;
			if (digit < 0) digit = 0;
			if (digit > 9) digit = 9;
			buf[len++] = (char)('0' + digit);
			frac = frac - (double)digit;
		}
	}
	return(len);
}

static int
eputn(char *buf, double v, int prec, int upper)
{
	int len, i, neg, exp10, sign_e, digit;
	long ipart;
	double frac;
	union { double d; unsigned long u[2]; } u;

	len = 0;
	u.d = v;
	{
		unsigned long hi = u.u[1];
		unsigned long lo = u.u[0];
		unsigned int exp = (hi >> 20) & 0x7ff;
		unsigned long mant_hi = hi & 0xfffff;
		int sign = (hi >> 31) & 1;
		if (exp == 0x7ff) {
			if (mant_hi == 0 && lo == 0) {
				if (sign) buf[len++] = '-';
				buf[len++] = upper ? 'I' : 'i';
				buf[len++] = upper ? 'N' : 'n';
				buf[len++] = upper ? 'F' : 'f';
			} else {
				buf[len++] = upper ? 'N' : 'n';
				buf[len++] = upper ? 'A' : 'a';
				buf[len++] = upper ? 'N' : 'n';
			}
			return(len);
		}
	}

	neg = 0;
	if (v < 0.0) {
		neg = 1;
		v = -v;
	}
	exp10 = 0;
	if (v != 0.0) {
		while (v >= 10.0) {
			v = v / 10.0;
			exp10++;
			if (exp10 > 308) break;
		}
		while (v < 1.0) {
			v = v * 10.0;
			exp10--;
			if (exp10 < -308) break;
		}
	}
	{
		double p = 1.0;
		for (i = 0; i < prec; i++) p = p * 10.0;
		v = v + 0.5 / p;
		if (v >= 10.0) { v = v / 10.0; exp10++; }
	}
	if (neg) buf[len++] = '-';
	ipart = (long)v;
	if (ipart < 0) ipart = 0;
	if (ipart > 9) ipart = 9;
	buf[len++] = (char)('0' + ipart);
	frac = v - (double)ipart;
	if (frac < 0.0) frac = 0.0;
	if (prec > 0) {
		buf[len++] = '.';
		for (i = 0; i < prec; i++) {
			frac = frac * 10.0;
			digit = (int)frac;
			if (digit < 0) digit = 0;
			if (digit > 9) digit = 9;
			buf[len++] = (char)('0' + digit);
			frac = frac - (double)digit;
		}
	}
	buf[len++] = upper ? 'E' : 'e';
	sign_e = 0;
	if (exp10 < 0) { sign_e = 1; exp10 = -exp10; }
	buf[len++] = sign_e ? '-' : '+';
	if (exp10 < 10) buf[len++] = '0';
	len += sputn(buf + len, (long)exp10, 10, 0);
	return(len);
}

void
_doprnt(char *fmt, va_list *argp, FILE *file)
{
	char numbuf[64];
	char *p, *s;
	int c, width, prec, fillch, ladjust, lflag, base, upper, len;

	for (p = fmt; *p; p++) {
		if (*p != '%') {
			putc(*p, file);
			continue;
		}
		p++;
		ladjust = 0;
		fillch = ' ';
		if (*p == '-') { ladjust = 1; p++; }
		if (*p == '0') { fillch = '0'; p++; }
		width = 0;
		while (*p >= '0' && *p <= '9')
			width = width * 10 + *p++ - '0';
		prec = -1;
		if (*p == '.') {
			p++;
			prec = 0;
			while (*p >= '0' && *p <= '9')
				prec = prec * 10 + *p++ - '0';
		}
		lflag = 0;
		if (*p == 'l') { lflag = 1; p++; }
		c = *p;
		{
			int pad;

			if (c == 's') {
				s = va_arg(*argp, char *);
				if (s == 0)
					s = "(null)";
				len = 0;
				while (s[len] && (prec < 0 || len < prec))
					len++;
				pad = width - len;
				if (pad < 0)
					pad = 0;
				_strout(s, len, ladjust ? pad : -pad, file, fillch);
			} else if (c == 'c') {
				numbuf[0] = (char)va_arg(*argp, int);
				pad = width - 1;
				if (pad < 0)
					pad = 0;
				_strout(numbuf, 1, ladjust ? pad : -pad, file, fillch);
			} else if (c == 'd' || c == 'u' || c == 'o' || c == 'x'
			           || c == 'X' || c == 'D' || c == 'O' || c == 'U') {
				long lv;
				int isupper;

				isupper = (c == 'X');
				upper = isupper;
				if (c == 'd') base = 10;
				else if (c == 'u' || c == 'U') base = 10;
				else if (c == 'o' || c == 'O') base = 8;
				else if (c == 'x' || c == 'X') base = 16;
				else base = 10;
				if (c == 'D' || c == 'O' || c == 'U' || c == 'X' || lflag) {
					if (c == 'd' || c == 'D')
						lv = va_arg(*argp, long);
					else
						lv = (long)va_arg(*argp, unsigned long);
				} else if (c == 'd')
					lv = (long)va_arg(*argp, int);
				else
					lv = (long)va_arg(*argp, unsigned);
				len = sputn(numbuf, lv, base, upper);
				if (prec > len) {
					int i;
					char tmp[34];
					for (i = 0; i < len; i++)
						tmp[i] = numbuf[i];
					for (i = 0; i < prec - len; i++)
						numbuf[i] = '0';
					for (i = 0; i < len; i++)
						numbuf[prec - len + i] = tmp[i];
					len = prec;
				}
				pad = width - len;
				if (pad < 0)
					pad = 0;
				_strout(numbuf, len, ladjust ? pad : -pad, file, fillch);
			} else if (c == 'f' || c == 'F' || c == 'e' || c == 'E'
				   || c == 'g' || c == 'G') {
				double dv;
				int isupper;

				isupper = (c == 'F' || c == 'E' || c == 'G');
				if (prec < 0)
					prec = 6;
				dv = va_arg(*argp, double);
				if (c == 'f' || c == 'F') {
					len = fputn(numbuf, dv, prec, isupper);
				} else if (c == 'e' || c == 'E') {
					len = eputn(numbuf, dv, prec, isupper);
				} else {
					double av = dv < 0.0 ? -dv : dv;
					int exp10 = 0;
					if (av != 0.0) {
						while (av >= 10.0) {
							av = av / 10.0;
							exp10++;
							if (exp10 > 308) break;
						}
						while (av < 1.0) {
							av = av * 10.0;
							exp10--;
							if (exp10 < -308) break;
						}
					}
					if (prec == 0) prec = 1;
					if (exp10 < -4 || exp10 >= prec)
						len = eputn(numbuf, dv, prec - 1, isupper);
					else
						len = fputn(numbuf, dv, prec - 1 - exp10, isupper);
					/* Trim trailing zeros from fraction.  Stop at the
					 * '.', then drop it too.  Walk backwards over the
					 * mantissa portion; for %e variant, preserve the
					 * 'e<exp>' tail. */
					{
						int end = len, etail = len, i;
						char ec = isupper ? 'E' : 'e';
						for (i = 0; i < len; i++)
							if (numbuf[i] == ec) { end = i; break; }
						etail = end;
						if (end > 0) {
							int has_dot = 0;
							for (i = 0; i < end; i++)
								if (numbuf[i] == '.') { has_dot = 1; break; }
							if (has_dot) {
								while (end > 0 && numbuf[end-1] == '0')
									end--;
								if (end > 0 && numbuf[end-1] == '.')
									end--;
							}
						}
						if (end != etail) {
							int tail = len - etail;
							for (i = 0; i < tail; i++)
								numbuf[end + i] = numbuf[etail + i];
							len = end + tail;
						}
					}
				}
				pad = width - len;
				if (pad < 0)
					pad = 0;
				_strout(numbuf, len, ladjust ? pad : -pad, file, fillch);
			} else if (c == '%') {
				putc('%', file);
			} else {
				putc(c, file);
			}
		}
	}
}
