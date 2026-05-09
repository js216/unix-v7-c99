/*
 * Concatenate s2 on the end of s1.  S1's space must be large enough.
 * Return s1.
 *
 * Ported from v7/usr/src/libc/gen/strcat.c.
 */

char *
strcat(char *s1, char *s2)
{
	char *os1;

	os1 = s1;
	while(*s1++)
		;
	--s1;
	while((*s1++ = *s2++) != 0)
		;
	return(os1);
}
