/*
 * C99/Armv7 replacement for v7's libc/stdio/doprnt.s -- the original
 * is PDP-11 assembly and cannot be ported as-is.  This implementation
 * handles the integer/string/char specifiers v7 supports (%d %u %o %x
 * %D %O %X %U %ld %lu %s %c) plus width, '-' left-justify, '0' zero-
 * pad, and '.prec'.  Floating-point (%e %f %g) is omitted: nothing in
 * the unix-v7-c99 cmd tree currently formats floats, and pulling in
 * libgcc's softfp helpers would balloon every binary that calls
 * printf -- the same trap atof avoided.
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

void
_doprnt(fmt, argp, file)
char *fmt;
va_list *argp;
FILE *file;
{
	char numbuf[34];
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
			} else if (c == '%') {
				putc('%', file);
			} else {
				putc(c, file);
			}
		}
	}
}
