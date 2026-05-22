/* printf -- minimal printf(1).  V7 didn't ship one; scripts that
 * port from later Unixes expect it.  Supports %s %d %i %x %o %c %%
 * and \n \t \\ \r \0 in both format and string args.  Format string
 * is reused if more args remain.
 */

#include <stdio.h>

static int
hexval(char c)
{
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

static int
expand(char *out, char *in)
{
	char *p = in, *q = out;
	int v, h;
	while (*p) {
		if (*p == '\\' && p[1]) {
			p++;
			switch (*p) {
			case 'n':  *q++ = '\n'; p++; break;
			case 't':  *q++ = '\t'; p++; break;
			case 'r':  *q++ = '\r'; p++; break;
			case '\\': *q++ = '\\'; p++; break;
			case 'a':  *q++ = '\a'; p++; break;
			case 'b':  *q++ = '\b'; p++; break;
			case 'f':  *q++ = '\f'; p++; break;
			case 'v':  *q++ = '\v'; p++; break;
			case 'x':
				p++;
				v = 0;
				if ((h = hexval(*p)) >= 0) {
					v = h;
					p++;
					if ((h = hexval(*p)) >= 0) {
						v = (v << 4) | h;
						p++;
					}
				} else {
					/* bare \x with no hex digit: keep literal */
					*q++ = '\\';
					*q++ = 'x';
					break;
				}
				*q++ = (char)v;
				break;
			case '0': case '1': case '2': case '3':
			case '4': case '5': case '6': case '7':
				v = 0;
				/* up to 3 octal digits */
				for (int i = 0; i < 3 && *p >= '0' && *p <= '7'; i++)
					v = (v << 3) | (*p++ - '0');
				*q++ = (char)v;
				break;
			default:   *q++ = '\\'; *q++ = *p; p++; break;
			}
		} else {
			*q++ = *p++;
		}
	}
	*q = '\0';
	return q - out;
}

static char *
emit(char *spec, char *arg)
{
	char buf[64];
	char *p = spec;
	int n;
	long iv;
	while (*p && *p != '%')
		putchar(*p++);
	if (!*p)
		return p;
	/* p points at '%' */
	buf[0] = *p++;
	n = 1;
	while (*p && n < (int)sizeof(buf) - 2 &&
	    (*p == '-' || *p == '+' || *p == ' ' || *p == '#' || *p == '0' ||
	     (*p >= '0' && *p <= '9') || *p == '.'))
		buf[n++] = *p++;
	if (!*p)
		return p;
	buf[n++] = *p;
	buf[n] = '\0';
	switch (*p++) {
	case 's':
		printf(buf, arg ? arg : "");
		break;
	case 'c':
		printf(buf, arg ? arg[0] : '\0');
		break;
	case 'd': case 'i':
	case 'o': case 'u': case 'x': case 'X':
		iv = arg ? atol(arg) : 0;
		printf(buf, (int)iv);
		break;
	case '%':
		putchar('%');
		break;
	default:
		printf("%s", buf);
		break;
	}
	return p;
}

int
main(int argc, char *argv[])
{
	char fmt[512], arg[256];
	char *p;
	int ai = 2;

	if (argc < 2)
		exit(1);
	if (argc == 2 && argv[1][0] == '\0') {
		exit(0);
	}
	{
		int n = expand(fmt, argv[1]);
		if (argc == 2) {
			if (n > 0) write(1, fmt, n);
			exit(0);
		}
	}
	while (ai < argc || (ai == argc && !*fmt /* skip */)) {
		p = fmt;
		while (*p) {
			if (*p == '%' && p[1] == '%') {
				putchar('%');
				p += 2;
			} else if (*p == '%') {
				if (ai < argc) {
					expand(arg, argv[ai++]);
					p = emit(p, arg);
				} else {
					p = emit(p, "");
				}
			} else {
				putchar(*p++);
			}
		}
		if (ai >= argc)
			break;
	}
	exit(0);
}
