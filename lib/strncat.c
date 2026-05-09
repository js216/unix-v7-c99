/* Ported from v7/usr/src/libc/gen/strncat.c.
 * K&R prototype -> C99, register dropped, type widening:
 * v7's `register n` was implicit-int (16-bit on PDP-11);
 * an explicit `int` keeps the same name in C99 (32-bit on Armv7). */

char *
strncat(char *s1, char *s2, int n)
{
	char *os1;

	os1 = s1;
	while(*s1++)
		;
	--s1;
	while((*s1++ = *s2++) != 0)
		if(--n < 0) {
			*--s1 = '\0';
			break;
		}
	return(os1);
}
