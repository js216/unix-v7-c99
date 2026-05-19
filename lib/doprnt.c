/*
 * C99/Armv7 replacement for v7's libc/stdio/doprnt.s -- the original
 * is PDP-11 assembly and cannot be ported as-is.  This implementation
 * handles the integer/string/char specifiers v7 supports (%d %u %o %x
 * %D %O %X %U %ld %lu %s %c) plus width, '-' left-justify, '0' zero-
 * pad, and '.prec'.  A minimal %f / %F / %e / %E / %g / %G is also
 * provided: ARMv7 has no FPU instructions when we build with the
 * default softvfp ABI, but libgcc's __aeabi_d* helpers do the actual
 * arithmetic, so floats cost a handful of helper calls per format and
 * iostat's ratios print correctly.  Special-cases inf/-inf/nan; no
 * %a, no '+' flag, no locale.
 */
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

/*
 * Format a double into buf as "[-]int.frac".  Returns the number of
 * bytes written.  prec is the number of fractional digits (default 6).
 * Handles negative, NaN, and infinity.  No exponent form.  Rounds the
 * trailing fractional digit by adding 0.5 ulp before truncation.
 *
 * The algorithm is the obvious one: split into integer and fractional
 * parts, format the integer with sputn(), then walk the fraction one
 * digit at a time (multiply by 10, take int part).  This is enough for
 * iostat-style ratios; it loses precision for very large magnitudes
 * (|x| >= 2^31) and we explicitly bail out to "ovf" there rather than
 * silently print garbage.
 */
static int
fputn(char *buf, double v, int prec, int upper)
{
	int len, i, neg, digit;
	long ipart;
	double frac, pow10;
	union { double d; unsigned long u[2]; } u;

	len = 0;
	/* NaN / +-Inf detection without libm.  IEEE-754 double:
	 * exponent == 0x7ff -> NaN (mantissa != 0) or +-Inf (mantissa == 0).
	 * Bytes are little-endian on ARM EABI, so u[1] holds the high word. */
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

	/* Round to `prec` fractional digits before splitting, so that
	 * e.g. 0.999999 with prec=2 prints "1.00" and not "0.99". */
	pow10 = 1.0;
	for (i = 0; i < prec; i++)
		pow10 = pow10 * 10.0;
	v = v + 0.5 / pow10;

	/* Refuse magnitudes that don't fit a signed long -- the only
	 * sane thing without a real %e fallback is to surface the limit.
	 * iostat ratios are always small, so this never trips in practice. */
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
		frac = 0.0;	/* guard against rounding-mode quirks */

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

/*
 * Same as fputn() but emits scientific form "d.dddedd".  Used by
 * %e/%E and as %g's exponent-form fallback.  We compute the decimal
 * exponent by repeated multiplication/division -- no log10, no libm.
 */
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
	/* Round after normalization. */
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
_doprnt(fmt, argp, file)
char *fmt;
va_list *argp;
FILE *file;
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
					/* %g/%G: pick %e if exponent < -4 or
					 * >= prec, else %f.  Treat prec==0 as 1
					 * per C89.  Trim trailing zeros (and the
					 * trailing '.' if no fractional digits
					 * remain) to match C printf semantics --
					 * awk's default OFMT is %.6g and v7 awk
					 * prints integer floats as plain ints. */
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
