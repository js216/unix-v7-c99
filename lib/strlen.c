/*
 * Returns the number of non-NULL bytes in string argument.
 *
 * Ported from v7/usr/src/libc/gen/strlen.c.  K&R "register n" was
 * default-int (16-bit on PDP-11); explicit `int` keeps the same
 * name and widens to 32-bit on Armv7.
 */

int
strlen(char *s)
{
	int n;

	n = 0;
	while(*s++)
		n++;
	return(n);
}
