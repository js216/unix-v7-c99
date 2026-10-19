#include <stdio.h>
#include <stdarg.h>

void	_doprnt(char *fmt, va_list *argp, FILE *iop);

static int
gnum(register char **fmtp, va_list *argp)
{
	register int n;

	if (**fmtp == '*') {
		(*fmtp)++;
		return(va_arg(*argp, int));
	}
	for (n = 0; **fmtp >= '0' && **fmtp <= '9'; )
		n = n*10 + *(*fmtp)++ - '0';
	return(n);
}

void
_doprnt(char *fmt, va_list *argp, FILE *iop)
{
	char buf[400];
	register char *p, *s;
	register int c;
	int width, ndigit, ndfnd, rjust, zfill, base, decpt, sign, ll;
	unsigned long long u;

	for (;;) {
		for (s = fmt; *fmt && *fmt != '%'; fmt++)
			;
		if (fmt > s)
			_strout(s, fmt-s, 0, iop, ' ');
		if (*fmt++ == '\0')
			return;
		rjust = 0;
		zfill = ' ';
		if (*fmt == '-') {
			fmt++;
			rjust++;
		}
		if (*fmt == '0')
			zfill = '0';
		width = gnum(&fmt, argp);
		ndigit = ndfnd = 0;
		if (*fmt == '.') {
			s = ++fmt;
			ndigit = gnum(&fmt, argp);
			ndfnd = fmt > s;
		}
		p = s = buf;
		ll = 0;
		switch (c = *fmt++) {
		case 'l':
		case 'L':
			if ((ll = *fmt == 'l'))
				fmt++;
			switch (c = *fmt++) {
			case 'd': c = 'D'; break;
			case 'o': c = 'O'; break;
			case 'x': c = 'X'; break;
			case 'u': c = 'U'; break;
			default: fmt--; c = 'u';
			}
		}
		base = 10;
		switch (c) {
		case '\0':
			return;
		case 'd':
		case 'D':
			u = ll? va_arg(*argp,
			    long long): c=='d'? va_arg(*argp,
			    int): va_arg(*argp, long);
			if ((long long)u < 0) {
				*p++ = '-';
				u = -u;
			}
			goto num;
		case 'o':
		case 'O':
			base = 8;
			goto unum;
		case 'x':
		case 'X':
			base = 16;
			/* fallthrough */
		case 'u':
		case 'U':
		unum:
			u = ll? va_arg(*argp,
			    unsigned long long): c>='a'? va_arg(*argp,
			    unsigned): va_arg(*argp, unsigned long);
		num:
			if (ndigit && u)
				*p++ = '0';
			s = &buf[sizeof buf];
			do
				*--s = "0123456789abcdef"[u%base];
			while (u /= base);
			while (s < &buf[sizeof buf])
				*p++ = *s++;
			s = buf;
			break;
		case 'e':
		case 'f':
		case 'g':
			if (!ndfnd)
				ndigit = 6;
			if (ndigit > 70)
				ndigit = 70;
			if (c == 'g') {
				gcvt(va_arg(*argp, double), ndigit,
				    buf);
				while (*p)
					p++;
				break;
			}
			s = (c=='e'? ecvt: fcvt)(va_arg(*argp, double),
			    ndigit+(c=='e'), &decpt, &sign);
			if (sign)
				*p++ = '-';
			if (c == 'e') {
				if (*s == '0')
					decpt++;
				*p++ = *s++;
				*p++ = '.';
				for (c = ndigit; c > 0; c--)
					*p++ = *s++;
				*p++ = 'e';
				if (--decpt < 0) {
					*p++ = '-';
					decpt = -decpt;
				} else
					*p++ = '+';
				if (decpt >= 100) {
					*p++ = decpt/100 + '0';
					decpt %= 100;
				}
				*p++ = decpt/10 + '0';
				*p++ = decpt%10 + '0';
			} else {
				if (decpt <= 0)
					*p++ = '0';
				for (c = decpt; c > 0; c--)
					*p++ = *s? *s++: '0';
				if (ndigit)
					*p++ = '.';
				for (c = ndigit; c > 0; c--)
					*p++ = decpt++ < 0 ||
					    !*s? '0': *s++;
			}
			s = buf;
			break;
		case 'c':
			zfill = ' ';
			if ((*p = va_arg(*argp, int)) != 0)
				p++;
			break;
		case 's':
			zfill = ' ';
			if ((s = p = va_arg(*argp, char *)) == 0)
				s = p = "(null)";
			while (*p && (!ndfnd || ndigit-- > 0))
				p++;
			break;
		default:
			*p++ = c;
		}
		c = width - (p - s);
		if (c < 0)
			c = 0;
		_strout(s, p - s, rjust? c: -c, iop, zfill);
	}
}
