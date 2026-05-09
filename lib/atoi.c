/* Ported from v7/usr/src/libc/gen/atoi.c.
 * K&R prototype -> C99, register dropped, explicit `int` return. */

int
atoi(char *p)
{
	int n;
	int f;

	n = 0;
	f = 0;
	for(;;p++) {
		switch(*p) {
		case ' ':
		case '\t':
			continue;
		case '-':
			f++;
		case '+':
			p++;
		}
		break;
	}
	while(*p >= '0' && *p <= '9')
		n = n*10 + *p++ - '0';
	return(f ? -n : n);
}
