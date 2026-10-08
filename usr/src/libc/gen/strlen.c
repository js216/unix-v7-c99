/*
 * Returns the number of
 * non-NULL bytes in string argument.
 */

int
strlen(register const char *s)
{
	register int n;

	n = 0;
	while (*s++)
		n++;
	return(n);
}
